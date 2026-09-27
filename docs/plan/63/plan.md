# #63 분해 — 사용 기록의 브랜치 유형을 설정 값으로 분류

명세: [`docs/spec/63-usage-log-config-values.md`](../../spec/63-usage-log-config-values.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | fix | 사용 기록의 브랜치 유형을 설정 값으로 분류 | 없음 |
| T2 | fix | 설정을 읽지 못하면 사용 기록을 남기지 않고 종료 | T1 |

T2 는 T1 과 같은 두 파일(`usage-log.sh` · `test-usage-log.sh`)을 고친다. 충돌 없이 이어 쌓도록 T1 다음에 한다.

## 브랜치·리뷰 요청·커밋

- 브랜치: `fix/63-usage-log-config-values` — 요구사항 이슈 #63 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #63` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `fix: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #63`

## 전 task 공통 사항

- 정본은 `src/templates/managed/script/usage-log.sh` · `src/templates/managed/script/test-usage-log.sh` 다.
  정본을 고친 뒤 `src/bin/harness render` 로 이 리포의 `script/` 사본을 갱신하고, 사본을 손으로 고치지 않는다
- 판정 값은 `script/harness.env` 에서만 받는다. 기록기와 테스트 본문에 브랜치 이름·태그 이름을 적지 않는다
- 새 설정 변수를 더하지 않는다. 기존 `PROTECTED_BRANCHES` · `COMMIT_TAGS` 를 쓰므로 생성물은 바뀌지 않는다
- 기록 한 줄의 형식(필드 5개)과 `script/usage-report.sh` 는 바꾸지 않는다
- 회귀 테스트는 원격을 부르지 않고 임시 디렉터리에서 돈다. 이 리포의 `script/harness.env` 를 지우거나 옮기지 않는다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 정하지 않는 값

- 이미 남은 사용 기록의 브랜치 유형 이관 — 대상이 아니다 (명세 4절)
