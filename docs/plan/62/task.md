# #62 task

## T1 · feat: 표준 입력의 본문을 프로젝트 문서·메모에 쓰고 render 하는 write-doc 명령 추가

### 상위 Requirement

- relates to #62

### 작업 내용

UI 가 파일을 직접 쓰지 않도록, 프로젝트 문서와 역할·절차 메모를 쓰고 render 하는 `harness write-doc <이름> -` 을 만든다.

- 명세 2절(`write-doc`) · 9-1 의 write-doc 케이스
- 이름 목록: 하네스 원형 `templates/owned/.ai/project/*.md` 의 문서 이름, 설정 `roles` 의 `roles/<역할>`, 설정 `workflows`(기본 절차 포함)의
  `workflows/<절차>`. 이름을 이 목록과 문자열로 비교하고 맞는 항목의 경로를 쓴다. `commands` 와 목록 밖 이름은 거절한다
- 두 번째 인수는 `-` 만 받는다
- 쓰기 순서는 명세 2-2 그대로다 — 설정 검증 → 표준 입력 UTF-8 → 메모 머리 주석(공백이 아니고 `<!--` 로 시작하지 않을 때) →
  끝 줄바꿈 → 상위 디렉터리 생성과 쓰기(이전 내용 기억) → render → 실패 시 되돌림과 `reverted — the document is unchanged`, 종료 코드 2
- 역할·절차 머리 주석 문구는 지금 UI 의 `NOTES_HEAD` · `WF_HEAD` 가 붙이는 것과 같다(명세 2-2 원문)
- 성공 출력 `write-doc: <쓴 경로>` 와 render 출력, 모르는 이름의 `help:` 에 받는 이름 목록
- `COMMANDS` 에 `write-doc`(`<name> -`) 등록, `DELEGATES` 에 추가
- `render-test.sh` 에 새 `UT-<번호>` 블록을 만들고 write-doc 케이스를 넣는다. T3 · T4 · T5 · T2 가 같은 블록에 케이스를 더한다
- 건드릴 파일: `src/bin/harness`(`cmd_write_doc` · `COMMANDS` · `DELEGATES`), `src/test/render-test.sh`

### 완료 조건

