# #58 task

## T1 · feat: 프로젝트 스크립트 자리 `script/project/` 와 소유 원형 추가

### 상위 Requirement

- relates to #58

### 작업 내용

대상 리포에서 프로젝트 자동화 스크립트의 자리를 `script/project/` 로 정하고, 그 안에 소유 파일 `script/project/README.md` 하나를
없을 때만 깐다. 규칙 문서·관리 문서가 프로젝트 스크립트를 관리 파일 `script/README.md` 에 적으라고 지시하던 문구를 이 자리로 보낸다.

- 명세 1절(1-1 자리 · 1-2 원형 · 1-3 의 README.md 두 행을 뺀 나머지) · 7-1 의 소유 원형 · 불변식 케이스
- 새 소유 원형 `src/templates/owned/script/project/README.md`: 이 디렉터리가 프로젝트 것이고 하네스 갱신이 건드리지 않는다는 것,
  하네스 스크립트는 `script/README.md` 에 있고 `script/` 바로 아래에 두면 하네스 갱신과 겹칠 수 있다는 것, 열이
  `스크립트 | 용도 | 호출 시점` 인 빈 표와 그 아래 "스크립트를 추가하면 이 표에 한 줄 추가한다" 한 줄. `TBD` 자리표시자를 넣지 않는다
- `src/templates/generated/.ai/AI_AGENT.md`: 3장 끝 문단, 9장 문서 지도의 `script/README.md` 행과 새 `script/project/README.md` 행,
  10장 하네스 배치의 새 `script/project/` 소유 행과 관리 행의 `script/` 가 `script/project/` 를 뺀 나머지라는 표기
- `src/templates/managed/script/README.md` 부류 표의 **소유** 행(`project/`)과 끝 문장의 대상(하네스 스크립트) 명시
- `src/templates/managed/.ai/templates/docs-writer.md` 2단계의 "스크립트가 늘었으면" 줄
- `src/templates/managed/docs/workflow/changing.md` "프로젝트가 쓰는 것 (소유 파일)" 표의 새 행
- `.ai/project/review-checks.md`(이 리포, 보호 문서 아님)의 "관리 스크립트를 더했으면" 점검이 가리키는 표를 `src/templates/managed/script/README.md` 로
- `render-test.sh` 에 새 `UT-<번호>` 블록(사용자 파일과 소유 자리): 소유 원형과 불변식 케이스. T3 이 이 블록에 케이스를 더한다
- 이 리포에서 render 해 생성물(`.ai/AI_AGENT.md`)·설치된 관리 파일·`script/project/README.md` 를 함께 커밋한다
- 건드릴 파일: `src/templates/owned/script/project/README.md`(신규), `src/templates/generated/.ai/AI_AGENT.md`,
  `src/templates/managed/script/README.md`, `src/templates/managed/.ai/templates/docs-writer.md`,
  `src/templates/managed/docs/workflow/changing.md`, `.ai/project/review-checks.md`, `src/test/render-test.sh`

### 완료 조건

- [ ] render 가 `script/project/README.md` 를 없을 때만 깔고, 고친 내용을 다음 render 가 덮지 않는다
- [ ] `uninstall` 이 `script/project/README.md` 를 남기고 `uninstall --purge` 가 지운다
- [ ] 관리 파일 경로와 `plan()` 경로 가운데 `script/project/` 로 시작하는 것이 없다
- [ ] 생성된 `.ai/AI_AGENT.md` 3장이 프로젝트 스크립트를 `script/project/` 와 `script/project/README.md` 표로 보내고, 9장·10장에 `script/project/` 행이 있다
- [ ] `doctor` 의 `project facts` 절이 새 소유 원형으로 자리표시자 경고를 내지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 소유 원형을 없을 때만 깐다 | 새 리포에 install | `script/project/README.md` 가 원형 내용으로 있다 |
| UT-02 | 고친 소유 원형을 덮지 않는다 | `script/project/README.md` 에 줄을 더하고 render | 더한 줄이 남는다 |
| UT-03 | uninstall 이 남긴다 | 설치된 리포에서 `uninstall` | `script/project/README.md` 가 있다 |
| UT-04 | purge 가 지운다 | 설치된 리포에서 `uninstall --purge --yes` | `script/project/README.md` 가 없다 |
| UT-05 | 하네스는 `script/project/` 에 쓰지 않는다 | `src/templates/managed/` · `src/templates/generated/` 의 경로와 `plan()` 경로 | `script/project/` 로 시작하는 것이 없다 |
| UT-06 | 규칙 문서가 새 자리를 가리킨다 | render 뒤 `.ai/AI_AGENT.md` | `script/project/README.md` 가 3장·9장에, `script/project/` 소유 행이 10장에 있다 |

## T2 · feat: `.harness/managed` 에 관리 파일과 고정 사본의 sha256 기록

### 상위 Requirement

- relates to #58

### 작업 내용

`.harness/managed` 를 경로 목록에서 `<sha256>  <경로>` 줄로 바꾸고, install 이 고정 사본의 해시를, render 가 관리 파일의 해시를 기록하게 한다.
옛 형식 매니페스트도 읽는다. 재설치가 매니페스트를 지우지 않게 한다.

- 명세 2절(2-1 형식 · 2-2 담는 것 · 2-3 읽기 · 2-4 정리와 설치) · 7-2 의 형식 · 옛 형식 읽기 케이스 · 7-5 의 매니페스트 읽기
- 줄 형식: sha256 소문자 16진 64자, 공백 두 칸, 하네스 루트 기준 상대 경로. 경로 순 정렬, LF 끝
- `previous()` 는 두 형식을 명세 2-3 표대로 읽어 경로 목록을 돌려준다. 경로와 해시 짝을 돌려주는 읽기 함수를 따로 둔다 — T4 · T5 가 쓴다.
  옛 형식 줄의 해시는 없음이다
- `cmd_render`: 관리 파일 줄은 이번에 깐 내용으로 새로 계산하고, `.harness/` 로 시작하는 줄은 이전 매니페스트에서 해시째 그대로 옮긴다.
  고정 사본의 해시를 계산하지 않는다. `.harness/bin/harness` 가 없는 하네스 루트에서는 `.harness/` 줄을 쓰지도 옮기지도 않는다
- `prune()` 은 `.harness/` 로 시작하는 경로를 지우지 않는다
- `install_registered`: `.harness/` 를 새 사본으로 갈아 끼울 때 `.harness/generated` · `.harness/managed` 를 남기고, 사본을 깐 직후
  `.harness/bin/` · `.harness/templates/` 아래 파일 전부(`__pycache__/` 제외)와 `.harness/VERSION` 의 줄을 새 사본의 것으로 바꾼다.
  소스 리포 분기는 고정 사본 줄을 쓰지 않는다
- `cmd_uninstall` 은 두 매니페스트의 경로를 지금처럼 지운다 — 새 `previous()` 로 읽는다
- 매니페스트를 경로 목록으로 읽는 기존 검사를 새 형식에 맞춘다. 검증하는 내용은 바꾸지 않는다
- `render-test.sh` 에 새 `UT-<번호>` 블록(매니페스트와 대조): 형식 · 옛 형식 읽기 케이스. T4 · T5 가 이 블록에 케이스를 더한다
- 이 리포에서 render 해 새 형식의 `.harness/managed` 를 함께 커밋한다
- 건드릴 파일: `src/bin/harness`(`previous()` · 새 읽기 함수 · `prune()` · `cmd_render` · `install_registered` · `cmd_uninstall`), `src/test/render-test.sh`

### 완료 조건

- [ ] 설치 뒤 `.harness/managed` 의 줄이 전부 `<64자 16진>  <경로>` 이고 경로 순이다
- [ ] 관리 파일 · `.harness/bin/harness` · `.harness/VERSION` · `.harness/templates/harness.toml` 줄이 있고, `__pycache__/` 아래 경로가 없다
- [ ] 하네스 루트에서 `shasum -a 256 -c .harness/managed` 가 통과한다
- [ ] 고정 사본 파일을 고친 뒤 render 해도 그 파일의 줄의 해시가 바뀌지 않는다
- [ ] 재설치 뒤 `.harness/generated` · `.harness/managed` 가 남고, 고정 사본 줄이 새 사본의 해시다
- [ ] 옛 형식 매니페스트에서 render 하면 더는 깔지 않게 된 관리 파일이 지워지고 매니페스트가 새 형식이 된다
- [ ] 소스 리포의 `.harness/managed` 에 `.harness/` 로 시작하는 줄이 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 줄 형식 | 새 리포에 install 뒤 `.harness/managed` | 모든 줄이 `^[0-9a-f]{64}  .+$`, 경로 순 |
| UT-02 | 담는 줄 | 같은 매니페스트 | `script/review-mr.sh` · `.harness/bin/harness` · `.harness/VERSION` · `.harness/templates/harness.toml` 줄이 있다 |
| UT-03 | 외부 도구로 확인된다 | 하네스 루트에서 `shasum -a 256 -c .harness/managed` | 종료 코드 0 |
| UT-04 | render 는 사본 해시를 다시 계산하지 않는다 | `.harness/templates/` 아래 파일 하나를 고치고 render | 그 줄의 해시가 설치 때와 같다 |
| UT-05 | 재설치가 매니페스트를 남긴다 | 설치된 리포에서 다시 install | 두 매니페스트가 있고 관리 파일 줄이 그대로, 고정 사본 줄이 새 사본과 일치한다 |
| UT-06 | 옛 형식 읽기 | 매니페스트를 경로 목록으로 바꾸고, 역할 하나를 설정에서 빼 그 계약이 더는 깔리지 않게 render | 그 계약 파일이 지워지고 매니페스트가 새 형식이다 |
| UT-07 | 정리가 사본을 지우지 않는다 | 설치된 리포에서 설정을 바꿔 render | `.harness/bin/harness` 가 남는다 |
| UT-08 | 소스 리포 | 소스 트리 복제본에서 install | `.harness/managed` 에 `.harness/` 줄이 없다 |

