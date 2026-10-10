# #217 분해 — 하네스 CI 게이트 생성과 preset 정책 검사

명세: [`docs/spec/217-org-ci-gate.md`](../../spec/217-org-ci-gate.md)
결정 기록: [`docs/adr/0025-the-ci-gate-file-is-generated-and-checks-the-preset-policy.md`](../../adr/0025-the-ci-gate-file-is-generated-and-checks-the-preset-policy.md)

착수 조건: #216 이 `develop` 에 머지된 뒤 착수한다 — #216 의 선행(#206 · #207 · #208)이 함께 들어와 있다.

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | chore | 이 리포의 release job 을 workflow_run 으로 도는 소유 워크플로 release.yml 로 분리 | 없음 |
| T2 | feat | [ci] · [policy] 설정 절의 기본값과 검증, 잠금 · 개인 레이어 경계 | 없음 |
| T3 | feat | preset 저장소의 ci/ 아래 CI 게이트 템플릿 두 경로를 받는 파일로 추가 | 없음 |
| T4 | feat | CI 게이트 템플릿의 변수 치환 · 규칙 검사 · 머리말 함수 | T2 |
| T5 | feat | render 가 리포 루트에 CI 게이트를 생성하고 이 리포의 게이트를 넘겨받음 | T1, T4 |
| T6 | feat | 기존 게이트 넘겨받기 안내와 리뷰 호스트 전환 · uninstall 의 게이트 정리 | T5 |
| T7 | feat | lock 체인의 preset 이 공급한 CI 템플릿으로 게이트를 렌더하고 pull 이 템플릿 규칙을 검사 | T3, T5 |
| T8 | feat | check 가 lock 체인의 preset 출처를 policy.preset_sources 로 검사 | T2 |
| T9 | feat | check --min-preset-version 으로 preset 최소 버전을 검사하고 게이트가 정책에 따라 넘김 | T5, T8 |
| T10 | feat | doctor 의 ci gate 절과 UI Doctor 문구 | T5, T8 |
| T11 | docs | 운영 안내 docs/workflow/ci-gate.md 와 docs/workflow 문서 표 · 층 표 반영 | T6, T7, T9, T10 |
| T12 | docs | README 와 다른 명세(58 · 60 · 216)에 CI 게이트 생성과 preset 정책 반영 | T3, T6, T7, T9, T11 |
| T13 | docs | 담당 범위 · 아키텍처 · 용어 문서에 CI 게이트와 preset 정책 반영 | T6, T7, T9, T10 |

- T1 이 T5 앞이다. T5 가 게이트를 생성 파일로 바꾸는 커밋에서 이 리포의 `.github/workflows/harness-verify.yml` 을 `--adopt` 로 넘겨받으므로,
  그 파일에 있던 `release` job 이 먼저 소유 워크플로로 옮겨져 있어야 한다. 옮긴 뒤에도 워크플로 이름 `harness verify` 는 그대로라서
  `release.yml` 의 `workflow_run` 트리거가 T5 전후로 같은 워크플로를 가리킨다
- T5 는 게이트 등록(`plan()`)과 이 리포의 넘겨받기를 한 커밋에서 한다. 게이트가 생성 파일이 되는 순간 이 리포의 `check` 가 그 파일을
  대조하기 때문이다(명세 8절)
- T4 는 render 에 닿지 않는 함수와 단위 테스트다. 치환 · 거부 규칙을 T5 의 render 연결 전에 단위로 고정한다
- T2 · T3 · T8 은 서로 기대지 않는다. T3 은 preset 받기의 받는 파일 표만 고치고, 받은 템플릿을 읽는 것은 T7 이다
- T8 의 출처 판정 함수를 T10 의 doctor 줄(`<n> preset source(s) not allowed by policy`)이 다시 쓴다
- T9 의 `{{CI_VERIFY}}` 참 쪽 명령은 T4 의 함수가 이미 내고, T9 는 그 명령이 부를 `check --min-preset-version` 을 만들고 render · 실행 케이스로 고정한다
- 문서 task(T11 · T12 · T13)는 코드 task 가 만든 동작을 적는다. T12 의 README 는 T11 의 운영 안내로 잇는다

### 다른 이슈와의 관계

