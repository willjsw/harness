#!/usr/bin/env sh
# forge 어댑터 — GitLab / glab. 계약은 `script/forge/_common.sh` 상단이 정본이다.
#
# **검증 상태: 미검증.** 정규화 JSON 계약에 맞춰 다시 쓴 뒤 실제 리포에서 돌려보지 않았다.
# `script/forge-selftest.sh <리뷰요청번호> <이슈번호>` 를 전 단계까지 통과시키면 이 줄을 지운다.
#
# **함수군은 따로 켜진다.** 이슈 트래커와 리뷰 호스트를 서로 다른 forge 로 고를 수 있어야 하므로,
# `script/forge.sh` 가 `_FORGE_WANT_TRACKER` / `_FORGE_WANT_REVIEW` 를 세우고 이 파일을 source 한다.
# 그렇지 않으면 뒤에 source 된 어댑터가 앞 어댑터의 함수를 덮는다.
#
# 이 파일은 source 전용이다. 직접 실행하지 않는다.
set -u

GITLAB_CLI=glab

_gl_norm_issue='
import json, sys
def one(d):
    a = (d.get("assignees") or [{}])[0] if d.get("assignees") else {}
    return {
        "iid": str(d.get("iid") or ""),
        "title": d.get("title") or "",
        "state": d.get("state") or "",
        "description": d.get("description") or "",
        "labels": [l.get("name") if isinstance(l, dict) else str(l) for l in (d.get("labels") or [])],
        "assignee": a.get("username") or "",
        "milestone": (d.get("milestone") or {}).get("title") or "",
    }
v = json.load(sys.stdin)
json.dump([one(x) for x in v] if isinstance(v, list) else one(v), sys.stdout, ensure_ascii=False)
'

_gl_norm_mr='
import json, sys
def one(d):
    refs = d.get("diff_refs") or {}
    return {
        "iid": str(d.get("iid") or ""),
        "source_branch": d.get("source_branch") or "",
        "head_sha": refs.get("head_sha") or d.get("sha") or "",
        "description": d.get("description") or "",
        "labels": [l.get("name") if isinstance(l, dict) else str(l) for l in (d.get("labels") or [])],
        "state": d.get("state") or "",
    }
v = json.load(sys.stdin)
json.dump([one(x) for x in v] if isinstance(v, list) else one(v), sys.stdout, ensure_ascii=False)
'

# 목록 API 는 한 번에 한 페이지만 준다. per_page 를 키우는 것만으로는 부족하다 —
# 마지막 페이지가 가득 차면 다음 페이지에 남은 것이 있을 수 있다.
_gl_paged() {
  _path="$1"
  _page=1
  printf '['
  _first=1
  while :; do
    case "$_path" in *\?*) _sep='&' ;; *) _sep='?' ;; esac
    _batch=$("$GITLAB_CLI" api "${_path}${_sep}per_page=100&page=${_page}") || return 1
    _n=$(printf '%s' "$_batch" | python3 -c 'import json,sys; v=json.load(sys.stdin); print(len(v) if isinstance(v,list) else -1)') || return 1
    [ "$_n" -ge 0 ] || { echo "error: list response is not an array: $_path" >&2; return 1; }
    [ "$_n" -eq 0 ] && break
    [ "$_first" -eq 1 ] || printf ','
    _first=0
    printf '%s' "$_batch" | python3 -c 'import json,sys; s=json.dumps(json.load(sys.stdin),ensure_ascii=False); sys.stdout.write(s[1:-1])'
    [ "$_n" -lt 100 ] && break
    _page=$((_page + 1))
  done
  printf ']'
}

# ── 이슈 트래커 ──────────────────────────────────────────────────────────────

if [ "${_FORGE_WANT_TRACKER:-0}" = 1 ]; then

tracker_require() {
  command -v "$GITLAB_CLI" >/dev/null || { echo "error: $GITLAB_CLI is not installed" >&2; return 2; }
}

tracker_issue_view() {
  "$GITLAB_CLI" api "projects/:id/issues/$1" | python3 -c "$_gl_norm_issue"
}

tracker_issue_list() {
  _gl_paged "projects/:id/issues" | python3 -c "$_gl_norm_issue"
}

tracker_issue_create() {
  # <제목> <본문파일> <라벨> <담당자> <마일스톤>
  _cmd_title="$1"; _cmd_body="$2"; _cmd_label="$3"; _cmd_assignee="$4"; _cmd_ms="$5"
  _out=$(
    set -- issue create --title "$_cmd_title" --description "$(cat "$_cmd_body")"
    [ -n "$_cmd_label" ]    && set -- "$@" --label "$_cmd_label"
    [ -n "$_cmd_assignee" ] && set -- "$@" --assignee "$_cmd_assignee"
    [ -n "$_cmd_ms" ]       && set -- "$@" --milestone "$_cmd_ms"
    "$GITLAB_CLI" "$@"
  ) || return 1
  # glab 은 만든 이슈의 URL 을 낸다. 번호는 그 끝이다.
  printf '%s\n' "$_out" | sed -n 's|.*/\([0-9][0-9]*\)[^0-9]*$|\1|p' | tail -1
}

tracker_issue_note() {
  "$GITLAB_CLI" issue note create "$1" -m "$2" >/dev/null
}

# 라벨을 먼저 붙이고 닫는다. GitLab 은 붙이는 순간 라벨을 만들어 주므로 사전 생성이 없다.
tracker_issue_close() {
  if [ -n "$2" ]; then
    "$GITLAB_CLI" issue update "$1" --label "$2" >/dev/null || return 1
  fi
  "$GITLAB_CLI" issue close "$1" >/dev/null
}

