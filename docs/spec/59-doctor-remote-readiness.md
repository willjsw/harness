# doctor 의 원격 준비 점검과 구조화된 결과

`harness doctor` 는 점검 결과를 항목 목록으로 모으고, 텍스트 출력과 JSON 출력은 그 목록을 그린다.
`harness status` 는 사람용 출력을 다시 읽지 않고 같은 목록을 쓴다. `--remote` 를 주면 doctor 가 원격 준비 상태
(origin · base 브랜치 · 원격 기본 브랜치 · forge 로그인 · 라벨 · 브랜치 보호 · 리뷰어 러너)를 읽기 전용으로 점검한다.
자리표시자와 어댑터 미검증 판정은 정해진 표지로만 한다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 점검 수집 · 텍스트/JSON 렌더 · `status` · 인자 | `src/bin/harness` |
| 러너 인증 확인 선언 | `src/templates/vendors.toml` 의 `auth_check` |
| 러너 준비 확인 진입점 | `src/templates/managed/script/run-agent.py` 의 `--check` |
| forge 읽기 함수 계약 | `src/templates/managed/script/forge/_common.sh` 상단 |
| forge 읽기 함수 구현 | `src/templates/managed/script/forge/<kind>.sh` |
| 어댑터 자체 검사 | `src/templates/managed/script/forge-selftest.sh` |
| UI | `src/ui/lib/harness.js` · `src/ui/lib/actions.js` · `src/ui/lib/status-cache.js` · `src/ui/components/DoctorView.js` · `src/ui/lib/doctor.js` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/test/fake-forge.sh` · `src/ui/lib/doctor.test.js` |
| 사람용 설명 | `README.md` · `src/templates/managed/script/README.md` |

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

- `--remote` 가 없으면 doctor 는 네트워크에 닿지 않는다. 점검 항목과 판정은 3절의 두 표지 변경을 빼면 지금과 같다
- doctor 의 텍스트 한 줄 형식(`  ok   무엇  — 설명` · `  warn` · `  FAIL`), 절 제목, 마지막 요약 줄, 종료 코드는 그대로다
- `harness status` 의 JSON 키 구조는 그대로다. `doctor.items` 의 항목은 지금처럼 `section` · `state` · `what` · `detail` 넷이다
- 원격 점검은 읽기 전용이다. 라벨·브랜치 보호·원격 설정을 만들거나 바꾸지 않는다
- 기존 `tracker_require` · `review_require` 의 동작은 그대로다(설치 확인만). 인증 확인은 새 함수가 한다

## 2. 결과 목록과 렌더

### 2-1. 수집

doctor 의 점검은 출력하지 않는 수집 함수 하나가 한다. 수집 함수는 `(cfg, target, remote)` 를 받아 항목 목록을 돌려준다.

```
{"section": "<절 이름>", "state": "ok" | "warn" | "bad", "what": "<무엇>", "detail": "<설명, 없으면 빈 문자열>"}
```

- 목록의 순서가 출력 순서다. 절 순서는 `config` · `generated files` · `project facts` · `verification` · `references` ·
  `tools and connections` · `registry` · `git` · `remote` 이다. `remote` 절은 `remote` 가 참일 때만 항목을 갖는다
- 수집 함수는 표준 출력에 아무것도 쓰지 않는다. 검증 스크립트처럼 수집 중에 띄우는 프로세스의 출력은 지금처럼 받아 둔다
- 문구는 전부 영어다

### 2-2. 렌더

| 출력 | 그리는 것 |
|---|---|
| 텍스트 (기본) | 절마다 절 이름 한 줄과 그 절 항목 줄들, 절 사이에 빈 줄. 항목이 없는 절은 그리지 않는다. `remote` 가 거짓이면 요약 줄 앞에 `` remote checks not run — use `harness doctor --remote` `` 한 줄. 마지막에 지금과 같은 요약 줄 |
| JSON (`--json`) | 표준 출력에 JSON 객체 하나만: `{"bad": <bad 수>, "warn": <warn 수>, "items": [<항목>...]}`. 안내 줄·요약 줄은 없다 |

- 두 출력의 종료 코드는 같다 — `bad` 가 하나라도 있으면 1, 아니면 0
- 텍스트의 `remote checks not run` 줄은 항목이 아니다. JSON 과 `status` 에 들어가지 않고 개수에 세지 않는다

### 2-3. `harness status`

- `cmd_status` 는 수집 함수를 직접 부르고 그 목록으로 `doctor` 값(`bad` · `warn` · `items`)을 만든다. doctor 의 표준 출력을
  가로채거나 정규식으로 읽지 않는다. `harness status` 의 `doctor` 값은 같은 조건의 `harness doctor --json` 출력과 같다
- `--remote` 를 받으면 수집 함수에 그대로 넘긴다. 없으면 원격 점검을 하지 않는다
- 설정 진행도(`facts.filled`)는 지금처럼 `project facts` 절의 `ok` 가 아닌 항목으로 센다

### 2-4. 인자

| 인자 | 받는 명령 | 뜻 |
|---|---|---|
| `--remote` | `doctor` · `status` | 원격 준비 점검(4절)을 함께 한다 |
| `--json` | `doctor` | 결과를 2-2 의 JSON 으로 낸다 |

- 도움말 표(`COMMANDS`)의 인수 칸: `doctor` 는 `[--remote] [--json]`, `status` 는 `[--remote]`
- 두 명령은 지금처럼 고정 사본으로 위임되고, 인자는 그대로 넘어간다

## 3. 판정 표지

| 판정 | 표지 |
|---|---|
| `project facts` 의 자리표시자 | 파일 본문의 `<!-- TBD` 출현 수. 본문에 `TBD` 라는 낱말이 따로 나오는 것은 세지 않는다. `detail` 문구 `<N> placeholder(s) still to fill` 는 그대로다 |
| `tools and connections` 의 어댑터 미검증 | 어댑터 파일의 **머리글** — 1행부터 `#` 로 시작하는 줄이 이어지는 첫 주석 덩어리 — 에 `검증 상태: 미검증` 이 있을 때. 그 뒤 본문 주석이나 코드에 `미검증` 이 나오는 것은 판정에 쓰지 않는다. `detail` 문구는 그대로다 |

