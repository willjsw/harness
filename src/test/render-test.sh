#!/usr/bin/env bash
# 렌더·검사 회귀 테스트. 원격도 대상 리포도 건드리지 않는다 — 임시 디렉터리에서만 돈다.
#
#   src/test/render-test.sh
#
# 확인하는 것: 설정 하나를 고치면 그것을 쓰는 생성 파일이 **전부** 따라 바뀌는가,
# 생성 파일을 손으로 고치면 check 가 잡는가, 불변식 위반이 render 를 막는가.
# 이 셋이 하네스가 약속하는 전부다.
set -uo pipefail
# 훅이 넘긴 GIT_DIR·GIT_INDEX_FILE 같은 리포 지역 변수를 비운다. 남아 있으면 임시 리포를 만드는
# git init 이 임시 디렉터리 대신 그 변수가 가리키는 리포를 다시 초기화한다.
unset $(git rev-parse --local-env-vars 2>/dev/null)
cd "$(dirname "$0")/.."
root=$(pwd)
pass=0
fail=0

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# 설치 등록부를 사용자 홈에 남기지 않는다.
export HARNESS_HOME="$work/home"
# 바깥 실행의 지표 문맥을 물려받지 않는다 — 이 테스트가 검증 스크립트(harness-verify.sh) 아래에서 돌면
# 트레이스와 부모 스팬이 환경으로 넘어와, 케이스가 만드는 실행이 자기 트레이스를 갖지 못한다.
unset HARNESS_TRACE_ID HARNESS_PARENT_SPAN HARNESS_METRIC_SELF HARNESS_METRICS HARNESS_WORKFLOW

ok()   { pass=$((pass + 1)); }
bad()  { fail=$((fail + 1)); echo "  FAIL: $1" >&2; }
check(){ if [ "$2" = "$3" ]; then ok; else bad "$1 — expected '$3', actual '$2'"; fi; }
has()  { if grep -qF -- "$2" "$1"; then ok; else bad "$3"; fi; }
# 제자리 편집. BSD sed 는 `-i ''`, GNU sed 는 `-i` 만 받으므로 두 쪽이 같이 받는 `-i.bak` 을 쓰고 지운다.
sedi() { sed -i.bak "$1" "$2" && rm -f "$2.bak"; }
hasnt(){ if grep -qF -- "$2" "$1"; then bad "$3"; else ok; fi; }


records_under_work() { # records_under_work <리포> — 두 기록 경로가 $work 아래를 가리키는지 본다
  local md ul
  md=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["metrics"]["dir"])' "$1/script/harness.plan.json")
  case "$md" in "$work"/*) ok ;; *) bad "$1: the plan's metrics dir is outside \$work: $md" ;; esac
  ul=$(sed -n 's/^USAGE_LOG_PATH=//p' "$1/script/harness.env" | tr -d "\"'")
  case "$ul" in "$work"/*) ok ;; *) bad "$1: the usage log path is outside \$work: $ul" ;; esac
}

isolate_records() { # isolate_records <리포> — install 한 리포의 기록 경로를 테스트 작업 디렉터리로 옮긴다
  "$root/bin/harness" set --target "$1" metrics.dir "$1.records/metrics" usage.log_path "$1.records/usage.log" >/dev/null \
    || bad "$1: could not move the record paths"
  records_under_work "$1"
}

setup() {          # setup <대상> — 기본 설정으로 렌더한 대상 하나를 만든다
  rm -rf "$1"; mkdir -p "$1"
  cp "$root/templates/harness.toml" "$1/harness.toml"
  # 아래 케이스가 바꿔 보는 값을 **전부** 알려진 상태로 고정한다.
  #
  # 고정하지 않으면 기본값이 그 값과 같아지는 순간 치환이 아무것도 바꾸지 않고, 테스트는
  # 통과하면서 아무것도 검사하지 않는 상태가 된다 — 실패보다 나쁘다. 배포되는 기본값 자체는
  # UT-00 이 따로 본다.
  # 기록 경로(지표·사용 기록)는 대상 옆의 테스트 작업 디렉터리로 둔다 — 기본값은 실제 홈 아래다.
  python3 - "$1/harness.toml" "$1.records" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding="utf-8"); rec = sys.argv[2]
for pat, repl in [
    (r'^base = .*$',            'base = "development"'),
    (r'^protected = \[.*\]$',  'protected = ["main", "development"]'),
    (r'^issue_ref = .*$',       'issue_ref = "suffix"'),
    (r'^ticket_key = .*$',      'ticket_key = ""'),
    (r'^tracker = .*$',         'tracker = "gitlab"'),
    (r'^review_host = .*$',     'review_host = "gitlab"'),
    (r'^style = .*$',           'style = "nygard"'),
    (r'^tool = .*$',            'tool = "adr-tools"'),
    (r'^deletion_forbidden = .*$', 'deletion_forbidden = true'),
]:
    s = re.sub(pat, repl, s, count=1, flags=re.M)
# 같은 키 이름이 여러 절에 있으므로 절 안에서만 바꾼다.
def in_section(s, section, pat, repl):
    m = re.search(r'^\[' + re.escape(section) + r'\]\s*$', s, flags=re.M)
    if not m:
        sys.exit("setup: no [%s] section" % section)
    nxt = re.search(r'^\[', s[m.end():], flags=re.M)
    end = m.end() + (nxt.start() if nxt else len(s) - m.end())
    body, n = re.subn(pat, lambda _: repl, s[m.end():end], count=1, flags=re.M)
    if n != 1:
        sys.exit("setup: no match for %s in [%s]" % (pat, section))
    return s[:m.end()] + body + s[end:]
s = in_section(s, "adr", r'^dir = .*$', 'dir = "docs/adr"')
s = in_section(s, "metrics", r'^dir = .*$', 'dir = "%s/metrics"' % rec)
s = in_section(s, "usage", r'^log_path = .*$', 'log_path = "%s/usage.log"' % rec)
p.write_text(s, encoding="utf-8")
PY
  "$root/bin/harness" render --target "$1" >/dev/null
}

echo "UT-00 the shipped default config renders as-is"
# 기본값이 깨져 있으면 설치한 사람이 첫 명령에서 막힌다.
t="$work/shipped"; rm -rf "$t"; mkdir -p "$t"
cp "$root/templates/harness.toml" "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
check "default config render" "$?" "0"

echo "UT-01 renders with the default config and check passes"
t="$work/base"; setup "$t"
"$root/bin/harness" check --target "$t" >/dev/null; check "check exit code" "$?" "0"
sh -n "$t/script/githooks/commit-msg"; check "commit-msg syntax" "$?" "0"
sh -n "$t/script/githooks/pre-push";   check "pre-push syntax" "$?" "0"
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$t/.claude/settings.json"
check "settings.json parses" "$?" "0"
python3 -c "
import sys, tomllib, pathlib
for p in pathlib.Path(sys.argv[1]).glob('.codex/agents/*.toml'):
    tomllib.load(p.open('rb'))
" "$t"
check "codex toml parses" "$?" "0"

echo "UT-57 the test setup keeps its records under the test work directory"
# 기본 설정의 기록 경로는 실제 홈 아래다. 테스트가 만든 대상이 거기 쌓으면 안 된다.
t="$work/recpath"; setup "$t"
python3 - "$t/harness.toml" > "$work/recpath.out" <<'PY'
import sys, tomllib
c = tomllib.load(open(sys.argv[1], "rb"))
print(c["adr"]["dir"]); print(c["metrics"]["dir"]); print(c["usage"]["log_path"])
PY
check "the adr dir in the adr section" "$(sed -n 1p "$work/recpath.out")" "docs/adr"
[ "$(sed -n 2p "$work/recpath.out")" != "docs/adr" ] && ok || bad "the adr dir value landed in the metrics dir"
records_under_work "$t"

echo "UT-02 changing the commit subject format changes the pattern and the guidance together"
# 값 하나를 바꿨는데 한쪽만 따라오면 훅이 거부하며 보여 주는 예시가 통과하지 못하는 형식이 된다.
t="$work/prefix"; setup "$t"
python3 - "$t/harness.toml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('issue_ref = "suffix"', 'issue_ref = "prefix"')
s = s.replace('ticket_key = ""', 'ticket_key = "BD"')
open(p, 'w', encoding='utf-8').write(s)
PY
"$root/bin/harness" render --target "$t" >/dev/null
hook="$t/script/githooks/commit-msg"
has   "$hook" '^\[BD-[0-9]+\]'      "the pattern did not switch to the prefix form"
has   "$hook" '[BD-123] feat: short summary' "the guidance example did not switch to the prefix form"
hasnt "$hook" '(#{issue})'          "suffix-form wording is still in the guidance"

# 같은 값을 읽는 다른 소비자도 따라와야 한다
has "$t/script/harness.env" 'BD-' "the harness.env pattern did not follow"

echo "UT-03 changing protected branches changes the hook and the permission list together"
t="$work/branch"; setup "$t"
python3 - "$t/harness.toml" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('base = "development"', 'base = "develop"')
s = s.replace('protected = ["main", "development"]', 'protected = ["trunk", "develop"]')
open(p, 'w', encoding='utf-8').write(s)
PY
"$root/bin/harness" render --target "$t" >/dev/null
has   "$t/script/githooks/pre-push" 'refs/heads/trunk|refs/heads/develop' "pre-push did not follow"
hasnt "$t/script/githooks/pre-push" 'refs/heads/main'                     "an old branch is still in pre-push"
has   "$t/.claude/settings.json"    'git push origin develop'             "the deny list did not follow"
hasnt "$t/.claude/settings.json"    'git push origin development)'        "an old branch is still in the deny list"
has   "$t/script/githooks/pre-push" 'onto develop instead'                 "the refusal message did not follow"

echo "UT-04 check catches a generated file edited by hand"
t="$work/edited"; setup "$t"
echo "# 사람이 끼워 넣은 줄" >> "$t/script/githooks/commit-msg"
out=$("$root/bin/harness" check --target "$t" 2>&1); rc=$?
check "check exit code" "$rc" "1"
case "$out" in *commit-msg*) ok ;; *) bad "did not name the file that drifted" ;; esac

echo "UT-05 check catches a missing generated file"
rm "$t/.claude/settings.json"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check exit code" "$?" "1"

echo "UT-59 check and doctor see the same drift"
t="$work/drift"; setup "$t"
"$root/bin/harness" doctor --target "$t" >"$work/drift-ok.log" 2>&1
has "$work/drift-ok.log" "files match the config" "doctor right after render does not report a match"
echo "# hand edit" >> "$t/AGENTS.md"
rm "$t/.claude/settings.json"
"$root/bin/harness" check --target "$t" >"$work/drift-check.log" 2>&1; check "check exit code on drift" "$?" "1"
grep -E '^  AGENTS.md +differs from the config$' "$work/drift-check.log" >/dev/null && ok || bad "check did not name the edited file with its reason"
grep -E '^  .claude/settings.json +missing$' "$work/drift-check.log" >/dev/null && ok || bad "check did not name the deleted file with its reason"
"$root/bin/harness" doctor --target "$t" >"$work/drift-doc.log" 2>&1
has "$work/drift-doc.log" "2 files differ from the config" "doctor does not count the same two files"

echo "UT-06 render refuses when the implementer and the reviewer share a runner"
# 같은 모델이 자기 코드를 리뷰하면 같은 맹점을 두 번 지나간다. 문서가 아니라 도구가 막아야 한다.
t="$work/samerunner"; setup "$t"
python3 - "$t/harness.toml" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('[roles.code-reviewer]\nrunner = "codex"', '[roles.code-reviewer]\nrunner = "claude"')
open(p, 'w', encoding='utf-8').write(s)
PY
out=$("$root/bin/harness" render --target "$t" 2>&1); rc=$?
check "render exit code" "$rc" "2"
case "$out" in *distinct_reviewer*) ok ;; *) bad "the refusal does not say how to lift it" ;; esac

echo "UT-07 a config that breaks the rules is refused before render"
# 티켓 접두사형인데 키가 없으면 검사식을 만들 수 없다.
t="$work/invalid"; setup "$t"
sedi 's/issue_ref = "suffix"/issue_ref = "prefix"/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "prefix form without a ticket key" "$?" "2"
sedi 's/^runner = "codex"$/runner = "unknown-runner"/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "unknown runner" "$?" "2"

echo "UT-07d a branch list written as one comma-joined string is refused"
# 브랜치 이름은 훅의 case 패턴에 그대로 들어가므로, 쉼표·공백이 섞이면 훅이 문법 오류로 깨진다.
t="$work/branchname"; setup "$t"
sedi 's/^protected = \["main", "development"\]$/protected = ["main, development"]/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "comma-joined branch list" "$?" "2"

echo "UT-07b the integration branch is protected even when it is not listed"
# 거기로 직접 push 할 수 있으면 승인 게이트가 우회된다. 선택지가 아니므로 채운다.
t="$work/autoprotect"; setup "$t"
sedi 's/^protected = \["main", "development"\]$/protected = ["main"]/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
check "render exit code" "$?" "0"
has "$t/script/githooks/pre-push" "refs/heads/development" "the integration branch did not reach the hook"
has "$t/.claude/settings.json"    "git push origin development" "the integration branch is not in the permission list"

echo "UT-07c the harness source tree runs on itself and never vendors a copy of itself"
# 소스 리포 루트의 harness.toml 은 그 리포 자신의 설정이다 — 기본값은 templates/harness.toml 에 있다.
# 사본을 고정하면 템플릿을 고칠 때마다 두 곳이 어긋나므로 소스 리포는 자기 src/bin/harness 로 돈다.
# 이 리포 자신을 건드리지 않게 소스 트리를 임시 디렉터리에 복제해서 본다.
src="$work/source"; rm -rf "$src"; mkdir -p "$src/src/bin"
cp "$root/bin/harness" "$root/bin/harness_metrics.py" "$src/src/bin/"; cp -R "$root/templates" "$src/src/templates"
( cd "$src" && git init -q . )
"$src/src/bin/harness" install --target "$src" >/dev/null 2>&1; check "install on the source tree" "$?" "0"
[ -e "$src/.harness/bin" ] && bad "the source tree vendored a copy of itself" || ok
[ -f "$src/.ai/AI_AGENT.md" ] && ok || bad "the source tree did not render"
has "$src/harness.toml" 'name = "source"' "the seeded config is not the source tree's own"
[ -f "$HARNESS_HOME/source/project.json" ] && ok || bad "the source tree was not registered"
"$src/src/bin/harness" check --target "$src" >/dev/null 2>&1; check "check on the source tree" "$?" "0"
"$src/src/bin/harness" metrics --target "$src" >"$work/source-metrics.out" 2>&1; check "metrics on the source tree" "$?" "0"
[ -e "$src/src/bin/__pycache__" ] && bad "the metrics module left bytecode in src/bin" || ok
# 다른 CLI(여기서는 $root 의 것)로 불러도 소스 리포 자신의 템플릿으로 돈다 — 템플릿을 바꿔 두면 드러난다.
printf '\n<!-- source tree only -->\n' >> "$src/src/templates/generated/AGENTS.md"
"$src/src/bin/harness" render --target "$src" >/dev/null
"$root/bin/harness" check --target "$src" >/dev/null 2>&1
check "a foreign CLI delegates to the source tree's own src/bin/harness" "$?" "0"


echo "UT-08 an update does not overwrite owned files"
# 프로젝트가 쓴 사실을 하네스 갱신이 지우면 사람이 같은 것을 다시 쓴다.
t="$work/owned"; setup "$t"
printf '\n- 이 프로젝트가 직접 쓴 줄\n' >> "$t/.ai/project/scope.md"
"$root/bin/harness" render --target "$t" >/dev/null
has "$t/.ai/project/scope.md" "이 프로젝트가 직접 쓴 줄" "the owned file was overwritten"

echo "UT-09 editing an owned file updates the rule canon, and check blocks until it does"
# 규칙 정본이 소유 파일 본문을 담아 생성되므로, render 를 잊으면 둘이 어긋난다.
printf -- '- 아직 render 하지 않은 줄\n' >> "$t/.ai/project/scope.md"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check before render" "$?" "1"
"$root/bin/harness" render --target "$t" >/dev/null
has "$t/.ai/AI_AGENT.md" "아직 render 하지 않은 줄" "the rule canon does not carry the owned file"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after render" "$?" "0"

echo "UT-09b an owned file may carry template syntax — it is prose, not a harness variable"
# 템플릿 엔진을 쓰는 프로젝트(그리고 이 하네스 자신)는 사실 문서에 {{VAR}} 같은 표기를 적는다.
# 그것을 하네스 변수로 읽으면 사실 문서 한 줄이 render 를 막는다.
printf -- '- 뷰는 {{VAR}} 표기로 값을 받는다\n' >> "$t/.ai/project/scope.md"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "render with template syntax in an owned file" "$?" "0"
has "$t/.ai/AI_AGENT.md" "{{VAR}} 표기" "the owned file's template syntax did not survive as prose"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after that render" "$?" "0"
# 소유 파일 머리의 안내 주석은 규칙 정본에 들어가지 않는다 — 에이전트가 읽는 근거의 소음이다.
hasnt "$t/.ai/AI_AGENT.md" "이 파일은 프로젝트가 소유한다" "the owned file's guidance comment leaked into the canon"

echo "UT-10 an update overwrites managed files"
# 하네스 것이므로 로컬 수정이 남으면 다음 버전의 개선이 오지 않는다.
t="$work/managed"; setup "$t"
printf '\n사람이 끼워 넣은 줄\n' >> "$t/.ai/templates/developer.md"
"$root/bin/harness" render --target "$t" >/dev/null
hasnt "$t/.ai/templates/developer.md" "사람이 끼워 넣은 줄" "the managed file was not overwritten"

echo "UT-11 changing the forge changes the adapter choice and the command glossary together"
t="$work/forge"; setup "$t"
sedi 's/tracker = "gitlab"/tracker = "github"/; s/review_host = "gitlab"/review_host = "github"/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null
has   "$t/script/forge.sh" "script/forge/github.sh" "the adapter choice did not follow"
hasnt "$t/script/forge.sh" "script/forge/gitlab.sh" "the old adapter is still there"
has   "$t/.ai/forge.md"   "gh pr view"              "the command glossary did not follow"
hasnt "$t/.ai/forge.md"   "glab mr view"            "an old command is still in the glossary"
# 두 어댑터 파일은 둘 다 깔려 있다 — 고르는 것은 생성된 진입점이다
has "$t/script/forge/gitlab.sh" "GITLAB_CLI" "the adapter implementation is missing"

echo "UT-12 changing the ADR style switches the doc set and the old one disappears"
# 설정이 더는 만들지 않는 파일이 남으면 어느 쪽이 현재인지 알 수 없다.
t="$work/adr"; setup "$t"
[ -f "$t/docs/adr/README.md" ] && ok || bad "the nygard doc set is missing"
[ -f "$t/.adr-dir" ] && ok || bad "the adr-tools target file is missing"
sedi 's/style = "nygard"/style = "madr"/; s/tool = "adr-tools"/tool = "manual"/; s|dir = "docs/adr"|dir = "docs/decisions"|' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null
[ -f "$t/docs/decisions/README.md" ] && ok || bad "the madr doc set was not created"
[ -e "$t/docs/adr" ] && bad "docs from the old style are still there" || ok
[ -e "$t/.adr-dir" ] && bad "config for an unused tool is still there" || ok
has "$t/.ai/adr.md" "front matter" "the decision-record glossary did not follow the style"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after the switch" "$?" "0"

echo "UT-13 render refuses a style and tool combination that cannot hold"
# adr-tools 는 상태와 대체 표기를 Nygard 절 구조에서 찾는다. MADR 에 쓰면 조용히 아무 일도 안 한다.
t="$work/adrbad"; setup "$t"
sedi 's/^style = .*/style = "madr"/; s/^tool = .*/tool = "adr-tools"/' "$t/harness.toml"
out=$("$root/bin/harness" render --target "$t" 2>&1); rc=$?
check "render exit code" "$rc" "2"
case "$out" in *madr*) ok ;; *) bad "the refusal does not say the combination is the problem" ;; esac

