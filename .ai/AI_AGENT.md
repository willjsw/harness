# harness — 공통 규칙 (정본)

이 파일이 모든 AI 하네스가 읽는 **규칙 정본**이다.

**이 파일은 harness.toml 과 `.ai/project/` 에서 생성된다. 직접 고치지 않는다.**
프로젝트 사실(1~5장)은 `.ai/project/` 의 파일을(3장 명령은 `harness.toml` 의 `[commands]` 를), 규칙 값(6장 이후)은
`harness.toml` 을 고친 뒤 `harness render` 를 돌린다. 고쳐야 할 곳이 언제나 한 곳이도록 이렇게 둔다.

## 1. 담당 범위

- 담당 범위는 **이 리포지토리로 한정**한다.
- AI 개발 하네스를 만든다 — 설정 파일 하나(`harness.toml`)와 프로젝트 사실(`.ai/project/`)에서
  규칙 문서·git 훅·권한 파일·에이전트 정의·절차 문서를 생성하고, 이슈 하나를 명세 → 분해 → 구현 →
  리뷰 루프로 끌고 가는 역할·절차·가드 한 벌을 대상 리포에 깐다.
- 지키는 층은 넷이다 — 규칙 문서(에이전트가 읽는다), 권한 설정(도구가 막는다), 명령 가드와 git 훅
  (실행 전에 막는다), CI(머지 전에 돌린다). 문서에만 있고 깔리지 않는 층은 두지 않는다.

### 사용자

- 자기 리포에 AI 에이전트(Claude Code·Codex CLI)로 개발 절차를 세우려는 개발자. `harness install` 로
  깔고 `harness.toml` 과 `.ai/project/` 로 자기 값을 채운다. 모노레포는 서브프로젝트마다 따로 깐다
- 그 리포에서 도는 에이전트 — 규칙 정본·역할 계약·절차 문서를 읽는 쪽이다
- 이 리포 자신 — 소스 리포도 같은 하네스를 쓴다. 루트 `harness.toml` 이 이 리포의 설정이고,
  대상 리포로 복사되는 기본값은 `src/templates/harness.toml` 이다

### 할 수 있는 일

- 대상 리포에 하네스를 설치·갱신·검사·점검·제거한다 (`install` · `render` · `check` · `doctor` · `uninstall`)
- 설정 값·절차 단계·검증 검사를 CLI 로 바꾸고 생성물을 따라 바꾼다 (`set` · `steps` · `checks`)
- 설정된 오케스트레이터로 절차를 시작한다 (`run`). 절차는 `/prework` · `/work` · `/retro` 셋이 기본이고 프로젝트가 더할 수 있다
- 웹 UI 로 설정·절차·에이전트·프로젝트 문서·실행 지표·점검 결과를 보고 고친다 (`start-server`)
- 실행 지표를 모으고 집계한다 (`metrics`). 이 기기의 에이전트 CLI 와 결정 기록 도구를 찾는다 (`tools`)

### 만들지 않는 것

- 에이전트 CLI 자체(Claude Code·Codex CLI 등) — 벤더가 만든다. 하네스는 `src/templates/vendors.toml` 로
  실행 명령만 안다
- forge(GitHub·GitLab·Jira)의 CLI 와 인증 — `gh`·`glab`·`jira` 가 맡는다. 하네스는 어댑터(`script/forge/`)로
  그 명령을 감쌀 뿐이다
- Homebrew 포뮬러 — 별도 탭 리포 `willjsw/homebrew-harness` 가 갖는다
- 대상 프로젝트의 사실(범위·아키텍처·용어·테스트 기준) — 그 프로젝트가 `.ai/project/` 에 쓴다.
  하네스는 빈 원형만 깔고, 채우는 것은 사람이나 UI 의 AI Completion 이다
- 히스토리 전수 시크릿 조사 — pre-commit 의 시크릿 스캔은 더한 줄만 본다. 전수 조사는 다른 도구의 일이다

### 인접 모듈

- `willjsw/homebrew-harness` — 전역 CLI 설치 포뮬러. 이 리포의 `src/` 아래를 `libexec` 에 넣고
  `bin/harness` 링크를 건다. 포뮬러 수정은 그 리포에서 한다

## 2. 용어

### 용어

