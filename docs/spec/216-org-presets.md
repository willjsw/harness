# 조직·스택 preset 상속과 고정 — `extends` · `harness pull`

프로젝트 `harness.toml` 의 `extends` 가 git 태그로 고정한 preset 을 가리키면, `harness pull` 이 그 preset 과
그 preset 이 잇는 preset 들(체인)을 받아 `.harness/preset/` 에 두고 `.harness/preset.lock` 에 고정한 뒤 다시 렌더한다.
설정 계층의 preset 자리는 이 사본으로 채워지고, 역할·절차 메모는 preset 의 것이 프로젝트 메모 앞에 붙는다.
사본과 lock 은 대상 리포에 커밋되므로 클론한 사람과 CI 는 네트워크 없이 같은 결과를 얻는다. 설정을 읽을 때마다
사본을 lock 과 대조한다.

기준 코드는 #206 · #207 · #208 의 변경이 들어간 통합 브랜치다. 아래는 그 이슈들이 정하고 이 명세가 그대로 쓴다.

| 이슈 | 이 명세가 쓰는 것 |
|---|---|
| #206 | 패키지 `src/harness/` 의 모듈 지도(명령 하나에 모듈 하나), 고정 사본의 `.harness/lib/` |
| #207 | 레이어 로더와 키별 병합 규칙, `locked` 의 표기와 거부, 개인 레이어 허용 키, `set` 이 파일에 없는 키를 더하는 규칙, `harness schema` 의 값 출처(`layers` · `sources`)와 레이어 이름표 함수, 명령마다 읽는 설정(공유 · 실효), 씨앗 설정 원형 |
| #208 | `workflow` 블록, 빈 하위 절차, 드라이버 실행 상태 파일과 그 선택 필드 `preset`, `--resume` |

정본 위치:

| 대상 | 정본 |
|---|---|
| 참조 판정 · 체인 · git 받기 · 트리 멤버 판정 · 사본 쓰기 · lock 읽기·쓰기 · 내용 해시 · 대조 | `src/harness/preset/` (새 패키지) |
| `harness pull` | `src/harness/commands/pull.py` |
| `install --preset`, 사본 교체에서 preset 사본 남기기 | install 명령 모듈 |
| `set extends` | set 명령 모듈 |
| doctor `preset` 절 | doctor 명령 모듈 |
| 레이어 로더의 preset 자리, preset 레이어 id 와 schema `layers` 의 preset 항목 | `src/harness/config/` |
| 메모 렌더 순서 | 역할 어댑터와 절차 문서를 만드는 render 모듈 |
| 실행 상태의 `preset` 값과 재개 검사 | `src/harness/workflow/` |
| `extends` 설명 주석 | 씨앗 설정 원형 |
| UI doctor 문구 | `src/ui/lib/doctor.js` |
| preset 레이어의 이름표 | `src/ui/lib/labels.js` |
| 규칙 문서 10장 | `src/templates/generated/.ai/AI_AGENT.md` |
| 사람용 설명 | `README.md` · `src/templates/managed/docs/workflow/changing.md` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/test/unit/` · `src/ui/lib/doctor.test.js` · `src/ui/lib/labels.test.js` |

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

- **`extends` 가 없는 프로젝트는 그대로다.** `.harness/preset/` 와 lock 이 생기지 않고, 생성물과 매니페스트는 바이트 단위로 같다
- 파일 세 부류(ADR 0002)는 그대로다. preset 사본은 render 의 출력이 아니라 **입력**이고, 매니페스트에 들지 않는다. 매니페스트 형식은 바뀌지 않는다
- 고정 사본(ADR 0005)은 그대로 install 만 쓰고, 전역 CLI 는 그쪽으로 넘긴다. `.harness/` 는 하네스 입력의 사본을 두는 자리이고 항목마다 쓰는 명령이 정해져 있다(4-1)
- 네트워크는 `harness pull` 과 `harness install --preset` 만 쓴다. render · check · doctor · run 과 CI 는 리포 안의 사본으로 돈다
- 새 명령 `pull`, install 의 새 플래그 `--preset`, 설정의 새 키 `extends` 가 생긴다
- 이 단계의 preset 백엔드는 git 태그 하나다. OCI 백엔드(#218)는 같은 lock 형식 · 내용 해시 · 멤버 판정을 쓴다

## 2. 참조 — `extends`

### 2-1. 형식

```toml
extends = "https://git.example.com/acme/harness-preset-python@v2.3.0"
```

`git.example.com` 은 예시 호스트다. 참조는 **전체 참조**만 받는다 — 호스트 없는 이름, 짧은 이름, 다른 스킴은 받지 않는다.

| 부분 | 규칙 |
|---|---|
| 스킴 | `https://` 로 시작한다(소문자) |
| 호스트 | 소문자 영숫자와 `-` 로 된 이름을 `.` 으로 이은 것. 이름은 `-` 로 시작하거나 끝나지 않는다. 뒤에 `:<포트>`(1~65535)를 붙일 수 있다 |
| 경로 | 호스트 뒤의 `/` 다음. `/` 로 나눈 성분이 하나 이상이고, 성분마다 `[A-Za-z0-9._-]+` 이며 `.` · `..` 이 아니다. 빈 성분과 끝의 `/` 가 없다 |
| 태그 | `@` 뒤. `[A-Za-z0-9][A-Za-z0-9._-]*` 이고, `..` 을 담지 않으며, `.` 이나 `.lock` 으로 끝나지 않는다. git 태그 이름(`refs/tags/<태그>`)이다 — 브랜치를 가리키지 않는다 |

- `@` 는 호스트와 경로에 들 수 없으므로 문자열 안에 하나뿐이다
- `https://<호스트>/<경로>` 를 **출처**, `@` 뒤를 **태그**라 한다. 둘 다 적힌 문자열 그대로 쓴다 — 정규화하지 않는다
- 태그는 정확한 버전으로 다룬다 — 움직이는 참조로 쓰지 않는다. 리포 안에서는 lock 의 `resolved` 가 받은 커밋을 고정하고, 태그가 원격에서 옮겨졌으면 다음 pull 이 경고한다(7-3)
- 판정은 문자열로만 하고 원격에 묻지 않는다
- 하네스는 참조를 바꾸지 않고 git 에 그대로 넘긴다. SSH 로 받는 사람은 자기 git 설정의 `url.<ssh 주소>.insteadOf` 로
  https 참조를 바꿔 받는다 — 커밋되는 문자열은 사람마다 같다

어긋남과 사유 — 위에서부터 처음 맞는 하나:

| 어긋남 | 사유 |
|---|---|
| `https://` 로 시작하지 않는다(`http://` · `ssh://` · `git://` · `file://` · `ext::` · scp 형식 `git@host:org/repo` · 로컬 경로 · `-` 로 시작 등) | `not an https:// reference` |
| `https://` 뒤 첫 `/` 앞에 `@` 가 있다(자격증명) | `it carries credentials` |
| `@<태그>` 가 없다 | `it has no @<tag>` |
| 그 밖의 형식 어긋남(대문자 호스트, `?` · `#` · `%` · 공백, 규칙 밖 문자) | `not a full git reference` |

거부 안내는 **값을 옮기지 않는다.** 종료 코드 2.

```
error: extends is not a full git reference (it carries credentials)
  --> harness.toml

help: extends takes https://<host>/<path>@<tag> — git reads credentials from your own git setup
      if that credential was ever committed, revoke it and issue a new one
```

- `-->` 는 그 `extends` 를 담은 파일이다. preset 의 `extends` 면 `preset.toml of <그 preset 의 출처>@<태그>` 다
- 둘째 help 줄은 사유가 `it carries credentials` 일 때만 낸다

### 2-2. 적는 곳

| 레이어 | `extends` |
|---|---|
| 내장 기본값 | 두지 않는다 |
| preset (`preset.toml`) | 최상위 키, 선택 — 그 preset 의 부모 |
| 프로젝트 `harness.toml` | 최상위 키, 선택 — 체인의 시작 |
| 개인 `harness.local.toml` | 둘 수 없다 — #207 의 개인 허용 키 밖이라 거부된다 |

- `extends` 는 설정 값이 아니라 레이어를 잇는 키다. 실효 설정에 들지 않고 템플릿 변수(`derive()`)에도 들지 않는다
- 프로젝트 레이어의 값은 설정을 읽을 때 2-1 로 판정한다. preset 의 값은 pull 의 받기(7-3)가 판정한다

### 2-3. 체인

- 프로젝트가 가리키는 preset 이 **깊이 1**, 깊이 d 의 preset 이 `extends` 로 가리키는 preset 이 깊이 d+1 이다
- 깊이 상한은 3 이다(상수 `PRESET_DEPTH_LIMIT`). 깊이 3 의 preset 이 `extends` 를 가지면 거부한다
- 같은 출처가 체인에 두 번 나오면 순환으로 보고 거부한다. 태그가 달라도 같다 — 한 체인에 같은 preset 의 두 버전이 섞이지 않는다
- 레이어 순서는 내장 기본값 ← 깊이 3 ← 깊이 2 ← 깊이 1 ← 프로젝트 ← 개인이다. 조직 preset 은 깊은 쪽, 스택 preset 은 얕은 쪽에 놓인다

```
error: the preset chain is deeper than 3
  1  https://git.example.com/acme/preset-python-django@v1.0.0
  2  https://git.example.com/acme/preset-python@v2.3.0
  3  https://git.example.com/acme/preset@v1.4.0
  4  https://git.example.com/acme/preset-base@v0.9.0
nothing was changed

help: a preset chain holds at most 3 presets — fold one into another
```

```
error: the preset chain comes back to https://git.example.com/acme/preset
  1  https://git.example.com/acme/preset-python@v2.3.0
  2  https://git.example.com/acme/preset@v1.4.0
  3  https://git.example.com/acme/preset@v1.3.0
nothing was changed

help: a preset appears in a chain once — point its extends at a different preset
```

