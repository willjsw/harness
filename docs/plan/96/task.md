# #96 task

## T1 · feat: 클론 키 공용 모듈과 project.name 의 키 형식 거부

### 상위 Requirement

- relates to #96

### 작업 내용

하네스 루트 하나에서 클론 키를 계산하고 설정 값의 자리표시를 푸는 공용 모듈을 만들고, CLI 가 그 모듈을 불러오게 한다.
`project.name` 이 키 형식이면 설정 검증이 거부한다.

- 명세 1절(클론 키 — 계산 · 공용 모듈 · 이름공간) · 8-1 의 UT-75
- `src/templates/managed/script/_clone_key.py`: `clone_key(root)` · `expand(text, root)` 와 명령줄 `expand <text>`. git 트리 안이면
  `git\0<공통 디렉터리>\0<리포 안의 위치>`, 그 밖이면 `dir\0<실제 경로>` 를 SHA-256 으로 해시해 `c-` + 16자. 바이트코드를 쓰지 않는다
- `src/bin/harness`: `metrics_module()` 과 같은 방식(`importlib`, 바이트코드 없이)으로 모듈을 불러오는 함수와, 한 실행에서 키를 한 번만 계산하는 캐시
- `validate()`: `project.name` 이 `^c-[0-9a-f]{16}$` 이면 명세 1-3 의 `error:` · `help:` 안내로 종료 코드 2
- `script/README.md` 표에 `_clone_key.py` 한 줄 (정본 `src/templates/managed/script/README.md`)
- `src/bin/harness render` 로 이 리포의 `script/_clone_key.py` · `script/README.md` 사본 갱신
- `render-test.sh` 에 새 `UT-75` 블록
- 건드릴 파일: `src/templates/managed/script/_clone_key.py`(신규), `src/templates/managed/script/README.md`, `src/bin/harness`, `src/test/render-test.sh`, render 로 갱신되는 `script/`

### 완료 조건

