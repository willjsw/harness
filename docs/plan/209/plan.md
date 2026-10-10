# #209 분해 — forge 어댑터의 Python 패키지 이식

명세: [`docs/spec/209-port-forge-adapters.md`](../../spec/209-port-forge-adapters.md)
결정 기록: 없음

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | chore | forge 회귀 테스트의 어댑터 내부 이름 의존을 계약 함수와 PATH 앞 CLI 스텁으로 교체 | 없음 |
| T2 | refactor | forge 어댑터 계약 함수 표와 정규화 dataclass 모듈 추가 | T1 |
| T3 | refactor | GitHub 어댑터를 Python 모듈로 이식 | T2 |
| T4 | refactor | GitLab 어댑터를 Python 모듈로 이식 | T3 |
| T5 | refactor | Jira 어댑터를 Python 모듈로 이식 | T3 |
| T6 | feat | forge 어댑터 선택 · 계약 함수 호출과 HARNESS_FORGE_FAKE 셸 구현 | T4, T5 |
| T7 | feat | harness forge 로 계약 함수 하나 호출 | T6 |
| T8 | feat | doctor 의 어댑터 판정과 원격 forge 호출을 Python 어댑터로 전환하고 forge fake 경고 추가 | T7 |
| T9 | refactor | script/forge.sh 를 계약 표에서 생성하는 harness forge shim 으로 전환 | T7 |
| T10 | feat | 자체 검사를 harness forge-selftest 로 이식하고 script/forge-selftest.sh 를 shim 으로 전환 | T9 |
| T11 | refactor | harness forge-setup 이 라벨을 직접 준비하고 script/forge-setup.sh 를 shim 으로 전환 | T10 |
| T12 | refactor | 셸 어댑터 파일 제거와 대상 리포 script/forge/ 정리 | T8, T11 |
| T13 | feat | UI doctor 문구의 어댑터 파일 없음 분기 제거와 forge fake 경고 추가 | T8 |
| T14 | docs | README 와 명세 59 · 60 에 Python forge 어댑터 반영 | T12 |
| T15 | docs | 아키텍처 · 용어 · 담당 범위 · 테스트 문서에 Python forge 어댑터 반영 | T12 |
| T16 | docs | GitHub 어댑터의 자체 검사 전 단계 통과 기록 | T12, T14 |

- T1 은 제품 코드를 고치지 않는다. 명세 8-2(묶음 A)의 세 테스트를 **지금의 셸 어댑터에서** 통과시킨다. 뒤의 task 는 이 줄을 기대값 그대로 둔 채
  이식한다
- T2 ~ T6 은 `src/harness/forge/` 를 쌓는다 — 계약(T2), 어댑터 셋(T3 · T4 · T5), 선택과 호출 · 셸 구현(T6). 이 다섯 task 동안 셸 호출부 ·
  doctor · 자체 검사 · 라벨 준비는 아직 셸 어댑터를 탄다. 새 코드는 단위 테스트로만 확인된다
- T3 이 기본 실행기와 세 어댑터가 함께 쓰는 도우미를 처음 두고 T4 · T5 가 그것을 쓴다. T4 와 T5 는 서로 기대지 않는다
- T7 이 첫 진입점 `harness forge` 를 더한다. T8 · T9 · T10 · T11 이 doctor · `script/forge.sh` · 자체 검사 · 라벨 준비를 차례로 Python 어댑터로
  옮긴다. 명세 8-3(묶음 B)의 바꾸는 줄은 그 줄을 거짓으로 만드는 task 에 든다 — 아래 표
- T12 가 셸 어댑터 파일을 마지막에 지운다. 그때는 그 파일을 읽거나 source 하거나 가리키는 코드 · 출력이 남아 있지 않다 — doctor 의 판정(T8),
  `script/forge.sh`(T9), 자체 검사의 머리글과 끝 안내(T10)
- T13 은 CLI 가 `file is missing` 을 더 내지 않는 T8 뒤에 UI 문구를 맞춘다
- T14 · T15 는 코드가 끝난 뒤의 사실을 적는다. T15 가 명세 10절의 보호 문서를 고치는 유일한 task 다
- T16 은 실제 forge 로 자체 검사를 돌린 결과를 한 커밋에 적는다(명세 9절). 묶음 B 가 끝난 T12 뒤에 돌리고, README 를 함께 고치는 T14
  뒤에 커밋한다