| 표기 | 뜻 |
|---|---|
| 하네스 | 설정 하나에서 생성되는 규칙·훅·권한·에이전트 정의·절차 한 벌. 이 리포가 만드는 것 |
| 하네스 루트 | `harness.toml` 이 있는 디렉터리. 리포 루트가 아니어도 된다(모노레포) |
| 소스 리포 | 이 리포. `src/bin/harness` 와 `src/templates/` 를 갖고, 자기 자신은 고정하지 않고 자기 것으로 돈다 |
| 고정(pin) | 대상 리포가 `.harness/` 에 설치 시점의 하네스 사본을 두고 그 버전으로만 도는 것 |
| 생성 파일 | `harness.toml` 에서 나오는 파일. 고치지 않고 `render` 로 다시 만든다 |
| 관리 파일 | 하네스가 그대로 복사해 두는 파일. 갱신이 덮는다 |
| 소유 파일 | 프로젝트 것. 없을 때만 깔고 갱신이 건드리지 않는다 (`.ai/project/` · `docs/spec/README.md` · CI 설정) |
| 보호 문서 | 에이전트가 근거로 읽는 소유 파일(scope · architecture · glossary · testing · `roles/` · `workflows/`). 권한과 가드가 쓰기를 막고, 사람이 지시한 턴에만 고친다 |
| 매니페스트 | 지난 렌더가 무엇을 깔았는지 적은 목록(`.harness/generated` · `.harness/managed`). 정리와 제거의 근거 |
| 정본 | 어떤 값·규칙을 고칠 때 손대는 유일한 자리. 규칙 값은 `harness.toml`, 프로젝트 사실은 `.ai/project/` |
| 렌더 | 설정과 프로젝트 사실에서 생성 파일을 만드는 일 (`harness render`) |
| 역할 | 절차의 한 단계를 맡는 에이전트 (requirement-analyzer · spec-writer · planner · developer · code-reviewer · docs-writer · security-guard) |
| 역할 계약 | 역할이 무엇을 판단하고 무엇을 내는지 정한 문서 (`.ai/templates/<역할>.md`). 자기 러너를 모른다 |
| 역할 선언 | 역할 어댑터 본문의 frontmatter (`src/templates/agents/<역할>.md`). `distinct_from` · `headless` · `entry` · `about` |
| 러너 | 역할을 실제로 도는 주체. `inproc`(오케스트레이터의 서브에이전트) 또는 CLI(`claude` · `codex`) |
| 오케스트레이터 | 절차를 실제로 도는 세션의 CLI (`harness.orchestrator`) |
| 실행 계획 | 역할마다 무엇을 어떻게 띄우는지 적은 생성물 (`script/harness.plan.json`). `run-agent.py` 가 읽는다 |
| 벤더 선언 | 에이전트 CLI 등록부 (`src/templates/vendors.toml`). 실행 명령은 여기만 갖는다 |
| 절차(워크플로) | 역할·스크립트·게이트를 순서로 엮은 것. `.ai/workflows/<절차>.md` 로 생성된다 |
| 조각(fragment) | 절차 한 단계의 본문 원형 (`src/templates/workflows/<절차>/<id>.md`) |
| 게이트 | 사람의 결정·승인을 기다리는 절차 단계 |
| 요구사항 이슈 | 사람이 만드는 상위 이슈. 분해가 있으면 브랜치·리뷰 요청의 단위 |
| task 이슈 | 승인된 분해에서 `sync-task-issues.sh` 가 만드는 하위 이슈. 커밋의 단위 |
| 분해 | 명세를 task 로 쪼갠 문서 (`docs/plan/<번호>/`). 원격 통합 브랜치에 있으면 승인된 것 |
| 착수 판정 | `work-preflight.sh` 가 원격 기준으로 내리는 판정 — `plan` · `standalone` · 착수 불가 |
| 리뷰 요청 | GitHub 의 PR, GitLab 의 MR. 문서에서는 forge 에 중립적으로 이렇게 부른다 |
| 회차 라벨 | 리뷰 요청에 붙는 `<prefix>:<N>` 라벨. `review-mr.sh` 만 올린다 |
| 이월 이슈 | 범위 밖으로 넘긴 지적을 담는 이슈. `create-carryover-issue.sh` 가 만든다 |
| 표지 | 기계가 읽는 문자열 (`script/harness-format.sh`). `REVIEW_VERDICT` · `harness:allow-secret` 등 |
| forge | 이슈 추적기와 코드 리뷰 호스트를 묶어 부르는 말 (GitHub · GitLab · Jira) |
| 어댑터 | forge 명령을 감싸는 스크립트(`script/forge/<kind>.sh`), 또는 역할 계약을 CLI 별 형식으로 옮긴 정의 파일(`.claude/agents/` · `.codex/agents/`) |
| 자체 검사 | 어댑터가 계약을 지키는지 실제 forge 로 확인하는 것 (`script/forge-selftest.sh`) |
| 등록부 | 설치된 프로젝트와 기기의 도구 기록 (`~/.harness/`). UI 가 이것으로 프로젝트를 전환한다 |
| 스팬 · 트레이스 | 실행 지표의 단위. 명령·단계·역할·스크립트 한 번이 스팬, 한 실행의 스팬 묶음이 트레이스 |
| 결정 기록 | 되돌리기 비싼 결정의 "왜" (`docs/adr/`, Nygard 방식) |

