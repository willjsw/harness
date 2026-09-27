# #71 task

## T1 · feat: worktree 설정 절과 값 검증 추가

### 상위 Requirement

- relates to #71

### 작업 내용

`harness run --worktree` 가 읽을 `[worktree]` 설정 절(`dir` · `include`)을 기본 설정에 두고, render 가 값을 검증하게 한다.
생성 파일은 늘지 않는다 — `plan()` 에 등록할 것이 없다.

- 명세 2절(설정)의 절 본문·키 규칙·거부 메시지, 9-1 의 "설정 검사" 케이스
- 기본값: `dir = "$HOME/.harness/{project}/worktrees"`, `include = [".claude/settings.local.json"]`. 명세 2절의 머리 주석을 기본 설정에 그대로 둔다
- `validate()`: 정의되지 않은 키(`error: unknown key(s) in [worktree]: <키> ... help: the keys are dir, include`),
  공백만이거나 여러 줄인 `dir`, 규칙을 어긴 `include` 항목(`error: worktree.include[<번호>] must be a path relative to the harness root (got <값>)`)을 거부한다.
  `include` 항목 규칙은 `/` 로 시작하지 않음 · `..` 경로 조각 없음 · 공백·glob 문자(`*` `?` `[`)·줄바꿈 없음이다
- `derive()`: 절이 없는 설정에 기본값을 채운다. 이 리포 루트의 `harness.toml` 은 절 없이 기본값으로 돈다
- `dir` 의 `{project}` · `~` · 환경 변수 확장은 쓰는 시점에 한다 — `[metrics].dir` · `[usage].log_path` 와 같은 해석. 확장한 값의 절대 경로·리포 밖 검사는 T2 의 실행 시점 검사다
- README 의 "`harness.toml` 이 정하는 것" 표에 `worktree.dir` · `include` 행(읽는 곳: `harness run --worktree` · `doctor` · 세션 가져오기),
  `src/ui/lib/help.js` 에 `worktree.dir` · `worktree.include` 도움말 한 줄씩
- 건드릴 파일: `src/templates/harness.toml`, `src/bin/harness`(`validate()` · `derive()`), `README.md`, `src/ui/lib/help.js`, `src/test/render-test.sh`

### 완료 조건

