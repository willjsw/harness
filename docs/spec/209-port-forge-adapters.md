# forge 어댑터의 Python 패키지 이식

forge 어댑터(이슈 트래커 군 · 리뷰 호스트 군)와 자체 검사 · 라벨 준비가 CLI 패키지 `src/harness/forge/` 에 있다.
`gh` · `glab` · `jira` 는 그 패키지가 subprocess 로 감싼다. 아직 셸인 호출부를 위해 `script/forge.sh` ·
`script/forge-selftest.sh` · `script/forge-setup.sh` 는 같은 인자로 CLI 명령을 부르는 **shim** 으로 남는다.
외부 계약 — 계약 함수의 이름 · 인자 · 표준 출력 · 종료 코드, 자체 검사와 라벨 준비의 명령줄 · 출력 · 종료 코드 — 은
바뀌지 않는다.

근거는 #206 의 결정 기록 "하네스 로직은 Python 표준 라이브러리 패키지 하나에 둔다" 와 ADR 0006 이다. 0006 의 Decision
(어댑터 계약 · 정규화 JSON · 트래커와 리뷰 호스트의 분리 · 리뷰 호스트로 Jira 거부 · 실제 forge 자체 검사 · 미검증 표기)은
그대로이고, 바뀌는 것은 어댑터가 놓이는 파일이다. 이 명세의 결정 기록은 없다.

