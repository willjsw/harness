# #59 task

## T1 · refactor: doctor 점검을 항목 목록 수집과 텍스트 렌더로 나누고 status 가 그 목록을 씀

### 상위 Requirement

- relates to #59

### 작업 내용

`cmd_doctor` 의 점검을 표준 출력에 쓰지 않는 수집 함수 하나로 옮기고, 텍스트 출력은 그 목록을 그리게 한다.
`cmd_status` 는 doctor 의 표준 출력을 가로채 정규식으로 읽지 않고 수집 함수의 목록을 직접 쓴다. 출력과 종료 코드는 지금과 같다.

- 명세 2-1(수집) · 2-2 의 텍스트 행(요약 줄까지. `remote checks not run` 줄은 T6) · 2-3 의 첫째·셋째 항목 · 9-3(기존 케이스)
- 수집 함수는 `(cfg, target, remote)` 를 받아 `{"section", "state", "what", "detail"}` 목록을 돌려준다. `remote` 는 이 task 에서 받기만 하고 쓰지 않는다
- 절 순서는 `config` · `generated files` · `project facts` · `verification` · `references` · `tools and connections` · `registry` · `git`.
  항목이 없는 절은 그리지 않는다
- 수집 중에 띄우는 프로세스(검증 스크립트 등)의 출력은 지금처럼 받아 두고 표준 출력에 흘리지 않는다
- `cmd_status` 의 `doctor` 값(`bad` · `warn` · `items`)은 목록에서 만든다. `facts.filled` 는 지금처럼 `project facts` 절의 `ok` 가 아닌 항목으로 센다.
  docstring 의 "doctor 를 돌려 읽는다" 서술을 목록을 쓰는 동작으로 고친다
- `render-test.sh` 에 새 `UT-<번호>` 블록: 같은 리포에서 doctor 텍스트의 항목 줄과 `status` 의 `doctor.items` 가 같은 순서·같은 값인지,
  `status` 의 최상위 키 · `doctor` 의 키 · 항목의 키가 지금과 같은지 확인한다
- 건드릴 파일: `src/bin/harness`(`cmd_doctor` · `cmd_status`), `src/test/render-test.sh`

### 완료 조건

- [ ] doctor 의 점검이 표준 출력에 쓰지 않는 수집 함수 하나에 있고, `cmd_doctor` 는 그 목록을 그리기만 한다
- [ ] `cmd_status` 에 doctor 출력의 가로채기와 정규식 파싱이 없다
- [ ] 기존 doctor 텍스트 케이스(생성물 불일치 · 자리표시자 · 참조 · 검증 · worktree · registry)와 `status` 케이스가 문구를 바꾸지 않고 통과한다
- [ ] `status` 의 최상위 키 · `doctor` 키 · 항목 키가 지금과 같다
- [ ] doctor 의 종료 코드가 지금과 같다 — `bad` 가 하나라도 있으면 1, 아니면 0
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/59-doctor-remote-readiness` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 텍스트와 status 항목 일치 | 경고와 실패가 섞인 리포에서 `doctor` · `status` | `status` 의 `doctor.items` 가 텍스트 항목 줄과 같은 순서 · 같은 `section` · `state` · `what` · `detail` |
| UT-02 | status 키 구조 유지 | `status` | 최상위 키 · `doctor` 키(`bad` · `warn` · `items`) · 항목 키(`section` · `state` · `what` · `detail`)가 지금과 같다 |
| UT-03 | 설정 진행도 | 자리표시자가 남은 사실 문서 하나 | `facts.filled` 가 그 문서를 빼고 센다 |
| UT-04 | 종료 코드 | `bad` 항목이 있는 리포 · 없는 리포 | 각각 1 · 0 |
| UT-05 | 기존 케이스 | 기존 doctor · status 케이스 전부 | 문구 변경 없이 통과 |

## T2 · feat: doctor --json 출력 추가

### 상위 Requirement

- relates to #59

### 작업 내용

`harness doctor --json` 이 T1 의 항목 목록을 JSON 객체 하나로 내게 한다. 사람용 출력과 기계용 출력이 같은 목록에서 나온다.

- 명세 2-2 의 JSON 행과 아래 두 항목 · 2-3 의 "같은 조건의 `doctor --json` 과 같다" · 2-4 의 `--json`
- 표준 출력에 `{"bad": <수>, "warn": <수>, "items": [...]}` 하나만 낸다. 절 제목 · 안내 줄 · 요약 줄이 없다. 종료 코드는 텍스트 출력과 같다
- 인자 해석에 `--json` 을 더하고, `COMMANDS` 의 `doctor` 인수 칸을 `[--json]` 으로 둔다(`--remote` 는 T6). 고정 사본 위임에 인자가 그대로 넘어간다
- `render-test.sh` 에 새 `UT-<번호>` 블록
- 건드릴 파일: `src/bin/harness`(`cmd_doctor` · 인자 해석 · `COMMANDS`), `src/test/render-test.sh`

### 완료 조건

- [ ] `harness doctor --json` 의 표준 출력 전체가 JSON 객체 하나로 읽힌다
- [ ] 그 `items` 의 각 항목이 텍스트 출력의 항목 줄 하나와 대응하고, `bad` · `warn` 이 항목 수와 맞다
- [ ] 텍스트 출력과 JSON 출력의 종료 코드가 같다
- [ ] `harness status` 의 `doctor` 값이 같은 리포의 `harness doctor --json` 출력과 같다
- [ ] 고정 사본으로 위임되는 리포에서도 `--json` 이 동작한다
- [ ] 도움말의 `doctor` 인수 칸에 `--json` 이 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/59-doctor-remote-readiness` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | JSON 하나만 출력 | `doctor --json` | 표준 출력 전체가 `json.loads` 로 읽히고 키가 `bad` · `warn` · `items` |
| UT-02 | 텍스트와 대응 | 경고와 실패가 섞인 리포에서 `doctor` · `doctor --json` | 항목마다 텍스트의 한 줄과 같은 값, 개수 일치 |
| UT-03 | 종료 코드 일치 | `bad` 가 있는 리포 · 없는 리포 | 두 출력의 종료 코드가 각각 같다 |
| UT-04 | status 와 같음 | 같은 리포에서 `status` · `doctor --json` | `status` 의 `doctor` 값과 `doctor --json` 이 같다 |
| UT-05 | 위임 | 고정 사본이 있는 대상 리포에서 전역 CLI 로 `doctor --json` | JSON 객체 하나, 종료 코드는 고정 사본의 판정 |

