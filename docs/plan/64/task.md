# #64 task

## T1 · fix: 회귀 테스트의 기록 경로를 테스트 작업 디렉터리로 격리

### 상위 Requirement

- relates to #64

### 작업 내용

`render-test.sh` 가 `install` 로 만든 임시 리포와 `setup()` 으로 만든 대상은 기본 설정의 `[metrics].dir` ·
`[usage].log_path`(실제 홈 아래)를 그대로 써서, 회귀 테스트를 돌릴 때마다 실제 홈에 지표와 사용 기록이 쌓인다.
또 `setup()` 의 `^dir = ` 치환이 설정 파일에서 처음 나오는 `dir =` 줄을 바꾸는데, 기본 설정에서 그 줄은
`[metrics]` 절의 것이어서 ADR 디렉터리 값이 `[metrics].dir` 에 들어간다. 두 기록 경로를 테스트 작업 디렉터리
아래로 옮기고 ADR 디렉터리 치환을 `[adr]` 절로 한정한다.

- 명세 10절 · 12-2 의 "설치 리포의 기록 경로" · "`setup()` 의 ADR 디렉터리" 케이스
- `install` 로 만든 임시 리포(`$work/installed` · `$work/secret`)는 설치 직후
  `harness set --target <리포> metrics.dir <$work 아래 경로> usage.log_path <$work 아래 경로>` 로 두 값을 옮긴다
- `setup()` 은 `[adr]` 절 안의 `dir =` 줄만 `docs/adr` 로 바꾸고, 대상의 `[metrics].dir` · `[usage].log_path` 를
  그 대상의 테스트 작업 디렉터리 아래 경로로 둔다. `metrics.dir` 을 직접 정하는 기존 케이스는 지금처럼 `harness set` 으로 덮는다
- 관리 스크립트의 `test-*.sh` 중 기록을 남기는 스크립트(`usage-log.sh` · `metric.py` 를 부르는 것)를 임시 배치에
  함께 두는 것은, 배치한 `harness.env` 의 `USAGE_LOG_PATH` 와 `harness.plan.json` 의 `metrics.dir` 을 샌드박스 경로
  또는 `off` 로 덮는다. `test-review-loop.sh` 의 배치가 그 형식이고, 나머지 `test-*.sh` 를 같은 기준으로 확인해 맞춘다
- 제품의 경로 해석(`script/metric.py` · `script/usage-log.sh`)과 `HOME` 은 바꾸지 않는다. 이미 실제 홈에 생긴 기록을 지우지 않는다
- 건드릴 파일: `src/test/render-test.sh`, 필요하면 `src/templates/managed/script/test-*.sh` 와 render 로 갱신되는 `script/` 사본

### 완료 조건

- [ ] `setup()` 으로 만든 대상의 `harness.toml` 에서 `[adr].dir` 이 `docs/adr` 이고 `[metrics].dir` 은 `docs/adr` 가 아니다
- [ ] `setup()` 으로 만든 대상의 `script/harness.plan.json` 의 `metrics.dir` 과 `script/harness.env` 의 `USAGE_LOG_PATH` 가 테스트 작업 디렉터리 아래를 가리킨다
- [ ] `$work/installed` · `$work/secret` 의 `script/harness.env` 의 `USAGE_LOG_PATH` 와 `script/harness.plan.json` 의 `metrics.dir` 이 `$work` 아래를 가리킨다
- [ ] 설치본의 검증 일괄(`script/run-lint-test.sh`)을 돈 뒤 지표가 `$work` 아래 경로에 남는다
- [ ] 기록을 남기는 스크립트를 배치하는 `test-*.sh` 가 모두 배치한 설정의 두 기록 경로를 샌드박스 경로 또는 `off` 로 덮는다
- [ ] `render-test.sh` 와 관리 스크립트 테스트가 `HOME` 을 바꾸지 않는다
- [ ] `src/bin/harness render` 뒤 사본이 정본과 같고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/64-modularize-cli-review-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | ADR 디렉터리 치환이 `[adr]` 절에만 닿는다 | `setup()` 으로 만든 대상의 `harness.toml` | `[adr].dir` = `docs/adr`, `[metrics].dir` ≠ `docs/adr` |
| UT-02 | `setup()` 대상의 기록 경로가 작업 디렉터리 아래다 | 같은 대상의 `script/harness.plan.json` · `script/harness.env` | `metrics.dir` · `USAGE_LOG_PATH` 가 그 대상의 테스트 작업 디렉터리 아래 경로 |
| UT-03 | 설치 리포의 기록 경로가 `$work` 아래다 | `$work/installed` · `$work/secret` 의 두 생성물 | `USAGE_LOG_PATH` · `metrics.dir` 이 `$work` 로 시작 |
| UT-04 | 설치본 검증 일괄의 지표가 격리 경로에 남는다 | `$work/installed` 에서 `script/run-lint-test.sh` 실행 | 옮긴 `metrics.dir` 아래에 스팬 파일이 생긴다 |

