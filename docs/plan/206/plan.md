# #206 분해 — CLI 패키지와 고정 사본의 패키지 설치

명세: [`docs/spec/206-split-cli-into-package.md`](../../spec/206-split-cli-into-package.md)
결정 기록: [`docs/adr/0019-harness-logic-lives-in-one-python-stdlib-package.md`](../../adr/0019-harness-logic-lives-in-one-python-stdlib-package.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | refactor | 회귀 테스트와 UI 단위 테스트를 CLI 파일 배치에 기대지 않게 정리 | 없음 |
| T2 | refactor | 렌더·대조 본문을 render_target·check_target 으로 떼고 urllib 을 쓰는 함수 안에서 불러옴 | 없음 |
| T3 | feat | 명령줄 해석을 parse_command_line 으로 떼고 명령 표에 통과 표시를 둠 | T1 |
| T4 | chore | CLI 컴파일·의존 방향 검사 스크립트를 두고 검증 단계를 그것으로 바꿈 | T1 |
| T5 | refactor | CLI 를 진입 스크립트와 패키지로 나누고 고정 사본에 패키지를 설치 | T1, T2, T3, T4 |
| T6 | feat | CLI 바이트코드를 등록부 아래 .cache/pycache 에 쌓음 | T5 |
| T7 | docs | README 와 리뷰 점검 문서에 CLI 패키지 구조와 바이트코드 캐시 반영 | T6 |
| T8 | docs | 다른 명세의 함수·상수 자리를 CLI 패키지 모듈로 고침 | T6 |
| T9 | docs | 아키텍처·용어·테스트 문서에 CLI 패키지와 바이트코드 캐시 반영 | T6 |

- T1 은 CLI 를 고치지 않는다. 옛 배치(`src/bin/harness` 한 파일과 `src/bin/harness_metrics.py`)에서 회귀 테스트 · UI 단위 테스트가
  배치에 기대는 곳(명세 7-2)을 두 배치 모두에서 도는 형태로 바꾸고 통과시킨다. 그 뒤의 task 는 이 테스트 파일을 고치지 않는다 —
  T5 · T6 은 명세 7-3 의 새 블록을 더하기만 한다(명세 7-1)
- T2 · T3 · T4 는 옛 배치에서 한다. 옮기기 전에 할 수 있는 일 — 다른 명령이 부르던 명령 진입 함수의 본문을 공용 함수로 떼기,
  인자 해석과 통과 표시, 컴파일 · 의존 방향 검사 — 을 먼저 해서 T5 의 커밋에 옮기기만 남긴다. T4 의 검사는 T5 가 만드는 패키지를
  첫 커밋부터 본다
- T3 은 T1 의 로더(`src/test/cli_loader.py`)로 옛 진입 스크립트를 불러 `parse_command_line()` 을 확인한다. 그 표를 고정하는 단위
  테스트(`test_cli.py`)는 T5 가 더한다 — 단위 테스트는 패키지를 불러오고, 옛 배치에는 패키지가 없다(명세 7-5)
- T4 와 T1 은 같은 `harness.toml` 의 `[verify]` 를 고친다. T1 뒤에 한다
- T5 는 나누지 않는다. `src/harness/__init__.py` 가 생기는 커밋부터 회귀 테스트의 로더가 패키지의 모듈만 보므로 정의 전부가 그 커밋에
  옮겨져야 한다. 설치본 케이스는 고정 사본의 진입 스크립트가 패키지를 찾아야 하므로 install 의 변경도 같은 커밋이다. 명세 7-5 의
  단위 테스트 두 파일과 검증 단계도 패키지가 생기는 커밋에 든다
- T5 의 진입 스크립트는 바이트코드를 쓰지 않는다(명세 2-2 의 2번 자리에서 `sys.dont_write_bytecode` 를 켠다). T6 이 그 자리를
  등록부 아래 캐시(명세 5절)로 바꾼다. 리포 밖에 쓰는 변경은 T6 하나다
- T7 · T8 · T9 는 코드가 만든 사실을 문서에 적는다. 셋은 서로 기대지 않는다. T9 는 보호 문서 task 이고 명세 9절 범위만 고친다

## 착수 순서와 다른 이슈

- **착수 조건: #96(리뷰 요청 #205)이 `develop` 에 머지된 뒤 착수한다.** 명세 3-2 의 모듈 지도가 #96 의 정의 — 클론 키 모듈 불러오기
  (`home/clone_key.py`), 클론 키 등록부(`home/registration.py`), 옛 이름 디렉터리 옮기기(`home/legacy.py`), `harness projects`
  (`commands/projects.py`) — 를 담는다. 지도의 이름은 `feat/96-machine-local-state-key` 브랜치 코드의 정의 이름과 같다
- **머지 조건: Homebrew 포뮬러를 먼저 바꾼다.** 탭 리포 `willjsw/homebrew-harness` 의 `Formula/harness.rb` 가 `libexec/harness/` 를
  깔고, `src/harness/` 가 없는 트리와 있는 트리 모두에서 설치되는 것을 사람이 확인한 뒤에 #206 구현 리뷰 요청을 `develop` 에
  머지한다. 이 변경이 든 `develop` 의 `main` 머지는 그 뒤다(명세 11절). 포뮬러는 이 리포 밖이라 task 가 아니다. 포뮬러가 그대로면
  이 변경이 든 `main` 을 받은 전역 CLI 와 그것을 부르는 UI 가 모든 명령에서 `error: cannot find the harness package` 로 멈춘다
- 후행 Requirement — #207 · #209 · #210 이 이 패키지 위에 착수한다. 이 이슈가 넘기는 인터페이스는 명세 3-2 의 모듈 지도, 명령 표
  (`src/harness/commands/__init__.py` 의 `COMMANDS`, 항목 `(통과, 설정이 필요한가, 인수, 설명)`)와 통과 명령의 인자 통과(3-3), 의존
  방향 검사(`script/project/check-cli.py imports`), 단위 테스트 자리(`src/test/unit/` 과 `[verify]` 의 "Python 단위 테스트")다
- 이 브랜치가 열려 있는 동안 `src/bin/harness` 나 `src/bin/harness_metrics.py` 를 고친 다른 리뷰 요청이 먼저 머지되면, `git fetch -p origin`
  뒤 `develop` 위로 rebase 하고 그 변경을 지도의 모듈로 옮겨 얹는다. rebase 뒤 push 는 사람이 한다
- `src/test/render-test.sh` 의 새 블록 번호는 착수 시점 최대 `UT-<번호>` 의 다음부터 매긴다 — 번호 중복은 회귀 테스트가 막는다

## 브랜치·리뷰 요청·커밋

- 브랜치: `refactor/206-split-cli-into-package` — 요구사항 이슈 #206 하나가 브랜치 하나·리뷰 요청 하나다. 태그는 요구사항 이슈
  제목의 태그(`refactor`)다
- 리뷰 요청 제목: `refactor: CLI 를 진입 스크립트와 패키지로 나누고 고정 사본을 패키지째 설치(#206)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #206` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 리뷰 요청 본문에 T1 이 바꾼 검사 줄마다 전후 대응표를 둔다(명세 7-1)
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #206`

## 전 task 공통 사항

- 모든 명령의 인자 · 표준 출력 · 표준 오류 · 종료 코드 · 대상 리포에 쓰는 파일이 그대로다. 다른 것은 고정 사본의 구성(명세 4절),
  바이트코드 위치(5절), 패키지를 찾지 못할 때의 오류(2-2)뿐이다. 같은 설정과 프로젝트 사실에서 같은 생성 파일이 나온다
- 실행 경로 셋(`src/bin/harness` · `.harness/bin/harness` · Homebrew 의 `bin/harness`)이 그대로다. 그래서 git 훅 · 검증 일괄 · CI ·
  권한 규칙 · UI 의 `HARNESS_BIN` 과 에이전트가 보는 명령 표기가 그대로다. 관리 스크립트(`src/templates/managed/script/`)와 그 셸
  표기는 옮기지 않는다
- CLI 는 소스 그대로 python3(3.11 이상)로 돈다. 표준 라이브러리만 쓰고 빌드 단계를 더하지 않는다
- 판정 기준은 `src/test/render-test.sh` 와 `src/ui/lib/doctor.test.js` 검사 줄의 기대값 — 종료 코드 · 출력 문자열 · 파일 상태 — 이다.
  기대값은 바꾸지 않는다. 준비부와 명세 7-2 표의 검사 줄은 T1 에서만 고친다
- CLI 패키지의 단위 테스트는 `src/test/unit/test_<대상>.py` 에 두고 `cd src && python3 -B -m unittest discover -s test/unit` 로 돈다.
  표준 라이브러리 `unittest` 만 쓰고 소스 리포에만 있다
- 회귀 테스트 · 단위 테스트 · 검사 · CLI 실행이 소스 트리와 설치본에 `__pycache__` 를 남기지 않는다
- `harness.toml` 을 고치면 `src/bin/harness render` 로 생성 파일(`script/harness-verify.sh` · `.ai/AI_AGENT.md` 등)을 갱신해 함께 커밋한다
- 출력 문구는 명세의 영어 원문 그대로 둔다. 새 블록의 터미널 출력에도 한글 검사를 적용한다
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록
  형식을 따른다. 배치가 바뀌어 틀리게 된 주석은 그 배치를 바꾸는 task 에서 고친다
- 커밋 전 `script/run-lint-test.sh --commit` 이 통과한다. push 전 검증이 회귀 테스트 전체를 돈다

## 이번 이슈에서 정하지 않는 값

- 명세 3-2 지도의 표에 없는 정의(도우미 함수 · 내부 상수)의 자리 — 명세는 "같은 책임의 모듈로 간다" 만 정한다
- `src/test/cli_loader.py` 의 내부 구현 — 명세 7-2 의 계약(`load()` · 이름 속성 · `module_of()` · 예외)만 정한다
- `script/project/check-cli.py` 의 `<규칙>` 칸 문장과 사용법 한 줄의 문구 — 명세 6절은 줄의 모양(`<경로>:<줄>: <규칙>`)과 종료 코드만 정한다
- `render-test.sh` 새 블록의 번호 — 착수 시점에 정한다

## 이번 이슈에서 다루지 않는 것

- Homebrew 포뮬러 변경 — 탭 리포에서 사람이 한다(명세 11절)
- 관리 스크립트의 이식과, 관리 스크립트가 스스로 바이트코드 쓰기를 끄는 것(`_clone_key.py` · `metric.py` · `run-agent.py`) — 명세 5-2
- 뒤의 Requirement 가 처음 만드는 디렉터리(`forge/` · `workflow/` · `steps/` · `guard/` · `registry/` 등)와 통과 명령 자체
- 함수 본문의 정리 · 긴 함수의 분할, doctor 출력의 절 이름 같은 외부 출력의 이름
- 바이트코드 캐시의 정리, 프로젝트 `.gitignore` 의 이름만 적은 규칙(`lib/` · `bin/`) 감지 — 명세 12절