- [ ] 한 리포와 그 `git worktree add` worktree 의 키가 같다
- [ ] 같은 원격을 두 번 clone 한 두 경로, 같은 리포의 두 서브디렉터리의 키가 서로 다르다
- [ ] git 트리가 아닌 디렉터리에서도 키 형식의 키가 나오고, 다시 구하면 같다
- [ ] 모든 키가 `^c-[0-9a-f]{16}$` 이고 하네스 루트의 경로 조각을 담지 않는다
- [ ] `python3 script/_clone_key.py expand` 가 `{clone}` · `{project}` 를 같은 키로 바꾸고, 자리표시 없는 값은 그대로 내며, 인자가 없으면 아무것도 내지 않고 1 로 끝난다
- [ ] 실행 뒤 `script/__pycache__` 가 생기지 않는다
- [ ] `project.name` 이 키 형식이면 `harness render` 가 종료 코드 2 와 `error:` 로 멈춘다
- [ ] 생성 파일에 키가 들어가지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/96-machine-local-state-key` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | worktree 의 키 | 한 리포와 그 `git worktree add` worktree 에서 `clone_key` | 두 키가 같다 |
| UT-02 | 두 클론의 키 | 같은 원격을 두 번 clone | 두 키가 다르다 |
| UT-03 | 모노레포의 키 | 같은 리포의 두 서브디렉터리를 하네스 루트로 | 두 키가 다르다 |
| UT-04 | git 밖의 키 | git 트리가 아닌 디렉터리에서 두 번 | 키 형식이고 두 값이 같다 |
| UT-05 | 키 형식 | 위에서 구한 키 전부 | `^c-[0-9a-f]{16}$` 이고 경로 조각이 없다 |
| UT-06 | 명령줄 `expand` | `{clone}/x` · `{project}/x` · `plain` · 인자 없음 | 앞의 둘이 같은 값, `plain` 그대로, 인자 없음은 출력 없이 1 |
| UT-07 | 이름 검사 | `project.name = "c-0123456789abcdef"` 로 render | 종료 코드 2, 표준 오류에 `error:` 와 `help:` |

## T2 · feat: 지표·사용 기록·worktree 경로의 자리표시를 실행할 때 클론 키로 풀기

### 상위 Requirement

- relates to #96

### 작업 내용

기기 단위 기록의 경로를 커밋되는 이름이 아니라 실행할 때 계산한 클론 키로 나눈다. 렌더는 자리표시를 풀지 않고 설정 값을
그대로 생성 파일에 옮겨, 두 클론의 생성 파일이 같게 한다.

- 명세 2-1(뜻과 기본값) · 2-2(생성 파일) · 2-3(실행할 때 푸는 곳) · 2-5(다른 클론과 겹치는 worktree 자리) · 8-1 의 UT-78 "같은 값" · "기본값" · 8-2(기존 블록) · 8-3(`test-usage-log.sh`)
- 기본값: `metrics.dir` · `usage.log_path` · `worktree.dir` 를 `{clone}` 으로. `src/templates/harness.toml`(각 키 주석에 `{clone}` 의 뜻과 `{project}` 가 옛 별칭이라는 것) ·
  `METRICS_DEFAULTS` · `WORKTREE_DEFAULTS` · 이 리포의 `harness.toml`
- `src/bin/harness`: `run_plan()` 은 `cfg["metrics"]` 를 그대로 싣는다. `metrics_cfg()` · `worktree_dir()` 가 모듈로 자리표시를 푼다.
  세션 가져오기의 커서 디렉터리는 `registry() / <클론 키> / "state"`. `issue_worktree()` 의 "이 리포의 worktree 가 아니다" 안내는 명세 2-5 문구
- `src/templates/managed/script/metric.py` 의 `config()`: 계획 파일의 `metrics.dir` 를 모듈로 풀고, 키를 계산하지 못하면 기록하지 않는다
- `src/templates/managed/script/usage-log.sh` · `usage-report.sh`: `USAGE_LOG_PATH` 를 `_clone_key.py expand` 로 푼다. 풀지 못하면 `usage-log.sh` 는 기록 없이 0,
  `usage-report.sh` 는 명세 2-3 의 `error:` 로 2. 환경 변수로 준 경로와 `off` 는 풀지 않는다
- `render-test.sh`: 새 `UT-78` 블록의 "같은 값" · "기본값" 케이스. UT-70 의 기본값 문자열 검사를 `{clone}` 으로, UT-36 · UT-56 · UT-73 의 가져오기 커서 경로를 클론 키 경로로 고친다
- `test-usage-log.sh` 에 명세 8-3 의 네 케이스
- `src/bin/harness render` 로 이 리포의 생성 파일과 `script/` 사본 갱신
- 건드릴 파일: `src/bin/harness`, `src/templates/harness.toml`, `harness.toml`, `src/templates/managed/script/metric.py` · `usage-log.sh` · `usage-report.sh` · `test-usage-log.sh`, `src/test/render-test.sh`, render 로 갱신되는 생성 파일과 `script/`

### 완료 조건

- [ ] 기본 설정의 세 값이 `{clone}` 을 담고 `{project}` 가 없다
- [ ] `script/harness.plan.json` 의 `metrics.dir` 와 `script/harness.env` 의 `USAGE_LOG_PATH` 가 설정 값 그대로이고 키가 없다
- [ ] 한 클론에서 `script/metric.py` 로 남긴 스팬과 `script/usage-log.sh` 로 남긴 줄이 그 클론의 키로 푼 경로 아래에 쌓인다
- [ ] 세 설정 값을 `{project}` 로 두면 `{clone}` 과 같은 경로에 쌓인다
- [ ] 세션 가져오기의 커서가 `$HARNESS_HOME/<클론 키>/state/` 에 쌓인다
- [ ] `harness run --worktree` 의 worktree 가 `worktree.dir` 를 키로 푼 경로 아래에 생긴다
- [ ] 이 리포의 worktree 가 아닌 자리를 만나면 명세 2-5 의 `error:` · `help:` 가 나온다
- [ ] `usage-log.sh` 는 키를 풀지 못하면 파일을 만들지 않고 0 으로 끝난다. `usage-report.sh` 는 명세 2-3 의 `error:` 로 2 로 끝난다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/96-machine-local-state-key` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 기본값 | `src/templates/harness.toml` · `METRICS_DEFAULTS` · `WORKTREE_DEFAULTS` | 세 값에 `{clone}`, `{project}` 없음 |
| UT-02 | 생성 파일은 설정 값 그대로 | `{clone}` 설정으로 render | 계획 파일과 `harness.env` 에 `{clone}` 문자열, 키 없음 |
| UT-03 | 옛 별칭은 같은 값 | 세 값을 `{project}` 로 두고 스팬·사용 기록 남김 | `{clone}` 일 때와 같은 경로에 쌓인다 |
| UT-04 | 가져오기 커서 | 세션 가져오기 | 커서가 `$HARNESS_HOME/<클론 키>/state/` |
| UT-05 | 사용 기록 자리표시 | 덮어쓰기 없이 `USAGE_LOG_PATH` 에 `{clone}` | 풀린 경로에 한 줄 |
| UT-06 | 사용 기록 옛 별칭 | `USAGE_LOG_PATH` 에 `{project}` | UT-05 와 같은 경로 |
| UT-07 | 풀지 못함 | `_clone_key.py` 를 1 로 끝나는 스텁으로 | 파일 없음, 종료 코드 0 |
| UT-08 | 덮어쓰기 | 환경 변수로 `{clone}` 문자가 든 경로 | 그 경로 그대로 쓴다 |
| UT-09 | worktree 자리 겹침 | `worktree.dir` 아래 다른 리포의 worktree 가 같은 이름으로 있음 | `error:` 와 `help: another clone may share worktree.dir` |

