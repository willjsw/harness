# #210 task

## T1 · chore: 명령 가드 회귀 테스트를 훅 명령 호출과 훅 입력 모양으로 바꾸고 판정 고정 케이스 추가

### 상위 Requirement

- relates to #210

### 작업 내용

가드를 고치지 않고, `test-bash-guard.sh` 를 옛 구현과 새 구현이 같은 배치로 도는 회귀 테스트로 바꾼다. 바꾼 테스트는 지금 가드
(#220 머지 뒤 셸 가드)에서 통과하고, T11 이 진입점을 바꾼 뒤에는 케이스와 기대값을 고치지 않고 새 구현에서 통과한다.

- 명세 9-1 · 9-2 의 "입력 만들기" · "부르는 곳" · "임시 루트" · "더하는 케이스" 행과 5-3
- 입력 만들기: `probe` 가 `json.dumps({"tool_name": "Bash", "tool_input": {"command": <명령>}}, ensure_ascii=False)` 로 입력을 만든다.
  따옴표 · 백슬래시 · 제어 문자만 이스케이프되고 줄바꿈 · CR · 탭은 지금 `probe` 와 같은 `\n` · `\r` · `\t` 다. python3 가 없으면
  실행 실패(2)로 끝난다
- 부르는 곳: 테스트를 부른 루트의 `.claude/settings.json` 에서 `hooks.PreToolUse[0].hooks[0].command` 를 읽고, 판정할 루트를
  `CLAUDE_PROJECT_DIR` 로 두어 `sh -c` 로 부른다. 훅 스크립트를 경로로 부르던 케이스 함수(`case_is` · `at_is` · `punct_is`, 작업
  브랜치 commit 판정 등)를 모두 이 방식으로 바꾼다
- 임시 루트: 하네스가 지키는 임시 리포 — 작업 트리 절 · 다른 리포 절 · 공백 경로 · 구획 문자 보호 목록 — 는 `script/harness.env`
  (또는 값을 바꾼 사본), 루트 `script/hooks/` 의 사본, 테스트를 부른 루트의 CLI(`.harness/bin/harness`, 없으면 `src/bin/harness`)를
  가리키는 심볼릭 링크 `.harness/bin/harness` 를 갖는다. 구획 문자 보호 목록의 평평한 사본(`$punct/`)도 이 배치로 바꾼다
- 더하는 케이스: 명세 5-3 의 세 표 가운데 지금 `test-bash-guard.sh` 에 없는 행 전부. 기대값은 5-3 의 판정이다. `git commit` 을
  실행하고 0 을 기대하는 행과 `git push origin<U+00A0><보호 브랜치>` 는 작업 브랜치 임시 리포에서 돈다
- 차단 문구 대조: 명세 9-2 의 계열 목록 항목마다 한 케이스씩 — 보호 브랜치 push · `--all` · 보호 브랜치 commit, force push ·
  `+refspec` · 원격 브랜치 삭제, `--no-verify` · `commit -n`, 원격 삭제, 보호 문서 셸 편집, write-doc, 설정 없음 — 표준 오류 전체를
  지금 가드의 출력과 대조한다. 기대 문구의 브랜치 · 문서 · forge CLI · 루트 경로는 설정과 임시 루트에서 받는다
- 그대로 두는 것: 기존 케이스 표와 기대값. `_guards.sh` 를 읽어 비교 함수를 바꿔 끼우는 비교 값 검사와 가드 하나를 망가뜨린 사본
  검사 둘은 이 task 에서 고치지 않는다 — T11 이 지우고 단위 테스트가 받는다
- `src/bin/harness render` 로 이 리포의 `script/test-bash-guard.sh` 사본과 `.harness/managed` 를 갱신한다
- 건드릴 파일: `src/templates/managed/script/test-bash-guard.sh`, render 로 갱신되는 `script/test-bash-guard.sh` · `.harness/managed`

### 완료 조건

- [ ] `probe` 가 명세 9-2 의 `json.dumps(…, ensure_ascii=False)` 로 입력을 만든다
- [ ] 판정 케이스가 모두 루트 `.claude/settings.json` 의 훅 명령을 `CLAUDE_PROJECT_DIR` 와 `sh -c` 로 부른다. 훅 스크립트를 경로로
  직접 부르는 곳은 비교 값 검사와 망가뜨린 사본 검사 둘뿐이다
- [ ] 하네스가 지키는 임시 리포마다 `script/harness.env` · `script/hooks/` 사본 · `.harness/bin/harness` 링크가 있다
- [ ] 더한 5-3 케이스가 지금 가드에서 5-3 의 판정이다
- [ ] 차단 문구 대조 12 케이스의 표준 오류가 지금 가드의 출력과 글자 하나까지 같다
- [ ] 기존 케이스의 기대값이 그대로이고 모두 통과한다
- [ ] `bash-guard.sh` · `_guards.sh` 가 바뀌지 않는다
- [ ] render 뒤 `script/test-bash-guard.sh` 와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | #220 이 바꾸지 않는 규칙 | 명세 5-3 첫 표의 행 가운데 없는 것 — `#` · 닫히지 않은 따옴표 · 명령 끝 백슬래시 · 유니코드 공백 | 5-3 의 판정 |
| UT-02 | 줄 판정 규칙 | 명세 5-3 둘째 표의 행 가운데 없는 것 | 5-3 의 판정 |
| UT-03 | 두 판정의 합 | 명세 5-3 셋째 표의 행 가운데 없는 것 | 2 |
| UT-04 | 차단 문구 | 계열 목록 12 항목의 대표 명령 | 표준 오류 전체가 지금 가드의 출력과 같다 |
| UT-05 | 설정 없음 | `script/harness.env` 가 없는 임시 루트에 `git status` | 2, 명세 4-6 의 두 줄(루트는 그 임시 루트) |
| UT-06 | 같은 배치 | `.harness/bin/harness` 링크를 둔 임시 루트의 기존 케이스 | 기대값 그대로 |

## T2 · chore: 시크릿 스캔 회귀 테스트와 git 훅 회귀 단언을 배치 중립으로 전환

### 상위 Requirement

- relates to #210

### 작업 내용

구현을 고치지 않고, `test-secret-scan.sh` 와 `render-test.sh` 의 git 훅 단언을 옛 구현과 새 구현이 같은 배치로 도는 형태로 바꾼다.
바꾼 테스트는 지금 구현에서 통과하고, T10 · T11 뒤에 고치지 않고 통과한다.

- 명세 9-1 · 9-3 과 9-5 의 UT-02 · UT-03 · UT-07b · UT-22 행
- `test-secret-scan.sh`: 임시 리포에 `script/secret-scan.sh` · `script/harness-format.sh` 사본과, 테스트를 부른 루트의 CLI
  (`.harness/bin/harness`, 없으면 `src/bin/harness`)를 가리키는 심볼릭 링크 `.harness/bin/harness` 를 둔다. UT-07 에 다른 명령의
  옵션 `--purge` 가 종료 코드 2 인 케이스를 더한다. 기존 기대값은 그대로다
- `render-test.sh` — 생성 훅 파일의 내용을 찾던 단언을 같은 기대값의 동작 단언으로 바꾼다
  - UT-02: `[BD-123] feat: x` 제목을 commit-msg 에 넣으면 0, `feat: x(#1)` 은 1 이고 표준 오류에 `[BD-123] feat: short summary` 가
    있고 `(#{issue})` 가 없다. `harness.env` 단언은 그대로
  - UT-03: pre-push 에 원격 ref `refs/heads/trunk` 줄을 넣으면 1 이고 `onto develop instead` 가 나온다. `refs/heads/main` 줄에는 보호
    브랜치 차단 문구(`is a protected branch`)가 나오지 않는다. 권한 목록 단언은 그대로
  - UT-07b: pre-push 가 `refs/heads/development` 줄을 막는다(1)
  - UT-22: pre-push 가 `refs/heads/develop` 줄을 막는다(1)
- 생성 훅을 실제로 돌리는 케이스의 대상에 CLI 를 둔다 — 위 넷과, 생성 훅을 돌리는 기존 케이스(UT-72 의 worktree commit-msg,
  UT-101 의 pre-push, `core.hooksPath` 를 켠 뒤 커밋하는 대상 등) 가운데 `.harness/bin/harness` · `src/bin/harness` 가 없는 대상.
  회귀 테스트가 부르는 CLI 를 가리키는 `.harness/bin/harness` 심볼릭 링크를 훅을 돌리기 전에 둔다(9-2 · 9-3 과 같은 배치).
  `harness run --worktree` 로 만든 worktree 는 만든 뒤 그 worktree 에 둔다. 링크가 가리키는 CLI 는 자기 자신이라 넘기지 않으므로
  그 대상의 render · set · check 결과가 같다. 기대값은 바꾸지 않는다
- `src/bin/harness render` 로 이 리포의 `script/test-secret-scan.sh` 사본과 `.harness/managed` 를 갱신한다
- 건드릴 파일: `src/templates/managed/script/test-secret-scan.sh`, `src/test/render-test.sh`, render 로 갱신되는
  `script/test-secret-scan.sh` · `.harness/managed`

### 완료 조건

- [ ] `test-secret-scan.sh` 의 임시 리포가 두 사본과 `.harness/bin/harness` 링크를 갖고, 기존 케이스와 `--purge` 케이스가 지금
  구현에서 통과한다
- [ ] UT-02 · UT-03 · UT-07b · UT-22 에 `script/githooks/` 파일 내용을 찾는 단언이 없고, 명세 9-5 의 동작 단언이 지금 구현에서 통과한다
- [ ] 생성 훅을 돌리는 케이스의 대상마다 `.harness/bin/harness` 또는 `src/bin/harness` 가 있다
- [ ] `secret-scan.sh` · `src/templates/generated/script/githooks/` · CLI 가 바뀌지 않는다
- [ ] render 뒤 `script/test-secret-scan.sh` · `src/test/render-test.sh` · `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 다른 명령의 옵션 | `script/secret-scan.sh --purge` | 2 |
| UT-02 | 같은 배치 | 사본 둘과 CLI 링크를 둔 임시 리포의 기존 케이스 | 기대값 그대로 |
| UT-03 | 접두 형식 제목 | 접두 형식 설정 대상의 commit-msg 에 `[BD-123] feat: x` / `feat: x(#1)` | 0 / 1, 표준 오류에 `[BD-123] feat: short summary` 가 있고 `(#{issue})` 가 없다 |
| UT-04 | 바꾼 보호 브랜치 | 보호 목록 `trunk` · `develop` 대상의 pre-push 에 `refs/heads/trunk` 줄 / `refs/heads/main` 줄 | 1 과 `onto develop instead` / 보호 브랜치 차단 문구 없음 |
| UT-05 | 목록에 없는 통합 브랜치 | 보호 목록이 `main` 뿐인 대상의 pre-push 에 `refs/heads/development` 줄 | 1 |
| UT-06 | `set` 으로 바꾼 통합 브랜치 | `branches.base develop` 뒤 pre-push 에 `refs/heads/develop` 줄 | 1 |

## T3 · refactor: 표지 읽기 format.py 의 markers 와 허용 표지 단언 추가

### 상위 Requirement

- relates to #210

### 작업 내용

시크릿 스캔(T9)이 허용 표지 `FMT_SECRET_ALLOW` 를 읽는 `src/harness/format.py` 의 `markers(root)` 를 준비한다. 이 모듈은 #209 와
이 이슈 가운데 먼저 머지되는 쪽이 만든다.

- 명세 6절의 `markers()` 정의(#209 2-1 과 같다)와 9-4 의 `format.py` 행
- 통합 브랜치에 `src/harness/format.py` 가 없으면 만든다
  - `markers(root)` 는 `<root>/script/harness-format.sh` 를 실행하지 않고 텍스트로 읽어 `FMT_*` 의 이름과 값을 사전으로 돌려준다
  - `#` 로 시작하는 줄과 빈 줄은 건너뛴다. 나머지 줄은 모두 `FMT_<대문자 · 숫자 · _>='<값>'` 한 줄 대입이다. 값은 두 홑따옴표
    사이의 글자 그대로이고 `'` 를 담지 않는다
  - 파일이 없거나 일반 파일이 아니거나 읽지 못하거나, 형식이 아닌 줄이 있으면 그 경로를 적은 `FormatError` 를 낸다
  - 표준 라이브러리만 쓰는 공용 모듈이다. `envfile` 과 서로 부르지 않는다
  - `src/test/unit/test_format.py` 를 #209 8-5 가 정한 내용으로 함께 둔다
- 통합 브랜치에 이미 있으면 `format.py` 를 고치지 않는다. 정의가 위 목록과 같은지 대조만 한다. 다르면 고치지 않고 그 차이를 사람에게
  보고한다
- 어느 경우든 `test_format.py` 에 이 명세가 더하는 단언 하나를 더한다 — `markers()` 가
  `src/templates/managed/script/harness-format.sh` 에서 읽은 `FMT_SECRET_ALLOW` 가 `harness:allow-secret` 이다
- 건드릴 파일: `src/harness/format.py`(없을 때만 신규), `src/test/unit/test_format.py`

### 완료 조건

- [ ] `src/harness/format.py` 의 `markers()` 가 명세 6절의 정의와 같다 — 새로 만들었으면 그 정의로, 이미 있었으면 바뀌지 않은 채로
- [ ] `test_format.py` 가 #209 8-5 의 내용과 `FMT_SECRET_ALLOW` 단언을 갖고 통과한다
- [ ] CLI 패키지에서 `script/harness-format.sh` 를 읽는 곳이 `markers()` 하나다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 셸로 source 한 값과 같다 | `src/templates/managed/script/harness-format.sh` | `FMT_*` 전부가 그 파일을 `sh` 로 source 한 값과 같다 |
| UT-02 | 읽지 못하는 파일 | 형식이 아닌 줄이 든 견본 · 없는 파일 · 디렉터리 | `FormatError`, 메시지에 경로가 있다 |
| UT-03 | 실행하지 않는다 | 홑따옴표 밖의 명령 치환 `FMT_X=$(…)` 줄을 담은 견본 | 명령이 실행되지 않고 `FormatError` |
| UT-04 | 허용 표지 | `src/templates/managed/script/harness-format.sh` | `FMT_SECRET_ALLOW` 가 `harness:allow-secret` |

## T4 · refactor: harness.env 읽기 모듈 envfile 추가

### 상위 Requirement

- relates to #210

### 작업 내용

명령 가드와 git 훅이 판정 값을 읽는 `src/harness/envfile.py` 를 만든다. `harness.toml` 을 읽지 않고, render 가 쓰는
`script/harness.env` 의 형식만 받는다.

- 명세 4-6 과 9-4 의 `envfile` 행
- 받는 형식 셋
  - 맨값 — `KEY=값`
  - 홑따옴표 값 — 여러 줄일 수 있고, 안의 `'` 는 `'\''` 로 적혀 있다
  - 겹따옴표 값 — `\\` · `\"` · `` \` `` 를 풀고 `$NAME` · `${NAME}` 을 환경의 값으로 펼친다(없으면 빈 값)
- `#` 로 시작하는 줄과 빈 줄은 건너뛴다
- 파일이 없거나, 일반 파일이 아니거나, 읽지 못하거나, 형식이 아닌 줄이 있으면 읽지 못한 것이다. 부르는 쪽이 차단 · 거부할 수 있게
  구별되는 예외로 알린다
- 표준 라이브러리만 쓰는 공용 모듈이다. `format.py` 와 서로 부르지 않는다. 가드 경로가 불러오므로 명세 2-3 의 import 제한을 지킨다
- 건드릴 파일: `src/harness/envfile.py`(신규), `src/test/unit/test_envfile.py`(신규)

### 완료 조건

- [ ] 세 형식, 여러 줄 홑따옴표, `'\''`, 겹따옴표의 `$HOME` · `${HOME}`, 주석 · 빈 줄을 읽는다
- [ ] 형식이 아닌 줄 · 디렉터리 · 없는 파일을 읽지 못한 것으로 알린다
- [ ] render 가 쓴 이 리포의 `script/harness.env` 를 읽은 값이 그 파일을 `sh` 로 source 한 값과 같다
- [ ] `envfile` 이 `harness.toml` 해석 · render · 지표 모듈과 `urllib` · `http` 를 불러오지 않는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 맨값 | `KEY=a/b:c` | `a/b:c` |
| UT-02 | 홑따옴표 | 여러 줄 값, `'\''` 가 든 값 | 줄바꿈이 남은 값, `'` 가 든 값 |
| UT-03 | 겹따옴표 | `"$HOME/x"` · `"${HOME}/x"` · 없는 변수 · `\\` `\"` `` \` `` | 환경의 값으로 펼친 값, 빈 값, 풀린 글자 |
| UT-04 | 주석 · 빈 줄 | `#` 줄과 빈 줄이 섞인 파일 | 건너뛴다 |
| UT-05 | 읽지 못함 | 형식이 아닌 줄 · 디렉터리 · 없는 파일 | 읽지 못했다는 예외 |
| UT-06 | 생성물과 같다 | 이 리포의 `script/harness.env` | 모든 키의 값이 `sh` 로 source 한 값과 같다 |

## T5 · refactor: 명령 가드의 입력 해석·기존 판정 명령·낱말 분해·가드 6종을 CLI 패키지로 이식

### 상위 Requirement

- relates to #210

### 작업 내용

명령 가드의 기존 판정 — 줄바꿈 · `<<` 가 없는 명령의 판정 전부 — 을 `src/harness/guard/` 로 옮긴다. 하위 명령과 진입점은 바꾸지
않는다.

- 명세 4-2(입력 해석) · 4-3 의 원문 표기와 기존 판정 명령 · 4-4(낱말 분해와 명령 자리) · 4-5(가드 6종) · 5-2 · 5-3 첫 표
- 입력 해석: 표준 입력 바이트를 UTF-8 · JSON 으로 엄격하게 풀고, 최상위가 객체이고 `tool_input` 이 객체이고 그 `command` 가
  문자열일 때만 명령을 꺼낸다. 그 밖은 꺼내지 못한 것이다
- 원문 표기: 꺼낸 명령을 명세 4-3 목록의 직렬화로 다시 적는다
- 기존 판정 명령: 원문 표기에 `\"` → `"`, `\n` → 공백, `\t` → 공백, `\\` → `\` 를 이 순서로 값 전체에 적용하고, 처음 나오는 `<<`
  부터 끝까지 잘라낸다
- 낱말 분해: 명세 4-4 표의 규칙 그대로 — 따옴표 구간 · 빈 따옴표 · 닫히지 않은 따옴표 · 따옴표 밖 백슬래시 · `#` · 구획 · 낱말 경계
  · 명령 자리 · git 전역 옵션 · 작업 디렉터리 · 다른 리포. git 을 부르지 못하거나 0 이 아니면 그 출력이 빈 것으로 본다. 보호 목록과
  비교하는 값은 셸이 넘기는 값이다
- 가드 6종: 명세 4-5 의 순서 · 판정 · 라벨 · 차단 문구. 판정 값은 `envfile` 로 읽은 사전에서 받고, 값이 비었을 때의 대체어와 보호
  문서 목록이 비면 5 · 6 을 돌지 않는 것도 지금 그대로다. 보호 문서 셸 편집은 판정 대상 전체를 정규식으로 보고 `[[:space:]]` 를
  유니코드 공백 전부로 옮긴다
- 판정 결과는 처음 걸린 가드의 라벨과 표준 오류 문구다. 사용 기록 · 출력 · 종료 코드는 T8 이 맡는다
- 문자열 처리는 어떤 명령 문자열에도 예외를 내지 않는다
- 단위 테스트의 판정 값 견본(`harness.env` 형식)을 단위 테스트 자리 아래에 둔다
- 건드릴 파일: `src/harness/guard/`(신규), `src/test/unit/test_guard.py`(신규), 판정 값 견본(신규)

### 완료 조건

- [ ] 입력 해석이 `tool_input.command` 문자열만 꺼내고, 명세 5-2 의 행마다 "이식 뒤" 열의 판정이 나온다
- [ ] `test-bash-guard.sh` 의 차단 · 통과 케이스 가운데 줄바꿈 · `<<` 가 없는 것의 판정이 셸 테스트와 같다
- [ ] 계열마다 차단 사유 문구가 T1 이 대조하는 지금 가드의 출력과 같다
- [ ] 판정에 `shlex` 를 쓰지 않는다
- [ ] 가드 패키지가 `harness.toml` 해석 · render · 지표 모듈과 `urllib` · `http` 를 불러오지 않고, `cli` · `commands` 를 불러오지 않는다
- [ ] 고정 시드의 임의 명령 문자열에서 기존 판정이 예외를 내지 않는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 차단 · 통과 표 | `test-bash-guard.sh` 계열의 케이스 가운데 줄바꿈 · `<<` 가 없는 것 | 셸 테스트와 같은 판정 |
| UT-02 | #220 이 바꾸지 않는 규칙 | 명세 5-3 첫 표의 7행 | 5-3 의 판정 |
| UT-03 | 입력 해석 | 명세 5-2 의 행 / 명령 없음 · 문자열 아님 · 빈 입력 | "이식 뒤" 열의 판정 / 꺼내지 못함 |
| UT-04 | 원문 표기 | 따옴표 · 백슬래시 · 줄바꿈 · 탭 · CR · BS · FF · 그 밖의 제어 문자 / 짝 없는 서로게이트 | 명세 9-2 의 `json.dumps(…, ensure_ascii=False)` 의 문자열 표기와 같다 / `\uXXXX` |
| UT-05 | 기존 판정 명령 | 글자로 적힌 백슬래시+`n` · 줄 끝 백슬래시 / `\r` · `\b` · `\f` · `\uXXXX` / 따옴표 안 · `<<<` 의 `<<` | 백슬래시와 공백 / 적힌 그대로 / 처음 `<<` 부터 잘림 |
| UT-06 | 비교 값 | 셸 테스트에서 옮겨 오는 인용 섞인 명령 일곱(구획 문자가 든 인용 목적지, 인용 목적지 둘, 빈 따옴표가 붙은 refspec, 공백 · 물결표가 든 인용 목적지, 인용된 `-C` 경로, 인용된 `cd` 경로, 빈 따옴표 목적지) | 보호 목록과 비교된 값이 셸이 넘기는 값이고 제어 문자가 없다 |
| UT-07 | 작업 디렉터리 · 다른 리포 | git 을 부르는 함수를 바꿔 끼운 `cd` · `-C` · 공통 디렉터리가 다른 리포 · git 실패 | 그 트리의 브랜치로 판정 / 보호 브랜치 가드를 적용하지 않음 / 빈 출력으로 봄 |
| UT-08 | 차단 문구 | 계열 목록 12 항목 가운데 설정 없음을 뺀 대표 명령 | 사유 문구가 지금 가드의 출력과 같다 |
| UT-09 | 유니코드 공백 | `sed` 와 `-i` 사이에 U+3000 이 든 보호 문서 쓰기 | 차단(`arch-doc`) |
| UT-10 | 무예외 | 고정 시드의 임의 명령 문자열 | 예외 없이 차단 또는 통과 |

## T6 · refactor: 명령 가드 줄 판정의 디코드와 판정 문자열을 CLI 패키지로 이식

### 상위 Requirement

- relates to #210

### 작업 내용

줄바꿈이 든 명령을 줄 판정으로 한 번 더 판정한다. 디코드와 판정 문자열 만들기를 옮기고, 판정 문자열은 따옴표 구간과 닫힌 산술
구간 밖에서 처음 만나는 `<<` 앞까지 만든다 — T7 이 그 처리를 히어독 규칙으로 바꾼다.

- 명세 4-1 의 4 · 5(두 판정의 순서와 합), 4-3 의 줄 판정 디코드와 줄 판정 문자열 가운데 #220 4-2 표에서 `<<<` · `<<` 두 행을 뺀
  나머지, #220 4-4 의 둘째 · 셋째 행(조건에 맞는 명령 치환이 든 큰따옴표 구간, 같은 줄 안에서 닫히지 않는 산술 구간)
- 줄 판정 디코드: 원문 표기의 이스케이프를 한 번에 푼다 — `\"` · `\\` · `\n` · `\t` · `\r` 만 풀고 그 밖은 적힌 그대로다
- 판정 문자열: 따옴표 구간은 줄을 넘을 수 있고 안의 줄바꿈은 공백이 된다. 닫히는지는 명령 끝까지 보고 정한다. 닫히지 않은 따옴표,
  따옴표 밖의 백슬래시+줄바꿈(지운다), 따옴표 밖의 줄바꿈(`;`), 산술 구간의 괄호 세기, 명령 치환 구간은 #220 4-2 표대로다. 결과에
  줄바꿈이 없다
- 두 판정: 기존 판정(T5)이 먼저 가드 6종을 돌고, 디코드에 줄바꿈이 있을 때만 줄 판정이 판정 문자열을 같은 가드 함수로 같은 순서로
  판정한다. 둘 중 하나가 막으면 막고, 사유는 먼저 막은 쪽의 것이다
- 이 task 의 단위 테스트는 `<<` 가 없는 입력만 쓴다
- 건드릴 파일: `src/harness/guard/`, `src/test/unit/test_guard_lines.py`(신규)

### 완료 조건

- [ ] 줄 판정 디코드와 판정 문자열이 #220 4-1 · 4-2 표(`<<<` · `<<` 행 제외)의 행마다 같은 결과를 내고, 판정 문자열에 줄바꿈이 없다
- [ ] 줄바꿈이 없는 명령은 판정 문자열을 만들지 않는다
- [ ] 명세 5-3 둘째 · 셋째 표와 #220 6-2 의 행 가운데 `<<` 가 없는 것이 표의 판정이다
- [ ] 두 판정이 모두 막는 명령의 사유가 기존 판정의 것이다
- [ ] T5 의 단위 테스트가 고치지 않고 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 줄 판정 디코드 | #220 4-1 표의 행 | `\"` · `\\` · `\n` · `\t` · `\r` 이 한 번만 풀리고 그 밖은 적힌 그대로. 글자로 적힌 백슬래시+`n` 은 두 글자 |
| UT-02 | 판정 문자열 | `'…'` · `"…"` · `$'…'` · 닫히지 않은 따옴표 · 따옴표 밖 백슬래시+줄바꿈 · 백슬래시+다른 글자 · 따옴표 밖 줄바꿈 · 산술 구간인 `$((` · `((` 와 아닌 것 · `$(` · 백틱 | #220 4-2 표의 결과, 줄바꿈 없음 |
| UT-03 | 다루지 못하는 구조 | #220 4-4 의 둘째 · 셋째 행 | 판정 문자열은 그 자리 앞까지, 기존 판정은 명령 전체를 판정 |
| UT-04 | 줄 판정 조건 | 줄바꿈이 없는 명령 | 판정 문자열을 만들지 않는다 |
| UT-05 | 줄 판정 차단 | 명세 5-3 둘째 표와 #220 6-2 의 행 가운데 `<<` 가 없는 것 | 표의 판정 |
| UT-06 | 두 판정의 합 | `git push origin feat\n<보호 브랜치>` · `echo "<CR>; git push --force origin x"` · `git push origin<LF><보호 브랜치>` | 2, 사유는 기존 판정의 것 |

## T7 · refactor: 명령 가드 줄 판정의 히어독 처리를 CLI 패키지로 이식

### 상위 Requirement

- relates to #210

### 작업 내용

줄 판정이 히어독을 다룬다. 히어독 본문과 종결 줄만 판정 문자열에서 빼고, 연산자 줄의 나머지와 종결 줄 다음 줄은 판정한다.
히어스트링 · 따옴표 안 · 산술 구간 안의 `<<` 는 히어독이 아니므로 그 뒤도 판정하고, `<<` 가 든 한 줄 명령도 줄 판정을 받는다.

- 명세 4-1 의 5(줄 판정 조건: 디코드에 줄바꿈이나 `<<`), 4-3 의 줄 판정 문자열 가운데 #220 4-2 의 `<<<` · `<<` 두 행 · #220 4-3 ·
  #220 4-4 의 첫째 · 넷째 · 다섯째 행, 5-3 의 `<<` 가 든 행
- T6 의 "`<<` 앞까지만 만든다" 를 아래로 바꾼다
  - `<<<` 는 그대로 둔다
  - `<<` · `<<-` 는 히어독 연산자다. 연산자와 구분어, 연산자 줄의 나머지는 남고 본문과 종결 줄은 빠진다. 판정은 종결 줄 다음 줄부터
    다시 한다. `<<-` 의 탭 떼기, 한 줄의 연산자 여럿, 종결 줄이 없는 본문, 구분어의 따옴표 · 백슬래시 떼기는 #220 4-3 그대로다
  - 명령 치환 안의 `<<`, 구분어가 빈 연산자, 본문이 남은 히어독이 있는데 명령 치환 안에서 만난 줄바꿈을 만나면 그 자리 앞까지만
    만든다
  - 판정 문자열은 `<<` 에서 자르지 않는다
- 가드 하나를 끈 판정을 단위 테스트에서 만들 수 있게, 가드 6종의 순서 목록을 두 판정이 함께 쓴다
- 건드릴 파일: `src/harness/guard/`, `src/test/unit/test_guard_lines.py`

### 완료 조건

- [ ] 판정 문자열이 #220 4-2 · 4-3 · 4-4 표의 행마다 같은 결과를 낸다
- [ ] `test-bash-guard.sh` 의 차단 · 통과 케이스 전부(#220 6-2 · 6-4 가 더한 행 포함)의 판정이 셸 테스트와 같다
- [ ] force push 가드만 끈 판정에서 force 계열만 통과로 뒤집히고, write-doc 가드만 끈 판정에서 write-doc 계열만 뒤집힌다 — 두 판정에서
  함께 꺼진다
- [ ] 고정 시드의 임의 명령 문자열에서 두 판정이 예외를 내지 않는다
- [ ] T5 · T6 의 단위 테스트가 고치지 않고 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 히어독 | 구분어가 끝나는 글자와 따옴표 · 백슬래시 떼기, `<<-` 의 탭 떼기, 한 줄의 연산자 여럿, 종결 줄이 없는 본문, CR 로 끝나는 줄 | 본문과 종결 줄이 빠진 판정 문자열 |
| UT-02 | 본문이 빠진 문자열의 보호 문서 판정 | `cat <<EOF > <보호 문서><LF>x<LF>EOF` / 본문에만 보호 문서 쓰기가 적힌 히어독 | 차단 / 통과 |
| UT-03 | 다루지 못하는 구조 | #220 4-4 의 첫째 · 넷째 · 다섯째 행 | 판정 문자열은 그 자리 앞까지, 기존 판정은 명령 전체를 판정 |
| UT-04 | 히어독 행 | 명세 5-3 둘째 표와 #220 6-2 의 행 가운데 `<<` 가 든 것 | 표의 판정 |
| UT-05 | 두 판정의 합 | 명세 5-3 셋째 표의 `<<` 가 든 5행 | 2 |
| UT-06 | 가드 하나를 끈 사본 | force push 가드만 끈 판정 · write-doc 가드만 끈 판정에 차단 표 전체 | 끈 가드의 계열(#220 6-2 가 더한 행 포함)만 통과, 나머지 계열은 차단 |
| UT-07 | 무예외 | 고정 시드로 만든 임의 명령 문자열 — 따옴표 · 백슬래시 · `\|;&` · `<<` · `#` · `$(` · 백틱 · 공백 · 유니코드 공백 · 제어 문자 · 줄바꿈을 섞은 것 | 예외 없이 차단 또는 통과 |
| UT-08 | 차단 · 통과 표 전체 | `test-bash-guard.sh` 의 차단 · 통과 케이스 전부 | 셸 테스트와 같은 판정 |

## T8 · refactor: 명령 가드 하위 명령 bash-guard 추가

### 상위 Requirement

- relates to #210

### 작업 내용

Claude Code `PreToolUse(Bash)` 훅 본문을 CLI 하위 명령 `bash-guard` 로 둔다. 진입점은 아직 셸 가드를 부른다 — T11 이 바꾼다.

- 명세 1절의 사용 기록 · 2-1 · 2-2 · 2-3 · 4-1 · 4-6
- 등록: `src/harness/commands/__init__.py` 의 `COMMANDS` 에 `"bash-guard": (True, False, "", <2-1 의 help 설명>)`,
  `src/harness/cli.py` 의 `DELEGATES` 에 `bash-guard`. 진입 함수는 `src/harness/commands/bash_guard.py` 의 `cmd_bash_guard`
- 순서(4-1): 표준 입력 전체를 읽어 명령을 꺼낸다(T5) — 꺼내지 못했거나 빈 문자열이면 0. 기존 판정 명령과 줄 판정 디코드를 만든다.
  `<루트>/script/harness.env` 를 `envfile` 로 읽는다 — 읽지 못하면 4-6 의 두 줄을 표준 오류로 내고 2. 두 판정(T6 · T7)이 처음 걸린
  가드에서 `<루트>/script/usage-log.sh` 가 실행 가능하면 `block bash-guard <라벨>` 로 부르고 출력과 실패를 버린 뒤, 사유를 표준
  오류로 내고 2. 아니면 0
- `<루트>` 는 `--target` 을 심볼릭 링크를 풀지 않고 절대 경로로 만든 것이다. 작업 디렉터리를 옮기지 않는다
- 인수 검사: 이름 바로 뒤의 `--target DIR` 를 뺀 나머지 인수가 있으면 판정하지 않고 `usage: harness bash-guard` 와 1
- 예기치 않은 예외: 표준 오류 한 줄 `error: the command guard stopped on an unexpected error and did not check this command —
  <예외 이름>: <메시지 첫 줄>` 과 1. 트레이스백을 내지 않는다
- import(2-3): 판정에 쓰는 패키지 모듈은 가드 패키지와 `envfile` 이다. 사용 기록 모듈을 불러오지 않고, 사용 기록 호출 말고 아무것도
  쓰지 않는다
- 건드릴 파일: `src/harness/commands/bash_guard.py`(신규), `src/harness/commands/__init__.py`, `src/harness/cli.py`,
  `src/test/unit/test_bash_guard.py`(신규)

### 완료 조건

- [ ] `harness help` 에 `bash-guard` 가 2-1 의 설명으로 나오고, `test_commands.py` 가 그 항목(첫 원소 `True`)과 명령 모듈을 확인한다
- [ ] 차단 입력에 2 와 지금 가드와 같은 표준 오류를 내고, 사용 기록 스크립트를 `block bash-guard <라벨>` 로 한 번 부른다
- [ ] `script/harness.env` 를 읽지 못하면 4-6 의 두 줄과 2 이고, 명령을 꺼내지 못하면 그 파일이 없어도 0 이다
- [ ] 인수가 있으면 1 과 `usage: harness bash-guard`, 예기치 않은 예외는 1 과 오류 한 줄이고 트레이스백이 없다
- [ ] `harness.toml` 이 깨진 TOML 인 루트에서도 판정과 문구가 같다
- [ ] 차단 입력과 통과 입력으로 한 번씩 `python3 -X importtime src/bin/harness --target <루트> bash-guard` 를 돌린 import 기록에
  `urllib` · `http` · `harness.render` · `harness.metrics` 가 없다
- [ ] `.claude/settings.json` 과 `script/hooks/` 가 바뀌지 않는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 차단 | 판정 값 견본을 둔 임시 루트에 보호 브랜치 push 입력 | 2, 지금 가드의 표준 오류, 사용 기록 호출에 `block bash-guard protected-branch` |
| UT-02 | 통과 | `git status` 입력 | 0, 출력 없음 |
| UT-03 | 입력 해석 | `harness.env` 가 없는 루트에 명령 없음 · 문자열 아님 · 빈 입력 | 0 |
| UT-04 | 설정 없음 | `harness.env` 가 없는 루트에 `git status` 입력 | 2 와 4-6 의 두 줄 |
| UT-05 | 설정 해석 없음 | `harness.toml` 이 깨진 TOML 인 루트 | UT-01 · UT-02 와 같은 판정과 문구 |
| UT-06 | 예외 정책 | 가드 하나가 예외를 내게 바꿔 끼움 | 1, `error: the command guard stopped` 로 시작하는 한 줄, 트레이스백 없음 |
| UT-07 | 인자 통과 | `--target R bash-guard` · `bash-guard --target R` | `parse_command_line()` 이 같은 루트와 빈 인자로 나눈다 |
| UT-08 | 인수 검사 | `bash-guard x` | 1, `usage: harness bash-guard` |
| UT-09 | 사용 기록 스크립트 없음 | 실행 가능하지 않은 `script/usage-log.sh` | 2, 기록 호출 없음 |
| UT-10 | 무예외 | T7 의 임의 명령 문자열을 훅 입력으로 | 0 또는 2 |

## T9 · refactor: 시크릿 스캔 하위 명령 secret-scan 추가

### 상위 Requirement

- relates to #210

### 작업 내용

시크릿 스캔 본문을 CLI 하위 명령 `secret-scan` 으로 둔다. `script/secret-scan.sh` 는 아직 셸 스캔이다 — T11 이 shim 으로 바꾼다.

- 명세 2-1 · 2-2 · 6 · 8-1 의 시크릿 스캔 행
- 탐지: `secret-scan.sh` 의 파이썬 본문을 `src/harness/guard/` 아래 시크릿 스캔 모듈로 옮긴다 — 발급처를 확정하는 형태 18종, 이름이
  자격증명을 가리키는 대입과 그 제외 검사(자리표시자 · 구조화된 이름 · `$` 로 시작 · 서로 다른 글자 6개 미만 · 엔트로피 3.0 미만),
  줄 번호 계산, 출력 형식 · 문구가 지금 그대로다. 값을 출력에 옮기지 않는다
- git: 하네스 루트에서 부른다. 기준은 HEAD 가 있으면 HEAD, 없으면 `git hash-object -t tree /dev/null`. 기본은
  `git diff -U0 --no-color --diff-filter=ACMR <기준>`, `--staged` 는 `--cached` 를 더한다. diff 의 풀리지 않는 바이트는 대체 문자로
  바꾼다. git 이 실패하면 git 의 표준 오류를 그대로 두고 2
- 허용 표지: `markers(<루트>)` 의 `FMT_SECRET_ALLOW`. `FormatError` 이거나 키가 없으면 git 을 부르기 전에
  `error: cannot read the secret allow marker from <루트>/script/harness-format.sh` 한 줄과 2
- 인수 검사: `--staged` 말고는 `error: unknown option: <인수>` 와 `usage: harness secret-scan [--staged]` 를 내고 2
- 예기치 않은 예외: `error: the secret scan stopped on an unexpected error — <예외 이름>: <메시지 첫 줄>` 한 줄과 2
- 등록: `COMMANDS` 에 `"secret-scan": (True, False, "[--staged]", <2-1 의 help 설명>)`, `DELEGATES` 에 `secret-scan`
- T10 의 pre-commit 이 같은 스캔을 프로세스 안에서 부를 수 있게, 스캔은 루트와 모드를 받아 종료 코드를 돌려주는 함수로 둔다
- 단위 테스트의 표본 값은 조각을 이어 붙여 만든다 — 이 리포의 스캔이 테스트 파일을 잡지 않게 한다
- 건드릴 파일: `src/harness/guard/` 의 시크릿 스캔 모듈(신규), `src/harness/commands/secret_scan.py`(신규),
  `src/harness/commands/__init__.py`, `src/harness/cli.py`, `src/test/unit/test_secret_scan.py`(신규)

### 완료 조건

- [ ] `harness help` 에 `secret-scan` 이 2-1 의 인수 · 설명으로 나오고, `test_commands.py` 가 그 항목과 명령 모듈을 확인한다
- [ ] 표지를 읽지 못하는 세 경우 각각 2 이고 표준 오류는 6절의 한 줄뿐이며 git 을 부르지 않는다
- [ ] 인수 검사와 예외 정책이 2-1 · 2-2 대로다
- [ ] 탐지 대표 케이스의 판정과 출력 형식이 지금 `secret-scan.sh` 와 같고 출력에 값이 없다
- [ ] 시크릿 스캔 코드에 표지 문자열 리터럴이 없다
- [ ] `script/secret-scan.sh` 가 바뀌지 않는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 표지 파일 없음 | `script/harness-format.sh` 가 없는 루트 | 2, 6절의 한 줄뿐, git 을 부르지 않는다 |
| UT-02 | 형식이 아닌 줄 | `FMT_X=$(…)` 줄이 든 견본 | 2, 6절의 한 줄뿐, 명령이 실행되지 않는다 |
| UT-03 | 허용 표지 줄 없음 | `FMT_SECRET_ALLOW` 줄만 뺀 견본 | 2, 6절의 한 줄뿐 |
| UT-04 | 인수 | `--stage` · `--purge` · `--staged --target R` · 남는 위치 인수 | 2, `error: unknown option: <인수>` 와 사용법 |
| UT-05 | 인자 통과 | `--target R secret-scan --staged` · `secret-scan --target R --staged` | `parse_command_line()` 이 같은 루트와 인자 `--staged` 로 나눈다 |
| UT-06 | 예외 정책 | 스캔 함수가 예외를 내게 바꿔 끼움 | 2, `error: the secret scan stopped` 로 시작하는 한 줄 |
| UT-07 | 탐지 대표 | git diff 를 바꿔 끼운 발급처 형태 한 줄 · 이름 대입 한 줄 · 자리표시자 · 허용 표지를 단 줄 | 1 · 1 · 0 · 0, 출력에 값이 없다 |
| UT-08 | git 실패 | git 을 부르는 함수가 실패를 돌려주게 바꿔 끼움 | 2 |

## T10 · refactor: git 훅 본문 하위 명령 git-hook 과 harness.env 의 VERIFY_PRE_PUSH 추가

### 상위 Requirement

- relates to #210

### 작업 내용

commit-msg · pre-commit · pre-push 의 본문을 CLI 하위 명령 `git-hook <훅>` 으로 두고, pre-push 의 검증 여부를 `script/harness.env`
로 받게 한다. 생성 git 훅은 아직 셸 본문이다 — T11 이 shim 으로 바꾼다.

- 명세 2-1 · 2-2 · 7 · 10-1 의 `derive()` 행 · 9-5 의 UT-101 행
- 등록: 본문은 `src/harness/hooks.py`, 진입 함수는 `src/harness/commands/git_hook.py` 의 `cmd_git_hook`. `COMMANDS` 에
  `"git-hook": (True, False, "<commit-msg|pre-commit|pre-push>", <2-1 의 help 설명>)`, `DELEGATES` 에 `git-hook`
- 인수 검사: 훅 이름 하나만 받는다. 없거나 모르는 이름이거나 남는 인수(훅 이름 뒤의 `--target` 포함)가 있으면
  `usage: harness git-hook <commit-msg|pre-commit|pre-push>` 와 2
- commit-msg(7-1): 표준 입력을 바이트로 읽어 첫 LF 앞까지가 제목이다. UTF-8 로 풀리지 않으면 거부. `Merge ` · `Revert ` · `fixup!` ·
  `squash!` 로 시작하면 0. `harness.env` 의 `COMMIT_SUBJECT_RE` 에 맞으면 0. 아니면 `block commit-msg format` 사용 기록(결과 무시)
  뒤 7-1 의 안내문과 1. `harness.env` 를 읽지 못하면 7-1 의 두 줄과 1
- pre-commit(7-2): `harness --target <루트> check --staged` 와 같은 검사 — 설정 오류를 포함해 0 이 아니면 1. 이어서 T9 의 스캔을
  `--staged` 로 — 0 이 아니면 `block pre-commit secret-scan` 사용 기록(출력 · 실패 버림) 뒤 1. 두 검사의 출력은 그대로 보인다.
  `harness.env` 를 읽지 않는다
- pre-push(7-3): 표준 입력의 ref 줄에서 로컬 sha 를 모으고, 원격 ref 가 `PROTECTED_BRANCHES` 의 이름에 `refs/heads/` 를 붙인 것과
  같으면 `block pre-push protected-branch` 사용 기록 뒤 7-3 의 두 줄과 1. `VERIFY_PRE_PUSH` 가 `1` 이면 push 전 검증을 지금 순서와
  문구 그대로 돈다 — `script/run-lint-test.sh` 실행 가능 여부, 보내는 리비전(지우는 ref 제외, 주석 태그는 가리키는 커밋)이
  HEAD 인가, 작업 트리가 깨끗한가, `script/run-lint-test.sh` 를 표준 입력을 비우고 돌려 통과하는가, 검증 뒤에도 깨끗한가. 하나라도
  아니면 `block pre-push verify` 사용 기록(출력 · 실패 버림) 뒤 사유 두 줄과 1. `harness.env` 를 읽지 못하면 7-3 의 두 줄과 1
- 예기치 않은 예외: `error: the <훅> hook stopped on an unexpected error — <예외 이름>: <메시지 첫 줄>` 한 줄과 1
- commit-msg · pre-push 의 git 명령은 프로세스의 작업 디렉터리에서 돈다. 작업 디렉터리를 옮기지 않는다
- `derive()`(`src/harness/render/derive.py`)에 `VERIFY_PRE_PUSH` — `verify.pre_push` 가 참이면 `1`, 아니면 `0`. `script/harness.env`
  로 간다
- `render-test.sh` UT-101: pre-push 파일에서 `run-lint-test.sh` 를 찾던 두 단언을 `harness.env` 의 `VERIFY_PRE_PUSH` 가 `1` · `0` 인지로
  바꾸고, `verify.pre_push` 를 끈 뒤 더러운 작업 트리에서 pre-push 가 0 인 단언을 더한다
- `src/bin/harness render` 로 이 리포의 `script/harness.env` 를 갱신한다
- 건드릴 파일: `src/harness/hooks.py`(신규), `src/harness/commands/git_hook.py`(신규), `src/harness/commands/__init__.py`,
  `src/harness/cli.py`, `src/harness/render/derive.py`, `src/test/render-test.sh`, `src/test/unit/test_git_hook.py`(신규), render 로
  갱신되는 `script/harness.env`

### 완료 조건

- [ ] `harness help` 에 `git-hook` 이 2-1 의 인수 · 설명으로 나오고, `test_commands.py` 가 그 항목과 명령 모듈을 확인한다
- [ ] 세 훅 본문의 판정 · 문구 · 사용 기록 라벨이 지금 생성 훅과 같다
- [ ] `script/harness.env` 에 `VERIFY_PRE_PUSH` 가 있고 `verify.pre_push` 를 따라 `1` · `0` 이다
- [ ] UT-101 의 바꾼 단언이 통과한다
- [ ] `src/templates/generated/script/githooks/` 와 `.claude/settings.json` 이 바뀌지 않는다
- [ ] `src/test/render-test.sh` 와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | commit-msg 제목 | `feat: x(#1)<LF>본문` / `feat: x(#1)<CR><LF>` | 첫 LF 앞만 보고 0 / CR 이 남은 제목은 맞지 않아 1 |
| UT-02 | git 이 만든 메시지 | `Merge ` · `Revert ` · `fixup!` · `squash!` 로 시작하는 제목 | 0 |
| UT-03 | UTF-8 아님 | 풀리지 않는 바이트가 든 제목 | 1 |
| UT-04 | 형식 불일치 | 견본 `COMMIT_SUBJECT_RE` 에 맞지 않는 제목 | 1, `block commit-msg format` 사용 기록, 7-1 의 안내문 |
| UT-05 | commit-msg 설정 없음 | `harness.env` 가 없는 루트 | 1, 7-1 의 두 줄 |
| UT-06 | pre-commit | 생성물 검사 실패 / 스캔 발견 / 둘 다 통과 (두 함수를 바꿔 끼움) | 1 / `block pre-commit secret-scan` 사용 기록 뒤 1 / 0 |
| UT-07 | pre-push ref 줄 | 여러 줄 입력 · `refs/heads/<보호 브랜치>-x` 줄 | 로컬 sha 를 모으고, 보호 브랜치와 정확히 같은 이름만 막는다 |
| UT-08 | pre-push 보호 브랜치 | `refs/heads/<보호 브랜치>` 줄 | 1, `block pre-push protected-branch` 사용 기록, 7-3 의 두 줄 |
| UT-09 | 검증 꺼짐 | `VERIFY_PRE_PUSH=0` | 검증 함수를 부르지 않고 0 |
| UT-10 | pre-push 설정 없음 | `harness.env` 가 없는 루트 | 1, 7-3 의 두 줄 |
| UT-11 | 인자 통과 · 인수 검사 | `--target R git-hook pre-push` · `git-hook --target R pre-push` / `git-hook pre-push --target R` · 이름 없음 · 모르는 이름 | 같은 루트와 인자 `pre-push` / 2 와 사용법 |
| UT-12 | 예외 정책 | 훅 본문이 예외를 내게 바꿔 끼움 | 1, `error: the <훅> hook stopped` 로 시작하는 한 줄 |
| UT-13 | `VERIFY_PRE_PUSH` (`render-test.sh` UT-101) | `verify.pre_push` 참 / 거짓 | `harness.env` 가 `1` / `0`, 끈 뒤 더러운 작업 트리에서 pre-push 0 |

## T11 · refactor: 훅 명령·git 훅·옛 경로를 하위 명령으로 넘기는 shim 으로 전환

### 상위 Requirement

- relates to #210

### 작업 내용

진입점 셋을 하위 명령으로 넘기는 shim 으로 한 커밋에서 바꾼다. 이 커밋부터 명령 가드 · git 훅 · 옛 경로가 새 구현으로 돈다.

- 명세 3-1 · 3-2 · 3-3 · 10-1 · 11, 9-2 의 "단위 테스트로 옮기는 검사" 행, 9-5 의 UT-72 행, 10-2 의 관리 스크립트 목록 · 변경 안내 ·
  `test-bash-guard.sh` 머리글 행
- 훅 명령: `settings_json()`(`src/harness/render/settings.py`)의 `PreToolUse` 훅 명령을 3-1 의 한 줄로 바꾼다. `matcher` 는 그대로다
- git 훅: `src/templates/generated/script/githooks/{commit-msg,pre-commit,pre-push}` 를 3-2 의 shim 으로 바꾼다
  - 템플릿 변수를 쓰지 않는다. 루트 잡기(자기 위치의 `../..`, 거기에 `script/harness.env` 가 없으면 `git rev-parse --show-toplevel`)는
    지금 코드 그대로다
  - `<루트>/.harness/bin/harness`, `<루트>/src/bin/harness` 순으로 실행 가능한 첫 CLI 에 `exec <CLI> --target <루트> git-hook <훅>`.
    commit-msg 는 `< "$1"`, pre-push 는 표준 입력을 물려주고 인수를 넘기지 않으며, pre-commit 은 인수가 없다
  - 루트나 CLI 를 찾지 못하면 3-2 의 표대로 끝난다. 사용 기록은 남기지 않는다
  - 머리글의 생성 표지 · 활성화 안내와 pre-commit 의 "하네스를 찾지 못하면 통과시킨다" 는 그대로 둔다. 본문이 옮겨 가 맞지 않게 된
    서술은 shim 이 하는 일로 고친다. post-commit 은 그대로다
- 생성 모듈에서 `PRE_PUSH_VERIFY` 블록과 그 치환을 걷는다 — T10 의 pre-push 본문이 받는다
- 옛 경로: `src/templates/managed/script/hooks/bash-guard.sh` · `src/templates/managed/script/secret-scan.sh` 를 3-3 의 shim 으로
  바꾼다. 현재 디렉터리 · 표준 입출력 · 환경을 바꾸지 않는다
- `src/templates/managed/script/hooks/_guards.sh` 를 지운다. 관리 파일 목록에서 빠지고, render 의 정리가 이 리포의
  `script/hooks/_guards.sh` 를 지운다
- `test-bash-guard.sh`: `_guards.sh` 를 읽어 비교 함수를 바꿔 끼우는 비교 값 검사와 가드 하나를 망가뜨린 사본 검사 둘을 지운다 —
  T5 의 비교 값 테스트와 T7 의 가드를 끈 사본 테스트가 받는다. 머리글의 망가뜨린 사본 서술을 지운다. 그 밖의 케이스와 기대값은
  고치지 않는다
- `render-test.sh` UT-72: 훅 명령 단언을 3-1 의 한 줄과 같은지로 바꾼다. `sh -c` 판정 단언은 그대로다
- 끊긴 참조를 남기지 않도록 `_guards.sh` 를 가리키는 문서 두 곳을 같은 커밋에서 고친다
  - `src/templates/managed/script/README.md` 목록 표 — `secret-scan.sh` · `hooks/bash-guard.sh` 행을 CLI 로 넘기는 shim 으로 고치고
    `hooks/_guards.sh` 행을 지운다
  - `src/templates/managed/docs/workflow/changing.md` — "가드 판정" 행을 하네스 리포의 `src/harness/guard/` + 테스트 케이스로
- render 하면 작업 세션의 다음 Bash 호출부터 새 가드가 돈다. 떠 있는 세션은 시작할 때 읽은 옛 경로의 훅 명령으로 shim 을 거친다
  (명세 3-3 · 11). render 전에 단위 테스트가 통과하는 것을 확인한다
- 건드릴 파일: `src/harness/render/settings.py`, 생성 모듈의 `PRE_PUSH_VERIFY` 자리(`src/harness/render/scripts.py` ·
  `src/harness/render/plan.py`), `src/templates/generated/script/githooks/{commit-msg,pre-commit,pre-push}`,
  `src/templates/managed/script/hooks/bash-guard.sh` · `hooks/_guards.sh`(삭제) · `secret-scan.sh` · `test-bash-guard.sh` · `README.md`,
  `src/templates/managed/docs/workflow/changing.md`, `src/test/render-test.sh`, render 로 갱신되는 `.claude/settings.json` ·
  `script/githooks/` · `script/hooks/` · `script/secret-scan.sh` · `script/test-bash-guard.sh` · `script/README.md` ·
  `docs/workflow/changing.md` · `.harness/managed` · `.harness/generated`

### 완료 조건

- [ ] 생성 모듈과 이 리포의 `.claude/settings.json` 훅 명령이 3-1 의 한 줄과 글자 하나까지 같다
- [ ] 세 git 훅이 템플릿 변수 없이 CLI 를 찾아 `git-hook <훅>` 으로 넘기고, CLI 가 없으면 3-2 의 표대로 끝난다
- [ ] 옛 경로의 shim 둘이 3-3 대로 넘기고, CLI 가 없으면 각각 1 · 2 와 3-2 의 두 줄이다
- [ ] `script/hooks/_guards.sh` 가 템플릿 · 이 리포 · `.harness/managed` 에 없다
- [ ] 생성 모듈에 `PRE_PUSH_VERIFY` 가 없다
- [ ] `script/test-bash-guard.sh` 의 남은 케이스와 `script/test-secret-scan.sh` 가 기대값 그대로 새 구현에서 통과한다
- [ ] `src/test/render-test.sh` 가 통과한다 — UT-61(설치된 `script/test-*.sh` 전부) · UT-34(pre-commit 의 시크릿 스캔) 포함
- [ ] 관리 스크립트 목록 · 변경 안내에 `_guards.sh` 가 없고, `harness doctor` 의 끊긴 참조에 `script/hooks/_guards.sh` 가 없다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 훅 명령 | 이 리포 `.claude/settings.json` 의 `hooks.PreToolUse[0].hooks[0].command` | 3-1 의 한 줄 |
| UT-02 | 셸 가드 오라클 | `script/test-bash-guard.sh` | 남은 케이스 전부 통과 |
| UT-03 | 시크릿 스캔 오라클 | `script/test-secret-scan.sh` | 통과 |
| UT-04 | git 훅 동작 | `render-test.sh` 의 UT-02 · UT-03 · UT-07b · UT-22 · UT-101 · UT-34 | 통과 |
| UT-05 | worktree 의 가드 | `render-test.sh` UT-72 | 훅 명령이 3-1 의 한 줄이고 worktree 에서 보호 브랜치 push 가 2 |
| UT-06 | 옛 가드 파일 정리 | render 뒤 이 리포 | `script/hooks/_guards.sh` 와 그 매니페스트 줄이 없다 |

## T12 · chore: 진입점 전환의 회귀 케이스 추가

### 상위 Requirement

- relates to #210

### 작업 내용

T11 이 만든 진입점 동작을 `render-test.sh` 의 새 `UT-<번호>` 블록으로 고정한다.

- 명세 9-5 의 "새 블록" 표 일곱 케이스
- 훅 명령: 설치한 리포와 소스 트리 복제본의 `.claude/settings.json` 훅 명령이 3-1 의 한 줄이다. 소스 트리 복제본에서 그 명령이 보호
  브랜치 push 를 막는다(2)
- CLI 없음: 설치한 리포에서 `.harness/bin/harness` 를 치우면 commit-msg 1, pre-push 1, pre-commit 0, 훅 명령과
  `script/hooks/bash-guard.sh` 1(2 가 아니다), `script/secret-scan.sh` 2. pre-commit 을 뺀 다섯 곳의 표준 오류가
  `error: harness CLI not found under <루트> (.harness/bin/harness or src/bin/harness)` 와 `help: harness install --target <루트>`
  두 줄이다
- 설정 없음: `script/harness.env` 를 치우면 commit-msg · pre-push 는 1 과 7-1 · 7-3 의 문구, 훅 명령은 2 와 4-6 의 문구
- 옛 경로의 shim: `script/hooks/bash-guard.sh` 가 보호 브랜치 push 를 막고(2), `script/secret-scan.sh --staged` 가 스테이징한 견본을
  잡는다(1). 견본 값은 조각을 이어 붙여 만든다
- 옛 가드 파일 정리: `.harness/managed` 에 `script/hooks/_guards.sh` 가 있는 설치본을 render 하면 그 파일이 지워진다. 새 설치에는 없다
- 모노레포: 서브프로젝트의 commit-msg 훅이 그 서브프로젝트의 CLI 로 형식을 검사한다
- 가드 경로의 import: 설치한 리포에서 `python3 -X importtime .harness/bin/harness --target <루트> bash-guard` 를 차단 입력과 통과
  입력으로 한 번씩 돌리면 표준 오류의 import 기록에 `urllib` · `http` · `harness.render` · `harness.metrics` 가 없다
- 건드릴 파일: `src/test/render-test.sh`

### 완료 조건

- [ ] 명세 9-5 "새 블록" 표의 일곱 케이스가 `render-test.sh` 에 있고 통과한다
- [ ] 새 블록이 실제 홈에 지표 · 사용 기록을 남기지 않는다 — 기존 블록의 기록 경로 격리를 따른다
- [ ] 기존 블록의 기대값이 그대로다
- [ ] `src/test/render-test.sh` 와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 훅 명령 | 설치한 리포 · 소스 트리 복제본의 `.claude/settings.json`, 복제본에서 보호 브랜치 push 입력 | 3-1 의 한 줄, 2 |
| UT-02 | CLI 없음 | `.harness/bin/harness` 를 치운 설치 리포의 여섯 진입점 | commit-msg 1 · pre-push 1 · pre-commit 0 · 훅 명령 1 · `bash-guard.sh` 1 · `secret-scan.sh` 2, 다섯 곳의 표준 오류가 shim 공통 두 줄 |
| UT-03 | 설정 없음 | `script/harness.env` 를 치운 설치 리포 | commit-msg · pre-push 1 과 그 문구, 훅 명령 2 와 4-6 의 문구 |
| UT-04 | 옛 경로의 shim | `script/hooks/bash-guard.sh` 에 보호 브랜치 push 입력 / 견본을 스테이징하고 `script/secret-scan.sh --staged` | 2 / 1 |
| UT-05 | 옛 가드 파일 정리 | `.harness/managed` 에 `script/hooks/_guards.sh` 가 있는 설치본을 render / 새 설치 | 그 파일이 지워진다 / 없다 |
| UT-06 | 모노레포 | 서브프로젝트의 commit-msg 에 형식이 맞지 않는 제목 | 1, 그 서브프로젝트의 CLI 가 검사한다 |
| UT-07 | 가드 경로의 import | 설치 리포에서 `python3 -X importtime` 으로 차단 · 통과 입력 | import 기록에 `urllib` · `http` · `harness.render` · `harness.metrics` 가 없다 |

## T13 · docs: README 명령 표·벤더 선언 주석·다른 명세에 하위 명령 반영

### 상위 Requirement

- relates to #210

### 작업 내용

하위 명령 셋과 바뀐 진입점을 사람용 문서와 다른 명세에 적는다. T11 이 고친 관리 스크립트 목록 · 변경 안내 · `test-bash-guard.sh`
머리글을 뺀 명세 10-2 의 나머지 행이다.

- 명세 10-2
- `README.md` 명령 표에 세 줄 — `harness bash-guard`(Claude Code 의 명령 가드 훅 본문. `.claude/settings.json` 이 부른다),
  `harness secret-scan [--staged]`(더한 줄의 자격증명 검사. 사람은 `script/secret-scan.sh` 로 부른다),
  `harness git-hook <훅>`(git 훅 본문. `script/githooks/` 가 부른다). "harness.toml 이 정하는 것" 의 `commit.tags` · `verify.pre_push`
  행은 그대로다
- `src/templates/vendors.toml` — `hooks` 주석의 `(bash-guard.sh)` 를 `(harness bash-guard)` 로
- `docs/spec/71-issue-worktree-run.md` 4절 — 명령 가드 줄: 훅 명령은 `$CLAUDE_PROJECT_DIR` 아래의 CLI(`.harness/bin/harness`, 없으면
  `src/bin/harness`)로 `--target "$CLAUDE_PROJECT_DIR" bash-guard` 를 부른다
- `docs/spec/62-unify-ui-writes-through-cli.md` — 정본 위치 표의 `write-doc` 명령 가드 행을 `src/harness/guard/` 로, 6-1 첫 문장을
  "가드 순서 목록에서 보호 문서 셸 편집 다음에 돈다" 로
- `docs/spec/70-generate-permission-allow-list.md` — `hooks.PreToolUse` 줄의 괄호를 `harness bash-guard` 로
- 다른 명세 셋은 #206 이 함수 자리를 고친 문장 위에서 이 행들만 고친다
- 건드릴 파일: `README.md`, `src/templates/vendors.toml`, `docs/spec/71-issue-worktree-run.md`,
  `docs/spec/62-unify-ui-writes-through-cli.md`, `docs/spec/70-generate-permission-allow-list.md`

### 완료 조건

- [ ] `README.md` 명령 표에 세 하위 명령이 명세 10-2 의 설명으로 있다
- [ ] `src/templates/vendors.toml` 의 `hooks` 주석이 `(harness bash-guard)` 다
- [ ] 명세 71 · 62 · 70 의 해당 줄이 명세 10-2 의 문안이고, `_guards.sh` 를 가드의 정본으로 적은 곳이 없다
- [ ] `docs/spec/58-…` 의 doctor 출력 예시는 그대로다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 명령 표 | `README.md` | `harness bash-guard` · `harness secret-scan [--staged]` · `harness git-hook <훅>` 세 줄이 있다 |
| UT-02 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-03 | 옛 정본 표기 | 명세 62 · 70 · 71 | 가드 정본으로 `_guards.sh` · `bash-guard.sh` 를 가리키는 문장이 없다 |

## T14 · docs: 아키텍처·테스트 문서에 가드·훅 하위 명령 반영

### 상위 Requirement

- relates to #210

### 작업 내용

T5 ~ T11 로 바뀐 사실을 에이전트가 근거로 읽는 보호 문서에 적는다.

**보호 문서를 수정하는 task 다.** `.ai/project/architecture.md` · `.ai/project/testing.md` 는 보호 문서이고, 이 개정은 2026-10-09 결정
게이트에서 사용자가 허용한 범위다 — 명세 12절의 표가 그 범위이고 그 밖은 고치지 않는다. 권한 설정 · 가드에 걸리면 사람이 대응한다.

- 명세 12-1 · 12-2
- `.ai/project/architecture.md`
  - "구성 요소" 의 `src/harness/` 항목(#206 이 더한 CLI 패키지 항목)에 덧붙인다: 명령 가드 · 시크릿 스캔 · git 훅 본문도 CLI 하위
    명령이다 — `bash-guard`(Claude Code `PreToolUse(Bash)` 훅) · `secret-scan` · `git-hook <commit-msg|pre-commit|pre-push>`. 코드는
    `src/harness/guard/` · `src/harness/hooks.py` 이고, `script/harness.env` 읽기는 `src/harness/envfile.py`, 표지
    (`script/harness-format.sh`) 읽기는 `src/harness/format.py` 다
  - "구성 요소" 의 대상 리포 `script/` 항목: "가드(`hooks/`)·시크릿 스캔" 을 "명령 가드 · 시크릿 스캔의 shim(`hooks/bash-guard.sh` ·
    `secret-scan.sh` — CLI 로 넘긴다)" 으로. 덧붙인다: `githooks/` 는 CLI 를 찾아 `git-hook` 으로 넘기는 생성 shim 이다
  - "데이터 흐름" 새 항목 "가드 · 훅": Claude Code `PreToolUse(Bash)` → `.claude/settings.json` 의 훅 명령 → 하네스 루트의 CLI
    (`.harness/bin/harness`, 없으면 `src/bin/harness`) `bash-guard` → `script/harness.env` 의 값으로 판정(0 통과 · 2 차단). git →
    `script/githooks/<훅>` → 같은 CLI 의 `git-hook <훅>`
  - "신뢰 경계" 의 들어오는 입력: "도구 호출 JSON(`script/hooks/bash-guard.sh`)" 을 "도구 호출 JSON(`harness bash-guard`)" 으로
  - "새 코드를 둘 곳" 의 새 가드: "새 가드 → `src/harness/guard/` 의 가드 함수와 가드 순서 목록 + `test-bash-guard.sh` 케이스 +
    `src/test/unit/` 의 단위 테스트. 판정에 쓰는 값은 `script/harness.env` 로 받는다"
  - "새 코드를 둘 곳" 새 항목: "git 훅 본문 → `src/harness/hooks.py`. `script/githooks/*` 는 CLI 를 찾아 넘기는 shim 으로만 둔다"
- `.ai/project/testing.md` — "무엇을 어느 수준으로 검증하나" 의 Python 단위 테스트 항목(#206 9절이 더한 것) 끝에 덧붙인다: 명령
  가드는 셸 테스트가 보지 못하는 것 — 가드 하나를 끈 사본에서 그 계열만 통과로 뒤집히는지, 보호 목록과 비교되는 값이 셸이 넘기는
  값인지, 임의 입력에서 예외가 나지 않는지 — 를 단위 테스트로 본다. 가드 경로가 설정 해석 · 생성 · 지표 모듈을 불러오지 않는지는
  `render-test.sh` 가 새 프로세스로 본다
- Python 단위 테스트 층의 기본 문장은 #206 이 쓴 것을 다시 쓰지 않는다. `glossary.md` · `scope.md` 는 고치지 않는다
- 같은 절을 고친 다른 이슈(#206 · #209 · #213 · #221)가 먼저 머지됐으면 그 문장 위에 이 범위의 사실만 더한다
- 보호 문서 경로를 명령 문자열에 적어 Bash 도구로 돌리지 않는다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 두 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/architecture.md`, `.ai/project/testing.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] `.ai/project/architecture.md` 가 명세 12-1 표의 여섯 위치 사실을 담는다
- [ ] `.ai/project/testing.md` 의 Python 단위 테스트 항목 끝에 명세 12-2 의 문장이 있다
- [ ] 두 문서에 `script/hooks/_guards.sh` · "`bash-guard.sh` 의 호출" 같은 옛 가드 배치 서술이 남지 않는다
- [ ] `glossary.md` · `scope.md` 가 바뀌지 않는다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 가 두 문서와 일치하고 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `refactor/210-port-guards-and-hooks` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 두 문서 수정 뒤 `src/bin/harness check` | 어긋난 생성 파일 없음 |
| UT-02 | 반영 확인 | `.ai/AI_AGENT.md` 5장 | 구성 요소 · 데이터 흐름 · 신뢰 경계 · 새 코드를 둘 곳에 `bash-guard` · `git-hook` · `src/harness/guard/` 가 있다 |
| UT-03 | 옛 배치 서술 | `.ai/project/architecture.md` · `.ai/AI_AGENT.md` | `_guards.sh` 문자열이 없다 |
