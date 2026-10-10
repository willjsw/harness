# 리뷰 루프 · 착수 판정 · task 동기화 하위 명령

리뷰 루프(`review-mr.sh` · `post-review.sh` · `_review.py`), 착수 판정(`work-preflight.sh`), task 이슈 동기화
(`sync-task-issues.sh`)의 로직은 하네스 패키지의 하위 명령 `harness review` · `harness preflight` · `harness sync-tasks`
가 갖는다. 인자 · 표준 출력 · 종료 코드는 이식 전과 같다. `script/` 의 같은 이름 스크립트는 하위 명령을 부르기만 하는
shim 이고, 에이전트 · 설정 · 사람은 지금 표기(`script/<이름>.sh`)로 부른다.

기준 코드는 #206 · #207 · #209 의 변경이 들어간 통합 브랜치다. 셋이 머지된 뒤에 착수한다.

| 따르는 것 | 정하는 이슈 |
|---|---|
| 패키지 배치(모듈 지도, 명령 이름의 `-` 를 모듈 파일 이름에 적는 규칙, 진입 스크립트, 고정 사본 `.harness/lib/harness/`, 바이트코드 캐시 위치), 명령 표의 통과 표시와 `--target` 규칙, 단위 테스트 자리와 `[verify]` 단계 | #206 |
| 공유 설정 · 실효 설정, 실행 계획 함수 `run_plan()` | #207 |
| forge 파이썬 어댑터와 셸 페이크 주입 지점 | #209 |
| 표지 모듈 `src/harness/format.py` — 하네스 루트의 `script/harness-format.sh` 를 실행하지 않고 파싱한다 | #209 · #210 가운데 먼저 머지된 쪽 |

정본 위치:

| 대상 | 정본 |
|---|---|
| 하위 명령 | `src/harness/commands/review.py` · `preflight.py` · `sync_tasks.py` |
| 리뷰 판정 데이터 · 집계 · 등록 댓글 렌더링 · 리뷰 입력 맥락 · 회차 라벨 · 반복 지적 이력 | `src/harness/review.py` |
| 이식하지 않은 관리 스크립트를 부르는 경계 (사용 기록 · 지표 기록 · 역할 실행기) | `src/harness/scripts.py` |
| 명령 표 `COMMANDS` | `src/harness/commands/__init__.py` |
| 고정 버전 위임 `DELEGATES` · 인자 해석 | `src/harness/cli.py` |
| shim | `src/templates/managed/script/review-mr.sh` · `post-review.sh` · `work-preflight.sh` · `sync-task-issues.sh` |
| 스크립트 목록 | `src/templates/managed/script/README.md` |
| 회귀 테스트 | `src/templates/managed/script/test-review-loop.sh` · `test-work-preflight.sh` · `test-sync-task-issues.sh` · `src/test/unit/` · `src/test/render-test.sh` |
| 사람용 설명 | `README.md` |

- 위 경로는 #206 의 모듈 지도 안의 자리다
- forge 는 #209 의 파이썬 어댑터로만 부른다
- 이 리포의 `script/` 아래 같은 이름의 파일은 거기서 설치된 사본이다

근거 결정: `docs/adr/0004-review-rounds-are-counted-by-one-script.md`(회차는 한 주체가 센다) ·
`0005-projects-pin-the-installed-harness.md` · `0013-the-source-repo-runs-itself-without-a-vendored-copy.md` ·
`0014-review-verdicts-are-structured-data.md`, 그리고 #206 의 결정 기록 "하네스 로직은 Python 표준 라이브러리 패키지
하나에 둔다". 이 변경은 새 결정 기록을 만들지 않는다.

## 1. 바뀌는 것과 바뀌지 않는 것

바뀌는 것:

- 로직이 있는 자리. 세 하위 명령이 로직을 갖고, 네 스크립트는 하위 명령을 부르기만 한다 (3절)
- `script/_review.py` 는 더 깔리지 않는다. 기존 설치본에서는 다음 `render` · `install` 이 지운다 (3-4)
- 표지는 환경 변수가 아니라 표지 모듈로 하네스 루트의 표지 파일에서 읽는다 (2-1-5)
- 리뷰 러너와 작성자표시는 같은 프로세스에서 계산한 실행 계획에서 받는다. `harness run-plan` 을 하위 프로세스로 부르지 않는다 (2-1-2)
- 예상하지 못한 실패는 종료 코드 2 로 끝난다 (2-1-3)

바뀌지 않는 것:

- 네 스크립트의 인자, 표준 출력, 종료 코드 (2-2 ~ 2-5, 3-2)
- 이식 전 스크립트가 내던 표준 오류 문구. 회귀 테스트가 대조하는 문구가 그 일부다
- 판정 순서. 리뷰 러너 점검이 forge 조회와 회차 라벨보다 앞이고, 회차 라벨 갱신이 리뷰 실행보다 앞이다
- 판정 데이터 계약 · 집계 · 등록 댓글(`docs/spec/64-modularize-cli-review-scripts.md` 2~4절), 리뷰 입력의 절 구성(같은 문서 1 · 5절),
  착수 판정의 이슈 확인(`docs/spec/60-automate-work-prerequisites.md` 4절), 회차 전 러너 점검(같은 문서 5절),
  반복 지적 이력의 자리와 형식(`docs/spec/71-issue-worktree-run.md` 7절)
- 부수 기록의 이름과 형식 (2-1-6)
- 에이전트 · 설정 · 권한이 쓰는 명령 표기 (3-3)
- 회차 라벨을 올리는 코드는 하나다 — `harness review`. shim 은 그것을 부르기만 한다

세 명령은 기계용 출력(`--json`)을 두지 않는다. 다음 단계는 종료 코드와 `preflight` 표준 출력의 첫 토큰으로 분기한다.

## 2. 하위 명령

### 2-1. 공통

#### 2-1-1. 명령 표

`COMMANDS`(`commands/__init__.py`)에 세 항목을 더한다. 셋 다 설정이 필요하고, 셋 다 통과 명령(#206 3-3)이며, 셋 다
`DELEGATES` 에 넣는다 — 프로젝트가 고정한 버전이 답한다.

| 이름 | 인수 | 설명 |
|---|---|---|
| `review` | `[--force] <number> \| post <number> - [label] [revision]` | `review a review request's diff, post the result and count the round (writes to the remote)` |
| `preflight` | `<issue>` | `decide whether work on an issue can start: prints plan or standalone` |
| `sync-tasks` | `<parent-issue> [--dry-run]` | `create the task issues of an approved breakdown that do not exist yet (writes to the remote)` |

#### 2-1-2. 하네스 루트와 설정 값

- 하네스 루트는 `--target`(기본 현재 디렉터리)이다 (2-1-3). 명령은 git, forge 어댑터, 역할 실행기, 사용 기록을 하네스 루트를
  작업 디렉터리로 해서 부른다. 자기 프로세스의 현재 디렉터리는 바꾸지 않는다
- 설정 값은 #207 의 공유 설정(내장 기본값 · preset · 프로젝트 레이어)에서 읽는다. `script/harness.env` 에 쓰이는 값과 같은 파생(`derive()`)이다
- 공유 설정이 없거나 검증에 실패하면 다른 명령과 같은 안내로 종료 코드 2 다
- 리뷰 러너와 그 작성자표시는 실행 계획에서 받는다. 실행 계획은 같은 프로세스에서 #207 의 `run_plan()` 으로 실효 설정(공유 설정 +
  개인 레이어)을 계산한 것이다. `harness run-plan` 을 하위 프로세스로 부르지 않고, 실행 계획 파일을 읽지 않는다

명령마다 읽는 설정:

| 명령 | 읽는 설정 |
|---|---|
| `preflight` · `sync-tasks` | 공유 설정. 개인 레이어 파일을 열지 않는다 — 그 파일이 깨져 있어도 돈다 |
| `review` | 공유 설정과 실행 계획. 실행 계획을 계산하지 못하면 회차를 쓰기 전에 멈춘다 (2-2 의 1단계) |
| `review post` | 공유 설정. 작성자표시를 주지 않았을 때만 실행 계획을 계산하고, 계산하지 못하면 기본값으로 등록을 계속한다 (2-3) |

| 값 | 출처 | 쓰는 명령 |
|---|---|---|
| 회차 상한 | `review.max_rounds` | `review` |
| 연속 상한 | `review.repeat_file_max` | `review` · `review post` |
| 회차 라벨 접두 | `review.round_label` | `review` |
| 리뷰 러너 | 실행 계획의 `roles.code-reviewer` — `exe` 가 있으면 CLI 러너다 | `review` |
| 리뷰 러너의 작성자표시 | 실행 계획의 `roles.code-reviewer.label` — 그 역할을 실행하는 벤더 선언의 `label`, 없으면 `name` | `review` 가 등록에 넘긴다. `review post` 의 기본값 |
| 통합 브랜치 | `branches.base` | `preflight` · `sync-tasks` |
| 이슈 참조 표기 | `commit.issue_ref` — `suffix` 면 `#{id}`, 아니면 `{id}` | `sync-tasks` |
| 필수 필드 | `issues.required_fields` | `sync-tasks` |
| task 라벨 | `issues.labels.task` | `sync-tasks` |

#### 2-1-3. 인자 규칙 · 종료 코드 · 출력 순서

- 세 명령은 통과 명령이다 — 호출 꼴은 `harness [--target DIR] <명령> <인자…>` 이고, 명령 이름 뒤의 인자는 전부 그 명령이 받는다.
  하네스 루트는 이름 앞의 전역 `--target DIR`, 또는 이름 바로 뒤에 한 번 오는 `--target DIR` 로 정한다. 규칙은 #206 3-3 의 통과 장치다
- 명령마다 받는 인자는 2-2 ~ 2-5 의 표가 정한다. 그 밖의 옵션은 거부한다. 다른 명령의 전역 옵션(`--json` · `--remote` · `--yes` ·
  `--staged` 등), 줄임 철자(`--forc` · `--dry` · `--targ`), 이름 바로 뒤가 아닌 자리의 `--target`, `-h` · `--help` 가 모두 해당한다.
  표준 오류에 `error: unknown option: <인자>` 와 사용법을 내고 종료 코드 2 다. `review post` 다음 자리는 옵션이 아니라 값이다 (2-3)
  - 세 명령의 종료 코드 0 에는 판정 뜻(PASS · 착수 가능 · 동기화 완료)이 있어서, 도움말 요청도 0 으로 끝내지 않는다.
    명령과 인수 목록은 `harness help` 가 보인다
- 사용법:

  ```
  usage: harness review [--force] <review-request-number>
         harness review post <review-request-number> - [author-label] [reviewed-revision]
  usage: harness preflight <issue-number>
  usage: harness sync-tasks <parent-issue-number> [--dry-run]
  ```

- 처리하지 않은 예외는 표준 오류에 트레이스백과 마지막 줄 `error: harness <명령> stopped on an unexpected error` 를 내고
  종료 코드 2 로 끝난다. `<명령>` 은 `review` · `review post` · `preflight` · `sync-tasks` 다. 2 는 어느 명령에서나 "판정하지 못했다" 다
- SIGINT · SIGTERM 으로 끝나면 임시 디렉터리와 동기화 잠금(2-5)을 지우고, `review` 는 사용 기록(2-1-6)을 남긴 뒤
  128 + 신호 번호로 끝난다
- 표준 출력은 줄마다 바로 내보낸다. 표준 출력과 표준 오류를 한 파일로 받아도 이식 전 스크립트와 같은 순서로 나온다

#### 2-1-4. forge

forge 는 #209 의 파이썬 어댑터로만 부른다. 부르는 계약 함수는 이식 전과 같다. 계약의 정본 위치와 파이썬 쪽 이름은 #209 가 정한다.

| 명령 | 계약 함수 |
|---|---|
| `review` | `review_require` · `review_mr_view` · `review_mr_diff` · `review_mr_labels_set` · `review_mr_threads` · `tracker_issue_view` |
| `review post` | `review_require` · `review_mr_note_inline` · `review_mr_note_summary` |
| `preflight` | `tracker_require` · `tracker_issue_view` · `review_require` · `harness_issue_open_mrs` |
| `sync-tasks` | `tracker_require` · `tracker_issue_view` · `tracker_issue_list` · `tracker_issue_create` |

- 테스트는 #209 가 정한 주입 지점(환경 변수)으로 셸 페이크를 끼운다. 명령이 하네스 루트에서 돌므로 페이크 함수도
  그 자리에서, 부른 쪽의 환경을 받아 불린다

#### 2-1-5. 표지와 이식하지 않은 관리 스크립트

표지는 표지 모듈 `src/harness/format.py` 로 읽는다. 사용 기록 · 지표 기록 · 역할 실행기는 이 변경에서 옮기지 않고, 하위 명령은
이것들을 `src/harness/scripts.py` 한 곳에서 부른다. 파이썬 쪽에 표지 값이나 그 스크립트 로직의 사본을 두지 않는다.