- [ ] 기본 설정에 `[worktree]` 절과 명세 2절의 두 기본값·머리 주석이 있다
- [ ] `[worktree]` 에 정의되지 않은 키가 있으면 render 가 명세 2절의 메시지로 거부한다
- [ ] 절대 경로·`..`·공백·glob 문자가 든 `include` 항목과 빈 `dir` 을 render 가 거부한다
- [ ] `[worktree]` 절이 없는 설정이 기본값으로 렌더되고, 이 리포의 `harness check` 가 통과한다
- [ ] README 표와 `help.js` 에 두 키가 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/71-issue-worktree-run` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 정의되지 않은 키 거부 | `[worktree]` 에 `enabled = true` | render 실패, `unknown key(s) in [worktree]: enabled` |
| UT-02 | `include` 항목 거부 | `/etc/x` · `../x` · `a b` · `*.json` 항목 각각 | render 실패, `worktree.include[<번호>] must be a path relative to the harness root` |
| UT-03 | 빈 `dir` 거부 | `dir = "  "` | render 실패 |
| UT-04 | 절 없는 설정 | `[worktree]` 절을 지운 설정 | render 성공, 기본값이 채워진다 |

## T2 · feat: harness run --worktree 로 이슈별 worktree 생성·다시 열기·정리

### 상위 Requirement

- relates to #71

### 작업 내용

`harness run <절차> <이슈> --worktree` 가 원격 통합 브랜치에서 이슈 번호 이름의 worktree 를 만들거나 남아 있는 것을 열고,
그 안에서 오케스트레이터를 띄운 뒤 끝나면 정리를 판정하게 한다. `--worktree` 가 없으면 지금과 같다.

- 명세 3-1(인자) · 3-2(경로) · 3-3(순서, `include` 복사 단계 제외) · 3-4(기존 경로 가르기) · 3-6(정리 판정),
  9-1 의 "새 worktree" · "플래그 없음" · "미커밋 변경으로 남김" · "미push 커밋으로 남김" · "깨끗한 worktree 다시 열기" ·
  "미커밋 변경이 있는 worktree" · "다른 리포의 worktree" · "git 트리가 아닌 디렉터리" · "숫자가 아닌 이슈" · "리포 안의 `dir`" ·
  "fetch 실패" · "`--dry-run`" · "모노레포"(실행 디렉터리) 케이스
- 플래그 `--worktree`(값 없음). 도움말 `run: start the workflow in a worktree of its own for the issue`.
  `COMMANDS` 표와 README 명령 표의 `run` 사용법은 `<workflow> <issue> [--worktree]`
- 실행 시점 검사(아무것도 만들지 않고 종료 코드 2): 숫자가 아닌 이슈(`error: --worktree needs an issue number (got <값>)`),
  하네스 루트가 git 리포 밖, 확장한 `dir` 이 절대 경로가 아니거나 `git rev-parse --show-toplevel` 아래
- 경로: worktree 는 `<확장한 dir>/<번호>`, 실행 디렉터리는 `<worktree>/<git rev-parse --show-prefix>`
- 새로 만들 때: `git fetch origin <branches.base>` 뒤 `git worktree add --detach <경로> origin/<branches.base>`. `<dir>` 이 없으면 만든다.
  fetch·add 실패는 git 출력을 그대로 보이고 종료 코드 2
- 기존 경로 판정: 이 리포의 worktree 인지는 `git -C <경로> rev-parse --show-toplevel` 이 그 경로 자신이고, `--git-common-dir` 을
  절대·실제 경로로 푼 값이 하네스 루트의 것과 같은지로 본다. 상태별 동작·종료 코드·출력 문구는 명세 3-4 표와 그 아래 목록대로다.
  경로가 없는데 worktree 등록만 남아 있으면 먼저 `git worktree prune`
- 오케스트레이터 실행: `worktree: <경로> (new|reopened)` 를 출력하고 실행 디렉터리에서 띄운다. 명령·환경·대화형 실행은 플래그 없는 경우와 같다.
  `harness run` 의 종료 코드는 오케스트레이터의 것이고 정리 결과는 그것을 바꾸지 않는다. 중단 신호로 끝나도 정리를 판정한다
- 정리: 미커밋 변경(`git status --porcelain` 이 비어 있지 않음)·미push 커밋(`rev-list --count HEAD --not --remotes` ≥ 1)이 없으면
  `git worktree remove <경로>`(강제 없이). 남기거나 제거할 때의 출력은 명세 3-6 대로다
- 미커밋 변경·미push 커밋 판정은 함수 하나로 두고 3-4 · 3-6 이 함께 쓴다. T5 의 doctor 도 이 함수를 쓴다
- `--dry-run` 이면 아무것도 만들거나 가져오지 않고 worktree 경로·새로 만들지 여부·실행 디렉터리·띄울 명령을 출력한다
- 건드릴 파일: `src/bin/harness`(`COMMANDS` · 인자 파서 · `cmd_run`), `README.md`, `src/test/render-test.sh`

### 완료 조건

- [ ] 새 worktree 가 `<dir>/<번호>` 에 분리된 HEAD `origin/<base>` 로 만들어지고 페이크 오케스트레이터가 그 안에서 불린다
- [ ] 변경 없이 끝나면 worktree 가 제거되고 `git worktree list` 에 없다
- [ ] 미커밋 변경·미push 커밋이 남으면 worktree 가 남고 명세 3-6 의 `kept worktree` 문구가 나오며, 종료 코드는 페이크의 것이다
- [ ] 깨끗한 worktree 는 HEAD 를 바꾸지 않고 다시 열린다
- [ ] 미커밋 변경이 있는 worktree 는 페이크를 부르지 않고 종료 코드 1 과 경로·status 줄을 출력한다
- [ ] 다른 리포의 worktree, 비어 있지 않은 일반 디렉터리는 종료 코드 2 이고 그 디렉터리가 바뀌지 않는다. 빈 디렉터리는 새로 만든다
- [ ] 숫자가 아닌 이슈, 리포 안의 `dir`, fetch 실패가 종료 코드 2 이고 worktree 와 페이크 호출이 없다
- [ ] `--dry-run` 이 worktree 를 만들지 않고 경로와 명령을 출력한다
- [ ] 하네스 루트가 서브디렉터리면 페이크가 `<worktree>/<리포 내 위치>` 에서 불린다
- [ ] `--worktree` 없이 돌리면 페이크가 하네스 루트에서 불리고 worktree 가 생기지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/71-issue-worktree-run` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 새 worktree 생성과 제거 | 변경 없이 0 으로 끝나는 페이크, `harness run work 7 --worktree` | 페이크 cwd = `<dir>/7`, HEAD = `origin/<base>`(분리), 끝난 뒤 worktree 없음, 종료 코드 0 |
| UT-02 | 플래그 없음 | 같은 페이크, `harness run work 7` | 페이크 cwd = 하네스 루트, `<dir>/7` 없음 |
| UT-03 | 미커밋 변경으로 남김 | 추적 파일을 고치고 3 으로 끝나는 페이크 | worktree 남음, `kept worktree <경로> — uncommitted changes`, 종료 코드 3 |
| UT-04 | 미push 커밋으로 남김 | 커밋하고 끝나는 페이크 | worktree 남음, `unpushed commits` |
| UT-05 | 깨끗한 worktree 다시 열기 | UT-04 뒤 로컬 커밋을 원격에 올려 깨끗하게 만든 worktree | `(reopened)`, HEAD 그대로, 페이크 cwd = 그 worktree |
| UT-06 | 미커밋 변경이 있는 worktree | 추적 파일이 고쳐진 채 남은 worktree | 페이크 호출 없음, 종료 코드 1, 출력에 경로와 status 줄 |
| UT-07 | 다른 리포의 worktree | `<dir>/7` 이 다른 리포의 worktree | 페이크 호출 없음, 종료 코드 2, `is not a worktree of this repository`, 디렉터리 불변 |
| UT-08 | git 트리가 아닌 디렉터리 | 파일이 든 일반 디렉터리 / 빈 디렉터리 | 종료 코드 2 / 새로 만든다 |
| UT-09 | 숫자가 아닌 이슈 | `harness run retro x --worktree` | 종료 코드 2, `--worktree needs an issue number` |
| UT-10 | 리포 안의 `dir` | `worktree.dir` 을 리포 안 경로로 | 종료 코드 2, worktree 없음 |
| UT-11 | fetch 실패 | origin 원격이 없는 리포 | 종료 코드 2, 페이크 호출 없음 |
| UT-12 | `--dry-run` | `harness run work 7 --worktree --dry-run` | worktree 없음, 출력에 `<dir>/7` 과 띄울 명령 |
| UT-13 | 모노레포 실행 디렉터리 | 하네스 루트가 리포의 서브디렉터리 | 페이크 cwd = `<dir>/7/<리포 내 위치>` |

