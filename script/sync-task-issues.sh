#!/usr/bin/env bash
# `docs/plan/<상위이슈>/task.md` 의 task 절을 이슈 트래커와 맞춘다.
#
#   script/sync-task-issues.sh <상위이슈번호> [--dry-run]
#
# 종료 코드: 0 = 동기화 완료 · 2 = 실행 실패(분해 없음·조회 실패·필수 값 누락 포함)
#
# 제목으로 기존 이슈를 찾아 **있으면 건너뛰고 없는 것만 만든다.** 두 번 돌려도 중복이 생기지 않는다.
#
# **동시 실행은 막는다. 막지 못한 경합은 만들기 전에 잡는다.** 이슈 삭제를 금지한 프로젝트에서는
# 중복 이슈가 닫힌 채 영구히 남으므로, 의심스러우면 만들지 않는 쪽으로 넘어진다. 층이 셋이다.
#
#   1. 같은 상위 이슈에 대한 두 번째 실행을 잠금으로 막는다 (같은 기계 한정)
#   2. 이미 중복 제목이 목록에 있으면 과거 경합의 흔적이다 — 만들지 않고 충돌 지점을 낸다
#   3. 계획을 세운 뒤 만들기 직전에 목록을 다시 읽는다. 그 사이에 생긴 것이 있으면 멈춘다
#
# 3 이 다른 기계·CI 에서 동시에 도는 경우까지 받는다. 잠금은 기계 안에서만 유효하다.
#
# **분해는 로컬 작업 트리가 아니라 방금 fetch 한 원격의 통합 브랜치에서 읽는다.** 승인된
# 분해로만 이슈가 생긴다는 게이트를 스크립트 자신이 지킨다 — 미승인 브랜치에서 직접 돌려도
# 승인 전 task 이슈가 생기지 않는다.
#
# 출력은 `T1 #6 skip(opened)` 형식 한 줄씩. 구현자는 이 매핑으로 커밋 메시지의 이슈 번호를 정한다.
set -euo pipefail
# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# 실행 지표 — 이 스크립트 한 번을 스팬으로 남긴다(script/metric.py). 출력·종료 코드는 그대로다
[ "${HARNESS_METRIC_SELF:-}" = sync-task-issues ] || [ ! -x script/metric.py ] || \
  exec env HARNESS_METRIC_SELF=sync-task-issues script/metric.py wrap --name sync-task-issues --kind script --attr script=sync-task-issues -- "$PWD/script/sync-task-issues.sh" "$@"
. script/harness.env
. script/harness-format.sh
. script/forge.sh

usage() { echo "usage: script/sync-task-issues.sh <parent-issue-number> [--dry-run]" >&2; exit 2; }

# 두 번째 인수를 느슨하게 받으면 `--dryrun` 같은 오타가 조용히 실제 생성 모드가 된다.
# 이슈 삭제가 금지된 프로젝트에서는 그 실수를 되돌릴 수 없다 — 모르는 인수는 거부한다.
[ $# -ge 1 ] && [ $# -le 2 ] || usage
case "${2:-}" in ""|--dry-run) ;; *) echo "error: unknown option: $2" >&2; usage ;; esac
parent="$1"
dry="${2:-}"

ref() { printf '%s' "$ISSUE_REF_DISPLAY" | sed "s|{id}|$1|"; }

tracker_require || exit 2
command -v python3 >/dev/null || { echo "error: python3 is not installed" >&2; exit 2; }

work=$(mktemp -d)

# (1) 같은 상위 이슈에 대한 동시 실행을 막는다. `mkdir` 은 원자적이라 잠금 하나로 충분하다.
# 리포 안이 아니라 기계의 임시 디렉터리에 둔다 — 잠금은 작업 산출물이 아니고 커밋 대상도 아니다.
# 같은 리포의 다른 체크아웃끼리는 경로가 달라 서로를 막지 않는다.
lock="${TMPDIR:-/tmp}/harness-sync-$(printf '%s' "$PWD" | cksum | cut -d' ' -f1)-$parent"
if ! mkdir "$lock" 2>/dev/null; then
  echo "stop: another sync is already running for issue $parent" >&2
  echo "  lock: $lock" >&2
  [ -f "$lock/owner" ] && sed 's/^/  /' "$lock/owner" >&2
  echo "help: wait for it to finish. if nothing is running, the last run was killed --" >&2
  echo "        rm -rf $lock" >&2
  rm -rf "$work"
  exit 2
