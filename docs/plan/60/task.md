# #60 task

## T1 · feat: 훅 설정 함수와 install 의 core.hooksPath 설정

### 상위 Requirement

- relates to #60

### 작업 내용

`harness install` 뒤 `core.hooksPath` 가 비어 있어 사람이 켜기 전까지 훅이 돌지 않는 문제를 없앤다. 값이 비어 있고 다른 훅이
없을 때만 켜고, 그 밖에는 건드리지 않고 켜는 명령을 알려 준다.

- 명세 1-1(기대 값과 켜짐 판정) · 1-2(설정 함수) · 1-3(`harness install`) · 7-1 의 install 케이스
- `src/bin/harness` 에 함수 둘을 둔다
  - 기대 값 계산·켜짐 판정: 하네스 루트의 `git rev-parse --show-prefix` 로 리포 안의 위치를 얻어 기대 값 `<위치>script/githooks` 를
    만들고, 현재 `core.hooksPath` 를 `git rev-parse --show-toplevel` 기준으로 풀어(절대 경로면 그대로) 하네스 루트의
    `script/githooks` 와 같은 디렉터리인지 가른다
  - 설정 함수: 명세 1-2 표의 결과(`no-git` · `already` · `other` · `own-hooks` · `set` · `failed`)와 그 부가 값을 돌려주고 출력하지 않는다.
    자기 훅 판정은 `git rev-parse --git-path hooks` 디렉터리에서 이름이 `.sample` 로 끝나지 않는 파일을 본다. 값은 언제나 기대 값
    (상대 경로)으로 리포 로컬 설정에 쓴다
- `cmd_install` 은 등록과 렌더가 성공한 뒤 설정 함수를 부르고, 명세 1-3 표의 문구를 표준 출력에 낸다. 결과는 종료 코드를 바꾸지
  않는다. `no-git` 의 기대 값은 `script/githooks` 다
- `render-test.sh` 에 새 `UT-75` 블록: 명세 7-1 의 install 케이스(빈 값 · 모노레포 설치 값 · 다른 값 · 두 번째 서브프로젝트 · 자기 훅 ·
  `.sample` 만 · git 밖 · 재설치). 각 케이스는 새 임시 리포에서 돈다
- 기존 테스트 중 install 뒤 `core.hooksPath` 가 비어 있다고 가정하거나 손으로 설정하던 곳은 새 동작에 맞춘다. 검증하는 내용은 바꾸지 않는다
- 건드릴 파일: `src/bin/harness`(새 함수 둘 · `cmd_install`), `src/test/render-test.sh`

### 완료 조건