- [ ] `printf 'x' | harness write-doc stack -` 가 종료 코드 0 이고 `.ai/project/stack.md` 가 `x\n`, `.ai/AI_AGENT.md` 가 그 본문을 담으며 이어진 `harness check` 가 통과한다
- [ ] `roles/developer` 로 쓰면 `.ai/project/roles/` 가 없던 리포에도 파일이 생기고 역할 머리 주석이 붙으며 `.claude/agents/developer.md` 가 본문을 담는다
- [ ] `<!--` 로 시작하는 메모 본문에는 머리 주석을 붙이지 않고, 공백뿐인 본문은 줄바꿈 한 개로 쓴다
- [ ] `workflows/work` 로 쓰면 절차 머리 주석이 붙고 `.ai/workflows/work.md` 가 본문을 담는다
- [ ] 거절 대상 호출이 종료 코드 2 이고 어떤 파일도 생기거나 바뀌지 않는다. 모르는 이름의 `help:` 에 받는 이름 목록이 있다
- [ ] render 가 실패하면 종료 코드 2, 표준 오류에 `reverted`, 문서가 쓰기 전 본문이고 없던 메모 파일은 남지 않는다
- [ ] 고정 사본이 있는 리포에서 전역 CLI 로 부르면 고정 사본이 답한다
- [ ] 터미널 출력에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/62-unify-ui-writes-through-cli` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 문서 쓰기 | `printf 'x' \| harness write-doc stack -` | 종료 코드 0, `stack.md` 가 `x\n`, `.ai/AI_AGENT.md` 반영, `harness check` 통과 |
| UT-02 | 역할 메모 | `roles/developer` 에 일반 본문 · `<!--` 본문 · 공백 본문 | 머리 주석 붙음 · 붙지 않음 · 줄바꿈 한 개. `.claude/agents/developer.md` 반영 |
| UT-03 | 절차 메모 | `workflows/work` 에 일반 본문 | 절차 머리 주석, `.ai/workflows/work.md` 반영 |
| UT-04 | 거절 | `commands` · `../x` · `stack.md` · `roles/없는역할` · `workflows/없는절차` · 두 번째 인수 `x` | 각각 종료 코드 2, 파일 변화 없음, 모르는 이름 안내에 이름 목록 |
| UT-05 | 렌더 실패 되돌림 | 생성 파일 자리에 디렉터리를 두고 문서·새 메모 쓰기 | 종료 코드 2, 표준 오류 `reverted`, 문서 원래 본문, 새 메모 파일 없음 |
| UT-06 | 위임 | 고정 사본 리포에서 전역 CLI 로 호출 | 고정 사본이 답한다 |

## T2 · feat: write-doc 으로 보호 문서를 쓰는 호출을 명령 가드와 권한 deny 로 차단

### 상위 Requirement

- relates to #62

### 작업 내용

에이전트가 `harness write-doc` 으로 보호 문서·역할 메모·절차 메모를 고치는 길을 셸 편집과 같은 층(명령 가드 · 권한 deny)에서 막는다.

- 명세 6절 · 9-1 의 deny 케이스 · 9-2
- `_guards.sh` 에 `guard_write_doc`: `invocations_at harness` 로 명령 자리의 호출만 보고, 옵션(`--target` · `--rename` · `--since` · `--trace` 는 값까지,
  `--target=<값>` 과 그 밖의 `-` 토큰은 그 토큰만)을 걷어 첫 위치 인수가 `write-doc` 이면 다음 위치 인수를 이름으로 본다.
  `.ai/project/<이름>.md` 가 `^(<PROTECTED_DOCS_RE>)` 에 맞으면 명세 6-1 의 영어 안내로 막는다. 이름이 셸 확장을 담거나 없으면 통과
- `bash-guard.sh` 가 `guard_arch_docs` 다음에 부르고, 사용 기록 라벨은 `arch-doc`
- `deny_rules()` 가 `docs.protected` 항목마다 명세 6-2 표대로 `Bash(<H> write-doc …:*)` 를 세 호출 형태(`harness` · `.harness/bin/harness` ·
  `src/bin/harness`)마다 만든다. 기존 `Edit(...)` 규칙은 그대로 둔다
- `test-bash-guard.sh` 에 차단·통과 케이스. 보호 이름은 `PROTECTED_DOCS_SAMPLE` 에서, 보호되지 않은 이름은 `stack` · `environment` · `review-checks`
  중 `PROTECTED_DOCS_RE` 에 걸리지 않는 첫 이름에서 얻는다. 새 차단 케이스를 가드를 망가뜨린 사본 검사에도 넣는다
- `render-test.sh` 의 T1 블록에 deny 케이스를 더한다
- 이 리포의 `script/` 사본과 `.claude/settings.json` 은 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `src/templates/managed/script/hooks/_guards.sh` · `bash-guard.sh` · `test-bash-guard.sh`, `src/bin/harness`(`deny_rules()`),
  `src/test/render-test.sh`, render 로 갱신되는 `script/` · `.claude/settings.json`

### 완료 조건

- [ ] 명세 9-2 표의 차단 명령이 모두 막히고 통과 명령이 모두 통과한다
- [ ] `guard_write_doc` 을 무력화한 사본에서 새 차단 케이스만 통과로 뒤집히고 나머지 계열은 차단 그대로다
- [ ] 차단 안내가 영어이고 명세 6-1 의 세 줄이다
- [ ] 기본 설정의 `.claude/settings.json` deny 에 세 호출 형태마다 `write-doc scope:*` · `write-doc roles/:*` · `write-doc workflows/:*` 가 있고 `write-doc stack:*` 가 없다
- [ ] `docs.protected` 에 `.ai/project/stack.md` 를 더하면 `write-doc stack:*` 가 생기고, `.ai/project/` 밖 경로를 더하면 `write-doc` 규칙이 늘지 않는다
- [ ] 기존 `Edit(...)` deny 규칙이 그대로다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/62-unify-ui-writes-through-cli` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 호출 형태별 차단 | `harness` · `.harness/bin/harness` · `src/bin/harness` · `./src/bin/harness` 로 `write-doc <보호> -` | 모두 차단 |
| UT-02 | 옵션 위치 | `harness --target . write-doc <보호> -` · `harness write-doc --target . <보호> -` | 둘 다 차단 |
| UT-03 | 메모 | `harness write-doc roles/<역할> -` · `harness write-doc workflows/work -` | 둘 다 차단 |
| UT-04 | 명령 연결 | `cd x && harness write-doc <보호> -` · `printf x \| harness write-doc <보호> -` | 둘 다 차단 |
| UT-05 | 통과 | `harness write-doc <보호되지 않은> -` · `harness schema` · `harness render` · `echo harness write-doc <보호>` · `grep write-doc README.md` | 모두 통과 |
| UT-06 | 망가뜨린 가드 | `guard_write_doc` 무력화 사본 | UT-01~04 만 통과로 뒤집힌다 |
| UT-07 | 기본 deny | 기본 설정 render 뒤 `.claude/settings.json` | 세 형태 × `scope` · `roles/` · `workflows/` 규칙 있음, `stack` 없음 |
| UT-08 | 설정 변경 deny | `docs.protected` 에 `stack.md` · `.ai/project/` 밖 경로 추가 | `write-doc stack:*` 생김, 밖 경로로는 규칙 증가 없음 |

