# #215 task

## T1 · feat: 요약 기록 표지와 기록 렌더 · 읽기 · 연속 회차 재구성 함수 추가

### 상위 Requirement

- relates to #215

### 작업 내용

반복 지적 이력을 리뷰 요청의 요약 댓글로 옮기는 데 필요한 순수 함수를 리뷰 모듈에 두고, 기록 표지를 표지 정본과 셸 표기에
더한다. **이 task 는 등록과 리뷰 입력의 동작을 바꾸지 않는다** — 함수와 단위 테스트만 더한다. 리뷰 입력이 직전 요약을 고르는
코드를 공용 판정으로 바꾸는 것은 고르는 결과가 같다.

- 명세 2-1(요약 노트) · 2-2(기록 줄) · 2-3(기록 읽기) · 2-4 의 1~3(연속 회차) · 2-5 의 알 수 없는 기록 · 2-6(인용에서 기록 줄 빼기) ·
  9-1 의 기록 렌더 · 기록 읽기 · 재구성
- 표지: `src/harness/format.py` 와 `src/templates/managed/script/harness-format.sh` 에 `FMT_REVIEW_RECORD` 를 값 `harness:review-record` 로 더한다.
  두 쪽 모두 등록 댓글 표지(`FMT_SUMMARY_HEADING` · `FMT_REVIEWED_HEAD`) 곁에 두고, 셸 표기에서는 "등록 댓글" 절이다. 주석은 리뷰 등록이
  요약 마지막 줄에 쓰고 다음 회차가 읽는다는 것
- `src/harness/review.py`
  - 요약 노트 판정 — 스레드 조회 결과의 노트 가운데 본문이 앞 공백을 걷은 뒤 `FMT_SUMMARY_HEADING` 으로 시작하는 것. 작성자 표시와
    등록 계정을 가리지 않는다. 리뷰 입력이 직전 요약을 고르는 코드도 이 판정 하나를 쓴다
  - 기록 렌더 — 판정 데이터에서 반복 키(심각도가 `FMT_INLINE_SEVERITIES` 인 발견의 `path`, `null` 이면 `FMT_NO_LOCATION`, 줄 번호 없음)를
    처음 나온 순서로 중복 없이 모아 `<!-- harness:review-record {"format":1,"keys":[…]} -->` 한 줄을 만든다. 키 순서는 `format` · `keys`,
    구분자에 공백이 없고, ASCII 밖의 문자와 `<` · `>` · `&` 는 `\uXXXX` 다. 요약 본문 끝에 빈 줄 하나와 기록 줄을 붙여 기록 줄이 마지막
    줄이 되게 한다
  - 기록 읽기 — 명세 2-3 의 여섯 조건을 모두 만족하면 키 집합, 하나라도 어기면 알 수 없는 기록. 본문은 `str.splitlines()` 로 나누고 줄마다
    끝 공백을 걷는다(CRLF 포함). 같은 키가 둘인 객체와 불리언 `format` 을 거부한다. `keys` 원소의 경로 규칙은 판정 데이터 `path` 검증
    (64 명세 2-2)과 같은 검사를 쓴다
  - 재구성 — 요약 노트를 `created_at` 오름차순(같으면 조회 결과 순서)으로 늘어놓아 노트마다 읽은 기록을 이전 회차 목록으로 만들고,
    이번 회차의 키마다 연속 회차 = 1 + 목록 끝에서부터 그 키를 가진 기록이 이어지는 수를 낸다. 그 키가 없는 기록 · 알 수 없는 기록에서
    멈춘다. 조회 실패는 이전 회차 목록을 알 수 없는 기록 하나로 받는다. 알 수 없는 기록의 수도 함께 돌려준다
  - 인용 거르기 — 요약 본문에서 `<!-- ` 와 표지로 시작하는 줄을 모두 뺀다
- `src/test/unit/test_review_record.py` 새 파일 — 아래 표
- `src/bin/harness render` 로 이 리포의 `script/harness-format.sh` 사본과 `.harness/managed` 갱신
- 건드릴 파일: `src/harness/format.py`, `src/harness/review.py`, `src/templates/managed/script/harness-format.sh`, `src/test/unit/test_review_record.py`(신규),
  render 로 갱신되는 `script/`

### 완료 조건

