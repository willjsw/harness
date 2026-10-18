# #213 분해 — 남은 관리 스크립트의 하위 명령 이식과 shim 전환

명세: [`docs/spec/213-retire-shell-scripts.md`](../../spec/213-retire-shell-scripts.md)
결정 기록: 없음. 근거 결정은 #206 의 결정 기록 0019 "하네스 로직은 Python 표준 라이브러리 패키지 하나에 둔다" 다

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | chore | 관리 스크립트 셸 회귀 테스트의 준비부를 하네스 루트 샌드박스로 전환 | 없음 |
| T2 | chore | 회귀 테스트의 검증 · 지표 · 역할 실행기 준비부를 설치한 리포 기준으로 전환 | 없음 |
| T3 | feat | 표지를 패키지 내장 값으로 갖고 표지 파일을 읽지 못해 멈추는 경로 제거 | 없음 |
| T4 | refactor | 이월 이슈 생성을 carryover 하위 명령으로 옮기고 shim 전환 | T1, T3 |
| T5 | refactor | 되감기를 rollback 하위 명령으로 옮기고 shim 전환 | T1, T3 |
| T6 | refactor | 사용 기록 모듈과 usage log 하위 명령, 가드 · 훅의 차단 기록 전환 | T1 |
| T7 | refactor | 사용 기록 집계를 usage report 하위 명령으로 옮기고 shim 전환 | T6 |
| T8 | refactor | 스팬 기록기를 패키지 모듈로 옮기고 CLI 안의 스팬 기록을 그 모듈로 전환 | T2 |
| T9 | refactor | 역할 실행기를 run-agent 하위 명령으로 옮기고 드라이버가 같은 프로세스에서 부름 | T1, T2, T8 |
| T10 | refactor | 스팬 기록을 span 하위 명령으로 옮기고 metric.py 를 shim 으로 전환 | T8, T9 |
| T11 | refactor | 클론 키 계산을 패키지 모듈 하나로 모으고 _clone_key.py 를 clone-key shim 으로 전환 | T10 |
| T12 | feat | 검증 실행을 verify 하위 명령으로 옮기고 harness-verify.sh 를 설정과 무관한 생성 shim 으로 전환 | T2, T8 |
| T13 | refactor | 리뷰 루프 · 착수 판정 · task 동기화가 사용 기록 · 스팬 · 역할 실행을 패키지 모듈로 부름 | T6, T8, T9 |
| T14 | feat | 권한 허용 목록에 하위 명령 묶음 추가 | T6, T9, T10, T12 |
| T15 | docs | README · 스크립트 목록 · 변경 안내 · 설정 주석에 하위 명령과 shim 반영 | T4, T5, T7, T11, T12, T13, T14 |
| T16 | docs | 다른 명세의 표지 · 클론 키 · 허용 목록 서술을 하위 명령 기준으로 갱신 | T3, T11, T14 |
| T17 | docs | 아키텍처 · 용어 · 테스트 문서에 하위 명령과 패키지 정본 반영 | T3 ~ T14 |

- T1 · T2 는 구현을 바꾸지 않는다. 회귀 테스트의 준비부를 옛 스크립트와 shim 양쪽에서 같은 결과를 내는 형태로 바꾸고 **옛 스크립트로
  통과시킨다**(명세 10-1). 기대값은 바꾸지 않는다. T1 은 `script/test-*.sh`, T2 는 `src/test/render-test.sh` 를 고친다
- T3 이 표지를 패키지 값으로 만든 뒤에 표지를 쓰는 이월 이슈 · 되감기(T4 · T5)가 옮겨 온다. 새 명령에 표지 파일을 읽지 못하는 경로를
  만들지 않는다
- 사용 기록은 기록(T6)과 집계(T7)로 나눈다. T6 이 `usage` 명령을 `log` 하나로 만들고 T7 이 `report` 를 더한다
- 지표와 역할 실행기는 T8 → T9 → T10 순이다. `script/run-agent.py` 는 같은 디렉터리의 `metric.py` 를 모듈로 불러오고, CLI 는 대상
  리포의 `script/metric.py` 를 경로로 불러온다(`load_metric`). 그래서 `metric.py` 를 shim 으로 바꾸는 T10 은 CLI 쪽(T8)과 역할
  실행기(T9)가 패키지 기록기로 옮겨 간 뒤다. T8 은 `script/metric.py` 를 고치지 않는다 — 셸 쪽 부르는 곳이 T10 까지 그것을 쓴다
- T11 은 T10 뒤다. `metric.py` 가 `_clone_key.py` 를 모듈로 불러오는 일이 T10 에서 없어지고, CLI 의 `clone_key_module` 이 경로로
  불러오는 일은 T11 이 없앤다. 그 뒤라야 `_clone_key.py` 를 shim 으로 바꿀 수 있다