## T3 · feat: Doctor 조치를 명령으로 돌리는 fix hooks·verify 추가

### 상위 Requirement

- relates to #62

### 작업 내용

UI Doctor 의 ▷ 조치 가운데 CLI 명령이 없던 둘을 `harness fix <조치>` 로 둔다.

- 명세 3절 · 9-1 의 fix 케이스
- `fix hooks`: #60 이 install 에 넣은 훅 경로(`core.hooksPath`) 설정 로직을 그대로 부른다. 모노레포 접두와 기존 `.git/hooks` 훅이 있을 때
  설정하지 않는 판정도 그 로직의 것이다. 설정함 · 이미 맞음은 종료 코드 0, 설정하지 않음은 이유를 내고 종료 코드 2. 따로 판정하지 않는다
- `fix verify`: 하네스 루트에서 `bash` 로 검증 스크립트를 돌리고 표준 출력·오류를 그대로 흘린다. 채운 옛 검증 스크립트(`legacy_verify`)가 있으면
  `script/verify-project.sh`, 아니면 `script/harness-verify.sh`. 이 판정은 T5 의 `verify_script` 와 같은 함수로 둔다. 종료 코드는 스크립트의 것
- 그 밖의 조치나 빠진 인수는 사용법과 종료 코드 2
- `COMMANDS` 와 `DELEGATES` 에 `fix` 추가
- `render-test.sh` 의 T1 블록에 fix 케이스를 더한다
- 건드릴 파일: `src/bin/harness`(`cmd_fix` · `COMMANDS` · `DELEGATES`, 검증 스크립트 판정 함수), `src/test/render-test.sh`

### 완료 조건

