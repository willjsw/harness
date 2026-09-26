#!/usr/bin/env sh
# 계약을 지키는 forge 어댑터 페이크. `test/render-test.sh` 가 자체 검사를 검사하는 데 쓴다.
#
# **자체 검사는 실제 forge 를 상대로 도는 도구이므로 그 자신은 검사되지 않는다.**
# 계약을 지키는 페이크를 통과시키고 어기는 페이크를 잡아내야, 자체 검사의 판정을 믿을 수 있다.
#
# `FAKE_BREAK` 에 함수 이름을 주면 그 함수만 계약을 어긴다.
#   mr_view      head_sha 를 뺀다
#   threads      스레드에 inline 키를 뺀다
#   issue_list   대상 이슈를 목록에서 뺀다 (첫 페이지만 도는 어댑터를 흉내)
#   open_mrs     이슈↔리뷰 요청 연결을 찾지 못한다
#   inline_any   diff 밖 줄에도 인라인을 단다
#   create_url   생성 결과로 식별자가 아니라 URL 을 돌려준다
set -u
: "${FAKE_BREAK:=}"
: "${FAKE_STATE:?FAKE_STATE 가 필요하다}"

forge_require()       { return 0; }
tracker_require()     { return 0; }
review_require()      { return 0; }
tracker_current_user() { echo "user-a"; }

review_mr_view() {
  python3 - "$1" "$FAKE_BREAK" "$(cat "$FAKE_STATE/labels" 2>/dev/null || true)" <<'PY'
import json, sys
mr, brk, labels = sys.argv[1], sys.argv[2], sys.argv[3]
out = {"iid": mr, "source_branch": "feat/100-selftest",
       "head_sha": "0123456789abcdef0123456789abcdef01234567",
       "description": "Closes 100", "labels": labels.split(), "state": "opened"}
if brk == "mr_view":
    del out["head_sha"]
json.dump(out, sys.stdout, ensure_ascii=False)
PY
}

review_mr_diff() {
  printf 'diff --git a/sample.txt b/sample.txt\n--- a/sample.txt\n+++ b/sample.txt\n@@ -1,2 +1,3 @@\n 첫 줄\n+더한 줄\n 셋째 줄\n'
}

review_mr_threads() {
  python3 - "$FAKE_BREAK" "$FAKE_STATE" <<'PY'
import json, os, sys
brk, state = sys.argv[1], sys.argv[2]
out = []
p = os.path.join(state, "notes.json")
if os.path.exists(p):
    out = json.load(open(p, encoding="utf-8"))
if brk == "threads":
    for t in out:
        t.pop("inline", None)
    if not out:
        out = [{"path": "", "line": "", "notes": [{"body": "x", "created_at": ""}]}]
json.dump(out, sys.stdout, ensure_ascii=False)
PY
}

review_mr_list_open() {
  printf '[{"iid":"1","source_branch":"feat/100-selftest","description":"Closes 100","head_sha":"0123456789abcdef0123456789abcdef01234567","labels":[],"state":"opened"}]'
}

tracker_issue_view() {
  # 실제 트래커처럼 식별자만 받는다. URL 을 넘기면 조회에 실패한다 —
  # 생성 함수가 식별자 대신 URL 을 돌려주는 어댑터를 자체 검사가 잡을 수 있어야 한다.
  case "$1" in
    *[!0-9A-Za-z-]*) echo "이슈를 찾지 못했다: $1" >&2; return 1 ;;
  esac
  python3 - "$1" <<'PY'
import json, sys
json.dump({"iid": sys.argv[1], "title": "자체 검사 대상", "state": "opened",
           "description": "본문", "labels": [], "assignee": "user-a",
           "milestone": "M1"}, sys.stdout, ensure_ascii=False)
PY
}

tracker_issue_list() {
  python3 - "$FAKE_BREAK" <<'PY'
import json, sys
items = [{"iid": str(i), "title": "다른 이슈 %d" % i, "state": "opened"} for i in range(1, 30)]
if sys.argv[1] != "issue_list":
    items.append({"iid": "100", "title": "자체 검사 대상", "state": "opened"})
json.dump(items, sys.stdout, ensure_ascii=False)
PY
}

harness_issue_open_mrs() {
  [ "$FAKE_BREAK" = open_mrs ] && { echo ""; return 0; }
  echo "1"
}

review_mr_labels_set() { # <n> <붙일것> <뗄것>
  _add=$2; _rm=$3
  _kept=""
  for _l in $(cat "$FAKE_STATE/labels" 2>/dev/null || true); do
    _keep=1
    for _d in $_rm; do [ "$_l" = "$_d" ] && _keep=0; done
    [ "$_keep" = 1 ] && _kept="$_kept $_l"
  done
  printf '%s\n' $_kept $_add | sort -u | tr '\n' ' ' | sed 's/ *$//' > "$FAKE_STATE/labels"
}

_fake_add_note() { # <inline> <path> <line> <본문>
  python3 - "$FAKE_STATE/notes.json" "$1" "$2" "$3" "$4" <<'PY'
import json, os, sys
path, inline, f, line, body = sys.argv[1:6]
cur = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else []
cur.append({"inline": inline == "1", "path": f, "line": line,
            "notes": [{"body": body, "created_at": "2026-01-01T00:00:00Z"}]})
json.dump(cur, open(path, "w", encoding="utf-8"), ensure_ascii=False)
PY
}

# 실제 어댑터처럼 diff 안의 줄에만 단다. `inline_any` 면 그 제약을 잃는다.
review_mr_note_inline() { # <n> <파일> <줄> <본문>
  if [ "$FAKE_BREAK" != inline_any ] && [ "$3" -gt 100 ]; then
    echo "diff 에 없는 줄이다: $2:$3" >&2
    return 1
  fi
  _fake_add_note 1 "$2" "$3" "$4"
}

review_mr_note_summary() { _fake_add_note 0 "" "" "$(cat "$2")"; }

tracker_issue_create() {
  [ "$FAKE_BREAK" = create_url ] && { echo "https://forge.invalid/proj/-/issues/42"; return 0; }
  echo 42
}
