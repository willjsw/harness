# #214 task

## T1 · feat: schema 에 블록 목록·끝 상태·와일드카드·실행 방식 목록과 절차별 커맨드 추가

### 상위 Requirement

- relates to #214

### 작업 내용

UI 가 블록 팔레트 · 단계 패널 · 끝 상태 노드 · 실행 방식 선택 · 커맨드 표기를 CLI 에서 받도록 `harness schema` 에 키를 더한다.
값은 모두 #208 의 정의(블록 정의 · 단계 키 정의 · 끝 상태 · 실행 방식별 허용 키)에서 만든다. schema 용으로 같은 표를 따로 두지 않는다.

- 명세 2-1 · 2-2 · 7-1 의 첫 두 행
- `blocks`: #208 의 블록 정의 순서로 블록마다 `{ "type", "keys" }`
  - `keys` 는 그 블록이 받는 단계 키에서 `id` · `type` · `title` · `next` 를 뺀 것이고, 순서는 #208 의 단계 키 정의 순서다.
    항목은 `{ "key", "input", "execute", "choices" }` 이고 `choices` 는 `input` 이 `choice` 일 때만 있다
  - `input` 은 #208 의 단계 키 정의 옆에 둔 입력 종류다. 단계 키 정의의 모든 키에 입력 종류가 있고, 블록마다 뜻이 다른 키(`on`)는
    블록별로 둔다. 입력 종류가 없는 키를 `keys` 에서 빼지 않는다 — 빠진 입력 종류가 회귀 테스트에 드러나야 한다
  - 입력 종류는 #208 2-2 의 값 모양을 명세 2-2 의 어휘로 옮긴 것이다

    | 키 | 블록 | `input` | `choices` |
    |---|---|---|---|
    | `text` | 다섯 블록 | `markdown` | |
    | `run` | script | `command` | |
    | `role` | agent | `role` | |
    | `workflow` | workflow | `workflow` | |
    | `schema` | agent | `output_schema` | |
    | `on` | script | `choice` | `exit` · `stdout` |
    | `on` | agent | `schema_field` | |
    | `access` | prompt | `choice` | `read-only` · `write` |
    | `options` | gate | `list` | |
    | `set` | script · agent | `fixed` | |

  - `execute` 는 그 키를 받는 실행 방식들이다. #208 이 agent 절차에서 거부하는 키(driver 전용)는 `["driver"]`, 나머지는 `["agent", "driver"]`
- `ends`: #208 의 끝 상태 — `["done", "stop", "handoff"]`
- `wildcard`: `"*"`
- `execute`: `{ "default", "modes" }`
  - `default` 는 #208 의 기본 실행 방식(`agent`)이다
  - `modes` 는 #208 의 실행 방식마다 `{ "value", "wiring", "command" }` 다. `wiring` 은 그 실행 방식의 절차가 `next` 를 받는지(agent 거짓 ·
    driver 참), `command` 는 프로젝트가 만든 그 실행 방식의 절차에 render 가 슬래시 커맨드를 만드는지(agent 참 · driver 거짓)다