- [ ] 훅 경로를 설정하는 코드가 install 의 것 하나뿐이고 `fix hooks` 가 그것을 부른다
- [ ] 훅 경로가 빈 리포에서 `fix hooks` 가 설정하고 종료 코드 0, install 이 설정하지 않는 조건에서는 설정하지 않고 종료 코드 2
- [ ] 명령을 정한 리포에서 `fix verify` 가 종료 코드 0, 실패하는 명령을 둔 리포에서 0 이 아니다
- [ ] 채운 `script/verify-project.sh` 가 있으면 `fix verify` 가 그것을 돌린다
- [ ] 모르는 조치와 빠진 인수가 종료 코드 2 다
- [ ] 터미널 출력에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/62-unify-ui-writes-through-cli` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 검증 통과 | 통과하는 명령을 정한 리포에서 `harness fix verify` | 종료 코드 0 |
| UT-02 | 검증 실패 | 실패하는 명령을 둔 리포에서 `harness fix verify` | 종료 코드 0 이 아님 |
| UT-03 | 옛 검증 스크립트 | 채운 `script/verify-project.sh` 를 둔 리포 | 그 스크립트가 돈다 |
| UT-04 | 훅 설정 | `core.hooksPath` 가 빈 리포에서 `harness fix hooks` | 설정되고 종료 코드 0 |
| UT-05 | 훅 설정 안 함 | install 이 설정하지 않는 조건(기존 `.git/hooks` 훅) | 설정 값 그대로, 종료 코드 2 |
| UT-06 | 모르는 조치 | `harness fix x` · `harness fix` | 종료 코드 2 |

## T4 · feat: install 에 대상 디렉터리 생성과 git 시작 옵션 추가

### 상위 Requirement

- relates to #62

### 작업 내용

UI 의 새 프로젝트 만들기가 CLI 한 번으로 끝나도록 `harness install` 에 `--create` · `--git-init` 을 더한다.

- 명세 4절 · 9-1 의 install 케이스
- `--create`: `--target` 이 없으면 상위까지 만든다. 없는 경로에 `--create` 가 없으면 `error: target directory does not exist` 와 `--create` 를 쓰라는
  `help:`, 종료 코드 2, 아무것도 만들지 않는다
- `--git-init`: `.git` 이 없을 때만 그 디렉터리에서 `git init -q`. `--create` 없이도 받는다
- 순서: 등록 판정 → 디렉터리 생성 → `git init` → 기본 설정 깔기 → 기존 install. 판정 이름은 대상에 `harness.toml` 이 있으면 그 `project.name`,
  없으면 새로 깔 때 채울 이름(디렉터리 이름). 판정부터 등록까지 기존 등록부 잠금 안의 한 구역이다
- 거부면 디렉터리 · `.git` · `harness.toml` 을 만들지 않고 기존 거부 안내문과 종료 코드 2
- `COMMANDS` 의 install 인수 표기에 두 옵션을 더한다. `DELEGATES` 는 바꾸지 않는다
- `render-test.sh` 의 T1 블록에 install 케이스를 더한다
- 건드릴 파일: `src/bin/harness`(`cmd_install` · 인수 해석 · `COMMANDS`), `src/test/render-test.sh`

### 완료 조건

- [ ] 없는 경로에 `--create --git-init` 이면 디렉터리 · `.git` · `harness.toml` 이 생기고 등록부에 그 경로가 등록된다
- [ ] `--create` 없이 없는 경로면 종료 코드 2 이고 경로가 생기지 않는다
- [ ] 같은 이름이 다른 경로에 살아 있을 때 `--create` 로 새 경로를 주면 종료 코드 2, 경로가 생기지 않고 등록부가 그대로다
- [ ] `.git` 이 있는 디렉터리에 `--git-init` 이면 `git init` 을 돌지 않고 기존 커밋이 그대로다
- [ ] 판정과 등록이 기존 등록부 잠금 안에서 돈다
- [ ] 터미널 출력에 한글이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/62-unify-ui-writes-through-cli` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 새 디렉터리 | 없는 경로에 `install --create --git-init --target <경로>` | 디렉터리 · `.git` · `harness.toml` 생성, 등록부 등록 |
| UT-02 | `--create` 없음 | 없는 경로에 `install --target <경로>` | 종료 코드 2, 경로 없음 |
| UT-03 | 이름 거부 | 같은 이름이 살아 있는 상태에서 새 경로에 `--create` | 종료 코드 2, 경로 없음, 등록부 그대로 |
| UT-04 | 기존 `.git` | 커밋이 있는 리포에 `--git-init` | 기존 커밋 그대로 |

## T5 · feat: schema 에 문서·절차·검증·훅 경로와 설정 주석·기본 보호 목록 키 추가

### 상위 Requirement

- relates to #62

### 작업 내용

UI 가 경로와 판정 값을 짓지 않도록 `harness schema` 가 그것을 낸다. 기존 키는 그대로 두고 새 키를 더한다.

- 명세 5절 · 5-1 · 9-1 의 schema 케이스
- `docs`: T1 의 문서 이름 목록과 같은 키. 값은 `path`(`.ai/project/<문서>.md`)와 `template`(그 명령을 답한 하네스의 원형 — 고정 사본이면
  `.harness/templates/owned/...`, 소스 리포면 `src/templates/owned/...`, 하네스 루트 밖이면 절대 경로). `commands` 는 없다
- `workflows.<절차>.path`: 생성된 절차 문서 `.ai/workflows/<절차>.md`
- `verify_script`: T3 의 `fix verify` 와 같은 판정 함수의 값
- `hooks_path`: #60 의 훅 경로 설정 로직이 `core.hooksPath` 에 넣는 값(모노레포 접두 포함)
- `config_notes`: 대상 `harness.toml` 의 키 바로 위 주석을 명세 5-1 규칙으로 읽는다
- `base_protected`: `BASE_PROTECTED` 그대로, 같은 순서
- 문서 목록에 제목·안내문·질문 양식을 싣지 않는다
- `render-test.sh` 의 T1 블록에 schema 케이스를 더한다
- 건드릴 파일: `src/bin/harness`(`cmd_schema`, 설정 주석 읽기 함수), `src/test/render-test.sh`

### 완료 조건

