# #61 task

## T1 · feat: UI 빌드 판정과 서버 기록·상태 판정 함수 추가

### 상위 Requirement

- relates to #61

### 작업 내용

`start-server` · `stop-server` · `server-status` 가 공유하는 판정을 부작용 없는 함수로 `src/bin/harness` 에 둔다.
파일·소켓·HTTP·`ps` 는 부르는 쪽이 읽어 인자로 넘긴다.

- 명세 2-1(UI 소스 해시) · 2-2(빌드가 필요한가) · 3-1(`ui.pid` 형식과 해석) · 3-2(기록과 프로세스의 일치) · 3-3(서버 상태) · 8절
- `ui_source_hash(ui)`: `package.json` · `package-lock.json` · `jsconfig.json` · `next.config.js` 와 `app/` · `components/` · `lib/` 아래
  일반 파일 전부. 경로 구성 요소가 `.` 으로 시작하면 빼고, `skills/` 는 넣지 않는다. UI 루트 기준 POSIX 상대 경로 순으로
  `상대 경로 + NUL + 내용 + NUL` 을 이어 SHA-256 16진 문자열을 낸다. 없는 대상은 건너뛴다
- `needs_build(hash, stamp, build_id_exists)`: 스탬프가 `None`(없음·읽지 못함)이거나, 앞뒤 공백을 뺀 스탬프가 해시와 다르거나,
  `BUILD_ID` 가 없으면 참
- `parse_server_record(text)`: JSON 객체이고 `pid` 는 2 이상의 정수(`bool` 제외), `started` · `root` · `hash` 는 비어 있지 않은 문자열,
  `port` 는 1–65535 의 정수(`bool` 제외)일 때만 dict, 아니면 `None`
- `process_matches(record, ps_output)`: `ps -o pgid=,lstart=` 출력의 첫 필드가 `record["pid"]` 와 같고 나머지(앞뒤 공백 제거)가
  `record["started"]` 와 같을 때만 참. 빈 출력은 거짓
- `server_state(record, matches, root, hash, port_busy, http_ok)`: 명세 3-3 표의 순서로 `other-copy` · `other-build` · `running` ·
  `unresponsive` · `busy` · `free` 중 하나. 맞지 않는 기록은 기록 없음과 같게 다룬다
- `render-test.sh` 에 새 UT 블록 하나: `importlib.machinery.SourceFileLoader` 로 `src/bin/harness` 를 불러 다섯 함수를 직접 부른다.
  해시 대상 트리는 임시 디렉터리에 만든다
- 건드릴 파일: `src/bin/harness`, `src/test/render-test.sh`

### 완료 조건

