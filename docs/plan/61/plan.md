# #61 분해 — UI 서버의 백그라운드 기동·상태 확인·중지

명세: [`docs/spec/61-start-server-background.md`](../../spec/61-start-server-background.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | UI 빌드 판정과 서버 기록·상태 판정 함수 추가 | 없음 |
| T2 | feat | stop-server 와 server-status 명령 추가 | T1 |
| T3 | feat | start-server 가 필요할 때 빌드하고 백그라운드로 기동 | T1, T2 |
| T4 | feat | 없는 프로젝트 화면이 404 를 반환 | 없음 |
| T5 | docs | README 에 백그라운드 UI 서버와 중지·상태 명령 안내 | T3 |
| T6 | docs | 아키텍처·담당 범위 문서에 UI 서버 기동 흐름과 명령 반영 | T3 |

- T1 이 `src/bin/harness` 에 판정 함수 다섯(`ui_source_hash` · `needs_build` · `parse_server_record` · `process_matches` · `server_state`)과
  `src/test/render-test.sh` 의 새 UT 블록을 만든다. 이 블록이 이 이슈의 회귀 테스트 전부다
- T2 는 T1 의 함수로 두 명령을 만들고, 프로세스 그룹 중지 절차(명세 6-2)를 함수 하나로 둔다. T3 의 기동 실패 정리가 그 함수를 쓴다
- T3 는 `cmd_start_server` 를 백그라운드 기동과 `--dev` 로 나눈다
- T4 는 `src/ui/` 만 건드리고 CLI 와 기대지 않는다
- T5 · T6 은 T3 까지의 동작을 문서에 적는다. 둘은 서로 기대지 않는다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/61-start-server-background` — 요구사항 이슈 #61 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: start-server 의 백그라운드 기동과 상태 확인·중지(#61)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #61` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #61`

## 전 task 공통 사항

- CLI 는 표준 라이브러리만 쓴다. 포트 연결은 `socket`, HTTP 는 `urllib.request`, 프로세스 그룹은 `os.killpg`
- `ui.pid` · `ui.log` 는 `registry()`(`HARNESS_HOME`, 없으면 `~/.harness/`) 최상위에 두고 권한은 0600 이다 (명세 1절)
- 판정 함수는 파일·소켓·`ps` 를 직접 부르지 않고 그 결과를 인자로 받는다. 부르는 쪽이 명령 함수다
- 출력 문구는 명세의 영어 원문 그대로 둔다. 터미널 출력에 한글이 없다
- 실제 기동·응답 대기·중지는 자동 테스트하지 않는다 (명세 8절). 그 경로의 완료 조건은 손으로 확인한다
- 새 UT 블록 번호는 구현 시점에 `render-test.sh` 에 없는 다음 번호로 매긴다. 번호 중복은 회귀 테스트가 막는다
- 주석과 테스트 이름에 이슈 번호·문서 번호·테스트 항목 ID 를 넣지 않는다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- 여러 `start-server` 를 동시에 돌리는 경우 (명세 1절)
- 포트 `7777` 을 설정으로 바꾸는 것, 루프백 밖에 묶는 것
- `stop-server` 가 기록 없이 포트를 쓰는 프로세스를 찾아 멈추는 것 (명세 6-1)
- `ui.log` 의 누적·순환 — 기동할 때마다 비운다
- `src/ui/package.json` 의 스크립트 변경 — CLI 가 `node_modules/.bin/next` 를 직접 부른다
