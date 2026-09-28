# CLI 모듈화와 리뷰 판정 데이터

`src/bin/harness` 의 지표 코드와 중복 로직, 리뷰 루프 스크립트(`review-mr.sh` · `post-review.sh`)의
내장 파이썬, 테스트의 기록 경로를 정리한다. 리뷰어의 판정은 구조화된 데이터(JSON)로 받고, 등록 댓글은
하네스가 그 데이터로 렌더링한다.

정본 위치:

| 대상 | 정본 |
|---|---|
| CLI | `src/bin/harness` · `src/bin/harness_metrics.py` |
| 리뷰 루프 스크립트·공용 모듈·표지 | `src/templates/managed/script/` 의 `review-mr.sh` · `post-review.sh` · `_review.py` · `harness-format.sh` |
| 리뷰 역할 계약 | `src/templates/managed/.ai/templates/code-reviewer.md` · `security-guard.md` · `developer.md` |
| 절차 조각 | `src/templates/workflows/work/review.md` · `branch.md` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/templates/managed/script/test-review-loop.sh` |

이 리포의 `script/` · `.ai/templates/` · `.ai/workflows/` 아래 같은 이름의 파일은 거기서 설치·생성된 사본이다.

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

**바뀌는 것은 리뷰어 출력 계약과 등록 댓글의 본문 하나다** (2~5절). 모든 설치본의 리뷰 역할 계약·표지·
절차 문서가 함께 바뀐다.

그 밖은 수행 결과가 같다.

- CLI 의 모든 명령은 같은 입력에 같은 출력·종료 코드·파일을 낸다 (6·7절)
- `review-mr.sh` · `post-review.sh` 의 명령줄 인자와 종료 코드(0 PASS · 1 CHANGES_REQUESTED · 2 실패·계약 위반 ·
  3 상한)는 그대로다
- 회차 라벨, 회차 상한, 반복 지적 누적 파일(`<git-dir>/work-loop/review-findings-<번호>.tsv`, 첫 줄 `#format 1`)의
  형식과 연속 회차 판정은 그대로다
- 리뷰 입력(`review-mr.sh` 가 리뷰어에게 넘기는 본문)의 절 구성과 내용은 그대로다
- 제품의 기록 경로 해석(`script/metric.py` · `script/usage-log.sh`)은 그대로다 (8절은 테스트만 바꾼다)

## 2. 리뷰어 출력 계약 — 판정 데이터

리뷰어(`code-reviewer`)와 보안 검토자(`security-guard`)는 **판정 데이터 블록 하나**를 낸다.

### 2-1. 블록

- 판정 데이터는 info string 이 정확히 `json` 인 fenced 코드 블록(```` ```json ```` 로 여는 줄부터 ```` ``` ```` 로 닫는 줄까지)
  **하나**에 담는다. info string 은 표지 `FMT_REVIEW_BLOCK` 이다
- 여는 줄과 닫는 줄은 행 첫 칸에서 시작한다
- 블록 밖의 텍스트는 읽지 않고 등록하지도 않는다. 판정에 닿지 않는다
- 블록이 없거나 둘 이상이면 계약 위반이다

JSON 문자열 안의 줄바꿈은 `\n` 으로 이스케이프되므로 블록 내용에 닫는 줄이 나타날 수 없다. 블록 경계는
내용과 무관하게 정해진다.

### 2-2. 스키마

```json
{
  "summary": "전반 상태와 판정 의견, 3문장 이내",
  "findings": [
    {
      "severity": "major",
      "path": "script/review-mr.sh",
      "line": 42,
      "title": "요지 한 줄",
      "problem": "무엇이 문제인가",
      "repro": "입력 → 결과",
      "recommendation": "무엇을 하라",
      "out_of_scope": false,
      "decision_basis": null
    }
  ],
  "strengths": ["잘된 점"],
  "verdict": "CHANGES_REQUESTED"
}
```

최상위 객체:

| 키 | 형 | 규칙 |
|---|---|---|
| `summary` | 문자열 | 공백만이 아닌 문자열 |
| `findings` | 배열 | 발견 객체의 배열. **빈 배열이 "발견 없음"이다** |
| `strengths` | 배열 | 문자열 배열. 빈 배열을 허용한다. 원소 값은 검증하지 않는다 — 공백만인 문자열도 받는다 |
| `verdict` | 문자열 | `PASS` 또는 `CHANGES_REQUESTED` (표지 `FMT_VERDICT_PASS` · `FMT_VERDICT_CHANGES`) |

