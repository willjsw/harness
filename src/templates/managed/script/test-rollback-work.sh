#!/usr/bin/env bash
# 되감기의 회귀 테스트 — 무엇을 닫고 무엇을 남기는지.
#
#   script/test-rollback-work.sh
#
# 종료 코드: 0 = 전 케이스 통과 · 1 = 실패한 케이스 있음 · 2 = 실행 실패
#
# 원격을 부르지 않는다. 임시 리포와 로컬 bare 원격을 만들고 **forge 어댑터를 페이크로
# 갈아끼워** 어떤 닫기 호출이 나갔는지만 본다.
#
# **남기는 쪽이 이 테스트의 요점이다.** 되감기는 되돌릴 수 없으므로, 요구사항 이슈와 원격
# 브랜치를 건드리지 않는다는 것이 닫는 동작 자체보다 중요하다.
set -uo pipefail

command -v python3 >/dev/null || { echo "error: python3 is required to run this test" >&2; exit 2; }

# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 2
. "$repo_root/script/harness.env"
. "$repo_root/script/harness-format.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

work="$sandbox/repo"
state="$sandbox/state"
mkdir -p "$state" "$work/script"

cp "$repo_root/script/rollback-work.sh" "$work/script/"
cp "$repo_root/script/harness.env" "$repo_root/script/harness-format.sh" "$work/script/"
chmod +x "$work/script/"*.sh

# ── forge 페이크 ────────────────────────────────────────────────────────────
# 계약(`script/forge/_common.sh` 상단)이 정한 정규화 JSON 을 상태 파일에서 돌려준다.
# 닫기 호출은 인수까지 기록한다 — 무엇을 닫았는지가 이 테스트가 보는 전부다.
cat > "$work/script/forge.sh" <<'FAKE'
#!/usr/bin/env sh
tracker_require() { return 0; }
review_require()  { return 0; }
forge_require()   { return 0; }
tracker_issue_view() { cat "$FAKE_STATE/issue.json"; }
tracker_issue_list() { cat "$FAKE_STATE/issues.json"; }
harness_issue_open_mrs() { cat "$FAKE_STATE/open-mrs" 2>/dev/null || echo ""; }
tracker_issue_close() { printf 'issue=%s label=%s\n' "$1" "$2" >> "$FAKE_STATE/closed"; }
review_mr_close()     { printf 'mr=%s\n' "$1" >> "$FAKE_STATE/closed"; }
FAKE

# ── 임시 리포와 로컬 원격 ───────────────────────────────────────────────────
git() { command git -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.invalid "$@"; }

git init -q --bare "$sandbox/origin.git" || { echo "error: could not create the temp remote" >&2; exit 2; }
git init -q "$work" || { echo "error: could not create the temp repo" >&2; exit 2; }
git -C "$work" symbolic-ref HEAD "refs/heads/$BASE_BRANCH"
git -C "$work" remote add origin "$sandbox/origin.git"

mkdir -p "$work/docs/plan/100"
cat > "$work/docs/plan/100/task.md" <<'MD'
## T1 · feat: 모듈 골격 구성

본문

## T2 · feat: 입력 검증 유틸

본문
MD
git -C "$work" add -A >/dev/null
git -C "$work" commit -q -m "docs: 분해" >/dev/null || { echo "error: could not commit" >&2; exit 2; }
git -C "$work" push -q origin "$BASE_BRANCH" || { echo "error: could not push" >&2; exit 2; }

# 되감을 브랜치와, 되감으면 안 되는 브랜치(다른 이슈)를 함께 둔다.
git -C "$work" branch "feat/100-skeleton"
git -C "$work" branch "feat/101-other"
git -C "$work" push -q origin "feat/100-skeleton" || { echo "error: could not push a branch" >&2; exit 2; }

# ── 조회 응답 ───────────────────────────────────────────────────────────────
ref() { printf '%s' "$ISSUE_REF_DISPLAY" | sed "s|{id}|$1|"; }
t1="feat: 모듈 골격 구성($(ref 100))"
t2="feat: 입력 검증 유틸($(ref 100))"

printf '{"iid":"100","title":"요구사항","state":"opened","description":"","labels":[],"assignee":"user-a","milestone":"M1"}\n' \
  > "$sandbox/issue.json"
