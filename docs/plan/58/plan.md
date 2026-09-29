# #58 분해 — 관리 부품과 프로젝트 부품의 경계, 관리 파일 변조 감지

명세: [`docs/spec/58-separate-managed-and-project-parts.md`](../../spec/58-separate-managed-and-project-parts.md)
결정 기록: [`docs/adr/0015-detect-changes-to-the-pinned-copy-and-managed-files.md`](../../adr/0015-detect-changes-to-the-pinned-copy-and-managed-files.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | 프로젝트 스크립트 자리 `script/project/` 와 소유 원형 추가 | 없음 |
| T2 | feat | `.harness/managed` 에 관리 파일과 고정 사본의 sha256 기록 | 없음 |
| T3 | feat | 하네스가 쓸 경로의 사용자 파일을 덮지 않고 멈추고 `--adopt` 로 넘겨받음 | T1, T2 |
| T4 | feat | check 가 관리 파일과 고정 사본을 매니페스트와 대조 | T2 |
| T5 | feat | doctor 에 관리 파일 절과 UI 문구 추가 | T3, T4, #59 |
| T6 | feat | 전역 CLI 가 넘기기 전에 같은 버전의 고정 사본을 대조 | 없음 |
| T7 | docs | README 에 파일 부류의 프로젝트 스크립트 자리와 관리 파일 대조 반영 | T3, T4, T5 |
| T8 | docs | 용어·아키텍처 문서에 소유 자리·매니페스트·사용자 파일·사본 대조 반영 | T1 ~ T6 |

- T1 은 규칙 문서 원형·관리 문서·소유 원형의 문구와 `render-test.sh` 의 새 블록(7-1 의 소유 원형 · 불변식)을 만든다.
  이 블록을 T3 이 넓힌다
- T2 는 매니페스트를 쓰고 읽는 쪽(`previous()` · 해시 짝 읽기 · `prune()` · `cmd_render` · `install_registered`)만 바꾼다.
  대조는 T4 · T5 · T6 이 한다
- T3 의 판정은 이전 매니페스트에 기댄다. T2 가 재설치에서 매니페스트를 남기기 전에는 재설치마다 하네스 파일 전부가 사용자 파일로 판정된다
- T4 가 판정 함수(명세 4-1)를 만들고 T5 가 그것을 doctor 에서 쓴다. T5 의 `managed files` 절은 #59 가 만드는 doctor 결과 목록
  (`section` · `state` · `what` · `detail`)에 항목을 더하는 것이라 #59 구현이 `develop` 에 머지된 뒤에 착수한다
- T6 은 매니페스트를 읽지 않고 전역 CLI 의 파일과 사본을 바로 비교하므로 T2 에 기대지 않는다
- T7 · T8 은 앞 task 가 만든 동작을 문서에 적는다. T8 은 보호 문서라 사람이 지시한 턴에서만 진행한다

## 브랜치·리뷰 요청·커밋

- 브랜치: `fix/58-separate-managed-and-project-parts` — 요구사항 이슈 #58 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `fix: 관리 부품과 프로젝트 부품의 경계 분리와 관리 파일 변조 감지(#58)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #58` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #58`

## 전 task 공통 사항

- CLI 는 표준 라이브러리만 쓴다. sha256 은 `hashlib`
- 넘겨받기 인수의 이름은 `--adopt` 다. #60 이 이 이름을 참조한다
- 출력 문구는 명세의 영어 원문 그대로 둔다. 터미널 출력에 한글이 없다. 새 블록의 출력에도 한글 검사를 적용한다
- 주석과 테스트 이름에 이슈 번호·문서 번호·테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 블록 번호는 구현 시점에 기존
  `UT-<번호>` 블록과 겹치지 않는 다음 번호를 쓴다(중복은 회귀 테스트가 잡는다). 등록부는 기존처럼 `HARNESS_HOME` 을 쓴다
- 관리·생성 템플릿(`src/templates/managed/` · `src/templates/generated/`)을 고친 task 는 커밋 전에 이 리포에서 render 해 설치된 사본과
  생성물·`.harness/managed` 를 함께 커밋한다. 이 리포의 `script/` · `.ai/templates/` 는 설치된 사본이라 직접 고치지 않는다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- 고정 사본을 바이너리로 묶는 것, 사본 변경을 막는 것 — 목표는 감지다(명세 10절)
- 이미 `script/` 루트에 있는 프로젝트 스크립트를 `script/project/` 로 옮기는 것
- 하네스가 `script/project/` 의 스크립트를 부르는 것 — 검증에 넣으려면 `harness.toml` 의 `[verify]` · `[commands]` 에 적는다
- UI 가 `--adopt` 를 넘기는 것
- 히스토리 전체의 관리 파일 변경 조사, CI 에서 고정 사본 변조를 잡는 것(명세 8절 "검사하지 않는 것")