## T3 · fix: 자리표시자·어댑터 미검증 판정을 정해진 표지로 좁힘

### 상위 Requirement

- relates to #59

### 작업 내용

doctor 가 본문에 `TBD` · `미검증` 이라는 낱말이 나오기만 해도 경고하던 판정을 정해진 표지로만 하게 한다.

- 명세 3절
- `project facts`: 파일 본문의 `<!-- TBD` 출현 수로 센다. `detail` 문구 `<N> placeholder(s) still to fill` 는 그대로다
- `tools and connections` 의 어댑터 미검증: 어댑터 파일의 머리글(1행부터 `#` 로 시작하는 줄이 이어지는 첫 주석 덩어리)에 `검증 상태: 미검증` 이
  있을 때만. 머리글 표지 문자열은 `src/bin/harness` 의 상수 하나가 갖는다. `detail` 문구는 그대로다
- `src/templates/managed/script/forge/_common.sh` 상단 계약 주석에 명세 3절의 머리글 표지 문장을 둔다
- `src/ui/lib/doctor.js` 가 자리표시자 · 미검증 안내에서 판정 기준을 설명하면 표지 기준으로 맞춘다
- `render-test.sh` 에 새 `UT-<번호>` 블록
- 건드릴 파일: `src/bin/harness`(T1 의 수집 함수), `src/templates/managed/script/forge/_common.sh`, `src/test/render-test.sh`, 필요하면 `src/ui/lib/doctor.js`

### 완료 조건