- [ ] `format.py` 와 `script/harness-format.sh` 에 `FMT_REVIEW_RECORD` 가 같은 값으로 등록 댓글 표지 곁에 있고, 셸 표기와 정본의 일치 단위 테스트가 통과한다
- [ ] 기록 렌더가 명세 2-2 의 직렬화대로 ASCII 한 줄을 내고, 요약 본문 끝에 빈 줄과 함께 붙어 마지막 줄이 된다
- [ ] 렌더한 요약을 읽으면 같은 키 집합이고, CRLF 본문도 읽힌다
- [ ] 명세 9-1 의 알 수 없는 기록 견본 15가지가 모두 알 수 없는 기록이다
- [ ] 재구성이 명세 9-1 의 재구성 케이스대로 연속 회차를 낸다
- [ ] 리뷰 입력이 고르는 직전 요약, 등록된 요약 본문, 리뷰 · 등록 명령의 출력과 종료 코드가 바뀌지 않는다 — `test-review-loop.sh` 와 기존 단위 테스트가 고치지 않고 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/215-multi-user-safety` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 키 순서와 중복 | blocker `a.sh` · major `b.sh` · major `a.sh` · minor `c.sh` 인 판정 데이터 | `keys` 가 `["a.sh","b.sh"]` |
| UT-02 | 빈 회차 | blocker · major 가 없는 판정 데이터 | `{"format":1,"keys":[]}` |
| UT-03 | 위치 없는 발견 | `path` 가 `null` 인 major | `keys` 가 `FMT_NO_LOCATION` 하나(이스케이프된 꼴) |
| UT-04 | 이스케이프 | 한국어 경로 · `a-->b.sh` · `<` 와 `&` 가 든 경로 | `\uXXXX` 로 쓰이고 `a-->b.sh` 는 `"a-->b.sh"`, 기록 줄이 ASCII 한 줄이고 `-->` 가 값 안에 없다 |
| UT-05 | 기록 줄 자리 | 요약 본문에 기록을 붙임 | 마지막 줄이 기록 줄이고 바로 앞 줄이 빈 줄 |
| UT-06 | 왕복 | 렌더한 요약을 읽음, 같은 본문을 CRLF 로 바꿔 읽음 | 둘 다 렌더한 키 집합 |
| UT-07 | 알 수 없는 기록 | 기록 줄 없음 · 둘 · 마지막 줄 아님 · ` -->` 없음 · JSON 아님 · 키가 더 있음 · 키가 모자람 · 같은 키 둘 · `format` 이 `2` · `format` 이 `true` · `keys` 가 문자열 · 원소가 숫자 · 원소에 제어 문자 · `/` 로 시작 · `..` 조각 | 15가지 모두 알 수 없는 기록 |
| UT-08 | 연속 | 상한 3, 이전 기록 `{a}` · `{a}`, 이번 `{a}` | `a` 의 연속 회차 3 |
| UT-09 | 빈 기록이 끊는다 | 이전 `{a}` · `{}` · `{a}`, 이번 `{a}` | 연속 회차 2 |
| UT-10 | 알 수 없는 기록이 끊는다 | 이전 `{a}` · 알 수 없음 · `{a}`, 이번 `{a}` | 연속 회차 2, 알 수 없는 기록 수 1 |
| UT-11 | 키마다 따로 | 이전 `{a}` · `{a,b}`, 이번 `{a,b}` | `a` 3 · `b` 2 |
| UT-12 | 같은 시각 | `created_at` 이 같은 두 요약 노트 | 조회 결과 순서로 늘어놓는다 |
| UT-13 | 조회 실패 | 조회 실패로 받은 이전 목록, 이번 `{a}` | 알 수 없는 기록 하나와 같은 결과 — `a` 1 |
| UT-14 | 상한 1 | 이전 기록 없음, 이번 `{a}` | `a` 의 연속 회차 1 이 상한 1 에 닿는다 |
| UT-15 | 요약 노트 판정 | 앞 공백 뒤 요약 제목으로 시작하는 노트, 요약 제목이 아닌 노트의 기록 줄, 작성자 표시가 다른 요약 | 첫째 · 셋째만 요약 노트 |
| UT-16 | 인용 거르기 | 기록 줄과 표지로 시작하는 다른 주석 줄이 든 요약 | 표지로 시작하는 줄이 모두 빠지고 나머지는 그대로 |

## T2 · feat: 리뷰 등록이 요약 기록을 남기고 이전 요약의 기록으로 반복 지적을 셈

### 상위 Requirement

- relates to #215

### 작업 내용

리뷰 등록이 판정 전에 그 리뷰 요청의 스레드를 조회해 이전 요약들의 기록으로 연속 회차를 다시 세고, 이번 회차의 기록을 요약 마지막
줄에 남기게 한다. 클론 로컬 이력 파일을 걷는다. 리뷰 입력의 직전 요약 인용에서 기록 줄을 뺀다. 반복 키 · 연속 규칙 · 종료 코드는
그대로다.

- 명세 1절(바뀌지 않는 것) · 2-4 · 2-5 · 2-6 · 2-7 · 9-2
- `src/harness/commands/review.py`
  - 등록(`review post` 와 `review` 의 등록 단계 — 같은 구현): 요약을 렌더하기 전에 `review_mr_threads <번호>` 로 스레드를 조회하고 T1 의
    재구성으로 연속 회차를 센다. `review.repeat_file_max` 이상인 키가 있으면 요약에 반복 줄(64 명세 4-1)을 쓰고, 요약 등록에 성공한 뒤
    종료 코드 3 이다. 요약 본문 마지막 줄은 이번 회차의 기록 줄이다
  - 스레드를 조회하지 못했거나 결과가 정규화 JSON 배열로 읽히지 않으면 표준 오류에
    `warning: could not read the review threads — repeat findings are counted from this round only` 를 쓰고 등록과 판정을 계속한다.
    조회 실패는 종료 코드에 닿지 않는다
  - 조회에 성공했고 요약 노트 가운데 알 수 없는 기록이 있으면 표준 오류에
    `note: <N> earlier review summaries carry no readable record — repeat counts restart after them` 한 줄
  - 등록 순서표(211 명세 2-3)의 "이력 자리"(4) · "이력 누적"(8) 단계를 걷는다. 하네스 루트가 git 작업 트리 밖이라는 이유로 멈추지 않는다.
    리뷰한 리비전을 인자로 받지 않았을 때 `HEAD` 를 읽는 동작은 그대로다
  - `<git 공통 디렉터리>/work-loop/` 를 만들지도 읽지도 쓰지도 않는다. 누적 파일의 경로 · 형식 판별자 · 읽기 · 쓰기 코드를 걷는다
  - 등록이 부르는 계약 함수에 `review_mr_threads` 가 든다(211 명세 2-1-4 표의 `review post` 행)
  - 리뷰 입력: 직전 요약 인용에 T1 의 인용 거르기를 쓴다. 직전 요약을 고르는 규칙 · 리뷰 시점 head 를 읽는 규칙 · 절 구성은 그대로다
  - 명령 모듈 머리 설명에서 반복 지적을 로컬에 누적한다는 서술을 "이전 요약의 기록으로 센다" 로 바꾼다. shim 머리글은 213 명세 4-1 의
    형식 그대로 둔다
- `src/templates/managed/script/test-review-loop.sh`
  - forge 페이크의 요약 등록이 그 리뷰 요청의 스레드에 인라인이 아닌 노트로 쌓이고 다음 조회에 나온다. 노트 시각은 등록 순서로 늘어나는
    고정값이고, 스레드 상태는 리뷰 요청 번호마다 따로다. 스레드 조회 실패를 `FAKE_STATE` 의 파일로 켠다
  - 기존 케이스의 종료 코드 기대값(같은 파일 반복 · 위치 없는 발견 · 줄 없는 경로)은 그대로다. `.git/work-loop/review-findings-<번호>.tsv`
    를 읽던 검사 줄은 등록된 요약의 기록 줄을 읽는 검사로 바꾼다
  - 옛 형식 누적 파일 케이스와 worktree 이력 공유 케이스를 지우고 명세 9-2 표의 일곱 케이스를 더한다. "클론이 바뀌어도 이어 센다" 는
    같은 원격을 따로 clone 한 두 번째 샌드박스(git 공통 디렉터리가 다르다)와 같은 `FAKE_STATE` 로 돈다
- `src/templates/managed/script/README.md` 의 `post-review.sh` 행: 반복 지적은 이전 요약의 기록으로 세고 로컬에 누적하지 않는다
- `src/bin/harness render` 로 이 리포의 `script/` 사본과 `.harness/managed` 갱신
- 건드릴 파일: `src/harness/commands/review.py`, `src/harness/review.py`(반복 지적 이력 파일의 읽기 · 쓰기 코드를 걷는다),
  `src/templates/managed/script/test-review-loop.sh`, `src/templates/managed/script/README.md`, `src/test/unit/test_review_record.py`, render 로 갱신되는 `script/`

### 완료 조건

- [ ] 같은 리뷰 요청에 클론 A 에서 1 · 2회차, 따로 clone 한 클론 B 에서 3회차를 같은 파일 major 로 등록하면 종료 코드가 1 · 1 · 3 이다
- [ ] 등록 뒤 git 공통 디렉터리에 `work-loop` 가 없고, 하네스 코드에 그 경로를 다루는 코드가 남지 않는다
- [ ] 등록된 요약의 마지막 줄이 명세 2-2 형식이고 `keys` 가 이번 회차의 키다. PASS 회차는 `"keys":[]` 이다
- [ ] 기록 줄 없는 요약 · `format` 이 `2` 인 기록이 연속을 끊고 표준 오류에 `note:` 줄이 나온다
- [ ] 요약 제목으로 시작하지 않는 노트의 기록 줄은 세지 않고, 요약 본문 중간의 기록 줄은 알 수 없는 기록이다
- [ ] 스레드 조회가 실패하면 그 회차는 1 이고 `warning:` 줄이 나오며 요약이 기록 줄과 함께 등록된다
- [ ] 리뷰 입력의 직전 요약 인용에 기록 줄이 없고, 요약 절과 리뷰 시점 head 를 읽는 것은 그대로다
- [ ] 기존 케이스의 종료 코드 기대값, `review-mr.sh` · `post-review.sh` 의 인자 · 종료 코드, 회차 라벨 동작이 그대로다
- [ ] 하네스 루트가 git 작업 트리 밖이어도 리비전 인자를 준 등록이 이력 때문에 멈추지 않는다
- [ ] `script/README.md` 의 `post-review.sh` 행이 기록으로 센다는 것을 적는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/215-multi-user-safety` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 클론이 바뀌어도 이어 센다 | 같은 리뷰 요청 · 같은 파일 major, 클론 A 1 · 2회차와 클론 B 3회차 (`test-review-loop.sh`) | 종료 코드 1 · 1 · 3 |
| UT-02 | 로컬 이력 없음 | 등록 한 번 | git 공통 디렉터리에 `work-loop` 없음 |
| UT-03 | 기록 줄 | major 회차 하나와 PASS 회차 하나 | 요약 마지막 줄이 2-2 형식, `keys` 가 그 회차 키, PASS 는 `"keys":[]` |
| UT-04 | 알 수 없는 기록이 끊는다 | 같은 파일 major 기록 둘 사이에 기록 줄 없는 요약, 또는 `format` 이 `2` 인 기록 | 셋째 회차 1, 표준 오류에 `note:` |
| UT-05 | 기록으로 세지 않는 줄 | 요약 제목이 아닌 노트의 기록 줄, 요약 본문 중간의 기록 줄 | 앞의 것은 세지 않고 뒤의 것은 알 수 없는 기록 |
| UT-06 | 조회 실패 | 같은 파일 major 두 회차 뒤 스레드 조회 실패 주입 | 셋째 회차 1, `warning:` 줄, 요약이 등록되고 기록 줄을 담는다 |
| UT-07 | 리뷰 입력 | 기록 줄이 있는 직전 요약 | 리뷰어 입력의 인용에 기록 줄이 없고 요약 절 · 리뷰 시점 head 는 그대로 |
| UT-08 | 기존 기대값 | 같은 파일 반복 · 위치 없는 발견 · 줄 없는 경로 케이스 | 종료 코드가 바꾸기 전과 같다 |
| UT-09 | git 밖 등록 | git 작업 트리가 아닌 하네스 루트에서 리비전 인자를 준 `harness review post` (단위 테스트, 페이크 forge) | 등록되고 판정 종료 코드로 끝난다 |

## T3 · feat: 착수 잠금 프로토콜 공용 모듈 추가

### 상위 Requirement

- relates to #215

### 작업 내용

같은 이슈의 `work` 를 한 클론만 돌게 하는 원격 잠금 ref 의 프로토콜을 공용 모듈 하나에 둔다. 잠금 명령 · pre-push · 되감기 ·
자체 검사가 이 모듈을 함께 쓴다. 이 task 는 명령과 절차를 더하지 않는다.