echo "UT-14 the generated file list covers rules, gateways and adapters"
# 하나라도 빠지면 그 파일만 설정과 무관하게 손으로 관리된다.
t="$work/coverage"; setup "$t"
for f in .ai/AI_AGENT.md .ai/forge.md .ai/adr.md CLAUDE.md AGENTS.md \
         .claude/settings.json .claude/agents/developer.md .codex/agents/developer.toml \
         script/harness.env script/forge.sh \
         script/githooks/commit-msg script/githooks/pre-push script/githooks/pre-commit; do
  [ -f "$t/$f" ] && ok || bad "not generated: $f"
done

echo "UT-15 every managed script's regression test passes in an installed repo"
# 여기까지가 실제 사용 경로다 — 설치하고, 훅을 켜고, 검증을 돌린다.
t="$work/installed"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null
isolate_records "$t"
# 목록을 적지 않고 설치된 것을 센다 — 적어 두면 새 테스트가 여기서 빠진 채 지나간다.
for f in "$t"/script/test-*.sh; do
  s=$(basename "$f" .sh)
  if ( cd "$t" && "./script/$s.sh" >"$work/$s.log" 2>&1 ); then
    ok
  else
    bad "$s failed — $work/$s.log"
    tail -5 "$work/$s.log" >&2
  fi
done
# 프로젝트 명령을 정하기 전이므로 검증 일괄은 실패한다. 그 사실 자체가 신호다.
( cd "$t" && ./script/run-lint-test.sh >"$work/lint.log" 2>&1 )
check "verification bundle right after install" "$?" "1"
has "$work/lint.log" "verify: not set up" "the failure is not about unset project commands"
ls "$t.records/metrics"/spans-*.jsonl >/dev/null 2>&1 && ok || bad "the verification bundle left no spans under the isolated metrics dir"

echo "UT-61 regression tests run from a linked worktree's hook leave that worktree's repo alone"
# 링크된 워크트리의 훅은 GIT_DIR·GIT_INDEX_FILE 을 절대 경로로 넘긴다. 그 값을 물려받은 채
# 임시 리포를 만들면 임시 디렉터리 대신 그 리포가 다시 초기화된다.
victim="$work/victim"; rm -rf "$victim" "$victim-wt"; mkdir -p "$victim"
( cd "$victim" && git init -q . && git -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init \
    && git worktree add -q -b side "$victim-wt" ) || bad "could not set up the linked worktree"
wt_gitdir=$(git -C "$victim-wt" rev-parse --absolute-git-dir)
branches_before=$(git -C "$victim" branch --format='%(refname:short)' | sort)
for f in "$t"/script/test-*.sh; do
  s=$(basename "$f" .sh)
  ( cd "$t" && GIT_DIR="$wt_gitdir" GIT_INDEX_FILE="$wt_gitdir/index" "./script/$s.sh" >"$work/$s.hookenv.log" 2>&1 ) \
    || bad "$s failed under a linked worktree's hook environment — $work/$s.hookenv.log"
  check "$s: core.bare of the worktree's repo" "$(git -C "$victim" config core.bare)" "false"
  check "$s: branches of the worktree's repo" "$(git -C "$victim" branch --format='%(refname:short)' | sort)" "$branches_before"
done

echo "UT-58 the installed CLI carries its metrics module and leaves no bytecode"
[ -f "$t/.harness/bin/harness_metrics.py" ] && ok || bad "install did not vendor the metrics module"
python3 "$t/.harness/bin/harness" metrics --target "$t" >"$work/installed-metrics.out" 2>&1
check "metrics in an installed repo" "$?" "0"
has "$work/installed-metrics.out" '"summary"' "the installed metrics command printed no report"
[ -e "$t/.harness/bin/__pycache__" ] && bad "the metrics module left bytecode in .harness/bin" || ok

echo "UT-16 the forge self-test tells contract compliance apart"
# 자체 검사는 실제 forge 를 상대로 도는 도구라 그 자신은 검사되지 않는다.
# 계약을 지키는 페이크를 통과시키고 어기는 페이크를 잡아야 판정을 믿을 수 있다.
t="$work/selftest"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null
cp "$root/test/fake-forge.sh" "$t/script/forge.sh"
fstate="$work/fake-state"; mkdir -p "$fstate"

run_selftest() { # <FAKE_BREAK> <인수...>
  local brk=$1; shift
  rm -f "$fstate/labels" "$fstate/notes.json"
  ( cd "$t" && FAKE_STATE="$fstate" FAKE_BREAK="$brk" \
      ./script/forge-selftest.sh "$@" >"$work/selftest.log" 2>&1 )
  echo $?
}

check "read-only passes when the contract holds" "$(run_selftest '' 1 100)" "0"
has "$work/selftest.log" "skip" "read-only, but it did not report skipping the writes"
check "writes pass when the contract holds" "$(run_selftest '' --write 1 100)" "0"
check "issue creation passes when the contract holds" "$(run_selftest '' --create-issue 1 100)" "0"
hasnt "$work/selftest.log" "skip  " "ran every item, yet something was skipped"

# 계약을 어기는 아홉 가지를 각각 잡아야 한다. 하나라도 통과로 지나가면 "검증됨" 이 거짓이 된다.
for brk in mr_view threads thread_id issue_list open_mrs; do
  check "catches a contract violation: $brk" "$(run_selftest "$brk" 1 100)" "1"
done
for brk in inline_any reply_any reply_new; do
  check "catches a contract violation: $brk" "$(run_selftest "$brk" --write 1 100)" "1"
done
check "catches a contract violation: create_url" "$(run_selftest create_url --create-issue 1 100)" "1"

# 인수를 잘못 주면 돌지 않는다 — 대상 없이 돌면 엉뚱한 리뷰 요청에 흔적이 남는다.
check "does not run without a target" "$(run_selftest '' )" "2"
check "does not run in create mode without an issue" "$(run_selftest '' --create-issue 1)" "2"

echo "UT-17 the rule prose does not state config values as fact"
# 설정에 있는 값을 산문에 박아 두면 그 값을 바꾼 프로젝트에서 규칙이 거짓말을 한다.
t="$work/prose"; setup "$t"
has "$t/.ai/AI_AGENT.md" "이슈 삭제를 **금지**한다" "the deletion ban rule was not rendered"
sedi 's/deletion_forbidden = true/deletion_forbidden = false/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null
hasnt "$t/.ai/AI_AGENT.md" "이슈 삭제를 **금지**한다" "deletion is allowed, yet the ban rule is still there"
has   "$t/.ai/AI_AGENT.md" "지울 수 있다"             "the allowing sentence did not appear"

echo "UT-18 every owned file has a reader"
# 아무도 읽지 않는 문서는 채워 달라고 할 근거가 없다.
t="$work/readers"; setup "$t"
for f in scope glossary stack architecture testing environment review-checks; do
  # 규칙 정본이 본문을 담거나(포함), 계약·문서 지도가 경로로 가리키거나 둘 중 하나여야 한다.
  if grep -rqF ".ai/project/$f.md" "$t/.ai/AI_AGENT.md" "$t/.ai/templates" 2>/dev/null; then
    ok
  elif grep -qF "{{INCLUDE:.ai/project/$f.md}}" "$root/templates/generated/.ai/AI_AGENT.md"; then
    ok
  else
    bad "owned file nobody reads: .ai/project/$f.md"
  fi
done

echo "UT-19 uninstall removes only what the harness installed"
# 프로젝트가 쓴 산문과 작업 산출물을 지우면 되돌릴 수 없다.
t="$work/rm"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . && git config core.hooksPath script/githooks )
"$root/bin/harness" install --target "$t" >/dev/null
printf '내가 쓴 담당 범위\n' >> "$t/.ai/project/scope.md"
mkdir -p "$t/docs/spec" && echo "명세" > "$t/docs/spec/12-foo.md"
"$root/bin/harness" uninstall --target "$t" >/dev/null
check "uninstall exit code" "$?" "0"
[ -e "$t/.harness" ]        && bad "the harness copy is still there"  || ok
[ -e "$t/script/review-mr.sh" ] && bad "a managed file is still there"    || ok
[ -e "$t/.ai/AI_AGENT.md" ] && bad "a generated file is still there"   || ok
has "$t/.ai/project/scope.md" "내가 쓴 담당 범위" "prose the project wrote was deleted"
has "$t/docs/spec/12-foo.md"  "명세"              "work output was deleted"
[ -f "$t/harness.toml" ]    && ok || bad "the config was deleted"
[ -f "$t/docs/spec/README.md" ] && ok || bad "an owned file was deleted"
# 훅이 사라진 디렉터리를 가리키면 커밋할 때마다 git 이 실패한다.
check "hooks setting cleared" "$( cd "$t" && git config core.hooksPath || echo '(none)' )" "(none)"

echo "UT-20 --purge names what it removes and stops without a confirmation"
# 되돌릴 수 없는 유일한 명령이다. 목록을 보이지 않거나 묻지 않고 지우면 사람이 쓴 산문이 사라진다.
t="$work/purge"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null
mkdir -p "$t/docs/spec" && echo "명세" > "$t/docs/spec/12-foo.md"
"$root/bin/harness" uninstall --target "$t" --purge >"$work/purge.log" 2>&1
check "unconfirmed --purge exit code" "$?" "2"
[ -f "$t/harness.toml" ] && ok || bad "unconfirmed --purge deleted the config"
[ -f "$t/.ai/project/scope.md" ] && ok || bad "unconfirmed --purge deleted an owned file"
has "$work/purge.log" "harness.toml"              "the preview does not name the config"
has "$work/purge.log" ".ai/project/scope.md"      "the preview does not name the owned files"
has "$work/purge.log" "docs/spec"                 "the preview does not name the untouched work output"
has "$work/purge.log" ".harness/"                 "the preview does not name the vendored copy"

echo "UT-20b --purge with --yes removes owned files and the config but keeps work output"
"$root/bin/harness" uninstall --target "$t" --purge --yes >/dev/null
[ -e "$t/.ai" ]          && bad "owned files are still there"  || ok
[ -e "$t/harness.toml" ] && bad "the config is still there"    || ok
has "$t/docs/spec/12-foo.md" "명세" "--purge deleted work output too"

echo "UT-21 uninstall does not run where nothing was installed"
t="$work/never"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" uninstall --target "$t" >/dev/null 2>&1
check "exit code" "$?" "2"

