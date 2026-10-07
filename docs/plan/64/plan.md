# #64 분해 — CLI 모듈화와 리뷰 판정 데이터

명세: [`docs/spec/64-modularize-cli-review-scripts.md`](../../spec/64-modularize-cli-review-scripts.md)
결정 기록: [`docs/adr/0014-review-verdicts-are-structured-data.md`](../../adr/0014-review-verdicts-are-structured-data.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | fix | 회귀 테스트의 기록 경로를 테스트 작업 디렉터리로 격리 | 없음 |
| T2 | refactor | 리뷰 입력 구성의 내장 파이썬을 리뷰 루프 공용 모듈로 이동 | 없음 |
| T3 | feat | 리뷰 판정을 판정 데이터로 검증·집계하고 등록 댓글을 렌더링 | T2 |
| T4 | refactor | 지표 집계와 세션 가져오기를 지표 모듈로 분리 | T1 |
| T5 | refactor | 생성물 일치 판정을 drift 하나로 통합 | T4 |
| T6 | refactor | 역할 frontmatter 읽기를 role_meta 하나로 통합 | T5 |
| T7 | docs | 아키텍처·용어 문서에 지표 모듈과 판정 데이터 반영 | T3, T4 |

- T1 을 먼저 한다. 뒤의 task 가 회귀 테스트를 돌릴 때 기록이 실제 홈에 쌓이지 않는다
- T2 → T3 은 같은 공용 모듈(`_review.py`)을 이어 쌓는다. T2 는 `review-mr.sh` 쪽, T3 은 `post-review.sh` 쪽이다
- T3 은 리뷰어 출력 계약을 바꾼다. 스크립트·표지·역할 계약·절차 조각·회귀 테스트를 한 커밋에서 함께 바꾼다 —
  나눠 커밋하면 계약 문서와 검증이 서로 다른 형식을 요구하는 커밋이 생긴다
- T4 → T5 → T6 은 모두 `src/bin/harness` 와 `src/test/render-test.sh` 를 고친다. 충돌 없이 이어 쌓도록 이 순서로 한다
- T7 은 T3 · T4 가 만든 사실을 보호 문서에 적는다. 두 task 뒤에 한다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/64-modularize-cli-review-scripts` — 요구사항 이슈 #64 하나가 브랜치 하나·리뷰 요청 하나다.
  리뷰어 출력 계약이 바뀌는(T3) 변경이므로 태그는 `feat` 다
- 리뷰 요청 제목: `feat: CLI 모듈화와 리뷰 판정 데이터 도입(#64)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #64` 와 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #64`

## 전 task 공통 사항

- 관리 스크립트·역할 계약의 정본은 `src/templates/managed/` 아래, 절차 조각의 정본은 `src/templates/workflows/` 다.
  정본을 고친 뒤 `src/bin/harness render` 로 이 리포의 `script/` · `.ai/templates/` · `.ai/workflows/` 를 갱신하고,
  사본과 생성 파일을 손으로 고치지 않는다
- CLI 와 모듈은 표준 라이브러리만 쓴다. 새 외부 의존을 더하지 않는다
- 명세 1절대로, T3 이 바꾸는 리뷰어 출력 계약과 등록 댓글 본문 밖에서는 수행 결과가 같다. CLI 의 출력·종료 코드·파일,
  `review-mr.sh` · `post-review.sh` 의 인자·종료 코드, 회차 라벨, 반복 지적 누적 파일 형식, 리뷰 입력의 절 구성이 그대로다
- 제품의 기록 경로 해석(`script/metric.py` · `script/usage-log.sh`)을 바꾸지 않는다. 테스트는 `HOME` 을 바꾸지 않는다
- 주석과 테스트 이름에 이슈 번호·문서 번호·테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록 형식을 따른다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- 이미 실제 홈 아래에 생긴 지표·사용 기록 — 테스트와 스크립트가 지우지 않는다 (명세 10절)
- 긴 함수(`cmd_doctor` · `validate` · `metrics_report` · `derive`)의 분할, 지표 모듈 밖의 CLI 모듈 분리 (명세 8절)
- 커맨드 파일 frontmatter 를 읽는 `command_rows` (명세 9-2)
- 벤더 CLI 의 출력 스키마 강제 옵션 (명세 2-3)