- [ ] `docs` 키가 원형 `.ai/project/*.md` 목록과 같고 `commands` 가 없으며, 각 `path` 가 `.ai/project/<문서>.md` 이고 `template` 이 가리키는 파일이 있다 — 고정 사본 리포와 소스 트리 복제본 둘 다
- [ ] `workflows.<절차>.path` 가 있는 파일을 가리킨다
- [ ] `verify_script` 가 옛 검증 스크립트 유무에 따라 바뀌고 `fix verify` 가 돌리는 스크립트와 같다
- [ ] `hooks_path` 가 install 이 설정하는 값과 같다
- [ ] `config_notes` 가 주석을 단 키의 주석을 담고, `─` 구분선 줄이 빠지며, 빈 줄로 떨어진 주석은 붙지 않고, 점이 든 절의 키가 `roles.developer.runner` 꼴이다
- [ ] `base_protected` 가 `BASE_PROTECTED` 와 같고 `.ai/project/workflows/` 를 담으며 `docs.protected` 를 비운 설정에서도 같다
- [ ] 기존 schema 키가 그대로다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/62-unify-ui-writes-through-cli` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 문서 목록 | 고정 사본 리포 · 소스 트리 복제본에서 `harness schema` | `docs` 키가 원형 목록과 같고 `commands` 없음, `path` · `template` 이 성립 |
| UT-02 | 절차 경로 | `harness schema` | `workflows.<절차>.path` 가 있는 파일 |
| UT-03 | 검증 스크립트 | 옛 검증 스크립트 있음 · 없음 | `verify_script` 가 `script/verify-project.sh` · `script/harness-verify.sh` |
| UT-04 | 훅 경로 | 루트 리포 · 모노레포 서브프로젝트 | `hooks_path` 가 install 이 설정하는 값 |
| UT-05 | 설정 주석 | 주석 · 구분선 · 빈 줄 · 점 절이 든 `harness.toml` | 명세 5-1 규칙대로 값이 나온다 |
| UT-06 | 기준 보호 목록 | 기본 설정 · `docs.protected` 를 비운 설정 | 둘 다 `BASE_PROTECTED` 와 같다 |

## T6 · refactor: UI 의 문서·메모 저장과 읽기 경로를 write-doc 과 schema 로 전환

### 상위 Requirement

- relates to #62

### 작업 내용

UI 의 문서·역할 메모·절차 메모 저장을 `harness write-doc` 으로 바꾸고, 문서·원형·절차 문서·설정 주석 읽기를 schema 의 값으로 바꾼다.

- 명세 7-1 · 7-2(`saveDoc` · `saveRoleNotes` · `saveWorkflowNotes` · `completeDoc`) · 7-3(문서·메모 부분) · 7-4(`DocEditor` · `FlowCanvas` · `CommandsEditor`) · 7-6
- `harness.js`: `harness(dir, args, { input })` 가 표준 입력을 넘긴다. `readDoc` · `readDocTemplate` · `listWorkflows` 가 schema 를 받아 그 경로를 읽는다.
  `docPath` · `writeDoc` · `writeRoleNotes` · `readConfigNotes` 를 지우고, `fields.js` 의 `DOCS` 를 import 하지 않는다
- `actions.js`: 세 저장 액션이 `write-doc` 한 번을 부르고 별도 render 호출 · `NOTES_HEAD` · `WF_HEAD` · 역할·절차 존재 확인용 schema 조회를 지운다.
  CLI 의 거절을 그대로 돌려준다. `completeDoc` 은 새 읽기 함수와 `schema.docs[doc].path` 를 쓴다
- 설정 주석이 필요한 곳은 `schema.config_notes` 를 쓴다
- `fields.js` 의 `DOCS` 는 탭 구성·제목·안내·질문 양식만 갖는다. `commands` 밖의 탭 키가 `schema.docs` 에 없으면 재설치 안내를 보인다
- 옛 사본(schema 에 `docs` 없음): 문서 탭 · Agents 메모 · Workflows 절차 메모가 편집·저장 대신 `harness install` 재설치 안내를 보인다
- 화면 경로: `DocEditor` 는 `schema.docs[doc].path`, `FlowCanvas` 는 `schema.workflows.<절차>.path` 와 삭제 확인의 `schema.workflow_notes.<절차>`,
  `CommandsEditor` 의 옛 검증 스크립트 안내는 `schema.verify_script`
- 건드릴 파일: `src/ui/lib/harness.js`, `src/ui/lib/actions.js`, `src/ui/lib/fields.js`, 이 함수들을 부르는 `src/ui/app/[project]/` 화면과
  `src/ui/components/`(`DocEditor` · `FlowCanvas` · `CommandsEditor` 와 메모 편집 컴포넌트)

### 완료 조건

- [ ] `src/ui/lib/harness.js` 와 `actions.js` 의 문서·메모 경로에 `fs.writeFile` · `fs.mkdir` 이 없다
- [ ] `src/ui/` 에 `.ai/project/` · `.ai/workflows/` · `templates/owned` 경로를 조립하는 코드가 없다
- [ ] Project Settings 문서 저장, Agents 메모 저장, Workflows 절차 메모 저장의 결과 파일과 render 결과가 전환 전과 같다
- [ ] 소스 리포에서 문서 원형이 빈 값이 아니다
- [ ] 목록 밖 문서·역할·절차 이름을 저장하면 CLI 의 거절 안내가 그대로 보인다
- [ ] schema 에 `docs` 가 없는 사본에서 세 화면이 재설치 안내를 보이고 저장하지 않는다
- [ ] 문서 탭 목록이 전환 전과 같다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/62-unify-ui-writes-through-cli` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 문서 저장 | UI 에서 `stack` 문서 저장 | `.ai/project/stack.md` · `.ai/AI_AGENT.md` 가 전환 전 저장과 같다 (손 확인) |
| UT-02 | 메모 저장 | Agents 역할 메모 · Workflows 절차 메모 저장 | 머리 주석과 생성물이 전환 전과 같다 (손 확인) |
| UT-03 | 소스 리포 원형 | 소스 리포 프로젝트의 문서 완성 요청 | 원형이 채워진 채 읽힌다 (손 확인) |
| UT-04 | 옛 사본 | schema 에 `docs` 가 없는 고정 사본 프로젝트 | 세 화면에 재설치 안내, 저장 없음 (손 확인) |
| UT-05 | 경로 조립 없음 | `src/ui/` 소스 검색 | `.ai/project/` · `.ai/workflows/` · `templates/owned` 조립 코드 없음 |