발견 객체:

| 키 | 형 | 규칙 |
|---|---|---|
| `severity` | 문자열 | `blocker` · `major` · `minor` 중 하나 |
| `path` | 문자열 또는 `null` | 리포 기준 상대 경로. `/` 로 시작하지 않고, `..` 경로 조각이 없고, Unicode 일반 범주 Cc(제어)·Zl(줄 구분)·Zp(문단 구분)·Cf(서식) 문자가 없다. 파일을 지목할 수 없으면 `null` |
| `line` | 정수 또는 `null` | 1 이상. `path` 가 `null` 이면 `null` 이어야 한다. 불리언은 정수로 받지 않는다 |
| `title` | 문자열 | 공백만이 아니고, Python `str.splitlines()` 가 줄 경계로 보는 문자 10종(LF·CR·VT·FF·FS·GS·RS·NEL·U+2028·U+2029)이 없다. 그 밖의 제어 문자(탭·BEL 등)는 허용한다 |
| `problem` | 문자열 | 공백만이 아닌 문자열 |
| `repro` | 문자열 | 공백만이 아닌 문자열. 구체적인 입력과 결과 |
| `recommendation` | 문자열 | 공백만이 아닌 문자열 |
| `out_of_scope` | 불리언 | 이번 변경이 의존·호출하는 코드의 결함이라 이월이 필요하면 `true` |
| `decision_basis` | 문자열 또는 `null` | 이미 결정된 사안의 재검토 요청이면 그 결정을 정한 근거(문서 경로 또는 이슈·MR 본문의 절). 그 밖에는 `null` |

- **키는 전부 필수다.** 값이 없는 자리는 `null` 로 적는다
- 정의되지 않은 키가 있으면 계약 위반이다
- 한 객체 안에 같은 키가 둘이면 계약 위반이다
- `decision_basis` 가 `null` 이 아니면 `severity` 는 `minor` 여야 한다. 결정 재검토 요청은 판정에 닿지 않는다

`path` 의 문자 제한은 `path` 가 인라인 등록 목록과 반복 지적 누적 파일의 탭·줄·NUL 구분 형식에 들어가고,
서식 문자가 댓글에 보이는 경로를 바꿀 수 있어서 둔다.

**검증은 위 두 표(최상위 객체·발견 객체)의 형·규칙 열과 바로 위 목록의 규칙만 한다. 적히지 않은 제약을 더하지 않는다.**

아래는 리뷰어에게 주는 작성 지침이다. 검증하지 않으며, 어겨도 계약 위반이 아니다.

- `summary` 는 전반 상태와 판정 의견을 3문장 이내로 쓴다
- 확신이 없는 발견은 `severity` 를 `minor` 로 두고 `problem` 에 "확인 필요" 를 적는다
- 발견은 심각도 순(blocker → major → minor)으로 나열한다. 렌더링이 심각도 순으로 다시 정렬한다
- 보안 검토자는 아래 대응표대로 필드를 채운다

보안 검토자는 같은 스키마를 쓴다. 필드의 뜻은 이렇게 옮긴다.

| 필드 | 보안 검토자가 적는 것 |
|---|---|
| `problem` | 무엇이 취약한가 |
| `repro` | 악용 경로 — 무엇을 입력하면 무엇이 일어나는가 |
| `recommendation` | 조치 |
| `summary` | 무엇을 보았고 어느 경로를 따라갔는지, 그리고 이번 변경과 무관해 보지 않은 것 |
| `strengths` | 빈 배열 |

자격증명을 발견했을 때 값을 어느 필드에도 옮겨 적지 않는 규칙은 그대로다.

### 2-3. 계약 위반

아래 중 하나면 계약 위반이다. `post-review.sh` 는 **아무것도 등록하지 않고** 종료 코드 2 로 끝난다.

- 블록이 없거나 둘 이상이다
- 블록 내용이 UTF-8 JSON 으로 파싱되지 않는다
- 2-2 의 스키마를 하나라도 어긴다

표준 오류에는 첫 줄에 `contract violation: <무엇을 어겼는지>` 를 쓰고, 이어서
`help: nothing was posted — the raw review follows` 와 리뷰어 출력 원문을 쓴다. 스키마 위반은 어긴 위치를
`findings[<번호>].<키>` 처럼 지목한다.

벤더 CLI 의 출력 스키마 강제 옵션에 기대지 않는다. 계약은 역할 계약 문서의 지시와 이 검증으로 성립한다.

## 3. 판정과 집계