## T3 · feat: 옛 자리표시 {project} 를 render 와 doctor 가 안내

### 상위 Requirement

- relates to #96

### 작업 내용

`{project}` 는 `{clone}` 과 같은 값으로 풀리지만 이름과 뜻이 어긋나므로, 그 값을 쓰는 설정을 render 와 doctor 가 알린다. 동작과 종료 코드는 바꾸지 않는다.

- 명세 2-4(옛 별칭 안내) · 8-1 의 UT-78 "안내"
- `cmd_render`: `metrics.dir` · `usage.log_path` · `worktree.dir` 중 값에 `{project}` 가 든 키마다 명세 2-4 의 `note:` 한 줄을 표준 오류로
- doctor 수집 함수: 같은 키마다 `section` 이 `config` 인 `warn` 항목(명세 2-4 표의 `what` · `detail`)
- `render-test.sh` 의 `UT-78` 블록에 "안내" 케이스
- 건드릴 파일: `src/bin/harness`(`cmd_render` · doctor 수집 함수), `src/test/render-test.sh`

### 완료 조건

- [ ] 세 값을 `{project}` 로 두고 render 하면 표준 오류에 키마다 `note:` 줄이 있고 종료 코드와 생성 파일이 `{clone}` 일 때와 같은 규칙이다
- [ ] 같은 설정에서 doctor `config` 절에 키마다 `warn` 이 있고 `FAIL` 이 없다
- [ ] `{clone}` 만 쓰는 설정에서는 `note:` 도 `warn` 도 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/96-machine-local-state-key` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | render 안내 | 세 값을 `{project}` 로 두고 render | 표준 오류에 세 `note:` 줄과 `{clone}`, 종료 코드 0 |
| UT-02 | doctor 안내 | 같은 설정에서 doctor | `config` 절에 세 `warn`, `FAIL` 없음 |
| UT-03 | 안내 없음 | 기본 설정에서 render 와 doctor | `note:` 없음, `{project}` `warn` 없음 |

## T4 · feat: 설치 등록부를 클론 키로 나누고 같은 이름은 알리기만 함

### 상위 Requirement

- relates to #96

### 작업 내용

등록부를 `registry()/<클론 키>/project.json` 에 `{path, name}` 으로 두어, 같은 `project.name` 의 클론 여럿이 한 기기에 함께 등록되게 한다.
같은 이름의 거부를 없애고 알리기만 한다. doctor `registry` 절의 판정을 같은 커밋에서 새 등록부로 옮긴다.

- 명세 3-1(배치) · 3-2(`project.json`) · 3-3(등록 · 해제) · 3-5(같은 이름) · 5절 표의 앞 세 줄 · 8-1 의 UT-76(`projects` 케이스 제외) · UT-79 · 8-2
- `src/bin/harness`: `registration()` · `refuse_taken()` 과 거부 안내문, `register()` 의 넘겨받기 안내 줄을 없앤다. `register()` 가 키 디렉터리(0700)에
  `project.json` 을 쓰고 다른 키 디렉터리에서 이 루트를 가리키는 `project.json` 을 지운다. `cmd_install` 은 등록부 잠금 안에서 명세 3-3 순서(고정 사본 → 등록 → 같은 이름 알림)
- `unregister()`: 키 디렉터리와 옛 이름 디렉터리 양쪽에서 이 루트를 가리키는 `project.json` 을 지운다. 기록은 남긴다
- 같은 이름 알림: 명세 3-5 의 `install:` 줄을 `path` 순으로
- doctor 수집 함수의 `registry` 절: `registry()/<클론 키>/project.json` 으로 명세 5절 표의 `ok` · 다른 경로 `warn` · 미등록 `warn` 을 낸다.
  같은 클론 판정은 `path` 의 클론 키로 한다. 등록부를 바꾸지 않는다
- `render-test.sh`: `UT-62` 블록을 지운다. 새 `UT-76` 블록(등록 · 생성 파일 · 기록 경로 · worktree · 재설치 · 소스 리포 · uninstall)과 새 `UT-79` 블록.
  등록부를 `$HARNESS_HOME/<이름>/…` 로 읽는 기존 케이스(소스 리포 등록 · UT-36)를 클론 키 경로로 고친다
- 건드릴 파일: `src/bin/harness`(`registry` 주변 함수 · `cmd_install` · `cmd_uninstall` · doctor 수집 함수), `src/test/render-test.sh`

### 완료 조건

- [ ] 같은 `project.name` 의 두 클론을 install 하면 둘 다 종료 코드 0 이고, 두 키 디렉터리에 각자의 `path` 와 같은 `name` 이 있다
- [ ] 두 번째 install 의 표준 출력에 `is also registered at` 과 첫 클론 경로가 있다
- [ ] 두 클론의 `script/harness.plan.json` · `script/harness.env` 가 같고, 한쪽을 다른 쪽에 복사해도 `harness check` 가 통과한다
- [ ] 같은 클론을 다시 install 하면 등록이 하나이고, `project.name` 을 바꿔 다시 install 하면 같은 키의 `name` 만 바뀌고 기록 디렉터리의 표지 파일이 남는다
- [ ] 소스 트리 복제본 두 개를 같은 이름으로 install 하면 둘 다 통과하고 각자의 키로 등록된다
- [ ] 한 클론을 uninstall 하면 그 키의 `project.json` 만 없고 다른 클론의 등록과 두 기록이 남는다
- [ ] doctor `registry` 절이 등록된 클론과 그 worktree 에서 `ok`, 미등록 · 다른 경로에서 `warn` 이고 `FAIL` 이 없다. doctor 가 등록부를 바꾸지 않는다
- [ ] 같은 리포의 다른 서브디렉터리 하네스 루트는 자기 키로 판정된다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/96-machine-local-state-key` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 두 클론 등록 | 같은 이름의 두 클론 install | 둘 다 0, 두 키 디렉터리에 각자의 `path` 와 같은 `name`, 두 번째 출력에 `is also registered at` |
| UT-02 | 생성 파일 동일 | 두 클론의 계획 파일 · `harness.env` | 같고 키 없음, 교차 복사 뒤 `harness check` 통과 |
| UT-03 | 기록 경로 분리 | 두 클론에서 스팬과 사용 기록 한 줄씩 | 서로 다른 키 디렉터리 아래 |
| UT-04 | worktree 기록 | 한 클론의 worktree 에서 스팬 | 그 클론의 키 디렉터리 아래 |
| UT-05 | 재설치 | 같은 클론 재설치, 이름 바꿔 재설치 | 등록 하나, 같은 키의 `name` 만 바뀜, 표지 파일 남음 |
| UT-06 | 소스 리포 | 소스 트리 복제본 둘을 같은 이름으로 install | 둘 다 통과, 각자의 키 |
| UT-07 | uninstall | 한 클론 uninstall | 그 키의 `project.json` 만 없음, 기록은 남음 |
| UT-08 | doctor 상태별 | 등록된 클론 · 그 worktree · 미등록 리포 · `path` 를 다른 리포로 바꾼 등록 | `ok` · `ok` · `warn` `this repository is not registered` · `warn` 과 그 경로, `FAIL` 없음 |
| UT-09 | doctor 모노레포 | 같은 리포의 다른 서브디렉터리에 같은 이름, 설치 안 함 | `this repository is not registered` |
| UT-10 | doctor 는 바꾸지 않음 | doctor 전후 등록부, 미등록 리포에서 doctor | 파일이 같다, 등록이 생기지 않는다 |
| UT-11 | doctor JSON | `harness doctor --json` | `items` 에 `section` 이 `registry` 인 항목이 명세 5절 표대로 |

