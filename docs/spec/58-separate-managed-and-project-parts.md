# 관리 부품과 프로젝트 부품의 경계, 관리 파일 변조 감지

대상 리포에서 하네스 것과 프로젝트 것의 자리를 나눈다. 프로젝트 스크립트는 `script/project/` 에 두고,
하네스가 쓸 경로에 이미 있는 사용자 파일은 덮지 않고 멈춘다. `.harness/managed` 는 관리 파일과 고정 사본의
sha256 을 담고, `check`·`doctor` 는 그것과 대조해 바뀐 관리 파일을 보고한다. 전역 CLI 는 고정 사본으로 넘기기 전에
같은 버전의 자기 파일과 사본을 대조한다. 하네스가 대상 리포를 바꾸는 지점은 전부 경로 규칙을 지키는 공용 함수 하나를 거치고,
매니페스트는 읽을 때마다 그 규칙으로 검증한다(11절).

정본 위치:

| 대상 | 정본 |
|---|---|
| 충돌 판정 · 매니페스트 읽기·쓰기(`previous()` · `prune()` · `cmd_render` · `cmd_install`) · `cmd_check` · `cmd_doctor` · `delegate()` | `src/bin/harness` |
| 경로 규칙 · 공용 함수 `guarded_path()` · 사전 판정 · 매니페스트 검증(11절), 그것을 거치는 `copy_tree()` · `cmd_render` · `prune()` · `install_registered()` · `seed_config()` · `cmd_uninstall` · `rename_or_delete_workflow()`(`steps --rename`) | `src/bin/harness` |
| 프로젝트 스크립트 표 | `src/templates/owned/script/project/README.md` (새 소유 파일) |
| 규칙 문서 3·9·10장 문구 | `src/templates/generated/.ai/AI_AGENT.md` |
| 하네스 스크립트 표 | `src/templates/managed/script/README.md` |
| 문서 정리자 계약 | `src/templates/managed/.ai/templates/docs-writer.md` |
| 사람용 설명 | `src/templates/managed/docs/workflow/changing.md` · `README.md` |
| UI doctor 문구 | `src/ui/lib/doctor.js` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/ui/lib/doctor.test.js` |
| 매니페스트를 들어오는 입력으로 적는 문장 | `.ai/project/architecture.md` "신뢰 경계"(8절) |

## 1. 프로젝트 스크립트 자리 — `script/project/`

### 1-1. 자리

- `script/project/` 는 프로젝트 것이다. 하네스는 그 안에 소유 파일 `script/project/README.md` 하나만 깔고(없을 때만),
  나머지 파일을 만들지도 덮지도 지우지도 않는다
- `src/templates/managed/` 와 `src/templates/generated/`, `plan()` 은 `script/project/` 아래 경로를 만들지 않는다.
  회귀 테스트가 이 불변식을 본다(7절)
- `script/` 바로 아래(와 `script/project/` 를 뺀 하위 디렉터리)는 하네스 것이다 — 관리 파일과 생성 파일의 자리다
- 이미 `script/` 루트에 있는 프로젝트 스크립트는 옮기지 않는다. 하네스가 같은 이름의 파일을 들이려 하면 3절의 충돌 판정이 멈춘다
- 하네스는 `script/project/` 의 스크립트를 부르지 않는다. 검증에 넣으려면 `harness.toml` 의 `[verify]`·`[commands]` 에 적는다

### 1-2. `script/project/README.md` 원형

`src/templates/owned/script/project/README.md` 에 둔다. 담는 것:

- 이 디렉터리는 프로젝트 것이고 하네스 갱신이 건드리지 않는다는 것
- 하네스 스크립트는 `script/README.md` 에 있고, `script/` 바로 아래에 두면 하네스 갱신과 겹칠 수 있다는 것
- 빈 스크립트 표 — 열은 `스크립트 | 용도 | 호출 시점`. 표 아래에 "스크립트를 추가하면 이 표에 한 줄 추가한다" 한 줄
- `TBD` 자리표시자를 넣지 않는다 — doctor 의 `project facts` 절이 소유 파일 원형 전부를 자리표시자로 검사한다

### 1-3. 함께 고치는 문구

| 파일 · 위치 | 바꾼 뒤의 사실 |
|---|---|
| `src/templates/generated/.ai/AI_AGENT.md` 3장 끝 문단 | 프로젝트 자동화 스크립트는 `script/project/` 에 두고 `script/project/README.md` 표에 한 줄 추가한다. `script/` 바로 아래는 하네스 것이라 갱신이 덮는다 |
| 같은 파일 9장 문서 지도 | `script/README.md` 행: 하네스 스크립트를 실행할 때. 새 행 `script/project/README.md`: 프로젝트 스크립트를 추가·실행할 때 |
| 같은 파일 10장 하네스 배치 | 새 행 `script/project/` — **소유** — 프로젝트가 쓰고 하네스 갱신이 건드리지 않는다. `script/` 가 있는 관리 행은 `script/project/` 를 뺀 나머지임을 적는다 |
| `src/templates/managed/script/README.md` 부류 표 | **소유** 행 추가: `project/` — 프로젝트 것이다. 표는 `script/project/README.md` 에 적는다. 끝의 "새 스크립트는 위 표에 한 줄 추가한다" 는 하네스 스크립트에 대한 것임을 밝히고, 프로젝트 스크립트는 `script/project/` 와 그 README 로 보낸다 |
| `src/templates/managed/.ai/templates/docs-writer.md` 2단계 | "스크립트가 늘었으면" 줄: 프로젝트 스크립트면 `script/project/README.md` 표에 한 줄 추가한다. `script/README.md` 는 관리 파일이라 고치면 갱신이 덮는다 |
| `src/templates/managed/docs/workflow/changing.md` "프로젝트가 쓰는 것 (소유 파일)" 표 | 새 행: 프로젝트 자동화 스크립트 → `script/project/` 와 `script/project/README.md` |
| `README.md` "파일은 세 부류다" 표 | **소유** 행에 `script/project/README.md` 를 더하고, **관리** 행의 `script/` 의 나머지에서 `script/project/` 를 뺀다. 표 아래에 한 문단: 하네스가 쓸 경로에 이미 있는 파일은 덮지 않고 멈추며 `--adopt` 로 넘겨받는다(3절), `check`·`doctor` 가 바뀐 관리 파일을 보고한다(4절) |
| `README.md` "명령" 표의 `check` · `doctor` 행 | `check`: 생성 파일이 설정과, 관리 파일이 매니페스트와 일치하는지. `doctor` 설명에 관리 파일 변조를 더한다 |
| `.ai/project/review-checks.md` (이 리포, 보호 문서 아님) | "관리 스크립트를 더했으면" 점검이 가리키는 표를 `src/templates/managed/script/README.md` 로 적는다 — 이 리포의 `script/README.md` 는 설치된 사본이라 직접 고치면 4절 검사에 걸린다 |

## 2. 매니페스트

### 2-1. 형식

| 파일 | 줄 형식 | 담는 것 |
|---|---|---|
| `.harness/generated` | `<경로>` | 지난 render 가 만든 생성 파일. 형식은 바뀌지 않는다 |
| `.harness/managed` | `<sha256>  <경로>` | 지난 render 가 깐 관리 파일, 그리고 고정 사본(2-2) |

- `<sha256>` 은 파일 바이트의 sha256 소문자 16진 64자, 그 뒤 공백 두 칸, 하네스 루트 기준 상대 경로. `sha256sum` 출력과 같은 형식이다
- 줄은 경로 순으로 정렬하고 LF 로 끝낸다

### 2-2. `.harness/managed` 가 담는 것

| 줄 | 해시의 출처 | 쓰는 명령 |
|---|---|---|
| 관리 파일 (`src/templates/managed/` 에서 깐 것) | render 가 그 경로에 쓴 내용 | render |
| 고정 사본 — `.harness/bin/` · `.harness/templates/` 아래 파일 전부와 `.harness/VERSION`. `__pycache__/` 는 뺀다 | install 이 사본을 깐 직후의 파일 | install |

- install 은 사본을 깐 직후 고정 사본 줄을 매니페스트에 넣는다
- render 는 매니페스트를 다시 쓸 때 관리 파일 줄을 새로 계산하고, `.harness/` 로 시작하는 줄은 이전 매니페스트에서 그대로 옮긴다.
  render 는 고정 사본의 해시를 계산하지 않는다 — 계산하면 고친 사본의 해시가 기록된다
- `.harness/bin/harness` 가 없는 하네스 루트(소스 리포)에서는 고정 사본 줄을 쓰지 않는다. 이전 매니페스트에 있어도 옮기지 않는다

### 2-3. 읽기 — `previous()`

매니페스트는 **신뢰하지 않는 입력**이다. 커밋된 파일이라 누구든 고칠 수 있고 병합이 충돌 표지를 남길 수 있다.
읽을 때마다 줄마다 11-2 의 경로 규칙으로 검증하고, 어긋난 줄은 11-5 대로 다룬다. 어긋난 줄의 경로는 열지도 바꾸지도 않는다.

`previous()` 는 두 형식을 모두 읽고 경로 목록을 돌려준다. 판정 전에 줄 끝의 CR 하나를 뗀다.

| 줄 | 경로 | 해시 |
|---|---|---|
| `^[0-9a-f]{64}  (.+)$` 에 맞는다 | 두 번째 부분. 11-2 를 지켜야 한다 | 첫 번째 부분 |
| 그 밖의 비어 있지 않은 줄 (옛 형식) | 줄 전체(앞뒤 공백 제거). 11-2 를 지켜야 한다 | 없음 |
| 빈 줄(공백뿐인 줄 포함) | 건너뛴다 | — |

- 경로와 해시의 짝이 필요한 쪽(4절 · 3절)은 같은 규칙으로 읽는 별도 함수를 쓴다. `prune()` · `cmd_uninstall` · 충돌 판정은 경로만 쓴다
- 두 함수 모두 검증을 거친 줄만 돌려주고, 어긋난 줄은 매니페스트 이름 · 줄 번호(1부터) · 사유로 따로 돌려준다(11-5)
- 옛 형식 매니페스트는 render 가 다음에 쓸 때 새 형식이 된다
- 옛 하네스 사본이 새 형식을 읽으면 해시 토큰을 경로로 보고, 그 경로에 파일이 없으므로 `prune()` · `uninstall` 이 건너뛴다

### 2-4. 정리와 설치에서의 매니페스트

- `prune()` 은 `.harness/` 로 시작하는 경로를 지우지 않는다. 지우는 파일과 걷는 빈 부모 디렉터리는 11-3 의 공용 함수를 거친다
- `cmd_install` 은 `.harness/` 를 새 사본으로 갈아 끼울 때 `.harness/generated` · `.harness/managed` 를 남긴다.
  고정 사본 줄만 새 사본의 것으로 바꾼다 — 매니페스트가 사라지면 이전에 깐 하네스 파일 전부가 3절의 사용자 파일로 판정된다
- `cmd_uninstall` 은 11-4 의 사전 판정을 통과한 뒤 두 매니페스트의 경로를 지우고 `.harness/` 를 걷는다

## 3. 사용자 파일 덮어쓰기 차단

### 3-1. 판정

**사용자 파일**은 이번 render 가 쓸 경로(관리 파일 · 생성 파일)에 이미 있으면서, 이전 매니페스트
(`.harness/generated` ∪ `.harness/managed` 의 경로)에 없는 것이다.

- 판정 대상은 관리 파일 경로(쓰지 않는 역할의 계약처럼 건너뛰는 경로는 뺀다)와 `plan()` 의 경로 전부다.
  `.claude/agents/` · `.claude/commands/` · `.claude/settings.json` · `CLAUDE.md` · `AGENTS.md` 가 여기 든다
- 소유 파일과 CI 골격은 대상이 아니다 — 원래 없을 때만 깐다
- 내용이 같아도 사용자 파일이다. 판정은 경로만 본다
- 경로에 디렉터리가 있으면 사용자 파일이다. 이전 매니페스트에 있는 경로여도 같다
- 쓸 경로(관리 파일 · 생성 파일 · 소유 파일 · CI 골격 · 매니페스트)의 부모 가운데 디렉터리가 아닌 것이 있으면 그 부모를 사용자 파일로 판정한다
- 이전 매니페스트에 있는 경로는 하네스 것이다 — 사람이 고쳤어도 지금처럼 덮는다(4절이 덮기 전의 변경을 보고한다)
- 심볼릭 링크는 이 판정이 아니라 11-4 가 먼저 막는다

### 3-2. 순서

1. render 는 **어떤 파일도 쓰기 전에** 11-5 매니페스트 검증과 11-4 사전 판정을 돌고, 이어 3-1 판정을 돈다 — 소유 파일과 CI 골격을 깔기 전이다
2. 사용자 파일이 하나라도 있으면 전부 모아 안내문(3-3)을 표준 오류로 내고 종료 코드 2 로 끝난다. 소유 파일 · 관리 파일 ·
   생성 파일 · 매니페스트 어느 것도 바뀌지 않는다
3. `--adopt` 가 있으면 3-4 대로 넘겨받고 계속한다

### 3-3. 안내문

영어로 `error:` · `-->` · `help:` 형식을 따른다. `<명령>` 은 사용자가 부른 명령(`render` · `install` · `set` · `steps` · `checks`)이다.

```
error: 2 file(s) the harness would write already exist and are not the harness's
  --> CLAUDE.md
  --> script/deploy.sh
