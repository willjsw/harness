# #70 task

## T1 · feat: 관리 스크립트·forge 선언·git 명령으로 권한 허용 목록 생성

### 상위 Requirement

- relates to #70

### 작업 내용

`harness render` 가 `.claude/settings.json` 의 `permissions.allow` 를 관리 스크립트 · forge 선언 · git 명령 세 묶음으로 만들게 한다.
절차가 정상 경로에서 부르는 명령이 승인 대기 없이 돌게 하기 위함이다.

- 명세 1절 · 3절(관리 스크립트 묶음) · 4절(forge 명령 묶음) · 5절의 `git switch -c` · `git commit` · 6절(생성 형식) · 8절의 케이스 1 · 4
- `allow_rules(cfg)`: `src/templates/managed/script/` 바로 아래 정규 파일 중 확장자 `.sh` · `.py`, `_` 로 시작하지 않고 제외 목록에 없는 것을
  파일 이름 오름차순으로 `Bash(script/<이름>:*)` 로 낸다. 이어서 forge 규칙, 끝에 `Bash(git switch -c:*)` · `Bash(git commit:*)`
- 제외 목록 상수: `rollback-work.sh` · `create-carryover-issue.sh` · `forge-selftest.sh`. 이름이 관리 스크립트 디렉터리에 없으면
  `error: permission exclusion names a script that is not shipped: <이름>` 으로 거부
- `src/templates/forge/{github,gitlab,jira}/allow.toml`: 명세 4-1 의 머리 주석과 표의 항목. jira 는 `tracker` 키만 둔다
- forge 규칙: `forge.tracker` 의 파일에서 `tracker`, `forge.review_host` 의 파일에서 `review` 를 선언 순서대로 읽어 `Bash(<항목>:*)` 로 낸다.
  같은 규칙이 두 번 나오면 처음 것만 둔다. 파일 없음 · 키 없음 · 문자열 배열이 아님 · 항목 형식 위반 · 다른 키는 명세 4-2 의 메시지로 거부
- `settings_json()`: `permissions` 를 `{"allow": allow_rules(cfg), "deny": deny_rules(cfg)}` 로 바꾸고 주석을 명세 6절의 뜻으로 고친다.
  기존 `Bash(script/metric.py step:*)` 는 `Bash(script/metric.py:*)` 로 대체된다
- `render-test.sh` 에 새 `UT-75` 블록: 명세 8절 케이스 1(기본 설정, gitlab)과 4(`tracker = jira` · `review_host = github`), `allow.toml` 거부 케이스
- 이 리포의 `.claude/settings.json` 을 `harness render` 로 다시 만든다
- 건드릴 파일: `src/bin/harness`(`allow_rules()` · 제외 목록 상수 · `settings_json()`), `src/templates/forge/github/allow.toml`,
  `src/templates/forge/gitlab/allow.toml`, `src/templates/forge/jira/allow.toml`, `src/test/render-test.sh`, `.claude/settings.json`(생성물)

### 완료 조건

