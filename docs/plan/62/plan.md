# #62 분해 — UI 쓰기의 CLI 일원화

명세: [`docs/spec/62-unify-ui-writes-through-cli.md`](../../spec/62-unify-ui-writes-through-cli.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | 표준 입력의 본문을 프로젝트 문서·메모에 쓰고 render 하는 write-doc 명령 추가 | 없음 |
| T2 | feat | write-doc 으로 보호 문서를 쓰는 호출을 명령 가드와 권한 deny 로 차단 | T1 |
| T3 | feat | Doctor 조치를 명령으로 돌리는 fix hooks·verify 추가 | #60 |
| T4 | feat | install 에 대상 디렉터리 생성과 git 시작 옵션 추가 | 없음 |
| T5 | feat | schema 에 문서·절차·검증·훅 경로와 설정 주석·기본 보호 목록 키 추가 | T1, T3 |
| T6 | refactor | UI 의 문서·메모 저장과 읽기 경로를 write-doc 과 schema 로 전환 | T1, T5 |
| T7 | refactor | UI Doctor 조치를 fix 명령과 항목 네 키 매핑으로 전환 | T3, T5, #59 |
| T8 | refactor | UI 새 프로젝트 만들기를 install --create 로 전환 | T4 |
| T9 | refactor | UI 보호 문서 목록을 schema 의 기준 목록으로 전환 | T5 |
| T10 | docs | README 에 write-doc·fix·install 옵션과 UI 쓰기 경로 반영 | T1–T9 |
| T11 | docs | 담당 범위·아키텍처 문서에 UI 쓰기의 CLI 일원화 반영 | T1–T9 |

- CLI(T1–T5)가 UI(T6–T9)보다 먼저다. UI 는 CLI 를 서브프로세스로 부를 뿐이고 반대 방향 의존은 없다
- T5 의 `docs` 키는 그 사본이 `write-doc` 과 `fix` 를 안다는 표지다(명세 5절). 그래서 T1 · T3 뒤에 온다
- T2 는 T1 의 명령 이름과 이름 규칙(2-1)을 막는 대상으로 쓴다
- T3 의 `fix hooks` 와 T5 의 `hooks_path` 는 #60 이 install 에 넣는 훅 경로 설정 로직을 부른다. 그 로직을 이 이슈에서 따로 만들지 않는다
- T7 의 조치 고르기는 #59 가 정한 doctor 항목 `{section, state, what, detail}` 을 입력으로 쓴다
- T6 · T7 · T8 · T9 는 서로 기대지 않는다. 모두 `src/ui/lib/actions.js` 를 고치므로 한 브랜치에서 차례로 커밋한다
- T10 · T11 은 T1–T9 가 만든 동작을 문서에 적는다. 둘은 서로 기대지 않는다

### 다른 이슈와의 구현 순서

| 이슈 | 순서 |
|---|---|
| #59 | 이 이슈보다 먼저 머지된다. T7 착수 전제다 |
| #60 | 이 이슈보다 먼저 머지된다. T3 착수 전제다 |
| #96 | 이 이슈가 먼저 머지된다. 둘 다 `src/ui/lib/harness.js` 를 고친다 |
| #70 | 절차 명령의 허용 목록에 `harness write-doc` 을 넣지 않는다. 이 이슈는 허용 목록을 만들거나 고치지 않는다 |

## 브랜치·리뷰 요청·커밋

- 브랜치: `refactor/62-unify-ui-writes-through-cli` — 요구사항 이슈 #62 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `refactor: UI 의 쓰기와 경로를 CLI 명령과 schema 로 일원화(#62)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #62` 와 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #62`

## 전 task 공통 사항

- CLI 는 표준 라이브러리만 쓴다
- 터미널 출력은 영어다. 안내문은 `error:` · `-->` · `help:` 형식이고 명세의 영어 원문 그대로 둔다. `render-test.sh` 의 한글 검사가 새 블록의 출력에도 돈다
- 새 명령은 `COMMANDS` 표에 등록하고, 프로젝트에 고정된 버전이 답해야 하는 `write-doc` · `fix` 는 `DELEGATES` 에도 넣는다. `install` 은 `DELEGATES` 에 넣지 않는다
- 경로를 입력에서 조립하지 않는다. CLI 는 이름을 목록과 문자열로 비교하고, UI 는 경로를 `harness schema` 에서 받는다
- UI 에서 `fs.writeFile` · `fs.mkdir` 과 `git` · `bash` 직접 실행을 새로 두지 않는다. 설정을 고치는 로직은 UI 에 두지 않고 CLI 명령을 부른다
- UI 순수 함수는 `src/ui/lib/` 에 두고 `<모듈>.test.js` 로 단위 테스트한다. 화면과 서버 액션은 자동 테스트가 없으므로 완료 조건의 화면 동작은 손으로 확인한다
- `render-test.sh` 의 새 블록은 기존 `UT-<번호>` 형식을 따르고 번호는 구현 시점의 다음 번호다
- 주석과 테스트 이름에 이슈 번호·문서 번호·테스트 항목 ID 를 넣지 않는다
- 관리 스크립트의 정본은 `src/templates/managed/script/` 다. 이 리포의 `script/` 사본은 render 로 갱신한다
- 생성 파일(`.claude/settings.json` · `.ai/AI_AGENT.md` 등)은 직접 고치지 않고 `src/bin/harness render` 로 갱신한다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- `python3 src/bin/harness write-doc …` 처럼 인터프리터를 앞에 둔 호출과 셸 확장으로 적은 이름의 차단 (명세 12절)
- `write-doc` 안의 저장 전 검사(정적 · 모델). 검사는 UI 가 저장 전에 한다
- doctor 항목에 조치 키를 더하는 것. 항목 구조는 #59 의 네 키 그대로다
- 문서 탭 구성의 변경. 탭과 질문 양식은 `fields.js` 의 `DOCS` 가 갖고, 더해지거나 빠지는 탭은 없다
- 모델 질의(`ask`) · 명령 탭 실행(`runCommand`) · 폴더 선택 창(`pickDirectory`) — UI 가 파일을 쓰는 동작이 아니다
- 절차 명령 허용 목록의 생성 (#70)