## T3 · feat: 새 worktree 에 로컬 파일 복사와 worktree 안의 가드·훅 확인

### 상위 Requirement

- relates to #71

### 작업 내용

새로 만든 worktree 에 `worktree.include` 의 로컬 파일(git 이 무시하는 경로만)을 하네스 루트에서 복사한다. 그리고 worktree 안에서
git 훅과 명령 가드가 그 worktree 의 사본으로 도는 것을 회귀 테스트로 확인한다.

- 명세 3-3 의 4단계 · 3-5(`include` 복사) · 4절(가드와 훅), 9-1 의 "`include` 복사" · "모노레포"(복사 위치) · "worktree 안의 git 훅" · "worktree 안의 명령 가드" 케이스
- 새로 만든 worktree 에만 복사한다. 다시 연 worktree 에는 복사하지 않는다
- 항목마다 명세 3-5 표의 순서로 판정한다: 하네스 루트에 없으면 조용히 건너뜀 → worktree 에서 추적 대상이면 건너뜀 →
  `git check-ignore -q` 가 실패하면 복사하지 않고 `warn: <경로> is not ignored by git — not copied` → 그 밖에는
  `<하네스 루트>/<경로>` 를 `<실행 디렉터리>/<경로>` 로 복사(디렉터리는 통째로, 심볼릭 링크는 링크로, 권한 비트 유지)
