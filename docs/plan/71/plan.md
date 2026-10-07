# #71 분해 — 이슈별 worktree 에서 절차 실행

명세: [`docs/spec/71-issue-worktree-run.md`](../../spec/71-issue-worktree-run.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | worktree 설정 절과 값 검증 추가 | 없음 |
| T2 | feat | harness run --worktree 로 이슈별 worktree 생성·다시 열기·정리 | T1 |
| T3 | feat | 새 worktree 에 로컬 파일 복사와 worktree 안의 가드·훅 확인 | T2 |
| T4 | feat | run 스팬의 worktree 식별자와 세션 가져오기의 worktree 귀속 | T2 |
| T5 | feat | doctor 에 남아 있는 이슈 worktree 보고 | T2 |
| T6 | feat | 반복 지적 이력을 git 공통 디렉터리로 이동 | 없음 |
| T7 | feat | 되감기에서 다른 worktree 가 체크아웃한 브랜치 남김 | 없음 |
| T8 | docs | 아키텍처·용어·담당 범위 문서에 이슈 worktree 반영 | T3, T4, T5, T6, T7 |

- 구현은 #64 의 구현 리뷰 요청이 `develop` 에 머지된 뒤 시작한다. 브랜치는 그 뒤의 `origin/develop` 에서 만든다.
  세션 가져오기 함수(`import_claude` · `import_codex` · `metrics_import`)는 #64 가 `src/bin/harness_metrics.py` 로 옮긴다.
  task 는 함수 이름으로 적고, 함수가 있는 파일을 따라간다
- T1 → T2 → T3 은 `src/bin/harness` 의 설정·`cmd_run` 과 `src/test/render-test.sh` 를 이어 쌓는다
- T2 가 만드는 worktree 상태 판정 함수(미커밋 변경·미push 커밋)를 T5 가 함께 쓴다. T4 는 T2 의 `cmd_run` 에 스팬 속성을 더한다
- T4 와 T5 는 서로 기대지 않는다. 둘 다 `render-test.sh` 를 고치므로 한 번에 하나씩 커밋한다
- T6 · T7 은 관리 스크립트만 고친다. CLI task 와 순서를 바꿔도 된다
- T8 은 T3 ~ T7 이 만든 사실을 보호 문서에 적는다. 마지막에 한다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/71-issue-worktree-run` — 요구사항 이슈 #71 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: 이슈별 worktree 에서 절차 실행(#71)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #71` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #71`

## 전 task 공통 사항

- 관리 스크립트의 정본은 `src/templates/managed/script/` 다. 정본을 고친 뒤 `src/bin/harness render` 로 이 리포의
  `script/` 사본을 갱신하고, 사본과 생성 파일을 손으로 고치지 않는다
- CLI 와 모듈은 표준 라이브러리만 쓴다. 지표 모듈은 `src/bin/harness` 를 import 하지 않고 CLI 의 값을 인자로 받는다
- `--worktree` 가 없으면 `harness run` 의 동작과 run 스팬 속성이 지금과 같다 (명세 1절)
- worktree 경로·`worktree.dir` 값·`include` 로 복사한 파일의 경로와 내용을 스팬·사용 기록에 남기지 않는다
- 회귀 테스트는 `HOME` 을 바꾸지 않는다. `worktree.dir` 은 `harness set` 으로 테스트 작업 디렉터리 아래에 두고,
  원격은 로컬 bare 리포, 오케스트레이터는 PATH 앞에 둔 페이크 실행 파일이다 (명세 9절)
- 주석과 테스트 이름에 이슈 번호·문서 번호·테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록 형식을 따른다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- 같은 `project.name` 을 쓰는 프로젝트의 등록 차단 — #79 가 다룬다
- 포트·DB 같은 실행 자원의 분리, 같은 이슈 worktree 에서 동시에 도는 두 실행의 막기 (명세 11절)
- `harness uninstall` 이 남은 worktree 를 지우는 것 (명세 11절)
- `harness run` 을 켜고 끄는 설정 키 — 켜는 수단은 `--worktree` 하나다 (명세 2절)
