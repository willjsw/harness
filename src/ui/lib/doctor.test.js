import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { explain, SECTIONS, STATUS_TIMEOUT_MS, REMOTE_TIMEOUT_DEFAULT, REMOTE_TIMEOUT_LIMIT, RUNNER_CHECK_AFTER_START, remoteCallLimit, remoteCallTimeoutMs, remoteStatusTimeoutMs } from "./doctor.js";

test("explain", () => {
  const b = "/demo";
  assert.deepEqual(explain({ state: "bad", what: "git hooks enabled", detail: "run `git config core.hooksPath script/githooks`" }, b).run.kind, "hooks");
  assert.equal(explain({ state: "warn", what: ".ai/project/glossary.md", detail: "2 placeholder(s) still to fill" }, b).href, "/demo/project/glossary");
  assert.match(explain({ state: "warn", what: ".ai/project/glossary.md", detail: "2 placeholder(s) still to fill" }, b).body, /2곳/);
  assert.equal(explain({ state: "bad", what: "3 files differ from the config", detail: "" }, b).run.kind, "render");
  assert.equal(explain({ state: "bad", what: "script/verify-project.sh", detail: "" }, b).run.kind, "verify");
  const unset = explain({ state: "bad", what: "script/harness-verify.sh", detail: "not set up — no commands yet" }, b);
  assert.equal(unset.label, "SETUP");
  assert.equal(unset.href, "/demo/project/commands");
  assert.match(explain({ state: "bad", what: "script/harness-verify.sh", detail: "fails at 테스트" }, b).title, /테스트/);
  // 모르는 줄은 원문 그대로
  assert.deepEqual(explain({ state: "warn", what: "something new", detail: "why" }, b), { title: "something new", body: "why" });
});

test("the git hooks command comes from the doctor detail", () => {
  const b = "/demo";
  const root = explain({ state: "bad", what: "git hooks enabled", detail: "run `git config core.hooksPath script/githooks`" }, b);
  assert.equal(root.run.cmd, "git config core.hooksPath script/githooks");
  const sub = explain({ state: "bad", what: "git hooks enabled", detail: "run `git config core.hooksPath packages/api/script/githooks`" }, b);
  assert.equal(sub.run.cmd, "git config core.hooksPath packages/api/script/githooks");
  assert.equal(sub.run.kind, "hooks");
  const none = explain({ state: "bad", what: "git hooks enabled", detail: "not a git repository" }, b);
  assert.equal(none.run, undefined);
  assert.match(none.title, /git 훅/);
});

test("explain registry lines", () => {
  const b = "/demo";
  const line = { state: "warn", what: "`demo` is registered to another path", detail: "/elsewhere/demo" };
  const other = explain(line, b);
  assert.notEqual(other.title, line.what);
  assert.notEqual(other.body, line.detail);
  assert.match(other.body, /\/elsewhere\/demo/);
  assert.equal(other.cmd, "harness install");
  const none = explain({ state: "warn", what: "this repository is not registered", detail: "run `harness install` to list it in the UI" }, b);
  assert.equal(none.cmd, "harness install");
  assert.notEqual(none.title, "this repository is not registered");
  assert.equal(SECTIONS.registry, "등록");
});

test("explain remote lines", () => {
  const b = "/demo";
  const r = (what, detail, state = "bad") => ({ section: "remote", state, what, detail });
  const differs = (line) => { const x = explain(line, b); assert.notEqual(x.title, line.what); return x; };
  assert.equal(SECTIONS.remote, "원격");

  const nogit = differs(r("remote `origin`", "not a git repository"));
  assert.equal(nogit.cmd, undefined); assert.equal(nogit.href, undefined); assert.equal(nogit.run, undefined);
  assert.match(nogit.title, /git 리포가 아니/);

  assert.equal(differs(r("remote `origin`", "not set — run `git remote add origin <url>`")).cmd, "git remote add origin <url>");
  assert.equal(differs(r("branch `develop` on origin", "missing — run `git push origin develop`")).cmd, "git push origin develop");

  const head = differs(r("origin default branch", "is `trunk`, not branches.base `develop` — new clones and review requests start from it", "warn"));
  assert.match(head.title, /trunk/);
  assert.equal(head.href, "/demo/settings");

  assert.equal(differs(r("sign-in to `github`", "not signed in — run `gh auth login`")).cmd, "gh auth login");

  const label = differs(r("label `Task`", "missing on github — create it on the forge", "warn"));
  assert.equal(label.cmd, undefined); assert.equal(label.href, undefined); assert.equal(label.run, undefined);
  const prot = differs(r("branch protection `main`", "not protected on github — only local hooks block direct pushes; protect it on the forge", "warn"));
  assert.equal(prot.cmd, undefined); assert.equal(prot.href, undefined); assert.equal(prot.run, undefined);
  assert.notEqual(prot.title, label.title);

  const runner = differs(r("reviewer runner `codex`", "codex is not installed (roles.code-reviewer.runner = codex)"));
  assert.match(runner.body, /codex is not installed/);
  assert.equal(runner.href, "/demo/agents");

  for (const line of [r("branch `develop` on origin", "could not check — git ls-remote failed", "warn"),
                      r("labels", "could not check", "warn"),
                      r("sign-in to `github`", "could not check", "warn")]) {
    const x = differs(line);
    assert.match(x.title, /확인하지 못했습니다/);
  }
});

