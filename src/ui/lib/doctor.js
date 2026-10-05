// `harness status` 의 doctor 줄 → 사람이 읽는 한 항목. CLI 의 영어 문구를 그대로 보이지 않는다.
// 모르는 줄은 원문을 그대로 둔다 — 새 검사가 생겨도 사라지지 않게.
import { DOCS } from "./fields.js";

export const SECTIONS = {
  config: "설정",
  "generated files": "생성 파일",
  "managed files": "관리 파일",
  "project facts": "프로젝트 문서",
  verification: "검증",
  references: "문서 참조",
  "tools and connections": "도구와 연결",
  registry: "등록",
  git: "git",
  remote: "원격",
};

// `status --remote` 에 줄 실행 제한(ms). 원격 점검은 호출을 순차로 하고 호출 하나를 설정의
// doctor.remote_timeout(초)에 끊는다 — 원격이 모두 응답하지 않으면 호출 수 × 그 제한이 걸린 뒤에야
// 확인하지 못한 줄을 낸다. 호출 수의 상한은 ls-remote 1 · forge 로그인 최대 2(트래커 · 리뷰 호스트) ·
// 라벨 1 · 보호 브랜치마다 1 · 리뷰어 러너 1 이다. 리뷰어 러너 호출은 실행기가 로그인 확인을 시작했다고
// 알리기까지 그 제한 하나, 알린 뒤로 그 제한의 RUNNER_CHECK_AFTER_START 배를 기다린다. 로컬 점검 몫으로 기본 제한을 더한다.
export const STATUS_TIMEOUT_MS = 60_000;
// doctor.remote_timeout 의 기본값과 상한(초). CLI 의 DOCTOR_DEFAULTS · REMOTE_TIMEOUT_LIMIT 과 같다
export const REMOTE_TIMEOUT_DEFAULT = 30;
export const REMOTE_TIMEOUT_LIMIT = 600;
// 리뷰어 러너 호출이 로그인 확인 시작 알림 뒤로 기다리는 호출 제한의 배수. CLI 의 RUNNER_CHECK_AFTER_START 와 같다
export const RUNNER_CHECK_AFTER_START = 2;

// 설정의 호출 하나 제한(ms). 없거나 CLI 가 받지 않을 값이면 기본값 — 그때 CLI 는 설정 검증에서 멈춘다
export function remoteCallTimeoutMs(cfg) {
  const n = cfg?.doctor?.remote_timeout;
  const ok = Number.isInteger(n) && n >= 1 && n <= REMOTE_TIMEOUT_LIMIT;
  return (ok ? n : REMOTE_TIMEOUT_DEFAULT) * 1000;
}

// 설정을 읽지 못했으면 보호 브랜치 없이 센다 — 그때는 CLI 도 설정에서 멈춰 원격에 닿지 않는다
export function remoteCallLimit(cfg) {
  const prot = cfg?.branches?.protected;
  const branches = new Set(Array.isArray(prot) ? prot : []).size;
  return 1 + 2 + 1 + branches + 1;
}

export function remoteStatusTimeoutMs(cfg) {
  return STATUS_TIMEOUT_MS + (remoteCallLimit(cfg) + RUNNER_CHECK_AFTER_START) * remoteCallTimeoutMs(cfg);
}

