# #211 task

## T1 · chore: 리뷰 루프·착수 판정·동기화 sh 테스트의 준비부를 샌드박스 CLI·설정 사본·페이크 주입으로 전환

### 상위 Requirement

- relates to #211

### 작업 내용

하위 명령으로 옮기기 전에, 세 sh 테스트와 `render-test.sh` UT-99 의 준비부를 새 구현이 돌 수 있는 배치로 바꾼다. 하위 명령은 하네스 루트의
CLI 고정 사본 · `harness.toml` · `HARNESS_FORGE_FAKE` 로 돌고, 샌드박스의 `script/forge.sh` 덮어쓰기는 보지 않는다. 바꾸는 것은 준비부뿐이고
검사 줄의 기대값은 그대로다. 이 task 의 변경은 이식 전 구현(셸 스크립트와 `_review.py`)에서 통과해야 한다 — 이식 전 셸 스크립트는
`script/forge.sh` shim 을 거쳐 CLI 의 `harness forge` 를 부르므로 같은 주입 지점이 닿는다.

- 명세 5-2 의 준비부 표 가운데 "배치 목록" 을 뺀 행, `test-review-loop.sh` 의 리뷰 러너 상황 · 실행 계획 실패 · 작성자표시 · UT-31 · UT-32 · UT-33 행,
  `test-sync-task-issues.sh` 의 UT-07 행, 5-5 의 UT-99 행, 5-6 첫 항목
- 세 테스트 공통
  - CLI: 자기 하네스 루트에서 `.harness/bin/harness` → `src/bin/harness` 순서로 CLI 를 찾는다. 없으면 표준 오류에 까닭을 내고 종료 코드 2
  - 고정 사본: 샌드박스 하네스 루트에 그 CLI 의 진입 스크립트 · 패키지 · 템플릿을 `.harness/bin/harness` · `.harness/lib/harness/` ·
    `.harness/templates/` 로 복사한다(`__pycache__` 제외). 심볼릭 링크가 아니라 사본이다
  - 설정: 샌드박스 하네스 루트에 자기 하네스 루트의 `harness.toml` 사본을 둔다. `script/harness.env` 사본은 이식 전 구현과 사용 기록 스크립트를
    위해 지금처럼 둔다
  - 페이크: 페이크 함수 파일을 샌드박스의 `script/forge.sh` 가 아닌 별도 경로(예: `$sandbox/forge-fake.sh`)에 쓰고, forge 를 부르는 실행의
    환경에 `HARNESS_FORGE_FAKE=<그 절대 경로>` 를 준다. 샌드박스 `script/forge.sh` 는 자기 하네스 루트의 생성된 `script/forge.sh`(shim) 사본이다.
    페이크의 함수와 호출 기록은 그대로다
  - git 상태: 샌드박스에 더한 파일(고정 사본 · 설정 사본)은 첫 커밋에 든다
  - `HARNESS_HOME`: 샌드박스에서 CLI 를 부르는 실행은 샌드박스 안 경로를 쓴다
- `test-review-loop.sh` — #207 이 바꾼 준비부(고정 사본 · `metrics.dir` 덮기 · 벤더 선언 사본의 `auth_check` · `exe` · `run-plan` 으로 읽는
  리뷰 러너 · 작성자표시)는 그대로 쓰고, 아래를 바꾼다
  - 상한 `cap` · `repeat` 를 설정 사본의 `review.max_rounds` · `review.repeat_file_max` 로도 덮는다(키나 절이 없으면 더한다). `script/harness.env`
    사본의 덮기는 그대로 둔다
  - 서브에이전트 역할 상황은 설정 사본의 `roles.code-reviewer.runner = "inproc"` 와 `invariants.distinct_reviewer = false` 로 만들고 케이스 뒤에 되돌린다
  - 실행 계획을 받지 못하는 상황은 샌드박스 하네스 루트에 받지 않는 키를 둔 `harness.local.toml` 로 만들고 케이스 뒤에 지운다. 설정 사본을 검증에
    걸리게 만들던 줄은 이것으로 바꾼다. 기대값(종료 코드 2 · 회차 라벨 그대로 · `help: the round was not used — fix the config, then rerun`)은 그대로다
  - UT-31 의 하위 하네스 루트(`$work/sub`)에 `script/` 와 함께 설정 사본과 고정 사본을 둔다
  - UT-32 · UT-33 은 옮긴 페이크 파일을 직접 source 한다
- `test-work-preflight.sh` — 공통 준비부만 바꾼다. `check-open-mrs.sh` 복사는 이식 전 구현이 쓰므로 그대로 둔다
- `test-sync-task-issues.sh` — `build_repo` 가 공통 준비부를 하네스 루트(리포 루트 또는 하위 디렉터리)에 둔다. UT-07 의 직접 호출 두 곳에 주입 환경
  변수를 함께 넘긴다. `lock_path` 는 이 task 에서 바꾸지 않는다
- `render-test.sh` UT-99 — 설치한 리포의 `script/forge.sh` 에 `fake-forge.sh` 를 덮어 쓰지 않고, `pf99` 의 환경에
  `HARNESS_FORGE_FAKE=<src/test/fake-forge.sh 의 절대 경로>` 를 준다. 기대값은 그대로다
- 건드릴 파일: `src/templates/managed/script/test-review-loop.sh` · `test-work-preflight.sh` · `test-sync-task-issues.sh`, `src/test/render-test.sh`,
  render 로 갱신되는 `script/` 사본과 `.harness/managed`

### 완료 조건