- 명세 3-1(이름과 내용) · 3-2(소유 기록) · 3-4(획득) · 3-5(해제) · 3-6(상태) · 3-7(원격 삭제의 범위) · 9-1 의 잠금 행(인자 행은 T5)
- `src/harness/worklock.py`
  - 접두 상수 `refs/harness/work-lock/`. 이슈 형식 `^[0-9]+$` 또는 `^[A-Z][A-Z0-9_]*-[0-9]+$` 를 git 을 부르기 전에 검사하고, 아니면 판정
    불가로 돌려준다
  - 잠금 커밋 — `git commit-tree` 로 부모가 없고 트리가 비어 있는 커밋을 만든다. 메시지에 이슈와 128비트 무작위 값(16진 32자)을 담아
    획득마다 다른 커밋이다. 작성자 · 커미터는 그 클론의 git 설정에서 오고, 신원이 없어 만들지 못하면 판정 불가다. 커밋 훅을 거치지 않는다
  - 소유 기록 — `<git 공통 디렉터리>/harness/work-lock/<이슈>` 에 잠금 커밋의 전체 객체 이름 한 줄. git 공통 디렉터리는 하네스 루트에서
    `git rev-parse --path-format=absolute --git-common-dir` 로 구한다. 같은 디렉터리의 임시 파일을 rename 해서 쓰고, 16진 40자 또는
    64자 한 줄이 아니면 기록이 없는 것으로 본다
  - 원격 값 — `git ls-remote --refs origin <ref>` 출력에서 ref 이름이 정확히 같은 줄. 명령이 실패하면 판정 불가
  - 획득 — 명세 3-4 의 1~6 과 다시 읽기 표. 새 커밋을 소유 기록에 먼저 쓴 뒤
    `git push --porcelain --force-with-lease=<ref>: origin <C>:<ref>` 로 생성 전용 push 를 하고, push 의 종료 코드와 출력이 아니라 원격 값을
    다시 읽어 판정한다
  - 해제 — 명세 3-5. 소유 기록이 없으면 원격을 부르지 않는다. `git push --porcelain --force-with-lease=<ref>:<L> origin :<ref>` 뒤 다시 읽어
    판정하고, 원격 값이 이 클론이 만든 값이 아니면 건드리지 않는다
  - 상태 — 명세 3-6. 원격도 기록도 바꾸지 않는다
  - 결과는 값(결과 종류와 원격 객체 이름)으로 돌려주고 터미널에 쓰지 않는다 — 문구는 부르는 쪽이 낸다. 잠금 커밋 만들기와 ref 이름을
    받는 생성 전용 push · 기대값 삭제 push 는 자체 검사가 다른 이름(`selftest-<16진 12자>`)으로 쓸 수 있게 따로 부를 수 있다
  - git 은 하네스 루트를 작업 디렉터리로 해서 `GIT_TERMINAL_PROMPT=0` 으로 부른다. git 의 출력에서 원격 주소를 돌려주는 값에 옮기지 않는다
- `src/test/unit/test_work_lock.py` 새 파일 — 원격은 임시 bare 리포다. 이름공간 거부 · 경합 · 삭제 거부는 bare 리포의 `pre-receive` 훅으로,
  두 번째 `ls-remote` 실패는 PATH 앞의 git 래퍼로 만든다. 잠금 커밋의 시각과 신원은 환경 변수로 고정한다
- 건드릴 파일: `src/harness/worklock.py`(신규), `src/test/unit/test_work_lock.py`(신규)

### 완료 조건

- [ ] 빈 원격에서 획득하면 새로 잡았다는 결과이고, 원격 ref 가 생기며 소유 기록과 같다. 잠금 커밋은 부모가 없고 트리가 비어 있다
- [ ] 같은 클론과 그 linked worktree 에서 다시 획득하면 push 없이 이 클론의 잠금이라는 결과이고 원격 값이 그대로다
- [ ] 같은 원격을 따로 clone 한 리포의 획득은 다른 클론의 잠금이라는 결과이고, 원격 값은 첫 클론의 것이며 둘째 클론에 소유 기록이 없다
- [ ] 조회 뒤 push 전에 같은 ref 가 생기면(서버 훅) 다른 클론의 잠금이라는 결과이고 원격 값은 먼저 만든 쪽, 소유 기록이 없다
- [ ] 시각 · 신원을 고정하고 두 번 만든 잠금 커밋이 서로 다르다
- [ ] `origin` 이 없으면 판정 불가이고 push 하지 않는다. 원격이 이름공간을 거부하면 판정 불가이고 소유 기록이 없다. push 는 받아졌는데
  다시 읽기가 실패하면 판정 불가이고 소유 기록이 남으며, 다음 획득이 이 클론의 잠금이라는 결과다
- [ ] 해제 — 이 클론의 잠금이면 풀었다는 결과이고 원격 ref 와 소유 기록이 없다. 소유 기록이 없으면 원격을 부르지 않는다(`origin` 없는 리포 포함).
  소유 기록이 원격 값과 다르면 이 클론의 잠금이 없다는 결과이고 원격 값이 그대로다. 원격이 삭제를 거부하면 풀지 못했다는 결과이고 원격 ref 와
  소유 기록이 그대로다