echo "UT-22 a one-line config change flows into the output, and one that cannot hold is rolled back"
t="$work/set"; setup "$t"
"$root/bin/harness" set --target "$t" branches.base develop >/dev/null
check "set exit code" "$?" "0"
has "$t/script/githooks/pre-push" "refs/heads/develop" "the changed value did not reach the output"
before=$(grep -c 'issue_ref' "$t/harness.toml")
"$root/bin/harness" set --target "$t" commit.issue_ref prefix >/dev/null 2>&1
check "exit code for a value that cannot hold" "$?" "2"
has "$t/harness.toml" 'issue_ref = "suffix"' "a value that cannot hold was not rolled back"
"$root/bin/harness" set --target "$t" nosuch.key x >/dev/null 2>&1
check "exit code for an unknown key" "$?" "2"

echo "UT-23 help and doctor run"
"$root/bin/harness" help >"$work/help.log" 2>&1; check "help exit code" "$?" "0"
for c in install render check doctor set run vars uninstall help; do
  has "$work/help.log" "harness $c" "help does not list $c"
done
t="$work/doc"; setup "$t"
"$root/bin/harness" doctor --target "$t" >"$work/doctor.log" 2>&1
check "doctor exit code right after setup" "$?" "1"
has "$work/doctor.log" "placeholder" "did not report the places left to fill"
has "$work/doctor.log" "git hooks"   "did not report the hook state"

echo "UT-24 running a workflow launches the orchestrator interactively"
# 승인 게이트가 있으므로 비대화형으로 돌리면 그 지점이 통과된 것처럼 지나간다.
t="$work/run"; setup "$t"
# 실행 기기에 오케스트레이터가 없어도 돌도록 가짜를 PATH 앞에 둔다. --dry-run 도 설치 여부는 확인한다.
orch24="$work/orch24"; mkdir -p "$orch24"; printf '#!/bin/sh\nexit 0\n' > "$orch24/claude"; chmod +x "$orch24/claude"
out=$(PATH="$orch24:$PATH" "$root/bin/harness" run --target "$t" work 12 --dry-run 2>&1)
check "run exit code" "$?" "0"
case "$out" in *claude*"/work 12"*) ok ;; *) bad "the command to launch is not what is expected: $out" ;; esac
case "$out" in *-p*|*--print*) bad "launches non-interactively — the approval gate is skipped" ;; *) ok ;; esac
"$root/bin/harness" set --target "$t" harness.model opus >/dev/null 2>&1
out=$(PATH="$orch24:$PATH" "$root/bin/harness" run --target "$t" work 12 --dry-run 2>&1)
case "$out" in *"claude --model opus"*) ok ;; *) bad "the orchestrator model is not passed at launch: $out" ;; esac
"$root/bin/harness" run --target "$t" nosuch 12 --dry-run >/dev/null 2>&1
check "exit code for an unknown workflow" "$?" "2"

echo "UT-25 templates are found even when run through a symlink"
# Homebrew 는 트리를 libexec 에 넣고 bin 에 링크만 건다. 링크를 타고도 옆의 템플릿을
# 찾아야 전역 설치가 성립한다.
keg="$work/keg"; rm -rf "$keg"; mkdir -p "$keg/libexec" "$keg/bin"
cp -R "$root/bin" "$root/templates" "$root/harness.toml" "$keg/libexec/"
ln -s "$keg/libexec/bin/harness" "$keg/bin/harness"
t="$work/keg-target"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$keg/bin/harness" install --target "$t" >/dev/null 2>&1
check "install through the link" "$?" "0"
"$keg/bin/harness" check --target "$t" >/dev/null 2>&1
check "check through the link" "$?" "0"

echo "UT-26 a version pinned in the project wins over the global one"
# 전역을 올릴 때마다 모든 프로젝트의 생성물이 바뀌면 그 리포의 검사가 한꺼번에 깨진다.
echo "0.0.9" > "$t/.harness/VERSION"
out=$("$keg/bin/harness" check --target "$t" 2>&1)
case "$out" in *0.0.9*) ok ;; *) bad "did not report that it defers to the pinned version" ;; esac
# 넘긴 뒤에도 실제로 돌아야 한다
case "$out" in *"match the config"*) ok ;; *) bad "check did not run after deferring: $out" ;; esac
# install 은 넘기지 않는다 — 고정된 사본을 갈아 끼우는 것이 그 명령의 일이다
"$keg/bin/harness" install --target "$t" >/dev/null 2>&1
check "pinned version after install" "$(cat "$t/.harness/VERSION")" "0.1.0"

echo "UT-27 the decision-record procedure follows the tool setting"
# 도구를 바꿨는데 절차가 그대로면 없는 명령을 지시한다.
t="$work/adrtool"; setup "$t"
sedi 's/^tool = .*/tool = "manual"/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null
has   "$t/.ai/adr.md" "도구를 쓰지 않는다" "manual, yet there is no by-hand procedure"
hasnt "$t/.ai/adr.md" "adr new"            "manual, yet it prescribes a command that does not exist"
[ -e "$t/.adr-dir" ] && bad "no tool in use, yet a tool config file appeared" || ok
"$root/bin/harness" set --target "$t" adr.tool adr-tools >/dev/null
has "$t/.ai/adr.md" 'adr new -s'  "adr-tools, yet there is no supersede command"
[ -f "$t/.adr-dir" ] && ok || bad "adr-tools, yet the tool config file is missing"

echo "UT-28 no Korean leaks into CLI output"
# 규칙은 문서·커밋은 한국어, 로그 메시지는 영어다. 새 메시지를 한국어로 적으면 여기서 걸린다.
# 생성 파일로 들어가는 문자열은 문서 내용이므로 대상이 아니다.
t="$work/lang"; setup "$t"
{ "$root/bin/harness" help
  "$root/bin/harness" version --target "$t"
  "$root/bin/harness" check --target "$t"
  "$root/bin/harness" doctor --target "$t"
  "$root/bin/harness" render --target "$root"
  "$root/bin/harness" set --target "$t" nosuch.key x
  "$root/bin/harness" run --target "$t" nosuch 1
  "$root/bin/harness" uninstall --target "$work/never"
  "$root/bin/harness" uninstall --target "$t" --purge
} > "$work/lang.log" 2>&1
# grep 은 한글 범위를 이식 가능하게 못 찾는다 — BSD 에 -P 가 없어 오류로 빠지면 검사가 통과해 버린다.
python3 - "$work/lang.log" > "$work/lang.hits" <<'HANGUL'
import re, sys
for n, line in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
    if re.search(r"[가-힣]", line):
        print(f"{n}: {line.rstrip()}")
HANGUL
if [ -s "$work/lang.hits" ]; then
  bad "Korean is still in CLI output"
  head -3 "$work/lang.hits" >&2
else
  ok
fi

echo "UT-29 doctor finds broken references"
# 손으로 돌리던 grep 을 명령이 대신한다. 통과만 하는 검사는 없는 것과 같으므로,
# 깨뜨린 상태를 실제로 만들어 잡히는지 본다.
t="$work/refs"; setup "$t"
"$root/bin/harness" doctor --target "$t" > "$work/ref-clean.log" 2>&1 || true
has "$work/ref-clean.log" "every role reference resolves" "a clean install, yet it faults a role reference"
has "$work/ref-clean.log" "every path a document names exists" "a clean install, yet it reports a missing file"

python3 - "$t/harness.toml" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
p.write_text(re.sub(r'\[roles\.docs-writer\][^\[]*', '', p.read_text(encoding="utf-8")), encoding="utf-8")
PY
"$root/bin/harness" render --target "$t" >/dev/null
[ -f "$t/.ai/templates/docs-writer.md" ] && bad "the contract for an unused role is still there" || ok
hasnt "$t/CLAUDE.md" "agents/docs-writer.md" "the asset table still points at the removed role"
{ echo "docs-writer 가 여기서 돈다."; echo '`docs/nope/missing.md` 를 본다.'; } >> "$t/.ai/project/scope.md"
"$root/bin/harness" render --target "$t" >/dev/null
"$root/bin/harness" doctor --target "$t" > "$work/ref-bad.log" 2>&1 || true
has "$work/ref-bad.log" "role \`docs-writer\` is not in harness.toml" "did not find the place that calls the removed role"
has "$work/ref-bad.log" "\`docs/nope/missing.md\` does not exist"   "did not find the reference to a missing file"
hasnt "$work/ref-bad.log" "settings.local.json"                     "faulted a file that is normally absent"

echo "UT-34 the pre-commit hook blocks a credential from being committed"
# 층이 실제로 서 있는지는 훅을 돌려 봐야 안다. 스크립트만 있고 훅이 부르지 않으면 층이 없다.
t="$work/secret"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null
isolate_records "$t"
# 훅은 생성물 일치도 본다. 하네스를 먼저 커밋해 두어야 시크릿 층까지 도달한다.
gitq() { git -C "$t" -c user.name=t -c user.email=t@example.invalid "$@"; }
gitq add -A >/dev/null && gitq commit -q -m "chore: 하네스" >/dev/null
# 표본 값을 이 파일에 문자열로 적지 않는다 — 적으면 이 리포의 스캔이 이 줄에 걸린다.
( cd "$t" && printf 'aws = "%s%s"\n' AKIA IOSFODNN7EXAMPLE > leak.txt )
gitq add leak.txt >/dev/null
( cd "$t" && script/githooks/pre-commit >"$work/hook.log" 2>&1 )
check "pre-commit blocks" "$?" "1"
has "$work/hook.log" "possible credential" "the hook did not run the secret scan"
# 표지를 달면 지나간다 — 오탐에 막히는 사람이 --no-verify 로 가지 않게 하는 탈출구다.
( cd "$t" && printf 'aws = "%s%s"  # harness:allow-secret\n' AKIA IOSFODNN7EXAMPLE > leak.txt )
gitq add leak.txt >/dev/null
( cd "$t" && script/githooks/pre-commit >"$work/hook2.log" 2>&1 )
check "a marked line passes" "$?" "0"

echo "UT-33 Jira can track issues but cannot host review"
# 트래커와 리뷰 호스트를 따로 고를 수 있다는 것이 forge 분리의 요점이다.
t="$work/jira"; setup "$t"
"$root/bin/harness" set --target "$t" commit.ticket_key BD >/dev/null
"$root/bin/harness" set --target "$t" commit.issue_ref prefix >/dev/null
"$root/bin/harness" set --target "$t" forge.tracker jira >/dev/null
check "jira as tracker" "$?" "0"
has "$t/script/forge.sh" "forge/jira.sh"  "the dispatcher does not source the Jira adapter"
has "$t/.ai/forge.md"   "jira issue view" "the command glossary does not carry the Jira commands"
has "$t/.ai/forge.md"   "BD-12"           "the glossary does not use the project ticket key"
"$root/bin/harness" set --target "$t" forge.review_host jira >"$work/jira-rh.log" 2>&1
check "jira as review host is refused" "$?" "2"
has "$work/jira-rh.log" "does not host code review" "the refusal does not say why"
has "$t/harness.toml"   'review_host = "gitlab"'   "the refused value was not rolled back"
# 정규화는 어댑터의 실제 로직이다. 자격증명 없이 도는 유일한 부분이라 여기서 본다.
cat > "$work/jira-raw.json" <<'JSON'
{"total":2,"issues":[
 {"key":"BD-12","fields":{"summary":"feat: 골격",
  "status":{"name":"진행 중","statusCategory":{"key":"indeterminate"}},
  "description":{"type":"doc","content":[{"type":"paragraph","content":[
    {"type":"text","text":"첫 줄"},{"type":"hardBreak"},{"type":"text","text":"둘째 줄"}]}]},
  "labels":["Task"],"assignee":{"displayName":"담당자"},"fixVersions":[{"name":"M1"}]}},
 {"key":"BD-13","fields":{"summary":"fix: 밀림",
  "status":{"name":"완료","statusCategory":{"key":"done"}},
  "description":"평문 본문","labels":[],"assignee":null,"fixVersions":[]}}]}
JSON
( _FORGE_WANT_TRACKER=1; _FORGE_WANT_REVIEW=0
  . "$t/script/forge/jira.sh"
  python3 -c "$_jira_norm_issue" < "$work/jira-raw.json" ) > "$work/jira-norm.json" 2>&1
has "$work/jira-norm.json" '"iid": "BD-12"'   "the issue key did not become the identifier"
has "$work/jira-norm.json" '"state": "opened"' "an in-progress issue was not read as open"
has "$work/jira-norm.json" '"state": "closed"' "a done issue was not read as closed"
has "$work/jira-norm.json" '첫 줄\n둘째 줄'    "the rich-text body was not flattened"
has "$work/jira-norm.json" '"milestone": "M1"' "fixVersions did not become the milestone"

echo "UT-32 dropping a role drops its contract, its adapter and its command together"
# 손으로 적은 표는 역할을 지운 뒤에도 남아 만들어지지 않은 파일을 가리킨다.
t="$work/role"; setup "$t"
[ -f "$t/.claude/commands/security-guard.md" ] && ok || bad "the role's command was not installed"
has "$t/CLAUDE.md" "/security-guard" "the asset table does not list the command"
python3 - "$t/harness.toml" <<'DROP'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
p.write_text(re.sub(r"\n\[roles\.security-guard\][^\[]*", "\n", p.read_text(encoding="utf-8")),
             encoding="utf-8")
DROP
"$root/bin/harness" render --target "$t" >/dev/null
[ -e "$t/.claude/agents/security-guard.md" ]   && bad "the adapter survived the role removal"  || ok
[ -e "$t/.ai/templates/security-guard.md" ]    && bad "the contract survived the role removal" || ok
[ -e "$t/.claude/commands/security-guard.md" ] && bad "the command survived the role removal"  || ok
hasnt "$t/CLAUDE.md" "/security-guard" "the asset table still points at a file that is gone"

echo "UT-31 CI is seeded once and never overwritten"
# CI 는 방어층의 마지막 칸이다. 깔지 않으면 층 표가 거짓이 되고, 덮으면 설치 한 번에 빌드가 바뀐다.
t="$work/ci"; setup "$t"
[ -f "$t/.gitlab-ci.yml" ] && ok || bad "no CI config was seeded for the configured review host"
has "$t/.gitlab-ci.yml" "run-lint-test.sh" "the CI config does not run the verification bundle"
has "$t/.gitlab-ci.yml" "development"      "the CI config does not follow the integration branch"
printf 'MY OWN PIPELINE\n' > "$t/.gitlab-ci.yml"
"$root/bin/harness" render --target "$t" >/dev/null
has "$t/.gitlab-ci.yml" "MY OWN PIPELINE" "render overwrote a pipeline the project owns"
"$root/bin/harness" uninstall --target "$t" --purge --yes >/dev/null
[ -f "$t/.gitlab-ci.yml" ] && ok || bad "--purge deleted the CI config"
# 리뷰 호스트가 GitHub 이면 GitHub Actions 쪽이 깔린다.
t="$work/ci-gh"; rm -rf "$t"; mkdir -p "$t"; cp "$root/templates/harness.toml" "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null
[ -f "$t/.github/workflows/harness-verify.yml" ] && ok || bad "no GitHub workflow was seeded"
has "$t/.github/workflows/harness-verify.yml" "run-lint-test.sh" "the workflow does not run the verification bundle"