## T3 · feat: 하네스가 쓸 경로의 사용자 파일을 덮지 않고 멈추고 `--adopt` 로 넘겨받음

### 상위 Requirement

- relates to #58

### 작업 내용

render · install 이 관리 파일이나 생성 파일을 쓸 경로에 이전 매니페스트에 없는 파일(사용자 파일)이 있으면 아무것도 쓰지 않고 종료 코드 2
로 멈추게 한다. `--adopt` 를 주면 원래 파일을 `<경로>.orig` 로 옮기고 넘겨받는다. 설정을 바꾸는 명령은 멈추면 설정을 되돌린다.

- 명세 3절(3-1 판정 · 3-2 순서 · 3-3 안내문 · 3-4 `--adopt` · 3-5 설정을 바꾸는 명령 · 3-6 install) · 6절의 충돌 판정 · 7-1 의 나머지 케이스 · 7-5 의 기존 케이스
- 판정 함수: 이번 render 가 쓸 관리 파일 경로(쓰지 않는 역할의 계약처럼 건너뛰는 경로 제외)와 `plan()` 경로 가운데, 이미 있으면서
  (디렉터리 포함) `.harness/generated` ∪ `.harness/managed` 의 경로에 없는 것. 내용은 보지 않는다. 소유 파일과 CI 골격은 대상이 아니다
- 경로에 디렉터리가 있으면 이전 매니페스트에 있어도 사용자 파일이다. 쓸 경로(관리 파일 · 생성 파일 · 소유 파일 · CI 골격 · 매니페스트)의 부모 가운데
  디렉터리가 아닌 것은 그 부모를 사용자 파일로 판정하고 `(not a directory)` 를 붙인다. 심볼릭 링크는 이 판정에 넣지 않는다 — T9 의 사전 판정이 막는다
- `cmd_render`: 소유 파일과 CI 골격을 깔기 전에 판정한다. 사용자 파일이 있으면 명세 3-3 의 안내문을 표준 오류로 내고 종료 코드 2.
  `script/` 아래 경로가 있으면 `help:` 에 `project scripts belong in script/project/, which the harness never writes` 를 더하고,
  넘겨받을 수 없는 경로에는 `(a directory)` · `(<path>.orig already exists)` 를 붙인다
- `--adopt`: argparse 옵션으로 더하고 `install` · `render` · `set` · `steps` · `checks` 가 받는다. 사용자 파일마다 `<경로>.orig` 로 옮기고
  (권한 비트 유지) 하네스 것을 쓰며 표준 출력에 `render: adopted <경로> — yours is at <경로>.orig`. 넘겨받을 수 없는 경로가 하나라도 있으면
  아무것도 쓰지 않고 멈춘다. `.orig` 는 매니페스트에 넣지 않는다
- `set` · `steps` · `checks`: render 가 사용자 파일로 멈추면 `harness.toml` 을 바꾸기 전 내용으로 되돌리고 `reverted — the config is unchanged`
  를 표준 오류로 낸 뒤 종료 코드 2. `steps --dry-run` 은 판정에 닿지 않는다
- `cmd_install`: 등록 판정 뒤, `.harness/` 를 바꾸기 전에 설치하려는 CLI 의 템플릿과 설정으로 판정한다. 멈추면 `.harness/` · 생성 파일 · 등록부가
  그대로다. 소스 리포 분기는 옛 사본을 걷어내기 전에 판정한다
- `<명령>` 자리에는 사용자가 부른 명령 이름을 넣는다
- `render-test.sh` 의 T1 블록에 명세 7-1 의 첫 설치의 겹침 · 넘겨받기 · 넘겨받을 수 없음 · 재설치 · 다른 이름의 사용자 스크립트(render 부분) ·
  설정을 바꾸는 명령 케이스를 더한다
- 설치 전에 하네스가 쓸 경로에 파일을 두는 기존 케이스는 그 파일을 두지 않거나 `--adopt` 를 준다. 검증하는 내용은 바꾸지 않는다.
  "관리 파일을 덮는다" 케이스는 그대로 통과한다
- 건드릴 파일: `src/bin/harness`(판정 함수 · `cmd_render` · `cmd_install` · `install_registered` · `cmd_set` · `cmd_steps` · `cmd_checks` · `main()`), `src/test/render-test.sh`

### 완료 조건

- [ ] 설치 전에 사용자 `CLAUDE.md` 와 `script/review-mr.sh` 를 두면 `install` 이 종료 코드 2 이고, 표준 오류에 두 경로 · `nothing was written` · `--adopt` · `script/project/` 가 있다
- [ ] 멈춘 install 뒤 두 파일 내용이 그대로이고 `.harness/` · `.ai/AI_AGENT.md` · `script/project/README.md` · 등록부의 `project.json` 이 없다
- [ ] `install --adopt` 가 종료 코드 0 이고 `.orig` 두 파일이 원래 내용, 두 경로가 매니페스트에 있고 `.orig` 는 없으며 표준 출력에 `adopted` 두 줄이 있다
- [ ] `<경로>.orig` 가 이미 있거나 경로에 디렉터리가 있으면 `install --adopt` 가 종료 코드 2 이고 아무것도 바뀌지 않는다
- [ ] 새 리포에 일반 파일 `script` 를 두고 install 하면 종료 코드 2 이고 표준 오류에 `script (not a directory)` 가 있으며 고정 사본 · 생성물 · 소유 파일 · 등록부가 없다
- [ ] 설치된 리포에서 재설치가 종료 코드 0 이고, 고친 관리 파일이 덮인다
- [ ] 하네스가 쓰지 않는 이름의 `script/deploy.sh` 가 있어도 render 가 통과하고 그 파일이 그대로다
- [ ] `steps` · `set` 이 사용자 파일로 멈추면 종료 코드 2, `reverted`, `harness.toml` 이 바이트 단위로 그대로다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 첫 설치의 겹침 | 설치 전 사용자 `CLAUDE.md` · `script/review-mr.sh` 를 두고 install | 종료 코드 2, 표준 오류에 두 경로 · `nothing was written` · `--adopt` · `script/project/`, 두 파일 그대로, `.harness/` · `.ai/AI_AGENT.md` · `script/project/README.md` · `project.json` 없음 |
| UT-02 | 넘겨받기 | 같은 상태에서 `install --adopt` | 종료 코드 0, `.orig` 두 파일이 원래 내용, 두 경로가 매니페스트에 있고 `.orig` 는 없음, 표준 출력에 `adopted` 두 줄 |
| UT-03 | `.orig` 가 이미 있음 | `CLAUDE.md.orig` 를 더 두고 `install --adopt` | 종료 코드 2, 표준 오류에 `.orig already exists`, 파일이 전부 그대로 |
| UT-04 | 경로에 디렉터리 | `CLAUDE.md` 자리에 디렉터리를 두고 `install --adopt` | 종료 코드 2, 표준 오류에 `(a directory)`, 아무것도 바뀌지 않음 |
| UT-05 | 재설치 | 설치된 리포에서 관리 파일을 고친 채 다시 install | 종료 코드 0, 고친 관리 파일이 하네스 내용으로 돌아온다 |
| UT-06 | 다른 이름의 사용자 스크립트 | `script/deploy.sh` 를 두고 render | 종료 코드 0, 그 파일 그대로 |
| UT-07 | 설정을 바꾸는 명령 — steps | 사용자 `.claude/commands/<새 절차>.md` 를 두고 `steps` 로 그 이름의 절차 생성 | 종료 코드 2, 표준 오류에 `reverted`, `harness.toml` 바이트 단위로 그대로 |
| UT-08 | 설정을 바꾸는 명령 — set | 새 생성 경로가 생기는 값에 대응하는 경로에 사용자 파일을 두고 `set` | 종료 코드 2, `reverted`, `harness.toml` 그대로 |
| UT-09 | render 도 쓰기 전에 멈춘다 | 설치된 리포에서 설정을 바꿔 새 생성 경로가 생기게 하고 그 경로에 사용자 파일을 둔 뒤 render | 종료 코드 2, 소유 파일 · 매니페스트가 그대로 |
| UT-10 | 한글 없는 출력 | UT-01 ~ UT-09 의 표준 출력·표준 오류 | 한글이 없다 |
| UT-11 | 디렉터리가 아닌 부모 | 새 리포에 일반 파일 `script` 를 두고 install | 종료 코드 2, 표준 오류에 `script (not a directory)`, 고정 사본 · 생성물 · 소유 파일 · 등록부 없음 |

## T4 · feat: check 가 관리 파일과 고정 사본을 매니페스트와 대조

### 상위 Requirement

- relates to #58

### 작업 내용

`harness check` 가 생성 파일 어긋남에 더해 `.harness/managed` 의 해시와 현재 관리 파일·고정 사본을 대조해, 바뀌거나 없어진 파일이 있으면
종료 코드 1 로 보고하게 한다.

