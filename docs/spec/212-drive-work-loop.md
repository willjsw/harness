# work 를 driver 절차로 — 리뷰 루프는 하위 절차 `review-loop`

기본 절차 `work` 는 하네스가 단계를 직접 도는 driver 절차다. `harness run work <이슈>` 하나로 착수 판정부터
구현·리뷰 루프·마무리까지 돌고, 리뷰 루프는 재사용하는 하위 절차 `review-loop` 로 떨어져 있다. 오케스트레이터가
절차 문서를 읽고 판단하던 지점(착수 전 확인, 재판정, 코드가 바뀌지 않은 재시도, 마무리 뒤 확인)은 배선과
판정 단계가 맡는다. 구현자는 단계마다 구조화 출력(`developer-result`)을 내고, outcome 은 그 자기 보고가 아니라
판정 명령(`harness work-check`)이 git·forge 관측으로 정한다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 기본 절차 `work` · `review-loop` 의 정의 | 내장 기본값 파일 (#207 이 둔 `src/templates/defaults.toml`) |
| 단계 본문 조각 | `src/templates/workflows/work/` · `src/templates/workflows/review-loop/` |
| 구현자 결과 스키마 `developer-result` | 하네스 동봉 스키마 (#208 이 정한 자리 `src/harness/schemas/`) |
| 판정 명령 `harness work-check` | `src/harness/` 의 명령 모듈 하나 (#206 의 `commands/` 배치). shim 은 `src/templates/managed/script/work-check.sh` |
| 처리 노트 표지 `FMT_HANDLED_HEADING` | `src/templates/managed/script/harness-format.sh` |
| 구현자 계약 | `src/templates/managed/.ai/templates/developer.md` |
| doctor 항목 · `harness fix legacy-work` | CLI (`src/harness/`) |
| UI doctor 문구 · 조치 고르기 | `src/ui/lib/doctor.js` |
| 사람용 설명 | `README.md` · `src/templates/managed/docs/workflow/` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/test/unit/` · `src/ui/lib/doctor.test.js` |

이 리포의 `script/` · `.ai/templates/` · `docs/workflow/` 아래 같은 이름의 파일은 거기서 설치된 사본이다.

### 선행 이슈가 정하는 것

| 무엇 | 정하는 이슈 |
|---|---|
| 단계 스키마(`execute` · `type = "workflow"` · `next` · `on` · `schema` · `set`), 끝 상태 `done` · `stop` · `handoff`, `"*"` 배선, 설정 표기 | #208 |
| 템플릿 이름 `{issue}` · `{<set 변수>}` · `{steps.<id>.out.<최상위 키>}` — `run` 을 인자로 나눈 뒤 원소 안에서 치환하고 셸을 거치지 않는다. 하위 절차는 상위 변수를 읽기만 한다 | #208 |
| script 블록의 outcome(종료 코드, `on = "stdout"` 이면 stdout 의 첫 토큰), agent 블록의 구조화 출력 검증과 검증 실패 outcome `failed`, 스키마 자리와 문법(stdlib 부분집합) | #208 |
| inproc 역할을 오케스트레이터 벤더의 헤드리스로 띄우는 것, 실행 시점의 러너·권한 해석 | #208 (#207 의 실행 시점 해석 위에서) |
| 실행 상태와 재개, 재개 때 중단된 단계를 처음부터 다시 도는 규칙, 방문·단계 상한 | #208 |
| driver 단계 스팬, driver 절차 문서(그래프와 단계별 다음 표), driver 절차의 슬래시 커맨드 제외(관리 커맨드 포함) | #208 |
| 리뷰 · 착수 판정 · task 동기화 하위 명령과 `script/*.sh` shim, 하위 명령의 인자 거부 규칙 | #211 |
| forge 접근(파이썬 어댑터)과 테스트용 페이크 주입 지점 | #209 |
| 내장 기본값 레이어와 프로젝트 시드 | #207 |
| 패키지 배치(`src/harness/`) | #206 |

## 1. 바뀌는 것과 바뀌지 않는 것

바뀌지 않는 것:

- 리뷰 명령의 회차·상한·판정·등록과 종료 코드 0 · 1 · 2 · 3 (ADR 0004 · 0014). 리뷰 수단은 그 명령 하나다
- 착수 판정 · task 동기화 명령의 인자 · stdout · 종료 코드
- 구현과 리뷰의 러너 분리 (ADR 0003)
- 구현자의 브랜치 · 커밋 · 리뷰 요청 규칙. 이슈 하나가 브랜치 하나 · 리뷰 요청 하나다
- 절차는 리뷰 요청과 이슈를 닫지 않는다. 머지는 사람이 한다
- `prework` · `retro` 는 agent 절차다

바뀌는 것:

- 내장 기본값의 `work` 가 driver 절차이고, 리뷰 루프는 하위 절차 `review-loop` 다 (2절)
- 진입은 `harness run work <이슈>` 다. `/work` 슬래시 커맨드는 `work` 가 agent 절차일 때만 깔린다 (10절)
- 구현자는 모드(구현 · 재시도 · 마무리)로 불리고 `developer-result` 를 낸다. 계속할 수 없으면 되묻지 않고
  `escalate` 로 돌아온다 (3 · 4절)
- 판정 명령 `harness work-check` 가 작업 트리 확인과 구현 · 수정 · 마무리 뒤 판정을 한다 (5절)
- 리뷰 본문은 단계 사이로 넘기지 않는다. 구현자가 리뷰 요청에서 읽는다
- driver 절차에는 절차 문서를 읽고 따르는 오케스트레이터가 없다. 절차 메모(`.ai/project/workflows/work.md`)는
  문서에만 붙고, 구현자에게 줄 프로젝트 지시는 역할 메모(`.ai/project/roles/developer.md`)가 역할 어댑터에 붙어 전한다
- 단계 지표의 키가 바뀐다 (9절)
- 설치 때 기본 설정 전체를 복사받은 기존 설치본은 `[workflows.work]` 가 이전 기본값으로 남아 있어 그대로 agent
  절차로 돈다. doctor 가 짚고 `harness fix legacy-work` 가 옮긴다 (10절)

## 2. 기본 절차

### 2-1. `work`

`execute = "driver"`. 단계는 이 순서이고 첫 단계에서 시작한다.

| id | type | 제목 | 실행 · 역할 | on | set | next |
|---|---|---|---|---|---|---|
| `clean` | script | 작업 트리 확인 | `script/work-check.sh clean` | `stdout` | | `clean` → `preflight` · `*` → stop |
| `preflight` | script | 착수 판정 | `script/work-preflight.sh {issue}` | `stdout` | | `plan` → `task-sync` · `standalone` → `develop` · `*` → stop |
| `task-sync` | script | task 이슈 동기화 | `script/sync-task-issues.sh {issue}` | | | `0` → `recheck` · `*` → stop |
| `recheck` | script | 착수 재판정 | `script/work-preflight.sh {issue}` | `stdout` | | `plan` → `develop` · `*` → stop |
| `develop` | agent | 구현 | `developer`, 스키마 `developer-result` | `status` | `mr` ← `mr` | `failed` → stop · `*` → `develop-check` |
| `develop-check` | script | 구현 판정 | `script/work-check.sh develop {issue} {mr} {steps.develop.out.status} {steps.develop.out.reason}` | `stdout` | | `committed` → `loop` · `*` → stop |
| `loop` | workflow | 리뷰 루프 | 하위 절차 `review-loop` | | | `done` → `finalize` · `stop` → stop · `handoff` → handoff |
| `finalize` | agent | 마무리 | `developer`, 스키마 `developer-result` | `status` | | `failed` → handoff · `*` → `finalize-check` |
| `finalize-check` | script | 마무리 확인 | `script/work-check.sh finalize {issue} {mr} {steps.finalize.out.status} {steps.finalize.out.reason} {steps.finalize.out.handled}` | `stdout` | | `*` → done |

- 착수 재판정은 분해 경로에만 있다. task 동기화가 원격 조회와 이슈 생성을 하는 사이 원격이 바뀔 수 있다.
  단독 경로는 판정 직후 구현자에게 간다
- 구현 단계가 리뷰 요청 번호 없이 끝나면 구현 판정은 `committed` 를 내지 않는다. 그 실행의 끝은 `stop` 이다
- 마무리는 리뷰 루프가 `done` 으로 끝날 때마다 돈다. 처리할 발견이 없으면 구현자가 곧바로 돌아온다

### 2-2. `review-loop`

`execute = "driver"`. `work` 의 하위 절차다. 상위의 `{issue}` · `{mr}` 를 읽는다.

| id | type | 제목 | 실행 · 역할 | on | next |
|---|---|---|---|---|---|
| `review` | script | 리뷰 | `script/review-mr.sh {mr}` | | `0` → done · `1` → `fix` · `3` → handoff · `*` → stop |
| `fix` | agent | 수정 | `developer`, 스키마 `developer-result` | `status` | `failed` → handoff · `*` → `fix-check` |
| `fix-check` | script | 수정 판정 | `script/work-check.sh fix {issue} {mr} {steps.fix.out.status} {steps.fix.out.reason} {steps.fix.out.handled}` | `stdout` | `committed` → `review` · `no_change` → handoff · `escalate` → handoff · `verify_failed` → stop · `*` → stop |

- 리뷰 종료 코드 2 와 0 ~ 3 밖의 코드는 `*` 로 stop 에 간다. 종료 코드 2 는 PASS 가 아니다
- 회차를 세고 상한에서 멈추는 것은 리뷰 명령이다. 배선은 리뷰 명령을 거치지 않는 리뷰 경로를 두지 않는다 —
  `fix-check` 가 `committed` 를 낸 뒤에만 다시 리뷰로 간다
- `review-loop` 는 단독으로 돌지 않는다. `{mr}` 을 주는 상위가 없으면 `harness run review-loop <이슈>` 를 #208 의 참조 검증이 거부한다

### 2-3. 명령 표기

- 기본 절차의 `run` 은 `script/<이름>.sh` 표기를 쓴다. 착수 판정 · task 동기화 · 리뷰는 #211 의 shim 을 거쳐 하위 명령으로 간다
- `script/work-check.sh` 는 #211 의 shim 과 같은 방식으로 CLI 위치를 찾아 `harness work-check` 에 인자를 그대로 넘기는 shim 이다
- shim 과 이 표기를 걷는 일은 main 릴리스 한 번 뒤의 shim 정리 Requirement 가 한다. 그 대상에 `script/work-check.sh` 가 든다

### 2-4. 단계 본문 조각

새 단계의 조각은 아래에 둔다. agent 단계의 조각은 구현자에게 넘기는 입력이기도 하다 — 모드와 입력값을 첫머리에 적고
`{issue}` · `{mr}` 자리표시를 쓴다. 자리표시는 render 의 `{{VAR}}` 치환과 겹치지 않는다.

| 조각 | 담는 것 |
|---|---|
| `work/clean.md` | 미커밋 변경이 있으면 아무것도 만들지 않고 멈춘다. git 이 무시하는 파일은 세지 않는다 |
| `work/preflight.md` | `plan` 이면 task 동기화로, `standalone` 이면 구현으로 간다. 착수 불가(1) · 실행 실패(2)면 멈추고 사유는 명령이 stderr 로 낸다 |
| `work/task-sync.md` | 원격 통합 브랜치의 분해로 없는 task 이슈만 만든다. 경합이면 아무것도 만들지 않고 멈춘다. 손으로 이슈를 만들어 우회하지 않는다 |
| `work/recheck.md` | 동기화 뒤 착수 판정을 다시 돌린다. `plan` 이 아니면 멈춘다 |
| `work/develop.md` | 구현 모드. 대상 이슈 `{issue}`. 분해가 있으면 task↔이슈 매핑을 `script/sync-task-issues.sh {issue} --dry-run` 출력에서 읽는다. 끝나면 `developer-result` 를 낸다 |
| `work/develop-check.md` | 구현 판정의 순서(5-3)와 각 outcome 의 행선 |
| `work/loop.md` | 하위 절차 `review-loop` 를 부른다. 그 끝 상태가 이 단계의 outcome 이다 |
| `work/finalize.md` | 마무리 모드. 이슈 `{issue}`, 리뷰 요청 `{mr}`. 판정은 PASS 다. 코드를 고치지 않는다. 처리가 리뷰 요청에 없는 발견마다 처리를 남기고 그 자리를 `handled` 로 낸다 |
| `work/finalize-check.md` | 마무리 확인(5-5). 무엇이 나와도 끝은 done 이고, 확인하지 못한 것은 남은 것으로 보고된다 |
| `review-loop/_head.md` | 하위 절차 머리 — `work` 가 부르고 단독으로 돌지 않는다. 입력은 상위의 `{issue}` · `{mr}`. 회차와 상한은 리뷰 명령이 센다 |
| `review-loop/review.md` | 리뷰 명령이 하는 일, 종료 코드 표, 판정은 발견 등급 집계라는 것, 리뷰 수단은 이 명령 하나라는 것 |
| `review-loop/fix.md` | 재시도 모드. 이슈 `{issue}`, 리뷰 요청 `{mr}`. 리뷰 본문은 리뷰 요청의 가장 최근 자동 리뷰 요약과 그 회차 스레드에서 읽는다(`review_mr_threads {mr}`) |
| `review-loop/fix-check.md` | 수정 판정의 순서(5-4) — 검증 실패를 먼저 보고, 그다음 커밋 유무. 코드가 바뀌지 않았으면 재리뷰하지 않고 넘긴다 |

`work/_head.md` · `work/_tail.md` 는 옛 agent 절(10절)과 새 기본값이 함께 쓴다. 두 실행 방식 모두에서 참인 서술만 둔다.
다른 단계를 `{{step:<id>}}` 로 가리키지 않는다 — 두 절차의 단계 id 가 다르다.

| 조각 | 담는 것 |
|---|---|
| `work/_head.md` | 진입 `harness run work <이슈번호>`, 입력, 분해 유무로 갈리는 경로, 착수 판정(검사 순서와 그 이유), 착수 전 확인 넷(이슈 · 미커밋 변경 · 착수 판정 · 단독 경로의 완료 조건) — 하나라도 걸리면 아무것도 만들지 않고 멈춘다, 구현과 리뷰를 다른 도구가 맡는다는 것 |
| `work/_tail.md` | 결과 — 6절의 판정 표와 결과가 담는 것(브랜치 · task 이슈 매핑 · 리뷰 요청 · 리뷰 회차 · 최종 판정 · 남은 것). 하지 않는 것 — 지금 목록 그대로 |

## 3. 구현자 결과 — `developer-result`

구현자가 구현 · 재시도 · 마무리 모드에서 마지막에 내는 구조화 출력이다. 블록 표기와 검증은 #208 의 agent 블록
공통 규칙을 따르고, 검증에 실패하면 그 단계의 outcome 은 `failed` 다.

| 키 | 값 | 뜻 |
|---|---|---|
| `status` | `committed` · `no_change` · `verify_failed` · `escalate` 중 하나 | 이번 호출의 결과(자기 보고) |
| `mr` | 문자열 | 다룬 리뷰 요청 번호. 구현 모드에서 리뷰 요청을 올리지 못했으면 빈 문자열 |
| `reason` | 비지 않은 한 줄 문자열 | `committed` · `no_change` 면 한 일, `verify_failed` · `escalate` 면 멈춘 사유 |
| `handled` | 배열. 빈 배열 허용 | 고치지 않고 넘긴 발견의 처리 자리. 구현 모드는 빈 배열 |

`handled` 의 원소:

| 키 | 값 | 뜻 |
|---|---|---|
| `finding` | 비지 않은 문자열 | 어느 발견인지 — `<파일 경로> — <요지>`. 파일을 지목하지 않은 발견은 `(파일 미지정) — <요지>` |
| `where` | `reply` · `note` | 처리를 남긴 자리 |
| `thread` | 문자열 | `reply` 면 답글을 단 스레드의 `id`(`review_mr_threads` 출력의 값), `note` 면 빈 문자열 |
| `issue` | 문자열 | 이월 이슈 번호. 없으면 빈 문자열 |

- 키는 모두 필수다
- `status` 의 뜻

| 값 | 뜻 |
|---|---|
| `committed` | 이번 호출에서 커밋을 남기고 push 했다. 구현 모드면 리뷰 요청을 올렸다 |
| `no_change` | 커밋을 남기지 않았다 — 고칠 것이 없었다(재시도에서 전부 이월 · 반증, 마무리 모드의 보통 값) |
| `verify_failed` | 검증이 실패했거나 push 가 막혀 커밋 · push 를 끝내지 못했다 |
| `escalate` | 계속하지 않고 사람에게 넘긴다. 사유는 `reason` |

- 스키마 파일은 하네스 동봉 스키마 `developer-result` 하나다. 문법은 #208 의 stdlib 부분집합이고, 이 스키마는
  `type` · `properties` · `required` · `enum` · `items` · `minLength` 를 쓴다

## 4. 구현자 계약 — `developer.md`

계약은 두 실행 방식(driver 와 옛 agent 절)에서 같다. 바뀌는 절과 내용:

### 4-1. 입력

- 이슈 번호와 **모드**(구현 · 재시도 · 마무리). 모드는 부르는 쪽이 알린다
- 재시도 · 마무리는 리뷰 요청 번호를 받는다. 없으면 손대지 않고 `escalate` 로 돌아온다. 사유에 무엇이 없는지 적는다
- 리뷰 본문은 넘겨받지 않으면 리뷰 요청에서 읽는다. `review_mr_threads <리뷰 요청>` 출력에서 본문이 자동 리뷰 요약
  제목(`FMT_SUMMARY_HEADING`)으로 시작하는 가장 늦은 노트가 이번 회차 요약이고, 그 앞 요약 뒤에 달린 인라인 스레드가
  이번 회차 발견이다
- task↔이슈 매핑은 넘겨받지 않으면 `script/sync-task-issues.sh <이슈> --dry-run` 출력에서 읽는다. 분해가 있는데 매핑을
  얻지 못하면 `escalate`
- "받지 못했으면 손대기 전에 요구한다" 는 "손대기 전에 `escalate` 로 돌아온다" 로 바뀐다

### 4-2. 모든 모드

- 착수 전 작업 트리에 미커밋 변경이 있으면 손대지 않고 `escalate`. 그 변경이 이 이슈의 것인지 구현자가 가를 수 없다
- 도구 · 환경 변수가 없어 검증이 서지 않고 갖출 수 없으면 고치지 않고 `escalate`. 코드 실패가 아니다

### 4-3. 구현 모드

- 분해가 없는데 이슈 본문에 완료 조건이 없으면 착수하지 않고 `escalate`
- 이 이슈의 작업 브랜치(`<태그>/<이슈번호>-*`)가 로컬에 하나 있으면 그 브랜치에서 이어 한다. 이미 커밋된 작업은 다시
  하지 않는다. 둘 이상이면 `escalate`
- 그 밖의 절차(브랜치 · 구현 · 검증 · 커밋 · push · 리뷰 요청 하나)는 지금 그대로다

### 4-4. 재시도 모드

- 수정이 새 파일 · 스크립트를 만들거나 리뷰 요청에 없던 파일을 건드려야 하면 고치지 않고 `escalate`(범위 확대)
- 같은 지적이 반복되는데 코드로 덮을 수 없으면 고치지 않고 `escalate`. 사유에 명세 단계로 되돌릴 근거를 적는다
- blocker 가 설계와 상충하는 인터페이스 변경을 지적했으면 고치지 않고 `escalate`. 코드 수정으로 덮을 문제가 아니다
- 고치지 않고 넘긴 지적은 "고치지 않고 넘기는 지적" 절대로 처리를 남기고 그 자리를 `handled` 에 적는다

### 4-5. 마무리 모드 (새 절)

- 코드를 고치지 않는다. 커밋하지 않는다
- 이번 회차(PASS 회차) 발견 가운데 처리가 리뷰 요청에 아직 없는 것마다 "고치지 않고 넘기는 지적" 절대로 처리를 남긴다.
  minor 는 인라인 스레드가 없으므로 새 리뷰 요청 노트다
- 고쳐야 한다고 판단되는 발견은 고치지 않고 `escalate` 의 사유로 낸다
- 처리할 것이 없으면 아무것도 남기지 않고 `no_change` 로 곧바로 돌아온다
- 남긴 자리를 모두 `handled` 에 적는다

### 4-6. 고치지 않고 넘기는 지적

- 새 리뷰 요청 노트의 첫 줄은 처리 노트 표지 `FMT_HANDLED_HEADING` 의 값(`## 구현자 처리`)이다. 판정 명령이 이 표지로 노트를 찾는다
- `script/harness-format.sh` 에 `FMT_HANDLED_HEADING='## 구현자 처리'` 를 더하고, 머리글의 "함께 고칠 문서" 목록에
  `.ai/templates/developer.md` 를 더한다

### 4-7. 출력

- 지금의 출력 항목(브랜치 · 커밋 목록 · 리뷰 요청 · 검증 결과 · 완료 조건 대비 현황 · 넘긴 지적의 처리 · 커밋이 없을 때의 사유)에
  더해 마지막에 `developer-result` 를 낸다
- 재시도 절의 "회차와 상한을 세지 않는다" · "스레드를 직접 resolve 하지 않는다" 는 그대로다

## 5. 판정 명령 — `harness work-check`

```
script/work-check.sh clean
script/work-check.sh develop  <이슈> <리뷰요청> <status> <reason>
script/work-check.sh fix      <이슈> <리뷰요청> <status> <reason> <handled>
script/work-check.sh finalize <이슈> <리뷰요청> <status> <reason> <handled>
```

- 판정했으면 stdout 에 outcome 토큰 한 줄을 내고 종료 코드 0. 판정하지 못했으면 stdout 을 비우고 종료 코드 2
- 동작 이름이 없거나 모르는 것, 인자 개수가 틀린 것, 이 명령의 것이 아닌 플래그는 종료 코드 2 (#211 의 하위 명령과 같은 거부 규칙)
- `COMMANDS` 와 `DELEGATES` 에 넣는다 — 고정된 버전이 답한다. 도움말: `work-check: judge a step of the work workflow (its steps call it)`
- 사람이 읽는 줄은 stderr 에 영어로 낸다. 구현자 출력에서 온 문자열(`reason` · `finding`)은 제어 문자를 지우고 한 줄로 바꿔 옮긴다
- forge 는 #209 의 어댑터 함수로만 부른다. 표지는 #211 의 하위 명령과 같은 방식으로 `script/harness-format.sh` 에서 읽는다

### 5-1. 공통 관측

| 이름 | 값 |
|---|---|
| 미커밋 변경 | 하네스 루트에서 `git status --porcelain` 이 비어 있지 않다. git 이 무시하는 파일은 들지 않는다 |
| 로컬 HEAD · 현재 브랜치 | `git rev-parse HEAD` · `git rev-parse --abbrev-ref HEAD` |
| 리뷰 요청 | `review_mr_view <리뷰요청>` 의 상태 · 소스 브랜치 · head |
| 이슈의 열린 리뷰 요청 | `harness_issue_open_mrs <이슈>` — 착수 판정이 보는 것과 같은 목록 |
| 기준 요약 | `review_mr_threads <리뷰요청>` 의 노트 가운데 본문이 `FMT_SUMMARY_HEADING` 으로 시작하고 `FMT_REVIEWED_HEAD` 줄이 있는 것 중 가장 늦은 것. 리뷰 맥락 조회와 같은 함수로 찾는다 |
| 기준 리비전 | 기준 요약의 `FMT_REVIEWED_HEAD` 값 — 리뷰 명령이 원격 head 와 로컬 HEAD 가 같음을 확인하고 리뷰한 리비전이다 |

### 5-2. `clean`

| 조건 | stdout |
|---|---|
| 미커밋 변경이 있다 | `dirty` — stderr 에 `stop: the work tree has uncommitted changes — nothing was started`, `git status --short` 줄들, `help: commit or discard them, then rerun` |
| 없다 | `clean` |

git 을 실행하지 못하면 종료 코드 2.

### 5-3. `develop`

위에서부터 처음 맞는 줄이 outcome 이다.

| 순서 | 조건 | stdout |
|---|---|---|
| 1 | 미커밋 변경이 있다 | `verify_failed` |
| 2 | `status` 가 `verify_failed` | `verify_failed` |
| 3 | `status` 가 `escalate` | `escalate` |
| 4 | 리뷰 요청 인자가 숫자가 아니다 · 리뷰 요청이 열려 있지 않다 · 소스 브랜치가 현재 브랜치가 아니다 · 이슈의 열린 리뷰 요청 목록에 없다 | `no_mr` |
| 5 | 리뷰 요청 head 가 로컬 HEAD 가 아니다 | `verify_failed` — push 되지 않았다 |
| 6 | 그 밖 | `committed` — stderr 에 `develop: branch <브랜치>, review request <번호>` |

- 관측이 자기 보고에 앞선다. `status` 가 `no_change` 여도 4 · 5 를 지나면 `committed` 다
- 리뷰 요청 조회가 실패하면 종료 코드 2

### 5-4. `fix`

| 순서 | 조건 | stdout |
|---|---|---|
| 1 | 미커밋 변경이 있다 | `verify_failed` |
| 2 | `status` 가 `verify_failed` | `verify_failed` |
| 3 | 리뷰 요청이 열려 있지 않거나 소스 브랜치가 현재 브랜치가 아니다 | 종료 코드 2 |
| 4 | 리뷰 요청 head 가 로컬 HEAD 가 아니다 | `verify_failed` — push 되지 않았다 |
| 5 | 기준 요약이 없다 | 종료 코드 2 |
| 6 | (처리 대조 — 5-6. outcome 에 닿지 않는다) | |
| 7 | `status` 가 `escalate` | `escalate` |
| 8 | 리뷰 요청 head 가 기준 리비전과 같다 | `no_change` — stderr 에 `stop: no commit since the reviewed head <12자> — not reviewing again` |
| 9 | 그 밖 | `committed` |

- 검증 실패를 커밋 유무보다 먼저 본다. 검증 실패로 커밋하지 못한 것도 head 는 그대로라 순서가 바뀌면 검증 실패가
  "고칠 것이 없었다" 로 묻힌다
- 관측이 자기 보고에 앞선다. 커밋 없이 `committed` 라 보고하면 `no_change`, 커밋을 push 하고 `no_change` 라 보고하면 `committed` 다
- 기준 리비전이 새 head 의 조상이 아니어도(rebase · force push) head 가 다르면 `committed` 다. 증분 diff 처리는 리뷰 명령이 한다

### 5-5. `finalize`

outcome 은 늘 `checked` 이고, 확인하지 못한 것은 `remaining:` 줄로 낸다.

| 확인 | 걸리면 |
|---|---|
| 처리 대조 (5-6) | 5-6 의 줄 |
| 미커밋 변경 | `remaining: uncommitted changes are left` |
| 리뷰 요청 head 또는 로컬 HEAD 가 기준 리비전과 다르다 | `remaining: commits after the passing review — not reviewed` |
| `status` 가 `escalate` | `remaining: the developer handed this over: <reason>` |

- 리뷰 요청 · 스레드 조회가 실패하거나 기준 요약이 없으면 `remaining: could not verify the handling — <사유>` 를 내고 종료 코드 2.
  배선이 `*` 로 받아 끝은 done 이다
- 마무리 뒤의 커밋을 재리뷰하지 않는다. 사람이 리뷰 요청에서 받는다

### 5-6. 처리 대조

`handled` 인자는 JSON 배열 텍스트다. 원소마다 아래를 본다. 기준 요약보다 늦다는 것은 `created_at` 이 기준 요약의 것보다 크다는 뜻이다.

| 원소 | 확인 | 아니면 |
|---|---|---|
| `where` 가 `reply` | `thread` 가 스레드 목록의 `id` 하나이고, 그 스레드에 기준 요약보다 늦은 노트가 있다 | `remaining: no reply after the review in thread <id> — <finding>` |
| `where` 가 `note` | 기준 요약보다 늦은 노트 가운데 본문이 `FMT_HANDLED_HEADING` 으로 시작하는 것이 있다 | `remaining: no handling note after the review — <finding>` |
| `issue` 가 비지 않았다 | `tracker_issue_view <issue>` 가 성공한다 | `remaining: carryover issue <issue> not found — <finding>` |

- 인자가 JSON 배열이 아니거나 원소 형식이 3절과 다르면 `remaining: the handled list is not readable` 한 줄을 내고 대조를 건너뛴다
- 끝에 `handled: <확인한 원소 수> of <원소 수> confirmed` 한 줄
- 참조가 있는지만 본다. 답글 · 노트의 내용이 맞는지, 목록이 그 회차 발견을 빠짐없이 덮는지는 보지 않는다

## 6. 끝과 판정 어휘

`harness run work <이슈>` 의 끝 보고와 종료 코드는 #208 의 driver 공통 규칙이다 — 지나온 단계와 outcome, 끝 상태.
이 절차의 판정은 끝 상태와 그 끝으로 보낸 단계 · outcome 으로 정해진다. 어느 끝이든 리뷰 요청은 열린 채로 남는다.

| 끝 | 그 끝으로 보낸 자리 | 판정 | 사유로 보이는 것 |
|---|---|---|---|
| done | `finalize-check` | PASS | blocker · major 0건. 남은 것은 `finalize-check` 의 `remaining:` 줄 |
| handoff | `review` 종료 코드 3 | 상한 도달 | 회차 상한 또는 반복 지적 — 리뷰 명령의 출력 |
| handoff | `fix-check` `no_change` | 중단 | 코드가 바뀌지 않은 재시도. 남은 blocker · major 의 처리는 `remaining:` 줄 |
| handoff | `fix-check` `escalate` | 중단 | 구현자가 넘긴 사유 |
| handoff | `fix` `failed` | 중단 | 구현자 출력이 계약을 어겼다 |
| handoff | `finalize` `failed` | 중단 | 리뷰는 PASS 였다. 마무리 처리를 확인하지 못했다 |
| stop | `clean` `dirty` | 중단 | 미커밋 변경 |
| stop | `preflight` · `recheck` | 중단 | 착수 불가 · 실행 실패, 또는 재판정이 `plan` 이 아니다 — 착수 판정 명령의 출력 |
| stop | `task-sync` | 중단 | 동기화 실패 · 경합 — 동기화 명령의 출력 |
| stop | `develop` `failed` | 중단 | 구현자 출력이 계약을 어겼다 |
| stop | `develop-check` | 중단 | `verify_failed` · `escalate` · `no_mr` 또는 판정 실패 |
| stop | `review` 종료 코드 2 · 0 ~ 3 밖 | 중단 | 리뷰를 수행하지 못했다 — 리뷰 명령의 출력 |
| stop | `fix-check` `verify_failed` · 판정 실패 | 중단 | 검증 실패 · push 실패 |

driver 자신이 멈춘 끝(방문 · 단계 상한, 상태 불일치 등)의 사유는 #208 의 끝 보고가 낸다. 판정은 중단이다.

## 7. 헤드리스 구현자 권한

- `harness run work <이슈>` 호출이 그 이슈의 커밋 · push · 리뷰 요청 생성 지시다 (`.ai/AI_AGENT.md` 금지 사항의 "명시적 지시")
- 구현자 단계(`develop` · `fix` · `finalize`)는 헤드리스로 돈다. 그 실행에 한해 구현자는 아래를 승인 없이 한다

| 조작 | 예 |
|---|---|
| 파일 읽기 · 쓰기 | 역할의 `access = "write"` |
| git | `git switch` · `git switch -c` · `git add` · `git commit` · `git push`(작업 브랜치, 강제 없이) |
| 검증 | `script/run-lint-test.sh --commit` |
| forge | `.ai/forge.md` 의 리뷰 요청 생성 · 조회, `review_mr_threads` · `review_mr_thread_reply` · `review_mr_note_summary` |
| 하네스 스크립트 | `script/create-carryover-issue.sh`, `script/sync-task-issues.sh <이슈> --dry-run` |

- 이 허용은 #208 의 역할 러너가 그 실행의 인자로 준다. `[permissions].allow_push` 는 대화형 세션의 설정으로 남고 이 허용을 정하지 않는다
- 보호 브랜치 push · force push · `--no-verify` 는 deny 규칙 · 명령 가드 · pre-push 훅이 그대로 막는다. 헤드리스 실행에 `--bare` 를
  쓰지 않으므로 훅과 가드가 살아 있다

## 8. 이어 돌기

- 같은 클론에서 끊긴 실행은 #208 의 재개로 잇는다. 끊길 때 돌던 단계는 처음부터 다시 돈다
  - 구현자 단계: 4-2 · 4-3 의 재진입 규칙이 받는다. 커밋된 진행은 이어 가고, 미커밋 변경이 남았으면 구현자가 손대지 않고
    `escalate` 하고 판정은 미커밋 변경을 `verify_failed` 로 본다
  - 리뷰 단계: 다시 돌면 회차를 하나 더 쓸 수 있다. 회차 상한이 종료를 보장한다
  - 판정 단계: 관측만 하므로 다시 돌아도 같다
- 다른 클론에서 잇거나 실행 상태를 잃으면 이어지지 않는다. 새로 `harness run work <이슈>` 를 돌리면 열린 리뷰 요청 때문에 착수
  판정이 착수 불가를 낸다. 그 리뷰 요청은 사람이 이어받는다

## 9. 단계 지표

- driver 가 단계마다 스팬을 남긴다(#208). 이름은 `<절차>/<단계 id>` 이고 하위 절차의 단계는 하위 절차 이름을 쓴다
- 절차 문서의 시작 표지 줄(`script/metric.py step <절차> <단계>`)은 agent 절차 문서에만 render 가 넣는다. 옛 agent 절 `work` 의 문서도 그렇다

| 옛 키 (agent 절) | driver 의 키 |
|---|---|
| `work/sync-tasks` | `work/task-sync` |
| `work/implement` | `work/develop` (재시도는 `review-loop/fix`, 마무리는 `work/finalize`) |
| `work/review` | `review-loop/review` |
| `work/branch` · `work/limits` | 없음 — 판정은 `review-loop/fix-check` · `work/develop-check` · `work/finalize-check` |
| 없음 | `work/clean` · `work/preflight` · `work/recheck` · `work/loop` |

## 10. 옛 절과 이행

### 10-1. 되돌림

- `work` 를 agent 절차로 돌리려면 프로젝트 `harness.toml` 에 이전 기본값 절을 그대로 둔다. `workflows.<이름>` 은 통째로 교체되므로
  그 절이 내장 기본값을 가린다
- 이전 기본값 절:

```toml
[workflows.work]
steps = [
  { id = "sync-tasks", type = "script", title = "task 이슈 동기화", run = "script/sync-task-issues.sh <Requirement 이슈번호>" },
  { id = "implement", type = "agent", title = "구현", role = "developer" },
  { id = "review", type = "script", title = "리뷰", run = "script/review-mr.sh <MR번호>" },
  { id = "branch", type = "prompt", title = "분기 — 종료 코드로만 한다" },
  { id = "limits", type = "prompt", title = "상한" },
]
```

- 기존 설치본은 설치 때 이 절을 복사받아 이미 이 상태다. 시드(#207 의 프로젝트 `harness.toml` 원형)에는 `[workflows.work]` ·
  `[workflows.review-loop]` 를 두지 않는다 — 새 설치본은 내장 기본값을 쓴다
- 옛 절과 함께 쓰는 설정에서도 `review-loop` 는 내장 기본값으로 있다. 부르는 절차가 없어도 render 는 통과한다

### 10-2. 옛 조각과 `/work` 커맨드

- 옛 단계 조각 `work/sync-tasks.md` · `implement.md` · `review.md` · `branch.md` · `limits.md` 는 그대로 둔다. 옛 절이 이 조각으로 렌더된다
- `src/templates/managed/.claude/commands/work.md` 는 그대로 두고, `work` 가 agent 절차일 때만 깔린다(#208 의 driver 절차 커맨드 제외 규칙).
  CLAUDE.md 의 커맨드 표 행도 같은 조건을 따른다
- `harness run work <이슈>` 는 두 실행 방식 모두의 진입점이다. agent 절이면 오케스트레이터를 띄워 `/work` 를 부른다

### 10-3. doctor 와 `harness fix legacy-work`

doctor `config` 절에 항목 하나를 더한다.

| 조건 | state | what | detail |
|---|---|---|---|
| 프로젝트 레이어의 `[workflows.work]` 가 이전 기본값과 같다 | `warn` | `workflows.work is the previous default` | `` work runs on the old agent workflow — remove it with `harness fix legacy-work` `` |

- "같다" 는 읽은 표가 `{"steps": <이전 기본값의 다섯 단계>}` 와 같다는 뜻이다. 단계의 `kind` 는 `type` 으로 읽고, 키 순서는 보지 않는다.
  `title` · `execute` · `text` 같은 키가 더 있거나 단계 값이 하나라도 다르면 같지 않다 — 프로젝트가 고른 절로 두고 짚지 않는다
- 이전 기본값은 doctor 와 `fix legacy-work` 가 함께 쓰는 상수 하나다

`harness fix legacy-work`:

| 상태 | 동작 | 종료 코드 |
|---|---|---|
| 프로젝트 `harness.toml` 에 `[workflows.work]` 가 없다 | `fix: workflows.work is not in harness.toml — nothing to do` | 0 |
| 있고 이전 기본값과 다르다 | 아무것도 바꾸지 않고 `error: workflows.work differs from the previous default — edit it yourself` | 2 |
| 이전 기본값과 같다 | 그 절을 지우고 설정을 다시 읽어 검증한 뒤 render 한다. `fix: removed workflows.work — work now runs on the driver workflow` | render 의 것 |

- 절을 지우는 범위와 빈 줄 정리는 `harness steps <절차> --delete` 와 같다. 매니페스트 사전 판정 · 사용자 파일 판정 · 실패 시 되돌림도 같다
- `FIXES` 에 `legacy-work` 를 더하고 사용법 문구에 한 줄을 더한다: `legacy-work  remove a [workflows.work] that equals the previous default`
- UI: `src/ui/lib/doctor.js` 의 조치 고르기 표에 `config` · `workflows.work is the previous default` · — · `legacy-work` 행,
  `doctorFix` 가 `legacy-work` 를 `harness fix legacy-work` 로 부른다. 문구는 제목 "work 절차가 이전 기본값으로 고정되어 있습니다",
  본문 "harness.toml 의 [workflows.work] 가 이전 기본값과 같아 work 가 옛 agent 절차로 돕니다. 지우면 하네스가 단계를 직접 도는 기본 절차를 씁니다."

### 10-4. 이 리포

- 루트 `harness.toml` 의 `[workflows.work]` 절을 지운다. 이 리포의 `work` 는 내장 기본값(driver)으로 돈다
- 그 결과 이 리포의 `.claude/commands/work.md` 는 다음 render 가 걷고, `.ai/workflows/work.md` · `review-loop.md` 는 driver 문서다

### 10-5. 범위 밖 — 옛 경로를 걷는 일

main 릴리스를 한 번 거친 뒤 shim 정리 Requirement 가 함께 걷는다. 걷을 대상과 그때 함께 가야 하는 것:

- 옛 단계 조각 다섯, `/work` 관리 커맨드, 이전 기본값 상수와 doctor 항목, `fix legacy-work`
- 옛 절을 가진 설정의 render 를 고유한 거부 메시지와 이행 안내(절을 지운다)로 멈추는 검사

## 11. 문서 갱신

| 파일 | 고치는 것 |
|---|---|
| `src/templates/generated/CLAUDE.md` | 흐름 그림의 `/work <이슈>  →  work-preflight.sh …` 줄을 `harness run work <이슈>` 에서 시작하는 driver 흐름(작업 트리 확인 → 착수 판정 → [분해 있음] task 동기화 · 재판정 → developer → 구현 판정 → review-loop(리뷰 ⇄ 수정 · 수정 판정) → 마무리)으로 |
| `src/templates/agents/code-reviewer.md` summary | "`/work` 루프의 리뷰 수단이 아니다 — 루프는 `script/review-mr.sh` 하나만 쓴다" → "`work` 의 리뷰 루프(`review-loop`) 수단이 아니다 — 리뷰 루프는 `script/review-mr.sh` 하나만 쓴다" |
| `src/templates/agents/security-guard.md` | summary 와 본문의 "`/work` 루프" 를 "`work` 의 리뷰 루프(`review-loop`)" 로 |
| `src/templates/managed/docs/workflow/flow.md` | 머리 그림과 절 제목의 `/work` 를 `harness run work` 로. 흐름 그림을 2절의 단계로. "루프가 멈추는 조건" 표의 "절차" 칸을 구현 판정 · 수정 판정(`script/work-check.sh`)으로. 옛 절로 되돌리는 법과 doctor · `fix legacy-work` 한 단락 |
| `src/templates/managed/docs/workflow/changing.md` | 기본 절차 `work` 는 driver 이고 리뷰 루프는 `workflows.review-loop` 라는 것. agent 로 되돌리는 법(10-1). 구현자에게 줄 프로젝트 지시는 역할 메모에 둔다는 것 |
| `src/templates/managed/script/README.md` | `work-check.sh` 행(판정 명령 shim — `clean` · `develop` · `fix` · `finalize`, 0=판정 · 2=판정 못 함, 호출 시점: `work` 의 판정 단계). `work-preflight.sh` 의 호출 시점을 "착수 판정 · 착수 재판정 단계", `review-mr.sh` 를 "`review-loop` 의 리뷰 단계" 로 |
| 착수 판정 명령의 머리 설명 (#211 이 옮긴 자리와 shim 머리글) | "착수 전과 구현 위임 직전에 같은 명령을 돌린다" → "착수 전에 돌리고, 분해 경로는 task 동기화 뒤에 한 번 더 돌린다" |
| `src/templates/workflows/retro/signals.md` | "커맨드 직후 교정 발언 집중" 행을 "대화형 절차 직후 교정 발언 집중" 으로. driver 절차는 헤드리스로 돌아 대화 기록이 남지 않는다 |
| `src/ui/lib/doctor.js` | origin 항목 본문 "/work 가 원격을 가져오지 못하고 멈춥니다" → "work 절차가 원격을 가져오지 못하고 멈춥니다". 10-3 의 항목 |
| `README.md` "명령" 표 | `harness fix hooks\|verify\|legacy-work` — `legacy-work` 는 이전 기본값과 같은 `[workflows.work]` 를 지워 driver 기본 절차로 옮긴다. `harness work-check <동작> …` — `work` 의 판정 단계가 부른다 |
| `README.md` "업데이트" | 기존 설치본의 `work` 이행 — 이전 기본값 절이 남아 옛 절차로 돈다는 것, doctor 의 항목, `harness fix legacy-work`, 되돌릴 때 넣을 절(10-1 원문) |

## 12. 회귀 테스트

테스트는 원격과 에이전트 CLI 를 부르지 않는다. 원격은 로컬 bare 리포, forge 는 페이크(#209 의 주입 지점), 구현자 · 리뷰어는
PATH 앞의 스텁 실행 파일이다. 구현자 스텁은 케이스마다 정해진 git 조작과 페이크 forge 상태 변경(리뷰 요청 생성 · 답글 · 노트)을
하고 `developer-result` 를 낸다. 리뷰어 스텁은 케이스마다 정해진 판정 데이터를 낸다.

### 12-1. `render-test.sh` — driver `work`

| 케이스 | 확인하는 것 |
|---|---|
| PASS — 단독 경로 | 끝 done, 지나온 단계가 `clean` · `preflight` · `develop` · `develop-check` · `loop`(`review`) · `finalize` · `finalize-check`. task 동기화가 불리지 않는다. 리뷰 요청이 열려 있다 |
| PASS — 분해 경로 | `preflight` → `task-sync` → `recheck` → `develop`. 페이크 트래커에 task 이슈가 생긴다 |
| 재판정이 다르다 | 두 번째 착수 판정이 착수 불가를 내면 구현자가 불리지 않고 끝 stop |
| 미커밋 변경 | `clean` 에서 stop. 착수 판정과 구현자가 불리지 않는다 |
| 착수 불가 | 이슈에 열린 리뷰 요청이 있으면 `preflight` 에서 stop |
| 수정 뒤 PASS | 리뷰 1 → `fix`(커밋 · push) → `fix-check` `committed` → 리뷰 0 → 마무리 → done. 리뷰 단계 두 번, 회차 라벨 2 |
| 코드가 바뀌지 않은 재시도 | `fix` 가 커밋 없이 끝나면 `no_change` → handoff. 리뷰 단계는 한 번이다 |
| 관측이 보고에 앞선다 | `committed` 라 보고하고 커밋이 없으면 handoff. `no_change` 라 보고하고 커밋을 push 하면 리뷰가 다시 돈다 |
| 검증 실패 | `fix` 가 미커밋 변경을 남기면 stop. 로컬 커밋만 하고 push 하지 않아도 stop |
| escalate | `develop` 의 `escalate` 는 stop, `fix` 의 `escalate` 는 handoff. 사유가 stderr 에 나온다 |
| 리뷰 상한 · 실패 | 리뷰 3 이면 handoff, 2 면 stop. 그 뒤 구현자가 불리지 않는다 |
| 구현자 출력 위반 | 스키마를 어긴 출력이면 `develop` 은 stop, `fix` · `finalize` 는 handoff |
| 마무리 확인 | `handled` 가 가리킨 답글이 없으면 `remaining:` 줄이 나오고 끝은 done. 마무리 중 커밋이 생기면 `remaining: commits after the passing review` |
| 단독 실행 거부 | `harness run review-loop <이슈>` 가 거부된다 |
| 기본 설정 렌더 | 새 설치본에 `.ai/workflows/work.md` · `review-loop.md` 가 생기고 `.claude/commands/work.md` 가 없다. CLAUDE.md 커맨드 표에 `work` 행이 없다. `work.md` 에 시작 표지 줄이 없다 |
| 옛 절 | 이전 기본값 절을 가진 설정이 옛 조각으로 렌더되고 시작 표지 줄이 있으며 `.claude/commands/work.md` 가 깔린다. doctor 가 `workflows.work is the previous default` 를 `warn` 으로 낸다 |
| `fix legacy-work` | 이전 기본값 절을 지우고 render 해 `work.md` 가 driver 문서가 되고 `.claude/commands/work.md` 가 걷힌다. 고친 절이면 종료 코드 2 와 파일 그대로, 절이 없으면 종료 코드 0 과 파일 그대로 |
| 표지 일치 | 설치된 `.ai/templates/developer.md` 가 `FMT_HANDLED_HEADING` 의 값을 그대로 적는다 |

### 12-2. `src/test/unit/` — `work-check`

임시 git 리포와 페이크 forge 로 돈다.

| 케이스 | 확인하는 것 |
|---|---|
| `clean` | 추적 파일 변경 · 비추적 파일이면 `dirty`, git 이 무시하는 파일만 있으면 `clean` |
| 순서 — 검증 실패 먼저 | `fix` 에서 미커밋 변경이 있으면 `status` 와 head 에 상관없이 `verify_failed` |
| 순서 — escalate 와 커밋 유무 | `fix` 에서 `escalate` 보고는 head 가 기준 리비전과 같든 다르든 `escalate` |
| 관측 우선 | `fix`: `committed` 보고 + head 그대로 → `no_change`, `no_change` 보고 + 새 head → `committed`. `develop`: `no_change` 보고 + 열린 리뷰 요청 → `committed` |
| push 안 됨 | 리뷰 요청 head 가 로컬 HEAD 와 다르면 `verify_failed` |
| 리뷰 요청이 아니다 | 숫자가 아닌 인자 · 닫힌 리뷰 요청 · 다른 소스 브랜치 · 이슈 목록에 없는 리뷰 요청이면 `develop` 이 `no_mr` |
| 기준 요약 | 리뷰 시점 head 줄이 없는 더 늦은 요약은 건너뛴다. 줄이 있는 요약이 하나도 없으면 `fix` 가 종료 코드 2 와 빈 stdout |
| 처리 대조 | 기준 요약보다 늦은 답글은 확인, 이른 답글 · 없는 스레드 id 는 `remaining:`. 표지로 시작하는 늦은 노트는 확인, 표지 없는 노트는 `remaining:`. 없는 이월 이슈는 `remaining:`. 읽을 수 없는 `handled` 는 한 줄로 알리고 outcome 은 그대로 |
| `finalize` | 무엇이 걸려도 `checked`. 조회 실패면 종료 코드 2 와 `remaining: could not verify` |
| 출력 위생 | `reason` · `finding` 의 제어 문자와 줄바꿈이 stderr 에 그대로 나오지 않는다 |
| 인자 | 동작 없음 · 모르는 동작 · 인자 개수 틀림 · `--json` 이면 종료 코드 2 |
| forge 실패 | 리뷰 요청 조회가 실패하면 `develop` · `fix` 가 종료 코드 2 와 빈 stdout |

### 12-3. UI

| 파일 | 케이스 |
|---|---|
| `doctor.test.js` | `config` 의 `workflows.work is the previous default` 가 10-3 의 제목 · 본문과 조치 `legacy-work` 로 옮겨진다. 다른 절의 같은 문구에는 조치가 붙지 않는다. origin 항목 본문에 `/work` 가 없다 |

회귀 테스트 전체(`script/run-lint-test.sh`)가 통과한다.

## 13. 보호 문서 개정 범위

분해의 task 하나가 이 범위 안에서 고친다. #208 · #211 도 같은 위치를 고친다 — 아래 문안은 그 개정 위에 더하는 사실이다.

| 문서 · 위치 | 문안 |
|---|---|
| `.ai/project/scope.md` "할 수 있는 일" 의 `run` 항목 | 기본 절차는 `prework` · `work` · `retro` 셋이고 프로젝트가 더할 수 있다. `work` 는 하네스가 단계를 직접 도는 절차이고 그 리뷰 루프는 하위 절차 `review-loop` 다. `prework` · `retro` 는 설정된 오케스트레이터가 절차 문서를 따라 돈다 |
| `.ai/project/architecture.md` "구성 요소" 의 대상 리포 `script/` 항목 | 나열에 `work` 절차의 판정(`work-check.sh` → `harness work-check` — 작업 트리 확인 · 구현 판정 · 수정 판정 · 마무리 확인)을 더한다 |
| `.ai/project/architecture.md` "데이터 흐름" 의 절차 실행 | "리뷰 루프는 `work-preflight.sh`(…) → 구현자 → `review-mr.sh`(…) → … → 종료 코드로 분기." 를 다음으로 바꾼다: 기본 `work` 는 driver 절차다 — `harness run work <이슈>` 가 작업 트리 확인 → 착수 판정 → (분해 있음) task 이슈 동기화 → 착수 재판정 → 구현자(헤드리스, 구현자 결과) → 구현 판정 → 하위 절차 `review-loop` → 마무리 → 마무리 확인을 돈다. `review-loop` 는 `review-mr.sh`(리뷰 러너 점검 · diff 조회 · 리뷰어 실행 · 등록 · 회차 라벨) → 리뷰어의 판정 데이터(JSON 블록) → `post-review.sh`(스키마 검증 · 등급 집계 · 반복 지적 누적 · 요약 · 인라인 댓글 렌더링) → 종료 코드 0 끝 · 1 수정 → 수정 판정 → 다시 리뷰 · 2 멈춤 · 3 사람에게 넘김 |
| `.ai/project/architecture.md` "신뢰 경계" 의 들어오는 입력 | 구현자 결과(구조화 출력)를 더한다 — 하네스가 스키마로 검증하고, 판정 명령은 그 자기 보고보다 git · forge 관측을 앞세운다. 그 문자열은 셸을 거치지 않고 인자로만 들어가며, 터미널에 옮길 때 제어 문자를 지운다 |
| `.ai/project/architecture.md` "새 코드를 둘 곳" | `work` 절차의 판정 규칙 → `harness work-check` 명령 모듈 |
| `.ai/project/glossary.md` "용어" | `구현자 결과` — 구현자가 단계마다 내는 구조화 출력(`developer-result`). `status`(committed · no_change · verify_failed · escalate) · `mr` · `reason` · `handled` |
| `.ai/project/glossary.md` "용어" | `구현 판정` — `harness work-check` 가 구현자 결과와 git · forge 관측으로 내리는 outcome. 관측이 자기 보고에 앞선다 |
| `.ai/project/glossary.md` "용어" | `리뷰 루프` — `work` 의 하위 절차 `review-loop`. 리뷰 명령 → 수정 → 수정 판정을 돈다 |
| `.ai/project/glossary.md` "용어" | `구현자 모드` — 구현 · 재시도 · 마무리. 부르는 쪽이 알린다 |
| `.ai/project/glossary.md` "폐기된 별칭" | `/work <이슈>` (기본 `work` 절차의 진입점) → `harness run work <이슈>` |
| `.ai/project/testing.md` "외부 의존을 어떻게 다루나" 의 에이전트 CLI 항목 | 구현자도 스텁 실행 파일이다 — `developer-result` 를 내고 케이스에 따라 커밋 · push · 리뷰 요청 생성을 흉내 낸다 |

## 14. 결정 기록

결정 기록: 없음 — 이 명세의 결정은 작업 절차 조정이다(`.ai/adr.md` 의 대상 밖). 절차를 블록 그래프로 하네스가 돌리는 결정과
구조화 출력은 하네스 검증이 계약이라는 결정은 #208 의 결정 기록이 갖는다. ADR 0003 · 0004 · 0014 의 Decision 은 그대로다.

## 15. 한계

- 이어 돌기는 같은 클론에서만 된다. 다른 클론에서 잇거나 여러 클론이 같은 이슈를 동시에 착수하는 것은 막지 않는다(#215 의 범위)
- 재개로 다시 도는 리뷰 단계는 회차를 하나 더 쓸 수 있다
- "설계와 상충하는 인터페이스 변경" 을 사람에게 돌리는 판단은 구현자(리뷰받는 쪽)가 한다. 리뷰 판정 데이터에는 이 범주를 가르는 필드가 없다
- 처리 대조는 참조가 있는지만 본다. 답글 · 노트의 내용과, 목록이 그 회차 발견을 빠짐없이 덮는지는 보지 않는다
- 발견 0건으로 PASS 해도 마무리에서 구현자를 한 번 부른다
- 리뷰 시점 head 를 남기지 않은 요약(손으로 등록한 요약)은 기준 요약이 되지 않는다. 그런 요약만 있으면 수정 판정이 멈춘다
- 리뷰 요청 head 의 반영이 forge 에서 늦으면 push 한 직후의 판정이 `verify_failed` 를 낼 수 있다 — 리뷰 명령의 같은 검사와 같은 한계다
- 헤드리스 실행에서 허용되지 않은 명령이 승인 대기 없이 거부로 끝나는지, codex 의 `workspace-write` 샌드박스가 push 와 forge CLI 의
  네트워크를 막는지 <!-- TBD: 확인 필요 --> — 확인과 그에 맞는 실행 인자는 #208 의 역할 러너가 갖는다. push 가 막히면 판정이
  `verify_failed` 로 멈춘다
- 옛 agent 절은 프로젝트 레이어 설정이다. 하네스는 그 단계 목록을 바꾸지 못하고 조각 본문만 바꿀 수 있다