- 복사한 경로를 출력하지 않고, 파일 내용을 어디에도 옮겨 적지 않는다
- 훅은 `core.hooksPath`(상대 경로 `script/githooks`)가 worktree 최상위 기준으로 풀리는 것을, 가드는 `CLAUDE_PROJECT_DIR=<worktree>` 로
  부른 `script/hooks/bash-guard.sh` 가 worktree 의 `script/harness.env` 로 판정하는 것을 확인한다. 훅·가드 코드는 바꾸지 않는다
- 건드릴 파일: `src/bin/harness`(`cmd_run` 의 복사 단계), `src/test/render-test.sh`

### 완료 조건

- [ ] git 이 무시하는 `include` 경로가 새 worktree 의 실행 디렉터리 아래로 복사되고 권한 비트가 같다
- [ ] 무시되지 않는 비추적 경로는 복사되지 않고 경고가 나온다
- [ ] 하네스 루트에 없는 경로는 출력 없이 건너뛴다
- [ ] 추적 경로는 덮어쓰지 않는다
- [ ] 복사 뒤 worktree 의 `git status --porcelain` 이 비어 있다
- [ ] 다시 연 worktree 에는 복사가 일어나지 않는다
- [ ] 모노레포에서 `include` 가 `<worktree>/<리포 내 위치>` 아래로 복사된다
- [ ] 설치한 리포의 worktree 에서 형식이 틀린 커밋 메시지를 `commit-msg` 훅이 막는다
- [ ] worktree 의 가드를 `CLAUDE_PROJECT_DIR=<worktree>` 로 부르면 보호 브랜치 push 를 막는다
- [ ] `run` 의 출력에 복사한 경로가 나오지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/71-issue-worktree-run` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 무시되는 파일 복사 | 하네스 루트에 gitignore 된 `.claude/settings.local.json`(0600) | 새 worktree 에 같은 내용·권한으로 있다 |
| UT-02 | 무시되지 않는 파일 | `include` 에 무시되지 않는 비추적 파일 | 복사 안 됨, `is not ignored by git — not copied` |
| UT-03 | 없는 경로 | `include` 에 하네스 루트에 없는 경로 | 출력 없음, worktree 에 없음 |
| UT-04 | 추적 경로 | `include` 에 추적 파일, 하네스 루트에서 내용을 바꿔 둠 | worktree 의 파일은 checkout 내용 그대로 |
| UT-05 | 복사 뒤 상태 | UT-01 ~ UT-04 를 모은 설정 | worktree 의 `git status --porcelain` 비어 있음 |
| UT-06 | 다시 열 때 복사 안 함 | 남은 깨끗한 worktree 에서 복사 대상 파일을 지운 뒤 재실행 | 그 파일이 다시 생기지 않는다 |
| UT-07 | 모노레포 복사 위치 | 하네스 루트가 서브디렉터리 | `<dir>/<번호>/<리포 내 위치>/<경로>` 에 복사 |
| UT-08 | worktree 안의 git 훅 | 설치 리포의 worktree 에서 형식이 틀린 메시지로 커밋 | 커밋 거부 |
| UT-09 | worktree 안의 명령 가드 | `CLAUDE_PROJECT_DIR=<worktree>` 로 보호 브랜치 push 도구 호출 JSON 을 가드에 넣음 | 차단 |

## T4 · feat: run 스팬의 worktree 식별자와 세션 가져오기의 worktree 귀속

### 상위 Requirement

- relates to #71

### 작업 내용

`--worktree` 로 돈 run 스팬에 worktree 식별자(이슈 번호)만 남기고, 세션 가져오기가 그 식별자와 설정으로 worktree 실행 디렉터리를
다시 계산해 대화 기록을 그 실행에 붙이게 한다. 스팬에 경로를 남기지 않는다.

- 명세 6-1(run 스팬 속성) · 6-2(세션 가져오기), 9-1 의 "run 스팬 속성" · "세션 가져오기 — 병렬" · "세션 가져오기 — 하네스 루트" ·
  "세션 가져오기 — 제거된 worktree" 케이스
- `script/metric.py`: `ATTR_KEYS` 에 `worktree` 를 더하고, 값은 `issue` 와 같은 검사식(`^[0-9]{1,10}$`)으로만 받는다
- `cmd_run`: `--worktree` 일 때 run 스팬 시작 속성에 `worktree=<번호>` 를 넣는다. 플래그가 없으면 넣지 않는다
- `metrics_import`: 스팬을 먼저 읽고 가져오기 창 안의 run 스팬에서 `worktree` 값을 모은다. CLI 가 확장한 `worktree.dir` 과
  하네스 루트의 리포 내 위치(`git rev-parse --show-prefix`)를 인자로 넘기고, 이름마다 실행 디렉터리 `<dir>/<이름>/<리포 내 위치>`
  를 그 경로와 실제 경로로 푼 형태 둘 다로 쓴다
- `import_claude`: 하네스 루트의 프로젝트 디렉터리에 더해, 이름마다 실행 디렉터리를 같은 규칙(영숫자 밖 문자를 `-` 로)으로 바꾼 프로젝트 디렉터리를 읽는다
- `import_codex`: `session_meta` 의 `cwd` 가 하네스 루트 또는 그 아래면 하네스 루트의 기록, 어느 실행 디렉터리 또는 그 아래면 그 이름의 기록이다.
  "다른 프로젝트" 표시는 어디에도 맞지 않을 때만 붙고, 커서에 출처 이름을 함께 둔다
- 귀속: 기록마다 출처(하네스 루트 또는 worktree 이름)를 붙이고, worktree 출처는 `worktree` 속성이 같은 run, 하네스 루트 출처는
  `worktree` 속성이 없는 run 중에서 같은 벤더·같은 시각 창(시작부터 끝 + 60초, 끝 기록이 없으면 지금까지)의 후보가 하나일 때만 붙인다. 아니면 unattributed
- 가져온 스팬의 속성·이름 규칙과 메시지 본문을 저장하지 않는 규칙은 그대로다
- 건드릴 파일: `src/templates/managed/script/metric.py`, `src/bin/harness`(`cmd_run` · 가져오기에 인자를 넘기는 곳),
  세션 가져오기 함수가 있는 파일(`src/bin/harness_metrics.py`), `src/test/render-test.sh`, render 로 갱신되는 `script/metric.py`

### 완료 조건

- [ ] `--worktree` 로 돈 run 스팬에 `worktree=<번호>` 가 있고, 플래그 없이는 없다
- [ ] `metric.py` 가 숫자가 아닌 `worktree` 값을 버린다
- [ ] 스팬 파일에 worktree 경로·`worktree.dir` 문자열이 없다
- [ ] 같은 벤더로 겹쳐 돈 서로 다른 번호의 worktree 두 실행이 각자의 Claude·Codex 기록을 받고 unattributed 가 0 이다
- [ ] worktree 실행과 겹쳐 돈 하네스 루트 실행 하나가 하네스 루트의 기록을 받는다
- [ ] worktree 가 제거된 뒤에 가져와도 기록이 그 실행에 붙는다
- [ ] `cwd` 가 worktree 실행 디렉터리인 Codex 기록에 "다른 프로젝트" 표시가 붙지 않는다
- [ ] 기존 `harness metrics` · `harness run` 회귀 케이스가 같은 기대값으로 통과한다
- [ ] `src/bin/harness render` 뒤 `script/metric.py` 가 정본과 같고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/71-issue-worktree-run` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | run 스팬 속성 | 페이크로 `harness run work 7 --worktree` / 플래그 없이 | 전자의 run 스팬 attrs 에 `worktree=7`, 후자에는 없음 |
| UT-02 | 경로 비기록 | UT-01 뒤 스팬 파일 전체 | worktree 경로·`dir` 값 문자열 없음 |
| UT-03 | 속성 값 검사 | `metric.py` 에 `worktree=../x` 속성 | 그 속성이 버려진다 |
| UT-04 | 병렬 귀속 | 시각이 겹치는 `worktree=7` · `worktree=8` run 스팬, 각 실행 디렉터리의 Claude 기록과 `cwd` 가 그 경로인 Codex 기록 | 각 기록이 자기 run 의 트레이스에 붙고 unattributed 0 |
| UT-05 | 하네스 루트 귀속 | 겹치는 `worktree=7` run 과 속성 없는 run 하나, 하네스 루트의 기록 | 하네스 루트 기록이 속성 없는 run 에 붙는다 |
| UT-06 | 제거된 worktree | UT-04 의 입력에서 worktree 디렉터리를 지운 뒤 가져오기 | UT-04 와 같은 귀속 |
| UT-07 | Codex 다른 프로젝트 표시 | `cwd` 가 worktree 실행 디렉터리인 기록 / 무관한 경로인 기록 | 전자는 표시 없음, 후자는 표시 |

