# #206 task

## T1 · refactor: 회귀 테스트와 UI 단위 테스트를 CLI 파일 배치에 기대지 않게 정리

### 상위 Requirement

- relates to #206

### 작업 내용

CLI 를 패키지로 옮기기 전에, 옛 배치(`src/bin/harness` 한 파일과 `src/bin/harness_metrics.py`)에서 회귀 테스트와 UI 단위 테스트가
CLI 의 파일 배치에 기대는 곳을 두 배치 모두에서 도는 형태로 바꾼다. CLI 코드는 고치지 않는다. 검사 줄의 기대값 — 종료 코드 · 출력
문자열 · 파일 상태 — 은 바꾸지 않는다. 고치는 것은 준비부(무엇을 어디에 복사하고 어떻게 불러오나)와 CLI 의 내부 구조를 보는 검사
줄뿐이다.

- 명세 7-1 · 7-2 · 7-4, 6절의 "UI 단위 테스트" `paths` 와 `test_paths`
- `src/test/cli_loader.py`(신규) — 명세 7-2 의 계약
  - `load(<진입 스크립트 경로>)`: 진입 스크립트의 `bin/` 부모에 `harness/__init__.py` 가 있으면 그 부모를 `sys.path` 맨 앞에 넣고
    패키지의 모듈을 전부 불러온다. 없으면 진입 스크립트를 모듈 하나로 불러온다. 불러오기 전에 `sys.dont_write_bytecode` 를 켠다
  - 돌려주는 객체의 `<이름>` 속성은 그 이름을 모듈 최상위에서 정의한(대입 · `def` · `class`) 모듈의 값이다. import 로 받은 이름은
    정의로 치지 않는다
  - `module_of(<이름>)` 은 그 이름을 정의한 모듈을 돌려준다
  - 같은 이름을 두 모듈이 정의하거나 아무 모듈도 정의하지 않으면 예외로 멈춘다
  - 패키지 분기도 이 task 에서 쓴다. 표준 라이브러리만 쓴다
- `src/test/render-test.sh` — 명세 7-2 표의 행마다
  - 소스 트리 복제와 CLI 복제(다른 CLI · Homebrew keg 흉내): `src/` 에서 `ui/` · `test/` · `__pycache__` 를 뺀 전부를 복제 위치에
    복사한다. CLI 를 이루는 파일 이름(`harness_metrics.py` 등)을 케이스마다 적지 않는다
  - 고정 사본의 지표 모듈 확인: `src/` 에서 복사한 실행 부품마다 고정 사본에 같은 바이트의 파일이 있다 — `bin/` → `.harness/bin/`,
    `templates/` → `.harness/templates/`, 그 밖의 디렉터리 → `.harness/lib/<이름>/`. `.harness/bin/` 에 짝이 없는 파일이 없다
  - 바이트코드 흔적: 복제본의 `src/` 아래와 설치본의 `.harness/` 아래 어디에도 `__pycache__` 가 없다. 관리 스크립트의
    `script/__pycache__` 검사는 그대로 둔다
  - 프로세스 안 호출: 진입 스크립트를 `SourceFileLoader` 로 직접 불러오던 곳을 모두 `cli_loader.load()` 로 바꾼다. 모듈 전역 ·
    함수 · 상수를 바꿔 끼우는 곳(`subprocess` · `select` · `os` · `open` · `registry_lock` · `append_range` · `COPY_CHUNK` 등)은
    `module_of(<그 이름을 쓰는 함수>)` 의 모듈에 한다. 그 이름을 쓰는 함수가 명세 3-2 지도에서 서로 다른 모듈로 가면 그 모듈마다
    바꿔 끼운다 — 옛 배치에서는 같은 모듈이라 결과가 같다
  - CLI 원문 검사(표지 상수가 하나인지, forge CLI 를 직접 부르지 않는지, 지운 이름이 없는지, `BASE_PROTECTED` 의 값): CLI 원문
    전부 — `src/bin/` 의 파일과 `src/harness/` 아래 `.py`, `__pycache__` 제외 — 에서 찾는다. `src/harness/` 가 없어도 돈다
- `src/ui/lib/doctor.test.js`: `DOCTOR_DEFAULTS` · `REMOTE_TIMEOUT_LIMIT` · `RUNNER_CHECK_AFTER_START` 를 같은 범위의 CLI 원문에서 읽는다
- `harness.toml` 의 `[verify]`: "UI 단위 테스트" 의 `paths` 에 `src/bin/**` · `src/harness/**` 를 더하고, `test_paths` 에
  `src/harness/**` 를 더한다(명세 6절). `src/bin/harness render` 로 생성 파일을 갱신한다
- 명세 64 12-2 의 "설치본의 지표 모듈" · "소스 리포의 지표 모듈" 케이스는 위의 실행 부품 확인과 바이트코드 흔적 확인이 대신한다(명세 7-4)
- 리뷰 요청 본문에 바꾼 검사 줄마다 전후 대응표를 둔다
- 건드릴 파일: `src/test/render-test.sh`, `src/test/cli_loader.py`(신규), `src/ui/lib/doctor.test.js`, `harness.toml`, render 로 갱신되는 생성 파일

### 완료 조건

