"use server";
import { revalidatePath } from "next/cache";
import { DOCS, fieldsOf, UNKNOWN } from "./fields.js";
import { staticCheck, parseVerdict, answered, asText } from "./validate.js";
import { staticIssues, parseIssues, numbered } from "./mdcheck.js";
import fs from "node:fs/promises";
import nodePath from "node:path";
import os from "node:os";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { getProject, readConfig, harness, readDoc, readDocTemplate, writeDoc, ask, readTools, readSchema, writeRoleNotes, listProjects, HOME, readStatus } from "./harness.js";

// 목록 값은 끝에 쉼표를 붙여 넘긴다. `harness set` 은 쉼표가 있을 때만 배열로 쓴다 —
// 항목이 하나면 문자열로 바뀌어 버린다.
export async function setValue(project, key, value, isList) {
  const { path } = await getProject(project);
  const v = isList ? value.split(",").map((s) => s.trim()).filter(Boolean).join(",") + "," : String(value);
  const r = await harness(path, ["set", key, v]);
  revalidatePath(`/${project}`, "layout");
  return r;
}

// 단계 목록을 통째로 넘긴다. 검증·되돌림·렌더는 `harness steps` 가 한다.
// title 이 있으면 새 절차다 — 제목과 단계를 한 번에 넘겨 설정에 한 번에 들어간다(성립하지 않으면 CLI 가 되돌린다)
export async function saveSteps(project, workflow, steps, title) {
  const { path } = await getProject(project);
  const clean = steps.map(({ builtin, body, ...s }) => s);
  const r = await harness(path, ["steps", workflow, JSON.stringify(title ? { title, steps: clean } : clean)]);
  revalidatePath(`/${project}/workflow`);
  return r;
}

// 쓰지 않고 검사만 한다. 편집 중인 캔버스가 노드에 오류를 붙이는 근거다.
export async function checkSteps(project, workflow, steps, title) {
  const { path } = await getProject(project);
  const clean = steps.map(({ builtin, body, ...s }) => s);
  return harness(path, ["steps", workflow, JSON.stringify(title ? { title, steps: clean } : clean), "--dry-run"]);
}

export async function render(project) {
  const { path } = await getProject(project);
  return harness(path, ["render"]);
}

// 정적 검사 → 통과한 항목만 저렴한 모델에 묻는다. 결과는 { 항목: 오류코드 }.
export async function checkFields(project, doc, values) {
  const { path } = await getProject(project);
  const fields = fieldsOf(doc);
  const errors = staticCheck(values, fields);
  // "없음"·"모름"·빈 고급 항목은 판정할 내용이 없다
  const rest = fields.filter((f) => !errors[f.k] && answered(values[f.k]));
  if (!rest.length) return errors;

  const cfg = await readConfig(path);
  const items = rest.map((f) => `- ${f.k} (${f.label}): ${asText(values[f.k])}`).join("\n");
  const prompt =
    `소프트웨어 프로젝트 문서 "${DOCS[doc].title}" 의 입력 항목이다. 각 값이 그 질문에 대한 ` +
    `프로젝트 관련 답으로 읽히면 "ok", 무의미한 문자열·질문과 무관한 내용이면 "meaningless" 로 판정한다. ` +
    `"없음" 은 유효한 답이다. 파일을 읽지 말고 JSON 객체 하나만 출력한다. 키는 항목 이름이다.\n\n${items}`;
  try {
    const verdict = parseVerdict(await ask(path, cfg.harness.orchestrator, prompt, { cheap: true }), rest.map((f) => f.k));
    if (!verdict) return { ...errors, _: "E_CHECK_FAILED" };
    return { ...errors, ...verdict };
  } catch {
    return { ...errors, _: "E_CHECK_FAILED" };
  }
}

