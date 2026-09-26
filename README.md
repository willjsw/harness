# harness

AI 개발 하네스. 이슈 하나를 명세 → 분해 → 구현 → 리뷰 루프로 끌고 가는 역할·절차·가드 한 벌이다.

**프로젝트마다 달라지는 값은 `harness.toml` 하나에 있다.** 규칙 문서·git 훅·권한 파일·에이전트
정의는 그 설정에서 생성되므로, 값을 바꿀 때 고치는 곳은 언제나 한 곳이다.

```bash
vim harness.toml              # 값을 바꾼다
.harness/bin/harness render   # 그 값을 쓰는 파일이 전부 따라 바뀐다
```

## 설치

```bash
brew tap willjsw/harness
brew trust willjsw/harness
brew install --HEAD harness
```

포뮬러는 별도 탭 리포 [`willjsw/homebrew-harness`](https://github.com/willjsw/homebrew-harness)
에 있다 — Homebrew 가 `homebrew-` 접두사를 붙여 찾으므로 탭 이름에 URL 이 필요 없다.
`brew trust` 는 공식이 아닌 탭의 포뮬러를 읽게 하는 한 번짜리 승인이다.

Homebrew 가 `bin` 을 이미 PATH 에 두므로 **따로 등록할 환경 변수가 없다.**
Homebrew 없이 쓰려면 클론한 뒤 `src/bin/harness` 를 직접 부르거나 링크 하나를 건다.

## 업데이트

```bash
brew update                           # 탭(포뮬러)을 새로 받는다
brew upgrade --fetch-HEAD harness     # 하네스 리포 main 의 최신 커밋으로 다시 설치
harness version
```

`--HEAD` 설치는 버전 번호가 없어 `brew upgrade` 만으로는 새 커밋을 보지 못한다 —
`--fetch-HEAD` 가 있어야 원격 main 을 다시 받는다. UI 의 `node_modules` 는 새 설치에 없으므로
다음 `harness start-server` 가 `npm install` 을 한 번 다시 한다.

**전역 CLI 를 올려도 프로젝트는 따라오지 않는다**(아래 "시작하기" 참고). 프로젝트의 사본까지
올리려면 그 리포에서 다시 설치하고 생성물 변경을 커밋한다.

```bash
cd <내-프로젝트>
harness install
harness doctor
```

## 시작하기

```bash
cd <내-프로젝트>
harness install
git config core.hooksPath script/githooks
harness doctor
```

`install` 은 하네스를 `<프로젝트>/.harness/` 에 넣고, 설정이 없으면 기본값을 깔아 프로젝트
이름까지 채운 뒤 렌더한다. **기본값은 그 프로젝트의 사실이 아니다** — `harness doctor` 가
무엇이 비어 있는지 알려 준다.

훅 활성화는 클론마다 1회다. 하지 않으면 커밋·push 검사가 조용히 건너뛰어진다.

### 모노레포

**하네스 루트는 리포 루트가 아니어도 된다.** 서브프로젝트마다 따로 설치하면 각자의 설정·역할·
검증을 갖는다. 스크립트와 훅은 git 루트가 아니라 **자기 위치**에서 하네스 루트를 잡으므로,
어디서 불러도 자기 서브트리만 본다.

```bash
harness install --target packages/api
git config core.hooksPath packages/api/script/githooks
```

두 가지는 리포당 하나뿐이라 서브프로젝트가 나눠 갖지 못한다.

| | 무엇이 걸리나 |
|---|---|
| `core.hooksPath` | 리포 설정이라 **한 서브프로젝트만 훅을 갖는다.** 나머지는 커밋·push 검사가 서지 않는다 |
| `.claude/` | 도구가 여는 작업 디렉터리 기준이다. 그 서브프로젝트를 열어야 권한·훅 설정이 적용된다 |

`docs/spec`·`docs/plan`·ADR 도 하네스 루트 아래에 선다 — 서브프로젝트의 명세는 그 서브프로젝트가 갖는다.

**프로젝트는 설치한 버전에 고정된다.** `.harness/` 안의 사본이 그 리포의 정본이고, 전역
CLI 를 올려도 거기까지 따라가지 않는다 — 그러지 않으면 전역을 올리는 순간 모든 프로젝트의
생성물이 바뀌고 검사가 한꺼번에 깨진다. 올리려면 그 리포에서 `harness install` 을 다시 돌린다.

**하네스 소스 리포만 예외다.** 자기 `src/bin/harness` 와 `src/templates/` 로 돌고 사본을 고정하지 않는다 —
사본을 두면 템플릿을 고칠 때마다 두 곳이 어긋난다. 여기서 `harness install` 은 등록과 렌더만 하고,
어느 CLI 로 부르든 이 리포의 `src/bin/harness` 로 넘어간다. 루트의 `harness.toml` 은 이 리포 자신의
설정이고, 대상 리포로 복사되는 기본값은 `src/templates/harness.toml` 이다.

python3 3.11 이상이 필요하다. 그 밖의 의존성은 없다.

## 명령

| 명령 | 하는 일 |
|---|---|
| `harness install` | 하네스를 `.harness/` 에 넣고 렌더까지 |
| `harness render` | 설정과 프로젝트 사실 → 생성 파일 |
| `harness check` | 생성 파일이 설정과 일치하는지. pre-commit 이 `--staged` 로 부른다 |
| `harness doctor` | 쓸 준비가 됐는지 — 설정·생성물·비어 있는 자리·끊긴 참조·도구·어댑터 검증 상태·훅 |
| `harness set <절.키> <값> ...` | 설정 값을 (여러 쌍이면 함께) 바꾸고 렌더까지. 성립하지 않으면 되돌린다 |
| `harness steps [<절차> <JSON>]` | 절차의 단계를 JSON 으로 보거나, 한 절차의 단계를 통째로 바꾸고 렌더까지. `--dry-run` 이면 검사만 |
| `harness checks [<JSON>]` | 검증 검사(`[verify]`)를 JSON 으로 보거나 통째로 바꾸고 렌더까지 |
| `harness run <워크플로> <이슈>` | 설정된 오케스트레이터로 절차를 시작한다 |
| `harness start-server` | 설정·절차·에이전트·프로젝트 문서를 고치는 웹 UI 를 `localhost:7777` 에 띄운다 |
| `harness tools [--sync]` | 이 기기에 설치된 에이전트 CLI·결정 기록 도구. 결과는 `~/.harness/tools.json` |
| `harness schema` | 에이전트 등록부와 역할별 실제 실행 주체(JSON). UI 가 선택지를 그린다 |
| `harness status` | 홈 화면용 프로젝트 상태(JSON) — check·doctor·프로젝트 사실·git |
| `harness uninstall` | 하네스가 깐 것만 지운다. `--purge` 면 소유 파일과 설정도 (확인을 받는다) |
| `harness metrics [import\|prune] [--since 7d] [--trace ID]` | 실행 지표 집계(JSON, Metrics 탭이 읽는다). `import` 는 새 대화 기록의 사용량을 먼저 가져오고, `prune` 은 보관 기간·용량 상한을 적용한다 |
| `harness vars` | 템플릿 변수 출력(디버깅용) |
| `harness version` · `help` | 버전, 도움말 |

`uninstall` 은 **프로젝트가 쓴 것을 지우지 않는다.** `.ai/project/` 의 산문,
명세 색인, 명세·분해·결정 기록은 그대로 둔다. `--purge` 는 앞의 것과
설정까지 지우지만 작업 산출물은 건드리지 않는다.

**`--purge` 는 지우기 전에 멈춘다.** 사라질 것을 디렉터리 단위로 보이고 — 다시 설치하면 돌아오는
것과 돌아오지 않는 것을 나눠 — 확인을 받는다. 되돌릴 수 없는 유일한 명령이라 여기만 게이트가 있다.

```
purge target: /path/to/project

  installed by the harness — `harness install` puts these back
    .harness/                      vendored copy of the harness
    .ai/                           16 files
    script/                        29 files

  yours — these do not come back
    .ai/project/scope.md
    …
    harness.toml

  untouched work output: docs/spec, docs/plan, docs/adr

remove these? [y/N]
```

대화형이 아닌 셸에서는 묻지 못하므로 그대로 멈춘다(종료 코드 2). 스크립트에서 돌리려면
`--yes` 를 준다.

## UI

```bash
harness start-server          # http://localhost:7777
```

`harness install` 이 `~/.harness/<프로젝트>/project.json` 에 경로를 남기고, UI 가 그 목록으로
프로젝트를 전환한다. 경로가 없는 옛 설치는 목록에 "재설치 필요" 로 뜬다 — 그 프로젝트에서
`harness install` 을 다시 돌린다. 서버는 루프백에만 묶이고, 첫 실행에 `npm install` 을 한 번 한다
(Node.js 필요).

| 화면 | 무엇을 | 쓰기 경로 |
|---|---|---|
| Harness | `harness.toml` 의 한 줄짜리 값. 역할·절차·명령·검증은 각자의 화면이 다룬다 | `harness set` |
| Project Settings | `.ai/project/` — 항목별 50자 입력 → AI Completion → 검토 → 저장. 명령 탭은 빌드·테스트 명령과 검증 검사 | 파일 쓰기 후 `harness render` · `harness set` · `harness checks` |
| Workflows | 단계 블럭을 끌어 순서 바꾸기·끼우기·빼기, 고른 블럭 하나를 우측 패널에서 편집 | `harness steps` (편집 중에는 `--dry-run` 으로 검사만) · `harness set` |
| Agents | 역할 카드를 넘겨 보고, 역할 계약(읽기 전용)과 이 프로젝트의 지시(`.ai/project/roles/<역할>.md`)를 본다·고친다 | 파일 쓰기 후 `harness render` · `harness set` |
| Metrics | 토큰·실행 시간·상태·단계별 사용량·실패 로그. 열 때마다 새 대화 기록을 가져온다 | `harness metrics import` (읽기만) |
| Doctor | `doctor` 결과를 절별로, 막힌 것부터. 정해 둔 조치는 ▷ 로 바로 실행 | `harness status` · 조치별 명령 |

UI 는 설정을 고치는 로직을 따로 갖지 않는다 — 검증·되돌림·렌더는 CLI 가 한다.

**문서는 읽기가 기본이다.** 워크플로 노드의 본문과 프로젝트 문서는 마크다운으로 그려 보이고,
눈·연필 아이콘으로 편집 모드를 켜야 원문(`#`·`-` 등)을 고칠 수 있다. 노드에서 고치는 것은 덧붙인 지시(`text`)뿐이다 —
기본 본문은 하네스 것이다.

**저장 전에 검사한다.** 정적 검사가 깨진 글자·닫히지 않은 코드 블록·`#` 뒤 공백 누락을 잡고,
`src/ui/skills/md-check/SKILL.md` 스킬을 저렴한 모델로 돌려 맞춤법·문장을 본다. 찾은 것이 있으면 목록을
보이고 **저장할지는 사람이 정한다** — 모델 판정이라 오탐이 있을 수 있다.

**AI Completion 은 검사를 통과해야 돈다.** 비었거나 50자를 넘거나 글자가 없는 항목은 정적
검사가 잡고(`E_EMPTY`·`E_TOO_LONG`·`E_NO_CONTENT`), 남은 항목은 저렴한 모델이 무의미한지 본다
(`E_MEANINGLESS`, 모델을 부르지 못하면 `E_CHECK_FAILED`). 모델은 오케스트레이터 CLI 로 부른다 —
`claude` 는 검사에 `haiku`, `codex` 는 기본 모델. 쓰기 도구는 주지 않는다.

## 파일은 세 부류다

부류가 곧 갱신 경계다. 한 파일 안에 두 부류가 섞이면 갱신할 방법이 없으므로, 섞이지 않게
파일을 나눈다.

| 부류 | 어디 | 고치는 법 |
|---|---|---|
| **생성** | `.ai/AI_AGENT.md` · `.ai/workflows/` · `.ai/forge.md` · `.ai/adr.md` · `.claude/` · `.codex/` · `script/githooks/` · `script/harness.env` · `script/harness.plan.json` · `script/harness-verify.sh` · `script/forge.sh` · `CLAUDE.md` · `AGENTS.md` | 고치지 않는다. `harness.toml` 을 고치고 `render` |
| **관리** | `.ai/templates/` · `script/` 의 나머지 · `docs/workflow/` | 하네스 것이다. 갱신이 덮는다 |
| **소유** | `.ai/project/`(역할·절차별 지시 `roles/`·`workflows/` 포함) · `docs/spec/README.md` · CI 설정 | 프로젝트 것이다. 갱신이 건드리지 않는다 |

**CI 설정은 첫 설치 때 한 번만 깔린다.** `forge.review_host` 에 따라
`.github/workflows/harness-verify.yml` 또는 `.gitlab-ci.yml` 이 **없을 때만** 생기고,
그 뒤로는 프로젝트 것이다 — `render` 가 덮지 않고 `uninstall --purge` 도 지우지 않는다
(하네스가 만든 것인지 원래 있던 것인지 가릴 수 없다). 내용은 `script/run-lint-test.sh`
한 줄을 돌리는 골격뿐이고, 무엇을 검증할지는 `harness.toml` 의 `[commands]`·`[verify]` 가 갖는다.
`review_host` 를 바꿔도 이미 깔린 파일은 남는다 — 소유 파일이므로 지우는 것은 사람이 한다.

**역할에 이 프로젝트만의 지시를 더하려면 `.ai/project/roles/<역할>.md` 를 쓴다.** `render` 가 그 역할의 에이전트
정의(Claude·Codex 양쪽) 끝에 "이 프로젝트에서" 절로 붙인다. 역할 계약(`.ai/templates/`)은 관리 파일이라
고쳐도 다음 갱신이 덮는다. 이 디렉터리는 기준 문서처럼 늘 보호된다.

프로젝트 사실은 규칙 문서 안에 직접 쓰지 않고 `.ai/project/` 에 둔다. 규칙 문서가 그 본문을
포함해 생성되므로, 소유 파일을 고치고 `render` 를 잊으면 `harness check` 가 커밋을 막는다.

## `harness.toml` 이 정하는 것

| 설정 | 생성되는 것 |
|---|---|
| `branches.base` · `protected` | pre-push 검사와 차단 메시지, 권한 deny, 착수 판정의 기준 ref, 규칙 문서 |
| `commit.tags` · `issue_ref` · `ticket_key` | commit-msg 의 **검사식과 안내문 예시**, task 이슈 제목 |
| `review.max_rounds` · `repeat_file_max` · `round_label` | 리뷰·등록·집계 스크립트가 읽는 상수 |
| `roles.<역할>.runner` · `model` · `access` | 역할마다 에이전트 정의(Claude·Codex 양쪽)와 그 역할 전용 커맨드, 리뷰 실행 명령 |
| `forge.tracker` · `review_host` | 어댑터 선택, forge 명령 사전 |
| `issues.labels` · `required_fields` · `deletion_forbidden` | 이슈 생성 스크립트, 삭제 가드, 규칙 문서 |
| `mr.default_assignee` · `default_reviewer` | forge 명령 사전, 작성 요령 |
| `adr.style` · `tool` · `dir` | 결정 기록 사전·양식·디렉터리 |
| `docs.protected` | 권한 deny, 명령 가드, 규칙 문서 |
| `usage.log_path` · `env_var` | 기록·집계 스크립트, 회고 절차 |
| `workflows.<절차>.steps` | `.ai/workflows/<절차>.md` — 단계 순서·종류(`type`)·제목. 없으면 하네스 기본값. 절차 끝에 붙일 지시는 `.ai/project/workflows/<절차>.md` |

`invariants.distinct_reviewer` 는 파일을 만들지 않고 **render 를 막는다.** 구현자와 리뷰어의
러너가 같으면 거부한다 — 같은 모델이 자기 코드를 리뷰하면 같은 맹점을 두 번 지나간다.
어느 역할끼리 달라야 하는지는 역할 선언의 `distinct_from` 이 정한다.

`roles.<역할>.runner` 는 `inproc`(오케스트레이터의 서브에이전트)이거나 벤더 선언
(`src/templates/vendors.toml`)에 실행 명령이 있는 CLI 다. 역할마다 무엇을 어떻게 띄우는지는
`script/harness.plan.json` 으로 생성되고, CLI 러너 역할은 `script/run-agent.py <역할>` 이 그 계획대로 띄운다.

설정이 더는 만들지 않는 파일은 다음 `render` 가 지운다. 옛 forge 어댑터나 옛 결정 기록 양식이
남아 어느 쪽이 현재인지 알 수 없게 되는 일이 없다.

## 설계 원칙 셋

**1. 설정이 정본이고 파일은 생성물이다.**
설치할 때 한 번 치환하는 방식은 설치 순간에만 단일 지점이다. 운영 중에 값을 바꾸면 다시 여러
곳을 손으로 고쳐야 한다. `harness.toml` 은 리포에 남고 `render` 는 언제든 다시 돈다.

**2. 계약은 자기가 누구인지 모른다.**
`.ai/templates/<역할>.md` 는 자기가 어느 모델로 도는지, 결과를 누가 받는지 모른다.
스크립트와 어댑터가 정한다. 덕분에 도구를 바꿔도 계약은 그대로다.

**3. 생성물은 문서가 아니라 검사가 지킨다.**
`harness check` 가 생성 파일과 설정의 일치를 확인하고, pre-commit 이 스테이징 기준으로 같은
검사를 돌린다. "고치지 마세요" 라고 적어 두는 대신 못 고치게 한다.

## 구조

```
harness/
├── harness.toml              이 리포 자신의 하네스 설정 — 소스 리포도 하네스를 쓴다
├── .ai/ · script/ · docs/    그 설정에서 생성·설치된 이 리포의 하네스
└── src/                      하네스 자체 — 대상 리포로 가는 것과 그것을 만드는 것
    ├── bin/harness           CLI — 위 명령 전부
    ├── templates/
    │   ├── harness.toml      기본 설정. `install` 이 대상 리포로 복사한다
    │   ├── generated/        {{VAR}} 치환 대상
    │   ├── managed/          그대로 복사 — 역할 계약·절차·배관
    │   ├── owned/            없을 때만 복사 — 프로젝트 사실
    │   ├── workflows/<절차>/ 절차의 머리·꼬리와 기본 단계 본문
    │   ├── agents/           역할 어댑터 본문. frontmatter 는 설정에서 나온다
    │   ├── forge/<kind>/     forge 명령 사전 조각
    │   └── adr/<style>/      결정 기록 문서 세트
    ├── ui/                   `harness start-server` 의 Next.js 앱
    └── test/render-test.sh   회귀 테스트
```

설정 형식은 TOML 이다. `tomllib` 가 python 표준 라이브러리라 의존성이 0이고, YAML 은 `yq` 나
`PyYAML` 이 필요하다. 주석을 쓸 수 있어 설정 파일이 곧 스키마 문서가 된다.

## 검증

```bash
src/test/render-test.sh
```

373건. 설정 변경이 생성물에 전파되는가, 생성물을 손대면 검사가 잡는가, 소유 파일이 보존되고
관리 파일이 갱신되는가, 불변식 위반과 성립하지 않는 조합을 거부하는가, 제거가 프로젝트의 것을
남기는가, 심볼릭 링크로 실행해도 템플릿을 찾는가, 끊긴 참조를 `doctor` 가 잡는가를 본다.
뒤쪽 케이스는 임시 리포에 실제로 설치해 관리 스크립트의 회귀 테스트 359건을 돌리고,
아래 자체 검사가 계약 위반 6종을 실제로 잡는지 확인한다.

설치된 리포에서는 `script/run-lint-test.sh` 가 생성물 일치·회귀 테스트·프로젝트 검증을 잇는다.

## 지원 범위

| 대상 | 어댑터 | 실제 forge 검증 |
|---|---|---|
| GitLab (`glab`) | 이슈·리뷰 양쪽 | **미검증** |
| GitHub (`gh`) | 이슈·리뷰 양쪽 | 계약 13종 통과 |
| Jira (`jira`) | **이슈만** | **미검증** |

`forge.tracker` 와 `forge.review_host` 는 따로 고른다. **Jira 는 리뷰 호스트가 될 수 없다** —
코드 리뷰를 호스팅하지 않으므로 설정 검증이 거부한다. 트래커로 Jira 를 쓰고 리뷰는 GitLab·
GitHub 에서 한다. 없는 forge 를 고르면 `render` 가 거부한다.

Jira 는 이슈 식별자가 번호가 아니라 키(`PROJ-12`)다. `commit.issue_ref = "prefix"` 와
`commit.ticket_key` 를 함께 쓰고, `issues.type` 에 그 프로젝트의 이슈 유형 이름을 적는다 —
유형이 없으면 생성이 거부된다. 인증은 `jira init` 이 만든 설정이 갖고 리포에는 두지 않는다.

어댑터가 계약을 지키는지는 **실제 forge 를 상대로** 확인한다. 회귀 테스트는 페이크를 쓰므로
어댑터를 한 줄도 타지 않는다.

```bash
script/forge-selftest.sh <리뷰요청번호> <이슈번호>                 # 읽기 9종, 흔적 없음
script/forge-selftest.sh --write <리뷰요청번호> <이슈번호>          # + 쓰기 3종, 댓글 2건이 남는다
script/forge-selftest.sh --create-issue <리뷰요청번호> <이슈번호>   # + 이슈 1건, 되돌릴 수 없다
```

버려도 되는 리뷰 요청에만 쓴다. 전 단계를 통과하면 어댑터 머리글의 미검증 표기를 지운다.

결정 기록은 Nygard(`adr-tools`)·MADR(수동)·쓰지 않음 셋이고, 오케스트레이터는 Claude Code 와
Codex CLI 다.

`.ai/forge.md` 와 이슈·리뷰 양식은 `.ai/templates/` 에 있다. forge 네이티브 디렉터리
(`.gitlab/`, `.github/`)에 사본을 만들지 않으므로, 웹 UI 의 양식이 필요하면 직접 둔다.

## 언어

**터미널로 내는 출력은 영어, 파일과 forge 로 올라가는 본문은 한국어다.** 명령·훅·가드·
스크립트의 메시지가 앞쪽이고, 규칙 문서·역할 계약·리뷰 입력·리뷰 요약 댓글·이슈 본문이 뒤쪽이다.
코드 주석도 한국어다.

기계가 읽는 표지 문자열(`script/harness-format.sh`)은 뒤쪽에 속한다. 쓰는 쪽이 역할 계약이고
읽는 쪽이 스크립트라, 한쪽만 옮기면 파서가 조용히 빈 결과를 낸다. 문서를 다른 언어로 옮기려면
그 파일과 역할 계약·양식을 **같은 커밋에서** 함께 고친다.
