# #221 task

## T1 · chore: 계약 시험 공용 준비부와 명령 가드 셸 회귀 테스트 이관

### 상위 Requirement

- relates to #221

### 작업 내용

대상 리포의 셸 회귀 테스트를 소스 리포의 단위 시험으로 옮기는 첫 task 다. 계약 시험이 함께 쓰는 준비부를 두고, 명령 가드 셸 테스트의 검사 줄을 전부 옮긴다.
셸 테스트와 shim 은 지우지 않는다 — 옮긴 시험이 지금 트리에서 통과하고, 셸 테스트는 T21 이 지운다.

- 근거: 명세 12-1, 12-4 의 "12-1 의 이관 시험" 행
- 공용 준비부(`src/test/unit/` 의 보조 모듈)가 하는 일
  - 임시 git 리포를 하네스 루트로 만들고, `src/bin/harness install` 로 하네스를 깐다. `HARNESS_HOME` 은 임시 디렉터리다
  - 원격은 로컬 bare 리포, forge 는 `HARNESS_FORGE_FAKE` 로 끼운 `src/test/fake-forge.sh`, forge CLI · 에이전트 CLI 는 PATH 앞 스텁이다
  - 설치한 CLI(`.harness/bin/harness`)를 하위 프로세스로 부르고 종료 코드 · 표준 출력 · 표준 오류를 돌려준다
  - 끝나면 임시 디렉터리를 지운다
- 명령 가드: `src/templates/managed/script/test-bash-guard.sh` 의 검사 줄을 옮긴다
  - 형태: `harness bash-guard` 에 훅 입력 JSON 을 표준 입력으로 주는 계약 시험
  - 판정 기준: 그 검사 줄의 기대값(0 · 2, 표준 오류의 사유, 사용 기록 라벨)
  - 입력은 셸 테스트의 `probe` 와 같은 규칙으로 이스케이프해 만든다
  - 옮기는 절: 차단 표, 통과 케이스, 작업 트리 절, 브랜치에 따라 갈리는 commit 판정, 비교 값 검사
  - 망가뜨린 가드 사본 검사: 같은 약속(가드 하나를 끄면 그 가드의 표만 통과한다)을 본다. 그 가드를 끈 가드 모듈 사본으로 돌린다
  - shim 자신의 형태 · 문구만 보던 줄은 옮기지 않는다
- 이 리포 `harness.toml`: `[verify]` 의 "Python 단위 테스트" 단계 `paths` 에 `src/bin/**` 를 더한다. 계약 시험이 진입 스크립트를 거치기 때문이다(12-1). 고친 뒤 render 로 생성물을 갱신한다
- 건드릴 파일
  - `src/test/unit/` 의 새 시험 모듈과 보조 모듈
  - `harness.toml`
  - render 로 갱신되는 생성물

### 완료 조건

- [ ] `test-bash-guard.sh` 의 검사 줄(shim 형태만 보던 줄 제외)마다 대응하는 단위 시험이 있고, 기대값이 같다
- [ ] 계약 시험이 설치한 CLI 를 하위 프로세스로 부른다
- [ ] 시험이 임시 `HARNESS_HOME` 밖에 등록부 · 캐시를 만들지 않는다. 리포에 `__pycache__` 를 남기지 않는다
- [ ] `test-bash-guard.sh` 와 `render-test.sh` 가 바뀌지 않고 통과한다
- [ ] "Python 단위 테스트" 단계의 `paths` 에 `src/bin/**` 가 있다
- [ ] `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 가드 6종의 차단 | 셸 테스트 차단 표의 케이스 전부 | 각 2, 표준 오류의 사유가 셸 테스트 기대와 같음 |
| UT-02 | 통과 케이스 | 셸 테스트 통과 케이스 전부 | 0 |
| UT-03 | 작업 트리 절 | 훅 작업 디렉터리와 `cd` · `-C` 대상이 다른 케이스 | 셸 테스트 기대값 |
| UT-04 | 브랜치에 따라 갈리는 commit 판정 | 작업 브랜치 임시 리포와 보호 브랜치 임시 리포의 `git commit` 케이스 | 작업 브랜치 0 · 보호 브랜치 2 |
| UT-05 | 망가뜨린 가드 | force push · write-doc 가드를 하나씩 끈 사본에 차단 표 | 끈 가드의 표만 0, 나머지 표는 2 |
| UT-06 | 차단 사용 기록 | 차단되는 케이스 하나 | `block bash-guard <라벨>` 줄이 셸 테스트 기대와 같음 |
| UT-07 | 준비부 정리 | 시험 한 번 | 임시 디렉터리 밖에 변화가 없고 `__pycache__` 가 없음 |

## T2 · chore: 시크릿 스캔 · 사용 기록 셸 회귀 테스트 이관

### 상위 Requirement

- relates to #221

### 작업 내용

시크릿 스캔과 사용 기록의 셸 테스트 검사 줄을 T1 의 공용 준비부로 계약 시험에 옮긴다. 셸 테스트는 지우지 않는다.

- 근거: 명세 12-1
- 시크릿 스캔: `src/templates/managed/script/test-secret-scan.sh`
  - 대상: `harness secret-scan [--staged]`
  - 판정 기준: 더한 줄만 본다, 값을 출력하지 않는다, 0 · 1 · 2, 허용 표지 `harness:allow-secret`
- 사용 기록: `src/templates/managed/script/test-usage-log.sh`
  - 대상: `harness usage log` · `harness usage report`
  - 판정 기준: 기록에 남기지 않는 것, 상한 신호, 기록 없음 처리, 줄 형식 · 어휘
  - 기록 파일은 임시 디렉터리에 둔다
- shim 을 부르던 줄은 하위 명령을 부르는 줄로 옮긴다. shim 자신의 형태 · 문구만 보던 줄은 옮기지 않는다
- 건드릴 파일: `src/test/unit/` 의 새 시험 모듈 둘

### 완료 조건

- [ ] `test-secret-scan.sh` · `test-usage-log.sh` 의 검사 줄마다 대응하는 단위 시험이 있고, 기대값이 같다
- [ ] 자격증명 견본을 잡는 시험에서 표준 출력 · 표준 오류에 견본 값이 없다
- [ ] 두 셸 테스트와 `render-test.sh` 가 바뀌지 않고 통과한다
- [ ] `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 잡는 쪽 | 셸 테스트의 자격증명 견본을 더한 커밋 대상 | 1, 출력에 값이 없음 |
| UT-02 | 지나가는 쪽 | 셸 테스트의 오탐 견본 | 0 |
| UT-03 | 허용 표지 | `harness:allow-secret` 을 단 견본 줄 | 0 |
| UT-04 | `--staged` 와 인수 검사 | 인덱스에만 있는 견본, 모르는 옵션 | 셸 테스트 기대값(1 · 사용법과 2) |
| UT-05 | 사용 기록 줄 | 셸 테스트의 `usage log` 호출 | 기록 줄의 형식 · 어휘가 셸 테스트 기대와 같음 |
| UT-06 | 남기지 않는 것 | 자유 문장 · 사람 이름 모양 · 80자 넘는 상세 | 셸 테스트 기대대로 걸러짐 |
| UT-07 | 집계 | 셸 테스트의 기록 견본과 기록 없음 | `usage report` 출력이 셸 테스트 기대와 같음 |

## T3 · chore: 리뷰 루프 셸 회귀 테스트 이관

### 상위 Requirement

- relates to #221

### 작업 내용

리뷰 루프 셸 테스트의 검사 줄을 T1 의 공용 준비부로 계약 시험에 옮긴다. 셸 테스트는 지우지 않는다.

- 근거: 명세 12-1
- 대상: `src/templates/managed/script/test-review-loop.sh` 한 파일 전부. `harness review` · `harness review post` 를 부른다
- 판정 기준: 그 검사 줄의 기대값
  - 회차 라벨 · 상한 · 등급 판정 · 종료 코드 0 · 1 · 2 · 3
  - 반복 지적의 요약 기록
  - 판정 데이터 검증과 거부
  - 등록된 요약 · 인라인 댓글
  - 리뷰어 러너 점검
  - forge 페이크가 기록한 호출
- 리뷰어 · 러너 상황은 샌드박스 `harness.toml` 과 설치한 고정 사본의 벤더 선언 사본으로 만든다. 에이전트 CLI 는 PATH 앞 스텁이다
- shim 을 부르던 줄은 하위 명령을 부르는 줄로 옮긴다. shim 자신의 형태 · 문구만 보던 줄은 옮기지 않는다
- 건드릴 파일: `src/test/unit/` 의 새 시험 모듈

### 완료 조건

- [ ] `test-review-loop.sh` 의 검사 줄마다 대응하는 단위 시험이 있고, 기대값이 같다
- [ ] 클론이 바뀌어도 이어 세는 케이스가 git 공통 디렉터리가 다른 두 클론으로 돈다
- [ ] `test-review-loop.sh` 와 `render-test.sh` 가 바뀌지 않고 통과한다
- [ ] `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 회차 라벨과 상한 | 셸 테스트의 회차 진행 케이스 | 라벨 · 종료 코드가 셸 테스트 기대와 같음 |
| UT-02 | 등급 판정 | blocker · major · minor 조합의 판정 데이터 | 0 · 1 이 셸 테스트 기대와 같음 |
| UT-03 | 판정 데이터 거부 | 스키마를 어긴 판정 데이터 | 등록하지 않고 셸 테스트 기대 종료 코드 |
| UT-04 | 반복 지적 | 같은 파일 major 회차 연속 · 끊기는 기록 · 조회 실패 | 셸 테스트 기대 종료 코드와 `note:` · `warning:` 줄 |
| UT-05 | 등록 댓글 | 요약 · 인라인 등록 | 페이크가 기록한 본문 · 기록 줄이 셸 테스트 기대와 같음 |
| UT-06 | 러너 점검 | 러너 스텁 없음 · 있음 | 셸 테스트 기대값 |

## T4 · chore: 착수 판정 · task 동기화 셸 회귀 테스트 이관

### 상위 Requirement

- relates to #221

### 작업 내용

착수 판정과 task 동기화의 셸 테스트 검사 줄을 T1 의 공용 준비부로 계약 시험에 옮긴다. 셸 테스트는 지우지 않는다.

- 근거: 명세 12-1
- 착수 판정: `src/templates/managed/script/test-work-preflight.sh`
  - 대상: `harness preflight <이슈>`
  - 판정 기준: 열린 이슈의 `plan` · `standalone`, 닫힌 이슈와 읽히지 않는 이슈의 착수 불가, 종료 코드
- task 동기화: `src/templates/managed/script/test-sync-task-issues.sh`
  - 대상: `harness sync-tasks <이슈> [--dry-run]`
  - 판정 기준: 분해 절이 생성 호출의 어느 인수로 들어가는지, 없는 이슈만 만드는지, 매핑 출력, 경합
- 분해(`docs/plan/<번호>/`)가 든 원격 통합 브랜치는 로컬 bare 원격에 만든다
- shim 을 부르던 줄은 하위 명령을 부르는 줄로 옮긴다. shim 자신의 형태 · 문구만 보던 줄은 옮기지 않는다
- 건드릴 파일: `src/test/unit/` 의 새 시험 모듈 둘

### 완료 조건

- [ ] `test-work-preflight.sh` · `test-sync-task-issues.sh` 의 검사 줄마다 대응하는 단위 시험이 있고, 기대값이 같다
- [ ] 두 셸 테스트와 `render-test.sh` 가 바뀌지 않고 통과한다
- [ ] `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 분해가 있는 열린 이슈 | 원격 통합 브랜치에 `docs/plan/<번호>/` | `plan` 과 셸 테스트 기대 종료 코드 |
| UT-02 | 분해가 없는 열린 이슈 | 분해 없음 | `standalone` |
| UT-03 | 착수 불가 | 닫힌 이슈 · 읽히지 않는 이슈 | 셸 테스트 기대 종료 코드와 사유 |
| UT-04 | 생성 호출의 인수 | 분해의 task 절 | 페이크가 기록한 제목 · 본문 · 라벨 · 담당자가 셸 테스트 기대와 같음 |
| UT-05 | 있는 이슈는 만들지 않음 | 같은 제목의 이슈가 있는 페이크 | 생성 호출 없음 |
| UT-06 | `--dry-run` 매핑 | 분해와 기존 이슈 | 매핑 출력이 셸 테스트 기대와 같고 생성 호출 없음 |

## T5 · chore: 이월 이슈 · 되감기 셸 회귀 테스트 이관

### 상위 Requirement

- relates to #221

### 작업 내용

이월 이슈와 되감기의 셸 테스트 검사 줄을 T1 의 공용 준비부로 계약 시험에 옮긴다. 셸 테스트는 지우지 않는다.

- 근거: 명세 12-1
- 이월 이슈: `src/templates/managed/script/test-carryover-issue.sh`
  - 대상: `harness carryover <원본이슈> <제목> <본문파일>`
  - 판정 기준: 본문 검사 · 제목 검사 · 상속 값 누락 · 중복 제목 · 드라이런 · 인수 검증
- 되감기: `src/templates/managed/script/test-rollback-work.sh`
  - 대상: `harness rollback`
  - 판정 기준: 닫는 것과 남기는 것, `--dry-run`, `--yes`, 이 클론 · 다른 클론의 착수 잠금, 잠금 상태를 읽지 못할 때
- 착수 잠금 케이스의 원격은 로컬 bare 리포다. 다른 클론은 같은 원격을 따로 clone 한 리포다
- shim 을 부르던 줄은 하위 명령을 부르는 줄로 옮긴다. shim 자신의 형태 · 문구만 보던 줄은 옮기지 않는다
- 건드릴 파일: `src/test/unit/` 의 새 시험 모듈 둘

### 완료 조건

