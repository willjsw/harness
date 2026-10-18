# #208 분해 — 절차 블록 그래프와 결정론 드라이버

명세: [`docs/spec/208-workflow-block-engine.md`](../../spec/208-workflow-block-engine.md)
결정 기록: [`docs/adr/0021-workflows-are-block-graphs-run-by-the-harness.md`](../../adr/0021-workflows-are-block-graphs-run-by-the-harness.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | 절차의 실행 방식과 블록 다섯의 단계 키를 render 가 검증 | 없음 |
| T2 | feat | 구조화 출력 스키마의 자리·문법·검증과 schema 출력의 output_schemas·execute | T1 |
| T3 | feat | 배선·암묵 배선·자리표시·set 을 render 가 검증 | T2 |
| T4 | feat | agent 절차의 workflow 블록 문서와 커맨드를 하위 절차가 아닌 agent 절차로 한정 | T1 |
| T5 | feat | driver 절차 문서에 Mermaid 그래프와 단계별 다음 표 생성 | T3 · T4 |
| T6 | feat | harness steps 가 단계 키와 절차 키를 전부 보존 | T3 |
| T7 | feat | 벤더 선언의 agent·driver_write·structured 와 실행 계획의 driver·prompt 자리 | 없음 |
| T8 | feat | 역할 실행기에 --driver·--driver-prompt·--schema 추가 | T7 |
| T9 | feat | driver 실행 상태 파일과 doctor 의 runs 절 | T2 |
| T10 | feat | driver 절차의 harness run — 인자·잠금·상태·script 블록·끝 상태 | T3 · T4 · T9 |
| T11 | feat | driver 실행의 workflow 블록과 하위 절차 변수 조회 | T10 |
| T12 | feat | driver 실행의 게이트 입력·멈춤·중단과 --resume | T11 |
| T13 | feat | driver 실행의 agent·prompt 블록과 구조화 출력 판정 | T8 · T10 |
| T14 | feat | driver 실행과 이슈 worktree 의 재개·정리 판정 | T12 |
| T15 | feat | driver 블록 스팬과 by_step 집계 | T12 · T13 |
| T16 | docs | README·기본값 주석·절차 안내 문서에 블록 그래프와 driver 실행 반영 | T6 · T14 · T15 |
| T17 | docs | 보호 문서에 블록 그래프와 driver 실행 반영 | T14 · T15 |

- T1 ~ T3 은 정의와 render 검증이다. T1 은 블록 표와 키 · 실행 방식 · 하위 절차 관계, T2 는 스키마 자리 · 문법과 그 검증기,
  T3 은 배선 · 자리표시 · `set` 을 넣는다. T3 의 완전성과 자리표시 검사는 T2 의 스키마(`on` 필드의 열거값, 최상위 키의 형)를 쓴다.
  T3 이 끝나면 driver 절차 정의가 render 를 통과하거나 6절의 위치 표기로 거부된다
- T4 · T5 는 생성물이다. T4 는 agent 절차 쪽(workflow 블록 문서, 빈 절차 문서, 커맨드 생성 조건), T5 는 driver 절차 문서다.
  두 task 모두 기본 절차의 생성물을 바이트 단위로 바꾸지 않는다
- T6 은 `harness steps` 가 T1 ~ T3 의 새 키를 지우지 않게 한다
- T7 · T8 은 역할 러너다. 드라이버가 부르기 전에 실행 계획의 두 자리와 역할 실행기의 세 인자를 따로 넣고 시험한다
- T9 는 실행 상태와 doctor 다. 드라이버 없이 상태 파일을 직접 만들어 시험한다
- T10 ~ T15 는 드라이버다. T10 이 실행 골격(인자 · 시작 전 확인 · 잠금 · 상태 · script 블록 · 상한 · 끝 상태)을 놓고, T11 이 하위
  절차, T12 가 게이트와 재개, T13 이 agent · prompt 블록, T14 가 worktree, T15 가 지표를 더한다
- T16 은 사람용 문서, T17 은 보호 문서다. 벤더 선언 머리 주석은 T7 이, 역할 실행기 안내 표는 T8 이 같은 파일의 코드와 함께 고친다

## 착수 순서와 다른 이슈

- 착수 조건: #206 · #207 구현이 `develop` 에 머지된 뒤 착수한다(그 선행인 #96 포함). 이 분해의 경로와 함수 이름은 #206 의 모듈 지도와
  #207 의 실효 설정 · `run_plan()` · `harness run-plan` · `src/templates/defaults.toml` 을 따른다
- 후행 이슈가 이 이슈의 결과에 기댄다
  - #212 — 블록 계약 · 자리표시 · 동봉 스키마 자리(`src/harness/schemas/`) · `driver_write` 가 여는 범위 · 재개 · 단계 스팬 · driver 절차의 커맨드 제외
  - #214 — `src/harness/workflow/` 의 outcome 집합 · 실효 배선 · 시작 단계 계산, render 오류 위치 표기, `harness steps` 의 키 보존, `harness schema` 의 `output_schemas` · `workflows.<절차>.execute`
  - #216 — workflow 블록, 빈 하위 절차, 실행 상태의 선택 필드 `preset`, `--resume`
  - #213 — 역할 실행기를 `harness run-agent` 로 옮기면서 `--driver` · `--driver-prompt` · `--schema` 를 그대로 받고, 드라이버가 패키지의 역할 실행기를 부른다. 그때 시작 전 확인의 `script/run-agent.py` 확인이 없어진다
  - #215 — driver 의 끝 상태 · 실행 상태 · `--discard`. 드라이버가 스스로 낸 `stop` 과 `--discard` 뒤의 잠금 해제는 #215 의 안내가 다룬다
- 보호 문서 개정의 적용 순서는 #206 → #207 → #208 · #209 · #210 → #211 → #212 → #213 → #215 다. T17 은 #206 · #207 이 고친 문장 위에 더한다
- #209 · #210 도 같은 시기에 `src/test/render-test.sh` 의 블록 번호, 보호 문서, `README.md` 를 고친다. 먼저 머지된 쪽 위로
  `git fetch -p origin` 뒤 `develop` 에 rebase 하고 블록 번호를 다음 번호로 다시 매긴다. rebase 뒤 push 는 사람이 한다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/208-workflow-block-engine` — 요구사항 이슈 #208 하나가 브랜치 하나 · 리뷰 요청 하나다
- 리뷰 요청 제목: `feat: 절차를 블록 그래프로 정의하고 결정론 드라이버로 실행한다(#208)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #208` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #208`

## 전 task 공통 사항

- 코드 자리 — 명세 정본 위치 표를 #206 의 모듈 지도에 놓은 것이다

  | 대상 | 자리 |
  |---|---|
  | 블록 표 · 끝 상태 · 실행 방식별 키 | `src/harness/workflow/blocks.py` |
  | 배선 판정 · 실효 배선 · 시작 단계 · outcome 집합 · 도달 · 끝 · 하위 절차 관계 | `src/harness/workflow/graph.py` |
  | 자리표시 파싱 · 풀기 | `src/harness/workflow/placeholders.py` |
  | 스키마 자리 · 문법 검사 · 검증기 · 결과 본문에서 꺼내기 | `src/harness/workflow/schemas.py` |
  | render 검증(6절)과 위치 표기 | `src/harness/workflow/validate.py` — `src/harness/config/workflows.py` 의 `validate_workflows()` 가 부른다 |
  | 실행 상태 · 잠금 · 정의 digest | `src/harness/workflow/state.py` |
  | 드라이버(블록 실행 · 게이트 · 재개) | `src/harness/workflow/driver.py` |
  | 동봉 구조화 출력 스키마 | `src/harness/schemas/<이름>.json` — 이 이슈는 동봉 스키마를 더하지 않는다 |
  | 절차 문서 | `src/harness/render/workflows.py` (`step_heading()` · `step_body()` · `workflow_doc()`) |
  | 커맨드 생성 · 자산 표 · 관리 파일 설치 판정 | `src/harness/render/plan.py` (`plan()` · `role_file_skip()` · `harness_paths()`) · `src/harness/render/agents.py` (`command_rows()`) |
  | `harness steps` 쓰기 | `src/harness/config/edit.py` (`steps_block()`) · `src/harness/commands/steps.py` |
  | `harness schema` | `src/harness/commands/schema.py` |
  | 벤더 argv 풀기 · 실행 계획 | `src/harness/config/agents.py` (`expand()` · `headless_argv()` · `run_plan()`) |
  | `harness run` | `src/harness/commands/run.py` |
  | doctor 항목 | `src/harness/readiness/items.py` |
  | 지표 집계 | `src/harness/metrics/spans.py` (`metrics_report()`) |
  | 벤더 선언 | `src/templates/vendors.toml` |
  | 역할 실행기 | `src/templates/managed/script/run-agent.py` |
  | UI doctor 문구 | `src/ui/lib/doctor.js` · `src/ui/lib/doctor.test.js` |

- 의존 방향 — `src/harness/workflow/` 는 공용 모듈이라 `cli` · `commands` 를 불러오지 않는다(#206 3-4). 검증 모듈(`blocks` · `graph` ·
  `placeholders` · `schemas` · `validate`)은 `config/workflows.py` · `render/` 를 모듈 최상위에서 불러오지 않는다 — `validate_workflows()`
  가 그 모듈들을 부르므로, 조각이 있는지와 하네스 루트는 인자로 받는다. `metrics/` 는 다른 하네스 모듈을 불러오지 않는다.
  매 task 에서 `python3 script/project/check-cli.py imports` 가 통과한다
- 블록 정의와 단계 키 정의의 순서, outcome 집합 · 실효 배선 · 시작 단계를 내는 함수는 #214 가 부르는 공개 함수다. render 검증과
  드라이버와 절차 문서가 같은 함수를 쓰고 따로 계산하지 않는다
- agent 절차 불변 — 매 task 에서 이 리포의 `.ai/workflows/*.md` · `.claude/commands/*.md` 가 render 뒤 바뀌지 않고 `harness check` 가
  통과한다. 내장 기본값의 세 절차(`prework` · `work` · `retro`)의 설정 값은 바꾸지 않는다
- 기존 회귀 테스트 케이스의 기대값은 바꾸지 않는다
- 단위 테스트는 `src/test/unit/test_<대상>.py` 에 둔다. `[verify]` 의 "Python 단위 테스트"(`cd src && python3 -B -m unittest discover -s test/unit`)가
  돌린다. CLI 를 하위 프로세스로 띄우지 않고 패키지 모듈을 불러 함수를 부른다
- `src/test/render-test.sh` 의 새 블록은 명세 13-1 의 아홉 블록(블록 그래프 검증 · agent 절차 불변 · driver 문서 · 커맨드 ·
  `harness steps` 보존 · `harness schema` · 실행 계획 · driver 실행 · 역할 실행기)이다. 블록을 처음 여는 task 가 착수 시점의 다음
  `UT-<번호>` 로 열고, 뒤 task 는 같은 블록에 케이스를 더한다. 터미널 출력의 한글 검사를 이 블록들에도 적용한다
- 에이전트 CLI 는 부르지 않는다. 오케스트레이터와 러너는 PATH 앞에 둔 스텁이다 — claude 스텁은 `--output-format json` 결과 객체를,
  codex 스텁은 `--json` 이벤트 줄을 흉내 내고, 받은 인자와 프롬프트를 기록하고, 케이스가 정한 결과 본문과 종료 코드를 낸다.
  게이트의 답은 표준 입력으로 준다. 등록부는 `HARNESS_HOME` 으로 테스트 작업 디렉터리 아래에 둔다
- 터미널 출력은 영어다. 진행 줄은 표준 출력, `warn:` · `error:` 는 표준 오류로 낸다. 명세가 문장을 정한 출력은 그 문장 그대로 낸다
- 실행 상태 · 지표 · `warn:` 줄에 에이전트 결과 본문 원문 · 프롬프트 · 명령줄 · 변수 값을 남기지 않는다. 실행 상태가 담는 출력은
  스키마를 통과한 객체와 script 의 JSON 출력뿐이다
- 역할 실행기의 정본을 고친 task 는 `src/bin/harness render` 로 이 리포의 `script/run-agent.py` 사본과 `.harness/managed` 를 갱신해
  함께 커밋한다. 관리 문서(`src/templates/managed/docs/workflow/` · `src/templates/managed/script/README.md`)도 같다
- 에이전트가 보는 명령 표기는 `script/<이름>.sh` · `script/run-agent.py` 그대로다
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다
- 커밋 전 `script/run-lint-test.sh --commit` 이 통과한다

## 이번 이슈에서 정하지 않는 값

- `src/harness/workflow/` 안의 함수 이름과 한 모듈 안의 나눔 — 모듈 자리와 #214 가 부르는 계산이 공개 함수라는 것은 위 공통 사항이 정한다
- 명세가 문장을 정하지 않은 오류 · 안내 줄 — 6절 각 행의 오류 문장(앞머리 `error: workflows.<절차>` 와 위치 표기는 명세대로), 빈 절차
  오류의 `help:` 줄, `--resume` 인데 상태가 없을 때의 거부 문장. 종료 코드는 명세대로 2 다
- 벤더별 `driver_write` · `structured` 의 인자 값 — T7 에서 그 CLI 로 확인한 것만 적는다. 확인하지 못한 키는 선언하지 않고 명세 7-4 의
  대체 규칙으로 돈다

## 이번 이슈에서 다루지 않는 것

- 기본 절차 `work` 의 driver 전환, 하위 절차 `review-loop`, 동봉 스키마 `developer-result` — #212
- UI 의 배선 편집과 블록 편집용 schema 키(`blocks` · `ends` · `wildcard` · 최상위 `execute` · `workflows.<절차>.command`), `harness steps --dry-run --json` — #214
- 역할 실행기의 하위 명령 이식(`harness run-agent`) — #213
- 원격 착수 잠금과 그 해제 — #215. 엔진은 끝 상태 공통 처리 키를 두지 않는다
- 실행 상태의 `preset` 값 채우기와 재개 때 대조 — #216. 이 이슈의 드라이버는 `null` 을 쓴다
- 블록 시간 제한, 다른 클론 · 기기에서의 재개 — 명세 15절의 한계
- 생성되는 `CLAUDE.md` 의 커맨드 흐름 서술 — 기본 절차를 driver 로 바꾸는 변경이 고친다
