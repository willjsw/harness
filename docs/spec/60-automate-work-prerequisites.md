# `/work` 착수 전제의 자동화와 착수 전 검증

설치 뒤 `/work` 에 필요한 전제 중 기계가 채울 수 있는 것은 하네스가 채우고, 리뷰 루프 도중에야 드러나던 실패는
착수 전·회차 소모 전에 잡는다.

- `harness install` 이 git 훅 설정(`core.hooksPath`)을 비어 있을 때만 켠다 (1절)
- `harness render` 가 forge 별 이슈·리뷰 요청 템플릿을 생성 파일로 만든다 (2절)
- `harness forge-setup` 이 원격에 이슈 라벨을 미리 만든다. 어댑터 계약에 라벨 준비 함수가 생긴다 (3절)
- GitHub 어댑터의 라벨 생성이 실패를 삼키지 않는다 (3-3)
- `script/work-preflight.sh` 가 이슈를 조회해 닫힌 이슈에는 착수하지 않는다 (4절)
- `script/review-mr.sh` 가 회차 라벨을 올리기 전에 리뷰 러너의 설치와 인증을 점검한다 (5절)

정본 위치:

| 대상 | 정본 |
|---|---|
| 훅 설정 함수 · install · doctor · uninstall · 템플릿 생성(`plan()`) · `forge-setup` 명령 | `src/bin/harness` |
| 이슈·리뷰 요청 템플릿 본문 | `src/templates/managed/.ai/templates/issue-requirement.md` · `issue-task.md` · `mr.md` |
| 어댑터 계약 · 구현 | `src/templates/managed/script/forge/_common.sh` · `github.sh` · `gitlab.sh` · `jira.sh` |
| 원격 준비 스크립트 | `src/templates/managed/script/forge-setup.sh` |
| 착수 판정 · 리뷰 루프 | `src/templates/managed/script/work-preflight.sh` · `review-mr.sh` |
| 사용 기록 어휘 | `src/templates/managed/script/usage-vocab.sh` |
| UI doctor 문구 | `src/ui/lib/doctor.js` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/test/fake-forge.sh` · `src/templates/managed/script/test-*.sh` · `src/ui/lib/doctor.test.js` |
| 사람용 설명 | `README.md` · `src/templates/managed/script/README.md` · `src/templates/managed/docs/workflow/flow.md` |

## 1. git 훅 설정

### 1-1. 기대 값과 켜짐 판정

하네스의 훅 디렉터리는 하네스 루트의 `script/githooks` 다. git 은 상대 경로의 `core.hooksPath` 를 작업 트리 최상위
기준으로 풀므로, 모노레포 서브프로젝트의 기대 값은 리포 안의 위치를 앞에 붙인 값이다.

| 항목 | 값 |
|---|---|
| 리포 안의 위치 | 하네스 루트에서 `git rev-parse --show-prefix` (리포 루트면 빈 문자열, 아니면 `/` 로 끝난다) |
| 기대 값 | `<리포 안의 위치>script/githooks` — 리포 루트면 `script/githooks`, `packages/api/` 면 `packages/api/script/githooks` |
| 켜짐 | 현재 `core.hooksPath` 값을 작업 트리 최상위(`git rev-parse --show-toplevel`) 기준으로 풀어(절대 경로면 그대로) 하네스 루트의 `script/githooks` 와 같은 디렉터리다 |

기대 값 계산과 켜짐 판정은 `src/bin/harness` 의 함수 하나가 갖고, install · doctor · uninstall 이 모두 그것을 쓴다.
`"script/githooks"` 문자열과 직접 비교하는 곳을 남기지 않는다.

### 1-2. 설정 함수

`src/bin/harness` 에 훅을 켜는 함수 하나를 둔다. install 이 부르고, UI 의 훅 조치를 CLI 로 옮기는 쪽도 이 함수를
부른다. 함수는 판정 결과를 돌려주고 출력은 부르는 쪽이 한다.

| 조건 (위에서부터 처음 맞는 행) | 결과 | 바꾸는 것 |
|---|---|---|
| 하네스 루트가 git 작업 트리 안이 아니다 | `no-git` | 없음 |
| `core.hooksPath` 가 이미 켜짐(1-1)이다 | `already` | 없음 |
| `core.hooksPath` 에 다른 값이 있다 | `other` (그 값) | 없음 |
| `core.hooksPath` 가 비어 있고 `git rev-parse --git-path hooks` 디렉터리에 이름이 `.sample` 로 끝나지 않는 파일이 있다 | `own-hooks` (그 파일 이름 목록) | 없음 |
| `core.hooksPath` 가 비어 있다 | `set` (기대 값) | `git config core.hooksPath <기대 값>` (리포 로컬 설정) |
| 위 `git config` 가 실패했다 | `failed` (git 의 오류 끝 줄) | 없음 |

- 값은 언제나 기대 값(상대 경로)으로 쓴다. 상대 경로여야 같은 리포의 worktree 가 각자의 `script/githooks` 를 쓴다
- `--git-path hooks` 는 linked worktree 에서도 공통 디렉터리의 훅 디렉터리를 가리킨다

### 1-3. `harness install`

`cmd_install` 은 등록과 렌더가 성공한 뒤 1-2 함수를 부른다. 렌더가 먼저여야 `script/githooks/` 가 있다. 결과는
install 의 종료 코드를 바꾸지 않는다. 표준 출력:

| 결과 | 출력 |
|---|---|
| `set` | `install: set core.hooksPath to <기대 값> — git hooks now run on commit and push` |
| `already` | 없음 |
| `other` | `install: core.hooksPath is already <값> — left as is` 와 ``help: to use this harness's hooks, run `git config core.hooksPath <기대 값>` `` |
| `own-hooks` | `install: core.hooksPath is not set but <훅 디렉터리> has hooks of its own (<이름>, …) — left as is` 와 위와 같은 `help:` 줄 |
| `no-git` | `install: not a git repository — git hooks were not enabled` 와 ``help: after `git init`, run `git config core.hooksPath <기대 값>` `` |
| `failed` | `install: could not set core.hooksPath: <git 의 오류 끝 줄>` 와 위와 같은 `help:` 줄 |

`no-git` 의 기대 값은 리포 안의 위치를 알 수 없으므로 `script/githooks` 다.

### 1-4. `harness doctor` · `harness uninstall`

- doctor 의 `git` 절 `git hooks enabled` 줄은 1-1 켜짐이면 `ok`, 아니면 `bad` 이고 detail 은
  ``run `git config core.hooksPath <기대 값>` `` 다
- uninstall 은 `core.hooksPath` 가 1-1 켜짐일 때만 값을 지운다. 다른 서브프로젝트나 다른 도구를 가리키는 값은 두고
  지금처럼 출력 줄을 내지 않는다
- 두 판정 모두 모노레포 서브프로젝트에서 기대 값을 쓴다 — 리포 루트의 `script/githooks` 로 보지 않는다

### 1-5. UI Doctor — `src/ui/lib/doctor.js`

- `git hooks enabled` 줄의 항목이 보이는 명령(`run.cmd`)은 doctor 의 detail 에서 백틱 안의 명령을 그대로 가져온다.
  `script/githooks` 를 화면 쪽에 적어 두지 않는다
- detail 에서 명령을 찾지 못하면 `run` 없이 제목·본문만 낸다
- ▷ 실행(`src/ui/lib/actions.js` 의 `doctorFix` `hooks`)이 설정을 하는 방법은 이 명세가 바꾸지 않는다 — 그 조치는 CLI
  호출로 옮겨지고, 그때 1-2 함수를 쓴다

## 2. 이슈·리뷰 요청 템플릿 생성

### 2-1. 무엇을 어디에 만드는가

`plan()` 이 아래 파일을 생성 파일로 낸다. 본문은 관리 파일인 `.ai/templates/` 양식이 정본이고, 템플릿은 그 본문에
forge 가 읽는 머리(또는 꼬리)만 더한다.

| 설정 | 경로 | 내용 |
|---|---|---|
| `forge.tracker = "github"` | `.github/ISSUE_TEMPLATE/requirement.md` | 머리(2-2) + `issue-requirement.md` 본문 |
| `forge.tracker = "github"` | `.github/ISSUE_TEMPLATE/task.md` | 머리(2-2) + `issue-task.md` 본문 |
| `forge.review_host = "github"` | `.github/pull_request_template.md` | `mr.md` 본문 그대로 |
| `forge.tracker = "gitlab"` | `.gitlab/issue_templates/Requirement.md` | `issue-requirement.md` 본문 + 꼬리(2-3) |
| `forge.tracker = "gitlab"` | `.gitlab/issue_templates/Task.md` | `issue-task.md` 본문 + 꼬리(2-3) |
| `forge.review_host = "gitlab"` | `.gitlab/merge_request_templates/Default.md` | `mr.md` 본문 그대로 |
| `forge.tracker = "jira"` | 없음 | Jira 는 리포 파일로 이슈 양식을 받지 않는다 |

- 두 설정은 따로 적용된다. `tracker = "jira"`, `review_host = "github"` 이면 `.github/pull_request_template.md` 하나만 생긴다
- 생성 파일이므로 매니페스트(`.harness/generated`)에 오르고, 설정이 바뀌어 더는 만들지 않으면 다음 render 가 지우며,
  손으로 고치면 `harness check` 가 잡고, `harness uninstall` 이 지운다
- `.github/workflows/` · `.gitlab-ci.yml`(CI 골격, 소유 파일)과는 경로가 겹치지 않고 그 처리도 바뀌지 않는다
- 템플릿은 하네스 루트가 git 작업 트리 최상위일 때(1-1 의 리포 안의 위치가 빈 문자열) 또는 git 작업 트리 밖일 때
  만든다. 모노레포 서브프로젝트에서는 만들지 않는다 — forge 는 리포 루트의 템플릿만 읽는다

### 2-2. GitHub 이슈 템플릿 머리

```
---
name: <이름>
about: <설명>
title: ""
labels: [<라벨>]
---