### 폐기된 별칭

| 옛 표기 | 정식 이름 |
|---|---|
| 루트 `harness.toml` (대상 리포로 복사되는 기본값) | `src/templates/harness.toml`. 루트의 것은 이 리포 자신의 설정 |
| `.harness/harness.toml` (설치본의 기본 설정) | `.harness/templates/harness.toml` |
| `bin/` · `templates/` · `ui/` · `test/` (리포 루트) | `src/` 아래의 같은 이름 |
| `script/verify-project.sh` (손으로 쓰던 검증 스크립트) | `harness.toml` 의 `[commands]` · `[verify]` 에서 생성되는 `script/harness-verify.sh` |
| `.ai/project/commands.md` (옛 명령 문서) | `harness.toml` 의 `[commands]` |
| 단계의 `kind` | 단계의 `type` (`workflows.<절차>.steps`) |
| `AGENTS` 표 · `SCRIPT_ROLES` (CLI 안의 벤더·역할 분기) | 벤더 선언(`vendors.toml`)과 역할 선언(frontmatter) |
| task 라벨 `new` | `Task` (`issues.labels.task`) |

## 3. 명령어

| 작업 | 명령 |
|---|---|
| 빌드 | 정하지 않음 |
| 테스트 전체 | `src/test/render-test.sh` |
| 단일 테스트 | 정하지 않음 |
| 코드 검사 | 정하지 않음 |
| 코드 자동 수정 | 정하지 않음 |
| 검증 일괄 | `script/run-lint-test.sh` |

검증(`script/harness-verify.sh`)은 이 순서로 돈다: CLI 가 컴파일된다 → UI 단위 테스트 → 테스트.

자동화 스크립트는 `script/` 에 둔다. 새 스크립트는 `script/README.md` 표에 한 줄 추가한다.

## 4. 스택

- CLI: python3 (3.11 이상, `tomllib`). 표준 라이브러리만 쓴다 — 의존성 0
- 대상 리포에 깔리는 스크립트: POSIX sh · bash · python3. 훅은 sh
- UI: Node.js + Next.js (React). `harness start-server` 가 첫 실행에 `npm install` 을 한다
- 설정 형식: TOML. 문서는 마크다운(한국어)

**정확한 버전과 의존성 목록은 `src/ui/package.json` 이 정본이다.** CLI 와 스크립트는 매니페스트가 없다 — python3 3.11 이상이 전부다.

### 도입 예정이지만 아직 없는 것

없음

## 5. 아키텍처

### 구성 요소