## T5 · feat: doctor 에 남아 있는 이슈 worktree 보고

### 상위 Requirement

- relates to #71

### 작업 내용

`harness doctor` 의 `git` 절에 `worktree.dir` 아래 남아 있는 이 리포의 worktree 를 상태와 함께 `warn` 으로 보고한다.
worktree 디렉터리의 gitignore 여부는 보지 않는다 — 리포 밖이다.

- 명세 5절, 9-1 의 "doctor" 케이스
- 대상: `git worktree list --porcelain` 의 항목 중 경로가 `<확장한 dir>/<이름>` 인 것
- 상태 판정은 T2 의 미커밋 변경·미push 커밋 판정 함수를 쓴다. 항목마다 `warn` 한 줄 `worktree <이름>` 과 명세 5절 표의 상태 표기
  (`uncommitted changes at <경로>` · `unpushed commits at <경로>` · `clean at <경로> — rerun its workflow or remove it with \`git worktree remove\`` ·
  `missing — run \`git worktree prune\``)
- 남은 것이 없으면 `ok` 한 줄 `no worktrees left`. 하네스 루트가 git 리포 밖이면 이 항목을 보지 않는다
- 건드릴 파일: `src/bin/harness`(`cmd_doctor`), `src/test/render-test.sh`

### 완료 조건

