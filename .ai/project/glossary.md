<!--
이 파일은 프로젝트가 소유한다. 하네스 갱신이 덮지 않는다.
같은 것을 다르게 부르는 표기가 있으면 여기서 하나로 정한다. 없으면 없다고 적는다.
-->

### 용어

| 표기 | 뜻 |
|---|---|
| 하네스 | 설정 하나에서 생성되는 규칙·훅·권한·에이전트 정의·절차 한 벌. 이 리포가 만드는 것 |
| 하네스 루트 | `harness.toml` 이 있는 디렉터리. 리포 루트가 아니어도 된다(모노레포) |
| 소스 리포 | 이 리포. `src/bin/harness` 와 `src/templates/` 를 갖고, 자기 자신은 고정하지 않고 자기 것으로 돈다 |
| 고정(pin) | 대상 리포가 `.harness/` 에 설치 시점의 하네스 사본을 두고 그 버전으로만 도는 것 |
| 생성 파일 | `harness.toml` 에서 나오는 파일. 고치지 않고 `render` 로 다시 만든다 |
| 관리 파일 | 하네스가 그대로 복사해 두는 파일. 갱신이 덮는다 |
| 소유 파일 | 프로젝트 것. 없을 때만 깔고 갱신이 건드리지 않는다 (`.ai/project/` · `docs/spec/README.md` · CI 설정) |
| 보호 문서 | 에이전트가 근거로 읽는 소유 파일(scope · architecture · glossary · testing · `roles/` · `workflows/`). 권한과 가드가 쓰기를 막고, 사람이 지시한 턴에만 고친다 |
| 매니페스트 | 지난 렌더가 무엇을 깔았는지 적은 목록(`.harness/generated` · `.harness/managed`). 정리와 제거의 근거 |
| 정본 | 어떤 값·규칙을 고칠 때 손대는 유일한 자리. 규칙 값은 `harness.toml`, 프로젝트 사실은 `.ai/project/` |
| 렌더 | 설정과 프로젝트 사실에서 생성 파일을 만드는 일 (`harness render`) |
| 역할 | 절차의 한 단계를 맡는 에이전트 (requirement-analyzer · spec-writer · planner · developer · code-reviewer · docs-writer · security-guard) |
| 역할 계약 | 역할이 무엇을 판단하고 무엇을 내는지 정한 문서 (`.ai/templates/<역할>.md`). 자기 러너를 모른다 |
| 역할 선언 | 역할 어댑터 본문의 frontmatter (`src/templates/agents/<역할>.md`). `distinct_from` · `headless` · `entry` · `about` |
| 러너 | 역할을 실제로 도는 주체. `inproc`(오케스트레이터의 서브에이전트) 또는 CLI(`claude` · `codex`) |
| 오케스트레이터 | 절차를 실제로 도는 세션의 CLI (`harness.orchestrator`) |
| 실행 계획 | 역할마다 무엇을 어떻게 띄우는지 적은 생성물 (`script/harness.plan.json`). `run-agent.py` 가 읽는다 |
| 벤더 선언 | 에이전트 CLI 등록부 (`src/templates/vendors.toml`). 실행 명령은 여기만 갖는다 |
| 절차(워크플로) | 역할·스크립트·게이트를 순서로 엮은 것. `.ai/workflows/<절차>.md` 로 생성된다 |
| 조각(fragment) | 절차 한 단계의 본문 원형 (`src/templates/workflows/<절차>/<id>.md`) |
| 게이트 | 사람의 결정·승인을 기다리는 절차 단계 |
| 요구사항 이슈 | 사람이 만드는 상위 이슈. 분해가 있으면 브랜치·리뷰 요청의 단위 |
| task 이슈 | 승인된 분해에서 `sync-task-issues.sh` 가 만드는 하위 이슈. 커밋의 단위 |
| 분해 | 명세를 task 로 쪼갠 문서 (`docs/plan/<번호>/`). 원격 통합 브랜치에 있으면 승인된 것 |
| 착수 판정 | `work-preflight.sh` 가 원격 기준으로 내리는 판정 — `plan` · `standalone` · 착수 불가 |
| 리뷰 요청 | GitHub 의 PR, GitLab 의 MR. 문서에서는 forge 에 중립적으로 이렇게 부른다 |
| 회차 라벨 | 리뷰 요청에 붙는 `<prefix>:<N>` 라벨. `review-mr.sh` 만 올린다 |
| 이월 이슈 | 범위 밖으로 넘긴 지적을 담는 이슈. `create-carryover-issue.sh` 가 만든다 |
| 표지 | 기계가 읽는 문자열 (`script/harness-format.sh`). `REVIEW_VERDICT` · `harness:allow-secret` 등 |
| forge | 이슈 추적기와 코드 리뷰 호스트를 묶어 부르는 말 (GitHub · GitLab · Jira) |
| 어댑터 | forge 명령을 감싸는 스크립트(`script/forge/<kind>.sh`), 또는 역할 계약을 CLI 별 형식으로 옮긴 정의 파일(`.claude/agents/` · `.codex/agents/`) |
| 자체 검사 | 어댑터가 계약을 지키는지 실제 forge 로 확인하는 것 (`script/forge-selftest.sh`) |
| 등록부 | 설치된 프로젝트와 기기의 도구 기록 (`~/.harness/`). UI 가 이것으로 프로젝트를 전환한다 |
| 스팬 · 트레이스 | 실행 지표의 단위. 명령·단계·역할·스크립트 한 번이 스팬, 한 실행의 스팬 묶음이 트레이스 |
| 결정 기록 | 되돌리기 비싼 결정의 "왜" (`docs/adr/`, Nygard 방식) |

### 폐기된 별칭

| 옛 표기 | 정식 이름 |
|---|---|
| 루트 `harness.toml` (대상 리포로 복사되는 기본값) | `src/templates/harness.toml`. 루트의 것은 이 리포 자신의 설정 |
| `.harness/harness.toml` (설치본의 기본 설정) | `.harness/templates/harness.toml` |
| `bin/` · `templates/` · `ui/` · `test/` (리포 루트) | `src/` 아래의 같은 이름 |
| `script/verify-project.sh` (손으로 쓰던 검증 스크립트) | `harness.toml` 의 `[commands]` · `[verify]` 에서 생성되는 `script/harness-verify.sh` |
| `.ai/project/commands.md` (옛 명령 문서) | `harness.toml` 의 `[commands]` |
| 단계의 `kind` | 단계의 `type` (`workflows.<절차>.steps`) |
| `AGENTS` 표 · `SCRIPT_ROLES` (CLI 안의 벤더·역할 분기) | 벤더 선언(`vendors.toml`)과 역할 선언(frontmatter) |
| task 라벨 `new` | `Task` (`issues.labels.task`) |
