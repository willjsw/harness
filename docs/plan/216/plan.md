# #216 분해 — 조직·스택 preset 상속과 고정

명세: [`docs/spec/216-org-presets.md`](../../spec/216-org-presets.md)
결정 기록: [`docs/adr/0024-presets-are-inherited-through-pinned-references.md`](../../adr/0024-presets-are-inherited-through-pinned-references.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | preset 참조와 체인 판정 함수 | 없음 |
| T2 | feat | preset 받는 파일 표와 트리 멤버 판정 · preset.toml 판정 | T1 |
| T3 | feat | preset lock 형식과 내용 해시 · 체인 digest | T1 |
| T4 | feat | preset 사본과 lock 의 대조 함수 | T2, T3 |
| T5 | feat | 설정 로더의 preset 레이어와 설정을 읽는 명령의 대조 멈춤 | T4 |
| T6 | feat | check 의 preset 사본 대조와 check --staged 의 인덱스 대조 | T5 |
| T7 | feat | preset 메모를 프로젝트 메모 앞에 렌더 | T5 |
| T8 | feat | preset git 받기 백엔드 | T2, T3 |
| T9 | feat | harness pull 의 준비 · 반영과 출력 | T7, T8 |
| T10 | feat | harness pull 의 멈춤 조건과 덮는 키 보고 | T9 |
| T11 | feat | .harness 의 고정 사본과 preset 사본을 나눠 다루는 install · render · uninstall | T9 |
| T12 | feat | install --preset 으로 preset 에서 프로젝트 시작 | T10, T11 |
| T13 | feat | set extends 를 단독으로 쓰고 pull 을 안내 | T12 |
| T14 | feat | doctor preset 절 | T9 |
| T15 | feat | 실행 상태에 preset 체인 digest 기록과 재개 대조 | T9 |
| T16 | feat | UI 의 preset doctor 문구와 레이어 이름표 | T5, T14 |
| T17 | docs | README · 절차 문서 · 규칙 문서 10장 · 명세 58 에 preset 반영 | T6, T13, T14, T15 |
| T18 | docs | 보호 문서에 preset 상속 반영 | T17 |

- T1 ~ T4 는 새 패키지 `src/harness/preset/` 의 함수와 단위 테스트다. 대상 리포를 바꾸지 않고, 부르는 곳은 T5 부터다
- T5 가 설정을 읽는 길목에 대조를 넣는다. 그 뒤로 설정을 읽는 명령은 모두 사본과 lock 을 대조한다. `check` 의 보고(T6)는 다른 검사와 함께 도는
  자기 규칙이 있어 따로 둔다
- T5 · T6 · T7 의 회귀 테스트는 사본과 lock 을 손으로 만든다 — 사본 파일을 쓰고 내용 해시를 명세 4-4 의 셸 계산으로 구해 4-3 형식의 lock 을 쓴다.
  pull 이 들어오기 전에 레이어 · 대조 · 메모를 확인하고, 4-4 의 셸 계산이 하네스의 계산과 같다는 것도 함께 확인한다
- T8 은 git 받기, T9 는 pull 의 준비 · 반영 골격과 출력, T10 은 멈춤 조건 넷(1 · 2 · 4 · 5)과 덮는 키 보고다. 멈춤 조건 3(사용자 파일)은 render 의
  사용자 파일 판정을 그대로 쓰므로 T9 에 든다
- T11 은 install 이 preset 사본을 지우지 않게 하는 지점들을 한 커밋에서 바꾼다. 4-6 의 표가 한 규칙(`.harness/` 를 쓰는 명령의 분리)이라 나누면
  사이 커밋에서 install 이 사본을 지운다
- T12 는 pull 의 준비 · 반영을 install 에서 다시 쓴다. T13 은 남은 쓰기 경로(`set extends`)를 더하고 갱신 경로별 불변식 테스트를 맡는다 —
  그 테스트는 pull · set · install · `install --preset` · `set extends` 가 모두 있어야 돈다
- T14 · T15 는 서로 기대지 않는다. T16 은 CLI 가 내는 doctor 항목(T14)과 schema `layers`(T5) 위에서 UI 를 맞춘다
- T17 · T18 은 코드가 만든 동작을 문서에 적는다

### `src/harness/preset/` 의 모듈

| 모듈 | 책임 | task |
|---|---|---|
| `ref.py` | 참조 판정과 스킴 표(출처 · 태그 나누기와 다시 잇기), 체인 판정(깊이 상한 · 순환), 그 안내문 | T1 |
| `tree.py` | 받는 파일 표와 받는 디렉터리, 트리 멤버 판정, `preset.toml` 판정 · UTF-8 판정, 요구 버전 비교, 그 안내문 | T2 |
| `lock.py` | lock 쓰기 · 읽기 판정(스킴별 행), 내용 해시, 체인 digest, `resolved` 의 짧은 꼴 | T3 |
| `verify.py` | 사본과 lock 의 대조(디스크 · 인덱스), 5-3 안내문 | T4 |
| `git.py` | git 받기 백엔드 | T8 |
| `store.py` | `PRESET_PARTS`, 사본 · lock 쓰기와 지우기 | T9 |
| `sync.py` | pull 과 `install --preset` 이 함께 쓰는 준비 · 반영 | T9 |

- `__init__.py` 는 docstring 만 갖는다(#206 3-1)
- `ref` · `tree` · `lock` · `verify` · `git` · `store` 는 `config/` · `render/` · `commands/` 를 불러오지 않는다. 설정 로더(`config/`)가 `verify` · `lock` 을 부른다
- `sync` 는 병합 · 검증 · render 계산을 위해 `config/` · `render/` · `changes` 를 부르는 유일한 preset 모듈이다. `commands/pull.py` 와 `commands/install.py` 가
  그것을 부른다 — 명령 모듈은 서로 부르지 않는다(#206 3-4). 모듈 최상위 import 사이에 순환이 없다(`config/` → `preset.verify`, `preset.sync` → `config/`)
- 받기는 참조의 스킴으로 백엔드를 고른다. 이 이슈의 스킴 표에는 `https://` → git 한 행뿐이다

## 착수 조건

- #206 · #207 · #208 이 `develop` 에 머지된 뒤 착수한다

## 다른 이슈와의 접점

| 이슈 | 이 분해가 쓰는 것 · 넘기는 것 |
|---|---|
| #206 | 패키지 `src/harness/` 의 모듈 지도(`commands/<명령>.py` · `readiness/items.py` · `readiness/remote.py` · `render/agents.py` · `render/workflows.py` · `render/apply.py` · `manifest.py` · `changes.py` · `drift.py` · `pin.py` · `safepath.py`), 명령 표 `COMMANDS`(`commands/__init__.py`) · `DELEGATES`(`cli.py`), 단위 테스트 자리 `src/test/unit/` 와 의존 방향 검사 `script/project/check-cli.py imports`, 고정 사본의 `.harness/lib/` |
| #207 | 레이어 로더와 그 preset 자리, 병합 규칙 · `locked` 판정 · 개인 레이어 허용 키, 공유 · 실효 설정, `harness schema` 의 `layers` · `sources` · `checks[].source`, `labels.js` 의 레이어 이름표 함수, `set` 이 파일에 없는 키를 더하는 규칙, 씨앗 설정 원형 `src/templates/harness.toml` 과 내장 기본값 `src/templates/defaults.toml` |
| #208 | workflow 블록과 빈 하위 절차(확장 지점), 드라이버 실행 상태(`src/harness/workflow/`)의 선택 필드 `preset` 과 `--resume` |
| #213 | `usage log` 는 설정을 읽지 못하면 기록하지 않고 0 으로 끝난다. T5 가 대조를 설정을 읽는 길목에 두므로 머지 순서와 상관없이 명세 5-2 의 `usage log` 행이 성립한다 |
| #214 | Workflows 캔버스가 레이어 이름표 함수를 부른다. 그 함수의 인자는 (레이어 id, `schema.layers`) 다. T16 은 착수 시점의 `src/ui/` 에서 그 함수를 부르는 곳을 모두 고친다 |
| #217 | 받는 파일 표에 `ci/github/harness-verify.yml` · `ci/gitlab/harness-verify.yml` 두 행을 더하고, pull 의 render 계산이 새 체인의 CI 템플릿을 임시 위치에서 읽게 한다. T2 의 받는 디렉터리는 표에서 나오고, T7 · T9 의 render 계산은 새 체인을 읽는 위치를 한 인자로 받는다. `check` 의 preset 정책 검사는 T6 의 대조 결과가 실패면 돌지 않는다 |
| #218 | 스킴 표에 `oci://` 행(참조 판정 · lock 판정 · 백엔드)을 더하고, OCI 받기는 tar 전용 검사 뒤에 T2 의 멤버 판정 함수와 `preset.toml` · UTF-8 판정을 부른다. 내용 해시 · lock 쓰기 · 반영은 이 분해의 것을 그대로 쓴다. #218 은 T1 의 첫 거부 사유 문구와 그 테스트 기대값을 바꾼다 |

- 같은 파일(`README.md` · `commands/install.py` · `readiness/items.py` · `src/ui/lib/` · 보호 문서)을 #209 ~ #215 의 구현이 함께 건드린다. 먼저 머지된 쪽 위로
  `git fetch -p origin` 뒤 rebase 한다
- 보호 문서는 #206 → #207 → #208 순으로 고친 문장 위에 이 명세의 문장을 더한다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/216-org-presets` — 요구사항 이슈 #216 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: 조직·스택 preset 의 extends 상속과 harness pull(#216)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #216` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #216`

## 전 task 공통 사항

- CLI 는 python3 표준 라이브러리만 쓴다. lock 읽기는 `tomllib`, 쓰기는 고정 형식 문자열이다
- **`extends` 가 없는 프로젝트는 그대로다.** `.harness/preset/` 와 lock 이 생기지 않고 생성물 · 매니페스트가 바이트 단위로 같다. 기존 회귀 테스트의
  기대값(종료 코드 · 출력 · 파일 상태)은 고치지 않는다 — 고치게 되면 그 task 의 변경이 명세 1절을 어긴 것이다. 예외는 씨앗 설정 원형의 내용을 보는
  기대값 하나로, 14-4 의 `extends` 설명 주석만큼 바뀐다(T12)
- 네트워크는 `harness pull` 과 `harness install --preset` 만 쓴다. render · check · doctor · run 과 테스트는 리포 안의 사본으로 돈다
- 하네스 출력에 옮기지 않는 것: 받은 preset 트리의 항목 이름(사유와 순번만), git 의 출력, 거부한 `extends` 의 값, 사본 파일의 내용
- 대상 리포를 바꾸는 쓰기와 지우기는 모두 `guarded_path()` 를 거치고, 바꾸기 전에 매니페스트 검증과 경로 사전 판정을 돈다(ADR 0017)
- 상수 이름: `PRESET_DEPTH_LIMIT`(3) · `PRESET_FETCH_TIMEOUT`(120) · `PRESET_PARTS`(`.harness/preset` · `.harness/preset.lock`)
- 단위 테스트는 `src/test/unit/test_<대상>.py` 에 두고 `cd src && python3 -B -m unittest discover -s test/unit` 로 돈다(#206 7-5). CLI 를 하위 프로세스로 띄우지 않고,
  외부 명령은 그것을 부르는 함수를 바꿔 끼운다
- `render-test.sh` 의 새 블록은 기존 `UT-<번호>` 형식이고 번호는 착수 시점 최대 번호의 다음부터다. 터미널 출력의 한글 검사를 새 블록에도 적용한다
- preset 원격은 로컬 bare 리포다. 임시 `GIT_CONFIG_GLOBAL` 파일에 `url."file://<임시>/remote/".insteadOf "https://git.example.test/"` 를 두고 `GIT_CONFIG_NOSYSTEM=1` 을
  준다. `extends` 는 `https://git.example.test/…` 로 적는다. 제품 코드에 테스트용 예외를 두지 않는다
- 터미널 출력은 명세의 영어 원문 그대로다(ADR 0011)
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다
- 에이전트가 보는 명령 표기(`script/<이름>.sh`)는 바꾸지 않는다. 새 명령 `harness pull` 과 `install --preset` 은 사람이 부르는 명령이다
- 동작이 바뀌어 틀리게 된 주석(`.harness/` 아래는 고정 사본이라는 서술 등)은 그 동작을 바꾸는 task 에서 고친다
- 템플릿 · 관리 파일을 고치면 `src/bin/harness render` 로 이 리포의 사본(`.ai/AI_AGENT.md` · `docs/workflow/` 등)을 갱신해 함께 커밋한다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- OCI 백엔드(`oci://` 참조 · 레지스트리) — #218
- 하네스 CI 게이트의 생성물 전환, preset 정책 검사, lock 을 원격과 다시 맞춰 보는 검사 — #217
- preset 리포의 운영 — 만들기 · 권한 · 태그 보호 · 서명
- SSH 참조 · 짧은 이름 · 리포 안의 하위 경로
- 받는 크기의 상한, 같은 하네스 루트에서 동시에 도는 두 pull 의 배제
- 전체 값 사본 `harness.toml` 을 줄이는 쓰기 명령 — pull 이 덮는 키를 알리고 줄이는 것은 사람이 한다
