# #219 task

## T1 · docs: 레지스트리 운영 안내 문서와 목차 한 행, README 지원 범위의 안내 링크 추가

### 상위 Requirement

- relates to #219

### 작업 내용

preset 을 레지스트리로 배포하는 팀이 무엇을 준비하고 누가 올리고 누가 받는지를, 하네스가 레지스트리에 기대는 것 중심으로
벤더 중립으로 적는 관리 문서를 새로 둔다. 레지스트리 벤더 이름은 쓰지 않는다 — Harbor 의 사실은 T2 가 이 문서 끝에 더한다.

- 첫 변경 전 확인(명세 2-1 · 2-3 · 5절): 이슈 #219 의 가장 최근 `## 실측 입력 — Harbor` 댓글을 찾아 아래를 모두 확인한다.
  하나라도 어긋나면 아무것도 바꾸지 않고 빠진 전제를 보고한다
  - #217 · #218 이 `develop` 에 머지되어 있다
  - 댓글의 칸이 모두 채워져 있다
  - "버전 공개" 칸이 `허용 확인`, "검증 수단" 칸이 `수동 실측` 이다
  - "M1 왕복 확인" · "M2 CI push (config.json auths)" · "M3 정책 아래 pull" 칸이 모두 `통과` 다
  - "인증" 칸이 `none` · `basic` · `bearer` 가운데 하나, "O1 referrers 경로" 칸이 `api` · `fallback` 가운데 하나다