fi
printf 'pid: %s\nhost: %s\nstarted: %s\n' "$$" "$(hostname)" "$(date '+%Y-%m-%d %H:%M:%S')" \
  > "$lock/owner"
trap 'rm -rf "$work" "$lock"' EXIT

# git 객체 경로는 **리포 루트 기준**이다. 모노레포에서 하네스 루트가 하위 디렉터리면
# 현재 위치의 접두를 앞에 붙여야 같은 파일을 가리킨다.
prefix=$(git rev-parse --show-prefix 2>/dev/null) || {
  echo "stop: not inside a git repository" >&2; exit 2; }

git fetch -q origin "$BASE_BRANCH" || {
  echo "stop: git fetch failed — refusing to create issues from a stale breakdown" >&2; exit 2; }
git show "FETCH_HEAD:${prefix}docs/plan/$parent/task.md" > "$work/task.md" 2>/dev/null || {
  echo "stop: docs/plan/$parent/task.md is not on the remote integration branch" >&2
  echo "help: the breakdown is not approved and merged yet — rerun after it lands" >&2
  exit 2; }

tracker_issue_view "$parent" > "$work/parent.json" || {
  echo "stop: could not read parent issue $parent" >&2; exit 2; }
tracker_issue_list > "$work/issues.json" || {
  echo "stop: could not list issues — refusing to create any without a duplicate check" >&2; exit 2; }

# 계획을 먼저 세운다. 만들기 전에 전부 검사해, 절반만 만들어진 상태를 피한다.
python3 - "$parent" "$work" "$ISSUE_REF_DISPLAY" "$ISSUE_REQUIRED_FIELDS" "$FMT_TASK_HEADING" <<'PY' || exit 2
import json, os, re, sys

parent, work, ref_display, required, task_heading = sys.argv[1:6]


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)


meta = json.load(open(f"{work}/parent.json", encoding="utf-8"))
issues = json.load(open(f"{work}/issues.json", encoding="utf-8"))
src = open(f"{work}/task.md", encoding="utf-8").read()

# 필수 필드는 상위 이슈에서 물려받는다. 하나라도 없으면 만들지 않는다 —
# 규칙을 깬 이슈는 삭제가 금지된 프로젝트에서 영구히 남는다.
missing = [f for f in required.split() if not (meta.get(f) or "").strip()]
if missing:
    die("stop: parent issue %s has no %s, and task issues must inherit it\n"
        "help: set it on the parent issue first, then rerun" % (parent, ", ".join(missing)))

parts = re.split(task_heading, src, flags=re.M)
if len(parts) < 4:
    die("stop: no task section found in %s (expected `## T<N> · <title>`)" % f"docs/plan/{parent}/task.md")

# split 결과는 [머리말, id, 제목, 본문, id, 제목, 본문, ...]
plan = []
for i in range(1, len(parts), 3):
    tid, head, body = parts[i], parts[i + 1].strip(), parts[i + 2]
    title = "%s(%s)" % (head, ref_display.format(id=parent))
    same = [x for x in issues if (x.get("title") or "").strip() == title]
    plan.append((tid, title, body.strip(), same[0] if same else None, same))