- 명세 4-1 판정 · 4-2 `harness check` · 6절의 check · 7-2 의 옛 형식 대조(check) · 관리 파일 변경 · staged · 고정 사본 변경 케이스
- 판정 함수: T2 의 해시 짝 읽기로 줄마다 현재 파일(staged 면 `git show :<경로>` 의 바이트)의 sha256 과 비교해 일치 · `modified managed file` ·
  `missing managed file` 로 가른다. 해시가 없는 줄은 비교하지 않는다. 매니페스트 자신은 작업 트리에서 읽는다. T5 가 이 함수를 쓴다
- `cmd_check`: 생성 파일 어긋남과 관리 파일 어긋남을 함께 보고한다. 출력은 명세 4-2 원문(경로 열 `%-52s`), 고정 사본 경로가 있으면
  `help:` 에 `the pinned copy under .harness/ comes back with \`harness install\``. 통과하면 기존 줄 뒤에
  `check: <N> managed files match the manifest`
- `render-test.sh` 의 T2 블록에 위 케이스를 더한다. "관리 파일을 덮는다" 케이스는 그대로 통과한다
- 건드릴 파일: `src/bin/harness`(판정 함수 · `cmd_check`), `src/test/render-test.sh`

### 완료 조건

- [ ] `script/review-mr.sh` 를 고치면 `check` 가 종료 코드 1 이고 표준 오류에 `modified managed file` 과 그 경로가 있다
- [ ] 그 파일을 지우면 `missing managed file` 이고, render 뒤 `check` 가 종료 코드 0 이다
- [ ] 고친 관리 파일을 스테이징하면 `check --staged` 가 1, 작업 트리만 고치면 `check --staged` 가 0 이다
- [ ] `.harness/templates/` 아래 파일을 고치면 `check` 가 1 이고 `help:` 에 `harness install` 이 있으며, render 뒤에도 1 이다
- [ ] 옛 형식 매니페스트에서 `check` 가 종료 코드 0 이다
- [ ] 통과한 `check` 의 표준 출력에 `managed files match the manifest` 줄이 있다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 관리 파일 변경 | `script/review-mr.sh` 에 줄을 더하고 `check` | 종료 코드 1, 표준 오류에 `modified managed file` 과 `script/review-mr.sh` |
| UT-02 | 관리 파일 없음 | `script/review-mr.sh` 삭제 뒤 `check` | 종료 코드 1, `missing managed file` |
| UT-03 | render 로 복구 | UT-01 뒤 render, `check` | 종료 코드 0 |
| UT-04 | staged 변경 | 고친 관리 파일을 `git add` 하고 `check --staged` | 종료 코드 1 |
| UT-05 | 작업 트리만 변경 | 고치고 스테이징하지 않은 채 `check --staged` | 종료 코드 0 |
| UT-06 | 고정 사본 변경 | `.harness/templates/` 아래 파일을 고치고 `check`, 이어서 render 뒤 `check` | 둘 다 종료 코드 1, `help:` 에 `harness install` |
| UT-07 | 옛 형식 대조 | 매니페스트를 경로 목록으로 바꾸고 `check` | 종료 코드 0 |
| UT-08 | 생성 파일과 함께 | 생성 파일과 관리 파일을 함께 고치고 `check` | 종료 코드 1, 두 오류가 모두 나온다 |
| UT-09 | 통과 줄 | 설치 직후 `check` | 표준 출력에 `managed files match the manifest` |

## T5 · feat: doctor 에 관리 파일 절과 UI 문구 추가

### 상위 Requirement

- relates to #58

### 작업 내용

`harness doctor` 의 결과 목록에 `managed files` 절을 더해 바뀌거나 없어진 관리 파일과 해시가 없는 매니페스트를 보고하고, UI Doctor 가 그 항목을
한국어로 옮기게 한다. doctor 결과 목록은 #59 가 만든 구조(`section` · `state` · `what` · `detail`)를 쓴다.

- 명세 4-3 `harness doctor` · 4-4 UI 문구 · 6절의 doctor · 7-1 의 다른 이름의 사용자 스크립트(doctor 부분) · 7-2 의 옛 형식 대조(doctor) · doctor 항목 · 7-6
- `cmd_doctor`: `generated files` 절 바로 뒤에 `managed files` 절. T4 의 판정 함수로 명세 4-3 표의 항목을 낸다. `bad` 는 경로 순 10개까지,
  넘으면 `<N> more modified or missing managed file(s)` 한 항목. `.harness/managed` 가 없으면 `warn` `no manifest of managed files` 한 항목만.
  `.harness/bin/harness` 가 있는데 고정 사본 줄이 없거나 해시가 없으면 `warn` `the pinned copy has no recorded hash`
- `src/ui/lib/doctor.js`: `SECTIONS` 에 `"managed files": "관리 파일"`, `explain()` 이 명세 4-4 표의 다섯 항목을 옮긴다. `.harness/` 로 시작하는
  detail 의 `modified` · `missing` 항목은 조치를 `cmd`: `harness install` 로 한다
- `render-test.sh` 의 T2 블록에 doctor 항목 · 옛 형식 대조(doctor) 케이스를, T1 블록의 다른 이름의 사용자 스크립트 케이스에 doctor 확인을 더한다
- `doctor.test.js` 에 명세 7-6 케이스
- 건드릴 파일: `src/bin/harness`(`cmd_doctor`), `src/ui/lib/doctor.js`, `src/ui/lib/doctor.test.js`, `src/test/render-test.sh`

### 완료 조건

- [ ] 설치 직후 `harness status` 의 `doctor.items` 에서 `section` 이 `managed files` 인 항목이 `ok` 하나다
- [ ] `script/review-mr.sh` 를 고치면 `state` `bad` · `what` `modified managed file` · `detail` `script/review-mr.sh` 항목이 있다
- [ ] 관리 파일 11개 이상이 바뀌면 `bad` 경로 항목이 10개이고 `more modified or missing managed file(s)` 항목이 하나 있다
- [ ] 옛 형식 매니페스트에서 `have no recorded hash` `warn` 항목이 있고, `.harness/managed` 가 없으면 `no manifest of managed files` 한 항목만 있다
- [ ] `script/deploy.sh` 가 있어도 `managed files` 절에 `bad` · `warn` 이 없다
- [ ] UI Doctor 의 절 이름이 `관리 파일` 이고, 다섯 항목이 한국어로 옮겨진다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 일치 | 설치 직후 `harness status` | `managed files` 절이 `ok` 항목 하나 |
| UT-02 | 변경 항목 | `script/review-mr.sh` 를 고치고 `harness status` | `bad` · `modified managed file` · `script/review-mr.sh` 항목 |
| UT-03 | 없음 항목 | 관리 파일 하나 삭제 뒤 `harness status` | `bad` · `missing managed file` 항목 |
| UT-04 | 개수 제한 | 관리 파일 11개를 고치고 `harness status` | 경로 `bad` 항목 10개와 `1 more modified or missing managed file(s)` |
| UT-05 | 옛 형식 | 매니페스트를 경로 목록으로 바꾸고 `harness status` | `warn` · `<N> managed files have no recorded hash`, 사본 줄도 없으므로 `the pinned copy has no recorded hash` |
| UT-06 | 매니페스트 없음 | `.harness/managed` 삭제 뒤 `harness status` | `managed files` 절이 `warn` · `no manifest of managed files` 한 항목 |
| UT-07 | 다른 이름의 사용자 스크립트 | `script/deploy.sh` 를 두고 `harness status` | `managed files` 절에 `bad` · `warn` 없음 |
| UT-08 | 절 이름 | `SECTIONS["managed files"]` | `"관리 파일"` |
| UT-09 | 변경 항목 문구 | `explain()` 에 `modified managed file` · detail `script/review-mr.sh` | 원문과 다른 제목, 본문에 그 경로와 `script/project/`, `run.kind` 가 `render` |
| UT-10 | 고정 사본 경로 | detail 이 `.harness/templates/harness.toml` 인 `modified managed file` | `cmd` 가 `harness install`, `run` 없음 |
| UT-11 | 사본 해시 없음 | `the pinned copy has no recorded hash` | `cmd` 가 `harness install` |

## T6 · feat: 전역 CLI 가 넘기기 전에 같은 버전의 고정 사본을 대조

### 상위 Requirement

- relates to #58

### 작업 내용

전역 CLI 가 고정 사본(`.harness/bin/harness`)으로 넘기기 직전에, 고정 버전이 자기 버전과 같으면 사본을 자기 파일과 바이트 단위로 비교해
다르면 표준 오류에 경고를 내고 그대로 넘기게 한다. 버전이 다르거나 읽히지 않으면 비교하지 않고 `cannot verify` 한 줄을 낸다.

- 명세 5절(5-1 버전 · 5-2 대조) · 6절의 `delegate()` · 7-3 · 결정 기록 0015
- `delegate()`: `DELEGATES` 명령 전부가 대상이다. 소스 리포에서는 대조하지 않고 줄도 내지 않는다
- 비교 쌍: `HERE / "harness"` ↔ `.harness/bin/harness`, `HERE / "harness_metrics.py"` ↔ `.harness/bin/harness_metrics.py`, `TEMPLATES` 아래 파일 전부 ↔
  `.harness/templates/` 아래 파일 전부. 다름은 해시가 다른 파일, 한쪽에만 있는 파일, `.harness/bin/` 의 위 두 파일 말고의 파일. `__pycache__/` 는 양쪽에서 뺀다.
  매니페스트를 읽지 않는다