- [ ] 남은 worktree 가 미커밋 변경·미push 커밋·깨끗함·경로 없음 각각의 표기와 함께 `warn` 으로 나온다
- [ ] 남은 것이 없으면 `ok` `no worktrees left` 가 나온다
- [ ] `worktree.dir` 밖의 worktree 는 보고하지 않는다
- [ ] doctor 출력에 worktree 디렉터리의 gitignore 항목이 없다
- [ ] 하네스 루트가 git 리포 밖이면 이 항목이 나오지 않고 doctor 가 실패하지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/71-issue-worktree-run` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 상태별 보고 | `<dir>` 아래 미커밋 변경 · 미push 커밋 · 깨끗함 worktree 하나씩, 디렉터리를 지운 worktree 하나 | 네 줄의 `warn`, 각각 명세 5절 표기 |
| UT-02 | 남은 것 없음 | worktree 가 없는 리포 | `ok` `no worktrees left` |
| UT-03 | 범위 밖 worktree | `<dir>` 밖에 만든 worktree | 보고하지 않음 |
| UT-04 | git 리포 밖 | git 리포가 아닌 하네스 루트 | worktree 항목 없음, doctor 종료 코드가 이 항목 때문에 바뀌지 않음 |

## T6 · feat: 반복 지적 이력을 git 공통 디렉터리로 이동

### 상위 Requirement

- relates to #71

### 작업 내용

`post-review.sh` 의 반복 지적 이력 디렉터리를 `git rev-parse --git-dir` 기준에서 `--git-common-dir` 기준으로 옮겨, 같은 리포의
모든 worktree 와 원래 작업 트리가 이력 하나를 공유하게 한다. 원래 작업 트리에서는 두 값이 같아 이미 쌓인 이력이 그대로 읽힌다.

- 명세 7절, 9-2 의 "worktree 에서 이력 공유" 케이스
- 이력 디렉터리는 `$(git rev-parse --git-common-dir)/work-loop` 를 절대 경로로 푼 값이다 — 모노레포에서 작업 디렉터리가 리포 루트가 아니어도 같은 자리
- 파일 이름(`review-findings-<리뷰 요청 번호>.tsv`), 첫 줄 `#format 1`, 연속 회차 판정은 그대로다
- 스크립트 머리글의 위치 서술을 `<git-common-dir>/work-loop/` 로 바꾼다
- 기존 케이스의 이력 경로 기대값(`$work/.git/work-loop/…`)은 원래 작업 트리라 그대로 둔다
- 건드릴 파일: `src/templates/managed/script/post-review.sh`, `src/templates/managed/script/test-review-loop.sh`, render 로 갱신되는 `script/` 사본