- T12 는 검증의 스팬을 패키지 기록기(T8)로 남긴다. 이 리포의 검증 일괄 자체가 T12 의 커밋부터 새 구현으로 돈다
- T13 은 사용 기록 · 기록기 · 역할 실행기(T6 · T8 · T9)가 모두 패키지에 생긴 뒤 #211 의 경계 모듈 `src/harness/scripts.py` 를 걷는다.
  그 전까지 #211 하위 명령은 shim 을 거쳐 같은 출력 · 종료 코드 · 기록을 낸다
- T14 는 묶음의 네 명령(`run-agent` · `span` · `usage` · `verify`)이 `COMMANDS` 에 든 뒤다 — 묶음 상수의 이름이 `COMMANDS` 에 없으면
  render 가 거부한다
- T15 · T16 은 코드가 만든 사실을 사람용 문서와 다른 명세에 적는다. T17 은 보호 문서를 고치는 task 하나다

## 착수 순서와 다른 이슈

- 착수 조건: #96 · #206 · #207 · #208 · #209 · #210 · #211 · #212 가 `develop` 에 머지된 뒤 착수한다(#210 은 #220 뒤에 머지된다)
- 이 이슈 뒤에 #215 가 온다. #215 는 되감기 명령 모듈(`src/harness/commands/rollback.py`)의 머리 설명과 `harness help` 설명을 고치고,
  표지 정본 `src/harness/format.py` 와 셸 표기 `script/harness-format.sh` 에 `FMT_REVIEW_RECORD` 를 더한다. T3 의 일치 단위 테스트가 두
  쪽을 함께 고치게 한다
- #221 은 이 이슈 · #215 의 머지와 main 릴리스 한 번 뒤에 shim · 셸 생성물 · 셸 표기 · 옛 허용 규칙을 걷는다. `script/run-lint-test.sh` 는
  #221 3절의 조건부 생성 대상이다. 이 이슈는 아무 파일도 걷지 않는다
- 이 이슈의 task 는 #206 ~ #212 가 고친 파일(`src/harness/commands/__init__.py` · `src/harness/cli.py` · `src/test/render-test.sh` ·
  `src/templates/managed/script/README.md` 등)을 다시 고친다. 선행 리뷰 요청이 머지되면 `git fetch -p origin` 뒤 `develop` 위로
  rebase 한다. rebase 뒤 push 는 사람이 한다
- `src/test/render-test.sh` 의 새 블록 번호는 착수 시점의 최대 `UT-<번호>` 다음부터 매긴다 — 번호 중복은 회귀 테스트가 막는다

## 브랜치·리뷰 요청·커밋

- 브랜치: `refactor/213-retire-shell-scripts` — 요구사항 이슈 #213 하나가 브랜치 하나·리뷰 요청 하나다. 태그는 요구사항 이슈 제목의
  `refactor` 다
- 리뷰 요청 제목: `refactor: 남은 관리 스크립트를 하위 명령으로 옮기고 shim 으로 전환(#213)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #213` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 리뷰 요청 본문에 회귀 테스트의 대응표를 둔다 — task 가 고치거나 지운 검사 줄마다 옛 줄 → 새 줄(지운 줄은 그 약속을 이어받는 검사)
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #213`

## 전 task 공통 사항

- 정본: 하위 명령과 공용 모듈은 `src/harness/`, shim · 셸 표기 · 셸 회귀 테스트는 `src/templates/managed/script/`. 정본을 고친 뒤
  `src/bin/harness render` 로 이 리포의 `script/` 사본 · 생성 파일 · `.harness/managed` · `.harness/generated` 를 갱신해 함께 커밋한다.
  사본과 생성 파일을 손으로 고치지 않는다
- 표준 라이브러리만 쓴다. 새 명령과 shim 은 리포 어디에도 `__pycache__` 를 남기지 않는다
- 새 명령은 #206 의 규칙을 따른다 — 명령마다 `src/harness/commands/<모듈>.py` 하나(`run-agent` → `run_agent.py`, `clone-key` →
  `clone_key.py`), `COMMANDS` 항목의 통과 표시 `True` 와 명세 2-1 의 `harness help` 인수 · 설명, `DELEGATES` 에 이름.
  명령은 자기 프로세스의 현재 디렉터리를 바꾸지 않는다. 처리하지 않은 예외의 종료 코드는 명세 2-1 대로다
- 옛 경로의 인자 · 표준 입력 처리 · 표준 출력 · 표준 오류 문구 · 종료 코드 · 남기는 기록을 바꾸지 않는다. 터미널 출력은 영어다(ADR 0011)
- shim 은 명세 4-1 의 공통 형태 하나다 — 자기 위치의 부모를 하네스 루트로 잡고, `<루트>/.harness/bin/harness` · `<루트>/src/bin/harness`
  순으로 실행 가능한 첫 것을 CLI 로 골라 `<CLI> --target <루트> <명령> <받은 인자 그대로>` 로 exec 한다(파이썬 shim 은 `sys.executable`).
  현재 디렉터리 · 표준 입출력 · 환경을 바꾸지 않고 설정 · 생성물을 읽지 않는다. CLI 를 찾지 못할 때의 문구 두 줄과 종료 코드는 명세 4-1
  의 표대로다. 실행 권한과 첫 줄(`#!/usr/bin/env sh` · `#!/usr/bin/env python3`)을 지키고, 머리글에 부르는 명령의 이름과 로직이 패키지에
  있다는 것을 적는다
