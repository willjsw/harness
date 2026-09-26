// 서버 전용. 파일을 읽고 하네스 CLI 를 부른다 — 설정을 고치는 로직을 여기서 다시 만들지 않는다.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { DOCS } from "./fields.js";

const run = promisify(execFile);
export const HOME = process.env.HARNESS_HOME || path.join(os.homedir(), ".harness");
const BIN = process.env.HARNESS_BIN || "harness";

// `~/.harness/<이름>/project.json` 이 설치 목록이다. `harness install` 이 쓴다.
// 경로가 없는 디렉터리(등록부 도입 전 설치)는 목록에 남기되 다시 설치하라고 알린다.
export async function listProjects() {
  let names = [];
  // 등록부에는 기기 단위 기록(tools.json)도 있다 — 프로젝트는 디렉터리만이다
  try { names = (await fs.readdir(HOME, { withFileTypes: true })).filter((d) => d.isDirectory()).map((d) => d.name); } catch { return []; }
  const out = [];
  for (const name of names.sort()) {
    if (name.startsWith(".")) continue;
    let p = null;
    try { p = JSON.parse(await fs.readFile(path.join(HOME, name, "project.json"), "utf8")).path; } catch {}
    const ok = !!p && (await exists(path.join(p, "harness.toml")));
    out.push({ name, path: p, ok });
  }
  return out;
}

export async function getProject(name) {
  const p = (await listProjects()).find((x) => x.name === name);
  if (!p?.ok) throw new Error(`unknown project: ${name}`);
  return p;
}

async function exists(f) {
  try { await fs.access(f); return true; } catch { return false; }
}

// TOML 파서를 들이지 않는다. 하네스가 이미 요구하는 python3 의 tomllib 로 읽는다.
export async function readConfig(dir) {
  const { stdout } = await run("python3", ["-c",
    "import tomllib,json,sys;print(json.dumps(tomllib.load(open(sys.argv[1],'rb'))))",
    path.join(dir, "harness.toml")]);
  return JSON.parse(stdout);
}

// 쓰기는 전부 CLI 로 간다. `set` 이 검증·되돌림·렌더를 이미 한다.
export async function harness(dir, args) {
  try {
    const { stdout, stderr } = await run(BIN, [...args, "--target", dir], { timeout: 60_000 });
    return { ok: true, out: (stdout + stderr).trim() };
  } catch (e) {
    return { ok: false, out: ((e.stdout || "") + (e.stderr || "") || e.message).trim() };
  }
}

// 기본값을 채운 단계 목록. 설정에 절차가 없을 때의 기본값은 CLI 만 안다 — 여기서 다시 풀지 않는다.
export async function readSteps(dir) {
  const r = await harness(dir, ["steps"]);
  if (!r.ok) throw new Error(r.out);
  return JSON.parse(r.out);
}

export async function listWorkflows(dir) {
  const d = path.join(dir, ".ai", "workflows");
  let files = [];
  try { files = (await fs.readdir(d)).filter((f) => f.endsWith(".md")).sort(); } catch {}
  return Promise.all(files.map(async (f) => ({
    name: f.slice(0, -3),
    text: await fs.readFile(path.join(d, f), "utf8"),
  })));
}

export function docPath(dir, doc) {
  if (!(doc in DOCS)) throw new Error(`unknown doc: ${doc}`);   // 경로를 입력에서 만들지 않는다
  return path.join(dir, ".ai", "project", `${doc}.md`);
}

export async function readDoc(dir, doc) {
  try { return await fs.readFile(docPath(dir, doc), "utf8"); } catch { return ""; }
}

// 원형은 프로젝트에 고정된 하네스 사본의 것을 쓴다 — 그 프로젝트가 따르는 양식이다.
export async function readDocTemplate(dir, doc) {
  const f = path.join(dir, ".harness", "templates", "owned", ".ai", "project", `${doc}.md`);
  try { return await fs.readFile(f, "utf8"); } catch { return ""; }
}

export async function writeDoc(dir, doc, text) {
  await fs.writeFile(docPath(dir, doc), text.endsWith("\n") ? text : text + "\n", "utf8");
}