묶음 B 의 바꾸는 줄과 task:

| 테스트 | task | 그 task 에서 바뀌는 까닭 |
|---|---|---|
| UT-79 의 표지를 세는 범위 · UT-83 의 "CLI 가 forge CLI 를 직접 부르지 않는다" 범위 | T2 | `src/harness/forge/` 가 생기고 그 안에 표지 문자열(계약 머리글)과 forge CLI 이름(어댑터)이 들어온다 |
| UT-79 의 나머지 · UT-83 의 페이크 주입 | T8 | doctor 가 어댑터 모듈의 머리글을 읽고 원격 forge 호출을 `harness forge` 로 띄운다 |
| UT-11 · UT-33 | T9 | `script/forge.sh` 가 어댑터 파일을 source 하지 않는다 |
| UT-16 · UT-81 의 페이크 주입 | T10 | 자체 검사가 `script/forge.sh` 를 거치지 않는다 |
| UT-98 · `test-forge-setup.sh` | T11 | 라벨 준비가 CLI 로 가고 실행 방향이 스크립트 → CLI 가 된다 |
| UT-63 · UT-81 의 어댑터 파일 grep · `test-forge-labels.sh` 의 전제와 로더 | T12 | 셸 어댑터 파일이 없어진다 |

## 착수 순서와 다른 이슈

- **착수 조건: #206 이 `develop` 에 머지된 뒤 착수한다.** 이 분해는 #206 명세의 모듈 지도와 통과 명령 · 단위 테스트 기반 위에 선다
  - 모듈 자리: doctor 항목과 `adapter_header` · `ADAPTER_UNVERIFIED` 는 `src/harness/readiness/items.py`, `remote_call()` · `forge_call` 은
    `src/harness/readiness/remote.py`, 셸 생성물은 `src/harness/render/scripts.py`, `ALLOW_EXCLUDED` 는 `src/harness/render/settings.py`,
    명령 표 `COMMANDS` 는 `src/harness/commands/__init__.py`, `DELEGATES` · `delegate()` 는 `src/harness/cli.py`, 실행 위치 `ENTRY` ·
    `PACKAGE` 는 `src/harness/base.py`, 라벨 준비 명령은 `src/harness/commands/forge_setup.py`
  - 통과 명령: #206 3-3 의 "인자 통과". 명령 표 항목은 `(통과, 설정이 필요한가, 인수, 설명)` 이다
  - 단위 테스트: 자리 `src/test/unit/`, 실행 `cd src && python3 -B -m unittest discover -s test/unit`, 검증 단계 "Python 단위 테스트"
    (`paths` 에 `src/harness/**` · `src/templates/**` · `src/test/**`). 이 이슈는 `[verify]` 를 고치지 않는다
  - 회귀 테스트의 CLI 원문 범위와 프로세스 안 호출 로더(`src/test/cli_loader.py`)는 #206 7-2 다
- **T15 는 #207 이 `develop` 에 머지된 뒤 커밋한다.** 명세 10절의 적용 순서가 #206 → #207 → #208 · #209 · #210 이고, 문안이 #207 이 고친
  "계층과 의존 방향" 문장과 용어 "공유 설정" 위에 더하는 것이기 때문이다
- #207 은 그 밖의 task 의 선행이 아니다. 명령이 읽는 설정은 명령 표의 설정 필요 표시로 `main()` 이 읽고 검증해 넘긴 설정이다 — 명세의
  "공유 설정" 은 그 설정이고, 이 이슈는 설정 읽기를 따로 두지 않는다
- **#210 과 병렬이다.** `src/harness/format.py`(`markers()` · `FormatError`)는 둘 가운데 먼저 머지되는 쪽이 명세 2-1 의 정의로 만든다.
  T10 착수 시점에 `develop` 에 그 모듈이 있으면 그것을 쓰고 고치지 않는다. 없으면 T10 이 만들고 `test_format.py` 를 함께 둔다. 두 이슈는
  `COMMANDS` · `DELEGATES` · `render-test.sh` 를 함께 고쳐 병합 충돌이 날 수 있다. 동작은 서로 기대지 않는다
