# #79 task

## T1 · feat: install 이 다른 경로에 등록된 같은 이름을 거부하고 낡은 등록을 넘겨받음

### 상위 Requirement

- relates to #79

### 작업 내용

`harness install` 이 설치하는 리포의 `project.name` 이 아직 쓰이는 다른 경로에 등록돼 있으면 아무것도 바꾸지 않고 종료 코드 2 로
멈추게 하고, 옛 경로가 더는 그 프로젝트가 아니면 등록을 넘겨받게 한다.

- 명세 1절(바뀌는 것과 바뀌지 않는 것) · 2절(등록 판정) · 6-1 의 install 케이스 · 6-2(기존 케이스)
- 판정 함수: `~/.harness/<이름>/project.json` 의 `path` 를 명세 2-1 표대로 가른다 — 등록 없음 · 재설치 · 낡은 등록(옛 경로에 `harness.toml`
  이 없음, 또는 읽힌 `project.name` 이 다름) · 아직 쓰는 중(읽힌 `project.name` 이 같음) · 옛 설정을 읽지 못함. 옛 설정은 `tomllib` 으로
  읽기만 하고 `validate()` 를 돌리지 않는다
- `cmd_install` 은 판정을 가장 먼저 돈다 — 소스 리포 분기에서는 옛 사본을 걷어내기 전, 일반 분기에서는 `.harness/` 를 지우기 전.
  거부면 명세 2-3 의 두 안내문 중 하나를 표준 오류로 내고 종료 코드 2
- `register()`: `unregister(target)` 로 현재 하네스 루트를 가리키는 `project.json` 을 이름과 관계없이 지운 뒤 새 `project.json` 을 쓴다.
  넘겨받은 경우 명세 2-2 의 `install: ... registered here instead` 한 줄을 표준 출력에 낸다. `~/.harness/<이름>/` 아래 다른 파일은 건드리지 않는다
- `register()` 위의 "나중에 설치한 쪽이 이긴다" 주석을 지운다
- `render-test.sh` 에 새 `UT-62` 블록: 두 리포 A · B 를 같은 `project.name` 으로 두고 명세 6-1 표의 install 케이스(다른 경로의 같은 이름 ·
  같은 경로 재설치 · 이름을 바꾼 두 번째 클론 · 옛 경로에 설정이 없다 · 옛 경로가 없다 · 옛 경로의 이름이 다르다 · 옛 설정을 읽지 못한다 ·
  경로가 없는 등록 · 이름 변경 뒤 재설치 · 소스 리포)를 확인한다. 이 블록의 터미널 출력에도 한글 검사를 적용한다
- 같은 `project.name` 으로 여러 리포를 설치해 둔 채 다시 설치하는 기존 케이스는 리포마다 다른 이름을 주거나 앞 리포를 지운 뒤 설치하도록 고친다.
  검증하는 내용은 바꾸지 않는다
- 건드릴 파일: `src/bin/harness`(`register()` · `unregister()` · `cmd_install`), `src/test/render-test.sh`

### 완료 조건