- [ ] `test-carryover-issue.sh` · `test-rollback-work.sh` 의 검사 줄마다 대응하는 단위 시험이 있고, 기대값이 같다
- [ ] 되감기 시험이 `--yes` 없이 묻는 경로에서 표준 입력을 비워 멈추지 않는다
- [ ] 두 셸 테스트와 `render-test.sh` 가 바뀌지 않고 통과한다
- [ ] `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 이월 이슈 본문 · 제목 검사 | 셸 테스트의 거부 견본 | 셸 테스트 기대 종료 코드와 문구, 생성 호출 없음 |
| UT-02 | 이월 이슈 생성 | 맞는 제목 · 본문 | 페이크 생성 호출의 인수 · 상속 값이 셸 테스트 기대와 같음 |
| UT-03 | 중복 제목 · 드라이런 | 같은 제목의 열린 이슈, 드라이런 인수 | 셸 테스트 기대값 |
| UT-04 | 되감기 대상 | 리뷰 요청 · task 이슈 · 로컬 브랜치가 있는 이슈 | 보이는 단계와 `--yes` 뒤 닫힌 대상이 셸 테스트 기대와 같음 |
| UT-05 | 착수 잠금 | 이 클론의 잠금 · 다른 클론의 잠금 · 잠금만 남은 경우 | 셸 테스트 기대 줄과 원격 잠금 상태 |
| UT-06 | `--dry-run` · 판정 불가 | 잠금이 있는 이슈, 원격을 읽지 못하는 리포 | 원격 · 소유 기록 그대로, `state unknown` 줄과 종료 코드 그대로 |

## T6 · chore: forge 라벨 준비 · forge-setup 과 남은 셸 회귀 테스트 이관

### 상위 Requirement

- relates to #221

### 작업 내용

forge 어댑터의 라벨 준비 · 목록과 원격 라벨 준비의 셸 테스트 검사 줄을 계약 시험에 옮긴다. T1~T5 가 옮기지 않은 `test-*.sh` 가 착수 시점 트리에 있으면 그것도 같은 규칙으로 여기서 옮긴다.
이 task 가 끝나면 `src/templates/managed/script/test-*.sh` 의 검사 줄이 모두 단위 시험에 대응을 갖는다.

- 근거: 명세 12-1
- forge 라벨 준비: `src/templates/managed/script/test-forge-labels.sh`
  - 대상: `harness forge <함수>` 의 라벨 준비 · 라벨 목록 · 이슈 목록 · 열린 리뷰 요청 목록
  - forge CLI(`gh` 등)는 PATH 앞 스텁이다
  - 판정 기준: 만들지 못한 라벨을 삼키지 않는다, 그때 이슈 · 리뷰 요청을 바꾸지 않는다, 목록을 개수 상한 없이 끝까지 읽는다, Jira 는 원격을 부르지 않는다
- forge-setup: `src/templates/managed/script/test-forge-setup.sh`
  - 대상: `harness forge-setup`
  - 판정 기준: 설정의 이슈 라벨을 넘긴다, 빈 라벨을 건너뛴다, 실패는 2
- shim 을 부르던 줄은 하위 명령을 부르는 줄로 옮긴다. shim 자신의 형태 · 문구만 보던 줄은 옮기지 않는다
- 건드릴 파일: `src/test/unit/` 의 새 시험 모듈

### 완료 조건

- [ ] `test-forge-labels.sh` · `test-forge-setup.sh` 의 검사 줄마다 대응하는 단위 시험이 있고, 기대값이 같다
- [ ] `src/templates/managed/script/test-*.sh` 전부의 검사 줄(shim 형태만 보던 줄 제외)이 `src/test/unit/` 에 대응 시험을 갖는다
- [ ] 시험 모듈이 시험 대상마다 하나다 — 리뷰 루프 · 이월 이슈 · forge 라벨 준비 · forge-setup · 되감기 · 시크릿 스캔 · 명령 가드 · task 동기화 · 사용 기록 · 착수 판정
- [ ] 셸 테스트와 `render-test.sh` 가 바뀌지 않고 통과한다
- [ ] `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 만들지 못한 라벨 | 라벨 생성이 실패하는 `gh` 스텁 | 셸 테스트 기대 종료 코드, 이슈 · 리뷰 요청 변경 호출 없음 |
| UT-02 | 목록 끝까지 | 여러 쪽으로 나뉜 응답의 `gh` 스텁 | 모든 항목이 나옴 |
| UT-03 | Jira 라벨 | `forge.tracker = "jira"` | 원격 호출 없음, 셸 테스트 기대값 |
| UT-04 | forge-setup 라벨 넘기기 | 설정의 이슈 라벨과 빈 라벨 | 페이크 호출이 빈 라벨을 뺀 목록 |
| UT-05 | forge-setup 실패 | 실패하는 페이크 | 2 |

## T7 · chore: 회귀 테스트의 shim 호출과 셸 생성물 내용 검사를 하위 명령 행동 검사로 전환

### 상위 Requirement

- relates to #221

### 작업 내용

`render-test.sh` 에서 파일 걷기에 기대는 줄을 걷기 전에 바꾼다. 하네스 코드는 고치지 않는다. 바꾼 줄은 지금 트리(shim 과 셸 생성물이 있는 트리)에서 통과하고, T21 은 이 줄들을 다시 고치지 않는다.

- 근거: 명세 12-2 의 셋째 · 넷째 항목, 12-1 의 규칙
- 설치된 `script/<이름>` 을 부르는 준비부와 호출 줄
  - 대상: #209 · #210 · #211 · #212 · #213 · #215 의 shim 블록 포함
  - 같은 인자로 `.harness/bin/harness <명령>`(소스 트리 복제면 `src/bin/harness <명령>`)을 부르는 줄로 바꾼다. 대응은 명세 4-5 표다
  - 예: `script/run-lint-test.sh` → `verify`, `script/metric.py wrap` → `span wrap`, `python3 script/_clone_key.py expand` → `clone-key expand`
- shim 자신의 형태 · 문구만 보던 줄은 지운다
  - shim 이 인자를 그대로 넘긴다
  - 현재 디렉터리를 바꾸지 않는다
  - CLI 를 찾지 못하면 공통 문구 두 줄을 낸다
  - CLI 를 치운 샌드박스에서 `script/work-lock.sh status` 가 2 다
- 셸 생성물의 내용을 보던 줄은 같은 약속을 하위 명령의 행동으로 본다
  - `script/harness.env` 의 판정 값 → 설정을 바꾼(`harness set`) 뒤 가드 · 훅의 판정
  - `script/harness-verify.sh` 의 단계 목록 → `verify --steps-only` 의 출력
  - `script/forge.sh` 의 함수 → `harness forge <함수>` 의 결과
- 이 task 가 고치지 않는 줄과 고칠 task
  - 허용 목록의 `Bash(script/…)` 규칙을 보는 줄 → T12
  - 옛 agent 절 케이스 → T13
  - pre-push 가 `script/run-lint-test.sh` 를 부르는 경로 → T15
  - doctor 의 `script/harness-verify.sh` 항목 → T16
  - `verify.script_tests` 준비부 → T17
  - 설치본 셸 회귀 테스트를 세어 돌리는 블록(UT-61) → T21
  - 각 줄은 그 동작을 바꾸는 task 가 고친다
- 바꾸거나 지운 줄마다 옛 줄 → 새 줄 대응을 리뷰 요청 본문용으로 남긴다
- 건드릴 파일: `src/test/render-test.sh`

### 완료 조건

- [ ] `render-test.sh` 에서 설치된 리포의 `script/` 아래 하네스 파일을 실행하거나 source 하는 줄은 위 "이 task 가 고치지 않는 줄" 목록의 것만 남는다
- [ ] `script/harness.env` · `script/harness-verify.sh` · `script/forge.sh` 의 내용을 읽는 줄이 없다
- [ ] 바꾼 줄의 기대값(종료 코드 · 출력 · 기록 · 파일 상태)이 바꾸기 전과 같다
- [ ] 하네스 코드(`src/harness/` · `src/bin/` · `src/templates/`)가 바뀌지 않는다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | shim 호출 줄의 전환 | 바꾼 블록 전부 | 바꾸기 전과 같은 종료 코드 · 출력 |
| UT-02 | 판정 값의 행동 검사 | `branches.protected` 를 `harness set` 으로 바꾼 설치본 | 가드가 새 보호 브랜치 push 를 막음 |
| UT-03 | 검증 단계 목록의 행동 검사 | `[verify].checks` 가 든 설치본 | `verify --steps-only` 출력에 그 단계 이름 |
| UT-04 | forge 함수의 행동 검사 | 페이크를 끼운 설치본 | `harness forge <함수>` 가 바꾸기 전 셸 함수 검사와 같은 결과 |

## T8 · feat: 하네스 CLI 표기 변수와 관리 파일 치환, 걷힌 경로 대응 상수

### 상위 Requirement

- relates to #221

### 작업 내용

생성물 · 관리 파일 · 설정 값이 하네스 명령을 적을 변수 `{{HARNESS_CLI}}` 를 만들고, 관리 파일에도 그 변수 하나만 채우게 한다. 걷힌 경로와 새 표기의 대응을 상수 하나로 둔다.
표기 전환은 T9~T11 이 한다. 이 task 뒤에도 관리 파일에는 아직 `{{HARNESS_CLI}}` 가 없다.

- 근거: 명세 4-1, 4-3, 4-5
- `derive()` 가 하네스 루트로 `HARNESS_CLI` 를 낸다
  - `source_tree()` 가 참이면 `src/bin/harness`, 아니면 `.harness/bin/harness`
  - 고정 사본이 빠진 리포에서도 같은 값이다. 소스 리포의 worktree 는 `src/bin/harness` 다
- 관리 파일 치환
  - render · install 이 관리 파일을 깔 때 `{{HARNESS_CLI}}` 하나만 4-1 의 값으로 채운다
  - 다른 `{{대문자}}` 변수가 관리 파일에 있으면 `substitute()` 의 `unknown template variable` 오류로 render 를 거부한다
  - `{{step:<id>}}` 같은 다른 중괄호는 글자 그대로다
  - `.harness/managed` 의 해시는 깐 내용으로 계산한다
  - 관리 파일 대조(`check` · doctor)는 채운 내용을 기준으로 한다. 고정 사본의 템플릿(`.harness/templates/managed/`)은 채우지 않은 원문이다
- 걷힌 경로 대응 상수(4-5)
  - 각 행은 걷힌 경로 · 새 표기 · 비고다
  - `script/test-*.sh` 는 `script/test-` 로 시작하고 `.sh` 로 끝나는 이름 전부다
  - 6절의 사전 판정, doctor, README "업데이트" 의 표가 이 상수를 쓴다
- 건드릴 파일
  - `render/derive.py`
  - 관리 파일을 까는 render · install 경로와 관리 파일 대조
  - 대응 상수를 두는 모듈
  - `src/test/render-test.sh`
  - `src/test/unit/`

### 완료 조건

- [ ] `harness vars` 에 `HARNESS_CLI` 가 있다. 설치한 리포는 `.harness/bin/harness`, 소스 트리 복제와 그 worktree 는 `src/bin/harness` 다
- [ ] 관리 템플릿에 `{{HARNESS_CLI}}` 를 넣은 CLI 로 설치하면 그 파일에 4-1 의 값이 들어가고 `check` 가 0 이다. 고정 사본 대조 경고가 나지 않는다
- [ ] 관리 템플릿에 `{{PROJECT_NAME}}` 을 넣으면 render 가 `unknown template variable` 로 멈추고 아무 파일도 바뀌지 않는다
- [ ] 대응 상수가 명세 2-2 기대 목록의 경로를 모두 갖는다
- [ ] 지금 관리 템플릿 전부가 바뀐 치환을 거쳐 그대로 깔린다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 루트 종류별 값 | 소스 트리 · 대상 리포 · 고정 사본이 빠진 대상 리포 | `src/bin/harness` · `.harness/bin/harness` · `.harness/bin/harness` |
| UT-02 | 관리 파일 치환 | `{{HARNESS_CLI}} verify` 와 `{{step:x}}` 가 든 관리 템플릿 | 앞은 채운 값, 뒤는 글자 그대로 |
| UT-03 | 다른 변수 거부 | `{{PROJECT_NAME}}` 이 든 관리 템플릿 | render 1 이 아닌 오류 종료와 `unknown template variable`, 파일 변화 없음 |
| UT-04 | 해시 · 대조 | 치환된 관리 파일을 깐 설치본 | `.harness/managed` 의 해시가 깐 내용의 것, `check` 0 |
| UT-05 | 대응 상수 | 명세 2-2 기대 목록 | 모든 경로에 새 표기가 있음, `script/test-x.sh` 가 패턴에 맞음 |

## T9 · chore: 절차 조각 · 절차 문서 · 내장 기본값 work 의 명령 표기를 하네스 CLI 로 전환

### 상위 Requirement

- relates to #221

### 작업 내용

절차가 부르는 하네스 명령을 `{{HARNESS_CLI}} <명령>` 으로 바꾼다. 옛 agent `work` 조각도 표기만 바뀐다. 내장 기본값 `work` 의 표기가 바뀌므로 바뀌기 전 판을 이전 기본값 목록에 더한다.

- 근거: 명세 4-2 의 절차 조각 · 절차 문서 생성 행, 4-4, 6-3 의 첫 항목, 11-2 의 `work/limits.md` 행
- 절차 조각 `src/templates/workflows/*/`
  - 대상: prework · retro · `work`(옛 agent 조각 다섯 포함) · `review-loop`
  - `script/<이름>` 표기를 4-5 의 새 표기로 바꾼다
  - forge 함수를 바로 적은 곳(`review_mr_threads {mr}` 등)은 `{{HARNESS_CLI}} forge <함수> …` 로 바꾼다
  - `work/limits.md` 의 `script/README.md` 는 `docs/workflow/README.md` 로 바꾼다
