// 서버 전용. 파일을 읽고 하네스 CLI 를 부른다 — 설정을 고치는 로직을 여기서 다시 만들지 않는다.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { STATUS_TIMEOUT_MS, remoteStatusTimeoutMs } from "./doctor.js";

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
    try { p = registeredPath(JSON.parse(await fs.readFile(path.join(HOME, name, "project.json"), "utf8"))); } catch {}
    const ok = p !== null && (await exists(path.join(p, "harness.toml")));
    out.push({ name, path: p, ok });
  }
  return out;
}

// 등록 JSON 의 경로. 비어 있지 않은 문자열만 경로로 보고, 나머지는 경로 없음(null)이다.
export function registeredPath(data) {
  const p = data && typeof data === "object" && !Array.isArray(data) ? data.path : null;
  return typeof p === "string" && p !== "" ? p : null;
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

// 쓰기는 전부 CLI 로 간다. `set` · `write-doc` 이 검증·되돌림·렌더를 이미 한다.
// timeout 은 그 명령이 끝나기를 기다리는 최대 시간(ms)이다. 넘기면 결과 없이 실패로 돌려준다.
// input 이 있으면 자식 프로세스의 표준 입력으로 넘긴다(`write-doc <이름> -` 의 본문).
export async function harness(dir, args, { timeout = STATUS_TIMEOUT_MS, input } = {}) {
  try {
    const { stdout, stderr } = await runWithInput(BIN, [...args, "--target", dir], { timeout, input });
    return { ok: true, out: (stdout + stderr).trim() };
  } catch (e) {
    return { ok: false, out: ((e.stdout || "") + (e.stderr || "") || e.message).trim() };
  }
}

function runWithInput(cmd, args, { timeout, input }) {
  return new Promise((resolve, reject) => {
    const child = execFile(cmd, args, { timeout, maxBuffer: 8 << 20 }, (err, stdout, stderr) =>
      err ? reject(Object.assign(err, { stdout, stderr })) : resolve({ stdout, stderr }));
    child.stdin?.on("error", () => {});   // 입력을 다 읽기 전에 끝난 명령 — 결과는 콜백이 알린다
    child.stdin?.end(input ?? "");
  });
}

// 기본값을 채운 단계 목록. 설정에 절차가 없을 때의 기본값은 CLI 만 안다 — 여기서 다시 풀지 않는다.
export async function readSteps(dir) {
  const r = await harness(dir, ["steps"]);
  if (!r.ok) throw new Error(r.out);
  return JSON.parse(r.out);
}

// 생성된 절차 문서. 경로는 schema 가 준 것만 쓴다 — 디렉터리를 나열하지 않는다.
export async function listWorkflows(dir, schema) {
  return Promise.all(Object.entries(schema?.workflows ?? {}).filter(([, w]) => w.path).map(async ([name, w]) => ({
    name, text: await readText(dir, w.path),
  })));
}

// 프로젝트 문서. schema 에 없는 문서(옛 사본·모르는 이름)는 빈 문자열이다.
export async function readDoc(dir, schema, doc) {
  const rel = schema?.docs?.[doc]?.path;
  return rel ? readText(dir, rel) : "";
}

// 원형은 그 프로젝트의 schema 를 답한 하네스의 것이다 — 그 프로젝트가 따르는 양식이다.
export async function readDocTemplate(dir, schema, doc) {
  const f = schema?.docs?.[doc]?.template;
  if (!f) return "";
  try { return await fs.readFile(path.isAbsolute(f) ? f : path.join(dir, f), "utf8"); } catch { return ""; }
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

export async function readText(dir, rel) {
  try { return await fs.readFile(path.join(dir, rel), "utf8"); } catch { return ""; }
}

// 홈 화면용 프로젝트 상태. 프로젝트에 고정된 하네스가 답하므로 옛 버전이면 null 이다.
// remote 면 원격 준비 점검까지 한다 — `--remote` 를 모르는 옛 버전도 null 이다.
// 원격 점검은 원격이 응답하지 않을 때 걸리는 최악 누적 시간보다 길게 기다린다 — 그래야 확인하지 못한 줄을 받는다.
export async function readStatus(dir, remote = false) {
  let opts = {};
  if (remote) {
    let cfg = null;
    try { cfg = await readConfig(dir); } catch {}
    opts = { timeout: remoteStatusTimeoutMs(cfg) };
  }
  const r = await harness(dir, remote ? ["status", "--remote"] : ["status"], opts);
  if (!r.ok) return null;
  try { return JSON.parse(r.out); } catch { return null; }
}

// 전역 하네스 버전 — 프로젝트에 고정된 버전과 비교해 업데이트할 수 있는지 본다
export async function globalVersion() {
  const r = await harness(HOME, ["version"]);
  return r.out.match(/^harness (\S+)/m)?.[1] ?? "";
}