- `src/bin/harness` — python3 표준 라이브러리만 쓰는 단일 파일 CLI. 설정을 읽어 검증(`validate()`)하고, 생성물을 만들고(`plan()` · `render`), 검사하고(`check`), 점검하고(`doctor`), 설정을 고치고(`set` · `steps` · `checks`), 절차를 띄우고(`run`), 지표를 집계한다(`metrics`). 명령 전부가 여기 있다
- `src/templates/` — 대상 리포로 가는 것 전부. `harness.toml`(기본 설정) · `generated/`({{VAR}} 치환) · `managed/`(그대로 복사) · `owned/`(없을 때만 복사) · `agents/`(역할 어댑터 본문과 선언) · `workflows/<절차>/`(절차 조각) · `forge/<kind>/`(forge 명령 사전 조각) · `adr/<style>/`(결정 기록 문서 세트) · `ci/<host>/`(CI 골격) · `vendors.toml`(에이전트 CLI 등록부)
- `src/ui/` — Next.js 앱. `harness start-server` 가 루프백에 띄운다. 화면은 홈(등록된 프로젝트 카드)·Harness(설정)·Project Settings(사실 문서·명령)·Workflows(단계 캔버스)·Agents(역할)·Metrics·Doctor. 쓰기는 CLI 명령을 서브프로세스로 부른다
- `src/test/render-test.sh` — 회귀 테스트. `src/test/fake-forge.sh` 는 forge 어댑터 자리를 대신하는 페이크(계약 위반 6종을 주입할 수 있다)
- 대상 리포에 깔리는 `script/` — 착수 판정(`work-preflight.sh`)·task 이슈 동기화·리뷰 루프(`review-mr.sh` · `post-review.sh`)·이월 이슈·되감기·가드(`hooks/`)·시크릿 스캔·사용 기록·지표 기록(`metric.py`)·역할 실행기(`run-agent.py`)·forge 어댑터(`forge/`). 정본은 `src/templates/managed/script/` 이고, 이 리포의 `script/` 는 거기서 설치된 사본이다
- 기기 단위 상태 — 홈 아래 `.harness/`: 설치 등록부(`<프로젝트>/project.json`), 도구 기록(`tools.json`), 프로젝트별 지표·사용 기록·가져오기 커서

### 데이터 흐름

- 렌더: `harness.toml` + `.ai/project/` → `src/bin/harness render` → 생성 파일(`.ai/AI_AGENT.md` · `.ai/workflows/` · `.ai/forge.md` · `.ai/adr.md` · `.claude/` · `.codex/` · `script/githooks/` · `script/harness.env` · `script/harness.plan.json` · `script/harness-verify.sh` · `CLAUDE.md` · `AGENTS.md`) → 에이전트·훅·가드·CI 가 읽는다
- UI: 브라우저 → 루프백 HTTP → Next.js 서버 액션 → `src/bin/harness <명령>` 서브프로세스 → 파일 → 다시 UI. 저장 전 검사는 정적 검사와 저렴한 모델(오케스트레이터 CLI, 쓰기 도구 없이)로 한다
- 절차 실행: `harness run` → 오케스트레이터 CLI → 절차 문서를 따라 역할(서브에이전트, 또는 `script/run-agent.py` 가 실행 계획대로 띄운 CLI)과 스크립트를 부른다. 리뷰 루프는 `work-preflight.sh` → 구현자 → `review-mr.sh`(diff 조회 · 리뷰어 실행 · 등록 · 회차 라벨) → `post-review.sh`(발견 집계 · 반복 지적 누적) → 종료 코드로 분기
- forge: 스크립트 → `script/forge.sh` 어댑터 함수(tracker 군 · review 군) → `gh` · `glab` · `jira`. 호출부는 forge 를 모르고 정규화된 JSON 을 받는다
- 실행 지표: 명령·단계·역할·스크립트 → `script/metric.py`(start · end · wrap) → 홈 아래 `.harness/<프로젝트>/metrics/spans-*.jsonl` → `harness metrics`(가져오기 · 집계) → UI Metrics 탭. 트레이스·부모 스팬은 환경 변수로 자식에게 넘어간다

### 신뢰 경계

- 들어오는 입력: `harness.toml`(TOML)과 `.ai/project/` 마크다운(프로젝트가 쓴다), 오케스트레이터 훅이 stdin 으로 주는 도구 호출 JSON(`script/hooks/bash-guard.sh`), forge CLI 의 출력, 에이전트 CLI 의 출력(JSON · JSONL)과 대화 기록, UI 요청(루프백에만 묶인다), 명령줄 인자(경로는 리포 기준 상대 경로만 받는다 — 절대 경로 · `..` · 공백 · glob 거부)
- 다루는 민감 정보: forge 와 에이전트 CLI 의 인증은 각 CLI 가 갖고 리포에 두지 않는다. 실행 지표는 프롬프트·명령줄·문서 본문을 남기지 않고, 실패 로그는 토큰·쿠키·URL 쿼리·이메일·홈 경로를 지운 뒤 끝부분만 남긴다(디렉터리 0700 · 파일 0600). `script/secret-scan.sh` 가 커밋에 새로 들어오는 자격증명을 막고, 막을 때 값을 출력에 옮기지 않는다
- 가드는 미탐을 허용하고 오탐을 피한다. 규칙이 정본이고 가드·권한은 보조다. 단 가드가 설정을 읽지 못하면 통과가 아니라 차단이다

### 새 코드를 둘 곳