// 검사를 통과해야만 완성을 부른다. 빈 입력으로 문서를 지어내게 두지 않는다.
export async function completeDoc(project, doc, values) {
  const errors = await checkFields(project, doc, values);
  if (Object.keys(errors).length) return { errors };

  const { path } = await getProject(project);
  const cfg = await readConfig(path);
  const [template, current] = await Promise.all([readDocTemplate(path, doc), readDoc(path, doc)]);
  const items = fieldsOf(doc).map((f) => `- ${f.label}: ${asText(values[f.k]) || UNKNOWN}`).join("\n");
  const prompt = [
    `이 리포의 .ai/project/${doc}.md 를 완성한다. 에이전트가 근거로 읽는 문서다.`,
    "규칙:",
    "- 원형의 맨 위 HTML 주석을 그대로 두고, 장 제목과 표 구조를 유지한다.",
    "- `<!-- TBD ... -->` 자리를 사용자 입력과 리포에서 확인한 사실로 채운다.",
    "- 입력에도 리포에도 없는 사실은 지어내지 않는다. 모르면 그 자리를 TBD 로 남긴다.",
    `- 입력이 "${UNKNOWN}" 인 항목은 리포에서 확인해 채우고, 확인하지 못하면 TBD 로 남긴다.`,
    "- 원형에 자리가 없는 입력은 알맞은 장을 새로 만들어 넣는다. 목록 입력(\" / \" 로 이음)은 목록으로 쓴다.",
    "- 한국어 개조체로 짧게 쓴다.",
    "- 설명 없이 완성된 마크다운 파일 본문만 출력한다. 코드 펜스로 감싸지 않는다.",
    "", "## 사용자 입력", items,
    "", "## 원형", template,
    "", "## 현재 파일", current || "(없음)",
  ].join("\n");
  try {
    const text = (await ask(path, cfg.harness.orchestrator, prompt)).replace(/^```\w*\n([\s\S]*)\n```$/, "$1");
    return { text };
  } catch (e) {
    return { errors: { _: "E_CHECK_FAILED" }, detail: String(e.message).slice(0, 500) };
  }
}

// 저장 뒤 render — 규칙 문서가 이 본문을 담고 있어, 빠뜨리면 `harness check` 가 커밋을 막는다.
export async function saveDoc(project, doc, text) {
  const { path } = await getProject(project);
  await writeDoc(path, doc, text);
  const r = await harness(path, ["render"]);
  revalidatePath(`/${project}/project`, "layout");
  return r;
}

// 저장 전 마크다운 검사. 정적 검사로 확실한 것을 먼저 잡고, 나머지는 md-check 스킬을 저렴한 모델로 돌린다.
// 결과는 { issues, failed } — 모델을 부르지 못해도 정적 결과는 돌려주고, 저장을 막을지는 사람이 정한다.
export async function checkMarkdown(project, text) {
  const { path } = await getProject(project);
  const found = staticIssues(text);
  if (!text.trim()) return { issues: found, failed: false };
  try {
    const skill = (await fs.readFile("skills/md-check/SKILL.md", "utf8")).replace(/^---[\s\S]*?---\n/, "");
    const cfg = await readConfig(path);
    const out = await ask(path, cfg.harness.orchestrator, `${skill}\n\n## 검사할 문서\n\n${numbered(text)}`, { cheap: true });
    const issues = parseIssues(out);
    if (!issues) return { issues: found, failed: true };
    const seen = new Set(found.map((x) => `${x.line}:${x.type}`));
    return { issues: [...found, ...issues.filter((x) => !seen.has(`${x.line}:${x.type}`))].sort((a, b) => a.line - b.line), failed: false };
  } catch {
    return { issues: found, failed: true };
  }
}

// 설치된 도구를 다시 찾는다. 결과는 기기 단위 기록에 남고, 드롭다운은 그것을 읽는다.
export async function syncTools(project) {
  const t = await readTools(true);
  revalidatePath(`/${project}`, "layout");
  return t ? { ok: true, out: `synced ${t.synced_at}` } : { ok: false, out: "harness tools --sync failed" };
}

