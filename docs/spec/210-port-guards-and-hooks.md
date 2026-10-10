# 명령 가드·시크릿 스캔·git 훅 본문의 Python 이식

명령 가드(Claude Code `PreToolUse(Bash)` 훅), 시크릿 스캔, git 훅(commit-msg · pre-commit · pre-push)의 본문이
CLI 패키지(`src/harness/`)의 하위 명령으로 옮겨 간다. 외부 계약을 유지하는 이식이다 — **Claude Code 가
보내는 입력에 대한 판정은 통과 쪽으로 하나도 뒤집히지 않고**, 차단 사유 문구 · 종료 코드 · 사용 기록이 그대로다.
셸 가드와 판정이 달라질 수 있는 입력은 5-2 의 표가 전부다.

기준 코드는 #206 의 패키지 배치(`src/harness/`, 명령마다 `commands/` 모듈 하나, 고정 사본 `.harness/lib/harness/`)가
들어가고, #220 의 셸 가드 수정(기존 판정에 여러 줄 · 히어독을 나눠 보는 줄 판정을 더한 것)이 머지된 통합 브랜치다. 선행은 #206 과 #220 이다.
이 명세에서 "현행" 과 "셸 가드" 는 #220 이 머지된 뒤의 셸 구현을 말한다.

근거 결정 기록은 0011(터미널 출력은 영어) · 0012(시크릿 스캔은 더한 줄만 본다) · 0013(소스 리포는 사본 없이
`src/bin/harness` 로 돈다)과 "하네스 로직은 Python 표준 라이브러리 패키지 하나에 둔다"(#206 분해에서 작성)다.
이 명세가 새로 요구하는 결정 기록은 없다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 명령 가드 — 입력 해석 · 기존 판정 명령과 줄 판정 문자열 · 낱말 분해 · 가드 6종 | `src/harness/guard/` |
| 시크릿 스캔 | `src/harness/guard/` 의 시크릿 스캔 모듈 |
| git 훅 본문 | `src/harness/hooks.py` |
| `script/harness.env` 읽기 | `src/harness/envfile.py` |
| 표지 읽기(`script/harness-format.sh`) | `src/harness/format.py` 의 `markers()` — #209 와 이 명세 가운데 먼저 머지되는 쪽이 만든다 (6절) |
| 명령 등록과 명령 모듈 | `COMMANDS` · `DELEGATES` 와 `src/harness/commands/` 의 `bash_guard` · `secret_scan` · `git_hook`. 셋 다 통과 명령이다 (2-1) |
| 생성 — 훅 명령 · git 훅 shim · `harness.env` 의 새 키 | #206 의 생성 모듈(`settings_json()` · `derive()` · `plan()`)과 `src/templates/generated/script/githooks/` |
| 옛 경로의 shim | `src/templates/managed/script/hooks/bash-guard.sh` · `src/templates/managed/script/secret-scan.sh` |
| 회귀 테스트 | `src/templates/managed/script/test-bash-guard.sh` · `test-secret-scan.sh` · `src/test/render-test.sh` · `src/test/unit/` |

이 리포의 `script/` 아래 같은 이름의 파일은 거기서 설치된 사본이다.

## 1. 바뀌는 것과 바뀌지 않는 것

바뀌지 않는 것:

- 가드 6종과 그 순서 — 보호 브랜치 → force push → 훅 우회 → 원격 삭제 → 보호 문서 셸 편집 → write-doc. 처음 걸린
  가드의 사유가 나온다
- 차단 프로토콜 — 0 통과, 2 차단. 사유와 안내는 표준 오류로 내는 영어 문장이고 한 글자도 바뀌지 않는다
- 차단할 때의 사용 기록 — 하네스 루트의 `script/usage-log.sh` 가 실행 가능하면 `block bash-guard <라벨>` 로 부르고
  출력과 실패를 버린다. 라벨은 `protected-branch` · `force-push` · `no-verify` · `remote-delete` · `arch-doc` 다섯이다
  (write-doc 가드도 `arch-doc`)
- 판정 값의 출처 — `script/harness.env`. `harness.toml` 을 읽지 않는다. 명령이 있는데 이 파일을 읽지 못하면 차단한다
- 시크릿 스캔 계약 — 더한 줄만 본다, 값을 출력하지 않는다, `--staged` 를 받는다, 0 발견 없음 · 1 발견 · 2 실행 실패,
  탈출구는 `harness:allow-secret` 표지 하나이고 그 정본은 `script/harness-format.sh` 다
- git 훅의 판정 · 문구 · 사용 기록(`block commit-msg format` · `block pre-commit secret-scan` ·
  `block pre-push protected-branch` · `block pre-push verify`)
- `core.hooksPath` 와 그 기대 값, 훅 파일 이름, post-commit 훅
- `.claude/settings.json` 의 `permissions`(allow · deny)와 에이전트가 보는 명령 표기(`script/secret-scan.sh` 등)
- 파일 부류 — `script/githooks/*` 는 생성, 옛 경로의 shim 둘(`script/hooks/bash-guard.sh` · `script/secret-scan.sh`)은 관리
- Codex 에는 훅을 연결하지 않는다(`vendors.toml` 의 `hooks = false`)
- doctor 의 `no command guard for <오케스트레이터>` 항목과 그 설명, UI Doctor 문구
- 결정 기록 본문. 0012 · 0013 의 `script/…` 경로 표기는 그 시점의 관측이다

바뀌는 것:

- CLI 에 하위 명령 셋이 생긴다 — `bash-guard` · `secret-scan` · `git-hook` (2절)
- `.claude/settings.json` 의 `PreToolUse` 훅 명령이 하네스 루트의 CLI 를 부른다 (3-1)
- `script/githooks/` 의 commit-msg · pre-commit · pre-push 가 CLI 를 찾아 `git-hook` 으로 넘기는 shim 이다 (3-2)
- `script/hooks/bash-guard.sh` · `script/secret-scan.sh` 가 CLI 로 넘기는 shim 이다 (3-3)
- `script/hooks/_guards.sh` 가 관리 파일 목록에서 빠진다. 다음 render · install 의 정리가 대상 리포에서 지운다 — 관리
  파일 목록에서 빠진 경로는 수정 여부와 상관없이 지우고, 매니페스트에 없는 파일은 건드리지 않는 기존 정리 규칙이다
- `script/harness.env` 에 `VERIFY_PRE_PUSH`(`1` · `0`)가 생긴다. `verify.pre_push` 의 값이다

## 2. 하위 명령

### 2-1. 등록

| 이름 | 통과 | 설정 필요 | 인수 | `harness help` 설명 |
|---|---|---|---|---|
| `bash-guard` | `True` | 아니오 | (없음) | `PreToolUse(Bash) hook: read the tool call JSON on standard input and block a command the guards forbid (exit 2)` |
| `secret-scan` | `True` | 아니오 | `[--staged]` | `look for credentials in the lines being added (exit 1 when found)` |
| `git-hook` | `True` | 아니오 | `<commit-msg\|pre-commit\|pre-push>` | `run a git hook body; script/githooks/ calls this` |

- `COMMANDS` 항목은 표의 순서대로 `(통과, 설정이 필요한가, 인수, 설명)` 이다 — 셋 다 첫 원소가 `True` 인 통과 명령이고,
  설정이 필요하지 않다
- 셋 다 `DELEGATES` 에 든다. 전역 CLI 로 부르면 대상 리포의 고정 사본이 답한다
- 인자는 #206 3-3 "인자 통과" 의 규칙으로 나뉜다
  - 명령줄은 `harness [--target DIR] <명령> <인자…>` 다. 이름 뒤의 토큰은 공용 파서를 거치지 않고 순서 · 내용 그대로
    그 명령의 인자다
  - 이름 바로 뒤의 `--target DIR`(`--target=DIR`) 한 번만 하네스 루트로 읽는다. 그 뒤에 다시 오는 `--target` 은 명령의
    인자다 — `git-hook pre-push --target R` 의 `--target R` 은 훅 이름 뒤의 남는 인수다
  - 진입점(3절)은 `harness --target <루트> <명령> …` 으로 부른다. `harness <명령> --target <루트> …` 도 같다
- 하네스 루트는 그 `--target DIR`(기본 현재 디렉터리)이다. 판정 값 · 표지 · 사용 기록 스크립트를 그 아래에서 찾는다
- **작업 디렉터리를 옮기지 않는다.** 가드의 상대 경로 · 브랜치 판정과 commit-msg · pre-push 의 git 명령은 프로세스의
  작업 디렉터리에서 돈다. 시크릿 스캔의 git 만 하네스 루트에서 돈다(6절) — 현행 스크립트와 같다
- 문구에 나오는 `<루트>` 는 `--target` 을 심볼릭 링크를 풀지 않고 절대 경로로 만든 것이다 — 현행 `cd … && pwd` 와 같다
- `--target` 말고 경로 인수를 받지 않는다. commit-msg 의 메시지는 표준 입력으로 받는다 (3-2)
- 인수 검사 — 이름 바로 뒤의 `--target DIR` 를 뺀 나머지 인수를 본다
  - `secret-scan` 은 `--staged` 말고 아무것도 받지 않는다. 줄여 쓴 옵션(`--stage`) · 다른 명령의 옵션(`--purge` 등) ·
    `--staged` 뒤에 온 `--target` · 남는 위치 인수는 `error: unknown option: <인수>` 와
    `usage: harness secret-scan [--staged]` 를 내고 종료 코드 2
  - `git-hook` 은 훅 이름 하나만 받는다. 없거나 모르는 이름이거나 남는 인수(훅 이름 뒤의 `--target` 포함)가 있으면
    `usage: harness git-hook <commit-msg|pre-commit|pre-push>` 를 내고 종료 코드 2
  - `bash-guard` 는 인수가 있으면 판정하지 않고 `usage: harness bash-guard` 를 내고 종료 코드 1 — 2 는 차단이라
    쓰지 않는다

### 2-2. 예기치 않은 예외

| 명령 | 표준 오류(한 줄) | 종료 코드 | 뜻 |
|---|---|---|---|
| `bash-guard` | `error: the command guard stopped on an unexpected error and did not check this command — <예외 이름>: <메시지>` | 1 | 통과 |
| `secret-scan` | `error: the secret scan stopped on an unexpected error — <예외 이름>: <메시지>` | 2 | 실행 실패 |
| `git-hook` | `error: the <훅> hook stopped on an unexpected error — <예외 이름>: <메시지>` | 1 | 거부 |

- 트레이스백을 내지 않는다. 메시지는 첫 줄만 쓴다
- Claude Code 는 종료 코드 2 만 차단으로 보고 그 밖의 0 이 아닌 코드는 막지 않는 오류로 다룬다
  <!-- TBD: 확인 필요 — 설치된 Claude Code 버전에서 -->
- 가드의 문자열 처리는 어떤 명령 문자열에도 예외를 내지 않는다. 예외는 파일 · 프로세스 오류에서만 난다 (4-4)

### 2-3. 가드 경로의 import

`bash-guard` 는 Bash 도구 호출마다 돈다.

- 진입 스크립트와 벤더 선언 말고는 `harness.toml` 해석 · render · 지표 모듈과 `urllib` · `http` 를 불러오지 않는다.
  진입 스크립트가 맨 먼저 불러오는 `tomllib`(#206 2-2)와 `harness.cli` 를 불러올 때 읽는 벤더 선언(#206 3-3)은 모든
  명령에 공통이고 이 제한에 들지 않는다
- 모듈 최상위의 `urllib` · `http` 는 #206 3-1 · 3-4 가 패키지 전부에서 막는다. 가드 경로는 함수 안에서 늦게 불러오는
  것도 하지 않는다
- 판정에 쓰는 CLI 패키지 모듈은 가드 모듈(`src/harness/guard/`)과 `envfile` 이다
- 차단 때의 사용 기록은 `script/usage-log.sh` 를 하위 프로세스로 부른다(1절). 사용 기록 모듈을 불러오지 않는다
- 가드는 사용 기록 호출 말고 아무것도 쓰지 않는다

## 3. 진입점

### 3-1. `.claude/settings.json` 의 훅 명령

`hooks.PreToolUse[0]` 의 `matcher` 는 `Bash` 그대로이고, 그 `hooks[0].command` 가 아래 한 줄이다.

```sh
for c in "$CLAUDE_PROJECT_DIR/.harness/bin/harness" "$CLAUDE_PROJECT_DIR/src/bin/harness"; do [ -x "$c" ] && exec "$c" --target "$CLAUDE_PROJECT_DIR" bash-guard; done; echo "error: harness CLI not found under $CLAUDE_PROJECT_DIR (.harness/bin/harness or src/bin/harness)" >&2; echo "help: harness install --target $CLAUDE_PROJECT_DIR" >&2; exit 1
```

- 고정 사본의 CLI 를 먼저 찾고, 없으면 소스 리포의 CLI 를 쓴다(0013). 대상 리포와 소스 리포의 생성물이 같다
- 둘 다 없으면 #213 4-1 의 shim 공통 문구 두 줄을 내고 1 로 끝난다. 통과다
- POSIX 셸 문법(`for` · `[ -x ]` · `&&` · `exec`)을 쓴다. Claude Code 가 훅 명령을 POSIX 셸로 실행한다는 전제다
  <!-- TBD: 확인 필요 — 훅 명령을 실행하는 셸 -->
- worktree 에서는 `$CLAUDE_PROJECT_DIR` 가 worktree 이므로 worktree 의 CLI 가 worktree 의 `script/harness.env` 로 판정한다

### 3-2. git 훅 shim — `script/githooks/{commit-msg,pre-commit,pre-push}`

셋 다 생성 파일이고 내용에 설정 값이 들어가지 않는다. 템플릿 변수(`{{COMMIT_SUBJECT_RE}}` · `{{PROTECTED_REF_CASE}}` ·
`{{PRE_PUSH_VERIFY}}` 등)를 쓰지 않는다. 각 파일이 하는 일:

1. 하네스 루트를 현행과 같이 잡는다 — 자기 위치의 `../..`, 거기에 `script/harness.env` 가 없으면
   `git rev-parse --show-toplevel`
2. 루트가 있으면 `<루트>/.harness/bin/harness`, `<루트>/src/bin/harness` 순으로 실행 가능한 첫 CLI 에
   `exec <CLI> --target <루트> git-hook <훅>` 한다
   - commit-msg 는 git 이 넘긴 메시지 파일을 표준 입력으로 연결한다(`< "$1"`)
   - pre-push 는 git 이 표준 입력으로 준 ref 줄을 그대로 물려준다. 원격 이름 · URL 인수는 넘기지 않는다
   - pre-commit 은 인수가 없다
3. 루트를 잡지 못했거나 CLI 를 찾지 못하면 아래처럼 끝난다. 사용 기록은 남기지 않는다 — 규칙 위반이 아니라 하네스가
   없는 것이다. 문구는 #213 4-1 의 shim 공통 문구이고, 종료 코드는 훅마다 현행의 통과 · 거부 뜻을 따른다

| 훅 | 표준 오류 | 종료 코드 |
|---|---|---|
| commit-msg | `error: harness CLI not found under <루트> (.harness/bin/harness or src/bin/harness)` / `help: harness install --target <루트>` | 1 (거부) |
| pre-commit | (없음) | 0 (통과) |
| pre-push | commit-msg 와 같은 두 줄 | 1 (거부) |

- 문구의 `<루트>` 는 1 에서 잡은 루트다. 잡지 못했으면 자기 위치의 `../..` 다
- 머리글 주석(생성 표지 · 활성화 안내)은 현행대로 둔다. pre-commit 머리글의 "하네스를 찾지 못하면 통과시킨다" 도 그대로다
- 모노레포 서브프로젝트의 훅은 그 서브프로젝트의 CLI 를 찾는다

### 3-3. 옛 경로의 shim

| 파일 | 하는 일 | CLI 를 찾지 못하면 |
|---|---|---|
| `script/hooks/bash-guard.sh` | 자기 위치의 `../..` 를 루트로, 3-2 의 순서로 CLI 를 찾아 `exec <CLI> --target <루트> bash-guard` | 3-2 의 두 줄 · 1 (통과) |
| `script/secret-scan.sh` | 자기 위치의 `..` 를 루트로, 같은 순서로 찾아 `exec <CLI> --target <루트> secret-scan "$@"` | 3-2 의 두 줄 · 2 (실행 실패) |

- 형태는 #213 4-1 의 shim 과 같다 — 자기 위치로 루트를 잡고, ADR 0013 의 순서로 CLI 를 고르고, `--target <루트> <명령>`
  으로 exec 하며, 현재 디렉터리 · 표준 입출력 · 환경을 바꾸지 않는다. CLI 를 찾지 못했을 때의 종료 코드만 지점의 뜻을 따른다
- 이미 떠 있는 Claude Code 세션은 시작할 때 읽은 훅 명령(`$CLAUDE_PROJECT_DIR/script/hooks/bash-guard.sh`)을 계속 쓴다
  <!-- TBD: 확인 필요 -->. 그 세션의 가드도 shim 을 거쳐 새 구현으로 돈다
- `script/secret-scan.sh` 는 사람이 직접 돌리는 경로다. pre-commit 은 이것을 거치지 않는다
- 두 shim 을 걷는 일은 #221 이 맡는다

## 4. 명령 가드 — `harness bash-guard`

### 4-1. 순서

1. 표준 입력 전체를 읽어 명령을 꺼낸다 (4-2). 꺼내지 못했거나 꺼낸 값이 빈 문자열이면 0
2. 꺼낸 명령에서 기존 판정 명령과 줄 판정 디코드를 만든다 (4-3)
3. `<루트>/script/harness.env` 를 읽는다 (4-6). 읽지 못하면 차단(2)
4. 기존 판정 — 가드 6종(4-5)이 기존 판정 명령을 순서대로 판정한다. 처음 걸린 가드가 사용 기록을 남기고 사유를 내고 2
5. 줄 판정 — 줄 판정 디코드에 줄바꿈(LF)이나 `<<` 가 있을 때만 판정 문자열을 만들어(4-3) 가드 6종이 판정한다. 처음
   걸린 가드가 4 와 같이 끝낸다
6. 0

- 순서는 #220 2절과 같다. 두 판정은 같은 가드 함수를 같은 순서로 부른다
- 기존 판정이 먼저다. 두 판정이 모두 막는 명령의 사유는 기존 판정의 것이다

### 4-2. 입력 해석

- 표준 입력을 UTF-8 로 읽어 JSON 으로 엄격하게 푼다. 풀지 못하면 판정하지 않고 0 이다 — 빈 입력, JSON 이 아닌 글,
  잘린 JSON, 문자열 안의 이스케이프되지 않은 제어 문자, UTF-8 이 아닌 바이트가 여기 든다
- 최상위가 객체이고 `tool_input` 이 객체이고 그 `command` 가 문자열일 때만 명령을 꺼낸다. 아니면 0. 다른 자리의
  `command` 키는 보지 않는다
- 명령을 꺼내지 못하면 통과시키는 것은 현행 원칙 그대로다. 설정을 읽지 못한 경우(4-6)만 차단한다

### 4-3. 기존 판정 명령과 줄 판정 문자열

#220 이 셸 가드에 넣은 두 판정의 입력 만들기를 그대로 옮긴다. 규칙의 정본은 #220 명세 3절(기존 판정 명령)과
4-1 ~ 4-4(줄 판정)이고, 이식은 그 표의 행마다 같은 결과를 낸다. 이식이 더 정하는 것은 셸이 받던 JSON 문자열 표기를
되살리는 일뿐이다.

**원문 표기.** 셸 가드는 JSON 을 풀지 않은 문자열 값에서 시작하고, 4-2 는 JSON 을 푼 명령을 꺼낸다. 이식은 꺼낸 명령을
5-1 의 전제가 정하는 직렬화로 다시 적어 원문 표기를 얻는다.

- `"` → `\"`, `\` → `\\`, 줄바꿈 → `\n`, 탭 → `\t`, CR → `\r`, BS → `\b`, FF → `\f`, 그 밖의 제어 문자(U+0000–U+001F)와
  짝 없는 서로게이트 → `\uXXXX`. 나머지 글자는 그대로다
- 5-1 의 전제 아래 원문 표기는 Claude Code 가 보낸 문자열 값과 같다
- `\uXXXX` 의 16진수 대소문자는 판정에 닿지 않는다. 그 표기가 든 낱말은 백슬래시 때문에 경로로 풀리지 않고 보호 목록의
  이름이 될 수 없다

**기존 판정 명령** (#220 3절)

1. 원문 표기에 `\"` → `"`, `\n` → 공백, `\t` → 공백, `\\` → `\` 를 이 순서로 하나씩 값 전체에 적용한다. 각 치환은 왼쪽부터
   겹치지 않게 찾아 바꾸고(`sed s///g` · `str.replace` 와 같다), 앞 치환의 결과에 뒤 치환이 걸린다. 그래서 글자로 적힌
   백슬래시+`n`(원문 `\\n`)과 줄 끝 백슬래시(원문 `\\\n`)는 백슬래시와 공백이 된다. 그 밖의 이스케이프(`\r` · `\b` ·
   `\f` · `\uXXXX`)는 적힌 그대로 둔다
2. 처음 나오는 `<<` 부터 끝까지 잘라낸다. 따옴표 안이어도, `<<<` 여도 자른다

**줄 판정 디코드** (#220 4-1)

- 원문 표기의 이스케이프를 한 번에 푼다. 이스케이프 하나는 한 번만 풀린다 — `\"` → `"`, `\\` → `\`, `\n` → 줄바꿈,
  `\t` → 탭, `\r` → CR. 그 밖(`\b` · `\f` · `\uXXXX`)은 적힌 그대로다
- 결과는 꺼낸 명령에서 줄바꿈 · 탭 · CR 말고 제어 문자와 짝 없는 서로게이트를 이스케이프 표기로 되돌린 것과 같다
- 글자로 적힌 백슬래시+`n` 은 백슬래시와 `n` 두 글자다. CR 은 낱말 안의 글자이고 줄을 나누지 않는다

**줄 판정 문자열** (#220 4-2 · 4-3 · 4-4)

디코드에 줄바꿈이나 `<<` 가 있을 때만 만든다. 디코드를 앞에서부터 읽어 줄바꿈이 없는 문자열을 만든다. #220 4-2 표의
행 전부를 옮기고, 요지는 아래와 같다.

- 따옴표 구간(`'…'` · `"…"` · `$'…'`)은 줄을 넘을 수 있고, 안의 줄바꿈은 공백이 된다. 닫히는지는 명령 끝까지 보고 정한다.
  닫히지 않은 따옴표는 그 글자를 그대로 두고, 그 뒤로는 따옴표 글자를 따옴표로 보지 않는다
- 따옴표 밖의 백슬래시+줄바꿈은 지운다(줄 잇기). 따옴표 밖의 줄바꿈은 `;` 가 된다
- `<<<` 는 그대로 둔다. `<<` · `<<-` 는 히어독 연산자다. 연산자와 구분어, 연산자 줄의 나머지는 남고, 본문과 종결 줄은
  빠진다. 판정은 종결 줄 다음 줄부터 다시 한다. `<<-` 의 탭 떼기, 연산자 여럿, 종결 줄이 없는 본문, 구분어의 따옴표 ·
  백슬래시 떼기는 #220 4-3 그대로다
- 산술 구간 `$((…))` · `((…))` 은 그대로 둔다 — 안의 `<<` 는 시프트 연산자다. 산술 구간인지는 #220 4-2 의 괄호 세기로
  정한다. 명령 치환 구간(`$(…)` · 백틱) 안의 따옴표와 줄바꿈은 바깥과 같이 다룬다
- 다루지 못하는 구조를 만나면 그 자리 앞까지만 만든다 — #220 4-4 의 다섯 행: 명령 치환 안의 `<<`, 조건에 맞는 명령 치환이
  든 큰따옴표 구간, 같은 줄 안에서 닫히지 않는 산술 구간, 구분어가 빈 연산자, 본문이 남은 히어독이 있는데 명령 치환 안에서
  만난 줄바꿈. 그 자리부터 뒤는 기존 판정만 본다
- 판정 문자열은 `<<` 에서 자르지 않는다

공통:

- 기존 판정 명령과 줄 판정 문자열에는 줄바꿈이 없다. 낱말 분해(4-4)와 가드(4-5)는 둘을 각각 한 줄 명령처럼 읽는다
- 히어독 본문에 적힌 위험 명령은 어느 판정도 보지 않는다. 기존 판정은 `<<` 에서 자르고, 줄 판정은 본문을 뺀다

### 4-4. 낱말 분해와 명령 자리

#220 머지 뒤 셸 구현의 규칙을 그대로 옮긴다 — #220 이 바꾸지 않은 기존 가드의 규칙이다(#220 1절 · 4-5). 기존 판정
명령과 줄 판정 문자열에 같은 규칙을 쓴다. 셸 문법 라이브러리(`shlex` 등)의 분해 결과로 판정하지 않는다. 아래는 그런
분해와 갈리는 지점이고 전부 셸 가드의 규칙이다.

| 지점 | 규칙 |
|---|---|
| 따옴표 구간 | 안에 `$` · 백틱 · 백슬래시가 없는 `"…"` · `'…'` 만 푼다. 따옴표를 떼고, 안의 공백 · 탭 · `\|` · `;` · `&` · `~` 를 구분자나 확장으로 보지 않는다. 그 밖의 구간은 따옴표째 글자 그대로 둔다 |
| 빈 따옴표 | `''` · `""` 만으로 된 낱말은 빈 인수다. 낱말에 붙은 빈 따옴표는 지운다(`g''it` 은 `git`) |
| 닫히지 않은 따옴표 | 여는 따옴표부터 끝까지 글자 그대로 두고 판정을 계속한다 |
| 따옴표 밖의 백슬래시 | 이스케이프로 풀지 않는다. 백슬래시와 다음 글자를 그대로 두며, 다음 글자가 공백이면 그 공백은 여전히 낱말 경계다. 줄 끝 백슬래시는 4-3 이 이미 처리했다 |
| `#` | 주석으로 보지 않는다 |
| 구획 | 풀린 따옴표 구간 밖의 `\|` · `;` · `&` 에서만 나눈다. 리다이렉션과 괄호는 구획을 나누지 않는다. 줄 판정 문자열에서는 따옴표 밖의 줄바꿈이 이미 `;` 다(4-3) |
| 낱말 경계 | ASCII 공백과 탭뿐이다. 유니코드 공백(U+00A0 등)에서 나누지 않는다 |
| 명령 자리 | 구획의 첫 낱말. 앞에 붙은 `$(` · `(` · 백틱을 떼고 본다. 빈 낱말 · `{` · `!` · `sudo` · `command` · `exec` · `nohup` · `time` · `env` · `then` · `do` · `else` 와 `=` 가 든 낱말은 건너뛰고 다음 낱말을 본다. 프로그램은 그 이름 자체이거나 `/<이름>` 으로 끝나는 낱말이다 |
| git 전역 옵션 | `-c` · `--namespace` · `--exec-path` · `--config-env` 는 값까지, 그 밖의 `-` 로 시작하는 낱말은 그 낱말만 걷는다. `-C` 는 그때까지의 디렉터리에 차례로 덧붙이고, `--git-dir` · `--work-tree` 는 디렉터리를 풀지 못한 것으로 둔다 |
| 작업 디렉터리 | 앞 구획의 `cd` 가 옮긴 곳을 다음 구획에 이어 쓴다. 인수 없는 `cd` 와 `cd -`, 셸이 실행 때 정하는 값(변수 · 명령 치환 · glob · 중괄호 · 괄호 · 따옴표 · 백슬래시)이 든 경로, `~사용자` 는 풀지 못한 것이다. 풀지 못한 디렉터리, git 작업 트리가 아닌 디렉터리는 훅 작업 디렉터리로 판정한다 |
| 다른 리포 | 명령이 가리키는 작업 트리의 git 공통 디렉터리(실제 경로)가 하네스 루트의 것과 다르면 보호 브랜치 가드를 그 호출에 적용하지 않는다. 어느 쪽이든 공통 디렉터리를 얻지 못하면 같은 리포로 본다 |

- git 을 부르지 못하거나(없음 · 실행 실패) 0 이 아닌 코드로 끝나면 그 출력이 빈 것으로 본다 — 현행의 `2>/dev/null` 과 같다
- 보호 목록과 비교하는 값은 셸이 넘기는 값이다. 따옴표를 떼고 구획 문자를 되돌린 값이며, 분해에 쓴 표지가 남지 않는다

### 4-5. 가드 6종

| 순서 | 가드 | 막는 것 | 라벨 |
|---|---|---|---|
| 1 | 보호 브랜치 | 명령 자리의 `git push` 가 보호 브랜치로 가는 것 — refspec 의 오른쪽에서 `+` · `refs/heads/` 를 떼고 비교한다. 목적지가 없으면 그 작업 디렉터리의 현재 브랜치다(`--tags` 는 대체하지 않는다). `--all` · `--mirror` 는 보호 브랜치가 든다고 본다. 보호 브랜치에서의 `git commit` | `protected-branch` |
| 2 | force push | `push` 의 `--force` · `--force-with-lease[=…]` · `--force-if-includes` · 짧은 옵션 묶음의 `f`, `+refspec`, `--delete` · `--mirror` · 묶음의 `d` | `force-push` |
| 3 | 훅 우회 | `push` · `commit` · `merge` · `rebase` 의 `--no-verify`, `commit` 의 짧은 옵션 묶음의 `n`. 값을 받는 옵션의 값은 옵션으로 읽지 않는다 | `no-verify` |
| 4 | 원격 삭제 | 이슈 삭제를 금지한 설정에서 forge CLI 의 `issue` · `mr` · `pr` · `release` · `milestone` 다음 `delete` | `remote-delete` |
| 5 | 보호 문서 셸 편집 | 명령 문자열에 보호 문서 경로가 있고, 그 경로로의 리다이렉션이나 쓰기 명령(`sed -i` · `tee` · `patch` · `dd` · `cp` · `mv` · `rm` · `install` · `truncate`)이 함께 있는 것 | `arch-doc` |
| 6 | write-doc | 명령 자리의 하네스 호출에서 옵션을 걷은 첫 위치 인수가 `write-doc` 이고, 다음 위치 인수의 `.ai/project/<이름>.md` 가 보호 목록에 앞머리부터 맞는 것. 셸이 실행 때 정하는 이름은 판정하지 않는다 | `arch-doc` |

- 판정 값은 `PROTECTED_BRANCHES`(공백으로 나눈 목록) · `BRANCH_PATTERN` · `BASE_BRANCH` · `ISSUE_DELETE_FORBIDDEN` ·
  `FORGE_CLIS` · `ISSUE_LABEL_INVALID` · `PROTECTED_DOCS_RE` 다. 값이 비었거나 없을 때 문구에 쓰는 대체어(`topic` ·
  `the integration branch` · `<topic-branch>` · `invalid`)와, 보호 문서 목록이 비면 5 · 6 을 돌지 않는 것도 현행 그대로다
- 5 는 낱말로 나누지 않은 판정 대상 전체 — 기존 판정 명령, 또는 히어독 본문이 빠진 줄 판정 문자열(4-3) — 를
  정규식으로 본다. POSIX 공백 클래스(`[[:space:]]`)는 유니코드 공백 전부로 옮긴다. 현행 `grep` 의 공백 클래스는 로캘에 따라 다르고, 유니코드 공백은
  어느 로캘의 것보다 좁지 않다. 그 밖의 문자 범위는 ASCII 로 본다
- 차단 문구는 현행 출력과 같다. 계열마다 한 케이스씩 표준 오류 전체를 대조한다 (9-2)

### 4-6. `script/harness.env` 읽기

- `envfile` 이 읽는다. render 가 쓰는 세 형식만 받는다
  - 맨값 — `KEY=값`
  - 홑따옴표 값 — 여러 줄일 수 있고, 안의 `'` 는 `'\''` 로 적혀 있다
  - 겹따옴표 값 — `\\` · `\"` · `` \` `` 를 풀고 `$NAME` · `${NAME}` 을 환경의 값으로 펼친다(없으면 빈 값)
- `#` 로 시작하는 줄과 빈 줄은 건너뛴다
- 파일이 없거나, 일반 파일이 아니거나, 읽지 못하거나, 위 형식이 아닌 줄이 있으면 설정을 읽지 못한 것이다. 가드는
  현행 문구로 차단한다

```
blocked: cannot read the harness config at <루트>/script/harness.env, so the guards cannot run
help: passing everything through without the lists is the same as having no guard — run `harness render` to generate it, then retry
```

- `script/harness-format.sh` 는 `format.py` 가 읽는다 (6절)

## 5. 판정 불변의 범위

### 5-1. 전제

Claude Code 는 훅 입력으로 완전한 JSON 객체 하나를 보내고, 명령은 `tool_input.command` 문자열 한 곳에만 있으며,
문자열에서 `"` · `\` · 제어 문자 · 짝 없는 서로게이트만 이스케이프한다. 줄바꿈 · 탭 · CR · BS · FF 는 `\n` · `\t` · `\r` ·
`\b` · `\f` 로, 그 밖의 제어 문자와 짝 없는 서로게이트는 `\uXXXX` 로 적고, `\/` 나 그 밖의 글자의 `\uXXXX` 를 쓰지 않는다.
줄바꿈 · 탭 · CR 의 표기는 #220 10절의 전제와 같다.
<!-- TBD: 확인 필요 — Claude Code 의 훅 입력 직렬화 -->

이 전제 아래 4-3 의 원문 표기는 셸 가드가 받는 문자열 값과 같다. 그래서 기존 판정 명령과 줄 판정 디코드가 #220 머지 뒤
셸 가드의 것과 글자 하나까지 같고, 판정 문자열 만들기 · 낱말 분해 · 가드는 그 셸의 규칙 그대로다. 따라서 Claude Code 가
보내는 입력에서 셸 가드보다 통과 쪽으로 뒤집히는 판정은 없다.

### 5-2. 셸 가드와 달라질 수 있는 입력

아래 표가 전부다. "셸 가드" 열은 #220 이전에 관측한 값이다. #220 은 값 꺼내기와 기존 판정을 바꾸지 않고(#220 2절 ·
3절), 이 행들은 줄바꿈 · `<<` 가 없어 줄 판정이 돌지 않으므로 #220 머지 뒤 셸 가드도 같은 값이다. 통과 쪽인 행은 모두
Claude Code 가 보내지 않는 형식이고, 4-2 의 "명령을 꺼내지 못하면 통과" 가 적용된다.

| 입력 | 셸 가드 | 이식 뒤 | Claude Code 가 보내는가 |
|---|---|---|---|
| 잘린 JSON `{"tool_input":{"command":"git push origin main"}` | 2 | 0 | 아니다 |
| JSON 이 아닌 글에 `"command":"…"` 가 든 것 | 그 값으로 판정 | 0 | 아니다 |
| `tool_input` 밖의 `command` 키 — `{"command":"git push origin main"}` | 2 | 0 | 아니다 |
| `command` 키가 둘 이상 — `tool_input.command` 는 `git status`, 뒤의 다른 객체에 `"command":"git push origin main"` | 마지막 키로 판정(2) | `tool_input.command` 로 판정(0) | 아니다 |
| 문자열 안에 이스케이프하지 않은 제어 문자 | 그 값으로 판정 | 0 | 아니다 |
| `\/` 와 제어 문자가 아닌 글자의 `\uXXXX` — `git push origin ma\u0069n`, `harness write-doc ro\u006ces/x -` | 풀지 않고 판정(두 예 모두 0) | 풀어서 판정(두 예 모두 2) | 아니다 |
| 보호 문서 쓰기 판정의 공백 자리에 든 유니코드 공백 — `sed` 와 `-i` 사이의 U+3000 | 로캘에 따라 다르다 | 공백으로 본다 | 보낸다. 차단 쪽으로만 달라진다 |

### 5-3. 셸 가드와 같게 지키는 지점

셸 문법 라이브러리나 표준 JSON 처리를 그대로 쓰면 판정이 갈리는 입력이다. 기대값은 #220 머지 뒤 셸 가드의 판정이다 —
#220 5절의 "#220 뒤" 열과 6절의 회귀 케이스 기대값이 그것이다. 전부 회귀 케이스로 고정한다. `<LF>` · `<CR>` · `<TAB>` ·
`<U+00A0>` 는 그 글자 하나다.

#220 이 바꾸지 않는 규칙. 줄바꿈 · `<<` 가 없어 기존 판정만 돈다. 값은 #220 이전 관측과 같다(작업 브랜치에서).

| 입력 | 판정 | 지키는 규칙 |
|---|---|---|
| `git push origin feat#1; git push --force origin feat/1-x` | 2 | `#` 은 주석이 아니다 |
| `echo hi # ; git push origin <보호 브랜치>` | 2 | 같음 |
| `git push --force origin feat/1-x  # don't` | 2 | 닫히지 않은 홑따옴표 뒤도 판정한다 |
| `git push --force origin "feat` | 2 | 닫히지 않은 따옴표 |
| `git push --force origin feat/1-x \` | 2 | 명령 끝의 백슬래시 |
| `git push origin<U+00A0><보호 브랜치>` (작업 브랜치의 임시 리포에서) | 0 | 유니코드 공백은 낱말 경계가 아니다 |
| `git push --force<U+00A0>origin feat/1-x` | 0 | 같음 |

#220 이 정한 줄 판정 규칙(4-3). 줄 판정이 정하는 값이다.

| 입력 | 판정 | 지키는 규칙 |
|---|---|---|
| `echo hi<LF>git push origin <보호 브랜치>` | 2 | 따옴표 밖의 줄바꿈은 구획 구분자 |
| `git status<LF>git push --force origin feat/1-x` | 2 | 같음 |
| `git status<CR><LF>git push --force origin feat/1-x` | 2 | CR 은 낱말 안의 글자이고 줄을 나누는 것은 줄바꿈이다 |
| `git push \<LF>  --force origin feat/1-x` | 2 | 줄 끝 백슬래시는 줄을 잇는다 |
| `git commit -m "a<LF>git push --force origin x"` | 0 | 닫힌 따옴표 안의 줄바꿈은 구분자가 아니다 |
| `echo a\ngit push --force origin feat/1-x` (백슬래시와 `n` 두 글자) | 0 | 글자로 적힌 백슬래시+`n` 은 줄바꿈이 아니다 — 줄 판정이 돌지 않고 기존 판정은 `echo` 한 명령으로 읽는다 |
| `cat <<EOF > out.txt<LF>body<LF>EOF<LF>git push --force origin feat/1-x` | 2 | 종결 줄 다음 줄은 판정한다 |
| `cat <<-EOF<LF><TAB>body<LF><TAB>EOF<LF>git push --force origin feat/1-x` | 2 | `<<-` 는 줄 앞의 탭을 떼고 종결 줄과 비교한다 |
| `cat <<EOF<LF>git push --force origin feat/1-x<LF>EOF` | 0 | 히어독 본문은 판정하지 않는다 |
| `cat <<EOF > <보호 문서><LF>x<LF>EOF` | 2 | 연산자 줄의 나머지는 판정한다 |
| `cat <<EOF; git push --force origin feat/1-x` | 2 | 같음 |
| `git commit -m "$(cat <<'EOF'<LF>body<LF>EOF<LF>)"` | 0 | 명령 치환이 든 큰따옴표 구간에 줄바꿈이 있어 다루지 못하는 구조다 — 줄 판정은 그 큰따옴표 앞에서 멈추고, 기존 판정은 `<<` 에서 자른다 |

두 판정의 합이 정하는 값(#220 5-1 · 5-2 · 5-4). 기존 판정과 줄 판정이 갈리는 입력이다.

| 입력 | 기존 판정 | 줄 판정 | 판정 | 까닭 |
|---|---|---|---|---|
| `git commit -m "a << b" --no-verify` | 0 | 2 | 2 | 따옴표 안의 `<<` 는 히어독이 아니다. 기존 판정은 처음 `<<` 에서 자른다 |
| `echo "a << b"; git push --force origin feat/1-x` | 0 | 2 | 2 | 같음 |
| `echo $((1<<2)); git push --force origin feat/1-x` | 0 | 2 | 2 | 산술 구간 안의 `<<` 는 시프트 연산자다 |
| `cat <<< hi; git push --force origin feat/1-x` | 0 | 2 | 2 | `<<<` 는 히어스트링이다 |
| `git push origin feat\n<보호 브랜치>` (백슬래시와 `n` 두 글자) | 2 | — | 2 | 기존 판정이 백슬래시+`n` 을 백슬래시와 공백으로 읽어 `<보호 브랜치>` 를 목적지로 본다. 줄 판정은 돌지 않는다 |
| `echo "<CR>; git push --force origin x"` (CR 은 JSON 으로 `\r`) | 2 | — | 2 | 기존 판정이 `\r` 을 두 글자로 두어 구간을 풀지 않고 `;` 에서 나눈다 |
| `git push origin<LF><보호 브랜치>` | 2 | 0 | 2 | 기존 판정은 줄바꿈을 공백으로 읽어 한 명령으로 본다 |
| `echo 'a; git push --force origin feat/1-x <<' x` | 2 | 0 | 2 | 기존 판정은 `<<` 에서 잘라 닫히지 않은 따옴표가 되고 `;` 에서 나뉜다 |

줄 판정의 `—` 는 줄바꿈도 `<<` 도 없어 줄 판정이 돌지 않는다는 뜻이다.

- #220 이 `test-bash-guard.sh` 에 넣은 케이스(#220 6절 — 5-1 · 5-2 · 5-3 의 행 전부)도 모두 이 이식의 오라클이다

## 6. 시크릿 스캔 — `harness secret-scan`

- 하네스 루트에서 git 을 부른다. 기준은 HEAD 가 있으면 HEAD, 없으면 git 이 내는 빈 트리(`git hash-object -t tree /dev/null`)
- 기본은 작업 트리, `--staged` 는 인덱스다 — `git diff [--cached] -U0 --no-color --diff-filter=ACMR <기준>`
- 허용 표지는 `src/harness/format.py` 의 `markers(<루트>)` 가 돌려준 `FMT_SECRET_ALLOW` 다. Python 쪽에 표지 문자열을
  적지 않는다
- `markers(root)` 의 정의는 #209 2-1 과 같다
  - 하네스 루트의 `<root>/script/harness-format.sh` 를 실행하지 않고 텍스트로 읽어 `FMT_*` 의 이름과 값을 사전으로 돌려준다
  - `#` 로 시작하는 줄과 빈 줄은 건너뛴다. 나머지 줄은 모두 `FMT_<대문자 · 숫자 · _>='<값>'` 한 줄 대입이다. 값은 두
    홑따옴표 사이의 글자 그대로이고 `'` 를 담지 않는다
  - 파일이 없거나 일반 파일이 아니거나 읽지 못하거나, 위 형식이 아닌 줄이 있으면 그 경로를 적은 `FormatError` 를 낸다
  - CLI 패키지에서 표지를 읽는 곳은 이 함수 하나다. 4-6 의 `envfile` 과 형식 규칙이 다르고 서로 부르지 않는다
- `markers()` 가 `FormatError` 를 내거나, 돌려준 사전에 `FMT_SECRET_ALLOW` 가 없으면 git 을 부르기 전에 표준 오류에
  `error: cannot read the secret allow marker from <루트>/script/harness-format.sh` 한 줄을 내고 2(실행 실패)로 끝난다.
  `FormatError` 의 메시지는 따로 내지 않는다 — 같은 경로가 이 문구에 있다. 2-2 의 예기치 않은 예외로 다루지 않는다
- `format.py` 는 #209 와 이 명세 가운데 먼저 머지되는 쪽이 위 정의로 만들고, 뒤에 머지되는 쪽은 있는 것을 쓴다
- 탐지 규칙은 현행 그대로다 — 발급처를 확정하는 형태 18종, 이름이 자격증명을 가리키는 대입과 그 제외 검사(자리표시자 ·
  구조화된 이름 · `$` 로 시작 · 서로 다른 글자 6개 미만 · 엔트로피 3.0 미만). 줄 번호 계산과 출력 형식 · 문구도 그대로다
- diff 를 UTF-8 로 풀 때 풀리지 않는 바이트는 대체 문자로 바꾼다 — 현행과 같다
- 발견이 있으면 표준 오류로 내고 1. 값을 출력에 옮기지 않는다
- git 이 실패하면 git 의 표준 오류를 그대로 두고 2

## 7. git 훅 본문 — `harness git-hook <훅>`

### 7-1. commit-msg

- 표준 입력을 바이트로 읽어 첫 LF 앞까지를 제목으로 본다. CR 같은 다른 줄 구분 문자에서 자르지 않는다 — 현행 `head -1`
  과 같다
- 제목이 UTF-8 로 풀리지 않으면 형식이 맞지 않는 것으로 거부한다
- `Merge ` · `Revert ` · `fixup!` · `squash!` 로 시작하면 0
- `harness.env` 의 `COMMIT_SUBJECT_RE` 에 맞으면 0
- 아니면 `block commit-msg format` 사용 기록(결과 무시) 뒤 현행 안내문을 내고 1

```
error: commit subject does not match the required form

  expected  <COMMIT_SUBJECT_FORM>
  example   <COMMIT_SUBJECT_EXAMPLE>
  tags      <COMMIT_TAGS_HUMAN>

help: every commit needs an issue number — create the issue first, then commit
```

- `harness.env` 를 읽지 못하면 아래를 내고 1

```
error: cannot read the harness config at <루트>/script/harness.env, so the commit message cannot be checked
help: run `harness render` to generate it, then retry
```

### 7-2. pre-commit

1. 생성물 일치 검사 — `harness --target <루트> check --staged` 와 같은 검사다. 설정 오류를 포함해 0 이 아니면 1
2. 시크릿 스캔 `--staged`(6절). 0 이 아니면 `block pre-commit secret-scan` 사용 기록(출력 · 실패 버림) 뒤 1
3. 0

두 검사의 출력은 현행처럼 그대로 보인다. `harness.env` 는 읽지 않는다.

### 7-3. pre-push

1. 표준 입력의 줄마다 `<로컬 ref> <로컬 sha> <원격 ref> <원격 sha>` 로 나눠 로컬 sha 를 모은다. 원격 ref 가
   `PROTECTED_BRANCHES` 의 어느 이름에 `refs/heads/` 를 붙인 것과 같으면 `block pre-push protected-branch` 사용 기록 뒤
   아래를 내고 1

   ```
   blocked: <원격 ref> is a protected branch — direct push is not allowed
     open a review request from a <BRANCH_PATTERN> branch onto <BASE_BRANCH> instead
   ```

2. `VERIFY_PRE_PUSH` 가 `1` 이면 push 전 검증을 현행 순서와 문구 그대로 돈다 — `script/run-lint-test.sh` 가 실행 가능한가,
   보내는 리비전(지우는 ref 는 빼고, 주석 태그는 가리키는 커밋으로)이 체크아웃한 HEAD 인가, 작업 트리가 깨끗한가,
   `script/run-lint-test.sh` 를 표준 입력을 비우고 돌려 통과하는가, 검증 뒤에도 작업 트리가 깨끗한가. 하나라도 아니면
   `block pre-push verify` 사용 기록(출력 · 실패 버림) 뒤 사유 두 줄을 내고 1
3. 0

- `harness.env` 를 읽지 못하면 아래를 내고 1

```
blocked: cannot read the harness config at <루트>/script/harness.env, so the push cannot be checked
help: run `harness render` to generate it, then retry
```

- 검증 일괄은 `script/run-lint-test.sh` 를 부른다. 그 스크립트의 이식은 #213 이 맡는다

## 8. 실패 정책

### 8-1. 지점별

| 지점 | CLI 를 찾지 못함 | CLI 를 띄우지 못함(python3 없음 · 3.11 미만) | 예기치 않은 예외 | 설정을 읽지 못함 |
|---|---|---|---|---|
| 명령 가드 — 훅 명령 · `script/hooks/bash-guard.sh` | 1, 3-2 의 두 줄 — 통과 | 2 가 아닌 코드 — 통과 | 1, 오류 한 줄 — 통과 | 2, 4-6 의 문구 — 차단 |
| commit-msg | 1 — 거부 | 0 이 아닌 코드 — 거부 | 1 — 거부 | 1 — 거부 |
| pre-commit | 0 — 통과(생성물 검사와 시크릿 스캔을 모두 건너뛴다) | 0 이 아닌 코드 — 거부 | 1 — 거부 | 해당 없음 |
| pre-push | 1 — 거부 | 0 이 아닌 코드 — 거부 | 1 — 거부 | 1 — 거부 |
| `script/secret-scan.sh` · `harness secret-scan` | 2 | 0 이 아닌 코드 | 2 | 표지를 읽지 못하면 2 |

### 8-2. 현행과 다른 지점

| 지점 | 현행 | 이식 뒤 | 방향 |
|---|---|---|---|
| python3 3.11 이상이 없는 기기의 명령 가드 | 셸만으로 판정한다 | 가드가 돌지 않는다 | 통과 쪽 |
| CLI 를 찾지 못한 pre-commit | 생성물 검사만 건너뛰고 시크릿 스캔은 돈다 | 둘 다 건너뛴다 | 통과 쪽 |
| CLI 를 찾지 못한 commit-msg · pre-push | 셸만으로 검사한다 | 거부한다 | 거부 쪽 |
| `script/harness.env` 를 읽지 못한 commit-msg · pre-push | 생성 때 박힌 값으로 검사한다 | 거부한다 | 거부 쪽 |
| `script/secret-scan.sh` 가 없는 설치본의 pre-commit | 시크릿 스캔을 건너뛴다 | 스캔한다 | 거부 쪽 |
| `script/harness-format.sh` 가 없을 때의 시크릿 스캔 | 1 | 2 | 둘 다 거부 |
| 시크릿 스캔의 git 실패 | git 의 종료 코드 | 2 | 둘 다 거부 |
| python3 가 없는 기기의 `script/secret-scan.sh` | 2 | CLI 를 띄우지 못한 코드 | 둘 다 0 이 아니다 |

## 9. 회귀 테스트

### 9-1. 판정 기준과 순서

- 오라클은 기존 셸 테스트(`test-bash-guard.sh` · `test-secret-scan.sh` · `render-test.sh` 의 훅 · 가드 케이스) 검사 줄의
  기대값(종료 코드 · 출력)과 5-2 · 5-3 의 표다. #220 이 넣은 케이스가 여기 든다
- 배치에 기대는 준비부 수정(9-2 · 9-3), 5-3 의 케이스, 차단 문구 대조는 새 구현보다 먼저 들어가 **옛 구현(#220 머지 뒤 셸 가드)에서 통과**한다
- 셸 테스트에서 옮기거나 지운 검사 줄은 리뷰 요청 본문에 줄 단위 대응표(그 검사를 받는 단위 테스트)로 남긴다
- 셸 테스트는 대상 리포에 깔리는 계약 테스트로 남는다

### 9-2. `test-bash-guard.sh`

| 바꾸는 곳 | 내용 |
|---|---|
| 입력 만들기 | Claude Code 와 같은 모양의 입력을 만든다 — `json.dumps({"tool_name": "Bash", "tool_input": {"command": <명령>}}, ensure_ascii=False)`. 따옴표 · 백슬래시 · 제어 문자만 이스케이프된다. 줄바꿈 · CR · 탭이 `\n` · `\r` · `\t` 가 되는 것은 #220 6-1 의 `probe` 와 같다. 그 밖의 제어 문자는 `json.dumps` 가 `\b` · `\f` · `\uXXXX` 로 적고 `probe` 는 그대로 두지만, #220 6절의 케이스에는 그런 글자가 없다 |
| 부르는 곳 | 루트의 `.claude/settings.json` 훅 명령을 `CLAUDE_PROJECT_DIR=<루트>` 로 `sh -c` 해 종료 코드를 본다 |
| 임시 루트 | 하네스가 지키는 임시 리포(작업 트리 · 다른 리포 · 공백 경로 · 구획 문자 보호 목록)는 `script/harness.env`(또는 값을 바꾼 사본), 루트의 `script/hooks/` 사본, 테스트를 부른 루트의 CLI 를 가리키는 심볼릭 링크 `.harness/bin/harness` 를 갖는다. 옛 구현과 새 구현이 같은 배치로 돈다 |
| 더하는 케이스 | 5-3 의 표 가운데 #220 이 넣지 않은 것 전부(기대값은 5-3 의 값, 곧 #220 5절의 "#220 뒤" 값). 계열(보호 브랜치 push · `--all` · commit, force push · `+refspec` · 삭제, `--no-verify` · `commit -n`, 원격 삭제, 보호 문서, write-doc, 설정 없음)마다 한 케이스씩 표준 오류 전체를 현행 문구와 대조 |
| 단위 테스트로 옮기는 검사 | `_guards.sh` 를 읽어 함수를 바꿔 끼우는 검사(비교 값에 자리표가 남지 않음), 가드 하나를 망가뜨린 사본 검사 둘(force push · write-doc) |

케이스 표와 기대값은 그대로다.

### 9-3. `test-secret-scan.sh`

- 임시 리포에 `script/secret-scan.sh` · `script/harness-format.sh` 사본과, 테스트를 부른 루트의 CLI 를 가리키는 심볼릭 링크
  `.harness/bin/harness` 를 둔다. 옛 구현과 새 구현이 같은 배치로 돈다
- UT-07 에 다른 명령의 옵션(`--purge`)이 종료 코드 2 인 케이스를 더한다
- 기대값은 그대로다

### 9-4. 단위 테스트 — `src/test/unit/`

#206 이 둔 단위 테스트 기반 — #206 7-5 의 자리 · 실행 명령 · 스모크 테스트(`test_commands.py`)와 #206 6절의 "Python 단위
테스트" 단계 — 에 파일을 더한다. 그 넷은 #206 이 정한 그대로 쓴다. 스모크 테스트가 세 명령의 명령 모듈과 `COMMANDS` 항목
모양(첫 원소 `True`)도 본다. 그 규칙대로 CLI 를 하위 프로세스로 띄우지 않고, 명령 진입 함수와 가드 함수를
프로세스 안에서 부른다. 새 프로세스가 있어야 보는 것(가드 경로의 import)은 `render-test.sh` 가 본다 (9-5).

| 대상 | 확인하는 것 |
|---|---|
| 차단 · 통과 표 | `test-bash-guard.sh` 와 같은 계열의 차단 케이스와 통과 케이스(#220 6-2 · 6-4 가 더한 행 포함)를 가드에 직접 돌린다. 판정 값은 고정한 `harness.env` 견본에서 온다 |
| 가드 하나를 끈 사본 | force push 가드만 끄면 force 계열(#220 6-2 가 더한 행 포함)만 통과로 뒤집히고 나머지 계열은 차단 그대로다. 두 판정이 같은 가드 함수를 부르므로 두 판정에서 함께 꺼진다. write-doc 가드도 같다 |
| 비교 값 | 셸 테스트에서 옮겨 오는 인용 섞인 명령 일곱(구획 문자가 든 인용 목적지, 인용 목적지 둘, 빈 따옴표가 붙은 refspec, 공백 · 물결표가 든 인용 목적지, 인용된 `-C` 경로, 인용된 `cd` 경로, 빈 따옴표 목적지)에서 보호 목록과 비교된 값이 셸이 넘기는 값이고 제어 문자가 없다 |
| 입력 해석 | 5-2 의 행마다 이식 뒤 판정. 명령이 없거나 문자열이 아니거나 빈 입력이면 0 이고 `harness.env` 없이도 0 이다 |
| 원문 표기 | 4-3 의 되살리기가 9-2 의 `json.dumps` 표기와 같다 — 따옴표 · 백슬래시 · 줄바꿈 · 탭 · CR · BS · FF · 그 밖의 제어 문자 · 짝 없는 서로게이트 |
| 기존 판정 명령 (#220 3절) | 순차 치환의 성질 — 글자로 적힌 백슬래시+`n` 과 줄 끝 백슬래시가 백슬래시와 공백이 되고, `\r` · `\b` · `\f` · `\uXXXX` 는 적힌 그대로 남는다 — 과 처음 `<<` 에서 자르기(따옴표 안 · `<<<` 포함) |
| 줄 판정 디코드 (#220 4-1) | 표의 행마다 — `\"` · `\\` · `\n` · `\t` · `\r` 은 한 번만 풀리고 그 밖은 적힌 그대로다. 글자로 적힌 백슬래시+`n` 은 두 글자다 |
| 판정 문자열 (#220 4-2) | 표의 행마다 — `'…'` · `"…"` · `$'…'` · 닫히지 않은 따옴표 · 따옴표 밖 백슬래시+줄바꿈 · 백슬래시+다른 글자 · 따옴표 밖 줄바꿈 · `<<<` · 산술 구간인 `$((` · `((` 와 아닌 것 · `$(` · 백틱. 결과에 줄바꿈이 없다 |
| 히어독 (#220 4-3) | 구분어가 끝나는 글자와 따옴표 · 백슬래시 떼기, `<<-` 의 탭 떼기, 한 줄의 연산자 여럿, 종결 줄이 없는 본문, CR 로 끝나는 줄, 본문이 빠진 문자열을 보호 문서 가드가 보는 것 |
| 다루지 못하는 구조 (#220 4-4) | 다섯 행마다 판정 문자열이 그 자리 앞까지만 만들어지고, 기존 판정은 명령 전체를 그대로 판정한다 |
| 두 판정의 합 (#220 2절) | 줄바꿈도 `<<` 도 없으면 줄 판정이 돌지 않는다. 두 판정이 모두 막으면 사유는 기존 판정의 것이다. 5-3 의 "두 판정의 합" 표의 행마다 판정이 같다 |
| 무예외 | 고정한 시드로 만든 임의 명령 문자열(따옴표 · 백슬래시 · `\|;&` · `<<` · `#` · `$(` · 백틱 · 공백 · 유니코드 공백 · 제어 문자를 섞은 것)에서 예외 없이 0 또는 2 |
| 설정 해석 없음 | `harness.toml` 이 깨진 TOML 인 루트에서도 가드의 판정과 문구가 같다 |
| 예외 정책 | 가드 하나가 예외를 내면 종료 코드 1, 표준 오류는 `error: the command guard stopped` 로 시작하는 한 줄이고 트레이스백이 없다 |
| `envfile` | 세 형식, 여러 줄 홑따옴표, `'\''`, 겹따옴표의 `$HOME` · `${HOME}`, 주석 · 빈 줄. 형식이 아닌 줄 · 디렉터리 · 없는 파일은 읽지 못한 것이다 |
| `format.py` 의 `markers()` | `test_format.py` 는 #209 8-5 가 정한 내용 그대로이고 `format.py` 를 만드는 쪽이 함께 둔다. 이 명세가 더하는 것: `markers()` 가 읽은 `FMT_SECRET_ALLOW` 가 `harness:allow-secret` 이다 |
| secret-scan 표지 실패 | 표지 파일이 없을 때, 형식이 아닌 줄(`FMT_X=$(…)`)이 있을 때(`FormatError`), `FMT_SECRET_ALLOW` 줄만 뺀 견본일 때 각각 종료 코드 2 이고 표준 오류는 6절의 한 줄뿐이다. 형식이 아닌 줄의 명령은 실행되지 않는다 |
| 인자 통과 | 세 명령 각각 `--target R <명령>` 과 `<명령> --target R` 이 `parse_command_line()` 에서 같은 루트와 인자로 나뉜다. 명령의 인수 검사에서 `git-hook pre-push --target R` 은 2, `bash-guard x` 는 1 |
| commit-msg | 제목은 첫 LF 앞까지다(CR 이 남은 제목은 맞지 않는다). `Merge ` 등 네 접두는 0. UTF-8 이 아닌 제목은 거부 |
| pre-push | ref 줄 나누기, 보호 브랜치 비교는 정확히 같은 이름만, `VERIFY_PRE_PUSH=0` 이면 검증을 돌지 않는다 |
| secret-scan 인수 | `--stage` · `--purge` · `--staged --target R` · 남는 위치 인수는 2 |

### 9-5. `render-test.sh`

생성 파일 내용을 찾던 단언을 같은 기대값의 동작 단언으로 바꾼다.

| 블록 | 지금의 단언 | 바꾼 단언 |
|---|---|---|
| UT-02 | commit-msg 파일에 접두 형식 검사식 · 안내 예시가 있고 접미 형식 문구가 없다 | `[BD-123] feat: x` 제목을 commit-msg 에 넣으면 0, `feat: x(#1)` 은 1 이고 표준 오류에 `[BD-123] feat: short summary` 가 있고 `(#{issue})` 가 없다. `harness.env` 단언은 그대로 |
| UT-03 | pre-push 파일에 새 보호 브랜치가 있고 옛 것이 없고 안내문이 따라왔다 | pre-push 에 `refs/heads/trunk` 줄을 넣으면 1 이고 `onto develop instead` 가 나온다. `refs/heads/main` 줄은 보호 브랜치로 막지 않는다 |
| UT-07b | pre-push 파일에 통합 브랜치가 있다 | pre-push 가 `refs/heads/development` 줄을 막는다 |
| UT-22 | pre-push 파일에 바꾼 값이 있다 | pre-push 가 `refs/heads/develop` 줄을 막는다 |
| UT-101 | pre-push 파일에 `run-lint-test.sh` 가 있다 · 없다 | `harness.env` 의 `VERIFY_PRE_PUSH` 가 `1` · `0` 이다. 끈 뒤 더러운 작업 트리에서 pre-push 가 0 이다 |
| UT-72 | 훅 명령이 `$CLAUDE_PROJECT_DIR/script/hooks/bash-guard.sh` 다 | 훅 명령이 3-1 의 한 줄과 같다. `sh -c` 로 돌린 판정 단언은 그대로 |

새 블록:

| 케이스 | 확인하는 것 |
|---|---|
| 훅 명령 | 설치한 리포와 소스 트리 복제본의 `.claude/settings.json` 훅 명령이 3-1 의 한 줄이다. 소스 트리 복제본에서 그 명령이 보호 브랜치 push 를 막는다 |
| CLI 없음 | 설치한 리포에서 `.harness/bin/harness` 를 치우면 commit-msg 는 1, pre-push 는 1, pre-commit 은 0, 훅 명령과 `script/hooks/bash-guard.sh` 는 1(2 가 아니다), `script/secret-scan.sh` 는 2. pre-commit 을 뺀 다섯 곳의 표준 오류가 `error: harness CLI not found under <루트> (.harness/bin/harness or src/bin/harness)` 와 `help: harness install --target <루트>` 두 줄이다 |
| 설정 없음 | `script/harness.env` 를 치우면 commit-msg · pre-push 는 1 과 그 문구, 훅 명령은 2 와 4-6 의 문구 |
| 옛 경로의 shim | `script/hooks/bash-guard.sh` 가 보호 브랜치 push 를 막고(2), `script/secret-scan.sh --staged` 가 스테이징한 견본을 잡는다(1) |
| 옛 가드 파일 정리 | `.harness/managed` 에 `script/hooks/_guards.sh` 가 있는 설치본을 render 하면 그 파일이 지워진다. 새 설치에는 없다 |
| 모노레포 | 서브프로젝트의 commit-msg 훅이 그 서브프로젝트의 CLI 로 형식을 검사한다 |
| 가드 경로의 import | 설치한 리포에서 `python3 -X importtime .harness/bin/harness --target <루트> bash-guard` 를 차단 입력과 통과 입력으로 한 번씩 돌리면, 표준 오류의 import 기록에 `urllib` · `http` · `harness.render` · `harness.metrics` 가 없다 (2-3) |

기존 UT-61(설치된 `script/test-*.sh` 전부)과 UT-34(pre-commit 의 시크릿 스캔)는 그대로 통과한다.

## 10. 생성 파일과 문서

### 10-1. 생성

- `settings_json()` 의 훅 명령 — 3-1
- `script/githooks/{commit-msg,pre-commit,pre-push}` 템플릿 — 3-2 의 shim. `PRE_PUSH_VERIFY` 블록은 생성 모듈에서 빠지고
  7-3 의 본문이 된다
- `derive()` 에 `VERIFY_PRE_PUSH` — `harness.env` 로 간다
- README "harness.toml 이 정하는 것" 의 `commit.tags` · `verify.pre_push` 행은 뜻이 같아 그대로다

### 10-2. 문서

| 문서 | 고칠 것 |
|---|---|
| `README.md` 명령 표 | `harness bash-guard`(Claude Code 의 명령 가드 훅 본문. `.claude/settings.json` 이 부른다) · `harness secret-scan [--staged]`(더한 줄의 자격증명 검사. 사람은 `script/secret-scan.sh` 로 부른다) · `harness git-hook <훅>`(git 훅 본문. `script/githooks/` 가 부른다) 세 줄 |
| `src/templates/managed/script/README.md` | 목록 표의 `secret-scan.sh` · `hooks/bash-guard.sh` 행을 CLI 로 넘기는 shim 으로 고치고 `hooks/_guards.sh` 행을 지운다 |
| `src/templates/managed/docs/workflow/changing.md` | "가드 판정" 행을 하네스 리포의 `src/harness/guard/` + 테스트 케이스로 |
| `src/templates/vendors.toml` | `hooks` 주석의 `(bash-guard.sh)` 를 `(harness bash-guard)` 로 |
| `test-bash-guard.sh` 머리글 | 가드 하나를 망가뜨린 사본 검사 서술을 지운다(단위 테스트로 옮겼다) |
| `docs/spec/71-issue-worktree-run.md` 4절 | 명령 가드 줄: 훅 명령은 `$CLAUDE_PROJECT_DIR` 아래의 CLI(`.harness/bin/harness`, 없으면 `src/bin/harness`)로 `--target "$CLAUDE_PROJECT_DIR" bash-guard` 를 부른다 |
| `docs/spec/62-unify-ui-writes-through-cli.md` | 정본 위치 표의 `write-doc` 명령 가드 행을 `src/harness/guard/` 로, 6-1 첫 문장을 "가드 순서 목록에서 보호 문서 셸 편집 다음에 돈다" 로 |
| `docs/spec/70-generate-permission-allow-list.md` | `hooks.PreToolUse` 줄의 괄호를 `harness bash-guard` 로 |

`docs/spec/58-…` 의 doctor 출력 예시(`script/hooks/_guards.sh  missing managed file`)는 예시라 그대로 둔다. 이 리포의
`script/` · `docs/workflow/` 사본은 render 가 따라 바꾼다.

## 11. 이행

- #220 이 머지된 뒤에 착수한다. 그 머지가 넣은 셸 가드와 케이스가 이 이식의 오라클이다
- 진입점(훅 명령 · git 훅 shim · 옛 경로의 shim)을 새 명령으로 돌리는 변경은 세 하위 명령이 들어간 뒤에 오고, 한
  커밋에서 함께 바뀐다. 어느 커밋에서도 가드와 훅이 돈다
- `script/hooks/_guards.sh` 는 진입점을 돌리는 커밋에서 관리 파일 목록에서 빠진다
- 이 리포는 자기 가드 아래에서 이 변경을 만든다. 진입점이 바뀐 뒤 떠 있던 세션은 옛 경로의 shim 을 거친다 (3-3)

## 12. 보호 문서 개정 범위

이 이슈 범위에서 사용자가 일괄 허용한 개정이다. 구현 단계의 task 하나가 이 범위 안에서만 고치고 render 한다.

### 12-1. `.ai/project/architecture.md`

| 위치 | 반영할 사실 |
|---|---|
| "구성 요소" 의 `src/harness/` 항목(#206 이 더한 CLI 패키지 항목) | 덧붙인다: 명령 가드 · 시크릿 스캔 · git 훅 본문도 CLI 하위 명령이다 — `bash-guard`(Claude Code `PreToolUse(Bash)` 훅) · `secret-scan` · `git-hook <commit-msg\|pre-commit\|pre-push>`. 코드는 `src/harness/guard/` · `src/harness/hooks.py` 이고, `script/harness.env` 읽기는 `src/harness/envfile.py`, 표지(`script/harness-format.sh`) 읽기는 `src/harness/format.py` 다 |
| "구성 요소" 의 대상 리포 `script/` 항목 | "가드(`hooks/`)·시크릿 스캔" 을 "명령 가드 · 시크릿 스캔의 shim(`hooks/bash-guard.sh` · `secret-scan.sh` — CLI 로 넘긴다)" 으로. 덧붙인다: `githooks/` 는 CLI 를 찾아 `git-hook` 으로 넘기는 생성 shim 이다 |
| "데이터 흐름" | 새 항목 "가드 · 훅": Claude Code `PreToolUse(Bash)` → `.claude/settings.json` 의 훅 명령 → 하네스 루트의 CLI(`.harness/bin/harness`, 없으면 `src/bin/harness`) `bash-guard` → `script/harness.env` 의 값으로 판정(0 통과 · 2 차단). git → `script/githooks/<훅>` → 같은 CLI 의 `git-hook <훅>` |
| "신뢰 경계" 의 들어오는 입력 | "도구 호출 JSON(`script/hooks/bash-guard.sh`)" 을 "도구 호출 JSON(`harness bash-guard`)" 으로 |
| "새 코드를 둘 곳" 의 새 가드 | "새 가드 → `src/harness/guard/` 의 가드 함수와 가드 순서 목록 + `test-bash-guard.sh` 케이스 + `src/test/unit/` 의 단위 테스트. 판정에 쓰는 값은 `script/harness.env` 로 받는다" 로 바꾼다 |
| "새 코드를 둘 곳" | 새 항목: "git 훅 본문 → `src/harness/hooks.py`. `script/githooks/*` 는 CLI 를 찾아 넘기는 shim 으로만 둔다" |

Python 단위 테스트 층의 기본 문장 — architecture "구성 요소" 의 `src/test/render-test.sh` 항목과 "새 코드를 둘 곳" 의
새 회귀 테스트에 더하는 `src/test/unit/` 문장, testing.md 의 Python 단위 테스트 항목 — 은 #206 9절이 쓴다. 이 명세는
그 문장을 다시 쓰지 않고 가드에 관한 것만 더한다.

### 12-2. `.ai/project/testing.md`

| 위치 | 반영할 사실 |
|---|---|
| "무엇을 어느 수준으로 검증하나" 의 Python 단위 테스트 항목(#206 9절이 더한 것) | 끝에 덧붙인다: 명령 가드는 셸 테스트가 보지 못하는 것 — 가드 하나를 끈 사본에서 그 계열만 통과로 뒤집히는지, 보호 목록과 비교되는 값이 셸이 넘기는 값인지, 임의 입력에서 예외가 나지 않는지 — 를 단위 테스트로 본다. 가드 경로가 설정 해석 · 생성 · 지표 모듈을 불러오지 않는지는 `render-test.sh` 가 새 프로세스로 본다 |

`glossary.md` · `scope.md` 는 고치지 않는다.

## 13. 한계

- #220 의 한계(#220 10절)를 그대로 물려받는다
  - 명령 치환 안의 히어독과 다루지 못하는 큰따옴표 구간 뒤의 명령은 판정하지 못한다. 줄 판정은 그 자리에서 멈추고, 기존
    판정은 처음 `<<` 에서 자르거나 줄을 한 명령으로 읽는다. Claude Code 커밋 관용형 `git commit -m "$(cat <<'EOF' … EOF<LF>)"`
    뒤의 `&& git push --force …` 나 다음 줄의 명령이 여기 든다. 다루지 못하는 다른 구조 — 같은 줄 안에서 닫히지 않는
    산술 구간, 구분어가 빈 히어독 연산자 — 뒤도 같다
  - `#` 을 주석으로 보지 않으므로 주석 안의 따옴표가 뒤 줄의 따옴표와 짝지어지면 그 사이의 줄을 판정하지 못한다
  - 판정 문자열 만들기가 따로 다루지 않는 구조 안의 `<<`(매개변수 확장 `${…}` 안 등)는 히어독 연산자로 읽혀, 종결 줄로
    읽힌 줄까지 판정하지 못한다
  - 기존 판정이 내는 차단은 셸이 그렇게 실행하지 않는 해석이어도 남는다 — `git push origin<LF><보호 브랜치>` 는 셸이
    `<보호 브랜치>` 로 push 하지 않지만 막힌다
  - 줄바꿈이나 `<<` 가 든 명령은 가드 6종을 두 번 돈다
- python3 3.11 이상이 없는 기기에서는 명령 가드가 돌지 않는다(8-2)
- CLI 를 찾지 못한 pre-commit 은 시크릿 스캔도 건너뛴다(8-2)
- Claude Code 가 보내지 않는 형식의 입력은 통과한다(5-2). 5-1 의 전제가 틀리면 그 표가 늘어난다
- `.claude/settings.json` 의 훅 명령을 손으로 고쳐 명령 이름 앞에 `--target` 말고 다른 옵션을 넣거나 `--target` 을
  이름 앞과 바로 뒤에 모두 두면, #206 3-3 의 인자 해석이 종료 코드 2 로 끝나 모든 명령이 막힌다. 그 밖에 이름 뒤에
  넣은 인수는 `bash-guard` 가 받아 1(통과)로 끝난다. 생성 파일이라 `check` 가 잡는다
- 히어독 본문 안의 명령은 판정하지 않는다(4-3)
- 가드 · 훅의 설정 출처는 `script/harness.env` 다. 그 파일과 shim 을 걷는 #221 이 출처를 함께 바꾼다
