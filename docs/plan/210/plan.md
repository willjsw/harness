# #210 분해 — 명령 가드·시크릿 스캔·git 훅 본문의 Python 이식

명세: [`docs/spec/210-port-guards-and-hooks.md`](../../spec/210-port-guards-and-hooks.md)
결정 기록: 없음

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | chore | 명령 가드 회귀 테스트를 훅 명령 호출과 훅 입력 모양으로 바꾸고 판정 고정 케이스 추가 | 없음 |
| T2 | chore | 시크릿 스캔 회귀 테스트와 git 훅 회귀 단언을 배치 중립으로 전환 | 없음 |
| T3 | refactor | 표지 읽기 format.py 의 markers 와 허용 표지 단언 추가 | 없음 |
| T4 | refactor | harness.env 읽기 모듈 envfile 추가 | 없음 |
| T5 | refactor | 명령 가드의 입력 해석·기존 판정 명령·낱말 분해·가드 6종을 CLI 패키지로 이식 | T4 |
| T6 | refactor | 명령 가드 줄 판정의 디코드와 판정 문자열을 CLI 패키지로 이식 | T5 |
| T7 | refactor | 명령 가드 줄 판정의 히어독 처리를 CLI 패키지로 이식 | T6 |
| T8 | refactor | 명령 가드 하위 명령 bash-guard 추가 | T7 |
| T9 | refactor | 시크릿 스캔 하위 명령 secret-scan 추가 | T3 |
| T10 | refactor | git 훅 본문 하위 명령 git-hook 과 harness.env 의 VERIFY_PRE_PUSH 추가 | T4, T9 |
| T11 | refactor | 훅 명령·git 훅·옛 경로를 하위 명령으로 넘기는 shim 으로 전환 | T1, T2, T8, T10 |
| T12 | chore | 진입점 전환의 회귀 케이스 추가 | T11 |
| T13 | docs | README 명령 표·벤더 선언 주석·다른 명세에 하위 명령 반영 | T11 |
| T14 | docs | 아키텍처·테스트 문서에 가드·훅 하위 명령 반영 | T11 |