nothing was written

help: move them aside, or let the harness take them over (each is kept as <path>.orig)
        harness <명령> --adopt
```

- `-->` 줄은 경로 순이고 개수를 자르지 않는다
- `script/` 아래 경로가 있으면 `help:` 끝에 한 줄을 더한다: `project scripts belong in script/project/, which the harness never writes`
- `--adopt` 로도 넘겨받을 수 없는 경로(3-4)가 있으면 그 줄 끝에 사유를 붙인다: `(a directory)` · `(not a directory)`(디렉터리여야 할 부모가 아니다) · `(<path>.orig already exists)`

### 3-4. `--adopt`

`install` · `render` · `set` · `steps` · `checks` 가 받는다. UI 는 넘기지 않는다.

- 사용자 파일마다 원래 파일을 같은 디렉터리의 `<경로>.orig` 로 옮기고(권한 비트 유지), 하네스 것을 쓴다
- `.orig` 파일은 매니페스트에 넣지 않는다. render 가 덮지도 지우지도 않고, `uninstall` 도 남긴다
- 넘겨받은 파일마다 표준 출력에 한 줄: ``render: adopted <경로> — yours is at <경로>.orig``
- 아래 경로가 하나라도 있으면 `--adopt` 여도 3-2 의 2 처럼 아무것도 쓰지 않고 멈춘다. 안내문은 3-3 이다
  - 경로에 디렉터리가 있다
  - 디렉터리여야 할 부모가 디렉터리가 아니다
  - `<경로>.orig` 가 이미 있다
- 옮기는 원래 경로와 `<경로>.orig` 는 둘 다 11-3 의 공용 함수를 거친다
- 사용자 파일이 없으면 `--adopt` 는 아무 일도 하지 않는다

### 3-5. 설정을 바꾸는 명령

- `set` · `steps` · `checks` 는 설정을 쓰기 **전에** 11-5 매니페스트 검증을 돈다. 어긋난 줄이 있으면 설정을 쓰지 않고 종료 코드 2 로 끝난다
- render 가 3-2 의 2 로, 또는 11-4 사전 판정으로 멈추면 설정을 바꾸기 전의 내용으로 되돌리고
  `reverted — the config is unchanged` 를 표준 오류로 낸 뒤 종료 코드 2 로 끝난다
- `steps --dry-run` 은 render 를 부르지 않으므로 이 판정에 닿지 않는다

### 3-6. `install`

- `cmd_install` 은 등록 판정 뒤, `.harness/` 를 바꾸기 전에 11-5 매니페스트 검증 · 11-4 사전 판정 · 3-1 판정을 이 순서로 돈다. 판정은 설치하려는 CLI 의 템플릿과 설정으로 한다
- 사용자 파일이 있고 `--adopt` 가 없으면(또는 3-4 의 멈춤 조건이면) 3-3 안내문을 내고 종료 코드 2 로 끝난다.
  `.harness/` · 생성 파일 · 등록부는 그대로다. `main()` 이 설정이 없던 대상에 먼저 깐 기본 `harness.toml` 은 남는다
- 소스 리포 분기도 같은 판정을 거친다 — 옛 사본을 걷어내기 전이다

## 4. 관리 파일 대조 — `check` · `doctor`

### 4-1. 판정

`.harness/managed` 의 줄마다 현재 파일과 비교한다. `check --staged` 는 작업 트리 대신 인덱스의 내용(`git show :<경로>`)을 쓴다.
매니페스트 자신은 작업 트리에서 읽는다.

| 상태 | 판정 |
|---|---|
| 해시가 있고 파일 바이트의 sha256 이 같다 | 일치 |
| 해시가 있고 sha256 이 다르다 | `modified managed file` |
| 해시가 있고 파일이 없다 (staged 면 인덱스에 없다) | `missing managed file` |
| 해시가 없다 (옛 형식 줄) | 비교하지 않는다 |

고정 사본 줄도 같은 표로 가른다. 11-5 검증에 어긋난 줄은 이 표로 가르지 않고 그 경로를 읽지 않는다 — `unsafe manifest line` 으로 보고한다(4-2 · 4-3).
`check` 의 생성 파일 어긋남이 `.harness/generated` 를 읽을 때도 같다.

### 4-2. `harness check`

- 4-1 의 `modified managed file` · `missing managed file` 이 하나라도 있으면 종료 코드 1 이다. 생성 파일 어긋남과 함께 있으면 둘 다 보고한다
- 출력(표준 오류). 경로 열은 생성 파일 어긋남과 같은 `%-52s` 폭이다

```
error: managed files differ from what the harness installed
  script/review-mr.sh                                  modified managed file
  script/hooks/_guards.sh                              missing managed file