- [ ] `.ai/project/` 문서의 `<!-- TBD` 를 모두 채우고 본문에 낱말 `TBD` 만 남기면 그 문서 줄이 `ok` 다
- [ ] `<!-- TBD` 가 두 곳이면 `2 placeholder(s) still to fill` 이다
- [ ] 머리글에 표지가 없는 어댑터의 본문 주석 · 코드에 `미검증` 이 있어도 어댑터 줄이 `ok` 다
- [ ] 머리글에 `검증 상태: 미검증` 이 있는 어댑터는 지금과 같은 `warn` 이다
- [ ] 머리글 표지 문자열이 `src/bin/harness` 의 상수 하나에만 있다
- [ ] `_common.sh` 상단에 머리글 `검증 상태:` 줄이 검증 상태의 표지라는 계약 문장이 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/59-doctor-remote-readiness` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 낱말 TBD 는 세지 않음 | 사실 문서의 `<!-- TBD` 를 모두 채우고 본문에 `TBD` 낱말만 남김 | 그 문서 줄 `ok` |
| UT-02 | 자리표시자 수 | `<!-- TBD` 두 곳 | `warn` · `2 placeholder(s) still to fill` |
| UT-03 | 본문의 미검증은 무시 | 머리글에 표지가 없는 어댑터의 본문 주석에 `미검증` | 어댑터 줄 `ok` |
| UT-04 | 머리글 표지 | 머리글에 `검증 상태: 미검증` | 어댑터 줄 `warn`, detail 이 지금과 같다 |
| UT-05 | 머리글 경계 | 첫 주석 덩어리 뒤 빈 줄 다음의 주석에 `검증 상태: 미검증` | 어댑터 줄 `ok` |

## T4 · feat: 벤더 auth_check 선언과 run-agent.py --check 러너 준비 확인 추가

### 상위 Requirement

- relates to #59

### 작업 내용

역할을 실행하지 않고 그 역할의 CLI 러너가 설치 · 로그인되어 있는지 보는 공용 진입점 `script/run-agent.py <역할> --check` 를 만든다.
로그인 확인 명령은 벤더 선언의 `auth_check` 가 갖고 실행 계획으로 내려간다. doctor 의 리뷰어 러너 점검(T8)과 리뷰 루프의 러너 사전 점검이 이 진입점을 함께 쓴다.

- 명세 5절 · 9-1 의 `run-agent.py --check` 표 · 렌더 결과 · 벤더 선언 검사
- `src/templates/vendors.toml`: 선택 키 `auth_check`. `claude` 는 `["claude", "auth", "status"]`, `codex` 는 `["codex", "login", "status"]`, 그 밖은 적지 않는다.
  머리 주석의 키 설명에 `auth_check` 한 줄
- 선언 읽기: `auth_check` 가 있는데 비어 있거나 문자열 목록이 아니거나 첫 원소가 `exe` 와 다르면 `die`
- `run_plan()`: `via = headless` 역할마다 `auth_check`(없으면 빈 목록)를 싣는다. render 로 `script/harness.plan.json` 을 다시 만든다
- `run-agent.py --check`: 명세 5-3 표의 종료 코드 0 · 2 · 3 · 4 와 출력. `auth_check` 는 제한 시간 30초, 표준 입력을 닫고 표준 출력 · 표준 오류를 버린다.
  실행 지표 스팬과 사용 기록을 남기지 않는다. `--out` · `--prompt` · 입력과 함께 주면 `--check` 만 본다. 머리 docstring 의 사용법과 종료 코드에 `--check` 를 더한다
- `render-test.sh` 에 새 `UT-<번호>` 블록: 손으로 쓴 실행 계획과 `PATH` 의 `codex` 스텁(종료 코드를 환경 변수로 정한다)을 쓴다
- 건드릴 파일: `src/templates/vendors.toml`, `src/bin/harness`(벤더 선언 읽기 · `run_plan()`), `src/templates/managed/script/run-agent.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 렌더한 `script/harness.plan.json` 의 CLI 러너 역할마다 `auth_check` 가 있고, codex 러너면 `["codex", "login", "status"]` 다
- [ ] `auth_check` 의 첫 원소가 `exe` 와 다른 선언, 빈 목록, 문자열 목록이 아닌 값이면 렌더가 멈춘다
- [ ] `--check` 가 명세 5-3 표의 상황마다 정해진 종료 코드와 출력을 낸다
- [ ] `auth_check` 명령이 낸 출력이 `--check` 의 출력에 옮겨지지 않는다
- [ ] `--check` 가 실행 지표 스팬과 사용 기록을 남기지 않는다
- [ ] `--check` 없는 `run-agent.py` 의 동작이 지금과 같다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/59-doctor-remote-readiness` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 로그인됨 | `codex` 스텁이 `login status` 에 0 | 종료 코드 0, 표준 출력 `signed-in` |
| UT-02 | 미로그인 | 스텁이 1 과 표준 출력에 표지 문자열 | 종료 코드 3, 표준 오류에 `is not signed in`, 표지 문자열이 어디에도 없다 |
| UT-03 | 확인 선언 없음 | 실행 계획의 `auth_check` 가 빈 목록 | 종료 코드 0, `unchecked`, 스텁이 불리지 않는다 |
| UT-04 | 실행 불가 | 서브에이전트 역할 · `PATH` 에 없는 실행 파일 · 실행 계획 없음 | 종료 코드 2, 표준 오류 `error:` |
| UT-05 | 확인 못 함 | 실행 파일이지만 없는 인터프리터를 가리키는 스텁(띄우지 못함) | 종료 코드 4, `could not check sign-in for` |
| UT-06 | 지표 없음 | `--check` 한 번 | 지표 디렉터리에 새 스팬 · 사용 기록 없음 |
| UT-07 | 다른 인자와 함께 | `--check --out <파일> --prompt x` | `--check` 결과만, `<파일>` 이 생기지 않는다 |
| UT-08 | 렌더 결과 | codex 러너 역할이 있는 설정으로 render | 실행 계획의 그 역할에 `["codex", "login", "status"]` |
| UT-09 | 선언 검사 | 첫 원소가 `exe` 와 다른 `auth_check` 선언 | render 가 멈춘다 |

## T5 · feat: forge 읽기 함수 넷과 자체 검사·페이크 추가

### 상위 Requirement

- relates to #59

### 작업 내용

원격 점검이 forge 를 어댑터 함수로만 읽도록 로그인 확인 · 라벨 목록 · 브랜치 보호 조회 함수를 계약에 더하고, 세 어댑터 · 자체 검사 · 페이크에 구현한다.

- 명세 6절 · 9-2
- `_common.sh` 상단 계약: 트래커 군 `tracker_auth` · `tracker_labels`, 리뷰 호스트 군 `review_auth` · `review_branch_protected <브랜치>`. 넷 모두 읽기만 한다
- 어댑터 구현은 명세 6-2 표대로. `*_auth` 는 CLI 출력을 버리고 종료 코드로 가르며, 실패 안내는 어댑터가 정한 고정 문구 한 줄이다
- `gitlab.sh` · `jira.sh` 의 머리글 `검증 상태: 미검증` 을 유지한다
- `github.sh`: `forge-selftest.sh` 읽기 단계를 실제 GitHub 리포로 통과시킨 뒤 머리글의 검증 상태 줄을 그 실행의 gh 버전으로 고친다
- `forge-selftest.sh` 읽기 단계에 명세 6-3 의 네 검사를 더한다. `BASE_BRANCH` 는 이미 읽는 `script/harness.env` 의 값이다
- `fake-forge.sh`: 네 함수와 `FAKE_AUTH` · `FAKE_LABELS` · `FAKE_PROTECTED`, `FAKE_BREAK` 의 `labels` · `protected`
- `render-test.sh` 에 새 `UT-<번호>` 블록: 기존 자체 검사 케이스와 같은 방식으로 페이크를 끼워 네 검사의 통과와 두 계약 위반의 검출을 본다
- 건드릴 파일: `src/templates/managed/script/forge/_common.sh` · `github.sh` · `gitlab.sh` · `jira.sh`, `src/templates/managed/script/forge-selftest.sh`,
  `src/test/fake-forge.sh`, `src/test/render-test.sh`

### 완료 조건

- [ ] `_common.sh` 상단에 네 함수의 계약이 명세 6-1 대로 있다
- [ ] 세 어댑터가 명세 6-2 표대로 네 함수를 갖고(Jira 는 리뷰 호스트 함수 없음), 어느 함수도 forge 에 쓰지 않는다
- [ ] 인증 실패 안내가 CLI 출력이 아닌 어댑터의 고정 문구 한 줄이다
- [ ] 페이크를 끼운 `forge-selftest.sh` 가 네 검사를 통과하고, `FAKE_BREAK=labels` · `FAKE_BREAK=protected` 를 계약 위반으로 잡는다
- [ ] 실제 GitHub 리포에서 `forge-selftest.sh` 읽기 단계가 통과하고, `github.sh` 머리글 검증 상태 줄이 그 gh 버전이다
- [ ] `gitlab.sh` · `jira.sh` 머리글에 `검증 상태: 미검증` 이 남아 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/59-doctor-remote-readiness` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 자체 검사 통과 | 페이크 기본값 | `tracker_auth` · `review_auth` · `tracker_labels` · `review_branch_protected <BASE_BRANCH>` 통과 |
| UT-02 | 라벨을 두지 않는 트래커 | `FAKE_LABELS=none` | `tracker_labels` 가 종료 코드 3 과 빈 출력, 자체 검사 통과 |
| UT-03 | 라벨 계약 위반 | `FAKE_BREAK=labels` | 자체 검사가 `tracker_labels` 를 실패로 보고 |
| UT-04 | 보호 계약 위반 | `FAKE_BREAK=protected` | 자체 검사가 `review_branch_protected` 를 실패로 보고 |
| UT-05 | 인증 실패 | `FAKE_AUTH=fail` | 인증 함수가 종료 코드 1 과 표준 오류 안내 한 줄 |
| UT-06 | 보호 브랜치 | `FAKE_PROTECTED=<base>` | `<base>` 는 `true`, 그 밖은 `false` |