- [ ] 세 테스트가 자기 하네스 루트에서 `.harness/bin/harness` → `src/bin/harness` 순서로 CLI 를 찾고, 둘 다 없으면 종료 코드 2 로 끝난다
- [ ] 세 테스트의 샌드박스 하네스 루트에 CLI 고정 사본(`.harness/bin/harness` · `.harness/lib/harness/` · `.harness/templates/`)과 `harness.toml` 사본이 있고 첫 커밋에 든다
- [ ] 세 테스트와 UT-99 가 `script/forge.sh` 자리에 페이크를 덮어 쓰지 않는다. 페이크는 `HARNESS_FORGE_FAKE` 로만 끼우고, 그 값을 테스트 전체에 내보내지 않는다
- [ ] `test-review-loop.sh` 의 상한이 설정 사본의 `review.max_rounds` · `review.repeat_file_max` 에 들어 있다
- [ ] 서브에이전트 역할 상황이 설정 사본으로, 실행 계획 실패 상황이 성립하지 않는 `harness.local.toml` 로 만들어진다
- [ ] UT-31 의 하위 하네스 루트에 설정 사본과 고정 사본이 함께 있고, UT-07 의 직접 호출 두 곳이 주입 환경 변수를 넘긴다
- [ ] 검사 줄의 기대값(종료 코드 · 표준 출력 · 표준 오류 문구 · 페이크 호출 기록 · 라벨 · 이력 파일 · 사용 기록 · 지표)이 하나도 바뀌지 않는다
- [ ] 이식 전 구현에서 세 테스트가 소스 리포에서 통과하고, `render-test.sh` 가 통과한다 — 설치한 리포와 모노레포 서브프로젝트의 세 테스트 포함
- [ ] 세 테스트가 실제 홈의 등록부 · 지표 · 사용 기록에 쓰지 않는다
- [ ] `src/bin/harness render` 뒤 `script/` 사본이 정본과 같고 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/211-port-work-steps` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 리뷰 루프 오라클이 옮긴 준비부로 통과 | 이식 전 `review-mr.sh` · `post-review.sh` 에 `script/test-review-loop.sh` | 종료 코드 0, 실패 케이스 0 |
| UT-02 | 착수 판정 · 동기화 오라클이 옮긴 준비부로 통과 | 이식 전 `work-preflight.sh` · `sync-task-issues.sh` 에 두 테스트 | 각각 종료 코드 0 |
| UT-03 | 페이크가 주입 지점으로만 끼워진다 | 세 테스트의 샌드박스 `script/forge.sh` | 자기 하네스 루트의 생성된 `script/forge.sh` 와 같은 내용 |
| UT-04 | 서브에이전트 역할 상황 | 설정 사본 `roles.code-reviewer.runner = "inproc"` · `invariants.distinct_reviewer = false` 로 `review-mr.sh 1` | 2, `error: no review runner is configured`, 로그인 확인 없음, 회차 라벨 그대로 |
| UT-05 | 실행 계획 실패 상황 | 받지 않는 키를 둔 `harness.local.toml` 로 `review-mr.sh 1` | 2, 회차 라벨 그대로, `help: the round was not used — fix the config, then rerun` |
| UT-06 | 하위 하네스 루트의 이력 | UT-31 의 `$work/sub` 에서 `post-review.sh` | 1, 이력이 공통 git 디렉터리에 있다 |
| UT-07 | 설치본 착수 판정의 이슈 확인 | UT-99 — 설치한 리포에서 주입 환경 변수로 `script/work-preflight.sh 100` | 닫힘 1 · 조회 실패 2 · 상태 없음 2, 기존 문구와 사용 기록 라벨 |

## T2 · refactor: 착수 판정을 harness preflight 로 이식하고 work-preflight.sh 를 shim 으로 전환

### 상위 Requirement

- relates to #211

### 작업 내용

착수 판정 로직을 하위 명령 `harness preflight` 로 옮기고 `script/work-preflight.sh` 를 그 명령을 부르는 shim 으로 바꾼다. 세 명령이 함께 쓰는
처리와 이식하지 않은 관리 스크립트를 부르는 경계 모듈 `src/harness/scripts.py` 를 이 task 에서 둔다. 판정 순서 · 표준 출력 · 종료 코드 ·
표준 오류 문구 · 사용 기록 라벨은 이식 전과 같다.

- 명세 2-1(공통) · 2-4 · 3-1 · 3-4 의 `check-open-mrs.sh` · 4절의 `commands/preflight.py` · `scripts.py` · 5-2 의 배치 목록(`test-work-preflight.sh`) ·
  5-3 의 `test-work-preflight.sh` 행 · 5-4 의 인자 규칙 · 예외 · 신호 · 명령 표 · 5-5 의 도움말 · 6절의 `script/README.md` 행
- 명령 표: `COMMANDS` 에 `"preflight": (True, True, "<issue>", "decide whether work on an issue can start: prints plan or standalone")`,
  `DELEGATES` 에 `preflight`. 모듈은 `src/harness/commands/preflight.py`, 진입 함수 `cmd_preflight`
- 인자: 값 하나, 형식을 검사하지 않는다. 개수가 다르면 `usage: harness preflight <issue-number>`, `-` 로 시작하는 인자(`--json` · `-h` · `--help` ·
  이름 바로 뒤가 아닌 `--target` 포함)는 `error: unknown option: <인자>` 와 사용법 — 모두 종료 코드 2 이고 forge 를 부르지 않는다
- 설정: 공유 설정의 `branches.base`. 개인 레이어 파일을 열지 않는다
- 순서: 명세 2-4 표 — git → `tracker_require` → 이슈(`docs/spec/60-automate-work-prerequisites.md` 4-1 표) → `review_require` ·
  `harness_issue_open_mrs` → `git fetch -q origin <통합 브랜치>` → `FETCH_HEAD` 의 `<접두>docs/plan/<이슈>/task.md` → `<접두>docs/spec/<이슈>-*` → 판정.
  `<접두>` 는 하네스 루트에서 `git rev-parse --show-prefix` 를 돌린 출력이다. 열린 리뷰 요청은 계약 함수를 어댑터로 직접 부르고
  `script/check-open-mrs.sh` 를 부르지 않는다
- 부수 기록: 스팬 `work-preflight`(종류 `script`, 속성 `script=work-preflight`). 사용 기록은 종류 `preflight`, 출처 `work-preflight`, 상세는 명세 2-4 표의
  라벨이고 표에 라벨이 있는 경로에서만 남긴다
- `scripts.py`
  - 사용 기록: 하네스 루트의 `script/usage-log.sh <종류> <출처> <상세>` 를 부른다. 그 종료 코드는 판정에 닿지 않는다
  - 지표 감싸기: 명령이 자기 실행 전체를 `script/metric.py wrap --name <이름> --kind script --attr script=<이름> -- <자기 진입 스크립트> <같은 인자>` 로
    다시 실행한다. 감싼 실행의 환경에 `HARNESS_METRIC_SELF=<이름>`. 그 값이 이미 그 이름이거나 하네스 루트의 `script/metric.py` 가 실행 파일이
    아니면 감싸지 않는다. 감싸기는 명령 자신의 인자 검사보다 앞이다
- 공통 처리
  - 처리하지 않은 예외: 표준 오류에 트레이스백과 마지막 줄 `error: harness preflight stopped on an unexpected error`, 종료 코드 2
  - SIGINT · SIGTERM: 128 + 신호 번호로 끝난다
  - 표준 출력은 줄마다 바로 내보낸다
- `work-preflight.sh` 머리 주석의 설명(이슈를 먼저 보고 열린 리뷰 요청을 그다음에 보는 까닭, 착수 전과 위임 직전에 같은 명령을 돈다)을
  `commands/preflight.py` 머리 설명으로 옮긴다
- shim `src/templates/managed/script/work-preflight.sh` — 명세 3-1 의 형태와 문구. `script/harness.env` · `script/forge.sh` 를 source 하지 않고 감싸기 ·
  사용 기록을 하지 않는다. 실행 권한은 그대로다
- `check-open-mrs.sh` 는 고치지 않는다
- `test-work-preflight.sh`: 복사 목록에서 `check-open-mrs.sh` 를 뺀다. 명세 5-3 케이스를 더한다
- `script/README.md`: `work-preflight.sh` 행 용도에 "`harness preflight` 를 부르는 shim" 을 적는다(종료 코드 설명은 그대로). `check-open-mrs.sh` 행의
  호출 시점을 "수동 — 착수 판정은 같은 조회를 `harness preflight` 안에서 한다" 로 바꾼다. "규칙" 절에 "하위 명령은 설정을 직접 읽고, 표지를 표지
  모듈로 읽는다" 를 더한다
- `render-test.sh`: 하위 명령 블록 `UT-<번호>` 를 새로 두고 도움말 케이스를 넣는다. T3 · T4 가 같은 블록에 케이스를 더한다
- 건드릴 파일: `src/harness/commands/__init__.py` · `src/harness/commands/preflight.py`(신규) · `src/harness/cli.py` · `src/harness/scripts.py`(신규),
  공통 처리를 둘 공용 모듈, `src/templates/managed/script/work-preflight.sh` · `test-work-preflight.sh` · `README.md`, `src/test/render-test.sh`,
  `src/test/unit/test_preflight.py`(신규), render 로 갱신되는 `script/` 사본과 `.harness/managed`

### 완료 조건

- [ ] `harness preflight <이슈>` 가 명세 2-4 의 순서 · 표준 출력 · 표준 오류 · 사용 기록 라벨 · 종료 코드를 낸다
- [ ] `script/work-preflight.sh` 가 명세 3-1 의 shim 이고, CLI 를 찾지 못하면 2 와 `error: harness CLI not found under <루트> (.harness/bin/harness or src/bin/harness)` · `help: harness install --target <루트>` 를 낸다
- [ ] 명령이 `script/check-open-mrs.sh` 와 `script/forge.sh` 를 부르지 않고, `harness_issue_open_mrs` 를 어댑터로 부른다
- [ ] 개인 레이어 파일이 깨져 있어도 판정이 그대로다
- [ ] `COMMANDS` 의 `preflight` 항목이 통과 표시 `True` · 설정 필요 `True` 이고 `DELEGATES` 에 있다. `harness help` 에 `preflight` 줄이 있다
- [ ] `test-work-preflight.sh` 의 기존 검사 줄이 기대값 그대로 통과하고, 더한 케이스가 통과한다
- [ ] `render-test.sh` UT-99 와 설치한 리포 · 모노레포 서브프로젝트의 `test-work-preflight.sh` 가 통과한다
- [ ] 하네스 루트와 `script/` 에 `__pycache__` 가 생기지 않는다
- [ ] `python3 script/project/check-cli.py imports` 와 `cd src && python3 -B -m unittest discover -s test/unit` 이 통과한다
- [ ] `src/bin/harness render` 뒤 `script/` 사본이 정본과 같고 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/211-port-work-steps` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 인자 거부 | 인자 없음 · `1 2` | 2, 표준 오류에 `usage: harness preflight <issue-number>`, forge 호출 0 |
| UT-02 | 옵션 거부 | `--json` · `-h` · `--help` · `1 --target D` | 2, `error: unknown option: <인자>` 와 사용법, forge 호출 0 |
| UT-03 | 이름 바로 뒤의 `--target` | `parse_command_line(["preflight", "--target", "D", "1"])` | 하네스 루트 `D`, 명령 인자 `1` |
| UT-04 | 처리하지 않은 예외 | 판정 도중 예외를 내도록 바꿔 끼운 함수 | 2, 표준 오류 마지막 줄 `error: harness preflight stopped on an unexpected error` |
| UT-05 | 신호 | 명령의 SIGTERM · SIGINT 처리를 부른다 | 143 · 130 |
| UT-06 | 개인 레이어를 열지 않는다 | 깨진 `harness.local.toml` 이 있는 하네스 루트, 열린 이슈 · 분해 없음 | 0, 표준 출력 `standalone` |
| UT-07 | 명령 표 | `COMMANDS["preflight"]` · `DELEGATES` | `(True, True, "<issue>", …)`, `DELEGATES` 에 있음 |
| UT-08 | 감싸기 판정 | `HARNESS_METRIC_SELF=work-preflight` · 실행 파일이 아닌 `script/metric.py` | 둘 다 다시 실행하지 않는다 |
| UT-09 | 오라클 | `script/test-work-preflight.sh` | 0 |
| UT-10 | 옵션 인자는 이슈 조회 전에 거부 | `script/work-preflight.sh 100 --json` · `script/work-preflight.sh --help` | 2, 이슈 조회 0 |
| UT-11 | 도움말 | `harness help` | `preflight` 줄이 있다 |