- [ ] 같은 이름이 아직 쓰이는 다른 경로에 등록돼 있으면 `harness install` 이 종료 코드 2 로 멈추고, 표준 오류에 명세 2-3 의 안내문이 나온다
- [ ] 거부된 설치 뒤 대상 리포에 `.harness/` 와 생성 파일이 없고, 등록부의 `path` 가 옛 경로 그대로다
- [ ] 옛 경로에 `harness.toml` 이 없거나 경로가 없거나 옛 설정의 `project.name` 이 다르면 설치가 통과하고 `path` 가 새 경로이며, `~/.harness/<이름>/` 아래 기존 파일이 남는다
- [ ] 옛 경로의 `harness.toml` 을 읽지 못하면 설치가 종료 코드 2 로 멈추고 표준 오류에 `could not be read` 와 옛 설정 경로가 나온다
- [ ] 같은 경로 재설치가 지금처럼 통과한다
- [ ] 이름을 바꿔 다시 설치하면 그 경로를 가리키던 옛 이름의 `project.json` 이 없다
- [ ] 소스 리포 분기에서 거부되면 옛 사본 걷어내기와 렌더가 일어나지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/79-reject-duplicate-project-name` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 다른 경로의 같은 이름 거부 | A 설치 뒤 같은 이름의 B 설치 | 종료 코드 2, 표준 오류에 `error:` · A 의 경로 · `harness uninstall` · `project.name`. `path` 는 A, B 에 `.harness/` · `.ai/AI_AGENT.md` 없음 |
| UT-02 | 같은 경로 재설치 | A 를 다시 설치 | 종료 코드 0, `path` 는 A |
| UT-03 | 이름을 바꾼 두 번째 클론 | B 의 `project.name` 을 바꾸고 설치 | 통과, 두 이름이 각자의 경로를 가리킨다 |
| UT-04 | 옛 경로에 설정이 없음 | A 의 `harness.toml` 삭제 뒤 B 설치 | 통과, `path` 는 B, 표준 출력에 `which no longer holds this project`, 미리 둔 표지 파일이 남는다 |
| UT-05 | 옛 경로가 없음 | A 디렉터리 삭제 뒤 B 설치 | 통과, `path` 는 B |
| UT-06 | 옛 경로의 이름이 다름 | A 의 `project.name` 을 설정 파일에서만 바꾸고 B 설치 | 통과, `path` 는 B |
| UT-07 | 옛 설정을 읽지 못함 | A 의 `harness.toml` 을 TOML 로 읽히지 않게 만든 뒤 B 설치 | 종료 코드 2, 표준 오류에 `could not be read` 와 A 의 설정 경로, `path` 는 A |
| UT-08 | 경로가 없는 등록 | `project.json` 이 `{}` 인 상태에서 B 설치 | 통과, `path` 는 B |
| UT-09 | 이름 변경 뒤 재설치 | A 의 이름을 바꾸고 A 재설치 | 옛 이름의 `project.json` 없음, 새 이름의 `path` 는 A |
| UT-10 | 소스 리포 거부 | 소스 트리 복제본 두 개를 같은 이름으로 설치 | 두 번째가 종료 코드 2, 옛 사본 걷어내기·렌더 없음 |

## T2 · feat: doctor 에 등록 상태 절과 UI 문구 추가

### 상위 Requirement

- relates to #79

### 작업 내용

`harness doctor` 가 이 리포가 등록부에 어떻게 등록돼 있는지 `registry` 절로 보고하고, UI Doctor 가 그 줄을 한국어 항목으로 옮기게 한다.

- 명세 3절(`harness doctor`) · 4절(UI Doctor 문구) · 6-1 의 doctor · doctor — worktree 케이스 · 6-3(`doctor.test.js`)
- `cmd_doctor`: `tools and connections` 절과 `git` 절 사이에 `registry` 절. 명세 3절 표의 네 상태를 `ok` 두 가지와 `warn` 두 가지로 낸다.
  등록부를 바꾸지 않고, 이 절은 `FAIL` 을 내지 않는다
- 같은 리포의 worktree 판정: 두 경로 각각에서 `git rev-parse --git-common-dir` 을 그 경로 기준 절대 경로로 푼 값과 `git rev-parse --show-prefix`
  가 모두 같으면 `ok`. 어느 쪽이든 git 실행이 실패하거나 값을 구하지 못하면 다른 경로 `warn`
- `src/ui/lib/doctor.js`: `SECTIONS` 에 `registry: "등록"`, `explain()` 이 두 `warn` 줄을 명세 4절 표대로 옮긴다. 두 항목의 조치는 `cmd: "harness install"`
- `render-test.sh` 의 `UT-62` 블록에 doctor 케이스를 더한다. worktree 케이스는 등록된 리포에 `git worktree add` 로 만든 linked worktree 와,
  같은 리포의 다른 서브디렉터리에 같은 이름으로 둔 하네스 루트를 쓴다
- 건드릴 파일: `src/bin/harness`(`cmd_doctor`), `src/ui/lib/doctor.js`, `src/ui/lib/doctor.test.js`, `src/test/render-test.sh`

### 완료 조건

- [ ] doctor 출력의 `tools and connections` 절과 `git` 절 사이에 `registry` 절이 있다
- [ ] 등록된 리포와 그 리포의 linked worktree 에서 `registry` 절이 `ok` `registered as` 이고 `warn` 줄이 없다
- [ ] 등록이 다른 경로를 가리키면 `warn` 과 그 경로, 등록이 없으면 `warn` `this repository is not registered` 가 나온다
- [ ] 같은 리포의 다른 서브디렉터리에 같은 이름으로 둔 하네스 루트에서 `warn` 이 나온다
- [ ] `registry` 절이 어느 상태에서도 `FAIL` 줄을 내지 않고, doctor 가 등록부를 바꾸지 않는다
- [ ] UI `explain()` 이 두 `warn` 줄을 한국어 항목으로 옮기고 `SECTIONS.registry` 가 `"등록"` 이다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/79-reject-duplicate-project-name` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 등록된 리포 | 설치한 리포에서 doctor | `registry` 절에 `ok` `registered as` |
| UT-02 | 다른 경로 등록 | `path` 가 다른 리포를 가리키는 상태에서 doctor | `warn` 과 그 경로, `FAIL` 줄 없음 |
| UT-03 | 미등록 | `project.json` 이 없는 리포에서 doctor | `warn` `this repository is not registered`, `FAIL` 줄 없음 |
| UT-04 | linked worktree | 등록된 리포의 `git worktree add` 트리에서 doctor | `registry` 절 `ok`, `warn` 줄 없음 |
| UT-05 | 같은 리포의 다른 서브디렉터리 | 같은 이름의 하네스 루트를 같은 리포의 다른 서브디렉터리에 두고 doctor | `warn` |
| UT-06 | UI 다른 경로 항목 | `explain()` 에 `` `demo` is registered to another path `` 줄 | 제목·본문이 원문과 다르고, 본문에 detail 의 경로, `cmd` 는 `harness install` |
| UT-07 | UI 미등록 항목 | `explain()` 에 `this repository is not registered` 줄 | `cmd` 는 `harness install` |
| UT-08 | UI 절 이름 | `SECTIONS.registry` | `"등록"` |