## T6 · feat: doctor --remote 와 origin·base·원격 기본 브랜치 점검 추가

### 상위 Requirement

- relates to #59

### 작업 내용

`harness doctor --remote` · `harness status --remote` 를 받아 `remote` 절을 만들고, 그 첫 항목으로 origin · base 브랜치 · 원격 기본 브랜치를 점검한다.
원격 호출 공통 규칙을 한 곳에 두어 T7 · T8 이 같이 쓴다.

- 명세 1절 · 2-2 의 `remote checks not run` 줄 · 2-3 의 `--remote` 전달 · 2-4 의 `--remote` · 4-1 · 4-2 의 앞 세 항목과 등급 기준 · 4-3 의 첫째 · 둘째 항목 · 9-1 의 해당 케이스
- 수집 함수가 `remote` 가 참일 때만 `remote` 절 항목을 낸다. 거짓이면 텍스트 출력에만 요약 줄 앞에 `` remote checks not run — use `harness doctor --remote` `` 한 줄을 낸다.
  이 줄은 항목이 아니며 JSON · `status` · 개수에 들어가지 않는다
- 원격 호출 공통: 호출마다 제한 시간 30초, 표준 입력을 닫고 git 호출에 `GIT_TERMINAL_PROMPT=0`. 제한 시간 초과 · 실행 실패 · 해석할 수 없는 응답은 `warn` `could not check`.
  원격 URL 과 CLI 출력을 `what` · `detail` 에 옮기지 않는다
