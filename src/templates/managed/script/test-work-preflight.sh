#!/usr/bin/env bash
# 착수 판정의 회귀 테스트 — 열린 이슈는 지금 판정 그대로, 닫힌 이슈와 읽히지 않는 이슈에는 착수하지 않는다.
#
#   script/test-work-preflight.sh
#
# 종료 코드: 0 = 전 케이스 통과 · 1 = 실패한 케이스 있음 · 2 = 실행 실패
#
# 원격을 부르지 않는다. 임시 리포와 로컬 bare 원격을 만들고 forge 어댑터를 페이크로 갈아끼운다.
set -uo pipefail
# 훅이 넘긴 GIT_DIR·GIT_INDEX_FILE 같은 리포 지역 변수를 비운다. 남아 있으면 임시 리포를 만드는
# git init 이 임시 디렉터리 대신 그 변수가 가리키는 리포를 다시 초기화한다.
unset $(git rev-parse --local-env-vars 2>/dev/null)

command -v python3 >/dev/null || { echo "error: python3 is required to run this test" >&2; exit 2; }

# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 2
for f in work-preflight.sh check-open-mrs.sh usage-log.sh usage-vocab.sh harness.env; do
  [ -f "$repo_root/script/$f" ] || { echo "error: script/$f is missing" >&2; exit 2; }
done
. "$repo_root/script/harness.env"

sandbox=$(mktemp -d) || exit 2
trap 'rm -rf "$sandbox"' EXIT
state="$sandbox/state"
mkdir -p "$state" || exit 2

# 페이크 어댑터. 이슈의 상태는 FAKE_ISSUE 로 정한다.
#   open · opened · closed  그 state 를 낸다
#   fail                    조회 명령이 실패한다
#   empty                   state 가 빈 JSON 을 낸다
#   garbage                 JSON 이 아닌 출력을 낸다
#   weird                   알 수 없는 state 를 낸다
# 열린 리뷰 요청 조회는 FAKE_STATE/calls 에 남긴다.
cat > "$sandbox/forge-fake.sh" <<'FAKE'
#!/usr/bin/env sh
tracker_require() { return 0; }
review_require()  { return 0; }
tracker_issue_view() {
  printf 'tracker_issue_view %s\n' "$1" >> "$FAKE_STATE/calls"
  case "$FAKE_ISSUE" in
    fail)    echo "could not resolve issue $1" >&2; return 1 ;;
    empty)   printf '{"iid":"%s","title":"t","state":"","description":"","labels":[],"assignee":"","milestone":""}' "$1" ;;
    garbage) printf 'not json' ;;
    weird)   printf '{"iid":"%s","state":"archived"}' "$1" ;;
    *)       printf '{"iid":"%s","title":"t","state":"%s","description":"","labels":[],"assignee":"","milestone":""}' "$1" "$FAKE_ISSUE" ;;
  esac
}
harness_issue_open_mrs() {
  printf 'harness_issue_open_mrs %s\n' "$1" >> "$FAKE_STATE/calls"
  echo ""
}
FAKE

git() { command git -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.invalid "$@"; }

# 하네스 루트 하나와 로컬 원격. 분해가 있는 이슈(200)와 없는 이슈(100)를 원격 통합 브랜치에 둔다.
repo="$sandbox/repo"
mkdir -p "$repo/script" || exit 2
for f in work-preflight.sh check-open-mrs.sh usage-log.sh usage-vocab.sh harness.env; do
  cp "$repo_root/script/$f" "$repo/script/" || exit 2
done
cp "$sandbox/forge-fake.sh" "$repo/script/forge.sh"
chmod +x "$repo/script/"*.sh
git init -q --bare "$sandbox/origin.git" || exit 2
git init -q "$repo" || exit 2
git -C "$repo" symbolic-ref HEAD "refs/heads/$BASE_BRANCH"
git -C "$repo" remote add origin "$sandbox/origin.git"
mkdir -p "$repo/docs/plan/200" "$repo/docs/spec"
printf '# 분해\n' > "$repo/docs/plan/200/task.md"
printf '# 명세\n' > "$repo/docs/spec/200-something.md"
git -C "$repo" add -A >/dev/null
git -C "$repo" commit -q -m "docs: 분해" >/dev/null || exit 2
git -C "$repo" push -q origin "$BASE_BRANCH" 2>/dev/null || exit 2

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
# preflight <이슈 상태> <이슈> — 판정을 돌린다. 출력은 $out · $err, 사용 기록은 $ulog, 어댑터 호출은 $state/calls
preflight() {
  n=$((n + 1)); out="$sandbox/out-$n"; err="$sandbox/err-$n"; ulog="$sandbox/usage-$n.log"
  : > "$state/calls"
  ( cd "$repo" && env FAKE_STATE="$state" FAKE_ISSUE="$1" "$USAGE_ENV_VAR=$ulog" HARNESS_METRIC_SELF=work-preflight \
      ./script/work-preflight.sh "$2" ) > "$out" 2> "$err"
}
last_label() { [ -f "$ulog" ] && tail -1 "$ulog" | cut -d'|' -f4 || echo "(none)"; }
asked_mrs() { grep -c '^harness_issue_open_mrs' "$state/calls" | tr -d ' '; }

for st in open opened; do
  preflight "$st" 100
  check "open-$st" "exit code for an open issue without a breakdown" 0 "$?"
  check "open-$st" "standalone" standalone "$(cat "$out")"
  check "open-$st" "the issue was read" 1 "$(grep -c '^tracker_issue_view 100$' "$state/calls" | tr -d ' ')"
  check "open-$st" "open review requests were checked" 1 "$(asked_mrs)"
done

preflight open 200
check plan "exit code for an open issue with a breakdown" 0 "$?"
check plan "plan" plan "$(cat "$out")"
check plan "the requirement issue is the one read" 1 "$(grep -c '^tracker_issue_view 200$' "$state/calls" | tr -d ' ')"

preflight closed 100
check closed "exit code for a closed issue" 1 "$?"
check closed "stderr says the issue is closed" "stop: issue 100 is closed" "$(cat "$err")"
check closed "no verdict on stdout" "" "$(cat "$out")"
check closed "open review requests were not checked" 0 "$(asked_mrs)"
check closed "the usage label" issue-closed "$(last_label)"

preflight closed 200
check closed-plan "a closed issue with a breakdown is not started either" 1 "$?"

preflight fail 100
check query-failed "exit code when the issue cannot be read" 2 "$?"
check query-failed "stderr says the issue could not be read" 1 "$(grep -c '^stop: could not read issue 100 from the tracker$' "$err" | tr -d ' ')"
check query-failed "stderr carries the help line" 1 "$(grep -c '^help: check that the issue exists and that the tracker CLI is signed in$' "$err" | tr -d ' ')"
check query-failed "open review requests were not checked" 0 "$(asked_mrs)"
check query-failed "the usage label" issue-query-failed "$(last_label)"

for st in empty garbage weird; do
  preflight "$st" 100
  check "state-$st" "exit code when the state cannot be read" 2 "$?"
  check "state-$st" "stderr says the state could not be read" "stop: could not read the state of issue 100" "$(cat "$err")"
  check "state-$st" "open review requests were not checked" 0 "$(asked_mrs)"
  check "state-$st" "the usage label" issue-query-failed "$(last_label)"
done

echo
if [ "$fail" -gt 0 ]; then
  echo "work preflight test failed: $pass passed, $fail failed" >&2
  exit 1
fi
echo "work preflight test passed: $pass cases"