help: managed files are the harness's — render puts them back
        harness render
      project scripts belong in script/project/
```

- 고정 사본 경로(`.harness/`)가 있으면 `help:` 에 한 줄을 더한다: `the pinned copy under .harness/ comes back with \`harness install\``
- 통과하면 기존 줄 뒤에 한 줄을 더한다: `check: <N> managed files match the manifest` (N 은 해시가 있어 비교한 줄 수)
- 해시가 없는 줄은 check 의 판정과 출력에 들지 않는다
- 두 매니페스트 가운데 11-5 검증에 어긋난 줄이 하나라도 있으면 종료 코드 1 이다. 다른 어긋남과 함께 있으면 모두 보고한다.
  줄의 내용은 옮기지 않고 매니페스트 이름 · 줄 번호 · 사유(11-5 의 사유 문구에서 괄호를 뗀 것)만 낸다

```
error: the harness manifest has line(s) that are not safe paths under the harness root
  .harness/generated:12                                has a .. component
  .harness/managed:3                                   a merge conflict marker

help: the manifest lists only files the harness wrote, as paths under the harness root
      fix or delete those lines
```

- 병합 충돌 표지 줄이 있으면 `help:` 에 11-5 의 충돌 조치 줄을 더한다

### 4-3. `harness doctor`