// 역할의 추가 지시를 저장하고 render — 에이전트 정의가 이 본문을 담는다. 역할과 경로는 schema 가 아는 것만 받는다.
const NOTES_HEAD = "<!--\n이 파일은 프로젝트가 소유한다. 하네스 갱신이 덮지 않는다.\n`harness render` 가 이 본문을 이 역할의 에이전트 정의 끝(\"이 프로젝트에서\")에 붙인다.\n-->\n\n";
export async function saveRoleNotes(project, role, text) {
  const { path } = await getProject(project);
  const schema = await readSchema(path);
  const r = schema?.roles?.[role];
  if (!r) return { ok: false, out: `unknown role: ${role}` };
  const body = text.trim() ? (text.trimStart().startsWith("<!--") ? text : NOTES_HEAD + text) : "";
  await writeRoleNotes(path, r.notes, body);
  const out = await harness(path, ["render"]);
  revalidatePath(`/${project}/agents`);
  return out;
}

// 절차 끝에 붙는 이 프로젝트의 지시. 절차 이름과 경로는 schema 가 아는 것만 받는다.
const WF_HEAD = "<!--\n이 파일은 프로젝트가 소유한다. 하네스 갱신이 덮지 않는다.\n`harness render` 가 이 본문을 이 절차 끝(\"이 프로젝트에서\")에 붙인다.\n-->\n\n";
export async function saveWorkflowNotes(project, wf, text) {
  const { path } = await getProject(project);
  const rel = (await readSchema(path))?.workflow_notes?.[wf];
  if (!rel) return { ok: false, out: `unknown workflow: ${wf}` };
  const body = text.trim() ? (text.trimStart().startsWith("<!--") ? text : WF_HEAD + text) : "";
  await writeRoleNotes(path, rel, body);
  const out = await harness(path, ["render"]);
  revalidatePath(`/${project}/workflow`);
  return out;
}

// 새 프로젝트: 디렉터리를 만들고(필요하면 git init) `harness install` 로 설치·등록한다.
// 로컬 파일을 쓰는 동작이라 경로를 좁힌다 — 절대 경로, 홈 디렉터리 안쪽, 하네스 등록부 밖.
// 등록부는 이름(디렉터리 이름)이 키라, 같은 이름의 다른 프로젝트가 있으면 덮지 않고 거부한다.
export async function createProject(dir, gitInit) {
  const home = os.homedir();
  if (!dir || !nodePath.isAbsolute(dir)) return { ok: false, out: "절대 경로를 적는다 (예: /Users/me/work/my-app)" };
  const target = nodePath.resolve(dir);
  if (target !== dir.replace(/\/+$/, "")) return { ok: false, out: "경로에 . 이나 .. 을 쓰지 않는다" };
  if (!target.startsWith(home + nodePath.sep) || target === home) return { ok: false, out: `홈 디렉터리(${home}) 안의 디렉터리만 만든다` };
  if (target === HOME || target.startsWith(HOME + nodePath.sep)) return { ok: false, out: "하네스 등록부 안에는 만들지 않는다" };
  const name = nodePath.basename(target);
  const taken = (await listProjects()).find((p) => p.name === name && p.path && p.path !== target);
  if (taken) return { ok: false, out: `같은 이름의 프로젝트가 이미 등록돼 있다: ${taken.path}\n디렉터리 이름을 바꿔 만든다` };
  await fs.mkdir(target, { recursive: true });
  if (gitInit) {
    try { await fs.access(nodePath.join(target, ".git")); }
    catch { await promisify(execFile)("git", ["init", "-q"], { cwd: target }); }
  }
  const r = await harness(target, ["install"]);
  revalidatePath("/");
  return { ...r, name: r.ok ? name : undefined };
}

// 새 프로젝트 디렉터리를 macOS 폴더 선택 창으로 고른다. 창에서 새 폴더도 만들 수 있다.
// 브라우저는 절대 경로를 주지 않아 서버(같은 컴퓨터)가 창을 띄운다 — UI 가 127.0.0.1 에서만 뜨기에 성립한다.
export async function pickDirectory() {
  if (process.platform !== "darwin") return { ok: false, out: "폴더 선택 창은 macOS 에서만 열립니다. 경로를 직접 적어 주세요." };
  try {
    const { stdout } = await promisify(execFile)("osascript", [
      "-e", "activate",
      "-e", 'POSIX path of (choose folder with prompt "프로젝트 폴더를 고르거나, 새 폴더를 만들어 고르세요" default location (path to home folder))',
    ]);
    return { ok: true, path: stdout.trim().replace(/\/+$/, "") };
  } catch (e) {
    // -128 = 사용자가 취소
    return /-128/.test(String(e.stderr || e.message)) ? { ok: false, cancel: true } : { ok: false, out: "폴더 선택 창을 열지 못했습니다. 경로를 직접 적어 주세요." };
  }
}