## T2 · refactor: 리뷰 입력 구성의 내장 파이썬을 리뷰 루프 공용 모듈로 이동

### 상위 Requirement

- relates to #64

### 작업 내용

`review-mr.sh` 본문의 `python3 -c` 와 파이썬 heredoc(실행 계획 조회, 리뷰 요청 JSON 필드 읽기, 회차 라벨 계산,
종료 참조 추출, 리뷰 입력 맥락 구성)을 공용 모듈 `script/_review.py` 의 하위명령으로 옮긴다. 수행 결과는 같다.

- 명세 5절의 하위명령 `plan-exe` · `mr-field` · `round` · `issue-ref` · `context` 와 모듈 규칙
- 모듈은 표준 라이브러리만 쓰고 스크립트로 실행한다(`python3 script/_review.py <하위명령> <인자…>`). import 하지 않는다
- 표지는 하드코딩하지 않는다. `review-mr.sh` 가 `script/harness-format.sh` 를 `set -a` 로 source 하고, 모듈은 환경의
  `FMT_*` 를 쓴다. 필요한 표지가 환경에 없으면 종료 코드 2
- `context` 의 절 추출은 제목이 일치하는 절을 같은 수준 이상의 다음 제목까지 읽고, 두 절을 모두 찾지 못하면 본문 전체를
  넘기는 지금 동작 그대로다. 인용 접두(`> `)와, 맥락 조회·구성 실패가 리뷰를 막지 않는 동작(경고 후 diff 만 넘김)도 그대로다
- `script/README.md` 표에 `_review.py` 행을 더한다. 부르는 곳은 `review-mr.sh`
- 건드릴 파일: `src/templates/managed/script/_review.py`(신규), `src/templates/managed/script/review-mr.sh`,
  `src/templates/managed/script/test-review-loop.sh`(샌드박스 배치에 `_review.py` 복사), `script/README.md` 의 정본, render 로 갱신되는 `script/` 사본

### 완료 조건

- [ ] `review-mr.sh` 본문에 `python3 -c` 와 파이썬 heredoc 이 없다
- [ ] `_review.py` 가 표준 라이브러리만 import 하고, 실행 뒤 `script/__pycache__` 가 생기지 않는다
- [ ] `_review.py` 본문에 표지 값 리터럴이 없고, 필요한 `FMT_*` 가 환경에 없으면 종료 코드 2 로 끝난다
- [ ] `test-review-loop.sh` 의 기존 케이스(회차, 증분, 리뷰 입력, 맥락 절 추출, 맥락 실패 시 diff 만 넘김)가 같은 기대값으로 통과한다
- [ ] `script/README.md` 표에 `_review.py` 행이 있다
- [ ] `src/bin/harness render` 뒤 `script/` 사본이 정본과 같고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/64-modularize-cli-review-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 리뷰 요청 조회 스크립트에 내장 파이썬이 없다 | `review-mr.sh` 본문 | `python3 -c` · `python3 -` heredoc 없음 |
| UT-02 | 맥락 절 추출 | 목적·리뷰 요청 포인트 절이 있는 리뷰 요청 본문 / 두 절이 없는 본문 | 전자는 두 절만, 후자는 본문 전체가 리뷰 입력에 든다 |
| UT-03 | 회차 계산 | `<prefix>:1` · `<prefix>:3` 라벨과 다른 라벨이 섞인 목록 / 회차 라벨이 없는 목록 | 최댓값 `3` 과 해당 라벨 목록 / `0` |
| UT-04 | 표지 누락 | `FMT_*` 가 없는 환경에서 `_review.py` 하위명령 실행 | 종료 코드 2 |
| UT-05 | 바이트코드를 남기지 않는다 | 샌드박스에서 리뷰 루프 실행 | 샌드박스 `script/__pycache__` 없음 |