## T7 · refactor: UI Doctor 조치를 fix 명령과 항목 네 키 매핑으로 전환

### 상위 Requirement

- relates to #62

### 작업 내용

Doctor 의 ▷ 조치가 `git` · `bash` 를 직접 돌리지 않고 CLI 를 부르게 하고, 조치 종류를 doctor 항목의 네 키로 고르게 한다.

- 명세 7-2(`doctorFix`) · 7-3(Doctor 부분) · 7-4(`doctor.js` 행) · 7-5 · 9-3
- `doctorFix(project, kind)`: `hooks` → `harness fix hooks`, `verify` → `harness fix verify`, `render` → `harness render`, `upgrade` → `harness install`.
  그 밖은 거절. `git` · `bash` 직접 실행 내부 함수와 `legacyVerify` 를 지운다
- `explain(i, base, schema)`: 명세 7-5 표로 `section` · `what` · `state` · `detail` 에서 조치 종류를 고른다. `section` 까지 맞아야 고른다.
  보일 명령은 `verify` → `bash <schema.verify_script>`, `hooks` → `git config core.hooksPath <schema.hooks_path>`, `render` → `harness render`.
  schema 가 없으면 `verify` · `hooks` 의 보일 명령을 비운다. 표에 없는 항목의 안내(`href` · `cmd`)는 지금 그대로다
- `upgrade` 는 지금처럼 `DoctorView` 가 목록 앞에 더하는 UI 항목이 싣는다
- `DoctorView` 가 schema 를 `explain()` 에 넘기고, schema 에 `docs` 가 없는 사본에서는 `hooks` · `verify` ▷ 대신 재설치 안내를 보인다
- 건드릴 파일: `src/ui/lib/actions.js`, `src/ui/lib/doctor.js`, `src/ui/lib/doctor.test.js`, `src/ui/components/DoctorView.js`, Doctor 화면

### 완료 조건