- 출력은 명세 5-1 · 5-2 원문. `-->` 줄은 경로 순 10개까지, 넘으면 `  ... and <N> more`. 버전이 둘 다 읽히고 다르면 기존 `note: this project is pinned to …`
  두 줄도 그대로 낸다. 표준 출력에는 아무것도 내지 않고 종료 코드를 바꾸지 않는다
- `render-test.sh` 에 새 `UT-<번호>` 블록(고정 사본 대조). 전역 CLI 는 테스트의 `src/bin/harness`, 고정 사본은 그것으로 설치한 것
- 건드릴 파일: `src/bin/harness`(`delegate()` 와 대조 함수), `src/test/render-test.sh`

### 완료 조건

- [ ] 고치지 않은 사본에서 전역 CLI 로 `doctor` 를 부르면 표준 오류에 `warning:` · `cannot verify` 가 없다
- [ ] `.harness/templates/` 아래 파일을 고치면 표준 오류에 `warning: the pinned harness differs` · 그 경로 · `harness install --target` 이 있고, `status` 표준 출력이 JSON 으로 읽힌다
- [ ] `.harness/VERSION` 을 다른 값으로 바꾸면 `cannot verify` 줄이 한 번 나오고 `warning: the pinned harness differs` 가 없다
- [ ] `.harness/VERSION` 을 지우면 `cannot verify` 줄에 `no version` 이 있다
- [ ] 소스 트리 복제본에서 전역 CLI 로 `doctor` 를 부르면 `warning:` · `cannot verify` 가 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 일치 | 설치 직후 전역 CLI 로 `doctor` | 표준 오류에 `warning:` · `cannot verify` 없음 |
| UT-02 | 템플릿 변조 | `.harness/templates/` 아래 파일 하나를 고치고 전역 CLI 로 `doctor` · `status` | 표준 오류에 `warning: the pinned harness differs` · 그 경로 · `harness install --target`. 종료 코드가 고치기 전과 같고 `status` 표준 출력이 JSON |
| UT-03 | 실행 파일 변조 | `.harness/bin/harness` 에 주석 한 줄을 더하고 전역 CLI 로 `doctor` | 경고에 `.harness/bin/harness` |
| UT-04 | 사본에만 있는 파일 | `.harness/bin/` 에 파일 하나를 더하고 전역 CLI 로 `doctor` | 경고에 그 경로 |
| UT-05 | 개수 제한 | `.harness/templates/` 아래 파일 11개를 고치고 전역 CLI 로 `doctor` | `-->` 줄 10개와 `... and 1 more` |
| UT-06 | 버전 다름 | `.harness/VERSION` 을 다른 값으로 바꾸고 전역 CLI 로 `doctor` | `cannot verify` 줄 한 번, `warning: the pinned harness differs` 없음 |
| UT-07 | 버전 없음 | `.harness/VERSION` 을 지우고 전역 CLI 로 `doctor` | `cannot verify` 줄에 `no version` |
| UT-08 | 소스 리포 | 소스 트리 복제본에서 전역 CLI 로 `doctor` | `warning:` · `cannot verify` 없음 |
| UT-09 | 한글 없는 출력 | UT-01 ~ UT-08 의 표준 출력·표준 오류 | 한글이 없다 |

## T7 · docs: README 에 파일 부류의 프로젝트 스크립트 자리와 관리 파일 대조 반영

### 상위 Requirement

- relates to #58

### 작업 내용

사람용 README 의 파일 부류 표와 명령 표를 T1 ~ T5 가 만든 동작에 맞춘다.

- 명세 1-3 의 `README.md` 두 행
- "파일은 세 부류다" 표: **소유** 행에 `script/project/README.md` 를 더하고, **관리** 행의 `script/` 의 나머지에서 `script/project/` 를 뺀다.
  표 아래 한 문단 — 하네스가 쓸 경로에 이미 있는 파일은 덮지 않고 멈추며 `--adopt` 로 넘겨받는다(원래 파일은 `<경로>.orig`),
  `check` · `doctor` 가 바뀐 관리 파일을 보고한다
- "명령" 표: `check` 는 생성 파일이 설정과, 관리 파일이 매니페스트와 일치하는지. `doctor` 설명에 관리 파일 변조를 더한다
- 건드릴 파일: `README.md`

### 완료 조건

- [ ] README 의 파일 부류 표 소유 행에 `script/project/README.md` 가 있고 관리 행이 `script/project/` 를 뺀 나머지라고 적는다
- [ ] 표 아래 문단에 `--adopt` · `.orig` · `check` · `doctor` 가 있다
- [ ] 명령 표의 `check` · `doctor` 설명이 관리 파일 대조를 포함한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 문서 참조가 살아 있다 | 이 리포에서 `doctor` | `references` 절에 README 의 끊긴 참조 경고가 없다 |

## T8 · docs: 용어·아키텍처 문서에 소유 자리·매니페스트·사용자 파일·사본 대조 반영

### 상위 Requirement

- relates to #58

### 작업 내용

에이전트가 근거로 읽는 보호 문서 `.ai/project/glossary.md` · `.ai/project/architecture.md` 를 T1 ~ T6 이 만든 사실에 맞춘다.
보호 문서이므로 사람이 지시한 턴에서만 고친다.

- 명세 8절 표 가운데 "신뢰 경계" 행을 뺀 나머지. 그 행은 T14 가 반영한다
- `.ai/project/glossary.md`: "소유 파일" 목록에 `script/project/README.md`, "매니페스트" 의 새 정의(`.harness/generated` 는 생성 파일 경로,
  `.harness/managed` 는 관리 파일과 고정 사본의 sha256 과 경로, 정리·제거·변조 감지의 근거), 새 행 "사용자 파일"
- `.ai/project/architecture.md`: "구성 요소" 의 `script/` 항목(`script/project/` 는 프로젝트 것), "데이터 흐름" 의 렌더(사용자 파일 판정 · sha256 기록 ·
  `check` · `doctor` 대조 · 전역 CLI 의 사본 대조), "새 코드를 둘 곳"(새 관리 스크립트의 표는 `src/templates/managed/script/README.md`, 새 행
  대상 리포의 프로젝트 스크립트 → `script/project/` + `script/project/README.md`), "검사하지 않는 것"(사본과 매니페스트를 함께 고치면 훅 · 검증 일괄 · CI 가
  알아채지 못하고, 잡는 것은 같은 버전의 전역 CLI 대조뿐이며 경고만 한다)
- 이 리포에서 render 해 생성물(`.ai/AI_AGENT.md` 1~5장)을 함께 커밋한다
- 건드릴 파일: `.ai/project/glossary.md`, `.ai/project/architecture.md`, 생성물 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] glossary 의 "소유 파일" · "매니페스트" · "사용자 파일" 행이 명세 8절과 같은 사실을 담는다
- [ ] architecture 의 네 곳이 명세 8절과 같은 사실을 담는다
- [ ] render 뒤 `.ai/AI_AGENT.md` 에 두 문서의 변경이 반영되고 `check` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 두 문서를 고치고 render 뒤 `check` | 종료 코드 0 |
| UT-02 | 문서 참조가 살아 있다 | 이 리포에서 `doctor` | `references` 절에 두 문서의 끊긴 참조 경고가 없다 |

## T9 · feat: 경로 규칙과 공용 함수 `guarded_path()`, render 의 사전 판정과 변경 지점 전환

### 상위 Requirement

- relates to #58

### 작업 내용

하네스가 대상 리포를 바꾸는 경로의 규칙(11-2)을 함수 하나로 두고, 그 규칙을 지키는 경로만 돌려주는 공용 함수 `guarded_path()`(11-3)를 만든다.
render 가 무엇이든 바꾸기 전에 이번에 바꿀 경로 전부를 같은 규칙으로 판정하게 하고(11-4 의 render 행), render 가 대상 리포를 바꾸는 지점 여섯 곳을
공용 함수로 옮긴다. T3 이 사용자 파일 판정과 쓰기 지점마다 덧댄 링크 검사를 이 판정으로 대체한다. 결정 기록 0017.

- 명세 11-2 · 11-3 · 11-4 의 render 행과 안내문 · 11-1 의 지점 가운데 `copy_tree()` 두 곳 · 생성 파일 쓰기 · 매니페스트 쓰기 · `prune()` · `--adopt`,
  3-1 의 끝 줄(링크는 3-1 이 아니라 11-4 가 막는다) · 3-2 의 1(사전 판정 → 사용자 파일 판정) · 3-4 의 `.orig` 옮기기 · 3-5 의 사전 판정으로 멈춘 경우의 되돌리기 ·
  2-4 의 `prune()` · 11-6 · 7-4 의 심볼릭 링크 케이스 일부
- 경로 규칙 판정 함수: 하네스 루트 기준 상대 경로 문자열을 받아 어긋남의 사유를 돌려준다. 하네스 루트는 `--target` 을 `resolve()` 한 경로다
  - 형식(문자열만 본다): `/` 로 나눈 성분이 하나 이상이고 성분마다 `[\w.-]+`(`PROTECTED_PATH` 의 성분과 같은 문자 집합). 앞의 `/` · 끝의 `/` · 빈 성분 ·
    `.` · `..` 성분이 없다
  - 링크(`lstat`): 하네스 루트 아래의 성분 `a` · `a/b` · … · 경로 자신 가운데 심볼릭 링크가 없다. 링크 대상이 있는지와 상관없다. 하네스 루트 자신과
    그 위는 보지 않는다. 아직 없는 성분은 어긋남이 아니다. 없을 때만 까는 소유 파일 · CI 골격과 그 부모도 같다
  - 사유: 위에서부터 처음 맞는 하나 — `an absolute path` · `has a .. component` · `not a path` · `through a symbolic link`. 링크면 링크인 성분도 돌려준다.
    형식 판정은 파일 시스템을 보지 않는 부분으로 따로 부를 수 있게 둔다 — T11 의 매니페스트 검증이 그 부분만 쓰고 `a merge conflict marker` 를 앞에 더한다