`post-review.sh` 는 검증을 통과한 판정 데이터를 **데이터로** 집계한다. 마크다운 제목·행 문법을 읽지 않는다.

- **판정은 등급 집계다.** `findings` 의 `blocker` + `major` 가 1건 이상이면 `CHANGES_REQUESTED`, 0건이면 `PASS`.
  `minor` 는 세지 않는다
- `verdict` 는 계약 준수 확인용이다. 집계와 다르면 집계를 따르고 그 사실을 요약 댓글에 남긴다 (4-1)
- 인라인 대상: 심각도가 표지 `FMT_INLINE_SEVERITIES`(blocker · major)에 들고 `path` 와 `line` 이 모두 있는 발견
- 반복 키: 심각도가 `FMT_INLINE_SEVERITIES` 에 드는 발견의 `path`. `path` 가 `null` 이면 표지 `FMT_NO_LOCATION`.
  `line` 은 키에 넣지 않는다. 한 회차의 같은 키는 한 번만 센다. blocker·major 가 없는 회차는 자리표시자 `-` 를 남긴다
- 연속 회차가 `REVIEW_REPEAT_FILE_MAX` 에 닿으면 종료 코드 3 이다. 누적은 요약 등록에 성공한 뒤에만 한다

## 4. 등록 댓글 렌더링

요약 댓글과 인라인 댓글은 판정 데이터에서 하네스가 만든다. 리뷰어 출력 원문은 등록하지 않는다.

### 4-1. 요약 댓글

```
## 자동 리뷰 결과 (<작성자표시>)

> `script/post-review.sh` 가 등록했다. 판정은 참고용이며 머지 승인은 사람이 한다.
>
> 발견 blocker <n> · major <n> · minor <n> → **판정 <PASS|CHANGES_REQUESTED>**
> (minor 는 판정에 넣지 않는다.)
>
> 리뷰 시점 head `<SHA>`
>
> 리뷰어가 선언한 판정은 `<verdict>` 였다. 판정은 발견 등급 집계를 따른다.
>
> **한 파일에 blocker·major 가 <N>회차 연속 나왔다. 루프를 여기서 멈춘다** — 코드가 아니라 명세를 다시 본다.
> - <N>회차 연속: `<키>`
>
> 인라인 <n> 건은 해당 줄이 이번 diff 에 없어 달지 못했다. 아래 본문을 참조한다.

### 요약

<summary>

### 발견 사항

- **[<severity>]** `<path>:<line>` — <title>
  - 문제: <problem>
  - 재현: <repro>
  - 권고: <recommendation>
  - 범위 밖 — 이월 필요
  - 결정 재검토 근거: <decision_basis>

### 잘된 점

- <strengths 항목>
```

- 인용 머리의 줄 구성과 조건은 1절대로 그대로다. 리뷰 시점 head 줄은 리비전이 있을 때, 선언 줄은 `verdict` 가
  집계와 다를 때, 반복 줄은 연속 상한에 닿았을 때, 인라인 실패 줄은 실패가 있을 때만 쓴다
- 첫 줄은 표지 `FMT_SUMMARY_HEADING`, 리비전 줄의 머리는 표지 `FMT_REVIEWED_HEAD` 다. 다음 회차의 `review-mr.sh` 가
  이 둘로 직전 요약과 증분 기준을 찾는다
- 발견은 심각도 순(blocker → major → minor)으로, 같은 심각도 안에서는 입력 순서로 쓴다
- 위치 표기: `path` 와 `line` 이 있으면 `` `<path>:<line>` ``, `path` 만 있으면 `` `<path>` ``, `path` 가 `null` 이면
  표지 `FMT_NO_LOCATION`
- `범위 밖 — 이월 필요`(표지 `FMT_OUT_OF_SCOPE`) 줄은 `out_of_scope` 가 `true` 일 때만, 결정 재검토 근거 줄은
  `decision_basis` 가 있을 때만 쓴다
- `findings` 가 비면 `### 발견 사항` 아래에 표지 `FMT_NO_FINDINGS`(`발견 사항 없음`) 한 줄을 쓴다
- `strengths` 의 원소 중 공백만인 것은 쓰지 않는다. 남는 원소가 없으면(`strengths` 가 빈 배열인 경우 포함) `### 잘된 점` 절을 쓰지 않는다
- 여러 줄 값은 둘째 줄부터 그 항목의 들여쓰기를 맞춰 이어 쓴다. 값 안의 제목 문법(`#`)이 댓글의 절 제목으로
  읽히지 않도록 들여쓰기 안에 둔다

