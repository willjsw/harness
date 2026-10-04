# UI 쓰기의 CLI 일원화

UI 는 파일을 직접 쓰지 않는다. 문서·메모 저장, Doctor 조치, 새 프로젝트 만들기가 모두 CLI 명령을 서브프로세스로
부르고, 같은 조작은 CLI 와 UI 에서 같은 코드 지점을 거친다. UI 는 파일 경로와 판정 값을 `harness schema` 에서
받고 스스로 짓지 않는다. 에이전트가 `harness write-doc` 으로 보호 문서를 고치는 길은 명령 가드와 권한 deny 가 막는다.

정본 위치:

| 대상 | 정본 |
|---|---|
| `write-doc` · `fix` 명령, `install --create` · `--git-init`, `schema` 의 새 키, `deny_rules()` | `src/bin/harness` |
| `write-doc` 명령 가드 | `src/templates/managed/script/hooks/_guards.sh` · `bash-guard.sh` |
| UI 의 읽기·쓰기 | `src/ui/lib/harness.js` · `src/ui/lib/actions.js` |
| 문서 탭 구성과 질문 양식 | `src/ui/lib/fields.js` |
| UI Doctor 문구와 조치 고르기 | `src/ui/lib/doctor.js` |
| UI 보호 문서 목록 편집 | `src/ui/lib/paths.js` · `src/ui/components/PathList.js` · `src/ui/components/ValueField.js` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/templates/managed/script/test-bash-guard.sh` · `src/ui/lib/doctor.test.js` · `src/ui/lib/paths.test.js` |
| 사람용 설명 | `README.md` |

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

- UI 에서 `fs.writeFile` · `fs.mkdir` 과 `git` · `bash` 직접 실행이 사라진다. UI 가 부르는 실행 파일은 하네스 CLI,
  모델 질의용 에이전트 CLI(`ask`), 사람이 명령 탭에 적은 명령(`runCommand`), macOS 폴더 선택 창(`pickDirectory`)이다.
  뒤의 셋은 UI 가 파일을 쓰는 동작이 아니므로 그대로 둔다
- 문서 저장(`saveDoc`)·역할 메모(`saveRoleNotes`)·절차 메모(`saveWorkflowNotes`)는 `harness write-doc` 한 번으로 끝난다.
  쓰기 뒤의 render 는 그 명령이 한다 (2절)
- Doctor 의 ▷ 조치 `hooks` · `verify` 는 `harness fix` 를 부른다 (3절). `render` · `upgrade` 는 지금처럼 `harness render` ·
  `harness install` 이다
- 새 프로젝트 만들기는 `harness install --create [--git-init]` 한 번이다 (4절)
- UI 가 읽는 파일 경로(문서·원형·생성된 절차 문서·검증 스크립트·훅 경로)와 옛 검증 스크립트 판정·설정 주석·기본 보호
  문서 목록은 `harness schema` 에서 받는다 (5절)
- Doctor 의 ▷ 조치는 doctor 항목의 `section` · `what` · `state` · `detail` 로 고른다. 항목 구조(#59)에 키를 더하지 않는다 (7-5)
- 문서 탭 구성과 탭마다의 질문 양식은 `fields.js` 의 `DOCS` 가 계속 갖는다. schema 의 문서 목록은 탭을 정하지 않는다.
  이 변경으로 더해지거나 빠지는 탭은 없다
- 에이전트가 `harness write-doc` 으로 보호 문서·역할 메모·절차 메모를 쓰는 호출은 명령 가드와 deny 가 막는다 (6절)
- 쓰기 결과(파일 내용·render 결과)는 지금 UI 가 내는 것과 같다. 메모 머리 주석을 붙이는 규칙이 UI 에서 CLI 로 옮겨 온다

## 2. `harness write-doc <이름> -`

표준 입력의 본문을 이름이 가리키는 소유 파일에 쓰고 render 한다.

### 2-1. 이름

| 이름 | 쓰는 파일 | 받는 조건 |
|---|---|---|
| `<문서>` | `.ai/project/<문서>.md` | 하네스 원형(`templates/owned/.ai/project/*.md`)에 있는 문서. schema `docs` 의 키와 같다 |
| `roles/<역할>` | `.ai/project/roles/<역할>.md` | `<역할>` 이 설정의 `roles` 에 있다. schema `roles.<역할>.notes` 와 같은 경로다 |
| `workflows/<절차>` | `.ai/project/workflows/<절차>.md` | `<절차>` 가 설정의 `workflows` 에 있다(기본 절차 포함). schema `workflow_notes.<절차>` 와 같은 경로다 |

- 위 표에 없는 이름은 거절한다. `commands`(명령은 설정의 `[commands]` 다)와 옛 `.ai/project/commands.md` 도 거절 대상이다
- 경로를 입력에서 만들지 않는다. 이름을 표의 목록과 문자열로 비교하고, 맞는 항목의 경로를 쓴다 — `..` · 절대 경로 ·
  `.md` 가 붙은 이름은 목록에 없으므로 거절된다
- 두 번째 인수는 `-` 만 받는다. 다른 값이나 빠진 인수는 거절한다

### 2-2. 쓰기

1. 설정을 읽는다. 설정이 성립하지 않으면 아무것도 쓰지 않고 멈춘다
2. 표준 입력 전체를 UTF-8 로 읽는다
3. 메모(`roles/` · `workflows/`)이고 본문이 공백이 아니며 공백을 걷은 앞머리가 `<!--` 로 시작하지 않으면 머리 주석을 붙인다

   역할 메모:

   ```
   <!--
   이 파일은 프로젝트가 소유한다. 하네스 갱신이 덮지 않는다.
   `harness render` 가 이 본문을 이 역할의 에이전트 정의 끝("이 프로젝트에서")에 붙인다.
   -->

   ```

   절차 메모:

   ```
   <!--
   이 파일은 프로젝트가 소유한다. 하네스 갱신이 덮지 않는다.
   `harness render` 가 이 본문을 이 절차 끝("이 프로젝트에서")에 붙인다.
   -->

   ```

   메모 본문이 공백뿐이면 빈 본문으로 쓴다
4. 본문이 줄바꿈으로 끝나지 않으면 하나 붙인다 (빈 본문은 줄바꿈 한 개)
5. 상위 디렉터리가 없으면 만들고 파일을 쓴다. 쓰기 전 내용(파일이 없었으면 없음)을 기억한다
6. `harness render` 와 같은 렌더를 돈다
7. 렌더가 실패하면 파일을 쓰기 전 상태로 되돌린다(없던 파일은 지운다). 표준 오류에
   `reverted — the document is unchanged` 를 내고 종료 코드 2 로 끝난다

### 2-3. 출력과 종료 코드

- 성공: 표준 출력에 `write-doc: <쓴 경로>` 한 줄, 이어서 렌더 출력. 종료 코드 0
- 거절(모르는 이름 · 두 번째 인수가 `-` 가 아님 · 설정 오류) · 렌더 실패: `error:` · `-->` · `help:` 형식의 영어 안내를 표준 오류로
  내고 종료 코드 2. 모르는 이름이면 `help:` 가 받는 이름 목록(문서 이름, `roles/<역할>`, `workflows/<절차>`)을 보인다
- 터미널 출력은 영어다

### 2-4. 등록

- `COMMANDS` 표에 `write-doc` 을 더한다. 인수 표기는 `<name> -`, 설명은 표준 입력의 본문을 프로젝트 문서나 역할·절차 메모에
  쓰고 render 한다는 것
- `DELEGATES` 에 더한다 — 프로젝트에 고정된 사본이 받는 이름 목록과 렌더를 갖고 있다

## 3. `harness fix <조치>`

Doctor 화면의 ▷ 조치 가운데 CLI 명령이 없던 둘을 명령으로 둔다.

| 조치 | 하는 일 | 종료 코드 |
|---|---|---|
| `hooks` | `harness install` 이 git 훅 경로(`core.hooksPath`)를 설정하는 로직(#60)을 그대로 부른다. 모노레포의 경로 접두와 기존 `.git/hooks` 훅이 있을 때 설정하지 않는 판정도 그 로직의 것이다. 설정했으면 그 사실을, 이미 맞는 값이면 그 사실을, 설정하지 않았으면 그 이유를 표준 출력·오류로 낸다 | 설정함·이미 맞음 0 · 설정하지 않음 2 |
| `verify` | 검증 스크립트를 하네스 루트에서 `bash` 로 돌린다. 스크립트는 5절 `verify_script` 와 같다 — 채운 옛 검증 스크립트(`legacy_verify`)가 있으면 `script/verify-project.sh`, 아니면 `script/harness-verify.sh`. 표준 출력·오류를 그대로 흘린다 | 스크립트의 종료 코드 |

- 훅 경로를 설정하는 코드는 install 의 것 하나뿐이다. `fix hooks` 는 그것을 호출할 뿐 따로 판정하지 않는다
- 위 둘이 아닌 조치나 빠진 인수는 사용법을 표준 오류로 내고 종료 코드 2
- `COMMANDS` 표와 `DELEGATES` 에 더한다 — 훅 경로와 검증 스크립트는 프로젝트에 고정된 버전이 안다

## 4. `harness install --create [--git-init]`

새 프로젝트 만들기가 CLI 한 번으로 끝난다.

| 옵션 | 하는 일 |
|---|---|
| `--create` | `--target` 디렉터리가 없으면 상위 디렉터리까지 만든다. 이미 있으면 아무것도 하지 않는다 |
| `--git-init` | `--target` 아래에 `.git` 이 없으면 `git init -q` 를 그 디렉터리에서 돈다. 있으면 아무것도 하지 않는다 |

- `--create` 없이 `--target` 이 없는 경로면 `error: target directory does not exist` 와 `--create` 를 쓰라는 `help:` 를 내고
  종료 코드 2. 아무것도 만들지 않는다
- 디렉터리를 만들기 전에 등록 판정(같은 이름의 거부)을 돈다. 판정에 쓰는 이름은 대상에 `harness.toml` 이 있으면 그
  `project.name`, 없으면 설정을 새로 깔 때 채울 이름(디렉터리 이름)이다. 거부면 디렉터리·`.git`·`harness.toml` 중 어느 것도
  만들지 않고, 기존 거부 안내문을 그대로 내고 종료 코드 2
- 판정부터 등록까지는 기존 install 과 같은 등록부 잠금 안에서 한 구역이다
- 순서: 판정 → 디렉터리 생성 → `git init` → 기본 설정 깔기 → 기존 install(고정 사본 · 등록 · render)
- `--git-init` 은 `--create` 없이도 받는다 — 이미 있는 디렉터리에 git 을 시작한다
- install 은 `DELEGATES` 에 없으므로 이 옵션은 전역 CLI 가 처리한다

## 5. `harness schema` 의 새 키

기존 키는 그대로다. 아래를 더한다. 경로는 하네스 루트 기준 상대 경로다.

| 키 | 값 |
|---|---|
| `docs` | `{ "<문서>": { "path": ".ai/project/<문서>.md", "template": "<원형 경로>" } }`. 문서는 2-1 의 `<문서>` 목록과 같다 |
| `workflows.<절차>.path` | 생성된 절차 문서 `.ai/workflows/<절차>.md` |
| `verify_script` | `fix verify` 가 돌리는 스크립트 경로 (3절) |
| `hooks_path` | install 의 훅 경로 설정 로직(#60)이 `core.hooksPath` 에 넣는 값. 모노레포 접두가 붙은 값이다 |
| `config_notes` | `{ "<절>.<키>": "<설명>" }` — 대상 `harness.toml` 의 주석 (5-1) |
| `base_protected` | 설정에서 빠져도 늘 보호하는 기준 문서 목록. CLI 의 `BASE_PROTECTED` 그대로, 같은 순서다 |

- `template` 은 그 명령을 실제로 답한 하네스의 원형이다. 고정 사본이면 `.harness/templates/owned/.ai/project/<문서>.md`,
  소스 리포면 `src/templates/owned/.ai/project/<문서>.md`. 원형이 하네스 루트 밖에 있으면(고정 사본이 없어 전역 CLI 가 답했다)
  절대 경로다
- 이미 있는 `legacy_verify` · `roles.<역할>.notes` · `workflow_notes` 를 UI 가 쓴다. 같은 판정을 UI 에 다시 두지 않는다
- `docs` 키가 있는 사본은 `write-doc` 과 `fix` 도 갖는다. UI 는 이 키의 유무로 사본이 새 명령을 아는지 가른다 (7-3)
- 문서 목록은 탭 목록이 아니다. schema 는 이름·경로·원형 경로만 낸다 — 제목·안내문·질문 양식은 내지 않는다

### 5-1. `config_notes`

키 바로 위의 주석 줄을 그 키의 설명으로 읽는다.

- 절 머리 `[<절>]` 을 만나면 절 이름을 바꾸고 모은 주석을 비운다. 점이 든 절(`[roles.developer]`)은 그 이름 그대로다
- `#` 로 시작하는 줄은 `#` 와 그 뒤 공백 한 칸을 떼고 모은다. 떼고 난 내용이 `─` 로만 된 줄은 버린다
- `<키> =` 줄을 만나면 모은 주석이 있을 때 `"<절>.<키>"` 에 줄바꿈으로 이어 앞뒤 공백을 걷어 넣고, 모은 것을 비운다
- 빈 줄을 만나면 모은 것을 비운다
- 키 이름은 영문자·숫자·`_`·`-` 다

## 6. `write-doc` 이 보호 문서를 대상으로 하는 호출 막기

`write-doc` 을 부르는 쪽은 UI 다. 에이전트가 이 명령으로 보호 문서를 고치는 것은 셸 편집과 같은 금지 행위이므로
같은 층(명령 가드 · 권한 deny)이 막는다.

### 6-1. 명령 가드 — `guard_write_doc`

`_guards.sh` 에 함수를 더하고 `bash-guard.sh` 가 `guard_arch_docs` 다음에 부른다. 사용 기록 라벨은 `arch-doc` 이다.

- `invocations_at harness` 로 명령 자리의 호출만 본다. `harness`, `.harness/bin/harness`, `src/bin/harness` 와 `/harness` 로 끝나는
  경로(`./src/bin/harness` · 절대 경로)가 여기 걸린다. 앞선 명령의 인수로 적힌 말(`echo harness write-doc scope`)은 호출이 아니다
- 인수에서 옵션을 걷어 첫 위치 인수를 명령으로 본다. 값을 다음 토큰으로 받는 옵션(`--target` · `--rename` · `--since` · `--trace`)은
  그 값까지 걷고, `--target=<값>` 꼴과 나머지 `-` 로 시작하는 토큰은 그 토큰만 걷는다
- 명령이 `write-doc` 이면 그 다음 위치 인수가 이름이다. `.ai/project/<이름>.md` 가 `PROTECTED_DOCS_RE` 에 앞머리부터 맞으면
  (`^(<PROTECTED_DOCS_RE>)`) 막는다. 역할 메모·절차 메모는 기본 보호 목록의 `.ai/project/roles/` · `.ai/project/workflows/` 로 걸린다
- 이름이 셸 확장(`$` · 백틱 · glob)을 담아 풀 수 없거나 없으면 통과시킨다 — 가드는 미탐을 허용하고 오탐을 피한다
- 차단 사유와 안내는 영어다

```
blocked: writing a protected document through harness write-doc
agents read these documents as ground truth — if a request conflicts with one, report it instead of editing
help: this command is for the UI; if the user explicitly asked for this edit, they make it themselves
```

### 6-2. 권한 deny — `deny_rules()`

`docs.protected` 의 항목마다, 그 항목이 `write-doc` 이름으로 닿는 범위를 deny 로 만든다. 세 호출 형태
(`harness` · `.harness/bin/harness` · `src/bin/harness`)마다 한 줄씩이다.

| 보호 항목 | deny 규칙 (`<H>` 는 세 호출 형태) |
|---|---|
| `.ai/project/<이름>.md` | `Bash(<H> write-doc <이름>:*)` |
| `.ai/project/<하위>/` · `.ai/project/<하위>/**` | `Bash(<H> write-doc <하위>/:*)` |
| `.ai/project/` 전체를 덮는 디렉터리(`.ai/project/` · `.ai/**` 등) | `Bash(<H> write-doc:*)` |
| 그 밖(`.ai/project/` 밖의 경로 · `.md` 가 아닌 파일) | 없음 — `write-doc` 이 쓰지 못하는 경로다 |

- 기존 `Edit(...)` 규칙은 그대로 둔다
- deny 는 보조다. `--target` 을 이름 앞에 둔 호출 같은 표기 차이는 6-1 가드가 잡는다

### 6-3. 허용 목록

절차가 부르는 명령의 허용 목록(#70)에 `harness write-doc` 을 넣지 않는다. 절차의 어느 단계도 이 명령을 부르지 않는다.

## 7. UI

### 7-1. `src/ui/lib/harness.js`

| 함수 | 바뀌는 것 |
|---|---|
| `harness(dir, args, { input })` | `input` 이 있으면 자식 프로세스의 표준 입력으로 넘긴다. `--target` 을 붙이는 규칙과 반환 모양(`{ ok, out }`)은 그대로다 |
| `readDoc(dir, schema, doc)` | `schema.docs[doc].path` 를 읽는다. schema 에 없는 문서면 빈 문자열 |
| `readDocTemplate(dir, schema, doc)` | `schema.docs[doc].template` 을 읽는다(절대 경로면 그대로, 상대 경로면 `dir` 기준). 없으면 빈 문자열 |
| `listWorkflows(dir, schema)` | `schema.workflows.<절차>.path` 를 읽는다. 디렉터리를 나열하지 않는다 |
| `docPath` · `writeDoc` · `writeRoleNotes` · `readConfigNotes` | 지운다. 설정 주석이 필요한 곳은 `schema.config_notes` 를 쓴다 |

- `fields.js` 의 `DOCS` 를 import 하지 않는다. 이 파일은 경로를 알지 않는다

### 7-2. `src/ui/lib/actions.js`

| 액션 | 부르는 것 |
|---|---|
| `saveDoc(project, doc, text)` | `harness write-doc <doc> -` (본문은 표준 입력). 별도 render 호출을 지운다 |
| `saveRoleNotes(project, role, text)` | `harness write-doc roles/<role> -`. 머리 주석 붙이기(`NOTES_HEAD`)를 지운다 |
| `saveWorkflowNotes(project, wf, text)` | `harness write-doc workflows/<wf> -`. 머리 주석 붙이기(`WF_HEAD`)를 지운다 |
| `doctorFix(project, kind)` | 조치 종류 하나를 받는다(7-5 의 표가 고른 것). `hooks` → `harness fix hooks`, `verify` → `harness fix verify`, `render` → `harness render`, `upgrade` → `harness install`. 그 밖의 종류는 지금처럼 거절한다. `git` · `bash` 를 직접 실행하는 내부 함수와 `legacyVerify` 를 지운다 |
| `createProject(dir, gitInit)` | `harness install --create [--git-init] --target <dir>`. `fs.mkdir` · `git init` 직접 실행과 같은 이름 사전 검사를 지운다 — 거부는 CLI 안내문을 그대로 돌려준다 |
| `completeDoc(project, doc, values)` | 원형·현재 파일을 7-1 의 함수로 읽고, 프롬프트의 문서 경로를 `schema.docs[doc].path` 로 적는다 |

- `createProject` 의 입력 좁히기(절대 경로 · `.`/`..` 없음 · 홈 디렉터리 안쪽 · 등록부 밖)는 UI 요청을 받는 자리의 검사라 그대로 둔다
- 문서 이름·역할·절차 이름은 UI 가 먼저 거르지 않고 CLI 의 거절을 그대로 돌려준다. 역할·절차 존재 확인용 schema 조회를 지운다

### 7-3. 옛 고정 사본

`schema` 에 `docs` 키가 없으면 그 프로젝트의 고정 사본은 `write-doc` · `fix` 를 모른다.

- Project Settings 의 문서 탭, Agents 의 메모, Workflows 의 절차 메모는 편집·저장 대신 재설치 안내를 보인다 —
  그 프로젝트에서 `harness install` 을 다시 돌린다
- Doctor 의 `hooks` · `verify` ▷ 조치도 같은 안내를 보인다. `render` · `upgrade` 는 그대로 돈다
- Harness 화면의 보호 문서 목록(`PathList`)은 편집·저장 대신 같은 안내를 보인다 (7-7)
- schema 자체를 받지 못하는 사본은 지금의 처리를 따른다

### 7-4. 화면이 보이는 경로

| 화면 · 파일 | 보이는 값 |
|---|---|
| `DocEditor` 의 문서 경로 | `schema.docs[doc].path` |
| `FlowCanvas` 의 생성된 절차 문서 경로 | `schema.workflows.<절차>.path` |
| `FlowCanvas` 의 절차 삭제 확인 문구의 메모 경로 | `schema.workflow_notes.<절차>` |
| `CommandsEditor` 의 옛 검증 스크립트 안내 | `schema.verify_script` (`legacy_verify` 가 참일 때) |
| `doctor.js` `explain()` 의 ▷ 조치에 보이는 명령 | `verify` → `bash <schema.verify_script>`, `hooks` → `git config core.hooksPath <schema.hooks_path>`, `render` → `harness render` |

- `explain(i, base, schema)` 로 schema 를 받는다. schema 가 없으면(옛 사본) `verify` · `hooks` 의 보일 명령 자리를 비운다

### 7-5. Doctor 조치 고르기

doctor 항목은 #59 가 정한 `{section, state, what, detail}` 넷이고 조치 키가 없다. #59 가 `harness status` 의 JSON 키 구조와
항목의 네 키를 유지하므로 이 명세도 항목에 키를 더하지 않는다. `explain()` 이 아래 표로 조치 종류를 고르고, ▷ 는 그 종류를
`doctorFix` 에 넘긴다. `section` 까지 맞아야 고른다 — 다른 절의 같은 문구에 조치가 붙지 않는다.

| `section` | `what` | 조건 | 조치 |
|---|---|---|---|
| `verification` | `script/harness-verify.sh` | `state` 가 `ok` 가 아니고 `detail` 이 `not set up` 으로 시작하지 않는다 | `verify` |
| `verification` | `script/verify-project.sh (hand-written)` | `state` 가 `ok` 가 아니다 | `verify` |
| `verification` | `script/verify-project.sh` (옛 사본의 줄) | `state` 가 `ok` 가 아니다 | `verify` |
| `git` | `git hooks enabled` | `state` 가 `ok` 가 아니다 | `hooks` |
| `generated files` | `<N> files differ from the config` | — | `render` |
| `tools and connections` | ``adapter `<kind>` `` | `detail` 이 `file is missing` | `render` |

- `upgrade` 는 지금처럼 `DoctorView` 가 고정 버전과 전역 버전을 비교해 목록 앞에 더하는 UI 쪽 항목이 싣는다. doctor 항목이 아니므로 이 표의 대상이 아니다
- 표의 `what` · `detail` 문구는 CLI 의 영어 고정 문구다. 문구를 바꾸는 쪽은 이 표와 `doctor.test.js` 를 함께 고친다
- 표에 없는 항목에는 ▷ 조치가 없다. 안내(`href` · `cmd`)는 지금의 `explain()` 그대로다

### 7-6. `src/ui/lib/fields.js`

- `DOCS` 는 탭 구성과 탭마다의 제목·안내·질문 양식만 갖는다. 문서 경로를 갖지 않는다
- 탭 키 가운데 `commands` 는 설정 편집 탭(`CommandsEditor`)이고 `write-doc` 대상이 아니다. 그 밖의 탭 키가 `schema.docs` 에
  없으면 그 탭은 7-3 의 재설치 안내를 보인다

### 7-7. 보호 문서 목록 — `paths.js` · `PathList`

- `paths.js` 의 `BASE_PROTECTED` 상수를 지운다. 기준 문서 목록은 `schema.base_protected` 에서 받는다
- Harness 화면(`settings/page.js`)이 schema 의 `base_protected` 를 `ValueField` 를 거쳐 `PathList` 에 넘긴다.
  `PathList` 는 클라이언트 컴포넌트라 schema 를 직접 읽지 않는다
- `PathList` 는 받은 목록을 고정 행(지울 수 없음)으로 보이고, 설정 값에서 그 목록을 뺀 나머지를 편집 행으로 보인다.
  추가 검사(`pathProblem`)와 저장 값은 받은 목록과 편집 행을 합친 것이다
- 설정 값에서 기준 목록을 빼는 일은 `paths.js` 의 순수 함수 `ownPaths(value, base)` 가 한다 — 순서를 유지하고 `base` 에 있는 항목만 뺀다
- `schema` 에 `docs` 키가 없으면(7-3) `PathList` 는 재설치 안내를 보이고 저장하지 않는다
- 경로 모양 검사(`pathProblem` · `dirProblem`)는 추가 전에 미리 보이는 검사로 남는다. 저장 때 CLI `validate()` 가 다시 검사한다

## 8. README

| 절 | 적는 사실 |
|---|---|
| "명령" 표 | `harness write-doc <이름> -` — 표준 입력의 본문을 `.ai/project/` 문서나 역할·절차 메모에 쓰고 render 한다. UI 가 쓰는 명령이고, 에이전트가 보호 문서를 대상으로 부르면 가드가 막는다. `harness fix hooks\|verify` — Doctor 조치: 훅 경로 설정, 검증 다시 돌리기. `harness install` 행에 `--create`(디렉터리 생성) · `--git-init` |
| "명령" 표의 `harness schema` 행 | 문서·원형·절차 문서 경로, 검증 스크립트·훅 경로, 설정 주석, 기본 보호 문서 목록도 낸다. UI 는 경로와 목록을 이것에서 받는다 |
| "UI" 표의 쓰기 경로 | Project Settings: `harness write-doc` · `harness set` · `harness checks`. Agents: `harness write-doc` · `harness set`. Doctor: `harness status` · `harness fix` · `harness render` · `harness install` |
| "UI" 본문 | UI 는 파일을 직접 쓰지 않는다 — 문서·메모 저장, Doctor 조치, 새 프로젝트 만들기도 CLI 명령이다. 고정 사본이 이 명령을 모르면 재설치를 안내한다 |

## 9. 회귀 테스트

### 9-1. `render-test.sh` — 새 UT 블록

번호는 구현 시점의 다음 번호를 쓴다.

**write-doc**

| 케이스 | 확인하는 것 |
|---|---|
| 문서 쓰기 | `printf 'x' \| harness write-doc stack -` 가 종료 코드 0. `.ai/project/stack.md` 가 `x\n` 이고 `.ai/AI_AGENT.md` 가 그 본문을 담는다. 이어서 `harness check` 가 통과한다 |
| 역할 메모 | `roles/developer` 로 쓰면 `.ai/project/roles/` 가 없던 리포에도 파일이 생기고, 본문 앞에 역할 머리 주석이 붙으며, `.claude/agents/developer.md` 가 본문을 담는다. `<!--` 로 시작하는 본문에는 머리 주석을 붙이지 않는다. 공백뿐인 본문은 줄바꿈 한 개다 |
| 절차 메모 | `workflows/work` 로 쓰면 절차 머리 주석이 붙고 `.ai/workflows/work.md` 가 본문을 담는다 |
| 거절 | `commands` · `../x` · `stack.md` · `roles/없는역할` · `workflows/없는절차` · 두 번째 인수가 `-` 가 아닌 호출이 각각 종료 코드 2 이고, 어떤 파일도 생기거나 바뀌지 않는다. 모르는 이름의 안내에 받는 이름 목록이 있다 |
| 렌더 실패 되돌림 | 생성 파일 자리 하나에 디렉터리를 두어 render 가 실패하게 하면 종료 코드 2, 표준 오류에 `reverted`, 문서가 쓰기 전 본문이다. 없던 메모 파일은 남지 않는다 |
| 위임 | 고정 사본이 있는 리포에서 전역 CLI 로 부르면 고정 사본이 답한다 (`DELEGATES`) |

**fix**

| 케이스 | 확인하는 것 |
|---|---|
| `fix verify` | 명령을 정한 리포에서 종료 코드 0, 실패하는 명령을 둔 리포에서 0 이 아니다. 채운 `script/verify-project.sh` 가 있으면 그것이 돈다 |
| `fix hooks` | 훅 경로가 빈 리포에서 설정되고 종료 코드 0. install 이 설정하지 않는 조건(#60)에서는 설정하지 않고 종료 코드 2 |
| 모르는 조치 | 종료 코드 2 |

**install --create · --git-init**

| 케이스 | 확인하는 것 |
|---|---|
| 새 디렉터리 | 없는 경로에 `--create --git-init` 이면 디렉터리 · `.git` · `harness.toml` 이 생기고 등록부에 그 경로가 등록된다 |
| `--create` 없음 | 없는 경로면 종료 코드 2, 경로가 생기지 않는다 |
| 이름 거부 | 같은 이름이 다른 경로에 살아 있을 때 `--create` 로 새 경로를 주면 종료 코드 2, 경로가 생기지 않고 등록부가 그대로다 |
| 기존 `.git` | `.git` 이 있는 디렉터리에 `--git-init` 이면 `git init` 을 돌지 않는다(기존 커밋이 그대로다) |

**schema**

| 케이스 | 확인하는 것 |
|---|---|
| `docs` | 키가 원형의 `.ai/project/*.md` 목록과 같고 `commands` 가 없다. 각 `path` 가 `.ai/project/<문서>.md` 이고 `template` 이 가리키는 파일이 있다 — 고정 사본 리포와 소스 트리 복제본 둘 다 |
| 경로 키 | `workflows.<절차>.path` 가 있는 파일을 가리킨다. `verify_script` 가 옛 검증 스크립트 유무에 따라 바뀐다. `hooks_path` 가 install 이 설정하는 값과 같다 |
| `config_notes` | 주석을 단 키가 그 주석을 값으로 갖고, `─` 구분선 줄이 빠지며, 빈 줄로 떨어진 주석은 붙지 않는다. 점이 든 절의 키는 `roles.developer.runner` 꼴이다 |
| `base_protected` | CLI 의 `BASE_PROTECTED` 와 같고 `.ai/project/workflows/` 를 담는다. `docs.protected` 를 비운 설정에서도 같다 |

**deny**

| 케이스 | 확인하는 것 |
|---|---|
| 기본 보호 목록 | `.claude/settings.json` deny 에 세 호출 형태마다 `write-doc scope:*` · `write-doc roles/:*` · `write-doc workflows/:*` 가 있고 `write-doc stack:*` 가 없다 |
| 설정 변경 | `docs.protected` 에 `.ai/project/stack.md` 를 더하면 `write-doc stack:*` 가 생기고, `.ai/project/` 밖의 경로를 더하면 `write-doc` 규칙이 늘지 않는다 |

터미널 출력의 한글 검사는 이 블록의 출력에도 적용한다.

### 9-2. `test-bash-guard.sh`

보호 이름은 `PROTECTED_DOCS_SAMPLE` 에서 `.ai/project/` 와 `.md` 를 뗀 값, 보호되지 않은 이름은 `stack` · `environment` ·
`review-checks` 가운데 `PROTECTED_DOCS_RE` 에 걸리지 않는 첫 이름이다. 값을 표에 박지 않는다.

| 기대 | 명령 |
|---|---|
| 차단 | `harness write-doc <보호> -` · `.harness/bin/harness write-doc <보호> -` · `src/bin/harness write-doc <보호> -` · `./src/bin/harness write-doc <보호> -` · `harness --target . write-doc <보호> -` · `harness write-doc --target . <보호> -` · `harness write-doc roles/<역할> -` · `harness write-doc workflows/work -` · `cd x && harness write-doc <보호> -` · `printf x \| harness write-doc <보호> -` |
| 통과 | `harness write-doc <보호되지 않은> -` · `harness schema` · `harness render` · `echo harness write-doc <보호>` · `grep write-doc README.md` |

- 새 차단 케이스를 가드를 망가뜨린 사본 검사에 넣는다 — `guard_write_doc` 을 무력화하면 이 케이스들만 통과로 뒤집히고
  나머지 계열은 차단 그대로다

### 9-3. `doctor.test.js`

- `explain()` 에 schema(`verify_script` · `hooks_path`)를 주면 `verify` 조치의 보일 명령이 `bash <verify_script>`, `hooks` 조치가
  `git config core.hooksPath <hooks_path>` 다. 모노레포 접두가 든 `hooks_path` 가 그대로 들어간다
- schema 를 주지 않으면 조치 종류는 남고 `verify` · `hooks` 의 보일 명령이 비어 있다
- 7-5 표의 행마다 `{section, state, what, detail}` 항목 하나를 주면 `explain()` 이 그 조치 종류를 고른다. 같은 `what` 을 다른 `section` 으로
  주면 조치가 없다. `script/harness-verify.sh` 의 `detail` 이 `not set up — no commands yet` 이면 조치가 없고 명령 탭 링크가 있다
- 항목에 네 키 밖의 키가 없어도 위가 성립한다 — 테스트 입력에 조치 키를 넣지 않는다

### 9-4. `paths.test.js`

- `ownPaths` 가 기준 목록에 있는 항목만 빼고 순서를 유지한다. 기준 목록이 비면 값 그대로다
- 기존 `pathProblem` · `dirProblem` 케이스는 그대로 통과한다

## 10. 보호 문서에 반영할 것

사람이 지시한 턴에 반영한다.

| 문서 · 위치 | 반영할 사실 |
|---|---|
| `.ai/project/scope.md` "할 수 있는 일" | 프로젝트 문서와 역할·절차 메모를 CLI 로 쓰고 생성물을 따라 바꾼다(`write-doc`). Doctor 조치를 CLI 로 돈다(`fix`) |
| `.ai/project/architecture.md` "구성 요소" 의 `src/bin/harness` | 명령 나열에 `write-doc` · `fix` |
| `.ai/project/architecture.md` "구성 요소" 의 `src/ui/` | 문서·메모 저장, Doctor 조치, 새 프로젝트 만들기도 CLI 명령을 부른다. 파일 경로는 `harness schema` 에서 받는다 |

## 11. 다른 이슈와의 관계

| 이슈 | 관계 |
|---|---|
| #59 | doctor 결과를 `{section, state, what, detail}` 항목 목록으로 낸다. 이 명세보다 먼저 구현되고, `explain()` 이 그 네 키로 조치를 고른다 (7-5). 항목 구조는 바꾸지 않는다 |
| #60 | install 에 훅 경로 설정 로직을 넣는다. 이 명세보다 먼저 구현되고, `fix hooks` 와 schema `hooks_path` 가 그 로직을 부른다 |
| #70 | 절차 명령의 허용 목록을 만든다. 그 목록에 `harness write-doc` 은 없다 (6-3) |
| #96 | `src/ui/lib/harness.js` 를 함께 고친다. 이 명세가 먼저 구현된다 |

## 12. 한계

- 명령 가드는 `python3 src/bin/harness write-doc …` 처럼 인터프리터를 앞에 둔 호출과 셸 확장으로 적은 이름을 판정하지 않는다.
  deny 도 그 표기를 덮지 않는다
- `write-doc` 은 저장 전 검사(정적 · 모델)를 하지 않는다. 검사는 UI 가 저장 전에 하고, 저장할지는 사람이 정한다