- 머리글 표지 문자열은 `src/bin/harness` 의 상수 하나가 갖는다
- `script/forge/_common.sh` 의 계약 주석에 "어댑터 머리글의 `검증 상태:` 줄이 검증 상태의 표지이고, 실제 forge 로
  `forge-selftest.sh` 를 통과하기 전의 어댑터는 `검증 상태: 미검증` 을 적는다" 를 둔다
- 지금 `gitlab.sh` · `jira.sh` 의 머리글은 표지를 갖고 있고 `github.sh` 의 머리글은 갖고 있지 않다

## 4. 원격 준비 점검 — `remote` 절

`--remote` 일 때만 돈다. 모든 항목은 하네스 루트를 작업 디렉터리로 한다.

### 4-1. 원격 호출 공통

- 원격에 닿는 호출(git · forge 어댑터 함수 · 러너 인증 확인)은 호출마다 30초 제한 시간을 둔다. 표준 입력은 닫고,
  git 호출에는 `GIT_TERMINAL_PROMPT=0` 을 준다 — 자격증명 입력을 기다리며 멈추지 않는다
- 제한 시간 초과 · 실행 실패 · 해석할 수 없는 응답은 그 항목의 `warn` `could not check` 다
- 원격 URL, git·forge CLI·러너 CLI 의 출력을 `what` · `detail` 에 옮기지 않는다. URL 에 사용자 정보가 들어 있을 수 있고,
  CLI 출력에는 계정 식별 정보가 들어 있다. 옮기는 것은 이 절이 정한 고정 문구와 설정 값(브랜치·라벨·forge 종류·벤더 이름),
  그리고 어댑터 인증 함수가 계약대로 내는 안내 한 줄(4-4)뿐이다

### 4-2. 항목

`<base>` 는 `branches.base`, `<tracker>` · `<host>` 는 `forge.tracker` · `forge.review_host` 값이다.

