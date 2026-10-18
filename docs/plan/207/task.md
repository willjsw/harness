# #207 task

## T1 · feat: roles.<역할>.enabled 로 역할을 끄고 켬

### 상위 Requirement

- relates to #207

### 작업 내용

역할마다 켜고 끄는 참 · 거짓 키를 둔다. 꺼진 역할은 설정에 없는 역할과 같다. 레이어 병합(T3) 아래서는 역할 표를 지워도 내장 기본값이
그 역할을 되살리므로, 그보다 먼저 끄는 방식을 넣고 역할 표 삭제에 기대던 회귀 케이스를 이 방식으로 옮긴다.

- 명세 5-1 · 3-6 셋째 항목 · 14-3 둘째 항목(UT-29 · UT-32)
- `src/harness/config/load.py`
  - `validate()`: `roles.<역할>.enabled` 가 참 · 거짓이 아니면 `error: roles.<역할>.enabled must be true or false (got <값>)`
  - 설정을 읽은 직후 `enabled = false` 인 역할을 `roles` 에서 뺀다. 키가 없는 역할은 켜져 있다. 그 뒤의 검증 · 생성 · `schema` 의 역할 표는
    켜진 역할만 본다 — 계약 · 어댑터 두 형식 · 그 역할 전용 커맨드 · 자산 표 행이 만들어지지 않고, 지난 render 가 만든 것은 정리된다
- `src/harness/config/agents.py`: `harness set` 이 역할 절에 처음 정할 때 더하는 키(`OPTIONAL_ROLE_KEYS`)에 `enabled` 를 더한다 —
  `harness set roles.<역할>.enabled <true|false>` 가 역할을 끄고 켠다
- 꺼진 역할을 부르는 `agent` 단계는 지금처럼 `is not a configured role` 로 거부된다
- `src/harness/readiness/refs.py` `dangling_roles()`: 설정에 없거나 꺼진 역할을 같은 "없는 역할" 로 보고, 설정 파일(`harness.toml` ·
  `harness.local.toml`)은 훑지 않는다. `src/harness/readiness/items.py` 의 항목 문구를 `role \`<역할>\` is off in the config` 로 바꾼다
- render-test
  - UT-29 · UT-32 가 역할 표를 지우는 대신 `harness set roles.<역할>.enabled false` 로 역할을 끈다. 계약 · 어댑터 · 커맨드 · 자산 표 행이
    빠지는 기대값은 그대로, UT-29 의 남은 참조 문구 기대값은 `is off in the config` 로 바꾼다
  - 새 케이스: 다시 켜면 파일이 돌아온다, 형 오류, 꺼진 역할을 부르는 단계 거부, 끄는 줄이 든 `harness.toml` 을 남은 참조로 알리지 않는다
- 건드릴 파일: `src/harness/config/load.py` · `agents.py`, `src/harness/readiness/refs.py` · `items.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] `harness set roles.security-guard.enabled false` 가 역할 절에 줄을 더하고, render 뒤 그 역할의 계약 · 어댑터 두 형식 · 커맨드 · 자산 표 행이 없다
- [ ] 같은 역할을 `enabled true` 로 되돌려 render 하면 그 파일들이 다시 생긴다
- [ ] `enabled = "no"` 인 설정이면 render 가 종료 코드 2 와 명세 5-1 의 오류를 낸다
- [ ] 꺼진 역할을 부르는 `agent` 단계가 `is not a configured role` 로 거부된다
- [ ] doctor 가 꺼진 역할을 부르는 문서 자리를 `role \`<역할>\` is off in the config` 로 알리고, 끄는 줄이 든 `harness.toml` 은 알리지 않는다
- [ ] UT-29 · UT-32 가 역할 표를 지우지 않고 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 역할 끄기 | 전체 값 사본에 `set roles.security-guard.enabled false` 뒤 render | 계약 · 어댑터 두 형식 · 커맨드 · 자산 표 행 없음 |
| UT-02 | 다시 켜기 | 이어서 `set roles.security-guard.enabled true` 뒤 render | 네 가지가 다시 있음 |
| UT-03 | 형 오류 | `enabled = "no"` | 종료 코드 2, `must be true or false (got` |
| UT-04 | 꺼진 역할을 부르는 단계 | 꺼진 역할을 `role` 로 둔 `agent` 단계의 `steps --dry-run` | 종료 코드 2, `is not a configured role` |
| UT-05 | 남은 참조 | `docs-writer` 를 끄고 `scope.md` 에 그 이름을 적은 뒤 doctor | `role \`docs-writer\` is off in the config`, `harness.toml` 은 항목에 없음 |

## T2 · feat: 레이어 병합 규칙 표와 병합 · 출처 함수

### 상위 Requirement

- relates to #207

### 작업 내용

레이어 목록(아래 → 위)을 받아 키마다 고정된 규칙으로 합치는 순수 함수와, 값마다 그 값을 마지막으로 정한 레이어를 계산하는 함수를
`src/harness/config/layers.py` 에 둔다. 설정을 읽는 자리에는 아직 잇지 않는다 — 잇는 것은 T3 이다.

- 명세 2-1 넷째 항목 · 2-5 · 3-1 ~ 3-5 · 10 의 `sources` 규칙 · 14-1 의 스칼라 · 테이블 · 배열 · 보호 목록 · `verify.checks` · 절차 · 형이 다른 값 · 출처
- 레이어 하나는 id · 경로 · 읽은 값이다. 목록은 내장 기본값, preset 들(먼 조상이 아래), 프로젝트, 개인 순서이고, 규칙은 목록 단위로
  레이어마다 차례로 적용된다. 이 task 는 개인 레이어의 받는 키를 보지 않는다(T9)
- 병합 규칙 표(명세 3-1)
  - `docs.protected` · `branches.protected` — 합집합. 아래 항목을 그 순서대로 두고 위에만 있는 항목을 뒤에 붙인다. 중복은 한 번(3-2)
  - `verify.checks` — `name` 으로 짝짓는다. 같은 이름은 위 항목 전체가 아래 자리에서 대신하고, 새 이름은 위 레이어 순서대로 뒤에 붙는다(3-3)
  - `workflows.<이름>` — 절차 하나를 통째로 교체한다. 위에 없는 절차는 아래 것이 남는다(3-4)
  - 그 밖의 테이블(인라인 테이블 포함) — 키 단위 깊은 병합. 그 밖의 배열 — 통째 교체. 스칼라 — 덮어쓰기
- 형이 다른 값(3-5): 한 레이어는 테이블이고 다른 레이어는 테이블이 아니거나, 배열 대 배열이 아니면 명세의 `error:` · `-->` 형식으로 멈춘다.
  레이어 표시는 내장 기본값 `the built-in defaults`, 그 밖은 파일 이름(`harness.toml` · `harness.local.toml`). 스칼라끼리의 형 차이는 덮어쓴다
- 최상위 `locked` 는 병합 결과에 넣지 않는다. `verify.checks` 항목 안의 `locked` 는 항목의 키로 함께 옮긴다 — 잠금 선언 검사와 판정은 T6 이다
- 출처: 점으로 이은 키마다 레이어 id. 테이블은 안의 값까지 내려가고, 배열과 `workflows.<이름>` 은 한 값이며, 보호 목록은 항목을 더한 가장 위 레이어다
- 단위 테스트: `src/test/unit/test_layers.py`
- 건드릴 파일: `src/harness/config/layers.py`(신규), `src/test/unit/test_layers.py`(신규)

### 완료 조건

- [ ] 명세 14-1 의 스칼라 · 테이블 · 배열 · 보호 목록 · `verify.checks` · 절차 · 형이 다른 값 케이스가 레이어를 값으로 넣은 단위 테스트로 통과한다
- [ ] 출처가 명세 10 의 `sources` 규칙대로 나온다
- [ ] 가운데에 preset 자리 레이어를 둔 셋 이상의 목록에도 같은 규칙이 레이어마다 차례로 적용된다
- [ ] 최상위 `locked` 가 병합 결과에 없다
- [ ] 설정을 읽는 코드가 바뀌지 않아 회귀 테스트의 기대값이 그대로 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 스칼라 | 아래 `review.max_rounds = 5`, 위 `7` / 위에 없음 | `7` / `5` |
| UT-02 | 테이블 | 위 레이어에 `issues.labels.task` 하나만 | `task` 만 위 값, 나머지 키는 아래 값 |
| UT-03 | 배열 | 위 레이어 `commit.tags = ["feat"]` | `["feat"]` |
| UT-04 | 보호 목록 | 아래 `[a, b]`, 위 `[c, a]` | `[a, b, c]` — 아래 항목이 빠지지 않고 위에만 있는 항목이 뒤에, 중복 없음 |
| UT-05 | `verify.checks` | 아래 `x` · `y`, 위 `y`(다른 `run`) · `z` | `x` · 위의 `y`(아래 자리) · `z` |
| UT-06 | 절차 | 위 `[workflows.work]` 가 단계 하나, 위에 `prework` 없음 | `work` 는 그 단계 하나, `prework` 는 아래 것 |
| UT-07 | 형이 다른 값 | 아래 `roles.code-reviewer` 테이블, 위 문자열 / 아래 배열, 위 문자열 | 3-5 의 오류, 레이어 표시와 `-->` 경로 |
| UT-08 | 출처 | 기본값 · preset 자리 · 프로젝트에 나눠 적은 값 | 키마다 마지막으로 정한 레이어 id. 보호 목록은 항목을 더한 가장 위 레이어 |
| UT-09 | `locked` 는 값이 아님 | 아래 레이어에 최상위 `locked` | 병합 결과에 `locked` 없음 |

## T3 · feat: 내장 기본값 파일을 가장 아래 레이어로 두고 설정을 레이어 병합으로 읽음

### 상위 Requirement

- relates to #207

### 작업 내용

지금 기본 설정의 값과 주석을 내장 기본값 파일로 옮기고, 설정을 읽는 모든 자리가 내장 기본값 ← preset(빈 목록) ← 프로젝트를 병합한
공유 설정을 쓰게 한다. 기본값의 정본은 그 파일 하나이고 코드 상수로 기본값을 채우지 않는다. 설치가 까는 파일은 바꾸지 않는다 — 전체 값
사본이 같은 생성 파일을 만들므로 기존 회귀 케이스가 고치지 않고 통과한다.

- 명세 1절 · 2-1 ~ 2-3 · 2-5 · 3-6 · 14-1 역할 끄기 · 14-2 의 "전체 값 사본 호환" · "레이어 병합 끝까지" · 14-3 다섯째 · 여섯째 항목 · 14-5 둘째 항목
- `src/templates/defaults.toml`(신규): 지금 `src/templates/harness.toml` 의 값과 키마다의 주석을 옮기고 명세 2-3 표대로 고친다
  - 머리 주석, `project.name = ""`, `branches.protected = []`, `docs.protected` 여섯 항목, 역할마다 `enabled = true` · `model = ""`
  - `harness.model` · `[commands]` · `[verify]` · `[metrics]` · `[worktree]` · `[permissions]` · `[doctor]` · `forge.templates` 는 지금 코드 상수와 같은 값
  - 나머지 키는 지금 값 그대로. `locked` 를 선언하지 않는다
- `src/harness/config/load.py`: 공유 설정을 읽는 함수 하나 — 내장 기본값 · preset(빈 목록) · 프로젝트 레이어를 읽어 T2 로 병합하고, 3-6
  파생(`branches.base` 를 보호 목록 끝에, `kind` → `type`, 꺼진 역할 빼기)을 한 뒤 검증한다
  - 프로젝트 레이어 파일이 없으면 지금처럼 `error: no config found`. 어느 레이어든 TOML 이 깨졌으면 그 파일 경로와 `error: could not parse config`
  - `project.name` 이 비면 `error: project.name is empty — set it in harness.toml`
- 설정을 읽던 모든 자리(`load` · `normalize` · `validate` 를 차례로 부르던 명령과 `loaded_config` · `seeded_config`, `set` · `steps` · `checks` 의
  다시 읽기)가 그 함수를 부른다
- 코드 상수(`VERIFY_DEFAULTS` · `METRICS_DEFAULTS` · `WORKTREE_DEFAULTS` · `PERMISSIONS_DEFAULTS` · `DOCTOR_DEFAULTS` · `FORGE_DEFAULTS` ·
  `COMMAND_KEYS` 의 빈 값)를 값의 출처로 쓰지 않는다. `normalize()` 의 `setdefault` 들, `default_workflows()`, `BASE_PROTECTED` 를 걷는다.
  T1 의 "키가 없는 역할은 켜져 있다" 코드도 걷는다 — 내장 기본값이 채운다