- ls-remote 는 `git ls-remote --symref origin HEAD refs/heads/<b>...` 한 번. `<b>` 는 `PROTECTED_BRANCHES` 전부(base 포함). 결과를 T7 의 브랜치 보호 점검이 함께 쓴다
- ``remote `origin` `` 이 `bad` 면 뒤의 git 항목을 내지 않는다
- `cmd_status` 는 `--remote` 를 수집 함수에 넘긴다. `COMMANDS` 인수 칸은 `doctor` `[--remote] [--json]`, `status` `[--remote]`
- `doctor --remote` 는 실행 지표를 남기지 않는다
- `render-test.sh` 에 새 `UT-<번호>` 블록: 원격은 테스트 작업 디렉터리 아래의 bare 리포
- 건드릴 파일: `src/bin/harness`(수집 함수 · 텍스트 렌더 · `cmd_status` · 인자 해석 · `COMMANDS`), `src/test/render-test.sh`

### 완료 조건

- [ ] `--remote` 없는 doctor 에 `remote` 절이 없고 `remote checks not run` 줄이 있으며, origin 을 닿지 않는 주소로 둬도 결과가 같다
- [ ] `--remote` 없는 `status` 의 `doctor.items` 에 `section` 이 `remote` 인 항목이 없고, `remote checks not run` 이 JSON 출력 어디에도 없다
- [ ] 명세 4-2 의 ``remote `origin` `` · ``branch `<base>` on origin`` · `origin default branch` 가 상황마다 정해진 상태와 `detail` 이다
- [ ] origin 이 없으면 base · 기본 브랜치 줄이 없고 종료 코드 1 이다
- [ ] 닿지 않는 origin 에서 base 줄이 `warn` `could not check` 이고, origin 주소에 넣은 표지 문자열이 텍스트 · JSON 출력에 없다
- [ ] 자격증명을 묻는 원격에서도 doctor 가 입력을 기다리며 멈추지 않는다
- [ ] `status --remote` 의 `doctor` 값이 `doctor --remote --json` 과 같다
- [ ] `doctor --remote` 가 실행 지표를 남기지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/59-doctor-remote-readiness` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 원격 없이 | `doctor` · `status`, origin 을 닿지 않는 경로로 둔 경우 포함 | `remote` 절 없음, `remote checks not run` 줄 있음, 두 결과 같음, `status` 에 `remote` 항목 없음 |
| UT-02 | git 리포가 아님 | git 작업 트리가 아닌 하네스 루트에서 `doctor --remote` | ``remote `origin` `` `FAIL` `not a git repository` |
| UT-03 | origin 없음 | origin 을 지운 리포 | ``remote `origin` `` `FAIL`, base · 기본 브랜치 줄 없음, 종료 코드 1 |
| UT-04 | base 가 원격에 없음 | base 를 push 하지 않은 bare 원격 | ``branch `<base>` on origin`` `FAIL` ``missing — run `git push origin <base>` `` |
| UT-05 | 준비됨 | base 를 push 하고 bare 원격 `HEAD` 가 base | base 줄 `ok`, `origin default branch` `ok` `` `<base>` `` |
| UT-06 | 기본 브랜치가 다름 | bare 원격 `HEAD` 를 다른 브랜치로 | `origin default branch` `warn`, detail 에 그 브랜치 이름 |
| UT-07 | 닿지 않는 원격 | origin 이 닿지 않는 주소(표지 문자열 포함) | base 줄 `warn` `could not check — git ls-remote failed`, 표지 문자열이 출력에 없다 |
| UT-08 | status 전달 | `status --remote` · `doctor --remote --json` | 두 `doctor` 값이 같다 |
| UT-09 | 지표 없음 | `doctor --remote` | 새 스팬 없음 |

## T7 · feat: doctor --remote 에 forge 로그인·라벨·브랜치 보호 점검 추가

### 상위 Requirement

- relates to #59

### 작업 내용

`remote` 절에 forge 로그인 · 트래커 라벨 · 원격 브랜치 보호 항목을 더한다. forge 는 T5 의 어댑터 함수로만 읽는다.

- 명세 4-2 의 ``sign-in to `<kind>` `` · ``label `<L>` `` · `labels` · ``branch protection `<b>` `` 행 · 4-3 의 셋째 · 넷째 항목 · 4-4 · 4-5 · 4-6 · 9-1 의 해당 케이스
- 대상 forge 종류는 `[forge.tracker, forge.review_host]` 에서 중복을 뺀 순서. 트래커는 `tracker_auth`, 리뷰 호스트는 `review_auth`, 같은 종류면 `tracker_auth` 한 번.
  종료 코드 0 `ok`, 1 `bad` ``not signed in — <표준 오류 첫 줄>``, 그 밖 `warn` `could not check`
- `forge CLI` 가 `bad` 인 종류, 로그인이 `ok` 가 아닌 종류는 그 종류의 뒤 항목을 내지 않는다
- 라벨: `issues.labels` 의 빈 문자열이 아닌 값, 중복을 뺀 설정 순서. 대소문자를 가리지 않고 비교한다. 종료 코드 3 이면 라벨 항목 없음, 그 밖의 실패 · 배열이 아닌 출력이면 `labels` `warn` `could not check` 한 줄
- 브랜치 보호: 보호 브랜치 중 T6 의 ls-remote 가 origin 에 있다고 낸 것만. `true` `ok`, `false` `warn`, 그 밖 `warn` `could not check`
- 어댑터 함수 호출에도 T6 의 원격 호출 공통 규칙을 쓴다
- `render-test.sh` 에 새 `UT-<번호>` 블록: `script/forge.sh` 를 `fake-forge.sh` 로 바꿔 끼우고, forge CLI 설치 확인을 지나도록 `PATH` 앞에 빈 `gh` 스텁을 둔다
- 건드릴 파일: `src/bin/harness`(수집 함수), `src/test/render-test.sh`

### 완료 조건

- [ ] forge 종류마다 로그인 줄 하나가 명세 4-4 대로 나오고, 미로그인의 `detail` 에 어댑터 안내 줄이 있다
- [ ] 미로그인 · forge CLI 미설치인 종류에 라벨 · 브랜치 보호 줄이 없다
- [ ] 설정 라벨 중 트래커에 없는 것만 `warn` 이고, 대소문자만 다른 라벨은 `ok` 다
- [ ] 라벨 조회가 종료 코드 3 이면 라벨 줄이 없고, 배열이 아닌 응답이면 `labels` `warn` `could not check` 한 줄이다
- [ ] 보호 여부에 따라 브랜치 보호 줄이 `ok` · `warn` 이고, origin 에 없는 보호 브랜치는 줄이 없다
- [ ] `src/bin/harness` 가 `gh` · `glab` · `jira` 를 직접 부르지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/59-doctor-remote-readiness` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | forge 미인증 | `FAKE_AUTH=fail` | ``sign-in to `<kind>` `` `FAIL`, detail 에 페이크 안내 줄, 라벨 · 브랜치 보호 줄 없음 |
| UT-02 | 로그인됨 | 페이크 기본값 | 로그인 줄 `ok` |
| UT-03 | 라벨 하나 없음 | `FAKE_LABELS` 가 설정 라벨 하나를 뺌 | 그 라벨만 `warn` ``missing on <tracker> — create it on the forge`` |
| UT-04 | 대소문자 | `FAKE_LABELS` 가 설정 라벨을 대소문자만 바꿔 냄 | 그 라벨 `ok` |
| UT-05 | 라벨을 두지 않는 트래커 | `FAKE_LABELS=none` | 라벨 줄 없음 |
| UT-06 | 라벨 응답 이상 | `FAKE_BREAK=labels` | `labels` `warn` `could not check` 한 줄 |
| UT-07 | 브랜치 보호 | `FAKE_PROTECTED=<base>` · 비움 | 각각 `ok` ``protected on <host>`` · `warn` ``not protected on <host> …`` |
| UT-08 | 원격에 없는 보호 브랜치 | base 만 push 한 bare 원격 | base 외 보호 브랜치 줄 없음 |
| UT-09 | 보호 응답 이상 | `FAKE_BREAK=protected` | 브랜치 보호 줄 `warn` `could not check` |