| 항목 (`what`) | 상태와 `detail` |
|---|---|
| ``remote `origin` `` | 하네스 루트가 git 작업 트리가 아니면 `bad` `not a git repository`. `git remote get-url origin` 이 실패하면 `bad` ``not set — run `git remote add origin <url>` ``. 그 밖에는 `ok`, `detail` 없음 |
| ``branch `<base>` on origin`` | ls-remote(4-3)가 `refs/heads/<base>` 를 내면 `ok`. 내지 않으면 `bad` ``missing — run `git push origin <base>` ``. ls-remote 가 실패하면 `warn` `could not check — git ls-remote failed` |
| `origin default branch` | ls-remote 의 `HEAD` 심볼릭 참조가 `refs/heads/<base>` 면 `ok` `` `<base>` ``. 다른 브랜치 `<X>` 면 `warn` ``is `<X>`, not branches.base `<base>` — new clones and review requests start from it``. 심볼릭 참조가 없으면 `warn` `could not check — origin does not report it`. ls-remote 가 실패하면 `warn` `could not check — git ls-remote failed` |
| ``sign-in to `<kind>` `` | forge 종류마다 한 줄(4-4). `ok` · `bad` ``not signed in — <안내>`` · `warn` `could not check` |
| ``label `<L>` `` | 트래커 라벨마다 한 줄(4-5). 있으면 `ok` ``on <tracker>``, 없으면 `warn` ``missing on <tracker> — create it on the forge`` |
| `labels` | 트래커 라벨 목록을 읽지 못하면 이 한 줄만 `warn` `could not check` (4-5) |
| ``branch protection `<b>` `` | 보호 브랜치마다 한 줄(4-6). 보호되어 있으면 `ok` ``protected on <host>``, 아니면 `warn` ``not protected on <host> — only local hooks block direct pushes; protect it on the forge``, 조회에 실패하면 `warn` `could not check` |
| ``reviewer runner `<vendor>` `` | 4-7 |

등급 기준: 동작을 막는 것(origin 없음 · base 가 원격에 없음 · forge 미인증 · 리뷰어 러너 미설치·미인증)은 `bad`,
그 밖(라벨 없음 · 원격 기본 브랜치가 base 와 다름 · 브랜치 보호 없음)은 `warn`, 조회하지 못한 것은 `warn` `could not check` 이다.

### 4-3. 선행 조건과 생략

- ``remote `origin` `` 이 `bad` 면 그 뒤의 git 항목(base · 기본 브랜치 · 브랜치 보호)을 내지 않는다
- ls-remote 는 한 번만 부른다: `git ls-remote --symref origin HEAD refs/heads/<b>...` — `<b>` 는 base 를 포함한 보호 브랜치 목록
  (설정 파생 값 `PROTECTED_BRANCHES`) 전부. 종료 코드 0 이 아니면 실패다
- forge CLI 가 설치되어 있지 않은 forge 종류(`tools and connections` 절의 `forge CLI` 가 `bad`)는 그 종류의 로그인 · 라벨 ·
  브랜치 보호 항목을 내지 않는다
- ``sign-in to `<kind>` `` 이 `ok` 가 아닌 forge 종류는 그 종류의 라벨 · 브랜치 보호 항목을 내지 않는다

### 4-4. forge 로그인

- 대상 종류는 `[forge.tracker, forge.review_host]` 에서 중복을 뺀 순서다
- 트래커 종류는 `tracker_auth`, 리뷰 호스트 종류는 `review_auth` 로 확인한다. 두 값이 같으면 `tracker_auth` 한 번이다
- 함수 종료 코드 0 은 `ok`, 1 은 `bad` 이고 `<안내>` 는 그 함수가 표준 오류에 낸 첫 줄이다. 그 밖의 종료 코드는 `warn` `could not check`

### 4-5. 라벨

- 점검하는 라벨은 `issues.labels` 의 값 중 빈 문자열이 아닌 것, 중복을 뺀 설정 순서다. 회차 라벨(`<round_label>:<N>`)은 점검하지 않는다
- 트래커의 `tracker_labels` 가 종료 코드 0 과 문자열 배열을 내면 라벨마다 비교한다. 비교는 대소문자를 가리지 않는다
- 종료 코드 3(트래커가 라벨을 미리 두지 않는다)이면 라벨 항목을 하나도 내지 않는다
- 그 밖의 종료 코드이거나 출력이 문자열 배열이 아니면 `labels` `warn` `could not check` 한 줄이다

### 4-6. 브랜치 보호

