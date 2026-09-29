# 절차가 부르는 명령의 권한 허용 목록 생성

`harness render` 가 `.claude/settings.json` 의 `permissions.allow` 를 설정과 하네스 템플릿에서 만든다.
절차가 정상 경로에서 부르는 명령은 승인 프롬프트 없이 돌고, 막아야 할 명령은 지금처럼 deny·명령 가드·git 훅이 막는다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 허용 목록 생성 (`settings_json` · 새 `allow_rules`) · 설정 검증 (`normalize()` · `validate()`) · `set` | `src/bin/harness` |
| 기본 설정 | `src/templates/harness.toml` |
| forge 별 허용 선언 | `src/templates/forge/<kind>/allow.toml` (새 파일) |
| 가드레일 층위 표 | `src/templates/managed/script/README.md` |
| 회귀 테스트 | `src/test/render-test.sh` |
| UI 설정 도움말·절 묶음 | `src/ui/lib/help.js` · `src/ui/app/[project]/settings/page.js` |

이 리포의 `script/` · `.claude/settings.json` 은 거기서 설치·생성된 사본이다.

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

- `.claude/settings.json` 의 `permissions.allow` 가 세 묶음으로 늘어난다 — 관리 스크립트(3절), forge 명령(4절), git 명령(5절).
  기존의 `Bash(script/metric.py step:*)` 는 `Bash(script/metric.py:*)` 로 대체된다
- `permissions.deny` 는 바뀌지 않는다. `deny_rules()` 의 입력과 출력이 그대로다
- `hooks.PreToolUse` 의 명령 가드(`script/hooks/bash-guard.sh`)는 바뀌지 않는다. allow 는 승인 프롬프트를 없앨 뿐
  가드를 건너뛰지 않는다 — 가드는 allow 에 든 명령에도 실행 전에 돈다
- git 훅(`pre-push` · `commit-msg` · `pre-commit`)은 바뀌지 않는다
- 규칙 정본의 금지 사항은 바뀌지 않는다. "명시적 지시 없는 커밋, push, 리뷰 요청 생성" 은 allow 에 들어도 여전히 금지다 —
  allow 는 도구 차원의 승인 대기를 없앨 뿐 규칙을 바꾸지 않는다
- 대상은 Claude Code 의 `.claude/settings.json` 하나다. `.codex/` 생성물과 Codex 오케스트레이터의 승인 방식은 바뀌지 않는다
- 새 생성 파일은 없다. `.claude/settings.json` 은 이미 `plan()` 에 있다
- 설정에 `[permissions]` 절이 새로 생긴다 (2절)

## 2. 설정 — `[permissions]`

```toml
# ─────────────────────────────────────────────────────────────────────────────
# 권한 (Claude Code `.claude/settings.json`)
# ─────────────────────────────────────────────────────────────────────────────
[permissions]
# 절차가 부르는 관리 스크립트, forge 의 조회·리뷰 요청 생성·댓글, `git switch -c`·`git commit` 은
# 승인 없이 돈다. 이 값이 참이면 `git push` 도 승인 없이 돈다.
# 보호 브랜치 push 와 force push 는 이 값과 무관하게 deny·명령 가드·pre-push 가 막는다.
allow_push = false
```

`src/templates/harness.toml` 에서 이 절은 `[docs]` 절 다음, `[usage]` 절 앞에 둔다.

| 키 | 기본값 | 규칙 |
|---|---|---|
| `allow_push` | `false` | 불리언 |

- 절에 정의되지 않은 키가 있으면 render 를 거부한다:
  `error: unknown key(s) in [permissions]: <키> ... help: the keys are allow_push`
- `allow_push` 가 불리언이 아니면(TOML 의 `true`/`false` 가 아닌 문자열·숫자 포함) 거부한다:
  `error: permissions.allow_push must be true or false (got <값>)`
- 기본값은 `normalize()` 가 채운다 (`[worktree]` 와 같은 자리). `[permissions]` 절이 없는 옛 설정도 기본값으로 그대로 렌더된다.
  이 리포 루트의 `harness.toml` 도 절 없이 기본값으로 돈다