## T8 · feat: doctor --remote 에 리뷰어 러너 점검 추가

### 상위 Requirement

- relates to #59

### 작업 내용

`remote` 절에 리뷰어(`roles.code-reviewer`) 러너의 설치 · 로그인 항목을 더한다. 판정은 T4 의 `script/run-agent.py code-reviewer --check` 에 맡긴다.

- 명세 4-2 의 ``reviewer runner `<vendor>` `` 행과 등급 기준 · 4-7 · 9-1 의 리뷰어 러너 케이스
- `run_plan()` 에서 그 역할이 `via = subagent` 면 항목을 내지 않는다. CLI 러너면 `--check` 를 불러 명세 4-7 표대로 가른다. `<vendor>` 는 러너의 벤더 id
- `script/run-agent.py` 가 없으면 `bad` `` `script/run-agent.py` is missing — run `harness render` ``
- `--check` 호출에도 T6 의 원격 호출 공통 규칙(제한 시간 · 표준 입력 · 출력 비전달)을 쓴다
- `render-test.sh` 에 새 `UT-<번호>` 블록: 리뷰어 러너는 `PATH` 의 `codex` 스텁
- 건드릴 파일: `src/bin/harness`(수집 함수), `src/test/render-test.sh`

### 완료 조건

- [ ] CLI 러너 리뷰어의 `--check` 결과마다 명세 4-7 표의 상태와 `detail` 이 나온다
- [ ] `roles.code-reviewer.runner = inproc` 이면 리뷰어 러너 줄이 없다
- [ ] `script/run-agent.py` 가 없으면 `FAIL` 과 `harness render` 안내다
- [ ] 러너 CLI 의 출력이 doctor 출력에 옮겨지지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/59-doctor-remote-readiness` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 로그인됨 | `codex` 스텁이 `login status` 에 0 | ``reviewer runner `codex` `` `ok` `signed in` |
| UT-02 | 미로그인 | 스텁이 1 과 표준 출력에 표지 문자열 | `FAIL` ``not signed in — `codex login status` fails``, 표지 문자열이 출력에 없다 |
| UT-03 | 미설치 | `PATH` 에 스텁 없음 | `FAIL`, detail 이 `--check` 표준 오류 첫 줄에서 `error: ` 를 뗀 것 |
| UT-04 | 서브에이전트 리뷰어 | `roles.code-reviewer.runner = inproc` | 리뷰어 러너 줄 없음 |
| UT-05 | 실행기 없음 | `script/run-agent.py` 삭제 | `FAIL` `` `script/run-agent.py` is missing — run `harness render` `` |
| UT-06 | 확인 선언 없음 | 실행 계획의 `auth_check` 를 빈 목록으로 | `ok` ``installed — sign-in is not checked for <벤더 name>`` |

## T9 · feat: UI Doctor 에 원격 점검 버튼과 원격 절 문구 추가

### 상위 Requirement

- relates to #59

### 작업 내용

UI Doctor 화면에서 버튼을 눌렀을 때만 `harness status --remote` 를 돌리고, `remote` 절 줄을 한국어 항목으로 옮긴다. 홈과 사이드바는 원격을 점검하지 않는다.

- 명세 7절 · 9-4
- `readStatus(dir, remote = false)` · `projectStatus(project, remote = false)` · `loadStatus(project, fresh = false, remote = false)`. `remote` 가 참이면 언제나 새로 돌리고,
  캐시는 마지막 결과 하나를 갖고 구독자에게 알린다. `HomeGrid` 와 사이드바는 `remote` 를 넘기지 않는다
- `DoctorView`: 요약 카드의 `Run again` 옆에 `원격까지 점검`. 한 번 돌린 뒤의 `Run again` 은 원격까지, 화면을 새로 열면 원격 없이. 원격 절 항목이 없을 때의 안내 한 줄,
  원격 결과가 `null` 일 때 이전 결과를 두고 옛 버전 안내 — 문구는 명세 7-2 원문
- `src/ui/lib/doctor.js`: `SECTIONS.remote = "원격"`, `explain()` 이 명세 7-3 표의 줄을 옮긴다
- `doctor.test.js` 에 명세 9-4 의 케이스
- 건드릴 파일: `src/ui/lib/harness.js`, `src/ui/lib/actions.js`, `src/ui/lib/status-cache.js`, `src/ui/components/DoctorView.js`, `src/ui/lib/doctor.js`, `src/ui/lib/doctor.test.js`

### 완료 조건

- [ ] `remote` 가 참일 때만 `harness status --remote` 가 불리고, 홈 · 사이드바 경로에서는 불리지 않는다
- [ ] `원격까지 점검` 을 누르면 원격 결과가 보이고, 그 뒤 `Run again` 이 원격까지 다시 돌린다. 화면을 새로 열면 원격 없이 시작한다
- [ ] 원격 절 항목이 없는 결과에서 명세 7-2 의 안내 한 줄이 보인다
- [ ] 원격 결과가 `null` 이면 이전 결과가 남고 옛 버전 안내가 보인다
- [ ] `explain()` 이 명세 7-3 표의 줄마다 원문과 다른 제목과 표의 조치를 낸다
- [ ] UI 가 설정 경로를 짓지 않고 CLI 명령만 부른다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/59-doctor-remote-readiness` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 절 이름 | `SECTIONS.remote` | `"원격"` |
| UT-02 | origin 없음 | ``remote `origin` `` · `not set …` 줄 | 한국어 제목, 조치 `cmd` `git remote add origin <url>` |
| UT-03 | base 없음 | ``branch `<base>` on origin`` · `missing …` 줄 | 조치 `cmd` `git push origin <base>` |
| UT-04 | 기본 브랜치가 다름 | `origin default branch` · `is …` 줄 | detail 의 브랜치 이름을 담은 항목, 조치 `href` Harness 설정 화면 |
| UT-05 | forge 미인증 | ``sign-in to `github` `` · ``not signed in — run `gh auth login` `` 줄 | 조치 `cmd` `gh auth login` |
| UT-06 | 라벨 · 브랜치 보호 | 라벨 `missing …` · 보호 `not protected …` 줄 | 각각 한국어 항목, 조치 없음 |
| UT-07 | 리뷰어 러너 | ``reviewer runner `codex` `` `bad` 줄 | detail 을 담은 항목, 조치 `href` Agents 화면 |
| UT-08 | 확인 못 함 | detail 이 `could not check` 로 시작하는 `remote` 줄 | 확인하지 못했다는 항목 |
| UT-09 | git 리포 아님 | ``remote `origin` `` · `not a git repository` 줄 | 원격을 점검할 수 없다는 항목, 조치 없음 |