- 보호 브랜치 목록 중 ls-remote 가 origin 에 있다고 낸 브랜치만 점검한다. origin 에 없는 보호 브랜치는 항목을 내지 않는다
- 리뷰 호스트의 `review_branch_protected <b>` 가 종료 코드 0 과 `true` 를 내면 `ok`, `false` 면 `warn`, 그 밖은 `warn` `could not check`

### 4-7. 리뷰어 러너

리뷰어는 `roles.code-reviewer` 다. 실행 계획(`run_plan()`)에서 그 역할이 서브에이전트(`via = subagent`)면 이 항목을 내지 않는다.
CLI 러너면 `script/run-agent.py code-reviewer --check`(5절)를 부르고 종료 코드로 가른다. `<vendor>` 는 러너의 벤더 id 다.

| `--check` 결과 | 항목 |
|---|---|
| 종료 코드 0, 표준 출력 `signed-in` | `ok` `signed in` |
| 종료 코드 0, 표준 출력 `unchecked` | `ok` ``installed — sign-in is not checked for <벤더 name>`` |
| 종료 코드 2 | `bad`. `detail` 은 표준 오류 첫 줄에서 앞의 `error: ` 를 뗀 것 |
| 종료 코드 3 | `bad` ``not signed in — `<auth_check argv 를 공백으로 이은 것>` fails`` |
| 그 밖 (4 포함) · 제한 시간 초과 | `warn` `could not check` |
| `script/run-agent.py` 가 없다 | `bad` `` `script/run-agent.py` is missing — run `harness render` `` |

## 5. 러너 준비 확인 — `vendors.toml` 의 `auth_check` 와 `run-agent.py --check`

이 선언과 진입점은 doctor 와 리뷰 루프가 함께 쓴다 — 리뷰 루프의 러너 사전 점검은 같은 `--check` 를 부른다.

### 5-1. `auth_check`

- 벤더 선언의 선택 키. 로그인 여부를 확인하는 argv 이고, 로그인되어 있으면 종료 코드 0, 아니면 0 이 아닌 코드를 내는 명령이어야 한다
- 자리 치환(`{model}` 등)을 쓰지 않는다. 첫 원소는 그 벤더의 `exe` 와 같다
- 그 CLI 로 직접 확인한 벤더에만 적는다. 적지 않은 벤더는 설치만 확인한다
- `vendors.toml` 머리 주석의 키 설명에 `auth_check` 한 줄을 더한다
- 선언을 읽을 때 `auth_check` 가 있는데 비어 있거나 문자열 목록이 아니거나 첫 원소가 `exe` 와 다르면 `die` 로 멈춘다

| 벤더 | `auth_check` | 확인한 것 |
|---|---|---|
| `claude` | `["claude", "auth", "status"]` | Claude Code 2.1.284 — 로그인 상태 0, 설정 디렉터리가 빈 상태 1 |
| `codex` | `["codex", "login", "status"]` | codex-cli 0.155.1 — 로그인 상태 0, 설정 디렉터리가 빈 상태 1 |
| 그 밖 | 적지 않는다 | — |

API 키 환경 변수로만 인증한 상태에서 두 명령의 종료 코드 <!-- TBD: 확인 필요 -->

### 5-2. 실행 계획

`run_plan()` 은 CLI 러너 역할(`via = headless`)마다 `auth_check` 키를 싣는다. 값은 벤더 선언의 `auth_check`, 없으면 빈 목록이다.
`script/harness.plan.json` 이 바뀌므로 render 가 다시 만든다.

### 5-3. `script/run-agent.py <역할> --check`

역할을 실행하지 않고 그 역할의 CLI 러너를 쓸 수 있는지만 본다.

| 상황 | 종료 코드 | 출력 |
|---|---|---|
| 실행 계획이 없다 · 역할이 없다 · 서브에이전트 역할이다 · 실행 파일이 설치되어 있지 않다 | 2 | 지금과 같은 `error:` 안내 (표준 오류) |
| `auth_check` 가 빈 목록 | 0 | 표준 출력 `unchecked` |
| `auth_check` 가 종료 코드 0 | 0 | 표준 출력 `signed-in` |
| `auth_check` 가 0 이 아닌 종료 코드 | 3 | 표준 오류 ``error: <벤더> is not signed in (`<argv>` failed)`` |
| `auth_check` 제한 시간(30초) 초과 · 띄우지 못함 | 4 | 표준 오류 ``error: could not check sign-in for <벤더>`` |