- `derive()` 는 새 변수를 내지 않는다. 허용 목록은 `settings_json(cfg)` 가 설정을 직접 읽어 만든다
- `harness set permissions.allow_push true` 는 `[permissions]` 절이 없는 설정에서도 동작한다 — `set_line()` 이
  절이 없으면 파일 끝에 `[permissions]` 절을 더하고, 키가 없으면 그 절 끝에 `allow_push = <값>` 줄을 더한다.
  더한 뒤의 검증 실패는 지금처럼 파일을 되돌린다

새 설정 키를 둘 곳의 나머지:

- README 의 "`harness.toml` 이 정하는 것" 표에 `permissions.allow_push` 행 — 생성되는 것: `.claude/settings.json` 의 허용 목록에 `git push` 를 넣는지.
  같은 표의 `forge.tracker` · `review_host` 행에 "권한 허용 목록의 forge 명령" 을 더한다
- `src/ui/lib/help.js` 에 `permissions.allow_push` 도움말 한 줄 — 켜면 `git push` 가 승인 없이 돌고, 보호 브랜치와 force push 는 그대로 막힌다는 뜻
- `src/ui/app/[project]/settings/page.js` 의 `GROUPS` 에서 `permissions` 절을 `scm`(Source Control) 묶음에 넣는다

## 3. 관리 스크립트 묶음

규칙 형식: `Bash(script/<이름>:*)`. 스크립트마다 한 줄이고, 이름은 파일 이름 그대로다. `script/*` 같은 글롭 규칙을 두지 않는다.

대상은 **하네스가 까는 관리 스크립트** 로 한정한다 — `src/templates/managed/script/` 바로 아래의 정규 파일 중

- 확장자가 `.sh` 또는 `.py` 이고
- 이름이 `_` 로 시작하지 않고 (`_review.py` 처럼 다른 스크립트가 `python3 script/_review.py` 로만 부르는 모듈)
- 제외 목록에 없는 것 전부다

목록은 렌더할 때 그 디렉터리를 읽어 만든다. 관리 스크립트를 더하면 다음 렌더에서 허용 목록에 따라 들어간다.
하위 디렉터리(`hooks/` · `forge/`)는 대상이 아니다 — 훅이 부르거나 다른 스크립트가 소스하는 파일이다.
생성 스크립트(`script/harness-verify.sh` · `script/forge.sh`)와 프로젝트가 둔 스크립트(`script/project/` 등)도 대상이 아니다.

제외 목록 (`src/bin/harness` 의 상수 하나):

| 스크립트 | 제외하는 이유 |
|---|---|
| `rollback-work.sh` | 리뷰 요청·task 이슈를 닫는다. 사용자가 직접 부르고 확인을 주는 턴에서만 돈다 |
| `create-carryover-issue.sh` | 이슈를 만든다. 되돌릴 수 없는 forge 쓰기다 |
| `forge-selftest.sh` | `--create-issue` 로 이슈를 만든다. 되돌릴 수 없는 forge 쓰기다 |

제외 목록의 이름이 `src/templates/managed/script/` 에 없으면 render 를 거부한다 (이름이 바뀐 스크립트가 조용히 허용되지 않게):
`error: permission exclusion names a script that is not shipped: <이름>`.

`sync-task-issues.sh` 는 대상에 든다 — 승인된 분해로만 이슈를 만드는 게이트를 스크립트 자신이 지킨다.

## 4. forge 명령 묶음

### 4-1. 선언 파일

forge 마다 `src/templates/forge/<kind>/allow.toml` 을 둔다. 마크다운 사전(`tracker.md` · `review.md`)은 읽지 않는다.

```toml
# 절차가 정상 경로에서 부르는 이 forge 의 명령. `.claude/settings.json` 의 permissions.allow 로 간다.
# 항목 하나가 규칙 `Bash(<항목>:*)` 하나다 — 이 접두로 시작하는 명령이 승인 없이 돈다.
# 되돌릴 수 없는 쓰기(이슈 생성·머지·닫기·삭제)와 범용 API 호출은 넣지 않는다.
tracker = [...]   # 이 forge 가 forge.tracker 일 때
review = [...]    # 이 forge 가 forge.review_host 일 때
```

