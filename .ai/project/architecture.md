<!--
이 파일은 프로젝트가 소유한다. 하네스 갱신이 덮지 않는다.
**보호 문서다** — 에이전트가 근거로 읽고 스스로 고치지 못한다.

실제 디렉터리 구조에서 읽어낸 것만 적는다. 없는 구조를 지어내지 않는다.
-->

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
