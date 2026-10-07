# UI 서버의 백그라운드 기동·상태 확인·중지

`harness start-server` 는 빌드된 UI 를 백그라운드로 띄우고, 응답이 오면 URL 한 줄을 내고 돌아온다.
UI 소스가 지난 빌드와 달라졌을 때만 빌드한다. `harness server-status` 가 서버 상태를, `harness stop-server` 가
중지를 맡는다. UI 개발용 포그라운드 `next dev` 는 `start-server --dev` 로 남는다. 없는 프로젝트 화면은 404 를 낸다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 기동·빌드 판정·상태·중지 (`cmd_start_server` · `cmd_stop_server` · `cmd_server_status`, 판정 함수) | `src/bin/harness` |
| 없는 프로젝트의 404 | `src/ui/app/[project]/layout.js` |
| 회귀 테스트 | `src/test/render-test.sh` |
| 사람용 설명 | `README.md` |
| 에이전트용 사실 | `.ai/project/architecture.md` · `.ai/project/scope.md` (7절) |

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

- 서버는 지금처럼 루프백(`127.0.0.1`)의 포트 `7777`(`UI_PORT`)에만 묶는다
- UI 는 지금처럼 전역 설치에만 있다. 고정된 사본(`.harness/`)에서 부르면 지금의 안내로 멈춘다
- 첫 실행의 `npm install` 은 지금처럼 `node_modules` 가 디렉터리로 없을 때만 돈다
- UI 가 실행할 때 읽는 `HARNESS_HOME` · `HARNESS_BIN` 은 지금처럼 서버 프로세스의 환경으로 넘긴다. 빌드는 이 값을
  굳히지 않는다
- 새 파일은 등록부 최상위(`HARNESS_HOME`, 없으면 `~/.harness/`)의 둘이다

| 파일 | 내용 | 권한 |
|---|---|---|
| `ui.pid` | 백그라운드 서버 기록(3-1) | 0600 |
| `ui.log` | 백그라운드 기동 한 번의 `npm install` · `next build` · `next start` 출력. 기동할 때마다 비우고 새로 쓴다 | 0600 |