# (2) 같은 제목이 둘 이상이면 과거에 경합이 있었다는 뜻이다. 어느 쪽이 정본인지 스크립트가
# 정할 수 없고, 삭제가 금지된 프로젝트에서는 되돌릴 수도 없다 — 사람에게 넘긴다.
dup = [(tid, title, [x.get("iid") for x in same]) for tid, title, _b, _h, same in plan if len(same) > 1]
if dup:
    die("stop: duplicate task issues already exist - refusing to touch this breakdown\n"
        + "\n".join("  %s  %s  ->  %s" % (t, ti, ", ".join(str(i) for i in ids)) for t, ti, ids in dup)
        + "\nhelp: a concurrent run created these. close all but one, then rerun")

# 쓰지 않는 칸은 비우지 않고 `-` 로 채운다. 탭은 공백류라 bash `read` 가 연속 탭을 구분자
# 하나로 합치고, 그러면 필드가 한 칸씩 밀려 제목이 본문 파일 자리로 들어간다.
with open(f"{work}/plan.tsv", "w", encoding="utf-8") as fp, \
     open(f"{work}/to-create.txt", "w", encoding="utf-8") as tf:
    for n, (tid, title, body, hit, _same) in enumerate(plan):
        if hit:
            fp.write("skip\t%s\t%s\t-\t%s\n" % (tid, hit["iid"], hit.get("state") or "-"))
            continue
        bodyfile = f"{work}/body-{n}.md"
        open(bodyfile, "w", encoding="utf-8").write(body + "\n")
        fp.write("create\t%s\t-\t%s\t%s\n" % (tid, bodyfile, title))
        tf.write("%s\t%s\n" % (tid, title))

print("breakdown tasks: %d  ·  to create: %d"
      % (len(plan), sum(1 for p in plan if not p[3])), file=sys.stderr)
PY

# (3) 계획과 생성 사이에 다른 실행이 끼어들 수 있다 -- 다른 기계·CI 는 잠금이 닿지 않는다.
# 만들기 직전에 목록을 다시 읽어 그 사이에 생긴 것이 있으면 **하나도 만들지 않고** 멈춘다.
if [ -s "$work/to-create.txt" ] && [ "$dry" != "--dry-run" ]; then
  tracker_issue_list > "$work/issues-recheck.json" || {
    echo "stop: could not re-read the issue list - refusing to create without a fresh check" >&2
    exit 2; }
  python3 - "$work" <<'RECHECK_PY' || exit 2
import json, sys

work = sys.argv[1]
issues = json.load(open(f"{work}/issues-recheck.json", encoding="utf-8"))
before = {(x.get("title") or "").strip() for x in
          json.load(open(f"{work}/issues.json", encoding="utf-8"))}

hits = []
for line in open(f"{work}/to-create.txt", encoding="utf-8"):
    tid, title = line.rstrip("\n").split("\t", 1)
    if title in before:
        continue
    for x in issues:
        if (x.get("title") or "").strip() == title:
            hits.append((tid, title, x.get("iid")))
            break

if hits:
    print("stop: these task issues appeared while this run was planning - created nothing",
          file=sys.stderr)
    for tid, title, iid in hits:
        print("  %s  %s  ->  %s" % (tid, title, iid), file=sys.stderr)
    print("help: another sync ran at the same time, probably on another machine or in CI.\n"
          "      rerun - the second pass skips what already exists", file=sys.stderr)
    sys.exit(2)
RECHECK_PY
fi

assignee=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["assignee"])' "$work/parent.json")
milestone=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["milestone"])' "$work/parent.json")

while IFS=$'\t' read -r action tid iid bodyfile extra; do
  case "$action" in
    skip)
      echo "$tid $(ref "$iid")  skip($extra)"
      ;;
    create)
      if [ "$dry" = "--dry-run" ]; then
        echo "$tid (dry-run) create  $extra"
        continue
      fi
      new=$(tracker_issue_create "$extra" "$bodyfile" "$ISSUE_LABEL_TASK" "$assignee" "$milestone") || {
        echo "stop: issue creation failed — $extra" >&2; exit 2; }
      [ -n "$new" ] || { echo "stop: could not read the number of the issue just created — $extra" >&2; exit 2; }
      echo "$tid $(ref "$new")  created"
      ;;
  esac
done < "$work/plan.tsv"
