#!/usr/bin/env bash
# 어댑터의 라벨 준비 회귀 테스트 — GitHub 은 만들지 못한 라벨을 삼키지 않고 그때 이슈·리뷰 요청을 바꾸지 않는다.
# Jira 는 라벨을 미리 두지 않으므로 원격을 부르지 않는다.
#
#   script/test-forge-labels.sh
#
# 종료 코드: 0 = 전 케이스 통과 · 1 = 실패한 케이스 있음 · 2 = 실행 실패
#
# 원격을 부르지 않는다. `gh` · `jira` 스텁을 PATH 앞에 두고 받은 인수를 기록한다.
set -uo pipefail
# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
root=$(pwd)
[ -f "$root/script/forge/github.sh" ] || { echo "error: script/forge/github.sh is missing" >&2; exit 2; }

sandbox=$(mktemp -d) || exit 2
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin" || exit 2

# 스텁의 동작은 환경 변수로 정한다.
#   STUB_CREATE_FAIL  label create 가 실패할 라벨(공백 구분)
#   STUB_EXISTING     label list 가 낼 라벨(공백 구분)
#   STUB_LIST_FAIL    1 이면 label list 가 실패한다
cat > "$sandbox/bin/gh" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_LOG"
case "$1 $2" in
  "label create")
    for l in ${STUB_CREATE_FAIL:-}; do
      if [ "$3" = "$l" ]; then
        echo "HTTP 403: Resource not accessible by integration" >&2
        exit 1
      fi
    done
    exit 0 ;;
  "label list")
    [ "${STUB_LIST_FAIL:-}" = 1 ] && { echo "HTTP 500" >&2; exit 1; }
    # shellcheck disable=SC2086
    python3 -c 'import json, sys; print(json.dumps([{"name": n} for n in sys.argv[1:]]))' ${STUB_EXISTING:-}
    exit 0 ;;
  "issue create") echo "https://example.invalid/o/r/issues/7"; exit 0 ;;
esac
exit 0
SH
chmod +x "$sandbox/bin/gh" || exit 2

pass=0
fail=0
check() {
  local id="$1" name="$2" want="$3" got="$4"
  if [ "$want" = "$got" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "fail [$id] $name — want '$want', got '$got'" >&2
  fi
}

n=0
# adapter <함수> <인수...> — 어댑터를 새 셸에 source 하고 함수 하나를 부른다. 기록은 $log, 표준 오류는 $err
adapter() {
  n=$((n + 1)); log="$sandbox/calls-$n.log"; err="$sandbox/err-$n.log"; : > "$log"
  (
    export PATH="$sandbox/bin:$PATH" STUB_LOG="$log"
    _FORGE_WANT_TRACKER=1 _FORGE_WANT_REVIEW=1
    . "$root/script/forge/_common.sh"
    . "$root/script/forge/github.sh"
    "$@"
  ) > "$sandbox/out-$n.log" 2> "$err"
}
calls() { grep -c -- "$1" "$log" | tr -d ' '; }

adapter _gh_ensure_label Task
check created "exit code when the label is created" 0 "$?"
check created "label create called once" 1 "$(calls '^label create Task ')"

STUB_CREATE_FAIL=Task STUB_EXISTING="Task Bug" adapter _gh_ensure_label Task
check exists "exit code when the label already exists" 0 "$?"
check exists "the remote was asked whether it exists" 1 "$(calls '^label list')"
check exists "nothing on stderr" "" "$(cat "$err")"

STUB_CREATE_FAIL=Task STUB_EXISTING="Bug" adapter _gh_ensure_label Task
rc=$?
check missing "exit code when the label could not be made" 1 "$rc"
check missing "stderr names the label" 1 "$(grep -c 'error: could not create label `Task`' "$err" | tr -d ' ')"
check missing "stderr carries the last line of label create" 1 "$(grep -c 'HTTP 403: Resource not accessible by integration' "$err" | tr -d ' ')"

STUB_CREATE_FAIL=Task STUB_LIST_FAIL=1 adapter _gh_ensure_label Task
check list-fails "a failed lookup is not taken as existing" 1 "$?"

STUB_CREATE_FAIL=First adapter _gh_ensure_label First Second
check stops "exit code when the first of two labels fails" 1 "$?"
check stops "the second label is not tried" 0 "$(calls '^label create Second ')"

STUB_CREATE_FAIL=Task adapter tracker_issue_create "title" /dev/null Task "" ""
check issue-create "tracker_issue_create fails when its label could not be made" 1 "$?"
check issue-create "issue create is not called" 0 "$(calls '^issue create')"

adapter tracker_issue_create "title" /dev/null Task "" ""
check issue-create-ok "tracker_issue_create succeeds when the label is made" 0 "$?"
check issue-create-ok "the created issue id" 7 "$(cat "$sandbox/out-$n.log")"

STUB_CREATE_FAIL=invalid adapter tracker_issue_close 12 invalid
check issue-close "tracker_issue_close fails when its label could not be made" 1 "$?"
check issue-close "the issue is neither edited nor closed" 0 "$(calls '^issue ')"

STUB_CREATE_FAIL=round:2 adapter review_mr_labels_set 5 round:2 round:1
check mr-labels "review_mr_labels_set fails when its label could not be made" 1 "$?"
check mr-labels "the pull request is not edited" 0 "$(calls '^pr edit')"

# 계약 함수 tracker_labels_ensure — 빈 인수는 건너뛰고, 인수가 없으면 부르지 않으며, 실패를 전달한다
adapter tracker_labels_ensure "" Task
check ensure-skip "exit code with an empty argument" 0 "$?"
check ensure-skip "only the non-empty label is created" "label create Task --color ededed" "$(grep '^label create' "$log")"

adapter tracker_labels_ensure
check ensure-none "exit code with no arguments" 0 "$?"
check ensure-none "gh is not called" 0 "$(grep -c . "$log" | tr -d ' ')"

STUB_CREATE_FAIL=Second adapter tracker_labels_ensure First Second Third
check ensure-fail "exit code when the second label fails" 1 "$?"
check ensure-fail "stderr names the failed label" 1 "$(grep -c 'could not create label `Second`' "$err" | tr -d ' ')"
check ensure-fail "the label after it is not tried" 0 "$(calls '^label create Third ')"

STUB_CREATE_FAIL=Task STUB_EXISTING=Task adapter tracker_labels_ensure Task
check ensure-exists "an existing label is a success" 0 "$?"

# Jira 는 라벨을 미리 두지 않는다 — 원격을 부르지 않고 성공한다
if [ -f "$root/script/forge/jira.sh" ]; then
  cp "$sandbox/bin/gh" "$sandbox/bin/jira"
  n=$((n + 1)); log="$sandbox/calls-$n.log"; : > "$log"
  (
    export PATH="$sandbox/bin:$PATH" STUB_LOG="$log"
    _FORGE_WANT_TRACKER=1 _FORGE_WANT_REVIEW=0
    . "$root/script/forge/_common.sh"
    . "$root/script/forge/jira.sh"
    tracker_labels_ensure Requirement Task
  ) >/dev/null 2>&1
  check jira "Jira's tracker_labels_ensure exits 0" 0 "$?"
  check jira "Jira's tracker_labels_ensure calls nothing" 0 "$(grep -c . "$log" | tr -d ' ')"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "forge labels test failed: $pass passed, $fail failed" >&2
  exit 1
fi
echo "forge labels test passed: $pass cases"