| kind | `tracker` | `review` |
|---|---|---|
| github | `gh issue view` · `gh issue comment` | `gh pr view` · `gh pr diff` · `gh pr create` · `gh api repos/{owner}/{repo}/pulls/*/comments/*/replies` |
| gitlab | `glab issue view` · `glab issue note create` | `glab mr view` · `glab mr diff` · `glab mr create` · `glab api --method POST projects/:id/merge_requests/*/discussions/*/notes` |
| jira | `jira issue view` · `jira issue comment add` | 키 없음 (리뷰 호스트가 될 수 없다) |

- `gh api` · `glab api` 는 리뷰 스레드 답글 경로 하나로만 둔다. `{owner}/{repo}` · `:id` 는 명령 사전과 같은 표기 그대로다(각 CLI 가 채우는 자리 표시)
- 이슈 생성(`gh issue create` · `glab issue create` · `jira issue create`), 라벨 변경(`gh pr edit` · `glab mr update`), 현재 사용자 조회(`gh api user` 등)는 넣지 않는다.
  라벨은 `review-mr.sh` 가 어댑터로 올리고, 이슈 생성은 `sync-task-issues.sh` 가 한다
- 리뷰 요청 생성이 allow 에 드는 것은 승인 대기를 없앨 뿐이다. 명시 지시 없이 만들지 않는 규칙은 1절대로 남는다

### 4-2. 읽는 규칙

- `forge.tracker` 의 `allow.toml` 에서 `tracker` 를, `forge.review_host` 의 `allow.toml` 에서 `review` 를 읽는다. 두 forge 가 같아도 각 키만 읽는다
- 파일이 없으면 render 를 거부한다: `error: no permission list for this forge\n  --> <경로>\n\nhelp: check [forge] in harness.toml`
- 읽는 키가 없거나 문자열 배열이 아니면 거부한다: `error: <경로>: \`<키>\` must be a list of command prefixes`
- 항목마다: 비어 있지 않고, 한 줄이고, 앞뒤 공백이 없고, `(` `)` 가 없고, `:*` 로 끝나지 않는다. 어기면
  `error: <경로>: <키>[<번호>] is not a command prefix (got <값>)`
- 파일의 다른 키는 거부한다: `error: <경로>: unknown key(s): <키> ... help: the keys are tracker, review`

## 5. git 명령 묶음

| 규칙 | 조건 |
|---|---|
| `Bash(git switch -c:*)` | 항상 |
| `Bash(git commit:*)` | 항상 |
| `Bash(git push:*)` | `permissions.allow_push = true` 일 때만 |

- `allow_push = false` 면 `git push` 는 allow 에도 deny 에도 없어 승인 대상으로 남는다
- 보호 브랜치 push · force push · `--no-verify` 는 `allow_push` 와 무관하게 deny 에 그대로 있다 (1절).
  deny 와 allow 가 같은 명령에 걸리면 deny 가 이긴다 — Claude Code 의 권한 판정 동작이다 <!-- TBD: 확인 필요 — 이 리포의 회귀 테스트는 판정을 흉내 내지 않고, 리뷰 요청 본문에 수동 확인 결과를 기록한다 -->
- `git switch -c <보호 브랜치 이름>` 처럼 보호 브랜치 이름의 로컬 브랜치를 만드는 것은 막지 않는다. 그 브랜치로의 커밋·push 는 명령 가드와 git 훅이 막는다

## 6. 생성 형식

`settings_json(cfg)` 의 `permissions` 는 `{"allow": allow_rules(cfg), "deny": deny_rules(cfg)}` 다.

`allow_rules(cfg)` 의 순서는 고정한다 — 렌더가 같은 설정에서 같은 파일을 내야 `harness check` 가 어긋남을 오탐하지 않는다.

1. 관리 스크립트 규칙 — 파일 이름 오름차순
2. forge 규칙 — `tracker` 항목을 선언 순서대로, 이어서 `review` 항목을 선언 순서대로. 같은 규칙이 두 번 나오면 처음 것만 둔다
3. git 규칙 — 5절 표의 순서