echo "UT-30 a harness installed below the repo root keeps to its own subtree"
# 모노레포: 서브프로젝트마다 하네스가 따로 선다. 스크립트가 git 루트로 올라가면 남의 것을 본다.
t="$work/mono"; rm -rf "$t"; mkdir -p "$t/packages/api" "$t/packages/web"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t/packages/api" >/dev/null
[ -f "$t/packages/api/script/harness.env" ] && ok || bad "the harness did not land in the subdirectory"
[ -e "$t/script" ]              && bad "the harness leaked into the repo root"  || ok
[ -e "$t/packages/web/script" ] && bad "the harness leaked into a sibling"      || ok
# 리포 루트에서 불러도 자기 루트를 잡는다 — git 루트로 올라가면 설정을 찾지 못하고 죽는다.
( cd "$t" && packages/api/script/test-carryover-issue.sh >"$work/mono.log" 2>&1 )
check "managed test called from the repo root" "$?" "0"
( cd "$t/packages/api" && ./script/test-sync-task-issues.sh >"$work/mono2.log" 2>&1 )
check "managed test called from the subproject" "$?" "0"
# 훅도 자기 서브프로젝트를 봐야 한다.
has "$t/packages/api/script/githooks/pre-commit" 'dirname -- "$0"' "the hook still resolves through git"

echo "UT-35 workflow steps are the config: reorder, insert, and dangling references are refused"
t="$work/steps"; setup "$t"
# 기본 단계가 조각을 그대로 잇는다 — 번호 참조가 전부 풀려 있어야 한다
hasnt "$t/.ai/workflows/work.md" "{{step:" "a step reference was left unresolved"
has "$t/.ai/workflows/work.md" "#### 4-1. 마무리" "the default numbering changed"
steps_work=$("$root/bin/harness" steps --target "$t" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["work"]))')
# 구현 뒤에 보안 검토를 끼운다 → 뒤 단계 번호와 그 번호를 가리키는 참조가 함께 밀린다
ins=$(printf '%s' "$steps_work" | python3 -c 'import json,sys; s=json.load(sys.stdin); s.insert(2,{"id":"security","type":"agent","title":"보안 검토","role":"security-guard"}); print(json.dumps(s))')
"$root/bin/harness" steps --target "$t" work "$ins" >/dev/null; check "insert a step" "$?" "0"
has "$t/.ai/workflows/work.md" "### 3. 보안 검토 — \`security-guard\` 역할에 위임" "the inserted step is not third"
has "$t/.ai/workflows/work.md" "#### 5-1. 마무리" "the sub-step did not follow its step"
has "$t/.ai/workflows/work.md" "거기서 코드가 바뀌지 않으면 6-1 이 받는다" "a reference did not follow the renumbering"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after steps" "$?" "0"
# 다른 단계가 가리키는 단계를 빼면 거부하고 설정을 되돌린다
cp "$t/harness.toml" "$work/steps.before"
del=$(printf '%s' "$ins" | python3 -c 'import json,sys; print(json.dumps([x for x in json.load(sys.stdin) if x["id"]!="limits"]))')
"$root/bin/harness" steps --target "$t" work "$del" --dry-run >/dev/null 2>&1; check "dry-run refuses a referenced step" "$?" "2"
"$root/bin/harness" steps --target "$t" work "$ins" --dry-run >/dev/null 2>&1; check "dry-run accepts valid steps" "$?" "0"
cmp -s "$t/harness.toml" "$work/steps.before"; check "dry-run leaves the config alone" "$?" "0"
"$root/bin/harness" steps --target "$t" work "$del" >/dev/null 2>&1; check "removing a referenced step" "$?" "2"
cmp -s "$t/harness.toml" "$work/steps.before"; check "config reverted" "$?" "0"
# CLI 러너 역할은 서브에이전트로 부를 수 없다
bad_role='[{"id":"x","type":"agent","title":"리뷰","role":"code-reviewer"}]'
"$root/bin/harness" steps --target "$t" retro "$bad_role" >/dev/null 2>&1; check "agent step on a script-run role" "$?" "2"
"$root/bin/harness" steps --target "$t" retro '[{"id":"x","type":"bogus","title":"t"}]' >/dev/null 2>&1; check "unknown step kind" "$?" "2"
# 설정에 절차가 없으면 기본값 — 단계 정의 전에 설치한 프로젝트도 그대로 렌더된다
t="$work/steps-legacy"; setup "$t"
python3 - "$t/harness.toml" <<'PY2'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding="utf-8")
p.write_text(re.sub(r"\n\[workflows\.[\s\S]*$", "\n", s), encoding="utf-8")
PY2
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "render without workflows" "$?" "0"
cmp -s "$t/.ai/workflows/work.md" "$work/steps/../shipped/.ai/workflows/work.md"; check "falls back to the default steps" "$?" "0"

echo "UT-37 set replaces a multi-line array whole"
# 첫 줄만 바꾸면 나머지 줄이 떠서 설정이 통째로 읽히지 않는다.
t="$work/set-multiline"; setup "$t"
"$root/bin/harness" set --target "$t" docs.protected ".ai/project/scope.md,docs/a.md," >/dev/null 2>&1
check "set on a multi-line array" "$?" "0"
python3 -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1],"rb"))["docs"]["protected"])' "$t/harness.toml" > "$work/ml.out" 2>&1
has "$work/ml.out" "['.ai/project/scope.md', 'docs/a.md']" "the array was not replaced whole"
has "$t/harness.toml" 'usage]' "the section after the array was damaged"

echo "UT-38 base documents stay protected, directories cover their contents, bad paths are refused"
t="$work/protected"; setup "$t"
"$root/bin/harness" set --target "$t" docs.protected "docs/spec/," >/dev/null 2>&1
check "set a directory" "$?" "0"
has "$t/.claude/settings.json" '"Edit(.ai/project/scope.md)"' "a base document lost its protection when dropped from the list"
has "$t/.claude/settings.json" '"Edit(docs/spec/**)"' "a directory rule does not cover the files under it"
hasnt "$t/.claude/settings.json" '"Edit(docs/spec/)"' "a directory rule was left in a form that matches nothing"
hasnt "$t/.claude/settings.json" '"Write(' "a Write rule is left, which file permission checks never match"
hasnt "$t/.claude/settings.json" '"NotebookEdit(' "a NotebookEdit rule is left, which file permission checks never match"
for p in "/etc/passwd" "../x.md" "docs/../x.md" "docs/a b.md"; do
  "$root/bin/harness" set --target "$t" docs.protected "$p," >/dev/null 2>&1
  check "refuse protected path '$p'" "$?" "2"
done
t="$work/adrdir"; setup "$t"
"$root/bin/harness" set --target "$t" adr.dir "../outside" >/dev/null 2>&1; check "refuse adr.dir outside the repo" "$?" "2"

