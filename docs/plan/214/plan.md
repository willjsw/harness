# #214 분해 — UI 블록 편집

명세: [`docs/spec/214-ui-block-editor.md`](../../spec/214-ui-block-editor.md)
결정 기록: 없음

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | schema 에 블록 목록·끝 상태·와일드카드·실행 방식 목록과 절차별 커맨드 추가 | 없음 |
| T2 | feat | steps --dry-run --json 으로 검사 결과와 단계별 outcome·실효 배선·오류 위치 출력 | 없음 |
| T3 | feat | 절차 그래프 변환·자동 배치 순수 함수 모듈 flow.js 추가 | 없음 |
| T4 | feat | Workflows 캔버스가 검사 결과의 실효 배선으로 선·outcome 핸들·끝 상태를 그리고 오류 위치 표시 | T1, T2, T3 |
| T5 | feat | 블록 팔레트와 단계 패널을 schema 의 블록·단계 키·입력 종류로 구성 | T1, T4 |
| T6 | feat | outcome 핸들 잇기·다시 잇기·끊기와 패널 Next 절로 배선 편집 | T4, T5 |
| T7 | feat | 절차 실행 방식 선택과 실행 방식에 따른 커맨드 표기 | T3, T4, T5 |
| T8 | feat | 하위 절차 블록에서 그 절차로 이동과 돌아오기 | T5 |
| T9 | feat | 아래 레이어 절차의 읽기 전용 표시와 프로젝트로 분리 | T4, T6, T7 |
| T10 | docs | README 명령 표와 UI 표에 블록 편집·검사 JSON 반영 | T1–T9 |
| T11 | docs | 담당 범위·아키텍처·용어·테스트 문서에 UI 블록 편집 반영 | T1–T9 |

- CLI(T1 · T2)가 UI(T4–T9)보다 먼저다. UI 는 CLI 를 서브프로세스로 부를 뿐이고 반대 방향 의존은 없다
- T1 · T2 는 #208 의 정의와 계산 함수(블록 정의 · 단계 키 정의 · 끝 상태 · outcome 집합 · 실효 배선 · 시작 단계 · render 검증)를
  그대로 부른다. schema 와 `--json` 용으로 같은 표나 계산을 따로 두지 않는다(명세 2-1 · 2-3)
- T3 은 React 를 import 하지 않는 순수 함수다. 입력 모양은 명세 2-3 의 `wiring` · `start` · `steps` 이므로 CLI 구현을 기다리지 않는다.
  `nodeW` 를 `FlowCanvas.js` 에서 옮기는 것만 화면 코드를 건드린다
- T4–T9 는 모두 `src/ui/components/FlowCanvas.js` 를 고친다. 서로 겹치는 줄이 많으므로 표의 순서대로 한 브랜치에서 차례로 커밋한다
  - T4 가 검사 결과(`--dry-run --json`)로 그리는 바탕을 놓는다 — 서버 액션(명세 5-1), 선 · 핸들 · 끝 상태 · 자동 배치 · 오류 위치,
    검사 결과와 그것을 부른 편집 상태의 짝
  - T5 가 블록과 단계 키를 schema 에서 받는다. T6 은 T4 의 핸들과 T5 의 패널 위에 배선 편집을 얹는다
  - T7 이 실행 방식을 편집 상태에 넣는다. T4–T6 은 저장된 절차의 `schema.workflows.<절차>.execute`(초안은 `schema.execute.default`)를
    편집 중인 실행 방식으로 쓴다
  - T9 는 T4–T8 이 만든 조작 가운데 읽기 전용에서 빠지는 것(명세 3-1)을 걷는다. 그래서 편집 조작을 모두 만든 뒤에 온다
- 명세 3-4(옛 고정 사본)는 둘로 나뉜다. `schema.blocks` 가 없을 때 `--dry-run --json` 을 부르지 않고 단계 순서대로 선을 긋는 것은
  T4, 읽기 전용과 재설치 안내는 T9 다
- 명세 6절의 도움말 두 줄은 그것을 보이는 화면 task 가 넣는다 — `workflow.execute` 는 T7, `workflow.source` 는 T9. README 는 T10 이다
- T10 · T11 은 T1–T9 가 만든 동작을 문서에 적는다. 둘은 서로 기대지 않는다

## 착수 순서와 다른 이슈

- 착수 조건: #208 이 `develop` 에 머지된 뒤 착수한다. #208 의 선행인 #206(CLI 패키지) · #207(설정 계층)도 그때 들어 있다
- 명령 코드의 자리는 #206 의 모듈 지도다 — `harness schema` 는 `src/harness/commands/schema.py`, `harness steps` 는
  `src/harness/commands/steps.py`, 공용 옵션 `--json` 의 도움말은 `src/harness/cli.py`, 단계 키 정의와 outcome · 배선 계산은
  #208 의 `src/harness/workflow/`
- 절차의 출처 레이어는 #207 이 schema 에 내는 `sources` 의 `workflows.<절차>` 값이고, 레이어 이름표는 #207 이 `src/ui/lib/labels.js` 에 둔
  레이어 이름표 함수다