- 절에 정의되지 않은 키를 거부하는 검사(`[commands]` · `[verify]` · `[metrics]` · `[worktree]` · `[permissions]` · `[doctor]`)는 받을 키 목록을
  내장 기본값 파일의 그 절에서 읽는다
- `src/harness/base.py`: 기본 설정(`DEFAULT_CONFIG`)이 `TEMPLATES/defaults.toml` 이다. `harness_version()` · `source_tree()` 가 그 파일을 읽는다
- 설치가 까는 파일은 이 task 에서 바뀌지 않는다 — `seed_text()` 는 `TEMPLATES/harness.toml` 을 읽는다
- `harness schema` 의 `base_protected` 는 내장 기본값 레이어의 `docs.protected` 다
- `src/ui/lib/doctor.test.js`: 원격 점검 제한 시간 기본값을 CLI 원문의 `DOCTOR_DEFAULTS` 대신 `src/templates/defaults.toml` 의
  `doctor.remote_timeout` 에서 읽는다. `src/ui/lib/doctor.js` 의 그 상수 주석을 같은 사실로 고친다
- render-test
  - 새 블록: "전체 값 사본 호환"(레이어 이전 형식의 전체 값 사본이 렌더되고, 같은 값을 최소 설정 + 몇 줄로 적은 설정과 생성 파일이
    바이트까지 같다), "레이어 병합 끝까지"(최소 설정에 `commit.tags` 만 적으면 commit-msg 검사식이 그 태그만 받고, `docs.protected` 에
    하나를 더하면 기본 여섯 항목과 함께 가드 · deny 에 들어간다), `project.name` 이 빈 최소 설정 거부, 형이 다른 값 거부
  - 레이어 이전 형식의 사본은 케이스가 `src/templates/harness.toml` 에 기대지 않게 내장 기본값 사본에서 만든다 — 역할 절의 `enabled` 와
    서브에이전트 역할의 빈 `model` 이 없는 모양
  - 고정 사본 대조 케이스의 목록에 `.harness/templates/defaults.toml` 이 든다. 버전 번호를 내장 기본값 파일에서 읽는다
  - 늘 보호되는 문서 목록을 CLI 원문의 상수에서 읽던 케이스는 내장 기본값 파일의 `docs.protected` 를 읽는다
- 단위 테스트(`test_layers.py`): 내장 기본값과 프로젝트를 값으로 넣어 읽으면 `enabled = false` 인 역할이 결과의 `roles` 에 없다
- 건드릴 파일: `src/templates/defaults.toml`(신규), `src/harness/base.py`, `src/harness/config/load.py` · `defaults.py` · `workflows.py` ·
  `values.py`, 설정을 읽는 명령 모듈, `src/harness/commands/schema.py`, `src/test/render-test.sh`, `src/test/unit/test_layers.py`,
  `src/ui/lib/doctor.js` · `doctor.test.js`

### 완료 조건

- [ ] `src/templates/defaults.toml` 이 명세 2-3 표의 값을 갖고, 지금 기본 설정의 키마다 주석이 옮겨져 있다
- [ ] 코드 상수와 `normalize()` 의 `setdefault` 가 설정 값을 채우지 않는다. `BASE_PROTECTED` · `default_workflows()` 가 없다
- [ ] 레이어 이전 형식의 전체 값 사본과, 같은 값을 최소 설정 + 몇 줄로 적은 설정이 바이트까지 같은 생성 파일을 만든다
- [ ] 최소 설정에 적은 `commit.tags` 와 `docs.protected` 항목이 commit-msg 검사식 · 가드 · deny 에 반영된다
- [ ] `project.name` 이 빈 설정을 읽는 명령이 `error: project.name is empty` 로 멈춘다
- [ ] `harness version` 의 번호와 소스 리포 판정이 `defaults.toml` 을 읽는다. 고정 사본에 `.harness/templates/defaults.toml` 이 든다
- [ ] 이 리포의 생성 파일이 바뀌지 않는다
- [ ] 기존 회귀 케이스가 이 task 가 적은 준비부 · 상수 읽기 말고는 고치지 않고 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 역할 끄기 | 내장 기본값 + `roles.security-guard.enabled = false` 인 프로젝트 레이어 | 결과의 `roles` 에 `security-guard` 없음 |
| UT-02 | 전체 값 사본 호환 | 레이어 이전 형식의 전체 값 사본 / 같은 값의 최소 설정 + 몇 줄 | 두 render 의 생성 파일이 바이트까지 같다 |
| UT-03 | 레이어 병합 끝까지 | 최소 설정에 `commit.tags = ["feat", "docs"]` · `docs.protected` 한 항목 | commit-msg 검사식이 두 태그만, 가드 · deny 에 여섯 항목 + 한 항목 |
| UT-04 | 이름 없는 설정 | `[project]` 가 없는 최소 설정 | 종료 코드 2, `error: project.name is empty` |
| UT-05 | 형이 다른 값 | 프로젝트 레이어 `roles = "x"` | 종료 코드 2, 3-5 의 오류와 `--> harness.toml` |
| UT-06 | 깨진 레이어 | TOML 이 깨진 `harness.toml` | 종료 코드 2, `error: could not parse config` 와 그 경로 |
| UT-07 | 버전과 고정 사본 | `harness version`, install 한 리포의 `.harness/managed` | 번호가 `defaults.toml` 의 값, `.harness/templates/defaults.toml` 줄이 있음 |
| UT-08 | 늘 보호되는 문서 | 내장 기본값 파일의 `docs.protected` | 여섯 항목이 가드 · deny 에 있다 |

## T4 · chore: 회귀 테스트의 대상 설정을 내장 기본값 사본으로 만듦

### 상위 Requirement

- relates to #207

### 작업 내용

대상 설정을 `src/templates/harness.toml` 사본으로 만들거나 설치된 설정을 고쳐 쓰는 회귀 케이스를 내장 기본값 사본(이름을 채운 전체 값
사본)으로 옮긴다. 기대값은 바꾸지 않는다. T5 가 설치 파일을 최소 설정으로 바꿀 때 이 케이스들이 그 때문에 깨지지 않게 하는 준비다.

- 명세 14-3 첫째 항목
- `src/test/render-test.sh`
  - 내장 기본값 사본을 만들고 `project.name` 을 채우는 공용 도우미 하나를 둔다
  - `setup()` 과, 대상 설정을 `templates/harness.toml` 사본으로 만들던 케이스 전부가 그 도우미를 쓴다
  - install 한 뒤 설치된 `harness.toml` 의 값을 `sed` 로 고치던 케이스는 install 전에 그 사본을 `harness.toml` 로 둔다 — install 은 이미 있는
    설정을 건드리지 않는다
  - UT-00 은 배포되는 내장 기본값(`templates/defaults.toml`, 이름을 채운 사본)이 그대로 렌더되는지 본다. `[doctor]` 기본값을 기본 설정에서
    읽던 케이스는 `templates/defaults.toml` 에서 읽는다
- 설정이 없는 리포에 install 이 설정을 까는 것 자체를 보는 케이스는 바꾸지 않는다
- 건드릴 파일: `src/test/render-test.sh`

### 완료 조건

- [ ] `render-test.sh` 에 `templates/harness.toml` 을 대상 설정으로 복사하는 줄이 없다
- [ ] install 뒤 설치된 설정의 값을 고치는 케이스가 install 전에 내장 기본값 사본을 둔다
- [ ] 기존 케이스의 기대값이 그대로이고 T3 의 코드에서 모두 통과한다
- [ ] 작업 트리에서 `src/templates/harness.toml` 을 명세 2-4 의 최소 설정으로 바꿔 돌려도 이 task 가 옮긴 케이스는 실패하지 않는다(확인 뒤 되돌린다)
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 배포되는 기본값 | 이름을 채운 `templates/defaults.toml` 사본으로 render | 종료 코드 0 |
| UT-02 | 대상 설정 도우미 | 도우미로 만든 설정 | `project.name` 이 채워진 전체 값 사본, `setup()` 이 고정하던 값이 모두 바뀜 |
| UT-03 | 옮긴 케이스 | 회귀 테스트 전체 | 기대값을 바꾸지 않고 통과 |
| UT-04 | 설치 파일에 기대지 않음 | `src/templates/harness.toml` 을 최소 설정으로 바꾼 작업 트리 | 이 task 가 옮긴 케이스가 통과 |

## T5 · feat: install 이 프로젝트 이름만 담은 최소 설정을 깜

### 상위 Requirement

- relates to #207

### 작업 내용

설치가 기본값 전체가 아니라 프로젝트 이름만 담은 최소 설정을 프로젝트 레이어로 깐다. 나머지 값은 내장 기본값에서 온다.

- 명세 2-4 · 14-2 "최소 설정 설치"
- `src/templates/harness.toml` 을 명세 2-4 의 내용(머리 주석, `[project]` 의 `name`)으로 바꾼다
- `src/harness/config/load.py`
  - `seed_config()`: 프로젝트 레이어 파일이 없을 때 그 파일을 깔고 `name` 을 대상 디렉터리 이름으로 채운다. 자리와 경로 규칙은 지금과 같다.
    출력은 `created <경로> — it holds only this project's values; run \`harness schema\` to see the rest and where each comes from`
  - `seeded_config()`: 깔 최소 설정을 프로젝트 레이어로 두고 공유 설정을 읽는다
- 이미 있는 `harness.toml`(전체 값 사본 포함)은 건드리지 않는다
- render-test: 새 블록 "최소 설정 설치". install 출력 문구를 보던 케이스는 새 문구로
- 건드릴 파일: `src/templates/harness.toml`, `src/harness/config/load.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 빈 리포에 install 하면 `harness.toml` 이 명세 2-4 의 내용이고 `name` 이 대상 디렉터리 이름이다
- [ ] 그 리포의 생성 파일이 같은 이름을 채운 내장 기본값 전체 사본으로 렌더한 것과 같다
- [ ] install 출력에 명세 2-4 의 `created …` 줄이 있다
- [ ] 전체 값 사본이 이미 있는 리포에 install 하면 그 파일이 바이트까지 그대로다
- [ ] 이 리포 루트의 `harness.toml` 이 바뀌지 않는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 최소 설정 내용 | 빈 리포 `demo` 에 install | `harness.toml` 이 2-4 의 내용, `name = "demo"` |
| UT-02 | 생성 파일 동등 | UT-01 의 리포 / 이름을 `demo` 로 채운 내장 기본값 전체 사본으로 render 한 리포 | 생성 파일이 같다 |
| UT-03 | 출력 | UT-01 의 표준 출력 | `created … — it holds only this project's values` |
| UT-04 | 있는 설정 보존 | 전체 값 사본이 있는 리포에 install | 파일이 그대로 |

## T6 · feat: 내장 기본값과 preset 이 locked 로 값을 잠금

### 상위 Requirement

- relates to #207

### 작업 내용

아래 레이어(내장 기본값 · preset)가 키를 잠그면 위 레이어가 다른 값을 적지 못하게 한다. 이 이슈에서 잠금을 선언하는 레이어는 없으므로,
판정은 레이어를 직접 넣는 단위 테스트와 잠금을 선언한 내장 기본값 사본을 쓰는 회귀 테스트로 본다.

- 명세 4절 · 14-1 잠금(개인 레이어의 `locked` 선언은 T9) · 14-2 잠금
- `src/harness/config/layers.py`
  - 선언 검사(4-2): 선언할 수 있는 레이어는 내장 기본값 · preset. 프로젝트 레이어 파일의 최상위 `locked` 나 `verify.checks` 항목의 `locked` 는
    `error: harness.toml declares locked — only the built-in defaults and presets can lock values`
  - 경로가 선언한 레이어까지 병합한 설정에서 스칼라 · 배열이 아니면(없는 키 · 테이블) `error: <레이어>: locked path <경로> is not a scalar or an array`
  - 보호 목록 경로는 `cannot be locked — upper layers can only add to it`, `verify.checks` 경로는 `verify.checks cannot be locked as a whole — mark its items with locked = true`
  - 개인 레이어가 받는 키 넷(`harness.orchestrator` · `harness.model` · `roles.<역할>.runner` · `roles.<역할>.model`)은 `cannot be locked — it is a personal choice`.
    받는 키 목록은 `src/harness/config/defaults.py` 에 두고 T9 가 개인 레이어 검증에 같은 목록을 쓴다
  - 판정(4-3): 잠긴 경로를 위 레이어가 적으면 잠근 레이어까지의 병합 값과 같을 때(TOML 값의 동등, 배열은 원소와 순서) 받고, 다르면 명세 4-3 의
    `error:` · `-->` · 값 비교 줄 · `help:` 로 거부한다. 잠긴 검사 항목은 위 레이어의 같은 `name` 항목이 `locked` 를 뺀 모든 키에서 같을 때 받는다.
    한 번 잠긴 경로는 그 위 모든 레이어에 잠긴 채다