- [ ] 상태가 `free` · `mine <객체 이름>` · `held <객체 이름>` 에 해당하는 결과를 내고 원격과 기록을 바꾸지 않는다. `origin` 이 없으면 판정 불가다
- [ ] 16진 40자 · 64자 한 줄이 아닌 소유 기록은 기록이 없는 것으로 본다
- [ ] 이슈 형식이 아닌 값(`../x` · 공백이 든 값 · 빈 값 · `abc`)은 git 을 부르지 않고 판정 불가다. `PROJ-12` 는 받는다
- [ ] `script/project/check-cli.py imports` 의 의존 방향 검사가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/215-multi-user-safety` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 획득 | 빈 bare 원격에서 획득 | 새로 잡음, 원격 ref = 소유 기록, 커밋은 부모 없음 · 빈 트리 |
| UT-02 | 다시 획득 | 같은 클론에서 한 번 더, linked worktree 에서 한 번 더 | 둘 다 이 클론의 잠금, push 없음, 원격 값 그대로 |
| UT-03 | 다른 클론 | 같은 원격을 따로 clone 한 리포에서 획득 | 다른 클론의 잠금, 원격 값은 첫 클론의 것, 둘째 클론에 소유 기록 없음 |
| UT-04 | 경합 | `pre-receive` 훅이 받은 갱신을 처리하기 전에 같은 ref 를 다른 커밋으로 만든다 | 다른 클론의 잠금, 원격 값은 먼저 만든 쪽, 소유 기록 없음 |
| UT-05 | 같은 커밋 | 시각 · 신원을 고정하고 잠금 커밋 두 번 | 객체 이름이 다르다 |
| UT-06 | 판정 불가 — origin 없음 | `origin` 이 없는 리포에서 획득 | 판정 불가, push 호출 없음 |
| UT-07 | 판정 불가 — 이름공간 거부 | `pre-receive` 훅이 `refs/harness/` 갱신을 거부 | 판정 불가, 소유 기록 없음 |
| UT-08 | 판정 불가 — 다시 읽기 실패 | PATH 앞 git 래퍼가 두 번째 `ls-remote` 를 실패시킴 | 판정 불가, 소유 기록 남음, 래퍼를 치운 뒤 획득이 이 클론의 잠금 |
| UT-09 | 해제 | 이 클론의 잠금 | 풀었음, 원격 ref · 소유 기록 없음 |
| UT-10 | 해제 — 기록 없음 | 소유 기록 없는 리포, `origin` 없는 리포 | 이 클론의 잠금 없음, 원격 호출 없음 |
| UT-11 | 해제 — 다른 값 | 소유 기록과 다른 원격 값 | 이 클론의 잠금 없음, 원격 값 그대로 |
| UT-12 | 해제 — 삭제 거부 | `pre-receive` 훅이 삭제를 거부 | 풀지 못함, 원격 ref · 소유 기록 그대로 |
| UT-13 | 상태 | 원격 없음 · 이 클론의 값 · 다른 값, 그리고 `origin` 없음 | `free` · `mine` · `held` 와 판정 불가, 원격 · 기록 그대로 |
| UT-14 | 소유 기록 형식 | 빈 파일 · 39자 · 16진 아닌 문자 · 두 줄 | 기록 없음으로 본다 |
| UT-15 | 이슈 형식 | `../x` · `a b` · 빈 값 · `abc` · `PROJ-12` · `12` | 앞의 넷은 git 호출 없이 판정 불가, 뒤의 둘은 받는다 |

## T4 · feat: pre-push 가 잠금 이름공간만 담은 push 에 검증을 돌지 않음

### 상위 Requirement

- relates to #215

### 작업 내용

잠금 커밋의 push 는 HEAD 가 아닌 리비전이라 지금의 pre-push 검증이 거부한다. 잠금 이름공간만 담은 push 는 검증을 돌지 않고 통과시키고,
섞인 push 에서는 잠금 줄의 리비전만 HEAD 일치 검사에서 뺀다.

- 명세 5절 · 9-3 의 "pre-push 예외"
- `src/harness/hooks.py` 의 pre-push(`harness git-hook pre-push`)
  - 보호 브랜치 검사는 그대로 모든 갱신 줄에 돈다
  - 갱신 줄의 원격 ref 이름이 `worklock` 모듈의 접두 상수로 시작하면 잠금 줄이다. 판정은 ref 이름 전체로 한다 — `refs/heads/harness/work-lock/7` 은
    잠금 줄이 아니다
  - 갱신 줄이 전부 잠금 줄이면 push 전 검증(HEAD 일치 · 작업 트리 · 검증 일괄)을 돌지 않고 0 이다. 생성과 삭제 모두다
  - 잠금 줄과 다른 줄이 섞이면 잠금 줄의 리비전만 HEAD 일치 검사에서 빼고, 나머지는 지금대로 검사하고 검증한다
  - 잠금 줄이 보내는 커밋의 내용을 보지 않는다. `VERIFY_PRE_PUSH` 가 `0` 이면 지금처럼 보호 브랜치 검사만 돈다
- 단위 테스트: #210 의 pre-push 단위 테스트 곁에 잠금 줄 판정 케이스
- `src/test/render-test.sh` 새 블록 "pre-push 예외"
- `src/templates/managed/script/README.md` "규칙" 절: 잠금 이름공간만 담은 push 는 pre-push 검증을 돌지 않는다
- `src/bin/harness render` 로 이 리포의 `script/README.md` 사본과 `.harness/managed` 갱신
- 건드릴 파일: `src/harness/hooks.py`, `src/test/unit/` 의 pre-push 테스트, `src/test/render-test.sh`, `src/templates/managed/script/README.md`, render 로 갱신되는 `script/`

### 완료 조건

- [ ] `verify.pre_push` 를 켜고 실패하는 검증 단계와 미커밋 변경을 둔 설치 리포에서, 잠금 ref 생성 push 와 삭제 push 가 통과하고 검증 단계가 돌지 않는다
- [ ] 잠금 ref 와 HEAD 가 아닌 브랜치를 함께 push 하면 지금처럼 막힌다
- [ ] `harness/work-lock/7` 브랜치 push 는 예외가 아니다 — 검증이 돌아 막힌다
- [ ] 보호 브랜치 push 는 잠금 줄과 섞여도 지금처럼 막힌다
- [ ] `verify.pre_push` 를 끄면 보호 브랜치 검사만 돈다
- [ ] 접두 문자열은 `worklock` 모듈의 상수에서 오고 훅 코드에 다시 적지 않는다
- [ ] 새 블록의 터미널 출력에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/215-multi-user-safety` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 잠금 줄 판정 | 원격 ref `refs/harness/work-lock/7` · `refs/harness/work-lock/PROJ-1` · `refs/heads/harness/work-lock/7` · `refs/harness/work-lockx/7` | 앞의 둘만 잠금 줄 |
| UT-02 | 생성 push | 설치 리포(검증 켬 · 실패하는 단계 · 미커밋 변경)에서 잠금 커밋을 잠금 ref 로 push | 통과, 검증 단계 안 돎 |
| UT-03 | 삭제 push | 같은 리포에서 잠금 ref 삭제 push | 통과, 검증 단계 안 돎 |
| UT-04 | 섞인 push | 잠금 ref 와 HEAD 가 아닌 브랜치를 함께 push | 지금처럼 막힘 |
| UT-05 | 닮은 이름 | `harness/work-lock/7` 브랜치 push | 검증이 돌아 막힘 |
| UT-06 | 보호 브랜치 | 보호 브랜치 push, 잠금 ref 와 함께 push | 둘 다 지금처럼 막힘 |

## T5 · feat: 착수 잠금 명령 work-lock 과 shim 추가

### 상위 Requirement

- relates to #215

### 작업 내용

잠금 프로토콜 모듈을 부르는 하위 명령 `harness work-lock` 과 대상 리포 진입점 `script/work-lock.sh` 를 더한다. 출력 · 종료 코드 · 표준 오류
문구는 명세 3-3 의 표 그대로다.

- 명세 3-3 · 3-4 ~ 3-6 의 출력, 9-1 의 인자 · 다른 클론 표준 오류 행, 9-3 의 "진입점과 권한"
- `src/harness/commands/work_lock.py` 의 `cmd_work_lock`
  - 인자는 동작 하나(`acquire` · `release` · `status`)와 이슈 하나다. 모르는 동작, 남는 인자, 옵션 꼴 인자(`--json` · `-h` 등)는 211 명세 2-1-3
    의 거부 형식으로 사용법 `usage: harness work-lock <acquire|release|status> <issue>` 를 내고 2. 이슈 형식이 아니면 git 을 부르지 않고 2
  - 동작별 표준 출력과 종료 코드 — 명세 3-3 의 첫 표. 표준 오류 — 둘째 표(`acquire` 1 의 두 줄은 객체 이름 앞 12자와
    `git push origin --delete refs/harness/work-lock/<이슈>`, `release` 2 의 두 줄, 판정하지 못함의 `error:` · `help:` 한 줄씩)
  - 읽는 설정은 공유 설정이고 이 명령이 쓰는 설정 키는 없다. 설정을 읽지 못하면 2
- `src/harness/commands/__init__.py` 의 `COMMANDS` 에 `work-lock` — 통과 명령, 설정이 필요함, 인수 `<acquire|release|status> <issue>`.
  `src/harness/cli.py` 의 `DELEGATES` 에 넣는다
- `src/templates/managed/script/work-lock.sh` 새 shim — 213 명세 4-1 의 공통 형태와 CLI 없음 두 줄 · 종료 코드 2. 첫 줄 `#!/usr/bin/env sh`,
  실행 권한, 머리글은 부르는 명령과 로직이 패키지에 있다는 것
- `src/templates/managed/script/README.md` 에 `work-lock.sh` 행 — shim(`harness work-lock`), 동작 셋과 종료 코드 0 · 1 · 2, 호출 시점(`work` 의 잠금 ·
  해제 단계와 사람의 해제)
- 권한 허용 목록: 관리 스크립트 규칙(70 명세)대로 `Bash(script/work-lock.sh:*)` 가 나오고 제외 목록에 넣지 않는다. 다른 클론의 잠금을 지우는
  동작이 없다
- 사용 기록 어휘를 늘리지 않는다
- `README.md` "명령" 표에 `harness work-lock <acquire|release|status> <이슈>` 행 — 같은 이슈의 `work` 를 한 클론만 돌게 하는 원격 잠금 ref 를
  잡고 · 풀고 · 본다. 0 · 1 · 2. **원격 쓰기**. 절차와 사람은 `script/work-lock.sh` 로 부른다
- 단위 테스트: `src/test/unit/test_work_lock.py` 에 명령 케이스
- `src/test/render-test.sh` 새 블록 "진입점과 권한"
- `src/bin/harness render` 로 이 리포의 `script/work-lock.sh` · `script/README.md` · `.claude/settings.json` 과 `.harness/managed` 갱신
- 건드릴 파일: `src/harness/commands/work_lock.py`(신규), `src/harness/commands/__init__.py`, `src/harness/cli.py`, `src/templates/managed/script/work-lock.sh`(신규),
  `src/templates/managed/script/README.md`, `README.md`, `src/test/unit/test_work_lock.py`, `src/test/render-test.sh`, render 로 갱신되는 파일

### 완료 조건

