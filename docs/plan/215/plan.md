# #215 분해 — 여러 클론이 함께 쓰는 반복 지적 이력과 착수 잠금

명세: [`docs/spec/215-multi-user-safety.md`](../../spec/215-multi-user-safety.md)
결정 기록: [`docs/adr/0022-repeat-findings-history-lives-on-the-review-request.md`](../../adr/0022-repeat-findings-history-lives-on-the-review-request.md) ·
[`docs/adr/0023-work-starts-are-locked-by-creating-a-dedicated-ref.md`](../../adr/0023-work-starts-are-locked-by-creating-a-dedicated-ref.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | 요약 기록 표지와 기록 렌더 · 읽기 · 연속 회차 재구성 함수 추가 | 없음 |
| T2 | feat | 리뷰 등록이 요약 기록을 남기고 이전 요약의 기록으로 반복 지적을 셈 | T1 |
| T3 | feat | 착수 잠금 프로토콜 공용 모듈 추가 | 없음 |
| T4 | feat | pre-push 가 잠금 이름공간만 담은 push 에 검증을 돌지 않음 | T3 |
| T5 | feat | 착수 잠금 명령 work-lock 과 shim 추가 | T3, T4 |
| T6 | feat | 기본 work 가 시작 단계에서 잠금을 잡고 끝 상태로 가는 배선에서 품 | T2, T5 |
| T7 | feat | agent 모드 work 문서와 위임 어댑터에 잠금 획득 · 해제 지시 추가 | T5 |
| T8 | feat | 되감기가 이 클론의 착수 잠금을 보이고 다른 대상 뒤에 품 | T3, T4 |
| T9 | feat | 자체 검사의 쓰기 단계에 잠금 생성 · 배타 · 삭제 항목 추가 | T3, T4 |
| T10 | docs | 반복 지적 기록과 착수 잠금을 절차 · 사람용 문서와 관련 명세에 반영 | T2, T6, T8 |
| T11 | docs | 아키텍처 · 용어 · 담당 범위 · 테스트 문서에 요약 기록과 착수 잠금 반영 | T2, T5, T6, T8 |

- T1 → T2 가 반복 지적 이력(명세 2절)이다. T1 은 리뷰 모듈에 함수와 단위 테스트만 더하고 등록 · 리뷰 입력의 동작을 바꾸지 않는다.
  T2 가 그 함수를 등록과 리뷰 입력에 잇고, 클론 로컬 이력을 걷고, `test-review-loop.sh` 를 기록 기준으로 바꾼다
- T3 → T4 → T5 가 착수 잠금 명령(명세 3절 · 5절)이다. 잠금 프로토콜은 공용 모듈 하나(T3)이고 명령 · pre-push · 되감기 · 자체 검사가
  그것을 함께 쓴다. pre-push 예외(T4)가 명령(T5)보다 먼저다 — 훅이 켜진 설치본에서 잠금 커밋의 push 는 HEAD 가 아닌 리비전이라
  예외 없이는 거부되고, T5 의 설치본 케이스가 그 push 를 한다
- 반복 지적(T1 · T2)과 잠금(T3 ~ T5)은 서로 기대지 않는다. T6 이 둘을 만난다 — 리뷰 명령 모듈의 동시 실행 서술(명세 4-4)이
  잠금이 리뷰 회차를 직렬화한다는 것과 기록 재구성의 전제를 함께 적는다
- T6 은 내장 기본값 `work` 의 배선과 doctor 의 이전 기본값 목록을 바꾼다. T7 은 단계 목록과 무관하게 렌더되는 머리 · 꼬리 조각과
  위임 어댑터로 agent 모드의 같은 지시를 둔다. 둘 다 `script/work-lock.sh` 가 있어야 참인 서술이라 T5 뒤다
- T8 · T9 는 잠금 모듈을 같은 프로세스에서 부르고 shim 을 거치지 않는다. 둘 다 원격 ref 를 만들거나 지우므로 pre-push 예외(T4) 뒤다
- T10 은 코드가 만든 동작을 절차 조각 · 사람용 문서 · 역할 계약 · 관련 명세에 적는다. 관리 스크립트 표(`script/README.md`)의 행은
  그 스크립트를 바꾸는 task(T2 · T4 · T5 · T8)가, README "명령" 표의 행은 그 명령을 더하거나 바꾸는 task(T5 · T8)가 함께 고친다
- T11 은 보호 문서 개정 task 하나다(명세 10절)
- 명세 8절의 `docs/spec/README.md` 행은 명세와 함께 들어가 있다

## 착수 순서와 다른 이슈

- 착수 조건: #211 · #212 · #213 의 구현 리뷰 요청이 `develop` 에 머지된 뒤 착수한다(그 선행 #206 · #207 · #208 · #209 · #210 포함).
  브랜치는 그 뒤의 `origin/develop` 에서 만든다. 보호 문서 문안은 #206 → #207 → #208 · #209 · #210 → #211 → #212 → #213 → #215 순서로
  얹힌다(명세 10절)
- 이 분해가 기대는 선행 명세의 자리
  - 패키지 배치와 명령 표: `src/harness/commands/<이름>.py`(`-` 는 `_`) · `commands/__init__.py` 의 `COMMANDS`(`(통과, 설정이 필요한가, 인수, 설명)`
    네 원소 항목) · `cli.py` 의 `DELEGATES`, 공용 모듈 규칙(명령 모듈끼리 부르지 않는다), 단위 테스트 자리 `src/test/unit/`
    (`cd src && python3 -B -m unittest discover -s test/unit`) — #206
  - 내장 기본값 `src/templates/defaults.toml`, 공유 설정 — #207
  - driver 절차의 단계 · 배선 · 끝 상태 · 끝 보고(`at <절차>/<id>` 는 끝 상태로 보낸 가장 안쪽 단계), 드라이버가 스스로 내는 `stop`,
    실행 상태 · 재개 · `--discard` — #208
  - 자체 검사 `src/harness/forge/selftest.py` 와 그 단계 · 항목 출력, 페이크 주입 `HARNESS_FORGE_FAKE` — #209
  - git 훅 본문 `src/harness/hooks.py` 의 pre-push(`harness git-hook pre-push`) — #210
  - 리뷰 하위 명령 `harness review` · `harness review post`(명령 모듈 `src/harness/commands/review.py`, 리뷰 모듈 `src/harness/review.py`),
    등록의 순서표(2-3), 하위 명령의 인자 거부 규칙 — #211
  - 기본 `work` driver 절차(첫 단계 `clean`)와 하위 절차 `review-loop`, 머리 · 꼬리 조각을 두 실행 방식이 함께 쓰는 것, doctor 의
    `workflows.work is a previous default` 항목과 이전 기본값 목록 상수 — #212
  - 되감기 하위 명령 `harness rollback`(진입점 `script/rollback-work.sh`), 표지 정본 `src/harness/format.py` 와 셸 표기
    `script/harness-format.sh` 의 일치 단위 테스트, shim 공통 형태와 CLI 없음 문구(213 명세 4-1) — #213
- 뒤에 오는 이슈와의 경계
  - #221 은 main 릴리스 한 번 뒤에 `script/work-lock.sh` 를 포함한 shim 을 걷고 에이전트가 보는 표기를 하위 명령으로 바꾼다. 이 이슈가
    낸 기본 `work` 를 doctor 의 이전 기본값 목록에 더하는 것도 #221 이 한다
  - #216 ~ #219 와는 순서 간선이 없다
- **실제 forge 확인은 사람이 한다.** GitHub 원격이 `refs/harness/work-lock/` 의 생성 · 기대값 삭제 push 를 받는지는 회귀 테스트가 보지 않는다
  (명세 3절의 확인 필요). T9 를 커밋한 뒤 구현 리뷰 요청을 머지하기 전에, 사람이 이 리포에서 `script/forge-selftest.sh --write <리뷰요청번호>`
  를 돌려 잠금 세 항목의 결과를 리뷰 요청 본문에 적는다. 쓰기 단계는 그 리뷰 요청에 탐침 댓글을 남기는 원격 쓰기라 구현자 권한 밖이다
- 같은 배치의 다른 구현 리뷰 요청이 `README.md` · `src/test/render-test.sh` · `src/templates/defaults.toml` · `src/templates/managed/script/README.md` ·
  보호 문서를 함께 고친다. 먼저 머지된 쪽 위로 `git fetch -p origin` 뒤 rebase 한다. rebase 뒤 push 는 사람이 한다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/215-multi-user-safety` — 요구사항 이슈 #215 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: 여러 클론이 반복 지적 이력을 공유하고 같은 이슈의 동시 착수를 막음(#215)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #215` 와 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #215`

## 전 task 공통 사항

- 관리 파일의 정본은 `src/templates/managed/`, 절차 조각은 `src/templates/workflows/`, 내장 기본값은 `src/templates/defaults.toml` 이다. 고친 뒤
  `src/bin/harness render` 로 이 리포의 사본(`script/` · `.ai/templates/` · `docs/workflow/`)과 생성 파일 · `.harness/managed` 를 갱신해 함께
  커밋한다. 사본과 생성 파일을 손으로 고치지 않는다
- CLI 패키지는 python3 표준 라이브러리만 쓴다. 공용 모듈은 `cli` · `commands` 를 불러오지 않고, 명령 모듈은 다른 명령 모듈을 불러오지
  않는다(#206 3-4). `script/project/check-cli.py imports` 가 이것을 검사한다
- **잠금 프로토콜 모듈은 `src/harness/worklock.py` 하나다.** 접두 상수 `refs/harness/work-lock/` 는 이 모듈에만 적고, 명령 · pre-push ·
  되감기 · 자체 검사가 이 모듈에서 가져온다. git 은 하네스 루트를 작업 디렉터리로 해서 `GIT_TERMINAL_PROMPT=0` 으로 부르고, git 의 출력에서
  원격 주소를 터미널로 옮기지 않는다
- 표지는 `src/harness/format.py` 에서만 읽고 파이썬 쪽에 표지 문자열을 적지 않는다. 표지를 더하면 셸 표기 `script/harness-format.sh` 에도
  같은 이름과 값을 같은 변경에서 둔다
- forge 는 #209 의 어댑터로만 부른다. 어댑터 계약 함수를 더하지 않는다. 설정 키를 더하지 않는다(명세 1절)
- 에이전트 · 설정이 보는 명령 표기는 `script/<이름>.sh` 그대로다. 기본 `work` 의 `run` 값과 절차 조각 · 위임 어댑터도 `script/work-lock.sh`
  를 쓴다. `script/work-lock.sh` 는 213 명세 4-1 의 shim 이고 걷는 일은 #221 이 한다
- 터미널 출력은 영어, 문서와 조각은 한국어다. 출력 문구는 명세의 영어 원문 그대로 둔다
- 회귀 테스트는 실제 원격 · forge · 에이전트 CLI 를 부르지 않는다. 원격은 로컬 bare 리포이고, forge 서버의 ref 갱신 동작(이름공간 거부 ·
  조회와 push 사이의 경합 · 삭제 거부)은 bare 리포의 `pre-receive` 훅으로 흉내 낸다. 잠금 커밋의 시각과 신원은 환경 변수
  (`GIT_AUTHOR_*` · `GIT_COMMITTER_*`)로 고정한다. forge 는 `HARNESS_FORGE_FAKE` 와 `FAKE_STATE` 로 끼우고 명령 하나의 환경에만 준다
- Python 단위 테스트는 `src/test/unit/test_<대상>.py` 에 두고 CLI 를 하위 프로세스로 띄우지 않는다. 패키지 모듈의 함수를 부르고, git 은
  임시 리포에서 실제로 돌린다
- 기존 회귀 테스트의 검사 줄을 바꾸는 곳(`test-review-loop.sh` 의 누적 파일 검사 줄, #212 의 driver `work` 케이스의 지나온 단계와 끝 줄)은
  구현 리뷰 요청 본문에 옛 줄 → 새 줄 대응표와 바꾼 까닭을 둔다. 종료 코드 기대값은 명세가 바꾸라고 적은 곳 말고는 그대로다
- `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록 형식과 병렬 블록 묶음 형식을 따르고, 블록 번호는 착수 시점의 다음 번호를 쓴다.
  터미널 출력의 한글 검사는 새 블록에도 적용한다
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다. 동작이 바뀌어 틀리게 된 주석(명령 모듈 · shim 의 머리 설명
  포함)은 그 동작을 바꾸는 task 에서 고친다
- 커밋 전 `script/run-lint-test.sh --commit` 이 통과한다

## 이번 이슈에서 정하지 않는 값

- 잠금 모듈 · 리뷰 모듈 안의 함수 이름과 나눔 — 자리는 `src/harness/worklock.py` · `src/harness/review.py` 로 정한다
- 잠금 커밋 메시지의 문장 — 이슈와 128비트 무작위 값(16진 32자)을 담는다는 것만 정한다(명세 3-1)
- `harness work-lock` 이 판정하지 못할 때(2)의 `error:` · `help:` 문구 — 영어 한 줄씩이고 무엇을 하지 못했는지 적으며 원격 주소를 담지 않는다(명세 3-3)
- `harness help` 의 `work-lock` 설명 문구 — 영어 한 줄이고 원격에 쓴다는 것을 `(writes to the remote)` 로 밝힌다(#211 의 `review` · `sync-tasks` 표기)
- 회귀 테스트의 서버 훅 · git 래퍼 · 스텁 파일과 도우미 함수의 이름, `FAKE_STATE` 아래 새 상태 파일의 이름

## 이번 이슈에서 다루지 않는 것

- 남은 잠금의 자동 해제 — 시간 만료 · 드라이버의 끝 공통 처리를 두지 않는다. 해제 단계를 거치지 않은 끝은 안내로 다룬다(명세 4-1 · 12절)
- 손으로 부른 리뷰 명령의 잠금 · 리뷰 요청 단위 잠금(명세 4-4)
- 같은 클론 안에서 agent 모드로 같은 이슈를 동시에 도는 것(명세 12절)
- 리뷰 스레드 노트의 작성자 필터와 어댑터 계약 변경(명세 1절 · 2-1)
- 이미 남은 `<git 공통 디렉터리>/work-loop/review-findings-<번호>.tsv` 를 지우는 것(명세 2-7)
- `script/work-lock.sh` 를 걷고 표기를 하위 명령으로 바꾸는 것 — #221
- 실제 forge(GitHub · GitLab)에서 잠금 이름공간을 확인하는 것 — 사람이 자체 검사로 한다(위 "착수 순서와 다른 이슈")
