# #216 task

## T1 · feat: preset 참조와 체인 판정 함수

### 상위 Requirement

- relates to #216

### 작업 내용

preset 을 가리키는 참조 문자열을 판정해 출처와 태그로 나누는 함수와, 깊이 순의 참조 목록이 체인 규칙을 지키는지 보는 함수를
새 패키지 `src/harness/preset/` 에 둔다. 원격에 묻지 않고 문자열로만 판정한다.

- 명세 2-1(형식 · 거부 사유와 안내문) · 2-3(체인) · 4-3 의 "참조를 출처와 태그로 나누는 규칙도 스킴이 정한다"
- `src/harness/preset/__init__.py`: 패키지 docstring 만 둔다
- `src/harness/preset/ref.py`
  - 스킴 표: 스킴마다 판정 · 출처와 태그 나누기 · 다시 잇기. 표는 `https://` 한 행이고 다시 이은 형식은 `<출처>@<태그>` 다. 행을 더할 수 있는 한 자리에 둔다
  - 참조 판정: 2-1 의 규칙표를 지키면 (출처, 태그), 아니면 2-1 의 거부 사유 넷 가운데 표의 위에서부터 처음 맞는 것. 출처와 태그는 적힌 문자열 그대로이고 정규화하지 않는다
  - 2-1 의 안내문: 판정한 값을 옮기지 않는다. `-->` 는 그 값을 담은 파일 — 프로젝트면 `harness.toml`, preset 이면 `preset.toml of <출처>@<태그>`. 둘째 help 줄은 사유가 `it carries credentials` 일 때만 낸다. 종료 코드 2
  - 체인 판정: 깊이 순 (출처, 태그) 목록 → 통과 · 깊이 초과 · 순환. 깊이 상한은 상수 `PRESET_DEPTH_LIMIT = 3`. 같은 출처가 두 번 나오면 태그와 상관없이 순환이다
  - 2-3 의 안내문 둘: 깊이 번호와 참조를 한 줄씩 보이고 `nothing was changed` 와 help 를 낸다
- 이 함수를 부르는 곳은 T2(`preset.toml` 의 `extends`) · T5(프로젝트 `extends`) · T9(체인)다
- 단위 테스트 `src/test/unit/test_preset_ref.py`
- 건드릴 파일: `src/harness/preset/__init__.py`(신규), `src/harness/preset/ref.py`(신규), `src/test/unit/test_preset_ref.py`(신규)

### 완료 조건

- [ ] 2-1 의 허용 형식(포트를 붙인 호스트, 여러 경로 성분, `.` · `_` · `-` 가 든 태그)이 통과하고 출처와 태그가 `@` 앞뒤 문자열 그대로 나뉜다
- [ ] `http://` · `ssh://` · `git://` · `file://` · `ext::` · scp 형식 · 로컬 경로 · `-` 로 시작하는 값이 `not an https:// reference` 다
- [ ] `https://` 뒤 첫 `/` 앞에 `@` 가 있는 값이 `it carries credentials`, `@<태그>` 가 없는 값이 `it has no @<tag>` 다
- [ ] 대문자 호스트, `?` · `#` · `%` · 공백, `.` · `..` · 빈 경로 성분, 끝의 `/`, `..` 을 담거나 `.` · `.lock` 으로 끝나는 태그가 `not a full git reference` 다
- [ ] 거부 안내문에 판정한 값이 없고, 둘째 help 줄은 자격증명 사유에서만 나온다
- [ ] 깊이 3 체인은 통과, 깊이 4 체인은 깊이 초과, 같은 출처의 다른 태그가 든 체인은 순환이며 안내문이 2-3 대로다
- [ ] `python3 script/project/check-cli.py imports` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 허용 형식 | `https://git.example.com/acme/harness-preset-python@v2.3.0`, `https://git.example.com:8443/a/b/c@v1_0-rc.1` | (출처, 태그)가 `@` 앞뒤 문자열 그대로 |
| UT-02 | https 아님 | `http://` · `ssh://` · `git://` · `file://` · `ext::` · `git@host:org/repo` · `./p` · `-x` | 사유 `not an https:// reference` |
| UT-03 | 자격증명 | 호스트 앞에 `<사용자>:<표지 문자열>@` userinfo 를 붙인 참조(테스트가 실행 중에 조립한다) | 사유 `it carries credentials`, 안내문에 표지 문자열이 없고 둘째 help 줄이 있다 |
| UT-04 | 태그 없음 | `https://git.example.com/a/b` | 사유 `it has no @<tag>`, 둘째 help 줄이 없다 |
| UT-05 | 형식 어긋남 | 대문자 호스트 · `?x` · `#x` · `%20` · 공백 · `/a//b` · `/a/../b` · 끝 `/` · 태그 `v1..2` · `v1.` · `v1.lock` | 각각 `not a full git reference` |
| UT-06 | 사유 순서 | `http://u@git.example.com/a@v1` | `not an https:// reference` |
| UT-07 | `-->` 줄 | 프로젝트의 값, 깊이 1 preset 의 값 | `--> harness.toml` / `--> preset.toml of <출처>@<태그>` |
| UT-08 | 체인 | 깊이 3 목록, 깊이 4 목록, 같은 출처의 `v1.4.0` · `v1.3.0` 이 든 목록 | 통과 / 깊이 초과 / 순환, 안내문의 번호와 참조가 2-3 대로 |

## T2 · feat: preset 받는 파일 표와 트리 멤버 판정 · preset.toml 판정

### 상위 Requirement

- relates to #216

### 작업 내용

preset 트리에서 무엇을 받고 무엇을 거부하는지 정하는 받는 파일 표와, 백엔드가 만든 (경로, 종류) 목록을 그 표로 판정하는 함수 하나를 둔다.
받은 `preset.toml` 과 메모의 판정, 요구 버전 비교도 여기 둔다. git 받기(T8)와 사본 대조(T4)가 같은 함수를 쓴다.

- 명세 3-1 · 3-2 · 3-3
- `src/harness/preset/tree.py`
  - 받는 파일 표: `preset.toml`(필수) · `project/roles/<이름>.md` · `project/workflows/<이름>.md`, `<이름>` 은 `[a-z][a-z0-9-]{1,30}`. 받는 디렉터리는
    표의 경로에서 계산한다 — 표에 행을 더하면 받는 디렉터리와 판정이 따라온다
  - 트리 멤버 판정 함수: 입력은 (경로, 종류) 목록, 종류는 파일 · 디렉터리 · 심볼릭 링크 · 서브모듈 · 그 밖. 3-2 의 표대로 항목마다 경로를 먼저 보고
    종류를 보며, 처음 어긴 항목에서 멈춰 (사유, 1부터의 순번)을 돌려준다. 통과하면 받을 파일 목록과 받지 않은 항목을 돌려준다. 끝까지 통과했는데
    `preset.toml` 이 파일로 없으면 거부한다. **경로는 돌려주지 않는다**
  - git 모드 → 종류 대응: `100644` · `100755` → 파일, `040000` → 디렉터리, `120000` → 심볼릭 링크, `160000` → 서브모듈, 그 밖
  - `preset.toml` 판정: UTF-8 · TOML, `[preset].schema` 가 정수 1, `[preset].requires` 가 `<정수>.<정수>.<정수>`, `[preset]` 의 다른 키 거부,
    `[project]` 거부, `extends` 는 T1 의 판정. 레이어를 다루는 키(`[preset]` · `extends` · `locked`)를 떼어 레이어 본문과 따로 돌려준다.
    그 밖의 절은 여기서 판정하지 않는다 — 병합 때 #207 의 키별 규칙이 본다
  - 메모의 UTF-8 판정
  - 요구 버전 비교: `harness version` 첫 줄의 값에서 `+` 와 그 뒤를 떼고 세 정수로 읽어 `requires` 와 정수 순서로 비교한다. 읽지 못하면 미달이다
  - 안내문: 3-2 의 git 받기 안내문(사유 · 순번 · 둘째 help 줄의 태그), `error: preset <참조> has no preset.toml at its root`,
    `error: preset <참조> has a file that is not UTF-8 text`, `error: preset <참조> uses preset schema <N> — this harness reads 1`
- 받지 않은 항목은 git 받기(T8)가 버리고 사본 대조(T4)가 사유 `outside the preset tree` 로 거부한다
- 단위 테스트 `src/test/unit/test_preset_tree.py`
- 건드릴 파일: `src/harness/preset/tree.py`(신규), `src/test/unit/test_preset_tree.py`(신규)

### 완료 조건

- [ ] 받는 디렉터리가 `project` · `project/roles` · `project/workflows` 로 계산된다
- [ ] 디렉터리 항목이 든 git 목록과 디렉터리 항목이 없는 목록이 같은 받을 파일을 낸다
- [ ] `project/roles/` 아래의 링크 · 서브모듈 · 규칙 밖 이름, `project/` 아래의 다른 디렉터리, 디렉터리 자리의 파일(`project` 가 파일), `preset.toml` 없음을
      각각 3-2 의 사유와 순번으로 거부하고, 돌려주는 값과 안내문에 그 항목의 경로가 없다
- [ ] 리포 루트의 링크(README 등)와 받는 디렉터리 밖의 다른 디렉터리는 받지 않은 항목으로 돌려주고 통과한다
- [ ] UTF-8 이 아닌 메모 · 비 UTF-8 `preset.toml`, `[project]`, `schema = 2`, `[preset]` 의 모르는 키, 형식이 어긋난 `requires` 를 각각 거부한다
- [ ] 레이어를 다루는 키가 레이어 본문에서 빠지고 `extends` · `locked` 는 따로 돌려준다
- [ ] 요구 버전 비교가 `+` 접미사를 무시하고 정수로 비교하며(`0.10.0` 이 `0.9.9` 보다 높다), 읽지 못하는 버전은 미달이다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 받는 디렉터리 | 받는 파일 표 | `project` · `project/roles` · `project/workflows` |
| UT-02 | 통과하는 git 목록 | `README.md`(링크) · `docs`(디렉터리) · `docs/a.md` · `preset.toml` · `project` · `project/roles` · `project/roles/developer.md` | 받을 파일 `preset.toml` · `project/roles/developer.md`, 받지 않은 항목 `README.md` · `docs` · `docs/a.md` |
| UT-03 | 디렉터리 항목 없는 목록 | UT-02 에서 디렉터리 항목을 뺀 목록 | UT-02 와 같은 받을 파일 |
| UT-04 | 종류 거부 | `project/roles/x.md` 가 링크 · 서브모듈 · 그 밖 | `a symbolic link` · `a submodule` · `not a regular file` 과 그 항목의 순번 |
| UT-05 | 경로 거부 | `project/roles/Bad-MARK.md`, `project/notes-MARK/a.md`, `project/roles/a-MARK.txt` | 각각 `not a preset path`, 결과와 안내문에 `MARK` 가 없다 |
| UT-06 | 디렉터리 자리의 파일 | `project` 가 파일 | `not a directory` |
| UT-07 | `preset.toml` 없음 | 메모만 있는 목록 | 거부 |
| UT-08 | `preset.toml` 판정 | `schema = 2` · `[project]` · `[preset]` 의 `foo = 1` · `requires = "1.2"` · 비 UTF-8 바이트 | 각각 거부와 3-3 문구 |
| UT-09 | 레이어 키 떼기 | `extends` · `locked` · `[preset]` · `[review]` 가 든 `preset.toml` | 레이어 본문은 `[review]` 만, `extends` · `locked` 는 따로 |
| UT-10 | 버전 비교 | 하네스 `0.14.0+abc` 대 `requires = "0.14.0"`, `0.9.9` 대 `0.10.0`, 하네스 `dev` | 충족 · 미달 · 미달 |

