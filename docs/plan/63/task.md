# #63 task

## T1 · fix: 사용 기록의 브랜치 유형을 설정 값으로 분류

### 상위 Requirement

- relates to #63

### 작업 내용

`usage-log.sh` 의 브랜치 유형 판정이 보호 브랜치(`main|development`)와 태그 목록을 본문에 박아 두고 있어,
설정의 보호 브랜치 `develop` 이 `protected` 로 분류되지 않고 `commit.tags` 를 바꿔도 따라가지 않는다.
판정을 `script/harness.env` 의 `PROTECTED_BRANCHES`(공백 구분) · `COMMIT_TAGS`(`|` 구분)로 바꾼다.

- 명세 1절(값의 출처) · 2절(분류 규칙) · 4절(기록 형식 불변) · 5절의 분류 케이스 셋
- 판정은 목록의 항목 단위 일치로 한다. `|` 를 담은 값을 `case` 패턴 자리에 변수로 넣지 않는다
- 판정 순서: 빈 이름 `-` → 보호 브랜치와 정확히 같음 `protected` → `<태그>/` 접두사이고 태그가 목록 항목과 정확히 같음 그 태그 → 그 밖 `unknown`
- 설정 값이 비면 그 판정은 아무 브랜치에도 맞지 않는다
- 건드릴 파일: `src/templates/managed/script/usage-log.sh`, `src/templates/managed/script/test-usage-log.sh`, render 로 갱신되는 `script/` 사본

### 완료 조건

- [ ] `usage-log.sh` 본문에 브랜치 이름·태그 이름 리터럴이 없다
- [ ] `PROTECTED_BRANCHES` 의 모든 항목(`develop` 포함)의 브랜치에서 기록하면 5번째 필드가 `protected` 다
- [ ] `COMMIT_TAGS` 의 항목으로 만든 `<태그>/<이름>` 브랜치의 5번째 필드가 그 태그다
- [ ] 설정 태그에 없는 접두사의 브랜치와 슬래시 없이 태그 이름만인 브랜치가 `unknown` 이다
- [ ] 기록 한 줄의 필드 수가 5 로 유지된다
- [ ] 회귀 테스트가 브랜치·태그 이름을 `script/harness.env` 값에서 가져온다
- [ ] `src/bin/harness render` 뒤 `script/` 사본이 정본과 같고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/63-usage-log-config-values` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 보호 브랜치 전부가 protected 로 분류된다 | 임시 git 저장소에서 `PROTECTED_BRANCHES` 의 항목마다 그 이름의 브랜치를 만들고 기록 | 항목마다 기록 한 줄, 5번째 필드 `protected` |
| UT-02 | 기본 통합 브랜치도 protected 다 | `PROTECTED_BRANCHES` 에 `develop` 이 있는 설정에서 `develop` 브랜치로 기록 | 5번째 필드 `protected` |
| UT-03 | 태그 브랜치는 그 태그로 분류된다 | `COMMIT_TAGS` 의 항목마다 `<태그>/x` 브랜치를 만들고 기록 | 5번째 필드가 그 태그 |
| UT-04 | 설정 밖 접두사는 unknown 이다 | `COMMIT_TAGS` 에 없는 접두사의 `<접두사>/x` 브랜치로 기록 | 5번째 필드 `unknown` |
| UT-05 | 태그 이름만인 브랜치는 unknown 이다 | `COMMIT_TAGS` 첫 항목과 같은 이름(슬래시 없음)의 브랜치로 기록 | 5번째 필드 `unknown` |

## T2 · fix: 설정을 읽지 못하면 사용 기록을 남기지 않고 종료

### 상위 Requirement

- relates to #63

### 작업 내용

`usage-log.sh` 는 `script/harness.env` 를 확인 없이 source 하므로, 파일이 없거나 읽을 수 없으면 셸이 비0 으로
끝나 "항상 0 으로 끝난다" 계약을 깬다. source 전에 파일이 있고 읽을 수 있는지 확인하고, 아니면 아무것도
기록하지 않고 출력 없이 종료 코드 0 으로 끝낸다.

- 명세 3절(설정을 읽지 못할 때) · 5절의 설정 누락 케이스
- 기록 파일을 만들거나 줄을 더하지 않는다. stdout·stderr 에 아무것도 내지 않는다
- 스크립트 머리글과 `script/README.md` 의 `usage-log.sh` 행의 "항상 0 으로 끝난다" 문구는 그대로 둔다
- 건드릴 파일: `src/templates/managed/script/usage-log.sh`, `src/templates/managed/script/test-usage-log.sh`, render 로 갱신되는 `script/` 사본

### 완료 조건

- [ ] `script/harness.env` 가 없는 배치에서 기록기를 부르면 종료 코드가 0 이다
- [ ] 그때 기록 파일이 생기지 않고, 이미 있던 기록 파일에 줄이 늘지 않는다
- [ ] 그때 stdout·stderr 가 비어 있다
- [ ] 설정 누락 테스트가 이 리포의 `script/harness.env` 를 지우거나 옮기지 않고, 기록기를 임시 디렉터리에 배치해 설정이 없는 상태를 만든다
- [ ] "항상 0 으로 끝난다" 계약 문구(스크립트 머리글, `script/README.md`)가 바뀌지 않는다
- [ ] `src/bin/harness render` 뒤 `script/` 사본이 정본과 같고 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/63-usage-log-config-values` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 설정 누락 시 종료 코드 0 | 임시 디렉터리에 `usage-log.sh` · `usage-vocab.sh` 만 두고(`harness.env` 없음) 기록 위치를 환경 변수로 지정해 호출 | 종료 코드 0 |
| UT-02 | 설정 누락 시 새 기록 파일이 생기지 않는다 | UT-01 과 같은 배치, 존재하지 않는 기록 경로 | 기록 파일 없음 |
| UT-03 | 설정 누락 시 기존 기록에 줄이 늘지 않는다 | UT-01 과 같은 배치, 한 줄이 든 기존 기록 파일 | 줄 수 1 그대로 |
| UT-04 | 설정 누락 시 출력이 없다 | UT-01 과 같은 배치 | stdout·stderr 모두 빈 문자열 |