- `workflows.<절차>.command`: render 가 그 절차를 부르는 커맨드 파일(생성 파일이든 관리 파일이든)을 대상 리포에 두면 그 이름(`/` 없이),
  두지 않으면 `null`
  - 판정은 render 의 것을 그대로 부른다 — 프로젝트 절차의 커맨드 생성 조건(`plan()`), 기본 절차의 관리 커맨드 설치 판정(#208 10절).
    schema 에서 따로 판정하지 않는다. 명령 모듈끼리 부르지 않으므로 그 판정은 render 자리의 공용 함수로 둔다
- 기존 키와 #208 이 내는 `output_schemas` · `workflows.<절차>.execute` 는 그대로 둔다
- `render-test.sh` 에 새 `UT-<번호>` 블록을 만들고 명세 7-1 의 첫 두 행을 넣는다. T2 가 같은 블록에 케이스를 더한다
- 건드릴 파일: `src/harness/workflow/`(단계 키 정의 옆의 입력 종류), `src/harness/commands/schema.py`(`cmd_schema`),
  커맨드 판정을 공용으로 부르는 render 자리(`src/harness/render/`), `src/test/render-test.sh`

### 완료 조건

- [ ] `harness schema` 출력에 `blocks` · `ends` · `wildcard` · `execute` 가 있고 `workflows` 의 절차마다 `command` 가 있다
- [ ] `blocks` 의 블록 순서와 키 순서가 #208 의 블록 정의 · 단계 키 정의 순서와 같고, `keys` 에 `id` · `type` · `title` · `next` 가 없다
- [ ] 모든 블록의 모든 키에 `input` 이 있고 명세 2-2 의 어휘(`role` · `command` · `markdown` · `line` · `list` · `choice` · `workflow` ·
  `output_schema` · `schema_field` · `fixed`) 안에 있다. `choice` 키에만 `choices` 가 있다
- [ ] driver 전용 키의 `execute` 가 `["driver"]` 이고 나머지 키는 두 실행 방식을 모두 담는다
- [ ] `execute.default` 가 `agent` 이고, `modes` 가 agent(`wiring` 거짓 · `command` 참)와 driver(`wiring` 참 · `command` 거짓)다
- [ ] 프로젝트가 만든 agent 절차의 `command` 가 그 이름이다. 프로젝트 driver 절차, 하위 절차인 프로젝트 agent 절차, 커맨드 파일이 없는
  기본 절차, driver 로 둔 기본 절차는 `null` 이다
- [ ] `execute` 키가 없는 절차의 `workflows.<절차>.execute` 가 `execute.default` 와 같다
- [ ] 기존 schema 키의 값이 그대로다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/214-ui-block-editor` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 블록 편집 표 | 기본 설정에서 `harness schema` | `blocks` · `ends` · `wildcard` · `execute` 가 있다. 블록 · 키 순서가 #208 정의 순서이고 `id` · `type` · `title` · `next` 가 `keys` 에 없다 |
| UT-02 | 입력 종류 어휘 | 같은 출력의 `blocks[].keys[]` 전부 | 모두 `input` 이 있고 2-2 어휘 안이다. `choices` 는 `choice` 키에만 있다 |
| UT-03 | 실행 방식별 키 | 같은 출력의 driver 전용 키와 그 밖의 키 | driver 전용 키는 `["driver"]`, 나머지는 `["agent", "driver"]` |
| UT-04 | 실행 방식 목록 | 같은 출력의 `execute` | `default` 가 `agent`, `modes` 가 agent(`wiring` 거짓 · `command` 참) · driver(`wiring` 참 · `command` 거짓) |
| UT-05 | 절차별 커맨드 | 프로젝트 agent 절차 · 프로젝트 driver 절차 · 하위 절차인 프로젝트 agent 절차 · 커맨드 파일이 없는 기본 절차 · driver 로 둔 기본 절차 | 첫째만 그 이름, 나머지는 `null`. 각 경우 render 가 둔 `.claude/commands/` 파일 유무와 맞는다 |
| UT-06 | 기본 실행 방식 | `execute` 키가 없는 절차 | `workflows.<절차>.execute` 가 `execute.default` 와 같다 |

## T2 · feat: steps --dry-run --json 으로 검사 결과와 단계별 outcome·실효 배선·오류 위치 출력

### 상위 Requirement

- relates to #214

### 작업 내용

편집 중인 캔버스가 선 · 핸들 · 오류 위치를 그릴 근거를 CLI 에서 받도록 `harness steps <절차> <JSON> --dry-run --json` 을 둔다.
설정 파일을 쓰지 않는다.

- 명세 2-3 · 2-4 · 7-1 의 셋째 행부터 끝까지
- 인자
  - `--json` 은 `--dry-run` 과 함께일 때만 받는다. 아니면 종료 코드 2 와 `error: steps takes --json only with --dry-run` 이고 설정 파일을 건드리지 않는다
  - 공용 옵션 `--json` 의 도움말을 `doctor: print the items as one JSON object; steps --dry-run: print the check as one JSON object` 로 바꾼다
- 입력 JSON 이 형식을 어기면 지금 문장 그대로 거부한다(종료 코드 2). JSON 을 내지 않는다
- 그 밖에는 표준 출력에 JSON 객체 하나를 내고 표준 오류는 비운다. 종료 코드는 검사가 통과하면 0, 거부하면 2 다
- 키는 명세 2-3 의 표다 — `ok` · `error` · `at` · `wiring` · `start` · `steps[]`(`id` · `outcomes` · `open` · `next`)
  - 검사는 텍스트 `--dry-run` 과 같은 함수에 같은 입력을 준다. 하위 절차는 저장된 설정의 그 절차다
  - 검사 중 표준 오류로 가던 문장을 모아 `error` 에 넣는다(거부한 첫 오류 문장의 원문, 여러 줄일 수 있다). 통과하면 `error` 는 null 이고 모인 경고는 내지 않는다
  - `at` 은 `error` 의 첫 위치 표기(#208 6절)에서 읽는다 — `step` 은 `steps[<i>]` 의 번호, `outcome` 은 `next[…]` 안의 JSON 문자열을 푼 값이다.
    outcome 표기가 없으면 `outcome` 이 null, 위치 표기가 없으면 둘 다 null 이다. 통과하면 `at` 이 null 이다
  - `wiring` · `start` · `steps[].outcomes` · `steps[].next` 는 #208 의 배선 판정 · 시작 단계 · outcome 집합 · 실효 배선 함수를 그대로 부른다.
    실행 방식과 상관없이 같은 함수다. 검사가 거부해도 낸다
  - outcome 집합을 계산할 수 없는 단계(모르는 블록 · 없는 스키마 · 없는 하위 절차)는 `outcomes: []` · `open: true` 다. script 단계는 `open: true` 다.
    실효 배선을 계산할 수 없는 단계는 `next` 키가 없다
- `render-test.sh` 의 T1 블록에 명세 7-1 의 셋째 행부터 끝까지 — 검사 JSON 다섯 행, `--json` 단독, 형식 오류, 객체 형식 왕복 — 를 더한다
- 건드릴 파일: `src/harness/commands/steps.py`(`cmd_steps`), `src/harness/cli.py`(공용 옵션 도움말), `src/test/render-test.sh`

### 완료 조건

- [ ] 통과하는 명시 배선 절차의 검사가 종료 코드 0, `ok` 참, `error` · `at` null, `wiring` 이 `explicit`, `start` 가 첫 단계 id 이고 단계별 `outcomes` · `open` · `next` 를 낸다. 설정 파일 바이트가 그대로다
- [ ] `next` 가 없는 절차에서 `wiring` 이 `implicit` 이고 단계마다 `next` 가 #208 의 암묵 배선을 펼친 값이다
- [ ] gate 의 `outcomes` 는 `options`, 스키마와 `on` 을 고른 agent 는 그 필드의 열거값(#208 의 outcome 집합), 저장된 하위 절차를 부르는 workflow 는
  `done` · `stop` · `handoff` 이고, script 는 `open` 이 참이다
- [ ] 거부하는 입력에서 종료 코드 2, 표준 출력은 JSON 하나, 표준 오류는 비어 있고, `error` 가 같은 입력의 텍스트 `--dry-run` 표준 오류와 같으며 `steps` 가 있다
- [ ] 없는 대상을 가리키는 outcome 의 `at` 이 그 단계 번호와 outcome 키이고, `.` 이 든 outcome 이름도 그대로다. 단계 위치만 있는 오류는 `at.outcome` 이 null,
  `execute` 값이 틀린 절차는 `at.step` · `at.outcome` 이 둘 다 null 이다
- [ ] `--dry-run` 없는 `--json` 이 종료 코드 2 와 정해진 문구이고 설정 파일이 그대로다
- [ ] 형식이 틀린 입력은 `--json` 이어도 종료 코드 2 이고 표준 출력이 비어 있다
- [ ] `{title, execute, steps}` 로 저장한 뒤 `harness steps` 가 낸 단계(`builtin` · `body` 를 뺀 것)와 schema 의 `title` · `execute` 가 넘긴 값과 같다
- [ ] 텍스트 `--dry-run` 의 출력과 종료 코드가 그대로다
- [ ] 터미널 출력에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/214-ui-block-editor` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 통과한 명시 배선 | 모든 단계에 `next` 가 있고 성립하는 driver 절차 | 종료 코드 0, `ok` 참, `wiring` `explicit`, `start` 첫 단계, 단계별 `outcomes` · `open` · `next`, 설정 파일 바이트 그대로 |
| UT-02 | 암묵 배선 펼치기 | `next` 가 없는 절차 | `wiring` `implicit`, 단계마다 암묵 배선을 펼친 `next` |
| UT-03 | 블록별 outcome | gate · 스키마와 `on` 을 고른 agent · 저장된 하위 절차를 부르는 workflow · script 가 든 절차 | 선택지 · 필드 열거값 · 끝 상태 셋 · script `open` 참 |
| UT-04 | 계산할 수 없는 단계 | 모르는 블록 · 없는 스키마 · 없는 하위 절차 | 그 단계 `outcomes: []` · `open: true`, 종료 코드 2 이고 `steps` 가 있다 |
| UT-05 | 거부 알림 | 성립하지 않는 절차 | 종료 코드 2, 표준 출력 JSON 하나, 표준 오류 빔, `error` 가 텍스트 `--dry-run` 표준 오류와 같음 |
| UT-06 | 오류 위치 | 없는 대상 outcome · `.` 든 outcome 이름 · 단계 위치만 있는 오류 · 틀린 `execute` | `at` 이 각각 (번호, 키) · (번호, 그 이름) · (번호, null) · (null, null) |
| UT-07 | `--json` 단독 | `--dry-run` 없이 `--json` | 종료 코드 2, `error: steps takes --json only with --dry-run`, 설정 파일 그대로 |
| UT-08 | 형식 오류 | JSON 이 아닌 입력에 `--dry-run --json` | 종료 코드 2, 표준 출력 빔 |
| UT-09 | 객체 형식 왕복 | `{title, execute, steps}` 로 저장 | `harness steps` 단계와 schema 의 `title` · `execute` 가 넘긴 값과 같다 |

## T3 · feat: 절차 그래프 변환·자동 배치 순수 함수 모듈 flow.js 추가

### 상위 Requirement

- relates to #214

### 작업 내용

캔버스가 그릴 핸들 · 선 · 노드 위치와 배선 편집 결과를 계산하는 순수 함수를 `src/ui/lib/flow.js` 에 둔다.
React 와 `@xyflow/react` 를 import 하지 않고, 입력을 바꾸지 않고 새 값을 돌려준다. React Flow 의 노드 · 선 객체로 바꾸는 일은 `FlowCanvas.js` 의 몫이다.

- 명세 5-2 · 4-2(핸들 순서) · 4-3(선) · 4-4(펼치기 · 잇기 · 끊기) · 4-5(자동 배치) · 4-8(받지 않는 키) · 7-2
- `outline` 은 명세 2-3 의 `wiring` · `start` · `steps` 이고, 실효 배선은 `outline.steps[].next` 다. `mode` 는 `schema.execute.modes` 의 항목이다
- 함수
  - `nodeW(step)` — `FlowCanvas.js` 의 노드 폭 계산(스크립트 명령 길이에 따라 넓히고 상한이 있다)을 그 상수와 함께 옮긴다. 폭 값은 그대로이고
    `FlowCanvas.js` 는 이것을 import 한다
  - `handles(step, outline, wildcard)` — 그 단계의 `outcomes` → 단계의 `next` 에 있으나 그 목록에 없는 키(키 순서) → `wildcard`. 같은 키는 한 번
  - `edgesOf(steps, outline, { wiring })` — 선마다 출발 단계 · outcome · 대상 · 점선 여부
    - 배선을 받지 않는다: 단계마다 실효 배선의 대상 가운데 `stop` 이 아닌 서로 다른 대상마다 한 선, 점선, outcome 이름표 없음
    - 배선을 받고 암묵 배선: 대상이 `stop` 이 아닌 outcome 마다 한 선, 점선
    - 배선을 받고 명시 배선: `next` 의 outcome 마다 한 선, 실선
    - 자기 자신으로 가는 선도 낸다
  - `layout(steps, edges, ends, start)` — 노드 id → 위치. 명세 4-5 의 층 규칙(시작 단계 층 0, 앞으로 가는 선만 층에 쓰고, 받지 않으면 바로 앞 단계 층 + 1),
    같은 층은 목록 순서로 위에서 아래 · 층마다 세로 가운데, 층의 가로 위치는 앞 층들의 가장 넓은 노드 폭과 간격의 합, 끝 상태는 마지막 단계 층 다음 층에
    `ends` 순서로. 노드 높이는 재지 않고 고정 줄 높이를 쓴다
  - `expand(steps, outline)` — 실효 배선을 모든 단계의 `next` 로 펼친 목록. 실효 배선이 없는 단계는 `next` 없이 둔다
  - `connect(steps, id, outcome, target)` · `disconnect(steps, id, outcome)` — `next` 한 칸을 바꾸거나 뺀 목록. 마지막 칸을 빼도 `next` 는 빈 표로 남는다
  - `strip(steps, mode, blocks)` — 실행 방식이 받지 않는 키(배선을 받지 않는데 있는 `next`, `blocks[].keys[].execute` 에 그 실행 방식이 없는 키)를
    걷은 목록과 걷은 것(단계 id → 키 이름들)
- `src/ui/lib/flow.test.js` 에 명세 7-2 의 케이스를 넣는다
- 건드릴 파일: `src/ui/lib/flow.js`(새 파일), `src/ui/lib/flow.test.js`(새 파일), `src/ui/components/FlowCanvas.js`(`nodeW` 를 import 로 바꾼다)

### 완료 조건

- [ ] `flow.js` 가 React · `@xyflow/react` 를 import 하지 않는다
- [ ] 명세 7-2 의 케이스가 모두 통과한다
- [ ] 모든 함수가 입력을 바꾸지 않는다 — 테스트가 호출 전 깊은 사본과 호출 뒤 입력을 비교한다
- [ ] `FlowCanvas.js` 에 노드 폭 계산이 남아 있지 않고, 캔버스의 노드 폭이 옮기기 전과 같다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/214-ui-block-editor` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 핸들 순서 | `outcomes` 와 겹치는 키 · `next` 에만 있는 키 · `"*"` 가 든 단계 | 알려진 outcome → `next` 에만 있는 키 → 와일드카드, 중복 없음 |
| UT-02 | 배선을 받지 않는 선 | 대상이 겹치는 outcome 과 `stop` 대상이 있는 단계 | 단계마다 `stop` 이 아닌 서로 다른 대상에 하나, 이름표 없음, 점선 |
| UT-03 | 암묵 배선 선 | `wiring` `implicit` outline | `stop` 으로 가는 outcome 의 선이 없다, 점선 |
| UT-04 | 명시 배선 선 | `wiring` `explicit` outline, `stop` · 자기 자신 대상 포함 | `next` 의 모든 칸이 선, 실선 |
| UT-05 | 직선 배치 | 암묵 배선 직선 절차 | 한 줄이고 x 가 목록 순서로 커진다 |
| UT-06 | 분기 배치 | 한 단계에서 두 단계로 가는 선 | 두 대상이 같은 층에서 목록 순서로 위에서 아래 |
| UT-07 | 뒤로 가는 선 | 뒤 단계에서 앞 단계로 가는 선을 더한 절차 | 층이 바뀌지 않는다 |
| UT-08 | 이어 주는 선 없는 단계 | 앞으로 가는 선을 받지 않는 단계 | 앞 단계 층 + 1 |
| UT-09 | 끝 상태 배치 | 끝 상태 둘 이상 | 마지막 단계 층 다음 층에 `ends` 순서 |
| UT-10 | 결정성 | 같은 입력 두 번 | 같은 출력 |
| UT-11 | 펼치기 | 실효 배선이 있는 단계와 없는 단계 | 있는 단계는 `next` 가 채워지고 없는 단계는 `next` 가 없다. 입력 목록 그대로 |
| UT-12 | 잇기 · 끊기 | 대상 바꾸기 · 칸 빼기 · 마지막 칸 빼기 | 대상이 바뀌고 빠지며 마지막 칸을 빼면 `next` 가 빈 표, 다른 단계 그대로 |
| UT-13 | 받지 않는 키 걷기 | `next` · driver 전용 키가 든 단계와 agent 실행 방식 | `next` 와 `execute` 에 agent 가 없는 키를 걷고, 걷은 목록이 단계 id → 키 이름들로 맞다 |

## T4 · feat: Workflows 캔버스가 검사 결과의 실효 배선으로 선·outcome 핸들·끝 상태를 그리고 오류 위치 표시

### 상위 Requirement

- relates to #214

### 작업 내용

캔버스의 선을 단계 순서가 아니라 CLI 가 계산한 실효 배선에서 그리고, 검사 결과의 위치로 노드 · 선 · 핸들에 오류를 붙인다.
검사와 저장은 명세 2-5 의 객체를 넘긴다.

- 명세 5-1 · 2-5 · 4-2 · 4-3 · 4-5 · 4-10 · 4-12, 3-4 의 선 긋기
- 서버 액션(5-1)
  - `harness(dir, args, { json })` — `json` 이 참이면 종료 코드와 상관없이 표준 출력만 JSON 으로 읽어 `{ ok, data }` 를 돌려준다. 읽지 못하면 `{ ok: false, out }` 이다
  - `checkSteps(project, workflow, payload)` 는 `harness steps <절차> <JSON> --dry-run --json`, `saveSteps(project, workflow, payload)` 는
    `harness steps <절차> <JSON>` 을 부른다. 단계에서 `builtin` · `body` 를 빼는 일은 두 액션이 한다
  - 객체(2-5): `title` 은 초안이면 새 절차 대화상자의 값, 저장된 절차면 `schema.workflows.<절차>.title` 이고 비어 있으면 넣지 않는다.
    `execute` 는 편집 중인 실행 방식이 `schema.execute.default` 와 다를 때만 넣는다. `steps` 의 나머지 키는 그대로다
- 편집 중인 실행 방식은 저장된 절차면 `schema.workflows.<절차>.execute`, 초안이면 `schema.execute.default` 다. "배선을 받는 절차" 는
  그 실행 방식의 `schema.execute.modes[].wiring` 이 참인 절차다
- 검사(4-10)
  - 부르는 때는 절차를 열 때와 편집이 멈춘 뒤(400ms)다. 단계가 없는 초안은 부르지 않는다. 늦게 온 옛 결과는 버린다
  - 결과에 그 검사를 부른 편집 상태를 함께 둔다. T6 이 이 짝으로 결과 대기(4-4)를 판정한다
  - `at.step` 이 있으면 그 노드에 오류 표지와 문장 첫 줄, `at.outcome` 도 있으면 그 outcome 의 선을 오류 색으로, 선이 없으면 그 핸들을 오류 색으로 그린다
  - 위치가 없는 오류와 JSON 을 읽지 못한 결과(`{ ok: false, out }`)는 패널의 단계 목록 위에 보인다
  - 상태 표시(`Checking…` · `Valid` · `Saved` · `1 error`)는 지금과 같고, 열 때 검사가 거부하면 `1 error` 다
  - 정규식으로 위치를 찾는 `locate` 를 지운다
- 노드와 핸들(4-2)
  - 단계 노드의 머리와 본문은 지금과 같고, 시작 단계(결과의 `start`)에 `Start` 표지를 붙인다
  - 들어오는 핸들은 노드마다 왼쪽에 하나다
  - 나가는 핸들: 배선을 받지 않는 절차는 노드마다 오른쪽에 하나, 받는 절차는 `handles()` 순서로 outcome 마다 하나를 오른쪽에 세로로 놓고 outcome
    이름표를 붙인다. 이어지지 않은 핸들은 빈 표지다
  - 끝 상태 노드는 `schema.ends` 의 상태마다 하나이고 들어오는 핸들만 있다. 명시 배선이면 셋 다 늘 보이고, 그 밖에는 그리는 선이 닿는 것만 보인다
- 선(4-3)은 `edgesOf()` 결과를 React Flow 선으로 바꿔 그린다 — 점선 · 실선, outcome 이름표, 고리와 자기 자신으로 가는 선.
  암묵 배선이면 캔버스 아래에 `암묵 배선 — 선이 없는 outcome 은 stop 으로 간다` 한 줄을 보인다
- 배치(4-5)는 `layout()` 이다. 위치를 저장하지 않는다. 절차를 바꾸거나 단계 수가 바뀌면 화면을 맞춘다
- 옛 고정 사본(3-4): `schema.blocks` 가 없으면 `--dry-run --json` 을 부르지 않고 단계 순서대로 이은 선을 그린다. 읽기 전용과 재설치 안내는 T9 다
- Procedure 보기(4-12)는 지금 마크다운 렌더러로 그린다. driver 절차 문서의 Mermaid 블록이 코드 블록으로, 다음 표가 GFM 표로 보이는 것을 확인한다
- 건드릴 파일: `src/ui/lib/harness.js`, `src/ui/lib/actions.js`, `src/ui/components/FlowCanvas.js`, `src/ui/app/globals.css`

### 완료 조건

- [ ] `FlowCanvas.js` 에 단계 순서로 선을 만드는 코드와 `locate` 가 없다
- [ ] 저장된 절차를 열면 `--dry-run --json` 이 불리고, 통과면 `Saved`, 거부면 `1 error` 다
- [ ] agent 절차에서 노드마다 오른쪽 핸들 하나, `stop` 이 아닌 대상으로 가는 점선, 선이 닿는 끝 상태 노드만 보이고 가로 한 줄이다
- [ ] driver 명시 배선 절차에서 outcome 핸들이 4-2 의 순서와 이름표로 놓이고, 실선 · 끝 상태 셋 · 고리 · 자기 자신 선 · `Start` 표지가 보이며 4-5 대로 층이 나뉜다
- [ ] driver 암묵 배선 절차에서 `stop` 으로 가는 outcome 에 선이 없고 캔버스 아래 안내 줄이 보인다
- [ ] 없는 대상을 가리키는 outcome 이 있으면 그 노드에 오류 표지가 붙고 그 선(없으면 핸들)이 오류 색이다. 절차 전체의 오류는 단계 목록 위에 보인다
- [ ] 저장과 검사에 넘기는 객체가 2-5 형식이다 — 초안 제목이 들어가고, 기본 실행 방식이면 `execute` 가 없다
- [ ] `schema.blocks` 가 없는 고정 사본에서 `--dry-run --json` 을 부르지 않고 순서대로 이은 선이 보인다
- [ ] Procedure 보기에서 driver 절차 문서의 Mermaid 블록이 코드 블록, 다음 표가 표로 보인다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/214-ui-block-editor` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 열 때 검사 | 저장된 성립 절차 · 성립하지 않는 절차 열기 | `Saved` · `1 error` (손 확인) |
| UT-02 | agent 절차 그리기 | 기본 `prework` | 노드마다 핸들 하나, 점선, 가로 한 줄 (손 확인) |
| UT-03 | 명시 배선 그리기 | 분기 · 루프 · 자기 자신 배선이 든 driver 절차 | outcome 핸들 · 이름표 · 실선 · 끝 상태 셋 · `Start` · 층 배치 (손 확인) |
| UT-04 | 암묵 배선 그리기 | `next` 없는 driver 절차 | `stop` outcome 선 없음, 안내 줄 (손 확인) |
| UT-05 | 오류 위치 | 없는 대상 outcome · 틀린 `execute` | 노드 표지와 선 · 핸들 오류 색 · 단계 목록 위 오류 (손 확인) |
| UT-06 | 넘기는 객체 | 제목을 준 초안 저장 | 설정의 절에 `title` 이 있고 `execute` 가 없다 (손 확인) |
| UT-07 | 옛 사본 | `schema.blocks` 가 없는 고정 사본 프로젝트 | `--json` 호출 없이 순서 선 (손 확인) |
| UT-08 | Procedure 보기 | driver 절차 문서 | Mermaid 코드 블록 · 다음 표 (손 확인) |

## T5 · feat: 블록 팔레트와 단계 패널을 schema 의 블록·단계 키·입력 종류로 구성

### 상위 Requirement

- relates to #214

### 작업 내용

블록 팔레트 · 단계 추가 폼 · 오른쪽 패널의 입력을 UI 의 블록 표와 블록별 필드 분기 대신 `schema.blocks` 의 블록 · 단계 키 · 입력 종류로 그린다.

- 명세 4-1 · 2-2 · 4-7(`Next` 절 제외) · 4-2 의 키 태그 · 1절의 필수값 검사 삭제
- 블록 표(`KINDS`)에는 블록별 표시만 남긴다 — agent `Call Agent` · script `Run Script` · prompt `Run Prompt` · gate `Human Gate` · workflow `Run Workflow`.
  표에 없는 블록은 종류 이름과 기본 아이콘으로 그린다
- 팔레트(4-1): `+ Add Step after <N>` · `+ Add First Step` 의 항목이 `schema.blocks` 의 블록이고 그 순서다
- 추가 폼
  - 제목(기본값은 이름표)과 그 블록 `keys` 가운데 편집 중인 실행 방식이 받는 키(`keys[].execute`)
  - `Add` 는 값 검사 없이 고른 단계 뒤에 새 단계를 끼운다. 새 단계 id 는 지금처럼 `step-<N>` 이고, 명시 배선 절차에 끼운 단계는 `next` 가 없다
  - 필수값 검사(`missing`)를 지운다. 빠진 값은 다음 검사가 그 노드에 오류로 보인다
- 입력 종류별 입력(2-2)
  - `role` 역할 고르기(후보는 `schema.roles` 에서 `schema.script_roles` 의 역할을 뺀 것) · `command` 한 줄 고정폭 · `markdown` 마크다운 · `line` 한 줄 ·
    `list` `TagInput` · `choice` `choices` 중 하나 또는 "없음" · `workflow` 이 절차를 뺀 `schema.workflows` 의 이름 · `output_schema` `schema.output_schemas` 의
    이름과 "없음" · `schema_field` 같은 단계에서 `output_schema` 키의 값이 가리키는 항목의 `fields` 이름과 "없음"(그 키가 비면 고를 수 없다) ·
    `fixed` 값을 읽기 전용으로 보이고 그대로 돌려보낸다
  - "없음" 을 고르면 그 키를 단계에서 뺀다
  - 단계에 있으나 그 블록의 `keys` 에 없는 키는 고치지 않고 그대로 돌려보내며 패널에 "Other keys" 로 읽기 전용으로 보인다
  - 값이 입력 종류의 값 모양과 다르면 그 키는 `fixed` 처럼 다룬다
  - 키 이름표는 키 이름이다. `text` 는 `Instructions`, 기본 단계에서는 `Extra Instructions` 다
- 오른쪽 패널(4-7)
  - 읽기 모드: 본문과 지시를 지금처럼 보이고, 그 블록 `keys` 의 값과 "Other keys" 를 보인다
  - 편집 모드: 기본 단계(`builtin`)는 지시(`text`)만 고치고 다른 키 입력은 읽기 전용이다. 그 밖의 단계는 제목과 편집 중인 실행 방식이 받는 키를 고친다
  - `Agent Setting` 링크 · `Delete` · 순서 버튼은 지금과 같다
- 노드(4-2): 입력 종류가 `role` · `command` 인 값은 지금처럼 실행 정보로 보이고, 그 블록 `keys` 의 값 가운데 입력 종류가 `role` · `command` · `markdown` ·
  `fixed` 가 아닌 것을 `키 값` 꼴의 작은 태그로 보인다
- 건드릴 파일: `src/ui/components/FlowCanvas.js`, `src/ui/app/globals.css`

### 완료 조건

- [ ] `FlowCanvas.js` 에 블록 종류별 입력 분기와 `missing` 이 없고, 블록 표가 이름표 · 아이콘만 갖는다
- [ ] 팔레트가 `schema.blocks` 의 다섯 블록을 그 순서와 이름표로 보인다
- [ ] agent 절차의 추가 폼에 driver 전용 키가 없고 driver 절차의 추가 폼에는 있다
- [ ] 값을 비운 채 `Add` 한 단계가 끼워지고 다음 검사가 그 노드에 오류를 보인다
- [ ] 입력 종류 열 가지가 2-2 대로 그려지고, "없음" 이 키를 빼며, `schema_field` 는 `output_schema` 키가 비면 고를 수 없다
- [ ] "Other keys" 와 `fixed` 키가 읽기 전용으로 보이고 저장 뒤 설정에 그대로 남는다
- [ ] 기본 단계의 편집 모드에서 지시만 고칠 수 있다
- [ ] 노드에 `키 값` 태그가 보이고 `markdown` · `fixed` 값은 태그로 보이지 않는다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/214-ui-block-editor` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 팔레트 | 단계를 고르고 추가 메뉴 열기 | 다섯 블록이 schema 순서 · 이름표로 (손 확인) |
| UT-02 | 실행 방식별 추가 폼 | agent 절차 · driver 절차에서 agent 블록 추가 | agent 절차 폼에 `schema` · `on` 이 없고 driver 절차 폼에는 있다 (손 확인) |
| UT-03 | 검사 없는 추가 | 명령을 비운 script 단계 `Add` | 끼워지고 노드에 오류 (손 확인) |
| UT-04 | 입력 종류 | 각 입력 종류의 키를 가진 단계 편집 | 2-2 의 입력, "없음" 이 키를 뺌, 빈 스키마에서 필드 고르기 막힘 (손 확인) |
| UT-05 | 보존 | 모르는 키와 `set` 이 든 단계를 고쳐 저장 | 두 키가 설정에 그대로 (손 확인) |
| UT-06 | 기본 단계 | 기본 단계 편집 모드 | 지시만 입력 가능 (손 확인) |
| UT-07 | 블록 분기 제거 | `FlowCanvas.js` 소스 검색 | 블록 종류별 입력 분기와 `missing` 이 없다 |

## T6 · feat: outcome 핸들 잇기·다시 잇기·끊기와 패널 Next 절로 배선 편집

### 상위 Requirement

- relates to #214

### 작업 내용

배선을 받는 절차에서 outcome 핸들을 노드로 이어 단계의 `next` 를 고친다. 오른쪽 패널의 `Next` 절에서도 같은 변경을 한다.
변경 결과는 `flow.js` 의 `connect()` · `disconnect()` · `expand()` 로 만든다.

- 명세 4-4 · 4-6 · 4-7 의 `Next` 절
- 연결 편집은 배선을 받는 절차에서만 켠다
  - 잇기: outcome 핸들에서 단계 노드나 끝 상태 노드로 끌어 놓으면 그 단계의 `next[<outcome>]` 이 그 대상이 된다. 이미 이어져 있으면 대상을 바꾼다 — 핸들 하나에 선 하나
  - 다시 잇기: 선의 끝을 다른 노드로 옮기면 대상을 바꾼다
  - 끊기: 선을 고르고 `Delete` · `Backspace` 를 누르면 그 outcome 을 `next` 에서 뺀다. 마지막 outcome 을 빼도 `next` 는 빈 표로 남는다
  - 자기 자신으로 잇기를 받는다. 끝 상태에서 나가는 선은 없다
- 첫 연결: 마지막 검사 결과의 `wiring` 이 `implicit` 인 절차에 배선 변경(잇기 · 다시 잇기 · 끊기 · 패널의 배선 변경)이 처음 오면 `expand()` 로 모든 단계의
  `next` 를 실효 배선으로 채운 뒤 그 변경을 적용한다
- 결과 대기: 검사 결과가 지금 편집 상태의 것이 아니면(T4 의 짝) 배선 변경을 받지 않는다. 그동안 핸들과 선은 직전 결과로 그린다
- 순서 바꾸기 · 단계 지우기(4-6)
  - 암묵 배선 절차는 노드를 끌어 순서를 바꾼다(지금과 같다)
  - 명시 배선 절차는 노드를 끌 수 없다. 순서는 패널의 `← Earlier` · `Later →` 로 바꾸고 선은 그대로다
  - 단계를 지우는 방법은 패널의 `Delete`, 또는 노드를 고르고 `Delete` 키다. 다른 단계의 `next` 는 고치지 않는다
- 패널 `Next` 절(배선을 받는 절차)
  - 읽기 모드: outcome 마다(`handles()` 순서) 대상을 적는다 — `<번호>. <제목>` 또는 끝 상태
  - 편집 모드: outcome 마다 대상을 고른다. 후보는 단계들(`<번호>. <제목>`) · 끝 상태 · `(none)` 이고, `(none)` 은 그 outcome 을 `next` 에서 뺀다
  - `open` 인 단계는 맨 아래에 새 outcome 입력(이름 + 대상 + `Add`)을 둔다. 이름이 비었거나 이미 있으면 `Add` 를 막는다
  - 기본 단계도 배선을 고친다. 첫 연결과 결과 대기 규칙은 캔버스와 같다
- 건드릴 파일: `src/ui/components/FlowCanvas.js`, `src/ui/app/globals.css`

### 완료 조건

- [ ] driver 명시 배선 절차에서 outcome 핸들을 노드로 끌어 놓으면 그 단계의 `next` 가 바뀌고 다음 검사 뒤 그 선이 실선으로 그려진다
- [ ] 이어진 핸들을 다른 노드로 다시 이으면 대상이 바뀌고 선은 하나다
- [ ] 선을 끊으면 그 outcome 이 빠지고, 마지막 칸을 끊고 저장하면 `harness steps` 가 그 단계의 `next` 를 빈 표로 낸다
- [ ] 암묵 배선 driver 절차에서 첫 연결이 모든 단계의 `next` 를 펼친 뒤 적용되고 다음 검사의 `wiring` 이 `explicit` 이다
- [ ] 검사 결과가 오기 전의 배선 변경이 적용되지 않는다
- [ ] 명시 배선 절차에서 노드를 끌 수 없고, 순서 버튼으로 바꿔도 선이 그대로다
- [ ] 단계를 지워도 다른 단계의 `next` 가 그대로이고, 지운 단계를 가리키던 outcome 에 검사 오류가 보인다
- [ ] 패널 `Next` 절에서 대상 고르기 · `(none)` · `open` 단계의 새 outcome 추가가 되고, 빈 이름 · 있는 이름에서 `Add` 가 막힌다
- [ ] agent 절차에서는 연결 편집이 꺼져 있다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/214-ui-block-editor` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 잇기 · 다시 잇기 | 명시 배선 절차의 outcome 핸들 끌기 | `next` 대상이 바뀌고 선 하나 (손 확인) |
| UT-02 | 끊기 | 선 고르고 `Delete`, 마지막 칸까지 | outcome 이 빠지고 저장 뒤 `next = {}` (손 확인) |
| UT-03 | 첫 연결 | 암묵 배선 driver 절차에서 잇기 | 모든 단계 `next` 펼침, `wiring` `explicit` (손 확인) |
| UT-04 | 결과 대기 | 편집 직후 검사 전에 잇기 | 적용되지 않음 (손 확인) |
| UT-05 | 명시 배선 순서 | 노드 끌기 · 순서 버튼 | 끌리지 않고, 버튼으로 바꿔도 선 그대로 (손 확인) |
| UT-06 | 단계 지우기 | 다른 단계가 가리키는 단계 지우기 | 다른 `next` 그대로, 그 outcome 에 오류 (손 확인) |
| UT-07 | 패널 Next | 대상 고르기 · `(none)` · script 단계 새 outcome | `next` 반영, 빈 이름 · 있는 이름에서 `Add` 막힘 (손 확인) |
| UT-08 | agent 절차 | agent 절차에서 핸들 끌기 | 연결되지 않음 (손 확인) |

## T7 · feat: 절차 실행 방식 선택과 실행 방식에 따른 커맨드 표기

### 상위 Requirement

- relates to #214

### 작업 내용

절차의 실행 방식(`execute`)을 편집 상태에 넣어 툴바와 새 절차 대화상자에서 고르게 하고, 슬래시 커맨드가 없는 절차에는 `/<이름>` 표기와 커맨드 안내를 보이지 않는다.

- 명세 4-8 · 4-11 · 2-5 의 `execute` · 6절의 `workflow.execute` 도움말
- 실행 방식은 편집 상태의 일부다 — 바꾸면 저장하지 않은 변경이고 `Revert` 가 되돌린다. 검사와 저장은 2-5 대로 넘긴다
- 툴바에 실행 방식 단추 묶음을 둔다. 값은 `schema.execute.modes` 의 `value` 이고 그 순서다
- 바꾼 실행 방식이 받지 않는 키가 단계에 있으면 확인 대화상자를 연다
  - 받지 않는 키는 `strip()` 이 정한다 — 배선을 받지 않는데 있는 `next`, `blocks[].keys[].execute` 에 그 실행 방식이 없는 키
  - 대화상자는 지울 것을 단계별 키 이름으로 보인다. 확인하면 그 키들을 지우고 실행 방식을 바꾼다. 취소하면 바꾸지 않는다
- 새 절차 대화상자에 실행 방식 선택을 더한다. 기본값은 `schema.execute.default` 다
- 커맨드 표기(4-11)
  - 절차 고르기 메뉴의 항목: `schema.workflows.<절차>.command` 가 있으면 `/<command>`, 없으면 `<절차>`. 초안은 고른 실행 방식의 `command` 가 참이면 `/<이름>`
  - 빈 절차 안내와 패널의 단계 목록 머리: 같은 규칙
  - 새 절차 대화상자 안내: 고른 실행 방식의 `command` 가 참이면 `커맨드 /<이름> 이 함께 만들어진다. 단계를 더하고 저장해야 설정에 들어간다.`,
    거짓이면 `커맨드 없이 harness run <이름> <이슈> 로 시작한다. 단계를 더하고 저장해야 설정에 들어간다.`
  - 이름 변경 대화상자 안내: 커맨드가 있으면 지금 문구, 없으면 `절차 문서와 이 절차에 더한 지시 파일이 새 이름을 따라간다.`
  - 삭제 대화상자: 커맨드가 있으면 `/<이름> 절차와 그 커맨드를 지운다.`, 없으면 `<이름> 절차를 지운다.` 메모 경로 안내는 지금과 같다
- `src/ui/lib/help.js` 에 `workflow.execute` 를 명세 6절 문구로 더하고 실행 방식 단추 묶음 옆 도움말로 보인다
- 건드릴 파일: `src/ui/components/FlowCanvas.js`, `src/ui/lib/help.js`, `src/ui/app/globals.css`

### 완료 조건

- [ ] 툴바 단추가 `schema.execute.modes` 순서로 `agent` · `driver` 를 보이고 지금 값이 골라져 있다
- [ ] driver 절차를 agent 로 바꾸면 `next` 와 driver 전용 키가 단계별로 나열된 확인 대화상자가 열리고, 확인하면 지워지며 바뀌고, 취소하면 그대로다
- [ ] 받지 않는 키가 없으면 대화상자 없이 바뀐다
- [ ] 실행 방식을 바꾸면 저장하지 않은 변경으로 표시되고 `Revert` 가 되돌린다
- [ ] driver 로 바꿔 저장하면 schema 의 `workflows.<절차>.execute` 가 `driver` 이고 그 절차의 커맨드 파일이 없다. driver 로 저장된 절차를 agent 로 바꿔 저장하면
  `workflows.<절차>.execute` 가 `agent` 다
- [ ] 새 절차 대화상자의 실행 방식 기본값이 `agent` 이고, 고른 실행 방식에 따라 안내 문구가 바뀐다
- [ ] 커맨드가 없는 절차가 메뉴 · 빈 절차 안내 · 단계 목록 머리에서 `<이름>` 으로, 이름 변경 · 삭제 대화상자에서 커맨드 없는 문구로 보인다
- [ ] 단추 묶음 옆에 `workflow.execute` 도움말이 보인다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/214-ui-block-editor` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 실행 방식 바꾸기 | 명시 배선 driver 절차를 agent 로 | 단계별 지울 키 대화상자, 확인 · 취소 결과 (손 확인) |
| UT-02 | 편집 상태 | 실행 방식 바꾸고 `Revert` | 저장하지 않은 변경 표시, 되돌림 (손 확인) |
| UT-03 | 저장 | driver 로 바꿔 저장, 다시 agent 로 바꿔 저장 | schema `execute` 가 차례로 `driver` · `agent`, driver 일 때 커맨드 파일 없음 (손 확인) |
| UT-04 | 새 절차 | 새 절차 대화상자에서 driver 고르기 | 기본값 agent, 커맨드 없는 안내 문구, 메뉴 표기 `<이름>` (손 확인) |
| UT-05 | 커맨드 표기 | 커맨드 있는 절차 · 없는 절차의 이름 변경 · 삭제 대화상자 | 4-11 의 두 문구 (손 확인) |

## T8 · feat: 하위 절차 블록에서 그 절차로 이동과 돌아오기

### 상위 Requirement

- relates to #214

### 작업 내용

workflow 블록처럼 하위 절차를 가리키는 단계에서 그 절차의 캔버스로 들어가고, 들어온 차례의 반대로 돌아온다.

- 명세 4-9 · 4-2 의 `Open`
- 입력 종류가 `workflow` 인 키에 값이 있는 단계는 노드와 패널에 `Open <절차>` 를 보인다. 그 절차가 `schema.workflows` 에 없으면 `Open` 은 꺼진다
- 누르면 캔버스가 그 절차로 바뀐다
  - 떠나온 절차를 기억해 툴바에 `← <절차>` 를 보인다. 여러 번 들어가면 들어온 차례의 반대로 돌아온다
  - 절차 고르기 메뉴로 절차를 바꾸면 기억을 비운다
- 저장하지 않은 편집은 절차별로 남는다(지금과 같다)
- 건드릴 파일: `src/ui/components/FlowCanvas.js`, `src/ui/app/globals.css`

### 완료 조건

- [ ] 하위 절차를 가리키는 단계의 노드와 패널에 `Open <절차>` 가 보이고, 누르면 그 절차의 캔버스가 열린다
- [ ] 두 번 들어간 뒤 `← <절차>` 로 들어온 차례의 반대로 돌아온다
- [ ] 메뉴로 절차를 바꾸면 `← <절차>` 가 사라진다
- [ ] 설정에 없는 절차를 가리키면 `Open` 이 꺼져 있다
- [ ] 들어갔다 돌아와도 두 절차의 저장하지 않은 편집이 남아 있다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/214-ui-block-editor` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 이동 | workflow 블록의 `Open` | 그 절차 캔버스, 툴바 `← <절차>` (손 확인) |
| UT-02 | 되돌아오기 | 두 단계 들어간 뒤 `←` 두 번 | 들어온 반대 차례로 돌아옴 (손 확인) |
| UT-03 | 기억 비우기 | 들어간 뒤 메뉴로 절차 바꾸기 | `←` 사라짐 (손 확인) |
| UT-04 | 없는 절차 | 설정에 없는 절차를 가리키는 단계 | `Open` 꺼짐 (손 확인) |
| UT-05 | 편집 보존 | 상위 · 하위 절차를 고친 채 오가기 | 두 편집 모두 남음 (손 확인) |

## T9 · feat: 아래 레이어 절차의 읽기 전용 표시와 프로젝트로 분리

### 상위 Requirement

- relates to #214

### 작업 내용

내장 기본값 · preset 이 준 절차는 캔버스에서 읽기 전용으로 보이고, 사람이 "프로젝트로 분리" 를 고른 뒤에만 프로젝트 레이어가 그 절차를 통째로 교체한다.
옛 고정 사본은 읽기 전용과 재설치 안내로 다룬다.

- 명세 3절 · 3-1 · 3-2 · 3-3 · 3-4 · 6절의 `workflow.source` 도움말
- 출처 판정
  - 절차의 출처 레이어는 schema `sources` 의 `workflows.<절차>` 값이다. `project` 면 편집하고, 그 밖의 레이어면 읽기 전용이다. preset 레이어 id 의 형식에 기대지 않는다
  - 초안(저장하지 않은 새 절차)은 `project` 로 다룬다
  - 화면 문구의 `<레이어>` 는 출처 레이어 id 를 `src/ui/lib/labels.js` 의 레이어 이름표 함수로 바꾼 것이다
- 읽기 전용(3-1)
  - 보이는 것은 편집할 때와 같다 — 노드, 선, 끝 상태, 패널의 읽기 모드, 하위 절차 이동, Procedure 보기
  - 빠지는 조작: 단계 추가 메뉴, 잇기 · 다시 잇기 · 선 끊기, 노드 끌기, 노드 지우기, 패널의 편집 모드 · 순서 바꾸기 · `Delete`, 실행 방식 선택(지금 값만 보인다),
    `Revert` · `Check & Save`, `Rename` · `Delete Workflow`
  - 캔버스 위에 `이 절차는 <레이어> 에서 온다 — 읽기 전용이다.` 와 `Separate into Project` 단추를 보이고, 그 옆에 `workflow.source` 도움말을 보인다
  - 절차 메모(Procedure 보기의 Project Instructions)는 출처와 상관없이 고친다
  - 읽기 전용 절차도 열 때 `--dry-run --json` 을 불러 선과 핸들을 그린다
- 프로젝트로 분리(3-2)
  - `Separate into Project` 를 누르면 확인 대화상자를 연다 — 제목 `Separate Workflow`, 본문 세 줄(`<절차>` 를 프로젝트 `harness.toml` 에 통째로 옮겨 적는다 ·
    그 뒤로 `<레이어>` 가 이 절차를 바꿔도 이 프로젝트에는 닿지 않는다 · 이 절차에 확장 지점(빈 하위 절차)이 있으면 그 하위 절차만 분리해 채울 수 있다), 단추 `Separate`
  - 확인하면 지금 보이는 그 절차를 2-5 의 형식(제목 · 실행 방식 · 단계 키 전부)으로 `saveSteps` 에 넘긴다. 내용은 바꾸지 않는다
  - 성공하면 화면이 schema 를 다시 읽고, 그 절차는 프로젝트 레이어 출처가 되어 편집할 수 있다. 실패하면 CLI 출력을 그대로 보이고 읽기 전용으로 남는다
  - CLI 에 새 명령을 두지 않는다
- 이름 변경 · 삭제(3-3): `Rename` · `Delete Workflow` 는 출처가 프로젝트 레이어이고 `schema.workflows.<절차>.custom` 이 참인 저장된 절차에만 보인다
- 옛 고정 사본(3-4)
  - `schema.blocks` 가 없으면 캔버스는 읽기 전용이고, 캔버스 위에 재설치 안내(`Reinstall`, "절차를 편집")를 보인다. 선 긋기와 검사 생략은 T4 가 둔 대로다
  - 절차 메모 편집은 `schema.docs` 유무 판정을 그대로 따른다
  - `harness steps` 나 `harness schema` 를 받지 못하는 사본은 `page.js` 의 지금 안내를 따른다
- 건드릴 파일: `src/ui/components/FlowCanvas.js`, `src/ui/app/[project]/workflow/page.js`(이름표에 쓰는 값을 넘길 때), `src/ui/lib/help.js`, `src/ui/app/globals.css`

### 완료 조건

- [ ] 프로젝트 `harness.toml` 에 절이 없는 기본 절차가 읽기 전용이고, 캔버스 위에 레이어 이름표가 든 안내 줄과 `Separate into Project` 가 보인다
- [ ] 읽기 전용 절차에서 3-1 의 조작이 모두 없고, 선 · 핸들 · 끝 상태 · 검사 오류 · 하위 절차 이동 · Procedure 보기 · 절차 메모 편집은 된다
- [ ] `Separate` 를 확인하면 프로젝트 `harness.toml` 에 그 절차의 절이 생기고, 분리 전후의 `harness steps` 출력과 schema 의 `title` · `execute` 가 같으며, 화면이 편집 가능으로 바뀐다
- [ ] 분리가 실패하면 CLI 출력이 보이고 읽기 전용으로 남는다
- [ ] 프로젝트 `harness.toml` 에 `[workflows.<절차>]` 절이 있는 리포에서는 그 절차가 편집된다
- [ ] `Rename` · `Delete Workflow` 가 프로젝트 출처이고 `custom` 인 저장된 절차에만 보인다
- [ ] `schema.blocks` 가 없는 고정 사본에서 캔버스가 읽기 전용이고 재설치 안내가 보이며, 절차 메모 편집은 `schema.docs` 판정을 따른다
- [ ] 안내 줄 옆에 `workflow.source` 도움말이 보인다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/214-ui-block-editor` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 읽기 전용 | 새로 설치한 리포의 기본 절차 | 안내 줄 · 분리 단추, 3-1 조작 없음, 선과 핸들 보임 (손 확인) |
| UT-02 | 분리 성공 | `Separate into Project` → `Separate` | `harness.toml` 에 절, 분리 전후 `harness steps` · `title` · `execute` 같음, 편집 가능 (손 확인) |
| UT-03 | 분리 실패 | render 가 멈추는 상태(하네스가 쓸 경로에 사용자 파일)에서 분리 | CLI 출력 표시, 읽기 전용 유지 (손 확인) |
| UT-04 | 옮겨 적은 절차 | 기본 절차를 `harness.toml` 에 둔 리포 | 편집 가능 (손 확인) |
| UT-05 | 이름 변경 · 삭제 | 프로젝트 custom 절차 · 기본 절차 | 앞에만 `Rename` · `Delete Workflow` (손 확인) |
| UT-06 | 옛 사본 | `schema.blocks` 가 없는 고정 사본 프로젝트 | 읽기 전용, 재설치 안내 (손 확인) |
| UT-07 | 절차 메모 | 읽기 전용 절차의 Project Instructions 저장 | 저장된다 (손 확인) |

## T10 · docs: README 명령 표와 UI 표에 블록 편집·검사 JSON 반영

### 상위 Requirement

- relates to #214

### 작업 내용

T1–T9 로 바뀐 명령 출력과 Workflows 화면을 사람용 설명에 적는다.

- 명세 6절의 README 항목
- 명령 표의 `harness steps` 행: `--dry-run --json` 이면 검사 결과와 단계별 outcome · 실효 배선을 JSON 으로 낸다
- 명령 표의 `harness schema` 행: 블록 목록 · 끝 상태 · 와일드카드 키 · 실행 방식 목록과 절차별 커맨드도 낸다
- UI 표의 Workflows 행
  - 무엇을: 블록을 팔레트에서 끼우고 outcome 핸들을 이어 분기 · 루프를 만든다. 실행 방식을 고르고, 하위 절차로 이동한다. 아래 레이어가 준 절차는 읽기 전용이고
    프로젝트로 분리해야 고친다. 절차 끝에 붙는 이 프로젝트의 지시를 고친다
  - 쓰기 경로 칸의 `harness steps` 항목: `harness steps`(편집 중에는 `--dry-run --json` 으로 검사만). 같은 칸의 다른 항목은 이 task 가 고치지 않는다
- "문서는 읽기가 기본이다" 단락의 "노드에서 고치는 것은 덧붙인 지시(`text`)뿐이다" → "기본 단계에서 고치는 것은 덧붙인 지시(`text`)와 배선뿐이다"
- 건드릴 파일: `README.md`

### 완료 조건

- [ ] README 명령 표의 `harness steps` · `harness schema` 행과 UI 표의 Workflows 행이 명세 6절의 사실을 담는다
- [ ] "문서는 읽기가 기본이다" 단락의 문장이 바뀌어 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/214-ui-block-editor` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 반영 확인 | `README.md` | 명령 표 두 행 · UI 표 Workflows 행 · 단락 문장이 명세 6절과 같다 |

## T11 · docs: 담당 범위·아키텍처·용어·테스트 문서에 UI 블록 편집 반영

### 상위 Requirement

- relates to #214

### 작업 내용

T1–T9 로 바뀐 사실을 에이전트가 근거로 읽는 문서에 적는다.

**보호 문서를 수정하는 task 다.** 2026-10-09 결정 게이트에서 사용자가 허용한 범위 — 명세 8절 "보호 문서 개정 범위" 의 표 — 안에서만 고치고, 그 밖은 고치지 않는다.
권한 설정 · 가드에 걸리면 사람이 대응한다.

- 명세 8절의 일곱 행을 표의 문안 그대로 반영한다
  - `.ai/project/architecture.md` "구성 요소" 의 `src/ui/` 항목: 화면 나열의 `Workflows(단계 캔버스)` → `Workflows(블록 그래프 — outcome 핸들 연결·실행 방식·하위 절차 이동. 아래 레이어가 준 절차는 읽기 전용)`
  - 같은 항목의 끝 문장: "파일 경로는 짓지 않고 `harness schema` 에서 받는다" 뒤에 "블록 목록·단계별 outcome·실효 배선도 CLI(`harness schema` · `harness steps --dry-run --json`)에서 받는다" 를 잇는다
  - `architecture.md` "새 코드를 둘 곳": 줄 하나 "새 단계 키 → 단계 키 정의에 그 키의 UI 입력 종류도 함께 둔다(`harness schema` 의 `blocks`)"
  - `architecture.md` "계층과 의존 방향" 의 `src/ui/` 줄: "UI 는 파일 경로를 짓지 않고 `harness schema` 에서 받는다" → "UI 는 파일 경로·블록 종류·outcome·배선 해석을 짓지 않고 CLI 에서 받는다"
  - `.ai/project/testing.md` "무엇을 어느 수준으로 검증하나" 의 UI 줄: 순수 함수 나열에 `절차 그래프 변환·자동 배치` 를 더한다
  - `.ai/project/glossary.md` 용어 표: 행 `프로젝트로 분리` — 아래 레이어가 준 절차를 프로젝트 레이어(`harness.toml`)에 통째로 옮겨 적는 UI 동작. 그 뒤로 아래 레이어의 그 절차 갱신은 이 프로젝트에 닿지 않는다
  - `.ai/project/scope.md` "할 수 있는 일" 의 웹 UI 줄: `절차` → `절차(블록을 이어 분기·루프를 만든다)`
- #206 · #207 · #208 이 고친 문장 위에 더한다. 이 task 가 바꾸는 문장을 고치는 다른 명세는 없고, 새 줄 · 새 행은 앞 명세가 더한 것 뒤에 둔다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 문서를 고친 뒤 render 로 갱신한다
- 건드릴 파일: `.ai/project/architecture.md`, `.ai/project/testing.md`, `.ai/project/glossary.md`, `.ai/project/scope.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] 네 문서가 명세 8절 표의 일곱 문안을 담고, 그 밖의 줄은 바뀌지 않는다
- [ ] render 뒤 `.ai/AI_AGENT.md` 1장 · 2장 · 5장이 문서와 일치하고 `harness check` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/214-ui-block-editor` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 범위 | 네 문서의 diff | 명세 8절 일곱 행만 바뀌었다 |
| UT-02 | 생성물 일치 | 문서 수정 뒤 render · `harness check` | 어긋남 없음, `.ai/AI_AGENT.md` 1 · 2 · 5장에 반영 |
