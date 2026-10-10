# 여러 클론이 함께 쓰는 반복 지적 이력과 착수 잠금

같은 리포를 여러 사람·여러 클론이 돌려도 리뷰 루프가 같은 상태를 본다. 반복 지적 이력은 클론 로컬 파일이 아니라
**리뷰 요청의 요약 댓글**에 남고, 다음 회차는 그 댓글들에서 연속 회차를 다시 센다. 같은 이슈의 `work` 는
**원격의 착수 잠금 ref** 를 만든 클론 하나만 돌고, 배선이 끝 상태로 갈 때 그 ref 를 지운다. 서버를 두지 않는다 —
forge 의 댓글과 git 원격의 ref 가 공유 상태의 정본이다.

기준 코드는 #211 · #212 · #213 의 변경이 들어간 통합 브랜치다. 이 명세의 구현은 셋이 머지된 뒤 착수한다. 이 명세는 외부 계약 —
명령 인자·출력·종료 코드, 댓글 데이터 형식, 잠금 프로토콜, 절차 배선, 테스트 케이스 — 으로 적고, 코드가 놓이는 자리는
아래 이슈가 정한 것을 따른다.

| 따르는 것 | 정하는 이슈 |
|---|---|
| 패키지 배치, 명령마다 모듈 하나(`src/harness/commands/<명령>.py`, 이름의 `-` 는 `_`), 명령 모듈끼리 부르지 않고 함께 쓰는 코드는 공용 모듈에 둔다는 규칙 | #206 |
| 내장 기본값 파일 `src/templates/defaults.toml`, 공유 설정 | #207 |
| driver 절차의 끝 상태 · 배선 · 실행 상태 · 재개 · `--discard`, 드라이버가 스스로 내는 `stop` | #208 |
| 자체 검사의 자리(`src/harness/forge/selftest.py`) | #209 |
| 리뷰 · 착수 판정 하위 명령(`harness review` · `harness preflight`), 리뷰 모듈 `src/harness/review.py`, 하위 명령의 인자 거부 규칙 | #211 |
| 기본 `work` driver 절차와 하위 절차 `review-loop`, doctor 의 `work` 절 점검 | #212 |
| 되감기 하위 명령 `harness rollback`, 표지 정본 `src/harness/format.py` 와 셸 표기의 일치 검사, shim 의 공통 형태(213 명세 4-1) | #213 |

정본 위치:

| 대상 | 정본 |
|---|---|
| 요약 기록의 렌더·읽기, 연속 회차 재구성, 리뷰 입력의 인용 | 리뷰 모듈 `src/harness/review.py`. 스레드 조회와 순서는 리뷰 명령 모듈 `src/harness/commands/review.py`. 진입점 `script/review-mr.sh` · `script/post-review.sh`(#211 의 shim)는 그대로다 |
| 기록 표지 `FMT_REVIEW_RECORD` | 표지 정본 `src/harness/format.py`. 셸 표기 `src/templates/managed/script/harness-format.sh` 에도 같은 이름과 값을 둔다 |
| 착수 잠금 명령 `harness work-lock` | 명령 모듈 `src/harness/commands/work_lock.py`. 대상 리포 진입점 `src/templates/managed/script/work-lock.sh`(shim) |
| 잠금 프로토콜 — 접두 상수 · 잠금 커밋 · 획득 · 해제 · 상태 · 소유 기록 | 공용 모듈 하나. 이름과 자리는 #206 의 공용 모듈 규칙을 따른다. 잠금 명령 · 되감기 · pre-push 판정 · 자체 검사가 이 모듈을 함께 쓴다 |
| 기본 절차 `work` 의 잠금 배선 | 내장 기본값 파일 `src/templates/defaults.toml` 의 `[workflows.work]` (#212 가 정한 driver 절차) |
| agent 모드 `work` 문서의 잠금 지시 | `src/templates/workflows/work/` 의 머리 조각(`_head`) · 꼬리 조각(`_tail`) |
| 위임 어댑터 | `src/templates/managed/.claude/commands/work.md` |
| pre-push 판정 | 생성 훅 `script/githooks/pre-push` 와 그것이 부르는 하네스 코드 |
| 되감기 | 되감기 명령 `harness rollback` 의 모듈(#213). 진입점 `script/rollback-work.sh`(#213 의 shim)는 그대로다 |
| 자체 검사 | `src/harness/forge/selftest.py`. 진입점 `script/forge-selftest.sh` 는 그대로다 |
| 회귀 테스트 | `src/test/unit/` · `src/templates/managed/script/test-review-loop.sh` · `test-rollback-work.sh` · `src/test/render-test.sh` |

이 리포의 `script/` · `.ai/` 아래 같은 이름의 파일은 거기서 설치·생성된 사본이다.

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

바뀌는 것:

- 반복 지적 이력이 클론 로컬 파일에서 **요약 댓글의 마지막 줄(요약 기록)** 로 옮겨 간다. 어느 클론에서 이어 돌려도
  같은 연속 회차를 센다 (2절)
- 리뷰 등록이 판정 전에 그 리뷰 요청의 스레드를 조회한다 (2-4)
- 착수 잠금 명령이 생긴다 (3절). 기본 `work` 가 시작 단계에서 잠금을 잡고 끝 상태로 가는 배선에서 푼다 (4절)
- pre-push 훅이 잠금 이름공간만 담은 push 에 검증을 돌지 않는다 (5절)
- 되감기가 이 클론의 착수 잠금을 푼다 (6절)
- 자체 검사의 `--write` 단계에 잠금 항목 셋이 더해진다 (7절)

바뀌지 않는 것:

- `review-mr.sh` · `post-review.sh` 의 명령줄 인자와 종료 코드(0 PASS · 1 CHANGES_REQUESTED · 2 실패·계약 위반 · 3 상한),
  회차 라벨과 회차 상한(`review.max_rounds`). 회차 라벨이 주 상한이고 반복 카운트는 보조 신호다
- 반복 키와 연속 규칙 — 키는 심각도가 `FMT_INLINE_SEVERITIES`(blocker · major)인 발견의 `path`(`null` 이면 `FMT_NO_LOCATION`)이고
  줄 번호를 넣지 않으며 한 회차의 같은 키는 한 번만 센다. 연속한 회차만 세고, blocker·major 가 없던 회차는 연속을 끊고,
  요약 등록에 성공한 회차만 센다. 상한 값은 `review.repeat_file_max`
- 요약 댓글에서 기록 줄 앞의 본문(`docs/spec/64-modularize-cli-review-scripts.md` 4-1)과 인라인 댓글
- 착수 판정(`script/work-preflight.sh`)의 검사·출력·종료 코드
- forge 어댑터 계약 — 스레드 조회의 정규화 JSON 으로 충분하다. 어댑터 함수를 더하지 않는다
- 설정 키를 더하지 않는다

## 2. 반복 지적 이력 — 요약 기록

### 2-1. 요약 노트

**요약 노트**는 리뷰 요청의 스레드 조회 결과에서 본문이 앞 공백을 걷은 뒤 표지 `FMT_SUMMARY_HEADING` 으로 시작하는 노트다.
리뷰 입력이 직전 회차 요약을 고르는 규칙과 같은 정의이고, 두 곳이 그 정의 하나를 함께 쓴다.

작성자 표시(`post-review.sh` 의 셋째 인자)와 등록한 계정을 가리지 않는다. 누구의 등록이든 요약 노트 하나가 회차 하나다.

### 2-2. 기록 줄

리뷰 등록은 요약 댓글 본문의 **마지막 줄**에 기록 줄 하나를 쓴다. 바로 앞 줄은 빈 줄이다.

```
<!-- harness:review-record {"format":1,"keys":["script/review-mr.sh","(\ud30c\uc77c \ubbf8\uc9c0\uc815)"]} -->
```

- 형식: `<!-- ` · 표지 `FMT_REVIEW_RECORD` · 공백 하나 · JSON · ` -->`
- 표지 `FMT_REVIEW_RECORD` 의 값은 `harness:review-record` 다. 리뷰 등록이 쓰고 다음 회차가 읽는다
- 표지 정본 `src/harness/format.py` 와 셸 표기 `script/harness-format.sh` 둘 다에 같은 값으로 더하고, 두 쪽 모두 등록 댓글 표지
  (`FMT_SUMMARY_HEADING` · `FMT_REVIEWED_HEAD`) 곁에 둔다. 셸 표기에서는 "등록 댓글" 절이다. 한쪽에만 더하면 #213 의 일치 단위 테스트가 막는다
- JSON 은 키 둘의 객체다

| 키 | 값 |
|---|---|
| `format` | 형식 판별자. 정수 `1`. 반복 키의 구성이 바뀌면 올린다 |
| `keys` | 이번 회차의 반복 키. 처음 나온 순서이고 중복이 없다. blocker·major 가 없는 회차는 빈 배열 |

- 직렬화: 키 순서는 `format` · `keys`, 구분자에 공백이 없다. ASCII 밖의 문자와 `<` · `>` · `&` 는 `\uXXXX` 로 쓴다.
  그래서 기록 줄은 ASCII 한 줄이고, 주석을 닫는 `-->` 가 값 안에 나타나지 않으며, forge 가 댓글의 유니코드를 정규화해도 바뀌지 않는다
- 예: 경로 `a-->b.sh` 는 `"a--\u003eb.sh"`, blocker·major 가 없는 회차는 `{"format":1,"keys":[]}`
- 판정 데이터의 다른 필드와 리뷰어 출력 원문은 기록에 넣지 않는다. 기록은 판정 데이터 스키마와 따로 있어, 그 스키마가 바뀌어도
  기록의 형식과 읽기 규칙은 그대로다

### 2-3. 기록 읽기

요약 노트 하나의 기록은 아래를 **모두** 만족할 때 읽힌 것이다. 하나라도 어기면 그 노트는 **알 수 없는 기록**이다.

1. 본문을 Python `str.splitlines()` 로 나누고 줄마다 끝 공백을 걷었을 때, `<!-- ` 와 표지로 시작하는 줄(기록 줄)이 정확히 하나다
2. 기록 줄이 비지 않은 마지막 줄이다
3. 기록 줄이 ` -->` 로 끝나고, 앞의 `<!-- <표지> ` 와 뒤의 ` -->` 사이가 JSON 객체로 읽힌다
4. 객체의 키가 정확히 `format` · `keys` 이고, 같은 키가 둘이 아니다
5. `format` 이 정수 `1` 이다. 불리언은 정수로 받지 않는다
6. `keys` 가 문자열 배열이고, 원소마다 `FMT_NO_LOCATION` 과 같거나 판정 데이터 `path` 의 규칙(64 명세 2-2 — `/` 로 시작하지 않고,
   `..` 경로 조각이 없고, Cc · Zl · Zp · Cf 문자가 없다)을 지킨다

읽힌 기록의 키 집합은 `keys` 원소의 집합이다. 줄 끝의 CR 은 끝 공백으로 걷히므로 CRLF 본문도 읽힌다.

### 2-4. 연속 회차 재구성

리뷰 등록은 판정 전에 그 리뷰 요청의 스레드를 조회한다(forge 어댑터의 스레드 조회 — 리뷰 입력이 쓰는 것과 같다). 그 뒤 아래 순서로
연속 회차를 센다.

1. 요약 노트를 만든 시각(`created_at`) 오름차순으로 늘어놓는다. 시각이 같으면 조회 결과의 순서를 따른다. 노트마다 2-3 으로 읽힌 키 집합
   또는 알 수 없는 기록이 된다 — 이것이 **이전 회차 목록**이다
2. 이번 회차의 판정 데이터에서 반복 키 집합을 낸다
3. 그 키마다 **연속 회차 = 1 + 이전 회차 목록의 끝에서부터 그 키를 가진 기록이 이어지는 수**다. 그 키가 없는 기록이나 알 수 없는 기록에서 멈춘다
4. 연속 회차가 `review.repeat_file_max` 이상인 키가 있으면 요약 댓글에 반복 줄(64 명세 4-1)을 쓰고, 요약 등록에 성공한 뒤 종료 코드 3 이다

요약 등록이 실패하면 그 회차의 요약이 원격에 없으므로 다음 회차의 목록에 들지 않는다 — 등록에 성공한 회차만 센다는 규칙이 그대로 성립한다.
이번 회차의 기록은 이번 회차의 키만 담으므로, 조회에 실패한 회차의 기록도 다음 회차가 그대로 쓸 수 있다.

### 2-5. 조회 실패와 알 수 없는 기록

- 스레드를 조회하지 못했거나 결과가 정규화 JSON 배열로 읽히지 않으면 이전 회차 목록을 **알 수 없는 기록 하나**로 둔다. 표준 오류에
  `warning: could not read the review threads — repeat findings are counted from this round only` 를 쓰고 등록과 판정을 계속한다.
  조회 실패는 종료 코드에 닿지 않는다. 이번 회차만으로 상한에 닿는 경우(`review.repeat_file_max` 가 1)는 그대로 3 이다
- 조회에 성공했고 요약 노트 가운데 알 수 없는 기록이 있으면 표준 오류에 `note: <N> earlier review summaries carry no readable record — repeat counts restart after them` 한 줄을 쓴다
- 기록 줄이 없는 요약(이 형식이 생기기 전에 등록된 것 포함)과 다른 판별자의 기록은 알 수 없는 기록이다. 진행 중인 리뷰 요청은 마지막 알 수 없는
  기록 뒤부터 연속을 센다

알 수 없는 기록이 연속을 끊는 것은 의도다. 반복 카운트는 보조 신호이고, 읽지 못한 회차를 이어진 것으로 세면 틀린 상한이 생긴다.
위조된 기록 줄이 할 수 있는 일은 거짓 종료 코드 3(사람에게 넘김)과 반복 신호의 누락뿐이고, 루프의 종료는 회차 라벨이 보장한다.

### 2-6. 리뷰 입력

직전 회차 요약을 리뷰 입력에 인용할 때 그 요약에서 `<!-- ` 와 표지로 시작하는 줄을 모두 빼고 인용한다. 직전 요약을 고르는 규칙,
리뷰 시점 head(`FMT_REVIEWED_HEAD`)를 읽는 규칙, 리뷰 입력의 절 구성은 그대로다.

### 2-7. 클론 로컬 이력

- `<git 공통 디렉터리>/work-loop/` 를 만들지도 읽지도 쓰지도 않는다
- 이미 있는 `review-findings-<번호>.tsv` 는 하네스가 지우지 않는다. 어느 동작도 읽지 않으므로 사람이 지워도 된다
- 리뷰 등록은 반복 이력 때문에 git 리포를 요구하지 않는다 — 211 명세 2-3 순서표의 "이력 자리"(4) · "이력 누적"(8) 단계가 없어진다.
  리뷰한 리비전을 인자로 받지 않았을 때 `HEAD` 를 읽는 동작은 그대로다

## 3. 착수 잠금

**착수 잠금**은 같은 이슈의 `work` 를 한 번에 한 클론만 돌게 하는 원격 ref 다. 잠금을 잡는 것은 원격에 그 ref 를 **없을 때만** 만드는 것이다.
git 서버는 push 가 보낸 기대값(갱신 전 값)을 확인하고 ref 를 바꾸므로, 같은 ref 를 동시에 만들려는 두 push 가운데 하나만 받아진다.
<!-- TBD: 확인 필요 — GitHub · GitLab 이 refs/heads 밖 이름공간(refs/harness/work-lock/*)의 생성·삭제 push 를 받는지, 받을 때 생성 전용(기대값 없음)·기대값 삭제의 기대값 검사를 하는지. 7절의 자체 검사 항목이 이것을 실제 forge 로 확인한다 -->

### 3-1. 이름과 내용

- 이름은 `refs/harness/work-lock/<이슈>` 다. 접두 `refs/harness/work-lock/` 는 하네스 코드 한 곳의 상수이고, 잠금 명령 · pre-push 판정 ·
  자체 검사 · 되감기가 그 상수를 쓴다
- `<이슈>` 는 `^[0-9]+$` 또는 Jira 키 `^[A-Z][A-Z0-9_]*-[0-9]+$` 다. 그 밖의 값은 git 을 부르지 않고 종료 코드 2 다
- 원격은 `origin` 이다. ref 는 리포 단위다 — 모노레포의 서브프로젝트들은 같은 이슈에 같은 잠금을 쓴다
- ref 의 값은 **잠금 커밋**이다
  - 부모가 없고 트리가 비어 있다
  - 메시지에 이슈와 128비트 무작위 값(16진 32자)을 담는다. 획득마다 새로 만들므로 같은 클론 · 같은 시각 · 같은 작성자라도 서로 다른 커밋이다
  - 작성자와 커미터는 그 클론의 git 설정에서 온다. `git commit-tree` 로 만들어 커밋 훅을 거치지 않는다. 신원 설정이 없어 만들지 못하면 판정 불가(2)다
- 잠금 커밋의 작성자와 시각은 사람이 누가 언제 잡았는지 볼 때 쓴다. 판정은 원격 ref 의 값(객체 이름)과 소유 기록(3-2)의 비교로만 한다
- `refs/heads/` 밖이라 git 의 기본 fetch refspec 과 브랜치 목록에 나오지 않는다

### 3-2. 소유 기록

- 파일 `<git 공통 디렉터리>/harness/work-lock/<이슈>` — 이 클론이 만든 잠금 커밋의 전체 객체 이름 한 줄
- git 공통 디렉터리는 하네스 루트에서 `git rev-parse --path-format=absolute --git-common-dir` 로 구한 절대 경로다. 같은 클론의 원래 작업 트리와
  모든 worktree 가 같은 기록을 본다 — **잠금의 소유 단위는 클론이다**
- 쓰기는 같은 디렉터리의 임시 파일을 rename 한다. 내용이 16진 40자 또는 64자 한 줄이 아니면 기록이 없는 것으로 본다
- **원격 값과 기록이 같으면 이 클론의 잠금이다.** 그 밖의 원격 값은 다른 클론의 잠금이다

### 3-3. 명령

```
script/work-lock.sh <acquire|release|status> <이슈>
```

대상 리포의 진입점이고 하네스 명령 `harness work-lock` 을 부른다. 진입점은 213 명세 4-1 의 shim 이다.

- 자기 파일이 있는 디렉터리의 부모를 하네스 루트로 잡고, `<루트>/.harness/bin/harness` · `<루트>/src/bin/harness` 순으로 실행 가능한
  첫 것을 `<CLI> --target <루트> work-lock <받은 인자 그대로>` 로 exec 한다. 현재 디렉터리 · 표준 입출력 · 환경을 바꾸지 않는다
- CLI 를 찾지 못하면 표준 오류에 `error: harness CLI not found under <루트> (.harness/bin/harness or src/bin/harness)` 와
  `help: harness install --target <루트>` 를 내고 2 다. 판정하지 못함과 같은 코드이므로 `lock` 단계는 `stop` 으로 간다

`work-lock` 은 `COMMANDS` 와 `DELEGATES` 에 든다 — 프로젝트에 고정된 버전이 답한다. 읽는 설정은 공유 설정(#207)이고 이 명령이 쓰는
설정 키는 없다. 설정을 읽지 못하면 판정하지 못함(2)이다. git 은 하네스 루트에서 부른다. 인자 규칙은 #211 의 하위 명령과 같다 —
동작과 이슈 말고 다른 인자가 있으면 종료 코드 2 다.

| 동작 | 결과 | 종료 코드 | 표준 출력 |
|---|---|---|---|
| `acquire` | 새로 잡았다 | 0 | `acquired refs/harness/work-lock/<이슈>` |
| | 이미 이 클론의 잠금이다 | 0 | `already held by this clone: refs/harness/work-lock/<이슈>` |
| | 다른 클론의 잠금이다 | 1 | 없음 |
| | 판정하지 못했다 | 2 | 없음 |
| `release` | 풀었다 | 0 | `released refs/harness/work-lock/<이슈>` |
| | 원격에 이 클론의 잠금이 없다 | 0 | `no lock held by this clone for issue <이슈>` |
| | 풀지 못했다 | 2 | 없음 |
| `status` | 판정했다 | 0 | `free` · `mine <객체 이름>` · `held <객체 이름>` 중 한 줄 |
| | 판정하지 못했다 | 2 | 없음 |

표준 오류:

| 경우 | 줄 |
|---|---|
| `acquire` 1 | `stop: issue <이슈> is being worked on from another clone — refs/harness/work-lock/<이슈> is <객체 이름 앞 12자>`<br>`help: if that run ended without releasing it, delete the lock: git push origin --delete refs/harness/work-lock/<이슈>` |
| 판정하지 못함 (2) | `error: <무엇을 하지 못했는지>` 한 줄과 `help:` 한 줄. git 의 출력에서 원격 주소를 옮기지 않는다 |
| `release` 2 | `error: could not release refs/harness/work-lock/<이슈> — it stays held`<br>`help: rerun script/work-lock.sh release <이슈>` |

- git 을 부를 때 `GIT_TERMINAL_PROMPT=0` 을 준다 — 자격 증명을 묻느라 멈추지 않고 2 로 끝난다
- 세 동작 모두 같은 상태에서 다시 돌려도 결과가 같다. 재개가 중단된 단계를 처음부터 다시 돌려도 된다
- 사용 기록 어휘를 늘리지 않는다
- 권한 허용 목록에 든다 — 관리 스크립트 허용 규칙(70 명세)대로이고 제외 목록에 넣지 않는다. 다른 클론의 잠금을 지우는 동작이 없다
- 관리 스크립트 표(`src/templates/managed/script/README.md`)에 shim 행 한 줄을 더한다
- `script/work-lock.sh` 를 걷고 절차 · 문서의 표기를 하위 명령으로 바꾸는 일은 #221 이 한다

### 3-4. 획득

1. 원격 값 R 을 읽는다 — `git ls-remote --refs origin refs/harness/work-lock/<이슈>` 의 출력에서 ref 이름이 정확히 같은 줄. 명령이 실패하면 2
2. 소유 기록 L 을 읽는다
3. R 이 있고 R = L 이면 0 (`already held by this clone`). push 하지 않는다
4. R 이 있고 R ≠ L 이면 L 을 지우고 1
5. R 이 없으면 새 잠금 커밋 C 를 만들고, **C 를 소유 기록에 먼저 쓴 뒤**(있던 기록은 덮는다) 생성 전용으로 push 한다

   ```
   git push --porcelain --force-with-lease=refs/harness/work-lock/<이슈>: origin <C>:refs/harness/work-lock/<이슈>
   ```

   기대값이 빈 lease 는 원격에 그 ref 가 없을 때만 받아진다
6. push 의 종료 코드와 출력으로 판정하지 않는다. R 을 다시 읽어 판정한다

| 다시 읽은 R | 기록 | 종료 코드 |
|---|---|---|
| C | 남긴다 | 0 (`acquired`) |
| C 가 아닌 값 — 그 사이 다른 클론이 잡았다 | 지운다 | 1 |
| 없다 — push 가 받아지지 않았다(이름공간 거부 · 권한 · 네트워크) | 지운다 | 2 |
| 읽지 못했다 | 남긴다 | 2 |

기록을 push 전에 쓰고 다시 읽지 못했을 때 남기므로, push 가 원격에 닿고 응답만 잃은 경우에도 다음 획득이 3번에서 이 클론의 잠금을 알아본다.

### 3-5. 해제

1. 소유 기록 L 을 읽는다. 없으면 원격을 부르지 않고 0 (`no lock held by this clone`)
2. 기대값을 L 로 건 삭제 push 를 한다 — 원격 값이 L 일 때만 지워진다

   ```
   git push --porcelain --force-with-lease=refs/harness/work-lock/<이슈>:<L> origin :refs/harness/work-lock/<이슈>
   ```

3. R 을 다시 읽어 판정한다

| 다시 읽은 R | 기록 | 종료 코드 |
|---|---|---|
| 없다 | 지운다 | 0 (`released`) |
| L 이 아닌 값 — 이 클론의 잠금은 이미 없고 지금 값은 다른 클론의 것이다 | 지운다 | 0 (`no lock held by this clone`). 원격 값은 건드리지 않는다 |
| L | 남긴다 | 2 |
| 읽지 못했다 | 남긴다 | 2 |

### 3-6. 상태

R 과 L 을 읽어 R 이 없으면 `free`, R = L 이면 `mine <R>`, 그 밖이면 `held <R>` 를 낸다. 원격도 기록도 바꾸지 않는다. R 을 읽지 못하면 2 다.

### 3-7. 원격 삭제의 범위

- 하네스가 원격 ref 를 지우는 경로는 해제 하나다(되감기가 부르는 해제 포함). 지우는 것은 잠금 이름공간의 ref 하나이고, 원격 값이 **이 클론이 만든 값일 때만**
  지운다(기대값 삭제)
- 되감기의 "원격 브랜치를 지우지 않는다" 는 그대로다. 잠금 ref 는 브랜치가 아니고 그 위에 작업이 올라가지 않는다
- 명령 가드는 에이전트가 직접 치는 `--force-with-lease` · `--delete` push 를 잠금 ref 에도 그대로 막는다. **다른 클론의 잠금을 지우는 것은 사람이 한다**

## 4. 절차 배선

### 4-1. driver `work`

내장 기본값의 `work`(`src/templates/defaults.toml`, #212 가 정한 driver 절차)에 단계 넷을 더하고 끝 상태로 가는 배선을 바꾼다.
이 리포는 기본 `work` 를 쓴다.

| 단계 id | 블록 | 제목 | `run` | 배선 |
|---|---|---|---|---|
| `lock` | script | 착수 잠금 | `script/work-lock.sh acquire {issue}` | `"0"` → `clean`(#212 의 첫 단계) · `"*"` → `stop` |
| `unlock-done` | script | 잠금 해제 | `script/work-lock.sh release {issue}` | `"*"` → `done` |
| `unlock-stop` | script | 잠금 해제 | `script/work-lock.sh release {issue}` | `"*"` → `stop` |
| `unlock-handoff` | script | 잠금 해제 | `script/work-lock.sh release {issue}` | `"*"` → `handoff` |

- **`lock` 이 `work` 의 시작 단계다.** #212 가 정한 작업 트리 확인(`clean`)과 착수 판정(`preflight`)보다 앞이다. 착수 판정은 잠금을 잡은 뒤에 해야 잠금을 쥔 동안 유효하다 —
  잠금 전에 판정하면, 그 사이 다른 클론이 리뷰 요청을 만들고 루프를 끝내 잠금을 푼 경우를 보지 못하고 같은 이슈를 다시 착수한다
- `lock` 이 0 이 아니면 곧바로 `stop` 이다. 잡지 않은 잠금이므로 해제를 거치지 않는다
- `lock` 뒤의 단계에서 끝 상태(`done` · `stop` · `handoff`)로 가던 배선은 모두 **같은 이름의 해제 단계**로 간다. 끝 상태를 직접 가리키는 배선은 `lock` 의 실패 쪽과
  해제 단계 셋뿐이다
- 하위 절차(`review-loop` 등)는 바꾸지 않는다. 하위 절차의 끝 상태는 그것을 부른 `work` 단계의 결과로 돌아오고, 그 단계의 배선이 위 규칙을 따른다
- 해제 단계의 결과는 끝 상태를 바꾸지 않는다. 해제가 2 면 잠금 명령의 표준 오류가 실행 출력에 남고 잠금만 남는다
- 끝 상태가 아닌 멈춤(게이트 대기 등 #208 이 정한 재개 가능한 멈춤)에서는 잠금을 유지한다. 재개는 같은 클론에서 하므로 잠금은 그대로 이 클론의 것이다
- 해제 단계를 거치지 않고 끝나는 경우가 셋이다. 셋 모두 원격 잠금이 남는다
  - 드라이버가 스스로 낸 `stop`(#208 의 방문 · 단계 상한, 값이 없는 자리표시, 배선이 없는 outcome) — 깊이와 상관없이 실행 전체가 그 자리에서 끝난다
  - 끝 상태에 닿지 못하고 끊긴 실행(중단 신호 · 프로세스 종료 · 예외) — 실행 상태도 남는다
  - `harness run work <이슈> --discard` — 실행 상태만 지우고 잠금은 풀지 않는다
- 남은 잠금은 이 클론의 것이다. 같은 클론에서 그 이슈를 다시 돌리면(`--resume`, 또는 실행 상태가 없을 때 새 실행) 획득이 이 클론의 잠금을
  알아보고(3-4 의 3) 이어 간다. 다시 돌리지 않으면 **`script/work-lock.sh release <이슈>` 로 푼다** — 끊긴 실행을 `--discard` 로 버릴 때는
  이 해제를 함께 돈다. 그동안 다른 클론은 1 로 멈춘다. 다른 클론에서의 회수는 6절과 3-3 의 `help` 다

### 4-2. agent 모드 `work` 문서

`work` 가 agent 모드로 렌더되면(#212 의 되돌림 경로, 옛 `[workflows.work]` 단계 목록을 가진 설치본 포함) **머리 조각과 꼬리 조각**이 잠금을 지시한다.
두 조각은 단계 목록과 무관하게 렌더되므로, 설치본의 단계 목록을 고치지 않아도 닿는다.

머리 조각 — "중단 조건":

- 순서: 작업 트리 → **잠금 획득** → 착수 판정(이슈 확인 포함) → 완료 조건
- 잠금 항목: "`script/work-lock.sh acquire <번호>` 가 0 이 아니다. 1 은 다른 클론이 이 이슈를 돌고 있다는 뜻이다. 2 는 잠금을 판정하지 못한 것이다 —
  "없음" 이 아니다. 멈추고 출력을 그대로 보고한다"
- "**잠금이 착수 판정보다 먼저다.**" 와 4-1 첫 항목의 이유 한 문장
- "잠금을 잡은 뒤 중단 조건에 걸리면 꼬리 조각의 해제를 돌고 끝낸다"

꼬리 조각 — "출력" 앞에 "끝내기 전" 절:

- "어느 판정으로 끝나든(PASS · 상한 도달 · 중단) `script/work-lock.sh release <번호>` 를 돈다. 잡지 않았으면 아무것도 하지 않고 0 이다"
- "2 면 그 출력을 '남은 것' 에 그대로 적는다 — 잠금이 남아 다른 클론이 이 이슈를 착수하지 못한다"
- "driver 실행이 해제 단계를 거치지 않고 끝났으면 — 드라이버가 스스로 낸 stop, 끊긴 실행을 `--discard` 로 버림 — 잠금이 남는다.
  이 이슈를 다시 돌리지 않으면 `script/work-lock.sh release <번호>` 로 푼다"
- 출력 양식의 머리 목록에 줄 하나: `- 착수 잠금: 해제 | 남음(<사유>)`

### 4-3. 위임 어댑터

`.claude/commands/work.md` 의 위임표에 행 하나를 더한다(#212 가 정한 대로 `work` 가 agent 모드일 때 깔리는 파일이다).

| 정본의 표현 | 이 하네스에서 | 넘기는 것 |
|---|---|---|
| 착수 잠금 (착수 판정 전 · 끝내기 전) | `script/work-lock.sh acquire <이슈번호>` · `script/work-lock.sh release <이슈번호>` — Bash | 이슈 번호 |

### 4-4. 리뷰 회차의 직렬화

- `work` 경로의 리뷰는 잠금을 잡은 클론에서만 돈다. 같은 리뷰 요청의 회차 라벨 갱신과 요약 등록이 클론 사이에서 겹치지 않고, 2절의 재구성은 이것을
  전제로 한 번에 한 등록자를 가정한다
- 손으로 부른 `script/review-mr.sh` · `script/post-review.sh`(또는 `harness review` · `harness review post`)는 잠금을 잡지 않는다. 그것끼리,
  또는 그것과 `work` 가 겹치는 동시 실행은 지원하지 않는다 — 양쪽이 같은 회차를 읽으면 상한을 한 번 넘긴다
- 리뷰 명령의 동시 실행 서술(#211 이 옮긴 명령 모듈의 머리 설명)을 위 두 항목으로 바꾼다

### 4-5. doctor — 잠금 없는 `work` 절

#212 가 둔 `work` 절 점검(설정의 `work` 절이 이전 기본값과 같으면 짚고 fix 조치로 지운다)의 이전 기본값 목록에, 잠금 단계가 없는 driver 기본값(#212 가 낸 것)을
더한다. 그 절을 가진 설치본은 절을 지우면 이 명세의 기본 `work` 를 받는다.

## 5. pre-push 훅

- 보호 브랜치 검사는 그대로 모든 갱신 줄에 돈다
- 갱신 줄의 원격 ref 이름이 잠금 접두 `refs/harness/work-lock/` 로 시작하면 **잠금 줄**이다. 판정은 ref 이름 전체로 한다 —
  `refs/heads/harness/work-lock/7` 은 잠금 줄이 아니다
- push 의 갱신 줄이 **전부** 잠금 줄이면 push 전 검증(HEAD 일치 · 작업 트리 · 검증 일괄)을 돌지 않고 통과한다. 생성과 삭제 모두다
- 잠금 줄과 다른 줄이 섞이면 잠금 줄의 리비전만 HEAD 일치 검사에서 빼고, 나머지는 지금대로 검사하고 검증한다
- 훅은 잠금 줄이 보내는 커밋의 내용을 보지 않는다
- `verify.pre_push` 가 꺼져 있으면 지금처럼 보호 브랜치 검사만 돈다

## 6. 되감기 — `harness rollback`

되감기(`harness rollback`, 진입점 `script/rollback-work.sh`)는 잠금 프로토콜 모듈의 상태 판정(3-6)으로 잠금 상태를 보고, 이 클론의 잠금만
해제(3-5)로 푼다. 같은 프로세스에서 부르고 `script/work-lock.sh` 를 거치지 않는다. 판정 결과는 잠금 명령의 같은 동작과 같다.

| 상태 | 보이는 단계 | 되감는 단계 |
|---|---|---|
| `mine` | "will be closed or removed" 아래 `    work lock refs/harness/work-lock/<이슈>   held by this clone` | 다른 대상을 모두 되감은 **뒤에** 해제(3-5). 성공하면 `released the work lock refs/harness/work-lock/<이슈>`, 2 면 `warning: could not release the work lock refs/harness/work-lock/<이슈>` 와 실패(종료 코드 2) |
| `held` | "left alone" 아래 `    work lock refs/harness/work-lock/<이슈> — held by another clone. if that run is gone, delete it yourself: git push origin --delete refs/harness/work-lock/<이슈>` | 건드리지 않는다 |
| `free` | 없음 | 없음 |
| 판정 불가 (2) | "left alone" 아래 `    work lock — state unknown (could not read origin)` | 건드리지 않는다. 종료 코드에 닿지 않는다 |

- "되감을 것이 없음" 판정은 열린 리뷰 요청 · task 이슈 · 로컬 브랜치 · `mine` 잠금이 모두 없을 때다. 그때도 `held` · 판정 불가 줄은
  `nothing to roll back for issue <이슈>` 다음에 보인다
- 해제를 마지막에 하는 것은 되감는 도중에 다른 클론이 같은 이슈를 착수하지 않게 하려는 것이다
- `--dry-run` 은 상태만 보이고 해제하지 않는다
- 되감기 명령의 "되감는다" · "남긴다" 서술(#213 이 옮긴 명령 모듈의 머리 설명)에서 "되감는다" 에 이 클론의 착수 잠금을, "남긴다" 에
  다른 클론의 착수 잠금을 더한다
- `harness help` 의 `rollback` 설명은 `roll back what work made for an issue: close its review requests and task issues, remove local branches, release this clone's work lock (asks first)` 다

## 7. 자체 검사

자체 검사의 `--write` 단계에 항목 셋을 더한다. 잠금 프로토콜 모듈의 생성 · 삭제 코드를 쓰고, 이름은 이슈 잠금 형식과 겹치지 않는
`refs/harness/work-lock/selftest-<무작위 16진 12자>` 다 — 실사용 잠금을 건드리지 않는다.

| 항목 | 통과 조건 |
|---|---|
| `work lock: create` | 새 잠금 커밋을 생성 전용으로 push 한 뒤 원격 값이 그 커밋이다 |
| `work lock: exclusive` | 같은 이름에 다른 잠금 커밋을 생성 전용으로 push 하면 받아지지 않고 원격 값이 그대로다 |
| `work lock: delete` | 첫 커밋을 기대값으로 건 삭제 push 뒤 원격에 그 ref 가 없다 |

- `create` 가 실패하면 나머지 둘은 `skip` 이고 사유는 `the remote did not accept refs/harness/work-lock/ — work cannot take its start lock on this forge` 다
- `delete` 가 실패하면 `FAIL` 사유에 지우는 명령(`git push origin --delete <ref>`)을 함께 쓴다
- 머리글의 단계 표에서 `--write` 가 남기는 것은 댓글 3건 그대로다. 잠금 ref 는 지우고 끝나며, `delete` 가 실패한 경우에만 ref 하나가 남는다

## 8. 현재형 문서 갱신

| 문서 | 바꿀 것 |
|---|---|
| `src/templates/workflows/work/limits.md` | 상한 표의 보조 행: "`script/post-review.sh` — 회차마다 요약 댓글에 그 회차의 반복 키를 기록으로 남기고, 이전 요약들의 기록으로 연속 회차를 세어 상한에 닿으면 종료 코드 3". 신뢰 수준 문단: 반복 카운트는 요약 기록에서 다시 세므로 어느 클론에서 이어 돌려도 같다. 다만 댓글은 사람이 지우거나 고칠 수 있고 읽지 못한 기록은 연속을 끊는다 — 회차 상한보다 먼저 잡는 신호이지 종료 보장이 아니다. 되감기 문단에 "이 클론의 착수 잠금도 푼다" |
| `src/templates/workflows/work/` 머리·꼬리 조각 | 4-2 |
| `src/templates/managed/.claude/commands/work.md` | 4-3 |
| `src/templates/managed/docs/workflow/flow.md` | "루프가 멈추는 조건" 표의 반복 행 — 요약 기록으로 세고 어느 클론에서 이어 돌려도 같다. 새 절 "여러 클론이 같은 리포를 쓸 때" — 착수 잠금의 획득 · 해제 시점, 남은 잠금 찾기(`git ls-remote origin 'refs/harness/work-lock/*'`)와 누가 잡았는지 보기(`git fetch origin refs/harness/work-lock/<이슈> && git log -1 FETCH_HEAD`), 사람이 지우는 명령, 해제 단계를 거치지 않는 끝(드라이버가 스스로 낸 stop · 끊긴 실행 · `--discard`)이 잠금을 남긴다는 것과 푸는 명령(`script/work-lock.sh release <이슈>` — `--discard` 로 버릴 때 함께 돈다), `work` 를 직접 정의하면 잠금 단계와 해제 배선을 함께 둔다는 것 |
| `src/templates/managed/script/README.md` | `work-lock.sh` 행(shim — `harness work-lock`, 동작 셋과 종료 코드 0 · 1 · 2, 호출 시점: `work` 의 잠금 · 해제 단계와 사람의 해제), `post-review.sh` · `rollback-work.sh` 행, "규칙" 절에 "잠금 이름공간만 담은 push 는 pre-push 검증을 돌지 않는다" |
| 리뷰 · 등록 · 되감기 명령 모듈의 머리 설명 (#211 · #213 이 옮긴 자리) | 4-4 · 2절 · 6절. shim 머리글은 213 명세 4-1 의 형식 그대로다 |
| `src/templates/managed/.ai/templates/code-reviewer.md` | `path` 문자 제한의 근거 문장: "인라인 등록 목록의 탭 · 줄 · NUL 구분 형식과 요약 기록 줄에 들어가고" |
| `src/harness/format.py` · `src/templates/managed/script/harness-format.sh` | `FMT_REVIEW_RECORD` 와 그 주석. 두 쪽에 같은 이름과 값 (2-2) |
| `README.md` | 같은 리포를 여러 클론이 쓸 때 — 반복 지적은 리뷰 요청에서 이어 세고 같은 이슈는 한 클론만 착수한다는 한 문단 |
| `docs/spec/64-modularize-cli-review-scripts.md` | 1절의 누적 파일 항목, 3절의 마지막 항목, 5절 `judge` 행의 "반복 누적분" — 이 명세 2절을 가리키게 고친다 |
| `docs/spec/71-issue-worktree-run.md` | 1절의 이력 위치 항목, 7절, 9-2 — 이 명세 2절을 가리키게 고친다 |
| `docs/spec/README.md` | 이 명세의 행 |

## 9. 회귀 테스트

원격은 로컬 bare 리포다. forge 서버의 ref 갱신 동작은 bare 리포의 서버 훅(`pre-receive`)으로 흉내 낸다 — 이름공간 거부는 훅이 그 이름공간의 갱신을 거부하고,
조회와 push 사이의 경합은 훅이 받은 갱신을 처리하기 전에 같은 ref 를 다른 커밋으로 먼저 만든다. 잠금 커밋의 시각과 신원은 환경 변수로 고정한다.

### 9-1. 단위 테스트 — `src/test/unit/`

| 대상 | 케이스 |
|---|---|
| 기록 렌더 | 키가 처음 나온 순서이고 중복이 없다. blocker·major 가 없으면 빈 배열. `FMT_NO_LOCATION` 키. 한국어 경로가 `\u` 이스케이프로, `-->` 를 담은 경로가 `\u003e` 로 쓰인다. 기록 줄이 본문의 마지막 줄이고 앞 줄이 비어 있다 |
| 기록 읽기 | 렌더한 요약을 그대로 읽으면 같은 키 집합이다. CRLF 본문도 읽힌다. 알 수 없는 기록: 기록 줄 없음 · 둘 · 마지막 줄 아님 · ` -->` 없음 · JSON 아님 · 키가 더 있음 · 키가 모자람 · 같은 키 둘 · `format` 이 `2` · `format` 이 `true` · `keys` 가 문자열 · 원소가 숫자 · 원소에 제어 문자 · `/` 로 시작 · `..` 조각 |
| 재구성 | 같은 키 두 기록 뒤 이번 회차가 그 키면 3(상한 3). 빈 기록이 사이에 있으면 끊긴다. 알 수 없는 기록이 사이에 있으면 끊긴다. 다른 키는 따로 센다. 같은 시각이면 조회 순서를 따른다. 조회 실패는 알 수 없는 기록 하나와 같다. 상한 1 이면 이전 기록 없이도 상한이다 |
| 잠금 — 획득 | 빈 원격에서 0 · `acquired`, 원격 ref 가 생기고 소유 기록과 같다. 잠금 커밋은 부모가 없고 트리가 비어 있다. 같은 클론에서 다시 돌리면 0 · `already held by this clone` 이고 원격 값이 그대로다. 같은 클론의 linked worktree 에서도 0 |
| 잠금 — 다른 클론 | 같은 원격을 따로 clone 한 리포에서 1, 원격 값은 첫 클론의 것, 둘째 클론에 소유 기록이 없다. 표준 오류에 ref 이름과 `git push origin --delete` |
| 잠금 — 경합 | 조회 뒤 push 전에 같은 ref 가 생기면(서버 훅) 1, 원격 값은 먼저 만든 쪽, 소유 기록이 없다 |
| 잠금 — 같은 커밋 | 시각 · 신원을 고정하고 두 번 만든 잠금 커밋이 서로 다르다 |
| 잠금 — 판정 불가 | `origin` 이 없으면 2 이고 push 하지 않는다. 원격이 이름공간을 거부하면(서버 훅) 2 이고 소유 기록이 없다. push 는 받아졌는데 다시 읽기가 실패하면(PATH 앞의 git 래퍼가 두 번째 `ls-remote` 를 실패시킨다) 2 이고 소유 기록이 남으며, 다음 획득이 0 · `already held by this clone` |
| 잠금 — 해제 | 이 클론의 잠금이면 0 · `released`, 원격 ref 와 소유 기록이 없다. 소유 기록이 없으면 0 · `no lock held by this clone` 이고 원격을 부르지 않는다(`origin` 없는 리포에서도 0). 소유 기록이 원격 값과 다르면 0 이고 **원격 값이 그대로** 남는다. 원격이 삭제를 거부하면(서버 훅) 2 이고 원격 ref 와 소유 기록이 그대로다 |
| 잠금 — 상태 | `free` · `mine <객체 이름>` · `held <객체 이름>` 과 0. 상태를 본 뒤 원격과 기록이 그대로다. `origin` 이 없으면 2 |
| 잠금 — 인자 | `../x` · 공백이 든 값 · 빈 값 · `abc` 는 2 이고 git 을 부르지 않는다. `PROJ-12` 는 받는다. 모르는 동작과 남는 인자는 2 |
| 잠금 — 소유 기록 | 16진 40자 · 64자 한 줄이 아닌 내용은 기록이 없는 것으로 본다 |

### 9-2. `test-review-loop.sh`

forge 페이크의 요약 등록은 그 리뷰 요청의 스레드에 인라인이 아닌 노트로 쌓이고 다음 조회에 나온다. 노트 시각은 등록 순서로 늘어나는 고정값이고, 스레드 상태는
리뷰 요청 번호마다 따로다. 스레드 조회 실패를 주입할 수 있다.

기존 케이스의 종료 코드 기대값(같은 파일 반복 · 위치 없는 발견 · 줄 없는 경로)은 그대로다. 누적 파일을 읽던 검사 줄은 등록된 요약의 기록 줄을 읽는 검사로 바꾼다.
옛 형식 누적 파일 케이스와 worktree 이력 공유 케이스는 아래 케이스가 대신한다.

| 케이스 | 확인하는 것 |
|---|---|
| 클론이 바뀌어도 이어 센다 | 같은 리뷰 요청에 클론 A 에서 1 · 2회차, 따로 clone 한 클론 B(git 공통 디렉터리가 다르다)에서 3회차를 같은 파일 major 로 등록하면 종료 코드가 1 · 1 · 3 이다 |
| 로컬 이력 없음 | 등록 뒤 git 공통 디렉터리에 `work-loop` 가 없다 |
| 기록 줄 | 등록된 요약의 마지막 줄이 2-2 형식이고 `keys` 가 이번 회차의 키다. PASS 회차는 `"keys":[]` |
| 알 수 없는 기록이 끊는다 | 같은 파일 major 기록 둘 사이에 기록 줄 없는 요약이 있으면 셋째 회차가 1 이다. `format` 이 `2` 인 기록도 같다. 표준 오류에 `note:` 줄 |
| 기록으로 세지 않는 줄 | 요약 제목으로 시작하지 않는 노트의 기록 줄은 세지 않는다. 요약 본문 중간(마지막 줄이 아닌 곳)의 기록 줄은 알 수 없는 기록이다 |
| 조회 실패 | 같은 파일 major 두 회차 뒤 조회가 실패하면 셋째 회차가 1 이고 `warning:` 줄이 있으며, 요약이 등록되고 기록 줄을 담는다 |
| 리뷰 입력 | 직전 요약 인용에 기록 줄이 없고, 요약 절과 리뷰 시점 head 를 읽는 것은 그대로다 |

### 9-3. `render-test.sh`

| 블록 | 확인하는 것 |
|---|---|
| pre-push 예외 | 설치한 리포(`verify.pre_push` 켬, 실패하는 검증 단계, 미커밋 변경)에서 잠금 ref 생성 push 와 삭제 push 가 통과하고 검증 단계가 돌지 않는다. 잠금 ref 와 HEAD 가 아닌 브랜치를 함께 push 하면 지금처럼 막힌다. `harness/work-lock/7` 브랜치 push 는 예외가 아니다. 보호 브랜치 push 는 지금처럼 막힌다 |
| 기본 `work` 배선 | 내장 기본값 `work` 의 시작 단계가 `lock` 이고 `run` 이 3-3 의 획득이다. 끝 상태를 직접 가리키는 배선이 `lock` 의 실패 쪽과 해제 단계 셋뿐이고, 해제 단계 셋이 각자 같은 이름의 끝 상태로 간다 |
| 끝 상태마다 해제 | 테스트용 driver 절차(잠금 → 종료 코드를 고를 수 있는 스텁 단계 → 해제 셋)를 로컬 bare 원격으로 돌리면 `done` · `stop` · `handoff` 각각 끝난 뒤 원격 잠금이 없고 끝 상태가 스텁이 고른 것이다 |
| 획득 실패 | 다른 클론이 잡은 상태에서 같은 절차를 돌리면 스텁 단계가 불리지 않고 `stop` 이며 원격 잠금 값이 그대로다 |
| 해제를 거치지 않는 끝 | 같은 테스트용 절차에 해제 단계보다 먼저 닿는 `max_steps` 를 두고 돌리면 드라이버의 `stop` 으로 끝나고 원격 잠금이 남는다. 같은 클론에서 다시 돌리면 `lock` 이 0(`already held by this clone`)으로 지나간다. `script/work-lock.sh release <이슈>` 뒤 원격 잠금이 없다 |
| agent 모드 문서 | 옛 다섯 단계 `[workflows.work]` 로 렌더한 `.ai/workflows/work.md` 에서 `script/work-lock.sh acquire` 가 `script/work-preflight.sh` 보다 앞에, `script/work-lock.sh release` 가 출력 절 앞에 있다 |
| 진입점과 권한 | 설치된 `script/work-lock.sh` 로 획득 · 상태 · 해제가 3-3 대로 돈다(로컬 bare 원격). `.claude/settings.json` 허용 목록에 `Bash(script/work-lock.sh:*)` 가 있다. CLI 를 치운 샌드박스에서 `script/work-lock.sh status 1` 이 3-3 의 두 줄(`error: harness CLI not found under …` · `help: harness install --target …`)을 내고 2 다 |
| 자체 검사 | `--write` 를 받는 bare 원격에서 잠금 세 항목이 `ok` 다. 이름공간을 거부하는 원격(서버 훅)에서 `create` 가 `FAIL`, 나머지 둘이 `skip`, 종료 코드 1 이다. 두 경우 모두 끝난 뒤 원격의 잠금 이름공간에 ref 가 없다 |
| doctor | 잠금 단계가 없는 driver 기본값과 같은 `work` 절을 가진 설정에서 #212 의 `work` 절 점검이 그 절을 짚는다 |

터미널 출력의 한글 검사는 이 블록들의 출력에도 적용한다.

### 9-4. `test-rollback-work.sh`

| 케이스 | 확인하는 것 |
|---|---|
| 이 클론의 잠금 | 보이는 단계의 "will be closed or removed" 아래에 잠금 줄이 있고, `--yes` 뒤 원격 잠금이 없으며 종료 코드 0 |
| 다른 클론의 잠금 | 보이는 단계의 "left alone" 아래에 잠금 줄과 `git push origin --delete` 가 있고, `--yes` 뒤 **원격 잠금 값이 그대로**다 |
| 잠금만 남은 경우 | 다른 클론의 잠금 말고 되감을 것이 없으면 `nothing to roll back` 다음에 잠금 줄이 있고 종료 코드 0, 원격 잠금 값이 그대로다 |
| `--dry-run` | 이 클론의 잠금이 있어도 원격 잠금과 소유 기록이 그대로다 |
| 판정 불가 | 잠금 상태를 읽지 못해도 나머지 되감기는 돌고, `state unknown` 줄이 있으며 그 때문에 종료 코드가 바뀌지 않는다 |

회귀 테스트 전체(`script/run-lint-test.sh`)가 통과한다.

## 10. 보호 문서 개정 범위

분해의 task 하나가 이 범위 안에서 고친다. 같은 절을 앞 이슈들이 먼저 고친다 — 적용 순서는 #206 → #207 → #208 · #209 · #210 → #211 →
#212 → #213 → #215 다. 아래 문안은 #213 까지 반영된 문장 위에 더하거나, 그 문장 안의 어구를 내용으로 찾아 바꾼다.

### 10-1. `.ai/project/architecture.md`

| 절 | 문안 |
|---|---|
| "구성 요소" 의 CLI 패키지(`src/harness/`) 항목 | 하위 명령 나열에 착수 잠금(`work-lock` — 원격 잠금 ref 의 획득 · 해제 · 상태)을 더한다. 되감기(`rollback`)의 서술에 "이 클론의 착수 잠금을 푼다" 를 더한다 |
| "구성 요소" 의 대상 리포 `script/` 항목 | shim 나열에 착수 잠금(`work-lock.sh` → `harness work-lock`)을 더한다 |
| "구성 요소" 의 기기 단위 상태 다음 | "클론 단위 상태 — git 공통 디렉터리 아래 `harness/work-lock/<이슈>`: 이 클론이 잡은 착수 잠금의 커밋 이름. 같은 클론의 worktree 가 함께 쓴다" |
| "데이터 흐름" 의 절차 실행 | 기본 `work` 의 단계 나열(`harness run work <이슈>` 가 작업 트리 확인 → 착수 판정 → … 을 돈다) 맨 앞에 "착수 잠금(원격에 잠금 ref 를 만들어 잡는다 — 착수 판정보다 먼저)" 을 더하고, 그 문장 뒤에 "끝 상태로 가는 배선은 잠금 해제 단계를 거친다. 드라이버가 스스로 낸 stop 과 `--discard` 는 해제를 거치지 않아 잠금이 남는다" 를 더한다. `review-loop` 의 등록 단계 괄호(스키마 검증 · 등급 집계 · 반복 지적 누적 · 요약 · 인라인 댓글 렌더링)에서 "반복 지적 누적" 을 "이전 요약 기록으로 반복 지적 판정" 으로, "요약" 을 "요약(기록 줄 포함)" 으로 바꾼다 |
| "신뢰 경계" | "요약 댓글의 기록 줄(`harness:review-record`)은 forge 출력이라 신뢰하지 않는다 — 형식을 어기면 그 회차를 알 수 없는 기록으로 보고 연속을 끊는다. 위조된 기록이 할 수 있는 일은 거짓 종료 코드 3 과 반복 신호의 누락뿐이고, 회차 상한은 원격 라벨이 지킨다" 와 "착수 잠금 ref 는 push 권한자 누구나 만들고 지울 수 있다. 하네스는 원격 값이 이 클론이 만든 값일 때만 지우고, 다른 클론의 잠금은 사람이 지운다. pre-push 훅은 잠금 이름공간만 담은 push 에 검증을 돌지 않는다" 를 더한다 |
| "계층과 의존 방향" 의 기기 단위 상태 항목 | "기기 단위 상태(등록부·도구 기록·지표)는 홈 아래에 두고 리포에 두지 않는다 …" 항목 끝에 "클론에 묶인 상태(착수 잠금의 소유 기록)는 git 공통 디렉터리에 둔다 — 클론을 옮기면 따라가고 클론을 지우면 함께 사라진다" 를 더한다 |

### 10-2. `.ai/project/glossary.md`

| 위치 | 문안 |
|---|---|
| "용어" 표 | `착수 잠금` — 같은 이슈의 `work` 를 한 클론만 돌게 하는 원격 ref(`refs/harness/work-lock/<이슈>`). 원격에 그 ref 를 만든 클론이 잡은 것이고(`harness work-lock`), `work` 의 배선이 끝 상태로 갈 때 해제 단계가 푼다 |
| "용어" 표 | `요약 기록` — 리뷰 요약 댓글 마지막 줄의 기계 판독 기록(형식 판별자와 그 회차의 blocker·major 키). 다음 회차가 이것으로 반복 지적의 연속 회차를 다시 센다 |
| "용어" 표의 `표지` | 예시에 `harness:review-record` 를 더한다 |

### 10-3. `.ai/project/scope.md`

| 위치 | 문안 |
|---|---|
| "할 수 있는 일" 의 `run` 항목 | 끝에 "여러 클론이 같은 리포를 돌려도 같은 이슈는 한 클론만 착수하고, 반복 지적은 리뷰 요청의 요약 기록으로 이어 센다" 를 더한다 |

### 10-4. `.ai/project/testing.md`

| 위치 | 문안 |
|---|---|
| "외부 의존을 어떻게 다루나" 의 forge 항목 | 끝에 "forge 서버의 ref 갱신 동작(이름공간 거부 · 조회와 push 사이의 경합)은 bare 리포의 서버 훅으로 흉내 낸다" 를 더한다 |

## 11. 결정 기록

- 결정 기록: 반복 지적 이력을 리뷰 요청의 요약 기록에서 다시 센다(0004 Decision 의 로컬 누적 문장 대체) (분해에서 작성)
- 결정 기록: 같은 이슈의 착수를 원격 잠금 ref 의 생성 원자성으로 하나만 잡는다 (분해에서 작성)

## 12. 한계

- 잠금은 시간이 지나도 풀리지 않는다. 해제 단계를 거치지 않고 끝난 실행 — 드라이버가 스스로 낸 `stop`(상한 · 값이 없는 자리표시 · 배선이 없는 outcome),
  끊긴 실행, `--discard` 로 버린 실행 — 은 잠금을 남긴다. 하네스는 이것을 자동으로 풀지 않는다. 같은 클론은 다시 돌려 이어 가거나
  `script/work-lock.sh release <이슈>` 로 풀고, 다른 클론의 잠금은 사람이 지운다(3-3 의 `help`)
- 같은 클론 안에서 같은 이슈를 동시에 도는 것은 이 잠금이 막지 않는다 — 소유 단위가 클론이다. driver 실행은 #208 이 정한 실행 상태가 막고, agent 모드는 막지 않는다
- 잠금은 협조 규약이다. push 권한이 있으면 누구나 잠금 ref 를 만들고 지울 수 있고, 손으로 부른 리뷰 명령은 잠금을 잡지 않는다
- 고정 사본이 이 기능을 가진 버전인 커밋에서 도는 클론끼리만 배타가 성립한다. 옛 버전으로 도는 클론은 잠금을 모른다
- 프로젝트가 `work` 를 따로 정의하면 잠금은 그 정의의 배선에 달렸다. 하네스 밖의 pre-push 훅을 쓰면 그 훅이 잠금 push 를 막을 수 있고, 그때 획득은 2 로 끝난다
- `origin` 의 fetch 주소와 push 주소가 다른 서버를 가리키면 획득의 다시 읽기가 push 한 곳을 보지 못해 잠금이 성립하지 않는다
- 요약 댓글을 사람이 지우거나 고치면 연속 회차가 달라진다. 반복 카운트는 보조 신호이고 루프의 종료는 회차 라벨이 보장한다
- 이 형식 전에 등록된 요약은 알 수 없는 기록이라, 진행 중인 리뷰 요청의 연속은 그 뒤부터 센다