- [ ] `actions.js` 에 `git` · `bash` 직접 실행과 `legacyVerify` 가 없다
- [ ] 명세 7-5 표의 행마다 네 키 항목 하나를 주면 `explain()` 이 그 조치 종류를 고르고, 같은 `what` 을 다른 `section` 으로 주면 조치가 없다
- [ ] `script/harness-verify.sh` 의 `detail` 이 `not set up — no commands yet` 이면 조치가 없고 명령 탭 링크가 있다
- [ ] schema 를 주면 `verify` · `hooks` 의 보일 명령이 `bash <verify_script>` · `git config core.hooksPath <hooks_path>` 이고, 모노레포 접두가 그대로 들어간다
- [ ] schema 를 주지 않으면 조치 종류는 남고 보일 명령이 비어 있다
- [ ] 테스트 입력에 네 키 밖의 키가 없다
- [ ] 옛 사본에서 `hooks` · `verify` ▷ 대신 재설치 안내가 보이고 `render` · `upgrade` 는 그대로 돈다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/62-unify-ui-writes-through-cli` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 조치 고르기 | 7-5 표 행마다 `{section, state, what, detail}` 항목 | 표의 조치 종류 |
| UT-02 | 절 불일치 | 같은 `what` 을 다른 `section` 으로 | 조치 없음 |
| UT-03 | 명령 미설정 | `verification` · `script/harness-verify.sh` · `detail` `not set up — no commands yet` | 조치 없음, 명령 탭 링크 |
| UT-04 | 보일 명령 | schema(`verify_script` · 모노레포 접두 `hooks_path`) 전달 | `bash <verify_script>` · `git config core.hooksPath <hooks_path>` |
| UT-05 | schema 없음 | schema 없이 `verify` · `hooks` 항목 | 조치 종류 있음, 보일 명령 비어 있음 |
| UT-06 | 옛 사본 조치 | schema 에 `docs` 없는 프로젝트의 Doctor | `hooks` · `verify` 에 재설치 안내 (손 확인) |

## T8 · refactor: UI 새 프로젝트 만들기를 install --create 로 전환

### 상위 Requirement

- relates to #62

### 작업 내용

새 프로젝트 만들기가 디렉터리 생성과 `git init` 을 직접 하지 않고 `harness install --create [--git-init]` 한 번을 부르게 한다.

- 명세 7-2(`createProject`)
- `createProject(dir, gitInit)`: `harness install --create [--git-init] --target <dir>`. `fs.mkdir` · `git init` 직접 실행과 같은 이름 사전 검사를 지우고,
  거부는 CLI 안내문을 그대로 돌려준다
- 입력 좁히기(절대 경로 · `.`/`..` 없음 · 홈 디렉터리 안쪽 · 등록부 밖)는 그대로 둔다
- 건드릴 파일: `src/ui/lib/actions.js`, 필요하면 `src/ui/components/NewProject.js`

### 완료 조건

- [ ] `createProject` 에 `fs.mkdir` · `git init` 직접 실행과 같은 이름 사전 검사가 없다
- [ ] 없는 경로로 만들기(git 시작 켬)가 디렉터리 · `.git` · `harness.toml` 과 등록을 남긴다
- [ ] 같은 이름이 다른 경로에 살아 있으면 CLI 거부 안내문이 그대로 보이고 경로가 생기지 않는다
- [ ] 입력 좁히기가 전환 전과 같은 입력을 거절한다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/62-unify-ui-writes-through-cli` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 새 프로젝트 | 홈 안쪽의 없는 경로, git 시작 켬 | 디렉터리 · `.git` · `harness.toml` · 등록 (손 확인) |
| UT-02 | 이름 거부 | 살아 있는 같은 이름의 새 경로 | CLI 거부 안내 그대로, 경로 없음 (손 확인) |
| UT-03 | 입력 좁히기 | 상대 경로 · `..` 포함 · 홈 밖 · 등록된 경로 | 전환 전과 같이 거절 (손 확인) |

## T9 · refactor: UI 보호 문서 목록을 schema 의 기준 목록으로 전환

### 상위 Requirement

- relates to #62

### 작업 내용

Harness 화면의 보호 문서 목록이 UI 에 복제된 `BASE_PROTECTED` 대신 `schema.base_protected` 를 쓰게 한다.

- 명세 7-3(보호 목록 부분) · 7-7 · 9-4
- `paths.js`: `BASE_PROTECTED` 상수를 지우고 순수 함수 `ownPaths(value, base)`(순서 유지, `base` 에 있는 항목만 뺀다)를 둔다
- `settings/page.js` 가 `schema.base_protected` 를 `ValueField` 를 거쳐 `PathList` 에 넘긴다. `PathList` 는 schema 를 직접 읽지 않는다
- `PathList`: 받은 목록을 고정 행, `ownPaths` 결과를 편집 행으로 보이고, 추가 검사와 저장 값은 받은 목록과 편집 행을 합친 것
- schema 에 `docs` 가 없으면 재설치 안내를 보이고 저장하지 않는다
- `pathProblem` · `dirProblem` 은 추가 전 미리 보이는 검사로 남는다
- 건드릴 파일: `src/ui/lib/paths.js`, `src/ui/lib/paths.test.js`, `src/ui/components/PathList.js`, `src/ui/components/ValueField.js`, `src/ui/app/[project]/settings/page.js`