### 4-2. 인라인 댓글

```
**[<severity>]** <title>

문제: <problem>
재현: <repro>
권고: <recommendation>
범위 밖 — 이월 필요
```

- 첫 줄의 `**[<severity>]**` 접두가 인라인 발견의 표식이다. 다음 회차의 `review-mr.sh` 가 이 접두(blocker · major)로
  직전 회차의 발견 스레드를 가려 답글과 함께 리뷰 입력에 넣는다. 접두를 만드는 코드와 알아보는 코드는
  공용 모듈 한 곳에 있다 (5절)
- 마지막 줄은 `out_of_scope` 가 `true` 일 때만 쓴다
- 인라인 등록이 실패한 발견은 요약 댓글에 그대로 있다. 줄 번호를 추측해 재시도하지 않는다

## 5. 공용 모듈 `script/_review.py`

`review-mr.sh` 와 `post-review.sh` 의 파이썬은 전부 `script/_review.py`(정본
`src/templates/managed/script/_review.py`) 하나에 둔다. **두 스크립트 본문에는 `python3 -c` 와 파이썬 heredoc 이 없다.**

- 표준 라이브러리만 쓴다
- 스크립트로 실행한다: `python3 script/_review.py <하위명령> <인자…>`. import 하지 않으므로 `script/` 에 `__pycache__` 가 생기지 않는다
- 표지는 하드코딩하지 않는다. 부르는 스크립트가 `script/harness-format.sh` 를 자동 export(`set -a`)로 source 하고,
  모듈은 환경 변수의 `FMT_*` 값을 쓴다. 필요한 표지가 환경에 없으면 종료 코드 2 로 끝난다
- 판정 데이터 스키마(키 이름·허용 값)는 모듈 안 한 곳에 정의하고, 검증·집계·렌더링이 그것을 함께 쓴다

하위명령:

| 하위명령 | 부르는 곳 | 하는 일 |
|---|---|---|
| `plan-exe` | `review-mr.sh` | `script/harness.plan.json` 에서 `code-reviewer` 의 실행 파일 이름을 낸다. 파일이 없거나 깨졌으면 비0 |
| `mr-field` | `review-mr.sh` | 정규화된 리뷰 요청 JSON 에서 필드 하나(`source_branch` · `head_sha`)를 낸다 |
| `round` | `review-mr.sh` | 라벨 목록에서 회차 라벨 `<prefix>:<N>` 의 최댓값과 해당 라벨 목록을 낸다(두 줄). 없으면 `0` |
| `issue-ref` | `review-mr.sh` | 리뷰 요청 본문의 종료 참조(표지 `FMT_MR_CLOSES`)에서 이슈 번호를 낸다. 없으면 빈 줄 |
| `context` | `review-mr.sh` | 리뷰 요청 본문의 목적·리뷰 요청 포인트 절, 이슈 본문과 명세 경로, 직전 회차 요약과 발견 스레드의 답글로 리뷰 입력의 맥락 절을 만들고, 직전 요약의 리뷰 시점 head 를 따로 낸다 |
| `judge` | `post-review.sh` | 판정 데이터를 검증하고 등급 건수·선언 값·인라인 대상·반복 누적분·연속 상한 도달 키를 작업 디렉터리에 쓴다. 계약 위반이면 2 |
| `render` | `post-review.sh` | 인라인 등록 결과를 받아 4-1 의 요약 댓글 본문을 만든다 |

- 각 하위명령의 출력 형식(작업 디렉터리의 파일 이름, NUL·탭 구분)은 모듈과 두 스크립트 사이의 내부 형식이다.
  `post-review.sh` 의 인라인 대상 목록은 지금처럼 `<path>\t<line>\t<note>\0` 로 읽는다
- `context` 의 절 추출(`md_section`)은 리뷰 요청 본문이라는 사람의 글에서 맥락을 뽑는 일이고 판정이 아니다.
  제목이 일치하는 절을 같은 수준 이상의 다음 제목까지 읽고, 두 절을 모두 찾지 못하면 본문 전체를 넘기는 동작은 그대로다.
  인용 접두(`> `)도 그대로다
- 맥락 조회·구성 실패가 리뷰를 막지 않는 동작(경고 후 diff 만 넘김)은 그대로다
- `script/README.md` 표에 `_review.py` 행을 더한다 — 리뷰 루프의 파이썬 전부(판정 데이터 검증·집계·등록 댓글 렌더링·리뷰 입력 맥락). 부르는 곳은 `review-mr.sh` · `post-review.sh`