- [ ] 옛 배치에서 `src/test/render-test.sh` 전체와 UI 단위 테스트가 통과한다
- [ ] 소스 트리 · CLI 를 복제하는 곳이 모두 `src/` 에서 `ui/` · `test/` · `__pycache__` 를 뺀 전부를 복사하고, `harness_metrics.py` 를 이름으로 적은 줄이 테스트에 없다
- [ ] 진입 스크립트를 `SourceFileLoader` 로 직접 불러오는 줄이 `render-test.sh` 에 없고, 프로세스 안 호출이 모두 `cli_loader` 를 쓴다
- [ ] 바꿔 끼우기가 모두 `module_of(<그 이름을 쓰는 함수>)` 의 모듈에 한다
- [ ] CLI 원문 검사와 `doctor.test.js` 의 상수 대조가 `src/bin/` 의 파일과 `src/harness/` 아래 `.py` 를 함께 읽는다
- [ ] `cli_loader.module_of()` 가 아무 모듈도 정의하지 않은 이름에서 예외를 낸다
- [ ] 이 task 의 diff 에서 바뀐 검사 줄이 명세 7-2 표의 행에 드는 것뿐이고, 기대값(종료 코드 · 출력 문자열 · 파일 상태)이 그대로다
- [ ] 회귀 테스트와 UI 단위 테스트를 돈 뒤 소스 트리에 `__pycache__` 가 없다
- [ ] `[verify]` 의 "UI 단위 테스트" `paths` 와 `test_paths` 가 명세 6절과 같고, render 뒤 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/206-split-cli-into-package` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 옛 배치 회귀 | 바꾼 `render-test.sh` · `doctor.test.js` 를 옛 배치에서 실행 | 전체 통과 |
| UT-02 | 복제 범위 | 소스 트리 복제본의 `src/` | 옛 배치에서 `bin/` · `templates/` 만 있고 `ui/` · `test/` · `__pycache__` 가 없다 |
| UT-03 | 실행 부품 확인 | install 한 리포의 `.harness/` | `src/bin/` 두 파일과 `src/templates/` 아래 파일마다 같은 바이트의 사본이 있고 `.harness/bin/` 에 짝 없는 파일이 없다 |
| UT-04 | 로더의 옛 배치 분기 | `cli_loader.load(src/bin/harness)` | 이름 속성이 진입 스크립트 모듈의 값이고 `module_of()` 가 그 모듈을 돌려준다 |
| UT-05 | 로더의 없는 이름 | `module_of("<어디에도 없는 이름>")` | 예외 |
| UT-06 | 바이트코드 흔적 | 소스 트리 복제본에서 CLI 실행, install 한 리포 | 복제본 `src/` 아래와 `.harness/` 아래에 `__pycache__` 없음 |
| UT-07 | 원문 검사 범위 | `BASE_PROTECTED` · 표지 상수 · forge CLI 직접 호출 · 지운 이름 검사 | `src/bin/` 과 `src/harness/` 범위에서 찾고 옛 배치에서 기대값 그대로 통과 |
| UT-08 | UI 상수 대조 | `doctor.test.js` | 세 상수를 CLI 원문 범위에서 읽어 통과 |

## T2 · refactor: 렌더·대조 본문을 render_target·check_target 으로 떼고 urllib 을 쓰는 함수 안에서 불러옴

### 상위 Requirement

- relates to #206

### 작업 내용

옛 배치에서, 다른 명령이 부르던 명령 진입 함수의 본문을 공용 함수로 뗀다. 패키지로 옮긴 뒤 명령 모듈끼리 부르지 않게 하려는
준비다(명세 3-4). 무거운 모듈을 모듈 최상위에서 불러오지 않게 한다. 동작은 같다.

- 명세 3-1 의 `cmd_render` · `cmd_check` 행과 그 아래 문단, 3-1 의 `urllib.request` 원칙
- `render_target(cfg, target, args, migrate=True)` 가 지금 `cmd_render` 의 본문을 갖는다. `cmd_render(cfg, target, args)` 는 그것을 부른다
- `check_target(cfg, target, args)` 가 지금 `cmd_check` 의 본문을 갖는다. `cmd_check(cfg, target, args)` 는 그것을 부른다
- `install` · `set` · `write-doc` · `steps`(`rename_or_delete_workflow` 포함) · `checks` 는 `render_target()` 을, `status` 는
  `check_target()` 을 부른다. 인자는 지금 `cmd_render` · `cmd_check` 에 넘기던 것 그대로다(`migrate=False` 포함)
- `urllib.request` 는 그것을 쓰는 함수(`http_ok`) 안에서 불러온다. 모듈 최상위에서 `urllib` · `http` 를 불러오지 않는다
- 건드릴 파일: `src/bin/harness`

### 완료 조건

- [ ] `cmd_render` · `cmd_check` 를 부르는 곳이 명령 표의 진입(`main()`) 말고 없다
- [ ] `render_target` · `check_target` 이 명세 3-1 의 시그니처를 갖고, `cmd_render` · `cmd_check` 는 그것을 부르기만 한다
- [ ] `src/bin/harness` 의 모듈 최상위 import 에 `urllib` · `http` 가 없다
- [ ] 회귀 테스트(T1 의 것)를 고치지 않고 전체가 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/206-split-cli-into-package` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 렌더를 부르는 명령의 결과 | 회귀 테스트의 `install` · `set` · `write-doc` · `steps` · `checks` · `render` 케이스 | 기대값 그대로 통과 |
| UT-02 | 대조를 부르는 명령의 결과 | 회귀 테스트의 `check` · `status` 케이스 | 기대값 그대로 통과 |
| UT-03 | 최상위 import | `src/bin/harness` 의 구문 트리 | 모듈 최상위에 `urllib` · `http` import 가 없다 |
| UT-04 | UI 서버 응답 확인 | 회귀 테스트의 `start-server` · `server-status` 케이스 | 기대값 그대로 통과 |

## T3 · feat: 명령줄 해석을 parse_command_line 으로 떼고 명령 표에 통과 표시를 둠

### 상위 Requirement

- relates to #206

### 작업 내용

옛 배치에서 `main()` 안의 인자 해석을 `parse_command_line(argv)` 로 떼고, 이름 뒤의 인자를 공용 파서에 넘기지 않고 그대로 받는 통과
명령의 장치를 둔다. 이 이슈의 명령은 모두 통과 명령이 아니어서 인자 해석이 그대로다. 통과 명령은 그 명령을 더하는 Requirement 가
명령 표에 표시한다.

