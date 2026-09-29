# #59 분해 — doctor 의 원격 준비 점검과 구조화된 결과

명세: [`docs/spec/59-doctor-remote-readiness.md`](../../spec/59-doctor-remote-readiness.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | refactor | doctor 점검을 항목 목록 수집과 텍스트 렌더로 나누고 status 가 그 목록을 씀 | 없음 |
| T2 | feat | doctor --json 출력 추가 | T1 |
| T3 | fix | 자리표시자·어댑터 미검증 판정을 정해진 표지로 좁힘 | T1 |
| T4 | feat | 벤더 auth_check 선언과 run-agent.py --check 러너 준비 확인 추가 | 없음 |
| T5 | feat | forge 읽기 함수 넷과 자체 검사·페이크 추가 | 없음 |
| T6 | feat | doctor --remote 와 origin·base·원격 기본 브랜치 점검 추가 | T2 |
| T7 | feat | doctor --remote 에 forge 로그인·라벨·브랜치 보호 점검 추가 | T5, T6 |
| T8 | feat | doctor --remote 에 리뷰어 러너 점검 추가 | T4, T6 |
| T9 | feat | UI Doctor 에 원격 점검 버튼과 원격 절 문구 추가 | T6, T7, T8 |
| T10 | docs | README 와 스크립트 표에 원격 점검·러너 준비 확인·자체 검사 종수 반영 | T5, T9 |
| T11 | docs | 아키텍처 문서에 doctor 결과 목록과 원격 점검 입력 반영 | T8 |

- T1 이 `cmd_doctor` 를 출력하지 않는 수집 함수와 텍스트 렌더로 나누고 `cmd_status` 의 정규식 파싱을 없앤다.
  출력은 바이트 단위로 지금과 같다. T2 · T3 · T6 은 그 수집 함수와 렌더 위에 쌓는다
- T3 은 T1 이 옮긴 `project facts` · `tools and connections` 점검의 판정 조건만 바꾼다
- T4 는 `src/templates/vendors.toml` · `run_plan()` · `run-agent.py` 만, T5 는 `script/forge/` · `forge-selftest.sh` · `fake-forge.sh` 만 고친다.
  CLI task 와 순서를 바꿔도 된다
- T6 이 `--remote` 인자와 `remote` 절, 원격 호출 공통 규칙(제한 시간·표준 입력·`GIT_TERMINAL_PROMPT`·출력 비전달)을 만든다.
  T7 · T8 은 그 절에 항목을 더하고 같은 공통 규칙을 쓴다. T7 과 T8 은 서로 기대지 않는다
- T9 는 `harness status --remote` 가 `remote` 절 항목 전부를 낼 때 UI 를 붙인다
- T10 은 T5 ~ T9 가 만든 동작을 사람용 문서에 적는다
- T11 은 보호 문서(`.ai/project/architecture.md`) 수정이다. 사람이 지시한 턴에서만 한다

## 다른 이슈와의 순서

- #59 의 구현은 #58 · #60 · #62 의 구현보다 먼저 한다
  - doctor 결과 목록(수집 함수와 항목 구조)이 #58 의 doctor 절 추가의 기반이다
  - `run-agent.py --check` 가 #60 의 착수 전 러너 점검이 부르는 진입점이다
  - `harness status` 의 목록 사용과 `--remote` 전달이 #62 의 UI 정리의 기반이다
- 구현 브랜치는 이 분해의 리뷰 요청이 `develop` 에 머지된 뒤의 `origin/develop` 에서 만든다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/59-doctor-remote-readiness` — 요구사항 이슈 #59 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: doctor 가 원격 준비 상태를 점검하고 구조화된 결과를 낸다(#59)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #59` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #59`

## 전 task 공통 사항

- 관리 스크립트의 정본은 `src/templates/managed/script/` 다. 정본을 고친 뒤 `src/bin/harness render` 로 이 리포의
  `script/` 사본과 생성 파일을 갱신하고, 사본과 생성 파일을 손으로 고치지 않는다
- CLI 는 표준 라이브러리만 쓴다
- `--remote` 가 없으면 doctor 는 네트워크에 닿지 않는다. doctor 의 텍스트 한 줄 형식 · 절 제목 · 요약 줄 · 종료 코드와
  `harness status` 의 JSON 키 구조는 바꾸지 않는다 (명세 1절)
- 원격 점검은 읽기 전용이다. 라벨 · 브랜치 보호 · 원격 설정을 만들거나 바꾸지 않는다
- 원격 URL 과 git · forge CLI · 러너 CLI 의 출력을 `what` · `detail` · 실행 지표에 옮기지 않는다 (명세 4-1)
- CLI 출력 문구는 명세의 영어 원문 그대로 둔다. 터미널 출력에 한글이 없다. UI 문구는 명세 7절의 한국어 원문 그대로 둔다
- 회귀 테스트는 task 마다 `render-test.sh` 에 새 `UT-<번호>` 블록을 연다. 번호는 그 시점의 다음 빈 번호이고, 새 블록의 출력에도
  터미널 출력 한글 검사를 적용한다. 원격은 테스트 작업 디렉터리 아래의 bare 리포, forge 는 `fake-forge.sh`, 러너는 `PATH` 의 스텁이다.
  실제 네트워크에 닿지 않는다
- doctor 의 텍스트를 읽는 기존 케이스와 `status` 를 읽는 기존 케이스는 문구를 바꾸지 않고 통과한다 (명세 9-3)
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- 원격 점검을 기본으로 켜는 것과 UI 홈 · 사이드바의 원격 점검 — 원격 점검은 `harness doctor --remote` · `harness status --remote` 와
  Doctor 화면의 버튼으로만 돈다
- 라벨 · 브랜치 보호를 만들거나 고치는 것 (명세 1절)
- 로그인은 되어 있으나 권한이 부족한 계정, 회차 라벨의 점검 (명세 11절)
- `auth_check` 를 선언하지 않은 벤더의 인증 확인 — 설치만 본다
- `gitlab.sh` · `jira.sh` 를 실제 forge 로 검증하는 것 — 머리글의 `검증 상태: 미검증` 을 유지한다
- 명세의 확인 필요 값 둘 — API 키 환경 변수로만 인증한 상태에서 `claude auth status` · `codex login status` 의 종료 코드,
  네트워크 없이 도는 상태에서 `gh auth status` 의 종료 코드. 구현은 명세의 종료 코드 계약(0 이면 로그인, 0 이 아니면 미로그인)대로 한다