- task 번호 순서로 커밋한다
- T1 · T2 는 구현을 고치지 않는다. 배치에 기대는 테스트 준비부를 바꾸고 명세 5-3 의 케이스와 차단 문구 대조를 더해 **옛 구현**
  (#220 머지 뒤 셸 가드 · 셸 시크릿 스캔 · 생성 훅)에서 통과시킨다(명세 9-1). T11 이 진입점을 바꾼 뒤 같은 케이스가 기대값을
  고치지 않고 새 구현에서 통과한다
- T3 · T4 는 가드와 훅이 함께 쓰는 공용 모듈이다. T3 의 `format.py` 는 #209 와 이 이슈 가운데 먼저 머지되는 쪽이 만든다 —
  통합 브랜치에 이미 있으면 정의를 명세 6절과 대조만 하고, 이 명세가 더하는 단언 하나만 더한다
- T5 → T6 → T7 은 판정이다. T5 는 기존 판정, T6 은 줄 판정의 디코드와 판정 문자열(`<<` 앞까지), T7 은 히어독과 `<<` 조건이다.
  #220 의 T2 · T3 경계와 같다. T6 의 단위 테스트는 `<<` 가 없는 입력만 써서 T7 이 그 테스트를 고치지 않는다
- T8 · T9 · T10 이 하위 명령 셋을 등록한다. T11 전까지 진입점은 옛 구현을 부르고, 새 하위 명령은 단위 테스트로만 돈다
- T11 이 진입점 셋(훅 명령 · git 훅 · 옛 경로)을 한 커밋에서 바꾼다(명세 11). `script/hooks/_guards.sh` 가 관리 파일 목록에서
  빠지고, 셸 테스트의 내부 구조 검사 셋은 지워진다 — T5 · T7 의 단위 테스트가 받는다
- T12 는 T11 이 만든 동작을 `render-test.sh` 새 블록으로 고정한다
- T14 가 보호 문서를 고치는 유일한 task 다(명세 12)

## 착수 조건

- #206 과 #220 이 `develop` 에 머지된 뒤 그 위에서 브랜치를 만든다
  - #206 — CLI 패키지 배치(`src/harness/`, 명령 모듈 `commands/<명령>.py`, 고정 사본 `.harness/lib/harness/`), 통과 명령 장치
    (`COMMANDS` 의 통과 표시 · `parse_command_line()`), 단위 테스트 기반(`src/test/unit/`, `[verify]` 의 "Python 단위 테스트",
    `test_commands.py`), 의존 방향 검사(`script/project/check-cli.py imports`)
  - #220 — 셸 가드의 두 판정(기존 판정 · 줄 판정)과 `test-bash-guard.sh` 케이스. 이 이식의 오라클이다

## 다른 이슈와의 관계

- #209 — `src/harness/format.py` 의 `markers()` 와 `test_format.py` 를 먼저 머지되는 쪽이 만든다(T3)
- #213 — 이 이슈 뒤에 온다. `script/usage-log.sh` · `script/run-lint-test.sh` 와 표지 정본을 옮긴다. 그때까지 가드 · 훅은 두
  스크립트를 하위 프로세스로 부르고 표지는 `script/harness-format.sh` 에서 읽는다
- #221 — 옛 경로의 shim 둘(`script/hooks/bash-guard.sh` · `script/secret-scan.sh`)과 `script/harness.env` 를 걷는다
- 보호 문서의 같은 절을 #206 · #209 · #213 · #221 도 고친다. 먼저 머지된 쪽이 고친 문장 위에 이 이슈의 사실만 더한다(T14)

## 브랜치·리뷰 요청·커밋

- 브랜치: `refactor/210-port-guards-and-hooks` — 요구사항 이슈 #210 하나가 브랜치 하나·리뷰 요청 하나다. 이슈 제목의 태그
  `refactor` 를 따른다
- 리뷰 요청 제목: `refactor: 명령 가드·시크릿 스캔·git 훅 본문을 CLI 하위 명령으로 이식(#210)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #210` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #210`
- 리뷰 요청 본문에 셸 테스트에서 옮기거나 지운 검사 줄의 줄 단위 대응표(그 검사를 받는 단위 테스트)와, 준비부를 바꾼 줄의
  전후 대응표를 둔다(명세 9-1)

## 전 task 공통 사항

- 외부 계약은 명세 1절의 "바뀌지 않는 것" 그대로다 — 가드 6종과 순서, 0 통과 · 2 차단, 차단 사유와 안내 문구(한 글자도),
  사용 기록 라벨, 판정 값의 출처(`script/harness.env`), 시크릿 스캔의 0 · 1 · 2 와 허용 표지, git 훅의 판정 · 문구 · 사용 기록,
  `core.hooksPath`, `.claude/settings.json` 의 `permissions` 와 에이전트가 보는 명령 표기(`script/secret-scan.sh` 등), Codex 훅
  미연결. 현행과 달라지는 지점은 명세 5-2 · 8-2 의 표가 전부다
- 오라클은 #220 머지 뒤 셸 테스트(`test-bash-guard.sh` · `test-secret-scan.sh` · `render-test.sh` 의 훅 · 가드 케이스) 검사 줄의
  기대값(종료 코드 · 출력)과 명세 5-2 · 5-3 의 표다. 기대값을 바꾸지 않는다. 고칠 수 있는 것은 준비부와 내부 구조를 보는
  검사 줄뿐이다
- 셸 문법 라이브러리(`shlex` 등)의 분해 결과로 판정하지 않는다. 낱말 분해는 명세 4-4 의 셸 가드 규칙을 옮긴다
- CLI 패키지 코드는 표준 라이브러리만 쓴다. 패키지 안의 import 는 `harness.` 로 시작하는 절대 경로이고 #206 3-4 의 의존 방향을
  지킨다 — 가드 · 표지 · 설정 파일 읽기 모듈은 공용 모듈이라 `cli` · `commands` 를 불러오지 않는다
- 가드 경로(`bash-guard`)는 진입 스크립트와 벤더 선언 말고는 `harness.toml` 해석 · render · 지표 모듈과 `urllib` · `http` 를
  불러오지 않는다. 함수 안에서 늦게 불러오는 것도 하지 않는다(명세 2-3)
- 단위 테스트는 `src/test/unit/test_<대상>.py` 에 두고 #206 7-5 의 규칙을 따른다 — CLI 를 하위 프로세스로 띄우지 않고, 패키지
  모듈을 불러 함수를 부르며, 외부 명령(git · `script/usage-log.sh` · `script/run-lint-test.sh`)은 그것을 부르는 함수를 바꿔
  끼운다. 소스 리포에만 있다. 실행은 `cd src && python3 -B -m unittest discover -s test/unit`
- 셸 테스트는 대상 리포에 깔리는 계약 테스트로 남는다
- 판정 값이 필요한 단위 테스트는 단위 테스트 자리 아래의 고정한 `harness.env` 견본 하나를 `envfile` 로 읽어 쓴다 — 보호 브랜치
  둘, 보호 문서 목록, forge CLI, 이슈 삭제 금지를 담는다
- 관리 스크립트 · 생성 템플릿의 정본은 `src/templates/managed/` · `src/templates/generated/` 다. 정본을 고친 뒤
  `src/bin/harness render` 로 이 리포의 `script/` 사본 · 생성 파일 · `.harness/managed` 를 갱신해 함께 커밋한다. 사본과 생성
  파일을 손으로 고치지 않는다
- 이 리포는 `[verify]` 의 `script_tests = false` 라 커밋 단계 검증이 `script/test-bash-guard.sh` · `script/test-secret-scan.sh` 를
  돌리지 않는다. 이 둘이나 판정 · 스캔 동작에 닿는 task 는 커밋 전에 render 뒤의 사본을 직접 돌린다. `src/test/render-test.sh` 는
  push 단계에서 돌고, 그것을 고치는 task 는 커밋 전에 직접 돌린다
- 보호 문서 경로를 명령 문자열에 적어 Bash 도구로 돌리지 않는다 — 작업 세션의 보호 문서 가드가 명령 문자열 전체를 보고 막는다.
  케이스 값은 기존 테스트처럼 설정에서 받는다
- 터미널 출력은 영어다(결정 기록 0011)
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 케이스는 `UT-<번호>` 블록
  형식이고 번호는 머지 시점에 겹치지 않는 다음 번호다
- 커밋 전 `script/run-lint-test.sh --commit` 이 통과한다

## 이번 이슈에서 정하지 않는 값

- `src/harness/guard/` 안의 모듈 나눔과 함수 이름, 판정 순서(명세 4-1)를 가드 패키지와 명령 모듈 가운데 어디에 두는지 — 명세는
  정본 위치(`src/harness/guard/` · `commands/bash_guard.py` · `commands/secret_scan.py` · `commands/git_hook.py` · `hooks.py` ·
  `envfile.py` · `format.py`)만 정한다
- 시크릿 스캔 모듈의 파일 이름 — 명세는 `src/harness/guard/` 아래라는 것만 정한다
- 단위 테스트의 `harness.env` 견본 파일 이름과 무예외 시험의 시드 값 · 생성 건수

## 이번 이슈에서 다루지 않는 것

- 명세 13절의 한계 — 명령 치환 안의 히어독과 다루지 못하는 구조 뒤의 명령, 주석 안 따옴표가 뒤 줄과 짝지어지는 경우,
  `${…}` 안의 `<<`, 셸이 그렇게 실행하지 않아도 기존 판정이 내는 차단, python3 3.11 이상이 없는 기기의 명령 가드
- `script/run-lint-test.sh` · `script/usage-log.sh` 와 표지 정본의 이식 — #213
- 옛 경로의 shim 둘 · `script/harness.env` · 옛 허용 규칙을 걷는 일 — #221
- Codex 훅 연결 — `src/templates/vendors.toml` 의 `hooks = false` 그대로
- 결정 기록 본문(0012 · 0013 의 `script/…` 경로 표기)과 `docs/spec/58-…` 의 doctor 출력 예시
