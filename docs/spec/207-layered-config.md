# 설정 레이어와 개인 선택의 실행 시점 해석

하네스 설정은 파일 하나가 아니라 **레이어**로 해석한다. 아래부터 내장 기본값 ← 조직 preset ← 스택 preset ←
프로젝트 `harness.toml` ← 개인 `harness.local.toml` 이고, 위 레이어가 아래 레이어를 키마다 고정된 병합 규칙으로 덮는다.
설치는 기본값 전체가 아니라 프로젝트 이름만 담은 최소 설정을 깐다.

사람마다 다른 선택(오케스트레이터 · 러너 · 모델)은 커밋하지 않는 개인 레이어에 두고, 커밋되는 생성 파일에 넣지 않는다.
역할을 어떻게 띄우는지는 render 가 파일로 남기지 않고 실행할 때 CLI 가 해석해 낸다(`harness run-plan`). 그래서 같은 리포를 쓰는
사람들이 서로 다른 에이전트 CLI 를 골라도 생성 파일과 `harness check` 결과는 같다.

기준 코드는 #206 의 변경(하네스 로직을 `src/harness/` 패키지로 나누고 고정 사본을 패키지째 설치한다)이 들어간 통합 브랜치다.
이 명세는 함수와 모듈을 #206 의 배치로 가리킨다. 지금 이름(`normalize()` · `validate()` · `derive()` · `run_plan()` · `set_line()` 등)은
그 배치 안에서 같은 일을 하는 함수를 뜻한다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 레이어 읽기 · 병합 규칙 표 · 잠금 판정 · 값 출처 · 개인 레이어 검증 | `src/harness/config/` (#206 의 설정 패키지) |
| 명령 (`render` · `check` · `set` · `schema` · `run` · `doctor` · `install` · `uninstall` · `run-plan`) | `src/harness/commands/` (명령 하나에 모듈 하나 — 모듈 이름 규칙은 #206) |
| 생성물 (역할 어댑터 · 절차 문서 · `script/harness.env`) | #206 의 생성 모듈 (`src/harness/render/`) |
| 내장 기본값 | `src/templates/defaults.toml` |
| 설치가 까는 최소 설정 | `src/templates/harness.toml` |
| 리뷰어 어댑터 본문 | `src/templates/agents/code-reviewer.md` |
| 역할 실행기 · 리뷰 루프 · 지표 기록기 | `src/templates/managed/script/` 의 `run-agent.py` · `review-mr.sh` · `_review.py` · `post-review.sh` · `metric.py`. 하위 명령으로 이식된 것(#211 · #213)은 이식된 자리 |
| UI | `src/ui/lib/harness.js` · `src/ui/lib/labels.js` · `src/ui/lib/doctor.js` · `src/ui/app/page.js` · `src/ui/app/[project]/settings/page.js` · `src/ui/app/[project]/agents/` |
| 회귀 테스트 | `src/test/unit/` · `src/test/render-test.sh` · `src/templates/managed/script/test-review-loop.sh` · `src/ui/lib/*.test.js` |
| 사람용 설명 | `README.md` · `src/templates/managed/docs/workflow/` · `src/templates/managed/script/README.md` |

이 리포의 `script/` · `docs/workflow/` 아래 같은 이름의 파일은 거기서 설치된 사본이다.

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

바뀌는 것:

- 설정을 다섯 레이어로 읽는다(2절). 기본값의 정본은 내장 기본값 파일 하나이고, 코드 상수로 기본값을 채우지 않는다
- `harness install` 이 새 프로젝트에 프로젝트 이름만 담은 최소 `harness.toml` 을 깐다(2-4)
- `script/harness.plan.json` 을 생성하지 않는다. 이미 있으면 다음 render 가 지운다(7-2)
- 역할 어댑터(`.claude/agents/*.md` · `.codex/agents/*.toml`)에 모델이 없고, 절차 문서에 벤더 이름이 없고, `script/harness.env` 에
  `REVIEWER_LABEL` 이 없다(7절)
- 서브에이전트(`inproc`) 역할은 오케스트레이터의 모델로 돈다. 그 역할의 `roles.<역할>.model` 은 쓰이지 않는다(7-7)
- 역할은 표를 지워서가 아니라 `roles.<역할>.enabled = false` 로 끈다(5절)
- 개인 레이어 `harness.local.toml` 이 생긴다. 하네스가 git 이 그 파일을 무시하게 하고, 커밋되면 `check` 가 거부한다(6절)
- 새 명령 `harness run-plan` 이 실행 계획을 낸다. 역할 실행기 · 리뷰 루프 · 지표 기록기가 그것을 읽는다(7-1, 7-3)
- 구현자 · 리뷰어 러너 분리 불변식을 render 와 실행 시점 두 번 본다(8절)
- `harness set` 이 파일에 없는 키와 절을 더하고, `--local` 로 개인 레이어에 쓴다(9절)
- `harness schema` 가 공유 설정 값과 값마다의 출처 레이어, 개인 레이어 값을 내고, UI 설정 화면이 출처를 보인다(10절, 12절)

바뀌지 않는 것:

- **기존 전체 값 사본 `harness.toml` 은 그대로 읽힌다.** 프로젝트 레이어로 읽히고, 적힌 값이 아래 레이어 값을 덮는다.
  예외는 전체 값 사본에서 지운 역할 하나다(5-2)
- 같은 값이면 생성 파일은 위에 적은 것 말고는 지금과 같다. 전체 값 사본과, 그 사본과 공유 설정이 같은 최소 설정은 같은 생성 파일을 만든다
- 플래그 없는 `harness set` 은 지금처럼 `harness.toml` 에 쓰고 render 한다
- 역할이 서브에이전트로 도는지 CLI 러너로 도는지(실행 방식)는 공유 설정이 정한다. 절차 문서의 구조는 그것만 따른다
- 내장 기본값 파일은 `templates/` 안에 있어 고정 사본(`.harness/templates/defaults.toml`)에 함께 들어간다. 프로젝트는 설치한 버전의 기본값으로만 돈다
- 매니페스트(`.harness/generated` · `.harness/managed`)의 형식과 뜻

## 2. 레이어

### 2-1. 순서와 파일

| 순서 (아래 → 위) | 레이어 | id | 파일 |
|---|---|---|---|
| 1 | 내장 기본값 | `default` | 하네스의 `templates/defaults.toml` — 소스 리포 `src/templates/defaults.toml`, 대상 리포 `.harness/templates/defaults.toml` |
| 2 | preset | preset 받기(#216)가 정한다 | 2-5 |
| 3 | 프로젝트 | `project` | `<하네스 루트>/harness.toml` |
| 4 | 개인 | `local` | `<하네스 루트>/harness.local.toml` |

- 위 레이어가 아래 레이어를 3절의 병합 규칙으로 덮는다
- 프로젝트 레이어 파일이 없으면 지금처럼 `error: no config found` 로 멈춘다. 개인 레이어 파일은 없어도 된다
- 레이어 파일의 TOML 이 깨졌으면 그 파일 경로와 함께 `error: could not parse config` 로 멈춘다
- 최상위 키 `locked` 는 설정 값이 아니라 레이어의 잠금 선언이다(4절). 병합 결과에 들어가지 않는다

### 2-2. 공유 설정과 실효 설정

| 이름 | 병합하는 레이어 | 성질 |
|---|---|---|
| 공유 설정 | 내장 기본값 · preset · 프로젝트 | 커밋된 파일만으로 정해진다. 모든 클론과 CI 에서 같다 |
| 실효 설정 | 공유 설정 + 개인 | 이 기기에서 실제로 도는 값 |

명령마다 읽는 설정:

| 명령 | 읽는 설정 |
|---|---|
| `install` · `render` · `check` · `set`(프로젝트 레이어) · `steps` · `checks` · `write-doc` · `fix` · `forge-setup` · `vars` · `metrics` | 공유 설정. 개인 레이어 파일을 열지 않는다 — 그 파일이 깨져 있어도 이 명령들은 돈다 |
| `run` · `run-plan` · `set --local` | 실효 설정. 개인 레이어가 성립하지 않으면 멈춘다(6-2) |
| `doctor` · `status` | 둘 다. 생성 파일 대조는 공유 설정으로, 역할 · 불변식 · 모델 항목은 실효 설정으로 본다. 개인 레이어가 성립하지 않으면 멈추지 않고 그 사실을 항목으로 내며 나머지는 공유 설정으로 본다(11절) |
| `schema` | 둘 다(10절). 개인 레이어가 성립하지 않으면 멈추지 않고 그 오류를 출력에 싣는다 |

### 2-3. 내장 기본값 — `src/templates/defaults.toml`

지금 `src/templates/harness.toml` 의 내용(값과 키마다의 주석)을 옮기고 아래를 더하고 고친 파일이다. 키 바로 위 주석이 그 키의 설명이다 —
`harness schema` 의 `config_notes` 가 이 파일에서 나온다(10절).

| 키 | 내장 기본값 | 근거 |
|---|---|---|
| 머리 주석 | 이 파일이 가장 아래 레이어이고, 프로젝트는 이 파일을 고치지 않고 `harness.toml` 에 같은 키를 적어 덮는다는 안내 | — |
| `project.name` | `""` | 프로젝트 레이어가 반드시 채운다. 비어 있으면 설정을 읽는 명령이 거부한다: `error: project.name is empty — set it in harness.toml` |
| `branches.protected` | `[]` | `branches.base` 는 병합 뒤 보호 목록에 자동으로 들어간다(3-6). 기본값에 브랜치 이름을 두면 합집합 규칙 때문에 그 이름을 쓰지 않는 프로젝트에도 보호 브랜치로 들어간다 |
| `docs.protected` | 지금 코드의 `BASE_PROTECTED` 여섯 항목(`.ai/project/` 의 scope · architecture · glossary · testing · `roles/` · `workflows/`) | 합집합 규칙이 위 레이어에서 이 항목을 빼지 못하게 한다(3-2). `BASE_PROTECTED` 상수는 없어진다 |
| `roles.<역할>.enabled` | 모든 역할에 `true` | 5절 |
| `roles.<역할>.model` | 모든 역할에 `""` | 키가 아래 레이어에 있어야 `harness set` 이 그 키를 더할 수 있다(9-1) |
| `harness.model` · `[commands]` · `[verify]` · `[metrics]` · `[worktree]` · `[permissions]` · `[doctor]` · `forge.templates` | 지금 코드 상수(`VERIFY_DEFAULTS` · `METRICS_DEFAULTS` · `WORKTREE_DEFAULTS` · `PERMISSIONS_DEFAULTS` · `DOCTOR_DEFAULTS` · `FORGE_DEFAULTS` · `COMMAND_KEYS` 의 빈 값)와 같은 값 | 기본값의 정본을 이 파일 하나로 둔다. 그 상수들은 값의 출처로 쓰지 않는다 |

- 나머지 키(`[harness]` 의 `version` · `orchestrator`, `[commit]` · `[review]` · `[roles.*]` 의 `runner` · `access` · `tools`, `[invariants]` · `[forge]` · `[issues]` · `[mr]` · `[adr]` · `[usage]` · `[workflows.*]`)의 값은 지금 기본 설정의 값 그대로다
- 이 파일은 `locked` 를 선언하지 않는다
- 절에 정의되지 않은 키를 거부하는 검사(`[commands]` · `[verify]` · `[metrics]` · `[worktree]` · `[permissions]` · `[doctor]`)는 받을 키 목록을 이 파일의 그 절에서 읽는다
- 하네스 버전 번호(`harness_version()`)와 소스 리포 판정(`source_tree()`)이 읽던 기본 설정 파일은 이 파일이다
- 절차가 하나도 없는 설정에 하네스 기본 절차를 채우던 일(`default_workflows()` 와 `normalize()` 의 `setdefault`)은 이 레이어의 `[workflows.*]` 가 병합으로 한다

### 2-4. 프로젝트 레이어와 최소 설정

`src/templates/harness.toml` 은 설치가 프로젝트에 까는 최소 설정이다.

```toml
# 이 프로젝트의 하네스 설정 — 프로젝트 레이어.
#
# 이 프로젝트가 기본값과 다르게 정하는 값만 적는다. 적지 않은 키는 내장 기본값을 따른다 —
# 키와 설명은 .harness/templates/defaults.toml 에 있고, 값마다 어디서 왔는지는 `harness schema` 가 보인다.
# 사람마다 다른 에이전트 CLI · 모델은 이 파일이 아니라 커밋하지 않는 harness.local.toml 에 둔다(`harness set --local`).
#
#   harness set <절.키> <값>    값을 이 파일에 쓰고 다시 생성한다

[project]
name = "my-project"
```

- `harness install` 은 프로젝트 레이어 파일이 없을 때 이 파일을 깔고 `name` 을 대상 디렉터리 이름으로 채운다(지금 `seed_config()` 와 같은 자리 · 같은 경로 규칙)
- 깔았다는 출력은 `created <경로> — it holds only this project's values; run \`harness schema\` to see the rest and where each comes from` 이다
- 이미 있는 `harness.toml`(전체 값 사본 포함)은 건드리지 않는다
- 이 리포 루트의 `harness.toml` 은 고치지 않는다. 전체 값 사본이 그대로 읽히는 것을 이 리포가 보인다

### 2-5. preset 자리

설정 로더는 내장 기본값과 프로젝트 사이에 preset 레이어 목록을 받는다. 목록에서 앞의 것이 아래 레이어다 — 체인의 먼 조상(조직 preset)이
아래, 프로젝트가 직접 가리키는 preset(스택 preset)이 위다. **이 명세 범위에서 그 목록은 언제나 비어 있다.** 무엇을 몇 개 싣는지, 레이어
id 와 출처 표시를 어떻게 적는지는 preset 받기(#216)가 정한다.

병합 규칙(3절)과 잠금(4절)은 preset 레이어에도 똑같이 적용되도록 레이어 목록 단위로 동작한다.

## 3. 병합 규칙

### 3-1. 규칙 표

규칙은 키마다 하네스의 병합 규칙 표(`src/harness/config/`)에 고정한다. 사용자가 고르지 않고 연산자 문법은 없다.

| 키 | 규칙 |
|---|---|
| `docs.protected` · `branches.protected` | 합집합 (3-2) |
| `verify.checks` | `name` 기준 병합 (3-3) |
| `workflows.<이름>` | 절차 하나를 통째로 교체 (3-4) |
| 그 밖의 테이블(인라인 테이블 포함 — `issues.labels`, `roles.<역할>` 등) | 키 단위 깊은 병합 |
| 그 밖의 배열(`commit.tags` · `worktree.include` · `roles.<역할>.tools` · `issues.required_fields` 등) | 위 레이어의 배열로 통째 교체 |
| 그 밖의 스칼라 | 위 레이어 값으로 덮어쓰기. 잠긴 키면 4절 |

- 아래 레이어에 없는 키는 위 레이어 값이 그대로 들어간다. 위 레이어에 없는 키는 아래 레이어 값이 남는다
- 병합한 뒤 지금과 같은 검증(`validate()`)을 돈다. 값의 형식 오류는 병합이 아니라 검증이 잡는다

### 3-2. 보호 목록

- 결과는 아래 레이어의 항목을 그 순서대로 두고, 위 레이어에만 있는 항목을 그 순서대로 뒤에 붙인 것이다. 같은 항목은 한 번만 둔다
- 위 레이어가 아래 레이어의 항목을 빼는 표기는 없다. 위 레이어 목록에 아래 항목이 없어도 결과에 남는다
- 지금 `normalize()` 가 하던 두 동작 중 `BASE_PROTECTED` 를 앞에 붙이는 것은 이 규칙과 내장 기본값의 `docs.protected` 가 대신한다

### 3-3. `verify.checks`

- 항목은 `name` 으로 짝짓는다
- 위 레이어에 같은 `name` 의 항목이 있으면 그 항목 전체가 아래 항목을 대신한다. 결과에서 자리는 아래 항목의 자리다
- 위 레이어에만 있는 항목은 아래 레이어 항목들 뒤에 위 레이어의 순서대로 붙는다
- 아래 레이어의 항목을 빼는 표기는 없다
- 항목 안의 `locked` 는 4절이다

### 3-4. 절차

- `workflows` 아래는 절차 이름 단위로 합친다. 위 레이어에 같은 이름의 절차가 있으면 그 절차의 본문(`title` · `steps` 와 그 밖의 키 전부)이
  아래 절차를 통째로 대신한다. 단계 단위로 섞지 않는다
- 위 레이어에 없는 절차는 아래 레이어 것이 남는다 — 프로젝트가 `[workflows.<이름>]` 를 지우면 내장 기본값의 그 절차로 돌아온다
- 절차를 확장하는 지점(빈 하위 절차)은 절차 블록 엔진(#208)이 정한다

### 3-5. 형이 다른 값

같은 키가 한 레이어에서는 테이블이고 다른 레이어에서는 테이블이 아니거나, 한 레이어에서는 배열이고 다른 레이어에서는 배열이 아니면
병합하지 않고 멈춘다.

```
error: roles.code-reviewer is a table in the built-in defaults but a string in harness.toml
  --> harness.toml
```

스칼라끼리 형이 다른 것(문자열과 정수 등)은 덮어쓴 뒤 검증이 잡는다.

### 3-6. 병합 뒤 파생

병합과 잠금 판정이 끝난 설정에 아래를 한 번 한다. 지금 `normalize()` 의 남는 일이다.

- `branches.base` 가 `branches.protected` 에 없으면 뒤에 붙인다
- 절차 단계의 `kind` 를 `type` 으로 읽는다(옛 표기)
- `enabled = false` 인 역할을 `roles` 에서 뺀다(5-1). 그 뒤의 모든 소비자(검증 · 생성 · `run-plan` · `schema` 의 역할 표)는 켜진 역할만 본다

## 4. 잠금 — `locked`

### 4-1. 표기

레이어 파일 최상위에 잠글 키의 경로 목록을 둔다. `verify.checks` 항목은 항목 안에 표시한다.

```toml
locked = ["invariants.distinct_reviewer", "roles.code-reviewer.enabled"]

[verify]
checks = [
  { name = "모듈 경계", run = "script/check-deps.sh", locked = true },
]
```

- 경로는 점으로 이은 키 경로 하나다. 와일드카드는 없다
- TOML 규칙상 최상위 키라서 첫 절 머리보다 앞에 적는다

### 4-2. 선언할 수 있는 레이어와 잠글 수 있는 값

| 조건 | 어기면 |
|---|---|
| `locked` 와 항목의 `locked` 는 내장 기본값과 preset 레이어만 선언한다 | 프로젝트 · 개인 레이어 파일에 있으면 거부: `error: harness.toml declares locked — only the built-in defaults and presets can lock values` |
| 경로는 선언한 레이어까지 병합한 설정에서 스칼라를 가리킨다 | `error: <레이어>: locked path <경로> is not a scalar value` (없는 키 · 테이블 · 배열) |
| 개인 레이어가 받는 키 넷(6-1)은 잠그지 않는다 — 에이전트 CLI · 모델은 사람마다 고른다 | `error: <레이어>: <경로> cannot be locked — it is a personal choice` |
| 항목의 `locked` 는 참 · 거짓 값이다 | `verify.checks` 항목 검증 오류 |

이 명세 범위에서 잠금을 선언하는 레이어는 없다 — 내장 기본값은 선언하지 않고 preset 자리는 비어 있다. 판정은 4-3 대로 구현하고 회귀 테스트가
잠금을 선언한 내장 기본값 사본으로 본다(14절).

### 4-3. 판정

- 잠긴 경로를 그 위의 레이어(위의 preset · 프로젝트)가 적으면, 값이 잠근 레이어까지의 병합 값과 **같으면 받아들이고 다르면 거부한다**
- 같은지는 TOML 로 읽은 값의 동등이다
- 잠긴 `verify.checks` 항목은, 위 레이어의 같은 `name` 항목이 `locked` 를 뺀 모든 키에서 같으면 받아들이고 다르면 거부한다
- 한 번 잠긴 경로는 그 위의 모든 레이어에 잠긴 채다

```
error: review.max_rounds is locked by the built-in defaults
  --> harness.toml

  harness.toml sets 7, but the locked value is 5.

help: remove the line from harness.toml, or set it to the locked value
```

잠금 위반은 공유 설정을 읽는 모든 명령을 멈춘다. 개인 레이어가 받는 키는 잠기지 않으므로(4-2) 개인 레이어는 잠금에 걸리지 않는다.

## 5. 역할 끄기 — `roles.<역할>.enabled`

### 5-1. 뜻

- `enabled` 는 참 · 거짓 값이고 내장 기본값은 모든 역할에서 `true` 다. 참 · 거짓이 아니면 거부: `error: roles.<역할>.enabled must be true or false (got <값>)`
- `false` 인 역할은 설정에 없는 역할과 같다 — 역할 계약(`.ai/templates/<역할>.md`) · 어댑터 두 형식 · 그 역할 전용 커맨드 · 자산 표의 행이
  만들어지지 않고, 지난 render 가 만든 것은 정리된다. 지금 역할 표를 지웠을 때의 결과와 같다
- 꺼진 역할을 부르는 `agent` 단계가 있으면 지금처럼 `is not a configured role` 로 거부한다. 개인 레이어가 꺼진 역할을 적으면 6-2 의 오류다
- 조직은 `locked = ["roles.<역할>.enabled"]` 로 역할 단위로 켠 채 잠글 수 있다(4절)
- 역할을 끄고 켜는 수단은 `harness set roles.<역할>.enabled <true|false>` 다

`harness doctor` 의 남은 참조 검사(`dangling_roles()`)는 꺼진 역할을 "설정에 없는 역할" 로 본다. 항목 문구는
`role \`<역할>\` is off in the config` 이고, 설정 파일(`harness.toml` · `harness.local.toml`)은 그 검사에서 훑지 않는다 — 역할을 끄는
줄 자체가 그 역할 이름을 담는다.

### 5-2. 전체 값 사본에서 지운 역할

깊은 병합 아래서는 전체 값 사본에서 `[roles.<역할>]` 표를 지운 프로젝트에도 내장 기본값이 그 역할을 켠다. 그 역할이 말없이 되살아나지 않게
render 가 멈추고 안내한다.

판정 — 아래가 모두 참인 역할이 하나라도 있으면 멈춘다.

1. 직전 생성 매니페스트(`.harness/generated`)에 `script/harness.plan.json` 이 있다 — 직전 render 가 레이어 이전 하네스의 것이다
2. 직전 생성 매니페스트에 그 역할의 어댑터(`.claude/agents/<역할>.md` · `.codex/agents/<역할>.toml`)가 하나도 없다
3. 이번 공유 설정에서 그 역할이 켜져 있다
4. 프로젝트 레이어 파일에 그 역할의 키가 하나도 없다

```
error: role security-guard was not part of the last render, and the built-in defaults now turn it on
  harness.toml does not mention it, so the default applies.

help: keep it off
        harness set roles.security-guard.enabled false
help: or take it
        harness set roles.security-guard.enabled true
```

- 걸린 역할을 한 번에 모두 적고, `help` 의 명령은 그 역할 전부를 한 줄의 `harness set` 쌍으로 낸다
- `render` · `check` 가 이 판정으로 멈춘다(종료 코드 2). `doctor` 는 생성 파일 절에 같은 사실을 `bad` 항목으로 낸다
- `set` · `steps` · `checks` 는 바꾼 설정으로 이 판정을 돌고, 걸리면 지금 검증 실패처럼 설정을 되돌리고 멈춘다. 걸린 역할을 `enabled` 로 적는
  `set` 은 4번 조건을 깨므로 통과한다
- `install` 은 render 단계에서 같은 오류로 멈춘다. 고정 사본과 등록은 이미 갱신된 채다
- 판정이 통과해 render 가 끝나면 매니페스트에서 `script/harness.plan.json` 이 빠지므로(7-2) 이 판정은 그 하네스 루트에서 다시 돌지 않는다
- 매니페스트가 없는 첫 설치는 판정하지 않는다

## 6. 개인 레이어 — `harness.local.toml`

### 6-1. 받는 키와 값 범위

| 키 | 값 |
|---|---|
| `harness.orchestrator` | 공유 설정과 같은 검증 — 벤더 선언에 `launch` 가 있는 벤더 id |
| `harness.model` | 문자열 |
| `roles.<역할>.runner` | **공유 설정의 그 역할과 실행 방식이 같은 값.** 공유 설정이 `inproc` 이면 `inproc` 만, CLI 러너면 벤더 선언에 `headless` 가 있는 벤더 id 만 받는다 |
| `roles.<역할>.model` | 문자열. 공유 설정에서 그 역할이 `inproc` 이면 빈 문자열만 받는다(7-7) |

- `<역할>` 은 공유 설정에서 켜진 역할이어야 한다
- 이 밖의 키, 최상위 `locked`, preset 참조 키는 받지 않는다
- 병합은 3절 그대로다. 이 넷은 모두 스칼라라 덮어쓰기다

### 6-2. 읽는 명령과 오류

실효 설정을 읽는 명령(2-2)은 개인 레이어가 성립하지 않으면 종료 코드 2 로 멈춘다 — 설정을 읽지 못하면 통과가 아니라 차단이다.

| 경우 | 오류 첫 줄 |
|---|---|
| TOML 이 깨졌다 | `error: could not parse config` (`--> harness.local.toml`) |
| 받지 않는 키 | `error: harness.local.toml sets <키>, which is not a personal choice` — 받는 키 넷과 `help: put project values in harness.toml` 을 함께 낸다 |
| 켜진 역할이 아니다 | `error: harness.local.toml sets roles.<역할>.<키>, but <역할> is not a configured role` |
| 실행 방식을 바꾼다 | `error: roles.<역할>.runner = <값> in harness.local.toml, but the project runs <역할> <as a subagent \| through a CLI>` — 개인 러너는 실행 방식을 유지하고 CLI 만 고른다는 설명과 고를 수 있는 값을 `help` 로 낸다 |
| 서브에이전트 역할의 모델 | `error: roles.<역할>.model in harness.local.toml has no effect — <역할> runs as a subagent and uses the orchestrator's model` 과 `help: harness set --local harness.model <model>` |
| 값의 형 | `error: harness.local.toml: <키> must be a string (got <값>)` |
| 불변식 위반 | 8절의 오류 |

`render` · `check` 는 이 파일을 읽지 않으므로 이 오류로 멈추지 않는다. 개인 파일이 있든 없든, 내용이 무엇이든 생성 파일과 `check` 결과가 같다.

### 6-3. git 이 무시하게 하기

하네스는 프로젝트의 `.gitignore` 를 고치지 않는다. 대신 git 공통 디렉터리의 `info/exclude` 에 한 줄을 적는다 — 커밋되지 않고 같은 클론의
모든 worktree 가 공유한다.

- 적는 파일: 하네스 루트에서 `git rev-parse --git-path info/exclude` 가 내는 경로. linked worktree 에서도 본 클론의 `.git/info/exclude` 다
- 적는 줄: `/<리포 안의 위치>harness.local.toml` — 리포 안의 위치는 하네스 루트에서 `git rev-parse --show-prefix` 의 출력이다
  (리포 최상위면 `/harness.local.toml`, 모노레포 서브프로젝트면 `/services/api/harness.local.toml`)
- 하네스 루트에서 `git check-ignore -q -- harness.local.toml` 이 이미 무시한다고 답하거나, 같은 줄이 이미 있으면 적지 않는다
- `info/` 디렉터리가 없으면 만든다. 그 파일이 심볼릭 링크이거나 쓸 수 없으면 적지 않고 `warn: could not add harness.local.toml to git's exclude file` 을 낸다.
  명령은 멈추지 않는다
- 적었으면 `ignore: harness.local.toml (git info/exclude)` 한 줄을 출력한다
- 하네스 루트가 git 작업 트리가 아니면 하지 않는다

적는 시점:

| 시점 | 개인 파일 |
|---|---|
| `harness install` — 등록 뒤 render 전 | 만들지 않는다. 나중에 손으로 만든 파일도 무시되게 줄만 미리 적는다 |
| `harness set --local` — 파일을 쓰기 전 | 9-2 |

새로 클론한 기기는 두 명령 중 하나를 돌기 전까지 이 줄이 없다. 그 사이 손으로 만든 개인 파일은 미추적 파일로 보이므로 `review-mr.sh` 의 작업 트리
검사가 멈추고(안전한 쪽), `harness doctor` 가 알린다(11절).

### 6-4. 추적 금지 — `harness check`

개인 파일이 git 인덱스에 있으면(`git ls-files --error-unmatch -- harness.local.toml` 이 성공하면) `check` 가 종료 코드 1 로 거부한다. `--staged` 도 같다 —
pre-commit 이 그 파일을 커밋에 넣는 것을 막고, CI 의 검증이 커밋된 파일을 잡는다.

```
error: harness.local.toml is tracked by git
  It holds one person's choices; committed, it would become every clone's.

help: untrack it and keep your copy
        git rm --cached harness.local.toml
```

하네스 루트가 git 작업 트리가 아니면 보지 않는다.

### 6-5. 이슈 worktree 로 옮기기

`harness run --worktree` 가 새 worktree 를 만들면 하네스 루트의 `harness.local.toml` 을 worktree 실행 디렉터리로 복사한다.

- `worktree.include` 값과 상관없이 복사한다
- 복사 규칙은 `include` 복사와 같다 — 없으면 건너뛰고, worktree 에서 추적되는 경로면 덮지 않고, git 이 무시하지 않으면 복사하지 않고
  `warn: harness.local.toml is not ignored by git — not copied` 를 낸다. 복사한 내용을 출력하지 않는다
- worktree 안의 역할 실행기 · 리뷰 루프가 본 클론과 같은 개인 선택으로 실행 계획을 받는다

### 6-6. `harness uninstall`

- `--purge` 가 지우는 설정에 `harness.local.toml` 이 든다. 확인 목록에도 보인다. `--purge` 가 없으면 남긴다 — `harness.toml` 과 같다
- `info/exclude` 에 적은 줄은 지우지 않는다

## 7. 개인 의존 값을 커밋 생성물에서 빼기

### 7-1. 실행 계획 — `harness run-plan`

`harness run-plan` 은 실효 설정을 읽어 실행 계획을 JSON 한 개로 표준 출력에 낸다. 인자는 `--target` 뿐이다. 고정한 버전이 답하는 명령이다
(`DELEGATES` 에 든다).

```json
{
  "roles": {
    "code-reviewer": {"via": "headless", "vendor": "codex", "label": "Codex", "model": "",
                      "exe": "codex", "argv": ["codex", "exec", "--sandbox", "read-only", "--ephemeral"],
                      "output": ["--output-last-message", "{out}"], "usage_format": ["--json"],
                      "usage_parser": "codex-jsonl", "auth_check": ["codex", "login", "status"],
                      "auth_timeout": 30, "entry": "script/review-mr.sh"},
    "developer": {"via": "subagent", "vendor": "claude", "label": "Claude", "model": ""}
  },
  "metrics": {"dir": "...", "retention_days": 30, "max_file_mb": 10, "max_total_mb": 100,
              "stale_after_hours": 6, "capture_logs": "errors"}
}
```

| 필드 | 뜻 |
|---|---|
| `roles` | 켜진 역할마다 한 항목. 지금 `run_plan()` 이 내던 필드에 `label` 을 더한 것 |
| `roles.*.via` | `subagent`(러너 `inproc`) · `headless`(CLI 러너) |
| `roles.*.vendor` | 그 역할을 실제로 실행하는 벤더 — 서브에이전트 역할은 실효 오케스트레이터 |
| `roles.*.label` | 그 벤더 선언의 `label`, 없으면 `name`. 리뷰 댓글의 작성자 표시다 |
| `roles.*.model` | 그 역할이 실제로 쓰는 모델(7-7) |
| `exe` · `argv` · `output` · `usage_format` · `usage_parser` · `auth_check` · `auth_timeout` · `entry` | CLI 러너 역할에만. 뜻과 계산은 지금과 같고 실효 설정으로 계산한다 |
| `metrics` | 공유 설정의 `[metrics]` 값 그대로. 자리표시는 풀지 않는다 — 지표 기록기가 실행할 때 푼다 |

- 실효 설정이 성립하지 않으면(공유 설정 오류 · 6-2 · 잠금 · 8절) 아무것도 내지 않고 그 오류로 종료 코드 2
- 실행 계획을 계산하는 함수는 하나다. `run-plan` 과, 같은 프로세스 안에서 실행 계획이 필요한 CLI 코드(`harness run` · doctor)가 같은 함수를 부른다.
  절차 드라이버(#208) · 하위 명령으로 이식된 실행기와 지표 기록기(#211 · #213)도 같은 함수를 부른다
- 출력은 기기마다 다를 수 있다. 파일로 남기지 않는다

### 7-2. `script/harness.plan.json` 걷기

- `plan()` 에서 `script/harness.plan.json` 을 뺀다. 생성 파일이 아니다
- 이미 있는 리포는 다음 render 가 지운다 — 직전 생성 매니페스트에 있고 이번 render 가 만들지 않는 생성 파일이므로 지금의 정리(`prune`)가 그대로 지운다
- `check` 는 그 파일을 대조하지 않는다. 이 이슈를 담은 버전의 render 를 한 번 돈 리포에는 그 파일이 없다

### 7-3. 실행 계획을 읽는 쪽

스크립트는 하네스 루트에서 `.harness/bin/harness`, 없으면 `src/bin/harness` 중 처음 실행할 수 있는 것을 CLI 로 쓴다 — `run-lint-test.sh` 와 같은 순서다.
둘 다 없으면 실행 계획이 없는 것이다. CLI 를 `run-plan --target <하네스 루트>` 로 부르고 표준 출력의 JSON 을 읽는다.

| 읽는 쪽 | 받는 것 | 실행 계획을 받지 못했을 때 |
|---|---|---|
| 역할 실행기 `run-agent.py` | 자기 역할의 항목 | CLI 의 표준 오류를 그대로 흘리고 종료 코드 2. CLI 가 없으면 `error: no harness CLI to resolve the run plan (.harness/bin/harness or src/bin/harness)`. `--check` 도 같다 |
| 리뷰 루프 `review-mr.sh` | `code-reviewer` 의 `exe` 와 `label` | 회차를 올리기 전에 CLI 의 표준 오류를 흘리고 `help: the round was not used — fix the config, then rerun` 과 종료 코드 2 |
| 리뷰 등록 `post-review.sh` | 작성자 표시 인자가 없을 때 `code-reviewer` 의 `label` | 지금 기본값 `자동 리뷰` 를 쓴다. 등록은 계속한다 |
| 지표 기록기 `metric.py` | `metrics` | 기록하지 않는다. 부른 쪽의 출력 · 종료 코드를 바꾸지 않는다 |

- `run-agent.py` 의 역할이 실행 계획에 없으면 `error: no role \`<역할>\` in the config (have: <역할들>)` 이다. 실행 계획의 필수 필드가 없거나 형이 틀리면
  `error: the run plan from <CLI 경로> is broken` 과 종료 코드 2 다
- `review-mr.sh` 는 `_review.py` 로 실행 계획을 읽는다. `plan-exe` 는 파일 경로 대신 표준 입력의 실행 계획 JSON 에서 `code-reviewer` 의 `exe` 를 내고,
  `plan-label` 이 같은 입력에서 `label` 을 낸다. 받은 `label` 을 `post-review.sh` 의 작성자 표시로 넘긴다. `exe` 가 비면 지금처럼
  `no review runner is configured` 로 멈춘다
- `metric.py` 는 프로세스 하나에서 한 번만 CLI 를 부른다. `HARNESS_METRICS=off` 면 CLI 를 부르지 않고 기록하지 않는다
- CLI 가 지표 기록기를 같은 프로세스에 불러 쓸 때(`harness run`)는 CLI 가 해석한 지표 설정을 넘기고 CLI 를 다시 띄우지 않는다

### 7-4. 역할 어댑터

- `.claude/agents/<역할>.md` 의 frontmatter 에 `model:` 을 쓰지 않는다. `.codex/agents/<역할>.toml` 에 `model =` 을 쓰지 않는다
- 리뷰어 어댑터 본문(`src/templates/agents/code-reviewer.md`)의 등록 명령에서 작성자 표시 자리표시(`{{REVIEWER_LABEL}}`)를 뺀다

  ```bash
  script/post-review.sh <리뷰요청번호> <리뷰본문파일>
  ```

  그 아래에 "작성자 표시를 주지 않으면 이 기기의 실행 계획에서 리뷰어 이름을 찾아 붙인다" 는 한 문장을 둔다
- 어댑터의 나머지(이름 · 설명 · 도구 · 샌드박스 · 본문 · 이 프로젝트의 역할 메모)는 지금과 같다

### 7-5. 절차 문서

CLI 러너 역할을 부르는 `agent` 단계의 제목과 본문에서 벤더 이름을 뺀다.

| 자리 | 지금 | 바뀐 뒤 |
|---|---|---|
| 단계 제목 | `<제목> — <역할> 역할을 <벤더 이름> 로 실행` | `<제목> — <역할> 역할을 CLI 러너로 실행` |
| 본문 첫 문단 | `이 역할은 서브에이전트가 아니라 <벤더 이름> 로 따로 돈다(\`roles.<역할>.runner\`).` | `이 역할은 서브에이전트가 아니라 CLI 러너로 따로 돈다(\`roles.<역할>.runner\`). 어느 CLI 인지는 실행하는 기기의 설정이 정한다.` |

본문의 나머지 문장과 서브에이전트 단계("… 역할에 위임")는 그대로다.

### 7-6. `script/harness.env`

`REVIEWER_LABEL` 을 뺀다(`derive()` 의 그 변수도 없어진다). 리뷰어 표시는 7-3 대로 실행할 때 정해진다. 나머지 변수는 그대로다.

### 7-7. 서브에이전트 역할의 모델

- `inproc` 역할은 오케스트레이터 세션의 모델로 돈다. `roles.<역할>.model` 은 어느 레이어에 있든 쓰이지 않는다 — 지금 "러너가 오케스트레이터와 같은
  CLI 인 역할" 이 `harness.model` 만 쓰는 것과 같은 규칙이다
- 실행 계획의 `model` 은 서브에이전트 역할과 러너가 오케스트레이터와 같은 역할에서 `harness.model`, 다른 CLI 러너 역할에서 `roles.<역할>.model` 이다
- 공유 설정의 `inproc` 역할에 빈 문자열이 아닌 `model` 이 있으면 받아들이고(전체 값 사본 호환) `harness doctor` 가 경고한다(11절)
- 오케스트레이터 모델은 `harness run` 이 띄울 때 벤더 선언의 `model` 인자로 넘긴다(지금과 같다)
- 모델을 적지 않은 서브에이전트 정의가 그 세션의 모델로 도는지는 벤더마다 <!-- TBD: 확인 필요 -->

## 8. 불변식 — 두 시점에서 본다

`invariants.distinct_reviewer` 가 켜져 있으면 역할 선언의 `distinct_from` 짝의 실행 주체가 같은지 두 시점에서 본다.

| 시점 | 설정 | 위반이면 |
|---|---|---|
| `render` · `check` · 프로젝트 레이어 `set` · `steps` · `checks` | 공유 설정 | 지금과 같은 오류로 거부 |
| `harness run`(띄우기 전, `--dry-run` 포함) · `harness run-plan` · `set --local` | 실효 설정 | 아래 오류로 거부. `run` 은 아무것도 띄우지 않고 worktree 도 만들지 않는다 |

실효 설정의 위반은 그 값을 개인 레이어가 만들었음을 알린다.

```
error: developer and code-reviewer run on the same runner (codex) on this machine
  --> harness.local.toml

  A model reviewing its own output walks past the same blind spot twice,
  so the review adds nothing the implementation did not already assume.

help: give code-reviewer a different runner on this machine
        harness set --local roles.code-reviewer.runner <claude|codex>
```

- `run-agent.py` · `review-mr.sh` 는 실행 계획을 받을 때 `run-plan` 이 이 검사로 거부하므로 진입에서 멈춘다(7-3)
- 불변식을 끄는 키(`invariants.distinct_reviewer`)는 개인 레이어가 받지 않는다. 끄는 것은 프로젝트의 결정이다
- `harness doctor` 는 실효 설정의 위반을 `bad` 항목으로 낸다(11절)

## 9. `harness set`

### 9-1. 프로젝트 레이어 — 파일에 없는 키와 절 더하기

플래그 없는 `harness set <절.키> <값> ...` 은 지금처럼 `harness.toml` 에 쓰고 한 번에 검증한 뒤 render 한다. 바뀌는 것은 쓸 수 있는 키의 범위다.

- 쓸 수 있는 키: 프로젝트 레이어 아래 레이어들을 병합한 설정에 있는 키와, `harness.toml` 에 이미 있는 키. 그 밖이면 지금처럼
  `error: no such key \`<키>\`` 로 거부하고 `help: the keys are the ones in the built-in defaults (harness schema shows them)` 를 낸다
- 값이 테이블인 키와 인라인 테이블 안의 키는 지금처럼 쓰지 않는다
- 키가 파일에 없고 그 절이 있으면 그 절 끝에 한 줄을 더한다(지금 선택 키를 더하는 자리 규칙)
- 절이 없으면 파일 끝에 빈 줄과 `[<절>]` 머리, 그 키 한 줄을 더한다 — `roles.<역할>.enabled` 처럼 역할 절이 없는 전체 값 사본에도 쓴다
- 지금의 선택 키 특례(`OPTIONAL_ROLE_KEYS` · `harness.model` · 기본값이 있는 절)는 위 규칙이 대신한다
- 출력은 지금 형식(`set: <바꾸기 전>` / `  to <바꾼 뒤>`)이다. 파일에 없던 키는 바꾸기 전 자리에 아래 레이어 값과 그 레이어를 보인다 —
  `set: max_rounds = 5 (default)`
- 바꾼 설정이 잠금 · 검증 · 5-2 의 판정에 걸리면 지금처럼 설정을 되돌린다

### 9-2. 개인 레이어 — `harness set --local`

`harness set --local <절.키> <값> [<절.키> <값> ...]` 은 모든 쌍을 `harness.local.toml` 에 쓴다.

1. 키가 모두 6-1 의 넷인지 본다. 아니면 아무것도 쓰지 않고 6-2 의 오류로 멈춘다
2. 6-3 대로 `info/exclude` 에 줄을 적는다
3. 파일이 없으면 머리 주석과 함께 만든다. 주석은 이 파일이 이 기기의 개인 선택이고 커밋하지 않는다는 것과 받는 키 넷을 적는다
4. 9-1 과 같은 줄 편집으로 값을 쓴다. 쓰기는 대상 리포 경로 규칙의 공용 함수를 거친다
5. 실효 설정 전체를 검증한다(6-2 · 8절). 실패하면 원래 내용으로 되돌리고, 이 명령이 만든 파일이면 지운 뒤 `reverted — the config is unchanged` 와 종료 코드 2
6. 바뀐 줄을 9-1 형식으로 출력한다. render 하지 않는다 — 개인 레이어는 생성 파일에 닿지 않는다

- 개인 레이어의 키를 지우는 명령은 두지 않는다. 파일에서 그 줄을 지운다
- 사용법 오류 문구의 예시에 `harness set --local harness.orchestrator codex` 를 더한다

## 10. `harness schema` — 값과 출처

지금 출력에 아래 키를 더한다. 기존 키의 뜻은 그대로이고 공유 설정으로 계산한다.

| 키 | 값 |
|---|---|
| `config` | 공유 설정 전체(병합 · 파생 뒤). 꺼진 역할은 `roles` 에 없다 |
| `layers` | 아래 → 위 순서의 레이어 목록. 항목은 `{"id", "path"}` 이고 개인 레이어는 `"present"`(파일이 있는가)를 더한다. 내장 기본값의 `path` 는 지금 `template_path()` 규칙으로 적는다 |
| `sources` | `{"<점으로 이은 키>": "<레이어 id>"}` — `config` 의 값마다 그 값을 마지막으로 정한 레이어. 테이블은 안의 값까지 내려가고, 배열과 `workflows.<이름>` 은 한 값이다. 보호 목록은 항목을 더한 가장 위 레이어다 |
| `same_as_below` | 출처가 `project` 인 키 가운데 그 값이 프로젝트 아래 레이어들의 병합 값과 같은 키 목록. 그 줄을 지워도 값이 바뀌지 않는다는 표시다 |
| `locked` | 잠긴 키 경로 목록 |
| `inherited_items` | `{"docs.protected": [...], "branches.protected": [...]}` — 프로젝트 아래 레이어에서 온, 프로젝트가 뺄 수 없는 항목 |
| `roles_off` | 꺼진 역할 이름 목록 |
| `local` | 개인 레이어가 정한 값 `{"<점으로 이은 키>": <값>}`. 파일이 없거나 성립하지 않으면 `{}` |
| `local_error` | 개인 레이어가 성립하지 않을 때 그 오류의 첫 줄. 성립하면 키가 없다 |

- `checks` 의 항목마다 `source`(레이어 id) · `same_as_below`(참 · 거짓) · `locked`(참 · 거짓)를 더한다
- `roles.<역할>.follows_orchestrator` 는 러너가 오케스트레이터와 같은 역할에 더해 `inproc` 역할도 참이다(7-7)
- `base_protected` 는 `inherited_items["docs.protected"]` 와 같은 값이다
- `config_notes` 는 프로젝트 파일이 아니라 내장 기본값 파일의 주석에서 읽는다
- 전체 값 사본을 줄이는 것은 사람이 한다. `same_as_below` 가 그 판단의 근거이고, 하네스는 프로젝트 레이어의 줄을 지우는 명령을 두지 않는다

## 11. `harness doctor`

`config` 절에 아래 항목을 더하거나 바꾼다. 역할 · 불변식 · 모델 항목은 실효 설정으로, `generated files` 절은 공유 설정으로 본다.

| 상황 | 상태 | 항목 |
|---|---|---|
| 개인 레이어가 있고 성립한다 | ok | `harness.local.toml sets <키들>` |
| 개인 레이어가 성립하지 않는다 | bad | `harness.local.toml is not valid` — 상세에 오류 첫 줄. 나머지 항목은 공유 설정으로 본다 |
| 개인 파일이 있는데 git 이 무시하지 않는다 | warn | `harness.local.toml is not ignored by git` — 상세에 `info/exclude` 에 줄을 더하는 명령 |
| 개인 파일이 git 인덱스에 있다 | bad | `harness.local.toml is tracked by git` — 상세에 `git rm --cached harness.local.toml` |
| 실효 설정이 불변식을 어긴다 | bad | `<구현 역할> and <리뷰 역할> run on the same runner (<벤더>) on this machine` |
| 공유 설정의 `inproc` 역할에 모델이 있다 | warn | `roles.<역할>.model = <값> is not used` — 상세 `<역할> runs as a subagent, so it uses harness.model` |
| 5-2 의 판정에 걸린다 | bad (`generated files` 절) | `role <역할> comes back on from the built-in defaults` — 상세에 5-2 의 `harness set` 명령 |
| 꺼진 역할을 가리키는 남은 참조 | warn | `role \`<역할>\` is off in the config` (5-1) |

지금의 "러너가 오케스트레이터와 같은 역할의 모델" 경고 · 오케스트레이터 능력 경고 · 모델 판정(`model_ok`)은 실효 설정으로 본다.

## 12. UI

- **값은 `harness schema` 의 `config` 로 읽는다.** `readConfig()` 가 `harness.toml` 을 직접 파싱하던 자리(홈 카드 · 설정 화면 · 문서 검사의 오케스트레이터)는
  schema 를 쓴다. schema 에 `config` 가 없는 옛 고정 사본이면 지금처럼 파일을 읽는다
- 설정 화면(`app/[project]/settings`)은 값마다 출처 표시를 단다 — `sources` 의 레이어 id 를 사람이 읽는 이름(`기본값` · `preset` · `프로젝트`)으로 보인다
- `same_as_below` 인 값에는 "기본값과 같습니다 — 이 줄을 지우면 기본값을 따릅니다" 를 보인다
- 잠긴 값은 읽기 전용으로 그리고 잠근 레이어를 보인다
- 개인 레이어가 덮는 값(`local`)에는 "이 기기에서는 `<값>` (harness.local.toml)" 을 함께 보인다. Agents 화면도 역할의 러너 · 모델에 같은 표시를 단다.
  `local_error` 가 있으면 설정 화면 머리에 그 오류를 보인다
- 보호 목록 입력의 뺄 수 없는 항목은 `inherited_items` 로 그린다
- 서브에이전트 역할도 `follows_orchestrator` 로 그린다 — 모델을 고르게 하지 않는다(7-7)
- UI 의 쓰기는 지금처럼 플래그 없는 `harness set`(프로젝트 레이어)이다. UI 에서 개인 레이어를 쓰거나 역할을 끄고 켜는 조작은 두지 않는다
- 레이어 id → 표시 이름은 `src/ui/lib/labels.js` 의 순수 함수가 한다
- `src/ui/lib/doctor.js` 에 11절 항목의 한국어 문구를 더하고, 바뀐 남은 참조 문구(`is off in the config`)를 읽는다
- `src/ui/lib/help.js` 의 `harness.orchestrator` · `harness.model` 도움말에 "사람마다 다르게 쓰려면 harness.local.toml" 을 더한다

## 13. 문서와 명령 도움말

| 문서 | 반영할 사실 |
|---|---|
| `README.md` | 새 절 "설정 레이어" — 레이어 순서와 파일, 병합 규칙 표, `locked`, 개인 레이어(받는 키 · 실행 방식 유지 · 무시 보장 · 추적 금지 · `set --local`), `run-plan`. "`harness.toml` 이 정하는 것" 표에 `roles.<역할>.enabled` 행, `roles.<역할>.runner · model · access` 행에서 모델 · 벤더가 생성물에 들어가지 않고 실행 계획으로 간다는 것, `doctor.remote_timeout` 행의 `script/harness.plan.json` 을 실행 계획으로. 그 아래 실행 계획 문단과 "파일은 세 부류다" 의 생성 목록에서 `script/harness.plan.json` 을 뺀다. "시작하기" 의 "설정이 없으면 기본값을 깔아" 를 최소 설정으로 |
| `src/templates/managed/docs/workflow/README.md` · `changing.md` · `flow.md` | "값의 정본은 `harness.toml` 하나" 를 "프로젝트 값은 `harness.toml`, 기본값은 내장 기본값, 개인 선택은 `harness.local.toml`" 로. `changing.md` 의 역할 삭제를 `harness set roles.<이름>.enabled false` 로, 역할별 모델 행에 서브에이전트 역할은 오케스트레이터 모델을 쓴다는 것을 |
| `src/templates/managed/script/README.md` | `run-agent.py` 행의 "실행 계획(`harness.plan.json`)" 을 "고정 사본 CLI 의 `run-plan`" 으로. `metric.py` 행에 지표 설정을 `run-plan` 에서 받는다는 것을 |
| `src/templates/generated/.ai/AI_AGENT.md` | 10장 배치 표의 `harness.toml` 행을 "프로젝트 레이어 — 기본값과 다르게 정하는 규칙 값" 으로, `harness.local.toml`(개인 레이어, 커밋하지 않는다) 행과 내장 기본값(고정 사본의 `templates/defaults.toml`, 고치지 않는다) 행을 더한다. 9장 문서 지도의 `harness.toml` 행에 값마다의 출처는 `harness schema` 라는 것을 |
| 명령 도움말(`harness help`) | `set` 의 인수 `[--local] <section.key> <value> ...`, 새 줄 `run-plan` — `the run plan for this machine as JSON: how each role runs, and the metrics settings`. 끝 문단을 `Values live in layers: the built-in defaults, presets, harness.toml, and harness.local.toml (this machine only).` 로 |

역할 계약(`.ai/templates/`)과 절차 조각은 바뀌지 않는다. 생성 파일 머리의 "이 파일은 harness.toml 에서 생성된다" 문구는 그대로 둔다 — 프로젝트가
값을 고치는 자리는 여전히 `harness.toml` 이다.

## 14. 회귀 테스트

### 14-1. 단위 테스트 — `src/test/unit/`

#206 이 둔 단위 테스트 자리(`python3 -m unittest`, 소스 리포 전용)에 설정 패키지의 순수 함수를 레이어를 직접 넣어 본다.

| 케이스 | 확인하는 것 |
|---|---|
| 스칼라 | 위 레이어 값이 이기고, 위에 없으면 아래 값이 남는다 |
| 테이블 | `issues.labels` 의 키 하나만 위 레이어에 있으면 나머지 키는 아래 값이다 |
| 배열 | `commit.tags` 는 위 레이어 배열로 통째 바뀐다 |
| 보호 목록 | 위 레이어가 아래 항목을 빠뜨려도 남고, 위에만 있는 항목은 뒤에 붙고, 중복이 없고, 순서가 3-2 대로다 |
| `verify.checks` | 같은 `name` 은 위 항목으로 아래 자리에서 바뀌고, 새 이름은 뒤에 붙는다 |
| 절차 | 위 레이어의 `[workflows.work]` 가 단계를 줄이면 그 단계만 남고, 위에 없는 절차는 아래 것이다 |
| 형이 다른 값 | 테이블 · 배열 대 다른 형은 3-5 오류다 |
| 잠금 | 같은 값은 받고 다른 값은 4-3 오류다. 잠긴 검사 항목도 같다. 프로젝트 · 개인의 `locked` 선언, 스칼라가 아닌 경로, 개인 키 잠금이 4-2 오류다 |
| 출처 | `sources` · `same_as_below` · `inherited_items` 가 레이어 구성대로 나온다 |
| 개인 레이어 | 받는 키 넷만 받고, 실행 방식을 바꾸는 러너 · 꺼진 역할 · 서브에이전트 역할의 모델이 6-2 오류다 |
| 역할 끄기 | `enabled = false` 인 역할이 병합 결과의 `roles` 에 없다 |
| 실행 계획 | 같은 공유 설정에 개인 레이어만 다르게 넣으면 실행 계획의 `vendor` · `label` · `model` · `argv` 가 개인 값을 따르고, 서브에이전트 역할의 `model` 이 `harness.model` 이다 |

### 14-2. `render-test.sh` — 새 케이스

| 케이스 | 확인하는 것 |
|---|---|
| 최소 설정 설치 | 빈 리포에 `install` 하면 `harness.toml` 이 2-4 의 내용(이름 채움)이고, 생성 파일이 같은 이름의 내장 기본값 전체 사본으로 렌더한 것과 같다 |
| 전체 값 사본 호환 | 레이어 이전 형식의 전체 값 사본이 그대로 렌더되고, 같은 값을 최소 설정 + 몇 줄로 적은 설정과 생성 파일이 같다 |
| 레이어 병합 끝까지 | 최소 설정에 `commit.tags` 만 적으면 commit-msg 검사식이 그 태그만 받고, `docs.protected` 에 하나를 더하면 기본 여섯 항목과 함께 가드 · deny 에 들어간다 |
| 잠금 | 소스 트리를 복제해 내장 기본값 사본에 `locked = ["review.max_rounds"]` 를 넣으면, 같은 값을 적은 프로젝트는 렌더되고 다른 값은 4-3 오류로 거부되며 파일이 바뀌지 않는다 |
| 개인 레이어는 생성물에 닿지 않는다 | 오케스트레이터 · 리뷰어 러너 · 모델을 바꾼 `harness.local.toml` 을 두고 render 하면 생성 파일이 파일 없이 렌더한 것과 바이트까지 같고 `check` 가 통과한다. 파일을 깨뜨려도 render · check 가 통과한다 |
| 개인 레이어 거부 | 받지 않는 키 · 실행 방식 변경 · 서브에이전트 역할의 모델이 든 개인 파일이면 `run-plan` 과 `run --dry-run` 이 종료 코드 2 와 6-2 오류를 낸다 |
| 실행 시점 불변식 | 공유 설정은 성립하고 개인 오케스트레이터가 리뷰어와 같은 러너를 만들면 render · check 는 통과하고 `run-plan` · `run --dry-run` · `set --local` 이 8절 오류로 거부한다 |
| `run --dry-run` | 출력된 명령이 개인 레이어의 오케스트레이터와 모델을 쓴다 |
| `run-plan` 출력 | 7-1 의 필드가 있고 `metrics.dir` 이 설정 값 그대로다. 개인 레이어의 러너 · 모델이 반영된다 |
| `set --local` | 파일을 만들고 `info/exclude` 에 줄을 적어 `git check-ignore` 가 무시한다고 답한다. 생성 파일과 매니페스트가 바뀌지 않는다. 검증에 걸리면 파일이 남지 않는다. 받지 않는 키면 아무것도 쓰지 않는다 |
| `install` 의 무시 줄 | 설치한 리포에서 손으로 만든 `harness.local.toml` 이 `git status --porcelain` 에 나오지 않는다. 다시 설치해도 줄이 겹치지 않는다. 모노레포 서브프로젝트면 줄에 리포 안의 위치가 붙는다 |
| 추적 금지 | 개인 파일을 `git add` 하면 `check` · `check --staged` 가 6-4 오류로 실패하고 pre-commit 이 커밋을 막는다 |
| doctor | 무시되지 않는 개인 파일 · 추적되는 개인 파일 · 깨진 개인 파일 · 실효 불변식 위반이 11절 항목으로 나온다. 깨진 개인 파일이어도 doctor 가 끝까지 돈다 |
| worktree 로 옮기기 | `worktree.include = []` 인 리포에서 `run --worktree` 가 개인 파일을 worktree 실행 디렉터리로 복사하고, 복사 뒤 그 worktree 의 `git status --porcelain` 이 비어 있다 |
| 생성물에 개인 의존 값이 없다 | 어댑터 두 형식에 모델 줄이 없고, `script/harness.env` 에 `REVIEWER_LABEL` 이 없고, CLI 러너 단계의 절차 문서 제목이 `CLI 러너로 실행` 이며 벤더 이름(`Codex CLI` · `Claude Code`)이 없다 |
| `script/harness.plan.json` 걷기 | 직전 매니페스트에 그 파일이 있는 리포를 render 하면 파일이 지워지고 매니페스트에서 빠진다 |
| 지운 역할 | 직전 매니페스트에 `script/harness.plan.json` 이 있고 역할 하나의 어댑터가 없는 전체 값 사본이면 render 가 5-2 오류로 멈추고 아무것도 쓰지 않는다. `set roles.<역할>.enabled false` 가 역할 절을 더하며 통과하고, 그 뒤 render 는 판정하지 않는다 |
| `set` 이 키를 더한다 | 최소 설정에 `set review.max_rounds 7` 이 `[review]` 절을 더하고, `set roles.code-reviewer.model x` 가 `[roles.code-reviewer]` 절을 더한다. 없는 키는 거부한다. 깨진 개인 파일이 있어도 프로젝트 레이어 `set` 은 돈다 |
| schema | `config` · `layers` · `sources` · `same_as_below` · `locked` · `inherited_items` · `roles_off` · `local` · `local_error` 가 10절 대로다 |

### 14-3. `render-test.sh` — 바뀌는 기존 케이스

- 대상 설정을 만들 때 값을 `sed` 로 바꾸는 케이스는 내장 기본값 파일 사본(전체 값 사본)을 프로젝트 설정으로 쓴다. 배포되는 기본값을 보는 케이스(UT-00)는 `templates/defaults.toml` 을 본다
- 역할을 빼는 케이스(UT-29 · UT-32)는 역할 표를 지우는 대신 `roles.<역할>.enabled = false` 로 끄고, 계약 · 어댑터 · 커맨드 · 자산 표의 행이 함께 빠지는 기대값은 그대로다
- `script/harness.plan.json` 을 읽거나 고치던 케이스(실행 계획의 argv · entry · via, 지표 경로, `auth_check` · `auth_timeout`)는 `harness run-plan` 출력을 본다. 실행 계획 값을 바꿔 보던 케이스는 고정 사본의 벤더 선언 사본을 고쳐 같은 상황을 만들고, 깨진 `auth_timeout` 은 7-3 의 `the run plan … is broken` 을 페이크 CLI 로 본다
- 어댑터의 모델을 보던 케이스는 모델 줄이 없음을 본다. CLI 러너 단계 제목의 벤더 이름을 보던 케이스는 `CLI 러너로 실행` 을 본다
- 고정 사본 대조 케이스의 목록에 `.harness/templates/defaults.toml` 이 든다. 버전 번호는 내장 기본값 파일에서 읽는다
- 늘 보호되는 문서 목록을 CLI 코드의 상수에서 읽던 케이스는 내장 기본값 파일의 `docs.protected` 를 읽는다

### 14-4. `test-review-loop.sh`

- 실행 계획 파일 사본 대신 샌드박스 리포에 페이크 CLI(`.harness/bin/harness`)를 둔다. `run-plan` 에 샌드박스의 실행 계획 JSON(지표 경로 · 스텁 로그인 확인 · `label`)을 내고, 케이스가 그 JSON 을 바꿔 리뷰 러너 준비 상태를 만든다
- 스텁으로 갈아끼울 리뷰 도구의 이름은 실제 설치본의 `harness run-plan` 출력에서 읽는다
- `review-mr.sh` 가 실행 계획의 `label` 을 등록의 작성자 표시로 넘기는 것, 실행 계획을 받지 못하면 회차 라벨을 올리지 않고 종료 코드 2 인 것을 본다
- 기존 케이스의 기대값(종료 코드 · 라벨 · 등록 내용)은 그대로다

### 14-5. UI 단위 테스트

- `src/ui/lib/labels.test.js` — 레이어 id 를 표시 이름으로 바꾸는 함수
- `src/ui/lib/doctor.test.js` — 11절 항목의 문구. 원격 점검 제한 시간의 기본값을 CLI 코드의 상수에서 읽던 검사는 내장 기본값 파일의 `doctor.remote_timeout` 을 읽는다

회귀 테스트 전체(`script/run-lint-test.sh`)가 통과한다.

## 15. 결정 기록

결정 기록: 설정은 계층으로 해석한다 (분해에서 작성)

## 16. 보호 문서 개정 범위

분해의 task 하나가 아래 범위 안에서만 고친다. 그 뒤 `harness render` 로 `.ai/AI_AGENT.md` 를 다시 만든다.

### 16-1. `.ai/project/scope.md`

| 위치 | 지금 | 고친 문안 |
|---|---|---|
| 첫 목록 둘째 항목 | 설정 파일 하나(`harness.toml`)와 프로젝트 사실(`.ai/project/`)에서 | 계층으로 해석하는 설정(내장 기본값 ← preset ← 프로젝트 `harness.toml` ← 개인 `harness.local.toml`)과 프로젝트 사실(`.ai/project/`)에서 |
| "사용자" 첫 항목 | `harness install` 로 깔고 `harness.toml` 과 `.ai/project/` 로 자기 값을 채운다 | `harness install` 로 깔고 `harness.toml` 에 기본값과 다른 프로젝트 값만 적고 `.ai/project/` 로 사실을 채운다. 사람마다 다른 에이전트 CLI·모델은 커밋하지 않는 `harness.local.toml` 에 둔다 |
| "사용자" 셋째 항목 | 루트 `harness.toml` 이 이 리포의 설정이고, 대상 리포로 복사되는 기본값은 `src/templates/harness.toml` 이다 | 루트 `harness.toml` 이 이 리포의 프로젝트 레이어이고, 내장 기본값은 `src/templates/defaults.toml`, 설치가 새 프로젝트에 까는 최소 설정은 `src/templates/harness.toml` 이다 |
| "할 수 있는 일" 둘째 항목 끝 | — | 이 기기의 개인 선택은 `set --local` 로 쓴다 |
| "할 수 있는 일" `run` 항목 끝 | — | 역할마다 이 기기에서 무엇을 어떻게 띄우는지 실행 시점에 해석해 낸다 (`run-plan`) |

### 16-2. `.ai/project/glossary.md`

"용어" 표:

| 표기 | 고친 뜻 |
|---|---|
| 생성 파일 | 공유 설정에서 나오는 파일. 고치지 않고 `render` 로 다시 만든다 |
| 정본 | 어떤 값·규칙을 고칠 때 손대는 유일한 자리. 프로젝트의 규칙 값은 `harness.toml`, 기본값은 내장 기본값, 개인 선택은 `harness.local.toml`, 프로젝트 사실은 `.ai/project/` |
| 실행 계획 | 역할마다 무엇을 어떻게 띄우는지 실효 설정에서 실행 시점에 해석한 표. `harness run-plan` 이 내고 `run-agent.py` · `review-mr.sh` · `metric.py` 가 읽는다. 파일로 남기지 않는다 |

"용어" 표에 더할 행:

| 표기 | 뜻 |
|---|---|
| 레이어 | 설정을 이루는 TOML 한 겹. 아래부터 내장 기본값 · preset · 프로젝트(`harness.toml`) · 개인(`harness.local.toml`). 위 레이어가 아래를 병합 규칙대로 덮는다 |
| 내장 기본값 | 하네스가 싣고 오는 가장 아래 레이어 (`src/templates/defaults.toml`, 고정 사본의 `.harness/templates/defaults.toml`) |
| 개인 레이어 | 사람마다 다른 선택(오케스트레이터·러너·모델)만 담는 레이어 (`harness.local.toml`). 커밋하지 않고, render · check 가 읽지 않는다 |
| 공유 설정 | 개인 레이어를 뺀 레이어들을 병합한 설정. 모든 클론과 CI 에서 같다 |
| 실효 설정 | 공유 설정에 개인 레이어를 더한 설정. 실행(`run` · `run-plan`)과 점검이 읽는다 |
| 병합 규칙 | 키마다 하네스가 고정한 레이어 병합 방식 — 덮어쓰기 · 깊은 병합 · 교체 · 합집합 · 이름 병합 · 통째 교체 |
| 잠금 | 내장 기본값이나 preset 이 `locked` 로 지정한 값. 위 레이어가 다른 값을 적으면 거부한다 |
| 실행 방식 | 역할이 도는 방식 — 서브에이전트(`inproc`) 또는 CLI 러너. 공유 설정이 정하고 개인 레이어는 바꾸지 못한다 |

"폐기된 별칭" 표:

| 옛 표기 | 정식 이름 |
|---|---|
| 루트 `harness.toml` · `src/templates/harness.toml` 을 기본값으로 부르는 것 (지금 행 "루트 `harness.toml` (대상 리포로 복사되는 기본값)" 을 바꾼다) | 내장 기본값 `src/templates/defaults.toml`. `src/templates/harness.toml` 은 설치가 까는 최소 설정이고, 루트의 것은 이 리포 자신의 프로젝트 레이어 |
| `.harness/harness.toml` · `.harness/templates/harness.toml` (설치본의 기본 설정) (지금 행을 바꾼다) | `.harness/templates/defaults.toml` |
| `script/harness.plan.json` (커밋되는 실행 계획) | `harness run-plan` 의 출력 |
| 역할 표를 지워 역할 빼기 | `roles.<역할>.enabled = false` |

### 16-3. `.ai/project/architecture.md`

| 위치 | 반영할 사실 |
|---|---|
| "구성 요소" 의 CLI 항목 | 설정은 레이어로 읽어 병합 규칙 표대로 합치고 공유 설정과 실효 설정을 따로 낸다. 실행 계획은 실행 시점에 실효 설정에서 계산한다(`run-plan`) |
| "구성 요소" 의 `src/templates/` 항목 | `harness.toml`(기본 설정) → `defaults.toml`(내장 기본값 레이어 — 키마다 기본값과 설명) · `harness.toml`(설치가 까는 최소 설정) |
| "데이터 흐름" 의 렌더 | `harness.toml` + `.ai/project/` → 공유 설정(내장 기본값 ← preset ← `harness.toml`) + `.ai/project/`. 생성 파일 목록에서 `script/harness.plan.json` 을 뺀다. 개인 레이어는 읽지 않는다 |
| "데이터 흐름" 의 절차 실행 | "`script/run-agent.py` 가 실행 계획대로 띄운 CLI" → "`script/run-agent.py` 가 고정 사본 CLI 의 `run-plan` 으로 받은 실행 계획대로 띄운 CLI". `review-mr.sh` 의 단계에 실행 계획 조회를 더한다. `harness run` 은 실효 설정의 오케스트레이터로 띄우고, worktree 에 개인 레이어 파일을 옮긴다 |
| "데이터 흐름" 의 실행 지표 | `script/metric.py` 는 지표 설정을 `run-plan` 에서 받는다 |
| "신뢰 경계" 의 들어오는 입력 | `harness.local.toml`(개인 레이어 — 받는 키 넷과 실행 방식 유지만 받고 어기면 그것을 읽는 명령이 거부한다. git 이 무시하도록 `info/exclude` 에 적고, 커밋되면 `check` 가 거부한다) |
| "새 코드를 둘 곳" 의 새 설정 키 | `src/templates/harness.toml` 의 주석과 기본값 → `src/templates/defaults.toml` 의 주석과 기본값(기본 규칙과 다르게 병합하면 병합 규칙 표에도). 개인 레이어에 여는 키면 개인 레이어의 받는 키 목록에도 |
| "새 코드를 둘 곳" 의 새 역할 | `src/templates/harness.toml` 의 `[roles.<역할>]` → `src/templates/defaults.toml` 의 `[roles.<역할>]` |
| "계층과 의존 방향" | "규칙 값은 `harness.toml` 에서 생성물로 내려간다. … 생성물(`script/harness.env` · `script/harness.plan.json` · `script/forge.sh`)에서 받는다" → "규칙 값은 공유 설정에서 생성물로 내려간다. 개인 레이어 값은 생성물에 들어가지 않는다. 대상 리포의 스크립트·훅·가드는 값을 하드코딩하지 않고 생성물(`script/harness.env` · `script/forge.sh`)에서, 역할의 실행 방법과 지표 설정은 고정 사본 CLI 의 `run-plan` 에서 실행할 때 받는다" |
| "검사하지 않는 것" | render · check 는 개인 레이어를 읽지 않는다. 개인 선택으로만 생기는 불변식 위반은 실행 시점(`run` · `run-plan`)에야 드러난다 |

### 16-4. `.ai/project/testing.md`

| 위치 | 지금 | 고친 문안 |
|---|---|---|
| "무엇을 어느 수준으로 검증하나" 첫 항목의 셋째 약속 | 불변식 위반과 성립하지 않는 조합이 `render` 를 막는가 | 불변식 위반과 성립하지 않는 조합이 공유 설정이면 `render` 를, 개인 레이어를 더한 실효 설정이면 실행(`run` · `run-plan`)을 막는가. 개인 레이어가 생성 파일과 `check` 결과를 바꾸지 않는가 |
| 같은 절에 더할 항목 | — | 레이어 병합 규칙 · 잠금 · 개인 레이어 판정은 `src/test/unit/` 의 단위 테스트가 레이어를 직접 넣어 본다 |

## 17. 범위 밖과 한계

범위 밖:

- preset 레이어를 채우는 일 — `extends` 해석, preset 받기 · lock · `harness pull`, preset 이 선언하는 잠금의 실제 사용 (#216 이후)
- 절차 확장 지점(빈 하위 절차)과 절차 블록 엔진 (#208)
- 전체 값 사본을 최소 설정으로 줄이는 쓰기 명령. 이 명세는 `schema` 의 `same_as_below` 로 읽기 보고만 한다
- UI 에서 개인 레이어 값을 쓰거나 역할을 끄고 켜는 조작

한계:

- 스크립트로 도는 역할 실행기 · 리뷰 루프 · 지표 기록기는 실행 계획이 필요할 때마다 고정 사본 CLI 를 한 번 띄운다. 지표 기록기는 기록하는 프로세스마다 한 번이다
- 서브에이전트 역할은 역할마다 모델을 고를 수 없다. 오케스트레이터 모델 하나로 돈다
- 전체 값 사본에서 지운 테이블 키는 아래 레이어 값으로 채워진다. 지운 것을 판정해 멈추는 것은 역할(5-2) 하나다
- 아래 레이어의 `verify.checks` 항목과 보호 목록 항목을 위 레이어가 빼는 표기는 없다
- 개인 레이어의 키를 지우는 명령이 없다 — 파일에서 그 줄을 지운다
- `harness uninstall` 은 `info/exclude` 에 적은 줄을 지우지 않는다
- render · check 가 개인 레이어를 읽지 않으므로, 개인 선택으로만 성립하지 않는 조합은 실행할 때 드러난다