- 새 생성 파일 → `src/bin/harness` 의 `plan()` 에 등록한다. 어느 설정 키가 어느 파일에 닿는지 기록하는 유일한 자리다
- 새 설정 키 → `src/templates/harness.toml` 의 주석과 기본값, `src/bin/harness` 의 `validate()` · `derive()`, README 의 "harness.toml 이 정하는 것" 표. UI 는 `harness schema` 와 `src/ui/lib/fields.js` 가 그것을 그린다
- 새 CLI 명령 → `COMMANDS` 표와 `cmd_<이름>()`. 프로젝트에 고정된 버전이 답해야 하면 `DELEGATES` 에도 넣는다
- 새 역할 → `src/templates/agents/<역할>.md`(어댑터 본문과 frontmatter 선언) + `src/templates/managed/.ai/templates/<역할>.md`(계약) + `src/templates/harness.toml` 의 `[roles.<역할>]`. 부를 수 있는 경로(커맨드나 절차 단계)를 함께 만든다
- 새 에이전트 CLI → `src/templates/vendors.toml` 한 항목. 실행 명령은 여기만 갖고, 사용량 파서가 필요하면 `run-agent.py` 의 `PARSERS`
- 새 forge → `src/templates/managed/script/forge/<kind>.sh`(계약 함수 전부) + `src/templates/forge/<kind>/`(명령 사전 조각) + `validate()` 의 허용 목록. 실제 forge 로 `forge-selftest.sh` 를 통과하기 전까지 머리글에 미검증 표기
- 새 관리 스크립트 → `src/templates/managed/script/` + `script/README.md` 표 한 줄. 회귀 테스트는 같은 곳의 `test-<이름>.sh`
- 새 가드 → `src/templates/managed/script/hooks/_guards.sh` 의 함수 + `bash-guard.sh` 의 호출 + `test-bash-guard.sh` 케이스. 판정에 쓰는 값은 `script/harness.env` 로 받는다
- 새 절차 단계 본문 → `src/templates/workflows/<절차>/<id>.md`. 다른 단계는 `{{step:<id>}}` 로 가리킨다
- 새 결정 기록 스타일 → `src/templates/adr/<style>/`
- UI 화면 → `src/ui/app/[project]/<화면>/` + `src/ui/components/`. 설정을 고치는 로직은 UI 에 두지 않고 CLI 명령을 부른다. 순수 함수는 `src/ui/lib/` 에 두고 단위 테스트한다
- 새 회귀 테스트 → `src/test/render-test.sh` 의 `UT-<번호>` 블록. UI 순수 함수는 `src/ui/lib/<모듈>.test.js`
- 되돌리기 비싼 결정 → `docs/adr/`. 절차·워크플로 조정은 대상이 아니다

### 계층과 의존 방향

- `src/templates/` 는 아무것도 import 하지 않는다. `src/bin/harness` 가 읽고, 결과가 대상 리포에 놓인다
- 규칙 값은 `harness.toml` 에서 생성물로 내려간다. 대상 리포의 스크립트·훅·가드는 값을 하드코딩하지 않고 생성물(`script/harness.env` · `script/harness.plan.json` · `script/forge.sh`)에서 받는다
- 관리 스크립트는 forge 를 `script/forge.sh` 의 어댑터 함수로만 부른다. `gh` · `glab` · `jira` 를 직접 부르지 않는다
- 역할 계약(`.ai/templates/`)은 자기 러너·모델·다음 역할을 모른다. 그것은 절차(`.ai/workflows/`)와 어댑터(`.claude/` · `.codex/`)와 실행 계획의 몫이다. 어댑터에는 도구 이름·권한 같은 결합 정보만 둔다
- `src/ui/` → `src/bin/harness`(서브프로세스) → 파일. 반대 방향은 없다. UI 는 파일 경로를 짓지 않고 `harness schema` 에서 받는다
- 기기 단위 상태(등록부·도구 기록·지표)는 홈 아래에 두고 리포에 두지 않는다. 리포에 두는 것은 클론한 사람에게도 같아야 하는 것뿐이다

### 검사하는 것

기계로 검사하는 규칙은 이 문서가 아니라 `harness.toml` 의 `[verify]` 에 둔다 — 커밋 뒤와 CI 에서 실제로 돈다.
목록은 `.ai/AI_AGENT.md` 3장에 있다.

### 검사하지 않는 것 (현재 상태 기록)

