# script/

하네스의 자동화 스크립트. **AI 가 아니라 셸과 git 이 실행한다.**

세 부류가 섞여 있다. 고치기 전에 어느 부류인지 본다.

| 부류 | 파일 | 고치는 법 |
|---|---|---|
| **관리** | 아래 표의 대부분 | 하네스 것이다. 갱신이 덮으므로 하네스 리포에서 고친다 |
| **생성** | `harness.env` · `harness-verify.sh` · `forge.sh` · `githooks/*` | 고치지 않는다. `harness.toml` 을 고치고 `harness render` |
| **소유** | `project/` | 프로젝트 것이다. 하네스 갱신이 건드리지 않는다. 표는 `script/project/README.md` 에 적는다 |

## 목록

| 스크립트 | 용도 | 호출 시점 |
|---|---|---|
| `run-lint-test.sh` | 검증 일괄 — 생성물 일치 + `harness-verify.sh`. `--commit` 이면 push 단계를 뺀다 | 커밋 전 `--commit`, pre-push 훅, CI (`verify.post_commit` 이면 post-commit 훅도) |
| `metric.py` | 실행 지표 기록 — 명령·단계·에이전트·스크립트를 스팬으로 남긴다. `wrap -- <명령>` 은 출력·종료 코드를 바꾸지 않는다. 보관·로테이션은 `harness.toml` 의 `[metrics]` | 스크립트·`run-agent.py`·`harness run` |
| `run-agent.py` | CLI 러너 역할 하나를 실행 계획(`harness.plan.json`)대로 한 번 돌리는 공용 실행기. `--check` 는 실행하지 않고 러너 설치·로그인만 확인한다 — 0=준비됨, 2=실행 불가, 3=미로그인, 4=확인 못 함 | 절차의 CLI 러너 단계, `harness doctor --remote` |
| `harness-verify.sh` | **생성.** `harness.toml` 의 `[verify]` — 스크립트 회귀 → 검사 → 코드 검사 → 테스트. 단계마다 통과한 작업 트리를 기억해 경로가 안 바뀐 단계는 건너뛴다. 0=통과, 1=실패, 3=명령을 아직 정하지 않음 | `run-lint-test.sh` |
| `work-preflight.sh` | 착수 판정 — 이슈 → 열린 리뷰 요청 → 분해 → 명세 순으로 확인하고 `plan`/`standalone` 출력. 0=가능, 1=불가(닫힌 이슈 포함), 2=실패(이슈 조회 실패 포함) | 착수 전과 위임 직전 |
| `check-open-mrs.sh` | 이슈에 연결된 **열린** 리뷰 요청 조회. 0=없음, 1=있음, 2=실패 | `work-preflight.sh` 의 첫 검사 |
| `sync-task-issues.sh` | 원격 통합 브랜치의 분해를 읽어 **없는 task 이슈만 생성.** 머지 전이면 중단(승인 게이트). 동시 실행은 잠금으로 막고, 막지 못한 경합은 만들기 전에 잡는다. `--dry-run` | 착수 단계(분해가 있을 때만) |
| `test-secret-scan.sh` | 시크릿 스캔 회귀 테스트 — 무엇을 잡고 무엇을 지나가는지 | `run-lint-test.sh` |
| `test-rollback-work.sh` | 되감기 회귀 테스트 — 무엇을 닫고 무엇을 남기는지 | `run-lint-test.sh` |
| `test-sync-task-issues.sh` | 동기화 회귀 테스트 — 분해 절이 생성 호출의 어느 인수로 가는지. 로컬 bare 원격과 페이크 어댑터로만 돈다 | `run-lint-test.sh` |
| `forge-setup.sh` | 설정의 이슈 라벨(`issues.labels`)을 트래커에 미리 만든다. **원격 쓰기** — 이미 있는 라벨은 그대로 둔다. 0=준비됨, 2=트래커를 쓸 수 없거나 라벨을 만들지 못함 | `harness forge-setup` (사람이 1회) |
| `test-forge-setup.sh` | 원격 라벨 준비 회귀 테스트 — 설정의 라벨을 넘기고 빈 라벨을 건너뛰며 실패를 2 로 알리는지. 페이크 어댑터로만 돈다 | `run-lint-test.sh` |
| `test-work-preflight.sh` | 착수 판정 회귀 테스트 — 열린 이슈는 판정 그대로, 닫힌 이슈·조회 실패에서는 리뷰 요청 조회 없이 멈추는지. 로컬 bare 원격과 페이크 어댑터로만 돈다 | `run-lint-test.sh` |
| `test-forge-labels.sh` | 어댑터의 라벨 준비 회귀 테스트 — GitHub 이 만들지 못한 라벨을 삼키지 않고 그때 이슈·리뷰 요청을 바꾸지 않는지, `tracker_labels_ensure` 의 빈 인수·무인수, Jira 의 무호출. CLI 스텁으로만 돈다 | `run-lint-test.sh` |
| `secret-scan.sh` | 커밋에 **새로 들어오는** 자격증명을 찾는다. python3 만 쓴다. `--staged` | pre-commit 훅, 수동 |
| `rollback-work.sh` | 이슈 하나에 대해 하네스가 만든 것을 되감는다 — 리뷰 요청·task 이슈를 닫고 로컬 브랜치를 지운다. **요구사항 이슈와 원격 브랜치는 남긴다.** 확인을 받는다. `--dry-run`·`--yes` | 잘못 돈 `work` 를 치울 때 |
| `create-carryover-issue.sh` | 범위 밖으로 넘긴 지적의 이월 이슈 생성 — 본문 검사 뒤 원본에서 필수 필드 상속. `--dry-run` | 구현자가 이월처를 만들 때 |
| `review-mr.sh` | 리뷰 입력을 묶어 리뷰 도구에 넘기고 `post-review.sh` 로 등록. **회차 라벨을 스스로 올리고 상한을 강제.** 0=PASS, 1=수정 필요, 2=실패, 3=상한 | 리뷰 단계 |
| `post-review.sh` | 리뷰어의 판정 데이터를 검증해 등록(인라인 + 요약)하고 **발견 등급 집계로 판정.** 0=PASS, 1=수정 필요, 2=실패, 3=한 파일 반복 | `review-mr.sh` |
| `_review.py` | 리뷰 루프의 파이썬 전부 — 판정 데이터 검증·집계, 등록 댓글(요약·인라인) 렌더링, 리뷰 입력 맥락 구성, 회차 라벨 계산. `python3 script/_review.py <하위명령>` 으로만 실행한다. 표지는 환경의 `FMT_*` 를 읽는다 | `review-mr.sh` · `post-review.sh` |
| `_clone_key.py` | 클론 키 — 이 기기에서 하네스 루트 하나를 가리키는 값을 git 공통 디렉터리와 리포 안의 위치로 계산하고, 설정 값의 `{clone}` · `{project}` 를 그 키로 푼다. `python3 script/_clone_key.py expand <값>` — 0=푼 값 한 줄, 1=인자 없음·계산 실패 | `metric.py` · `usage-log.sh` · `usage-report.sh` · `harness` CLI |
| `harness-format.sh` | **기계가 읽는 문자열의 정본.** 쓰는 쪽(계약·양식)과 읽는 쪽(파서)이 같은 값을 보게 한다 | 리뷰·이슈 스크립트 |
| `forge/_common.sh` | forge 어댑터 **계약**과 기본 구현 | `forge.sh` |
| `forge/<kind>.sh` | forge 어댑터 구현. CLI 이름과 응답 형태를 여기서만 안다 | `forge.sh` |
| `forge-selftest.sh` | **어댑터가 계약을 지키는지 실제 forge 로 확인.** 읽기 13종이 기본이고, 흔적이 남는 3종은 `--write`, 되돌릴 수 없는 1종은 `--create-issue` 로 따로 켠다 | 새 forge 를 쓰기 전 1회 |
| `usage-vocab.sh` | 사용 기록 어휘의 정본 — 허용 이벤트·출처·라벨과 키별 값 형식 | 기록·집계 |
| `usage-log.sh` | 하네스 사용 기록 — 가드 차단·착수 판정·리뷰 회차. **명령 내용·본문·사람 이름은 남기지 않는다.** 항상 0 으로 끝난다 | 훅, 판정, 리뷰 |
| `usage-report.sh` | 사용 기록 집계 → 마크다운 표 + `KEY=VALUE`. 0=출력, 2=실패 | 회고 |
| `hooks/bash-guard.sh` | 도구 호출 JSON 에서 명령을 꺼내 가드를 돌린다 — **실행 전에** 판정. 0=통과, 2=차단 | Claude Code `PreToolUse(Bash)` |
| `hooks/_guards.sh` | 가드 함수 — 보호 브랜치 push·commit, force push·원격 삭제, 훅 우회, 보호 문서의 셸 수정 | `bash-guard.sh` |
| `test-*.sh` | 회귀 테스트. 원격을 부르지 않는다 | `run-lint-test.sh` |

