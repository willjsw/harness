# 같은 이름의 프로젝트 등록 거부

한 기기의 설치 등록부에서 프로젝트 이름(`project.name`) 하나는 경로 하나만 가리킨다. `harness install` 은
같은 이름이 아직 쓰이는 다른 경로에 등록돼 있으면 설치를 거부하고, 옛 경로가 더는 그 프로젝트가 아니면
등록을 넘겨받는다. `harness doctor` 는 등록 상태를 보고한다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 등록 판정 (`register()` · `unregister()` · `cmd_install`) · doctor | `src/bin/harness` |
| UI doctor 문구 | `src/ui/lib/doctor.js` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/ui/lib/doctor.test.js` |
| 사람용 설명 | `README.md` |

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

- 등록부의 키 구조는 그대로다 — `~/.harness/<이름>/project.json` 에 `{"path": "<하네스 루트>"}` 한 줄
  (`HARNESS_HOME` 이 있으면 그 아래)
- 경로는 `main()` 이 `Path(args.target).resolve()` 로 정규화한 하네스 루트다. 같은 경로의 재설치는 지금처럼 통과한다
- 소스 리포 설치 분기도 같은 판정을 거친다
- 같은 이름이 다른 경로에 살아 있으면 `harness install` 이 종료 코드 2 로 멈춘다 (2절)
- 등록을 넘겨받을 때 바뀌는 것은 `project.json` 뿐이다. `~/.harness/<이름>/` 아래의 기록(실행 지표·사용 기록·
  가져오기 커서)은 그대로 남고, 새 경로의 프로젝트가 그 기록을 이어 쓴다
- 이름을 바꾼 리포를 다시 설치하면 그 경로를 가리키던 옛 이름의 `project.json` 이 지워진다. 옛 이름의 디렉터리와
  그 아래 기록은 남는다
- 이슈 worktree(`harness run --worktree`)는 install 을 돌지 않으므로 이 판정에 닿지 않는다

## 2. 등록 판정

### 2-1. 같은 이름의 기존 등록 가르기

`register()` 는 `~/.harness/<이름>/project.json` 을 읽어 아래 표로 가른다. `<이름>` 은 설치하는 리포의 `project.name`,
옛 경로는 그 파일의 `path` 다.

| 기존 등록 | 판정 |
|---|---|
| `project.json` 이 없다 · JSON 으로 읽히지 않는다 · `path` 가 없다 | 등록이 없다 — 쓴다 |
| 옛 경로가 현재 하네스 루트와 같다 | 재설치 — 쓴다 |
| 옛 경로에 `harness.toml` 이 없다 (경로 자체가 없는 경우 포함) | 낡은 등록 — 넘겨받는다 |
| 옛 경로의 `harness.toml` 이 읽히고 그 `project.name` 이 `<이름>` 과 다르다 | 낡은 등록 — 넘겨받는다 |
| 옛 경로의 `harness.toml` 이 읽히고 그 `project.name` 이 `<이름>` 과 같다 | 아직 쓰는 중 — 거부한다 |
| 옛 경로의 `harness.toml` 이 있으나 읽지 못한다 (파일을 열 수 없다 · TOML 로 읽히지 않는다 · `project.name` 이 문자열로 없다) | 아직 쓰는 중으로 본다 — 거부한다 |

옛 경로의 설정은 판정에만 읽는다. 검증(`validate()`)을 돌리지 않고, 그 파일과 그 리포를 바꾸지 않는다.

### 2-2. 순서

1. `cmd_install` 은 어떤 파일도 바꾸기 전에 2-1 판정을 돌린다 — 소스 리포 분기에서는 옛 사본을 걷어내기 전에,
   일반 분기에서는 `.harness/` 를 지우기 전에
2. 거부면 안내문(2-3)을 표준 오류로 내고 종료 코드 2 로 끝난다. 대상 리포의 `.harness/` · 생성 파일과 등록부는
   그대로다. `main()` 이 설정이 없던 대상에 먼저 깐 기본 `harness.toml` 은 남는다 — 안내가 고치라고 하는 파일이다
3. 통과면 기존 순서대로 설치하고, `register()` 가 쓴다
   1. `unregister(target)` — 현재 하네스 루트를 가리키는 `project.json` 을 이름과 관계없이 지운다
   2. `~/.harness/<이름>/project.json` 을 쓴다
4. 넘겨받은 경우 표준 출력에 한 줄을 낸다

```
install: `<이름>` was registered to <옛 경로>, which no longer holds this project — registered here instead
```

### 2-3. 거부 안내문

영어로 `error:` · `-->` · `help:` 형식을 따른다.

아직 쓰는 중:

```
error: project name `<이름>` is already registered to another repository
  --> <옛 경로>

