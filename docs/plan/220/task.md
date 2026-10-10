# #220 task

## T1 · chore: 가드 회귀 테스트 입력의 CR·탭 이스케이프와 바뀌지 않는 판정 케이스 추가

### 상위 Requirement

- relates to #220

### 작업 내용

가드를 고치기 전에 회귀 테스트의 입력을 Claude Code 가 보내는 모양으로 맞추고, 이 이슈가 바꾸지 않는 판정을 케이스로 고정한다.
가드는 고치지 않는다. 더한 케이스는 지금 가드에서 통과하고, T2 · T3 이 그 케이스를 고치지 않고 통과해야 한다.

- 명세 6-1(입력 만들기) · 6-2(차단 표 배정 가운데 5-2 의 행) · 6-3 넷째 행 · 6-4(통과 케이스) · 8 의 `test-bash-guard.sh` 행
- `probe`: `\` → `\\`, `"` → `\"`, 줄바꿈 → `\n`, CR → `\r`, 탭 → `\t` 로 이스케이프하고 나머지 글자는 그대로 둔다
- 머리글과 `probe` 주석: `probe` 가 Claude Code 모양으로 이스케이프한다는 것을 현재형으로 쓴다
- 차단 표: 명세 5-2 의 행 가운데 기존 표에 없는 것을 6-2 의 배정대로 더한다
  - `protected_cases` 5행 — `echo hi # ; …`, 줄 잇기, 낱말 사이 줄바꿈, 글자로 적힌 백슬래시+`n` 둘
    (`git push --force origin feat\n<보호 브랜치>` 도 여기 든다)
  - `force_cases` 12행 — `;` 구획, 주석 뒤 `;`, 줄 끝 `&&` · `|`, `if` · `( )` · `for` · `x=$(` 복합 명령, 줄 잇기, 낱말 사이 줄바꿈,
    큰따옴표 안 CR, 홑따옴표 안 `<<`
  - `verify_cases` 3행 — `git commit --no-verify -m x`, 줄 잇기, 낱말 사이 줄바꿈
  - `arch_cases` 4행 — 줄바꿈 뒤의 `>>` · `sed -i` · `cp`, 낱말 사이 줄바꿈
- 통과 케이스: 명세 5-3 의 행 가운데 기존 케이스에 없는 것
  - `git commit` 을 실행하는 둘(`git commit -m "$(cat <<'EOF' …)"` · `git commit -m "fix<LF><LF>git push --force …"`)은
    "브랜치에 따라 갈리는 commit 판정" 절의 작업 브랜치 반복에 더한다
  - 나머지 15행은 `case_is 0` 으로 더한다
- 작업 트리 절: 명세 6-3 넷째 행(훅 작업 디렉터리는 보호 브랜치 작업 트리, `cd <작업 브랜치 작업 트리><LF>git commit -m x`)을
  `at_is 0` 으로 더한다
- `src/bin/harness render` 로 이 리포의 `script/test-bash-guard.sh` 사본과 `.harness/managed` 를 갱신한다
- 건드릴 파일: `src/templates/managed/script/test-bash-guard.sh`, render 로 갱신되는 `script/test-bash-guard.sh` · `.harness/managed`

### 완료 조건