- `verify.checks` 항목 검증이 `locked` 키(참 · 거짓)를 받는다
- `src/harness/config/load.py`: 공유 설정을 읽는 함수가 병합 다음, 파생 전에 판정한다. 위반은 공유 설정을 읽는 모든 명령을 종료 코드 2 로 멈추고,
  render 는 아무것도 쓰지 않는다. 잠긴 키 경로와 잠근 레이어를 결과 옆에 남긴다 — `schema`(T18)가 쓴다
- 단위 테스트(`test_layers.py`)
- render-test 새 블록 "잠금": 소스 트리 복제의 내장 기본값 사본에 `locked = ["review.max_rounds", "commit.tags"]` 를 넣는다
- 건드릴 파일: `src/harness/config/layers.py` · `load.py` · `defaults.py`, `src/test/unit/test_layers.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 잠긴 스칼라 · 배열 · 검사 항목에 같은 값을 적은 위 레이어는 받고, 다른 값이면 명세 4-3 형식으로 거부된다
- [ ] 잠긴 배열은 원소와 순서가 모두 같을 때만 받는다
- [ ] 명세 4-2 표의 선언 오류(프로젝트 레이어의 선언, 스칼라도 배열도 아닌 경로, 보호 목록 · `verify.checks` 경로, 개인 키 잠금, 참 · 거짓이 아닌 항목 `locked`)가 각 문구로 나온다
- [ ] 잠금을 선언한 내장 기본값 사본의 소스 트리에서, 두 키에 같은 값을 적은 프로젝트는 렌더되고 어느 하나라도 다르면 종료 코드 2 로 거부되며 생성 파일이 바뀌지 않는다
- [ ] 배포되는 내장 기본값은 `locked` 를 선언하지 않는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 같은 값 | 기본값 `locked = ["review.max_rounds"]` · `5`, 프로젝트 `5` | 받는다 |
| UT-02 | 다른 값 | 같은 잠금, 프로젝트 `7` | 4-3 오류, `harness.toml sets 7, but the locked value is 5.` |
| UT-03 | 잠긴 배열 | `commit.tags` 잠금, 프로젝트가 같은 원소 다른 순서 / 같은 배열 | 거부 / 받는다 |
| UT-04 | 잠긴 검사 항목 | 기본값 항목 `locked = true`, 프로젝트가 같은 `name` 의 다른 `run` / `locked` 만 뺀 같은 항목 | 거부 / 받는다 |
| UT-05 | 프로젝트의 선언 | 프로젝트 레이어 최상위 `locked` | `harness.toml declares locked` |
| UT-06 | 잠글 수 없는 경로 | 없는 키 · 테이블 · `docs.protected` · `verify.checks` · `harness.model` | 4-2 의 각 문구 |
| UT-07 | 위에서도 잠긴 채 | preset 자리 레이어가 잠그고 그 위 preset 자리 · 프로젝트가 다른 값 | 둘 다 거부 |
| UT-08 | 회귀 — 잠금 | 소스 트리 복제의 기본값 사본에 두 키 잠금, 같은 값 / 다른 값의 프로젝트 | render 0 / 종료 코드 2 와 생성 파일 불변 |

## T7 · feat: harness set 이 파일에 없는 키와 절을 더함

### 상위 Requirement

- relates to #207

### 작업 내용

최소 설정에는 대부분의 키와 절이 없으므로, 플래그 없는 `harness set` 이 아래 레이어에 있는 키라면 파일에 없어도 줄을 더하게 한다.

- 명세 9-1 · 14-2 "`set` 이 키를 더한다"(깨진 개인 파일 몫은 T9)
- `src/harness/config/edit.py` `set_line()` 과 `src/harness/commands/set.py`
  - 쓸 수 있는 키: 프로젝트 레이어 아래 레이어들을 병합한 설정에 있는 키와 `harness.toml` 에 이미 있는 키. 그 밖이면 `error: no such key \`<키>\`` 와
    `help: the keys are the ones in the built-in defaults (harness schema shows them)`
  - 값이 테이블인 키와 인라인 테이블 안의 키는 지금처럼 쓰지 않는다
  - 키가 파일에 없고 절이 있으면 그 절 끝에 한 줄, 절이 없으면 파일 끝에 빈 줄 · `[<절>]` · 그 키 한 줄을 더한다
  - 선택 키 특례(`OPTIONAL_ROLE_KEYS` · `harness.model` · 기본값이 있는 절)를 걷는다
  - 출력은 `set: <바꾸기 전>` / `  to <바꾼 뒤>`. 파일에 없던 키는 바꾸기 전 자리에 아래 레이어 값과 그 레이어 — `set: max_rounds = 5 (default)`(T2 의 출처)
  - 바꾼 설정이 잠금 · 검증에 걸리면 지금처럼 원래 내용으로 되돌린다