## T3 · feat: preset lock 형식과 내용 해시 · 체인 digest

### 상위 Requirement

- relates to #216

### 작업 내용

`.harness/preset.lock` 을 고정 형식으로 쓰고 읽어 판정하는 함수, 사본 하나의 백엔드 중립 내용 해시와 체인 digest 를 계산하는 함수를 둔다.
OCI 백엔드(#218)도 같은 lock 형식 · 내용 해시를 쓴다.

- 명세 4-3 · 4-4 · 4-5
- `src/harness/preset/lock.py`
  - lock 쓰기: 4-3 의 고정 형식 — 주석 한 줄, 빈 줄, `format = 1`, 항목마다 빈 줄 · `[[preset]]` · `source` · `tag` · `resolved` · `content` 순.
    값은 TOML 기본 문자열이고 줄은 LF 로 끝난다. 같은 체인이면 같은 바이트다
  - lock 읽기 판정: TOML 이고, `format` 이 1 이고, 항목이 1~3 개이고, 항목마다 키가 정확히 넷이고, `content` 가 `sha256:` 뒤 소문자 16진 64자이고,
    `source` 의 스킴이 스킴 표에 있고 `source` · `tag` · `resolved` 가 그 행의 형식을 지킨다. 어긋나면 읽을 수 없는 lock 과 5-3 의 사유
    (`not TOML` · `format <N>` · `preset[<번호>] is not an entry`)
  - lock 의 스킴 표: `https://` 행 — `source` 는 T1 의 출처 규칙, `tag` 는 T1 의 태그 규칙, `resolved` 는 소문자 16진 40자 또는 64자. 행을 더할 수 있는 한 자리에 둔다
  - 내용 해시: (상대 경로, 바이트) 목록에서 4-4 의 세 단계 — 경로의 UTF-8 바이트 순, `<sha256 16진>  <경로>\n`, 이은 바이트의 sha256
  - 체인 digest: `content` 값을 깊이 순으로 `<content>\n` 이은 바이트의 sha256 에 `sha256:` 을 붙인다. 체인이 비면 `None`
  - `resolved` 의 짧은 꼴: `sha256:` 접두가 있으면 뗀 뒤의 앞 7자
- 단위 테스트 `src/test/unit/test_preset_lock.py`. 내용 해시의 기대값은 고정 입력 파일을 4-4 의 셸 명령으로 계산한 값을 상수로 둔다
- 건드릴 파일: `src/harness/preset/lock.py`(신규), `src/test/unit/test_preset_lock.py`(신규)

### 완료 조건

- [ ] 깊이 2 체인을 쓴 바이트가 4-3 의 형식(주석 · 빈 줄 · 키 순서 · LF)과 같고, 같은 입력을 두 번 쓰면 바이트가 같다
- [ ] 쓴 lock 을 읽으면 같은 항목이 나온다
- [ ] 깨진 TOML, `format = 2`, 항목 0 개 · 4 개, 키가 다섯인 항목, 형식이 어긋난 `content`, 39자 `resolved` 가 각각 읽을 수 없음과 사유로 나온다
- [ ] 스킴 표에 없는 `source`(`oci://…`)와, `https://` 출처에 `sha256:` 이 붙은 `resolved` 가 읽을 수 없음이다
- [ ] 내용 해시가 4-4 의 셸 계산 기대값과 같고, 경로 정렬이 UTF-8 바이트 순이다
- [ ] 체인 digest 가 4-5 의 정의와 같고 빈 체인은 `None` 이다
- [ ] 짧은 꼴이 40자 커밋 id 와 `sha256:` 값에서 각각 16진의 앞 7자다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 쓰기 바이트 | 깊이 2 항목 | 4-3 형식과 같은 바이트, 두 번 써도 같다 |
| UT-02 | 왕복 | UT-01 의 바이트 | 같은 항목 |
| UT-03 | 읽기 판정 | 깨진 TOML · `format = 2` · 항목 0 개 · 4 개 · 키 다섯 · `content = "md5:…"` · 39자 `resolved` | 읽을 수 없음과 사유 |
| UT-04 | 스킴 | `source = "oci://registry.example/acme/preset"`, `https://` 출처에 `resolved = "sha256:<64자>"` | 읽을 수 없음 |
| UT-05 | 내용 해시 | 고정 파일 셋(`preset.toml` · `project/roles/developer.md` · `project/workflows/work.md`) | 셸 계산 기대값 |
| UT-06 | 정렬 | `project/roles/a-b.md` · `project/roles/a.md` · `preset.toml` | UTF-8 바이트 순의 줄 |
| UT-07 | 체인 digest | `content` 둘, 빈 목록 | 정의대로의 값, `None` |
| UT-08 | 짧은 꼴 | 40자 커밋 id, `sha256:` 뒤 64자 | 각각 앞 7자 |

## T4 · feat: preset 사본과 lock 의 대조 함수

### 상위 Requirement

- relates to #216

### 작업 내용

리포 안의 사본과 lock 을 네트워크 없이 대조하는 함수를 둔다. 설정을 읽는 명령(T5) · `check`(T6) · pull(T10) · install(T11) · doctor(T14)가
이 함수 하나의 결과를 쓴다.

- 명세 4-2 · 5-1 · 5-3 · 5-4, 3-2 의 사본 대조 행
- `src/harness/preset/verify.py`
  - 사본 항목 읽기
    - 디스크: `.harness/preset/<깊이>/` 를 링크를 따라가지 않고 걷는다. 경로는 깊이 디렉터리 기준이고 경로의 UTF-8 바이트 순이다
    - 인덱스: 사본은 `git ls-files -s -z -- .harness/preset/<깊이>` 의 항목과 모드(멤버 판정은 T2 의 git 모드 대응), 파일 바이트는 `git show :<경로>`,
      lock 은 `git show :.harness/preset.lock`. git 을 부르는 자리는 하나로 두어 단위 테스트가 바꿔 끼운다
  - 대조: 입력은 하네스 루트, 프로젝트 레이어의 `extends`(없음 포함), 읽는 곳(디스크 · 인덱스), 하네스 버전. 5-1 의 여덟 항목을 보고
    결과를 "통과 · 어긋남 · 읽을 수 없음" 과 항목마다 자리(깊이 · `.harness/preset` · `.harness/preset.lock`)와 사유로 낸다
    - 사본 구조와 멤버는 T2 의 판정 함수로 본다. 받지 않은 항목은 사유 `outside the preset tree`
    - 통과 · 어긋남이면 깊이마다 레이어 본문 · `locked` · 출처 · 태그 · `ref`(그 스킴의 참조 형식으로 이은 값) · 메모 위치를 함께 돌려준다.
      읽을 수 없으면 레이어가 없다
  - 5-3 의 안내문: 대조 결과마다 첫 줄 · 줄 · help, 경로 열은 `%-52s`. 설정을 읽는 명령이 쓰는 변형은 줄 목록 뒤 · help 앞에 `nothing was changed` 를 넣는다.
    사본 안 항목의 경로와 파일 내용을 옮기지 않고, 참조 문자열은 2-1 을 통과한 것만 낸다
- 단위 테스트 `src/test/unit/test_preset_verify.py`
- 건드릴 파일: `src/harness/preset/verify.py`(신규), `src/test/unit/test_preset_verify.py`(신규)

### 완료 조건

- [ ] `extends` · 사본 · lock 이 모두 없으면 통과이고 레이어가 없다
- [ ] 5-1 의 여덟 항목이 각각 어긋날 때 표의 분류(읽을 수 없음 · 어긋남)와 자리 · 사유가 나온다
- [ ] 사본에 받는 디렉터리 밖의 파일을 더하면 `not a preset copy (outside the preset tree)`, 메모를 링크로 바꾸면 `not a preset copy (a symbolic link)` 이고, 링크를 따라가지 않는다
- [ ] lock 없이 `.harness/preset/` 만 있으면 `left over without a lock` 이다
- [ ] 인덱스에서 읽은 대조가 같은 내용의 디스크 대조와 같은 결과를 내고, 프로젝트 참조는 넘겨받은 `extends` 로 본다
- [ ] 어긋남이면 사본대로 만든 깊이별 레이어가 나오고, 읽을 수 없으면 레이어가 없다
- [ ] 안내문이 5-3 의 첫 줄 · 줄 · help 와 같고, 사본 항목의 경로와 파일 내용이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 빈 체인 | `extends` · 사본 · lock 없음 | 통과, 레이어 없음 |
| UT-02 | 통과 | 깊이 2 사본과 맞는 lock, 맞는 `extends` | 통과, 깊이 2 · 1 레이어와 `ref` |
| UT-03 | 내용 | 사본 파일 한 바이트 변경 | 어긋남, `.harness/preset/<d>` 와 `content differs from the lock` |
| UT-04 | 사본 구조 | 깊이 디렉터리 하나 없음, 남는 디렉터리 `3` | 읽을 수 없음, `missing` · 구조 사유 |
| UT-05 | 멤버 | 받는 디렉터리 밖의 파일, 링크로 바꾼 메모 | `outside the preset tree` · `a symbolic link` |
| UT-06 | lock | 깨진 TOML, `format = 2` | 읽을 수 없음, `not TOML` · `format 2` |
| UT-07 | 체인 연결 · 프로젝트 참조 | 깊이 1 의 `extends` 가 lock 의 깊이 2 와 다름, `harness.toml` 의 태그만 다름 | 어긋남 |
| UT-08 | 남은 사본 | lock 없이 사본 | 어긋남, `left over without a lock` |
| UT-09 | 요구 버전 | `requires` 가 하네스 버전보다 높음 | 어긋남, `needs <requires> — this harness is <버전>` |
| UT-10 | 인덱스 | git 호출을 바꿔 끼운 인덱스 항목 · 바이트 | UT-02 · UT-03 · UT-05 와 같은 결과 |
| UT-11 | 안내문 | UT-03 · UT-06 · UT-07 · UT-09 의 결과 | 5-3 의 첫 줄 · `%-52s` 줄 · help, 설정을 읽는 명령 변형의 `nothing was changed` 자리 |

## T5 · feat: 설정 로더의 preset 레이어와 설정을 읽는 명령의 대조 멈춤

### 상위 Requirement

- relates to #216

### 작업 내용

설정을 읽을 때 T4 의 대조를 먼저 돌고, 그 결과로 #207 레이어 로더의 preset 자리를 채운다. 대조가 실패하면 설정을 읽는 명령이 명세 5-2 대로
멈추거나 계속한다. `harness schema` 가 preset 레이어를 보인다.

- 명세 2-2 · 5-2(`check` · `install` · `pull` · `set extends` 를 뺀 행) · 5-3 의 "그 밖에 설정을 읽는 명령" · 6-1(UI 를 뺀 것) · 6-3
- `src/harness/config/`(#207 의 레이어 로더)
  - 프로젝트 레이어의 `extends` 를 T1 로 판정하고 병합 전에 뗀다. 실효 설정과 템플릿 변수(`derive()`)에 들지 않는다. 판정에 실패하면 2-1 안내문과 종료 코드 2
  - 개인 레이어의 `extends` 는 #207 의 개인 허용 키 검사가 거부한다. 이 task 는 그것을 회귀 테스트로 확인만 한다
  - 병합 전에 T4 의 대조(디스크)를 돈다. 통과 · 어긋남이면 깊은 쪽부터 preset 자리에 레이어를 넣는다. 레이어 id 는 `preset:<깊이>` 다.
    깊이 d 의 `locked` 는 #207 의 잠금 판정으로 위 레이어에 걸리고, 거부 안내의 잠근 레이어는 그 레이어의 `ref` 로 보인다
  - render · check 는 #207 대로 개인 레이어 없이 병합한다
- 명령별 동작 — 설정을 읽어 명령에 넘기는 곳(#206 의 `main()`)과 각 명령 모듈
  - 그 밖에 설정을 읽는 명령 — 공유 설정이나 실효 설정(`run_plan()` 포함)을 읽는 명령 전부: 어긋남 · 읽을 수 없음 모두 그 명령이 설정을 읽지
    못했을 때처럼 끝난다. 5-3 의 첫 줄 · 줄 · `nothing was changed` · help 를 내고 아무것도 바꾸지 않는다. 지금 명령으로는 `render` · `set` · `steps` ·
    `checks` · `write-doc` · `run` · `run-plan` · `fix` · `vars` · `metrics` · `forge-setup` 이고 종료 코드 2 다. 이식으로 생긴 명령은 그 명세의 설정 오류 코드를 따른다
  - `doctor` · `status` · `schema`: 멈추지 않는다. 어긋남이면 사본대로 만든 레이어로, 읽을 수 없으면 preset 레이어 없이 계속한다. 그렇게 만든 설정이
    #207 의 검증에 걸리면 지금처럼 설정 오류로 2. doctor 의 `preset` 절 항목은 T14 가 더한다
  - 설정을 읽지 않는 명령(`bash-guard` · `secret-scan` · `clone-key` 등)은 대조하지 않는다
  - `check` 는 T6, `install` 은 T11, `pull` 은 T9, `set extends` 는 T13 이 자기 규칙을 더한다
- `src/harness/commands/schema.py`: `layers` 에 preset 항목 `{"id": "preset:<d>", "path": ".harness/preset/<d>/preset.toml", "ref": "<참조>"}` 를 `default` 와
  `project` 사이에 깊은 쪽부터 넣는다. `sources` · `checks[].source` 는 preset 에서 온 값을 `preset:<d>` 로 적는다. preset 레이어를 만들지 못하면 preset 항목이 없다
- 확장 지점(6-3)에는 판정을 더하지 않는다. preset 레이어가 #208 의 workflow 블록과 빈 하위 절차를 실어 나르는 것을 회귀 테스트로 확인한다
- `render-test.sh` 새 블록 "preset 레이어"
  - 사본과 lock 을 손으로 만드는 도우미: 사본 파일을 쓰고 4-4 의 셸 계산으로 내용 해시를 구해 4-3 형식의 lock 을 쓴다
  - 케이스: 명세 16-1 의 "참조 형식", "`extends` 만 바꾼 상태" 의 render · `set`, "사본 손편집" 의 render, "schema 의 preset 레이어", "`locked`" 의 얕은 preset · 프로젝트, "확장 지점", "설정을 읽는 그 밖의 명령"
- 단위 테스트 `src/test/unit/test_config_preset.py`: preset 레이어 id 와 `layers` 항목, 레이어 병합 순서
- 건드릴 파일: `src/harness/config/` 의 레이어 로더 · 검증, 설정을 읽어 명령에 넘기는 `src/harness/cli.py`, `src/harness/commands/schema.py`, `src/test/render-test.sh`, `src/test/unit/test_config_preset.py`(신규)

### 완료 조건

- [ ] `extends` 가 없는 프로젝트의 생성 파일 · 매니페스트 · schema 출력이 이 task 전과 바이트 단위로 같고, 기존 회귀 테스트가 기대값을 고치지 않고 통과한다
- [ ] `harness.toml` 의 `extends` 가 2-1 을 어기면 render 가 2-1 안내문과 종료 코드 2 로 멈추고, 자격증명 사유일 때 심은 비밀 문자열이 표준 출력 · 표준 오류에 없다
- [ ] `harness.local.toml` 의 `extends` 를 #207 의 개인 레이어 오류로 거부한다
- [ ] `extends` 가 실효 설정과 `harness vars` 출력에 없다
- [ ] 손으로 만든 깊이 2 사본에서 preset 값이 생성물에 들고, 병합 순서가 내장 기본값 ← 깊이 2 ← 깊이 1 ← 프로젝트다
- [ ] schema 의 `layers` 가 `default` · `preset:2` · `preset:1` · `project` · `local` 순이고 preset 항목의 `path` · `ref` 가 6-1 대로이며, preset 이 정한 값의 `sources` 가 `preset:<d>` 다
- [ ] 얕은 preset 이 깊은 preset 의 잠긴 키를 다른 값으로 적으면 render 가 #207 의 잠금 오류로 거부하고 잠근 레이어를 참조로 보인다. 프로젝트가 잠긴 키에 같은 값을 적으면 통과, 다른 값이면 거부한다
- [ ] preset 이 `work` 의 한 단계를 workflow 블록으로 두고 그 하위 절차를 빈 절차로 정의한 사본에서, 프로젝트가 그 하위 절차를 채운 경우와 채우지 않은 경우 모두 render 가 통과한다
- [ ] `extends` 만 바꾼 상태에서 render · `set`(다른 키)이 종료 코드 2 와 5-3 의 프로젝트 참조 줄 · `nothing was changed` 를 내고 어느 파일도 바뀌지 않는다
- [ ] 사본을 손으로 고친 상태에서 render · `vars` · `metrics` 가 종료 코드 2 와 `nothing was changed` 를 낸다
- [ ] 같은 상태에서 `doctor` · `status` · `schema` 는 설정 오류로 멈추지 않고 끝까지 돌며, lock 을 깨뜨리면 schema 의 `layers` 에 preset 항목이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | `extends` 없음 | 이 task 전에 설치한 리포 | 생성물 · 매니페스트 · schema 바이트가 같다 |
| UT-02 | 참조 형식 | `extends` 에 2-1 의 거부 사유 넷 각각 | render 2, 그 사유 |
| UT-03 | 자격증명 값 | 호스트 앞에 `<사용자>:<표지 문자열>@` userinfo 를 붙인 `extends`(테스트가 실행 중에 조립한다) | 표준 출력 · 표준 오류에 표지 문자열 없음 |
| UT-04 | 개인 레이어 | `harness.local.toml` 에 `extends` | #207 의 개인 레이어 오류 |
| UT-05 | 레이어 병합 | 손으로 만든 깊이 2 사본(두 깊이가 `review.max_rounds` 를 다르게 적음) | 생성물에 깊이 1 값, 프로젝트가 적으면 프로젝트 값 |
| UT-06 | schema | UT-05 | `layers` 순서와 `path` · `ref`, `sources["review.max_rounds"] == "preset:1"` |
| UT-07 | 잠금 | 깊이 2 `locked = ["review.max_rounds"]`, 깊이 1 이 다른 값 / 프로젝트가 같은 값 · 다른 값 | 거부 / 통과 · 거부 |
| UT-08 | 확장 지점 | 빈 하위 절차를 둔 preset, 프로젝트가 채움 · 채우지 않음 | 두 경우 render 0 |
| UT-09 | `extends` 만 바꿈 | lock 과 다른 태그의 `extends` | render · `set review.max_rounds 6` 이 2, 파일 바이트 그대로 |
| UT-10 | 사본 손편집 | 사본 메모 한 줄 변경 | render · `vars` · `metrics` 2, `nothing was changed` |
| UT-11 | 계속하는 명령 | UT-10, 깨진 lock | doctor · status · schema 가 끝까지 돈다, 깨진 lock 이면 `layers` 에 preset 항목 없음 |
| UT-12 | 레이어 id (단위) | 깊이 2 레이어 목록 | `preset:2` · `preset:1` 과 `layers` 항목 |

## T6 · feat: check 의 preset 사본 대조와 check --staged 의 인덱스 대조

### 상위 Requirement

- relates to #216

### 작업 내용

`check` 가 T4 의 대조 결과를 다른 검사와 함께 보고하고, `check --staged` 가 사본과 lock 을 인덱스에서 읽어 대조한다. 사본을 손으로 고친 커밋과
`extends` 만 바꾼 커밋이 pre-commit 에서 막힌다.

- 명세 5-2 의 `check` 행 · 5-3 · 5-4
- `src/harness/drift.py`(`check_target`) · `src/harness/commands/check.py`
  - 어긋남: 5-3 의 안내문을 표준 오류에 내고 종료 코드 1. 생성 파일 대조(사본대로 만든 레이어로) · 관리 파일 대조 · 매니페스트 검증도 한다
  - 읽을 수 없음: 보고하고 종료 코드 1. 생성 파일 대조는 하지 않고 관리 파일 대조와 매니페스트 검증은 한다
  - `--staged`: lock 과 사본을 인덱스에서 읽고(T4), 프로젝트 참조는 작업 트리의 `harness.toml` 로 본다 — `check --staged` 가 설정을 작업 트리에서 읽는 것과 같다
- `render-test.sh` 의 "preset 레이어" 블록에 명세 16-1 의 "사본 손편집" · "`extends` 만 바꾼 상태" 의 `check` · `check --staged` 케이스를 더한다
- 건드릴 파일: `src/harness/drift.py`, `src/harness/commands/check.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 대조를 통과하는 사본이면 `check` 가 0 이다
- [ ] 사본 손편집 상태에서 `check` 가 종료 코드 1 이고 표준 오류가 5-3 의 첫 표대로다
- [ ] 사본에 받는 디렉터리 밖의 파일을 더하면 `not a preset copy (outside the preset tree)`, 메모를 링크로 바꾸면 `not a preset copy (a symbolic link)` 이고, 같은 변경을 스테이지하면 `check --staged` 도 같은 줄을 낸다
- [ ] lock 을 깨뜨리면 `check` 가 1 이고 생성 파일 대조 줄이 없으며 관리 파일 대조와 매니페스트 검증은 돈다
- [ ] `extends` 만 바꾼 상태에서 `check` · `check --staged` 가 1 이다
- [ ] 사본을 고친 변경과 `extends` 만 바꾼 변경을 커밋하려 하면 pre-commit 이 막는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 통과 | 손으로 만든 맞는 사본과 lock | `check` 0 |
| UT-02 | 내용 어긋남 | 사본 메모 한 줄 변경 | `check` 1, `the preset copy does not match .harness/preset.lock` 과 `content differs from the lock` |
| UT-03 | 밖의 파일 · 링크 | 사본에 `extra.txt` 추가, 메모를 링크로 | `not a preset copy (outside the preset tree)` · `not a preset copy (a symbolic link)` |
| UT-04 | 인덱스 | UT-03 의 변경을 `git add` | `check --staged` 1, 같은 줄 |
| UT-05 | 읽을 수 없는 lock | lock 에 깨진 TOML | `check` 1, 생성 파일 대조 줄 없음, 관리 파일 대조는 돈다 |
| UT-06 | `extends` 만 바꿈 | lock 과 다른 태그 | `check` · `check --staged` 1, `harness.toml extends a preset the lock does not have` |
| UT-07 | pre-commit | UT-02 · UT-06 의 변경을 커밋 | 커밋이 막힌다 |

## T7 · feat: preset 메모를 프로젝트 메모 앞에 렌더

### 상위 Requirement

- relates to #216

### 작업 내용

역할 어댑터와 절차 문서 끝에 preset 의 메모를 깊은 쪽부터 붙이고, 프로젝트 메모를 마지막에 붙인다. 뒤의 지시가 더 구체적이다.

- 명세 6-2
- `src/harness/render/agents.py`(`role_notes` · `agent_files`, Claude · Codex 두 형식) · `src/harness/render/workflows.py`(`workflow_doc`)
  - 역할 `<r>` 의 에이전트 정의와 절차 `<w>` 의 절차 문서 끝에: 깊이 N, …, 1 의 `project/roles/<r>.md`(절차는 `project/workflows/<w>.md`) 가운데 있는 것마다
    `## preset 에서 — <출처>` 절, 그다음 지금과 같은 `## 이 프로젝트에서` 절
  - 절 제목의 `<출처>` 는 lock 의 `source` 다. 태그를 넣지 않는다
  - 머리 안내 주석을 떼고 앞뒤 공백을 걷은 본문이 비면 절을 넣지 않는다 — 프로젝트 메모와 같은 규칙이다
  - 설정에 없는 역할 · 절차의 메모는 쓰이지 않는다
  - preset 트리를 읽는 위치를 인자 하나로 받는다. 기본은 사본(`.harness/preset/<깊이>/`)이고, pull 의 render 계산(T9)은 새 체인을 받은 임시 위치를 넘긴다
- `write-doc` 은 바꾸지 않는다 — 프로젝트 메모만 쓴다
- `render-test.sh` 의 "preset 레이어" 블록에 케이스를 더한다
- 건드릴 파일: `src/harness/render/agents.py`, `src/harness/render/workflows.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 손으로 만든 깊이 2 사본의 두 깊이와 프로젝트에 같은 역할 메모가 있으면 Claude · Codex 어댑터 끝의 절 순서가 깊이 2 · 깊이 1 · 프로젝트이고, 절차 메모도 절차 문서에서 같은 순서다
- [ ] 절 제목이 `## preset 에서 — <lock 의 source>` 이고 태그가 없다
- [ ] lock · 사본 · `extends` 의 태그만 바꾸고 메모가 같으면 render 뒤 생성 파일이 바이트 단위로 같다
- [ ] 안내 주석만 있는 preset 메모는 절을 만들지 않는다
- [ ] 설정에 없는 역할의 preset 메모가 어느 생성 파일에도 들지 않는다
- [ ] `write-doc` 이 preset 메모를 쓰지 않고 `.harness/preset/` 아래가 바뀌지 않는다
- [ ] preset 이 없는 프로젝트의 어댑터 · 절차 문서가 이 task 전과 같다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 역할 메모 순서 | 깊이 2 · 깊이 1 · 프로젝트의 `developer` 메모 | `.claude/agents/developer.md` · `.codex/agents/developer.toml` 끝의 절이 깊이 2 · 깊이 1 · 프로젝트 순 |
| UT-02 | 절차 메모 순서 | 깊이 1 · 프로젝트의 `work` 메모 | `.ai/workflows/work.md` 끝의 절이 깊이 1 · 프로젝트 순 |
| UT-03 | 절 제목 | UT-01 | `## preset 에서 — https://git.example.test/…`, 태그 없음 |
| UT-04 | 태그만 바꿈 | 같은 메모, 다른 태그로 다시 만든 사본 · lock · `extends` | 생성 파일 바이트가 같다 |
| UT-05 | 빈 메모 | 안내 주석만 있는 preset 메모 | 절 없음 |
| UT-06 | 설정에 없는 역할 | 설정에 없는 역할 이름의 preset 메모 | 어느 생성 파일에도 없음 |
| UT-07 | `write-doc` | `write-doc roles/developer` | 프로젝트 메모만 바뀌고 `.harness/preset/` 바이트가 같다 |

## T8 · feat: preset git 받기 백엔드

### 상위 Requirement

- relates to #216

### 작업 내용

git 태그로 고정한 preset 하나를 받아 받을 파일의 바이트와 `resolved` 를 돌려주는 백엔드를 둔다. 작업 트리를 만들지 않고 객체에서 읽으며,
git 의 출력은 판정에만 쓴다.

- 명세 7-3, 3-2 의 git 받기 행
- `src/harness/preset/git.py`
  - preset 하나 받기: (출처, 태그, 지금 lock 의 같은 출처 · 태그 항목) → `resolved` · 받을 파일의 바이트 · `preset.toml` 판정 결과(레이어 본문 · `locked` · 부모 `extends`) · 내용 해시 · 태그 이동 여부
    1. `git ls-remote <출처> refs/tags/<태그> refs/tags/<태그>^{}` — `^{}` 줄이 있으면 그 id, 없으면 태그 줄의 id. 둘 다 없으면 그 태그가 없다
    2. 하네스 루트 밖의 `tempfile.mkdtemp()` 에 `git init -q` 하고 `git fetch -q --depth 1 --no-tags <출처> refs/tags/<태그>`
    3. `git rev-parse FETCH_HEAD^{commit}` 이 1 의 id 와 다르면 받는 사이에 태그가 옮겨진 것으로 보고 멈춘다
    4. `git ls-tree -r -t -z --full-tree <resolved>` 의 항목을 그 순서대로 T2 의 멤버 판정에 넘긴다. 받지 않은 항목은 버린다
    5. 받을 파일의 바이트를 `git cat-file blob` 으로 읽는다. 작업 트리를 만들지 않는다
    6. `preset.toml` · 메모를 T2 로 판정하고 내용 해시(T3)를 객체 바이트로 계산한다
  - 원격에 닿는 호출(1 · 2)은 `remote_call()` 방식이다 — 표준 입력을 닫고, 제어 터미널 없이(새 세션) 띄우고, `GIT_TERMINAL_PROMPT=0` 을 준다.
    #206 의 `readiness/remote.py` 의 환경 · 기다리기 도우미를 쓰고, 제한 시간은 호출 하나에 상수 `PRESET_FETCH_TIMEOUT = 120` 초다
  - 출처는 인자 하나로 넘긴다. forge 어댑터를 거치지 않고 git 을 직접 부른다. 인증은 사용자의 git 설정이 갖고 하네스는 묻지도 저장하지도 않는다
  - git 의 출력은 판정에만 쓰고 결과 · 안내문에 옮기지 않는다
  - 임시 디렉터리는 성공 · 실패와 상관없이 지운다
  - 받기 실패 안내(7-3 의 표와 안내문): `git exited <코드>` · `timed out after 120s` · `git could not be started` · 태그 없음 · 받는 사이 태그 이동. help 의 `git ls-remote` 명령 줄
  - 태그 이동 경고(7-6): 지금 lock 의 같은 출처 · 태그 항목과 `resolved` 가 다르면 경고 문구를 돌려준다. 새 커밋으로 고정한다
- 단위 테스트 `src/test/unit/test_preset_git.py`: git 을 부르는 함수를 바꿔 끼운다
- 건드릴 파일: `src/harness/preset/git.py`(신규), `src/test/unit/test_preset_git.py`(신규)

### 완료 조건

- [ ] 주석 태그는 `^{}` 줄의 커밋 id, 가벼운 태그는 태그 줄의 id 가 `resolved` 다
- [ ] 태그가 없으면 `error: <출처> has no tag <태그>`, 받는 사이 id 가 바뀌면 `moved while fetching` 과 help `pull again` 이다
- [ ] git 이 0 이 아닌 코드로 끝남 · 제한 시간 초과 · 띄우지 못함이 각각 7-3 의 괄호 문구다
- [ ] git 의 표준 출력 · 표준 오류에 든 문자열이 결과와 안내문에 없다
- [ ] 받는 디렉터리 밖의 항목은 `cat-file` 로 읽지 않고, 받을 파일만 바이트로 돌려준다
- [ ] 원격 호출이 표준 입력을 닫고 새 세션으로 `GIT_TERMINAL_PROMPT=0` 을 주어 띄워지며 제한 시간이 120초다
- [ ] 임시 디렉터리가 하네스 루트 밖에 생기고 성공 · 실패 모두 남지 않는다
- [ ] 지금 lock 의 같은 출처 · 태그 항목과 `resolved` 가 다르면 7-6 의 경고 문구가 나온다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 주석 태그 | ls-remote 출력에 태그 줄과 `^{}` 줄 | `resolved` 가 `^{}` 의 id |
| UT-02 | 가벼운 태그 | 태그 줄만 | 그 id |
| UT-03 | 태그 없음 | 빈 출력 | `has no tag` 안내 |
| UT-04 | 받는 사이 이동 | rev-parse 가 다른 id | `moved while fetching`, help `pull again` |
| UT-05 | 실패 | ls-remote 종료 코드 128 · 시간 초과 · `OSError` | `git exited 128` · `timed out after 120s` · `git could not be started` |
| UT-06 | 출력 옮기지 않음 | git 표준 오류에 `LEAK-MARK` | 안내문에 `LEAK-MARK` 없음 |
| UT-07 | 받을 파일 | ls-tree 에 README 링크 · 메모 · `preset.toml` | `cat-file` 이 메모와 `preset.toml` 에만 불림 |
| UT-08 | 임시 위치 | 성공 · 받기 실패 | 임시 디렉터리가 하네스 루트 밖이고 남지 않음 |
| UT-09 | 호출 환경 | 띄운 원격 호출 | 표준 입력 닫힘 · 새 세션 · `GIT_TERMINAL_PROMPT=0` · 제한 120 |
| UT-10 | 태그 이동 경고 | 지금 lock 항목의 `resolved` 가 다름 | 7-6 의 경고 문구, 새 `resolved` |

## T9 · feat: harness pull 의 준비 · 반영과 출력

### 상위 Requirement

- relates to #216

### 작업 내용

`extends` 가 가리키는 preset 체인을 받아 `.harness/preset/` 와 lock 에 고정한 뒤 다시 렌더하는 명령 `harness pull` 을 더한다. 준비 단계는
대상 리포를 바꾸지 않고, 반영 단계는 파일마다 `guarded_path()` 로 쓴다. 준비 · 반영은 `install --preset`(T12)도 쓰도록 공용 모듈에 둔다.

- 명세 7-1 · 7-2 · 7-5 · 7-6(덮는 키 보고를 뺀 것) · 7-4 의 멈춤 조건 3 · 4-2 · 2-3 의 체인 판정
- `src/harness/preset/store.py`
  - `PRESET_PARTS = (".harness/preset", ".harness/preset.lock")`
  - 사본 쓰기: 새 체인의 파일을 내용이 다를 때만 쓰고, 새 체인에 없는 파일과 비게 된 디렉터리를 지우며, 체인이 비면 `.harness/preset/` 를 걷는다. 실행 비트는 버린다
  - lock 쓰기(바이트가 다를 때만) · 지우기(체인이 비면)
  - 쓰기와 지우기는 모두 `guarded_path()` 를 거친다
- `src/harness/preset/sync.py`
  - 준비(7-2 의 1 · 3 · 5 ~ 8): 하네스 루트가 git 작업 트리 안인지(`git rev-parse --show-toplevel`), `harness.toml` 의 `extends` 를 T1 로 판정, 받기 — 참조의
    스킴으로 백엔드를 골라(스킴 표는 `https://` → T8 한 행) 깊이 1 부터 부모 `extends` 를 따라간다, 체인 판정(T1), 병합 검증(내장 기본값 ← 새 체인 ← 프로젝트,
    #207 의 검증 · `validate()` · 절차 검증), render 결과 계산(새 체인을 임시 위치에서 읽는다 — T7 의 인자), 매니페스트 검증과 경로 사전 판정(render 가 바꿀
    경로 전부 · `.harness/preset/` 아래 쓰고 지울 경로 · `.harness/preset.lock`), 멈춤 조건 3(명세 58 3-3 의 안내문, 명령 `harness pull`, `--adopt` 안내 `harness pull --adopt`)
  - 7-2 의 2(멈춤 조건 5)와 4(멈춤 조건 4)의 자리는 T10 이 채운다
  - 반영(9 ~ 11): 사본 → lock → render(`render_target`). 도중에 멈추면 원인의 안내문을 그대로 내고, 반영 단계에서 파일을 하나라도 바꿨으면 7-5 의 안내를 더해
    종료 코드 2. 하나도 바꾸지 않았으면 원인과 `nothing was changed` 만 낸다
  - 받기에 쓴 임시 위치는 성공 · 실패와 상관없이 지운다
- `src/harness/commands/pull.py` 의 `cmd_pull`
  - `main()` 의 설정 읽기를 거치지 않는다. 프로젝트 레이어를 직접 읽고, 병합은 새로 받은 사본으로 한다
  - `harness.toml` 과 `harness.local.toml` 을 쓰지 않는다
  - 출력(7-6): preset 마다 `pull: <출처>@<태그> -> <resolved 의 짧은 꼴> (depth <d>)`, lock 이 바뀌었으면 `pull: .harness/preset.lock updated · <N> vendored file(s) (<W> written, <R> removed)`,
    그대로면 `pull: the preset is up to date`, `extends` 가 없을 때의 두 줄, 이어서 render 의 출력. 태그가 옮겨졌으면 그 preset 줄 앞에 표준 오류로 T8 의 경고
  - 준비 단계에서 멈추면 종료 코드 2 와, 줄 목록 뒤 · help 앞에 `nothing was changed`. `harness.toml` 이 없으면 `error: no config found` 안내, git 작업 트리 밖이면 7-4 의 안내
- `src/harness/commands/__init__.py`: `COMMANDS` 에 `pull` — 사용법 `[--target DIR] [--adopt]`, 설명 `fetch the presets harness.toml extends, lock them under .harness/ and re-render`.
  `--adopt` 도움말을 `install, render, set, steps, checks, pull: take over files the harness would write, keeping each as <path>.orig` 로
- `src/harness/cli.py`: `DELEGATES` 에 `pull` — 고정 사본이 있으면 그 버전이 받는다
- `render-test.sh` 새 블록 "harness pull"
  - 로컬 bare 원격, 임시 `GIT_CONFIG_GLOBAL` 의 `insteadOf` 와 `GIT_CONFIG_NOSYSTEM=1`, preset 리포를 만들어 태그를 다는 도우미
  - 케이스: 명세 16-1 의 "pull 기본", "체인", "멤버", "git 작업 트리 밖", "받기 실패", "태그 이동", "`extends` 제거", "소스 리포", 멈춤 조건 3
- 건드릴 파일: `src/harness/preset/store.py`(신규), `src/harness/preset/sync.py`(신규), `src/harness/commands/pull.py`(신규), `src/harness/commands/__init__.py`, `src/harness/cli.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 깊이 2 체인(메모가 있는 preset)을 pull 하면 사본이 4-2 대로이고, lock 바이트가 테스트가 구한 커밋 id 와 4-4 셸 계산의 내용 해시로 짠 4-3 형식의 기대 바이트와 같다
- [ ] 생성물에 preset 값이 들고, 메모가 깊은 preset · 얕은 preset · 프로젝트 순으로 붙으며, 매니페스트에 `.harness/preset` 경로가 없다
- [ ] 같은 pull 을 다시 돌리면 `pull: the preset is up to date` 이고 어느 파일의 바이트도 바뀌지 않는다
- [ ] 깊이 3 체인은 통과하고, 깊이 4 와 같은 출처의 다른 태그(순환)는 거부되며, 거부 때 대상 리포 · 인덱스 바이트가 그대로다
- [ ] 명세 16-1 "멤버" 행의 거부 케이스가 각각 3-2 의 사유와 순번을 내고 이름에 심은 표지 문자열이 하네스 출력에 없으며, 리포 루트의 README 링크와 받는 디렉터리 밖의 디렉터리는 통과한다
- [ ] 하네스 루트가 git 작업 트리 밖이면 pull 이 거부하고 아무것도 바뀌지 않는다
- [ ] 없는 태그와 없는 리포에서 받기 실패 안내가 나오고, 원격 경로에 심은 표지 문자열이 하네스 출력에 없다
- [ ] bare 리포에서 태그를 옮긴 뒤 pull 하면 경고가 나고 lock 의 `resolved` 가 새 커밋이다
- [ ] `extends` 를 지운 뒤 pull 하면 사본과 lock 이 걷히고 생성물이 preset 없는 값이다
- [ ] 소스 리포에서 고정 사본 없이 pull 이 돈다
- [ ] 새 생성 경로에 사용자 파일이 있으면 멈춤 조건 3 으로 2 이고, `--adopt` 면 넘겨받고 통과한다
- [ ] pull 앞뒤로 `harness.toml` 바이트가 같다
- [ ] 받기에 쓴 임시 디렉터리가 남지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | pull 기본 | 깊이 2 체인, 두 preset 에 메모 | 사본 · lock 바이트 · 생성물 · 메모 순서 · 매니페스트가 기대대로, 출력이 7-6 대로 |
| UT-02 | 다시 pull | UT-01 직후 | `up to date`, 모든 파일 바이트 그대로 |
| UT-03 | 체인 | 깊이 3, 깊이 4, 순환 | 통과 / 거부 / 거부, 거부 때 리포 · 인덱스 그대로 |
| UT-04 | 멤버 | 16-1 "멤버" 행의 preset 리포 각각 | 사유 · 순번, 표지 문자열 없음, 통과 케이스 둘 |
| UT-05 | git 밖 | git 작업 트리가 아닌 하네스 루트 | 2, `pull needs the harness root inside a git work tree`, 아무것도 바뀌지 않음 |
| UT-06 | 받기 실패 | 없는 태그, 표지 문자열을 심은 없는 리포 경로 | 2, `has no tag` · `could not fetch`, 표지 문자열 없음 |
| UT-07 | 태그 이동 | bare 리포에서 태그를 다른 커밋으로 옮긴 뒤 pull | 표준 오류 경고, lock 의 `resolved` 가 새 커밋 |
| UT-08 | `extends` 제거 | UT-01 뒤 `extends` 줄을 지우고 pull | 사본 · lock 없음, `removed the preset copy and the lock`, 생성물이 preset 없는 값 |
| UT-09 | 소스 리포 | 소스 트리 복제본에서 pull | 0 |
| UT-10 | 사용자 파일 | 새 preset 이 켠 역할의 커맨드 자리에 손으로 만든 파일 | 2 와 명세 58 3-3 안내, `--adopt` 면 `<경로>.orig` 로 옮기고 통과 |

## T10 · feat: harness pull 의 멈춤 조건과 덮는 키 보고

### 상위 Requirement

- relates to #216

### 작업 내용

pull 의 준비 단계에 남은 멈춤 조건 넷(요구 버전 · 잠금 · 사본과 lock 불일치 · 작업 트리 미정리)을 넣고, 성공했을 때 프로젝트 값이 preset 값을
덮는 키를 알린다.

- 명세 7-4(멈춤 조건 1 · 2 · 4 · 5) · 7-6 의 덮는 키 보고 · 5-2 의 `pull` 행
- `src/harness/preset/sync.py` · `src/harness/commands/pull.py`
  - 판정 순서는 7-2 의 번호 순이다: 5 → 4 → 1 → 2 → 3
  - 조건 5: 하네스 루트 아래에 `harness.toml` · `.harness/preset/` · `.harness/preset.lock` 을 뺀 미커밋 변경(추적 파일의 수정 · 스테이지된 변경 · 무시되지 않는
    추적 밖 파일)이 있다. ⑤ 안내의 줄은 `git status --porcelain` 의 두 글자 상태와 경로이고 10줄까지, 넘으면 `  … <N> more` 한 줄
  - 조건 4: T4 대조의 lock · 사본 구조 · `preset.toml` · 내용 · 남은 사본이 어긋나면 5-3 의 첫 표 안내. 체인 연결 · 프로젝트 참조 · 요구 버전 어긋남은 멈추지 않고 새로 받아 고친다
  - 조건 1: 새 체인의 어느 preset 의 `requires` 가 이 하네스의 버전보다 높다 — ① 안내. 고정 사본이 있으면 위임으로 그 버전이 돈다
  - 조건 2: 프로젝트 레이어가 새 체인의 잠긴 키에 다른 값을 적었다(같은 값은 통과) — ② 안내, 경로 열 `%-52s` 와 `locked by <ref>`
  - 덮는 키 보고: 프로젝트 레이어와 새 체인이 모두 적은 키 가운데 #207 의 병합 규칙이 프로젝트 값으로 덮어쓰는 것 — 스칼라 · 교체되는 배열 · `name` 이 같은
    `verify.checks` 항목 · 통째 교체되는 `workflows.<이름>` — 이 값이 달라 실제로 덮였으면 성공 출력 끝에 표준 오류로 7-6 의 `note:` 를 낸다. 합집합 목록
    (`docs.protected` · `branches.protected`)은 들지 않는다. 키는 경로 순으로 20개까지, 넘으면 `  … <N> more`. 값을 옮기지 않는다
- `render-test.sh` 의 "harness pull" 블록에 케이스를 더한다
- 건드릴 파일: `src/harness/preset/sync.py`, `src/harness/commands/pull.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 멈춤 조건 1 · 2 · 4 · 5 가 각각 종료 코드 2 · `nothing was changed` 이고 대상 리포 · 인덱스 · 매니페스트 바이트가 그대로다
- [ ] 조건 5 가 `harness.toml` · 사본 · lock 의 변경을 미정리로 보지 않고, 11 개 이상의 변경을 10줄과 `… <N> more` 로 줄인다
- [ ] 조건이 둘 이상 걸리면 5 → 4 → 1 → 2 → 3 가운데 앞선 것 하나만 낸다
- [ ] 프로젝트가 새 preset 의 잠긴 키에 다른 값이면 조건 2, 같은 값이면 통과한다
- [ ] `requires` 가 이 하네스보다 높은 preset 이면 조건 1 이다
- [ ] 사본을 손으로 고친 뒤 pull 은 조건 4 이고, 사본과 lock 을 지운 뒤 pull 은 통과한다
- [ ] `extends` 만 바꾼 상태의 pull 은 통과해 lock 과 사본을 새 참조로 고친다
- [ ] 내장 기본값 전체를 담은 `harness.toml` 로 pull 하면 note 에 preset 이 바꾼 키가 경로 순으로 나오고 값과 합집합 목록은 나오지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 조건 5 | 추적 파일 수정 · 무시되지 않는 새 파일 | 2, ⑤ 안내와 두 글자 상태 줄 |
| UT-02 | 조건 5 제외 | `harness.toml` · 사본 · lock 만 바뀐 상태 | 조건 5 로 멈추지 않는다 |
| UT-03 | 조건 5 줄임 | 미커밋 변경 12 개 | 10줄과 `  … 2 more` |
| UT-04 | 조건 4 | 사본 메모 변경 | 2, `the preset copy does not match .harness/preset.lock` |
| UT-05 | 조건 4 풀기 | UT-04 뒤 사본과 lock 삭제 | pull 통과 |
| UT-06 | 조건 1 | `requires = "99.0.0"` 인 preset | 2, ① 안내 |
| UT-07 | 조건 2 | 새 preset 이 잠근 `review.max_rounds` 를 프로젝트가 다른 값 · 같은 값으로 | 2 와 ② 안내 / 통과 |
| UT-08 | 순서 | 조건 5 와 조건 1 이 함께 | 조건 5 만 |
| UT-09 | `extends` 만 바꿈 | lock 과 다른 태그의 `extends` | 통과, lock 이 새 태그 |
| UT-10 | 덮는 키 보고 | 내장 기본값 전체 사본 `harness.toml`, preset 이 `commit.tags` · `review.max_rounds` · `workflows.retro` · `docs.protected` 를 적음 | note 에 앞의 셋이 경로 순, 값 없음, `docs.protected` 없음 |
| UT-11 | 바이트 그대로 | UT-01 · UT-04 · UT-06 · UT-07 의 멈춤 | 대상 리포 · 인덱스 · 매니페스트 바이트가 그대로 |

## T11 · feat: .harness 의 고정 사본과 preset 사본을 나눠 다루는 install · render · uninstall

### 상위 Requirement

- relates to #216

### 작업 내용

`.harness/` 를 하네스 입력의 사본 자리로 다루어 항목마다 쓰는 명령을 나눈다. 하네스를 올리는 install 이 preset 사본과 lock 을 지우지 않고,
`.harness/` 아래를 고정 사본으로 보던 지점들이 고정 사본 부분만 본다. 한 규칙이라 한 커밋에서 바꾼다.

- 명세 4-1 · 4-6 · 8-2 · 13 · 5-2 의 `install` 행 · 15 의 명세 58 4-4
- `src/harness/commands/install.py`
  - `install_registered()` 의 사본 교체: `.harness/` 안에서 매니페스트 둘과 `PRESET_PARTS` 를 남기고 나머지를 걷는다. `preset` 이 실제 디렉터리, `preset.lock` 이
    일반 파일일 때만 남긴다 — 링크면 다른 항목처럼 링크 자신만 걷는다
  - 소스 리포의 install: `PINNED_PARTS` 만 걷는다. preset 사본은 건드리지 않는다
  - `--preset` 없는 install: 설정에 `extends` 가 있거나 사본 · lock 이 있으면 T4 대조를 돈다. 통과하면 지금처럼 고정 사본을 갈아 끼우고 render 하며 사본과 lock 은
    바이트 그대로다. 어긋나거나 읽을 수 없으면 아무것도 바꾸지 않고 종료 코드 2 와 5-3 안내. 프로젝트 참조 어긋남(사본이 없는 경우 포함)이면 help 를
    `harness install --preset <extends 값>` 으로 낸다. 요구 버전은 설치하려는 전역 CLI 의 버전과 비교한다
  - `undo_created()` 는 그대로다 — 시작할 때 `.harness` 가 없었으면 통째로 걷는다
- `src/harness/render/apply.py`: 이전 `.harness/managed` 에서 옮기는 고정 사본 줄을 `PINNED_PARTS` 아래 경로의 줄로 한다
- `src/harness/manifest.py`(`prune()`) · `src/harness/changes.py`(`stale_paths()`): `.harness/` 아래 경로를 정리하지 않는다
- `src/harness/drift.py`: 고정 사본 help 줄(``the pinned copy under .harness/ comes back with `harness install` ``)을 `PINNED_PARTS` 아래 경로가 어긋날 때 낸다
- `src/harness/pin.py`: `pinned_files()` · `pinned_differences()` 는 고정 사본만 본다. preset 사본은 전역 CLI 대조에 들지 않는다
- `src/harness/readiness/items.py`: `managed files` 절에서 detail 이 고정 사본 아래 경로인 `modified` · `missing` 항목의 조치가 `harness install` 이다
- `src/harness/commands/uninstall.py`: `.harness/` 를 걷으므로 preset 사본과 lock 도 걷힌다. `--purge` 확인 목록의 `.harness/` 줄 설명은 사본이 있을 때
  `vendored copy of the harness and the preset` 다. `harness.toml` 의 `extends` 는 `--purge` 가 아니면 남는다
- `render-test.sh` 새 블록 "preset 과 install": pull 로 만든 리포에서 명세 16-1 의 "install 갱신", "`install` 이 사본 없는 프로젝트를 만나면", "요구 버전" 의 install, "uninstall" 케이스
- 건드릴 파일: `src/harness/commands/install.py`, `src/harness/render/apply.py`, `src/harness/manifest.py`, `src/harness/changes.py`, `src/harness/drift.py`, `src/harness/pin.py`, `src/harness/readiness/items.py`, `src/harness/commands/uninstall.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] `extends` 가 있는 프로젝트에서 `harness install` 뒤 사본 · lock 바이트가 그대로이고 고정 사본은 갈아 끼워진다
- [ ] 사본이 없는(또는 다른 참조의) 프로젝트에서 install 이 2 로 거부하고 help 가 `harness install --preset <extends 값>` 이며 아무것도 바뀌지 않는다
- [ ] 사본이 손으로 고쳐진 프로젝트에서 install 이 5-3 안내와 2 로 거부한다
- [ ] 버전을 낮춘 CLI 복제본으로 `requires` 가 그보다 높은 사본의 프로젝트를 install 하면 거부한다
- [ ] `.harness/preset` 이 바깥 디렉터리를 가리키는 링크면 install 이 링크만 걷고 바깥 디렉터리는 그대로다
- [ ] 소스 리포의 install 이 `PINNED_PARTS` 만 걷는다
- [ ] render 뒤 매니페스트에 `.harness/preset` 경로가 없고, 이전 매니페스트의 고정 사본 줄이 옮겨진다
- [ ] `check` 의 고정 사본 help 줄이 고정 사본 경로가 어긋날 때만 나온다
- [ ] uninstall 이 `.harness/preset/` 와 lock 을 걷고 `extends` 줄은 남기며, `--purge` 확인 목록의 `.harness/` 설명이 13절대로다
- [ ] `extends` 가 없는 프로젝트의 install · render · uninstall 결과가 이 task 전과 같다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | install 갱신 | pull 로 만든 리포에서 `harness install` | 0, 사본 · lock 바이트 그대로, 고정 사본 갱신 |
| UT-02 | 사본 없음 | 사본과 lock 을 지우고 커밋한 리포에서 install | 2, help `harness install --preset <extends 값>`, 바이트 그대로 |
| UT-03 | 사본 손편집 | 사본 메모 변경 | 2, 5-3 안내 |
| UT-04 | 요구 버전 | `requires` 가 현재 버전인 preset, 버전을 낮춘 CLI 복제본으로 install | 거부 |
| UT-05 | 사본 자리의 링크 | `.harness/preset` 을 바깥 디렉터리 링크로 | 링크만 걷힘, 바깥 디렉터리 그대로 |
| UT-06 | 매니페스트 | pull 뒤 render | `.harness/generated` · `.harness/managed` 에 `.harness/preset` 없음 |
| UT-07 | help 줄 | 고정 사본 파일 변경, 사본 변경 | 앞의 것에만 `harness install` help 줄 |
| UT-08 | uninstall | pull 로 만든 리포에서 uninstall, `--purge` 확인 목록 | 사본 · lock 없음, `extends` 줄 남음, `vendored copy of the harness and the preset` |

## T12 · feat: install --preset 으로 preset 에서 프로젝트 시작

### 상위 Requirement

- relates to #216

### 작업 내용

`harness install --preset <참조>` 가 preset 을 받아 사본과 lock 을 깔며 프로젝트를 시작한다. 준비 · 반영은 T9 · T10 의 `preset/sync.py` 를 쓰고,
install 은 넘기지 않으므로 전역 CLI 의 버전으로 돈다.

- 명세 8-1 · 14-4
- `src/harness/commands/install.py`
  - 새 플래그 `--preset REF`. `<참조>` 는 T1 로 판정한다
  - 대상의 `harness.toml` 이 없으면 씨앗 설정에 `extends = "<참조>"` 한 줄을 넣어 깔고 받는다. 있고 `extends` 가 `<참조>` 와 같으면 설정은 그대로 두고 사본과 lock 을
    그 참조대로 받아 맞춘다. 있고 `extends` 가 없거나 다르면 아무것도 바꾸지 않고 2 — 8-1 의 두 첫 줄과 help
  - 순서: 등록 잠금 · 같은 이름 판정 → 준비(멈춤 조건 4 · 받기 · 1 · 2 · 병합 검증 · render 계산 · 경로 사전 판정 · 3) → 반영(디렉터리 · `git init` · 씨앗 설정 ·
    고정 사본 · 등록 · 사본 · lock · render). 멈춤 조건 5 는 쓰지 않는다
  - 경로 사전 판정에 install 의 경로(`.harness` · `PINNED_PARTS` · 설정이 없으면 `harness.toml`)와 `.harness/preset/` 아래 경로 · `.harness/preset.lock` 을 함께 넣는다
  - 준비 단계에서 멈추면 아무것도 만들지 않는다. 반영 단계에서 멈추면 지금 install 처럼 이번 실행이 만든 것(디렉터리 · `.git` · 씨앗 설정 · 시작할 때 없던 `.harness`)을 걷는다
  - 출력은 install 의 줄, 7-6 의 pull 줄, render 의 줄 순서다
- `src/harness/commands/__init__.py`: install 사용법 `[--target DIR] [--adopt] [--create] [--git-init] [--preset REF]`, 도움말 `install: start the project from a preset (a full https://<host>/<path>@<tag> reference)`
- 씨앗 설정 원형 `src/templates/harness.toml`: 첫 테이블 앞에 14-4 의 `extends` 설명 주석을 둔다(값 없음). 씨앗 설정을 만드는 곳(#206 의 `seed_text`)이 `--preset` 이면
  그 주석 바로 아래, 첫 테이블 앞에 `extends` 줄을 넣는다. 내장 기본값 `src/templates/defaults.toml` 에는 `extends` 를 두지 않는다
- 씨앗 설정 원형의 내용을 보는 기존 기대값은 14-4 의 주석만큼 바뀐다
- `render-test.sh` 의 "preset 과 install" 블록에 명세 16-1 의 "`install --preset`" 케이스
- 건드릴 파일: `src/harness/commands/install.py`, `src/harness/commands/__init__.py`, `src/harness/config/load.py`(`seed_text`), `src/templates/harness.toml`, `src/test/render-test.sh`

### 완료 조건

- [ ] 새 대상에 `install --preset <참조>` 하면 씨앗 설정의 `extends` 설명 주석 바로 아래에 `extends` 줄이 있고, 사본 · lock · 고정 사본 · 생성물이 깔리며, 출력이 install · pull · render 순이다
- [ ] uninstall 로 사본과 lock 이 걷힌 같은 `extends` 의 설정에 `install --preset` 하면 다시 받는다
- [ ] `extends` 가 다르거나 없는 설정이면 8-1 의 첫 줄과 help 로 2 이고 아무것도 바뀌지 않는다
- [ ] 받기가 실패하면 새 대상에 디렉터리 · `.git` · `harness.toml` · `.harness` 가 생기지 않는다
- [ ] `--preset` 값이 2-1 을 어기면 2-1 안내로 2 이다
- [ ] `--preset` 없이 새로 설치한 `harness.toml` 에 `extends` 설명 주석이 있고 값은 없으며, `defaults.toml` 에 `extends` 가 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 새 대상 | 빈 디렉터리에 `install --create --git-init --preset <참조>` | 씨앗 설정의 주석 아래 `extends` 줄, 사본 · lock · 고정 사본 · 생성물, 출력 순서 |
| UT-02 | 다시 받기 | UT-01 뒤 uninstall, 같은 참조로 `install --preset` | 사본 · lock 이 다시 생긴다 |
| UT-03 | 다른 `extends` | 다른 참조의 `extends` 가 든 설정 | 2, `install --preset does not change it`, 바이트 그대로 |
| UT-04 | `extends` 없음 | `extends` 없는 설정 | 2, `harness.toml extends no preset — install --preset does not change it` |
| UT-05 | 받기 실패 | 없는 태그의 참조로 새 대상 | 2, 새 대상에 아무것도 없음 |
| UT-06 | 형식 | `--preset http://x/y@v1` | 2-1 안내, 2 |
| UT-07 | 씨앗 주석 | `--preset` 없는 새 설치 | 주석 있음 · `extends` 값 없음, `defaults.toml` 에 `extends` 없음 |

## T13 · feat: set extends 를 단독으로 쓰고 pull 을 안내

### 상위 Requirement

- relates to #216

### 작업 내용

`harness set extends <참조>` 가 `harness.toml` 의 `extends` 한 줄만 쓰고 render 대신 pull 을 안내한다. preset 을 올리는 경로(`extends` 를 고치고 → pull)의
첫 단계다. 쓰기 경로가 모두 갖춰지므로 갱신 경로별 불변식 테스트를 여기서 둔다.

- 명세 9 · 10 · 5-2 의 "`set extends` 는 대조하지 않는다"
- `src/harness/commands/set.py`
  - `extends` 와 다른 키를 함께 주면 아무것도 쓰지 않고 2: `error: extends is set on its own — it needs a pull, not a render`
  - `<참조>` 를 T1 로 판정하고, 어긋나면 쓰지 않고 2-1 의 안내문과 2
  - 쓰는 자리는 #207 의 `set` 이 파일에 없는 키를 더하는 규칙을 따른다 — 최상위 키라 첫 테이블 앞이다
  - render 하지 않고 사본 · lock 을 대조하지 않는다 — 설정 읽기의 대조(T5)를 거치지 않는다
  - 출력은 9절: `set: extends = "<이전>"` / `  to extends = "<새 값>"`, 키가 없던 파일은 첫 줄이 `set: extends (not set)`, 이어서 `next:` 와 `harness pull`
- `render-test.sh` 새 블록 "갱신 경로별 불변식"과 `set extends` 케이스
- 건드릴 파일: `src/harness/commands/set.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] `set extends <참조>` 단독이면 render 없이 9절 출력을 내고 `harness.toml` 만 바뀐다(생성물 · 매니페스트 · 사본 · lock 바이트 그대로)
- [ ] 키가 없던 파일에서 `extends` 줄이 첫 테이블 앞에 들고 첫 줄이 `set: extends (not set)` 이다
- [ ] 다른 키와 함께면 거부하고 `harness.toml` 바이트가 그대로다
- [ ] 형식 어긋남이면 2-1 안내와 2 이고 `harness.toml` 바이트가 그대로다
- [ ] 사본이 lock 과 어긋난 상태에서도 `set extends` 가 돈다
- [ ] pull · `set` · 개인 레이어 수정 · install · `install --preset` · `set extends` 마다 바뀐 커밋 대상 경로가 10절 표 안이고, 미리 둔 소유 파일 · `docs/spec/` · `docs/plan/` · 결정 기록 · 소스 파일의 바이트가 그대로다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 바꾸기 | `extends` 가 있는 설정에 `set extends <새 참조>` | 9절 출력, `harness.toml` 만 바뀜 |
| UT-02 | 더하기 | `extends` 없는 설정 | 첫 테이블 앞에 줄, `set: extends (not set)` |
| UT-03 | 다른 키와 함께 | `set extends <참조> review.max_rounds 6` | 2, `extends is set on its own`, 바이트 그대로 |
| UT-04 | 형식 | `set extends ssh://x/y@v1` | 2-1 안내, 바이트 그대로 |
| UT-05 | 대조하지 않음 | 사본을 고친 상태에서 `set extends` | 0 |
| UT-06 | 갱신 경로별 불변식 | 소유 파일 · `docs/spec/` · `docs/plan/` · `docs/adr/` · 소스 파일을 미리 둔 리포에서 여섯 경로를 차례로 | 경로마다 바뀐 커밋 대상 경로가 10절 표 안, 미리 둔 파일 바이트 그대로 |

## T14 · feat: doctor preset 절

### 상위 Requirement

- relates to #216

### 작업 내용

doctor 결과 목록에 `preset` 절을 더해 사본 · lock · `extends` 의 상태를 보인다. 원격에 묻지 않는다.

- 명세 12(CLI) · 5-2 의 `doctor` · `status` 행
- `src/harness/readiness/items.py`(`doctor_items`): `managed files` 절 바로 뒤에 `preset` 절. T4 대조 결과로 12절 표의 항목을 낸다. `bad` 항목이 있으면 `ok` 항목을 내지 않는다.
  `--remote` 여도 같다
- `status` 는 doctor 항목을 쓰므로 같은 항목이 나온다
- `render-test.sh` 의 "harness pull" 블록에 명세 16-1 의 "doctor `preset` 절" 과 "`extends` 만 바꾼 상태" 의 doctor · status 케이스
- 건드릴 파일: `src/harness/readiness/items.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] 12절 표의 조건마다(preset 없음 · 통과한 체인 · 사본 어긋남 · lock 읽을 수 없음 · 받지 않음 · `extends` 와 lock 다름 · 남은 사본 · 요구 버전 미달) state · what · detail 이 표대로다
- [ ] `extends` 만 바꾼 상태에서 doctor 의 `preset` 절이 `bad` 이고 `status` 의 doctor 항목에 같은 것이 있다
- [ ] `bad` 항목이 있으면 `preset` 절에 `ok` 항목이 없다
- [ ] `--remote` 여도 `preset` 절이 같고 preset 원격에 닿지 않는다
- [ ] `doctor --json` 에서 `preset` 절이 `managed files` 절 바로 뒤다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | preset 없음 | `extends` · 사본 · lock 없는 리포 | `ok` `no preset — harness.toml extends nothing` |
| UT-02 | 통과한 체인 | 깊이 2 를 pull 한 리포 | preset 마다 `ok` `preset <출처>@<태그>`, detail `depth <d> · <짧은 꼴>` |
| UT-03 | 사본 어긋남 | 깊이 1 메모 변경 | `bad` `the preset copy does not match the lock`, detail `.harness/preset/1: content differs from the lock`, `ok` 없음 |
| UT-04 | lock | 깨진 lock | `bad` `.harness/preset.lock is not a lock this harness reads` |
| UT-05 | 받지 않음 | `extends` 만 있고 lock 없음 | `bad` `the preset harness.toml extends is not pulled` |
| UT-06 | 다름 | `extends` 의 태그만 바꿈 | `bad` `harness.toml extends a preset the lock does not have`, status 에도 같은 항목 |
| UT-07 | 남은 사본 | `extends` 를 지우고 사본 · lock 남김 | `bad` `a preset copy is left but harness.toml extends nothing` |
| UT-08 | 요구 버전 | 버전을 낮춘 CLI 복제본의 doctor | `bad` `preset <출처>@<태그> needs harness <requires> or later` |
| UT-09 | 자리와 원격 | `doctor --json --remote` | `preset` 절이 `managed files` 바로 뒤, 같은 항목 |

## T15 · feat: 실행 상태에 preset 체인 digest 기록과 재개 대조

### 상위 Requirement

- relates to #216

### 작업 내용

driver 실행 상태의 `preset` 필드(#208 이 예약한 선택 필드)에 실행을 시작할 때의 체인 digest 를 쓰고, `--resume` 이 preset 이 바뀐 실행을 거부한다.
실행 상태에 필드를 더하지 않는다.

- 명세 11 · 4-5
- `src/harness/workflow/`(#208 의 드라이버 실행 상태와 재개)
  - 새 실행을 만들 때 `preset` 에 지금 lock 의 `content` 로 계산한 체인 digest(T3)를 쓴다. 체인이 비면 `null`
  - `--resume` 은 지금 체인 digest 가 상태의 값과 다르면 아무 단계도 돌리지 않고 종료 코드 2 와 11절의 안내. 상태에 `preset` 필드가 없으면 `null` 로 본다
  - 다시 시작하는 방법의 안내는 #208 의 정의 digest 불일치와 같다
- `render-test.sh` 의 #208 드라이버 블록 방식으로 케이스를 더하고, #208 의 실행 상태 단위 테스트에 digest 기록을 더한다
- 건드릴 파일: `src/harness/workflow/` 의 실행 상태 · 재개, `src/test/render-test.sh`, `src/test/unit/` 의 #208 실행 상태 테스트

### 완료 조건

- [ ] preset 이 없는 프로젝트의 새 실행 상태에 `"preset": null` 이 있다
- [ ] preset 이 있는 프로젝트의 새 실행 상태의 `preset` 이 4-5 의 체인 digest 다
- [ ] 게이트에서 멈춘 실행 뒤 다른 태그로 pull 하고 `--resume` 하면 아무 단계도 돌지 않고 11절의 안내와 2 다
- [ ] preset 을 바꾸지 않았으면 재개된다
- [ ] `preset` 필드가 없는 상태 파일은 `null` 로 읽고, 체인이 비어 있으면 재개된다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 빈 체인 기록 | preset 없는 프로젝트에서 driver 절차 시작 | 상태의 `preset` 이 `null` |
| UT-02 | digest 기록 | 깊이 2 를 pull 한 프로젝트 | 상태의 `preset` 이 체인 digest |
| UT-03 | 바뀐 preset | 게이트에서 멈춘 뒤 다른 태그로 pull, `--resume` | 2, `the preset changed since this run of <절차> <이슈> started`, 단계가 돌지 않음 |
| UT-04 | 그대로인 preset | 게이트에서 멈춘 뒤 `--resume` | 재개 |
| UT-05 | 필드 없음 | `preset` 필드를 뺀 상태 파일, preset 없는 프로젝트 | 재개 |

## T16 · feat: UI 의 preset doctor 문구와 레이어 이름표

### 상위 Requirement

- relates to #216

### 작업 내용

UI Doctor 화면이 `preset` 절의 `bad` 항목을 한국어로 설명하고, 설정 화면과 Workflows 캔버스가 preset 레이어를 그 참조로 보인다.

- 명세 12 의 `src/ui/lib/doctor.js` · 6-1 의 UI 이름표
- `src/ui/lib/doctor.js`: `SECTIONS` 에 `preset: "preset"`. `explain()` 이 12절의 `bad` 항목 여섯을 한국어로 옮기고 표의 조치를 단다 — 조치 없음 둘,
  `cmd` `harness pull` 셋, `cmd` `harness install` 하나
- `src/ui/lib/labels.js`: #207 이 둔 레이어 이름표 함수를 (레이어 id, schema `layers`) 를 받는 순수 함수로 하고 preset 규칙을 더한다 — `preset:<d>` 는 같은 id 의
  `layers` 항목이 있으면 `preset — <ref>`, 없으면 `preset <d>`. `default` · `project` · `local` 은 #207 대로다
- 이름표 함수를 부르는 곳 전부가 레이어 id 와 함께 `schema.layers` 를 넘긴다 — 설정 화면(`src/ui/app/[project]/settings/`)의 출처 · 잠근 레이어 표시와
  Workflows 캔버스(`src/ui/app/[project]/workflow/page.js` · `src/ui/components/FlowCanvas.js`)의 출처 레이어 표시. 착수 시점의 `src/ui/` 에서 부르는 곳을 찾아 모두 고친다
- 단위 테스트 `src/ui/lib/doctor.test.js` · `src/ui/lib/labels.test.js`
- 건드릴 파일: `src/ui/lib/doctor.js`, `src/ui/lib/labels.js`, 이름표 함수를 부르는 `src/ui/app/` · `src/ui/components/` 의 파일, `src/ui/lib/doctor.test.js`, `src/ui/lib/labels.test.js`

### 완료 조건

- [ ] `explain()` 이 12절의 `bad` 항목마다 표의 내용과 조치를 낸다
- [ ] `preset:<d>` 가 같은 id 의 `layers` 항목이 있으면 `preset — <ref>`, 없으면 `preset <d>` 로 보이고, `default` · `project` · `local` 의 이름표는 그대로다
- [ ] `src/ui/` 에서 이름표 함수를 부르는 곳이 모두 `schema.layers` 를 넘긴다
- [ ] `cd src/ui && node --test lib/*.test.js` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 절 이름 | `SECTIONS` | `preset: "preset"` |
| UT-02 | 조치 없는 항목 | `the preset copy does not match the lock` · `.harness/preset.lock is not a lock this harness reads` | 한국어 설명, 조치 없음 |
| UT-03 | pull 조치 | `the preset harness.toml extends is not pulled` · `harness.toml extends a preset the lock does not have` · `a preset copy is left but harness.toml extends nothing` | 한국어 설명, `cmd` `harness pull` |
| UT-04 | install 조치 | `preset … needs harness … or later` | 한국어 설명, `cmd` `harness install` |
| UT-05 | preset 이름표 | `preset:1` 과 같은 id 항목이 있는 `layers` · 없는 `layers` | `preset — <ref>` / `preset 1` |
| UT-06 | 다른 레이어 | `default` · `project` · `local` | #207 의 이름표 그대로 |

## T17 · docs: README · 절차 문서 · 규칙 문서 10장 · 명세 58 에 preset 반영

### 상위 Requirement

- relates to #216

### 작업 내용

T1 ~ T16 이 만든 동작을 사람용 설명과 규칙 문서 배치 표에 적고, `.harness/` 아래를 고정 사본으로만 서술하던 명세 58 의 네 자리를 지금 사실로 고친다.

- 명세 14-1 · 14-2 · 14-3 · 15
- `README.md`: 14-1 표의 다섯 자리 — "명령" 표의 `harness pull [--adopt]` 행과 `install` 행의 `--preset <참조>`, "파일은 세 부류다" 아래 문단, "`harness.toml` 이 정하는 것" 표의 `extends` 행,
  새 절 "preset", "업데이트" 절
- `src/templates/managed/docs/workflow/changing.md`: 14-2 의 두 자리. `src/bin/harness render` 로 이 리포의 `docs/workflow/changing.md` 를 갱신한다
- `src/templates/generated/.ai/AI_AGENT.md`: 10장 하네스 배치 표에 `.harness/` 행. `src/bin/harness render` 로 이 리포의 `.ai/AI_AGENT.md` 를 갱신한다
- `docs/spec/58-separate-managed-and-project-parts.md`: 2-2 · 2-4 · 4-2 · 4-4 를 15절 표의 오른쪽 사실로 고친다. 다른 절은 건드리지 않는다
- 건드릴 파일: `README.md`, `src/templates/managed/docs/workflow/changing.md`, `src/templates/generated/.ai/AI_AGENT.md`, `docs/spec/58-separate-managed-and-project-parts.md`, render 로 갱신되는 `docs/workflow/changing.md` · `.ai/AI_AGENT.md`

### 완료 조건

- [ ] README "명령" 표에 `harness pull [--adopt]` 행과 `install` 의 `--preset <참조>` 가 있다
- [ ] README 의 "preset" 절이 14-1 의 항목(preset 리포 형식 · 참조 형식과 SSH 사용자의 `insteadOf` · 체인과 상한 · 버전을 올리는 순서 · 멈춤 조건 다섯 · 사본을 손으로 고치지 않음 · 전체 값 사본 줄이기 · CI 는 preset 리포 자격증명이 필요 없음)을 담는다
- [ ] "파일은 세 부류다" 아래 문단, "`harness.toml` 이 정하는 것" 표의 `extends` 행, "업데이트" 절이 14-1 대로다
- [ ] `changing.md` 두 자리가 14-2 대로이고 이 리포의 `docs/workflow/changing.md` 가 render 결과와 같다
- [ ] 규칙 문서 10장 배치 표에 `.harness/` 행이 있고 이 리포의 `.ai/AI_AGENT.md` 가 render 결과와 같다
- [ ] 명세 58 의 네 자리가 15절의 사실로 바뀌었고 다른 절은 그대로다
- [ ] 추가한 문장에 실제 호스트 · 자격증명 · 개인 홈 절대 경로가 없다 — 예시 호스트는 `git.example.com`
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 문서 참조 | 수정 뒤 `harness doctor` | README · 절차 문서가 가리키는 경로가 모두 있다는 `ok` 줄 |
| UT-03 | 반영 확인 | `README.md` · `docs/workflow/changing.md` · `.ai/AI_AGENT.md` 10장 · 명세 58 | 14-1 ~ 14-3 · 15 의 자리마다 그 사실 |

## T18 · docs: 보호 문서에 preset 상속 반영

### 상위 Requirement

- relates to #216

### 작업 내용

preset 상속으로 생긴 소관 · 구성 요소 · 데이터 흐름 · 신뢰 경계 · 용어 · 테스트 방식을 에이전트가 근거로 읽는 문서에 적는다.

**보호 문서를 수정하는 task 다.** 2026-10-09 결정 게이트에서 사용자가 허용한 범위 — 명세 17절 "보호 문서 개정 범위" 의 표 — 안에서만 고친다.
그 범위 밖의 문장은 고치지 않는다. 권한 설정 · 가드에 걸리면 사람이 대응한다.

- 명세 17-1 ~ 17-4
- `.ai/project/scope.md`: "할 수 있는 일" 과 "만들지 않는 것" 에 17-1 의 항목 하나씩
- `.ai/project/architecture.md`: "구성 요소" · "데이터 흐름"(새 항목과 렌더) · "신뢰 경계" 의 들어오는 입력 · "새 코드를 둘 곳" · "계층과 의존 방향" · "검사하지 않는 것" 에 17-2 의 사실
- `.ai/project/glossary.md`: 새 행 `preset` · `전체 참조` · `체인` · `preset 사본` · `lock`, #208 이 둔 `하위 절차` · `확장 지점` 행 끝에 17-3 의 한 문장, `매니페스트` 행 끝에 한 문장
- `.ai/project/testing.md`: "외부 의존을 어떻게 다루나" 에 17-4 의 사실
- 같은 절을 먼저 고친 #206 · #207 · #208 의 문장 위에 더한다. 그 문장을 지우거나 바꾸지 않는다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/scope.md`, `.ai/project/architecture.md`, `.ai/project/glossary.md`, `.ai/project/testing.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] 네 문서가 명세 17-1 ~ 17-4 표의 자리마다 그 사실을 담는다
- [ ] 네 문서에서 17절 표에 없는 자리의 문장이 바뀌지 않았다(`git diff` 로 확인)
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 1장 · 2장 · 5장이 네 문서와 일치한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/216-org-presets` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 반영 확인 | `.ai/AI_AGENT.md` | 1장에 `pull` · `install --preset` 과 preset 리포 운영 제외, 2장에 `preset` · `전체 참조` · `체인` · `preset 사본` · `lock`, 5장에 `src/harness/preset/` · preset 데이터 흐름 · preset 원격의 신뢰 경계 |
| UT-03 | 범위 | 네 문서의 `git diff` | 17절 표의 자리 밖에 바뀐 줄이 없다 |