## 3. preset 저장소 형식

preset 은 git 리포 하나다. 리포 하나에 preset 하나이고, 그 루트에 둔다.

### 3-1. 받는 파일

태그가 가리키는 커밋의 트리에서 아래 표의 경로만 받는다. 이 표를 **받는 파일 표**라 한다.

| 경로 | 필수 | 뜻 |
|---|---|---|
| `preset.toml` | 필수 | 설정 레이어와 preset 머리(3-3) |
| `project/roles/<이름>.md` | 선택 | 역할 메모 — 그 역할의 에이전트 정의에 붙는다(6-2) |
| `project/workflows/<이름>.md` | 선택 | 절차 메모 — 그 절차 문서에 붙는다(6-2) |

- `<이름>` 은 `[a-z][a-z0-9-]{1,30}` 이다
- 표의 경로가 지나는 디렉터리 가운데 리포 루트를 뺀 것 — `project` · `project/roles` · `project/workflows` — 을 **받는 디렉터리**라 한다
- 받는 디렉터리 아래(몇 단계든)의 항목은 표의 경로이거나 받는 디렉터리여야 한다. 그 밖의 것이 하나라도 있으면 preset 을 거부한다
- 받는 디렉터리 밖에서 표에 없는 항목은 받지 않는다. 읽지도 판정하지도 않는다(README · CI 설정 · 테스트 등)
- preset 이 실어 나를 파일을 더할 때는 이 표에 행을 더한다. 받는 디렉터리와 멤버 판정(3-2)은 표에서 나온다.
  `ci/github/harness-verify.yml` · `ci/gitlab/harness-verify.yml` 두 행은 #217 이 더한다 — 그러면 `ci` · `ci/github` · `ci/gitlab` 이
  받는 디렉터리가 되어 `ci/` 아래에는 그 두 파일만 받는다
- `preset.toml` 과 메모는 UTF-8 이어야 한다. 아니면 `error: preset <참조> has a file that is not UTF-8 text` 로 거부한다 — 경로를 옮기지 않는다

### 3-2. 트리 멤버 판정

판정은 함수 하나가 한다. 입력은 백엔드가 만든 (경로, 종류) 목록이고, 종류는 파일 · 디렉터리 · 심볼릭 링크 · 서브모듈 · 그 밖 가운데 하나다.