// 여러 값을 한꺼번에 바꾼다. 두 값에 걸친 불변식(구현·리뷰 러너 분리)은 하나씩 바꾸면 중간에서 막힌다.
export async function setValues(project, pairs) {
  const { path } = await getProject(project);
  const r = await harness(path, ["set", ...pairs.flat().map(String)]);
  revalidatePath(`/${project}`, "layout");
  return r;
}

// 홈 카드가 뒤이어 채우는 상태. 이름은 등록부에 있는 것만 받는다.
export async function projectStatus(project) {
  const { path } = await getProject(project);
  return readStatus(path);
}

// 손으로 쓴 옛 검증 스크립트가 있는가 — 있으면 run-lint-test.sh 가 그것을 돈다(CLI 의 legacy_verify 와 같은 기준)
async function legacyVerify(dir) {
  try { return !(await fs.readFile(nodePath.join(dir, "script/verify-project.sh"), "utf8")).includes("verify-project: not filled in yet"); }
  catch { return false; }
}

// 명령 탭의 ▷ — 적은 명령이 이 리포에서 실제로 도는지 저장 전에 돌려 본다.
// 사람이 이 컴퓨터에서 직접 적은 명령을 그 리포에서 돌린다 — 터미널에서 치는 것과 같은 권한이다(UI 는 127.0.0.1 에서만 뜬다).
export async function runCommand(project, cmd) {
  const { path } = await getProject(project);
  if (typeof cmd !== "string" || !cmd.trim() || cmd.includes("\n")) return { ok: false, out: "한 줄짜리 명령만 돌립니다." };
  const t0 = Date.now();
  try {
    const { stdout, stderr } = await promisify(execFile)("bash", ["-c", cmd], { cwd: path, timeout: 600000, maxBuffer: 16 << 20 });
    return { ok: true, code: 0, ms: Date.now() - t0, out: (stdout + stderr).trim().slice(-4000) };
  } catch (e) {
    const out = `${e.stdout || ""}${e.stderr || ""}`.trim() || String(e.message);
    return { ok: false, code: e.killed ? "timeout" : e.code, ms: Date.now() - t0, out: out.slice(-4000) };
  }
}

// 명령과 검증 검사를 저장한다. 명령은 set 한 번(한 번에 검증), 검사는 checks 한 번 — 바뀐 것만 부른다.
export async function saveCommands(project, commands, checks, before) {
  const { path } = await getProject(project);
  const pairs = Object.entries(commands).filter(([k, v]) => v !== before.commands[k]).map(([k, v]) => [`commands.${k}`, v.trim()]);
  const out = [];
  if (pairs.length) {
    const r = await harness(path, ["set", ...pairs.flat()]);
    if (!r.ok) return r;
    out.push(r.out);
  }
  const clean = checks.map((c) => ({ name: c.name.trim(), run: c.run.trim() })).filter((c) => c.name || c.run);
  if (JSON.stringify(clean) !== JSON.stringify(before.checks)) {
    const r = await harness(path, ["checks", JSON.stringify(clean)]);
    if (!r.ok) return r;
    out.push(r.out);
  }
  revalidatePath(`/${project}`, "layout");
  return { ok: true, out: out.join("\n") || "바뀐 것이 없습니다." };
}