- `src/bin/harness` 가 명령 전부를 한 파일에 담는다(2천 줄 이상). 모듈로 나누지 않았다
- 대상 리포에 깔리는 셸 스크립트는 정적 검사 도구를 거치지 않는다. 회귀 테스트(`script/test-*.sh`)만 있다
- UI 의 화면과 서버 액션은 자동 테스트가 없다. 순수 함수만 단위 테스트한다
- README 와 `.ai/project/` 가 같은 사실(구조·명령·부류)을 두 곳에 적는다. README 는 사람용이고 여기는 에이전트용이라 둔 것이지만, 한쪽이 낡을 수 있다
- GitLab · Jira 어댑터는 실제 forge 로 검증하지 않았다. 머리글의 미검증 표기가 그 사실이다

### 코드 주석

**주석은 코드 그 자체만 간결하게 서술한다.** 문서 번호·이슈 번호·테스트 항목 ID 를 주석과
테스트 이름에 넣지 않는다.

문서는 생기고 사라지고 번호가 다시 매겨진다. 주석에 박아 둔 참조는 담당자가 바뀌거나 그 문서가
없어지는 순간 **가리키는 곳이 사라진 채 남아** 아무 의미가 없어지고, 추적도 불가능해진다.

- 근거 문서를 지목하는 대신 **그 근거가 무엇인지**를 쓴다
- 미구현을 알릴 때는 무엇이 없는지만 쓴다 ("후속 이슈에서 들어온다" 가 아니라 "아직 구현하지 않았다")
- 테스트 이름은 **무엇을 검증하는지**로 짓는다
- 산출물과 코드를 잇는 추적은 커밋 메시지와 리뷰 요청이 갖는다. 이슈 번호는 거기에 단다
- 스크립트도 코드다. 단 **그 스크립트가 실제로 읽거나 쓰는 경로는 동작 서술이므로 남긴다** —
  빼는 것은 "이 규칙의 정본은 저기 있다" 같은 **포인터**다

## 6. Git 컨벤션

### 6-1. 커밋 메시지 형식

```
<tag>: {summary}(#{issue})

- 커밋 설명 1
- 커밋 설명 2

relates to <상위 이슈>
```

예: `feat: short summary(#123)`

제목의 이슈는 **그 커밋이 끝내는 task 이슈**다. 상위 요구사항은 본문 마지막 줄의
`relates to` 로 단다 — 제목에 둘을 넣지 않는다. 상위가 없는 단독 작업이면 그 줄을 생략한다.

### 6-2. 태그 종류

`feat | fix | docs | chore | refactor`

| 태그 | 언제 |
|---|---|
| `feat` | 신규 로직·기능 |
| `fix` | 로직 자체의 수정, 오류 수정 |
| `refactor` | 수행 결과에 영향을 주지 않는 코드 정리 |
| `docs` | 문서화 |
| `chore` | 빌드·개발환경·CI·하네스 구성 |

목록에 없는 태그를 쓰려면 `harness.toml` 의 `commit.tags` 에 먼저 넣는다. 훅이 막는다.

### 6-3. 작성 규칙

- 모든 커밋은 유의미하고 명확한 작업 단위로 작성한다.
- 커밋 메시지는 명사형 종결어미, 개조식으로 작성한다.
- 커밋 메시지에 도구 생성 표기를 추가하지 않는다.
- 브랜치명: `<tag>/<issue-number>-<english-summary>`
  **이슈 하나가 브랜치 하나·리뷰 요청 하나다.**
  번호와 태그는 **작업의 단위가 되는 이슈**의 것을 쓴다. 그것이 어느 이슈인지는 분해
  (`docs/plan/<번호>/`)의 유무가 정한다.
  - 분해가 있으면 **요구사항 이슈**가 단위다. 그 안의 task 는 커밋 단위로 내려간다
  - 분해가 없으면 **그 이슈 자신**이 단위다. 상위가 없으므로 `relates to` 를 쓰지 않는다
- **리뷰 요청 대상 브랜치는 `main`.** 보호 브랜치(`main`)로의
  직접 push 는 훅과 권한 설정이 막는다.
- **선행 리뷰 요청이 머지되면 후속 브랜치를 `main` 위로 rebase 한다.** squash 머지는
  커밋 ID 를 바꾸므로, 그냥 두면 diff 에 이미 머지된 변경이 다시 섞인다.
  **`git fetch -p origin` 을 먼저 한다** — 로컬 추적 ref 는 자동 갱신되지 않아 낡은 ref 위로
  rebase 하면 문제가 남는다. **rebase 뒤 push 는 사람이 한다** — force push 는 AI 가 하지 않는다.
