# #212 task

## T1 · chore: 기본 work 를 agent 절차로 전제한 기존 회귀 케이스를 이전 기본값 절로 고정

### 상위 Requirement

- relates to #212

### 작업 내용

기본 `work` 를 driver 로 바꾸기(T5) 전에, 기본 `work` 를 agent 절차 고정물로 쓰는 기존 회귀 케이스가 설정에 이전 기본값 절을 직접 두게 한다.
동작과 기대값은 바꾸지 않는다. 그 절은 지금 기본값과 같으므로 지금 트리에서 통과하고, T5 뒤에도 고치지 않고 통과한다.

- 명세 10-1 의 이전 기본값 절 원문(`[workflows.work]` 다섯 단계)을 테스트 대상 설정에 넣는 도우미 하나를 `src/test/render-test.sh` 에 둔다.
  대상 설정에 `[workflows.work]` 가 있으면 그 절을 바꾸고, 없으면 더한다. T9 의 doctor · `fix legacy-work` 케이스도 이 도우미를 쓴다
- 고정하는 케이스는 agent 절 `work` 의 산출물이나 실행을 보는 것이다
  - 절차 문서 `.ai/workflows/work.md` 의 단계 번호 · 하위 번호 · 단계 삽입 뒤 번호 다시 매기기와 단계 참조 풀기
  - 시작 표지 줄 `script/metric.py step work <단계>`
  - `.claude/commands/work.md` 와 CLAUDE.md 커맨드 표의 `work` 행
  - `harness run work <번호>` 가 오케스트레이터를 띄우는 명령줄
  - 세션 가져오기 · 지표 집계가 `work/implement` · `work/review` 키로 묶는 것 — 설정에서 키가 나오는 케이스만. 스팬 고정물만 쓰는 케이스는 그대로 둔다
  - 그 밖에 `harness steps work` · 절차 메모 · 리뷰 상한처럼 기본 `work` 의 agent 절 단계 구성을 전제로 하는 케이스
- 내장 기본값 자체를 보는 케이스(배포되는 기본값의 렌더, 기본 단계로 돌아가는지 등)는 고정하지 않는다. T5 가 그 기대값을 바꾼다
- `src/test/unit/` 과 `script/test-*.sh` 에 같은 전제의 케이스가 있으면 같은 방식으로 고정한다
- 건드릴 파일: `src/test/render-test.sh`(그리고 같은 전제의 케이스가 있는 테스트 파일)

### 완료 조건

- [ ] 이전 기본값 절을 대상 설정에 넣는 도우미가 있고, 넣은 절이 명세 10-1 원문과 같다
- [ ] 위 범주의 케이스가 모두 그 도우미로 설정에 이전 기본값 절을 둔다
- [ ] 고정한 케이스의 기대값이 바뀌지 않았다
- [ ] 이 트리(기본 `work` 가 agent 절차)에서 `script/run-lint-test.sh` 와 `src/test/render-test.sh` 가 통과한다
- [ ] 제품 코드와 템플릿이 바뀌지 않는다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 도우미가 절을 바꾼다 | `[workflows.work]` 가 있는 대상 설정에 도우미 실행 | 그 절이 명세 10-1 원문으로 바뀌고 다른 절은 그대로다 |
| UT-02 | 도우미가 절을 더한다 | `[workflows.work]` 가 없는 최소 설정에 도우미 실행 | 명세 10-1 원문 절이 더해지고 render 가 통과한다 |
| UT-03 | 고정한 케이스가 지금 트리에서 통과 | 고정 뒤 `src/test/render-test.sh` | 실패 없음, 기대값 변경 없음 |

## T2 · feat: 구현자 결과 스키마와 처리 노트 표지 추가, 구현자 계약에 모드 · escalate · 마무리 반영

### 상위 Requirement

- relates to #212

### 작업 내용

구현자가 모드마다 마지막에 내는 구조화 출력 `developer-result` 를 동봉 스키마로 두고, 구현자 계약을 헤드리스 실행에 맞게 고친다.
고치지 않고 넘긴 지적의 새 노트를 판정 명령이 찾을 수 있게 처리 노트 표지를 더한다.