| 이슈 | 관계 |
|---|---|
| #216 | 착수 조건. 체인 · lock(`source` · `tag`) · preset 사본 · 트리 멤버 판정 함수와 받는 파일 표 · lock 과 사본의 대조 · pull 의 준비 단계를 그대로 쓴다. T3 이 받는 파일 표에 두 행을 더하고, T12 가 `docs/spec/216-org-presets.md` 3-1 · 3-2 · 4-2 를 명세 2-6 의 문안으로 고친다 |
| #207 | `defaults.toml` 의 절과 주석, 절의 모르는 키 검사, 일반 배열 잠금, 개인 레이어 허용 키를 그대로 쓴다. 세 키의 병합(명세 3-3)을 #207 의 병합 규칙 표에 더하되 규칙은 일반 배열 교체 · 스칼라 덮어쓰기라서 새 병합 동작은 없다 |
| #206 | 코드는 `src/harness/` 모듈 지도에 놓는다. 단위 테스트 자리와 실행은 #206 7-5 |
| #213 | G3 대로 `script/run-lint-test.sh` 가 shim 으로 남아 있다. 게이트는 그 경로를 부른다 |
| #221 | 순서가 없다. 착수 시점 `develop` 에 #221 이 있으면 명세 2-3 · 6 · 8 · 11-1 의 "#221 이 들어와 있을 때" 값(`<CLI> verify` 와 `{{HARNESS_CLI}}`, doctor 줄을 #221 3-4 에 맡김)으로 구현하고, 없으면 #221 이 나중에 그 값으로 맞춘다(#221 3-5) |
| #218 | 순서가 없다. 이 이슈는 OCI 를 가르는 코드와 테스트를 더하지 않는다 — 허용 출처 · 최소 버전은 lock 의 `source` · `tag` 문자열만 보고, `ci/` 두 경로는 #218 이 OCI 받기 뒤에 부르는 #216 의 멤버 판정 함수에 든다 |
| #219 | 이 이슈 뒤에 착수한다. #219 의 운영 안내가 가리키는 대상 리포 CI 검사가 이 이슈의 게이트(체크 이름 명세 2-5, 안내 `docs/workflow/ci-gate.md`)다 |

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/217-org-ci-gate` — 요구사항 이슈 #217 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: 하네스 CI 게이트를 생성물로 만들고 preset 정책을 검사함(#217)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #217` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #217`

## 전 task 공통 사항

- CLI 는 python3 표준 라이브러리만 쓴다. 코드는 #206 의 모듈 지도에 둔다 — CI 게이트의 템플릿 고르기 · 변수 치환 · 머리말은 새 모듈
  `src/harness/render/ci.py`, preset 정책 판정(출처 일치 · 버전 · `--min-preset-version` 해석)은 새 모듈 `src/harness/preset/policy.py`.
  두 모듈은 #206 3-4 의 의존 방향을 지킨다(`commands` · `cli` 를 불러오지 않는다)
- render · check · doctor 는 네트워크를 쓰지 않는다. 템플릿은 preset 사본(`.harness/preset/<깊이>/`)이나 내장 템플릿에서 읽는다
- 터미널 출력은 명세의 영어 원문 그대로 둔다. 새 오류 · 안내에도 회귀 테스트의 한글 검사를 적용한다
- `[ci].setup` 항목의 값과 `--min-preset-version` 의 값은 어떤 출력에도 옮기지 않는다. 오류는 항목 · 순번만 가리킨다
- 템플릿 규칙 위반과 설정 검증 위반은 render 의 다른 사전 판정과 같은 자리에서 보고, 종료 코드 2 로 아무것도 쓰지 않는다
- 게이트의 검증 일괄 명령은 명세 2-3 의 표대로다. 생성물과 에이전트가 보는 명령 표기는 G3 대로 `script/<이름>.sh` 를 유지한다
- 단위 테스트는 `src/test/unit/test_<대상>.py`(#206 7-5)에 두고 CLI 를 하위 프로세스로 띄우지 않는다
- `src/test/render-test.sh` 의 새 블록 번호는 착수 시점의 최대 `UT-<번호>` 다음부터 매긴다. 기존 블록 형식을 따른다
- preset 이 필요한 회귀 케이스는 #216 의 방식으로 만든다 — 로컬 bare 리포, 임시 `GIT_CONFIG_GLOBAL` 의 `insteadOf` 로 `https://git.example.test/` 를 잇고 `GIT_CONFIG_NOSYSTEM=1`
- 관리 파일 · 생성 파일 정본을 고치면 `src/bin/harness render` 로 이 리포의 사본과 매니페스트를 갱신해 함께 커밋한다
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다. 동작이 바뀌어 틀리게 된 주석은 그 동작을 바꾸는 task 에서 고친다
- 보호 문서(`.ai/project/` 의 scope · architecture · glossary)는 T13 만 고친다
- 커밋 전 `script/run-lint-test.sh --commit` 이 통과한다

## 이번 이슈에서 다루지 않는 것

- forge 서버 설정 — 조직 ruleset · 브랜치 보호 · required check 지정 · CI 변수 등록. 사람이 forge 에서 하고, 하네스는 게이트와 운영 안내만 둔다
- CI 에서 리뷰어 에이전트를 부르는 것, 리뷰 판정(PASS 댓글)을 머지 조건으로 확인하는 것
- 게이트를 끄는 설정, 모노레포 서브프로젝트의 게이트 생성
- 실제 GitLab 으로 게이트를 돌려 보는 검증
- 명세가 확인 필요(TBD)로 둔 forge 사실 — GitLab 그룹 변수가 job 환경 변수로 들어오는지(2-5), 조직 ruleset · 조직 변수의 플랜 조건과 체크 지정 방식(7절),
  GitLab `include: local` 경로 표기(7절), `workflow_run` 이 기본 브랜치의 `release.yml` 로 도는지(8절). 운영 안내와 이 리포 파일에 TBD 표기 그대로 남긴다.
  `release.yml` 이 첫 main 릴리스에서 Release 를 만드는지는 머지 뒤 사람이 확인한다