- [ ] `probe` 가 백슬래시 · 큰따옴표 · 줄바꿈 · CR · 탭을 명세 6-1 대로 이스케이프하고 나머지 글자를 그대로 둔다
- [ ] 더한 차단 케이스 24개가 지금 가드에서 2 다
- [ ] 더한 통과 케이스 18개(`case_is` 15 · 작업 브랜치 commit 2 · `at_is` 1)가 지금 가드에서 0 이다
- [ ] `echo "<CR>; git push --force origin <작업 브랜치>"` 가 2 다 — CR 을 이스케이프하지 않던 `probe` 로는 0 이 되는 케이스다
- [ ] 기존 케이스의 기대값이 그대로이고 모두 통과한다
- [ ] force push · write-doc 가드를 끈 사본 검사가 늘어난 표로 통과한다
- [ ] `bash-guard.sh` · `_guards.sh` 가 바뀌지 않는다
- [ ] `script/test-bash-guard.sh` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/220-guard-multiline-commands` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 보호 브랜치 push 가 그대로 막힘 | 명세 5-2 의 보호 브랜치 push 행 가운데 기존 표에 없는 5행 | 2 (`protected_cases`) |
| UT-02 | force push 가 그대로 막힘 | 명세 5-2 의 force push 행 가운데 기존 표에 없는 12행 | 2 (`force_cases`) |
| UT-03 | 훅 우회가 그대로 막힘 | 명세 5-2 의 훅 우회 행 가운데 기존 표에 없는 3행 | 2 (`verify_cases`) |
| UT-04 | 보호 문서 셸 편집이 그대로 막힘 | 명세 5-2 의 보호 문서 행 가운데 기존 표에 없는 4행 | 2 (`arch_cases`) |
| UT-05 | 큰따옴표 안 CR 의 이스케이프 | `echo "<CR>; git push --force origin <작업 브랜치>"` | 2 |
| UT-06 | 히어독 본문 · 닫힌 따옴표 안의 줄 · 다루지 못하는 구조 · 글자로 적힌 백슬래시+`n` 이 통과 | 명세 5-3 의 행 가운데 기존에 없고 `git commit` 을 실행하지 않는 15행 | 0 |
| UT-07 | 작업 브랜치 commit 메시지 안의 줄 | `git commit -m "$(cat <<'EOF'<LF>docs: 요약<LF><LF>- --no-verify 를 막는다<LF>EOF<LF>)"` · `git commit -m "fix<LF><LF>git push --force origin <작업 브랜치>"` | 작업 브랜치 임시 리포에서 0 |
| UT-08 | 앞 줄의 `cd` 가 작업 브랜치 작업 트리 | 훅 작업 디렉터리는 보호 브랜치 작업 트리, `cd <작업 브랜치 작업 트리><LF>git commit -m x` | 0 (`at_is`) |
| UT-09 | 망가뜨린 가드 사본 | force push · write-doc 가드를 하나씩 끈 사본에 늘어난 차단 표 | 끈 가드의 표만 0, 나머지 표는 2 |

## T2 · fix: 명령 가드가 줄바꿈이 든 명령을 줄 판정으로 한 번 더 판정

### 상위 Requirement

- relates to #220

### 작업 내용

명령 가드가 명령을 두 번 판정한다. 기존 판정은 지금 처리 그대로 만든 명령을, 줄 판정은 줄바꿈이 든 명령을 줄 단위로 나눠
만든 판정 문자열을 가드 6종으로 판정하고, 둘 중 하나가 막으면 막는다. 둘째 줄 이후의 명령이 이 task 에서 막힌다.

- 명세 2(판정 순서) · 3(기존 판정 명령) · 4-1(디코드) · 4-2(판정 문자열 만들기, `<<<` · `<<` 두 행 제외) · 4-4 의 둘째 · 셋째
  행 · 4-5(판정) · 5-1 의 `<<` 가 없는 행 · 6-2 · 6-3 첫째 · 둘째 행 · 8 의 머리 주석
- `bash-guard.sh`
  - 값 꺼내기는 그대로 둔다
  - 꺼낸 값에서 기존 판정 명령과 줄 판정 디코드 결과를 만든다
  - `script/harness.env` 확인 뒤 기존 판정, 이어서 디코드 결과에 줄바꿈이 있을 때만 줄 판정을 한다. 두 판정은 같은 가드
    6종을 같은 순서로 부른다
- `_guards.sh`
  - 기존 판정 명령 만들기 — 지금 `bash-guard.sh` 에 있는 차례 치환(`\"` · `\n` · `\t` · `\\`)과 처음 `<<` 부터 자르기를
    옮긴다. 결과는 바뀌지 않는다
  - 줄 판정 디코드 — 명세 4-1 표대로 이스케이프를 한 번에 푼다
  - 판정 문자열 만들기 — 명세 4-2 표의 `'…'` · `"…"` · `$'…'` · 닫히지 않은 따옴표 · 따옴표 밖의 백슬래시+줄바꿈 · 백슬래시+다른
    글자 · 줄바꿈 · `$((` · `((` · `$(` · 백틱 · 그 밖의 글자 행. 따옴표 구간이 닫히는지는 명령 끝까지 보고 정한다
  - 명령 치환이 든 큰따옴표 구간 가운데 명세 4-4 둘째 행의 조건에 드는 것, 같은 줄 안에서 닫히지 않는 `$((` · `((` 를 만나면
    그 자리 앞까지만 만든다
  - 따옴표 구간과 닫힌 산술 구간 밖에서 `<<` 를 만나면 그 앞까지만 만든다. T3 이 이 처리를 히어독 규칙으로 바꾼다
  - 가드 6종은 고치지 않는다. 두 판정 모두 `$CMD` 를 판정한다
- 머리 주석: `bash-guard.sh` 와 `_guards.sh` 에 두 판정과 판정 문자열을 현재형으로 쓴다. 줄바꿈을 공백으로 둔다는 서술은 기존
  판정 명령의 것으로 고친다
- `test-bash-guard.sh`: 명세 5-1 의 `<<` 가 없는 행을 차단 표에 더한다 — `protected_cases` 3 · `force_cases` 7 · `verify_cases` 1
  · `remote_delete_cases` 3 · `write_doc_cases` 2. 작업 트리 절에 6-3 첫째 · 둘째 행을 `at_is 2` 로 더한다