- `guarded_path(root, rel, verb)`: `verb` 는 `create` · `write` · `remove` · `move`. 시스템 호출 바로 앞에서 판정하고 통과하면 `root / rel` 을 돌려준다.
  사전 판정이 통과시킨 경로도 다시 본다. 어긋나면 아무것도 하지 않고 명세 11-3 의 안내문을 표준 오류로 낸 뒤 종료 코드 2 —
  링크면 `error: refusing to <verb> through a symbolic link` 와 `-->` 링크인 성분, 형식이면
  `error: refusing to <verb> a path that is not safe under the harness root (<사유>)` 이고 경로를 출력하지 않는다
- 사전 판정(render): 관리 파일 경로 · `plan()` 의 경로 · 소유 파일과 CI 골격의 경로 · `.harness/generated` · `.harness/managed` · 정리가 지울 옛 경로,
  `--adopt` 면 넘겨받을 경로와 `<경로>.orig` 를 판정한다. 링크 성분이 하나라도 있으면 전부 모아 명세 11-4 의 안내문(`go through a symbolic link` ·
  `-->` 링크인 성분 경로 순 · 한 링크 아래 경로를 따로 나열하지 않음 · `nothing was changed` · `help:` 와 `harness <명령>`)을 내고 종료 코드 2.
  `<명령>` 은 사용자가 부른 명령이다. 사용자 파일 판정(3-1)보다 먼저 돈다
- `user_files()` 에서 링크 판정을 뺀다. 남는 것은 3-1 의 사용자 파일 · 디렉터리 · `(not a directory)` · `.orig` 판정이다
- 지점 전환 — 대상 리포를 바꾸는 시스템 호출을 전부 `guarded_path()` 가 돌려준 경로에 한다
  - `copy_tree()` 의 관리 파일과 소유 파일 · CI 골격: 디렉터리 만들기는 만들 디렉터리마다, 쓰기 · 권한은 그 파일
  - `cmd_render` 의 `plan()` 루프: 부모 디렉터리 만들기 · 쓰기 · 권한
  - 매니페스트 쓰기: `.harness/generated` 와 `write_manifest_hashes()`(install 이 부르는 쓰기도 이 함수다)
  - `prune()`: 지우는 파일, 걷는 빈 부모 디렉터리마다
  - `--adopt`: 원래 경로와 `<경로>.orig` 둘 다
- 이 지점들의 `refuse_link()` 호출을 걷어낸다. T10 이 맡는 지점의 호출은 남긴다
- `set` · `steps` · `checks` 는 render 가 사전 판정으로 멈추면 설정을 되돌리고 `reverted — the config is unchanged` 를 낸다(3-5)
- `render-test.sh` 에 명세 7-4 블록(경로 안전)을 새로 둔다. 번호는 이 커밋을 만들 때 `develop` 의 `render-test.sh` 에 있는 최대 `UT-<번호>` 의 다음 번호다.
  T3 블록에 있는 심볼릭 링크 케이스를 이 블록으로 옮긴다(검증하는 내용은 7-4 표를 따른다). 링크 대상과 피해 파일은 하네스 루트 바깥의 테스트 임시 디렉터리 안에 둔다
- `guarded_path()` 자체의 판정(형식 사유 · 직전 재검사)은 기존 블록처럼 `src/bin/harness` 를 모듈로 읽어 부르는 단위 케이스로 본다
- 건드릴 파일: `src/bin/harness`(경로 규칙 판정 함수 · `guarded_path()` · 사전 판정 · `user_files()` · `copy_tree()` · `cmd_render` · `prune()` · `write_manifest_hashes()` ·
  넘겨받기 · `set` · `steps` · `checks` 의 되돌리기), `src/test/render-test.sh`

### 완료 조건

- [ ] 설치된 리포에서 매니페스트에 있는 `script/review-mr.sh` 를 바깥 파일 링크로 바꾸고 render 하면 종료 코드 2 이고 표준 오류가 11-4 안내문(`--> script/review-mr.sh`)이며 바깥 파일이 그대로다
- [ ] `script` 를 바깥 디렉터리 링크로 바꾸고 render 하면 종료 코드 2, 표준 오류의 `-->` 줄이 `script` 하나이고 바깥 디렉터리가 그대로다
- [ ] 설치된 리포의 `.ai/project` 를 같은 내용의 바깥 디렉터리 링크로 바꾸고 render 하면 종료 코드 2 이고 표준 오류에 `--> .ai/project` · `nothing was changed` · 11-4 의 `help:` 줄이 있다. 링크를 실제 디렉터리로 바꾸면 render 가 종료 코드 0 이다
- [ ] 소유 원형이 없는 새 리포에서 `script/project` 를 바깥 디렉터리 링크로 두고 install 하면 종료 코드 2 이고 바깥 디렉터리에 `README.md` 가 생기지 않는다
- [ ] `docs/adr` 를 바깥 디렉터리 링크로 두고 `set adr.dir docs/decisions` 하면 종료 코드 2, `reverted`, 바깥 `README.md` · `harness.toml` · 매니페스트가 그대로다
- [ ] `CLAUDE.md` 가 바깥 파일 링크인 새 리포에서 `install --adopt` 가 종료 코드 2 이고 바깥 파일이 그대로이며 `CLAUDE.md.orig` 가 없다
- [ ] 하네스 루트를 가리키는 링크 경로를 `--target` 으로 주면 render 가 종료 코드 0 이다
- [ ] `guarded_path()` 가 사전 판정 뒤에 생긴 링크를 직전 재검사로 거부하고, 형식이 어긋난 경로는 경로를 출력하지 않고 사유만 낸다
- [ ] 이 task 가 맡은 지점 여섯 곳에 `refuse_link()` 호출이 없다
- [ ] T3 의 사용자 파일 케이스(링크 케이스를 뺀 것)가 그대로 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 형식 사유 | 판정 함수에 `/etc/x` · `a/../b` · `a//b` · `./a` · `a/` · `a b` | 순서대로 `an absolute path` · `has a .. component` · `not a path` 네 번 |
| UT-02 | 정상 경로 | `script/review-mr.sh` · `.harness/managed` · `docs/workflow/changing.md` | 어긋남 없음 |
| UT-03 | 아직 없는 성분 | 없는 디렉터리 아래의 경로 | 어긋남 없음 |
| UT-04 | 대상 없는 링크 | 경로 자신이 대상 없는 링크 | `through a symbolic link` 와 그 경로 |
| UT-05 | 직전 재검사 | 사전 판정을 통과한 경로의 부모를 링크로 바꾼 뒤 `guarded_path(..., "write")` | 종료 코드 2, `refusing to write through a symbolic link`, 링크 대상 그대로 |
| UT-06 | 형식 오류는 경로를 내지 않는다 | `guarded_path(root, "../victim.md", "remove")` | 종료 코드 2, 표준 오류에 `(has a .. component)` 가 있고 `victim.md` 가 없다 |
| UT-07 | 관리 파일 링크 | 매니페스트에 있는 `script/review-mr.sh` 를 바깥 파일 링크로 바꾸고 render | 종료 코드 2, `go through a symbolic link` · `--> script/review-mr.sh`, 바깥 파일 그대로 |
| UT-08 | 링크 부모 — 관리 · 생성 | `script` 를 바깥 디렉터리 링크로 바꾸고 render | 종료 코드 2, `-->` 줄이 `script` 하나, 바깥 디렉터리 그대로 |
| UT-09 | 링크 부모 — 소유 | 새 리포에 `script/project` 바깥 디렉터리 링크를 두고 install | 종료 코드 2, 바깥 디렉터리에 `README.md` 없음 |
| UT-10 | 링크된 `.ai/project` | `.ai/project` 를 같은 내용의 바깥 디렉터리 링크로 바꾸고 render, 이어 실제 디렉터리로 되돌리고 render | 처음 종료 코드 2 와 `--> .ai/project` · `nothing was changed` · `help:`, 되돌린 뒤 종료 코드 0 |
| UT-11 | 정리 대상 링크 | `docs/adr` 바깥 디렉터리 링크(대상에 `README.md`)에서 `set adr.dir docs/decisions` | 종료 코드 2, `reverted`, 바깥 `README.md` · `harness.toml` · 매니페스트 그대로 |
| UT-12 | `--adopt` 링크 | 새 리포에 바깥 파일 링크 `CLAUDE.md` 를 두고 `install --adopt` | 종료 코드 2, 바깥 파일 그대로, `CLAUDE.md.orig` 없음 |
| UT-13 | 하네스 루트 위의 링크 | 하네스 루트를 가리키는 링크를 `--target` 으로 render | 종료 코드 0 |
| UT-14 | 한글 없는 출력 | UT-05 ~ UT-13 의 표준 출력·표준 오류 | 한글이 없다 |