- [ ] 빈 값의 새 리포에 설치하면 `core.hooksPath` 가 `script/githooks` 이고 표준 출력에 `set core.hooksPath` 줄이 있다
- [ ] `--target packages/api` 설치 뒤 값이 `packages/api/script/githooks` 다
- [ ] 값이 이미 다른 값이거나 `.git/hooks/` 에 `.sample` 이 아닌 훅이 있으면 값이 그대로이고, 표준 출력에 `left as is` 와 기대 값을 담은 `git config core.hooksPath` 명령이 있다
- [ ] 첫 서브프로젝트가 켠 리포에 둘째 서브프로젝트를 설치하면 값이 첫째 그대로다
- [ ] git 작업 트리 밖 설치는 종료 코드 0 이고 표준 출력에 `not a git repository` 가 있다
- [ ] 켜진 리포 재설치에서 값이 그대로이고 `set core.hooksPath` 줄이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/60-automate-work-prerequisites` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 빈 값에서 켠다 | 새 리포에 `harness install` | 값 `script/githooks`, 표준 출력에 `set core.hooksPath` |
| UT-02 | 모노레포 기대 값 | `--target packages/api` 설치 | 값 `packages/api/script/githooks` |
| UT-03 | 다른 값은 둔다 | 미리 `core.hooksPath` 를 다른 값으로 두고 설치 | 값 그대로, 표준 출력에 `left as is` 와 `git config core.hooksPath script/githooks` |
| UT-04 | 두 번째 서브프로젝트 | 첫 서브프로젝트 설치 뒤 둘째 설치 | 값이 첫째의 기대 값 그대로 |
| UT-05 | 자기 훅은 둔다 | 빈 값, `.git/hooks/pre-commit` 있음 | 값이 빈 채, 표준 출력에 `pre-commit` 과 `left as is` |
| UT-06 | `.sample` 만 | `.git/hooks/` 에 `.sample` 파일만 | 값 `script/githooks` |
| UT-07 | git 밖 | git 작업 트리가 아닌 디렉터리에 설치 | 종료 코드 0, 표준 출력에 `not a git repository` |
| UT-08 | 재설치 | 켜진 리포에 다시 설치 | 값 그대로, `set core.hooksPath` 줄 없음 |

## T2 · fix: doctor · uninstall · UI Doctor 가 서브프로젝트의 훅 기대 값으로 판정

### 상위 Requirement

- relates to #60

### 작업 내용

doctor 와 uninstall 이 `core.hooksPath` 를 `"script/githooks"` 문자열과 직접 비교해 모노레포 서브프로젝트에서 틀리게 판정하는 것을
T1 의 켜짐 판정으로 바꾼다. UI Doctor 가 훅 명령을 화면 쪽에 적어 두지 않고 doctor 의 detail 에서 가져오게 한다.

- 명세 1-4(`harness doctor` · `harness uninstall`) · 1-5(UI Doctor) · 7-1 의 doctor 모노레포 · uninstall 케이스 · 7-5
- `cmd_doctor` 의 `git hooks enabled` 줄: 켜짐이면 `ok`, 아니면 `bad` 이고 detail 은 ``run `git config core.hooksPath <기대 값>` ``
- `cmd_uninstall`: 켜짐일 때만 값을 지운다. 다른 서브프로젝트나 다른 도구를 가리키는 값은 두고 출력 줄을 내지 않는다
- `src/bin/harness` 에 `"script/githooks"` 와 직접 비교하는 곳을 남기지 않는다
- `src/ui/lib/doctor.js`: `git hooks enabled` 항목의 `run.cmd` 를 detail 의 백틱 안 명령에서 가져온다. 명령을 찾지 못하면 `run` 없이
  제목·본문만 낸다. ▷ 실행(`actions.js` 의 `doctorFix` `hooks`)이 설정하는 방법은 바꾸지 않는다
- `render-test.sh` 의 `UT-75` 블록에 doctor 모노레포 · uninstall 케이스를 더한다. `src/ui/lib/doctor.test.js` 에 7-5 케이스를 더한다
- 건드릴 파일: `src/bin/harness`(`cmd_doctor` · `cmd_uninstall`), `src/ui/lib/doctor.js`, `src/ui/lib/doctor.test.js`, `src/test/render-test.sh`

### 완료 조건

- [ ] 서브프로젝트 설치 뒤 그 서브프로젝트 doctor 의 `git hooks enabled` 가 `ok` 다
- [ ] 리포 루트의 `script/githooks` 로 켜진 리포에서 서브프로젝트 doctor 는 `bad` 이고 detail 에 서브프로젝트 경로를 담은 명령이 있다
- [ ] 서브프로젝트 uninstall 이 자기 값은 지우고, 다른 서브프로젝트를 가리키는 값은 두며 출력 줄을 내지 않는다
- [ ] `src/bin/harness` 에 `"script/githooks"` 와의 직접 비교가 없다
- [ ] `doctor.js` 의 `run.cmd` 가 detail 의 명령과 같고, detail 에 명령이 없으면 `run` 이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/60-automate-work-prerequisites` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 서브프로젝트 doctor 켜짐 | `--target packages/api` 설치 뒤 그 서브프로젝트 doctor | `git hooks enabled` 가 `ok` |
| UT-02 | 서브프로젝트 doctor 꺼짐 | 값이 `script/githooks` 인 리포의 서브프로젝트 doctor | `bad`, detail 에 `git config core.hooksPath packages/api/script/githooks` |
| UT-03 | uninstall 자기 값 | 서브프로젝트가 켠 값에서 그 서브프로젝트 uninstall | 값이 비었다 |
| UT-04 | uninstall 남의 값 | 다른 서브프로젝트를 가리키는 값에서 uninstall | 값 그대로, `unset core.hooksPath` 줄 없음 |
| UT-05 | UI 명령 추출 — 리포 루트 | detail ``run `git config core.hooksPath script/githooks` `` 인 `bad` 줄 | `run.cmd` 가 `git config core.hooksPath script/githooks` |
| UT-06 | UI 명령 추출 — 서브프로젝트 | detail 에 `packages/api/script/githooks` 명령 | `run.cmd` 가 그 명령 |
| UT-07 | UI 명령 없음 | detail 에 백틱 명령이 없는 `bad` 줄 | `run` 없음 |