- `auth_check` 명령의 표준 입력은 닫고, 표준 출력·표준 오류는 버린다 — 옮기지 않는다
- `--check` 는 실행 지표 스팬과 사용 기록을 남기지 않는다
- `--check` 와 `--out` · `--prompt` · 입력을 함께 주면 `--check` 만 본다
- 스크립트 머리 docstring 의 사용법과 종료 코드 설명에 `--check` 를 더한다

## 6. forge 읽기 함수

### 6-1. 계약 — `_common.sh` 상단

이슈 트래커 군:

| 함수 | 계약 |
|---|---|
| `tracker_auth` | 로그인 확인. 되면 0. 안 되면 1 과 함께 표준 오류에 로그인 방법 한 줄(어댑터가 정한 고정 문구, 예: ``run `gh auth login` ``). 확인하지 못하면 그 밖의 코드. CLI 의 출력을 옮기지 않는다 |
| `tracker_labels` | 트래커 라벨 이름 전부를 JSON 문자열 배열로 (전 페이지). 라벨을 미리 두지 않는 트래커는 아무것도 내지 않고 종료 코드 3 |

리뷰 호스트 군:

| 함수 | 계약 |
|---|---|
| `review_auth` | `tracker_auth` 와 같은 계약 |
| `review_branch_protected <브랜치>` | 그 브랜치가 보호되어 있으면 `true`, 아니면 `false` 한 줄. 판단하지 못하면 0 이 아닌 코드 |

네 함수 모두 읽기만 한다.

### 6-2. 어댑터 구현

| 어댑터 | `*_auth` | `tracker_labels` | `review_branch_protected` |
|---|---|---|---|
| `github.sh` | `gh auth status` 의 출력을 버리고 종료 코드 0 → 0, 그 밖 → 1 (안내 ``run `gh auth login` ``) | `gh label list --json name --limit 1000` 을 이름 배열로 | `gh api repos/{owner}/{repo}/branches/<b>` 의 `protected` |
| `gitlab.sh` | `glab auth status` 의 출력을 버리고 종료 코드 0 → 0, 그 밖 → 1 (안내 ``run `glab auth login` ``) | 프로젝트 라벨 API(`projects/:id/labels`)를 끝 페이지까지 이름 배열로 | 보호 브랜치 API(`projects/:id/protected_branches/<b>`) — 있으면 `true`, 404 면 `false` |
| `jira.sh` | `jira me` 의 출력을 버리고 종료 코드 0 → 0, 그 밖 → 1 (안내 ``run `jira init` ``) | 종료 코드 3 | 해당 없음 — Jira 는 리뷰 호스트가 아니다 |

- `gitlab.sh` · `jira.sh` 는 머리글의 `검증 상태: 미검증` 을 유지한다
- `github.sh` 는 새 함수를 포함해 `forge-selftest.sh` 읽기 단계를 실제 GitHub 리포로 통과시킨 뒤 머리글의 검증 상태 줄을 그 실행의 gh 버전으로 고친다

`gh auth status` 가 네트워크 없이 도는 상태에서 내는 종료 코드 <!-- TBD: 확인 필요 -->

### 6-3. 자체 검사 — `forge-selftest.sh`

읽기 단계(흔적 없음)에 넷을 더한다.

| 검사 | 통과 조건 |
|---|---|
| `tracker_auth` | 종료 코드 0 |
| `review_auth` | 종료 코드 0 |
| `tracker_labels` | 종료 코드 0 과 JSON 문자열 배열, 또는 종료 코드 3 과 빈 출력 |
| `review_branch_protected <BASE_BRANCH>` | 종료 코드 0 과 `true` 또는 `false` 한 줄 |

`BASE_BRANCH` 는 이 스크립트가 이미 읽는 `script/harness.env` 의 값이다.

## 7. UI

### 7-1. 상태 읽기

