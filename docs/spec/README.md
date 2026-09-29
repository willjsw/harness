# 명세

이 디렉터리는 **프로젝트 것이다.** 하네스 갱신이 덮지 않는다.

## 파일 이름

| 종류 | 형식 | 예 |
|---|---|---|
| 시나리오 명세 | `S-<번호>-<영문-요약>.md` | `S-01-inbound-message.md` |
| 그 밖의 기능 명세 | `<이슈번호>-<영문-요약>.md` | `42-retry-policy.md` |

번호는 재사용하지 않는다. 명세를 지워도 그 번호는 비워 둔다 — 커밋과 이슈가 옛 이름으로
그 문서를 가리키고 있고, 번호를 돌려쓰면 그 참조가 **틀린 문서를 가리킨 채** 남는다.

## 문서

<!-- 명세를 추가할 때마다 이 표에 한 행을 더한다. 이 주석은 지우지 않는다. -->

| 문서 | 다루는 것 |
|---|---|
| [`58-separate-managed-and-project-parts.md`](58-separate-managed-and-project-parts.md) | 관리 부품과 프로젝트 부품의 경계 — `script/project/` 소유 자리, 사용자 파일 덮어쓰기 차단과 `--adopt`, `.harness/managed` 의 sha256 매니페스트(옛 형식 호환), `check`·`doctor` 의 관리 파일 대조, 전역 CLI 의 고정 사본 대조 |
| [`63-usage-log-config-values.md`](63-usage-log-config-values.md) | 사용 기록의 브랜치 유형 분류 — 설정 값으로 판정, 설정 누락 시 기록하지 않음 |
| [`64-modularize-cli-review-scripts.md`](64-modularize-cli-review-scripts.md) | 리뷰 판정 데이터(JSON) 계약·집계·등록 댓글 렌더링, 리뷰 루프 공용 모듈, CLI 지표 모듈 분리와 중복 정리, 테스트 기록 경로 격리 |
| [`70-generate-permission-allow-list.md`](70-generate-permission-allow-list.md) | `.claude/settings.json` 의 권한 허용 목록 생성 — 관리 스크립트·forge 선언(`allow.toml`)·git 명령 묶음, `[permissions].allow_push`, 제외 스크립트, deny 유지와 회귀 테스트 |
| [`71-issue-worktree-run.md`](71-issue-worktree-run.md) | `harness run --worktree` — 이슈별 worktree 생성·다시 열기·정리 판정, `[worktree]` 설정, doctor 보고, 세션 가져오기의 worktree 귀속, 반복 지적 이력의 공통 디렉터리 이동, 되감기의 worktree 브랜치 처리 |
| [`79-reject-duplicate-project-name.md`](79-reject-duplicate-project-name.md) | 설치 등록부의 같은 이름 거부 — 기존 등록 판정(재설치·낡은 등록 넘겨받기·거부), 거부 안내문, doctor `registry` 절과 UI 문구, README 안내 |
| [`61-start-server-background.md`](61-start-server-background.md) | `start-server` 의 빌드 판정(UI 소스 해시↔스탬프)·백그라운드 기동·응답 대기, `ui.pid` 기록과 서버 식별, `stop-server` · `server-status`, `--dev` 포그라운드, 없는 프로젝트 404, 보호 문서 개정 범위 |