// 오케스트레이터 CLI 로 한 번 묻는다. API 키를 따로 두지 않는다 — 사용자가 이미 로그인한 CLI 다.
// cwd 가 프로젝트라 모델이 리포를 읽을 수 있다. 쓰기 도구는 주지 않는다.
export async function ask(dir, orchestrator, prompt, { cheap = false } = {}) {
  const [cmd, args] = orchestrator === "codex"
    // ponytail: codex 는 저렴한 모델 이름을 고정하지 않는다. 기본 모델로 검사한다
    ? ["codex", ["exec", "--sandbox", "read-only", prompt]]
    : ["claude", ["-p", prompt, "--allowedTools", "Read,Grep,Glob",
        ...(cheap ? ["--model", "haiku"] : [])]];
  const { stdout } = await run(cmd, args, { cwd: dir, timeout: 300_000, maxBuffer: 8 << 20 });
  return stdout.trim();
}

// 설정 파일의 주석이 곧 스키마 문서다. 키 바로 위의 주석 줄을 그 키의 설명으로 쓴다.
export async function readConfigNotes(dir) {
  const lines = (await fs.readFile(path.join(dir, "harness.toml"), "utf8")).split("\n");
  const notes = {};
  let section = "", buf = [];
  for (const ln of lines) {
    const s = ln.trim();
    const sec = s.match(/^\[([^\]]+)\]$/);
    if (sec) { section = sec[1]; buf = []; continue; }
    if (s.startsWith("#")) { const t = s.replace(/^#\s?/, ""); if (!/^─+$/.test(t)) buf.push(t); continue; }
    const kv = s.match(/^([\w-]+)\s*=/);
    if (kv && buf.length) notes[`${section}.${kv[1]}`] = buf.join("\n").trim();
    if (s === "" || kv) buf = [];
  }
  return notes;
}

// 이 기기의 에이전트 CLI·결정 기록 도구. 기록(`~/.harness/tools.json`)을 읽고, sync 면 다시 찾는다.
export async function readTools(sync = false) {
  const r = await harness(HOME, ["tools", ...(sync ? ["--sync"] : [])]);
  if (!r.ok) return null;
  try { return JSON.parse(r.out); } catch { return null; }
}

// 에이전트 등록부와 역할별 실제 실행 주체. 프로젝트에 고정된 하네스가 낸다 — 버전마다 고를 수 있는 값이 다를 수 있다.
export async function readSchema(dir) {
  const r = await harness(dir, ["schema"]);
  if (!r.ok) return null;
  try { return JSON.parse(r.out); } catch { return null; }
}

// 역할 하나의 계약(관리 파일)과 이 프로젝트가 더한 지시(소유 파일). 경로는 schema 가 준 것만 쓴다.
export async function readRoleFiles(dir, role) {
  const read = async (rel) => { try { return await fs.readFile(path.join(dir, rel), "utf8"); } catch { return ""; } };
  return { contract: await read(role.contract), notes: await read(role.notes) };
}

export async function writeRoleNotes(dir, rel, text) {
  const f = path.join(dir, rel);
  await fs.mkdir(path.dirname(f), { recursive: true });
  await fs.writeFile(f, text.endsWith("\n") ? text : text + "\n", "utf8");
}

export async function readText(dir, rel) {
  try { return await fs.readFile(path.join(dir, rel), "utf8"); } catch { return ""; }
}

// 홈 화면용 프로젝트 상태. 프로젝트에 고정된 하네스가 답하므로 옛 버전이면 null 이다.
export async function readStatus(dir) {
  const r = await harness(dir, ["status"]);
  if (!r.ok) return null;
  try { return JSON.parse(r.out); } catch { return null; }
}

// 전역 하네스 버전 — 프로젝트에 고정된 버전과 비교해 업데이트할 수 있는지 본다
export async function globalVersion() {
  const r = await harness(HOME, ["version"]);
  return r.out.match(/^harness (\S+)/m)?.[1] ?? "";
}