- `readStatus(dir, remote = false)` (`src/ui/lib/harness.js`) 는 `remote` 가 참이면 `harness status --remote` 를 부른다
- `projectStatus(project, remote = false)` (`src/ui/lib/actions.js`) 가 그것을 넘긴다
- `loadStatus(project, fresh = false, remote = false)` (`src/ui/lib/status-cache.js`) 는 `remote` 가 참이면 언제나 새로 돌린다.
  캐시는 그 프로젝트의 마지막 결과 하나를 갖고, 구독자(사이드바 건수)에게 알린다
- 홈(`HomeGrid`)과 사이드바는 `remote` 를 넘기지 않는다

### 7-2. Doctor 화면 — `DoctorView`

- 요약 카드에 `Run again` 옆으로 버튼 `원격까지 점검` 을 둔다. 누르면 `loadStatus(project, true, true)` 를 부른다
- 원격 점검을 한 번 돌린 뒤의 `Run again` 은 원격까지 다시 돌린다. 화면을 새로 열면 원격 없이 시작한다
- 결과에 `remote` 절 항목이 없으면 요약 카드에 한 줄: "원격 점검은 돌리지 않았습니다. 원격까지 점검 을 누르면 origin·forge 로그인·라벨·브랜치 보호·리뷰어 러너를 확인합니다."
- 원격 점검 결과가 `null` 이면(고정된 하네스가 `--remote` 를 모르는 옛 버전) 이전 결과를 그대로 두고
  "원격 점검을 돌리지 못했습니다. 이 프로젝트의 하네스가 원격 점검을 모르는 옛 버전일 수 있습니다." 를 보인다

### 7-3. 문구 — `src/ui/lib/doctor.js`

- `SECTIONS` 에 `remote: "원격"` 을 더한다
- `explain()` 이 4-2 의 `ok` 가 아닌 줄을 한국어 항목으로 옮긴다

| 줄 | 항목에 담는 것 | 조치 |
|---|---|---|
| ``remote `origin` `` · `not a git repository` | 이 디렉터리가 git 리포가 아니어서 원격을 점검할 수 없다는 것 | — |
| ``remote `origin` `` · `not set …` | origin 이 없어 `/work` 가 원격을 가져오지 못하고 멈춘다는 것 | `cmd`: `git remote add origin <url>` |
| ``branch `<base>` on origin`` · `missing …` | 통합 브랜치가 원격에 없어 착수 판정과 리뷰 요청이 실패한다는 것 | `cmd`: `git push origin <base>` |
| `origin default branch` · `is …` | 원격 기본 브랜치(detail 의 `<X>`)가 설정의 통합 브랜치와 달라 새 클론과 리뷰 요청이 그쪽에서 시작한다는 것. forge 에서 기본 브랜치를 바꾸거나 `branches.base` 를 고친다 | `href`: Harness 설정 화면 |
| ``sign-in to `<kind>` `` · `not signed in …` | 그 forge CLI 에 로그인되어 있지 않아 이슈·리뷰 요청 명령이 실패한다는 것. detail 의 안내 | `cmd`: detail 의 백틱 안 명령 |
| ``label `<L>` `` · `missing …` | 그 라벨이 트래커에 없어 그 라벨을 붙이는 이슈 생성이 실패할 수 있다는 것 | — |
| ``branch protection `<b>` `` · `not protected …` | 원격에서 그 브랜치로의 직접 push 를 로컬 훅만 막고 있다는 것. forge 의 브랜치 보호를 켠다 | — |
| ``reviewer runner `<vendor>` `` · `bad` | 리뷰 루프가 리뷰어를 띄우지 못한다는 것과 detail | `href`: Agents 화면 |
| detail 이 `could not check` 로 시작하는 줄 | 그 항목을 확인하지 못했다는 것(네트워크·forge 응답·제한 시간). 다시 점검한다 | — |

## 8. README · 스크립트 표

