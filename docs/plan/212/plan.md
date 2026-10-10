# #212 분해 — work 를 driver 절차로, 리뷰 루프는 하위 절차 `review-loop`

명세: [`docs/spec/212-drive-work-loop.md`](../../spec/212-drive-work-loop.md)
결정 기록: 없음 (명세 14절)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | chore | 기본 work 를 agent 절차로 전제한 기존 회귀 케이스를 이전 기본값 절로 고정 | 없음 |
| T2 | feat | 구현자 결과 스키마와 처리 노트 표지 추가, 구현자 계약에 모드 · escalate · 마무리 반영 | 없음 |
| T3 | feat | 판정 명령 work-check 의 작업 트리 확인 · 구현 판정과 shim 추가 | T2 |
| T4 | feat | work-check 의 수정 판정 · 마무리 확인과 처리 대조 추가 | T3 |
| T5 | feat | 기본 절차 work 를 driver 로 전환하고 하위 절차 review-loop 와 단계 조각 추가 | T1, T4 |
| T6 | chore | driver work 의 착수 · 구현 경로 회귀 케이스 추가 | T5 |
| T7 | chore | driver work 의 리뷰 루프 · 마무리 경로 회귀 케이스 추가 | T6 |
| T8 | refactor | 절차 절 지우기와 되돌림을 공용 모듈로 이동 | 없음 |
| T9 | feat | doctor 의 이전 기본값 work 항목과 fix legacy-work 추가 | T5, T8 |
| T10 | docs | work 진입점과 리뷰 루프 서술을 driver 절차 기준으로 갱신 | T5, T9 |
| T11 | docs | 아키텍처 · 용어 · 담당 범위 · 테스트 문서에 driver work 반영 | T2, T4, T5, T9 |
| T12 | chore | 이 리포의 work 를 내장 기본값 driver 절차로 전환 | T5, T9, T10 |

- T1 은 동작을 바꾸지 않는다. 기본 `work` 를 agent 절차 고정물로 쓰는 기존 회귀 케이스(agent 절 문서의 단계 번호 · 단계 삽입,
  시작 표지 줄, `/work` 커맨드, `harness run work <번호>` 의 오케스트레이터 실행, 세션 가져오기의 `work/implement` 키 등)가 설정에
  이전 기본값 절(명세 10-1 원문)을 직접 두게 한다. 그 절은 지금 기본값과 같으므로 **지금 트리에서** 통과하고, T5 가 기본값을 바꿔도
  고치지 않고 통과한다. 기본값 자체를 보는 케이스는 고정하지 않는다 — T5 가 기대값을 바꾼다
