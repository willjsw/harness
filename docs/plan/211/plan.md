# #211 분해 — 리뷰 루프 · 착수 판정 · task 동기화 하위 명령

명세: [`docs/spec/211-port-work-steps.md`](../../spec/211-port-work-steps.md)
결정 기록: 없음

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | chore | 리뷰 루프·착수 판정·동기화 sh 테스트의 준비부를 샌드박스 CLI·설정 사본·페이크 주입으로 전환 | 없음 |
| T2 | refactor | 착수 판정을 harness preflight 로 이식하고 work-preflight.sh 를 shim 으로 전환 | T1 |
| T3 | refactor | task 이슈 동기화를 harness sync-tasks 로 이식하고 sync-task-issues.sh 를 shim 으로 전환 | T2 |
| T4 | refactor | 리뷰 루프를 harness review 로 이식하고 review-mr.sh·post-review.sh 를 shim 으로 전환 | T3 |
| T5 | docs | README 명령 표와 관련 명세를 하위 명령 기준으로 갱신 | T4 |
| T6 | docs | 아키텍처·용어·범위 문서에 리뷰·착수 판정·동기화 하위 명령 반영 | T4 |

- T1 은 구현을 고치지 않는다. 세 sh 테스트(`test-review-loop.sh` · `test-work-preflight.sh` · `test-sync-task-issues.sh`)와
  `render-test.sh` UT-99 의 준비부 가운데 이식 전 구현에서도 성립하는 것(명세 5-6 첫 항목)을 바꾸고, **이식 전 구현에서** 통과시킨다.
  이식 전 구현은 #207 · #209 가 고친 셸 스크립트다 — `script/forge.sh` 가 CLI 의 `harness forge` 를 부르는 shim 이라
  `HARNESS_FORGE_FAKE` 로 끼운 페이크가 셸 호출부에도 닿는다
- T2 · T3 · T4 는 명령 하나씩 옮긴다. 각 task 가 하위 명령, shim, 그 명령의 sh 테스트에서 새 구현에서만 성립하는 줄(명세 5-6 둘째 항목),
  명세 5-3 의 sh 케이스, 5-4 의 단위 테스트, 5-5 의 render-test 케이스, `script/README.md` 의 그 행을 한 커밋에 바꾼다.
  커밋마다 회귀 테스트 전체가 통과한다
- T2 가 세 명령이 함께 쓰는 처리(인자 거부 문구 · 처리하지 않은 예외 · 신호 · 줄 단위 출력)와 경계 모듈 `src/harness/scripts.py`
  (사용 기록 · 지표 감싸기)를 둔다. T3 은 그것을 쓰고, T4 가 `scripts.py` 에 역할 실행기 호출을 더한다
- T4 는 리뷰 모듈 `src/harness/review.py`, 명령 모듈 `commands/review.py`, 두 shim, `_review.py` 삭제를 한 커밋에 둔다. 판정 데이터를
  만드는 코드와 읽는 코드(인라인 발견 접두, 이력 형식 판별자)가 커밋 사이에서 두 모듈로 갈리지 않게 한다. `_review.py` 를 보던
  sh 테스트 구조 검사(UT-21 · UT-26 · UT-27)도 같은 커밋에서 단위 테스트로 옮긴다
- T4 뒤 이 브랜치의 `script/review-mr.sh` 는 새 구현을 부른다. 구현 리뷰 요청의 리뷰 루프는 이 브랜치의 새 구현으로 돈다(명세 3-5)
- T5 는 사람용 설명과 이 리포의 다른 명세를, T6 은 보호 문서를 T2 ~ T4 가 만든 사실에 맞춘다

## 착수 순서와 다른 이슈

