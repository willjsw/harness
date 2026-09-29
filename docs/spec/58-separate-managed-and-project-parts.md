# 관리 부품과 프로젝트 부품의 경계, 관리 파일 변조 감지

대상 리포에서 하네스 것과 프로젝트 것의 자리를 나눈다. 프로젝트 스크립트는 `script/project/` 에 두고,
하네스가 쓸 경로에 이미 있는 사용자 파일은 덮지 않고 멈춘다. `.harness/managed` 는 관리 파일과 고정 사본의
sha256 을 담고, `check`·`doctor` 는 그것과 대조해 바뀐 관리 파일을 보고한다. 전역 CLI 는 고정 사본으로 넘기기 전에
같은 버전의 자기 파일과 사본을 대조한다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 충돌 판정 · 매니페스트 읽기·쓰기(`previous()` · `prune()` · `cmd_render` · `cmd_install`) · `cmd_check` · `cmd_doctor` · `delegate()` | `src/bin/harness` |
| 프로젝트 스크립트 표 | `src/templates/owned/script/project/README.md` (새 소유 파일) |
| 규칙 문서 3·9·10장 문구 | `src/templates/generated/.ai/AI_AGENT.md` |
| 하네스 스크립트 표 | `src/templates/managed/script/README.md` |
| 문서 정리자 계약 | `src/templates/managed/.ai/templates/docs-writer.md` |
| 사람용 설명 | `src/templates/managed/docs/workflow/changing.md` · `README.md` |
| UI doctor 문구 | `src/ui/lib/doctor.js` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/ui/lib/doctor.test.js` |

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

`previous()` 는 두 형식을 모두 읽고 경로 목록을 돌려준다.

| 줄 | 경로 | 해시 |
|---|---|---|
| `^[0-9a-f]{64}  (.+)$` 에 맞는다 | 두 번째 부분 | 첫 번째 부분 |
| 그 밖의 비어 있지 않은 줄 (옛 형식) | 줄 전체(앞뒤 공백 제거) | 없음 |
| 빈 줄 | 건너뛴다 | — |

- 경로와 해시의 짝이 필요한 쪽(4절 · 3절)은 같은 규칙으로 읽는 별도 함수를 쓴다. `prune()` · `cmd_uninstall` · 충돌 판정은 경로만 쓴다
- 옛 형식 매니페스트는 render 가 다음에 쓸 때 새 형식이 된다
- 옛 하네스 사본이 새 형식을 읽으면 해시 토큰을 경로로 보고, 그 경로에 파일이 없으므로 `prune()` · `uninstall` 이 건너뛴다

### 2-4. 정리와 설치에서의 매니페스트

- `prune()` 은 `.harness/` 로 시작하는 경로를 지우지 않는다
- `cmd_install` 은 `.harness/` 를 새 사본으로 갈아 끼울 때 `.harness/generated` · `.harness/managed` 를 남긴다.
  고정 사본 줄만 새 사본의 것으로 바꾼다 — 매니페스트가 사라지면 이전에 깐 하네스 파일 전부가 3절의 사용자 파일로 판정된다
- `cmd_uninstall` 은 지금처럼 두 매니페스트의 경로를 지우고 `.harness/` 를 걷는다

## 3. 사용자 파일 덮어쓰기 차단

### 3-1. 판정

**사용자 파일**은 이번 render 가 쓸 경로(관리 파일 · 생성 파일)에 이미 있으면서, 이전 매니페스트
(`.harness/generated` ∪ `.harness/managed` 의 경로)에 없는 것이다.

- 판정 대상은 관리 파일 경로(쓰지 않는 역할의 계약처럼 건너뛰는 경로는 뺀다)와 `plan()` 의 경로 전부다.
  `.claude/agents/` · `.claude/commands/` · `.claude/settings.json` · `CLAUDE.md` · `AGENTS.md` 가 여기 든다
- 소유 파일과 CI 골격은 대상이 아니다 — 원래 없을 때만 깐다
- 내용이 같아도 사용자 파일이다. 판정은 경로만 본다
- 경로에 디렉터리가 있으면 사용자 파일이다
- 이전 매니페스트에 있는 경로는 하네스 것이다 — 사람이 고쳤어도 지금처럼 덮는다(4절이 덮기 전의 변경을 보고한다)

### 3-2. 순서

1. render 는 **어떤 파일도 쓰기 전에** 3-1 판정을 돈다 — 소유 파일과 CI 골격을 깔기 전이다
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
- `--adopt` 로도 넘겨받을 수 없는 경로(3-4)가 있으면 그 줄 끝에 사유를 붙인다: `(a directory)` · `(<path>.orig already exists)`

### 3-4. `--adopt`

`install` · `render` · `set` · `steps` · `checks` 가 받는다. UI 는 넘기지 않는다.

- 사용자 파일마다 원래 파일을 같은 디렉터리의 `<경로>.orig` 로 옮기고(권한 비트 유지), 하네스 것을 쓴다
- `.orig` 파일은 매니페스트에 넣지 않는다. render 가 덮지도 지우지도 않고, `uninstall` 도 남긴다
- 넘겨받은 파일마다 표준 출력에 한 줄: ``render: adopted <경로> — yours is at <경로>.orig``
- 아래 경로가 하나라도 있으면 `--adopt` 여도 3-2 의 2 처럼 아무것도 쓰지 않고 멈춘다. 안내문은 3-3 이다
  - 경로에 디렉터리가 있다
  - `<경로>.orig` 가 이미 있다
- 사용자 파일이 없으면 `--adopt` 는 아무 일도 하지 않는다

### 3-5. 설정을 바꾸는 명령

- `set` · `steps` · `checks` 는 render 가 3-2 의 2 로 멈추면 설정을 바꾸기 전의 내용으로 되돌리고
  `reverted — the config is unchanged` 를 표준 오류로 낸 뒤 종료 코드 2 로 끝난다
- `steps --dry-run` 은 render 를 부르지 않으므로 이 판정에 닿지 않는다

### 3-6. `install`

- `cmd_install` 은 등록 판정 뒤, `.harness/` 를 바꾸기 전에 3-1 판정을 돈다. 판정은 설치하려는 CLI 의 템플릿과 설정으로 한다
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

고정 사본 줄도 같은 표로 가른다.

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

`render-test.sh` 에 새 `UT-<번호>` 블록 셋을 둔다. 번호는 기존 블록과 겹치지 않게 고른다(중복은 회귀 테스트가 잡는다).
등록부는 기존처럼 `HARNESS_HOME` 을 쓴다.

### 7-1. 사용자 파일 덮어쓰기 차단

| 케이스 | 확인하는 것 |
|---|---|
| 첫 설치의 겹침 | 설치 전에 사용자 `CLAUDE.md` 와 `script/review-mr.sh` 를 두면 `install` 이 종료 코드 2. 표준 오류에 두 경로와 `nothing was written` · `--adopt` · `script/project/`. 두 파일 내용이 그대로, `.harness/` · `.ai/AI_AGENT.md` · `script/project/README.md` 가 없고, 등록부에 `project.json` 이 없다 |
| 넘겨받기 | 같은 상태에서 `install --adopt` 가 종료 코드 0. `CLAUDE.md.orig` · `script/review-mr.sh.orig` 가 원래 내용이고, 두 경로가 매니페스트에 있고 `.orig` 는 없다. 표준 출력에 `adopted` 두 줄 |
| 넘겨받을 수 없음 | `CLAUDE.md.orig` 가 이미 있으면 `install --adopt` 가 종료 코드 2 이고 아무것도 바뀌지 않는다. 경로에 디렉터리가 있을 때도 같다 |
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

터미널 출력의 한글 검사는 세 블록의 출력에도 적용한다.

### 7-4. 기존 케이스

- 설치 전에 하네스가 쓸 경로에 파일을 두는 기존 케이스는 그 파일을 두지 않거나 `--adopt` 를 준다. 케이스가 검증하는 내용은 바꾸지 않는다
- 매니페스트를 경로 목록으로 읽는 기존 검사는 2-1 형식에 맞춘다
- "관리 파일을 덮는다" 케이스(관리 파일에 줄을 더하고 render 하면 사라진다)는 그대로 통과해야 한다

### 7-5. `doctor.test.js`

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
| 같은 파일 "검사하지 않는 것" | 고정 사본(`.harness/bin` · `.harness/templates`)을 고치면 pre-commit · `run-lint-test.sh` · CI 의 검사도 고친 사본이 돈다. 사본과 매니페스트를 함께 고치면 그 검사들은 알아채지 못한다. 사본 변조를 잡는 것은 같은 버전의 전역 CLI 가 넘기기 전에 하는 대조뿐이고, 그것도 경고만 한다 |

## 9. 결정 기록

5절의 대조 방식 — 전역 CLI 와 고정 버전이 같을 때만 사본을 전역 CLI 의 파일과 직접 비교하고, 다르면 대조하지 않는다는 한 줄을
내며, 불일치는 경고한 뒤 그대로 넘긴다 — 은 새 결정 기록 대상이다. 번호는 `docs/adr/` 의 다음 번호다.

## 10. 한계

- 목표는 감지다. 파이썬 사본은 막을 수 없고, 바이너리로 묶지 않는다
- 고정 사본을 고치면 그 사본이 도는 검사(`check` · `doctor` · 훅 · CI)는 고친 기준으로 돈다(8절 "검사하지 않는 것")
- 5절 대조는 이 기기에 같은 버전의 전역 CLI 가 있을 때만 돈다. 전역 CLI 가 같은 버전 번호의 수정된 작업 트리이면 그 차이도 다름으로 보고한다
- 줄바꿈을 바꾸는 git 설정(`core.autocrlf`)으로 체크아웃하면 파일 바이트가 달라져 `modified managed file` 로 보고된다
- `script/` 루트에 이미 있는 프로젝트 스크립트는 그 자리에 남는다. 하네스가 같은 이름을 들일 때에야 3절이 알린다