## T3 · feat: render 가 forge 별 이슈·리뷰 요청 템플릿을 생성 파일로 생성

### 상위 Requirement

- relates to #60

### 작업 내용

forge 의 이슈·리뷰 요청 템플릿을 하네스가 만들지 않아 사람이 손으로 두던 것을, `.ai/templates/` 양식과 설정의 이슈 라벨에서
생성 파일로 만든다. 양식이 바뀌면 render 가 따라간다.

- 명세 2절 전부 · 7-2
- `plan()` 에 명세 2-1 표의 경로를 등록한다. `forge.tracker` · `forge.review_host` 를 따로 적용하고, Jira 트래커는 이슈 템플릿이 없다
- 본문은 `src/templates/managed/.ai/templates/issue-requirement.md` · `issue-task.md` · `mr.md` 를 바꾸지 않고 쓴다. GitHub 이슈
  템플릿은 명세 2-2 의 머리(`labels` 는 JSON 문자열 배열, 빈 값이면 `[]`)를, GitLab 이슈 템플릿은 명세 2-3 의 꼬리
  (`/label ~"<라벨>"`, 빈 값이면 생략)를 더한다
- 템플릿은 하네스 루트가 git 작업 트리 최상위이거나 git 작업 트리 밖일 때만 만든다. 리포 안의 위치는 T1 의 계산을 쓴다
- 이미 있는 파일은 명세 2-4 대로 사용자 파일 판정과 #58 의 `--adopt` 를 따른다
- 이 리포: `.github/ISSUE_TEMPLATE/requirement.md` · `task.md` · `.github/pull_request_template.md` 를 `harness render --adopt` 로
  넘겨받아 생성 파일로 커밋한다. `.orig` 파일은 옛 내용과 비교한 뒤 커밋에 넣지 않는다
- `render-test.sh` 에 새 `UT-76` 블록: 명세 7-2 의 케이스
- 건드릴 파일: `src/bin/harness`(`plan()` 과 템플릿 조립 함수), `src/test/render-test.sh`, 이 리포의 `.github/` 템플릿 세 파일 · 매니페스트

### 완료 조건