| 부르는 쪽 | 목록 | 종류 |
|---|---|---|
| git 받기(7-3) | `git ls-tree -r -t -z --full-tree <resolved>` 의 항목, 그 순서대로 | 모드 `100644` · `100755` → 파일, `040000` → 디렉터리, `120000` → 심볼릭 링크, `160000` → 서브모듈 |
| 사본 대조(4-2 · 5-1) | `.harness/preset/<깊이>/` 를 링크를 따라가지 않고 걸은 항목, 경로의 UTF-8 바이트 순. `check --staged` 는 `git ls-files -s -z -- .harness/preset/<깊이>` 의 항목. 경로는 그 깊이 디렉터리 기준으로 바꿔 넘긴다 | 디스크는 링크를 따라가지 않은 파일 종류. 인덱스는 git 받기와 같은 모드 대응 |
| OCI 받기(#218) | tar 멤버. tar 전용 검사를 통과한 뒤 이 함수를 부른다 | #218 이 정한다 |

목록의 항목을 차례로 보고 처음 어긋난 항목에서 멈춘다. 항목마다 경로를 먼저 보고 종류를 본다.

| 항목의 경로 | 판정 | 어긋날 때의 사유 |
|---|---|---|
| 받는 디렉터리 아래인데 표의 경로도 받는 디렉터리도 아니다 | 거부 | `not a preset path` |
| 표의 경로 | 파일이어야 한다 | `a symbolic link` · `a submodule` · `not a regular file` |
| 받는 디렉터리 | 디렉터리여야 한다 | `a symbolic link` · `a submodule` · `not a directory` |
| 받는 디렉터리 밖이고 표에 없다 | 판정하지 않는다. 받지 않은 항목으로 돌려준다 | — |

- 목록에 디렉터리 항목이 없어도 된다 — 파일 경로가 부모 디렉터리를 함의한다
- 끝까지 통과하면 목록에 `preset.toml` 이 파일로 있어야 한다. 없으면 거부한다
- 통과하면 받을 파일 목록과 받지 않은 항목을 돌려준다. git 받기는 받지 않은 항목을 버리고, 사본 대조는 사유 `outside the preset tree` 로 거부한다. OCI 받기에서 받지 않은 항목을 어떻게 다룰지는 #218 이 정한다
- 거부하면 사유와 그 항목의 순번(목록에서 1 부터)을 돌려준다. **경로는 돌려주지 않는다** — 받은 이름은 신뢰하지 않는 입력이라 어느 백엔드의 안내문에도 옮기지 않는다
- 이름은 3-1 의 규칙을 따른다. ADR 0017 경로 규칙의 형식(성분 `[\w.-]+`, `.` · `..` 성분 없음)을 만족하는 더 좁은 집합이다
- 실행 비트는 버린다. 사본에는 보통 파일로 쓴다
- 받지 않는 항목의 종류는 보지 않는다 — git 받기에서 리포 루트의 README 가 링크여도 통과한다
- 하나라도 어긋나면 preset 전체를 거부한다. 종료 코드 2

git 받기의 안내문:

```
error: preset https://git.example.com/acme/preset@v1.4.0 has an entry the harness does not accept (a symbolic link, entry 7)
nothing was changed

help: a preset holds regular files only — preset.toml, and notes under project/roles/ and project/workflows/
      the entry number counts the lines of `git ls-tree -r -t --full-tree v1.4.0` in the preset repository
```

- 괄호 안은 함수가 돌려준 사유와 순번이다. 둘째 help 줄의 태그는 그 preset 의 태그다
- `preset.toml` 이 없으면 `error: preset <참조> has no preset.toml at its root`
- 사본 대조의 사유는 5-3 의 줄로 낸다

### 3-3. `preset.toml`

```toml
extends = "https://git.example.com/acme/harness-preset@v1.4.0"
locked = ["invariants.distinct_reviewer"]

[preset]
schema = 1
requires = "0.14.0"

[review]
max_rounds = 4
```

| 키 | 필수 | 규칙 |
|---|---|---|
| `[preset].schema` | 필수 | 정수. 이 하네스가 읽는 형식은 `1` 이다 |
| `[preset].requires` | 선택 | `<정수>.<정수>.<정수>`. 이 preset 을 읽을 수 있는 하네스의 최소 버전 |
| `extends` | 선택 | 2-1. 부모 preset |
| `locked` | 선택 | #207 이 정한 표기 |
| 그 밖의 절 | 선택 | 설정 레이어. #207 의 키별 규칙으로 판정한다 |

- `[preset]` 에 다른 키가 있으면 거부한다
- `[project]` 를 두면 거부한다 — 프로젝트의 이름은 프로젝트 레이어의 것이다
- `[preset]` · `extends` · `locked` 는 레이어를 다루는 키라 병합 전에 뗀다
- `schema` 가 1 이 아니면 `error: preset <참조> uses preset schema <N> — this harness reads 1` 로 거부한다
- 요구 버전 비교: 이 하네스의 버전(`harness version` 첫 줄의 값)에서 `+` 와 그 뒤를 떼고 세 정수로 읽어 `requires` 와 정수 순서로 비교한다.
  읽지 못하면 미달로 본다
- OCI 아티팩트의 annotation `requires` · `schema` 는 이 두 값을 옮긴 것이다(#218)

## 4. `.harness/` 의 자리

### 4-1. 항목과 쓰는 명령

| 항목 | 무엇 | 쓰는 명령 | 해시를 적는 곳 |
|---|---|---|---|
| `bin/` · `lib/` · `templates/` · `VERSION` (`PINNED_PARTS`) | 고정 사본 | install | `.harness/managed` |
| `generated` · `managed` | 매니페스트 | render · install | — |
| `preset/` · `preset.lock` (`PRESET_PARTS`) | preset 사본과 lock | pull · `install --preset` | `.harness/preset.lock` 에만 |

- `.harness/` 안의 그 밖의 항목은 install 이 고정 사본을 갈아 끼울 때 걷는다
- preset 사본은 render 가 읽기만 한다. render 의 정리(`prune()`)는 `.harness/` 아래를 지우지 않는다

### 4-2. preset 사본 — `.harness/preset/<깊이>/`

받은 파일을 깊이마다 같은 상대 경로로 둔다.

```
.harness/
  preset/
    1/
      preset.toml
      project/roles/developer.md
    2/
      preset.toml
      project/workflows/work.md
  preset.lock
```

- `.harness/preset/` 에는 디렉터리 `1` … `N`(N 은 체인 길이)만 있다
- 각 디렉터리는 3-2 의 판정 함수를 통과하고 받지 않은 항목이 없다. 그래서 받는 파일 표(3-1)의 파일과 받는 디렉터리만 있고,
  파일은 일반 파일이며 경로 성분에 링크가 없다
- 체인이 비면 `.harness/preset/` 도 lock 도 없다

### 4-3. lock — `.harness/preset.lock`

```toml
# harness pull 이 쓴다. 손으로 고치지 않는다 — extends 를 고치고 `harness pull` 을 돌린다.

format = 1

[[preset]]
source = "https://git.example.com/acme/harness-preset-python"
tag = "v2.3.0"
resolved = "<커밋 id — 소문자 16진 40자>"
content = "sha256:<소문자 16진 64자>"

[[preset]]
source = "https://git.example.com/acme/harness-preset"
tag = "v1.4.0"
resolved = "<커밋 id>"
content = "sha256:<…>"
```

| 키 | 뜻 |
|---|---|
| `format` | lock 형식 번호. `1` |
| `[[preset]]` | 체인의 preset 하나. 깊이 순(1 부터) |
| `source` | 출처 — 그 preset 을 가리킨 참조에서 태그를 뗀 것 |
| `tag` | 태그 |
| `resolved` | 받은 것의 불변 식별자 |
| `content` | 사본의 내용 해시. `sha256:` 뒤에 4-4 의 해시(소문자 16진 64자) |

백엔드는 `source` 의 스킴이 정하고, `source` · `tag` · `resolved` 의 형식도 스킴마다 다르다.

| `source` 의 스킴 | 백엔드 | `source` | `tag` | `resolved` |
|---|---|---|---|---|
| `https://` | git (이 명세) | 2-1 의 출처 `https://<호스트>/<경로>` | 2-1 의 태그 규칙 | 태그가 가리키는 커밋 id. 주석 태그면 벗긴 커밋. 소문자 16진 40자 또는 64자 |
| `oci://` | OCI (#218) | `oci://<레지스트리>/<저장소>` — #218 2-2 의 태그를 뺀 출처 | #218 2-1 의 태그 규칙 | manifest digest. `sha256:` 뒤에 소문자 16진 64자 |

- `oci://` 행은 OCI 백엔드와 함께 #218 이 판정에 더한다. 표에 행이 없는 스킴의 `source` 는 읽을 수 없는 lock 이다
- `content` 는 두 백엔드가 같은 형식이고 같은 알고리즘(4-4)으로 계산한다
- 참조를 출처와 태그로 나누는 규칙도 스킴이 정한다 — `https://` 는 2-1 의 `@`, `oci://` 는 #218 2-2. 순환 판정(2-3)과
  체인 연결 · 프로젝트 참조 대조(5-1)는 나눈 출처와 태그로 비교한다
- 거꾸로 잇는 것도 스킴을 따른다. 이 명세의 안내문 · doctor 가 `<출처>@<태그>` 로 적은 자리와 schema 의 `ref`(6-1)는 그 스킴의 참조 형식으로 이은 값이다
- 쓰는 형식은 고정이다 — 위의 주석 한 줄, 빈 줄, `format = 1`, 그리고 항목마다 빈 줄 · `[[preset]]` · 네 키를 이 순서로.
  값은 TOML 기본 문자열이고 줄은 LF 로 끝난다. 같은 체인이면 같은 바이트가 나온다
- 읽을 때의 판정: TOML 이고, `format` 이 1 이고, 항목이 1~3 개이고, 항목마다 키가 정확히 넷이고, `content` 가 위 형식이고,
  `source` 의 스킴이 표에 있고 `source` · `tag` · `resolved` 가 그 행의 형식을 지킨다. 어긋나면 읽을 수 없는 lock 이다(5-1)
- `resolved` 의 **짧은 꼴**은 `sha256:` 접두가 있으면 뗀 뒤의 앞 7자다. pull 의 출력과 경고(7-6), doctor(12절)가 이것을 쓴다

### 4-4. 내용 해시

깊이 하나의 사본(`.harness/preset/<깊이>/`)에서 계산한다.

1. 사본 안의 파일마다 사본 기준 상대 경로(`/` 구분)를 구하고, 그 경로의 UTF-8 바이트 순으로 정렬한다
2. 파일마다 `<파일 바이트의 sha256 소문자 16진 64자>  <경로>\n` 한 줄을 만든다(공백 두 칸) — `sha256sum` 출력과 같은 형식이다
3. 그 줄들을 이은 바이트의 sha256 소문자 16진 64자가 내용 해시다

- 파일의 바이트와 경로만 들어간다. 권한 · 수정 시각 · 디렉터리는 들지 않는다
- 받은 직후에는 git 객체의 바이트로 계산하고, 설정을 읽을 때는 디스크의 사본으로 계산한다. 두 값은 같다
- 하네스 없이 계산하면 이렇다(사본 디렉터리에서). 출력의 앞 64자가 `content` 의 `sha256:` 뒤와 같다

```bash
find . -type f | sed 's|^\./||' | LC_ALL=C sort | tr '\n' '\0' | xargs -0 shasum -a 256 | shasum -a 256
```

### 4-5. 체인 digest

lock 의 `content` 값을 깊이 순으로 한 줄씩(`<content>\n`) 이은 바이트의 sha256 에 `sha256:` 을 붙인 것이다.
체인이 비면 체인 digest 는 없다(`null`). 실행 상태(11절)가 쓴다.

### 4-6. 고정 사본과 나눠 다루는 지점

| 지점 | 동작 |
|---|---|
| `install_registered()` 의 사본 교체 | `.harness/` 안에서 매니페스트 둘과 `PRESET_PARTS` 를 남기고 나머지를 걷은 뒤 고정 사본을 깐다. 남기는 것은 `preset` 이 실제 디렉터리, `preset.lock` 이 일반 파일일 때다 — 링크면 다른 항목처럼 링크 자신만 걷는다 |
| 소스 리포의 install | `PINNED_PARTS` 만 걷는다. preset 사본은 건드리지 않는다 |
| `cmd_render` 의 매니페스트 쓰기 | 이전 `.harness/managed` 에서 옮기는 고정 사본 줄은 `PINNED_PARTS` 아래 경로의 줄이다 |
| `prune()` · `stale_paths()` | `.harness/` 아래 경로는 정리하지 않는다 |
| `check` 의 고정 사본 help 줄 | `PINNED_PARTS` 아래 경로가 어긋날 때 낸다 |
| `pinned_files()` · `pinned_differences()` | 고정 사본만 본다. preset 사본은 전역 CLI 대조에 들지 않는다 |
| `undo_created()` | 시작할 때 `.harness` 가 없었으면 통째로 걷는다. `install --preset` 이 이번에 깐 preset 사본도 그 안에 있다 |
| `cmd_uninstall` | `.harness/` 를 걷는다. preset 사본과 lock 도 걷힌다(13절) |

## 5. 설정을 읽을 때의 대조

### 5-1. 대조 항목

설정을 읽는 명령은 레이어를 병합하기 전에 사본을 lock 과 대조한다. 네트워크를 쓰지 않는다.

| 항목 | 통과 조건 | 결과의 분류 |
|---|---|---|
| lock | 없거나, 4-3 의 판정을 지킨다 | 읽을 수 없음 |
| 사본 구조 | lock 이 있으면 `.harness/preset/` 가 4-2 를 지키고 디렉터리가 lock 의 항목 수만큼 있다 | 읽을 수 없음 |
| `preset.toml` | 깊이마다 3-3 을 지킨다 | 읽을 수 없음 |
| 내용 | 깊이마다 4-4 의 해시가 lock 의 `content` 와 같다 | 어긋남 |
| 체인 연결 | 깊이 d 의 `extends` 가 lock 의 깊이 d+1 항목과 출처·태그가 같고, 마지막 깊이에는 `extends` 가 없다 | 어긋남 |
| 프로젝트 참조 | `harness.toml` 의 `extends` 가 lock 의 깊이 1 항목과 출처·태그가 같다. 둘 다 없으면 통과 | 어긋남 |
| 남은 사본 | lock 이 없으면 `.harness/preset/` 도 없다 | 어긋남 |
| 요구 버전 | 깊이마다 `requires` 가 이 하네스의 버전 이하다 | 어긋남 |

- **읽을 수 없음**은 preset 레이어를 만들 수 없는 경우다
- **어긋남**은 사본 그대로 preset 레이어를 만들 수 있는 경우다

### 5-2. 명령별 동작

| 명령 | 어긋남 | 읽을 수 없음 |
|---|---|---|
| `check` | 보고하고 종료 코드 1. 다른 검사도 한다 | 보고하고 종료 코드 1. 생성 파일 대조는 하지 않고, 관리 파일 대조와 매니페스트 검증은 한다 |
| `doctor` · `status` · `schema` | doctor 의 `preset` 절에 `bad` 항목을 내고, 사본대로 만든 레이어로 계속한다 | `preset` 절에 `bad` 항목을 내고, preset 레이어 없이 계속한다 |
| `pull` | 체인 연결 · 프로젝트 참조 · 요구 버전은 새로 받아 고친다. 내용 · 남은 사본은 멈춤 조건 4 | 멈춤 조건 4 |
| `install` (`--preset` 없이) | 종료 코드 2, 아무것도 바꾸지 않는다(8-2) | 같다 |
| `usage log`(#213) | 기록하지 않고 0 으로 끝난다 — 설정을 읽지 못했을 때와 같다 | 같다 |
| 그 밖에 설정을 읽는 명령 전부 | 그 명령이 설정을 읽지 못했을 때처럼 끝난다 — 아무것도 바꾸지 않고, 종료 코드는 그 명령의 설정 오류 코드다 | 같다 |

- "그 밖에 설정을 읽는 명령" 은 공유 설정이나 실효 설정(실행 계획 `run_plan()` 포함)을 읽는 명령이다. 지금의 명령으로는 `render` · `set` ·
  `steps` · `checks` · `write-doc` · `run` · `run-plan` · `fix` · `vars` · `metrics` · `forge-setup` 이고 모두 종료 코드 2 다.
  이식으로 생기는 명령은 각 명세가 적은 읽는 설정을 따른다 — 공유 설정이나 실행 계획을 읽는 명령은 여기에 들고, 그 명세의 설정 오류 코드로 끝난다
- 설정을 읽지 않는 명령(`bash-guard` · `secret-scan` · `clone-key` 등)은 대조하지 않는다
- `doctor` · `status` · `schema` 가 계속할 때 그 레이어로 만든 설정이 #207 의 검증을 통과하지 못하면 지금처럼 설정 오류로 종료 코드 2 다
- `set extends` 는 대조하지 않는다(9절). `install --preset` 은 8-1 이다
- pull 이 사본을 덮지 않는 것은 손으로 고친 내용을 알리지 않고 지우지 않기 위해서다. 사본과 lock 을 둘 다 지우면 체인이 빈 상태로 대조를 통과한다

### 5-3. 안내문

`check` 의 출력(표준 오류). 경로 열은 다른 `check` 오류와 같은 `%-52s` 폭이다.

```
error: the preset copy does not match .harness/preset.lock
  .harness/preset/1                                    content differs from the lock
  .harness/preset/2                                    missing

help: the preset copy is what `harness pull` wrote — the harness does not take hand edits to it
      restore it from git, or remove .harness/preset and .harness/preset.lock and pull again
        harness pull
```

| 대조 결과 | 첫 줄 | 줄 | help |
|---|---|---|---|
| 내용 · 사본 구조 · `preset.toml` · 남은 사본 | `the preset copy does not match .harness/preset.lock` | `.harness/preset/<깊이>` 와 `content differs from the lock` · `missing` · `not a preset copy (<사유>)` · `left over without a lock` | 위와 같다 |
| lock | `.harness/preset.lock is not a lock this harness reads` | `.harness/preset.lock` 과 사유(`not TOML` · `format <N>` · `preset[<번호>] is not an entry`) | 위와 같다 |
| 프로젝트 참조 · 체인 연결 | `harness.toml extends a preset the lock does not have` | `extends` 와 그 참조, `.harness/preset.lock` 과 깊이 1 의 참조(없으면 `nothing`) | `fetch what harness.toml names` 와 `harness pull` |
| 요구 버전 | `the preset needs a newer harness` | `<출처>@<태그>` 와 `needs <requires> — this harness is <버전>` | `upgrade the harness this project pins` 와 `harness install` |

- `not a preset copy (<사유>)` 의 사유는 3-2 의 사유와 `outside the preset tree`, 또는 3-3 의 판정 사유다. 사본 안의 항목 경로는 옮기지 않는다
- 줄의 값으로 사본 파일의 내용을 옮기지 않는다. 참조 문자열은 2-1 을 통과한 것만 낸다 — 통과하지 못한 `extends` 는 2-1 의 안내문이 대신한다
- 그 밖에 설정을 읽는 명령(5-2)은 설정 오류를 내는 자리에 같은 첫 줄 · 줄 · help 를 내고, 줄 목록 뒤 · help 앞에 `nothing was changed` 를 더한다.
  설정 오류를 내지 않는 계약의 명령(`usage log`)은 그 계약대로다
- `install` 은 프로젝트 참조 어긋남의 help 를 `harness install --preset <extends 값>` 으로 낸다(8-2)

### 5-4. `check --staged`

`check --staged` 는 lock 과 사본을 인덱스에서 읽어 대조한다 — lock 은 `git show :.harness/preset.lock`, 사본의 항목과 모드는
`git ls-files -s -z -- .harness/preset`(멤버 판정은 3-2), 파일 바이트는 `git show :<경로>`. 프로젝트 참조는 작업 트리의 `harness.toml` 로 본다 — `check --staged` 가 설정을 작업 트리에서 읽는 것과 같다.
사본을 손으로 고친 커밋과 `extends` 만 바꾼 커밋은 pre-commit 에서 막힌다.

## 6. 레이어 병합

### 6-1. preset 자리

- #207 의 레이어 로더가 비워 둔 preset 자리에 사본의 레이어가 깊은 쪽부터 들어간다(2-3 의 순서)
- 레이어 하나는 그 깊이의 `preset.toml` 에서 `[preset]` · `extends` · `locked` 를 뗀 것이다. 병합은 #207 의 키별 규칙 그대로다
- 깊이 d 의 `locked` 는 그보다 위의 레이어(얕은 preset · 프로젝트, 그리고 #207 이 정한 범위의 개인 레이어)에 걸린다. 위 레이어가 잠긴 키에 다른 값을 적으면 #207 대로 거부된다.
  거부 안내는 잠근 레이어를 그 레이어의 참조(아래 `ref`)로 가리킨다
- render · check 는 #207 대로 개인 레이어 없이 병합한다

레이어 id 와 schema 의 레이어 목록:

- preset 레이어의 id 는 `preset:<깊이>` 다 — `preset:1` 이 프로젝트가 가리키는 preset 이다
- `harness schema` 의 `layers`(#207 10절)는 아래 → 위 순서이므로 `default` · `preset:<N>` … `preset:1` · `project` · `local` 이다
- `layers` 의 preset 항목은 `{"id": "preset:<d>", "path": ".harness/preset/<d>/preset.toml", "ref": "<참조>"}` 다
  - `path` 는 하네스 루트 기준 상대 경로다
  - `ref` 는 lock 항목의 출처와 태그를 그 스킴의 참조 형식으로 이은 것이다 — git 은 `<출처>@<태그>`. preset 항목에만 있다
- `sources` · `checks[].source` 처럼 레이어 id 를 담는 값도 preset 레이어를 `preset:<d>` 로 적는다
- preset 레이어를 만들지 못하면(5-2 의 읽을 수 없음) `layers` 에 preset 항목이 없다

UI 이름표 — `src/ui/lib/labels.js`:

- #207 이 둔 레이어 이름표 함수에 preset 규칙을 더한다. `preset:<d>` 는 `preset — <ref>` 로 보인다. `ref` 는 schema `layers` 에서 같은 id 의 항목에서 읽는다
- 이름표에 `ref` 가 필요하므로 함수는 레이어 id 와 schema 의 `layers` 를 받는 순수 함수다. 같은 id 의 항목이 없으면 `preset <d>` 로 보인다
- 설정 화면의 출처 표시 · 잠근 레이어 표시(#207)와 절차의 출처 레이어 표시(#214)가 이 이름표를 쓴다

### 6-2. 메모 렌더 순서

역할 `<r>` 의 에이전트 정의(Claude · Codex 양쪽)와 절차 `<w>` 의 절차 문서 끝에 메모를 이 순서로 붙인다.

1. 깊이 N, N-1, …, 1 의 `project/roles/<r>.md` (절차는 `project/workflows/<w>.md`) — 있는 것마다 `## preset 에서 — <출처>` 절
2. 프로젝트의 `.ai/project/roles/<r>.md` (절차는 `.ai/project/workflows/<w>.md`) — 지금과 같은 `## 이 프로젝트에서` 절

- 깊은 쪽(조직)이 먼저, 프로젝트가 마지막이다 — 뒤의 지시가 더 구체적이다
- 절 제목의 `<출처>` 는 lock 의 `source` 다. 태그를 넣지 않으므로 메모가 같으면 태그를 올려도 생성물이 바뀌지 않는다
- 메모 머리의 안내 주석을 떼고 앞뒤 공백을 걷은 본문이 비어 있으면 절을 넣지 않는다 — 프로젝트 메모와 같은 규칙이다
- 설정에 없는 역할·절차의 메모는 쓰이지 않는다
- `write-doc` 은 preset 메모를 쓰지 않는다. 프로젝트 메모만 쓴다

### 6-3. 확장 지점

preset 은 절차를 통째로 주고, 프로젝트가 채울 자리를 빈 하위 절차로 둔다.

- preset 의 `preset.toml` 이 절차(예: `work`)의 한 단계를 `workflow` 블록으로 두어 하위 절차(예: `work-extra`)를 부르고,
  그 하위 절차를 빈 절차(`[workflows.work-extra]` 에 `steps = []`)로 정의한다
- 빈 절차는 하위 절차로만 둘 수 있고, 부르면 곧바로 `done` 이다. `workflow` 블록의 키 · 빈 절차의 판정 · 실행 방식(`execute`)이 같아야 한다는 규칙은 #208 이 정한다
- 프로젝트는 `harness.toml` 에 `[workflows.work-extra]` 를 정의해 채운다. #207 의 규칙대로 그 절차가 통째로 바뀌고, 부르는 절차(`work`)는 preset 의 것 그대로다
- 프로젝트가 채우지 않으면 그 단계는 아무것도 하지 않고 지나간다
- 이 명세가 더하는 판정은 없다. preset 레이어가 이 정의를 실어 나를 뿐이다

## 7. `harness pull`

### 7-1. 인자와 위임

- `harness pull [--adopt]`. `COMMANDS` 의 사용법은 `[--target DIR] [--adopt]`, 설명은 `fetch the presets harness.toml extends, lock them under .harness/ and re-render`
- `DELEGATES` 에 든다 — 고정 사본이 있으면 그 버전이 받는다. 요구 버전(멈춤 조건 1)은 그 버전과 비교한다
- `main()` 의 설정 읽기를 거치지 않는다. pull 은 프로젝트 레이어(`harness.toml`)를 직접 읽고, 레이어 병합은 새로 받은 사본으로 한다
- `--adopt` 도움말에 pull 을 더한다: `install, render, set, steps, checks, pull: take over files the harness would write, keeping each as <path>.orig`
- **pull 은 `harness.toml` 과 `harness.local.toml` 을 쓰지 않는다**

### 7-2. 순서

**준비** — 대상 리포를 바꾸지 않는다. 여기서 멈추면 대상 리포 · 인덱스 · 매니페스트가 그대로다.

1. 하네스 루트가 git 작업 트리 안인지 본다(`git rev-parse --show-toplevel`)
2. 멈춤 조건 5 — 작업 트리 미정리
3. `harness.toml` 을 읽고 `extends` 를 2-1 로 판정한다
4. 멈춤 조건 4 — 지금 사본과 lock 의 대조(5-1 의 lock · 사본 구조 · `preset.toml` · 내용 · 남은 사본)
5. 받기(7-3). `extends` 가 없으면 새 체인은 비어 있다. 체인 판정(2-3), 멤버 판정(3-2), `preset.toml` 판정(3-3), 멈춤 조건 1
6. 병합과 검증 — 내장 기본값 ← 새 체인 ← 프로젝트. 멈춤 조건 2, 그리고 #207 · 기존 검증(`validate()` 와 절차 검증)
7. render 결과 계산 — 새 체인의 메모는 임시 위치에서 읽는다
8. 매니페스트 검증과 경로 사전 판정(ADR 0017) — 이번에 바꿀 경로는 render 가 바꿀 경로 전부와 쓰고 지울 `.harness/preset/` 아래 경로, `.harness/preset.lock` 이다. 그다음 멈춤 조건 3

**반영**

9. 사본을 쓴다 — 새 체인의 파일을 쓰고(내용이 다를 때만), 새 체인에 없는 파일과 비게 된 디렉터리를 지운다. 체인이 비면 `.harness/preset/` 를 걷는다
10. lock 을 쓴다(바이트가 다를 때만). 체인이 비면 lock 을 지운다
11. render 한다 — `cmd_render` 와 같다
12. 출력(7-6)

- 9 · 10 의 쓰기와 지우기는 전부 `guarded_path()` 를 거친다
- 받기에 쓴 임시 위치는 성공 · 실패와 상관없이 지운다

### 7-3. 받기 — git

체인의 preset 마다(깊이 1 부터) 아래를 한다.

1. `git ls-remote <출처> refs/tags/<태그> refs/tags/<태그>^{}` — `^{}` 줄이 있으면 그 id, 없으면 태그 줄의 id 가 `resolved` 다. 둘 다 없으면 그 태그가 없다
2. 하네스 루트 밖의 임시 디렉터리(`tempfile.mkdtemp()`)에 `git init -q` 한 리포를 만들고 `git fetch -q --depth 1 --no-tags <출처> refs/tags/<태그>`
3. `git rev-parse FETCH_HEAD^{commit}` 이 1 의 id 와 같은지 본다. 다르면 받는 사이에 태그가 옮겨진 것으로 보고 멈춘다
4. `git ls-tree -r -t -z --full-tree <resolved>` 로 멤버를 얻어 3-1 · 3-2 로 판정한다
5. 받을 파일의 바이트를 `git cat-file blob` 으로 읽는다. 작업 트리를 만들지 않는다 — 링크가 디스크에 생기지 않는다
6. `preset.toml` 을 3-3 으로 판정하고, 내용 해시(4-4)를 계산하고, `extends` 가 있으면 다음 깊이로 간다

- 원격에 닿는 호출(1 · 2)은 `remote_call()` 방식이다 — 표준 입력을 닫고, 제어 터미널 없이 띄우고, `GIT_TERMINAL_PROMPT=0` 을 준다.
  제한 시간은 호출 하나에 120초다(상수 `PRESET_FETCH_TIMEOUT`)
- 인증은 사용자의 git 설정(credential helper · `insteadOf` · ssh-agent)이 갖는다. 하네스는 자격증명을 묻지도 저장하지도 않는다
- forge 어댑터를 거치지 않고 git 을 직접 부른다
- **git 의 출력은 판정에만 쓰고 하네스 출력에 옮기지 않는다.** `insteadOf` 가 바꾼 주소나 자격증명이 거기 담길 수 있다
- 출처는 `https://` 로 시작하므로 git 의 옵션으로 읽히지 않는다. 인자 하나로 넘긴다
- 지금 lock 에 같은 출처 · 태그의 항목이 있는데 `resolved` 가 다르면 태그가 원격에서 옮겨진 것이다. 경고를 내고(7-6) 새 커밋으로 고정한다

받기 실패의 안내(종료 코드 2):

```
error: could not fetch https://git.example.com/acme/preset@v1.4.0 (git exited 128)
nothing was changed

help: see what git says
        git ls-remote https://git.example.com/acme/preset refs/tags/v1.4.0
```

| 경우 | 첫 줄의 괄호 |
|---|---|
| git 이 0 이 아닌 코드로 끝났다 | `git exited <코드>` |
| 제한 시간을 넘겼다 | `timed out after 120s` |
| git 을 띄우지 못했다 | `git could not be started` |
| 태그가 없다 | 첫 줄이 `error: https://git.example.com/acme/preset has no tag v1.4.0` |
| 받는 사이에 태그가 옮겨졌다 | 첫 줄이 `error: the tag v1.4.0 of https://git.example.com/acme/preset moved while fetching` 이고 help 는 `pull again` |

### 7-4. 멈춤 조건

준비 단계(7-2 의 1~8)에서 멈추면 종료 코드 2 이고, 줄 목록 뒤 · help 앞에 `nothing was changed` 를 낸다.

| 번호 | 조건 | 판정 | 안내 |
|---|---|---|---|
| 1 | 요구 하네스 버전 미달 | 새 체인의 어느 preset 의 `requires` 가 이 하네스의 버전보다 높다 | 아래 ① |
| 2 | 새 preset 이 잠근 키를 프로젝트가 덮음 | 프로젝트 레이어가 새 체인의 잠긴 키에 다른 값을 적었다(같은 값은 통과 — #207) | 아래 ② |
| 3 | 새 생성 경로가 사용자 파일과 겹침 | 이번 render 가 쓸 경로에 매니페스트에 없는 파일이 있다 | 명세 58 3-3 의 안내문. 명령은 `harness pull`, `--adopt` 안내는 `harness pull --adopt` |
| 4 | 사본과 lock 불일치 | 지금 사본이 5-1 의 lock · 사본 구조 · `preset.toml` · 내용 · 남은 사본에 어긋난다 | 5-3 의 첫 표와 같다 |
| 5 | 작업 트리 미정리 | 하네스 루트 아래에 `harness.toml` · `.harness/preset/` · `.harness/preset.lock` 을 뺀 미커밋 변경(추적 파일의 수정 · 스테이지된 변경 · 무시되지 않는 추적 밖 파일)이 있다 | 아래 ⑤ |

- 조건 5 가 `harness.toml` 을 빼는 것은 `extends` 를 고친 뒤 pull 하기 때문이다. preset 사본과 lock 을 빼는 것은 조건 4 를 풀려고 둘을 지운 뒤 pull 하기 때문이다
- 판정 순서는 7-2 의 번호 순이다: 5 → 4 → 1 → 2 → 3

```
① error: preset https://git.example.com/acme/preset@v1.4.0 needs harness 0.14.0 or later (this is 0.12.0)
   nothing was changed

   help: upgrade the harness this project pins, then pull again
           harness install
```

```
② error: harness.toml sets 2 key(s) that the preset locks
     review.max_rounds                                    locked by https://git.example.com/acme/preset@v1.4.0
     invariants.distinct_reviewer                         locked by https://git.example.com/acme/preset@v1.4.0
   nothing was changed

   help: delete those keys from harness.toml so the preset's values apply, then pull again
           harness pull
```

```
⑤ error: the work tree has uncommitted changes besides harness.toml and the preset copy
     M  script/project/build.sh
     ?? notes.txt
   nothing was changed

   help: commit or stash them, then pull again — a pull that stops halfway is undone with git
           harness pull
```

- ⑤ 의 줄은 `git status --porcelain` 의 두 글자 상태와 경로다. 10줄까지 내고 넘으면 `  … <N> more` 한 줄로 줄인다
- `harness.toml` 이 없으면 다른 명령과 같은 `error: no config found` 안내다
- 하네스 루트가 git 작업 트리 밖이면: `error: pull needs the harness root inside a git work tree` · `--> <하네스 루트>` · `help: a pull that stops halfway is undone with git`
- 그 밖에 준비 단계에서 멈추는 것 — 참조 형식(2-1), 체인(2-3), 멤버(3-2), `preset.toml`(3-3), 받기 실패(7-3), 병합 검증(#207 · `validate()` 의 안내문 그대로), 매니페스트 검증과 링크(명세 58 11-4 · 11-5 의 안내문, 명령은 `harness pull`) — 도 종료 코드 2 이고 아무것도 바꾸지 않는다

### 7-5. 반영 도중 실패

반영 단계(7-2 의 9~11)는 파일마다 쓰고, 도중에 멈추면 그때까지 바꾼 파일을 되돌리지 않는다. ADR 0017 이 받아들인 범위와 같다.
멈춤 조건 5 가 있으므로 git 으로 되돌릴 수 있다.

- 멈춘 원인의 안내문(`guarded_path()` 의 직전 재검사, 쓰기 실패, render 의 오류)을 그대로 낸 뒤, 반영 단계에서 파일을 하나라도 바꿨으면 아래를 더한다. 종료 코드 2

```
error: the pull stopped after changing files — the work tree is partly updated

help: put the work tree back to the last commit, keeping harness.toml — from the harness root
        git restore --source=HEAD --staged --worktree -- . ':(exclude)harness.toml'
        git clean -fd -- . ':(exclude)harness.toml'
      then pull again
```

- 하나도 바꾸기 전에 멈췄으면 원인의 안내문과 `nothing was changed` 만 낸다

### 7-6. 출력

성공하면 종료 코드 0 이고 표준 출력에 낸다.

```
pull: https://git.example.com/acme/harness-preset-python@v2.3.0 -> 3f2a1c9 (depth 1)
pull: https://git.example.com/acme/harness-preset@v1.4.0 -> 9b8e7d6 (depth 2)
pull: .harness/preset.lock updated · 5 vendored file(s) (3 written, 1 removed)
render: …
```

| 경우 | 출력 |
|---|---|
| preset 마다 | `pull: <출처>@<태그> -> <resolved 의 짧은 꼴> (depth <d>)` |
| lock 이 바뀌었다 | `pull: .harness/preset.lock updated · <N> vendored file(s) (<W> written, <R> removed)` |
| lock 이 그대로다 | `pull: the preset is up to date` |
| `extends` 가 없고 사본이 있었다 | `pull: harness.toml extends no preset — removed the preset copy and the lock` |
| `extends` 가 없고 사본도 없었다 | `pull: harness.toml extends no preset` |

- 마지막에 render 의 출력 줄이 이어진다
- 태그가 옮겨졌으면 그 preset 줄 앞에 표준 오류로:
  `warning: the tag v1.4.0 of https://git.example.com/acme/preset now points at 9b8e7d6 (the lock had 1c2d3e4) — locking the new commit`
- **덮는 키 보고.** 프로젝트 레이어와 새 체인이 모두 적은 키 가운데 #207 의 병합 규칙이 프로젝트 값으로 덮어쓰는 것(스칼라 · 교체되는 배열 ·
  `name` 이 같은 `verify.checks` 항목 · 통째 교체되는 `workflows.<이름>`)이 값이 달라 실제로 덮였으면, 성공 출력 끝에 표준 오류로 낸다.
  합집합 목록(`docs.protected` · `branches.protected`)은 덮지 않으므로 들지 않는다

```
note: harness.toml sets 3 key(s) the preset also sets — harness.toml wins for those
  commit.tags
  review.max_rounds
  workflows.retro
  delete the ones that should follow the preset
```

- 키는 경로 순으로 20개까지 내고 넘으면 `  … <N> more` 로 줄인다. 값은 옮기지 않는다
- 아래 레이어와 값이 같은 키는 #207 의 값 출처 보고가 맡는다. pull 은 `harness.toml` 을 줄이지 않는다 — 줄이는 것은 사람이 한다

## 8. `harness install`

### 8-1. `install --preset <참조>`

- 새 플래그 `--preset REF`. `COMMANDS` 의 install 사용법은 `[--target DIR] [--adopt] [--create] [--git-init] [--preset REF]`,
  도움말은 `install: start the project from a preset (a full https://<host>/<path>@<tag> reference)`
- install 은 넘기지 않으므로 전역 CLI 의 버전으로 돈다. 요구 버전은 그 버전과 비교하고, 깔리는 고정 사본도 그 버전이다
- `<참조>` 는 2-1 로 판정한다

| 대상의 `harness.toml` | 동작 |
|---|---|
| 없다 | 씨앗 설정에 `extends = "<참조>"` 한 줄을 넣어 깔고, 그 preset 을 받아 사본과 lock 을 깐다 |
| 있고 `extends` 가 `<참조>` 와 같다 | 설정은 그대로 두고, 사본과 lock 을 그 참조대로 받아 맞춘다 |
| 있고 `extends` 가 없거나 다르다 | 아무것도 바꾸지 않고 종료 코드 2 |

```
error: harness.toml extends https://git.example.com/acme/preset-go@v1.0.0 — install --preset does not change it
nothing was changed

help: point harness.toml at the preset, then fetch it
        harness set extends https://git.example.com/acme/harness-preset-python@v2.3.0
        harness pull
```

- `extends` 가 없으면 첫 줄이 `error: harness.toml extends no preset — install --preset does not change it` 이다
- 순서: 등록 잠금 · 같은 이름 판정 → **준비**(멈춤 조건 4 · 받기 · 1 · 2 · 병합 검증 · render 계산 · 경로 사전 판정 · 3) → **반영**(디렉터리 · `git init` · 씨앗 설정 · 고정 사본 · 등록 · 사본 · lock · render).
  멈춤 조건 5 는 쓰지 않는다 — install 은 git 밖의 새 디렉터리에서도 돈다
- 경로 사전 판정에는 install 의 경로(`.harness` · `PINNED_PARTS` · 설정이 없으면 `harness.toml`)에 `.harness/preset/` 아래 경로와 `.harness/preset.lock` 을 더한다
- 준비 단계에서 멈추면 아무것도 만들지 않는다. 반영 단계에서 멈추면 지금의 install 처럼 이번 실행이 만든 것(디렉터리 · `.git` · 씨앗 설정 · 시작할 때 없던 `.harness`)을 걷는다
- 씨앗 설정에서 `extends` 줄은 씨앗 설정 원형의 `extends` 설명 주석(14-4) 바로 아래, 첫 테이블 앞에 넣는다
- 출력은 install 의 줄, 7-6 의 pull 줄, render 의 줄 순서다

### 8-2. `install` (`--preset` 없이)

- 설정에 `extends` 가 있고 5-1 의 대조를 통과하면 지금처럼 고정 사본을 갈아 끼우고 render 한다. preset 사본과 lock 은 바이트 그대로 남는다(4-6)
- 대조가 어긋나거나 읽을 수 없으면 아무것도 바꾸지 않고 종료 코드 2. 안내는 5-3 이고, 프로젝트 참조 어긋남(사본이 없는 경우 포함)이면 help 를 아래로 낸다

```
help: fetch the preset harness.toml names as part of the install
        harness install --preset https://git.example.com/acme/harness-preset-python@v2.3.0
```

- 요구 버전은 설치하려는 전역 CLI 의 버전과 비교한다 — preset 이 요구하는 버전보다 낮은 하네스로 갈아 끼우지 않는다

## 9. `harness set extends <참조>`

- `extends` 는 다른 키와 함께 바꿀 수 없다. 함께 주면 아무것도 쓰지 않고 종료 코드 2:
  `error: extends is set on its own — it needs a pull, not a render`
- `<참조>` 를 2-1 로 판정한다. 어긋나면 쓰지 않고 2-1 의 안내문, 종료 코드 2
- 쓰는 자리는 #207 의 `set` 이 파일에 없는 키를 더하는 규칙을 따른다. 최상위 키라 첫 테이블 앞이다
- **render 하지 않고** 사본과 lock 도 대조하지 않는다. 출력:

```
set: extends = "https://git.example.com/acme/harness-preset-python@v2.3.0"
  to extends = "https://git.example.com/acme/harness-preset-python@v2.4.0"

next: fetch it — render and check stop until harness.toml and the lock agree
        harness pull
```

- 키가 없던 파일이면 첫 줄이 `set: extends (not set)` 이다
- `extends` 를 빼려면 `harness.toml` 에서 그 줄을 지우고 `harness pull` 한다. pull 이 사본과 lock 을 걷는다(7-6)

## 10. 갱신 경로별로 바뀌는 커밋 대상 파일

| 경로 | 바뀔 수 있는 것 |
|---|---|
| `harness pull` | `.harness/preset/` · `.harness/preset.lock` · 매니페스트 · 입력이 바뀐 생성 파일 · 역할 설정을 따르는 관리 파일 집합 · 없던 소유 원형과 CI 골격 |
| `harness set` | `harness.toml` · 매니페스트 · 입력이 바뀐 생성 파일 · 역할 설정을 따르는 관리 파일 집합 · 없던 소유 원형과 CI 골격 |
| `harness set extends` | `harness.toml` |
| 개인 레이어 수정 | 없음 |
| 도구 업그레이드(`harness install`) | 고정 사본 · 관리 파일 · 매니페스트 · 입력이 바뀐 생성 파일 · 없던 소유 원형과 CI 골격 |
| `harness install --preset` | 위 install 의 것 · `.harness/preset/` · `.harness/preset.lock` · 설정이 없을 때 `harness.toml` |

- **이미 있는 소유 파일의 내용과 프로젝트 산출물(`docs/spec/` · `docs/plan/` · 결정 기록 본문 · 소스)은 어느 경로에서도 바뀌지 않는다**
- 없던 소유 원형과 CI 골격은 ADR 0002 대로 없을 때만 깔린다. preset 이 `forge.review_host` 를 바꾸면 그 forge 의 CI 골격이 없을 때 깔린다
- 관리 파일 집합은 역할 설정을 따른다 — preset 이 역할을 더하거나 빼면 그 역할의 계약과 커맨드가 함께 깔리거나 정리된다
- pull 은 `harness.toml` 을 쓰지 않는다. `install --preset` 은 설정이 없을 때만 씨앗 설정을 쓴다

## 11. 실행 상태의 preset digest

- #208 이 드라이버 실행 상태 형식에 예약한 선택 필드 `preset`(문자열 또는 `null`)에 값을 쓴다. 값은 실행을 시작할 때의 체인 digest(4-5)이고, 체인이 비면 `null` 이다.
  이 명세는 실행 상태에 필드를 더하지 않는다
- `--resume` 은 지금 체인 digest 가 상태의 값과 다르면 아무 단계도 돌리지 않고 종료 코드 2 로 거부한다. 상태에 `preset` 필드가 없으면 `null` 로 본다

```
error: the preset changed since this run of work 216 started
  --> .harness/preset.lock

help: a run resumes only on the preset it started with — start it again
```

- 실행을 다시 시작하는 방법은 #208 의 정의 digest 불일치와 같다

## 12. `harness doctor` — `preset` 절

doctor 결과 목록에 `preset` 절을 더한다. 자리는 `managed files` 절 바로 뒤다.

| 조건 | state | what | detail |
|---|---|---|---|
| `extends` 도 사본도 lock 도 없다 | `ok` | `no preset — harness.toml extends nothing` | — |
| 대조를 통과한 체인의 preset 마다 | `ok` | `preset <출처>@<태그>` | `depth <d> · <resolved 의 짧은 꼴>` |
| 내용 · 사본 구조 · `preset.toml` · 남은 사본 어긋남(자리마다) | `bad` | `the preset copy does not match the lock` | `.harness/preset/<d>: <5-3 의 사유>` (남은 사본은 `.harness/preset: left over without a lock`) |
| lock 을 읽을 수 없다 | `bad` | `.harness/preset.lock is not a lock this harness reads` | `<사유>` |
| `extends` 가 있고 lock 이 없다 | `bad` | `the preset harness.toml extends is not pulled` | ``run `harness pull` `` |
| `extends` 와 lock 이 다르다(체인 연결 포함) | `bad` | `harness.toml extends a preset the lock does not have` | ``run `harness pull` `` |
| `extends` 가 없는데 lock 이 있다 | `bad` | `a preset copy is left but harness.toml extends nothing` | ``run `harness pull` to remove it`` |
| 요구 버전 미달 | `bad` | `preset <출처>@<태그> needs harness <requires> or later` | ``this project runs <버전> — run `harness install` with a newer harness`` |

- `bad` 항목이 있으면 `ok` 항목을 내지 않는다
- 원격에 묻지 않는다. `--remote` 여도 이 절은 같다

`src/ui/lib/doctor.js`:

- `SECTIONS` 에 `preset: "preset"` 을 더한다
- `explain()` 이 위 `bad` 항목을 한국어로 옮긴다

| what | 항목에 담는 것 | 조치 |
|---|---|---|
| `the preset copy does not match the lock` | 받은 preset 사본(detail 의 깊이)이 lock 과 달라 render · check 가 멈춘다는 것. git 으로 되돌리거나 사본과 lock 을 지우고 다시 받는다는 것 | 없음 — 사람이 고른다 |
| `.harness/preset.lock is not a lock this harness reads` | lock 을 읽지 못해 preset 값을 쓸 수 없다는 것. 병합 충돌이면 한쪽을 고르거나 둘을 지우고 다시 받는다는 것 | 없음 |
| `the preset harness.toml extends is not pulled` | `extends` 가 가리키는 preset 을 아직 받지 않았다는 것 | `cmd`: `harness pull` |
| `harness.toml extends a preset the lock does not have` | `extends` 를 바꾼 뒤 받지 않았다는 것 | `cmd`: `harness pull` |
| `a preset copy is left but harness.toml extends nothing` | `extends` 를 지운 뒤 사본을 걷지 않았다는 것 | `cmd`: `harness pull` |
| `preset … needs harness … or later` | 이 프로젝트의 하네스가 preset 이 요구하는 버전보다 낮다는 것 | `cmd`: `harness install` |

## 13. `harness uninstall`

- `.harness/` 를 걷으므로 preset 사본과 lock 도 걷힌다. `harness.toml` 의 `extends` 는 남는다(`--purge` 가 아니면)
- `--purge` 확인 목록의 `.harness/` 줄 설명은 사본이 있을 때 `vendored copy of the harness and the preset` 이다
- 다시 깔 때는 `harness install --preset <extends 값>` 이 사본과 lock 을 다시 받는다(8-1)

## 14. 문서

### 14-1. `README.md`

| 위치 | 바꾼 뒤의 사실 |
|---|---|
| "명령" 표 | 새 행 `harness pull [--adopt]` — `extends` 가 가리키는 preset 체인을 받아 `.harness/preset/` 에 두고 `.harness/preset.lock` 에 고정한 뒤 렌더. `harness.toml` 을 쓰지 않는다. 받기 · 검증에서 멈추면 아무것도 바뀌지 않는다. `install` 행에 `--preset <참조>` — preset 에서 프로젝트를 시작한다 |
| "파일은 세 부류다" 아래 | 한 문단: `.harness/` 는 하네스 입력의 사본이다 — 고정 사본은 install 이, preset 사본과 lock 은 pull 이 쓴다. 손으로 고치면 `check` 가 커밋을 막는다 |
| "`harness.toml` 이 정하는 것" 표 | 새 행 `extends` — 직접 만드는 파일은 없다. 그 preset 체인의 값과 메모가 모든 생성물에 들어간다. `harness pull` 이 `.harness/preset/` · `.harness/preset.lock` 을 받아 고정한다 |
| 새 절 "preset" | preset 리포 형식(3절), 참조 형식과 SSH 사용자의 `insteadOf`(2-1), 체인과 상한(2-3), 버전을 올리는 순서(`extends` 를 고치고 → `harness pull` → 생긴 diff 를 리뷰 요청으로), 멈춤 조건 다섯(7-4), 사본을 손으로 고치지 않는다는 것, 전체 사본 `harness.toml` 을 줄이는 법(pull 의 덮는 키 보고를 보고 사람이 지운다), CI 는 사본으로 돌아 preset 리포 자격증명이 필요 없다는 것 |
| "업데이트" 절 | 하네스를 올려도 preset 사본과 lock 은 그대로라는 것. preset 을 올리는 것은 pull 이라는 것 |

### 14-2. `src/templates/managed/docs/workflow/changing.md`

| 위치 | 바꾼 뒤의 사실 |
|---|---|
| "설정으로 바꾸는 것" 표 | 새 행: 조직·스택 preset → `extends` → `.harness/preset/` · lock · 모든 생성물. `harness pull` 로 받는다 |
| "고치면 안 되는 것" 표의 `.harness/` 행 | 이유: 하네스 사본과 preset 사본이다. 하네스는 install 로, preset 은 `extends` 를 고치고 `harness pull` 로 받는다 |

### 14-3. `src/templates/generated/.ai/AI_AGENT.md` 10장

하네스 배치 표에 새 행:

| 위치 | 성격 |
|---|---|
| `.harness/` | **사본** — 고정된 하네스(install 이 쓴다)와 preset(`harness pull` 이 쓴다). 손으로 고치지 않는다 |

### 14-4. 씨앗 설정 원형

`extends` 설명 주석을 첫 테이블 앞에 둔다. 값은 두지 않는다.

```toml
# 조직·스택 preset. 이 preset 의 값과 메모를 물려받는다 — `harness pull` 이 받아 .harness/ 에 고정한다.
#   https://<호스트>/<경로>@<태그> 형식의 전체 참조만 받는다
# extends = "https://git.example.com/<조직>/<preset 리포>@<태그>"
```

내장 기본값 파일에는 `extends` 를 두지 않는다.

## 15. 다른 명세의 서술

이 명세가 들어간 뒤 `docs/spec/58-separate-managed-and-project-parts.md` 의 아래 서술은 오른쪽 사실로 읽는다. 분해의 task 하나가 그 명세를 고친다.

| 위치 | 이 명세 이후의 사실 |
|---|---|
| 2-2 | render 가 이전 매니페스트에서 그대로 옮기는 줄은 `.harness/` 아래 가운데 고정 사본(`PINNED_PARTS`) 아래 줄이다 |
| 2-4 | `prune()` 은 `.harness/` 아래 경로를 지우지 않는다. `cmd_install` 은 고정 사본을 갈아 끼울 때 매니페스트 둘과 preset 사본(`.harness/preset/` · `.harness/preset.lock`)을 남긴다 |
| 4-2 | ``the pinned copy under .harness/ comes back with `harness install` `` 줄은 고정 사본 아래 경로가 어긋날 때 낸다 |
| 4-4 | detail 이 고정 사본 아래 경로인 `modified` · `missing` 항목의 조치가 `harness install` 이다 |

## 16. 회귀 테스트

원격은 로컬 bare 리포다. 테스트는 임시 `GIT_CONFIG_GLOBAL` 파일에 `url."file://<임시>/remote/".insteadOf "https://git.example.test/"` 를 두고
`GIT_CONFIG_NOSYSTEM=1` 을 준다. `extends` 는 `https://git.example.test/…` 로 적는다 — 제품 코드에 테스트용 예외가 없고, 연결이 빠지면
`.test` 호스트는 풀리지 않는다.

### 16-1. `render-test.sh` — 새 블록

| 무엇을 | 기대 |
|---|---|
| 참조 형식 | 2-1 의 허용 형식은 통과. 거부 사유 넷이 각각 나온다. 자격증명 사유일 때 심은 비밀 문자열이 표준 출력 · 표준 오류 어디에도 없다 |
| pull 기본 — 깊이 2 체인, 메모가 있는 preset | 사본 · lock 이 4-2 · 4-3 대로이고 lock 바이트가 고정 기대값과 같다. 생성물에 preset 값이 들고, 메모가 깊은 preset · 얕은 preset · 프로젝트 순으로 붙는다. 매니페스트에 `.harness/preset` 경로가 없다. 같은 pull 을 다시 돌리면 `up to date` 이고 어느 파일의 바이트도 바뀌지 않는다 |
| 체인 | 깊이 3 통과, 깊이 4 거부, 같은 출처의 다른 태그로 순환 거부. 거부 때 대상 리포 · 인덱스 바이트가 그대로다 |
| 멤버 | `project/roles/` 의 링크 · 서브모듈 · 규칙 밖 이름 · `project/` 아래 다른 디렉터리 · 디렉터리 자리의 파일(`project` 가 파일) · `preset.toml` 없음 · UTF-8 이 아닌 메모 · `[project]` · `schema = 2` · `[preset]` 의 모르는 키 각각 거부. 거부 안내의 사유와 순번이 3-2 대로이고, 이름에 심은 표지 문자열이 하네스 출력에 없다. 리포 루트의 README 링크와 받는 디렉터리 밖의 다른 디렉터리는 통과 |
| 멈춤 조건 1~5 | 각각 종료 코드 2 · `nothing was changed` · 대상 리포 · 인덱스 · 매니페스트 바이트가 그대로다. 조건 3 은 `--adopt` 로 넘어간다. 조건 5 는 `harness.toml` · 사본 · lock 의 변경을 미정리로 보지 않는다 |
| git 작업 트리 밖 | pull 거부, 아무것도 바뀌지 않는다 |
| 받기 실패 | 없는 태그 · 없는 리포. 원격 경로에 심은 표지 문자열이 하네스 출력에 없다 |
| 태그 이동 | bare 리포에서 태그를 옮긴 뒤 pull — 경고가 나고 lock 의 `resolved` 가 새 커밋이다 |
| `extends` 만 바꾼 상태 | render · `set`(다른 키) 종료 코드 2, `check` · `check --staged` 종료 코드 1, doctor 의 `preset` 절 `bad`, `status` 의 doctor 항목에 같은 것 |
| 사본 손편집 | `check` 1, render 2, pull 은 조건 4. 사본에 받는 디렉터리 밖의 파일을 더하면 `not a preset copy (outside the preset tree)`, 메모를 링크로 바꾸면 `not a preset copy (a symbolic link)` — `check --staged` 도 같다. 사본과 lock 을 지운 뒤 pull 은 통과 |
| `extends` 제거 | pull 이 사본과 lock 을 걷고 생성물이 preset 없는 값이다 |
| `set extends` | 단독이면 render 없이 안내하고 `harness.toml` 만 바뀐다. 다른 키와 함께면 거부. 형식 어긋남이면 `harness.toml` 바이트가 그대로다 |
| install 갱신 | `extends` 가 있는 프로젝트에서 install 뒤 사본 · lock 바이트가 그대로다 |
| `install --preset` | 새 대상 — 씨앗 설정에 `extends` 줄, 사본 · lock · 고정 사본 · 생성물. 같은 `extends` 의 기존 설정(uninstall 뒤) — 다시 받는다. 다른 `extends` — 거부하고 아무것도 바뀌지 않는다. 받기 실패 — 새 대상에 아무것도 생기지 않는다 |
| `install` 이 사본 없는 프로젝트를 만나면 | 거부하고 `install --preset <extends>` 를 안내한다 |
| 갱신 경로별 불변식 | pull · set · 개인 레이어 수정 · install 마다 바뀐 커밋 대상 경로가 10절 표 안이다. 미리 둔 소유 파일 · `docs/spec/` · `docs/plan/` · 결정 기록 · 소스 파일 바이트가 그대로다 |
| `locked` | 프로젝트가 잠긴 키에 다른 값 — pull 조건 2. 같은 값 — 통과. 얕은 preset 이 깊은 preset 의 잠긴 키를 다른 값으로 — 거부 |
| 요구 버전 | `requires` 가 높으면 조건 1. 사본이 있는 프로젝트를 낮은 버전 하네스로 install — 거부 |
| 확장 지점 | preset 의 빈 하위 절차를 프로젝트가 채운 경우와 채우지 않은 경우 모두 render 가 통과한다 |
| 실행 상태 | preset 을 바꾼 뒤 `--resume` 이 거부된다(#208 의 드라이버 테스트 방식) |
| uninstall | `.harness/preset/` · lock 이 걷히고 `--purge` 목록 설명이 13절대로다 |
| 소스 리포 | 고정 사본 없이 pull 이 돈다 |
| 덮는 키 보고 | 기본값 전체를 담은 `harness.toml` 로 pull — note 에 preset 이 바꾼 키가 나오고 값은 나오지 않는다 |
| doctor `preset` 절 | 12절의 조건마다 그 항목 |
| schema 의 preset 레이어 | 깊이 2 체인에서 `layers` 가 `default` · `preset:2` · `preset:1` · `project` · `local` 순이고 preset 항목의 `path` · `ref` 가 6-1 대로다. preset 이 정한 값의 `sources` 가 `preset:<d>` 다 |
| 설정을 읽는 그 밖의 명령 | 사본 손편집 상태에서 `vars` · `metrics` 가 종료 코드 2 와 `nothing was changed` 를 낸다 |

### 16-2. 단위 테스트 — `src/test/unit/`

참조 판정, 멤버 판정(git 목록 · 디렉터리 항목이 없는 목록 · 사본 목록, 사유와 순번, 받지 않은 항목), 내용 해시(고정 입력의 기대값을 4-4 의 셸 계산과 맞춘다), lock 쓰기 바이트와 읽기 판정(스킴 표에 없는 `source`, 스킴과 맞지 않는 `resolved` 거부), `resolved` 의 짧은 꼴, 버전 비교, 체인 digest, preset 레이어 id 와 `layers` 항목.

### 16-3. `doctor.test.js`

12절의 `bad` 항목마다 `explain()` 의 문구와 조치.

### 16-4. `labels.test.js`

`preset:<d>` 가 `layers` 의 같은 id 항목이 있으면 `preset — <ref>`, 없으면 `preset <d>` 로 보인다. `default` · `project` · `local` 의 이름표는 #207 대로다.

회귀 테스트 전체(`script/run-lint-test.sh`)가 통과한다.

## 17. 보호 문서 개정 범위

분해의 task 하나가 이 범위 안에서 고친다.

### 17-1. `.ai/project/scope.md`

| 위치 | 반영할 사실 |
|---|---|
| "할 수 있는 일" | 새 항목: 조직·스택 preset 을 `extends` 로 상속하고, git 태그로 고정한 preset 체인을 받아 리포 안에 둔다(`pull`). preset 에서 프로젝트를 시작한다(`install --preset`) |
| "만들지 않는 것" | 새 항목: preset 리포의 운영 — 만들기 · 권한 · 태그 보호 · 서명. 하네스는 고정 참조로 받고 받은 것을 고정할 뿐이다 |

### 17-2. `.ai/project/architecture.md`

| 위치 | 반영할 사실 |
|---|---|
| "구성 요소" | `src/harness/preset/` — 참조 판정 · 체인 · git 받기 · 트리 멤버 판정 · 사본과 lock · 내용 해시 · 대조. 설정 로더가 preset 레이어를 이것으로 읽는다. 대상 리포의 `.harness/` 는 하네스 입력의 사본 자리다 — 고정 사본(install), preset 사본과 lock(pull · `install --preset`) |
| "데이터 흐름" 새 항목 | preset: `harness pull` → git(`ls-remote` · 얕은 fetch, 리포 밖 임시 위치) → 멤버 판정 · 병합 · 검증 · render 계산 · 경로 사전 판정 → `.harness/preset/` · `.harness/preset.lock` → render. 설정을 읽을 때마다 사본을 lock 과 대조한다 |
| "데이터 흐름" 의 렌더 | 렌더의 입력에 `.harness/preset/` 가 든다. 역할·절차 메모는 preset 의 것(깊은 쪽부터) 뒤에 프로젝트 것이 붙는다 |
| "신뢰 경계" 의 들어오는 입력 | preset 원격의 트리 — 신뢰하지 않는다. 받는 경로만 읽고, 일반 파일 · 디렉터리만, 경로 규칙의 이름만 받으며, 작업 트리를 만들지 않고 객체에서 읽는다. 멤버 판정은 백엔드와 상관없이 함수 하나가 하고, 거부 안내에 받은 이름을 옮기지 않는다(사유와 순번만). git 의 출력은 판정에만 쓰고 옮기지 않는다. 인증은 사용자의 git 설정이 갖는다. `.harness/preset/` 와 lock — 커밋된 파일이라 설정을 읽을 때마다 lock 과 대조한다. 받은 preset 의 설정은 병합되면 프로젝트 설정과 같은 신뢰를 받는다(검증 명령 포함) — 사람은 pull 이 만든 diff 를 리뷰 요청에서 본다 |
| "새 코드를 둘 곳" | 새 preset 백엔드 → `src/harness/preset/` 의 백엔드 하나(받기, `resolved`, lock 의 스킴 행). 멤버 판정 · 내용 해시 · lock 쓰기는 공용이다. preset 이 실어 나를 파일을 더하면 받는 파일 표에 행을 더한다 — 받는 디렉터리와 멤버 판정은 그 표에서 나온다 |
| "계층과 의존 방향" | preset 받기는 forge 어댑터를 거치지 않고 git 을 직접 부른다 |
| "검사하지 않는 것" | 사본과 lock 을 함께 고친 변경은 대조가 잡지 못한다 — 리뷰가 본다. 태그가 원격에서 옮겨졌는지는 pull 때만 본다 |

### 17-3. `.ai/project/glossary.md`

| 위치 | 반영할 사실 |
|---|---|
| 새 행 `preset` | 조직·스택이 공유하는 설정 레이어와 역할·절차 메모. git 리포 하나의 태그로 배포되고 `extends` 로 상속한다 |
| 새 행 `전체 참조` | `https://<호스트>/<경로>@<태그>` — 커밋되는 파일이 preset 을 가리키는 유일한 형식 |
| 새 행 `체인` | `extends` 로 이어진 preset 들. 깊이 1 이 프로젝트가 가리키는 것이고 상한은 3 |
| 새 행 `preset 사본` | `.harness/preset/<깊이>/` — pull 이 받은 preset 의 파일. render 의 입력이다 |
| 새 행 `lock` | `.harness/preset.lock` — 체인의 출처 · 태그 · `resolved` · 내용 해시. 사본의 정본 기록 |
| `하위 절차` · `확장 지점` 행(#208 이 둔다) | 행 끝에 한 문장: preset 은 절차의 한 단계를 확장 지점으로 두고, 프로젝트가 그 절차를 정의해 채운다 |
| "매니페스트" | 끝에 한 문장: preset 사본은 들지 않는다 — 그 해시는 lock 에 있다 |

### 17-4. `.ai/project/testing.md`

| 위치 | 반영할 사실 |
|---|---|
| "외부 의존을 어떻게 다루나" | preset 원격은 로컬 bare 리포다. 임시 `GIT_CONFIG_GLOBAL` 의 `insteadOf` 로 가짜 https 호스트(`.test`)를 그 리포에 잇는다 — 제품 코드에 테스트용 예외를 두지 않는다 |

## 18. 결정 기록

결정 기록: preset 은 고정 참조로 상속한다 — 참조 형식 · lock 형식 · `.harness/` 자리 재정의 (분해에서 작성)

## 19. 한계

- 사본과 lock 을 함께 고친 변경은 대조가 잡지 못한다. 원격과 다시 맞춰 보는 검사는 이 명세에 없다 — 그 사이는 리뷰 요청의 diff 를 사람이 본다
- 태그가 원격에서 옮겨진 것은 다음 pull 에서만 알린다. 고정은 리포 안의 `resolved` 가 한다. 태그 보호는 preset 리포 운영의 몫이다
- 반영 단계 도중의 실패는 되돌리지 않는다 — git 으로 되돌린다(7-5). `install --preset` 이 이미 있던 `.harness/` 에 사본을 깔다 멈추면 깔다 만 사본이 남고, 다음 명령의 대조가 그것을 알린다
- 리포 하나에 preset 하나다. 리포 안의 하위 경로, SSH 참조, 짧은 이름은 받지 않는다
- 받는 크기에 상한을 두지 않는다. 얕은 fetch 라 이력은 받지 않지만 태그 커밋 트리의 객체는 받는다
- 줄바꿈을 바꾸는 git 설정(`core.autocrlf`)으로 체크아웃하면 사본 바이트가 달라져 내용이 어긋난다 — 관리 파일 대조와 같은 한계다
- 전체 사본 `harness.toml` 을 줄이는 쓰기 명령은 없다. pull 이 덮는 키를 알리고 줄이는 것은 사람이 한다
- 두 pull 이 같은 하네스 루트에서 동시에 도는 것을 막지 않는다