- 두 파일은 프로젝트 디렉터리가 아니라 등록부 최상위에 있다. 서버 하나가 등록된 프로젝트 전부를 보이므로
  프로젝트별 키 아래에 두지 않는다. 기기 단위 상태의 키를 프로젝트 이름에서 다른 값으로 바꾸는 작업(#96)의
  재키잉 대상이 아니다
- UI 의 프로젝트 목록은 등록부의 디렉터리만 읽으므로 두 파일은 목록에 뜨지 않는다
- 빌드 산출물과 빌드 스탬프는 UI 루트의 `.next/` 안에 둔다. `next dev` 의 산출물(`.next/dev/`)과 따로 있다
- 여러 `start-server` 를 동시에 돌리는 경우는 다루지 않는다

## 2. 빌드 판정

### 2-1. UI 소스 해시

`ui_source_hash(ui)` 는 UI 루트(`ROOT / "ui"`) 아래 다음 대상의 SHA-256 을 16진 문자열로 낸다.

| 대상 | 넣는 까닭 |
|---|---|
| `package.json` | 모듈 형식(`"type"`)과 스크립트가 빌드에 닿는다 |
| `package-lock.json` | 의존성 버전 |
| `jsconfig.json` | `@/` 경로 별칭 |
| `next.config.js` | 빌드 설정 |
| `app/` · `components/` · `lib/` 아래 파일 전부(하위 디렉터리 포함) | 앱 소스 |

- `skills/` 는 넣지 않는다. 서버가 실행할 때 파일로 읽는 것이라 빌드 결과에 들어가지 않는다
- 경로의 어느 구성 요소가 `.` 으로 시작하면 뺀다. 일반 파일만 넣는다
- 파일을 UI 루트 기준 POSIX 상대 경로 순으로 정렬하고, 파일마다 `상대 경로 + NUL + 내용 + NUL` 을 이어 해시한다.
  없는 대상은 건너뛴다

### 2-2. 빌드가 필요한가

`needs_build(hash, stamp, build_id_exists)` 는 아래 중 하나면 참이다.

- 스탬프(`.next/harness-ui-hash`)가 없다 · 읽히지 않는다
- 스탬프의 내용(앞뒤 공백 제거)이 현재 해시와 다르다
- `.next/BUILD_ID` 가 없다

거짓이면 빌드 없이 기동한다.

### 2-3. 빌드

1. `node_modules` 가 심볼릭 링크면 빌드 전에 멈춘다 (종료 코드 2)

```
error: the UI's node_modules is a symbolic link, which the UI build cannot use
  --> <UI 루트>/node_modules

help: remove the link and run `harness start-server` again — it reinstalls the dependencies
```

2. 표준 출력에 `start-server: building the UI` 한 줄을 내고, `<UI 루트>/node_modules/.bin/next build` 를 UI 루트에서
   돌린다. 출력은 `ui.log` 로 간다
3. 성공하면 현재 해시를 `.next/harness-ui-hash` 에 한 줄로 쓴다. 실패하면 스탬프를 쓰지 않고 멈춘다 (종료 코드 2)

```
error: the UI build failed
  --> <등록부>/ui.log

help: read the log above, fix the cause, and run `harness start-server` again
```

`npm install` 도 백그라운드 기동 경로에서는 출력을 `ui.log` 로 보내고, 표준 출력에는 지금의
`start-server: installing UI dependencies (first run)` 한 줄만 낸다. 실패 안내는 `--> <등록부>/ui.log` 를 더한다.

## 3. 서버 기록과 식별

### 3-1. `ui.pid`

JSON 객체 하나다.

| 키 | 값 |
|---|---|
| `pid` | 서버 프로세스 id. 프로세스 그룹 id 와 같다(새 세션으로 띄운다) |
| `started` | 띄운 직후 `ps -o lstart= -p <pid>` 의 출력(앞뒤 공백 제거) |
| `root` | UI 루트의 절대 경로 |
| `hash` | 기동한 빌드의 UI 소스 해시(2-1) |
| `port` | 포트 |

`parse_server_record(text)` 는 아래를 모두 만족할 때 dict 를, 아니면 `None`(읽지 못함)을 낸다.

- JSON 객체다
- `pid` 는 2 이상의 정수다. `bool` 은 정수로 보지 않는다 — 0 · 1 · 음수는 `killpg` 가 엉뚱한 그룹을 가리킨다
- `started` · `root` · `hash` 는 비어 있지 않은 문자열이다
- `port` 는 1–65535 의 정수다(`bool` 제외)

파일이 없으면 기록 없음, 파일이 있으나 `None` 이면 읽지 못한 기록이다.

### 3-2. 기록과 살아 있는 프로세스가 맞는가

`process_matches(record, ps_output)` 는 `LC_ALL=C ps -o pgid=,lstart= -p <record.pid>` 의 표준 출력을 받아,
첫 필드(프로세스 그룹 id)가 `record.pid` 와 같고 나머지(앞뒤 공백 제거)가 `record.started` 와 같을 때만 참이다.
출력이 비었으면(프로세스 없음) 거짓이다. 기록 시각을 비교하므로 같은 pid 를 다시 받은 다른 프로세스는 맞지 않는다.
`started` 를 기록할 때도 `LC_ALL=C` 로 부른다.

프로세스 이름이나 명령줄은 보지 않는다. `next start` 는 자기 프로세스 이름을 바꾼다.

맞지 않는 기록은 낡은 기록이다.

### 3-3. 서버 상태

`server_state(record, matches, root, hash, port_busy, http_ok)` 는 아래 표로 상태 하나를 낸다. `record` 는 3-1 의
dict 또는 `None`(기록 없음·읽지 못함), `matches` 는 3-2 의 결과, `root` · `hash` 는 지금 부르는 하네스의 UI 루트와
해시, `port_busy` 는 `127.0.0.1:<포트>` TCP 연결 성공 여부, `http_ok` 는 `GET http://127.0.0.1:<포트>/` 가 1초 안에
200 을 돌려주는지다.

| 조건 (위에서부터 먼저 맞는 것) | 상태 |
|---|---|
| `record` 가 있고 `matches` 이며 `record.root != root` | `other-copy` |
| `record` 가 있고 `matches` 이며 `record.hash != hash` | `other-build` |
| `record` 가 있고 `matches` 이며 `http_ok` | `running` |
| `record` 가 있고 `matches` | `unresponsive` |
| `port_busy` | `busy` |
| 그 밖 | `free` |

`record` 가 있고 `matches` 가 거짓이면 기록이 없는 것처럼 아래 두 줄로 간다.

## 4. `harness start-server [--dev]`

### 4-1. 백그라운드 기동 (기본)

1. UI 사본 확인과 npm 확인은 지금과 같다
2. `ui.pid` 를 읽어 3-3 상태를 구한다. `root` · `hash` 는 현재 UI 루트와 2-1 해시다. 낡은 기록(3-2 거짓)이면
   `ui.pid` 를 지운다
3. 상태별로 가른다

| 상태 | 동작 | 종료 코드 |
|---|---|---|
| `running` | `start-server: already running at http://localhost:<포트>` 를 표준 출력에 낸다 | 0 |
| `other-copy` | 안내(4-2)를 내고 멈춘다. 서버를 건드리지 않는다 | 2 |
| `other-build` | 안내(4-2)를 내고 멈춘다. 서버를 건드리지 않는다 | 2 |
| `unresponsive` | 안내(4-2)를 내고 멈춘다. 서버를 건드리지 않는다 | 2 |
| `busy` | 안내(4-2)를 내고 멈춘다 | 2 |
| `free` | 4번으로 간다. 읽지 못한 기록은 6번이 새 기록으로 덮는다 | — |

4. `ui.log` 를 비운다. `node_modules` 가 디렉터리로 없으면 설치한다(2-3 끝). 2-2 가 참이면 빌드한다(2-3)
5. `<UI 루트>/node_modules/.bin/next start -H 127.0.0.1 -p <포트>` 를 새 세션(`start_new_session`)으로 띄운다.
   작업 디렉터리는 UI 루트, 표준 입력은 `/dev/null`, 표준 출력·오류는 `ui.log` 다
6. 곧바로 3-1 기록을 `ui.pid` 에 쓴다
7. 0.25초 간격으로 `GET http://127.0.0.1:<포트>/` 를 보낸다. 200 이 오면 `start-server: http://localhost:<포트>` 한 줄을
   표준 출력에 내고 종료 코드 0 으로 돌아온다
8. 200 전에 프로세스가 끝나면, 또는 30초 안에 200 이 오지 않으면 프로세스 그룹을 중지하고(6-2 의 2–4번) `ui.pid` 를
   지운 뒤 멈춘다 (종료 코드 2)

```
error: the UI server did not come up on http://localhost:<포트>
  --> <등록부>/ui.log

help: read the log for the cause, then run `harness start-server` again
```

성공 경로의 표준 출력은 7번의 URL 한 줄이다. 설치·빌드를 한 실행은 그 앞에 진행 한 줄씩(2-3)이 더 붙는다.

### 4-2. 기동하지 않는 상태의 안내

모두 영어로 `error:` · `-->` · `help:` 형식이고 표준 오류로 낸다.

`other-copy`:

```
error: a harness UI from another copy is already running on http://localhost:<포트>
  --> <record.root>

help: run `harness stop-server`, then `harness start-server` again
```

`other-build`:

```
error: the running harness UI was built from an older version of this copy
  --> <record.root>

help: run `harness stop-server`, then `harness start-server` again
```

`unresponsive`:

```
error: the harness UI (pid <pid>) is running but does not respond on http://localhost:<포트>
  --> <등록부>/ui.log

help: run `harness stop-server`, then `harness start-server` again
```

`busy`:

```
error: port <포트> is in use by another process
  --> http://localhost:<포트>

help: stop the process using the port, then run `harness start-server` again
```

`busy` 의 help 는 `stop-server` 를 권하지 않는다 — 그 프로세스는 하네스가 띄운 서버로 확인되지 않았다.

### 4-3. `--dev`

UI 개발용이다. 기록을 남기지 않고 포그라운드에서 돈다.

1. UI 사본 확인·npm 확인·첫 설치는 지금과 같다(출력은 지금처럼 터미널로)
2. 3-3 상태가 `free` 가 아니면 멈춘다 (종료 코드 2). `running` · `other-copy` · `other-build` · `unresponsive` 는
   4-2 의 `other-copy` 와 같은 help(`stop-server`)를, `busy` 는 4-2 의 `busy` 안내를 낸다. `running` 의 error 줄은
   `error: a harness UI is already running on http://localhost:<포트>` 다
3. 지금처럼 `start-server: http://localhost:<포트>` 를 내고 `next dev -H 127.0.0.1 -p <포트>` 로 `execvp` 한다

`--dev` 는 빌드 판정·심볼릭 링크 검사·`ui.pid` · `ui.log` 를 거치지 않는다.

## 5. `harness server-status`

`ui.pid` 를 읽어 3-3 상태를 구해 한 줄로 알린다. 파일을 바꾸지 않는다(낡은 기록도 지우지 않는다).

| 상태 | 표준 출력 | 종료 코드 |
|---|---|---|
| `running` | `server-status: running at http://localhost:<포트> (pid <pid>)` | 0 |
| `other-copy` · `other-build` | `running` 과 같은 줄 + `note: this server is from another copy or an older build — run \`harness stop-server\`, then \`harness start-server\`` | 0 |
| `unresponsive` | `server-status: pid <pid> is running but http://localhost:<포트> does not respond` | 1 |
| `busy` | `server-status: not running (port <포트> is in use by another process)` | 1 |
| `free` | `server-status: not running` | 1 |

`ui.pid` 가 있으나 읽지 못하면 아래를 표준 오류로 내고 종료 코드 2 다.

```
error: the UI server record could not be read
  --> <등록부>/ui.pid

help: run `harness stop-server` to clear it
```

## 6. `harness stop-server`

### 6-1. 판정

| `ui.pid` | 동작 | 표준 출력 | 종료 코드 |
|---|---|---|---|
| 없다 | 아무것도 하지 않는다 | `stop-server: not running` | 0 |
| 읽지 못한다 | 파일을 지운다. 프로세스를 건드리지 않는다 | `stop-server: removed an unreadable record; no process was stopped` | 0 |
| 낡은 기록(3-2 거짓) | 파일을 지운다. 프로세스를 건드리지 않는다 | `stop-server: not running (removed a stale record)` | 0 |
| 맞는 기록(3-2 참) | 6-2 로 멈춘다. UI 루트·해시가 달라도 멈춘다 | `stop-server: stopped (pid <pid>)` | 0 |

`stop-server` 는 포트를 쓰는 프로세스를 찾아 멈추지 않는다. 기록과 살아 있는 프로세스가 맞을 때만 멈춘다.

### 6-2. 중지

1. 기록이 맞는지(3-2) 다시 확인한다
2. `os.killpg(pid, SIGTERM)`
3. 0.1초 간격으로 확인해 10초 안에 프로세스가 없어지면 5번으로 간다
4. 남아 있으면 `os.killpg(pid, SIGKILL)` 을 보내고 5초 더 기다린다. 그래도 남아 있으면 `ui.pid` 를 지우지 않고 멈춘다
   (종료 코드 2)

```
error: the UI server (pid <pid>) did not stop

help: check the process yourself, then run `harness stop-server` again
```

5. 없어지면 `ui.pid` 를 지운다

`killpg` 가 권한 오류를 내면 같은 형식의 error 로 멈추고 `ui.pid` 를 지우지 않는다.

## 7. 명령 등록과 문서

### 7-1. CLI

- `COMMANDS` 에 두 항목을 더하고 `start-server` 의 인수를 `[--dev]` 로 적는다. 셋 다 설정이 필요 없다

| 이름 | 인수 | 설명 |
|---|---|---|
| `start-server` | `[--dev]` | `build if needed and start the web UI in the background on http://localhost:7777 (--dev: foreground next dev)` |
| `stop-server` | | `stop the web UI started by start-server` |
| `server-status` | | `whether the web UI is running and responding` |

- `main()` 은 `start-server` 처럼 두 명령을 대상 리포 없이 부른다. `DELEGATES` 에는 넣지 않는다 — UI 는 전역 설치의 것이다
- `--dev` 는 argparse 플래그로 더한다 (`help="start-server: run next dev in the foreground"`)
- `cmd_help` 의 명령 이름 칸은 가장 긴 이름(`server-status`)에 맞춘다

### 7-2. UI

`src/ui/app/[project]/layout.js` 는 등록부에서 그 이름의 프로젝트를 찾지 못하거나 그 경로가 쓸 수 없으면
(`!current?.ok`) `next/navigation` 의 `notFound()` 를 부른다. 응답은 404 다. 판정 조건은 지금 빈 화면을 보이는
조건과 같다.

### 7-3. README

- 명령 표: `start-server` 행을 백그라운드 기동·빌드 판정·`--dev` 로 고치고, `stop-server` · `server-status` 행을 더한다
- UI 절: 백그라운드로 돌고 URL 을 내고 돌아온다는 것, `ui.pid` · `ui.log` 위치, UI 소스가 바뀌면 다음 기동이 빌드한다는 것,
  다른 사본·옛 빌드의 서버가 떠 있으면 `stop-server` 를 먼저 한다는 것, `node_modules` 를 심볼릭 링크로 두지 않는다는 것

### 7-4. 보호 문서 개정

이 이슈 범위에서 사용자가 지시한 개정이다. 구현 단계에서 고친다.

- `.ai/project/architecture.md`
  - 구성 요소의 "기기 단위 상태": 등록부 최상위의 `ui.pid`(백그라운드 UI 서버 기록) · `ui.log`(그 기동의 설치·빌드·서버 출력)를 더한다
  - 구성 요소의 `src/ui/`: `harness start-server` 가 필요할 때 빌드하고 백그라운드로 띄운다는 서술
  - 데이터 흐름의 "UI": 앞에 `harness start-server` → (UI 소스 해시가 `.next` 스탬프와 다르면) `next build` → 새 세션의
    `next start`(루프백) → `ui.pid` · `ui.log` 흐름을 더한다
- `.ai/project/scope.md`
  - "할 수 있는 일" 의 웹 UI 줄: 괄호의 명령을 `start-server` · `stop-server` · `server-status` 로

## 8. 테스트

`src/test/render-test.sh` 에 새 UT 블록을 더한다. 번호는 기존 블록과 겹치지 않게 매긴다. 판정 함수를
`importlib.machinery.SourceFileLoader` 로 `src/bin/harness` 에서 불러 직접 부른다. 파일은 임시 디렉터리에만 둔다.

실제 기동·응답 대기·중지는 자동 테스트하지 않는다. 포트 연결·HTTP·`ps` 호출은 판정 함수의 입력으로만 넣는다.

### 8-1. 빌드 판정

| 입력 | 기대 |
|---|---|
| 같은 트리 두 번 | `ui_source_hash` 가 같다 |
| `app/` · `components/` · `lib/` 의 파일 하나, `package.json` · `package-lock.json` · `jsconfig.json` · `next.config.js` 각각을 고침 | 해시가 바뀐다 |
| `skills/` 아래 파일, 점으로 시작하는 파일을 고침 | 해시가 그대로다 |
| 스탬프 = 해시, `BUILD_ID` 있음 | `needs_build` 거짓 |
| 스탬프 없음 · 스탬프 ≠ 해시 · `BUILD_ID` 없음 | 각각 참 |

### 8-2. 서버 기록 해석

| 입력 | 기대 |
|---|---|
| 필드가 모두 맞는 JSON | dict |
| JSON 아님 · 배열 · 필드 누락 · `pid` 가 `0` · `1` · `-5` · `true` · `"123"` · `port` 가 `0` · `70000` · 빈 `root` | `None` |
| `ps` 출력의 그룹 id 와 시각이 기록과 같음 | `process_matches` 참 |
| 빈 출력 · 그룹 id 다름 · 시각 다름 | 거짓 |

### 8-3. 서버 상태

3-3 표의 각 행을 입력으로 넣어 해당 상태를 확인한다. 아울러 아래를 고정한다.

- 맞지 않는 기록 + 포트 사용 중 → `busy` (기록의 루트·해시가 달라도 `other-*` 가 아니다)
- 맞지 않는 기록 + 포트 비어 있음 → `free`
- 기록 없음 + 포트 사용 중 + `http_ok` → `busy` (응답만으로 하네스 서버로 보지 않는다)
- 맞는 기록 + 루트 다름 + `http_ok` → `other-copy` (응답해도 `running` 이 아니다)
