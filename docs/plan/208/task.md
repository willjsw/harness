# #208 task

## T1 · feat: 절차의 실행 방식과 블록 다섯의 단계 키를 render 가 검증

### 상위 Requirement

- relates to #208

### 작업 내용

render 가 절차의 실행 방식(`execute`)과 블록 다섯의 단계 키를 검증한다. 블록 표를 한 자리에 두고 render 검증 · 절차 문서 ·
드라이버가 그 표를 쓴다. 배선 · 스키마 · 자리표시는 보지 않는다(T2 · T3). workflow 블록의 문서는 T4 가 만든다.

- 명세 2-1 · 2-2 · 2-5, 6절의 실행 방식 · 블록 종류 · 키 · driver 전용(† 키와 상한 키) · 빈 절차 · 하위 절차 · 역할 · 명령 ·
  프롬프트 · 선택지 · 상한 행, 6절 위치 표기 가운데 절차와 단계
- `src/harness/workflow/` 패키지를 만든다. `__init__.py` 는 docstring 만 갖는다
- `blocks.py` — 블록 다섯과 블록마다 받는 단계 키(2-2 표), 절차 키(2-1 표), driver 전용 키(†), 끝 상태 셋(`done` · `stop` ·
  `handoff`). 블록 순서는 지금 넷(agent · script · prompt · gate) 뒤에 workflow 다. `src/harness/config/workflows.py` 의
  `STEP_KINDS` 는 이 표에서 나온다