## T5 · feat: harness projects 로 등록된 클론 목록을 JSON 으로 냄

### 상위 Requirement

- relates to #96

### 작업 내용

UI 가 등록부 디렉터리 규칙을 알지 않도록, 이 기기에 등록된 클론 목록을 CLI 가 JSON 으로 낸다.

- 명세 3-4(목록 조회) · 8-1 의 UT-76 `projects` 케이스
- `src/bin/harness`: `COMMANDS` 표에 `projects`(설명 `registered clones on this machine as JSON (for the UI)`)와 `cmd_projects()`. `tools` 처럼
  `main()` 이 대상 해석 전에 처리하고 `DELEGATES` 에 넣지 않는다. 설정을 읽지 않고 등록부를 바꾸지 않는다
- 키 형식 디렉터리는 `projects`, 그 밖의 디렉터리의 `project.json` 은 `legacy`. 최상위 파일과 `.` 으로 시작하는 항목은 어디에도 넣지 않는다.
  읽히지 않는 `project.json` 은 `path: null`. 정렬은 `name` → `path`(`null` 뒤) → `key`
- `render-test.sh` 의 `UT-76` 블록에 `projects` 케이스
- 건드릴 파일: `src/bin/harness`, `src/test/render-test.sh`

### 완료 조건

- [ ] 출력이 `{"projects": [...], "legacy": [...]}` 형식이다
- [ ] 두 클론이 `ok: true` 로 경로 순이고, 옛 이름 디렉터리의 `project.json` 은 `legacy` 에 있다
- [ ] `tools.json` · `.install.lock` · 최상위 `ui.log` 가 어디에도 없다
- [ ] 읽히지 않는 `project.json` 이 있어도 예외 없이 `path: null` 로 낸다
- [ ] `harness.toml` 이 없는 디렉터리에서도 돌고, 등록부가 없으면 두 배열이 빈다
- [ ] 실행 전후 등록부가 같다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/96-machine-local-state-key` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 형식과 정렬 | 같은 이름의 두 클론 설치 뒤 `harness projects` | 두 항목 `ok: true`, 경로 순, `key` 는 키 형식 |
| UT-02 | 옛 등록 | 옛 이름 디렉터리에 `project.json` | `legacy` 에 `name` 은 디렉터리 이름 |
| UT-03 | 등록 아닌 항목 | 등록부에 `tools.json` · `.install.lock` · `ui.log` | 어느 배열에도 없다 |
| UT-04 | 깨진 `project.json` | JSON 이 아닌 내용 | 해당 항목 `path: null`, 종료 코드 0 |
| UT-05 | 대상 없음 | 설정 없는 디렉터리, 등록부 없음 | 종료 코드 0, `{"projects": [], "legacy": []}` |

## T6 · feat: 옛 이름 디렉터리의 기록을 install 과 render 가 클론 키 아래로 옮김

### 상위 Requirement

- relates to #96

### 작업 내용

옛 버전이 `~/.harness/<이름>/` 과 이름으로 푼 경로에 남긴 가져오기 커서 · 실행 지표 · 사용 기록 · 이슈 worktree 를, 그 디렉터리가 이 루트를
가리킬 때 install 과 render 가 등록부 잠금 안에서 클론 키 아래로 옮긴다. doctor 는 옮기지 않은 상태를 알린다.

- 명세 4절(옛 이름 디렉터리 옮기기) · 5절 표의 넷째 줄 · 8-1 의 UT-77
- `src/bin/harness`: `migrate_legacy(cfg, target)`. `cmd_install` 은 이미 잡은 잠금 안(고정 사본 뒤 · 등록 앞)에서, `cmd_render` 는 install 이 부른 렌더를 빼고
  렌더 전에 `registry_lock()` 을 잡아 부른다. 조건(이름이 키 형식이 아님, 옛 `project.json` 의 `path` 가 이 루트의 실제 경로)이 맞지 않으면 아무것도 하지 않는다
- 디렉터리 옮기기의 합치기 규칙(스팬 파일 덧붙이기 · 커서는 새 것 · 그 밖은 옛 것 지움), 사용 기록 덧붙이기, 권한 0700 · 0600
- worktree 는 `git worktree move`. 잠김 · 미커밋 변경 · 경로 없음 · 새 자리 있음 · git 거부면 남기고 사유를 알린다
- 마무리(키의 `project.json` 쓰기, 옛 디렉터리 지우기 또는 남기기)와 명세 4-4 의 출력. 옮기기는 종료 코드를 바꾸지 않는다
- doctor 수집 함수의 `registry` 절에 명세 5절의 `state under the old name directory is not moved` `warn`
- `render-test.sh` 에 새 `UT-77` 블록
- 건드릴 파일: `src/bin/harness`(`cmd_install` · `cmd_render` · doctor 수집 함수), `src/test/render-test.sh`

### 완료 조건

- [ ] 옛 이름 디렉터리의 커서 · 지표 · 사용 기록 · 깨끗한 worktree 가 install 뒤 전부 키 아래에 있고, worktree 가 `git worktree list` 에 새 경로로 있으며, 옛 디렉터리가 없다
- [ ] 미커밋 변경이 있는 worktree 와 잠긴 worktree 는 옛 자리에 남고, 출력에 `left` 와 각 사유, `kept` 가 있으며 옛 `project.json` 이 남는다
- [ ] 남긴 worktree 의 변경을 커밋하고 잠금을 푼 뒤 render 하면 옮겨지고 옛 디렉터리가 사라진다
- [ ] 키 아래에 같은 이름의 스팬 파일 · `usage.log` 가 있으면 옛 줄이 끝에 붙고 원래 줄도 남으며, 커서는 새 것이 남는다
- [ ] 옛 `project.json` 의 `path` 가 다른 경로이거나 이슈 worktree 에서 render 하면 아무것도 옮기지 않고 출력이 없다
- [ ] 옮기기 전 상태에서 doctor `registry` 절에 `state under the old name directory is not moved` `warn` 이 있다
- [ ] 옮기기가 실패해도 install · render 의 종료 코드가 0 이다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/96-machine-local-state-key` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 전부 옮김 | 옛 디렉터리에 `project.json`(이 루트) · 커서 · 지표 · `usage.log` · 깨끗한 worktree, install | 전부 키 아래, worktree 새 경로, 옛 디렉터리 없음, 출력에 `moved` · `removed` |
| UT-02 | 남김 | 미커밋 변경 worktree 와 잠긴 worktree | 옛 자리 그대로, `left` 와 `uncommitted changes` · `locked`, `kept`, 옛 `project.json` 남음 |
| UT-03 | 다시 옮김 | UT-02 뒤 커밋 · 잠금 해제 · render | 옮겨지고 옛 디렉터리 없음 |
| UT-04 | 합치기 | 키 아래 같은 이름의 스팬 파일 · `usage.log` · 커서 | 옛 줄이 끝에 붙고 원래 줄 남음, 커서는 새 것 |
| UT-05 | 다른 경로 | 옛 `project.json` 의 `path` 가 다른 리포 | 아무것도 옮기지 않음, 출력 없음 |
| UT-06 | worktree 의 렌더 | 이슈 worktree 에서 render | 옮기지 않음 |
| UT-07 | doctor 알림 | 옮기기 전 상태에서 doctor | `registry` 절에 `state under the old name directory is not moved` `warn` |