## 6. 표지 — `script/harness-format.sh`

| 표지 | 값 | 누가 쓰고 누가 읽는가 |
|---|---|---|
| `FMT_REVIEW_BLOCK` | `json` | 리뷰어가 쓰고 `_review.py` 가 읽는다 — 판정 데이터 블록의 info string |
| `FMT_VERDICT_PASS` | `PASS` | 리뷰어가 `verdict` 에 쓰고 `_review.py` 가 읽는다 |
| `FMT_VERDICT_CHANGES` | `CHANGES_REQUESTED` | 위와 같다 |
| `FMT_INLINE_SEVERITIES` | `blocker major` | 판정·인라인·반복 키의 심각도 (값 그대로) |
| `FMT_NO_LOCATION` | `(파일 미지정)` | 반복 키와 요약 댓글의 위치 표기 (값 그대로) |
| `FMT_NO_FINDINGS` | `발견 사항 없음` | `_review.py` 가 요약 댓글에 쓴다 |
| `FMT_OUT_OF_SCOPE` | `범위 밖 — 이월 필요` | `_review.py` 가 댓글에 쓰고 구현자가 읽는다 |
| `FMT_SUMMARY_HEADING` · `FMT_REVIEWED_HEAD` | 값 그대로 | `_review.py` 가 쓰고 다음 회차에 읽는다 |

- `FMT_FINDINGS_HEADING` 과 `FMT_FINDINGS_LEVEL` 은 없다. 발견 절 제목을 읽는 코드가 없다
- 리뷰 본문 절의 머리 주석은 "리뷰어가 쓰고 `_review.py` 가 읽는다" 와 "`_review.py` 가 등록 댓글에 쓰고
  다음 회차와 구현자가 읽는다" 로 가른다
- MR 본문·이슈 본문·시크릿·분해 머리글 표지는 그대로다

## 7. 계약·절차 문서

| 문서 | 바뀌는 것 |
|---|---|
| `.ai/templates/code-reviewer.md` "출력 계약" | 2절의 블록·스키마·위반 조건. `## 요약` · `## 발견 사항` · `## 잘된 점` 절 제목 규칙, 등급 형식 줄, 마지막 줄 선언 규칙, "발견은 `## 발견 사항` 절 안에만 둔다" 절이 판정 데이터 규칙으로 바뀐다. "판정의 정본은 등급 집계다" 절은 `verdict` 필드 기준으로 같은 뜻을 유지한다 |
| 같은 문서 "반증 절차" 4 | 결정 재검토 형식이 `severity: minor` + `decision_basis` + `problem`(성립하지 않는 조건)으로 바뀐다 |
| 같은 문서 "반증 절차" 5 | "범위 밖 — 이월 필요" 표기가 `out_of_scope: true` 로 바뀐다 |
| `.ai/templates/security-guard.md` "출력 계약" · "출력" | 2-2 의 같은 스키마와 필드 대응표. 출력 예시가 판정 데이터 블록으로 바뀐다 |
| `.ai/templates/developer.md` "고치지 않고 넘기는 지적" | 리뷰어의 범위 밖 표기가 `out_of_scope: true` 이고 등록 댓글에는 `범위 밖 — 이월 필요` 로 보인다는 것 |
| 절차 조각 `workflows/work/review.md` | 종료 코드 2 의 계약 위반 목록이 2-3 으로 바뀐다. "집계는 `## 발견 사항` 절 안만 센다" 항목이 "판정 데이터의 `findings` 를 센다, 블록 밖 텍스트는 읽지 않는다" 로 바뀐다 |
| 절차 조각 `workflows/work/branch.md` | 마무리 단계의 조건 "그 회차 리뷰 본문의 `## 발견 사항` 절에" 가 "그 회차 판정 데이터의 `findings` 에" 로 바뀐다 |

- 절차의 "리뷰 본문" 은 `review-mr.sh` 가 표준 출력으로 내는 리뷰어 출력(판정 데이터 블록을 담은 것)이다. 재시도·마무리 모드의 구현자에게 이것을 넘긴다
- `src/templates/agents/code-reviewer.md` · `security-guard.md` 의 등록 명령(`script/post-review.sh <번호> <본문파일> <표시>`)은 그대로다

## 8. CLI — 지표 모듈

지표 집계와 세션 가져오기를 `src/bin/harness_metrics.py` 로 옮긴다.