## T3 · docs: README 에 한 기기 한 클론과 등록 넘겨받기 안내

### 상위 Requirement

- relates to #79

### 작업 내용

T1 이 바꾼 install 동작과 등록부 규칙을 사람용 설명에 적는다.

- 명세 5절(README)
- "시작하기" 의 `install` 설명: 한 기기에 같은 리포는 하나만 설치한다는 것, 같은 `project.name` 이 아직 쓰이는 다른 경로에 등록돼 있으면
  `install` 이 거부하고 다른 클론에서 `harness uninstall` 하거나 `project.name` 을 바꾼다는 것, 옛 경로에 그 프로젝트가 없으면 등록을
  넘겨받고 `~/.harness/<이름>/` 아래 기록이 이어진다는 것, 같은 리포의 병렬 작업은 `harness run --worktree` 라는 것
- "UI" 절: 등록부의 프로젝트 이름 하나는 경로 하나를 가리키고, 같은 리포의 병렬 작업은 두 번째 클론이 아니라 `harness run --worktree` 라는 것
- 건드릴 파일: `README.md`

### 완료 조건

- [ ] README "시작하기" 의 `install` 설명이 명세 5절 표의 사실을 담는다
- [ ] README "UI" 절이 이름 하나 경로 하나와 `harness run --worktree` 를 담는다
- [ ] 추가한 문장에 개인 홈 절대 경로가 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/79-reject-duplicate-project-name` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 문서 참조 | README 수정 뒤 `harness doctor` | README 가 가리키는 경로가 모두 있다는 `ok` 줄 |
| UT-02 | 반영 확인 | `README.md` | "시작하기" 와 "UI" 절에 명세 5절 사실이 있다 |

## T4 · docs: 아키텍처 문서에 설치 등록부의 이름 하나 경로 하나 반영

### 상위 Requirement

- relates to #79

### 작업 내용

T1 로 생긴 등록부 규칙을 에이전트가 근거로 읽는 문서에 적는다.

**보호 문서를 수정하는 task 다.** `.ai/project/architecture.md` 는 보호 문서이므로 사용자가 명시적으로 지시한 턴에서 고친다
(`.ai/AI_AGENT.md` 금지 사항). 권한 설정·가드에 걸리면 사람이 대응한다.

- 명세 7절(보호 문서에 반영할 것)
- `.ai/project/architecture.md` "구성 요소" 의 기기 단위 상태: 설치 등록부는 프로젝트 이름 하나에 경로 하나이고, `install` 이 아직 쓰이는
  다른 경로의 같은 이름을 거부한다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/architecture.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] `.ai/project/architecture.md` 의 기기 단위 상태 항목이 명세 7절의 사실을 담는다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 5장이 그 문서와 일치한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/79-reject-duplicate-project-name` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 반영 확인 | `.ai/AI_AGENT.md` | 5장 구성 요소의 기기 단위 상태에 이름 하나 경로 하나와 install 거부가 있다 |
