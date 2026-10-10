# 명령 가드의 여러 줄 명령 판정

명령 가드(Claude Code `PreToolUse(Bash)` 훅)가 줄바꿈으로 이어진 여러 줄 명령의 둘째 줄 이후와 히어독 뒤의 명령도
판정한다. 한 줄일 때 막히는 명령은 줄을 바꾸거나 히어독 뒤에 두어도 막힌다.

판정은 둘이다. **기존 판정**은 이 명세 전의 가드가 하던 처리(3절)로 만든 명령을 판정하고, **줄 판정**은 명령을 줄과
히어독 단위로 나눠 만든 판정 문자열(4절)을 판정한다. 둘 중 하나가 막으면 막는다. 그래서 이 명세 전에 막히던 명령은 모두
그대로 막히고, 새로 막히는 것은 셸이 실제로 실행하는 줄에서 가드가 거는 명령뿐이다.

이 동작과 6절의 회귀 케이스는 명령 가드를 Python 으로 옮기는 이식(#210)의 오라클이다. 이식은 이 명세의 규칙을 그대로
옮긴다. 선행 이슈는 없고, #210 구현보다 먼저 머지한다.

이 명세가 요구하는 결정 기록은 없다. 판정 원칙(미탐을 허용하고 오탐을 피한다, 설정을 읽지 못하면 차단한다)은
`.ai/project/architecture.md` 의 신뢰 경계가 갖는다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 입력에서 값 꺼내기 · 두 판정의 순서 | `src/templates/managed/script/hooks/bash-guard.sh` |
| 두 디코드 · 판정 문자열 만들기 · 가드 6종 | `src/templates/managed/script/hooks/_guards.sh` |
| 회귀 테스트 | `src/templates/managed/script/test-bash-guard.sh` |
| 스크립트 목록 설명 | `src/templates/managed/script/README.md` |

이 리포의 `script/` 아래 같은 이름의 파일은 거기서 설치된 사본이고 render 가 따라 바꾼다.

## 1. 바뀌는 것과 바뀌지 않는 것

바뀌지 않는 것:

- 가드 6종과 그 순서 — 보호 브랜치 → force push → 훅 우회 → 원격 삭제 → 보호 문서 셸 편집 → write-doc. 처음 걸린
  가드의 사유가 나온다
- 차단 프로토콜 — 0 통과, 2 차단. 사유와 안내 문구, 사용 기록(`block bash-guard <라벨>`)과 라벨 다섯
- 판정 값의 출처는 `script/harness.env` 다. 명령이 있는데 이 파일이 없으면 지금 문구로 차단한다
- 명령을 꺼내지 못하거나 꺼낸 값이 비면 통과한다
- 낱말 분해와 가드의 규칙 — 단순한 따옴표 구간만 푸는 것, 빈 따옴표, 따옴표 밖 백슬래시를 풀지 않는 것, `#` 을
  주석으로 보지 않는 것, 닫히지 않은 따옴표 뒤도 판정하는 것, 명령 자리, git 전역 옵션, `cd` 추적, 다른 리포 판정,
  보호 문서 가드의 문자열 판정
- 셸과 표준 도구(`sed` · `awk` · `tr` · `grep` · `git`)만으로 판정한다. python3 를 부르지 않는다
- Codex 에는 훅을 연결하지 않는다(`src/templates/vendors.toml` 의 `hooks = false`)

바뀌는 것:

- 줄바꿈이나 `<<` 가 든 명령은 줄 판정을 한 번 더 받는다
- 그래서 아래가 새로 막힌다 (5-1)
  - 둘째 줄 이후의 명령 — `git status<LF>git push --force …`
  - 히어독 종결 줄 다음 줄의 명령
  - 히어독 연산자 줄의 나머지 — `cat <<EOF > <보호 문서>` 같은 셸 쓰기, `cat <<EOF; git push --force …`
  - `<<` 가 히어독이 아닌 한 줄 명령의 뒤쪽 — 히어스트링 `<<<`, 따옴표 안의 `<<`, 산술 구간 안의 `<<`

판정 범위:

- 이 명세 전에 차단(2)이던 입력은 모두 차단이다. 기존 판정이 그대로 돌기 때문이다. 차단 사유도 같다 (2절)
- 줄 판정이 새로 판정 대상으로 삼는 것은 셸이 실행하는 명령 줄뿐이다. 히어독 본문, 닫힌 따옴표 안의 줄, 다루지
  못하는 구조(4-4)와 그 뒤는 줄 판정이 보지 않는다
- 판정 대상이 된 줄을 판정하는 규칙은 기존 가드의 규칙 그대로다

## 2. 판정 순서

1. 입력에서 명령의 JSON 문자열 값을 꺼낸다. 지금과 같다 — 입력의 줄바꿈 바이트를 지우고, 마지막 `"command"` 키의
   값을 이스케이프된 따옴표를 건너뛰며 닫는 따옴표까지 잘라낸다. 값이 비었으면 0
2. 그 값에서 기존 판정 명령(3절)과 줄 판정용 디코드 결과(4-1)를 만든다
3. `script/harness.env` 가 없으면 지금 문구로 차단(2)
4. 기존 판정 — 가드 6종이 기존 판정 명령을 판정한다. 처음 걸린 가드가 사용 기록을 남기고 사유를 내고 2
5. 줄 판정 — 줄 판정용 디코드 결과에 줄바꿈(LF)이나 `<<` 가 있을 때만 돈다. 판정 문자열(4-2)을 만들어 가드 6종이
   판정한다. 처음 걸린 가드가 4 와 같이 끝낸다
6. 0

- 두 판정은 같은 가드 함수를 같은 순서로 부른다. 가드 함수 하나를 바꾸면 두 판정에서 함께 바뀐다
- 기존 판정이 먼저 돈다. 두 판정이 모두 막는 명령의 사유는 기존 판정의 것이므로, 이 명세 전에 막히던 명령의 출력은
  바뀌지 않는다

## 3. 기존 판정 명령

1. JSON 문자열 값에 다음 치환을 이 순서로 하나씩, 값 전체에 적용한다 — `\"` → `"`, `\n` → 공백, `\t` → 공백,
   `\\` → `\`. 그 밖의 이스케이프(`\r` · `\b` · `\f` · `\/` · `\uXXXX`)는 적힌 그대로 둔다
2. 처음 나오는 `<<` 부터 끝까지 잘라낸다. 따옴표 안이어도, `<<<` 여도 자른다

치환을 차례로 적용하므로 다음이 성립한다. 줄 판정에 없는 이 성질이 기존 판정의 차단을 지킨다.

- 명령에 글자로 적힌 백슬래시+`n`(JSON 으로 `\\n`)은 백슬래시와 공백이 된다. 그 공백이 낱말 경계다
- 줄 끝 백슬래시(JSON 으로 `\\\n`)도 백슬래시와 공백이 된다
- `\r` 은 백슬래시와 `r` 두 글자로 남는다. 큰따옴표 구간 안에 든 CR 은 그 구간을 안에 백슬래시가 있는 구간으로 만들고,
  그런 구간은 풀지 않으므로 안의 `;` · `|` · `&` 가 구획을 나눈다

## 4. 줄 판정

### 4-1. 디코드

JSON 문자열 값의 이스케이프를 한 번에 푼다. 이스케이프 하나는 한 번만 풀린다.

| 이스케이프 | 결과 |
|---|---|
| `\"` | `"` |
| `\\` | `\` |
| `\n` | 줄바꿈(LF) |
| `\t` | 탭 |
| `\r` | CR |
| 그 밖 — `\b` · `\f` · `\/` · `\uXXXX` | 적힌 그대로 |

- 명령에 글자로 적힌 백슬래시+`n`(JSON 으로 `\\n`)은 백슬래시와 `n` 두 글자다. 줄바꿈이 아니다
- CR 은 낱말 안의 글자다. 줄을 나누지 않는다

### 4-2. 판정 문자열 만들기

디코드 결과를 앞에서부터 읽어 줄바꿈이 없는 판정 문자열을 만든다. 다루지 못하는 구조(4-4)를 만나면 그 자리 앞까지만
만든다.

| 만나는 것 | 처리 |
|---|---|
| `'…'` | 다음 `'` 까지가 한 구간이다. 안의 글자는 그대로 두고 줄바꿈만 공백으로 바꾼다 |
| `"…"` | 백슬래시가 이스케이프한 글자를 건너뛰며 다음 `"` 까지가 한 구간이다. 안의 백슬래시+줄바꿈은 지우고 남은 줄바꿈은 공백으로 바꾼다. 안에 명령 치환(`$(` · 백틱)이 있으면 먼저 4-4 를 본다 |
| `$'…'` | 백슬래시가 이스케이프한 글자를 건너뛰며 다음 `'` 까지가 한 구간이다. 줄바꿈은 공백으로 바꾼다 |
| 닫히지 않은 따옴표 | 그 따옴표 글자를 그대로 두고, 그 뒤로는 따옴표 글자를 따옴표로 보지 않는다 |
| 따옴표 밖의 백슬래시+줄바꿈 | 둘 다 지운다 — 줄을 잇는다 |
| 따옴표 밖의 백슬래시+다른 글자 | 둘 다 그대로 둔다 |
| 따옴표 밖의 줄바꿈 | `;` 로 바꾼다 — 구획 구분자다. 본문이 남은 히어독이 있으면 그 본문을 뺀다 (4-3) |
| `<<<` | 히어스트링이다. 그대로 둔다 |
| `<<` · `<<-` | 히어독 연산자다 (4-3). 명령 치환 안이면 4-4 |
| `$((` · `((` | `((` 다음부터 괄호를 세어 두 여는 괄호가 모두 닫히는 `)` 를 같은 줄 안에서 찾는다. 그 `)` 바로 앞 글자도 `)` 이면 산술 구간이고 그대로 둔다 — 안의 `<<` 는 시프트 연산자다. 앞 글자가 `)` 가 아니면 `$((` 는 명령 치환 `$(` 와 여는 괄호, `((` 는 여는 괄호 둘이다. 같은 줄 안에서 닫히지 않으면 4-4 |
| `$(` · 백틱 | 명령 치환 구간이다. `$(` 는 괄호 짝이 맞는 `)` 까지, 백틱은 다음 백틱까지다. 안의 따옴표와 줄바꿈은 바깥과 같이 다룬다 |
| 그 밖의 글자 | 그대로 둔다 |

- 따옴표 구간이 닫히는지는 명령 끝까지 보고 정한다. 구간은 줄을 넘을 수 있다
- 판정 문자열에는 줄바꿈이 없다. 가드의 낱말 분해가 이 문자열을 한 줄 명령처럼 읽는다

### 4-3. 히어독

- 연산자는 `<<` 또는 `<<-` 와, 이어지는 공백 · 탭 뒤의 구분어 낱말이다
  - 구분어는 공백 · 탭 · 줄바꿈 · `;` · `&` · `|` · `<` · `>` · `(` · `)` 앞에서 끝난다
  - 구분어는 따옴표와 백슬래시를 뗀 값이다 — `'EOF'` · `"EOF"` · `\EOF` · `E"O"F` 는 모두 `EOF`
- 연산자와 구분어는 판정 문자열에 남는다. 연산자 줄의 나머지(리다이렉션, 같은 줄의 다른 구획)는 판정한다
- 본문은 연산자 줄을 끝내는 줄바꿈(따옴표 밖이고 줄 잇기가 아닌 것) 다음 줄부터, 구분어와 글자가 똑같은 줄(종결 줄)까지다
  - `<<-` 면 각 줄 앞의 탭을 떼고 비교한다
  - 본문과 종결 줄은 판정 문자열에서 빠진다. 판정은 종결 줄 다음 줄부터 다시 한다
  - 한 줄에 연산자가 여럿이면 그 차례로 본문이 이어진다
  - 종결 줄이 없으면 본문은 명령 끝까지다
- 비교는 글자 그대로다. CR 로 끝나는 줄로 쓴 히어독은 구분어와 종결 줄이 모두 CR 로 끝나므로 맞는다
- 보호 문서 셸 편집 가드도 본문이 빠진 판정 문자열을 본다. 히어독 본문에 적힌 보호 문서 경로와 쓰기 명령은 판정하지 않는다

### 4-4. 다루지 못하는 구조

아래를 만나면 판정 문자열을 그 자리 앞까지만 만든다. 그 자리부터 뒤는 기존 판정만 본다.

| 구조 | 자리 |
|---|---|
| 명령 치환(`$(…)` · 백틱) 안의 `<<` (`<<<` 는 제외) | 그 `<<` |
| 명령 치환이 든 큰따옴표 구간 가운데 다음 하나에 해당하는 것 — 구간에 줄바꿈이 있다, 백슬래시가 이스케이프한 글자를 뺀 `(` 와 `)` 의 수가 다르다, 백틱이 홀수 개다, `#` · `case` · `<<`(`<<<` 는 제외)가 들었다 | 그 큰따옴표 |
| 같은 줄 안에서 닫히지 않는 `$((` · `((` | 그 구간의 시작 |
| 구분어가 빈 히어독 연산자 | 그 `<<` |
| 본문이 남은 히어독이 있는데 명령 치환 안에서 만난 줄바꿈 | 그 히어독의 연산자 |

- 큰따옴표 구간 안의 명령 치환은 백슬래시가 이스케이프하지 않은 `$(` 와 백틱이다. `$((` 는 명령 치환으로 세지 않는다
- 큰따옴표 구간은 4-2 의 규칙으로 잡는다. 명령 치환 안의 따옴표는 셸에서는 새 따옴표 구간을 열지만 이 규칙은 그것을
  구간의 끝으로 읽는다. 둘째 행의 조건은 그렇게 잘못 잡혔을 수 있는 구간을 고른다
- 줄 판정이 판정 문자열을 끝까지 만들지 못해도 기존 판정은 명령 전체를 그대로 판정한다

### 4-5. 판정

- 가드 6종이 판정 문자열을 기존 가드의 규칙 그대로 판정한다 — 풀린 따옴표 구간 밖의 `|` · `;` · `&` 에서 구획을 나누고,
  앞 구획의 `cd` 를 다음 구획에 잇고, 보호 문서 셸 편집 가드는 문자열 전체를 정규식으로 본다
- 판정 문자열은 `<<` 에서 자르지 않는다

## 5. 판정 표

"현행" 은 2026-10-10 이 기기에서 관측한 값이다. 이 리포의 `script/hooks/bash-guard.sh`(이 명세를 쓸 때의 develop 과
같은 파일)에 `HARNESS_USAGE_LOG=off` 를 주고, Claude Code 와 같은 모양의 입력
(`json.dumps({"tool_name": "Bash", "tool_input": {"command": <명령>}}, ensure_ascii=False)`)을 표준 입력으로 흘렸다.
기존 판정은 현행과 같은 처리이므로 그 값도 이 열과 같다.

"줄 판정" 과 "#220 뒤" 는 이 명세의 규칙이 정하는 값이다. 줄 판정의 `—` 는 줄바꿈도 `<<` 도 없어 줄 판정이 돌지 않는다는
뜻이다. "#220 뒤" 는 6절의 회귀 케이스 기대값이다.

표기:

- `<LF>` · `<CR>` · `<TAB>` 는 그 글자 하나다
- `<보호 브랜치>` 는 `PROTECTED_BRANCHES` 의 이름, `<작업 브랜치>` 는 보호 목록에 없는 기능 브랜치 이름이다
- `<보호 문서>` 는 `PROTECTED_DOCS_SAMPLE`, `<보호 문서 이름>` 은 그 문서의 write-doc 이름, `<forge CLI>` 는
  `FORGE_CLIS` 의 첫 이름이다
- 보호 브랜치 commit 묶음의 훅 작업 디렉터리는 작업 브랜치 작업 트리다. `<보호 브랜치 작업 트리>` 는 같은 리포에서
  보호 브랜치를 체크아웃한 작업 트리다
- 보호 문서 · write-doc 이름과 원격 삭제 행은 이 리포의 설정(`roles/` 가 보호 목록에 들고, 이슈 삭제를 금지한다)에서의 값이다

### 5-1. 새로 막히는 것

| 묶음 | 입력 | 현행 | 줄 판정 | #220 뒤 |
|---|---|---|---|---|
| 보호 브랜치 push | `git status<LF>git push origin <보호 브랜치>` | 0 | 2 | 2 |
| 보호 브랜치 push | `echo hi<LF>git push origin <보호 브랜치>` | 0 | 2 | 2 |
| 보호 브랜치 push | `echo hi<LF>env GIT_TRACE=1 git push origin <보호 브랜치>` | 0 | 2 | 2 |
| 보호 브랜치 commit | `echo hi<LF>git -C <보호 브랜치 작업 트리> commit -m x` | 0 | 2 | 2 |
| 보호 브랜치 commit | `cd <보호 브랜치 작업 트리><LF>git commit -m x` | 0 | 2 | 2 |
| 보호 브랜치 commit | `cat <<EOF<LF>x<LF>EOF<LF>cd <보호 브랜치 작업 트리><LF>git commit -m x` | 0 | 2 | 2 |
| force push | `git status<LF>git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `# note<LF>git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `echo hi # c<LF>git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `# don't<LF>git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `git status<CR><LF>git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `x=$(git status)<LF>git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `cd "$(git rev-parse --show-toplevel)"<LF>git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `cat <<EOF > out.txt<LF>body<LF>EOF<LF>git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `cat <<-EOF<LF><TAB>body<LF><TAB>EOF<LF>git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `cat <<A <<B<LF>a<LF>A<LF>b<LF>B<LF>git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `cat <<EOF<CR><LF>body<CR><LF>EOF<CR><LF>git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `cat <<EOF; git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `cat <<< hi; git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `echo "a << b"; git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| force push | `echo $((1<<2)); git push --force origin <작업 브랜치>` | 0 | 2 | 2 |
| 훅 우회 | `echo hi<LF>git commit --no-verify -m x` | 0 | 2 | 2 |
| 훅 우회 | `cat <<'EOF' > out.txt<LF>x<LF>EOF<LF>git commit --no-verify -m x` | 0 | 2 | 2 |
| 훅 우회 | `git commit -m "a << b" --no-verify` | 0 | 2 | 2 |
| 훅 우회 | `git commit -m "$(cat <<<x)" --no-verify` | 0 | 2 | 2 |
| 원격 삭제 | `echo hi<LF><forge CLI> issue delete 100` | 0 | 2 | 2 |
| 원격 삭제 | `<forge CLI> issue view 1<LF><forge CLI> pr delete 7` | 0 | 2 | 2 |
| 원격 삭제 | `<forge CLI> issue \<LF>delete 3` | 0 | 2 | 2 |
| 보호 문서 | `cat <<EOF > out.txt<LF>x<LF>EOF<LF>echo y >> <보호 문서>` | 0 | 2 | 2 |
| 보호 문서 | `cat <<EOF > <보호 문서><LF>x<LF>EOF` | 0 | 2 | 2 |
| 보호 문서 | `cat <<'EOF' > <보호 문서><LF>x<LF>EOF` | 0 | 2 | 2 |
| write-doc | `echo hi<LF>harness write-doc <보호 문서 이름> -` | 0 | 2 | 2 |
| write-doc | `cd x<LF>src/bin/harness write-doc roles/developer -` | 0 | 2 | 2 |

### 5-2. 그대로 막히는 것

| 묶음 | 입력 | 현행 | 줄 판정 | #220 뒤 |
|---|---|---|---|---|
| 보호 브랜치 push | `git push origin <보호 브랜치>` | 2 | — | 2 |
| 보호 브랜치 push | `echo hi # ; git push origin <보호 브랜치>` | 2 | — | 2 |
| 보호 브랜치 push | `git push origin \<LF><보호 브랜치>` | 2 | 2 | 2 |
| 보호 브랜치 push | `git push origin<LF><보호 브랜치>` | 2 | 0 | 2 |
| 보호 브랜치 push | `git push origin feat\n<보호 브랜치>` (백슬래시와 `n` 두 글자) | 2 | — | 2 |
| 보호 브랜치 push | `git push --force origin feat\n<보호 브랜치>` (백슬래시와 `n` 두 글자) | 2 | — | 2 |
| 보호 브랜치 commit | `git -C <보호 브랜치 작업 트리> commit -m x` | 2 | — | 2 |
| force push | `git push --force origin <작업 브랜치>` | 2 | — | 2 |
| force push | `git status; git push --force origin <작업 브랜치>` | 2 | — | 2 |
| force push | `# don't; git push --force origin <작업 브랜치>` | 2 | — | 2 |
| force push | `git status &&<LF>git push --force origin <작업 브랜치>` | 2 | 2 | 2 |
| force push | `git status \|<LF>git push --force origin <작업 브랜치>` | 2 | 2 | 2 |
| force push | `if git status; then<LF>git push --force origin <작업 브랜치><LF>fi` | 2 | 2 | 2 |
| force push | `(<LF>git push --force origin <작업 브랜치><LF>)` | 2 | 2 | 2 |
| force push | `for r in origin; do<LF>git push --force $r <작업 브랜치><LF>done` | 2 | 2 | 2 |
| force push | `x=$(<LF>git push --force origin <작업 브랜치><LF>)` | 2 | 2 | 2 |
| force push | `git push \<LF>--force origin <작업 브랜치>` | 2 | 2 | 2 |
| force push | `git push<LF>--force origin <작업 브랜치>` | 2 | 0 | 2 |
| force push | `echo "<CR>; git push --force origin <작업 브랜치>"` (CR 은 JSON 으로 `\r`) | 2 | — | 2 |
| force push | `echo 'a; git push --force origin <작업 브랜치> <<' x` | 2 | 0 | 2 |
| 훅 우회 | `git commit --no-verify -m x` | 2 | — | 2 |
| 훅 우회 | `git commit -m x \<LF>--no-verify` | 2 | 2 | 2 |
| 훅 우회 | `git commit -m x<LF>--no-verify` | 2 | 0 | 2 |
| 원격 삭제 | `<forge CLI> issue delete 100` | 2 | — | 2 |
| 보호 문서 | `cat > <보호 문서> <<EOF` | 2 | 2 | 2 |
| 보호 문서 | `echo hi<LF>echo x >> <보호 문서>` | 2 | 2 | 2 |
| 보호 문서 | `cd .<LF>sed -i '' 's/a/b/' <보호 문서>` | 2 | 2 | 2 |
| 보호 문서 | `ls<LF>cp /dev/null <보호 문서>` | 2 | 2 | 2 |
| 보호 문서 | `echo x ><LF><보호 문서>` | 2 | 0 | 2 |
| write-doc | `harness write-doc <보호 문서 이름> -` | 2 | — | 2 |

### 5-3. 그대로 통과하는 것

| 입력 | 현행 | 줄 판정 | #220 뒤 |
|---|---|---|---|
| `cat <<EOF<LF>git push --force origin <작업 브랜치><LF>EOF` | 0 | 0 | 0 |
| `cat <<EOF<LF>git push origin <보호 브랜치><LF>EOF` | 0 | 0 | 0 |
| `git commit -F - <<EOF<LF>요약<LF><LF>- --no-verify 로 훅을 우회하는 명령을 차단<LF>EOF` | 0 | 0 | 0 |
| `cat <<EOF > notes.txt<LF>mv <보호 문서> old.md<LF>EOF` | 0 | 0 | 0 |
| `python3 - <<'EOF'<LF>print('git push --force')<LF>EOF` | 0 | 0 | 0 |
| `cat <<EOF<LF>git push --force origin <작업 브랜치>` (종결 줄 없음) | 0 | 0 | 0 |
| `cat <<EOF<LF>x<LF>EOF<LF>echo '<LF>git push --force origin <작업 브랜치><LF>'` | 0 | 0 | 0 |
| `git commit -m "$(cat <<'EOF'<LF>docs: 요약<LF><LF>- --no-verify 를 막는다<LF>EOF<LF>)"` | 0 | 0 | 0 |
| `echo "a<LF>git push --force origin <작업 브랜치>"` | 0 | 0 | 0 |
| `echo 'a<LF>git push --force origin <작업 브랜치>'` | 0 | 0 | 0 |
| `git commit -m "fix<LF><LF>git push --force origin <작업 브랜치>"` | 0 | 0 | 0 |
| `<forge CLI> issue create --title x --body "a<LF><forge CLI> issue delete 1"` | 0 | 0 | 0 |
| `echo "$(echo "<LF>git push --force origin <작업 브랜치>")"` | 0 | 0 | 0 |
| `echo "$(printf ")")<LF>git push --force origin <작업 브랜치>"` | 0 | 0 | 0 |
| `echo "$(case $x in a) echo "<LF>git push --force origin <작업 브랜치><LF>";; esac)"` | 0 | 0 | 0 |
| `echo $'a\'b<LF>git push --force origin <작업 브랜치><LF>'` | 0 | 0 | 0 |
| `echo a\ngit push --force origin <작업 브랜치>` (백슬래시와 `n` 두 글자) | 0 | — | 0 |
| `git status<LF>git log --oneline -3` | 0 | 0 | 0 |
| `cd <작업 브랜치 작업 트리><LF>git commit -m x` (훅 작업 디렉터리는 보호 브랜치 작업 트리) | 0 | 0 | 0 |

### 5-4. 규칙이 정하는 값

- 따옴표 안의 `<<` 와 산술 구간 안의 `<<` 는 히어독이 아니다. 줄 판정은 그 뒤를 이어 판정한다. 그래서
  `echo "a << b"; git push --force …` · `echo $((1<<2)); git push --force …` · `git commit -m "a << b" --no-verify` 는 2 다.
  셋 다 셸이 뒤쪽 명령(옵션)을 실제로 실행한다. 기존 판정은 처음 `<<` 에서 잘라 셋 다 0 이다
- 명령에 글자로 적힌 백슬래시+`n` 은 줄 판정에서 줄바꿈이 아니다. 줄바꿈도 `<<` 도 없는 한 줄 명령이면 줄 판정이 돌지
  않고 기존 판정만 본다. 기존 판정은 이것을 백슬래시와 공백으로 읽으므로 `git push origin feat\n<보호 브랜치>` 와
  `git push --force origin feat\n<보호 브랜치>` 는 `<보호 브랜치>` 를 목적지로 보아 2 다(사유는 보호 브랜치 push).
  `echo a\ngit push --force …` 는 기존 판정에서 `echo` 한 명령이므로 0 이다
- 큰따옴표 안의 CR 이 JSON 으로 `\r` 로 오면(6-1 의 전제) 기존 판정은 그것을 두 글자로 두어 구간을 풀지 않는다. 그래서
  `echo "<CR>; git push --force …"` 는 `;` 에서 나뉘어 2 다. 같은 명령의 CR 을 JSON 에 이스케이프하지 않고 넣으면 기존
  판정에서도 단순한 구간이 되어 0 이다. 이 값도 바뀌지 않는다
- 줄바꿈이 낱말 사이에 든 명령(`git push origin<LF><보호 브랜치>` · `git push<LF>--force …` · `git commit -m x<LF>--no-verify`
  · `echo x ><LF><보호 문서>`)은 줄 판정에서는 두 명령이라 0 이지만 기존 판정이 한 명령으로 읽어 2 다

## 6. 회귀 테스트 — `test-bash-guard.sh`

### 6-1. 입력 만들기

`probe` 는 Claude Code 가 보내는 모양으로 명령을 이스케이프한다 — `\` → `\\`, `"` → `\"`, 줄바꿈 → `\n`, CR → `\r`,
탭 → `\t`. 나머지 글자는 그대로 둔다. <!-- TBD: 확인 필요 — Claude Code 가 훅 입력에서 CR · 탭을 이 모양으로 이스케이프하는지 -->

### 6-2. 차단 표에 더하는 케이스

5-1 · 5-2 의 행을 묶음에 따라 아래 표에 더한다. 망가뜨린 가드 사본 검사가 이 표를 그대로 쓰므로 더한 케이스도 그
검사를 받는다. 케이스 값은 기존 표처럼 설정에서 받는다(`protected_a` · `protected_b` · `work_branch` · `doc` ·
`doc_name` · `forge_cli`).

| 표 | 더하는 행 |
|---|---|
| `protected_cases` | 5-1 · 5-2 의 보호 브랜치 push 행 가운데 기존 표에 없는 것 |
| `force_cases` | 5-1 · 5-2 의 force push 행 가운데 기존 표에 없는 것 |
| `verify_cases` | 5-1 · 5-2 의 훅 우회 행 가운데 기존 표에 없는 것 |
| `remote_delete_cases` | 5-1 의 원격 삭제 행 |
| `arch_cases` | 5-1 · 5-2 의 보호 문서 행 가운데 기존 표에 없는 것 |
| `write_doc_cases` | 5-1 의 write-doc 행 |

- 각 행은 그 묶음의 가드가 두 판정의 합에서 처음 막는 명령이다. 그래서 force push 가드만 끈 사본에서 `force_cases` 는 모두
  통과하고 나머지 표는 그대로 막힌다. write-doc 가드만 끈 사본도 같다
- `git push --force origin feat\n<보호 브랜치>` 는 기존 판정에서 보호 브랜치 가드가 먼저 막으므로 `protected_cases` 에 든다

### 6-3. 작업 트리 절

보호 브랜치 commit 행은 임시 작업 트리 절에서 `at_is` 로 돈다.

| 기대 | 훅 작업 디렉터리 | 명령 |
|---|---|---|
| 2 | 작업 브랜치 작업 트리 | `echo hi<LF>git -C <보호 브랜치 작업 트리> commit -m x` |
| 2 | 작업 브랜치 작업 트리 | `cd <보호 브랜치 작업 트리><LF>git commit -m x` |
| 2 | 작업 브랜치 작업 트리 | `cat <<EOF<LF>x<LF>EOF<LF>cd <보호 브랜치 작업 트리><LF>git commit -m x` |
| 0 | 보호 브랜치 작업 트리 | `cd <작업 브랜치 작업 트리><LF>git commit -m x` |

### 6-4. 통과 케이스

5-3 의 행 가운데 기존 케이스에 없는 것을 `case_is 0` 으로 더한다. 작업 트리가 필요한 마지막 행은 6-3 에 든다.

### 6-5. 그대로 두는 것과 두지 않는 것

- 기존 케이스와 기대값은 그대로다
- 망가뜨린 가드 사본 검사 둘(force push · write-doc)과 비교 값 검사(`_guards.sh` 를 읽어 비교 함수를 바꿔 끼우는 것)는
  그대로다. 두 판정이 같은 가드 함수를 부르므로 사본의 함수 하나를 바꾸면 두 판정에서 함께 바뀐다
- 10절의 미탐은 회귀 케이스로 고정하지 않는다. 실행되는 위험 명령의 통과를 기대값으로 두지 않는다
- `src/test/render-test.sh` 는 고치지 않는다. 설치한 리포에서 `script/test-*.sh` 를 모두 돌리는 블록(UT-61)이 이 테스트를
  돌린다

## 7. 이행

- develop 위에서 착수한다. #210 구현보다 먼저 머지한다
- 이 리포는 자기 가드 아래에서 이 변경을 만든다. render 가 이 리포의 `script/hooks/` 사본을 바꾸면 같은 세션의 다음
  Bash 호출부터 새 판정이 돈다

## 8. 문서

| 문서 | 고칠 것 |
|---|---|
| `src/templates/managed/script/README.md` 목록 표 | `hooks/bash-guard.sh` 행: 도구 호출 JSON 에서 명령을 꺼내 기존 판정과 줄 판정(여러 줄 · 히어독을 나눠 본다)으로 가드를 돌린다 — **실행 전에** 판정. 0=통과, 2=차단. `hooks/_guards.sh` 행: 가드 함수와 줄 판정 문자열 만들기 |
| `bash-guard.sh` · `_guards.sh` 머리 주석 | 두 판정과 판정 문자열을 현재형으로 서술한다 |
| `test-bash-guard.sh` 머리글과 `probe` 주석 | `probe` 가 Claude Code 모양(6-1)으로 이스케이프한다 |

## 9. 보호 문서 개정 범위

없다. `.ai/project/architecture.md` 는 가드의 명령 분해 방식을 적지 않고, 이 명세는 신뢰 경계의 "가드는 미탐을 허용하고
오탐을 피한다" 를 그대로 따른다. `.ai/project/testing.md` 의 "관리 스크립트는 각자 `script/test-<이름>.sh` 를 갖는다" 도
그대로다.

## 10. 한계

- 명령 치환 안의 히어독과 다루지 못하는 큰따옴표 구간(4-4) 뒤의 명령은 판정하지 못한다. 줄 판정은 그 자리에서 멈추고,
  기존 판정은 처음 `<<` 에서 자르거나 줄을 한 명령으로 읽는다. Claude Code 커밋 관용형
  `git commit -m "$(cat <<'EOF' … EOF<LF>)"` 뒤에 오는 `&& git push --force …` 나 다음 줄의 명령이 여기 든다. 4-4 의 다른
  구조(줄을 넘는 산술 구간, 구분어가 빈 연산자) 뒤도 같다
- `#` 을 주석으로 보지 않으므로 주석 안의 따옴표가 뒤 줄의 따옴표와 짝지어지면 그 사이의 줄을 따옴표 안으로 읽어 판정하지
  못한다 — `# don't<LF>git push --force origin '<작업 브랜치>'`. 주석 안의 따옴표에 짝이 없으면 닫히지 않은 따옴표로 다뤄
  다음 줄을 판정한다(5-1 의 `# don't<LF>…`)
- 4-2 가 따로 다루지 않는 구조 안의 `<<`(매개변수 확장 `${…}` 안 등)는 히어독 연산자로 읽는다. 그 뒤 줄은 종결 줄로 읽힌
  줄까지 판정하지 못한다
- 기존 판정이 내는 차단은 셸이 그렇게 실행하지 않는 해석이어도 남는다. `git push origin<LF><보호 브랜치>` 는 셸이
  `<보호 브랜치>` 로 push 하지 않지만 기존 판정이 한 명령으로 읽어 막는다 — 이 명세 전의 차단을 하나도 풀지 않기 때문이다
- 줄 판정의 디코드는 Claude Code 가 줄바꿈 · 탭 · CR 을 `\n` · `\t` · `\r` 로 보낸다는 전제다. 다른 표기(`\u000a` 등)로
  보내면 그 글자는 줄 판정에서 적힌 그대로 남아 줄을 나누지 않는다 <!-- TBD: 확인 필요 — Claude Code 의 훅 입력 직렬화 -->
- 줄바꿈이나 `<<` 가 든 명령은 가드 6종을 두 번 돈다
