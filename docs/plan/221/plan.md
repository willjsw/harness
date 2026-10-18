# #221 분해 — 이식 뒤 남은 shim · 셸 생성물 · 옛 허용 규칙 걷기와 최종 명령 표기

명세: [`docs/spec/221-retire-shims-and-generated.md`](../../spec/221-retire-shims-and-generated.md)
결정 기록: 없음 — 명세 15절. ADR 0002 · 0013 · 0015 · 0017 의 Decision 을 적용한다

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | chore | 계약 시험 공용 준비부와 명령 가드 셸 회귀 테스트 이관 | 없음 |
| T2 | chore | 시크릿 스캔 · 사용 기록 셸 회귀 테스트 이관 | T1 |
| T3 | chore | 리뷰 루프 셸 회귀 테스트 이관 | T1 |
| T4 | chore | 착수 판정 · task 동기화 셸 회귀 테스트 이관 | T1 |
| T5 | chore | 이월 이슈 · 되감기 셸 회귀 테스트 이관 | T1 |
| T6 | chore | forge 라벨 준비 · forge-setup 과 남은 셸 회귀 테스트 이관 | T1 |
| T7 | chore | 회귀 테스트의 shim 호출과 셸 생성물 내용 검사를 하위 명령 행동 검사로 전환 | 없음 |
| T8 | feat | 하네스 CLI 표기 변수와 관리 파일 치환, 걷힌 경로 대응 상수 | 없음 |
| T9 | chore | 절차 조각 · 절차 문서 · 내장 기본값 work 의 명령 표기를 하네스 CLI 로 전환 | T8 |
| T10 | chore | 역할 어댑터 · 역할 계약 · 양식 · 관리 커맨드의 명령 표기를 하네스 CLI 로 전환 | T8 |
| T11 | chore | 규칙 문서 · CLAUDE.md · forge 명령 사전 · doctor 문구의 명령 표기를 하네스 CLI 로 전환 | T8 |
| T12 | feat | 명령 표의 허용 표시로 하위 명령 허용 규칙 생성 | T9, T10, T11 |
| T13 | feat | 걷힌 경로를 가리키는 설정 값에서 render 를 멈추는 사전 판정과 doctor 항목 | T8, T9, T10 |
| T14 | feat | 명령 가드 · commit-msg · pre-push 가 공유 설정에서 판정 값을 읽음 | 없음 |
| T15 | feat | git 훅의 루트 판정과 pre-push · post-commit 검증을 CLI verify 로 전환 | T14 |
| T16 | feat | doctor · fix · schema 의 검증 진입점과 리뷰어 러너 점검을 하위 명령으로 전환 | T8 |
| T17 | feat | verify.script_tests 를 읽되 무시하고 지우라고 안내 | 없음 |
| T18 | feat | 리포 루트 CI 가 부를 때만 script/run-lint-test.sh 생성 | T8 |
| T19 | feat | CI 원형 · doctor 검증 절 · 이 리포 CI 의 검증 명령을 CLI verify 로 전환 | T15, T18 |
| T20 | docs | docs/workflow 의 하네스 명령 절과 script/README.md 를 가리키던 자리 갱신 | T9, T10, T11 |
| T21 | chore | 관리 스크립트 · 셸 생성물 · 셸 표기 · 셸 회귀 테스트 · script/README.md 걷기 | T1~T20 |
| T22 | feat | UI Doctor 의 새 설정 · CI 항목과 단계 입력 자리표시를 하네스 CLI 표기로 전환 | T11, T13, T16, T17, T19 |
| T23 | docs | README · 설정 주석 · 프로젝트 문서의 이행 안내와 끝 상태 반영 | T21 |
| T24 | docs | 이전 명세의 걷힌 경로 서술을 현재형으로 갱신 | T21 |
| T25 | docs | 이식 명세들의 shim · 셸 생성물 서술을 현재형으로 갱신 | T21 |
| T26 | docs | 보호 문서를 명세 13절 범위로 개정 | T21 |