- 먼저 머지된 쪽 위로 `git fetch -p origin` 뒤 `develop` 위로 rebase 한다. rebase 뒤 push 는 사람이 한다
- 후행 이슈가 쓰는 것
  - #211 · #212 · #213 — `harness.forge` 의 `load()` · `Forge`(정규화 dataclass 를 돌려주는 메서드)와 페이크 주입 지점 `HARNESS_FORGE_FAKE`,
    shim 의 공통 형태(명세 3-3), 용어 `shim`
  - #213 — 표지 정본을 `format.py` 로 옮긴다. #215 — 자체 검사 자리 `src/harness/forge/selftest.py`
  - #221 — shim 셋(`script/forge.sh` · `script/forge-selftest.sh` · `script/forge-setup.sh`)과 `test-forge-labels.sh` · `test-forge-setup.sh` 를
    걷는다. 그때까지 에이전트가 보는 표기(`. script/forge.sh` · `script/forge-selftest.sh`)는 그대로다
- 새 `render-test.sh` 블록(명세 8-4)은 T7 이 하나를 만들고 T8 ~ T12 가 케이스를 더한다. 번호는 T7 착수 시점의 최대 `UT-<번호>` 다음이다 —
  번호 중복은 회귀 테스트가 막는다

## 브랜치 · 리뷰 요청 · 커밋

- 브랜치: `refactor/209-port-forge-adapters` — 요구사항 이슈 #209 하나가 브랜치 하나 · 리뷰 요청 하나다. 태그는 이슈 제목의 `refactor`
- 리뷰 요청 제목: `refactor: forge 어댑터를 Python 패키지로 이식(#209)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #209` 와 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #209`
- 구현 리뷰 요청 본문에 더할 것
  - 명세 8-2 · 8-3 의 바꾼 줄마다 옛 줄 → 새 줄 대응표 (T1 · T2 · T8 ~ T12)
  - 명세 9절의 기록 — 자체 검사 판정 줄(`pass · fail · skip`) 둘(읽기 · `--create-issue`), 그 실행의 gh 버전, 만들어진 이슈 번호 (T16)
  - `HARNESS_FORGE_FAKE` 주입 지점(T6 · T7 · T8)의 security-guard 검토 결과와 반영 여부(명세 4-4). security-guard 는 명시 호출 전용이라
    리뷰 요청 전에 사람이 `/security-guard` 로 부른다

## 전 task 공통 사항

- 외부 계약은 바뀌지 않는다(명세 1절) — 계약 함수 24개의 이름 · 인자 · 표준 출력 · 종료 코드, 정규화 JSON, 자체 검사와 라벨 준비의 명령줄 ·
  출력 · 종료 코드, doctor 항목 문구, 에이전트가 보는 명령 표기, 권한 허용 목록과 `ALLOW_EXCLUDED`, GitLab · Jira 의 미검증 표기.
  `src/templates/managed/.ai/templates/developer.md` 는 고치지 않는다
- 오라클(명세 8-1)은 기존 셸 테스트 검사 줄의 기대값이다 — `render-test.sh` 의 UT-11 · UT-16 · UT-33 · UT-63 · UT-79 · UT-81 · UT-83 · UT-98 ·
  UT-99 · UT-100, `test-forge-labels.sh` · `test-forge-setup.sh`, 셸 호출부 테스트(`test-review-loop.sh` · `test-work-preflight.sh` ·
  `test-sync-task-issues.sh` · `test-carryover-issue.sh` · `test-rollback-work.sh`)
  - 고칠 수 있는 줄은 준비부 · 로더 · 내부 구조 단언 · 실행 방향 단언 넷뿐이고, 명세 8-2 · 8-3 의 표에 든 줄만 고친다. 기대값은 바꾸지 않는다
  - UT-99 · UT-100 과 셸 호출부 테스트는 고치지 않고 모든 task 뒤에 그대로 통과한다
  - 페이크의 계약 위반 11종(UT-16 의 9종 · UT-81 의 2종)마다 자체 검사가 1 로 끝나는 검사가 모든 task 뒤에 남는다