- [ ] 같은 트리의 해시가 두 번 같고, 해시 대상 파일 하나를 고치면 해시가 바뀌며, `skills/` 아래 파일이나 점으로 시작하는 파일을 고치면 그대로다
- [ ] `needs_build` 가 스탬프 = 해시이고 `BUILD_ID` 가 있을 때만 거짓이다
- [ ] `parse_server_record` 가 명세 8-2 의 잘못된 입력 전부에 `None` 을 낸다
- [ ] `process_matches` 가 그룹 id 와 시각이 모두 같을 때만 참이다
- [ ] `server_state` 가 명세 3-3 표의 각 행과 8-3 의 고정 케이스를 명세대로 낸다
- [ ] 다섯 함수가 파일 쓰기·소켓·서브프로세스를 하지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/61-start-server-background` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 해시의 결정성 | 같은 트리로 두 번 | 같은 값 |
| UT-02 | 해시 대상의 변경 | `app/` · `components/` · `lib/` 의 파일 하나, `package.json` · `package-lock.json` · `jsconfig.json` · `next.config.js` 를 하나씩 고침 | 각각 해시가 바뀐다 |
| UT-03 | 해시 대상 밖의 변경 | `skills/` 아래 파일, `app/` 아래 점으로 시작하는 파일을 고침 | 해시가 그대로다 |
| UT-04 | 빌드 불필요 | 스탬프 = 해시(뒤에 개행), `BUILD_ID` 있음 | `needs_build` 거짓 |
| UT-05 | 빌드 필요 | 스탬프 없음 · 스탬프 ≠ 해시 · `BUILD_ID` 없음 | 각각 참 |
| UT-06 | 기록 해석 성공 | 필드가 모두 맞는 JSON | dict |
| UT-07 | 기록 해석 실패 | JSON 아님 · 배열 · 필드 누락 · `pid` 가 `0` · `1` · `-5` · `true` · `"123"` · `port` 가 `0` · `70000` · 빈 `root` | 각각 `None` |
| UT-08 | 프로세스 일치 | 그룹 id·시각이 기록과 같은 `ps` 출력(앞뒤 공백 포함) | 참 |
| UT-09 | 프로세스 불일치 | 빈 출력 · 그룹 id 다름 · 시각 다름 | 각각 거짓 |
| UT-10 | 상태 표의 각 행 | 명세 3-3 표의 행마다 맞는 입력 | `other-copy` · `other-build` · `running` · `unresponsive` · `busy` · `free` |
| UT-11 | 맞지 않는 기록 | 루트·해시가 다른 기록 + `matches` 거짓 + 포트 사용 중 / 포트 비어 있음 | `busy` / `free` |
| UT-12 | 응답만으로 하네스 서버로 보지 않음 | 기록 없음 + 포트 사용 중 + `http_ok` | `busy` |
| UT-13 | 다른 사본이 응답함 | 맞는 기록 + 루트 다름 + `http_ok` | `other-copy` |

## T2 · feat: stop-server 와 server-status 명령 추가

### 상위 Requirement

- relates to #61

### 작업 내용

기록이 살아 있는 프로세스와 맞을 때만 서버 프로세스 그룹을 멈추는 `harness stop-server` 와, 서버 상태를 한 줄로 알리는
`harness server-status` 를 더한다.

- 명세 5절(`server-status`) · 6절(`stop-server`) · 7-1(CLI 등록)
- `ui.pid` 읽기: 파일 없음 · 읽지 못함(`parse_server_record` 가 `None`) · 기록을 가른다. 기록이 있으면 `LC_ALL=C ps -o pgid=,lstart= -p <pid>` 의
  출력을 `process_matches` 에 넘긴다
- `server-status`: 포트 연결(`127.0.0.1:<포트>`)과 `GET /` 1초 제한의 200 여부를 구해 `server_state` 에 넘기고, 명세 5절 표의 줄과 종료 코드를 낸다.
  파일을 바꾸지 않는다. 읽지 못한 기록은 표준 오류 안내와 종료 코드 2
- `stop-server`: 명세 6-1 표대로. 맞는 기록이면 6-2 의 중지 절차 — 다시 확인, `SIGTERM` 을 그룹에, 0.1초 간격 10초 대기, 남으면 `SIGKILL` 과 5초 대기,
  그래도 남거나 `killpg` 가 권한 오류를 내면 `ui.pid` 를 두고 종료 코드 2. 없어지면 `ui.pid` 를 지운다. 이 절차는 T3 이 다시 쓰도록 함수 하나로 둔다
- `COMMANDS` 에 두 항목(설정 불필요), `main()` 이 두 명령을 대상 리포 없이 부른다. `DELEGATES` 에는 넣지 않는다.
  `cmd_help` 의 명령 이름 칸을 `server-status` 길이에 맞춘다
- 건드릴 파일: `src/bin/harness`

### 완료 조건

- [ ] `ui.pid` 가 없으면 `stop-server` 가 `stop-server: not running` 을 내고 종료 코드 0 이다
- [ ] 읽지 못하는 `ui.pid` 는 `stop-server` 가 지우고 프로세스를 건드리지 않는다. `server-status` 는 같은 파일에 종료 코드 2 와 명세 5절의 안내를 내고 파일을 남긴다
- [ ] 기록의 시각이 실제 프로세스와 다르면 `stop-server` 가 파일만 지우고 `not running (removed a stale record)` 를 낸다
- [ ] 맞는 기록이면 UI 루트·해시가 달라도 그룹을 멈추고 `stopped (pid <pid>)` 를 낸 뒤 `ui.pid` 를 지운다 — 손으로 띄운 `sleep` 그룹으로 확인
- [ ] 멈추지 않거나 권한 오류가 나면 `ui.pid` 가 남고 종료 코드 2 다
- [ ] `stop-server` 가 기록 없이 포트를 쓰는 프로세스를 멈추지 않는다
- [ ] `server-status` 가 명세 5절 표의 상태별 줄과 종료 코드를 낸다
- [ ] `harness help` 에 두 명령이 나오고 명령 이름 칸이 어긋나지 않는다
- [ ] 대상 리포 밖에서도, 고정된 사본이 있는 리포 안에서도 두 명령이 전역 설치의 것으로 돈다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/61-start-server-background` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 판정은 T1 의 UT 블록이 고정한다 | — | 명령 함수는 `ps` · 소켓 · 시그널을 부르므로 자동 테스트하지 않는다 (명세 8절). 완료 조건을 손으로 확인한다 |

## T3 · feat: start-server 가 필요할 때 빌드하고 백그라운드로 기동

### 상위 Requirement