## T3 · feat: 리뷰 판정을 판정 데이터로 검증·집계하고 등록 댓글을 렌더링

### 상위 Requirement

- relates to #64

### 작업 내용

리뷰어·보안 검토자의 출력 계약을 판정 데이터(JSON 블록 하나)로 바꾸고, `post-review.sh` 가 그 블록을 스키마로
엄격히 검증해 데이터로 집계한 뒤 요약·인라인 댓글을 하네스가 렌더링하게 한다. 판정은 마크다운 제목·행 문법을 읽지
않는다. 결정 근거는 `docs/adr/0014-review-verdicts-are-structured-data.md` 다.

- 명세 2절(블록·스키마·계약 위반) · 3절(판정과 집계) · 4절(요약·인라인 댓글 렌더링) · 5절의 `judge` · `render` ·
  6절(표지) · 7절(계약·절차 문서) · 12-1
- `post-review.sh` 의 파이썬을 `_review.py` 의 `judge` · `render` 로 옮긴다. 두 스크립트 본문에 파이썬이 남지 않는다
- 스키마(키 이름·허용 값)는 모듈 안 한 곳에 정의하고 검증·집계·렌더링이 함께 쓴다. 벤더 CLI 의 출력 스키마 강제 옵션을 쓰지 않는다
- 계약 위반이면 아무것도 등록하지 않고 종료 코드 2, 표준 오류 첫 줄 `contract violation: <무엇을 어겼는지>`,
  이어서 `help: nothing was posted — the raw review follows` 와 원문. 스키마 위반은 `findings[<번호>].<키>` 처럼 지목한다
- 인자·종료 코드·회차 라벨·반복 지적 누적 파일 형식(`#format 1`)·연속 회차 판정은 그대로다. 누적은 요약 등록에 성공한 뒤에만 한다
- 표지: `FMT_REVIEW_BLOCK` · `FMT_VERDICT_PASS`(`PASS`) · `FMT_VERDICT_CHANGES`(`CHANGES_REQUESTED`)를 명세 6절 값으로 두고
  `FMT_FINDINGS_HEADING` · `FMT_FINDINGS_LEVEL` 을 없앤다. 리뷰 본문 절의 머리 주석을 명세 6절대로 가른다
- 역할 계약 `code-reviewer.md` · `security-guard.md` · `developer.md` 와 절차 조각 `workflows/work/review.md` · `branch.md` 를
  명세 7절 표대로 고친다. `src/templates/agents/` 의 등록 명령은 그대로다
- `script/README.md` 의 `_review.py` 행을 명세 5절 설명(판정 데이터 검증·집계·등록 댓글 렌더링·리뷰 입력 맥락)으로 채우고 부르는 곳에 `post-review.sh` 를 더한다
- 건드릴 파일: `src/templates/managed/script/{_review.py,post-review.sh,harness-format.sh,test-review-loop.sh}`,
  `src/templates/managed/.ai/templates/{code-reviewer.md,security-guard.md,developer.md}`,
  `src/templates/workflows/work/{review.md,branch.md}`, `script/README.md` 의 정본, render 로 갱신되는 사본·생성 파일

### 완료 조건

