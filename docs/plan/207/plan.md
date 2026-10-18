# #207 분해 — 설정 레이어와 개인 선택의 실행 시점 해석

명세: [`docs/spec/207-layered-config.md`](../../spec/207-layered-config.md)
결정 기록: [`docs/adr/0020-config-is-resolved-in-layers.md`](../../adr/0020-config-is-resolved-in-layers.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | roles.<역할>.enabled 로 역할을 끄고 켬 | 없음 |
| T2 | feat | 레이어 병합 규칙 표와 병합 · 출처 함수 | 없음 |
| T3 | feat | 내장 기본값 파일을 가장 아래 레이어로 두고 설정을 레이어 병합으로 읽음 | T1, T2 |
| T4 | chore | 회귀 테스트의 대상 설정을 내장 기본값 사본으로 만듦 | T3 |
| T5 | feat | install 이 프로젝트 이름만 담은 최소 설정을 깜 | T4 |
| T6 | feat | 내장 기본값과 preset 이 locked 로 값을 잠금 | T3 |
| T7 | feat | harness set 이 파일에 없는 키와 절을 더함 | T1, T3 |
| T8 | feat | 역할 어댑터의 모델과 절차 문서의 벤더 이름을 생성물에서 뺌 | T3 |
| T9 | feat | 개인 레이어 harness.local.toml 을 실효 설정으로 읽고 harness run 이 씀 | T6, T8 |
| T10 | feat | harness run-plan 이 이 기기의 실행 계획을 JSON 으로 냄 | T9 |
| T11 | feat | harness set --local 과 개인 파일을 git 이 무시하게 하는 줄 | T7, T9 |
| T12 | feat | 추적되는 개인 파일을 check 가 거부하고 worktree · uninstall 이 개인 파일을 다룸 | T11 |
| T13 | feat | 역할 실행기가 실행 계획을 run-plan 으로 받음 | T10 |
| T14 | feat | 리뷰 루프가 리뷰어 러너와 작성자 표시를 run-plan 으로 받음 | T10 |
| T15 | feat | 지표 기록기가 지표 설정을 run-plan 으로 받음 | T10 |
| T16 | feat | script/harness.plan.json 을 생성하지 않고 남은 파일을 render 가 지움 | T13, T14, T15 |
| T17 | feat | 전체 값 사본에서 지운 역할이 기본값으로 되살아나면 멈추고 안내 | T7, T16 |
| T18 | feat | harness schema 가 공유 설정과 값마다의 출처 · 개인 레이어 값을 냄 | T6, T9 |
| T19 | feat | harness doctor 가 개인 레이어와 실효 설정을 점검 | T10, T12 |
| T20 | feat | UI 가 설정 값을 schema 로 읽고 레이어 이름표와 점검 문구를 더함 | T18, T19 |
| T21 | feat | UI 설정 · Agents 화면에 값의 출처 · 잠금 · 개인 값 표시 | T20 |
| T22 | docs | README 와 사람용 문서 · 규칙 정본 원형에 설정 레이어 반영 | T16, T17, T18, T19 |
| T23 | docs | 보호 문서에 설정 레이어와 실행 계획 반영 | T16, T17, T18, T19 |

- T1 은 레이어보다 먼저 역할을 끄는 키를 넣는다. T3 이 내장 기본값의 일곱 역할을 깊게 병합하면 역할 표를 지우는 방식은 더는 역할을
  빼지 못한다. 그 방식에 기대는 회귀 케이스(남은 참조 검사 · 역할을 빼면 계약 · 어댑터 · 커맨드가 함께 빠지는 케이스)를 T1 이
  `enabled = false` 로 먼저 옮겨, T3 이 그 케이스를 고치지 않고 통과한다
- T2 는 병합 규칙 표와 출처 계산을 순수 함수로 두고 단위 테스트로만 본다. 설정을 읽는 자리에 잇는 것은 T3 이다
- T3 은 지금 기본 설정의 내용을 내장 기본값 파일로 옮기고 설정 읽기를 레이어 병합으로 바꾼다. 설치가 까는 파일
  (`src/templates/harness.toml`)은 T3 에서 바꾸지 않는다 — 전체 값 사본이 그대로 읽히므로 기존 회귀 케이스가 고치지 않고 통과한다
- T4 는 대상 설정을 손으로 만들거나 설치된 설정을 고치는 회귀 케이스를 내장 기본값 사본(이름을 채운 전체 값 사본)으로 옮긴다.
  기대값은 바꾸지 않고 T3 의 코드에서 통과한다. 그래서 T5 가 설치 파일을 최소 설정으로 바꿀 때 이 케이스들을 고치지 않는다
- T6(잠금) · T7(set) · T8(생성물의 모델 · 벤더 이름)은 T3 위에서 서로 기대지 않는다
- T9 는 실효 설정을 읽는 함수와 개인 레이어 검증을 넣고 `harness run` 이 그것을 쓴다. 받는 키 목록과 잠그지 못하는 키는 T6 이 둔
  것을 쓰고, 서브에이전트 역할의 개인 모델을 거부하는 규칙은 T8 이 정한 모델 규칙에 기댄다
- T10 이 `run-plan` 을 내면 실행 계획을 읽는 스크립트 셋(T13 · T14 · T15)이 파일 대신 그것을 받는다. 셋은 서로 기대지 않는다.
  `script/harness.plan.json` 은 T16 까지 지금처럼 공유 설정으로 생성된다
- T16 은 마지막 읽는 쪽이 파일을 떠난 뒤 생성을 멈춘다
- T17 의 판정은 직전 매니페스트의 `script/harness.plan.json` 을 "레이어 이전 하네스의 render" 표지로 쓰고, 통과한 render 가 그 줄을
  매니페스트에서 빼는 것(T16)까지 본다. 안내의 `harness set roles.<역할>.enabled` 가 역할 절을 더하는 것은 T7 이다
- T18 · T19 는 CLI 가 내는 값과 점검 항목을 확정하고, UI(T20 · T21)는 그것만 읽는다. UI → CLI 방향만 생긴다
- T22 · T23 은 코드가 만든 동작을 문서에 적는다. 둘은 서로 기대지 않는다. 결정 기록은 이 분해와 같은 리뷰 요청에 들어 있어 task 가 아니다

## 착수 순서와 다른 이슈

- 착수 조건: **#206 이 `develop` 에 머지된 뒤 착수한다.** 이 분해의 경로는 #206 명세의 모듈 지도(`src/harness/config/` ·
  `render/` · `commands/` · `readiness/` · `metrics/`), 명령 표 `COMMANDS`(`commands/__init__.py`)와 `DELEGATES`(`cli.py`),
  Python 단위 테스트 기반(`src/test/unit/` 과 `[verify]` 의 "Python 단위 테스트" 단계)을 쓴다. #96 은 #206 의 선행으로 이미 들어와 있다