- 명세 3절(구현자 결과), 4절(구현자 계약), 4-6(처리 노트 표지), 12-1 의 "표지 일치" 케이스
- 스키마 `src/harness/schemas/developer-result.json`
  - 최상위 object, `required` 는 `status` · `mr` · `reason` · `handled`
  - `status`: string, `enum` 은 `committed` · `no_change` · `verify_failed` · `escalate`. `mr`: string. `reason`: string, `minLength = 1`
  - `handled`: array, `items` 는 object 이고 `required` 는 `finding` · `where` · `thread` · `issue`. `finding`: string, `minLength = 1`.
    `where`: string, `enum` 은 `reply` · `note`. `thread` · `issue`: string
  - 키워드는 `type` · `properties` · `required` · `enum` · `items` · `minLength` 만 쓴다(#208 5-2 의 부분집합)
- 구현자 계약 `src/templates/managed/.ai/templates/developer.md`
  - 입력: 이슈 번호와 모드(구현 · 재시도 · 마무리) — 모드는 부르는 쪽이 알린다. 재시도 · 마무리는 리뷰 요청 번호를 받고, 없으면 손대지 않고
    `escalate` 로 돌아오며 사유에 무엇이 없는지 적는다. 리뷰 본문은 넘겨받지 않으면 `review_mr_threads <리뷰 요청>` 에서 읽는다 — 본문이
    `FMT_SUMMARY_HEADING` 으로 시작하는 가장 늦은 노트가 이번 회차 요약이고, 그 앞 요약 뒤에 달린 인라인 스레드가 이번 회차 발견이다.
    task↔이슈 매핑은 넘겨받지 않으면 `script/sync-task-issues.sh <이슈> --dry-run` 출력에서 읽고, 분해가 있는데 얻지 못하면 `escalate`.
    "받지 못했으면 손대기 전에 요구한다" 는 "손대기 전에 `escalate` 로 돌아온다" 로 바꾼다 (4-1)
  - 모든 모드: 착수 전 미커밋 변경이 있으면 손대지 않고 `escalate`. 도구 · 환경 변수가 없어 검증이 서지 않고 갖출 수 없으면 고치지 않고 `escalate` (4-2)
  - 구현 모드: 분해가 없는데 이슈 본문에 완료 조건이 없으면 착수하지 않고 `escalate`. 작업 브랜치(`<태그>/<이슈번호>-*`)가 로컬에 하나 있으면
    그 브랜치에서 이어 하고 커밋된 작업을 다시 하지 않는다. 둘 이상이면 `escalate` (4-3)
  - 재시도 모드: 범위 확대 · 코드로 덮을 수 없는 반복 지적 · 설계와 상충하는 인터페이스 변경 blocker 는 고치지 않고 `escalate`. 고치지 않고
    넘긴 지적은 처리를 남기고 그 자리를 `handled` 에 적는다 (4-4)
  - 마무리 모드 새 절: 코드를 고치지 않고 커밋하지 않는다. PASS 회차 발견 가운데 처리가 리뷰 요청에 없는 것마다 처리를 남긴다(minor 는 새
    리뷰 요청 노트). 고쳐야 할 발견은 `escalate` 사유로 낸다. 처리할 것이 없으면 `no_change` 로 곧바로 돌아온다. 남긴 자리를 모두 `handled` 에 적는다 (4-5)
  - "고치지 않고 넘기는 지적": 새 리뷰 요청 노트의 첫 줄은 `FMT_HANDLED_HEADING` 의 값이다 (4-6)
  - 출력: 지금 항목에 더해 마지막에 `developer-result` 를 낸다. 출력 절에 스키마 이름과 필드 · `status` 값의 뜻(명세 3절 표)을 적는다(#208 5-1).
    "회차와 상한을 세지 않는다" · "스레드를 직접 resolve 하지 않는다" 는 그대로 둔다 (4-7)
  - 계약은 driver 와 옛 agent 절에서 같다. 실행 방식에 따라 갈리는 서술을 두지 않는다
- 표지: `src/templates/managed/script/harness-format.sh` 의 "등록 댓글" 묶음 근처에 `FMT_HANDLED_HEADING='## 구현자 처리'` 와 쓰는 쪽 ·
  읽는 쪽을 적은 주석 한 줄을 더한다. 머리글의 "함께 고칠 문서" 목록에 `.ai/templates/developer.md` 를 더한다. 파이썬 쪽은 `format.py` 의
  `markers()` 가 이 파일을 파싱해 읽는다 — 사본을 두지 않는다
- 건드릴 파일: `src/harness/schemas/developer-result.json`, `src/templates/managed/.ai/templates/developer.md`,
  `src/templates/managed/script/harness-format.sh`, `src/test/unit/test_developer_result.py`, `src/test/render-test.sh`,
  render 로 갱신되는 `.ai/templates/developer.md` · `script/harness-format.sh` · `.harness/managed`

### 완료 조건

- [ ] `developer-result.json` 이 #208 5-2 문법 검사를 통과하고 명세 3절의 키 · 값 · `minLength` 를 담는다
- [ ] `harness schema` 의 `output_schemas` 에 `developer-result` 가 동봉 자리(`source = "harness"`)로 나오고 `fields.status` 가 네 값이다
- [ ] 구현자 계약이 명세 4-1 ~ 4-7 을 담고, "받지 못했으면 요구한다" 류 문장이 남지 않는다
- [ ] 구현자 계약 출력 절에 `developer-result` 의 이름과 필드 뜻이 있다
- [ ] `harness-format.sh` 에 `FMT_HANDLED_HEADING` 이 있고 `markers()` 가 그 값을 돌려준다
- [ ] 설치된 `.ai/templates/developer.md` 가 `FMT_HANDLED_HEADING` 의 값을 그대로 적는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 스키마 문법 | `developer-result.json` 을 #208 의 문법 검사에 | 오류 없음 |
| UT-02 | 맞는 출력 | `status` 네 값 각각, `handled` 가 빈 배열 · `reply` 원소 · `note` 원소인 객체 | 검증 통과 |
| UT-03 | 빠진 키 | `reason` 이 없는 객체, `thread` 가 없는 `handled` 원소 | 검증 실패 |
| UT-04 | 값 위반 | `status = "done"`, `where = "issue"`, `reason = ""`, `finding = ""` | 검증 실패 |
| UT-05 | 표지 값 | `markers(root)` | `FMT_HANDLED_HEADING` 이 `## 구현자 처리` |
| UT-06 | 표지 일치 (render-test) | 새 설치본의 `.ai/templates/developer.md` 와 `script/harness-format.sh` | 계약에 `FMT_HANDLED_HEADING` 의 값이 그대로 있다 |
| UT-07 | schema 출력 (render-test) | `harness schema` | `output_schemas.developer-result.source = "harness"`, `fields.status` = 네 값 |

## T3 · feat: 판정 명령 work-check 의 작업 트리 확인 · 구현 판정과 shim 추가

### 상위 Requirement

- relates to #212

### 작업 내용

`work` 의 판정 단계가 부를 하위 명령 `harness work-check` 를 두고, 공통 규칙과 동작 `clean` · `develop` 을 넣는다. 셸 진입점
`script/work-check.sh` 는 공통 shim 이다. `fix` · `finalize` 는 T4 가 더한다.

- 명세 5절 머리(출력 · 인자 · 하네스 루트 · 명령 표 · 설정 · 출력 위생 · 사유 줄 · forge), 5-1(공통 관측 가운데 미커밋 변경 · 로컬 HEAD ·
  현재 브랜치 · 리뷰 요청 · 이슈의 열린 리뷰 요청), 5-2, 5-3, 2-3(shim), 12-2 의 해당 케이스
- 명령 모듈 `src/harness/commands/work_check.py`, 진입 함수 `cmd_work_check`
  - `commands/__init__.py` 의 `COMMANDS` 에 통과 명령(첫 원소 `True`)으로, 설정이 필요한 명령으로 넣는다. 도움말
    `work-check: judge a step of the work workflow (its steps call it)`. `cli.py` 의 `DELEGATES` 에도 넣는다 — 고정된 버전이 답한다
  - 인자는 위치로만 읽는다. `-` 로 시작해도 값이다. 동작 이름이 없거나 모르는 것(옵션 꼴 포함), 동작마다 정한 개수와 다른 인자는 명세 5절의
    사용법 네 줄을 표준 오류에 내고 2. 이 task 에서 받는 동작은 `clean`(인자 0) · `develop`(인자 4) 이다
  - 하네스 루트는 #206 의 통과 명령 규칙(이름 앞, 또는 이름 바로 뒤 한 번의 `--target`)으로 받고, 그 디렉터리에서 git 과 forge 를 부른다
  - 공유 설정을 읽는다(forge 선택). 설정 파일이 없거나 검증에 실패하면 다른 명령과 같은 안내로 2
  - 판정했으면 stdout 에 outcome 토큰 한 줄과 0, 판정하지 못했으면 stdout 을 비우고 2
  - 사람이 읽는 줄은 stderr 에 영어로. 구현자 출력에서 온 문자열은 제어 문자를 지우고 한 줄로 바꿔 옮긴다 — 이 처리는 함수 하나로 두고
    T4 가 함께 쓴다
  - `committed` · `clean` · `checked` 가 아닌 outcome 이면 stderr 에 `<동작>: <outcome> — <사유>` 한 줄. 사유 문구는 명세 5절 표
  - forge 는 #209 어댑터의 `review_mr_view` · `harness_issue_open_mrs` 로만 부른다
- `clean`: 명세 5-2 표. 미커밋 변경은 하네스 루트의 `git status --porcelain` 이 비어 있지 않은 것이고 git 이 무시하는 파일은 들지 않는다.
  git 을 실행하지 못하면 2
- `develop`: 명세 5-3 표의 순서 1~6 과 아래 두 규칙. 관측이 자기 보고에 앞선다 — `status` 가 `no_change` 여도 4 · 5 를 지나면 `committed`.
  리뷰 요청 조회가 실패하면 2
- shim `src/templates/managed/script/work-check.sh`: 명세 2-3 의 공통 형태와 문구(`#!/usr/bin/env sh`, 부모 디렉터리를 하네스 루트로,
  `.harness/bin/harness` → `src/bin/harness` 순 탐색, `<CLI> --target <루트> work-check <받은 인자 그대로>` 로 exec, CLI 없음 두 줄과 2).
  머리글은 부르는 명령의 이름과 "로직은 패키지에 있다" 는 것. 실행 권한을 준다
- `src/templates/managed/script/README.md` 표에 `work-check.sh` 행 — 판정 명령 shim(`clean` · `develop` · `fix` · `finalize`),
  0 = 판정 · 2 = 판정 못 함, 호출 시점은 `work` 의 판정 단계(명세 11절)
- `README.md` 명령 표에 `harness work-check <동작> …` — `work` 의 판정 단계가 부른다(명세 11절)
- 대화형 허용 목록: 관리 스크립트 허용 규칙이 `script/` 바로 아래 스크립트를 그대로 내므로 `script/work-check.sh` 규칙이 생긴다. 판정만 하는
  읽기 명령이다. 허용 목록을 단언하는 기존 케이스가 있으면 그 기대값에 더한다
- `src/test/fake-forge.sh`: `review_mr_view` 가 `FAKE_STATE` 의 리뷰 요청 상태 파일(상태 · 소스 브랜치 · head)을, `harness_issue_open_mrs` 가
  `FAKE_STATE` 의 열린 리뷰 요청 목록 파일을 있으면 따르게 한다. 리뷰 요청 조회 실패는 `FAKE_STATE` 의 파일로 켠다. 파일이 없으면 지금 출력 그대로다
- 단위 테스트 `src/test/unit/test_work_check.py`: 임시 git 리포와 `HARNESS_FORGE_FAKE=<src/test/fake-forge.sh>` · 임시 `FAKE_STATE` 로 돈다
- 건드릴 파일: `src/harness/commands/work_check.py`, `src/harness/commands/__init__.py`, `src/harness/cli.py`,
  `src/templates/managed/script/work-check.sh`, `src/templates/managed/script/README.md`, `README.md`, `src/test/fake-forge.sh`,
  `src/test/unit/test_work_check.py`, `src/test/render-test.sh`, render 로 갱신되는 `script/work-check.sh` · `script/README.md` ·
  `.claude/settings.json` 등 생성 파일 · `.harness/managed`

### 완료 조건

- [ ] `harness work-check clean` 이 미커밋 변경 유무로 `dirty` · `clean` 을 내고, `dirty` 면 명세 5-2 의 stderr 세 부분을 낸다
- [ ] `harness work-check develop` 이 명세 5-3 의 순서대로 outcome 을 내고, 관측이 자기 보고에 앞선다
- [ ] `committed` 가 아닌 `develop` outcome 마다 명세 5절 표의 사유 줄이 stderr 에 나온다
- [ ] 동작 없음 · 모르는 동작 · 개수 틀림 · 옵션 꼴 동작이 사용법과 2 이고, `reason` 이 `-` 로 시작해도 판정한다
- [ ] 리뷰 요청 조회 실패 · git 실행 실패 · 설정 없음이 빈 stdout 과 2 다
- [ ] `reason` 의 제어 문자와 줄바꿈이 stderr 에 그대로 나오지 않는다
- [ ] `COMMANDS` · `DELEGATES` 에 `work-check` 가 있고 #206 의 명령 표 스모크 테스트가 통과한다
- [ ] 설치된 `script/work-check.sh` 가 실행 가능하고 명세 2-3 대로 CLI 로 넘기며, CLI 가 없는 트리에서 두 줄과 2 를 낸다
- [ ] 페이크 forge 의 새 상태 파일이 없을 때 기존 사용처가 고치지 않고 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | `clean` | 추적 파일 변경 / 비추적 파일 / git 이 무시하는 파일만 | `dirty` / `dirty` / `clean` |
| UT-02 | 구현 판정 — 미커밋 변경 먼저 | 미커밋 변경 + `status = committed` + 열린 리뷰 요청 | `verify_failed`, 사유 `uncommitted changes are left` 와 status 줄 |
| UT-03 | 구현 판정 — 자기 보고 | `status = verify_failed` / `escalate`, 깨끗한 트리 | `verify_failed` 와 `reason` / `escalate` 와 `reason` |
| UT-04 | 관측 우선 | `status = no_change` + 열린 리뷰 요청 + head 일치 | `committed`, stderr `develop: branch <브랜치>, review request <번호>` |
| UT-05 | 리뷰 요청이 아니다 | 빈 문자열 · 숫자 아님 · 닫힘 · 다른 소스 브랜치 · 이슈 목록에 없음 | 각각 `no_mr` 과 명세 5절 표의 사유 |
| UT-06 | push 안 됨 | 리뷰 요청 head 가 로컬 HEAD 와 다르다 | `verify_failed`, 사유 `the review request head is not the local HEAD — not pushed` |
| UT-07 | 인자 | 인자 없음 · `nope` · `--json` · `develop` 에 인자 셋 | 사용법 네 줄, 2 |
| UT-08 | `-` 로 시작하는 값 | `reason = "-x"` | 판정한다 |
| UT-09 | `--target` | 이름 바로 뒤 `--target D clean` / 동작 뒤 `clean --target D` | 하네스 루트 `D` 로 판정 / 사용법과 2 |
| UT-10 | forge 실패 | 리뷰 요청 조회 실패 상태 파일 | 빈 stdout, 2 |
| UT-11 | 출력 위생 | 제어 문자 · 줄바꿈이 든 `reason` | stderr 에 제어 문자가 없고 사유가 한 줄 |
| UT-12 | shim (render-test) | 설치된 `script/work-check.sh` 인자 없이 / CLI 를 지운 트리에서 | 사용법과 2 / `error: harness CLI not found under <루트> …` · `help: …` 와 2 |

## T4 · feat: work-check 의 수정 판정 · 마무리 확인과 처리 대조 추가

### 상위 Requirement

- relates to #212

### 작업 내용

`harness work-check` 에 동작 `fix` · `finalize` 를 더한다. 리뷰 요청의 기준 요약에서 기준 리비전을 잡고, 구현자가 낸 `handled` 의
처리 자리가 리뷰 요청 · 트래커에 있는지 대조한다.

- 명세 5-1 의 기준 요약 · 기준 리비전, 5-4, 5-5, 5-6, 12-2 의 해당 케이스
- 동작 `fix`(인자 5) · `finalize`(인자 5) 를 사용법 · 인자 개수 검사에 더한다
- 기준 요약은 리뷰 입력 맥락이 쓰는 것과 같은 함수로 찾는다 — `review_mr_threads` 의 노트 가운데 본문이 `FMT_SUMMARY_HEADING` 으로 시작하고
  `FMT_REVIEWED_HEAD` 줄이 있는 것 중 가장 늦은 것. `src/harness/review.py` 에서 이 찾기를 함수 하나로 두고 리뷰 입력 맥락과 `work-check` 가
  함께 부른다. 리뷰 입력 맥락의 동작은 그대로다
- 표지(`FMT_SUMMARY_HEADING` · `FMT_REVIEWED_HEAD` · `FMT_HANDLED_HEADING`)는 `format.py` 의 `markers()` 로 읽는다. 필요한 표지를 읽지 못하면
  stderr 에 `error:` 와 표지 이름, 2
- `fix`: 명세 5-4 표의 순서 1~9. 검증 실패를 커밋 유무보다 먼저 본다. 관측이 자기 보고에 앞선다. 기준 리비전이 새 head 의 조상이 아니어도
  head 가 다르면 `committed`. 순서 8 의 stderr 는 `stop: no commit since the reviewed head <12자> — not reviewing again`
- `finalize`: outcome 은 늘 `checked`. 명세 5-5 표의 확인마다 걸리면 `remaining:` 줄. 리뷰 요청 · 스레드 조회 실패나 기준 요약 없음은
  `remaining: could not verify the handling — <사유>` 와 2
- 처리 대조: 명세 5-6 표. `handled` 인자는 JSON 배열 텍스트이고, 배열이 아니거나 원소 형식이 3절과 다르면 `remaining: the handled list is not readable`
  한 줄을 내고 대조를 건너뛴다. 끝에 `handled: <확인한 원소 수> of <원소 수> confirmed`. 기준 요약보다 늦다는 것은 `created_at` 이 기준 요약의
  것보다 큰 것이다. 참조가 있는지만 본다
- forge 는 #209 어댑터의 `review_mr_view` · `review_mr_threads` · `tracker_issue_view` 로만 부른다
- `src/test/fake-forge.sh`: 노트의 `created_at` 이 등록 순서대로 커지게 한다(`FAKE_STATE` 의 카운터). 스레드 조회 실패와 없는 이슈를
  `FAKE_STATE` 의 파일로 켠다. 기존 사용처가 고치지 않고 통과한다
- 건드릴 파일: `src/harness/commands/work_check.py`, `src/harness/review.py`, `src/test/fake-forge.sh`, `src/test/unit/test_work_check.py`

### 완료 조건

- [ ] `fix` 가 명세 5-4 의 순서대로 outcome 을 내고, 미커밋 변경이 있으면 `status` 와 head 에 상관없이 `verify_failed` 다
- [ ] `fix` 의 `escalate` 보고가 head 가 기준 리비전과 같든 다르든 `escalate` 다
- [ ] `fix` 에서 `committed` 보고 + head 그대로는 `no_change` 와 순서 8 의 stderr, `no_change` 보고 + 새 head 는 `committed` 다
- [ ] `FMT_REVIEWED_HEAD` 줄이 없는 더 늦은 요약을 건너뛰고, 줄이 있는 요약이 없으면 `fix` 가 빈 stdout 과 2 다
- [ ] 기준 요약 찾기가 `src/harness/review.py` 의 함수 하나이고 리뷰 입력 맥락이 그 함수를 쓴다. 리뷰 명령의 기존 테스트가 통과한다
- [ ] 처리 대조가 명세 5-6 의 세 확인과 읽을 수 없는 목록 처리, 끝 줄을 낸다
- [ ] `finalize` 가 무엇이 걸려도 `checked` 이고, 조회 실패면 `remaining: could not verify` 와 2 다
- [ ] 표지를 읽지 못하면 `error:` 와 표지 이름, 2 다
- [ ] 페이크 forge 의 기존 사용처가 고치지 않고 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 순서 — 검증 실패 먼저 | 미커밋 변경 + `status` 넷 각각 + head 같음 · 다름 | 모두 `verify_failed` |
| UT-02 | 순서 — escalate 와 커밋 유무 | `escalate` 보고 + head 가 기준 리비전과 같음 / 다름 | 둘 다 `escalate` |
| UT-03 | 관측 우선 | `committed` 보고 + head 그대로 / `no_change` 보고 + 새 head | `no_change` 와 `stop: no commit since the reviewed head …` / `committed` |
| UT-04 | push 안 됨 | 리뷰 요청 head ≠ 로컬 HEAD | `verify_failed` |
| UT-05 | 리뷰 요청 상태 | 닫힌 리뷰 요청 / 다른 소스 브랜치 | 빈 stdout, 2 |
| UT-06 | 기준 요약 | head 줄 있는 요약 뒤에 head 줄 없는 요약 / head 줄 있는 요약 없음 | 앞 요약의 리비전을 쓴다 / 빈 stdout, 2 |
| UT-07 | 처리 대조 — 답글 | 기준 요약보다 늦은 답글 / 이른 답글 / 없는 스레드 id | 확인 / `remaining: no reply after the review in thread <id> — <finding>` / 같은 줄 |
| UT-08 | 처리 대조 — 노트 | 표지로 시작하는 늦은 노트 / 표지 없는 늦은 노트 | 확인 / `remaining: no handling note after the review — <finding>` |
| UT-09 | 처리 대조 — 이월 이슈 | 있는 이슈 / 없는 이슈 | 확인 / `remaining: carryover issue <issue> not found — <finding>` |
| UT-10 | 읽을 수 없는 목록 | `handled = "x"` · 키가 빠진 원소 | `remaining: the handled list is not readable` 한 줄, outcome 그대로 |
| UT-11 | 끝 줄 | 원소 셋 가운데 둘 확인 | `handled: 2 of 3 confirmed` |
| UT-12 | `finalize` | 미커밋 변경 · 기준 리비전 뒤 커밋 · `escalate` 보고 | stdout `checked`, 걸린 것마다 명세 5-5 의 `remaining:` 줄 |
| UT-13 | `finalize` 조회 실패 | 스레드 조회 실패 상태 파일 | `remaining: could not verify the handling — …`, 2 |
| UT-14 | forge 실패 | `fix` 에서 리뷰 요청 조회 실패 | 빈 stdout, 2 |
| UT-15 | 표지 읽기 실패 | 하네스 루트의 표지 파일에서 `FMT_REVIEWED_HEAD` 줄을 뺀다 | `error:` 와 표지 이름, 2 |
| UT-16 | 출력 위생 | 제어 문자 · 줄바꿈이 든 `finding` | `remaining:` 줄에 제어 문자가 없고 한 줄 |

## T5 · feat: 기본 절차 work 를 driver 로 전환하고 하위 절차 review-loop 와 단계 조각 추가

### 상위 Requirement

- relates to #212

### 작업 내용

내장 기본값의 `work` 를 명세 2-1 의 driver 절차로 바꾸고 하위 절차 `review-loop`(명세 2-2)를 더한다. 새 단계의 조각을 두고, 옛 agent 절과
함께 쓰는 머리 · 꼬리 조각을 두 실행 방식에서 참인 서술로 고친다.

- 명세 2절 전체, 6절(꼬리 조각의 판정 표), 10-1(시드에 절을 두지 않음 · 옛 절과 함께 쓰는 설정의 `review-loop`), 10-2, 12-1 의
  "기본 설정 렌더" · "단독 실행 거부" 케이스와 "옛 절" 케이스의 렌더 부분
- `src/templates/defaults.toml`
  - `[workflows.work]` 를 명세 2-1 표대로: `execute = "driver"`, 단계 `clean` · `preflight` · `task-sync` · `recheck` · `develop` ·
    `develop-check` · `loop` · `finalize` · `finalize-check` 와 각 `run` · `role` · `schema` · `on` · `set` · `workflow` · `next`
  - `[workflows.review-loop]` 를 명세 2-2 표대로: `execute = "driver"`, 단계 `review` · `fix` · `fix-check`
  - 구현자 단계 `develop` · `fix` · `finalize` 에는 `text` 로 모드와 입력값을 둔다 — driver 의 agent 블록 프롬프트는 역할 지시 · 이슈 줄 ·
    단계 `text` · 스키마로 이뤄지고 조각을 넣지 않는다(#208 3-2 · 4-2). 문장은 각 조각의 첫머리와 같다: `develop` 은 구현 모드와 `{issue}`,
    `fix` 는 재시도 모드와 `{issue}` · `{mr}` 과 리뷰 본문을 읽을 자리, `finalize` 는 마무리 모드와 `{issue}` · `{mr}`, 판정이 PASS 라는 것
  - `run` 값은 `script/<이름>.sh` 표기다. 절차 키 `title` · `max_steps` · `max_visits` 는 두지 않는다
- 단계 조각: 명세 2-4 첫 표의 13개를 `src/templates/workflows/work/` · `src/templates/workflows/review-loop/` 에 새로 둔다. agent 단계 조각은
  모드와 입력값을 첫머리에 적고 `{issue}` · `{mr}` 자리표시를 쓴다
- `work/_head.md` · `work/_tail.md` 를 명세 2-4 둘째 표대로 고친다. 옛 agent 절과 새 기본값 모두에서 참인 서술만 두고 `{{step:<id>}}` 를 쓰지 않는다
- 옛 단계 조각 다섯과 `src/templates/managed/.claude/commands/work.md` 는 고치지 않는다
- 내장 기본값 자체를 보는 기존 케이스의 기대값을 새 기본값으로 바꾼다. T1 이 고정한 케이스는 고치지 않고 통과해야 한다. 머리 · 꼬리 조각의
  문장을 단언하는 케이스가 있으면 새 문장으로 바꾼다
- render 로 이 리포의 생성물을 갱신한다 — 이 리포는 루트 `harness.toml` 에 옛 절을 두므로 `.ai/workflows/work.md` 는 머리 · 꼬리만 바뀌고,
  `.ai/workflows/review-loop.md` 가 새로 생긴다
- 건드릴 파일: `src/templates/defaults.toml`, `src/templates/workflows/work/`(새 조각 · `_head.md` · `_tail.md`),
  `src/templates/workflows/review-loop/`, `src/test/render-test.sh`, render 로 갱신되는 생성 파일

### 완료 조건

- [ ] 내장 기본값의 `work` · `review-loop` 가 명세 2-1 · 2-2 표와 같은 단계 · 배선이고 render 검증(#208 6절)을 통과한다
- [ ] 구현자 단계 셋에 모드와 입력값을 담은 `text` 가 있다
- [ ] 명세 2-4 의 새 조각 13개가 있고, 머리 · 꼬리 조각에 `{{step:` 이 없다
- [ ] 새 설치본에 `.ai/workflows/work.md` · `review-loop.md` 가 driver 문서로 생기고 `.claude/commands/work.md` 가 없으며, CLAUDE.md 커맨드
      표에 `work` 행이 없고 `work.md` 에 시작 표지 줄이 없다
- [ ] 새 설치본의 `harness run work <번호> --dry-run` 첫 줄이 `driver: work <번호> — 9 step(s) from work/clean` 이다
- [ ] `harness run review-loop <번호>` 가 2 로 거부되고 실행 상태가 생기지 않는다
- [ ] 이전 기본값 절을 가진 설정이 옛 조각으로 렌더되고 시작 표지 줄이 있으며 `.claude/commands/work.md` 가 깔린다. 그 설정에서도
      `.ai/workflows/review-loop.md` 가 생기고 render 가 통과한다
- [ ] T1 이 고정한 케이스가 고치지 않고 통과한다
- [ ] 이 리포의 `harness check` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 기본 설정 렌더 | 새 설치본 render | `work.md` · `review-loop.md` 가 driver 문서(그래프 · 다음 표), `.claude/commands/work.md` 없음, CLAUDE.md 커맨드 표에 `work` 행 없음, `work.md` 에 시작 표지 줄 없음 |
| UT-02 | 단계 구성 | `harness steps` 출력의 `work` · `review-loop` | 단계 id · `run` · `on` · `set` · `next` 가 명세 2-1 · 2-2 표와 같다 |
| UT-03 | 구현자 단계 `text` | `harness steps` 출력의 `develop` · `fix` · `finalize` | 모드 이름과 `{issue}`(재시도 · 마무리는 `{mr}` 도)를 담는다 |
| UT-04 | dry-run | 새 설치본 `harness run work 7 --dry-run` | 첫 줄 `driver: work 7 — 9 step(s) from work/clean`, 상태 · 잠금이 생기지 않는다 |
| UT-05 | 단독 실행 거부 | `harness run review-loop 7` | 2, `` error: `review-loop` reads {mr} from a calling workflow — it runs only as a sub-workflow of work ``, 실행 상태 없음 |
| UT-06 | 옛 절 렌더 | 이전 기본값 절을 둔 설정 render | 옛 조각으로 렌더, `script/metric.py step work implement` 줄 있음, `.claude/commands/work.md` 있음, `review-loop.md` 있음 |
| UT-07 | 머리 · 꼬리 조각 | 두 설정의 `work.md` | 같은 머리 · 꼬리 문장이 들어가고 `{{step:` 이 남지 않는다 |

## T6 · chore: driver work 의 착수 · 구현 경로 회귀 케이스 추가

### 상위 Requirement

- relates to #212

### 작업 내용

T5 의 기본 `work` 를 `harness run work <이슈>` 로 끝까지 돌리는 회귀 케이스의 기반을 만들고, 착수 · 구현 경로의 케이스를 더한다. 제품 코드는
바꾸지 않는다.

- 명세 12절 머리(스텁 · 페이크), 12-1 의 "PASS — 단독 경로" · "PASS — 분해 경로" · "재판정이 다르다" · "미커밋 변경" · "착수 불가" ·
  "리뷰 요청 없이 끝남" · "escalate"(`develop`) · "구현자 출력 위반"(`develop`) · "리뷰 상한 · 실패"
- 기반 (`src/test/render-test.sh` 의 새 블록)
  - 대상 리포: 하네스를 설치한 작업 리포와 로컬 bare 원격. 분해 경로는 원격 통합 브랜치에 `docs/plan/<번호>/` 와 명세를 둔다
  - forge: `HARNESS_FORGE_FAKE` 로 `src/test/fake-forge.sh` 와 케이스별 `FAKE_STATE`. 이슈 · 리뷰 요청 · 노트를 상태 파일로 다룬다
  - 구현자 스텁: PATH 앞의 오케스트레이터 벤더 스텁(`developer` 는 서브에이전트 역할이라 오케스트레이터 벤더의 headless 로 돈다). 프롬프트의 모드로
    케이스가 정한 동작을 고른다 — 작업 브랜치 만들기 · 커밋 · bare 원격으로 push, 페이크 forge 상태에 리뷰 요청 만들기, 결과 본문 끝에
    `developer-result` 블록. 받은 프롬프트를 기록한다
  - 리뷰어 스텁: 리뷰어 러너 벤더의 스텁이 케이스가 정한 판정 데이터를 회차마다 낸다
  - 등록부는 `HARNESS_HOME` 으로 테스트 작업 디렉터리 아래에 둔다
- `src/test/fake-forge.sh`: 이 경로에 필요한 상태를 더한다 — task 동기화가 만든 이슈를 목록에 남기기, 이슈 열린 리뷰 요청 목록을 구현자 스텁이
  바꿀 수 있게. 상태 파일이 없으면 지금 출력 그대로다
- 건드릴 파일: `src/test/render-test.sh`, `src/test/fake-forge.sh`, 스텁 파일(테스트 디렉터리 안)

### 완료 조건

- [ ] 단독 경로 PASS 가 끝 done 이고 지나온 단계가 `clean` · `preflight` · `develop` · `develop-check` · `loop`(`review`) · `finalize` ·
      `finalize-check` 이며, task 동기화가 불리지 않고 리뷰 요청이 열려 있다
- [ ] 분해 경로 PASS 가 `preflight` → `task-sync` → `recheck` → `develop` 을 지나고 페이크 트래커에 task 이슈가 생긴다
- [ ] 재판정이 착수 불가면 구현자가 불리지 않고 끝 stop 이다
- [ ] 미커밋 변경이면 `clean` 에서 stop 이고 착수 판정과 구현자가 불리지 않는다
- [ ] 이슈에 열린 리뷰 요청이 있으면 `preflight` 에서 stop 이다
- [ ] 구현자가 `mr` 을 빈 문자열로 내면 `develop-check` 가 돌아 `no_mr` 과 사유 줄을 내고 끝 stop 이다
- [ ] `develop` 의 `escalate` 는 stop 이고 사유가 stderr 에 나온다. 스키마를 어긴 `develop` 출력은 stop 이다
- [ ] 리뷰 종료 코드 3 이면 handoff, 2 면 stop 이고 그 뒤 구현자가 불리지 않는다
- [ ] 구현자 스텁이 받은 프롬프트에 모드 이름과 푼 이슈 번호가 있다
- [ ] 케이스가 원격 · 에이전트 CLI 를 부르지 않고, `HARNESS_FORGE_FAKE` 를 테스트 전체에 내보내지 않는다
- [ ] `script/run-lint-test.sh` 와 `src/test/render-test.sh` 가 통과한다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | PASS — 단독 경로 | 분해 없는 이슈, 구현자 커밋 · push · 리뷰 요청, 리뷰 0, 마무리 `no_change` | 끝 done(0), 지나온 단계 일곱, task 동기화 호출 없음, 리뷰 요청 열림 |
| UT-02 | PASS — 분해 경로 | 원격 통합 브랜치에 분해, 리뷰 0 | `task-sync` · `recheck` 를 지나고 페이크 트래커에 task 이슈 |
| UT-03 | 재판정이 다르다 | 동기화 뒤 두 번째 착수 판정이 착수 불가 | 구현자 호출 없음, 끝 stop |
| UT-04 | 미커밋 변경 | 추적 파일을 고친 작업 트리 | `clean` 에서 stop, 착수 판정 · 구현자 호출 없음 |
| UT-05 | 착수 불가 | 이슈에 열린 리뷰 요청 | `preflight` 에서 stop |
| UT-06 | 리뷰 요청 없이 끝남 | 구현자가 커밋 · push 뒤 `mr = ""`, `status = committed` | `develop-check` 가 돌고 `no_mr` 과 `no review request number was reported`, 끝 stop |
| UT-07 | escalate | `develop` 이 리뷰 요청 없이 `escalate` 와 사유 | 끝 stop, 사유가 stderr 에 |
| UT-08 | 구현자 출력 위반 | `develop` 결과에 스키마를 어긴 블록 | `develop` outcome `failed`, 끝 stop |
| UT-09 | 리뷰 상한 · 실패 | 리뷰 종료 코드 3 / 2 | handoff / stop, 그 뒤 구현자 호출 없음 |
| UT-10 | 구현자 입력 | UT-01 의 기록된 프롬프트 | `구현 모드` 와 이슈 번호가 있다 |

## T7 · chore: driver work 의 리뷰 루프 · 마무리 경로 회귀 케이스 추가

### 상위 Requirement

- relates to #212

### 작업 내용

T6 의 기반으로 하위 절차 `review-loop` 와 마무리 경로의 케이스를 더한다. 제품 코드는 바꾸지 않는다.

- 명세 12-1 의 "수정 뒤 PASS" · "코드가 바뀌지 않은 재시도" · "관측이 보고에 앞선다" · "검증 실패" · "escalate"(`fix`) ·
  "구현자 출력 위반"(`fix` · `finalize`) · "마무리 확인"
- 구현자 스텁에 재시도 · 마무리 모드 동작을 더한다 — 커밋 · push 하거나 하지 않기, 미커밋 변경 남기기, 로컬 커밋만 하기, 페이크 forge 에 스레드
  답글 · 처리 노트 남기기, `handled` 를 담은 결과
- 판정 명령이 받은 `handled` 인자를 기록해 압축 JSON 한 원소인지 본다(받은 argv 기록)
- 건드릴 파일: `src/test/render-test.sh`, 스텁 파일(테스트 디렉터리 안)

### 완료 조건

- [ ] 리뷰 1 → `fix`(커밋 · push) → `fix-check` `committed` → 리뷰 0 → 마무리 → done 이고 리뷰 단계가 두 번, 회차 라벨이 2 다
- [ ] `fix` 가 커밋 없이 끝나면 `no_change` → handoff 이고 리뷰 단계는 한 번이다
- [ ] `committed` 라 보고하고 커밋이 없으면 handoff, `no_change` 라 보고하고 커밋을 push 하면 리뷰가 다시 돈다
- [ ] `fix` 가 미커밋 변경을 남기면 stop, 로컬 커밋만 하고 push 하지 않아도 stop 이다
- [ ] `fix` 의 `escalate` 는 handoff 이고 사유가 stderr 에 나온다
- [ ] 스키마를 어긴 `fix` · `finalize` 출력은 handoff 다
- [ ] `handled` 가 가리킨 답글이 없으면 `remaining:` 줄이 나오고 끝은 done 이다. 마무리 중 커밋이 생기면 `remaining: commits after the passing review`
- [ ] 판정 명령이 받은 `handled` 인자가 압축 JSON 한 원소다
- [ ] 구현자 스텁이 받은 재시도 · 마무리 프롬프트에 모드 이름과 푼 리뷰 요청 번호가 있다
- [ ] `script/run-lint-test.sh` 와 `src/test/render-test.sh` 가 통과한다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 수정 뒤 PASS | 리뷰 1 → 수정 커밋 · push → 리뷰 0 | 끝 done, 리뷰 단계 두 번, 회차 라벨 2 |
| UT-02 | 코드가 바뀌지 않은 재시도 | 리뷰 1 → `fix` 가 커밋 없이 `no_change` | `fix-check` `no_change`, 끝 handoff, 리뷰 단계 한 번 |
| UT-03 | 관측이 보고에 앞선다 | `committed` 보고 + 커밋 없음 / `no_change` 보고 + push 한 커밋 | handoff / 리뷰가 다시 돈다 |
| UT-04 | 검증 실패 | `fix` 가 미커밋 변경을 남김 / 로컬 커밋만 | 둘 다 끝 stop |
| UT-05 | escalate | `fix` 가 `escalate` 와 사유 | 끝 handoff, 사유가 stderr 에 |
| UT-06 | 구현자 출력 위반 | `fix` / `finalize` 결과가 스키마 위반 | 둘 다 끝 handoff |
| UT-07 | 마무리 확인 — 답글 없음 | `handled` 가 답글을 남기지 않은 스레드를 가리킨다 | `remaining: no reply after the review in thread …`, 끝 done |
| UT-08 | 마무리 확인 — 마무리 중 커밋 | 마무리 모드 스텁이 커밋 · push | `remaining: commits after the passing review — not reviewed`, 끝 done |
| UT-09 | `handled` 인자 | 원소 둘인 `handled` | 판정 명령의 인자 하나가 압축 JSON 배열 텍스트 |
| UT-10 | 구현자 입력 | UT-01 의 재시도 · 마무리 프롬프트 기록 | `재시도 모드` · `마무리 모드` 와 리뷰 요청 번호가 있다 |

## T8 · refactor: 절차 절 지우기와 되돌림을 공용 모듈로 이동

### 상위 Requirement

- relates to #212

### 작업 내용

`harness steps <절차> --delete` 의 절 지우기 · 다시 읽어 검증 · 사용자 파일 판정 · 실패 시 되돌림을 명령 모듈 밖의 공용 함수로 옮긴다. T9 의
`harness fix legacy-work` 가 같은 코드를 쓰기 위해서다 — 명령 모듈은 다른 명령 모듈을 불러오지 않는다(#206 3-4). 동작은 바꾸지 않는다.

- 명세 10-3 의 "절을 지우는 범위와 빈 줄 정리는 `harness steps <절차> --delete` 와 같다. 매니페스트 사전 판정 · 사용자 파일 판정 · 실패 시
  되돌림도 같다"
- `src/harness/commands/steps.py` 의 `rename_or_delete_workflow` 에서 위 부분을 공용 모듈 `src/harness/config/edit.py`(`workflow_span` 이 있는
  자리)의 함수 하나로 옮긴다. 하네스 기본 절차를 거부하는 판정과 이름 바꾸기 · 절차 메모 처리는 `steps` 에 남긴다
- `steps --delete` 의 출력 · 종료 코드 · 되돌림 문구는 그대로다
- 건드릴 파일: `src/harness/commands/steps.py`, `src/harness/config/edit.py`

### 완료 조건

- [ ] 절 지우기 · 검증 · 사용자 파일 판정 · 되돌림이 공용 모듈의 함수 하나이고 `steps --delete` 가 그것을 부른다
- [ ] `harness steps` 의 기존 회귀 케이스(지우기 · 이름 바꾸기 · 사용자 파일 거부 · 잘못된 매니페스트 줄 · 되돌림)가 고치지 않고 통과한다
- [ ] `script/project/check-cli.py imports` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 지우기 그대로 | 프로젝트 절차에 `harness steps <절차> --delete` | 지우기 전과 같은 출력 · 파일 결과 |
| UT-02 | 되돌림 그대로 | 지우면 검증이 실패하는 설정 | `reverted — the config is unchanged`, 2, 파일 그대로 |
| UT-03 | 사용자 파일 · 매니페스트 판정 그대로 | 사용자 파일이 있는 대상 / 잘못된 매니페스트 줄 | 기존 케이스의 기대값 그대로 |
| UT-04 | 의존 방향 | `script/project/check-cli.py imports` | 위반 없음 |

## T9 · feat: doctor 의 이전 기본값 work 항목과 fix legacy-work 추가

### 상위 Requirement

- relates to #212

### 작업 내용

설치 때 기본 설정 전체를 복사받아 `[workflows.work]` 가 이전 기본값으로 남은 설치본을 doctor 가 짚고, `harness fix legacy-work` 가 그 절을 지워
지금의 내장 기본 절차로 옮기게 한다. UI Doctor 화면이 그 조치를 고르게 한다.

- 명세 10-3 전체, 11절의 `src/ui/lib/doctor.js` 행, 12-1 의 "옛 절"(doctor 부분) · "`fix legacy-work`" · "비교 키", 12-3
- 이전 기본값 목록: doctor 와 `fix legacy-work` 가 함께 쓰는 상수 하나를 공용 모듈 `src/harness/config/workflows.py` 에 둔다. 항목마다 그때 내장
  기본값이 낸 `[workflows.work]` 표 전체이고, 이 task 가 넣는 항목은 명세 10-1 의 agent 절 하나다. 항목을 더하면 doctor 와 fix 가 함께 따른다
- "같다" 판정 함수(같은 모듈): 절차 키(`title` · `execute` · `max_steps` · `max_visits` · `steps`)와 단계마다 모든 키를 비교한다. 단계의 `kind` 는
  `type` 으로 읽는다. 표 안의 키 순서는 보지 않고 단계 순서는 본다. 키가 더 있거나 빠졌거나 값이 다르면 같지 않다
- doctor `config` 절 항목(`src/harness/readiness/items.py`): 프로젝트 레이어(#207)의 `[workflows.work]` 가 목록의 한 항목과 같으면 `warn` ·
  `workflows.work is a previous default` · 명세 10-3 의 detail. 병합된 설정이 아니라 프로젝트 레이어 파일의 절을 본다
- `harness fix legacy-work`(`src/harness/commands/fix.py`): `FIXES` 에 `legacy-work`, 사용법 한 줄
  `legacy-work  remove a [workflows.work] that equals a previous default`. 명세 10-3 표의 세 상태와 출력 · 종료 코드. 지우기는 T8 의 공용 함수로
  하고, 설정을 다시 읽어 검증한 뒤 render 한다
- UI: `src/ui/lib/doctor.js` 의 조치 고르기 표에 `config` · `workflows.work is a previous default` · — · `legacy-work` 행과 명세 10-3 의 제목 ·
  본문. `src/ui/lib/actions.js` 의 `doctorFix` 조치 표에 `legacy-work` → `harness fix legacy-work`. origin 항목 본문 "/work 가 원격을 가져오지
  못하고 멈춥니다" → "work 절차가 원격을 가져오지 못하고 멈춥니다"
- `README.md` 명령 표의 `harness fix hooks|verify|legacy-work` — `legacy-work` 는 이전 기본값과 같은 `[workflows.work]` 를 지워 지금의 내장 기본
  절차로 옮긴다
- 건드릴 파일: `src/harness/config/workflows.py`, `src/harness/readiness/items.py`, `src/harness/commands/fix.py`, `src/ui/lib/doctor.js`,
  `src/ui/lib/actions.js`, `src/ui/lib/doctor.test.js`, `README.md`, `src/test/render-test.sh`, 판정 함수의 단위 테스트
  `src/test/unit/test_previous_work_defaults.py`

### 완료 조건

- [ ] 이전 기본값 절을 가진 설정에서 doctor 가 `config` 절에 `workflows.work is a previous default` 를 `warn` 으로 낸다
- [ ] `fix legacy-work` 가 이전 기본값 절을 지우고 render 해 `work.md` 가 driver 문서가 되고 `.claude/commands/work.md` 가 걷힌다
- [ ] 고친 절이면 2 와 `error: workflows.work differs from every previous default — edit it yourself`, 파일 그대로다
- [ ] 절이 없으면 0 과 `fix: workflows.work is not in harness.toml — nothing to do`, 파일 그대로다
- [ ] 이전 기본값에 `title` 이나 `execute` 를 더한 절, 한 단계에 키 하나를 더한 절은 doctor 가 짚지 않고 fix 가 2 다. 키 순서만 다른 절과
      `kind` 로 적은 절은 같다고 본다
- [ ] 지우기 범위 · 빈 줄 정리 · 매니페스트 사전 판정 · 사용자 파일 판정 · 되돌림이 `steps --delete` 와 같은 코드다
- [ ] UI 가 그 항목을 명세 10-3 의 제목 · 본문과 조치 `legacy-work` 로 옮기고, 다른 절의 같은 문구에는 조치를 붙이지 않으며, origin 항목 본문에
      `/work` 가 없다
- [ ] `harness help` 의 `fix` 사용법과 README 명령 표에 `legacy-work` 가 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 같다 — 원문 | 명세 10-1 원문 표 | 같다 |
| UT-02 | 같다 — 키 순서 · `kind` | 단계 안 키 순서를 바꾼 표 / `type` 대신 `kind` 로 적은 표 | 같다 |
| UT-03 | 다르다 | `title` 을 더한 표 · `execute` 를 더한 표 · 한 단계에 `next` 를 더한 표 · 단계 순서를 바꾼 표 · `run` 값을 바꾼 표 | 다르다 |
| UT-04 | doctor 옛 절 (render-test) | T1 의 도우미로 이전 기본값 절을 둔 설정 | `config` 절에 `warn` `workflows.work is a previous default` |
| UT-05 | `fix legacy-work` (render-test) | 이전 기본값 절 | 0, 절이 지워지고 `work.md` 가 driver 문서, `.claude/commands/work.md` 없음 |
| UT-06 | 고친 절 (render-test) | 이전 기본값 절에 단계 하나를 더한 설정 | 2 와 `differs from every previous default`, 파일 그대로, doctor 항목 없음 |
| UT-07 | 절 없음 (render-test) | `[workflows.work]` 가 없는 설정 | 0 과 `nothing to do`, 파일 그대로 |
| UT-08 | 사용자 파일 판정 (render-test) | 렌더가 덮을 경로에 사용자 파일 | `steps --delete` 와 같은 거부와 되돌림, 파일 그대로 |
| UT-09 | UI 문구 (`doctor.test.js`) | `config` 의 그 항목 / 다른 절의 같은 문구 / origin 항목 | 제목 · 본문 · 조치 `legacy-work` / 조치 없음 / 본문에 `/work` 없음 |

## T10 · docs: work 진입점과 리뷰 루프 서술을 driver 절차 기준으로 갱신

### 상위 Requirement

- relates to #212

### 작업 내용

T5 · T9 로 생긴 사실 — 기본 `work` 의 진입점 `harness run work <이슈>`, 하위 절차 `review-loop`, 판정 명령, 옛 절 되돌림과 이행 — 을 사람용
문서와 에이전트가 읽는 서술에 적는다.

- 명세 11절의 행 가운데 T3 · T9 가 고친 것(`script/README.md` 의 `work-check.sh` 행, README 명령 표의 `work-check` · `legacy-work`,
  `doctor.js`)을 뺀 나머지
- `src/templates/generated/CLAUDE.md`: 흐름 그림의 `/work <이슈>  →  work-preflight.sh …` 줄을 `harness run work <이슈>` 에서 시작하는 driver
  흐름(작업 트리 확인 → 착수 판정 → [분해 있음] task 동기화 · 재판정 → developer → 구현 판정 → review-loop(리뷰 ⇄ 수정 · 수정 판정) → 마무리)으로
- `src/templates/agents/code-reviewer.md` summary: "`work` 의 리뷰 루프(`review-loop`) 수단이 아니다 — 리뷰 루프는 `script/review-mr.sh` 하나만 쓴다"
- `src/templates/agents/security-guard.md`: summary 와 본문의 "`/work` 루프" → "`work` 의 리뷰 루프(`review-loop`)"
- `src/templates/managed/docs/workflow/flow.md`: 머리 그림과 절 제목의 `/work` → `harness run work`, 흐름 그림을 명세 2절의 단계로, "루프가
  멈추는 조건" 표의 "절차" 칸을 구현 판정 · 수정 판정(`script/work-check.sh`)으로, 옛 절로 되돌리는 법과 doctor · `fix legacy-work` 한 단락
- `src/templates/managed/docs/workflow/changing.md`: 기본 절차 `work` 는 driver 이고 리뷰 루프는 `workflows.review-loop` 라는 것, agent 로
  되돌리는 법(명세 10-1), 구현자에게 줄 프로젝트 지시는 역할 메모에 둔다는 것
- `src/templates/managed/script/README.md`: `work-preflight.sh` 의 호출 시점 "착수 판정 · 착수 재판정 단계", `review-mr.sh` 의 호출 시점
  "`review-loop` 의 리뷰 단계"
- 착수 판정 명령의 머리 설명(`src/harness/commands/preflight.py` 의 머리 설명과 shim `src/templates/managed/script/work-preflight.sh` 머리글):
  "착수 전과 구현 위임 직전에 같은 명령을 돌린다" → "착수 전에 돌리고, 분해 경로는 task 동기화 뒤에 한 번 더 돌린다"
- `src/templates/workflows/retro/signals.md`: "커맨드 직후 교정 발언 집중" 행 → "대화형 절차 직후 교정 발언 집중". driver 절차는 헤드리스로 돌아
  대화 기록이 남지 않는다는 것
- `README.md` "업데이트": 기존 설치본의 `work` 이행 — 이전 기본값 절이 남아 옛 절차로 돈다는 것, doctor 의 항목, `harness fix legacy-work`,
  되돌릴 때 넣을 절(명세 10-1 원문)
- render 로 이 리포의 사본(`docs/workflow/` · `script/README.md` · `script/work-preflight.sh`)과 생성 파일(`CLAUDE.md` · `AGENTS.md` ·
  `.claude/agents/` · `.codex/agents/` · `.ai/workflows/retro.md` 등)을 갱신한다
- 건드릴 파일: 위 정본들, `README.md`, render 로 갱신되는 사본 · 생성 파일

### 완료 조건

- [ ] 생성되는 CLAUDE.md 흐름 그림이 `harness run work <이슈>` 의 driver 흐름이다
- [ ] 두 역할 어댑터와 그 생성물에 "`/work` 루프" 표기가 없다
- [ ] `flow.md` · `changing.md` 가 명세 11절의 사실을 담고 `/work` 를 기본 진입점으로 적지 않는다
- [ ] `script/README.md` · 착수 판정 머리 설명 · `retro/signals.md` 가 명세 11절의 문안이다
- [ ] README "업데이트" 에 이행 안내와 명세 10-1 원문 절이 있다
- [ ] `harness check` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 정본 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | `/work` 표기 | 새 설치본의 `CLAUDE.md` · `.claude/agents/code-reviewer.md` · `security-guard.md` · `docs/workflow/flow.md` | 기본 진입점으로서의 `/work <이슈>` · "`/work` 루프" 표기가 없다 |
| UT-03 | 되돌림 안내 | `README.md` "업데이트" · `docs/workflow/changing.md` | 명세 10-1 원문 절과 `harness fix legacy-work` 가 있다 |

## T11 · docs: 아키텍처 · 용어 · 담당 범위 · 테스트 문서에 driver work 반영

### 상위 Requirement

- relates to #212

### 작업 내용

T2 ~ T9 로 생긴 사실을 에이전트가 근거로 읽는 보호 문서에 적는다. 명세 13절 "보호 문서 개정 범위" 의 표를 그대로 반영한다.

**보호 문서를 수정하는 task 다.** `.ai/project/scope.md` · `architecture.md` · `glossary.md` · `testing.md` 의 수정은 2026-10-09 결정 게이트에서
사용자가 허용한 범위다. 그 범위는 명세 13절 표의 행이고, 표 밖의 문장은 고치지 않는다. 권한 설정 · 가드에 걸리면 사람이 대응한다.

- 문안은 앞 명세(#206 → #207 → #208 · #209 · #210 → #211)가 고친 문장 위에 더한다. 앞 명세가 들인 용어(`shim` 등)는 그대로 쓴다
- `.ai/project/scope.md` "할 수 있는 일" 의 `run` 항목: #208 이 고친 문장 가운데 기본 절차 문장만 명세 13절 문안으로 바꾼다. 나머지 문장과 #207 이
  끝에 더한 문장은 그대로다
- `.ai/project/architecture.md`
  - "구성 요소" 의 CLI 패키지 항목(#206 · #210 · #211 이 고친 것)에 `work-check` 와 `developer-result` 문장을 덧붙인다
  - 같은 절의 대상 리포 `script/` 항목(#211 이 고친 것)에 `work-check.sh` shim 문장을 덧붙인다
  - "데이터 흐름" 의 절차 실행: #211 이 고친 리뷰 루프 문장을 명세 13절 문안으로 바꾼다. `(…)` 는 앞 명세가 고친 괄호를 그대로 옮기고,
    #208 이 더한 `harness run` 의 실행 방식 문장은 그대로 둔다
  - "신뢰 경계" 의 들어오는 입력: #208 이 더한 agent 블록 결과 본문 항목 끝에 구현자 결과 문장을 덧붙인다
  - "새 코드를 둘 곳": 새 항목 — `work` 판정 규칙은 `src/harness/commands/work_check.py`, 기본 절차 `work` · `review-loop` 의 단계와 배선은
    `src/templates/defaults.toml`
- `.ai/project/glossary.md`: "용어" 새 행 `구현자 결과` · `판정 명령` · `리뷰 루프` · `구현자 모드`, "폐기된 별칭" 새 행 `/work <이슈>` → `harness run work <이슈>`
- `.ai/project/testing.md` "외부 의존을 어떻게 다루나" 의 에이전트 CLI 항목(#208 이 고친 것) 끝에 구현자 스텁 문장을 덧붙인다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 네 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/scope.md`, `.ai/project/architecture.md`, `.ai/project/glossary.md`, `.ai/project/testing.md`, render 로 갱신되는
  `.ai/AI_AGENT.md`

### 완료 조건

- [ ] 네 문서가 명세 13절 표의 행마다 그 문안을 담는다
- [ ] 13절 표 밖의 문장과 앞 명세가 고친 문장이 바뀌지 않았다
- [ ] 문안 안의 경로 · 명령 이름이 실제 자리(`src/harness/commands/work_check.py` · `src/harness/schemas/developer-result.json` ·
      `src/templates/defaults.toml` · `script/work-check.sh`)와 맞는다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 가 네 문서와 일치하고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 네 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 반영 확인 | `.ai/AI_AGENT.md` | 1장 `run` 항목의 기본 절차 문장, 2장 새 용어 넷과 폐기된 별칭 행, 5장 구성 요소 · 데이터 흐름 · 신뢰 경계 · 새 코드를 둘 곳에 명세 13절 문안 |
| UT-03 | 범위 | 네 문서의 diff | 명세 13절 표의 위치에만 변경이 있다 |

## T12 · chore: 이 리포의 work 를 내장 기본값 driver 절차로 전환

### 상위 Requirement

- relates to #212

### 작업 내용

이 리포 루트의 `harness.toml` 에서 `[workflows.work]` 절을 지워 이 리포의 `work` 가 내장 기본값(driver)으로 돌게 한다. 이 리포의 다음 `work`
실행부터 진입점은 `harness run work <이슈>` 다.

- 명세 10-4
- 루트 `harness.toml` 의 `[workflows.work]` 절만 지운다. 그 절은 이전 기본값과 같으므로 `src/bin/harness fix legacy-work` 로 지우고 render 한다.
  다른 절은 그대로다
- render 결과: `.claude/commands/work.md` 가 걷히고, `.ai/workflows/work.md` · `review-loop.md` 가 driver 문서이며, `CLAUDE.md` · `AGENTS.md` 의
  커맨드 표에서 `work` 행이 빠진다
- 건드릴 파일: `harness.toml`, render 로 갱신 · 정리되는 생성 파일과 `.harness/generated` · `.harness/managed`

### 완료 조건

- [ ] 루트 `harness.toml` 에 `[workflows.work]` 가 없고 다른 절은 바뀌지 않았다
- [ ] `.claude/commands/work.md` 가 없고 `.ai/workflows/work.md` 가 driver 문서(그래프 · 다음 표, 시작 표지 줄 없음)다
- [ ] `harness doctor` 에 `workflows.work is a previous default` 가 없다
- [ ] `harness run work <번호> --dry-run` 첫 줄이 `driver: work <번호> — 9 step(s) from work/clean` 이다
- [ ] `harness check` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/212-drive-work-loop` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 전환 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 커맨드 정리 | 전환 뒤 작업 트리 | `.claude/commands/work.md` 없음, `CLAUDE.md` 커맨드 표에 `work` 행 없음 |
| UT-03 | 실행 계획 | `src/bin/harness run work 1 --dry-run` | driver 첫 줄과 구현자 단계의 러너 줄, 상태가 생기지 않는다 |
| UT-04 | doctor | `src/bin/harness doctor` | `config` 절에 이전 기본값 항목이 없다 |