echo "UT-39 tools lists what is on PATH and records it per machine"
fakebin="$work/fakebin"; mkdir -p "$fakebin"
printf '#!/bin/sh\necho "hermes 9.9"\n' > "$fakebin/hermes"; printf '#!/bin/sh\necho "codex 1.2"\n' > "$fakebin/codex"; chmod +x "$fakebin"/*
# PATH 를 좁히면 env 가 다른 python3 를 집는다 — 인터프리터를 직접 준다
py=$(command -v python3)
PATH="$fakebin:/usr/bin:/bin" "$py" "$root/bin/harness" tools --sync > "$work/tools.out" 2>&1
check "tools --sync" "$?" "0"
has "$work/tools.out" '"id": "codex"' "an installed agent CLI was not listed"
has "$work/tools.out" '"version": "hermes 9.9"' "the version line was not read"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); a={x["id"]:x["supported"] for x in d["agents"]}; print(a)' "$HARNESS_HOME/tools.json" > "$work/tools.sup"
has "$work/tools.sup" "'hermes': False" "an agent the harness cannot drive was marked supported"
hasnt "$work/tools.sup" "'claude'" "a CLI that is not on PATH was listed"

echo "UT-40 the commit form in procedures follows the config"
t="$work/commitform"; setup "$t"
has "$t/.ai/workflows/prework.md" '`docs: <요약>(#<이슈번호>)`' "the default commit form changed"
"$root/bin/harness" set --target "$t" commit.ticket_key DEV >/dev/null 2>&1
"$root/bin/harness" set --target "$t" commit.issue_ref prefix >/dev/null 2>&1
has "$t/.ai/workflows/prework.md" '`[DEV-<이슈번호>] docs: <요약>`' "the procedure kept a commit form the config no longer uses"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after the form changed" "$?" "0"

echo "UT-41 runners follow the vendor registry, and schema resolves who runs each role"
t="$work/runners"; setup "$t"
"$root/bin/harness" set --target "$t" roles.planner.runner gemini > "$work/runner.out" 2>&1
check "a vendor the registry only detects" "$?" "2"
"$root/bin/harness" set --target "$t" roles.planner.runner codex >/dev/null 2>&1
check "any role may take a CLI runner" "$?" "0"
"$root/bin/harness" set --target "$t" invariants.distinct_reviewer false >/dev/null 2>&1   # 구현·리뷰 분리 규칙과 떼어 본다
"$root/bin/harness" set --target "$t" roles.code-reviewer.runner claude >/dev/null 2>&1
check "a CLI runner for the script-run role" "$?" "0"
"$root/bin/harness" schema --target "$t" > "$work/schema.out" 2>&1
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["roles"]["planner"]["vendor"], d["roles"]["planner"]["runners"], d["script_roles"])' "$work/schema.out" > "$work/schema.sum"
has "$work/schema.sum" "codex ['inproc', 'claude', 'codex'] {'code-reviewer': 'script/review-mr.sh'}" "schema does not resolve who runs each role"

echo "UT-51 the run plan is generated from the config and the vendor registry"
t="$work/plan"; setup "$t"
"$root/bin/harness" set --target "$t" roles.planner.runner codex roles.planner.model gpt-x >/dev/null 2>&1
python3 -c 'import json,sys; r=json.load(open(sys.argv[1]))["roles"]; print(r["planner"]["argv"], r["planner"]["entry"], r["developer"]["via"])' "$t/script/harness.plan.json" > "$work/plan.sum"
has "$work/plan.sum" "['codex', 'exec', '--sandbox', 'workspace-write', '--ephemeral', '-m', 'gpt-x'] script/run-agent.py planner subagent" "the plan does not carry the vendor's argv"
has "$t/.ai/workflows/prework.md" "script/run-agent.py planner <이슈번호>" "an agent step with a CLI runner does not call the runner"
has "$t/.ai/workflows/prework.md" "작업 분해자 역할을 Codex CLI 로 실행" "the step heading does not say who runs it"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check covers the plan" "$?" "0"
printf '{}\n' > "$t/script/harness.plan.json"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check catches an edited plan" "$?" "1"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
( cd "$t" && python3 script/run-agent.py developer 1 ) > "$work/ra.out" 2>&1; check "the runner refuses a subagent role" "$?" "2"
has "$work/ra.out" "runs as a subagent" "the runner does not say why"
"$root/bin/harness" steps --target "$t" work '[{"id":"r","type":"agent","title":"리뷰","role":"code-reviewer"}]' --dry-run > "$work/entry.out" 2>&1
check "an agent step for a role with its own script" "$?" "2"
has "$work/entry.out" "script/review-mr.sh" "the refusal does not name the role's script"

echo "UT-60 a missing or incomplete adapter body stops render with its message"
frontmatter_case() { # <이름> <기대 메시지> <템플릿을 바꾸는 파이썬 한 줄>
  local h="$work/fm-$1" t="$work/fm-$1-target"
  rm -rf "$h"; mkdir -p "$h"; cp -R "$root/bin" "$root/templates" "$h/"
  python3 -c "import pathlib, re; p = pathlib.Path('$h/templates/agents/planner.md'); s = p.read_text(encoding='utf-8'); $3" \
    || { bad "$1: could not prepare the template"; return; }
  setup "$t"
  "$h/bin/harness" render --target "$t" >"$work/fm-$1.out" 2>&1
  [ "$?" -ne 0 ] && ok || bad "$1: render did not stop"
  has "$work/fm-$1.out" "$2" "$1: render did not say '$2'"
}
frontmatter_case nobody "no adapter body for role \`planner\`" "p.unlink()"
for c in schema metrics; do
  "$work/fm-nobody/bin/harness" "$c" --target "$work/fm-nobody-target" >"$work/fm-nobody-$c.out" 2>&1
  check "$c stops on a role without an adapter body" "$?" "2"
  has "$work/fm-nobody-$c.out" "no adapter body for role \`planner\`" "$c did not say which role has no adapter body"
done
frontmatter_case nosummary "frontmatter has no \`summary\`" "p.write_text(re.sub(r'(?m)^summary:.*\\n', '', s, count=1), encoding='utf-8')"
frontmatter_case nodescription "frontmatter has no \`description\`" "p.write_text(re.sub(r'(?m)^description:.*\\n', '', s, count=1), encoding='utf-8')"

echo "UT-52 a role may forbid CLI runners, and orchestrator gaps show in doctor"
h="$work/harness-copy"; rm -rf "$h"; mkdir -p "$h"; cp -R "$root/bin" "$root/templates" "$h/"
python3 - "$h/templates/agents/planner.md" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding="utf-8")
p.write_text(s.replace("\n---\n", "\nheadless: false\n---\n", 1), encoding="utf-8")
PY
t="$work/nohead"; setup "$t"
"$h/bin/harness" set --target "$t" roles.planner.runner codex > "$work/nohead.out" 2>&1
check "a CLI runner for a headless: false role" "$?" "2"
has "$work/nohead.out" "headless: false" "the refusal does not say why"
"$h/bin/harness" schema --target "$t" | python3 -c 'import json,sys; print(json.load(sys.stdin)["roles"]["planner"]["runners"])' > "$work/nohead.sum"
has "$work/nohead.sum" "['inproc']" "schema offers a runner the role forbids"
t="$work/codexorch"; setup "$t"
"$root/bin/harness" set --target "$t" harness.orchestrator codex roles.code-reviewer.runner claude >/dev/null 2>&1
"$root/bin/harness" doctor --target "$t" > "$work/doc2.out" 2>&1
has "$work/doc2.out" "no command guard for Codex CLI" "doctor does not warn that the guard hook is not wired"

echo "UT-42 a role's project instructions reach both agent definitions and stay protected"
t="$work/rolenotes"; setup "$t"
mkdir -p "$t/.ai/project/roles"
printf '<!-- 사람에게 하는 안내 -->\n\n- 분해는 한 task 당 파일 다섯 개 이하로 한다\n' > "$t/.ai/project/roles/planner.md"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check notices an unrendered role note" "$?" "1"
"$root/bin/harness" render --target "$t" >/dev/null
has "$t/.claude/agents/planner.md" "## 이 프로젝트에서" "the Claude agent did not get the project section"
has "$t/.codex/agents/planner.toml" "한 task 당 파일 다섯 개 이하" "the Codex agent did not get the instruction"
hasnt "$t/.claude/agents/planner.md" "사람에게 하는 안내" "the file's guidance comment leaked into the agent"
hasnt "$t/.claude/agents/developer.md" "## 이 프로젝트에서" "another role got the note"
has "$t/.claude/settings.json" '"Edit(.ai/project/roles/**)"' "role notes are not protected"
rm "$t/.ai/project/roles/planner.md"; "$root/bin/harness" render --target "$t" >/dev/null
hasnt "$t/.claude/agents/planner.md" "## 이 프로젝트에서" "removing the note left the section behind"

echo "UT-43 steps use type, and a config that still says kind reads the same"
t="$work/wfnotes"; setup "$t"
has "$t/harness.toml" 'type = "prompt"' "the shipped steps still use kind"
sedi 's/type = "/kind = "/g' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "an old config with kind still renders" "$?" "0"

echo "UT-44 workflow notes reach that procedure only, and stay protected"
t="$work/wfnotes2"; setup "$t"
mkdir -p "$t/.ai/project/workflows"; printf -- '- 머지 전 스테이징에서 한 번 돌려 본다\n' > "$t/.ai/project/workflows/work.md"
"$root/bin/harness" render --target "$t" >/dev/null
has "$t/.ai/workflows/work.md" "## 이 프로젝트에서" "the workflow note did not reach the procedure"
has "$t/.ai/workflows/work.md" "스테이징에서 한 번" "the workflow note text is missing"
hasnt "$t/.ai/workflows/prework.md" "스테이징에서 한 번" "another workflow got the note"
has "$t/.claude/settings.json" '"Edit(.ai/project/workflows/**)"' "workflow notes are not protected"

echo "UT-45 review limits are whole numbers from 1 to 20"
t="$work/reviewlimit"; setup "$t"
for n in 0 21 abc; do
  "$root/bin/harness" set --target "$t" review.max_rounds "$n" >/dev/null 2>&1; check "refuse max_rounds=$n" "$?" "2"
done
"$root/bin/harness" set --target "$t" review.repeat_file_max 20 >/dev/null 2>&1; check "accept the upper bound" "$?" "0"

echo "UT-46 models come from each CLI's own record, and a role's model must match who runs it"
fh="$work/fakehome"; fb="$work/fakebin2"; mkdir -p "$fh/.claude" "$fh/.codex" "$fb"
cat > "$fb/claude" <<'SH'
#!/bin/sh
case "$1" in --version) echo "9.9.9 (Claude Code)";; --help) printf "  --model <model>   Model. Provide an alias (e.g.\n                    'fable', 'opus' or 'sonnet').\n  -n, --name <name>  x\n";; esac
SH
printf '#!/bin/sh\necho "codex-cli 1.0.0"\n' > "$fb/codex"; chmod +x "$fb"/*
printf '{"model": "opus[1m]"}' > "$fh/.claude/settings.json"
printf '{"models":[{"slug":"gpt-a","display_name":"GPT-A","visibility":"list"},{"slug":"gpt-hidden","visibility":"hide"}]}' > "$fh/.codex/models_cache.json"
printf 'model = "gpt-a"\n' > "$fh/.codex/config.toml"
py=$(command -v python3)
HOME="$fh" PATH="$fb:/usr/bin:/bin" "$py" "$root/bin/harness" tools --sync > "$work/models.out" 2>&1
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print({a["id"]: [m["id"] for m in a.get("models", [])] for a in d["agents"]})' "$HARNESS_HOME/tools.json" > "$work/models.sum"
has "$work/models.sum" "'claude': ['fable', 'opus', 'sonnet', 'opus[1m]']" "claude models were not read from its help and settings"
has "$work/models.sum" "'codex': ['gpt-a']" "codex models were not read from its cache (or a hidden one leaked)"
t="$work/models"; setup "$t"
"$root/bin/harness" set --target "$t" harness.model opus >/dev/null 2>&1; check "set the orchestrator model" "$?" "0"
has "$t/.claude/agents/planner.md" "model: opus" "a subagent without its own model does not inherit the orchestrator model"
"$root/bin/harness" schema --target "$t" | python3 -c 'import json,sys; d=json.load(sys.stdin)["roles"]["planner"]; print(d["model_ok"], d["follows_orchestrator"])' > "$work/mok"
check "a subagent role on the inherited model" "$(cat "$work/mok")" "True False"
"$root/bin/harness" set --target "$t" roles.planner.model sonnet >/dev/null 2>&1; check "set a model a role had no key for" "$?" "0"
has "$t/.claude/agents/planner.md" "model: sonnet" "a subagent's own model does not win over the inherited one"
"$root/bin/harness" set --target "$t" roles.planner.runner claude >/dev/null 2>&1
has "$t/.claude/agents/planner.md" "model: opus" "a role run by the orchestrator's own CLI does not use the orchestrator model"
"$root/bin/harness" doctor --target "$t" > "$work/doc.out" 2>&1
has "$work/doc.out" "roles.planner.model = sonnet is not used" "doctor does not say the role's model is unused"
"$root/bin/harness" set --target "$t" roles.code-reviewer.model opus >/dev/null 2>&1
"$root/bin/harness" schema --target "$t" | python3 -c 'import json,sys; print(json.load(sys.stdin)["roles"]["code-reviewer"]["model_ok"])' > "$work/mok"
check "a model of another vendor is flagged" "$(cat "$work/mok")" "False"
"$root/bin/harness" doctor --target "$t" > "$work/doc.out" 2>&1
has "$work/doc.out" "roles.code-reviewer.model = opus" "doctor does not warn about a model the runner lacks"

echo "UT-47 set changes several values at once, so a swap that no single step allows goes through"
t="$work/swap"; setup "$t"
"$root/bin/harness" set --target "$t" harness.orchestrator codex >/dev/null 2>&1; check "orchestrator alone collides with the reviewer" "$?" "2"
"$root/bin/harness" set --target "$t" roles.code-reviewer.runner claude >/dev/null 2>&1; check "reviewer alone collides with the orchestrator" "$?" "2"
"$root/bin/harness" set --target "$t" harness.orchestrator codex roles.code-reviewer.runner claude >/dev/null 2>&1
check "both at once" "$?" "0"
"$root/bin/harness" schema --target "$t" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["roles"]["planner"]["vendor"], d["roles"]["code-reviewer"]["vendor"])' > "$work/swap.out"
has "$work/swap.out" "codex claude" "subagent roles did not follow the orchestrator"
cp "$t/harness.toml" "$work/swap.before"
"$root/bin/harness" set --target "$t" review.max_rounds 3 review.repeat_file_max 99 >/dev/null 2>&1; check "one bad value refuses the batch" "$?" "2"
cmp -s "$t/harness.toml" "$work/swap.before"; check "the whole batch is reverted" "$?" "0"

echo "UT-48 status reports what doctor and check see, as JSON"
t="$work/status"; setup "$t"
"$root/bin/harness" status --target "$t" > "$work/status.json" 2>&1; check "status" "$?" "0"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["check_ok"], d["facts"]["total"], d["facts"]["filled"], any(i["what"]=="git hooks enabled" for i in d["doctor"]["items"]))' "$work/status.json" > "$work/status.sum"
has "$work/status.sum" "True 7 0 True" "status does not carry check, facts and the hooks warning"
printf '\nx\n' >> "$t/.ai/workflows/work.md"
"$root/bin/harness" status --target "$t" | python3 -c 'import json,sys; print(json.load(sys.stdin)["check_ok"])' > "$work/status.chk"
check "status sees generated drift" "$(cat "$work/status.chk")" "False"

echo "UT-49 a project can add its own workflow — procedure, command and table row come with it"
t="$work/customwf"; setup "$t"
wf='{"title":"긴급 수정","steps":[{"id":"step-1","type":"prompt","title":"원인 찾기","text":"로그를 본다"},{"id":"step-2","type":"agent","title":"고치기","role":"developer"}]}'
"$root/bin/harness" steps --target "$t" hotfix "$wf" --dry-run >/dev/null 2>&1; check "dry-run a new workflow" "$?" "0"
[ ! -f "$t/.ai/workflows/hotfix.md" ] && ok || bad "dry-run wrote the procedure"
"$root/bin/harness" steps --target "$t" hotfix "$wf" >/dev/null 2>&1; check "create a new workflow" "$?" "0"
has "$t/.ai/workflows/hotfix.md" "# hotfix — 긴급 수정" "the procedure has no head"
has "$t/.ai/workflows/hotfix.md" "### 2. 고치기 — 구현자 역할에 위임" "the steps were not rendered"
has "$t/.claude/commands/hotfix.md" ".ai/workflows/hotfix.md" "no command points at the procedure"
has "$t/CLAUDE.md" '`/hotfix <이슈번호>` — 긴급 수정' "the command table does not list it"
has "$t/harness.toml" 'title = "긴급 수정"' "the title was not written"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after a new workflow" "$?" "0"
"$root/bin/harness" steps --target "$t" hotfix '[{"id":"step-1","type":"prompt","title":"원인 찾기","text":"로그를 다시 본다"}]' >/dev/null 2>&1
has "$t/harness.toml" 'title = "긴급 수정"' "editing the steps dropped the title"
for bad in security-guard "Hot Fix" x; do
  "$root/bin/harness" steps --target "$t" "$bad" "$wf" >/dev/null 2>&1; check "refuse workflow name '$bad'" "$?" "2"
done
"$root/bin/harness" steps --target "$t" noname '[{"id":"a","type":"gate","title":"t"}]' >/dev/null 2>&1; check "a new workflow without a title" "$?" "0"
has "$t/.ai/workflows/noname.md" "# noname — noname" "a workflow without a title does not fall back to its name"

echo "UT-50 a project's own workflow can be renamed and deleted; the harness's cannot"
t="$work/wfrename"; setup "$t"
"$root/bin/harness" steps --target "$t" hotfix '{"title":"긴급","steps":[{"id":"a","type":"gate","title":"확인"}]}' >/dev/null 2>&1
mkdir -p "$t/.ai/project/workflows"; printf -- '- 메모\n' > "$t/.ai/project/workflows/hotfix.md"
"$root/bin/harness" steps --target "$t" hotfix --rename quickfix >/dev/null 2>&1; check "rename" "$?" "0"
[ -f "$t/.ai/workflows/quickfix.md" ] && [ ! -f "$t/.ai/workflows/hotfix.md" ] && ok || bad "the procedure did not follow the rename"
[ -f "$t/.claude/commands/quickfix.md" ] && [ ! -f "$t/.claude/commands/hotfix.md" ] && ok || bad "the command did not follow the rename"
[ -f "$t/.ai/project/workflows/quickfix.md" ] && ok || bad "the workflow note did not follow the rename"
"$root/bin/harness" steps --target "$t" quickfix --rename work >/dev/null 2>&1; check "rename onto an existing name" "$?" "2"
"$root/bin/harness" steps --target "$t" quickfix --delete >/dev/null 2>&1; check "delete" "$?" "0"
[ ! -f "$t/.ai/workflows/quickfix.md" ] && [ ! -f "$t/.claude/commands/quickfix.md" ] && ok || bad "delete left generated files"
hasnt "$t/harness.toml" "workflows.quickfix" "delete left the section in the config"
[ -f "$t/.ai/project/workflows/quickfix.md" ] && ok || bad "delete removed the person's note"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after delete" "$?" "0"
"$root/bin/harness" steps --target "$t" work --delete >/dev/null 2>&1; check "refuse deleting a harness workflow" "$?" "2"

echo "UT-36 install registers the project for the UI, uninstall drops it"
t="$work/reg/demo"; rm -rf "$t"; mkdir -p "$t"; ( cd "$t" && git init -q )
"$root/bin/harness" install --target "$t" >/dev/null 2>&1
has "$HARNESS_HOME/demo/project.json" "\"$(cd "$t" && pwd -P)\"" "install did not record the project path"
"$root/bin/harness" uninstall --target "$t" >/dev/null 2>&1
[ ! -f "$HARNESS_HOME/demo/project.json" ] && ok || bad "uninstall left the registry entry"

echo "UT-53 commands and checks live in harness.toml; verification is generated from them"
t="$work/verify"; setup "$t"
bash "$t/script/harness-verify.sh" >/dev/null 2>&1; check "unset verification" "$?" "3"
"$root/bin/harness" doctor --target "$t" > "$work/v.doc" 2>&1
has "$work/v.doc" "script/harness-verify.sh  — not set up" "doctor does not say verification is unset"
has "$t/.ai/AI_AGENT.md" "명령이 아직 정해지지 않았다" "the rules do not say the commands are unset"
# 쉼표·따옴표가 든 명령도 문자열 하나로 남는다
"$root/bin/harness" set --target "$t" commands.test 'echo "a, b" >/dev/null' commands.format_check 'true' >/dev/null 2>&1; check "set commands" "$?" "0"
has "$t/harness.toml" 'test = "echo \"a, b\" >/dev/null"' "the command was not kept as one string"
has "$t/.ai/AI_AGENT.md" '| 테스트 전체 | `echo "a, b" >/dev/null` |' "the rules do not list the command"
# 명령의 정본은 harness.toml 하나다 — UI 가 읽는 schema, 규칙 문서, 검증 스크립트가 모두 같은 값을 본다
"$root/bin/harness" schema --target "$t" | python3 -c 'import json,sys; print(json.load(sys.stdin)["commands"]["test"])' > "$work/v.schema"
has "$work/v.schema" 'echo "a, b" >/dev/null' "schema does not read the command from harness.toml"
has "$t/script/harness-verify.sh" "step '테스트'" "the verification script does not run the same command"
"$root/bin/harness" checks --target "$t" '[{"name":"경계","run":"! grep -rq forbidden src"}]' >/dev/null 2>&1; check "set checks" "$?" "0"
has "$t/.ai/AI_AGENT.md" "경계 → 코드 검사 → 테스트" "the check order is not in the rules"
( cd "$t" && bash script/harness-verify.sh ) > "$work/v.out" 2>&1; check "verification passes" "$?" "0"
mkdir -p "$t/src" && echo forbidden > "$t/src/a.txt"
( cd "$t" && bash script/harness-verify.sh ) > "$work/v.out" 2>&1; check "a failing check stops verification" "$?" "1"
has "$work/v.out" "verify: FAIL 경계" "the failure does not name the check"
"$root/bin/harness" doctor --target "$t" > "$work/v.doc" 2>&1
has "$work/v.doc" "fails at 경계" "doctor does not name the failing check"
"$root/bin/harness" checks --target "$t" '[{"name":"","run":"x"}]' >/dev/null 2>&1; check "refuse a nameless check" "$?" "2"
"$root/bin/harness" set --target "$t" commands.nope x >/dev/null 2>&1; check "refuse an unknown command key" "$?" "2"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after edits" "$?" "0"
# 손으로 쓴 옛 검증 스크립트가 있으면 그것이 돈다 — 옮기기 전까지 동작을 바꾸지 않는다
printf '#!/usr/bin/env bash\necho legacy-ran\n' > "$t/script/verify-project.sh"
( cd "$t" && sed -n '/^old=/,$p' script/run-lint-test.sh | bash ) > "$work/v.leg" 2>&1
has "$work/v.leg" "legacy-ran" "the hand-written script did not run"
"$root/bin/harness" doctor --target "$t" > "$work/v.doc" 2>&1
has "$work/v.doc" "runs instead of [commands] and [verify]" "doctor does not warn about the two sources"
# 옛 설정에는 [commands] 절이 없다 — set 이 절을 만든다
python3 - "$t/harness.toml" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r"(?ms)^\[commands\].*?(?=^\[verify\])", "", s)
open(p, "w").write(s)
PY
"$root/bin/harness" set --target "$t" commands.build "make" >/dev/null 2>&1; check "set on a config without [commands]" "$?" "0"
has "$t/harness.toml" 'build = "make"' "the section was not created"

echo "UT-54 run metrics: spans, rotation, retention, redaction, and the aggregate"
t="$work/metrics"; setup "$t"; md="$work/metrics-data"
"$root/bin/harness" set --target "$t" metrics.dir "$md" >/dev/null 2>&1; check "set metrics.dir" "$?" "0"
has "$t/script/harness.plan.json" "\"dir\": \"$md\"" "the plan does not carry the metrics dir"
# 감싼 명령의 출력과 종료 코드는 그대로다
( cd "$t" && script/metric.py wrap --name demo --kind script --attr step=review --attr workflow=work \
    -- bash -c 'echo out-line; echo "token=abc123 fail me@x.com at '"$HOME"'/x?q=1" >&2; exit 3' ) > "$work/m.out" 2> "$work/m.err"
check "wrap keeps the exit code" "$?" "3"
has "$work/m.out" "out-line" "wrap swallowed stdout"
has "$work/m.err" "token=abc123" "wrap swallowed stderr"
f=$(ls "$md"/spans-*.jsonl | head -1)
[ "$(stat -c %a "$md" 2>/dev/null || stat -f %Lp "$md")" = "700" ] && ok || bad "the metrics dir is not 0700"
[ "$(stat -c %a "$f" 2>/dev/null || stat -f %Lp "$f")" = "600" ] && ok || bad "a span file is not 0600"
hasnt "$f" "abc123" "a token reached the log"
hasnt "$f" "me@x.com" "an email reached the log"
hasnt "$f" "$HOME/" "the home path reached the log"
has "$f" 'token=***' "the log was not kept in redacted form"
"$root/bin/harness" set --target "$t" metrics.capture_logs off >/dev/null 2>&1
( cd "$t" && script/metric.py wrap --name demo2 --kind script -- false )
hasnt "$f" '"log":"",' "an empty log was written"
python3 -c 'import json,sys; e=[json.loads(l) for l in open(sys.argv[1])][-1]; sys.exit("log" in e)' "$f"; check "capture_logs off keeps no log" "$?" "0"
"$root/bin/harness" set --target "$t" metrics.capture_logs loud >/dev/null 2>&1; check "refuse an unknown capture_logs" "$?" "2"
# 두 프로세스가 동시에 써도 줄이 섞이지 않는다
rm -f "$md"/spans-*.jsonl
for n in 1 2; do ( cd "$t" && python3 -B -c 'import sys; sys.path.insert(0, "script"); import metric
for i in range(500): metric.start("p%d" % i, "script")' ) & done; wait
python3 -c 'import json,glob,sys; ls=[l for f in glob.glob(sys.argv[1]+"/spans-*.jsonl") for l in open(f)]; [json.loads(l) for l in ls]; print(len(ls))' "$md" > "$work/m.n"
has "$work/m.n" "1000" "concurrent writers lost or broke lines"
# 파일 하나가 상한을 넘으면 다음 번호로 넘어간다 (max_file_mb = 1)
"$root/bin/harness" set --target "$t" metrics.max_file_mb 1 metrics.max_total_mb 2 >/dev/null 2>&1
( cd "$t" && python3 -B -c 'import sys; sys.path.insert(0, "script"); import metric
for i in range(4500): metric.start("rotate-%d" % i, "script", {"workflow": "x" * 60})' )
[ "$(ls "$md"/spans-*.jsonl | wc -l | tr -d ' ')" -ge 2 ] && ok || bad "the span file did not rotate at max_file_mb"
# 보관 기간이 지난 파일과, 전체 상한을 넘는 오래된 파일은 지운다. 쓰는 중인 파일은 남는다
echo '{}' > "$md/spans-20000101-1.jsonl"
cur=$(ls "$md"/spans-*.jsonl | sort -t- -k2,2 -k3,3n | tail -1)
( cd "$t" && script/metric.py prune ) >/dev/null
[ ! -f "$md/spans-20000101-1.jsonl" ] && ok || bad "a file past retention_days was kept"
[ -f "$cur" ] && ok || bad "prune removed the file being written"
python3 -c 'import glob,os,sys; print(sum(os.path.getsize(f) for f in glob.glob(sys.argv[1]+"/spans-*.jsonl")) <= 2*1024*1024)' "$md" > "$work/m.cap"
has "$work/m.cap" "True" "prune did not enforce max_total_mb"
# 꺼져 있으면 아무것도 만들지 않고 명령만 돈다. 기록할 수 없는 곳이어도 종료 코드는 그대로다
"$root/bin/harness" set --target "$t" metrics.dir off >/dev/null 2>&1
( cd "$t" && script/metric.py wrap --name off --kind script -- sh -c 'exit 4' ); check "wrap with metrics off" "$?" "4"
"$root/bin/harness" set --target "$t" metrics.dir /dev/null/nope >/dev/null 2>&1
( cd "$t" && script/metric.py wrap --name nowhere --kind script -- sh -c 'exit 5' ) 2>/dev/null; check "an unwritable metrics dir does not change the exit code" "$?" "5"
# 집계 — 고정 스팬으로 상태·토큰·성공률·트리를 본다
"$root/bin/harness" set --target "$t" metrics.dir "$md" >/dev/null 2>&1
rm -f "$md"/spans-*.jsonl
python3 - "$md" <<'PY'
import datetime, json, sys
now = datetime.datetime.now(datetime.timezone.utc)
ts = lambda m: (now - datetime.timedelta(minutes=m)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
ev = [
  {"ev":"start","trace":"t1","span":"a","parent":None,"name":"work","kind":"command","source":"runner","attrs":{"workflow":"work"},"t":ts(30)},
  {"ev":"start","trace":"t1","span":"b","parent":"a","name":"review","kind":"agent","source":"runner","attrs":{"workflow":"work","step":"review","role":"code-reviewer","vendor":"codex"},"t":ts(29)},
  {"ev":"end","span":"b","status":"ok","dur_ms":60000,"usage":{"input":100,"output":20},"model":"m1","t":ts(28)},
  {"ev":"end","span":"a","status":"ok","dur_ms":120000,"t":ts(28)},
  {"ev":"start","trace":"t2","span":"c","parent":None,"name":"verify","kind":"script","source":"script","attrs":{},"t":ts(20)},
  {"ev":"end","span":"c","status":"error","exit":1,"dur_ms":5000,"t":ts(19)},
  {"ev":"start","trace":"t3","span":"d","parent":None,"name":"long","kind":"command","source":"runner","attrs":{},"t":ts(60*8)},
  {"ev":"start","trace":"t4","span":"e","parent":None,"name":"now","kind":"command","source":"runner","attrs":{},"t":ts(1)},
]
open(sys.argv[1] + "/spans-20990101-1.jsonl", "w").write("".join(json.dumps(dict(e, v=1)) + "\n" for e in ev) + '{"ev":"start","half')
PY
"$root/bin/harness" metrics --target "$t" --since 1d --trace t1 > "$work/m.json"; check "metrics" "$?" "0"
python3 - "$work/m.json" > "$work/m.sum" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); s = d["summary"]
print(s["runs"], s["ok"], s["error"], s["running"], s["stale"], s["success_rate"], s["tokens"]["input"] + s["tokens"]["output"])
print(d["by_role"][0]["name"], d["by_role"][0]["tokens"], d["by_step"][0]["name"], d["diagnostics"]["bad_lines"])
print([(x["name"], x["offset_ms"] >= 0) for x in d["trace"]], d["errors"][0]["name"], d["daily"][0]["by"])
PY
has "$work/m.sum" "4 1 1 1 1 0.5 120" "the summary counts are wrong (runs ok error running stale rate tokens)"
has "$work/m.sum" "code-reviewer 120 work/review 1" "grouping or the half-written line count is wrong"
has "$work/m.sum" "[('work', True), ('review', True)] verify {'codex/m1': 120}" "the trace tree, errors or daily tokens are wrong"

echo "UT-55 harness run, run-lint-test and verification steps nest under one trace"
t="$work/traced"; setup "$t"; md="$work/traced-data"
"$root/bin/harness" set --target "$t" metrics.dir "$md" commands.test "true" commands.format_check "true" >/dev/null 2>&1
( cd "$t" && git init -q . 2>/dev/null; ./script/run-lint-test.sh ) > "$work/rl.log" 2>&1; check "run-lint-test with commands set" "$?" "0"
python3 - "$md" > "$work/rl.sum" <<'PY'
import glob, json, sys
ev = [json.loads(l) for f in glob.glob(sys.argv[1] + "/spans-*.jsonl") for l in open(f)]
st = {e["span"]: e for e in ev if e["ev"] == "start"}
root = [e for e in st.values() if e["name"] == "run-lint-test"]
kids = sorted(e["name"] for e in st.values() if root and e["trace"] == root[0]["trace"] and e["name"].startswith("verify/"))
print(len(root), kids, all(st.get(e["parent"], {}).get("name") in ("run-lint-test", "harness-verify") or e["name"] == "run-lint-test" for e in st.values() if root and e["trace"] == root[0]["trace"]))
PY
has "$work/rl.sum" "1 ['verify/코드-검사', 'verify/테스트'] True" "verification steps did not nest under run-lint-test"
# doctor 는 점검이다 — 검증을 돌려도 실행 지표를 남기지 않는다. 직접 부른 검증은 한 실행으로 묶인다
n0=$(cat "$md"/spans-*.jsonl | wc -l)
"$root/bin/harness" doctor --target "$t" >/dev/null 2>&1
[ "$(cat "$md"/spans-*.jsonl | wc -l)" = "$n0" ] && ok || bad "doctor left metrics behind"
( cd "$t" && bash script/harness-verify.sh ) >/dev/null 2>&1
python3 -c 'import glob,json,sys; ev=[json.loads(l) for f in glob.glob(sys.argv[1]+"/spans-*.jsonl") for l in open(f)][int(sys.argv[2]):]; st=[e for e in ev if e["ev"]=="start"]; print(len({e["trace"] for e in st}), [e["name"] for e in st][0])' "$md" "$n0" > "$work/hv.sum"
has "$work/hv.sum" "1 harness-verify" "a direct verification run did not stay one trace"
# harness run — 오케스트레이터(스텁)를 기다렸다가 끝 기록까지 남기고, 트레이스를 자식에게 넘긴다
mkdir -p "$work/orch" && cat > "$work/orch/claude" <<'SH'
#!/usr/bin/env sh
echo "trace=$HARNESS_TRACE_ID wf=$HARNESS_WORKFLOW" > "$ORCH_OUT"
exit 0
SH
chmod +x "$work/orch/claude"
"$root/bin/harness" set --target "$t" harness.orchestrator claude roles.code-reviewer.runner codex >/dev/null 2>&1
( cd "$t" && ORCH_OUT="$work/orch.out" PATH="$work/orch:$PATH" "$root/bin/harness" run work 12 ) >/dev/null 2>&1; check "harness run exit code" "$?" "0"
has "$work/orch.out" "wf=work" "harness run did not pass the workflow to the orchestrator"
"$root/bin/harness" metrics --target "$t" --since 1d > "$work/run.json"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); r=[x for x in d["traces"] if x["name"]=="run/work"]; print(len(r), r[0]["status"], r[0]["attrs"].get("issue"), r[0]["trace"] in open(sys.argv[2]).read())' "$work/run.json" "$work/orch.out" > "$work/run.sum"
has "$work/run.sum" "1 ok 12 True" "harness run did not record its span or pass the trace"

echo "UT-56 session import: usage by run, step and role, once, without message text"
t="$work/imported"; setup "$t"; md="$work/imported-data"; cl="$work/claude-projects"; cx="$work/codex-sessions"
"$root/bin/harness" set --target "$t" metrics.dir "$md" >/dev/null 2>&1
python3 - "$t" "$cl" "$cx" <<'PY'
import datetime, json, os, re, sys
t, cl, cx = sys.argv[1:4]
sys.path.insert(0, t + "/script"); sys.dont_write_bytecode = True
import metric
now = datetime.datetime.now(datetime.timezone.utc)
at = lambda m: now - datetime.timedelta(minutes=m)
ts = lambda m: at(m).strftime("%Y-%m-%dT%H:%M:%S.000Z")
tr, run = metric.start("run/work", "command", {"workflow": "work", "vendor": "claude"}, trace="t-run", parent="", source="runner", t=at(10))
metric.end(run, "ok", 0, t=at(1))
for m, st in ((9, "implement"), (5, "review")):
    _, s = metric.start("work/" + st, "marker", {"workflow": "work", "step": st}, trace="t-run", parent=run, source="session", t=at(m)); metric.end(s, t=at(m))
d = os.path.join(cl, re.sub(r"[^A-Za-z0-9]", "-", os.path.realpath(t)))
os.makedirs(d + "/sess/subagents")
line = lambda m, mid, i, o: json.dumps({"type": "assistant", "sessionId": "sess", "timestamp": ts(m),
    "message": {"id": mid, "model": "claude-x", "content": [{"type": "text", "text": "SECRET-BODY"}], "usage": {"input_tokens": i, "output_tokens": o}}})
open(d + "/sess.jsonl", "w").write("\n".join([line(8, "a1", 10, 5), line(8, "a1", 10, 5), line(4, "a2", 20, 10)]) + "\n" + line(3, "a3", 100, 0)[:40])
open(d + "/sess/subagents/agent-1.jsonl", "w").write(line(7, "b1", 7, 3) + "\n")
open(d + "/sess/subagents/agent-1.meta.json", "w").write(json.dumps({"agentType": "developer"}))
os.makedirs(cx + "/2026/09/25")
rec = lambda m, rid: json.dumps({"timestamp": ts(m), "type": "token_usage_record", "payload": {"response_id": rid, "usage": {"input_tokens": 14, "cached_input_tokens": 4, "output_tokens": 6}}})
meta = lambda cwd: json.dumps({"timestamp": ts(3), "type": "session_meta", "payload": {"id": "cx1", "cwd": cwd}})
open(cx + "/2026/09/25/rollout-a.jsonl", "w").write("\n".join([meta(os.path.realpath(t)), rec(3, "r1"), rec(3, "r1")]) + "\n")
open(cx + "/2026/09/25/rollout-b.jsonl", "w").write("\n".join([meta("/elsewhere"), rec(3, "r9")]) + "\n")
PY
imp() { HARNESS_CLAUDE_DIR="$cl" HARNESS_CODEX_DIR="$cx" "$root/bin/harness" metrics import --target "$t" --since 1d --trace t-run; }
imp > "$work/imp1.json"; check "metrics import" "$?" "0"
sum() { python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
st = {x["name"]: x["tokens"] for x in d["by_step"]}; ro = {x["name"]: x["tokens"] for x in d["by_role"]}
un = [x["tokens"] for x in d["traces"] if x["name"] == "unattributed"]
print(d["diagnostics"]["imported"]["records"], st.get("work/implement"), st.get("work/review"), ro.get("developer"), un, d["summary"]["runs"])
PY
}
sum "$work/imp1.json" > "$work/imp1.sum"
has "$work/imp1.sum" "4 25 30 10 [16] 1" "import totals are wrong (records implement review developer unattributed runs)"
hasnt "$md"/$(ls "$md" | grep spans | head -1) "SECRET-BODY" "message text reached the metrics"
grep -rqF "SECRET-BODY" "$md" && bad "message text reached the metrics" || ok
imp > "$work/imp2.json"; sum "$work/imp2.json" > "$work/imp2.sum"
has "$work/imp2.sum" "0 25 30 10 [16] 1" "a second import counted the same usage again"
# 쓰는 중이던 마지막 줄이 끝나면 다음 가져오기에서 한 번만 센다
python3 - "$cl" "$t" <<'PY'
import glob, json, sys
f = glob.glob(sys.argv[1] + "/*/sess.jsonl")[0]
body = open(f).read(); last = body.rsplit("\n", 1)[1]
full = json.dumps({"type": "assistant", "sessionId": "sess", "timestamp": json.loads(body.split("\n")[2])["timestamp"],
                   "message": {"id": "a3", "model": "claude-x", "usage": {"input_tokens": 100, "output_tokens": 0}}})
