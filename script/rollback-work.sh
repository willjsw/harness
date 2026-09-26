#!/usr/bin/env bash
# 이슈 하나에 대해 하네스가 만든 것을 되감는다.
#
#   script/rollback-work.sh <이슈번호> [--dry-run|--yes]
#
# 종료 코드: 0 = 되감았거나 되감을 것이 없음 · 1 = 사용자가 거절 · 2 = 실행 실패
#
# **잘못 돈 `work` 를 치우는 명령이다.** 되돌릴 수 없는 동작을 포함하므로 무엇이 바뀌는지
# 먼저 보이고 확인을 받는다 — `harness uninstall --purge` 와 같은 배치다.
#
# 되감는 것과 남기는 것을 명확히 가른다.
#
#   되감는다   열린 리뷰 요청(닫기) · 분해의 task 이슈(닫고 라벨) · 로컬 브랜치(삭제)
#   남긴다     요구사항 이슈 자신 · 원격 브랜치 · 커밋과 머지된 것 · 명세·분해 문서
#
# **요구사항 이슈를 닫지 않는다.** 그것은 사람이 만든 요구이고, 구현을 되감았다고 요구가
# 사라지는 것이 아니다. 다시 `work` 를 돌릴 수 있어야 한다.
#
# **원격 브랜치를 지우지 않는다.** 원격 삭제는 가드가 막는 동작이고, 남의 작업이 그 위에
# 올라가 있을 수 있다 — 명령만 알려 주고 사람이 판단한다.
#
# **이슈 삭제를 금지한 프로젝트에서는 닫고 라벨을 붙이는 것이 되감기의 전부다.** 지우지 못하므로
# 왜 닫혔는지가 라벨로 남아야 한다.
set -euo pipefail
# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. script/harness.env
. script/harness-format.sh
. script/forge.sh

usage() { echo "usage: script/rollback-work.sh <issue-number> [--dry-run|--yes]" >&2; exit 2; }

# 두 번째 인수를 느슨하게 받으면 오타가 조용히 실제 되감기 모드가 된다.
[ $# -ge 1 ] && [ $# -le 2 ] || usage
case "${2:-}" in ""|--dry-run|--yes) ;; *) echo "error: unknown option: $2" >&2; usage ;; esac
issue="$1"
mode="${2:-}"

ref() { printf '%s' "$ISSUE_REF_DISPLAY" | sed "s|{id}|$1|"; }

