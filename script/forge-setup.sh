#!/usr/bin/env bash
# 설정의 이슈 라벨을 트래커에 미리 만든다. **원격에 쓴다** — 사람이 한 번 부른다(`harness forge-setup`).
# 절차·훅·다른 명령은 이 스크립트를 부르지 않는다.
#
#   script/forge-setup.sh
#
# 종료 코드: 0 = 라벨 준비됨 · 2 = 트래커를 쓸 수 없거나 라벨을 만들지 못함
#
# 만드는 것은 `issues.labels` 의 requirement · task · invalid 뿐이다. 빈 값은 건너뛴다.
# 회차 라벨은 리뷰 요청에 붙일 때 만들어지고, 이슈·리뷰 요청 템플릿은 render 가 만든다.
set -uo pipefail
# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)" || exit 2
. script/harness.env || exit 2
. script/forge.sh || exit 2

tracker_require || exit 2

if ! tracker_labels_ensure "$ISSUE_LABEL_REQUIREMENT" "$ISSUE_LABEL_TASK" "$ISSUE_LABEL_INVALID"; then
  echo "stop: could not prepare labels on $FORGE_TRACKER" >&2
  exit 2
fi

ready=""
for l in "$ISSUE_LABEL_REQUIREMENT" "$ISSUE_LABEL_TASK" "$ISSUE_LABEL_INVALID"; do
  [ -n "$l" ] && ready="${ready:+$ready, }$l"
done
echo "forge-setup: labels ready on $FORGE_TRACKER: ${ready:-none}"