### 완료 조건

- [ ] `src/ui/` 에 `BASE_PROTECTED` 상수가 없다
- [ ] 고정 행이 `schema.base_protected` 와 같고 `.ai/project/workflows/` 를 담는다
- [ ] 저장 값이 기준 목록과 편집 행을 합친 것이다
- [ ] schema 에 `docs` 가 없는 사본에서 재설치 안내가 보이고 저장하지 않는다
- [ ] UI 단위 테스트와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/62-unify-ui-writes-through-cli` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 기준 목록 빼기 | `ownPaths([기준 항목과 자기 항목이 섞인 값], base)` | 자기 항목만, 원래 순서 |
| UT-02 | 빈 기준 목록 | `ownPaths(value, [])` | `value` 그대로 |
| UT-03 | 기존 검사 | 기존 `pathProblem` · `dirProblem` 케이스 | 그대로 통과 |
| UT-04 | 화면 | Harness 화면의 보호 문서 목록 | 고정 행이 schema 값, 저장 값이 합친 목록 (손 확인) |

## T10 · docs: README 에 write-doc·fix·install 옵션과 UI 쓰기 경로 반영

### 상위 Requirement

- relates to #62

### 작업 내용

T1–T9 가 만든 명령과 UI 쓰기 경로를 사람용 설명에 적는다.

- 명세 8절
- "명령" 표: `harness write-doc <이름> -`(UI 가 쓰는 명령, 에이전트가 보호 문서를 대상으로 부르면 가드가 막는다), `harness fix hooks|verify`,
  `harness install` 행의 `--create` · `--git-init`, `harness schema` 행의 새 키
- "UI" 표의 쓰기 경로와 "UI" 본문: UI 는 파일을 직접 쓰지 않고, 고정 사본이 새 명령을 모르면 재설치를 안내한다
- 건드릴 파일: `README.md`

### 완료 조건

- [ ] README "명령" 표와 "UI" 표·본문이 명세 8절 표의 사실을 담는다
- [ ] 추가한 문장에 개인 홈 절대 경로가 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/62-unify-ui-writes-through-cli` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 문서 참조 | README 수정 뒤 `harness doctor` | README 가 가리키는 경로가 모두 있다는 `ok` 줄 |
| UT-02 | 반영 확인 | `README.md` | "명령" · "UI" 절에 명세 8절 사실이 있다 |

## T11 · docs: 담당 범위·아키텍처 문서에 UI 쓰기의 CLI 일원화 반영

### 상위 Requirement

- relates to #62

### 작업 내용

T1–T9 로 바뀐 사실을 에이전트가 근거로 읽는 문서에 적는다.

**보호 문서를 수정하는 task 다.** `.ai/project/scope.md` · `.ai/project/architecture.md` 는 보호 문서이므로 사용자가 명시적으로 지시한 턴에서 고친다
(`.ai/AI_AGENT.md` 금지 사항). 권한 설정·가드에 걸리면 사람이 대응한다.

- 명세 10절
- `scope.md` "할 수 있는 일": 프로젝트 문서와 역할·절차 메모를 CLI 로 쓰고 생성물을 따라 바꾼다(`write-doc`), Doctor 조치를 CLI 로 돈다(`fix`)
- `architecture.md` "구성 요소": `src/bin/harness` 명령 나열에 `write-doc` · `fix`, `src/ui/` 가 문서·메모 저장 · Doctor 조치 · 새 프로젝트 만들기도
  CLI 명령을 부르고 파일 경로를 `harness schema` 에서 받는다는 것
- `.ai/AI_AGENT.md` 는 생성 파일이다. 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/scope.md`, `.ai/project/architecture.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] 두 문서가 명세 10절 표의 사실을 담는다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 1장 · 5장이 두 문서와 일치한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `refactor/62-unify-ui-writes-through-cli` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 반영 확인 | `.ai/AI_AGENT.md` | 1장 할 수 있는 일과 5장 구성 요소에 `write-doc` · `fix` 와 UI 의 CLI 일원화가 있다 |