## T3 · refactor: task 이슈 동기화를 harness sync-tasks 로 이식하고 sync-task-issues.sh 를 shim 으로 전환

### 상위 Requirement

- relates to #211

### 작업 내용

task 이슈 동기화 로직을 하위 명령 `harness sync-tasks` 로 옮기고 `script/sync-task-issues.sh` 를 그 명령을 부르는 shim 으로 바꾼다. 승인된
분해로만 이슈가 생기는 게이트, 잠금, 재조회로 잡는 경합, 표준 출력의 task → 이슈 매핑은 이식 전과 같다.

- 명세 2-1 · 2-5 · 3-1 · 4절의 `commands/sync_tasks.py` · 5-2 의 `lock_path` 행 · 5-3 의 `test-sync-task-issues.sh` 행 · 5-4 의 인자 규칙 · 예외 ·
  잠금 경로 · 신호 · 명령 표 · 5-5 의 도움말 · 6절의 `script/README.md` 행
- 명령 표: `COMMANDS` 에 `"sync-tasks": (True, True, "<parent-issue> [--dry-run]", "create the task issues of an approved breakdown that do not exist yet (writes to the remote)")`,
  `DELEGATES` 에 `sync-tasks`. 모듈은 `src/harness/commands/sync_tasks.py`, 진입 함수 `cmd_sync_tasks`
