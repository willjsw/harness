# #217 task

## T1 · chore: 이 리포의 release job 을 workflow_run 으로 도는 소유 워크플로 release.yml 로 분리

### 상위 Requirement

- relates to #217

### 작업 내용

게이트가 생성 파일이 되면 이 리포의 `.github/workflows/harness-verify.yml` 은 render 가 내장 템플릿으로 다시 쓰고, 템플릿에 없는
`release` job 은 사라진다. 그 전에 release 를 이 리포의 소유 워크플로로 옮긴다. 워크플로 이름 `harness verify` 는 그대로 두므로
옮긴 release 는 T5 의 넘겨받기 전후로 같은 워크플로의 완료에 붙는다.

- 명세 8-2 · 8-3, 10절의 README "업데이트" 행
- `.github/workflows/release.yml`(신규): 명세 8-2 의 본문. 머리 주석 두 줄은 명세 그대로다. `create release` step 의 `run` 은 지금
  `release` job 의 스크립트 그대로이고, 마지막 줄의 `--target "$GITHUB_SHA"` 만 `--target "$HEAD_SHA"` 로 바꾼다
- `.github/workflows/harness-verify.yml`: `release` job 과 그 주석을 지운다. 워크플로 이름 · 트리거 · `verify` job 은 그대로다 —
  이 파일은 T5 가 넘겨받을 때까지 이 리포의 소유 파일이다
- `README.md` "업데이트" 절: main push 에서 CI 게이트(워크플로 `harness verify`)가 성공으로 끝나면 `release` 워크플로가 그 커밋을
  `v<번호>+<커밋 7자리>` 태그의 GitHub Release 로 낸다는 서술로 바꾼다. 태그 형식 · 버전 검사 · 같은 커밋을 다시 돌릴 때 이미 있는
  릴리스를 두는 처리는 그대로다
- 건드릴 파일: `.github/workflows/release.yml`(신규), `.github/workflows/harness-verify.yml`, `README.md`

### 완료 조건

- [ ] `release.yml` 의 트리거가 `workflow_run` · `workflows: ["harness verify"]` · `types: [completed]` · `branches: [main]` 이다
- [ ] `release` job 의 `if` 가 실행 결론 `success` 와 실행 이벤트 `push` 를 함께 요구하고, 권한이 `contents: write` 다
- [ ] checkout 이 `github.event.workflow_run.head_sha` 를 받고, `gh release create` 의 대상이 `HEAD_SHA` 다. `GITHUB_SHA` 가 남지 않는다
- [ ] 옮기기 전 `release` job 의 `run` 과 `release.yml` 의 `run` 의 차이가 `--target` 줄 하나다
- [ ] `harness-verify.yml` 에 `release` job 이 없고 워크플로 이름 `harness verify` · 트리거 · `verify` job 이 그대로다
- [ ] README "업데이트" 절이 새 릴리스 동작을 적는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | release 워크플로 트리거 | `.github/workflows/release.yml` | `workflow_run`, `harness verify`, `completed`, `main` |
| UT-02 | 릴리스 대상 커밋 | `.github/workflows/release.yml` | checkout `ref` 가 `head_sha`, `--target "$HEAD_SHA"`, `GITHUB_SHA` 없음 |
| UT-03 | 스크립트 보존 | 옮기기 전 `release` job 의 `run` 과 `release.yml` 의 `run` 을 diff | `--target` 줄 하나만 다르다 |
| UT-04 | 게이트 파일에 남는 것 | `.github/workflows/harness-verify.yml` | `release:` 없음, `name: harness verify`, `verify` job |
| UT-05 | 워크플로 파일 형식 | 리뷰 요청 push 뒤 GitHub Actions 의 워크플로 목록 | 두 워크플로가 파일 오류 없이 보인다 |

## T2 · feat: [ci] · [policy] 설정 절의 기본값과 검증, 잠금 · 개인 레이어 경계

### 상위 Requirement

- relates to #217

### 작업 내용

CI 게이트의 프로젝트 준비 단계(`[ci].setup`)와 preset 정책(`[policy]`)을 설정 키로 둔다. 이 task 는 값을 읽고 검증하는 데까지다 —
게이트 렌더(T5)와 `check` 의 검사(T8 · T9)가 이 값을 쓴다.

- 명세 3-1 · 3-2 · 3-3, 11-1 의 "`[ci]` · `[policy]` 검증" · "정책 키 잠금"
- `src/templates/defaults.toml`: `[ci]` · `[policy]` 절을 명세 3-1 · 3-2 의 주석과 기본값 그대로 더한다
- `src/harness/config/` 의 검증(`validate()`): 명세 3-1 · 3-2 표의 규칙과 오류 문구
  - 절의 모르는 키 검사는 #207 2-3 의 검사 대상 절에 `ci` · `policy` 를 더해 받을 키를 `defaults.toml` 의 그 절에서 읽는다. help 줄은
    그 절의 키를 적힌 순서대로 쉼표로 잇는다
  - `ci.setup` 항목의 키(`run` · `uses` · `with`)는 고정 목록으로 본다. `<번호>` 는 1부터 세고, 항목의 값은 출력에 옮기지 않는다
  - `forge.review_host = "gitlab"` 이면 `uses` 항목을 거부한다
- `src/harness/config/` 의 병합 규칙 표: 세 키를 명세 3-3 대로 더한다(`ci.setup` · `policy.preset_sources` 일반 배열 교체,
  `policy.check_min_preset_version` 스칼라 덮어쓰기). 잠금은 #207 의 일반 배열 · 스칼라 잠금 그대로이고, 개인 레이어 허용 키에 넣지 않는다
- `src/ui/lib/help.js`: `ci.setup` · `policy.preset_sources` · `policy.check_min_preset_version` 의 도움말 한 줄씩
- 이 리포의 `harness.toml` 은 고치지 않는다 — 두 절 없이 기본값으로 돈다
- `render-test.sh` 에 새 블록. 잠금 케이스의 preset 은 #216 의 로컬 bare 리포 방식으로 만든다
- 건드릴 파일: `src/templates/defaults.toml`, `src/harness/config/`(검증 · 병합 규칙 표), `src/ui/lib/help.js`, `src/test/render-test.sh`

### 완료 조건

