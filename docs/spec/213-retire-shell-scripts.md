# 남은 관리 스크립트의 하위 명령 이식과 shim 전환

대상 리포에 깔리는 관리 스크립트 가운데 이월 이슈 · 되감기 · 지표 기록 · 사용 기록 · 역할 실행기 · 검증 실행 ·
표지 · 클론 키의 로직을 `src/harness/` 패키지의 하위 명령과 모듈로 옮긴다. 옛 경로의 파일은 받은 인자를 그대로
하위 명령에 넘기는 shim 이 된다. 인자 · 표준 출력 · 종료 코드 · 남기는 기록은 바뀌지 않는다.

근거는 #206 의 결정 기록 "하네스 로직은 Python 표준 라이브러리 패키지 하나에 둔다" 다. 이 명세는 새 결정 기록을 만들지 않는다.

기준 코드는 #96 · #206 · #207 · #208 · #209 · #210 · #211 · #212 의 변경이 들어간 통합 브랜치이고, 그 머지가 착수 조건이다.
#207 이 실행 계획을 실행 시점 계산(`run_plan()`)으로 바꾼 뒤라야 이 명세의 역할 실행기 · 스팬 기록이 그 계산을 같은 프로세스에서
받는다. 보호 문서 문안은 #206 → #207 → #208 · #209 · #210 → #211 → #212 → #213 → #215 순서로 적용한다. #215 는 이 명세 뒤에
오고, 이 명세가 옮긴 되감기(`harness rollback`)와 표지 정본(`src/harness/format.py`)을 고친다 (12-2).

이 명세는 그 이슈들이 정한 것을 따르고 함수 · 모듈 단위로 적는다.

| 따르는 것 | 정하는 이슈 |
|---|---|
| 패키지의 모듈 지도, 명령마다 모듈 하나를 두는 규칙, 공용 모듈 규칙과 의존 방향(`metrics/` 는 `metrics/` 밖의 하네스 모듈을 불러오지 않는다), 명령 인자를 그대로 넘기는 통과 장치, 클론 키 모듈 자리(`home/clone_key.py`), 단위 테스트 자리(`src/test/unit/`)와 검증 단계 "Python 단위 테스트", 고정 사본의 패키지 자리(`.harness/lib/harness/`) | #206 |
| 공유 설정 · 실효 설정, 실행 계획을 계산하는 함수 `run_plan()` | #207 |
| 실행 계획의 `roles.<역할>.driver` · 최상위 `prompt` 항목, 역할 실행기의 `--driver` · `--driver-prompt` · `--schema` | #208 |
| forge 어댑터의 계약 함수, 셸 페이크를 파이썬 쪽 호출에 끼우는 주입 지점(환경 변수), 용어 `shim` | #209 |
| 표지를 읽는 `src/harness/format.py` — 루트 `script/harness-format.sh` 를 실행하지 않고 파싱한다 | #209 · #210 |
| 명령 가드 · git 훅 · 시크릿 스캔의 하위 명령 | #210 |
| 리뷰 루프 · 착수 판정 · task 동기화의 하위 명령 | #211 |
| 클론 키의 계산 규칙 | #96 (`docs/spec/96-machine-local-state-key.md` 1-1) |

정본 위치:

| 대상 | 정본 |
|---|---|
| 하위 명령 `carryover` · `rollback` · `span` · `usage` · `run-agent` · `verify` · `clone-key` | `src/harness/commands/` — 명령마다 모듈 하나 |
| 표지 | `src/harness/format.py` |
| 검증 실행(단계 · 통과 기록 · 경로 대조) | `src/harness/verify.py` |
| 스팬 기록기 | `src/harness/metrics/recorder.py` |
| 사용 기록과 그 어휘 | `src/harness/usage.py` |
| 역할 실행기와 사용량 파서 | `src/harness/runner.py` |
| 클론 키 | `src/harness/home/clone_key.py` |
| shim | `src/templates/managed/script/` 의 `create-carryover-issue.sh` · `rollback-work.sh` · `metric.py` · `usage-log.sh` · `usage-report.sh` · `run-agent.py` · `run-lint-test.sh` · `_clone_key.py` |
| 생성 shim `script/harness-verify.sh` | `verify_script()` |
| 표지 · 어휘의 셸 표기 | `src/templates/managed/script/harness-format.sh` · `usage-vocab.sh` |
| 권한 허용 목록 | `allow_rules()` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/test/unit/` · `src/templates/managed/script/test-carryover-issue.sh` · `test-rollback-work.sh` · `test-usage-log.sh` |
| 사람용 설명 | `README.md` · `src/templates/managed/script/README.md` · `src/templates/managed/docs/workflow/changing.md` |

이 리포의 `script/` · `docs/workflow/` 아래 같은 이름의 파일은 거기서 설치된 사본이다.

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

바뀌지 않는 것:

- 옛 경로(`script/<이름>`)를 부르는 사용법. 인자 · 표준 출력 · 종료 코드 · 표준 입력 처리가 같다 (2절)
- 에이전트와 사람이 보는 명령 표기. 절차 조각 · 역할 계약 · 역할 어댑터 · 규칙 문서 · `CLAUDE.md` · 실행 계획의 `entry` 는
  지금처럼 `script/<이름>` 을 적는다
- 남기는 기록. 스팬의 이름 · 종류 · 속성 · 부모 관계 · 파일 형식, 사용 기록의 줄 형식과 어휘, 검증 통과 기록의 위치와 키,
  실패 로그의 지우기 규칙, 기록 디렉터리 0700 · 파일 0600
- 환경 변수 `HARNESS_TRACE_ID` · `HARNESS_PARENT_SPAN` · `HARNESS_METRICS` · `HARNESS_WORKFLOW` · `HARNESS_STEP` ·
  `HARNESS_CHECK_START_FD` · `HARNESS_SCRIPT_TESTS` · `HARNESS_VERIFY_CACHE`, 설정 `usage.env_var` 가 이름을 정하는 사용 기록 경로 변수
- 생성 파일 목록. `script/harness.env` · `script/forge.sh` · `script/harness-verify.sh` 는 그대로 생성된다
- 대상 리포에서 지워지는 파일은 없다 (8절)
- 권한 허용 목록의 기존 규칙 · 제외 목록, deny, 명령 가드 (6절)
- `verify.script_tests` 와 "하네스 스크립트 회귀" 단계, 셸 회귀 테스트(`script/test-*.sh`)
- 원격에 쓰는 동작의 게이트. 이슈 · 리뷰 요청을 닫는 동작은 되감기 하나이고, 사용자가 직접 부르고 확인한 턴에서만 돈다

바뀌는 것:

- 로직이 패키지에 있다. 하네스 안의 부르는 쪽은 패키지를 부른다 (5절)
- CLI 에 하위 명령 7개가 생긴다 (2절)
- 옛 경로의 파일이 shim 이 된다. `script/harness-verify.sh` 는 단계 목록을 담지 않고 `verify --steps-only` 를 부르는
  생성 shim 이 된다 (4절)
- 검증 단계 목록(`[commands]` · `[verify]`)은 검증할 때 공유 설정에서 읽는다. `script/harness-verify.sh` 를 직접 부르면
  render 하지 않은 설정 변경도 바로 반영되고, 설정을 읽지 못하면 1 로 끝난다. `script/run-lint-test.sh` 는 지금처럼
  생성물 일치 검사가 먼저 막는다
- 이월 이슈 · 되감기 · 사용 기록 · 검증은 설정 값을 공유 설정에서 읽고, 역할 실행기 · 스팬 기록은 실행 계획을 같은 프로세스에서
  `run_plan()` 으로 계산한다 — `harness run-plan` 을 하위 프로세스로 띄우지 않는다 (7절). `usage.log_path` 값의
  셸 문법(명령 치환 등)은 해석하지 않는다
- 권한 허용 목록에 하위 명령 규칙 4개가 더해진다 (6절)

## 2. 하위 명령

### 2-1. 공통

| 명령 | 맡는 옛 경로 | 종료 코드 |
|---|---|---|
| `carryover <원본이슈> <제목> <본문파일> [--dry-run]` | `create-carryover-issue.sh` | 0 생성 · 같은 제목이 이미 있음 · 2 실패 |
| `rollback <이슈> [--dry-run\|--yes]` | `rollback-work.sh` | 0 되감음 · 되감을 것 없음 · 1 사용자가 거절 · 2 실패 |
| `span wrap\|start\|end\|step\|prune ...` | `metric.py` | 2-4 |
| `usage log <종류> <출처> [상세]` | `usage-log.sh` | 언제나 0 |
| `usage report [--since YYYY-MM-DD] [로그파일\|디렉터리 ...]` | `usage-report.sh` | 0 출력 · 2 실패 |
| `run-agent <역할> [--driver [--schema <파일>]] [--out <파일>] [--prompt <지시>] [<입력> ...]` | `run-agent.py` | 그 CLI 의 종료 코드 · 2 실행하지 못함 |
| `run-agent --driver-prompt <read-only\|write> --prompt <지시> --out <파일>` | `run-agent.py --driver-prompt` | 그 CLI 의 종료 코드 · 2 실행하지 못함 |
| `run-agent <역할> --check` | `run-agent.py --check` | 0 준비됨 · 2 실행하지 못함 · 3 로그인 안 됨 · 4 확인하지 못함 |
| `verify [--commit] [--no-cache]` | `run-lint-test.sh` | 0 통과 · 1 실패 |
| `verify --steps-only [--commit] [--no-cache]` | `harness-verify.sh` | 0 통과 · 1 실패 · 2 인자 오류 · 3 명령을 아직 정하지 않음 |
| `clone-key expand <값>` | `_clone_key.py expand` | 0 푼 값 · 1 인자 오류 · 계산 실패 |

- 일곱 명령 모두 `COMMANDS` 와 `DELEGATES` 에 든다. 전역 CLI 로 부르면 프로젝트에 고정된 버전으로 넘어간다
- 일곱 명령 모두 #206 3-3 의 통과 명령이다 — `COMMANDS` 에 통과 표시를 갖고, 형식은 `harness [--target DIR] <명령> <인자…>` 다
- **명령 이름 뒤의 인자는 전부 그 명령이 받는다.** 전역 옵션과 이름이 같아도(`--yes` · `--dry-run` · `--json` · `--since` 등)
  그 명령의 인자다. 하네스 루트는 명령 이름 앞의 `--target DIR` 가 정하고, 이름 바로 뒤의 `--target DIR` 한 번은 #206 3-3 대로
  하네스 루트로 받는다. 그 밖의 자리의 `--target` 은 그 명령의 인자다 — `span wrap … -- <명령> --target <값>` 의 `--target <값>` 은
  감싼 명령에 간다
- 인자 규칙은 각 절의 옛 스크립트와 같다. 모르는 인자를 거부하던 명령은 같은 종료 코드로 거부하고, 무시하던 명령(`span`)은 무시한다
- 작업 디렉터리는 옛 스크립트와 같다. 명령은 자기 프로세스의 현재 디렉터리를 바꾸지 않는다 — 다른 명령이 같은 프로세스에서
  불러도 부른 쪽의 현재 디렉터리가 그대로다

  | 명령 | 하네스 루트에서 하는 일 | 부른 쪽의 현재 디렉터리에서 하는 일 |
  |---|---|---|
  | `carryover` · `rollback` · `usage report` · `verify` | 전부. 상대 경로 인자는 하네스 루트 기준이다 | — |
  | `usage log` | 설정을 읽는다 | 브랜치를 읽는다 |
  | `span` | 실행 계획을 계산한다 | `wrap` 이 감싼 명령을 띄운다 |
  | `run-agent` | 실행 계획을 계산하고 자식 CLI 를 띄운다 | `--out` 의 상대 경로를 푼다 |
  | `clone-key` | 키를 계산한다 | — |

- 이월 이슈의 본문 파일, 사용 기록 집계의 로그 파일 · 디렉터리, 역할 실행기의 `--out` 은 부른 쪽이 주는 입출력 파일이다.
  지금 스크립트처럼 절대 경로도 받는다
- 터미널 출력은 영어다(ADR 0011). 표준 오류 문구는 옛 스크립트의 것을 쓴다
- 처리하지 않은 예외는 그 명령의 실패 코드로 끝난다 — `carryover` · `rollback` · `usage report` · `run-agent` · `span` 은 2,
  `verify` 는 1, `clone-key` 는 1, `usage log` 는 0. 되감기의 1(거절)과 겹치지 않는다. 기록 실패는 예외로 올리지 않는다(2-4 · 2-5)
- 공유 설정을 읽지 못하거나 검증에 실패하면 `carryover` · `rollback` · `usage report` 는 2, `verify` 는 그 안내를 내고 1,
  `usage log` 는 기록하지 않고 0 으로 끝난다. `span` · `run-agent` 는 실행 계획을 실효 설정에서 계산한다 — 실효 설정이 성립하지
  않으면 `run-agent` 는 2 로 끝나고 `span` 은 기록하지 않는다. `clone-key` 는 설정을 읽지 않는다 (7절)

`harness help` 에 나오는 인수와 설명:

| 명령 | 인수 | 설명 |
|---|---|---|
| `carryover` | `<source-issue> <title> <body-file> [--dry-run]` | create the carryover issue for a review finding moved out of scope (writes to the remote) |
| `rollback` | `<issue> [--dry-run\|--yes]` | roll back what work made for an issue: close its review requests and task issues, remove local branches (asks first) |
| `span` | `<wrap\|start\|end\|step\|prune> ...` | record run-metric spans: wrap a command, open or close a span, mark a workflow step, apply retention |
| `usage` | `<log\|report> ...` | append a usage record, or summarize usage records as tables and KEY=VALUE lines |
| `run-agent` | `<role> [--driver [--schema FILE]] [--out FILE] [--prompt TEXT] [input ...]` | run a role once on its CLI runner from the run plan (--driver: as a driver block, --driver-prompt MODE: a prompt block without a role, --check: is the runner installed and signed in) |
| `verify` | `[--commit] [--no-cache] [--steps-only]` | check generated files, then run the [verify] steps (--steps-only: the steps alone) |
| `clone-key` | `expand <text>` | print the text with {clone} and {project} replaced by this clone's key |

### 2-2. `carryover`

판정 순서와 결과는 지금 `create-carryover-issue.sh` 와 같다.

1. 인자가 셋 또는 넷이고 넷째는 `--dry-run` 이어야 한다. 아니면 사용법을 내고 2
2. 본문 파일이 없으면 2
3. 제목이 `<태그>: <요약>` 형식이고 태그가 `commit.tags` 에 있어야 한다. 아니면 2
4. 트래커를 쓸 수 있어야 한다(`tracker_require`). 아니면 2
5. 원본 이슈를 조회하고 이슈 목록을 조회한다. 어느 쪽이든 실패하면 만들지 않고 2 — 중복 확인 없이 만들지 않는다
6. 본문을 검사한다. 하나라도 어긋나면 2
   - 내용이 있다
   - task 이슈 양식(하네스 루트의 `.ai/templates/issue-task.md`, 없으면 비교하지 않는다) 원문 그대로가 아니다
   - 작업 내용 절(제목은 표지 `FMT_ISSUE_WORK`)이 있고 주석을 뺀 내용이 있다
   - 표지 `FMT_ISSUE_RELATES` 뒤에 원본 이슈 번호가 있다
7. 원본 이슈에 필수 필드(`issues.required_fields`)가 모두 있어야 한다. 아니면 2
8. 같은 제목의 이슈가 있으면 만들지 않고 `<참조> skip(<상태>)` 를 내고 0
9. `--dry-run` 이면 `(dry-run) create  <제목>` · `--- body ---` · 본문을 내고 0
10. task 라벨(`issues.labels.task`)과 원본 이슈의 담당자 · 마일스톤으로 만들고 `<참조> created` 를 내고 0.
    만들지 못하거나 새 번호를 읽지 못하면 2

- `<참조>` 는 `commit.issue_ref` 가 정하는 표시(`#{id}` 또는 `{id}`)다
- forge 는 #209 어댑터의 계약 함수(`tracker_require` · `tracker_issue_view` · `tracker_issue_list` · `tracker_issue_create`)로만 부른다
- 같은 제목의 동시 실행은 지금처럼 막지 않는다 — 중복 확인은 순차 실행 기준이다

### 2-3. `rollback`

되감는 것과 남기는 것은 지금 `rollback-work.sh` 와 같다.

| 되감는다 | 남긴다 |
|---|---|
| 이슈에 연결된 열린 리뷰 요청 — 닫는다(머지하지 않는다) | 요구사항 이슈 자신 |
| 원격 통합 브랜치의 `docs/plan/<이슈>/task.md` 의 task 절 제목(`<task 제목>(<참조>)`)과 같은 제목의 열린 이슈 — 닫고 `issues.labels.invalid` 라벨을 단다 | 원격 브랜치 — 지우는 명령만 알린다 |
| `refs/heads/*/<이슈>-*` 로컬 브랜치 — 지운다 | 커밋 · 머지된 것 · 명세와 분해 문서 |
| | 체크아웃된 브랜치, 다른 worktree 가 체크아웃한 브랜치와 그 worktree |

- 먼저 대상을 보이고(`rollback target:` · `will be closed or removed` · `left alone` 단락), `--dry-run` 이면
  `(dry-run) nothing was changed` 를 내고 0
- `--yes` 가 없으면 표준 입력이 터미널일 때만 `roll these back? [y/N] ` 로 묻는다. `y` · `Y` · `yes` · `YES` 만 진행하고,
  그 밖이면 `stop: nothing was changed` 를 내고 1. 터미널이 아니면 묻지 않고 2
- 리뷰 요청 → task 이슈 → 로컬 브랜치 순으로 되감는다. 하나가 실패해도 나머지를 계속하고, 실패가 있었으면 끝에 2
- 되감을 것이 없으면 `nothing to roll back for issue <이슈>` 를 내고 0
- task 절 머리글은 표지 `FMT_TASK_HEADING` 이다
- forge 는 #209 어댑터의 계약 함수(`forge_require` · `tracker_issue_view` · `harness_issue_open_mrs` · `tracker_issue_list` ·
  `review_mr_close` · `tracker_issue_close`)로만 부른다
- 출력 줄은 지금과 같다 — worktree 가 체크아웃한 브랜치의 문구(`docs/spec/71-issue-worktree-run.md` 8절)도 같다

### 2-4. `span`