| 위치 | 적는 사실 |
|---|---|
| `README.md` "명령" 의 `harness doctor` | `--remote` 면 origin · base 브랜치 · 원격 기본 브랜치 · forge 로그인 · 라벨 · 브랜치 보호 · 리뷰어 러너까지 읽기 전용으로 점검한다. `--json` 이면 결과를 JSON 으로 낸다 |
| `README.md` "명령" 의 `harness status` | `--remote` 를 받아 doctor 에 넘긴다 |
| `README.md` "시작하기" | 설치 뒤 원격 준비는 `harness doctor --remote` 로 확인한다 |
| `README.md` "UI" 의 Doctor 행 | 원격 점검은 `원격까지 점검` 을 누를 때만 돈다. 홈은 원격을 점검하지 않는다 |
| `README.md` "지원 범위" | 자체 검사의 읽기 종수와 GitHub 통과 종수를 6-3 의 넷만큼 올린다 |
| `script/README.md` 의 `forge-selftest.sh` 행 | 읽기 종수를 넷만큼 올린다 |
| `script/README.md` 표에 `run-agent.py` 행을 더한다 | CLI 러너 역할 하나를 실행 계획대로 한 번 돌리는 공용 실행기. `--check` 는 러너 설치·로그인만 확인한다 — 0=준비됨, 2=실행 불가, 3=미로그인, 4=확인 못 함 |

## 9. 회귀 테스트

### 9-1. `render-test.sh` — 새 `UT-<다음 빈 번호>` 블록

원격은 테스트 작업 디렉터리 아래의 bare 리포다. forge 는 `script/forge.sh` 를 `fake-forge.sh` 로 바꿔 끼운다.
forge CLI 설치 확인을 지나도록 `PATH` 앞에 빈 `gh` 스텁을 두고, 리뷰어 러너는 `PATH` 의 `codex` 스텁(종료 코드를 환경 변수로 정한다)으로 대신한다.

| 케이스 | 확인하는 것 |
|---|---|
| 원격 없이 | `doctor` 에 `remote` 절이 없고 `remote checks not run` 줄이 있다. origin 을 닿지 않는 경로로 둬도 결과가 같다. `status` 의 `doctor.items` 에 `section` 이 `remote` 인 항목이 없다 |
| JSON 과 텍스트 | `doctor --json` 이 JSON 객체 하나만 내고, 그 `items` 의 각 항목이 텍스트 출력의 한 줄로 나온다. 두 종료 코드가 같다. `status` 의 `doctor` 값이 `doctor --json` 과 같다 |
| status 키 | `status` 의 최상위 키와 `doctor` 의 키, 항목의 키가 지금과 같다 |
| origin 없음 | `remote` 절에 ``remote `origin` `` `FAIL` 이 있고 base · 기본 브랜치 · 브랜치 보호 줄이 없다. 종료 코드 1 |
| base 가 원격에 없다 | bare 원격에 base 를 push 하지 않으면 ``branch `<base>` on origin`` 이 `FAIL` |
| 준비됨 | base 를 push 하고 bare 원격의 `HEAD` 가 base 면 base · 기본 브랜치 줄이 `ok` |
| 기본 브랜치가 다르다 | bare 원격의 `HEAD` 를 다른 브랜치로 바꾸면 `origin default branch` 가 `warn` 이고 그 브랜치 이름이 detail 에 있다 |
| 닿지 않는 원격 | origin 이 닿지 않는 주소면 base 줄이 `warn` `could not check`. origin 주소에 넣은 표지 문자열이 출력(텍스트·JSON)에 없다 |
| forge 미인증 | 페이크의 인증을 실패로 두면 ``sign-in to `<kind>` `` 이 `FAIL` 이고 detail 에 페이크의 안내 줄이 있다. 라벨 · 브랜치 보호 줄이 없다 |
| 라벨 | 페이크가 설정 라벨 하나를 빼고 내면 그 라벨만 `warn`. 대소문자만 다르면 `ok`. 종료 코드 3 이면 라벨 줄이 없다. 배열이 아니면 `labels` `warn` `could not check` 한 줄 |
| 브랜치 보호 | 페이크가 base 를 보호됨으로 내면 `ok`, 아니면 `warn`. origin 에 없는 보호 브랜치는 줄이 없다 |
| 리뷰어 러너 | `codex` 스텁이 `login status` 에 0 이면 `ok` `signed in`, 1 이면 `FAIL`. `PATH` 에 스텁이 없으면 `FAIL`. `roles.code-reviewer.runner = inproc` 이면 줄이 없다 |
| 지표 | `doctor --remote` 가 실행 지표를 남기지 않는다 |
| 자리표시자 표지 | `.ai/project/` 문서의 `<!-- TBD` 를 모두 채우고 본문에 낱말 `TBD` 만 남기면 그 문서 줄이 `ok`. `<!-- TBD` 두 곳이면 `2 placeholder(s)` |
| 어댑터 표지 | 머리글 표지가 없는 어댑터의 본문 주석에 `미검증` 이 있어도 `ok`. 머리글에 `검증 상태: 미검증` 이 있으면 `warn` |