- relates to #61

### 작업 내용

`harness start-server` 를 백그라운드 기동으로 바꾼다. UI 소스가 지난 빌드와 다를 때만 `next build` 를 하고, 새 세션의 `next start` 가
200 을 돌려주면 URL 한 줄을 내고 돌아온다. 지금의 포그라운드 `next dev` 는 `--dev` 로 남긴다.

- 명세 1절 · 2-3(빌드) · 4절(`start-server [--dev]`) · 7-1(인수와 플래그)
- 기동 전 판정: 현재 UI 루트·해시로 `server_state` 를 구하고 낡은 기록은 지운다. `running` 은 already running 과 종료 코드 0,
  `other-copy` · `other-build` · `unresponsive` · `busy` 는 명세 4-2 의 안내로 표준 오류·종료 코드 2. 서버를 건드리지 않는다
- 기동: `ui.log` 를 비운다(0600) → `node_modules` 가 디렉터리로 없으면 설치(출력은 `ui.log`) → `needs_build` 가 참이면
  `node_modules` 심볼릭 링크 검사 뒤 `node_modules/.bin/next build`(출력은 `ui.log`), 성공하면 `.next/harness-ui-hash` 에 해시를 쓴다 →
  `node_modules/.bin/next start -H 127.0.0.1 -p <포트>` 를 `start_new_session` 으로 띄운다(작업 디렉터리 UI 루트, 표준 입력 `/dev/null`,
  출력 `ui.log`, 환경에 `HARNESS_HOME` · `HARNESS_BIN`) → 곧바로 `LC_ALL=C ps -o lstart=` 로 `started` 를 구해 `ui.pid`(0600)에 쓴다 →
  0.25초 간격으로 `GET /` 를 보내 200 이면 URL 한 줄을 내고 종료 코드 0
- 실패: 프로세스가 먼저 끝나거나 30초 안에 200 이 없으면 T2 의 중지 함수로 그룹을 멈추고 `ui.pid` 를 지운 뒤 명세 4-1 의 안내로 종료 코드 2.
  설치·빌드 실패와 심볼릭 링크는 명세 2-3 의 안내
- `--dev`: argparse 플래그(`help="start-server: run next dev in the foreground"`). 사본·npm 확인·첫 설치는 지금과 같고(출력은 터미널),
  상태가 `free` 가 아니면 명세 4-3 의 안내로 종료 코드 2, `free` 면 지금처럼 URL 을 내고 `next dev` 로 `execvp`. 빌드 판정·링크 검사·`ui.pid` · `ui.log` 를 거치지 않는다
- `COMMANDS` 의 `start-server` 행을 명세 7-1 의 인수·설명으로 고친다
- 건드릴 파일: `src/bin/harness`

### 완료 조건

- [ ] 빌드가 없는 UI 에서 `harness start-server` 가 `building the UI` 한 줄과 URL 한 줄을 내고 돌아오며, 브라우저로 그 URL 이 열린다
- [ ] UI 소스를 고치지 않고 멈췄다 다시 띄우면 빌드 없이 URL 만 낸다. `app/` 아래 파일을 고치면 다음 기동이 빌드한다
- [ ] 떠 있는 서버에 다시 `start-server` 를 하면 `already running at` 과 종료 코드 0 이고 두 번째 서버가 뜨지 않는다
- [ ] 기록 없이 다른 프로세스가 포트를 쓰면 `busy` 안내로 멈추고 그 프로세스를 건드리지 않는다
- [ ] 떠 있는 서버의 기록 해시와 현재 해시가 다르면 `other-build` 안내로 멈추고 서버를 건드리지 않는다
- [ ] `node_modules` 가 심볼릭 링크이고 빌드가 필요하면 빌드 전에 명세 2-3 의 안내로 종료 코드 2 다
- [ ] 빌드가 실패하면 스탬프가 쓰이지 않고 `ui.log` 경로를 안내한다
- [ ] 서버가 뜨지 않으면(예: `next start` 가 곧바로 끝남) 그룹이 남지 않고 `ui.pid` 가 없으며 `ui.log` 경로를 안내한다
- [ ] `ui.pid` · `ui.log` 의 권한이 0600 이다
- [ ] `--dev` 가 포트가 비어 있으면 지금처럼 포그라운드 `next dev` 로 돌고, 떠 있는 서버가 있으면 `stop-server` 를 안내하며 멈춘다
- [ ] 고정된 사본에서 부르면 지금의 안내로 멈춘다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/61-start-server-background` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 판정은 T1 의 UT 블록이 고정한다 | — | 기동·응답 대기·중지는 실제 시각과 대기에 기대므로 자동 테스트하지 않는다 (명세 8절). 완료 조건을 손으로 확인한다 |

## T4 · feat: 없는 프로젝트 화면이 404 를 반환

### 상위 Requirement

- relates to #61

### 작업 내용

등록부에 없는 이름이나 쓸 수 없는 경로의 프로젝트 경로(`/<이름>/...`)가 지금은 200 과 빈 화면을 낸다. 같은 조건에서 404 를 내게 한다.

- 명세 7-2
- `src/ui/app/[project]/layout.js` 에서 `current?.ok` 가 거짓이면 `next/navigation` 의 `notFound()` 를 부른다. 판정 조건은 지금 빈 화면을
  보이는 조건과 같다. 빈 화면 분기는 지운다
- 건드릴 파일: `src/ui/app/[project]/layout.js`

### 완료 조건

- [ ] 등록되지 않은 이름의 경로(`/nope/settings`)가 404 를 돌려준다
- [ ] 등록된 프로젝트의 화면은 지금처럼 200 이다
- [ ] 경로가 기록되지 않은 등록(`ok` 거짓)의 화면이 404 를 돌려준다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/61-start-server-background` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 화면 자동 테스트 없음 | — | UI 화면은 자동 테스트 대상이 아니다. 완료 조건의 세 경로를 손으로 확인한다 |