- 명세 4-1 · 4-2 · 4-3 · 4-5
- 새 관리 문서 `src/templates/managed/docs/workflow/registry.md`, 제목 "레지스트리 운영". 아래 두 절을 이 순서로 담는다
  - "하네스가 레지스트리에 기대는 것" — 명세 4-2 표의 여섯 주제(저장소 · 자격 · 인증 · 고정 · 서명 · 대상 리포 CI)를 표의
    내용대로 적는다
    - 인증: 개발자는 credential helper 를 두고 `harness registry login` 으로 로그인한다. 헬퍼가 없으면 `registry login` 이
      거부한다(#218 8-4). 헬퍼가 없는 CI 는 다른 도구(`docker login` 등)가 써 둔 `config.json` 으로 인증하고
      `harness registry login` 을 쓰지 않는다
    - 고정: lock(`.harness/preset.lock`)의 digest 로 고정한다(#216 4-3)
    - 대상 리포 CI: 레지스트리에 붙지 않는다. 커밋된 vendoring(`.harness/preset/`)과 lock 을 CI 게이트가 도는 `harness check` 가
      대조하고, preset 정책(허용 출처 · 최소 버전)도 같은 명령이 본다(#216 5절 · #217 5절). 게이트 파일과 체크 이름은 같은
      디렉터리의 `ci-gate.md` 로 잇는다(`[ci-gate.md](ci-gate.md)`)
  - "레지스트리 확인" — 명세 4-3 의 네 항목
    - `harness registry check --push` 는 태그 불변 규칙과 서명 강제를 걸지 않은 확인용 저장소에서 돌린다. 태그는 check 가
      실행마다 새로 짓는다(#218 8-7)
    - 올린 확인용 아티팩트는 남고 하네스는 지우지 않는다. 레지스트리의 보존 정책으로 정리한다
    - 태그 불변 규칙과 서명 강제 아래의 흐름은 check 가 아니라 실제 `harness preset push`(서명 포함)와 `harness pull` 로 확인한다
    - 지원 목록 링크: `https://github.com/willjsw/harness/blob/main/README.md#지원-범위`
- `src/templates/managed/docs/workflow/README.md` 의 문서 표에서 `ci-gate.md` 행 뒤에 한 행 — 문서 `[registry.md](registry.md)`,
  답하는 것 "preset 을 레지스트리로 배포할 때 무엇을 준비하나. 누가 올리고 누가 받나"
- `README.md` "지원 범위" 절의 레지스트리 표와 그 안내 뒤에, 운영 안내 `docs/workflow/registry.md` 로 가는 링크 한 문장.
  레지스트리별 실측 사실은 README 에 적지 않는다
- `src/bin/harness render` 로 이 리포의 `docs/workflow/registry.md` · `docs/workflow/README.md` 사본과 `.harness/managed` 를 갱신한다
- 건드릴 파일: `src/templates/managed/docs/workflow/registry.md`(신규), `src/templates/managed/docs/workflow/README.md`,
  `README.md`, render 로 갱신되는 `docs/workflow/` · `.harness/managed`

### 완료 조건

- [ ] 첫 변경 전에 실측 입력 댓글이 착수 전제(명세 2-1)와 통과 기준(2-3)을 채우는지 확인했다
- [ ] `src/templates/managed/docs/workflow/registry.md` 가 제목 "레지스트리 운영" 아래 명세 4-2 · 4-3 을 이 순서로 담는다
- [ ] 4-2 의 여섯 주제가 모두 있다. 하네스가 저장소 · 권한 · 불변 규칙 · 보존 · 복제를 만들거나 바꾸지 않는다는 것, 자격증명을
  저장하지 않는다는 것, 서명하지도 검증하지도 않는다는 것이 적혀 있다
- [ ] 문서에 레지스트리 벤더 이름이 없다
- [ ] 대상 리포 CI 주제가 `ci-gate.md` 로 같은 디렉터리 상대 링크된다
- [ ] 지원 목록 링크가 하네스 리포 README "지원 범위" 절의 절대 주소이고, 문서에 `../` 로 시작하는 상대 링크가 없다
- [ ] 문서에 백틱으로 적은 `.ai/` · `.claude/` · `.codex/` · `script/` · `docs/` 경로가 모두 대상 리포에도 깔리는 파일이다
- [ ] `docs/workflow/README.md` 문서 표에 `registry.md` 행이 `ci-gate.md` 행 뒤에 있다
- [ ] README "지원 범위" 에 `docs/workflow/registry.md` 로 가는 링크 문장이 하나 있고 Harbor 의 실측 사실은 없다
- [ ] render 뒤 이 리포의 `docs/workflow/registry.md` · `docs/workflow/README.md` 가 정본과 같다
- [ ] 명세 2-5 의 항목이 문서와 커밋 메시지에 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `chore/219-harbor-support` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 착수 전제 확인 | 이슈 #219 의 가장 최근 실측 입력 댓글 | 칸이 모두 차 있고 버전 공개 `허용 확인` · M1 · M2 · M3 `통과`. 아니면 변경 없이 보고 |
| UT-02 | 정본과 사본 일치 | render 뒤 `src/bin/harness check` | 생성물 · 관리 파일이 일치하고 종료 코드 0 |
| UT-03 | 벤더 중립 | `grep -n -i harbor src/templates/managed/docs/workflow/registry.md` | 출력 없음 |
| UT-04 | 대상 리포에서도 맞는 링크 | `grep -n '](\.\./' src/templates/managed/docs/workflow/registry.md` | 출력 없음 |
| UT-05 | 문서가 적은 경로의 실재 | render 뒤 `src/bin/harness doctor` 의 references 절 | `docs/workflow/registry.md` · `docs/workflow/README.md` · `README.md` 를 가리키는 경고 없음 |
| UT-06 | 공개 기록 제외 | 바꾼 문서 셋과 커밋 메시지 | 명세 2-5 의 항목 없음 |

## T2 · docs: 지원 목록에 Harbor 한 줄과 레지스트리 운영 안내에 Harbor 절 추가

### 상위 Requirement

- relates to #219

### 작업 내용

실측 입력 댓글의 값으로 Harbor 를 지원 목록에 올리고, 실측으로 확인된 Harbor 사실을 운영 안내 끝에 적는다. 두 곳이 같은
댓글에서 채워지고 Harbor 절이 지원 목록을 가리키므로 한 커밋에 둔다.

- 명세 3절 · 4-4 · 2-5
- 쓰는 댓글: 이슈 #219 의 가장 최근 `## 실측 입력 — Harbor` 댓글. T1 의 확인 뒤에 새 실측 입력 댓글이 생겼으면 그 댓글을 T1 의
  확인 항목으로 다시 확인하고 쓴다
- `README.md` "지원 범위" 의 레지스트리 표(#218 9절) 끝에 한 줄. 칸마다 실측 입력 댓글에서 채운다

  | 지원 목록 칸 | 값 |
  |---|---|
  | 레지스트리 | `Harbor` |
  | 검증한 버전 | "Harbor 버전" 칸 그대로 |
  | referrers | "O1 referrers 경로" 칸 그대로 |
  | 인증 | "인증" 칸 그대로 |
  | 검증 수단 | "검증 수단" 칸 그대로 — `수동 실측` |

  - 버전을 범위로 넓히지 않는다 — "2.x" · "이상" 같은 표기를 쓰지 않는다
  - 댓글에 없는 값은 적지 않는다
- `src/templates/managed/docs/workflow/registry.md` 끝에 절 "Harbor"
  - 검증한 버전은 다시 적지 않고 지원 목록(T1 과 같은 절대 주소)을 가리킨다
  - M2: credential helper 가 없는 CI 가 다른 도구가 써 둔 `config.json` 의 `auths` 로 인증해 `harness preset push` 를 했다
  - M3: 태그 불변 규칙과 서명 강제가 걸린 프로젝트에서 서명된 아티팩트를 `harness pull` 로 받았다
  - O1: referrers 조회 경로 — `api` 면 referrers API 로, `fallback` 이면 referrers 태그 규칙으로 조회했다
  - O2 · O3: 댓글에서 관측된 칸만 적는다. "관측 안 함" 인 칸은 적지 않는다. O2 는 서명을 붙이기 전의 아티팩트 pull 이
    거부됐는지 허용됐는지만 적는다. O3 은 관측 내용에서 명세 2-5 의 항목을 뺀 것만 적는다
  - Harbor 의 프로젝트 · robot 계정 · 태그 불변 규칙 · 서명 정책을 만드는 절차는 적지 않고 Harbor 공식 문서로 넘긴다.
    공식 문서 주소는 구현할 때 열리는 것을 확인하고 쓴다
- `src/bin/harness render` 로 이 리포의 `docs/workflow/registry.md` 사본과 `.harness/managed` 를 갱신한다
- 건드릴 파일: `README.md`, `src/templates/managed/docs/workflow/registry.md`, render 로 갱신되는 `docs/workflow/registry.md` ·
  `.harness/managed`

### 완료 조건

- [ ] 지원 목록에 Harbor 줄이 하나 더해졌고 다섯 칸이 실측 입력 댓글의 해당 칸과 글자 그대로 같다
- [ ] 검증한 버전이 범위 표기 없이 하나다
- [ ] 운영 안내 끝에 Harbor 절이 있고 M2 · M3 결과와 O1 이 적혀 있다
- [ ] Harbor 절이 검증한 버전을 다시 적지 않고 지원 목록 주소를 가리킨다
- [ ] "관측 안 함" 인 O2 · O3 이 문서에 없다
- [ ] Harbor 설정 절차가 없고 Harbor 공식 문서로 넘긴다
- [ ] 운영 안내에서 Harbor 라는 이름이 Harbor 절 안에만 나온다
- [ ] 명세 2-5 의 항목이 README · 운영 안내 · 커밋 메시지에 없다
- [ ] render 뒤 이 리포의 `docs/workflow/registry.md` 가 정본과 같다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `chore/219-harbor-support` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 지원 목록 칸 대조 | README 지원 목록의 Harbor 줄과 실측 입력 댓글 | 다섯 칸이 글자 그대로 같다 |
| UT-02 | 버전 범위 표기 없음 | Harbor 줄의 검증한 버전 칸 | 실측 입력의 "Harbor 버전" 하나이고 `x` · `이상` · `~` 가 없다 |
| UT-03 | 관측 안 함 칸 | O2 나 O3 이 "관측 안 함" 인 실측 입력 | 그 항목의 문장이 Harbor 절에 없다 |
| UT-04 | 벤더 이름 위치 | `grep -n -i harbor src/templates/managed/docs/workflow/registry.md` | Harbor 절 안의 줄만 나온다 |
| UT-05 | 정본과 사본 일치 | render 뒤 `src/bin/harness check` | 생성물 · 관리 파일이 일치하고 종료 코드 0 |
| UT-06 | 공개 기록 제외 | README · 운영 안내 · 커밋 메시지 | 명세 2-5 의 항목 없음 |