| 모듈로 가는 것 | `src/bin/harness` 에 남는 것 |
|---|---|
| `read_spans` · `parse_iso` · `pct` · `metrics_report` · `UNATTRIBUTED` · `claude_usage` · `codex_usage` · `new_lines` · `seen` · `import_claude` · `import_codex` · `metrics_import` · `load_metric` | `METRICS_DEFAULTS` · `metrics_cfg`(설정 해석), `cmd_metrics`(명령 표의 명령), `cmd_run`(모듈의 `load_metric` 을 부른다) |

- 모듈은 표준 라이브러리만 쓰고 `src/bin/harness` 를 import 하지 않는다. 등록부 경로 같은 CLI 의 값은 인자로 받는다
- CLI 는 자기 파일의 디렉터리(`Path(__file__).resolve().parent`)에서 모듈을 찾는다. 설치본은 `.harness/bin/`, 소스 리포는 `src/bin/`,
  Homebrew 설치는 `libexec` 아래 같은 디렉터리다
- **CLI 는 모듈을 import 하기 전에 바이트코드 쓰기를 끈다**(`sys.dont_write_bytecode`). `.harness/bin/` 과 `src/bin/` 에 `__pycache__` 가 생기지 않는다
- `cmd_install` 은 `.harness/bin/` 에 `harness` 와 함께 `harness_metrics.py` 를 복사한다
- 나머지 CLI 는 한 파일에 둔다. 긴 함수(`cmd_doctor` · `validate` · `metrics_report` · `derive`)는 나누지 않는다

## 9. CLI — 중복 정리

### 9-1. `drift()`

생성물 일치 판정은 `drift(cfg, target, staged=False)` 하나가 한다. 반환값은 `(경로, 사유)` 목록이다.

| 사유 | 조건 |
|---|---|
| `left over; the config no longer generates it` | 지난 매니페스트에 있고 이번 `plan()` 에 없으며 작업 트리에 파일이 있다 |
| `missing` | `plan()` 에 있고 비교 대상(작업 트리, `staged` 면 인덱스)에 없다 |
| `differs from the config` | 비교 대상의 내용이 생성 내용과 다르다 |

- `cmd_check` 는 목록을 지금과 같은 형식으로 출력한다. `--staged` 는 `drift(..., staged=True)` 다
- `cmd_doctor` 는 `drift(cfg, target)` 의 건수만 쓴다 (`<n> files differ from the config` / `<n> files match the config`)

### 9-2. `role_meta()`

역할 어댑터 본문(`src/templates/agents/<역할>.md`)의 frontmatter 는 `role_meta(name)` 하나가 읽는다.

- 파일이 없으면 `{}` 를 돌려준다
- 파일이 있으면 frontmatter 의 원래 키(`description` · `summary` · `about` 등)와 해석한 값(`headless` · `entry` · `distinct_from`), 본문(`body`)을 담은 dict 를 돌려준다
- `agent_table` · `agent_files` · `cmd_schema` 는 `role_meta` 를 쓴다. 파일이 없을 때(`no adapter body for role`)와 키가 없을 때(`frontmatter has no summary` / `description`) `die` 하는 동작과 메시지는 호출부에 남는다
- 커맨드 파일(`.claude/commands/`)의 frontmatter 를 읽는 `command_rows` 는 대상이 아니다

### 9-3. `cmd_schema` docstring

`cmd_schema` 의 docstring 을 함수 첫 문장으로 옮긴다. `tools = recorded_tools()` 는 그 뒤에 온다. 출력은 같다.

## 10. 테스트의 기록 경로 격리

회귀 테스트가 만든 임시 리포는 기록(`[metrics].dir` · `[usage].log_path`)을 실제 홈 아래에 남기지 않는다.

- `render-test.sh` 에서 `install` 로 만든 임시 리포(`$work/installed` · `$work/secret`)는 설치 직후
  `harness set --target <리포> metrics.dir <$work 아래 경로> usage.log_path <$work 아래 경로>` 로 두 값을 테스트 작업 디렉터리 아래로 옮긴다
- `test-*.sh` 가 관리 스크립트를 임시 배치에서 돌릴 때 기록을 남기는 스크립트(`usage-log.sh` · `metric.py` 를 부르는 것)를
  함께 배치하면, 배치한 `harness.env` 의 `USAGE_LOG_PATH` 와 `harness.plan.json` 의 `metrics.dir` 을 샌드박스 경로 또는 `off` 로 덮는다.
  `test-review-loop.sh` 의 배치가 그 형식이다