- [ ] 기본 설정 render 뒤 `.github/ISSUE_TEMPLATE/requirement.md` · `task.md` · `.github/pull_request_template.md` 가 있고, 이슈 템플릿 머리의 `labels` 가 설정 값이며 본문이 `.ai/templates/` 양식과 같다
- [ ] `issues.labels.task` 를 바꾸고 render 하면 `task.md` 머리의 라벨이 따라 바뀐다
- [ ] `tracker = "jira"`, `review_host = "github"` 이면 PR 템플릿만 있고 `.github/ISSUE_TEMPLATE/` 가 없다
- [ ] 두 설정을 `gitlab` 으로 바꾸고 render 하면 `.gitlab/` 세 파일이 생기고 `.github/` 템플릿이 지워지며, 이슈 템플릿 끝 줄이 `/label ~"<라벨>"` 이다
- [ ] 생성된 템플릿을 고치면 `harness check` 가 그 경로를 보고한다
- [ ] 서브프로젝트 설치에서는 템플릿이 생기지 않는다
- [ ] uninstall 뒤 템플릿이 없고 `.github/workflows/` 는 남는다
- [ ] 이 리포의 `.github/` 템플릿 세 파일이 매니페스트에 있고 `harness check` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/60-automate-work-prerequisites` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | GitHub 템플릿 | 기본 설정 render | 세 파일 존재, 머리 `labels` 가 설정 값, 본문이 양식과 같음, PR 템플릿이 `mr.md` 와 같음 |
| UT-02 | 라벨 변경 | `issues.labels.task` 변경 뒤 render | `task.md` 머리의 라벨이 새 값 |
| UT-03 | 트래커 Jira | `tracker = "jira"`, `review_host = "github"` | PR 템플릿만 있음, `.github/ISSUE_TEMPLATE/` 없음 |
| UT-04 | GitLab | 두 설정을 `gitlab` 으로 render | `.gitlab/` 세 파일, `.github/` 템플릿 없음, 이슈 템플릿 끝 줄 `/label ~"<라벨>"` |
| UT-05 | 손대면 잡힌다 | 생성된 템플릿 수정 뒤 `harness check` | 그 경로 보고, 종료 코드 0 이 아님 |
| UT-06 | 모노레포 | 서브프로젝트 설치 | 템플릿 없음 |
| UT-07 | 넘겨받기 | 매니페스트 없는 리포에 손으로 둔 `.github/pull_request_template.md` | render 종료 코드 2 · 파일 그대로. `render --adopt` 뒤 원래 내용이 `.orig` 에 있고, 경로는 매니페스트에 있고 `.orig` 는 없음 |
| UT-08 | 제거 | uninstall | 템플릿 없음, `.github/workflows/` 남음 |

## T4 · fix: GitHub 어댑터의 라벨 생성 실패를 호출부로 전달

### 상위 Requirement

- relates to #60

### 작업 내용

`_gh_ensure_label` 이 `label create` 실패를 삼켜, 권한이 부족하면 뒤의 `issue create` · `pr edit` 에서야 원인 모를 실패가 나는 것을
고친다. "이미 있음" 만 정상 실패로 보고 나머지는 원인을 알리며 멈춘다.

- 명세 3-3 · 7-4
- `_gh_ensure_label`: 라벨마다 `label create` 를 부르고, 실패하면 그 라벨이 원격에 있는지 조회한다. 있으면 성공, 없으면(조회 실패 포함)
  표준 오류에 ``error: could not create label `<라벨>` `` 과 `label create` 의 오류 끝 줄을 내고 0 이 아닌 코드로 돌아간다. 뒤 라벨로 가지 않는다
- `tracker_issue_create` · `tracker_issue_close` · `review_mr_labels_set` 은 라벨 준비 실패에서 이슈 생성·편집 전에 0 이 아닌 코드로 돌아간다
- 새 회귀 테스트 `script/test-forge-labels.sh`: `gh` 스텁을 PATH 앞에 두고 명세 7-4 의 경우를 확인한다. 원격을 부르지 않는다
- 건드릴 파일: `src/templates/managed/script/forge/github.sh`, `src/templates/managed/script/test-forge-labels.sh`(새 파일),
  `src/templates/managed/script/README.md`, `src/templates/managed/script/run-lint-test.sh`

### 완료 조건

- [ ] `label create` 가 성공하면 성공한다
- [ ] `label create` 가 실패하고 조회에서 라벨이 있으면 성공한다
- [ ] `label create` 가 실패하고 조회에서 없으면 0 이 아닌 코드이고 표준 오류에 그 라벨 이름이 있다
- [ ] 그때 `tracker_issue_create` 가 `issue create` 를 부르지 않고 0 이 아닌 코드로 돌아간다
- [ ] `script/run-lint-test.sh` 가 새 테스트를 돌리고 통과한다

### 브랜치

- `feat/60-automate-work-prerequisites` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성 성공 | 스텁 `label create` 0 | 종료 코드 0 |
| UT-02 | 이미 있음 | `label create` 실패, 조회에 라벨 있음 | 종료 코드 0 |
| UT-03 | 만들지 못함 | `label create` 실패, 조회에 라벨 없음 | 0 이 아닌 코드, 표준 오류에 `could not create label` 과 라벨 이름 |
| UT-04 | 뒤 라벨로 가지 않음 | 첫 라벨 실패, 라벨 둘 | 둘째 라벨의 `label create` 호출 없음 |
| UT-05 | 이슈 생성 중단 | UT-03 조건에서 `tracker_issue_create` | 0 이 아닌 코드, 스텁 기록에 `issue create` 없음 |

## T5 · feat: 어댑터 계약에 라벨 준비 함수 tracker_labels_ensure 추가

### 상위 Requirement

- relates to #60

### 작업 내용

원격에 이슈 라벨을 미리 만들 수 있도록 이슈 트래커 군에 라벨 준비 함수 하나를 더하고, 어댑터 셋과 페이크와 자체 검사가 그것을 갖게 한다.

- 명세 3-1
- `_common.sh` 머리의 계약에 `tracker_labels_ensure <라벨> ...` 를 적는다. 빈 인수는 건너뛰고, 인수가 없으면 성공하며, 하나라도 못 만들면
  0 이 아닌 코드와 표준 오류의 원인 줄
- `github.sh`: 라벨마다 `_gh_ensure_label`. `gitlab.sh`: `glab` 으로 만들고 이미 있다는 실패만 성공으로 본다, 미검증 표기. `jira.sh`: 성공만 돌려준다
- `src/test/fake-forge.sh`: 받은 라벨을 `FAKE_STATE` 아래 기록하고 성공한다
- `script/forge-selftest.sh`: 이슈 트래커 단계에서 설정의 이슈 라벨로 `tracker_labels_ensure` 를 한 번 부르고 성공을 확인한다.
  페이크 검사가 새 함수를 포함해도 계약 위반 6종을 모두 잡는다
- `script/test-forge-labels.sh` 에 GitHub 어댑터의 `tracker_labels_ensure` 경우를 더한다
- 건드릴 파일: `src/templates/managed/script/forge/_common.sh` · `github.sh` · `gitlab.sh` · `jira.sh`, `src/templates/managed/script/forge-selftest.sh`,
  `src/test/fake-forge.sh`, `src/templates/managed/script/test-forge-labels.sh`, 필요하면 `src/test/render-test.sh` 의 자체 검사 블록

### 완료 조건

- [ ] 세 어댑터와 페이크가 `tracker_labels_ensure` 를 정의한다
- [ ] GitHub 어댑터에서 빈 인수는 `label create` 호출 없이 건너뛰고, 인수가 없으면 종료 코드 0 이다
- [ ] GitHub 어댑터에서 한 라벨을 만들지 못하면 0 이 아닌 코드다
- [ ] Jira 어댑터는 원격을 부르지 않고 종료 코드 0 이다
- [ ] 페이크 forge 로 도는 자체 검사가 통과하고, 계약 위반 6종 주입을 모두 잡는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/60-automate-work-prerequisites` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 빈 인수 건너뜀 | GitHub 어댑터, 인수 `"" "Task"` | `Task` 만 `label create`, 종료 코드 0 |
| UT-02 | 인수 없음 | 인수 없이 호출 | 스텁 호출 없음, 종료 코드 0 |
| UT-03 | 실패 전달 | 둘째 라벨을 만들지 못하는 스텁 | 0 이 아닌 코드, 표준 오류에 그 라벨 |
| UT-04 | 페이크 기록 | 페이크 forge 에 라벨 셋 | `FAKE_STATE` 아래 세 라벨 기록, 종료 코드 0 |
| UT-05 | 자체 검사 | 페이크 forge 로 `forge-selftest.sh` | 통과, 위반 6종 주입 시 각각 실패 |