- `validate.py` — 아래 검사. `validate_workflows()` 가 지금 검사(절차 이름 · 단계 id · 제목 · agent 의 역할 · script 의 `run` ·
  prompt 의 조각과 `text`) 뒤에 부른다
  - 실행 방식: `execute` 는 `"agent"` · `"driver"` 다. 적지 않은 절차는 agent 절차다
  - 키: driver 절차의 절과 단계에서 2-1 · 2-2 표에 없거나 그 블록이 받지 않는 키를 거부한다. agent 절차는 † 키(`next` · `on` ·
    `schema` · `set` · `options` · `access`)와 `max_steps` · `max_visits` 를 거부하고, 그 밖의 모르는 키는 지금처럼 넘긴다
  - 하위 절차: workflow 블록의 `workflow` 가 설정에 없는 절차다 · 자기 자신이다 · 호출이 순환한다 · 부르는 절차와 `execute` 가 다르다
  - 빈 절차: 단계가 없는데 어느 workflow 블록도 가리키지 않으면 지금 문구의 첫 줄(`… is empty — a workflow needs at least one step`)과
    하위 절차만 비어 있을 수 있다는 `help:` 줄로 거부한다. 하위 절차면 받아들인다
  - 역할: driver 절차의 agent 블록은 `entry` 가 있는 역할을 러너와 상관없이 거부한다. agent 절차의 판정은 지금과 같다
  - 명령: driver 절차의 script `run` 이 `shlex.split` 에 실패한다 · 셸 연산자로만 된 원소(`;` `&` `|` `<` `>` 와 그 조합, 앞에
    숫자가 붙은 리다이렉트)가 있다 · 원소에 `$` 나 `` ` `` 가 있다
  - 프롬프트: `access` 가 `read-only` · `write` 가 아니다
  - 선택지: `options` 가 서로 다른 outcome 이름(`^[A-Za-z0-9_.-]{1,64}$`) 1개 이상의 배열이 아니다
  - 상한: `max_steps` · `max_visits` 가 1 이상 1000 이하 정수(불리언 제외)가 아니다
  - 오류 줄은 `error: workflows.<절차>` 로 시작한다. 위치는 절차 전체면 `workflows.<절차>`, 단계면 `workflows.<절차>.steps[<번호>]`(0 부터)다
- `render-test.sh` 에 "블록 그래프 검증" 블록과 "agent 절차 불변" 블록을 연다. "agent 절차 불변" 의 생성물 케이스는 뒤 task 에서도
  기본 절차 생성물이 바뀌지 않았음을 확인하는 기준이다
- 건드릴 파일: `src/harness/workflow/__init__.py` · `blocks.py` · `validate.py`(신규), `src/harness/config/workflows.py`,
  `src/test/render-test.sh`, `src/test/unit/test_workflow_validate.py`(신규)

### 완료 조건

- [ ] 이 task 가 맡은 6절의 행마다 그 조건 하나만 어긴 설정을 render 가 종료 코드 2 로 거부하고, 오류 줄이 `error: workflows.<절차>` 와 그 위치로 시작한다
- [ ] agent 절차의 † 키와 상한 키를 render 가 거부하고, agent 절차의 그 밖의 모르는 단계 키는 지금처럼 통과한다
- [ ] 하위 절차로 불리는 빈 절차가 render 를 통과하고, 불리지 않는 빈 절차는 지금 문구의 첫 줄과 `help:` 줄로 거부된다
- [ ] `execute` 를 적지 않은 절차가 agent 절차로 판정된다
- [ ] 소스 트리 복제에서 render 한 뒤 `.ai/workflows/*.md` · `.claude/commands/*.md` 가 바뀌지 않고 `harness check` 가 통과한다
- [ ] `python3 script/project/check-cli.py imports` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 실행 방식 | `execute = "auto"` 인 절차 | 2, 위치 `workflows.<절차>` |
| UT-02 | 블록 종류 | `type = "loop"` 인 단계 | 2, 위치 `workflows.<절차>.steps[<번호>]` |
| UT-03 | driver 의 키 | driver 절차의 script 단계에 `role`, 절차에 `command` | 각각 2 |
| UT-04 | agent 절차의 driver 전용 키 | agent 절차 단계에 `next` · `on` · `schema` · `set` · `options` · `access`, 절차에 `max_steps` · `max_visits` | 각각 2 |
| UT-05 | agent 절차의 모르는 키 | agent 절차 단계에 `note = "x"` | 통과 |
| UT-06 | 빈 절차 | 불리지 않는 빈 절차 / workflow 블록이 가리키는 빈 절차 | 2 와 지금 문구 첫 줄 · `help:` / 통과 |
| UT-07 | 하위 절차 | 없는 절차 · 자기 자신 · `a → b → a` 순환 · agent 절차가 driver 절차를 부름 | 각각 2 |
| UT-08 | driver 의 entry 역할 | driver 절차의 agent 블록 `role = "code-reviewer"`(러너 `inproc` 포함) | 2 |
| UT-09 | driver 의 명령 | `run` = `a \| b` · `a > f` · `a 2>&1` · `echo $HOME` · `` echo `id` `` · 닫히지 않은 따옴표 | 각각 2 |
| UT-10 | 프롬프트 · 선택지 · 상한 | `access = "admin"`, `options = []` · 중복 · `a b`, `max_steps` = `0` · `1001` · `true` | 각각 2 |
| UT-11 | 위치 표기 (단위) | 절차 `w`, 단계 번호 2 | `workflows.w` · `workflows.w.steps[2]` |
| UT-12 | 기본 절차 생성물 | 소스 트리 복제에서 render | `.ai/workflows/*.md` · `.claude/commands/*.md` 가 같고 `harness check` 0 |

## T2 · feat: 구조화 출력 스키마의 자리·문법·검증과 schema 출력의 output_schemas·execute

### 상위 Requirement

- relates to #208

### 작업 내용

agent 블록이 가리키는 구조화 출력 스키마를 두 자리에서 찾고, 문법을 render 가 검사한다. 드라이버가 쓸 검증기와 결과 본문에서
출력을 꺼내는 함수를 둔다. `harness schema` 가 고를 수 있는 스키마와 절차의 실행 방식을 낸다.

- 명세 5절, 6절의 스키마 행, 11-2
- `src/harness/workflow/schemas.py`
  - 자리: 동봉은 패키지의 `schemas/`(#206 의 `harness.base.PACKAGE` 아래, 고정 사본은 `.harness/lib/harness/schemas/`), 프로젝트는
    하네스 루트의 `.ai/project/schemas/`. 디렉터리가 없으면 그 자리의 스키마는 없다. 이름은 `^[a-z][a-z0-9-]{0,40}$` 이고 파일 이름에서
    `.json` 을 뺀 것이다. 프로젝트 자리에서 `.json` 이 아닌 파일은 읽지 않는다
  - 문법 검사(5-2): 표의 키워드만 받는다. 최상위는 `type = "object"`, `required` 는 모두 `properties` 에 있고, `enum` 은 1개 이상 ·
    서로 다름 · `type` 과 맞음, `minLength` 는 0 이상 정수(불리언 제외), `additionalProperties` 는 불리언이다
  - `on` 필드 조건: 최상위 `properties` 와 `required` 에 있고 `type = "string"` 이며 `enum` 이 있고, 열거값이 outcome 이름 형식이고
    `failed` 가 아니다. 조건을 만족하는 필드와 열거값을 내는 함수 하나를 render 검증 · `harness schema` · T3 의 outcome 집합이 쓴다
  - 검증기: `type`(`integer` 는 소수부가 없는 수, `number` 는 수, 둘 다 불리언 제외) · `required` · `additionalProperties` · `enum` ·
    `minLength`(문자 수) · `items`. 어긴 곳의 위치와 사유를 낸다
  - 꺼내기(5-3): 앞뒤 공백을 뺀 전체가 JSON 객체면 그것, 아니면 info string 이 `json` 인 fenced 블록이 정확히 하나이고 내용이 JSON
    객체면 그것이다. 그 밖과 직렬화 크기 1 MiB 초과는 꺼내지 못한 것이다
- render 검증(`validate.py`): agent 블록의 없는 스키마 이름 · 문법을 어긴 파일 · 두 자리의 이름 겹침 · `schema` 없는 `on` · `on`
  조건 위반을 거부한다. 프로젝트 자리의 `.json` 파일은 가리키지 않아도 문법을 본다. 프로젝트 자리를 찾도록 `validate_workflows()` 가
  하네스 루트를 받고, render · check · `harness steps` 가 넘긴다
- `harness schema`(`commands/schema.py`)
  - `workflows.<절차>.execute` — 기본값을 채운 값. `execute` 를 적지 않은 절차는 `"agent"`
  - `output_schemas` — `{"<이름>": {"source": "harness" | "project", "path": "<하네스 루트 기준 경로>", "fields": {"<필드>": ["<값>", ...]}}}`.
    `fields` 는 `on` 이 가리킬 수 있는 필드와 열거값이고 없으면 빈 객체다. 읽지 못하거나 문법을 어긴 파일은 빠진다
- 이 이슈는 동봉 스키마를 더하지 않는다. 동봉 자리를 쓰는 케이스는 소스 트리 복제의 `src/harness/schemas/` 에 시험용 스키마를 두고 본다
- `render-test.sh` 에 "`harness schema`" 블록을 열고, "블록 그래프 검증" 블록에 스키마 행을 더한다
- 건드릴 파일: `src/harness/workflow/schemas.py`(신규) · `validate.py`, `src/harness/config/workflows.py`, `validate_workflows()` 를
  부르는 곳, `src/harness/commands/schema.py`, `src/test/render-test.sh`, `src/test/unit/test_workflow_schemas.py`(신규)

### 완료 조건

- [ ] 6절 스키마 행의 조건마다 하나만 어긴 설정이 2 와 단계 위치로 거부된다 — 가리키지 않는 프로젝트 스키마의 문법 위반 포함
- [ ] 프로젝트 자리의 `.json` 이 아닌 파일은 읽지 않는다
- [ ] 동봉 자리 디렉터리가 없어도 render · check 가 통과한다
- [ ] `harness schema` 가 `workflows.<절차>.execute`(적지 않은 절차는 `"agent"`)와 `output_schemas` 의 두 자리 항목 · `source` · `path` · `fields` 를 내고, 문법을 어긴 프로젝트 스키마는 빠진다
- [ ] 기본 절차 생성물이 바뀌지 않는다(T1 의 생성물 케이스)
- [ ] `python3 script/project/check-cli.py imports` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 문법 검사 | 표 밖 키워드(`$ref` · `pattern`), 최상위 `type = "string"`, `properties` 밖의 `required`, 빈 · 중복 · 형이 다른 `enum`, `minLength` = `-1` · `true` | 각각 거부 |
| UT-02 | 검증기 type | `integer` 에 `1.5` · `true`, `number` 에 `true`, `string` 에 `1` | 각각 위반과 위치 |
| UT-03 | 검증기 나머지 | `required` 빠짐, `additionalProperties = false` 밖의 키, `enum` 밖 값, `minLength` 미달, `items` 위반 원소 | 각각 위반과 위치 |
| UT-04 | 꺼내기 | 전체가 JSON 객체 / `json` 블록 하나 / 블록 둘 / 블록 없음 / 전체가 배열 / 1 MiB 초과 객체 | 객체 · 객체 · 실패 · 실패 · 실패 · 실패 |
| UT-05 | `on` 필드 | `enum` 없는 string, `required` 밖, 열거값 `failed`, 형식 밖 열거값 | 각각 `on` 대상 아님 |
| UT-06 | render 거부 | 없는 이름, 동봉 · 프로젝트 이름 겹침, `schema` 없는 `on`, 가리키지 않는 깨진 프로젝트 스키마 | 각각 2 |
| UT-07 | `harness schema` | 동봉 하나 · 프로젝트 하나 · 깨진 프로젝트 하나, `execute` 없는 절차와 driver 절차 | 두 항목과 `fields`, 깨진 것 없음, `"agent"` · `"driver"` |

## T3 · feat: 배선·암묵 배선·자리표시·set 을 render 가 검증

### 상위 Requirement

- relates to #208

### 작업 내용

driver 절차의 배선과 자리표시를 render 가 검증한다. 드라이버와 절차 문서가 쓸 배선 · 자리표시 계산을 같은 모듈에 둔다.

- 명세 2-3 · 2-4 · 4-1 · 4-2 · 4-3 · 4-4, 6절의 배선 섞임 · 암묵 배선의 `on` · 대상 · outcome 키 · 완전성 · 도달 · 끝 · 자리표시 ·
  `set` 행, driver 전용 행의 `{steps.…}`, 2-2 의 예약 id, 6절의 outcome 집합 표와 위치 표기
- `src/harness/workflow/graph.py`
  - 배선 판정: 한 단계라도 `next` 가 있으면(빈 표 포함) 명시 배선, 어느 단계에도 없으면 암묵 배선이다
  - outcome 집합(6절 표 — `on` 이 있는 agent 는 T2 의 `on` 필드 열거값과 `failed`), 실효 배선(명시면 단계의 `next`, 암묵이면 2-4 를
    펼친 것 — script · gate 의 "그 밖" 은 `"*"`, 마지막 단계의 "다음 단계로" 는 `done`), 시작 단계(목록의 첫 단계)
  - 도달(첫 단계에서 `next` 를 따라 닿는가), 끝(어느 끝 상태에 닿는가 — script 의 표에 없는 outcome 이 `stop` 으로 가는 것은 세지 않는다)
- `src/harness/workflow/placeholders.py`
  - 이름 파싱: `{` 와 `}` 사이가 영문자 · 숫자 · `_` · `.` · `-` 1자 이상이고 앞뒤에 다른 중괄호가 붙지 않은 것. `{}` · `{a: .b}` ·
    `{{…}}` 는 글자 그대로
  - 이름 형식: `{issue}`, `{<변수>}`(`^[a-z][a-z0-9_]{0,31}$`, `issue` · `steps` 제외), `{steps.<id>.out.<키>}`(키 `^[A-Za-z_][A-Za-z0-9_]{0,63}$`)
  - 풀기(T10 의 드라이버가 쓴다): 문자열은 그대로(빈 문자열도 값), 정수(불리언 제외)는 10진, 배열 · 객체는 압축 JSON(구분자 `,` · `:`
    뒤 공백 없음, 키 순서 그대로, 비ASCII 를 이스케이프하지 않음). 키가 없거나 null 이면 `{<이름>} has no value`, 불리언 · 정수가 아닌
    수면 `{<이름>} is not a string, a whole number, an array or an object`. 변수는 그 절차 실행에서 찾고 없으면 바깥 실행으로 차례로 찾는다
- render 검증(`validate.py`)
  - 배선: 배선 섞임, 암묵 배선 절차의 `on`, 대상(같은 절차의 단계 id 도 끝 상태도 아님), 명시 배선 절차의 예약 id(`done` · `stop` ·
    `handoff`), outcome 키(형식 `^[A-Za-z0-9_.-]{1,64}$` 도 `"*"` 도 아님, script 가 아닌 블록에서 outcome 집합 밖의 키), 완전성(script 가
    아닌 블록에서 집합의 원소가 키로도 없고 `"*"` 도 없음), 도달, 끝
  - 자리표시: 푸는 곳(script 의 `run` 을 인자로 나눈 원소, agent · prompt · gate 의 `text`)에서 형식이 아닌 이름 · 같은 절차의 `set` 에도
    그 절차를 (거슬러 올라가며) 부르는 절차의 `set` 에도 없는 변수 · 같은 절차에 없는 단계의 출력 · 출력이 없는 블록(`on = "stdout"` 인
    script, 스키마 없는 agent, prompt · gate · workflow)의 출력 · 스키마 최상위 `properties` 밖의 키나 `type` 이 string · integer · array ·
    object 가 아닌 키
  - `set`: 변수 · 키 이름 형식, 출력이 없는 블록, 스키마의 최상위 `properties` 밖의 키나 형이 위 넷이 아닌 키
  - agent 절차: `run` · `text` 의 `{steps.…}` 자리표시만 거부한다. 나머지 중괄호는 풀지 않고 글자 그대로 문서에 들어간다
  - 위치: 대상 · outcome 키 · 완전성의 빠진 outcome 은 `workflows.<절차>.steps[<번호>].next[<outcome 의 JSON 문자열>]`, 배선 섞임은 `next`
    가 없는 첫 단계, 도달 · 끝은 걸린 단계 가운데 목록에서 첫 단계의 위치
- 건드릴 파일: `src/harness/workflow/graph.py` · `placeholders.py`(신규) · `validate.py`, `src/test/render-test.sh`,
  `src/test/unit/test_workflow_graph.py` · `test_workflow_placeholders.py`(신규)

### 완료 조건

- [ ] 이 task 가 맡은 6절의 행마다 그 조건 하나만 어긴 설정이 2 와 6절의 위치로 거부된다 — 배선 칸은 `next["<outcome>"]`(`.` 이 든 outcome 이름 포함), 배선 섞임 · 도달 · 끝은 단계 위치
- [ ] 한 단계의 `next` 가 빈 표인 절차가 명시 배선으로 판정되어 완전성(script 가 아닌 블록) · 끝(script) 검사로 거부되고, 암묵 배선으로 읽히지 않는다
- [ ] 명시 배선 · 암묵 배선 · 하위 절차 · 빈 하위 절차 · 프로젝트 스키마를 쓰는 최소 driver 절차가 render 된다
- [ ] 하위 절차의 `set` 변수를 바깥 절차에서 쓰면 render 가 거부하고, 바깥 절차의 `set` 변수를 하위 절차에서 쓰는 것은 통과한다
- [ ] agent 절차의 `{steps.…}` 를 render 가 거부하고, agent 절차 문서에 `{issue}` 같은 나머지 중괄호가 글자 그대로 들어간다
- [ ] 기본 절차 생성물이 바뀌지 않는다(T1 의 생성물 케이스)
- [ ] `python3 script/project/check-cli.py imports` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 배선 판정 | `next` 없음 / 한 단계에 `next` / 한 단계에 `next = {}` | 암묵 · 명시 · 명시 |
| UT-02 | 암묵 배선 펼치기 | script · agent · prompt · gate · workflow 차례의 절차 | 2-4 표와 같은 실효 배선, 마지막 단계의 다음은 `done` |
| UT-03 | outcome 집합 · 완전성 | `on` 열거값 `a` · `b` 인 agent 에 `next = {a = …}` / `"*"` 를 더함 / gate `options` | `b` · `failed` 빠짐 / 통과 / 집합이 `options` |
| UT-04 | 도달 · 끝 | 닿지 않는 단계, 끝에 닿지 않는 루프, 표에 없는 outcome 만 `stop` 으로 가는 script | 거부 · 거부 · 끝 판정에서 세지 않음 |
| UT-05 | 위치 표기 | outcome `a.b` · `x"y` · `*` | `next["a.b"]` · `next["x\"y"]` · `next["*"]` |
| UT-06 | 이름 파싱 | `{issue}` · `{{issue}}` · `{a: .b}` · `{}` · `x{mr}y` · `{steps.s.out.k}` | 이름 · 글자 · 글자 · 글자 · 이름 `mr` · 이름 |
| UT-07 | 값 형식 | `"a b"` · `""` · `12` · `[1,"가"]` · `{"k":1}` · `true` · `1.5` | `a b` · 빈 문자열 · `12` · `[1,"가"]` · `{"k":1}` · 형 오류 · 형 오류 |
| UT-08 | 값 없음 · 바깥 조회 | 없는 키 · null · 바깥 실행에만 있는 변수 | `has no value` · `has no value` · 바깥 값 |
| UT-09 | render 의 자리표시 · `set` | 어디서도 `set` 하지 않는 변수, 없는 단계의 출력, `on = "stdout"` script 의 출력, 스키마 밖 키, `type = "boolean"` 키, `set` 의 `Mr` | 각각 2 |
| UT-10 | 받아들임 | 명시 · 암묵 · 하위 절차 · 빈 하위 절차 · 프로젝트 스키마 `on` 을 쓰는 driver 절차 | render 0 |

## T4 · feat: agent 절차의 workflow 블록 문서와 커맨드를 하위 절차가 아닌 agent 절차로 한정

### 상위 Requirement

- relates to #208

### 작업 내용

agent 절차 문서에 workflow 블록과 빈 절차를 그리고, 슬래시 커맨드를 하위 절차가 아닌 agent 절차에만 만든다. agent 하위 절차와
빈 절차를 `harness run` 이 거부한다. 기본 절차의 생성물은 바이트 단위로 같다.

- 명세 9-1 · 10절, 7-1 의 "agent 하위 절차" · "단계가 없는 절차" 행
- 절차 문서(`render/workflows.py`)
  - workflow 블록의 제목 줄은 `` ### <n>. <제목> — 하위 절차 `<이름>` `` 이다. 본문은 하위 절차에 단계가 있으면
    "`` `.ai/workflows/<이름>.md` `` 의 절차를 이 자리에서 그 문서대로 수행한다. 그 절차가 끝나면 다음 단계로 간다.", 없으면
    "`` `workflows.<이름>` `` 은 단계가 없는 확장 지점이다. 할 일이 없으니 다음 단계로 간다." 이고 그 뒤에 `text` 가 온다.
    시작 표지 줄은 다른 단계와 같다
  - 단계가 없는 절차의 문서는 머리, "이 절차에는 단계가 없다. 다른 절차가 하위 절차로 부르는 확장 지점이고, 불리면 곧바로 끝난다.",
    꼬리 조각, `## 이 프로젝트에서` 다
- 커맨드
  - 프로젝트 절차의 `.claude/commands/<절차>.md`(`plan()`)와 자산 표 행(`command_rows()`)은 agent 절차이면서 하위 절차가 아닌
    절차에만 만든다
  - 기본 절차의 관리 커맨드(`.claude/commands/prework.md` · `work.md`)는 그 절차가 driver 이거나 하위 절차면 설치하지 않고 자산 표
    행도 뺀다. 쓰지 않는 역할의 커맨드를 빼는 판정(`role_file_skip()`)과 같은 자리에서 가른다. 지난 설치가 깐 것은 지금의
    정리(`prune`)가 지운다
- `harness run`(`commands/run.py`): agent 하위 절차는 `` error: `<절차>` runs only as a sub-workflow of <부르는 절차, 쉼표로> ``,
  단계가 없는 절차는 `` error: `<절차>` has no steps — it is an extension point other workflows call `` 로 종료 코드 2 다.
  오케스트레이터를 띄우지 않고 worktree 를 만들지 않는다. 판정 자리는 7-1 표의 순서를 지킨다 — T10 이 나머지 행을 그 순서대로 끼운다
- `render-test.sh` 에 "커맨드" 블록을 열고, "agent 절차 불변" 블록에 workflow 블록 케이스를 더한다
- 건드릴 파일: `src/harness/render/workflows.py` · `render/plan.py` · `render/agents.py`, `src/harness/commands/run.py`,
  `src/test/render-test.sh`

### 완료 조건

- [ ] 소스 트리 복제에서 render 한 뒤 `.ai/workflows/*.md` · `.claude/commands/*.md` 가 바뀌지 않고 `harness check` 가 통과한다
- [ ] 하위 절차를 부르는 agent 절차의 문서에 9-1 의 제목 줄과 본문이 있고, 빈 하위 절차를 부르는 단계에는 확장 지점 본문이 있다
- [ ] 단계가 없는 절차의 문서가 9-1 의 문장과 꼬리 조각을 담는다
- [ ] 프로젝트 driver 절차에 `.claude/commands/<절차>.md` 와 자산 표 행이 없다
- [ ] 기본 `work` 를 driver 로 두고 render 하면 `.claude/commands/work.md` 가 없어지고 자산 표 행이 빠진다. agent 로 되돌리면 다시 생긴다
- [ ] 하위 절차인 프로젝트 agent 절차에 커맨드가 없고 `harness run` 이 2 로 거부한다. 단계가 없는 절차의 `harness run` 도 2 이고 오케스트레이터 스텁이 불리지 않는다
- [ ] `python3 script/project/check-cli.py imports` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | workflow 블록 문서 | agent 절차 `main` 이 단계 있는 `sub` 와 빈 `ext` 를 부름 | 9-1 의 제목 줄 · 본문 둘 · 시작 표지 줄 |
| UT-02 | 빈 절차 문서 | `ext` 의 문서 | 9-1 의 문장 · 꼬리 조각 · 프로젝트 지시 절 |
| UT-03 | 프로젝트 driver 절차 | driver 절차 하나 | 커맨드 파일 · 자산 표 행 없음 |
| UT-04 | 관리 커맨드 | 기본 `work` 를 driver 로 render → agent 로 render | `work.md` · 행 없어짐 → 다시 생김 |
| UT-05 | agent 하위 절차 | `sub` 의 커맨드, `harness run sub 1` | 커맨드 없음, 2 와 7-1 문구 |
| UT-06 | 빈 절차 실행 | `harness run ext 1` | 2 와 7-1 문구, 스텁 호출 기록 없음 |

## T5 · feat: driver 절차 문서에 Mermaid 그래프와 단계별 다음 표 생성

### 상위 Requirement

- relates to #208

### 작업 내용

driver 절차 문서를 사람이 읽는 설명으로 만든다 — 실행 안내, Mermaid 그래프, 끝 상태 범례, 단계마다 블록 설명과 다음 표.
에이전트가 따라 수행하는 문서가 아니다.

- 명세 9-2
- `render/workflows.py`
  - 머리: 기본 절차는 `_head` 조각, 프로젝트 절차는 9-2 의 머리(입력은 이슈 번호 또는 Jira 키)
  - 첫 단계 앞: 실행 안내 인용 두 줄, `mermaid` 코드 블록, 끝 상태 범례
  - 그래프: 단계마다 `s<번호>["<번호>. <제목>"]`, 쓰인 끝 상태마다 `end_<이름>(["<이름>"])`, 제목의 `"` 는 `#quot;`. 간선은 단계
    순서대로, 단계 안에서는 배선 표의 순서대로, 라벨은 outcome(`*` 포함)을 큰따옴표로 감싼다. 배선은 T3 의 실효 배선을 쓴다 —
    암묵 배선 절차는 2-4 를 그린다
  - 단계: `### <n>. <제목 줄>`, 블록 설명(9-2 표 — agent 의 스키마 자리는 동봉이면 `동봉`, 프로젝트면
    `` `.ai/project/schemas/<이름>.json` ``, `on` 이 없으면 outcome 문장을 뺀다), `set` 이 있으면 변수마다
    `` 올리는 변수: `{<변수>}` ← 출력 `<키>` ``, 조각(있으면), `text`, 다음 표(outcome → `<번호>. <제목>` 또는 끝 상태)
  - 단계 시작 표지 줄을 넣지 않는다. 꼬리 조각과 `## 이 프로젝트에서` 는 agent 절차와 같고, 조각의 `{{step:<id>}}` 는 번호로 풀린다
- `render-test.sh` 에 "driver 문서" 블록을 연다
- 건드릴 파일: `src/harness/render/workflows.py`, `src/test/render-test.sh`, `src/test/unit/test_render_workflows.py`(신규)

### 완료 조건

- [ ] driver 절차 문서에 실행 안내 · Mermaid 블록 · 끝 상태 범례 · 단계마다 다음 표가 있고 시작 표지 줄이 없다
- [ ] `next` 없는 driver 절차의 다음 표와 간선이 2-4 의 암묵 배선과 같다
- [ ] 블록 다섯의 제목 줄과 블록 설명이 9-2 표와 같다 — 스키마 자리 두 가지, `on` 없는 agent, `on = "stdout"` script, `set` 줄 포함
- [ ] 기본 절차 생성물이 바뀌지 않는다(T1 의 생성물 케이스)
- [ ] `python3 script/project/check-cli.py imports` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 노드와 따옴표 | 제목 `a "b"` 인 1번 단계 | `s1["1. a #quot;b#quot;"]` |
| UT-02 | 끝 상태 노드 | `done` 만 쓰는 절차 | `end_done` 만 있다 |
| UT-03 | 간선 순서 · 라벨 | 명세 9-2 예의 두 단계(리뷰 · 수정) | 예와 같은 `flowchart TD` 블록 |
| UT-04 | 다음 표 | `0` → `done`, `1` → 2번 단계, `*` → `stop` | 9-2 의 표와 같은 줄 |
| UT-05 | 암묵 배선 문서 | script · gate · workflow 의 암묵 절차 | 라벨 `"0"` · `"*"` · 첫 선택지 · `done` · `stop` · `handoff` 와 같은 다음 표 |
| UT-06 | 블록 설명 | 블록 다섯, 동봉 · 프로젝트 스키마, `set` 둘 | 9-2 표의 문장과 `올리는 변수` 두 줄 |

## T6 · feat: harness steps 가 단계 키와 절차 키를 전부 보존

### 상위 Requirement

- relates to #208

### 작업 내용

`harness steps` 쓰기가 단계와 절차의 키를 하나도 잃지 않게 한다. 지금은 `id` · `type` · `title` · `role` · `run` · `text` 와 절 머리의
`title` 만 다시 써서 배선과 실행 방식이 지워진다.

- 명세 11-1
- `steps_block()`(`config/edit.py`)
  - 단계마다 받은 키를 전부 쓴다. 순서는 `id` · `type` · `title` · `role` · `run` · `workflow` · `schema` · `on` · `access` · `options` ·
    `text` · `next` · `set`, 그 밖의 키는 이름 순이다. 값이 빈 문자열인 키는 쓰지 않고, 빈 표 · 빈 배열인 키는 쓴다(`next = {}`)
  - 값 표기: 문자열은 JSON 인용, 정수 · 실수 · 불리언은 TOML 표기, 배열은 `[…]`, 표는 키를 JSON 인용한 인라인 표
    (`{ "0" = "done", "*" = "stop" }`). 값이 null 이면 `error: steps[<번호>].<키> is null` 로 거부한다
- 절차 키(`title` · `execute` · `max_steps` · `max_visits`, `commands/steps.py`): JSON 이 배열이면 지금 설정의 절차 키를 그대로 두고,
  객체면 그 안의 절차 키가 값을 정하며 없는 절차 키는 지금 값을 둔다. `title` 이 빈 문자열이면 지운다. 절의 줄 순서는
  `[workflows.<절차>]` · `title` · `execute` · `max_steps` · `max_visits` · `steps` 다
- `--dry-run` 도 같은 규칙으로 만든 정의를 검사하고 설정을 바꾸지 않는다
- 다른 절차가 workflow 블록으로 가리키는 절차의 `--rename` · `--delete` 는 6절 하위 절차 검증에 걸려 지금의 되돌리기로 되돌린다
- `render-test.sh` 에 "`harness steps` 보존" 블록을 연다
- 건드릴 파일: `src/harness/config/edit.py`, `src/harness/commands/steps.py`, `src/test/render-test.sh`,
  `src/test/unit/test_steps_block.py`(신규)

### 완료 조건

- [ ] 모든 단계 키(`next` · `set` · `options` · 모르는 키 포함)와 절차 키를 담은 JSON 으로 저장한 뒤 `harness steps` 로 읽은 그 절차가 받은 JSON 과 같다
- [ ] 배열로 저장해도 `execute` · `max_steps` 가 남는다
- [ ] `next = {}` 인 단계를 담은 JSON 으로 저장한 뒤 다시 읽으면 `next` 가 빈 표로 남는다
- [ ] `--dry-run` 이 새 키가 든 정의를 검사하고 `harness.toml` 을 바꾸지 않는다
- [ ] 값이 null 인 키는 `error: steps[<번호>].<키> is null` 로 거부되고 설정이 그대로다
- [ ] 다른 절차가 가리키는 절차의 `--rename` · `--delete` 가 거부되고 설정이 그대로다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 키 순서 | 13 키 전부와 모르는 키 `zeta` · `alpha` | 정해진 순서 뒤 `alpha` · `zeta` |
| UT-02 | 값 표기 | 문자열 · 정수 · 실수 · 불리언 · 배열 · 표 · 빈 표 · 빈 문자열 | JSON 인용 · `3` · `1.5` · `true` · `[…]` · `{ "0" = "done" }` · `{}` · 키 없음 |
| UT-03 | null | `{"next": null}` 인 단계 | `error: steps[0].next is null` |
| UT-04 | 왕복 | 모든 단계 키 · 절차 키를 담은 객체 JSON 저장 뒤 읽기 | 받은 JSON 과 같음 |
| UT-05 | 배열 입력 | `execute = "driver"` · `max_steps = 50` 인 절차에 배열 저장 | 두 키가 남음 |
| UT-06 | 빈 표 | `next = {}` 인 단계 저장 뒤 읽기 | `next` 가 빈 표 |
| UT-07 | `--dry-run` | 새 키가 든 정의 | 검사 결과, `harness.toml` 바이트가 같음 |
| UT-08 | 가리켜진 절차 | 다른 절차가 부르는 절차의 `--rename` · `--delete` | 각각 2, `reverted` |

## T7 · feat: 벤더 선언의 agent·driver_write·structured 와 실행 계획의 driver·prompt 자리

### 상위 Requirement

- relates to #208

### 작업 내용

벤더 선언에 키 셋을 더하고, 실행 계획에 driver 실행용 두 자리를 더한다. 렌더되는 역할 argv 는 바뀌지 않는다.

- 명세 7-4 의 벤더 선언 표 · 실행 계획 두 자리 · `driver_write` 범위 · `--bare`, 12절의 `vendors.toml` 머리 주석 행
- `src/templates/vendors.toml`
  - claude: `headless = ["claude", "-p", "{agent}", "--no-session-persistence", "{access}", "{model}"]`, `agent = ["--agent", "{role}"]`
  - `driver_write` · `structured`: claude · codex 각각 그 CLI 로 직접 확인한 인자만 적고, 확인한 CLI 버전과 관측을 그 줄 주석에 적는다
    (`auth_check` 주석과 같은 방식). 확인할 것은 명세 7-4 의 셋이다
    - `claude -p` 에서 승인이 필요한 도구 호출이 거부로 끝나는지와, 7-4 범위 표의 조작을 허용하는 인자
    - `codex exec --sandbox workspace-write` 가 네트워크(push · forge CLI)를 막는지와, 허용하는 인자
    - `claude --json-schema` · `codex exec --output-schema` 를 붙였을 때 결과 본문이 5-3 을 만족하는 자리에 오는지 — claude 는
      `--output-format json` 결과 객체의 어느 필드인지
  - 확인하지 못한 키는 적지 않는다 — 실행 계획이 7-4 의 대체 규칙(`access.write`, 빈 `structured`)으로 돈다
  - 헤드리스 `claude -p` 가 `.claude/settings.json` 의 PreToolUse 훅을 거는지 확인하고 결과를 리뷰 요청 본문에 적는다
  - 머리 주석에 `agent`(`headless` 의 `{agent}` 자리, `{role}` 을 쓴다, 없으면 빈 목록) · `driver_write`(driver 실행의 쓰기 권한 인자,
    없으면 `access.write`) · `structured`(출력 스키마 보조 인자, `{schema_file}` · `{schema_json}`)를 더한다
- `config/agents.py`
  - `headless_argv()` 가 `{agent}` 자리를 그 벤더의 `agent` 표(`{role}` 을 푼 것)로 채운다. 역할이 없는 실행에서는 빈 목록이다
  - `run_plan()`(#207)에 `roles.<역할>.driver` — 켜진 역할이고 `entry` 가 없으며 실제 벤더(`inproc` 이면 실효 오케스트레이터)에 `headless` 가
    있을 때. 키는 `vendor` · `exe` · `argv` · `output` · `usage_format` · `usage_parser` · `structured`. `argv` 의 `{access}` 는 역할이
    `write` 면 `driver_write`(없으면 `access.write`), `read-only` 면 `access.read-only`, `{model}` 은 역할 모델 규칙(#207 7-7)이다
  - 최상위 `prompt` — 늘 있는 객체다. 권한 키(`"read-only"` · `"write"`)는 실효 오케스트레이터 벤더에 `headless` 가 있을 때 있고, 값은
    `vendor` · `exe` · `argv` · `output` · `usage_format` · `usage_parser` 다. `{agent}` 는 빈 목록, `{access}` 는 위와 같은 규칙을 그 권한에,
    `{model}` 은 실효 `harness.model` 이다
  - 기존 필드는 그대로다. 두 자리는 다른 필드처럼 실효 설정(개인 레이어 포함)으로 계산한다
- `render-test.sh` 에 "실행 계획" 블록을 연다
- 건드릴 파일: `src/templates/vendors.toml`, `src/harness/config/agents.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] `harness run-plan` 출력에서 `entry` 없는 켜진 역할마다 `driver` 가, 최상위 `prompt` 에 두 권한이 있고 7-4 의 키를 갖는다. `code-reviewer` 에는 `driver` 가 없다
- [ ] 개인 레이어의 러너 · 오케스트레이터가 `driver.vendor` · `prompt.<권한>.vendor` 에 반영된다
- [ ] claude 러너 역할의 `roles.<역할>.argv` 가 이 변경 전과 같다
- [ ] `driver_write` 가 없는 벤더에서 쓰기 역할의 `driver.argv` 에 `access.write` 인자가, 읽기 역할에 `access.read-only` 인자가 든다
- [ ] 선언한 `driver_write` · `structured` 마다 확인한 CLI 버전 주석이 있다
- [ ] 벤더 선언의 어느 argv(`launch` · `headless` · `agent` · `access` · `driver_write` · `structured`)에도 `--bare` 가 없다
- [ ] 기본 절차 생성물이 바뀌지 않는다(T1 의 생성물 케이스). `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | `driver` 자리 | 기본 설정의 `harness run-plan` | `entry` 없는 켜진 역할마다 일곱 키, `code-reviewer` 에 없음 |
| UT-02 | `prompt` 자리 | 기본 설정 | `read-only` · `write` 마다 여섯 키 |
| UT-03 | inproc 역할 | `developer`(러너 `inproc`), 오케스트레이터 claude | `driver.vendor = "claude"`, `argv` 에 `--agent developer` |
| UT-04 | 개인 레이어 | `harness.local.toml` 로 오케스트레이터를 codex 로 | inproc 역할의 `driver.vendor` · `prompt.<권한>.vendor` 가 codex |
| UT-05 | 권한 인자 대체 | `driver_write` 를 지운 벤더 선언 사본 | 쓰기 역할 → `access.write`, 읽기 역할 → `access.read-only` |
| UT-06 | 역할 argv 불변 | claude 러너 역할 | 이 변경 전과 같은 `argv` |
| UT-07 | `headless` 없는 오케스트레이터 | 오케스트레이터 벤더의 `headless` 를 지운 선언 사본 | `prompt` 가 빈 객체, inproc 역할의 `driver` 없음 |
| UT-08 | `--bare` | `src/templates/vendors.toml` 의 모든 argv | `--bare` 없음 |

## T8 · feat: 역할 실행기에 --driver·--driver-prompt·--schema 추가

### 상위 Requirement

- relates to #208

### 작업 내용

공용 역할 실행기가 실행 계획의 driver 실행용 항목으로 역할이나 오케스트레이터를 띄우게 한다. 기존 호출은 그대로다.

- 명세 7-4 의 역할 실행기 인자 표, 12절의 `script/README.md` 행
- `src/templates/managed/script/run-agent.py`
  - `<역할> --driver [--schema <파일>] --prompt <지시> --out <파일>` — 실행 계획의 `roles.<역할>.driver` 로 띄운다. 러너가 `inproc` 인
    역할도 실행한다. 그 항목이 없으면 2
  - `--driver-prompt <read-only|write> --prompt <지시> --out <파일>` — 역할 없이 `prompt.<권한>` 으로 띄운다. 권한 값이 둘이 아니거나 그
    항목이 없으면 2
  - `--schema <파일>` — 항목의 `structured` 가 비어 있지 않으면 `{schema_file}` = 그 파일 경로, `{schema_json}` = 그 내용으로 푼 인자를
    붙이고, 비어 있으면 무시한다. 붙이는 자리는 항목의 `argv` 와 결과 · 사용량 인자 뒤, 지시 앞이다
  - 결과 받기(`output` · `--out`) · 사용량 파서 · 스팬은 기존 실행과 같다. 실행 계획은 #207 이 정한 방법으로 받는다
  - `--driver-prompt` 실행의 스팬은 이름 `prompt` 로, `role` 속성 없이 남긴다
  - 기존 호출(`<역할> [--out <파일>] [--prompt <지시>] [<입력> ...]` · `--check`)은 그대로다. 서브에이전트 역할을 `--driver` 없이
    부르면 지금처럼 2 다
  - 머리 docstring 의 사용법과 인자 설명에 세 인자를 더한다
- `src/templates/managed/script/README.md` 의 `run-agent.py` 행에 세 인자를 적는다
- `src/bin/harness render` 로 이 리포의 `script/run-agent.py` · `script/README.md` 사본과 `.harness/managed` 를 갱신한다
- `render-test.sh` 에 "역할 실행기" 블록을 연다
- 건드릴 파일: `src/templates/managed/script/run-agent.py` · `README.md`, render 로 갱신되는 `script/run-agent.py` · `script/README.md` ·
  `.harness/managed`, `src/test/render-test.sh`

### 완료 조건

- [ ] `--driver` 가 서브에이전트 역할을 `roles.<역할>.driver.argv` 로 띄운다(스텁에 기록된 argv)
- [ ] `--schema` 는 `structured` 가 비지 않은 항목에만 인자를 붙이고, 빈 항목에서는 무시된다
- [ ] 항목이 없는 역할(`entry` 역할)의 `--driver` 가 2 다
- [ ] `--driver-prompt read-only` · `write` 가 역할 인자 없이 `prompt.<권한>.argv` 로 띄우고, 그 밖의 권한 값은 2 다
- [ ] `--driver` 없이 서브에이전트 역할을 부르면 지금처럼 2 이고, 기존 역할 실행기 케이스가 기대값 그대로 통과한다
- [ ] `script/run-agent.py` 사본이 정본과 같고 `harness check` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | `--driver` | `developer --driver --prompt p --out f` | 스텁 argv = `driver.argv` + 사용량 인자 + `p`, `f` 에 결과 본문 |
| UT-02 | `--schema` 붙임 | `structured` 를 선언한 벤더 선언 사본, `--schema s.json` | 푼 `structured` 인자가 지시 앞 |
| UT-03 | `--schema` 무시 | `structured` 없는 벤더 | 붙은 인자 없음 |
| UT-04 | entry 역할 | `code-reviewer --driver` | 2 |
| UT-05 | `--driver-prompt` | `read-only` · `write` · `admin` | 각 권한의 argv · 역할 인자 없음 / 2 |
| UT-06 | 기존 호출 | `developer`(inproc) 를 `--driver` 없이 | 2 |

## T9 · feat: driver 실행 상태 파일과 doctor 의 runs 절

### 상위 Requirement

- relates to #208

### 작업 내용

끝나지 않은 driver 실행의 상태를 기기 로컬 파일로 다루는 모듈을 두고, doctor 가 그 파일을 보고한다. 드라이버는 T10 부터 이 모듈을
쓴다. 이 task 는 상태 파일을 직접 만들어 시험한다.

- 명세 8-1 · 8-2 · 8-3 의 형식 검증 · 잠금 · 지우기, 8-4 의 정의 digest, 8-5
- `src/harness/workflow/state.py`
  - 자리: `<등록부>/<클론 키>/runs/<절차>-<이슈>.json` 과 `.lock`. 등록부는 `HARNESS_HOME` 이 있으면 그것, 없으면 `~/.harness`, 클론
    키는 `home/clone_key.py` 의 값이다. 디렉터리 0700 · 파일 0600, 같은 디렉터리의 임시 파일에 쓰고 rename 으로 바꾼다
  - 파일 이름 가르기: 끝에서 Jira 키(`^[A-Z][A-Z0-9_]*-[0-9]+$`), 그다음 숫자 순으로 이슈를 맞추고 앞부분이 절차 이름 형식
    (`[a-z][a-z0-9-]{1,30}`)인지 본다
  - 형식(8-2): 최상위 필드는 `preset` 을 뺀 전부 필수이고 `preset` 은 없거나 null 이거나 문자열이다. 프레임은 `workflow` · `at` ·
    `vars` · `outputs` 를 갖고 안쪽 프레임만 `status`(`ready` · `running` · `waiting`)를 갖는다. JSON 이 아니다 · `format` 이 다르다 ·
    필드가 형식과 다르다 · 표에 없는 필드가 있다 · `workflow` · `issue` 가 파일 이름과 다르다 · 프레임의 절차나 단계가 지금 정의에 없다 —
    이면 읽지 못한 상태다
  - 잠금: 잠금 파일에 비차단 `flock`. 잡지 못한 것을 부른 쪽에 알린다 — 문장(8-3)과 종료 코드는 `harness run` 이 낸다
  - 정의 digest: 시작한 절차와 거기서 닿는 하위 절차의 정의(정규화한 절차 표 전부)와 그 절차들이 가리키는 스키마 내용을 키 정렬
    JSON 으로 직렬화한 SHA-256(`sha256:<16진>`). 러너 · 모델과 조각 본문은 들지 않는다
- doctor `runs` 절(`readiness/items.py`): 이 클론의 `runs/` 에서 이름이 `<절차>-<이슈>.json` 형식인 파일마다 `warn` 한 줄 — 읽히면
  `unfinished run of <절차> for issue <이슈>` · `` at <절차>/<id> — resume with `harness run <절차> <이슈> --resume` or drop it with `--discard` ``
  (안쪽 프레임이 `waiting` 이면 `<id>` 뒤에 ` (gate)`), 읽히지 않으면 `unreadable run state of <절차> for issue <이슈>` ·
  `` drop it with `harness run <절차> <이슈> --discard` ``. 없으면 `ok` 한 줄 `no unfinished runs`. 상태의 출력 · 변수와 파일 경로는
  옮기지 않는다
- UI `src/ui/lib/doctor.js`: `SECTIONS.runs` 는 `"실행"` 이다. `explain()` 이 두 `warn` 줄을 "멈춘 driver 실행이 있다 — 이어 돌거나
  지운다", "읽지 못하는 실행 상태가 있다 — 지운다" 는 뜻으로 옮기고 조치 명령으로 `harness run <절차> <이슈> --resume` · `--discard` 를 준다
- `render-test.sh` 에 "driver 실행" 블록을 열고 doctor 케이스를 둔다
- 건드릴 파일: `src/harness/workflow/state.py`(신규), `src/harness/readiness/items.py`, `src/ui/lib/doctor.js` · `doctor.test.js`,
  `src/test/render-test.sh`, `src/test/unit/test_workflow_state.py`(신규)

### 완료 조건

- [ ] 직접 만든 상태 파일이 있는 클론에서 doctor 의 `runs` 절이 읽히는 파일과 읽히지 않는 파일마다 `warn` 한 줄을 내고, 없으면 `no unfinished runs` 다 — Jira 키 이름의 상태 파일 포함
- [ ] 표에 없는 필드가 든 상태는 읽히지 않고, `preset` 이 없거나 null 인 상태는 읽힌다
- [ ] doctor 출력에 상태의 출력 · 변수 값과 파일 경로가 없다
- [ ] `doctor.test.js` 의 `SECTIONS.runs` 와 두 `warn` 줄 케이스가 통과한다
- [ ] `python3 script/project/check-cli.py imports` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 직렬화 · 검증 | 정상 상태, 표에 없는 최상위 필드 · 프레임 필드, `preset` 없음 · null · 문자열 · 정수 | 읽힘 · 거부 · 거부 · 읽힘 · 읽힘 · 읽힘 · 거부 |
| UT-02 | 이름 · 정의 대조 | 파일 이름과 다른 `workflow` · `issue`, 지금 정의에 없는 단계의 프레임 | 각각 거부 |
| UT-03 | 원자적 쓰기 | 상태를 쓴 뒤의 디렉터리 | 임시 파일 없음, 파일 0600 · 디렉터리 0700 |
| UT-04 | digest | 키 순서만 다른 정의 / 단계 하나가 바뀐 정의 / 러너 · 모델만 다른 설정 / 가리키는 스키마 내용이 바뀜 | 같음 · 다름 · 같음 · 다름 |
| UT-05 | 파일 이름 가르기 | `work-12.json` · `work-PROJ-7.json` · `review-loop-3.json` · `Work-1.json` | `(work, 12)` · `(work, PROJ-7)` · `(review-loop, 3)` · 형식 밖 |
| UT-06 | 잠금 | 다른 프로세스가 쥔 잠금 | 잡지 못함 |
| UT-07 | doctor | 읽히는 상태 · 게이트 대기 상태 · 깨진 상태 · Jira 키 상태 / 상태 없음 | 8-5 의 `warn` 줄 넷 / `no unfinished runs` |
| UT-08 | UI 문구 | `doctor.test.js` | `SECTIONS.runs` 가 `"실행"`, 두 `warn` 줄이 원문과 다른 제목 · 본문과 조치 명령 |

## T10 · feat: driver 절차의 harness run — 인자·잠금·상태·script 블록·끝 상태

### 상위 Requirement

- relates to #208

### 작업 내용

driver 절차의 `harness run` 이 그래프를 하네스 안에서 돈다. 이 task 는 실행 골격 — 인자, 시작 전 확인, 잠금, 실행 상태의 생애,
script 블록, 배선 따라가기, 상한, 끝 상태 — 를 넣는다. workflow · gate · agent · prompt 블록과 worktree · 지표는 뒤 task 가 더한다.

- 명세 2-3 의 실행 때 배선, 3-1, 4-1 의 `set`, 4-2 의 순서, 4-3, 7-1, 7-2 의 1 · 3 · 4, 7-3(worktree · 재개 줄 제외), 7-6, 7-7 의
  `done` · `stop` · 실행하지 못함 · `handoff` 행, 8-2 의 쓰는 때(만들 때 · `running` · `ready`), 8-3
- `commands/run.py`: 실효 설정(#207)에서 절차의 실행 방식을 보고, agent 절차는 지금 경로로, driver 절차는 `workflow/driver.py` 로 보낸다
- 인자(7-1)
  - 공용 파서에 `--resume` · `--discard` 를 더한다(`--worktree` · `--dry-run` 과 같은 방식). `COMMANDS` 의 `run` 사용법은
    `<workflow> <issue> [--worktree] [--resume] [--discard]` 다
  - 7-1 의 거부 표를 위에서부터 그 순서로 판정한다 — driver 이슈 형식, `--worktree` 의 숫자 이슈, agent 절차의 `--resume` · `--discard`,
    agent 하위 절차(T4), 부르는 절차가 올리는 변수를 쓰는 driver 절차, 단계가 없는 절차(T4), `--discard` 와 다른 플래그
  - 자기 `set` 에 없는 변수의 판정은 시작한 절차의 단계만 본다. `{issue}` 와 `{steps.…}` 는 변수가 아니다. 여럿이면 단계 순서로 첫
    변수를 적는다
- 시작 전 확인(7-2): 실효 설정을 읽고 #207 의 실행 시점 불변식 검사를 거친다, `script/run-agent.py` 가 없으면 `error: script/run-agent.py is missing`
  과 `help: harness render`, `.ai/workflows/<절차>.md` 가 있다. 걸리면 상태를 만들거나 바꾸지 않고 2
- 실행 순서(7-3): 인자 → 잠금(`--dry-run` 은 잡지 않는다) → 상태 판정 → 설정 · 스키마 읽기와 시작 전 확인 → 상태 만들기와 첫 줄
  `driver: <절차> <이슈> — <단계 수> step(s) from <절차>/<첫 단계>` → 블록마다 `step <n>: <절차>/<id> (<블록>)` 과
  `  -> <outcome> -> <대상>`(outcome 이 없으면 `-`) → 마지막 줄과 종료 코드 → 잠금 풀기
- 잠금과 상태(8-3): 잠금을 잡지 못하면 `error: another run of <절차> for issue <이슈> is in progress on this clone` 로 2. 새 실행인데
  상태가 있으면 `` error: an unfinished run of <절차> for issue <이슈> exists (at <절차>/<id>) `` 와 `help:` · `--resume` · `--discard` 두
  명령, 읽지 못하면 `error: the run state of <절차> for issue <이슈> cannot be read` 와 `--discard` 안내로 2
- script 블록(3-1)
  - `run` 을 `shlex.split` 으로 나눈 뒤 원소마다 render 치환(`{{VAR}}`)을 하고 그 뒤에 자리표시를 푼다(T3). 푼 값은 다시 치환하지 않는다
  - 셸 없이 실행한다. 실행 디렉터리는 하네스 루트, 표준 입력은 비어 있고 표준 오류는 그대로 흐르며, 표준 출력은 모았다가 블록이
    끝나면 드라이버의 표준 출력에 그대로 낸다. 환경에 `HARNESS_WORKFLOW` · `HARNESS_STEP` 을 더한다
  - outcome: 종료 코드의 10진 문자열(시그널로 끝나면 `128 + 번호`). `on = "stdout"` 이면 종료 코드 0 일 때 표준 출력을 공백으로 나눈
    첫 토큰이고, 토큰이 outcome 이름 형식이 아니거나 출력이 비었거나 종료 코드가 0 이 아니면 outcome 이 없다(`"*"` 만 받는다)
  - 출력: `on = "exit"` 이고 표준 출력의 앞뒤 공백을 뺀 전체가 JSON 객체면 그 객체
- 데이터: `set` 은 단계가 끝나면 출력의 최상위 키 값을 그 절차 실행의 변수에 둔다(출력이 없거나 키가 없거나 값이 null 이면 그 변수를
  지운다). 같은 단계가 다시 돌면 새 출력이 이전 출력을 대신하고, 출력 없이 끝나면 이전 출력도 없어진다. 풀 수 없는 자리표시는 그 블록을
  시작하지 않고 실행 전체를 `stop` 으로 끝낸다(4-3 의 이유)
- 배선: outcome 이 표의 키에 있으면 그 값, 없고 `"*"` 가 있으면 그 값, 둘 다 없으면 `stop` — 이유 `outcome <outcome> is not wired`
- 상한(7-6): 블록을 시작하기 전에 세고, 닿았으면 그 블록을 시작하지 않고 `stop` — 이유 `max_steps <n> reached` · `max_visits <n> reached at <절차>/<id>`
- 끝(7-7): `done` 0 · `stop` 1(드라이버의 이유가 있으면 ` — <이유>`) · `handoff` 3. 끝 상태에 닿으면 상태 파일을 지운다
- 상태 쓰기(8-2): 새 실행을 만들 때, 블록을 시작할 때(`running`), outcome 을 따라 옮길 때(`ready`). `worktree` 는 `--worktree` 로
  시작했는가, `preset` 은 null
- `--discard`: 잠금을 잡고 상태 파일을 지운다 — 지웠으면 `discarded: run state of <절차> for issue <이슈>`, 없었으면
  `discard: no run state of <절차> for issue <이슈>`, 둘 다 0. 잠금을 잡지 못하면 2
- `--dry-run`: 상태 · 잠금을 만들거나 바꾸지 않고 첫 줄을 내고 0 이다(러너 줄은 T13, worktree 경로 줄은 T14)
- 건드릴 파일: `src/harness/workflow/driver.py`(신규), `src/harness/commands/run.py`, `src/harness/commands/__init__.py`,
  `src/harness/cli.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] script 셋을 암묵 배선으로 잇는 절차가 차례로 돌고 `done` · 0 이며 상태 파일이 없다
- [ ] 종료 코드마다 배선된 단계로 가고, 표에 없는 코드는 `"*"` 로, `"*"` 도 없으면 `stop` · 1 과 `outcome <outcome> is not wired` 다
- [ ] `on = "stdout"` 의 첫 토큰으로 가고, 종료 코드가 0 이 아니면 `"*"` 로 간다
- [ ] script 의 JSON 출력을 `set` 으로 올리고 다음 script 의 인자에 푼 값이 공백 · `;` 를 담아도 인자 하나로 들어간다. 배열 · 객체 값은 압축 JSON 인자 하나로 들어간다(받은 argv 기록)
- [ ] 없는 변수나 null 값을 쓰면 그 블록이 돌지 않고 `stop` · 1 · `has no value` 다. 빈 문자열 값은 빈 인자 하나로 들어가고 블록이 돈다
- [ ] Jira 키 이슈로 driver 절차가 돌고 상태 파일 이름이 `<절차>-<키>.json` 이다. 숫자도 Jira 키도 아닌 이슈는 2, Jira 키에 `--worktree` 를 주면 2 와 71 명세의 문구다
- [ ] 부르는 절차가 올리는 변수를 쓰는 driver 하위 절차를 직접 시작하면 2 이고 상태가 생기지 않는다. 자기 `set` 변수만 쓰는 driver 하위 절차는 직접 돈다
- [ ] 새 실행인데 상태가 있으면 2, `--discard` 가 0 으로 지우고 다시 해도 0 이다. 깨진 상태 파일이 있으면 새 실행이 2 다
- [ ] 다른 프로세스가 잠금을 쥐고 있으면 2 다
- [ ] 순환 배선에서 `max_visits` · `max_steps` 에 닿으면 `stop` · 1 과 이유다
- [ ] `handoff` 로 끝나면 3 이다
- [ ] 개인 레이어로 구현자와 리뷰어의 러너를 같게 두면 2 이고 상태가 생기지 않는다
- [ ] agent 절차의 `--resume` · `--discard` 가 2 이고, agent 절차의 `--dry-run` 명령줄이 이 변경 전과 같다
- [ ] `python3 script/project/check-cli.py imports` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 암묵 직선 | script 셋, `next` 없음 | `done: <절차> <이슈>`, 0, 상태 파일 없음 |
| UT-02 | 종료 코드 배선 | `next = {"0" = …, "1" = …}` 에 종료 코드 0 · 1 · 5, `"*"` 있음 · 없음 | 배선된 단계 · `"*"` 대상 · `stop` 1 과 이유 |
| UT-03 | 표준 출력 토큰 | `on = "stdout"` 에 `retry later` · 빈 출력 · 종료 코드 1 | `retry` 로 · `"*"` 로 · `"*"` 로 |
| UT-04 | 출력과 변수 | `{"v": "a b; c", "l": [1, "가"]}` 를 내는 script → `{v}` · `{l}` 을 쓰는 script | 받은 argv 의 원소 `a b; c` · `[1,"가"]` |
| UT-05 | 값 없음 | null 값 변수 / 빈 문자열 변수 | 블록 안 돎 · `stop` 1 · `has no value` / 빈 인자 하나로 돎 |
| UT-06 | 이슈 형식 | `PROJ-7` · `abc` · `PROJ-7 --worktree` | 상태 파일 `<절차>-PROJ-7.json` 으로 돎 · 2 · 2 와 71 명세 문구 |
| UT-07 | 하위 절차 직접 시작 | 부르는 절차의 `set` 변수를 쓰는 하위 절차 / 자기 `set` 변수만 쓰는 하위 절차 | 2 · 상태 없음 / 돎 |
| UT-08 | 상태가 있을 때 | 남은 상태로 새 실행, `--discard` 두 번 | 2 · `discarded:` 0 · `discard: no run state` 0 |
| UT-09 | 잠금 | 다른 프로세스가 `flock` 을 쥔 동안 실행 | 2 와 8-3 문장 |
| UT-10 | 상한 | 자기 자신으로 도는 배선, `max_visits = 3` / `max_steps = 4` | `stop` 1 · `max_visits 3 reached at <절차>/<id>` / `max_steps 4 reached` |
| UT-11 | handoff | `next = {"0" = "handoff"}` | 3 과 `handoff:` 줄 |
| UT-12 | 실행 시점 불변식 | 개인 레이어로 두 역할의 러너를 같게 | 2, 상태 없음 |
| UT-13 | agent 절차 | `--resume` · `--discard` · `--dry-run` | 2 · 2 · 이 변경 전과 같은 명령줄 |

## T11 · feat: driver 실행의 workflow 블록과 하위 절차 변수 조회

### 상위 Requirement

- relates to #208

### 작업 내용

driver 실행이 workflow 블록으로 하위 절차를 그 자리에서 돈다.

- 명세 2-5 · 3-5, 4-1 의 바깥 조회, 7-6 의 하위 절차 블록 세기, 7-7 의 `at` 과 깊이 규칙, 8-2 의 `frames`
- workflow 블록은 하위 절차를 그 첫 단계부터 새 프레임으로 돌고, 하위 절차의 끝 상태(`done` · `stop` · `handoff`)를 그 블록의 outcome
  으로 받는다. 단계가 없는 하위 절차는 블록을 하나도 돌리지 않고 곧바로 `done` 이다. workflow 블록의 출력은 없다
- 변수는 그 절차 실행에서 찾고 없으면 바깥 실행으로 차례로 찾는다(T3 의 풀기). 하위 절차 안에서 `set` 이 올린 변수와 단계 출력은 그
  실행 안에서만 보이고, 하위 절차가 끝나면 그 프레임과 함께 사라진다
- 상태의 `frames` 는 바깥에서 안쪽으로 절차 실행 하나에 하나다. 바깥 프레임의 `at` 은 실행 중인 workflow 블록이고, 안쪽 프레임만
  `status` 를 갖는다
- 드라이버가 내는 `stop`(배선 없음 · 값 없음 · 상한)은 깊이와 상관없이 실행 전체를 끝낸다. 하위 절차의 끝 상태는 실행의 끝이 아니다.
  마지막 줄의 `at <절차>/<id>` 는 끝 상태로 보낸 가장 안쪽 단계다
- `max_steps` 는 하위 절차의 블록과 workflow 블록을 모두 센다. `max_visits` 는 `<절차>/<id>` 마다 센다. 상한 값은 시작한 절차의 것이다
- 건드릴 파일: `src/harness/workflow/driver.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 하위 절차가 바깥 절차의 변수를 읽고, 하위 절차의 끝 상태가 바깥 workflow 블록의 outcome 이 된다 — `done` · `stop` · `handoff` 각각
- [ ] 단계가 없는 하위 절차가 블록 없이 곧바로 `done` 이다
- [ ] 하위 절차 안에서 드라이버가 낸 `stop` 이 실행 전체를 1 로 끝내고, 마지막 줄의 `at` 이 하위 절차의 단계다
- [ ] `max_steps` 가 하위 절차의 블록과 workflow 블록을 함께 센다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 바깥 변수 | 바깥이 `set` 한 `{mr}` 을 하위 절차 script 가 인자로 씀 | 받은 argv 에 그 값 |
| UT-02 | 끝 상태 전달 | 하위 절차가 `done` · `stop` · `handoff` 로 끝남, 바깥 `next` 가 셋을 다른 단계로 배선 | 각각 배선된 단계 |
| UT-03 | 빈 하위 절차 | 단계 없는 하위 절차를 부르는 workflow 블록 | 블록 시작 줄 없이 `-> done` |
| UT-04 | 깊은 곳의 드라이버 stop | 하위 절차 안의 배선 없는 outcome | 1, `stop: … at <하위 절차>/<id> — outcome … is not wired` |
| UT-05 | 상한 세기 | 하위 절차 블록 둘을 부르는 workflow 블록, `max_steps = 2` | 셋째 블록 전에 `max_steps 2 reached` |

## T12 · feat: driver 실행의 게이트 입력·멈춤·중단과 --resume

### 상위 Requirement

- relates to #208

### 작업 내용

gate 블록이 터미널에서 묻고, 멈추거나 중단된 실행을 `--resume` 으로 잇는다. 게이트를 지나간 것으로 보는 경로를 두지 않는다.

- 명세 3-4 · 7-5, 7-7 의 게이트 멈춤 · 중단 신호 행, 7-3 의 재개 첫 줄과 `--dry-run` 의 상태 표시, 8-2 의 `waiting`, 8-4
- gate: `gate <절차>/<id>: <제목>`, 자리표시를 푼 `text`, `options: 1) approve  2) reject` 꼴의 선택지, `> ` 를 표준 출력에 내고 표준 입력
  한 줄을 읽는다. 선택지 이름이나 1 부터 센 번호를 받고 앞뒤 공백은 무시한다
  - 표준 입력이 터미널이면 맞지 않는 답에 `not an option: <답>` 을 내고 다시 묻는다
  - 터미널이 아니면 맞지 않는 답이나 입력 끝(EOF)에서 상태의 안쪽 프레임을 `waiting` 으로 남기고
    `paused: <절차> <이슈> at gate <절차>/<id>` 와 `help:` · `harness run <절차> <이슈> --resume`, 종료 코드 4
- 중단 신호(SIGINT): 상태를 남기고 `interrupted: <절차> <이슈> at <절차>/<id>` 와 같은 `help:`, 종료 코드 130. 진행 중이던 블록의 상태는
  `running` 그대로다. 드라이버가 예외로 죽어도 상태는 마지막으로 쓴 그대로 남는다
- `--resume`
  - 상태가 있어야 한다. 없으면 2 다. 읽지 못하면 8-3 의 문장과 `--discard` 안내로 2
  - 정의 digest(T9)를 다시 계산해 다르면 `error: the definition of <절차> changed since this run was saved — it cannot resume` 과 `--discard`
    안내로 2
  - 시작 전 확인(7-2)을 다시 한다 — 개인 레이어가 바뀌었으면 바뀐 러너로 돌고, 불변식을 어기면 2
  - 첫 줄 `driver: resume <절차> <이슈> at <절차>/<단계>`. 안쪽 프레임의 `status` 가 `ready` 면 그 단계를 시작하고, `running` 이면 그 단계를
    처음부터 다시 돌고, `waiting` 이면 그 게이트를 다시 묻는다. `steps_run` · `visits` 는 이어 센다
- `--dry-run --resume`: 재개 첫 줄 뒤에 상태의 `status` 를 괄호로 붙인다. 상태를 바꾸지 않는다
- 건드릴 파일: `src/harness/workflow/driver.py`, `src/harness/commands/run.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 이름 답과 번호 답이 그 선택지로 가고, 터미널이 아닌 잘못된 답은 4 로 멈춘다
- [ ] EOF 로 4 이고 상태 파일 0600 · 디렉터리 0700 · 안쪽 프레임 `waiting` 이다. 답을 주고 `--resume` 하면 이어서 `done` 이고 상태 파일이 없다
- [ ] script 가 드라이버에 SIGINT 를 보내면 130 이고 상태가 `running` 이다. 재개하면 그 단계가 다시 불린다(호출 기록 두 번)
- [ ] 멈춘 뒤 설정을 바꾸고 재개하면 2 다
- [ ] 깨진 상태 파일과 표에 없는 필드가 든 상태에서 재개가 2 다
- [ ] 하위 절차 안의 게이트에서 멈춘 실행을 재개하면 그 게이트부터 잇고, 하위 절차가 끝나면 바깥 절차의 다음 단계로 간다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 게이트 답 | 표준 입력 `approve` · ` 2 ` · `maybe` | approve 배선 · reject 배선 · 4 |
| UT-02 | 멈춤과 재개 | 표준 입력 없음(EOF) → `echo approve \| harness run … --resume` | 4 · `waiting` · 0600/0700 → `done` · 상태 파일 없음 |
| UT-03 | 중단과 재개 | `kill -INT $PPID` 하는 script → `--resume` | 130 · `running` → 그 script 호출 기록 두 번 |
| UT-04 | digest | 멈춘 뒤 단계 제목을 바꾸고 `--resume` | 2 와 8-4 문장 |
| UT-05 | 읽지 못하는 상태 | 깨진 JSON · 표에 없는 필드 상태로 `--resume` | 각각 2 |
| UT-06 | 하위 절차 안의 게이트 | 하위 절차 게이트에서 EOF → 답과 `--resume` | 하위 절차 게이트부터 이어 바깥 다음 단계 |
| UT-07 | 재개 dry-run | 멈춘 상태에서 `--resume --dry-run` | `driver: resume … (waiting)`, 상태 그대로 |

## T13 · feat: driver 실행의 agent·prompt 블록과 구조화 출력 판정

### 상위 Requirement

- relates to #208

### 작업 내용

agent · prompt 블록을 공용 역할 실행기로 헤드리스 한 번 돌리고, agent 블록의 구조화 출력을 하네스가 검증해 outcome 을 정한다.

- 명세 3-2 · 3-3, 5-3 의 판정과 `warn:` 줄, 7-2 의 2, 7-3 의 `--dry-run` 러너 줄, 7-4 의 드라이버 쪽
- 실행: agent 블록은 `script/run-agent.py <역할> --driver [--schema <파일>] --prompt <지시> --out <파일>`, prompt 블록은
  `script/run-agent.py --driver-prompt <access> --prompt <지시> --out <파일>`(T8). 표준 입력을 비우고, `--out` 파일과 스키마 파일은
  드라이버가 만든 0700 임시 디렉터리에 두며, 블록이 끝나면 그 디렉터리를 지운다. 결과 본문은 블록이 끝나면 표준 출력에 그대로 낸다.
  환경은 script 블록과 같다(`HARNESS_WORKFLOW` · `HARNESS_STEP`)
- agent 프롬프트(3-2): 역할 지시 — 역할 실행기 기본 지시와 같은 문장(역할 이름 · `.ai/templates/<역할>.md` · 규칙 정본), `입력: 이슈 <이슈>`,
  자리표시를 푼 `text`(없으면 빠진다), 스키마가 있으면 결과 끝에 그 스키마를 따르는 JSON 객체 하나를 info string 이 `json` 인 fenced 블록
  하나로 내라는 지시와 스키마 원문
- prompt 프롬프트(3-3): 이 리포의 절차 `<절차>` 의 단계 하나를 수행한다는 문장과 규칙 정본(`.ai/AI_AGENT.md`), `입력: 이슈 <이슈>`,
  `## <제목>` 과 본문 — 조각(있으면, 절차 문서와 같은 render 치환을 거친 것)과 자리표시를 푼 `text`
- outcome
  - 역할 실행기의 종료 코드가 0 이 아니면 `failed`
  - agent: 스키마가 없으면 `ok`. 있으면 결과 본문에서 꺼내(T2) 검증하고, 통과하면 `on` 필드 값(없으면 `ok`), 꺼내지 못하거나 어기면
    `failed` 와 표준 오류의 `warn: <절차>/<id>: output does not match schema <이름> — <위치>: <사유>`. 출력 내용은 옮기지 않는다. 출력은
    통과한 객체다
  - prompt: 0 이면 `ok`. 출력 없음
- 시작 전 확인(7-2 의 2): 시작한 절차와 거기서 닿는 하위 절차의 agent · prompt 블록마다 실행 계획의 그 역할 `driver` 항목(prompt 블록은
  `prompt.<access>`)의 `vendor` 로 러너를 정한다. 항목이 없거나 실행 파일이 없으면
  `` error: <실행 파일> is not installed — <절차>/<id> runs <역할 | the orchestrator> with it `` 로 2. 실행 계획은 #207 의 실효 설정과
  `run_plan()` 을 같은 프로세스에서 부른다
- `--dry-run`: 시작한 절차와 닿는 하위 절차의 agent · prompt 블록마다 `runner <절차>/<id>: <벤더>`
- 건드릴 파일: `src/harness/workflow/driver.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] claude 스텁과 codex 스텁 각각에서 결과 블록의 필드 값으로 가고, 프롬프트에 스키마 원문과 푼 `text` 가 있다
- [ ] 스키마를 어긴 결과와 블록 둘인 결과가 `failed` 로 가고, `warn:` 줄에 결과 본문의 문자열이 없다
- [ ] 러너가 `inproc` 인 역할이 오케스트레이터 벤더의 스텁으로 불리고, claude 면 `--agent <역할>` 이 있다
- [ ] 쓰기 역할과 `write` prompt 블록은 `driver_write`(선언이 없으면 `access.write`), 읽기 블록은 `access.read-only` 인자로 불린다
- [ ] prompt 블록이 역할 인자 없이 오케스트레이터 스텁으로 불리고, 프롬프트에 `## <제목>` 과 조각 · `text` 가 있다
- [ ] 러너 실행 파일이 없으면 2 이고 상태가 생기지 않는다
- [ ] agent 블록 프롬프트의 역할 지시가 `script/run-agent.py` 의 기본 지시에서 입력 줄을 뺀 문장과 같다
- [ ] 블록이 끝난 뒤 드라이버가 만든 임시 디렉터리가 남지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | agent 와 스키마 | `on = "verdict"` 프로젝트 스키마, claude 스텁 · codex 스텁이 `verdict: "retry"` 블록을 냄 | 둘 다 `retry` 배선, 기록된 프롬프트에 스키마 원문과 푼 `text` |
| UT-02 | 검증 위반 | 열거값 밖 값을 낸 결과 / `json` 블록 둘 | 둘 다 `failed`, `warn:` 줄에 결과 본문 표지 문자열 없음 |
| UT-03 | 스키마 없는 agent | 종료 코드 0 · 1 인 스텁 | `ok` · `failed` |
| UT-04 | inproc 역할 | `developer`(inproc), 오케스트레이터 claude | claude 스텁 argv 에 `--agent developer` |
| UT-05 | 권한 인자 | 쓰기 역할 · `write` prompt · 읽기 역할, `driver_write` 를 선언한 벤더 선언 사본과 지운 사본 | `driver_write` 인자 / `access.write` 인자 / `access.read-only` 인자 |
| UT-06 | prompt 블록 | 조각 있는 prompt 단계 | 역할 인자 없음, 프롬프트에 `## <제목>` · 조각 · `text` |
| UT-07 | 러너 없음 | PATH 에서 러너 스텁을 뺌 | 2, 7-2 문장, 상태 없음 |
| UT-08 | dry-run 러너 줄 | agent · prompt 블록이 있는 절차의 `--dry-run` | 블록마다 `runner <절차>/<id>: <벤더>` |
| UT-09 | 임시 디렉터리 | agent 블록 한 번 뒤 | 드라이버가 만든 디렉터리 없음 |

## T14 · feat: driver 실행과 이슈 worktree 의 재개·정리 판정

### 상위 Requirement

- relates to #208

### 작업 내용

driver 실행을 이슈 worktree 에서 돌리고, 재개 방식 대조와 worktree 정리 판정을 실행 상태에 맞춘다.

- 명세 7-3 의 4 · 5 와 worktree 문단, 7-8, 71 명세 3-3 · 3-4 · 3-6
- `--worktree` 면 71 명세 3-3 의 1 ~ 4 로 worktree 를 만들거나 열고 드라이버가 그 실행 디렉터리에서 돈다. 7-3 의 1 ~ 4 는 `harness run`
  을 부른 하네스 루트의 설정으로 판정하고, 설정 · 스키마 · 역할 실행기는 worktree 의 하네스 루트에서 읽는다. worktree 의 설정에서 그
  절차가 driver 절차가 아니면 `` error: `<절차>` is not a driver workflow in the worktree — commit the harness config to <base> first `` 로 2
- 상태의 `worktree` 로 재개 방식을 대조한다. 다르면 `error: this run started in the issue worktree — resume it with --worktree` 또는
  `error: this run started without --worktree — resume it without --worktree` 로 2
- `--resume --worktree` 는 worktree 가 남아 있어야 한다. 71 명세 3-4 의 "없다" · "빈 디렉터리" 면 아무것도 만들지 않고
  `error: the worktree of this run is gone — it cannot resume` 과 `help:` · `harness run <절차> <이슈> --discard` 로 2. 미커밋 변경이
  있으면 71 명세 3-4 대로 1 로 멈춘다
- 정리 판정(71 명세 3-6, `worktree.py`): 끝나지 않은 실행 상태가 있으면 worktree 를 남긴다
- `--dry-run --worktree`: 71 명세 3-3 의 경로 줄을 낸다
- 건드릴 파일: `src/harness/workflow/driver.py`, `src/harness/commands/run.py`, `src/harness/worktree.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 게이트에서 멈춘 `--worktree` 실행의 worktree 가 남는다
- [ ] `--resume --worktree` 가 같은 worktree 에서 잇고, `--resume` 만 주면 2 다
- [ ] worktree 를 지운 뒤 `--resume --worktree` 는 2 이고 worktree 를 새로 만들지 않는다
- [ ] worktree 의 커밋된 설정에서 그 절차가 driver 절차가 아니면 2 다
- [ ] `--worktree` 실행이 끝 상태에 닿고 미커밋 변경 · 미push 커밋이 없으면 worktree 가 71 명세 3-6 대로 정리된다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 멈춘 worktree | 게이트가 있는 절차를 `--worktree` 로, EOF | 4, worktree 남음 |
| UT-02 | 같은 방식 재개 | `--resume --worktree` / `--resume` | 같은 worktree 에서 `done` / 2 와 7-8 문장 |
| UT-03 | 사라진 worktree | worktree 를 지운 뒤 `--resume --worktree` | 2 와 7-8 문장, 새 worktree 없음 |
| UT-04 | worktree 의 설정 | 원격 통합 브랜치의 설정에서는 agent 절차인 절차를 `--worktree` 로 | 2 와 7-3 문장 |
| UT-05 | 정리 | `done` 으로 끝난 깨끗한 `--worktree` 실행 | worktree 정리 |

## T15 · feat: driver 블록 스팬과 by_step 집계

### 상위 Requirement

- relates to #208

### 작업 내용

driver 실행이 블록마다 스팬을 남기고, 지표 집계가 블록 스팬으로 단계를 센다.

- 명세 7-9
- run 스팬: `harness run` 한 번(새 실행 · 재개 각각)이 트레이스 하나다. 이름 `run/<절차>`, kind `command`, source `runner`, 속성
  `workflow` · `issue` · `worktree`(있으면) · `vendor`(오케스트레이터) · `model`(있으면) — 지금의 run 스팬과 같다
- 블록 스팬: 이름 `<절차>/<id>`, kind `step`, 속성 `workflow` · `step` · `issue`. 부모는 run 스팬이고, 하위 절차의 블록은 그 workflow
  블록의 스팬이다. 끝 상태 — script 는 종료 코드 0 이면 `ok`, 아니면 `error` 와 종료 코드, agent · prompt 는 outcome 이 `failed` 면
  `error`, 아니면 `ok`, gate · workflow 는 `ok`
- 자식(script 블록의 명령 · 역할 실행기)에 `HARNESS_TRACE_ID` · `HARNESS_PARENT_SPAN`(그 블록 스팬)을 더한다. `HARNESS_WORKFLOW` ·
  `HARNESS_STEP` 은 T10 · T13 이 넘긴다
- 스팬에 출력 · 변수 값 · 프롬프트 · 명령줄을 남기지 않는다. `issue` 속성은 지표 기록기의 이슈 검사식에 맞을 때만 남는다
- 지표 기록기는 `metrics/spans.py` 의 `load_metric()` 으로 같은 프로세스에 불러 쓴다. 지표 설정의 자리표시는 `harness run` 이 클론 키로
  풀어 기록기에 넘긴다(#207 7-3)
- `metrics_report()` 의 `by_step`: 트레이스마다, kind `step` 스팬이 있는 단계는 횟수 · 시간 · 오류를 그 스팬으로만 세고 토큰은 같은
  `workflow` · `step` 속성을 가진 스팬 전부에서 더한다. kind `step` 스팬이 없는 단계는 지금과 같다
- 건드릴 파일: `src/harness/workflow/driver.py`, `src/harness/commands/run.py`, `src/harness/metrics/spans.py`, `src/test/render-test.sh`,
  `src/test/unit/test_metrics_by_step.py`(신규)

### 완료 조건

- [ ] run 스팬과 블록 스팬(`workflow` · `step`)이 남고, 역할 실행기 스팬의 부모가 블록 스팬이며, 하위 절차 블록 스팬의 부모가 workflow 블록 스팬이다
- [ ] 스팬 파일에 script 출력과 에이전트 결과 본문의 표지 문자열이 없다
- [ ] `by_step` 이 블록마다 한 번 세고 토큰을 더한다
- [ ] Jira 키 이슈의 스팬에는 `issue` 속성이 없다
- [ ] 재개한 실행이 새 트레이스를 갖는다
- [ ] `python3 script/project/check-cli.py imports`(`metrics/` 고립 포함)와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | step 스팬 우선 | 한 트레이스에 kind `step` 스팬 하나와 같은 `workflow` · `step` 의 agent 스팬 하나(토큰) | 횟수 1, 시간 · 오류는 step 스팬, 토큰은 agent 스팬의 것 |
| UT-02 | step 스팬 없는 단계 | 단계 속성만 가진 스팬들 | 지금과 같은 집계 |
| UT-03 | 트레이스 경계 | 두 트레이스에 같은 단계, 한쪽만 step 스팬 | 트레이스마다 규칙을 따로 적용 |
| UT-04 | 스팬 구조 | script · agent · workflow(하위 script) 블록이 있는 driver 실행 | 블록 스팬 부모 관계, 역할 실행기 스팬의 부모가 블록 스팬 |
| UT-05 | 본문 없음 | 출력에 표지 문자열을 담은 script · 스텁 결과 | 스팬 파일에 표지 문자열 없음 |
| UT-06 | 이슈 속성 | `PROJ-7` 로 돈 실행 | 스팬에 `issue` 없음 |

## T16 · docs: README·기본값 주석·절차 안내 문서에 블록 그래프와 driver 실행 반영

### 상위 Requirement

- relates to #208

### 작업 내용

사람용 문서에 블록 그래프와 driver 실행을 적는다. 벤더 선언 머리 주석(T7)과 역할 실행기 안내 표(T8)는 앞 task 가 고쳤다.

- 명세 12절의 나머지 행
- `README.md`
  - 명령 표: `harness run <절차> <이슈> [--worktree] [--resume] [--discard]` — agent 절차는 오케스트레이터로, driver 절차는 하네스가 직접 실행한다
  - "`harness.toml` 이 정하는 것": `workflows.<절차>.execute` · `max_steps` · `max_visits`, 단계의 `next` · `on` · `schema` · `set` · `options` ·
    `access` · `workflow` — driver 절차의 문서는 그래프와 다음 표를 담고 커맨드가 없다
  - 실행 계획 문단(#207 이 둔 것): `roles.<역할>.driver` · `prompt` 자리 — driver 절차의 agent · prompt 블록이 쓴다
- `src/templates/defaults.toml` 의 "절차" 머리 주석: 실행 방식, 블록 다섯, 배선과 끝 상태, 자리표시, 스키마 자리. 기본 절차의 값은
  바꾸지 않는다
- `src/templates/managed/docs/workflow/changing.md` 의 "절차의 단계를 바꾼다": 단계 종류 표의 workflow 블록, 실행 방식과 배선, 자리표시,
  스키마 자리와 문법, 확장 지점
- `src/templates/managed/docs/workflow/flow.md`: driver 절차가 도는 방식 — 드라이버 · 게이트 · 재개 · 실행 상태 · 종료 코드
- `src/bin/harness render` 로 이 리포의 `docs/workflow/` 사본과 `.harness/managed` 를 갱신한다
- 건드릴 파일: `README.md`, `src/templates/defaults.toml`, `src/templates/managed/docs/workflow/changing.md` · `flow.md`, render 로 갱신되는
  `docs/workflow/changing.md` · `docs/workflow/flow.md` · `.harness/managed`

### 완료 조건

- [ ] README 의 명령 표 · 설정 표 · 실행 계획 문단에 12절의 사실이 있다
- [ ] `defaults.toml` 의 기본 절차 값이 바뀌지 않고, 기본 절차 생성물이 바뀌지 않는다(T1 의 생성물 케이스)
- [ ] `docs/workflow/changing.md` · `flow.md` 사본이 정본과 같고 `harness check` 가 통과한다
- [ ] 문서의 키 이름 · 끝 상태 · 종료 코드 · 플래그가 명세와 같다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 개정 뒤 render, `harness check` | 어긋남 없음 |
| UT-02 | 설정 설명 | `harness schema` 의 `config_notes` | 절차 머리 주석이 새 문장을 담고 JSON 이 깨지지 않음 |
| UT-03 | 검증 | `script/run-lint-test.sh` | 통과 |

## T17 · docs: 보호 문서에 블록 그래프와 driver 실행 반영

### 상위 Requirement

- relates to #208

### 작업 내용

에이전트가 근거로 읽는 보호 문서에 블록 그래프와 driver 실행을 반영한다. **보호 문서를 수정하는 task 다.** 고치는 범위는 명세 14절이고,
2026-10-09 결정 게이트에서 사용자가 허용한 범위다. 그 밖의 자리는 고치지 않는다.

- 명세 14-1 ~ 14-4. 문안은 #206 · #207 이 고친 문장 위에 더하고, 두 명세가 고친 문장을 지우거나 되돌리지 않는다
- `.ai/project/scope.md`: "할 수 있는 일" 의 `run` 항목 첫 문장만 14-1 의 문안으로 바꾼다. 같은 항목의 나머지 문장은 그대로다
- `.ai/project/architecture.md`: 14-2 표의 여덟 자리 — 구성 요소의 새 항목과 기기 단위 상태 끝, 데이터 흐름 절차 실행의 첫 문장 앞과 뒤,
  신뢰 경계의 들어오는 입력 끝과 새 항목, 새 코드를 둘 곳의 새 항목 셋, 계층과 의존 방향의 새 항목
- `.ai/project/glossary.md`: 14-3 의 새 행 열(`블록` · `outcome` · `배선` · `끝 상태` · `실행 방식` · `드라이버` · `하위 절차` · `확장 지점` ·
  `절차 변수` · `구조화 출력 스키마` · `실행 상태`)과 고친 뜻 둘(`절차(워크플로)` · `게이트`)
- `.ai/project/testing.md`: 14-4 의 에이전트 CLI 항목
- `src/bin/harness render` 로 `.ai/AI_AGENT.md` 를 다시 만든다
- 건드릴 파일: `.ai/project/scope.md` · `architecture.md` · `glossary.md` · `testing.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] 네 문서의 고친 자리가 명세 14절 문안과 같고, 14절에 없는 자리는 바뀌지 않는다
- [ ] #206 · #207 이 고친 문장이 그대로 남는다
- [ ] 렌더된 `.ai/AI_AGENT.md` 가 네 문서와 일치하고 `harness check` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/208-workflow-block-engine` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 보호 문서 개정 뒤 render, `harness check` | 어긋남 없음 |
| UT-02 | 범위 | 네 문서의 `git diff` | 14절의 자리만 바뀜 |
| UT-03 | 검증 | `script/run-lint-test.sh` | 통과 |