## T10 · feat: install · uninstall 의 사전 판정과 변경 지점을 공용 함수로 전환

### 상위 Requirement

- relates to #58

### 작업 내용

install 과 uninstall 이 대상 리포를 바꾸기 전에 바꿀 경로 전부를 경로 규칙으로 판정하게 하고(11-4 의 install · uninstall 행), 두 명령의 변경 지점
네 곳을 T9 의 `guarded_path()` 로 옮긴다. 이 task 로 `refuse_link()` · `linked_component()` 를 부르는 곳이 없어지므로 둘을 지운다. 결정 기록 0017.

- 명세 11-4 의 install · uninstall 행과 끝의 두 줄(install 의 기본 `harness.toml` · `seed_config()`) · 11-1 의 지점 가운데 `install_registered()` 두 곳 ·
  `seed_config()` · `cmd_uninstall` · 11-3 의 디렉터리 통째 걷기 · 2-4 의 `cmd_uninstall` · 3-6 의 순서(사전 판정 부분) · 7-4 의 심볼릭 링크 케이스 나머지
- 사전 판정(install): T9 의 render 경로에 `.harness` · `.harness/bin` · `.harness/templates` · `.harness/VERSION` 을 더한다. 등록 판정 뒤, `.harness/` 를 바꾸기 전에
  돌고 사용자 파일 판정보다 먼저다. 판정은 설치하려는 CLI 의 템플릿과 설정으로 한다. 소스 리포 분기도 옛 사본을 걷어내기 전에 같은 판정을 거친다.
  멈추면 `.harness/` · 생성 파일 · 등록부가 그대로다. `main()` 이 설정이 없던 대상에 먼저 깐 기본 `harness.toml` 은 남는다
- 사전 판정(uninstall): 두 매니페스트의 경로 · `.harness` · `--purge` 면 지울 소유 파일과 `harness.toml`. `--purge` 의 확인 목록을 내기 전이다.
  안내문은 T9 의 11-4 안내문이고 `<명령>` 은 `uninstall` 이다 — T3 이 둔 uninstall 전용 링크 안내문을 대체한다
- 지점 전환
  - `install_registered()` 사본 교체: `.harness` 를 `guarded_path()` 로 거친 뒤 안의 항목을 걷는다. 안의 링크는 링크 자신만 지우고 따라가지 않는다.
    디렉터리 만들기 · 사본 복사 · `.harness/VERSION` 쓰기도 공용 함수가 돌려준 경로에 한다
  - `install_registered()` 소스 리포 옛 사본 정리: `.harness/bin` · `.harness/templates` · `.harness/VERSION` 을 공용 함수로 거친 뒤 지운다. 안의 링크는 링크 자신만 지운다
  - `seed_config()`: 설정을 읽기 전에 돌아 사전 판정보다 앞선다. `harness.toml` 이 없을 때(대상 없는 링크 포함) 공용 함수를 거쳐 쓰고, 링크면 쓰지 않고 11-3 대로 멈춘다
  - `cmd_uninstall`: 매니페스트의 경로 · 소유 파일 · `harness.toml`(`--purge`) 지우기, `.harness/` 걷기(안의 링크는 링크 자신만), 빈 부모 디렉터리 걷기를
    디렉터리마다 공용 함수로
- `refuse_link()` · `linked_component()` 를 지운다
- `render-test.sh` 의 T9 블록에 케이스를 더한다
- 건드릴 파일: `src/bin/harness`(사전 판정 · `install_registered()` · `seed_config()` · `cmd_uninstall` · `refuse_link()` · `linked_component()`), `src/test/render-test.sh`

### 완료 조건

- [ ] 새 리포와 설치된 리포 각각에서 `.harness` 를 바깥 디렉터리 링크로 두고 install 하면 종료 코드 2 이고, 링크 대상의 파일 · 하위 디렉터리 파일이 그대로이며 등록부에 기록이 없다
- [ ] `.harness/bin` 이 바깥 디렉터리 링크인 소스 트리 복제본에서 install 하면 종료 코드 2 이고 바깥 디렉터리가 그대로다
- [ ] `harness.toml` 이 대상 없는 링크인 새 리포에서 install 하면 종료 코드 2 이고 링크 대상 경로에 파일이 생기지 않는다
- [ ] `docs/adr` 가 바깥 디렉터리 링크인 설치 리포에서 `uninstall` 이 종료 코드 2 이고 바깥 디렉터리 · `.harness/` · 매니페스트의 경로가 그대로다
- [ ] `.ai/project` 가 바깥 디렉터리 링크일 때 `uninstall --purge --yes` 가 종료 코드 2 이고 바깥 디렉터리가 그대로다. `--yes` 없이 비대화형으로 부르면 확인 목록 대신 링크 오류로 종료 코드 2 다
- [ ] 소유 원형이 없는 새 리포에서 `script/project` 를 바깥 디렉터리 링크로 두고 install 하면 `.harness/` 가 생기지 않는다
- [ ] `src/bin/harness` 에 `refuse_link` · `linked_component` 가 없다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | `.harness` 링크 — 새 리포 | 새 리포에 바깥 디렉터리 링크 `.harness`(하위 디렉터리에 파일)를 두고 install | 종료 코드 2, 링크 대상 파일 · 하위 파일 그대로, 등록부에 기록 없음 |
| UT-02 | `.harness` 링크 — 설치된 리포 | 설치된 리포의 `.harness` 를 바깥 디렉터리 링크로 바꾸고 install | 종료 코드 2, 링크 대상 그대로, 등록부 그대로 |
| UT-03 | 소스 리포 옛 사본 | 소스 트리 복제본의 `.harness/bin` 을 바깥 디렉터리 링크로 두고 install | 종료 코드 2, 바깥 디렉터리 그대로 |
| UT-04 | 설정 씨앗 | 새 리포의 `harness.toml` 이 대상 없는 링크인 채 install | 종료 코드 2, 링크 대상 경로에 파일 없음 |
| UT-05 | uninstall 링크 | 설치 리포의 `docs/adr` 를 바깥 디렉터리 링크로 바꾸고 `uninstall` | 종료 코드 2, 표준 오류에 `--> docs/adr` · `nothing was changed`, 바깥 디렉터리 · `.harness/` · 매니페스트의 경로 그대로 |
| UT-06 | purge 링크 | `.ai/project` 바깥 디렉터리 링크에서 `uninstall --purge --yes`, 이어 `--yes` 없이 비대화형 | 둘 다 종료 코드 2, 바깥 디렉터리 그대로, 두 번째에 확인 목록이 없다 |
| UT-07 | install 은 사본을 바꾸기 전에 멈춘다 | 새 리포에 `script/project` 바깥 디렉터리 링크를 두고 install | 종료 코드 2, `.harness/` 없음 |
| UT-08 | 정상 uninstall | 링크 없는 설치 리포에서 `uninstall` | 종료 코드 0, 매니페스트의 경로와 `.harness/` 가 없다 |
| UT-09 | 한글 없는 출력 | UT-01 ~ UT-08 의 표준 출력·표준 오류 | 한글이 없다 |

## T11 · feat: 매니페스트를 읽을 때마다 경로 규칙으로 검증하고 어긋나면 변경 명령을 멈춤

### 상위 Requirement

- relates to #58

### 작업 내용

`.harness/generated` · `.harness/managed` 를 신뢰하지 않는 입력으로 읽는다. 읽을 때마다 줄마다 T9 의 경로 규칙 가운데 형식으로 검증하고, 어긋난 줄이 하나라도 있으면
대상 리포를 바꾸는 명령(render · install · set · steps · checks · uninstall)이 아무것도 바꾸지 않고 멈추게 한다. 결정 기록 0017.

- 명세 2-3 · 11-5 의 변경 명령 · 3-2 의 1(매니페스트 검증이 맨 앞) · 3-5 의 첫 줄 · 3-6 의 순서(매니페스트 검증 부분) · 2-4 의 `cmd_uninstall` 순서 · 7-4 의 매니페스트 검증 케이스 가운데 변경 명령의 것
- 읽기: `previous()` 와 해시 짝 읽기 함수가 판정 전에 줄 끝의 CR 하나를 떼고, 줄마다 2-3 표대로 경로를 뽑아 T9 의 판정 함수(형식 · 링크)로 본다.
  `.harness/` 로 시작하는 줄도 같다. `<<<<<<<` · `|||||||` · `=======` · `>>>>>>>` 로 시작하는 줄은 `a merge conflict marker` 다. 빈 줄(공백뿐인 줄 포함)은 건너뛴다.
  두 함수 모두 검증을 거친 줄만 돌려주고, 어긋난 줄은 매니페스트 이름 · 줄 번호(1부터) · 사유로 따로 돌려준다. 어긋난 줄의 경로는 열지도 바꾸지도 않는다
- 검증은 줄의 문자열만 본다. T9 의 판정 함수 가운데 형식 부분만 쓰고 파일 시스템(링크 성분)은 보지 않는다. 사유는 `a merge conflict marker` · `an absolute path` ·
  `has a .. component` · `not a path` 넷뿐이다. 매니페스트 경로의 링크 성분은 T9 · T10 의 사전 판정이 판정하고 11-4 안내문 하나로 보고한다