### 완료 조건

- [ ] `post-review.sh` 가 이력 디렉터리를 `--git-common-dir` 을 절대 경로로 푼 값 아래에 둔다
- [ ] 원래 작업 트리와 linked worktree 에서 같은 리뷰 요청의 회차를 번갈아 등록하면 `<공통 디렉터리>/work-loop/review-findings-<번호>.tsv` 한 파일에 쌓이고 연속 회차가 이어서 세어진다
- [ ] 리포 루트가 아닌 작업 디렉터리에서 실행해도 같은 이력 파일을 쓴다
- [ ] 머리글의 위치 서술이 `<git-common-dir>/work-loop/` 다
- [ ] 기존 `test-review-loop.sh` 케이스가 같은 기대값으로 통과한다
- [ ] `src/bin/harness render` 뒤 `script/` 사본이 정본과 같고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/71-issue-worktree-run` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | worktree 간 이력 공유 | 같은 리뷰 요청에서 1회차 원래 작업 트리, 2회차 linked worktree, 같은 지적 | 이력 파일 하나, 2회차가 연속 회차로 세어진다 |
| UT-02 | 서브디렉터리에서 실행 | 원래 작업 트리의 하위 디렉터리에서 등록 | `<공통 디렉터리>/work-loop/` 의 같은 파일에 쌓인다 |
| UT-03 | 원래 작업 트리 호환 | 기존 케이스 | 이력 경로 `$work/.git/work-loop/review-findings-12.tsv` 그대로 |

## T7 · feat: 되감기에서 다른 worktree 가 체크아웃한 브랜치 남김

### 상위 Requirement

- relates to #71

### 작업 내용

다른 worktree 가 체크아웃한 로컬 브랜치는 `git branch -D` 가 실패한다. `rollback-work.sh` 가 그 브랜치를 지우지 않고 남기며,
보이는 단계와 되감는 단계에서 이유를 알리고 실패로 세지 않게 한다.

- 명세 8절, 9-3 의 "다른 worktree 가 체크아웃한 브랜치" 케이스
- `git worktree list --porcelain` 으로 브랜치마다 체크아웃한 worktree 경로를 모은다. 현재 작업 트리의 브랜치(`current`)는 지금처럼 따로 다룬다
- 보이는 단계: `local branch <브랜치>   ** checked out in worktree <경로> — will not be removed **`
- 되감는 단계: `kept local branch <브랜치> — it is checked out in worktree <경로>. remove that worktree and rerun to remove it`. 종료 코드에 닿지 않는다
- worktree 는 지우지 않는다. "되감을 것이 없음" 판정은 지금처럼 로컬 브랜치 건수로 한다
- 건드릴 파일: `src/templates/managed/script/rollback-work.sh`, `src/templates/managed/script/test-rollback-work.sh`, render 로 갱신되는 `script/` 사본

### 완료 조건

- [ ] 다른 worktree 가 체크아웃한 브랜치가 보이는 단계와 되감는 단계에 명세 8절 문구로 나온다
- [ ] 그 브랜치와 worktree 는 남고, 다른 로컬 브랜치는 지워지며 종료 코드는 0 이다
- [ ] 현재 작업 트리의 브랜치를 다루는 기존 케이스가 같은 기대값으로 통과한다
- [ ] `src/bin/harness render` 뒤 `script/` 사본이 정본과 같고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/71-issue-worktree-run` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | worktree 가 체크아웃한 브랜치 | 되감기 대상 로컬 브랜치 둘 중 하나를 linked worktree 가 체크아웃 | 그 브랜치는 남고 `checked out in worktree` 가 두 단계에 나옴, 다른 브랜치는 지워짐, 종료 코드 0, worktree 그대로 |
| UT-02 | 대상이 그 브랜치 하나뿐 | 되감기 대상이 worktree 가 체크아웃한 브랜치 하나 | "되감을 것이 없음" 이 아니라 보이는 단계에 그 브랜치가 나오고, 되감은 뒤 브랜치가 남고 종료 코드 0 |