- [ ] `post-review.sh` 본문에 `python3 -c` 와 파이썬 heredoc 이 없다
- [ ] 판정이 `findings` 의 blocker + major 건수로 정해지고, `verdict` 가 집계와 다르면 요약 댓글에 선언 줄이 남는다
- [ ] 블록 없음·블록 둘·JSON 파싱 실패·스키마 위반 각각에서 종료 코드 2 이고 등록 호출이 0 이며, 표준 오류에 명세 2-3 의 머리 두 줄과 원문이 있다
- [ ] 블록 밖 텍스트가 집계와 등록 댓글에 닿지 않는다
- [ ] 요약·인라인 댓글이 명세 4절 형식으로 렌더링되고, 다음 회차의 `review-mr.sh` 가 그 댓글로 직전 요약·발견 스레드·증분 기준 리비전을 읽는다
- [ ] `harness-format.sh` 에 `FMT_FINDINGS_HEADING` · `FMT_FINDINGS_LEVEL` 이 없고 명세 6절의 표지가 있다
- [ ] 모듈이 정의한 키 이름·허용 값과 표지 `FMT_REVIEW_BLOCK` 이 `code-reviewer.md` · `security-guard.md` 에 모두 있다
- [ ] 역할 계약과 절차 조각에 `## 발견 사항` 절 제목 규칙과 `REVIEW_VERDICT:` 선언 규칙이 남지 않는다
- [ ] 종료 코드·회차·반복 누적·증분·리뷰 입력을 보는 기존 케이스가 같은 기대값으로 통과한다
- [ ] `src/bin/harness render` 뒤 사본·생성 파일이 정본과 같고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/64-modularize-cli-review-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 발견 없음 | `findings: []`, `verdict: PASS` | 종료 코드 0, 요약 댓글에 `발견 사항 없음` |
| UT-02 | minor 만 | minor 발견만, `verdict: CHANGES_REQUESTED` | 종료 코드 0, 요약 댓글에 선언 줄 |
| UT-03 | 같은 파일 반복 | 문장이 다른 같은 `path` 의 major 를 상한 회차 연속 | 종료 코드 3, 요약에 경로와 회차 |
| UT-04 | 위치 없음 | `path: null` 인 major | `FMT_NO_LOCATION` 키로 누적, 인라인 대상 아님 |
| UT-05 | 줄 없음 | `path` 만 있고 `line: null` 인 major | 그 `path` 로 누적, 인라인 대상 아님 |
| UT-06 | 블록 밖 텍스트 | 블록 밖에 `- [major] …` · `## 발견 사항` 이 있는 출력 | 집계 불변, 댓글에 옮겨지지 않음 |
| UT-07 | 블록 경계 위반 | 블록 없음 / 블록 둘 / JSON 파싱 실패 | 각각 종료 코드 2, 등록 호출 0 |
| UT-08 | 스키마 위반 | 필수 키 누락 · 정의되지 않은 키 · 중복 키 · 허용 밖 `severity`/`verdict` · 정수가 아닌 `line`(불리언 포함) · `path` 없이 `line` · 절대 경로·`..` 가 든 `path` · 빈 `title` · minor 가 아닌 결정 재검토 | 각각 종료 코드 2, 등록 호출 0, 표준 오류에 어긴 위치 |
| UT-09 | 요약 댓글 렌더링 | 등급이 섞이고 `out_of_scope: true` · `decision_basis` · 빈 `strengths` 인 발견 | 심각도 순 항목, `범위 밖 — 이월 필요` 줄, 근거 줄, 잘된 점 절 없음 |
| UT-10 | 인라인 댓글 렌더링 | `path` · `line` 이 있는 blocker·major | 인라인 본문이 `**[<severity>]** <title>` 로 시작 |
| UT-11 | 직전 회차 인식 | 이번 회차 `render` 결과를 다음 회차 스레드로 제공 | 리뷰 입력에 직전 요약·발견·답글, 증분 기준 리비전 |
| UT-12 | 계약·모듈 일치 | 모듈의 키 이름·허용 값, `FMT_REVIEW_BLOCK` | `code-reviewer.md` · `security-guard.md` 에 모두 있음 |
| UT-13 | 내장 파이썬 없음 | `review-mr.sh` · `post-review.sh` 본문 | `python3 -c` 와 파이썬 heredoc 없음 |

## T4 · refactor: 지표 집계와 세션 가져오기를 지표 모듈로 분리

### 상위 Requirement

- relates to #64

### 작업 내용

`src/bin/harness` 의 지표 집계와 세션 가져오기 코드를 옆의 `src/bin/harness_metrics.py` 로 옮긴다. 명령의 출력·종료 코드·파일은 같다.

- 명세 8절 · 12-2 의 "설치본의 지표 모듈" · "소스 리포의 지표 모듈" 케이스
- 모듈로 가는 것: `read_spans` · `parse_iso` · `pct` · `metrics_report` · `UNATTRIBUTED` · `claude_usage` · `codex_usage` ·
  `new_lines` · `seen` · `import_claude` · `import_codex` · `metrics_import` · `load_metric`.
  CLI 에 남는 것: `METRICS_DEFAULTS` · `metrics_cfg` · `cmd_metrics` · `cmd_run`(모듈의 `load_metric` 을 부른다)