## T6 · feat: harness forge-setup 명령과 forge-setup.sh 로 원격 이슈 라벨 준비

### 상위 Requirement

- relates to #60

### 작업 내용

라벨이 처음 쓰일 때에야 만들어지고 권한 문제가 그때 드러나는 것을 없애도록, 사람이 한 번 부르는 원격 쓰기 명령으로 설정의 이슈 라벨을
미리 만든다. 절차·훅·다른 명령은 이 명령을 부르지 않는다.

- 명세 3-2 · 7-3 의 `test-forge-setup.sh`
- `COMMANDS` 에 `"forge-setup": (None, True, "", "create the configured issue labels on the tracker (writes to the remote)")` 를 더하고
  `DELEGATES` 에도 넣는다. `cmd_forge_setup()` 은 하네스 루트에서 `script/forge-setup.sh` 를 돌리고 그 종료 코드를 그대로 돌려준다
- 새 관리 스크립트 `script/forge-setup.sh`: `script/harness.env` 와 `script/forge.sh` 를 읽고 `tracker_require`(실패 시 2) →
  `tracker_labels_ensure "$ISSUE_LABEL_REQUIREMENT" "$ISSUE_LABEL_TASK" "$ISSUE_LABEL_INVALID"` → 명세 3-2 의 성공·실패 문구와 종료 코드 0 · 2
- 새 회귀 테스트 `script/test-forge-setup.sh`: 페이크 forge 로 명세 7-3 의 경우
- 건드릴 파일: `src/bin/harness`(`COMMANDS` · `DELEGATES` · `cmd_forge_setup`), `src/templates/managed/script/forge-setup.sh`(새 파일),
  `src/templates/managed/script/test-forge-setup.sh`(새 파일), `src/templates/managed/script/README.md`, `src/templates/managed/script/run-lint-test.sh`

### 완료 조건