## T7 · feat: UI 가 harness projects 로 목록을 받고 클론 키로 라우트

### 상위 Requirement

- relates to #96

### 작업 내용

UI 가 등록부 디렉터리를 읽지 않고 `harness projects` 의 출력으로 프로젝트 목록을 만들며, `/[project]/` 라우트 인자를 클론 키로 쓴다.
화면에는 이름과 경로를 보여 같은 이름의 클론을 구별한다.

- 명세 6-1(등록 목록) · 6-2(라우트와 표시) · 6-3(새 프로젝트) · 8-4 의 `harness.test.js`
- `src/ui/lib/harness.js`: `listProjects()` 가 `harness projects` 를 부르고 순수 함수 `parseProjects()` 로 옮긴다. `registeredPath()` 를 없앤다. `getProject(key)` 는 키가 같고 `ok` 인 항목
- `src/ui/lib/actions.js`: `project` 인자는 클론 키. `createProject` 의 같은 이름 거부를 없애고 설치 뒤 만든 경로의 키를 돌려준다. "등록부는 이름이 키" 주석을 지운다
- `src/ui/app/` · `src/ui/components/`: 홈 카드(`HomeGrid`) · 옛 등록 카드("재설치 필요") · 전환 메뉴(`[project]/layout.js`) · 사이드바 머리 · `Nav` · `MetricsView` · `NewProject` 를 명세 6-2 · 6-3 표대로
- 건드릴 파일: `src/ui/lib/harness.js` · `harness.test.js` · `actions.js`, `src/ui/app/`, `src/ui/components/`