doctor 결과 목록(#59)에 `managed files` 절을 더한다. 자리는 `generated files` 절 바로 뒤다. 항목의 필드는
`harness status` 의 `doctor.items` 와 같다(`section` · `state` · `what` · `detail`). 텍스트 출력은 그 목록을 그린다.

| 조건 | state | what | detail |
|---|---|---|---|
| 해시가 있는 줄이 전부 일치한다 | `ok` | `<N> managed files match the manifest` | — |
| `modified managed file` 인 줄마다 | `bad` | `modified managed file` | `<경로>` |
| `missing managed file` 인 줄마다 | `bad` | `missing managed file` | `<경로>` |
| 해시가 없는 관리 파일 줄이 있다 | `warn` | `<N> managed files have no recorded hash` | ``run `harness render` `` |
| `.harness/bin/harness` 가 있는데 고정 사본 줄이 없거나 해시가 없다 | `warn` | `the pinned copy has no recorded hash` | ``run `harness install` `` |

- `bad` 항목은 경로 순으로 10개까지 내고, 넘으면 `bad` `<N> more modified or missing managed file(s)` 한 항목으로 줄인다
- 11-5 검증에 어긋난 줄마다 `bad` `unsafe manifest line` 항목을 낸다. detail 은 `<매니페스트>:<줄 번호> (<사유>)` 이고 줄의 내용은 담지 않는다.
  `.harness/managed` 의 줄은 이 절에, `.harness/generated` 의 줄은 `generated files` 절에 낸다. 각 절에서 줄 번호 순으로 10개까지 내고,
  넘으면 `bad` `<N> more unsafe manifest line(s)` 한 항목으로 줄인다. 이 항목이 있는 절에는 `ok` 를 내지 않는다
- `.harness/managed` 가 없으면 `warn` `no manifest of managed files` — ``run `harness render` `` 한 항목만 낸다
- `ok` 와 `bad` · `warn` 은 함께 나올 수 있다 — `ok` 는 비교한 줄 전부가 일치할 때만 낸다

### 4-4. UI 문구 — `src/ui/lib/doctor.js`

- `SECTIONS` 에 `"managed files": "관리 파일"` 을 더한다
- `explain()` 이 4-3 의 `bad` · `warn` 항목을 한국어로 옮긴다

| what | 항목에 담는 것 | 조치 |
|---|---|---|
| `modified managed file` | 하네스 파일(detail 경로)이 설치 뒤 바뀌었고, 다음 render 가 덮는다는 것. 프로젝트 스크립트면 `script/project/` 로 옮긴다는 것 | `run`: `render` |
| `missing managed file` | 하네스 파일(detail 경로)이 없어졌다는 것 | `run`: `render` |
| `<N> managed files have no recorded hash` | 옛 하네스가 쓴 매니페스트라 바뀐 것을 가릴 수 없다는 것 | `run`: `render` |
| `the pinned copy has no recorded hash` | 고정 사본이 바뀌었는지 가릴 수 없다는 것 | `cmd`: `harness install` |
| `<N> more modified or missing managed file(s)` | 나머지 건수 | `run`: `render` |
| `unsafe manifest line` | 하네스 기록(detail 의 매니페스트와 줄 번호)에 하네스 루트 아래의 정상 경로가 아닌 줄이 있어 render · install · set · steps · checks · uninstall 이 아무것도 바꾸지 않고 멈춘다는 것. 사유가 `a merge conflict marker` 면 양쪽 줄을 남기고 표지 줄을 지운 뒤 `harness install` 로 다시 쓰게 한다는 것 | 없음 — 파일을 손으로 고친다 |
| `<N> more unsafe manifest line(s)` | 나머지 건수 | 없음 |

`.harness/` 로 시작하는 detail 의 `modified`·`missing` 항목은 조치를 `cmd`: `harness install` 로 한다 — render 는 고정 사본을 되돌리지 않는다.

## 5. 고정 사본 대조 — `delegate()`

전역 CLI 가 고정 사본(`.harness/bin/harness`)으로 넘기기 직전에 돈다. `DELEGATES` 의 명령 전부가 대상이다.

### 5-1. 버전

| 전역 CLI 버전(`DEFAULT_CONFIG` 의 `harness.version`) · 고정 버전(`.harness/VERSION`) | 동작 |
|---|---|
| 둘 다 읽히고 같다 | 5-2 대조 |
| 다르다 · 어느 쪽이든 읽지 못한다 | 대조하지 않고 표준 오류에 한 줄을 낸다: `note: cannot verify the pinned harness — this machine has harness <전역 버전>, the project pins <고정 버전 또는 "no version">` |

버전이 둘 다 읽히고 다르면 기존 `note: this project is pinned to …` 두 줄도 그대로 낸다.

### 5-2. 대조

| 전역 CLI 쪽 | 고정 사본 쪽 |
|---|---|
| `HERE / "harness"` | `.harness/bin/harness` |
| `HERE / "harness_metrics.py"` | `.harness/bin/harness_metrics.py` |
| `TEMPLATES` 아래 파일 전부 | `.harness/templates/` 아래 파일 전부 |

- 파일 바이트의 sha256 으로 비교한다. 매니페스트를 읽지 않는다
- 다름으로 세는 것: 해시가 다른 파일, 한쪽에만 있는 파일, 그리고 `.harness/bin/` 에 위 두 파일 말고 있는 파일. `__pycache__/` 는 양쪽에서 뺀다
- 다름이 있으면 표준 오류에 아래를 내고 **그대로 넘긴다**(종료 코드와 명령 결과를 바꾸지 않는다)

```
warning: the pinned harness differs from harness <버전> on this machine — 2 file(s)
  --> .harness/bin/harness
  --> .harness/templates/managed/script/review-mr.sh

help: restore the pinned copy
        harness install --target <하네스 루트>
```

- `-->` 줄은 경로 순으로 10개까지, 넘으면 `  ... and <N> more` 한 줄
- 다름이 없으면 아무것도 내지 않는다
- 표준 출력에는 아무것도 내지 않는다 — `status` · `schema` · `steps` · `metrics` 의 JSON 출력이 그대로여야 한다

## 6. 소스 리포

소스 리포는 사본을 고정하지 않고 자기 `src/bin/harness` 로 돈다(ADR 0013).

- `delegate()` 는 소스 리포에서 5절 대조를 하지 않고 줄도 내지 않는다 — 넘겨받는 쪽이 작업 트리 자신이다
- `.harness/managed` 는 관리 파일 줄만 갖는다(2-2). `check` · `doctor` 는 이 리포의 `script/` · `.ai/templates/` · `.claude/commands/` ·
  `docs/workflow/` 가 지난 render 뒤 바뀌었는지 본다. 관리 파일을 고치려면 `src/templates/managed/` 를 고치고 render 한다
- 3절 충돌 판정도 같게 돈다. `script/project/README.md` 가 이 리포에도 깔린다

## 7. 회귀 테스트

`render-test.sh` 에 새 `UT-<번호>` 블록 넷을 둔다(7-1 · 7-2 · 7-3 · 7-4 가 한 블록씩). 번호는 기존 블록과 겹치지 않게 고른다(중복은 회귀 테스트가 잡는다).
등록부는 기존처럼 `HARNESS_HOME` 을 쓴다.

### 7-1. 사용자 파일 덮어쓰기 차단

| 케이스 | 확인하는 것 |
|---|---|
| 첫 설치의 겹침 | 설치 전에 사용자 `CLAUDE.md` 와 `script/review-mr.sh` 를 두면 `install` 이 종료 코드 2. 표준 오류에 두 경로와 `nothing was written` · `--adopt` · `script/project/`. 두 파일 내용이 그대로, `.harness/` · `.ai/AI_AGENT.md` · `script/project/README.md` 가 없고, 등록부에 `project.json` 이 없다 |
| 넘겨받기 | 같은 상태에서 `install --adopt` 가 종료 코드 0. `CLAUDE.md.orig` · `script/review-mr.sh.orig` 가 원래 내용이고, 두 경로가 매니페스트에 있고 `.orig` 는 없다. 표준 출력에 `adopted` 두 줄 |
| 넘겨받을 수 없음 | `CLAUDE.md.orig` 가 이미 있으면 `install --adopt` 가 종료 코드 2 이고 아무것도 바뀌지 않는다. 경로에 디렉터리가 있을 때(매니페스트에 있는 관리 파일 자리를 디렉터리로 바꾼 render 포함)와, 새 리포에 일반 파일 `script` 를 두고 install 할 때(`script (not a directory)`, 고정 사본 · 생성물 · 소유 파일 · 등록부 없음)도 같다 |
| 재설치 | 설치된 리포에서 `install` 을 다시 돌리면 종료 코드 0 — 매니페스트가 남아 사용자 파일이 없다. 관리 파일을 고쳐 둔 채 재설치해도 덮인다 |
| 다른 이름의 사용자 스크립트 | `script/deploy.sh` 를 두고 render 하면 통과하고 그 파일이 그대로다. `doctor` 가 그 파일로 `bad` · `warn` 을 내지 않는다 |
| 설정을 바꾸는 명령 | 사용자 `.claude/commands/<새 절차>.md` 를 둔 채 `steps` 로 그 이름의 절차를 만들면 종료 코드 2, `reverted`, `harness.toml` 이 바이트 단위로 그대로다. `set` 으로 새 생성 경로가 생기는 값을 바꿀 때도 같다 |
| 소유 원형 | render 가 `script/project/README.md` 를 없을 때만 깔고, 고친 내용을 다음 render 가 덮지 않는다. `uninstall` 이 남기고 `uninstall --purge` 가 지운다 |
| 불변식 | 관리 파일 경로와 `plan()` 경로 가운데 `script/project/` 로 시작하는 것이 없다 |

### 7-2. 매니페스트와 대조

| 케이스 | 확인하는 것 |
|---|---|
| 형식 | 설치 뒤 `.harness/managed` 의 줄이 전부 `<64자 16진>  <경로>` 이고, 관리 파일 · `.harness/bin/harness` · `.harness/VERSION` · `.harness/templates/harness.toml` 줄이 있다. 하네스 루트에서 `shasum -a 256 -c .harness/managed` 가 통과한다 |
| 옛 형식 읽기 | 매니페스트를 경로 목록으로 바꾸고, 설정을 바꿔 더는 깔지 않게 된 관리 파일(쓰지 않게 된 역할의 계약 등)이 생기게 render 하면 그 파일이 지워지고(정리가 옛 형식을 읽는다) 사용자 파일 오류가 없으며, 매니페스트가 새 형식이 된다 |
| 옛 형식 대조 | 옛 형식 매니페스트에서 `check` 가 종료 코드 0, `doctor` 의 `managed files` 절에 `have no recorded hash` `warn` |
| 관리 파일 변경 | `script/review-mr.sh` 를 고치면 `check` 가 종료 코드 1 이고 `modified managed file` 과 그 경로. 지우면 `missing managed file`. render 뒤 `check` 가 0 |
| staged | 고친 관리 파일을 스테이징하면 `check --staged` 가 1, 작업 트리만 고치고 스테이징하지 않으면 `check --staged` 가 0 |
| 고정 사본 변경 | `.harness/templates/` 아래 파일 하나를 고치면 `check` 가 1 이고 `help:` 에 `harness install`. render 뒤에도 1 이다(render 가 고정 사본 해시를 다시 계산하지 않는다) |
| doctor 항목 | `harness status` 의 `doctor.items` 에 `section` 이 `managed files` 이고 `state` `bad` · `what` `modified managed file` · `detail` 이 그 경로인 항목이 있다. 고치기 전에는 `ok` 항목 하나다 |

### 7-3. 고정 사본 대조

전역 CLI 는 테스트의 `src/bin/harness` 이고, 고정 사본은 그것으로 설치한 것이다.

| 케이스 | 확인하는 것 |
|---|---|
| 일치 | `doctor` 를 전역 CLI 로 부르면 표준 오류에 `warning:` · `cannot verify` 가 없다 |
| 변조 | `.harness/templates/` 아래 파일 하나를 고치면 표준 오류에 `warning: the pinned harness differs` 와 그 경로, `harness install --target`. 명령의 종료 코드와 표준 출력이 고치지 않았을 때와 같은 종류다(`status` 표준 출력이 JSON 으로 읽힌다) |
| 버전 다름 | `.harness/VERSION` 을 다른 값으로 바꾸면 `cannot verify` 줄이 한 번 나오고 `warning: the pinned harness differs` 는 없다 |
| 버전 없음 | `.harness/VERSION` 을 지우면 `cannot verify` 줄에 `no version` |
| 소스 리포 | 소스 트리 복제본에서 전역 CLI 로 `doctor` 를 부르면 `warning:` · `cannot verify` 가 없다 |

### 7-4. 경로 안전

11절의 케이스다. 링크 대상과 피해 파일은 하네스 루트 바깥(테스트 임시 디렉터리 안)에 둔다. "그대로" 는 바이트 단위로 같다는 뜻이다.
리포 밖 파일을 바꿀 수 있는 지점의 케이스는 모두 이 블록이 정본이다 — 7-1 블록에 있던 링크 케이스는 이 블록으로 옮긴다.

매니페스트 검증(11-5):

| 케이스 | 확인하는 것 |
|---|---|
| `..` 줄 | 하네스 루트의 부모에 `victim.md` 를 두고 `.harness/generated` 에 `../victim.md` 한 줄을 더해 render 하면 종료 코드 2. 표준 오류에 `.harness/generated:<줄 번호> (has a .. component)` 와 `nothing was changed`. `victim.md` · 두 매니페스트 · 관리 파일 · 생성 파일이 그대로다 |
| 절대 경로 줄 | `.harness/managed` 에 `<64자 16진>  <바깥 파일의 절대 경로>` 줄을 더하면 render · install · uninstall 이 각각 종료 코드 2 이고 `(an absolute path)`. 바깥 파일이 그대로이고, uninstall 뒤에도 `.harness/` 와 매니페스트의 다른 경로가 남아 있다 |
| 형식 오류 줄 | 공백이 든 줄, 빈 성분(`script//x.sh`), `.` 성분(`./CLAUDE.md`), 끝의 `/` 가 든 줄이 각각 `(not a path)` 로 종료 코드 2 |
| 병합 충돌 표지 줄 | `.harness/managed` 에 `<<<<<<< HEAD` · `=======` · `>>>>>>> other` 세 줄을 더하면 render 가 종료 코드 2 이고 세 줄 모두 `(a merge conflict marker)`, `help:` 에 `harness install`. 표지 줄을 지우면 install 이 종료 코드 0 이다 |
| 링크 성분 줄 | 매니페스트에 있는 관리 파일을 바깥 파일 링크로 바꾸고 `check` 를 부르면 그 줄이 `through a symbolic link` 로 보고되고 바깥 파일의 해시를 대조하지 않는다 |
| CR 줄 끝 | 두 매니페스트의 줄 끝을 CRLF 로 바꿔도 render 가 종료 코드 0 이다 |
| 설정을 바꾸는 명령 | 위반 줄이 있을 때 `set` · `steps <새 절차>` · `checks` 가 종료 코드 2 이고 `harness.toml` 이 그대로다 |
| check 보고 | `..` 줄과 충돌 표지 줄이 있으면 `check` 가 종료 코드 1 이고 표준 오류에 두 `<매니페스트>:<줄 번호>` 와 사유. 피해 파일이 그대로다 |
| doctor 보고 | 같은 상태에서 `harness status` 의 `doctor.items` 에 `state` `bad` · `what` `unsafe manifest line` 항목이 있고, `.harness/generated` 의 줄은 `section` `generated files`, `.harness/managed` 의 줄은 `managed files` 다. detail 에 줄의 내용이 없다 |

심볼릭 링크(11-2 · 11-4):

| 케이스 | 확인하는 것 |
|---|---|
| 관리 파일 링크 | 설치된 리포에서 `script/review-mr.sh` 를 바깥 파일 링크로 바꾸고 render 하면 종료 코드 2. 바깥 파일이 그대로다 |
| 링크 부모 — 관리 · 생성 | `script` 를 바깥 디렉터리 링크로 바꾸고 render 하면 종료 코드 2. 표준 오류의 `-->` 줄이 `script` 하나이고(그 아래 경로를 따로 나열하지 않는다) 바깥 디렉터리가 그대로다 |
| 링크 부모 — 소유 | 소유 원형이 아직 없는 새 리포에서 `script/project` 를 바깥 디렉터리 링크로 두고 install 하면 종료 코드 2. 바깥 디렉터리에 `README.md` 가 생기지 않는다 |
| 링크된 `.ai/project` | 설치된 리포의 `.ai/project` 를 같은 내용의 바깥 디렉터리 링크로 바꾸고 render 하면 종료 코드 2. 표준 오류에 `--> .ai/project`, `nothing was changed`, 11-4 의 `help:` 줄. 링크를 실제 디렉터리로 바꾸면 render 가 종료 코드 0 이다 |
| 정리 대상 링크 | `docs/adr` 를 바깥 디렉터리 링크로 두고(링크 대상에 `README.md`) `set adr.dir docs/decisions` 하면 종료 코드 2, `reverted`. 바깥 `README.md` · `harness.toml` · 매니페스트가 그대로다 |
| `--adopt` 링크 | `CLAUDE.md` 가 바깥 파일 링크인 새 리포에서 `install --adopt` 가 종료 코드 2. 바깥 파일이 그대로이고 `CLAUDE.md.orig` 가 없다 |
| `.harness` 링크 | 새 리포와 설치된 리포 각각에서 `.harness` 를 바깥 디렉터리 링크로 두고 install 하면 종료 코드 2. 링크 대상의 파일 · 하위 디렉터리 파일이 그대로이고 등록부에 기록이 없다 |
| 소스 리포 옛 사본 | `.harness/bin` 이 바깥 디렉터리 링크인 소스 트리 복제본에서 install 하면 종료 코드 2. 바깥 디렉터리가 그대로다 |
| 설정 씨앗 | `harness.toml` 이 대상 없는 링크인 새 리포에서 install 하면 종료 코드 2. 링크 대상 경로에 파일이 생기지 않는다 |
| uninstall 링크 | `docs/adr` 가 바깥 디렉터리 링크인 설치 리포에서 `uninstall` 이 종료 코드 2. 바깥 디렉터리 · `.harness/` · 매니페스트의 경로가 그대로다 |
| purge 링크 | `.ai/project` 가 바깥 디렉터리 링크일 때 `uninstall --purge --yes` 가 종료 코드 2 이고 바깥 디렉터리가 그대로다. `--yes` 없이 비대화형으로 부르면 확인 목록 대신 링크 오류로 종료 코드 2 다 |
| 하네스 루트 위의 링크 | 하네스 루트를 가리키는 링크 경로를 `--target` 으로 주면 render 가 종료 코드 0 이다 — 루트 자신과 그 위는 보지 않는다 |

`steps --rename`(11-7):

| 케이스 | 확인하는 것 |
|---|---|
| 대상 존재 | 사용자 절차 `hotfix` 가 있고 `.ai/project/workflows/hotfix.md` · `.ai/project/workflows/quickfix.md` 를 다른 내용으로 두면 `steps hotfix --rename quickfix` 가 종료 코드 2. 두 파일과 `harness.toml` 이 그대로다 |
| 대상 없음 | `quickfix.md` 가 없으면 종료 코드 0 이고 `hotfix.md` 의 내용이 `quickfix.md` 로 옮겨진다 |
| 링크 | `.ai/project/workflows` 가 바깥 디렉터리 링크면 같은 명령이 종료 코드 2 이고 바깥 디렉터리와 `harness.toml` 이 그대로다. `hotfix.md` 하나만 바깥 파일 링크일 때도 같다 |

터미널 출력의 한글 검사는 네 블록의 출력에도 적용한다.

### 7-5. 기존 케이스

- 설치 전에 하네스가 쓸 경로에 파일을 두는 기존 케이스는 그 파일을 두지 않거나 `--adopt` 를 준다. 케이스가 검증하는 내용은 바꾸지 않는다
- 매니페스트를 경로 목록으로 읽는 기존 검사는 2-1 형식에 맞춘다
- "관리 파일을 덮는다" 케이스(관리 파일에 줄을 더하고 render 하면 사라진다)는 그대로 통과해야 한다

### 7-6. `doctor.test.js`

- `SECTIONS["managed files"]` 가 `"관리 파일"` 이다
- `explain()` 이 `modified managed file`(detail `script/review-mr.sh`) 항목을 원문과 다른 제목의 항목으로 옮기고, 본문에 그 경로와 `script/project/` 가 있으며 `run.kind` 가 `render` 다
- detail 이 `.harness/` 로 시작하면 `cmd` 가 `harness install` 이고 `run` 이 없다
- `the pinned copy has no recorded hash` 의 `cmd` 가 `harness install` 이다

## 8. 보호 문서에 반영할 것

사람이 지시한 턴에 반영한다. 이 이슈의 범위다.

| 문서 · 위치 | 반영할 사실 |
|---|---|
| `.ai/project/glossary.md` "소유 파일" | 목록에 `script/project/README.md` 를 더한다: (`.ai/project/` · `docs/spec/README.md` · `script/project/README.md` · CI 설정) |
| 같은 파일 "매니페스트" | 지난 설치·렌더가 무엇을 깔았는지 적은 목록. `.harness/generated` 는 생성 파일 경로, `.harness/managed` 는 관리 파일과 고정 사본의 sha256 과 경로. 정리·제거·변조 감지의 근거 |
| 같은 파일 새 행 "사용자 파일" | 하네스가 쓸 경로에 있으나 매니페스트에 없는 파일. render · install 이 덮지 않고 멈추며, `--adopt` 면 `<경로>.orig` 로 옮기고 넘겨받는다 |
| `.ai/project/architecture.md` "구성 요소" 의 `script/` 항목 | `script/project/` 는 프로젝트 것이다. 하네스는 그 안의 `README.md` 만 없을 때 깐다 |
| 같은 파일 "데이터 흐름" 의 렌더 | render 는 쓰기 전에 사용자 파일을 판정하고, 관리 파일의 sha256 을 `.harness/managed` 에 기록한다. `check` · `doctor` 가 그것과 대조한다. 전역 CLI 는 고정 사본으로 넘기기 전에 같은 버전의 자기 파일과 대조한다 |
| 같은 파일 "새 코드를 둘 곳" | 새 관리 스크립트 → 표는 `src/templates/managed/script/README.md`. 새 행: 대상 리포의 프로젝트 스크립트 → `script/project/` + `script/project/README.md` 표 한 줄 |
| 같은 파일 "신뢰 경계" 의 "들어오는 입력" | 한 항목을 더한다: 매니페스트(`.harness/generated` · `.harness/managed`) — 커밋된 파일이라 신뢰하지 않는다. 읽을 때마다 줄마다 경로 규칙(하네스 루트 기준 정규화된 상대 경로, `..` · 절대 경로 · 빈 성분 · 링크 성분 거부)으로 검증하고, 어긋난 줄이 하나라도 있으면 대상 리포를 바꾸는 명령은 아무것도 바꾸지 않는다(11절) |
| 같은 파일 "검사하지 않는 것" | 고정 사본(`.harness/bin` · `.harness/templates`)을 고치면 pre-commit · `run-lint-test.sh` · CI 의 검사도 고친 사본이 돈다. 사본과 매니페스트를 함께 고치면 그 검사들은 알아채지 못한다. 사본 변조를 잡는 것은 같은 버전의 전역 CLI 가 넘기기 전에 하는 대조뿐이고, 그것도 경고만 한다 |

## 9. 결정 기록

- 5절의 대조 방식 — 전역 CLI 와 고정 버전이 같을 때만 사본을 전역 CLI 의 파일과 직접 비교하고, 다르면 대조하지 않는다는 한 줄을
  내며, 불일치는 경고한 뒤 그대로 넘긴다 — 은 `docs/adr/0015-detect-changes-to-the-pinned-copy-and-managed-files.md` 가 기록한다
- 11절의 경로 안전 규칙 — 대상 리포를 바꾸는 지점 전부가 공용 함수 하나를 거치고, 매니페스트를 신뢰하지 않는 입력으로 검증해
  위반이 있으면 아무것도 바꾸지 않으며, 하네스 루트 아래의 심볼릭 링크 성분을 전부 거부하고, 경합은 사전 판정과 직전 재검사까지 덮는다 —
  은 `docs/adr/0017-the-harness-changes-the-target-repo-only-through-safe-paths.md` 가 기록한다. 0015 와 별개의 기록이다

## 10. 한계

- 목표는 감지다. 파이썬 사본은 막을 수 없고, 바이너리로 묶지 않는다
- 고정 사본을 고치면 그 사본이 도는 검사(`check` · `doctor` · 훅 · CI)는 고친 기준으로 돈다(8절 "검사하지 않는 것")
- 5절 대조는 이 기기에 같은 버전의 전역 CLI 가 있을 때만 돈다. 전역 CLI 가 같은 버전 번호의 수정된 작업 트리이면 그 차이도 다름으로 보고한다
- 줄바꿈을 바꾸는 git 설정(`core.autocrlf`)으로 체크아웃하면 파일 바이트가 달라져 `modified managed file` 로 보고된다
- `script/` 루트에 이미 있는 프로젝트 스크립트는 그 자리에 남는다. 하네스가 같은 이름을 들일 때에야 3절이 알린다
- 하네스 루트 아래의 심볼릭 링크는 지원하지 않는다. `.ai/project` · `docs/adr` · `script` 같은 디렉터리나 하네스가 쓰는 파일을
  링크로 두면 render · install 이 멈춘다(11-6). 하네스 루트 자신과 그 위의 경로는 보지 않으므로 루트를 링크로 가리켜 부르는 것은 그대로 된다
- 경합은 사전 판정(11-4)과 공용 함수 안의 직전 재검사(11-3)까지만 덮는다. 재검사와 실제 시스템 호출 사이에 링크를 끼워 넣는 창은 남는다.
  그런 창을 쓸 수 있는 쪽은 대상 리포에 같은 쓰기 권한을 가진 쪽이고, 그 권한이면 고정 사본을 직접 고칠 수 있다(ADR 0015 Context)
- 직전 재검사가 명령 도중에 멈추면 그때까지 바꾼 파일은 되돌리지 않는다
- 하드 링크는 판정하지 않는다. 하네스가 덮는 파일이 리포 밖 파일과 하드 링크로 묶여 있으면 그 파일도 바뀐다

## 11. 대상 리포 경로 안전

하네스가 대상 리포를 바꿀 때 리포 밖으로 새거나 리포 안의 남의 파일을 덮지 않게 하는 규칙이다.
경로 규칙(11-2)을 하나 두고, 사전 판정(11-4)과 공용 함수(11-3)가 같은 규칙을 쓴다. 매니페스트는 그 규칙으로 검증한다(11-5).

### 11-1. 적용 범위

`src/bin/harness` 가 대상 리포의 파일 · 디렉터리를 만들거나 쓰거나 권한을 바꾸거나 지우거나 옮기는 지점 전부다.

| 지점 | 일으키는 명령 | 동작 |
|---|---|---|
| `copy_tree()` — 관리 파일 | render(install · set · steps · checks 경유 포함) | 디렉터리 만들기 · 쓰기 · 권한 |
| `copy_tree()` — 소유 파일 · CI 골격(없을 때만) | 같음 | 같음 |
| 생성 파일 쓰기(`cmd_render` 의 `plan()` 루프) | 같음 | 같음 |
| 매니페스트 쓰기(`.harness/generated` · `.harness/managed`) | render · install | 디렉터리 만들기 · 쓰기 |
| `prune()` | render | 파일 지우기 · 빈 부모 디렉터리 걷기 |
| `--adopt` 의 넘겨받기 | install · render · set · steps · checks | `<경로>` → `<경로>.orig` 옮기기 |
| `install_registered()` — 사본 교체 | install | `.harness/` 걷기 · 디렉터리 만들기 · 사본 복사 · `.harness/VERSION` 쓰기 |
| `install_registered()` — 소스 리포의 옛 사본 정리 | install(소스 리포) | `.harness/bin` · `.harness/templates` · `.harness/VERSION` 지우기 |
| `seed_config()` | install | `harness.toml` 쓰기(없을 때) |
| `cmd_uninstall` | uninstall · `uninstall --purge` | 매니페스트의 경로 · 소유 파일 · `harness.toml`(`--purge`) 지우기, `.harness/` 걷기, 빈 부모 디렉터리 걷기 |
| `rename_or_delete_workflow()` | `steps <절차> --rename <새 이름>` | `.ai/project/workflows/<절차>.md` 옮기기 |

대상이 아닌 것:

- `copy_include()` — `harness run --worktree` 가 git 이 무시하는 로컬 파일을 worktree 로 복사한다. 쓰는 곳이 기기 단위 worktree
  디렉터리이고 대상 리포가 아니다. 링크를 따라가지 않는 지금의 복사를 유지한다
- `set` · `steps` · `checks` 의 `harness.toml` 쓰기와 되돌리기 — 프로젝트 설정 파일 자체다. 링크면 그 링크 대상이 그 설정이다
- 기기 단위 상태(등록부 · 도구 기록 · 지표 · UI 서버 파일) — 대상 리포 밖이다
- git 이 바꾸는 것(`git config` 등) — 하네스가 경로에 쓰지 않는다

11-1 의 표에 없는 지점에서 대상 리포를 바꾸는 코드를 새로 두면 그것도 11-3 의 공용 함수를 거친다.

### 11-2. 경로 규칙

대상 경로는 하네스 루트 기준 상대 경로 문자열이다. 하네스 루트는 `--target` 을 `resolve()` 한 경로다.

형식 — 파일 시스템을 보지 않고 문자열로 판정한다.

- `/` 로 나눈 성분이 하나 이상이고, 성분마다 `[\w.-]+` 에 맞는다. `docs.protected` 를 검증하는 `PROTECTED_PATH` 의 성분과 같은 문자 집합이다
  (파이썬 `re` 의 유니코드 `\w`). 공백 · 역슬래시 · 제어 문자 · glob 문자(`*` `?` `[`) · `:` 는 들지 않는다
- 앞의 `/`(절대 경로), 끝의 `/`, 빈 성분(`//`)이 없다
- `.` · `..` 성분이 없다 — 정규화된 경로다

링크 — 파일 시스템을 본다.

- 하네스 루트 아래의 성분 `a` · `a/b` · … · 경로 자신 가운데 심볼릭 링크가 없다. `lstat` 으로 보고, 링크 대상이 있는지와 상관없다.
  소유 파일과 CI 골격처럼 없을 때만 까는 경로도, 그 부모도 같다
- 하네스 루트 자신과 그 위의 경로는 보지 않는다
- 아직 없는 성분은 어긋남이 아니다

어긋남의 사유 문구 — 위에서부터 처음 맞는 하나를 붙인다.

| 어긋남 | 사유 |
|---|---|
| 매니페스트 줄이 `<<<<<<<` · `\|\|\|\|\|\|\|` · `=======` · `>>>>>>>` 로 시작한다 | `a merge conflict marker` |
| 앞의 `/` | `an absolute path` |
| `..` 성분 | `has a .. component` |
| 그 밖의 형식 어긋남 | `not a path` |
| 링크 성분 | `through a symbolic link` |

### 11-3. 공용 함수 — `guarded_path()`

`guarded_path(root, rel, verb)` 는 11-2 를 판정하고 통과하면 `root / rel` 을 돌려준다. `verb` 는 `create` · `write` · `remove` · `move` 다.

- 11-1 의 지점은 대상 리포를 바꾸는 시스템 호출(쓰기 · 권한 · 디렉터리 만들기 · 지우기 · 디렉터리 걷기 · 옮기기 · 복사)을 전부 이 함수가 돌려준 경로에 한다
- 호출 **바로 앞에서** 판정한다. 사전 판정(11-4)이 통과시킨 경로도 다시 본다
- 옮기기는 원래 경로와 새 경로를 둘 다, 디렉터리 만들기는 만들 디렉터리를, 빈 부모 걷기는 걷는 디렉터리마다 거친다
- 디렉터리를 통째로 걷는 것(`.harness/` 걷기 · 소스 리포 옛 사본 정리)은 그 디렉터리를 이 함수로 거친 뒤, 안의 링크는 링크 자신만 지우고 따라가지 않는다
- 어긋나면 아무것도 하지 않고 표준 오류에 아래를 낸 뒤 종료 코드 2 로 끝난다

```
error: refusing to <verb> through a symbolic link
  --> <링크인 성분>

help: replace the link with the directory or file it points to, then run the command again
```

- 형식이 어긋나면 첫 줄이 `error: refusing to <verb> a path that is not safe under the harness root (<사유>)` 이고 `-->` 줄이 없다.
  경로를 출력하지 않는다

### 11-4. 사전 판정

변경 명령은 무엇이든 바꾸기 전에 이번에 바꿀 경로 전부를 11-2 로 판정한다. 순서는 11-5 매니페스트 검증 → 이 판정 → 3-1 사용자 파일 판정이다.

| 명령 | 판정하는 경로 |
|---|---|
| render(install · set · steps · checks 의 render 포함) | 관리 파일 경로 · `plan()` 의 경로 · 소유 파일과 CI 골격의 경로 · `.harness/generated` · `.harness/managed` · 정리가 지울 옛 경로. `--adopt` 면 넘겨받을 경로와 `<경로>.orig` |
| install | render 의 것과 `.harness` · `.harness/bin` · `.harness/templates` · `.harness/VERSION`. 소스 리포 분기도 같다 |
| uninstall | 두 매니페스트의 경로 · `.harness` · `--purge` 면 지울 소유 파일과 `harness.toml`. `--purge` 의 확인 목록을 내기 전이다 |
| `steps --rename` | 11-7 |

- 링크 성분이 하나라도 있으면 전부 모아 아래를 표준 오류로 내고 종료 코드 2 로 끝난다. 아무것도 바뀌지 않는다 — 대상 리포 · 매니페스트 · 등록부 모두
- `-->` 줄은 링크인 성분이고 경로 순이며 개수를 자르지 않는다. 한 링크 아래의 경로를 따로 나열하지 않는다
- `<명령>` 은 사용자가 부른 명령이다

```
error: 1 path(s) the harness would change go through a symbolic link
  --> .ai/project
nothing was changed

help: the harness does not write through symbolic links under the harness root
      replace each link with the directory or file it points to, then run the command again
        harness <명령>
```

- `set` · `steps` · `checks` 는 이 판정이 render 안에서 돌므로 3-5 대로 설정을 되돌린다
- install 에서 `main()` 이 설정이 없던 대상에 먼저 깐 기본 `harness.toml` 은 남는다(3-6)
- `seed_config()` 는 설정을 읽기 전에 돌아 이 판정보다 앞선다. `harness.toml` 이 없을 때(대상 없는 링크 포함) 11-3 의 공용 함수를 거쳐 쓰고,
  링크면 쓰지 않고 11-3 대로 멈춘다

### 11-5. 매니페스트 검증

`.harness/generated` · `.harness/managed` 를 읽는 명령은 읽을 때마다 줄마다 2-3 대로 경로를 뽑아 11-2 의 형식과 링크로 판정한다.
`.harness/` 로 시작하는 줄도 같다. 어긋난 줄의 경로는 열지도 바꾸지도 않는다.

변경 명령(render · install · set · steps · checks · uninstall):

- 어긋난 줄이 하나라도 있으면 아무것도 바꾸지 않고 아래를 표준 오류로 낸 뒤 종료 코드 2 로 끝난다
- `set` · `steps` · `checks` 는 설정을 쓰기 전에 판정한다(3-5). `steps --dry-run` 은 매니페스트를 읽지 않는다
- uninstall 은 "매니페스트가 없다" 판정보다 먼저 판정한다
- `-->` 줄은 `<매니페스트>:<줄 번호> (<사유>)` 이고 매니페스트 이름 순 · 줄 번호 순이며 개수를 자르지 않는다. **줄의 내용은 출력하지 않는다**

```
error: the harness manifest has 2 line(s) that are not safe paths under the harness root
  --> .harness/generated:12 (has a .. component)
  --> .harness/managed:3 (a merge conflict marker)
nothing was changed

help: the manifest lists only files the harness wrote, as paths under the harness root
      fix or delete those lines, then run the command again
        harness <명령>
```

- 사유가 `a merge conflict marker` 인 줄이 있으면 `help:` 끝에 충돌 조치 줄을 더한다

```
      a merge left conflict markers in it — keep the lines of both sides, delete the marker lines,
      then let the harness rewrite it
        harness install
```

- 사유가 `through a symbolic link` 인 줄은 11-4 와 같은 조치다. 링크를 실제 파일 · 디렉터리로 바꾸면 그 줄은 통과한다

읽기 명령(check · doctor · status 의 doctor 항목):

- 어긋난 줄을 오류 항목으로 보고하고, 검증을 통과한 줄로 나머지 판정을 한다. 출력과 종료 코드는 4-2 · 4-3 이다
- 표준 출력 · 표준 오류 어디에도 줄의 내용을 옮기지 않는다

`delegate()` 의 5절 대조는 매니페스트를 읽지 않으므로 이 검증을 거치지 않는다.

### 11-6. 하네스 루트 아래의 링크

- 하네스 루트 아래의 링크 성분은 쓰는 경로 · 지우는 경로 · 덮는 경로를 가리지 않고 전부 거부한다. 링크 대상이 리포 안이어도 같다
- 그래서 `.ai/project` · `docs/adr` · `docs/spec` · `script` 같은 디렉터리를 링크로 둔 설치는 지원하지 않는다. 그런 기존 설치는 이 규칙이 든
  하네스로 갱신하면 render · install · set · steps · checks · uninstall 이 11-4 로 멈추고, 링크를 실제 디렉터리로 바꿀 때까지 대상 리포를 바꾸지 않는다
- 조치는 11-4 의 `help:` 다 — 링크를 그것이 가리키는 디렉터리 · 파일의 사본으로 바꾸고 명령을 다시 부른다
- `check` · `doctor` 는 이 링크로 멈추지 않는다. 매니페스트 줄에 링크 성분이 있으면 11-5 대로 그 줄을 보고한다

### 11-7. `steps --rename`

`steps <절차> --rename <새 이름>` 은 이름 중복 판정 뒤, **설정을 쓰기 전에** 아래를 판정한다.
원래 문서는 `.ai/project/workflows/<절차>.md`, 새 문서는 `.ai/project/workflows/<새 이름>.md` 다.

| 조건 | 동작 |
|---|---|
| 원래 문서나 새 문서의 경로에 링크 성분이 있다(파일 자신 포함) | 11-4 의 안내문(`-->` 는 링크인 성분)을 내고 종료 코드 2 |
| 새 문서의 자리에 무엇이든 있다(파일 · 디렉터리 · 링크) | 아래 안내문을 내고 종료 코드 2 |
| 둘 다 아니다 | 설정을 쓰고 지금처럼 render 한다. 원래 문서가 있으면 11-3 의 공용 함수를 거쳐 새 문서로 옮긴다 |

```
error: cannot rename the workflow notes — a file is already at the new name
  --> .ai/project/workflows/quickfix.md
nothing was changed

help: move that file aside or merge it into the old notes, then rename again
        harness steps hotfix --rename quickfix
```

- 멈추면 `harness.toml` · 두 문서가 그대로다
- 하네스가 덮어쓰는 것은 3절이 정한 경우(이전 매니페스트에 있는 관리 · 생성 파일과 `--adopt`)뿐이다. `steps --rename` 은 덮지 않는다
- `steps <절차> --delete` 는 지금처럼 문서를 남긴다
