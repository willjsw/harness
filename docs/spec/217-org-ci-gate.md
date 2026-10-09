# 하네스 CI 게이트 생성과 preset 정책 검사

하네스의 머지 전 검증 파일(**CI 게이트**)을 render 가 생성한다. 게이트 본문은 preset 이 공급하는 템플릿이나 내장
템플릿에서 나오고, 프로젝트는 `[ci].setup` 으로 준비 단계만 더한다. `harness check` 는 lock 의 preset 체인이 허용된
출처인지 늘 검사하고, CI 게이트는 조직·그룹 CI 변수로 받은 최소 버전을 함께 검사한다. 여러 리포에 걸친 강제는
조직 ruleset 의 required status check 가 맡고, 하네스는 그 운영 안내를 둔다.

기준 코드는 #216(preset 의 `extends` · lock · vendoring · `harness pull`)이 들어간 통합 브랜치다. CLI 코드는 #206 이 정한
`src/harness/` 모듈 지도에 놓인다. 이 명세는 함수·명령 단위로 적는다(`plan()` · `drift()` · `validate()` ·
`refuse_user_files()` · `doctor_items()` · `cmd_check` 와 그 이식본).

정본 위치:

| 대상 | 정본 |
|---|---|
| CLI (게이트 생성 · 템플릿 고르기 · 설정 검증 · `check` 의 preset 정책 · doctor) | `src/harness/` (모듈 배치는 #206 의 지도) · 진입 `src/bin/harness` |
| 내장 게이트 템플릿 | `src/templates/ci/github/harness-verify.yml` · `src/templates/ci/gitlab/harness-verify.yml` |
| GitLab 루트 파일 원형 | `src/templates/ci/gitlab/gitlab-ci.yml` |
| 설정 기본값과 주석 | 내장 기본값(#207 이 정한 자리) · `src/templates/harness.toml` |
| 운영 안내 | `src/templates/managed/docs/workflow/ci-gate.md` (대상 리포의 `docs/workflow/ci-gate.md`) |
| 회귀 테스트 | `src/test/render-test.sh` · `src/test/unit/` · `src/ui/lib/doctor.test.js` |
| UI 문구 | `src/ui/lib/doctor.js` · `src/ui/lib/help.js` |
| 이 리포의 CI | `.github/workflows/harness-verify.yml`(생성) · `.github/workflows/release.yml`(소유) |

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

- 하네스 루트가 리포 루트이거나 git 작업 트리 밖이면 CI 게이트가 **생성 파일**이다. render 가 매번 쓰고, `.harness/generated`
  에 들고, `check` 가 설정과 대조하고, `uninstall` 이 지운다
- 게이트를 끄는 설정은 없다
- 모노레포 서브프로젝트에서는 게이트를 생성하지 않는다. 그 자리에는 소유 골격을 없을 때만 깐다 (2-1)
- GitLab 의 리포 루트 `.gitlab-ci.yml` 은 소유 파일이다. 없을 때만 게이트를 include 하는 원형을 깔고, 있으면 건드리지 않는다
- 이미 깔린 게이트 경로의 파일은 매니페스트에 없으므로 사용자 파일이다. 하네스 갱신이 그 자리에서 한 번 멈추고 `--adopt` 를 요구한다 (4-1)
- 무엇을 검증할지는 그대로 `[commands]` · `[verify]` 가 정한다. 게이트가 도는 검증 일괄은 `script/run-lint-test.sh` 다
- `check` 에 preset 정책 검사가 더해진다 (5절). 네트워크를 쓰지 않는다. 허용 출처는 pre-commit 의 `check --staged` 에서도 본다.
  최소 버전은 `--min-preset-version` 을 받을 때만 보고, 그 인자는 CI 게이트만 넘긴다
- 게이트는 개인 레이어를 뺀 설정으로 렌더된다(#207). 오케스트레이터·러너·모델 값을 담지 않는다
- 훅 본문(pre-commit · pre-push · commit-msg)은 바뀌지 않는다
- CI 에서 리뷰어 에이전트를 부르지 않고, 리뷰 판정(PASS 댓글)을 머지 조건으로 확인하지 않는다

## 2. CI 게이트 파일

### 2-1. 경로와 부류

| 하네스 루트 | `forge.review_host = "github"` | `forge.review_host = "gitlab"` |
|---|---|---|
| 리포 루트, 또는 git 작업 트리 밖 | 생성: `.github/workflows/harness-verify.yml` | 생성: `.gitlab/harness-verify.yml`<br>소유(없을 때만): `.gitlab-ci.yml` |
| 모노레포 서브프로젝트 | 소유(없을 때만): `.github/workflows/harness-verify.yml` | 소유(없을 때만): `.gitlab-ci.yml` |

- 하네스 루트를 가르는 기준은 forge 이슈·리뷰 요청 템플릿(`forge_templates()`)과 같은 `repo_prefix()` 판정이다
- 생성 게이트는 `plan()` 에 든다. 사용자 파일 판정(spec 58 3-1), 경로 규칙의 사전 판정과 공용 함수(ADR 0017), `drift()`,
  정리(`prune`)를 다른 생성 파일과 똑같이 받는다
- 게이트의 `.harness/generated` 줄에는 해시를 붙이지 않는다. 더는 생성하지 않게 되면 정리가 지운다. 손으로 고친 게이트는 `check` 가 이미 막는다
- 서브프로젝트의 소유 골격은 생성 게이트와 같은 템플릿·변수(2-2 · 2-3)로 만든 본문 앞에 소유 머리말(2-4)을 붙인 것이다.
  소유 파일처럼 없을 때만 깔고, 그 뒤로는 건드리지 않는다
- 없을 때만 까는 경로(소유 파일 · GitLab 루트 파일 · 서브프로젝트 골격)는 지금의 소유 파일처럼 경로 규칙과 부모 디렉터리 판정만 받는다

GitLab 루트 원형(`src/templates/ci/gitlab/gitlab-ci.yml`)의 본문:

```yaml
# 이 리포의 GitLab 파이프라인. 하네스가 없을 때만 깐 것이고 프로젝트 것이다 — render 가 덮지 않고 uninstall 도 지우지 않는다.
# 하네스 CI 게이트는 아래 include 로 들어온다. .gitlab/harness-verify.yml 은 harness.toml 에서 생성된다.
# 프로젝트 job 은 이 파일에 더한다.
include:
  - local: /.gitlab/harness-verify.yml
```

### 2-2. 템플릿 고르기

`forge.review_host` 가 `<host>` 이면, 아래 순서로 처음 찾은 것이 게이트 본문의 템플릿이다.

1. lock 의 체인을 프로젝트가 가리키는 preset(깊이 1)부터 위로 따라가며, vendoring 에 `ci/<host>/harness-verify.yml` 이 있는 첫 preset 의 그 파일
2. 내장 템플릿 `src/templates/ci/<host>/harness-verify.yml` (고정 사본에서는 `.harness/templates/ci/<host>/harness-verify.yml`)

- preset 저장소 형식에 `ci/github/harness-verify.yml` · `ci/gitlab/harness-verify.yml` 두 경로를 더한다. vendoring 이 담는 파일과
  lock 내용 해시의 대상이 그만큼 늘어난다. 해시 정의는 #216 의 것 그대로다
- 템플릿은 vendoring 된 사본에서 읽는다. render 는 네트워크를 쓰지 않는다
- 템플릿이 UTF-8 텍스트가 아니면 render 를 거부한다: `error: the CI template is not UTF-8 text` 와 템플릿 출처 줄

오류의 템플릿 출처 줄은 `  --> built-in ci/<host>/harness-verify.yml` 또는 `  --> preset <출처> ci/<host>/harness-verify.yml` 이다.

### 2-3. 템플릿 변수

CI 템플릿이 쓸 수 있는 변수는 아래 넷뿐이다. 다른 `{{…}}` 와 `{{INCLUDE:…}}` 가 있으면 render 를 거부한다
(`error: unknown template variable(s): <변수>` 와 템플릿 출처 줄). 다른 호스트의 변수도 모르는 변수로 본다.

| 변수 | 호스트 | 자리 | 치환 |
|---|---|---|---|
| `{{CI_BRANCHES}}` | github | 줄 안 | 트리거 브랜치의 JSON 배열 — `["develop", "main"]` |
| `{{CI_BRANCH_RULES}}` | gitlab | 홀로 선 줄 | 트리거 브랜치마다 `- if: $CI_COMMIT_BRANCH == "<브랜치>"` |
| `{{CI_SETUP}}` | 둘 다 | 홀로 선 줄 | `[ci].setup` 의 항목 (3-1). github 는 step, gitlab 은 `before_script` 항목 |
| `{{CI_VERIFY}}` | 둘 다 | 줄 안 | 검증 명령 한 줄. YAML 큰따옴표 스칼라(JSON 문자열 표기)로 |

- **트리거 브랜치**는 `branches.base` 를 맨 앞에 두고 `branches.protected` 를 설정 순서대로 이은 목록이다. 같은 이름은 한 번만 둔다
- **홀로 선 줄**은 그 변수 말고 공백만 있는 줄이다. 치환은 그 줄을 항목 줄들로 바꾸고, 줄마다 원래 줄의 앞 공백을 붙인다.
  항목이 없으면 그 줄을 지운다. 홀로 서야 할 변수가 다른 글자와 한 줄에 있으면 거부한다: `error: {{<변수>}} must stand alone on its line`
- 반드시 있어야 하는 변수: `{{CI_VERIFY}}`, 그 호스트의 브랜치 변수(`{{CI_BRANCHES}}` 또는 `{{CI_BRANCH_RULES}}`), 그리고
  `[ci].setup` 이 비어 있지 않을 때 `{{CI_SETUP}}`. 없으면 거부한다

  | 없는 변수 | 출력 |
  |---|---|
  | `{{CI_VERIFY}}` | `error: the CI template has no {{CI_VERIFY}}` / `help: the gate must run the harness verification` |
  | 브랜치 변수 | `error: the CI template has no {{<변수>}}` / `help: the gate must run on the base and protected branches` |
  | `{{CI_SETUP}}` | `error: the CI template has no {{CI_SETUP}}` / `help: [ci].setup has steps and this template has no place for them` |

- 대문자·밑줄만으로 된 이름이 아닌 `${{ … }}`(GitHub Actions 식)는 변수가 아니다. 그대로 남는다
- 거부는 모두 종료 코드 2 이고 아무것도 쓰지 않는다 — render 의 다른 사전 판정과 같은 자리에서 본다

`{{CI_VERIFY}}` 가 내는 명령:

| `policy.check_min_preset_version` | 명령 |
|---|---|
| `false` | `script/run-lint-test.sh` |
| `true` | `<CLI> check --min-preset-version "$HARNESS_MIN_PRESET_VERSION" && script/run-lint-test.sh` |

- `<CLI>` 는 하네스 루트가 하네스 소스 리포(`source_tree()`)면 `src/bin/harness`, 아니면 `.harness/bin/harness` 다
- 게이트 템플릿은 검증 명령을 직접 적지 않는다. 검증 진입점은 이 값으로만 정해진다

`{{CI_SETUP}}` 이 내는 항목 줄. 3-1 의 예라면 이렇다. 값은 모두 JSON 문자열 표기다.

```yaml
# github
- uses: "actions/setup-node@v4"
  with:
    node-version: "20"
- run: "npm ci"
```

```yaml
# gitlab (run 항목만)
- "npm ci"
```

### 2-4. 머리말

render 는 치환한 템플릿 본문 앞에 머리말 주석을 붙인다. 템플릿 자신의 주석은 그 뒤에 그대로 남는다.

생성 게이트:

```
# 하네스 CI 게이트 — harness.toml 과 preset 에서 생성된다. 직접 고치지 않는다(harness check 가 어긋남을 막는다).
# 템플릿: 내장 | preset <출처>
# 프로젝트 준비 단계는 harness.toml 의 [ci].setup 에 둔다. 운영 안내: docs/workflow/ci-gate.md
```

서브프로젝트 소유 골격:

```
# 하네스가 없을 때만 깐 CI 골격이다. 프로젝트 것이다 — render 가 덮지 않고 uninstall 도 지우지 않는다.
# 이 하네스 루트는 리포의 서브프로젝트라서 하네스가 CI 게이트를 생성하지 않는다.
# (github) GitHub 은 리포 루트의 .github/workflows/ 만 읽는다. 이 파일을 리포 루트로 옮기고 defaults.run.working-directory 를 이 서브프로젝트 경로로 맞춘다.
# (gitlab) GitLab 은 리포 루트의 .gitlab-ci.yml 만 읽는다. 이 파일을 리포 루트로 옮기고 default.before_script 에 cd <이 서브프로젝트 경로> 를 둔다.
```

셋째 줄은 그 호스트의 것 하나만 쓰고 `(github)` · `(gitlab)` 표시는 넣지 않는다.

### 2-5. 내장 템플릿

`src/templates/ci/github/harness-verify.yml`:

```yaml
name: harness verify

on:
  pull_request:
    branches: {{CI_BRANCHES}}
  push:
    branches: {{CI_BRANCHES}}

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      {{CI_SETUP}}
      - name: harness verify
        env:
          HARNESS_MIN_PRESET_VERSION: ${{ vars.HARNESS_MIN_PRESET_VERSION }}
        run: {{CI_VERIFY}}
```

`src/templates/ci/gitlab/harness-verify.yml`:

```yaml
# 검증 상태: 미검증 — 실제 GitLab 에서 돌려 보지 않았다.
harness-verify:
  image: python:3.11-slim
  before_script:
    - apt-get update -qq && apt-get install -y -qq git >/dev/null
    {{CI_SETUP}}
  script:
    - {{CI_VERIFY}}
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    {{CI_BRANCH_RULES}}
```

- 체크 이름: github 는 워크플로 `harness verify` 의 job `verify`, gitlab 은 job `harness-verify` 다. GitHub 조직 ruleset 의
  required status check 가 github 의 이름을 가리킨다. preset 템플릿이 그 이름을 바꾸면 ruleset 도 함께 바꿔야 한다 (7절)
- gitlab 의 `HARNESS_MIN_PRESET_VERSION` 은 그룹 CI 변수가 job 환경 변수로 들어온 값이다 <!-- TBD: 확인 필요 -->

## 3. 설정

### 3-1. `[ci]`

```toml
# CI 게이트(.github/workflows/harness-verify.yml · .gitlab/harness-verify.yml, 생성 파일)
#   setup  검증 전에 도는 이 프로젝트의 준비 단계. 항목마다 run(셸 한 줄) 또는 uses(GitHub action, with 는 선택)
#          언어 런타임·이미지와 체크 이름은 CI 템플릿(스택 preset 또는 내장)이 정한다
[ci]
setup = []
```

예:

```toml
[ci]
setup = [
  { uses = "actions/setup-node@v4", with = { node-version = "20" } },
  { run = "npm ci" },
]
```

| 규칙 | 어기면 (종료 코드 2) |
|---|---|
| `[ci]` 의 키는 `setup` 뿐이다 | `error: unknown key(s) in [ci]: <키> ...` / `help: the keys are setup` |
| `setup` 은 표의 배열이다 | `error: ci.setup must be a list of tables with run or uses` |
| 항목의 키는 `run` · `uses` · `with` 뿐이다 | `error: unknown key(s) in ci.setup[<번호>]: <키> ...` / `help: the keys are run, uses, with` |
| `run` 과 `uses` 가운데 정확히 하나가 있다 | `error: ci.setup[<번호>] needs exactly one of run, uses` |
| `run` 은 줄바꿈 없는 비지 않은 문자열이다 | `error: ci.setup[<번호>].run must be one non-empty line` |
| `uses` 는 `^[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[A-Za-z0-9_.-]+$` 이다 | `error: ci.setup[<번호>].uses must be owner/repo@ref` |
| `with` 는 `uses` 와 함께만 쓰고, 키는 `^[A-Za-z0-9_-]+$`, 값은 줄바꿈 없는 문자열이다 | `error: ci.setup[<번호>].with must be a table of strings next to uses` |
| `forge.review_host = "gitlab"` 이면 `uses` 를 쓰지 않는다 | `error: ci.setup[<번호>] uses an action, which GitLab does not run` / `help: use run, or a stack preset whose GitLab template prepares that runtime` |

- `<번호>` 는 1부터 센다. 항목의 값은 출력에 옮기지 않는다

### 3-2. `[policy]`

```toml
# preset 정책 — 조직 preset 이 정하고 locked 로 잠근다
#   preset_sources            lock 의 체인이 쓸 수 있는 preset 출처. 비우면 제한하지 않는다. / 로 끝나는 항목은 그 아래 전부
#   check_min_preset_version  CI 게이트가 조직·그룹 CI 변수 HARNESS_MIN_PRESET_VERSION 으로 preset 최소 버전을 검사하는가
[policy]
preset_sources = []
check_min_preset_version = false
```

| 규칙 | 어기면 (종료 코드 2) |
|---|---|
| `[policy]` 의 키는 위 둘뿐이다 | `error: unknown key(s) in [policy]: <키> ...` / `help: the keys are preset_sources, check_min_preset_version` |
| `preset_sources` 는 문자열 배열이고, 항목은 `https://` 또는 `oci://` 로 시작하며 공백·줄바꿈·자격증명(호스트 앞의 `@`)이 없다 | `error: policy.preset_sources[<번호>] must be an https:// or oci:// source without credentials` |
| `check_min_preset_version` 은 불리언이다 | `error: policy.check_min_preset_version must be true or false` |

- 기본값은 출처 제한 없음, 최소 버전 검사 없음이다. preset 을 쓰지 않는 프로젝트에서는 두 키가 아무 일도 하지 않는다

### 3-3. 계층 병합 (#207)

| 키 | 병합 | 개인 레이어 |
|---|---|---|
| `ci.setup` | 일반 배열 — 교체 | 쓸 수 없다 |
| `policy.preset_sources` | 일반 배열 — 교체 | 쓸 수 없다 |
| `policy.check_min_preset_version` | 스칼라 — 덮어쓰기 | 쓸 수 없다 |

- 조직 preset 이 `policy.*` 를 `locked` 로 잠근다. 잠긴 키를 아래 레이어가 다른 값으로 적으면 #207 의 규칙대로 거부한다
- `[ci]` · `[policy]` 절이 없는 설정은 기본값으로 돈다. 이 리포 루트의 `harness.toml` 도 이 절 없이 돈다
- `harness schema` 가 세 키를 다른 키와 같은 방식으로 내준다. `src/ui/lib/help.js` 에 세 키의 도움말을 한 줄씩 둔다

## 4. 넘겨받기 · 갱신 · 제거

### 4-1. 기존 설치본 넘겨받기

- 리포 루트에 설치된 GitHub 설치본의 `.github/workflows/harness-verify.yml` 은 이전 매니페스트에 없다. 그 경로를 쓰는 명령
  (install · render · set · steps · checks, write-doc 의 render)은 spec 58 3절대로 아무것도 쓰지 않고 종료 코드 2 로 멈춘다.
  `--adopt` 를 주면 그 파일을 `.github/workflows/harness-verify.yml.orig` 로 옮기고 게이트를 쓴다
- 멈출 때의 안내문(spec 58 3-3)은, 찾은 경로에 생성 게이트 경로가 있으면 `help:` 끝에 한 줄을 더한다

  ```
        the CI gate is generated now — move your extra steps into [ci].setup in harness.toml, then delete the .orig (docs/workflow/ci-gate.md)
  ```

- UI 는 `--adopt` 를 넘기지 않는다. 사람이 터미널에서 `harness install --adopt` 또는 `harness render --adopt` 를 돈다.
  doctor 가 그 명령을 알린다 (6절)
- `.orig` 는 매니페스트에 들지 않는다. render 가 덮지도 지우지도 않는다(spec 58 3-4). 지우는 것은 사람이다
- GitLab 설치본의 루트 `.gitlab-ci.yml` 은 생성 경로가 아니라서 멈추지 않는다. `.gitlab/harness-verify.yml` 이 새로 생기고
  루트 파일은 그대로다. 루트 파일의 옛 `harness-verify` job 을 include 로 바꾸는 것은 사람이 한다. doctor 가 알린다 (6절)

### 4-2. `forge.review_host` 를 바꿀 때

- 옛 호스트의 생성 게이트는 정리가 지우고, 새 호스트의 게이트를 생성한다
- github → gitlab: 루트 `.gitlab-ci.yml` 이 없으면 원형을 깔고, 있으면 그대로 둔다
- gitlab → github: 루트 `.gitlab-ci.yml` 은 소유 파일이라 남는다
- 서브프로젝트의 소유 골격은 바꾸지 않는다. 새 호스트의 골격 경로가 비어 있으면 깐다

### 4-3. uninstall

- 생성 게이트를 다른 생성 파일과 함께 지운다. 그 디렉터리가 비면 지운다(지금 규칙)
- 루트 `.gitlab-ci.yml` · 서브프로젝트 골격 · `.orig` 는 `--purge` 를 줘도 지우지 않는다. 프로젝트의 파이프라인일 수 있다
- 끝의 `untouched:` 목록(`.github/workflows` · `.gitlab-ci.yml`)은 그대로다

## 5. `harness check` 의 preset 정책

### 5-1. 범위와 순서

`check` 는 지금 보는 것(매니페스트 줄 · 생성물 일치 · 관리 파일 대조)과 #216 의 lock · vendoring 대조에 아래 둘을 더 본다.

| 검사 | 언제 | 기준값 |
|---|---|---|
| 허용 출처 | `policy.preset_sources` 가 비어 있지 않으면 늘 (`--staged` 포함) | 설정의 `policy.preset_sources` |
| 최소 버전 | `--min-preset-version` 을 받았을 때만 | 그 인자 |

- 두 검사의 대상은 lock 체인의 항목 전부다. 항목마다 출처(태그를 뺀 참조)와 태그를 본다. 필드 이름과 lock 을 읽는 방법은
  #216 · #218 의 것이다. `--staged` 면 lock 을 인덱스에서 읽는다 — 생성물 대조와 같다
- `extends` 가 없으면 체인이 비어 있으므로 두 검사는 아무것도 보지 않고 통과한다
- #216 의 lock 대조가 실패하면 이 둘은 돌지 않는다. 기준으로 삼을 체인이 없기 때문이다
- lock 과 vendoring 의 일치는 #216 의 대조가 이미 본다. 이 명세는 그 대조를 다시 만들지 않고, 대조 대상에 CI 템플릿 경로를 더할 뿐이다 (2-2)
- 네트워크를 쓰지 않는다
- `COMMANDS` 표의 `check` 사용법은 `[--staged] [--min-preset-version <list>]` 이고, README 의 명령 표도 같다

### 5-2. 허용 출처

체인 항목의 출처는 `policy.preset_sources` 의 값 가운데 하나와 맞아야 한다.

- 값이 `/` 로 끝나면, 출처가 그 값으로 시작할 때 맞는다
- 그 밖의 값은 출처와 같을 때 맞는다
- 비교는 바이트 단위다. 대소문자나 끝의 `/` 를 정규화하지 않는다

### 5-3. 최소 버전 — `--min-preset-version <list>`

`<list>` 는 공백(스페이스 · 탭 · 줄바꿈)으로 나뉜 항목들이다. 항목은 `<출처>=<최소 버전>` 이고 마지막 `=` 에서 나눈다.
예(실제 값이 아니다):

```
https://git.example.com/org/preset-base=v1.4.0 https://git.example.com/org/preset-python=2.1.0
```

- 체인 항목의 출처와 같은 출처를 가진 목록 항목이 있으면, 그 체인 항목의 태그가 최소 버전 이상이어야 한다
- 목록에 없는 체인 항목은 보지 않는다. 체인에 없는 목록 항목은 무시한다 — 조직 변수 하나가 여러 스택의 preset 을 담는다
- 인자는 다른 검사보다 먼저 본다. 어기면 아무것도 검사하지 않고 종료 코드 2 로 끝난다

  | 경우 | 출력 |
  |---|---|
  | 값이 비었다(공백뿐도 포함) | `error: --min-preset-version is empty`<br>`help: the CI gate passes HARNESS_MIN_PRESET_VERSION here — set it as an organization or group CI variable (docs/workflow/ci-gate.md)` |
  | 항목에 `=` 가 없거나, 그 앞이나 뒤가 비었다 | `error: --min-preset-version entry <번호> is not <source>=<version>` |
  | 최소 버전이 5-4 의 형식이 아니다 | `error: --min-preset-version entry <번호> has a minimum that is not a version (like v1.2.3)` |
  | 한 출처가 두 번 나온다 | `error: --min-preset-version names one source twice (entries <번호>, <번호>)` |

- `<번호>` 는 1부터 센다. 인자 값은 출력에 옮기지 않는다 — CI 로그에 남기 때문이다

### 5-4. 버전 비교

- 버전의 형식은 `^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$` 이다. 앞의 `v` 는 있으나 없으나 같다
- 세 수를 앞에서부터 정수로 비교한다
- 최소 버전이 걸린 체인 항목의 태그가 이 형식이 아니면(예: `v1.2.0-rc1`) 위반이다. 최소 버전 이상인지 알 수 없기 때문이다

### 5-5. 출력과 종료 코드

위반은 기존 오류들 뒤에 표준 오류로 낸다. 위반이 하나라도 있으면 종료 코드 1 이다. 아래 출처와 태그는 예시다.

```
error: preset source(s) not allowed by policy.preset_sources
  chain 2  https://git.example.com/other/preset-python

help: point extends at an allowed preset, then run harness pull
      policy.preset_sources usually comes locked from the organization preset
```

```
error: preset version(s) below the minimum given by --min-preset-version
  chain 1  https://git.example.com/org/preset-python  v2.0.3 < 2.1.0
  chain 2  https://git.example.com/org/preset-base  tag 2026-10 is not a version (like v1.2.3)

help: raise extends to the minimum or later, then run harness pull
```

- `chain <n>` 은 체인 깊이다. 프로젝트가 가리키는 preset 이 1 이다
- 출처와 태그는 lock 에 커밋된 값이다. #216 이 `extends` 에 자격증명을 받지 않으므로 그대로 출력한다
- 통과하면 기존 두 줄 뒤에, 본 검사마다 한 줄을 더한다
  - 허용 출처: `check: <n> preset source(s) allowed by policy`
  - 최소 버전: `check: <n> preset version(s) meet the minimum, <m> without one`

## 6. `harness doctor`

`generated files` 절 뒤에 `ci gate` 절을 둔다. 줄은 아래 표의 조건마다 하나다.

| 조건 | 상태 | `what` | `detail` |
|---|---|---|---|
| 게이트를 생성하는 루트이고, 게이트 경로가 이전 매니페스트에 있다 | ok | `<게이트 경로>` | `template: built-in` 또는 `template: preset <출처>` |
| 게이트를 생성하는 루트이고, 게이트 경로에 매니페스트에 없는 파일이 있다 | warn | `<게이트 경로> is the project's file, not the generated gate` | ``run `harness render --adopt` — see docs/workflow/ci-gate.md`` |
| 게이트를 생성하는 루트이고, 게이트 경로에 아무것도 없다 | bad | `<게이트 경로> is missing` | ``run `harness render` `` |
| gitlab, 게이트를 생성하는 루트이고, 루트 `.gitlab-ci.yml` 이 없다 | warn | `.gitlab-ci.yml is missing` | ``the CI gate does not run — `harness render` puts the template back`` |
| gitlab, 게이트를 생성하는 루트이고, 루트 `.gitlab-ci.yml` 에 `.gitlab/harness-verify.yml` 이 든 줄이 없다 | warn | `.gitlab-ci.yml does not include .gitlab/harness-verify.yml` | `add it under include: — see docs/workflow/ci-gate.md` |
| 게이트를 생성하는 루트이고, 게이트가 아닌 CI 파일에 `script/run-lint-test.sh` 가 든 줄이 있다 | warn | `<경로> runs script/run-lint-test.sh` | `the CI gate runs the harness verification — drop that job` |
| 서브프로젝트 | ok | `no CI gate in a subproject` | `the forge reads CI files only at the repository root; <골격 경로> is the project's` |
| `policy.preset_sources` 가 비어 있지 않다 | ok · bad | `preset sources allowed by policy` · `<n> preset source(s) not allowed by policy` | (없음) · ``run `harness check` `` |
| `policy.check_min_preset_version` 이 참이다 | ok | `the CI gate checks minimum preset versions` | `HARNESS_MIN_PRESET_VERSION must be set for the organization or group — doctor cannot see it` |

- "게이트를 생성하는 루트" 는 2-1 표의 첫 행(리포 루트, 또는 git 작업 트리 밖)이다
- "게이트가 아닌 CI 파일" 은 github 면 `.github/workflows/` 바로 아래의 `*.yml` · `*.yaml` 가운데 게이트가 아닌 것, gitlab 이면
  루트 `.gitlab-ci.yml` 이다. 판정은 줄에 문자열이 있는지만 본다 — YAML 을 해석하지 않는다
- 원격(forge 설정 · 조직 ruleset · CI 변수)은 보지 않는다. `--remote` 에도 더하지 않는다
- UI: `src/ui/lib/doctor.js` 의 `SECTIONS` 에 `"ci gate": "CI 게이트"` 를 두고, 새 줄마다 사람이 읽는 설명을 둔다

## 7. 운영 안내 — `docs/workflow/ci-gate.md`

관리 문서다. 정본은 `src/templates/managed/docs/workflow/ci-gate.md` 이고, `docs/workflow/README.md` 의 문서 표에 한 행을 더한다.
담는 것:

1. **무엇이 생성되는가** — 2-1 의 표. 서브프로젝트에는 게이트를 생성하지 않는다
2. **보장 범위** — 게이트가 잡는 것은 실수로 생긴 어긋남이다
   - 잡는 것: 훅이 꺼진 클론에서 들어온 생성물·관리 파일의 어긋남, 손으로 고친 게이트, lock 과 맞지 않는 vendoring,
     허용되지 않은 출처의 preset, 최소 버전 변수를 걸었을 때 오래된 preset
   - 잡지 못하는 것: 쓰기 권한이 있는 사람이 게이트·고정 사본·vendoring·lock 을 함께 고친 변경(게이트는 리포 안의 고정 사본으로 돈다),
     `[ci].setup` 단계가 검증 전에 작업 트리를 바꾸는 것, 프로젝트가 `extends` 를 조직 preset 을 잇지 않는 체인으로 바꾸는 것
     (정책 키가 함께 사라진다), 모노레포 서브프로젝트. 이것들은 리뷰 요청의 사람 리뷰가 받는다
3. **여러 리포에 걸친 강제** — 조직 ruleset 의 required status check 로 게이트의 체크 이름(github 는 `verify`)을 base 와
   보호 브랜치에 건다. 하네스는 forge 의 ruleset 과 브랜치 보호를 설정하지 않는다
   - 조직 ruleset 을 쓸 수 있는 GitHub 플랜 조건 <!-- TBD: 확인 필요 -->
   - ruleset 에서 이 체크를 어떤 이름으로 지정하는지, 같은 이름의 다른 워크플로 job 이 그 체크를 채울 수 있는지, 체크의 출처를 지정할 수 있는지 <!-- TBD: 확인 필요 -->
4. **최소 버전 변수** — 조직 preset 이 `policy.check_min_preset_version = true` 를 잠그고, 조직(GitHub Actions 조직 변수)이나
   그룹(GitLab 그룹 CI 변수)에 `HARNESS_MIN_PRESET_VERSION` 을 5-3 형식으로 둔다. 변수가 비어 있으면 게이트가 실패한다
   - GitHub 조직 변수를 private 리포의 워크플로가 읽을 수 있는 플랜·정책 조건 <!-- TBD: 확인 필요 -->
5. **preset 작성자에게** — `ci/<host>/harness-verify.yml` 템플릿, 2-3 의 변수 규칙, 머리말은 render 가 붙인다는 것,
   체크 이름을 바꾸면 ruleset 도 바꿔야 한다는 것, `ci/` 를 담은 preset 은 요구 하네스 버전(#216 의 필드)을 이 기능이 든
   릴리스 이상으로 선언한다는 것, `policy.*` 는 조직 preset 이 `locked` 로 잠근다는 것
6. **이관**
   - GitHub: `harness install --adopt`(또는 `render --adopt`) → `.orig` 에 있던 프로젝트 단계를 `[ci].setup` 으로 옮긴다 → `.orig` 를 지운다 → 커밋한다
   - GitLab: 루트 `.gitlab-ci.yml` 의 옛 `harness-verify` job 을 지우고 `include:` 에 `- local: /.gitlab/harness-verify.yml` 을 더한다
   - 다른 워크플로가 `script/run-lint-test.sh` 를 부르면 그 job 을 지운다(doctor 가 알린다)
7. **GitLab** — 실제 GitLab 으로 검증하지 않았다
   - 그룹 단위로 파이프라인 성공을 머지 조건으로 거는 조건과 플랜 <!-- TBD: 확인 필요 -->
   - `include: local` 의 경로 표기 <!-- TBD: 확인 필요 -->

## 8. 이 리포의 이관

구현과 같은 리뷰 요청에서 한다. 게이트가 생성 파일이 되면 이 리포의 CI(`check`)가 곧바로 그것을 대조하기 때문이다.

1. `src/bin/harness render --adopt` 로 `.github/workflows/harness-verify.yml` 을 넘겨받고, `.orig` 를 지운다. 생성 게이트의
   트리거 브랜치는 `["develop", "main"]` 이고, `[ci].setup` 은 비어 있고, `{{CI_VERIFY}}` 는 `script/run-lint-test.sh` 다
2. 지금 그 파일에 있는 `release` job 을 소유 파일 `.github/workflows/release.yml` 로 옮긴다

   ```yaml
   # main 에서 검증을 통과한 커밋을 GitHub Release 로 낸다. 이 리포의 배포 절차이고 프로젝트 소유 파일이다 — render 가 덮지 않는다.
   # 검증은 생성된 CI 게이트(워크플로 harness verify)가 한다. 그 실행이 main push 에서 성공으로 끝났을 때만 돈다.
   name: release

   on:
     workflow_run:
       workflows: ["harness verify"]
       types: [completed]
       branches: [main]

   jobs:
     release:
       if: github.event.workflow_run.conclusion == 'success' && github.event.workflow_run.event == 'push'
       runs-on: ubuntu-latest
       permissions:
         contents: write
       steps:
         - uses: actions/checkout@v4
           with:
             ref: ${{ github.event.workflow_run.head_sha }}
         - uses: actions/setup-python@v5
           with:
             python-version: "3.11"
         - name: create release
           env:
             GH_TOKEN: ${{ github.token }}
             HEAD_SHA: ${{ github.event.workflow_run.head_sha }}
           run: |
             # 지금 release job 의 스크립트 그대로. 마지막 줄의 --target "$GITHUB_SHA" 만 --target "$HEAD_SHA" 로 바꾼다
   ```

   - 태그 형식(`v<번호>+<커밋 7자리>`), 버전 검사, 같은 커밋을 다시 돌릴 때 이미 있는 릴리스를 두는 처리는 그대로다
   - `workflow_run` 은 기본 브랜치(`develop`)에 있는 `release.yml` 로 돈다 <!-- TBD: 확인 필요 -->. 첫 main 릴리스에서
     Release 가 생기는지 사람이 확인한다
3. README "업데이트" 절의 릴리스 서술을 위 동작에 맞춘다

## 9. 다른 이슈와의 경계

| 이슈 | 경계 |
|---|---|
| #216 | 체인 순서(깊이 1 = 프로젝트가 가리키는 preset), lock 의 출처·태그 필드, vendoring 경로, lock · vendoring 대조는 #216 이 정한다. 이 명세는 preset 저장소 형식에 `ci/<host>/harness-verify.yml` 두 경로를 더하고, 그 파일들이 vendoring 과 내용 해시에 든다. pull 의 멈춤 조건(5종)은 늘리지 않는다 |
| #218 | OCI preset 아티팩트의 레이어에 같은 `ci/` 경로가 든다(아티팩트 형식은 #218 이 정한다). 허용 출처·최소 버전은 `oci://` 출처와 OCI 태그에도 같은 규칙을 쓴다. 대상 리포 CI 는 레지스트리에 붙지 않는다. #218 의 레지스트리 통합 테스트 워크플로는 게이트와 다른 경로의 소유 파일이다 |
| #219 | 대상 리포 CI 는 레지스트리 없이 커밋된 vendoring 과 lock 으로 검사한다 |
| #207 | `[ci]` · `[policy]` 의 병합 규칙은 3-3 이고 #207 의 병합 규칙 표에 더한다. 조직은 `locked` 로 잠근다. 개인 레이어 허용 키가 아니다. 보호 브랜치 합집합이 트리거 브랜치에 그대로 들어간다 |
| #206 | 코드는 `src/harness/` 모듈 지도에 놓인다 |
| #213 · shim 정리 Requirement | `script/run-lint-test.sh` 는 #213 이 shim 으로 남긴다. 이 명세가 든 릴리스부터는 리포 루트의 하네스 CI 파일을 render 가 쓴다. 그래서 기존 설치본의 소유 CI 파일 때문에 그 shim 을 둘 이유가 사라진다. shim 을 걷는 일과 `{{CI_VERIFY}}` 가 내는 명령을 새 검증 진입점으로 바꾸는 일은 shim·셸 생성물 정리 Requirement 가 함께 한다. 남은 옛 호출(GitLab 루트 파일, 다른 워크플로)은 6절의 doctor 가 알린다 |
| 하네스 최소 버전 | 대상 리포 하네스의 최소 버전은 #216 의 pull 멈춤 조건(요구 하네스 버전 미달)이 맡는다. 이 명세의 최소 버전은 preset 버전이다 |

## 10. 함께 고치는 현재형 문서

| 문서 | 고칠 것 |
|---|---|
| README "파일은 세 부류다" 표 | 생성 행에 CI 게이트(`.github/workflows/harness-verify.yml` · `.gitlab/harness-verify.yml`)를 더한다. 소유 행의 "CI 설정" 을 "GitLab 의 루트 `.gitlab-ci.yml` · 서브프로젝트 CI 골격" 으로 바꾼다 |
| README "CI 설정은 첫 설치 때 한 번만 깔린다" 단락 | 2-1 · 4절의 사실로 바꾼다. 게이트는 생성 파일이고, 서브프로젝트 골격과 GitLab 루트 파일은 소유 파일이다. 기존 파일은 `--adopt` 로 넘겨받고, uninstall 이 게이트를 지우고, 운영 안내는 `docs/workflow/ci-gate.md` 에 있다 |
| README "`harness.toml` 이 정하는 것" 표 | `ci.setup` 행과 `policy.preset_sources` · `check_min_preset_version` 행을 더한다. `branches.base` · `protected` 행에 "CI 게이트의 트리거 브랜치", `forge.tracker` · `review_host` 행에 "CI 게이트 경로" 를 더한다 |
| README 명령 표 | `harness check` 행에 `--min-preset-version`(CI 게이트가 넘긴다) |
| README "업데이트" 절 | 8절의 릴리스 동작 |
| `docs/workflow/flow.md` 층 표의 CI 행 | 막는 대상에 "설정과 어긋난 생성물·관리 파일, preset 정책", 우회에 "필수 체크 지정은 forge 설정이다(`docs/workflow/ci-gate.md`)" |
| `docs/workflow/flow.md` 검증 루프 | 머지 전 CI 줄에 preset 정책 검사를 더한다 |
| `docs/workflow/README.md` 문서 표 | `ci-gate.md` 행 |
| `docs/spec/58-separate-managed-and-project-parts.md` 3-1 | "소유 파일과 CI 골격은 대상이 아니다" 를 "소유 파일 · GitLab 루트 파일 · 서브프로젝트 CI 골격은 대상이 아니다. CI 게이트는 생성 파일이라 대상이다" 로 바꾼다. 같은 문서의 "CI 골격" 표기도 같은 뜻으로 맞춘다 |
| `docs/spec/60-automate-work-prerequisites.md` | "`.github/workflows/` · `.gitlab-ci.yml`(CI 골격, 소유 파일)" 을 "CI 게이트(생성) · GitLab 루트 `.gitlab-ci.yml`(소유)" 로 바꾼다 |

`docs/workflow/` 는 관리 문서라서 정본 `src/templates/managed/docs/workflow/` 를 고치고, 이 리포의 `docs/workflow/` 는 render 로 따라온다.

## 11. 회귀 테스트

테스트는 임시 디렉터리에서만 돈다. preset 은 #216 의 방식(로컬 bare 리포를 임시 `GIT_CONFIG_GLOBAL` 의 insteadOf 로 잇기)으로 만든다.
네트워크와 실제 forge 는 쓰지 않는다.

### 11-1. `src/test/render-test.sh`

| 케이스 | 확인하는 것 |
|---|---|
| github 게이트 생성 | 리포 루트 설치에서 `.github/workflows/harness-verify.yml` 이 생기고 `.harness/generated` 에 있다. 머리말 세 줄, 트리거 브랜치가 base 와 보호 브랜치(중복 없이, base 먼저), `run: "script/run-lint-test.sh"` |
| 손편집 | 게이트를 고치면 `check` 와 `check --staged` 가 `differs from the config` 로 1. render 가 되돌린다 |
| 넘겨받기 | 매니페스트에 없는 게이트 파일이 있으면 render · install 이 종료 코드 2 이고 아무것도 쓰지 않으며, 안내문에 CI 줄이 있다. `--adopt` 면 `.orig` 와 생성 게이트가 생기고, `.orig` 는 매니페스트에 없다 |
| gitlab 게이트 생성 | `.gitlab/harness-verify.yml` 이 생성되고 루트 원형(include 줄)이 깔린다. 이미 있는 루트 `.gitlab-ci.yml` 은 바이트 그대로다 |
| 서브프로젝트 | `plan()` 에 게이트가 없다. 골격이 소유 머리말과 함께 없을 때만 깔리고, 고친 골격을 render 가 덮지 않는다 |
| 호스트 전환 | github → gitlab 에서 옛 게이트가 지워지고 새 게이트와 루트 원형이 생긴다. gitlab → github 에서 루트 `.gitlab-ci.yml` 은 남는다 |
| uninstall | 게이트가 지워지고 `.orig` · 루트 `.gitlab-ci.yml` 은 남는다. `--purge --yes` 도 그 둘을 남긴다 |
| `[ci].setup` 렌더 | `run` · `uses` · `with` 가 github step 으로, `run` 이 gitlab `before_script` 항목으로 들어간다. 비어 있으면 표지 줄이 사라진다 |
| `[ci]` · `[policy]` 검증 | 3-1 · 3-2 표의 위반마다 render 가 종료 코드 2 로 거부한다. gitlab 에서 `uses` 를 거부한다. 절이 없는 설정은 기본값으로 렌더된다 |
| preset 템플릿 고르기 | 조직·스택 두 단계 체인에서 스택 preset 의 템플릿을 쓰고, 스택에 없으면 조직 것, 둘 다 없으면 내장을 쓴다. 머리말의 템플릿 출처가 그것과 맞다 |
| 템플릿 규칙 | `{{CI_VERIFY}}` 없음, 브랜치 변수 없음, setup 이 있는데 `{{CI_SETUP}}` 없음, 홀로 서지 않은 표지, 모르는 변수, 다른 호스트의 변수, `{{INCLUDE:…}}`, UTF-8 이 아닌 템플릿 — 각각 render 를 거부하고 아무것도 쓰지 않는다. `${{ vars.X }}` 는 그대로 남는다 |
| vendoring 해시 | vendoring 된 `ci/github/harness-verify.yml` 을 고치면 #216 의 lock 대조가 render · check 를 멈춘다 |
| 허용 출처 | 같은 값, `/` 접두, 어긋남을 가른다. 깊이 2 항목의 출처만 어긋나도 잡는다. `--staged` 가 인덱스의 lock 을 본다. pre-commit 이 커밋을 막는다. 값이 비어 있으면 검사하지 않는다 |
| 최소 버전 | 이상이면 통과, 미만이면 1, 버전이 아닌 태그면 1, 빈 값 · 형식 어긋남 · 중복은 2(다른 검사 없이). 목록에 없는 체인 항목은 보지 않고, 인자가 없으면 검사하지 않는다 |
| `{{CI_VERIFY}}` | `check_min_preset_version = true` 면 대상 리포는 `.harness/bin/harness check --min-preset-version …`, 소스 트리 복제는 `src/bin/harness check --min-preset-version …` 이다. 거짓이면 `script/run-lint-test.sh` 뿐이다 |
| 게이트 명령 실행 | 설치한 임시 리포에서 생성 게이트의 `run:` 값(JSON 문자열로 풀어서)을 셸로 돌리면 0 이다. 정책을 켜고 `HARNESS_MIN_PRESET_VERSION` 을 비우면 2 다 |
| doctor | 6절 표의 줄마다 해당 조건을 만들어 상태·`what` 을 확인한다 |
| 터미널 출력 | 새 오류와 안내에 한글이 없다 |

### 11-2. `src/test/unit/`

| 대상 | 확인하는 것 |
|---|---|
| 버전 파싱·비교 | 5-4 형식의 받기·거부, `v` 유무가 같음, 수 비교(`1.10.0 > 1.9.0`) |
| `--min-preset-version` 파싱 | 공백 종류, 마지막 `=` 로 나누기, 빈 값 · 형식 어긋남 · 중복 |
| 출처 일치 | `/` 로 끝나는 값의 접두 일치, 그 밖은 같음, 끝 `/` 를 정규화하지 않음 |
| 표지 줄 치환 | 앞 공백 붙이기, 빈 목록이면 줄 삭제, 홀로 서지 않은 표지 거부 |
| setup 항목 렌더 | github 의 `uses` · `with` · `run`, gitlab 의 `run`, JSON 문자열 표기 |

### 11-3. UI

`src/ui/lib/doctor.test.js` 에 `ci gate` 절의 줄마다 설명이 나오는 케이스를 더한다.

회귀 테스트 전체(`script/run-lint-test.sh`)가 통과한다.

## 12. 보호 문서 개정 범위

분해의 task 하나가 아래 범위 안에서만 고친다. 문서의 다른 절은 건드리지 않는다.

### 12-1. `.ai/project/architecture.md`

| 위치 | 반영할 사실 |
|---|---|
| "구성 요소" 의 `src/templates/` | `ci/<host>/`(CI 골격) → `ci/<host>/`(CI 게이트 내장 템플릿과 GitLab 루트 파일 원형) |
| "데이터 흐름" 의 렌더 | 생성 파일 목록에 CI 게이트를 더한다 — `forge.review_host` 별 경로(`.github/workflows/harness-verify.yml` · `.gitlab/harness-verify.yml`)이고, 하네스 루트가 리포 루트이거나 git 작업 트리 밖일 때만 만든다. 템플릿은 lock 체인에서 가장 가까운 preset 의 것이고, 없으면 내장 템플릿이다 |
| "신뢰 경계" 의 들어오는 입력 | preset 이 공급하는 CI 템플릿(vendoring 사본. 변수 규칙을 어기면 render 를 거부한다), 조직·그룹 CI 변수 `HARNESS_MIN_PRESET_VERSION`(게이트가 `check --min-preset-version` 으로 넘긴다. 형식을 엄격히 검증하고, 비어 있으면 실패하고, 값을 출력에 옮기지 않는다) |
| "새 코드를 둘 곳" | CI 게이트 본문 → `src/templates/ci/<host>/harness-verify.yml`. 프로젝트 고유 단계는 템플릿이 아니라 `[ci].setup` 에 둔다 |
| "검사하지 않는 것" | CI 게이트는 리포 안의 고정 사본 · vendoring · lock 으로 돈다. 쓰기 권한이 있는 사람이 그것들과 게이트를 함께 고치면 게이트는 알아채지 못한다. 게이트가 잡는 것은 실수로 생긴 어긋남이다. 모노레포 서브프로젝트에는 게이트가 없다 |

### 12-2. `.ai/project/glossary.md`

| 위치 | 반영할 사실 |
|---|---|
| "용어" 표의 `소유 파일` | 괄호 목록의 "CI 설정" → "GitLab 의 루트 `.gitlab-ci.yml` · 서브프로젝트 CI 골격" |
| "용어" 표 새 행 `CI 게이트` | render 가 리뷰 호스트별로 생성하는 머지 전 검증 파일(`.github/workflows/harness-verify.yml` · `.gitlab/harness-verify.yml`). GitHub 에서는 조직 ruleset 의 required status check 가 그 job 을 가리킨다 |
| "용어" 표 새 행 `preset 정책` | `check` 가 lock 체인에 대해 늘 보는 허용 출처(`policy.preset_sources`)와, CI 게이트가 넘길 때만 보는 최소 버전(`HARNESS_MIN_PRESET_VERSION`) |

### 12-3. `.ai/project/scope.md`

| 위치 | 반영할 사실 |
|---|---|
| "할 수 있는 일" | 리뷰 호스트의 CI 게이트를 생성하고, preset 정책(허용 출처 · 최소 버전)을 검사한다 |
| "만들지 않는 것" | forge 서버 설정 — 조직 ruleset · 브랜치 보호 · required check 지정 · CI 변수 등록은 사람이 forge 에서 한다. 하네스는 CI 게이트와 운영 안내만 둔다 |

## 13. 결정 기록

결정 기록: the CI gate file is generated and checks the preset policy (분해에서 작성)

## 14. 한계

- 게이트가 보장하는 것은 실수로 생긴 어긋남이다. 고의 우회는 막지 못한다 (7절 2)
- 모노레포 서브프로젝트는 게이트가 없어 조직 강제 대상에서 빠진다. 서브프로젝트 골격과 그것을 리포 루트로 옮긴 사본은 하네스가 고치지 않는다
- GitLab 게이트는 실제 GitLab 으로 검증하지 않았다
- 하네스는 게이트가 forge 에서 required check 로 지정됐는지, CI 변수가 설정됐는지 알지 못한다
- `[ci].setup` 은 GitHub action 과 셸 한 줄만 받는다. GitLab 의 이미지와 그 밖의 job 키는 템플릿(스택 preset 또는 내장)이 정한다
- 게이트를 끄는 설정이 없다. 다른 CI 를 쓰는 프로젝트에도 리뷰 호스트의 게이트 파일이 생긴다
- 이 기능이 든 하네스로 갱신하지 않은 설치본은 옛 소유 CI 파일 그대로 돈다