- [ ] 세 동작이 명세 3-3 첫 표의 결과마다 그 표준 출력과 종료 코드를 낸다
- [ ] `acquire` 1 의 표준 오류가 ref 이름 · 객체 이름 앞 12자 · `git push origin --delete refs/harness/work-lock/<이슈>` 를 담은 두 줄이다
- [ ] `release` 2 와 판정하지 못함(2)의 표준 오류가 명세 3-3 둘째 표대로이고 원격 주소를 담지 않는다
- [ ] `../x` · 공백이 든 값 · 빈 값 · `abc` 는 2 이고 git 을 부르지 않는다. `PROJ-12` 는 받는다. 모르는 동작과 남는 인자는 2 다
- [ ] 같은 상태에서 세 동작을 다시 돌려도 결과가 같다
- [ ] 설치된 `script/work-lock.sh` 로 획득 · 상태 · 해제가 3-3 대로 돈다(로컬 bare 원격, 훅이 켜진 설치본)
- [ ] `.claude/settings.json` 허용 목록에 `Bash(script/work-lock.sh:*)` 가 있다
- [ ] CLI 를 치운 샌드박스에서 `script/work-lock.sh status 1` 이 `error: harness CLI not found under …` · `help: harness install --target …` 두 줄을 내고 2 다
- [ ] `harness help` 에 `work-lock` 이 나오고, 전역 CLI 로 부르면 고정 사본으로 넘어간다
- [ ] 사용 기록 어휘가 바뀌지 않는다
- [ ] `script/README.md` 와 README "명령" 표에 `work-lock` 행이 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/215-multi-user-safety` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | acquire 출력 | 빈 원격, 같은 클론에서 다시, 다른 클론의 잠금, 판정 불가 | 0 · `acquired …` / 0 · `already held by this clone: …` / 1 · 출력 없음 / 2 · 출력 없음 |
| UT-02 | acquire 1 표준 오류 | 다른 클론의 잠금 | `stop: issue <이슈> is being worked on from another clone — … is <앞 12자>` 와 `help: … git push origin --delete refs/harness/work-lock/<이슈>` |
| UT-03 | release 출력 | 이 클론의 잠금, 기록 없음, 삭제 거부 | 0 · `released …` / 0 · `no lock held by this clone for issue <이슈>` / 2 · 두 줄 표준 오류 |
| UT-04 | status 출력 | 원격 없음 · 이 클론 · 다른 클론 · `origin` 없음 | `free` · `mine <객체>` · `held <객체>` 와 0, 마지막은 2 |
| UT-05 | 판정하지 못함 문구 | `origin` 없음 | 표준 오류가 `error:` 한 줄과 `help:` 한 줄, 원격 주소 없음 |
| UT-06 | 인자 | `../x` · `a b` · 빈 값 · `abc` · `PROJ-12` · 모르는 동작 · 남는 인자 · `--json` | `PROJ-12` 만 받고 나머지는 2, 거부할 때 git 호출 없음 |
| UT-07 | 되풀이 | 같은 상태에서 세 동작을 두 번씩 | 두 번의 결과가 같다 |
| UT-08 | 설치본 진입점 | 설치 리포(로컬 bare 원격, 훅 켬)에서 `script/work-lock.sh acquire` · `status` · `release` (`render-test.sh`) | 3-3 의 출력 · 종료 코드 |
| UT-09 | 권한 | 설치 리포의 `.claude/settings.json` | `Bash(script/work-lock.sh:*)` 가 허용 목록에 있다 |
| UT-10 | CLI 없음 | CLI 를 치운 샌드박스에서 `script/work-lock.sh status 1` | 두 줄과 종료 코드 2 |
| UT-11 | 명령 표 | `COMMANDS` · `DELEGATES` · `harness help` | `work-lock` 이 통과 표시와 함께 있고 도움말에 나온다 |

## T6 · feat: 기본 work 가 시작 단계에서 잠금을 잡고 끝 상태로 가는 배선에서 품

### 상위 Requirement

- relates to #215

### 작업 내용

내장 기본값의 driver 절차 `work` 가 착수 판정보다 먼저 잠금을 잡고, 끝 상태로 가는 배선마다 같은 이름의 해제 단계를 거치게 한다.
doctor 의 이전 기본값 목록에 잠금 단계가 없는 driver 기본값을 더한다.

- 명세 4-1 · 4-4 · 4-5, 9-3 의 "기본 `work` 배선" · "끝 상태마다 해제" · "획득 실패" · "해제를 거치지 않는 끝" · "doctor"
- `src/templates/defaults.toml` 의 `[workflows.work]`
  - `lock` 을 단계 목록의 첫 원소로 둔다 — script, 제목 "착수 잠금", `run = "script/work-lock.sh acquire {issue}"`, 배선 `"0"` → `clean` · `"*"` → `stop`
  - 해제 단계 셋을 단계 목록 끝에 `unlock-done` · `unlock-stop` · `unlock-handoff` 순으로 둔다 — script, 제목 "잠금 해제",
    `run = "script/work-lock.sh release {issue}"`, 배선 `"*"` → 각자 같은 이름의 끝 상태
  - `lock` 뒤 단계에서 끝 상태로 가던 배선을 같은 이름의 해제 단계로 바꾼다 — `clean` · `preflight` · `task-sync` · `recheck` · `develop-check` 의 `*`,
    `develop` 의 `failed`, `loop` 의 `stop` 은 `unlock-stop`, `loop` 의 `handoff` 와 `finalize` 의 `failed` 는 `unlock-handoff`, `finalize-check` 의 `*` 는
    `unlock-done`. 끝 상태를 직접 가리키는 배선은 `lock` 의 실패 쪽과 해제 단계 셋뿐이다
  - 하위 절차 `review-loop` 는 바꾸지 않는다
- doctor 의 이전 기본값 목록 상수에 잠금 단계가 없는 driver 기본값(212 명세 2-1 의 절 그대로)을 한 항목으로 더한다. doctor 의
  `workflows.work is a previous default` 와 `harness fix legacy-work` 가 같은 목록을 따른다
- 리뷰 명령 모듈의 머리 설명에서 동시 실행 서술을 명세 4-4 의 두 항목으로 바꾼다 — `work` 경로의 리뷰는 잠금을 잡은 클론에서만 돌아 회차 라벨 갱신과
  요약 등록이 클론 사이에서 겹치지 않고, 기록 재구성은 이것을 전제로 한 번에 한 등록자를 가정한다. 손으로 부른 리뷰 명령은 잠금을 잡지 않고, 그것끼리
  또는 그것과 `work` 가 겹치는 동시 실행은 지원하지 않는다
- `src/test/render-test.sh`
  - 새 블록 다섯 — 명세 9-3 의 다섯 행. "끝 상태마다 해제" · "획득 실패" · "해제를 거치지 않는 끝" 은 샌드박스 `harness.toml` 의 테스트용 driver
    절차(잠금 → 종료 코드를 고를 수 있는 스텁 단계 → 해제 셋)를 로컬 bare 원격으로 돈다
  - #212 의 driver `work` 케이스: 지나온 단계의 맨 앞에 `lock`, 끝에 해제 단계가 더해지고, 끝 줄의 `at <절차>/<id>` 가 해제 단계를 가리키도록
    (#208 7-7) 기대값을 고친다. 끝 상태와 그 앞 단계 · outcome 은 그대로다. 샌드박스의 bare 원격에 잠금이 생기고 끝난 뒤 없어지는 것을 함께 본다
- `src/bin/harness render` 로 이 리포의 `.ai/workflows/work.md`(그래프와 단계별 다음 표)를 갱신
- 건드릴 파일: `src/templates/defaults.toml`, doctor 의 이전 기본값 목록을 가진 공용 모듈, `src/harness/commands/review.py`(머리 설명), `src/test/render-test.sh`,
  render 로 갱신되는 `.ai/workflows/work.md`

### 완료 조건

- [ ] 내장 기본값 `work` 의 시작 단계가 `lock` 이고 `run` 이 `script/work-lock.sh acquire {issue}` 다
- [ ] 끝 상태를 직접 가리키는 배선이 `lock` 의 실패 쪽과 해제 단계 셋뿐이고, 해제 단계 셋이 각자 같은 이름의 끝 상태로 간다
- [ ] 테스트용 driver 절차가 `done` · `stop` · `handoff` 각각으로 끝난 뒤 원격 잠금이 없고 끝 상태가 스텁이 고른 것이다
- [ ] 다른 클론이 잡은 상태에서 같은 절차를 돌리면 스텁 단계가 불리지 않고 `stop` 이며 원격 잠금 값이 그대로다
- [ ] 해제 단계보다 먼저 닿는 `max_steps` 로 드라이버의 `stop` 이 나면 원격 잠금이 남고, 같은 클론에서 다시 돌리면 `lock` 이 0(`already held by this clone`)으로
  지나가며, `script/work-lock.sh release <이슈>` 뒤 원격 잠금이 없다
- [ ] 잠금 단계가 없는 driver 기본값과 같은 `work` 절을 가진 설정에서 doctor 가 그 절을 짚고, `harness fix legacy-work` 가 그 절을 지운다
- [ ] #212 의 driver `work` 케이스가 고친 기대값으로 통과하고, 바꾼 줄은 구현 리뷰 요청 본문의 대응표에 있다
- [ ] 리뷰 명령 모듈의 머리 설명이 명세 4-4 의 두 항목이다
- [ ] 이 리포의 `.ai/workflows/work.md` 에 잠금 · 해제 단계와 그 배선이 있고 `harness check` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/215-multi-user-safety` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 기본 work 배선 | 내장 기본값 `work` 정의 | 시작 단계 `lock` · 획득 `run`, 끝 상태 직접 배선은 `lock` 실패 쪽과 해제 셋뿐, 해제 셋은 같은 이름의 끝으로 |
| UT-02 | 끝 상태마다 해제 | 테스트용 driver 절차, 스텁이 `done` · `stop` · `handoff` 를 고름 | 세 경우 모두 원격 잠금 없음, 끝 상태가 고른 것 |
| UT-03 | 획득 실패 | 다른 클론이 잡은 bare 원격에서 같은 절차 | 스텁 단계 안 불림, `stop`, 원격 값 그대로 |
| UT-04 | 해제를 거치지 않는 끝 | 해제보다 먼저 닿는 `max_steps`, 다시 실행, `script/work-lock.sh release` | 드라이버 `stop` 뒤 잠금 남음, 다시 돌면 `lock` 0 · `already held by this clone`, 해제 뒤 잠금 없음 |
| UT-05 | doctor | 잠금 단계가 없는 driver 기본값과 같은 `work` 절 | `workflows.work is a previous default` 를 `warn` 으로 짚고, `fix legacy-work` 가 절을 지운다 |
| UT-06 | 기존 driver work 케이스 | #212 의 PASS · 착수 불가 · 리뷰 상한 등 케이스 | 지나온 단계에 `lock` 과 해제 단계, 끝 상태 그대로, 끝난 뒤 원격 잠금 없음 |