- 이 이슈 뒤에 오는 것
  - #208 — 절차 드라이버가 실효 설정을 읽는 함수와 `run_plan()` 을 같은 프로세스에서 부르고, `run-plan` 의 역할 항목에 키를 더한다
  - #211 — `review-mr.sh` · `post-review.sh` 를 `harness review` · `review post` 로 옮기며 명세 7-3 의 실패 처리를 이어받는다
  - #213 — `run-agent.py` · `metric.py` 를 `harness run-agent` · `harness span` 으로 옮기며 명세 7-3 의 실패 처리를 이어받는다
  - #216 — preset 레이어 목록을 채우고 레이어 id 와 출처 표시를 정한다. #217 은 이 이슈의 배열 잠금을 쓴다
- 보호 문서 문안의 적용 순서는 #206 → #207 → #208 · #209 · #210 이다. T23 은 #206 이 고친 문장 위에 얹는다. #209 · #210 구현이
  먼저 머지되면 T23 의 문안을 그 위로 다시 맞춰, 명세 16절의 고친 문안과 같은 결과가 되게 한다
- #209 · #210 은 #206 뒤에 이 이슈와 나란히 갈 수 있고 같은 파일(`src/harness/` · `src/test/render-test.sh` · `README.md` ·
  `src/templates/managed/script/`)을 건드린다. 동작은 서로 기대지 않는다. 먼저 머지된 쪽 위로 `git fetch -p origin` 뒤 rebase 한다.
  rebase 뒤 push 는 사람이 한다
- `src/test/render-test.sh` 의 새 `UT-<번호>` 블록 번호는 머지 시점에 겹치지 않는 다음 번호로 매긴다 — 번호 중복은 회귀 테스트가 막는다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/207-layered-config` — 요구사항 이슈 #207 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: 설정을 레이어로 해석하고 개인 선택을 커밋 생성물에서 뺌(#207)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #207` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #207`

## 전 task 공통 사항

- CLI 와 대상 리포 스크립트는 python3 표준 라이브러리만 쓴다. CLI 코드는 #206 의 배치를 따르고, 패키지 안 import 규칙은
  `script/project/check-cli.py imports` 가 검사한다
- 새 코드의 자리
  - 레이어 목록 · 병합 규칙 표 · 병합 · 출처 · 잠금 판정: `src/harness/config/layers.py`
  - 개인 레이어의 받는 키 · 값 검증, 실효 설정 읽기, `info/exclude` 줄: `src/harness/config/local.py`
  - 공유 설정을 읽는 함수(레이어 읽기 → 병합 → 잠금 → 파생 → 검증): `src/harness/config/load.py`
  - `harness run-plan`: `src/harness/commands/run_plan.py`