```

| 파일 | `name` | `about` | `labels` |
|---|---|---|---|
| `requirement.md` | `Requirement` | `요구사항 이슈 — 브랜치 하나·리뷰 요청 하나의 단위` | `issues.labels.requirement` |
| `task.md` | `Task` | `단독 task 이슈. 분해의 task 는 sync-task-issues.sh 가 만든다` | `issues.labels.task` |

- 라벨은 JSON 문자열로 따옴표를 붙인다(`["Requirement"]`). 설정 값이 빈 문자열이면 `labels: []` 다
- 머리 다음 빈 줄 하나 뒤에 양식 본문을 바꾸지 않고 잇는다

### 2-3. GitLab 이슈 템플릿 꼬리

양식 본문 끝에 빈 줄 하나와 빠른 동작 한 줄 `/label ~"<라벨>"` 을 붙인다. 라벨은 2-2 표의 설정 값이고, 빈 문자열이면
꼬리를 붙이지 않는다.
<!-- TBD: 확인 필요 — GitLab 의 템플릿 경로(`.gitlab/issue_templates/` · `.gitlab/merge_request_templates/Default.md`)와 빠른 동작 문법을 실제 GitLab 으로 확인하지 않았다 -->

### 2-4. 이미 있는 파일

2-1 의 경로는 `plan()` 의 경로이므로 render 의 사용자 파일 판정 대상이다. 생성 경로에 이전 매니페스트에 없는 파일이
이미 있으면(이 리포의 손으로 둔 `.github/` 템플릿이 그렇다) render · install · set · steps · checks 는 아무것도 쓰지 않고
종료 코드 2 로 멈추며, 안내문에 그 경로와 `--adopt` 가 나온다.

- 사람이 같은 명령을 `--adopt` 와 함께 다시 돌리면 원래 파일은 같은 디렉터리의 `<경로>.orig` 로 옮겨지고, 그 자리에
  생성 파일이 쓰이며 매니페스트에 오른다. 표준 출력에 ``render: adopted <경로> — yours is at <경로>.orig`` 한 줄이 난다
- `.orig` 파일은 매니페스트에 들지 않는다. render 가 덮지도 지우지도 않고 uninstall 도 남긴다. 옛 내용과 비교한 뒤 지우는
  것은 사람이다
- `<경로>.orig` 가 이미 있거나 그 경로가 디렉터리면 `--adopt` 여도 멈춘다

이 리포에서는 넘겨받은 뒤 `.github/ISSUE_TEMPLATE/requirement.md` 가 양식 본문 전부(`## 리뷰` 절 포함)를 갖게 되고,
세 파일은 생성 파일이 된다.