- 절차 문서 생성(`step_body()` · `workflow_doc()`)
  - CLI 러너 단계의 첫 문단 명령을 `{{HARNESS_CLI}} run-agent <역할> <이슈번호>` 로 바꾼다
  - 상수 `RUN_AGENT` 를 없앤다
  - agent 절차 문서의 시작 표지 줄을 `{{HARNESS_CLI}} span step <절차> <단계>` 로 바꾼다
- 내장 기본값 `src/templates/defaults.toml` (4-4)
  - `work` 의 `run`: `{{HARNESS_CLI}} work-lock acquire {issue}` · `work-check clean` · `preflight {issue}` · `sync-tasks {issue}` · `work-check develop …` · `work-lock release {issue}`
  - `review-loop` 의 `run`: `{{HARNESS_CLI}} review {mr}` · `work-check fix …`
  - 인자와 배선은 #212 · #215 가 정한 그대로다
  - `[workflows]` 머리 주석과 `type agent` 설명을 4-4 의 문장으로 바꾼다
- 이전 기본값 목록(#212 10-3)
  - 바꾸기 직전의 `[workflows.work]` 표 전체(#215 4-1 이 낸 driver 기본값)를 더한다
  - doctor 항목과 `harness fix legacy-work` 가 같은 목록을 쓴다
- driver 는 #208 의 순서대로 render 치환을 먼저 하고 자리표시를 푼다. `{{HARNESS_CLI}}` 는 4-1 의 값으로 채워진다
- 렌더된 절차 문서의 `script/<이름>` 글자를 보던 기존 `render-test.sh` 줄은 새 표기를 보는 줄로 바꾼다. 명령 표기가 바뀌는 동작 변경이다(명세 1절)
- 건드릴 파일
  - `src/templates/workflows/`
  - `render/workflows.py` · `config/agents.py`(`RUN_AGENT`)
  - `src/templates/defaults.toml`
  - 이전 기본값 목록
  - `src/test/render-test.sh`
  - `src/test/unit/`

### 완료 조건

- [ ] 설치한 리포의 `.ai/workflows/*.md` 에 4-5 의 걷힌 경로가 없고, 하네스 명령이 `.harness/bin/harness <명령>` 이다. 소스 트리 복제는 `src/bin/harness <명령>` 이다
- [ ] 렌더된 절차 문서에 `{{HARNESS_CLI}}` 글자가 남지 않는다
- [ ] CLI 러너 단계의 첫 문단과 시작 표지 줄이 새 표기다. `RUN_AGENT` 가 없다
- [ ] 내장 기본값 `work` · `review-loop` 의 `run` 이 4-4 의 목록과 같다
- [ ] 내장 기본값 `work` 의 첫 단계 `lock` 이 로컬 bare 원격에 잠금 ref 를 만들고 0 으로 끝난다. 설치한 리포와 소스 트리 복제 둘 다다. 띄운 argv 에 `{{HARNESS_CLI}}` 글자가 없다
- [ ] #215 판 `[workflows.work]` 를 가진 설정에서 doctor 가 `workflows.work is a previous default` 를 낸다. `harness fix legacy-work` 가 그 절을 지우고 render 한다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 대상 리포 절차 문서 | 새로 설치한 리포의 `.ai/workflows/*.md` | `.harness/bin/harness` 표기, 걷힌 경로 없음 |
| UT-02 | 소스 트리 절차 문서 | 소스 트리 복제의 `.ai/workflows/*.md` | `src/bin/harness` 표기 |
| UT-03 | CLI 러너 단계 · 시작 표지 | 역할 러너가 CLI 인 설정 | 첫 문단 `… run-agent <역할> <이슈번호>`, 표지 줄 `… span step <절차> <단계>` |
| UT-04 | driver 의 `run` | 내장 기본값 `work` 를 로컬 bare 원격에서 `lock` 단계까지 | 잠금 ref 생성, 0, argv 에 `{{HARNESS_CLI}}` 없음 |
| UT-05 | 내장 기본값 | `src/templates/defaults.toml` | `work` · `review-loop` 의 `run` 이 4-4 와 같고 `script/` 경로가 없음 |
| UT-06 | #215 판 이전 기본값 | 그 판 `[workflows.work]` 를 옮긴 설정 | doctor 항목이 나옴, `fix legacy-work` 뒤 내장 기본값 `work` 로 렌더 |

## T10 · chore: 역할 어댑터 · 역할 계약 · 양식 · 관리 커맨드의 명령 표기를 하네스 CLI 로 전환

### 상위 Requirement

- relates to #221

### 작업 내용

역할이 읽는 명령 표기를 `{{HARNESS_CLI}} <명령>` 으로 바꾼다. 역할 계약 · 양식 · 관리 커맨드는 관리 파일이므로 T8 의 치환으로 채워진다.

- 근거: 명세 4-2 의 역할 어댑터 · 역할 선언 · frontmatter 생성 · 역할 계약 · 관리 커맨드 · `.codex/agents/` 행, 11-2 의 `docs-writer.md` 행
- 역할 어댑터 본문 `src/templates/agents/*.md`
  - 검증 줄: `{{HARNESS_CLI}} verify --commit`
  - 리뷰 · 등록 명령: `{{HARNESS_CLI}} review` · `{{HARNESS_CLI}} review post <번호> - < <본문파일>`
- 역할 선언 frontmatter
  - `entry: {{HARNESS_CLI}} review`
  - `summary` · `description` 에 명령이 들면 같은 표기다
- frontmatter 를 쓰는 생성
  - `agent_table()` · `command_rows()` · 어댑터 frontmatter 가 `{{HARNESS_CLI}}` 를 채운다
  - 실행 계획의 `entry` 도 채운 값이다. 공용 실행기면 `{{HARNESS_CLI}} run-agent <역할>` 을 채운다
  - `harness schema` 의 `script_roles` 와 `validate_workflows()` 의 안내는 채우지 않은 설정 표기 그대로다. 설정의 `run` 과 같은 글자로 맞대 보기 때문이다
- 역할 계약 · 양식 `src/templates/managed/.ai/templates/*.md`
  - developer · planner · code-reviewer · security-guard · docs-writer 계약과 `mr.md` · `mr-guide.md` 의 `script/<이름>` 표기를 새 표기로 바꾼다
  - developer 의 "조회는 `script/forge.sh` 의 함수로만 한다" → "조회는 `{{HARNESS_CLI}} forge <함수>` 로만 한다"
  - docs-writer 의 `script/README.md` → `docs/workflow/README.md`
- 관리 커맨드 `src/templates/managed/.claude/commands/` 의 `prework.md` · `security-guard.md` · `work.md`: 위임표와 본문의 스크립트 표기를 바꾼다
- `.codex/agents/` 는 같은 원형에서 나오므로 따라 바뀐다. 리뷰 요청 템플릿이 `mr.md` 에서 나오면 그것도 따라 바뀐다
- 기존 `render-test.sh` 줄이 어댑터 · 계약 · 커맨드의 `script/<이름>` 글자나 실행 계획 `entry` 의 옛 값을 보면 새 표기를 보는 줄로 바꾼다
- 건드릴 파일
  - `src/templates/agents/`
  - `src/templates/managed/.ai/templates/`
  - `src/templates/managed/.claude/commands/`
  - `render/agents.py` · `config/agents.py`(`run_plan()`)
  - `src/test/render-test.sh`
  - `src/test/unit/`

### 완료 조건

- [ ] 설치한 리포의 아래 파일에 4-5 의 걷힌 경로가 없고 하네스 명령이 `.harness/bin/harness` 표기다. 소스 트리 복제는 `src/bin/harness` 표기다
  - `.claude/agents/*.md`
  - `.codex/agents/*.toml`
  - `.ai/templates/*.md`
  - `.claude/commands/*.md`
- [ ] 이 파일들에 `{{HARNESS_CLI}}` 글자가 남지 않는다
- [ ] `harness run-plan` 의 `entry` 가 채운 값이다. `harness schema` 의 `script_roles` 는 `{{HARNESS_CLI}} …` 그대로다
- [ ] `agent` 절차의 공용 실행기 안내와 `validate_workflows()` 의 안내가 설정 표기로 맞대 본다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 어댑터 본문 | 새로 설치한 리포의 `.claude/agents/developer.md` · `code-reviewer.md` | `.harness/bin/harness verify --commit` · `… review post <번호> - < <본문파일>` |
| UT-02 | 역할 계약 · 양식 | 설치한 리포의 `.ai/templates/developer.md` · `mr.md` | `.harness/bin/harness forge <함수>` · `… verify`, `script/` 하네스 경로 없음 |
| UT-03 | 관리 커맨드 | 설치한 리포의 `.claude/commands/prework.md` · `security-guard.md` | 새 표기, 걷힌 경로 없음 |
| UT-04 | 실행 계획 `entry` | 리뷰어 역할 · 공용 실행기 역할 | `.harness/bin/harness review` · `.harness/bin/harness run-agent <역할>` |
| UT-05 | schema 의 설정 표기 | `harness schema` | `script_roles` 가 `{{HARNESS_CLI}} …` |
| UT-06 | 소스 트리 | 소스 트리 복제의 같은 파일 | `src/bin/harness` 표기 |

## T11 · chore: 규칙 문서 · CLAUDE.md · forge 명령 사전 · doctor 문구의 명령 표기를 하네스 CLI 로 전환

### 상위 Requirement

- relates to #221

### 작업 내용

규칙 문서와 관문 문서, forge 명령 사전, doctor 문구가 적는 하네스 명령을 새 표기로 바꾼다. forge 명령 사전은 셸에서 source 하던 함수 대신 명령줄 호출과 계약 함수 표를 싣는다.

- 근거: 명세 4-2 의 `AI_AGENT.md` · `CLAUDE.md` · 규칙 문서 3장 · `.ai/forge.md` · doctor 문구 행
- `src/templates/generated/.ai/AI_AGENT.md`
  - 6-4 이슈 생성 수단 표: `{{HARNESS_CLI}} sync-tasks <요구사항 이슈번호>` · `{{HARNESS_CLI}} carryover <원본이슈> <제목> <본문파일>`
  - 7장 되감기 예외: `{{HARNESS_CLI}} rollback`
  - 8장 검증 루프 둘째 줄: `{{HARNESS_CLI}} verify --commit`
  - 9장은 T20, 3장 끝 · 10장은 T21 이 고친다
- 규칙 문서 3장 `commands_doc()`
  - "검증 일괄" 행: `{{HARNESS_CLI}} verify`
  - 단계 순서 문장: "검증(`<CLI> verify`)은 이 순서로 돈다"
- `src/templates/generated/CLAUDE.md`
  - 검증 줄: `{{HARNESS_CLI}} verify --commit`
  - 설정 변경 줄: `{{HARNESS_CLI}} render`
  - 흐름 그림: 스크립트 이름을 하위 명령 이름(`preflight` · `sync-tasks` · `review` · `work-check` · `work-lock`)으로
- `.ai/forge.md` 원형 `src/templates/forge/forge.md`
  - "스크립트에서 쓸 때" 절을 "명령줄에서 쓸 때" 로 바꾼다 — `{{HARNESS_CLI}} forge <함수> [인수…]`, 본문 파일 자리는 `-` 와 표준 입력
  - `forge_doc()` 이 #209 의 계약 표에서 함수 표(이름 · 인자 · 출력 · 종료 코드)를 이 절에 싣는다. `script/forge.sh` 머리글이 갖던 표다
  - forge 명령 사전 조각(`src/templates/forge/github/review.md` 등)의 `script/` 표기도 바꾼다
- doctor 문구
  - `adapter <kind>` 의 미검증 detail: `` unverified — run `<CLI> forge-selftest` ``. `<CLI>` 는 4-1 의 값이다
  - `config` 절 `no command guard for <오케스트레이터>` 의 detail: `bash-guard.sh` → `the command guard`
- 기존 `render-test.sh` 줄이 이 문서 · 문구의 옛 글자를 보면 새 표기를 보는 줄로 바꾼다
- 건드릴 파일
  - `src/templates/generated/.ai/AI_AGENT.md` · `src/templates/generated/CLAUDE.md`
  - `render/scripts.py`(`commands_doc()`) · `render/docs.py`(`forge_doc()`)
  - `src/templates/forge/`
  - `readiness/items.py`
  - `src/test/render-test.sh`
  - `src/test/unit/`

### 완료 조건

- [ ] 설치한 리포의 `CLAUDE.md` · `.ai/forge.md` 에 4-5 의 걷힌 경로가 없고 하네스 명령이 `.harness/bin/harness` 표기다
- [ ] 설치한 리포의 `.ai/AI_AGENT.md` 3장 명령 표 · 단계 순서 문장 · 6-4 표 · 7장 · 8장이 `.harness/bin/harness` 표기다
- [ ] 소스 트리 복제의 같은 자리는 `src/bin/harness` 표기다
- [ ] `.ai/forge.md` 의 "명령줄에서 쓸 때" 절이 #209 계약 표의 함수를 전부 싣는다
- [ ] doctor 의 두 detail 이 새 문구다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 규칙 문서 3장 | 새로 설치한 리포의 `.ai/AI_AGENT.md` | "검증 일괄" 행 `.harness/bin/harness verify`, 순서 문장의 같은 표기 |
| UT-02 | 규칙 문서 6-4 · 7 · 8장 | 같은 파일 | `… sync-tasks` · `… carryover` · `… rollback` · `… verify --commit` |
| UT-03 | 관문 문서 | 설치한 리포의 `CLAUDE.md` | 검증 줄 · 설정 변경 줄 · 흐름 그림의 하위 명령 이름 |
| UT-04 | forge 명령 사전 | 설치한 리포의 `.ai/forge.md` | "명령줄에서 쓸 때" 절과 계약 함수 표, `script/forge.sh` 없음 |
| UT-05 | doctor 미검증 어댑터 | 미검증 표기 어댑터의 설치본 | detail `` unverified — run `.harness/bin/harness forge-selftest` `` |
| UT-06 | 소스 트리 | 소스 트리 복제의 같은 파일 | `src/bin/harness` 표기 |

## T12 · feat: 명령 표의 허용 표시로 하위 명령 허용 규칙 생성

### 상위 Requirement

- relates to #221

### 작업 내용

허용 여부를 명령 쪽에 선언하고 권한 허용 목록을 하위 명령 규칙으로만 만든다. 관리 스크립트 파일 목록에서 만들던 옛 규칙을 걷는다.

- 근거: 명세 5-1, 5-2, 11-2 의 `harness help` 행, 12-4 의 허용 표시 · 명령 표 스모크 행
- 명령 표 `COMMANDS`
  - 항목을 다섯 원소 `(통과, 설정이 필요한가, 허용, 인수, 설명)` 로 바꾼다. 허용 표시는 `True` 또는 `None` 이다
  - 허용 표시가 `True` 인 명령: `preflight` · `review` · `run-agent` · `secret-scan` · `span` · `sync-tasks` · `usage` · `verify` · `work-check` · `work-lock`
  - 명령 표를 읽는 곳(인자 해석 · `help` · `schema` 등)을 새 모양으로 바꾼다
- `allow_rules()`
  - 허용 표시 명령마다 `Bash(<4-1 의 값> <명령>:*)` 를 명령 이름 오름차순으로 낸다
  - 순서: 하위 명령 규칙 → forge 명령(`allow.toml`) → `git switch -c` · `git commit`(`allow_push` 면 `git push`)
- 없애는 것
  - `allowed_scripts()` · `ALLOW_EXCLUDED` 와 거부 문구 `permission exclusion names a script that is not shipped`
  - #213 이 둔 하위 명령 묶음 상수와 거부 문구 `permission list names a command that does not exist`
- 바뀌지 않는 것: deny 규칙, `write-doc` 세 형태(`WRITE_DOC_CALLERS`), 명령 가드, `.claude/settings.json` 의 훅 명령
- driver 쓰기 범위(5-2)
  - 벤더 선언 `src/templates/vendors.toml` 의 `driver_write` 인자 가운데 하네스 명령 경로를 담은 원소를 `{harness} <명령>` 꼴로 바꾼다
  - `expand()` 가 값 이름 `harness` 를 4-1 의 값으로 채운다
  - 범위는 그대로다 — 검증 `verify --commit`, forge 읽기 · 쓰기 함수, `carryover`, `sync-tasks <이슈> --dry-run`
- `harness help` 의 `forge` 설명에서 `script/forge.sh calls this` 를 지운다
- 단위 시험
  - `test_commands.py` 스모크: "명령 표 항목은 다섯 원소이고 첫 원소(통과 표시)와 셋째 원소(허용 표시)는 `True` 또는 `None` 이다"
  - 허용 표시가 있는 명령이 위 열 개와 같은지 본다
- `render-test.sh`
  - 명세 12-3 의 "허용 목록" 블록을 더한다
  - `Bash(script/…)` 규칙과 지운 두 거부 문구를 보던 기존 줄은 이 블록으로 바꾸거나 지운다
- 건드릴 파일
  - `commands/__init__.py` 와 명령 표를 읽는 모듈
  - `render/settings.py`
  - `config/agents.py`(`expand()`)
  - `src/templates/vendors.toml`
  - `src/test/unit/` · `src/test/render-test.sh`

### 완료 조건

- [ ] 설치한 리포의 `permissions.allow` 에 `Bash(.harness/bin/harness <명령>:*)` 가 열 명령에 하나씩, 이름순으로 forge 규칙 앞에 있다
- [ ] 소스 트리 복제는 `Bash(src/bin/harness <명령>:*)` 다
- [ ] `Bash(script/` 로 시작하는 규칙이 없다
- [ ] 아래 명령의 규칙이 없다: `carryover` · `rollback` · `forge` · `forge-selftest` · `forge-setup` · `bash-guard` · `git-hook` · `clone-key`
- [ ] deny 의 `write-doc` 세 형태와 훅 명령이 그대로다
- [ ] `allowed_scripts` · `ALLOW_EXCLUDED` 와 두 거부 문구가 코드에 없다
- [ ] 벤더 선언에 `script/` 로 시작하는 하네스 명령 경로가 없다. 실행 계획의 driver 쓰기 인자에 4-1 의 값이 들어간다
- [ ] `harness help` 의 `forge` 설명에 `script/forge.sh` 가 없다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 허용 표시 집합 | 명령 표 | 허용 표시가 `True` 인 명령이 열 개와 같음 |
| UT-02 | 명령 표 스모크 | 명령 표 항목 전부 | 다섯 원소, 첫째 · 셋째가 `True` 또는 `None` |
| UT-03 | 대상 리포 허용 목록 | 새로 설치한 리포의 `.claude/settings.json` | 하위 명령 규칙 열 개 → forge → git 순서 |
| UT-04 | 소스 트리 허용 목록 | 소스 트리 복제 | `Bash(src/bin/harness <명령>:*)` |
| UT-05 | 빠지는 규칙 | 같은 파일 | `Bash(script/` 규칙과 표시 없는 명령의 규칙이 없음 |
| UT-06 | deny 그대로 | 같은 파일 | `write-doc` 세 형태가 지금과 같음 |
| UT-07 | driver 쓰기 인자 | driver 역할이 있는 실행 계획 | 하네스 명령 경로가 4-1 의 값 |

## T13 · feat: 걷힌 경로를 가리키는 설정 값에서 render 를 멈추는 사전 판정과 doctor 항목

### 상위 Requirement

- relates to #221

### 작업 내용

공유 설정의 단계 · 검증 · 명령 값이 걷힌 경로를 부르면 render 가 아무것도 바꾸지 않고 멈추고, 바꿀 표기를 안내한다. doctor 도 같은 판정을 짚는다.

- 근거: 명세 6-1 ~ 6-4, 12-2 의 마지막 항목, 12-3 의 "설정 값 사전 판정" · "이전 기본값 — #215 판" · "옛 agent 절", 12-4 의 6-1 행
- 판정(6-1)
  - 공유 설정 레이어마다 아래 값을 본다
    - `workflows.<절차>.steps[<n>].run` · `.text`
    - `verify.checks[<n>].run`
    - `commands.<키>`
  - 4-5 의 걷힌 경로가 낱말로 들어 있으면 걸린다. 낱말 경계는 명세 6-1 의 앞 · 뒤 문자 규칙이다
  - 걸린 값마다 키 · 레이어 · 걷힌 경로 · 새 표기를 남긴다
  - `validate()` 의 일부가 아니다. 가드 · 훅 · 하위 명령은 이 판정으로 멈추지 않는다
- render(6-2)
  - `refuse_changes()` 의 첫 판정이다. 매니페스트 검증 · 경로 규칙 · 사용자 파일 판정보다 먼저 돈다
  - 걸리면 아무것도 쓰지 않고 2 로 끝난다
  - install(고정 사본을 바꾸기 전)과 `set` · `steps` · `checks`(바꾼 설정을 되돌린다)도 같은 판정으로 멈춘다
  - 표준 오류는 6-2 의 형식이다
    - `use` 줄은 절차 단계 값이면 설정 표기(`{{HARNESS_CLI}} …`), `verify.checks` · `commands` 값이면 4-1 의 값을 채운 경로다
    - 레이어 표시는 프로젝트면 `harness.toml`, preset 이면 #216 의 레이어 표시다
    - 비고가 있으면 `use` 줄 끝에 ` — <비고>` 를 붙인다
- 이전 기본값 안내(6-3): 프로젝트 레이어의 `[workflows.work]` 가 이전 기본값 목록의 한 항목과 같으면 `help:` 줄 뒤에 두 줄을 더 낸다
- doctor(6-4): `config` 절에 걸린 값마다 `bad` 줄을 낸다. `check` 는 이 판정을 따로 하지 않는다
- 기존 옛 agent 절 케이스를 6-3 에 맞춘다(#212 의 "옛 절" · `fix legacy-work`, #215 의 agent 모드 문서)
  - 이전 기본값 절은 render 가 6-2 · 6-3 의 안내로 멈춘다
  - `run` 을 새 표기로 바꾼 절은 옛 조각으로 렌더된다
- 건드릴 파일
  - `changes.py` 와 판정 모듈
  - `readiness/items.py`
  - `src/test/render-test.sh` · `src/test/unit/`

### 완료 조건

- [ ] 프로젝트 `[workflows.<절차>]` 의 `run` 에 `script/review-mr.sh {mr}` 를 두면 render 가 2 와 6-2 의 문구로 멈추고, 아무 파일도 바뀌지 않는다
- [ ] 낱말 경계 판정이 6-1 대로다
  - 걸린다: `text` 의 `` `script/forge.sh` `` 와 `./script/review-mr.sh`
  - 걸리지 않는다: `src/script/review-mr.sh` 와 `script/review-mr.sh.orig`
- [ ] `verify.checks` 값의 `use` 줄은 채운 경로다
- [ ] `harness set` 이 걸리는 값을 남기면 설정 파일이 바이트 그대로다. install 은 고정 사본을 바꾸지 않는다
- [ ] #215 판 `[workflows.work]` 로 render 하면 6-2 의 문구와 6-3 의 `harness fix legacy-work` 줄로 멈춘다. `fix legacy-work` 뒤 내장 기본값 `work` 가 새 표기로 렌더된다
- [ ] #212 10-1 의 agent 절로 render 하면 6-3 의 줄이 나온다. `fix legacy-work` 가 0 으로 끝나고 driver 문서가 생긴다
- [ ] `run` 만 새 표기로 바꾼 agent 절은 옛 조각으로 렌더된다. `.claude/commands/work.md` 가 깔리고 그 안의 명령이 `.harness/bin/harness` 표기다
- [ ] doctor 가 6-4 의 줄을 낸다
- [ ] 내장 기본값과 이 리포 `harness.toml` 에 걸리는 값이 없다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 낱말 경계 | 앞 문자(처음 · 공백 · 따옴표 · 백틱 · `(` · `=`) · 뒤 문자(끝 · 경로 문자) 표본 | 6-1 대로 걸림 · 안 걸림 |
| UT-02 | 패턴 경로 | `script/test-foo.sh`, `script/test-` | 앞은 걸림, 뒤는 안 걸림 |
| UT-03 | 키 셋 · 레이어 | 세 종류 키에 든 값, 프로젝트 레이어 | 키 · 레이어 · 걷힌 경로 · 새 표기가 남음 |
| UT-04 | `use` 줄 | 절차 값과 검증 값 | 앞은 `{{HARNESS_CLI}} …`, 뒤는 채운 경로, 비고가 붙음 |
| UT-05 | 내장 기본값 | 내장 기본값 레이어 | 걸리는 값 없음 |
| UT-06 | render 사전 판정 | 걸리는 프로젝트 설정 | 2, 6-2 문구, 파일 변화 없음 |
| UT-07 | `set` 되돌림 | 걸리는 값을 남기는 `harness set` | 설정 파일 바이트 그대로 |
| UT-08 | 이전 기본값 | #215 판 · #212 agent 절 | `harness fix legacy-work` 안내 두 줄 |
| UT-09 | 새 표기 agent 절 | `run` 을 새 표기로 바꾼 agent 절 | 옛 조각 렌더, `.claude/commands/work.md` 의 새 표기 |
| UT-10 | doctor | 걸리는 설정 | `config` 절 `bad` 줄과 6-4 의 detail |

## T14 · feat: 명령 가드 · commit-msg · pre-push 가 공유 설정에서 판정 값을 읽음

### 상위 Requirement

- relates to #221

### 작업 내용

가드와 git 훅 본문이 `script/harness.env` 대신 하네스 루트의 공유 설정을 직접 읽는다. 판정 값은 `derive()` 와 같은 함수 하나가 계산한다. `script/harness.env` 는 아직 생성되지만 하네스 코드는 읽지 않는다.

- 근거: 명세 7-1, 7-2, 7-4, 12-3 의 "가드 · 훅의 설정", 12-4 의 판정 값 함수 행
- 판정 값 함수
  - 자리: 설정 값 해석 모듈(`config/values.py`)
  - 계산하는 값: 보호 브랜치 목록, 보호 문서 검사식, 커밋 제목 검사식 · 형식 · 예시 · 태그, 브랜치 형식, 통합 브랜치, push 전 검증 여부
  - 공유 설정에서 계산한다. `derive()` 도 같은 함수로 같은 값을 낸다
- `harness bash-guard` · `harness git-hook commit-msg|pre-push` 가 하네스 루트(`--target`)의 공유 설정을 읽는다
  - render 와 같은 설정 로더 · 레이어 해석을 쓴다
  - 개인 레이어는 읽지 않는다
- 설정을 읽지 못한 경우 — 7-1 표의 문구와 종료 코드(가드 2, commit-msg 1, pre-push 1)를 설정 로더 · 대조의 오류 줄 뒤에 낸다
  - 프로젝트 레이어 파일이 없다
  - 어느 레이어든 해석 · 검증에 실패한다
  - preset 사본과 lock 의 대조(#216 5-1, 통합 브랜치에 있을 때)가 어긋남이나 읽을 수 없음을 낸다
- 6절의 판정은 가드 · 훅을 막지 않는다. pre-commit 은 바뀌지 않는다
- 가드 경로의 import(7-2)
  - 통과 경로가 불러오는 하네스 모듈: 진입 스크립트 · 벤더 선언 · 설정 로더 · 설정 값 해석 모듈 · 가드 모듈
  - 불러오지 않는 것: render · 지표 · 사용 기록 모듈, `urllib` · `http`
  - #210 의 가드 import 단위 시험을 이 조건으로 바꾼다
- 차단 기록(7-4): 가드 · 훅의 차단 사용 기록은 `script/usage-log.sh` 를 거치지 않는다. 차단 경로에서만 사용 기록 모듈을 불러 남긴다. 줄 형식 · 어휘 · 실패를 버리는 규칙은 그대로다
- `envfile`(셸 대입 파일 리더)을 없앤다. 표지는 `src/harness/format.py` 가 그대로 갖는다
- 이 리포는 소스 리포라 가드 코드를 고치는 순간 작업 세션의 Bash 호출이 새 코드로 판정된다. 판정 값 함수의 단위 시험을 먼저 통과시킨 뒤 가드가 그 함수를 쓰게 바꾼다
- 기존 테스트 가운데 `script/harness.env` 를 지우거나 깨뜨려 옛 문구(`cannot read the harness config at <루트>/script/harness.env`)를 보던 줄은 7-1 의 상황과 문구로 바꾼다. 대응표에 적는다
- 건드릴 파일
  - `config/values.py` · `render/derive.py`
  - `src/harness/guard/` · `src/harness/hooks.py`
  - `src/harness/envfile.py`(지운다)
  - `src/test/unit/` · `src/test/render-test.sh`

### 완료 조건

- [ ] `script/harness.env` 를 지운 설치본에서 가드가 보호 브랜치 push 를 막는다
- [ ] `branches.protected` 를 render 없이 바꾸면 가드와 pre-push 판정이 따른다
- [ ] `harness.toml` 을 깨뜨리면 가드는 2 와 7-1 의 문구, commit-msg · pre-push 는 1 과 그 문구를 낸다. 프로젝트 레이어 파일이 없을 때도 같다
- [ ] #216 이 통합 브랜치에 있으면 preset 사본의 내용을 lock 과 다르게 고쳤을 때도 같다
- [ ] 같은 설정에서 판정 값 함수의 값과 `derive()` 의 값이 같다
- [ ] 가드 통과 경로가 render · 지표 · 사용 기록 모듈과 `urllib` · `http` 를 불러오지 않는다
- [ ] 차단 사용 기록 줄이 바뀌지 않는다. `script/usage-log.sh` 가 없어도 기록된다
- [ ] 하네스 코드에 `script/harness.env` 를 읽는 곳과 `envfile` 이 없다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 판정 값 함수 | 보호 브랜치 · 커밋 태그 · 보호 문서를 바꾼 설정 | 함수 값과 `derive()` 값이 같음 |
| UT-02 | 가드 import | 통과하는 명령 하나 | 불러온 하네스 모듈이 7-2 의 다섯 무리 안 |
| UT-03 | `harness.env` 없이 | 그 파일을 지운 설치본에서 보호 브랜치 push | 2 |
| UT-04 | 설정을 바로 따름 | `harness.toml` 의 `branches.protected` 를 손으로 고친 설치본 | 가드 · pre-push 가 새 목록으로 막음 |
| UT-05 | 설정을 읽지 못함 — 가드 | 깨진 `harness.toml` · 없는 `harness.toml` | 2, `blocked: cannot read the harness config under <루트>, so the guards cannot run` |
| UT-06 | 설정을 읽지 못함 — 훅 | 같은 리포의 commit-msg · pre-push | 1, 7-1 의 각 문구 |
| UT-07 | preset 대조 | #216 이 있을 때 lock 과 다른 preset 사본 | UT-05 · UT-06 과 같음 |
| UT-08 | 개인 레이어 | 깨진 `harness.local.toml` | 가드 판정이 그대로 |
| UT-09 | 차단 기록 | `script/usage-log.sh` 를 지운 설치본의 차단 | `block bash-guard <라벨>` 줄이 남음 |

## T15 · feat: git 훅의 루트 판정과 pre-push · post-commit 검증을 CLI verify 로 전환

### 상위 Requirement

- relates to #221

### 작업 내용

git 훅이 하네스 루트를 `harness.toml` 로 잡게 바꾼다. push 전 · 커밋 뒤 검증은 `script/run-lint-test.sh` 대신 CLI 의 `verify` 를 부른다.

- 근거: 명세 7-3, 7-5, 12-3 의 "훅의 루트" · "pre-push · post-commit"
- 훅 루트(7-3)
  - 대상: `script/githooks/` 의 commit-msg · pre-commit · pre-push · post-commit
  - 자기 위치의 `../..` 에 `harness.toml` 이 있으면 그것을, 없으면 `git rev-parse --show-toplevel` 을 하네스 루트로 잡는다
  - 원형: `src/templates/generated/script/githooks/`
- pre-push(`verify.pre_push` 가 켜졌을 때)
  - 같은 CLI 의 `verify` 를 하위 프로세스로, 표준 입력을 비우고 돈다
  - 순서 · 문구 · 사용 기록은 그대로다
  - 없애는 것: `script/run-lint-test.sh` 가 실행 가능한지 보던 검사와 문구 `verify.pre_push is on but script/run-lint-test.sh is missing`
- post-commit(`verify.post_commit` 이 켜졌을 때 생성)
  - 다른 훅과 같은 형태의 shim 이다. 7-3 으로 루트를 잡고 CLI 를 골라 `exec <CLI> --target <루트> verify`
  - CLI 를 찾지 못하면 shim 공통 문구 두 줄과 1 이다
  - 원형은 `POST_COMMIT_HOOK`
- render 뒤 이 리포의 git 훅도 새 구현으로 돈다
- `script/run-lint-test.sh` 가 없을 때의 옛 pre-push 문구를 보던 기존 줄은 지운다. 대응표에 적는다
- 건드릴 파일
  - `src/templates/generated/script/githooks/`
  - `render/scripts.py`(`POST_COMMIT_HOOK`)
  - `src/harness/hooks.py`
  - `src/test/render-test.sh`

### 완료 조건

- [ ] 서브프로젝트의 `script/githooks/pre-commit` 이 그 서브프로젝트의 `harness.toml` 로 루트를 잡는다
- [ ] 하네스 훅 파일 어디에도 `script/harness.env` 를 보는 곳이 없다
- [ ] `script/run-lint-test.sh` 가 없는 설치본에서 pre-push 가 검증을 돈다. 실패하면 `block pre-push verify` 와 함께 막는다
- [ ] post-commit 을 켜면 커밋 뒤 `verify` 가 돈다. CLI 가 없으면 두 줄과 1 이다
- [ ] `verify.pre_push is on but script/run-lint-test.sh is missing` 문구가 코드에 없다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 서브프로젝트 루트 | 하위 디렉터리 하네스 루트의 pre-commit | 그 서브프로젝트의 생성물 일치 검사가 돎 |
| UT-02 | 리포 루트 | `../..` 에 `harness.toml` 이 없는 훅 | `git rev-parse --show-toplevel` 의 루트 |
| UT-03 | pre-push 검증 실패 | `script/run-lint-test.sh` 를 지우고 실패하는 검증 단계를 둔 설치본 | 1, `block pre-push verify` 기록 |
| UT-04 | pre-push 검증 통과 | 통과하는 검증 단계 | 0 |
| UT-05 | 표준 입력 | 표준 입력을 읽는 검증 단계 | ref 줄을 받지 않음 |
| UT-06 | post-commit | `verify.post_commit` 을 켠 설치본의 커밋 | 커밋 뒤 `verify` 출력 |
| UT-07 | post-commit CLI 없음 | CLI 를 치운 설치본 | shim 공통 문구 두 줄, 1 |

## T16 · feat: doctor · fix · schema 의 검증 진입점과 리뷰어 러너 점검을 하위 명령으로 전환

### 상위 Requirement

- relates to #221

### 작업 내용

doctor · `fix verify` · `schema` 가 걷힐 파일(`script/harness-verify.sh` · `script/run-agent.py`) 대신 하위 명령을 부르게 바꾼다. schema 키가 바뀌므로 UI 의 검증 항목 해석도 함께 맞춘다.

- 근거: 명세 9절의 doctor `verification` · `--remote` · `harness fix verify` · `verify_entry()` · `harness schema` 행, 10절의 `verification steps` · 보일 명령 행, 12-3 의 "doctor 검증 항목", 12-5 의 첫째 · 셋째 항목 일부
- doctor `verification` 절
  - 채운 옛 검증 스크립트(`script/verify-project.sh`)가 없으면 단계 실행(`verify --steps-only`)을 `QUIET_ENV()` 로 돌린다
  - 항목 이름은 `verification steps` 다. detail 은 그대로(`passes` · `not set up — no commands yet` · `fails at <이름>` · `does not pass`)다
  - 옛 검증 스크립트 쪽 항목은 그대로다
- doctor `--remote` 의 리뷰어 러너 점검
  - 같은 CLI 의 `run-agent <역할> --check` 를 하위 프로세스로 부른다
  - `script/run-agent.py` 가 있는지 보지 않는다
  - 제한 시간 · 시작 알림 · 판정은 그대로다
- `harness fix verify`
  - 채운 옛 검증 스크립트가 있으면 그것, 없으면 단계 실행을 돈다
  - 사용법 문구: `verify   run the verification again`
- `verify_entry()` 는 옛 검증 스크립트를 가르는 함수만 남긴다. 상수 `VERIFY_SCRIPT` 를 없앤다
- `harness schema`
  - `verify_script` 대신 두 키를 낸다
  - `verify_command`: 보일 명령. `bash script/verify-project.sh` 또는 `<CLI> verify --steps-only`
  - `harness_cli`: 4-1 의 값
- UI `src/ui/lib/doctor.js`
  - `verification` 의 `verification steps` 항목을 지금 `script/harness-verify.sh` 항목과 같은 제목 · 본문 · ▷ 조치(`verify`)로 옮긴다
  - 옛 고정 사본이 내는 `script/harness-verify.sh` 항목도 그대로 해석한다
  - ▷ 조치의 보일 명령은 schema 의 `verify_command` 다. 그 키가 없는 옛 사본이면 `bash ${verify_script}` 다
- 기존 테스트 가운데 doctor 항목 이름 `script/harness-verify.sh` 와 schema 의 `verify_script` 를 보던 줄은 새 이름 · 키로 바꾼다. 대응표에 적는다
- 건드릴 파일
  - `readiness/items.py` · `readiness/remote.py`
  - `commands/fix.py` · `commands/schema.py`
  - `config/values.py` · `config/defaults.py`
  - `src/ui/lib/doctor.js` · `src/ui/lib/doctor.test.js`
  - `src/test/render-test.sh`

### 완료 조건

- [ ] doctor 의 `verification steps` 가 `passes` · `not set up — no commands yet` · `fails at <이름>` 을 낸다
- [ ] `harness fix verify` 가 단계를 돈다
- [ ] schema 에 `verify_command` · `harness_cli` 가 있고 `verify_script` 가 없다
- [ ] `script/run-agent.py` 를 지운 설치본에서 `doctor --remote` 의 리뷰어 러너 점검이 스텁 러너로 돈다
- [ ] 코드에 `VERIFY_SCRIPT` 와 `script/harness-verify.sh` · `script/run-agent.py` 를 실행하는 곳이 없다
- [ ] UI 단위 테스트가 `verification steps` · 옛 `script/harness-verify.sh` 의 같은 옮김과 `verify_command` · `bash ${verify_script}` 를 본다
- [ ] `src/test/render-test.sh` · `src/ui` 단위 테스트 · `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 검증 항목 통과 | 통과하는 단계가 있는 설치본 | `verification steps` · `passes` |
| UT-02 | 검증 미설정 | 단계가 없는 설치본 | `not set up — no commands yet` |
| UT-03 | 검증 실패 | 실패하는 단계 | `fails at <이름>` |
| UT-04 | fix verify | 단계가 있는 설치본 | 단계 실행 출력과 그 종료 코드 |
| UT-05 | schema 키 | 설치한 리포 · 소스 트리 복제의 `harness schema` | `verify_command` · `harness_cli` 의 값 |
| UT-06 | 러너 점검 | `script/run-agent.py` 없는 설치본과 리뷰어 스텁 | 점검이 돌고 판정이 지금과 같음 |
| UT-07 | UI 검증 항목 | `verification steps` · 옛 `script/harness-verify.sh` 항목 | 같은 제목 · 본문 · 조치 |
| UT-08 | UI 보일 명령 | `verify_command` 가 있는 schema · 없는 schema | 그 값 · `bash ${verify_script}` |

## T17 · feat: verify.script_tests 를 읽되 무시하고 지우라고 안내

### 상위 Requirement

- relates to #221

### 작업 내용

"하네스 스크립트 회귀" 검증 단계를 없앤다. `verify.script_tests` 키는 받되 무시하고, render · doctor 가 지우라고 알린다.

- 근거: 명세 8절, 11-2 의 `docs/workflow/flow.md` 의 `script_tests` 행, 12-2 의 둘째 항목, 12-3 의 "`verify.script_tests`"
- 없애는 것
  - 상수 `SCRIPT_TESTS`
  - `VERIFY_DEFAULTS` 의 `script_tests`
  - 환경 변수 `HARNESS_SCRIPT_TESTS`(`QUIET_ENV()` 포함)
  - 단계 목록(`verify_steps()` 와 검증 실행 모듈)의 "하네스 스크립트 회귀" 단계
- 키 처리
  - 키는 공유 설정의 어느 레이어에 있어도 받고 무시한다. 값의 형을 보지 않는다. `validate()` 의 `[verify]` 키 목록이 받는다
  - `harness render` 는 그 키가 든 레이어마다 `note: verify.script_tests is no longer read — delete it from <레이어>` 를 낸다. 렌더 결과와 종료 코드는 바뀌지 않는다
  - `harness doctor` 의 `config` 절에 `warn` 한 줄을 낸다
- 지우는 자리
  - 내장 기본값 `src/templates/defaults.toml` 의 키와 주석
  - 이 리포 `harness.toml` 의 `script_tests = false` 줄과 그 위 주석
  - `src/templates/managed/docs/workflow/flow.md` 검증 표의 `script_tests` 행
- `render-test.sh`: `verify.script_tests false` 를 `set` 하던 준비부 쌍을 뺀다
- 건드릴 파일
  - `config/defaults.py` · `config/load.py` · `config/values.py`
  - 검증 실행 모듈 · `readiness/items.py`
  - 렌더 명령의 안내
  - `src/templates/defaults.toml` · `harness.toml` · `src/templates/managed/docs/workflow/flow.md`
  - `src/test/render-test.sh` · `src/test/unit/`

### 완료 조건

- [ ] 이 키가 든 설정의 render 결과가 키 없는 설정과 같다
- [ ] render 가 8절의 note 를 레이어마다 낸다. doctor 가 그 줄을 낸다
- [ ] 문자열 값이어도 거부하지 않는다
- [ ] `verify --steps-only` 의 단계 목록에 "하네스 스크립트 회귀" 가 없다
- [ ] 코드에 `SCRIPT_TESTS` · `HARNESS_SCRIPT_TESTS` 가 없다
- [ ] 이 리포 `harness.toml` 과 내장 기본값에 `script_tests` 가 없다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 무시 | `script_tests = true` 가 든 설정과 없는 설정 | 두 render 의 생성물이 같음 |
| UT-02 | note | 프로젝트 레이어에 키 | 표준 오류에 note 한 줄, 종료 코드 그대로 |
| UT-03 | 형 무시 | `script_tests = "x"` | render 0, note |
| UT-04 | doctor | 같은 설정 | `config` 절 `warn` 과 8절의 detail |
| UT-05 | 단계 목록 | 키가 참인 설정의 `verify --steps-only` | "하네스 스크립트 회귀" 단계 없음 |
| UT-06 | 조용한 환경 | `QUIET_ENV()` | `HARNESS_SCRIPT_TESTS` 가 없음 |

## T18 · feat: 리포 루트 CI 가 부를 때만 script/run-lint-test.sh 생성

### 상위 Requirement

- relates to #221

### 작업 내용

`script/run-lint-test.sh` 를 관리 파일에서 빼고 조건부 생성 파일로 바꾼다. 조건은 리포 루트의 CI 파일 가운데 이번 render 가 생성하지 않는 것에 그 경로가 든 줄이 있는 것이다.

- 근거: 명세 3-1 ~ 3-3, 9절의 `REF_OPTIONAL` 행, 12-3 의 "CI 가 부르는 동안"(doctor 줄 제외) · "서브프로젝트" · "스테이징", 12-4 의 3-1 행
- 판정(3-1)
  - 리포 루트: `repo_prefix()` 판정의 작업 트리 최상위. 하네스 루트가 git 작업 트리 밖이면 하네스 루트다
  - CI 파일: 리포 루트의 `.github/workflows/` 바로 아래 `*.yml` · `*.yaml` 과 `.gitlab-ci.yml`. `forge.review_host` 와 상관없이 둘 다 본다
  - 이번 render 가 생성하는 경로는 보지 않는다
  - 줄에 문자열 `script/run-lint-test.sh` 가 있는지만 본다. YAML 을 해석하지 않는다
  - 일반 파일만 읽는다. 심볼릭 링크와 디렉터리는 건너뛴다. 읽지 못한 파일은 부르는 것으로 본다
  - 읽기만 한다. 내용을 어떤 출력에도 옮기지 않는다
  - `check --staged` 는 인덱스의 CI 파일과 그 내용으로 같은 판정을 한다
- 파일(3-2)
  - `plan()` 이 조건이 맞을 때만 넣는다. `verify.post_commit` 이 켜질 때만 넣는 post-commit 과 같은 자리다
  - 원형 `src/templates/generated/script/run-lint-test.sh` 는 213 명세 4-1 의 shim 공통 템플릿 그대로 `verify` 를 부른다. 권한은 0755 다
  - 머리글은 아래를 적는다. 설정 값은 들어가지 않는다
    - 생성 표지
    - 리포 루트의 CI 파일이 부르는 동안에만 생성된다는 것
    - 그 줄을 `{{HARNESS_CLI}} verify` 로 바꾸면 다음 render 가 걷는다는 것
  - `src/templates/managed/script/run-lint-test.sh` 를 지운다
  - 기존 설치본의 render 에서 관리 파일이던 경로가 생성 파일로 옮겨 간다
    - 정리는 이번에 생성하는 경로를 지우지 않는다
    - 사용자 파일 판정은 두 매니페스트를 함께 본다. 멈추거나 지우지 않는다
- 조건이 바뀔 때(3-3)
  - CI 줄을 바꾸면 다음 render 가 지우고, 더하면 만든다
  - 그 사이 `check` 와 pre-commit 의 `check --staged` 는 생성 파일 대조로 어긋남을 낸다
- `REF_OPTIONAL` 에 `script/run-lint-test.sh` 를 더한다
- 이 리포는 CI 파일이 그 경로를 부르므로 계속 생성된다. 매니페스트에서 관리 줄이 생성 줄로 옮겨 간다
- 기존 테스트 가운데 `script/run-lint-test.sh` 를 관리 파일(`.harness/managed`)로 보던 줄은 생성 파일로 보는 줄로 바꾼다. 대응표에 적는다
- 건드릴 파일
  - 판정 모듈 · `render/plan.py` · `manifest.py` · `changes.py` · `drift.py`
  - `readiness/refs.py`
  - `src/templates/generated/script/run-lint-test.sh`(새로) · `src/templates/managed/script/run-lint-test.sh`(지운다)
  - `src/test/render-test.sh` · `src/test/unit/`

### 완료 조건

- [ ] 리포 루트 `.github/workflows/ci.yml` 에 `script/run-lint-test.sh` 줄을 두면 render 가 그 파일을 만들고 `.harness/generated` 에 둔다
- [ ] 그 파일이 `verify` 와 같은 종료 코드 · 출력을 낸다
- [ ] 줄을 지우면 `check` 가 `left over` 를 내고 render 가 지운다. `.gitlab-ci.yml` 도 같다
- [ ] 심볼릭 링크 CI 파일은 보지 않는다
- [ ] 하위 디렉터리 하네스 루트는 리포 루트의 CI 파일로 판정한다. 하네스 루트 안의 소유 골격만 부르면 만들지 않는다
- [ ] CI 파일의 줄을 지워 스테이징하고 render 하지 않으면 `check --staged` 가 어긋남을 낸다
- [ ] 관리 파일이던 설치본을 render 하면 멈추지 않고, 파일은 생성 파일로 남는다
- [ ] `src/templates/managed/script/run-lint-test.sh` 가 없다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 줄 판정 | 그 문자열이 든 줄 · 주석 줄 · 없는 파일 | 앞 둘은 부름, 뒤는 안 부름 |
| UT-02 | 위치 · 확장자 | `.github/workflows/x.yaml` · `.github/workflows/sub/x.yml` · `.gitlab-ci.yml` · `.github/workflows/x.txt` | 첫째 · 셋째만 봄 |
| UT-03 | 생성 경로 제외 | 이번 render 가 생성하는 CI 경로에만 그 줄 | 안 부름 |
| UT-04 | 읽지 못한 파일 | 권한 없는 CI 파일 | 부름 |
| UT-05 | 생성과 제거 | CI 줄을 더하고 지우는 설치본 | 생성 · `left over` · 제거 |
| UT-06 | 서브프로젝트 | 하위 디렉터리 하네스 루트 | 리포 루트 CI 로 판정 |
| UT-07 | 스테이징 | 줄을 지운 CI 파일을 스테이징 | `check --staged` 어긋남 |
| UT-08 | 관리 → 생성 | 옛 매니페스트의 관리 줄을 가진 설치본 | render 0, `.harness/generated` 로 옮겨짐 |

## T19 · feat: CI 원형 · doctor 검증 절 · 이 리포 CI 의 검증 명령을 CLI verify 로 전환

### 상위 Requirement

- relates to #221

### 작업 내용

새 설치에 까는 CI 원형이 `{{HARNESS_CLI}} verify` 를 부르게 바꾼다. 리포 루트 CI 파일이 옛 경로를 부르는 동안 doctor 가 짚는다. 이 리포의 CI 도 바꿔, 이 리포의 `script/run-lint-test.sh` 가 다음 render 에서 걷힌다.

- 근거: 명세 3-4, 3-5, 12-3 의 "CI 가 부르는 동안" 의 doctor 항목
- doctor(3-4)
  - `verification` 절에 조건을 이루는 CI 파일마다 `warn` 한 줄을 낸다
  - what: `<리포 루트 기준 경로> runs script/run-lint-test.sh`
  - detail: `` the harness keeps generating script/run-lint-test.sh while a CI file runs it — change that line to `<CLI> verify` ``. `<CLI>` 는 4-1 의 값이고, 서브프로젝트면 서브프로젝트 기준이다
  - #217 이 통합 브랜치에 있으면 그 `ci gate` 절의 `<경로> runs script/run-lint-test.sh` 줄은 이 줄 하나로 대신한다
- CI 원형(3-5)
  - `src/templates/ci/<host>/` 아래 원형이 `{{HARNESS_CLI}} verify` 를 부른다. 원형 머리 주석의 `script/run-lint-test.sh` 도 바꾼다
  - 원형은 지금처럼 `derive()` 값으로 치환해 깐다
  - #217 이 통합 브랜치에 있으면 `{{CI_VERIFY}}` 가 내는 명령은 `<CLI> verify` 다
  - `policy.check_min_preset_version` 이 참이면 `<CLI> check --min-preset-version "$HARNESS_MIN_PRESET_VERSION" && <CLI> verify` 다
  - 게이트 템플릿 · 서브프로젝트 골격 · GitLab 루트 원형의 주석도 같은 표기다
  - 이미 깔린 소유 CI 파일은 고치지 않는다
- 이 리포
  - `.github/workflows/harness-verify.yml`(소유 파일)의 검증 단계 `run` 과 머리 주석을 `src/bin/harness verify` 로 바꾼다
  - render 로 이 리포의 `script/run-lint-test.sh` 와 그 매니페스트 줄이 걷힌다
- 새 설치본에 `script/run-lint-test.sh` 가 생기지 않게 되므로, 그 파일이 있다고 보던 기존 `render-test.sh` 줄은 생기지 않는 것으로 바꾼다. 대응표에 적는다
- 건드릴 파일
  - `readiness/items.py`
  - `src/templates/ci/`
  - `.github/workflows/harness-verify.yml`
  - `src/test/render-test.sh`

### 완료 조건

- [ ] CI 파일이 그 경로를 부르는 설치본에서 doctor 가 3-4 의 줄을 파일마다 낸다. 부르지 않으면 줄이 없다
- [ ] 새로 설치한 리포의 CI 파일이 `.harness/bin/harness verify` 를 부르고 `script/run-lint-test.sh` 가 없다
- [ ] #217 이 통합 브랜치에 있으면 `{{CI_VERIFY}}` 의 두 값이 3-5 대로다
- [ ] 이 리포의 CI 가 `src/bin/harness verify` 를 부르고, 이 리포에 `script/run-lint-test.sh` 가 없다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | doctor 줄 | CI 파일 둘이 그 경로를 부르는 설치본 | `warn` 두 줄, detail 의 `<CLI>` 가 `.harness/bin/harness` |
| UT-02 | doctor 줄 없음 | 부르지 않는 설치본 | 그 줄이 없음 |
| UT-03 | 서브프로젝트 detail | 하위 디렉터리 하네스 루트 | detail 의 명령이 서브프로젝트 기준 |
| UT-04 | 새 설치 CI 원형 | GitHub · GitLab 설정으로 새로 설치 | CI 파일이 `.harness/bin/harness verify`, `script/run-lint-test.sh` 없음 |
| UT-05 | 게이트 검증 명령 | #217 이 있을 때 `check_min_preset_version` 참 · 거짓 | 3-5 의 두 명령 |

## T20 · docs: docs/workflow 의 하네스 명령 절과 script/README.md 를 가리키던 자리 갱신

### 상위 Requirement

- relates to #221

### 작업 내용

`script/README.md` 의 내용을 관리 문서 `docs/workflow/` 로 옮기고, 그 파일을 가리키던 자리를 고친다. 파일 자체는 T21 이 지운다.

- 근거: 명세 11-1, 11-2 의 `AI_AGENT.md` 9장 · `src/templates/owned/script/project/README.md` · `docs/workflow/flow.md` · `changing.md` 행
- `src/templates/managed/docs/workflow/README.md`
  - 새 절 "하네스 명령" 을 둔다
  - 절차 · 훅 · 사람이 부르는 하위 명령마다 하는 일 · 종료 코드 · 부르는 시점을 적는다. 옛 목록의 내용을 명령 단위로 옮긴다
  - 대상 명령: 5-1 의 허용 명령, `carryover` · `rollback` · `forge` · `forge-selftest` · `forge-setup` · `bash-guard` · `git-hook` · `clone-key`
  - 옛 경로와의 대응표는 싣지 않는다 — README "업데이트" 가 갖는다
- `src/templates/managed/docs/workflow/flow.md`
  - 흐름 그림 · 표의 스크립트 이름을 하위 명령으로 바꾼다
  - 검증 루프 그림의 `run-lint-test.sh` · `harness-verify.sh` → `{{HARNESS_CLI}} verify` · `verify --steps-only`
  - "가드레일 층" 절에 allow 문단("`.claude/settings.json` 의 allow 는 승인 프롬프트만 없앤다 …")을 옮긴다. "관리 스크립트" 는 "하네스 명령" 으로 바꾼다
- `src/templates/managed/docs/workflow/changing.md`
  - "하네스 자체를 바꾸는 것" 표의 `script/…` 행(표지 · 가드 · 역할 실행기 · 검증)을 패키지 모듈로 바꾼다
  - 새 하위 절 "규칙" 을 둔다. 11-1 의 규칙 목록이다
  - 옛 agent 절 예시는 4-4 의 `run = "{{HARNESS_CLI}} sync-tasks <Requirement 이슈번호>"` · `run = "{{HARNESS_CLI}} review <MR번호>"` 다
- `src/templates/generated/.ai/AI_AGENT.md` 9장
  - `script/README.md` 행을 바꾼다
  - 새 행: `docs/workflow/README.md` 의 "하네스 명령" — 절차와 훅이 부르는 하네스 명령을 실행할 때
- 소유 원형 `src/templates/owned/script/project/README.md` 의 문장을 11-2 의 문장으로 바꾼다
  - "하네스 명령은 `docs/workflow/README.md` 의 '하네스 명령' 절에 있다"
  - "`script/` 바로 아래는 하네스가 생성하는 자리라 프로젝트 스크립트를 두면 하네스 갱신과 겹칠 수 있다"
- 구조 그림과 "파일은 세 부류다" 표는 T23 이 끝 상태로 고친다
- 건드릴 파일
  - `src/templates/managed/docs/workflow/`
  - `src/templates/generated/.ai/AI_AGENT.md`
  - `src/templates/owned/script/project/README.md`
  - render 로 갱신되는 이 리포의 사본

### 완료 조건

- [ ] 설치한 리포의 `docs/workflow/README.md` 에 "하네스 명령" 절이 있다. 11-1 이 든 명령마다 하는 일 · 종료 코드 · 부르는 시점이 있다
- [ ] 설치한 리포의 `docs/workflow/*.md` 에 `{{HARNESS_CLI}}` 글자가 남지 않고, 4-5 의 걷힌 경로가 백틱 경로로 없다
- [ ] 설치한 리포의 아래 자리에 `script/README.md` 가 없다
  - `.ai/AI_AGENT.md` 9장
  - `.ai/templates/docs-writer.md`
  - `.ai/workflows/work.md`
- [ ] 새로 설치한 리포의 `script/project/README.md` 가 11-2 의 문장이다
- [ ] 새로 설치한 리포의 doctor `references` 가 이 문서들에서 끊긴 참조를 짚지 않는다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 하네스 명령 절 | 새로 설치한 리포의 `docs/workflow/README.md` | 절이 있고 11-1 의 명령 열여덟 개가 모두 나옴 |
| UT-02 | 치환 | 같은 리포의 `docs/workflow/*.md` | `{{HARNESS_CLI}}` 없음, `.harness/bin/harness` 표기 |
| UT-03 | 가리키던 자리 | 같은 리포의 규칙 문서 · docs-writer 계약 · work 절차 문서 | `script/README.md` 없음 |
| UT-04 | 끊긴 참조 | 같은 리포의 `harness doctor --json` | `references` 에 이 문서들의 항목 없음 |

## T21 · chore: 관리 스크립트 · 셸 생성물 · 셸 표기 · 셸 회귀 테스트 · script/README.md 걷기

### 상위 Requirement

- relates to #221

### 작업 내용

명세 2절의 걷기를 한 번에 한다. 걷힐 파일을 부르던 하네스 안의 자리는 T7 · T14 ~ T19 가 이미 옮겼다. 셸 회귀 테스트의 검사 줄은 T1 ~ T6 이 옮겼다.

- 근거: 명세 2-1 ~ 2-4, 7-1 의 마지막 항목, 11-2 의 `AI_AGENT.md` 3장 끝 · 10장 행, 12-2 의 첫 항목, 12-3 의 "끝 상태" · "기존 설치본 갱신" · "명령 표기 — 대상 리포" · "명령 표기 — 소스 트리 복제" · "바이트코드"
- 관리 파일: `src/templates/managed/script/` 를 통째로 지운다. 걷을 목록은 착수 시점 트리에서 센다. 기대 목록은 명세 2-2 표다
- 생성 파일
  - `plan()` 에서 `script/githooks/` 밖의 `script/` 생성 파일을 뺀다 — `script/harness.env` · `script/forge.sh` · `script/harness-verify.sh`
  - 만들던 원형과 생성 함수를 지운다 — `harness_env()` · `SHELL_EXPANDS` · `verify_script()` · `VERIFY_SH` · `src/templates/generated/script/forge.sh`
  - `script/run-lint-test.sh` 는 T18 의 조건으로 남는다
- `derive()` 의 값 가운데 생성물 템플릿이 쓰지 않고 `harness.env` 로만 가던 것(`VERIFY_PRE_PUSH` 등)을 없앤다
- render 가 이번 정리로 `script/hooks/bash-guard.sh` 를 지웠으면 표준 오류에 2-4 의 note 한 줄을 낸다. 렌더 결과와 종료 코드는 바뀌지 않는다
- 사라지는 파일의 처리는 지금 규칙 그대로다(2-3)
  - 정리(`prune()`)가 설치 뒤 고친 관리 파일까지 지운다. 비게 된 디렉터리도 걷는다
  - 매니페스트에 없는 사용자 파일, `script/project/`, 고정 사본은 지우지 않는다
- `src/templates/generated/.ai/AI_AGENT.md`
  - 3장 끝: "프로젝트 자동화 스크립트는 `script/project/` 에 두고 `script/project/README.md` 표에 한 줄 추가한다. `script/` 의 나머지(`githooks/`)는 하네스가 생성한다."
  - 10장 배치 표: 관리 행은 `.ai/templates/`, `docs/workflow/`. 생성 행에서 `script/harness.env` · `script/forge.sh` 를 빼고 `script/githooks/` 를 둔다
- `render-test.sh`
  - 설치한 리포의 `script/test-*.sh` 를 세어 돌리는 블록(UT-61)을 지운다
  - 명세 12-3 의 다섯 블록을 더한다: "끝 상태" · "기존 설치본 갱신" · "명령 표기 — 대상 리포" · "명령 표기 — 소스 트리 복제" · "바이트코드"
  - "기존 설치본 갱신" 은 지금 설치본에 옛 경로의 파일과 매니페스트 줄을 더해 옛 설치본을 흉내 낸다
- render 로 이 리포의 `script/` 사본과 매니페스트를 갱신한다. 이 리포 `script/` 에는 `githooks/` · `project/` 만 남는다
- 건드릴 파일
  - `src/templates/managed/script/`(지운다)
  - `src/templates/generated/script/forge.sh`(지운다)
  - `render/plan.py` · `render/scripts.py` · `render/derive.py`
  - render 의 정리 안내
  - `src/templates/generated/.ai/AI_AGENT.md`
  - `src/test/render-test.sh`
  - render 로 갱신되는 이 리포의 사본

### 완료 조건

- [ ] 새로 설치한 리포의 `script/` 에 `githooks/` · `project/` 만 있다. 두 매니페스트에 `script/githooks/` 밖의 `script/` 줄이 없다
- [ ] 옛 설치본을 render 하면 아래가 성립한다
  - 옛 매니페스트의 `script/` 관리 · 생성 파일(손으로 고친 것 포함)이 없고, `script/hooks/` 도 없다
  - 매니페스트에 없는 `script/my.sh` 와 `script/project/` 는 바이트 그대로다
  - 사용자 파일이 든 `script/hooks/` 는 남는다
- [ ] 2-4 의 note 가 `script/hooks/bash-guard.sh` 를 지운 render 에서만 나온다
- [ ] 새로 설치한 리포의 아래 파일에 `.harness/bin/harness` 표기가 있고 4-5 의 걷힌 경로가 없다. 소스 트리 복제는 `src/bin/harness` 표기다
  - `.ai/workflows/*.md` · `.claude/agents/*.md` · `.codex/agents/*.toml` · `.ai/templates/*.md`
  - `.claude/commands/*.md` · `CLAUDE.md` · `.ai/AI_AGENT.md` · `.ai/forge.md`
- [ ] 위 파일들과 `docs/workflow/*.md` 에 `{{HARNESS_CLI}}` 글자가 없다
- [ ] 하네스 코드(`src/harness/` · `src/bin/harness`)가 실행하거나 source 하는 `script/` 아래 하네스 파일이 없다
- [ ] 코드에 `harness_env` · `SHELL_EXPANDS` · `verify_script` · `VERIFY_SH` 가 없다
- [ ] 회귀 블록을 돈 뒤 리포 어디에도 `__pycache__` 가 없다
- [ ] 이 리포 `script/` 에 `githooks/` · `project/` 만 있다
- [ ] `src/test/render-test.sh` 와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 끝 상태 | 새로 설치한 리포 | `script/` 에 `githooks/` · `project/` 만, 매니페스트에 다른 `script/` 줄 없음 |
| UT-02 | 옛 설치본 갱신 | 옛 경로 파일 · 매니페스트 줄(손으로 고친 관리 파일 포함)을 더한 설치본 | render 뒤 그 파일 없음, `script/hooks/` 없음 |
| UT-03 | 남기는 것 | 같은 설치본의 `script/my.sh` · `script/project/` · 사용자 파일이 든 `script/hooks/` | 바이트 그대로, 그 디렉터리 남음 |
| UT-04 | 세션 안내 | `script/hooks/bash-guard.sh` 를 지운 render · 지우지 않은 render | 앞만 2-4 의 note, 둘 다 종료 코드 0 |
| UT-05 | 명령 표기 — 대상 리포 | 새로 설치한 리포의 열거 파일 | `.harness/bin/harness` 표기, 걷힌 경로 없음, `{{HARNESS_CLI}}` 없음 |
| UT-06 | 명령 표기 — 소스 트리 | 소스 트리 복제의 같은 파일 | `src/bin/harness` 표기 |
| UT-07 | 바이트코드 | 위 블록을 돈 뒤 | `__pycache__` 없음 |

## T22 · feat: UI Doctor 의 새 설정 · CI 항목과 단계 입력 자리표시를 하네스 CLI 표기로 전환

### 상위 Requirement

- relates to #221

### 작업 내용

CLI 가 새로 내는 doctor 줄 셋과 하네스 CLI 표기를 UI 가 옮기고, 단계 편집 화면의 자리표시를 새 표기로 바꾼다.

- 근거: 명세 10절의 `adapter <kind>` · 새 항목 셋 · `FlowCanvas.js` 행, 12-5 의 둘째 항목과 셋째 항목의 `forge-selftest`
- `src/ui/lib/doctor.js`
  - `adapter <kind>` 미검증의 보일 명령: `${harness_cli} forge-selftest <리뷰요청번호> <이슈번호>`. `harness_cli` 가 없는 옛 사본이면 지금 문구다
  - 새 항목 셋을 둔다. 셋 다 조치 명령이 없다

    | 절 | 원문 | 제목 | 본문 |
    |---|---|---|---|
    | `config` | `` `<키>` names <경로> `` | 설정이 없어진 하네스 스크립트를 부릅니다 | detail 의 새 표기로 바꾸라는 것, 바꾸기 전에는 생성이 멈춘다는 것 |
    | `config` | `` `verify.script_tests` is no longer read `` | 더 쓰지 않는 설정 키가 있습니다 | 하네스 회귀 테스트는 하네스 리포에서 돕니다. 이 키는 지워도 됩니다. |
    | `verification` | `<경로> runs script/run-lint-test.sh` | CI 가 옛 검증 스크립트를 부릅니다 | 그 줄을 detail 의 명령으로 바꾸면 하네스가 옛 스크립트를 걷는다는 것 |

- `src/ui/components/FlowCanvas.js`
  - script 단계 입력의 자리표시 글: `script/<이름>.sh <인자>` → `{{HARNESS_CLI}} <명령> <인자>`
  - 공용 실행기 주석: `script/run-agent.py` → `harness run-agent`
- `src/ui/lib/doctor.test.js` 에 12-5 의 케이스를 더한다
- 건드릴 파일
  - `src/ui/lib/doctor.js` · `src/ui/lib/doctor.test.js`
  - `src/ui/components/FlowCanvas.js`

### 완료 조건

- [ ] 새 항목 셋이 원문과 다른 제목 · 본문으로 옮겨지고 조치가 없다. 다른 절의 같은 문구에는 붙지 않는다
- [ ] `forge-selftest` 의 보일 명령이 `harness_cli` 를 쓰고, 그 키가 없으면 지금 문구다
- [ ] `FlowCanvas.js` 에 `script/<이름>.sh` · `script/run-agent.py` 글자가 없다
- [ ] UI 단위 테스트(`cd src/ui && node --test lib/*.test.js`)와 `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 걷힌 경로 설정 항목 | `config` 절 `` `workflows.work.steps[0].run` names script/sync-task-issues.sh `` | 제목 "설정이 없어진 하네스 스크립트를 부릅니다", 조치 없음 |
| UT-02 | 무시되는 키 항목 | `config` 절 `` `verify.script_tests` is no longer read `` | 제목 "더 쓰지 않는 설정 키가 있습니다", 조치 없음 |
| UT-03 | CI 항목 | `verification` 절 `.github/workflows/ci.yml runs script/run-lint-test.sh` | 제목 "CI 가 옛 검증 스크립트를 부릅니다", 조치 없음 |
| UT-04 | 다른 절 | 같은 문구를 다른 절에 둔 항목 | 위 제목이 붙지 않음 |
| UT-05 | forge-selftest 보일 명령 | `harness_cli` 가 있는 schema · 없는 schema | `.harness/bin/harness forge-selftest <리뷰요청번호> <이슈번호>` · 지금 문구 |

## T23 · docs: README · 설정 주석 · 프로젝트 문서의 이행 안내와 끝 상태 반영

### 상위 Requirement

- relates to #221

### 작업 내용

사람용 문서와 설정 주석에 끝 상태와 갱신 안내를 적는다.

- 근거: 명세 11-2 의 README · `docs/workflow/README.md` 구조 그림 · `src/templates/defaults.toml` · `harness.toml` · `vendors.toml` · `fake-forge.sh` · `environment.md` · `review-checks.md` 행, 11-1 의 부류 표 행
- `README.md` "업데이트"
  - 4-5 의 대응표(옛 이름 → 새 표기)
  - 이 갱신이 대상 리포에서 지우는 것(2-2)
  - 걷힌 경로를 가리키는 설정 값에서 render 가 멈춘다는 것과 고치는 법(4-5 의 표, 이전 기본값 절이면 `harness fix legacy-work`)
  - CI 파일의 `script/run-lint-test.sh` 를 바꾸면 그 shim 이 걷힌다는 것
  - `verify.script_tests` 를 지워도 된다는 것
  - `script/forge.sh` · `script/harness.env` 를 쓰던 프로젝트 스크립트는 `harness forge` · `harness vars` 로 바꾼다는 것
  - 프로젝트 문서에 남은 옛 경로는 doctor 의 `references` 가 짚는다는 것
- `README.md` 의 다른 절
  - "명령" 표: 하위 명령 행의 "절차는 `script/…` 로 부른다" 문장을 지운다. `harness fix verify` 의 설명을 고친다
  - "파일은 세 부류다" · "구조": 11-1 과 같은 부류. 설치본 트리의 `script/` 는 `githooks/` · `project/`
  - "`harness.toml` 이 정하는 것": `verify.*` 행은 검증(`harness verify` · pre-push · CI)이 실행할 때 읽는다. `script_tests` 를 뺀다. `permissions.allow_push` 행의 "관리 스크립트" → "하네스 명령"
  - "검증": 설치된 리포는 `.harness/bin/harness verify` 가 생성물 일치와 검증 단계를 잇는다
  - "지원 범위": 자체 검사 예시를 `.harness/bin/harness forge-selftest …` 로
  - "언어": 표지의 정본은 `src/harness/format.py`
- `src/templates/managed/docs/workflow/README.md`
  - 구조 그림: `script/githooks/ · harness.env` 줄을 `script/githooks/  훅 (생성)` 으로 바꾸고, `script/*.sh  배관 (관리)` 줄을 지운다
  - "파일은 세 부류다" 표: 생성 행에 `script/githooks/`(와 3절의 `script/run-lint-test.sh`)를 두고, 관리 행에서 `script/` 를 뺀다
- `src/templates/defaults.toml` 주석
  - `[permissions]` 의 "관리 스크립트" → "하네스 명령"
  - `[commands]` · `[verify]` 주석 예시의 `script/check-deps.sh` → `script/project/check-deps.sh`
  - `[commands]` 머리 주석의 괄호 → `harness verify`
- 이 리포 `harness.toml` 의 `[commands]` 머리 주석: 같은 괄호
- `src/templates/vendors.toml` 의 `usage_format` 주석: "`run-agent.py` 가 출력을 받아" → "역할 실행기(`harness run-agent`)가 출력을 받아"
- `src/test/fake-forge.sh` 머리글: 끼우는 법은 `HARNESS_FORGE_FAKE` 하나다
- `.ai/project/environment.md`: `HARNESS_TRACE_ID` 행의 "`script/metric.py` 가 준다" → "`harness run` 과 `harness span` 이 준다"
- `.ai/project/review-checks.md`
  - 표지 행 → "표지(`src/harness/format.py`)를 바꿨으면 그것을 쓰는 역할 계약도 같은 변경에 있는가"
  - 관리 스크립트 행 → "하위 명령을 더했으면 `docs/workflow/README.md` 의 '하네스 명령' 표에 한 줄이 있는가"
- 건드릴 파일
  - `README.md`
  - `src/templates/managed/docs/workflow/README.md`
  - `src/templates/defaults.toml` · `harness.toml` · `src/templates/vendors.toml`
  - `src/test/fake-forge.sh`
  - `.ai/project/environment.md` · `.ai/project/review-checks.md`
  - render 로 갱신되는 사본

### 완료 조건

- [ ] README "업데이트" 의 대응표가 4-5 상수의 행을 모두 담는다
- [ ] README · `docs/workflow/README.md` · `defaults.toml` · `vendors.toml` · `environment.md` · `review-checks.md` 에 걷힌 파일이 `script/` 를 붙인 백틱 경로로 없다
- [ ] README 의 `script_tests` 와 "절차는 `script/…` 로 부른다" 문장이 없다
- [ ] 이 리포의 doctor `references` 가 README · `docs/workflow/` · `.ai/project/` 에서 걷힌 파일을 짚지 않는다
- [ ] `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 대응표 | README "업데이트" 와 4-5 상수 | 상수의 걷힌 경로가 표에 모두 있음 |
| UT-02 | 끊긴 참조 | 이 리포의 `harness doctor --json` | `references` 에 README · `docs/workflow/` · `.ai/project/` 항목 없음 |
| UT-03 | 설치본 문서 | 새로 설치한 리포의 `docs/workflow/README.md` | 구조 그림과 부류 표가 끝 상태 |

## T24 · docs: 이전 명세의 걷힌 경로 서술을 현재형으로 갱신

### 상위 Requirement

- relates to #221

### 작업 내용

이 이슈 전에 머지된 명세 가운데 걷힌 `script/<이름>` 을 현재형으로 적은 문장을 끝 상태로 고친다.

- 근거: 명세 11-2 의 `docs/spec/70-generate-permission-allow-list.md` · `docs/spec/58` ~ `96` · `docs/spec/README.md` 행
- `docs/spec/70-generate-permission-allow-list.md` 1절 · 3절 · 6절 · 7절을 현재형으로 고친다
  - 첫 묶음은 5-1 의 하위 명령 규칙이고, 허용 표시가 `COMMANDS` 에 있다
  - 제외 이유 표는 5-1 의 표다
  - 가드레일 층위 표의 자리는 `docs/workflow/flow.md` 다
- `docs/spec/58` · `59` · `60` · `62` · `63` · `64` · `71` · `96`
  - 걷힌 `script/<이름>` 을 현재형으로 적은 문장을 4-5 의 새 표기로 바꾼다
  - 58 의 doctor 출력 예시는 예시라 그대로 둔다
- `docs/spec/README.md` 의 이 명세 행이 구현된 범위와 같은지 맞춘다
- 걷힌 파일은 `script/` 를 붙인 백틱 경로로 적지 않는다(11-2 머리)
- 건드릴 파일: 위 명세 파일

### 완료 조건

- [ ] 70 의 네 절이 하위 명령 규칙 · 허용 표시 · 5-1 제외 이유 표 · `docs/workflow/flow.md` 를 현재형으로 적는다
- [ ] 58 · 59 · 60 · 62 · 63 · 64 · 71 · 96 에 걷힌 경로를 현재형으로 적은 문장이 없다. 58 의 doctor 출력 예시는 남는다
- [ ] 이 리포의 doctor `references` 가 이 명세들에서 걷힌 파일을 짚는 항목이 58 의 예시 말고 없다
- [ ] `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 끊긴 참조 | 이 리포의 `harness doctor --json` | `references` 에서 위 명세의 항목이 58 의 예시뿐 |
| UT-02 | 허용 목록 명세 | `docs/spec/70-generate-permission-allow-list.md` | `allowed_scripts` · `ALLOW_EXCLUDED` 를 현재형으로 적은 문장 없음 |

## T25 · docs: 이식 명세들의 shim · 셸 생성물 서술을 현재형으로 갱신

### 상위 Requirement

- relates to #221

### 작업 내용

같은 로드맵의 명세들이 현재형으로 적은 shim · 셸 생성물 · `script/<이름>` 표기와, 가드 · 훅이 설정을 읽는 방식을 이 이슈의 결과로 고친다.

- 근거: 명세 11-2 의 `docs/spec/206-…` 7-5 · `207-…` 2-2 · `216-…` 5-2 · 선행 명세 행
- `docs/spec/206-split-cli-into-package.md` 7-5
  - "단위 테스트는 CLI 를 하위 프로세스로 띄우지 않는다" 뒤에 문장을 더한다: "하위 명령의 외부 계약 시험은 예외다 — 임시 하네스 루트에 설치한 CLI 를 하위 프로세스로 부른다(221 명세 12-1)"
  - 스모크 테스트 행은 12-4 의 문장으로 바꾼다
- `docs/spec/207-layered-config.md` 2-2
  - "이 명세 뒤의 이슈가 더하는 명령" 표에서 `bash-guard` · `git-hook` 을 "레이어를 읽지 않는다" 행에서 "공유 설정" 행으로 옮긴다
  - `git-hook` 은 commit-msg · pre-push 가 읽고, pre-commit 은 `check` 로 본다
- `docs/spec/216-org-presets.md` 5-2
  - "설정을 읽지 않는 명령(`bash-guard` · `secret-scan` · `clone-key` 등)" 에서 `bash-guard` 를 뺀다
  - 명령별 동작 표에 `bash-guard` · `git-hook` 행을 더한다 — 어긋남 · 읽을 수 없음 모두 설정을 읽지 못했을 때처럼 막는다(221 명세 7-1 — 가드 2, commit-msg · pre-push 1)
- 선행 명세 `docs/spec/209-…` · `210-…` · `211-…` · `212-…` · `213-…` · `215-…` · `217-…`
  - shim · 셸 생성물 · `script/<이름>` 표기를 현재형으로 적은 절의 머리에, 그 내용을 이 명세의 어느 절이 걷었는지 한 줄을 둔다
  - 본문의 현재형 서술을 그 결과로 고친다
- 건드릴 파일: 위 명세 파일

### 완료 조건

- [ ] 206 7-5 에 계약 시험 예외 문장이 있고, 스모크 행이 다섯 원소 문장이다
- [ ] 207 2-2 표에서 `bash-guard` · `git-hook` 이 "공유 설정" 행에 있다
- [ ] 216 5-2 의 설정을 읽지 않는 명령에 `bash-guard` 가 없고, 명령별 동작 표에 `bash-guard` · `git-hook` 행이 있다
- [ ] 209 · 210 · 211 · 212 · 213 · 215 · 217 에서 shim · 셸 생성물을 현재형으로 적은 절마다 머리에 걷은 절을 가리키는 한 줄이 있다
- [ ] 이 명세들에 걷힌 파일이 `script/` 를 붙인 백틱 경로로 현재형 문장에 남지 않는다
- [ ] `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 끊긴 참조 | 이 리포의 `harness doctor --json` | `references` 에 이 명세들의 현재형 문장 항목 없음 |
| UT-02 | 설정 원칙 표 | 207 2-2 · 216 5-2 | `bash-guard` · `git-hook` 의 행이 7-1 과 같음 |

## T26 · docs: 보호 문서를 명세 13절 범위로 개정

### 상위 Requirement

- relates to #221

### 작업 내용

보호 문서 셋을 명세 13절의 범위 안에서 고친다. **2026-10-09 결정 게이트에서 사용자가 허용한 범위**다. 표에 없는 문장은 고치지 않는다.

- 근거: 명세 13-1 ~ 13-4
- 적용 순서는 #206 → #207 → #208 · #209 · #210 → #211 → #212 → #213 → #215 다음이 이 명세다
  - 13절의 문안은 #215 까지 반영된 문장 위에서 shim · 셸 생성물 · 옛 표기를 걷는다
  - 문안이 가리키는 구절을 착수 시점 통합 브랜치의 문서에서 내용으로 찾아 고친다
  - 찾지 못하는 구절은 고치지 않고 리뷰 요청 본문에 보고한다
- `.ai/project/architecture.md`: 13-1 표의 행 전부
  - 구성 요소: CLI 패키지 · 대상 리포 `script/` · `src/templates/` · `src/test/render-test.sh` 항목
  - 데이터 흐름: 렌더 · 절차 실행 · forge · 실행 지표 · 가드 · 훅
  - 신뢰 경계: 리포 루트 CI 파일 항목
  - 새 코드를 둘 곳: 새 forge · 계약 함수 · 새 관리 스크립트 · 리뷰 루프 · 새 가드 · 표지 · 새 회귀 테스트
  - 계층과 의존 방향: 규칙 값 · forge · 하위 명령 · 클론 키
  - 검사하지 않는 것
- `.ai/project/glossary.md`: 13-2 표의 행 전부
  - 용어 행: `관리 파일` · 새 `하네스 CLI 표기` · `shim` · `실행 계획` · `자체 검사` · `forge 페이크` · `task 이슈` · `착수 판정` · `회차 라벨` · `판정 명령` · `이월 이슈` · `표지`
  - 폐기된 별칭: `script/verify-project.sh` 행과 새 행 다섯
- `.ai/project/testing.md`: 13-3 표의 행 전부
  - 관리 스크립트 항목 전체
  - Python 단위 테스트 항목의 세 구절
  - forge 항목
- `.ai/project/scope.md` 는 바꾸지 않는다(13-4)
- 걷힌 파일은 `script/` 를 붙인 백틱 경로로 적지 않는다(11-2 머리)
- 건드릴 파일: `.ai/project/architecture.md` · `.ai/project/glossary.md` · `.ai/project/testing.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] 13-1 · 13-2 · 13-3 표의 행마다 반영할 사실이 해당 위치에 있다
- [ ] 표에 없는 문장과 `.ai/project/scope.md` 가 바뀌지 않는다
- [ ] 세 문서에 걷힌 파일이 `script/` 를 붙인 백틱 경로로 남지 않는다. 이 리포의 doctor `references` 가 세 문서와 `.ai/AI_AGENT.md` 에서 걷힌 파일을 짚지 않는다
- [ ] render 로 `.ai/AI_AGENT.md` 1~5장이 갱신되고 `harness check` 가 0 이다
- [ ] `src/bin/harness verify --commit` 이 통과한다

### 브랜치

- `chore/221-retire-shims-and-generated` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 고친 세 문서로 render 한 이 리포 | `harness check` 0 |
| UT-02 | 끊긴 참조 | 이 리포의 `harness doctor --json` | `references` 에 세 문서와 `.ai/AI_AGENT.md` 의 항목 없음 |
| UT-03 | 범위 | 세 문서의 diff | 13절 표의 위치 밖 변경 없음, `scope.md` 변경 없음 |