- 이슈 번호가 없으면 커밋하지 않고 이슈 생성을 먼저 요청한다.

형식은 `script/githooks/commit-msg` 와 `pre-push` 가 기계적으로 한 번 더 막는다.
그 훅도 이 장도 `harness.toml` 에서 생성되므로 서로 어긋날 수 없다.

### 6-4. 양식과 이슈 생성

- 리뷰 요청 생성: `.ai/templates/mr.md` 항목을 전부 채운다. 작성 요령은 `.ai/templates/mr-guide.md`.
- 이슈 생성: `.ai/templates/issue-requirement.md`(요구사항) 또는 `.ai/templates/issue-task.md`(task).

  **어떤 경로로 만들든 아래 셋을 지킨다.**

  - **본문을 채운다.** 양식 원문을 그대로 등록하지 않는다 — 빈 이슈를 나중에 채우는 사람은
    만들 때의 맥락을 갖고 있지 않다
  - **필수 필드를 넣는다** (`assignee`). 상속할 곳이 없으면 만들지 말고
    물려줄 이슈에 먼저 지정한다
  - 이 프로젝트는 이슈 삭제를 **금지**한다. 잘못 만든 이슈는 `invalid` 로
    닫힌 채 영구히 남는다 — 되돌릴 수 없으므로 만들기 전에 확인한다

  **이슈를 만드는 수단은 경로마다 정해져 있다. 즉흥으로 만들지 않는다.**

  | 경로 | 수단 |
  |---|---|
  | 분해의 task 이슈 | `script/sync-task-issues.sh <요구사항 이슈번호>` — 승인된 분해로만 이슈가 생기게 하는 게이트다 |
  | 범위 밖으로 넘긴 지적의 이월 이슈 | `script/create-carryover-issue.sh <원본이슈> <제목> <본문파일>` |
  | 그 밖 (요구사항 이슈, 단독 task) | 사람이 만든다. 필요하다는 사실만 보고한다 |

- 양식 항목을 임의로 삭제하지 않고, 해당 없는 항목은 "해당 없음" 으로 표기한다.

## 7. 금지 사항

**아래를 하지 않는다.** 각 항목 뒤의 설명은 그 금지의 근거이거나 예외이지, 지시가 아니다.

- 이 리포지토리 외부 파일 수정
- 보호 브랜치(`main`) 직접 push, force push
- 명시적 지시 없는 커밋, push, 리뷰 요청 생성, 머지
- 리뷰 요청·이슈를 닫는 것. **예외는 `script/rollback-work.sh` 하나**이고, 그것도 사용자가
  직접 부르고 확인을 준 턴에서만 돈다 — 무엇이 닫히는지 먼저 보이고 멈춘다
- 시크릿·접속 정보의 리포지토리 기록. **pre-commit 이 새로 들어오는 것을 막는다** —
  막혔는데 자격증명이 아니면 그 줄에 `harness:allow-secret` 을 달고, 맞으면 지우고
  **폐기·재발급한다**(커밋만으로 유출이다). 값은 `.ai/project/environment.md` 에도 적지 않는다 —
  거기에는 항목명과 취득 경로만 둔다
- 확인되지 않은 값을 사실처럼 문서에 기재. 미확인 값은 `<!-- TBD: 확인 필요 -->`
- 문서 간 충돌을 임의 판단. **결정이 필요하면 사용자에게 올린다.** 이 세션에서 답할 수
  없는 것만 해당 문서 상단 "Open Questions" 에 쟁점과 출처를 기록
- **보호 문서 수정** — ``.ai/project/scope.md`, `.ai/project/architecture.md`, `.ai/project/glossary.md`, `.ai/project/testing.md`, `.ai/project/roles/`, `.ai/project/workflows/``.
  에이전트가 근거로 읽는 문서이며 **사용자가 명시적으로 지시한 턴에서만** 고친다.
  요구가 이 문서들과 어긋나면 고치지 말고 보고한다.
  권한 설정과 명령 가드가 함께 막지만 **규칙이 우선이고 그 둘은 보조다**
- 결정을 고민한 흔적을 **현재형 산출물**(명세·분해·코드 주석)에 기재하는 것.
  **금지되는 것은 그 위치뿐이다** — 검토한 대안과 기각 근거는 **이슈와 리뷰 요청 본문**에 남기고,
  결정 기록을 쓰는 결정이면 `.ai/adr.md` 가 정한 대안 절에도 적는다