- [ ] `harness forge-setup` 이 `script/forge-setup.sh` 의 종료 코드를 그대로 돌려주고, `harness` 도움말에 명령이 보인다
- [ ] 페이크 forge 로 설정의 세 라벨이 기록되고 종료 코드 0, 표준 출력에 `forge-setup: labels ready on <tracker>:` 와 빈 값을 뺀 라벨 목록이 있다
- [ ] 빈 라벨은 건너뛴다
- [ ] `tracker_require` 실패와 라벨 준비 실패에서 종료 코드 2 이고, 라벨 준비 실패면 표준 오류에 `stop: could not prepare labels on <tracker>` 가 있다
- [ ] `script/run-lint-test.sh` 가 새 테스트를 돌리고 통과한다

### 브랜치

- `feat/60-automate-work-prerequisites` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 라벨 준비 | 페이크 forge, 기본 라벨 셋 | 세 라벨 기록, 종료 코드 0, `labels ready on` |
| UT-02 | 빈 라벨 | `ISSUE_LABEL_INVALID` 가 빈 값 | 두 라벨만 기록, 출력 목록에 빈 값 없음 |
| UT-03 | 트래커 인증 실패 | 페이크의 `tracker_require` 실패 | 종료 코드 2, 라벨 기록 없음 |
| UT-04 | 라벨 준비 실패 | 페이크의 `tracker_labels_ensure` 실패 | 종료 코드 2, 표준 오류에 `could not prepare labels` |
| UT-05 | CLI 위임 | `harness forge-setup` | 스크립트와 같은 종료 코드 |

## T7 · feat: work-preflight 가 이슈를 조회해 닫힌 이슈와 조회 실패에 착수하지 않음

### 상위 Requirement

- relates to #60

### 작업 내용

없는 이슈 번호나 닫힌 이슈에도 착수 판정이 `standalone` 을 내는 것을 막는다. 열린 리뷰 요청 확인 앞에서 이슈를 조회해, 닫힌 이슈는
착수 불가(1), 조회 실패는 실행 실패(2)로 멈춘다.

- 명세 4절 · 7-3 의 `test-work-preflight.sh`
- `work-preflight.sh`: 열린 리뷰 요청 확인 앞에 `tracker_require` → `tracker_issue_view <이슈>` → 명세 4-1 표의 판정. 닫힘 판정은
  정규화 JSON 의 `state` 만 본다. 분해가 있는 경로에서도 인수로 받은 이슈를 확인하고 task 이슈는 확인하지 않는다
- 머리 주석의 종료 코드 설명에 "닫힌 이슈는 1, 이슈 조회 실패는 2" 를 반영한다
- `usage-vocab.sh` 의 `USAGE_LABELS` 에 `issue-closed` · `issue-query-failed` 를 더한다
- `src/test/fake-forge.sh`: `tracker_issue_view` 가 `FAKE_STATE` 로 열림·닫힘·조회 실패·`state` 가 빈 JSON 을 낼 수 있게 한다
- 새 회귀 테스트 `script/test-work-preflight.sh`: 페이크 forge 와 로컬 bare 원격으로 명세 7-3 의 경우
- 건드릴 파일: `src/templates/managed/script/work-preflight.sh` · `usage-vocab.sh`, `src/test/fake-forge.sh`,
  `src/templates/managed/script/test-work-preflight.sh`(새 파일), `src/templates/managed/script/README.md`, `src/templates/managed/script/run-lint-test.sh`

### 완료 조건

- [ ] 열린 이슈의 판정(`standalone` · `plan`)과 출력이 지금 그대로다
- [ ] 닫힌 이슈는 종료 코드 1 이고 표준 오류에 `stop: issue <이슈> is closed` 가 있다
- [ ] 조회 명령이 실패하면 종료 코드 2 이고 표준 오류에 `could not read issue` 와 `help:` 줄이 있다
- [ ] `state` 가 비었거나 알 수 없는 값이거나 출력이 JSON 이 아니면 종료 코드 2 다
- [ ] 닫힌 이슈·조회 실패에서 열린 리뷰 요청 조회가 돌지 않는다
- [ ] 사용 기록에 `issue-closed` · `issue-query-failed` 가 남고 `usage-vocab.sh` 가 그 어휘를 갖는다
- [ ] `script/run-lint-test.sh` 가 새 테스트를 돌리고 통과한다

### 브랜치