## 3. 원격 라벨 준비

### 3-1. 어댑터 계약 — `script/forge/_common.sh`

이슈 트래커 군에 함수 하나를 더한다.

```
tracker_labels_ensure <라벨> ...        라벨이 트래커에 있게 한다. 이미 있으면 성공. 하나라도 못 만들면 0 이 아닌 코드
```

- 빈 인수는 건너뛴다. 인수가 없으면 아무것도 하지 않고 성공한다
- 실패하면 표준 오류에 어느 라벨이 왜 실패했는지 한 줄 이상을 낸다

| 어댑터 | 동작 |
|---|---|
| `github.sh` | 라벨마다 3-3 의 `_gh_ensure_label` |
| `gitlab.sh` | 라벨마다 `glab` 으로 만든다. 이미 있다는 실패만 성공으로 본다. 함수 머리 주석에 미검증 표기를 둔다 |
| `jira.sh` | 할 일이 없다 — Jira 라벨은 이슈에 붙일 때 생긴다. 성공만 돌려준다 |
| `src/test/fake-forge.sh` | 받은 라벨을 `FAKE_STATE` 아래 기록하고 성공한다 |

`script/forge-selftest.sh` 는 이슈 트래커 단계에서 설정의 이슈 라벨로 `tracker_labels_ensure` 를 한 번 부르고 성공을
확인한다. 이미 있는 라벨에 대해 도는 멱등 호출이다.