## T8 · docs: 아키텍처·용어·담당 범위 문서에 이슈 worktree 반영

### 상위 Requirement

- relates to #71

### 작업 내용

T2 ~ T7 로 생긴 사실을 에이전트가 근거로 읽는 문서에 적는다.

**보호 문서를 수정하는 task 다.** `.ai/project/architecture.md` · `glossary.md` · `scope.md` 는 보호 문서이므로 사용자가 명시적으로
지시한 턴에서 고친다 (`.ai/AI_AGENT.md` 금지 사항). 권한 설정·가드에 걸리면 사람이 대응한다.

- 명세 10-1 · 10-2 · 10-3 의 위치별 반영 사실
- `.ai/project/architecture.md`: 데이터 흐름의 절차 실행(`harness run --worktree` 의 생성·실행·정리)과 실행 지표(worktree 이름과
  `worktree.dir` 로 실행 디렉터리를 다시 계산하는 귀속), 신뢰 경계(`include` 는 git 이 무시하는 로컬 파일만 복사하고 경로·내용을
  출력하지 않음, 기존 worktree 는 git 공통 디렉터리가 같을 때만 열림), 구성 요소의 기기 단위 상태(홈 아래 `.harness/<프로젝트>/worktrees/`)
- `.ai/project/glossary.md`: 용어 표에 `이슈 worktree` 행
- `.ai/project/scope.md`: "할 수 있는 일" 의 `run` 항목에 이슈별 worktree 로 같은 리포의 여러 이슈를 동시에 진행하는 것
- `.ai/AI_AGENT.md` 는 생성 파일이다. 세 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/architecture.md`, `.ai/project/glossary.md`, `.ai/project/scope.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] `.ai/project/architecture.md` 가 명세 10-1 표의 네 위치 사실을 담는다
- [ ] `.ai/project/glossary.md` 용어 표에 `이슈 worktree` 행이 있다
- [ ] `.ai/project/scope.md` 의 `run` 항목이 이슈별 worktree 실행을 담는다
- [ ] 세 문서에 worktree 절대 경로 예시나 개인 홈 경로가 없다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 가 세 문서와 일치하고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/71-issue-worktree-run` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 세 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 반영 확인 | `.ai/AI_AGENT.md` | 1장 `run` 항목, 2장 `이슈 worktree` 행, 5장 데이터 흐름·신뢰 경계·기기 단위 상태에 명세 10절 사실이 있다 |