## T7 · feat: agent 모드 work 문서와 위임 어댑터에 잠금 획득 · 해제 지시 추가

### 상위 Requirement

- relates to #215

### 작업 내용

`work` 가 agent 모드로 렌더될 때(#212 의 되돌림 경로, 옛 `[workflows.work]` 단계 목록을 가진 설치본 포함) 오케스트레이터가 착수 판정 전에
잠금을 잡고 끝내기 전에 풀도록 머리 · 꼬리 조각과 위임 어댑터에 지시를 둔다. 두 조각은 단계 목록과 무관하게 렌더되므로 설치본의 단계 목록을
고치지 않아도 닿는다.

- 명세 4-2 · 4-3, 9-3 의 "agent 모드 문서"
- `src/templates/workflows/work/_head.md` "중단 조건"
  - 순서: 작업 트리 → 잠금 획득 → 착수 판정(이슈 확인 포함) → 완료 조건
  - 잠금 항목: "`script/work-lock.sh acquire <번호>` 가 0 이 아니다. 1 은 다른 클론이 이 이슈를 돌고 있다는 뜻이다. 2 는 잠금을 판정하지 못한
    것이다 — "없음" 이 아니다. 멈추고 출력을 그대로 보고한다"
  - "**잠금이 착수 판정보다 먼저다.**" 와 그 이유 한 문장(잠금 전에 판정하면 그 사이 다른 클론이 리뷰 요청을 만들고 루프를 끝내 잠금을 푼 경우를
    보지 못하고 같은 이슈를 다시 착수한다)
  - "잠금을 잡은 뒤 중단 조건에 걸리면 꼬리 조각의 해제를 돌고 끝낸다"
  - 두 조각은 driver 절차 문서에도 들어간다(212 명세 2-4). 순서 문장은 agent 모드로 돌 때의 순서임을 밝힌다 — driver 의 `lock` 은 작업 트리
    확인보다도 앞이다
- `src/templates/workflows/work/_tail.md` — "출력" 앞에 "끝내기 전" 절
  - "어느 판정으로 끝나든(PASS · 상한 도달 · 중단) `script/work-lock.sh release <번호>` 를 돈다. 잡지 않았으면 아무것도 하지 않고 0 이다"
  - "2 면 그 출력을 '남은 것' 에 그대로 적는다 — 잠금이 남아 다른 클론이 이 이슈를 착수하지 못한다"
  - "driver 실행이 해제 단계를 거치지 않고 끝났으면 — 드라이버가 스스로 낸 stop, 끊긴 실행을 `--discard` 로 버림 — 잠금이 남는다. 이 이슈를 다시
    돌리지 않으면 `script/work-lock.sh release <번호>` 로 푼다"
  - 출력 양식의 머리 목록에 `- 착수 잠금: 해제 | 남음(<사유>)`
- `src/templates/managed/.claude/commands/work.md` 위임표에 행 — 착수 잠금 (착수 판정 전 · 끝내기 전) | `script/work-lock.sh acquire <이슈번호>` ·
  `script/work-lock.sh release <이슈번호>` — Bash | 이슈 번호
- `src/test/render-test.sh` 새 블록 "agent 모드 문서"
- `src/bin/harness render` 로 이 리포의 `.ai/workflows/work.md` 갱신
- 건드릴 파일: `src/templates/workflows/work/_head.md`, `src/templates/workflows/work/_tail.md`, `src/templates/managed/.claude/commands/work.md`, `src/test/render-test.sh`,
  render 로 갱신되는 `.ai/workflows/work.md`

### 완료 조건

- [ ] 옛 다섯 단계 `[workflows.work]` 로 렌더한 `.ai/workflows/work.md` 에서 `script/work-lock.sh acquire` 가 `script/work-preflight.sh` 보다 앞에,
  `script/work-lock.sh release` 가 출력 절 앞에 있다
- [ ] 머리 조각이 명세 4-2 의 잠금 항목 · "잠금이 착수 판정보다 먼저다" 와 이유 · 중단 시 해제 지시를 담는다
- [ ] 꼬리 조각의 "끝내기 전" 절이 명세 4-2 의 세 항목을 담고, 출력 머리 목록에 `- 착수 잠금: 해제 | 남음(<사유>)` 가 있다
- [ ] 옛 절로 깔린 `.claude/commands/work.md` 의 위임표에 착수 잠금 행이 있다
- [ ] 기본 설정(driver)으로 렌더한 `.ai/workflows/work.md` 에도 두 조각이 들어가고, 순서 서술이 driver 의 `lock` → `clean` 배선과 어긋나지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/215-multi-user-safety` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | agent 모드 순서 | 옛 다섯 단계 `[workflows.work]` 로 render | `work-lock.sh acquire` 가 `work-preflight.sh` 보다 앞, `work-lock.sh release` 가 출력 절 앞 |
| UT-02 | 꼬리 조각 출력 양식 | 같은 렌더 결과 | 머리 목록에 `- 착수 잠금: 해제 \| 남음(<사유>)` |
| UT-03 | 위임 어댑터 | 같은 설정으로 깔린 `.claude/commands/work.md` | 위임표에 `script/work-lock.sh acquire` · `release` 행 |
| UT-04 | driver 문서 | 기본 설정으로 render 한 `.ai/workflows/work.md` | 두 조각의 잠금 서술이 있고 agent 모드 순서임을 밝힌다 |

## T8 · feat: 되감기가 이 클론의 착수 잠금을 보이고 다른 대상 뒤에 품

### 상위 Requirement

- relates to #215

### 작업 내용

되감기(`harness rollback`, 진입점 `script/rollback-work.sh`)가 잠금 프로토콜 모듈의 상태 판정으로 잠금 상태를 보이고, 이 클론의 잠금만 다른 대상을
모두 되감은 뒤에 푼다. 같은 프로세스에서 모듈을 부르고 `script/work-lock.sh` 를 거치지 않는다.

- 명세 6절 · 9-4
- 되감기 명령 모듈 `src/harness/commands/rollback.py`(#213 의 `harness rollback`)
  - `mine`: 보이는 단계의 "will be closed or removed" 아래 `    work lock refs/harness/work-lock/<이슈>   held by this clone`. 확인을 받은 뒤 다른 대상을
    모두 되감은 **뒤에** 해제한다. 성공하면 `released the work lock refs/harness/work-lock/<이슈>`, 풀지 못하면
    `warning: could not release the work lock refs/harness/work-lock/<이슈>` 와 실패(종료 코드 2)
  - `held`: "left alone" 아래 `    work lock refs/harness/work-lock/<이슈> — held by another clone. if that run is gone, delete it yourself: git push origin --delete refs/harness/work-lock/<이슈>`.
    건드리지 않는다
  - `free`: 보이지 않는다
  - 판정 불가: "left alone" 아래 `    work lock — state unknown (could not read origin)`. 건드리지 않고 종료 코드에 닿지 않는다
  - "되감을 것이 없음" 판정은 열린 리뷰 요청 · task 이슈 · 로컬 브랜치 · `mine` 잠금이 모두 없을 때다. 그때도 `held` · 판정 불가 줄은
    `nothing to roll back for issue <이슈>` 다음에 보인다
  - `--dry-run` 은 상태만 보이고 해제하지 않는다
  - 명령 모듈 머리 설명의 "되감는다" 에 이 클론의 착수 잠금을, "남긴다" 에 다른 클론의 착수 잠금을 더한다
  - `COMMANDS` 의 `rollback` 설명을 `roll back what work made for an issue: close its review requests and task issues, remove local branches, release this clone's work lock (asks first)` 로
- `src/templates/managed/script/test-rollback-work.sh` — 샌드박스에 로컬 bare 원격(`origin`)과 따로 clone 한 두 번째 클론을 두고 명세 9-4 의 다섯 케이스를 더한다
- `src/templates/managed/script/README.md` 의 `rollback-work.sh` 행에 이 클론의 착수 잠금을 푼다는 것. `README.md` "명령" 표의 `harness rollback` 행도 같은 뜻으로
- `src/bin/harness render` 로 이 리포의 `script/` 사본과 `.harness/managed` 갱신
- 건드릴 파일: `src/harness/commands/rollback.py`, `src/harness/commands/__init__.py`, `src/templates/managed/script/test-rollback-work.sh`, `src/templates/managed/script/README.md`,
  `README.md`, render 로 갱신되는 `script/`

### 완료 조건

- [ ] 이 클론의 잠금이 있으면 보이는 단계의 "will be closed or removed" 아래에 잠금 줄이 있고, `--yes` 뒤 원격 잠금이 없으며 종료 코드 0 이다
- [ ] 해제는 리뷰 요청 · task 이슈 · 로컬 브랜치를 되감은 뒤에 돈다
- [ ] 다른 클론의 잠금이면 "left alone" 아래에 잠금 줄과 `git push origin --delete` 가 있고, `--yes` 뒤 원격 잠금 값이 그대로다
- [ ] 다른 클론의 잠금 말고 되감을 것이 없으면 `nothing to roll back` 다음에 잠금 줄이 있고 종료 코드 0, 원격 잠금 값이 그대로다
- [ ] `--dry-run` 은 이 클론의 잠금이 있어도 원격 잠금과 소유 기록을 그대로 둔다
- [ ] 잠금 상태를 읽지 못해도 나머지 되감기는 돌고, `state unknown` 줄이 있으며 그 때문에 종료 코드가 바뀌지 않는다
- [ ] 해제가 실패하면 `warning: could not release …` 와 종료 코드 2 다
- [ ] `harness help` 의 `rollback` 설명이 명세 6절 문구다
- [ ] `test-rollback-work.sh` 의 기존 케이스가 기대값 그대로 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/215-multi-user-safety` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 이 클론의 잠금 | 이 클론이 잡은 잠금과 열린 리뷰 요청, `--yes` | "will be closed or removed" 아래 잠금 줄, 원격 잠금 없음, 종료 코드 0, 해제가 마지막 |
| UT-02 | 다른 클론의 잠금 | 둘째 클론이 잡은 잠금, `--yes` | "left alone" 아래 잠금 줄과 `git push origin --delete`, 원격 값 그대로 |
| UT-03 | 잠금만 남은 경우 | 다른 클론의 잠금 말고 되감을 것 없음 | `nothing to roll back` 다음에 잠금 줄, 종료 코드 0, 원격 값 그대로 |
| UT-04 | `--dry-run` | 이 클론의 잠금, `--dry-run` | 원격 잠금 · 소유 기록 그대로 |
| UT-05 | 판정 불가 | `origin` 을 읽지 못하는 샌드박스 | 나머지 되감기가 돌고 `state unknown` 줄, 종료 코드는 잠금과 무관 |
| UT-06 | 해제 실패 | 삭제를 거부하는 서버 훅과 이 클론의 잠금, `--yes` | `warning: could not release …`, 종료 코드 2 |
| UT-07 | 도움말 | `harness help` | `rollback` 줄이 명세 6절 문구 |

## T9 · feat: 자체 검사의 쓰기 단계에 잠금 생성 · 배타 · 삭제 항목 추가

### 상위 Requirement

- relates to #215

### 작업 내용

forge 가 `refs/harness/work-lock/` 이름공간의 생성 · 배타 · 기대값 삭제를 받는지 실제 원격으로 확인하는 항목 셋을 자체 검사의 쓰기 단계에 더한다.
잠금 프로토콜 모듈의 잠금 커밋 만들기와 생성 · 삭제 push 를 쓰고, 실사용 잠금과 겹치지 않는 이름을 쓴다.

- 명세 7절, 9-3 의 "자체 검사"
- `src/harness/forge/selftest.py`
  - 쓰기 단계(`--write` · `--create-issue` 가 도는 2단계)의 기존 항목 뒤에 `work lock: create` · `work lock: exclusive` · `work lock: delete`
  - 이름은 `refs/harness/work-lock/selftest-<무작위 16진 12자>` 다
  - `create` — 새 잠금 커밋을 생성 전용으로 push 한 뒤 원격 값이 그 커밋이다. `exclusive` — 같은 이름에 다른 잠금 커밋을 생성 전용으로 push 하면
    받아지지 않고 원격 값이 그대로다. `delete` — 첫 커밋을 기대값으로 건 삭제 push 뒤 원격에 그 ref 가 없다
  - `create` 가 실패하면 나머지 둘은 `skip` 이고 사유는 `the remote did not accept refs/harness/work-lock/ — work cannot take its start lock on this forge`
  - `delete` 가 실패하면 `FAIL` 사유에 지우는 명령(`git push origin --delete <ref>`)을 함께 쓴다
  - 모듈 머리 설명의 단계 표에서 `--write` 가 남기는 것은 댓글 3건 그대로이고, 잠금 ref 는 지우고 끝나며 `delete` 가 실패한 경우에만 ref 하나가
    남는다고 적는다
  - 읽기 전용 실행의 쓰기 단계 skip 줄, 판정 줄의 문구와 종료 코드 규칙은 바꾸지 않는다
- `src/test/render-test.sh` 새 블록 "자체 검사" — forge 는 `HARNESS_FORGE_FAKE`, 원격은 로컬 bare 리포
- 건드릴 파일: `src/harness/forge/selftest.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] `--write` 를 받는 bare 원격에서 잠금 세 항목이 `ok` 다
- [ ] 이름공간을 거부하는 원격(서버 훅)에서 `create` 가 `FAIL`, 나머지 둘이 명세의 사유로 `skip`, 종료 코드 1 이다
- [ ] 두 경우 모두 끝난 뒤 원격의 잠금 이름공간에 ref 가 없다
- [ ] 삭제를 거부하는 원격에서 `delete` 의 `FAIL` 사유에 `git push origin --delete <ref>` 가 있다
- [ ] 항목 이름의 ref 가 `selftest-` 이름이고 이슈 잠금 형식과 겹치지 않는다
- [ ] 읽기 전용 실행의 출력이 바뀌지 않는다
- [ ] 새 블록의 터미널 출력에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/215-multi-user-safety` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 받는 원격 | `--write`, 받는 bare 원격 | 세 항목 `ok`, 끝난 뒤 잠금 이름공간에 ref 없음 |
| UT-02 | 거부하는 원격 | `--write`, `pre-receive` 훅이 `refs/harness/` 를 거부 | `create` `FAIL`, 둘 `skip`(명세 사유), 종료 코드 1, ref 없음 |
| UT-03 | 삭제 거부 | `--write`, 삭제만 거부하는 서버 훅 | `delete` `FAIL` 사유에 `git push origin --delete <ref>` |
| UT-04 | 이름 | 세 항목이 쓴 ref | `refs/harness/work-lock/selftest-` 뒤 16진 12자 |
| UT-05 | 읽기 전용 | 옵션 없이 실행 | 쓰기 단계 출력이 바꾸기 전과 같다 |

## T10 · docs: 반복 지적 기록과 착수 잠금을 절차 · 사람용 문서와 관련 명세에 반영

### 상위 Requirement

- relates to #215

### 작업 내용

T2 · T6 · T8 이 만든 동작을 절차 조각 · 사람용 문서 · 역할 계약과 관련 명세에 적는다.

- 명세 8절 가운데 다른 task 가 맡지 않은 행
- `src/templates/workflows/work/limits.md`
  - 상한 표의 보조 행: "`script/post-review.sh` — 회차마다 요약 댓글에 그 회차의 반복 키를 기록으로 남기고, 이전 요약들의 기록으로 연속 회차를 세어
    상한에 닿으면 종료 코드 3"
  - 신뢰 수준 문단: 반복 카운트는 요약 기록에서 다시 세므로 어느 클론에서 이어 돌려도 같다. 다만 댓글은 사람이 지우거나 고칠 수 있고 읽지 못한
    기록은 연속을 끊는다 — 회차 상한보다 먼저 잡는 신호이지 종료 보장이 아니다
  - 되감기 문단에 "이 클론의 착수 잠금도 푼다"
- `src/templates/managed/docs/workflow/flow.md`
  - "루프가 멈추는 조건" 표의 반복 행 — 요약 기록으로 세고 어느 클론에서 이어 돌려도 같다
  - 새 절 "여러 클론이 같은 리포를 쓸 때" — 착수 잠금의 획득 · 해제 시점, 남은 잠금 찾기(`git ls-remote origin 'refs/harness/work-lock/*'`)와 누가 잡았는지
    보기(`git fetch origin refs/harness/work-lock/<이슈> && git log -1 FETCH_HEAD`), 사람이 지우는 명령, 해제 단계를 거치지 않는 끝(드라이버가 스스로
    낸 stop · 끊긴 실행 · `--discard`)이 잠금을 남긴다는 것과 푸는 명령(`script/work-lock.sh release <이슈>` — `--discard` 로 버릴 때 함께 돈다),
    `work` 를 직접 정의하면 잠금 단계와 해제 배선을 함께 둔다는 것
- `src/templates/managed/.ai/templates/code-reviewer.md` 의 `path` 문자 제한 근거 문장: "인라인 등록 목록의 탭 · 줄 · NUL 구분 형식과 요약 기록 줄에 들어가고"
- `README.md` — 같은 리포를 여러 클론이 쓸 때 반복 지적은 리뷰 요청에서 이어 세고 같은 이슈는 한 클론만 착수한다는 한 문단
- `docs/spec/64-modularize-cli-review-scripts.md` 1절의 누적 파일 항목, 3절의 마지막 항목, 5절 `judge` 행의 "반복 누적분" — 215 명세 2절을 가리키게
- `docs/spec/71-issue-worktree-run.md` 1절의 이력 위치 항목, 7절, 9-2 — 215 명세 2절을 가리키게
- `src/bin/harness render` 로 이 리포의 `.ai/templates/code-reviewer.md` · `docs/workflow/flow.md` 사본과 `.harness/managed` 갱신
- 건드릴 파일: `src/templates/workflows/work/limits.md`, `src/templates/managed/docs/workflow/flow.md`, `src/templates/managed/.ai/templates/code-reviewer.md`, `README.md`,
  `docs/spec/64-modularize-cli-review-scripts.md`, `docs/spec/71-issue-worktree-run.md`, render 로 갱신되는 사본

### 완료 조건

- [ ] `limits.md` 의 보조 행 · 신뢰 수준 문단 · 되감기 문단이 명세 8절대로이고, 로컬 파일에 쌓여 새 클론에서 0 부터 센다는 서술이 없다
- [ ] `flow.md` 의 반복 행과 새 절이 명세 8절의 항목을 모두 담는다
- [ ] `code-reviewer.md` 의 `path` 근거 문장에 요약 기록 줄이 있고, 리뷰 계약 단위 테스트(스키마 키 · 표지 일치)가 통과한다
- [ ] README 에 여러 클론 문단이 있다
- [ ] 64 · 71 명세의 해당 절이 215 명세 2절을 가리키고 클론 로컬 이력 파일을 현재 사실로 적지 않는다
- [ ] `src/bin/harness check` 가 어긋남 없이 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/215-multi-user-safety` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 옛 서술 없음 | `grep -rn "work-loop" src README.md docs/workflow` | 하네스 문서에 클론 로컬 이력을 현재 사실로 적은 줄이 없다 |
| UT-03 | 리뷰 계약 | 리뷰 계약 단위 테스트 | 스키마 키 · 표지가 계약에 있다는 검사가 통과한다 |