- 착수 조건: #206 · #207 · #209 가 `develop` 에 머지된 뒤 착수한다. 표지 모듈 `src/harness/format.py` 는 그때 있다(#209 · #210 가운데 먼저 머지된 쪽이 둔다)
- 기대는 선행 명세
  - #206 — 모듈 지도(`commands/<이름>.py` · `cmd_<이름>`, 공용 모듈), `COMMANDS` 항목 `(통과, 설정이 필요한가, 인수, 설명)` 과 통과 명령의
    인자 나누기, 고정 사본 배치 `.harness/bin/harness` · `.harness/lib/harness/` · `.harness/templates/`, 단위 테스트 자리
    `src/test/unit/` 과 실행 `cd src && python3 -B -m unittest discover -s test/unit`, 의존 방향 검사 `script/project/check-cli.py imports`
  - #207 — 공유 설정 · 실효 설정, 실효 설정 읽기와 `run_plan()`(같은 프로세스), 실행 계획의 `roles.code-reviewer.exe` · `label`,
    `test-review-loop.sh` 의 준비부(명세 14-4 — 고정 사본 · 설정 사본 · 벤더 선언 사본 · `run-plan` 으로 읽는 리뷰 러너)
  - #209 — `harness.forge.load(cfg, root)` 의 어댑터와 계약 함수, 주입 지점 `HARNESS_FORGE_FAKE`, `format.markers(root)`, `script/forge.sh` shim
- 이 이슈 뒤에 오는 것: #212(driver 절차가 세 명령의 종료 코드와 `preflight` 표준 출력 첫 토큰으로 분기) · #213(`scripts.py` 를 패키지
  모듈로 바꾼다) · #215(이력 자리와 착수 순서를 바꾼다, 이 이슈 · #212 · #213 뒤) · #221(shim 과 `check-open-mrs.sh` 를 걷는다, main 릴리스 한 번 뒤)
- #210 과는 기대지 않는다. 둘 다 `src/test/render-test.sh` · `src/templates/managed/script/README.md` 를 고치므로 먼저 머지된 쪽 위로
  `git fetch -p origin` 뒤 rebase 한다. rebase 뒤 push 는 사람이 한다

## 브랜치·리뷰 요청·커밋

- 브랜치: `refactor/211-port-work-steps` — 요구사항 이슈 #211 하나가 브랜치 하나·리뷰 요청 하나다. 태그는 요구사항 이슈 제목의 `refactor` 다
- 리뷰 요청 제목: `refactor: 리뷰 루프·착수 판정·task 동기화를 하위 명령으로 이식(#211)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #211` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 리뷰 요청 본문에 명세 5-1 의 대응표를 단다 — T1 · T2 · T3 · T4 가 sh 테스트와 `render-test.sh` 에서 바꾼 줄마다 바꾸기 전 줄 → 바꾼 줄과 까닭.
  단위 테스트로 옮긴 케이스(UT-21 · UT-26 · UT-27)는 옮긴 자리를 적는다
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #211`

## 전 task 공통 사항