test("the remote call timeout defaults and limits match the CLI's", () => {
  const cli = fs.readFileSync(new URL("../../bin/harness", import.meta.url), "utf8");
  assert.equal(REMOTE_TIMEOUT_DEFAULT, Number(cli.match(/^DOCTOR_DEFAULTS = \{"remote_timeout": (\d+)\}$/m)?.[1]));
  assert.equal(REMOTE_TIMEOUT_LIMIT, Number(cli.match(/^REMOTE_TIMEOUT_LIMIT = (\d+)$/m)?.[1]));
  assert.equal(RUNNER_CHECK_AFTER_START, Number(cli.match(/^RUNNER_CHECK_AFTER_START = (\d+)$/m)?.[1]));
});

test("the remote call timeout comes from doctor.remote_timeout, else the default", () => {
  assert.equal(remoteCallTimeoutMs({ doctor: { remote_timeout: 45 } }), 45_000);
  assert.equal(remoteCallTimeoutMs({ doctor: { remote_timeout: 1 } }), 1_000);
  assert.equal(remoteCallTimeoutMs({ doctor: { remote_timeout: 600 } }), 600_000);
  for (const cfg of [null, {}, { doctor: {} }, { doctor: { remote_timeout: 0 } }, { doctor: { remote_timeout: -5 } },
                     { doctor: { remote_timeout: 601 } }, { doctor: { remote_timeout: "45" } }, { doctor: { remote_timeout: 2.5 } },
                     { doctor: { remote_timeout: true } }]) {
    assert.equal(remoteCallTimeoutMs(cfg), REMOTE_TIMEOUT_DEFAULT * 1000, JSON.stringify(cfg));
  }
  const cfg = { doctor: { remote_timeout: 45 }, branches: { protected: ["main", "develop"] } };
  assert.equal(remoteStatusTimeoutMs(cfg), 60_000 + (7 + 2) * 45_000);
});

test("remote status waits longer than every remote call timing out in turn", () => {
  assert.equal(remoteCallLimit(null), 5);
  assert.equal(remoteCallLimit({ branches: { protected: "main" } }), 5);
  assert.equal(remoteCallLimit({ forge: { tracker: "github", review_host: "github" }, branches: { protected: ["main", "develop", "main"] } }), 7);

  for (const cfg of [null, { branches: { protected: ["main", "develop"] } }, { branches: { protected: ["a", "b", "c", "d", "e", "f"] } },
                     { doctor: { remote_timeout: 120 }, branches: { protected: ["main", "develop"] } }]) {
    const t = remoteStatusTimeoutMs(cfg);
    const perCall = (cfg?.doctor?.remote_timeout ?? REMOTE_TIMEOUT_DEFAULT) * 1000;
    // 리뷰어 러너 호출은 시작 알림까지 하나, 알린 뒤로 RUNNER_CHECK_AFTER_START 개의 호출 제한을 쓴다
    const worst = (remoteCallLimit(cfg) - 1) * perCall + (1 + RUNNER_CHECK_AFTER_START) * perCall;
    assert.ok(t > worst, JSON.stringify(cfg));
    assert.ok(t - worst >= STATUS_TIMEOUT_MS, JSON.stringify(cfg));
  }
  assert.equal(remoteStatusTimeoutMs({ branches: { protected: ["main", "develop"] } }), 60_000 + (7 + 2) * 30_000);
});

test("explain managed file lines", () => {
  const b = "/demo";
  const m = (what, detail = "", state = "bad") => ({ section: "managed files", state, what, detail });
  assert.equal(SECTIONS["managed files"], "관리 파일");
  const edited = explain(m("modified managed file", "script/review-mr.sh"), b);
  assert.notEqual(edited.title, "modified managed file");
  assert.match(edited.body, /script\/review-mr\.sh/);
  assert.match(edited.body, /script\/project\//);
  assert.equal(edited.run.kind, "render");
  const gone = explain(m("missing managed file", "script/hooks/_guards.sh"), b);
  assert.notEqual(gone.title, "missing managed file");
  assert.match(gone.body, /script\/hooks\/_guards\.sh/);
  assert.equal(gone.run.kind, "render");
  for (const what of ["modified managed file", "missing managed file"]) {
    const pinned = explain(m(what, ".harness/templates/harness.toml"), b);
    assert.equal(pinned.cmd, "harness install");
    assert.equal(pinned.run, undefined);
    assert.match(pinned.body, /\.harness\/templates\/harness\.toml/);
  }
  const more = explain(m("3 more modified or missing managed file(s)"), b);
  assert.match(more.title, /3개/);
  assert.equal(more.run.kind, "render");
  const unhashed = explain(m("12 managed files have no recorded hash", "run `harness render`", "warn"), b);
  assert.match(unhashed.body, /12개/);
  assert.equal(unhashed.run.kind, "render");
  const copy = explain(m("the pinned copy has no recorded hash", "run `harness install`", "warn"), b);
  assert.notEqual(copy.title, "the pinned copy has no recorded hash");
  assert.equal(copy.cmd, "harness install");
  assert.equal(explain(m("no manifest of managed files", "run `harness render`", "warn"), b).run.kind, "render");
});