- 모듈은 표준 라이브러리만 쓰고 `src/bin/harness` 를 import 하지 않는다. 등록부 경로 같은 CLI 의 값은 인자로 받는다
- CLI 는 `Path(__file__).resolve().parent` 에서 모듈을 찾고, import 전에 `sys.dont_write_bytecode` 를 켠다
- `cmd_install` 이 `.harness/bin/` 에 `harness` 와 함께 `harness_metrics.py` 를 복사한다
- 긴 함수(`cmd_doctor` · `validate` · `metrics_report` · `derive`)는 나누지 않는다
- 건드릴 파일: `src/bin/harness`, `src/bin/harness_metrics.py`(신규), `src/test/render-test.sh`

### 완료 조건

- [ ] 명세 8절 표의 "모듈로 가는 것" 이 `src/bin/harness` 에 정의되어 있지 않고 `src/bin/harness_metrics.py` 에 있다
- [ ] `harness_metrics.py` 가 표준 라이브러리만 import 하고 `harness` 를 import 하지 않는다
- [ ] `install` 한 리포에 `.harness/bin/harness_metrics.py` 가 있고, 그 리포에서 `harness metrics` 가 종료 코드 0 이다
- [ ] 설치본의 `.harness/bin/__pycache__` 와 소스 리포 흉내의 `src/bin/__pycache__` 가 `harness metrics` 뒤에 생기지 않는다
- [ ] `harness metrics` 와 `harness run` 의 기존 회귀 케이스가 같은 기대값으로 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/64-modularize-cli-review-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 설치본에 지표 모듈이 깔린다 | `install` 한 임시 리포 | `.harness/bin/harness_metrics.py` 존재 |
| UT-02 | 설치본에서 지표 명령이 돈다 | 그 리포에서 `harness metrics` | 종료 코드 0, `.harness/bin/__pycache__` 없음 |
| UT-03 | 소스 리포에서 지표 명령이 돈다 | `$work/source` 에 `src/bin/` 의 두 파일을 복사해 `harness metrics` | 종료 코드 0, `src/bin/__pycache__` 없음 |

## T5 · refactor: 생성물 일치 판정을 drift 하나로 통합

### 상위 Requirement

- relates to #64

### 작업 내용

`cmd_check` 와 `cmd_doctor` 가 각자 하던 생성물 일치 판정을 `drift(cfg, target, staged=False)` 하나로 모은다.
반환값은 `(경로, 사유)` 목록이고 두 명령의 출력은 같다.

- 명세 9-1 · 12-2 의 "check 와 doctor 의 일치" 케이스
- 사유 셋: `left over; the config no longer generates it` · `missing` · `differs from the config` — 조건은 명세 9-1 표
- `cmd_check` 는 목록을 지금 형식으로 출력하고 `--staged` 는 `drift(..., staged=True)` 다. `cmd_doctor` 는 건수만 쓴다
  (`<n> files differ from the config` / `<n> files match the config`)
- 건드릴 파일: `src/bin/harness`, `src/test/render-test.sh`

### 완료 조건

- [ ] 생성물 일치 판정 로직이 `drift()` 한 곳에만 있고 `cmd_check` · `cmd_doctor` 가 그것을 부른다
- [ ] 생성물 하나를 고치고 하나를 지운 리포에서 `check` 가 두 경로를 사유와 함께 내고 `doctor` 가 `2 files differ` 를 낸다
- [ ] `check --staged` 와 남은 파일(left over) 판정의 기존 회귀 케이스가 같은 기대값으로 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/64-modularize-cli-review-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | check 와 doctor 가 같은 어긋남을 본다 | 생성물 하나 수정, 하나 삭제한 리포에서 `check` · `doctor` | `check` 가 두 경로를 `differs from the config` · `missing` 과 함께 출력, `doctor` 가 `2 files differ` |
| UT-02 | 일치하는 리포 | 렌더 직후 리포에서 `doctor` | `files match the config` 건수 줄 |

## T6 · refactor: 역할 frontmatter 읽기를 role_meta 하나로 통합

### 상위 Requirement

- relates to #64

### 작업 내용

역할 어댑터 본문(`src/templates/agents/<역할>.md`)의 frontmatter 를 `agent_table` · `agent_files` · `cmd_schema` 가 각자
읽는 것을 `role_meta(name)` 하나로 모은다. 함께 `cmd_schema` 의 docstring 을 함수 첫 문장으로 옮긴다. 출력은 같다.

