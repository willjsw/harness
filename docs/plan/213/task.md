# #213 task

## T1 · chore: 관리 스크립트 셸 회귀 테스트의 준비부를 하네스 루트 샌드박스로 전환

### 상위 Requirement

- relates to #213

### 작업 내용

관리 스크립트를 shim 으로 바꾸기 전에 셸 회귀 테스트의 준비부를 옛 스크립트와 shim 양쪽에서 같은 결과를 내는 형태로 바꾼다.
케이스와 기대값은 그대로 두고 **옛 스크립트로 통과시킨다**. 관리 스크립트와 CLI 코드는 고치지 않는다.

- 명세 10-1(준비부를 고치는 규칙) · 10-2
- 샌드박스 하네스 루트: 스크립트를 복사해 두는 임시 리포마다 아래를 갖춘다
  - `harness.toml` — 테스트를 부른 하네스 루트의 설정과 같은 값. 케이스가 값을 바꾸면 `harness.toml` 과 `script/harness.env` 에 같은 값을 둔다
  - 테스트를 부른 하네스 루트의 CLI 를 가리키는 `.harness/bin/harness` 링크 — 샌드박스의 하네스 루트에서 CLI 를 찾을 수 있다
  - forge 페이크: 페이크 파일을 지금처럼 `script/forge.sh` 자리에 두고, 같은 파일의 절대 경로를 그 스크립트 실행의 환경에
    `HARNESS_FORGE_FAKE` 로 준다(#209 4절). 테스트 전체에 내보내지 않는다
  - 역할 러너 · 지표 설정이 필요한 준비부는 샌드박스에 설치한 고정 사본의 벤더 선언 사본(`.harness/templates/vendors.toml`)과 샌드박스
    `harness.toml` 로 상황을 만든다. 실행 계획 JSON 을 내는 페이크 CLI 에 기대지 않는다
- `test-carryover-issue.sh` · `test-rollback-work.sh`: 임시 리포를 위 샌드박스 하네스 루트로 바꾼다
- `test-usage-log.sh`: 바꾼 설정 케이스(`stage_recorder` — 보호 브랜치 · 커밋 태그를 바꾼 설정, 빈 설정)를 위 샌드박스 하네스 루트로 바꾼다.
  "설정 없음" 케이스의 샌드박스는 `harness.toml` · `script/harness.env` 둘 다 없고 CLI 링크는 있다
- #210 · #211 의 셸 테스트(`test-bash-guard.sh` · `test-work-preflight.sh` · `test-review-loop.sh` · `test-sync-task-issues.sh`) 가운데
  `usage-log.sh` · `usage-vocab.sh` · `metric.py` · `run-agent.py` 를 샌드박스에 복사해 쓰는 준비부를 같은 규칙으로 고친다
- `src/bin/harness render` 로 이 리포의 `script/test-*.sh` 사본과 `.harness/managed` 를 갱신한다
- 건드릴 파일: `src/templates/managed/script/test-carryover-issue.sh` · `test-rollback-work.sh` · `test-usage-log.sh`, 위 준비부가 있는
  #210 · #211 셸 테스트, render 로 갱신되는 `script/` · `.harness/managed`

### 완료 조건

- [ ] `test-carryover-issue.sh`(UT-01~08) · `test-rollback-work.sh`(UT-01~08) · `test-usage-log.sh` 의 케이스와 기대값이 그대로이고 옛 스크립트로 모두 통과한다
- [ ] 이월 이슈 · 되감기 테스트에서 스크립트를 부르는 실행마다 환경에 `HARNESS_FORGE_FAKE` 가 있고, 그 값이 `script/forge.sh` 자리의 페이크와 같은 파일이다
- [ ] 샌드박스마다 `harness.toml` 이 있고 그 하네스 루트에서 `.harness/bin/harness` 로 CLI 를 찾을 수 있다. "설정 없음" 샌드박스에는 `harness.toml` · `script/harness.env` 가 없다
- [ ] 값을 바꾼 샌드박스에서 `harness.toml` 과 `script/harness.env` 의 보호 브랜치 · 커밋 태그 · 사용 기록 경로가 같다
- [ ] 고친 #210 · #211 셸 테스트가 기대값 그대로 통과한다
- [ ] 관리 스크립트(`src/templates/managed/script/` 의 `test-*.sh` 가 아닌 파일)와 `src/harness/` 가 바뀌지 않는다
- [ ] 고친 셸 테스트 전부와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 이월 이슈 테스트의 새 준비부 | 샌드박스 하네스 루트와 두 경로로 넣은 페이크로 `script/test-carryover-issue.sh` | UT-01~08 기대값 그대로 통과 |
| UT-02 | 되감기 테스트의 새 준비부 | 같은 준비부로 `script/test-rollback-work.sh` | UT-01~08 기대값 그대로 통과 |
| UT-03 | 바꾼 설정의 브랜치 유형 | 보호 브랜치 `release trunk` · 커밋 태그 `work\|hotfix\|spike` 를 `harness.toml` 과 `harness.env` 에 둔 샌드박스 | 기존 기대값(바꾼 값을 따른 브랜치 유형) 그대로 |
| UT-04 | 설정 없음 | `harness.toml` · `harness.env` 가 없는 샌드박스에서 `usage-log.sh note test-caller standalone` | 0, 출력 없음, 기록 없음 |
| UT-05 | #210 · #211 셸 테스트 | 고친 준비부 | 기대값 그대로 통과 |

## T2 · chore: 회귀 테스트의 검증 · 지표 · 역할 실행기 준비부를 설치한 리포 기준으로 전환

### 상위 Requirement

- relates to #213

### 작업 내용

`src/test/render-test.sh` 에서 관리 스크립트를 리포 밖으로 복사하거나 스크립트 일부를 잘라 돌던 준비부를, 설치한 리포의 진입점을 부르는
형태로 바꾼다. 옛 스크립트와 shim 양쪽에서 같은 결과를 내는 형태이고 **옛 스크립트로 통과시킨다**. 기대값은 바꾸지 않는다.

- 명세 10-1 · 10-4 의 준비부 행
- UT-53: `run-lint-test.sh` 의 옛 검증 분기를 `sed` 로 잘라 돌던 준비부 → 생성물 검사를 통과하는 상태에서 `script/run-lint-test.sh` 를
  돌려 채운 `script/verify-project.sh` 가 도는지 본다. 같은 블록의 `script/harness-verify.sh` 내용 검사(`step '테스트'`)는 T12 가 바꾼다
- UT-107: `script/metric.py` 를 다른 디렉터리에 복사해 쓰던 준비부 → 설치한 리포의 `script/metric.py`. 클론 키 모듈 없이 복사한 사본이
  기록하지 않음을 보는 줄은 T10 이 지운다
- UT-80: `run-agent.py` · `metric.py` 사본을 다른 디렉터리에 두던 준비부 → 그 디렉터리를 하네스 루트로 설치하고 그 리포의
  `script/run-agent.py` 를 부른다. 역할 러너 상황(로그인 확인 명령 · 실행 파일 스텁)은 샌드박스 `harness.toml` 과 고정 사본의 벤더 선언
  사본(`.harness/templates/vendors.toml`)으로 만든다
- #207 이 페이크 CLI 의 `run-plan` 출력으로 실행 계획 값을 바꿔 보던 케이스 → 벤더 선언 사본과 샌드박스 설정으로 만들 수 있는 상황은
  그렇게 옮긴다. 깨진 실행 계획 JSON(`the run plan … is broken`)을 보는 케이스는 그대로 두고 T9 · T10 이 지운다
- 건드릴 파일: `src/test/render-test.sh`

### 완료 조건

- [ ] UT-53 · UT-80 · UT-107 과 옮긴 실행 계획 케이스가 바꾼 준비부로 기대값 그대로 옛 스크립트에서 통과한다
- [ ] UT-53 이 `sed` 로 스크립트 일부를 잘라 돌지 않는다
- [ ] UT-80 · UT-107 이 관리 스크립트를 설치한 리포 밖으로 복사하지 않는다
- [ ] 옮긴 케이스가 실행 계획 JSON 을 내는 페이크 CLI 에 기대지 않는다
- [ ] 관리 스크립트와 `src/harness/` 가 바뀌지 않는다
- [ ] `src/test/render-test.sh` 와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 옛 검증 스크립트 분기 | 채운 `script/verify-project.sh` 가 있는 설치 리포에서 `script/run-lint-test.sh` | 그 스크립트의 출력(`legacy-ran`)이 나온다 |
| UT-02 | 설치한 리포의 지표 기록기 | UT-107 의 케이스를 설치한 리포의 `script/metric.py` 로 | 기존 기대값 그대로 |
| UT-03 | 설치한 리포의 역할 실행기 점검 | 벤더 선언 사본으로 로그인 확인 명령을 바꾼 설치 리포에서 `script/run-agent.py <역할> --check` | UT-80 의 기존 종료 코드 · 출력 그대로 |
| UT-04 | 실행 계획 값 케이스 | 벤더 선언 사본과 샌드박스 설정으로 만든 상황 | 기존 기대값 그대로 |

## T3 · feat: 표지를 패키지 내장 값으로 갖고 표지 파일을 읽지 못해 멈추는 경로 제거

### 상위 Requirement

- relates to #213

### 작업 내용

표지(`FMT_*`)의 정본을 `src/harness/format.py` 가 갖는 값으로 옮긴다. 하네스 루트의 `script/harness-format.sh` 가 없거나 깨져도 표지를
읽는 하위 명령이 그 때문에 실패하지 않는다. 셸 표기 `script/harness-format.sh` 는 관리 파일로 남고, 단위 테스트가 두 쪽이 같은지 본다.

- 명세 1절 "바뀌는 것" 의 표지 항목 · 3절(`markers()` 계약 · 셸 표기) · 10-1 의 예외 · 10-4 의 표지 행 · 10-5 의 "표지 · 어휘" 행(표지 쪽)
- `src/harness/format.py`: 착수 시점 `src/templates/managed/script/harness-format.sh` 의 `FMT_*` 이름과 값 전부를 모듈이 갖는다.
  `markers(root)` 는 이름과 인자를 그대로 두고 그 사전을 돌려준다 — `root` 는 받기만 하고 하네스 루트의 파일을 열지 않는다. 언제나 같은
  사전을 돌려주고 예외를 내지 않는다. `FormatError` 를 없앤다
- 부르는 쪽에서 표지를 읽지 못해 멈추던 분기를 지운다
  - #209 자체 검사의 "표지를 읽지 못한다" 행(`error: cannot read the markers from …` 과 2)
  - #210 시크릿 스캔의 허용 표지 읽기 실패(`error: cannot read the secret allow marker from …` 과 2)
  - #211 리뷰 루프 · task 동기화와 #212 `work-check` 의 "필요한 표지를 읽지 못하면 2"
- `src/templates/managed/script/harness-format.sh` 머리글: 정본은 `src/harness/format.py` 이고 이 파일은 같은 값을 셸에 둔 표기이며,
  남은 셸 소비자(셸 회귀 테스트)를 위해 있다는 것
- 단위 테스트 `src/test/unit/test_format.py`
  - 셸 표기를 `sh` 로 source 한 `FMT_*` 이름 · 값이 `markers()` 와 전부 같다 — 한쪽만 바꾸면 실패한다
  - 하네스 루트에 표지 파일이 없을 때 · 형식이 아닌 줄이 있을 때 · 그 자리가 디렉터리일 때도 같은 사전이고 예외가 없다
- 기존 검사 줄(대응표에 적는다)
  - #209 `test_format.py` 의 텍스트로 읽은 값 = source 한 값 줄 → 위의 셸 표기 = 내장 값 줄. `FormatError` 를 보는 줄 → 지운다
  - #210 9-4 의 `markers()` 행 → 하네스 루트에 표지 파일이 없어도 `markers()` 의 `FMT_SECRET_ALLOW` 가 `harness:allow-secret` 이다
  - #210 9-4 의 "secret-scan 표지 실패" 행 → 세 견본(표지 파일 없음 · 형식이 아닌 줄 · `FMT_SECRET_ALLOW` 줄을 뺀 견본)에서도 검사한다.
    허용 표지를 단 견본 줄은 0, 표지 없는 자격증명 견본은 1, 형식이 아닌 줄의 명령은 실행되지 않는다
  - #211 5-4 의 "표지" 행 → 지운다
  - 표지 파일을 치우거나 깨뜨려 2 를 보던 그 밖의 케이스(#209 3-3 · #212 5절) → 지운다
- `src/bin/harness render` 로 이 리포의 `script/harness-format.sh` 사본과 `.harness/managed` 를 갱신한다
- 건드릴 파일: `src/harness/format.py`, 표지를 읽는 하위 명령의 모듈(#209 자체 검사 · #210 시크릿 스캔 · #211 리뷰 루프 · task 동기화 ·
  #212 `work-check`), `src/templates/managed/script/harness-format.sh`, `src/test/unit/` 의 해당 테스트, 표지 실패를 보던
  `src/test/render-test.sh` · 셸 테스트의 케이스, render 로 갱신되는 `script/` · `.harness/managed`

### 완료 조건

- [ ] `markers()` 가 하네스 루트에 `script/harness-format.sh` 가 없거나 형식이 깨져도 같은 사전을 돌려주고 예외를 내지 않는다
- [ ] CLI 패키지에 `FormatError` 가 없고 `format.py` 가 하네스 루트의 파일을 열지 않는다
- [ ] 셸 표기를 셸로 읽은 `FMT_*` 이름 · 값이 `markers()` 와 전부 같다
- [ ] 하네스 루트에 표지 파일이 없어도 `harness secret-scan` 이 2 로 끝나지 않고 검사한다 — 허용 표지를 단 줄은 0, 표지 없는 자격증명은 1
- [ ] 자체 검사 · 리뷰 루프 · task 동기화 · `work-check` 에 표지를 읽지 못해 2 로 끝나는 경로가 없다
- [ ] 고치거나 지운 검사 줄이 리뷰 요청 본문의 대응표에 적혀 있다
- [ ] `script/run-lint-test.sh --commit` · `src/test/render-test.sh` · 고친 셸 테스트가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 셸 표기와 내장 값 | `src/templates/managed/script/harness-format.sh` 를 `sh` 로 source 한 `FMT_*` | `markers()` 와 이름 · 값 전부 같다 |
| UT-02 | 표지 파일 없음 | 빈 디렉터리를 `root` 로 `markers()` | UT-01 과 같은 사전, 예외 없음 |
| UT-03 | 깨진 표지 파일 | `FMT_X=$(…)` 줄이 든 파일 · 그 자리의 디렉터리 | 같은 사전, 예외 없음, 줄의 명령이 실행되지 않는다 |
| UT-04 | 허용 표지 | 표지 파일 없는 루트의 `markers()["FMT_SECRET_ALLOW"]` | `harness:allow-secret` |
| UT-05 | 표지 파일 없는 시크릿 스캔 | 세 견본 루트에서 허용 표지를 단 견본 줄 · 표지 없는 자격증명 견본 | 0 · 1 |
| UT-06 | 지운 실패 경로 | 표지 파일을 치운 루트에서 자체 검사 · `review` · `sync-tasks` · `work-check` | 표지 때문에 2 로 끝나지 않는다 |

## T4 · refactor: 이월 이슈 생성을 carryover 하위 명령으로 옮기고 shim 전환

### 상위 Requirement

- relates to #213

### 작업 내용

`create-carryover-issue.sh` 의 로직을 하위 명령 `harness carryover` 로 옮기고, 옛 경로를 받은 인자를 그대로 넘기는 shim 으로 바꾼다.
판정 순서 · 출력 · 종료 코드 · 원격에 쓰는 동작은 그대로다.

- 명세 2-1 · 2-2 · 4-1 · 7절 · 10-2 · 10-3 의 1 · 5 · 10 · 10-5 의 "이월 이슈" 행
- `src/harness/commands/carryover.py`
  - 2-2 의 판정 1~10 과 출력(`<참조> skip(<상태>)` · `(dry-run) create  <제목>` · `--- body ---` · `<참조> created`) · 종료 코드 0 · 2
  - 값은 공유 설정에서 — 커밋 태그(검사식 · 안내 표기), 이슈 참조 표시(`commit.issue_ref`), 필수 필드(`issues.required_fields`),
    task 라벨(`issues.labels.task`). 공유 설정을 읽지 못하거나 검증에 걸리면 2
  - 표지 `FMT_ISSUE_WORK` · `FMT_ISSUE_RELATES` 는 `format.py`, task 이슈 양식은 하네스 루트의 `.ai/templates/issue-task.md`(없으면 비교하지 않는다)
  - forge 는 #209 계약 함수 `tracker_require` · `tracker_issue_view` · `tracker_issue_list` · `tracker_issue_create` 로만 부른다
  - 하네스 루트에서 일한다. 본문 파일의 상대 경로는 하네스 루트 기준이고 절대 경로도 받는다. 처리하지 않은 예외는 2
- `COMMANDS` 항목(통과 표시, 인수 `<source-issue> <title> <body-file> [--dry-run]`, 설명
  `create the carryover issue for a review finding moved out of scope (writes to the remote)`)과 `DELEGATES`
- `src/templates/managed/script/create-carryover-issue.sh` → POSIX sh shim(명세 4-1). CLI 를 찾지 못하면 두 줄과 2
- 단위 테스트 `src/test/unit/test_carryover.py` — 본문 검사 넷, 제목 태그 검사. forge 는 계약 함수를 부르는 함수를 바꿔 끼운다
- `src/test/render-test.sh`: 10-3 의 1(이월 이슈의 사용법 오류 2 — shim 과 하위 명령 직접 호출이 같은 종료 코드 · 표준 출력) · 5 · 10 블록에
  `carryover` 케이스를 더한다
- 건드릴 파일: `src/harness/commands/carryover.py`(신규), `src/harness/commands/__init__.py`, `src/harness/cli.py`,
  `src/templates/managed/script/create-carryover-issue.sh`, `src/test/unit/test_carryover.py`(신규), `src/test/render-test.sh`,
  render 로 갱신되는 `script/` · `.harness/managed`

### 완료 조건

- [ ] `script/create-carryover-issue.sh` 가 받은 인자를 그대로 `<CLI> --target <루트> carryover` 로 넘기고 `test-carryover-issue.sh` UT-01~08 이 기대값 그대로 통과한다
- [ ] 원본 이슈 조회나 목록 조회가 실패하면 만들지 않고 2 로 끝난다
- [ ] 개인 레이어 파일이 깨져 있어도 돌고, 공유 설정을 읽지 못하면 2 로 끝난다
- [ ] 명령 이름 뒤의 `--dry-run` 이 그 명령의 인자로 간다
- [ ] `harness help` 에 명세 2-1 의 인수 · 설명이 나온다
- [ ] 전역 CLI 로 부른 `harness carryover` 가 고정 사본으로 넘어간다
- [ ] 실행 뒤 리포 어디에도 `__pycache__` 가 없다
- [ ] `script/run-lint-test.sh --commit` · `script/test-carryover-issue.sh` · `src/test/render-test.sh` 가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 빈 본문 | 공백만 든 본문 | 2, 생성 호출 없음 |
| UT-02 | 양식 원문 그대로 | `.ai/templates/issue-task.md` 원문 | 2 |
| UT-03 | 작업 내용 절 | 절이 없는 본문 · 주석만 든 절 | 둘 다 2 |
| UT-04 | 원본 이슈 참조 | `FMT_ISSUE_RELATES` 뒤에 다른 번호 | 2 |
| UT-05 | 제목 태그 | `요약만` · 목록 밖 태그 · 목록 안 태그 | 2 · 2 · 다음 판정으로 간다 |
| UT-06 | 셸 계약 | shim 을 거친 `test-carryover-issue.sh` | UT-01~08 기대값 그대로 |
| UT-07 | 그대로 넘김 | 인자 둘로 shim 과 `harness carryover` | 같은 사용법 출력과 2 |
| UT-08 | 고정 버전 위임 · 바이트코드 | 전역 CLI 로 `carryover` | 고정 사본이 답한다, `__pycache__` 없음 |

## T5 · refactor: 되감기를 rollback 하위 명령으로 옮기고 shim 전환

### 상위 Requirement

- relates to #213

### 작업 내용

`rollback-work.sh` 의 로직을 하위 명령 `harness rollback` 으로 옮기고, 옛 경로를 shim 으로 바꾼다. 되감는 것 · 남기는 것 · 확인 · 출력 ·
종료 코드는 그대로다. 이슈 · 리뷰 요청을 닫는 유일한 예외라는 규칙도 그대로다 — 사용자가 직접 부르고 확인한 턴에서만 돈다.

- 명세 2-1 · 2-3 · 4-1 · 7절 · 10-2 · 10-3 의 1 · 3 · 4 · 5 · 10 · 10-5 의 "되감기" 행
- `src/harness/commands/rollback.py`
  - 2-3 표의 되감는 것(열린 리뷰 요청 닫기, 원격 통합 브랜치의 `docs/plan/<이슈>/task.md` 제목과 같은 열린 task 이슈를 닫고 invalid 라벨,
    `refs/heads/*/<이슈>-*` 로컬 브랜치 지우기)과 남기는 것
  - 대상 먼저 보이기(`rollback target:` · `will be closed or removed` · `left alone`), `--dry-run` 의 `(dry-run) nothing was changed`,
    확인(표준 입력이 터미널일 때만 `roll these back? [y/N] `, `y` · `Y` · `yes` · `YES` 만 진행, 거절 1, 터미널이 아니면 2), 순서(리뷰 요청 →
    task 이슈 → 로컬 브랜치), 하나가 실패해도 계속하고 끝에 2, 되감을 것이 없으면 0, worktree 가 체크아웃한 브랜치 문구(71 명세 8절)
  - task 절 머리글은 표지 `FMT_TASK_HEADING`. 공유 설정의 이슈 참조 표시 · invalid 라벨 · 통합 브랜치
  - forge 는 계약 함수 `forge_require` · `tracker_issue_view` · `harness_issue_open_mrs` · `tracker_issue_list` · `review_mr_close` ·
    `tracker_issue_close` 로만 부른다
  - 모듈 머리 설명에 되감는 것과 남기는 것을 적는다. 처리하지 않은 예외는 2(거절의 1 과 겹치지 않는다)
- `COMMANDS` 항목(인수 `<issue> [--dry-run|--yes]`, 설명
  `roll back what work made for an issue: close its review requests and task issues, remove local branches (asks first)`)과 `DELEGATES`
- `src/templates/managed/script/rollback-work.sh` → POSIX sh shim. CLI 를 찾지 못하면 두 줄과 2
- 단위 테스트 `src/test/unit/test_rollback.py` — task 제목 대조
- `src/test/render-test.sh`: 10-3 의 1(`--dry-run`, 페이크) · 3(`rollback <이슈> --yes` 가 묻지 않고 되감는다, 페이크) · 4(CLI 를 치운
  샌드박스의 `rollback-work.sh` 가 2 와 두 줄) · 5 · 10 블록에 케이스를 더한다
- 건드릴 파일: `src/harness/commands/rollback.py`(신규), `src/harness/commands/__init__.py`, `src/harness/cli.py`,
  `src/templates/managed/script/rollback-work.sh`, `src/test/unit/test_rollback.py`(신규), `src/test/render-test.sh`,
  render 로 갱신되는 `script/` · `.harness/managed`

### 완료 조건

- [ ] `script/rollback-work.sh` 가 받은 인자를 그대로 넘기고 `test-rollback-work.sh` UT-01~08 이 기대값 그대로 통과한다
- [ ] `--yes` 없이 표준 입력이 터미널이 아니면 묻지 않고 2 로 끝나고 아무것도 바꾸지 않는다
- [ ] 명령 이름 뒤의 `--yes` · `--dry-run` 이 그 명령의 인자로 간다
- [ ] 출력 줄이 옛 스크립트와 같다 — worktree 가 체크아웃한 브랜치 문구 포함
- [ ] CLI 를 찾지 못하면 shim 이 `error: harness CLI not found under <루트> (.harness/bin/harness or src/bin/harness)` · `help: harness install --target <루트>` 와 2 로 끝난다
- [ ] 전역 CLI 로 부른 `harness rollback` 이 고정 사본으로 넘어가고, 실행 뒤 `__pycache__` 가 없다
- [ ] `script/run-lint-test.sh --commit` · `script/test-rollback-work.sh` · `src/test/render-test.sh` 가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | task 제목 대조 | 분해의 task 절 제목과 같은 열린 이슈 · 닫힌 이슈 · 다른 분해의 같은 요약 이슈 | 앞의 것만 고른다 |
| UT-02 | 셸 계약 | shim 을 거친 `test-rollback-work.sh` | UT-01~08 기대값 그대로 |
| UT-03 | 드라이런 | 페이크로 `script/rollback-work.sh <이슈> --dry-run` 과 `harness rollback <이슈> --dry-run` | 같은 표준 출력, 0, 페이크에 닫기 호출 없음 |
| UT-04 | 묻지 않는 되감기 | 페이크로 `harness rollback <이슈> --yes` | 묻지 않고 되감는다 |
| UT-05 | CLI 없음 | CLI 를 치운 샌드박스의 `script/rollback-work.sh <이슈>` | 2 와 두 줄 |
| UT-06 | 고정 버전 위임 · 바이트코드 | 전역 CLI 로 `rollback <이슈> --dry-run` | 고정 사본이 답한다, `__pycache__` 없음 |

## T6 · refactor: 사용 기록 모듈과 usage log 하위 명령, 가드 · 훅의 차단 기록 전환

### 상위 Requirement

- relates to #213

### 작업 내용

사용 기록의 기록 로직과 어휘를 사용 기록 모듈로 옮기고, 하위 명령 `harness usage log` 와 shim `usage-log.sh` 를 둔다. 명령 가드 · git
훅이 차단을 기록하는 수단도 이 모듈로 바꾼다. 기록 줄과 항상 0 으로 끝나는 계약은 그대로다.

- 명세 2-1 · 2-5 의 `usage log` · 3절(사용 기록 모듈 · 셸 표기) · 4-1 · 5-1 의 #210 행과 가드 조건 · 7절 · 10-2 · 10-3 의 1 · 4 · 5 · 9 · 10 ·
  10-4 의 #210 행 · 10-5 의 "표지 · 어휘"(어휘 쪽) · "사용 기록" 행
- `src/harness/usage.py`
  - 어휘(이벤트 · 출처 · 고정 라벨 · 키별 값 형식 정규식)의 정본. 값은 착수 시점 `usage-vocab.sh` 와 같다
  - 상세 거르기(개행 · CR · 탭 · `|` 를 공백으로, 고정 라벨이거나 형식에 맞는 `키=값` 만, 80자), 종류 · 출처가 어휘 밖이면 `other`
  - 브랜치 유형(부른 쪽 현재 디렉터리의 `git branch --show-current` — `-` · `protected` · 태그 · `unknown`), 줄 형식
  - 기록 위치: `usage.env_var` 가 이름인 환경 변수 → 없으면 `usage.log_path`. `off` 면 기록하지 않는다. `$NAME` · `${NAME}` 을 그 값으로
    바꾸고(없는 변수는 빈 문자열) `~` 와 명령 치환은 풀지 않는다. 이어서 `{clone}` · `{project}` 를 클론 키 모듈(`home/clone_key.py`)로
    푼다. 풀지 못하면 기록하지 않는다
  - 부모 디렉터리를 만들고 줄을 덧붙인다. 실패해도 예외를 올리지 않는다
- `src/harness/commands/usage.py`: `usage log <종류> <출처> [상세]` — 인자가 둘보다 적으면 기록하지 않고 아무것도 내지 않는다. 공유 설정
  (`usage.env_var` · `usage.log_path`, 통합 브랜치가 든 보호 브랜치 목록, 커밋 태그)을 읽고, 읽지 못하면 기록하지 않고 0. 처리하지 않은
  예외도 0. `usage` 뒤가 `log` 가 아니면 사용법을 내고 2
- `COMMANDS` 의 `usage` 항목(통과 표시, 인수 `<log> ...`, 설명 `append a usage record`)과 `DELEGATES`. `report` 는 T7 이 더한다
- `src/templates/managed/script/usage-log.sh` → POSIX sh shim. CLI 를 찾지 못하면 아무것도 내지 않고 0
- `src/templates/managed/script/usage-vocab.sh` 머리글: 정본은 `src/harness/usage.py` 이고 이 파일은 같은 값의 셸 표기라는 것
- 명령 가드 · git 훅(#210)의 차단 기록: 하네스 루트의 `script/usage-log.sh` 를 부르던 것을 사용 기록 모듈로 바꾼다
  - 가드 모듈은 사용 기록 모듈을 최상위에서 불러오지 않고 차단이 정해진 뒤에만 부른다. 통과 경로는 사용 기록 모듈과 그것이 부르는 설정
    해석을 불러오지 않는다
  - 기록의 출력과 실패는 버린다. 차단 사유 · 종료 코드 · 기록 줄(`block bash-guard <라벨>` · `block commit-msg format` 등)은 그대로다
- 단위 테스트 `src/test/unit/test_usage.py` — 10-5 의 "사용 기록" 행, 그리고 `usage-vocab.sh` 를 셸로 읽은 이름 · 값 = 모듈의 어휘
- `src/test/render-test.sh`: 10-3 의 1(`usage-log.sh` 0) · 4(CLI 를 치운 샌드박스의 `usage-log.sh` 0) · 5 · 9 · 10 블록에 케이스를 더한다.
  #210 의 가드 경로 import 케이스와 차단 기록을 보는 케이스가 그대로 통과한다
- 건드릴 파일: `src/harness/usage.py`(신규), `src/harness/commands/usage.py`(신규), `src/harness/commands/__init__.py`, `src/harness/cli.py`,
  `src/harness/guard/` · `src/harness/hooks.py`, `src/templates/managed/script/usage-log.sh` · `usage-vocab.sh`,
  `src/test/unit/test_usage.py`(신규), `src/test/render-test.sh`, render 로 갱신되는 `script/` · `.harness/managed`

### 완료 조건

- [ ] `script/usage-log.sh` 가 받은 인자를 그대로 `<CLI> --target <루트> usage log` 로 넘기고 `test-usage-log.sh` 의 기록 케이스가 기대값 그대로 통과한다
- [ ] 기록 줄에 명령 내용 · 문서 본문 · 사람 이름 · 체크아웃 디렉터리 이름 · 브랜치 이름이 없다
- [ ] 읽히지 않는 `harness.toml` 에서 `usage-log.sh` 가 0 으로 끝나고 아무것도 기록하지 않는다
- [ ] `usage.log_path` 의 명령 치환이 실행되지 않고 문자 그대로 남는다
- [ ] 가드의 통과 경로가 사용 기록 모듈과 설정 해석을 불러오지 않고, 차단 경로의 기록 줄이 옛 줄과 같다
- [ ] `usage-vocab.sh` 를 셸로 읽은 어휘가 모듈의 어휘와 전부 같다
- [ ] `script/run-lint-test.sh --commit` · `script/test-usage-log.sh` · `script/test-bash-guard.sh` · `src/test/render-test.sh` 가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 상세 거르기 | 허용 라벨 · 형식에 맞는/맞지 않는 `키=값` · 자유 문장 · 사람 이름 모양 · 80자 넘는 상세 | 라벨과 맞는 `키=값` 만 남고 80자에서 잘린다 |
| UT-02 | 브랜치 유형 | 브랜치 없음 · 보호 브랜치 · `<태그>/x` · 목록 밖 접두 | `-` · `protected` · 태그 · `unknown` |
| UT-03 | 기록 위치 | 환경 변수 있음 · 없는 변수 · `~` · `$(…)` · `{clone}` · `off` | 환경 변수 값 그대로 · 빈 문자열 · `~` 그대로 · 실행 안 됨 · 키로 풂 · 기록 안 함 |
| UT-04 | 어휘 셸 표기 | `usage-vocab.sh` 를 셸로 읽은 이름 · 값 | 모듈 어휘와 전부 같다 |
| UT-05 | 설정이 깨짐 | 읽히지 않는 `harness.toml` 에서 `usage-log.sh note x` | 0, 기록 없음 |
| UT-06 | 가드 경로 | 통과 입력과 차단 입력으로 `bash-guard` | 통과 경로에 사용 기록 모듈이 불러와지지 않고, 차단 기록 줄은 옛 줄과 같다 |
| UT-07 | CLI 없음 | CLI 를 치운 샌드박스의 `usage-log.sh note x` | 0, 출력 없음 |

## T7 · refactor: 사용 기록 집계를 usage report 하위 명령으로 옮기고 shim 전환

### 상위 Requirement

- relates to #213

### 작업 내용

`usage-report.sh` 의 집계를 사용 기록 모듈과 `harness usage report` 로 옮기고 옛 경로를 shim 으로 바꾼다. 표의 제목 · 열 · 문장과
`KEY=VALUE` 줄의 이름 · 순서 · 값이 그대로다.

- 명세 2-1 · 2-5 의 `usage report` · 4-1 · 7절 · 10-2 · 10-3 의 1 · 5 · 10
- `src/harness/usage.py`: 집계
  - 디렉터리는 그 아래 `*.log` 전부. 마지막 줄에 개행이 없는 파일도 다음 파일과 줄이 합쳐지지 않는다
  - 기간을 주지 않으면 최근 28일(로컬 날짜)
  - 입력 줄을 형식과 어휘로 다시 검증하고 맞지 않는 줄은 건수만 센다
  - 회차 상한은 `review.max_rounds`. 상한 도달은 `exit=3 stop=mrl-cap` 기록만, 한 파일 반복은 `stop=repeat` 기록만 센다
  - 건수로 정렬하는 표에서 같은 건수의 행은 `LC_ALL=C sort -t'|' -k3 -nr` 의 순서다
- `src/harness/commands/usage.py`: `usage report [--since YYYY-MM-DD] [로그파일|디렉터리 ...]` — `--since` 뒤에 값이 없으면 2, `-` 로
  시작하는 다른 인자는 사용법과 2, 나머지는 경로(하네스 루트 기준, 절대 경로도 받는다). 경로가 없으면 `usage log` 와 같은 규칙의 기록 위치
  하나를 읽고, 자리표시를 풀지 못하면 `error: could not resolve usage.log_path for this clone` 과 2. 공유 설정을 읽지 못하면 2, 처리하지
  않은 예외도 2
- `COMMANDS` 의 `usage` 항목을 명세 2-1 표대로(인수 `<log|report> ...`, 설명
  `append a usage record, or summarize usage records as tables and KEY=VALUE lines`) 바꾼다
- `src/templates/managed/script/usage-report.sh` → POSIX sh shim. CLI 를 찾지 못하면 두 줄과 2
- 단위 테스트 `src/test/unit/test_usage.py` 에 집계 케이스를 더한다
- `src/test/render-test.sh`: 10-3 의 1(`usage-report.sh` 의 기록 없음 출력이 직접 부른 것과 같다) · 5 · 10 블록에 케이스를 더한다
- 건드릴 파일: `src/harness/usage.py`, `src/harness/commands/usage.py`, `src/harness/commands/__init__.py`,
  `src/templates/managed/script/usage-report.sh`, `src/test/unit/test_usage.py`, `src/test/render-test.sh`, render 로 갱신되는 `script/` ·
  `.harness/managed`

### 완료 조건

- [ ] `script/usage-report.sh` 가 받은 인자를 그대로 넘기고 `test-usage-log.sh` 의 집계 케이스가 기대값 그대로 통과한다
- [ ] 같은 입력에서 표 · `KEY=VALUE` 출력이 옛 스크립트와 바이트 단위로 같다 — 같은 건수 행의 순서 포함
- [ ] 기록이 없을 때의 "미수집" 표기와 기간 밖에만 기록이 있을 때의 `PERIOD_EMPTY=yes` 가 옛 스크립트와 같다
- [ ] 명령 이름 뒤의 `--since` 가 그 명령의 인자로 간다
- [ ] `harness help` 의 `usage` 줄이 명세 2-1 표와 같다
- [ ] `script/run-lint-test.sh --commit` · `script/test-usage-log.sh` · `src/test/render-test.sh` 가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 줄 재검증 | 필드 수가 다른 줄 · 어휘 밖 종류 · 형식이 맞는 줄 | 앞의 둘은 건수로만 세고 집계에서 빠진다 |
| UT-02 | 같은 건수의 순서 | 같은 건수의 차단 라벨 여럿 | `LC_ALL=C sort -t'\|' -k3 -nr` 과 같은 행 순서 |
| UT-03 | 개행 없는 마지막 줄 | 마지막 줄에 개행이 없는 파일 둘이 든 디렉터리 | 두 파일의 줄이 합쳐지지 않는다 |
| UT-04 | 상한 · 반복 | `exit=3 stop=mrl-cap` · `exit=3 stop=repeat` · `exit=3` 만 | 상한 1 · 반복 1, 마지막 줄은 어느 쪽에도 세지 않는다 |
| UT-05 | 기간 | `--since` 없음(고정한 오늘) · 지정 | 최근 28일 · 그 날짜부터 |
| UT-06 | 인자 | `--since` 값 없음 · `--x` | 둘 다 2 |

## T8 · refactor: 스팬 기록기를 패키지 모듈로 옮기고 CLI 안의 스팬 기록을 그 모듈로 전환

### 상위 Requirement

- relates to #213

### 작업 내용

스팬 기록 로직을 `src/harness/metrics/recorder.py` 로 옮기고, CLI 안에서 대상 리포의 `script/metric.py` 를 불러와 기록하던 곳을 이
기록기로 바꾼다. 스팬의 이름 · 종류 · 속성 · 부모 관계 · 파일 형식은 그대로다. `script/metric.py` 는 이 task 에서 고치지 않는다.

- 명세 2-4 의 기록 형식 · 남기지 않는 것 · 기록기 계약 · 3절 · 5-1 의 `harness run` · 세션 가져오기 · `harness metrics prune` · 드라이버 블록
  스팬 행 · 10-4 의 "이 밖에 내부 함수를 보는 줄" · 10-5 의 "스팬 기록기" 행
- `src/harness/metrics/recorder.py`
  - `<dir>/spans-<YYYYMMDD>-<N>.jsonl`, 한 줄에 이벤트 하나(`start` · `end`), 스키마 `v: 1`, UTC 밀리초
  - 종류 · 속성 키 · 값 모양(`issue` · `worktree` 는 숫자만), 이름 정리(공백 → `-`, 80자, 모양이 맞지 않으면 기록하지 않음)
  - `max_file_mb` 넘김, 하루 한 번 `retention_days` · `max_total_mb` 정리, 쓰기와 정리를 디렉터리 잠금 안에서
  - 실패 로그(`capture_logs = "errors"` 이고 실패한 스팬일 때만, 표준 오류 끝 20줄 · 2048바이트, 지우기 규칙), 디렉터리 0700 · 파일 0600
  - 감싸기 — 기록할 때만 자식의 표준 오류를 파이프로 받아 그대로 흘리며 끝부분을 모은다. 자식에게 `HARNESS_TRACE_ID` · `HARNESS_PARENT_SPAN`
  - 지표 설정과 자리표시를 푼 기록 디렉터리를 인자로 받는다. 하네스 루트 · 설정 · 실행 계획 · 클론 키를 스스로 구하지 않고 `metrics/` 밖의
    하네스 모듈을 불러오지 않는다. 기록 실패는 예외로 올리지 않는다
- 부르는 쪽
  - `harness run` 의 run 스팬 — 자기가 해석한 지표 설정의 `dir` 을 클론 키 모듈로 풀어 넘기고 실행 계획을 다시 계산하지 않는다
  - 세션 가져오기(`harness metrics import`)의 기록
  - `harness metrics prune` — 대상 리포의 `script/metric.py prune` 을 띄우지 않고 기록기의 정리를 부른다. 출력(`prune: <N> file(s) removed`)과
    종료 코드는 지금과 같다
  - #208 드라이버의 블록 스팬
- `src/harness/metrics/spans.py` 의 `load_metric` 과 대상 리포 `script/metric.py` 를 경로로 불러오는 코드를 없앤다. CLI 의 기록 여부가
  대상 리포의 `script/metric.py` 유무에 기대지 않는다
- `src/test/render-test.sh`: 대상 리포의 `script/metric.py` 를 모듈로 불러 고정 스팬을 만들거나 내부 함수를 보던 줄 — UT-54 의 동시 쓰기 ·
  파일 넘김, UT-56 과 worktree 실행 스팬 케이스의 고정 스팬 만들기 — 을 패키지 기록기를 불러 쓰는 줄로 바꾼다. `clean_attrs` 를 보던 줄은
  기록기 단위 테스트로 옮긴다. 대응표에 적는다
- 단위 테스트 `src/test/unit/test_recorder.py` — 10-5 의 "스팬 기록기" 행
- 건드릴 파일: `src/harness/metrics/recorder.py`(신규), `src/harness/metrics/spans.py` · `metrics/sessions.py`, `src/harness/commands/run.py` ·
  `commands/metrics.py`, #208 드라이버 모듈, `src/test/unit/test_recorder.py`(신규), `src/test/render-test.sh`

### 완료 조건

- [ ] `harness run` · 세션 가져오기 · 드라이버 블록이 남긴 스팬의 이름 · 종류 · 속성 · 부모 관계 · 파일 형식이 옛 기록과 같다 — UT-54 · UT-56 · #208 지표 케이스의 기대값 그대로
- [ ] `harness metrics prune` 의 출력 · 종료 코드가 같고 대상 리포의 `script/metric.py` 를 띄우지 않는다
- [ ] CLI 패키지에 대상 리포의 `script/metric.py` 를 불러오는 코드가 없다
- [ ] 기록기가 받은 디렉터리 밖에 쓰지 않고, `script/project/check-cli.py imports` 가 `metrics/` 의 의존 방향 위반을 내지 않는다
- [ ] 기록할 수 없는 디렉터리에서도 부른 명령의 출력 · 종료 코드가 같다
- [ ] 고친 검사 줄이 리뷰 요청 본문의 대응표에 적혀 있다
- [ ] `script/run-lint-test.sh --commit` 과 `src/test/render-test.sh` 가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 이름 · 속성 모양 | 공백 든 이름 · 80자 넘는 이름 · `worktree=../x` · `issue=1` · 목록 밖 키 | 공백은 `-`, 80자, `worktree` 빠짐, `issue` 남음, 목록 밖 키 빠짐 |
| UT-02 | 지우기 규칙 | 토큰 · 쿠키 · bearer · 키 모양 · JWT · URL 쿼리 · URL 자격 · 이메일 · 홈 경로가 든 표준 오류 | 모두 지워지고 끝 20줄 · 2048바이트만 남는다 |
| UT-03 | 파일 넘김 | `max_file_mb` 를 넘기는 기록 | 다음 번호 파일로 넘어간다 |
| UT-04 | 보관 · 전체 상한 | 보관 기간이 지난 파일 · 상한을 넘는 오래된 파일 · 쓰는 중인 파일 | 앞의 둘이 지워지고 쓰는 중인 파일은 남는다 |
| UT-05 | 받은 디렉터리 | 임시 디렉터리를 넘긴 기록 | 그 디렉터리 밖에 파일이 생기지 않는다, 0700 · 0600 |
| UT-06 | 기록 실패 | 쓸 수 없는 디렉터리 | 예외 없이 끝난다 |
| UT-07 | prune 출력 | 지울 파일 둘이 있는 디렉터리로 `harness metrics prune` | `prune: 2 file(s) removed`, 0 |

## T9 · refactor: 역할 실행기를 run-agent 하위 명령으로 옮기고 드라이버가 같은 프로세스에서 부름

### 상위 Requirement

- relates to #213

### 작업 내용

`run-agent.py` 의 로직을 역할 실행기 모듈과 하위 명령 `harness run-agent` 로 옮기고 옛 경로를 shim 으로 바꾼다. 실행 계획은 실효 설정에서
같은 프로세스로 계산한다. #208 드라이버는 역할 실행기 모듈을 같은 프로세스에서 부른다.

- 명세 2-1 · 2-6 · 3절 · 4-1 · 5-1 의 드라이버 행과 시작 전 확인 문장 · 7절 · 9절의 `vendors.toml` 행 · 10-3 의 1 · 5 · 10 · 11(`run-agent.py`) ·
  10-4 의 UT-54 · UT-80 · UT-84 · UT-86 · 실행 계획 케이스 · #208 역할 실행기 케이스 · 10-5 의 "역할 실행기" 행
- `src/harness/runner.py`
  - 띄울 항목 고르기 — 역할만 `roles.<역할>`, `--driver` 면 `roles.<역할>.driver`, `--driver-prompt <권한>` 이면 최상위 `prompt.<권한>`
  - argv — 고른 항목의 `argv` 에 사용량 파서가 있으면 `usage_format`, 없고 `--out` 이 있으면 결과 파일 인자(`{out}` 치환), `structured`
    인자(#208 7-4 의 자리, `--schema` 를 주고 항목의 `structured` 가 비어 있지 않을 때만), 마지막에 지시. `--prompt` 가 없으면 지금의 기본 지시
  - 본문 받기와 `--out` 쓰기, 표준 입력은 그대로 넘긴다
  - 스팬(이름 역할, 종류 `agent`, 출처 `runner`, 속성 `role` · `vendor` · `model` · `workflow` · `step`, 끝 기록에 종료 코드 · 시간 · 사용량 ·
    모델, 실패면 지운 실패 로그) — 기록기(T8)에 클론 키 모듈로 푼 디렉터리를 넘긴다
  - `--check` — `auth_check` 가 없으면 `unchecked` 와 0, `auth_timeout` 이 1 이상의 정수가 아니면 2, `HARNESS_CHECK_START_FD`, 하네스 루트에서
    제한 시간 안에 돌리고 입출력을 버린다, 실패 3 · 띄우지 못함 · 시간 초과 4 · 성공 `signed-in` 과 0, 스팬 없음
  - `PARSERS`(`claude-json` · `codex-jsonl`). 모르는 출력 형식이면 받은 그대로 넘기고 사용량을 비운다
- `src/harness/commands/run_agent.py`: 명세 2-6 의 인자. 실행 계획을 같은 프로세스에서 실효 설정으로 `run_plan()` 으로 계산하고, 성립하지
  않으면 `harness run-plan` 이 내는 것과 같은 오류와 2(`--check` 포함). `` error: no role `<역할>` in the config (have: <역할들>) ``, 고른 항목이
  없거나 서브에이전트 역할을 `--driver` 없이 부르거나 실행 파일이 없으면 2. `--out` 의 상대 경로는 부른 쪽 현재 디렉터리 기준. 처리하지 않은
  예외는 2
- `COMMANDS` 항목(인수 · 설명은 명세 2-1 표)과 `DELEGATES`
- `src/templates/managed/script/run-agent.py` → python3 shim. CLI 를 찾지 못하면 두 줄과 2
- #208 드라이버: agent · prompt 블록이 역할 실행기 모듈을 같은 프로세스에서 부른다 — `run-agent --driver` · `--driver-prompt` 와 같은 구현이고
  shim 을 거치지 않는다. 시작 전 확인의 `error: script/run-agent.py is missing` 을 없앤다
- `src/templates/vendors.toml` 주석: `usage_parser` 가 고르는 파서는 `src/harness/runner.py` 의 `PARSERS`
- 기존 검사 줄(대응표에 적는다)
  - UT-86: `run-agent.py` 를 `runpy` 로 돌리며 `subprocess.run` 을 바꿔 끼우던 준비부 → 패키지의 역할 실행기 모듈을 같은 방식으로 돌린다
  - 깨진 실행 계획 JSON 에서 `run-agent.py` 가 `the run plan … is broken` 을 내던 케이스 → 지운다. 같은 프로세스에서 계산하므로 생기지 않는다
  - #208 의 `script/run-agent.py is missing` 시작 전 확인 케이스 → 지운다
  - UT-54 · UT-80 · UT-84 와 #208 의 `--driver` · `--driver-prompt` · `--schema` 케이스는 고치지 않고 shim 을 거쳐 통과한다
- 단위 테스트 `src/test/unit/test_runner.py` — 10-5 의 "역할 실행기" 행
- `src/test/render-test.sh`: 10-3 의 1(`run-agent.py` 의 서브에이전트 역할 2) · 5 · 10 · 11(`harness.local.toml` 로 역할의 러너를 바꾸면 바꾼
  러너의 스텁을 띄운다, 받지 않는 키가 든 개인 레이어에서 2 와 `harness run-plan` 이 내는 것과 같은 오류) 블록에 케이스를 더한다
- 건드릴 파일: `src/harness/runner.py`(신규), `src/harness/commands/run_agent.py`(신규), `src/harness/commands/__init__.py`, `src/harness/cli.py`,
  #208 드라이버 모듈, `src/templates/managed/script/run-agent.py`, `src/templates/vendors.toml`, `src/test/unit/test_runner.py`(신규),
  `src/test/render-test.sh`, render 로 갱신되는 `script/` · `.harness/managed`

### 완료 조건

- [ ] `script/run-agent.py` 가 받은 인자를 그대로 `<CLI> --target <루트> run-agent` 로 넘기고, UT-54 · UT-80 · UT-84 와 #208 역할 실행기 케이스가 기대값 그대로 통과한다
- [ ] `run-agent` 가 `harness run-plan` 을 하위 프로세스로 띄우지 않고 실행 계획 파일을 읽지 않는다
- [ ] 개인 레이어로 바꾼 러너가 반영되고, 개인 레이어가 성립하지 않으면 `harness run-plan` 과 같은 오류와 2 다
- [ ] 드라이버가 `script/run-agent.py` 없이도 agent · prompt 블록을 띄운다
- [ ] `--check` 가 스팬을 남기지 않고 종료 코드 0 · 2 · 3 · 4 가 옛 스크립트와 같다
- [ ] `test-review-loop.sh` 의 리뷰어 실행 · 러너 점검 케이스가 기대값 그대로 통과한다
- [ ] 고치거나 지운 검사 줄이 리뷰 요청 본문의 대응표에 적혀 있다
- [ ] `script/run-lint-test.sh --commit` · `script/test-review-loop.sh` · `src/test/render-test.sh` 가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 파서 정상 출력 | `claude-json` · `codex-jsonl` 의 정상 출력 견본 | 본문과 입력 · 출력 토큰 · 모델을 꺼낸다 |
| UT-02 | 파서 오류 표시 | 두 형식의 오류 표시 견본 | 실패로 판정한다 |
| UT-03 | 모르는 형식 | 형식에 맞지 않는 출력 | 받은 그대로 넘기고 사용량이 비어 있다 |
| UT-04 | 항목 고르기 | 역할만 · `--driver` · `--driver-prompt write` | `roles.<역할>` · `roles.<역할>.driver` · `prompt.write` |
| UT-05 | 없는 항목 | `entry` 역할에 `--driver` · `headless` 없는 오케스트레이터의 `--driver-prompt` | 둘 다 2 |
| UT-06 | `--schema` 무시 | `structured` 가 빈 항목에 `--schema f` | argv 에 스키마 인자가 없다 |
| UT-07 | 개인 레이어 | `harness.local.toml` 로 러너를 바꾼 루트 · 받지 않는 키가 든 개인 레이어 | 바꾼 러너의 스텁을 띄운다 · 2 와 `run-plan` 과 같은 오류 |
| UT-08 | 서브에이전트 역할 | `script/run-agent.py developer 1` | 2 |

## T10 · refactor: 스팬 기록을 span 하위 명령으로 옮기고 metric.py 를 shim 으로 전환

### 상위 Requirement

- relates to #213

### 작업 내용

`metric.py` 의 명령줄 동작을 하위 명령 `harness span` 으로 옮기고 옛 경로를 shim 으로 바꾼다. 지표 설정은 실행 계획을 실효 설정에서 같은
프로세스로 계산해 받는다. 이 task 뒤에는 `script/metric.py` 를 모듈로 불러오는 곳이 없다.

- 명세 2-1 · 2-4 · 4-1 · 7절 · 10-3 의 1 · 2 · 3 · 4 · 5 · 10 · 11(`metric.py`) · 12 · 10-4 의 UT-107 · 실행 계획 케이스 · 10-5 의
  "스팬 기록 명령" 행
- `src/harness/commands/span.py`
  - 동작 `wrap` · `start` · `end` · `step` · `prune` 과 종료 코드(명세 2-4 표). 동작 뒤의 `--<키> <값>` 쌍, `--attr` 여러 번, 모르는 키 무시,
    `--` 뒤를 감쌀 명령으로
  - 지표 설정은 하네스 루트의 실행 계획(`run_plan()` 의 `metrics`). `HARNESS_METRICS=off` 면 실행 계획을 계산하지 않는다
  - 기록하지 않는 경우(`HARNESS_METRICS=off`, 실효 설정이 성립하지 않음, `dir` 이 `off`, 자리표시를 풀지 못함)에도 출력과 종료 코드는 같다
  - `dir` 은 클론 키 모듈로 자리표시를 풀고 이어서 `~` 와 환경 변수를 펼친 값이고, 그것을 기록기(T8)에 넘긴다
  - `wrap` 은 부른 쪽 현재 디렉터리에서 감싼 명령을 띄운다. `start` 는 기록하지 않아도 스팬 id 를 낸다. `step` 은 이름 `<절차>/<단계>`,
    종류 `marker`, 출처 `session`, 트레이스는 `HARNESS_TRACE_ID` 없으면 `t-unattributed`. 처리하지 않은 예외는 2
- `COMMANDS` 항목(인수 `<wrap|start|end|step|prune> ...`, 설명은 명세 2-1 표)과 `DELEGATES`
- `src/templates/managed/script/metric.py` → python3 shim. CLI 를 찾지 못하면 `wrap` 은 `--` 뒤의 명령을 그대로 exec 하고(`--` 뒤가 비면
  사용법과 2) 그 밖의 동작은 아무것도 내지 않고 0
- 기존 검사 줄(대응표에 적는다)
  - UT-107: 클론 키 모듈 없이 복사한 `metric.py` 가 기록하지 않음을 보던 줄 → 지운다. 패키지 안에서는 모듈이 빠지지 않는다
  - 깨진 실행 계획 JSON 에서 `metric.py` 가 기록하지 않음을 보던 케이스 → 지운다
  - UT-54 의 `script/metric.py wrap` · `prune` 줄은 고치지 않고 shim 을 거쳐 통과한다
- 단위 테스트 `src/test/unit/test_span.py` — 10-5 의 "스팬 기록 명령" 행
- `src/test/render-test.sh`: 10-3 의 블록에 케이스를 더한다
  - 1 — `metric.py wrap` 이 감싼 명령의 출력 · 종료 코드
  - 2 — 하네스 루트가 아닌 디렉터리에서 `script/metric.py wrap … -- pwd` 가 그 디렉터리를 낸다
  - 3 — `span wrap --name x --kind script -- sh -c 'echo "$*"' _ --json --yes` 가 `--json --yes` 를 내고, 끝의 `--target /x` 도 감싼 명령에 간다
  - 4 — CLI 를 치운 샌드박스에서 `metric.py wrap` 이 감싼 명령의 종료 코드로 끝난다
  - 5 · 10
  - 11 — 받지 않는 키가 든 개인 레이어에서 `metric.py wrap` 이 감싼 명령의 종료 코드로 끝나고 스팬을 남기지 않는다
  - 12 — `metrics.dir` 에 `{clone}` 이 든 설정에서 `metric.py wrap` 이 클론 키로 푼 디렉터리에 기록한다
- 건드릴 파일: `src/harness/commands/span.py`(신규), `src/harness/commands/__init__.py`, `src/harness/cli.py`,
  `src/templates/managed/script/metric.py`, `src/test/unit/test_span.py`(신규), `src/test/render-test.sh`, render 로 갱신되는 `script/` ·
  `.harness/managed`

### 완료 조건

- [ ] `script/metric.py` 가 받은 인자를 그대로 `<CLI> --target <루트> span` 으로 넘기고, UT-54 의 `wrap` · `prune` 줄과 절차 문서의 `step` 이 기대값 그대로 돈다
- [ ] 명령 이름 뒤의 `--json` · `--yes` · `--target` 이 감싼 명령에 그대로 간다
- [ ] `span` 이 `harness run-plan` 을 하위 프로세스로 띄우지 않고, `HARNESS_METRICS=off` 면 실행 계획을 계산하지 않는다
- [ ] 기록이 실패하거나 기록하지 않는 경우에도 출력과 종료 코드가 기록할 때와 같다
- [ ] 패키지 · 관리 스크립트 · 회귀 테스트 어디에도 `script/metric.py` 를 모듈로 불러오는 코드가 없다
- [ ] 고치거나 지운 검사 줄이 리뷰 요청 본문의 대응표에 적혀 있다
- [ ] `script/run-lint-test.sh --commit` 과 `src/test/render-test.sh` 가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 자리표시 풀기 | `metrics.dir = "~/m/{clone}/$X"` | 클론 키로 풀고 `~` 와 `$X` 를 펼친 디렉터리를 기록기에 넘긴다 |
| UT-02 | 지표 끔 | `HARNESS_METRICS=off` 로 `wrap` | 실행 계획을 계산하는 함수를 부르지 않고 감싼 명령의 종료 코드로 끝난다 |
| UT-03 | 인자 읽기 | `--attr a=1 --attr b=2 --nope x -- cmd` | `attr` 둘, 모르는 키 무시, 감쌀 명령 `cmd` |
| UT-04 | `end` 규칙 | `--exit x` · `--status weird` | 종료 코드 빠짐 · `ok` |
| UT-05 | 동작 없음 | 인자 없음 · `wrap --name x --kind script --` | 둘 다 사용법과 2 |
| UT-06 | 실효 설정 실패 | 받지 않는 키가 든 개인 레이어 | 기록하지 않고 감싼 명령의 종료 코드 |

## T11 · refactor: 클론 키 계산을 패키지 모듈 하나로 모으고 _clone_key.py 를 clone-key shim 으로 전환

### 상위 Requirement

- relates to #213

### 작업 내용

클론 키 계산을 `src/harness/home/clone_key.py` 가 직접 하고, 관리 스크립트 `_clone_key.py` 를 경로로 불러오던 방식을 없앤다. 옛 경로는
하위 명령 `harness clone-key` 의 shim 이 된다. 키 계산 규칙은 96 명세 1-1 그대로다.

- 명세 2-1 · 2-8 · 3절(클론 키 모듈) · 4-1 · 10-3 의 1 · 4 · 5 · 10 · 10-4 의 UT-106 ~ UT-110 · 10-5 의 "클론 키" 행
- `src/harness/home/clone_key.py`: `clone_key` · `expand_key` 의 계산을 모듈이 갖는다 — git 트리 안이면 `git\0<공통 디렉터리>\0<리포 안의 위치>`,
  밖이면 `dir\0<실제 경로>` 를 SHA-256 으로 해시해 `c-` + 16자, 키를 구할 때 git 지역 변수를 비운다. `clone_key_module` 을 없앤다. 한 실행에서
  키를 한 번 계산하는 캐시는 그대로다
- `src/harness/commands/clone_key.py`: `clone-key expand <값>` — 하네스 루트(`--target`)의 키로 `{clone}` · `{project}` 를 전부 바꾼 한 줄과 0.
  자리표시가 없으면 git 을 부르지 않는다. `~` 와 환경 변수는 풀지 않는다. 인자가 맞지 않거나 계산이 실패하면 아무것도 내지 않고 1.
  설정을 읽지 않는다. 처리하지 않은 예외는 1
- `COMMANDS` 항목(인수 `expand <text>`, 설명 `print the text with {clone} and {project} replaced by this clone's key`)과 `DELEGATES`
- `src/templates/managed/script/_clone_key.py` → python3 shim. CLI 를 찾지 못하면 아무것도 내지 않고 1. 바이트코드를 남기지 않는다
- 단위 테스트 `src/test/unit/test_clone_key.py` — 10-5 의 "클론 키" 행
- `src/test/render-test.sh`: UT-106 ~ UT-110 의 `python3 script/_clone_key.py expand` 준비부는 고치지 않고 shim 을 거쳐 통과한다. 10-3 의 1
  (`_clone_key.py expand '{clone}'` 의 키가 직접 부른 것과 같다) · 4(CLI 를 치운 샌드박스에서 1 · 출력 없음) · 5 · 10 블록에 케이스를 더한다
- 건드릴 파일: `src/harness/home/clone_key.py`, `src/harness/commands/clone_key.py`(신규), `src/harness/commands/__init__.py`,
  `src/harness/cli.py`, `src/templates/managed/script/_clone_key.py`, `src/test/unit/test_clone_key.py`(신규), `src/test/render-test.sh`,
  render 로 갱신되는 `script/` · `.harness/managed`

### 완료 조건

- [ ] CLI 패키지에 `_clone_key.py` 를 경로로 불러오는 코드(`clone_key_module`)가 없고, 키를 계산하는 코드가 `home/clone_key.py` 하나다
- [ ] 같은 하네스 루트의 키가 이 task 전과 같다 — 기존 등록부 · 지표 · 사용 기록 경로가 그대로 이어진다
- [ ] `script/_clone_key.py expand <값>` 이 받은 인자를 그대로 `<CLI> --target <루트> clone-key` 로 넘기고 UT-106 ~ UT-110 이 기대값 그대로 통과한다
- [ ] CLI 를 찾지 못하면 shim 이 아무것도 내지 않고 1 로 끝난다
- [ ] 실행 뒤 `script/` 와 고정 사본 아래에 `__pycache__` 가 없다
- [ ] `script/run-lint-test.sh --commit` 과 `src/test/render-test.sh` 가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | git 트리 안의 해시 입력 | 리포의 서브디렉터리를 하네스 루트로 | `git\0<공통 디렉터리 실제 경로>\0<위치>` 의 해시 |
| UT-02 | git 트리 밖의 해시 입력 | git 이 아닌 디렉터리 | `dir\0<실제 경로>` 의 해시 |
| UT-03 | git 지역 변수 | `GIT_DIR` 이 다른 리포를 가리키는 환경 | UT-01 과 같은 키 |
| UT-04 | 자리표시 없음 | `plain` | git 을 부르는 함수를 부르지 않고 그대로 |
| UT-05 | 명령줄 | `expand` 인자 없음 · `expand a b` | 출력 없이 1 |
| UT-06 | 옛 키와 같음 | 이 task 전 모듈로 구한 키와 같은 루트 | 같은 키 |

## T12 · feat: 검증 실행을 verify 하위 명령으로 옮기고 harness-verify.sh 를 설정과 무관한 생성 shim 으로 전환

### 상위 Requirement

- relates to #213

### 작업 내용

검증 일괄(`run-lint-test.sh`)과 단계 실행(생성물 `harness-verify.sh`)을 `src/harness/verify.py` 와 하위 명령 `harness verify` 로 옮긴다.
단계 목록은 검증할 때 공유 설정에서 읽어, render 하지 않은 `[commands]` · `[verify]` 변경도 바로 반영된다. `script/harness-verify.sh` 는
설정과 무관한 생성 shim 이 된다. 통과 기록은 셸 검증 스크립트가 남긴 것을 그대로 읽는다.

- 명세 1절 "바뀌는 것" 의 검증 항목 · 2-1 · 2-7 · 4-1 · 4-2 · 5-2 · 7절 · 10-3 의 1 · 4 · 5 · 7 · 8 · 10 · 10-4 의 UT-53 · 10-5 의 "검증" 행
- `src/harness/verify.py`
  - 단계 목록: `verify_steps()` 와 같은 순서(`[verify].checks` 를 적은 순서, 코드 검사, 테스트). `verify.script_tests` 가 참이면 맨 앞에
    "하네스 스크립트 회귀" 단계가 지금 명령 그대로. `HARNESS_SCRIPT_TESTS=off` 면 그 단계는 출력 없이 빠진다
  - 단계 실행: `--commit` 의 push 단계 건너뛰기 문구, 통과 기록 건너뛰기 문구, `verify: <이름>` 과 하네스 루트의 `bash -c <명령>`,
    `verify: FAIL <이름>` 과 1(다음 단계는 돌지 않음), `verify: ok` 와 0. 단계가 없으면 명세 2-7 의 두 줄과 3
  - 통과 기록(ADR 0018): 켜지는 조건, 자리 `<git 공통 디렉터리>/harness-verify/<키>`, 키(`<이름>` · 개행 · `<명령>` 의 `git hash-object --stdin`),
    내용(트리 해시), 실제 인덱스 사본에 `git add -A .` 뒤 `git write-tree`, `git diff -z --no-renames --relative --name-only <기록한 트리> <지금 트리>`
  - 경로 glob 은 bash `case` 패턴의 뜻(`*` 가 `/` 를 넘음, `?` · `[…]` · `[!…]` · `[^…]` · `\`). 경로가 없는 단계는 무엇이든 바뀌면 돈다
  - 스팬: 기본 동작은 `run-lint-test` 아래 `harness-verify` 아래 단계마다 `verify/<이름>`, `--steps-only` 는 `harness-verify` 부터. 환경의 부모
    스팬에 붙는다. 기록하지 않을 때는 단계의 표준 오류를 파이프로 받지 않는다. 기록기(T8)에 클론 키 모듈로 푼 디렉터리를 넘긴다
- `src/harness/commands/verify.py`: 기본 동작(생성물 일치 검사 — `harness check` 와 같은 출력, 채운 옛 `script/verify-project.sh` 가 있으면
  인자 없이 `bash`, 아니면 받은 인자로 단계 실행 — 인자는 이 단계에서만 검사), `--steps-only`(인자 `--commit` · `--no-cache`, 그 밖은 사용법과
  2). 공유 설정을 읽지 못하면 그 안내와 1. 처리하지 않은 예외는 1
- `COMMANDS` 항목(인수 `[--commit] [--no-cache] [--steps-only]`, 설명은 명세 2-1 표)과 `DELEGATES`
- `src/templates/managed/script/run-lint-test.sh` → POSIX sh shim. CLI 를 찾지 못하면 두 줄과 1
- `verify_script()`: 명세 4-1 의 shim(`verify --steps-only`, CLI 를 찾지 못하면 두 줄과 1)을 생성 파일 머리글과 함께 낸다. `[commands]` ·
  `[verify]` 를 바꿔도 내용이 같다. `plan()` 의 등록은 그대로이고, 규칙 문서 3장의 명령 표와 단계 순서 문장은 지금처럼 설정을 따라 바뀐다
- 진입점을 부르는 곳(pre-push · post-commit 훅, doctor 의 `verification` 절, `harness fix verify`, `harness schema` 의 `verify_script`)은 바꾸지 않는다
- 기존 검사 줄(대응표에 적는다): UT-53 의 `script/harness-verify.sh` 가 `step '테스트'` 를 담는지 보던 줄 → `verify --steps-only` 출력에
  `verify: 테스트` 가 있다
- 단위 테스트 `src/test/unit/test_verify.py` — 10-5 의 "검증" 행
- `src/test/render-test.sh`: 10-3 의 1(`run-lint-test.sh` 통과, `harness-verify.sh` 의 미설정 3) · 4(CLI 를 치운 샌드박스의 `run-lint-test.sh` 가
  1 과 두 줄) · 5 · 7 · 8 · 10 블록에 케이스를 더한다
- `src/bin/harness render` 로 이 리포의 `script/run-lint-test.sh` · `script/harness-verify.sh` · `.harness/managed` · `.harness/generated` 를 갱신한다.
  이 커밋부터 이 리포의 검증 일괄이 새 구현으로 돈다
- 건드릴 파일: `src/harness/verify.py`(신규), `src/harness/commands/verify.py`(신규), `src/harness/commands/__init__.py`, `src/harness/cli.py`,
  `src/harness/render/scripts.py`, `src/templates/managed/script/run-lint-test.sh`, `src/test/unit/test_verify.py`(신규), `src/test/render-test.sh`,
  render 로 갱신되는 `script/` · 생성 파일 · `.harness/managed` · `.harness/generated`

### 완료 조건

- [ ] `script/run-lint-test.sh` 와 `script/harness-verify.sh` 가 받은 인자를 그대로 `verify` · `verify --steps-only` 로 넘기고 출력 · 종료 코드 0 · 1 · 2 · 3 이 옛 스크립트와 같다
- [ ] `[verify].checks` 를 render 없이 고치면 `script/harness-verify.sh` 가 새 단계를 돌고, `[verify]` 를 바꾸고 render 해도 `script/harness-verify.sh` 의 내용이 같다
- [ ] 셸 검증 스크립트가 남긴 통과 기록이 있으면 같은 단계를 `unchanged since it last passed` 로 건너뛴다
- [ ] 통과 기록을 만들 때 실제 인덱스가 바뀌지 않는다
- [ ] 스팬이 `run-lint-test` → `harness-verify` → `verify/<이름>` 으로 이어지고 이름 · 종류 · 속성이 옛 기록과 같다
- [ ] doctor 의 `verification` 절과 `harness schema` 의 `verify_script` 가 그대로 `script/harness-verify.sh` 를 가리킨다
- [ ] 고친 검사 줄이 리뷰 요청 본문의 대응표에 적혀 있다
- [ ] `script/run-lint-test.sh --commit` 과 `src/test/render-test.sh` 가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | glob 뜻 | `src/**` · `*.py` · `a?c` · `[ab]x` · `[!a]x` · `[^a]x` · `\*` 와 표본 경로들 | bash `case` 로 대조한 결과와 같다 |
| UT-02 | 통과 기록 키 | 이름 `테스트`, 명령 `make test` | `git hash-object --stdin` 에 `테스트\nmake test` 를 넣은 값과 같다 |
| UT-03 | 단계 시점 가르기 | `on = "push"` 단계와 `--commit` | `verify: skip <이름> (push stage)` |
| UT-04 | 단계 목록 순서 | `checks` 둘 · `format_check` · `test` · `script_tests = true` | 회귀 → checks 순서대로 → 코드 검사 → 테스트, `verify_steps()` 와 같다 |
| UT-05 | 스크립트 회귀 끔 | `HARNESS_SCRIPT_TESTS=off` | 그 단계가 출력 없이 빠진다 |
| UT-06 | 인자 | `--steps-only --x` | 사용법과 2 |
| UT-07 | 미설정 | 단계가 없는 설정 | 두 줄과 3 |
| UT-08 | 셸 기록 읽기 | 키 규칙으로 만든 통과 기록과 바뀌지 않은 작업 트리 | `unchanged since it last passed` |

## T13 · refactor: 리뷰 루프 · 착수 판정 · task 동기화가 사용 기록 · 스팬 · 역할 실행을 패키지 모듈로 부름

### 상위 Requirement

- relates to #213

### 작업 내용

#211 의 하위 명령 `review` · `preflight` · `sync-tasks` 가 이식하지 않은 관리 스크립트를 부르던 경계 모듈 `src/harness/scripts.py` 를 없애고,
사용 기록 모듈 · 스팬 기록기 · 역할 실행기 모듈을 직접 부르게 한다. 출력 · 종료 코드 · 기록은 그대로다.

- 명세 5-1 의 #211 행 두 개와 `scripts.py` 문장 · 10-1
- `review` · `preflight` 의 사용 기록 줄은 사용 기록 모듈로 남긴다(종류 · 출처 · 상세는 #211 2-1-6 그대로)
- 세 명령의 실행 스팬(`review-mr` · `work-preflight` · `sync-task-issues`, 종류 `script`, 속성 `script=<이름>`)은 스팬 기록기로 남긴다.
  지금 `script/metric.py wrap` 으로 자기를 다시 띄워 감싸던 일(`HARNESS_METRIC_SELF`)을 명령 안에서 한다 — 인자가 틀린 실행도 스팬 하나를 남기고,
  리뷰어 스팬이 `review-mr` 스팬의 자식이고, 실패한 실행에 `capture_logs` 대로 표준 오류 끝부분이 남는 것이 그대로다. 자리표시는 클론 키
  모듈로 풀어 넘긴다
- `review` 의 러너 점검과 리뷰어 실행은 역할 실행기 모듈을 부른다(이식 전과 같은 인자 · 입출력)
- 부르는 방법(같은 프로세스 · 하위 프로세스)은 구현이 고른다
- `scripts.py` 를 불러오거나 바꿔 끼우던 #211 단위 테스트 준비부는 해당 모듈로 바꾼다. 대응표에 적는다
- 건드릴 파일: `src/harness/scripts.py`(삭제), `src/harness/commands/review.py` · `preflight.py` · `sync_tasks.py`, `src/harness/review.py`,
  `src/test/unit/` 의 #211 테스트

### 완료 조건

- [ ] `src/harness/scripts.py` 가 없고, #211 하위 명령이 `script/usage-log.sh` · `script/metric.py` · `script/run-agent.py` 를 부르지 않는다
- [ ] `review` · `preflight` 의 사용 기록 줄, 세 명령의 스팬 이름 · 종류 · 속성 · 부모 관계가 옛 기록과 같다
- [ ] 인자가 틀린 실행도 스팬 하나를 남긴다
- [ ] `test-review-loop.sh` · `test-work-preflight.sh` · `test-sync-task-issues.sh` 와 #211 단위 테스트가 기대값 그대로 통과한다
- [ ] `script/project/check-cli.py imports` 가 위반을 내지 않는다
- [ ] `script/run-lint-test.sh --commit`, 위 셸 테스트, `src/test/render-test.sh` 가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 리뷰 사용 기록 | 페이크로 `review` 를 회차 상한에서 멈추게 | 기록 줄 `review|review-mr|mr=<번호> round=<회차> exit=3 stop=mrl-cap|…` 가 옛 줄과 같다 |
| UT-02 | 착수 판정 사용 기록 | 2-4 표에 라벨이 있는 경로 · 없는 경로 | 앞의 것만 한 줄 |
| UT-03 | 실행 스팬 | 세 명령 각각 | 이름 · 종류 `script` · 속성 `script=<이름>` 이 옛 스팬과 같다 |
| UT-04 | 틀린 인자의 스팬 | `review` 인자 없음 | 2 와 스팬 하나 |
| UT-05 | 리뷰어 스팬 부모 | 페이크 리뷰어로 `review` 한 회차 | 리뷰어 스팬의 부모가 `review-mr` 스팬 |

## T14 · feat: 권한 허용 목록에 하위 명령 묶음 추가

### 상위 Requirement

- relates to #213

### 작업 내용

`.claude/settings.json` 의 허용 목록에 이 이슈가 더한 하위 명령의 규칙 넷을 더한다. 기존 규칙 · 제외 목록 · deny · 명령 가드는 그대로다.

- 명세 6절 · 10-3 의 6
- `src/harness/render/settings.py` 의 `allow_rules()`
  - 묶음 규칙 `Bash(<CLI> <명령>:*)` — 명령은 `run-agent` · `span` · `usage` · `verify`
  - `<CLI>` 는 하네스 루트가 소스 리포(`source_tree()`)면 `src/bin/harness`, 아니면 `.harness/bin/harness`(ADR 0013)
  - 순서: 관리 스크립트 규칙 다음, forge 규칙 앞, 명령 이름 오름차순
  - 묶음의 명령 이름은 상수 하나가 갖는다. 그 이름이 `COMMANDS` 에 없으면 render 를 거부한다:
    `error: permission list names a command that does not exist: <이름>`
  - `carryover` · `rollback` · `clone-key` 는 넣지 않는다. 관리 스크립트 묶음의 `rollback-work.sh` · `create-carryover-issue.sh` 제외와
    `_` 로 시작하는 모듈 스크립트 제외는 그대로다
- `src/bin/harness render` 로 이 리포의 `.claude/settings.json` 을 갱신한다 — 소스 리포이므로 `src/bin/harness <명령>`
- `src/test/render-test.sh`: 10-3 의 6 블록
- 건드릴 파일: `src/harness/render/settings.py`, `src/test/render-test.sh`, render 로 갱신되는 `.claude/settings.json` · `.harness/generated`

### 완료 조건

- [ ] 설치한 리포의 허용 목록에 `Bash(.harness/bin/harness <명령>:*)` 가, 소스 트리 복제본에 `Bash(src/bin/harness <명령>:*)` 가 네 명령 모두 있다
- [ ] `carryover` · `rollback` · `clone-key` 규칙이 없다
- [ ] 기존 규칙이 전부 남고 묶음이 관리 스크립트 규칙 뒤 · forge 규칙 앞에 오름차순으로 있다
- [ ] 묶음 상수에 `COMMANDS` 에 없는 이름이 있으면 render 가 명세 6절의 문구와 0 이 아닌 종료 코드로 멈추고 파일을 바꾸지 않는다
- [ ] deny 와 명령 가드가 바뀌지 않는다
- [ ] `script/run-lint-test.sh --commit` 과 `src/test/render-test.sh` 가 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 설치한 리포 | `harness install` 한 리포의 `.claude/settings.json` | `.harness/bin/harness` 접두 규칙 넷 |
| UT-02 | 소스 트리 | 소스 트리 복제본의 `.claude/settings.json` | `src/bin/harness` 접두 규칙 넷 |
| UT-03 | 넣지 않는 명령 | 위 두 파일 | `carryover` · `rollback` · `clone-key` 규칙 없음 |
| UT-04 | 순서와 기존 규칙 | 위 두 파일 | 관리 스크립트 규칙 → 묶음(오름차순) → forge 규칙, 기존 규칙 전부 |
| UT-05 | 없는 명령 이름 | 묶음 상수에 없는 이름을 넣고 render | `error: permission list names a command that does not exist: <이름>`, 파일 그대로 |

## T15 · docs: README · 스크립트 목록 · 변경 안내 · 설정 주석에 하위 명령과 shim 반영

### 상위 Requirement

- relates to #213

### 작업 내용

T3 ~ T14 가 만든 사실을 사람용 설명과 설정 주석에 적는다.

- 명세 9절의 `README.md` · `src/templates/managed/script/README.md` · `changing.md` · `defaults.toml` · `harness.toml` · `review-checks.md` 행
- `README.md`
  - "명령" 표: 일곱 명령의 행
  - "`harness.toml` 이 정하는 것": `verify.checks` · `test_paths` · `test_on` · `incremental` · `script_tests` 행 — 생성 파일이 아니라 검증
    (`script/run-lint-test.sh` · pre-push · CI)이 실행할 때 읽는다. `usage.log_path` · `env_var` 행 — 기록 · 집계 명령
  - "검증": 회귀 테스트 건수를 실제와 맞춘다
  - "언어": 표지의 정본은 `src/harness/format.py`, 셸 표기는 `script/harness-format.sh`
- `src/templates/managed/script/README.md`
  - "목록": 명세 4-1 의 아홉 파일은 "shim — `harness <명령>`" 과 그 명령의 계약. `harness-format.sh` · `usage-vocab.sh` 는 셸 표기. `_clone_key.py` 행
  - "규칙": 값은 하위 명령이 공유 설정에서, 역할 실행기 · 스팬 기록은 실행 계획에서 실행할 때 받는다(남은 셸 소비자는 `harness.env`). 기계가
    읽는 문자열의 정본은 `src/harness/format.py`. 새 하네스 로직은 패키지의 하위 명령으로 두고 `script/` 에 로직을 담은 스크립트를 더하지 않는다
- `src/templates/managed/docs/workflow/changing.md`: "명령과 검증" 문단 — 규칙 문서 3장이 생성되고 검증이 실행할 때 공유 설정의 `[commands]` ·
  `[verify]` 를 읽는다. "리뷰 · 이슈 본문의 표지 문자열" 행 — `src/harness/format.py` + 셸 표기 + 해당 계약 · 양식
- `src/templates/defaults.toml` 과 이 리포의 `harness.toml` 의 `[commands]` 머리 주석: 규칙 문서(AI_AGENT.md 3장)가 여기서 생성되고, 검증
  (`script/run-lint-test.sh`)이 실행할 때 읽는다
- `.ai/project/review-checks.md` 표지 행: 표지(`src/harness/format.py` 와 셸 표기 `script/harness-format.sh`)를 바꿨으면 그것을 쓰는 역할 계약도
  같은 변경에 있는가
- `docs/workflow/flow.md` 와 절차 · 역할 문서는 바꾸지 않는다
- `src/bin/harness render` 로 이 리포의 `script/README.md` · `docs/workflow/changing.md` 사본과 생성 파일을 갱신한다
- 건드릴 파일: `README.md`, `src/templates/managed/script/README.md`, `src/templates/managed/docs/workflow/changing.md`, `src/templates/defaults.toml`,
  `harness.toml`, `.ai/project/review-checks.md`, render 로 갱신되는 사본 · 생성 파일 · `.harness/managed`

### 완료 조건

- [ ] README 네 곳이 명세 9절 표의 사실을 담고 회귀 테스트 건수가 실제와 같다
- [ ] 스크립트 목록의 아홉 shim 행이 부르는 하위 명령과 그 계약을 적고, 두 셸 표기 행이 정본 위치를 적는다
- [ ] `changing.md` · 두 `[commands]` 머리 주석 · `review-checks.md` 표지 행이 명세 9절 표의 사실을 담는다
- [ ] `docs/workflow/flow.md` 와 절차 · 역할 문서가 바뀌지 않는다
- [ ] 추가한 문장에 개인 홈 절대 경로가 없다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정과 render 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 문서 참조 | `harness doctor` | 고친 문서가 가리키는 경로가 모두 있다 |
| UT-03 | 반영 확인 | `README.md` · `script/README.md` · `docs/workflow/changing.md` | 명세 9절 표의 사실이 있다 |

## T16 · docs: 다른 명세의 표지 · 클론 키 · 허용 목록 서술을 하위 명령 기준으로 갱신

### 상위 Requirement

- relates to #213

### 작업 내용

이 이슈가 바꾼 표지 정본 · 클론 키 모듈 · 허용 목록 순서를 다른 명세의 현재형 서술에 맞춘다.

- 명세 9절의 `docs/spec/` 행
- `docs/spec/96-machine-local-state-key.md` 1-2 · 2-3 — 클론 키를 계산하고 푸는 곳은 `src/harness/home/clone_key.py` 이고 `script/_clone_key.py` 는
  `clone-key` 의 shim
- `docs/spec/64-modularize-cli-review-scripts.md` 6절 — 표지의 정본은 `src/harness/format.py`
- `docs/spec/70-generate-permission-allow-list.md` 6절 — 허용 목록의 순서에 하위 명령 묶음
- `docs/spec/209-port-forge-adapters.md` 2-1 · 3-3 · 8-5 — `markers()` 는 내장 값을 돌려주고 `FormatError` 가 없다, 표지의 정본은
  `src/harness/format.py`, 3-3 의 "표지를 읽지 못한다" 행 삭제, 8-5 의 `test_format.py` 행은 내장 값과 셸 표기의 일치
- `docs/spec/210-port-guards-and-hooks.md` 1 · 6 · 8-1 · 8-2 · 9-4 — 허용 표지의 정본은 `src/harness/format.py`, 6절의 `markers()` 정의와 허용
  표지 읽기 실패 문구 삭제, 8-1 시크릿 스캔 행의 "표지를 읽지 못하면 2" 와 8-2 의 표지 파일이 없을 때 행 삭제, 9-4 의 두 행은 이 명세 10-4 대로
- `docs/spec/211-port-work-steps.md` 2-1-5 · 5-4 — 2-1-5 의 표지 행은 "표지 모듈이 돌려준 값을 쓴다" 만 남긴다, 5-4 의 "표지" 행 삭제
- `docs/spec/212-drive-work-loop.md` 5절 — 끝 항목의 "필요한 표지를 읽지 못하면 … 종료 코드 2" 삭제
- 건드릴 파일: 위 일곱 명세

### 완료 조건

- [ ] 일곱 명세의 해당 절이 명세 9절 표의 서술을 담는다
- [ ] 일곱 명세 어디에도 `FormatError` 와 표지를 읽지 못해 2 로 끝나는 서술이 남지 않는다
- [ ] 각 명세의 다른 절은 바뀌지 않는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 실패 서술 없음 | `docs/spec/209-*` · `210-*` · `211-*` · `212-*` | `FormatError` · 표지 읽기 실패의 종료 코드 2 서술 없음 |
| UT-02 | 정본 위치 | 64 · 209 · 210 의 표지 서술, 96 의 클론 키 서술 | `src/harness/format.py` · `src/harness/home/clone_key.py` |
| UT-03 | 문서 참조 | `harness doctor` | 고친 명세가 가리키는 경로가 모두 있다 |

## T17 · docs: 아키텍처 · 용어 · 테스트 문서에 하위 명령과 패키지 정본 반영

### 상위 Requirement

- relates to #213

### 작업 내용

T3 ~ T14 로 생긴 하위 명령 · 공용 모듈 · shim 을 에이전트가 근거로 읽는 문서에 적는다.

**보호 문서를 수정하는 task 다.** 2026-10-09 결정 게이트에서 사용자가 허용한 범위 — 명세 11절 — 안에서만 고친다. 그 범위 밖은 고치지 않는다.
권한 설정 · 가드에 걸리면 사람이 대응한다.

- 명세 11절. 같은 절을 앞 명세들이 #206 → #207 → #208 · #209 · #210 → #211 → #212 순서로 먼저 고친 문장 위에 더한다
- `.ai/project/architecture.md` — 11-1 표의 열 행
  - "구성 요소" 의 CLI 패키지 항목: 하위 명령 일곱과 공용 모듈 여섯. #210 이 덧붙인 표지 읽기 문장을 "표지는 `src/harness/format.py` 가 값으로
    갖는다 — `script/harness-format.sh` 는 같은 값을 셸에 둔 표기다" 로
  - "구성 요소" 의 대상 리포 `script/`: 일곱 파일은 shim, 두 파일은 셸 표기
  - "데이터 흐름" 의 절차 실행 · 실행 지표: 역할 실행기 · 스팬 기록 표기와 지표 설정 문장(11-1 표의 문안 그대로)
  - "신뢰 경계" 의 명령줄 인자: 부른 쪽이 주는 입출력 파일은 절대 경로도 받는다
  - "새 코드를 둘 곳": 사용량 파서는 `src/harness/runner.py` 의 `PARSERS`, 새 관리 스크립트 대신 패키지의 하위 명령, 표지는 `format.py` 와 셸
    표기를 같은 변경에서, #211 의 `scripts.py` 줄 삭제와 지표 기록 코드 → `src/harness/metrics/recorder.py`
  - "계층과 의존 방향": #207 ③ 구절과 #211 덧문장을 11-1 표의 문안으로 바꾸고, 공유 설정 문장과 클론 키 문장을 더한다. #209 의 forge 문장과
    #211 의 "표지는 표지 모듈로만 읽는다" 는 그대로 둔다
- `.ai/project/glossary.md` — 11-2 표의 넷: "실행 계획" · "이월 이슈" · "표지" · "클론 키" 행. 새 행을 더하지 않는다(`shim` 은 #209 의 행)
- `.ai/project/testing.md` — 11-3 표의 둘: 관리 스크립트 셸 테스트는 shim 을 거쳐 하위 명령을 보는 계약 테스트, 단위 테스트 층에 이 이슈가 옮긴
  모듈(표지 · 사용 기록 · 스팬 기록기 · 검증 · 이월 이슈 · 되감기 · 역할 실행기 · 클론 키)
- `.ai/project/scope.md` 는 고치지 않는다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/architecture.md`, `.ai/project/glossary.md`, `.ai/project/testing.md`, render 로 갱신되는 `.ai/AI_AGENT.md` ·
  `.harness/generated`

### 완료 조건

- [ ] `.ai/project/architecture.md` 가 11-1 표의 열 행을 담고 `src/harness/scripts.py` · "스크립트는 고정 사본 CLI 의 `run-plan` 으로" 서술이 없다
- [ ] `.ai/project/glossary.md` 가 11-2 표의 네 행을 담고 새 용어 행이 없다
- [ ] `.ai/project/testing.md` 가 11-3 표의 두 사실을 담는다
- [ ] 세 문서에서 명세 11절 밖의 문장이 바뀌지 않고 `.ai/project/scope.md` 가 그대로다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 2장 · 5장이 세 문서와 일치한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/213-retire-shell-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 반영 확인 | `.ai/AI_AGENT.md` | 5장에 하위 명령 일곱 · 공용 모듈 여섯 · shim, 2장에 표지 · 클론 키 · 이월 이슈 · 실행 계획의 새 서술 |
| UT-03 | 범위 | 세 문서의 diff | 명세 11절 표의 위치만 바뀐다 |
