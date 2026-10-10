# 절차 블록 그래프와 결정론 드라이버

절차는 블록(script · agent · prompt · gate · workflow)과 **outcome → 다음 단계 배선**으로 정의된다.
절차마다 실행 방식(`execute`)을 고른다. `agent`(기본값) 절차는 지금처럼 오케스트레이터가 생성된 절차 문서를 따라 돈다.
`driver` 절차는 하네스의 드라이버가 그래프를 결정론으로 실행한다 — 블록 하나를 돌려 outcome 을 얻고, 배선이 가리키는
다음 단계로 간다. 설정은 배선만 하고 판단은 블록 안에 둔다. 조건식 언어는 없다.

기준 코드는 #206(하네스 패키지 `src/harness/`), #207(개인 레이어까지 병합한 실효 설정과 실행 시점 불변식 검사),
#96(클론 키)이 들어간 통합 브랜치다. 함수가 어느 모듈에 있든 이 명세는 함수 단위로 적는다.
이슈별 worktree 실행은 `docs/spec/71-issue-worktree-run.md`(이하 71 명세), 클론 키와 등록부는
`docs/spec/96-machine-local-state-key.md`(이하 96 명세)가 정한다.

결정 기록: 절차는 블록 그래프이고 하네스가 실행한다 (분해에서 작성)

정본 위치:

| 대상 | 정본 |
|---|---|
| 절차 정의 해석 · render 검증 · 배선 · 자리표시 · 스키마 검증 · 드라이버 · 실행 상태 | `src/harness/workflow/` |
| 동봉 구조화 출력 스키마 | `src/harness/schemas/<이름>.json` (고정 사본 `.harness/lib/harness/schemas/`) |
| 프로젝트 구조화 출력 스키마 | 대상 리포의 `.ai/project/schemas/<이름>.json` |
| `harness run` · `harness steps` · `harness schema` · `harness doctor` | #206 이 정한 명령 모듈 |
| 절차 문서 · 커맨드 생성(`workflow_doc()` · `plan()` · `command_rows()` · 관리 파일 설치 판정) | #206 이 정한 render 자리 |
| 역할 실행기 | `src/templates/managed/script/run-agent.py` (대상 리포의 `script/run-agent.py`). #213 이 하위 명령 `harness run-agent` 로 옮긴 뒤에는 그 명령 모듈이고 `script/run-agent.py` 는 그 shim 이다 |
| 실행 계획의 `driver` · `prompt` 자리 | #207 의 실행 계획 함수(`run_plan()`) |
| 벤더 선언 | `src/templates/vendors.toml` |
| 지표 집계(`metrics_report()`) | #206 이 정한 metrics 자리 |
| 내장 기본값 주석 | `src/templates/defaults.toml` (#207) |
| UI doctor 문구 | `src/ui/lib/doctor.js` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/test/unit/` · `src/ui/lib/doctor.test.js` |
| 사람용 설명 | `README.md` · `src/templates/managed/docs/workflow/` · `src/templates/managed/script/README.md` |

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

- `execute` 를 적지 않은 절차는 agent 절차다. 내장 기본값의 세 절차(`prework` · `work` · `retro`)는 agent 절차로 남고,
  그 절차 문서와 커맨드는 이 변경 전과 바이트 단위로 같다
- agent 절차의 `harness run` 은 지금과 같다 — 오케스트레이터를 대화형으로 띄우고 그 종료 코드로 끝난다.
  하위 절차로만 불리는 agent 절차의 거부와 새 플래그의 거부만 더해진다 (7-1)
- agent 절차가 새로 받는 블록은 workflow 하나다. 배선과 블록 값(`next` · `on` · `schema` · `set` · `options` · `access`),
  상한(`max_steps` · `max_visits`), 출력 참조(`{steps.…}`)는 driver 절차에서만 받는다 — agent 절차에 있으면 render 가 거부한다
- driver 절차에는 슬래시 커맨드가 없다. 진입점은 `harness run <절차> <이슈>` 하나다 (10절)
- driver 실행이 끝 상태에 닿지 않고 멈추면 기기 로컬에 실행 상태 파일이 남는다 (8절)
- `harness steps` 가 단계와 절차의 키를 전부 보존한다 (11-1)
- 벤더 선언에 키 셋(`agent` · `driver_write` · `structured`)이 생기고 claude 의 `headless` 템플릿이 `agent` 키를 쓴다.
  렌더되는 역할 argv 는 지금과 같다 (7-4)
- 실행 계획에 역할마다의 `driver` 항목과 최상위 `prompt` 항목이 더해진다. 기존 필드는 그대로다 (7-4)

## 2. 절차 설정

### 2-1. 절차 키

```toml
[workflows.review-loop]
title = "리뷰 루프"
execute = "driver"
max_steps = 200
max_visits = 30
steps = [
  { id = "review", type = "script", title = "리뷰", run = "script/review-mr.sh {mr}",
    next = { "0" = "done", "1" = "fix", "2" = "stop", "3" = "handoff" } },
  { id = "fix", type = "agent", title = "수정", role = "developer", text = "MR {mr} 의 리뷰를 반영한다",
    next = { ok = "review", failed = "stop" } },
]
```

`{mr}` 은 이 절차를 workflow 블록으로 부르는 절차가 `set` 으로 올린 변수다 (4-1).

| 키 | 값 | 기본값 | 받는 절차 |
|---|---|---|---|
| `title` | 한 줄 문자열 | 없음 — 절차 이름을 쓴다 | 전부 |
| `execute` | `"agent"` · `"driver"` | `"agent"` | 전부 |
| `steps` | 단계 배열 (2-2) | — | 전부. 비어 있어도 되는 것은 하위 절차뿐이다 (2-5) |
| `max_steps` | 1 이상 1000 이하 정수 | `200` | driver |
| `max_visits` | 1 이상 1000 이하 정수 | `30` | driver |

- driver 절차의 절에 표에 없는 키가 있으면 render 가 거부한다. agent 절차는 모르는 키를 지금처럼 읽지 않고 넘긴다
- 상한은 `harness run` 이 시작한 절차의 값만 쓴다 (7-6). 하위 절차의 상한 키는 그 절차를 직접 시작할 때만 쓰인다

### 2-2. 단계 키와 블록

블록은 단계의 `type` 이 정한다. 키마다 받는 블록:

| 키 | script | agent | prompt | gate | workflow |
|---|---|---|---|---|---|
| `id` · `type` · `title` | 필수 | 필수 | 필수 | 필수 | 필수 |
| `text` | 선택 | 선택 | 조각이 없으면 필수 | 선택 | 선택 |
| `run` | 필수 | | | | |
| `role` | | 필수 | | | |
| `workflow` | | | | | 필수 — 부를 절차 이름 |
| `schema` † | | 선택 — 스키마 이름 (5절) | | | |
| `on` † | 선택 — `"exit"`(기본) · `"stdout"` | 선택 — 스키마의 필드 이름 | | | |
| `access` † | | | 선택 — `"read-only"`(기본) · `"write"` | | |
| `options` † | | | | 선택 — outcome 이름 배열. 기본 `["approve", "reject"]` | |
| `next` † | 2-3 | 2-3 | 2-3 | 2-3 | 2-3 |
| `set` † | 선택 — `on = "exit"` 일 때 (4-1) | 선택 — 스키마가 있을 때 (4-1) | | | |

- † 는 driver 전용이다. agent 절차의 단계에 있으면 render 가 거부한다
- driver 절차의 단계에 빈칸인 키나 표에 없는 키가 있으면 render 가 거부한다. agent 절차는 † 를 뺀 모르는 키를 지금처럼 넘긴다
- 단계 id 규칙(영소문자 · 숫자 · `-`, 절차 안에서 하나)은 그대로다. 명시 배선 절차에서는 `done` · `stop` · `handoff` 를 id 로 쓸 수 없다

### 2-3. 배선 — `next`

- `next` 는 outcome → 대상 표다
  - 키: outcome 이름(`^[A-Za-z0-9_.-]{1,64}$`) 또는 `"*"`(표에 없는 outcome 전부)
  - 값: 같은 절차의 단계 id 이거나 끝 상태

| 끝 상태 | 뜻 |
|---|---|
| `done` | 성공 |
| `stop` | 실패 — 보고하고 멈춘다 |
| `handoff` | 리뷰 요청을 연 채 사람에게 넘긴다 |

- **배선은 절차 단위다.** 한 단계라도 `next` 가 있으면 그 절차의 모든 단계가 `next` 를 가진다(명시 배선).
  어느 단계에도 없으면 암묵 배선이다 (2-4)
- 빈 표(`next = {}`)도 `next` 가 있는 것이다. 그 단계는 outcome 이 하나도 이어지지 않은 명시 배선이고, 절차가 암묵 배선으로 돌아가지 않는다.
  그런 단계는 render 의 완전성 · 끝 검사를 통과하지 못한다 (6절)
- **시작 단계는 목록의 첫 단계다.** 목록 순서는 시작 단계와 문서의 단계 번호만 정한다 — 명시 배선 절차에서 순서를 바꿔도 배선은 그대로다
- 실행 때 outcome 이 표의 키에 있으면 그 값으로, 없고 `"*"` 가 있으면 그 값으로 간다. 둘 다 없으면 실행 전체가 `stop` 으로
  끝난다 — 이유 `outcome <outcome> is not wired`
- `on` 은 명시 배선 절차에서만 쓴다

### 2-4. 암묵 배선

`next` 가 없는 driver 절차는 아래처럼 잇는다. agent 절차의 지금 의미(성공하면 다음 단계, 실패하면 멈춤, 마지막 단계가 성공하면 끝)와 같다.

| 블록 | 다음 단계로 (마지막 단계면 `done`) | `stop` | `handoff` |
|---|---|---|---|
| script | `0` | 그 밖 | — |
| agent | `ok` | `failed` | — |
| prompt | `ok` | `failed` | — |
| gate | `options` 의 첫째 | 그 밖 | — |
| workflow | `done` | `stop` | `handoff` |

### 2-5. 하위 절차와 확장 지점

- **하위 절차**는 어느 절차의 workflow 블록이 `workflow` 키로 가리키는 절차다. workflow 블록은 그 절차를 그 자리에서 실행하고,
  하위 절차의 끝 상태가 그 블록의 outcome 이다
- 하위 절차는 같은 설정의 절차다. 부르는 절차와 `execute` 가 같아야 한다. 자기 자신이나 자기를 (거슬러 올라가며) 부르는 절차를 부를 수 없다
- **단계가 없는 절차는 하위 절차일 때만 허용한다** — 확장 지점이다. 불리면 블록을 하나도 돌리지 않고 곧바로 `done` 으로 끝난다
- agent 하위 절차는 커맨드가 없고 `harness run` 으로 직접 시작하지 않는다 (7-1, 10절). driver 하위 절차는 자기 `set` 에 없는 변수를
  자리표시로 쓰지 않으면 직접 시작할 수 있다 — 쓰면 부르는 절차가 그 값을 올리므로 직접 시작을 거부한다 (7-1)

## 3. 블록 계약

블록 하나는 입력(자리표시를 푼 단계 값)으로 실행되어 outcome 하나와 출력(JSON 객체 하나, 없을 수 있다)을 낸다.
이 절은 driver 절차의 의미다. agent 절차의 블록은 지금처럼 절차 문서의 지시로 돈다.

| 블록 | 실행 | outcome | 출력 |
|---|---|---|---|
| script | 드라이버가 셸 없이 직접 | 종료 코드, `on = "stdout"` 이면 표준 출력의 첫 토큰 | 표준 출력 전체가 JSON 객체일 때 그 객체 |
| agent | 역할 실행기로 헤드리스 한 번 | 스키마와 `on` 이 있으면 그 필드 값, 아니면 `ok` · `failed` | 스키마가 있을 때 검증한 객체 |
| prompt | 역할 실행기로 오케스트레이터를 헤드리스 한 번 | `ok` · `failed` | 없음 |
| gate | 터미널에서 묻는다 | 고른 선택지 | 없음 |
| workflow | 하위 절차 실행 | 하위 절차의 끝 상태 | 없음 |

### 3-1. script

- `run` 을 POSIX 셸의 인용 규칙(`shlex.split`)으로 인자로 나눈 뒤 원소마다 자리표시를 푼다 (4-2). 셸을 거치지 않으므로
  파이프 · 리다이렉트 · `$` 확장이 없다. 그런 것이 필요하면 스크립트 파일로 뺀다
- 실행 디렉터리는 드라이버의 실행 디렉터리(하네스 루트, `--worktree` 면 worktree 의 실행 디렉터리)다
- 표준 입력은 비어 있다. 표준 오류는 그대로 흐른다. 표준 출력은 모았다가 블록이 끝나면 드라이버의 표준 출력에 그대로 낸다
- outcome

  | `on` | outcome |
  |---|---|
  | `"exit"` (기본) | 종료 코드의 10진 문자열. 시그널로 끝나면 `128 + 시그널 번호` |
  | `"stdout"` | 종료 코드가 0 이면 표준 출력을 공백으로 나눈 첫 토큰. 토큰이 outcome 이름 형식이 아니거나, 출력이 비었거나, 종료 코드가 0 이 아니면 outcome 이 없다 — `"*"` 만 받는다 |

- script 의 가능한 outcome 은 `next` 의 키가 선언한다. render 는 script 의 outcome 이 빠짐없이 이어졌는지 보지 않는다 (6절).
  실행 때 표에 없는 outcome 은 2-3 대로 간다
- 출력: `on = "exit"` 이고 표준 출력의 앞뒤 공백을 뺀 전체가 JSON 객체면 그 객체. 아니면 출력이 없다
- 드라이버의 환경에 7-9 의 네 변수를 더해 넘긴다. 그 밖의 값은 자리표시로만 넘긴다
- 에이전트 명령 가드가 걸리지 않는다 — 에이전트의 도구 호출이 아니다. 명령은 커밋된 설정에서 오고 git 훅은 그대로 걸린다

### 3-2. agent

- 역할 실행기로 그 역할을 헤드리스로 한 번 돌린다 (7-4). 러너가 `inproc` 인 역할도 오케스트레이터 벤더의 headless 로 돈다
- 프롬프트는 차례대로 이렇다
  1. 역할 지시 — 역할 실행기의 기본 지시와 같은 문장(역할 이름 · 계약 경로 `.ai/templates/<역할>.md` · 규칙 정본)
  2. `입력: 이슈 <이슈>`
  3. 단계의 `text` — 자리표시를 푼 것. 없으면 빠진다
  4. 스키마가 있으면 — 결과 끝에 그 스키마를 따르는 JSON 객체 하나를 info string 이 `json` 인 fenced 블록 하나로 내라는 지시와 스키마 원문
- outcome

  | 경우 | outcome |
  |---|---|
  | 역할 실행기의 종료 코드가 0 이 아니다 | `failed` |
  | 스키마가 없다 | `ok` |
  | 스키마가 있고 출력이 검증을 통과했다 | `on` 이 있으면 그 필드 값, 없으면 `ok` |
  | 스키마가 있고 출력을 꺼내지 못했거나 검증을 어겼다 (5-3) | `failed` |

- `failed` 는 예약된 outcome 이다 — `on` 필드의 열거값에 둘 수 없다
- 출력은 스키마를 통과한 객체다. 스키마가 없으면 출력이 없다
- 결과 본문은 블록이 끝나면 드라이버의 표준 출력에 그대로 낸다
- driver 에서는 모든 agent 블록이 CLI 로 돈다. 그래서 전용 스크립트(`entry`)를 선언한 역할(`code-reviewer`)은 러너와 상관없이
  agent 블록으로 부를 수 없다 — 리뷰는 script 블록이 리뷰 명령을 부른다. 회차는 그 명령 하나가 센다

### 3-3. prompt

- 역할 실행기로 오케스트레이터 벤더를 역할 없이 헤드리스로 한 번 돌린다. 권한은 단계의 `access`(기본 `read-only`)다 (7-4)
- 프롬프트는 차례대로 이렇다
  1. 이 리포의 절차 `<절차>` 의 단계 하나를 수행한다는 문장과 규칙 정본(`.ai/AI_AGENT.md`)
  2. `입력: 이슈 <이슈>`
  3. `## <제목>` 과 본문 — 조각(있으면, 절차 문서와 같은 render 치환을 거친 것)과 자리표시를 푼 `text`
- outcome: 역할 실행기의 종료 코드가 0 이면 `ok`, 아니면 `failed`. 출력 없음. 결과 본문은 표준 출력에 낸다

### 3-4. gate

- 터미널에서 묻는다 (7-5). outcome 은 고른 선택지다
- `options` 는 서로 다른 outcome 이름 1개 이상의 배열이다

### 3-5. workflow

- 하위 절차를 그 첫 단계부터 돈다. 하위 절차의 끝 상태(`done` · `stop` · `handoff`)가 outcome 이다
- 하위 절차는 바깥 절차의 변수를 읽기만 한다 (4-1). 하위 절차 안에서 `set` 이 올린 변수와 단계 출력은 그 실행 안에서만 보이고
  하위 절차가 끝나면 사라진다. workflow 블록의 출력은 없다

## 4. 데이터 — 절차 변수와 자리표시

### 4-1. 이름

| 자리표시 | 값 |
|---|---|
| `{issue}` | `harness run` 의 이슈 인자 |
| `{<변수>}` | 절차 변수 — 그 절차 실행에서 `set` 이 올린 값. 없으면 그것을 부른 절차 실행에서 찾는다(바깥으로 차례로) |
| `{steps.<id>.out.<키>}` | 같은 절차 실행에서 단계 `<id>` 가 가장 최근에 낸 출력의 최상위 키 |

- 변수 이름은 `^[a-z][a-z0-9_]{0,31}$` 이고 `issue` · `steps` 는 쓸 수 없다. 키 이름은 `^[A-Za-z_][A-Za-z0-9_]{0,63}$` 이다
- 필터 · 기본값 · 식 · 중첩 경로는 없다
- `set = { <변수> = "<키>" }` — 그 단계가 끝나면 출력의 최상위 키 값을 그 절차 실행의 변수에 둔다. 출력이 없거나 키가 없거나
  값이 null 이면 그 변수를 지운다. 출력이 있는 블록(`on = "exit"` 인 script, 스키마가 있는 agent)에만 쓴다
- 같은 단계가 다시 돌면 새 출력이 이전 출력을 대신한다. 출력 없이 끝나면 이전 출력도 없어진다

### 4-2. 쓰는 곳과 푸는 방법

- 자리표시는 `{` 와 `}` 사이가 영문자 · 숫자 · `_` · `.` · `-` 1자 이상이고, 앞뒤에 다른 중괄호가 붙지 않은 것이다.
  그 밖의 중괄호(`{}` · `{a: .b}` · `{{…}}`)는 글자 그대로다
- 푸는 곳: script 의 `run`(인자로 나눈 뒤 원소마다), agent · prompt · gate 의 `text`. 조각 본문과 제목은 풀지 않는다
- 값
  - 문자열은 그대로다. 빈 문자열도 값이다 — 자리표시 하나로 된 원소는 빈 인자 하나가 된다
  - 정수(불리언 제외)는 10진 문자열이다
  - 배열 · 객체는 압축 JSON 한 문자열이다 — 구분자 `,` · `:` 뒤에 공백이 없고, 키 순서는 출력 그대로이며, 비ASCII 문자를 이스케이프하지 않는다
  - 푼 값은 그 원소 안에 그대로 들어가고 인자 하나로 남는다 — 공백 · 따옴표 · `;` 가 있어도 셸이 해석하지 않는다
- 벤더 argv 템플릿을 푸는 규칙(`expand()`)과 같다 — 모르는 이름은 막고, 값은 원소를 나누지 않는다
- 순서: 단계 값은 먼저 절차 문서와 같은 render 치환(`{{VAR}}`)을 거치고, 그 뒤에 자리표시를 푼다. 푼 값은 다시 치환하지 않는다
- agent 절차에서는 자리표시를 풀지 않는다. render 가 `{steps.…}` 만 거부하고, 나머지 중괄호는 지금처럼 글자 그대로 문서에 들어간다

### 4-3. 값이 없을 때

실행 중에 자리표시를 풀 수 없으면 그 블록을 시작하지 않고 실행 전체가 `stop` 으로 끝난다.

| 경우 | 이유 |
|---|---|
| 변수가 없다 · 참조한 단계가 아직 돌지 않았다 · 출력이나 키가 없다 · 값이 null 이다 | `{<이름>} has no value` |
| 값이 불리언이거나 정수가 아닌 수다 | `{<이름>} is not a string, a whole number, an array or an object` |

- 값이 없는 것은 키가 없거나 null 일 때뿐이다. 빈 문자열 · 빈 배열 · 빈 객체는 값이다 (4-2)

### 4-4. render 의 중괄호와의 구분

| 표기 | 언제 풀리나 | 무엇 |
|---|---|---|
| `{{VAR}}` · `{{INCLUDE:<경로>}}` | render | 템플릿 변수, 소유 파일 본문 |
| `{{step:<id>}}` | render | 단계 번호 (조각 안) |
| `{이름}` | driver 실행 | 4-1 의 값 |

## 5. 구조화 출력 스키마

agent 블록의 구조화 출력은 **하네스의 검증이 계약이다.** 역할 계약의 지시와 프롬프트의 스키마로 형식을 요구하고, 드라이버가
표준 라이브러리로 검증한다. 벤더의 출력 스키마 옵션은 형식 위반을 줄이는 보조다 (7-4).

### 5-1. 자리와 이름

| 자리 | 경로 | 성격 |
|---|---|---|
| 동봉 | `src/harness/schemas/<이름>.json` — 고정 사본은 `.harness/lib/harness/schemas/<이름>.json` | 하네스 것 |
| 프로젝트 | `.ai/project/schemas/<이름>.json` | 소유 — 하네스 갱신이 건드리지 않는다 |

- 이름은 `^[a-z][a-z0-9-]{0,40}$` 이고 파일 이름에서 `.json` 을 뺀 것이다. 단계는 `schema = "<이름>"` 으로 가리킨다
- 두 자리에 같은 이름이 있으면 render 가 거부한다
- 프로젝트 자리에서 `.json` 이 아닌 파일은 읽지 않는다
- 프로젝트 스키마는 보호 문서가 아니다 — 배선(`harness.toml`)과 같은 층의 설정 입력이다
- preset 은 스키마를 실어 나르지 않는다. preset 이 주는 절차의 agent 블록은 동봉 스키마를 쓴다
- 동봉 스키마는 그것을 쓰는 기본 절차와 함께 더한다. 스키마를 쓰는 역할의 계약은 출력 절에 그 스키마 이름과 필드의 뜻을 적는다

### 5-2. 문법

JSON Schema 의 부분 집합이다.

| 키워드 | 쓰는 곳 | 뜻 |
|---|---|---|
| `type` | 모든 스키마 | `"object"` · `"string"` · `"integer"` · `"number"` · `"boolean"` · `"array"` 중 하나(문자열 하나) |
| `properties` | object | 이름 → 스키마 |
| `required` | object | 있어야 하는 이름의 배열. 모두 `properties` 에 있다 |
| `additionalProperties` | object | `true`(기본) · `false`. `false` 면 `properties` 밖의 이름을 거부한다 |
| `enum` | string · integer | 허용 값 배열. 1개 이상, 서로 다르고, `type` 과 맞는다 |
| `minLength` | string | 0 이상 정수(불리언 제외). 문자열의 길이(문자 수)가 그 값 이상이다 |
| `items` | array | 원소의 스키마 |
| `title` · `description` | 모든 스키마 | 설명. 검증하지 않는다 |

- 최상위는 `type = "object"` 다
- 표에 없는 키워드(`$ref` · `oneOf` · `pattern` · `format` …)가 있으면 render 가 거부한다 — 검증되지 않는 제약을 계약처럼 두지 않는다
- `integer` 는 소수부가 없는 수(불리언 제외), `number` 는 수(불리언 제외)다
- `on` 이 가리키는 필드는 최상위 `properties` 와 `required` 에 있고, `type = "string"` 이며 `enum` 이 있다.
  열거값은 outcome 이름 형식이고 `failed` 가 아니다

### 5-3. 결과 본문에서 출력 꺼내기

결과 본문은 역할 실행기가 `--out` 파일로 받은 그 실행의 최종 결과다.

1. 앞뒤 공백을 뺀 전체가 JSON 객체로 읽히면 그것이 출력이다
2. 아니면 info string 이 `json` 인 fenced 블록이 정확히 하나이고 그 내용이 JSON 객체면 그것이다 — 리뷰 판정 데이터와 같은 추출 규칙이다
3. 그 밖(블록이 없다 · 둘 이상이다 · 객체가 아니다)은 꺼내지 못한 것이다

- 출력의 직렬화 크기가 1 MiB 를 넘으면 꺼내지 못한 것으로 본다
- 꺼내지 못했거나 검증을 어기면 outcome 은 `failed` 이고 표준 오류에
  `warn: <절차>/<id>: output does not match schema <이름> — <위치>: <사유>` 를 낸다. 출력 내용은 옮기지 않는다

## 6. render 검증

검증은 render · check · `harness steps`(`--dry-run` 포함)가 같은 함수로 한다. 오류 줄은 `error: workflows.<절차>` 로 시작한다.

| 걸리는 곳 | 위치 표기 |
|---|---|
| 절차 전체 (실행 방식 · 빈 절차 · 상한) | `workflows.<절차>` |
| 단계 하나 | `workflows.<절차>.steps[<번호>]` — 번호는 0 부터 |
| 단계 하나의 outcome 하나 | `workflows.<절차>.steps[<번호>].next[<outcome 의 JSON 문자열>]` — 예: `workflows.work.steps[2].next["*"]` |

- outcome 하나에 걸리는 것: 대상 · outcome 키의 거부, 완전성의 빠진 outcome(그 outcome 이름으로 적는다)
- 배선 섞임은 `next` 가 없는 첫 단계, 도달 · 끝은 걸린 단계 가운데 목록에서 첫 단계의 위치로 적는다
- 그 밖의 행은 거부한 키가 있는 단계의 위치다

| 검사 | 대상 | 거부하는 것 |
|---|---|---|
| 실행 방식 | 전부 | `execute` 가 `agent` · `driver` 가 아니다 |
| 블록 종류 | 전부 | `type` 이 script · agent · prompt · gate · workflow 가 아니다 |
| 키 | driver | 2-1 · 2-2 표에 없거나 그 블록이 받지 않는 키 |
| driver 전용 | agent | † 키, `max_steps` · `max_visits`, `run` · `text` 의 `{steps.…}` 자리표시 |
| 빈 절차 | 전부 | 단계가 없는데 하위 절차가 아니다. 첫 줄은 지금 문구 `… is empty — a workflow needs at least one step` 이고 `help:` 가 하위 절차만 비어 있을 수 있다고 알린다 |
| 하위 절차 | 전부 | `workflow` 가 설정에 없는 절차다 · 자기 자신이다 · 호출이 순환한다 · 부르는 절차와 `execute` 가 다르다 |
| 역할 | agent 블록 | 설정에 없는 역할, CLI 러너이고 `entry` 가 있는 역할(지금과 같다). driver 면 `entry` 가 있는 역할 전부 |
| 명령 | script | `run` 이 비었다(지금과 같다). driver 면 `shlex.split` 이 실패한다 · 셸 연산자로만 된 원소(`;` `&` `|` `<` `>` 와 그 조합, 앞에 숫자가 붙은 리다이렉트)가 있다 · 원소에 `$` 나 `` ` `` 가 있다 |
| 프롬프트 | prompt | 조각도 `text` 도 없다(지금과 같다). `access` 가 `read-only` · `write` 가 아니다 |
| 선택지 | gate | `options` 가 서로 다른 outcome 이름 1개 이상의 배열이 아니다 |
| 스키마 | agent | 없는 이름 · 5-2 를 어긴 파일 · 두 자리의 이름 겹침 · `schema` 없는 `on` · 5-2 조건을 어긴 `on` 필드. 프로젝트 자리의 `.json` 파일은 가리키지 않아도 문법을 본다 |
| 배선 섞임 | driver | 일부 단계에만 `next` 가 있다 — 빈 표도 있는 것이다 (2-3) |
| 암묵 배선의 `on` | driver | `next` 가 없는 절차의 `on` |
| 대상 | driver | `next` 값이 같은 절차의 단계 id 도 끝 상태도 아니다 · 명시 배선 절차의 예약 id |
| outcome 키 | driver | 키가 outcome 이름 형식도 `"*"` 도 아니다 · script 가 아닌 블록에서 그 블록의 outcome 집합에 없는 키 |
| 완전성 | driver 의 script 가 아닌 블록 | outcome 집합의 원소가 키로도 없고 `"*"` 도 없다 |
| 도달 | driver | 첫 단계에서 `next` 를 따라 닿지 않는 단계 |
| 끝 | driver | `next` 를 따라 어느 끝 상태에도 닿지 못하는 단계 — script 의 표에 없는 outcome 이 `stop` 으로 가는 것은 세지 않는다 |
| 자리표시 | driver | 4-1 의 형식이 아닌 이름 · 같은 절차의 `set` 에도, 그 절차를 (거슬러 올라가며) 부르는 절차의 `set` 에도 없는 변수 · 같은 절차에 없는 단계의 출력 · 출력이 없는 블록(`on = "stdout"` 인 script, 스키마 없는 agent, prompt · gate · workflow)의 출력 · 스키마의 최상위 `properties` 밖 키나 `type` 이 string · integer · array · object 가 아닌 키 |
| `set` | driver | 변수 · 키 이름 형식 · 출력이 없는 블록 · 스키마의 최상위 `properties` 밖 키나 `type` 이 string · integer · array · object 가 아닌 키 |
| 상한 | driver | `max_steps` · `max_visits` 가 1 이상 1000 이하 정수가 아니다 |

블록의 outcome 집합:

| 블록 | outcome 집합 |
|---|---|
| agent (`on` 있음) | `on` 필드의 열거값과 `failed` |
| agent (`on` 없음) · prompt | `ok` · `failed` |
| gate | `options` |
| workflow | `done` · `stop` · `handoff` |
| script | 정하지 않는다 — `next` 의 키가 선언이다 |

## 7. 드라이버 — driver 절차의 `harness run`

### 7-1. 인자

```
harness run <절차> <이슈> [--worktree] [--resume] [--dry-run]
harness run <절차> <이슈> --discard
```

| 플래그 | 뜻 |
|---|---|
| `--resume` | 끝나지 않은 실행을 잇는다 (8-4) |
| `--discard` | 끝나지 않은 실행의 상태를 지운다 (8-3). 아무것도 실행하지 않는다. 다른 플래그와 함께 쓰지 않는다 |
| `--worktree` | 71 명세 3절 그대로. driver 와의 관계는 7-8 |
| `--dry-run` | 상태 · 잠금 · worktree 를 만들거나 바꾸지 않고 7-3 의 출력 줄만 낸다 |

- `COMMANDS` 표의 `run` 사용법과 README 명령 표는 `<workflow> <issue> [--worktree] [--resume] [--discard]` 다
- 아래는 아무것도 바꾸지 않고 종료 코드 2 로 거부한다. 위에서부터 처음 맞는 줄의 출력을 낸다

| 경우 | 출력 |
|---|---|
| driver 절차인데 이슈가 숫자(`^[0-9]+$`)도 Jira 키(`^[A-Z][A-Z0-9_]*-[0-9]+$`)도 아니다 — 착수 잠금(#215)의 이슈 규칙과 같다 | `` error: a driver workflow needs an issue number or a Jira key (got <값>) `` |
| `--worktree` 인데 이슈가 숫자(`^[0-9]{1,10}$`)가 아니다 — 71 명세 3절의 규칙 그대로. Jira 키 이슈의 driver 실행은 `--worktree` 없이 돈다 | `` error: --worktree needs an issue number (got <값>) `` |
| agent 절차에 `--resume` · `--discard` | `` error: --resume and --discard work only for driver workflows (`<절차>` is an agent workflow) `` |
| agent 하위 절차 | `` error: `<절차>` runs only as a sub-workflow of <부르는 절차, 쉼표로> `` |
| driver 절차가 자기 `set` 에 없는 변수를 자리표시로 쓴다 — 그 값은 부르는 절차가 올린다 (2-5) | `` error: `<절차>` reads {<변수>} from a calling workflow — it runs only as a sub-workflow of <그 변수를 set 하는 부르는 절차, 쉼표로> `` |
| 단계가 없는 절차 | `` error: `<절차>` has no steps — it is an extension point other workflows call `` |
| `--discard` 와 다른 플래그 | `` error: --discard takes no other flag `` |

- 자기 `set` 에 없는 변수의 판정은 시작한 절차의 단계만 본다. `{issue}` 와 `{steps.…}` 는 변수가 아니다. 여럿이면 단계 순서로 첫 변수를 적는다.
  시작한 절차가 부르는 하위 절차 안의 값은 실행 때 4-3 이 판정한다

### 7-2. 시작 전 확인

새 실행과 재개가 같다. 하나라도 걸리면 상태를 만들거나 바꾸지 않고 종료 코드 2 로 끝난다.

1. 실효 설정(#207 — 개인 레이어 포함)을 읽고 #207 의 실행 시점 불변식 검사를 거친다
2. 시작한 절차와 거기서 닿는 하위 절차의 agent · prompt 블록마다 실제 러너를 정한다 — 실행 계획의 그 역할 `driver` 항목(prompt 블록은
   `prompt` 의 그 권한 항목)의 `vendor` 다 (7-4). 그 항목이 없거나(벤더에 `headless` 가 없다) 실행 파일이 없으면 거부한다:
   `` error: <실행 파일> is not installed — <절차>/<id> runs <역할 | the orchestrator> with it ``
3. 역할 실행기 `script/run-agent.py` 가 없으면 거부한다: `error: script/run-agent.py is missing` 과 `help: harness render`.
   역할 실행기가 CLI 의 하위 명령이 된 뒤(#213)에는 이 확인이 없다
4. `.ai/workflows/<절차>.md` 가 있다 (지금과 같다)

### 7-3. 실행 순서

1. 인자를 확인한다 (7-1)
2. 잠금을 잡는다 (8-3). `--dry-run` 은 잡지 않는다
3. 상태를 가른다 — 새 실행인데 끝나지 않은 상태가 있거나, 재개인데 없거나, 읽지 못하거나, worktree 방식이 다르면 거부한다 (8-3 · 8-4 · 7-8)
4. `--worktree` 면 71 명세 3-3 의 1~4 로 worktree 를 만들거나 연다. 재개는 7-8 의 조건을 따른다
5. 실행 디렉터리의 하네스 루트에서 설정과 스키마를 읽고 7-2 를 확인한다. 재개면 정의 digest 를 대조한다 (8-4)
6. 새 실행이면 상태를 만든다. 첫 줄 `driver: <절차> <이슈> — <단계 수> step(s) from <절차>/<첫 단계>`,
   재개면 `driver: resume <절차> <이슈> at <절차>/<단계>`
7. 블록을 차례로 돈다. 블록마다 시작 줄 `step <n>: <절차>/<id> (<블록>)`, 끝 줄 `  -> <outcome> -> <대상>`(outcome 이 없으면 `-`)
8. 끝 · 멈춤 · 중단에서 마지막 줄과 종료 코드를 낸다 (7-7). 잠금을 푼다. `--worktree` 면 정리를 판정한다 (71 명세 3-6)

- `--dry-run` 은 6 의 첫 줄(재개면 상태의 `status` 를 괄호로 덧붙인다), 블록마다 `runner <절차>/<id>: <벤더>`, worktree 면
  71 명세 3-3 의 경로 줄을 내고 0 으로 끝난다
- worktree 에서 도는 실행은 worktree 의 하네스 루트에서 설정 · 스키마 · 역할 실행기를 읽는다 — agent 절차에서 오케스트레이터가
  worktree 의 절차 문서를 읽는 것과 같다. 1~4 는 `harness run` 을 부른 하네스 루트의 설정으로 판정하고, worktree 의 설정에서 그 절차가
  driver 절차가 아니면 5 에서 2 로 거부한다: `` error: `<절차>` is not a driver workflow in the worktree — commit the harness config to <base> first ``
- 터미널 출력은 영어다. 진행 줄은 표준 출력, `warn:` · `error:` 는 표준 오류로 낸다

### 7-4. 역할 러너 — agent · prompt 블록

드라이버는 agent · prompt 블록을 **공용 역할 실행기로만** 띄운다.

```
script/run-agent.py <역할> --driver [--schema <파일>] --prompt <지시> --out <파일>
script/run-agent.py --driver-prompt <read-only|write> --prompt <지시> --out <파일>
```

| 인자 | 뜻 |
|---|---|
| `--driver` | 실행 계획의 `roles.<역할>.driver` 로 띄운다. 러너가 `inproc` 인 역할도 실행한다. 그 항목이 없으면 2 |
| `--driver-prompt <권한>` | 역할 없이 실행 계획의 `prompt.<권한>` 으로 띄운다. 그 항목이 없으면 2 |
| `--schema <파일>` | 그 항목의 `structured` 가 비어 있지 않으면 그 인자를 붙인다. 비어 있으면 무시한다 |

- 기존 호출(`<역할> [--out <파일>] [--prompt <지시>] [<입력> ...]` · `--check`)은 그대로다. 서브에이전트 역할을 `--driver` 없이 부르면 지금처럼 2 다
- 드라이버는 실행기의 표준 입력을 비우고, `--out` 파일을 자기가 만든 0700 임시 디렉터리에 두며, 블록이 끝나면 그 디렉터리를 지운다
- #213 이 역할 실행기를 하위 명령 `harness run-agent` 로 옮기면 위 세 인자(`--driver` · `--driver-prompt` · `--schema`)를 그 명령이 같은 뜻으로 받고,
  드라이버는 shim 을 거치지 않고 패키지의 역할 실행기를 부른다

실행 계획(#207 의 `run_plan()` — `harness run-plan` 이 내는 JSON. 드라이버는 같은 프로세스에서 그 함수를 부른다)에 두 자리를 더한다.
기존 필드는 그대로다. 아래에서 `…` 는 권한 · 모델 인자와 줄인 값이다.

```json
{
  "roles": {
    "developer": {"via": "subagent", "vendor": "claude", "label": "Claude", "model": "",
                  "driver": {"vendor": "claude", "exe": "claude",
                             "argv": ["claude", "-p", "--agent", "developer", "--no-session-persistence", "…"],
                             "output": "stdout", "usage_format": ["--output-format", "json"],
                             "usage_parser": "claude-json", "structured": []}}
  },
  "prompt": {
    "read-only": {"vendor": "claude", "exe": "claude", "argv": ["claude", "-p", "--no-session-persistence"],
                  "output": "stdout", "usage_format": ["--output-format", "json"], "usage_parser": "claude-json"},
    "write": {"vendor": "claude", "exe": "claude", "argv": ["claude", "-p", "--no-session-persistence", "…"],
              "output": "stdout", "usage_format": ["--output-format", "json"], "usage_parser": "claude-json"}
  },
  "metrics": {"…": "…"}
}
```

| 자리 | 있는 때 | 키 |
|---|---|---|
| `roles.<역할>.driver` | 켜진 역할이고 `entry` 가 없으며, 그 역할의 실제 벤더에 `headless` 가 있을 때 | `vendor` · `exe` · `argv` · `output` · `usage_format` · `usage_parser` · `structured` |
| `prompt` (최상위) | 늘. 값은 `"read-only"` · `"write"` 두 키의 객체다 | 권한마다 실효 오케스트레이터 벤더에 `headless` 가 있으면 `vendor` · `exe` · `argv` · `output` · `usage_format` · `usage_parser` 의 객체, 없으면 그 권한 키가 없다 |

| 키 | `roles.<역할>.driver` | `prompt.<권한>` |
|---|---|---|
| `vendor` | 역할의 실효 러너. `inproc` 이면 실효 `harness.orchestrator` | 실효 `harness.orchestrator` |
| `argv` | 그 벤더의 `headless` 를 푼 것. `{agent}` = `agent` 표(`{role}` 은 역할), `{access}` = 역할이 `write` 면 `driver_write`(없으면 `access.write`), `read-only` 면 `access.read-only`, `{model}` = 지금의 역할 모델 규칙 | `{agent}` 는 빈 목록, `{access}` 는 왼쪽과 같은 규칙을 그 권한에, `{model}` = 실효 `harness.model` |
| `exe` · `output` · `usage_format` · `usage_parser` | 그 벤더의 선언. 뜻은 기존 필드와 같다 | 같다 |
| `structured` | 그 벤더의 `structured` 선언(없으면 빈 목록) | 없다 |

- 두 자리는 다른 필드처럼 실효 설정(개인 레이어 포함)으로 계산한다

벤더 선언(`vendors.toml`)의 새 키:

| 키 | 뜻 |
|---|---|
| `agent` | `headless` 의 `{agent}` 자리에 들어가는 인자. `{role}` 을 쓴다. 없으면 빈 목록이고, 역할 없는 실행(prompt 블록)에서도 빈 목록이다 |
| `driver_write` | driver 실행의 쓰기 권한 인자. `{access}` 자리에 `access.write` 대신 들어간다. 없으면 `access.write` 를 쓴다 |
| `structured` | 출력 스키마 보조 인자. `{schema_file}` = 스키마 파일 경로, `{schema_json}` = 그 내용 |

- claude 의 `headless` 는 `["claude", "-p", "{agent}", "--no-session-persistence", "{access}", "{model}"]`, `agent = ["--agent", "{role}"]` 이다.
  렌더되는 역할 argv 는 지금과 같다
- `driver_write` 는 쓰기 역할이 그 driver 실행 하나에서 아래 조작을 승인 없이 할 수 있게 하는 인자다. 이 표가 기본 절차 `work` 의
  구현자 단계가 쓰는 조작이다(#212 7절의 헤드리스 구현자 권한 표와 같다). `[permissions].allow_push` 는 대화형 세션의 설정으로 남고
  이 범위를 정하지 않는다

  | 조작 | 범위 |
  |---|---|
  | 파일 | 하네스 루트 아래 읽기 · 쓰기 |
  | git 읽기 | `git status` · `git log` · `git diff` · `git show` · `git rev-parse` · `git branch` · `git fetch` |
  | git 쓰기 | `git switch` · `git switch -c` · `git add` · `git commit` · `git push`(작업 브랜치, 강제 없이) |
  | 검증 | `script/run-lint-test.sh --commit` |
  | forge 읽기 | `.ai/forge.md` 의 이슈 조회 · 리뷰 요청 조회 · diff · 현재 사용자명. `script/forge.sh` 의 `tracker_issue_view` · `review_mr_view` · `review_mr_threads` |
  | forge 쓰기 | `.ai/forge.md` 의 리뷰 요청 생성 · 리뷰 스레드 답글. `script/forge.sh` 의 `review_mr_thread_reply` · `review_mr_note_summary` |
  | 하네스 스크립트 | `script/create-carryover-issue.sh`(이월 이슈 생성 — 원격 쓰기), `script/sync-task-issues.sh <이슈> --dry-run` |

- 표에 없는 조작은 열지 않는다 — 이슈 · 리뷰 요청 닫기, 머지, 이슈 댓글, 라벨 변경, `--dry-run` 없는 task 동기화가 그렇다
- 보호 브랜치 push 와 force push 는 deny 규칙 · 명령 가드 · pre-push 훅이, `--no-verify` 는 deny 규칙 · 명령 가드가 그대로 막는다
- **헤드리스 실행에 `--bare` 를 쓰지 않는다** — 설정에 정의된 훅(명령 가드)을 건너뛴다. 벤더 선언의 어느 argv 에도 `--bare` 가 없다.
  헤드리스 `claude -p` 가 `.claude/settings.json` 의 PreToolUse 훅을 거는지 <!-- TBD: 확인 필요 -->
- claude · codex 의 `driver_write` 와 `structured` 는 그 CLI 로 직접 확인한 인자만 적는다(등록부 머리의 규칙). 확인하지 않은 키는 선언하지 않고,
  선언이 없으면 위 표의 대체 규칙으로 돈다. 확인할 것:
  - `claude -p` 에서 승인이 필요한 도구 호출이 거부로 끝나는지와, 위 동작을 허용하는 인자 <!-- TBD: 확인 필요 -->
  - `codex exec --sandbox workspace-write` 가 네트워크(push · forge CLI)를 막는지와, 허용하는 인자 <!-- TBD: 확인 필요 -->
  - `claude --json-schema` · `codex exec --output-schema` 를 붙였을 때 결과 본문이 5-3 을 만족하는 자리에 오는지 — claude 는
    `--output-format json` 결과 객체의 어느 필드에 오는지 <!-- TBD: 확인 필요 -->

### 7-5. 게이트 입력

- 제목 · `text`(자리표시를 푼 것) · 선택지를 표준 출력에 내고 표준 입력에서 한 줄을 읽는다

  ```
  gate <절차>/<id>: <제목>
  <text>
  options: 1) approve  2) reject
  >
  ```

- 선택지 이름이나 1 부터 센 번호를 받는다. 앞뒤 공백은 무시한다
- 표준 입력이 터미널이면 맞지 않는 답에 `not an option: <답>` 을 내고 다시 묻는다
- 터미널이 아니면 맞지 않는 답이나 입력 끝(EOF)에서 멈춘다 — 상태를 `waiting` 으로 남기고 종료 코드 4 (7-7).
  **게이트를 지나간 것으로 보지 않는다**
- 자동화와 테스트는 표준 입력으로 답을 준다: `echo approve | harness run <절차> <이슈> --resume`

### 7-6. 상한

- 블록을 시작하기 전에 센다. 아래에 닿았으면 그 블록을 시작하지 않고 실행 전체가 `stop` 으로 끝난다

  | 상한 | 세는 것 | 이유 |
  |---|---|---|
  | `max_steps` | 이 실행에서 시작한 블록 수 — 하위 절차의 블록, workflow 블록, 재개 전의 것을 모두 센다 | `max_steps <n> reached` |
  | `max_visits` | 그 단계(절차와 id 의 짝)를 시작한 횟수 | `max_visits <n> reached at <절차>/<id>` |

- 상한 값은 시작한 절차의 것이다 (2-1)
- 리뷰 회차 상한(`review.max_rounds`)은 그대로 리뷰 명령이 센다. 리뷰 단계는 회차마다 한 번 돌고 회차 상한에 닿으면 리뷰 명령이
  `3` 으로 끝나므로, 재개로 다시 도는 경우를 빼면 방문이 회차 상한 + 1(최대 21)을 넘지 않는다. `max_visits` 기본값 30 은 그보다 크다

### 7-7. 끝 · 출력 · 종료 코드

| 끝 | 종료 코드 | 마지막 줄 | 상태 파일 |
|---|---|---|---|
| `done` | 0 | `done: <절차> <이슈>` | 지운다 |
| `stop` | 1 | `stop: <절차> <이슈> at <절차>/<id>` — 드라이버가 낸 이유가 있으면 ` — <이유>` 를 붙인다 | 지운다 |
| 실행하지 못함 (7-1 · 7-2 · 8-3 · 8-4 · 7-8 의 거부) | 2 | `error: …` | 바꾸지 않는다 |
| `handoff` | 3 | `handoff: <절차> <이슈> at <절차>/<id>` | 지운다 |
| 게이트에서 멈춤 | 4 | `paused: <절차> <이슈> at gate <절차>/<id>` 와 `help:` · `harness run <절차> <이슈> --resume` | `waiting` 으로 남긴다 |
| 중단 신호(SIGINT) | 130 | `interrupted: <절차> <이슈> at <절차>/<id>` 와 같은 `help:` | 남긴다 |

- `at <절차>/<id>` 는 끝 상태로 보낸 가장 안쪽 단계다
- 하위 절차의 끝 상태는 실행의 끝이 아니다 — 바깥 workflow 블록의 outcome 이 된다. 실행의 끝은 시작한 절차의 끝 상태다
- 드라이버가 내는 `stop`(2-3 · 4-3 · 7-6)은 깊이와 상관없이 실행 전체를 끝낸다
- 드라이버가 예외로 죽으면 상태는 마지막으로 쓴 그대로 남는다 — 재개하면 8-4 대로 잇는다

### 7-8. worktree 와 함께

- `--worktree` 는 71 명세 3절 그대로 worktree 를 만들거나 열고, 드라이버는 그 실행 디렉터리에서 돈다
- 상태는 `--worktree` 로 시작했는지 기록한다. 재개는 같은 방식이어야 한다. 다르면 2:
  - `error: this run started in the issue worktree — resume it with --worktree`
  - `error: this run started without --worktree — resume it without --worktree`
- `--resume --worktree` 는 worktree 가 남아 있어야 한다. 71 명세 3-4 의 "없다" · "빈 디렉터리" 면 아무것도 만들지 않고 2:
  `error: the worktree of this run is gone — it cannot resume` 과 `help:` · `harness run <절차> <이슈> --discard`.
  미커밋 변경이 있으면 71 명세 3-4 대로 1 로 멈춘다
- 정리 판정(71 명세 3-6)은 끝나지 않은 실행 상태가 있으면 worktree 를 남긴다

### 7-9. 실행 지표

- `harness run` 한 번(새 실행 · 재개 각각)이 트레이스 하나다. 시작 스팬은 지금의 run 스팬과 같다 — 이름 `run/<절차>`, kind `command`,
  source `runner`, 속성 `workflow` · `issue` · `worktree`(있으면) · `vendor`(오케스트레이터) · `model`(있으면)
- 블록마다 스팬 하나 — 이름 `<절차>/<id>`, kind `step`, 속성 `workflow` · `step` · `issue`. 부모는 run 스팬이고, 하위 절차의 블록은
  그 workflow 블록의 스팬이다. 끝 상태: script 는 종료 코드가 0 이면 `ok`, 아니면 `error` 이고 종료 코드를 남긴다. agent · prompt 는
  outcome 이 `failed` 면 `error`, 아니면 `ok` 다. gate · workflow 는 `ok` 다
- 자식(script 블록의 명령 · 역할 실행기)에 `HARNESS_TRACE_ID` · `HARNESS_PARENT_SPAN`(그 블록 스팬) · `HARNESS_WORKFLOW` · `HARNESS_STEP` 을 넘긴다
- 스팬에 출력 · 변수 값 · 프롬프트 · 명령줄을 남기지 않는다
- `issue` 속성은 지표 기록기의 이슈 검사식(`^[0-9]{1,10}$`)에 맞을 때만 남는다 — Jira 키 이슈의 스팬에는 `issue` 가 없다 (15절)
- driver 절차 문서에는 단계 시작 표지 줄이 없다 — 드라이버가 블록 스팬을 남긴다. agent 절차 문서의 표지 줄은 그대로다
- 집계 `by_step`: 트레이스마다, kind `step` 스팬이 있는 단계는 횟수 · 시간 · 오류를 그 스팬으로만 세고 토큰은 같은 `workflow` · `step`
  속성을 가진 스팬 전부에서 더한다. kind `step` 스팬이 없는 단계는 지금과 같다

## 8. 실행 상태

### 8-1. 자리

| 파일 | 경로 |
|---|---|
| 상태 | `<등록부>/<클론 키>/runs/<절차>-<이슈>.json` |
| 잠금 | `<등록부>/<클론 키>/runs/<절차>-<이슈>.lock` |

- 등록부는 `HARNESS_HOME` 이 있으면 그것, 없으면 `~/.harness` 다. 클론 키는 96 명세 1절의 값이다 —
  같은 클론의 worktree 는 같은 자리를 쓴다
- 디렉터리는 0700, 파일은 0600 이다. 상태는 같은 디렉터리의 임시 파일에 쓰고 rename 으로 바꾼다
- 위치를 바꾸는 설정 키는 없다
- 파일 이름의 `<절차>-<이슈>` 는 한 가지로만 갈린다 — 절차 이름(`[a-z][a-z0-9-]{1,30}`)에는 대문자가 없고, 이슈는 숫자이거나 대문자로
  시작하는 Jira 키(7-1)다. 이름에서 읽을 때는 끝에서 Jira 키, 그다음 숫자 순으로 이슈를 맞추고 앞부분이 절차 이름 형식인지 본다

### 8-2. 형식

```json
{
  "format": 1,
  "workflow": "work",
  "issue": "12",
  "digest": "sha256:…",
  "worktree": false,
  "preset": null,
  "started": "2026-10-09T07:00:00Z",
  "updated": "2026-10-09T07:12:00Z",
  "steps_run": 7,
  "visits": {"work/implement": 1, "review-loop/review": 3},
  "frames": [
    {"workflow": "work", "at": "loop", "vars": {"mr": "41"}, "outputs": {"implement": {"mr": "41"}}},
    {"workflow": "review-loop", "at": "fix", "status": "running", "vars": {}, "outputs": {}}
  ]
}
```

| 필드 | 뜻 |
|---|---|
| `format` | `1` |
| `workflow` · `issue` | 시작한 절차와 이슈. 파일 이름과 같다 |
| `digest` | 정의 digest (8-4) |
| `worktree` | `--worktree` 로 시작했는가 |
| `preset` | 선택. 문자열 또는 null — 시작할 때의 preset 체인 digest 자리다. 필드가 없으면 null 로 본다. 이 명세의 드라이버는 null 을 쓴다. 값을 채우고 재개 때 대조하는 규칙은 preset 을 들이는 변경(#216)이 정한다 |
| `started` · `updated` | UTC 시각 |
| `steps_run` · `visits` | 상한의 계수 (7-6). `visits` 의 키는 `<절차>/<id>` |
| `frames` | 바깥에서 안쪽으로, 절차 실행 하나에 하나. `at` 은 그 절차의 현재 단계(바깥 프레임은 실행 중인 workflow 블록), `vars` 는 그 실행의 절차 변수, `outputs` 는 단계 id → 가장 최근 출력 |
| `frames[-1].status` | `ready`(아직 시작하지 않았다) · `running`(시작했다) · `waiting`(게이트가 답을 기다린다) |

- 최상위 필드는 `preset` 을 빼고 모두 필수다. 프레임은 `workflow` · `at` · `vars` · `outputs` 를 갖고, 안쪽 프레임만 `status` 를 갖는다
- 최상위나 프레임에 표에 없는 필드가 있으면 읽지 못한 상태로 본다 (8-3) — 그 필드를 아는 버전이 쓴 상태를 모르는 버전이 무시하고
  잇지 않게 한다. 필드를 더하는 변경은 이 표에 그 필드를 더한다
- 에이전트 결과 본문 원문과 프롬프트는 담지 않는다. 출력은 5-3 을 통과한 객체와 script 의 JSON 출력뿐이다
- 쓰는 때: 새 실행을 만들 때, 블록을 시작할 때(`running`), outcome 을 따라 다음 단계로 옮길 때(`ready`), 게이트가 멈출 때(`waiting`)

### 8-3. 수명 · 잠금 · 지우기

- (절차, 이슈)마다 끝나지 않은 실행은 하나다. `harness run` 은 잠금 파일에 비차단 `flock` 을 잡고 끝날 때까지 쥔다.
  잡지 못하면 2: `error: another run of <절차> for issue <이슈> is in progress on this clone`
- 끝 상태(`done` · `stop` · `handoff`)에 닿으면 상태 파일을 지운다. 게이트 멈춤 · 중단 신호 · 드라이버의 예외에서는 남는다
- 새 실행인데 상태가 있으면 2: `error: an unfinished run of <절차> for issue <이슈> exists (at <절차>/<id>)` 와
  `help:` · `harness run <절차> <이슈> --resume` · `harness run <절차> <이슈> --discard`
- `--discard` 는 잠금을 잡고 상태 파일을 지운다. 잠금 파일은 남아도 된다 — `flock` 은 프로세스가 끝나면 풀린다. 지웠으면 `discarded: run state of <절차> for issue <이슈>`, 없었으면
  `discard: no run state of <절차> for issue <이슈>`. 둘 다 0 이다. 잠금을 잡지 못하면 2
- 상태 파일은 기기 로컬이지만 들어오는 입력으로 검증한다. JSON 이 아니다 · `format` 이 다르다 · 필드가 형식과 다르다 · 표에 없는 필드가 있다 ·
  `workflow` · `issue` 가 파일 이름과 다르다 · `frames` 의 절차나 단계가 지금 정의에 없다 — 이면 새 실행과 재개 모두 2:
  `error: the run state of <절차> for issue <이슈> cannot be read` 와 `--discard` 안내

### 8-4. 재개

- **정의 digest** 는 시작한 절차와 거기서 닿는 하위 절차의 정의(정규화한 절차 표 전부)와 그 절차들이 가리키는 스키마의 내용을
  키 순서를 정렬한 JSON 으로 직렬화한 SHA-256 이다. 러너 · 모델(개인 값)과 조각 본문은 들지 않는다
- 재개하면 digest 를 다시 계산한다. 다르면 2: `error: the definition of <절차> changed since this run was saved — it cannot resume` 과 `--discard` 안내
- 7-2 를 다시 확인한다 — 개인 레이어가 바뀌었으면 바뀐 러너로 돌고, 불변식을 어기면 2 다
- 안쪽 프레임의 `status` 별로 잇는다

  | `status` | 재개하면 |
  |---|---|
  | `ready` | 그 단계를 시작한다 |
  | `running` | 그 단계를 처음부터 다시 돈다 |
  | `waiting` | 그 게이트를 다시 묻는다 |

- 처음부터 다시 도는 단계가 리뷰 명령이면 회차 라벨이 한 번 더 오를 수 있다. 종료는 회차 상한이 보장한다

### 8-5. `harness doctor` — `runs` 절

- 이 클론의 `runs/` 에서 이름이 `<절차>-<이슈>.json` 형식인 파일마다 `warn` 한 줄을 낸다

  | 경우 | `what` | `detail` |
  |---|---|---|
  | 읽힌다 | `unfinished run of <절차> for issue <이슈>` | `` at <절차>/<id> — resume with `harness run <절차> <이슈> --resume` or drop it with `--discard` ``. 게이트에서 멈췄으면 `<id>` 뒤에 ` (gate)` 를 붙인다 |
  | 읽히지 않는다 (8-3 의 판정) | `unreadable run state of <절차> for issue <이슈>` | `` drop it with `harness run <절차> <이슈> --discard` `` |

- 없으면 `ok` 한 줄: `no unfinished runs`
- 상태의 출력 · 변수와 파일 경로는 옮기지 않는다
- UI `src/ui/lib/doctor.js`: `SECTIONS.runs` 는 `"실행"` 이다. `explain()` 은 두 `warn` 줄을 "멈춘 driver 실행이 있다 — 이어 돌거나 지운다",
  "읽지 못하는 실행 상태가 있다 — 지운다" 는 뜻으로 옮기고 조치 명령으로 `harness run <절차> <이슈> --resume` · `--discard` 를 준다

## 9. 절차 문서

### 9-1. agent 절차

- 단계 구성이 이 변경 전과 같은 절차의 문서는 바이트 단위로 같다. 이 리포의 생성물(`.ai/workflows/*.md`)이 render 뒤 바뀌지 않고
  `harness check` 가 통과하는 것이 그 확인이다
- workflow 블록
  - 제목 줄: `` ### <n>. <제목> — 하위 절차 `<이름>` ``
  - 본문: 하위 절차에 단계가 있으면 "`.ai/workflows/<이름>.md` 의 절차를 이 자리에서 그 문서대로 수행한다. 그 절차가 끝나면 다음 단계로 간다.",
    없으면 "`workflows.<이름>` 은 단계가 없는 확장 지점이다. 할 일이 없으니 다음 단계로 간다." 뒤에 `text`
  - 시작 표지 줄은 다른 단계와 같다
- 단계가 없는 절차의 문서: 머리, "이 절차에는 단계가 없다. 다른 절차가 하위 절차로 부르는 확장 지점이고, 불리면 곧바로 끝난다.", 꼬리 조각과
  `## 이 프로젝트에서`

### 9-2. driver 절차

driver 절차 문서는 사람이 읽는 설명이다. 에이전트가 따라 수행하지 않는다.

1. 머리 — 기본 절차는 `_head` 조각이다. 프로젝트 절차는 아래 머리다

   ```
   # <절차> — <제목>

   하네스 설정(`workflows.<절차>`)에서 만든 절차다. 단계와 배선은 그 설정이 정한다.

   ## 입력

   이슈 번호(또는 Jira 키) 하나. 단계 값에서 `{issue}` 로 쓴다.

   ## 절차

   ```

2. 첫 단계 앞 — 실행 안내, 그래프, 끝 상태 범례

   ````
   > **하네스가 실행하는 절차다** (`execute = "driver"`). `harness run <절차> <이슈번호>` 로 시작하고, 멈춘 실행은 `--resume` 으로 잇는다.
   > 에이전트 세션이 이 문서를 따라 수행하지 않는다.

   ```mermaid
   flowchart TD
     s1["1. 리뷰"]
     s2["2. 수정"]
     end_done(["done"])
     end_stop(["stop"])
     end_handoff(["handoff"])
     s1 -->|"0"| end_done
     s1 -->|"1"| s2
     s1 -->|"2"| end_stop
     s1 -->|"3"| end_handoff
     s2 -->|"ok"| s1
     s2 -->|"failed"| end_stop
   ```

   끝 상태: `done` 성공 · `stop` 실패 보고 · `handoff` 리뷰 요청을 연 채 사람에게
   ````

   - 노드는 단계마다 `s<번호>["<번호>. <제목>"]`, 쓰인 끝 상태마다 `end_<이름>(["<이름>"])` 이다. 제목의 `"` 는 `#quot;` 로 쓴다
   - 간선은 단계 순서대로, 단계 안에서는 배선 표의 순서대로다. 라벨은 outcome(`*` 포함)을 큰따옴표로 감싼다
   - 암묵 배선 절차는 2-4 의 배선을 그린다. script · gate 의 "그 밖" 은 `*` 다
3. 단계마다 `### <n>. <제목 줄>`, 블록 설명, 조각(있으면), `text`, 다음 표

   | 블록 | 제목 줄 | 블록 설명 |
   |---|---|---|
   | agent | `<제목> — <역할 라벨> 역할` | `` `.ai/templates/<역할>.md` 계약을 따르는 역할을 드라이버가 헤드리스로 한 번 실행한다. `` 스키마가 있으면 `` 출력은 `<이름>` 스키마(<자리>)로 검증하고, outcome 은 `<on>` 필드 값이다. `` — `<자리>` 는 동봉이면 `동봉`, 프로젝트면 `` `.ai/project/schemas/<이름>.json` ``, `on` 이 없으면 outcome 문장을 뺀다 |
   | script | `` <제목> — `<run>` `` | `run` 을 담은 `bash` 코드 블록과 `드라이버가 셸 없이 실행한다. outcome 은 종료 코드다.`(`on = "stdout"` 이면 `… 표준 출력의 첫 토큰이다.`) |
   | prompt | `<제목>` | `` 드라이버가 오케스트레이터를 헤드리스로 한 번 실행한다(권한 `<access>`). `` |
   | gate | `<제목> (사람)` | `` 드라이버가 터미널에서 묻는다. 고를 수 있는 것: `<선택지>` · `<선택지>`. `` — `options` 를 차례대로 쓴다 |
   | workflow | `` <제목> — 하위 절차 `<이름>` `` | `` 하위 절차 `.ai/workflows/<이름>.md` 를 실행한다. outcome 은 그 절차의 끝 상태다. `` |

   - `set` 이 있으면 블록 설명 뒤에 `` 올리는 변수: `{<변수>}` ← 출력 `<키>` `` 를 변수마다 쓴다
   - 다음 표

     ```
     | outcome | 다음 |
     |---|---|
     | `0` | `done` |
     | `1` | 2. 수정 |
     | `*` | `stop` |
     ```

4. 단계 시작 표지 줄은 없다
5. 꼬리 조각과 `## 이 프로젝트에서` 는 지금과 같다. 조각의 `{{step:<id>}}` 는 지금처럼 번호로 풀린다

- Mermaid 를 그림으로 그리는지는 뷰어에 달렸다. 대상 GitHub · GitLab 버전이 그리는지 <!-- TBD: 확인 필요 -->.
  그리지 않는 곳에서는 코드 블록으로 보이고, 다음 표가 같은 배선을 글로 담는다

## 10. 커맨드

- 슬래시 커맨드는 **agent 절차이면서 하위 절차가 아닌 절차**에만 있다
  - 프로젝트 절차: `.claude/commands/<절차>.md` 생성(`plan()`)과 자산 표 행(`command_rows()`)을 이 조건으로 만든다
  - 기본 절차의 관리 커맨드(`.claude/commands/prework.md` · `work.md`): 그 절차가 driver 이거나 하위 절차면 설치하지 않고 자산 표 행도 뺀다.
    쓰지 않는 역할의 커맨드를 빼는 판정과 같은 자리에서 가른다. 지난 설치가 깐 것은 정리가 지운다
- driver 절차를 시작하는 방법은 9-2 의 실행 안내와 README 가 적는다

## 11. `harness steps` · `harness schema`

### 11-1. `harness steps` 쓰기 — 키 보존

- 단계마다 받은 키를 전부 쓴다. 순서는 `id` · `type` · `title` · `role` · `run` · `workflow` · `schema` · `on` · `access` · `options` · `text` · `next` · `set`,
  그 밖의 키는 이름 순이다. 값이 빈 문자열인 키는 지금처럼 쓰지 않는다
- 빈 표 · 빈 배열인 키는 빼지 않고 쓴다(`next = {}`). 빈 `next` 는 명시 배선의 표시다 (2-3) — 빼면 절차가 암묵 배선으로 바뀐다
- 값의 표기: 문자열은 JSON 인용, 정수 · 실수 · 불리언은 TOML 표기, 배열은 `[…]`, 표는 키를 JSON 인용한 인라인 표(`{ "0" = "done", "*" = "stop" }`)다.
  값이 null 이면 거부한다: `error: steps[<번호>].<키> is null`
- 절차 키(`title` · `execute` · `max_steps` · `max_visits`)
  - JSON 이 배열이면 지금 설정의 절차 키를 그대로 둔다
  - 객체면 그 안의 절차 키가 값을 정하고, 없는 절차 키는 지금 값을 둔다. `title` 이 빈 문자열이면 지운다
- 절의 줄 순서: `[workflows.<절차>]` · `title` · `execute` · `max_steps` · `max_visits` · `steps`
- `--dry-run` 도 같은 규칙으로 만든 정의를 검사한다
- 저장한 뒤 다시 읽은 설정의 그 절차는 받은 JSON 과 같다 — 단계 키 · 값 · 절차 키가 하나도 빠지지 않는다
- 읽기(`harness steps`)는 지금처럼 단계마다 모든 키를 낸다
- 다른 절차가 가리키는 절차의 이름 바꾸기 · 지우기(`--rename` · `--delete`)는 6절 검증에 걸려 되돌린다

### 11-2. `harness schema`

이 명세가 더하는 키는 둘이다.

| 키 | 값 |
|---|---|
| `workflows.<절차>.execute` | 그 절차의 실행 방식. 기본값을 채운 값이다 — `execute` 를 적지 않은 절차는 `"agent"` |
| `output_schemas` | `{"<이름>": {"source": "harness" \| "project", "path": "<하네스 루트 기준 경로>", "fields": {"<필드>": ["<값>", ...]}}}` |

- `output_schemas` 는 agent 블록이 고를 수 있는 구조화 출력 스키마다. 동봉과 프로젝트 두 자리(5-1)를 모두 든다
- `fields` 는 `on` 이 가리킬 수 있는 필드(5-2 의 `on` 조건을 만족하는 최상위 필드)와 그 열거값이다. 그런 필드가 없으면 빈 객체다
- 읽지 못하거나 5-2 를 어긴 스키마 파일은 목록에서 빠진다. 그 이름을 쓰는 단계는 render · `harness steps --dry-run` 이 거부한다 (6절)
- 같은 출력의 블록 편집 키(`blocks` · `ends` · `wildcard` · 최상위 `execute` · `workflows.<절차>.command`)는 #214 가 더한다. 값은 이 명세의 정의에서 만든다

## 12. 사람용 문서

| 문서 | 적는 사실 |
|---|---|
| `README.md` 명령 표 | `harness run <절차> <이슈> [--worktree] [--resume] [--discard]` — agent 절차는 오케스트레이터로, driver 절차는 하네스가 직접 실행한다 |
| `README.md` "`harness.toml` 이 정하는 것" | `workflows.<절차>.execute` · `max_steps` · `max_visits`, 단계의 `next` · `on` · `schema` · `set` · `options` · `access` · `workflow` — driver 절차의 문서는 그래프와 다음 표를 담고 커맨드가 없다 |
| `README.md` 실행 계획 문단 (#207 이 둔 것) | `roles.<역할>.driver` · `prompt` 자리 — driver 절차의 agent · prompt 블록이 쓴다 |
| `src/templates/defaults.toml` "절차" 머리 주석 | 실행 방식, 블록 다섯, 배선과 끝 상태, 자리표시, 스키마 자리. 기본 절차의 값은 바꾸지 않는다 |
| `src/templates/managed/docs/workflow/changing.md` "절차의 단계를 바꾼다" | 단계 종류 표의 workflow 블록, 실행 방식과 배선, 자리표시, 스키마 자리와 문법, 확장 지점 |
| `src/templates/managed/docs/workflow/flow.md` | driver 절차가 도는 방식 — 드라이버 · 게이트 · 재개 · 실행 상태 · 종료 코드 |
| `src/templates/managed/script/README.md` | `run-agent.py` 의 `--driver` · `--driver-prompt` · `--schema` |
| `src/templates/vendors.toml` 머리 주석 | `agent` · `driver_write` · `structured` |

## 13. 회귀 테스트

에이전트 CLI 는 부르지 않는다. 오케스트레이터와 러너는 PATH 앞에 둔 스텁이다 — claude 스텁은 `--output-format json` 결과 객체를,
codex 스텁은 `--json` 이벤트 줄을 흉내 내고, 받은 인자와 프롬프트를 기록하고, 케이스가 정한 결과 본문과 종료 코드를 낸다.
게이트의 답은 표준 입력으로 준다. 실제 대기는 없다. 등록부는 `HARNESS_HOME` 으로 테스트 작업 디렉터리 아래에 둔다.

### 13-1. `render-test.sh` — 새 블록

블록 번호는 착수 시점의 다음 번호를 쓴다. 터미널 출력의 한글 검사는 이 블록들에도 적용한다.

| 블록 | 케이스 | 확인하는 것 |
|---|---|---|
| 블록 그래프 검증 | 거부 | 6절 표의 행마다 그 조건을 하나만 어긴 설정을 render 가 종료 코드 2 와 6절의 위치 표기로 거부한다 — 배선 칸은 `next["<outcome>"]`(`.` 이 든 outcome 이름 포함), 배선 섞임 · 도달 · 끝은 단계 위치 |
| | 빈 `next` | 한 단계의 `next` 가 빈 표인 절차가 명시 배선으로 판정되어 완전성(script 가 아닌 블록) · 끝(script) 검사로 거부된다. 암묵 배선으로 읽히지 않는다 |
| | 받아들임 | 명시 배선 · 암묵 배선 · 하위 절차 · 빈 하위 절차 · 프로젝트 스키마를 쓰는 최소 driver 절차가 render 된다 |
| agent 절차 불변 | 생성물 | 소스 트리 복제에서 render 한 뒤 `.ai/workflows/*.md` · `.claude/commands/*.md` 가 바뀌지 않고 `harness check` 가 통과한다 |
| | driver 전용 키 | agent 절차의 † 키 · 상한 키 · `{steps.…}` 를 render 가 거부한다 |
| | workflow 블록 | 하위 절차를 부르는 agent 절차의 문서에 9-1 의 제목 줄과 본문, 빈 하위 절차의 본문이 있다 |
| driver 문서 | 그래프 | Mermaid 블록 · 끝 상태 범례 · 단계마다 다음 표가 있고, 시작 표지 줄이 없다 |
| | 암묵 배선 | `next` 없는 driver 절차의 다음 표와 간선이 2-4 와 같다 |
| 커맨드 | driver | 프로젝트 driver 절차에 `.claude/commands/<절차>.md` 와 자산 표 행이 없다 |
| | 관리 커맨드 | 기본 `work` 를 driver 로 두고 render 하면 `.claude/commands/work.md` 가 없어지고 자산 표 행이 빠진다. agent 로 되돌리면 다시 생긴다 |
| | agent 하위 절차 | 하위 절차인 프로젝트 agent 절차에 커맨드가 없고 `harness run` 이 2 로 거부한다 |
| `harness steps` 보존 | 왕복 | 모든 단계 키(`next` · `set` · `options` · 모르는 키 포함)와 절차 키를 담은 JSON 으로 저장한 뒤 읽은 결과가 같다 |
| | 배열 입력 | 배열로 저장해도 `execute` · `max_steps` 가 남는다 |
| | `--dry-run` | 새 키가 든 정의를 검사하고 설정을 바꾸지 않는다 |
| | 빈 표 | `next = {}` 인 단계를 담은 JSON 으로 저장한 뒤 다시 읽으면 `next` 가 빈 표로 남는다 |
| `harness schema` | 출력 | `workflows.<절차>.execute`(적지 않은 절차는 `agent`)와 `output_schemas` 의 두 자리 항목 · `source` · `path` · `fields`(`on` 이 가리킬 수 있는 필드와 열거값). 문법을 어긴 프로젝트 스키마는 빠진다 |
| 실행 계획 | `driver` · `prompt` | `harness run-plan` 출력에서 `entry` 없는 켜진 역할마다 `driver` 가, 최상위 `prompt` 에 두 권한이 있고 7-4 의 키를 갖는다. `code-reviewer` 에는 `driver` 가 없다. 개인 레이어의 러너 · 오케스트레이터가 `vendor` 에 반영된다 |
| driver 실행 | 암묵 직선 | script 셋이 차례로 돌고 `done`, 종료 코드 0, 상태 파일이 없다 |
| | 종료 코드 배선 | 종료 코드마다 배선된 단계로 가고, 표에 없는 코드는 `"*"` 로, `"*"` 도 없으면 `stop` 과 이유 |
| | 표준 출력 토큰 | `on = "stdout"` 의 첫 토큰으로 가고, 종료 코드가 0 이 아니면 `"*"` 로 간다 |
| | 출력과 변수 | script 의 JSON 출력을 `set` 으로 올리고 다음 script 의 인자에 푼 값이 공백 · `;` 를 담아도 인자 하나로 들어간다(받은 argv 기록). 배열 · 객체 값은 압축 JSON 인자 하나로 들어간다 |
| | 값 없음 | 없는 변수나 null 값을 쓰면 그 블록이 돌지 않고 `stop` 1, 이유 `has no value`. 빈 문자열 값은 빈 인자 하나로 들어가고 블록이 돈다 |
| | 이슈 형식 | Jira 키 이슈로 driver 절차가 돌고 상태 파일 이름이 `<절차>-<키>.json` 이며 doctor 가 그 실행을 읽는다. 숫자도 Jira 키도 아닌 이슈는 2. Jira 키에 `--worktree` 를 주면 2 와 71 명세의 문구 |
| | 하위 절차 직접 시작 | 부르는 절차가 올리는 변수를 쓰는 driver 하위 절차를 `harness run` 으로 시작하면 2 이고 상태가 생기지 않는다. 자기 `set` 변수만 쓰는 driver 하위 절차는 직접 돈다 |
| | agent 와 스키마 | claude 스텁과 codex 스텁 각각에서 결과 블록의 필드 값으로 가고, 프롬프트에 스키마 원문과 푼 `text` 가 있다 |
| | 검증 위반 | 스키마를 어긴 결과와 블록 둘인 결과가 `failed` 로 가고, `warn:` 줄에 결과 본문의 문자열이 없다 |
| | inproc 역할 | 러너가 `inproc` 인 역할이 오케스트레이터 벤더의 스텁으로 불리고 claude 면 `--agent <역할>` 이 있다 |
| | 권한 인자 | 쓰기 역할 · `write` prompt 블록은 `driver_write`(선언이 없으면 `access.write`), 읽기 블록은 `access.read-only` 인자로 불린다 |
| | prompt 블록 | 역할 인자 없이 오케스트레이터 스텁이 불린다 |
| | 게이트 | 이름과 번호 답이 그 선택지로 가고, 터미널이 아닌 잘못된 답은 4 로 멈춘다 |
| | 멈춤과 재개 | EOF 로 4, 상태 파일 0600 · 디렉터리 0700 · `waiting`. 답을 주고 `--resume` 하면 이어서 `done` 이고 상태 파일이 없다 |
| | 중단과 재개 | script 가 드라이버에 SIGINT 를 보내면 130 이고 상태가 `running`. 재개하면 그 단계가 다시 불린다(호출 기록 두 번) |
| | digest | 멈춘 뒤 설정을 바꾸고 재개하면 2 |
| | 상태가 있을 때 | 새 실행이 2, `--discard` 가 0 으로 지우고, 다시 `--discard` 해도 0 |
| | 잠금 | 다른 프로세스가 잠금을 쥐고 있으면 2 |
| | 읽지 못하는 상태 | 깨진 상태 파일과 표에 없는 필드가 든 상태 파일에서 새 실행 · 재개가 2 이고 doctor 에 `unreadable run state`. `preset` 이 없거나 null 인 상태는 읽힌다 |
| | 상한 | 순환 배선에서 `max_visits` · `max_steps` 에 닿으면 `stop` 1 과 이유 |
| | handoff | 3 |
| | 하위 절차 | 바깥 변수를 읽고, 끝 상태가 바깥 outcome 이 되고, 빈 하위 절차는 곧바로 `done`. 하위 절차의 `set` 변수를 바깥에서 쓰면 render 가 거부한다 |
| | 실행 시점 불변식 | 개인 레이어로 구현자와 리뷰어의 러너를 같게 두면 2 이고 상태가 생기지 않는다 |
| | 러너 없음 | 러너 실행 파일이 없으면 2 이고 상태가 생기지 않는다 |
| | agent 절차 | `--resume` · `--discard` 가 2, `--dry-run` 명령줄은 이 변경 전과 같다 |
| | worktree | 게이트에서 멈춘 `--worktree` 실행의 worktree 가 남고, `--resume --worktree` 가 같은 worktree 에서 잇고, `--resume` 만 주면 2, worktree 를 지운 뒤 `--resume --worktree` 는 2 |
| | 지표 | run 스팬과 블록 스팬(`workflow` · `step`), 역할 실행기 스팬의 부모가 블록 스팬이다. 스팬 파일에 출력의 표지 문자열이 없다. `by_step` 이 블록마다 한 번 세고 토큰을 더한다. Jira 키 이슈의 스팬에는 `issue` 속성이 없다 |
| | `--bare` | 벤더 선언의 어느 argv 에도 `--bare` 가 없다 |
| | doctor | 멈춘 실행이 `runs` 절에 `warn`, 없으면 `no unfinished runs` |
| 역할 실행기 | `--driver` | 서브에이전트 역할을 실행하고 `roles.<역할>.driver` 의 argv 로 띄운다. `--schema` 는 `structured` 가 비지 않은 항목에만 인자를 붙인다. 항목이 없는 역할(`entry` 역할)은 2 |
| | `--driver-prompt` | 역할 인자 없이 `prompt.<권한>` 의 argv 로 띄운다 |
| | 기존 호출 | `--driver` 없이 서브에이전트 역할을 부르면 지금처럼 2 |

### 13-2. Python 단위 테스트 — `src/test/unit/`

| 대상 | 확인하는 것 |
|---|---|
| 배선 | 명시 · 암묵 배선 해석, 도달 · 끝 판정, outcome 집합과 완전성 |
| 자리표시 | 이름 파싱(중괄호 경계 포함), 풀기, 값 형식(문자열 · 빈 문자열 · 정수 · 배열과 객체의 압축 JSON, 불리언 · 실수 거부), 값 없음(키 없음 · null) |
| 스키마 | 5-2 문법 검사, 검증기(type · required · additionalProperties · enum · minLength · items), 5-3 꺼내기 |
| 위치 표기 | 6절의 세 표기, `.` · `"` 가 든 outcome 이름의 JSON 문자열 표기 |
| 상태 | 직렬화와 검증(표에 없는 필드 거부, `preset` 필드 없음 · null · 문자열), 원자적 쓰기, digest 가 키 순서에 무관하고 정의 변경에 바뀜, 파일 이름에서 절차와 Jira 키 · 숫자 이슈 가르기 |
| 문서 | Mermaid 노드 · 간선 · 따옴표 처리, 다음 표 |
| 집계 | `by_step` 의 kind `step` 우선 규칙 |

### 13-3. UI 단위 테스트

| 파일 | 케이스 |
|---|---|
| `doctor.test.js` | `SECTIONS.runs` 가 `"실행"` 이다. 8-5 의 두 `warn` 줄이 원문과 다른 제목 · 본문과 조치 명령으로 옮겨진다 |

회귀 테스트 전체(`script/run-lint-test.sh`)가 통과한다.

## 14. 보호 문서 개정 범위

사람이 지시한 턴에 분해의 task 하나가 반영한다. 적용 순서는 #206 → #207 → 이 명세다. 아래 문안은 #206 · #207 이 고친 문장 위에
더하는 것이고, 그 두 명세가 고친 문장을 지우거나 되돌리지 않는다. 같은 위치를 뒤 명세(#211 · #212 · #213 · #215)가 이 문안 위에 이어 고친다.

### 14-1. `.ai/project/scope.md`

"할 수 있는 일" 의 `run` 항목에서 첫 문장만 바꾼다.

| 위치 | 지금 (#207 개정 뒤) | 고친 문안 |
|---|---|---|
| `run` 항목의 첫 문장 | 설정된 오케스트레이터로 절차를 시작한다 (`run`). | 절차를 시작한다 (`run`). 절차마다 실행 방식을 고른다 — agent 절차는 설정된 오케스트레이터가 절차 문서를 따라 돌고, driver 절차는 하네스가 블록 그래프(script · agent · prompt · gate · workflow 블록과 outcome 배선)를 결정론으로 실행한다. driver 실행은 게이트에서 멈추고 `--resume` 으로 잇는다. |

- 같은 항목의 나머지 문장 — 기본 절차 셋, 이슈별 worktree, #207 이 끝에 더한 `run-plan` 문장 — 은 그대로 둔다. 기본 절차 문장은 #212 가 고친다

### 14-2. `.ai/project/architecture.md`

| 위치 | 고치는 방법 | 문안 |
|---|---|---|
| "구성 요소" — #206 이 둔 `src/harness/` 항목 뒤 | 새 항목 | `src/harness/workflow/` — 절차 정의(블록 · 배선 · 자리표시)를 검증하고 driver 절차를 실행한다(드라이버 · 실행 상태 · 구조화 출력 검증). `src/harness/schemas/` — 동봉 구조화 출력 스키마 |
| "구성 요소" 의 기기 단위 상태 항목 | 끝(#206 이 더한 `.cache/pycache/` 뒤)에 더한다 | `<클론 키>/runs/` — 끝나지 않은 driver 실행의 상태와 잠금(디렉터리 0700 · 파일 0600). 끝 상태에 닿으면 지운다 |
| "데이터 흐름" 의 절차 실행 — 첫 문장 | 항목 머리 `절차 실행:` 바로 뒤, 첫 문장(`harness run` → 오케스트레이터 CLI → …) 앞에 붙인다. 첫 문장 자체(#207 이 고친 괄호 포함)는 그대로다 | `harness run` 은 절차의 실행 방식으로 가른다. agent 절차: |
| "데이터 흐름" 의 절차 실행 — 첫 문장 뒤 | 새 문장 | driver 절차: 드라이버가 첫 단계부터 블록을 돌려 outcome 을 얻고 배선을 따라간다 — script 블록은 셸 없이 직접, agent · prompt 블록은 역할 실행기가 실행 계획의 `driver` · `prompt` 항목으로 헤드리스 한 번, gate 는 터미널 입력, workflow 블록은 하위 절차. 블록마다 실행 상태를 쓰고 끝 상태에서 지운다 |
| "신뢰 경계" 의 들어오는 입력 | 끝(#207 이 더한 `harness.local.toml` 뒤)에 더한다 | agent 블록의 결과 본문 — 구조화 출력은 스키마로 엄격히 검증하고 어기면 outcome 이 `failed` 다. script 블록의 표준 출력. 실행 상태 파일 — 기기 로컬이지만 형식(모르는 필드 포함)과 정의 digest 를 검증하고 어긋나면 재개하지 않는다 |
| "신뢰 경계" | 새 항목 | 블록 출력과 절차 변수는 셸을 거치지 않고 argv 원소 하나로만 들어간다(배열 · 객체는 압축 JSON 한 원소). script 블록은 드라이버가 셸 없이 실행하므로 에이전트 명령 가드가 걸리지 않는다 — 명령은 커밋된 설정에서 오고 git 훅은 그대로 걸린다. driver 의 쓰기 역할은 그 실행 하나에 한해 벤더 선언의 `driver_write` 인자로 커밋 · 작업 브랜치 push · 리뷰 요청 생성과 댓글 · 이월 이슈 생성을 승인 없이 한다. 보호 브랜치 push 와 force push 는 deny · 가드 · pre-push 가 그대로 막고, 헤드리스 실행에 `--bare` 를 쓰지 않는다. 실행 상태는 구조화 출력을 담으므로 끝 상태에서 지운다 |
| "새 코드를 둘 곳" | 새 항목 셋 | 새 블록 종류 → `src/harness/workflow/` 의 블록 표(키 · outcome · 출력 · 암묵 배선 · 문서 표기)와 render 검증. 동봉 스키마 → `src/harness/schemas/<이름>.json` 과 그것을 쓰는 역할 계약의 출력 절. 프로젝트 스키마 → 대상 리포의 `.ai/project/schemas/<이름>.json` |
| "계층과 의존 방향" | 새 항목 | 드라이버는 역할을 공용 역할 실행기로만 띄운다. 역할 계약은 자기 출력 스키마의 이름과 필드 뜻만 알고 배선을 모른다 |

### 14-3. `.ai/project/glossary.md`

| 위치 | 반영할 문안 |
|---|---|
| "용어" — 새 행 `블록` | 단계의 `type` 이 정하는 실행 단위. script · agent · prompt · gate · workflow |
| "용어" — 새 행 `outcome` | 블록 하나가 끝나며 내는 결과 이름. 배선의 키다 |
| "용어" — 새 행 `배선` | 단계의 `next` — outcome 에서 다음 단계나 끝 상태로 가는 표. 절차 단위로 명시하거나 모두 생략(암묵 배선)한다 |
| "용어" — 새 행 `끝 상태` | 절차 실행의 끝 셋 — `done`(성공) · `stop`(실패 보고) · `handoff`(리뷰 요청을 연 채 사람에게) |
| "용어" — 새 행 `실행 방식` | 절차의 `execute`. agent(오케스트레이터가 절차 문서를 따른다) · driver(하네스가 블록 그래프를 실행한다) |
| "용어" — 새 행 `드라이버` | driver 절차를 실행하는 하네스 코드(`src/harness/workflow/`). `harness run` 이 부른다 |
| "용어" — 새 행 `하위 절차` · `확장 지점` | workflow 블록이 부르는 절차. 단계가 없는 하위 절차가 확장 지점이다 |
| "용어" — 새 행 `절차 변수` | `set` 이 단계 출력에서 올린 값. 단계 값에서 `{이름}` 으로 쓴다 |
| "용어" — 새 행 `구조화 출력 스키마` | agent 블록 출력의 계약(JSON Schema 부분 집합). 동봉(`src/harness/schemas/`)과 프로젝트(`.ai/project/schemas/`) 두 자리 |
| "용어" — 새 행 `실행 상태` | 끝나지 않은 driver 실행의 기기 로컬 스냅숏(`<클론 키>/runs/<절차>-<이슈>.json`). `--resume` 이 읽는다 |
| "용어" 의 `절차(워크플로)` — 고친 뜻 | 단계(블록)와 배선으로 엮은 것. `.ai/workflows/<절차>.md` 로 생성된다 |
| "용어" 의 `게이트` — 고친 뜻 | 사람의 결정 · 승인을 기다리는 절차 단계. driver 절차에서는 드라이버가 터미널에서 묻는다 |

- `실행 방식` 행은 이 명세의 것 하나다. 역할이 서브에이전트로 도는지 CLI 러너로 도는지는 #207 의 `러너 방식` 행이 갖는다
- `확장 지점` 의 preset 쪽 문장은 #216 이 이 행 끝에 더한다

### 14-4. `.ai/project/testing.md`

| 위치 | 지금 | 고친 문안 |
|---|---|---|
| "외부 의존을 어떻게 다루나" 의 에이전트 CLI 항목 | 에이전트 CLI 는 부르지 않는다. 리뷰어·오케스트레이터는 스텁 실행 파일을 PATH 앞에 두어 두 벤더의 출력 형식만 흉내 낸다. `harness run` 은 `--dry-run` 으로 명령줄만 본다 | 에이전트 CLI 는 부르지 않는다. 리뷰어 · 오케스트레이터 · driver 의 역할 러너는 스텁 실행 파일을 PATH 앞에 두어 두 벤더의 출력 형식만 흉내 낸다. agent 절차의 `harness run` 은 `--dry-run` 으로 명령줄만 보고, driver 절차는 스텁과 표준 입력으로 준 게이트 답으로 끝까지 돌린다 |

## 15. 한계

- 실행 상태는 클론 하나에 있다. 다른 클론 · 다른 기기에서, 또는 상태를 지운 뒤에는 이어 돌 수 없다
- 재개는 진행 중이던 단계를 처음부터 다시 돈다. 그 단계가 이미 남긴 부수 효과(커밋 · 댓글 · 회차 라벨)는 되돌리지 않는다
- 블록에 시간 제한이 없다. 멈춘 블록은 중단 신호로 끊고 재개한다
- driver 절차의 이슈는 숫자이거나 Jira 키다(7-1). Jira 키 이슈는 `--worktree` 로 돌릴 수 없고(71 명세의 숫자 규칙), 스팬에 `issue` 속성이 남지 않아
  지표를 이슈로 묶어 볼 수 없다 — 지표 기록기의 이슈 검사식이 숫자만 받는다
- 같은 이슈의 같은 절차를 다른 클론에서 동시에 도는 것은 막지 않는다
- 하위 절차의 변수 참조는 render 가 이름만 본다 — 어느 경로에서 값이 채워지는지는 실행 때 4-3 이 판정한다
- 기본 절차 `work` 를 driver 로 두면 생성되는 `CLAUDE.md` 의 커맨드 흐름 서술과 맞지 않는다. 그 서술은 기본 절차를 driver 로 바꾸는 변경이 함께 고친다
