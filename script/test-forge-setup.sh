#!/usr/bin/env bash
# 원격 라벨 준비의 회귀 테스트 — 설정의 이슈 라벨을 넘기고, 빈 라벨을 건너뛰고, 실패를 종료 코드 2 로 알린다.
#
#   script/test-forge-setup.sh
#
# 종료 코드: 0 = 전 케이스 통과 · 1 = 실패한 케이스 있음 · 2 = 실행 실패
#
# 원격을 부르지 않는다. 하네스 루트의 사본을 임시 디렉터리에 만들고 forge 어댑터를 페이크로 갈아끼운다.
set -uo pipefail
# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 2
[ -f "$repo_root/script/forge-setup.sh" ] || { echo "error: script/forge-setup.sh is missing" >&2; exit 2; }
[ -f "$repo_root/script/harness.env" ] || { echo "error: script/harness.env is missing" >&2; exit 2; }

sandbox=$(mktemp -d) || exit 2
trap 'rm -rf "$sandbox"' EXIT

# 페이크 어댑터. 받은 라벨을 FAKE_STATE/ensured 에 한 줄씩 남긴다.
#   FAKE_REQUIRE=fail  tracker_require 가 실패한다
#   FAKE_ENSURE=fail   tracker_labels_ensure 가 실패한다
cat > "$sandbox/forge-fake.sh" <<'FAKE'
#!/usr/bin/env sh
tracker_require() {
  [ "${FAKE_REQUIRE:-}" = fail ] && { echo "error: fake is not signed in" >&2; return 2; }
  return 0
}
tracker_labels_ensure() {
  [ "${FAKE_ENSURE:-}" = fail ] && { echo "error: could not create label \`$1\`" >&2; return 1; }
  for _l in "$@"; do
    [ -n "$_l" ] || continue
    printf '%s\n' "$_l" >> "$FAKE_STATE/ensured"
  done
}
FAKE

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
# setup_run <requirement> <task> <invalid> [환경...] — 그 라벨 값의 사본에서 forge-setup.sh 를 돌린다
setup_run() {
  n=$((n + 1))
  local r="$sandbox/root-$n" req="$1" task="$2" inv="$3"; shift 3
  mkdir -p "$r/script" "$r/state" || return 2
  cp "$repo_root/script/forge-setup.sh" "$r/script/" || return 2
  grep -Ev '^ISSUE_LABEL_(REQUIREMENT|TASK|INVALID)=' "$repo_root/script/harness.env" > "$r/script/harness.env"
  printf 'ISSUE_LABEL_REQUIREMENT=%s\nISSUE_LABEL_TASK=%s\nISSUE_LABEL_INVALID=%s\n' "$req" "$task" "$inv" >> "$r/script/harness.env"
  cp "$sandbox/forge-fake.sh" "$r/script/forge.sh"
  state="$r/state"; out="$r/out"; err="$r/err"
  env FAKE_STATE="$state" "$@" bash "$r/script/forge-setup.sh" > "$out" 2> "$err"
}
tracker=$(sed -n 's/^FORGE_TRACKER=//p' "$repo_root/script/harness.env" | tr -d "\"'")

setup_run Req-x Task-x invalid-x
check ready "exit code" 0 "$?"
check ready "the three labels are passed" "Req-x Task-x invalid-x" "$(tr '\n' ' ' < "$state/ensured" | sed 's/ $//')"
check ready "stdout names the tracker and the labels" "forge-setup: labels ready on $tracker: Req-x, Task-x, invalid-x" "$(cat "$out")"

setup_run Req-x Task-x ""
check empty "exit code with an empty label" 0 "$?"
check empty "only the non-empty labels are passed" "Req-x Task-x" "$(tr '\n' ' ' < "$state/ensured" | sed 's/ $//')"
check empty "the list on stdout has no empty value" "forge-setup: labels ready on $tracker: Req-x, Task-x" "$(cat "$out")"

setup_run Req-x Task-x invalid-x FAKE_REQUIRE=fail
check require "exit code when the tracker cannot be used" 2 "$?"
check require "no label is passed" no "$([ -e "$state/ensured" ] && echo yes || echo no)"
check require "nothing on stdout" "" "$(cat "$out")"

setup_run Req-x Task-x invalid-x FAKE_ENSURE=fail
check ensure "exit code when a label cannot be made" 2 "$?"
check ensure "stderr says the labels were not prepared" 1 "$(grep -c "stop: could not prepare labels on $tracker" "$err" | tr -d ' ')"
check ensure "stderr carries the adapter's reason" 1 "$(grep -c 'could not create label `Req-x`' "$err" | tr -d ' ')"
check ensure "nothing on stdout" "" "$(cat "$out")"

echo
if [ "$fail" -gt 0 ]; then
  echo "forge setup test failed: $pass passed, $fail failed" >&2
  exit 1
fi
echo "forge setup test passed: $pass cases"