`settings_json()` 의 주석은 "절차가 정상 경로에서 부르는 명령은 묻지 않고 돈다 — 승인을 기다리면 흐름이 끊기고 비대화형 실행은 멈춘다.
막아야 할 명령은 deny 와 가드가 막는다" 는 뜻으로 고친다.

규칙 표기는 Claude Code 권한 규칙의 `Bash(<접두>:*)` 형식이다. `*` 는 `/` 를 포함한 임의 문자열에 맞는다 <!-- TBD: 확인 필요 — 명령 중간의 `*`(forge 답글 경로)가 Claude Code 에서 이 뜻으로 해석되는지 -->

## 7. 문서

- `src/templates/managed/script/README.md` 의 "가드레일 층위" 표 바로 아래에 한 문단: `.claude/settings.json` 의 allow 는 승인 프롬프트만 없앤다.
  deny·`PreToolUse` 가드·git 훅은 allow 에 든 명령에도 그대로 적용된다. 이 설정은 Claude Code 에만 적용된다
- README 와 UI 도움말은 2절

## 8. 회귀 테스트 (`src/test/render-test.sh`)

생성 구조만 본다. Claude Code 의 권한 판정(deny 우선)을 흉내 내는 함수를 두지 않는다.

`setup()` 은 `allow_push = false` 로 고정한다 (케이스가 바꿔 보는 값이다).

새 UT 블록 — 번호는 기존 블록과 겹치지 않게 매긴다:

1. **기본값에서 허용과 거부가 함께 생성된다.** `setup()` 설정(`forge` 는 gitlab)으로 렌더한 `.claude/settings.json` 을 JSON 으로 읽어
   - `allow` · `deny` 가 둘 다 비어 있지 않다
   - 설치된 `script/` 바로 아래의 `.sh` · `.py` 중 `_` 로 시작하지 않고 제외 목록에 없는 것이 **전부** `Bash(script/<이름>:*)` 로 있다 — 목록을 테스트에 적지 않고 설치된 파일에서 센다
   - `script/rollback-work.sh` · `script/create-carryover-issue.sh` · `script/forge-selftest.sh` 규칙이 없다
   - `script/sync-task-issues.sh` 규칙이 있다
   - `Bash(script/*` 로 시작하는 글롭 규칙, `script/project/` 를 담은 규칙, `script/harness-verify.sh` 규칙이 없다
   - `Bash(git switch -c:*)` · `Bash(git commit:*)` 가 있고 `Bash(git push:*)` 가 없다
   - `glab mr view` 규칙이 있고 `gh ` 로 시작하는 규칙이 없다
   - `issue create` 를 담은 규칙이 없다 (명령 사전 `.ai/forge.md` 에는 그 문자열이 있다)
2. **allow 가 늘어도 보호 브랜치 deny 가 유지된다.** 1 의 `deny` 를 기록하고 `harness set permissions.allow_push true` 로 렌더한다
   - `allow` 에 `Bash(git push:*)` 가 생긴다
   - `deny` 가 1 의 것과 같다 — 보호 브랜치(`main` · `development`)마다의 push 규칙과 force push · `--no-verify` 규칙이 전부 남아 있다
3. **`[permissions]` 절이 없는 옛 설정.** 절을 지운 설정이 렌더되고 `Bash(git push:*)` 가 없다. 그 설정에서
   `harness set permissions.allow_push true` 가 성공하고 `harness.toml` 에 `[permissions]` 절과 `allow_push = true` 가 생긴다
4. **forge 를 따라간다.** `forge.tracker = jira` · `review_host = github` 로 렌더하면 `jira issue view` · `gh pr view` 규칙이 있고 `glab` 규칙이 없다.
   `gh api` 규칙은 답글 경로 하나뿐이다
5. **성립하지 않는 설정을 거부한다.** `[permissions]` 의 모르는 키, 불리언이 아닌 `allow_push` 가 각각 render 를 0 이 아닌 종료 코드로 막고 2절의 메시지를 낸다

UT-00(배포 기본값 렌더)은 새 절을 포함한 기본 설정이 그대로 렌더되는지를 이미 본다.

수동 확인 (리뷰 요청 본문에 기록): `allow_push = true` 로 렌더한 설정에서 Claude Code 가 `git push origin <보호 브랜치>` 를 거부하는지.