### 3-2. `harness forge-setup`

사람이 부르는 원격 쓰기 명령이다. 절차·훅·다른 명령이 자동으로 부르지 않는다.

- `COMMANDS` 에 `"forge-setup": (None, True, "", "create the configured issue labels on the tracker (writes to the remote)")`
  를 더하고 `cmd_forge_setup()` 을 둔다. 고정된 하네스가 답해야 하므로 `DELEGATES` 에도 넣는다
- `cmd_forge_setup()` 은 하네스 루트에서 `script/forge-setup.sh` 를 돌리고 그 종료 코드를 그대로 돌려준다
- `script/forge-setup.sh`(관리 스크립트, `script/README.md` 표에 한 줄):
  1. `script/harness.env` 와 `script/forge.sh` 를 읽는다
  2. `tracker_require` — 실패하면 종료 코드 2
  3. `tracker_labels_ensure "$ISSUE_LABEL_REQUIREMENT" "$ISSUE_LABEL_TASK" "$ISSUE_LABEL_INVALID"`
  4. 성공이면 `forge-setup: labels ready on <tracker>: <빈 값을 뺀 라벨 목록>` 을 내고 종료 코드 0. 실패면
     `stop: could not prepare labels on <tracker>` 를 표준 오류로 내고 종료 코드 2