- 하위 명령 코드는 python3 표준 라이브러리만 쓴다. 모듈 자리는 명세 4절이고, `script/project/check-cli.py imports`(#206 3-4 의 의존 방향)가 통과한다.
  명령 모듈은 다른 명령 모듈을 불러오지 않는다
- 관리 스크립트 · 역할 계약의 정본은 `src/templates/managed/` 다. 정본을 고친 뒤 `src/bin/harness render` 로 이 리포의 `script/` 사본과
  `.harness/managed` 를 갱신해 함께 커밋한다. 사본과 생성 파일을 손으로 고치지 않는다
- 인자 · 표준 출력 · 종료 코드 · 표준 오류 문구는 이식 전 스크립트에서 그대로 옮긴다. 새로 쓰는 문구는 명세가 적은 것(사용법 줄, 예외의 마지막 줄,
  실행 계획 실패의 `help:`, `review post` 의 본문 · 리비전 오류, shim 의 CLI 없음 두 줄)뿐이다
- `-` 로 시작하는 인자를 거부하는 문구는 명세 2-1-3 의 `error: unknown option: <인자>` 와 사용법이다. 2-4 · 2-5 의 "사용법과 종료 코드 2" 도
  이 문구로 낸다
- 하위 명령은 git · forge 어댑터 · 역할 실행기 · 사용 기록을 하네스 루트를 작업 디렉터리로 부르고, 자기 프로세스의 현재 디렉터리를 바꾸지 않는다
- forge 는 #209 의 `load(cfg, root)` 로만 부른다. `gh` · `glab` · `jira` 와 `script/forge.sh` 를 부르지 않는다. 주입 알림(#209 4-3)은 내지 않는다 —
  표준 오류가 이식 전과 같아야 한다
- 표지는 `format.markers(root)` 로만 읽는다. 파이썬 쪽에 표지 값 · 사용 기록 · 지표 기록 · 역할 실행기 로직의 사본을 두지 않는다
- 명령은 결과(판정 · 건수 · 회차 · 매핑)를 값으로 만든 뒤 텍스트로 낸다. 표준 출력은 줄마다 바로 내보낸다
- 스크립트 머리 주석의 설명(판정 순서의 까닭, 동시 실행, 반복 카운트가 보조 상한인 까닭 등)은 명령 모듈과 `review.py` 의 머리 설명으로 옮긴다.
  shim 머리 주석에는 부르는 명령, 로직이 패키지에 있다는 것, 인자 · 종료 코드 계약만 둔다(명세 3-1)
- 테스트는 원격을 부르지 않는다. 페이크는 `HARNESS_FORGE_FAKE=<절대 경로>` 로 끼우고, 그 값은 forge 를 부르는 명령 하나의 환경에만 준다 —
  테스트 전체에 내보내지 않는다(#209 4-4)
- 샌드박스에서 CLI 를 부르는 실행은 `HARNESS_HOME` 을 샌드박스 안 경로로 둔다. 테스트는 실제 홈의 등록부 · 지표 · 사용 기록에 쓰지 않고 `HOME` 을 바꾸지 않는다
- 단위 테스트는 `src/test/unit/test_<대상>.py` 에 두고 CLI 를 하위 프로세스로 띄우지 않는다. 명령 진입 함수를 불러 부르고, forge · git ·
  하위 프로세스는 그것을 부르는 함수를 바꿔 끼운다(#206 7-5). 셸 페이크를 써야 하는 확인은 sh 테스트가 맡는다
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록 형식을 따른다
- 커밋 전 `script/run-lint-test.sh --commit` 과, 그 task 가 고친 sh 테스트(`script/test-review-loop.sh` · `script/test-work-preflight.sh` ·
  `script/test-sync-task-issues.sh`)를 render 뒤에 직접 돌려 통과시킨다. 이 리포는 `[verify]` 의 `script_tests = false` 라 커밋 단계 검증이
  sh 테스트를 돌리지 않는다. push 전 검증은 `render-test.sh` 의 설치본 블록이 설치한 리포와 모노레포 서브프로젝트에서 세 sh 테스트를 돌린다

## 이번 이슈에서 정하지 않는 값

- 세 명령이 함께 쓰는 처리(인자 거부 문구 · 처리하지 않은 예외 · 신호 · 줄 단위 출력)의 모듈 자리 — 명세 4절 표 밖이다. 명령 모듈끼리
  불러오지 않는 규칙(#206 3-4)을 지키는 공용 모듈에 둔다
- `render-test.sh` 에 더하는 블록의 번호 — 머지 시점에 겹치지 않는 다음 번호

## 이번 이슈에서 다루지 않는 것

- 기계용 출력(`--json`) — 세 명령은 두지 않고 그 인자를 거부한다(명세 1절)
- 반복 지적 이력의 리뷰 요청 이전과 착수 잠금 — #215
- 사용 기록 · 지표 기록 · 역할 실행기 · 표지 정본의 이식 — #213
- shim · `check-open-mrs.sh` 걷기, 에이전트가 보는 명령 표기 전환, sh 테스트의 거취 — #221
- 절차 조각 · 역할 어댑터 선언 · 역할 계약 · 기본 설정과 이 리포 설정의 `run` 값 · 권한 허용 목록 · `docs/workflow/` 의 표기(명세 3-3 · 6절)
- `.ai/project/testing.md`(명세 7절)
- 같은 리뷰 요청을 동시에 두 번 리뷰할 때의 잠금, 다른 기기 · 클론 사이의 동기화 잠금(명세 9절)
