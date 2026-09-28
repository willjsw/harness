# #79 분해 — 같은 이름의 프로젝트 등록 거부

명세: [`docs/spec/79-reject-duplicate-project-name.md`](../../spec/79-reject-duplicate-project-name.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | install 이 다른 경로에 등록된 같은 이름을 거부하고 낡은 등록을 넘겨받음 | 없음 |
| T2 | feat | doctor 에 등록 상태 절과 UI 문구 추가 | T1 |
| T3 | docs | README 에 한 기기 한 클론과 등록 넘겨받기 안내 | T1 |
| T4 | docs | 아키텍처 문서에 설치 등록부의 이름 하나 경로 하나 반영 | T1 |

- T1 이 `src/bin/harness` 의 `register()` · `unregister()` · `cmd_install` 과 `src/test/render-test.sh` 의 새 `UT-62` 블록을 만든다.
  같은 이름으로 여러 리포를 설치하던 기존 케이스(명세 6-2)도 T1 에서 고친다 — 고치지 않으면 T1 커밋에서 회귀 테스트가 깨진다
- T2 는 T1 의 `UT-62` 블록에 doctor 케이스를 더하고, `cmd_doctor` · `src/ui/lib/doctor.js` · `doctor.test.js` 를 고친다
- T3 · T4 는 T1 이 만든 동작을 문서에 적는다. 둘은 서로 기대지 않는다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/79-reject-duplicate-project-name` — 요구사항 이슈 #79 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: 같은 이름의 프로젝트 등록 거부(#79)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #79` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #79`

## 전 task 공통 사항

- 등록부의 키 구조는 바꾸지 않는다 — `~/.harness/<이름>/project.json` 에 `{"path": "<하네스 루트>"}` 한 줄 (명세 1절)
- CLI 는 표준 라이브러리만 쓴다
- 회귀 테스트는 `HOME` 을 바꾸지 않고 `render-test.sh` 가 이미 두는 `HARNESS_HOME`(테스트 작업 디렉터리 아래)을 쓴다
- 출력 문구는 명세의 영어 원문 그대로 둔다. 터미널 출력에 한글이 없다
- 주석과 테스트 이름에 이슈 번호·문서 번호·테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록 형식을 따른다
- `register()` 위의 "나중에 설치한 쪽이 이긴다" 주석은 동작이 바뀌므로 T1 에서 지운다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- 등록부 키를 기기 로컬 값(경로·git 공통 디렉터리)으로 바꾸는 것 — 같은 리포의 두 번째 클론은 거부하고, 병렬 작업은 `harness run --worktree` 가 맡는다
- 넘겨받은 이름의 `~/.harness/<이름>/` 아래 옛 기록을 치우는 것, 등록이 지워진 이름의 디렉터리 정리 (명세 8절)
- `harness uninstall` 의 동작 변경