`run-agent.py --check` 는 손으로 쓴 실행 계획으로 따로 본다.

| 케이스 | 확인하는 것 |
|---|---|
| 로그인됨 | 스텁이 0 이면 종료 코드 0, 표준 출력 `signed-in` |
| 미로그인 | 스텁이 1 이면 종료 코드 3, 표준 오류에 `is not signed in`. 스텁이 표준 출력에 낸 표지 문자열이 출력에 없다 |
| 확인 선언 없음 | `auth_check` 가 빈 목록이면 종료 코드 0, `unchecked`. 스텁이 불리지 않는다 |
| 실행 불가 | 서브에이전트 역할 · 설치되지 않은 실행 파일이면 종료 코드 2 |
| 지표 | 실행 지표 스팬을 남기지 않는다 |

렌더 결과: `script/harness.plan.json` 의 CLI 러너 역할에 `auth_check` 가 있고 codex 러너면 `["codex", "login", "status"]` 다.
벤더 선언 검사: `auth_check` 의 첫 원소가 `exe` 와 다른 선언을 쓰면 렌더가 멈춘다.

터미널 출력의 한글 검사는 이 블록의 출력에도 적용한다.

### 9-2. `fake-forge.sh`

`tracker_auth` · `review_auth` · `tracker_labels` · `review_branch_protected` 를 더한다. 결과는 환경 변수로 정한다.

| 변수 | 뜻 |
|---|---|
| `FAKE_AUTH` | `fail` 이면 인증 함수가 1 과 안내 한 줄 |
| `FAKE_LABELS` | `tracker_labels` 가 낼 라벨(공백 구분). `none` 이면 종료 코드 3 |
| `FAKE_PROTECTED` | `review_branch_protected` 가 `true` 를 낼 브랜치(공백 구분) |

`FAKE_BREAK` 에 둘을 더한다 — `labels`(배열이 아니라 객체를 낸다), `protected`(`true`/`false` 가 아닌 값을 낸다).
자체 검사가 이 둘을 계약 위반으로 잡는지 기존 자체 검사 케이스와 같은 방식으로 확인한다.

### 9-3. 기존 케이스

doctor 의 텍스트를 읽는 기존 케이스(생성물 불일치 · 자리표시자 · 참조 · 검증 · worktree · registry)는 문구를 바꾸지 않고 통과한다.
`status` 를 읽는 기존 케이스도 그대로 통과한다.

### 9-4. `doctor.test.js`

- `SECTIONS.remote` 가 `"원격"` 이다
- 7-3 의 줄마다 `explain()` 이 원문과 다른 제목을 내고, 조치가 표와 같다
- `detail` 이 `could not check` 로 시작하는 `remote` 줄은 확인하지 못했다는 항목이 된다

## 10. 보호 문서에 반영할 것

사람이 지시한 턴에 반영한다.

| 문서 · 위치 | 반영할 사실 |
|---|---|
| `.ai/project/architecture.md` "신뢰 경계" 의 들어오는 입력 | `doctor --remote` 가 읽는 git·forge·러너 CLI 의 응답. 원격 점검은 읽기 전용이고, 원격 URL 과 CLI 출력을 결과에 옮기지 않는다 |
| `.ai/project/architecture.md` "구성 요소" 의 `src/bin/harness` | doctor 는 점검 결과를 항목 목록으로 모으고 텍스트·JSON 으로 그린다. `status` 는 그 목록을 쓴다 |

## 11. 한계

- 러너 인증은 `auth_check` 를 선언한 벤더만 확인한다. 선언이 없는 벤더는 설치만 본다
- 로그인은 되어 있으나 권한이 부족한 경우(라벨을 만들 수 없는 계정 등)는 점검하지 않는다
- 회차 라벨은 회차마다 이름이 달라 점검하지 않는다