- #216 과는 머지 순서가 정해지지 않았다. #216 은 레이어 이름표 함수를 레이어 id 와 `schema.layers` 를 받게 바꾸고 그 호출부를 고친다(#216 6-1)
  - 이 이슈가 먼저 머지되면 #216 이 T9 의 캔버스 호출부를 고친다
  - #216 이 먼저 머지되면 이 이슈가 rebase 할 때 T9 의 호출부가 #216 의 인자로 부른다
- #212 와는 순서가 없다. #212 가 먼저 머지되면 기본 `work` · `review-loop` 가 driver 절차로 보이고, 출처가 아래 레이어이므로 읽기 전용이며,
  `work` 의 workflow 블록에서 `review-loop` 로 이동한다(명세 9절). #212 는 단계 키를 더하지 않는다
- #221 은 `FlowCanvas.js` 의 script 명령 입력 자리표시 글을 바꾼다. 먼저 머지된 쪽 위로 `git fetch -p origin` 뒤 rebase 한다.
  rebase 뒤 push 는 사람이 한다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/214-ui-block-editor` — 요구사항 이슈 #214 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: UI 에서 블록을 이어 분기·루프가 있는 절차를 만들고 저장(#214)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #214` 와 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #214`

## 전 task 공통 사항

- CLI 는 표준 라이브러리만 쓴다. 터미널 출력은 영어이고, 명세가 적은 영어 원문(`error: steps takes --json only with --dry-run`, `--json` 도움말)을
  그대로 쓴다. `render-test.sh` 의 한글 검사가 새 블록의 출력에도 돈다
- 명령 모듈은 다른 명령 모듈을 부르지 않는다(#206 의 의존 방향). schema 와 steps 가 함께 쓰는 판정은 공용 모듈(#208 의 `workflow/`,
  render 자리)에서 부른다
- 생성 파일도 설정 키도 늘지 않는다. `plan()` 에 등록할 것이 없고, `src/bin/harness render` 뒤 `harness check` 가 어긋남 없이 통과한다
- UI 는 파일 경로 · 블록 종류 · outcome · 배선 해석 · 검사 규칙을 짓지 않는다. 블록 · 단계 키 · 입력 종류 · 끝 상태 · 실행 방식은
  `harness schema`, 단계별 outcome · 실효 배선 · 시작 단계 · 오류 위치는 `harness steps --dry-run --json` 에서 받는다
- 설정 쓰기는 `harness steps` 하나다(절차 메모는 지금처럼 `harness write-doc`). UI 에서 `fs.writeFile` · `fs.mkdir` 를 새로 두지 않는다
- UI 순수 함수는 `src/ui/lib/` 에 두고 `<모듈>.test.js` 로 단위 테스트한다(`node --test`). 화면과 서버 액션은 자동 테스트가 없으므로
  완료 조건의 화면 동작은 손으로 확인하고, 단위 테스트 항목에 "(손 확인)" 으로 적는다
- 화면의 단추 · 이름표는 명세의 영어 원문(`Separate into Project` · `Start` · `Open <절차>` 등), 안내 문장은 명세의 한국어 원문 그대로다
- `render-test.sh` 의 새 블록은 기존 `UT-<번호>` 형식을 따르고 번호는 구현 시점의 다음 번호다. T1 이 새 블록을 만들고 T2 가 같은 블록에 케이스를 더한다
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다. 동작이 바뀌어 틀리게 된 주석은 그 동작을 바꾸는 task 에서 고친다
- 커밋 전 `script/run-lint-test.sh --commit` 이 통과한다

## 이번 이슈에서 정하지 않는 값

- workflow 블록의 아이콘 — 명세는 이름표(`Run Workflow`)만 정한다
- 실행 방식을 바꿀 때 여는 확인 대화상자의 제목 · 단추 문구 — 명세는 보일 내용(단계별로 지울 키 이름)만 정한다
- 자동 배치의 간격 · 고정 줄 높이 값, 오류 색 · 빈 핸들 표지 · 점선의 모양 — 명세는 배치 규칙과 선 종류만 정한다
- `flow.js` 에서 명세 5-2 표 밖의 도움 함수, React Flow 의 사용자 정의 노드 · 선 · 핸들 컴포넌트의 이름과 나눔
- 입력 종류를 단계 키 정의 옆에 두는 자료 구조의 이름 — 명세는 `src/harness/workflow/` 의 단계 키 정의 옆이라는 자리만 정한다

## 이번 이슈에서 다루지 않는 것

- 분리한 절차를 아래 레이어로 되돌리는 UI 동작 — 프로젝트 `harness.toml` 에서 그 절을 지운다(명세 10절)
- `harness steps` 를 직접 불러 아래 레이어 절차를 교체하는 것을 막는 일 — 읽기 전용은 UI 의 동작이다
- 여러 오류를 한 번에 보이기 — 검사는 첫 오류만 알린다
- 저장하지 않은 하위 절차 편집을 상위 절차 핸들에 반영하기
- 노드 높이를 재는 배치
- 입력 종류가 `fixed` 인 키(표 값)와 `max_steps` · `max_visits` 같은 절차 키의 UI 편집
- 구조화 출력 스키마 파일 작성 — 있는 스키마를 고르기만 한다
- preset 레이어 id 와 그 표시 이름 — #216
- Procedure 보기에서 Mermaid 를 그림으로 그리기 — 그래프 그림은 Canvas 보기가 그린다