- render 전에 정본 두 파일을 `sh -n` 으로 확인하고, `src/bin/harness render` 로 이 리포의 `script/` 사본과 `.harness/managed` 를
  갱신한다
- 건드릴 파일: `src/templates/managed/script/hooks/bash-guard.sh` · `hooks/_guards.sh` · `test-bash-guard.sh`, render 로 갱신되는
  `script/hooks/` · `script/test-bash-guard.sh` · `.harness/managed`

### 완료 조건

- [ ] 명세 5-1 의 `<<` 가 없는 행 16개와 6-3 첫째 · 둘째 행이 2 다
- [ ] T1 이 더한 케이스와 기존 케이스가 기대값 그대로 통과한다
- [ ] 줄바꿈이 없는 명령은 줄 판정을 받지 않는다 — 판정 문자열을 만드는 처리를 부르지 않는다
- [ ] `git status<LF>git push --force origin <작업 브랜치>` 를 막을 때의 표준 오류가 `git push --force origin <작업 브랜치>` 의
  것과 같다
- [ ] force push · write-doc 가드를 끈 사본 검사가 늘어난 표로 통과한다
- [ ] `bash-guard.sh` · `_guards.sh` 가 python3 를 부르지 않는다
- [ ] `script/test-bash-guard.sh` 와 `script/run-lint-test.sh` 가 통과한다

### 브랜치

- `fix/220-guard-multiline-commands` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 둘째 줄의 보호 브랜치 push | `git status<LF>git push origin <보호 브랜치>` 등 명세 5-1 의 보호 브랜치 push 3행 | 2 (`protected_cases`) |
| UT-02 | 둘째 줄의 force push — 주석 줄 · CR 줄 끝 · 명령 치환 뒤 | 명세 5-1 의 force push 행 가운데 `<<` 가 없는 7행 | 2 (`force_cases`) |
| UT-03 | 둘째 줄의 훅 우회 | `echo hi<LF>git commit --no-verify -m x` | 2 (`verify_cases`) |
| UT-04 | 둘째 줄의 원격 삭제와 줄 잇기 | 명세 5-1 의 원격 삭제 3행 | 2 (`remote_delete_cases`) |
| UT-05 | 둘째 줄의 write-doc | 명세 5-1 의 write-doc 2행 | 2 (`write_doc_cases`) |
| UT-06 | 앞 줄의 `cd` · 다음 줄의 `-C` 가 보호 브랜치 작업 트리 | 훅 작업 디렉터리는 작업 브랜치 작업 트리, 명세 6-3 첫째 · 둘째 행 | 2 (`at_is`) |
| UT-07 | 바뀌지 않는 판정 | T1 이 더한 케이스와 기존 케이스 | 기대값 그대로 |
| UT-08 | 망가뜨린 가드 사본 | force push · write-doc 가드를 하나씩 끈 사본에 늘어난 차단 표 | 끈 가드의 표만 0, 나머지 표는 2 |

## T3 · fix: 명령 가드가 << 가 든 명령에서 히어독 본문만 빼고 나머지를 판정

### 상위 Requirement

- relates to #220

### 작업 내용

줄 판정이 히어독을 다룬다. 히어독 본문과 종결 줄만 판정 문자열에서 빼고, 연산자 줄의 나머지와 종결 줄 다음 줄은 판정한다.
히어스트링 · 따옴표 안 · 산술 구간 안의 `<<` 는 히어독이 아니므로 그 뒤도 판정하고, `<<` 가 든 한 줄 명령도 줄 판정을 받는다.

- 명세 2 의 5(줄 판정 조건) · 4-2 의 `<<<` · `<<` 두 행 · 4-3(히어독) · 4-4 의 첫째 · 넷째 · 다섯째 행 · 5-1 의 `<<` 가 든 행 ·
  5-4 첫째 항목 · 6-2 · 6-3 셋째 행 · 8
- `_guards.sh` 의 판정 문자열 만들기: T2 의 "`<<` 앞까지만 만든다" 를 아래로 바꾼다
  - `<<<` 는 히어스트링이다. 그대로 둔다
  - `<<` · `<<-` 와 이어지는 공백 · 탭 뒤의 구분어 낱말이 연산자다. 구분어는 명세 4-3 의 글자 앞에서 끝나고 따옴표와 백슬래시를
    뗀 값이다. 연산자와 구분어는 판정 문자열에 남는다
  - 본문은 연산자 줄을 끝내는 줄바꿈 다음 줄부터 종결 줄까지이고, 본문과 종결 줄은 판정 문자열에서 뺀다. `<<-` 는 각 줄 앞의
    탭을 떼고 비교하고, 한 줄의 연산자 여럿은 차례로 본문을 잇고, 종결 줄이 없으면 명령 끝까지가 본문이다. 비교는 글자 그대로다
  - 명령 치환 구간을 따라가 명세 4-4 의 첫째(명령 치환 안의 `<<`) · 넷째(빈 구분어) · 다섯째(본문이 남은 히어독이 있는데 명령
    치환 안에서 만난 줄바꿈) 행을 만나면 그 자리 앞까지만 만든다