- render-test 새 케이스. UT-46 의 "역할 절에 없던 모델을 정한다" 케이스는 고치지 않고 통과한다
- 건드릴 파일: `src/harness/config/edit.py` · `agents.py`, `src/harness/commands/set.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 최소 설정에 `set review.max_rounds 7` 이 `[review]` 절과 줄을 더하고 render 가 그 값을 쓴다
- [ ] 최소 설정에 `set roles.code-reviewer.model x` 가 `[roles.code-reviewer]` 절을 더한다
- [ ] 역할 절이 없는 전체 값 사본에 `set roles.<역할>.enabled false` 가 파일 끝에 그 절을 더한다
- [ ] 절이 있으면 그 절 끝에 한 줄을 더하고 다른 줄과 주석은 그대로다
- [ ] 없는 키는 `error: no such key` 와 명세 9-1 의 `help:` 로 거부되고 파일이 그대로다
- [ ] 파일에 없던 키의 출력이 `set: <키> = <값> (default)` 형식이다
- [ ] 잠긴 키(T6)를 다른 값으로 set 하면 파일이 원래 내용으로 돌아간다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 절 더하기 | 최소 설정에 `set review.max_rounds 7` | `[review]` 와 `max_rounds = 7` 추가, 출력 `set: max_rounds = 5 (default)` |
| UT-02 | 역할 절 더하기 | 최소 설정에 `set roles.code-reviewer.model x` | `[roles.code-reviewer]` 추가 |
| UT-03 | 있는 절에 더하기 | 전체 값 사본에 `set roles.planner.model y` | `[roles.planner]` 끝에 한 줄, 다른 줄 그대로 |
| UT-04 | 없는 절의 역할 키 | 역할 절을 지운 전체 값 사본에 `set roles.security-guard.enabled false` | 파일 끝에 그 절 |
| UT-05 | 없는 키 | `set review.nope 1` | 종료 코드 2, `no such key`, 파일 그대로 |
| UT-06 | 잠금 되돌리기 | 잠금을 선언한 소스 트리에서 잠긴 키를 다른 값으로 set | 종료 코드 2, 파일 그대로 |

## T8 · feat: 역할 어댑터의 모델과 절차 문서의 벤더 이름을 생성물에서 뺌

### 상위 Requirement

- relates to #207

### 작업 내용

커밋되는 역할 어댑터와 절차 문서에 사람마다 다른 모델과 벤더 이름이 들어가지 않게 한다. 서브에이전트 역할은 오케스트레이터 세션의 모델로 돈다.

- 명세 7-4 첫째 항목 · 7-5 · 7-7 · 10 의 `follows_orchestrator` · 11 의 "공유 설정의 inproc 역할에 모델이 있다" 행 · 14-2 "생성물에 개인 의존 값이 없다"의
  어댑터 · 절차 문서 몫 · 14-3 넷째 항목
- `src/harness/render/agents.py`: `.claude/agents/<역할>.md` 의 frontmatter 에 `model:` 을, `.codex/agents/<역할>.toml` 에 `model =` 을 쓰지 않는다. 나머지는 그대로
- `src/harness/render/workflows.py` `step_heading()` · `step_body()`: CLI 러너 역할의 `agent` 단계 제목은 `<제목> — <역할> 역할을 CLI 러너로 실행`, 본문 첫
  문단은 명세 7-5 의 문장. 서브에이전트 단계와 본문의 나머지 문장은 그대로
- `src/harness/config/agents.py` `role_model()`: 서브에이전트 역할과 러너가 오케스트레이터와 같은 역할은 `harness.model`, 다른 CLI 러너 역할은 `roles.<역할>.model`
- 공유 설정의 `inproc` 역할에 빈 문자열이 아닌 `model` 이 있으면 받아들이고, `harness doctor` 가 `warn` 항목
  `roles.<역할>.model = <값> is not used`(상세 `<역할> runs as a subagent, so it uses harness.model`)을 낸다 — `src/harness/readiness/items.py`
- `src/harness/commands/schema.py`: `roles.<역할>.follows_orchestrator` 가 `inproc` 역할에도 참이다
- render-test
  - UT-46: 어댑터의 모델 줄 기대값을 "모델 줄이 없다" 로, 서브에이전트 역할의 자기 모델은 쓰이지 않고 doctor 가 경고한다는 것으로,
    서브에이전트 역할의 `follows_orchestrator` 기대값을 참으로 바꾼다
  - UT-51: CLI 러너 단계 제목의 기대값을 `CLI 러너로 실행` 으로 바꾼다
  - 새 케이스 "생성물에 개인 의존 값이 없다"의 어댑터 · 절차 문서 몫
- 이 리포의 `.claude/agents/` · `.codex/agents/` · `.ai/workflows/` 를 render 로 갱신한다
- 건드릴 파일: `src/harness/render/agents.py` · `workflows.py`, `src/harness/config/agents.py`, `src/harness/readiness/items.py`, `src/harness/commands/schema.py`,
  `src/test/render-test.sh`, render 로 갱신되는 생성 파일

### 완료 조건

- [ ] 어댑터 두 형식에 모델 줄이 없다 — 오케스트레이터 모델과 역할 모델을 정한 설정에서도
- [ ] CLI 러너 단계의 절차 문서 제목이 `CLI 러너로 실행` 이고 본문 첫 문단이 명세 7-5 대로이며, 절차 문서에 `Codex CLI` · `Claude Code` 가 없다
- [ ] 서브에이전트 역할의 모델이 `harness.model` 이고, 그 역할에 모델을 적은 설정이 렌더되며 doctor 가 명세 11 의 경고를 낸다
- [ ] `schema` 에서 서브에이전트 역할의 `follows_orchestrator` 가 참이다
- [ ] CLI 러너 역할의 실행 argv 에 실린 모델은 그대로다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 어댑터 모델 줄 | `harness.model opus`, `roles.code-reviewer.model x` 로 render | `.claude/agents/*.md` 에 `model:`, `.codex/agents/*.toml` 에 `model =` 없음 |
| UT-02 | 절차 문서 | 리뷰어가 CLI 러너인 설정의 `.ai/workflows/*.md` | `CLI 러너로 실행`, 명세 7-5 첫 문단, `Codex CLI` · `Claude Code` 없음 |
| UT-03 | 서브에이전트 모델 | `roles.planner.model sonnet`(inproc) | 렌더 0, doctor `roles.planner.model = sonnet is not used` 와 상세 |
| UT-04 | schema | 서브에이전트 역할 | `follows_orchestrator` 참 |
| UT-05 | CLI 러너 모델 | `roles.planner.runner codex`, `roles.planner.model gpt-x` | 실행 argv 에 `-m gpt-x` |

## T9 · feat: 개인 레이어 harness.local.toml 을 실효 설정으로 읽고 harness run 이 씀

### 상위 Requirement

- relates to #207

### 작업 내용

사람마다 다른 선택(오케스트레이터 · 러너 · 모델)을 커밋하지 않는 개인 레이어에서 읽어 실효 설정을 만들고, 실행 시점의 검증과 불변식을
그 자리에서 본다. `harness run` 이 실효 설정으로 돈다. 공유 설정만 읽는 명령은 개인 파일을 열지 않는다.

- 명세 2-2 · 6-1 · 6-2 · 8 의 `harness run` 행 · 13 의 명령 도움말 끝 문단 · 14-1 개인 레이어와 잠금의 개인 레이어 `locked` · 14-2 "개인 레이어는 생성물에 닿지 않는다" ·
  "개인 레이어 거부"와 "실행 시점 불변식"의 `run --dry-run` 몫 · "`run --dry-run`" · "`set` 이 키를 더한다"의 깨진 개인 파일
- `src/harness/config/local.py`: 실효 설정을 읽는 함수 — 공유 설정에 `<하네스 루트>/harness.local.toml` 을 T2 의 규칙으로 더한다(파일이 없으면 공유 설정 그대로)
  - 받는 키는 T6 이 둔 목록의 넷. 값 범위는 명세 6-1 — 오케스트레이터는 벤더 선언에 `launch` 가 있는 id, 러너는 공유 설정의 그 역할과 러너 방식이 같은 값
    (`inproc` 이면 `inproc` 만, CLI 러너면 `headless` 가 있는 벤더 id 만), 역할 모델은 문자열이고 공유 설정에서 `inproc` 인 역할이면 빈 문자열만, 역할은 공유 설정에서 켜진 역할
  - 오류는 명세 6-2 표의 첫 줄 그대로 — TOML 깨짐, 받지 않는 키(받는 키 넷과 `help: put project values in harness.toml`), 켜진 역할 아님,
    러너 방식 변경(고를 수 있는 값을 `help` 로), 서브에이전트 역할의 모델(`help: harness set --local harness.model <model>`), 값의 형. 최상위 `locked` 는 명세 4-2 의
    선언 오류(`harness.local.toml declares locked …`)
  - 불변식(8): `invariants.distinct_reviewer` 가 켜져 있으면 역할 선언의 `distinct_from` 짝의 실행 주체를 실효 설정으로 보고, 같으면 명세 8 의 오류(`--> harness.local.toml`,
    `help: give code-reviewer a different runner on this machine` 와 `harness set --local …` 줄)
  - 모두 종료 코드 2
- `src/harness/commands/run.py`: `harness run`(`--dry-run` · `--worktree` 포함)이 실효 설정을 읽는다. 성립하지 않으면 아무것도 띄우지 않고 worktree 도 만들지 않는다.
  띄우는 오케스트레이터와 모델은 실효 설정 값이다
- 공유 설정만 읽는 명령(`install` · `render` · `check` · 플래그 없는 `set` · `steps` · `checks` · `write-doc` · `fix` · `forge-setup` · `vars` · `metrics`)은 그 파일을 열지 않는다
- `harness help` 끝 문단을 `Values live in layers: the built-in defaults, presets, harness.toml, and harness.local.toml (this machine only).` 로 — `src/harness/commands/help.py`
- 단위 테스트: `src/test/unit/test_local_layer.py`
- render-test 새 블록
- 건드릴 파일: `src/harness/config/local.py`(신규), `src/harness/commands/run.py` · `help.py`, `src/test/unit/test_local_layer.py`(신규), `src/test/render-test.sh`

### 완료 조건

- [ ] 받는 키 넷만 받고, 명세 6-2 표의 경우마다 그 오류 첫 줄과 종료 코드 2 가 나온다
- [ ] 오케스트레이터 · 리뷰어 러너 · 모델을 바꾼 개인 파일을 두고 render 하면 생성 파일이 파일 없이 렌더한 것과 바이트까지 같고 `check` 가 통과한다. 개인 파일을 깨뜨려도 render · check 가 통과한다
- [ ] 개인 파일이 깨져 있어도 플래그 없는 `set` 이 돈다
- [ ] `run --dry-run` 이 출력하는 명령이 개인 레이어의 오케스트레이터와 모델을 쓴다
- [ ] 받지 않는 키 · 러너 방식 변경 · 서브에이전트 역할의 모델이 든 개인 파일이면 `run --dry-run` 이 종료 코드 2 와 6-2 오류를 낸다
- [ ] 공유 설정은 성립하고 개인 오케스트레이터가 리뷰어와 같은 러너를 만들면 render · check 는 통과하고 `run --dry-run` 이 명세 8 의 오류로 거부하며, `run --worktree` 는 worktree 를 만들지 않는다
- [ ] `harness help` 끝 문단이 명세 13 의 문장이다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 받는 키 | 넷을 모두 적은 개인 레이어 | 실효 설정에 개인 값 |
| UT-02 | 받지 않는 키 | `review.max_rounds = 7` | `which is not a personal choice`, 받는 키 넷, `help: put project values in harness.toml` |
| UT-03 | 러너 방식 유지 | 공유 `inproc` 역할에 `runner = "codex"` / CLI 역할에 `runner = "inproc"` | 6-2 의 러너 방식 오류 |
| UT-04 | 꺼진 역할 | 꺼진 역할의 `runner` | `is not a configured role` |
| UT-05 | 서브에이전트 모델 | `inproc` 역할의 `model = "x"` | `has no effect`, `help: harness set --local harness.model <model>` |
| UT-06 | 형 | `harness.model = 1` | `must be a string (got 1)` |
| UT-07 | 개인 `locked` | 최상위 `locked = []` | `harness.local.toml declares locked` |
| UT-08 | 실행 시점 불변식 | 공유는 성립, 개인 `harness.orchestrator = "codex"` 와 리뷰어 `codex` | 명세 8 의 오류 |
| UT-09 | 생성물에 닿지 않음 | 개인 파일 있음 · 없음 · 깨짐으로 render, check | 생성 파일 바이트 동일, check 0 |
| UT-10 | `run --dry-run` | 개인 오케스트레이터 · 모델 | 출력 명령이 개인 값을 씀 |
| UT-11 | 거부되는 실행 | UT-02 · UT-03 · UT-05 · UT-08 의 개인 파일로 `run --dry-run`, UT-08 로 `run --worktree` | 종료 코드 2, worktree 없음 |
| UT-12 | 깨진 개인 파일과 `set` | 깨진 개인 파일이 있는 리포에 `set review.max_rounds 7` | 종료 코드 0 |

## T10 · feat: harness run-plan 이 이 기기의 실행 계획을 JSON 으로 냄

### 상위 Requirement

- relates to #207

### 작업 내용

역할을 어떻게 띄우는지를 render 가 파일로 남기는 대신 CLI 가 실행할 때 실효 설정에서 계산해 낸다. 이 task 는 명령과 계산을 넣고, 읽는 쪽을
옮기는 것은 T13 · T14 · T15 다.

- 명세 7-1 · 7-7 둘째 항목 · 13 의 `run-plan` 도움말 줄 · 14-1 실행 계획 · 14-2 "`run-plan` 출력"과 "개인 레이어 거부" · "실행 시점 불변식"의 `run-plan` 몫
- `src/harness/commands/run_plan.py`: 실효 설정을 읽는 함수(T9) → `run_plan()` → JSON 한 개를 표준 출력에. 인자는 `--target` 뿐이다. 실효 설정이 성립하지
  않으면 표준 출력에 아무것도 내지 않고 그 오류로 종료 코드 2
- `src/harness/commands/__init__.py` 의 `COMMANDS` 에 `run-plan` 행(설명 `the run plan for this machine as JSON: how each role runs, and the metrics settings`),
  `src/harness/cli.py` 의 `DELEGATES` 에 `run-plan`
- `src/harness/config/agents.py` `run_plan()`: 켜진 역할마다 한 항목. 모든 역할에 `label`(벤더 선언의 `label`, 없으면 `name`)과 `model`(7-7)을 싣는다 —
  서브에이전트 역할은 `via` · `vendor`(실효 오케스트레이터) · `label` · `model`, CLI 러너 역할은 지금 필드에 `label`. 출력 키는 `roles` · `metrics` 둘이고,
  `metrics` 는 공유 설정의 `[metrics]` 그대로(자리표시를 풀지 않는다)
- `script/harness.plan.json` 은 T16 까지 공유 설정으로 지금처럼 생성한다. 파일의 생성 표지는 쓰는 자리(`src/harness/render/plan.py`)가 붙인다
- 단위 테스트: `src/test/unit/test_run_plan.py`
- render-test 새 블록
- 건드릴 파일: `src/harness/commands/run_plan.py`(신규) · `__init__.py`, `src/harness/cli.py`, `src/harness/config/agents.py`, `src/harness/render/plan.py`,
  `src/test/unit/test_run_plan.py`(신규), `src/test/render-test.sh`, render 로 갱신되는 `script/harness.plan.json`

### 완료 조건

- [ ] `harness run-plan` 이 명세 7-1 의 필드를 가진 JSON 하나를 내고 `metrics.dir` 이 설정 값 그대로다
- [ ] 개인 레이어의 러너 · 모델이 `vendor` · `label` · `model` · `argv` 에 반영되고, 서브에이전트 역할의 `model` 이 `harness.model` 이다
- [ ] 6-2 의 개인 파일과 실행 시점 불변식 위반에서 표준 출력이 비고 종료 코드 2 다
- [ ] 고정 사본이 있는 리포에서 전역 CLI 의 `run-plan` 이 고정 사본으로 넘어간다
- [ ] `harness help` 에 `run-plan` 줄이 있고, 명령 표 스모크 테스트가 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 개인 값 반영 | 같은 공유 설정에 개인 레이어 없음 / 리뷰어 러너 `claude` · 모델 `m` | `vendor` · `label` · `model` · `argv` 가 개인 값을 따름 |
| UT-02 | 서브에이전트 모델 | `harness.model = "o"`, 서브에이전트 역할 | 그 역할의 `model` 이 `o` |
| UT-03 | label | 벤더 선언의 `label` 이 있는 벤더 / 없는 벤더 | `label` / `name` |
| UT-04 | 출력 모양 | `harness run-plan` | 최상위 키 `roles` · `metrics`, 꺼진 역할 없음, `metrics.dir` 에 자리표시 그대로 |
| UT-05 | 거부 | 받지 않는 키 · 러너 방식 변경 · 서브에이전트 모델 · 불변식 위반인 개인 파일 | 표준 출력 없음, 종료 코드 2, 6-2 · 8 의 오류 |
| UT-06 | 인자 | `harness run-plan extra` | 종료 코드 2, 사용법 오류 |

## T11 · feat: harness set --local 과 개인 파일을 git 이 무시하게 하는 줄

### 상위 Requirement

- relates to #207

### 작업 내용

개인 레이어를 쓰는 명령을 두고, 개인 파일이 커밋되지 않게 git 공통 디렉터리의 `info/exclude` 에 한 줄을 적는다. 프로젝트의 `.gitignore` 는 고치지 않는다.

- 명세 6-3 · 9-2 · 13 의 `set` 인수 · 14-2 "`set --local`" · "`install` 의 무시 줄" · "실행 시점 불변식"의 `set --local` 몫
- `src/harness/config/local.py`: 무시 줄 적기(6-3)
  - 하네스 루트에서 `git rev-parse --git-path info/exclude` 가 내는 파일에, `git rev-parse --show-prefix` 를 붙인 `/<리포 안의 위치>harness.local.toml` 한 줄
  - `git check-ignore -q -- harness.local.toml` 이 이미 무시한다고 답하거나 같은 줄이 있으면 적지 않는다. `info/` 가 없으면 만든다
  - 그 파일이 심볼릭 링크이거나 쓸 수 없으면 적지 않고 `warn: could not add harness.local.toml to git's exclude file`, 명령은 계속한다
  - 적었으면 `ignore: harness.local.toml (git info/exclude)` 한 줄. 하네스 루트가 git 작업 트리가 아니면 하지 않는다
- `src/harness/commands/set.py`: `harness set --local <절.키> <값> ...`(9-2) — 키가 모두 받는 키 넷인지 먼저 보고(아니면 아무것도 쓰지 않고 6-2 오류), 무시 줄을 적고,
  파일이 없으면 머리 주석(이 기기의 개인 선택이고 커밋하지 않는다는 것, 받는 키 넷)과 함께 만들고, 9-1 과 같은 줄 편집으로 쓰고(경로 안전 공용 함수를 거친다),
  실효 설정 전체를 검증한다(6-2 · 8). 실패하면 원래 내용으로 되돌리고 이 명령이 만든 파일이면 지운 뒤 `reverted — the config is unchanged` 와 종료 코드 2.
  바뀐 줄을 9-1 형식으로 출력하고 render 하지 않는다
- `src/harness/cli.py` 공용 파서에 `--local`, `COMMANDS` 의 `set` 인수를 `[--local] <section.key> <value> ...` 로, 사용법 오류 예시에 `harness set --local harness.orchestrator codex`
- `src/harness/commands/install.py`: 등록 뒤 render 전에 무시 줄을 적는다. 개인 파일은 만들지 않는다
- render-test 새 블록
- 건드릴 파일: `src/harness/config/local.py`, `src/harness/commands/set.py` · `install.py` · `__init__.py`, `src/harness/cli.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] `set --local harness.orchestrator codex` 가 개인 파일을 만들고 `info/exclude` 에 줄을 적어 `git check-ignore` 가 무시한다고 답한다
- [ ] `set --local` 뒤 생성 파일과 매니페스트가 바뀌지 않는다
- [ ] 검증(6-2 · 8)에 걸리는 `set --local` 은 파일을 남기지 않고(있던 파일이면 원래 내용) 종료 코드 2 다
- [ ] 받지 않는 키가 하나라도 있으면 아무것도 쓰지 않는다
- [ ] install 한 리포에서 손으로 만든 개인 파일이 `git status --porcelain` 에 나오지 않고, 다시 설치해도 줄이 겹치지 않으며, 모노레포 서브프로젝트면 줄에 리포 안의 위치가 붙는다
- [ ] `info/exclude` 가 심볼릭 링크면 줄을 적지 않고 `warn:` 을 내며 명령은 끝까지 돈다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 개인 파일 만들기 | install 한 리포에 `set --local harness.orchestrator codex` | 머리 주석과 값이 든 파일, `ignore:` 줄, `git check-ignore` 0 |
| UT-02 | 생성물 불변 | UT-01 전후의 생성 파일 · 매니페스트 | 같다 |
| UT-03 | 검증 실패 되돌리기 | 리뷰어와 같은 러너를 만드는 `set --local` | 종료 코드 2, `reverted`, 파일 없음 |
| UT-04 | 받지 않는 키 | `set --local review.max_rounds 7` | 종료 코드 2, 파일 · `info/exclude` 불변 |
| UT-05 | install 의 무시 줄 | install 뒤 손으로 만든 개인 파일, 다시 install | `git status --porcelain` 에 없음, 줄 하나 |
| UT-06 | 모노레포 | 서브디렉터리 하네스 루트에 install | 줄이 `/<서브디렉터리>/harness.local.toml` |
| UT-07 | 쓸 수 없는 exclude | `info/exclude` 가 심볼릭 링크 | 줄 없음, `warn: could not add`, 명령 성공 |

## T12 · feat: 추적되는 개인 파일을 check 가 거부하고 worktree · uninstall 이 개인 파일을 다룸

### 상위 Requirement

- relates to #207

### 작업 내용

개인 파일이 커밋되면 모든 클론의 선택이 되므로 `check` 가 막는다. 이슈 worktree 는 본 클론과 같은 개인 선택으로 돌게 개인 파일을 옮기고,
`uninstall --purge` 는 개인 파일도 지운다.

- 명세 6-4 · 6-5 · 6-6 · 14-2 "추적 금지" · "worktree 로 옮기기"
- `src/harness/drift.py` `check_target()`: 하네스 루트가 git 작업 트리이고 `git ls-files --error-unmatch -- harness.local.toml` 이 성공하면 명세 6-4 의 오류와
  `help:` 로 종료 코드 1. `--staged` 도 같다 — pre-commit 이 커밋을 막는다
- `src/harness/worktree.py`: `harness run --worktree` 가 새 worktree 를 만들면 `worktree.include` 값과 상관없이 하네스 루트의 `harness.local.toml` 을 worktree
  실행 디렉터리로 복사한다. 규칙은 `include` 복사와 같다 — 없으면 건너뛰고, worktree 에서 추적되는 경로면 덮지 않고, git 이 무시하지 않으면 복사하지 않고
  `warn: harness.local.toml is not ignored by git — not copied`. 복사한 내용을 출력하지 않는다
- `src/harness/commands/uninstall.py`: `--purge` 가 지우는 설정과 확인 목록에 `harness.local.toml` 이 든다. `--purge` 가 없으면 남긴다. `info/exclude` 의 줄은 지우지 않는다
- render-test 새 블록
- 건드릴 파일: `src/harness/drift.py`, `src/harness/worktree.py`, `src/harness/commands/uninstall.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 개인 파일을 `git add` 하면 `check` · `check --staged` 가 명세 6-4 의 오류로 1 이고 pre-commit 이 커밋을 막는다
- [ ] 하네스 루트가 git 작업 트리가 아니면 이 검사를 하지 않는다
- [ ] `worktree.include = []` 인 리포에서 `run --worktree` 가 개인 파일을 worktree 실행 디렉터리로 복사하고, 복사 뒤 그 worktree 의 `git status --porcelain` 이 비어 있다
- [ ] git 이 무시하지 않는 개인 파일은 복사하지 않고 `warn:` 을 낸다
- [ ] `uninstall --purge` 가 개인 파일을 지우고 확인 목록에 보이며, `--purge` 없이는 남긴다. `info/exclude` 의 줄은 남는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 추적 금지 | 개인 파일 `git add` 뒤 `check` · `check --staged` · pre-commit | 1 · 1 · 커밋 막힘, `harness.local.toml is tracked by git` 과 `git rm --cached` |
| UT-02 | git 밖 | git 작업 트리가 아닌 하네스 루트의 개인 파일 | `check` 가 이 오류를 내지 않음 |
| UT-03 | worktree 로 옮기기 | `worktree.include = []`, 무시되는 개인 파일, `run --worktree` | worktree 실행 디렉터리에 같은 내용, `git status --porcelain` 빔 |
| UT-04 | 무시되지 않는 파일 | 무시 줄을 지운 리포에서 `run --worktree` | 복사 없음, `warn: harness.local.toml is not ignored by git — not copied` |
| UT-05 | uninstall | `uninstall --purge --yes` / `uninstall` | 개인 파일 지워짐 · 확인 목록에 있음 / 남음, `info/exclude` 줄은 둘 다 남음 |

## T13 · feat: 역할 실행기가 실행 계획을 run-plan 으로 받음

### 상위 Requirement

- relates to #207

### 작업 내용

역할 실행기(`run-agent.py`)가 커밋된 실행 계획 파일 대신 고정 사본 CLI 의 `run-plan` 으로 이 기기의 실행 계획을 받는다.

- 명세 7-3 의 CLI 찾기 절차 · 찾지 못할 때의 두 줄 · `run-agent.py` 행 · 표 아래 첫 항목 · 13 의 `script/README.md` `run-agent.py` 행 · 14-3 셋째 항목의 역할 실행기 몫
- `src/templates/managed/script/run-agent.py`
  - 자기 파일이 있는 디렉터리의 부모를 하네스 루트로 잡고, `<루트>/.harness/bin/harness` · `<루트>/src/bin/harness` 순으로 실행할 수 있는 첫 것을 CLI 로 골라
    `<CLI> --target <루트> run-plan` 의 표준 출력 JSON 을 읽는다
  - CLI 를 찾지 못하면 명세 7-3 의 두 줄, `run-plan` 이 실패하면 CLI 의 표준 오류를 그대로 흘리고 종료 코드 2. `--check` 도 같다
  - 역할이 실행 계획에 없으면 `error: no role \`<역할>\` in the config (have: <역할들>)`, 필수 필드가 없거나 형이 틀리면 `error: the run plan from <CLI 경로> is broken`, 종료 코드 2
  - 머리 docstring 의 `script/harness.plan.json` 서술을 고친다
- `src/templates/managed/script/README.md` 의 `run-agent.py` 행: "실행 계획(`harness.plan.json`)" → "고정 사본 CLI 의 `run-plan`"
- render-test
  - 실행 계획을 손으로 만들어 쓰던 역할 실행기 케이스(`--check` 의 로그인 확인 · 확인 명령 없음 · 서브에이전트 역할 · PATH 에 없는 CLI · 시작하지 못하는 확인 명령 ·
    `--check` 아닌 실행의 스팬)는 하네스 루트의 `.harness/bin/harness` 자리에 같은 실행 계획을 내는 페이크 CLI 를 두고 같은 기대값을 본다
  - 실행 계획이 없는 케이스는 CLI 가 없는 루트에서 두 줄과 종료 코드 2 를 본다
  - 깨진 `auth_timeout` 케이스는 페이크 CLI 가 그 값을 실은 실행 계획으로 `the run plan … is broken` 을 본다
  - doctor 원격 점검의 리뷰어 러너 케이스(로그인 확인 명령이 없는 벤더 등)처럼 실행 계획 파일을 고쳐 상황을 만들던 케이스는 install 한 리포의 고정 사본 벤더 선언 사본
    (`.harness/templates/vendors.toml`)을 고쳐 같은 상황을 만든다. 역할 실행기를 부르는 대상 리포는 CLI 를 찾을 수 있게 install 한 리포를 쓴다
- `src/bin/harness render` 로 이 리포의 `script/run-agent.py` · `script/README.md` 사본 갱신
- 건드릴 파일: `src/templates/managed/script/run-agent.py` · `README.md`, `src/test/render-test.sh`, render 로 갱신되는 `script/`

### 완료 조건

- [ ] `run-agent.py` 가 `script/harness.plan.json` 을 읽지 않는다
- [ ] 개인 레이어로 리뷰어 러너를 바꾼 리포에서 `run-agent.py <역할> --check` 가 바뀐 러너의 로그인 확인 명령을 부른다
- [ ] CLI 가 없는 루트에서 명세 7-3 의 두 줄과 종료 코드 2, `run-plan` 이 거부하는 개인 파일이면 그 오류와 종료 코드 2 다 — `--check` 도 같다
- [ ] 없는 역할과 깨진 실행 계획이 명세의 문구로 종료 코드 2 다
- [ ] 기존 역할 실행기 케이스와 doctor 리뷰어 러너 케이스의 기대값(종료 코드 · 출력)이 그대로다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | CLI 찾기 | `.harness/bin/harness` 가 있는 루트 / `src/bin/harness` 만 있는 루트 | 그 CLI 의 `run-plan` 을 부른다 |
| UT-02 | CLI 없음 | 둘 다 없는 루트에서 `run-agent.py rev --check` | 종료 코드 2, `error: harness CLI not found under <루트>` 와 `help: harness install --target <루트>` |
| UT-03 | 기존 `--check` 케이스 | 같은 실행 계획을 내는 페이크 CLI | 로그인됨 0 · 안 됨 3 · 확인 명령 없음 0 · 서브에이전트 2 · 없는 CLI 2 · 시작 못함 4 그대로 |
| UT-04 | 개인 러너 | 개인 레이어로 리뷰어 러너를 바꾼 install 한 리포 | 바뀐 러너의 확인 명령을 부름 |
| UT-05 | 거부된 실행 계획 | 받지 않는 키가 든 개인 파일 | CLI 의 6-2 오류가 그대로, 종료 코드 2 |
| UT-06 | 없는 역할 · 깨진 계획 | 실행 계획에 없는 역할 / `auth_timeout` 이 문자열인 실행 계획 | `no role \`…\` in the config (have:` / `the run plan from … is broken`, 종료 코드 2 |
| UT-07 | doctor 리뷰어 러너 | 고정 사본 벤더 선언 사본에서 리뷰어 벤더의 `auth_check` 를 지운 리포 | `installed — sign-in is not checked for` 줄 그대로 |

## T14 · feat: 리뷰 루프가 리뷰어 러너와 작성자 표시를 run-plan 으로 받음

### 상위 Requirement

- relates to #207

### 작업 내용

리뷰 루프가 리뷰어 실행 파일과 리뷰 댓글의 작성자 표시를 이 기기의 실행 계획에서 받고, 커밋되는 생성물(`script/harness.env` · 리뷰어 어댑터)에서
리뷰어 표시를 뺀다.

- 명세 7-3 의 `review-mr.sh` · `post-review.sh` 행과 표 아래 둘째 항목 · 7-4 둘째 항목 · 7-6 · 14-2 "생성물에 개인 의존 값이 없다"의 `harness.env` 몫 · 14-4
- `src/templates/managed/script/review-mr.sh`: 회차 라벨을 올리기 전에 명세 7-3 의 절차로 CLI 를 찾아 `run-plan` 을 받고, `_review.py plan-exe` 로 `code-reviewer` 의
  `exe` 를, `plan-label` 로 `label` 을 얻는다. 받지 못하면 CLI 의 표준 오류(CLI 를 찾지 못하면 두 줄) 뒤에 `help: the round was not used — fix the config, then rerun` 을 내고
  종료 코드 2. `exe` 가 비면 지금처럼 `no review runner is configured`. 받은 `label` 을 `post-review.sh` 의 작성자 표시로 넘긴다
- `src/templates/managed/script/_review.py`: `plan-exe` 가 파일 경로 대신 표준 입력의 실행 계획 JSON 을 읽는다. 같은 입력에서 `label` 을 내는 `plan-label` 을 더한다
- `src/templates/managed/script/post-review.sh`: 작성자 표시 인자가 없으면 같은 절차로 `run-plan` 의 `code-reviewer` `label` 을 쓰고, 받지 못하면 지금 기본값 `자동 리뷰` 로
  등록을 계속한다
- `src/templates/agents/code-reviewer.md`: 등록 명령에서 `"{{REVIEWER_LABEL}}"` 를 빼고(`script/post-review.sh <리뷰요청번호> <리뷰본문파일>`), 그 아래에 "작성자 표시를 주지
  않으면 이 기기의 실행 계획에서 리뷰어 이름을 찾아 붙인다" 한 문장
- `src/harness/render/derive.py` `derive()`: `REVIEWER_LABEL` 을 뺀다 — `script/harness.env` 에서 빠진다
- `src/templates/managed/script/test-review-loop.sh`(명세 14-4)
  - 샌드박스 하네스 루트에 실제 CLI 의 고정 사본을 둔다 — 자기 하네스 루트에서 `.harness/bin/harness` → `src/bin/harness` 순으로 찾은 CLI 의 진입 스크립트 · 패키지 · 템플릿을
    샌드박스의 `.harness/bin/harness` · `.harness/lib/harness/` · `.harness/templates/` 로 복사한다(사본)
  - 자기 하네스 루트의 `harness.toml` 사본을 두고 `metrics.dir` 를 샌드박스 안으로 덮는다. `HARNESS_HOME` 도 샌드박스 안이다
  - 리뷰 러너 준비 상태는 고정 사본 벤더 선언 사본에서 리뷰 러너 벤더의 `auth_check` · `exe` 를 고쳐 만든다. 스텁으로 갈아끼울 도구 이름은 샌드박스 CLI 의
    `run-plan` 출력(`roles.code-reviewer.exe`)에서 읽는다
  - 샌드박스에 더한 파일은 첫 커밋에 넣는다
  - 새 케이스: 실행 계획의 `label` 이 등록의 작성자 표시로 넘어간다, 실행 계획을 받지 못하면(설정 사본이 검증에 걸리거나 고정 사본이 없을 때) 회차 라벨을 올리지 않고 종료 코드 2
  - 기존 케이스의 기대값(종료 코드 · 라벨 · 등록 내용)은 그대로다
- render-test: "생성물에 개인 의존 값이 없다"에 `script/harness.env` 에 `REVIEWER_LABEL` 이 없다는 것을 더한다. `REVIEWER_LABEL` 이나 실행 계획 파일의 리뷰어 값에 기대던 케이스를 고친다
- `src/bin/harness render` 로 이 리포의 `script/` 사본, `.claude/agents/code-reviewer.md` · `.codex/agents/code-reviewer.toml` · `script/harness.env` 갱신
- 건드릴 파일: `src/templates/managed/script/review-mr.sh` · `_review.py` · `post-review.sh` · `test-review-loop.sh`, `src/templates/agents/code-reviewer.md`,
  `src/harness/render/derive.py`, `src/test/render-test.sh`, render 로 갱신되는 `script/` 와 생성 파일

### 완료 조건

- [ ] `review-mr.sh` · `_review.py` 가 `script/harness.plan.json` 을 읽지 않는다
- [ ] 개인 레이어로 리뷰어 러너를 바꾼 샌드박스에서 `review-mr.sh` 가 바뀐 러너의 실행 파일을 띄우고 그 벤더의 `label` 을 작성자 표시로 넘긴다
- [ ] 실행 계획을 받지 못하면 회차 라벨이 그대로이고 종료 코드 2 이며 명세 7-3 의 `help:` 줄이 나온다
- [ ] 작성자 표시 인자 없는 `post-review.sh` 가 실행 계획의 `label` 을, 받지 못하면 `자동 리뷰` 를 쓰고 등록을 계속한다
- [ ] `script/harness.env` 에 `REVIEWER_LABEL` 이 없고, 리뷰어 어댑터 두 형식의 등록 명령에 작성자 표시 인자가 없다
- [ ] `test-review-loop.sh` 의 기존 케이스 기대값이 그대로이고 모두 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | `plan-exe` · `plan-label` | 표준 입력의 실행 계획 JSON | `code-reviewer` 의 `exe` · `label` |
| UT-02 | 작성자 표시 전달 | 샌드박스 리뷰 한 회차 | 등록 댓글의 작성자 표시가 실행 계획의 `label` |
| UT-03 | 실행 계획 없음 | 검증에 걸리는 설정 사본 / 고정 사본 없음 | 회차 라벨 불변, 종료 코드 2, `the round was not used` |
| UT-04 | 리뷰어 러너 없음 | 리뷰어가 서브에이전트인 설정 | `no review runner is configured` 그대로 |
| UT-05 | `post-review.sh` 기본 표시 | 작성자 표시 없이 부름, CLI 있음 / 없음 | 실행 계획의 `label` / `자동 리뷰`, 둘 다 등록 |
| UT-06 | 생성물 | render 한 리포의 `harness.env` · 리뷰어 어댑터 | `REVIEWER_LABEL` 없음, 등록 명령에 세 번째 인자 없음 |
| UT-07 | 기존 리뷰 루프 케이스 | `test-review-loop.sh` 전체 | 기대값 그대로 통과 |

## T15 · feat: 지표 기록기가 지표 설정을 run-plan 으로 받음

### 상위 Requirement

- relates to #207

### 작업 내용

지표 기록기(`metric.py`)가 지표 설정을 실행 계획 파일 대신 `run-plan` 에서 받는다. 같은 프로세스에서 기록기를 쓰는 `harness run` 은 CLI 를 다시 띄우지 않고
실효 설정의 지표 설정을 넘긴다.

- 명세 7-3 의 `metric.py` 행 · 표 아래 셋째 · 넷째 항목 · 그 아래 문단의 지표 설정 자리표시 · 13 의 `script/README.md` `metric.py` 행
- `src/templates/managed/script/metric.py`
  - 스크립트로 불리면 명세 7-3 의 절차로 CLI 를 찾아 `run-plan` 의 `metrics` 를 받는다. 프로세스 하나에서 한 번만 부른다
  - `HARNESS_METRICS=off` 면 CLI 를 부르지 않고 기록하지 않는다. 실행 계획을 받지 못하면 기록하지 않고, 부른 쪽의 출력 · 종료 코드를 바꾸지 않는다
  - `metrics.dir` 의 자리표시는 지금처럼 `_clone_key.py` 로 푼다
  - 넘겨받은 지표 설정이 있으면 그것을 쓰고 CLI 를 부르지 않는다
- `src/harness/commands/run.py`: 실효 설정을 읽는 함수 → `run_plan()` 의 `metrics` 를 클론 키(`src/harness/home/clone_key.py`)로 푼 값을, `src/harness/metrics/spans.py` 로 불러온
  기록기에 넘긴다. `metrics/` 는 다른 하네스 모듈을 불러오지 않는다 — 푸는 쪽은 `harness run` 이다
- `src/templates/managed/script/README.md` 의 `metric.py` 행에 지표 설정을 `run-plan` 에서 받는다는 것을 더한다
- render-test: 지표 기록 케이스가 CLI 를 찾을 수 있는 리포에서 돈다. 새 케이스 — `HARNESS_METRICS=off` 면 CLI 를 부르지 않는다(부름을 기록하는 페이크 CLI), CLI 가 없으면 기록 없이
  감싼 명령의 종료 코드가 그대로다, `harness run --dry-run` 이 아닌 실행의 스팬이 실효 설정의 지표 경로에 남는다
- `src/bin/harness render` 로 이 리포의 `script/metric.py` · `script/README.md` 사본 갱신
- 건드릴 파일: `src/templates/managed/script/metric.py` · `README.md`, `src/harness/commands/run.py`, `src/harness/metrics/spans.py`, `src/test/render-test.sh`, render 로 갱신되는 `script/`

### 완료 조건

- [ ] `metric.py` 가 `script/harness.plan.json` 을 읽지 않는다
- [ ] 스크립트로 불린 `metric.py` 가 `run-plan` 의 `metrics.dir` 를 클론 키로 푼 경로에 스팬을 남기고, 한 프로세스에서 CLI 를 한 번만 부른다
- [ ] `HARNESS_METRICS=off` 면 CLI 를 부르지 않는다
- [ ] CLI 가 없거나 `run-plan` 이 실패하면 기록하지 않고 감싼 명령의 출력 · 종료 코드가 그대로다
- [ ] `harness run` 의 스팬이 실효 설정의 지표 경로에 남고, `harness run` 이 `run-plan` 하위 프로세스를 띄우지 않는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 지표 경로 | install 한 리포에서 `metric.py wrap` | `run-plan` 의 `metrics.dir` 를 푼 경로에 스팬 |
| UT-02 | 한 번만 부름 | 한 프로세스에서 start · end, 부름을 기록하는 페이크 CLI | `run-plan` 부름 1회 |
| UT-03 | 꺼짐 | `HARNESS_METRICS=off` | 부름 0회, 스팬 없음 |
| UT-04 | CLI 없음 | CLI 가 없는 루트에서 `wrap` 으로 종료 코드 3 인 명령 | 스팬 없음, 종료 코드 3 |
| UT-05 | `harness run` | 페이크 오케스트레이터로 `harness run` | 실효 설정의 지표 경로에 스팬, `run-plan` 하위 프로세스 없음 |

## T16 · feat: script/harness.plan.json 을 생성하지 않고 남은 파일을 render 가 지움

### 상위 Requirement

- relates to #207

### 작업 내용

실행 계획을 읽는 쪽이 모두 `run-plan` 으로 옮겨 갔으므로 `script/harness.plan.json` 을 생성 파일에서 뺀다. 이미 있는 리포는 다음 render 가 지금의 정리로 지운다.

- 명세 7-2 · 14-2 "`script/harness.plan.json` 걷기" · 14-3 셋째 항목의 남은 몫
- `src/harness/render/plan.py` `plan()`: `script/harness.plan.json` 을 뺀다. 직전 생성 매니페스트에 있고 이번 render 가 만들지 않으므로 정리(`prune`)가 지운다. `check` 는 그 파일을 대조하지 않는다
- 이 리포: render 가 `script/harness.plan.json` 을 지우고 `.harness/generated` 에서 그 줄을 뺀다
- render-test
  - 새 케이스 "걷기": 직전 매니페스트에 그 파일이 있는 리포를 render 하면 파일이 지워지고 매니페스트에서 빠진다
  - 실행 계획 파일을 읽던 남은 케이스(실행 계획의 argv · entry · via, 지표 경로, 로그인 확인 명령, 로그인 확인 제한 시간, 기록 경로 도우미)는 `harness run-plan` 출력을 본다
  - 실행 계획 파일을 `check` 가 대조하던 줄은 "파일이 생성되지 않고 `check` 가 통과한다" 로 바꾼다
- 건드릴 파일: `src/harness/render/plan.py`, `src/test/render-test.sh`, render 로 지워지는 `script/harness.plan.json` 과 갱신되는 `.harness/generated`

### 완료 조건

- [ ] render 가 `script/harness.plan.json` 을 만들지 않는다
- [ ] 직전 매니페스트에 그 파일이 있는 리포를 render 하면 파일이 지워지고 매니페스트에서 빠진다
- [ ] 이 리포에 `script/harness.plan.json` 이 없고 `.harness/generated` 에 그 줄이 없다
- [ ] `src/` · `script/` 아래 코드에 `harness.plan.json` 을 읽는 곳이 없다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성하지 않음 | 새 리포 render | `script/harness.plan.json` 없음, `check` 0 |
| UT-02 | 걷기 | 직전 매니페스트에 그 파일이 있는 리포 render | 파일 지워짐, 매니페스트에 줄 없음 |
| UT-03 | 실행 계획 값 | `roles.planner.runner codex`, `roles.planner.model gpt-x` 뒤 `run-plan` | `argv` 에 `-m gpt-x`, `entry` 가 `script/run-agent.py planner`, `developer.via` 가 `subagent` |
| UT-04 | 지표 경로 | `metrics.dir` 를 정한 리포의 `run-plan` | `metrics.dir` 가 설정 값 그대로 |

## T17 · feat: 전체 값 사본에서 지운 역할이 기본값으로 되살아나면 멈추고 안내

### 상위 Requirement

- relates to #207

### 작업 내용

레이어 이전 하네스에서 역할 표를 지워 역할을 뺀 전체 값 사본은, 갱신 뒤 내장 기본값이 그 역할을 다시 켠다. 그 역할이 말없이 되살아나지 않게 render 가
멈추고 끄거나 받아들이는 명령을 안내한다.

- 명세 5-2 · 11 의 "5-2 의 판정에 걸린다" 행 · 14-2 "지운 역할"
- 판정 함수(`src/harness/changes.py`): 아래가 모두 참인 역할을 모은다 — ① 직전 생성 매니페스트(`.harness/generated`)에 `script/harness.plan.json` 이 있다
  ② 직전 생성 매니페스트에 그 역할의 어댑터(`.claude/agents/<역할>.md` · `.codex/agents/<역할>.toml`)가 하나도 없다 ③ 이번 공유 설정에서 그 역할이 켜져 있다
  ④ 프로젝트 레이어 파일에 그 역할의 키가 하나도 없다. 매니페스트가 없으면 판정하지 않는다
- 걸리면 명세 5-2 의 `error:` · 설명 줄 · `help:` 두 쌍을 낸다. 걸린 역할을 한 번에 모두 적고, `help` 의 명령은 그 역할 전부를 한 줄의 `harness set` 쌍으로 낸다
- `render` · `check` 는 이 판정으로 종료 코드 2 로 멈추고 아무것도 쓰지 않는다
- `set` · `steps` · `checks` 는 바꾼 설정으로 판정하고, 걸리면 검증 실패처럼 설정을 되돌리고 멈춘다. 걸린 역할을 `enabled` 로 적는 `set` 은 ④ 를 깨므로 통과한다
- `install` 은 render 단계에서 같은 오류로 멈춘다(고정 사본과 등록은 이미 갱신된 채)
- `harness doctor` 의 생성 파일 절에 `bad` 항목 `role <역할> comes back on from the built-in defaults`(상세에 명세 5-2 의 `harness set` 명령)
- render-test 새 블록 "지운 역할"
- 건드릴 파일: `src/harness/changes.py`, `src/harness/render/apply.py`, `src/harness/drift.py`, `src/harness/commands/set.py` · `steps.py` · `checks.py` · `install.py`,
  `src/harness/readiness/items.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 직전 매니페스트에 `script/harness.plan.json` 이 있고 역할 하나의 어댑터가 없는 전체 값 사본이면 render 가 명세 5-2 의 오류로 종료 코드 2 이고 아무것도 쓰지 않는다
- [ ] 같은 리포에서 `check` 가 종료 코드 2, doctor 가 생성 파일 절에 `bad` 항목을 낸다
- [ ] 걸린 역할이 둘이면 오류와 `help` 명령에 둘 다 한 줄로 든다
- [ ] `set roles.<역할>.enabled false` 가 역할 절을 더하며 통과하고, 그 뒤 render 는 판정하지 않는다(매니페스트에서 `script/harness.plan.json` 이 빠진다)
- [ ] 걸린 역할을 건드리지 않는 `set` 은 설정을 되돌리고 멈춘다
- [ ] 매니페스트가 없는 첫 설치는 판정하지 않는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | render 멈춤 | 매니페스트에 실행 계획 파일 줄이 있고 `security-guard` 어댑터 줄이 없는 리포, 그 역할 절이 없는 전체 값 사본 | 종료 코드 2, `role security-guard was not part of the last render`, 생성 파일 불변 |
| UT-02 | check · doctor | 같은 리포 | `check` 2, doctor `role security-guard comes back on from the built-in defaults` |
| UT-03 | 둘을 한 번에 | 어댑터가 없는 역할 둘 | 오류와 `help` 명령에 두 역할 |
| UT-04 | 끄기로 통과 | `set roles.security-guard.enabled false` 뒤 render | 0, 역할 절 추가, 다음 render 판정 없음 |
| UT-05 | 받아들이기로 통과 | `set roles.security-guard.enabled true` 뒤 render | 0, 그 역할 파일 생성 |
| UT-06 | 다른 `set` 되돌리기 | 같은 리포에서 `set review.max_rounds 7` | 종료 코드 2, 설정 불변 |
| UT-07 | 첫 설치 | 매니페스트가 없는 리포에 역할 절이 빠진 전체 값 사본 | 판정 없이 render |

## T18 · feat: harness schema 가 공유 설정과 값마다의 출처 · 개인 레이어 값을 냄

### 상위 Requirement

- relates to #207

### 작업 내용

UI 가 값을 파일 대신 `schema` 로 읽고 값마다의 출처 · 잠금 · 개인 값을 그릴 수 있게 출력에 키를 더한다. 기존 키의 뜻은 그대로이고 공유 설정으로 계산한다.

- 명세 10 · 2-2 의 `schema` 행 · 14-1 출처의 `same_as_below` · `inherited_items` · 14-2 "schema"
- `src/harness/commands/schema.py`
  - `config`(공유 설정 전체, 꺼진 역할 없음), `layers`(아래 → 위 `{"id", "path"}`, 개인 레이어는 `"present"`, 내장 기본값의 `path` 는 지금 `template_path()` 규칙),
    `sources`, `same_as_below`, `locked`, `inherited_items`, `roles_off`, `local`(개인 레이어가 정한 값, 없거나 성립하지 않으면 `{}`), `local_error`(성립하지 않을 때만, 오류 첫 줄)
  - `checks` 항목마다 `source` · `same_as_below` · `locked`
  - `base_protected` 는 `inherited_items["docs.protected"]` 와 같은 값
  - `config_notes` 는 내장 기본값 파일의 주석에서 읽는다
  - 개인 레이어가 성립하지 않아도 멈추지 않는다
- `src/harness/config/layers.py`: `same_as_below`(출처가 `project` 이고 값이 프로젝트 아래 레이어들의 병합 값과 같은 키)와 `inherited_items`(프로젝트 아래 레이어에서 온 보호 목록 항목) 계산.
  꺼진 역할 목록은 파생이 남긴다
- 단위 테스트(`test_layers.py`)
- render-test 새 블록 "schema"
- 건드릴 파일: `src/harness/commands/schema.py`, `src/harness/config/layers.py` · `load.py`, `src/test/unit/test_layers.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] `schema` 에 명세 10 의 키가 모두 있고 값이 레이어 구성대로다
- [ ] 전체 값 사본에서 기본값과 같은 키가 `same_as_below` 에, 기본 여섯 보호 문서가 `inherited_items["docs.protected"]` 에 있다
- [ ] 꺼진 역할이 `config.roles` 에 없고 `roles_off` 에 있다
- [ ] 개인 레이어가 있으면 `local` 에 그 값, 깨졌으면 `local` 이 `{}` 이고 `local_error` 가 오류 첫 줄이며 종료 코드 0 이다
- [ ] 최소 설정에서도 `config_notes` 가 내장 기본값의 주석으로 채워진다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | `same_as_below` | 프로젝트가 기본값과 같은 `review.max_rounds = 5` 와 다른 `review.round_label` | 앞의 것만 목록에 |
| UT-02 | `inherited_items` | 프로젝트 `docs.protected` 에 한 항목 | 기본 여섯 항목만 `inherited_items` 에 |
| UT-03 | `sources` | 최소 설정 + 몇 줄 | 적은 키는 `project`, 나머지는 `default` |
| UT-04 | `layers` | 개인 파일 있음 / 없음 | 마지막 항목 `local` 의 `present` 참 / 거짓 |
| UT-05 | `local_error` | 깨진 개인 파일 | `local` `{}`, `local_error` 첫 줄, 종료 코드 0 |
| UT-06 | `roles_off` · `locked` | 꺼진 역할, 잠금을 선언한 소스 트리 | `roles_off` 에 그 역할, `locked` 에 잠긴 경로, `checks` 항목의 `locked` |
| UT-07 | `config_notes` | 최소 설정 | 내장 기본값의 키 주석이 있음 |

## T19 · feat: harness doctor 가 개인 레이어와 실효 설정을 점검

### 상위 Requirement

- relates to #207

### 작업 내용

doctor 가 개인 레이어의 상태를 알리고, 역할 · 불변식 · 모델 항목을 이 기기의 실효 설정으로 본다. 생성 파일 대조는 공유 설정 그대로다.

- 명세 11(남은 참조 행은 T1, 서브에이전트 모델 행은 T8, 5-2 행은 T17) · 2-2 의 `doctor` · `status` 행 · 7-1 둘째 항목의 doctor 몫 · 14-2 "doctor"
- `src/harness/readiness/items.py` 의 `config` 절
  - 개인 레이어가 있고 성립: `ok` `harness.local.toml sets <키들>`
  - 성립하지 않음: `bad` `harness.local.toml is not valid`(상세에 오류 첫 줄) — 나머지 항목은 공유 설정으로 보고 끝까지 돈다
  - 개인 파일이 있는데 git 이 무시하지 않음: `warn` `harness.local.toml is not ignored by git`(상세에 `info/exclude` 에 줄을 더하는 명령)
  - 개인 파일이 git 인덱스에 있음: `bad` `harness.local.toml is tracked by git`(상세 `git rm --cached harness.local.toml`)
  - 실효 설정이 불변식을 어김: `bad` `<구현 역할> and <리뷰 역할> run on the same runner (<벤더>) on this machine`
- 러너가 오케스트레이터와 같은 역할의 모델 경고 · 오케스트레이터 능력 경고 · 모델 판정(`model_ok`)은 실효 설정으로 본다
- `src/harness/readiness/remote.py`: 리뷰어 러너 항목이 실행 계획을 실효 설정을 읽는 함수와 `run_plan()` 으로 받는다
- `harness status` 는 같은 항목 목록을 쓴다
- render-test 새 블록 "doctor"
- 건드릴 파일: `src/harness/readiness/items.py` · `remote.py`, `src/harness/commands/doctor.py` · `status.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 무시되지 않는 개인 파일 · 추적되는 개인 파일 · 깨진 개인 파일 · 실효 불변식 위반이 명세 11 의 항목과 상태로 나온다
- [ ] 깨진 개인 파일이어도 doctor 가 끝까지 돌고 나머지 항목을 공유 설정으로 낸다
- [ ] 성립하는 개인 파일이면 `ok` 항목에 그 파일이 정한 키가 있다
- [ ] 모델 판정과 오케스트레이터 경고가 개인 레이어의 오케스트레이터 · 모델을 따른다
- [ ] `status` 의 집계가 같은 항목을 센다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 성립하는 개인 파일 | `harness.orchestrator` · `harness.model` 을 적은 무시되는 개인 파일 | `ok` `harness.local.toml sets harness.orchestrator, harness.model` |
| UT-02 | 깨진 개인 파일 | TOML 이 깨진 개인 파일 | `bad` `harness.local.toml is not valid`, 나머지 절까지 출력 |
| UT-03 | 무시되지 않음 | 무시 줄이 없는 리포의 개인 파일 | `warn` `harness.local.toml is not ignored by git` |
| UT-04 | 추적됨 | `git add` 한 개인 파일 | `bad` `harness.local.toml is tracked by git` |
| UT-05 | 실효 불변식 | 개인 오케스트레이터가 리뷰어와 같은 러너 | `bad` `… run on the same runner (codex) on this machine` |
| UT-06 | 실효 모델 판정 | 개인 레이어로 오케스트레이터를 바꾼 리포 | 모델 판정이 바뀐 오케스트레이터로 |
| UT-07 | status | UT-02 의 리포 | `bad` 수에 그 항목이 든다 |

## T20 · feat: UI 가 설정 값을 schema 로 읽고 레이어 이름표와 점검 문구를 더함

### 상위 Requirement

- relates to #207

### 작업 내용

최소 설정의 `harness.toml` 에는 값이 거의 없으므로 UI 가 값을 `harness schema` 의 `config` 로 읽게 한다. 화면이 쓸 레이어 이름표와 새 doctor 항목의 한국어 문구를
순수 함수로 더한다.

- 명세 12 첫째 · 아홉째 · 열째 · 열한째 항목 · 14-5 첫째 항목과 `doctor.test.js` 의 문구
- `src/ui/lib/harness.js`: `readConfig()` 가 `harness.toml` 을 직접 파싱하던 자리를 `schema` 의 `config` 로. `config` 가 없는 옛 고정 사본이면 지금처럼 파일을 읽는다.
  부르는 곳 — 홈 카드(`src/ui/app/page.js`), 설정 화면(`src/ui/app/[project]/settings/page.js`), 문서 검사의 오케스트레이터(`src/ui/lib/actions.js`)
- `src/ui/lib/labels.js`: 레이어 id → 표시 이름 순수 함수(`default` → `기본값`, `project` → `프로젝트`, 그 밖의 id → `preset`)와 `labels.test.js`
- `src/ui/lib/doctor.js`: 명세 11 의 새 항목 한국어 문구와 바뀐 남은 참조 문구(`is off in the config`), `doctor.test.js`
- `src/ui/lib/help.js`: `harness.orchestrator` · `harness.model` 도움말에 "사람마다 다르게 쓰려면 harness.local.toml" 을 더한다
- 건드릴 파일: `src/ui/lib/harness.js` · `actions.js` · `labels.js` · `labels.test.js` · `doctor.js` · `doctor.test.js` · `help.js`, `src/ui/app/page.js`, `src/ui/app/[project]/settings/page.js`

### 완료 조건

- [ ] 최소 설정 프로젝트의 홈 카드와 설정 화면이 내장 기본값을 포함한 값을 보인다
- [ ] `schema` 에 `config` 가 없는 CLI 로 띄운 경우 파일을 읽는 동작이 그대로다
- [ ] 레이어 id 세 종류가 표시 이름으로 바뀐다
- [ ] doctor 화면이 명세 11 의 새 항목과 `is off in the config` 를 한국어로 보인다
- [ ] UI 단위 테스트(`cd src/ui && node --test lib/*.test.js`)와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 레이어 이름표 | `default` · `project` · preset 자리 id | `기본값` · `프로젝트` · `preset` |
| UT-02 | doctor 문구 — 개인 레이어 | `harness.local.toml is not valid` · `is not ignored by git` · `is tracked by git` · `sets <키들>` | 각 한국어 문구 |
| UT-03 | doctor 문구 — 실효 불변식 · 남은 참조 | `… run on the same runner (codex) on this machine` · `role \`docs-writer\` is off in the config` | 각 한국어 문구 |
| UT-04 | doctor 문구 — 지운 역할 · 서브에이전트 모델 | `role security-guard comes back on from the built-in defaults` · `roles.planner.model = x is not used` | 각 한국어 문구 |
| UT-05 | 값 읽기 | `config` 가 있는 schema / 없는 schema | `config` 값 / 파일 값 |

## T21 · feat: UI 설정 · Agents 화면에 값의 출처 · 잠금 · 개인 값 표시

### 상위 Requirement

- relates to #207

### 작업 내용

설정 화면과 Agents 화면이 값마다 어느 레이어에서 왔는지, 지워도 같은 값인지, 잠겼는지, 이 기기에서는 무엇으로 도는지를 보인다. UI 의 쓰기는 지금처럼
플래그 없는 `harness set` 이고, 개인 레이어를 쓰거나 역할을 끄고 켜는 조작은 두지 않는다.

- 명세 12 둘째 ~ 여덟째 항목
- 설정 화면(`src/ui/app/[project]/settings/page.js` 와 그 컴포넌트)
  - 값마다 `sources` 의 레이어 id 를 T20 의 표시 이름으로 단다
  - `same_as_below` 인 값에 "기본값과 같습니다 — 이 줄을 지우면 기본값을 따릅니다"
  - 잠긴 값(`locked`)은 읽기 전용으로 그리고 잠근 레이어를 보인다
  - 개인 레이어가 덮는 값(`local`)에 "이 기기에서는 `<값>` (harness.local.toml)", `local_error` 가 있으면 화면 머리에 그 오류
  - 보호 목록 입력의 뺄 수 없는 항목은 `inherited_items` 로 그린다
  - 서브에이전트 역할은 `follows_orchestrator` 로 그리고 모델을 고르게 하지 않는다
- Agents 화면(`src/ui/app/[project]/agents/`)이 역할의 러너 · 모델에 같은 개인 값 표시를 단다
- 표시를 정하는 로직은 `src/ui/lib/` 의 순수 함수로 두고 단위 테스트한다
- 건드릴 파일: `src/ui/app/[project]/settings/page.js`, `src/ui/app/[project]/agents/page.js`, `src/ui/components/` 의 설정 · 역할 컴포넌트, `src/ui/lib/` 의 표시 함수와 그 테스트

### 완료 조건

- [ ] 설정 화면의 값마다 출처 표시가 있고, `same_as_below` · 잠금 · 개인 값 · `local_error` 표시가 명세 12 대로 나온다
- [ ] 잠긴 값은 입력할 수 없다
- [ ] 보호 목록 입력에서 `inherited_items` 항목은 뺄 수 없다
- [ ] 서브에이전트 역할에 모델 선택이 없다
- [ ] Agents 화면의 러너 · 모델에 개인 값 표시가 있다
- [ ] UI 에 개인 레이어를 쓰거나 역할을 끄고 켜는 조작이 없다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 값 표시 정하기 | 키 하나와 schema 의 `sources` · `same_as_below` · `locked` · `local` | 출처 이름 · 같은 값 안내 · 읽기 전용 · 이 기기 값 |
| UT-02 | 보호 목록 | `inherited_items` 와 프로젝트 항목 | 앞의 것은 뺄 수 없음, 뒤의 것은 뺄 수 있음 |
| UT-03 | 서브에이전트 역할 | `follows_orchestrator` 참인 역할 | 모델 선택 없음 |
| UT-04 | `local_error` | 오류가 있는 schema | 머리 표시 문구 |

## T22 · docs: README 와 사람용 문서 · 규칙 정본 원형에 설정 레이어 반영

### 상위 Requirement

- relates to #207

### 작업 내용

코드가 만든 동작을 사람용 설명과 규칙 정본 원형에 적는다.

- 명세 13 표의 `README.md` · `src/templates/managed/docs/workflow/` · `src/templates/generated/.ai/AI_AGENT.md` 행
- `README.md`
  - 새 절 "설정 레이어" — 레이어 순서와 파일, 병합 규칙 표, `locked`, 개인 레이어(받는 키 · 러너 방식 유지 · 무시 보장 · 추적 금지 · `set --local`), `run-plan`
  - "`harness.toml` 이 정하는 것" 표: `roles.<역할>.enabled` 행, `roles.<역할>.runner · model · access` 행에 모델 · 벤더가 생성물에 들어가지 않고 실행 계획으로 간다는 것,
    `doctor.remote_timeout` 행의 `script/harness.plan.json` 을 실행 계획으로
  - 그 아래 실행 계획 문단과 "파일은 세 부류다" 의 생성 목록에서 `script/harness.plan.json` 을 뺀다. "시작하기" 의 "설정이 없으면 기본값을 깔아" 를 최소 설정으로
- `src/templates/managed/docs/workflow/README.md` · `changing.md` · `flow.md`: "값의 정본은 `harness.toml` 하나" 를 "프로젝트 값은 `harness.toml`, 기본값은 내장 기본값,
  개인 선택은 `harness.local.toml`" 로. `changing.md` 의 역할 삭제를 `harness set roles.<이름>.enabled false` 로, 역할별 모델 행에 서브에이전트 역할은 오케스트레이터 모델을 쓴다는 것
- `src/templates/generated/.ai/AI_AGENT.md`: 10장 배치 표의 `harness.toml` 행을 "프로젝트 레이어 — 기본값과 다르게 정하는 규칙 값" 으로, `harness.local.toml`(개인 레이어,
  커밋하지 않는다) 행과 내장 기본값(고정 사본의 `templates/defaults.toml`, 고치지 않는다) 행을 더한다. 9장 문서 지도의 `harness.toml` 행에 값마다의 출처는 `harness schema` 라는 것
- 생성 파일 머리의 "이 파일은 harness.toml 에서 생성된다" 문구와 역할 계약 · 절차 조각은 바꾸지 않는다
- `src/bin/harness render` 로 이 리포의 `.ai/AI_AGENT.md` · `docs/workflow/` 갱신
- 건드릴 파일: `README.md`, `src/templates/managed/docs/workflow/README.md` · `changing.md` · `flow.md`, `src/templates/generated/.ai/AI_AGENT.md`, render 로 갱신되는 `.ai/AI_AGENT.md` · `docs/workflow/`

### 완료 조건

- [ ] README 에 "설정 레이어" 절이 있고 명세 13 의 README 사실이 모두 반영돼 있다
- [ ] README · 사람용 절차 문서에 `script/harness.plan.json` 을 생성물로 적은 곳과 "값의 정본은 `harness.toml` 하나" 가 없다
- [ ] `changing.md` 의 역할 빼기가 `enabled false` 로 적혀 있다
- [ ] 렌더된 `.ai/AI_AGENT.md` 9장 · 10장에 명세 13 의 행이 있고 `harness check` 가 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 원형 개정 뒤 render, `harness check` | 어긋남 없음 |
| UT-02 | 낡은 서술 | README · `docs/workflow/` 에서 `harness.plan.json` · "정본은 `harness.toml` 하나" 찾기 | 없음 |
| UT-03 | 문서 검증 | `script/run-lint-test.sh` | 통과 |

## T23 · docs: 보호 문서에 설정 레이어와 실행 계획 반영

### 상위 Requirement

- relates to #207

### 작업 내용

에이전트가 근거로 읽는 보호 문서가 레이어 설정과 실행 시점 실행 계획을 담도록 개정한다. 이 개정은 2026-10-09 결정 게이트에서 사용자가 허용한
범위이고, 명세 16절이 적은 위치와 문안만 고친다. 그 범위 밖은 고치지 않는다.

- 명세 16절
- `.ai/project/scope.md`(16-1): 첫 목록 둘째 항목, "사용자" 첫째 · 셋째 항목, "할 수 있는 일" 둘째 항목 끝과 `run` 항목 끝
- `.ai/project/glossary.md`(16-2): "용어" 의 `생성 파일` · `정본` · `실행 계획` 뜻, 새 행 여덟(`레이어` · `내장 기본값` · `개인 레이어` · `공유 설정` · `실효 설정` · `병합 규칙` ·
  `잠금` · `러너 방식`), "폐기된 별칭" 의 두 행 교체와 두 행 추가
- `.ai/project/architecture.md`(16-3): "구성 요소" 의 CLI 패키지 · `src/templates/` 항목, "데이터 흐름" 의 렌더 · 절차 실행(네 곳) · 실행 지표, "신뢰 경계" 의 들어오는 입력,
  "새 코드를 둘 곳" 의 새 설정 키 · 새 역할, "계층과 의존 방향" 의 규칙 값 항목(고치고 더한다), "검사하지 않는 것"
- `.ai/project/testing.md`(16-4): "무엇을 어느 수준으로 검증하나" 첫 항목의 셋째 약속과 같은 절에 더할 항목
- 문안은 #206 이 고친 문장 위에 얹는다
- 네 문서의 내용을 담는 `.ai/AI_AGENT.md` 를 `src/bin/harness render` 로 맞춘다
- 건드릴 파일: `.ai/project/scope.md` · `glossary.md` · `architecture.md` · `testing.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] 네 문서의 고친 위치와 문안이 명세 16-1 ~ 16-4 와 같고 그 밖의 줄은 바뀌지 않는다
- [ ] `glossary.md` 에 새 행 여덟과 폐기된 별칭 네 행이 있다
- [ ] 렌더된 `.ai/AI_AGENT.md` 가 네 문서와 일치하고 `harness check` 가 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/207-layered-config` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 개정 범위 | 이 task 커밋의 네 문서 diff | 명세 16절의 위치만 바뀜 |
| UT-02 | 생성물 일치 | 보호 문서 개정 뒤 render, `harness check` | 어긋남 없음 |
| UT-03 | 문서 검증 | `script/run-lint-test.sh` | 통과 |