- T2 → T3 → T4 는 구현자 결과의 어휘와 처리 노트 표지를 먼저 두고, 그것을 읽는 판정 명령을 동작 둘씩 쌓는다. 동봉 스키마의 첫 사용처는
  같은 리뷰 요청의 T5 다(#208 5-1 "동봉 스키마는 그것을 쓰는 기본 절차와 함께 더한다")
- T5 는 기본 절차 정의 · 단계 조각과 render 수준 케이스를 한 커밋으로 둔다. driver 로 끝까지 도는 회귀 케이스는 스텁 기반을 만드는
  T6(착수 · 구현 경로)과 그 기반을 쓰는 T7(리뷰 루프 · 마무리 경로)이 나눠 더한다. 둘은 테스트만 더한다
- T8 은 동작을 바꾸지 않는다. T9 의 `fix legacy-work` 가 `harness steps --delete` 와 같은 지우기 · 되돌림을 쓰려면 그 코드가 명령
  모듈 밖에 있어야 한다 — 명령 모듈은 다른 명령 모듈을 불러오지 않는다(#206 3-4)
- T10 은 T5 · T9 가 만든 사실로 사람용 문서와 에이전트가 읽는 서술을 고친다. 명령을 더하는 task 는 그 명령의 문서 행을 함께 고친다 —
  T3 은 README 명령 표와 `script/README.md` 의 `work-check` 행, T9 는 README 명령 표의 `legacy-work` 와 UI doctor 문구
- T11 은 보호 문서 개정 task 하나다(명세 13절). 2026-10-09 결정 게이트에서 사용자가 허용한 범위만 고친다
- T12 는 마지막에 한다. 이 리포의 `work` 가 driver 로 바뀌는 시점이므로, 그 앞 task 는 모두 지금의 agent 절차 위에서 리뷰된다
- 명세 7절(헤드리스 구현자 권한)은 #208 의 벤더 선언 `driver_write` 가 연다. #208 7-4 의 범위 표가 명세 7절 표와 같고, 이 이슈의 task 는
  그 범위를 바꾸지 않는다. 명세 9절(단계 지표)은 #208 의 드라이버가 단계 스팬을 남기고 render 가 agent 절 문서에만 시작 표지 줄을 넣는
  것으로 성립한다 — 따로 바꾸는 코드가 없다

## 착수 순서와 다른 이슈

- 착수 조건: #206 · #207 · #208 · #209 · #210 · #211 의 구현 리뷰 요청이 `develop` 에 머지된 뒤 착수한다. 브랜치는 그 뒤의
  `origin/develop` 에서 만든다. 보호 문서 문안은 #206 → #207 → #208 · #209 · #210 → #211 → #212 순서로 얹힌다(명세 13절)
- 이 분해가 기대는 선행 명세의 자리
  - 패키지 배치와 명령 표: `src/harness/commands/<이름>.py` · `commands/__init__.py` 의 `COMMANDS`(통과 표시가 첫 원소인 네 원소 항목) ·
    `cli.py` 의 `DELEGATES`, 단위 테스트 자리 `src/test/unit/`(`cd src && python3 -B -m unittest discover -s test/unit`) — #206
  - 내장 기본값 `src/templates/defaults.toml`, 프로젝트 레이어, 공유 설정 · 실효 설정, `workflows.<이름>` 통째 교체 — #207
  - 블록 · 배선 · 자리표시 · 동봉 스키마 자리 `src/harness/schemas/` · 스키마 문법과 검증기 · driver 절차 문서 · driver 절차의 관리 커맨드
    제외 · 역할 실행기 `--driver` — #208
  - forge 어댑터 `harness.forge.load(cfg, root)` 와 계약 함수, 페이크 주입 `HARNESS_FORGE_FAKE`, 표지 모듈 `src/harness/format.py` 의
    `markers(root)` — #209
  - 하위 명령 `harness preflight` · `harness sync-tasks` · `harness review` 와 그 shim, 리뷰 모듈 `src/harness/review.py` — #211
- 뒤에 오는 이슈와의 경계
  - #213 은 이 이슈 뒤에 착수한다. 표지 정본을 `src/harness/format.py` 로 옮길 때 이 이슈가 더한 `FMT_HANDLED_HEADING` 을 함께 옮기고,
    `script/work-check.sh` 를 공통 shim 템플릿의 대상에 넣는다
  - #215 는 기본 `work` 에 잠금 단계를 더하고, T9 의 이전 기본값 목록에 T5 가 낸 driver 기본값을 더한다(#215 4-5). 목록은 항목을
    더하기만 하면 doctor 와 `fix legacy-work` 가 함께 따르는 형태로 둔다
  - #221 은 shim 과 `script/<이름>.sh` 표기를 걷는다. `script/work-check.sh` 가 그 대상에 든다. 옛 agent 경로(옛 단계 조각 다섯 ·
    `/work` 관리 커맨드 · 이전 기본값 목록과 doctor 항목 · `fix legacy-work`)를 걷는 일은 #221 범위가 아니고 맡은 이슈가 아직 없다(명세 10-5)
  - #214(UI 블록 편집기)와는 서로 기대지 않는다
- 같은 배치의 다른 spec+plan 리뷰 요청과 구현 리뷰 요청이 `README.md` · `src/test/render-test.sh` · `src/test/fake-forge.sh` ·
  `src/templates/managed/script/README.md` · 보호 문서를 함께 고친다. 먼저 머지된 쪽 위로 `git fetch -p origin` 뒤 rebase 한다.
  rebase 뒤 push 는 사람이 한다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/212-drive-work-loop` — 요구사항 이슈 #212 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: work 를 driver 절차로 전환하고 리뷰 루프를 하위 절차로 분리(#212)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #212` 와 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #212`

## 전 task 공통 사항

- 관리 파일의 정본은 `src/templates/managed/`, 생성 파일의 원형은 `src/templates/generated/` 다. 정본을 고친 뒤 `src/bin/harness render`
  로 이 리포의 사본(`script/` · `.ai/templates/` · `docs/workflow/`)과 생성 파일 · `.harness/managed` 를 갱신해 함께 커밋한다. 사본과 생성
  파일을 손으로 고치지 않는다
- CLI 패키지는 python3 표준 라이브러리만 쓴다. 공용 모듈은 `cli` · `commands` 를 불러오지 않고, 명령 모듈은 다른 명령 모듈을 불러오지
  않는다(#206 3-4). `script/project/check-cli.py imports` 가 이것을 검사한다
- forge 는 #209 의 어댑터로만 부른다. 표지는 `format.py` 의 `markers(root)` 로만 읽고 파이썬 쪽에 표지 문자열을 적지 않는다. 이 이슈가
  머지되는 시점의 표지 정본은 `src/templates/managed/script/harness-format.sh` 다
- 에이전트가 보는 명령 표기는 `script/<이름>.sh` 그대로다. 기본 절차의 `run` 값도 그 표기를 쓴다. shim 을 걷는 일은 #221 이 한다
- 옛 agent 경로 — 옛 단계 조각 `work/sync-tasks.md` · `implement.md` · `review.md` · `branch.md` · `limits.md` 와
  `src/templates/managed/.claude/commands/work.md` — 는 고치지 않는다(명세 10-2)
- 터미널 출력은 영어, 문서와 조각은 한국어다. 구현자 출력에서 온 문자열(`reason` · `finding` · 리뷰 요청 인자)은 제어 문자를 지우고
  한 줄로 바꿔 옮긴다
- 회귀 테스트는 원격과 에이전트 CLI 를 부르지 않는다. 원격은 로컬 bare 리포, forge 는 `HARNESS_FORGE_FAKE=<src/test/fake-forge.sh 의
  절대 경로>` 와 `FAKE_STATE`, 구현자 · 리뷰어 · 오케스트레이터는 PATH 앞의 스텁, 등록부는 `HARNESS_HOME` 으로 테스트 작업 디렉터리
  아래에 둔다. `HARNESS_FORGE_FAKE` 는 명령 하나의 환경에만 주고 테스트 전체에 내보내지 않는다
- `src/test/fake-forge.sh` 를 넓힐 때는 새 상태 파일이 없으면 지금 출력 그대로 내게 한다. 기존 사용처(자체 검사 · 라벨 · 리뷰 루프
  케이스)가 고치지 않고 통과한다. 실패 흉내는 `FAKE_BREAK`(계약 위반 주입)와 섞지 않고 `FAKE_STATE` 의 파일로 켠다
- Python 단위 테스트는 `src/test/unit/test_<대상>.py` 에 두고 CLI 를 하위 프로세스로 띄우지 않는다. 패키지 모듈의 함수를 부르고, git 은
  임시 리포에서 실제로 돌린다
- `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록 형식과 병렬 블록 묶음 형식을 따르고, 블록 번호는 착수 시점의 다음 번호를 쓴다.
  터미널 출력의 한글 검사는 새 블록에도 적용한다
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다
- 커밋 전 `script/run-lint-test.sh --commit` 이 통과한다

## 이번 이슈에서 정하지 않는 값

- 이전 기본값 목록 상수와 "같다" 비교 함수, T8 이 옮기는 절 지우기 함수의 이름 — 자리는 공용 모듈(T8 · T9)로 정한다
- 회귀 테스트의 스텁 파일 · 도우미 함수 이름과 `FAKE_STATE` 아래 새 상태 파일의 이름

## 이번 이슈에서 다루지 않는 것

- 옛 agent 경로를 걷는 일과, 옛 절을 가진 설정의 render 를 고유한 거부 메시지와 이행 안내로 멈추는 검사(명세 10-5) — 맡은 이슈가 없다
- 다른 클론에서 잇기와 여러 클론의 동시 착수 막기 — #215
- 벤더별 `driver_write` · `structured` 인자의 확인과 선언 — #208 의 역할 러너
- 리뷰 판정 데이터에 "설계와 상충하는 인터페이스 변경" 범주를 가르는 필드 — 구현자가 재시도 모드에서 `escalate` 로 넘긴다(명세 4-4)
- 명세 15절의 한계 — 처리 대조가 내용을 보지 않는 것, 발견 0건 PASS 에서도 마무리를 부르는 것, forge 의 head 반영 지연 등
