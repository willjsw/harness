# 이슈별 worktree 에서 절차 실행

`harness run <절차> <이슈> --worktree` 가 이슈마다 격리된 작업 트리(git worktree)를 만들어 그 안에서
오케스트레이터를 띄운다. 같은 리포에서 여러 이슈의 절차를 동시에 돌릴 수 있다.

기준 코드는 #64(`docs/spec/64-modularize-cli-review-scripts.md`)의 변경이 들어간 통합 브랜치다.
세션 가져오기 함수(`import_claude` · `import_codex` · `metrics_import`)가 어느 파일에 있든 이 명세는 함수 단위로 적는다.

정본 위치:

| 대상 | 정본 |
|---|---|
| CLI (`cmd_run` · `cmd_doctor` · `validate()` · `derive()` · 세션 가져오기) | `src/bin/harness` 와 그 옆의 지표 모듈 |
| 기본 설정 | `src/templates/harness.toml` |
| 지표 기록기 | `src/templates/managed/script/metric.py` |
| 리뷰 등록·집계 | `src/templates/managed/script/post-review.sh` |
| 되감기 | `src/templates/managed/script/rollback-work.sh` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/templates/managed/script/test-review-loop.sh` · `test-rollback-work.sh` |
| UI 설정 도움말 | `src/ui/lib/help.js` |

이 리포의 `script/` 아래 같은 이름의 파일은 거기서 설치된 사본이다.

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

- **`--worktree` 가 없으면 `harness run` 은 지금과 같다.** 하네스 루트로 옮겨 가 그 자리에서 오케스트레이터를 띄운다.
  run 스팬의 속성도 같다
- 절차 문서의 중단 조건("작업 트리에 내가 만들지 않은 미커밋 변경이 있다")은 바뀌지 않는다. `--worktree` 로 띄운
  절차는 그 worktree 의 `git status` 를 본다
- 구현자 계약("브랜치를 통합 브랜치에서 만든다")은 바뀌지 않는다. worktree 는 원격 통합 브랜치에서 분리된 HEAD 로 시작한다
- 반복 지적 이력의 위치가 git 공통 디렉터리로 옮겨 간다 (7절). 파일 이름과 형식은 그대로다
- 설정에 `[worktree]` 절이 새로 생긴다 (2절). 생성 파일은 늘지 않는다 — `plan()` 에 등록할 것이 없다

## 2. 설정 — `[worktree]`

```toml
# 이슈별 작업 트리 (`harness run <절차> <이슈> --worktree`)
#   dir      worktree 를 만드는 디렉터리. 리포 밖이어야 한다. 이름은 이슈 번호다(<dir>/<번호>)
#   include  새 worktree 에 하네스 루트에서 복사할 비추적 파일·디렉터리. git 이 무시하는 경로만 복사한다
[worktree]
dir = "$HOME/.harness/{project}/worktrees"
include = [".claude/settings.local.json"]
```

| 키 | 기본값 | 규칙 |
|---|---|---|
| `dir` | `"$HOME/.harness/{project}/worktrees"` | 공백만이 아닌 한 줄 문자열. `{project}` 는 `project.name` 으로 바뀌고, `~` 와 환경 변수(`$HOME`)는 쓰는 시점에 확장된다 — `[metrics].dir` · `[usage].log_path` 와 같은 해석이다 |
| `include` | `[".claude/settings.local.json"]` | 문자열 배열. 항목마다 하네스 루트 기준 상대 경로다 |

- 절에 정의되지 않은 키가 있으면 render 를 거부한다: `error: unknown key(s) in [worktree]: <키> ... help: the keys are dir, include`
- `include` 항목은 `/` 로 시작하지 않고, `..` 경로 조각이 없고, 공백과 glob 문자(`*` `?` `[`)가 없고, 줄바꿈이 없다.
  어기면 `error: worktree.include[<번호>] must be a path relative to the harness root (got <값>)` 로 거부한다
- 켜고 끄는 키는 없다. 켜는 것은 명령줄의 `--worktree` 하나다
- `[worktree]` 절이 없는 옛 설정은 `derive()` 가 기본값을 채워 그대로 돈다. 이 리포 루트의 `harness.toml` 도 절 없이 기본값으로 돈다
- 확장한 `dir` 이 절대 경로가 아니거나 리포 작업 트리 안(`git rev-parse --show-toplevel` 아래)이면 `harness run --worktree` 가
  아무것도 만들지 않고 종료 코드 2 로 거부한다 — 확장이 실행 환경에 달려 있어 render 가 아니라 실행 시점에 본다

새 설정 키를 둘 곳의 나머지:

- README 의 "`harness.toml` 이 정하는 것" 표에 `worktree.dir` · `include` 행 — 생성 파일은 없고 `harness run --worktree` · `doctor` · 세션 가져오기가 읽는다
- `src/ui/lib/help.js` 에 `worktree.dir` · `worktree.include` 도움말 한 줄씩

## 3. `harness run <절차> <이슈> --worktree`

### 3-1. 인자

- 명령줄 플래그 `--worktree`(값 없음). 도움말: `run: start the workflow in a worktree of its own for the issue`
- `COMMANDS` 표의 `run` 사용법은 `<workflow> <issue> [--worktree]`, README 의 명령 표도 같다
- `--worktree` 는 이슈 인자가 숫자(`^[0-9]{1,10}$`)일 때만 받는다. 아니면 아무것도 만들지 않고 종료 코드 2:
  `error: --worktree needs an issue number (got <값>)`. 이슈 번호를 받지 않는 절차(`retro` 등)는 이 플래그를 쓸 수 없다
- 하네스 루트가 git 리포 안이 아니면 종료 코드 2 로 거부한다

### 3-2. 경로

| 이름 | 값 |
|---|---|
| worktree 이름 | 이슈 번호 |
| worktree 경로 | `<확장한 dir>/<번호>` |
| 하네스 루트의 리포 내 위치 | `git rev-parse --show-prefix` (리포 루트가 하네스 루트면 빈 값) |
| 실행 디렉터리 | `<worktree 경로>/<리포 내 위치>` — 오케스트레이터를 여기서 띄운다. 모노레포에서도 그 서브프로젝트 자리다 |

### 3-3. 순서

1. 인자·설정·경로를 확인한다 (3-1, 2절의 실행 시점 검사)
2. worktree 경로의 상태를 가른다 (3-4). 새로 만들 때만 3·4 를 한다
3. `git fetch origin <branches.base>` 뒤 `git worktree add --detach <worktree 경로> origin/<branches.base>`.
   `<dir>` 이 없으면 만든다. fetch 나 add 가 실패하면 git 의 출력을 그대로 보이고 종료 코드 2 — 오케스트레이터를 띄우지 않는다
4. `include` 를 복사한다 (3-5)
5. `worktree: <경로> (new|reopened)` 를 출력하고 실행 디렉터리에서 오케스트레이터를 띄운다. 띄우는 명령·환경·대화형 실행은
   `--worktree` 없는 경우와 같다. run 스팬에 `worktree=<번호>` 속성을 더한다 (6-1)
6. 오케스트레이터가 끝나면(중단 신호 포함) 정리를 판정한다 (3-6)

`harness run` 의 종료 코드는 오케스트레이터의 종료 코드다. 정리 결과는 종료 코드를 바꾸지 않는다.
단 3-4 에서 멈추면 오케스트레이터를 띄우지 않고 그 표의 종료 코드로 끝난다.

`--dry-run` 과 함께면 아무것도 만들거나 가져오지 않고, worktree 경로·새로 만들지 여부·실행 디렉터리·띄울 명령을 출력한다.

### 3-4. 기존 경로 가르기

worktree 경로가 **이 리포의 worktree** 라는 것은 둘 다 성립한다는 뜻이다.

- `git -C <경로> rev-parse --show-toplevel` 이 그 경로 자신이다 (둘러싼 다른 리포를 잡지 않게)
- `git -C <경로> rev-parse --git-common-dir` 을 절대 경로로 풀어 실제 경로로 비교했을 때 하네스 루트의 것과 같다

| 경로 상태 | 동작 | 종료 코드 |
|---|---|---|
| 없다 | 새로 만든다. 없는 경로가 이 리포의 worktree 로 등록만 남아 있으면 먼저 `git worktree prune` 한다 | — |
| 빈 디렉터리 | 새로 만든다 | — |
| 이 리포의 worktree 이고 미커밋 변경이 없다 | 그것을 연다. fetch·리셋·복사를 하지 않는다 | — |
| 이 리포의 worktree 이고 미커밋 변경이 있다 | 오케스트레이터를 띄우지 않고 경로와 `git status --short` 출력을 보이고 멈춘다 | 1 |
| 그 밖(다른 리포의 worktree, git 트리가 아닌 비어 있지 않은 디렉터리, 파일) | 아무것도 바꾸지 않고 경로 충돌을 알린다 | 2 |

- 미커밋 변경 판정은 `git -C <경로> status --porcelain` 이 비어 있지 않은 것이다. git 이 무시하는 파일은 들지 않는다
- 미커밋 변경으로 멈출 때의 출력:
  `stop: worktree <경로> has uncommitted changes — nothing was launched` 와 status 줄들, 그리고
  `help: finish or discard them in that worktree, then rerun`
- 경로 충돌의 출력: `error: <경로> is not a worktree of this repository` 와
  `help: another checkout may use the same project name — set worktree.dir or move that directory`

### 3-5. `include` 복사

새로 만든 worktree 에만 복사한다. 항목마다 아래 순서로 판정한다.

| 순서 | 조건 | 동작 |
|---|---|---|
| 1 | 하네스 루트에 그 경로가 없다 | 건너뛴다. 출력하지 않는다 |
| 2 | worktree 에서 그 경로가 git 추적 대상이다 | 건너뛴다 — checkout 이 이미 갖고 있다 |
| 3 | worktree 에서 그 경로가 git 이 무시하는 경로가 아니다 (`git check-ignore -q` 실패) | 복사하지 않고 `warn: <경로> is not ignored by git — not copied` |
| 4 | 그 밖 | `<하네스 루트>/<경로>` 를 `<실행 디렉터리>/<경로>` 로 복사한다. 디렉터리는 통째로, 심볼릭 링크는 링크로, 권한 비트를 유지한다 |

- 무시되지 않는 파일을 복사하지 않으므로 복사한 파일은 `git status` 에 잡히지 않는다. 정리 판정(3-6)이 복사한 파일
  때문에 worktree 를 남기는 일이 없고, 에이전트가 그 파일을 커밋에 끌어들이지 않는다
- 복사한 경로를 출력하지 않는다. 파일 내용은 어디에도 옮겨 적지 않는다

### 3-6. 정리 판정

오케스트레이터가 끝난 뒤 worktree 를 본다. 새로 만든 것과 다시 연 것이 같다.

| 조건 | 동작 |
|---|---|
| 미커밋 변경이 있다 | 남기고 `kept worktree <경로> — uncommitted changes` |
| 미push 커밋이 있다 | 남기고 `kept worktree <경로> — unpushed commits` |
| 둘 다 없다 | `git worktree remove <경로>`(강제 없이). 성공하면 `removed worktree <경로>` |

- 미push 커밋 판정은 `git -C <경로> rev-list --count HEAD --not --remotes` 가 1 이상인 것이다
- 제거가 실패하면 남기고 `warn: could not remove worktree <경로>` 와 git 의 출력을 보인다
- 제거는 worktree 만 없앤다. 그 안에서 만든 로컬 브랜치는 리포에 남는다
- 판정 함수(미커밋 변경·미push 커밋)는 3-4 · 3-6 · 5절이 함께 쓰는 하나다

## 4. 가드와 훅

- 대상 리포의 하네스 파일(`.harness/` 고정 사본 · `script/` · `.claude/` · `.codex/`)은 커밋되어 있으므로 worktree 의 checkout 에 있다.
  worktree 안의 스크립트·가드·훅은 worktree 의 사본으로 돈다
- git 훅: `core.hooksPath` 는 리포 설정이라 worktree 가 공유하고, 상대 경로(`script/githooks`)는 그 worktree 의 최상위 기준으로 풀린다
- 명령 가드: `.claude/settings.json` 의 훅 명령은 `$CLAUDE_PROJECT_DIR/script/hooks/bash-guard.sh` 이고, 오케스트레이터가 실행 디렉터리에서
  뜨므로 worktree 의 가드가 worktree 의 `script/harness.env` 로 판정한다
- 둘은 회귀 테스트로 확인한다 (9-1)

## 5. `harness doctor`

`git` 절에 남아 있는 worktree 를 보고한다. worktree 디렉터리의 gitignore 여부는 보지 않는다 — 리포 밖이다.

- 대상: `git worktree list --porcelain` 의 항목 중 경로가 `<확장한 dir>/<이름>` 인 것 (이 리포의 것만)
- 항목마다 `warn` 한 줄: `worktree <이름>` 과 상태

| 상태 | 표기 |
|---|---|
| 미커밋 변경이 있다 | `uncommitted changes at <경로>` |
| 미커밋 변경은 없고 미push 커밋이 있다 | `unpushed commits at <경로>` |
| 둘 다 없다 | `clean at <경로> — rerun its workflow or remove it with \`git worktree remove\`` |
| 경로가 없다 | `missing — run \`git worktree prune\`` |

- 남은 것이 없으면 `ok` 한 줄: `no worktrees left`
- 하네스 루트가 git 리포 안이 아니면 이 항목을 보지 않는다

## 6. 실행 지표

### 6-1. run 스팬 속성

- `script/metric.py` 의 `ATTR_KEYS` 에 `worktree` 를 더한다. 값은 이슈 번호와 같은 모양(`^[0-9]{1,10}$`)만 받는다 — `issue` 와 같은 검사식
- `harness run --worktree` 의 run 스팬 시작 속성에 `worktree=<번호>` 를 넣는다. `--worktree` 가 없으면 넣지 않는다
- 스팬에 worktree 경로·`dir` 값을 남기지 않는다. 경로는 가져오기가 설정에서 다시 계산한다 (6-2)

### 6-2. 세션 가져오기

가져오기는 스팬을 먼저 읽고, 가져오기 창 안의 run 스팬에서 `worktree` 속성 값(이름)을 모은다. CLI 는 확장한
`worktree.dir` 과 하네스 루트의 리포 내 위치를 가져오기에 인자로 넘긴다. 이름마다 실행 디렉터리를
`<dir>/<이름>/<리포 내 위치>` 로 계산하고, 그 경로와 실제 경로로 푼 형태를 둘 다 쓴다 — 하네스 루트를 다루는 방식과 같다.

| 벤더 | 찾는 곳 |
|---|---|
| Claude Code | 하네스 루트의 프로젝트 디렉터리에 더해, 이름마다 실행 디렉터리를 같은 규칙(영숫자 밖 문자를 `-` 로)으로 바꾼 프로젝트 디렉터리 |
| Codex | `session_meta` 의 `cwd` 가 하네스 루트이거나 그 아래면 하네스 루트의 기록, 어느 실행 디렉터리이거나 그 아래면 그 이름의 기록 |

가져온 기록마다 출처(하네스 루트 또는 worktree 이름)를 붙이고, 붙일 실행을 이렇게 고른다.

| 출처 | 후보 run | 붙이는 곳 |
|---|---|---|
| worktree `<이름>` | 같은 벤더, `worktree` 속성이 `<이름>`, 그 시각에 돌던 것 | 후보가 하나면 그 실행, 아니면 unattributed |
| 하네스 루트 | 같은 벤더, `worktree` 속성이 없는, 그 시각에 돌던 것 | 후보가 하나면 그 실행, 아니면 unattributed |

- "그 시각에 돌던" 의 창(시작 시각부터 끝 시각 + 60초, 끝 기록이 없으면 지금까지)은 그대로다
- 서로 다른 이슈의 worktree 에서 같은 벤더로 동시에 돈 실행은 각자의 기록을 받는다. worktree 실행과 하네스 루트 실행이 동시에 돌아도 서로의 후보가 되지 않는다
- Codex 커서의 "다른 프로젝트" 표시는 `cwd` 가 하네스 루트와 모든 실행 디렉터리 어디에도 맞지 않을 때만 붙는다. 커서에는 출처 이름을 함께 둔다
- 가져온 스팬의 속성과 이름 규칙, 메시지 본문을 저장하지 않는 규칙은 그대로다

## 7. 반복 지적 이력 — `post-review.sh`

- 이력 디렉터리를 `$(git rev-parse --git-common-dir)/work-loop` 로 옮긴다. 결과를 절대 경로로 풀어 쓴다 — 모노레포에서 스크립트의
  작업 디렉터리가 리포 루트가 아니어도 같은 자리를 가리킨다
- 같은 리포의 모든 worktree 와 원래 작업 트리가 한 이력을 공유한다. 파일 이름(`review-findings-<리뷰 요청 번호>.tsv`)과
  첫 줄 `#format 1`, 연속 회차 판정은 그대로다
- 원래 작업 트리에서는 git 디렉터리와 공통 디렉터리가 같으므로 이미 쌓인 이력이 그대로 읽힌다
- 스크립트 머리글의 위치 서술을 `<git-common-dir>/work-loop/` 로 바꾼다

## 8. 되감기 — `rollback-work.sh`

다른 worktree 가 체크아웃한 로컬 브랜치는 `git branch -D` 가 실패한다. 되감기는 그 브랜치를 지우지 않고 남긴다.

- `git worktree list --porcelain` 으로 브랜치마다 체크아웃한 worktree 경로를 모은다. 현재 작업 트리의 브랜치(`current`)는 지금처럼 따로 다룬다
- 보이는 단계: `local branch <브랜치>   ** checked out in worktree <경로> — will not be removed **`
- 되감는 단계: `kept local branch <브랜치> — it is checked out in worktree <경로>. remove that worktree and rerun to remove it`.
  실패로 세지 않는다(종료 코드에 닿지 않는다)
- 되감기는 worktree 를 지우지 않는다. 그 안의 미커밋 변경과 미push 커밋이 사라질 수 있다
- 되감기 대상이 그 브랜치 하나뿐이어도 "되감을 것이 없음" 판정은 지금처럼 로컬 브랜치 건수로 한다

## 9. 회귀 테스트

테스트는 `HOME` 을 바꾸지 않는다. `worktree.dir` 은 `harness set` 으로 테스트 작업 디렉터리 아래로 둔다. 원격은 로컬 bare 리포,
오케스트레이터는 PATH 앞에 둔 페이크 실행 파일이다 — 불린 디렉터리·인자를 기록하고, 케이스에 따라 파일을 고치거나 커밋한 뒤 정해진 코드로 끝난다.

### 9-1. `render-test.sh`

| 케이스 | 확인하는 것 |
|---|---|
| 새 worktree | 페이크가 `<dir>/<번호>` 에서 불리고, 그 HEAD 가 분리된 `origin/<base>` 이다. 변경 없이 끝나면 worktree 가 제거되고 `git worktree list` 에 없다 |
| 플래그 없음 | `--worktree` 없이 돌리면 페이크가 하네스 루트에서 불리고 worktree 가 생기지 않는다 |
| 미커밋 변경으로 남김 | 페이크가 추적 파일을 고치고 끝나면 worktree 가 남고 `kept worktree <경로> — uncommitted changes`, 종료 코드는 페이크의 것 |
| 미push 커밋으로 남김 | 페이크가 커밋하고 끝나면 worktree 가 남고 `unpushed commits` |
| 깨끗한 worktree 다시 열기 | 남아 있는 깨끗한 worktree 가 있으면 새로 만들지 않고(HEAD 그대로) 그 안에서 페이크가 불린다 |
| 미커밋 변경이 있는 worktree | 페이크가 불리지 않고 종료 코드 1, 출력에 경로와 status 줄 |
| 다른 리포의 worktree | `<dir>/<번호>` 가 다른 리포의 worktree 면 페이크가 불리지 않고 종료 코드 2, 경로 충돌 메시지. 그 디렉터리는 바뀌지 않는다 |
| git 트리가 아닌 디렉터리 | 비어 있지 않은 일반 디렉터리면 종료 코드 2. 빈 디렉터리면 새로 만든다 |
| 숫자가 아닌 이슈 | `harness run retro x --worktree` 가 종료 코드 2, 아무것도 만들지 않는다 |
| 리포 안의 `dir` | `worktree.dir` 이 리포 안이면 종료 코드 2 |
| fetch 실패 | 원격이 없으면 종료 코드 2, 페이크가 불리지 않는다 |
| `--dry-run` | worktree 가 생기지 않고 경로와 명령을 출력한다 |
| 모노레포 | 하네스 루트가 서브디렉터리면 페이크가 `<worktree>/<리포 내 위치>` 에서 불리고 `include` 가 그 아래로 복사된다 |
| `include` 복사 | 무시되는 파일은 복사되고, 무시되지 않는 비추적 파일은 복사되지 않고 경고, 없는 경로는 조용히 건너뛰고, 추적 경로는 덮어쓰지 않는다. 복사 뒤 `git status --porcelain` 이 비어 있다 |
| 설정 검사 | `[worktree]` 의 정의되지 않은 키, 절대 경로·`..`·공백·glob 이 든 `include` 항목, 빈 `dir` 을 render 가 거부한다. 절이 없는 설정은 기본값으로 렌더된다 |
| run 스팬 속성 | `--worktree` 로 돈 run 스팬에 `worktree=<번호>` 가 있고, 플래그 없이는 없다. 스팬 파일에 worktree 경로 문자열이 없다 |
| 세션 가져오기 — 병렬 | 같은 벤더로 겹쳐 돈 worktree 두 실행(서로 다른 번호)에 대해 각 worktree 실행 디렉터리의 Claude 기록과 `cwd` 가 그 경로인 Codex 기록이 각자의 실행에 붙고 unattributed 가 0 이다 |
| 세션 가져오기 — 하네스 루트 | worktree 실행과 겹쳐 돈 하네스 루트 실행이 하나면 하네스 루트의 기록이 그 실행에 붙는다 |
| 세션 가져오기 — 제거된 worktree | worktree 가 제거된 뒤에 가져와도 기록이 그 실행에 붙는다 |
| doctor | 남은 worktree 가 상태(미커밋 변경·미push 커밋·깨끗함·경로 없음)와 함께 `warn` 으로 나오고, 없으면 `no worktrees left`. gitignore 항목이 없다 |
| worktree 안의 git 훅 | 설치한 리포의 worktree 에서 형식이 틀린 커밋 메시지를 `commit-msg` 훅이 막는다 |
| worktree 안의 명령 가드 | worktree 의 `.claude/settings.json` 이 가리키는 가드를 `CLAUDE_PROJECT_DIR=<worktree>` 로 부르면 보호 브랜치 push 를 막는다 |

### 9-2. `test-review-loop.sh`

| 케이스 | 확인하는 것 |
|---|---|
| worktree 에서 이력 공유 | 같은 리뷰 요청의 회차를 원래 작업 트리와 linked worktree 에서 번갈아 등록하면 이력이 `<공통 디렉터리>/work-loop/review-findings-<번호>.tsv` 한 파일에 쌓이고 연속 회차가 이어서 세어진다 |

기존 케이스의 이력 경로 기대값(`$work/.git/work-loop/…`)은 원래 작업 트리라 그대로다.

### 9-3. `test-rollback-work.sh`

| 케이스 | 확인하는 것 |
|---|---|
| 다른 worktree 가 체크아웃한 브랜치 | 그 브랜치는 남고 `checked out in worktree` 가 보이는 단계와 되감는 단계 모두에 나오며, 다른 로컬 브랜치는 지워지고 종료 코드 0. worktree 는 그대로 있다 |

회귀 테스트 전체(`script/run-lint-test.sh`)가 통과한다.

## 10. 보호 문서에 반영할 것

### 10-1. `.ai/project/architecture.md`

| 위치 | 반영할 사실 |
|---|---|
| "데이터 흐름" 의 절차 실행 | `harness run --worktree` 는 원격 통합 브랜치에서 이슈별 worktree 를 만들고 그 안에서 오케스트레이터를 띄운 뒤, 끝나면 미커밋 변경·미push 커밋이 없을 때 제거한다 |
| "데이터 흐름" 의 실행 지표 | 세션 가져오기는 run 스팬의 worktree 이름과 설정의 `worktree.dir` 로 worktree 실행 디렉터리를 다시 계산해 기록을 붙인다 |
| "신뢰 경계" | `worktree.include` 는 git 이 무시하는 로컬 파일만 worktree 로 복사하고 그 경로·내용을 출력하지 않는다. 기존 worktree 는 git 공통 디렉터리가 같을 때만 연다 |
| "구성 요소" 의 기기 단위 상태 | 홈 아래 `.harness/<프로젝트>/worktrees/` — 이슈별 worktree (기본 위치) |

### 10-2. `.ai/project/glossary.md`

| 위치 | 반영할 사실 |
|---|---|
| "용어" 표 | `이슈 worktree` — `harness run --worktree` 가 이슈 번호 이름으로 `worktree.dir` 아래에 만드는 git worktree |

### 10-3. `.ai/project/scope.md`

| 위치 | 반영할 사실 |
|---|---|
| "할 수 있는 일" 의 `run` 항목 | 이슈별 worktree 에서 절차를 돌려 같은 리포의 여러 이슈를 동시에 진행할 수 있다 |

## 11. 한계

- 포트·DB 같은 실행 자원은 나누지 않는다. 프로젝트가 `include` 로 복사하는 설정 파일이나 환경 변수로 다룬다
- 같은 이슈의 worktree 에서 두 실행이 동시에 도는 것을 막지 않는다. 그 두 실행의 세션 기록은 unattributed 로 간다
- 같은 `project.name` 을 쓰는 다른 리포는 기본 `dir` 을 공유한다. 이 명세는 그 리포의 worktree 에서 도는 것만 막는다(3-4).
  같은 이름의 프로젝트 등록 자체는 #79 가 다룬다
- 이슈 worktree 를 쓰려면 프로젝트의 고정 사본이 이 기능을 가진 버전이어야 한다. 옛 사본은 `--worktree` 를 모른다
- `harness uninstall` 은 남아 있는 worktree 를 지우지 않는다