- 명세 9-2 · 9-3 · 12-2 의 "역할 frontmatter" 케이스
- `role_meta` 는 파일이 없으면 `{}`, 있으면 frontmatter 원래 키와 해석한 값(`headless` · `entry` · `distinct_from`), 본문(`body`)을 담은 dict 를 돌려준다
- 파일이 없을 때(`no adapter body for role`)와 키가 없을 때(`frontmatter has no summary` / `description`) `die` 하는 동작과 메시지는 호출부에 남는다
- `command_rows` 는 바꾸지 않는다
- 건드릴 파일: `src/bin/harness`, `src/test/render-test.sh`

### 완료 조건

- [ ] 역할 어댑터 본문 frontmatter 파싱이 `role_meta()` 한 곳에만 있고 `agent_table` · `agent_files` · `cmd_schema` 가 그것을 부른다
- [ ] `cmd_schema` 의 첫 문장이 docstring 이고 `harness schema` 출력이 바뀌지 않는다
- [ ] 어댑터 본문이 없는 역할과 `summary` / `description` 이 없는 본문에서 render 가 지금과 같은 메시지로 멈춘다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/64-modularize-cli-review-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 어댑터 본문이 없는 역할 | 설정에 역할을 두고 `src/templates/agents/` 에 본문이 없는 소스 트리로 render | 비0 종료, `no adapter body for role` |
| UT-02 | summary 가 없는 본문 | frontmatter 에 `summary` 가 없는 어댑터 본문으로 render | 비0 종료, `frontmatter has no summary` |
| UT-03 | description 이 없는 본문 | frontmatter 에 `description` 이 없는 어댑터 본문으로 render | 비0 종료, `frontmatter has no description` |

## T7 · docs: 아키텍처·용어 문서에 지표 모듈과 판정 데이터 반영

### 상위 Requirement

- relates to #64

### 작업 내용

T3 · T4 로 달라진 사실을 에이전트가 근거로 읽는 문서에 적는다.

**사용자 지시로 보호 문서를 수정한다** — `.ai/project/architecture.md` 와 `.ai/project/glossary.md` 는 보호 문서이며,
이 두 파일의 수정은 사용자가 결정 게이트에서 이 이슈의 구현 범위로 지시했다. 리뷰나 가드에서 보호 문서 수정으로
걸리면 사람이 대응한다.

- 명세 11-1 · 11-2 의 위치별 반영 사실
- `.ai/project/architecture.md`: 구성 요소(`src/bin/harness` 와 `src/bin/harness_metrics.py`, 대상 리포 `script/` 의 `_review.py`),
  데이터 흐름(리뷰어 → 판정 데이터 → `post-review.sh` 의 검증·집계·누적·렌더링 → 종료 코드), 신뢰 경계(판정 데이터의 엄격한 스키마 검증),
  새 코드를 둘 곳(지표 코드와 리뷰 루프 파이썬의 자리), 검사하지 않는 것(한 파일 항목)
- `.ai/project/glossary.md`: 용어 표의 `표지` 행 예시에서 `REVIEW_VERDICT` 를 빼고 `FMT_REVIEW_BLOCK` 과 `harness:allow-secret` 등을 든다. 뜻은 그대로다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 두 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/architecture.md`, `.ai/project/glossary.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] `.ai/project/architecture.md` 가 명세 11-1 표의 여섯 위치 사실을 담는다
- [ ] `.ai/project/glossary.md` 의 `표지` 행에 `REVIEW_VERDICT` 가 없고 `FMT_REVIEW_BLOCK` 이 있다
- [ ] 두 문서에 `FMT_FINDINGS_HEADING` · `## 발견 사항` 절 제목 규칙 같은 옛 판정 형식이 남지 않는다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 가 두 문서와 일치하고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/64-modularize-cli-review-scripts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성된 규칙 정본이 보호 문서와 일치한다 | 두 문서 수정 뒤 `harness check` | 어긋난 생성 파일 없음 |
| UT-02 | 옛 표지 예시가 남지 않는다 | `.ai/project/glossary.md` · `.ai/AI_AGENT.md` | `REVIEW_VERDICT` 문자열 없음 |