- 명세 3-3 의 "인자 통과" 전부, 3-1 의 `main()` 안의 인자 해석 · `COMMANDS` 항목의 첫 원소 행
- `COMMANDS` 항목을 `(통과, 설정이 필요한가, 인수, 설명)` 으로 읽는다. 첫 원소는 통과 명령이면 `True`, 그 밖은 `None` 이고, 이
  이슈의 명령은 모두 `None` 이다. 명령 표 머리 주석의 항목 설명을 함께 바꾼다
- `parse_command_line(argv)`: 명령 표를 부를 때 읽고, 공용 파서가 명령 이름으로 읽는 첫 위치 인자(공용 옵션의 값은 위치 인자가
  아니다)로 가른다
  - 없거나 통과 명령이 아니면 지금 파서 그대로 argv 전체를 해석한다. 모르는 명령의 오류도 그대로다
  - 통과 명령이면 이름 앞에는 `--target DIR`(`--target=DIR`)과 `-h` · `--help` 만 받는다. `-h` · `--help` 가 있으면 `help` 로 간다
  - 이름 바로 뒤의 토큰이 `--target` 이면 그다음 토큰을, `--target=DIR` 이면 `=` 뒤를 하네스 루트로 한 번만 받는다
  - 그 밖의 이름 뒤 토큰은 순서 · 내용 그대로 `args.args` 다. 공용 옵션의 다른 속성은 기본값이다
  - 명세 3-3 표의 세 경우는 공용 파서의 오류 형식(사용법 줄 뒤에 `harness: error: <문구>`)으로 2 로 끝난다
- `main()` 은 `parse_command_line(sys.argv[1:])` 의 결과로 지금 순서대로 가른다. `delegate()` 는 지금처럼 `sys.argv[1:]` 를 그대로 넘긴다
- 확인은 T1 의 `src/test/cli_loader.py` 로 옛 진입 스크립트를 불러, 명령 표에 시험용 통과 항목 `probe` 를 잠시 더하고
  `parse_command_line()` 을 부른다. 확인 스크립트는 커밋하지 않는다 — 같은 표를 T5 의 `src/test/unit/test_cli.py` 가 고정한다
- 건드릴 파일: `src/bin/harness`

### 완료 조건