open(f, "w").write(body[: len(body) - len(last)] + full + "\n")
PY
imp > "$work/imp3.json"; sum "$work/imp3.json" > "$work/imp3.sum"
has "$work/imp3.sum" "1 25 130 10 [16] 1" "the completed line was not imported exactly once"
cur="$HARNESS_HOME/my-project/state/import-cursor.json"   # setup 의 설정은 project.name 을 바꾸지 않는다
[ "$(stat -c %a "$cur" 2>/dev/null || stat -f %Lp "$cur")" = "600" ] && ok || bad "the import cursor is not 0600"

echo "UT-61 review threads carry an id, and a reply lands on the thread it names"
# 답글을 달려면 조회 결과가 스레드를 지목할 수 있어야 한다. 정규화와 호출 경로는 자격증명 없이 도는
# 부분이라 가짜 CLI 로 본다 — 실제 forge 로 보는 것은 자체 검사의 몫이다.
t="$work/thread-reply"; rm -rf "$t"; mkdir -p "$t"
cp "$root/templates/managed/script/forge/"*.sh "$t/"
cat > "$t/fake-gh" <<'GH'
#!/bin/sh
printf '%s\n' "$@" >> "$FAKE_CALLS"
case "$*" in
  *pulls/5/comments\?*) printf '%s' '[{"id":11,"path":"a.sh","line":3,"body":"지적","created_at":"2026-01-01T00:00:00Z"},{"id":12,"in_reply_to_id":11,"path":"a.sh","line":3,"body":"조치","created_at":"2026-01-01T00:00:01Z"}]' ;;
  *issues/5/comments\?*) printf '%s' '[{"id":21,"body":"요약","created_at":"2026-01-01T00:00:02Z"}]' ;;
  *comments/11/replies*) printf '{}' ;;
  *) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