- Python 단위 테스트는 `src/test/unit/test_forge_*.py` · `test_format.py` 다. CLI 를 하위 프로세스로 띄우지 않는다. 어댑터는 생성자의 실행기를
  바꿔 끼우고, 셸 구현과 표지 비교는 임시 디렉터리의 셸 파일에 `sh` 를 띄워 본다(명세 8-5)
- CLI 패키지는 python3 표준 라이브러리만 쓴다
  - 모듈 최상위에서 `urllib` 을 불러오지 않는다 — 경로 인코딩의 `urllib.parse` 도 쓰는 함수 안에서 불러온다(#206 3-4 의 의존 방향 검사)
  - `src/harness/commands/__init__.py` 는 `harness.forge` 를 불러오지 않는다. 명령 모듈만 불러온다
  - `gh` · `glab` · `jira` 를 부르는 코드는 `src/harness/forge/` 뿐이다
- 페이크 주입: 테스트는 `HARNESS_FORGE_FAKE` 를 명령 하나의 환경에만 주고 테스트 전체에 내보내지 않는다. 하네스 · 생성 파일 · CI 설정은
  이 값을 설정하지 않는다. 값은 어떤 출력에도 옮기지 않는다(명세 4-2 · 4-4)
- `src/harness/forge/github.py` 머리글은 T3 부터 T16 전까지 `검증 상태: 미검증` 이다(명세 9-1). T8 부터 github 설정의 doctor 가
  `adapter github` 를 `warn` 으로 낸다 — 기대값을 바꾸지 않는다
- 관리 스크립트 · 템플릿의 정본은 `src/templates/` 아래다. 정본을 고친 뒤 `src/bin/harness render` 로 이 리포의 `script/` · `.ai/` ·
  `docs/workflow/` · `.harness/generated` · `.harness/managed` 를 갱신해 같은 커밋에 넣는다. 생성 파일과 사본을 손으로 고치지 않는다
- 출력 문구는 명세의 영어 원문 그대로 둔다. 새 블록의 터미널 출력에도 한글 검사를 적용한다
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다. 동작이 바뀌어 틀리게 된 주석과 문서 문장은 그 동작을 바꾸는
  task 에서 고친다. `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록 형식을 따른다
- 커밋 전 `script/run-lint-test.sh` 전부가 통과한다. 이 리포의 커밋 단계 검증(`--commit`)은 `render-test.sh` 를 돌리지 않으므로, 오라클
  확인을 위해 push 단계까지 돈다

## 이번 이슈에서 정하지 않는 값

- 기본 실행기(subprocess)와 세 어댑터가 함께 쓰는 도우미(0600 본문 임시 파일 · JSON 직렬화)를 두는 모듈 — 명세 2-1 의 모듈 표 안에서
  고른다
- 어댑터의 트래커 군 · 리뷰 호스트 군 클래스 이름과 `Forge` 가 두 군에 맡기는 방식
- `script/forge.sh` 본문을 만드는 함수의 이름 — 자리는 #206 지도의 셸 생성물 모듈 `src/harness/render/scripts.py` 다
- `harness forge` 인수 개수 오류 `error: <함수> takes <인자 목록>` 의 인자 목록 표기 — 계약 함수 표의 인자 이름에서 만든다
- 새 `render-test.sh` 블록의 번호

## 이번 이슈에서 다루지 않는 것

- GitHub `review_mr_threads` 가 두 조회의 실패를 종료 코드로 알리게 하는 것 — 외부 동작 변경이다(명세 11절)
- 셸 호출부(`review-mr.sh` · `post-review.sh` · `work-preflight.sh` · `check-open-mrs.sh` · `sync-task-issues.sh` · `create-carryover-issue.sh` ·
  `rollback-work.sh`)의 이식 — #211 · #213 이 맡는다. 호출마다 Python 프로세스가 하나 뜨는 비용도 그때 없어진다
- shim 셋과 `test-forge-labels.sh` · `test-forge-setup.sh` 의 제거 — #221
- 명령 가드가 `HARNESS_FORGE_FAKE` 를 보는 것
- GitLab · Jira 어댑터의 실제 forge 검증
- 어댑터 단위 테스트를 대상 리포로 보내는 것 — 단위 테스트는 소스 리포에서만 돈다