python3 - "$sandbox/issues.json" "$t1" "$t2" <<'PY'
import json, sys
json.dump([{"iid": "7", "title": sys.argv[2], "state": "opened"},
           {"iid": "8", "title": sys.argv[3], "state": "closed"},
           {"iid": "9", "title": "feat: 남의 이슈(#101)", "state": "opened"}],
          open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PY

# ── 실행 도우미 ─────────────────────────────────────────────────────────────
pass=0; fail=0
check() { # <ID> <무엇> <기대> <실제>
  if [ "$3" = "$4" ]; then
    pass=$((pass + 1))
  else
    echo "  FAIL $1 $2 → want '$3', got '$4'" >&2; fail=$((fail + 1))
  fi
}
line_hits() { [ -f "$2" ] || { echo 0; return; }; grep -cxF -- "$1" "$2" || true; }
hits()      { [ -f "$2" ] || { echo 0; return; }; grep -cF  -- "$1" "$2" || true; }

setup() { # <열린 리뷰 요청 목록>
  cp "$sandbox/issue.json" "$state/issue.json"
  cp "$sandbox/issues.json" "$state/issues.json"
  printf '%s' "$1" > "$state/open-mrs"
  rm -f "$state/closed"
  git -C "$work" checkout -q "$BASE_BRANCH"
  git -C "$work" branch -f "feat/100-skeleton" >/dev/null 2>&1 || \
    git -C "$work" branch "feat/100-skeleton" >/dev/null 2>&1
  git -C "$work" branch -f "feat/101-other" >/dev/null 2>&1 || \
    git -C "$work" branch "feat/101-other" >/dev/null 2>&1
}

closes() { [ -f "$state/closed" ] && wc -l < "$state/closed" | tr -d ' ' || echo 0; }
branches() {  # 현재 브랜치 목록을 파일로 떨어뜨리고 그 경로를 낸다
  git -C "$work" for-each-ref --format='%(refname:short)' refs/heads/ > "$state/branches.txt"
  printf '%s' "$state/branches.txt"
}

run() {
  ( cd "$work" && FAKE_STATE="$state" \
      script/rollback-work.sh "$@" >"$state/last.out" 2>"$state/last.err" </dev/null )
  echo $?
}

echo "UT-01 a dry run names everything and changes nothing"
setup "12"
check UT-01 "exit code" 0 "$(run 100 --dry-run)"
check UT-01 "close calls" 0 "$(closes)"
check UT-01 "names the review request" 1 "$(hits 'review request !12' "$state/last.out")"
check UT-01 "names the open task issue" 1 "$(hits "$t1" "$state/last.out")"
# 이미 닫힌 task 이슈는 되감을 것이 없다.
check UT-01 "leaves the closed task issue out" 0 "$(hits "$t2" "$state/last.out")"
check UT-01 "names the local branch" 1 "$(hits 'local branch feat/100-skeleton' "$state/last.out")"
check UT-01 "does not name another issue's branch" 0 "$(hits 'feat/101-other' "$state/last.out")"
check UT-01 "says the requirement issue stays" 1 "$(hits 'the requirement stays open' "$state/last.out")"
check UT-01 "hands the remote branch back to a person" 1 \
  "$(hits 'git push origin --delete feat/100-skeleton' "$state/last.out")"
before=$(cat "$(branches)")
check UT-01 "branches untouched" "$before" "$(cat "$(branches)")"

echo "UT-02 without a confirmation nothing is changed"
# 되돌릴 수 없는 명령이다. 비대화형에서 조용히 도는 것이 가장 나쁜 경우다.
setup "12"
check UT-02 "exit code" 2 "$(run 100)"
check UT-02 "close calls" 0 "$(closes)"
check UT-02 "the local branch survives" 1 "$(line_hits 'feat/100-skeleton' "$(branches)")"

echo "UT-03 --yes closes the review request and the open task issues"
setup "12"
check UT-03 "exit code" 0 "$(run 100 --yes)"
check UT-03 "closed the review request" 1 "$(line_hits 'mr=12' "$state/closed")"
check UT-03 "closed the open task issue with the label" 1 \
  "$(line_hits "issue=7 label=$ISSUE_LABEL_INVALID" "$state/closed")"
check UT-03 "did not reopen-and-close the closed one" 0 "$(hits 'issue=8' "$state/closed")"
check UT-03 "did not touch another issue's task" 0 "$(hits 'issue=9' "$state/closed")"
# **요구사항 이슈는 닫지 않는다.** 요구는 사람의 것이고 되감기는 구현만 되돌린다.
check UT-03 "did not close the requirement issue" 0 "$(hits 'issue=100' "$state/closed")"
check UT-03 "removed the local branch" 0 "$(line_hits 'feat/100-skeleton' "$(branches)")"
check UT-03 "kept another issue's branch" 1 "$(line_hits 'feat/101-other' "$(branches)")"
# 원격 브랜치는 남는다 — 지우는 것은 사람이 판단한다.
check UT-03 "kept the remote branch" 1 \
  "$(git -C "$work" ls-remote --heads origin 'feat/100-skeleton' | grep -c . || true)"

echo "UT-04 a branch that is checked out is kept"
setup "12"
git -C "$work" checkout -q "feat/100-skeleton"
check UT-04 "exit code" 0 "$(run 100 --yes)"
check UT-04 "the branch survives" 1 "$(line_hits 'feat/100-skeleton' "$(branches)")"
check UT-04 "says why" 1 "$(hits 'it is checked out' "$state/last.out")"
git -C "$work" checkout -q "$BASE_BRANCH"

echo "UT-05 nothing to roll back is not a failure"
setup ""
git -C "$work" branch -D "feat/100-skeleton" >/dev/null 2>&1
python3 - "$state/issues.json" <<'PY'
import json, sys
json.dump([], open(sys.argv[1], "w", encoding="utf-8"))
PY
check UT-05 "exit code" 0 "$(run 100)"
check UT-05 "close calls" 0 "$(closes)"
check UT-05 "says so" 1 "$(hits 'nothing to roll back' "$state/last.out")"

echo "UT-06 argument validation"
setup "12"
check UT-06 "no argument — exit code" 2 "$(run)"
check UT-06 "mistyped option — exit code" 2 "$(run 100 --dryrun)"
check UT-06 "close calls" 0 "$(closes)"

echo
if [ "$fail" -gt 0 ]; then
  echo "rollback test failed: ${pass} passed, ${fail} failed" >&2
  echo "last run output:" >&2
  cat "$state/last.out" "$state/last.err" >&2
  exit 1
fi
echo "rollback test passed: ${pass} cases"