## 훅 활성화

`harness install` 이 `core.hooksPath` 가 비어 있으면 켠다. 다른 값이나 `.git/hooks/` 의 자기 훅이 있으면 두고
켜는 명령만 알린다. 이미 설치된 리포를 새로 클론했으면 `harness doctor` 가 알려 주는 명령으로 켠다.

```bash
git config core.hooksPath script/githooks   # 모노레포면 packages/api/script/githooks 처럼 서브프로젝트 경로를 앞에 붙인다
```

이 설정이 없으면 커밋·push 검사가 **조용히 건너뛰어진다.**

## 가드레일 층위

| 층 | 막는 것 | 우회 가능성 |
|---|---|---|
| 리뷰 호스트의 보호 브랜치 설정 | 보호 브랜치로의 모든 push | **없음. 실제 최종 방어선** (서버 설정) |
| `.claude/settings.json` deny | Claude Code 가 실행하려는 위험 명령 | Claude 에만 적용. 문자열 패턴이라 변형을 다 덮지 못함 |
| `PreToolUse` 훅 | 명령 **실행 전**에 파싱으로 판정 | Claude 에만 적용. 셸 한 줄의 모든 우회를 막지는 못함 |
| git 훅 | 실제 git 동작 — 사람·AI 공통 | `--no-verify` (그래서 deny 에도 넣는다) |
| CI | 머지 전 검증 실행 | 성공 필수·승인 필수는 **서버 설정**이며 리포가 강제하지 못한다 |