// Don't know — 리포를 읽고 명령을 제안받는다. 저장하지 않는다: 사람이 ▷ 로 돌려 본 뒤 저장한다.
export async function suggestCommands(project) {
  const { path } = await getProject(project);
  const cfg = await readConfig(path);
  const prompt = [
    "이 리포의 빌드·테스트·코드 검사 명령을 찾는다. package.json·Makefile·pyproject.toml·build.gradle 같은 파일과 README 에서 **실제로 있는** 명령만 고른다.",
    "없는 명령은 지어내지 말고 빈 문자열로 둔다. 설명 없이 JSON 객체 하나만 출력한다.",
    '키: build(빌드), test(테스트 전체), test_single(파일 하나만 테스트, 파일 자리는 {file}), format_check(코드 모양 검사, 고치지 않음), format_fix(자동 수정)',
  ].join("\n");
  try {
    const m = (await ask(path, cfg.harness.orchestrator, prompt, { cheap: true })).match(/\{[\s\S]*\}/);
    const obj = m ? JSON.parse(m[0]) : null;
    if (!obj) return { ok: false, out: "AI 가 명령을 찾지 못했습니다. 직접 적어 주세요." };
    return { ok: true, commands: Object.fromEntries(Object.entries(obj).filter(([, v]) => typeof v === "string" && !v.includes("\n"))) };
  } catch {
    return { ok: false, out: "AI 에 묻지 못했습니다. 잠시 뒤 다시 시도해 주세요." };
  }
}

// Metrics 탭 — 새 대화 기록을 먼저 가져오고(import) 기간의 집계를 받는다. trace 를 주면 그 실행의 스팬 트리도.
// 옛 하네스 사본은 metrics 명령이 없다 — unsupported 로 알린다.
export async function metricsData(project, range, trace) {
  const { path } = await getProject(project);
  if (!/^\d+[hd]$/.test(range)) return { error: "bad range" };
  const r = await harness(path, ["metrics", "import", "--since", range, ...(trace && /^t-[\w-]+$/.test(trace) ? ["--trace", trace] : [])]);
  if (!r.ok) return /invalid choice: 'metrics'/.test(r.out) ? { unsupported: true } : { error: r.out.slice(-1000) };
  try { return JSON.parse(r.out); } catch { return { error: "지표를 읽지 못했습니다." }; }
}

// Doctor 화면의 ▷ 실행. 정해 둔 조치만 받는다 — 화면에서 임의 명령을 넘기지 못한다.
export async function doctorFix(project, kind) {
  const { path } = await getProject(project);
  const run = async (cmd, args) => {
    try {
      const { stdout, stderr } = await promisify(execFile)(cmd, args, { cwd: path, timeout: 300000, maxBuffer: 8 << 20 });
      return { ok: true, out: (stdout + stderr).trim() };
    } catch (e) {
      return { ok: false, out: `${e.stdout || ""}${e.stderr || ""}`.trim() || String(e.message) };
    }
  };
  let r;
  if (kind === "hooks") r = await run("git", ["config", "core.hooksPath", "script/githooks"]);
  else if (kind === "verify") r = await run("bash", [(await legacyVerify(path)) ? "script/verify-project.sh" : "script/harness-verify.sh"]);
  else if (kind === "render") r = await harness(path, ["render"]);
  else if (kind === "upgrade") r = await harness(path, ["install"]);
  else return { ok: false, out: `unknown fix: ${kind}` };
  revalidatePath("/");
  return { ...r, out: (r.out || "").slice(-4000) };   // 긴 테스트 출력은 끝부분만
}

// 생성물이 설정과 어긋났을 때 홈에서 바로 맞춘다
export async function renderProject(project) {
  const { path } = await getProject(project);
  const r = await harness(path, ["render"]);
  revalidatePath("/");
  return r;
}

// 고정된 하네스를 전역 버전으로 올린다 — 설정과 소유 파일은 그대로 두고 사본만 갈아 끼운다
export async function upgradeProject(project) {
  const { path } = await getProject(project);
  const r = await harness(path, ["install"]);
  revalidatePath("/");
  return r;
}

// 이 프로젝트가 만든 절차의 이름 변경·삭제. 하네스 기본 절차는 CLI 가 거부한다.
export async function renameWorkflow(project, wf, name) {
  const { path } = await getProject(project);
  const r = await harness(path, ["steps", wf, "--rename", name]);
  revalidatePath(`/${project}/workflow`);
  return r;
}
export async function deleteWorkflow(project, wf) {
  const { path } = await getProject(project);
  const r = await harness(path, ["steps", wf, "--delete"]);
  revalidatePath(`/${project}/workflow`);
  return r;
}
