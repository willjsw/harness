# #209 task

## T1 · chore: forge 회귀 테스트의 어댑터 내부 이름 의존을 계약 함수와 PATH 앞 CLI 스텁으로 교체

### 상위 Requirement

- relates to #209

### 작업 내용

이식 전에, 셸 어댑터의 비공개 함수 · CLI 변수 · 정규화 변수를 직접 쓰던 회귀 테스트 줄을 계약 함수와 PATH 앞 CLI 스텁으로 바꾼다.
제품 코드는 고치지 않는다. 바꾼 줄은 **지금의 셸 어댑터에서** 통과하고, 뒤의 이식 task 는 이 줄의 기대값을 그대로 둔다.

- 명세 8-1(오라클) · 8-2(묶음 A)
- `src/templates/managed/script/test-forge-labels.sh`: 비공개 함수 `_gh_ensure_label` 을 부르던 줄을 같은 인수의 `tracker_labels_ensure` 로.
  `check` 기대값은 그대로
- `src/test/render-test.sh` UT-63: 어댑터를 source 한 뒤 `GITHUB_CLI=` · `GITLAB_CLI=` 로 CLI 를 바꾸던 것을, 같은 응답을 내는 스텁을
  `gh` · `glab` 이름으로 PATH 앞에 두는 것으로. 스텁 응답과 기대값은 그대로
- `src/test/render-test.sh` UT-33: 정규화 변수 `_jira_norm_issue` 를 꺼내 쓰던 확인을, PATH 앞 `jira` 스텁이 같은 원본 JSON(`total` 2)을 내고
  `$t` 에서 `. ./script/forge.sh && tracker_issue_list` 를 부르는 것으로. 정규화 기대값 다섯은 그대로
- `src/bin/harness render` 로 이 리포의 `script/test-forge-labels.sh` 사본과 `.harness/managed` 를 갱신한다
- 건드릴 파일: `src/templates/managed/script/test-forge-labels.sh`, `src/test/render-test.sh`, render 로 갱신되는 `script/test-forge-labels.sh` ·
  `.harness/managed`

### 완료 조건

- [ ] `test-forge-labels.sh` 에 `_gh_ensure_label` 이 없고, 그 자리의 `tracker_labels_ensure` 케이스가 같은 기대값으로 통과한다
- [ ] UT-63 이 `GITHUB_CLI` · `GITLAB_CLI` 를 쓰지 않고 PATH 앞 스텁으로 같은 기대값을 통과한다
- [ ] UT-33 이 `_jira_norm_issue` 를 쓰지 않고 `tracker_issue_list` 출력으로 정규화 기대값 다섯을 통과한다
- [ ] `src/templates/managed/script/forge/` · `src/bin/` · `src/harness/` 가 바뀌지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 라벨 준비를 계약 함수로 | `test-forge-labels.sh` 의 라벨 준비 케이스를 `tracker_labels_ensure` 로 | 옛 `_gh_ensure_label` 케이스와 같은 `check` 기대값 통과 |
| UT-02 | 스레드 정규화를 PATH 스텁으로 | UT-63 의 `gh` · `glab` 스텁을 PATH 앞에 두고 `review_mr_threads 5` · `review_mr_thread_reply` | 스레드 id · inline · 노트 수와 답글 호출 경로가 옛 기대값과 같다 |
| UT-03 | Jira 정규화를 계약 함수로 | jira 트래커 설정의 `$t`, PATH 앞 `jira` 스텁이 원본 JSON 을 냄, `tracker_issue_list` | `"iid": "BD-12"` · `"state": "opened"` · `"state": "closed"` · 평문 본문 · `"milestone": "M1"` |

## T2 · refactor: forge 어댑터 계약 함수 표와 정규화 dataclass 모듈 추가

### 상위 Requirement

- relates to #209

### 작업 내용

CLI 패키지에 forge 어댑터 패키지 `src/harness/forge/` 를 만들고 계약 모듈을 둔다. 계약 서술의 정본이 이 모듈의 머리글이 된다. 아직 어디서도
부르지 않는다.