- [ ] 기본 설정 렌더의 `allow` · `deny` 가 둘 다 비어 있지 않다
- [ ] 설치된 `script/` 바로 아래의 `.sh` · `.py` 중 `_` 로 시작하지 않고 제외 목록에 없는 것이 전부 `Bash(script/<이름>:*)` 로 있다
- [ ] `rollback-work.sh` · `create-carryover-issue.sh` · `forge-selftest.sh` 규칙이 없고 `sync-task-issues.sh` 규칙이 있다
- [ ] `Bash(script/*` 글롭 규칙, `script/project/` 를 담은 규칙, `script/harness-verify.sh` 규칙이 없다
- [ ] `Bash(git switch -c:*)` · `Bash(git commit:*)` 가 있고 `Bash(git push:*)` 가 없다
- [ ] forge 규칙이 `forge.tracker` · `review_host` 를 따라가고, `issue create` 를 담은 규칙이 없다
- [ ] `allow.toml` 의 형식 위반과 제외 목록의 없는 이름이 render 를 0 이 아닌 종료 코드로 막고 명세의 메시지를 낸다
- [ ] 같은 설정으로 두 번 렌더한 `.claude/settings.json` 이 같다
- [ ] `deny` 가 이 변경 전과 같다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/70-generate-permission-allow-list` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 허용과 거부가 함께 생성 | `setup()` 설정(gitlab)으로 렌더 | `allow` · `deny` 모두 비어 있지 않음 |
| UT-02 | 관리 스크립트 전부 허용 | UT-01 의 산출물과 설치된 `script/` | 대상 스크립트마다 `Bash(script/<이름>:*)` 가 있음 |
| UT-03 | 되돌릴 수 없는 쓰기 스크립트 제외 | UT-01 의 산출물 | `rollback-work.sh` · `create-carryover-issue.sh` · `forge-selftest.sh` 규칙 없음, `sync-task-issues.sh` 규칙 있음 |
| UT-04 | 대상 밖 스크립트 제외 | UT-01 의 산출물 | `Bash(script/*` · `script/project/` · `script/harness-verify.sh` 규칙 없음 |
| UT-05 | 기본 git 묶음 | UT-01 의 산출물 | `Bash(git switch -c:*)` · `Bash(git commit:*)` 있음, `Bash(git push:*)` 없음 |
| UT-06 | forge 명령은 선언만 | UT-01 의 산출물 | `glab mr view` 규칙 있음, `gh ` 로 시작하는 규칙 없음, `issue create` 를 담은 규칙 없음 |
| UT-07 | forge 를 따라감 | `tracker = jira` · `review_host = github` 로 렌더 | `jira issue view` · `gh pr view` 규칙 있음, `glab` 규칙 없음, `gh api` 규칙은 답글 경로 하나 |
| UT-08 | 선언 파일 없음 | 설치본의 tracker forge `allow.toml` 삭제 뒤 렌더 | 0 이 아닌 종료 코드, `no permission list for this forge` |
| UT-09 | 선언 항목 형식 위반 | 항목에 `:*` 로 끝나는 값 · 괄호 · 빈 문자열 | 0 이 아닌 종료 코드, `is not a command prefix` |
| UT-10 | 선언 키 오류 | `tracker` 가 문자열 · 모르는 키 추가 | 0 이 아닌 종료 코드, `must be a list of command prefixes` · `unknown key(s)` |
| UT-11 | 순서 고정 | 같은 설정으로 두 번 렌더 | 두 `.claude/settings.json` 이 같음 |

## T2 · feat: `[permissions].allow_push` 설정과 `git push` 허용

### 상위 Requirement

- relates to #70

### 작업 내용

`[permissions]` 설정 절과 `allow_push` 키를 더해, 프로젝트가 `git push` 를 승인 없이 돌릴지 고르게 한다. 기본값 `false` 에서는 `git push` 가 승인 대상으로 남는다.

- 명세 2절(설정) · 5절의 `git push` · 8절의 케이스 2 · 3 · 5
- `src/templates/harness.toml`: `[docs]` 절 다음, `[usage]` 절 앞에 명세 2절의 주석과 `allow_push = false`
- `normalize()`: `[permissions]` 절이 없거나 키가 없으면 `allow_push = false` 를 채운다 (`[worktree]` 와 같은 자리)
- `validate()`: 모르는 키와 불리언이 아닌 값을 명세 2절의 메시지로 거부
- `set_line()`: `permissions.allow_push` 는 절이 없으면 파일 끝에 `[permissions]` 절을, 키가 없으면 그 절 끝에 `allow_push = <값>` 줄을 더한다
- `allow_rules()`: `allow_push` 가 참이면 git 묶음 끝에 `Bash(git push:*)`
- `render-test.sh` 의 `setup()` 이 `allow_push = false` 로 고정한다. `UT-75` 블록에 케이스 2 · 3 · 5 를 더한다
- `src/ui/lib/help.js` 에 `permissions.allow_push` 도움말 한 줄, `src/ui/app/[project]/settings/page.js` 의 `GROUPS` 에서 `permissions` 를 `scm` 묶음에 넣는다
- 건드릴 파일: `src/templates/harness.toml`, `src/bin/harness`(`normalize()` · `validate()` · `set_line()` · `allow_rules()`), `src/test/render-test.sh`,
  `src/ui/lib/help.js`, `src/ui/app/[project]/settings/page.js`

### 완료 조건

- [ ] `harness set permissions.allow_push true` 뒤 렌더한 `allow` 에 `Bash(git push:*)` 가 있다
- [ ] 그때의 `deny` 가 `allow_push = false` 일 때와 같고, 보호 브랜치마다의 push 규칙과 force push · `--no-verify` 규칙이 전부 있다
- [ ] `[permissions]` 절이 없는 설정이 렌더되고 `Bash(git push:*)` 가 없다
- [ ] 그 설정에서 `harness set permissions.allow_push true` 가 성공하고 `harness.toml` 에 `[permissions]` 절과 `allow_push = true` 가 생긴다
- [ ] `[permissions]` 의 모르는 키와 불리언이 아닌 `allow_push` 가 각각 render 를 0 이 아닌 종료 코드로 막고 명세 2절의 메시지를 낸다
- [ ] 배포 기본 설정이 그대로 렌더된다
- [ ] UI 설정 화면의 Source Control 묶음에 `permissions.allow_push` 가 도움말과 함께 보인다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/70-generate-permission-allow-list` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | push 허용 | `harness set permissions.allow_push true` 뒤 렌더 | `allow` 에 `Bash(git push:*)` 있음 |
| UT-02 | push 허용에도 deny 유지 | UT-01 과 `allow_push = false` 렌더의 `deny` 비교 | 같음. `main` · `development` push 규칙, force push · `--no-verify` 규칙 전부 있음 |
| UT-03 | 절이 없는 옛 설정 | `[permissions]` 절을 지운 설정으로 렌더 | 통과, `Bash(git push:*)` 없음 |
| UT-04 | 절이 없는 설정에서 set | UT-03 의 설정에 `harness set permissions.allow_push true` | 성공, `harness.toml` 에 `[permissions]` 와 `allow_push = true` |
| UT-05 | 모르는 키 거부 | `[permissions]` 에 `allow_merge = true` | 0 이 아닌 종료 코드, `unknown key(s) in [permissions]` |
| UT-06 | 불리언이 아닌 값 거부 | `allow_push = "true"` · `allow_push = 1` | 0 이 아닌 종료 코드, `permissions.allow_push must be true or false` |

## T3 · docs: README 설정 표와 가드레일 층위에 권한 허용 목록 반영

### 상위 Requirement

- relates to #70

### 작업 내용

T1 · T2 가 만든 권한 허용 목록을 사람용 문서에 적는다.

- 명세 2절의 README 항목 · 7절(문서)
- README 의 "`harness.toml` 이 정하는 것" 표: `permissions.allow_push` 행(생성되는 것: `.claude/settings.json` 의 허용 목록에 `git push` 를 넣는지),
  `forge.tracker` · `review_host` 행에 "권한 허용 목록의 forge 명령" 을 더한다
- `src/templates/managed/script/README.md` 의 "가드레일 층위" 표 바로 아래 한 문단: allow 는 승인 프롬프트만 없애고 deny · `PreToolUse` 가드 · git 훅은
  allow 에 든 명령에도 그대로 적용된다. 이 설정은 Claude Code 에만 적용된다
- 이 리포의 `script/README.md` 를 `harness render` 로 다시 만든다
- 건드릴 파일: `README.md`, `src/templates/managed/script/README.md`, `script/README.md`(설치본)

### 완료 조건

- [ ] README 설정 표에 `permissions.allow_push` 행이 있고 `forge.tracker` · `review_host` 행에 권한 허용 목록이 적혀 있다
- [ ] `src/templates/managed/script/README.md` 의 가드레일 층위 표 아래에 allow 와 deny · 가드 · 훅의 관계와 적용 대상(Claude Code)을 적은 문단이 있다
- [ ] 이 리포의 `script/README.md` 가 관리 원본과 같다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `feat/70-generate-permission-allow-list` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 관리 문서 설치본 일치 | `harness check` | `script/README.md` 어긋남 없음 |