만드는 것은 설정의 이슈 라벨(`issues.labels` 의 `requirement` · `task` · `invalid`)뿐이다. 회차 라벨(`<round_label>:<N>`)은
미리 만들지 않는다 — `review_mr_labels_set` 이 붙일 때 만든다. 이슈·리뷰 요청 템플릿은 이 명령이 아니라 render 가
만든다(2절). 리뷰 댓글의 작성자 표시(`REVIEWER_LABEL`, 벤더 선언의 `label`)는 forge 라벨이 아니므로 만들 대상이 아니다.

### 3-3. `_gh_ensure_label` — `script/forge/github.sh`

- 라벨마다 `label create` 를 부른다. 성공이면 다음 라벨로 간다
- 실패하면 그 라벨이 원격에 있는지 조회한다. 있으면 성공으로 본다 — "이미 있음" 만이 정상인 실패다
- 없으면(조회 실패 포함) 표준 오류에 ``error: could not create label `<라벨>` `` 과 `label create` 의 오류 끝 줄을 내고
  0 이 아닌 코드로 돌아간다. 뒤 라벨로 가지 않는다
- 이 함수를 쓰는 `tracker_issue_create` · `tracker_issue_close` · `review_mr_labels_set` 은 라벨 준비가 실패하면
  이슈 생성·편집 전에 0 이 아닌 코드로 돌아간다. 각 호출부의 기존 실패 처리가 그 코드를 받는다

## 4. 착수 판정의 이슈 확인 — `script/work-preflight.sh`

### 4-1. 순서

열린 리뷰 요청 확인(①) 앞에 이슈 확인(⓪)을 둔다. 나머지 순서와 출력은 그대로다.

1. `script/forge.sh` 를 읽고 `tracker_require` — 실패하면 종료 코드 2
2. `tracker_issue_view <이슈>` 로 정규화 JSON 을 받아 `state` 를 읽는다
3. 판정

| 조회 결과 | 판정 | 종료 코드 | 표준 오류 | 사용 기록 상세 |
|---|---|---|---|---|
| 명령이 실패했다 (없는 번호 · 인증 · 네트워크 · 권한) | 실행 실패 | 2 | `stop: could not read issue <이슈> from the tracker` 와 `help: check that the issue exists and that the tracker CLI is signed in` | `issue-query-failed` |
| 출력이 JSON 으로 읽히지 않거나 `state` 가 비었거나 알 수 없는 값이다 | 실행 실패 | 2 | `stop: could not read the state of issue <이슈>` | `issue-query-failed` |
| `state` 가 `closed` | 착수 불가 | 1 | `stop: issue <이슈> is closed` | `issue-closed` |
| `state` 가 `open` 또는 `opened` | 다음 검사(①)로 | — | — | — |

- 어댑터 계약은 바꾸지 않는다. "없는 이슈" 를 따로 가르지 않고 조회 실패로 다룬다
- 닫힘 판정은 정규화 JSON 의 `state` 값만 본다. 어댑터가 트래커의 상태를 `open`·`opened`·`closed` 로 옮긴다
- 분해가 있는 경로에서도 인수로 받은 이슈(요구사항 이슈)를 확인한다. task 이슈는 확인하지 않는다
- 착수 전과 위임 직전에 같은 명령을 돌리므로 두 번 모두 이 검사를 거친다

### 4-2. 머리 주석과 사용 기록 어휘

- 머리 주석의 종료 코드 설명에 "닫힌 이슈는 1, 이슈 조회 실패는 2" 를 반영한다
- `usage-vocab.sh` 의 `USAGE_LABELS` 에 `issue-closed` · `issue-query-failed` 를 더한다

## 5. 회차를 올리기 전 러너 점검 — `script/review-mr.sh`

러너의 설치와 인증은 벤더 선언의 `auth_check` 와 실행 계획(`script/harness.plan.json`)에 실린 그 값, 그리고 공용 진입점
`script/run-agent.py <역할> --check` 가 판정한다. review-mr.sh 는 판정을 새로 만들지 않고 이 진입점을 부른다.