- [ ] `[ci]` · `[policy]` 절이 없는 설정이 기본값(`setup = []`, `preset_sources = []`, `check_min_preset_version = false`)으로 렌더되고, 이 리포의 `harness check` 가 통과한다
- [ ] 명세 3-1 표의 위반 여덟 가지와 3-2 표의 위반 세 가지가 각각 render 를 종료 코드 2 로 멈추고 명세의 `error:` · `help:` 문구를 낸다
- [ ] 모르는 키의 help 줄이 `defaults.toml` 의 그 절의 키를 적힌 순서대로 잇는다 — `[ci]` 는 `setup`, `[policy]` 는 `preset_sources, check_min_preset_version`
- [ ] 오류 출력에 `[ci].setup` 항목의 값(명령 · action 이름 · `with` 값)이 나오지 않는다
- [ ] 조직 preset 이 두 `policy` 키를 `locked` 로 잠그면, 프로젝트가 다른 `preset_sources` 배열이나 다른 `check_min_preset_version` 을 적을 때 render 가 종료 코드 2 이고, 같은 값은 받는다
- [ ] `harness.local.toml` 에 적은 `[ci]` · `[policy]` 키를 #207 의 개인 레이어 검증이 거부한다
- [ ] `harness schema` 가 세 키를 값 · 출처와 `defaults.toml` 주석의 설명으로 낸다
- [ ] 새 오류 문구에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 절 없는 설정 | `[ci]` · `[policy]` 가 없는 `harness.toml` 로 render | 종료 코드 0, schema 의 세 값이 기본값 |
| UT-02 | `[ci]` 모르는 키 | `[ci]` 에 `image = "x"` | 2, `error: unknown key(s) in [ci]: image`, `help: the keys are setup` |
| UT-03 | setup 형식 | `setup = "npm ci"` · `setup = ["npm ci"]` | 2, `error: ci.setup must be a list of tables with run or uses` |
| UT-04 | 항목의 모르는 키 | `{ run = "a", shell = "b" }` | 2, `ci.setup[1]` 과 `help: the keys are run, uses, with` |
| UT-05 | run · uses 개수 | 둘 다 있는 항목 · 둘 다 없는 항목 | 2, `ci.setup[<번호>] needs exactly one of run, uses` |
| UT-06 | run 값 | 빈 문자열 · 줄바꿈이 든 문자열 | 2, `ci.setup[<번호>].run must be one non-empty line`, 값이 출력에 없다 |
| UT-07 | uses 형식 | `uses = "setup-node"` · `uses = "a/b"` | 2, `ci.setup[<번호>].uses must be owner/repo@ref` |
| UT-08 | with 형식 | `run` 옆의 `with`, 줄바꿈 값, 규칙 밖 키 | 2, `ci.setup[<번호>].with must be a table of strings next to uses` |
| UT-09 | GitLab 의 uses | `review_host = "gitlab"` 과 `uses` 항목 | 2, `uses an action, which GitLab does not run` 와 help |
| UT-10 | `[policy]` 모르는 키 | `[policy]` 에 `strict = true` | 2, `help: the keys are preset_sources, check_min_preset_version` |
| UT-11 | 허용 출처 형식 | `ssh://…` · 공백이 든 값 · `https://user@host/…` · 정수 항목 | 2, `policy.preset_sources[<번호>] must be an https:// or oci:// source without credentials`, 심은 자격증명 문자열이 출력에 없다 |
| UT-12 | 최소 버전 검사 키 | `check_min_preset_version = "yes"` | 2, `policy.check_min_preset_version must be true or false` |
| UT-13 | 정책 키 잠금 | 조직 preset 이 두 키를 `locked`, 프로젝트가 다른 값 · 같은 값 | 다른 값은 2(#207 잠금 문구), 같은 값은 0 |
| UT-14 | 개인 레이어 | `harness.local.toml` 에 `[policy]` | #207 의 개인 레이어 거부 |
| UT-15 | 터미널 출력 | UT-02 ~ UT-12 의 표준 오류 | 한글 없음 |

## T3 · feat: preset 저장소의 ci/ 아래 CI 게이트 템플릿 두 경로를 받는 파일로 추가

### 상위 Requirement

- relates to #217

### 작업 내용

preset 이 게이트 본문 템플릿을 실어 나를 수 있게 #216 의 받는 파일 표에 `ci/github/harness-verify.yml` · `ci/gitlab/harness-verify.yml`
을 선택 행으로 더한다. 받는 디렉터리와 멤버 판정은 그 표에서 나오므로 판정 함수를 따로 두지 않는다. 받은 템플릿을 render 가
읽는 것은 T7 이다.

- 명세 2-6, 11-1 의 "preset 의 `ci/` 멤버" · "vendoring 해시", 11-2 의 "트리 멤버 판정의 `ci/`"
- `src/harness/preset/` 의 받는 파일 표: 두 행(선택, "CI 게이트 템플릿. 그 리뷰 호스트의 게이트 본문이 된다")
- git 받기 거부 안내의 help 첫 줄을 `help: a preset holds regular files only — preset.toml, notes under project/roles/ and project/workflows/, and CI templates under ci/github/ and ci/gitlab/` 로 바꾼다
- 받은 템플릿이 preset 사본의 같은 상대 경로에 놓이고 내용 해시(#216 4-4)에 드는 것은 #216 의 코드 그대로다. 회귀 케이스로 고정한다
- 단위 테스트는 #216 의 트리 멤버 판정 단위 테스트 파일(`src/test/unit/`)에 `ci/` 케이스를 더한다
- 건드릴 파일: `src/harness/preset/`(받는 파일 표 · 안내문), `src/test/unit/`(멤버 판정 테스트), `src/test/render-test.sh`

### 완료 조건

- [ ] 두 템플릿과 받는 디렉터리 `ci` · `ci/github` · `ci/gitlab` 를 받는다. 템플릿이 하나뿐이거나 `ci/` 가 없는 preset 도 받는다
- [ ] `ci/` 아래 다른 디렉터리, `ci/` 바로 아래 파일, `ci/<host>/` 아래 다른 파일이 있으면 사유 `not a preset path` 로 pull 이 종료 코드 2 이고 대상 리포 · 인덱스 · 매니페스트가 그대로다
- [ ] 링크인 템플릿은 `a symbolic link` 로, 받는 디렉터리 자리의 파일 같은 종류 어긋남은 #216 3-2 표의 종류 사유로 거부한다
- [ ] 거부 안내가 #216 3-2 의 단일 형식(`… has an entry the harness does not accept (<사유>, entry <N>)`)이고 그 항목의 경로가 하네스 출력에 없다
- [ ] 받은 템플릿이 `.harness/preset/<깊이>/ci/<host>/harness-verify.yml` 에 놓이고 lock 의 `content` 에 든다. 그 사본을 고치면 #216 의 대조가 render 를 종료 코드 2, `check` 를 1 로 멈춘다
- [ ] git 받기 거부의 help 첫 줄이 위 문구다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 템플릿 받기 | 목록에 `ci` · `ci/github` · `ci/github/harness-verify.yml` · `ci/gitlab/harness-verify.yml` (파일 · 디렉터리) | 통과, 두 템플릿이 받을 파일에 든다 |
| UT-02 | 디렉터리 항목 없는 목록 | `ci/gitlab/harness-verify.yml` 파일 하나만 | 통과 |
| UT-03 | 다른 호스트 디렉터리 | `ci/bitbucket/harness-verify.yml` | 거부, 사유 `not a preset path`, 그 항목 순번, 경로 없음 |
| UT-04 | `ci/` 바로 아래 파일 | `ci/README.md` | 거부, `not a preset path` |
| UT-05 | 호스트 아래 다른 파일 | `ci/github/release.yml` | 거부, `not a preset path` |
| UT-06 | 링크인 템플릿 | `ci/github/harness-verify.yml` 이 심볼릭 링크 | 거부, `a symbolic link` |
| UT-07 | 디렉터리 자리의 파일 | `ci` 가 파일 | 거부, #216 의 디렉터리 종류 사유 |
| UT-08 | pull 거부 | 위 거부 경우의 preset 을 `extends` 로 pull | 2, `nothing was changed`, 대상 리포 · 인덱스 · 매니페스트 바이트 그대로, 심은 이름이 출력에 없다 |
| UT-09 | 사본과 해시 | 템플릿을 담은 preset 을 pull | 사본 경로에 템플릿, lock `content` 가 템플릿을 포함한 4-4 해시 |
| UT-10 | 사본 손편집 | UT-09 뒤 사본의 템플릿 한 줄 수정 | render 2, `check` · `check --staged` 1, `content differs from the lock` |
| UT-11 | help 문구 | 링크가 든 preset 의 pull | 표준 오류에 새 help 첫 줄 |

## T4 · feat: CI 게이트 템플릿의 변수 치환 · 규칙 검사 · 머리말 함수

### 상위 Requirement

- relates to #217

### 작업 내용

게이트 본문을 만드는 순수 함수를 새 모듈 `src/harness/render/ci.py` 에 둔다. 함수는 템플릿 텍스트(바이트)와 설정을 받아 치환한 본문이나
거부 사유를 돌려주고, 파일을 쓰거나 프로세스를 끝내지 않는다. render 의 사전 판정(T5)과 pull 의 render 결과 계산(T7)이 같은 함수로
거부를 판정한다.

- 명세 2-2 의 UTF-8 거부와 템플릿 출처 줄, 2-3, 2-4, 11-2 의 "표지 줄 치환" · "setup 항목 렌더"
- 트리거 브랜치: `branches.base` 를 맨 앞에 두고 `branches.protected` 를 설정 순서대로 잇는다. 같은 이름은 한 번만 둔다
- 변수 넷
  - `{{CI_BRANCHES}}`: 줄 안, 트리거 브랜치의 JSON 배열
  - `{{CI_BRANCH_RULES}}`: 홀로 선 줄, 트리거 브랜치마다 `- if: $CI_COMMIT_BRANCH == "<브랜치>"`
  - `{{CI_SETUP}}`: 홀로 선 줄, `[ci].setup` 항목. github 는 step(`- uses:` 와 `with:` 아래 키, `- run:`), gitlab 은 `before_script` 항목(`run` 만). 값은 모두 JSON 문자열 표기
  - `{{CI_VERIFY}}`: 줄 안, 검증 명령 한 줄의 JSON 문자열. 명령은 명세 2-3 표 — `policy.check_min_preset_version` 과 #221 유무로 정해진다.
    `<CLI>` 는 `source_tree()` 면 `src/bin/harness`, 아니면 `.harness/bin/harness` 이고, #221 이 있으면 `derive()` 의 `{{HARNESS_CLI}}` 값이다
- 홀로 선 줄의 치환은 그 줄을 항목 줄들로 바꾸고 줄마다 원래 줄의 앞 공백을 붙인다. 항목이 없으면 그 줄을 지운다
- 거부(명세 문구 그대로, 오류마다 템플릿 출처 줄 `  --> built-in ci/<host>/harness-verify.yml` 또는 `  --> preset <출처> ci/<host>/harness-verify.yml`)
  - 모르는 변수 — 넷 밖의 `{{…}}`, 다른 호스트의 변수, `{{INCLUDE:…}}`
  - 홀로 서야 할 변수가 다른 글자와 한 줄에 있음
  - 빠진 필수 변수 — `{{CI_VERIFY}}`, 그 호스트의 브랜치 변수, `[ci].setup` 이 비어 있지 않을 때 `{{CI_SETUP}}`. help 줄은 명세 2-3 의 표
  - UTF-8 이 아닌 템플릿
- 대문자 · 밑줄만으로 된 이름이 아닌 `${{ … }}` 는 변수로 보지 않고 그대로 둔다
- 머리말: 생성 게이트 세 줄(둘째 줄 `# 템플릿: 내장` 또는 `# 템플릿: preset <출처>`)과 서브프로젝트 소유 골격 세 줄(셋째 줄은 그 호스트의 것 하나, `(github)` · `(gitlab)` 표시 없이). 문구는 명세 2-4 그대로
- 단위 테스트 `src/test/unit/test_ci_gate.py`
- 건드릴 파일: `src/harness/render/ci.py`(신규), `src/test/unit/test_ci_gate.py`(신규)

### 완료 조건

- [ ] 트리거 브랜치가 base 먼저 · 보호 브랜치 설정 순서 · 중복 없음이다 — `base = "develop"`, `protected = ["main", "develop"]` 이면 `["develop", "main"]`
- [ ] 명세 2-3 의 `[ci].setup` 예가 github 항목 다섯 줄, gitlab 항목 한 줄로 명세의 바이트 그대로 나온다
- [ ] 홀로 선 줄의 앞 공백이 항목 줄마다 붙고, 빈 목록이면 그 줄이 사라진다
- [ ] `{{CI_VERIFY}}` 가 정책 거짓 · 참과 소스 트리 · 대상 리포의 네 조합에서 명세 2-3 표의 명령을 JSON 문자열로 낸다
- [ ] 거부 경우(모르는 변수 · 다른 호스트의 변수 · `{{INCLUDE:…}}` · 홀로 서지 않은 표지 · 빠진 필수 변수 셋 · UTF-8 아님)가 각각 명세의 `error:` · `help:` 문구와 출처 줄을 돌려준다
- [ ] `${{ vars.HARNESS_MIN_PRESET_VERSION }}` · `${{ github.token }}` 이 바뀌지 않는다
- [ ] 두 머리말이 명세 2-4 의 문구와 같다
- [ ] 함수가 파일을 쓰거나 프로세스를 끝내지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 트리거 브랜치 | base `develop`, protected `["main", "develop"]` · protected `[]` | `["develop", "main"]` · `["develop"]` |
| UT-02 | 브랜치 규칙 줄 | 앞 공백 4칸의 `{{CI_BRANCH_RULES}}` 줄, 브랜치 둘 | 공백 4칸이 붙은 `- if:` 두 줄 |
| UT-03 | github setup | 명세 3-1 의 예 | 명세 2-3 의 github 다섯 줄과 바이트 같음 |
| UT-04 | gitlab setup | `run` 항목 하나 | `- "npm ci"` |
| UT-05 | JSON 문자열 표기 | 따옴표 · 역슬래시가 든 `run` 값 | JSON 문자열로 이스케이프된 한 줄 |
| UT-06 | 빈 setup | `setup = []` 과 `{{CI_SETUP}}` 줄 | 그 줄이 사라진다 |
| UT-07 | 검증 명령 | 정책 거짓 · 참 × 소스 트리 · 대상 리포 | 명세 2-3 표의 명령 넷 |
| UT-08 | 모르는 변수 | `{{CI_IMAGE}}` · gitlab 템플릿의 `{{CI_BRANCHES}}` · `{{INCLUDE:x}}` | `error: unknown template variable(s): …` 와 출처 줄 |
| UT-09 | 홀로 서지 않은 표지 | `steps: {{CI_SETUP}}` | `error: {{CI_SETUP}} must stand alone on its line` |
| UT-10 | 빠진 필수 변수 | `{{CI_VERIFY}}` 없음 · 브랜치 변수 없음 · setup 이 있는데 `{{CI_SETUP}}` 없음 | 명세 2-3 표의 `error:` · `help:` |
| UT-11 | UTF-8 아님 | 0xff 바이트가 든 템플릿 | `error: the CI template is not UTF-8 text` 와 출처 줄 |
| UT-12 | Actions 식 보존 | `${{ vars.X }}` · `${{ github.token }}` | 그대로 |
| UT-13 | 출처 줄 | 내장 · preset 출처 | `  --> built-in ci/<host>/harness-verify.yml` · `  --> preset <출처> ci/<host>/harness-verify.yml` |
| UT-14 | 머리말 | 생성(내장 · preset) · 소유 골격(github · gitlab) | 명세 2-4 문구, 골격 셋째 줄이 호스트 것 하나 |

## T5 · feat: render 가 리포 루트에 CI 게이트를 생성하고 이 리포의 게이트를 넘겨받음

### 상위 Requirement

- relates to #217

### 작업 내용

CI 게이트를 첫 설치 때만 까는 소유 파일에서 render 가 매번 쓰는 생성 파일로 바꾼다. 게이트를 생성하지 않는 자리(GitLab 의 리포 루트
`.gitlab-ci.yml`, 모노레포 서브프로젝트)에는 소유 파일을 없을 때만 깐다. 이 task 의 템플릿은 내장 템플릿이고, preset 템플릿을 고르는
것은 T7 이다.

- 명세 1 · 2-1 · 2-4 · 2-5 · 8-1, 11-1 의 "github 게이트 생성" · "손편집" · "gitlab 게이트 생성" · "서브프로젝트" · "`[ci].setup` 렌더" · "템플릿 규칙" · "게이트 명령 실행"(정책 거짓)
- 내장 템플릿: `src/templates/ci/github/harness-verify.yml` · `src/templates/ci/gitlab/harness-verify.yml`(명세 2-5 의 본문), GitLab 루트 원형
  `src/templates/ci/gitlab/gitlab-ci.yml`(명세 2-1 의 본문). 옛 골격 `src/templates/ci/github/.github/workflows/harness-verify.yml` · `src/templates/ci/gitlab/.gitlab-ci.yml` 은 지운다.
  고정 사본에서는 install 이 복사한 `.harness/templates/ci/` 에서 읽는다
- `src/harness/render/plan.py`
  - `plan()`: 하네스 루트가 리포 루트이거나 git 작업 트리 밖이면(`forge_templates()` 와 같은 `repo_prefix()` 판정) 리뷰 호스트의 게이트 경로
    (`.github/workflows/harness-verify.yml` · `.gitlab/harness-verify.yml`)를 머리말 + T4 로 치환한 본문으로 낸다. 게이트의 `.harness/generated` 줄에는 해시를 붙이지 않는다
  - `ci_dir()` 를 걷는다. `seeded_paths()` 는 소유 파일에 GitLab 루트 `.gitlab-ci.yml`(게이트를 생성하는 루트이고 gitlab 일 때)과 서브프로젝트
    골격 경로(명세 2-1 표의 둘째 행 — github `.github/workflows/harness-verify.yml`, gitlab `.gitlab-ci.yml`)를 더한다. `harness_paths()` 설명의
    "CI 골격" 을 새 부류로 고친다
- `src/harness/render/apply.py`(`render_target`): `copy_tree(ci_dir…)` 자리에서 GitLab 루트 원형과 서브프로젝트 골격(소유 머리말 + 생성 게이트와
  같은 템플릿 · 변수로 만든 본문)을 없을 때만 깐다. 이 경로들은 지금의 소유 파일처럼 경로 규칙과 부모 디렉터리 판정만 받는다
- 템플릿 규칙 거부(T4)는 render 의 사전 판정 자리에서 보고 종료 코드 2 로 아무것도 쓰지 않는다. 서브프로젝트 골격을 깔 때도 같다
- 게이트는 공유 설정으로 렌더된다 — `harness.local.toml` 의 값이 게이트에 들지 않는다
- 이 리포의 넘겨받기: `src/bin/harness render --adopt` 로 `.github/workflows/harness-verify.yml` 을 넘겨받고 `.github/workflows/harness-verify.yml.orig` 를
  지운다. 생성 게이트의 트리거 브랜치는 `["develop", "main"]`, `[ci].setup` 은 비어 있고, `run:` 은 명세 2-3 표의 값이다(명세 8-1)
- `render-test.sh`
  - 기존 케이스 가운데 CI 골격을 첫 설치 때만 깐다는 기대(GitLab `.gitlab-ci.yml` 이 검증 일괄을 돌린다 · 손으로 고친 파이프라인을 render 가
    덮지 않는다 · `--purge` 가 남긴다, GitHub 워크플로가 깔린다, uninstall 이 CI 골격을 남긴다)를 새 부류의 기대로 고친다
  - 새 블록. "템플릿 규칙" 케이스는 소스 트리를 임시 디렉터리에 복제하고 그 복제의 내장 템플릿을 고친 CLI 로 render 한다
- 건드릴 파일: `src/templates/ci/`, `src/harness/render/plan.py` · `apply.py` · `ci.py`, `src/test/render-test.sh`,
  render 로 갱신되는 `.github/workflows/harness-verify.yml` · `.harness/generated`

### 완료 조건

- [ ] 리포 루트 설치(github)에서 `.github/workflows/harness-verify.yml` 이 생기고 `.harness/generated` 에 해시 없는 줄로 있다. 머리말 세 줄(템플릿 `내장`), 트리거 브랜치가 base 먼저 · 중복 없음, `run:` 이 명세 2-3 표의 값이다
- [ ] gitlab 이면 `.gitlab/harness-verify.yml` 이 생성되고, 루트 `.gitlab-ci.yml` 이 없을 때만 include 원형이 깔린다. 이미 있던 루트 파일은 바이트 그대로다
- [ ] 게이트를 손으로 고치면 `check` 와 `check --staged` 가 `differs from the config` 로 종료 코드 1 이고, render 가 되돌린다
- [ ] 서브프로젝트에서는 `plan()` 에 게이트가 없고, 그 호스트의 골격이 소유 머리말과 함께 없을 때만 깔린다. 고친 골격을 render 가 덮지 않는다
- [ ] `[ci].setup` 의 `run` · `uses` · `with` 가 github step 으로, `run` 이 gitlab `before_script` 항목으로 들어가고, 비어 있으면 표지 줄이 사라진다
- [ ] 내장 템플릿을 규칙에 어긋나게 고친 CLI 로 render 하면 위반마다 종료 코드 2 이고 대상 리포에 아무것도 쓰이지 않는다. `${{ vars.X }}` 는 그대로 남는다
- [ ] `harness.local.toml` 이 있어도 게이트 바이트가 같다
- [ ] 설치한 임시 리포에서 게이트의 `run:` 값(JSON 문자열을 풀어서)을 셸로 돌리면 종료 코드 0 이다
- [ ] 이 리포의 `.github/workflows/harness-verify.yml` 이 생성 게이트이고 `.harness/generated` 에 있으며, `.orig` 가 없고, `harness check` 가 통과한다
- [ ] 새 오류 · 안내에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | github 게이트 생성 | 리포 루트에 install, base `develop` · protected `main` | 게이트 파일, `.harness/generated` 의 해시 없는 줄, 머리말 세 줄, `branches: ["develop", "main"]`, `run:` 이 2-3 표의 값 |
| UT-02 | 손편집 | 게이트 한 줄 수정 뒤 `check` · `check --staged` · render | 1 · 1(`differs from the config`), render 뒤 원래 바이트 |
| UT-03 | gitlab 게이트 생성 | `review_host = "gitlab"` 로 install | `.gitlab/harness-verify.yml` 생성, 루트 `.gitlab-ci.yml` 에 `local: /.gitlab/harness-verify.yml` |
| UT-04 | 기존 루트 파일 | 루트 `.gitlab-ci.yml` 을 미리 둔 gitlab install | 루트 파일 바이트 그대로, 게이트는 생성 |
| UT-05 | 서브프로젝트 | 리포 하위 디렉터리에 install(github · gitlab) | `plan()` 에 게이트 없음, 골격이 소유 머리말과 함께 깔림, 고친 골격을 render 가 덮지 않음 |
| UT-06 | setup 렌더 | `run` · `uses` + `with` 항목(github), `run` 항목(gitlab) | step 다섯 줄 · `before_script` 항목, 빈 setup 이면 표지 줄 없음 |
| UT-07 | 템플릿 규칙 | 복제한 소스 트리의 내장 템플릿에서 `{{CI_VERIFY}}` 삭제 · 모르는 변수 · 홀로 서지 않은 표지 · 다른 호스트 변수 · `{{INCLUDE:x}}` · UTF-8 아닌 바이트 · setup 이 있는데 `{{CI_SETUP}}` 삭제 | 각각 2, 대상 리포 바이트 그대로 |
| UT-08 | Actions 식 | 생성 게이트 | `${{ vars.HARNESS_MIN_PRESET_VERSION }}` 그대로 |
| UT-09 | 개인 레이어 | `harness.local.toml` 을 두고 render | 게이트 바이트가 없을 때와 같음 |
| UT-10 | 게이트 명령 실행 | 설치한 임시 리포에서 `run:` 값을 풀어 `sh -c` | 0 |
| UT-11 | 이 리포 | `.github/workflows/harness-verify.yml` · `.harness/generated` | 생성 게이트, 매니페스트 줄 있음, `.orig` 없음 |
| UT-12 | 터미널 출력 | UT-07 의 표준 오류 | 한글 없음 |

## T6 · feat: 기존 게이트 넘겨받기 안내와 리뷰 호스트 전환 · uninstall 의 게이트 정리

### 상위 Requirement

- relates to #217

### 작업 내용

이미 깔린 게이트 파일을 가진 설치본이 갱신 때 무엇을 해야 하는지 안내하고, 리뷰 호스트를 바꾸거나 하네스를 제거할 때 생성 게이트와 소유
CI 파일이 각자의 부류대로 다뤄지는 것을 고정한다.

- 명세 4-1 · 4-2 · 4-3, 11-1 의 "넘겨받기" · "호스트 전환" · "uninstall"
- `src/harness/changes.py`(`refuse_user_files`): 찾은 사용자 파일에 생성 게이트 경로가 있으면 spec 58 3-3 안내문의 `help:` 끝에 명세 4-1 의 한 줄을 더한다.
  그 안내문을 쓰는 명령(install · render · set · steps · checks, write-doc 의 render)에 같은 줄이 나온다
- 호스트 전환: 옛 호스트의 생성 게이트는 정리(`prune`)가 지운다. github → gitlab 에서 루트 `.gitlab-ci.yml` 은 없을 때만 깔고, gitlab → github 에서 루트
  파일은 남는다. 서브프로젝트 골격은 새 호스트의 골격 경로가 비어 있을 때만 깐다
- uninstall: 게이트는 생성 파일로 지워지고 그 디렉터리가 비면 지운다. 루트 `.gitlab-ci.yml` · 서브프로젝트 골격 · `.orig` 는 `--purge` 에도 남고, 끝의
  `untouched:` 목록은 그대로다. `src/harness/commands/uninstall.py` 의 설명 · 안내가 CI 파일을 "첫 설치 때만 깐 것" 으로 적고 있으면 새 부류로 고친다
- 건드릴 파일: `src/harness/changes.py`, `src/harness/commands/uninstall.py`(설명이 어긋날 때), `src/test/render-test.sh`

### 완료 조건

- [ ] 매니페스트에 없는 게이트 파일이 있으면 render · install 이 종료 코드 2 이고 아무것도 쓰지 않으며, 안내문의 `help:` 끝에 명세 4-1 의 줄이 있다. 게이트가 아닌 사용자 파일만 찾았으면 그 줄이 없다
- [ ] `--adopt` 면 `.orig` 와 생성 게이트가 생기고 `.orig` 는 매니페스트에 없다. 다음 render 가 `.orig` 를 덮거나 지우지 않는다
- [ ] github → gitlab 에서 옛 게이트가 지워지고 새 게이트와 루트 원형이 생긴다. 이미 있던 루트 `.gitlab-ci.yml` 은 바이트 그대로다
- [ ] gitlab → github 에서 `.gitlab/harness-verify.yml` 이 지워지고 루트 `.gitlab-ci.yml` 은 남는다
- [ ] uninstall 이 게이트를 지우고 `.orig` · 루트 `.gitlab-ci.yml` 을 남긴다. `--purge --yes` 도 그 둘과 서브프로젝트 골격을 남긴다
- [ ] 새 안내 줄에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 넘겨받기 멈춤 | 매니페스트에 없는 `.github/workflows/harness-verify.yml` 이 있는 설치본에서 render · install | 2, 대상 리포 바이트 그대로, `help:` 끝에 `the CI gate is generated now — …` |
| UT-02 | 게이트 아닌 사용자 파일 | 다른 생성 경로에만 사용자 파일 | 2, CI 줄 없음 |
| UT-03 | `--adopt` | UT-01 상태에서 `render --adopt` | `.orig` 와 생성 게이트, `.orig` 가 매니페스트에 없음, 다음 render 뒤 `.orig` 바이트 그대로 |
| UT-04 | github → gitlab | `forge.review_host` 를 바꾸고 render | 옛 게이트 없음, `.gitlab/harness-verify.yml` · 루트 원형 생김 |
| UT-05 | 기존 루트 파일 보존 | 루트 `.gitlab-ci.yml` 이 있는 상태에서 github → gitlab | 루트 파일 바이트 그대로 |
| UT-06 | gitlab → github | 되돌려 render | `.gitlab/harness-verify.yml` 없음, 루트 `.gitlab-ci.yml` 남음 |
| UT-07 | uninstall | `.orig` · 루트 `.gitlab-ci.yml` 이 있는 설치본에서 uninstall · `--purge --yes` | 게이트 없음, 두 파일 남음 |
| UT-08 | 서브프로젝트 uninstall | 골격이 있는 서브프로젝트에서 `--purge --yes` | 골격 남음 |
| UT-09 | 터미널 출력 | UT-01 의 표준 오류 | 한글 없음 |

## T7 · feat: lock 체인의 preset 이 공급한 CI 템플릿으로 게이트를 렌더하고 pull 이 템플릿 규칙을 검사

### 상위 Requirement

- relates to #217

### 작업 내용

게이트 본문의 템플릿을 lock 체인에서 가장 가까운 preset 의 것으로 고른다. 템플릿은 preset 사본에서 읽고, pull 은 새 체인의 템플릿이 규칙을
어기면 대상 리포를 바꾸기 전에 멈춘다.

- 명세 2-2 · 2-4(템플릿 출처), 11-1 의 "preset 템플릿 고르기" · "pull 의 템플릿 규칙"
- `src/harness/render/ci.py`: 템플릿 고르기 — lock 체인을 깊이 1 부터 위로 따라가며 preset 사본(`.harness/preset/<깊이>/`)에
  `ci/<host>/harness-verify.yml` 이 있는 첫 preset 의 것, 없으면 내장 템플릿. 출처 표시는 그 lock 항목의 `source` 다.
  생성 게이트와 서브프로젝트 골격이 같은 고르기를 쓴다
- 머리말의 `# 템플릿:` 줄과 오류의 템플릿 출처 줄이 고른 템플릿을 가리킨다
- `src/harness/commands/pull.py`: 준비 단계의 render 결과 계산(#216 7-2 의 7)이 새 체인의 템플릿을 받은 임시 위치에서 읽는다 — 메모와 같다.
  템플릿이 규칙을 어기면 그 단계에서 종료 코드 2 로 멈추고, 준비 단계에서 멈춘 다른 경우처럼 줄 목록 뒤에 `nothing was changed` 를 낸다.
  #216 의 멈춤 조건 표에는 행을 더하지 않는다
- 건드릴 파일: `src/harness/render/ci.py`, `src/harness/commands/pull.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 조직(깊이 2) · 스택(깊이 1) 체인에서 스택 preset 의 템플릿을 쓰고, 스택에 없으면 조직 것, 둘 다 없으면 내장을 쓴다. 머리말의 템플릿 출처가 고른 것과 맞다
- [ ] 서브프로젝트 골격도 같은 고르기로 깔린다
- [ ] 새 체인의 템플릿이 규칙을 어기면 pull 이 종료 코드 2 · `nothing was changed` 로 멈추고 preset 사본 · lock · 생성 파일 · 인덱스가 그대로다. 오류의 출처 줄이 `  --> preset <출처> ci/<host>/harness-verify.yml` 이다
- [ ] 원격 bare 리포를 지운 뒤에도 render · `check` 가 같은 게이트로 통과한다 — render 가 네트워크를 쓰지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 스택 템플릿 우선 | 두 preset 모두 github 템플릿을 둔 깊이 2 체인으로 pull | 게이트 본문이 스택 템플릿, 머리말 `# 템플릿: preset <스택 출처>` |
| UT-02 | 조직 템플릿 | 스택에 템플릿이 없는 체인 | 조직 템플릿, 머리말에 조직 출처 |
| UT-03 | 내장 템플릿 | 두 preset 모두 템플릿 없음 | 내장 템플릿, `# 템플릿: 내장` |
| UT-04 | 다른 호스트 템플릿만 있음 | preset 에 gitlab 템플릿만, `review_host = "github"` | 내장 템플릿 |
| UT-05 | 서브프로젝트 골격 | 템플릿을 둔 preset 을 잇는 서브프로젝트 | 골격 본문이 preset 템플릿, 소유 머리말 |
| UT-06 | pull 의 템플릿 규칙 | `{{CI_VERIFY}}` 가 없는 템플릿 · 모르는 변수가 든 템플릿을 새 태그로 낸 preset 으로 pull | 2, `nothing was changed`, 출처 줄, 사본 · lock · 생성 파일 · 인덱스 바이트 그대로 |
| UT-07 | 오프라인 render | UT-01 뒤 원격 bare 리포 삭제 | render · `check` 통과, 게이트 바이트 그대로 |

## T8 · feat: check 가 lock 체인의 preset 출처를 policy.preset_sources 로 검사

### 상위 Requirement

- relates to #217

### 작업 내용

`check` 가 lock 체인의 preset 출처를 설정의 허용 목록과 대조한다. pre-commit 의 `check --staged` 에서도 돌아 허용되지 않은 출처의 lock 이
커밋되지 않게 한다. 네트워크를 쓰지 않는다.

- 명세 5-1 · 5-2 · 5-5(허용 출처), 11-1 의 "허용 출처", 11-2 의 "출처 일치"
- `src/harness/preset/policy.py`(신규): 출처 일치 — 값이 `/` 로 끝나면 출처가 그 값으로 시작할 때, 그 밖은 같을 때 맞는다. 바이트 비교이고
  대소문자 · 끝 `/` 를 정규화하지 않는다. 스킴을 가르지 않는다. 체인 항목마다 맞지 않는 것의 목록을 돌려준다
- `src/harness/drift.py`(`check_target`): `policy.preset_sources` 가 비어 있지 않으면 늘(`--staged` 포함) lock 체인 항목 전부의 `source` 를 본다
  - lock 은 #216 4-3 의 읽기로, `--staged` 면 인덱스에서 읽는다
  - `extends` 가 없으면 체인이 비어 통과한다. #216 의 lock 대조가 실패하면 이 검사는 돌지 않는다
  - 위반은 기존 오류 뒤에 명세 5-5 의 첫 블록(`chain <n>` 은 깊이)으로 표준 오류에 내고 종료 코드 1. 통과하면 `check: <n> preset source(s) allowed by policy`
- pre-commit 훅 본문은 바꾸지 않는다 — 지금의 `check --staged` 호출이 이 검사를 돈다
- 단위 테스트 `src/test/unit/test_preset_policy.py`(신규)
- 건드릴 파일: `src/harness/preset/policy.py`(신규), `src/harness/drift.py`, `src/test/unit/test_preset_policy.py`(신규), `src/test/render-test.sh`

### 완료 조건

- [ ] 같은 값 · `/` 로 끝나는 값의 접두 · 어긋남을 가른다. 끝 `/` 와 대소문자를 정규화하지 않고, `oci://` 값도 같은 규칙으로 본다
- [ ] 깊이 2 항목의 출처만 어긋나도 `chain 2  <출처>` 줄로 잡고 종료 코드 1 이다. 줄 형식과 help 두 줄이 명세 5-5 와 같다
- [ ] `check --staged` 가 인덱스의 lock 을 보고, 허용되지 않은 출처의 lock 을 스테이지한 커밋을 pre-commit 이 막는다
- [ ] `policy.preset_sources` 가 비어 있거나 `extends` 가 없으면 검사하지 않는다
- [ ] #216 의 lock 대조가 실패한 상태에서는 이 검사의 줄이 나오지 않는다
- [ ] 통과하면 `check: <n> preset source(s) allowed by policy` 가 기존 통과 줄 뒤에 나온다
- [ ] 새 문구에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 같은 값 | 값 `https://h/org/p`, 출처 `https://h/org/p` · `https://h/org/p2` | 맞음 · 안 맞음 |
| UT-02 | 접두 값 | 값 `https://h/org/`, 출처 `https://h/org/p` · `https://h/other/p` | 맞음 · 안 맞음 |
| UT-03 | 정규화 없음 | 값 `https://h/org/p/` · `https://H/org/p`, 출처 `https://h/org/p` | 둘 다 안 맞음 |
| UT-04 | 스킴 무관 | 값 `oci://r.example/org/`, 출처 `oci://r.example/org/p` | 맞음 |
| UT-05 | 깊이 2 위반 | 깊이 1 은 허용, 깊이 2 출처가 목록 밖인 체인으로 `check` | 1, `chain 2  <출처>`, help 두 줄 |
| UT-06 | 통과 줄 | 모든 출처가 허용된 체인으로 `check` | 0, `check: 2 preset source(s) allowed by policy` |
| UT-07 | `--staged` | 작업 트리는 허용된 lock, 인덱스는 목록 밖 출처의 lock | `check --staged` 1, 커밋이 pre-commit 에서 막힌다 |
| UT-08 | 검사하지 않음 | `preset_sources = []` · `extends` 없음 | 이 검사의 줄 없음 |
| UT-09 | lock 대조 실패 | 사본 손편집 상태 | #216 의 오류만, 출처 검사 줄 없음 |
| UT-10 | 터미널 출력 | UT-05 의 표준 오류 | 한글 없음 |

## T9 · feat: check --min-preset-version 으로 preset 최소 버전을 검사하고 게이트가 정책에 따라 넘김

### 상위 Requirement

- relates to #217

### 작업 내용

리포 밖(조직 · 그룹 CI 변수)에서 받은 preset 최소 버전을 `check` 가 lock 체인의 태그와 비교한다. 인자를 받을 때만 검사하고, 그 인자는
`policy.check_min_preset_version` 이 참인 게이트만 넘긴다.

- 명세 5-1 · 5-3 · 5-4 · 5-5(최소 버전), 2-3 의 `{{CI_VERIFY}}` 참 쪽, 11-1 의 "최소 버전" · "`{{CI_VERIFY}}`" · "게이트 명령 실행"(정책 참),
  11-2 의 "버전 파싱·비교" · "`--min-preset-version` 파싱"
- `src/harness/preset/policy.py`
  - 버전: `^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`, 앞의 `v` 유무는 같고, 세 수를 정수로 앞에서부터 비교한다
  - 목록 해석: 공백(스페이스 · 탭 · 줄바꿈)으로 나누고 항목마다 마지막 `=` 에서 출처와 최소 버전으로 나눈다. 빈 값 · 형식 어긋남 · 버전이 아닌 최소값 · 출처 중복을 명세 5-3 의 문구로 거부한다
  - 판정: 목록에 같은 출처가 있는 체인 항목만 본다. 체인에 없는 목록 항목은 무시한다. 최소 버전이 걸린 항목의 태그가 버전 형식이 아니면 위반이다
- 인자: `check` 가 `--min-preset-version <list>` 를 받는다. 공용 파서(`src/harness/cli.py`)에 `--staged` 와 같은 자리의 옵션으로 둔다.
  인자 판정은 다른 검사보다 먼저이고, 어기면 아무것도 검사하지 않고 종료 코드 2 다. 인자 값은 출력에 옮기지 않는다
- `src/harness/commands/__init__.py` 의 `COMMANDS`: `check` 사용법 `[--staged] [--min-preset-version <list>]`
- `src/harness/drift.py`(`check_target`): 인자를 받았을 때만 최소 버전 검사를 한다. #216 의 lock 대조가 실패하면 돌지 않는다. 위반은 명세 5-5 의 둘째 블록으로
  종료 코드 1, 통과하면 `check: <n> preset version(s) meet the minimum, <m> without one`
- 게이트: `policy.check_min_preset_version = true` 면 `{{CI_VERIFY}}` 가 명세 2-3 표의 참 쪽 명령이다(T4 의 함수). render 와 실행 케이스로 고정한다
- 건드릴 파일: `src/harness/preset/policy.py`, `src/harness/drift.py`, `src/harness/cli.py`, `src/harness/commands/__init__.py`, `src/harness/commands/check.py`,
  `src/test/unit/test_preset_policy.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 태그가 최소 이상이면 통과, 미만이면 종료 코드 1, 버전이 아닌 태그면 1 이다. 위반 줄과 help 가 명세 5-5 의 형식이다
- [ ] 빈 값(공백뿐 포함) · `=` 가 없거나 앞뒤가 빈 항목 · 버전이 아닌 최소값 · 한 출처의 중복이 각각 명세 5-3 의 문구로 종료 코드 2 이고, 다른 검사의 줄이 나오지 않는다
- [ ] 어느 출력에도 인자 값이 옮겨지지 않는다 — 위반 줄의 출처 · 태그는 lock 의 값이다
- [ ] 목록에 없는 체인 항목은 보지 않고, 인자가 없으면 검사하지 않으며, `extends` 가 없으면 통과한다
- [ ] 통과하면 `check: <n> preset version(s) meet the minimum, <m> without one` 이 나온다
- [ ] `check_min_preset_version = true` 면 대상 리포 게이트의 `run:` 이 `.harness/bin/harness check --min-preset-version "$HARNESS_MIN_PRESET_VERSION" && ` 로, 소스 트리 복제는 `src/bin/harness check --min-preset-version …` 로 시작하고 `&&` 뒤가 명세 2-3 표의 검증 명령이다. 거짓이면 검증 명령뿐이다
- [ ] 설치한 임시 리포에서 정책을 켠 게이트의 `run:` 값을 `HARNESS_MIN_PRESET_VERSION` 을 비우고 돌리면 2 다
- [ ] `harness help` 의 `check` 사용법이 `[--staged] [--min-preset-version <list>]` 다
- [ ] 새 문구에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 버전 형식 | `v1.2.3` · `1.2.3` · `01.2.3` · `1.2` · `v1.2.0-rc1` | 받음 · 받음 · 거부 · 거부 · 거부 |
| UT-02 | v 유무 | `v1.4.0` 과 `1.4.0` | 같음 |
| UT-03 | 수 비교 | `1.10.0` 과 `1.9.0` | `1.10.0` 이 크다 |
| UT-04 | 목록 공백 | 스페이스 · 탭 · 줄바꿈으로 나뉜 두 항목 | 두 항목 |
| UT-05 | 마지막 `=` | `https://h/p?a=b=v1.0.0` | 출처 `https://h/p?a=b`, 최소 `v1.0.0` |
| UT-06 | 목록 오류 | 빈 값 · 공백뿐 · `x` · `=v1.0.0` · `x=` · `x=latest` · 같은 출처 둘 | 명세 5-3 의 다섯 문구, 항목 번호 |
| UT-07 | 이상 · 미만 · 버전 아님 | 체인 태그 `v2.1.0` · `v2.0.3` · `2026-10`, 최소 `2.1.0` | 통과 · 1 · 1, 명세 5-5 줄 |
| UT-08 | 목록 밖 · 체인 밖 | 목록에 없는 체인 항목, 체인에 없는 목록 항목 | 보지 않음 · 무시, `<m> without one` 에 셈 |
| UT-09 | 인자 오류는 먼저 | 사본 손편집 상태에서 빈 인자 | 2, 인자 오류만 |
| UT-10 | 값을 옮기지 않음 | 표지 문자열을 심은 인자로 오류 · 위반 | 표준 출력 · 표준 오류에 표지 없음 |
| UT-11 | 게이트 명령 | 정책 참으로 대상 리포 · 소스 트리 복제 render, 거짓으로 render | 명세 2-3 표의 세 명령 |
| UT-12 | 게이트 실행 | 정책 참 게이트의 `run:` 을 `HARNESS_MIN_PRESET_VERSION=` 으로 실행 | 2 |
| UT-13 | 사용법 | `harness help` | `check` 행에 `[--staged] [--min-preset-version <list>]` |
| UT-14 | 터미널 출력 | UT-06 · UT-07 의 표준 오류 | 한글 없음 |

## T10 · feat: doctor 의 ci gate 절과 UI Doctor 문구

### 상위 Requirement

- relates to #217

### 작업 내용

doctor 가 CI 게이트의 상태와 사람이 할 일(넘겨받기, GitLab include, 남은 옛 검증 호출, 정책)을 알린다. 원격(forge 설정 · ruleset · CI 변수)은 보지 않는다.

- 명세 6, 11-1 의 "doctor", 11-3
- `src/harness/readiness/items.py`(`doctor_items`): `generated files` 절 뒤에 `ci gate` 절을 둔다. 줄은 명세 6절 표의 조건마다 하나다
  - "게이트를 생성하는 루트" 는 명세 2-1 표의 첫 행이다
  - "게이트가 아닌 CI 파일" 은 github 면 `.github/workflows/` 바로 아래의 `*.yml` · `*.yaml` 가운데 게이트가 아닌 것, gitlab 이면 루트 `.gitlab-ci.yml` 이다. 줄에 문자열이 있는지만 보고 YAML 을 해석하지 않는다
  - `<n> preset source(s) not allowed by policy` 의 수는 T8 의 판정 함수로 센다
  - 착수 시점 `develop` 에 #221 이 있으면 `<경로> runs script/run-lint-test.sh` 줄은 내지 않는다 — #221 3-4 의 `verification` 절 줄이 맡는다
  - `--remote` 에도 원격 점검을 더하지 않는다
- `status` 는 doctor 항목을 쓰므로 같은 줄이 나온다
- `src/ui/lib/doctor.js`: `SECTIONS` 에 `"ci gate": "CI 게이트"`, 새 줄마다 사람이 읽는 설명과 조치
- `src/ui/lib/doctor.test.js`: `ci gate` 절의 줄마다 설명이 나오는 케이스
- 건드릴 파일: `src/harness/readiness/items.py`, `src/ui/lib/doctor.js`, `src/ui/lib/doctor.test.js`, `src/test/render-test.sh`

### 완료 조건

- [ ] 명세 6절 표의 행마다 그 조건을 만든 설치본에서 명세의 상태 · `what` · `detail` 이 나온다
- [ ] `doctor --json` 의 항목 `section` 이 `ci gate` 이고, 그 절이 `generated files` 절 바로 뒤에 온다
- [ ] 게이트가 아닌 CI 파일 판정이 github 는 `.github/workflows/` 바로 아래의 `*.yml` · `*.yaml`(게이트 제외), gitlab 은 루트 `.gitlab-ci.yml` 만 본다
- [ ] `doctor --remote` 가 이 절 때문에 원격을 부르지 않는다
- [ ] UI 가 `ci gate` 절의 줄마다 설명을 낸다(`doctor.test.js`)
- [ ] 새 CLI 문구에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성된 게이트 | 리포 루트 설치 | ok, `<게이트 경로>`, `template: built-in` |
| UT-02 | preset 템플릿 | 템플릿을 둔 preset 을 잇는 설치 | ok, `template: preset <출처>` |
| UT-03 | 프로젝트 파일 | 매니페스트에 없는 게이트 파일 | warn, `… is the project's file, not the generated gate`, ``run `harness render --adopt` …`` |
| UT-04 | 게이트 없음 | 생성 게이트 삭제 | bad, `<게이트 경로> is missing` |
| UT-05 | GitLab 루트 없음 | gitlab 설치에서 루트 `.gitlab-ci.yml` 삭제 | warn, `.gitlab-ci.yml is missing` |
| UT-06 | include 없음 | 루트 `.gitlab-ci.yml` 에서 include 줄 삭제 | warn, `.gitlab-ci.yml does not include .gitlab/harness-verify.yml` |
| UT-07 | 옛 검증 호출 | `.github/workflows/old.yaml` 에 `script/run-lint-test.sh` 줄 | warn, `.github/workflows/old.yaml runs script/run-lint-test.sh` |
| UT-08 | 서브프로젝트 | 서브프로젝트 설치 | ok, `no CI gate in a subproject` |
| UT-09 | 허용 출처 | `preset_sources` 를 둔 체인 — 모두 허용 · 하나 어긋남 | ok `preset sources allowed by policy` · bad `1 preset source(s) not allowed by policy` |
| UT-10 | 최소 버전 정책 | `check_min_preset_version = true` | ok, `the CI gate checks minimum preset versions` |
| UT-11 | JSON · 위치 | `doctor --json` | `ci gate` 항목들이 `generated files` 항목 바로 뒤 |
| UT-12 | UI 설명 | `doctor.test.js` 에서 위 줄마다 `explain()` | 설명이 비지 않고 조치가 줄과 맞다 |
| UT-13 | 터미널 출력 | `doctor` 출력의 `ci gate` 절 | 한글 없음 |

## T11 · docs: 운영 안내 docs/workflow/ci-gate.md 와 docs/workflow 문서 표 · 층 표 반영

### 상위 Requirement

- relates to #217

### 작업 내용

CI 게이트를 쓰는 사람과 preset 작성자가 읽을 운영 안내를 관리 문서로 두고, `docs/workflow/` 의 기존 문서를 게이트가 생성 파일이고 preset
정책을 검사한다는 사실에 맞춘다.

- 명세 7, 10절의 `docs/workflow/flow.md` 두 행과 `docs/workflow/README.md` 행
- `src/templates/managed/docs/workflow/ci-gate.md`(신규): 명세 7절의 일곱 항목 — 무엇이 생성되는가, 보장 범위(잡는 것 · 잡지 못하는 것),
  여러 리포에 걸친 강제, 최소 버전 변수, preset 작성자에게, 이관, GitLab. 명세가 확인 필요로 둔 사실은 `<!-- TBD: 확인 필요 -->` 로 그대로 둔다
- `src/templates/managed/docs/workflow/README.md`: 문서 표에 `ci-gate.md` 행. 같은 문서 "파일은 세 부류다" 표의 생성 행에 CI 게이트 두 경로를 더한다
- `src/templates/managed/docs/workflow/flow.md`: 층 표 CI 행의 막는 대상에 "설정과 어긋난 생성물·관리 파일, preset 정책", 우회에 "필수 체크 지정은 forge 설정이다(`docs/workflow/ci-gate.md`)".
  검증 루프의 머지 전 CI 줄에 preset 정책 검사
- `src/bin/harness render` 로 이 리포의 `docs/workflow/` 와 `.harness/managed` 를 갱신한다
- 건드릴 파일: `src/templates/managed/docs/workflow/ci-gate.md`(신규) · `README.md` · `flow.md`, render 로 갱신되는 `docs/workflow/` · `.harness/managed`

### 완료 조건

- [ ] `ci-gate.md` 가 명세 7절의 일곱 항목을 담고, 확인되지 않은 forge 사실(플랜 조건 · 체크 지정 방식 · GitLab 조건 · `include: local` 표기)을 사실처럼 적지 않고 `<!-- TBD: 확인 필요 -->` 로 남긴다
- [ ] 체크 이름(github `verify`, gitlab `harness-verify`), 변수 이름 `HARNESS_MIN_PRESET_VERSION` 과 명세 5-3 의 값 형식, preset 경로 `ci/<host>/harness-verify.yml`, `[ci].setup` 이 명세와 같다
- [ ] 이관 절이 GitHub · GitLab · 옛 검증 호출을 가진 다른 워크플로 셋을 적는다
- [ ] `docs/workflow/README.md` 의 문서 표 · 부류 표와 `flow.md` 의 층 표 · 검증 루프가 바뀐다
- [ ] 이 리포의 `docs/workflow/` 가 정본과 같고 doctor 의 문서 참조 검사에 깨진 참조가 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 관리 문서 설치 | render 뒤 이 리포 | `docs/workflow/ci-gate.md` 가 정본과 같고 `.harness/managed` 에 해시 줄 |
| UT-02 | 생성물 일치 | `harness check` | 어긋난 생성 · 관리 파일 없음 |
| UT-03 | 문서 참조 | `harness doctor` 의 `references` 절 | `ci-gate.md` 와 그것을 가리키는 링크에 깨진 참조 없음 |
| UT-04 | 확인 필요 표기 | `ci-gate.md` | 명세 7절의 TBD 다섯 자리에 `<!-- TBD: 확인 필요 -->` |
| UT-05 | 이름 일치 | `ci-gate.md` 의 체크 이름 · 변수 이름 · preset 경로 | 명세 2-5 · 5-3 · 2-6 과 같음 |

## T12 · docs: README 와 다른 명세(58 · 60 · 216)에 CI 게이트 생성과 preset 정책 반영

### 상위 Requirement

- relates to #217

### 작업 내용

사람이 읽는 README 와, 같은 사실을 현재형으로 적은 다른 명세를 바뀐 부류와 정책에 맞춘다. README "업데이트" 절은 T1 이 고쳤다.

- 명세 10절의 README 행 다섯과 명세 행 셋, 2-6 의 #216 개정 문안
- `README.md`
  - "파일은 세 부류다" 표: 생성 행에 CI 게이트(`.github/workflows/harness-verify.yml` · `.gitlab/harness-verify.yml`), 소유 행의 "CI 설정" 을 "GitLab 의 루트 `.gitlab-ci.yml` · 서브프로젝트 CI 골격" 으로
  - "CI 설정은 첫 설치 때 한 번만 깔린다" 단락: 명세 2-1 · 4절의 사실 — 게이트는 생성 파일이고, 서브프로젝트 골격과 GitLab 루트 파일은 소유 파일이며, 기존 파일은 `--adopt` 로 넘겨받고, uninstall 이 게이트를 지우고, 운영 안내는 `docs/workflow/ci-gate.md`
  - "`harness.toml` 이 정하는 것" 표: `ci.setup` 행과 `policy.preset_sources` · `check_min_preset_version` 행, `branches.base` · `protected` 행에 "CI 게이트의 트리거 브랜치", `forge.tracker` · `review_host` 행에 "CI 게이트 경로"
  - 명령 표: `harness check` 행에 `--min-preset-version`(CI 게이트가 넘긴다)
  - "preset" 절의 preset 리포 형식: `ci/github/harness-verify.yml` · `ci/gitlab/harness-verify.yml` 과 `ci/` 아래에는 그 둘만 둔다는 것, 자세한 것은 `docs/workflow/ci-gate.md`
- `docs/spec/58-separate-managed-and-project-parts.md` 3-1: "소유 파일과 CI 골격은 대상이 아니다" 를 명세 10절의 문장으로, 같은 문서의 "CI 골격" 표기를 같은 뜻으로
- `docs/spec/60-automate-work-prerequisites.md`: "`.github/workflows/` · `.gitlab-ci.yml`(CI 골격, 소유 파일)" 을 "CI 게이트(생성) · GitLab 루트 `.gitlab-ci.yml`(소유)" 로
- `docs/spec/216-org-presets.md`: 3-1 받는 파일 표에 두 행, 3-2 git 받기 안내문의 help 첫 줄, 4-2 사본 예시에 깊이 1 의 `ci/github/harness-verify.yml` 한 줄 — 명세 2-6 의 개정 문안 그대로
- 건드릴 파일: `README.md`, `docs/spec/58-separate-managed-and-project-parts.md`, `docs/spec/60-automate-work-prerequisites.md`, `docs/spec/216-org-presets.md`

### 완료 조건

- [ ] README 세 부류 표의 생성 행에 게이트 두 경로가 있고, 소유 행에 "CI 설정" 이 남지 않는다
- [ ] README 에 게이트를 "첫 설치 때만 깔린다" · "uninstall --purge 도 지우지 않는다" 로 적은 문장이 남지 않고, 2-1 · 4절의 사실과 `docs/workflow/ci-gate.md` 링크가 있다
- [ ] README `harness.toml` 표 · 명령 표 · preset 절이 위 항목을 담는다
- [ ] 세 명세의 해당 문장이 명세 10절 · 2-6 의 문안이고, 그 밖의 절은 바뀌지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 옛 서술 없음 | `README.md` 에서 "CI 설정은 첫 설치 때" 검색 | 없음 |
| UT-02 | 새 키 행 | `README.md` 의 `harness.toml` 표 | `ci.setup` · `policy.preset_sources` · `policy.check_min_preset_version` 행 |
| UT-03 | 명령 표 | `README.md` 의 명령 표 `harness check` 행 | `--min-preset-version` |
| UT-04 | #216 개정 문안 | `docs/spec/216-org-presets.md` 3-1 · 3-2 · 4-2 | 명세 2-6 표의 문안과 같음 |
| UT-05 | 문서 참조 | `harness doctor` 의 `references` 절 | 깨진 참조 없음 |

## T13 · docs: 담당 범위 · 아키텍처 · 용어 문서에 CI 게이트와 preset 정책 반영

### 상위 Requirement

- relates to #217

### 작업 내용

에이전트가 근거로 읽는 프로젝트 사실 문서를 CI 게이트 생성과 preset 정책 검사에 맞춘다. 세 문서는 보호 문서이고, 이 개정은
**2026-10-09 결정 게이트에서 사용자가 허용한 범위**다 — 명세 12절 표의 위치만 고친다. 표에 없는 절은 건드리지 않고, 같은 절을 먼저
고친 명세(#207 · #216 등)의 문장은 그대로 두고 그 위에 더한다. 리뷰나 가드에서 보호 문서 수정으로 걸리면 사람이 대응한다.

- 명세 12-1 · 12-2 · 12-3
- `.ai/project/architecture.md`: "구성 요소" 의 `src/templates/` 항목, "데이터 흐름" 의 렌더, "신뢰 경계" 의 들어오는 입력, "새 코드를 둘 곳", "검사하지 않는 것" — 12-1 표의 사실
- `.ai/project/glossary.md`: "용어" 표의 `소유 파일` 괄호 목록, 새 행 `CI 게이트` · `preset 정책` — 12-2 표의 사실
- `.ai/project/scope.md`: "할 수 있는 일" · "만들지 않는 것" — 12-3 표의 사실
- `.ai/AI_AGENT.md` 는 생성 파일이다. 세 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/architecture.md` · `glossary.md` · `scope.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] 세 문서가 명세 12-1 · 12-2 · 12-3 표의 위치마다 반영할 사실을 담는다
- [ ] diff 가 표의 위치에만 있다 — 다른 절의 바이트가 그대로다
- [ ] glossary 의 `소유 파일` 행에 "CI 설정" 이 남지 않는다
- [ ] render 뒤 `.ai/AI_AGENT.md` 가 세 문서와 일치하고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/217-org-ci-gate` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 세 문서 수정 뒤 render, `harness check` | 어긋난 생성 파일 없음 |
| UT-02 | 옛 표기 없음 | `.ai/project/glossary.md` · `.ai/AI_AGENT.md` 의 `소유 파일` 행 | "CI 설정" 없음 |
| UT-03 | 범위 | `git diff` 의 바뀐 절 | 명세 12절 표의 위치뿐 |
