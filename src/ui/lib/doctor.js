// `harness status` 의 doctor 줄 → 사람이 읽는 한 항목. CLI 의 영어 문구를 그대로 보이지 않는다.
// 모르는 줄은 원문을 그대로 둔다 — 새 검사가 생겨도 사라지지 않게.
import { DOCS } from "./fields.js";

export const SECTIONS = {
  config: "설정",
  "generated files": "생성 파일",
  "project facts": "프로젝트 문서",
  verification: "검증",
  references: "문서 참조",
  "tools and connections": "도구와 연결",
  git: "git",
};

// label 을 주면 상태 대신 그 글자를 보인다 — 아직 설정하지 않은 것(SETUP)은 고장(FAIL)과 다르게 읽혀야 한다.
// 조치: run = ▷ 로 바로 실행(doctorFix 의 종류와 보일 명령), href = 고칠 화면, cmd = 직접 돌릴 명령(실행 버튼 없음)
export function explain(i, base) {
  const w = i.what, d = i.detail || "";
  let m;
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
  if (w === "git hooks enabled" && i.state !== "ok")
    return { title: "git 훅이 꺼져 있습니다", body: "커밋·push 할 때 하네스 검사(생성 파일 일치, 보호 브랜치)가 돌지 않습니다.",
      run: { kind: "hooks", cmd: "git config core.hooksPath script/githooks" } };
  if ((m = w.match(/^(\d+) files differ from the config$/)))
    return { title: "생성 파일이 설정과 다릅니다", body: `${m[1]}개 파일이 harness.toml 과 맞지 않습니다. 다시 생성하지 않으면 커밋이 막힙니다.`,
      run: { kind: "render", cmd: "harness render" } };
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