### 5-1. 자리

1. 지금처럼 `_review.py plan-exe` 로 리뷰 러너를 읽는다. 비어 있으면(서브에이전트 역할) 지금의 안내와 종료 코드 2 그대로다
2. 지금의 설치 확인(`command -v "$reviewer_exe"`)을 `script/run-agent.py code-reviewer --check` 호출로 바꾼다
3. 이 호출은 forge 조회(`review_require` · `review_mr_view`)와 회차 라벨 갱신(`review_mr_labels_set`)보다 앞이다

### 5-2. 종료 코드별 동작

| `--check` 종료 코드 | 뜻 | review-mr.sh |
|---|---|---|
| 0 (`signed-in`) | 설치되어 있고 로그인되어 있다 | 다음 단계로 간다 |
| 0 (`unchecked`) | 설치되어 있고, 벤더 선언에 `auth_check` 가 없다 | 다음 단계로 간다 |
| 2 | 실행 계획 · 역할 · 실행 파일이 없다 | 종료 코드 2 |
| 3 | 로그인되어 있지 않다 | 종료 코드 2 |
| 4 | 로그인 여부를 확인하지 못했다 (제한 시간 초과 · 띄우지 못함) | 종료 코드 2 |
| 그 밖 | — | 종료 코드 2 |

- `--check` 의 표준 출력(`signed-in` · `unchecked`)은 버린다. 표준 오류(`error:` 줄)는 그대로 옮긴다
- 0 이 아닌 모든 경우 그 뒤에 `help: the round was not used — fix the review runner, then rerun` 한 줄을 표준 오류로 더한다.
  회차 라벨은 그대로이고, 리뷰어는 돌지 않는다
- 사용 기록은 지금처럼 `on_exit` 이 남긴다 — 이때 회차는 올리기 전 값이다
- 로그인을 확인한 뒤 리뷰 실행 도중 실패하는 경우는 지금처럼 회차를 소모한다

## 6. 문서

| 문서 · 위치 | 적는 사실 |
|---|---|
| `README.md` "시작하기" | 명령 블록이 `harness install` · `harness forge-setup` · `harness doctor` 다. `git config core.hooksPath` 줄을 뺀다. install 이 `core.hooksPath` 가 비어 있으면 켜고 그 사실을 출력한다는 것, 다른 값이나 `.git/hooks/` 의 자기 훅이 있으면 건드리지 않고 켜는 명령을 알려 준다는 것. `forge-setup` 은 원격에 이슈 라벨을 만드는 쓰기이고 사람이 한 번 부른다는 것. 이미 설치된 리포를 새로 클론한 사람은 doctor 가 알려 주는 명령으로 훅을 켠다는 것 |
| `README.md` "모노레포" | install 이 서브프로젝트의 기대 값(`packages/api/script/githooks`)으로 켜고, 이미 다른 서브프로젝트가 켜 둔 값은 두므로 한 서브프로젝트만 훅을 갖는다는 것. 이슈·리뷰 요청 템플릿은 리포 루트에 설치한 하네스만 만든다는 것 |
| `README.md` "명령" 표 | `harness forge-setup` 행 |
| `README.md` "파일은 세 부류다" 의 생성 행 | forge 별 템플릿(`.github/ISSUE_TEMPLATE/` · `.github/pull_request_template.md` · `.gitlab/issue_templates/` · `.gitlab/merge_request_templates/`) |
| `README.md` "`harness.toml` 이 정하는 것" | `forge.tracker` · `review_host` 행에 이슈·리뷰 요청 템플릿, `issues.labels` 행에 이슈 템플릿의 라벨과 `forge-setup` |
| `src/templates/generated/.ai/AI_AGENT.md` 8장 훅 활성화 줄 | install 이 비어 있을 때 켠다. 켜지지 않았으면 `harness doctor` 가 켜는 명령을 알려 준다 |
| `src/templates/managed/script/README.md` | `forge-setup.sh` 행. "훅 활성화" 절에 install 이 켠다는 것 |
| `src/templates/managed/docs/workflow/flow.md` 훅 활성화 문단 | 같은 사실 |
| `src/templates/generated/script/githooks/*` 머리 주석의 활성화 줄 | install 이 켠다. 모노레포면 서브프로젝트 경로를 앞에 붙인다 |