## T10 · docs: README 와 스크립트 표에 원격 점검·러너 준비 확인·자체 검사 종수 반영

### 상위 Requirement

- relates to #59

### 작업 내용

T5 ~ T9 가 만든 동작을 사람용 문서에 적는다.

- 명세 8절
- `README.md`: "명령" 의 `harness doctor`(`--remote` · `--json`) · `harness status`(`--remote`), "시작하기" 의 `harness doctor --remote`, "UI" 의 Doctor 행,
  "지원 범위" 의 자체 검사 읽기 종수와 GitHub 통과 종수(넷만큼)
- `src/templates/managed/script/README.md`: `forge-selftest.sh` 행의 읽기 종수(넷만큼), `run-agent.py` 행 추가(`--check` 종료 코드 0 · 2 · 3 · 4)
- 정본을 고친 뒤 render 로 이 리포의 `script/README.md` 를 갱신한다
- 건드릴 파일: `README.md`, `src/templates/managed/script/README.md`

### 완료 조건

- [ ] `README.md` 의 네 곳에 명세 8절의 사실이 있다
- [ ] 자체 검사 종수가 T5 가 더한 검사 수와 맞다
- [ ] `script/README.md` 에 `run-agent.py` 행과 `--check` 종료 코드 설명이 있고, `forge-selftest.sh` 행의 종수가 맞다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/59-doctor-remote-readiness` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | render 뒤 `harness check` | 통과 — `script/README.md` 사본이 정본과 같다 |
| UT-02 | 문서 검증 | `script/run-lint-test.sh` | 통과 |

## T11 · docs: 아키텍처 문서에 doctor 결과 목록과 원격 점검 입력 반영

### 상위 Requirement

- relates to #59

### 작업 내용

보호 문서 `.ai/project/architecture.md` 에 명세 10절의 두 사실을 적는다. 보호 문서이므로 사람이 지시한 턴에서만 고친다.

- 명세 10절
- "구성 요소" 의 `src/bin/harness`: doctor 는 점검 결과를 항목 목록으로 모으고 텍스트 · JSON 으로 그린다. `status` 는 그 목록을 쓴다
- "신뢰 경계" 의 들어오는 입력: `doctor --remote` 가 읽는 git · forge · 러너 CLI 의 응답. 원격 점검은 읽기 전용이고 원격 URL 과 CLI 출력을 결과에 옮기지 않는다
- render 로 `.ai/AI_AGENT.md` 를 다시 만든다
- 건드릴 파일: `.ai/project/architecture.md`

### 완료 조건

- [ ] `.ai/project/architecture.md` 의 두 위치에 명세 10절의 사실이 있다
- [ ] render 뒤 `.ai/AI_AGENT.md` 5장에 같은 문장이 있다
- [ ] 사람이 지시한 턴에서 고쳤다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/59-doctor-remote-readiness` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | render 뒤 `harness check` | 통과 — `.ai/AI_AGENT.md` 가 `.ai/project/` 와 맞다 |