- `bash-guard.sh`: 줄 판정 조건을 "디코드 결과에 줄바꿈이나 `<<` 가 있을 때" 로 넓힌다
- 머리 주석: 기존 판정은 처음 `<<` 부터 자르고 줄 판정은 히어독 본문만 뺀다는 것을 현재형으로 쓴다
- `src/templates/managed/script/README.md` 목록 표의 `hooks/bash-guard.sh` · `hooks/_guards.sh` 행을 명세 8 의 문안으로 고친다
- `test-bash-guard.sh`: 명세 5-1 의 `<<` 가 든 행을 차단 표에 더한다 — `force_cases` 8 · `verify_cases` 3 · `arch_cases` 3. 작업
  트리 절에 6-3 셋째 행을 `at_is 2` 로 더한다
- render 전에 정본 두 파일을 `sh -n` 으로 확인하고, `src/bin/harness render` 로 이 리포의 `script/` 사본과 `.harness/managed` 를
  갱신한다
- 건드릴 파일: `src/templates/managed/script/hooks/bash-guard.sh` · `hooks/_guards.sh` · `test-bash-guard.sh` · `README.md`, render
  로 갱신되는 `script/hooks/` · `script/test-bash-guard.sh` · `script/README.md` · `.harness/managed`

### 완료 조건

- [ ] 명세 5-1 의 `<<` 가 든 행 14개와 6-3 셋째 행이 2 다
- [ ] 명세 5-3 의 히어독 행 — 본문에 적힌 위험 명령과 보호 문서 경로, 종결 줄이 없는 본문, 명령 치환 안의 히어독 — 이 0 이다
- [ ] T1 · T2 가 더한 케이스와 기존 케이스가 기대값 그대로 통과한다
- [ ] force push · write-doc 가드를 끈 사본 검사가 늘어난 표로 통과한다
- [ ] `src/templates/managed/script/README.md` 의 두 행이 명세 8 의 문안이다
- [ ] `bash-guard.sh` · `_guards.sh` 가 python3 를 부르지 않는다
- [ ] `script/test-bash-guard.sh` · `script/run-lint-test.sh` · `src/test/render-test.sh` 가 통과한다

### 브랜치

- `fix/220-guard-multiline-commands` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 종결 줄 다음 줄 | 명세 5-1 의 force push 히어독 4행 — `> out.txt` 리다이렉션, `<<-` 와 탭, 한 줄의 연산자 둘, CR 로 끝나는 줄 | 2 (`force_cases`) |
| UT-02 | 연산자 줄의 나머지 | `cat <<EOF; git push --force origin <작업 브랜치>` | 2 (`force_cases`) |
| UT-03 | 히어독이 아닌 `<<` | `cat <<< hi; …` · `echo "a << b"; …` · `echo $((1<<2)); …` (뒤는 `git push --force origin <작업 브랜치>`) | 2 (`force_cases`) |
| UT-04 | 히어독 뒤와 따옴표 안 `<<` 뒤의 훅 우회 | `cat <<'EOF' > out.txt<LF>x<LF>EOF<LF>git commit --no-verify -m x` · `git commit -m "a << b" --no-verify` · `git commit -m "$(cat <<<x)" --no-verify` | 2 (`verify_cases`) |
| UT-05 | 히어독 연산자 줄의 보호 문서 쓰기와 종결 줄 뒤의 쓰기 | 명세 5-1 의 보호 문서 3행 | 2 (`arch_cases`) |
| UT-06 | 히어독 뒤 줄의 `cd` | 훅 작업 디렉터리는 작업 브랜치 작업 트리, `cat <<EOF<LF>x<LF>EOF<LF>cd <보호 브랜치 작업 트리><LF>git commit -m x` | 2 (`at_is`) |
| UT-07 | 바뀌지 않는 판정 | T1 · T2 가 더한 케이스와 기존 케이스 — 특히 명세 5-3 의 히어독 본문 행 | 기대값 그대로 |
| UT-08 | 망가뜨린 가드 사본 | force push · write-doc 가드를 하나씩 끈 사본에 늘어난 차단 표 | 끈 가드의 표만 0, 나머지 표는 2 |
