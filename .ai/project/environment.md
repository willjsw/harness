<!--
이 파일은 프로젝트가 소유한다. 하네스 갱신이 덮지 않는다.
**값을 적지 않는다.** 항목명과 취득 경로만 적는다 — 시크릿은 리포에 남기지 않는다.
-->

### 필요한 도구

- `python3` 3.11 이상 — CLI 와 테스트. 그 밖의 의존성은 없다
- `git` — 훅과 착수 판정
- `node` · `npm` — UI(`harness start-server`)와 UI 단위 테스트. 서버 첫 실행이 `npm install` 을 한다
- `gh` — 이 리포의 forge(GitHub) 어댑터. `gh auth login` 으로 인증한다
- `claude` — 오케스트레이터. `codex` — code-reviewer 역할의 러너. 설치 여부와 모델 목록은 `harness tools --sync` 가 `~/.harness/tools.json` 에 기록한다
- `brew` — 전역 CLI 를 올릴 때만 (`brew update && brew upgrade --fetch-HEAD harness`)

### 환경 변수

| 이름 | 용도 | 어디서 얻나 |
|---|---|---|
| `HARNESS_HOME` | 설치 등록부·도구 기록의 위치. 비우면 홈 아래 `.harness/` | 테스트가 임시 위치로 준다. 평소엔 두지 않는다 |
| `HARNESS_METRICS` | `off` 면 그 프로세스와 자식이 실행 지표를 남기지 않는다 | `doctor` 가 검증을 돌릴 때 스스로 준다 |
| `HARNESS_TRACE_ID` · `HARNESS_PARENT_SPAN` · `HARNESS_WORKFLOW` | 실행 지표의 트레이스·부모 스팬·절차를 자식 프로세스에 넘긴다 | `harness run` 과 `script/metric.py` 가 준다. 손으로 두지 않는다 |
| `HARNESS_USAGE_LOG` | 사용 기록 파일 경로 재지정 | 필요할 때만. 기본값은 `harness.toml` 의 `[usage]` |
| `HARNESS_BIN` | UI 가 부를 CLI 경로 | `harness start-server` 가 자기 실행 파일로 준다 |

### 외부 시스템

- GitHub `willjsw/harness` — 이슈와 리뷰 요청. `gh` 의 인증을 쓴다
- Homebrew 탭 `willjsw/homebrew-harness` — 전역 CLI 배포. 포뮬러는 그 리포에서 고친다
