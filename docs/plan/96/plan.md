# #96 분해 — 기기 단위 상태의 클론 키

명세: [`docs/spec/96-machine-local-state-key.md`](../../spec/96-machine-local-state-key.md)
결정 기록: [`docs/adr/0016-machine-local-state-is-keyed-by-clone.md`](../../adr/0016-machine-local-state-is-keyed-by-clone.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | 클론 키 공용 모듈과 project.name 의 키 형식 거부 | 없음 |
| T2 | feat | 지표·사용 기록·worktree 경로의 자리표시를 실행할 때 클론 키로 풀기 | T1 |
| T3 | feat | 옛 자리표시 {project} 를 render 와 doctor 가 안내 | T2 |
| T4 | feat | 설치 등록부를 클론 키로 나누고 같은 이름은 알리기만 함 | T2 |
| T5 | feat | harness projects 로 등록된 클론 목록을 JSON 으로 냄 | T4 |
| T6 | feat | 옛 이름 디렉터리의 기록을 install 과 render 가 클론 키 아래로 옮김 | T2, T4 |
| T7 | feat | UI 가 harness projects 로 목록을 받고 클론 키로 라우트 | T5 |
| T8 | feat | UI Doctor 문구를 클론 키 등록 판정과 옛 자리표시에 맞춤 | T3, T4, T6 |
| T9 | docs | README 에 클론마다 따로인 등록과 기록, harness projects 안내 | T5, T6, T7 |
| T10 | docs | 용어·아키텍처 문서에 클론 키와 등록부 구조 반영 | T4, T6 |

- T1 이 `script/_clone_key.py`(정본 `src/templates/managed/script/_clone_key.py`)를 만든다. 뒤의 모든 코드 task 가 이 모듈 하나로 키를 얻는다
- T2 는 경로 계산(`metrics_cfg()` · `worktree_dir()` · `metric.py` · `usage-log.sh` · `usage-report.sh` · 가져오기 커서)을, T4 는 등록부를 바꾼다. T4 의 두 클론 공존 케이스가 기록 경로의 분리까지 확인하므로 T2 뒤에 온다. T3 과 T4 는 서로 기대지 않는다
- T4 는 doctor `registry` 절의 판정을 새 등록부로 옮긴다 — 등록부 형식과 그 형식을 읽는 판정이 한 커밋에서 바뀌어야 회귀 테스트가 깨지지 않는다. 옛 이름 디렉터리를 알리는 `registry` 줄은 옮기기가 생기는 T6 이 더한다
- T5 는 CLI 의 읽기 전용 명령이고, UI(T7)는 그 출력만 읽는다. UI → CLI 방향만 생긴다
- T8 은 CLI 가 내는 줄(T3 · T4 · T6)이 확정된 뒤 UI 문구를 한 번에 맞춘다
- T9 · T10 은 코드가 만든 동작을 문서에 적는다. 둘은 서로 기대지 않는다

## 착수 순서와 다른 이슈

- **#59 와 #62 가 `develop` 에 머지된 뒤 착수한다.** #59 는 doctor 결과 목록 구조(`{section, state, what, detail}` 항목을 내는 수집 함수)를,
  #62 는 `src/ui/lib/harness.js` 의 쓰기·경로 정리를 만든다. T3 · T4 · T6 의 doctor 항목은 #59 의 수집 함수에, T7 은 #62 뒤의
  `harness.js` 에 얹는다
- #60 · #61 과는 같은 파일(`src/bin/harness` 의 `cmd_install` · `COMMANDS`, `README.md`, `src/ui/lib/`)을 건드려 병합 충돌이 날 수 있다.
  동작은 서로 기대지 않는다. 먼저 머지된 쪽 위로 `git fetch -p origin` 뒤 rebase 한다
- 착수 시점의 `src/test/render-test.sh` 최대 `UT-<번호>` 가 74 를 넘었으면 새 블록 번호(명세 8-1 의 UT-75 ~ UT-79)를 그 다음부터 매긴다 —
  번호 중복은 회귀 테스트가 막는다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/96-machine-local-state-key` — 요구사항 이슈 #96 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: 기기 단위 상태를 클론 키로 나눔(#96)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #96` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #96`

## 전 task 공통 사항

- CLI 와 대상 리포 스크립트는 python3 표준 라이브러리만 쓴다. `_clone_key.py` 는 바이트코드를 남기지 않는다
- 클론 키는 템플릿 변수(`derive()`)에 넣지 않는다. 생성 파일에 키가 들어가지 않는다
- 키를 계산하는 코드는 `_clone_key.py` 하나다. CLI · `metric.py` · `usage-log.sh` · `usage-report.sh` 는 그것을 부르고 계산을 다시 쓰지 않는다
- 관리 스크립트를 고치면 `src/bin/harness render` 로 이 리포의 `script/` 사본을 갱신해 함께 커밋한다
- 회귀 테스트는 `HOME` 을 바꾸지 않고 `render-test.sh` 가 이미 두는 `HARNESS_HOME` 을 쓴다. 지표·사용 기록 경로는 테스트 작업 디렉터리 아래(`{clone}` 포함)로 고정하고, 기대 키는 설치된 `script/_clone_key.py` 로 구한다
- 출력 문구는 명세의 영어 원문 그대로 둔다. 새 블록의 터미널 출력에도 한글 검사를 적용한다
- 주석과 테스트 이름에 이슈 번호·문서 번호·테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록 형식을 따른다
- 동작이 바뀌어 틀리게 된 주석(등록부가 이름으로 나뉜다는 서술 등)은 그 동작을 바꾸는 task 에서 지운다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- 옮긴 클론의 옛 키 디렉터리 기록을 새 키로 잇는 것, 끊긴 등록 정리 (명세 10절)
- `path` 가 이 루트가 아닌 옛 이름 디렉터리의 정리 — `harness projects` 의 `legacy` 로 보이기만 한다
- 등록부 파일이나 디렉터리를 쓰지 못할 때를 가르는 안내문
- 다른 프로세스가 쓰는 중인 worktree 를 옮기기가 알아보는 것
