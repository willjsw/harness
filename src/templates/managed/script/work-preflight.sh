#!/usr/bin/env bash
# 이슈 하나에 대해 구현 착수가 가능한지 판정하고, 가능하면 어느 경로인지 출력한다.
#
#   script/work-preflight.sh <이슈번호>
#
# 출력(stdout): `plan` = 분해가 있는 경로 · `standalone` = 분해 없는 단독 task
# 종료 코드: 0 = 착수 가능 · 1 = 착수 불가(사유를 stderr 로) · 2 = 실행 실패
#           닫힌 이슈는 1, 이슈 조회 실패(없는 번호·인증·네트워크·권한, 읽히지 않는 상태)는 2
#
# **착수 전과 구현 위임 직전에 같은 명령을 돌린다.** 판정을 두 곳에 따로 적으면 한쪽에 검사를
# 더할 때 다른 쪽이 낡는다. 두 결과가 다르면 그 사이에 원격이 바뀐 것이므로 위임하지 않는다.
#
# 검사 순서가 결과를 바꾼다. 이슈 자체를 먼저 보고, 그다음 열린 리뷰 요청을 본다 — 두 검사 사이에
# spec+plan 이 머지되면 분해를 먼저 본 경우 "분해 없음 + 열린 것 없음" 이 되어 단독 task 로 오판한다.
set -euo pipefail
# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# 실행 지표 — 이 스크립트 한 번을 스팬으로 남긴다(script/metric.py). 출력·종료 코드는 그대로다
[ "${HARNESS_METRIC_SELF:-}" = work-preflight ] || [ ! -x script/metric.py ] || \
  exec env HARNESS_METRIC_SELF=work-preflight script/metric.py wrap --name work-preflight --kind script --attr script=work-preflight -- "$PWD/script/work-preflight.sh" "$@"
root=$(pwd)
. script/harness.env

if [ $# -ne 1 ]; then echo "usage: script/work-preflight.sh <issue-number>" >&2; exit 2; fi
issue="$1"

log() { "$root/script/usage-log.sh" preflight work-preflight "$1" || true; }

# git 객체 경로는 **리포 루트 기준**이다. 모노레포에서 하네스 루트가 하위 디렉터리면
# `docs/plan/...` 이 그대로는 맞지 않는다 — 현재 위치의 접두를 앞에 붙인다.
prefix=$(git rev-parse --show-prefix 2>/dev/null) || {
  echo "stop: not inside a git repository" >&2; exit 2; }

# ⓪ 이슈 — 닫혔거나 읽히지 않으면 착수하지 않는다. 분해가 있어도 인수로 받은 이슈만 본다.
#    닫힘은 정규화 JSON 의 state 로만 가른다. 없는 이슈는 따로 가르지 않고 조회 실패로 다룬다.
. script/forge.sh
tracker_require || exit 2
set +e
issue_json=$(tracker_issue_view "$issue")
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  log issue-query-failed
  echo "stop: could not read issue $issue from the tracker" >&2
  echo "help: check that the issue exists and that the tracker CLI is signed in" >&2
  exit 2
fi
state=$(printf '%s' "$issue_json" | python3 -c '
import json, sys
try:
    v = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
print((v.get("state") or "") if isinstance(v, dict) else "")
' 2>/dev/null || true)
case "$state" in
  open|opened) ;;
  closed)
    log issue-closed
    echo "stop: issue $issue is closed" >&2
    exit 1 ;;
  *)
    log issue-query-failed
    echo "stop: could not read the state of issue $issue" >&2
    exit 2 ;;
esac

# ① 열린 리뷰 요청 — 있으면 착수하지 않는다.
set +e
open_mrs=$(script/check-open-mrs.sh "$issue")
rc=$?
set -e
case "$rc" in
  0) ;;
  1) log open-mr
     echo "stop: issue $issue already has an open review request ($open_mrs)" >&2
     echo "  it is either a spec+plan awaiting approval or an implementation already in flight" >&2
     exit 1 ;;
  *) log mr-query-failed
     exit 2 ;;
esac

# ② 분해 — 로컬 작업 트리가 아니라 방금 fetch 한 원격의 통합 브랜치를 읽는다.
#    승인된 분해로만 착수가 열린다는 게이트를 이 스크립트가 지킨다.
git fetch -q origin "$BASE_BRANCH" || {
  log fetch-failed
  echo "stop: git fetch failed — refusing to decide from a stale ref" >&2
  exit 2
}

if ! git cat-file -e "FETCH_HEAD:${prefix}docs/plan/$issue/task.md" 2>/dev/null; then
  log standalone
  echo "standalone"
  exit 0
fi

# ③ 분해가 있으면 그것이 근거로 삼는 명세도 있어야 한다.
#    명세가 지워지거나 이름이 바뀌면 분해만 남고, 완료 조건의 근거가 가리키는 곳이 없어진다.
if ! git ls-tree --name-only FETCH_HEAD "${prefix}docs/spec/" | grep -q "^${prefix}docs/spec/$issue-"; then
  log spec-missing
  echo "stop: docs/plan/$issue/ has a breakdown but no matching spec at docs/spec/$issue-*.md" >&2
  echo "help: the completion criteria point at nothing — run prework to settle the spec first" >&2
  exit 1
fi

log plan
echo "plan"
