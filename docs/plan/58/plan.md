# #58 분해 — 관리 부품과 프로젝트 부품의 경계, 관리 파일 변조 감지

명세: [`docs/spec/58-separate-managed-and-project-parts.md`](../../spec/58-separate-managed-and-project-parts.md)
결정 기록: [`docs/adr/0015-detect-changes-to-the-pinned-copy-and-managed-files.md`](../../adr/0015-detect-changes-to-the-pinned-copy-and-managed-files.md) ·
[`docs/adr/0017-the-harness-changes-the-target-repo-only-through-safe-paths.md`](../../adr/0017-the-harness-changes-the-target-repo-only-through-safe-paths.md)

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
| T9 | feat | 경로 규칙과 공용 함수 `guarded_path()`, render 의 사전 판정과 변경 지점 전환 | T3 |
| T10 | feat | install · uninstall 의 사전 판정과 변경 지점을 공용 함수로 전환 | T9 |
| T11 | feat | 매니페스트를 읽을 때마다 경로 규칙으로 검증하고 어긋나면 변경 명령을 멈춤 | T9, T10 |
| T12 | feat | check · doctor 가 매니페스트의 어긋난 줄을 보고하고 UI 가 옮김 | T11, T5 |
| T13 | fix | `steps --rename` 이 새 이름 자리의 파일을 덮지 않고 멈춤 | T9 |
| T14 | docs | 아키텍처 문서 "신뢰 경계" 에 매니페스트를 들어오는 입력으로 추가 | T11, T12 |

- T1 은 규칙 문서 원형·관리 문서·소유 원형의 문구와 `render-test.sh` 의 새 블록(7-1 의 소유 원형 · 불변식)을 만든다.
  이 블록을 T3 이 넓힌다
- T2 는 매니페스트를 쓰고 읽는 쪽(`previous()` · 해시 짝 읽기 · `prune()` · `cmd_render` · `install_registered`)만 바꾼다.
  대조는 T4 · T5 · T6 이 한다
- T3 의 판정은 이전 매니페스트에 기댄다. T2 가 재설치에서 매니페스트를 남기기 전에는 재설치마다 하네스 파일 전부가 사용자 파일로 판정된다
- T4 가 판정 함수(명세 4-1)를 만들고 T5 가 그것을 doctor 에서 쓴다. T5 의 `managed files` 절은 #59 가 만드는 doctor 결과 목록
  (`section` · `state` · `what` · `detail`)에 항목을 더하는 것이라 #59 구현이 `develop` 에 머지된 뒤에 착수한다
- T6 은 매니페스트를 읽지 않고 전역 CLI 의 파일과 사본을 바로 비교하므로 T2 에 기대지 않는다
- T7 · T8 은 앞 task 가 만든 동작을 문서에 적는다. T8 은 보호 문서라 사람이 지시한 턴에서만 진행한다
- T9 ~ T14 는 명세 11절(대상 리포 경로 안전)과 그것을 가리키는 2-3 · 3-x · 4-x · 7-4 · 8절 "신뢰 경계" 행을 구현한다.
  T1 ~ T8 이 만든 코드 위에 얹고, T3 이 쓸 경로마다 덧댄 링크 검사(`refuse_link()` · `linked_component()` · `user_files()` 의 링크 판정)를 대체한다
- 명세 11-1 의 변경 지점 11곳은 T9(관리 파일 · 소유 파일과 CI 골격 · 생성 파일 · 매니페스트 쓰기 · `prune()` · `--adopt`),
  T10(`install_registered()` 의 사본 교체 · 소스 리포 옛 사본 정리, `seed_config()`, `cmd_uninstall`), T13(`rename_or_delete_workflow()`)이 나눠 맡는다.
  T10 이 끝나면 `refuse_link()` · `linked_component()` 를 부르는 곳이 없다
- T9 가 경로 규칙의 판정 함수(형식 · 링크 · 사유 문구)를 만들고 T11 이 매니페스트 줄에 같은 함수를 쓴다. 판정을 따로 두지 않는다
- T9 가 `render-test.sh` 에 명세 7-4 블록(경로 안전)을 새로 두고 T3 블록의 링크 케이스를 그리로 옮긴다. T10 · T11 · T12 · T13 이 이 블록에 케이스를 더한다
- T12 의 doctor 항목은 T5 의 `managed files` 절과 #59 의 `generated files` 절에 더한다
- T14 는 보호 문서 `.ai/project/architecture.md` 를 고친다. 사람 지시가 있다 — #58 결정 게이트에서 사용자가 "신뢰 경계" 한 줄 수정을 지시했다

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
- T9 가 두는 명세 7-4 블록의 번호는 그 커밋을 만들 때 `develop` 의 `render-test.sh` 에 있는 최대 `UT-<번호>` 의 다음 번호다
- 경로 안전 케이스의 링크 대상과 피해 파일은 하네스 루트 바깥의 테스트 임시 디렉터리 안에 둔다. "그대로" 는 바이트 단위로 비교한다
- 관리·생성 템플릿(`src/templates/managed/` · `src/templates/generated/`)을 고친 task 는 커밋 전에 이 리포에서 render 해 설치된 사본과
  생성물·`.harness/managed` 를 함께 커밋한다. 이 리포의 `script/` · `.ai/templates/` 는 설치된 사본이라 직접 고치지 않는다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- 고정 사본을 바이너리로 묶는 것, 사본 변경을 막는 것 — 목표는 감지다(명세 10절)
- 이미 `script/` 루트에 있는 프로젝트 스크립트를 `script/project/` 로 옮기는 것
- 하네스가 `script/project/` 의 스크립트를 부르는 것 — 검증에 넣으려면 `harness.toml` 의 `[verify]` · `[commands]` 에 적는다
- UI 가 `--adopt` 를 넘기는 것
- 히스토리 전체의 관리 파일 변경 조사, CI 에서 고정 사본 변조를 잡는 것(명세 8절 "검사하지 않는 것")
- 재검사와 시스템 호출 사이의 경합 창을 닫는 것(디렉터리 fd · `O_NOFOLLOW`), 직전 재검사로 멈춘 명령의 되돌리기, 하드 링크 판정(명세 10절)
- 하네스 루트 아래의 심볼릭 링크를 지원하는 것 — 링크인 성분은 전부 거부한다(명세 11-6)
- `copy_include()` 와 `harness.toml` 쓰기·되돌리기, 기기 단위 상태를 공용 함수로 옮기는 것(명세 11-1 "대상이 아닌 것")