### 완료 조건

- [ ] `src/ui/lib/` 에 등록부 디렉터리를 직접 읽는 코드가 없다
- [ ] `parseProjects()` 가 명세 3-4 형식을 `{ key, name, path, ok }` 와 `legacy` 항목으로 옮기고, 형식이 아닌 입력에 빈 배열을 돌려준다
- [ ] 홈 카드와 전환 메뉴의 링크가 `/<키>/settings` 이고 이름과 경로를 함께 보인다
- [ ] 옛 등록은 링크 없는 "재설치 필요" 카드로 보인다
- [ ] 새 프로젝트를 만들면 그 키의 설정 화면으로 이동한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/96-machine-local-state-key` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 등록 항목 옮김 | `projects` 두 항목이 든 명세 3-4 형식 JSON | `{ key, name, path, ok }` 두 개 |
| UT-02 | 옛 등록 옮김 | `legacy` 한 항목 | `key: null` · `ok: false` · `legacy: true` 로 붙는다 |
| UT-03 | 형식 아님 | 배열 · 문자열 · `null` · 필드 없는 객체 | 빈 배열 |
| UT-04 | 옛 케이스 정리 | `harness.test.js` | `registeredPath` · 디렉터리 읽기 케이스가 없다 |

## T8 · feat: UI Doctor 문구를 클론 키 등록 판정과 옛 자리표시에 맞춤

### 상위 Requirement

- relates to #96

### 작업 내용

CLI doctor 가 새로 내거나 바꾼 `registry` · `config` 줄을 UI Doctor 가 한국어 항목과 조치 명령으로 옮기게 한다.

- 명세 6-4(Doctor 문구) · 8-4 의 `doctor.test.js`
- `src/ui/lib/doctor.js`: `SECTIONS.registry` 는 `"등록"`. `explain()` 에 `this clone is registered to another path` · `this repository is not registered` ·
  `state under the old name directory is not moved` 세 줄(조치 `harness install` · `harness install` · `harness render`)과 `config` 절의 `` `<키>` uses `{project}` `` 줄(조치 없음).
  `` `<이름>` is registered to another path `` 옮김을 없앤다
- 건드릴 파일: `src/ui/lib/doctor.js` · `doctor.test.js`

### 완료 조건

- [ ] 세 `registry` 줄과 `{project}` 줄이 원문과 다른 한국어 제목 · 본문으로 옮겨진다
- [ ] 세 `registry` 항목의 `cmd` 가 명세 6-4 표대로이고 `{project}` 항목에는 `cmd` 가 없다
- [ ] 옛 `` `<이름>` is registered to another path `` 옮김과 그 케이스가 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/96-machine-local-state-key` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 절 이름 | `SECTIONS.registry` | `"등록"` |
| UT-02 | 다른 경로 | `this clone is registered to another path` 와 detail 경로 | 원문과 다른 제목 · 본문, 본문에 경로, `cmd` `harness install` |
| UT-03 | 미등록 | `this repository is not registered` | `cmd` `harness install` |
| UT-04 | 옮기지 않은 기록 | `state under the old name directory is not moved` | `cmd` `harness render` |
| UT-05 | 옛 자리표시 | `` `metrics.dir` uses `{project}` `` | 원문과 다른 제목 · 본문, `cmd` 없음 |

