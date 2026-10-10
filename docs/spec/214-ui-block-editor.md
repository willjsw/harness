# UI 블록 편집 — 블록을 이어 분기·루프가 있는 절차 만들기

UI Workflows 화면에서 블록을 이어 분기·루프가 있는 절차를 만들고 저장한다. 블록 종류·단계별 outcome·배선
해석·검증은 CLI 가 정본이다. UI 는 CLI 가 준 것을 그리고, 저장은 `harness steps` 로 한다(ADR 0009).
아래 레이어(내장 기본값·preset)가 준 절차는 읽기 전용이고, 사람이 "프로젝트로 분리" 를 고른 뒤에만
프로젝트 레이어가 그 절차를 통째로 교체한다.

기준 코드는 #208(블록 그래프와 드라이버)이 들어간 통합 브랜치다. 그 선행인 #206(Python 패키지)과
#207(설정 계층)도 들어 있다.

- 블록의 의미는 #208 이 정하고 이 명세는 그것을 그대로 쓴다. 블록 5종의 outcome, `next` 문법, 끝 상태,
  암묵 배선, 시작 단계, 실행 방식별 허용 키, render 검증과 그 오류 위치 표기, `harness steps` 의 키 보존,
  `harness schema` 의 `output_schemas` · `workflows.<절차>.execute` 가 여기에 든다
- 명령 코드가 어느 모듈에 있는지는 #206 의 모듈 지도를 따른다. 이 명세는 명령과 함수 단위로 적는다

정본 위치:

| 대상 | 정본 |
|---|---|
| `harness schema` · `harness steps` 명령 | #206 의 모듈 지도가 정한 각 명령의 모듈 |
| 단계 키 정의 · outcome 집합 · 실효 배선 · 시작 단계 계산 | #208 의 workflow 모듈 (`src/harness/workflow/`) |
| 캔버스 화면 | `src/ui/components/FlowCanvas.js` |
| 화면 진입 | `src/ui/app/[project]/workflow/page.js` |
| 그래프 변환·배치 순수 함수 | `src/ui/lib/flow.js` (새 파일) |
| 서버 액션 · CLI 호출 | `src/ui/lib/actions.js` · `src/ui/lib/harness.js` |
| 도움말 | `src/ui/lib/help.js` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/ui/lib/flow.test.js` (새 파일) |
| 사람용 설명 | `README.md` |

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

- 연결선은 단계 순서에서 만들지 않는다. CLI 가 계산한 실효 배선에서 그린다
- 배선을 받는 실행 방식의 절차에서는 outcome 핸들에서 선을 이어 `next` 를 고친다 (4-4)
- 블록 목록·단계 키·끝 상태·실행 방식은 `harness schema` 에서 받는다 (2-1). UI 의 블록 표(`KINDS`)에는
  블록별 표시(이름표·아이콘)만 남는다
- 단계 추가 폼의 필수값 검사(`missing`)를 지운다. 빠진 값은 `--dry-run` 검사가 그 노드에 보인다
- 아래 레이어가 준 절차는 읽기 전용이다. 고치려면 프로젝트로 분리한다 (3절)
- 슬래시 커맨드가 없는 절차(driver 절차 등)에는 `/<이름>` 표기와 "커맨드가 만들어진다" 안내를 보이지 않는다 (4-11)
- 저장 경로는 `harness steps <절차> <JSON>` 그대로다. UI 는 늘 객체 형식으로 넘기고 `execute` 를 실을 수 있다 (2-5)
- 바뀌지 않는 것
  - 절차 메모 편집(Procedure 보기의 Project Instructions)
  - 절차 이름 변경·삭제와 새 절차 이름 검사(`nameProblem`)
  - 저장 전 마크다운 검사, 기본 단계 본문 표시, 미니맵, 패널 너비 조절
- 생성 파일도 설정 키도 늘지 않는다. `plan()` 에 등록할 것이 없다
- CLI 변경은 출력 보강뿐이다 — `harness schema` 의 새 키(2-1)와 `harness steps --dry-run --json`(2-3)

## 2. CLI 출력

### 2-1. `harness schema` 의 새 키

기존 키는 그대로다. 아래를 더한다.

| 키 | 값 |
|---|---|
| `blocks` | `[{ "type": "<블록>", "keys": [{ "key": "<단계 키>", "input": "<입력 종류>", "execute": ["<실행 방식>", ...], "choices": ["<값>", ...] }] }]` |
| `ends` | 끝 상태 목록 — `["done", "stop", "handoff"]` |
| `wildcard` | 나머지 outcome 을 받는 `next` 키 — `"*"` |
| `execute` | `{ "default": "<실행 방식>", "modes": [{ "value": "<실행 방식>", "wiring": <bool>, "command": <bool> }] }` |
| `workflows.<절차>.command` | render 가 그 절차를 부르는 커맨드 파일(생성 파일이든 관리 파일이든)을 대상 리포에 두면 그 이름(`/` 없이). 두지 않으면 `null` |

`blocks`

- 블록 순서는 #208 의 블록 정의 순서다
- `keys` 는 그 블록이 받는 단계 키에서 `id` · `type` · `title` · `next` 를 뺀 것이다. 순서는 #208 의 단계 키 정의 순서다
- `input` 은 UI 가 그 키를 고치는 입력 종류다 (2-2)
- `execute` 는 그 키를 받는 실행 방식들이다. #208 이 agent 절차에서 거부하는 키의 `execute` 는 `["driver"]` 다
- `choices` 는 `input` 이 `choice` 일 때만 있다

`execute`

- `default` 는 `execute` 키가 없는 절차의 실행 방식이다
- `modes[].wiring` 은 그 실행 방식의 절차가 `next` 를 받는지다
- `modes[].command` 는 프로젝트가 만든 그 실행 방식의 절차에 render 가 슬래시 커맨드를 만드는지다

#208 이 같은 출력에 더하는 키

- `output_schemas`(`{ "<스키마 이름>": { "source", "path", "fields" } }`)와 `workflows.<절차>.execute` 는 #208 이 정하고 낸다. 이 명세는 두 키를 더하지 않고 읽기만 한다
- UI 는 `output_schemas` 의 이름을 agent 블록의 스키마 후보로, 그 항목 `fields` 의 필드 이름을 `on` 의 후보로 쓴다 (2-2)
- `workflows.<절차>.execute` 는 기본값을 채운 값이다. `execute` 키가 없는 절차에서는 위 `execute.default` 와 같다

값은 모두 #208 의 정의에서 만든다 — 블록 정의, 단계 키 정의, 끝 상태, 실행 방식별 허용 키.
schema 용으로 같은 표를 따로 두지 않는다. 입력 종류(`input`)는 단계 키 정의 옆에 둔다.
**단계 키 정의의 모든 키에 입력 종류가 있다** — 키를 더하는 변경은 입력 종류도 함께 정하고, 빠지면 회귀 테스트가 막는다 (7-1).

절차별 출처 레이어는 이 명세가 더하지 않는다. #207 이 schema 에 내는 값 출처를 쓴다 (3절).

### 2-2. 입력 종류

| `input` | 값 모양 | 오른쪽 패널의 입력 |
|---|---|---|
| `role` | 문자열 | 역할 고르기. 후보는 `schema.roles` 에서 `schema.script_roles` 에 있는 역할을 뺀 것 (지금과 같다) |
| `command` | 문자열 | 한 줄 고정폭 입력 |
| `markdown` | 문자열 | 마크다운 입력 |
| `line` | 문자열 | 한 줄 입력 |
| `list` | 문자열 배열 | 목록 입력(`TagInput`) |
| `choice` | 문자열 | `choices` 중 하나 또는 "없음" |
| `workflow` | 문자열 | 절차 고르기. 후보는 이 절차를 뺀 `schema.workflows` 의 이름 |
| `output_schema` | 문자열 | 스키마 고르기. 후보는 `schema.output_schemas` 의 이름과 "없음" |
| `schema_field` | 문자열 | 필드 고르기. 후보는 같은 단계에서 입력 종류가 `output_schema` 인 키의 값이 가리키는 `schema.output_schemas` 항목의 `fields` 이름과 "없음". 그 키가 비어 있으면 고를 수 없다 |
| `fixed` | 무엇이든 | 고치지 않는다. 값을 읽기 전용으로 보이고 그대로 돌려보낸다 |

- 표(TOML 테이블) 값을 받는 단계 키의 입력 종류는 `fixed` 다
- "없음" 을 고르면 그 키를 단계에서 뺀다
- 단계에 있으나 그 블록의 `keys` 에 없는 키는 고치지 않고 그대로 돌려보낸다. 패널에는 "Other keys" 로 읽기 전용으로 보인다
- 값이 입력 종류의 값 모양과 다르면 그 키는 `fixed` 처럼 다룬다
- 키 이름표는 키 이름이다. 단 `text` 는 `Instructions`, 기본 단계(`builtin`)에서는 `Extra Instructions` 다 (지금과 같다)

### 2-3. `harness steps <절차> <JSON> --dry-run --json`

텍스트 `--dry-run` 과 같은 검사를 돌리고, 결과와 함께 단계별 outcome 과 실효 배선을 JSON 으로 낸다.
설정 파일을 쓰지 않는다.

- `--json` 은 `--dry-run` 과 함께일 때만 받는다. 아니면 종료 코드 2 로 거부한다:
  `error: steps takes --json only with --dry-run`
- 입력 JSON 이 형식을 어기면 지금처럼 문장으로 거부한다(종료 코드 2). JSON 은 내지 않는다
- 그 밖에는 표준 출력에 JSON 객체 하나를 낸다. 표준 오류에는 아무것도 쓰지 않는다
- 종료 코드는 검사가 통과하면 0, 거부하면 2 다
- `--json` 의 도움말은 doctor 와 함께 쓴다: `doctor: print the items as one JSON object; steps --dry-run: print the check as one JSON object`

```json
{
  "ok": false,
  "error": "<거부한 첫 오류 문장>",
  "at": { "step": 1, "outcome": "reject" },
  "wiring": "explicit",
  "start": "build",
  "steps": [
    { "id": "build", "outcomes": [], "open": true, "next": { "0": "approve", "*": "stop" } },
    { "id": "approve", "outcomes": ["ship", "reject"], "open": false, "next": { "ship": "done" } }
  ]
}
```

| 키 | 값 |
|---|---|
| `ok` | 검사 통과 여부. 텍스트 `--dry-run` 의 판정과 같다 |
| `error` | 거부한 첫 오류 문장의 원문. 여러 줄일 수 있다. 통과하면 `null` |
| `at` | 오류 위치 `{ "step": <단계 번호(0부터)> \| null, "outcome": <outcome 키> \| null }`. 2-4 의 표기에서 읽는다. 통과하면 `null` |
| `wiring` | `"explicit"` 또는 `"implicit"`. #208 의 절차 단위 판정이다 |
| `start` | 시작 단계 id. 단계가 없으면 `null` |
| `steps` | 입력 단계와 같은 순서·같은 길이의 목록 |
| `steps[].id` | 입력 단계의 `id` 그대로 |
| `steps[].outcomes` | 그 단계에서 나온다고 알려진 outcome 목록. 순서는 #208 의 outcome 집합 계산이 정한 것이다 |
| `steps[].open` | 목록 밖의 outcome 도 나올 수 있는지 (script 블록처럼) |
| `steps[].next` | 실효 배선. 명시 배선이면 그 단계의 `next`, 암묵 배선이면 #208 의 암묵 배선을 펼친 것이다. 계산할 수 없으면 키가 없다 |

- 검사가 거부해도 `wiring` · `start` · `steps` 를 낸다
- outcome 집합을 계산할 수 없는 단계는 `"outcomes": []`, `"open": true` 다. 모르는 블록, 없는 스키마나 하위 절차가 그렇다
- 계산은 #208 의 render 검증과 드라이버가 쓰는 함수를 그대로 부른다 — outcome 집합, 실효 배선, 시작 단계. `--json` 용으로 따로 짓지 않는다
- 실효 배선은 실행 방식과 상관없이 같은 함수로 계산한다
- workflow 블록의 outcome 은 #208 의 고정 집합 `done` · `stop` · `handoff` 다. 하위 절차는 저장된 설정에서 찾는다 — 텍스트 `--dry-run` 의 검사와 입력이 같고, 저장된 설정에 없으면 위의 계산할 수 없는 단계다
- 검사 중 표준 오류로 가던 문장은 모아 `error` 에 넣는다. 통과했을 때 모인 경고는 내지 않는다

### 2-4. 오류 위치 표기

오류 문장의 위치 표기는 #208 의 render 검증이 정한다 — 단계는 `workflows.<절차>.steps[<i>]`, 단계의 outcome 은
`workflows.<절차>.steps[<i>].next[<outcome 의 JSON 문자열>]`(예: `workflows.work.steps[2].next["*"]`)이다.
이 명세는 그 표기를 더하거나 바꾸지 않고 `at` 을 거기서 읽는다.

- `at` 은 오류 문장의 첫 위치 표기에서 읽는다
  - `step` 은 `steps[<i>]` 의 번호다
  - `outcome` 은 `next[…]` 안의 JSON 문자열을 푼 값이다. outcome 이름에 `.` 이 있어도 그대로 읽힌다
- outcome 표기가 없으면 `outcome` 은 `null` 이다. 위치 표기가 없으면 `step` · `outcome` 이 둘 다 `null` 이고 절차 전체의 오류다

### 2-5. 저장·검사 때 UI 가 넘기는 것

저장(`harness steps <절차> <JSON>`)과 검사(`--dry-run --json`)에 같은 객체를 넘긴다.

```json
{ "title": "<제목>", "execute": "<실행 방식>", "steps": [ ... ] }
```

- `title`
  - 초안이면 새 절차 대화상자의 값이다
  - 저장된 절차면 `schema.workflows.<절차>.title` 이다
  - 비어 있으면 넣지 않는다
- `execute` 는 편집 중인 실행 방식이 `schema.execute.default` 와 다르거나 저장된 값(`schema.workflows.<절차>.execute`)과 다를 때 넣는다. 초안은 기본값과만 견준다
  - 그래서 driver 로 저장된 절차를 agent 로 바꾸면 `"execute": "agent"` 를 넘기고, 설정에 `execute = "agent"` 가 명시로 저장된다. 객체에 없는 절차 키는 지금 값을 두기 때문이다(#208)
- 단계에서 `builtin` · `body` 를 뺀다(지금과 같다). 나머지 키는 그대로 넘긴다
- 객체의 `execute` 를 받아 쓰는 것과 단계 키 전부·절차 키를 보존하는 것은 `harness steps` 가 한다(#208)

## 3. 편집 권한 — 절차의 출처 레이어

- 절차마다의 출처 레이어는 #207 이 `harness schema` 에 내는 값 출처 `sources` 의 `workflows.<절차>` 값(레이어 id)이다
  - `workflows.<이름>` 은 레이어 사이에서 통째로 교체되므로, 절차 하나에 출처 레이어는 하나다
- 출처가 `project`(프로젝트 레이어, `harness.toml`)인 절차는 편집한다
- 출처가 그 밖의 레이어 — `default`(내장 기본값)와 preset 레이어(조직 preset · 스택 preset) — 인 절차는 읽기 전용이다
  - 판정은 출처가 `project` 인지만 본다. preset 레이어 id 의 형식에 기대지 않는다
- 개인 레이어(`local`)는 절차를 갖지 않는다 (#207 의 개인 레이어 허용 키)
- 프로젝트 `harness.toml` 에 `[workflows.<절차>]` 절이 있으면 출처는 `project` 다. 기본 절차를 옮겨 적은 옛 설치본도 그렇다
- 초안(저장하지 않은 새 절차)은 `project` 로 다룬다
- 화면 문구의 `<레이어>` 는 출처 레이어 id 를 `src/ui/lib/labels.js` 의 레이어 표시 이름 함수(#207)로 바꾼 것이다
  - preset 레이어의 id 와 그 표시 이름은 #216 이 정한다
  - 이 명세는 그 함수에 표시를 더하지 않는다

### 3-1. 읽기 전용

- 보이는 것은 편집할 때와 같다 — 노드, 선, 끝 상태, 패널의 읽기 모드, 하위 절차 이동, Procedure 보기
- 읽기 전용에서 빠지는 조작
  - 단계 추가 메뉴
  - 잇기·다시 잇기·선 끊기, 노드 끌기, 노드 지우기
  - 패널의 편집 모드, 순서 바꾸기, `Delete`
  - 실행 방식 선택
  - `Revert` · `Check & Save`, `Rename` · `Delete Workflow`
- 캔버스 위에 한 줄과 버튼을 보인다: `이 절차는 <레이어> 에서 온다 — 읽기 전용이다.` · `Separate into Project`
- 절차 메모(Procedure 보기의 Project Instructions)는 출처와 상관없이 고친다. 설정이 아니라 소유 파일이다(`harness write-doc`)
- 읽기 전용 절차도 열 때 `--dry-run --json` 을 불러 선과 핸들을 그린다

### 3-2. 프로젝트로 분리

`Separate into Project` 를 누르면 확인 대화상자가 열린다.

- 제목: `Separate Workflow`
- 본문
  - `<절차>` 를 프로젝트 `harness.toml` 에 통째로 옮겨 적는다
  - 그 뒤로 `<레이어>` 가 이 절차를 바꿔도 이 프로젝트에는 닿지 않는다
  - 이 절차에 확장 지점(빈 하위 절차)이 있으면 그 하위 절차만 분리해 채울 수 있다
- 버튼: `Separate`

확인하면 이렇게 한다.

- 지금 보이는 그 절차를 2-5 의 형식으로 `harness steps <절차> <JSON>` 에 넘긴다 — 제목, 실행 방식, 단계 키 전부. 내용은 바꾸지 않는다
- 성공하면 화면이 schema 를 다시 읽는다. 그 절차는 프로젝트 레이어 출처가 되어 편집할 수 있다
- 실패하면 CLI 출력을 그대로 보인다. 절차는 읽기 전용으로 남는다
- CLI 에 새 명령을 두지 않는다. 분리는 아래 레이어 절차를 프로젝트 `harness.toml` 에 손으로 옮겨 적는 것과 결과가 같다

### 3-3. 이름 변경·삭제

`Rename` · `Delete Workflow` 는 두 조건을 모두 만족하는 저장된 절차에만 보인다.

- 출처가 프로젝트 레이어다
- `schema.workflows.<절차>.custom` 이 참이다

### 3-4. 옛 고정 사본

- `schema.blocks` 가 없으면 그 고정 사본은 이 명세의 출력을 모른다
  - 캔버스는 읽기 전용으로, 단계 순서대로 이은 선을 그린다
  - 캔버스 위에 재설치 안내(`Reinstall`, "절차를 편집")를 보인다
  - `--dry-run --json` 을 부르지 않는다
- 절차 메모 편집은 `schema.docs` 유무 판정을 그대로 따른다
- `harness steps` 나 `harness schema` 를 받지 못하는 사본은 지금의 안내를 따른다 (`page.js`)

## 4. 캔버스

아래에서 "배선을 받는 절차" 는 편집 중인 실행 방식의 `schema.execute.modes[].wiring` 이 참인 절차다.
"명시 배선" · "암묵 배선" 은 마지막 검사 결과의 `wiring` 이다.

### 4-1. 블록 팔레트와 단계 추가

- 블록 팔레트는 단계 추가 메뉴다 — 고른 노드 뒤의 `+ Add Step after <N>`, 빈 절차의 `+ Add First Step`
- 메뉴 항목은 `schema.blocks` 의 블록이고, 그 순서를 따른다
- UI 가 갖는 것은 블록별 표시뿐이다

  | 블록 | 이름표 |
  |---|---|
  | `agent` | `Call Agent` |
  | `script` | `Run Script` |
  | `prompt` | `Run Prompt` |
  | `gate` | `Human Gate` |
  | `workflow` | `Run Workflow` |

  표에 없는 블록은 종류 이름과 기본 아이콘으로 그린다
- 블록을 고르면 추가 폼이 열린다
  - 제목. 기본값은 이름표다
  - 그 블록의 `keys` 가운데 편집 중인 실행 방식이 받는 키. 입력은 2-2 를 따른다
- `Add` 는 값 검사 없이 고른 단계 뒤에 새 단계를 끼운다. 새 단계 id 는 지금처럼 `step-<N>` 이다
- 빠진 값은 다음 검사가 그 노드에 오류로 보인다
- 명시 배선 절차에 끼운 단계는 `next` 가 없다. 이어야 검사를 통과한다

### 4-2. 노드와 핸들

단계 노드

- 머리(아이콘·번호·제목·오류 표지)와 본문(실행 정보·지시 요약·블록 이름표·`Default` 표지)은 지금과 같다
- 시작 단계(검사 결과의 `start`)에 `Start` 표지를 붙인다
- 입력 종류가 `role` · `command` 인 값(역할·명령)은 지금처럼 실행 정보로 보인다
- 그 블록 `keys` 의 값 가운데 입력 종류가 `role` · `command` · `markdown` · `fixed` 가 아닌 것을 `키 값` 꼴의 작은 태그로 보인다
- 입력 종류가 `workflow` 인 키에 값이 있으면 `Open` 을 보인다 (4-9)

들어오는 핸들은 노드마다 왼쪽에 하나다.

나가는 핸들

- 배선을 받지 않는 절차: 노드마다 오른쪽에 하나
- 배선을 받는 절차: outcome 마다 하나. 오른쪽에 세로로 놓고 핸들마다 outcome 이름표를 붙인다
  - 순서: 검사 결과의 그 단계 `outcomes` → 단계의 `next` 에 있으나 그 목록에 없는 키(키 순서) → `schema.wildcard`
  - 같은 키는 한 번만 놓는다
  - 이어지지 않은 핸들은 빈 표지로 보인다

끝 상태 노드

- `schema.ends` 의 상태마다 하나다. 들어오는 핸들만 있다
- 명시 배선이면 셋 다 늘 보인다 — 이을 자리다
- 그 밖에는 그리는 선이 닿는 것만 보인다

### 4-3. 선

| 절차 | 그리는 선 | 모양 |
|---|---|---|
| 배선을 받지 않는다 | 단계마다, 실효 배선의 대상 가운데 `stop` 이 아닌 서로 다른 대상마다 한 선 | 점선, 이름표 없음 |
| 배선을 받는다 · 암묵 배선 | 실효 배선에서 대상이 `stop` 이 아닌 outcome 마다 한 선. 그 outcome 핸들에서 나간다 | 점선, outcome 이름표 |
| 배선을 받는다 · 명시 배선 | `next` 의 outcome 마다 한 선 | 실선, outcome 이름표 |

- 실효 배선은 마지막 검사 결과의 `steps[].next` 다
- 단계 사이의 선은 고리를 이룰 수 있다(루프). 자기 자신으로 가는 선도 그린다
- 암묵 배선이면 캔버스 아래에 한 줄을 보인다: `암묵 배선 — 선이 없는 outcome 은 stop 으로 간다`

### 4-4. 연결 편집

출처가 프로젝트 레이어이고 배선을 받는 절차에서만 한다.

- 잇기: outcome 핸들에서 단계 노드나 끝 상태 노드로 끌어 놓는다
  - 그 단계의 `next[<outcome>]` 이 그 대상(단계 id 또는 끝 상태)이 된다
  - 이미 이어져 있으면 대상을 바꾼다. 핸들 하나에 선은 하나다
- 다시 잇기: 선의 끝을 다른 노드로 옮기면 대상을 바꾼다
- 끊기: 선을 고르고 `Delete` · `Backspace` 를 누르면 그 outcome 을 `next` 에서 뺀다
  - 마지막 outcome 을 빼도 `next` 는 빈 표로 남는다. 절차가 몰래 암묵 배선으로 돌아가지 않게 한다.
    빈 표도 명시 배선으로 보고 `harness steps` 가 그대로 쓰는 것은 #208 이 정한다
- 자기 자신으로 잇기도 받는다. 성립하는지는 검사가 정한다
- 끝 상태에서 나가는 선은 없다

첫 연결 — 암묵 배선 절차에 배선 변경이 처음 오면

- 배선 변경은 잇기·다시 잇기·끊기, 그리고 패널의 배선 변경(4-7)이다
- 먼저 모든 단계의 `next` 를 검사 결과의 실효 배선(`steps[].next`)으로 채운다. 실효 배선이 없는 단계는 `next` 없이 둔다
- 그 뒤에 그 변경을 적용한다. 이때부터 절차는 명시 배선이다

검사 결과가 지금 편집 상태의 것이 아니면(편집 뒤 결과가 아직 오지 않았다) 배선 변경을 받지 않는다.
그동안 핸들과 선은 직전 결과로 그린다. UI 는 어느 편집 상태로 검사를 불렀는지 기억해 결과와 맞춘다.

### 4-5. 자동 배치

노드 위치는 계산으로 정하고 저장하지 않는다. 같은 입력이면 같은 위치다.

- 입력: 단계 목록 순서, 시작 단계, 단계 사이의 실효 배선, 그리는 끝 상태, 노드 폭
- 단계 층
  - 시작 단계는 층 0 이다
  - "앞으로 가는 선" 은 목록에서 자기보다 앞에 있는 단계에서 오는 선이다
  - 시작 단계가 아닌 단계의 층은, 앞으로 가는 선으로 이어 주는 단계들의 층 + 1 가운데 가장 큰 값이다
  - 앞으로 가는 선을 하나도 받지 않으면 목록에서 바로 앞 단계의 층 + 1 이다
  - 뒤로 가는 선(같거나 앞 단계로 가는 선)은 층 계산에 쓰지 않는다
- 같은 층의 단계는 목록 순서로 위에서 아래로 놓는다. 층마다 세로 가운데를 맞춘다
- 층의 가로 위치는 앞 층들의 가장 넓은 노드 폭과 간격을 더한 것이다
- 끝 상태 노드는 마지막 단계 층 다음 층에 `schema.ends` 순서로 위에서 아래로 놓는다
- 노드 폭은 지금의 계산(`nodeW` — 스크립트 명령 길이에 따라 넓힌다)이다. 노드 높이는 재지 않고 고정 줄 높이를 쓴다
- 암묵 배선 절차는 단계마다 층 하나라 지금처럼 가로 한 줄이다
- 절차를 바꾸거나 단계 수가 바뀌면 화면을 맞춘다 (지금과 같다)

### 4-6. 순서 바꾸기·단계 지우기

- 암묵 배선 절차는 노드를 끌어 순서를 바꾼다 (지금과 같다)
- 명시 배선 절차는 노드를 끌 수 없다
  - 순서는 패널의 `← Earlier` · `Later →` 로 바꾼다
  - 순서를 바꿔도 선은 그대로다. 목록 순서는 단계 번호와 시작 단계만 정한다(#208)
- 단계를 지우는 방법은 패널의 `Delete`, 또는 노드를 고르고 `Delete` 키다. 다른 단계의 `next` 는 고치지 않는다
  - 지운 단계를 가리키던 outcome 은 검사가 그 핸들에 오류로 보인다

### 4-7. 오른쪽 패널

읽기 모드

- 지금처럼 본문과 지시를 보인다
- 그 블록 `keys` 의 값과 "Other keys" 를 보인다
- 배선을 받는 절차면 `Next` 절을 보인다. outcome 마다(4-2 의 핸들 순서) 대상을 적는다 — `<번호>. <제목>` 또는 끝 상태

편집 모드

- 기본 단계(`builtin`)에서는 지시(`text`)와 배선만 고친다. 다른 키 입력은 읽기 전용이다
- 그 밖의 단계에서는 제목, 그리고 그 블록 `keys` 가운데 편집 중인 실행 방식이 받는 키를 2-2 의 입력으로 고친다
- `Next` 절(배선을 받는 절차)
  - outcome 마다 대상을 고른다. 후보는 단계들(`<번호>. <제목>`), 끝 상태, `(none)` 이다
  - `(none)` 은 그 outcome 을 `next` 에서 뺀다
  - `open` 인 단계는 맨 아래에 새 outcome 입력(이름 + 대상 + `Add`)을 둔다. 이름이 비었거나 이미 있으면 `Add` 를 막는다
  - 배선 변경은 캔버스와 같은 규칙(4-4 의 첫 연결, 결과 대기)을 따른다

`Agent Setting` 링크, `Delete`, 순서 버튼은 지금과 같다.

### 4-8. 실행 방식 선택

- 툴바에 실행 방식을 고르는 단추 묶음을 둔다. 값은 `schema.execute.modes` 의 `value` 이고, 그 순서를 따른다
- 읽기 전용 절차에서는 지금 값을 보이기만 한다
- 바꾼 실행 방식이 받지 않는 키가 단계에 있으면 확인 대화상자를 연다
  - 받지 않는 키: 배선을 받지 않는데 있는 `next`, 그리고 `blocks[].keys[].execute` 에 그 실행 방식이 없는 키
  - 대화상자는 지울 것을 단계별 키 이름으로 보인다
  - 확인하면 그 키들을 지우고 실행 방식을 바꾼다. 취소하면 바꾸지 않는다
- 실행 방식은 편집 상태의 일부다
  - 바꾸면 저장하지 않은 변경이다
  - `Revert` 가 되돌린다
  - 검사와 저장은 2-5 대로 넘긴다
- 새 절차 대화상자에 실행 방식 선택을 더한다. 기본값은 `schema.execute.default` 다

### 4-9. 하위 절차로 이동

- 입력 종류가 `workflow` 인 키에 값이 있는 단계는 노드와 패널에 `Open <절차>` 를 보인다
- 누르면 캔버스가 그 절차로 바뀐다
  - 떠나온 절차를 기억해 툴바에 `← <절차>` 를 보인다
  - 여러 번 들어가면 들어온 차례의 반대로 돌아온다
  - 절차 고르기 메뉴로 절차를 바꾸면 기억을 비운다
- 그 절차가 `schema.workflows` 에 없으면 `Open` 은 꺼진다
- 저장하지 않은 편집은 절차별로 남는다 (지금과 같다)

### 4-10. 검증 오류 표시

- `--dry-run --json` 을 부르는 때는 두 번이다. 절차를 열 때, 그리고 편집이 멈춘 뒤(지금처럼 400ms)
  - 단계가 없는 초안은 부르지 않는다
  - 늦게 온 옛 결과는 버린다 (지금과 같다)
- `at.step` 이 있으면 그 노드에 오류 표지와 문장 첫 줄을 붙인다 (지금과 같다)
- `at.outcome` 도 있으면 그 outcome 의 선을 오류 색으로 그린다. 선이 없으면 그 핸들을 오류 색으로 그린다
- 위치가 없는 오류는 패널의 단계 목록 위에 보인다 (지금과 같다)
- 상태 표시(`Checking…` · `Valid` · `Saved` · `1 error`)는 지금과 같다
  - 열 때 검사가 거부하면(저장된 절차가 성립하지 않는다) `1 error` 다
- 정규식으로 위치를 찾는 함수(`locate`)를 지운다. UI 는 검사 규칙을 더하지 않는다

### 4-11. 커맨드 표기

| 자리 | 표기 |
|---|---|
| 절차 고르기 메뉴의 항목 | `schema.workflows.<절차>.command` 가 있으면 `/<command>`, 없으면 `<절차>`. 초안은 고른 실행 방식의 `command` 가 참이면 `/<이름>` |
| 빈 절차 안내, 패널의 단계 목록 머리 | 같은 규칙 |
| 새 절차 대화상자 안내 | 고른 실행 방식의 `command` 가 참이면 `커맨드 /<이름> 이 함께 만들어진다. 단계를 더하고 저장해야 설정에 들어간다.`, 거짓이면 `커맨드 없이 harness run <이름> <이슈> 로 시작한다. 단계를 더하고 저장해야 설정에 들어간다.` |
| 이름 변경 대화상자 안내 | 커맨드가 있으면 지금 문구, 없으면 `절차 문서와 이 절차에 더한 지시 파일이 새 이름을 따라간다.` |
| 삭제 대화상자 | 커맨드가 있으면 `/<이름> 절차와 그 커맨드를 지운다.`, 없으면 `<이름> 절차를 지운다.` 메모 경로 안내는 지금과 같다 |

### 4-12. Procedure 보기

- 생성된 절차 문서를 지금처럼 마크다운으로 그린다
- #208 이 배선 있는 절차 문서에 넣는 Mermaid 블록은 코드 블록으로 보인다. "다음" 표는 GFM 표로 보인다
- 그래프 그림은 Canvas 보기가 그린다

## 5. 서버 액션과 순수 함수

### 5-1. `src/ui/lib/harness.js` · `actions.js`

| 함수 | 바뀌는 것 |
|---|---|
| `harness(dir, args, { json })` | `json` 이 참이면 종료 코드와 상관없이 표준 출력만 JSON 으로 읽어 `{ ok, data }` 를 돌려준다. 읽지 못하면 `{ ok: false, out }`(지금 모양)이다 |
| `checkSteps(project, workflow, payload)` | 2-5 의 객체를 받아 `harness steps <절차> <JSON> --dry-run --json` 을 부른다 |
| `saveSteps(project, workflow, payload)` | 2-5 의 객체를 받아 `harness steps <절차> <JSON>` 을 부른다. 분리(3-2)도 이것을 쓴다 |

- 단계에서 `builtin` · `body` 를 빼는 일은 두 액션이 한다 (지금과 같다)

### 5-2. `src/ui/lib/flow.js`

React 를 import 하지 않는 순수 함수다. 입력을 바꾸지 않고 새 값을 돌려준다.

| 함수 | 하는 일 |
|---|---|
| `nodeW(step)` | 노드 폭. `FlowCanvas.js` 의 계산을 옮긴다 |
| `handles(step, outline, wildcard)` | 나가는 핸들의 outcome 목록 (4-2 의 순서) |
| `edgesOf(steps, outline, { wiring })` | 그릴 선 목록. 선마다 출발 단계·outcome·대상·점선 여부다 (4-3) |
| `layout(steps, edges, ends, start)` | 노드 id → 위치 (4-5) |
| `expand(steps, outline)` | 실효 배선을 모든 단계의 `next` 로 펼친 목록 (4-4) |
| `connect(steps, id, outcome, target)` · `disconnect(steps, id, outcome)` | `next` 한 칸을 바꾸거나 뺀 목록. 마지막 칸을 빼도 `next` 는 빈 표로 남는다 |
| `strip(steps, mode, blocks)` | 실행 방식이 받지 않는 키를 걷은 목록과 걷은 것(단계 id → 키 이름들) (4-8) |

- `outline` 은 2-3 의 `wiring` · `start` · `steps` 다. `mode` 는 `schema.execute.modes` 의 항목이다
- React Flow 의 노드·선 객체로 바꾸는 일은 `FlowCanvas.js` 가 한다

## 6. README · 도움말

README

- 명령 표의 `harness steps` 행: `--dry-run --json` 이면 검사 결과와 단계별 outcome·실효 배선을 JSON 으로 낸다
- 명령 표의 `harness schema` 행: 블록 목록·끝 상태·와일드카드 키·실행 방식 목록과 절차별 커맨드도 낸다
- UI 표의 Workflows 행
  - 무엇을: 블록을 팔레트에서 끼우고 outcome 핸들을 이어 분기·루프를 만든다. 실행 방식을 고르고, 하위 절차로 이동한다.
    아래 레이어가 준 절차는 읽기 전용이고 프로젝트로 분리해야 고친다. 절차 끝에 붙는 이 프로젝트의 지시를 고친다
  - 쓰기 경로: `harness steps`(편집 중에는 `--dry-run --json` 으로 검사만)
- "문서는 읽기가 기본이다" 단락의 문장 "노드에서 고치는 것은 덧붙인 지시(`text`)뿐이다" →
  "기본 단계에서 고치는 것은 덧붙인 지시(`text`)와 배선뿐이다"

`src/ui/lib/help.js` 에 두 줄을 더한다.

| 키 | 문구 |
|---|---|
| `workflow.execute` | `agent는 오케스트레이터가 절차 문서를 읽고 따릅니다. driver는 하네스가 배선대로 돌리고, 슬래시 커맨드 없이 harness run으로 시작합니다.` |
| `workflow.source` | `아래 레이어(내장 기본값·preset)가 준 절차는 읽기 전용입니다. 프로젝트로 분리하면 고칠 수 있고, 그 뒤로는 아래 레이어의 갱신이 닿지 않습니다.` |

## 7. 회귀 테스트

### 7-1. `render-test.sh` — 새 UT 블록

| 블록 | 확인하는 것 |
|---|---|
| schema 가 블록 편집에 필요한 표를 낸다 | `blocks` · `ends` · `wildcard` · `execute` 가 있다. 모든 블록의 모든 키에 `input` 이 있고 2-2 의 어휘 안에 있다. `choice` 키에만 `choices` 가 있다 |
| schema 의 절차별 커맨드와 기본 실행 방식 | 프로젝트가 만든 agent 절차는 `command` 가 그 이름이다. driver 절차와 커맨드 파일이 없는 기본 절차는 `null` 이다. `execute` 키가 없는 절차의 `workflows.<절차>.execute`(#208)가 `schema.execute.default` 와 같다 |
| 검사 JSON 이 통과한 명시 배선 절차를 그린다 | 종료 코드 0. `ok` 참, `wiring` 이 `explicit`, `start` 가 첫 단계, 단계별 `outcomes` · `open` · `next`. 설정 파일 바이트가 그대로다 |
| 검사 JSON 이 암묵 배선을 펼친다 | `next` 가 없는 절차에서 `wiring` 이 `implicit` 이다. 단계마다 `next` 가 암묵 배선을 펼친 값이다 |
| 검사 JSON 의 블록별 outcome 집합 | gate 는 선택지, 스키마를 고른 agent 는 그 필드 값, 저장된 하위 절차를 부르는 workflow 는 `done` · `stop` · `handoff` 다. script 는 `open` 참이다 |
| 검사 JSON 이 거부를 알린다 | 종료 코드 2. 표준 출력은 JSON 하나이고 표준 오류는 비어 있다. `error` 는 같은 입력의 텍스트 `--dry-run` 표준 오류와 같다. 거부해도 `steps` 가 있다 |
| 오류 위치를 `at` 으로 읽는다 | 없는 대상을 가리키는 outcome 의 `at` 이 그 단계 번호와 outcome 키다. `.` 이 든 outcome 이름도 그 이름 그대로다. 단계 위치만 있는 오류는 `at.outcome` 이 `null` 이다. 절차 전체의 오류(`execute` 값이 틀리다)는 `at.step` · `at.outcome` 이 둘 다 `null` 이다 |
| `--json` 은 `--dry-run` 과만 | `--dry-run` 없이 주면 종료 코드 2 이고 설정 파일이 그대로다 |
| 형식이 틀린 입력은 `--json` 이어도 문장으로 거부한다 | 종료 코드 2. 표준 출력이 비어 있다 |
| UI 가 넘기는 객체 형식의 왕복 | `{title, execute, steps}` 로 저장한 뒤 `harness steps` 가 낸 단계(`builtin` · `body` 를 뺀 것)와 schema 의 `title` · `execute` 가 넘긴 값과 같다. driver 로 저장된 절차에 `"execute": "agent"` 를 넘기면 절에 `execute = "agent"` 가 적히고 schema 의 `execute` 가 `agent` 다 |

### 7-2. `src/ui/lib/flow.test.js`

- `handles` — 알려진 outcome → `next` 에만 있는 키 → 와일드카드 순서다. 중복이 없다
- `edgesOf`
  - 배선을 받지 않으면 단계마다 `stop` 이 아닌 대상에 하나씩이고 이름표가 없다
  - 암묵 배선이면 `stop` 으로 가는 outcome 의 선이 없다
  - 명시 배선이면 `next` 의 모든 칸이 선이다
- `layout`
  - 직선 절차는 한 줄이고 x 가 목록 순서로 커진다
  - 분기 대상은 같은 층에서 목록 순서로 위에서 아래다
  - 뒤로 가는 선은 층을 바꾸지 않는다
  - 앞으로 가는 선을 받지 않는 단계는 앞 단계 층 + 1 이다
  - 끝 상태는 마지막 층 다음이다
  - 같은 입력이면 같은 출력이다
- `expand` — 실효 배선을 모든 단계에 채운다. 실효 배선이 없는 단계는 `next` 가 없다. 입력 목록이 그대로다
- `connect` · `disconnect` — 대상을 바꾸고 뺀다. 마지막 칸을 빼면 `next` 가 빈 표다. 다른 단계는 그대로다
- `strip` — 배선을 받지 않는 실행 방식에서 `next` 를 걷는다. `execute` 에 그 실행 방식이 없는 키를 걷는다. 걷은 목록이 맞다

## 8. 보호 문서 개정 범위

분해의 task 하나가 이 범위 안에서 고친다.

| 문서 · 위치 | 고칠 문안 |
|---|---|
| `.ai/project/architecture.md` "구성 요소" 의 `src/ui/` | 화면 나열의 `Workflows(단계 캔버스)` → `Workflows(블록 그래프 — outcome 핸들 연결·실행 방식·하위 절차 이동. 아래 레이어가 준 절차는 읽기 전용)` |
| 같은 줄의 끝 문장 | "파일 경로는 짓지 않고 `harness schema` 에서 받는다" 뒤에 "블록 목록·단계별 outcome·실효 배선도 CLI(`harness schema` · `harness steps --dry-run --json`)에서 받는다" 를 잇는다 |
| `architecture.md` "새 코드를 둘 곳" | 줄 하나를 더한다: "새 단계 키 → 단계 키 정의에 그 키의 UI 입력 종류도 함께 둔다(`harness schema` 의 `blocks`)" |
| `architecture.md` "계층과 의존 방향" 의 `src/ui/` 줄 | "UI 는 파일 경로를 짓지 않고 `harness schema` 에서 받는다" → "UI 는 파일 경로·블록 종류·outcome·배선 해석을 짓지 않고 CLI 에서 받는다" |
| `.ai/project/testing.md` "무엇을 어느 수준으로 검증하나" 의 UI 줄 | 순수 함수 나열 `라벨·경로 검사·정적 문서 검사·차트 좌표·doctor 문구` 에 `절차 그래프 변환·자동 배치` 를 더한다 |
| `.ai/project/glossary.md` 용어 표 | 행을 더한다: `프로젝트로 분리` — 아래 레이어가 준 절차를 프로젝트 레이어(`harness.toml`)에 통째로 옮겨 적는 UI 동작. 그 뒤로 아래 레이어의 그 절차 갱신은 이 프로젝트에 닿지 않는다 |
| `.ai/project/scope.md` "할 수 있는 일" 의 웹 UI 줄 | "웹 UI 로 설정·절차·…" 의 `절차` → `절차(블록을 이어 분기·루프를 만든다)` |

## 9. 다른 이슈와의 관계

| 이슈 | 관계 |
|---|---|
| #206 | 명령 코드가 놓이는 모듈을 정한다. 이 명세의 CLI 변경은 그 모듈에 들어간다 |
| #207 | 절차별 출처 레이어를 `harness schema` 의 값 출처(`sources`)로 내고, 레이어 id 를 표시 이름으로 바꾸는 함수를 `labels.js` 에 둔다. 이 명세는 그 둘로 편집 권한을 가르고 출처를 보인다 (3절). Harness 화면 등 설정 값의 출처 표시는 #207 이 한다 |
| #208 | 블록·outcome·배선·끝 상태·암묵 배선·시작 단계·실행 방식별 허용 키·render 검증과 그 오류 위치 표기, `harness steps` 의 키 보존과 객체 형식의 `execute`, `harness schema` 의 `output_schemas` · `workflows.<절차>.execute` 를 정한다. 이 명세는 그 계산을 schema 의 새 키와 `--dry-run --json` 으로 내고 UI 가 그린다. `at` 은 그 오류 위치 표기에서 읽는다 (2-4) |
| #212 | 기본 `work` · `review-loop` 를 driver 절차로 바꾼다. 출처가 아래 레이어이면 두 절차는 읽기 전용으로 보이고, `work` 의 workflow 블록에서 `review-loop` 로 이동한다. #212 가 단계 키를 더하면 그 키의 입력 종류도 함께 정한다 |
| #216 | preset 레이어의 id 와 `labels.js` 의 그 표시 이름을 정한다. preset 에서 온 절차는 출처가 `project` 가 아니므로 읽기 전용으로 보이고, 화면 문구의 레이어는 그 표시 이름이다. 이 명세에서 바꿀 것은 없다 |

이 변경에는 결정 기록이 없다. 블록 그래프의 의미는 #208 의 결정 기록이 갖고, UI 의 쓰기 경계는 ADR 0009 그대로다.

## 10. 한계

- 분리한 절차를 아래 레이어로 되돌리는 UI 동작은 없다. 프로젝트 `harness.toml` 에서 그 절을 지우면 아래 레이어 절차로 돌아간다
  - 하네스 기본 절차는 `harness steps --delete` 가 거부하므로 사람이 지운다
- 읽기 전용은 UI 의 동작이다. `harness steps` 를 직접 부르면 아래 레이어 절차도 프로젝트 레이어로 교체된다(ADR 0007 이 프로젝트에 준 권한)
- 검사는 첫 오류만 알린다. 여러 곳이 틀려도 한 곳씩 보인다
- workflow 블록은 하위 절차를 저장된 설정에서 찾는다. 새 하위 절차를 저장하지 않은 채 상위 절차로 돌아오면, 그 블록은 outcome 을 모르는 단계(`open`)로 보인다
- 자동 배치는 노드 높이를 재지 않는다. 본문이 긴 노드는 이웃과 겹쳐 보일 수 있다
- 입력 종류가 `fixed` 인 키(표 값)와 `max_steps` · `max_visits` 같은 절차 키는 UI 에서 고치지 않는다. 저장할 때 보존되는 것은 #208 의 몫이다
- 출력 스키마는 고르기만 한다. 스키마 파일을 UI 에서 쓰지 않는다