| 동작 | 하는 일 | 종료 코드 |
|---|---|---|
| `wrap --name <이름> --kind <종류> [--attr 키=값 ...] -- <명령> [인수 ...]` | 명령 하나를 스팬으로 감싼다. 출력은 그대로 흐른다 | 감싼 명령의 것 · 띄우지 못하면 127 · 중단되면 130 · `--` 뒤가 비면 사용법을 내고 2 |
| `start --name <이름> --kind <종류> [--attr 키=값 ...]` | 스팬을 열고 스팬 id 를 출력한다. 기록하지 않아도 id 를 낸다 | 0 |
| `end --span <id> [--status ok\|error] [--exit N]` | 스팬을 닫는다. `--exit` 가 숫자가 아니면 빼고, `error` 가 아닌 상태는 `ok` 다 | 0 |
| `step <절차> <단계>` | 단계 시작 표지 — `--` 로 시작하지 않는 앞의 두 인자를 쓴다 | 0 |
| `prune` | 보관 기간 · 전체 상한을 적용하고 `prune: <N> file(s) removed` 를 낸다. 기록하지 않으면 아무것도 내지 않는다 | 0 |
| 그 밖 · 동작 없음 | 사용법을 낸다 | 2 |

- 동작 뒤에서 `--<키> <값>` 쌍을 읽고, `--` 뒤를 감쌀 명령으로 받는다. `--attr` 는 여러 번 받는다. 모르는 키는 무시한다
- 지표 설정은 하네스 루트의 실행 계획(`run_plan()` 의 `metrics`)에서 받는다. `HARNESS_METRICS=off` 면 실행 계획을 계산하지 않는다
- 기록하지 않는 경우: `HARNESS_METRICS=off`(이 프로세스와 자식 전부), 실행 계획을 계산하지 못함(실효 설정이 성립하지 않음),
  `dir` 이 `off`, `dir` 의 자리표시(`{clone}` · `{project}`)를 풀지 못함. 어느 경우든 출력과 종료 코드는 기록할 때와 같다
- `dir` 은 `commands/span.py` 가 클론 키 모듈로 자리표시를 풀고 이어서 `~` 와 환경 변수를 펼친 값이다
- 기록 형식은 지금과 같다
  - `<dir>/spans-<YYYYMMDD>-<N>.jsonl`, 한 줄에 이벤트 하나(`start` · `end`), 스키마 `v: 1`, 시각은 UTC 밀리초
  - 종류는 `command` · `step` · `agent` · `script` · `session` · `prompt` · `marker`. 속성 키는 `workflow` · `step` · `role` · `vendor` ·
    `model` · `issue` · `worktree` · `script` · `source` 이고 값은 짧은 식별자 모양만(`issue` · `worktree` 는 숫자만) 통과한다.
    이름은 공백을 `-` 로 바꾸고 80자까지, 모양이 맞지 않으면 기록하지 않는다
  - 파일 하나가 `max_file_mb` 를 넘으면 다음 번호로 넘어간다. 하루 한 번 `retention_days` 와 `max_total_mb` 로 정리한다.
    쓰기와 정리는 디렉터리 잠금 안에서 한다
- **남기지 않는 것: 프롬프트 · 명령줄 · 문서 본문 · 사람 이름.** 실패 로그는 `capture_logs = "errors"` 이고 실패한 스팬일 때만,
  표준 오류의 끝 20줄 · 2048바이트에서 토큰 · 쿠키 · bearer · 키 모양 문자열 · JWT · URL 쿼리 · URL 자격 · 이메일 · 홈 경로를 지운 뒤 남긴다
- `wrap` 은 기록할 때만 자식의 표준 오류를 파이프로 받아 그대로 흘리며 끝부분을 모은다. 기록하지 않으면 자식이 부모의 표준 오류를
  그대로 쓴다. 자식에게 `HARNESS_TRACE_ID` · `HARNESS_PARENT_SPAN` 을 넘긴다