- **생성 파일 직접 수정** — `harness.toml` 에서 나오는 파일이다. 값을 고치고 `harness render`
  를 돌린다. 어긋난 채로 커밋하면 `harness check` 가 막는다

## 8. 검증 루프

1. 코드 변경
2. `script/run-lint-test.sh` 실행 — 생성물 일치 + 셸 회귀 테스트 + 프로젝트 검증
3. 통과 시에만 커밋. 실패 시 커밋하지 않고 실패 원인을 보고
4. 커밋 시 pre-commit 훅이 생성물 일치를 다시 검사 — **어긋나면 커밋이 차단된다**

훅 활성화는 클론 후 1회: `git config core.hooksPath script/githooks`

## 9. 문서 지도

| 문서 | 언제 읽는가 |
|---|---|
| `.ai/AI_AGENT.md` (이 파일) | 규칙·컨벤션·금지 사항 |
| `.ai/project/` | 이 프로젝트의 사실. 1~5장이 그 본문을 담고 있다 |
| `.ai/project/testing.md` | 테스트를 작성할 때 |
| `.ai/project/environment.md` | 도구·환경 변수·외부 시스템 접근이 필요할 때. **값은 없고 취득 경로만 있다** |
| `.ai/project/review-checks.md` | 이 리포 고유의 리뷰 점검 |
| `.ai/forge.md` | 이슈·리뷰 요청 명령이 필요할 때 |
| `.ai/adr.md` | 되돌리기 비싼 결정을 할 때. 과거 결정의 "왜" 를 찾을 때 |
| `.ai/workflows/` | 여러 역할을 엮는 작업 절차 |
| `.ai/templates/` | 역할 계약과 산출물 양식 |
| `docs/spec/` | 특정 기능을 구현할 때 |
| `docs/plan/<이슈번호>/` | 구현에 착수할 때 |
| `docs/workflow/` | 하네스가 어떻게 도는지, 무엇을 고쳐야 하는지 (사람용) |
| `script/README.md` | 자동화 스크립트를 추가·실행할 때 |
| `harness.toml` | 하네스 설정을 바꿀 때. **규칙 값의 정본** |

**근거 우선순위: `.ai/adr.md` 가 가리키는 결정 기록 > `.ai/project/` > `docs/spec/` > 대화.**
상위 근거와 어긋나는 내용을 하위 근거로 덮지 않는다. 충돌하면 임의 판단하지 말고
**사용자에게 올려 결정을 받는다.**

**단 이 순위는 "왜 그렇게 정했나" 에 대한 것이다.**
"지금 무엇이 사실인가"(도구 동작·경로·버전처럼 관측으로 확인되는 상태)는 현재형 문서가 갖는다.
결정 기록은 그 시점의 관측과 판단을 담은 로그이고, 사실이 나중에 달라져도 본문을 고치지 않는다.
결정 자체를 뒤집으려면 새 기록을 쓰고, 관측이 틀렸던 것뿐이면 현재형 문서를 고친다.

## 10. 하네스 배치

| 위치 | 성격 |
|---|---|
| `harness.toml` | 설정 정본. 규칙 값은 전부 여기 |
| `.ai/project/` | **소유** — 프로젝트가 쓰고 하네스 갱신이 건드리지 않는다 |
| `.ai/templates/`, `script/` | **관리** — 하네스 것. 갱신이 덮는다 |
| `.ai/AI_AGENT.md`, `.ai/workflows/`, `.ai/forge.md`, `.ai/adr.md`, `.claude/`, `.codex/`, `script/githooks/`, `script/harness.env`, `script/forge.sh` | **생성** — 설정에서 나온다 |
| `AGENTS.md`, `CLAUDE.md` | 정본으로 보내는 관문 |

**규칙·절차·역할 계약을 하네스 전용 디렉터리에 복사하지 않는다** — 사본은 정본 개정을
따라가지 못해 구버전 기준을 주입한다. 어댑터에는 도구 이름·권한 같은 결합 정보만 둔다.

역할이 무엇을 판단하고 무엇을 출력하는지는 `.ai/templates/<역할>.md` 가 정본이다.
계약은 **자기가 어떤 모델인지, 다음에 어느 역할이 도는지 모른다.** 그건 절차와 어댑터의 몫이다.