- 인자: `<상위이슈>` 하나 또는 `<상위이슈> --dry-run`. 개수가 다르면 `usage: harness sync-tasks <parent-issue-number> [--dry-run]`, 첫 인자가 `-` 로
  시작하거나 둘째가 정확히 `--dry-run` 이 아니면 `error: unknown option: <그 인자>` 와 사용법 — 모두 종료 코드 2 이고 목록 조회 · 생성을 하지 않는다
- 설정: 공유 설정의 `branches.base` · `commit.issue_ref` · `issues.required_fields` · `issues.labels.task`. 개인 레이어 파일을 열지 않는다
- 순서: 명세 2-5 표의 1 ~ 9 — 트래커 → 잠금 → git → fetch → `FETCH_HEAD:<접두>docs/plan/<상위이슈>/task.md` → 조회 → 계획(표준 오류
  `breakdown tasks: <n>  ·  to create: <m>`) → 재조회 → 생성. 멈추면 전부 종료 코드 2, 1 은 쓰지 않는다
- 계획 규칙: task 절을 표지 `FMT_TASK_HEADING` 으로 줄 단위로 가른다(`format.markers(root)`, 읽지 못하면 표준 오류에 `error:` 와 표지 이름, 종료 코드 2).
  이슈 제목 `<절 제목>(<상위이슈 참조>)`, 본문은 절 내용의 앞뒤 공백을 뺀 것, 기존 이슈는 제목(앞뒤 공백 제외)이 같은 목록 항목, 생성 인자는
  제목 · 본문 · task 라벨 · 상위 이슈의 `assignee` · `milestone`
- 표준 출력: task 절 순서대로 `T<N> <참조>  skip(<상태>)` · `T<N> <참조>  created` · `T<N> (dry-run) create  <제목>`
- 잠금
  - 경로: `TMPDIR` 값(비었거나 없으면 `/tmp`) 뒤에 `/harness-sync-<cksum>-<상위이슈>` 를 그대로 이어 붙인 문자열. `<cksum>` 은 하네스 루트를 심볼릭
    링크까지 푼 절대 경로를 개행 없이 넣었을 때 POSIX `cksum` 이 내는 CRC 값(10진)이다. 외부 `cksum` 명령을 부르지 않고 표준 라이브러리로 계산한다
  - 디렉터리 하나를 원자적으로 만들고, 안에 `owner` 파일(`pid: <pid>` · `host: <호스트 이름>` · `started: <YYYY-MM-DD HH:MM:SS>`, 지역 시각)을 둔다
  - 만들지 못하면 `stop: another sync is already running for issue <상위이슈>`, `  lock: <경로>`, 주인 기록이 있으면 두 칸 들여 쓴 그 내용, `help:` 두 줄
  - 어느 경로로 끝나든(처리하지 않은 예외 · SIGINT · SIGTERM 포함) 잠금을 지운다
- 부수 기록: 스팬 `sync-task-issues`(종류 `script`, 속성 `script=sync-task-issues`). 사용 기록은 남기지 않는다
- 공통 처리는 T2 의 것을 쓴다. 예외의 마지막 줄은 `error: harness sync-tasks stopped on an unexpected error`
- `sync-task-issues.sh` 머리 주석의 설명(승인 게이트, 두 번 돌려도 중복이 없는 까닭, 잠금과 재조회의 몫)을 `commands/sync_tasks.py` 머리 설명으로 옮긴다
- shim `src/templates/managed/script/sync-task-issues.sh` — 명세 3-1 의 형태와 문구
- `test-sync-task-issues.sh`: `lock_path` 가 하네스 루트를 `pwd -P` 로 푼 경로로 계산한다. 명세 5-3 케이스를 더한다
- `script/README.md`: `sync-task-issues.sh` 행 용도에 "`harness sync-tasks` 를 부르는 shim" 을 적는다
- `render-test.sh`: 하위 명령 블록에 도움말 케이스를 더한다
- 건드릴 파일: `src/harness/commands/__init__.py` · `src/harness/commands/sync_tasks.py`(신규) · `src/harness/cli.py`,
  `src/templates/managed/script/sync-task-issues.sh` · `test-sync-task-issues.sh` · `README.md`, `src/test/render-test.sh`,
  `src/test/unit/test_sync_tasks.py`(신규), render 로 갱신되는 `script/` 사본과 `.harness/managed`

### 완료 조건