- `step` 은 이름 `<절차>/<단계>`, 종류 `marker`, 출처 `session` 의 스팬을 열고 닫는다. 트레이스는 `HARNESS_TRACE_ID`, 없으면 `t-unattributed`
- **기록은 부수 효과다.** 기록이 실패해도 출력과 종료 코드가 바뀌지 않는다
- 기록기(`src/harness/metrics/recorder.py`)는 지표 설정과 자리표시를 푼 기록 디렉터리를 인자로 받는다. 하네스 루트 · 설정 ·
  실행 계획 · 클론 키를 스스로 구하지 않는다 — `metrics/` 는 `metrics/` 밖의 하네스 모듈을 불러오지 않는다(#206 3-4)
- 기록기를 쓰는 곳이 자리표시를 풀어 넘긴다. `commands/span.py` 와 `harness run` 이 그렇고, 기록기의 스팬 열기 · 닫기 · 감싸기를
  부르는 다른 명령(5-1)도 같은 클론 키 모듈 함수로 풀어 넘긴다. `harness run` 은 자기가 해석한 지표 설정을 넘기고 실행 계획을
  다시 계산하지 않는다

### 2-5. `usage log` · `usage report`

`usage` 뒤가 `log` · `report` 가 아니면 사용법을 내고 2 다.

`usage log <종류> <출처> [상세]`:

- 인자가 둘보다 적으면 기록하지 않는다. 아무것도 출력하지 않는다
- 종류 · 출처가 어휘에 없으면 `other` 다
- 상세는 개행 · 캐리지 리턴 · 탭 · `|` 를 공백으로 바꿔 토큰으로 나눈다. 고정 라벨이거나, `키=값` 이고 그 키의 값 형식에 맞는
  토큰만 남겨 공백으로 잇고 80자에서 자른다
- 브랜치 유형: 현재 디렉터리에서 `git branch --show-current` 를 읽는다. 없으면 `-`, 보호 브랜치 목록에 있으면 `protected`,
  `<태그>/…` 이고 태그가 커밋 태그 목록에 있으면 그 태그, 아니면 `unknown`
- 줄 형식: `<로컬 시각 YYYY-MM-DDTHH:MM:SS>|<종류>|<출처>|<상세>|<브랜치 유형>`
- 기록 위치
  - `usage.env_var` 가 이름인 환경 변수가 있으면 그 값을 그대로 쓴다
  - 없으면 `usage.log_path`. `off` 면 기록하지 않는다. `$NAME` · `${NAME}` 을 그 값으로 바꾸고(없는 변수는 빈 문자열),
    `~` 와 명령 치환은 풀지 않는다. 이어서 `{clone}` · `{project}` 를 클론 키로 바꾼다. 풀지 못하면 기록하지 않는다
- 부모 디렉터리를 만들고 줄을 덧붙인다. 실패해도 0 이다
- **남기지 않는 것: 명령 내용 · 문서 본문 · 사람 이름 · 체크아웃 디렉터리 이름 · 브랜치 이름**

`usage report [--since YYYY-MM-DD] [로그파일|디렉터리 ...]`:

- `--since` 뒤에 값이 없으면 2. `-` 로 시작하는 다른 인자는 사용법을 내고 2. 나머지는 경로다
- 경로가 없으면 `usage log` 와 같은 규칙의 기록 위치 하나를 읽는다. 자리표시를 풀지 못하면
  `error: could not resolve usage.log_path for this clone` 을 내고 2
- 디렉터리는 그 아래 `*.log` 전부다. 마지막 줄에 개행이 없는 파일도 다음 파일과 줄이 합쳐지지 않는다
- 기간을 주지 않으면 최근 28일(로컬 날짜)이다
- 입력 줄을 형식과 어휘로 다시 검증하고, 맞지 않는 줄은 건수만 센다
- 회차 상한은 `review.max_rounds` 다. 상한 도달은 `exit=3 stop=mrl-cap` 기록만, 한 파일 반복은 `stop=repeat` 기록만 센다
- 출력은 지금 `usage-report.sh` 와 같다 — 표의 제목 · 열 · 문장, `KEY=VALUE` 줄의 이름 · 순서 · 값.
  건수로 정렬하는 표에서 같은 건수의 행은 `LC_ALL=C sort -t'|' -k3 -nr` 의 순서다

어휘(이벤트 · 출처 · 고정 라벨 · 키별 값 형식)의 정본은 사용 기록 모듈 `src/harness/usage.py` 다. 값은 지금 `usage-vocab.sh` 와 같고,
키별 값 형식은 지금처럼 정규식 하나다.

### 2-6. `run-agent`

인자:

- 첫 인자가 역할이다. 예외는 `--driver-prompt <read-only|write>` 하나다 — 역할 인자가 없는 형태이고 역할 없이 띄운다.
  그 밖에 첫 인자가 없거나 `-` 로 시작하면 사용법을 내고 2
- 나머지에 `--check` 가 있으면 확인만 한다. `--driver` · `--schema <파일>` · `--out <파일>` · `--prompt <지시>` 를 받고, 그 밖은 입력이다
- `--driver` · `--driver-prompt` · `--schema` 의 뜻과 인자 규칙은 #208 7-4 가 `script/run-agent.py` 에 둔 그대로다. #208 이 이 명세보다
  먼저 머지되고, 이 명세 뒤에는 `script/run-agent.py` 가 `harness run-agent` 의 shim 이다 (4-1)

실행 계획:

- 하네스 루트의 실행 계획을 같은 프로세스에서 `run_plan()` 으로 계산한다 — 실효 설정(#207)이다. `harness run-plan` 을 하위 프로세스로
  띄우지 않고 실행 계획 파일을 읽지 않는다
- 실효 설정이 성립하지 않으면 `harness run-plan` 이 내는 것과 같은 오류를 내고 2. `--check` 도 같다
- 띄울 항목은 인자로 고른다

  | 인자 | 항목 |
  |---|---|
  | 역할만 | `roles.<역할>` |
  | 역할과 `--driver` | `roles.<역할>.driver` — `vendor` · `exe` · `argv` · `output` · `usage_format` · `usage_parser` · `structured`. 서브에이전트 역할도 띄운다 |
  | `--driver-prompt <권한>` | 최상위 `prompt.<권한>`(`read-only` · `write`) |

- 역할이 실행 계획에 없으면 `` error: no role `<역할>` in the config (have: <역할들>) `` 과 2. 고른 항목이 없으면 2 — `driver` 가 없는
  역할(`entry` 역할 등)에 `--driver`, 오케스트레이터 벤더에 `headless` 가 없어 `prompt.<권한>` 이 없을 때의 `--driver-prompt`.
  `--driver` 없이 서브에이전트 역할을 부르거나, 실행 파일이 없으면 2
- `--schema <파일>` 은 고른 항목의 `structured` 가 비어 있지 않을 때만 그 인자를 붙이고, 비어 있거나 없으면 무시한다

띄우기:

- `--prompt` 가 없으면 지금과 같은 기본 지시(역할 계약을 읽고 따르라는 문장에 입력을 붙인 것)를 쓴다
- argv 는 고른 항목의 `argv` 에 — 사용량 파서가 있으면 `usage_format`, 없고 `--out` 이 있으면 항목의 결과 파일 인자(`{out}` 치환) — 를
  붙이고 마지막에 지시를 붙인다. `structured` 인자의 자리는 #208 7-4 를 따른다. 파서가 있거나, `--out` 이 있고 표준 출력으로 내는
  CLI 면 본문을 받아 `--out` 파일(없으면 표준 출력)에 쓴다. 그 밖에는 자식이 표준 출력에 그대로 쓴다
- 표준 입력은 그대로 넘어간다
- 스팬: 이름은 역할, 종류 `agent`, 출처 `runner`, 속성 `role` · `vendor` · `model` · `workflow`(`HARNESS_WORKFLOW`) ·
  `step`(`HARNESS_STEP`). 끝 기록에 종료 코드 · 시간 · 사용량 · 모델, 실패면 지운 실패 로그
- `--check`
  - 역할 항목에 로그인 확인 명령(`auth_check`)이 없으면 `unchecked` 를 내고 0
  - `auth_timeout` 이 1 이상의 정수가 아니면 2
  - `HARNESS_CHECK_START_FD` 가 있으면 확인 명령을 띄우기 직전에 그 파일 기술자에 한 바이트를 쓰고 닫는다
  - 확인 명령을 하네스 루트에서 `auth_timeout` 초 제한으로 돌리고 그 입출력은 버린다. 실패면 3, 띄우지 못했거나 시간이 넘으면 4,
    성공이면 `signed-in` 을 내고 0
  - 스팬을 남기지 않는다
- 사용량 파서 `PARSERS`(`claude-json` · `codex-jsonl`)는 역할 실행기 모듈 `src/harness/runner.py` 에 있다. 벤더 선언의 `usage_parser` 가 이름으로 고른다.
  모르는 출력 형식이면 받은 그대로 넘기고 사용량을 비운다

### 2-7. `verify`

기본 동작(`script/run-lint-test.sh` 가 하던 일):

1. 생성물 일치 검사 — `harness check` 와 같은 출력. 실패하면 1
2. 채운 옛 검증 스크립트 `script/verify-project.sh`(원형의 `verify-project: not filled in yet` 줄이 없는 것)가 있으면
   그것을 인자 없이 `bash` 로 돈다. 실패하면 1
3. 아니면 받은 인자로 단계 실행(`--steps-only`)을 한다. 0 이 아니면 1

인자는 3단계에서만 검사한다 — 옛 검증 스크립트가 도는 경우에는 보지 않는다. 설정을 읽지 못하면 그 안내를 내고 1 이다.

단계 실행(`--steps-only`, `script/harness-verify.sh` 가 하던 일):

- 인자는 `--commit`(`on = "commit"` 단계만)과 `--no-cache`. 그 밖은 사용법을 내고 2
- 단계 목록은 `verify_steps()` 와 같다 — `[verify].checks` 를 적은 순서대로, 이어서 코드 검사(`commands.format_check`),
  테스트(`commands.test` · `verify.test_paths` · `verify.test_on`). `verify.script_tests` 가 참이면 맨 앞에 "하네스 스크립트 회귀"
  단계가 지금의 명령 그대로 든다. `HARNESS_SCRIPT_TESTS=off` 면 그 단계는 출력 없이 빠진다
- 단계가 하나도 없으면 표준 오류에 `verify: not set up — harness.toml has no [commands] or [verify] checks yet` 와
  `help: harness set commands.test "<test command>"   (or Project Settings → Commands)` 를 내고 3
- 단계마다
  - `--commit` 이고 `on = "push"` 면 `verify: skip <이름> (push stage)`
  - 통과 기록이 있고 그 뒤 바뀐 파일이 단계의 경로에 하나도 걸리지 않으면 `verify: skip <이름> (unchanged since it last passed)`
  - 아니면 `verify: <이름>` 을 내고 하네스 루트에서 `bash -c <명령>` 으로 돈다. 실패하면 표준 오류에 `verify: FAIL <이름>` 을
    내고 1 — 다음 단계는 돌지 않는다. 통과하면 기록을 남긴다
- 모두 끝나면 `verify: ok` 를 내고 0

통과 기록(ADR 0018)의 자리 · 키 · 내용은 셸로 된 검증 스크립트가 쓰던 것과 같다. 그 스크립트가 남긴 기록을 그대로 읽는다.

- 켜지는 조건: `verify.incremental` 이 참, `--no-cache` 없음, `HARNESS_VERIFY_CACHE` 가 `off` 가 아님, git 공통 디렉터리를 구함.
  작업 트리의 트리 해시를 얻지 못하면 기록 없이 전부 돈다
- 자리 `<git 공통 디렉터리>/harness-verify/<키>`. 키는 `<이름>` · 개행 · `<명령>`(끝 개행 없음)을 `git hash-object --stdin` 한 값,
  내용은 통과한 작업 트리의 트리 해시다
- 작업 트리의 트리 해시는 실제 인덱스의 사본에 `git add -A .` 를 한 뒤 `git write-tree` 로 얻는다. 실제 인덱스를 건드리지 않는다
- 바뀐 파일은 `git diff -z --no-renames --relative --name-only <기록한 트리> <지금 트리>` 다
- 경로 glob 은 bash `case` 패턴의 뜻이다 — `*` 는 `/` 도 넘는다. `?` · `[…]` · `[!…]` · `[^…]` · `\` 이스케이프도 같다.
  경로가 없는 단계는 무엇이든 바뀌면 돈다

스팬: 기본 동작은 `run-lint-test`(종류 `script`, 속성 `script=run-lint-test`) 아래 `harness-verify`(`script=harness-verify`)
아래 단계마다 `verify/<이름>`(`script=harness-verify`)이다. `--steps-only` 는 `harness-verify` 부터다. 환경에 부모 스팬이 있으면
거기 붙는다. 기록하지 않을 때는 단계의 표준 오류를 파이프로 받지 않는다.

### 2-8. `clone-key`

`clone-key expand <값>` 은 하네스 루트(`--target`)의 클론 키로 값의 `{clone}` · `{project}` 를 전부 바꾼 결과를 한 줄 내고 0 으로
끝난다. 자리표시가 없으면 git 을 부르지 않고 그대로 낸다. `~` 와 환경 변수는 풀지 않는다. 인자가 맞지 않거나 계산이 실패하면
아무것도 내지 않고 1 이다. 계산 규칙은 `docs/spec/96-machine-local-state-key.md` 1-1 그대로다.

## 3. 패키지 안의 정본

| 정본 | 담는 것 | 쓰는 쪽 |
|---|---|---|
| `src/harness/format.py` | 표지 — 지금 `harness-format.sh` 의 이름(`FMT_*`)과 값 전부 | 이월 이슈 · 되감기, #209 자체 검사, #210 시크릿 스캔, #211 리뷰 루프 · task 동기화 |
| 사용 기록 모듈 `src/harness/usage.py` | 기록 · 집계, 어휘 | `usage`, #210 명령 가드 · git 훅, #211 착수 판정 · 리뷰 루프 |
| 스팬 기록기 `src/harness/metrics/recorder.py` | 2-4 의 기록 | `span`, `run-agent`, `verify`, `harness run`, 세션 가져오기, `harness metrics prune`, #211 하위 명령, #208 드라이버 |
| 역할 실행기 모듈 `src/harness/runner.py` | 2-6, `PARSERS` | `run-agent`, #211 리뷰 루프, #208 드라이버 |
| `src/harness/verify.py` | 단계 목록 · 통과 기록 · 경로 대조 · 단계 실행 | `verify` |
| 클론 키 모듈 `src/harness/home/clone_key.py` | 키 계산(`clone_key`)과 자리표시 풀기(`expand_key`) | CLI 의 모든 명령 — 지표 경로 · worktree 경로 · 등록 · 옛 이름 디렉터리 옮기기 · `span` · `usage` · `clone-key`, 스팬 기록기를 부르는 명령 |

- 파이썬 코드는 표지를 `src/harness/format.py` 에서만 읽는다 — #209 · #210 · #211 의 하위 명령도 지금처럼 이 모듈에서 읽는다.
  바뀌는 것은 이 모듈이 값을 얻는 곳 하나다. 루트 `script/harness-format.sh` 를 파싱하지 않고 값을 스스로 갖는다
- 클론 키는 `home/clone_key.py` 하나가 계산한다. 그 모듈이 관리 스크립트 `_clone_key.py` 를 경로로 불러오던 방식(`clone_key_module`)은
  없어진다
- #206 의 `metrics/spans.py` 가 대상 리포의 `script/metric.py` 를 경로로 불러오던 방식(`load_metric`)은 없어진다. 스팬 기록은
  `metrics/recorder.py` 가 한다
- **셸 표기.** `script/harness-format.sh` · `script/usage-vocab.sh` 는 관리 파일로 남는다. 남은 셸 소비자(셸 회귀 테스트)와
  그 경로를 가리키는 문서를 위한 것이고, 머리글에 정본이 패키지에 있다는 것을 적는다. 단위 테스트가 두 파일을 셸로 읽은
  이름 · 값이 정본과 전부 같은지 본다 — 한쪽만 바꾸면 검증이 실패한다

## 4. shim

### 4-1. 대상과 동작

| 파일 | 부르는 명령 | 형식 |
|---|---|---|
| `script/create-carryover-issue.sh` | `carryover` | POSIX sh |
| `script/rollback-work.sh` | `rollback` | POSIX sh |
| `script/metric.py` | `span` | python3 |
| `script/usage-log.sh` | `usage log` | POSIX sh |
| `script/usage-report.sh` | `usage report` | POSIX sh |
| `script/run-agent.py` | `run-agent` | python3 |
| `script/run-lint-test.sh` | `verify` | POSIX sh |
| `script/harness-verify.sh` (생성) | `verify --steps-only` | POSIX sh |
| `script/_clone_key.py` | `clone-key` | python3 |

1. 자기 파일이 있는 디렉터리의 부모를 하네스 루트로 잡는다
2. `<루트>/.harness/bin/harness`, `<루트>/src/bin/harness` 순으로 실행 가능한 첫 것을 CLI 로 고른다 — ADR 0013 의 순서이고
   지금 `run-lint-test.sh` 가 쓰는 순서다
3. `<CLI> --target <루트> <명령> <받은 인자 그대로>` 로 exec 한다. 파이썬 shim 은 같은 인터프리터(`sys.executable`)로 exec 한다

- 현재 디렉터리 · 표준 입출력 · 환경을 바꾸지 않는다. 종료 코드는 CLI 의 것이다
- 설정과 생성물을 읽지 않는다. 바이트코드를 남기지 않는다
- 실행 권한은 지금과 같다. 첫 줄은 `.sh` 가 `#!/usr/bin/env sh`, `.py` 가 `#!/usr/bin/env python3` 이다.
  셸 shim 은 `bash <파일>` 로도, 파이썬 shim 은 `python3 <파일>` 로도 돈다
- 머리글은 부르는 명령의 이름과 "로직은 패키지에 있다" 는 것을 적는다

**이 형태가 하네스 shim 의 공통 형태다** — 자기 위치로 잡은 하네스 루트, 두 자리의 CLI 탐색(PATH 의 전역 `harness` 는 부르지 않는다),
`<CLI> --target <루트> <명령> <받은 인자 그대로>` 로 exec, 현재 디렉터리를 바꾸지 않음, 그리고 아래 CLI 없음 문구 두 줄.
#207 · #209 · #211 · #212 · #215 의 shim 과 CLI 를 찾는 셸 진입점도 같은 형태와 문구를 쓴다. #210 의 가드 · git 훅 shim 은 CLI 가
없을 때의 종료 코드와 그 뜻(가드는 1 로 통과, pre-commit 은 0 으로 통과, commit-msg · pre-push 는 1 로 거부)을 자기 계약대로 두고
CLI 를 찾지 못했다는 문구만 이것을 쓴다.

CLI 를 찾지 못할 때:

| shim | 동작 |
|---|---|
| `usage-log.sh` | 아무것도 내지 않고 0 |
| `metric.py` | `wrap` 이면 `--` 뒤의 명령을 그대로 exec 한다(`--` 뒤가 비면 사용법을 내고 2). 그 밖의 동작은 아무것도 내지 않고 0 |
| `_clone_key.py` | 아무것도 내지 않고 1 |
| `run-lint-test.sh` · `harness-verify.sh` | 표준 오류에 `error: harness CLI not found under <루트> (.harness/bin/harness or src/bin/harness)` 와 `help: harness install --target <루트>` 를 내고 1 |
| 그 밖 | 같은 두 줄을 내고 2 |

### 4-2. 생성 shim — `script/harness-verify.sh`

`plan()` 에 그대로 있고 생성 파일 머리글을 갖는다. 내용은 설정과 무관한 4-1 의 shim 이다 — `verify_script()` 가 낸다.
`[commands]` · `[verify]` 를 바꿔도 이 파일은 바뀌지 않는다. 규칙 문서 3장의 명령 표와 단계 순서 문장은 지금처럼 따라 바뀐다.

### 4-3. 그대로 두는 셸 파일

- `script/harness-format.sh` · `script/usage-vocab.sh` — 셸 표기 (3절)
- `script/test-*.sh` — 셸 회귀 테스트 (10-2)
- #209 · #210 · #211 · #212 의 shim(`script/forge.sh` 포함)과 생성물 `script/harness.env`

## 5. 부르는 쪽

### 5-1. 패키지를 부르는 곳

하네스 안의 부르는 쪽은 옮긴 로직을 패키지에서 부른다. shim 을 거치지 않는다.

| 부르는 쪽 | 옮긴 로직 |
|---|---|
| `harness run` 의 run 스팬, 세션 가져오기(`harness metrics import`)의 기록 | 스팬 기록기. 대상 리포의 `script/metric.py` 를 불러오지 않는다 |
| #208 드라이버의 블록 스팬 | 스팬 기록기 |
| `harness metrics prune` | 스팬 기록기의 정리. 출력과 종료 코드는 지금과 같다 |
| 역할 실행기 · 검증의 스팬 | 스팬 기록기. 스크립트가 자기를 `metric.py wrap` 으로 감싸던 일은 명령 안에서 한다 |
| #210 의 명령 가드 · git 훅이 남기는 차단 기록 | 사용 기록 모듈. 기록 줄은 지금과 같다 — 아래 가드 조건을 지킨다 |
| #211 의 착수 판정 · 리뷰 루프 · task 동기화가 남기는 기록과 스팬 | 사용 기록 모듈 · 스팬 기록기 |
| #211 의 리뷰 루프가 리뷰어를 띄우고 러너를 점검하는 일 | 역할 실행기 모듈 |
| #208 드라이버의 agent · prompt 블록 | 역할 실행기 모듈을 같은 프로세스에서 부른다 — `harness run-agent --driver` · `--driver-prompt` 와 같은 구현이고 shim 을 거치지 않는다 |
| 표지를 읽는 하위 명령(#209 · #210 · #211) | `src/harness/format.py` |
| 자리표시를 푸는 곳(CLI · `span` · `usage` · 스팬 기록기를 부르는 명령) | 클론 키 모듈 |

표에 따로 적지 않은 곳의 부르는 방법(같은 프로세스 · 하위 프로세스)은 구현이 고른다. 출력 · 종료 코드 · 기록은 지금과 같다.

- #211 의 경계 모듈 `src/harness/scripts.py`(사용 기록 · 지표 기록 · 역할 실행기를 스크립트로 부르던 곳)는 없어진다. #211 의 하위
  명령은 위 모듈을 직접 부른다
- #208 드라이버는 역할 실행기를 패키지에서 부르므로 시작 전 확인에서 `script/run-agent.py` 가 있는지 보지 않는다
- **가드 조건.** `bash-guard` 의 통과 경로는 사용 기록 모듈과 그것이 부르는 설정 해석을 불러오지 않는다(#210 의 가드 경로 import
  조건). 가드 모듈은 사용 기록 모듈을 최상위에서 불러오지 않고, 차단이 정해진 뒤에만 부른다. 부르는 방법은 위 규칙대로
  구현이 고르고, 기록의 출력과 실패는 버린다. 차단 사유 · 종료 코드는 바뀌지 않는다

### 5-2. 진입점을 그대로 부르는 곳

사람과 에이전트가 부르는 진입점이 있는지 · 도는지를 보는 곳은 그 진입점(shim)을 지금처럼 부른다.

| 부르는 쪽 | 부르는 것 |
|---|---|
| pre-push 의 push 전 검증 | `script/run-lint-test.sh`. 없으면 지금 문구로 push 를 거부한다 |
| post-commit 훅 | `script/run-lint-test.sh` 를 exec 한다 (생성 본문 그대로) |
| doctor 의 `verification` 절 | `script/harness-verify.sh`(채운 옛 검증 스크립트가 있으면 그것)를 `QUIET_ENV()` 로 돌려 출력을 읽는다. 항목 이름 `script/harness-verify.sh` 그대로 |
| doctor `--remote` 의 리뷰어 러너 점검 | `script/run-agent.py` 가 있는지 보고 `--check` 를 두 단계 제한으로 부른다 |
| `harness fix verify` | 검증 진입점(`verify_entry()`) |
| `harness schema` 의 `verify_script` | 값 `script/harness-verify.sh` 그대로 |

## 6. 권한 허용 목록

- 기존 묶음(관리 스크립트 · forge · git)과 제외 목록(`ALLOW_EXCLUDED`)은 그대로다. shim 은 관리 스크립트이므로
  `Bash(script/<이름>:*)` 규칙이 남고, `rollback-work.sh` · `create-carryover-issue.sh` 는 계속 빠진다
- 하위 명령 묶음을 더한다. 규칙 형식은 `Bash(<CLI> <명령>:*)` 이고 명령은 `run-agent` · `span` · `usage` · `verify` 넷이다
- `<CLI>` 는 하네스 루트의 종류로 고른다 — 소스 리포(`source_tree()`)면 `src/bin/harness`, 아니면 `.harness/bin/harness`(ADR 0013)
- 넣지 않는 명령: `carryover`(이슈를 만든다) · `rollback`(리뷰 요청 · 이슈를 닫는다) — `docs/spec/70-generate-permission-allow-list.md`
  3절의 제외 이유와 같다. `clone-key` 는 다른 명령이 쓰는 모듈의 진입점이라 넣지 않는다 — `_clone_key.py` 가 관리 스크립트 묶음에서
  빠지는 것과 같다
- 묶음의 명령 이름은 상수 하나가 갖는다. 그 이름이 `COMMANDS` 에 없으면 render 를 거부한다:
  `error: permission list names a command that does not exist: <이름>`
- 순서: 관리 스크립트 규칙 다음, forge 규칙 앞에 명령 이름 오름차순으로 둔다
- 이 묶음은 이 명세가 더한 명령만 담는다. #209 · #210 · #211 의 하위 명령 규칙과 옛 규칙 걷기는 12절이다
- deny 와 명령 가드는 바뀌지 않는다

## 7. 설정을 읽는 곳

| 명령 | 읽는 것 | 쓰는 값 |
|---|---|---|
| `carryover` · `rollback` | 공유 설정 — CLI 의 설정 읽기 · 검증 | `derive()` 가 내는 값과 같은 것: 커밋 태그(검사식 · 안내 표기), 이슈 참조 표시, 필수 필드, task · invalid 라벨, 통합 브랜치 |
| `usage log` · `usage report` | 공유 설정 | `usage.env_var` · `usage.log_path`, 보호 브랜치(통합 브랜치가 자동으로 든 목록), 커밋 태그, `review.max_rounds` |
| `verify` | 공유 설정 | `[commands]` · `[verify]` |
| `span` · `run-agent` | 실행 계획 — 실효 설정에서 `run_plan()` 으로 같은 프로세스에서 계산한다 | `metrics` · `roles`(역할마다의 `driver` 포함) · 최상위 `prompt` |
| `clone-key` | 없음 | — |

- 공유 설정을 읽는 명령은 개인 레이어 파일을 열지 않는다 — 그 파일이 깨져 있어도 돈다(#207 2-2 의 공유 설정 명령과 같다)
- 실행 계획을 계산하지 못할 때: `run-agent` 는 `harness run-plan` 과 같은 오류를 내고 2 (2-6), `span` 은 기록하지 않고 출력 · 종료 코드를
  바꾸지 않는다 (2-4). 실행 계획은 파일로 남지 않고(#207), 이 명령들은 `harness run-plan` 을 하위 프로세스로 띄우지 않는다
- 이 명령들은 `script/harness.env` · `script/forge.sh` 를 읽지 않는다. 두 파일은 지금처럼 생성되고, #209 · #210 · #211 이 정한
  소비자와 셸 회귀 테스트가 읽는다

## 8. 대상 리포의 파일

- 이 명세로 대상 리포에서 지워지는 파일은 없다. 갱신(`install` · `render`)은 관리 파일 자리의 내용을 shim 으로 덮고
  `script/harness-verify.sh` 를 다시 생성한다
- 경로가 생성 · 관리 파일에서 빠질 때의 규칙은 지금 그대로다(ADR 0002 · 0015, `docs/spec/58-separate-managed-and-project-parts.md`)
  - 다음 render 가 지운다. 설치 뒤 고친 관리 파일도 지운다
  - 매니페스트에 없는 사용자 파일과 `script/project/` 는 지우지 않는다
  - 지울 경로도 사전 판정과 안전 경로 함수를 거친다(ADR 0017)
  - render 출력은 지금처럼 지운 건수만 낸다

## 9. 문서

| 문서 | 고칠 것 |
|---|---|
| `README.md` "명령" 표 | 일곱 명령의 행 |
| `README.md` "`harness.toml` 이 정하는 것" | `verify.checks` · `test_paths` · `test_on` · `incremental` · `script_tests` 행 — 생성 파일이 아니라 검증(`script/run-lint-test.sh` · pre-push · CI)이 실행할 때 읽는다. `usage.log_path` · `env_var` 행 — 기록 · 집계 명령 |
| `README.md` "검증" | 회귀 테스트 건수를 실제와 맞춘다 |
| `README.md` "언어" | 표지의 정본은 `src/harness/format.py`, 셸 표기는 `script/harness-format.sh` |
| `src/templates/managed/script/README.md` "목록" | 4-1 의 아홉 파일은 "shim — `harness <명령>`" 과 그 명령의 계약. `harness-format.sh` · `usage-vocab.sh` 는 셸 표기. `_clone_key.py` 행 |
| `src/templates/managed/script/README.md` "규칙" | 값은 하위 명령이 공유 설정에서, 역할 실행기 · 스팬 기록은 실행 계획에서 실행할 때 받는다(남은 셸 소비자는 `harness.env`). 기계가 읽는 문자열의 정본은 `src/harness/format.py`. 새 하네스 로직은 패키지의 하위 명령으로 두고 `script/` 에 로직을 담은 스크립트를 더하지 않는다 |
| `src/templates/managed/docs/workflow/changing.md` | "명령과 검증" 문단 — 규칙 문서 3장이 생성되고 검증이 실행할 때 공유 설정의 `[commands]` · `[verify]` 를 읽는다. "리뷰 · 이슈 본문의 표지 문자열" 행 — `src/harness/format.py` + 셸 표기 + 해당 계약 · 양식 |
| `src/templates/vendors.toml` 주석 | `usage_parser` 가 고르는 파서는 역할 실행기 모듈(`src/harness/runner.py`)의 `PARSERS` |
| `src/templates/defaults.toml` · 이 리포의 `harness.toml` 의 `[commands]` 머리 주석 | 규칙 문서(AI_AGENT.md 3장)가 여기서 생성되고, 검증(`script/run-lint-test.sh`)이 실행할 때 읽는다 |
| `.ai/project/review-checks.md` 표지 행 | 표지(`src/harness/format.py` 와 셸 표기 `script/harness-format.sh`)를 바꿨으면 그것을 쓰는 역할 계약도 같은 변경에 있는가 |
| `docs/spec/96-machine-local-state-key.md` 1-2 · 2-3 | 클론 키를 계산하고 푸는 곳은 패키지의 클론 키 모듈(`src/harness/home/clone_key.py`)이고, `script/_clone_key.py` 는 `clone-key` 의 shim 이다 |
| `docs/spec/64-modularize-cli-review-scripts.md` 6절 | 표지의 정본은 `src/harness/format.py` 다 |
| `docs/spec/70-generate-permission-allow-list.md` 6절 | 허용 목록의 순서에 하위 명령 묶음(이 명세 6절)이 든다 |

`docs/workflow/flow.md` 와 절차 · 역할 문서는 바꾸지 않는다 — 진입점 표기가 그대로다.

## 10. 회귀 테스트

### 10-1. 판정 기준

- 판정 기준은 기존 셸 테스트와 `render-test.sh` 의 검사 줄이 기대하는 값이다 — 종료 코드 · 출력 · 남긴 기록 · 페이크가 기록한 호출.
  기대값은 바꾸지 않는다
- 고칠 수 있는 줄은 준비부(샌드박스 배치 · 설정 파일 · 진입점 · 페이크 주입)와 구조 검사(파일 내용 · 내부 함수 · 모듈이 있는지를 보는 줄)다.
  고친 줄마다 리뷰 요청 본문에 옛 줄 → 새 줄 대응표를 둔다
- 준비부 수정은 구현을 바꾸는 task 보다 먼저 하고 옛 스크립트로 통과시킨다. 그래서 준비부는 옛 스크립트와 shim 양쪽에서 같은 결과를
  내는 형태로 고친다 — 샌드박스에 `harness.toml` 을 함께 두고, 샌드박스의 하네스 루트에서 CLI 를 찾을 수 있게 하고, forge 페이크를
  `script/forge.sh` 와 #209 의 주입 지점 양쪽으로 넣는다
- 역할 러너 · 지표 설정이 필요한 준비부는 샌드박스의 `harness.toml` 과 샌드박스에 설치한 고정 사본의 벤더 선언 사본
  (`.harness/templates/vendors.toml`)으로 상황을 만든다. 옛 스크립트(#207 의 `harness run-plan` 을 부른다)와 새 명령(같은 프로세스에서
  `run_plan()` 으로 계산한다)이 같은 실행 계획을 얻는다. 페이크 CLI 가 내는 실행 계획 JSON 에 기대는 준비부는 쓰지 않는다
- 구조 검사를 행동 검사로 바꿀 때는 같은 약속을 본다. 예: 검증 스크립트가 단계 명령을 담는지 보던 줄은 `verify --steps-only` 가 그 단계를 도는지 본다

### 10-2. 셸 회귀 테스트

- `test-carryover-issue.sh`(UT-01~08) · `test-rollback-work.sh`(UT-01~08) · `test-usage-log.sh` 의 모든 케이스가 기대값 그대로 shim 을 거쳐 통과한다
- #210 · #211 의 셸 테스트 가운데 사용 기록 · 지표 기록 · 역할 실행기를 샌드박스 사본으로 갈아끼우던 준비부는 10-1 규칙으로 고친다
- 셸 테스트는 대상 리포의 계약 테스트로 남는다. 지우지 않는다

### 10-3. `render-test.sh` — 새 블록

번호는 기존 블록과 겹치지 않게 매긴다.

1. **shim 은 받은 것을 하위 명령에 그대로 넘긴다.** 설치한 리포에서 4-1 의 아홉 shim 이 하위 명령을 직접 부른 것과 같은 종료 코드 ·
   표준 출력을 낸다 — 이월 이슈의 사용법 오류 2, 되감기 `--dry-run`(페이크), `metric.py wrap` 이 감싼 명령의 출력 · 종료 코드,
   `usage-log.sh` 0, `usage-report.sh` 의 기록 없음 출력, `run-agent.py` 의 서브에이전트 역할 2, `run-lint-test.sh` 통과,
   `harness-verify.sh` 의 미설정 3, `_clone_key.py expand '{clone}'` 의 키
2. **shim 은 현재 디렉터리를 바꾸지 않는다.** 하네스 루트가 아닌 디렉터리에서 `script/metric.py wrap … -- pwd` 가 그 디렉터리를 낸다
3. **전역 옵션을 가로채지 않는다.** `span wrap --name x --kind script -- sh -c 'echo "$*"' _ --json --yes` 가 `--json --yes` 를 낸다.
   같은 명령 끝의 `--target /x` 도 감싼 명령에 가서 `--target /x` 로 나온다. `rollback <이슈> --yes` 가 묻지 않고 되감는다(페이크)
4. **CLI 를 찾지 못할 때.** CLI 를 치운 샌드박스에서 4-1 의 표대로 — `usage-log.sh` 0, `metric.py wrap` 이 감싼 명령의 종료 코드,
   `_clone_key.py` 1 · 출력 없음, `run-lint-test.sh` 1, `rollback-work.sh` 2. `run-lint-test.sh` 와 `rollback-work.sh` 의 표준 오류가
   `error: harness CLI not found under <루트> (.harness/bin/harness or src/bin/harness)` 와 `help: harness install --target <루트>` 두 줄이다
5. **고정 버전으로 넘어간다.** 전역 CLI 로 부른 새 명령이 고정 사본으로 넘어간다
6. **허용 목록.** 설치한 리포는 `Bash(.harness/bin/harness <명령>:*)`, 소스 트리 복제는 `Bash(src/bin/harness <명령>:*)` 를
   `run-agent` · `span` · `usage` · `verify` 넷 모두 갖는다. `carryover` · `rollback` · `clone-key` 규칙이 없다. 기존 규칙이 전부 남는다.
   묶음이 관리 스크립트 규칙 뒤 · forge 규칙 앞에 있다. 상수의 이름이 `COMMANDS` 에 없으면 render 가 6절의 문구로 막힌다
7. **검증 설정을 실행할 때 읽는다.** `[verify].checks` 를 render 없이 고친 뒤 `script/harness-verify.sh` 가 새 단계를 돈다.
   `[verify]` 를 바꾸고 render 해도 `script/harness-verify.sh` 의 내용이 같다
8. **셸 검증 스크립트가 남긴 통과 기록을 읽는다.** 2-7 의 키 규칙으로 만든 기록이 있으면 같은 단계를 `unchanged since it last passed` 로 건너뛴다
9. **사용 기록은 설정이 깨져도 0 이다.** 읽히지 않는 `harness.toml` 에서 `usage-log.sh` 가 0 으로 끝나고 아무것도 기록하지 않는다
10. **바이트코드를 남기지 않는다.** 새 명령과 shim 을 돈 뒤 리포 어디에도 `__pycache__` 가 없다
11. **실행 계획은 실효 설정에서 같은 프로세스로 계산한다.** `harness.local.toml` 로 역할의 러너를 바꾸면 `run-agent.py` 가 바꾼 러너의
    스텁을 띄운다. 받지 않는 키가 든 개인 레이어에서 `run-agent.py` 는 2 와 `harness run-plan` 이 내는 것과 같은 오류를 내고,
    `metric.py wrap` 은 감싼 명령의 종료 코드로 끝나며 스팬을 남기지 않는다
12. **자리표시는 부르는 쪽이 푼다.** `metrics.dir` 에 `{clone}` 이 든 설정에서 `metric.py wrap` 이 클론 키로 푼 디렉터리에 기록한다

### 10-4. 기존 블록

| 블록 | 고치는 줄 | 같은 약속을 보는 줄 |
|---|---|---|
| UT-53 | `script/harness-verify.sh` 가 `step '테스트'` 를 담는지 | `verify --steps-only` 출력에 `verify: 테스트` 가 있다 |
| UT-53 | `run-lint-test.sh` 의 옛 검증 분기를 `sed` 로 잘라 도는 준비부 | 생성물 검사를 통과하는 상태에서 `script/run-lint-test.sh` 로 옛 검증 스크립트가 돈다 |
| UT-107 | `script/metric.py` 를 다른 디렉터리로 복사해 쓰는 준비부 | 설치한 리포의 shim 또는 `span` |
| UT-107 | 클론 키 모듈 없이 `metric.py` 만 복사해 기록하지 않음을 보는 줄 | 지운다 — 패키지 안에서는 모듈이 빠지지 않는다. 대응표에 적는다 |
| UT-80 | 실행기 · 기록기 사본을 다른 디렉터리에 복사해 쓰는 준비부 | 그 디렉터리를 하네스 루트로 `run-agent` 를 부른다. 역할 러너 상황은 10-1 대로 만든다 |
| UT-86 | `run-agent.py` 를 `runpy` 로 돌리며 `subprocess.run` 을 바꿔 끼우는 준비부 | 패키지의 역할 실행기 모듈을 같은 방식으로 돌린다 |
| UT-54 · UT-84 | — | 설치한 리포의 `script/metric.py` · `script/run-agent.py` 를 부르는 줄이 shim 으로 그대로 돈다 |
| UT-106 ~ UT-110 | — | `python3 script/_clone_key.py expand` 준비부가 shim 으로 그대로 돈다 |
| 실행 계획 값을 바꿔 보던 케이스(#207 이 고정 사본의 벤더 선언 사본과 페이크 CLI 로 옮긴 것) | 페이크 CLI 의 `run-plan` 출력에 기대는 준비부 | 벤더 선언 사본으로 만들 수 있는 상황은 10-1 대로 옮긴다. 깨진 실행 계획 JSON(`the run plan … is broken`)은 같은 프로세스에서 계산하므로 생기지 않는다 — 지운다. 대응표에 적는다 |
| #208 의 역할 실행기 케이스(`--driver` · `--driver-prompt` · `--schema`) | — | shim 을 거쳐 그대로 돈다 |
| #210 의 가드 import 단위 테스트 · 차단 기록을 보는 셸 케이스 | — | 차단 기록이 사용 기록 모듈로 바뀐 뒤에도 통과 경로의 불러온 모듈과 차단 기록 줄이 그대로다 |

이 밖에 옮긴 파일의 내용이나 내부 함수를 보는 줄은 10-1 규칙으로 고친다.

### 10-5. 단위 테스트 — `src/test/unit/`

#206 이 둔 단위 테스트 자리(`src/test/unit/`)와 검증 단계 "Python 단위 테스트"를 쓴다. 원격 · 에이전트 CLI 를 부르지 않고, 시각은 고정값을 넣는다.

| 모듈 | 보는 것 |
|---|---|
| 표지 · 어휘 | 셸 표기 두 파일을 셸로 읽은 이름 · 값이 정본과 전부 같다 |
| 사용 기록 | 상세 거르기(허용 라벨 · 키별 값 형식 · 자유 문장 · 사람 이름 모양 · 80자), 브랜치 유형 판정, 기록 위치 풀기(환경 변수 · 없는 변수 · `~` · 명령 치환 · 자리표시 · `off`) |
| 스팬 기록기 | 이름 · 속성 모양, 지우기 규칙, 파일 넘김 · 보관 · 전체 상한. 받은 기록 디렉터리에만 쓴다 |
| 스팬 기록 명령 | `commands/span.py` 가 `metrics.dir` 의 자리표시를 풀고 `~` · 환경 변수를 펼쳐 넘긴다. `HARNESS_METRICS=off` 면 실행 계획을 계산하지 않는다 |
| 검증 | glob 뜻(bash `case` 와 같은 표본), 통과 기록 키, 단계 시점 가르기, 단계 목록 순서 |
| 이월 이슈 | 본문 검사 넷, 제목 태그 검사 |
| 되감기 | task 제목 대조 — 닫힌 이슈와 다른 분해의 제목은 고르지 않는다 |
| 역할 실행기 | 두 파서의 정상 출력 · 오류 표시 · 모르는 형식. 인자로 고르는 항목(역할 · `driver` · `prompt.<권한>`), `structured` 가 없으면 `--schema` 를 무시함 |
| 클론 키 | git 트리 안 · 밖의 해시 입력, 자리표시가 없으면 git 을 부르지 않음 |

`metrics/recorder.py` 가 `metrics/` 밖의 하네스 모듈을 불러오지 않는 것은 #206 의 의존 방향 검사(`script/project/check-cli.py imports`)가 본다.

검증 일괄(`script/run-lint-test.sh`)이 전부 통과한다.

## 11. 보호 문서에 반영할 것

분해의 task 하나가 이 범위 안에서 고친다. 같은 절을 앞 명세들이 #206 → #207 → #208 · #209 · #210 → #211 → #212 순서로 먼저 고친다 —
아래는 그 순서로 고친 문장 위에 더할 사실이다. #215 가 이 위에 더한다.

### 11-1. `.ai/project/architecture.md`

| 위치 | 반영할 사실 |
|---|---|
| "구성 요소" 의 CLI | 하위 명령 `carryover` · `rollback` · `span` · `usage` · `run-agent` · `verify` · `clone-key` 가 이월 이슈 · 되감기 · 지표 기록 · 사용 기록 · 역할 실행 · 검증 · 클론 키를 맡는다. 공용 모듈은 표지 `src/harness/format.py`(정본) · 사용 기록 `src/harness/usage.py` · 역할 실행기 `src/harness/runner.py` · 스팬 기록기 `src/harness/metrics/recorder.py` · 검증 실행 `src/harness/verify.py` · 클론 키 `src/harness/home/clone_key.py` 다 |
| "구성 요소" 의 대상 리포 `script/` | 이월 이슈 · 되감기 · 지표 기록 · 사용 기록 · 역할 실행기 · 검증 일괄 · 클론 키 파일은 받은 인자를 그대로 하위 명령에 넘기는 shim 이다. `harness-format.sh` · `usage-vocab.sh` 는 패키지 정본의 셸 표기다 |
| "데이터 흐름" 의 절차 실행 | 앞 명세들이 고친 문장에서 역할 실행기 표기만 바꾼다. #207 이 고친 표기("`script/run-agent.py` 가 고정 사본 CLI 의 `run-plan` 으로 받은 실행 계획대로 띄운 CLI") → "역할 실행기(`harness run-agent` — 실행 계획을 같은 프로세스에서 `run_plan()` 으로 계산한다. 절차 문서는 shim `script/run-agent.py` 로 부른다)가 실행 계획대로 띄운 CLI". #208 의 driver 문장이 가리키는 역할 실행기는 같은 모듈이고, 드라이버는 그것을 같은 프로세스에서 부른다 — 그 뜻을 괄호로 붙인다. 나머지 문장은 그대로다 |
| "데이터 흐름" 의 실행 지표 | "명령·단계·역할·스크립트 → `script/metric.py`(start · end · wrap) →" 를 "명령·단계·역할·스크립트 → 스팬 기록(`harness span` — start · end · wrap · step, 셸에서는 shim `script/metric.py`. CLI 안의 기록은 같은 모듈을 부른다) → 패키지의 스팬 기록기(`src/harness/metrics/recorder.py`) →" 로 바꾼다. #207 이 더한 "`script/metric.py` 는 지표 설정을 `run-plan` 에서 받는다" 는 "지표 설정은 실행 계획(`run_plan()`)에서 받고, 기록 디렉터리의 자리표시는 기록기를 부르는 쪽이 클론 키로 풀어 넘긴다" 로 바꾼다 |
| "신뢰 경계" 의 명령줄 인자 | 부른 쪽이 주는 입출력 파일(이월 이슈 본문 · 사용 기록 로그 · 역할 실행기의 `--out`)은 리포 기준 상대 경로 규칙의 예외로 절대 경로도 받는다 |
| "새 코드를 둘 곳" 의 새 에이전트 CLI | "사용량 파서가 필요하면 `run-agent.py` 의 `PARSERS`" → "사용량 파서가 필요하면 `src/harness/runner.py` 의 `PARSERS`" |
| "새 코드를 둘 곳" 의 새 관리 스크립트 | 하네스가 대상 리포에서 하는 일은 패키지의 하위 명령으로 둔다. `script/` 에 로직을 담은 새 스크립트를 두지 않는다 |
| "새 코드를 둘 곳" 의 표지 | 기계가 읽는 문자열은 `src/harness/format.py` 에 두고 셸 표기 `script/harness-format.sh` 를 같은 변경에서 맞춘다 |
| "새 코드를 둘 곳" | #211 이 더한 `src/harness/scripts.py` 줄(이식하지 않은 관리 스크립트 자산을 부르는 코드)을 지운다. 더한다: 지표 기록 코드 → `src/harness/metrics/recorder.py`(`metrics/` 밖의 하네스 모듈을 불러오지 않는다) |
| "계층과 의존 방향" 의 규칙 값 문장 | #207 · #209 가 고친 문장 끝에 더한다: 이월 이슈 · 되감기 · 사용 기록 · 검증 하위 명령은 공유 설정을 설정 로더로 읽는다. 역할 실행기 · 스팬 기록 하위 명령은 실행 계획을 `run_plan()` 으로 같은 프로세스에서 계산하고, 대상 리포의 셸 · 파이썬 진입점은 이 하위 명령을 부르는 shim 이다 |
| "계층과 의존 방향" 의 #211 경계 문장 | #211 이 더한 `src/harness/scripts.py` 경계 문장을 이것으로 바꾼다: 하위 명령은 표지 · 사용 기록 · 지표 기록 · 역할 실행기를 패키지 모듈(`format.py` · `usage.py` · `metrics/recorder.py` · `runner.py`)로 부른다 |
| "계층과 의존 방향" 의 클론 키 | 더한다: 클론 키 모듈(`src/harness/home/clone_key.py`) 하나를 CLI 의 모든 명령이 쓰고 계산을 다시 두지 않는다. `script/_clone_key.py` 는 그 shim 이다. 스팬 기록기는 클론 키를 모르고 푼 디렉터리를 받는다 |

### 11-2. `.ai/project/glossary.md`

| 위치 | 반영할 사실 |
|---|---|
| "실행 계획" 행 | #207 이 고친 뜻에서 읽는 쪽 `run-agent.py` · `metric.py` 를 `harness run-agent` · `harness span` 으로 바꾸고 "이 둘은 같은 프로세스에서 계산한다" 를 붙인다 |
| "이월 이슈" 행 | `harness carryover` 가 만든다(절차는 `script/create-carryover-issue.sh` 로 부른다) |
| "표지" 행 | 정본은 `src/harness/format.py`, 셸 표기는 `script/harness-format.sh` |
| "클론 키" 행 | 계산은 `src/harness/home/clone_key.py` 가 한다 |

`shim` 은 #209 가 둔 "용어" 행을 쓴다. 이 명세는 새 행을 더하지 않는다.

### 11-3. `.ai/project/testing.md`

| 위치 | 반영할 사실 |
|---|---|
| "무엇을 어느 수준으로 검증하나" 의 관리 스크립트 테스트 | 이월 이슈 · 되감기 · 사용 기록의 셸 테스트는 shim 을 거쳐 하위 명령을 보는 계약 테스트다 |
| 단위 테스트 층(`src/test/unit/`) 서술 | 이 명세가 옮긴 모듈(표지 · 사용 기록 · 스팬 기록기 · 검증 · 이월 이슈 · 되감기 · 역할 실행기 · 클론 키)이 든다 |

`.ai/project/scope.md` 는 바뀌지 않는다.

## 12. 이 명세 밖

### 12-1. #221 — shim 과 셸 생성물 정리

main 릴리스를 한 번 거친 뒤 #221 이 맡는다. 대상 리포 `script/` 에 git 훅 shim 과 `script/project/` 만 남는 것이 #221 의 완료 조건이다.

- shim 전부(#209 · #210 · #211 · #212 · #215 · 이 명세) 걷기. `script/run-lint-test.sh` 는 #217 이 릴리스된 뒤 걷는다 — 기존 설치본의 소유 CI 설정이 그것을 부른다
- 셸 생성물 `script/harness.env` · `script/forge.sh` · `script/harness-verify.sh` 걷기
- 셸 표기 `script/harness-format.sh` · `script/usage-vocab.sh` 걷기
- 옛 허용 규칙(`Bash(script/<이름>:*)`) 걷기와 남은 하위 명령의 허용 규칙
- `script/README.md` 걷기 — 가드레일 층위 표와 훅 활성화 절을 옮길 자리 포함
- 최종 명령 표기 — 절차 조각 · 역할 계약 · 역할 어댑터 · 규칙 문서 · `CLAUDE.md` · 실행 계획의 `entry` · 5-2 의 진입점 ·
  doctor 항목 이름과 UI 의 `script/harness-verify.sh` 키. 표기는 render 가 하네스 루트의 종류로 고른 CLI 경로(6절과 같은 접두)다
- `script/harness.env` 를 걷을 때 훅 · 가드의 하네스 루트 판정(지금 `script/harness.env` 가 있는지로 잡는다)을 `harness.toml` 기준으로 바꾸는 일
- `verify.script_tests` 와 "하네스 스크립트 회귀" 단계 — 단계를 없애고, 키는 읽되 무시하며 render · doctor 가 지우라고 알린다
- 셸 회귀 테스트의 거취
- 용어집 "폐기된 별칭" 표의 행

### 12-2. 다른 이슈

| 일 | 이슈 |
|---|---|
| 되감기(`harness rollback`)가 이 클론의 착수 잠금을 푸는 일, 표지 정본 `src/harness/format.py` 와 셸 표기에 리뷰 기록 표지(`FMT_REVIEW_RECORD`)를 더하는 일 — 이 명세 뒤에 온다 | #215 |
| 하네스 CI 게이트 파일의 생성물화 | #217 |

## 13. 한계

- 기존 GitLab 설치본의 소유 `.gitlab-ci.yml` 은 파이프라인 전체를 담고 `script/run-lint-test.sh` 를 직접 부른다
  <!-- TBD: 확인 필요 — #217 의 GitLab 게이트 형태(게이트는 별도 파일로 생성, 루트 `.gitlab-ci.yml` 은 소유)에서 기존 설치본의 이 호출이 남는지. 남으면 #221 이 `script/run-lint-test.sh` 를 걷는 시점에 닿는다 -->
- 단계 시작 표지(`script/metric.py step`)처럼 자주 부르는 경로도 shim 을 거치면 CLI 를 한 번 띄운다. 그 지연은 재지 않았다
- CLI 를 찾지 못한 `script/metric.py start` 는 스팬 id 를 내지 않는다 (4-1)
- 스팬 기록은 실행 계획을 실효 설정에서 계산한다. 개인 레이어가 성립하지 않는 기기에서는 그 레이어를 고칠 때까지 스팬을 남기지 않는다