- `render-test.sh` 의 `setup()` 은 ADR 디렉터리 값을 `[adr]` 절의 `dir` 에만 적용한다. 설정 파일에서 처음 나오는
  `dir =` 줄이 아니라 `[adr]` 절 안의 `dir =` 줄을 바꾼다 — 기본 설정에서 처음 나오는 `dir =` 은 `[metrics]` 절의 것이다.
  `[metrics].dir` 은 ADR 디렉터리 값을 받지 않는다
- `setup()` 이 만든 대상의 `[metrics].dir` 과 `[usage].log_path` 는 그 대상의 테스트 작업 디렉터리 아래 경로로 둔다.
  `metrics.dir` 을 직접 정하는 케이스는 지금처럼 `harness set` 으로 덮는다
- 제품의 경로 해석은 바꾸지 않는다. 테스트는 `HOME` 을 바꾸지 않는다
- 이미 실제 홈에 생긴 기록은 테스트와 스크립트가 지우지 않는다

## 11. 보호 문서에 반영할 것

### 11-1. `.ai/project/architecture.md`

| 위치 | 반영할 사실 |
|---|---|
| "구성 요소" 의 `src/bin/harness` 항목 | CLI 본체이고 명령 전부가 여기 있다. 지표 집계와 세션 가져오기는 옆의 `src/bin/harness_metrics.py` 모듈이 갖는다. 둘 다 표준 라이브러리만 쓴다 |
| "구성 요소" 의 대상 리포 `script/` 항목 | 리뷰 루프의 공용 모듈 `_review.py`(판정 데이터 검증·집계·등록 댓글 렌더링·리뷰 입력 맥락) |
| "데이터 흐름" 의 리뷰 루프 | 리뷰어 → 판정 데이터(JSON 블록) → `post-review.sh`(스키마 검증 · 등급 집계 · 반복 지적 누적 · 요약·인라인 댓글 렌더링) → 종료 코드 |
| "신뢰 경계" 의 들어오는 입력 | 리뷰어의 판정 데이터는 스키마로 엄격히 검증하고, 어기면 등록하지 않는다 |
| "새 코드를 둘 곳" | 지표 집계·세션 가져오기 코드는 `src/bin/harness_metrics.py`. 리뷰 루프의 파이썬은 `script/_review.py`(정본 `src/templates/managed/script/_review.py`) — 두 스크립트 본문에 파이썬을 넣지 않는다 |
| "검사하지 않는 것" 의 한 파일 항목 | `src/bin/harness` 는 지표 모듈을 뺀 나머지 명령을 한 파일에 담는다(2천 줄 이상). 그 나머지는 모듈로 나누지 않았다 |

### 11-2. `.ai/project/glossary.md`

| 위치 | 반영할 사실 |
|---|---|
| "용어" 표의 `표지` 행 | 예시에서 `REVIEW_VERDICT` 를 빼고 판정 데이터 블록의 info string(`FMT_REVIEW_BLOCK`)과 `harness:allow-secret` 등을 든다. 뜻("기계가 읽는 문자열 (`script/harness-format.sh`)")은 그대로다 |

### 11-3. 결정 기록

리뷰 판정을 구조화된 데이터로 받는 결정은 새 결정 기록 "Review verdicts are structured data" 가 갖는다.
그 기록은 `docs/adr/0004-review-rounds-are-counted-by-one-script.md` Consequences 의 "리뷰 본문의 `REVIEW_VERDICT` 는
계약 준수 확인용이다" 부분만 대체한다. 0004 의 상태와 본문은 그대로다.

## 12. 회귀 테스트

### 12-1. `test-review-loop.sh`

리뷰 본문 표본은 판정 데이터 블록으로 쓴다. 샌드박스 배치에 `_review.py` 를 함께 복사한다.
종료 코드·회차·반복 누적·증분·리뷰 입력을 보는 기존 케이스는 같은 기대값으로 유지한다.