## T11 · docs: 아키텍처 · 용어 · 담당 범위 · 테스트 문서에 요약 기록과 착수 잠금 반영

### 상위 Requirement

- relates to #215

### 작업 내용

T2 · T3 · T4 · T5 · T6 · T8 로 생긴 요약 기록과 착수 잠금을 에이전트가 근거로 읽는 문서에 적는다.

**보호 문서를 수정하는 task 다.** 고치는 범위는 명세 10절의 "보호 문서 개정 범위" 그대로이고, 2026-10-09 결정 게이트에서 사용자가 허용한 범위다.
그 범위 밖의 문장은 고치지 않는다. 같은 절을 앞 이슈들이 먼저 고친다 — #206 → #207 → #208 · #209 · #210 → #211 → #212 → #213 이 고친 문장 위에
더하거나, 그 문장 안의 어구를 내용으로 찾아 바꾼다. 권한 설정 · 가드에 걸리면 사람이 대응한다.

- 명세 10-1 `.ai/project/architecture.md`
  - "구성 요소" 의 CLI 패키지(`src/harness/`) 항목: 하위 명령 나열에 착수 잠금(`work-lock` — 원격 잠금 ref 의 획득 · 해제 · 상태). 되감기(`rollback`)
    서술에 "이 클론의 착수 잠금을 푼다"
  - "구성 요소" 의 대상 리포 `script/` 항목: shim 나열에 착수 잠금(`work-lock.sh` → `harness work-lock`)
  - "구성 요소" 의 기기 단위 상태 다음: "클론 단위 상태 — git 공통 디렉터리 아래 `harness/work-lock/<이슈>`: 이 클론이 잡은 착수 잠금의 커밋 이름.
    같은 클론의 worktree 가 함께 쓴다"
  - "데이터 흐름" 의 절차 실행: 기본 `work` 의 단계 나열 맨 앞에 "착수 잠금(원격에 잠금 ref 를 만들어 잡는다 — 착수 판정보다 먼저)", 그 문장 뒤에
    "끝 상태로 가는 배선은 잠금 해제 단계를 거친다. 드라이버가 스스로 낸 stop 과 `--discard` 는 해제를 거치지 않아 잠금이 남는다". `review-loop` 의 등록
    단계 괄호에서 "반복 지적 누적" 을 "이전 요약 기록으로 반복 지적 판정" 으로, "요약" 을 "요약(기록 줄 포함)" 으로
  - "신뢰 경계": 요약 기록 줄(`harness:review-record`)은 forge 출력이라 신뢰하지 않는다는 문장과, 착수 잠금 ref 를 push 권한자 누구나 만들고 지울 수
    있고 하네스는 이 클론이 만든 값일 때만 지우며 pre-push 가 잠금 이름공간만 담은 push 에 검증을 돌지 않는다는 문장 — 명세 10-1 의 문안 그대로
  - "계층과 의존 방향" 의 기기 단위 상태 항목 끝: "클론에 묶인 상태(착수 잠금의 소유 기록)는 git 공통 디렉터리에 둔다 — 클론을 옮기면 따라가고
    클론을 지우면 함께 사라진다"