## T9 · docs: README 에 클론마다 따로인 등록과 기록, harness projects 안내

### 상위 Requirement

- relates to #96

### 작업 내용

T2 ~ T7 이 바꾼 동작을 사람용 설명에 적는다.

- 명세 7절(README)
- "시작하기" 의 `install` 설명: 등록과 기록이 클론마다 따로라는 것, 같은 이름은 알리기만 한다는 것, 이슈 worktree 는 그 클론의 등록과 기록을 쓴다는 것,
  옛 `~/.harness/<이름>/` 기록을 `install` · `render` 가 옮기고 옮기지 못한 worktree 는 사유와 함께 알린다는 것
- "UI" 절: `~/.harness/<클론 키>/project.json` 과 `harness projects`, 같은 이름의 클론은 경로로 구별, 옛 설치는 "재설치 필요"
- 명령 표에 `harness projects` 한 줄
- "harness.toml 이 정하는 것" 표: 세 설정 값의 `{clone}` 과 옛 별칭 `{project}`
- #79 가 적은 "한 기기 한 클론" · 같은 이름 거부 서술을 지운다
- 건드릴 파일: `README.md`

### 완료 조건

- [ ] README 네 곳이 명세 7절 표의 사실을 담는다
- [ ] 같은 이름 거부와 한 기기 한 클론 서술이 없다
- [ ] 추가한 문장에 개인 홈 절대 경로가 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/96-machine-local-state-key` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 문서 참조 | README 수정 뒤 `harness doctor` | README 가 가리키는 경로가 모두 있다는 `ok` 줄 |
| UT-02 | 반영 확인 | `README.md` | 네 곳에 명세 7절 사실이 있고 같은 이름 거부 서술이 없다 |

## T10 · docs: 용어·아키텍처 문서에 클론 키와 등록부 구조 반영

### 상위 Requirement

- relates to #96

### 작업 내용

T1 · T2 · T4 · T6 으로 생긴 클론 키와 등록부 구조를 에이전트가 근거로 읽는 문서에 적는다.

**보호 문서를 수정하는 task 다.** `.ai/project/glossary.md` · `.ai/project/architecture.md` 는 보호 문서이므로 사용자가 명시적으로 지시한 턴에서
고친다(`.ai/AI_AGENT.md` 금지 사항). 권한 설정 · 가드에 걸리면 사람이 대응한다.

- 명세 9절(보호 문서에 반영할 것)
- `.ai/project/glossary.md` "용어": `클론 키` 추가, `등록부` 뜻 갱신. "폐기된 별칭": `{project}` → `{clone}`
- `.ai/project/architecture.md` "구성 요소" 의 기기 단위 상태: 등록부와 기록이 클론 키 아래에 있고 같은 이름의 클론이 여럿 등록될 수 있다.
  "설치 등록부는 프로젝트 이름 하나에 경로 하나" 와 `install` 거부 서술을 지운다
- `.ai/project/architecture.md` "데이터 흐름" 의 실행 지표: 스팬 파일 위치 `.harness/<클론 키>/metrics/`
- `.ai/project/architecture.md` "계층과 의존 방향": 클론 키는 생성 파일에 들어가지 않고 실행할 때 `script/_clone_key.py` 로 계산하며, CLI · 지표 기록 · 사용 기록이 그 모듈 하나를 쓴다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/glossary.md`, `.ai/project/architecture.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] `.ai/project/glossary.md` 가 명세 9절 표의 세 사실을 담는다
- [ ] `.ai/project/architecture.md` 가 명세 9절 표의 세 사실을 담고 이름 하나 경로 하나 · install 거부 서술이 없다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 2장 · 5장이 두 문서와 일치한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/96-machine-local-state-key` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 반영 확인 | `.ai/AI_AGENT.md` | 2장에 `클론 키` 와 `{project}` 폐기 별칭, 5장에 클론 키 아래 기기 단위 상태와 `_clone_key.py` |