패키지 배치(`src/harness/` · 명령 하나에 모듈 하나인 `commands/` · 진입 스크립트 `src/bin/harness` · 고정 사본
`.harness/lib/harness/` · 바이트코드 위치)는 #206 이 정한다. 이 명세는 CLI 쪽 코드를 함수 이름으로 적는다 —
`derive()` · `validate()` · `doctor_items()` · `remote_call()` · `delegate()` 는 #206 이 옮긴 자리에 있다. 명령 이름 뒤의 인자를
공용 파서가 건드리지 않는 통과 명령(#206 3-3)과 Python 단위 테스트의 자리 · 실행 명령 · 검증 단계도 #206 이 둔다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 어댑터 계약 — 함수 표 · 정규화 dataclass · 오류 · 머리글 표지 규칙 | `src/harness/forge/contract.py` |
| 어댑터 구현 | `src/harness/forge/github.py` · `gitlab.py` · `jira.py` |
| 어댑터 선택 · 함수 호출 · 페이크 주입 | `src/harness/forge/__init__.py` · `shell.py` |
| 자체 검사 | `src/harness/forge/selftest.py` |
| 표지 읽기 | `src/harness/format.py` |
| CLI 명령 `forge` · `forge-selftest` · `forge-setup` | `src/harness/commands/` 의 명령 모듈 |
| shim `script/forge.sh` (생성) | 원형 `src/templates/generated/script/forge.sh` + 계약 함수 표 |
| shim `script/forge-selftest.sh` · `script/forge-setup.sh` (관리) | `src/templates/managed/script/` |
| doctor 의 어댑터 판정 · `forge fake` 항목 · 원격 forge 호출 | #206 이 옮긴 doctor 모듈 |
| forge 명령 사전 원형 | `src/templates/forge/forge.md` · `src/templates/forge/github/review.md` |
| 페이크 | `src/test/fake-forge.sh` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/templates/managed/script/test-forge-labels.sh` · `test-forge-setup.sh` |
| forge 어댑터 · 표지 읽기의 Python 단위 테스트 | `src/test/unit/test_forge_*.py` · `test_format.py` |
| UI doctor 문구 | `src/ui/lib/doctor.js` |
| 사람용 설명 | `README.md` · `src/templates/managed/script/README.md` · `src/templates/managed/docs/workflow/` |

이 리포의 `script/` · `docs/workflow/` 아래 같은 이름의 파일은 거기서 설치된 사본이다.

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

바뀌지 않는다.

- 계약 함수 24개(2-2)의 이름 · 인자 · 표준 출력 · 종료 코드. 셸 호출부는 `. script/forge.sh` 뒤 같은 함수를 같은 인자로 부른다
- 정규화 JSON 의 키와 값(2-3 · 2-6)
- `script/forge-selftest.sh` 의 인자 · 단계 · 항목 · 판정 · 종료 코드(3-3). `script/forge-setup.sh` 와 `harness forge-setup` 의 출력 · 종료 코드(3-4)
- doctor 의 항목 문구 — `adapter <kind>` 의 `ok` · ``unverified — run `script/forge-selftest.sh` ``, `--remote` 의 sign-in · label · branch protection 항목
- 에이전트가 보는 명령 표기(`. script/forge.sh` · `script/forge-selftest.sh`). 권한 허용 목록과 그 제외 목록(`ALLOW_EXCLUDED` 의 네 스크립트)
- GitLab · Jira 어댑터의 미검증 표기
- 아직 셸인 관리 스크립트(`review-mr.sh` · `post-review.sh` · `work-preflight.sh` · `check-open-mrs.sh` · `sync-task-issues.sh` ·
  `create-carryover-issue.sh` · `rollback-work.sh`)와 그 테스트의 forge 페이크 주입 — `script/forge.sh` 자리에 페이크를 덮어 끼운다
- `src/templates/managed/.ai/templates/developer.md` 의 "조회는 `script/forge.sh` 의 함수로만 한다"

바뀐다.

- 어댑터 구현이 `src/harness/forge/` 에 있다. 대상 리포의 `script/forge/` 는 깔리지 않고 정리된다(6절)
- `script/forge.sh` 는 계약 함수마다 `harness forge <함수>` 를 부르는 shim 이다(3-2)
- 새 CLI 명령 `harness forge` · `harness forge-selftest`(3-1 · 3-3). 둘 다 통과 명령이다. `harness forge-setup` 은 라벨 준비를 스스로 하고
  `script/forge-setup.sh` 가 그것을 부른다 — 실행 방향이 스크립트 → CLI 다(3-4)
- 페이크 주입 지점 `HARNESS_FORGE_FAKE`(4절)
- doctor 는 어댑터 모듈의 머리글(docstring)로 미검증을 판정하고, `adapter <kind>` 의 `file is missing` 항목은 없다.
  `HARNESS_FORGE_FAKE` 가 설정되어 있으면 `forge fake` 경고를 낸다. `--remote` 의 forge 호출은 `harness forge` 를 하위 프로세스로
  띄운다(5절)
- forge 어댑터와 표지 읽기의 Python 단위 테스트(8-5). #206 이 둔 자리와 검증 단계를 쓴다
- GitHub 어댑터의 검증 상태는 이 구현으로 돌린 자체 검사 결과로 적는다(9절). `.ai/forge.md` 에 GitHub "어댑터 미검증" 안내가 없다

## 2. 어댑터 패키지 — `src/harness/forge/`

### 2-1. 모듈

| 모듈 | 갖는 것 |
|---|---|
| `contract.py` | 계약 함수 표(이름 · 군 · 인자 · 출력 · 설명), 정규화 dataclass, `ForgeError` · `ContractError`, 머리글 표지 규칙. 모듈 머리글(docstring)이 계약 서술의 정본이다 |
| `github.py` · `gitlab.py` · `jira.py` | forge 하나의 구현 — 트래커 군 클래스와 리뷰 호스트 군 클래스. CLI 이름과 응답 형태를 여기서만 안다. 모듈 머리글에 `검증 상태:` 줄을 둔다 |
| `shell.py` | `HARNESS_FORGE_FAKE` 가 가리키는 셸 파일의 함수를 계약 함수로 부르는 구현(4절) |
| `__init__.py` | `load(cfg, root)` · `call(forge, name, args)` · `Forge`(2-12) |
| `selftest.py` | 자체 검사(3-3) |

`contract.py` 머리글은 표지 규칙을 이렇게 적는다 — "어댑터 모듈 머리글의 `검증 상태:` 줄이 검증 상태의 표지다. 실제 forge 로
`script/forge-selftest.sh` 를 통과하기 전의 어댑터는 `검증 상태: 미검증` 을 적는다. `harness doctor` 는 머리글의 이 표지로만 미검증을
판정한다."

`src/harness/format.py` 의 `markers(root)` 는 하네스 루트의 `<root>/script/harness-format.sh` 를 실행하지 않고 텍스트로
읽어 `FMT_*` 의 이름과 값을 사전으로 돌려준다.

- `#` 로 시작하는 줄과 빈 줄은 건너뛴다. 나머지 줄은 모두 `FMT_<대문자 · 숫자 · _>='<값>'` 한 줄 대입이다. 값은 두 홑따옴표 사이의
  문자 그대로이고 `'` 를 담지 않는다
- 파일이 없거나 일반 파일이 아니거나 읽지 못하거나, 위 형식이 아닌 줄이 있으면 그 경로를 적은 `FormatError` 를 낸다
- 표지의 정본은 `script/harness-format.sh` 이고 Python 쪽에 사본을 두지 않는다. Python 코드는 표지를 이 함수로만 읽는다
- `format.py` 는 #210 의 시크릿 스캔도 쓴다. #209 · #210 가운데 먼저 머지되는 쪽이 이 정의로 만든다

자체 검사가 이것으로 `FMT_ISSUE_WORK` · `FMT_ISSUE_RELATES` · `FMT_MR_CLOSES` 를 읽는다.

### 2-2. 계약 함수

이슈 트래커 군:

| 함수 | 표준 출력 | 종료 코드 |
|---|---|---|
| `tracker_require` | 없음 | 0. CLI 가 PATH 에 없으면 표준 오류 `error: <cli> is not installed` 와 2 |
| `tracker_issue_view <id>` | 이슈 정규화 JSON 객체 | 0 · 실패 1 |
| `tracker_issue_list` | 열린 · 닫힌 이슈 전부의 정규화 JSON 배열(전 페이지) | 0 · 실패 1 |
| `tracker_issue_create <제목> <본문파일> <라벨> <담당자> <마일스톤>` | 만든 이슈의 식별자 한 줄. 식별자를 찾지 못하면 빈 출력 | 0 · 실패 1 |
| `tracker_issue_note <id> <본문>` | 없음 — 이슈 댓글 1건 | 0 · 실패 1 |
| `tracker_issue_close <id> <라벨>` | 없음 — 라벨이 비지 않으면 먼저 붙이고 닫는다 | 0 · 실패 1 |
| `tracker_current_user` | 현재 사용자명 한 줄 | 0 · 실패 1 |
| `tracker_auth` | 없음 | 0 = 로그인됨. 1 = 아님 — 표준 오류에 어댑터의 고정 안내 한 줄. 그 밖 = 확인하지 못함. CLI 의 출력을 옮기지 않는다 |
| `tracker_labels` | 트래커 라벨 이름 전부의 JSON 문자열 배열(전 페이지) | 0 · 실패 1. 라벨을 미리 두지 않는 트래커는 출력 없이 3 |
| `tracker_labels_ensure <라벨> ...` | 없음 — 라벨이 트래커에 있게 한다. 이미 있으면 성공. 빈 인수는 건너뛰고 인수가 없으면 아무것도 하지 않는다 | 0 · 하나라도 못 만들면 1 과 표준 오류에 어느 라벨이 왜 실패했는지 |

리뷰 호스트 군:

| 함수 | 표준 출력 | 종료 코드 |
|---|---|---|
| `review_require` | 없음 | `tracker_require` 와 같다 |
| `review_mr_view <n>` | 리뷰 요청 정규화 JSON 객체 | 0 · 실패 1 |
| `review_mr_diff <n>` | unified diff — CLI 출력 그대로 | 0 · 실패 1 |
| `review_mr_labels_set <n> <붙일것> <뗄것>` | 없음 — 둘 다 공백 구분 목록이고 빈 문자열을 받는다 | 0 · 실패 1 |
| `review_mr_threads <n>` | 리뷰 스레드 전수의 정규화 JSON 배열 | 0 · 실패 1 |
| `review_mr_note_inline <n> <파일> <줄> <본문>` | CLI 의 표준 출력 그대로 | 0 · 실패(diff 밖 줄 포함) 1 |
| `review_mr_note_summary <n> <본문파일>` | CLI 의 표준 출력 그대로 | 0 · 실패 1 |
| `review_mr_thread_reply <n> <스레드id> <본문>` | 없음 — 기존 스레드에 답글 1건 | 0 · 없는 id 면 1 |
| `review_mr_list_open` | 열린 리뷰 요청 전부의 정규화 JSON 배열 | 0 · 실패 1 |
| `review_mr_close <n>` | 없음 — 닫는다. **머지하지 않는다** | 0 · 실패 1 |
| `review_auth` | 없음 | `tracker_auth` 와 같다 |
| `review_branch_protected <브랜치>` | 보호되어 있으면 `true`, 아니면 `false` 한 줄 | 0 · 판단하지 못하면 1 |

공통:

| 함수 | 표준 출력 | 종료 코드 |
|---|---|---|
| `forge_require` | 없음 — `tracker_require` 다음 `review_require` | 0 · 어느 쪽이든 실패하면 2 |
| `harness_issue_open_mrs <id>` | 그 이슈에 걸린 **열린** 리뷰 요청 번호를 공백으로 이은 한 줄. 없으면 빈 줄 | 0 · 실패 1 |

모든 함수에 걸리는 규칙:

- 위 표에 정한 코드가 없는 실패 — CLI 가 실패했거나 응답을 해석하지 못함 — 는 1 이다
- 처리하지 못한 예외는 종료 코드 2 와 표준 오류 한 줄 `error: <함수>: <예외 이름>` 이다
- JSON 출력은 `json.dumps(값, ensure_ascii=False)` 의 기본 구분자 직렬화이고 끝에 줄바꿈이 없다. 한 줄 출력은 값 뒤에 줄바꿈 하나다
- 실패한 함수는 계약 출력을 내지 않는다 — 일부만 읽은 목록을 표준 출력에 내지 않는다
- `tracker_auth` · `tracker_labels` · `review_auth` · `review_branch_protected` 는 읽기만 한다

### 2-3. 정규화 dataclass

| 클래스 | JSON 키 (이 순서) | 값의 타입 |
|---|---|---|
| `Issue` | `iid` · `title` · `state` · `description` · `labels` · `assignee` · `milestone` | `labels` 는 문자열 배열, 나머지는 문자열 |
| `MergeRequest` | `iid` · `source_branch` · `head_sha` · `description` · `labels` · `state` | `labels` 는 문자열 배열, 나머지는 문자열 |
| `Thread` | `id` · `inline` · `path` · `line` · `notes` | `id` 는 문자열 또는 null(답글을 받지 않는 노트), `inline` 은 불리언, `path` 는 문자열, `line` 은 정수 또는 빈 문자열, `notes` 는 `Note` 배열 |
| `Note` | `body` · `created_at` | 문자열 |

- 값이 없는 자리는 빈 문자열(`labels` 는 빈 배열)이고 키를 빼지 않는다
- 시스템 노트(라벨 변경 · 커밋 추가 안내)는 스레드에 들지 않는다
- `to_json()` 은 위 키 순서의 사전을 낸다
- `from_json(값)` 은 엄격하다. 객체가 아니거나 키가 빠지거나 타입이 다르면 `ContractError` 이고, 메시지는 어긴 내용을 적는다
  (`missing keys: head_sha` · `not an object: list` 처럼)

### 2-4. 오류

| 클래스 | 뜻 | `call()` 에서 |
|---|---|---|
| `ForgeError(code, message)` | 계약이 정한 실패 — CLI 가 없음(2) · CLI 실패나 해석 실패(1) · 미로그인(1) · 라벨을 두지 않는 트래커(3) 등 | `code` 가 종료 코드, `message` 가 있으면 표준 오류 |
| `ContractError(message)` | `ForgeError` 의 하위, 코드 2. 주입된 셸 파일(4절)의 출력이 계약을 어김 — 타입 메서드 경로에서만 난다 | 종료 코드 2 와 메시지 |

### 2-5. 어댑터별 CLI 호출

빈 값을 받는 옵션(`[--label <라벨>]` 등)은 그 값이 비면 옵션째 뺀다. `{owner}/{repo}` · `:id` 는 CLI 가 푸는 자리표시다.

이슈 트래커 군:

| 함수 | GitHub (`gh`) | GitLab (`glab`) | Jira (`jira`) |
|---|---|---|---|
| `tracker_issue_view` | `issue view <id> --json number,title,state,body,labels,assignees,milestone` | `api projects/:id/issues/<id>` | `issue view <id> --raw` |
| `tracker_issue_list` | `api --paginate repos/{owner}/{repo}/issues?state=all&per_page=100`. `pull_request` 키가 있는 항목을 뺀다 | `projects/:id/issues` 를 페이지 순회 | `issue list -q "ORDER BY created ASC" --raw --paginate <from>:100` 를 `total` 까지 |
| `tracker_issue_create` | 라벨 준비(2-8) → `issue create --title <제목> --body-file <본문> [--label] [--assignee] [--milestone]`. 출력 줄 가운데 `/<숫자>` 뒤에 숫자 아닌 문자만 오는 마지막 줄의 그 숫자 | `issue create --title <제목> --description <본문> [--label] [--assignee] [--milestone]`. 식별자는 GitHub 과 같은 규칙 | `issue create --no-input -t <issues.type> -s <제목> -T <본문 파일> [-l] [-a] [--fix-version] --raw`. 출력이 `key` 를 가진 JSON 객체면 그 값, 아니면 출력에서 단어 경계로 감싼 `[A-Z][A-Z0-9_]+-[0-9]+` 의 마지막 |
| `tracker_issue_note` | `issue comment <id> --body <본문>` | `issue note create <id> -m <본문>` | `issue comment add <id> <본문> --no-input` |
| `tracker_issue_close` | 라벨이 비지 않으면 라벨 준비 → `issue edit <id> --add-label <라벨>`. 그 뒤 `issue close <id> --reason "not planned"` | 라벨이 비지 않으면 `issue update <id> --label <라벨>`. 그 뒤 `issue close <id>` | 라벨이 비지 않으면 `issue edit <id> --no-input -l <라벨>`. 그 뒤 `issue move <id> <issues.closed_status>` |
| `tracker_current_user` | `api user -q .login` | `api user` 의 `username` | `me` |
| `tracker_auth` | `auth status` 가 0 이면 0. 아니면 ``run `gh auth login` `` 과 1 | `auth status` · ``run `glab auth login` `` | `me` · ``run `jira init` `` |
| `tracker_labels` | `api --paginate repos/{owner}/{repo}/labels?per_page=100` 의 `name` | `projects/:id/labels` 를 페이지 순회한 `name` | CLI 를 부르지 않고 3 |
| `tracker_labels_ensure` | 라벨 준비(2-8) | 라벨 준비(2-8) | CLI 를 부르지 않고 0 |

리뷰 호스트 군:

| 함수 | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| `review_mr_view` | `pr view <n> --json number,headRefName,headRefOid,body,labels,state` | `mr view <n> -F json` |
| `review_mr_diff` | `pr diff <n>` | `mr diff <n> --color=never` |
| `review_mr_labels_set` | 붙일 라벨의 라벨 준비 → `pr edit <n> [--add-label <l>]… [--remove-label <l>]…` | `mr update <n> [--label <l>]… [--unlabel <l>]…` |
| `review_mr_threads` | `api repos/{owner}/{repo}/pulls/<n>/comments?per_page=100 --paginate` 와 `api repos/{owner}/{repo}/issues/<n>/comments?per_page=100 --paginate`. 인라인 댓글은 `in_reply_to_id` 로 루트에 묶는다 — 루트 id 가 스레드 id 이고 답글은 `created_at` 순으로 루트 뒤에 온다. `line` 은 `line`, 없으면 `original_line`. 일반 댓글은 하나씩 `id: null` · `inline: false` 스레드다. 두 조회의 종료 코드는 판정에 쓰지 않는다 — 실패한 조회는 빈 목록으로 든다 | `projects/:id/merge_requests/<n>/discussions` 를 페이지 순회. 시스템 노트를 빼고 남는 노트가 없으면 그 discussion 을 뺀다. `individual_note` 가 false 면 `id` 는 discussion id 의 문자열, 아니면 null. `inline` 은 id 가 있고 첫 노트에 `position` 이 있을 때 참. `path` 는 `new_path`, 없으면 `old_path`. `line` 은 `new_line`, 없으면 `old_line` |
| `review_mr_note_inline` | `pr view <n> --json headRefOid -q .headRefOid` → `api repos/{owner}/{repo}/pulls/<n>/comments -f path=<파일> -F line=<줄> -f side=RIGHT -f commit_id=<sha> -f body=<본문>` | `mr note create <n> --file <파일> --line <줄> -m <본문>` |
| `review_mr_note_summary` | `pr comment <n> --body-file <본문>` | `mr note create <n> --resolvable=false -m <본문>` |
| `review_mr_thread_reply` | `api repos/{owner}/{repo}/pulls/<n>/comments/<스레드id>/replies -f body=<본문>` | `api --method POST projects/:id/merge_requests/<n>/discussions/<스레드id>/notes -f body=<본문>` |
| `review_mr_list_open` | `api --paginate repos/{owner}/{repo}/pulls?state=open&per_page=100`. `head.ref` · `head.sha` 를 브랜치 · head 로 | `projects/:id/merge_requests?state=opened` 를 페이지 순회 |
| `review_mr_close` | `pr close <n>` | `mr close <n>` |
| `review_auth` | `tracker_auth` 와 같다 | `tracker_auth` 와 같다 |
| `review_branch_protected` | `api repos/{owner}/{repo}/branches/<b> -q .protected` 가 `true` · `false` 면 그 줄. 그 밖 출력이나 실패면 1 | `api projects/:id/protected_branches/<b 를 경로 한 칸으로 인코딩>` 이 성공하면 `true`. 실패하고 오류 출력에 `404` 가 있으면 `false`. 그 밖이면 1 |
| `harness_issue_open_mrs` | 기본 구현(2-9) | `projects/:id/issues/<id>/related_merge_requests` 를 페이지 순회해 `state` 가 `opened` 인 것의 `iid` |

- `harness_issue_open_mrs` 는 리뷰 호스트 군에 속한다 — 리뷰 호스트가 GitLab 이면 GitLab 구현, 아니면 기본 구현이다
- Jira 는 리뷰 호스트 군에 `review_mr_thread_reply` 하나만 둔다. 표준 오류
  `error: jira does not host code review — review thread replies are not supported` 와 2 로 끝난다. 설정 검증이 리뷰 호스트로 Jira 를
  받지 않으므로 `load()` 가 고르는 일은 없다
- `*_require` 는 CLI 이름(`gh` · `glab` · `jira`)이 PATH 에 있는지만 본다

### 2-6. 정규화

이슈:

| 키 | GitHub | GitLab | Jira |
|---|---|---|---|
| `iid` | `number` 의 문자열 | `iid` 의 문자열 | `key` |
| `title` | `title` | `title` | `fields.summary` |
| `state` | `state` 의 소문자 | `state` | `fields.status.statusCategory.key` 가 `done` 이면 `closed`, 아니면 `opened` |
| `description` | `body` | `description` | `fields.description` 을 평문으로 누르고 앞뒤 공백을 뺀 것 |
| `labels` | `labels` 의 `name`. 항목이 문자열이면 그대로 | GitHub 과 같다 | `fields.labels` |
| `assignee` | `assignees[0].login` | `assignees[0].username` | `fields.assignee.displayName` |
| `milestone` | `milestone.title` | `milestone.title` | `fields.fixVersions[0].name` |

리뷰 요청:

| 키 | GitHub | GitLab |
|---|---|---|
| `iid` | `number` 의 문자열 | `iid` 의 문자열 |
| `source_branch` | `headRefName` (목록은 `head.ref`) | `source_branch` |
| `head_sha` | `headRefOid` (목록은 `head.sha`) | `diff_refs.head_sha`, 없으면 `sha` |
| `description` | `body` | `description` |
| `labels` | 이슈와 같다 | 이슈와 같다 |
| `state` | `state` 의 소문자 | `state` |

- 원본 값이 없거나 null 이면 빈 문자열이다
- Jira 응답은 이슈 객체 하나, `issues` 배열을 가진 객체, 배열 가운데 무엇이든 받는다
- Jira 평문 누르기: 문자열은 그대로, 배열은 항목을 이어 붙인다. `text` 노드는 그 `text`, `hardBreak` · `rule` 은 줄바꿈 하나,
  `paragraph` · `heading` · `codeBlock` 은 내용 뒤에 줄바꿈 둘, 그 밖 노드는 내용이다. 객체가 아닌 값은 빈 문자열이다

### 2-7. 페이지네이션

| forge | 규칙 |
|---|---|
| GitHub | `api --paginate` 는 페이지마다 JSON 배열을 이어 붙여 낸다. 앞에서부터 JSON 값을 하나씩 읽어(값 사이 공백 허용) 합친다. 배열이 아닌 값이 나오면 실패다. `gh` 가 실패하면 출력이 일부 있어도 실패다. 스레드의 두 조회만은 배열이 아닌 값을 항목 하나로 넣는다 |
| GitLab | 경로에 `per_page=100&page=<N>` 을 `?` 또는 `&` 로 붙여 N=1 부터 읽는다. 응답이 배열이 아니면 표준 오류 `error: list response is not an array: <경로>` 와 실패. 빈 배열이거나 100 개보다 적으면 끝이다 |
| Jira | `--paginate <from>:100` 을 from=0 부터 읽는다. 응답이 객체면 `issues`, 배열이면 그 자체가 이번 항목이고 배열이 아니면 실패다. `total` 이 없으면 이번 항목 수다. 항목이 0 개면 끝, from 에 항목 수를 더해 `total` 이상이면 끝이다 |

### 2-8. 라벨 준비

GitHub — 인수 순서대로, 빈 라벨은 건너뛴다.

1. `label create <라벨> --color ededed`. 성공이면 다음 라벨
2. 실패하면 `api repos/{owner}/{repo}/labels/<라벨을 경로 한 칸으로 인코딩(빗금 포함)> --jq .name`. 성공이면 이미 있는 것이므로 다음 라벨
3. 그것도 실패하면 표준 오류에 ``error: could not create label `<라벨>` `` 과, 1 의 오류 출력에서 빈 줄이 아닌 마지막 줄을 두 칸
   들여 쓴 줄을 내고 1. 뒤 라벨로 가지 않는다

GitLab — 라벨마다 `label create --name <라벨> --color "#ededed"`. 실패하고 오류 출력에 `already exists` 나 `409` 가 있으면 성공이다.
그 밖의 실패는 GitHub 3 과 같은 두 줄과 1.

GitHub 의 `tracker_issue_create` · `tracker_issue_close` · `review_mr_labels_set` 은 라벨 준비가 실패하면 이슈 · 리뷰 요청을
바꾸는 호출 전에 1 로 끝난다.

### 2-9. 열린 리뷰 요청 찾기 — 기본 구현

forge 기능이 아니라 하네스 자신의 문법에서 도출한다. `review_mr_list_open` 의 항목 가운데 다음 둘 중 하나에 맞는 것의 `iid` 를
목록 순서대로 공백으로 잇는다. `<이슈>` 와 `<키워드>` 는 정규식 문자 그대로 넣는다.

- `source_branch` 가 `^[A-Za-z]+/<이슈>(?:[^0-9A-Za-z]|$)` 에 맞는다
- `description` 이 대소문자를 가리지 않고 `\b<키워드>\s+\S*<이슈>(?![0-9A-Za-z])` 를 포함한다

`<키워드>` 는 2-11 이 정한다. 목록 조회가 실패하면 1.

### 2-10. 입출력 처리

- **작업 디렉터리**: 어댑터의 CLI 호출은 하네스 루트에서 돈다
- **표준 입력**: `*_auth` · GitHub 의 `api --paginate` 목록 조회(이슈 · 라벨 · 열린 리뷰 요청) · GitLab 의 `tracker_labels` · 라벨 이름
  조회(2-8 의 2) · GitLab 라벨 생성 · `review_branch_protected` 의 호출은 표준 입력을 닫는다. 그 밖의 호출은 물려받는다
- **CLI 의 표준 오류**: 흘려보낸다. 예외 — `*_auth` 는 버리고 고정 안내 한 줄만 낸다. 라벨 생성 실패는 끝 줄만 옮긴다(2-8). 라벨 이름
  조회는 버린다. GitLab `review_branch_protected` 는 판정에만 쓰고 버린다
- **CLI 의 표준 출력**: 계약 출력으로 바꾸거나 버린다. `review_mr_diff` · `review_mr_note_inline` · `review_mr_note_summary` · Jira 의
  `tracker_current_user` 는 그대로 흘려보낸다
- **본문**: `tracker_issue_create` 와 `review_mr_note_summary` 의 본문은 문자열로 받는다. CLI 에 넘기는 방식(표준 입력 또는 임시 파일)은
  어댑터가 정하고, 임시 파일은 0600 으로 만들어 호출이 끝나면 지운다. GitLab 은 본문 끝의 줄바꿈을 뺀 문자열을 인수로 넘긴다
- **실행기**: 어댑터는 CLI 실행을 생성자로 받은 실행기 하나로 한다. 기본 실행기는 subprocess 다. 단위 테스트는 실행기를 바꿔 끼워
  CLI 없이 돈다(8-5)

### 2-11. 설정에서 오는 값

| 값 | 출처 | 쓰는 곳 |
|---|---|---|
| 이슈 유형 | `issues.type` | Jira `tracker_issue_create` 의 `-t` |
| 닫힘 상태 이름 | `issues.closed_status` | Jira `tracker_issue_close` 의 `issue move` |
| 종료 참조 키워드 | 환경 변수 `ISSUE_CLOSES_KEYWORD`. 없거나 비면 `Closes` | 2-9 |

`load()` 가 설정에서 읽어 어댑터에 넘긴다. 어댑터는 `script/harness.env` 를 읽지 않는다.

### 2-12. `load()` · `Forge` · `call()`

- `load(cfg, root)` — `HARNESS_FORGE_FAKE` 가 있으면 셸 구현(4절)을, 없으면 `forge.tracker` 의 트래커 군과 `forge.review_host` 의 리뷰
  호스트 군을 묶은 `Forge` 를 돌려준다. 환경 변수는 이 함수 한 곳에서만 읽는다
- `Forge` 는 계약 함수 24개를 같은 이름의 메서드로 갖는다. 반환값은 출력 종류를 따른다 — JSON 객체는 `Issue` · `MergeRequest`, 배열은
  그 클래스나 `Thread` 의 리스트 또는 문자열 리스트, 한 줄은 문자열(`review_branch_protected` 는 불리언, `harness_issue_open_mrs` 는
  문자열 리스트), 출력 없음은 `None`. 실패는 `ForgeError` 다. 예: `forge.review_mr_view("12")` → `MergeRequest`
- `call(forge, name, args)` — 계약 함수 하나를 부르고 `(종료 코드, 표준 출력, 표준 오류)` 를 셸 계약의 모양 그대로 돌려준다.
  Python 어댑터면 메서드의 반환값을 2-2 의 규칙으로 직렬화하고 `ForgeError` 를 종료 코드 · 표준 오류로 바꾼다. 셸 구현이면 셸 함수의
  세 값을 손대지 않고 돌려준다 — 페이크의 계약 위반이 자체 검사에 그대로 보여야 한다
- 셸 호출부 · 자체 검사 · 라벨 준비 · doctor 는 `call()` 의 결과를 쓴다

## 3. 진입점

### 3-1. `harness forge [--target DIR] <함수> [인수...]`

- 통과 명령이다 — `harness [--target DIR] forge <함수> [인수...]`. 인자를 나누는 규칙과 그 오류는 #206 3-3 의 "인자 통과" 다.
  하네스 루트는 명령 이름 앞의 `--target DIR`, 또는 명령 이름 바로 뒤의 `--target DIR` 하나다(둘 다 주면 #206 3-3 의 오류와 2).
  그다음 인자가 함수 이름이고, 함수 이름부터 뒤는 그대로 함수 인수다 — `-` 로 시작하는 본문(`--help` · `--target` 포함)도 인수다
- 공유 설정을 읽고 검증한 뒤 `load()` · `call()` 로 함수 하나를 부르고, 그 표준 출력 · 표준 오류 · 종료 코드를 그대로 낸다.
  그 밖에는 아무것도 출력하지 않는다
- 본문 파일 자리(`tracker_issue_create` 의 둘째 인수, `review_mr_note_summary` 의 둘째 인수)는 `-` 만 받고 본문을 표준 입력에서 읽는다.
  이 명령이 받는 경로 인수는 `--target` 뿐이다
- `review_mr_note_inline` 의 `<파일>` 은 리뷰 요청 diff 안의 경로로 forge 에 넘기는 데이터다. CLI 가 열지 않는다
- 오류는 모두 종료 코드 2 와 표준 오류다

| 경우 | 표준 오류 |
|---|---|
| 함수 이름이 없다 | `usage: harness forge [--target DIR] <function> [args...]` |
| 모르는 함수 | `error: unknown forge function: <이름>` |
| 인수 개수가 다르다 (`tracker_labels_ensure` 는 개수 제한 없음) | `error: <함수> takes <인자 목록>` |
| 본문 자리가 `-` 가 아니다 | `error: <함수> reads the body from standard input — pass -` |
| 설정을 읽지 못하거나 검증에 걸린다 | 다른 명령과 같은 설정 오류 |

### 3-2. `script/forge.sh` — source 하는 shim

- 생성 파일이다. 원형은 `src/templates/generated/script/forge.sh` 이고, render 가 계약 함수 표(`contract.py`)로 머리글의 함수 표와 함수
  정의를 채운다. 설정 값은 들어가지 않으므로 forge 설정이 달라도 내용이 같다
- source 전용이다. source 하는 순간 둘을 정한다
  - 하네스 루트: source 하는 스크립트(`$0`)가 있는 디렉터리의 부모. 거기 `script/forge.sh` 가 없으면 현재 디렉터리. 둘 다 아니면 표준 오류
    `error: could not locate the harness root from <현재 디렉터리>` 와 함께 2 로 돌아간다
  - CLI: `<루트>/.harness/bin/harness`, `<루트>/src/bin/harness` 순으로 처음 실행 가능한 것
- 계약 함수마다 한 줄 정의다 — `<CLI> --target <루트> forge <함수> "$@"` 를 부르고 그 종료 코드를 돌려준다. 본문 파일 자리 함수는 그
  파일을 표준 입력으로 넘기고 그 자리에 `-` 를 둔다. 현재 디렉터리를 바꾸지 않는다
- CLI 를 찾지 못하면 함수는 표준 오류 두 줄 `error: harness CLI not found under <루트> (.harness/bin/harness or src/bin/harness)` ·
  `help: harness install --target <루트>` 를 내고 2 로 돌아간다
- 머리글: 생성 파일이니 고치지 않는다는 문구, source 방법(하네스 루트에서, 모노레포면 그 서브프로젝트), 계약 함수 표(2-2 의 이름 ·
  인자 · 출력), 정규화 JSON 형태, 계약 정본이 CLI 패키지의 `forge/contract.py` 라는 것

### 3-3. `harness forge-selftest` · `script/forge-selftest.sh`

`harness forge-selftest [--target DIR] [--write|--create-issue] <리뷰요청번호> [이슈번호]` 는 어댑터가 계약을 지키는지 실제 forge 를
상대로 확인한다. 3-1 과 같은 통과 명령이다 — 하네스 루트는 #206 3-3 대로 명령 이름 앞이나 바로 뒤의 `--target DIR` 하나이고,
그 뒤 인자는 전부 자체 검사의 인자다.

`script/forge-selftest.sh`(관리 파일)는 실행하는 shim 이다.

1. 자기 파일이 있는 디렉터리의 부모를 하네스 루트로 잡는다
2. `<루트>/.harness/bin/harness`, `<루트>/src/bin/harness` 순으로 실행 가능한 첫 것을 CLI 로 고른다
3. `<CLI> --target <루트> forge-selftest <받은 인자 그대로>` 로 exec 한다

- 현재 디렉터리 · 표준 입출력 · 환경을 바꾸지 않고, 설정과 생성물을 읽지 않는다. 종료 코드는 CLI 의 것이다
- 첫 줄은 `#!/usr/bin/env sh` 이고 `bash <파일>` 로도 돈다. 머리글은 부르는 명령의 이름과 로직이 CLI 패키지에 있다는 것을 적는다
- CLI 를 찾지 못하면 3-2 와 같은 두 줄을 표준 오류에 내고 2
- 이 형태와 문구는 다른 이식 이슈(#211 · #213)의 shim 과 같다

인자와 종료 코드:

| 경우 | 동작 |
|---|---|
| 리뷰 요청 번호가 없다 | 표준 오류 `usage: script/forge-selftest.sh [--write\|--create-issue] <review-request-number> [issue-number]` 와 2 |
| `--create-issue` 인데 이슈 번호가 없다 | `error: --create-issue needs an issue number to inherit from` 과 위 usage, 2 |
| 모르는 옵션 | `error: unknown option: <옵션>` 과 위 usage, 2 |
| 표지를 읽지 못한다 — `markers()` 의 `FormatError`, 또는 쓰는 키(2-1)가 없다 | `error: cannot read the markers from <루트>/script/harness-format.sh` 와 2 |
| 전 항목 통과 | 0 |
| 실패한 항목이 있다 | 1 |

공유 설정을 읽는다. 설정에서 읽는 값은 `derive()` 가 `script/harness.env` 에 쓰는 것과 같다 — `forge.tracker` · `forge.review_host` · `branches.base` ·
`review.round_label` · `issues.labels` · `issues.deletion_forbidden`. 함수는 `load()` 한 `Forge` 에 `call()` 로 부른다.

출력: 첫 줄 `forge adapter selftest — tracker=<tracker> · review_host=<host>`, 빈 줄, 단계 머리 줄, 항목 줄. 항목 줄은 통과
`  ok    <항목>`, 실패 `  FAIL  <항목> — <이유>`(표준 오류), 건너뜀 `  skip  <항목> — <이유>` 다. 실패 이유가 함수의 표준 오류면 그 첫 줄이다.

| 단계 | 머리 줄 | 항목 — 통과 조건 |
|---|---|---|
| 1 | `1. reads — nothing is left behind` | `forge_require` — 0 · `tracker_current_user → <사용자>` — 출력이 비지 않음(실패 이유 `empty (<표준 오류 첫 줄>)`) · `review_mr_view shape` — 객체이고 `iid` `source_branch` `head_sha` `description` `labels` `state` 를 가짐 · `review_mr_view head_sha` — 16진 숫자로 시작하고 7자 이상 · `review_mr_view source_branch` — 비지 않음 · `review_mr_diff` — `diff --git` 으로 시작하는 줄 · `review_mr_threads shape` — 배열이고 첫 항목이 `id` `inline` `path` `line` `notes` 를 가짐(빈 배열 통과) · `review_mr_list_open shape` — 배열이고 첫 항목이 `iid` `source_branch` `description` 을 가짐 · `tracker_auth` · `review_auth` — 0 · `tracker_labels` — 0 과 JSON 문자열 배열, 또는 3 과 빈 출력(이때 항목 이름 `tracker_labels — this tracker keeps no labels`) · `review_branch_protected <base> → <값>` — 0 과 `true` 또는 `false` 한 줄 |
| 1 (이슈 번호가 있을 때) | | `tracker_issue_view shape` — 객체이고 `iid` `title` `state` `description` `labels` `assignee` `milestone` 을 가짐 · `tracker_issue_view iid matches` — `iid` 가 준 번호 · `tracker_issue_list shape` — 배열이고 첫 항목이 `iid` `title` `state` 를 가짐 · `tracker_issue_list contains the target issue (<N> total)` — 준 번호가 목록에 있음 · `tracker_labels_ensure` — 설정의 이슈 라벨 셋으로 0 · `harness_issue_open_mrs finds this review request` — 출력에 준 리뷰 요청 번호(실패 이유에 브랜치 형식 `<tag>/<이슈>-...` 와 본문의 `<FMT_MR_CLOSES> <이슈>` 를 안내) |
| 1 (이슈 번호가 없을 때) | | `skip  tracker_* (4 functions) — no issue number was given` |
| 2 (`--write` · `--create-issue`) | `2. writes — this leaves traces on review request <n>` | `review_mr_labels_set add` · `review_mr_labels_set remove` — 탐침 라벨 `<round_label>:selftest` 을 붙이면 조회에 나오고 떼면 사라짐 · `review_mr_note_inline appears inline in threads` — diff 의 첫 추가 줄에 단 탐침이 inline 스레드로 나옴 · `review_mr_thread_reply lands at the end of the thread it names` — 그 스레드 id 로 단 답글이 그 스레드 `notes` 의 마지막 · `review_mr_thread_reply fails for an unknown thread` — 스레드 id `0` 에 0 이 아닌 코드 · `review_mr_note_inline fails outside the diff range` — 줄 999999 에 0 이 아닌 코드 · `review_mr_note_summary appears in threads` — 요약 탐침이 스레드에 나옴. diff 에서 대상 줄을 고르지 못하면 `skip  review_mr_note_inline` |
| 2 (읽기 전용) | `2. writes — skipped (enable with --write)` | skip 두 줄 — 쓰기 함수 넷, `tracker_issue_create` |
| 3 (`--create-issue`) | `3. issue creation — this cannot be undone` | `issues.deletion_forbidden` 이면 표준 오류 경고 한 줄 · `tracker_issue_create → <식별자>` — 설정의 task 라벨과 준 이슈의 담당자 · 마일스톤으로 만든 이슈의 식별자가 비지 않음 · `tracker_issue_create returns an identifier that reads back` — 그 식별자로 `tracker_issue_view` 한 `iid` 가 같음. 끝에 `  a person closes the issue it created: <식별자>` |
| 3 (그 밖) | `3. issue creation — skipped (enable with --create-issue)` | `--write` 면 skip 한 줄 |

- 3 단계가 만드는 이슈의 제목은 `자체 검사 — 어댑터 계약 확인`, 본문은 `## <FMT_ISSUE_WORK>` 절(어댑터 자체 검사가 만든 이슈이고 닫아도
  된다는 한 줄)과 `## 상위` 절(`- <FMT_ISSUE_RELATES> <이슈>`)이다
- 판정 줄 `pass <N> · fail <N> · skip <N>`. 실패가 있으면 표준 오류
  `the adapter does not honour the contract — do not use this forge until it is fixed` 와 1. 건너뛴 것이 있으면
  `some checks were skipped — the adapter counts as verified only once all of them run` 과 0. 전부 돌았으면
  `all 18 contract functions checked — clear the unverified note in the adapter header:` 뒤에 트래커 · 리뷰 호스트의 어댑터 모듈 경로
  (`   src/harness/forge/<kind>.py`, 종류마다 한 줄)와 0

### 3-4. `harness forge-setup` · `script/forge-setup.sh`

`harness forge-setup [--target DIR]` 은 사람이 부르는 원격 쓰기 명령이다. 절차 · 훅 · 다른 명령이 부르지 않는다.

1. `load()` 한 `Forge` 에 `tracker_require` — 실패하면 그 표준 오류를 내고 2
2. `tracker_labels_ensure <requirement> <task> <invalid>` (`issues.labels`) — 실패하면 그 표준 오류 뒤에
   `stop: could not prepare labels on <tracker>` 를 표준 오류로 내고 2
3. 표준 출력 `forge-setup: labels ready on <tracker>: <빈 값을 뺀 라벨을 ", " 로 이은 것, 없으면 none>` 과 0

`script/forge-setup.sh`(관리 파일)는 3-3 과 같은 형태의 shim 이고 `<CLI> --target <루트> forge-setup <받은 인자 그대로>` 로 exec 한다.
CLI 를 찾지 못하면 3-2 와 같은 두 줄과 2. `harness forge-setup` 은 통과 명령이 아니다 — 공용 파서로 인자를 받고, 위치 인자를 쓰지 않는다.
공유 설정을 읽는다.

만드는 것은 설정의 이슈 라벨뿐이다. 회차 라벨은 `review_mr_labels_set` 이 붙일 때 만든다.

### 3-5. 명령 등록

- `COMMANDS` 에 둘을 더한다. 항목은 #206 3-3 의 `(통과, 설정이 필요한가, 인수, 설명)` 이고, 둘 다 통과 명령이며 설정이 필요하다
  - `"forge": (True, True, "<function> [args...]", "call one forge adapter function — script/forge.sh calls this; write functions write to the remote")`
  - `"forge-selftest": (True, True, "[--write|--create-issue] <review-request> [issue]", "check the forge adapters against the real forge (--write and --create-issue leave traces)")`
- `forge-setup` 항목은 통과 표시가 `None` 그대로다
- `DELEGATES` 에 `forge` · `forge-selftest` 를 더한다(`forge-setup` 은 이미 있다). 어댑터는 고정 사본의 패키지에 있으므로 고정된 버전이
  답한다
- 권한 허용 목록은 바뀌지 않는다. `harness forge` 는 쓰기 함수(`tracker_issue_create` · `tracker_issue_close` · `review_mr_close` 등)를
  함께 부르므로 허용 목록에 넣지 않는다. `script/forge-selftest.sh` · `script/forge-setup.sh` 는 관리 스크립트로 남아 `ALLOW_EXCLUDED`
  그대로 허용 목록에서 빠진다. `script/forge.sh` 는 생성 파일이라 허용 목록에 들지 않는다

## 4. 페이크 주입 — `HARNESS_FORGE_FAKE`

### 4-1. 동작

- 값이 비지 않으면 `load()` 는 그 경로의 셸 파일을 forge 로 쓰는 셸 구현을 돌려준다. 트래커 군 · 리뷰 호스트 군 · 공통 함수가 모두 그
  파일에서 온다 — 파일이 정의한 함수가 곧 그 forge 의 함수다
- `call()` 은 함수 하나마다 하네스 루트에서 `sh -c '. "$0" && "$@"' <파일> <함수> <인수...>` 를 실행하고 그 종료 코드 · 표준 출력 ·
  표준 오류를 그대로 돌려준다. 환경(`FAKE_STATE` 등)은 물려받는다. 본문 자리 함수에는 본문을 0600 임시 파일에 써서 그 경로를 넘기고
  끝나면 지운다 — 셸 계약 그대로다
- 타입 메서드(`forge.review_mr_view(…)` 등)는 같은 실행의 표준 출력을 2-3 의 `from_json` 으로 읽는다. 계약을 어긴 출력은
  `ContractError` 다
- 호출마다 새 `sh` 에서 돈다. 페이크의 상태는 파일로만 이어진다

### 4-2. 값 검사

값은 절대 경로이고 일반 파일이어야 한다. 아니면 `load()` 가 `ForgeError(2, "error: HARNESS_FORGE_FAKE must be an absolute path to a regular file")`
를 낸다. 값 자체는 어떤 출력에도 옮기지 않는다.

### 4-3. 알림

- 사람이 부르는 명령은 주입이 켜져 있음을 알린다 — `harness forge-selftest` · `harness forge-setup` 은 표준 오류 첫 줄에
  `note: HARNESS_FORGE_FAKE is set — forge calls go to that file, not the forge` 를 낸다. `harness doctor` 는 `forge fake` 항목을 낸다(5절)
- `harness forge`(함수 호출)는 함수의 출력만 낸다 — 셸 호출부와 doctor 가 그 표준 오류를 읽는다

### 4-4. 신뢰

- PATH 앞 스텁과 같은 신뢰 수준이다. 하네스를 부르는 쪽의 환경이 정하고, 그 환경을 바꿀 수 있는 쪽은 PATH 의 `gh` 도 바꿀 수 있다
- 하네스 · 생성 파일 · CI 설정은 이 값을 설정하지 않는다. 테스트는 명령 하나의 환경에만 주고 테스트 전체에 내보내지 않는다
- 이 주입 지점의 구현은 security-guard 검토를 받는다

### 4-5. 주입 지점 정리

CLI 패키지로 옮긴 로직의 테스트는 아래 넷 가운데 하나로 forge 를 바꿔 끼운다. 셸 호출부를 이식하는 다음 이슈들도 같은 지점을 쓴다.

| 층 | 지점 | 쓰는 곳 |
|---|---|---|
| Python 단위 | 어댑터 생성자의 실행기(2-10) | `src/test/unit/` — 정규화 · 페이지네이션 · 식별자 추출 |
| CLI · Python 호출부 통합 | `HARNESS_FORGE_FAKE=<셸 함수 파일의 절대 경로>` | `render-test.sh` · `script/test-*.sh` 에서 `harness forge` · `forge-selftest` · `forge-setup` · `doctor --remote` 와 셸 shim 을 거치는 호출 |
| forge CLI 응답 | PATH 앞의 `gh` · `glab` · `jira` 스텁 | 어댑터의 CLI 호출과 응답 처리 (`test-forge-labels.sh` · UT-11 · UT-33 · UT-63) |
| 셸 호출부 | `script/forge.sh` 자리에 페이크를 덮어 끼운다 | 아직 셸인 관리 스크립트의 테스트 |

## 5. doctor

### 5-1. 어댑터 검증 상태 — `tools and connections`

- 트래커 · 리뷰 호스트의 종류마다 한 줄 `adapter <kind>` 다. 어댑터 모듈(`harness/forge/<kind>.py`, 실행 중인 CLI 의 패키지)의 머리글이
  `검증 상태: 미검증` 을 가지면 `warn` ``unverified — run `script/forge-selftest.sh` ``, 아니면 `ok`
- 머리글은 모듈 소스의 docstring(`ast.get_docstring`)이다. 주석이나 함수 docstring 에 나오는 같은 낱말은 판정에 쓰지 않는다. 판정 함수는
  모듈 소스 텍스트를 받아 머리글을 돌려준다
- 표지 문자열은 doctor 쪽 상수 하나가 갖는다(`ADAPTER_UNVERIFIED`)
- 어댑터는 CLI 패키지의 모듈이므로 `file is missing` 항목은 없다

### 5-2. `forge fake` 항목

`HARNESS_FORGE_FAKE` 가 비지 않으면 `tools and connections` 의 어댑터 줄 뒤에 `warn` `forge fake` —
`HARNESS_FORGE_FAKE is set — forge calls go to that file, not the forge` 를 낸다. 값은 옮기지 않는다. 설정되어 있지 않으면 줄이 없다.

### 5-3. `--remote` 의 forge 호출

forge 로그인 · 트래커 라벨 · 브랜치 보호 항목의 호출은 실행 중인 CLI 의 진입 스크립트를 `sys.executable` 로
`--target <하네스 루트> forge <함수> <인수...>` 와 함께 `remote_call()` 로 띄운다. 제한 시간 · 닫힌 표준 입력 · 새 세션 · 원격 환경
(`GIT_TERMINAL_PROMPT=0` · `HARNESS_METRICS=off`)과 결과 판정은 그대로다. `HARNESS_FORGE_FAKE` 는 그 환경으로 물려받는다.
CLI 가 forge CLI 를 직접 부르지 않는다.

### 5-4. UI — `src/ui/lib/doctor.js`

- `adapter <kind>` 의 `file is missing` 분기를 지운다. 미검증 문구와 조치(`script/forge-selftest.sh`)는 그대로다
- `forge fake` 경고: 제목 `forge 호출이 페이크로 갑니다`, 본문
  `HARNESS_FORGE_FAKE 가 설정되어 있어 이슈·리뷰 요청 호출이 실제 forge 가 아니라 그 파일로 갑니다. 테스트가 아니면 환경에서 지웁니다.`
  조치 명령은 없다

## 6. 대상 리포의 정리

- `src/templates/managed/script/forge/` 를 지운다. 대상 리포의 `script/forge/` 아래 관리 파일(`_common.sh` · `github.sh` · `gitlab.sh` ·
  `jira.sh`)은 더 깔리지 않으므로 다음 install · render 의 정리(`prune()`)가 지우고 빈 디렉터리도 걷는다
- 이 리포의 `script/forge/` 도 render 가 지운다. 그 삭제는 이 이슈의 커밋에 든다
- 어댑터 코드는 고정 사본 `.harness/lib/harness/forge/` 로 간다(#206 의 고정 사본 범위)

## 7. 문서

| 문서 | 반영할 것 |
|---|---|
| `src/templates/forge/forge.md` | "함수 목록과 출력 계약은 `script/forge/_common.sh` 상단에 있다." → "함수 목록과 출력 계약은 `script/forge.sh` 머리글에 있다. CLI 패키지의 계약 표(`forge/contract.py`)에서 생성된다." |
| `src/templates/forge/github/review.md` | 끝의 "어댑터 미검증" 인용 두 줄을 지운다 — 9절의 기록과 같은 커밋 |
| `src/templates/managed/script/README.md` | 부류 표의 생성 행 `forge.sh` 에 "계약 함수마다 `harness forge` 를 부르는 shim". 목록의 `forge/_common.sh` · `forge/<kind>.sh` 행을 지운다. `forge-selftest.sh` 행은 "shim — `harness forge-selftest` 를 같은 인자로 부른다" 를 더하고, `forge-setup.sh` 행은 "shim — `harness forge-setup` 을 부른다" 로, 호출 시점은 "사람이 1회". 규칙의 "어댑터를 새로 쓰거나 고치면 …" 은 "어댑터(CLI 패키지의 `forge/`)를 새로 쓰거나 고치면 `forge-selftest.sh` 를 실제 forge 로 돌린다. 회귀 테스트는 페이크와 CLI 스텁을 쓰므로 실제 forge 의 응답을 보지 않는다" |
| `src/templates/managed/docs/workflow/README.md` | "어댑터는 `script/forge/` 에 이미 있다" → "어댑터는 CLI 패키지에 이미 있다" |
| `src/templates/managed/docs/workflow/changing.md` | `forge 함수 구현` 행 → `src/harness/forge/<kind>.py` — **한 곳** |
| `src/test/fake-forge.sh` 머리글 | 쓰는 곳 `src/test/render-test.sh`, 끼우는 법(셸 호출부는 `script/forge.sh` 자리, CLI 는 `HARNESS_FORGE_FAKE`) |
| `README.md` | 지원 범위 표의 GitHub 행 "실제 forge 검증" 을 9절의 결과(`자체 검사 전 단계 통과 (gh <버전>)`)로. "계약 위반 6종" → "계약 위반 11종" |
| `docs/spec/59-doctor-remote-readiness.md` | 3절의 어댑터 행과 그 아래 세 줄, 6-1 제목, 6-2 의 어댑터 이름, 6-3 의 `BASE_BRANCH` 출처를 이 명세(2-2 · 2-5 · 3-3 · 5-1)를 가리키게 고친다 |
| `docs/spec/60-automate-work-prerequisites.md` | 3-1 제목과 표의 어댑터 이름, 3-2 의 `cmd_forge_setup()` · `script/forge-setup.sh` 서술, 3-3 의 위치를 이 명세(2-2 · 2-8 · 3-4)를 가리키게 고친다 |

`src/templates/managed/.ai/templates/developer.md` 는 고치지 않는다.

## 8. 테스트

### 8-1. 오라클

- 오라클은 기존 셸 테스트 검사 줄의 **기대값**(종료 코드 · 표준 출력 · 표준 오류에서 찾는 문자열 · 페이크 상태 기록)이다. 대상은
  `render-test.sh` 의 UT-11 · UT-16 · UT-33 · UT-63 · UT-79 · UT-81 · UT-83 · UT-98 · UT-99 · UT-100 과 `test-forge-labels.sh` ·
  `test-forge-setup.sh`, 그리고 셸 호출부 테스트(`test-review-loop.sh` · `test-work-preflight.sh` · `test-sync-task-issues.sh` ·
  `test-carryover-issue.sh` · `test-rollback-work.sh`)다
- 고칠 수 있는 줄은 넷뿐이다 — 준비부(샌드박스 배치 · 페이크 주입 · CLI 스텁 이름), 로더, 내부 구조 단언, 실행 방향 단언. 준비부와 로더는
  기대값을 바꾸지 않는다. 내부 구조 단언은 같은 사실을 동작으로 보는 단언으로 바꾸거나 단위 테스트로 옮긴다. 실행 방향 단언(UT-98 의
  셋)은 shim 방향(스크립트 → CLI)의 단언으로 바꾼다
- 페이크의 계약 위반 11종을 모두 오라클에 둔다 — UT-16 의 9종(`mr_view` · `threads` · `thread_id` · `issue_list` · `open_mrs` ·
  `inline_any` · `reply_any` · `reply_new` · `create_url`)과 UT-81 의 2종(`labels` · `protected`). 자체 검사는 그 각각에 1 로 끝나야 한다
- 셸 테스트는 외부 계약의 시험으로 남는다. 그 거취는 #221 이 정한다

### 8-2. 바꾸는 줄 — 묶음 A

이식 전 구현에서 먼저 통과시키고 이식보다 앞선 커밋에 둔다.

| 테스트 | 바꾸는 것 | 그대로인 것 |
|---|---|---|
| `test-forge-labels.sh` | 비공개 함수 `_gh_ensure_label` 을 부르던 줄 → 같은 인수로 `tracker_labels_ensure` | 모든 `check` 기대값 |
| UT-63 | 어댑터를 source 한 뒤 `GITHUB_CLI=` · `GITLAB_CLI=` 로 CLI 를 바꾸던 것 → 같은 내용의 스텁을 `gh` · `glab` 이름으로 PATH 앞에 둔다 | 스텁 응답과 기대값 |
| UT-33 | 어댑터의 정규화 변수(`_jira_norm_issue`)를 꺼내 쓰던 확인 → PATH 앞 `jira` 스텁이 같은 원본 JSON(`total` 2)을 내고 `$t` 에서 `. ./script/forge.sh && tracker_issue_list` 를 부른다 | 정규화 기대값 다섯 |

### 8-3. 바꾸는 줄 — 묶음 B

이식과 같은 task 에서 바꾼다.

| 테스트 | 바꾸는 것 | 그대로인 것 |
|---|---|---|
| UT-11 | `script/forge.sh` 내용 단언 둘과 `gitlab.sh` 의 `GITLAB_CLI` 단언 → github 설정의 `$t` 에서 `harness forge --target "$t" tracker_current_user` 가 PATH 앞 `gh` 스텁만 부르고 `glab` 스텁은 부르지 않는다. gitlab 설정에서는 `glab` 스텁으로 간다 | `.ai/forge.md` 단언 둘 |
| UT-33 | `script/forge.sh` 의 `forge/jira.sh` 단언 → jira 트래커 설정에서 `tracker_current_user` 가 `jira` 스텁으로 간다. 정규화 확인의 호출 → `harness forge --target "$t" tracker_issue_list` | 나머지 기대값 |
| UT-63 | 어댑터 파일 복사와 source → github · gitlab 설정의 샌드박스 하네스 루트에 `harness forge --target`. Jira 리뷰 답글 거부 두 줄 → 단위 테스트(8-5) | 기대값 |
| UT-16 | `fake-forge.sh` 를 `script/forge.sh` 로 복사 → 자체 검사 실행과 페이크 함수 호출의 환경에 `HARNESS_FORGE_FAKE=<fake-forge.sh 절대 경로>`. 페이크의 `tracker_labels_ensure` 확인은 같은 환경으로 `. ./script/forge.sh` 를 거친다 | 기대값 전부 |
| UT-79 | 어댑터 파일을 고쳐 보던 두 경우(본문 주석의 낱말, 첫 주석 덩어리 뒤의 표지) → 단위 테스트. 표지 상수와 표지 문자열을 세는 범위에서 `forge/` 어댑터 모듈을 뺀다. 계약 문구 단언의 파일 → `contract.py` | `adapter gitlab` 이 `warn` 인 첫 경우 |
| UT-81 | `script/forge.sh` 덮어쓰기 → `HARNESS_FORGE_FAKE`. 어댑터 머리글 · 계약 표 · 함수 정의를 grep 하던 줄 → 단위 테스트 | 자체 검사 · 페이크 기대값 |
| UT-83 | `script/forge.sh` 덮어쓰기 → `fdoc` 의 환경에 `HARNESS_FORGE_FAKE`. "CLI 가 forge CLI 를 직접 부르지 않는다" 의 검사 범위 → CLI 패키지에서 `forge/` 를 뺀 전부 | 기대값 |
| UT-98 | 페이크 덮어쓰기 → `HARNESS_FORGE_FAKE`. 실행 방향 단언 셋 → `script/forge-setup.sh` 가 CLI 를 `--target <하네스 루트> forge-setup` 으로 부르고 그 종료 코드를 돌려준다(고정 사본의 CLI 자리에 둔 스텁이 받은 인수를 남기고 7 로 끝나면 7). CLI 가 없으면 2 와 `harness CLI not found under` | 라벨 · 표준 출력 · help · 한글 검사 기대값 |
| `test-forge-labels.sh` | 라벨 준비 테스트의 전제(`script/forge/github.sh`) → 하네스 루트의 CLI 와 `script/forge.sh`. `adapter()` 로더 → 샌드박스 하네스 루트(설정의 forge 만 github 로 바꾼 `harness.toml`, 하네스 루트에서 복사한 `script/forge.sh`, 샌드박스 CLI 자리)에서 `. ./script/forge.sh` 뒤 함수를 부른다 — 본문 파일 인수가 셸 계약 그대로 간다. Jira 블록의 전제와 로더 → 같은 방식의 jira 트래커 설정 샌드박스 | `check` 기대값 |
| `test-forge-setup.sh` | `setup_run` 준비부 → 샌드박스 하네스 루트(라벨 값을 바꾼 `harness.toml`, shim `script/forge-setup.sh`, 샌드박스 CLI 자리). 페이크는 `HARNESS_FORGE_FAKE`. `harness.toml` 전제를 더한다 | `check` 기대값, tracker 를 `script/harness.env` 에서 읽는 줄 |

- 샌드박스 CLI 자리는 `<샌드박스>/.harness/bin/harness` 에 둔 하네스 루트 CLI 로의 심볼릭 링크다. CLI 의 `delegate()` 는 고정 사본 자리의
  파일을 `sys.executable` 로 다시 띄우므로 그 자리에 셸 래퍼를 두지 않는다 — 링크면 자기 자신으로 풀려 넘기지 않는다
- UT-99 · UT-100 과 셸 호출부 테스트는 바꾸지 않는다

구현 리뷰 요청 본문에 8-2 · 8-3 의 바꾼 줄마다 옛 줄 → 새 줄 대응표를 둔다.

### 8-4. `render-test.sh` — 새 블록

`UT-<다음 빈 번호>` 하나로 둔다. 원격을 부르지 않는다 — 페이크는 `HARNESS_FORGE_FAKE`, forge CLI 는 PATH 앞 스텁이다.

| 케이스 | 기대 |
|---|---|
| `harness forge` 인자 | 명령 이름 앞의 `--target D` 와 이름 바로 뒤의 `--target D` 가 각각 하네스 루트 `D` 가 된다 · 함수 이름 뒤의 `--help` · `--target` 은 함수 인수로 간다(페이크 스레드에 그 본문이 남는다) · 함수 이름이 없으면 2 와 usage · 모르는 함수 2 · 인수 개수가 다르면 2 · 본문 자리가 `-` 가 아니면 2 |
| 본문 전달 | 셸 shim 으로 `review_mr_note_summary 1 <파일>` 을 부르면 페이크에 남은 요약 본문이 그 파일 내용과 같다. `harness forge … review_mr_note_summary 1 -` 에 표준 입력으로 준 본문도 같다 |
| 출력 그대로 | 페이크 `FAKE_AUTH=fail` 에서 `harness forge tracker_auth` 가 1 과 표준 오류 한 줄 ``run `fake auth login` `` 만 낸다 |
| shim | 생성된 `script/forge.sh` 가 계약 함수 24개를 하나씩 정의한다. forge 설정을 바꿔 render 해도 내용이 같다. 고정 사본의 CLI 를 치운 리포에서 함수가 2 와 `harness CLI not found under` · `help: harness install --target` 두 줄을 낸다. 같은 리포에서 `script/forge-selftest.sh` 도 2 와 같은 두 줄 |
| 값 검사 | `HARNESS_FORGE_FAKE` 가 상대 경로이거나 없는 파일이면 2 와 4-2 의 문구. 출력 어디에도 그 값이 없다 |
| 알림 | 주입한 `forge-selftest` · `forge-setup` 의 표준 오류 첫 줄이 4-3 의 문구다. `doctor` 에 `warn` `forge fake` 가 있고, 주입하지 않으면 없다 |
| 정리 | `script/forge/` 를 가진 옛 매니페스트의 리포를 render 하면 `script/forge/` 가 없어진다 |
| 명령 등록 | `harness help` 에 `forge` · `forge-selftest` 가 있다 |
| 터미널 출력 | 이 블록의 출력에 한글이 없다 |

### 8-5. Python 단위 테스트

- 자리 · 실행 명령 · 실행 규칙은 #206 7-5, 검증 단계 "Python 단위 테스트"("CLI 패키지 의존 방향" 바로 뒤)는 #206 6절이 둔다.
  이 명세는 아래 파일을 더하기만 하고 `[verify]` 를 고치지 않는다
- CLI 를 하위 프로세스로 띄우지 않는다. 어댑터는 실행기를 바꿔 끼운다. 셸 구현(4절)과 표지 비교는 임시 디렉터리의 셸 파일에 `sh` 를 띄워 본다

| 파일 | 보는 것 |
|---|---|
| `test_forge_contract.py` | 함수 표가 24개 함수와 군 · 인자를 갖는다. 세 어댑터가 자기 군의 함수를 전부 구현한다(Jira 는 트래커 군과 `review_mr_thread_reply`). dataclass 의 키 순서와 `from_json` 의 엄격함. `call()` 의 직렬화(JSON · 한 줄 · 없음 · 그대로)와 `ForgeError` · 처리하지 못한 예외의 종료 코드. doctor 의 머리글 판정 — docstring 의 표지는 미검증, 주석 · 함수 docstring 의 같은 낱말은 아니다. GitLab · Jira 모듈 머리글이 표지를 갖는다 |
| `test_forge_github.py` | 이슈 · 리뷰 요청 정규화. `--paginate` 연접 배열 읽기와 배열 아닌 페이지의 실패. 이슈 목록의 `pull_request` 제외. 스레드 묶기(`in_reply_to_id` · 답글 순서 · `original_line` · 일반 댓글 null id). 생성 출력에서 식별자 뽑기. 열린 목록의 `head.ref` · `head.sha` |
| `test_forge_gitlab.py` | 정규화(`diff_refs.head_sha` 와 `sha` 대체). 페이지 순회의 끝(빈 배열 · 100 미만)과 배열 아닌 응답의 문구. discussion(시스템 노트 제외 · `individual_note` · position 대체). 브랜치 보호의 404 → `false` · 그 밖 실패. 라벨 생성의 `already exists` · `409`. 연결 리뷰 요청의 `opened` 거르기 |
| `test_forge_jira.py` | 평문 누르기. `statusCategory` 로 상태. `fixVersions` 로 마일스톤. `total` 기반 순회와 객체 · 배열 응답. 생성 출력의 키 뽑기(JSON · 패턴 · 빈 값). `issues.type` · `issues.closed_status` 가 인수로 간다. 리뷰 답글 거부의 2 와 `not supported` |
| `test_forge_common.py` | 기본 `harness_issue_open_mrs` — 브랜치 경계(`feat/12-x` 는 12 에 맞고 `feat/123-x` 는 아니다), 본문 키워드의 대소문자 무시와 뒤 경계, `ISSUE_CLOSES_KEYWORD` |
| `test_forge_shell.py` | 셸 구현의 `call()` 이 세 값을 그대로 돌려준다. 타입 메서드가 키가 빠진 출력에 `ContractError`. 4-2 의 값 검사와 문구에 값이 없음 |
| `test_format.py` | `markers()` 가 `src/templates/managed/script/harness-format.sh` 의 `FMT_*` 전부를 그 파일을 셸로 source 한 값과 같게 읽는다. 형식이 아닌 줄 · 없는 파일 · 디렉터리는 `FormatError` 이고 메시지에 경로가 있다. 홑따옴표 밖의 명령 치환(`FMT_X=$(…)`)을 담은 줄은 실행되지 않고 `FormatError` 다. `format.py` 를 만드는 이슈가 함께 둔다 |

### 8-6. UI 단위 테스트 — `src/ui/lib/doctor.test.js`

`adapter <kind>` 의 `file is missing` 케이스를 지우고, `forge fake` 경고가 5-4 의 제목 · 본문으로 옮겨지고 조치가 없는 케이스를 더한다.

## 9. GitHub 어댑터의 실제 검증

GitHub 어댑터는 이 구현으로 자체 검사 전 단계(`--create-issue` 포함)를 이 리포의 GitHub 에서 통과한 뒤에 검증됨으로 적는다.

1. 구현 중 `github.py` 머리글은 `검증 상태: 미검증` 이다
2. 전제: 묶음 B 까지 끝나 회귀 테스트 · 단위 테스트가 통과한 브랜치, `HARNESS_FORGE_FAKE` 가 없는 셸, `gh` 로그인
3. 대상: 사람이 지정한 이 리포의 버려도 되는 리뷰 요청 하나와 그것에 연결된 이슈. 연결은 리뷰 요청의 브랜치가 `<tag>/<이슈>-…` 이거나
   본문에 `Closes <이슈>` 가 있는 것이다
4. 읽기 단계 `script/forge-selftest.sh <리뷰요청> <이슈>` — fail 0
5. `--create-issue` 를 돌리기 **직전에 사람의 확인을 받는다.** 확인을 구할 때 남는 것을 밝힌다 — 그 리뷰 요청에 댓글 3건(인라인 · 그 답글 ·
   요약)과, 트래커에 이슈 1건(이 리포는 이슈 삭제를 금지하므로 `invalid` 로 닫힌 채 영구히 남는다)
6. 확인을 받으면 `script/forge-selftest.sh --create-issue <리뷰요청> <이슈>` — fail 0 · skip 0
7. 기록은 한 커밋에서 한다 — `github.py` 머리글의 `검증 상태:` 줄을 `script/forge-selftest.sh --create-issue 전 단계 통과 (gh <그 실행의 gh 버전>)`
   로, README 지원 범위 표의 GitHub 행, `src/templates/forge/github/review.md` 의 "어댑터 미검증" 안내 삭제. 구현 리뷰 요청 본문에 판정 줄
   (`pass · fail · skip`)과 gh 버전, 만들어진 이슈 번호를 적는다
8. 만들어진 이슈는 사람이 `invalid` 로 닫는다. 남은 댓글과 버려도 되는 리뷰 요청도 사람이 정리한다. 에이전트는 이슈 · 리뷰 요청을 닫지 않는다

6 까지 통과한 기록이 구현 리뷰 요청의 완료 조건이다.

## 10. 보호 문서 개정 범위

분해의 task 하나가 아래 범위 안에서만 고친다. 그 밖의 보호 문서 수정은 이 명세의 범위가 아니다.

- 적용 순서는 #206 → #207 → #208 · #209 · #210 → #211 → #212 → #213 → #215 다. 아래 문안은 #206 · #207 이 고친 문장 위에 더하는
  것이다. 같은 묶음의 #208 · #210 과는 고치는 구절이 겹치지 않는다
- 단위 테스트 층(`src/test/unit/` · `[verify]` 의 "Python 단위 테스트")의 기본 문장은 #206 9절이 둔다 — architecture 의 `src/test/render-test.sh`
  항목 끝 · "새 코드를 둘 곳" 의 새 회귀 테스트, testing 의 "무엇을 어느 수준으로 검증하나" 새 항목. 이 명세는 그 문장을 다시 쓰지 않고 forge 의 것만 더한다

### 10-1. `.ai/project/architecture.md`

| 위치 | 반영할 문안 |
|---|---|
| "구성 요소" 의 `src/test/render-test.sh` 항목 | "forge 어댑터 자리를 대신하는 페이크(계약 위반 6종을 주입할 수 있다)" → "forge 어댑터 자리를 대신하는 셸 함수 파일 페이크(계약 위반 11종을 주입할 수 있다). 셸 호출부에는 `script/forge.sh` 자리에 덮어 끼우고, CLI 에는 `HARNESS_FORGE_FAKE` 로 끼운다" |
| "구성 요소" 의 CLI 패키지 항목 | 더한다: `src/harness/forge/` — forge 어댑터 계약(함수 표 · 정규화 dataclass)과 github · gitlab · jira 구현, 자체 검사. `gh` · `glab` · `jira` 를 subprocess 로 감싼다 |
| "구성 요소" 의 대상 리포에 깔리는 `script/` 항목 | "·forge 어댑터(`forge/`)" → "·forge shim(`forge.sh` 는 생성물이고 계약 함수마다 `harness forge` 를 부른다. `forge-selftest.sh` · `forge-setup.sh` 는 같은 이름의 CLI 명령을 부른다)" |
| "데이터 흐름" 의 forge | forge: 셸 스크립트 → `script/forge.sh`(shim) → `harness forge <함수>` → `src/harness/forge/` 어댑터(tracker 군 · review 군) → `gh` · `glab` · `jira`. CLI 의 `forge-selftest` · `forge-setup` 은 어댑터를 직접 쓰고, `doctor --remote` 는 `harness forge` 를 하위 프로세스로 띄운다. 호출부는 forge 를 모르고 정규화된 JSON(Python 에서는 정규화 dataclass)을 받는다 |
| "신뢰 경계" 의 들어오는 입력 | 더한다: 환경 변수 `HARNESS_FORGE_FAKE`(테스트 전용 주입 지점 — 값이 가리키는 셸 파일의 함수가 forge 어댑터를 대신한다. PATH 앞 스텁과 같은 신뢰 수준이고 하네스 · 생성물 · CI 는 설정하지 않는다. 절대 경로의 일반 파일만 받고 값을 출력에 옮기지 않으며, 설정되어 있으면 doctor 가 경고한다) |
| "새 코드를 둘 곳" 의 새 forge | 새 forge → `src/harness/forge/<kind>.py`(자기 군의 계약 함수 전부) + `src/templates/forge/<kind>/`(명령 사전 조각) + `validate()` 의 허용 목록. 실제 forge 로 `script/forge-selftest.sh` 를 통과하기 전까지 모듈 머리글(docstring)에 `검증 상태: 미검증` |
| "새 코드를 둘 곳" | 더한다: 새 forge 계약 함수 → `src/harness/forge/contract.py` 의 함수 표 + 세 어댑터 + `src/test/fake-forge.sh` + 자체 검사. 셸 shim `script/forge.sh` 는 render 가 함수 표에서 만든다 |
| "계층과 의존 방향" 의 규칙 값 줄(#207 이 고친 문장) | 생성물 괄호에서 `script/forge.sh` 를 뺀다. 그 문장 끝에 더한다: "셸의 forge 호출은 `script/forge.sh` shim 을 거쳐 `harness forge` 로 가고, forge 선택은 `harness forge` 가 공유 설정에서 읽는다" |
| "계층과 의존 방향" 의 forge 줄 | forge 는 `src/harness/forge/` 의 어댑터로만 부른다 — 셸 관리 스크립트는 `script/forge.sh` 의 함수로, CLI 는 `harness.forge` 로. `gh` · `glab` · `jira` 를 부르는 코드는 `src/harness/forge/` 뿐이다 |
| "검사하지 않는 것" 의 GitLab · Jira 줄 | "머리글의 미검증 표기가 그 사실이다" → "모듈 머리글(docstring)의 미검증 표기가 그 사실이다" |
| "검사하지 않는 것" | 더한다: `HARNESS_FORGE_FAKE` 는 명령 가드가 보지 않는다 |

### 10-2. `.ai/project/glossary.md`

| 위치 | 반영할 문안 |
|---|---|
| "용어" 의 `어댑터` | forge 명령을 감싸는 모듈(`src/harness/forge/<kind>.py`), 또는 역할 계약을 CLI 별 형식으로 옮긴 정의 파일(`.claude/agents/` · `.codex/agents/`) |
| "용어" 의 `자체 검사` | 어댑터가 계약을 지키는지 실제 forge 로 확인하는 것 (`harness forge-selftest`, shim `script/forge-selftest.sh`) |
| "용어" 에 새 행 `shim` | 로직이 CLI 하위 명령으로 옮겨 간 뒤 옛 경로에 남아 그 하위 명령을 부르는 얇은 파일. 실행하는 shim 은 받은 인자를 그대로 넘겨 하위 명령을 exec 하고(`script/forge-selftest.sh` · `script/forge-setup.sh` 등), source 해서 쓰는 shim `script/forge.sh` 는 계약 함수마다 `harness forge` 를 부르는 같은 이름의 셸 함수를 정의한다. 어느 쪽이든 하위 명령의 표준 출력 · 표준 오류 · 종료 코드를 그대로 돌려준다 |
| "용어" 에 새 행 `forge 페이크` | 계약을 지키는 셸 함수 파일(`src/test/fake-forge.sh`). 셸 호출부에는 `script/forge.sh` 자리에, CLI 에는 `HARNESS_FORGE_FAKE` 로 끼운다 |

### 10-3. `.ai/project/scope.md`

| 위치 | 반영할 문안 |
|---|---|
| "만들지 않는 것" 의 forge CLI 항목 | "하네스는 어댑터(`script/forge/`)로 그 명령을 감쌀 뿐이다" → "하네스는 어댑터(`src/harness/forge/`)로 그 명령을 감쌀 뿐이다" |

### 10-4. `.ai/project/testing.md`

| 위치 | 반영할 문안 |
|---|---|
| "무엇을 어느 수준으로 검증하나" 의 자체 검사 항목 | 자체 검사(`forge-selftest`) 자신도 검사한다 — 계약을 지키는 페이크는 통과시키고, 위반을 주입한 페이크 11종은 전부 잡아야 한다 |
| "외부 의존을 어떻게 다루나" 의 forge 항목 | forge 는 `src/test/fake-forge.sh`(셸 함수 파일)가 대신한다. 셸 호출부에는 `script/forge.sh` 자리에 덮어 끼우고, CLI · Python 쪽 호출에는 `HARNESS_FORGE_FAKE` 로 끼운다 — 명령 하나의 환경에만 주고 테스트 전체에 내보내지 않는다. forge CLI 의 응답 처리는 PATH 앞의 `gh` · `glab` · `jira` 스텁으로, 어댑터의 응답 정규화 · 페이지네이션 · 식별자 추출은 단위 테스트에서 어댑터의 실행기를 바꿔 끼워 forge CLI 없이 본다. 원격은 로컬 bare 리포다. 실제 forge 를 상대로 하는 어댑터 검증은 `script/forge-selftest.sh` 로 사람이 버려도 되는 리뷰 요청에만 돌린다 |

## 11. 한계

- GitHub 의 `review_mr_threads` 는 두 조회의 실패를 종료 코드로 알리지 않는다 — 실패한 조회는 빈 목록이 되고 CLI 의 표준 오류만 남는다.
  실패로 바꾸는 것은 외부 동작 변경이라 이 명세 밖이다
- 셸 호출부의 계약 함수 호출마다 Python 프로세스가 하나 뜬다. 셸 호출부가 CLI 패키지로 옮겨 가면 없어진다
- shim 셋(`script/forge.sh` · `script/forge-selftest.sh` · `script/forge-setup.sh`)과 `test-forge-labels.sh` · `test-forge-setup.sh` 는 #221 이
  다룬다
- `HARNESS_FORGE_FAKE` 는 명령 가드가 보지 않는다
- 페이크 셸 파일의 함수는 호출마다 새 `sh` 에서 돈다. 같은 셸의 변수로 상태를 잇는 페이크는 쓸 수 없다
- GitLab · Jira 어댑터는 실제 forge 로 검증하지 않았다
- 어댑터의 단위 테스트는 #206 의 단위 테스트 층에 있어 소스 리포에서만 돈다. 대상 리포에는 셸 계약 테스트만 간다