- 공유 설정만 읽는 명령(명세 2-2 의 첫 줄과 2-2 원칙 표의 공유 설정 줄)은 `harness.local.toml` 을 열지 않는다. 그 파일을 읽는 것은
  실효 설정을 읽는 함수 하나다
- Python 단위 테스트는 `src/test/unit/test_<대상>.py` 에 두고 `cd src && python3 -B -m unittest discover -s test/unit` 로 돈다.
  CLI 를 하위 프로세스로 띄우지 않고 패키지 모듈의 함수를 부르며, 레이어는 파일 대신 값으로 넣는다. 파일 이름은 레이어 병합 ·
  잠금 · 출처 `test_layers.py`, 개인 레이어 `test_local_layer.py`, 실행 계획 `test_run_plan.py`
- 이 이슈는 동작을 바꾼다. 회귀 테스트(`render-test.sh` · `test-review-loop.sh` · `src/ui/lib/*.test.js`)의 기존 기대값은 명세
  14-3 · 14-4 · 14-5 와 각 task 의 완료 조건이 적은 것만 바꾼다. 기대값이나 준비부를 바꾼 줄은 리뷰 요청 본문에 전후 대응표로 둔다
- 기대값이 바뀌지 않는 준비부 수정은 그 준비부에 기대는 동작을 바꾸는 task 보다 앞 task 에서 하고, 그 task 의 코드에서 통과를 확인한다
  (T1 이 T3 앞에서, T4 가 T5 앞에서)
- 관리 스크립트(`run-agent.py` · `review-mr.sh` · `_review.py` · `post-review.sh` · `metric.py`)는 제자리(`src/templates/managed/script/`)에서
  고친다. 에이전트가 보는 명령 표기(`script/run-agent.py` · `script/review-mr.sh` · `script/post-review.sh`)는 바꾸지 않는다 —
  하위 명령으로 옮기는 것은 #211 · #213 이다
- 스크립트가 CLI 를 찾는 절차와 찾지 못할 때의 두 줄은 명세 7-3 그대로이고, 실행 계획을 읽는 스크립트 넷이 같은 절차 · 같은 문구를 쓴다
- 출력 · 오류 문구는 명세의 영어 원문 그대로 둔다. 새 블록의 터미널 출력에도 한글 검사를 적용한다
- 관리 스크립트 · 템플릿 · 생성 규칙을 고치면 `src/bin/harness render` 로 이 리포의 `script/` 사본, 생성 파일(`.claude/` · `.codex/` ·
  `.ai/workflows/` · `script/harness.env` 등)과 `.harness/managed` 를 갱신해 함께 커밋한다
- 이 리포 루트의 `harness.toml` 은 고치지 않는다 — 전체 값 사본이 그대로 읽히는 것을 이 리포가 보인다
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록
  형식을 따른다. 동작이 바뀌어 틀리게 된 주석은 그 동작을 바꾸는 task 에서 고친다
- 커밋 전 `script/run-lint-test.sh --commit` 이 통과한다. push 전 검증(pre-push)이 회귀 테스트 전체를 돈다

## 이번 이슈에서 정하지 않는 값

- preset 레이어를 몇 개 싣는지, 레이어 id 와 `layers[]` 항목의 출처 표시 — preset 받기(#216)가 정한다. 이 이슈에서 preset 목록은
  언제나 비어 있다
- `config/layers.py` · `config/local.py` 의 공개 함수 이름과 나눔 — 이 분해는 모듈 자리만 정한다

## 이번 이슈에서 다루지 않는 것

- preset 레이어를 채우는 일 — `extends` 해석, preset 받기 · lock · `harness pull`, preset 이 선언하는 잠금의 실제 사용
- 절차 확장 지점(빈 하위 절차)과 절차 블록 엔진
- 관리 스크립트(역할 실행기 · 리뷰 루프 · 지표 기록기)를 하위 명령으로 옮기는 일
- 전체 값 사본을 최소 설정으로 줄이는 쓰기 명령 — `schema` 의 `same_as_below` 로 읽기 보고만 한다
- UI 에서 개인 레이어 값을 쓰거나 역할을 끄고 켜는 조작
- 개인 레이어의 키를 지우는 명령, `harness uninstall` 이 `info/exclude` 에 적은 줄을 지우는 것
- 명세 7-7 의 확인 필요 항목(모델을 적지 않은 서브에이전트 정의가 그 세션의 모델로 도는지 벤더마다) — 코드 동작은 그 답과 상관없다