## 7. 회귀 테스트

### 7-1. `render-test.sh` — 새 `UT-75` 블록: install 의 훅 설정

각 케이스는 새 임시 리포(`git init`)에서 `harness install` 을 돈다.

| 케이스 | 확인하는 것 |
|---|---|
| 빈 값 | 설치 뒤 `core.hooksPath` 가 `script/githooks`, 표준 출력에 `set core.hooksPath` |
| 모노레포 | `--target packages/api` 설치 뒤 값이 `packages/api/script/githooks`. 그 서브프로젝트의 doctor `git hooks enabled` 가 `ok` |
| 다른 값 | 미리 `core.hooksPath` 를 다른 값으로 두면 값이 그대로이고, 표준 출력에 `left as is` 와 기대 값을 담은 `git config core.hooksPath` 명령 |
| 두 번째 서브프로젝트 | 첫 서브프로젝트가 켠 리포에 둘째 서브프로젝트를 설치하면 값이 첫째 그대로 |
| 자기 훅 | 값이 비어 있고 `.git/hooks/pre-commit` 이 있으면 값이 빈 채이고 표준 출력에 `pre-commit` 과 `left as is` |
| `.sample` 만 | `.git/hooks/` 에 `.sample` 파일만 있으면 값이 설정된다 |
| git 밖 | git 작업 트리가 아닌 디렉터리에 설치하면 종료 코드 0, 표준 출력에 `not a git repository` |
| 재설치 | 켜진 리포에 다시 설치하면 값이 그대로이고 `set core.hooksPath` 줄이 없다 |
| doctor 모노레포 | 리포 루트의 `script/githooks` 로 켜진 리포에서 서브프로젝트 doctor 는 `bad` 이고 detail 에 서브프로젝트 경로를 담은 명령 |
| uninstall | 서브프로젝트 uninstall 이 자기 값은 지우고, 다른 서브프로젝트를 가리키는 값은 둔다 |

### 7-2. `render-test.sh` — 새 `UT-76` 블록: forge 템플릿 생성

| 케이스 | 확인하는 것 |
|---|---|
| GitHub | 기본 설정 render 뒤 세 파일이 있고, 이슈 템플릿 머리의 `labels` 가 `setup()` 이 고정한 라벨 값, 본문이 `.ai/templates/` 양식과 같다. PR 템플릿이 `mr.md` 와 같다 |
| 라벨 변경 | `issues.labels.task` 를 바꾸고 render 하면 `task.md` 머리의 라벨이 따라 바뀐다 |
| 트래커 Jira | `tracker = "jira"`, `review_host = "github"` 이면 PR 템플릿만 있고 `.github/ISSUE_TEMPLATE/` 가 없다 |
| GitLab | `tracker`·`review_host` 를 `gitlab` 으로 바꾸고 render 하면 `.gitlab/` 세 파일이 생기고 `.github/` 템플릿이 지워진다. 이슈 템플릿 끝 줄이 `/label ~"<라벨>"` |
| 손대면 잡힌다 | 생성된 템플릿을 고치면 `harness check` 가 그 경로를 보고한다 |
| 모노레포 | 서브프로젝트 설치에서는 템플릿이 생기지 않는다 |
| 넘겨받기 | 매니페스트 없는 리포에 손으로 둔 `.github/pull_request_template.md` 가 있으면 render 가 종료 코드 2 이고 그 파일이 그대로다. `render --adopt` 뒤 원래 내용이 `.github/pull_request_template.md.orig` 에 있고, 그 경로는 매니페스트에 있고 `.orig` 는 없다 |
| 제거 | uninstall 뒤 템플릿이 없고 `.github/workflows/` 는 남는다 |

