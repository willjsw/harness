# #70 분해 — 절차가 부르는 명령의 권한 허용 목록 생성

명세: [`docs/spec/70-generate-permission-allow-list.md`](../../spec/70-generate-permission-allow-list.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | 관리 스크립트·forge 선언·git 명령으로 권한 허용 목록 생성 | 없음 |
| T2 | feat | `[permissions].allow_push` 설정과 `git push` 허용 | T1 |
| T3 | docs | README 설정 표와 가드레일 층위에 권한 허용 목록 반영 | T2 |

- T1 이 `src/bin/harness` 의 `allow_rules()` 와 제외 목록 상수, `src/templates/forge/<kind>/allow.toml` 세 파일, `src/test/render-test.sh` 의 새 `UT-75` 블록을 만든다.
  이 단계의 git 묶음은 `git switch -c` · `git commit` 둘이다
- T2 는 `[permissions]` 절(기본 설정 · `normalize()` · `validate()` · `set_line()`)을 더하고, `allow_rules()` 가 `allow_push` 로 `git push` 규칙을 넣게 한다.
  UI 도움말과 설정 화면 묶음도 T2 에서 고친다. 회귀 테스트는 T1 의 `UT-75` 블록에 더한다
- T3 은 T1 · T2 가 만든 동작을 사람용 문서에 적는다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/70-generate-permission-allow-list` — 요구사항 이슈 #70 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: 절차가 부르는 명령의 권한 허용 목록 생성(#70)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #70` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #70`

## 전 task 공통 사항

- `permissions.deny` · `hooks.PreToolUse` · git 훅은 바꾸지 않는다. `deny_rules()` 의 입력과 출력이 그대로다 (명세 1절)
- 대상은 `.claude/settings.json` 하나다. `.codex/` 생성물은 바꾸지 않는다
- 새 생성 파일은 없다 — `plan()` 을 고치지 않는다
- `allow.toml` 은 허용 목록 생성만 읽는다. forge 명령 사전(`.ai/forge.md`) 조립은 지금처럼 `tracker.md` · `review.md` 만 읽는다
- 회귀 테스트는 생성 구조만 본다. Claude Code 의 권한 판정을 흉내 내는 함수를 두지 않는다 (명세 8절)
- 관리 스크립트 목록은 테스트에 적지 않고 설치된 `script/` 에서 센다
- CLI 는 표준 라이브러리만 쓴다. `allow.toml` 은 `tomllib` 으로 읽는다
- 출력 문구는 명세의 영어 원문 그대로 둔다
- 주석과 테스트 이름에 이슈 번호·문서 번호·테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록 형식을 따른다
- 이 리포의 생성물(`.claude/settings.json` · `script/README.md`)은 `harness render` 로 다시 만들어 같은 커밋에 넣는다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- Codex 오케스트레이터의 승인 정책과 `.codex/` 생성물
- 이슈 생성 · 라벨 변경 · 머지 · 닫기 · 현재 사용자 조회 등 명세 4-1 이 뺀 forge 명령의 허용
- 프로젝트가 둔 스크립트(`script/project/` 등)와 생성 스크립트의 허용
- `bash-guard.sh` 의 판정 변경