- [ ] `harness sync-tasks` 가 명세 2-5 의 인자 · 순서 · 표준 출력 · 표준 오류 · 종료 코드(0 · 2)를 낸다
- [ ] 잠금 경로가 명세 2-5 의 규칙대로이고, 어느 경로로 끝나든 잠금 디렉터리가 남지 않는다
- [ ] 계획 뒤 목록에 같은 제목이 생기면 하나도 만들지 않는다. 생성이 실패하면 그 자리에서 멈추고 앞에서 만든 이슈는 남는다
- [ ] `script/sync-task-issues.sh` 가 명세 3-1 의 shim 이다
- [ ] 개인 레이어 파일이 깨져 있어도 동기화가 그대로다
- [ ] `COMMANDS` 의 `sync-tasks` 항목이 통과 표시 `True` · 설정 필요 `True` 이고 `DELEGATES` 에 있다. `harness help` 의 `sync-tasks` 줄에 `writes to the remote` 가 있다
- [ ] `test-sync-task-issues.sh` 의 기존 검사 줄이 기대값 그대로 통과하고, 더한 케이스가 통과한다. 설치한 리포 · 모노레포 서브프로젝트에서도 통과한다
- [ ] 하네스 루트와 `script/` 에 `__pycache__` 가 생기지 않는다
- [ ] `python3 script/project/check-cli.py imports` 와 `cd src && python3 -B -m unittest discover -s test/unit` 이 통과한다
- [ ] `src/bin/harness render` 뒤 `script/` 사본이 정본과 같고 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/211-port-work-steps` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 인자 거부 | 인자 없음 · `1 2 3` | 2, 사용법, 목록 조회 0 · 생성 0 |
| UT-02 | 옵션 거부 | `-1` · `100 --dry` · `--dry-run 100` · `100 --json` · `100 --target D` | 2, `error: unknown option: <인자>` 와 사용법, 목록 조회 0 · 생성 0 |
| UT-03 | 잠금 경로의 CRC | 공백 · 한글 · 심볼릭 링크가 든 하네스 루트 여러 개 | `<cksum>` 이 `printf %s <푼 경로> \| cksum` 의 첫 칸과 같다 |
| UT-04 | 잠금 경로의 이어 붙이기 | `TMPDIR=/x/` · `TMPDIR` 빈 값 · 없음 | `/x//harness-sync-…` · `/tmp/harness-sync-…` · `/tmp/harness-sync-…` |
| UT-05 | 주인 기록 | 잡은 잠금의 `owner` | `pid:` · `host:` · `started:` 세 줄 |
| UT-06 | 신호 | 잠금을 잡은 뒤 SIGINT · SIGTERM 처리를 부른다 | 잠금 디렉터리 없음, 130 · 143 |
| UT-07 | 처리하지 않은 예외 | 계획 도중 예외를 내도록 바꿔 끼운 함수 | 2, 마지막 줄 `error: harness sync-tasks stopped on an unexpected error`, 잠금 디렉터리 없음 |
| UT-08 | 표지를 읽지 못함 | 표지 파일에 `FMT_TASK_HEADING` 이 없는 하네스 루트 | 2, 표준 오류에 `error:` 와 `FMT_TASK_HEADING`, 생성 0 |
| UT-09 | 개인 레이어를 열지 않는다 | 깨진 `harness.local.toml` 이 있는 하네스 루트에서 `--dry-run` | 0, `(dry-run) create` 줄 |
| UT-10 | 명령 표 | `COMMANDS["sync-tasks"]` · `DELEGATES` | `(True, True, "<parent-issue> [--dry-run]", …)`, `DELEGATES` 에 있음 |
| UT-11 | 오라클 | `script/test-sync-task-issues.sh` | 0 |
| UT-12 | 줄임 철자와 순서 바뀐 인자 | `script/sync-task-issues.sh 100 --dry` · `script/sync-task-issues.sh --dry-run 100` | 2, 목록 조회 0, 생성 0 |
| UT-13 | 도움말 | `harness help` | `sync-tasks` 줄에 `writes to the remote` |

## T4 · refactor: 리뷰 루프를 harness review 로 이식하고 review-mr.sh·post-review.sh 를 shim 으로 전환

### 상위 Requirement

- relates to #211

### 작업 내용

리뷰 루프 로직을 하위 명령 `harness review`(리뷰 실행)와 `harness review post`(등록)로, 판정 데이터 · 집계 · 등록 댓글 렌더링 · 리뷰 입력 맥락 ·
회차 · 반복 지적 이력을 리뷰 모듈 `src/harness/review.py` 로 옮긴다. `script/review-mr.sh` · `script/post-review.sh` 는 shim 이 되고
`script/_review.py` 는 없어진다. 회차 라벨을 올리는 코드는 `harness review` 하나다. 판정 데이터 계약 · 집계 · 등록 댓글 · 리뷰 입력의 절 구성 ·
이력의 자리와 형식 · 종료 코드는 이식 전과 같다.

- 명세 1절 · 2-1 · 2-2 · 2-3 · 3-1 · 3-2 · 3-4 의 `_review.py` · 4절의 `commands/review.py` · `review.py` · `scripts.py` · 5-2 의 `test-review-loop.sh`
  가운데 새 구현에서만 성립하는 행 · 5-3 의 `test-review-loop.sh` 행 · 5-4 의 스키마와 역할 계약 · 회차 · 표지 · 인자 규칙 · 실행 계획 · 예외 · 신호 · 명령 표 ·
  5-5 의 옛 모듈 정리 · 허용 목록의 모듈 스크립트 · 도움말 · 6절의 `script/README.md` · `harness-format.sh` 행
- 명령 표: `COMMANDS` 에 `"review": (True, True, "[--force] <number> | post <number> - [label] [revision]", "review a review request's diff, post the result and count the round (writes to the remote)")`,
  `DELEGATES` 에 `review`. 모듈은 `src/harness/commands/review.py`, 진입 함수 `cmd_review`
- 인자
  - `review`: `--force`(몇 번이든, 어느 자리든)와 숫자 번호 하나. 번호가 없으면 사용법, 둘이면 `error: expected one number, got two: <앞>, <뒤>`,
    숫자가 아니면 `error: the number must be numeric, got '<값>'` 과 사용법. 그 밖의 `-` 인자는 `error: unknown option: <인자>` 와 사용법. 모두 2 이고
    사용 기록을 남기지 않는다
  - 첫 위치 인자가 `post` 면 등록이다. `post` 와 `--force` 는 함께 받지 않는다. `post` 다음 인자는 전부 값이다 — 2 ~ 4개이고 둘째가 정확히 `-`
  - 사용법 두 줄은 명세 2-1-3
- 설정과 실행 계획
  - 공유 설정의 `review.max_rounds` · `review.repeat_file_max` · `review.round_label`
  - 리뷰 러너와 작성자표시는 같은 프로세스에서 #207 의 실효 설정 읽기와 `run_plan()` 으로 계산한 실행 계획의 `roles.code-reviewer`(`exe` · `label`)다.
    `harness run-plan` 을 하위 프로세스로 부르지 않고 실행 계획 파일을 읽지 않는다
  - `review` 는 실행 계획을 계산하지 못하면 그 오류 문구 뒤에 `help: the round was not used — fix the config, then rerun` 을 내고 forge 를 부르기 전에 2
  - `review post` 는 작성자표시가 없거나 빈 문자열일 때만 실행 계획을 계산한다. 계산하지 못하거나 `code-reviewer` 가 없으면 `자동 리뷰` 로 등록을 계속한다
