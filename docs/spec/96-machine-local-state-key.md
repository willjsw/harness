# 기기 단위 상태의 클론 키

기기 단위 상태(설치 등록부 · 실행 지표 · 사용 기록 · 가져오기 커서 · 이슈 worktree)는 프로젝트 이름이 아니라
**클론 키**로 나뉜다. 클론 키는 하네스 루트의 git 공통 디렉터리와 리포 안의 위치에서 실행할 때 계산하는
불투명 값이다. 같은 리포를 한 기기에 여러 번 클론해도 클론마다 등록과 기록이 따로 있고, 한 클론의 worktree 는
그 클론과 같은 키를 쓴다. 생성 파일에는 키가 들어가지 않으므로 모든 클론에서 같다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 클론 키 계산 · 자리표시 풀기 | `src/templates/managed/script/_clone_key.py` (대상 리포의 `script/_clone_key.py`) |
| 등록 · 옮기기 · 목록 조회 · doctor · 지표 경로 · worktree 경로 | `src/bin/harness` |
| 지표 기록 | `src/templates/managed/script/metric.py` |
| 사용 기록 · 집계 | `src/templates/managed/script/usage-log.sh` · `usage-report.sh` |
| 설정 기본값 | `src/templates/harness.toml` · `src/bin/harness` 의 `METRICS_DEFAULTS` · `WORKTREE_DEFAULTS` · 이 리포의 `harness.toml` |
| UI 등록 목록 · 라우트 | `src/ui/lib/harness.js` · `src/ui/lib/actions.js` · `src/ui/app/` · `src/ui/components/` |
| UI doctor 문구 | `src/ui/lib/doctor.js` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/templates/managed/script/test-usage-log.sh` · `src/ui/lib/*.test.js` |
| 사람용 설명 | `README.md` |

## 1. 클론 키

### 1-1. 계산

입력은 하네스 루트 경로 하나다.

| 하네스 루트 | 해시 입력 |
|---|---|
| git 트리 안 — 아래 두 값을 둘 다 구했다 | `git\0<공통 디렉터리>\0<리포 안의 위치>` |
| 그 밖 — git 트리가 아니거나 git 을 실행하지 못했다 | `dir\0<하네스 루트의 실제 경로>` |

- 공통 디렉터리는 하네스 루트에서 `git rev-parse --path-format=absolute --git-common-dir` 를 돌린 출력을
  실제 경로(`os.path.realpath`)로 푼 값이다
- 리포 안의 위치는 하네스 루트에서 `git rev-parse --show-prefix` 를 돌린 출력이다. 리포 최상위면 빈 문자열이다
- 하네스 루트의 실제 경로는 `os.path.realpath` 로 푼 값이다
- 키는 `c-` 뒤에 해시 입력(UTF-8)의 SHA-256 16진 다이제스트 앞 16자를 붙인 것이다 — 정규식 `^c-[0-9a-f]{16}$`

결과:

| 경우 | 키 |
|---|---|
| 같은 클론의 linked worktree (`harness run --worktree` 가 만든 것 포함) | 그 클론과 같다 — 공통 디렉터리와 위치가 같다 |
| 같은 리포를 한 기기에 두 번 클론 | 서로 다르다 — 공통 디렉터리가 다르다 |
| 모노레포의 두 서브프로젝트 | 서로 다르다 — 리포 안의 위치가 다르다 |
| 클론을 다른 경로로 옮김 | 옮기기 전과 다르다 (9절) |

키는 원래 경로를 드러내지 않는다. 키는 템플릿 변수(`derive()`)에 넣지 않는다 — 생성 파일에 들어가지 않는다.

### 1-2. 공용 모듈 — `script/_clone_key.py`

python3 표준 라이브러리만 쓴다. 바이트코드를 쓰지 않는다(`sys.dont_write_bytecode`) — `script/__pycache__` 를 남기지 않는다.

| 함수 | 하는 일 |
|---|---|
| `clone_key(root)` | 1-1 의 키 |
| `expand(text, root)` | `text` 안의 `{clone}` 과 `{project}` 를 전부 `clone_key(root)` 로 바꾼 문자열. 자리표시가 없으면 git 을 부르지 않고 그대로 돌려준다. `~` 와 환경 변수는 풀지 않는다 |

명령줄: `python3 script/_clone_key.py expand <text>` — 하네스 루트를 이 파일이 있는 디렉터리의 부모로 보고 `expand` 결과를
한 줄 출력하고 0 으로 끝난다. 인자가 없거나 계산이 실패하면 아무것도 출력하지 않고 1 로 끝난다.

부르는 쪽은 셋이고 모두 이 모듈 하나를 쓴다. 계산을 다시 구현하지 않는다.

| 부르는 쪽 | 불러오는 방법 | 하네스 루트 |
|---|---|---|
| `src/bin/harness` | `TEMPLATES / "managed" / "script" / "_clone_key.py"` 를 `importlib` 로 (`metrics_module()` 과 같은 방식, 바이트코드 없이) | 대상(`--target`) |
| `script/metric.py` | 같은 디렉터리의 `_clone_key.py` 를 경로로 | `ROOT` |
| `script/usage-log.sh` · `script/usage-report.sh` | `python3 "$(dirname "$0")/_clone_key.py" expand "<값>"` | 스크립트 디렉터리의 부모 |

CLI 는 한 번 실행하는 동안 키를 한 번만 계산한다.

### 1-3. 이름공간 — `project.name` 검사

`validate()` 는 `project.name` 이 키 형식(`^c-[0-9a-f]{16}$`)과 같으면 종료 코드 2 로 거부한다. 안내문은 영어로 `error:` · `help:` 형식을 따른다.

```
error: project.name `<이름>` has the form of a clone key (c- and 16 hex digits)

help: choose another project.name in harness.toml
```

## 2. 자리표시 `{clone}` · `{project}`

### 2-1. 뜻

| 자리표시 | 푸는 값 |
|---|---|
| `{clone}` | 클론 키 |
| `{project}` | `{clone}` 의 옛 별칭. 같은 값(클론 키)으로 푼다 |

자리표시를 푸는 설정 값은 `metrics.dir` · `usage.log_path` · `worktree.dir` 셋이다. 기본값:

| 키 | 기본값 |
|---|---|
| `metrics.dir` | `$HOME/.harness/{clone}/metrics` |
| `usage.log_path` | `$HOME/.harness/{clone}/usage.log` |
| `worktree.dir` | `$HOME/.harness/{clone}/worktrees` |

`src/templates/harness.toml` · `METRICS_DEFAULTS` · `WORKTREE_DEFAULTS` · 이 리포의 `harness.toml` 이 이 값을 갖는다.
`src/templates/harness.toml` 의 각 키 주석에 `{clone}` 이 이 클론의 키로 풀린다는 것과 `{project}` 가 그 옛 별칭이라는 것을 적는다.

### 2-2. 생성 파일

렌더는 자리표시를 풀지 않는다. 설정 값을 그대로 생성 파일에 옮긴다.

| 생성 파일 | 들어가는 값 |
|---|---|
| `script/harness.plan.json` 의 `metrics.dir` | `metrics.dir` 설정 값 그대로 (`run_plan()` 이 `metrics_cfg()` 를 부르지 않고 `cfg["metrics"]` 를 싣는다) |
| `script/harness.env` 의 `USAGE_LOG_PATH` | `usage.log_path` 설정 값 그대로 |

그래서 두 클론의 생성 파일이 같고, 한 클론에서 렌더한 결과를 다른 클론의 `harness check` 가 통과시킨다.

### 2-3. 실행할 때 푸는 곳

| 곳 | 푸는 값 | 푼 뒤 |
|---|---|---|
| `src/bin/harness` 의 `metrics_cfg()` | `metrics.dir` | `cmd_metrics` 가 쓴다. `diagnostics.dir` 는 자리표시를 푼 값(환경 변수는 풀지 않은 것)이다 |
| `src/bin/harness` 의 `worktree_dir()` | `worktree.dir` | `~` 와 환경 변수를 확장한다. `harness run --worktree` · `doctor` · 세션 가져오기가 쓴다 |
| `script/metric.py` 의 `config()` | 계획 파일의 `metrics.dir` | `~` 와 환경 변수를 확장한다. 키를 계산하지 못하면 `None` — 기록하지 않는다 |
| `script/usage-log.sh` | `USAGE_LOG_PATH` | 셸이 `$HOME` 을 푼 뒤 모듈의 `expand` 로 자리표시를 푼다. 모듈이 1 로 끝나거나 python3 가 없으면 기록하지 않고 0 으로 끝난다 |
| `script/usage-report.sh` | 인자가 없을 때 읽는 `USAGE_LOG_PATH` | 같은 방식. 풀지 못하면 `error: could not resolve usage.log_path for this clone` 을 표준 오류로 내고 2 로 끝난다 |

- 설정 `usage.env_var` 가 가리키는 환경 변수로 준 경로는 자리표시를 풀지 않고 그대로 쓴다. `usage-log.sh` 는 이때 python3 를 부르지 않는다
- 값이 `off` 면 푸는 단계에 가지 않는다 — 지금처럼 기록하지 않는다
- 세션 가져오기의 커서 디렉터리는 `registry() / <클론 키> / "state"` 다 (`cmd_metrics` 가 `metrics_import` 에 넘긴다)

### 2-4. 옛 별칭 안내

`metrics.dir` · `usage.log_path` · `worktree.dir` 중 값에 `{project}` 가 든 키마다:

- `harness render` 가 표준 오류에 한 줄을 낸다. 렌더 결과와 종료 코드는 바뀌지 않는다

  ```
  note: <키> uses {project}, an old alias of {clone} — replace it with {clone} in harness.toml
  ```

- `harness doctor` 의 수집 함수가 `section` 이 `config` 인 `warn` 항목을 낸다

  | `what` | `detail` |
  |---|---|
  | `` `<키>` uses `{project}` `` | `an old alias of {clone} — replace it with {clone} in harness.toml` |

`<키>` 는 `metrics.dir` 처럼 점으로 이은 설정 키다.

### 2-5. worktree 자리가 다른 클론과 겹칠 때

`issue_worktree()` 가 자리를 이 리포의 worktree 가 아니라고 판정할 때의 안내를 바꾼다.

```
error: <경로> is not a worktree of this repository

help: another clone may share worktree.dir — put {clone} in worktree.dir or move that directory
```

## 3. 설치 등록부

### 3-1. 배치

`registry()` 는 지금처럼 `HARNESS_HOME` 이 있으면 그 경로, 없으면 `~/.harness` 다. 그 바로 아래 항목은 이렇게 가른다.

| 최상위 항목 | 무엇 |
|---|---|
| 이름이 키 형식(`^c-[0-9a-f]{16}$`)인 디렉터리 | 클론 하나의 상태 디렉터리. `project.json` 이 있으면 등록이다 |
| 이름이 `.` 으로 시작하는 항목 (`.install.lock` 등) | 등록부 내부 파일. 등록이 아니다 |
| 파일 (`tools.json` · `ui.pid` · `ui.log` 등) | 기기 단위 기록. 등록이 아니다 |
| 그 밖의 디렉터리 | 옛 이름 디렉터리. `project.json` 이 있으면 옛 등록이다 (3-4 의 `legacy`, 4절) |

새 기기 단위 파일은 파일로 두거나 이름을 `.` 으로 시작한다. 키 형식의 이름을 쓰지 않는다.

### 3-2. `project.json`

`registry()/<클론 키>/project.json`:

```json
{"path": "<하네스 루트>", "name": "<project.name>"}
```

- `path` 는 `main()` 이 `Path(args.target).resolve()` 로 정규화한 하네스 루트다
- `name` 은 설치할 때의 `project.name` 이다. 표시에만 쓰고 판정에 쓰지 않는다

### 3-3. 등록 · 해제

`harness install` 은 같은 이름의 기존 등록을 판정하지 않는다. `registration()` · `refuse_taken()` 과 그 거부 안내문,
`register()` 의 넘겨받기 안내 줄을 없앤다. 등록은 거부되지 않는다.

`cmd_install` 은 등록부 잠금(`registry_lock()`) 안에서 이 순서로 한다.

1. 고정 사본을 깐다 (소스 리포 분기는 옛 사본을 걷어낸다) — 지금과 같다
2. 옛 이름 디렉터리를 옮긴다 (4절)
3. `register(cfg, target)`
   1. `registry()/<클론 키>/project.json` 을 쓴다 (디렉터리가 없으면 0700 으로 만든다)
   2. 다른 키 디렉터리의 `project.json` 중 `path` 가 이 하네스 루트인 것을 지운다. 그 디렉터리의 다른 파일은 남는다
4. 같은 `name` 의 다른 등록을 알린다 (3-5)

잠금을 푼 뒤 렌더한다. 이 렌더는 4절 옮기기를 다시 돌리지 않는다.

- 같은 하네스 루트를 다시 설치하면 같은 키의 `project.json` 을 다시 쓴다 — 등록은 하나다
- `project.name` 을 바꾼 뒤 다시 설치하면 같은 키의 `name` 만 바뀐다. 기록은 그대로 이어진다
- 소스 리포 설치 분기도 같은 순서를 거친다. 옛 사본 걷어내기만 1번에서 다르다
- 이슈 worktree(`harness run --worktree`)는 install 을 돌지 않으므로 등록을 쓰지 않는다. 본 클론의 등록을 같은 키로 읽는다
- 등록부 파일이나 디렉터리를 쓰지 못하면(`OSError`) 지금처럼 예외가 설치를 멈춘다. 이 경우를 가르는 안내문은 없다

`harness uninstall` 은 `path` 가 이 하네스 루트인 `project.json` 을 키 디렉터리와 옛 이름 디렉터리 양쪽에서 지우고, 옛 이름
디렉터리의 다 옮김 표지 `.moved.json`(4-3)도 지운다 — 그 뒤로는 옮기지 않는다. 그 디렉터리 아래 기록은 남는다.

### 3-4. 목록 조회 — `harness projects`

등록 목록을 JSON 으로 표준 출력에 낸다. 설정을 읽지 않고 대상 리포가 필요 없다 — `tools` 처럼 `main()` 이 대상 해석 전에
처리하고, `DELEGATES` 에 넣지 않는다. 등록부를 바꾸지 않는다. `COMMANDS` 표 설명: `registered clones on this machine as JSON (for the UI)`.

```json
{
  "projects": [{"key": "c-…", "name": "demo", "path": "/…/demo", "ok": true}],
  "legacy":   [{"name": "old-demo", "path": null}]
}
```

| 필드 | 값 |
|---|---|
| `projects` | 키 형식 디렉터리 중 `project.json` 이 있는 것 |
| `projects[].key` | 디렉터리 이름 |
| `projects[].name` | `project.json` 의 `name` 이 비어 있지 않은 문자열이면 그 값, 아니면 키 |
| `projects[].path` | `project.json` 의 `path` 가 비어 있지 않은 문자열이면 그 값, 아니면 `null` |
| `projects[].ok` | `path` 가 있고 그 아래 `harness.toml` 이 파일로 있다 |
| `legacy` | 옛 이름 디렉터리 중 `project.json` 이 있는 것. `name` 은 디렉터리 이름, `path` 는 위와 같은 규칙 |

- `project.json` 이 JSON 으로 읽히지 않거나 객체가 아니면 `path` 는 `null` 이다. 예외로 멈추지 않는다
- 두 배열 모두 `name`, 그다음 `path`(`null` 은 뒤), 그다음 `key` 순으로 정렬한다
- 등록부 디렉터리가 없으면 `{"projects": [], "legacy": []}`

### 3-5. 같은 이름의 등록

`register()` 뒤, `name` 이 같고 키가 다른 등록마다 표준 출력에 한 줄을 낸다(`path` 순). 종료 코드는 바뀌지 않는다.

```
install: `<이름>` is also registered at <경로>
```

`path` 가 `null` 인 등록은 `<경로>` 자리에 `(no path)` 를 쓴다.

## 4. 옛 이름 디렉터리 옮기기

### 4-1. 언제

`migrate_legacy(cfg, target)` 가 옮긴다. 부르는 곳은 둘이다.

| 부르는 곳 | 잠금 |
|---|---|
| `cmd_install` (3-3 의 2번) | 이미 잡은 등록부 잠금 안 |
| `cmd_render` — `cmd_install` 이 부른 렌더는 빼고 | 렌더 시작 전에 `registry_lock()` 을 잡고, 옮긴 뒤 푼다 |

옮길 대상이 있는 조건은 모두 맞아야 한다.

- `<이름>` = `project.name` 이 키 형식이 아니다
- `registry()/<이름>/project.json` 이 있고, 그 `path` 를 실제 경로로 푼 값이 하네스 루트의 실제 경로와 같다.
  다 옮긴 디렉터리는 `project.json` 대신 다 옮김 표지 `.moved.json`(같은 형식)으로 판정한다 (4-3)

조건이 맞지 않으면 아무것도 하지 않고 출력도 없다. 이슈 worktree 에서 도는 렌더는 옛 `path` 가 본 클론이라 옮기지 않는다.
옛 이름 디렉터리 자체가 심볼릭 링크면 아무것도 옮기지 않고 `kept <옛 이름 디렉터리> — a symbolic link` 만 낸다.

### 4-2. 무엇을

옛 경로는 설정 값의 `{clone}` · `{project}` 를 `<이름>` 으로 푼 것, 새 경로는 클론 키로 푼 것이다(둘 다 `~` 와 환경 변수 확장).
옛 경로와 새 경로가 같거나 설정 값이 `off` 인 항목은 건너뛴다. 옮길 것이 남지 않은 항목도 건너뛴다(아래 "남은 것").

| 항목 | 옛 → 새 | 옮기는 방법 |
|---|---|---|
| 가져오기 커서 | `registry()/<이름>/state/` → `registry()/<클론 키>/state/` | 디렉터리 옮기기 |
| 실행 지표 | `metrics.dir` | 디렉터리 옮기기 — 기록기의 잠금 아래 |
| 사용 기록 | `usage.log_path` | 사용 기록 옮기기 |
| 이슈 worktree | `worktree.dir` 바로 아래, 이 리포에 등록된 worktree 마다 | `git -C <git 최상위> worktree move <옛 경로> <새 경로>` |

옛 버전 하네스는 옮긴 뒤에도 옛 경로에 쓸 수 있다. 그래서 옮기기는 새 이름을 덮지 않고, 옛 쪽 기록은 새 쪽에 반영된 뒤에만
지우며, 옛 기록기가 쓰는 자리(디렉터리 · 표지 · 덧붙인 사용 기록)는 남긴다. 남긴 자리에 그 뒤로 생긴 기록은 다음
install · render 가 옮긴다.

**링크.** 아래 중 하나면 그 항목을 옮기지 않고 `left` 로 사유를 알린다. 링크는 사람이 정리한다.

| 판정 | 알림의 `<사유>` |
|---|---|
| 옛 경로가 심볼릭 링크다 | `a symbolic link` |
| 옛 경로와 새 경로가 실제 경로로 같거나 한쪽이 다른 쪽 안에 있다 | `overlaps the new path` |
| 자리표시가 든 성분부터 옛 경로까지에 링크가 있거나, 옛 디렉터리 안에 링크(파일이든 디렉터리든)가 있다 | `holds a symbolic link` |
| 새 경로 쪽에 같은 방식으로 링크가 있다 | `a symbolic link at the new path` |

worktree 디렉터리(`worktree.dir` 의 옛 경로)도 같은 판정을 거친다 — 그 안의 링크는 보지 않는다(worktree 의 파일이다). 걸리면
`left worktrees at <옛 경로> — <사유>` 로 통째로 남긴다.

**디렉터리 옮기기.** 새 디렉터리가 없으면 만들고(0700) 옛 디렉터리의 파일을 하나씩 옮긴다. 옛 디렉터리는 옮기지 않고 남긴다.

- 실행 지표는 기록기(`script/metric.py`)의 잠금 파일 `.lock` 을 옛 · 새 디렉터리 양쪽에서 잡은 채 옮긴다. 기록기는 그 잠금
  아래에서 파일을 경로로 열어 쓰므로, 옛 파일을 지운 뒤에 쓰는 기록기는 옛 자리에 새 파일을 만든다
- 기록기의 표지(`.lock` · `.pruned`)는 옮기지도 지우지도 않는다
- 새 이름은 하드 링크로 차지한다. 새 이름이 없으면 옛 파일에 새 이름을 걸고 옛 이름을 지운다
- 새 이름이 이미 있거나 그 사이 생겼으면
  - `spans-*.jsonl` 은 옛 내용을 새 파일 끝에 덧붙이고(추가 쓰기, 새 파일이 줄 중간에서 끝나면 줄을 바꾼 뒤) 옛 파일을 지운다
  - 그 밖(`state/import-cursor.json` 등)은 새 것을 남기고 옛 것을 지운다
- 하드 링크를 만들 수 없으면(파일 시스템이 지원하지 않거나 장치가 다르다) `spans-*.jsonl` 은 새 파일에 덧붙여(없으면 만든다) 옮기고, 그 밖의 파일은 옛 자리에
  남긴 채 항목을 `left <항목> at <옛 경로> — cannot hard-link to the new path` 로 알린다
- 덧붙이기는 옛 파일을 고정 크기 조각(1MiB)씩 읽어 쓴다 — 기록 크기에 비례한 메모리를 쓰지 않는다
- 덧붙이다 실패하면 잠금 아래인 실행 지표는 이번에 붙인 앞부분(여러 조각이면 그 전부)을 잘라 되돌린다. 옛 파일은 남는다
- 한 파일의 두 이름(지난번에 새 이름을 걸고 옛 이름을 지우기 전에 멈춘 것)이면 옛 이름만 지운다
- 읽지 못하는 하위 디렉터리를 만나면 거기서 멈추고 항목을 `left … — <예외 클래스 이름>` 으로 알린다
- 옮긴 지표 디렉터리와 커서 디렉터리는 0700, 그 안의 파일은 0600 이다

**사용 기록 옮기기.** 사용 기록 기록기(`script/usage-log.sh`)는 잠금 없이 덧붙인다.

- 새 파일이 없으면 옛 파일에 새 이름을 하드 링크로 걸고 옛 이름을 지운다. 한 파일이라 옛 이름으로 연 기록기가 늦게 쓴 줄도
  새 파일에 남는다
- 새 파일이 있거나(그 사이 생긴 것도) 하드 링크를 만들 수 없으면, 옛 파일에서 지난번에 덧붙인 자리 뒤의 온전한 줄(마지막
  줄바꿈까지)을 새 파일 끝에 덧붙이고(없으면 0600 으로 만든다) 그 자리를 옛 이름 디렉터리의 `.moved-offsets.json` 에 적는다.
  **옛 파일은 지우지 않는다** — 옛 파일을 열어 둔 기록기가 그 뒤에 쓴 줄은 다음 install · render 가 덧붙인다
- `.moved-offsets.json` 은 옛 경로마다 장치 번호 · inode · 덧붙인 바이트 위치 · 그 위치까지의 앞부분(많아야 4KiB) sha256 을 담는다.
  옛 파일이 그 장치 · inode · 앞부분과 같고 그 위치보다 줄지 않았을 때만 그 뒤부터 잇고, 아니면 처음부터 덧붙인다. 파일이
  없거나 읽히지 않으면 처음부터다
- 남은 줄 판정과 덧붙이기는 옛 파일을 고정 크기 조각(1MiB)씩 읽는다 — 기록 크기에 비례한 메모리를 쓰지 않는다. 판정은
  파일 끝에서부터 거꾸로 읽어 마지막 줄바꿈을 찾는다. 덧붙이기는 조각을 그 안의 마지막 줄바꿈에서 끊어 쓴다 — 그 사이 다른
  기록기가 새 파일에 덧붙인 줄은 옛 줄과 옛 줄 사이에만 들어간다(옛 줄이 한 덩어리로 이어지지 않을 수 있다)
- 자리는 덧붙인 뒤에 바꾼다(임시 파일에 써 두고 이름을 바꾼다). 덧붙이다 실패하면 붙이다 만 앞부분을 그대로 두고 자리를
  바꾸지 않는다 — 잠금이 없어 되돌리면 다른 기록기의 줄을 자를 수 있다. 덧붙이는 도중 옛 파일이 줄어 판정한 끝까지 읽을
  것이 없어도 실패다
- 옛 경로가 일반 파일이 아니면 `left usage log at <옛 경로> — not a file`

**남은 것.** 항목마다 옮길 것이 남았는지를 이렇게 가른다. 옮긴 뒤에도 남았으면 4-3 의 `kept` 수에 든다.

| 항목 | 남았다 |
|---|---|
| 가져오기 커서 · 실행 지표 | 옛 디렉터리에 표지 말고 파일이 있거나, 링크(파일이든 디렉터리든)가 있거나, 읽지 못하는 하위 디렉터리가 있다. 옛 경로가 링크이거나 디렉터리가 아니어도 남았다 |
| 사용 기록 | 옛 파일에 아직 덧붙이지 않은 온전한 줄이 있다. 옛 경로가 링크이거나 일반 파일이 아니거나, 새 파일과 한 파일이거나, 읽지 못해도 남았다 |
| 이슈 worktree | 옛 `worktree.dir` 바로 아래에 이 리포의 worktree 가 등록돼 있다. 옛 worktree 디렉터리를 링크 판정으로 통째로 남기면 1 |

worktree 는 아래 중 하나면 옮기지 않고 남긴다.

| 사유 | 판정 | 알림의 `<사유>` |
|---|---|---|
| 잠겼다 | `git worktree list --porcelain` 의 그 항목에 `locked` 줄이 있다 | `locked` |
| 미커밋 변경 | 그 경로에서 `git status --porcelain` 출력이 있거나 명령이 실패한다 | `uncommitted changes` |
| 경로가 없다 | 등록만 남고 디렉터리가 없다 | `missing — run git worktree prune` |
| 새 자리가 이미 있다 | 새 경로가 있다 | `destination exists` |
| git 이 거부했다 | `git worktree move` 가 0 이 아닌 코드로 끝났다 | `git worktree move failed` |

worktree 에 등록되지 않은 옛 `worktree.dir` 아래 디렉터리는 건드리지 않는다.

### 4-3. 마무리

항목을 다 처리한 뒤:

1. `registry()/<클론 키>/project.json` 이 없으면(그 이름에 아무것도 없으면) 3-2 형식으로 쓴다. 키 디렉터리가 링크면 쓰지 않는다
2. 4-2 의 "남은 것" 이 있으면 옛 이름 디렉터리를 `project.json` 까지 그대로 둔다 — 다음 install · render 가 다시 옮긴다
3. 남은 것이 없고 옛 `project.json` 이 일반 파일이면 그것을 `.moved.json` 으로 이름을 바꾼다. 옛 이름 디렉터리와 그 안의
   디렉터리 · 표지 · 덧붙인 사용 기록 · `.moved-offsets.json` 은 남긴다. `.moved.json` 은 등록이 아니라 `harness projects` 의
   `legacy` 에 나오지 않고, 다음 install · render 는 이것으로 4-1 을 판정해 옛 버전이 그 뒤로 남긴 기록을 계속 옮긴다

옮기기를 시작할 때 옛 이름 디렉터리 바로 아래의 `.harness-move-` 로 시작하는 임시 파일(멈춘 실행이 남긴 것)을 지운다.

### 4-4. 출력

표준 출력에 낸다. `<명령>` 은 `install` 또는 `render` 다. 옮기기는 종료 코드를 바꾸지 않는다 — 실패해도 설치·렌더는 이어진다.

```
<명령>: moved <항목> to <새 경로>
<명령>: left <항목> at <옛 경로> — <사유>
<명령>: left worktrees at <옛 경로> — <사유>
<명령>: kept <옛 이름 디렉터리> — <N> item(s) left there
<명령>: kept <옛 이름 디렉터리> — a symbolic link
<명령>: cleared <옛 이름 디렉터리> — files older versions may still write to stay there; render moves what they add
```

| `<항목>` | 값 |
|---|---|
| 가져오기 커서 | `import state` |
| 실행 지표 | `run metrics` |
| 사용 기록 | `usage log` |
| 이슈 worktree | `worktree <이름>` |

`<사유>` 는 4-2 의 표와 목록에 있는 것이다. 옮기기가 `OSError` 로 실패하면 그 항목을 `left … — <예외 클래스 이름>` 으로 알리고
다음 항목으로 간다. `<N>` 은 4-2 의 "남은 것" 의 수다. `cleared` 는 옛 `project.json` 을 `.moved.json` 으로 바꾼 실행만 낸다.

## 5. `harness doctor` — `registry` 절

doctor 의 수집 함수가 `section` 이 `registry` 인 항목을 낸다. 항목 형식(`{section, state, what, detail}`)과 절 순서
(`tools and connections` 다음, `git` 앞), 텍스트·JSON 렌더는 doctor 결과 목록의 규칙을 따른다. 판정은
`registry()/<클론 키>/project.json` 과 옛 이름 디렉터리로 한다. 등록부를 바꾸지 않는다.

| 상태 | `state` | `what` | `detail` |
|---|---|---|---|
| `path` 가 하네스 루트와 같거나, `path` 의 클론 키가 이 하네스 루트의 클론 키와 같다 (같은 클론의 worktree) | `ok` | ``registered as `<name>` `` | 빈 문자열 |
| `path` 가 있으나 위에 해당하지 않는다 | `warn` | `this clone is registered to another path` | `<그 경로>` |
| `project.json` 이 없다 · JSON 으로 읽히지 않는다 · `path` 가 비어 있지 않은 문자열로 없다 | `warn` | `this repository is not registered` | `` run `harness install` to list it in the UI `` |
| 4-1 의 옮길 조건이 맞고 4-2 의 "남은 것" 이 있다 — 위 항목에 더해 | `warn` | `state under the old name directory is not moved` | `` run `harness render` to move `<옛 이름 디렉터리>` `` |

- `<name>` 은 `project.json` 의 `name`, 없으면 `project.name` 이다
- `path` 의 클론 키는 1-1 규칙대로 그 경로에서 계산한다. 경로가 없거나 git 이 답하지 못하면 경로 대체 규칙의 키가 되어
  이 하네스 루트의 키와 다르다 — 다른 경로 `warn` 이다
- 모노레포에서 같은 리포의 다른 서브프로젝트는 리포 안의 위치가 달라 키가 다르다. 같은 클론의 worktree 로 보지 않는다
- 같은 이름의 다른 등록은 보고하지 않는다 — 여러 클론은 정상 상태다
- 이 절은 `bad` 를 내지 않는다. `harness status` 의 `doctor.items` 에 같은 항목이 그대로 들어간다

## 6. UI

### 6-1. 등록 목록 — `src/ui/lib/harness.js`

- `listProjects()` 는 등록부 디렉터리를 읽지 않는다. `harness projects` 를 부르고(`readTools` 와 같이 `harness(HOME, […])`)
  그 출력을 `parseProjects()` 로 옮긴다. 명령이 실패하면 빈 목록이다
- `parseProjects(json)` — 순수 함수. `projects` 항목을 `{ key, name, path, ok }` 로, `legacy` 항목을
  `{ key: null, name, path, ok: false, legacy: true }` 로 옮겨 한 배열로 돌려준다. 입력이 3-4 형식이 아니면 빈 배열이다
- `registeredPath()` 는 없앤다 — 경로 판정은 CLI 가 한다
- `getProject(key)` 는 `key` 가 같고 `ok` 인 항목을 찾는다. 없으면 지금처럼 예외다

### 6-2. 라우트와 표시

| 곳 | 라우트 인자 · 키 | 화면에 보이는 것 |
|---|---|---|
| `/[project]/` 라우트 전부 · `actions.js` 의 `project` 인자 | 클론 키 | — |
| 홈 카드 (`HomeGrid`) | 링크 `/<키>/settings`, 상태 캐시와 React `key` 는 클론 키 | `name` 과 그 아래 `path`. 아바타는 `name` 으로 |
| 옛 등록 카드 | 링크 없음 | `name` 과 "재설치 필요". 제목 설명: 옛 설치다 — 그 프로젝트에서 `harness install` 을 다시 돌린다 |
| 전환 메뉴 (`[project]/layout.js`) | 링크 `/<키>/settings`, 현재 항목 판정은 키 | `name` 과 `path` |
| 사이드바 머리 · `Nav` · `MetricsView` | 링크 기반은 `/<키>` | 현재 항목의 `name` |

키에 해당하는 등록이 없을 때의 화면은 `[project]/layout.js` 가 지금 방식대로 그린다.

### 6-3. 새 프로젝트 — `createProject`

- 같은 이름의 등록이 있으면 거부하는 검사를 없앤다
- `harness install` 이 성공하면 `listProjects()` 에서 `path` 가 만든 경로와 같은 항목을 찾아 그 `key` 를 돌려준다(`{ …, key }`).
  `NewProject` 는 `/<키>/settings` 로 이동한다. 찾지 못하면 이동하지 않고 결과만 보인다
- 등록부 안에 만들지 않는 검사는 그대로다
- 주석의 "등록부는 이름이 키" 서술을 지운다

### 6-4. Doctor 문구 — `src/ui/lib/doctor.js`

`SECTIONS.registry` 는 `"등록"` 이다. `explain()` 의 `registry` 줄:

| 줄 | 항목에 담는 것 | 조치 |
|---|---|---|
| `this clone is registered to another path` | 이 클론의 등록이 다른 경로(detail)를 가리켜 UI 가 그쪽을 연다는 것. 여기서 다시 설치하면 이 경로로 등록된다는 것 | `cmd`: `harness install` |
| `this repository is not registered` | UI 프로젝트 목록에 나오지 않는다는 것 | `cmd`: `harness install` |
| `state under the old name directory is not moved` | 옛 이름 디렉터리의 기록이 아직 이 클론으로 옮겨지지 않았다는 것. 렌더가 옮기고, 옮기지 못한 worktree 는 렌더 출력이 사유와 함께 알린다는 것 | `cmd`: `harness render` |

`config` 절의 `` `<키>` uses `{project}` `` 줄은 `{project}` 가 `{clone}` 의 옛 별칭이고 같은 값으로 풀린다는 것과
`harness.toml` 의 그 값을 `{clone}` 으로 바꾸라는 것을 담는다. 조치 명령은 없다.

`` `<이름>` is registered to another path `` 줄의 옮김은 없앤다.

## 7. README

| 절 | 적는 사실 |
|---|---|
| "시작하기" 의 `install` 설명 | 등록과 기록은 클론마다 따로다 — 같은 리포를 한 기기에 여러 번 클론해 각각 설치할 수 있다. 같은 이름이 이미 등록돼 있으면 `install` 이 알리기만 한다. 한 클론의 이슈 worktree 는 그 클론의 등록과 기록을 쓴다. 옛 버전이 `~/.harness/<이름>/` 에 남긴 기록은 `install` · `render` 가 이 클론 아래로 옮기고, 옮기지 못한 worktree 는 사유와 함께 알린다 |
| "UI" | `harness install` 이 `~/.harness/<클론 키>/project.json` 에 경로와 이름을 남기고, UI 는 `harness projects` 로 목록을 받는다. 같은 이름의 클론은 경로로 구별된다. 옛 설치는 "재설치 필요" 로 뜬다 |
| 명령 표 | `harness projects` — 이 기기에 등록된 클론 목록(JSON). UI 가 쓴다 |
| "harness.toml 이 정하는 것" 표 | `metrics.dir` · `usage.log_path` · `worktree.dir` 의 `{clone}` 은 실행할 때 이 클론의 키로 풀린다. `{project}` 는 옛 별칭이다 |

## 8. 회귀 테스트

등록부는 `render-test.sh` 가 이미 두는 `HARNESS_HOME` 을 쓴다. 지표·사용 기록 경로를 보는 케이스는 설정 값을
테스트 작업 디렉터리 아래(`{clone}` 포함)로 고정한다. 기대 키는 설치된 `script/_clone_key.py` 로 구한다.

### 8-1. `render-test.sh` — 새 블록

| 블록 | 케이스 | 확인하는 것 |
|---|---|---|
| UT-75 클론 키 | worktree | 한 리포와 그 `git worktree add` worktree 의 키가 같다 |
| | 두 클론 | 같은 원격을 두 번 clone 한 두 경로의 키가 다르다 |
| | 모노레포 | 같은 리포의 두 서브디렉터리를 하네스 루트로 두면 키가 다르다 |
| | git 밖 | git 트리가 아닌 디렉터리의 키가 키 형식이고, 같은 디렉터리에서 다시 구하면 같다 |
| | 형식 | 모든 키가 `^c-[0-9a-f]{16}$` 이고 하네스 루트의 경로 조각을 담지 않는다 |
| | 명령줄 | `expand` 가 `{clone}` 과 `{project}` 를 같은 값으로 바꾸고, 자리표시 없는 값은 그대로 낸다. 인자 없이 부르면 1 |
| | 이름 검사 | `project.name` 이 키 형식이면 `render` 가 멈추고 `error:` 를 낸다 |
| UT-76 두 클론 공존 | 등록 | 같은 `project.name` 의 두 클론을 install 하면 둘 다 종료 코드 0, 두 키 디렉터리에 각자의 `path` 와 같은 `name`. 두 번째 install 출력에 `is also registered at` 과 첫 클론 경로 |
| | 생성 파일 | 두 클론의 `script/harness.plan.json` · `script/harness.env` 가 같고, 한쪽 파일을 다른 쪽에 복사해도 `harness check` 가 통과한다. 두 파일에 키가 없다 |
| | 기록 경로 | 두 클론에서 `script/metric.py` 로 스팬을 남기고 `script/usage-log.sh` 로 한 줄 남기면 서로 다른 키 디렉터리 아래에 쌓인다 |
| | worktree | 한 클론의 worktree 에서 남긴 스팬이 그 클론의 키 디렉터리에 쌓인다 |
| | 재설치 | 같은 클론을 다시 설치하면 종료 코드 0 이고 등록이 하나다. `project.name` 을 바꿔 다시 설치하면 같은 키의 `name` 만 바뀌고 기록 디렉터리 아래 표지 파일이 남는다 |
| | 소스 리포 | 소스 트리 복제본 두 개를 같은 이름으로 설치하면 둘 다 통과하고 각자의 키로 등록된다 |
| | uninstall | 한 클론을 uninstall 하면 그 키의 `project.json` 만 없고 다른 클론의 등록과 두 기록은 남는다 |
| | `projects` | 출력이 3-4 형식이고, 두 클론이 `ok` 로 경로 순, 옛 이름 디렉터리의 `project.json` 은 `legacy` 에, `tools.json` · `.install.lock` · 최상위 `ui.log` 파일은 어디에도 없다. 설정 없는 디렉터리에서도 돈다 |
| UT-77 옛 이름 디렉터리 옮기기 | 전부 옮김 | 옛 `~/<이름>/` 에 `project.json`(이 루트) · `state/import-cursor.json` · 지표 파일 · `usage.log` 와 깨끗한 이슈 worktree 하나를 두고 install 하면 전부 키 아래로 가고, worktree 는 `git worktree list` 에 새 경로로 있으며, 옛 디렉터리에 옮길 기록이 없고 옛 `project.json` 이 `.moved.json` 으로 바뀐다. 옛 지표 디렉터리와 `.lock` 은 남는다. 출력에 `moved` 와 `cleared`. uninstall 하면 `.moved.json` 이 없다 |
| | 남김 | 미커밋 변경이 있는 worktree 와 잠긴 worktree 는 옛 자리에 그대로 있고 출력에 `left` 와 각 사유, `kept`. 옛 `project.json` 이 남는다. 변경을 커밋·잠금을 푼 뒤 render 하면 옮겨지고 옛 `project.json` 이 `.moved.json` 으로 바뀐다 |
| | 합치기 | 키 아래에 같은 이름의 스팬 파일·`usage.log` 가 이미 있으면 옛 줄이 새 파일 끝에 붙고 원래 줄도 남는다. 커서는 새 것이 남는다. 옛 `usage.log` 는 그대로 남고, 다시 render 해도 줄이 겹치지 않는다 |
| | 링크 | 옛 쪽(항목 · 이름 디렉터리 자체 · 안쪽 · 상위 경로로 겹침)이나 새 쪽에 링크가 있으면 4-2 의 사유로 남기고 링크가 가리키는 파일을 바꾸지 않는다. 링크 디렉터리만 든 옛 디렉터리도 남은 것으로 세어 `kept` 이고 doctor 가 `warn` 이다 |
| | 다른 기록기 | 지표는 옛 · 새 `.lock` 을 잡은 채 합치고, 합치는 동안 덧붙인 사용 기록 줄을 덮지 않는다. 옛 `.lock` 을 열고 기다리던 기록기는 같은 잠금 파일을 얻어 옛 자리에 쓰고, 그것을 다음 render 가 옮긴다 |
| | 늦은 쓰기 | 옛 `usage.log` 를 열어 둔 기록기가 render 뒤에 쓴 줄이, 새 파일이 있었으면 doctor `warn` 뒤 다음 render 에 한 번 덧붙고, 없었으면 이미 새 파일에 있다. 그 뒤 render 는 아무것도 옮기지 않는다 |
| | 하드 링크 없음 | 새 이름을 드러내기 바로 전에 새 기록기가 그 이름에 써도 덮지 않는다 — 사용 기록은 그 줄 뒤에 덧붙고 옛 파일이 남으며, 스팬은 덧붙여 옮겨지고, 커서는 `cannot hard-link to the new path` 로 옛 자리에 남는다. 다음 실행이 같은 줄을 다시 옮기지 않는다 |
| | 쓰기 실패 | 하드 링크 없이 덧붙이다 디스크가 차면 `left … — OSError`. 지표는 새 파일에 붙이다 만 것이 남지 않고 옛 파일이 남으며, 사용 기록은 옛 파일이 남고 `.moved-offsets.json` 이 없다. 다음 실행이 온전한 줄을 옮긴다 |
| | 조각 | 조각 크기를 몇 바이트로 줄여도 남은 것 판정 · 옮긴 내용 · 덧붙인 자리 · 출력이 한 조각일 때와 같고, 옛 기록을 한 번에 읽는 크기가 조각(또는 앞부분 4KiB)을 넘지 않는다. 여러 조각을 쓰다 실패한 스팬은 붙인 것이 다 되돌려지고, 조각 사이에 끼어든 다른 기록기의 줄은 옛 줄 사이에 온전히 있다. 덧붙이는 도중 줄어든 옛 사용 기록은 `left … — OSError` 이고 자리를 적지 않는다 |
| | 끊긴 옮기기 | 새 이름을 걸고 옛 이름을 지우기 전에 멈춘 사용 기록은 옛 이름만 지우고 줄을 겹치지 않는다. 옛 이름 디렉터리의 `.harness-move-` 임시 파일이 지워진다 |
| | 읽지 못함 | 옛 커서 디렉터리 안의 읽지 못하는 하위 디렉터리는 `left … — PermissionError` 와 `kept` 로 남는다 |
| | 거부된 렌더 | 사용자 파일로 거부된 render 는 아무것도 옮기지 않는다 |
| | 다른 경로 | 옛 `project.json` 의 `path` 가 다른 경로면 아무것도 옮기지 않고 출력이 없다 |
| | worktree 의 렌더 | 이슈 worktree 에서 render 하면 옮기지 않는다 |
| | doctor | 옮기기 전 상태의 리포에서 `registry` 절에 `state under the old name directory is not moved` `warn` |
| UT-78 옛 별칭 | 같은 값 | 세 설정 값을 `{project}` 로 두면 `{clone}` 과 같은 경로에 기록되고, 생성 파일은 설정 값 그대로다 |
| | 안내 | render 표준 오류에 키마다 `note:` 와 `{clone}`, doctor `config` 절에 키마다 `warn`. render 종료 코드 0 |
| | 기본값 | 기본 설정의 세 값이 `{clone}` 이고 `{project}` 가 없다 |
| UT-79 doctor `registry` | 상태별 | 등록된 클론 `ok`, 그 `git worktree add` worktree `ok` 이고 `warn` 없음, 등록이 없는 리포 `warn` `this repository is not registered`, 키의 `path` 를 다른 리포로 바꾼 등록 `warn` 과 그 경로. 어느 쪽도 `FAIL` 이 아니다 |
| | 모노레포 | 같은 리포의 다른 서브디렉터리에 같은 이름으로 둔 하네스 루트는 자기 키로 판정한다 — 설치하지 않았으면 `this repository is not registered` |
| | 바꾸지 않음 | doctor 전후로 등록부 파일이 같고, 등록이 없는 리포에서 doctor 가 등록을 만들지 않는다 |
| | JSON | `harness doctor --json` 의 `items` 에 `section` 이 `registry` 인 항목이 표대로 있다 |

터미널 출력의 한글 검사는 이 블록들의 출력에도 적용한다.

### 8-2. 기존 블록

- UT-62 블록을 지운다. 그 안의 재설치 · uninstall · 소스 리포 등록 케이스는 UT-76 이 새 구조로 덮는다
- 등록부와 가져오기 커서를 `$HARNESS_HOME/<이름>/…` 로 읽는 케이스(소스 리포 등록 · UT-36 · UT-56 · UT-73)는 클론 키 경로로 읽는다
- UT-70 처럼 `{project}` 기본값 문자열을 찾는 케이스는 `{clone}` 을 찾는다
- 같은 이름으로 여러 리포를 설치하려고 이름을 나눠 둔 케이스는 그대로 둔다 — 검증하는 내용은 바뀌지 않는다

### 8-3. `test-usage-log.sh`

| 케이스 | 확인하는 것 |
|---|---|
| 자리표시 | 환경 변수 덮어쓰기 없이 `USAGE_LOG_PATH` 가 `{clone}` 을 담으면 `expand` 로 푼 경로에 한 줄이 쌓인다 |
| 옛 별칭 | `{project}` 도 같은 경로에 쌓인다 |
| 풀지 못함 | `_clone_key.py` 가 1 로 끝나면(스텁으로 대신) 아무 파일도 생기지 않고 0 으로 끝난다 |
| 덮어쓰기 | 환경 변수로 준 경로는 `{clone}` 문자가 들어 있어도 그대로 쓴다 |

### 8-4. UI 단위 테스트

| 파일 | 케이스 |
|---|---|
| `harness.test.js` | `parseProjects()` 가 3-4 형식을 `{ key, name, path, ok }` 로 옮기고 `legacy` 항목을 `key: null` · `ok: false` · `legacy: true` 로 붙인다. 형식이 아닌 입력(배열 · 문자열 · `null` · 필드 없음)은 빈 배열. 기존 `registeredPath` · 디렉터리 읽기 케이스는 지운다 |
| `doctor.test.js` | `SECTIONS.registry` 가 `"등록"` 이다. 6-4 의 세 `registry` 줄과 `config` 의 `{project}` 줄이 원문과 다른 제목·본문으로 옮겨지고, 앞의 셋의 `cmd` 가 표대로다. 옛 `` `demo` is registered to another path `` 케이스는 지운다 |

## 9. 보호 문서에 반영할 것

사람이 지시한 턴에 반영한다.

| 문서 · 위치 | 반영할 사실 |
|---|---|
| `.ai/project/glossary.md` "용어" | `클론 키` — 한 기기에서 하네스 루트 하나(클론 하나, 모노레포면 서브프로젝트 하나)를 가리키는 불투명 값. git 공통 디렉터리와 리포 안의 위치에서 실행할 때 계산한다. 같은 클론의 worktree 는 같은 키다. 기기 단위 상태가 이것으로 나뉜다 |
| `.ai/project/glossary.md` "용어" 의 `등록부` | 클론 키마다 `project.json` 하나(`~/.harness/<클론 키>/`)와 기기의 도구 기록. UI 가 `harness projects` 로 목록을 받는다 |
| `.ai/project/glossary.md` "폐기된 별칭" | `{project}` (`metrics.dir` · `usage.log_path` · `worktree.dir` 의 자리표시) → `{clone}`. 같은 값(클론 키)으로 풀린다 |
| `.ai/project/architecture.md` "구성 요소" 의 기기 단위 상태 | 설치 등록부(`<클론 키>/project.json` — 경로와 이름)와 지표·사용 기록·가져오기 커서·이슈 worktree 는 클론 키 아래에 있다. 이름이 같은 클론이 여럿 등록될 수 있다. "설치 등록부는 프로젝트 이름 하나에 경로 하나" 와 `install` 의 거부 서술을 지운다 |
| `.ai/project/architecture.md` "데이터 흐름" 의 실행 지표 | 스팬 파일 위치가 `.harness/<클론 키>/metrics/` 다 |
| `.ai/project/architecture.md` "계층과 의존 방향" | 클론 키는 생성 파일에 들어가지 않고 실행할 때 `script/_clone_key.py` 로 계산한다. CLI · 지표 기록 · 사용 기록이 그 모듈 하나를 쓴다 |

## 10. 한계

- 클론을 다른 경로로 옮기면 공통 디렉터리가 바뀌어 키가 바뀐다. 옛 키 디렉터리의 기록은 이어지지 않고, 옛 등록은
  `harness projects` 에 `ok: false` 로 남는다
- git 밖 하네스 루트에서 나중에 `git init` 하면 키가 바뀐다
- 옮기기는 다른 프로세스가 쓰는 중인 worktree 를 알아보지 못한다. 옛 이름 아래 worktree 에서 세션이 돌고 있으면 그 세션을
  끝낸 뒤 install · render 한다
- 옮긴 worktree 의 옛 경로에서 돈 세션 가운데 아직 가져오지 않은 기록은 세션 가져오기가 새 경로로 찾으므로 붙지 않는다
- 옛 버전 하네스가 고정된 worktree 의 스크립트는 옛 이름 디렉터리에 계속 쓴다. 다음 install · render 가 그것을 합친다
- 새 파일에 덧붙인 옛 사용 기록은 옛 자리에도 그대로 남는다 — 같은 줄이 두 곳에 있다. 옛 버전이 더는 쓰지 않으면 사람이 지운다
- 사용 기록을 덧붙이다 실패하거나 덧붙인 뒤 자리를 적기 전에 멈추면 다음 실행이 같은 줄을 다시 붙인다. 실패했으면 붙이다 만
  조각도 새 파일에 남는다. 줄을 잃지는 않는다
- 한 조각(1MiB)보다 긴 사용 기록 줄은 나눠 덧붙인다 — 그 사이 다른 기록기가 새 파일에 덧붙이면 그 줄이 갈라진다. 기록기
  (`script/usage-log.sh`)는 세부 항목을 80자로 잘라 쓰므로 그런 줄을 만들지 않는다
- 하드 링크를 만들 수 없는 곳에서는 가져오기 커서처럼 덧붙이지 않는 기록 파일을 옮기지 않는다. 옛 자리에 남은 파일은 사람이 옮긴다
- 옛 이름 디렉터리 가운데 `path` 가 이 루트가 아닌 것(지운 리포 · 다른 기기에서 옮겨 온 디렉터리)은 옮기지 않는다.
  `harness projects` 의 `legacy` 에 남는다