esac
GH
cat > "$t/fake-glab" <<'GL'
#!/bin/sh
printf '%s\n' "$@" >> "$FAKE_CALLS"
case "$*" in
  *merge_requests/5/discussions\?*page=1*) printf '%s' '[{"id":"abc","individual_note":false,"notes":[{"body":"지적","created_at":"t1","position":{"new_path":"a.sh","new_line":3}},{"body":"조치","created_at":"t2"}]},{"id":"def","individual_note":true,"notes":[{"body":"요약","created_at":"t3"}]},{"id":"sys","individual_note":true,"notes":[{"body":"added 1 commit","system":true}]}]' ;;
  *discussions/abc/notes*) printf '{}' ;;
  *) echo "glab: 404 Not Found" >&2; exit 1 ;;
esac
GL
chmod +x "$t/fake-gh" "$t/fake-glab"
export FAKE_CALLS="$t/calls"

ids() { python3 -c '
import json, sys
for x in json.load(open(sys.argv[1])):
    print("%s %s %d" % (json.dumps(x.get("id", "MISSING")), x["inline"], len(x["notes"])))' "$1"; }

( _FORGE_WANT_REVIEW=1; . "$t/github.sh"; GITHUB_CLI="$t/fake-gh"; review_mr_threads 5 ) > "$work/gh-threads.json" 2>&1
ids "$work/gh-threads.json" > "$work/gh-ids.txt" 2>&1
has   "$work/gh-ids.txt" '"11" True 2' "GitHub: the inline thread does not carry its root comment id with its reply"
has   "$work/gh-ids.txt" 'null False 1' "GitHub: a plain PR comment does not carry a null id"
hasnt "$work/gh-ids.txt" '"12"'        "GitHub: a reply surfaced as a thread of its own"

: > "$FAKE_CALLS"
( _FORGE_WANT_REVIEW=1; . "$t/github.sh"; GITHUB_CLI="$t/fake-gh"; review_mr_thread_reply 5 11 "고쳤다" )
check "GitHub: a reply to an existing thread" "$?" "0"
has "$FAKE_CALLS" "repos/{owner}/{repo}/pulls/5/comments/11/replies" "GitHub: the reply did not go to the thread's replies endpoint"
has "$FAKE_CALLS" "body=고쳤다" "GitHub: the reply body was not sent"
( _FORGE_WANT_REVIEW=1; . "$t/github.sh"; GITHUB_CLI="$t/fake-gh"; review_mr_thread_reply 5 99 "고쳤다" ) 2>"$work/gh-reply.err"
check "GitHub: a reply to an unknown thread fails" "$?" "1"
has "$work/gh-reply.err" "404" "GitHub: the failure does not say why"

( _FORGE_WANT_REVIEW=1; . "$t/gitlab.sh"; GITLAB_CLI="$t/fake-glab"; review_mr_threads 5 ) > "$work/gl-threads.json" 2>&1
ids "$work/gl-threads.json" > "$work/gl-ids.txt" 2>&1
has   "$work/gl-ids.txt" '"abc" True 2' "GitLab: the inline discussion does not carry its id with its reply"
has   "$work/gl-ids.txt" 'null False 1' "GitLab: an individual note does not carry a null id"
hasnt "$work/gl-ids.txt" '"sys"'       "GitLab: a system note surfaced as a thread"

: > "$FAKE_CALLS"
( _FORGE_WANT_REVIEW=1; . "$t/gitlab.sh"; GITLAB_CLI="$t/fake-glab"; review_mr_thread_reply 5 abc "고쳤다" )
check "GitLab: a reply to an existing discussion" "$?" "0"
has "$FAKE_CALLS" "projects/:id/merge_requests/5/discussions/abc/notes" "GitLab: the reply did not go to the discussion's notes"
has "$FAKE_CALLS" "POST" "GitLab: the reply is not a POST"
( _FORGE_WANT_REVIEW=1; . "$t/gitlab.sh"; GITLAB_CLI="$t/fake-glab"; review_mr_thread_reply 5 nope "고쳤다" ) 2>/dev/null
check "GitLab: a reply to an unknown discussion fails" "$?" "1"

# 페이크 어댑터는 자체 검사의 기준이다. 계약대로 답글을 붙이고 없는 스레드를 거부해야 한다.
fst="$work/thread-fake"; rm -rf "$fst"; mkdir -p "$fst"
( FAKE_STATE="$fst"; FAKE_BREAK=""; . "$root/test/fake-forge.sh"
  review_mr_note_inline 1 sample.txt 2 "지적" >/dev/null
  printf '요약\n' > "$fst/s.md"; review_mr_note_summary 1 "$fst/s.md" >/dev/null
  review_mr_thread_reply 1 t1 "고쳤다" && review_mr_threads 1 ) > "$work/fake-threads.json" 2>&1
check "fake forge: a reply to an existing thread" "$?" "0"
python3 -c '
import json, sys
t = json.load(open(sys.argv[1]))
ok = t[0]["id"] == "t1" and [n["body"] for n in t[0]["notes"]] == ["지적", "고쳤다"] and t[1]["id"] is None and len(t) == 2
raise SystemExit(0 if ok else 1)' "$work/fake-threads.json" 2>/dev/null \
  && ok || bad "fake forge: the reply is not the last note of the thread it names"
( FAKE_STATE="$fst"; FAKE_BREAK=""; . "$root/test/fake-forge.sh"; review_mr_thread_reply 1 t9 "고쳤다" ) 2>"$work/fake-reply.err"
check "fake forge: a reply to an unknown thread fails" "$?" "1"
has "$work/fake-reply.err" "t9" "fake forge: the failure does not name the thread"

# Jira 는 리뷰를 호스트하지 않는다. 답글이 성공처럼 지나가면 조치가 어디에도 남지 않는다.
( _FORGE_WANT_TRACKER=0; _FORGE_WANT_REVIEW=1; . "$t/jira.sh"; review_mr_thread_reply 5 11 "고쳤다" ) 2>"$work/jira-reply.err"
check "Jira: a thread reply is refused" "$?" "2"
has "$work/jira-reply.err" "not supported" "Jira: the refusal does not say it is unsupported"
unset FAKE_CALLS

echo "UT-70 the worktree section: defaults, unknown keys and paths that are not relative are refused"
t="$work/wtcfg"; setup "$t"
has "$t/harness.toml" 'dir = "$HOME/.harness/{project}/worktrees"' "the default config has no worktree.dir default"
has "$t/harness.toml" 'include = [".claude/settings.local.json"]' "the default config has no worktree.include default"
cp "$t/harness.toml" "$work/wtcfg.orig"
wt_render() { "$root/bin/harness" render --target "$t" > "$work/wtcfg.log" 2>&1; }
python3 - "$t/harness.toml" <<'PY'
import sys; p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace('include = [".claude/settings.local.json"]', 'include = [".claude/settings.local.json"]\nenabled = true'))
PY
wt_render; check "render with an unknown worktree key" "$?" "2"
has "$work/wtcfg.log" "unknown key(s) in [worktree]: enabled" "the unknown worktree key is not named"
has "$work/wtcfg.log" "the keys are dir, include" "the worktree keys are not listed"
for bad_path in "/etc/x" "../x" "a/../b" "a b" "*.json" "a?" "[ab]"; do
  cp "$work/wtcfg.orig" "$t/harness.toml"
  python3 - "$t/harness.toml" "$bad_path" <<'PY'
import json, sys; p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace('include = [".claude/settings.local.json"]', 'include = [".env", %s]' % json.dumps(sys.argv[2])))
PY
  wt_render; check "render with worktree.include item $bad_path" "$?" "2"
  has "$work/wtcfg.log" "worktree.include[2] must be a path relative to the harness root" "the bad include item $bad_path is not named"
done
cp "$work/wtcfg.orig" "$t/harness.toml"
sedi 's|^dir = "\$HOME/.harness/{project}/worktrees"$|dir = "  "|' "$t/harness.toml"
wt_render; check "render with a blank worktree.dir" "$?" "2"
has "$work/wtcfg.log" "worktree.dir must be" "the blank worktree.dir is not named"
# 절이 없는 옛 설정은 기본값으로 돈다
cp "$work/wtcfg.orig" "$t/harness.toml"
python3 - "$t/harness.toml" <<'PY'
import re, sys; p = sys.argv[1]; s = open(p).read()
s, n = re.subn(r'^\[worktree\]\n(?:(?!\[).*\n)*', '', s, flags=re.M)
assert n == 1 and "[worktree]" not in s
open(p, "w").write(s)
PY
wt_render; check "render without a worktree section" "$?" "0"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check without a worktree section" "$?" "0"
cp "$work/wtcfg.orig" "$t/harness.toml"

echo "UT-71 harness run --worktree makes a worktree per issue, reopens a clean one and removes it when nothing is left"
t="$work/wtrun"; setup "$t"; wd="$work/wtrun-trees"
"$root/bin/harness" set --target "$t" worktree.dir "$wd" >/dev/null 2>&1 || bad "could not set worktree.dir"
wtg() { git -C "$1" -c user.name=t -c user.email=t@example.invalid "${@:2}"; }
git init -q --bare -b development "$work/wtrun-origin.git"
( cd "$t" && git init -q -b development . && echo a > tracked.txt )
wtg "$t" add -A && wtg "$t" commit -q -m "chore: 하네스" && wtg "$t" remote add origin "$work/wtrun-origin.git" \
  && wtg "$t" push -q origin development || bad "could not set up the worktree test repo"
# 가짜 오케스트레이터: 불린 자리와 HEAD 를 적고, 케이스에 따라 추적 파일을 고치거나 커밋한다
mkdir -p "$work/wtorch" && cat > "$work/wtorch/claude" <<'SH'
#!/bin/sh
{ pwd -P; git rev-parse HEAD; git symbolic-ref -q HEAD || echo detached; } > "$WT_OUT"
git status --porcelain > "$WT_OUT.status"
top=$(git rev-parse --show-toplevel)
case "$WT_ACT" in
  keep)   touch "$top/keep.me" ;;
  edit)   echo b >> "$top/tracked.txt" ;;
  commit) echo c >> "$top/tracked.txt"; git -c user.name=t -c user.email=t@example.invalid commit -qam "feat: x(#7)" --no-verify ;;
esac
exit "${WT_CODE:-0}"
SH
chmod +x "$work/wtorch/claude"
wtrun() { # wtrun <하네스 루트> <인자...> — 가짜 오케스트레이터로 harness run 을 돌린다. 출력은 wt.log, 불린 자리는 wt.cwd
  local dir="$1"; shift; rm -f "$work/wt.cwd"
  ( cd "$dir" && PATH="$work/wtorch:$PATH" WT_OUT="$work/wt.cwd" "$root/bin/harness" run "$@" ) > "$work/wt.log" 2>&1
}
called() { [ -f "$work/wt.cwd" ] && sed -n "${1}p" "$work/wt.cwd"; }
base_head=$(git -C "$t" rev-parse origin/development)

wtrun "$t" work 7 --worktree; check "run --worktree exit code" "$?" "0"
real_wd=$(cd "$wd" && pwd -P)
check "the orchestrator runs inside the new worktree" "$(called 1)" "$real_wd/7"
check "the new worktree starts at the remote integration branch" "$(called 2)" "$base_head"
check "the new worktree's HEAD is detached" "$(called 3)" "detached"
has "$work/wt.log" "worktree: $wd/7 (new)" "run --worktree did not name the new worktree"
has "$work/wt.log" "removed worktree $wd/7" "a worktree left clean was not removed"
[ ! -e "$wd/7" ] && ok || bad "the clean worktree is still on disk"
git -C "$t" worktree list | grep -qF "wtrun-trees/7" && bad "the clean worktree is still registered" || ok

wtrun "$t" work 7; check "run without --worktree exit code" "$?" "0"
check "without --worktree the orchestrator runs at the harness root" "$(called 1)" "$(cd "$t" && pwd -P)"
[ ! -e "$wd/7" ] && ok || bad "a worktree was made without --worktree"

WT_ACT=edit WT_CODE=3 wtrun "$t" work 7 --worktree; check "exit code is the orchestrator's when the worktree is kept" "$?" "3"
has "$work/wt.log" "kept worktree $wd/7 — uncommitted changes" "a worktree with uncommitted changes was not kept"
[ -d "$wd/7" ] && ok || bad "the worktree with uncommitted changes was removed"

wtrun "$t" work 7 --worktree; check "exit code for a worktree with uncommitted changes" "$?" "1"
[ -f "$work/wt.cwd" ] && bad "the orchestrator launched in a worktree with uncommitted changes" || ok
has "$work/wt.log" "stop: worktree $wd/7 has uncommitted changes" "the stop does not name the worktree"
has "$work/wt.log" " M tracked.txt" "the stop does not show the status lines"
wtg "$wd/7" checkout -q -- tracked.txt