- 순서: 명세 2-2 표의 1 ~ 14(실행 계획 → 리뷰 러너 → 러너 점검 → 역할 계약 → 리뷰 호스트 → 리뷰 요청 조회 → 회차 읽기 → 회차 상한 → 리비전 일치 →
  diff → 회차 라벨 → 맥락 → 리뷰어 실행 → 등록)와 2-3 표의 1 ~ 9. 14단계는 `review post` 와 같은 구현을 같은 프로세스에서 부르고, 작성자표시는
  1단계 실행 계획의 `label`, 리뷰한 리비전은 9단계에서 원격 head 와 맞춰 본 `HEAD` 다
- 리뷰 입력(머리말 · 맥락 절 · 증분 diff · 누적 diff), 증분 기준의 판정, 리뷰어 프롬프트, 리뷰 입력을 표준 입력으로 넘기는 방식은 이식 전과 같다.
  임시 디렉터리는 끝날 때 지운다
- `review.py`
  - 판정 데이터 스키마(최상위 키 · 발견 키 · 심각도 · 허용 값)를 한 곳에 정의하고 검증 · 집계 · 렌더링이 함께 쓴다
  - 인라인 발견 접두를 만드는 코드와 알아보는 코드, 맥락의 절 추출 · 인용, 회차 계산, 반복 지적 이력 읽기 · 쓰기를 갖는다
  - forge 와 하위 프로세스를 부르지 않는다. forge 응답과 설정 값은 인자로 받는다
  - 옮기는 상수 · 함수의 이름은 `_review.py` 의 것을 쓴다. 이력 형식 판별자는 `HIST_FORMAT = "#format 1"` 한 줄 상수다 — sh 테스트가 그 줄을 읽는다
  - `review-mr.sh` · `post-review.sh` 머리 주석의 설명(회차를 스스로 세는 까닭, 동시 실행을 지원하지 않는 것, 등급 집계로 판정하는 까닭, 반복 키가 파일
    경로 하나인 까닭과 보조 상한인 것, 등록을 리뷰어와 가르는 까닭)을 `commands/review.py` 와 `review.py` 머리 설명으로 옮긴다
- `scripts.py`: 역할 실행기 `script/run-agent.py` 를 `code-reviewer --check`(표준 출력은 버린다)와 `code-reviewer --out <파일> --prompt <프롬프트>` 로
  부르는 함수를 더한다. 인자 · 입출력은 이식 전과 같다
- 부수 기록: 스팬 `review-mr`(`review post` 는 따로 남기지 않는다). 사용 기록은 인자 검사를 통과한 뒤 어느 경로로 끝나든 한 줄 — 종류 `review`,
  출처 `review-mr`, 상세 `mr=<번호> round=<회차> exit=<종료 코드>`, 3 이면 `stop=mrl-cap` 또는 `stop=repeat`. 회차는 라벨 갱신 성공 전에는 읽은 회차,
  뒤에는 올린 회차
- 공통 처리는 T2 의 것을 쓴다. 예외의 마지막 줄은 `error: harness review stopped on an unexpected error` · `error: harness review post stopped on an unexpected error`.
  SIGINT · SIGTERM 이면 임시 디렉터리를 지우고, `review` 는 사용 기록을 남긴 뒤 128 + 신호 번호로 끝난다
- shim
  - `src/templates/managed/script/review-mr.sh` — 명세 3-1
  - `src/templates/managed/script/post-review.sh` — 명세 3-2. 인자가 2개보다 적으면 사용법과 2, 본문 파일이 없거나 비었으면
    `error: the review body is empty: <본문파일>` 과 2(CLI 를 찾지 않는다). 상대 경로는 하네스 루트 기준이고 절대 경로도 받는다. 본문 파일을 표준 입력으로
    해서 `<CLI> --target <루트> review post <번호> - [작성자표시] [리뷰한리비전]` 을 exec 하고, 다섯째부터의 인자는 넘기지 않는다
- `src/templates/managed/script/_review.py` 를 지운다. 이 리포의 `script/_review.py` 는 render 의 정리가 지운다
- `src/templates/managed/script/harness-format.sh`: 절 머리 주석의 `_review.py` 를 `src/harness/review.py` 로
- `test-review-loop.sh`
  - 이력 형식 판별자를 패키지의 `review.py`(`.harness/lib/harness/review.py` → `src/harness/review.py` 순서)에서 읽는다
  - 복사 목록과 필수 파일 확인에서 `_review.py` 를 뺀다
  - UT-21 · UT-26 · UT-27 을 지우고 단위 테스트로 옮긴다. UT-24 · UT-28 은 그대로 둔다
  - 명세 5-3 의 다섯 케이스를 더한다
- `render-test.sh`
  - 옛 모듈 정리: 설치한 리포에 `script/_review.py` 와 그 매니페스트 줄을 두고 render 하면 그 파일이 없어지고 매니페스트에서 빠진다
  - 허용 목록의 모듈 스크립트 검사의 대상을 `script/_clone_key.py` 로 바꾸고, 그 파일이 설치돼 있는지 먼저 본다
  - 하위 명령 블록에 도움말 케이스를 더한다
- `script/README.md`: `review-mr.sh` · `post-review.sh` 행 용도에 "`harness review` 를 부르는 shim" · "`harness review post` 를 부르는 shim" 을 적는다(종료 코드
  설명은 그대로). `post-review.sh` 행의 호출 시점은 사용자 지시 등록(`code-reviewer` · `security-guard` 어댑터, `/security-guard`)이다. `_review.py` 행을 지운다
- 건드릴 파일: `src/harness/review.py`(신규) · `src/harness/commands/review.py`(신규) · `src/harness/commands/__init__.py` · `src/harness/cli.py` ·
  `src/harness/scripts.py`, `src/templates/managed/script/review-mr.sh` · `post-review.sh` · `_review.py`(삭제) · `harness-format.sh` · `test-review-loop.sh` ·
  `README.md`, `src/test/render-test.sh`, `src/test/unit/test_review.py` · `test_review_command.py`(신규), render 로 갱신되는 `script/` 사본과 `.harness/managed`

### 완료 조건