help: run `harness uninstall` in that repository, or change `project.name` in this repository's harness.toml
```

옛 설정을 읽지 못함:

```
error: project name `<이름>` is registered to a repository whose config could not be read
  --> <옛 경로>/harness.toml

help: run `harness uninstall` in that repository, or change `project.name` in this repository's harness.toml
```

`harness uninstall` 은 설정을 읽지 않으므로 옛 설정이 깨져 있어도 그 리포에서 돈다.

## 3. `harness doctor`

`tools and connections` 절과 `git` 절 사이에 `registry` 절을 둔다. 판정은 `~/.harness/<이름>/project.json` 의 `path` 와
현재 하네스 루트의 비교다. 등록부를 바꾸지 않는다.

| 상태 | 줄 |
|---|---|
| `path` 가 현재 하네스 루트와 같다 | `ok` ``registered as `<이름>` `` |
| `path` 가 다른 경로이고, 두 경로의 git 공통 디렉터리가 같고 리포 안의 위치가 같다 — 같은 리포의 worktree | `ok` ``registered as `<이름>` `` |
| `path` 가 다른 경로다 (위 행에 해당하지 않는다) | `warn` `` `<이름>` is registered to another path `` — `<그 경로>` |
| `project.json` 이 없다 · 읽히지 않는다 · `path` 가 없다 | `warn` `this repository is not registered` — `` run `harness install` to list it in the UI `` |

- git 공통 디렉터리는 각 경로에서 `git rev-parse --git-common-dir` 을 돌려 그 경로 기준 절대 경로로 푼 값이다
- 리포 안의 위치는 각 경로의 `git rev-parse --show-prefix` 다. 모노레포에서 같은 리포의 다른 서브프로젝트를 같은 리포의 worktree 로 보지 않는다
- 어느 쪽 경로에서든 git 실행이 실패하거나 값을 구하지 못하면 다른 경로 `warn` 이다
- 2절의 등록 판정에는 이 규칙이 없다 — install 은 worktree 에서 돌지 않는다

`warn` 은 두 가지뿐이다. 이 절은 `FAIL` 을 내지 않는다.

## 4. UI Doctor 문구 — `src/ui/lib/doctor.js`

- `SECTIONS` 에 `registry: "등록"` 을 더한다
- `explain()` 이 3절의 두 `warn` 줄을 한국어 항목으로 옮긴다

| 줄 | 항목에 담는 것 | 조치 |
|---|---|---|
| `` `<이름>` is registered to another path `` | 이 이름이 다른 경로(detail)에 등록돼 UI 와 실행 기록이 그쪽을 가리킨다는 것. 그 경로가 더는 이 프로젝트가 아니면 여기서 다시 설치해 등록을 넘겨받고, 아직 쓰는 클론이면 그쪽에서 `harness uninstall` 하거나 `project.name` 을 바꾼다는 것 | `cmd`: `harness install` |
| `this repository is not registered` | UI 프로젝트 목록에 나오지 않는다는 것 | `cmd`: `harness install` |

## 5. README

| 절 | 적는 사실 |
|---|---|
| "시작하기" 의 `install` 설명 | 한 기기에 같은 리포는 하나만 설치한다. 같은 `project.name` 이 아직 쓰이는 다른 경로에 등록돼 있으면 `install` 이 거부한다 — 다른 클론에서 `harness uninstall` 하거나 `project.name` 을 바꾼다. 옛 경로에 그 프로젝트가 없으면(리포를 옮겼다) 등록을 넘겨받고, `~/.harness/<이름>/` 아래 기록은 그대로 이어진다. 같은 리포에서 여러 작업을 나란히 하려면 `harness run --worktree` 로 이슈별 worktree 를 쓴다 |
| "UI" | 등록부의 프로젝트 이름 하나는 경로 하나를 가리킨다. 같은 리포의 병렬 작업은 두 번째 클론이 아니라 `harness run --worktree` 다 |

## 6. 회귀 테스트

등록부는 `render-test.sh` 가 이미 두는 `HARNESS_HOME`(테스트 작업 디렉터리 아래)을 쓴다.

### 6-1. `render-test.sh` — 새 `UT-62` 블록

두 리포 A · B 는 같은 `project.name` 으로 `harness install` 한다(각자 `git init`).

| 케이스 | 확인하는 것 |
|---|---|
| 다른 경로의 같은 이름 | A 설치 뒤 B 설치가 종료 코드 2. 표준 오류에 `error:` · A 의 경로 · `harness uninstall` · `project.name` 이 있다. `project.json` 의 `path` 는 A 그대로, B 에 `.harness/` 와 `.ai/AI_AGENT.md` 가 없다 |
| 같은 경로 재설치 | A 를 다시 설치하면 종료 코드 0, `path` 는 A |
| 이름을 바꾼 두 번째 클론 | B 의 `project.name` 을 바꾸면 설치가 통과하고 두 이름이 각자의 경로를 가리킨다 |
| 옛 경로에 설정이 없다 | A 의 `harness.toml` 을 지우면 B 설치가 통과하고 `path` 가 B, 표준 출력에 `which no longer holds this project`. 설치 전에 `~/.harness/<이름>/` 아래 둔 표지 파일이 남아 있다 |
| 옛 경로가 없다 | A 디렉터리를 지우면 B 설치가 통과하고 `path` 가 B |
| 옛 경로의 이름이 다르다 | A 의 `project.name` 을 설정 파일에서만 바꾸면(재설치 없이) B 설치가 통과하고 `path` 가 B |
| 옛 설정을 읽지 못한다 | A 의 `harness.toml` 을 TOML 로 읽히지 않게 만들면 B 설치가 종료 코드 2, 표준 오류에 `could not be read` 와 A 의 설정 경로. `path` 는 A |
| 경로가 없는 등록 | `project.json` 이 `{}` 이면 B 설치가 통과하고 `path` 가 B |
| 이름 변경 뒤 재설치 | A 의 이름을 바꾸고 A 를 다시 설치하면 옛 이름의 `project.json` 이 없고, 새 이름의 `path` 가 A |
| 소스 리포 | 소스 트리 복제본 두 개를 같은 이름으로 설치하면 두 번째가 종료 코드 2 이고 옛 사본 걷어내기·렌더가 일어나지 않는다 |
| doctor | 등록된 리포에서 `registry` 절에 `ok` `registered as`. 등록이 다른 경로를 가리키는 리포에서 `warn` 과 그 경로, 등록이 없는 리포에서 `warn` `this repository is not registered`. 어느 쪽도 `FAIL` 줄이 아니다 |
| doctor — worktree | 등록된 리포에 `git worktree add` 로 만든 linked worktree 에서 doctor 를 돌리면 `registry` 절이 `ok` 이고 `warn` 줄이 없다. 같은 리포의 다른 서브디렉터리에 같은 이름으로 둔 하네스 루트에서는 `warn` 이다 |

터미널 출력의 한글 검사는 이 블록의 출력에도 적용한다.

### 6-2. 기존 케이스

같은 `project.name` 으로 여러 리포를 설치해 둔 채 다시 설치하는 기존 케이스는, 리포마다 다른 이름을 주거나 앞 리포를
지운 뒤 설치하도록 고친다. 케이스가 검증하는 내용은 바꾸지 않는다.

### 6-3. `doctor.test.js`

- `explain()` 이 `` `demo` is registered to another path `` 줄을 제목·본문이 원문과 다른 항목으로 옮기고, 본문에 detail 의
  경로가 들어가며 `cmd` 가 `harness install` 이다
- `this repository is not registered` 줄의 `cmd` 가 `harness install` 이다
- `SECTIONS.registry` 가 `"등록"` 이다

## 7. 보호 문서에 반영할 것

사람이 지시한 턴에 반영한다.

| 문서 · 위치 | 반영할 사실 |
|---|---|
| `.ai/project/architecture.md` "구성 요소" 의 기기 단위 상태 | 설치 등록부는 프로젝트 이름 하나에 경로 하나다. `install` 이 아직 쓰이는 다른 경로의 같은 이름을 거부한다 |

## 8. 한계

- 등록을 넘겨받아도 `~/.harness/<이름>/` 아래 옛 기록을 치우지 않는다. 옮긴 리포가 아니라 이름만 같은 다른 프로젝트가
  넘겨받으면 그 기록이 섞인다
- 등록이 지워진 이름의 디렉터리에 기록이 남아 있으면 UI 목록에 "재설치 필요" 로 뜬다