- 명세 2-1(모듈 · 표지 규칙) · 2-2(계약 함수 24개와 모든 함수에 걸리는 규칙) · 2-3(정규화 dataclass) · 2-4(오류) · 8-3 의 UT-79 · UT-83 범위 줄 · 8-5 의 `test_forge_contract.py`
- `src/harness/forge/__init__.py`: 이 task 에서는 docstring 만 둔다(#206 3-1 의 패키지 규칙)
- `src/harness/forge/contract.py`
  - 계약 함수 표 — 함수마다 이름 · 군(트래커 · 리뷰 호스트 · 공통) · 인자 · 출력 종류(JSON 객체 · JSON 배열 · 한 줄 · 없음 · 그대로) · 설명.
    본문 파일 자리 함수(`tracker_issue_create` · `review_mr_note_summary`)와 그 자리를 표가 갖는다
  - `Issue` · `MergeRequest` · `Thread` · `Note` — 명세 2-3 의 키 순서로 `to_json()`, 엄격한 `from_json()`(어긴 내용을 적은 `ContractError`)
  - `ForgeError(code, message)` 와 그 하위 `ContractError(message)`(코드 2)
  - 모듈 머리글: 계약 서술(두 군의 분리, 함수 표, 정규화 JSON, 값이 없는 자리 규칙)과 명세 2-1 의 표지 규칙 문장
- `src/test/render-test.sh`
  - UT-79: 표지 상수와 표지 문자열을 세는 범위(#206 이 넓힌 CLI 원문)에서 `src/harness/forge/` 를 뺀다 — 계약 머리글과 어댑터 머리글이 표지
    문자열을 갖는다. 기대값(각 1)은 그대로
  - UT-83: "CLI 가 forge CLI 를 직접 부르지 않는다" 의 검사 범위를 CLI 패키지에서 `src/harness/forge/` 를 뺀 전부로. 기대값(빈 출력)은 그대로
- `src/test/unit/test_forge_contract.py` 를 만든다
- 건드릴 파일: `src/harness/forge/__init__.py` · `contract.py`(신규), `src/test/unit/test_forge_contract.py`(신규), `src/test/render-test.sh`

### 완료 조건

- [ ] 계약 함수 표가 명세 2-2 의 함수 24개를 군 · 인자 · 출력 종류와 함께 갖는다
- [ ] 네 dataclass 의 `to_json()` 키 순서가 명세 2-3 과 같고, 값이 없는 자리는 빈 문자열(`labels` 는 빈 배열)이다
- [ ] `from_json()` 이 객체가 아님 · 키 빠짐 · 타입 다름을 `ContractError` 로 거부하고 메시지가 어긴 내용을 적는다(`missing keys: head_sha` · `not an object: list` 꼴)
- [ ] `contract.py` 머리글에 `머리글의 \`검증 상태:\` 줄이 검증 상태의 표지다` 문장이 있다
- [ ] UT-79 의 두 세기가 `src/harness/forge/` 밖에서 각 1 이고, UT-83 의 직접 호출 검사가 `src/harness/forge/` 밖에서 빈 출력이다
- [ ] 셸 어댑터와 그 호출부의 동작이 그대로다 — 오라클 테스트가 고치지 않은 기대값으로 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 함수 표 | 계약 함수 표 | 24개, 트래커 군 10 · 리뷰 호스트 군 12 · 공통 2, 인자 개수가 명세 2-2 와 같다 |
| UT-02 | 본문 파일 자리 | 계약 함수 표 | 본문 파일 자리를 가진 함수가 `tracker_issue_create`(둘째) · `review_mr_note_summary`(둘째) 둘뿐이다 |
| UT-03 | 키 순서 | 네 dataclass 의 `to_json()` | 명세 2-3 의 순서 |
| UT-04 | 엄격한 읽기 | 리스트 · `head_sha` 가 빠진 객체 · `labels` 가 문자열인 객체 · `inline` 이 문자열인 스레드 | 각각 `ContractError`, 메시지에 `not an object: list` · `missing keys: head_sha` · 어긴 키 |
| UT-05 | 오류 계층 | `ContractError("x")` | `ForgeError` 의 하위이고 `code` 가 2 |

## T3 · refactor: GitHub 어댑터를 Python 모듈로 이식

### 상위 Requirement

- relates to #209

### 작업 내용

`script/forge/github.sh` 의 트래커 군과 리뷰 호스트 군을 `src/harness/forge/github.py` 로 옮긴다. 셸 어댑터는 그대로 남고 아직 이 모듈을
부르는 곳이 없다. 동작은 단위 테스트로 확인한다.

- 명세 2-2 · 2-5(GitHub 열) · 2-6 · 2-7(GitHub) · 2-8(GitHub) · 2-10 · 8-5 의 `test_forge_github.py`
- 트래커 군 클래스와 리뷰 호스트 군 클래스. `harness_issue_open_mrs` 는 두지 않는다 — 기본 구현(T6)을 쓴다
- CLI 실행은 생성자로 받은 실행기 하나로 한다. 기본 실행기(subprocess)와 세 어댑터가 함께 쓸 도우미(0600 본문 임시 파일과 호출 뒤 삭제,
  명세 2-2 의 JSON 직렬화)를 이 task 에서 둔다 — 자리는 명세 2-1 의 모듈 표 안
- 입출력(2-10): CLI 호출은 하네스 루트에서, 표준 입력을 닫는 호출(`*_auth` · `api --paginate` 목록 조회 · 라벨 이름 조회 ·
  `review_branch_protected`), 표준 오류를 버리는 호출(`*_auth` · 라벨 이름 조회)과 끝 줄만 옮기는 라벨 생성 실패, 그대로 흘리는 출력
  (`review_mr_diff` · `review_mr_note_inline` · `review_mr_note_summary`)
- 경로 인코딩의 `urllib.parse` 는 쓰는 함수 안에서 불러온다
- 모듈 머리글: forge 하나의 구현이라는 것과 `검증 상태: 미검증` 줄(명세 9-1)
- `test_forge_contract.py` 에 GitHub 어댑터가 자기 두 군의 함수를 전부 구현하는지 더한다
- 건드릴 파일: `src/harness/forge/github.py`(신규), 공용 도우미를 둔 모듈, `src/test/unit/test_forge_github.py`(신규),
  `src/test/unit/test_forge_contract.py`

### 완료 조건

- [ ] 트래커 군 10 · 리뷰 호스트 군 12 함수(공통 둘 제외)가 명세 2-5 GitHub 열의 `gh` 호출을 낸다
- [ ] 이슈 · 리뷰 요청 정규화가 명세 2-6 과 같고, 원본 값이 없거나 null 이면 빈 문자열이다
- [ ] `--paginate` 의 이어 붙은 배열을 합치고, 배열이 아닌 값이나 `gh` 실패는 일부 출력이 있어도 실패(1)다. 스레드의 두 조회만 예외다
- [ ] 라벨 준비가 명세 2-8 의 세 단계를 따르고, 실패하면 이슈 · 리뷰 요청을 바꾸는 호출 전에 1 로 끝난다
- [ ] 단위 테스트가 실행기를 바꿔 끼워 `gh` 없이 돈다
- [ ] 모듈 머리글(docstring)에 `검증 상태: 미검증` 이 있다
- [ ] 모듈 최상위에 `urllib` import 가 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 이슈 정규화 | `issue view` 응답(라벨이 객체 · 문자열 섞임, 담당자 · 마일스톤 없음) | `Issue` — `state` 소문자, 라벨 이름 배열, 빈 문자열 자리 |
| UT-02 | 리뷰 요청 정규화 | `pr view` 응답과 열린 목록 항목(`head.ref` · `head.sha`) | `MergeRequest` 의 `source_branch` · `head_sha` |
| UT-03 | 연접 배열 읽기 | 페이지 셋이 이어 붙은 출력, 값 사이 공백 | 항목 전부를 합친 배열 |
| UT-04 | 배열 아닌 페이지 · `gh` 실패 | 둘째 값이 객체 / 실행기가 출력 일부와 1 | 실패(1), 계약 출력 없음 |
| UT-05 | 이슈 목록의 리뷰 요청 제외 | `pull_request` 키가 있는 항목 | 목록에서 빠진다 |
| UT-06 | 스레드 묶기 | 루트 · `in_reply_to_id` 답글(`created_at` 역순) · `line` 없이 `original_line` · 일반 댓글 | 루트 id 가 스레드 id, 답글이 시간순으로 뒤에, `line` 대체, 일반 댓글은 `id: null` · `inline: false` |
| UT-07 | 생성 식별자 | `issue create` 출력 여러 줄(URL 끝 `/12`, 뒤에 숫자 아닌 문자만 오는 마지막 줄) / 숫자 없음 | `12` / 빈 출력 |
| UT-08 | 라벨 준비 | 생성 성공 / 생성 실패 · 이름 조회 성공 / 둘 다 실패 / 빗금 든 라벨 / 빈 라벨 | 다음 라벨 / 이미 있음 / `could not create label` 과 두 칸 들여 쓴 끝 줄, 1, 뒤 라벨 안 감 / 경로 한 칸 인코딩 / 건너뜀 |
| UT-09 | 라벨 준비 실패 뒤 | `tracker_issue_create` 에서 라벨 준비 실패 | `issue create` 를 부르지 않고 1 |
| UT-10 | 인증 | `auth status` 0 / 0 아님 | 0 / 1 과 ``run `gh auth login` `` 한 줄, CLI 출력 없음 |
| UT-11 | 브랜치 보호 | `-q .protected` 가 `true` · `false` · 그 밖 · 실패 | `True` · `False` · 1 · 1 |

## T4 · refactor: GitLab 어댑터를 Python 모듈로 이식

### 상위 Requirement

- relates to #209

### 작업 내용

`script/forge/gitlab.sh` 의 두 군과 GitLab 이 덮어쓰는 `harness_issue_open_mrs` 를 `src/harness/forge/gitlab.py` 로 옮긴다. T3 의 실행기와
공용 도우미를 쓴다.

- 명세 2-5(GitLab 열) · 2-6 · 2-7(GitLab) · 2-8(GitLab) · 2-10 · 8-5 의 `test_forge_gitlab.py`
- 리뷰 호스트 군에 `harness_issue_open_mrs`(`related_merge_requests` 의 `opened`)를 둔다 — 리뷰 호스트가 GitLab 일 때 기본 구현 대신 쓰인다
- 본문은 끝의 줄바꿈을 뺀 문자열을 인수로 넘긴다(2-10)
- 페이지 순회는 `per_page=100&page=<N>` 을 `?` 또는 `&` 로 붙이고, 배열이 아닌 응답은 `error: list response is not an array: <경로>` 와 실패
- 모듈 머리글: `검증 상태: 미검증` 을 유지한다(명세 1절)
- `test_forge_contract.py` 에 GitLab 어댑터가 자기 두 군의 함수를 전부 구현하는지와 머리글 표지를 더한다
- 건드릴 파일: `src/harness/forge/gitlab.py`(신규), `src/test/unit/test_forge_gitlab.py`(신규), `src/test/unit/test_forge_contract.py`

### 완료 조건

- [ ] 두 군의 함수와 `harness_issue_open_mrs` 가 명세 2-5 GitLab 열의 `glab` 호출을 낸다
- [ ] 정규화가 명세 2-6 과 같고 `head_sha` 는 `diff_refs.head_sha`, 없으면 `sha` 다
- [ ] 페이지 순회가 빈 배열이나 100 개 미만에서 끝난다
- [ ] 스레드에서 시스템 노트가 빠지고, 남는 노트가 없는 discussion 이 빠진다
- [ ] 브랜치 보호의 404 가 `false`, 그 밖의 실패가 1 이다. 라벨 생성의 `already exists` · `409` 가 성공이다
- [ ] 모듈 머리글(docstring)에 `검증 상태: 미검증` 이 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 리뷰 요청 정규화 | `diff_refs` 가 있는 응답 / 없는 응답 | `head_sha` 가 `diff_refs.head_sha` / `sha` |
| UT-02 | 페이지 순회의 끝 | 100 · 100 · 0 개 / 100 · 37 개 | 셋째 페이지에서 끝 / 둘째 페이지에서 끝, 항목 합 |
| UT-03 | 배열 아닌 응답 | 첫 페이지가 객체 | 실패와 `error: list response is not an array: <경로>` |
| UT-04 | discussion | 시스템 노트만 든 것 · `individual_note` true/false · 첫 노트 `position` 의 `new_path` 없이 `old_path`, `new_line` 없이 `old_line` | 시스템 discussion 제외, id 는 false 일 때만 문자열, `path` · `line` 대체, `inline` 판정 |
| UT-05 | 브랜치 보호 | 성공 / 오류 출력에 `404` / 그 밖 실패 | `True` / `False` / 1. 브랜치 이름은 경로 한 칸으로 인코딩 |
| UT-06 | 라벨 생성 | `already exists` / `409` / 그 밖 실패 | 성공 / 성공 / `could not create label` 두 줄과 1 |
| UT-07 | 연결 리뷰 요청 | `opened` · `merged` · `closed` 가 섞인 응답 | `opened` 의 `iid` 만 공백으로 이은 목록 |
| UT-08 | 본문 끝 줄바꿈 | 끝에 줄바꿈이 둘 있는 본문 | 인수에 줄바꿈 없이 넘어간다 |

## T5 · refactor: Jira 어댑터를 Python 모듈로 이식

### 상위 Requirement

- relates to #209

### 작업 내용

`script/forge/jira.sh` 의 트래커 군과 리뷰 답글 거부를 `src/harness/forge/jira.py` 로 옮긴다. 이슈 유형과 닫힘 상태 이름은 생성자로 받는다 —
설정에서 넘기는 것은 T6 의 `load()` 다. T3 의 실행기와 공용 도우미를 쓴다.

- 명세 2-5(Jira 열과 리뷰 호스트 군의 Jira 항목) · 2-6 · 2-7(Jira) · 2-10 · 2-11 · 8-5 의 `test_forge_jira.py`
- `tracker_labels` 는 CLI 를 부르지 않고 3, `tracker_labels_ensure` 는 CLI 를 부르지 않고 0
- `review_mr_thread_reply` 는 표준 오류 `error: jira does not host code review — review thread replies are not supported` 와 2
- `tracker_current_user`(`me`)의 표준 출력은 그대로 흘린다(2-10)
- 모듈 머리글: `검증 상태: 미검증` 을 유지한다(명세 1절)
- `test_forge_contract.py` 에 Jira 어댑터가 트래커 군 전부와 `review_mr_thread_reply` 를 구현하는지와 머리글 표지를 더한다
- 건드릴 파일: `src/harness/forge/jira.py`(신규), `src/test/unit/test_forge_jira.py`(신규), `src/test/unit/test_forge_contract.py`

### 완료 조건

- [ ] 트래커 군 함수가 명세 2-5 Jira 열의 `jira` 호출을 내고, 이슈 유형 · 닫힘 상태 이름이 `-t` · `issue move` 인수로 간다
- [ ] 평문 누르기와 상태 · 마일스톤 정규화가 명세 2-6 과 같다
- [ ] `total` 기반 순회가 객체 · 배열 응답을 받고, 배열이 아닌 항목이면 실패다
- [ ] 리뷰 답글 거부가 2 와 `not supported` 문구다
- [ ] 모듈 머리글(docstring)에 `검증 상태: 미검증` 이 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 평문 누르기 | `paragraph` · `heading` · `codeBlock` · `text` · `hardBreak` · `rule` · 문자열 · 배열 · 객체 아닌 값 | 명세 2-6 의 규칙대로 이은 문자열, 앞뒤 공백 제거 |
| UT-02 | 상태 | `statusCategory.key` 가 `done` / 그 밖 | `closed` / `opened` |
| UT-03 | 마일스톤 | `fixVersions` 첫 항목 / 빈 배열 | 그 `name` / 빈 문자열 |
| UT-04 | 응답 모양 | 이슈 객체 하나 · `issues` 배열을 가진 객체 · 배열 | 모두 읽는다 |
| UT-05 | 순회 | `total` 250 에 100 · 100 · 50 / `total` 없음 / 0 개 | 셋째에서 끝 / 이번 항목 수로 끝 / 끝 |
| UT-06 | 생성 키 | `key` 를 가진 JSON / 키가 든 평문 여러 개 / 키 없음 | 그 값 / 단어 경계 패턴의 마지막 / 빈 출력 |
| UT-07 | 설정 값 전달 | 이슈 유형 `작업`, 닫힘 상태 `완료` 로 만든 어댑터의 생성 · 닫기 | `-t 작업` · `issue move <id> 완료` |
| UT-08 | 라벨 | `tracker_labels` / `tracker_labels_ensure A B` | 3 · 실행기 호출 없음 / 0 · 실행기 호출 없음 |
| UT-09 | 리뷰 답글 거부 | `review_mr_thread_reply 1 x y` | 2 와 `not supported` 문구 |

## T6 · feat: forge 어댑터 선택 · 계약 함수 호출과 HARNESS_FORGE_FAKE 셸 구현

### 상위 Requirement

- relates to #209

### 작업 내용

설정으로 트래커 군과 리뷰 호스트 군을 골라 묶고, 계약 함수 하나를 셸 계약 모양으로 부르는 진입 함수를 둔다. 테스트용 주입 지점
`HARNESS_FORGE_FAKE` 가 가리키는 셸 함수 파일을 forge 로 쓰는 셸 구현을 함께 둔다. 아직 진입점이 부르지 않는다.

- 명세 2-9(열린 리뷰 요청 찾기 기본 구현) · 2-11(설정에서 오는 값) · 2-12(`load()` · `Forge` · `call()`) · 4-1 · 4-2 · 4-4 · 8-5 의
  `test_forge_common.py` · `test_forge_shell.py` · `test_forge_contract.py`
- `src/harness/forge/__init__.py`
  - `load(cfg, root)` — `HARNESS_FORGE_FAKE` 가 비지 않으면 셸 구현, 아니면 `forge.tracker` 의 트래커 군과 `forge.review_host` 의 리뷰 호스트 군을
    묶은 `Forge`. `issues.type` · `issues.closed_status` 를 Jira 어댑터에, 환경 변수 `ISSUE_CLOSES_KEYWORD`(없거나 비면 `Closes`)를 기본
    구현에 넘긴다. 환경 변수는 이 함수에서만 읽는다
  - `Forge` — 계약 함수 24개를 같은 이름의 메서드로. `forge_require` 는 `tracker_require` 다음 `review_require`, 어느 쪽이든 실패하면 2.
    `harness_issue_open_mrs` 는 리뷰 호스트 군이 구현하면(GitLab) 그것을, 아니면 명세 2-9 의 기본 구현을 쓴다
  - `call(forge, name, args)` — `(종료 코드, 표준 출력, 표준 오류)`. Python 어댑터면 반환값을 명세 2-2 의 규칙으로 직렬화하고 `ForgeError` 를
    코드 · 표준 오류로, 처리하지 못한 예외를 2 와 `error: <함수>: <예외 이름>` 으로 바꾼다
- `src/harness/forge/shell.py` — 함수 하나마다 하네스 루트에서 `sh -c '. "$0" && "$@"' <파일> <함수> <인수...>` 를 띄우고 세 값을 그대로
  돌려준다. 환경은 물려받는다. 본문 자리 함수에는 본문을 0600 임시 파일에 써서 경로를 넘기고 끝나면 지운다. 타입 메서드는 같은 실행의 표준
  출력을 `from_json` 으로 읽어 계약을 어기면 `ContractError` 다
- 값 검사: 절대 경로의 일반 파일이 아니면 `ForgeError(2, "error: HARNESS_FORGE_FAKE must be an absolute path to a regular file")`. 값은
  어떤 출력에도 옮기지 않는다
- 이 주입 지점은 security-guard 검토 대상이다(명세 4-4) — 구현 리뷰 요청 전에 사람이 `/security-guard` 로 검토한다(`plan.md`)
- 건드릴 파일: `src/harness/forge/__init__.py`, `src/harness/forge/shell.py`(신규), `src/test/unit/test_forge_common.py` ·
  `test_forge_shell.py`(신규), `src/test/unit/test_forge_contract.py`

### 완료 조건

- [ ] `load()` 가 설정의 트래커와 리뷰 호스트를 따로 골라 묶는다 — 트래커 Jira · 리뷰 호스트 GitHub 조합이 성립한다
- [ ] `Forge` 가 계약 함수 24개를 메서드로 갖고, 반환값이 명세 2-12 의 타입이다
- [ ] `call()` 의 직렬화가 명세 2-2 와 같다 — JSON 은 `json.dumps(값, ensure_ascii=False)` 의 기본 구분자로 끝 줄바꿈 없이, 한 줄은 값 뒤 줄바꿈
  하나, 실패한 함수는 계약 출력 없음
- [ ] 셸 구현의 `call()` 이 셸 함수의 종료 코드 · 표준 출력 · 표준 오류를 손대지 않고 돌려준다
- [ ] `HARNESS_FORGE_FAKE` 가 상대 경로 · 없는 파일 · 디렉터리면 2 와 고정 문구이고 어느 출력에도 그 값이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 브랜치 경계 | 열린 목록에 `feat/12-x` · `feat/123-x` · `feat/12` | 이슈 12 에 첫째 · 셋째만 |
| UT-02 | 본문 키워드 | 본문 `closes #12` · `Closes #123` · `Closes org/repo#12` | 대소문자 무시로 첫째 · 셋째, 뒤 경계로 둘째 제외 |
| UT-03 | 종료 참조 키워드 | `ISSUE_CLOSES_KEYWORD=Fixes` 로 `load()` | `Fixes #12` 에 맞고 `Closes #12` 에 맞지 않는다 |
| UT-04 | 목록 실패 | `review_mr_list_open` 이 `ForgeError(1)` | `harness_issue_open_mrs` 가 1 |
| UT-05 | 군 선택 | 트래커 · 리뷰 호스트 조합(github/github · gitlab/gitlab · jira/github) | 각 군이 그 어댑터, `forge_require` 가 둘 다 부른다 |
| UT-06 | 직렬화 | JSON 객체 · 배열 · 한 줄 · 없음 · 그대로 출력 함수 | 명세 2-2 모양, `review_branch_protected` 는 `true` / `false` 한 줄 |
| UT-07 | 오류 변환 | 메서드가 `ForgeError(3)` · `ForgeError(1, "error: x")` · `KeyError` | 3 과 빈 출력 · 1 과 표준 오류 `error: x` 한 줄 · 2 와 표준 오류 `error: <함수>: KeyError` 한 줄, 셋 다 표준 출력 없음 |
| UT-08 | 셸 구현 세 값 | 임시 셸 파일의 함수가 표준 출력 · 표준 오류 · 종료 코드 5 | `call()` 이 그대로 돌려준다 |
| UT-09 | 셸 구현 타입 메서드 | `review_mr_view` 가 `head_sha` 없는 JSON | `ContractError`, 메시지에 `head_sha` |
| UT-10 | 본문 전달 | 셸 구현의 `review_mr_note_summary` 에 본문 문자열 | 셸 함수가 받은 경로의 내용이 본문이고 호출 뒤 그 파일이 없다 |
| UT-11 | 값 검사 | 상대 경로 · 없는 절대 경로 · 디렉터리 | `ForgeError(2)`, 문구에 그 값이 없다 |

## T7 · feat: harness forge 로 계약 함수 하나 호출

### 상위 Requirement

- relates to #209

### 작업 내용

계약 함수 하나를 부르는 통과 명령 `harness forge` 를 더한다. `script/forge.sh` 는 아직 셸 어댑터를 source 한다. 이 명령은 새로 생길 뿐 기존
동작을 바꾸지 않는다.

- 명세 3-1 · 3-5 · 4-3 둘째 항목 · 8-4 의 새 블록 가운데 "`harness forge` 인자" · "본문 전달"(표준 입력 쪽) · "출력 그대로" · "값 검사" ·
  "명령 등록"(`forge`) · "터미널 출력"
- `src/harness/commands/forge.py` 의 `cmd_forge(cfg, target, args)` — 함수 이름 · 인수 개수 · 본문 자리 검사(3-1 의 오류 표, 모두 2), 본문 자리의
  `-` 는 표준 입력을 읽어 본문 문자열로, `load()` · `call()` 의 세 값을 그대로 내고 그 밖에는 아무것도 출력하지 않는다
- `src/harness/commands/__init__.py` 의 `COMMANDS` 에 명세 3-5 의 `forge` 항목, `src/harness/cli.py` 의 `DELEGATES` 에 `forge`
- `src/test/fake-forge.sh` 머리글: 쓰는 곳 `src/test/render-test.sh`, 끼우는 법 — 셸 호출부는 `script/forge.sh` 자리에 덮어 끼우고 CLI 는
  `HARNESS_FORGE_FAKE` 로 끼운다(명세 7절)
- `src/test/render-test.sh` 에 새 `UT-<번호>` 블록 — 원격을 부르지 않는다. 페이크는 `HARNESS_FORGE_FAKE`, forge CLI 는 PATH 앞 스텁
- 건드릴 파일: `src/harness/commands/forge.py`(신규), `src/harness/commands/__init__.py`, `src/harness/cli.py`, `src/test/fake-forge.sh`,
  `src/test/render-test.sh`

### 완료 조건

- [ ] `harness --target D forge <함수>` 와 `harness forge --target D <함수>` 가 모두 하네스 루트 `D` 에서 함수를 부른다
- [ ] 함수 이름 뒤의 `--help` · `--target` 이 함수 인수로 간다
- [ ] 함수 이름 없음 · 모르는 함수 · 인수 개수 다름 · 본문 자리가 `-` 아님이 명세 3-1 의 문구와 2 다
- [ ] 표준 입력으로 준 요약 본문이 페이크에 그대로 남는다
- [ ] 함수의 표준 출력 · 표준 오류 · 종료 코드만 나오고 다른 줄이 없다
- [ ] `harness help` 에 `forge` 와 명세 3-5 의 설명이 있다
- [ ] 권한 허용 목록(`.claude/settings.json` 의 allow)이 바뀌지 않는다
- [ ] 새 블록의 출력에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 하네스 루트 자리 | 명령 이름 앞의 `--target D`, 이름 바로 뒤의 `--target D` | 둘 다 `D` 의 설정과 페이크로 돈다 |
| UT-02 | 함수 인수 통과 | 함수 이름 뒤에 `--help` · `--target` 을 본문으로 준 쓰기 함수 | 페이크 스레드에 그 본문이 남는다 |
| UT-03 | 인자 오류 | 함수 없음 / `nosuch` / `review_mr_view` 인수 0개 / `review_mr_note_summary 1 body.md` | 2 와 usage / `unknown forge function` / `takes` / `pass -` |
| UT-04 | 표준 입력 본문 | `review_mr_note_summary 1 -` 에 표준 입력으로 본문 | 페이크에 남은 요약 본문이 같다 |
| UT-05 | 출력 그대로 | 페이크 `FAKE_AUTH=fail` 로 `tracker_auth` | 1 과 표준 오류 한 줄 ``run `fake auth login` `` 만 |
| UT-06 | 값 검사 | `HARNESS_FORGE_FAKE` 상대 경로 · 없는 파일 | 2 와 명세 4-2 문구, 출력 어디에도 그 값이 없다 |
| UT-07 | 명령 등록 | `harness help` | `forge` 가 있다 |
| UT-08 | 한글 없음 | 블록의 모든 출력 | 한글이 없다 |

## T8 · feat: doctor 의 어댑터 판정과 원격 forge 호출을 Python 어댑터로 전환하고 forge fake 경고 추가

### 상위 Requirement

- relates to #209

### 작업 내용

doctor 가 셸 어댑터 파일 대신 실행 중인 CLI 패키지의 어댑터 모듈 머리글로 미검증을 판정하고, `--remote` 의 forge 호출을 `harness forge`
하위 프로세스로 띄운다. 주입이 켜져 있으면 경고한다. 항목 문구는 그대로다.

- 명세 4-3 · 5-1 · 5-2 · 5-3 · 8-3 의 UT-79(나머지) · UT-83(페이크 주입) · 8-4 의 "알림" 가운데 doctor · 8-5 의 `test_forge_contract.py`
  머리글 판정
- `src/harness/readiness/items.py`
  - `adapter <kind>` — `PACKAGE/forge/<kind>.py` 의 모듈 docstring(`ast.get_docstring`)에 `ADAPTER_UNVERIFIED` 가 있으면 `warn`
    ``unverified — run `script/forge-selftest.sh` ``, 아니면 `ok`. `file is missing` 항목을 지운다. 판정 함수는 모듈 소스 텍스트를 받아
    머리글을 돌려준다. 표지 문자열은 상수 `ADAPTER_UNVERIFIED` 하나가 갖는다
  - `forge fake` — `HARNESS_FORGE_FAKE` 가 비지 않으면 어댑터 줄 뒤에 `warn` `HARNESS_FORGE_FAKE is set — forge calls go to that file, not the forge`.
    값은 옮기지 않는다
- `src/harness/readiness/remote.py` 의 forge 호출 — `sys.executable` 로 `ENTRY` 를 `--target <하네스 루트> forge <함수> <인수...>` 와 함께
  `remote_call()` 로 띄운다. 제한 시간 · 닫힌 표준 입력 · 새 세션 · 원격 환경(`GIT_TERMINAL_PROMPT=0` · `HARNESS_METRICS=off`)과 결과 판정은
  그대로이고 `HARNESS_FORGE_FAKE` 는 그 환경으로 물려받는다. CLI 가 forge CLI 를 직접 부르지 않는다
- `src/test/render-test.sh`
  - UT-79: 설치본의 어댑터 파일을 고쳐 보던 두 경우(본문 주석의 낱말 · 첫 주석 덩어리 뒤의 표지)를 지우고 단위 테스트로 옮긴다. 계약 문구
    단언의 파일을 `src/harness/forge/contract.py` 로. `adapter gitlab` 이 `warn` 인 첫 경우는 그대로
  - UT-83: `script/forge.sh` 덮어쓰기를 `fdoc` 의 환경에 `HARNESS_FORGE_FAKE` 로. 기대값은 그대로
  - 새 블록에 "알림" 의 doctor 케이스
- `test_forge_contract.py` 에 머리글 판정 케이스
- 건드릴 파일: `src/harness/readiness/items.py`, `src/harness/readiness/remote.py`, `src/test/render-test.sh`, `src/test/unit/test_forge_contract.py`

### 완료 조건

- [ ] gitlab · jira 설정의 doctor 가 `adapter <kind>` 를 `warn` ``unverified — run `script/forge-selftest.sh` `` 로 낸다
- [ ] doctor 가 `script/forge/` 아래 파일을 읽지 않는다 — 설치본의 셸 어댑터 파일을 지워도 `file is missing` 이 나오지 않는다
- [ ] `HARNESS_FORGE_FAKE` 를 준 doctor 에 `warn` `forge fake` 가 있고 그 값이 출력에 없다. 주지 않으면 그 줄이 없다
- [ ] `doctor --remote` 의 sign-in · label · branch protection 항목이 UT-83 의 기대값 그대로 나오고, UT-82 · UT-100 이 고치지 않고 통과한다
- [ ] UT-79 의 표지 상수 · 표지 문자열 세기가 각 1 이다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | docstring 의 표지 | 모듈 docstring 에 `검증 상태: 미검증` | 미검증 |
| UT-02 | 주석의 낱말 | docstring 에 없고 `#` 주석에 `검증 상태: 미검증` | 미검증 아님 |
| UT-03 | 함수 docstring 의 낱말 | 모듈 docstring 에 없고 함수 docstring 에 표지 | 미검증 아님 |
| UT-04 | doctor 미검증 판정 | gitlab 설정으로 `doctor --json` | `adapter \`gitlab\`` 가 `warn` 과 미검증 문구 |
| UT-05 | forge fake 경고 | `HARNESS_FORGE_FAKE` 를 준 / 주지 않은 `doctor` | `warn` `forge fake` 있음, 값 없음 / 줄 없음 |
| UT-06 | 원격 호출 | 페이크를 `HARNESS_FORGE_FAKE` 로 준 `doctor --remote` | UT-83 의 로그인 · 라벨 · 브랜치 보호 기대값 |

## T9 · refactor: script/forge.sh 를 계약 표에서 생성하는 harness forge shim 으로 전환

### 상위 Requirement

- relates to #209

### 작업 내용

생성 파일 `script/forge.sh` 가 어댑터 파일을 source 하지 않고, 계약 함수마다 `harness forge <함수>` 를 부르는 셸 함수를 정의하는 shim 이
된다. 셸 호출부는 지금처럼 `. script/forge.sh` 뒤 같은 함수를 같은 인자로 부른다. 셸 어댑터 파일은 이 task 뒤에도 깔려 있지만 아무도
source 하지 않는다.

- 명세 1절(셸 호출부 불변) · 3-2 · 7절의 `src/templates/forge/forge.md` · `src/templates/managed/script/README.md` 의 생성 행 ·
  8-3 의 UT-11 · UT-33 · 8-4 의 "shim"(`script/forge.sh`) · "본문 전달"(셸 shim 쪽)
- `src/templates/generated/script/forge.sh` 원형을 다시 쓴다 — 머리글(고치지 않는다는 문구, source 방법, 계약 함수 표, 정규화 JSON 형태,
  계약 정본 `forge/contract.py`), 하네스 루트(`$0` 의 부모, 아니면 현재 디렉터리, 둘 다 아니면 `error: could not locate the harness root from <디렉터리>`
  와 2), CLI(`<루트>/.harness/bin/harness`, `<루트>/src/bin/harness` 순), CLI 를 못 찾을 때의 두 줄과 2
- `src/harness/render/scripts.py`: 원형에 계약 함수 표(`contract.py`)로 머리글의 함수 표와 함수 정의를 채운다. 설정 값은 넣지 않는다.
  본문 파일 자리 함수는 그 파일을 표준 입력으로 넘기고 그 자리에 `-` 를 둔다. 현재 디렉터리를 바꾸지 않는다
- `src/templates/forge/forge.md`: "함수 목록과 출력 계약은 `script/forge.sh` 머리글에 있다. CLI 패키지의 계약 표(`forge/contract.py`)에서
  생성된다."
- `src/templates/managed/script/README.md` 부류 표의 생성 행 `forge.sh`: "계약 함수마다 `harness forge` 를 부르는 shim"
- `src/test/render-test.sh`
  - UT-11: `script/forge.sh` 내용 단언 둘과 `gitlab.sh` 의 `GITLAB_CLI` 단언을, github 설정의 `$t` 에서 `harness forge --target "$t" tracker_current_user`
    가 PATH 앞 `gh` 스텁만 부르고 `glab` 스텁은 부르지 않는 것으로, gitlab 설정에서는 `glab` 스텁으로 가는 것으로. `.ai/forge.md` 단언 둘은 그대로
  - UT-33: `forge/jira.sh` 단언을 jira 트래커 설정에서 `tracker_current_user` 가 `jira` 스텁으로 가는 것으로. 정규화 확인의 호출을
    `harness forge --target "$t" tracker_issue_list` 로. 나머지 기대값은 그대로
  - 새 블록에 "shim" 의 `script/forge.sh` 케이스와 "본문 전달" 의 셸 shim 케이스
- `src/bin/harness render` 로 이 리포의 `script/forge.sh` · `.ai/forge.md` · `script/README.md` 와 매니페스트를 갱신한다
- 건드릴 파일: `src/templates/generated/script/forge.sh`, `src/harness/render/scripts.py`, `src/templates/forge/forge.md`,
  `src/templates/managed/script/README.md`, `src/test/render-test.sh`, render 로 갱신되는 생성 파일과 `script/`

### 완료 조건

- [ ] 생성된 `script/forge.sh` 가 계약 함수 24개를 하나씩 정의하고 `script/forge/` 를 source 하지 않는다
- [ ] forge 설정(github · gitlab · jira 트래커)을 바꿔 render 해도 `script/forge.sh` 내용이 같다
- [ ] 고정 사본의 CLI 를 치운 리포에서 함수가 2 와 `harness CLI not found under` · `help: harness install --target` 두 줄을 낸다
- [ ] 셸 shim 으로 `review_mr_note_summary 1 <파일>` 을 부르면 페이크에 남은 요약 본문이 그 파일 내용과 같다
- [ ] UT-99 와 셸 호출부 테스트가 고치지 않고 통과한다
- [ ] `.ai/forge.md` 가 계약의 자리를 `script/forge.sh` 머리글로 적는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 함수 정의 | 생성된 `script/forge.sh` | 계약 함수 24개가 하나씩 정의되어 있다 |
| UT-02 | 설정 무관 | github · gitlab · jira 트래커 설정으로 각각 render | 세 `script/forge.sh` 가 같다 |
| UT-03 | CLI 없음 | `.harness/bin/harness` 를 치운 설치본에서 `. ./script/forge.sh && tracker_current_user` | 2 와 두 줄 |
| UT-04 | 본문 전달 | 셸 shim 의 `review_mr_note_summary 1 <파일>`, 페이크는 `HARNESS_FORGE_FAKE` | 페이크의 요약 본문이 파일 내용과 같다 |
| UT-05 | 어댑터 선택 | github · gitlab 설정의 `harness forge --target "$t" tracker_current_user`, PATH 앞 `gh` · `glab` 스텁 | 설정한 forge 의 스텁만 불린다 |
| UT-06 | Jira 트래커 | jira 트래커 설정의 `tracker_current_user` · `tracker_issue_list` | `jira` 스텁으로 가고 정규화 기대값 다섯 |

## T10 · feat: 자체 검사를 harness forge-selftest 로 이식하고 script/forge-selftest.sh 를 shim 으로 전환

### 상위 Requirement

- relates to #209

### 작업 내용

`script/forge-selftest.sh` 의 자체 검사를 CLI 통과 명령 `harness forge-selftest` 로 옮긴다. 스크립트는 같은 인자로 그 명령을 exec 하는 shim
이 된다. 명령줄 · 단계 · 항목 · 판정 · 종료 코드는 그대로다. 표지는 표지 모듈로 읽는다.

- 명세 2-1 의 `format.py` · 3-3 · 3-5 · 4-3 · 7절의 `script/README.md` `forge-selftest.sh` 행 · 8-1 의 페이크 11종 · 8-3 의 UT-16 · UT-81(페이크 주입) ·
  8-4 의 "shim"(`script/forge-selftest.sh`) · "알림"(자체 검사) · "명령 등록"(`forge-selftest`) · 8-5 의 `test_format.py`
- `src/harness/format.py`: 착수 시점에 `develop` 에 있으면(#210 이 먼저 머지) 그것을 쓰고 고치지 않는다. 없으면 명세 2-1 의 `markers(root)` ·
  `FormatError` 로 만들고 `src/test/unit/test_format.py` 를 함께 둔다
- `src/harness/forge/selftest.py` — 공유 설정의 `forge.tracker` · `forge.review_host` · `branches.base` · `review.round_label` · `issues.labels` ·
  `issues.deletion_forbidden` 을 읽고, `load()` 한 `Forge` 에 `call()` 로 명세 3-3 의 단계 · 항목 · 판정을 돈다. `FMT_ISSUE_WORK` ·
  `FMT_ISSUE_RELATES` · `FMT_MR_CLOSES` 를 `markers()` 로 읽고, 읽지 못하면 `error: cannot read the markers from <루트>/script/harness-format.sh` 와 2.
  끝 안내의 어댑터 경로는 `src/harness/forge/<kind>.py`
- `src/harness/commands/forge_selftest.py` 의 `cmd_forge_selftest`, `COMMANDS` 에 명세 3-5 의 `forge-selftest` 항목, `DELEGATES` 에 `forge-selftest`.
  주입이 켜져 있으면 표준 오류 첫 줄에 `note: HARNESS_FORGE_FAKE is set — forge calls go to that file, not the forge`
- `src/templates/managed/script/forge-selftest.sh` — 명세 3-3 의 shim: 첫 줄 `#!/usr/bin/env sh`, 자기 디렉터리의 부모를 하네스 루트로,
  `<루트>/.harness/bin/harness` · `<루트>/src/bin/harness` 순의 첫 실행 가능한 CLI 로 `--target <루트> forge-selftest <받은 인자 그대로>` 를 exec.
  현재 디렉터리 · 표준 입출력 · 환경을 바꾸지 않고 설정과 생성물을 읽지 않는다. CLI 가 없으면 두 줄과 2. 머리글은 부르는 명령과 로직이 CLI
  패키지에 있다는 것
- `src/templates/managed/script/README.md` 의 `forge-selftest.sh` 행에 "shim — `harness forge-selftest` 를 같은 인자로 부른다"
- `src/test/render-test.sh`
  - UT-16: `fake-forge.sh` 를 `script/forge.sh` 로 복사하던 것을, 자체 검사 실행과 페이크 함수 호출의 환경에 `HARNESS_FORGE_FAKE=<fake-forge.sh 절대 경로>` 로.
    페이크의 `tracker_labels_ensure` 확인은 같은 환경으로 `. ./script/forge.sh` 를 거친다. 기대값은 전부 그대로
  - UT-81: `script/forge.sh` 덮어쓰기를 `HARNESS_FORGE_FAKE` 로. 자체 검사 · 페이크 기대값은 그대로
  - 새 블록에 "shim" 의 `script/forge-selftest.sh` 케이스, "알림" 의 자체 검사 케이스, "명령 등록" 의 `forge-selftest`
- `src/bin/harness render` 로 이 리포의 `script/forge-selftest.sh` · `script/README.md` 사본과 `.harness/managed` 를 갱신한다
- 건드릴 파일: `src/harness/forge/selftest.py`(신규), `src/harness/commands/forge_selftest.py`(신규), `src/harness/commands/__init__.py`,
  `src/harness/cli.py`, 만들 때 `src/harness/format.py` · `src/test/unit/test_format.py`(신규), `src/templates/managed/script/forge-selftest.sh` ·
  `README.md`, `src/test/render-test.sh`, render 로 갱신되는 `script/` 와 매니페스트

### 완료 조건

- [ ] 계약을 지키는 페이크에서 읽기 · `--write` · `--create-issue` 가 0 이고, `--create-issue` 에 skip 이 없다
- [ ] 페이크의 계약 위반 11종(UT-16 의 9종 · UT-81 의 2종)마다 자체 검사가 1 로 끝난다
- [ ] 대상 없음 · `--create-issue` 에 이슈 없음 · 모르는 옵션이 명세 3-3 의 문구와 2 다
- [ ] 표지 파일이 없거나 형식이 아니면 `cannot read the markers from` 과 2 다
- [ ] `script/forge-selftest.sh` 가 받은 인자를 그대로 넘기고 CLI 의 종료 코드를 돌려주며, CLI 를 치운 리포에서 2 와 두 줄이다
- [ ] 주입한 자체 검사의 표준 오류 첫 줄이 명세 4-3 의 `note:` 문구다
- [ ] `harness help` 에 `forge-selftest` 와 명세 3-5 의 설명이 있다
- [ ] `script/forge-selftest.sh` 가 권한 허용 목록에서 빠진 채다(`ALLOW_EXCLUDED`)
- [ ] `format.py` 를 만들었으면 `test_format.py` 가 명세 8-5 의 내용을 본다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 계약을 지키는 페이크 | 페이크를 `HARNESS_FORGE_FAKE` 로, 읽기 / `--write` / `--create-issue` | 0 / 0 / 0 과 skip 없음, 설정의 이슈 라벨 셋을 넘김 |
| UT-02 | 위반 9종 | `FAKE_BREAK` 가 `mr_view` · `threads` · `thread_id` · `issue_list` · `open_mrs` · `inline_any` · `reply_any` · `reply_new` · `create_url` | 각각 1 |
| UT-03 | 위반 2종 | `FAKE_BREAK` 가 `labels` · `protected` | 각각 1 |
| UT-04 | 인자 오류 | 인자 없음 / `--create-issue 1` / `--bogus 1` | 2 와 usage / 이슈 번호 안내 / `unknown option` |
| UT-05 | 표지 읽기 실패 | `script/harness-format.sh` 를 치운 설치본 | 2 와 `cannot read the markers from` |
| UT-06 | shim 의 CLI 없음 | `.harness/bin/harness` 를 치운 설치본의 `script/forge-selftest.sh 1` | 2 와 `harness CLI not found under` · `help: harness install --target` |
| UT-07 | 알림 | 주입한 `forge-selftest` | 표준 오류 첫 줄이 `note: HARNESS_FORGE_FAKE is set — forge calls go to that file, not the forge` |
| UT-08 | 명령 등록 | `harness help` | `forge-selftest` 가 있다 |
| UT-09 | 표지 읽기 (`format.py` 를 만들 때) | `src/templates/managed/script/harness-format.sh` | `markers()` 가 그 파일을 셸로 source 한 `FMT_*` 값 전부와 같다 |
| UT-10 | 표지 형식 오류 (`format.py` 를 만들 때) | 형식이 아닌 줄 · 없는 파일 · 디렉터리 · `FMT_X=$(…)` 줄 | `FormatError` 와 메시지의 경로, 명령 치환이 실행되지 않는다 |

## T11 · refactor: harness forge-setup 이 라벨을 직접 준비하고 script/forge-setup.sh 를 shim 으로 전환

### 상위 Requirement

- relates to #209

### 작업 내용

`harness forge-setup` 이 `script/forge-setup.sh` 를 돌리던 방향을 뒤집는다. 명령이 `load()` 한 `Forge` 로 라벨을 스스로 준비하고, 스크립트는
그 명령을 exec 하는 shim 이 된다. 출력 · 종료 코드는 그대로다.

- 명세 3-4 · 4-3 · 7절의 `script/README.md` `forge-setup.sh` 행 · 8-3 의 UT-98 · `test-forge-setup.sh` · 8-4 의 "알림"(라벨 준비)
- `src/harness/commands/forge_setup.py` — `tracker_require`(실패하면 그 표준 오류와 2) → `tracker_labels_ensure <requirement> <task> <invalid>`
  (`issues.labels`, 실패하면 그 표준 오류 뒤 `stop: could not prepare labels on <tracker>` 와 2) → 표준 출력
  `forge-setup: labels ready on <tracker>: <라벨, 없으면 none>` 과 0. 통과 명령이 아니다. 주입이 켜져 있으면 표준 오류 첫 줄에 명세 4-3 의 `note:`
- `src/templates/managed/script/forge-setup.sh` — T10 과 같은 형태의 shim 으로 `--target <루트> forge-setup <받은 인자 그대로>` 를 exec
- `src/templates/managed/script/README.md` 의 `forge-setup.sh` 행을 "shim — `harness forge-setup` 을 부른다" 로, 호출 시점 "사람이 1회"
- `src/test/render-test.sh` UT-98: 페이크 덮어쓰기를 `HARNESS_FORGE_FAKE` 로. 실행 방향 단언 셋을 shim 방향으로 — `script/forge-setup.sh` 가
  CLI 를 `--target <하네스 루트> forge-setup` 으로 부르고 그 종료 코드를 돌려준다(고정 사본의 CLI 자리에 둔 스텁이 받은 인수를 남기고 7 로
  끝나면 7), CLI 가 없으면 2 와 `harness CLI not found under`. 라벨 · 표준 출력 · help · 한글 검사 기대값은 그대로
- `src/templates/managed/script/test-forge-setup.sh`: `setup_run` 준비부를 샌드박스 하네스 루트(라벨 값을 바꾼 `harness.toml`, shim
  `script/forge-setup.sh`, 샌드박스 CLI 자리)로. 페이크는 `HARNESS_FORGE_FAKE`. 하네스 루트의 `harness.toml` 전제를 더한다. `check` 기대값과
  tracker 를 `script/harness.env` 에서 읽는 줄은 그대로
  - 샌드박스 CLI 자리는 `<샌드박스>/.harness/bin/harness` 에 둔 하네스 루트 CLI 로의 심볼릭 링크다 — 셸 래퍼를 두지 않는다(명세 8-3)
- 새 블록에 "알림" 의 라벨 준비 케이스
- `src/bin/harness render` 로 이 리포의 `script/forge-setup.sh` · `script/test-forge-setup.sh` · `script/README.md` 사본과 `.harness/managed` 를 갱신한다
- 건드릴 파일: `src/harness/commands/forge_setup.py`, `src/templates/managed/script/forge-setup.sh` · `test-forge-setup.sh` · `README.md`,
  `src/test/render-test.sh`, render 로 갱신되는 `script/` 와 매니페스트

### 완료 조건

- [ ] `harness forge-setup` 이 설정의 이슈 라벨을 페이크에 넘기고 `forge-setup: labels ready on github: Requirement, Task, invalid` 와 0 이다
- [ ] 트래커를 쓸 수 없거나 라벨을 만들지 못하면 명세 3-4 의 표준 오류와 2 다
- [ ] `harness forge-setup` 이 `script/forge-setup.sh` 를 부르지 않는다
- [ ] `script/forge-setup.sh` 가 CLI 를 `--target <하네스 루트> forge-setup` 으로 부르고 그 종료 코드를 돌려주며, CLI 가 없으면 2 와 `harness CLI not found under` 다
- [ ] `test-forge-setup.sh` 가 라벨을 `harness.toml` 로 넣은 샌드박스에서 기존 `check` 기대값을 통과한다
- [ ] 주입한 `forge-setup` 의 표준 오류 첫 줄이 명세 4-3 의 `note:` 문구다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 라벨 준비 | 페이크를 `HARNESS_FORGE_FAKE` 로 `harness forge-setup` | 0, 페이크에 `Requirement Task invalid`, 표준 출력 한 줄 |
| UT-02 | 빈 라벨 | `issues.labels` 의 task 를 빈 값으로 | 빈 값을 건너뛰고 출력 목록에서도 빠진다 |
| UT-03 | 트래커 실패 | `FAKE_REQUIRE=fail` · `FAKE_ENSURE=fail` 의 `test-forge-setup.sh` 케이스 | 2, 둘째는 `stop: could not prepare labels on` |
| UT-04 | shim 방향 | 고정 사본 CLI 자리에 인수를 남기고 7 로 끝나는 스텁 | `script/forge-setup.sh` 가 7, 스텁이 `--target <하네스 루트> forge-setup` 을 받음 |
| UT-05 | shim 의 CLI 없음 | CLI 자리를 치운 설치본의 `script/forge-setup.sh` | 2 와 `harness CLI not found under` |
| UT-06 | 알림 | 주입한 `forge-setup` | 표준 오류 첫 줄이 `note:` 문구 |

## T12 · refactor: 셸 어댑터 파일 제거와 대상 리포 script/forge/ 정리

### 상위 Requirement

- relates to #209

### 작업 내용

아무도 source 하지 않게 된 셸 어댑터 파일(`_common.sh` · `github.sh` · `gitlab.sh` · `jira.sh`)을 관리 파일에서 지운다. 다음 install · render 의
정리가 대상 리포의 `script/forge/` 를 걷는다. 그 파일을 가리키던 테스트 줄 · 문서 · 주석을 함께 고친다.

- 명세 6절 · 7절의 `docs/workflow/` 두 문서와 `script/README.md` 의 어댑터 행 · 규칙 · 8-3 의 UT-63 · UT-81(어댑터 파일 grep) ·
  `test-forge-labels.sh` · 8-4 의 "정리"
- `src/templates/managed/script/forge/` 를 지운다. `src/bin/harness render` 가 이 리포의 `script/forge/` 를 지우고 `.harness/managed` 를 갱신한다 —
  그 삭제가 이 커밋에 든다
- `src/test/render-test.sh`
  - UT-63: 어댑터 파일 복사와 source 를 github · gitlab 설정의 샌드박스 하네스 루트에 `harness forge --target` 으로. Jira 리뷰 답글 거부 두 줄을
    지운다 — T5 의 단위 테스트가 본다. 기대값은 그대로
  - UT-81: 어댑터 머리글 · 계약 표 · 함수 정의를 grep 하던 줄을 지운다 — T2 ~ T5 의 단위 테스트가 본다
  - 새 블록에 "정리" 케이스
- `src/templates/managed/script/test-forge-labels.sh`: 전제(`script/forge/github.sh`)를 하네스 루트의 CLI 와 `script/forge.sh` 로. `adapter()` 로더를
  샌드박스 하네스 루트(설정의 forge 만 github 로 바꾼 `harness.toml`, 하네스 루트에서 복사한 `script/forge.sh`, 샌드박스 CLI 자리)에서
  `. ./script/forge.sh` 뒤 함수를 부르는 것으로. Jira 블록의 전제와 로더도 같은 방식의 jira 트래커 설정 샌드박스로. `check` 기대값은 그대로
  - 샌드박스 CLI 자리는 T11 과 같은 심볼릭 링크다
- 문서
  - `src/templates/managed/docs/workflow/README.md`: "어댑터는 `script/forge/` 에 이미 있다" → "어댑터는 CLI 패키지에 이미 있다"
  - `src/templates/managed/docs/workflow/changing.md`: `forge 함수 구현` 행 → `src/harness/forge/<kind>.py` — **한 곳**
  - `src/templates/managed/script/README.md`: 목록의 `forge/_common.sh` · `forge/<kind>.sh` 행을 지운다. 규칙의 "어댑터를 새로 쓰거나 고치면 …" 을
    "어댑터(CLI 패키지의 `forge/`)를 새로 쓰거나 고치면 `forge-selftest.sh` 를 실제 forge 로 돌린다. 회귀 테스트는 페이크와 CLI 스텁을 쓰므로
    실제 forge 의 응답을 보지 않는다" 로
  - `src/templates/forge/github/review.md` 끝의 "어댑터 미검증" 인용에서 지워지는 파일 경로 `script/forge/github.sh` 를 경로가 아닌 이름
    (GitHub 어댑터)으로 바꾼다 — 렌더된 `.ai/forge.md` 가 없는 파일을 가리키면 doctor 의 참조 검사(UT-29)가 잡는다. 인용 자체는 T16 이 지운다
- 주석: `test-review-loop.sh` · `test-sync-task-issues.sh` · `test-carryover-issue.sh` · `test-rollback-work.sh` 의 계약 자리 주석
  (`script/forge/_common.sh` 상단)을 `script/forge.sh` 머리글로. 검사 줄은 고치지 않는다
- `src/bin/harness render` 로 이 리포의 `script/` · `docs/workflow/` · `.ai/forge.md` 와 매니페스트를 갱신한다
- 건드릴 파일: `src/templates/managed/script/forge/`(삭제), `src/templates/managed/script/test-forge-labels.sh` · `README.md` · 위 네 `test-*.sh`,
  `src/templates/managed/docs/workflow/README.md` · `changing.md`, `src/templates/forge/github/review.md`, `src/test/render-test.sh`, render 로 갱신되는
  `script/` · `docs/workflow/` · 생성 파일 · 매니페스트

### 완료 조건

- [ ] `src/templates/managed/script/forge/` 와 이 리포의 `script/forge/` 가 없다
- [ ] `script/forge/` 를 가진 옛 매니페스트의 리포를 render 하면 `script/forge/` 가 없어진다
- [ ] 새로 설치한 리포(github 설정)의 doctor 가 "every path a document names exists" 다
- [ ] UT-63 · UT-81 · `test-forge-labels.sh` 가 고치지 않은 기대값으로 통과한다
- [ ] `src/harness/` · `src/templates/` · `script/` · `docs/workflow/` 에 `script/forge/_common.sh` · `script/forge/<kind>.sh` 를 가리키는 줄이 없다
- [ ] 페이크의 계약 위반 11종 검사가 그대로 남아 각각 1 이다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 정리 | `.harness/managed` 에 `script/forge/*.sh` 줄이 있는 옛 설치본을 render | `script/forge/` 가 없고 매니페스트에 그 줄이 없다 |
| UT-02 | 스레드 · 답글 경로 | UT-63 의 `gh` · `glab` 스텁, 샌드박스 하네스 루트의 `harness forge --target … review_mr_threads 5` · `review_mr_thread_reply` | 옛 기대값과 같다 |
| UT-03 | 라벨 준비 회귀 | 샌드박스 하네스 루트의 `test-forge-labels.sh` 전 케이스 | 옛 `check` 기대값 통과, Jira 는 호출 없음 |
| UT-04 | 끊긴 참조 없음 | 새로 설치한 github 설정 리포의 doctor | "every path a document names exists" |

## T13 · feat: UI doctor 문구의 어댑터 파일 없음 분기 제거와 forge fake 경고 추가

### 상위 Requirement

- relates to #209

### 작업 내용

CLI 가 더 내지 않는 `adapter <kind>` 의 `file is missing` 설명을 UI 에서 지우고, 새 `forge fake` 경고의 설명을 더한다.

- 명세 5-4 · 8-6
- `src/ui/lib/doctor.js`: `adapter <kind>` 의 `file is missing` 분기 삭제. 미검증 문구와 조치(`script/forge-selftest.sh`)는 그대로.
  `forge fake` — 제목 `forge 호출이 페이크로 갑니다`, 본문 `HARNESS_FORGE_FAKE 가 설정되어 있어 이슈·리뷰 요청 호출이 실제 forge 가 아니라 그 파일로 갑니다. 테스트가 아니면 환경에서 지웁니다.`,
  조치 명령 없음
- `src/ui/lib/doctor.test.js`: `file is missing` 케이스를 지우고 `forge fake` 케이스를 더한다
- 건드릴 파일: `src/ui/lib/doctor.js`, `src/ui/lib/doctor.test.js`

### 완료 조건

- [ ] `doctor.js` 에 `adapter <kind>` 의 `file is missing` 분기가 없다
- [ ] `forge fake` 항목이 명세 5-4 의 제목 · 본문으로 옮겨지고 조치 명령이 없다
- [ ] 미검증 어댑터 항목의 문구와 조치가 그대로다
- [ ] UI 단위 테스트가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | forge fake 설명 | `tools and connections` 의 `warn` `forge fake` 항목 | 명세 5-4 의 제목 · 본문, `run` 없음 |
| UT-02 | 미검증 그대로 | `adapter \`github\`` 의 `warn` 미검증 항목 | 기존 설명, `run` 없음 |

## T14 · docs: README 와 명세 59 · 60 에 Python forge 어댑터 반영

### 상위 Requirement

- relates to #209

### 작업 내용

사람이 읽는 README 와, 어댑터 · 라벨 준비의 자리를 셸 파일로 적던 기존 명세 둘을 이 명세의 절을 가리키게 고친다.

- 명세 7절의 `README.md`("계약 위반 6종" 행) · `docs/spec/59-doctor-remote-readiness.md` · `docs/spec/60-automate-work-prerequisites.md`
- `README.md` 검증 절: "계약 위반 6종" → "계약 위반 11종". 지원 범위 표의 GitHub 행은 T16 이 고친다
- `docs/spec/59-doctor-remote-readiness.md`: 3절의 어댑터 행과 그 아래 세 줄, 6-1 제목, 6-2 의 어댑터 이름, 6-3 의 `BASE_BRANCH` 출처를 이 명세
  (2-2 · 2-5 · 3-3 · 5-1)를 가리키게
- `docs/spec/60-automate-work-prerequisites.md`: 3-1 제목과 표의 어댑터 이름, 3-2 의 `cmd_forge_setup()` · `script/forge-setup.sh` 서술,
  3-3 의 위치를 이 명세(2-2 · 2-8 · 3-4)를 가리키게
- 건드릴 파일: `README.md`, `docs/spec/59-doctor-remote-readiness.md`, `docs/spec/60-automate-work-prerequisites.md`

### 완료 조건

- [ ] `README.md` 가 페이크의 계약 위반을 11종으로 적는다
- [ ] 위에 짚은 절(59 의 3절 어댑터 행과 그 아래 세 줄 · 6-1 · 6-2 · 6-3, 60 의 3-1 · 3-2 · 3-3)이 셸 어댑터 파일을 어댑터 자리로 적지 않고 `docs/spec/209-port-forge-adapters.md` 의 절을 가리킨다
- [ ] 명세 60 이 `harness forge-setup` → `script/forge-setup.sh` 실행 방향을 적지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 옛 자리 서술 없음 | 짚은 절에서 `script/forge/` · `_common.sh` · `github.sh` 같은 셸 어댑터 경로 검색 | 어댑터 자리로 적는 문장이 없다 |
| UT-02 | 위반 종 수 | `README.md` 검증 절 | "계약 위반 11종" 이 있고 "6종" 이 없다 |

## T15 · docs: 아키텍처 · 용어 · 담당 범위 · 테스트 문서에 Python forge 어댑터 반영

### 상위 Requirement

- relates to #209

### 작업 내용

forge 어댑터가 CLI 패키지로 옮겨 간 사실과 shim · 페이크 주입 지점을 에이전트가 근거로 읽는 문서에 적는다. **2026-10-09 결정 게이트에서
사용자가 허용한 범위** — 명세 10절의 "보호 문서 개정 범위" — 를 그대로 고치고, 그 범위 밖은 고치지 않는다.

**보호 문서를 수정하는 task 다.** `.ai/project/architecture.md` · `glossary.md` · `scope.md` · `testing.md` 는 보호 문서이므로 사용자가 이 task 를
지시한 턴에서 고친다(`.ai/AI_AGENT.md` 금지 사항, #166 선례). 권한 설정 · 가드에 걸리면 사람이 대응한다.

- 명세 10절 — 적용 순서는 #206 → #207 → #208 · #209 · #210 이다. 문안은 #206 · #207 이 고친 문장 위에 더한다. #206 9절이 둔 단위 테스트 층
  기본 문장은 다시 쓰지 않는다
- `.ai/project/architecture.md` — 명세 10-1 의 열 군데: "구성 요소" 의 `src/test/render-test.sh` 항목 · CLI 패키지 항목 · 대상 리포 `script/` 항목,
  "데이터 흐름" 의 forge, "신뢰 경계" 의 들어오는 입력, "새 코드를 둘 곳" 의 새 forge · 새 forge 계약 함수, "계층과 의존 방향" 의 규칙 값 줄 ·
  forge 줄, "검사하지 않는 것" 의 GitLab · Jira 줄과 새 항목
- `.ai/project/glossary.md` — 명세 10-2: `어댑터` · `자체 검사` 행 갱신, 새 행 `shim` · `forge 페이크`
- `.ai/project/scope.md` — 명세 10-3: "만들지 않는 것" 의 어댑터 자리를 `src/harness/forge/` 로
- `.ai/project/testing.md` — 명세 10-4: 자체 검사 항목(위반 11종), "외부 의존을 어떻게 다루나" 의 forge 항목
- `.ai/AI_AGENT.md` 는 생성 파일이다. 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/architecture.md` · `glossary.md` · `scope.md` · `testing.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] 네 문서가 명세 10-1 ~ 10-4 의 문안을 담고, 그 밖의 문장이 바뀌지 않는다
- [ ] 네 문서와 `.ai/AI_AGENT.md` 에 "계약 위반 6종" · `script/forge/<kind>.sh` · 어댑터 자리로서의 `script/forge/` 가 없다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 1 · 2 · 5장이 네 문서와 일치한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 반영 확인 | `.ai/AI_AGENT.md` | 2장에 `shim` · `forge 페이크` 행과 `src/harness/forge/<kind>.py` 의 `어댑터`, 5장에 `HARNESS_FORGE_FAKE` 신뢰 경계와 forge 데이터 흐름 |

## T16 · docs: GitHub 어댑터의 자체 검사 전 단계 통과 기록

### 상위 Requirement

- relates to #209

### 작업 내용

Python GitHub 어댑터로 자체 검사 전 단계(`--create-issue` 포함)를 이 리포의 GitHub 에서 돌리고, 통과한 결과를 한 커밋에 적는다.
되돌릴 수 없는 이슈 생성 단계는 사람의 확인을 받은 뒤에만 돈다.

- 명세 9절 · 7절의 `src/templates/forge/github/review.md` · `README.md` 지원 범위 표의 GitHub 행
- 전제: T1 ~ T12 가 커밋되어 회귀 테스트 · 단위 테스트가 통과한 브랜치, `HARNESS_FORGE_FAKE` 가 없는 셸, `gh` 로그인
- 대상: 사람이 지정한 이 리포의 버려도 되는 리뷰 요청 하나와 그것에 연결된 이슈(브랜치가 `<tag>/<이슈>-…` 이거나 본문에 `Closes <이슈>`)
- 순서
  1. `script/forge-selftest.sh <리뷰요청> <이슈>` — fail 0
  2. `--create-issue` 직전에 사람에게 확인을 구한다. 남는 것을 밝힌다 — 그 리뷰 요청에 댓글 3건(인라인 · 그 답글 · 요약)과 트래커에 이슈
     1건(이 리포는 이슈 삭제를 금지하므로 `invalid` 로 닫힌 채 영구히 남는다)
  3. 확인을 받으면 `script/forge-selftest.sh --create-issue <리뷰요청> <이슈>` — fail 0 · skip 0
- 기록(한 커밋)
  - `src/harness/forge/github.py` 머리글의 `검증 상태:` 줄 → `script/forge-selftest.sh --create-issue 전 단계 통과 (gh <그 실행의 gh 버전>)`
  - `README.md` 지원 범위 표의 GitHub 행 "실제 forge 검증" → `자체 검사 전 단계 통과 (gh <버전>)`
  - `src/templates/forge/github/review.md` 끝의 "어댑터 미검증" 인용 두 줄 삭제
- 구현 리뷰 요청 본문에 두 실행의 판정 줄(`pass · fail · skip`)과 gh 버전, 만들어진 이슈 번호를 적는다
- 만들어진 이슈는 사람이 `invalid` 로 닫는다. 남은 댓글과 버려도 되는 리뷰 요청도 사람이 정리한다. 에이전트는 이슈 · 리뷰 요청을 닫지 않는다
- `src/bin/harness render` 로 이 리포의 `.ai/forge.md` 를 갱신한다
- 건드릴 파일: `src/harness/forge/github.py`, `README.md`, `src/templates/forge/github/review.md`, render 로 갱신되는 `.ai/forge.md`

### 완료 조건

- [ ] 읽기 단계가 fail 0 이다
- [ ] `--create-issue` 를 사람의 확인을 받은 뒤에만 돌렸고, fail 0 · skip 0 이다
- [ ] `github.py` 머리글에 `검증 상태: 미검증` 이 없고 통과 단계와 gh 버전이 있다
- [ ] github 설정의 doctor 가 `adapter github` 를 `ok` 로 낸다
- [ ] `.ai/forge.md` 에 GitHub "어댑터 미검증" 안내가 없다
- [ ] `README.md` 지원 범위 표의 GitHub 행이 그 결과를 적는다
- [ ] 구현 리뷰 요청 본문에 두 판정 줄 · gh 버전 · 만들어진 이슈 번호가 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/209-port-forge-adapters` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 읽기 단계 | `script/forge-selftest.sh <리뷰요청> <이슈>` (실제 GitHub) | `fail 0`, 종료 코드 0 |
| UT-02 | 전 단계 | 사람 확인 뒤 `script/forge-selftest.sh --create-issue <리뷰요청> <이슈>` | `fail 0 · skip 0`, `all 18 contract functions checked` 와 `src/harness/forge/github.py` |
| UT-03 | 검증 표지 | github 설정의 `harness doctor --json` | `adapter \`github\`` 가 `ok` |
| UT-04 | 명령 사전 | 렌더된 `.ai/forge.md` | "어댑터 미검증" 이 없다 |