forge_require || exit 2
command -v python3 >/dev/null || { echo "error: python3 is not installed" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# ── 무엇이 있는지 모은다 ────────────────────────────────────────────────────
tracker_issue_view "$issue" > "$work/issue.json" || {
  echo "stop: could not read issue $issue" >&2; exit 2; }

open_mrs=$(harness_issue_open_mrs "$issue") || {
  echo "stop: could not query the review requests linked to issue $issue" >&2; exit 2; }

# task 이슈는 **승인된 분해**에서 나온 제목으로만 찾는다. 제목이 맞지 않는 이슈는 이 분해의
# 것이 아니므로 건드리지 않는다 — 되감기가 남의 이슈를 닫으면 되돌릴 수 없다.
: > "$work/tasks.txt"
prefix=$(git rev-parse --show-prefix 2>/dev/null) || {
  echo "stop: not inside a git repository" >&2; exit 2; }
if git fetch -q origin "$BASE_BRANCH" 2>/dev/null \
   && git show "FETCH_HEAD:${prefix}docs/plan/$issue/task.md" > "$work/task.md" 2>/dev/null; then
  tracker_issue_list > "$work/issues.json" || {
    echo "stop: could not list issues — refusing to roll back without knowing what exists" >&2
    exit 2; }
  python3 - "$issue" "$work" "$ISSUE_REF_DISPLAY" "$FMT_TASK_HEADING" <<'PY' || exit 2
import json, re, sys

issue, work, ref_display, task_heading = sys.argv[1:5]

issues = json.load(open(f"{work}/issues.json", encoding="utf-8"))
parts = re.split(task_heading, open(f"{work}/task.md", encoding="utf-8").read(), flags=re.M)

with open(f"{work}/tasks.txt", "w", encoding="utf-8") as out:
    for i in range(1, len(parts), 3):
        title = "%s(%s)" % (parts[i + 1].strip(), ref_display.format(id=issue))
        for x in issues:
            if (x.get("title") or "").strip() == title and (x.get("state") or "") != "closed":
                out.write("%s\t%s\t%s\n" % (parts[i], x.get("iid"), title))
                break
PY
fi

# 브랜치 이름은 `<태그>/<이슈>-<요약>` 이다. 그 문법으로만 찾는다.
git for-each-ref --format='%(refname:short)' "refs/heads/*/$issue-*" > "$work/local.txt" || true
git ls-remote --heads origin "*/$issue-*" 2>/dev/null \
  | sed 's|.*refs/heads/||' > "$work/remote.txt" || : > "$work/remote.txt"
current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# ── 보인다 ──────────────────────────────────────────────────────────────────
n_mr=$(printf '%s' "$open_mrs" | wc -w | tr -d ' ')
n_task=$(wc -l < "$work/tasks.txt" | tr -d ' ')
n_local=$(wc -l < "$work/local.txt" | tr -d ' ')

if [ "$n_mr" -eq 0 ] && [ "$n_task" -eq 0 ] && [ "$n_local" -eq 0 ]; then
  echo "nothing to roll back for issue $issue"
  exit 0
fi

echo "rollback target: issue $(ref "$issue")"
echo
echo "  will be closed or removed"
for m in $open_mrs; do echo "    review request !$m        closed, not merged"; done
while IFS=$'\t' read -r tid iid title; do
  [ -n "$tid" ] || continue
  printf '    task issue %-12s %s\n' "$(ref "$iid")" "$title"
done < "$work/tasks.txt"
while read -r b; do
  [ -n "$b" ] || continue
  if [ "$b" = "$current" ]; then
    echo "    local branch $b   ** checked out — will not be removed **"
  else
    echo "    local branch $b"
  fi
done < "$work/local.txt"
if [ -n "$ISSUE_LABEL_INVALID" ] && [ "$n_task" -gt 0 ]; then
  echo "    (task issues also get the \`$ISSUE_LABEL_INVALID\` label)"
fi
echo
echo "  left alone"
echo "    issue $(ref "$issue") itself — the requirement stays open so work can run again"
while read -r b; do
  [ -n "$b" ] || continue
  echo "    remote branch origin/$b — delete it yourself: git push origin --delete $b"
done < "$work/remote.txt"
echo "    commits, merged work, and the spec and breakdown documents"

if [ "$mode" = "--dry-run" ]; then
  echo
  echo "(dry-run) nothing was changed"
  exit 0
fi

if [ "$mode" != "--yes" ]; then
  if [ ! -t 0 ]; then
    echo >&2
    echo "stop: rollback needs a confirmation and this shell is not interactive" >&2
    echo "help: rerun with --yes if you mean it" >&2
    exit 2
  fi
  printf '\nroll these back? [y/N] '
  read -r answer || answer=""
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "stop: nothing was changed"; exit 1 ;;
  esac
fi

# ── 되감는다 ────────────────────────────────────────────────────────────────
# **리뷰 요청을 먼저 닫는다.** task 이슈를 먼저 닫으면 열린 리뷰 요청이 닫힌 이슈를 가리키는
# 중간 상태가 남고, 거기서 실패하면 무엇이 되감겼는지 읽기 어려워진다.
failed=0
for m in $open_mrs; do
  if review_mr_close "$m"; then
    echo "closed review request !$m"
  else
    echo "warning: could not close review request !$m" >&2; failed=1
  fi
done

while IFS=$'\t' read -r tid iid title; do
  [ -n "$tid" ] || continue
  if tracker_issue_close "$iid" "$ISSUE_LABEL_INVALID"; then
    echo "closed task issue $(ref "$iid")  $tid"
  else
    echo "warning: could not close task issue $(ref "$iid")" >&2; failed=1
  fi
done < "$work/tasks.txt"

while read -r b; do
  [ -n "$b" ] || continue
  if [ "$b" = "$current" ]; then
    echo "kept local branch $b — it is checked out. switch away and rerun to remove it"
    continue
  fi
  # 머지되지 않은 커밋이 있어도 지운다 — 되감기가 그 목적이다. 원격 브랜치는 그대로 남아 있어
  # 여기서 잃는 것은 로컬 참조뿐이다.
  if git branch -D "$b" >/dev/null 2>&1; then
    echo "removed local branch $b"
  else
    echo "warning: could not remove local branch $b" >&2; failed=1
  fi
done < "$work/local.txt"

if [ "$failed" -ne 0 ]; then
  echo "stop: rollback finished with failures — check the warnings above" >&2
  exit 2
fi
echo "rollback complete for issue $(ref "$issue")"