- 변경 명령: 어긋난 줄이 있으면 명세 11-5 의 안내문(`error: the harness manifest has <N> line(s) that are not safe paths under the harness root` ·
  `-->` 줄은 `<매니페스트>:<줄 번호> (<사유>)` 로 매니페스트 이름 순 · 줄 번호 순 · 개수를 자르지 않음 · `nothing was changed` · `help:` 와 `harness <명령>`)을
  표준 오류로 내고 종료 코드 2. 사유가 `a merge conflict marker` 인 줄이 있으면 `help:` 끝에 충돌 조치 줄(`harness install`)을 더한다. **줄의 내용은 출력하지 않는다**
- 순서
  - render: 매니페스트 검증 → 사전 판정(T9) → 사용자 파일 판정
  - install: 등록 판정 뒤, `.harness/` 를 바꾸기 전에 매니페스트 검증 → 사전 판정(T10) → 사용자 파일 판정. 소스 리포 분기도 같다
  - `set` · `steps` · `checks`: 설정을 쓰기 전에 검증하고, 어긋나면 설정을 쓰지 않고 종료 코드 2. `steps --dry-run` 은 매니페스트를 읽지 않는다
  - uninstall: "매니페스트가 없다" 판정보다 먼저
- `render-test.sh` 의 T9 블록에 케이스를 더한다. 피해 파일은 하네스 루트 바깥의 테스트 임시 디렉터리 안에 둔다
- 건드릴 파일: `src/bin/harness`(`previous()` · 해시 짝 읽기 · 매니페스트 검증과 안내문 · `cmd_render` · `install_registered()` · `cmd_set` · `cmd_steps` · `cmd_checks` · `cmd_uninstall`), `src/test/render-test.sh`

### 완료 조건

- [ ] 하네스 루트의 부모에 `victim.md` 를 두고 `.harness/generated` 에 `../victim.md` 한 줄을 더해 render 하면 종료 코드 2, 표준 오류에 `.harness/generated:<줄 번호> (has a .. component)` 와 `nothing was changed` 가 있고, `victim.md` · 두 매니페스트 · 관리 파일 · 생성 파일이 그대로다
- [ ] `.harness/managed` 에 `<64자 16진>  <바깥 파일의 절대 경로>` 줄을 더하면 render · install · uninstall 이 각각 종료 코드 2 이고 `(an absolute path)` 가 있다. 바깥 파일이 그대로이고 uninstall 뒤에도 `.harness/` 와 매니페스트의 다른 경로가 남아 있다
- [ ] 공백이 든 줄 · `script//x.sh` · `./CLAUDE.md` · 끝의 `/` 가 든 줄이 각각 `(not a path)` 로 종료 코드 2 다
- [ ] `<<<<<<< HEAD` · `=======` · `>>>>>>> other` 세 줄을 더하면 render 가 종료 코드 2 이고 세 줄 모두 `(a merge conflict marker)`, `help:` 에 `harness install` 이 있다. 표지 줄을 지우면 install 이 종료 코드 0 이다
- [ ] 두 매니페스트의 줄 끝을 CRLF 로 바꿔도 render 가 종료 코드 0 이다
- [ ] 위반 줄이 있을 때 `set` · `steps <새 절차>` · `checks` 가 종료 코드 2 이고 `harness.toml` 이 바이트 단위로 그대로다
- [ ] 표준 오류 어디에도 어긋난 줄의 내용(바깥 파일의 경로)이 없다
- [ ] 매니페스트에 있는 관리 파일을 바깥 파일 링크로 바꾸고 render 하면 표준 오류가 11-4 안내문이고 `not safe paths` 가 없다
- [ ] T9 의 `script` 링크 케이스(`-->` 줄이 `script` 하나)와 `docs/adr` 링크의 `set adr.dir` 케이스(`reverted`)가 이 task 뒤에도 그대로 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | `..` 줄 | `.harness/generated` 에 `../victim.md` 를 더하고 render | 종료 코드 2, `.harness/generated:<줄 번호> (has a .. component)` · `nothing was changed`, `victim.md` · 매니페스트 · 관리 · 생성 파일 그대로 |
| UT-02 | 절대 경로 줄 | `.harness/managed` 에 해시와 바깥 파일 절대 경로 줄을 더하고 render · install · uninstall 각각 | 각각 종료 코드 2 와 `(an absolute path)`, 바깥 파일 그대로, uninstall 뒤 `.harness/` 와 다른 경로가 남는다 |
| UT-03 | 형식 오류 줄 | 공백이 든 줄 · `script//x.sh` · `./CLAUDE.md` · `script/` 를 하나씩 더하고 render | 각각 종료 코드 2 와 `(not a path)` |
| UT-04 | 병합 충돌 표지 | 표지 세 줄을 더하고 render, 이어 표지 줄을 지우고 install | 처음 종료 코드 2 · 세 줄 모두 `(a merge conflict marker)` · `help:` 에 `harness install`, 지운 뒤 종료 코드 0 |
| UT-05 | 링크는 매니페스트 검증이 아니다 | 매니페스트에 있는 관리 파일을 바깥 파일 링크로 바꾸고 render | 종료 코드 2, 표준 오류가 11-4 안내문(`go through a symbolic link` · `--> script/review-mr.sh`)이고 `not safe paths` 없음, 바깥 파일 그대로 |
| UT-06 | CR 줄 끝 | 두 매니페스트를 CRLF 로 바꾸고 render | 종료 코드 0 |
| UT-07 | 설정을 바꾸는 명령 | 위반 줄을 두고 `set` · `steps <새 절차>` · `checks` | 각각 종료 코드 2, `harness.toml` 바이트 단위로 그대로 |
| UT-08 | uninstall 순서 | `.harness/generated` 를 지우고 `.harness/managed` 에 `..` 줄만 남긴 채 `uninstall` | 종료 코드 2, `no harness manifest` 가 아니라 `not safe paths` 안내문 |
| UT-09 | 내용을 옮기지 않는다 | UT-02 의 표준 출력·표준 오류 | 바깥 파일의 절대 경로 문자열이 없다 |
| UT-10 | 한글 없는 출력 | UT-01 ~ UT-08 의 표준 출력·표준 오류 | 한글이 없다 |

## T12 · feat: check · doctor 가 매니페스트의 어긋난 줄을 보고하고 UI 가 옮김

### 상위 Requirement

- relates to #58

### 작업 내용

읽기 명령은 멈추지 않는다. `check` · `doctor` 가 T11 의 검증에 어긋난 매니페스트 줄을 오류로 보고하고, 그 줄의 경로는 읽지 않은 채 나머지 줄로 판정을 이어 가게 한다.
UI Doctor 가 그 항목을 한국어로 옮긴다. 결정 기록 0017.

- 명세 4-1 의 끝 문단 · 4-2 의 어긋난 줄 보고 · 4-3 의 `unsafe manifest line` 항목 · 4-4 표의 두 행 · 11-5 의 읽기 명령 · 11-6 의 끝 줄 · 7-4 의 관리 파일 링크(check · doctor 부분) · check 보고 · doctor 보고
- 어긋난 줄은 T11 의 형식 검증에 어긋난 줄이다. 매니페스트 경로의 링크 성분은 `unsafe manifest line` 으로 보고하지 않는다
- 판정: 어긋난 줄은 4-1 표로 가르지 않고 그 경로를 읽지 않는다. `check` 의 생성 파일 어긋남이 `.harness/generated` 를 읽을 때도 같다
- `cmd_check`: 두 매니페스트 가운데 어긋난 줄이 하나라도 있으면 종료 코드 1. 다른 어긋남과 함께 있으면 모두 보고한다. 출력은 명세 4-2 원문 —
  경로 열은 `<매니페스트>:<줄 번호>` 를 `%-52s` 로, 그 뒤 사유(괄호를 뗀 것). 병합 충돌 표지 줄이 있으면 `help:` 에 11-5 의 충돌 조치 줄을 더한다
- `cmd_doctor`: 어긋난 줄마다 `bad` `unsafe manifest line`, detail `<매니페스트>:<줄 번호> (<사유>)`. `.harness/managed` 의 줄은 `managed files` 절에,
  `.harness/generated` 의 줄은 `generated files` 절에 낸다. 각 절에서 줄 번호 순 10개까지, 넘으면 `bad` `<N> more unsafe manifest line(s)` 한 항목. 이 항목이 있는 절에는 `ok` 를 내지 않는다
- 표준 출력 · 표준 오류 · doctor 항목 어디에도 줄의 내용을 옮기지 않는다
- `src/ui/lib/doctor.js`: `explain()` 이 `unsafe manifest line` 을 하네스 기록(detail 의 매니페스트와 줄 번호)에 하네스 루트 아래의 정상 경로가 아닌 줄이 있어
  render · install · set · steps · checks · uninstall 이 아무것도 바꾸지 않고 멈춘다는 항목으로 옮긴다. 사유가 `a merge conflict marker` 면 양쪽 줄을 남기고
  표지 줄을 지운 뒤 `harness install` 로 다시 쓰게 한다는 것을 더한다. 조치는 없다(파일을 손으로 고친다). `<N> more unsafe manifest line(s)` 는 나머지 건수, 조치 없음
- `render-test.sh` 의 T9 블록에 케이스를 더하고 `doctor.test.js` 에 위 두 행의 케이스를 더한다
- 건드릴 파일: `src/bin/harness`(`cmd_check` · `cmd_doctor` · 관리 파일 판정 함수), `src/ui/lib/doctor.js`, `src/ui/lib/doctor.test.js`, `src/test/render-test.sh`

### 완료 조건