- T1~T7 은 테스트만 고친다. 파일 걷기(T21)에 기대는 테스트 수정이고, shim · 셸 회귀 테스트가 아직 있는 트리에서 통과시킨다
  - T1~T6 은 셸 회귀 테스트 열 개의 검사 줄을 `src/test/unit/` 의 계약 시험으로 옮긴다(명세 12-1). 셸 테스트는 T21 이 지운다
  - T1 이 공용 준비부와 "Python 단위 테스트" 단계의 `paths` 를 둔다
  - T7 은 `render-test.sh` 의 shim 호출 줄과 셸 생성물 내용 검사를 하위 명령 행동 검사로 바꾼다(12-2). 뒤 task 는 이 줄들을 다시 고치지 않는다
- T8 이 `{{HARNESS_CLI}}` 값(4-1), 관리 파일 치환(4-3), 걷힌 경로 대응 상수(4-5)를 둔다
  - T9~T11 이 그 변수로 표기를 바꾼다. 절차 쪽이 T9, 역할 쪽이 T10, 규칙 문서 · forge 명령 사전 · doctor 문구가 T11 이다
  - shim 이 남아 있는 동안 바꾸므로 각 커밋에서 새 표기가 돈다
- T12 는 표기가 바뀐 뒤 옛 허용 규칙을 걷는다
- T13 은 내장 기본값의 표기가 바뀐 뒤(T9)에 사전 판정을 넣는다. 먼저 넣으면 내장 기본값 레이어가 판정에 걸려 모든 render 가 멈춘다
- T14 · T15 · T16 · T18 은 걷힐 파일을 부르던 하네스 안의 자리를 하위 명령으로 옮긴다
  - T14: 가드 · 훅의 판정 값(7-1)
  - T15: 훅 루트와 push 전 · 커밋 뒤 검증(7-3 · 7-5)
  - T16: doctor · fix · schema(9)
  - T18: `script/run-lint-test.sh` 를 관리 파일에서 조건부 생성 파일로(3-1 ~ 3-3)
- T17 은 "하네스 스크립트 회귀" 단계를 없앤다. 셸 회귀 테스트를 지우기(T21) 전에 와야 그 단계가 없는 테스트를 부르지 않는다
- T19 는 새 설치의 CI 원형을 `{{HARNESS_CLI}} verify` 로 바꾼다. 그 뒤 새 설치본에는 `script/run-lint-test.sh` 가 생기지 않으므로, 훅이 그 파일을 부르지 않게 된 뒤(T15)에 온다
- T20 은 `script/README.md` 의 내용을 `docs/workflow/` 로 옮기고 그 파일을 가리키던 자리를 고친다. 파일을 지우기 전에 와야 doctor `references` 가 끊긴 참조를 짚지 않는다
- T21 이 2절의 걷기를 한 번에 한다 — 관리 스크립트 디렉터리 전체, 셸 생성물과 그 생성 함수, 끝 상태를 적는 규칙 문서 3장 끝 · 10장, 끝 상태 회귀 블록
- T22 는 CLI 가 낼 doctor 줄 · schema 키가 정해진 뒤 UI 를 맞춘다. `verification steps` 와 `verify_command` 의 UI 해석은 schema 키를 바꾸는 T16 이 함께 한다
- T23~T25 는 끝 상태를 사람용 문서와 명세에 적는다. T26 이 보호 문서를 고친다

## 착수 순서와 다른 이슈