| 케이스 | 확인하는 것 |
|---|---|
| 발견 없음 | `findings: []` 이면 종료 코드 0, 요약 댓글에 `발견 사항 없음` |
| minor 만 | 종료 코드 0, `verdict` 가 `CHANGES_REQUESTED` 면 선언 줄이 남는다 |
| 같은 파일 반복 | 문장이 달라도 같은 `path` 의 major 가 상한 회차 연속이면 종료 코드 3, 요약에 경로와 회차 |
| 위치 없음 | `path: null` 인 major 는 `FMT_NO_LOCATION` 키로 누적되고 인라인에서 빠진다 |
| 줄 없음 | `path` 만 있고 `line: null` 인 major 는 그 `path` 로 누적되고 인라인에서 빠진다 |
| 블록 밖 텍스트 | 블록 밖에 `- [major] …` · `## 발견 사항` 이 있어도 집계가 바뀌지 않고 댓글에 옮겨지지 않는다 |
| 블록 없음 · 블록 둘 · JSON 파싱 실패 | 종료 코드 2, 등록 호출 0 |
| 스키마 위반 | 필수 키 누락 · 정의되지 않은 키 · 중복 키 · 허용 밖 `severity`/`verdict` · 정수가 아닌 `line` · `path` 없이 `line` · 절대 경로·`..` 가 든 `path` · Cc·Zl·Zp·Cf 문자가 든 `path` · 빈 `title` · `str.splitlines()` 줄 경계 10종 문자 중 하나가 든 `title` · minor 가 아닌 결정 재검토 — 각각 종료 코드 2, 등록 호출 0, 표준 오류에 어긴 위치 |
| 스키마 허용 | 탭·BEL 이 든 `title`, 공백만인 원소가 든 `strengths` — 계약 위반이 아니고 등록된다 |
| 요약 댓글 렌더링 | 발견의 `title` · `problem` · `repro` · `recommendation` 이 심각도 순으로 들고, `out_of_scope: true` 에 `범위 밖 — 이월 필요`, `decision_basis` 에 근거 줄, `strengths` 가 비면 잘된 점 절이 없다. 공백만인 `strengths` 원소는 빠지고, 남는 원소가 없으면 `### 잘된 점` 절이 없다 |
| 인라인 댓글 렌더링 | blocker·major 의 인라인 본문이 `**[<severity>]** <title>` 로 시작한다 |
| 직전 회차 인식 | 이번 회차 `render` 로 만든 요약과 인라인 본문을 다음 회차의 스레드로 주면, 리뷰 입력에 직전 요약과 발견·답글이 들고 증분 기준 리비전을 읽는다 |
| 맥락 절 추출 | 리뷰 요청 본문의 목적·리뷰 요청 포인트만 넘기고, 두 절이 없으면 본문 전체를 넘긴다 |
| 계약·모듈 일치 | 모듈이 정의한 키 이름과 허용 값, 표지 `FMT_REVIEW_BLOCK` 이 `code-reviewer.md` 와 `security-guard.md` 에 모두 있다 |
| 내장 파이썬 없음 | `review-mr.sh` · `post-review.sh` 본문에 `python3 -c` 와 파이썬 heredoc 이 없다 |

### 12-2. `render-test.sh`

| 케이스 | 확인하는 것 |
|---|---|
| 설치본의 지표 모듈 | `install` 한 리포의 `.harness/bin/harness_metrics.py` 가 있고, 그 리포에서 `harness metrics` 가 종료 코드 0 이며 `.harness/bin/__pycache__` 가 생기지 않는다 |
| 소스 리포의 지표 모듈 | 소스 리포 흉내(`$work/source`)에 `src/bin/` 의 두 파일을 복사해 돌리고, `harness metrics` 뒤 `src/bin/__pycache__` 가 생기지 않는다 |
| check 와 doctor 의 일치 | 생성물 하나를 고치고 하나를 지운 리포에서 `check` 가 두 경로를 사유와 함께 내고, `doctor` 가 같은 건수(`2 files differ`)를 낸다 |
| 설치 리포의 기록 경로 | `$work/installed` · `$work/secret` 의 `script/harness.env` 의 `USAGE_LOG_PATH` 와 `script/harness.plan.json` 의 `metrics.dir` 이 `$work` 아래를 가리킨다. 설치본의 검증 일괄(`script/run-lint-test.sh`)을 돈 뒤 지표가 그 경로에 남는다 |
| `setup()` 의 ADR 디렉터리 | `setup()` 으로 만든 대상의 `harness.toml` 에서 `[adr].dir` 이 `docs/adr` 이고 `[metrics].dir` 은 `docs/adr` 가 아니다. 그 대상의 `script/harness.plan.json` 의 `metrics.dir` 과 `script/harness.env` 의 `USAGE_LOG_PATH` 가 테스트 작업 디렉터리 아래를 가리킨다 |
| 역할 frontmatter | 어댑터 본문이 없는 역할과 `summary`/`description` 이 없는 본문에서 render 가 지금과 같은 메시지로 멈춘다 |

회귀 테스트 전체(`script/run-lint-test.sh`)가 통과한다.