### 7-3. 관리 스크립트 테스트

| 파일 | 확인하는 것 |
|---|---|
| `script/test-work-preflight.sh` (새 파일) | 페이크 forge 와 로컬 bare 원격으로 — 열린 이슈는 지금 판정 그대로(`standalone` · `plan`), 닫힌 이슈는 종료 코드 1 과 `is closed`, 조회 실패는 종료 코드 2 와 `could not read issue`, `state` 가 빈 JSON 은 종료 코드 2. 닫힌 이슈·조회 실패에서는 열린 리뷰 요청 조회가 돌지 않는다. 사용 기록에 `issue-closed` · `issue-query-failed` |
| `script/test-review-loop.sh` | 리뷰어 스텁의 `auth_check` 명령이 0 이 아닌 코드를 내면(`--check` 3) review-mr.sh 가 종료 코드 2 이고, 표준 오류에 `not signed in` 과 `the round was not used`, 회차 라벨이 바뀌지 않으며 리뷰어 본 실행이 돌지 않는다. `--check` 가 4 · 2 인 경우도 같다. 스텁이 로그인 상태면 지금처럼 회차가 1 오른다 |
| `script/test-forge-setup.sh` (새 파일) | 페이크 forge 로 — 설정의 세 라벨이 기록되고 종료 코드 0, 빈 라벨은 건너뛴다. `tracker_require` 실패와 라벨 준비 실패에서 종료 코드 2 |

`src/test/fake-forge.sh` 에 `tracker_labels_ensure` 를 더하고, `tracker_issue_view` 가 `FAKE_STATE` 로 상태(열림·닫힘·조회 실패)를
바꿀 수 있게 한다. 자체 검사의 페이크 검사는 새 함수를 포함해도 계약 위반 6종을 모두 잡는다.

### 7-4. `_gh_ensure_label`

`gh` 스텁을 PATH 앞에 두고 — `label create` 성공 · 실패 후 조회에서 있음은 성공, 실패 후 조회에서 없음은 0 이 아닌 코드와
표준 오류의 라벨 이름. 그때 `tracker_issue_create` 가 `issue create` 를 부르지 않는다.

### 7-5. `doctor.test.js`

- `git hooks enabled` 의 `bad` 줄에서 `run.cmd` 가 detail 의 명령과 같다 — 리포 루트 값과 `packages/api/script/githooks` 값 모두
- detail 에 백틱 명령이 없으면 `run` 이 없다

터미널 출력의 한글 검사는 새 블록과 새 스크립트의 출력에도 적용한다.

## 8. 보호 문서 개정

이 이슈의 구현에서 아래 보호 문서를 개정한다.

| 문서 · 위치 | 반영할 사실 |
|---|---|
| `.ai/project/architecture.md` "데이터 흐름" 렌더 | 생성 파일에 forge 별 이슈·리뷰 요청 템플릿(`.github/…` · `.gitlab/…`)이 더해진다 |
| `.ai/project/architecture.md` "데이터 흐름" 절차 실행 | 리뷰 루프가 `work-preflight.sh`(이슈 확인 포함) → 구현자 → `review-mr.sh`(러너 점검 · diff 조회 · …) 순이다 |
| `.ai/project/scope.md` "할 수 있는 일" | 원격에 이슈 라벨을 준비한다 (`forge-setup`) |

## 9. 한계

- 이미 하네스가 깔린 리포를 새로 클론하면 install 을 다시 돌지 않는 한 훅은 꺼진 채다. doctor 가 켜는 명령을 알려 준다
- 모노레포에서 리포 루트의 forge 템플릿은 어느 서브프로젝트도 만들지 않는다
- `forge-setup` 은 라벨의 색·설명을 맞추지 않는다. 없는 라벨만 만든다