- [ ] `harness review` 가 명세 2-2 의 순서 · 표준 출력 · 종료 코드(0 · 1 · 2 · 3)를 내고, 회차 라벨을 올리는 코드가 `commands/review.py` 하나다
- [ ] `harness review post` 가 명세 2-3 의 인자 · 순서 · 표준 출력 한 줄 · 종료 코드를 낸다
- [ ] 리뷰 러너와 작성자표시를 같은 프로세스의 실행 계획에서 받고, `harness run-plan` 하위 프로세스와 실행 계획 파일을 쓰지 않는다
- [ ] `review.py` 가 `subprocess` 와 `harness.forge` 를 불러오지 않는다
- [ ] `script/review-mr.sh` · `script/post-review.sh` 가 명세 3-1 · 3-2 의 shim 이고 `src/templates/managed/script/_review.py` 가 없다
- [ ] 이 리포의 `script/_review.py` 가 없고 `.harness/managed` 에 그 줄이 없다
- [ ] 권한 허용 목록(`.claude/settings.json`)이 render 전과 같다
- [ ] `COMMANDS` 의 `review` 항목이 통과 표시 `True` · 설정 필요 `True` 이고 `DELEGATES` 에 있다. `harness help` 의 `review` 줄에 `writes to the remote` 가 있다
- [ ] `test-review-loop.sh` 의 남은 검사 줄이 기대값 그대로 통과하고, 더한 케이스가 통과한다. 설치한 리포 · 모노레포 서브프로젝트에서도 통과한다
- [ ] `render-test.sh` 의 옛 모듈 정리 · 허용 목록 · 도움말 케이스가 통과한다
- [ ] 하네스 루트와 `script/` 에 `__pycache__` 가 생기지 않는다
- [ ] `python3 script/project/check-cli.py imports` 와 `cd src && python3 -B -m unittest discover -s test/unit` 이 통과한다
- [ ] `src/bin/harness render` 뒤 `script/` 사본이 정본과 같고 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/211-port-work-steps` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 스키마와 역할 계약 | `review.py` 의 최상위 키 · 발견 키 · 심각도, 표지 `FMT_REVIEW_BLOCK` · `FMT_VERDICT_PASS` · `FMT_VERDICT_CHANGES` 와 `src/templates/managed/.ai/templates/code-reviewer.md` · `security-guard.md` | 모두 두 계약에 백틱으로 둘러싸여 있다. 두 계약에 `## 발견 사항` · `REVIEW_VERDICT` 가 없다 |
| UT-02 | 회차 | 라벨 `<접두>:1` · `other` · `<접두>:3` · `<접두>:x` / `other` 만 | 회차 3 과 회차 라벨 `<접두>:1 <접두>:3` / 회차 0 |
| UT-03 | 표지를 읽지 못함 | 표지 파일에 필요한 표지가 없는 하네스 루트에서 `review 1` | 2, 표준 오류에 `error:` 와 표지 이름, 회차 라벨 갱신 0 |
| UT-04 | `review` 인자 거부 | 인자 없음 · `1 2` · `x` · `--json` · `--forc` · `-h` · `--force post 1 -` · `1 --target D` | 2, 명세 2-2 · 2-1-3 의 문구, forge 호출 0, 사용 기록 0 |
| UT-05 | `review post` 인자 | `post 1` · `post 1 x` · `post 1 - a b c` / `post 1 - --label` | 2, 사용법 / `--label` 을 작성자표시로 받는다 |
| UT-06 | 실행 계획 실패 | 받지 않는 키를 둔 `harness.local.toml` 로 `review 1` | 2, `help: the round was not used — fix the config, then rerun`, forge 호출 0 |
| UT-07 | 개인 레이어의 리뷰 러너 | 같은 공유 설정에 개인 레이어 `roles.code-reviewer.runner` 만 다른 CLI 벤더 | 등록에 넘기는 작성자표시가 그 벤더 선언의 `label` |
| UT-08 | `review post` 작성자표시 기본값 | 작성자표시 없음 / 실행 계획을 계산하지 못함 | 실행 계획의 `label` / `자동 리뷰`, 등록은 계속 |
| UT-09 | 처리하지 않은 예외 | 명령 본문에서 예외를 내도록 바꿔 끼운 함수 — `review` · `review post` | 2, 마지막 줄 `error: harness review stopped on an unexpected error` · `error: harness review post stopped on an unexpected error` |
| UT-10 | 신호 | 임시 디렉터리를 만든 뒤 SIGTERM 처리를 부른다 | 임시 디렉터리 없음, 사용 기록 한 줄, 143 |
| UT-11 | 리뷰 모듈의 경계 | `review.py` 의 import | `subprocess` · `harness.forge` 없음 |
| UT-12 | 명령 표 | `COMMANDS["review"]` · `DELEGATES` | 통과 표시 `True` · 설정 필요 `True`, `DELEGATES` 에 있음 |
| UT-13 | 오라클 | `script/test-review-loop.sh` | 0 |
| UT-14 | 다른 명령의 옵션과 줄임 철자 | `script/review-mr.sh --json` · `--forc` · `-h` | 각각 2, 회차 라벨 그대로, 리뷰어 호출 0, forge 호출 0 |
| UT-15 | 없는 본문 파일 | `script/post-review.sh 1 <없는 파일>` | 2, `error: the review body is empty`, 등록 호출 0 |
| UT-16 | 하네스 루트 기준 상대 경로 | 하네스 루트가 아닌 디렉터리에서 상대 경로 본문으로 `post-review.sh` | 등록된다 |
| UT-17 | shim 의 작성자표시 기본값 | 작성자표시 없이 `post-review.sh` / 성립하지 않는 `harness.local.toml` 을 둔 뒤 | 요약에 벤더 선언 사본의 리뷰 러너 `label` / `자동 리뷰`, 종료 코드는 판정대로 |
| UT-18 | CLI 없음 | 샌드박스에서 고정 사본을 치운 뒤 `review-mr.sh 1` | 2, `error: harness CLI not found under` · `help: harness install --target` |
| UT-19 | 옛 모듈 정리 | `script/_review.py` 와 그 매니페스트 줄을 둔 설치 리포에서 render | 파일과 매니페스트 줄이 없다 |
| UT-20 | 허용 목록의 모듈 스크립트 | 설치한 리포의 `.claude/settings.json` | `script/_clone_key.py` 가 설치돼 있고 허용 목록에 없다 |
| UT-21 | 도움말 | `harness help` | `review` 줄에 `writes to the remote` |

## T5 · docs: README 명령 표와 관련 명세를 하위 명령 기준으로 갱신

### 상위 Requirement

- relates to #211