- **착수 조건**: #209 · #210 · #211 · #212 · #213 · #215 가 `develop` 에 머지되고, 그 여섯이 든 main 릴리스가 한 번 이상 나갔을 것
  - main 릴리스는 develop → main 릴리스 리뷰 요청을 merge commit 으로 머지한 뒤 CI 가 내는 GitHub Release 다
  - `harness preflight` 는 릴리스를 확인하지 않는다. 사람이 확인한다
  - 그 여섯의 선행(#206 · #207 · #208 · #220)은 함께 들어와 있다
- #216 · #217 은 선행이 아니다. 통합 브랜치에 들어와 있으면 이 이슈가 그 기능에 닿는 자리를 함께 바꾼다
  - #216 의 preset 대조가 어긋나거나 읽을 수 없으면 가드 · 훅은 설정을 읽지 못한 것으로 본다(T14)
  - #217 의 CI 게이트는 `{{CI_VERIFY}}` 값과 doctor 줄을 이 이슈의 것으로 쓴다(T19)
- 같은 파일을 건드리는 다른 이슈
  - #214: `src/ui/components/FlowCanvas.js`
  - #216: `docs/spec/216-org-presets.md`
  - #217: `src/templates/ci/` · doctor `verification` 절
  - 위 착수 조건 말고는 동작이 서로 기대지 않는다. 먼저 머지된 쪽 위로 `git fetch -p origin` 뒤 rebase 한다. rebase 뒤 push 는 사람이 한다
- 새 `render-test.sh` 블록 번호는 착수 시점 최대 `UT-<번호>` 다음부터 매긴다. 번호 중복은 회귀 테스트가 막는다

## 브랜치·리뷰 요청·커밋

- 브랜치: `chore/221-retire-shims-and-generated` — 요구사항 이슈 #221 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `chore: 이식 뒤 남은 shim · 셸 생성물 · 옛 허용 규칙 걷기와 최종 명령 표기 전환(#221)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #221` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #221`
- 리뷰 요청 본문에 대응표 둘을 둔다
  - 지운 셸 회귀 테스트 단언과 옮긴 단위 시험의 줄 대응 (T1~T6, 명세 12-1)
  - `render-test.sh` 에서 바꾸거나 지운 줄의 옛 줄 → 새 줄 (T7 과, 동작을 바꾸며 기존 줄을 고친 task, 명세 12-2)

## 전 task 공통 사항

- 테스트의 기대값(종료 코드 · 표준 출력 · 표준 오류 · 남긴 기록 · 페이크 상태 · 파일 상태)은 명세 1절의 "바뀌는 것"에 든 동작을 바꾸는 task 에서만 바뀐다
- 고칠 수 있는 테스트 줄은 정해져 있다. 고친 줄은 리뷰 요청 본문의 대응표에 적는다
  - 준비부 — 샌드박스 배치 · 페이크 주입 · 부르는 진입점
  - shim 자신의 형태 · 문구만 보던 줄
- T21 은 테스트를 둘만 고친다. 설치본의 셸 회귀 테스트를 세어 돌리는 블록(UT-61)을 지우고, 명세 12-3 의 끝 상태 블록을 더한다
- 단위 시험 자리는 `src/test/unit/` 이다. 실행 명령은 `cd src && python3 -B -m unittest discover -s test/unit` 이다(#206 7-5)
  - 내부 로직 시험은 CLI 를 하위 프로세스로 띄우지 않는다
  - 하위 명령의 외부 계약 시험만 예외다. 임시 하네스 루트에 설치한 CLI 를 하위 프로세스로 부른다(12-1)
- 계약 시험과 새 `render-test.sh` 블록은 `HARNESS_HOME` 을 임시 디렉터리로 두고 돈다. 그래서 설치 등록부와 바이트코드 캐시가 이 기기의 것에 닿지 않는다. 시험 뒤 리포 어디에도 `__pycache__` 가 남지 않는다
- 외부 의존은 모두 흉내 낸다. 실제 원격 · forge · 에이전트 CLI 를 부르지 않는다
  - 원격: 로컬 bare 리포
  - forge: `HARNESS_FORGE_FAKE` 로 끼운 `src/test/fake-forge.sh`
  - forge CLI · 에이전트 CLI: PATH 앞 스텁
- 함수 · 상수는 명세가 적은 이름으로 찾는다. 자리는 착수 시점 통합 브랜치의 모듈 지도(#206 3-2)를 따른다
  - `derive()` — `render/derive.py`
  - `plan()` — `render/plan.py`
  - `allow_rules()` — `render/settings.py`
  - `refuse_changes()` — `changes.py`
  - `prune()` — `manifest.py`
  - `doctor_items()` — `readiness/items.py`
  - `REF_OPTIONAL` — `readiness/refs.py`
  - `COMMANDS` — `commands/__init__.py`
  - 설정 값 해석 — `config/values.py`
  - 명령마다 모듈 하나 — `commands/<명령>.py`
- 템플릿 정본(`src/templates/`)을 고친 뒤에는 `src/bin/harness render` 를 돌린다. 이 리포의 생성 · 관리 사본(`.ai/` · `.claude/` · `.codex/` · `script/` · `docs/workflow/` · `CLAUDE.md` · `AGENTS.md`)과 매니페스트가 바뀌고, 그것을 함께 커밋한다
- 이 리포는 소스 리포다
  - 명령 가드 훅이 `src/bin/harness bash-guard` 로 돈다. 가드 · 설정 로더 · 설정 값 해석 모듈을 고치는 순간 작업 세션의 Bash 호출이 그 코드로 판정된다(T14)
  - git 훅은 render 뒤 새 구현으로 돈다(T14 · T15)
- 검증: 커밋 전 `src/bin/harness verify --commit` 이 통과한다
  - #213 의 `verify` 이고 `script/run-lint-test.sh --commit` 과 같은 일을 한다. 그 파일은 T19 뒤 이 리포에서 걷힌다
  - push 전 검증은 pre-push 훅이 돈다
- 현재형 문서(README · `docs/workflow/` · 역할 계약 · 보호 문서 · 명세)가 걷힌 파일을 이름으로 적을 때는 `script/` 를 붙인 백틱 경로로 적지 않는다. 파일 이름만 적거나 `script/<이름>` 꼴로 적는다(11-2 머리)
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다. 동작이 바뀌어 틀리게 된 주석은 그 동작을 바꾸는 task 에서 고친다
- 출력 문구는 명세의 영어 원문 그대로 둔다(ADR 0011). 새 블록의 터미널 출력에도 한글 검사를 적용한다

## 이번 이슈에서 정하지 않는 값

- 계약 시험 모듈과 공용 준비부의 파일 이름 · 모양 — #206 7-5 의 `test_<대상>.py` 규칙 안에서 고른다. 같은 대상의 내부 로직 시험 모듈과 겹치지 않게 한다. 시험 모듈 안에서 설치를 몇 번 하는지도 구현이 고른다
- 걷힌 경로 대응 상수(4-5), 설정 값 판정(6-1), CI 판정(3-1)을 두는 모듈과 이름 — #206 3-4 의 의존 방향 안에서 고른다. 판정 값 함수(7-1)는 설정 값 해석 모듈에 둔다
- 이전 기본값 목록에 더할 #215 판의 글자 — T9 가 바꾸기 직전 `src/templates/defaults.toml` 의 `[workflows.work]` 표를 그대로 옮긴다
- 새 `render-test.sh` 블록의 번호

## 이번 이슈에서 다루지 않는 것

- 옛 agent `work` 경로를 걷는 일 — 옛 단계 조각 다섯, `/work` 관리 커맨드, 이전 기본값 목록과 그 doctor 항목, `harness fix legacy-work` (명세 14). 이 이슈에서는 표기만 바뀐다
- `script/harness.plan.json` 걷기 — #207
- CI 게이트를 생성물로 바꾸는 일 — #217
- 이미 깔린 소유 CI 파일과 소유 원형 사본(`script/project/README.md` 등)의 수정 — 프로젝트 것이다(ADR 0002)
- 결정 기록 본문의 `script/…` 경로 — 그 시점의 관측이다
- `.claude/settings.local.json` 에 사람이 승인해 둔 옛 규칙 — 커밋하지 않는 개인 파일이다
- 프로젝트 스크립트가 옛 `script/forge.sh` · `script/harness.env` 를 source 하던 경우의 탐지 (명세 16)
- 가드가 Bash 호출마다 설정을 읽는 지연의 측정 (명세 16)
