# 명령 가드·시크릿 스캔·git 훅 본문의 Python 이식

명령 가드(Claude Code `PreToolUse(Bash)` 훅), 시크릿 스캔, git 훅(commit-msg · pre-commit · pre-push)의 본문이
하네스 패키지(`src/harness/`)의 CLI 하위 명령으로 옮겨 간다. 외부 계약을 유지하는 이식이다 — **Claude Code 가
보내는 입력에 대한 판정은 통과 쪽으로 하나도 뒤집히지 않고**, 차단 사유 문구 · 종료 코드 · 사용 기록이 그대로다.
셸 가드와 판정이 달라질 수 있는 입력은 5-2 의 표가 전부다.

기준 코드는 #206 의 패키지 배치(`src/harness/`, 명령마다 `commands/` 모듈 하나, 고정 사본 `.harness/lib/harness/`)가
들어가고, #220 의 셸 가드 수정(여러 줄 명령과 최상위 히어독 판정)이 머지된 통합 브랜치다. 선행은 #206 과 #220 이다.
이 명세에서 "현행" 과 "셸 가드" 는 #220 이 머지된 뒤의 셸 구현을 말한다.

근거 결정 기록은 0011(터미널 출력은 영어) · 0012(시크릿 스캔은 더한 줄만 본다) · 0013(소스 리포는 사본 없이
`src/bin/harness` 로 돈다)과 "하네스 로직은 Python 표준 라이브러리 패키지 하나에 둔다"(#206 분해에서 작성)다.
이 명세가 새로 요구하는 결정 기록은 없다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 명령 가드 — 입력 해석 · 명령 정리 · 낱말 분해 · 가드 6종 | `src/harness/guard/` |
| 시크릿 스캔 | `src/harness/guard/` 의 시크릿 스캔 모듈 |
| git 훅 본문 | `src/harness/hooks.py` |
| 셸 대입 파일 읽기(`script/harness.env` · `script/harness-format.sh`) | `src/harness/envfile.py` |
| 명령 등록과 명령 모듈 | `COMMANDS` · `DELEGATES` 와 `src/harness/commands/` 의 `bash_guard` · `secret_scan` · `git_hook` |
| 생성 — 훅 명령 · git 훅 shim · `harness.env` 의 새 키 | #206 의 생성 모듈(`settings_json()` · `derive()` · `plan()`)과 `src/templates/generated/script/githooks/` |
| 호환 shim | `src/templates/managed/script/hooks/bash-guard.sh` · `src/templates/managed/script/secret-scan.sh` |
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
- 파일 부류 — `script/githooks/*` 는 생성, 호환 shim 둘은 관리
- Codex 에는 훅을 연결하지 않는다(`vendors.toml` 의 `hooks = false`)
- doctor 의 `no command guard for <오케스트레이터>` 항목과 그 설명, UI Doctor 문구
- 결정 기록 본문. 0012 · 0013 의 `script/…` 경로 표기는 그 시점의 관측이다

바뀌는 것:

- CLI 에 하위 명령 셋이 생긴다 — `bash-guard` · `secret-scan` · `git-hook` (2절)
- `.claude/settings.json` 의 `PreToolUse` 훅 명령이 하네스 루트의 CLI 를 부른다 (3-1)
- `script/githooks/` 의 commit-msg · pre-commit · pre-push 가 CLI 를 찾아 `git-hook` 으로 넘기는 shim 이다 (3-2)
- `script/hooks/bash-guard.sh` · `script/secret-scan.sh` 가 CLI 로 넘기는 호환 shim 이다 (3-3)
- `script/hooks/_guards.sh` 가 관리 파일 목록에서 빠진다. 다음 render · install 의 정리가 대상 리포에서 지운다 — 관리
  파일 목록에서 빠진 경로는 수정 여부와 상관없이 지우고, 매니페스트에 없는 파일은 건드리지 않는 기존 정리 규칙이다
- `script/harness.env` 에 `VERIFY_PRE_PUSH`(`1` · `0`)가 생긴다. `verify.pre_push` 의 값이다

## 2. 하위 명령

### 2-1. 등록

| 이름 | 인수 | `harness help` 설명 | 설정 필요 |
|---|---|---|---|
| `bash-guard` | (없음) | `PreToolUse(Bash) hook: read the tool call JSON on standard input and block a command the guards forbid (exit 2)` | 아니오 |
| `secret-scan` | `[--staged]` | `look for credentials in the lines being added (exit 1 when found)` | 아니오 |
| `git-hook` | `<commit-msg\|pre-commit\|pre-push>` | `run a git hook body; script/githooks/ calls this` | 아니오 |

- 셋 다 `DELEGATES` 에 든다. 전역 CLI 로 부르면 대상 리포의 고정 사본이 답한다
- 하네스 루트는 `--target DIR`(기본 현재 디렉터리)이다. 판정 값 · 표지 · 사용 기록 스크립트를 그 아래에서 찾는다
- **작업 디렉터리를 옮기지 않는다.** 가드의 상대 경로 · 브랜치 판정과 commit-msg · pre-push 의 git 명령은 프로세스의
  작업 디렉터리에서 돈다. 시크릿 스캔의 git 만 하네스 루트에서 돈다(6절) — 현행 스크립트와 같다
- 문구에 나오는 `<루트>` 는 `--target` 을 심볼릭 링크를 풀지 않고 절대 경로로 만든 것이다 — 현행 `cd … && pwd` 와 같다
- `--target` 말고 경로 인수를 받지 않는다. commit-msg 의 메시지는 표준 입력으로 받는다 (3-2)
- 인수 검사
  - `secret-scan` 은 `--staged` 와 `--target DIR` 말고 아무것도 받지 않는다. 줄여 쓴 옵션(`--stage`) · 다른 명령의
    옵션(`--purge` 등) · 남는 위치 인수는 `error: unknown option: <인수>` 와 `usage: harness secret-scan [--staged]` 를
    내고 종료 코드 2
  - `git-hook` 은 훅 이름 하나만 받는다. 없거나 모르는 이름이거나 남는 인수가 있으면
    `usage: harness git-hook <commit-msg|pre-commit|pre-push>` 를 내고 종료 코드 2
  - `bash-guard` 는 위치 인수가 있으면 판정하지 않고 `usage: harness bash-guard` 를 내고 종료 코드 1 — 2 는 차단이라
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

- 진입 스크립트부터 판정까지 불러오는 모듈은 표준 라이브러리의 `json` · `os` · `re` · `subprocess` · `sys` 수준과
  하네스 패키지의 CLI 진입 · 가드 모듈 · `envfile` 이다
- `tomllib` · `urllib` · `http` 와 설정 해석 · 생성 · 지표 모듈을 불러오지 않는다
- 가드는 사용 기록 호출 말고 아무것도 쓰지 않는다

## 3. 진입점

### 3-1. `.claude/settings.json` 의 훅 명령

`hooks.PreToolUse[0]` 의 `matcher` 는 `Bash` 그대로이고, 그 `hooks[0].command` 가 아래 한 줄이다.

```sh
for c in "$CLAUDE_PROJECT_DIR/.harness/bin/harness" "$CLAUDE_PROJECT_DIR/src/bin/harness"; do [ -x "$c" ] && exec "$c" bash-guard --target "$CLAUDE_PROJECT_DIR"; done; echo "warning: no harness CLI found (.harness/bin/harness, src/bin/harness), so the command guard did not run" >&2; exit 1
```

- 고정 사본의 CLI 를 먼저 찾고, 없으면 소스 리포의 CLI 를 쓴다(0013). 대상 리포와 소스 리포의 생성물이 같다
- 둘 다 없으면 한 줄을 내고 1 로 끝난다. 통과다
- POSIX 셸 문법(`for` · `[ -x ]` · `&&` · `exec`)을 쓴다. Claude Code 가 훅 명령을 POSIX 셸로 실행한다는 전제다
  <!-- TBD: 확인 필요 — 훅 명령을 실행하는 셸 -->
- worktree 에서는 `$CLAUDE_PROJECT_DIR` 가 worktree 이므로 worktree 의 CLI 가 worktree 의 `script/harness.env` 로 판정한다

### 3-2. git 훅 shim — `script/githooks/{commit-msg,pre-commit,pre-push}`

셋 다 생성 파일이고 내용에 설정 값이 들어가지 않는다. 템플릿 변수(`{{COMMIT_SUBJECT_RE}}` · `{{PROTECTED_REF_CASE}}` ·
`{{PRE_PUSH_VERIFY}}` 등)를 쓰지 않는다. 각 파일이 하는 일:

1. 하네스 루트를 현행과 같이 잡는다 — 자기 위치의 `../..`, 거기에 `script/harness.env` 가 없으면
   `git rev-parse --show-toplevel`
2. 루트가 있으면 `<루트>/.harness/bin/harness`, `<루트>/src/bin/harness` 순으로 실행 가능한 첫 CLI 에
   `exec <CLI> git-hook <훅> --target <루트>` 한다
   - commit-msg 는 git 이 넘긴 메시지 파일을 표준 입력으로 연결한다(`< "$1"`)
   - pre-push 는 git 이 표준 입력으로 준 ref 줄을 그대로 물려준다. 원격 이름 · URL 인수는 넘기지 않는다
   - pre-commit 은 인수가 없다
3. CLI 를 찾지 못하면 아래처럼 끝난다. 사용 기록은 남기지 않는다 — 규칙 위반이 아니라 하네스가 없는 것이다

| 훅 | 표준 오류 | 종료 코드 |
|---|---|---|
| commit-msg | `error: cannot check the commit message — no harness CLI found (.harness/bin/harness, src/bin/harness)` / `help: restore the pinned copy with \`harness install\`, then commit again` | 1 (거부) |
| pre-commit | (없음) | 0 (통과) |
| pre-push | `blocked: cannot check the push — no harness CLI found (.harness/bin/harness, src/bin/harness)` / `help: restore the pinned copy with \`harness install\`, then push again` | 1 (거부) |

- 머리글 주석(생성 표지 · 활성화 안내)은 현행대로 둔다. pre-commit 머리글의 "하네스를 찾지 못하면 통과시킨다" 도 그대로다
- 모노레포 서브프로젝트의 훅은 그 서브프로젝트의 CLI 를 찾는다

### 3-3. 호환 shim

| 파일 | 하는 일 | CLI 를 찾지 못하면 |
|---|---|---|
| `script/hooks/bash-guard.sh` | 자기 위치의 `../..` 를 루트로, 3-2 의 순서로 CLI 를 찾아 `exec <CLI> bash-guard --target <루트>` | `warning: no harness CLI found (.harness/bin/harness, src/bin/harness), so the command guard did not run` · 1 |
| `script/secret-scan.sh` | 자기 위치의 `..` 를 루트로, 같은 순서로 찾아 `exec <CLI> secret-scan --target <루트> "$@"` | `error: no harness CLI found (.harness/bin/harness, src/bin/harness)` · 2 |

- 이미 떠 있는 Claude Code 세션은 시작할 때 읽은 훅 명령(`$CLAUDE_PROJECT_DIR/script/hooks/bash-guard.sh`)을 계속 쓴다
  <!-- TBD: 확인 필요 -->. 그 세션의 가드도 shim 을 거쳐 새 구현으로 돈다
- `script/secret-scan.sh` 는 사람이 직접 돌리는 경로다. pre-commit 은 이것을 거치지 않는다
- 두 shim 을 걷는 일은 호환 shim · 셸 생성물 정리 Requirement 가 맡는다

## 4. 명령 가드 — `harness bash-guard`

### 4-1. 순서

1. 표준 입력 전체를 읽어 명령을 꺼낸다 (4-2). 꺼내지 못했거나 꺼낸 값이 빈 문자열이면 0
2. 명령을 정리하고 구획으로 나눈다 (4-3)
3. `<루트>/script/harness.env` 를 읽는다 (4-6). 읽지 못하면 차단(2)
4. 가드 6종을 순서대로 돌린다 (4-5). 처음 걸린 가드가 사용 기록을 남기고 사유를 내고 2
5. 0

### 4-2. 입력 해석

- 표준 입력을 UTF-8 로 읽어 JSON 으로 엄격하게 푼다. 풀지 못하면 판정하지 않고 0 이다 — 빈 입력, JSON 이 아닌 글,
  잘린 JSON, 문자열 안의 이스케이프되지 않은 제어 문자, UTF-8 이 아닌 바이트가 여기 든다
- 최상위가 객체이고 `tool_input` 이 객체이고 그 `command` 가 문자열일 때만 명령을 꺼낸다. 아니면 0. 다른 자리의
  `command` 키는 보지 않는다
- 명령을 꺼내지 못하면 통과시키는 것은 현행 원칙 그대로다. 설정을 읽지 못한 경우(4-6)만 차단한다

### 4-3. 명령 정리와 줄 나누기

꺼낸 문자열을 판정 대상으로 바꾸고 구획으로 나누는 규칙은 #220 이 셸 가드에 넣은 규칙을 그대로 옮긴다. 구체 규칙의
정본은 #220 명세다. 이식이 같게 지켜야 하는 규칙은 아래와 같다.

1. JSON 문자열은 한 번에 디코드하고 개행을 보존한다. 명령에 글자로 적힌 백슬래시+`n` 은 개행이 아니다
2. 따옴표 상태는 줄을 넘어 이어진다. 닫힌 따옴표 안의 개행은 구분자가 아니다
3. 줄 끝 백슬래시(백슬래시 바로 뒤의 개행)는 줄을 잇는다
4. 그 밖의 개행은 `;` 와 같은 구획 구분자다
5. 최상위 히어독을 다룬다. 따옴표와 명령 치환 밖의 `<<` · `<<-` 와 구분어가 히어독이다. 본문은 종결 줄까지 판정에서
   빼고(보호 문서 가드의 문자열 판정에서도 뺀다), 연산자 줄의 나머지와 종결 줄 다음 줄은 판정한다. `<<<` 는 히어독이
   아니다
6. 다루지 못하는 구조를 만나면 그 지점부터 끝까지 #220 이전 처리를 따른다 — 개행은 공백이고, 처음 나오는 `<<` 에서
   자른다. 어느 구조가 여기 드는지는 #220 명세가 정한다

- JSON 이스케이프와 제어 문자는 5-1 의 전제 아래 셸 가드가 판정하는 글자와 같게 만든다. 셸 디코드가 풀지 않고 표기
  그대로 두는 이스케이프가 있으면 Python 도 그 표기로 되돌려 판정한다
- 히어독 본문에 적힌 위험 명령은 판정하지 않는다
- 낱말 분해(4-4)와 가드(4-5)는 이렇게 나눈 구획마다 돈다

### 4-4. 낱말 분해와 명령 자리

#220 머지 뒤 셸 구현의 규칙을 그대로 옮긴다. 셸 문법 라이브러리(`shlex` 등)의 분해 결과로 판정하지 않는다. 아래는
그런 분해와 갈리는 지점이고 전부 셸 가드의 규칙이다.

| 지점 | 규칙 |
|---|---|
| 따옴표 구간 | 구간은 줄을 넘어 이어질 수 있다. 안에 `$` · 백틱 · 백슬래시가 없는 `"…"` · `'…'` 만 푼다. 따옴표를 떼고, 안의 공백 · 탭 · `\|` · `;` · `&` · `~` 를 구분자나 확장으로 보지 않는다. 그 밖의 구간은 따옴표째 글자 그대로 둔다 |
| 빈 따옴표 | `''` · `""` 만으로 된 낱말은 빈 인수다. 낱말에 붙은 빈 따옴표는 지운다(`g''it` 은 `git`) |
| 닫히지 않은 따옴표 | 여는 따옴표부터 끝까지 글자 그대로 두고 판정을 계속한다 |
| 따옴표 밖의 백슬래시 | 이스케이프로 풀지 않는다. 백슬래시와 다음 글자를 그대로 두며, 다음 글자가 공백이면 그 공백은 여전히 낱말 경계다. 다음 글자가 개행이면 줄을 잇는다(4-3) |
| `#` | 주석으로 보지 않는다 |
| 구획 | 풀린 따옴표 구간 밖의 `\|` · `;` · `&` 와 개행(4-3)에서만 나눈다. 리다이렉션과 괄호는 구획을 나누지 않는다 |
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
- 5 는 낱말로 나누지 않은 명령 문자열 전체(히어독 본문은 뺀다, 4-3)를 정규식으로 본다. POSIX 공백 클래스
  (`[[:space:]]`)는 유니코드 공백 전부로 옮긴다. 현행 `grep` 의 공백 클래스는 로캘에 따라 다르고, 유니코드 공백은
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

- 같은 리더가 `script/harness-format.sh` 를 읽는다 (6절)

## 5. 판정 불변의 범위

### 5-1. 전제

Claude Code 는 훅 입력으로 완전한 JSON 객체 하나를 보내고, 명령은 `tool_input.command` 문자열 한 곳에만 있으며,
문자열에서 `"` · `\` · 제어 문자 · 짝 없는 서로게이트만 이스케이프한다(`\/` 나 그 밖의 글자의 `\uXXXX` 를 쓰지 않는다).
<!-- TBD: 확인 필요 — Claude Code 의 훅 입력 직렬화 -->

이 전제 아래 4-3 의 결과는 #220 머지 뒤 셸 가드의 것과 같고, 낱말 분해와 가드는 그 셸의 규칙 그대로다. 따라서 Claude
Code 가 보내는 입력에서 셸 가드보다 통과 쪽으로 뒤집히는 판정은 없다.

### 5-2. 셸 가드와 달라질 수 있는 입력

아래 표가 전부다. "#220 이전 셸" 열은 #220 이전에 관측한 값이다. #220 이 디코드를 바꾸므로 그 뒤의 셸은 이 열과 다를
수 있고, 이식 뒤 판정은 셸 값과 상관없이 "이식 뒤" 열의 값이다. 통과 쪽인 행은 모두 Claude Code 가 보내지 않는
형식이고, 4-2 의 "명령을 꺼내지 못하면 통과" 가 적용된다.

| 입력 | #220 이전 셸 | 이식 뒤 | Claude Code 가 보내는가 |
|---|---|---|---|
| 잘린 JSON `{"tool_input":{"command":"git push origin main"}` | 2 | 0 | 아니다 |
| JSON 이 아닌 글에 `"command":"…"` 가 든 것 | 그 값으로 판정 | 0 | 아니다 |
| `tool_input` 밖의 `command` 키 — `{"command":"git push origin main"}` | 2 | 0 | 아니다 |
| `command` 키가 둘 이상 — `tool_input.command` 는 `git status`, 뒤의 다른 객체에 `"command":"git push origin main"` | 마지막 키로 판정(2) | `tool_input.command` 로 판정(0) | 아니다 |
| 문자열 안에 이스케이프하지 않은 제어 문자 | 그 값으로 판정 | 0 | 아니다 |
| `\/` 와 제어 문자가 아닌 글자의 `\uXXXX` — `git push origin ma\u0069n`, `harness write-doc ro\u006ces/x -` | 풀지 않고 판정(두 예 모두 0) | 풀어서 판정(두 예 모두 2) | 아니다 |
| 보호 문서 쓰기 판정의 공백 자리에 든 유니코드 공백 — `sed` 와 `-i` 사이의 U+3000 | 로캘에 따라 다르다 | 공백으로 본다 | 보낸다. 차단 쪽으로만 달라진다 |

### 5-3. 셸 가드와 같게 지키는 지점

셸 문법 라이브러리나 표준 JSON 처리를 그대로 쓰면 판정이 갈리는 입력이다. 기대값은 #220 머지 뒤 셸 가드의 판정, 곧 그때의
`test-bash-guard.sh` 기대값이다. 전부 회귀 케이스로 고정한다. `<LF>` · `<CR>` · `<U+00A0>` 는 그 글자 하나다.

#220 이 바꾸지 않는 규칙. 값은 #220 이전 관측과 같다(작업 브랜치에서).

| 입력 | 판정 | 지키는 규칙 |
|---|---|---|
| `git push origin feat#1; git push --force origin feat/1-x` | 2 | `#` 은 주석이 아니다 |
| `echo hi # ; git push origin <보호 브랜치>` | 2 | 같음 |
| `git push --force origin feat/1-x  # don't` | 2 | 닫히지 않은 홑따옴표 뒤도 판정한다 |
| `git push --force origin "feat` | 2 | 닫히지 않은 따옴표 |
| `git push --force origin feat/1-x \` | 2 | 명령 끝의 백슬래시 |
| `git push origin<U+00A0><보호 브랜치>` (작업 브랜치의 임시 리포에서) | 0 | 유니코드 공백은 낱말 경계가 아니다 |
| `git push --force<U+00A0>origin feat/1-x` | 0 | 같음 |

#220 이 정한 여러 줄 · 히어독 규칙(4-3).

| 입력 | 판정 | 지키는 규칙 |
|---|---|---|
| `echo hi<LF>git push origin <보호 브랜치>` | 2 | 개행은 구획 구분자 |
| `git status<LF>git push --force origin feat/1-x` | 2 | 같음 |
| `git push \<LF>  --force origin feat/1-x` | 2 | 줄 끝 백슬래시는 줄을 잇는다 |
| `git commit -m "a<LF>git push --force origin x"` | 0 | 닫힌 따옴표 안의 개행은 구분자가 아니다 |
| `echo a\ngit push --force origin feat/1-x` (백슬래시와 `n` 두 글자) | 0 | 글자로 적힌 백슬래시+`n` 은 개행이 아니다 |
| `cat <<EOF > out.txt<LF>body<LF>EOF<LF>git push --force origin feat/1-x` | 2 | 종결 줄 다음 줄은 판정한다 |
| `cat <<EOF<LF>git push --force origin feat/1-x<LF>EOF` | 0 | 히어독 본문은 판정하지 않는다 |
| `cat <<EOF > <보호 문서><LF>x<LF>EOF` | 2 | 연산자 줄의 나머지는 판정한다 |
| `git commit -m "$(cat <<'EOF'<LF>body<LF>EOF<LF>)"` | 0 | 명령 치환 안의 히어독 본문은 판정하지 않는다 |

기대값을 #220 머지 뒤 셸 가드에서 관측해 정하는 것. 세부 규칙을 #220 명세가 정하는 지점이다.

| 입력 | 갈리는 지점 |
|---|---|
| `git commit -m "a << b" --no-verify` | 따옴표 안의 `<<` |
| `echo "a << b"; git push --force origin feat/1-x` · `echo $((1<<2)); git push --force origin feat/1-x` | 히어독이 아닌 `<<` |
| `git push origin feat\nmain` (백슬래시와 `n` 두 글자) | 글자로 적힌 백슬래시+`n` 과 낱말 경계 |
| `echo "<CR>; git push --force origin x"` | 제어 문자의 디코드와 따옴표 구간 |

- #220 이 `test-bash-guard.sh` 에 넣은 여러 줄 · 히어독 케이스도 모두 이 이식의 오라클이다

## 6. 시크릿 스캔 — `harness secret-scan`

- 하네스 루트에서 git 을 부른다. 기준은 HEAD 가 있으면 HEAD, 없으면 git 이 내는 빈 트리(`git hash-object -t tree /dev/null`)
- 기본은 작업 트리, `--staged` 는 인덱스다 — `git diff [--cached] -U0 --no-color --diff-filter=ACMR <기준>`
- 허용 표지는 `<루트>/script/harness-format.sh` 의 `FMT_SECRET_ALLOW` 를 `envfile` 로 읽는다. Python 쪽에 표지 문자열을
  적지 않는다. 읽지 못하거나 키가 없으면 `error: cannot read the secret allow marker from <루트>/script/harness-format.sh`
  를 내고 2
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

1. 생성물 일치 검사 — `harness check --target <루트> --staged` 와 같은 검사다. 설정 오류를 포함해 0 이 아니면 1
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
| 명령 가드 — 훅 명령 · `script/hooks/bash-guard.sh` | 1, 경고 한 줄 — 통과 | 2 가 아닌 코드 — 통과 | 1, 오류 한 줄 — 통과 | 2, 4-6 의 문구 — 차단 |
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
| 입력 만들기 | Claude Code 와 같은 모양의 입력을 만든다 — `json.dumps({"tool_name": "Bash", "tool_input": {"command": <명령>}}, ensure_ascii=False)`. 따옴표 · 백슬래시 · 제어 문자만 이스케이프된다 |
| 부르는 곳 | 루트의 `.claude/settings.json` 훅 명령을 `CLAUDE_PROJECT_DIR=<루트>` 로 `sh -c` 해 종료 코드를 본다 |
| 임시 루트 | 하네스가 지키는 임시 리포(작업 트리 · 다른 리포 · 공백 경로 · 구획 문자 보호 목록)는 `script/harness.env`(또는 값을 바꾼 사본), 루트의 `script/hooks/` 사본, 테스트를 부른 루트의 CLI 를 가리키는 심볼릭 링크 `.harness/bin/harness` 를 갖는다. 옛 구현과 새 구현이 같은 배치로 돈다 |
| 더하는 케이스 | 5-3 의 표 가운데 #220 이 넣지 않은 것 전부(관측해 정하는 표의 기대값은 #220 머지 뒤 셸에서 관측한 값). 계열(보호 브랜치 push · `--all` · commit, force push · `+refspec` · 삭제, `--no-verify` · `commit -n`, 원격 삭제, 보호 문서, write-doc, 설정 없음)마다 한 케이스씩 표준 오류 전체를 현행 문구와 대조 |
| 단위 테스트로 옮기는 검사 | `_guards.sh` 를 읽어 함수를 바꿔 끼우는 검사(비교 값에 자리표가 남지 않음), 가드 하나를 망가뜨린 사본 검사 둘(force push · write-doc) |

케이스 표와 기대값은 그대로다.

### 9-3. `test-secret-scan.sh`

- 임시 리포에 `script/secret-scan.sh` · `script/harness-format.sh` 사본과, 테스트를 부른 루트의 CLI 를 가리키는 심볼릭 링크
  `.harness/bin/harness` 를 둔다. 옛 구현과 새 구현이 같은 배치로 돈다
- UT-07 에 다른 명령의 옵션(`--purge`)이 종료 코드 2 인 케이스를 더한다
- 기대값은 그대로다

### 9-4. 단위 테스트 — `src/test/unit/`

소스 리포에만 두고 `python3 -m unittest` 로 돈다. `[verify]` 의 Python 단위 테스트 단계가 돌린다.

| 대상 | 확인하는 것 |
|---|---|
| 차단 · 통과 표 | `test-bash-guard.sh` 와 같은 계열의 차단 케이스와 통과 케이스를 가드에 직접 돌린다. 판정 값은 고정한 `harness.env` 견본에서 온다 |
| 가드 하나를 끈 사본 | force push 가드만 끄면 force 계열만 통과로 뒤집히고 나머지 계열은 차단 그대로다. write-doc 가드도 같다 |
| 비교 값 | 셸 테스트에서 옮겨 오는 인용 섞인 명령 일곱(구획 문자가 든 인용 목적지, 인용 목적지 둘, 빈 따옴표가 붙은 refspec, 공백 · 물결표가 든 인용 목적지, 인용된 `-C` 경로, 인용된 `cd` 경로, 빈 따옴표 목적지)에서 보호 목록과 비교된 값이 셸이 넘기는 값이고 제어 문자가 없다 |
| 입력 해석 | 5-2 의 행마다 이식 뒤 판정. 명령이 없거나 문자열이 아니거나 빈 입력이면 0 이고 `harness.env` 없이도 0 이다 |
| 명령 정리와 줄 나누기 | 4-3 의 규칙 1–6 을 각각 |
| 무예외 | 고정한 시드로 만든 임의 명령 문자열(따옴표 · 백슬래시 · `\|;&` · `<<` · `#` · `$(` · 백틱 · 공백 · 유니코드 공백 · 제어 문자를 섞은 것)에서 예외 없이 0 또는 2 |
| import | 새 프로세스에서 `bash-guard` 를 한 번 돌린 뒤 불러온 모듈에 `tomllib` · `urllib` · `http` 가 없다 |
| 예외 정책 | 가드 하나가 예외를 내면 종료 코드 1, 표준 오류는 `error: the command guard stopped` 로 시작하는 한 줄이고 트레이스백이 없다 |
| `envfile` | 세 형식, 여러 줄 홑따옴표, `'\''`, 겹따옴표의 `$HOME` · `${HOME}`, 주석 · 빈 줄. 형식이 아닌 줄 · 디렉터리 · 없는 파일은 읽지 못한 것이다 |
| commit-msg | 제목은 첫 LF 앞까지다(CR 이 남은 제목은 맞지 않는다). `Merge ` 등 네 접두는 0. UTF-8 이 아닌 제목은 거부 |
| pre-push | ref 줄 나누기, 보호 브랜치 비교는 정확히 같은 이름만, `VERIFY_PRE_PUSH=0` 이면 검증을 돌지 않는다 |
| secret-scan 인수 | `--stage` · `--purge` · 남는 위치 인수는 2. 표지 파일이 없으면 2 |

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
| CLI 없음 | 설치한 리포에서 `.harness/bin/harness` 를 치우면 commit-msg 는 1 과 그 문구, pre-push 는 1, pre-commit 은 0, 훅 명령과 `script/hooks/bash-guard.sh` 는 1 과 경고 한 줄(2 가 아니다), `script/secret-scan.sh` 는 2 |
| 설정 없음 | `script/harness.env` 를 치우면 commit-msg · pre-push 는 1 과 그 문구, 훅 명령은 2 와 4-6 의 문구 |
| 호환 shim | `script/hooks/bash-guard.sh` 가 보호 브랜치 push 를 막고(2), `script/secret-scan.sh --staged` 가 스테이징한 견본을 잡는다(1) |
| 옛 가드 파일 정리 | `.harness/managed` 에 `script/hooks/_guards.sh` 가 있는 설치본을 render 하면 그 파일이 지워진다. 새 설치에는 없다 |
| 모노레포 | 서브프로젝트의 commit-msg 훅이 그 서브프로젝트의 CLI 로 형식을 검사한다 |

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
| `src/templates/managed/script/README.md` | 목록 표의 `secret-scan.sh` · `hooks/bash-guard.sh` 행을 CLI 로 넘기는 호환 shim 으로 고치고 `hooks/_guards.sh` 행을 지운다 |
| `src/templates/managed/docs/workflow/changing.md` | "가드 판정" 행을 하네스 리포의 `src/harness/guard/` + 테스트 케이스로 |
| `src/templates/vendors.toml` | `hooks` 주석의 `(bash-guard.sh)` 를 `(harness bash-guard)` 로 |
| `test-bash-guard.sh` 머리글 | 가드 하나를 망가뜨린 사본 검사 서술을 지운다(단위 테스트로 옮겼다) |
| `docs/spec/71-issue-worktree-run.md` 4절 | 명령 가드 줄: 훅 명령은 `$CLAUDE_PROJECT_DIR` 아래의 CLI(`.harness/bin/harness`, 없으면 `src/bin/harness`)로 `bash-guard --target "$CLAUDE_PROJECT_DIR"` 를 부른다 |
| `docs/spec/62-unify-ui-writes-through-cli.md` | 정본 위치 표의 `write-doc` 명령 가드 행을 `src/harness/guard/` 로, 6-1 첫 문장을 "가드 순서 목록에서 보호 문서 셸 편집 다음에 돈다" 로 |
| `docs/spec/70-generate-permission-allow-list.md` | `hooks.PreToolUse` 줄의 괄호를 `harness bash-guard` 로 |

`docs/spec/58-…` 의 doctor 출력 예시(`script/hooks/_guards.sh  missing managed file`)는 예시라 그대로 둔다. 이 리포의
`script/` · `docs/workflow/` 사본은 render 가 따라 바꾼다.

## 11. 이행

- #220 이 머지된 뒤에 착수한다. 그 머지가 넣은 셸 가드와 케이스가 이 이식의 오라클이다
- 진입점(훅 명령 · git 훅 shim · 호환 shim)을 새 명령으로 돌리는 변경은 세 하위 명령이 들어간 뒤에 오고, 한 커밋에서
  함께 바뀐다. 어느 커밋에서도 가드와 훅이 돈다
- `script/hooks/_guards.sh` 는 진입점을 돌리는 커밋에서 관리 파일 목록에서 빠진다
- 이 리포는 자기 가드 아래에서 이 변경을 만든다. 진입점이 바뀐 뒤 떠 있던 세션은 호환 shim 을 거친다 (3-3)

## 12. 보호 문서 개정 범위

이 이슈 범위에서 사용자가 일괄 허용한 개정이다. 구현 단계의 task 하나가 이 범위 안에서만 고치고 render 한다.

### 12-1. `.ai/project/architecture.md`

| 위치 | 반영할 사실 |
|---|---|
| "구성 요소" 의 CLI 항목(#206 이 패키지 배치로 고친 것) | 덧붙인다: 명령 가드 · 시크릿 스캔 · git 훅 본문도 CLI 하위 명령이다 — `bash-guard`(Claude Code `PreToolUse(Bash)` 훅) · `secret-scan` · `git-hook <commit-msg\|pre-commit\|pre-push>`. 코드는 `src/harness/guard/` · `src/harness/hooks.py` 이고, 셸 대입 파일(`script/harness.env` · `script/harness-format.sh`) 읽기는 `src/harness/envfile.py` 다 |
| "구성 요소" 의 대상 리포 `script/` 항목 | "가드(`hooks/`)·시크릿 스캔" 을 "명령 가드 · 시크릿 스캔의 호환 shim(`hooks/bash-guard.sh` · `secret-scan.sh` — CLI 로 넘긴다)" 으로. 덧붙인다: `githooks/` 는 CLI 를 찾아 `git-hook` 으로 넘기는 생성 shim 이다 |
| "데이터 흐름" | 새 항목 "가드 · 훅": Claude Code `PreToolUse(Bash)` → `.claude/settings.json` 의 훅 명령 → 하네스 루트의 CLI(`.harness/bin/harness`, 없으면 `src/bin/harness`) `bash-guard` → `script/harness.env` 의 값으로 판정(0 통과 · 2 차단). git → `script/githooks/<훅>` → 같은 CLI 의 `git-hook <훅>` |
| "신뢰 경계" 의 들어오는 입력 | "도구 호출 JSON(`script/hooks/bash-guard.sh`)" 을 "도구 호출 JSON(`harness bash-guard`)" 으로 |
| "새 코드를 둘 곳" 의 새 가드 | "새 가드 → `src/harness/guard/` 의 가드 함수와 가드 순서 목록 + `test-bash-guard.sh` 케이스 + `src/test/unit/` 의 단위 테스트. 판정에 쓰는 값은 `script/harness.env` 로 받는다" 로 바꾼다 |
| "새 코드를 둘 곳" | 새 항목: "git 훅 본문 → `src/harness/hooks.py`. `script/githooks/*` 는 CLI 를 찾아 넘기는 shim 으로만 둔다" |
| "새 코드를 둘 곳" 의 새 회귀 테스트 | 덧붙인다: 하네스 패키지의 Python 단위 테스트는 `src/test/unit/` |

### 12-2. `.ai/project/testing.md`

| 위치 | 반영할 사실 |
|---|---|
| "무엇을 어느 수준으로 검증하나" | 새 줄: 하네스 패키지(`src/harness/`)는 소스 리포의 `src/test/unit/` 에서 `python3 -m unittest` 로 단위 테스트한다. 대상 리포로 가지 않는다. 명령 가드는 셸 테스트가 보지 못하는 것 — 가드 하나를 끈 사본에서 그 계열만 통과로 뒤집히는지, 보호 목록과 비교되는 값이 셸이 넘기는 값인지, 임의 입력에서 예외가 나지 않는지, 가드 경로가 무거운 모듈을 불러오지 않는지 — 를 여기서 본다 |

`glossary.md` · `scope.md` 는 고치지 않는다.

## 13. 한계

- #220 의 한계를 그대로 물려받는다. 큰따옴표 안 명령 치환 속 히어독(`"$(cat <<'EOF' …)"`) 뒤에 오는 명령과, 주석 안의
  따옴표가 뒤 줄의 따옴표와 짝지어지는 경우의 명령은 판정하지 못한다
- python3 3.11 이상이 없는 기기에서는 명령 가드가 돌지 않는다(8-2)
- CLI 를 찾지 못한 pre-commit 은 시크릿 스캔도 건너뛴다(8-2)
- Claude Code 가 보내지 않는 형식의 입력은 통과한다(5-2). 5-1 의 전제가 틀리면 그 표가 늘어난다
- `.claude/settings.json` 의 훅 명령을 손으로 고쳐 모르는 옵션을 넘기면 전역 인수 파서가 종료 코드 2 로 끝나 모든 명령이
  막힌다. 생성 파일이라 `check` 가 잡는다
- 히어독 본문 안의 명령은 판정하지 않는다. 다루지 못하는 구조(4-3 의 6) 뒤로는 #220 이전 처리를 따른다
- 가드 · 훅의 설정 출처는 `script/harness.env` 다. 그 파일과 호환 shim 을 걷는 정리 Requirement 가 출처를 함께 바꾼다