- `feat/60-automate-work-prerequisites` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 열린 이슈, 분해 없음 | 페이크 상태 열림 | `standalone`, 종료 코드 0 |
| UT-02 | 열린 이슈, 분해 있음 | 원격에 `docs/plan/<번호>/` | `plan`, 종료 코드 0 |
| UT-03 | 닫힌 이슈 | 페이크 상태 닫힘 | 종료 코드 1, `is closed`, 사용 기록 `issue-closed` |
| UT-04 | 조회 실패 | 페이크 조회 실패 | 종료 코드 2, `could not read issue`, 사용 기록 `issue-query-failed` |
| UT-05 | 빈 state | `state` 가 빈 JSON | 종료 코드 2, `could not read the state` |
| UT-06 | 리뷰 요청 조회 생략 | UT-03 · UT-04 조건 | 페이크 기록에 열린 리뷰 요청 조회 없음 |

## T8 · feat: review-mr 가 회차 라벨 전에 리뷰 러너의 설치와 인증을 점검

### 상위 Requirement

- relates to #60

### 작업 내용

리뷰어 CLI 가 인증 실패로 죽어도 회차 라벨이 먼저 올라 상한 한 칸을 쓰는 것을 막는다. forge 조회와 회차 라벨 갱신 앞에서 공용 진입점
`script/run-agent.py code-reviewer --check` 로 설치와 인증을 판정받는다.

- 명세 5절 · 7-3 의 `test-review-loop.sh`
- `review-mr.sh`: `_review.py plan-exe` 로 리뷰 러너를 읽는 것은 그대로 두고, `command -v "$reviewer_exe"` 설치 확인을
  `run-agent.py code-reviewer --check` 호출로 바꾼다. 호출은 `review_require` · `review_mr_view` · `review_mr_labels_set` 보다 앞이다
- 명세 5-2 표대로 0 이면 다음 단계, 그 밖은 종료 코드 2. `--check` 의 표준 출력은 버리고 표준 오류는 옮기며, 0 이 아니면
  `help: the round was not used — fix the review runner, then rerun` 한 줄을 더한다. 사용 기록은 `on_exit` 이 올리기 전 회차로 남긴다
- `--check` 와 `auth_check` 는 #59 가 만든 것을 쓴다. 판정을 review-mr.sh 안에 새로 만들지 않는다
- `test-review-loop.sh`: 리뷰어 스텁의 `auth_check` 가 로그인 안 됨(3) · 확인 불가(4) · 실행 파일 없음(2) 인 경우와 로그인 상태를 더한다
- 건드릴 파일: `src/templates/managed/script/review-mr.sh`, `src/templates/managed/script/test-review-loop.sh`

### 완료 조건