tracker_current_user() {
  "$GITLAB_CLI" api user | python3 -c 'import json,sys; print(json.load(sys.stdin).get("username",""))'
}

# 로그인 여부만 본다. glab 의 출력에는 계정 정보가 있어 옮기지 않는다.
tracker_auth() {
  "$GITLAB_CLI" auth status </dev/null >/dev/null 2>&1 && return 0
  echo 'run `glab auth login`' >&2
  return 1
}

tracker_labels() {
  _gl_paged "projects/:id/labels" </dev/null | python3 -c '
import json, sys
v = json.load(sys.stdin)
if not isinstance(v, list):
    raise SystemExit("label list is not an array")
json.dump([x["name"] for x in v], sys.stdout, ensure_ascii=False)
'
}

# 검증 상태: 미검증. 실제 GitLab 으로 돌려보지 않았다 — 이미 있다는 실패는 glab 오류의 `already exists` · `409` 로 가른다.
# 그 밖의 실패는 그 라벨과 glab 의 오류 끝 줄을 표준 오류로 내고 1. 뒤 라벨로 가지 않는다.
tracker_labels_ensure() {
  for _l in "$@"; do
    [ -n "$_l" ] || continue
    _gl_err=$("$GITLAB_CLI" label create --name "$_l" --color "#ededed" </dev/null 2>&1 >/dev/null) && continue
    case "$_gl_err" in *"already exists"*|*"409"*) continue ;; esac
    echo "error: could not create label \`$_l\`" >&2
    _gl_tail=$(printf '%s\n' "$_gl_err" | sed '/^[[:space:]]*$/d' | tail -1)
    [ -z "$_gl_tail" ] || printf '  %s\n' "$_gl_tail" >&2
    return 1
  done
}

fi

# ── 리뷰 호스트 ──────────────────────────────────────────────────────────────

if [ "${_FORGE_WANT_REVIEW:-0}" = 1 ]; then

review_require() {
  command -v "$GITLAB_CLI" >/dev/null || { echo "error: $GITLAB_CLI is not installed" >&2; return 2; }
}

review_mr_view() {
  "$GITLAB_CLI" mr view "$1" -F json | python3 -c "$_gl_norm_mr"
}

review_mr_diff() {
  "$GITLAB_CLI" mr diff "$1" --color=never
}

review_mr_labels_set() {
  # <n> <붙일것> <뗄것> — 공백 구분
  _mr="$1"; _add="$2"; _rm="$3"
  set -- mr update "$_mr"
  for _l in $_add; do set -- "$@" --label "$_l"; done
  for _l in $_rm; do set -- "$@" --unlabel "$_l"; done
  "$GITLAB_CLI" "$@" >/dev/null
}

review_mr_threads() {
  _gl_paged "projects/:id/merge_requests/$1/discussions" | python3 -c '
import json, sys
out = []
for d in json.load(sys.stdin):
    notes = [n for n in (d.get("notes") or []) if isinstance(n, dict) and not n.get("system")]
    if not notes:
        continue
    pos = notes[0].get("position") or {}
    threaded = d.get("individual_note") is False
    out.append({
        "id": str(d.get("id")) if threaded and d.get("id") else None,
        "inline": threaded and bool(pos),
        "path": pos.get("new_path") or pos.get("old_path") or "",
        "line": pos.get("new_line") or pos.get("old_line") or "",
        "notes": [{"body": n.get("body") or "", "created_at": n.get("created_at") or ""} for n in notes],
    })
json.dump(out, sys.stdout, ensure_ascii=False)
'
}

# `--unique` 는 `--file` 과 배타적이라 인라인에는 쓸 수 없다. 재리뷰 시 같은 지적이 다시 달릴 수 있다.
review_mr_note_inline() {
  "$GITLAB_CLI" mr note create "$1" --file "$2" --line "$3" -m "$4"
}

review_mr_note_summary() {
  "$GITLAB_CLI" mr note create "$1" --resolvable=false -m "$(cat "$2")"
}

# 스레드 id 는 discussion id 다. 단독 노트(individual_note)는 답글을 받지 않아 threads 가 null 로 낸다.
# 미검증: 실제 GitLab 으로 이 호출을 돌려보지 않았다.
review_mr_thread_reply() {
  "$GITLAB_CLI" api --method POST "projects/:id/merge_requests/$1/discussions/$2/notes" \
    -f "body=$3" >/dev/null
}

# 검증 상태: 미검증. 열린 리뷰 요청을 첫 페이지만이 아니라 끝까지 읽는다.
review_mr_list_open() {
  _gl_paged "projects/:id/merge_requests?state=opened" | python3 -c "$_gl_norm_mr"
}

review_auth() {
  "$GITLAB_CLI" auth status </dev/null >/dev/null 2>&1 && return 0
  echo 'run `glab auth login`' >&2
  return 1
}

# 보호 브랜치 API 는 보호되지 않은 브랜치에 404 를 준다. 그 밖의 실패는 판단하지 못한 것이다.
review_branch_protected() {
  _b=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1") || return 1
  _err=$("$GITLAB_CLI" api "projects/:id/protected_branches/$_b" </dev/null 2>&1 >/dev/null) && { echo true; return 0; }
  case "$_err" in
    *404*) echo false ;;
    *) return 1 ;;
  esac
}

review_mr_close() {
  "$GITLAB_CLI" mr close "$1" >/dev/null
}

# 이슈↔MR 연결을 직접 준다. 기본 구현(브랜치·본문 문법 매칭)보다 정확하므로 덮어쓴다.
harness_issue_open_mrs() {
  _gl_paged "projects/:id/issues/$1/related_merge_requests" | python3 -c '
import json, sys
print(" ".join(str(m.get("iid")) for m in json.load(sys.stdin) if m.get("state") == "opened"))
'
}

fi