- [ ] 매니페스트에 있는 관리 파일을 바깥 파일 링크로 바꾸고 `check` · `harness status` 를 부르면 그 줄이 `unsafe manifest line` 으로 보고되지 않는다
- [ ] `..` 줄과 충돌 표지 줄이 있으면 `check` 가 종료 코드 1 이고 표준 오류에 두 `<매니페스트>:<줄 번호>` 와 사유가 있으며 피해 파일이 그대로다
- [ ] 같은 상태에서 `harness status` 의 `doctor.items` 에 `state` `bad` · `what` `unsafe manifest line` 항목이 있고, `.harness/generated` 의 줄은 `section` `generated files`, `.harness/managed` 의 줄은 `managed files` 다. detail 에 줄의 내용이 없다
- [ ] 어긋난 줄이 있는 절에 `ok` 항목이 없다
- [ ] UI Doctor 가 `unsafe manifest line` 을 한국어로 옮기고 조치를 두지 않는다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 링크는 어긋난 줄이 아니다 | 매니페스트에 있는 관리 파일을 바깥 파일 링크로 바꾸고 `check` · `harness status` | 표준 오류에 `not safe paths under the harness root` 가 없고 doctor 항목에 `unsafe manifest line` 이 없다 |
| UT-02 | check 보고 | `.harness/generated` 에 `../victim.md`, `.harness/managed` 에 충돌 표지 한 줄을 더하고 `check` | 종료 코드 1, 두 `<매니페스트>:<줄 번호>` 와 `has a .. component` · `a merge conflict marker`, `help:` 에 `harness install`, `victim.md` 그대로 |
| UT-03 | 다른 어긋남과 함께 | UT-02 에 관리 파일 변경을 더하고 `check` | 종료 코드 1, 두 오류가 모두 나온다 |
| UT-04 | doctor 보고 | UT-02 상태에서 `harness status` | `generated files` · `managed files` 절에 각각 `bad` `unsafe manifest line`, detail 이 `<매니페스트>:<줄 번호> (<사유>)`, 두 절에 `ok` 없음 |
| UT-05 | 개수 제한 | `.harness/managed` 에 어긋난 줄 11개를 더하고 `harness status` | `managed files` 절에 `unsafe manifest line` 10개와 `1 more unsafe manifest line(s)` |
| UT-06 | 내용을 옮기지 않는다 | 바깥 절대 경로 줄을 더하고 `check` · `harness status` | 출력과 doctor 항목에 그 절대 경로 문자열이 없다 |
| UT-07 | UI 문구 | `explain()` 에 `unsafe manifest line` · detail `.harness/managed:3 (a merge conflict marker)` | 원문과 다른 제목, 본문에 `.harness/managed` 와 `harness install`, `run` · `cmd` 없음 |
| UT-08 | UI 나머지 건수 | `explain()` 에 `2 more unsafe manifest line(s)` | 한국어 항목, `run` · `cmd` 없음 |
| UT-09 | 한글 없는 출력 | UT-01 ~ UT-06 의 표준 출력·표준 오류 | 한글이 없다 |

## T13 · fix: `steps --rename` 이 새 이름 자리의 파일을 덮지 않고 멈춤

### 상위 Requirement

- relates to #58

### 작업 내용

`steps <절차> --rename <새 이름>` 은 절차 메모 `.ai/project/workflows/<절차>.md` 를 새 이름으로 옮기면서 그 자리에 있던 파일을 덮는다.
설정을 쓰기 전에 두 문서의 경로를 판정해, 새 이름 자리에 무엇이든 있거나 경로에 링크가 있으면 아무것도 바꾸지 않고 멈추게 한다.
옮기기는 T9 의 `guarded_path()` 를 거친다 — 명세 11-1 의 변경 지점 가운데 마지막 하나다. 결정 기록 0017.

- 명세 11-7 · 11-1 의 `rename_or_delete_workflow()` · 7-4 의 `steps --rename` 케이스
- 판정은 이름 중복 판정 뒤, 설정을 쓰기 전이다. 원래 문서는 `.ai/project/workflows/<절차>.md`, 새 문서는 `.ai/project/workflows/<새 이름>.md`
  - 두 문서의 경로에 링크 성분이 있다(파일 자신 포함): T9 의 11-4 안내문(`-->` 는 링크인 성분)을 내고 종료 코드 2
  - 새 문서의 자리에 무엇이든 있다(파일 · 디렉터리 · 링크): 명세 11-7 의 안내문(`error: cannot rename the workflow notes — a file is already at the new name` ·
    `-->` 새 문서 경로 · `nothing was changed` · `help:` 와 `harness steps <절차> --rename <새 이름>`)을 내고 종료 코드 2
  - 둘 다 아니다: 설정을 쓰고 지금처럼 render 한다. 원래 문서가 있으면 원래 경로와 새 경로를 둘 다 `guarded_path(..., "move")` 로 거쳐 옮긴다
- 멈추면 `harness.toml` · 두 문서가 그대로다. `steps <절차> --delete` 는 지금처럼 문서를 남긴다
- `render-test.sh` 의 T9 블록에 케이스를 더한다
- 건드릴 파일: `src/bin/harness`(`rename_or_delete_workflow()`), `src/test/render-test.sh`

### 완료 조건

- [ ] 사용자 절차 `hotfix` 가 있고 `hotfix.md` · `quickfix.md` 를 다른 내용으로 두면 `steps hotfix --rename quickfix` 가 종료 코드 2 이고 두 파일과 `harness.toml` 이 바이트 단위로 그대로다
- [ ] `quickfix.md` 가 없으면 종료 코드 0 이고 `hotfix.md` 의 내용이 `quickfix.md` 로 옮겨진다
- [ ] `.ai/project/workflows` 가 바깥 디렉터리 링크면 같은 명령이 종료 코드 2 이고 바깥 디렉터리와 `harness.toml` 이 그대로다. `hotfix.md` 하나만 바깥 파일 링크일 때도 같다
- [ ] `steps hotfix --delete` 가 `hotfix.md` 를 남긴다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 대상 존재 | `hotfix.md` · `quickfix.md` 를 다른 내용으로 두고 `steps hotfix --rename quickfix` | 종료 코드 2, `a file is already at the new name` · `--> .ai/project/workflows/quickfix.md` · `nothing was changed`, 두 파일 · `harness.toml` 그대로 |
| UT-02 | 대상이 디렉터리 | `quickfix.md` 자리에 디렉터리를 두고 같은 명령 | 종료 코드 2, `harness.toml` 그대로 |
| UT-03 | 대상 없음 | `quickfix.md` 없이 같은 명령 | 종료 코드 0, `quickfix.md` 가 `hotfix.md` 의 원래 내용, `hotfix.md` 없음 |
| UT-04 | 링크 디렉터리 | `.ai/project/workflows` 를 바깥 디렉터리 링크로 두고 같은 명령 | 종료 코드 2, `go through a symbolic link`, 바깥 디렉터리 · `harness.toml` 그대로 |
| UT-05 | 링크 파일 | `hotfix.md` 만 바깥 파일 링크로 두고 같은 명령 | 종료 코드 2, 바깥 파일 · `harness.toml` 그대로 |
| UT-06 | delete 는 남긴다 | `steps hotfix --delete` | 종료 코드 0, `hotfix.md` 가 남는다 |
| UT-07 | 한글 없는 출력 | UT-01 ~ UT-06 의 표준 출력·표준 오류 | 한글이 없다 |

## T14 · docs: 아키텍처 문서 "신뢰 경계" 에 매니페스트를 들어오는 입력으로 추가

### 상위 Requirement

- relates to #58

### 작업 내용

에이전트가 근거로 읽는 `.ai/project/architecture.md` 의 "신뢰 경계" 가 매니페스트를 들어오는 입력으로 적게 한다. T11 · T12 가 만든 동작을 기준 문서에 남긴다.

- 사람 지시 있음 — #58 결정 게이트에서 사용자가 이 보호 문서의 "신뢰 경계" 한 줄 수정을 지시했다. 이 task 의 범위는 그 한 항목이다
- 명세 8절 표의 "신뢰 경계" 행 · 결정 기록 0017
- "들어오는 입력" 에 한 항목: 매니페스트(`.harness/generated` · `.harness/managed`) — 커밋된 파일이라 신뢰하지 않는다. 읽을 때마다 줄마다 경로 형식
  (하네스 루트 기준 정규화된 상대 경로, `..` · 절대 경로 · 빈 성분 거부)으로 검증하고, 어긋난 줄이 하나라도 있으면 대상 리포를 바꾸는 명령은
  아무것도 바꾸지 않는다. 줄의 경로에 있는 심볼릭 링크 성분은 변경 명령의 사전 판정이 막는다
- 이 리포에서 render 해 생성물(`.ai/AI_AGENT.md`)을 함께 커밋한다
- 건드릴 파일: `.ai/project/architecture.md`, 생성물 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] architecture 의 "신뢰 경계" "들어오는 입력" 에 매니페스트 항목이 명세 8절과 같은 사실로 있다
- [ ] 같은 문서의 다른 절이 바뀌지 않았다
- [ ] render 뒤 `.ai/AI_AGENT.md` 에 변경이 반영되고 `check` 가 통과한다
- [ ] `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/58-separate-managed-and-project-parts` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서를 고치고 render 뒤 `check` | 종료 코드 0 |
| UT-02 | 문서 참조가 살아 있다 | 이 리포에서 `doctor` | `references` 절에 이 문서의 끊긴 참조 경고가 없다 |