- 에이전트와 사람이 보는 명령 표기(절차 조각 · 역할 계약 · 역할 어댑터 · 규칙 문서 · `CLAUDE.md` · 실행 계획의 `entry`)는
  `script/<이름>` 그대로 둔다
- 설정은 명세 7절대로 읽는다. 공유 설정을 읽는 명령은 개인 레이어 파일을 열지 않는다. `span` · `run-agent` 는 실행 계획을 실효 설정에서
  `run_plan()` 으로 같은 프로세스에서 계산하고 `harness run-plan` 을 하위 프로세스로 띄우지 않는다. 새 명령은 `script/harness.env` ·
  `script/forge.sh` 를 읽지 않는다
- forge 는 #209 어댑터의 계약 함수로만 부른다
- 회귀 테스트는 명세 10-1 을 따른다. 기대값은 바꾸지 않는다 — 예외는 1절의 표지 변화로 없어지는 경로를 보는 줄(T3)이다. 고칠 수 있는
  것은 준비부와 구조 검사 줄이고, 고친 줄은 리뷰 요청 본문의 대응표에 적는다
- 단위 테스트는 `src/test/unit/test_<대상>.py` 에 두고 `[verify]` 의 "Python 단위 테스트" 단계로 돈다. CLI 를 하위 프로세스로 띄우지
  않고, 원격 · 에이전트 CLI 를 부르지 않으며, 시각은 고정값을 넣는다
- `src/test/render-test.sh` 의 새 블록은 명세 10-3 의 항목마다 하나다. 항목을 성립시키는 task 가 자기 케이스를 그 블록에 더하고, 블록이
  아직 없으면 만든다. 10-3 의 1(그대로 넘김) · 5(고정 버전으로 넘어감) · 10(바이트코드 없음)은 shim 을 만드는 task 마다 자기 shim 의
  케이스를 더한다. 4(CLI 를 찾지 못할 때)는 그 항목이 적은 shim(`usage-log.sh` · `metric.py` · `_clone_key.py` · `run-lint-test.sh` ·
  `rollback-work.sh`)을 만드는 task 가 더한다. 터미널 출력의 한글 검사를 새 블록에도 적용한다
- 셸 회귀 테스트(`script/test-*.sh`)는 지우지 않는다. 이 리포는 `verify.script_tests = false` 라 커밋 단계 검증이 셸 테스트를 돌리지
  않는다 — 셸 테스트를 고치거나 그 테스트가 부르는 스크립트를 shim 으로 바꾼 task 는 커밋 전에 그 셸 테스트를 직접 돌린다.
  `src/test/render-test.sh` 를 고친 task 는 커밋 전에 그것도 돌린다
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다. 동작이 바뀌어 틀리게 된 주석은 그 동작을 바꾸는 task 에서
  고친다
- 커밋 전 `script/run-lint-test.sh --commit` 이 통과한다

## 이번 이슈에서 정하지 않는 값

- 공용 모듈(`usage.py` · `runner.py` · `metrics/recorder.py` · `verify.py`) 안의 함수 이름과 나눔 — 명세는 모듈 자리와 책임, 기록기가
  지표 설정과 자리표시를 푼 디렉터리를 인자로 받는다는 계약만 정한다
- 하위 명령 묶음 상수의 이름
- 명세 5-1 의 표에 따로 적지 않은 곳의 부르는 방법(같은 프로세스 · 하위 프로세스) — 가드 · 훅의 차단 기록, #211 하위 명령의 사용 기록과
  스팬. 출력 · 종료 코드 · 기록은 지금과 같다
- `src/test/render-test.sh` 새 블록의 번호

## 이번 이슈에서 다루지 않는 것

- shim · 셸 생성물(`script/harness.env` · `script/forge.sh` · `script/harness-verify.sh`) · 셸 표기 · 옛 허용 규칙 · `script/README.md`
  걷기, 최종 명령 표기, 훅 · 가드의 하네스 루트 판정 변경, `verify.script_tests` 와 "하네스 스크립트 회귀" 단계의 처리, 셸 회귀 테스트의
  거취, 용어집 "폐기된 별칭" 행 — #221 (명세 12-1)
- `script/run-lint-test.sh` 를 리포 루트 CI 파일이 부르는 동안만 생성 파일로 두는 일 — #221 3절
- 되감기가 이 클론의 착수 잠금을 푸는 일, 표지 `FMT_REVIEW_RECORD` — #215
- 하네스 CI 게이트 파일의 생성물화 — #217
- 같은 제목 이월 이슈의 동시 실행 막기 — 중복 확인은 순차 실행 기준이다 (명세 2-2)
- shim 을 거치는 단계 시작 표지(`script/metric.py step`)의 지연 측정 (명세 13)