- [ ] `--check` 가 3 이면 review-mr.sh 가 종료 코드 2 이고 표준 오류에 `not signed in` 과 `the round was not used` 가 있다
- [ ] `--check` 가 4 · 2 인 경우도 종료 코드 2 와 `the round was not used` 다
- [ ] 위 경우들에서 회차 라벨이 바뀌지 않고 리뷰어 본 실행과 forge 조회가 돌지 않는다
- [ ] 스텁이 로그인 상태면 지금처럼 회차가 1 오른다
- [ ] 리뷰 러너가 서브에이전트 역할이면 지금의 안내와 종료 코드 2 그대로다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/60-automate-work-prerequisites` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 로그인 안 됨 | 스텁 `auth_check` 가 0 이 아닌 코드 (`--check` 3) | 종료 코드 2, `not signed in` · `the round was not used`, 회차 라벨 그대로 |
| UT-02 | 확인 불가 | `--check` 4 | 종료 코드 2, `the round was not used`, 회차 라벨 그대로 |
| UT-03 | 실행 파일 없음 | `--check` 2 | 종료 코드 2, `the round was not used`, 회차 라벨 그대로 |
| UT-04 | 본 실행 생략 | UT-01~03 조건 | 리뷰어 본 실행 기록 없음, forge 조회 기록 없음 |
| UT-05 | 로그인 상태 | 스텁 로그인 상태 | 회차 1 오름, 리뷰 등록 |

## T9 · docs: README · 스크립트 안내 · 훅 활성화 문구에 자동 설정과 forge-setup 반영

### 상위 Requirement

- relates to #60

### 작업 내용

사람과 에이전트가 읽는 안내가 "클론 뒤 `git config core.hooksPath` 를 손으로 켠다" 와 템플릿·라벨을 손으로 두는 절차를 적고 있는 것을,
install 의 자동 설정 · render 의 템플릿 생성 · `harness forge-setup` 으로 바꾼다.

- 명세 6절 표 전부
- `README.md`: "시작하기" 명령 블록을 `harness install` · `harness forge-setup` · `harness doctor` 로 하고 `git config core.hooksPath` 줄을 뺀다.
  "모노레포" · "명령" 표 · "파일은 세 부류다" 의 생성 행 · "`harness.toml` 이 정하는 것" 을 명세 6절대로 고친다
- `src/templates/generated/.ai/AI_AGENT.md` 8장 훅 활성화 줄, `src/templates/generated/script/githooks/*` 머리 주석의 활성화 줄
- `src/templates/managed/script/README.md` 의 `forge-setup.sh` 행과 "훅 활성화" 절, `src/templates/managed/docs/workflow/flow.md` 의 훅 활성화 문단
- 생성 파일과 이 리포의 사본은 render 로 맞춘다
- 건드릴 파일: `README.md`, `src/templates/generated/.ai/AI_AGENT.md`, `src/templates/generated/script/githooks/*`,
  `src/templates/managed/script/README.md`, `src/templates/managed/docs/workflow/flow.md`, render 결과물

### 완료 조건

- [ ] README "시작하기" 명령 블록에 `git config core.hooksPath` 줄이 없고 `harness forge-setup` 이 있다
- [ ] README 가 install 의 훅 설정 조건(비어 있을 때만, 다른 값·자기 훅은 두고 명령을 알려 줌)과 새로 클론한 사람의 doctor 안내를 적는다
- [ ] README "모노레포" 가 서브프로젝트 기대 값과 리포 루트 설치만 템플릿을 만든다는 것을 적는다
- [ ] README "명령" 표에 `harness forge-setup` 행, 생성 부류에 forge 별 템플릿 경로가 있다
- [ ] 렌더된 `.ai/AI_AGENT.md` 8장과 `script/githooks/*` 머리 주석이 install 이 켠다고 적는다
- [ ] `script/README.md` 에 `forge-setup.sh` 행이 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/60-automate-work-prerequisites` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 템플릿 수정 뒤 render, `harness check` | 어긋남 없음 |
| UT-02 | 문서 검증 | `script/run-lint-test.sh` | 통과 |

## T10 · docs: 아키텍처·담당 범위 문서에 템플릿 생성 · 착수 전 검증 · forge-setup 반영

### 상위 Requirement

- relates to #60

### 작업 내용

에이전트가 근거로 읽는 보호 문서가 새 동작을 담도록 개정한다. 이 개정은 이 이슈의 사용자 결정으로 허용된 범위다.

- 명세 8절
- `.ai/project/architecture.md` "데이터 흐름" 의 렌더 항목: 생성 파일에 forge 별 이슈·리뷰 요청 템플릿(`.github/…` · `.gitlab/…`)
- `.ai/project/architecture.md` "데이터 흐름" 의 절차 실행 항목: 리뷰 루프가 `work-preflight.sh`(이슈 확인 포함) → 구현자 →
  `review-mr.sh`(러너 점검 · diff 조회 · …) 순
- `.ai/project/scope.md` "할 수 있는 일": 원격에 이슈 라벨을 준비한다(`forge-setup`)
- 두 문서에서 생성되는 `.ai/AI_AGENT.md` 는 render 로 맞춘다
- 건드릴 파일: `.ai/project/architecture.md`, `.ai/project/scope.md`, `.ai/AI_AGENT.md`(render 결과)

### 완료 조건

- [ ] `architecture.md` 렌더 흐름의 생성 파일 목록에 forge 별 템플릿이 있다
- [ ] `architecture.md` 절차 실행 흐름에 preflight 의 이슈 확인과 review-mr 의 러너 점검이 있다
- [ ] `scope.md` "할 수 있는 일" 에 `forge-setup` 이 있다
- [ ] 렌더된 `.ai/AI_AGENT.md` 가 두 문서와 일치하고 `harness check` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/60-automate-work-prerequisites` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 보호 문서 개정 뒤 render, `harness check` | 어긋남 없음 |
| UT-02 | 문서 검증 | `script/run-lint-test.sh` | 통과 |