## T5 · docs: README 에 백그라운드 UI 서버와 중지·상태 명령 안내

### 상위 Requirement

- relates to #61

### 작업 내용

사람용 README 에 바뀐 `start-server` 와 새 두 명령을 적는다.

- 명세 7-3
- 명령 표: `start-server` 행을 백그라운드 기동·빌드 판정·`--dev` 로 고치고 `stop-server` · `server-status` 행을 더한다
- UI 절: 백그라운드로 돌고 URL 을 내고 돌아온다는 것, `ui.pid` · `ui.log` 가 등록부 최상위에 있다는 것, UI 소스가 바뀌면 다음 기동이
  빌드한다는 것, 다른 사본·옛 빌드의 서버가 떠 있으면 `stop-server` 를 먼저 한다는 것, `node_modules` 를 심볼릭 링크로 두지 않는다는 것
- 건드릴 파일: `README.md`

### 완료 조건

- [ ] README 명령 표에 `start-server [--dev]` · `stop-server` · `server-status` 가 있고 설명이 T3 · T2 의 동작과 맞다
- [ ] UI 절이 명세 7-3 의 다섯 사실을 담는다
- [ ] 포그라운드 `next dev` 를 기본 동작으로 적은 문장이 남지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/61-start-server-background` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 문서 변경 | — | 해당 없음. 완료 조건을 읽어 확인한다 |

## T6 · docs: 아키텍처·담당 범위 문서에 UI 서버 기동 흐름과 명령 반영

### 상위 Requirement

- relates to #61

### 작업 내용

에이전트가 근거로 읽는 사실 문서를 바뀐 동작에 맞춘다. 두 파일은 보호 문서이고, 이 개정은 이 이슈 범위에서 사용자가 지시한 것이다.

- 명세 7-4
- `.ai/project/architecture.md`
  - 구성 요소의 "기기 단위 상태": 등록부 최상위의 `ui.pid`(백그라운드 UI 서버 기록) · `ui.log`(그 기동의 설치·빌드·서버 출력)
  - 구성 요소의 `src/ui/`: `harness start-server` 가 필요할 때 빌드하고 백그라운드로 띄운다
  - 데이터 흐름의 "UI": `harness start-server` → (UI 소스 해시가 `.next` 스탬프와 다르면) `next build` → 새 세션의 `next start`(루프백) →
    `ui.pid` · `ui.log` 흐름을 앞에 더한다
- `.ai/project/scope.md`: "할 수 있는 일" 의 웹 UI 줄 괄호를 `start-server` · `stop-server` · `server-status` 로
- 두 파일을 고친 뒤 `harness render` 로 `.ai/AI_AGENT.md` 를 다시 만든다
- 건드릴 파일: `.ai/project/architecture.md`, `.ai/project/scope.md`, `.ai/AI_AGENT.md`(생성물)

### 완료 조건

- [ ] `architecture.md` 의 기기 단위 상태·`src/ui/` · 데이터 흐름 "UI" 가 명세 7-4 의 서술을 담는다
- [ ] `scope.md` 의 웹 UI 줄이 세 명령을 적는다
- [ ] `.ai/AI_AGENT.md` 가 두 문서와 일치하고 `harness check` 가 통과한다
- [ ] 명세 7-4 밖의 절은 바뀌지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/61-start-server-background` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | `harness check` | 통과 |