`.claude/settings.json` 의 allow 는 승인 프롬프트만 없앤다. 절차가 정상 경로에서 부르는 관리 스크립트·forge 명령·
`git switch -c`·`git commit`(`permissions.allow_push` 가 참이면 `git push` 도)이 대상이다.
deny·`PreToolUse` 가드·git 훅은 allow 에 든 명령에도 그대로 적용된다. 이 설정은 Claude Code 에만 적용된다.

층이 겹치는 건 중복이 아니라 서로의 구멍을 메우는 것이다.
**리포 안의 어떤 설정도 보호 브랜치 push 를 완전히 막지 못한다** — 확실한 차단은 서버 설정이다.

## 규칙

- **값은 스크립트가 갖지 않는다.** 상한·브랜치·라벨은 `harness.toml` 에서 나와 `harness.env` 로 온다.
- **forge 명령을 직접 부르지 않는다.** `script/forge.sh` 를 source 하고 계약 함수만 쓴다.
- **기계가 읽는 문자열을 스크립트에 리터럴로 적지 않는다.** `harness-format.sh` 를 source 한다.
- **리뷰 수행과 등록을 분리한다.** 리뷰하는 쪽은 읽기 전용이고, 원격 쓰기는 `post-review.sh` 만 한다.
- **어댑터를 새로 쓰거나 고치면 `forge-selftest.sh` 를 실제 forge 로 돌린다.** 회귀 테스트는
  페이크를 쓰므로 실제 어댑터를 한 줄도 타지 않는다 — 계약 준수를 보는 것은 자체 검사뿐이다.
- **가드를 고치면 테스트 케이스를 함께 늘린다.** 가드는 망가져도 통과만 하므로 실패가 눈에 띄지 않는다.
- **사용 기록은 부수 효과다.** 기록 호출이 부른 쪽의 종료 코드를 바꾸지 않는다.
- 새 하네스 스크립트는 위 표에 한 줄 추가한다. 프로젝트 스크립트는 `script/project/` 에 두고
  `script/project/README.md` 표에 적는다 — 이 파일은 관리 파일이라 고치면 갱신이 덮는다.
