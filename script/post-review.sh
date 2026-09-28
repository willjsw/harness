#!/usr/bin/env bash
# 리뷰어의 판정 데이터를 검증해 리뷰 요청에 등록하고 판정을 종료 코드로 돌려준다.
#
#   script/post-review.sh <리뷰요청번호> <리뷰본문파일> [작성자표시] [리뷰한리비전]
#
# 종료 코드: 0 = PASS(blocker·major 0건) · 1 = CHANGES_REQUESTED · 2 = 등록·계약 실패
#            3 = 한 파일에 blocker·major 가 상한 회차 연속 — 코드가 아니라 명세를 다시 본다
#
# 리뷰어 출력은 판정 데이터(info string 이 표지 `FMT_REVIEW_BLOCK` 인 JSON 블록 하나)다.
# **판정은 발견 등급 집계로 한다.** 데이터의 `verdict` 는 계약 준수 확인용이고, 루프를 끝낼지는
# `findings` 의 blocker·major 건수가 정한다 — minor 만 남았는데 루프가 계속 도는 일을 막는다.
# 등록하는 요약·인라인 댓글은 리뷰어 출력 원문이 아니라 그 데이터로 렌더링한다.
#
# blocker·major 는 해당 diff 라인에 인라인으로, 전체 요약은 댓글 1건으로 등록한다.
# minor 는 인라인으로 달지 않는다 — 소음이 판정을 묻는다.
#
# 반복은 세션의 기억이 아니라 파일이 센다. 어느 파일에 blocker·major 가 나온 회차를
# `<git-dir>/work-loop/` 아래에 누적한다(커밋 대상 아님, 리뷰 요청 단위).
# **키는 파일 경로 하나이고, 연속한 회차만 센다.** 같은 뿌리의 결함은 회차마다 다른 문장으로
# 나오고 등급도 흔들려서, 요지나 심각도를 키에 넣으면 매 회차가 새 지적이 되어 상한이 발동하지
# 않는다. 서로 다른 파일의 독립 결함은 경로만으로 이미 갈린다. 줄 번호도 넣지 않는다 —
# 고칠 때마다 바뀐다. blocker·major 가 없던 회차도 자리표시자로 남긴다. 남기지 않으면 회차
# 번호가 멈춰, 깨끗하게 지나간 회차가 연속을 끊지 못한다.
#
# **이 카운트는 보조 상한이다.** 주 상한은 review-mr.sh 가 올리는 회차 라벨이고, 그건 원격에
# 있어 클론이 바뀌어도 유지된다. 반복 카운트는 "같은 지적이 반복되면 코드가 아니라 명세가
# 틀렸다" 를 **한 실행 환경 안에서** 잡는 신호라서, 다른 기기·새 클론에서 이어 돌리면 0 부터
# 다시 센다. 그래도 회차 상한이 루프를 끝낸다. 원격에서 복원하지 않는다 — 댓글을 파싱해
# 이력을 되살리는 방식은 형식 변경에 취약하고, 틀린 상한은 없는 것보다 나쁘다.
#
# 이 스크립트는 판정 데이터를 읽기만 하고 계약을 새로 정의하지 않는다. 검증·집계·렌더링은
# `script/_review.py` 의 `judge` · `render` 가 하고, 형식 문자열의 정본은 `script/harness-format.sh` 다.
#
# **블록 밖의 텍스트는 읽지 않는다.** 블록이 없거나 둘 이상이거나 JSON 이 아니거나 스키마를
# 하나라도 어기면 계약 위반이다 — 아무것도 등록하지 않고 종료 코드 2 다. 형식을 지키지 못한
# 출력은 발견 목록도 믿을 수 없으므로, 여기서 추측해 읽지 않고 리뷰를 다시 돌린다.
#
# 이 스크립트가 존재하는 이유: 등록에는 원격 쓰기 권한이 필요하지만 리뷰어는 읽기 전용이어야
# 한다. 등록을 여기로 분리해 리뷰 수행 주체에게 쓰기 도구를 주지 않는다.
set -euo pipefail
# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. script/harness.env
# 표지는 script/_review.py 가 환경에서 읽으므로 export 한다.
set -a
. script/harness-format.sh
set +a
. script/forge.sh
REVIEW_PY=script/_review.py