// 원격 절의 줄. 확인하지 못한 줄은 항목마다 다르지 않다 — 다시 점검하는 것 말고는 할 일이 없다
function explainRemote(i, base) {
  const w = i.what, d = i.detail || "";
  let m;
  if (d.startsWith("could not check"))
    return { title: `확인하지 못했습니다: ${w}`, body: "네트워크·forge 응답·제한 시간 때문에 이 항목을 확인하지 못했습니다. 원격까지 점검 으로 다시 돌립니다." };
  if (w === "remote `origin`" && d === "not a git repository")
    return { title: "git 리포가 아니어서 원격을 점검할 수 없습니다", body: "이 디렉터리는 git 리포가 아닙니다. origin 과 브랜치는 git 리포에서만 점검합니다." };
  if (w === "remote `origin`" && d.startsWith("not set"))
    return { title: "origin 이 설정되어 있지 않습니다", body: "origin 이 없으면 /work 가 원격을 가져오지 못하고 멈춥니다.", cmd: "git remote add origin <url>" };
  if ((m = w.match(/^branch `(.+)` on origin$/)) && d.startsWith("missing"))
    return { title: `통합 브랜치 ${m[1]} 가 원격에 없습니다`, body: "착수 판정과 리뷰 요청이 원격의 통합 브랜치를 기준으로 하므로 실패합니다.", cmd: `git push origin ${m[1]}` };
  if (w === "origin default branch" && (m = d.match(/^is `([^`]+)`/)))
    return { title: `원격 기본 브랜치(${m[1]})가 통합 브랜치와 다릅니다`,
      body: "새 클론과 리뷰 요청이 그 브랜치에서 시작합니다. forge 에서 기본 브랜치를 바꾸거나 Harness 탭에서 branches.base 를 고칩니다.",
      href: `${base}/settings` };
  if ((m = w.match(/^sign-in to `(.+)`$/)) && d.startsWith("not signed in")) {
    const hint = d.replace(/^not signed in(?: — )?/, "");
    const cmd = d.match(/`([^`]+)`/)?.[1];
    return { title: `${m[1]} CLI 에 로그인되어 있지 않습니다`, body: `이슈·리뷰 요청 명령이 실패합니다.${hint ? ` 안내: ${hint}` : ""}`, ...(cmd ? { cmd } : {}) };
  }
  if ((m = w.match(/^label `(.+)`$/)) && d.startsWith("missing"))
    return { title: `라벨 ${m[1]} 이 트래커에 없습니다`, body: "그 라벨을 붙이는 이슈 생성이 실패할 수 있습니다. forge 에서 라벨을 만듭니다." };
  if ((m = w.match(/^branch protection `(.+)`$/)) && d.startsWith("not protected"))
    return { title: `${m[1]} 브랜치가 원격에서 보호되지 않습니다`, body: "원격에서 그 브랜치로의 직접 push 를 로컬 훅만 막고 있습니다. forge 의 브랜치 보호를 켭니다." };
  if ((m = w.match(/^reviewer runner `(.+)`$/)) && i.state === "bad")
    return { title: `리뷰어 러너(${m[1]})를 띄울 수 없습니다`, body: `리뷰 루프가 리뷰어를 띄우지 못합니다. ${d}`, href: `${base}/agents` };
  return null;
}

// 관리 파일 절의 줄. 고정 사본(.harness/)은 render 가 되돌리지 않으므로 다시 설치한다
function explainManaged(i) {
  const w = i.what, d = i.detail || "";
  const render = { kind: "render", cmd: "harness render" };
  let m;
  if (w === "modified managed file" || w === "missing managed file") {
    const gone = w === "missing managed file";
    if (d.startsWith(".harness/"))
      return { title: gone ? "고정된 하네스 사본의 파일이 없어졌습니다" : "고정된 하네스 사본이 설치 뒤 바뀌었습니다",
        body: `${d} 는 이 프로젝트에 고정한 하네스의 일부입니다. 사본이 바뀌면 검사도 바뀐 기준으로 돕니다. 다시 설치해 되돌립니다.`,
        cmd: "harness install" };
    return gone
      ? { title: "하네스 파일이 없어졌습니다", body: `${d} 가 설치 뒤 사라졌습니다. 다시 생성해 되돌립니다.`, run: render }
      : { title: "하네스 파일이 설치 뒤 바뀌었습니다",
        body: `${d} 는 하네스가 관리하는 파일이라 다음 render 가 덮습니다. 프로젝트 스크립트라면 script/project/ 로 옮깁니다.`,
        run: render };
  }
  if ((m = w.match(/^(\d+) more modified or missing managed file\(s\)$/)))
    return { title: `바뀌거나 없어진 하네스 파일이 ${m[1]}개 더 있습니다`, body: "다시 생성하면 하네스 파일이 설치한 내용으로 돌아옵니다.", run: render };
  if ((m = w.match(/^(\d+) managed files have no recorded hash$/)))
    return { title: "하네스 파일의 해시가 기록되어 있지 않습니다",
      body: `옛 하네스가 쓴 매니페스트라 ${m[1]}개 파일이 바뀌었는지 가릴 수 없습니다. 다시 생성하면 해시가 기록됩니다.`, run: render };
  if (w === "the pinned copy has no recorded hash")
    return { title: "고정된 하네스 사본의 해시가 기록되어 있지 않습니다", body: "사본이 설치 뒤 바뀌었는지 가릴 수 없습니다. 다시 설치하면 해시가 기록됩니다.", cmd: "harness install" };
  if (w === "no manifest of managed files")
    return { title: "하네스 파일 목록(매니페스트)이 없습니다", body: "무엇이 하네스 파일인지 가릴 수 없습니다. 다시 생성하면 목록이 만들어집니다.", run: render };
  return null;
}

// label 을 주면 상태 대신 그 글자를 보인다 — 아직 설정하지 않은 것(SETUP)은 고장(FAIL)과 다르게 읽혀야 한다.
// 조치: run = ▷ 로 바로 실행(doctorFix 의 종류와 보일 명령), href = 고칠 화면, cmd = 직접 돌릴 명령(실행 버튼 없음)
export function explain(i, base) {
  const w = i.what, d = i.detail || "";
  let m;
  if (i.section === "remote" && i.state !== "ok") {
    const r = explainRemote(i, base);
    if (r) return r;
  }
  if ((m = w.match(/^\.ai\/project\/([\w-]+)\.md$/)) && DOCS[m[1]]) {
    const tab = DOCS[m[1]].title;
    if (d === "missing") return { title: `${tab} 문서가 없습니다`, body: `Project Settings 의 ${tab} 탭에서 새로 작성합니다.`, href: `${base}/project/${m[1]}` };
    const n = d.match(/^(\d+) placeholder/)?.[1];
    return { title: `${tab} 문서가 아직 덜 채워졌습니다`, body: `채우지 않은 자리가 ${n ?? "몇"}곳 남아 있습니다. 에이전트는 빈 자리를 근거로 쓰지 못합니다.`, href: `${base}/project/${m[1]}` };
  }
  if (w === "script/harness-verify.sh" && i.state !== "ok") {
    if (d.startsWith("not set up"))
      return { label: "SETUP", title: "검증 명령을 아직 정하지 않았습니다",
        body: "명령 탭에서 테스트·코드 검사 명령을 정하면 하네스가 검증 스크립트를 만듭니다. 이 검증은 커밋 뒤와 CI 에서 돕니다.",
        href: `${base}/project/commands` };
    const step = d.match(/^fails at (.+)$/)?.[1];
    return { title: step ? `검증이 실패합니다: ${step}` : "검증이 실패합니다",
      body: `${step ? `'${step}' 단계의 명령이 실패했습니다. ` : ""}▷ 로 다시 돌려 출력을 확인하고, 명령이 틀렸다면 명령 탭에서 고칩니다.`,
      run: { kind: "verify", cmd: "bash script/harness-verify.sh" }, href: `${base}/project/commands` };
  }
  if (w === "script/verify-project.sh (hand-written)" && i.state !== "ok")
    return { title: "손으로 쓴 검증 스크립트가 실패합니다", body: "script/verify-project.sh 가 검증을 맡고 있습니다. ▷ 로 다시 돌려 출력을 확인합니다.",
      run: { kind: "verify", cmd: "bash script/verify-project.sh" } };
  if (w === "script/verify-project.sh runs instead of [commands] and [verify]")
    return { title: "손으로 쓴 검증 스크립트가 명령 탭 설정을 가리고 있습니다",
      body: "script/verify-project.sh 가 있으면 그것만 돌고, 명령 탭에 적은 명령은 돌지 않습니다. 검사를 명령 탭으로 옮긴 뒤 이 파일을 지웁니다.",
      href: `${base}/project/commands` };
  if (w === ".ai/project/commands.md is no longer read")
    return { title: "옛 명령 문서는 더 이상 쓰이지 않습니다", body: "명령은 이제 명령 탭(harness.toml)에서 관리합니다. .ai/project/commands.md 는 지워도 됩니다." };
  // 옛 하네스 사본의 줄 — 명령을 문서와 손으로 쓴 스크립트로 받던 때
  if (w === "script/verify-project.sh" && i.state !== "ok")
    return { title: "프로젝트 검증이 아직 통과하지 않습니다",
      body: "script/verify-project.sh 는 이 프로젝트의 린트·테스트를 돌리는 스크립트입니다. Project Settings 의 명령 탭에 적은 명령을 이 스크립트에도 넣어야 통과합니다.",
      run: { kind: "verify", cmd: "sh script/verify-project.sh" } };
  if (w === "git hooks enabled" && i.state !== "ok") {
    // 켜는 명령은 doctor 가 detail 에 백틱으로 싣는다 — 서브프로젝트면 그 경로가 앞에 붙는다
    const cmd = d.match(/`([^`]+)`/)?.[1];
    const hooks = { title: "git 훅이 꺼져 있습니다", body: "커밋·push 할 때 하네스 검사(생성 파일 일치, 보호 브랜치)가 돌지 않습니다." };
    return cmd ? { ...hooks, run: { kind: "hooks", cmd } } : hooks;
  }
  if ((m = w.match(/^(\d+) files differ from the config$/)))
    return { title: "생성 파일이 설정과 다릅니다", body: `${m[1]}개 파일이 harness.toml 과 맞지 않습니다. 다시 생성하지 않으면 커밋이 막힙니다.`,
      run: { kind: "render", cmd: "harness render" } };
  if (i.section === "managed files" && i.state !== "ok") {
    const r = explainManaged(i);
    if (r) return r;
  }
  if ((m = w.match(/^no command guard for (.+)$/)))
    return { title: `${m[1]} 에는 명령 가드가 걸리지 않습니다`, body: "위험한 셸 명령을 막는 bash-guard.sh 가 이 오케스트레이터에는 연결되지 않습니다. git 훅 검사는 그대로 적용됩니다.", href: `${base}/settings` };
  if ((m = w.match(/^roles\.([\w-]+)\.model = (.+) is not used$/)))
    return { title: `${m[1]} 역할에 적은 모델(${m[2]})은 쓰이지 않습니다`, body: "이 역할은 오케스트레이터가 직접 실행하므로 Harness 탭의 오케스트레이터 모델을 따릅니다.", href: `${base}/agents` };
  if ((m = w.match(/^(.+) cannot run subagents$/)))
    return { title: `${m[1]} 는 서브에이전트를 실행할 수 없습니다`, body: `다음 역할에 CLI 러너를 지정해야 합니다: ${d.replace(/^.*: /, "")}`, href: `${base}/agents` };
  if ((m = w.match(/^roles\.([\w-]+)\.model = (.+)$/)))
    return { title: `${m[1]} 역할의 모델(${m[2]})을 이 컴퓨터에서 찾지 못했습니다`, body: "그 에이전트 CLI 가 제공하는 모델로 바꿉니다. 모델 목록이 오래됐다면 Agents 탭에서 도구 목록을 새로 읽습니다.", href: `${base}/agents` };
  if ((m = w.match(/^role `(.+)` is not in harness\.toml$/)))
    return { title: `설정에 없는 역할(${m[1]})을 가리키는 문서가 있습니다`, body: `위치: ${d.replace(/^still referenced at /, "")}` };
  if ((m = w.match(/^`(.+)` is registered to another path$/)))
    return { title: `프로젝트 이름 ${m[1]} 이 다른 경로에 등록되어 있습니다`,
      body: `UI 와 실행 기록이 ${d} 를 가리킵니다. 그 경로가 더는 이 프로젝트가 아니면 여기서 다시 설치해 등록을 넘겨받습니다. 아직 쓰는 클론이면 그쪽에서 harness uninstall 하거나 이 리포의 project.name 을 바꿉니다.`,
      cmd: "harness install" };
  if (w === "this repository is not registered")
    return { title: "이 리포가 등록되어 있지 않습니다", body: "UI 의 프로젝트 목록에 나오지 않습니다.", cmd: "harness install" };
  if ((m = w.match(/^`(.+)` does not exist$/)))
    return { title: `없는 경로(${m[1]})를 가리키는 문서가 있습니다`, body: `위치: ${d.replace(/^referenced by /, "")}` };
  if ((m = w.match(/^forge CLI `(.+)`$/)) && i.state !== "ok")
    return { title: `${m[1]} CLI 가 설치되어 있지 않습니다`, body: "이슈와 리뷰 요청을 만들 때 씁니다." };
  if ((m = w.match(/^adapter `(.+)`$/)) && i.state !== "ok")
    return d === "file is missing"
      ? { title: `${m[1]} 연결 스크립트가 없습니다`, body: "harness render 로 다시 만듭니다.", run: { kind: "render", cmd: "harness render" } }
      : { title: `${m[1]} 연결이 아직 검증되지 않았습니다`, body: "실제 저장소에 대고 한 번 돌려 확인합니다.", cmd: "script/forge-selftest.sh" };
  if ((m = w.match(/^decision-record tool `(.+)`$/)) && i.state !== "ok")
    return { title: `ADR 도구(${m[1]})가 설치되어 있지 않습니다`, body: "결정 기록(ADR)을 만들 때 씁니다." };
  return { title: w, body: d };
}
