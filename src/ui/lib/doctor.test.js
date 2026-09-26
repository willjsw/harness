import { test } from "node:test";
import assert from "node:assert/strict";
import { explain } from "./doctor.js";

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