### 작업 내용

T2 ~ T4 가 만든 하위 명령을 사람용 설명과 이 리포의 다른 명세에 적는다. 각 문서는 통합 브랜치의 현재 문장(앞 이슈들이 고친 것)을 기준으로 고친다.

- 명세 6절
- `README.md` "명령" 표에 명세 6절의 세 행(`harness review …` · `harness preflight <이슈>` · `harness sync-tasks <상위이슈> [--dry-run]`)을 더한다
- `docs/spec/64-modularize-cli-review-scripts.md`: 정본 위치 표의 리뷰 루프 행, 5절(공용 모듈 `script/_review.py`)이 이 이슈 명세 4절을 가리키게,
  6절의 머리 주석 문장, 12-1 의 "계약·모듈 일치" · "내장 파이썬 없음" 행
- `docs/spec/60-automate-work-prerequisites.md`: 정본 위치 표의 착수 판정 · 리뷰 루프 행, 5-1 의 `_review.py plan-exe`
- `docs/spec/70-generate-permission-allow-list.md`: 3절의 모듈 스크립트 예시(`_review.py`)
- `docs/spec/71-issue-worktree-run.md`: 정본 위치 표의 리뷰 등록 · 집계 행, 7절 제목
- `docs/workflow/` 는 고치지 않는다
- 건드릴 파일: `README.md`, `docs/spec/64-modularize-cli-review-scripts.md` · `60-automate-work-prerequisites.md` · `70-generate-permission-allow-list.md` ·
  `71-issue-worktree-run.md`

### 완료 조건

- [ ] `README.md` "명령" 표에 세 명령의 행이 있고, 각 행이 종료 코드와 절차가 부르는 `script/<이름>.sh` 표기를 적는다. `review` · `sync-tasks` 행에 원격 쓰기가 적혀 있다
- [ ] 네 명세가 리뷰 루프 · 착수 판정의 현재 자리로 `script/_review.py` 나 셸 본문을 가리키지 않고, 하위 명령과 `src/harness/review.py` 를 가리킨다
- [ ] `docs/workflow/` 가 바뀌지 않는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/211-port-work-steps` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 명령 표의 세 행 | `README.md` "명령" 표 | `harness review` · `harness preflight` · `harness sync-tasks` 행이 있다 |
| UT-02 | 옛 모듈을 현재 자리로 가리키지 않는다 | 네 명세에서 `_review.py` 검색 | 리뷰 루프의 현재 정본 자리로 `_review.py` 를 적은 문장이 없다 |
| UT-03 | 사람용 절차 문서 | `git diff --stat docs/workflow/` | 변경 없음 |

## T6 · docs: 아키텍처·용어·범위 문서에 리뷰·착수 판정·동기화 하위 명령 반영

### 상위 Requirement

- relates to #211

### 작업 내용

에이전트가 근거로 읽는 보호 문서를 T2 ~ T4 가 만든 사실에 맞춘다. **이 수정은 2026-10-09 결정 게이트에서 사용자가 허용한 범위다** — 명세 7절
"보호 문서 개정 범위" 의 표를 그대로 적용하고 그 범위 밖은 고치지 않는다. 리뷰나 가드에서 보호 문서 수정으로 걸리면 사람이 대응한다.

- 명세 7절. 보호 문서 개정의 적용 순서는 #206 → #207 → #208 · #209 · #210 → #211 이다. 아래는 그 이슈들이 고친 문장 위에 더하고, 표에 없는 문장은
  앞 이슈가 고친 그대로 둔다
- `.ai/project/architecture.md`
  - "구성 요소" 의 CLI 항목: 명령에 리뷰(`review` · `review post`) · 착수 판정(`preflight`) · task 이슈 동기화(`sync-tasks`)가 있고, 리뷰 판정 데이터 · 집계 ·
    등록 댓글 렌더링 · 리뷰 입력 맥락은 `src/harness/review.py` 가 갖는다는 문장을 덧붙인다
  - "구성 요소" 의 대상 리포 `script/` 항목: 착수 판정 · task 이슈 동기화 · 리뷰 루프 스크립트가 하위 명령을 부르는 shim 이라는 것. "그 공용 모듈 `_review.py` — …" 를 지운다
  - "데이터 흐름" 의 절차 실행: 리뷰 루프 문장만 명세 7절의 문안으로 바꾼다
  - "새 코드를 둘 곳": "리뷰 루프의 파이썬 → `script/_review.py` …" 줄을 명세 7절의 문안으로 바꾼다
  - "계층과 의존 방향": 명세 7절의 문장을 덧붙인다
- `.ai/project/glossary.md` "용어": `task 이슈` · `착수 판정` · `회차 라벨` 행, 그리고 #207 이 고친 `실행 계획` 행의 `리뷰 루프` 를 "리뷰 루프(`harness review`, 같은 프로세스에서 계산)" 로
- `.ai/project/scope.md` "할 수 있는 일": 착수 판정 · task 이슈 동기화 · 리뷰의 새 줄(뒤의 둘은 원격에 쓴다)
- `.ai/project/testing.md` 는 고치지 않는다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 세 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/architecture.md` · `.ai/project/glossary.md` · `.ai/project/scope.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] `.ai/project/architecture.md` 가 명세 7절 표의 다섯 위치 문안을 담고, 현재 자리로 `script/_review.py` 를 가리키지 않는다
- [ ] `.ai/project/glossary.md` 의 `task 이슈` · `착수 판정` · `회차 라벨` · `실행 계획` 행이 명세 7절의 문안이다
- [ ] `.ai/project/scope.md` "할 수 있는 일" 에 세 명령의 줄이 있다
- [ ] `.ai/project/testing.md` 와 명세 7절 표 밖의 문장이 바뀌지 않는다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 가 세 문서와 일치하고 `harness check` 와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/211-port-work-steps` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성된 규칙 정본이 보호 문서와 일치한다 | 세 문서 수정 뒤 `harness check` | 어긋난 생성 파일 없음 |
| UT-02 | 옛 모듈을 현재 자리로 가리키지 않는다 | `.ai/project/architecture.md` · `.ai/AI_AGENT.md` 에서 `_review.py` 검색 | 없음 |
| UT-03 | 개정 범위 밖은 그대로다 | `git diff .ai/project/` | 명세 7절 표의 위치만 바뀌고 `testing.md` 변경 없음 |