WT_ACT=commit wtrun "$t" work 7 --worktree; check "run that commits exit code" "$?" "0"
has "$work/wt.log" "worktree: $wd/7 (reopened)" "a clean worktree was not reopened"
has "$work/wt.log" "kept worktree $wd/7 — unpushed commits" "a worktree with unpushed commits was not kept"
wtg "$wd/7" push -q origin HEAD:refs/heads/wt7 || bad "could not push the worktree commit"
head7=$(git -C "$wd/7" rev-parse HEAD)
wtrun "$t" work 7 --worktree; check "reopening a clean worktree exit code" "$?" "0"
has "$work/wt.log" "worktree: $wd/7 (reopened)" "a clean worktree was not reopened"
check "the reopened worktree keeps its HEAD" "$(called 2)" "$head7"
check "the orchestrator runs inside the reopened worktree" "$(called 1)" "$real_wd/7"
[ ! -e "$wd/7" ] && ok || bad "the pushed worktree was not removed"

o="$work/wtother"; rm -rf "$o"; mkdir -p "$o"; ( cd "$o" && git init -q . && echo o > o.txt )
wtg "$o" add -A && wtg "$o" commit -q -m init && wtg "$o" worktree add -q --detach "$wd/7" || bad "could not make another repo's worktree"
ohead=$(git -C "$wd/7" rev-parse HEAD)
wtrun "$t" work 7 --worktree; check "exit code for another repository's worktree" "$?" "2"
[ -f "$work/wt.cwd" ] && bad "the orchestrator launched in another repository's worktree" || ok
has "$work/wt.log" "error: $wd/7 is not a worktree of this repository" "the path conflict is not named"
check "another repository's worktree is left as it was" "$(git -C "$wd/7" rev-parse HEAD) $(git -C "$wd/7" status --porcelain | wc -l | tr -d ' ')" "$ohead 0"
wtg "$o" worktree remove "$wd/7"

mkdir -p "$wd/7" && echo x > "$wd/7/f"
wtrun "$t" work 7 --worktree; check "exit code for a directory that is not a git tree" "$?" "2"
[ -f "$wd/7/f" ] && [ ! -f "$work/wt.cwd" ] && ok || bad "a plain directory was touched or the orchestrator launched"
rm -f "$wd/7/f"
wtrun "$t" work 7 --worktree; check "an empty directory becomes the worktree" "$?" "0"
check "the orchestrator runs inside the worktree made in an empty directory" "$(called 1)" "$real_wd/7"

wtrun "$t" retro x --worktree; check "exit code for an issue that is not a number" "$?" "2"
has "$work/wt.log" "error: --worktree needs an issue number (got x)" "the bad issue is not named"
[ ! -e "$wd/x" ] && [ ! -f "$work/wt.cwd" ] && ok || bad "something was made for an issue that is not a number"

for inside in "$t/trees" "rel/trees"; do
  "$root/bin/harness" set --target "$t" worktree.dir "$inside" >/dev/null 2>&1
  wtrun "$t" work 7 --worktree; check "exit code for worktree.dir $inside" "$?" "2"
  [ ! -e "$t/trees" ] && [ ! -e "$t/rel" ] && [ ! -f "$work/wt.cwd" ] && ok || bad "worktree.dir $inside made something or launched"
done
"$root/bin/harness" set --target "$t" worktree.dir "$wd" >/dev/null 2>&1

wtg "$t" remote rename origin upstream
wtrun "$t" work 7 --worktree; check "exit code when the fetch fails" "$?" "2"
[ ! -e "$wd/7" ] && [ ! -f "$work/wt.cwd" ] && ok || bad "a failed fetch made a worktree or launched"
wtg "$t" remote rename upstream origin

wtrun "$t" work 7 --worktree --dry-run; check "run --worktree --dry-run exit code" "$?" "0"
[ ! -e "$wd/7" ] && ok || bad "--dry-run made a worktree"
has "$work/wt.log" "worktree: $wd/7 (new)" "--dry-run does not show the worktree"
has "$work/wt.log" "/work 7" "--dry-run does not show the command"

mono="$work/wtmono"; rm -rf "$mono"; mkdir -p "$mono"; setup "$mono/sub"; wd2="$work/wtmono-trees"
"$root/bin/harness" set --target "$mono/sub" worktree.dir "$wd2" >/dev/null 2>&1
git init -q --bare -b development "$work/wtmono-origin.git"
( cd "$mono" && git init -q -b development . && echo a > tracked.txt )
wtg "$mono" add -A && wtg "$mono" commit -q -m "chore: 하네스" && wtg "$mono" remote add origin "$work/wtmono-origin.git" \
  && wtg "$mono" push -q origin development || bad "could not set up the monorepo worktree test repo"
wtrun "$mono/sub" work 7 --worktree; check "monorepo run --worktree exit code" "$?" "0"
check "in a monorepo the orchestrator runs at the harness root's place in the worktree" "$(called 1)" "$(cd "$wd2" && pwd -P)/7/sub"

echo "UT-72 a new worktree gets the ignored local files, and its hooks and guard are its own"
# UT-71 의 리포를 이어 쓴다. 무시 규칙은 checkout 이 가져가야 하므로 원격에 올린다
printf '.claude/settings.local.json\nlocal-dir/\n' >> "$t/.gitignore"
wtg "$t" add .gitignore && wtg "$t" commit -q -m "chore: 무시 규칙" && wtg "$t" push -q origin development || bad "could not push the ignore rules"
( cd "$t" && printf 'local\n' > .claude/settings.local.json && chmod 600 .claude/settings.local.json \
  && mkdir -p local-dir && echo d > local-dir/a && ln -sf a local-dir/ln && echo n > notignored.txt && echo changed > tracked.txt )
"$root/bin/harness" set --target "$t" worktree.include ".claude/settings.local.json,local-dir,notignored.txt,missing.txt,tracked.txt" >/dev/null 2>&1 \
  || bad "could not set worktree.include"
WT_ACT=keep wtrun "$t" work 8 --worktree; check "run --worktree with include exit code" "$?" "0"
cmp -s "$t/.claude/settings.local.json" "$wd/8/.claude/settings.local.json" && ok || bad "an ignored include file was not copied"
check "the copied file keeps its permission bits" "$(stat -c %a "$wd/8/.claude/settings.local.json" 2>/dev/null || stat -f %Lp "$wd/8/.claude/settings.local.json")" "600"
[ -f "$wd/8/local-dir/a" ] && [ -L "$wd/8/local-dir/ln" ] && ok || bad "an ignored directory was not copied whole with its symlink"
[ ! -e "$wd/8/notignored.txt" ] && ok || bad "a file git does not ignore was copied"
has "$work/wt.log" "warn: notignored.txt is not ignored by git — not copied" "the file git does not ignore was not warned about"
[ ! -e "$wd/8/missing.txt" ] && ok || bad "a missing include path appeared in the worktree"
hasnt "$work/wt.log" "missing.txt" "a missing include path was reported"
check "a tracked include path keeps the checkout's content" "$(cat "$wd/8/tracked.txt")" "a"
check "git status is clean after the copy" "$(wc -c < "$work/wt.cwd.status" | tr -d ' ')" "0"
hasnt "$work/wt.log" "settings.local.json" "run printed a copied path"
has "$work/wt.log" "kept worktree $wd/8 — uncommitted changes" "the kept worktree is not reported"
# 다시 열 때는 복사하지 않는다
rm -f "$wd/8/keep.me" "$wd/8/.claude/settings.local.json"
WT_ACT=keep wtrun "$t" work 8 --worktree; check "reopen with include exit code" "$?" "0"
has "$work/wt.log" "worktree: $wd/8 (reopened)" "the worktree was not reopened"
[ ! -e "$wd/8/.claude/settings.local.json" ] && ok || bad "a reopened worktree got the include files again"
# worktree 의 git 훅: core.hooksPath 의 상대 경로가 worktree 최상위 기준으로 풀린다
git -C "$t" config core.hooksPath script/githooks
rm -f "$wd/8/keep.me"; echo hook >> "$wd/8/tracked.txt"
wtg "$wd/8" commit -qam "not the commit form" > "$work/wthook.log" 2>&1; check "commit-msg in a worktree refuses a bad subject" "$?" "1"
has "$work/wthook.log" "commit subject does not match the required form" "the worktree's commit-msg hook did not run"
git -C "$t" config --unset core.hooksPath
# worktree 의 명령 가드: settings.json 의 훅 명령이 그 worktree 의 가드와 harness.env 를 부른다
gcmd=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["PreToolUse"][0]["hooks"][0]["command"])' "$wd/8/.claude/settings.json")
case "$gcmd" in '$CLAUDE_PROJECT_DIR/script/hooks/bash-guard.sh') ok ;; *) bad "the guard command is not under CLAUDE_PROJECT_DIR: $gcmd" ;; esac
printf '{"tool_input":{"command":"git push origin development"}}' | CLAUDE_PROJECT_DIR="$wd/8" sh -c "$gcmd" > "$work/wtguard.log" 2>&1
check "the worktree's guard blocks a push to a protected branch" "$?" "2"
wtg "$wd/8" checkout -q -- tracked.txt && wtg "$t" worktree remove "$wd/8" || bad "could not remove the include worktree"
"$root/bin/harness" set --target "$t" worktree.include ".claude/settings.local.json" >/dev/null 2>&1
# 모노레포: 실행 디렉터리 아래로 복사한다
printf '.claude/settings.local.json\n' > "$mono/sub/.gitignore"
wtg "$mono" add sub/.gitignore && wtg "$mono" commit -q -m "chore: 무시 규칙" && wtg "$mono" push -q origin development || bad "could not push the monorepo ignore rule"
echo local > "$mono/sub/.claude/settings.local.json"
WT_ACT=keep wtrun "$mono/sub" work 8 --worktree; check "monorepo run --worktree with include exit code" "$?" "0"
[ -f "$wd2/8/sub/.claude/settings.local.json" ] && [ ! -e "$wd2/8/.claude/settings.local.json" ] && ok \
  || bad "in a monorepo the include file was not copied under the harness root's place"

echo "UT-73 a worktree run carries only its issue number, and session import attributes each worktree's records to its run"
wtrun "$t" work 9 --worktree; check "run --worktree for the span exit code" "$?" "0"
wtrun "$t" work 9; check "run without --worktree for the span exit code" "$?" "0"
python3 - "$t.records/metrics" > "$work/wtspan.sum" <<'PY2'
import glob, json, sys
st = [json.loads(l) for f in sorted(glob.glob(sys.argv[1] + "/spans-*.jsonl")) for l in open(f)]
runs = [e["attrs"] for e in st if e["ev"] == "start" and e["name"] == "run/work" and e["attrs"].get("issue") == "9"]
print(len(runs), runs[0].get("worktree"), runs[1].get("worktree", "none"))
PY2
has "$work/wtspan.sum" "2 9 none" "the run span's worktree attribute is wrong (runs, with the flag, without)"
grep -rqF "wtrun-trees" "$t.records/metrics" && bad "a worktree path reached the spans" || ok
python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); sys.dont_write_bytecode = True; import metric; print(metric.clean_attrs(["worktree=../x", "issue=1"]), metric.clean_attrs(["worktree=12"]))' "$t/script" > "$work/wtattr.sum"
has "$work/wtattr.sum" "{'issue': '1'} {'worktree': '12'}" "metric.py does not keep only a numeric worktree attribute"
for wtcase in present removed; do
  ti="$work/wtimp-$wtcase"; setup "$ti"; wdi="$work/wtimp-$wtcase-trees"; cl="$work/wtimp-$wtcase-claude"; cx="$work/wtimp-$wtcase-codex"
  "$root/bin/harness" set --target "$ti" worktree.dir "$wdi" >/dev/null 2>&1
  [ "$wtcase" = present ] && mkdir -p "$wdi/7" "$wdi/8"
  python3 - "$ti" "$wdi" "$cl" "$cx" <<'PY2'
import datetime, json, os, re, sys
t, wd, cl, cx = sys.argv[1:5]
sys.path.insert(0, t + "/script"); sys.dont_write_bytecode = True
import metric
now = datetime.datetime.now(datetime.timezone.utc)
at = lambda m: now - datetime.timedelta(minutes=m)
ts = lambda m: at(m).strftime("%Y-%m-%dT%H:%M:%S.000Z")
for tr, vendor, wt in (("t-c7", "claude", "7"), ("t-c8", "claude", "8"), ("t-x7", "codex", "7"), ("t-x8", "codex", "8"), ("t-root", "claude", "")):
    attrs = {"workflow": "work", "vendor": vendor, **({"worktree": wt, "issue": wt} if wt else {})}
    _, run = metric.start("run/work", "command", attrs, trace=tr, parent="", source="runner", t=at(10))
    metric.end(run, "ok", 0, t=at(1))
def claude(path, n):
    d = os.path.join(cl, re.sub(r"[^A-Za-z0-9]", "-", path)); os.makedirs(d)
    open(d + "/s%d.jsonl" % n, "w").write(json.dumps({"type": "assistant", "sessionId": "s%d" % n, "timestamp": ts(5),
        "message": {"id": "m%d" % n, "model": "claude-x", "usage": {"input_tokens": n, "output_tokens": 0}}}) + "\n")
def codex(name, cwd, n):
    os.makedirs(cx, exist_ok=True)
    open(os.path.join(cx, "rollout-%s.jsonl" % name), "w").write("\n".join([
        json.dumps({"timestamp": ts(5), "type": "session_meta", "payload": {"id": name, "cwd": cwd}}),
        json.dumps({"timestamp": ts(5), "type": "token_usage_record", "payload": {"response_id": name, "usage": {"input_tokens": n, "output_tokens": 0}}})]) + "\n")
# 실행 디렉터리는 적힌 경로와 실제 경로 어느 쪽으로도 기록될 수 있다
claude(os.path.join(wd, "7"), 11)
claude(os.path.join(os.path.realpath(wd), "8"), 22)
codex("x7", os.path.join(wd, "7", "deeper"), 33)
codex("x8", os.path.join(os.path.realpath(wd), "8"), 44)
claude(os.path.realpath(t), 55)
codex("other", "/elsewhere", 66)
PY2
  HARNESS_CLAUDE_DIR="$cl" HARNESS_CODEX_DIR="$cx" "$root/bin/harness" metrics import --target "$ti" --since 1d > "$work/wtimp.json"
  check "metrics import with worktree runs ($wtcase)" "$?" "0"
  python3 - "$work/wtimp.json" "$HARNESS_HOME/my-project/state/import-cursor.json" "$cx" > "$work/wtimp.sum" <<'PY2'
import json, os, sys
d = json.load(open(sys.argv[1])); cur = json.load(open(sys.argv[2])); cx = sys.argv[3]
tok = {x["trace"]: x["tokens"] for x in d["traces"]}
other = lambda n: cur.get("codex:" + os.path.join(cx, "rollout-%s.jsonl" % n), {}).get("other")
print(tok.get("t-c7"), tok.get("t-c8"), tok.get("t-x7"), tok.get("t-x8"), tok.get("t-root"),
      d["diagnostics"]["imported"]["unattributed"], other("x7"), other("x8"), other("other"))
PY2
  has "$work/wtimp.sum" "11 22 33 44 55 0 False False True" "worktree records are not attributed to their own runs ($wtcase): c7 c8 x7 x8 root unattributed other-flags"
  rm -rf "$HARNESS_HOME/my-project/state"
done

echo
if [ "$fail" -eq 0 ]; then
  echo "render-test: ${pass} passed"
  exit 0
fi
echo "render-test: ${pass} passed, ${fail} failed" >&2
exit 1
