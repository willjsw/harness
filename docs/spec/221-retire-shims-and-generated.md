# 이식 뒤 남은 shim · 셸 생성물 · 옛 허용 규칙 걷기와 최종 명령 표기

관리 스크립트를 CLI 하위 명령으로 옮긴 이식(#209 · #210 · #211 · #212 · #213 · #215)이 옛 경로에 남긴 shim, 셸 생성물
(`script/harness.env` · `script/forge.sh` · `script/harness-verify.sh`), 옛 허용 규칙(`Bash(script/<이름>:*)`), `script/README.md` 를
걷는다. 에이전트 · 절차 · 설정이 보는 명령 표기는 render 가 하네스 루트 종류로 고른 CLI 경로(`{{HARNESS_CLI}}`)다. 끝나면 대상 리포
`script/` 에는 git 훅(`githooks/`)과 프로젝트 소유 `project/` 만 남는다. 리포 루트의 CI 파일이 `script/run-lint-test.sh` 를 부르는
설치본에만 그 shim 이 생성 파일로 남는다(3절).

**착수 조건**: #209 · #210 · #211 · #212 · #213 · #215 가 통합 브랜치에 머지되고, 그 여섯이 든 main 릴리스가 한 번 이상 나갔을 것.
main 릴리스는 develop → main 릴리스 리뷰 요청을 merge commit 으로 머지한 뒤 CI 가 내는 GitHub Release 다. 착수 판정(`harness preflight`)은
릴리스를 확인하지 않는다 — 사람이 확인한다. 그 여섯의 선행(#206 · #207 · #208 · #220)은 함께 들어와 있다. #217 은 선행이 아니다.

기준 코드는 위 이슈들이 들어간 통합 브랜치다. 함수가 어느 모듈에 있든 이 명세는 함수 이름으로 적는다(`derive()` · `plan()` ·
`allow_rules()` · `refuse_changes()` · `prune()` · `doctor_items()` 등 — 자리는 #206 의 모듈 지도).

| 따르는 것 | 정하는 이슈 |
|---|---|
| CLI 패키지 배치, `COMMANDS` · `DELEGATES` 의 자리, 통과 명령(`harness [--target DIR] <명령> <인자…>`), Python 단위 테스트 자리와 검증 단계 | #206 |
| 공유 설정 · 실효 설정과 레이어 해석, 내장 기본값 `src/templates/defaults.toml`, 실행 계획(`run_plan()` · `harness run-plan`), `script/harness.plan.json` 걷기 | #207 |
| 단계 값의 render 치환(`{{VAR}}`) 뒤 자리표시를 푸는 순서, 드라이버 · 역할 실행기 호출, 벤더 선언 `driver_write` | #208 |
| forge 어댑터와 `harness forge` · `forge-selftest` · `forge-setup`, 페이크 주입 지점 `HARNESS_FORGE_FAKE`, 용어 `shim` | #209 |
| `harness bash-guard` · `secret-scan` · `git-hook`, 훅 명령과 git 훅 shim 의 형태 | #210 |
| `harness review` · `preflight` · `sync-tasks` | #211 |
| `harness work-check`, 기본 절차 `work` · `review-loop`, 옛 agent 절(이전 기본값 목록 · `harness fix legacy-work`) | #212 |
| `harness carryover` · `rollback` · `span` · `usage` · `run-agent` · `verify` · `clone-key`, 표지 정본 `src/harness/format.py`, shim 공통 템플릿(213 명세 4-1) | #213 |
| `harness work-lock` | #215 |

정본 위치:

| 대상 | 정본 |
|---|---|
| 걷는 관리 파일 | `src/templates/managed/script/` — 통째로 지운다 |
| 걷는 생성 파일 | `plan()` 의 `script/harness.env` · `script/forge.sh` · `script/harness-verify.sh` 항목과 그 원형 · 생성 함수 |
| 조건부 shim `script/run-lint-test.sh` | 원형 `src/templates/generated/script/run-lint-test.sh` + `plan()` 의 조건 (3절) |
| 하네스 CLI 표기 `{{HARNESS_CLI}}` | `derive()` (4절) |
| 걷힌 경로와 새 표기의 대응 | 상수 하나 — 설정 값 사전 판정 · doctor 가 같은 값을 쓴다 (4-5) |
| 설정 값 사전 판정 | `refuse_changes()` 의 첫 판정 (6절) |
| 허용 목록 | `COMMANDS` 의 허용 표시와 `allow_rules()` (5절) |
| 가드 · 훅의 판정 값 | 설정 값 해석 모듈의 함수 하나 — `derive()` 와 가드 · 훅이 함께 쓴다 (7절) |
| 내장 기본 절차의 `run` | `src/templates/defaults.toml` |
| 사람용 설명 | `README.md` · `src/templates/managed/docs/workflow/` |
| UI | `src/ui/lib/doctor.js` · `src/ui/components/FlowCanvas.js` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/test/unit/` · `src/ui/lib/doctor.test.js` |

이 리포의 `script/` · `.ai/templates/` · `.claude/commands/` · `docs/workflow/` 아래 같은 이름의 파일은 거기서 설치 · 생성된 사본이다.

## 1. 바뀌는 것과 바뀌지 않는 것

바뀌지 않는 것:

- 하위 명령의 인자 · 표준 출력 · 종료 코드 · 남기는 기록. 문구가 바뀌는 곳은 가드 · 훅이 설정을 읽지 못할 때(7-1)와 pre-push 의 없어진 검사(7-5)뿐이다
- 매니페스트 규칙 — 사라지는 관리 · 생성 파일의 처리, 사용자 파일 · `script/project/` · 고정 사본을 지우지 않는 것 (2-3)
- git 훅 파일 이름과 `core.hooksPath` 기대 값, 훅의 판정 · 문구 · 사용 기록 (설정을 읽지 못할 때의 문구는 7-1)
- 권한 deny 규칙과 `write-doc` 세 호출 형태(`WRITE_DOC_CALLERS`), `.claude/settings.json` 의 훅 명령(#210 3-1)
- 옛 agent `work` 경로 — 옛 단계 조각 다섯, `/work` 관리 커맨드, 이전 기본값 목록, doctor 항목, `harness fix legacy-work` 는 남는다.
  그 문서의 명령 표기만 4절대로 바뀐다
- 결정 기록 본문의 `script/…` 경로. 그 시점의 관측이다

바뀌는 것:

- 대상 리포에서 shim · 셸 생성물 · 셸 표기 · 셸 회귀 테스트 · `script/README.md` 가 사라진다 (2절)
- `script/run-lint-test.sh` 는 리포 루트의 CI 파일이 부르는 동안에만 생성된다 (3절)
- 생성물 · 관리 파일 · 설정 값의 명령 표기가 `{{HARNESS_CLI}} <명령>` 이다 (4절)
- 허용 목록이 하위 명령 규칙(`Bash(<CLI> <명령>:*)`)만 갖는다 (5절)
- 걷힌 경로를 가리키는 설정 값이 있으면 render 가 아무것도 바꾸지 않고 멈춘다 (6절)
- 가드 · 훅이 공유 설정을 직접 읽고, 하네스 루트를 `harness.toml` 로 잡는다 (7절)
- `verify.script_tests` 를 읽되 무시하고, "하네스 스크립트 회귀" 단계가 없다 (8절)
- doctor 의 검증 항목 이름과 schema 키가 바뀐다 (9절)

## 2. 대상 리포에서 걷히는 것

### 2-1. 끝 상태

- 대상 리포 `script/` 에는 `githooks/`(생성)와 `project/`(소유)만 있다. 3절의 조건이 맞는 설치본에만 `script/run-lint-test.sh`(생성)가 더 있다
- 하네스 코드(`src/harness/` · `src/bin/harness`)가 실행하거나 source 하는 `script/` 아래 하네스 파일은 없다. git 이 `script/githooks/` 를, CI 가
  3절의 `script/run-lint-test.sh` 를 부른다. 검증이 실행하는 채운 옛 검증 스크립트 `script/verify-project.sh` 는 사용자 파일이다
- 이 리포도 같다. `script/project/` 는 이 리포의 것이다

### 2-2. 걷는 범위

걷을 목록은 착수 시점의 트리에서 센다. 규칙은 둘이다.

1. `src/templates/managed/script/` 를 통째로 지운다 — 그 아래 파일이 무엇이든 관리 파일에서 빠진다
2. `plan()` 에서 `script/githooks/` 밖의 `script/` 생성 파일을 뺀다 — `script/harness.env` · `script/forge.sh` · `script/harness-verify.sh`.
   그것을 만들던 원형과 생성 함수(`harness_env()` · `SHELL_EXPANDS` · `verify_script()` · `VERIFY_SH` · `src/templates/generated/script/forge.sh`)도 지운다.
   `script/run-lint-test.sh` 는 3절의 조건으로 다시 든다

기대 목록:

| 갈래 | 경로 | 남긴 이슈 |
|---|---|---|
| shim (관리) | `script/forge-selftest.sh` · `script/forge-setup.sh` | #209 |
| shim (관리) | `script/hooks/bash-guard.sh` · `script/secret-scan.sh` | #210 |
| shim (관리) | `script/review-mr.sh` · `script/post-review.sh` · `script/work-preflight.sh` · `script/sync-task-issues.sh` | #211 |
| 독립 진입점 (관리) | `script/check-open-mrs.sh` | #211 |
| shim (관리) | `script/work-check.sh` | #212 |
| shim (관리) | `script/create-carryover-issue.sh` · `script/rollback-work.sh` · `script/metric.py` · `script/usage-log.sh` · `script/usage-report.sh` · `script/run-agent.py` · `script/run-lint-test.sh` · `script/_clone_key.py` | #213 |
| shim (관리) | `script/work-lock.sh` | #215 |
| 셸 표기 (관리) | `script/harness-format.sh` · `script/usage-vocab.sh` | #213 |
| 셸 회귀 테스트 (관리) | `script/test-*.sh` 전부 | — |
| 문서 (관리) | `script/README.md` | — |
| 셸 생성물 | `script/harness.env` · `script/forge.sh` · `script/harness-verify.sh`(생성 shim) | — · #209 · #213 |

`script/harness.plan.json` 은 #207 이 걷는다. 이 명세의 범위가 아니다.

### 2-3. 사라지는 파일의 처리

지금 규칙 그대로다(ADR 0002 · 0015 · 0017, `docs/spec/58-separate-managed-and-project-parts.md`).

- 이전 매니페스트(`.harness/managed` · `.harness/generated`)에 있고 이번 render 가 쓰지 않는 경로는 다음 render · install 의 정리(`prune()`)가 지운다.
  설치 뒤 고친 관리 파일도 지운다. 해시를 대조해 남기는 예외는 forge 이슈 · 리뷰 요청 템플릿뿐이다
- 매니페스트에 없는 사용자 파일, `script/project/`, 고정 사본(`.harness/`)은 지우지 않는다
- 비게 된 디렉터리(`script/hooks/` 등)도 걷는다. 사용자 파일이 남은 디렉터리는 남긴다
- 지울 경로도 매니페스트 검증과 경로 규칙의 사전 판정을 거치고 `guarded_path()` 로 지운다
- render 출력은 지금처럼 지운 건수만 낸다

### 2-4. 이미 떠 있는 에이전트 세션

render 가 이번 정리로 `script/hooks/bash-guard.sh` 를 지웠으면 표준 오류에 한 줄을 낸다. 렌더 결과와 종료 코드는 바뀌지 않는다.

```
note: the command guard hook moved into the harness CLI — reopen running agent sessions so they pick up the new hook command
```

- 훅 명령이 `script/hooks/bash-guard.sh` 이던 버전에서 시작한 세션은 그 명령을 계속 쓴다. 릴리스를 건너뛴 설치본이 그렇다
- 그 세션에서는 훅 명령이 127 로 끝나 명령 가드가 돌지 않는다. 그 종료 코드를 Claude Code 가 통과로 다루는지
  <!-- TBD: 확인 필요 — Claude Code 가 PreToolUse 훅의 종료 코드 127 을 통과로 다루는지 -->. deny 규칙과 git 훅은 그대로 걸린다

## 3. `script/run-lint-test.sh` — 리포 루트 CI 가 부르는 동안만

### 3-1. 조건

render 가 `script/run-lint-test.sh` 를 생성하는 조건은 하나다 — **리포 루트의 CI 파일 가운데 이번 render 가 생성하지 않는 것에
`script/run-lint-test.sh` 가 든 줄이 있다.**

- 리포 루트는 `repo_prefix()` 판정의 작업 트리 최상위다. 하네스 루트가 git 작업 트리 밖이면 하네스 루트다. 모노레포 서브프로젝트는
  하네스 루트 밖인 리포 루트의 파일을 읽는다
- CI 파일은 리포 루트의 `.github/workflows/` 바로 아래 `*.yml` · `*.yaml` 과 `.gitlab-ci.yml` 이다. `forge.review_host` 와 상관없이 둘 다 본다
- 이번 render 가 생성하는 경로(#217 의 CI 게이트가 들어와 있으면 그 파일)는 보지 않는다. 생성 판정이 자기 출력에 기대지 않는다
- 판정은 줄에 문자열 `script/run-lint-test.sh` 가 있는지만 본다. YAML 을 해석하지 않는다
- 일반 파일만 읽는다. 심볼릭 링크와 디렉터리는 건너뛴다. 읽지 못한 파일은 부르는 것으로 본다 — 머지 게이트를 깨지 않는 쪽이다
- 읽기만 한다. 이 파일들을 쓰거나 지우지 않고(ADR 0002 · 0017), 내용을 어떤 출력에도 옮기지 않는다
- `check --staged` 는 인덱스에 있는 CI 파일과 그 내용으로 같은 판정을 한다. 그 밖의 명령은 작업 트리를 읽는다

### 3-2. 파일

- 생성 파일이다. `plan()` 이 3-1 의 조건이 맞을 때만 넣는다(`verify.post_commit` 이 켜질 때만 넣는 `script/githooks/post-commit` 과 같은 자리)
- 원형 `src/templates/generated/script/run-lint-test.sh` 는 213 명세 4-1 의 shim 공통 템플릿 그대로 `verify` 를 부른다 — 자기 위치의 부모를
  하네스 루트로, `.harness/bin/harness` → `src/bin/harness` 순으로 CLI 를 골라 `<CLI> --target <루트> verify <받은 인자 그대로>` 로 exec 한다.
  CLI 를 찾지 못하면 공통 문구 두 줄과 종료 코드 1 이다. 권한은 0755 다
- 머리글은 생성 표지와 함께 이 파일이 리포 루트의 CI 파일이 부르는 동안에만 생성된다는 것, 그 줄을 `{{HARNESS_CLI}} verify` 로 바꾸면
  다음 render 가 걷는다는 것을 적는다. 설정 값은 들어가지 않는다
- 기존 설치본에서는 관리 파일이던 경로가 생성 파일로 옮겨 간다. 그 render 의 정리는 이번에 생성하는 경로를 지우지 않고(지금 `prune()` 의 보존 집합),
  사용자 파일 판정은 두 매니페스트를 함께 본다 — 멈추거나 지우지 않는다

### 3-3. 조건이 바뀔 때

- 사람이 CI 파일의 줄을 바꾸면 다음 render 가 이 파일을 지운다. 줄을 더하면 다음 render 가 만든다
- 그 사이 `check` 는 생성 파일 대조로 어긋남을 낸다 — `left over; the config no longer generates it` 또는 `missing`. pre-commit 의 `check --staged` 도 같다
- 같은 리포의 다른 하네스 루트(모노레포 서브프로젝트 여럿)는 리포 루트의 같은 파일을 보고 각자 판정한다

### 3-4. doctor

`verification` 절에 조건을 이루는 CI 파일마다 한 줄을 낸다. 없으면 줄이 없다.

| state | what | detail |
|---|---|---|
| `warn` | `<리포 루트 기준 경로> runs script/run-lint-test.sh` | `` the harness keeps generating script/run-lint-test.sh while a CI file runs it — change that line to `<CLI> verify` `` |

- `<CLI>` 는 4-1 의 값이다. 서브프로젝트면 그 값은 서브프로젝트 기준이다 — CI 의 작업 디렉터리가 서브프로젝트다
- #217 이 들어와 있으면 그 `ci gate` 절의 `<경로> runs script/run-lint-test.sh` 줄은 이 줄 하나로 대신한다

### 3-5. CI 원형과 게이트

- 새 설치에 까는 CI 원형(`src/templates/ci/<host>/` 아래)은 `{{HARNESS_CLI}} verify` 를 부른다. 원형 머리 주석의 `script/run-lint-test.sh` 도 같이 바꾼다.
  원형은 지금처럼 `derive()` 값으로 치환해 깐다
- #217 이 들어와 있으면 `{{CI_VERIFY}}` 가 내는 명령은 `<CLI> verify`, `policy.check_min_preset_version` 이 참이면
  `<CLI> check --min-preset-version "$HARNESS_MIN_PRESET_VERSION" && <CLI> verify` 다. 게이트 템플릿 · 서브프로젝트 골격 · GitLab 루트 원형의
  주석도 같은 표기다
- 이미 깔린 소유 CI 파일은 하네스가 고치지 않는다. 3-1 · 3-4 가 그 동안을 맡는다
- 이 리포의 `.github/workflows/harness-verify.yml` 이 소유 파일이면 그 `run` 을 `src/bin/harness verify` 로 바꾼다. 같은 변경에서 이 리포의
  `script/run-lint-test.sh` 도 걷힌다

## 4. 명령 표기 — `{{HARNESS_CLI}}`

### 4-1. 값

| 하네스 루트 | `{{HARNESS_CLI}}` |
|---|---|
| 하네스 소스 리포(`source_tree()` 가 참) | `src/bin/harness` |
| 그 밖 | `.harness/bin/harness` |

- `derive()` 가 하네스 루트를 받아 낸다(ADR 0013). 고정 사본이 빠진 고장 상태에서도 같은 값이다 — 생성물은 클론마다 같아야 하고, 사본이 없는 것은 doctor 가 짚는다
- 소스 리포의 worktree 는 소스 리포다(`src/bin/harness`)
- 생성물은 이 값 뒤에 하위 명령 이름을 붙여 적는다 — `{{HARNESS_CLI}} <명령> <인자…>`. 전역 옵션 `--target` 은 적지 않는다(하네스 루트에서 부른다)
- 문서는 이 표기를 하네스 루트 기준 상대 경로로 읽는다. 하네스 루트가 리포 루트가 아니면(모노레포) 그 서브프로젝트에서 부른다

### 4-2. 적용 범위

| 자리 | 바꾸는 것 |
|---|---|
| 절차 조각 `src/templates/workflows/*/` — prework · retro · `work`(옛 agent 조각 다섯 포함) · `review-loop` | `script/<이름>` 표기 전부를 4-5 의 새 표기로. `review_mr_threads {mr}` 처럼 forge 함수를 바로 적은 곳은 `{{HARNESS_CLI}} forge review_mr_threads {mr}` |
| 절차 문서 생성(`step_body()` · `workflow_doc()`) | CLI 러너 단계의 첫 문단 명령 `script/run-agent.py <역할> <이슈번호>` 를 `{{HARNESS_CLI}} run-agent <역할> <이슈번호>` 로. 상수 `RUN_AGENT` 를 없앤다. agent 절차 문서의 시작 표지 줄 `script/metric.py step <절차> <단계>` 를 `{{HARNESS_CLI}} span step <절차> <단계>` 로 |
| 역할 어댑터 본문 `src/templates/agents/*.md` | 검증 줄 `{{HARNESS_CLI}} verify --commit`, 리뷰 · 등록 명령 `{{HARNESS_CLI}} review` · `{{HARNESS_CLI}} review post <번호> - < <본문파일>` |
| 역할 선언 frontmatter | `entry: {{HARNESS_CLI}} review`. `summary` · `description` 에 명령이 들면 같은 표기 |
| frontmatter 를 쓰는 생성 | `agent_table()` · `command_rows()` · 어댑터 frontmatter 가 `summary` · `description` 의 `{{HARNESS_CLI}}` 를 채운다. 실행 계획의 `entry`(공용 실행기면 `{{HARNESS_CLI}} run-agent <역할>`)도 채운 값이다. `harness schema` 의 `script_roles` 와 `validate_workflows()` 의 안내는 채우지 않은 설정 표기 그대로다 — 설정의 `run` 과 같은 글자로 맞대 본다 |
| 역할 계약 · 양식 `src/templates/managed/.ai/templates/*.md` | developer · planner · code-reviewer · security-guard · docs-writer 계약과 `mr.md` · `mr-guide.md` 의 `script/<이름>` 표기를 새 표기로. developer 의 "조회는 `script/forge.sh` 의 함수로만 한다" 는 "조회는 `{{HARNESS_CLI}} forge <함수>` 로만 한다" |
| 관리 커맨드 `src/templates/managed/.claude/commands/` — `prework.md` · `security-guard.md` · `work.md` | 위임표와 본문의 스크립트 표기를 새 표기로 |
| `.codex/agents/` | 역할 어댑터 본문과 같은 원형에서 나오므로 따라 바뀐다 |
| `src/templates/generated/.ai/AI_AGENT.md` | 3장 끝 문단, 6-4 의 이슈 생성 수단 표(`{{HARNESS_CLI}} sync-tasks <요구사항 이슈번호>` · `{{HARNESS_CLI}} carryover <원본이슈> <제목> <본문파일>`), 7장 되감기 예외(`{{HARNESS_CLI}} rollback`), 8장 검증 루프 둘째 줄(`{{HARNESS_CLI}} verify --commit`), 9장 문서 지도, 10장 배치 표 (11-2) |
| `src/templates/generated/CLAUDE.md` | 검증 줄 `{{HARNESS_CLI}} verify --commit`, 설정 변경 줄 `{{HARNESS_CLI}} render`, 흐름 그림의 스크립트 이름을 하위 명령 이름으로(`preflight` · `sync-tasks` · `review` · `work-check` · `work-lock`) |
| 규칙 문서 3장(`commands_doc()`) | "검증 일괄" 행 `{{HARNESS_CLI}} verify`. 단계 순서 문장 "검증(`<CLI> verify`)은 이 순서로 돈다" |
| `.ai/forge.md` 원형 `src/templates/forge/forge.md` | "스크립트에서 쓸 때" 절을 "명령줄에서 쓸 때" 로 — `{{HARNESS_CLI}} forge <함수> [인수…]`, 본문 파일 자리는 `-` 와 표준 입력. 계약 함수 표(이름 · 인자 · 출력 · 종료 코드)를 `forge_doc()` 이 #209 의 계약 표에서 이 절에 싣는다. `script/forge.sh` 머리글이 갖던 표다 |
| 관리 문서 `src/templates/managed/docs/workflow/` | 11절 |
| CI 원형 | 3-5 |
| 내장 기본값 `src/templates/defaults.toml` | 4-4 |
| doctor 문구 | `adapter <kind>` 의 미검증 detail `` unverified — run `<CLI> forge-selftest` `` (`<CLI>` 는 4-1 의 값). `config` 절 `no command guard for <오케스트레이터>` 의 detail 에서 `bash-guard.sh` 를 `the command guard` 로 |

### 4-3. 관리 파일의 치환

- render · install 은 관리 파일을 깔 때 `{{HARNESS_CLI}}` 하나만 4-1 의 값으로 채운다. 다른 `{{대문자}}` 변수가 관리 파일에 있으면
  `substitute()` 의 `unknown template variable` 오류로 render 를 거부한다. `{{step:<id>}}` 같은 다른 중괄호는 글자 그대로다
- `.harness/managed` 의 해시는 지금처럼 깐 내용으로 계산한다. 같은 하네스 루트에서는 같은 내용이 깔린다
- 고정 사본의 템플릿(`.harness/templates/managed/`)은 채우지 않은 원문이다

### 4-4. 설정 값

- 절차 단계의 `run` · `text` 에서 하네스 명령은 `{{HARNESS_CLI}} <명령>` 으로 적는다
  - agent 절차: 문서 전체가 render 치환을 거치므로 지금처럼 채워진다
  - driver 절차: 드라이버가 #208 4-2 의 순서대로 render 치환을 먼저 하고 자리표시를 푼다. 값에 공백이 없으므로 인자를 나누는 일과 섞이지 않는다
  - 같은 표기가 모든 하네스 루트에서 맞다. 내장 기본값과 preset 이 같은 글자로 소스 리포 · 대상 리포 양쪽에 닿는다
- `verify.checks[].run` 과 `[commands]` 는 검증이 셸로 그대로 돈다. 치환하지 않는다 — 하네스 명령이 필요하면 그 루트의 경로를 적는다
- `src/templates/defaults.toml` 의 기본 절차가 이 표기를 쓴다 — `work` 의 `{{HARNESS_CLI}} work-lock acquire {issue}` · `{{HARNESS_CLI}} work-check clean` ·
  `{{HARNESS_CLI}} preflight {issue}` · `{{HARNESS_CLI}} sync-tasks {issue}` · `{{HARNESS_CLI}} work-check develop …` · `{{HARNESS_CLI}} work-lock release {issue}`,
  `review-loop` 의 `{{HARNESS_CLI}} review {mr}` · `{{HARNESS_CLI}} work-check fix …`. 인자와 배선은 #212 · #215 가 정한 그대로다
- `src/templates/defaults.toml` 의 `[workflows]` 머리 주석: "`run` · `text` 에서 하네스 명령은 `{{HARNESS_CLI}} <명령>` 으로 적는다. render 가 하네스 루트
  종류로 채운다(대상 리포 `.harness/bin/harness`, 소스 리포 `src/bin/harness`)". `type agent` 설명의 "`script/run-agent.py` 로 따로 돈다" 는
  "`{{HARNESS_CLI}} run-agent` 로 따로 돈다"
- 옛 agent 절로 되돌리는 절(#212 10-1)의 문서 예시는 `run = "{{HARNESS_CLI}} sync-tasks <Requirement 이슈번호>"` · `run = "{{HARNESS_CLI}} review <MR번호>"` 다

### 4-5. 걷힌 경로와 새 표기

상수 하나가 갖는다. 6절의 사전 판정 · doctor 와 README "업데이트" 의 대응표(11-2)가 이 표를 쓴다.

| 걷힌 경로 | 새 표기 | 비고 |
|---|---|---|
| `script/review-mr.sh` | `{{HARNESS_CLI}} review` | |
| `script/post-review.sh` | `{{HARNESS_CLI}} review post` | 본문은 파일 인자가 아니라 `-` 와 표준 입력 |
| `script/work-preflight.sh` | `{{HARNESS_CLI}} preflight` | |
| `script/sync-task-issues.sh` | `{{HARNESS_CLI}} sync-tasks` | |
| `script/check-open-mrs.sh` | `{{HARNESS_CLI}} forge harness_issue_open_mrs` | 출력은 번호 목록이고 종료 코드 뜻이 다르다(0 성공 · 1 실패) |
| `script/work-check.sh` | `{{HARNESS_CLI}} work-check` | |
| `script/work-lock.sh` | `{{HARNESS_CLI}} work-lock` | |
| `script/create-carryover-issue.sh` | `{{HARNESS_CLI}} carryover` | |
| `script/rollback-work.sh` | `{{HARNESS_CLI}} rollback` | |
| `script/metric.py` | `{{HARNESS_CLI}} span` | |
| `script/usage-log.sh` | `{{HARNESS_CLI}} usage log` | |
| `script/usage-report.sh` | `{{HARNESS_CLI}} usage report` | |
| `script/run-agent.py` | `{{HARNESS_CLI}} run-agent` | |
| `script/run-lint-test.sh` | `{{HARNESS_CLI}} verify` | |
| `script/harness-verify.sh` | `{{HARNESS_CLI}} verify --steps-only` | |
| `script/_clone_key.py` | `{{HARNESS_CLI}} clone-key` | |
| `script/secret-scan.sh` | `{{HARNESS_CLI}} secret-scan` | |
| `script/hooks/bash-guard.sh` | `{{HARNESS_CLI}} bash-guard` | 훅 명령이 부른다 |
| `script/forge-selftest.sh` | `{{HARNESS_CLI}} forge-selftest` | |
| `script/forge-setup.sh` | `{{HARNESS_CLI}} forge-setup` | |
| `script/forge.sh` | `{{HARNESS_CLI}} forge <함수>` | source 하지 않는다. 본문 파일 자리는 `-` 와 표준 입력 |
| `script/harness.env` | 공유 설정 | 파생 값은 `harness vars` 가 보인다 |
| `script/harness-format.sh` · `script/usage-vocab.sh` | CLI 패키지의 표지 · 사용 기록 모듈 | 셸 표기가 없다 |
| `script/test-*.sh` | 소스 리포의 `src/test/unit/` | 대상 리포에 가지 않는다 |
| `script/README.md` | `docs/workflow/README.md` 의 "하네스 명령" 절 | |

## 5. 권한 허용 목록

### 5-1. 하위 명령 규칙

- 허용 여부는 명령 쪽에 선언한다. `COMMANDS` 의 항목은 `(통과, 설정이 필요한가, 허용, 인수, 설명)` 다섯 원소다 — #206 3-3 의 네 원소
  `(통과, 설정이 필요한가, 인수, 설명)` 의 셋째 자리에 허용 표시를 끼운다. 허용 표시는 통과 표시처럼 `True` 또는 `None` 이다
- `allow_rules()` 는 허용 표시가 `True` 인 명령마다 `Bash({{HARNESS_CLI}} <명령>:*)`(4-1 의 값으로 채운 것)를 명령 이름 오름차순으로 낸다
- 순서: 하위 명령 규칙 → forge 명령(`allow.toml`) → `git switch -c` · `git commit`(→ `allow_push` 면 `git push`). 지금 관리 스크립트 규칙이 있던 자리다
- `Bash(script/<이름>:*)` 규칙은 하나도 나오지 않는다. `allowed_scripts()` · `ALLOW_EXCLUDED` 와 그 거부 문구(`permission exclusion names a script that is not shipped`),
  #213 이 둔 하위 명령 묶음 상수와 그 거부 문구(`permission list names a command that does not exist`)를 없앤다 — 표시가 명령 표 자신에 있어 어긋날 수 없다

허용 표시가 있는 명령 — 옛 허용 규칙을 대신한 하위 명령만 1:1 로 옮긴다:

| 명령 | 대신하는 옛 규칙 |
|---|---|
| `preflight` | `Bash(script/work-preflight.sh:*)` |
| `review` | `Bash(script/review-mr.sh:*)` · `Bash(script/post-review.sh:*)` |
| `run-agent` | `Bash(script/run-agent.py:*)` |
| `secret-scan` | `Bash(script/secret-scan.sh:*)` |
| `span` | `Bash(script/metric.py:*)` |
| `sync-tasks` | `Bash(script/sync-task-issues.sh:*)` |
| `usage` | `Bash(script/usage-log.sh:*)` · `Bash(script/usage-report.sh:*)` |
| `verify` | `Bash(script/run-lint-test.sh:*)` |
| `work-check` | `Bash(script/work-check.sh:*)` |
| `work-lock` | `Bash(script/work-lock.sh:*)` |

- 대신할 하위 명령이 없는 옛 규칙은 사라진다 — `check-open-mrs.sh`(그 조회는 `forge` 이고 `forge` 는 쓰기 함수를 함께 부른다), `harness-format.sh` ·
  `usage-vocab.sh`(source 하던 표기), `test-*.sh`(대상 리포에 테스트가 없다)
- 표시가 없는 명령 가운데 절차가 부르는 것과 그 이유

| 명령 | 이유 |
|---|---|
| `carryover` | 이슈를 만든다. 되돌릴 수 없는 forge 쓰기다 |
| `rollback` | 리뷰 요청 · task 이슈를 닫는다. 사용자가 직접 부르고 확인을 주는 턴에서만 돈다 |
| `forge` | 쓰기 함수(`tracker_issue_create` · `tracker_issue_close` · `review_mr_close` 등)를 함께 부른다 |
| `forge-selftest` | `--create-issue` 로 이슈를 만든다 |
| `forge-setup` | 원격에 라벨을 만든다 |
| `bash-guard` · `git-hook` | 훅이 부른다. 에이전트가 부르지 않는다 |
| `clone-key` | 다른 명령이 쓰는 모듈의 진입점이다 |

- 그 밖의 명령(`install` · `render` · `set` · `fix` · `run` · `uninstall` 등)은 절차가 정상 경로에서 부르지 않는다. 표시가 없다
- deny 와 명령 가드는 바뀌지 않는다. allow 에 든 명령에도 가드가 실행 전에 돈다

### 5-2. driver 의 쓰기 범위

- `driver_write` 가 여는 범위 표(#208 7-4 · #212 7)의 하네스 명령 행을 새 표기로 바꾼다 — 검증 `{{HARNESS_CLI}} verify --commit`,
  forge 읽기 · 쓰기 `{{HARNESS_CLI}} forge <함수>`(`tracker_issue_view` · `review_mr_view` · `review_mr_threads` · `review_mr_thread_reply` · `review_mr_note_summary`),
  이월 이슈 `{{HARNESS_CLI}} carryover`, task 매핑 `{{HARNESS_CLI}} sync-tasks <이슈> --dry-run`. 범위 자체는 그대로다
- 벤더 선언의 `driver_write` 인자가 명령을 이름으로 담으면 그 하네스 명령 경로는 4-1 의 값으로 채운다 — `expand()` 의 값 이름 `harness`
  (`{harness}`)로 받는다 <!-- TBD: 확인 필요 — #208 이 벤더별로 확인하는 `driver_write` 인자가 명령 이름을 담는지 -->

## 6. 걷힌 경로를 가리키는 설정 값

### 6-1. 판정

공유 설정(#207 — 내장 기본값 · preset · 프로젝트)의 아래 값에 4-5 의 걷힌 경로가 낱말로 들어 있으면 걸린다.

- 절차 단계의 값 — `workflows.<절차>.steps[<n>].run` · `workflows.<절차>.steps[<n>].text`
- 검증 단계의 명령 — `verify.checks[<n>].run`
- 프로젝트 명령 — `commands.<키>`

- 걷힌 경로는 4-5 의 왼쪽 칸이다. `script/test-*.sh` 는 `script/test-` 로 시작하고 `.sh` 로 끝나는 모든 이름이다
- 낱말: 앞이 값의 처음 · 공백 · 따옴표 · 백틱 · `(` · `=` 이고(경로 앞의 `./` 는 경로에 든다), 뒤가 값의 끝이거나 경로 문자(영문자 · 숫자 · `_` · `.` · `-` · `/`)가 아닌 것
- 판정은 레이어마다 하고, 걸린 값마다 키 · 그 값이 온 레이어 · 걷힌 경로 · 새 표기를 남긴다
- 내장 기본값에는 걷힌 경로가 없다(단위 테스트가 본다). 개인 레이어는 이 키들을 받지 않는다(#207)
- 설정 검증(`validate()`)의 일부가 아니다 — 설정을 읽는 다른 명령(가드 · 훅 · 하위 명령)은 이 판정으로 멈추지 않는다

### 6-2. render

- `refuse_changes()` 의 첫 판정이다. 매니페스트 검증 · 경로 규칙 · 사용자 파일 판정보다 먼저 돌고, 걸리면 아무것도 쓰지 않고 종료 코드 2 다
- 그래서 install(고정 사본을 바꾸기 전), `set` · `steps` · `checks`(바꾼 설정을 되돌린다 — 지금 사용자 파일 판정과 같은 경로)도 같은 판정으로 멈춘다.
  걷힌 경로를 고치는 변경은 고친 뒤의 설정으로 판정하므로 통과한다
- 표준 오류:

```
error: <n> config value(s) name a script the harness no longer installs
  --> workflows.work.steps[0].run (harness.toml): script/sync-task-issues.sh
      use {{HARNESS_CLI}} sync-tasks
  --> verify.checks[1].run (harness.toml): script/run-lint-test.sh
      use .harness/bin/harness verify
nothing was written

help: change each value as shown, then rerun
```

- `use` 줄은 절차 단계 값이면 4-5 의 설정 표기(`{{HARNESS_CLI}} …`), `verify.checks` · `commands` 값이면 4-1 의 값을 채운 경로다(4-4)
- 레이어 표시는 프로젝트면 `harness.toml`, preset 이면 #216 의 레이어 표시다
- 걸린 값에 비고(4-5)가 있으면 `use` 줄 끝에 ` — <비고>` 를 붙인다

### 6-3. 이전 기본값 절

- 이 명세가 내장 기본값 `work` 의 표기를 바꾸므로(4-4) 바뀌기 전 판을 이전 기본값 목록(#212 10-3)에 더한다 — #215 4-1 이 낸 driver 기본값
  (#212 2-1 의 절차에 잠금 단계 넷과 해제 배선이 든 `[workflows.work]` 표 전체, `run` 이 `script/<이름>.sh` 표기)이다. #215 4-5 의 선례와 같다.
  목록은 #212 10-1 의 agent 절, #215 4-5 가 더한 #212 2-1 의 driver 절, 이 판 셋이다. doctor 항목과 `harness fix legacy-work` 가 같은 목록을 쓴다
- 프로젝트 레이어의 `[workflows.work]` 가 이전 기본값 목록의 한 항목과 같으면 6-2 의 `help:` 줄 뒤에 두 줄을 더 낸다

```
      or drop that workflows.work to run the built-in work workflow
        harness fix legacy-work
```

- 옛 agent 절은 계속 되돌림 경로다. 옛 단계 조각과 `/work` 커맨드는 남고 그 표기는 4절대로 바뀐다. 그 절의 `run` 값만 6-2 대로 새 표기로 바꾸면
  agent 절차로 계속 돈다 — 그렇게 바꾼 절은 이전 기본값 목록의 항목과 같지 않으므로 doctor 가 짚지 않는다
- `harness fix legacy-work` 는 절을 지운 설정으로 render 하므로 이 판정에 걸리지 않는다
- 렌더된 `.ai/workflows/work.md` 가 없는 스크립트를 지시하는 일은 없다 — 조각은 새 표기이고, 걷힌 경로를 담은 단계 값은 render 가 받지 않는다

### 6-4. doctor

`config` 절에 걸린 값마다 한 줄을 낸다.

| state | what | detail |
|---|---|---|
| `bad` | `` `<키>` names <걷힌 경로> `` | `the harness no longer installs it — use <새 표기> (render stops until it changes)` |

- `<새 표기>` 는 6-2 의 `use` 줄과 같은 값이다
- 이전 기본값과 같은 `[workflows.work]` 의 doctor 항목(#212 10-3)은 그대로 함께 나온다
- `check` 는 이 판정을 따로 하지 않는다. 하네스를 갱신하면 생성물 대조가 어긋남을 내고, render 가 6-2 의 안내를 낸다

## 7. 가드 · 훅의 값과 루트

### 7-1. 값의 출처

- 명령 가드(`harness bash-guard`)와 git 훅 본문(`harness git-hook commit-msg|pre-push`)은 `script/harness.env` 대신 하네스 루트의 공유 설정을 읽는다.
  render 와 같은 설정 로더 · 레이어 해석이다(#207). 개인 레이어는 읽지 않는다
- 판정 값(보호 브랜치 목록, 보호 문서 검사식, 커밋 제목 검사식 · 형식 · 예시 · 태그, 브랜치 형식, 통합 브랜치, push 전 검증 여부)은 설정 값 해석 모듈의
  함수 하나가 계산한다. `derive()` 도 같은 함수로 같은 값을 낸다 — 두 곳이 따로 계산하지 않는다
- 설정을 읽지 못하면 지금처럼 막는다. 설정을 읽지 못한 것은 프로젝트 레이어 파일이 없거나, 어느 레이어든 해석 · 검증에 실패하거나,
  preset 사본과 lock 의 대조(#216 5-1)가 어긋남이나 읽을 수 없음을 낸 경우다 — 가드가 설정을 읽지 못하면 통과가 아니라 차단이라는
  신뢰 경계 원칙(`.ai/project/architecture.md`)을 따른다. 설정 로더 · 대조의 오류 줄 뒤에 아래를 낸다

| 지점 | 표준 오류 | 종료 코드 |
|---|---|---|
| 명령 가드 | `blocked: cannot read the harness config under <루트>, so the guards cannot run` / `help: passing everything through without the lists is the same as having no guard — fix the config (harness check shows what is wrong), then retry` | 2 (차단) |
| commit-msg | `error: cannot read the harness config under <루트>, so the commit message cannot be checked` / `help: fix the config (harness check shows what is wrong), then retry` | 1 |
| pre-push | `blocked: cannot read the harness config under <루트>, so the push cannot be checked` / `help: fix the config (harness check shows what is wrong), then retry` | 1 |

- 6절의 판정은 가드 · 훅을 막지 않는다
- `envfile`(셸 대입 파일 리더)은 읽을 파일이 없으므로 없앤다. 표지는 지금처럼 `src/harness/format.py` 가 갖는다
- `derive()` 의 값 가운데 생성물 템플릿이 쓰지 않고 `harness.env` 로만 가던 것(#210 의 `VERIFY_PRE_PUSH` 등)은 없앤다

### 7-2. 가드 경로의 import

#210 2-3 의 제한과 #213 5-1 의 가드 조건을 이렇게 바꾼다 — 통과 경로가 불러오는 하네스 모듈은 진입 스크립트 · 벤더 선언 · 설정 로더 ·
설정 값 해석 모듈 · 가드 모듈이다. render · 지표 · 사용 기록 모듈과 `urllib` · `http` 는 불러오지 않는다. 사용 기록 모듈은 차단이 정해진
뒤에만 부른다(7-4). 설정을 읽는 것이 Bash 호출마다 한 번 늘어난다.

### 7-3. 루트 판정

- `script/githooks/` 의 훅(commit-msg · pre-commit · pre-push · post-commit)은 자기 위치의 `../..` 에 `harness.toml` 이 있으면 그것을, 없으면
  `git rev-parse --show-toplevel` 을 하네스 루트로 잡는다. 지금 `script/harness.env` 를 보던 자리다
- `.claude/settings.json` 의 훅 명령은 `$CLAUDE_PROJECT_DIR` 를 루트로 쓴다(#210 3-1, 그대로). worktree 에서는 worktree 의 설정으로 판정한다

### 7-4. 차단 기록

가드 · 훅의 차단 사용 기록(`block bash-guard <라벨>` · `block commit-msg format` · `block pre-commit secret-scan` · `block pre-push protected-branch` ·
`block pre-push verify`)은 `script/usage-log.sh` 를 거치지 않는다. 차단 경로에서만 사용 기록 모듈(#213)을 불러 남긴다 — 통과 경로의 import 는 7-2 그대로다.
줄 형식 · 어휘 · 실패를 버리는 규칙은 그대로다.

### 7-5. pre-push · post-commit 의 검증

- pre-push(`verify.pre_push` 가 켜졌을 때)는 같은 CLI 의 `verify` 를 하위 프로세스로, 표준 입력을 비우고 돈다. 순서 · 문구 · 사용 기록은 그대로이고,
  `script/run-lint-test.sh` 가 실행 가능한지 보던 검사와 그 문구(`verify.pre_push is on but script/run-lint-test.sh is missing`)는 없앤다
- post-commit(`verify.post_commit` 이 켜졌을 때 생성)은 다른 훅과 같은 형태의 shim 이다 — 7-3 으로 루트를 잡고 CLI 를 골라
  `exec <CLI> --target <루트> verify`. CLI 를 찾지 못하면 shim 공통 문구 두 줄과 1 이다. 커밋 뒤라 결과는 보고용이다

## 8. `verify.script_tests`

- "하네스 스크립트 회귀" 단계를 없앤다. 상수 `SCRIPT_TESTS` 와 `VERIFY_DEFAULTS` 의 `script_tests`, 환경 변수 `HARNESS_SCRIPT_TESTS`(`QUIET_ENV()` 에서도)를 없앤다
- 키는 공유 설정의 어느 레이어에 있어도 받고 무시한다. 값의 형을 보지 않는다. `validate()` 의 `[verify]` 키 목록이 이 키를 받는다
- `harness render` 는 그 키가 든 레이어마다 표준 오류에 한 줄을 낸다. 렌더 결과와 종료 코드는 바뀌지 않는다 — 옛 별칭 `{project}` 안내와 같은 형식이다

  ```
  note: verify.script_tests is no longer read — delete it from <레이어>
  ```

- `harness doctor` 의 `config` 절에 `warn` 한 줄

  | what | detail |
  |---|---|
  | `` `verify.script_tests` is no longer read `` | `the harness regression tests run in the harness repository — delete it from <레이어>` |

- 내장 기본값과 그 주석에 이 키가 없다. 이 리포 `harness.toml` 의 `script_tests = false` 줄과 그 위 주석을 지운다

## 9. 걷힌 파일을 부르던 하네스 안의 자리

| 자리 | 바뀐 뒤 |
|---|---|
| pre-push · post-commit | 7-5 |
| doctor `verification` 절 | 채운 옛 검증 스크립트(`script/verify-project.sh`)가 없으면 단계 실행(`verify --steps-only`)을 `QUIET_ENV()` 로 돌린다. 항목 이름은 `verification steps` 이고 detail 은 지금 그대로다(`passes` · `not set up — no commands yet` · `fails at <이름>` · `does not pass`). 옛 검증 스크립트 쪽 항목은 그대로다. 3-4 의 줄이 이 절에 더해진다 |
| doctor `--remote` 의 리뷰어 러너 점검 | 같은 CLI 의 `run-agent <역할> --check` 를 하위 프로세스로 부른다. `script/run-agent.py` 가 있는지 보지 않는다. 제한 시간 · 시작 알림 · 판정은 그대로다 |
| `harness fix verify` | 채운 옛 검증 스크립트가 있으면 그것, 없으면 단계 실행. 사용법 문구 `verify   run the verification again` |
| `verify_entry()` · `VERIFY_SCRIPT` | 옛 검증 스크립트를 가르는 함수만 남는다. 상수 `VERIFY_SCRIPT` 를 없앤다 |
| `harness schema` | `verify_script` 대신 `verify_command`(보일 명령 — `bash script/verify-project.sh` 또는 `<CLI> verify --steps-only`)와 `harness_cli`(4-1 의 값)를 낸다 |
| 드라이버의 역할 실행 | 역할 실행기 모듈을 부른다(#208 7-2 · 7-4). `script/run-agent.py` 를 보지 않는다 |
| 사용 기록 · 지표 · 클론 키 | 패키지 모듈만 쓴다(#213). `script/` 의 파일을 불러오지 않는다 |
| doctor `references` 의 `REF_OPTIONAL` | `script/run-lint-test.sh` 를 더한다 — 3절의 조건이 맞을 때만 생기는 파일이라 문서가 적어도 끊긴 참조가 아니다 |

## 10. UI

| 파일 | 바뀌는 것 |
|---|---|
| `src/ui/lib/doctor.js` | `verification` 의 `verification steps` 항목을 지금 `script/harness-verify.sh` 항목과 같은 제목 · 본문 · ▷ 조치(`verify`)로 옮긴다. `script/harness-verify.sh` 항목은 옛 고정 사본이 내므로 그대로 해석한다 |
| 같은 파일 | ▷ 조치의 보일 명령은 schema 의 `verify_command`, 그 키가 없는 옛 사본이면 `bash ${verify_script}` |
| 같은 파일 | `adapter <kind>` 미검증의 보일 명령은 `${harness_cli} forge-selftest <리뷰요청번호> <이슈번호>`. `harness_cli` 가 없는 옛 사본이면 지금 문구 |
| 같은 파일 | 새 항목 셋 — `config` 의 `` `<키>` names <경로> ``(제목 "설정이 없어진 하네스 스크립트를 부릅니다", 본문은 detail 의 새 표기로 바꾸라는 것과 바꾸기 전에는 생성이 멈춘다는 것), `config` 의 `` `verify.script_tests` is no longer read ``(제목 "더 쓰지 않는 설정 키가 있습니다", 본문 "하네스 회귀 테스트는 하네스 리포에서 돕니다. 이 키는 지워도 됩니다."), `verification` 의 `<경로> runs script/run-lint-test.sh`(제목 "CI 가 옛 검증 스크립트를 부릅니다", 본문은 그 줄을 detail 의 명령으로 바꾸면 하네스가 옛 스크립트를 걷는다는 것). 조치 명령은 없다 |
| `src/ui/components/FlowCanvas.js` | script 단계 입력의 자리표시 글 `script/<이름>.sh <인자>` → `{{HARNESS_CLI}} <명령> <인자>`. 공용 실행기 주석 `script/run-agent.py` → `harness run-agent` |

## 11. 문서

### 11-1. `script/README.md` 의 내용이 가는 곳

| 원래 절 | 가는 곳 |
|---|---|
| 부류 표 | `docs/workflow/README.md` "파일은 세 부류다" — 생성 행 `script/githooks/`(와 3절의 `script/run-lint-test.sh`), 관리 행에서 `script/` 를 뺀다 |
| 목록 | `docs/workflow/README.md` 새 절 "하네스 명령" — 절차 · 훅 · 사람이 부르는 하위 명령마다 하는 일 · 종료 코드 · 부르는 시점. 옛 목록의 내용을 명령 단위로 옮긴다(5-1 의 허용 명령, `carryover` · `rollback` · `forge` · `forge-selftest` · `forge-setup` · `bash-guard` · `git-hook` · `clone-key`). 옛 경로와의 대응표는 싣지 않는다 — README "업데이트" 가 갖는다 |
| 훅 활성화 | `docs/workflow/flow.md` "가드레일 층" 에 이미 있다 |
| 가드레일 층위 | `docs/workflow/flow.md` "가드레일 층" 에 이미 있다. allow 문단("`.claude/settings.json` 의 allow 는 승인 프롬프트만 없앤다 …")을 그 절에 옮기고 "관리 스크립트" 를 "하네스 명령" 으로 |
| 규칙 | `docs/workflow/changing.md` "하네스 자체를 바꾸는 것" 의 새 하위 절 "규칙" — 값은 하위 명령이 설정에서 읽는다(실행 방법은 실행 계획), forge 는 어댑터로만 부른다, 기계가 읽는 문자열은 `src/harness/format.py` 에 둔다, 리뷰 수행과 등록을 나눈다, 어댑터를 고치면 `harness forge-selftest` 를 실제 forge 로 돌린다, 가드를 고치면 테스트 케이스를 함께 늘린다, 사용 기록은 부수 효과다, 하네스가 대상 리포에서 하는 일은 하위 명령으로 두고 `script/` 에 스크립트를 더하지 않는다, 프로젝트 스크립트는 `script/project/` |

### 11-2. 고칠 문서

현재형 문서(README · `docs/workflow/` · 역할 계약 · 보호 문서)가 걷힌 파일을 이름으로 적을 때는 `script/` 를 붙인 백틱 경로로 적지 않는다 —
doctor `references` 가 없는 파일을 가리키는 참조로 짚는다. 파일 이름만 적거나 `script/<이름>` 꼴로 적는다.

| 문서 | 고칠 것 |
|---|---|
| `src/templates/generated/.ai/AI_AGENT.md` 3장 끝 | "프로젝트 자동화 스크립트는 `script/project/` 에 두고 `script/project/README.md` 표에 한 줄 추가한다. `script/` 의 나머지(`githooks/`)는 하네스가 생성한다." |
| 같은 원형 9장 | `script/README.md` 행 → `docs/workflow/README.md` 의 "하네스 명령" — 절차와 훅이 부르는 하네스 명령을 실행할 때 |
| 같은 원형 10장 | 관리 행 `.ai/templates/`, `docs/workflow/`. 생성 행에서 `script/harness.env` · `script/forge.sh` 를 빼고 `script/githooks/` 를 둔다 |
| 4-2 의 표 | 그 자리들 |
| `src/templates/managed/.ai/templates/docs-writer.md` | `script/README.md` 를 가리키는 줄 → `docs/workflow/README.md` |
| `src/templates/workflows/work/limits.md` | `script/README.md` → `docs/workflow/README.md`. 나머지 표기는 4-2 |
| `src/templates/owned/script/project/README.md` | "하네스 명령은 `docs/workflow/README.md` 의 '하네스 명령' 절에 있다. `script/` 바로 아래는 하네스가 생성하는 자리라 프로젝트 스크립트를 두면 하네스 갱신과 겹칠 수 있다" |
| `src/templates/managed/docs/workflow/README.md` | 구조 그림의 `script/githooks/ · harness.env` 줄을 `script/githooks/  훅 (생성)` 으로, `script/*.sh  배관 (관리)` 줄을 지운다. 11-1 |
| `src/templates/managed/docs/workflow/flow.md` | 흐름 그림 · 표의 스크립트 이름을 하위 명령으로. 검증 루프 그림의 `run-lint-test.sh` · `harness-verify.sh` → `{{HARNESS_CLI}} verify` · `verify --steps-only`. 검증 표의 `script_tests` 행을 지운다. 11-1 |
| `src/templates/managed/docs/workflow/changing.md` | 하네스 자체를 바꾸는 표의 `script/…` 행(표지 · 가드 · 역할 실행기 · 검증)을 패키지 모듈로. 옛 agent 절 예시는 4-4. 11-1 |
| `src/templates/forge/forge.md` · `src/templates/forge/github/review.md` | 4-2 |
| `src/templates/defaults.toml` | 4-4, 8절, `[permissions]` 주석의 "관리 스크립트" → "하네스 명령", `[commands]` · `[verify]` 주석 예시의 `script/check-deps.sh` → `script/project/check-deps.sh`. `[commands]` 머리 주석(#213 9 가 고친 "검증(`script/run-lint-test.sh`)이 실행할 때 읽는다")의 괄호 → `harness verify` |
| 이 리포 `harness.toml` | 8절, `[commands]` 머리 주석(위와 같은 괄호) |
| `src/templates/vendors.toml` 주석 | `usage_format` 의 "`run-agent.py` 가 출력을 받아" → "역할 실행기(`harness run-agent`)가 출력을 받아". `usage_parser` 는 #213 9, `hooks` 는 #210 10-2 가 이미 고친 문장 그대로다 |
| `src/test/fake-forge.sh` 머리글 | 끼우는 법은 `HARNESS_FORGE_FAKE` 하나다 |
| `harness help` 의 명령 설명(`COMMANDS`) | 걷힌 shim 을 가리키는 말을 지운다 — `forge` 의 `script/forge.sh calls this` |
| `README.md` "업데이트" | 4-5 의 대응표(옛 이름 → 새 표기), 이 갱신이 대상 리포에서 지우는 것(2-2), 걷힌 경로를 가리키는 설정 값에서 render 가 멈춘다는 것과 고치는 법(4-5 의 표, 이전 기본값 절이면 `harness fix legacy-work`), CI 파일의 `script/run-lint-test.sh` 를 바꾸면 그 shim 이 걷힌다는 것, `verify.script_tests` 를 지워도 된다는 것, `script/forge.sh` · `script/harness.env` 를 쓰던 프로젝트 스크립트는 `harness forge` · `harness vars` 로 바꾼다는 것, 프로젝트 문서에 남은 옛 경로는 doctor 의 `references` 가 짚는다는 것 |
| `README.md` "명령" 표 | 하위 명령 행의 "절차는 `script/…` 로 부른다" 문장을 지운다. `harness fix verify` 의 설명 |
| `README.md` "파일은 세 부류다" · "구조" | 11-1 과 같은 부류. 설치본 트리의 `script/` 가 `githooks/` · `project/` |
| `README.md` "`harness.toml` 이 정하는 것" | `verify.*` 행 — 검증(`harness verify` · pre-push · CI)이 실행할 때 읽는다. `script_tests` 를 뺀다. `permissions.allow_push` 행의 "관리 스크립트" → "하네스 명령" |
| `README.md` "검증" | 설치된 리포는 `.harness/bin/harness verify` 가 생성물 일치와 검증 단계를 잇는다 |
| `README.md` "지원 범위" | 자체 검사 예시를 `.harness/bin/harness forge-selftest …` 로 |
| `README.md` "언어" | 표지의 정본은 `src/harness/format.py` |
| `.ai/project/environment.md` | `HARNESS_TRACE_ID` 행의 "`script/metric.py` 가 준다" → "`harness run` 과 `harness span` 이 준다" |
| `.ai/project/review-checks.md` | 표지 행 → "표지(`src/harness/format.py`)를 바꿨으면 그것을 쓰는 역할 계약도 같은 변경에 있는가". 관리 스크립트 행 → "하위 명령을 더했으면 `docs/workflow/README.md` 의 '하네스 명령' 표에 한 줄이 있는가" |
| `docs/spec/70-generate-permission-allow-list.md` | 1절 · 3절 · 6절 · 7절을 현재형으로 — 첫 묶음은 5-1 의 하위 명령 규칙이고 허용 표시가 `COMMANDS` 에 있다, 제외 이유 표는 5-1 의 표, 가드레일 층위 표의 자리는 `docs/workflow/flow.md` |
| `docs/spec/58` · `59` · `60` · `62` · `63` · `64` · `71` · `96` | 걷힌 `script/<이름>` 을 현재형으로 적은 문장을 4-5 의 새 표기로. 58 의 doctor 출력 예시는 예시라 그대로 둔다 |
| `docs/spec/206-split-cli-into-package.md` 7-5 | "단위 테스트는 CLI 를 하위 프로세스로 띄우지 않는다" 뒤에 "하위 명령의 외부 계약 시험은 예외다 — 임시 하네스 루트에 설치한 CLI 를 하위 프로세스로 부른다(221 명세 12-1)". 스모크 테스트 행은 12-4 의 문장으로 |
| `docs/spec/207-layered-config.md` 2-2 | "이 명세 뒤의 이슈가 더하는 명령" 표에서 `bash-guard` · `git-hook` 을 "레이어를 읽지 않는다" 행에서 "공유 설정" 행으로 옮긴다(`git-hook` 은 commit-msg · pre-push 가 읽고 pre-commit 은 `check` 로 본다) |
| `docs/spec/216-org-presets.md` 5-2 | "설정을 읽지 않는 명령(`bash-guard` · `secret-scan` · `clone-key` 등)" 에서 `bash-guard` 를 뺀다. 명령별 동작 표에 행을 더한다 — `bash-guard` · `git-hook`: 어긋남 · 읽을 수 없음 모두 설정을 읽지 못했을 때처럼 막는다(221 명세 7-1 — 가드 2, commit-msg · pre-push 1) |
| 선행 명세 `docs/spec/209-…` · `210-…` · `211-…` · `212-…` · `213-…` · `215-…` · `217-…` | shim · 셸 생성물 · `script/<이름>` 표기를 현재형으로 적은 절의 머리에 그 내용을 이 명세의 어느 절이 걷었는지 한 줄을 두고, 본문의 현재형 서술을 그 결과로 고친다 |
| `docs/spec/README.md` | 이 명세의 행 |

## 12. 회귀 테스트

### 12-1. 셸 회귀 테스트의 이관

- 대상 리포에 하네스 회귀 테스트를 두지 않는다. 고정 사본의 변조는 매니페스트 해시(ADR 0015)가 잡는다
- `src/templates/managed/script/test-*.sh` 의 검사 줄은 `src/test/unit/` 의 Python 시험으로 옮긴다. 판정 기준은 그 검사 줄의 기대값(종료 코드 ·
  표준 출력 · 표준 오류 · 남긴 기록 · 페이크 상태)이다. 외부 계약을 보는 시험은 임시 하네스 루트에 설치한 CLI 를 하위 프로세스로 부른다.
  원격은 로컬 bare 리포, forge 는 `HARNESS_FORGE_FAKE` 의 페이크, forge CLI 는 PATH 앞 스텁이다
- 준비부(샌드박스 배치 · 페이크 주입)는 고칠 수 있다. shim 을 부르던 줄은 하위 명령을 부르는 줄이 되고, shim 자신의 형태 · 문구만 보던 줄은 지운다
- 지운 sh 단언과 옮긴 단언의 줄 대응표는 리뷰 요청 본문에 둔다
- 옮긴 뒤의 `src/test/unit/` 시험 모듈은 시험 대상마다 하나다 — 리뷰 루프 · 이월 이슈 · forge 라벨 준비 · forge-setup · 되감기 · 시크릿 스캔 · 명령 가드 ·
  task 동기화 · 사용 기록 · 착수 판정
- 옮긴 계약 시험은 임시 하네스 루트에 설치한 CLI 를 하위 프로세스로 부른다. #206 7-5 의 "단위 테스트는 CLI 를 하위 프로세스로 띄우지 않는다" 는
  내부 로직 시험의 규칙이고, 계약 시험이 그 예외다
- "Python 단위 테스트" 검증 단계의 `paths` 에 `src/bin/**` 를 더한다 — 계약 시험이 진입 스크립트를 거친다. `src/templates/**` · `src/test/**` 는 #206 이 둔다

### 12-2. `render-test.sh` — 바뀌는 것

- 설치한 리포의 `script/test-*.sh` 를 세어 돌리는 블록(UT-61)을 지운다
- `verify.script_tests false` 를 `set` 하던 준비부는 그 쌍을 뺀다
- shim 을 부르거나 shim 의 내용 · 문구를 보는 줄(#209 · #210 · #211 · #212 · #213 · #215 의 shim 블록과 설치된 `script/<이름>` 을 부르는 준비부)은
  12-1 의 규칙으로 하위 명령을 부르는 줄로 바꾸거나 지운다. 대응표는 리뷰 요청 본문에 둔다
- `script/harness.env` · `script/harness-verify.sh` · `script/forge.sh` 의 내용을 보던 줄은 같은 약속을 하위 명령의 행동으로 본다 — 예: 훅의 판정 값은
  설정을 바꾼 뒤 훅의 판정으로, 검증 단계 목록은 `verify --steps-only` 의 출력으로
- 옛 agent 절 케이스(#212 12-1 의 "옛 절" · `fix legacy-work`, #215 의 agent 모드 문서)는 6-3 에 맞춘다 — 이전 기본값 절은 render 가 6-2 · 6-3 의 안내로 멈추고,
  `run` 을 새 표기로 바꾼 절은 옛 조각으로 렌더된다

### 12-3. `render-test.sh` — 새 블록

번호는 기존 블록과 겹치지 않게 매긴다.

| 블록 | 확인하는 것 |
|---|---|
| 끝 상태 | 새로 설치한 리포의 `script/` 에 `githooks/` · `project/` 만 있다. 두 매니페스트에 `script/githooks/` 밖의 `script/` 줄이 없다 |
| 기존 설치본 갱신 | 옛 매니페스트의 `script/` 관리 · 생성 파일(손으로 고친 것 포함)이 render 뒤 없다. `script/hooks/` 가 없다. 매니페스트에 없는 `script/my.sh` 와 `script/project/` 는 바이트 그대로다. 사용자 파일이 든 `script/hooks/` 는 남는다. 2-4 의 note 가 `script/hooks/bash-guard.sh` 를 지운 render 에서만 나온다 |
| CI 가 부르는 동안 | 리포 루트 `.github/workflows/ci.yml` 에 `script/run-lint-test.sh` 줄을 두면 render 가 그 파일을 만들고 `.harness/generated` 에 둔다. 그 shim 이 `verify` 와 같은 종료 코드 · 출력을 낸다. 줄을 지우면 `check` 가 `left over` 를 내고, render 가 지운다. `.gitlab-ci.yml` 도 같다. 심볼릭 링크 CI 파일은 보지 않는다. doctor 가 3-4 의 줄을 낸다 |
| 서브프로젝트 | 하위 디렉터리 하네스 루트는 리포 루트의 CI 파일로 판정한다. 하네스 루트 안의 소유 골격만 부르면 만들지 않는다 |
| 스테이징 | CI 파일의 줄을 지워 스테이징하고 render 하지 않으면 `check --staged` 가 어긋남을 낸다 |
| 명령 표기 — 대상 리포 | 새로 설치한 리포의 `.ai/workflows/*.md` · `.claude/agents/*.md` · `.codex/agents/*.toml` · `.ai/templates/*.md` · `.claude/commands/*.md` · `CLAUDE.md` · `.ai/AI_AGENT.md` · `.ai/forge.md` 에 `.harness/bin/harness` 표기가 있고 4-5 의 걷힌 경로가 없다. 이 파일들과 `docs/workflow/*.md` 에 `{{HARNESS_CLI}}` 글자가 남지 않는다 |
| 명령 표기 — 소스 트리 복제 | 같은 파일들이 `src/bin/harness` 표기다 |
| 관리 파일의 다른 변수 | 관리 템플릿 사본에 `{{PROJECT_NAME}}` 을 넣으면 render 가 `unknown template variable` 로 멈춘다 |
| driver 의 `run` | 내장 기본값 `work` 의 첫 단계 `lock` 이 로컬 bare 원격에 잠금 ref 를 만들고 0 으로 끝난다 — 설치한 리포와 소스 트리 복제 둘 다. `run` 값에 `{{HARNESS_CLI}}` 가 그대로 남은 argv 로 띄우지 않는다 |
| 허용 목록 | 설치한 리포의 `permissions.allow` 에 `Bash(.harness/bin/harness <명령>:*)` 가 5-1 의 열 명령에 하나씩, 이름순으로 forge 규칙 앞에 있다. `Bash(script/` 로 시작하는 규칙이 없다. `carryover` · `rollback` · `forge` · `forge-selftest` · `forge-setup` · `bash-guard` · `git-hook` · `clone-key` 규칙이 없다. deny 의 `write-doc` 세 형태가 그대로다. 소스 트리 복제는 `Bash(src/bin/harness <명령>:*)` |
| 설정 값 사전 판정 | 프로젝트 `[workflows.<절차>]` 의 `run` 에 `script/review-mr.sh {mr}` 를 두면 render 가 2 와 6-2 의 문구로 멈추고 아무 파일도 바뀌지 않는다. `text` 의 `` `script/forge.sh` `` 와 `./script/review-mr.sh` 도 걸린다. `src/script/review-mr.sh` 와 `script/review-mr.sh.orig` 는 걸리지 않는다. `verify.checks` 값의 `use` 줄은 채운 경로다. `harness set` 이 걸리는 값을 남기면 설정 파일이 바이트 그대로다. doctor 가 6-4 의 줄을 낸다 |
| 이전 기본값 — #215 판 | #215 4-1 의 driver 기본값을 그대로 옮긴 `[workflows.work]` 로 render 하면 6-2 의 문구와 6-3 의 `harness fix legacy-work` 줄로 멈춘다. doctor 가 `workflows.work is a previous default` 를 낸다. `harness fix legacy-work` 가 그 절을 지우고 render 하며, 이어서 내장 기본값 `work` 가 새 표기로 렌더된다 |
| 옛 agent 절 | #212 10-1 의 agent 절 `[workflows.work]` 로 render 하면 6-3 의 `harness fix legacy-work` 줄이 나온다. `harness fix legacy-work` 가 0 으로 끝나고 driver 문서가 생긴다. `run` 만 새 표기로 바꾼 절은 옛 조각으로 렌더되고 `.claude/commands/work.md` 가 깔리며 그 안의 명령이 `.harness/bin/harness` 표기다 |
| `verify.script_tests` | 이 키가 든 설정의 render 결과가 키 없는 설정과 같다. render 가 8절의 note 를 내고 doctor 가 그 줄을 낸다. 문자열 값이어도 거부하지 않는다 |
| 가드 · 훅의 설정 | `script/harness.env` 없이 가드가 보호 브랜치 push 를 막는다. `branches.protected` 를 바꾸면 render 없이도 가드 · pre-push 판정이 따른다. `harness.toml` 을 깨면 가드가 2 와 7-1 의 문구, commit-msg · pre-push 가 1 과 그 문구. preset 사본의 내용을 lock 과 다르게 고쳐도 같다 |
| 훅의 루트 | 서브프로젝트의 `script/githooks/pre-commit` 이 그 서브프로젝트의 `harness.toml` 로 루트를 잡는다 |
| pre-push · post-commit | `script/run-lint-test.sh` 가 없는 설치본에서 pre-push 가 검증을 돌고 실패하면 `block pre-push verify` 와 함께 막는다. post-commit 을 켜면 커밋 뒤 `verify` 가 돈다 |
| doctor 검증 항목 | `verification steps` 가 `passes` · `not set up — no commands yet` · `fails at <이름>` 을 낸다. `harness fix verify` 가 단계를 돈다. schema 에 `verify_command` · `harness_cli` 가 있고 `verify_script` 가 없다 |
| 바이트코드 | 위 블록을 돈 뒤 리포 어디에도 `__pycache__` 가 없다 |

### 12-4. `src/test/unit/`

| 대상 | 보는 것 |
|---|---|
| 3-1 의 판정 | 줄 판정, 확장자 · 위치(`.github/workflows/sub/x.yml` 은 보지 않는다), 이번 render 가 생성하는 경로 제외, 읽지 못한 파일 |
| 6-1 의 판정 | 낱말 경계 표본(앞 · 뒤 문자), 키 셋, 레이어 표시, 절차 값과 검증 값의 `use` 차이, 내장 기본값에 걸리는 값이 없음 |
| 4-5 의 상수 | 2-2 의 기대 목록 경로가 모두 있다 |
| 허용 표시 | 표시가 있는 명령이 5-1 의 열 개와 같다 |
| 명령 표 스모크(`test_commands.py`, #206 7-5) | "명령 표 항목은 네 원소이고 첫 원소(통과 표시)는 `True` 또는 `None` 이다" 를 "명령 표 항목은 다섯 원소이고 첫 원소(통과 표시)와 셋째 원소(허용 표시)는 `True` 또는 `None` 이다" 로 바꾼다 |
| 판정 값 함수 | 같은 설정에서 `derive()` 의 값과 가드 · 훅이 쓰는 값이 같다 |
| 12-1 의 이관 시험 | 옮긴 sh 검사 줄 전부 |

### 12-5. UI — `src/ui/lib/doctor.test.js`

- `verification steps` 와 옛 `script/harness-verify.sh` 가 같은 제목 · 본문 · 조치로 옮겨진다
- 10절의 새 항목 셋이 원문과 다른 제목 · 본문으로 옮겨지고 조치가 없다. 다른 절의 같은 문구에는 붙지 않는다
- ▷ 조치의 보일 명령이 `verify_command` 를 쓰고, 그 키가 없으면 `bash ${verify_script}` 다. `forge-selftest` 의 보일 명령이 `harness_cli` 를 쓴다

회귀 테스트 전체(이 리포에서는 `src/bin/harness verify`)가 통과한다.

## 13. 보호 문서 개정 범위

분해의 task 하나가 이 범위 안에서 고친다. 적용 순서는 #206 → #207 → #208 · #209 · #210 → #211 → #212 → #213 → #215 다음이 이 명세다.
아래 문안은 #215 까지 반영된 문장 위에서 shim · 셸 생성물 · 옛 표기를 걷는다. 앞 명세가 더한 구절을 가리킬 때는 그 구절을 더한 명세를
괄호로 적는다. 표에 없는 문장은 앞 명세가 고친 그대로 둔다. 걷힌 파일을 이름으로 적을 때는 11-2 머리의 규칙을 따른다.

### 13-1. `.ai/project/architecture.md`

| 위치 | 반영할 사실 |
|---|---|
| "구성 요소" 의 CLI 패키지 항목 | #210 이 더한 "`script/harness.env` 읽기는 `src/harness/envfile.py`" 를 "가드 · 훅의 판정 값은 공유 설정에서 설정 값 해석 모듈이 계산한다" 로 바꾼다. #213 이 바꾼 표지 문장의 "— `script/harness-format.sh` 는 같은 값을 셸에 둔 표기다" 를 지운다. #213 이 더한 공용 모듈 나열은 그대로 둔다 |
| "구성 요소" 의 대상 리포 `script/` 항목 | 항목 전체를 바꾼다(#209 · #210 · #211 · #212 · #213 · #215 가 더한 shim 나열을 모두 대신한다): 대상 리포의 `script/` — git 훅(`githooks/`, CLI 를 찾아 `git-hook <훅>` · `verify` 로 넘기는 생성 shim)과 프로젝트 소유 `script/project/`. 리포 루트의 CI 파일이 `script/run-lint-test.sh` 를 부르는 동안에는 그 shim(`verify` 로 넘긴다)도 생성된다. 하네스가 대상 리포에서 하는 일은 CLI 하위 명령이고, 에이전트 · 절차 · 설정은 하네스 루트 종류의 CLI 경로(`{{HARNESS_CLI}}` — 대상 리포 `.harness/bin/harness`, 소스 리포 `src/bin/harness`)로 부른다. 하네스는 `script/project/` 안의 `README.md` 만 없을 때 깐다 |
| "구성 요소" 의 `src/templates/` 항목 | "`managed/`(그대로 복사)" → "`managed/`(복사 — `{{HARNESS_CLI}}` 만 하네스 루트의 값으로 채운다)" |
| "구성 요소" 의 `src/test/render-test.sh` 항목 | #209 가 더한 "셸 호출부에는 `script/forge.sh` 자리에 덮어 끼우고, CLI 에는 `HARNESS_FORGE_FAKE` 로 끼운다" → "`HARNESS_FORGE_FAKE` 로 끼운다". #206 이 더한 `src/test/unit/` 문장 끝에 더한다: 하위 명령의 외부 계약 시험도 여기 있고, 그 시험은 임시 하네스 루트에 설치한 CLI 를 하위 프로세스로 부른다 |
| "데이터 흐름" 의 렌더 | 생성 파일 괄호에서 `script/harness.env` · `script/harness-verify.sh` 를 뺀다. `script/githooks/` 뒤에 "리포 루트 CI 가 부를 때만 `script/run-lint-test.sh`" 를 더한다. 항목 끝에 더한다: 관리 파일은 깔 때 `{{HARNESS_CLI}}` 만 하네스 루트의 값으로 채운다 |
| "데이터 흐름" 의 절차 실행 | 셸 구절 셋을 고친다. ① #211 이 두고 #212 가 옮긴 괄호의 "shim `script/work-preflight.sh` — " · "shim `script/review-mr.sh` — " 를 지운다(괄호의 나머지는 그대로) ② #213 의 "절차 문서는 shim `script/run-agent.py` 로 부른다" → "절차 문서는 `{{HARNESS_CLI}} run-agent` 로 부른다" ③ #212 의 "단계는 하위 명령을 `script/<이름>.sh` shim 으로 부른다" → "단계는 하위 명령을 `{{HARNESS_CLI}} <명령>` 으로 부른다". #215 가 더한 착수 잠금 문장은 그대로다 |
| "데이터 흐름" 의 forge | #209 의 "셸 스크립트 → `script/forge.sh`(shim) → `harness forge <함수>` →" 를 "에이전트 · 사람 → `harness forge <함수>` →" 로. 같은 항목에 더한다: 하위 명령은 어댑터를 패키지 안에서 부른다 |
| "데이터 흐름" 의 실행 지표 | #213 이 바꾼 "스팬 기록(`harness span` — start · end · wrap · step, 셸에서는 shim `script/metric.py`)" 에서 ", 셸에서는 shim `script/metric.py`" 를 지운다. #207 이 더하고 #213 이 고친 지표 설정 문장은 그대로 둔다 |
| "데이터 흐름" 의 가드 · 훅 | #210 의 "`script/harness.env` 의 값으로 판정" → "하네스 루트의 공유 설정으로 판정(render 와 같은 레이어 해석 · preset 대조)" |
| "신뢰 경계" | 새 항목: 리포 루트의 CI 파일 — `script/run-lint-test.sh` 를 부르는지만 읽는다. 쓰지 않고 내용을 출력에 옮기지 않는다. 모노레포면 하네스 루트 밖의 파일을 읽는다 |
| "새 코드를 둘 곳" 의 새 forge | #209 의 "실제 forge 로 `script/forge-selftest.sh` 를 통과하기 전까지" → "실제 forge 로 `harness forge-selftest` 를 통과하기 전까지" |
| "새 코드를 둘 곳" 의 새 forge 계약 함수 | #209 의 "셸 shim `script/forge.sh` 는 render 가 함수 표에서 만든다" → "`.ai/forge.md` 의 함수 표는 render 가 함수 표에서 만든다" |
| "새 코드를 둘 곳" 의 새 관리 스크립트 | #213 이 바꾼 항목 전체를 바꾼다: 하네스가 대상 리포에서 하는 일 → CLI 하위 명령(`COMMANDS` 한 줄과 명령 모듈)과 `docs/workflow/README.md` 의 "하네스 명령" 표 한 줄. 절차가 정상 경로에서 부르는 명령이면 `COMMANDS` 의 허용 표시를 `True` 로 둔다. 대상 리포 `script/` 에 스크립트를 두지 않는다 |
| "새 코드를 둘 곳" 의 리뷰 루프 | #211 의 "`script/` 의 shim 에는 로직을 넣지 않는다" 를 지운다 |
| "새 코드를 둘 곳" 의 새 가드 | #210 의 "+ `test-bash-guard.sh` 케이스" → "+ `src/test/unit/` 의 가드 계약 시험", "판정에 쓰는 값은 `script/harness.env` 로 받는다" → "판정에 쓰는 값은 설정 값 해석의 판정 값 함수에서 받는다" |
| "새 코드를 둘 곳" 의 표지 | #213 의 "셸 표기 `script/harness-format.sh` 를 같은 변경에서 맞춘다" 를 지운다 |
| "새 코드를 둘 곳" 의 새 회귀 테스트 | 끝에 더한다: 하위 명령의 외부 계약 시험도 `src/test/unit/` 에 둔다 |
| "계층과 의존 방향" 의 규칙 값 항목 | 항목 전체를 바꾼다(#207 의 ①②③, #209 의 forge 덧문장, #213 의 덧문장을 모두 대신한다): 규칙 값은 공유 설정에서 생성물로 내려간다. 개인 레이어 값은 생성물에 들어가지 않는다. 대상 리포의 훅 · 가드와 하위 명령은 값을 하드코딩하지 않고 공유 설정을 설정 로더로 직접 읽는다 — forge 선택도 `harness forge` 가 공유 설정에서 읽는다. 역할의 실행 방법과 지표 설정은 실행할 때 실효 설정에서 `run_plan()` 으로 같은 프로세스 안에 계산한다 |
| "계층과 의존 방향" 의 forge 항목 | #209 의 "— 셸 관리 스크립트는 `script/forge.sh` 의 함수로, CLI 는 `harness.forge` 로" → "— 하위 명령은 `harness.forge` 로, 에이전트와 사람은 `harness forge <함수>` 로" |
| "계층과 의존 방향" 의 하위 명령 항목 | #211 이 더한 "`script/harness.env` 와 `harness run-plan` 을 거치지 않는다" → "`harness run-plan` 을 거치지 않는다" |
| "계층과 의존 방향" 의 클론 키 항목 | #213 의 "`script/_clone_key.py` 는 그 shim 이다" 를 지운다 |
| "검사하지 않는 것" | 셸 스크립트 항목 "대상 리포에 깔리는 셸 스크립트는 정적 검사 도구를 거치지 않는다. 회귀 테스트(`script/test-*.sh`)만 있다" → "대상 리포에 깔리는 셸 파일은 git 훅 shim(과 조건부 `script/run-lint-test.sh`)뿐이고 정적 검사 도구를 거치지 않는다". 고정 사본 항목의 "pre-commit · `run-lint-test.sh` · CI 의 검사" → "pre-commit · `harness verify` · CI 의 검사" |

### 13-2. `.ai/project/glossary.md`

| 위치 | 반영할 사실 |
|---|---|
| "용어" 의 `관리 파일` | 하네스가 복사해 두는 파일. 하네스 CLI 표기(`{{HARNESS_CLI}}`)만 하네스 루트의 값으로 채운다. 갱신이 덮는다 |
| "용어" 새 행 `하네스 CLI 표기` | render 가 하네스 루트 종류로 고르는 CLI 경로 — 대상 리포 `.harness/bin/harness`, 소스 리포 `src/bin/harness`. 템플릿과 절차 단계 값에 `{{HARNESS_CLI}}` 로 적는다 |
| "용어" 의 `shim` (#209 행) | CLI 를 찾아 하위 명령에 넘기기만 하는 얇은 셸 파일. git 훅(`script/githooks/*`)과, 리포 루트 CI 가 부르는 동안의 `script/run-lint-test.sh` 다 |
| "용어" 의 `실행 계획` (#207 · #211 · #213 이 고친 행) | 행 전체를 바꾼다: 역할마다 무엇을 어떻게 띄우는지 실효 설정에서 실행 시점에 해석한 표. `harness run-plan` 이 내고, 역할 실행기(`harness run-agent`) · 리뷰(`harness review`) · 스팬 기록(`harness span`) · 드라이버는 같은 함수(`run_plan()`)로 같은 프로세스에서 계산한다. 파일로 남기지 않는다 |
| "용어" 의 `자체 검사` (#209 행) | "(`harness forge-selftest`, shim `script/forge-selftest.sh`)" → "(`harness forge-selftest`)" |
| "용어" 의 `forge 페이크` (#209 행) | "셸 호출부에는 `script/forge.sh` 자리에, CLI 에는 `HARNESS_FORGE_FAKE` 로 끼운다" → "`HARNESS_FORGE_FAKE` 로 끼운다" |
| "용어" 의 `task 이슈` · `착수 판정` · `회차 라벨` (#211 행) | 괄호의 "(shim `script/…`)" 를 지운다 — `harness sync-tasks` · `harness preflight` · `harness review` 만 남는다 |
| "용어" 의 `판정 명령` (#212 행) | "`harness work-check`(shim `script/work-check.sh`)" → "`harness work-check`" |
| "용어" 의 `이월 이슈` (#213 행) | "(절차는 `script/create-carryover-issue.sh` 로 부른다)" 를 지운다 |
| "용어" 의 `표지` (#213 행) | ", 셸 표기는 `script/harness-format.sh`" 를 지운다 |
| "폐기된 별칭" 의 `script/verify-project.sh` 행 | 정식 이름 칸 → `harness.toml` 의 `[commands]` · `[verify]` (검증 `harness verify` 가 실행할 때 읽는다) |
| "폐기된 별칭" 새 행 | `script/<이름>` (관리 스크립트와 그 shim) → `{{HARNESS_CLI}} <명령>`. 이름마다의 대응은 README "업데이트" 의 표 |
| "폐기된 별칭" 새 행 | 셸 생성물 `harness.env` · `forge.sh` (`script/` 아래) → 공유 설정 · `harness forge <함수>` |
| "폐기된 별칭" 새 행 | 생성 검증 스크립트 `harness-verify.sh` (`script/` 아래) → `harness verify --steps-only` |
| "폐기된 별칭" 새 행 | `verify.script_tests` · "하네스 스크립트 회귀" 단계 → 없음. 하네스 회귀 테스트는 소스 리포에서 돈다 |
| "폐기된 별칭" 새 행 | 스크립트 목록 `README.md` (`script/` 아래) → `docs/workflow/README.md` 의 "하네스 명령" 절 |

### 13-3. `.ai/project/testing.md`

| 위치 | 반영할 사실 |
|---|---|
| "무엇을 어느 수준으로 검증하나" 의 관리 스크립트 항목 | 항목 전체를 바꾼다(지금 문장과 #213 이 더한 계약 테스트 문장을 대신한다): 하위 명령의 외부 계약(인자 · 표준 출력 · 종료 코드 · 남기는 기록)은 `src/test/unit/` 의 계약 시험이 임시 하네스 루트에 설치한 CLI 를 하위 프로세스로 불러 본다(리뷰 루프 · 이월 이슈 · task 동기화 · 되감기 · 시크릿 스캔 · 가드 · 사용 기록 · 착수 판정 · forge 라벨 준비 · forge-setup). 대상 리포에는 하네스 회귀 테스트가 가지 않는다 — 고정 사본의 변조는 매니페스트 해시가 잡는다 |
| 같은 절의 Python 단위 테스트 항목 (#206 9절이 더한 것) | "CLI 를 하위 프로세스로 띄우지 않고 패키지 모듈을 불러 함수를 부르며" 앞에 "내부 로직 시험은" 을 둔다. 끝 문장 "셸 테스트(`render-test.sh` · `script/test-*.sh`)는 외부 계약(인자 · 표준 출력 · 종료 코드)을 본다" → "외부 계약(인자 · 표준 출력 · 종료 코드 · 남기는 기록)은 `render-test.sh` 와 위 항목의 계약 시험이 본다". #210 이 덧붙인 "가드 경로가 설정 해석 · 생성 · 지표 모듈을 불러오지 않는지" → "가드 경로가 생성 · 지표 · 사용 기록 모듈을 불러오지 않는지" |
| "외부 의존을 어떻게 다루나" 의 forge 항목 (#209 가 고친 것) | "셸 호출부에는 `script/forge.sh` 자리에 덮어 끼우고, CLI · Python 쪽 호출에는 `HARNESS_FORGE_FAKE` 로 끼운다" → "CLI · Python 쪽 호출에 `HARNESS_FORGE_FAKE` 로 끼운다". "`script/forge-selftest.sh` 로" → "`harness forge-selftest` 로" |

### 13-4. `.ai/project/scope.md`

바뀌지 않는다 — #215 까지 고친 문장에 shim · 셸 생성물 서술이 없다.

## 14. 이 명세 밖

- 옛 agent `work` 경로 — 옛 단계 조각 다섯(`work/sync-tasks.md` · `implement.md` · `review.md` · `branch.md` · `limits.md`), `/work` 관리 커맨드,
  이전 기본값 목록과 그 doctor 항목, `harness fix legacy-work`. 이 이슈는 그 경로를 걷지 않는다. 표기만 4절대로 바뀐다
- `script/harness.plan.json` 걷기 — #207
- CI 게이트를 생성물로 바꾸는 일 — #217. 이 명세는 그것이 들어와 있을 때의 `{{CI_VERIFY}}` 값과 doctor 줄만 정한다 (3-4 · 3-5)
- 이미 깔린 소유 CI 파일 · 소유 원형 사본(`script/project/README.md` 등)의 수정 — 프로젝트 것이다(ADR 0002)

## 15. 결정 기록

결정 기록: 없음 — 이 명세는 ADR 0002 · 0013 · 0015 · 0017 의 Decision 을 적용한다. shim 을 남기는 조건과 설정 값의 갱신 규칙은 이행 절차이고
소유 파일의 분류를 바꾸지 않는다.

## 16. 한계

- 리포 루트 CI 의 판정은 문자열이 줄에 있는지만 본다. 주석 줄에 든 문자열도 부르는 것으로 보고, 다른 이름으로 감싸 부르는 호출은 보지 못한다
- 모노레포에서 리포 루트 CI 파일이 어느 서브프로젝트의 `script/run-lint-test.sh` 를 부르는지 가르지 않는다. 문자열이 있으면 모든 서브프로젝트가 그 shim 을 남긴다
- 소유 CI 파일을 고치지 않는 설치본에는 `script/run-lint-test.sh` 가 계속 생성된다. doctor 가 짚을 뿐 끝 시점이 없다
- 기존 설치본의 소유 원형 사본 `script/project/README.md` 는 옛 `script/README.md` 를 가리킨 채 남는다. doctor 의 `references` 가 짚는다
- 가드가 Bash 호출마다 설정 레이어를 읽고 preset 사본을 lock 과 대조한다. 그 지연은 재지 않았다
- preset 사본(`.harness/preset/`)이나 lock 을 손으로 고쳐 대조가 어긋나면 명령 가드가 에이전트의 Bash 호출을 모두 막고, commit-msg · pre-push 도
  거부한다(7-1). `harness pull` 이나 사본 · lock 을 되돌리는 일은 사람이 셸에서 한다
- 프로젝트가 옮겨 둔 `[workflows.review-loop]` 는 이전 기본값 목록의 대상이 아니다. 그 `run` 의 `script/review-mr.sh` · `script/work-check.sh` 는
  6-2 로 render 를 멈추고, 값을 새 표기로 바꾸거나 `harness.toml` 에서 그 절을 지워 내장 기본값을 쓴다(하네스 기본 절차라 `harness steps --delete` 는 받지 않는다). `harness fix legacy-work` 는
  `review-loop` 를 다루지 않는다
- 릴리스를 건너뛴 설치본은 shim 기간을 거치지 않는다. 그 영향은 설정 값(6절 — render 가 멈춘다), 소유 CI(3절 — shim 이 남는다), 이미 떠 있는 세션의 훅
  명령(2-4)에 모인다
- 프로젝트 스크립트가 옛 `script/forge.sh` · `script/harness.env` 를 source 하던 경우는 하네스가 찾지 않는다. 문서화된 사용처가 없고, 갱신 안내(11-2 README "업데이트")가 바꿀 명령을 적는다