- [ ] `COMMANDS` 의 모든 항목이 네 원소이고 첫 원소가 `None` 이다
- [ ] `main()` 이 인자를 `parse_command_line(sys.argv[1:])` 로만 해석한다
- [ ] `help` 출력과 모든 명령의 인자 해석 · 오류 출력 · 종료 코드가 그대로다 — 회귀 테스트를 고치지 않고 전체가 통과한다
- [ ] 시험용 통과 항목을 더한 `parse_command_line()` 이 명세 7-5 의 `test_cli.py` 표대로 나눈다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/206-split-cli-into-package` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 통과 명령이 아닌 명령 | `set --target D a.b v` · `--target D set a.b v` | 명령 `set`, 하네스 루트 `D`, 인자 `a.b` `v` |
| UT-02 | 이름 뒤를 그대로 받음 | `--target D probe x --json -h --target E` | 명령 `probe`, 하네스 루트 `D`, 인자 `x` `--json` `-h` `--target` `E` |
| UT-03 | 이름 바로 뒤의 하네스 루트 | `probe --target D x` · `probe --target=D x` | 하네스 루트 `D`, 인자 `x` |
| UT-04 | 바로 뒤가 아닌 `--target` | `probe x --target D` · `probe -- --help` | 하네스 루트 `.` 과 인자 `x` `--target` `D` / 인자 `--` `--help` |
| UT-05 | 이름 앞의 도움말 | `-h probe x` | `help` 로 간다 |
| UT-06 | 거부 | `--json probe x` · `--target D probe --target E` · `probe --target` | 종료 코드 2 와 명세 3-3 의 문구 |
| UT-07 | 기존 해석 | 회귀 테스트 전체 | 기대값 그대로 통과 |

## T4 · chore: CLI 컴파일·의존 방향 검사 스크립트를 두고 검증 단계를 그것으로 바꿈

### 상위 Requirement

- relates to #206

### 작업 내용

CLI 원문을 컴파일하고 CLI 패키지의 import 규칙을 구문 트리로 검사하는 프로젝트 스크립트를 두고, 이 리포의 검증 단계를 그것으로
바꾼다. 옛 배치에서 한다 — 패키지가 생기는 T5 의 커밋부터 의존 방향 검사가 패키지를 본다.

- 명세 6절의 `script/project/check-cli.py` 표와 "CLI 가 컴파일된다" · "CLI 패키지 의존 방향" 단계, 3-1 의 절대 경로 규칙, 3-4 의 규칙 표
- `script/project/check-cli.py`(신규): python3 표준 라이브러리만 쓴다. 리포 루트는 이 파일의 위치에서 구한다
  - `compile`: `src/bin/harness` 와 `src/harness/` 아래 `.py` 전부를 `compile()` 한다. 바이트코드를 쓰지 않는다. 실패한 파일마다
    `<경로>:<줄>: <메시지>` 를 표준 오류에 낸다. 모두 되면 0, 아니면 1
  - `imports`: 3-1 의 절대 경로 규칙(패키지 안의 import 는 `harness.` 로 시작)과 3-4 의 규칙 여덟을 각 모듈의 구문 트리로 본다.
    어긴 import 마다 `<경로>:<줄>: <규칙>` 을 표준 오류에 낸다. 순환은 이은 모듈 이름을 한 줄로 낸다. 어긴 것이 없으면 0, 있으면 1
  - 인자가 없거나 그 밖이면 사용법 한 줄을 표준 오류에 내고 2
  - 옛 배치에는 `src/harness/` 가 없다. `compile` 은 진입 스크립트만, `imports` 는 볼 모듈이 없어 0 이다
- `harness.toml` 의 `[verify]`: "CLI 가 컴파일된다" 를 `python3 script/project/check-cli.py compile`(`paths` = `src/bin/**` ·
  `src/harness/**` · `script/project/check-cli.py`)로 바꾸고, 그 바로 뒤에 "CLI 패키지 의존 방향"(`python3 script/project/check-cli.py imports`,
  `paths` = `src/harness/**` · `script/project/check-cli.py`)을 더한다. `src/bin/harness render` 로 `script/harness-verify.sh` 와 규칙 정본의
  검증 순서를 갱신한다
- `script/project/README.md` 표에 `check-cli.py` 한 줄
- 건드릴 파일: `script/project/check-cli.py`(신규), `script/project/README.md`, `harness.toml`, render 로 갱신되는 생성 파일

### 완료 조건

- [ ] 옛 배치에서 `python3 script/project/check-cli.py compile` 과 `imports` 가 0 이고, 실행 뒤 `src/bin/__pycache__` 가 없다
- [ ] 문법 오류를 넣은 임시 사본에서 `compile` 이 1 이고 그 파일의 `<경로>:<줄>: <메시지>` 를 낸다
- [ ] 임시 리포 모양에 규칙을 하나씩 어긴 모듈을 두면 `imports` 가 각각 1 이고 그 import 의 `<경로>:<줄>: <규칙>` 을 낸다 — 상대 import,
  `base` 의 하네스 모듈 import, `text` 의 `base` 밖 import, `metrics/` 의 밖 import, 공용 모듈의 `cli` · `commands` import, 명령 모듈의 다른
  명령 모듈 · `cli` import, `cli` 의 `commands.<명령>` import 문, 모듈 최상위의 `urllib` · `http` import
- [ ] 최상위 import 로 이은 순환이 있으면 `imports` 가 1 이고 이은 모듈 이름을 한 줄로 낸다
- [ ] 인자 없음과 모르는 인자에서 사용법 한 줄과 종료 코드 2
- [ ] `[verify]` 의 두 단계가 명세 6절의 `run` · `paths` · 순서와 같고, render 뒤 생성물이 일치한다
- [ ] `script/project/README.md` 표에 `check-cli.py` 행이 있다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/206-split-cli-into-package` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 옛 배치 컴파일 | 이 리포에서 `check-cli.py compile` | 0, `__pycache__` 없음 |
| UT-02 | 문법 오류 | 진입 스크립트에 문법 오류를 넣은 임시 사본 | 1, `<경로>:<줄>: <메시지>` |
| UT-03 | 옛 배치 의존 방향 | 이 리포에서 `check-cli.py imports` | 0 |
| UT-04 | 규칙 위반 | 규칙마다 어긴 모듈 하나를 둔 임시 `src/harness/` | 1, 어긴 import 의 경로와 줄 |
| UT-05 | 순환 | 최상위 import 로 서로 부르는 두 공용 모듈 | 1, 이은 모듈 이름 한 줄 |
| UT-06 | 사용법 | 인자 없음 · `foo` | 2, 사용법 한 줄 |

## T5 · refactor: CLI 를 진입 스크립트와 패키지로 나누고 고정 사본에 패키지를 설치

### 상위 Requirement

- relates to #206

### 작업 내용

`src/bin/harness` 의 정의와 `src/bin/harness_metrics.py` 를 패키지 `src/harness/` 로 옮기고 `src/bin/harness` 를 진입 스크립트로
줄인다. install 이 패키지를 고정 사본 `.harness/lib/harness/` 에 깔고, 고정 사본 대조와 위임이 새 구성을 따른다. 함수 · 상수 ·
클래스는 명세 3-1 의 표 말고는 본문과 이름을 바꾸지 않고 옮긴다. 결정 근거는 `docs/adr/0019-harness-logic-lives-in-one-python-stdlib-package.md` 다.

- 명세 1절, 2절(2-2 의 2번은 아래), 3절, 4절, 6절의 "Python 단위 테스트" 단계, 7-3 의 "CLI 패키지와 고정 사본", 7-5
- 진입 스크립트(2-2): `tomllib` 확인(지금과 같은 문구 · 종료 코드 1) → 바이트코드 → 패키지 경로(`<base>/lib/harness/` 다음
  `<base>/harness/`, 둘 다 없으면 명세의 `error:` · `help:` 두 줄과 종료 코드 2) → `harness.cli.main()` 의 반환값으로 끝난다.
  2번 자리에서는 `sys.dont_write_bytecode` 를 켠다 — T6 이 5-1 로 바꾼다. 파일 전체를 `match` 문 · 대입 표현식 없이 쓴다
- 실행 위치(2-3): `harness.base` 가 `PACKAGE` · `ROOT` · `TEMPLATES` · `DEFAULT_CONFIG` · `ENTRY` 를 패키지 자기 위치에서 구한다.
  `HERE` 를 없애고, 템플릿 · 기본 설정 · 벤더 선언, `harness_version()`, UI 위치, `HARNESS_BIN`, install 원본, 대조 짝, `delegate()`
  자기 판정이 명세 2-3 표의 값을 쓴다
- 모듈 지도(3-2): 표의 모듈마다 표의 정의를 옮긴다. 표에 없는 정의는 같은 책임의 모듈로 간다. `src/bin/harness_metrics.py` 의
  정의는 전부 `metrics/spans.py` · `metrics/sessions.py` 로 가고 `metrics_module()` 은 없어진다. 명령 모듈은 명령마다 하나다
  (`install` · `render` · `check` · `doctor` · `set` · `write_doc` · `fix` · `run` · `steps` · `checks` · `metrics` · `forge_setup` ·
  `vars` · `uninstall` · `start_server` · `stop_server` · `server_status` · `schema` · `status` · `tools` · `projects` · `version` · `help`)
- 원칙(3-1)
  - 패키지 안의 import 는 `harness.` 로 시작하는 절대 경로다. 다른 하네스 모듈의 정의는 `from harness.<모듈> import <이름>` 으로
    받는다 — 회귀 테스트가 그 이름을 쓰는 함수의 모듈에서 바꿔 끼운다(명세 7-2)
  - `__init__.py` 는 docstring 만 갖고(명령 표를 갖는 `commands/__init__.py` 예외), `harness/__init__.py` 의 docstring 은 지금 진입
    스크립트의 docstring 이다
  - 클론 키 모듈과 키 캐시는 `home/clone_key.py` 가 갖고 그 모듈의 함수로만 읽고 바꾼다
  - `urllib.request` 는 쓰는 함수 안에서 불러온다
  - 지표 모듈 · 클론 키 모듈 · 대상 리포 지표 기록기를 불러오는 곳의 `sys.dont_write_bytecode = True` 를 없앤다(5-2)
- 명령 가르기(3-3): `cli.py` 가 `main` · `parse_command_line`(T3 에서 뗀 것) · `DELEGATES` · `delegate` 를 갖고, 명령 표는
  `commands/__init__.py` 에서 불러온다. `main()` 은 실행할 명령의 모듈 하나만 `importlib` 로 불러오고, 위임하는 실행은 명령 모듈을
  불러오지 않는다. 벤더 선언은 `harness.cli` 를 불러올 때, 명령을 가르기 전에 읽고 검사한다
- 고정 사본(4절)
  - `PINNED_PARTS` 에 `.harness/lib` 를, `pinned_files()` 에 `lib/` 아래 파일(`__pycache__/` 제외)을 더한다
  - install 이 `ENTRY` · `PACKAGE` · `TEMPLATES` · `VERSION` 을 4-1 의 자리에 경로 안전 공용 함수(`guarded_path()`)를 거쳐 깐다.
    사전 판정의 바꿀 경로에 `.harness/lib` 가 들고, 링크 성분이면 아무것도 바꾸지 않고 2 로 끝난다
  - 깐 직후의 `pinned_files()` 해시로 `.harness/managed` 의 사본 줄을 쓴다. 소스 리포 분기는 `PINNED_PARTS` 전부를 걷는다
  - 옛 배치의 리포에서 install 하면 `.harness/` 를 매니페스트 둘만 남기고 비운 뒤 새 구성으로 깐다(4-3)
  - `delegate()` 는 넘길 진입 스크립트의 실제 경로가 `ENTRY` 의 실제 경로와 같으면 넘기지 않는다. `pinned_differences()` 는 4-4 의
    짝(`ENTRY` · `PACKAGE` 아래 · `TEMPLATES` 아래)으로 비교하고, 읽지 못한 파일은 사본 쪽 `.harness/` 기준, 전역 CLI 쪽 `ROOT` 기준으로 표시한다
- 단위 테스트(7-5): `src/test/unit/test_commands.py`(스모크) · `test_cli.py` 를 명세 7-5 의 두 표대로 더한다. `[verify]` 에 "Python 단위
  테스트"(`cd src && python3 -B -m unittest discover -s test/unit`, `paths` = `src/harness/**` · `src/templates/**` · `src/test/**`)를
  "CLI 패키지 의존 방향" 바로 뒤에 더하고 render 한다
- 회귀 테스트: `render-test.sh` 에 "CLI 패키지와 고정 사본" `UT-<번호>` 블록 하나(명세 7-3 표의 여덟 케이스)만 더한다. 그 밖의 줄과
  `doctor.test.js` · `cli_loader.py` 는 고치지 않는다
- 주석: 옮긴 정의의 주석 가운데 "한 파일" 처럼 배치가 바뀌어 틀리게 된 것, 함수 · 상수의 자리로 `bin/harness` 를 가리키는 주석
  (`src/ui/lib/agent-icons.js` · `enums.js` · `labels.js` 포함)을 그 정의가 간 모듈로 고친다
- 건드릴 파일: `src/bin/harness`, `src/bin/harness_metrics.py`(삭제), `src/harness/`(신규), `src/test/unit/`(신규), `src/test/render-test.sh`(블록 추가),
  `harness.toml`, `src/ui/lib/` 의 주석 셋, render 로 갱신되는 생성 파일

### 완료 조건

- [ ] `src/bin/harness` 가 명세 2-2 의 네 단계만 하고, `ast.parse(<원문>, feature_version=(3, 7))` 로 해석된다
- [ ] `tomllib` 을 불러오지 못할 때의 문구와 종료 코드가 옛 진입 스크립트와 같다
- [ ] `src/bin/harness_metrics.py` 가 없다
- [ ] 명세 3-2 의 표에 적힌 이름마다 `cli_loader.module_of()` 가 표의 모듈을 돌려준다
- [ ] `script/project/check-cli.py compile` 과 `imports` 가 0 이다
- [ ] `cd src && python3 -B -m unittest discover -s test/unit` 이 통과한다
- [ ] "CLI 패키지와 고정 사본" 블록의 여덟 케이스가 통과한다
- [ ] T4 뒤로 `render-test.sh` 의 diff 는 새 블록의 추가뿐이고, `doctor.test.js` · `cli_loader.py` 는 바뀌지 않는다
- [ ] `render-test.sh` 전체와 UI 단위 테스트가 통과한다
- [ ] 회귀 테스트 · 단위 테스트 · CLI 실행 뒤 `src/` 와 설치본 `.harness/` 아래에 `__pycache__` 가 없다
- [ ] `[verify]` 의 "Python 단위 테스트" 가 명세 6절의 `run` · `paths` · 위치와 같고, render 뒤 생성물이 일치한다
- [ ] 주석에 함수 · 상수의 자리로 `bin/harness` 를 적은 곳이 없다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/206-split-cli-into-package` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 패키지 사본 | install 한 리포 | `.harness/lib/harness/` 의 파일 목록 · 바이트가 `src/harness/` 와 같고(`__pycache__` 제외) `.harness/bin/` 에는 `harness` 하나. `.harness/managed` 에 패키지 파일마다 줄이 있고 `shasum -a 256 -c .harness/managed` 통과 |
| UT-02 | 옛 배치에서 갱신 | `.harness/lib/` 와 그 줄을 지우고 `.harness/bin/harness_metrics.py` 와 그 줄을 더한 리포에서 install | 0. `harness_metrics.py` 와 그 줄이 없고 `.harness/lib/harness/` 와 그 줄이 있으며 `check` 가 0 |
| UT-03 | 사본 자리의 링크 | `.harness/lib` 가 바깥 디렉터리를 가리키는 링크인 리포에서 install | 2, 바깥 디렉터리 그대로 |
| UT-04 | 패키지 변경 | `.harness/lib/harness/` 아래 파일 하나를 고침 / 파일 하나를 더함 | `check` 1 과 `help:` 의 `harness install`. 회귀 테스트의 `src/bin/harness doctor` 표준 오류의 `warning: the pinned harness differs` 아래에 그 경로 |
| UT-05 | 위임이 끝난다 | 고정 사본이 있는 리포에서 `src/bin/harness check` · `.harness/bin/harness check` | 각각 60초 안에 0. 뒤의 것은 표준 오류에 `note: this project is pinned` 없음 |
| UT-06 | 패키지 없음 | `.harness/lib` 를 지운 리포에서 `.harness/bin/harness version` | 2, 표준 오류 첫 줄이 `error: cannot find the harness package` 로 시작 |
| UT-07 | help 첫 줄 | `harness help` | `harness — generate the AI development harness from one config, and block drift.` |
| UT-08 | 가벼운 시작 | 소스 트리 밖에서 `python3 -X importtime src/bin/harness version` | 표준 오류에 `urllib.request` · `http.client` 없음, `harness.commands.` 로 시작하는 모듈은 `harness.commands.version` 하나 |
| UT-09 | 명령 표와 명령 모듈의 짝 | `test_commands.py` | 명령 표의 이름마다 `harness.commands.<모듈 이름>` 에 `cmd_<모듈 이름>` 이 있고, 명령 모듈마다 명령 표에 이름이 있으며, 항목은 네 원소이고 첫 원소는 `True` 또는 `None` |
| UT-10 | 인자 나누기 | `test_cli.py` — 명세 7-5 의 명령줄 표 일곱 행 | 표의 결과 |

## T6 · feat: CLI 바이트코드를 등록부 아래 .cache/pycache 에 쌓음

### 상위 Requirement

- relates to #206

### 작업 내용

진입 스크립트가 바이트코드 위치를 등록부 아래 캐시로 정한다. CLI 패키지 · 경로로 불러오는 관리 스크립트 모듈 · 표준 라이브러리의
바이트코드가 그 아래에 쌓이고, 리포에는 `__pycache__` 가 생기지 않는다.

- 명세 2-2 의 2번, 5절, 7-3 의 "바이트코드 캐시"
- 진입 스크립트의 2번(5-1)
  - 등록부 루트는 `HARNESS_HOME` 이 비어 있지 않으면 그 값, 아니면 `~/.harness` 다 — `registry()` 와 같은 규칙이다
  - 등록부 루트가 디렉터리로 있으면 `sys.pycache_prefix` 를 `<등록부 루트>/.cache/pycache` 의 절대 경로로 정한다. 환경의
    `PYTHONPYCACHEPREFIX` 보다 앞선다. `pycache` 디렉터리가 없으면 0700 으로 만들고(없는 `.cache` 는 기본 권한), 있으면 권한을
    바꾸지 않는다. 만들지 못하면(`OSError`) 아무것도 내지 않고 넘어간다
  - 등록부 루트가 없으면(파일이어도) `sys.dont_write_bytecode` 를 켜고 접두 경로는 정하지 않는다. 진입 스크립트는 등록부 루트를 만들지 않는다
- 패키지 코드는 `sys.dont_write_bytecode` 를 바꾸지 않는다(5-2). 관리 스크립트가 스스로 바이트코드 쓰기를 끄는 것은 바꾸지 않는다
- 등록부 안의 `.cache/` 는 `.` 으로 시작하는 내부 항목이다(5-3). `harness projects` · doctor `registry` 절 · 옛 이름 디렉터리 옮기기 ·
  `uninstall` 은 #96 의 규칙대로 `.` 으로 시작하는 항목을 건너뛴다. "등록 목록" 케이스가 이것을 고정한다. 등록을 읽기만 하는 명령도
  이 아래에 쓰고, 하네스는 이 아래를 정리하지 않는다
- 회귀 테스트: `render-test.sh` 에 "바이트코드 캐시" `UT-<번호>` 블록 하나(명세 7-3 표의 다섯 케이스)만 더한다. 바이트코드를 보는
  케이스는 `PYTHONDONTWRITEBYTECODE` 를 뺀 환경에서 CLI 를 부른다. 그 밖의 테스트 줄은 고치지 않는다
- 건드릴 파일: `src/bin/harness`, `src/test/render-test.sh`(블록 추가)

### 완료 조건

- [ ] "바이트코드 캐시" 블록의 다섯 케이스가 통과한다
- [ ] 환경의 `PYTHONPYCACHEPREFIX` 가 다른 경로여도 바이트코드가 등록부 아래에 쌓인다
- [ ] 이미 있는 `.cache/pycache` 의 권한을 바꾸지 않고, 만들지 못해도 명령의 출력과 종료 코드가 같다
- [ ] `src/harness/` 아래에 `sys.dont_write_bytecode` 대입이 없다
- [ ] T5 뒤로 `render-test.sh` 의 diff 는 새 블록의 추가뿐이고 전체가 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/206-split-cli-into-package` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 캐시 위치 | 빈 디렉터리를 `HARNESS_HOME` 으로 두고 install 한 리포에서 `harness check` | `$HARNESS_HOME/.cache/pycache` 가 0700, 그 아래 리포 `.harness/lib/harness/` 의 실제 경로를 따른 자리에 `cli` 모듈의 `.pyc`, 리포 아래 `__pycache__` 없음 |
| UT-02 | 소스 트리 | 소스 트리 복제본의 `src/bin/harness check` | 복제본 `src/` 아래 `__pycache__` 없음, `$HARNESS_HOME/.cache/pycache` 아래에 복제본 `src/harness/` 를 따른 `.pyc` |
| UT-03 | 등록부가 없을 때 | 없는 경로를 `HARNESS_HOME` 으로 두고 복제본의 `harness version` · `harness projects` | 둘 다 0, `projects` 는 `{"projects": [], "legacy": []}`, 그 경로가 생기지 않고 복제본 `src/` 아래 `__pycache__` 없음 |
| UT-04 | 등록부 자리가 파일일 때 | 파일을 `HARNESS_HOME` 으로 두고 `harness version` | 0, 출력 `harness <버전>` |
| UT-05 | 등록 목록 | `.cache/` 가 생긴 등록부에서 `harness projects` | `projects` · `legacy` 어디에도 `.cache` 없음 |

## T7 · docs: README 와 리뷰 점검 문서에 CLI 패키지 구조와 바이트코드 캐시 반영

### 상위 Requirement

- relates to #206

### 작업 내용

T5 · T6 이 만든 구조와 동작을 사람용 설명과 이 리포의 리뷰 점검 문서에 적는다.

- 명세 8-1(README) · 8-3(프로젝트 문서)
- README "구조" 트리: `src/bin/harness` 는 진입 스크립트(패키지를 찾아 `harness.cli.main()` 을 부른다), `src/harness/` 는 CLI 패키지(명령마다
  `commands/<명령>.py`, 여러 명령이 쓰는 공용 모듈), `src/test/unit/` 은 CLI 패키지의 Python 단위 테스트
- README "검증": `cd src && python3 -B -m unittest discover -s test/unit` 이 CLI 패키지의 단위 테스트를 돌고 소스 리포에서만 돈다
- README "시작하기" 의 `install` 설명: `.harness/` 에 진입 스크립트(`bin/`) · CLI 패키지(`lib/harness/`) · 템플릿(`templates/`) · `VERSION` 이
  깔리고 커밋된다
- README "업데이트": 바이트코드 캐시는 등록부 아래 `.cache/pycache/`(`HARNESS_HOME` 이 있으면 그 아래)에 쌓이고 지워도 된다. 리포에는
  `__pycache__` 가 생기지 않는다. Homebrew 설치는 `src/` 의 `bin/` · `harness/` · `templates/` · `ui/` 를 `libexec` 에 넣는다
- `.ai/project/review-checks.md` 의 생성 파일 점검 줄이 `src/harness/render/plan.py` 의 `plan()` 을 가리킨다
- 건드릴 파일: `README.md`, `.ai/project/review-checks.md`, render 로 갱신되는 생성 파일이 있으면 그것

### 완료 조건

- [ ] README 네 곳이 명세 8-1 표의 사실을 담는다
- [ ] README 에 `harness_metrics.py` 와 CLI 를 한 파일로 적은 서술이 없다
- [ ] `.ai/project/review-checks.md` 의 생성 파일 점검 줄이 `src/harness/render/plan.py` 의 `plan()` 을 가리킨다
- [ ] 추가한 문장에 개인 홈 절대 경로가 없다
- [ ] `src/bin/harness check` 가 어긋남 없이 끝나고 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/206-split-cli-into-package` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 문서 참조 | 수정 뒤 `harness doctor` | 문서가 가리키는 경로가 모두 있다는 `ok` 줄 |
| UT-02 | README 반영 | `README.md` | 네 곳에 명세 8-1 의 사실이 있고 `harness_metrics.py` 서술이 없다 |
| UT-03 | 리뷰 점검 반영 | `.ai/project/review-checks.md` | 생성 파일 점검 줄이 `src/harness/render/plan.py` 의 `plan()` |

## T8 · docs: 다른 명세의 함수·상수 자리를 CLI 패키지 모듈로 고침

### 상위 Requirement

- relates to #206

### 작업 내용

다른 명세가 함수 · 상수의 자리로 `src/bin/harness` 를 적은 서술을 명세 3-2 지도의 모듈로 바꾸고, 고정 사본 · 지표 모듈 · 바이트코드
서술을 이 명세의 배치에 맞춘다.

- 명세 8-2
- 대상 명세: 58 · 59 · 60 · 61 · 62 · 64 · 70 · 71 · 96. 함수 · 상수의 자리로 적은 `src/bin/harness`(정본 위치 표 포함)를 그 정의가 간
  모듈로 바꾼다. 명령줄로서의 `src/bin/harness`(실행 경로)는 그대로 둔다
- 내용을 바꾸는 곳: 명세 8-2 의 표 아홉 행 — 58 의 2-2 고정 사본 행 · 5-2 대조 표와 그 아래 목록 · 11-1 `install_registered()` 행 · 11-4
  install 행, 61 의 8 판정 함수 불러오기, 64 의 8 전체 · 12-2 의 두 케이스, 96 의 1-2 부르는 쪽 표의 CLI 행 · 3-1 표의 `.` 으로 시작하는 항목
- 각 명세의 "보호 문서에 반영할 것" 절과 `docs/plan/` 은 고치지 않는다
- 건드릴 파일: `docs/spec/58-separate-managed-and-project-parts.md` · `59-doctor-remote-readiness.md` · `60-automate-work-prerequisites.md` ·
  `61-start-server-background.md` · `62-unify-ui-writes-through-cli.md` · `64-modularize-cli-review-scripts.md` · `70-generate-permission-allow-list.md` ·
  `71-issue-worktree-run.md` · `96-machine-local-state-key.md`

### 완료 조건

- [ ] 대상 명세 아홉에서 함수 · 상수의 자리로 `src/bin/harness` 를 적은 서술이 없다. 실행 경로로서의 `src/bin/harness` 는 그대로다
- [ ] 명세 8-2 표의 아홉 행이 표의 "바꾼 뒤의 서술" 을 담는다
- [ ] 대상 명세의 "보호 문서에 반영할 것" 절과 `docs/plan/` 이 바뀌지 않는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/206-split-cli-into-package` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 정의 자리 | 대상 명세 아홉의 `src/bin/harness` 출현 | 남은 것은 모두 명령줄 · 실행 경로 |
| UT-02 | 고정 사본 서술 | 58 의 2-2 · 5-2 · 11-1 · 11-4 | `.harness/lib/` 가 들고 대조 짝이 명세 4-4 와 같다 |
| UT-03 | 지표 모듈 서술 | 64 의 8 · 12-2 | `src/harness/metrics/` 와 이 명세 7-2 · 7-3 을 가리키고 `sys.dont_write_bytecode` · `.harness/bin/harness_metrics.py` 서술이 없다 |
| UT-04 | 클론 키 서술 | 96 의 1-2 · 3-1 | `src/harness/home/clone_key.py` 가 불러오고 `.cache/` 가 `.` 으로 시작하는 항목의 예에 있다 |
| UT-05 | 고치지 않는 곳 | 대상 명세의 "보호 문서에 반영할 것" 절, `docs/plan/` | diff 없음 |

## T9 · docs: 아키텍처·용어·테스트 문서에 CLI 패키지와 바이트코드 캐시 반영

### 상위 Requirement

- relates to #206

### 작업 내용

T4 ~ T6 이 만든 CLI 패키지 구조 · 고정 사본 구성 · 바이트코드 캐시 · 단위 테스트 자리를 에이전트가 근거로 읽는 문서에 적는다.

**보호 문서를 수정하는 task 다.** `.ai/project/architecture.md` · `glossary.md` · `testing.md` 는 보호 문서다. 2026-10-09 결정 게이트에서
사용자가 허용한 범위 — 명세 9절의 표 — 만 고치고, 그 범위 밖은 고치지 않는다. 권한 설정 · 가드에 걸리면 사람이 대응한다.

- 명세 9절
- `.ai/project/architecture.md`: "구성 요소" 의 `src/bin/harness` 항목을 두 항목(진입 스크립트 · CLI 패키지)으로, 기기 단위 상태 항목 끝에
  `.cache/pycache/`, `src/test/render-test.sh` 항목 끝에 `src/test/unit/`. "신뢰 경계" 에 바이트코드 캐시 항목. "새 코드를 둘 곳" 의 새 생성
  파일 · 새 설정 키 · 새 CLI 명령 · 지표 코드 · 새 회귀 테스트. "계층과 의존 방향" 의 첫 항목과 CLI 패키지 안의 의존 방향 새 항목. "검사하지
  않는 것" 의 한 파일 항목 삭제, 고정 사본 항목의 괄호, `.gitignore` 이름만 적은 규칙 새 항목. 문안은 명세 9절 표 그대로다
- `.ai/project/glossary.md`: "용어" 의 `소스 리포` · `고정(pin)`, 새 행 `진입 스크립트` · `CLI 패키지` · `명령 모듈` · `공용 모듈` · `통과 명령`.
  "폐기된 별칭" 새 행 둘
- `.ai/project/testing.md`: "외부 의존을 어떻게 다루나" 의 등록부 줄 · 소스 트리 복제 줄, "무엇을 어느 수준으로 검증하나" 의 새 항목 둘(`cli_loader.py`,
  CLI 패키지의 Python 단위 테스트)
- `.ai/project/scope.md` 는 고치지 않는다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/architecture.md`, `.ai/project/glossary.md`, `.ai/project/testing.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] `.ai/project/architecture.md` 가 명세 9절 표의 열네 위치를 표의 문안대로 담고, "검사하지 않는 것" 에 CLI 가 한 파일이라는 항목이 없다
- [ ] `.ai/project/glossary.md` 가 명세 9절 표의 여덟 행을 담는다
- [ ] `.ai/project/testing.md` 가 명세 9절 표의 네 행을 담는다
- [ ] `.ai/project/scope.md` 와 세 문서의 표 밖 문장이 바뀌지 않는다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 2장 · 5장이 세 문서와 일치하고 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/206-split-cli-into-package` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 아키텍처 반영 | `.ai/AI_AGENT.md` 5장 | 진입 스크립트 · CLI 패키지 두 항목, `.cache/pycache/`, `src/test/unit/`, CLI 패키지 안의 의존 방향, 새 명령 자리 `src/harness/commands/` |
| UT-03 | 용어 반영 | `.ai/AI_AGENT.md` 2장 | `진입 스크립트` · `CLI 패키지` · `명령 모듈` · `공용 모듈` · `통과 명령` 행과 지표 모듈 · 한 파일 CLI 의 폐기된 별칭 |
| UT-04 | 범위 밖 무변경 | `.ai/project/scope.md`, 세 문서의 표 밖 문장 | diff 없음 |