if [ $# -lt 2 ]; then echo "usage: script/post-review.sh <review-request-number> <review-body-file> [author-label] [reviewed-revision]" >&2; exit 2; fi
mr="$1"
body="$2"
label="${3:-자동 리뷰}"
reviewed="${4:-}"

review_require || exit 2
command -v python3 >/dev/null || { echo "error: python3 is not installed" >&2; exit 2; }
[ -s "$body" ] || { echo "error: the review body is empty: $body" >&2; exit 2; }

# 리뷰한 리비전을 받았으면 형식을 확인한다. 틀린 값을 그대로 적으면 다음 회차가 없는 커밋을
# 기준으로 증분을 만들거나, 기준을 읽지 못해 조용히 누적 diff 로 물러난다.
if [ -n "$reviewed" ] && ! printf '%s' "$reviewed" | grep -qE '^[0-9a-f]{7,40}$'; then
  echo "error: the reviewed revision is not a SHA, got '$reviewed'" >&2
  echo "help: nothing was posted — a wrong baseline would misalign the next round incremental diff" >&2
  exit 2
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# 이번 리뷰가 본 리비전. 다음 회차가 증분 diff 의 기준으로 읽으므로 요약 노트에 남긴다.
# **부르는 쪽이 넘긴 값이 우선이다** — 리뷰 도중 커밋이 생기면 지금 HEAD 는 리뷰하지 않은
# 리비전이고, 그것을 기준으로 적으면 그 커밋의 변경이 다음 회차의 증분에서 빠진다.
head_sha="$reviewed"
[ -n "$head_sha" ] || head_sha=$(git rev-parse HEAD 2>/dev/null || true)

# 이력은 로컬 git 디렉터리에 둔다 — 클론이 바뀌면 초기화된다(상단 주석: 보조 상한).
hist_dir="$(git rev-parse --git-dir)/work-loop"
hist="$hist_dir/review-findings-$mr.tsv"
mkdir -p "$hist_dir"

# 판정 데이터를 한 번만 검증해 인라인 대상·등급 집계·반복 횟수를 함께 낸다. 읽는 곳이 둘이면
# "발견 하나"의 기준이 갈라져 인라인과 판정이 서로 다른 것을 센다.
parse_rc=0
python3 "$REVIEW_PY" judge "$body" "$hist" "$REVIEW_REPEAT_FILE_MAX" "$work" || parse_rc=$?

if [ "$parse_rc" -ne 0 ]; then
  echo "help: nothing was posted — the raw review follows" >&2
  cat "$body" >&2
  exit 2
fi

read -r n_blocker n_major n_minor < "$work/counts"
computed=$(cat "$work/computed")

inline_ok=0
inline_fail=0
while IFS=$'\t' read -r -d '' file line note; do
  if err=$(review_mr_note_inline "$mr" "$file" "$line" "$note" 2>&1 >/dev/null); then
    inline_ok=$((inline_ok + 1))
  else
    # 이번 diff 에 없는 줄이면 실패한다. 줄 번호를 추측해 재시도하지 않는다 —
    # 해당 발견은 아래 요약 본문에 그대로 남는다.
    inline_fail=$((inline_fail + 1))
    echo "warning: inline comment failed (it still appears in the summary): $file:$line — $(printf '%s' "$err" | tr -d '\n' | tail -c 200)" >&2
  fi
done < "$work/inline"

python3 "$REVIEW_PY" render "$work" "$label" "$head_sha" "$inline_fail" "$REVIEW_REPEAT_FILE_MAX" \
  || { echo "error: could not render the summary — nothing was posted" >&2; exit 2; }

review_mr_note_summary "$mr" "$work/note.md" \
  || { echo "error: posting the summary failed — the review body follows:" >&2; cat "$work/note.md" >&2; exit 2; }

# 등록에 성공한 회차만 누적한다. 등록 실패는 리뷰가 남지 않았으므로 회차로 세지 않는다.
if [ -f "$work/reset" ]; then : > "$hist"; fi
cat "$work/append" >> "$hist"

echo "posted to $mr: $inline_ok inline, 1 summary · blocker $n_blocker · major $n_major · minor $n_minor -> $computed"

if [ -s "$work/repeat" ]; then
  echo "stop: the same file drew a blocker or major ${REVIEW_REPEAT_FILE_MAX} rounds running — more edits will not fix this" >&2
  while IFS=$'\t' read -r seen key; do echo "  - $seen rounds running: $key" >&2; done < "$work/repeat"
  echo "help: stop editing, propose returning to the spec stage, and hand off" >&2
  exit 3
fi

[ "$computed" = "$FMT_VERDICT_PASS" ] && exit 0 || exit 1