| 자산 | 하위 명령이 쓰는 방법 |
|---|---|
| 표지 `script/harness-format.sh` | 표지 모듈이 하네스 루트의 `script/harness-format.sh` 를 실행하지 않고 파싱해 돌려준 값을 쓴다. 필요한 표지를 읽지 못하면 표준 오류에 `error:` 와 표지 이름을 내고 종료 코드 2. 파싱 규칙은 표지 모듈이 정한다 |
| 사용 기록 `script/usage-log.sh` | 하네스 루트의 스크립트를 `<종류> <출처> <상세>` 인자로 부른다. 그 종료 코드는 판정에 닿지 않는다 |
| 지표 기록 `script/metric.py` | 2-1-6 의 감싸기 |
| 역할 실행기 `script/run-agent.py` | `code-reviewer --check`(러너 점검)와 `code-reviewer --out <파일> --prompt <프롬프트>`(리뷰어 실행)를 이식 전과 같은 인자 · 입출력으로 부른다. 역할 실행기는 실행 계획을 스스로 받는다(#207 7-3) |

#### 2-1-6. 부수 기록

이름과 형식을 바꾸지 않는다. 회고 집계(`script/usage-report.sh`)와 Metrics 탭이 이 이름으로 읽는다.

| 기록 | 내용 |
|---|---|
| 지표 스팬 | `review` · `preflight` · `sync-tasks` 실행 하나가 스팬 하나다. 이름은 차례로 `review-mr` · `work-preflight` · `sync-task-issues`, 종류 `script`, 속성 `script=<그 이름>`. `review post` 는 스팬을 따로 남기지 않는다 |
| 사용 기록 | `review` — 종류 `review`, 출처 `review-mr`, 상세 `mr=<번호> round=<회차> exit=<종료 코드>`. 종료 코드 3 이면 뒤에 `stop=mrl-cap`(회차 상한) 또는 `stop=repeat`(같은 파일 반복). `preflight` — 종류 `preflight`, 출처 `work-preflight`, 상세는 2-4 표의 라벨 하나. `review post` · `sync-tasks` 는 남기지 않는다 |
| 반복 지적 이력 | `<git 공통 디렉터리>/work-loop/review-findings-<번호>.tsv`, 첫 줄 `#format 1` |
| 동기화 잠금 | `<TMPDIR 또는 /tmp>/harness-sync-<cksum>-<상위이슈>` (2-5) |

스팬 감싸기:

- 명령은 자기 실행 전체를 `script/metric.py wrap --name <이름> --kind script --attr script=<이름> -- <자기 진입 스크립트> <같은 인자>`
  로 다시 실행해 감싼다. 감싼 실행의 환경에는 `HARNESS_METRIC_SELF=<이름>` 이 있다
- `HARNESS_METRIC_SELF` 가 이미 그 이름이거나 하네스 루트의 `script/metric.py` 가 실행 파일이 아니면 감싸지 않는다
- 지표 설정은 지표 기록기가 스스로 받는다(#207 7-3). 받지 못하면 스팬을 기록하지 않고 감싼 실행을 그대로 돌린다 — 출력과 종료 코드가 같다
- 감싸기는 명령 자신의 인자 검사보다 앞이다. 인자가 틀린 실행도 스팬 하나를 남긴다
- 그래서 역할 실행기가 남기는 리뷰어 스팬은 `review-mr` 스팬의 자식이고, 실패한 실행에는 `[metrics]` 의 `capture_logs` 대로
  표준 오류 끝부분이 남는다. 출력과 종료 코드는 감싸기와 무관하다

사용 기록을 남기는 때:

- `review` 는 인자 검사를 통과한 뒤 어느 경로로 끝나든 한 줄을 남긴다. 회차는 라벨 갱신에 성공하기 전에는 읽은 회차,
  성공한 뒤에는 올린 회차다
- `preflight` 는 2-4 표에 라벨이 적힌 경로에서만 남긴다

#### 2-1-7. 바이트코드

하위 명령은 하네스 루트와 `script/` 에 `__pycache__` 를 남기지 않는다. 캐시 자리는 #206 이 정한다.

### 2-2. `harness review [--force] <리뷰요청번호>`

리뷰 요청 하나의 diff 를 리뷰하고 결과를 등록한다. 실행마다 회차 라벨을 1 올리고 상한을 강제한다.

| 인자 | 규칙 |
|---|---|
| `--force` | 회차 상한을 넘겨 돈다. 몇 번이든, 어느 자리든 받는다 |
| `<리뷰요청번호>` | 숫자만. 하나만 받는다 |

- 번호가 없으면 사용법, 번호가 둘이면 `error: expected one number, got two: <앞>, <뒤>`, 숫자가 아니면
  `error: the number must be numeric, got '<값>'` 과 사용법 — 종료 코드 2. 이때는 사용 기록을 남기지 않는다
- 첫 위치 인자가 `post` 면 2-3 의 등록이다. `post` 와 `--force` 는 함께 받지 않는다. `post` 앞의 옵션은 2-1-3 을 따른다

표준 출력:

1. 회차 라벨을 올린 뒤 `review round <N> (<접두>:<N>, cap <상한>)`
2. 리뷰어 출력(판정 데이터 블록을 담은 것) 그대로
3. 등록의 표준 출력 (2-3)

종료 코드: 0 PASS · 1 CHANGES_REQUESTED · 2 실행 실패(리뷰 미수행 · 계약 위반 · 등록 실패) · 3 상한(회차 상한 또는 같은 파일 반복)

순서 — 앞 단계에서 멈추면 뒤 단계는 돌지 않는다. 문구는 이식 전 스크립트와 같다.

| 단계 | 멈추는 조건 | 종료 코드 |
|---|---|---|
| 1. 실행 계획 | 실효 설정으로 실행 계획을 계산하지 못함(개인 레이어 · 잠금 · 불변식 등 #207 7-1 의 오류). 그 오류 문구 뒤에 `help: the round was not used — fix the config, then rerun` | 2 |
| 2. 리뷰 러너 | 실행 계획에 `code-reviewer` 가 없거나(역할이 꺼짐) 그 `exe` 가 없거나 비었음 — `error: no review runner is configured` 와 서브에이전트 역할이라는 안내 | 2 |
| 3. 러너 점검 | `script/run-agent.py code-reviewer --check` 가 0 이 아님. 그 표준 오류 뒤에 `help: the round was not used — fix the review runner, then rerun`. 표준 출력은 버린다 | 2 |
| 4. 역할 계약 | `.ai/templates/code-reviewer.md` 가 없음 | 2 |
| 5. 리뷰 호스트 | `review_require` 실패 | 2 |
| 6. 리뷰 요청 조회 | `review_mr_view` 실패 | 2 |
| 7. 회차 읽기 | 라벨을 읽지 못함. 회차가 숫자가 아님 | 2 |
| 8. 회차 상한 | 읽은 회차 ≥ `review.max_rounds` 이고 `--force` 가 없음 | 3 (`stop=mrl-cap`) |
| 9. 리비전 일치 | 소스 브랜치를 모름 · 현재 브랜치와 다름 · 원격 head 를 모름 · 로컬 `HEAD` 와 다름 · 작업 트리가 깨끗하지 않음(추적하지 않는 파일 포함) | 2 |
| 10. diff | 조회 실패 · 빈 diff | 2 |
| 11. 회차 라벨 | `<접두>:<N+1>` 을 붙이고 다른 회차 라벨을 떼는 갱신이 실패 | 2 |
| 12. 맥락 | 스레드 조회 · 이슈 조회 · 맥락 구성이 실패하면 `warning:` 만 내고 그 절 없이 간다 | — |
| 13. 리뷰어 실행 | 실행 실패 · 빈 출력. 실행 기록의 끝 30줄을 함께 낸다 | 2 |
| 14. 등록 | 2-3 의 동작. 작성자표시는 1단계 실행 계획의 `code-reviewer.label`(2-1-2), 리뷰한 리비전은 9단계에서 원격 head 와 맞춰 본 `HEAD` | 등록의 종료 코드 |

- 회차는 `<접두>:<숫자>` 꼴 라벨의 숫자 가운데 가장 큰 값이다. 그런 라벨이 없으면 0
- 리뷰 입력(머리말 · 맥락 절 · 증분 diff · 누적 diff)의 구성, 증분 기준의 판정, 리뷰어 프롬프트, 리뷰 입력을 표준 입력으로
  넘기는 방식은 이식 전과 같다
- 리뷰에 쓴 임시 디렉터리는 끝날 때 지운다
- 같은 리뷰 요청을 동시에 두 번 돌리는 것은 지원하지 않는다 — 회차 읽기와 갱신 사이에 잠금이 없다

### 2-3. `harness review post <리뷰요청번호> - [작성자표시] [리뷰한리비전]`

리뷰어의 판정 데이터를 검증해 리뷰 요청에 등록하고 판정을 종료 코드로 돌려준다. 사용자가 지시해 루프 밖에서
등록하는 경로(`script/post-review.sh`, 3-2)와 `harness review` 의 14단계가 이 구현 하나를 쓴다.

| 인자 | 규칙 |
|---|---|
| `<리뷰요청번호>` | 형식을 검사하지 않는다 |
| `-` | 정확히 `-`. 리뷰어 출력은 표준 입력으로 받는다 |
| `[작성자표시]` | 없거나 빈 문자열이면 실행 계획의 `code-reviewer.label`(2-1-2). 실행 계획을 계산하지 못하거나 거기 `code-reviewer` 가 없으면 `자동 리뷰` 이고, 등록은 계속한다 |
| `[리뷰한리비전]` | 비어 있지 않으면 `^[0-9a-f]{7,40}$` 꼴이어야 한다. 없거나 빈 문자열이면 하네스 루트의 `HEAD` |

- `post` 다음 인자는 전부 값이다. `-` 로 시작해도 옵션으로 읽지 않는다 — 작성자표시는 자유 문자열이다
- 값이 2개보다 적거나 4개보다 많거나, 둘째가 `-` 가 아니면 사용법과 종료 코드 2
- 리뷰어 출력은 파일 경로로 받지 않는다. 파일로 가진 쪽은 shim 이 표준 입력으로 넘긴다 (3-2)

순서:

| 단계 | 멈추는 조건 | 종료 코드 |
|---|---|---|
| 1. 리뷰 호스트 | `review_require` 실패 | 2 |
| 2. 본문 | 표준 입력이 비었음 — `error: the review body is empty` | 2 |
| 3. 리비전 형식 | `error: the reviewed revision is not a SHA, got '<값>'` 과 `help: nothing was posted — a wrong baseline would misalign the next round incremental diff` | 2 |
| 4. 이력 자리 | 하네스 루트가 git 작업 트리 밖 | 2 |
| 5. 검증 · 집계 | 64 2-3 의 계약 위반 — 표준 오류 첫 줄 `contract violation: …`, 둘째 줄 `help: nothing was posted — the raw review follows`, 그 뒤에 표준 입력으로 받은 원문을 바이트 그대로. 검증 · 집계가 다른 까닭으로 실패해도 `help:` 줄과 원문을 낸다. 어느 쪽이든 아무것도 등록하지 않는다 | 2 |
| 6. 인라인 | 등록에 실패한 인라인은 `warning:` 을 내고 요약 본문에 남는다 | — |
| 7. 요약 | 렌더 실패. 등록 실패 — 요약 본문을 표준 오류에 낸다 | 2 |
| 8. 이력 누적 | 요약 등록에 성공한 회차만 누적한다 | — |
| 9. 판정 | 한 파일에 blocker · major 가 `review.repeat_file_max` 회차 연속 — `stop:` 줄, 회차와 키 목록, `help:` | 3 |
| | blocker · major 0 건 | 0 |
| | 그 밖 | 1 |

표준 출력: 요약을 등록한 뒤 한 줄.

```
posted to <번호>: <n> inline, 1 summary · blocker <n> · major <n> · minor <n> -> <PASS|CHANGES_REQUESTED>
```

### 2-4. `harness preflight <이슈번호>`

이슈 하나에 대해 구현 착수가 가능한지 판정하고, 가능하면 경로를 낸다.

- 인자는 값 하나. 형식을 검사하지 않는다 — 이슈 식별자의 꼴은 트래커가 정한다. 개수가 다르거나 `-` 로 시작하는 인자는
  사용법과 종료 코드 2
- 표준 출력: `plan` 또는 `standalone` 한 줄. 착수 불가와 실행 실패에서는 아무것도 내지 않는다
- 종료 코드: 0 착수 가능 · 1 착수 불가 · 2 실행 실패

순서:

| 단계 | 조건 | 표준 오류 | 사용 기록 | 종료 코드 |
|---|---|---|---|---|
| 1. git | 하네스 루트가 git 작업 트리 밖 | `stop: not inside a git repository` | — | 2 |
| 2. 트래커 | `tracker_require` 실패 | 어댑터의 안내 | — | 2 |
| 3. 이슈 | 60 4-1 표 그대로 — 조회 실패 · 상태를 읽지 못함은 2, 닫힘은 1, 열림은 다음 단계 | 60 4-1 표 | `issue-query-failed` · `issue-closed` | 2 · 1 |
| 4. 열린 리뷰 요청 | `review_require` 실패 | 어댑터의 안내 | `mr-query-failed` | 2 |
| | `harness_issue_open_mrs` 실패 | `stop: could not query the review requests linked to issue <이슈>` | `mr-query-failed` | 2 |
| | 결과가 있음 (공백만이면 없음) | `stop: issue <이슈> already has an open review request (<결과>)` 와 `  it is either a spec+plan awaiting approval or an implementation already in flight` | `open-mr` | 1 |
| 5. fetch | `git fetch -q origin <통합 브랜치>` 실패 | `stop: git fetch failed — refusing to decide from a stale ref` | `fetch-failed` | 2 |
| 6. 분해 | `FETCH_HEAD` 에 `<접두>docs/plan/<이슈>/task.md` 가 없음 | — (표준 출력 `standalone`) | `standalone` | 0 |
| 7. 명세 | `FETCH_HEAD` 의 `<접두>docs/spec/` 에 이름이 `<이슈>-` 로 시작하는 파일이 없음 | `stop: docs/plan/<이슈>/ has a breakdown but no matching spec at docs/spec/<이슈>-*.md` 와 `help: the completion criteria point at nothing — run prework to settle the spec first` | `spec-missing` | 1 |
| 8. 판정 | 그 밖 | — (표준 출력 `plan`) | `plan` | 0 |

- `<접두>` 는 하네스 루트에서 `git rev-parse --show-prefix` 를 돌린 출력이다. 모노레포 서브프로젝트에서도 git 객체 경로를
  리포 루트 기준으로 맞춘다
- 절차가 착수 전과 구현 위임 직전에 같은 명령을 돌리는 것은 그대로다

### 2-5. `harness sync-tasks <상위이슈번호> [--dry-run]`

원격 통합 브랜치에 있는 `docs/plan/<상위이슈>/task.md` 의 task 절을 이슈 트래커와 맞춘다. 같은 제목의 이슈가 있으면
건너뛰고 없는 것만 만든다. 두 번 돌려도 중복이 생기지 않는다.

- 인자는 `<상위이슈>` 하나, 또는 `<상위이슈> --dry-run`. `--dry-run` 은 둘째 자리에서만 받는다. 첫 인자는 `-` 로 시작하지만 않으면
  형식을 검사하지 않는다
- 개수가 다르거나 첫 인자가 `-` 로 시작하면 사용법, 둘째가 정확히 `--dry-run` 이 아니면 `error: unknown option: <둘째>` 와
  사용법 — 종료 코드 2. `--dry-run <상위이슈>` 순서는 둘째가 `--dry-run` 이 아닌 경우다

표준 출력 — task 절 순서대로 한 줄씩:

```
T<N> <참조>  skip(<상태>)
T<N> <참조>  created
T<N> (dry-run) create  <제목>
```

`<참조>` 는 이슈 참조 표기의 `{id}` 를 그 이슈 번호로 바꾼 것이다. 구현자는 이 매핑으로 커밋 메시지의 이슈 번호를 정한다.

종료 코드: 0 동기화 완료 · 2 실행 실패. 1 은 쓰지 않는다.

순서 — 멈추면 전부 종료 코드 2 다.

| 단계 | 멈추는 조건 |
|---|---|
| 1. 트래커 | `tracker_require` 실패 |
| 2. 잠금 | 잠금 디렉터리를 만들지 못함(까닭과 무관). `stop: another sync is already running for issue <상위이슈>`, `  lock: <경로>`, 주인 기록이 있으면 두 칸 들여 쓴 그 내용, `help:` 두 줄 |
| 3. git | 하네스 루트가 git 작업 트리 밖 |
| 4. fetch | `git fetch -q origin <통합 브랜치>` 실패 |
| 5. 분해 | `FETCH_HEAD:<접두>docs/plan/<상위이슈>/task.md` 가 없음 — 승인되어 머지된 분해로만 이슈가 생긴다 |
| 6. 조회 | 상위 이슈 조회 실패 · 이슈 목록 조회 실패 |
| 7. 계획 | 상위 이슈의 필수 필드가 비었음 · task 절이 없음 · 같은 제목의 이슈가 목록에 둘 이상 · 조회 응답을 JSON 으로 읽지 못함. 계획을 세우면 표준 오류에 `breakdown tasks: <n>  ·  to create: <m>` |
| 8. 재조회 | 만들 것이 있고 `--dry-run` 이 아니면 목록을 다시 읽는다. 읽지 못하거나 계획 뒤에 같은 제목이 생겼으면 하나도 만들지 않는다 |
| 9. 생성 | 절 순서대로 만든다. 생성이 실패하거나 새 번호를 읽지 못하면 그 자리에서 멈춘다 — 앞에서 만든 이슈는 남는다 |

계획 규칙:

- task 절은 표지 `FMT_TASK_HEADING` 으로 줄 단위로 가른다
- 이슈 제목은 `<절 제목>(<상위이슈 참조>)`, 본문은 절 내용의 앞뒤 공백을 뺀 것
- 기존 이슈는 목록 항목 가운데 제목(앞뒤 공백 제외)이 같은 것이다
- 생성 인자는 제목, 본문, task 라벨, 상위 이슈의 `assignee` · `milestone` 이다

잠금:

- 경로는 `TMPDIR` 값(비었거나 없으면 `/tmp`) 뒤에 `/harness-sync-<cksum>-<상위이슈>` 를 그대로 이어 붙인 문자열이다.
  `<cksum>` 은 하네스 루트(`--target` 을 심볼릭 링크까지 푼 절대 경로)를 개행 없이 넣었을 때 POSIX `cksum` 이 내는 CRC 값(10진)이다
- 잠금은 디렉터리 하나를 원자적으로 만드는 것이다. 안에 `owner` 파일을 둔다 — `pid: <pid>` · `host: <호스트 이름>` ·
  `started: <YYYY-MM-DD HH:MM:SS, 지역 시각>` 세 줄
- 어느 경로로 끝나든(신호 포함, 2-1-3) 잠금을 지운다
- 잠금은 같은 기계 안에서만 막는다. 다른 기계 · CI 와의 경합은 8단계가 잡는다

## 3. shim — `script/*.sh`

### 3-1. 배치와 형태

| 스크립트 | 하는 일 |
|---|---|
| `review-mr.sh` | `harness review` 에 받은 인자를 그대로 넘긴다 |
| `post-review.sh` | 3-2 |
| `work-preflight.sh` | `harness preflight` 에 받은 인자를 그대로 넘긴다 |
| `sync-task-issues.sh` | `harness sync-tasks` 에 받은 인자를 그대로 넘긴다 |

형태와 문구는 모든 하네스 shim 이 같다(#209 · #210 · #213 의 shim 과 같은 공통 형태).

1. 자기 파일이 있는 디렉터리의 부모를 하네스 루트로 잡는다
2. `<루트>/.harness/bin/harness`, `<루트>/src/bin/harness` 순으로 실행 가능한 첫 것을 CLI 로 고른다
3. `<CLI> --target <루트> <명령> <받은 인자 그대로>` 로 `exec` 한다

- 현재 디렉터리 · 표준 입출력 · 환경을 바꾸지 않는다. 종료 코드는 CLI 의 것이다
- CLI 를 찾지 못하면 표준 오류에 아래 두 줄을 내고 종료 코드 2 로 끝난다

  ```
  error: harness CLI not found under <루트> (.harness/bin/harness or src/bin/harness)
  help: harness install --target <루트>
  ```

- PATH 의 전역 `harness` 는 부르지 않는다. 프로젝트가 고정한 버전이 돈다
- shim 에는 값 · 표지 · 판정이 없다. `script/harness.env` · `script/harness-format.sh` · `script/forge.sh` 를 source 하지 않는다.
  지표 감싸기와 사용 기록은 하위 명령이 한다 — shim 은 한 번 더 감싸지 않는다
- 첫 줄은 `#!/usr/bin/env sh` 이고 `bash <파일>` 로도 돈다. 실행 권한은 지금과 같다
- 머리 주석에는 부르는 명령의 이름, 로직은 패키지에 있다는 것, 인자 · 종료 코드 계약을 적는다

### 3-2. `post-review.sh <리뷰요청번호> <본문파일> [작성자표시] [리뷰한리비전]`

- 인자가 2개보다 적으면 `usage: script/post-review.sh <review-request-number> <review-body-file> [author-label] [reviewed-revision]`
  과 종료 코드 2
- 본문 파일의 상대 경로는 하네스 루트 기준이다 — 이식 전과 같다. 절대 경로도 받는다
- 본문 파일이 없거나 비었으면 `error: the review body is empty: <본문파일>` 과 종료 코드 2. CLI 를 찾지 않는다
- 그 밖에는 3-1 의 순서로 CLI 를 고르고, 본문 파일을 표준 입력으로 해서 `<CLI> --target <루트> review post <번호> - [작성자표시] [리뷰한리비전]`
  을 `exec` 한다. 셋째 · 넷째 인자는 받은 만큼 그대로 넘기고, 다섯째부터는 넘기지 않는다. 작성자표시의 기본값은 `review post` 가 정한다 (2-3)
- 이 진입점을 부르는 곳(`code-reviewer` · `security-guard` 어댑터의 사용자 지시 등록, `/security-guard` 커맨드, `security-guard`
  역할 계약)의 표기는 그대로다

### 3-3. 바뀌지 않는 표기

에이전트 · 설정 · 권한이 보는 명령은 `script/<이름>.sh` 그대로다. 아래는 이 변경에서 고치지 않는다.

- 절차 조각(work · prework · retro)의 스크립트 표기
- 역할 어댑터 선언 `entry: script/review-mr.sh` 와, 그 값을 쓰는 `validate_workflows()` 의 안내 · `harness schema` 의 `script_roles`
- 역할 계약(developer · planner · code-reviewer · security-guard)의 스크립트 표기
- 기본 설정과 이 리포 설정의 단계 `run` 값 — `script/sync-task-issues.sh <Requirement 이슈번호>` · `script/review-mr.sh <MR번호>`
- 권한 허용 목록. `script/` 바로 아래 관리 스크립트의 규칙이 그대로 나오고, 하위 명령의 규칙은 더하지 않는다
- `.ai/AI_AGENT.md` · `CLAUDE.md` 원형의 스크립트 표기

### 3-4. `check-open-mrs.sh` 와 `_review.py`

- `check-open-mrs.sh` 는 고치지 않는다. `script/forge.sh`(#209 의 shim)의 `harness_issue_open_mrs` 를 부르는 독립 진입점으로 남는다.
  `harness preflight` 는 이 스크립트를 부르지 않고 같은 계약 함수를 어댑터로 부른다
- `src/templates/managed/script/_review.py` 를 지운다. 기존 설치본의 `script/_review.py` 는 관리 매니페스트(`.harness/managed`)에
  있으므로 다음 `render` · `install` 이 지운다. 이 리포의 사본도 그렇게 지운다

### 3-5. shim 이 지키는 호출과 걷는 시점

- shim 이 지키는 호출은 셋이다 — 프로젝트 소유 `harness.toml` 의 단계 `run` 값, 에이전트가 읽는 절차 · 역할 문서, 사람의 호출
- 이 리포가 이 변경의 리뷰 요청을 리뷰할 때도 리뷰는 그 브랜치의 구현으로 돈다. `harness review` 는 현재 브랜치가 소스 브랜치이고
  `HEAD` 가 원격 head 와 같고 작업 트리가 깨끗할 때만 리뷰한다(2-2 의 9단계). 구현이 깨져 있으면 종료 코드 2 로 멈추고
  리뷰 요청은 열린 채 사람에게 간다. 그 앞에서 pre-push 의 회귀 테스트가 먼저 막는다
- shim 과 `check-open-mrs.sh` 를 걷고 에이전트가 보는 표기를 바꾸는 일은 main 릴리스를 한 번 거친 뒤 #221 이 한다

## 4. 패키지 안의 배치

| 모듈 | 갖는 것 |
|---|---|
| `commands/review.py` | `review` · `review post` 의 인자 처리, 2-2 · 2-3 의 순서, forge · 역할 실행기 호출, 출력 |
| `commands/preflight.py` | 2-4 |
| `commands/sync_tasks.py` | 2-5 — 잠금 · 계획 · 재조회 · 생성 |
| `review.py` | 판정 데이터 스키마(키 이름 · 허용 값)를 한 곳에 정의하고 검증 · 집계 · 렌더링이 함께 쓴다. 인라인 발견 접두를 만드는 코드와 알아보는 코드, 리뷰 입력 맥락(절 추출 · 인용), 회차 계산, 반복 지적 이력 읽기 · 쓰기 |
| `scripts.py` | 2-1-5 의 경계 — 사용 기록 · 역할 실행기 호출, 지표 감싸기 |

- `commands/` 의 파일 이름에 명령 이름의 `-` 를 적는 방법은 #206 의 모듈 지도 규칙을 따른다
- 명령 모듈은 표지를 표지 모듈 `format.py` 에서, 실행 계획을 #207 의 `run_plan()` 에서 받는다. 둘 다 이 변경이 두지 않는 공용 코드다
- 각 명령은 결과(판정 · 건수 · 회차 · 매핑)를 값으로 만든 뒤 그 값을 텍스트로 출력한다
- `review.py` 는 forge 와 하위 프로세스를 부르지 않는다. forge 응답과 설정 값은 인자로 받는다

## 5. 회귀 테스트

### 5-1. 오라클

- 판정 기준은 세 sh 테스트(`test-review-loop.sh` · `test-work-preflight.sh` · `test-sync-task-issues.sh`)의 검사 줄 기대값이다 —
  종료 코드, 표준 출력, 표준 오류 문구, 페이크 호출 기록, 라벨, 이력 파일, 사용 기록, 지표. 이식 뒤에도 같은 기대값으로 통과한다
- 바꿀 수 있는 줄은 준비부(샌드박스 배치 · 페이크 주입 · 설정 덮기)와 옛 모듈의 내부 구조를 직접 보는 줄뿐이다 (5-2)
- 세 sh 테스트는 대상 리포의 계약 테스트로 남는다. 설치된 리포(CLI `.harness/bin/harness`)와 소스 리포(CLI `src/bin/harness`)
  양쪽에서 돈다
- 리뷰 요청 본문에 바꾼 줄마다 바꾸기 전 줄과 바꾼 까닭을 잇는 대응표를 단다

### 5-2. 기존 sh 테스트에서 바꾸는 줄

세 테스트의 준비부:

| 무엇 | 어떻게 |
|---|---|
| CLI | 테스트는 자기 하네스 루트에서 `.harness/bin/harness` → `src/bin/harness` 순서로 CLI 를 찾는다(없으면 종료 코드 2). 샌드박스 하네스 루트에 그 CLI 의 고정 사본을 복사해 둔다 — #206 2-1 의 배치에서 그 CLI 의 진입 스크립트 · 패키지 · 템플릿을 `.harness/bin/harness` · `.harness/lib/harness/` · `.harness/templates/` 로. 진입 스크립트는 자기 실제 경로에서 패키지와 템플릿을 찾으므로 심볼릭 링크로는 샌드박스의 템플릿을 쓰지 않는다. 실행 계획을 흉내 내는 페이크 CLI 는 두지 않는다 — 실행 계획은 샌드박스의 CLI 가 계산한다 |
| 설정 | 샌드박스 하네스 루트에 자기 하네스 루트의 `harness.toml` 사본을 둔다. `test-review-loop.sh` 가 고정하는 상한(`cap` · `repeat`)은 그 사본의 `review.max_rounds` · `review.repeat_file_max` 로, 지표 경로는 `metrics.dir` 로 샌드박스 안을 가리키게 덮는다. 개인 레이어 파일은 케이스가 둘 때만 있다. `script/harness.env` 사본은 사용 기록 스크립트를 위해 그대로 둔다 |
| forge 페이크 | 페이크 파일을 #209 의 주입 환경 변수로 가리킨다. 페이크의 함수와 그것이 남기는 호출 기록은 그대로다 |
| git 상태 | 샌드박스에 더한 파일은 첫 커밋에 넣는다 — `harness review` 는 작업 트리가 깨끗할 때만 돈다 |
| 배치 목록 | 새 구현이 쓰지 않는 파일(`_review.py` · `check-open-mrs.sh`)을 복사 목록과 필수 파일 확인에서 뺀다 |

테스트별:

| 테스트 | 줄 | 처리 |
|---|---|---|
| `test-review-loop.sh` | 이력 형식 판별자(`#format N`)를 `_review.py` 에서 읽는 줄 | 같은 값을 패키지의 `review.py`(`.harness/lib/harness/` → `src/harness/` 순서)에서 읽는다 |
| | 스텁으로 갈아끼울 리뷰 러너 실행 파일을 읽는 줄 | 샌드박스 하네스 루트에서 CLI 의 `run-plan` 출력의 `roles.code-reviewer.exe` 를 읽는다 |
| | 리뷰 러너 상황(로그인 확인 · 설치되지 않은 러너 · 서브에이전트 역할)을 만드는 줄 | 샌드박스 고정 사본의 벤더 선언 사본(`.harness/templates/vendors.toml`)과 샌드박스 설정으로 만든다 — 로그인 확인은 리뷰 러너 벤더의 `auth_check` 를 스텁이 알아보는 인자로, 설치되지 않은 러너는 그 벤더의 `exe` 를 고친다. 서브에이전트 역할은 샌드박스 설정의 `roles.code-reviewer.runner = "inproc"` 와 `invariants.distinct_reviewer = false` 로 만든다. 기대값은 그대로다 |
| | 실행 계획을 받지 못하는 상황을 만드는 줄 | 샌드박스에 성립하지 않는 `harness.local.toml`(받지 않는 키)을 둔다. 기대값(종료 코드 2 · 회차 라벨 그대로 · `help: the round was not used — fix the config, then rerun`)은 그대로다 |
| | 등록의 작성자표시를 보는 줄 | 기대 label 은 벤더 선언 사본에서 리뷰 러너 벤더의 `label` 이다 |
| | UT-21 — 모듈의 스키마 키 · 표지가 두 역할 계약에 있다, 읽은 뒤 바이트코드가 없다 | 단위 테스트로 옮긴다 (5-4) |
| | UT-24 — 리뷰 스크립트에 내장 파이썬이 없다 | 그대로 둔다. shim 에 대해 참이다 |
| | UT-26 — 회차는 회차 라벨의 최댓값 | 단위 테스트로 옮긴다 |
| | UT-27 — 표지가 환경에 없으면 모듈이 2 | 단위 테스트로 옮기고 "표지 파일에 없으면 2" 로 바꾼다 |
| | UT-28 — `script/__pycache__` 가 없다 | 그대로 둔다 |
| | UT-31 — 하위 하네스 루트(`script/` 복사) | 설정 사본과 고정 사본도 함께 둔다 |
| | UT-32 · UT-33 — 페이크 자신의 계약 | 그대로 둔다. 페이크 파일을 직접 source 한다 |
| `test-work-preflight.sh` | 준비부만 바꾼다 | |
| `test-sync-task-issues.sh` | `lock_path` — 잠금 경로를 다시 계산하는 도우미 | 하네스 루트를 심볼릭 링크까지 푼 경로(`pwd -P`)로 계산한다 (2-5 잠금) |
| | UT-07 의 직접 호출 두 곳 | 주입 환경 변수를 함께 넘긴다 |

### 5-3. sh 테스트에 더하는 케이스

| 테스트 | 케이스 |
|---|---|
| `test-review-loop.sh` | `review-mr.sh` 에 `--json` · `--forc` · `-h` 를 각각 주면 종료 코드 2, 회차 라벨 그대로, 리뷰어 호출 0, forge 호출 0 |
| | `post-review.sh` 에 없는 본문 파일을 주면 종료 코드 2, 표준 오류에 `error: the review body is empty`, 등록 호출 0 |
| | 하네스 루트가 아닌 디렉터리에서 하네스 루트 기준 상대 경로의 본문 파일로 `post-review.sh` 를 부르면 등록된다 |
| | `post-review.sh` 에 작성자표시를 주지 않으면 요약에 벤더 선언 사본의 리뷰 러너 `label` 이 붙는다. 성립하지 않는 `harness.local.toml` 을 두면 `자동 리뷰` 가 붙고 종료 코드는 판정대로다 |
| | 샌드박스에서 고정 사본을 치우면 `review-mr.sh` 가 종료 코드 2 이고 표준 오류에 `error: harness CLI not found under` 와 `help: harness install --target` |
| `test-work-preflight.sh` | `100 --json` 과 `--help` 는 종료 코드 2 이고 이슈 조회 0 |
| `test-sync-task-issues.sh` | `100 --dry` 와 `--dry-run 100` 은 종료 코드 2, 목록 조회 0, 생성 호출 0 |

### 5-4. 단위 테스트 — `src/test/unit/`

#206 이 둔 자리와 `[verify]` 의 Python 단위 테스트 단계를 쓴다. 대상 리포로 가지 않는다.

| 케이스 | 확인하는 것 |
|---|---|
| 스키마와 역할 계약 | `review.py` 의 최상위 키 · 발견 키 · 심각도와 표지 `FMT_REVIEW_BLOCK` · `FMT_VERDICT_PASS` · `FMT_VERDICT_CHANGES` 가 `src/templates/managed/.ai/templates/code-reviewer.md` · `security-guard.md` 에 백틱으로 둘러싸여 있다. 두 계약에 `## 발견 사항` · `REVIEW_VERDICT` 규칙이 없다 (UT-21 에서 옮김) |
| 회차 | 라벨 `<접두>:1` · `other` · `<접두>:3` · `<접두>:x` 에서 회차 3, 회차 라벨 `<접두>:1 <접두>:3`. 회차 라벨이 없으면 0 (UT-26 에서 옮김) |
| 표지 | 하네스 루트의 표지 파일에서 필요한 표지를 읽지 못하면 종료 코드 2 (UT-27 에서 옮김) |
| 인자 규칙 | 세 명령과 `review post` 가 2-1-3 · 2-2 ~ 2-5 의 인자는 받고 그 밖은 거부한다. `--target DIR` 은 이름 바로 뒤에서 한 번 받고 다른 자리면 거부한다. 거부는 종료 코드 2 이고 forge 를 부르지 않는다 |
| 실행 계획 | 실행 계획을 계산하지 못하면 `review` 가 forge 를 부르기 전에 종료 코드 2 이고 `help: the round was not used — fix the config, then rerun` 을 낸다. 같은 공유 설정에 개인 레이어의 리뷰어 러너만 바꾸면 `review` 가 등록에 넘기는 작성자표시가 그 벤더의 `label` 이다. `review post` 는 작성자표시가 없으면 실행 계획의 `label`, 계산하지 못하면 `자동 리뷰` 를 쓴다 |
| 예외 | 명령 본문에서 처리하지 않은 예외가 나면 종료 코드 2 이고 표준 오류 마지막 줄이 `error: harness <명령> stopped on an unexpected error` |
| 잠금 경로 | 여러 경로에서 `<cksum>` 이 POSIX `cksum` 명령의 출력과 같다. `TMPDIR` 이 `/` 로 끝나도 그대로 이어 붙인 문자열이다 |
| 신호 | 신호 처리를 부르면 잠금 · 임시 디렉터리를 지우고 128 + 신호 번호로 끝난다 |
| 명령 표 | `review` · `preflight` · `sync-tasks` 가 `COMMANDS` 에 통과 표시와 함께 있고 `DELEGATES` 에 있다 |

### 5-5. `src/test/render-test.sh`

| 케이스 | 확인하는 것 |
|---|---|
| 옛 모듈 정리 | 설치한 리포에 `script/_review.py` 와 그 매니페스트 줄을 두고(옛 설치본) `render` 하면 그 파일이 없어지고 매니페스트에서 빠진다 |
| 허용 목록의 모듈 스크립트 | `_` 로 시작하는 모듈 스크립트가 허용 목록에 없다는 검사의 대상을 깔리는 모듈(`script/_clone_key.py` — #96 이 더한다)로 바꾸고, 그 파일이 설치돼 있는지 먼저 본다 |
| 도움말 | `harness help` 가 `review` · `preflight` · `sync-tasks` 를 보이고 `review` · `sync-tasks` 줄에 `writes to the remote` 가 있다 |
| UT-99 | 페이크를 #209 의 주입 지점으로 끼운다. 기대값은 그대로다 |
| 설치본의 관리 테스트 | 설치한 리포와 모노레포 서브프로젝트에서 세 sh 테스트가 통과한다 — 설치된 테스트를 세어 전부 돌리는 기존 블록이 본다 |

### 5-6. 순서

- 옛 구현에서도 성립하는 준비부 변경(고정 사본 · 설정 사본 · 주입 환경 변수 · 첫 커밋 · 벤더 선언 사본과 샌드박스 설정으로 만드는
  리뷰 러너 상황)은 이식보다 먼저 하고 옛 구현에서 통과하는 것을 확인한다
- 새 구현에서만 성립하는 줄(배치 목록에서 옛 파일 빼기, 구조 검사 이동, 잠금 경로 계산)은 옛 모듈을 걷는 변경과 함께 바꾼다
- 회귀 테스트 전체(`script/run-lint-test.sh`)가 통과한다

## 6. 문서

| 문서 | 바뀌는 것 |
|---|---|
| `src/templates/managed/script/README.md` | `review-mr.sh` · `post-review.sh` · `work-preflight.sh` · `sync-task-issues.sh` 행의 용도에 "`harness <명령>` 을 부르는 shim" 을 적는다. 종료 코드 설명은 그대로다. `_review.py` 행을 지운다. `check-open-mrs.sh` 행의 호출 시점은 "수동 — 착수 판정은 같은 조회를 `harness preflight` 안에서 한다". "규칙" 절에 "하위 명령은 설정을 직접 읽고, 표지를 표지 모듈로 읽는다" 를 더한다 |
| `src/templates/managed/script/harness-format.sh` | 절 머리 주석의 `_review.py` 를 `src/harness/review.py` 로 |
| `README.md` "명령" 표 | 아래 세 행을 더한다 |
| `docs/spec/64-modularize-cli-review-scripts.md` | 정본 위치 표의 리뷰 루프 행, 5절(공용 모듈 `script/_review.py`)이 이 명세 4절을 가리키게, 6절의 머리 주석 문장, 12-1 의 "계약·모듈 일치" · "내장 파이썬 없음" 행 |
| `docs/spec/60-automate-work-prerequisites.md` | 정본 위치 표의 착수 판정 · 리뷰 루프 행, 5-1 의 `_review.py plan-exe` |
| `docs/spec/70-generate-permission-allow-list.md` | 3절의 모듈 스크립트 예시(`_review.py`) |
| `docs/spec/71-issue-worktree-run.md` | 정본 위치 표의 리뷰 등록 · 집계 행, 7절 제목 |

`docs/workflow/` 는 고치지 않는다. 스크립트 표기로 절차를 설명하고, 그 표기는 그대로다.

README 명령 표에 더하는 행:

| 명령 | 하는 일 |
|---|---|
| `harness review [--force] <번호>` · `harness review post <번호> - [표시] [리비전]` | 리뷰 요청의 diff 를 리뷰하고 결과를 등록한다. 실행마다 회차 라벨을 올리고 상한을 강제한다. 0=PASS · 1=수정 필요 · 2=실패 · 3=상한. `post` 는 표준 입력의 판정 데이터를 등록만 한다. **원격 쓰기**. 절차와 에이전트는 `script/review-mr.sh` · `script/post-review.sh` 로 부른다 |
| `harness preflight <이슈>` | 착수 판정 — `plan` · `standalone` 을 낸다. 0=가능 · 1=불가 · 2=실패. 절차는 `script/work-preflight.sh` 로 부른다 |
| `harness sync-tasks <상위이슈> [--dry-run]` | 승인된 분해의 task 이슈 가운데 없는 것만 만든다. 0=완료 · 2=실패. **원격 쓰기**. 절차는 `script/sync-task-issues.sh` 로 부른다 |

## 7. 보호 문서 개정 범위

이 이슈의 사용자 결정으로 허용된 범위다. 분해의 task 하나가 구현과 함께 고치고, 고친 뒤 `harness render` 로 `.ai/AI_AGENT.md` 를
다시 만든다. 보호 문서 개정의 적용 순서는 #206 → #207 → #208 · #209 · #210 → #211 이다. 아래 문안은 그 이슈들이 고친 문장 위에
더하며, 표에 적지 않은 문장은 앞 이슈가 고친 그대로 둔다. 용어 `shim` 의 행은 #209 가 용어집에 둔다.

| 문서 · 위치 | 문안 |
|---|---|
| `.ai/project/architecture.md` "구성 요소" 의 CLI 항목 | 덧붙인다: 명령에 리뷰(`review` — 실행 계획 계산 · 리뷰 러너 점검 · diff 조회 · 회차 라벨 · 리뷰어 실행 · 판정 데이터 검증 · 등록. `review post` — 등록만), 착수 판정(`preflight`), task 이슈 동기화(`sync-tasks`)가 있다. 리뷰 판정 데이터 · 집계 · 등록 댓글 렌더링 · 리뷰 입력 맥락은 리뷰 모듈(`src/harness/review.py`)이 갖는다 |
| 같은 문서 "구성 요소" 의 대상 리포 `script/` 항목 | 착수 판정(`work-preflight.sh`) · task 이슈 동기화(`sync-task-issues.sh`) · 리뷰 루프(`review-mr.sh` · `post-review.sh`)는 같은 일을 하는 하위 명령을 부르는 shim 이다. "그 공용 모듈 `_review.py` — …" 를 지운다 |
| 같은 문서 "데이터 흐름" 의 절차 실행 | #207 · #208 이 고친 항목에서 리뷰 루프 문장만 이것으로 바꾼다 — 리뷰 루프는 `harness preflight`(shim `script/work-preflight.sh` — 이슈 확인 · 착수 판정) → 구현자 → `harness review`(shim `script/review-mr.sh` — 실효 설정으로 실행 계획 계산 · 리뷰 러너 점검 · diff 조회 · 회차 라벨 · 리뷰어 실행) → 리뷰어의 판정 데이터(JSON 블록) → 등록(`harness review post` 와 같은 구현 — 스키마 검증 · 등급 집계 · 반복 지적 누적 · 요약 · 인라인 댓글 렌더링) → 종료 코드로 분기 |
| 같은 문서 "새 코드를 둘 곳" | "리뷰 루프의 파이썬 → `script/_review.py` …" 줄을 이것으로 바꾼다 — 리뷰 루프의 판정 · 렌더링 · 맥락 → `src/harness/review.py`. 리뷰 · 착수 판정 · task 동기화의 순서와 forge 호출 → 각 명령 모듈. 이식하지 않은 관리 스크립트를 부르는 코드 → `src/harness/scripts.py` 한 곳. `script/` 의 shim 에는 로직을 넣지 않는다 |
| 같은 문서 "계층과 의존 방향" | 덧붙인다: 하위 명령은 설정 값을 공유 설정에서, 역할의 실행 방법을 실행 계획 함수에서 같은 프로세스 안에 받는다 — `script/harness.env` 와 `harness run-plan` 을 거치지 않는다. 표지는 표지 모듈(`src/harness/format.py`)로만 읽는다. 이식하지 않은 관리 스크립트(사용 기록 · 지표 기록 · 역할 실행기)는 `src/harness/scripts.py` 로만 부른다 |
| `.ai/project/glossary.md` "용어" 의 `task 이슈` | 승인된 분해에서 `harness sync-tasks`(shim `script/sync-task-issues.sh`)가 만드는 하위 이슈. 커밋의 단위 |
| 같은 표의 `착수 판정` | `harness preflight`(shim `script/work-preflight.sh`)가 원격 기준으로 내리는 판정 — `plan` · `standalone` · 착수 불가 |
| 같은 표의 `회차 라벨` | 리뷰 요청에 붙는 `<prefix>:<N>` 라벨. `harness review`(shim `script/review-mr.sh`)만 올린다 |
| 같은 표의 `실행 계획`(#207 이 고친 행) | "역할 실행기 · 리뷰 루프 · 지표 기록기가 읽는다" 의 `리뷰 루프` 를 "리뷰 루프(`harness review`, 같은 프로세스에서 계산)" 로 |
| `.ai/project/scope.md` "할 수 있는 일" | 새 줄 — 이슈의 착수를 판정하고(`preflight`), 승인된 분해로 task 이슈를 만들고(`sync-tasks`), 리뷰 요청을 리뷰해 회차를 세고 결과를 등록한다(`review`). 뒤의 둘은 원격에 쓴다 |

`.ai/project/testing.md` 는 고치지 않는다. 관리 스크립트마다 `script/test-<이름>.sh` 를 갖는다는 서술은 그대로 참이고,
단위 테스트의 자리는 #206 이 더한다.

## 8. 다른 이슈와의 경계

| 이슈 | 그 이슈가 정하는 것 | 이 명세와 닿는 곳 |
|---|---|---|
| #206 | 패키지 모듈 지도와 파일 이름 규칙, 진입 스크립트, 고정 사본 `.harness/lib/harness/`, 바이트코드 캐시 자리, `COMMANDS`(`commands/__init__.py`) · `DELEGATES`(`cli.py`) 의 자리, 통과 명령 표시와 `--target` 규칙(3-3), 단위 테스트 자리와 `[verify]` 단계 | 4절의 모듈이 그 지도 안에 놓인다. 2-1-1 · 2-1-3, 5-2 의 패키지 위치와 고정 사본 배치, 5-4 |
| #207 | 공유 설정 · 실효 설정, 실행 계획 함수 `run_plan()`, 역할 실행기 · 지표 기록기가 실행 계획을 받는 방법. 이 명세보다 먼저 머지된다 | 2-1-2 의 설정과 실행 계획, 2-2 의 1 · 2 · 14단계, 2-3 의 작성자표시 기본값, 5-2 의 리뷰 러너 상황 |
| #209 | forge 파이썬 어댑터(계약 함수의 파이썬 이름), `script/forge.sh` shim, 셸 페이크 주입 환경 변수, 용어 `shim` 의 행 | 2-1-4, 3-4 의 `check-open-mrs.sh`, 5-2 |
| #209 · #210 | 표지 모듈 `src/harness/format.py` — 먼저 머지된 쪽이 둔다 | 2-1-5 |
| #208 · #212 | 블록 엔진과 driver 절차 | script 블록은 이 명령들의 종료 코드와 `preflight` 표준 출력 첫 토큰으로 분기한다. 기계용 출력은 그것을 쓰는 쪽이 생기는 이슈가 더한다 |
| #213 | 사용 기록 · 지표 기록 · 역할 실행기의 이식, 표지 정본을 `format.py` 로 옮기는 일 | `src/harness/scripts.py` 를 이식된 모듈로 바꾼다. 5-5 의 모듈 스크립트 검사 대상(`_clone_key.py`)도 그때 다시 정한다 |
| #215 | 반복 지적 이력의 리뷰 요청 이전, 착수 잠금 | 2-1-6 의 이력 파일과 2-4 의 순서를 바꾼다 |
| #221 (main 릴리스 한 번 뒤) | shim · `check-open-mrs.sh` 를 걷고, 에이전트가 보는 표기를 하네스 루트 종류별 CLI 경로로 바꾼다. sh 테스트의 거취 | 3-3 · 3-5 |

## 9. 한계

- 같은 리뷰 요청에 `harness review` 를 동시에 두 번 돌리면 둘 다 같은 회차를 읽어 상한을 한 번 넘길 수 있다
- 반복 지적 이력은 클론 하나의 git 공통 디렉터리에 있다. 다른 기기 · 새 클론에서 이어 돌리면 0 부터 센다 — 주 상한은 원격의 회차 라벨이다
- 동기화 잠금은 같은 기계 안에서만 막는다. 같은 리포의 다른 클론끼리는 하네스 루트 경로가 달라 서로를 막지 않는다
- shim 은 하네스 루트에 CLI 가 있어야 돈다. 고정 사본이 없는 대상 리포에서는 종료 코드 2 로 멈춘다