- 명세 10-2 `.ai/project/glossary.md` "용어" 표: `착수 잠금` · `요약 기록` 새 행, `표지` 행의 예시에 `harness:review-record`
- 명세 10-3 `.ai/project/scope.md` "할 수 있는 일" 의 `run` 항목 끝: "여러 클론이 같은 리포를 돌려도 같은 이슈는 한 클론만 착수하고, 반복 지적은 리뷰
  요청의 요약 기록으로 이어 센다"
- 명세 10-4 `.ai/project/testing.md` "외부 의존을 어떻게 다루나" 의 forge 항목 끝: "forge 서버의 ref 갱신 동작(이름공간 거부 · 조회와 push 사이의 경합)은
  bare 리포의 서버 훅으로 흉내 낸다"
- `.ai/AI_AGENT.md` 는 생성 파일이다. 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/architecture.md`, `.ai/project/glossary.md`, `.ai/project/scope.md`, `.ai/project/testing.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] `.ai/project/architecture.md` 가 명세 10-1 표의 여섯 행을 담는다
- [ ] `.ai/project/glossary.md` 가 명세 10-2 표의 세 행을 담는다
- [ ] `.ai/project/scope.md` · `.ai/project/testing.md` 가 명세 10-3 · 10-4 의 문장을 담는다
- [ ] 네 문서에서 명세 10절 밖의 문장이 바뀌지 않았다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 1장 · 2장 · 5장이 네 문서와 일치하고 `harness check` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/215-multi-user-safety` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 반영 확인 | `.ai/AI_AGENT.md` | 2장에 `착수 잠금` · `요약 기록`, 5장에 `work-lock` · 클론 단위 상태 · 요약 기록 신뢰 경계 · pre-push 예외 |
| UT-03 | 범위 | 네 문서의 diff | 명세 10절 표의 위치에만 변경이 있다 |
