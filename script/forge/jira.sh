#!/usr/bin/env sh
# forge 어댑터 — Jira / jira-cli. 계약은 `script/forge/_common.sh` 상단이 정본이다.
#
# **검증 상태: 미검증.** 실제 Jira 인스턴스로 돌려보지 않았다.
# `script/forge-selftest.sh <리뷰요청번호> <이슈키>` 를 전 단계까지 통과시키면 이 줄을 지운다.
#
# **Jira 는 이슈 트래커 전용이다.** 코드 리뷰 호스트 함수는 여기 없다 — `forge.review_host` 는
# gitlab 또는 github 이어야 하고, 설정이 그것을 검사한다.
#
# Jira 에서 다른 점 넷. 어댑터가 흡수하므로 호출부는 알지 않는다.
#   - 이슈 번호가 아니라 **키**(`PROJ-12`)다. 정규화 JSON 의 `iid` 에 그 키가 들어간다.
#     그래서 `commit.issue_ref = prefix` 와 `commit.ticket_key` 를 함께 쓴다.
#   - 본문이 평문이 아니라 ADF(문서 트리 JSON)로 올 수 있다. 여기서 평문으로 눌러 준다.
#   - 상태 이름이 프로젝트마다 다르다. 이름이 아니라 `statusCategory` 로 열림·닫힘을 가른다.
#   - **이슈 유형이 필수다.** GitLab·GitHub 에는 없는 개념이라 `[issues] type` 이 값을 갖는다.
#     한국어 프로젝트는 `작업` 처럼 다른 이름을 쓰므로 설정에서 온다.
#
# 마일스톤은 `fixVersions` 로 옮긴다 — 만들 때와 읽을 때가 같은 필드여야 왕복이 성립한다.
#
# **인증은 jira-cli 설정이 갖는다** (`jira init`). 이 어댑터는 토큰을 읽지도 받지도 않는다.
#
# **함수군은 따로 켜진다.** `script/forge.sh` 가 `_FORGE_WANT_TRACKER` 를 세우고 source 한다.
#
# 이 파일은 source 전용이다. 직접 실행하지 않는다.
set -u

JIRA_CLI=jira

# 이슈 유형. 설정(`[issues] type`)이 갖고 `script/harness.env` 로 온다.
# 어댑터만 쓰는 값이라 harness.env 를 읽지 않는 호출부에서도 돌도록 기본값을 둔다.
_jira_type() { printf '%s' "${ISSUE_TYPE:-Task}"; }

_jira_norm_issue='
import json, sys


def text_of(v):
    """ADF(문서 트리)를 평문으로 누른다. 이미 평문이면 그대로 돌려준다."""
    if isinstance(v, str):
        return v
    if isinstance(v, list):
        return "".join(text_of(x) for x in v)
    if not isinstance(v, dict):
        return ""
    t = v.get("type")
    if t == "text":
        return v.get("text") or ""
    if t in ("hardBreak", "rule"):
        return "\n"
    inner = text_of(v.get("content") or [])
    return inner + "\n\n" if t in ("paragraph", "heading", "codeBlock") else inner


def one(d):
    f = d.get("fields") or {}
    cat = ((f.get("status") or {}).get("statusCategory") or {}).get("key") or ""
    fix = f.get("fixVersions") or []
    return {
        "iid": d.get("key") or "",
        "title": f.get("summary") or "",
        # 상태 이름은 프로젝트마다 다르다. 분류(key)만이 어느 forge 에서나 같은 뜻을 갖는다.
        "state": "closed" if cat == "done" else "opened",
        "description": text_of(f.get("description")).strip(),
        "labels": list(f.get("labels") or []),
        # 만들 때 `-a` 가 표시 이름을 받으므로 읽을 때도 그것을 돌려준다 — 왕복이 맞는다.
        "assignee": (f.get("assignee") or {}).get("displayName") or "",
        "milestone": (fix[0] or {}).get("name") if fix else "",
    }


v = json.load(sys.stdin)
if isinstance(v, dict) and "issues" in v:
    v = v["issues"]
json.dump([one(x) for x in v] if isinstance(v, list) else one(v), sys.stdout, ensure_ascii=False)
'

# ── 이슈 트래커 ──────────────────────────────────────────────────────────────

if [ "${_FORGE_WANT_TRACKER:-0}" = 1 ]; then

tracker_require() {
  command -v "$JIRA_CLI" >/dev/null || { echo "error: $JIRA_CLI is not installed" >&2; return 2; }
  command -v python3 >/dev/null || { echo "error: python3 is not installed" >&2; return 2; }
}

tracker_issue_view() {
  "$JIRA_CLI" issue view "$1" --raw | python3 -c "$_jira_norm_issue"
}

# 검색 응답은 한 번에 최대 100건이다. `total` 을 보고 끝까지 돈다 —
# 마지막 페이지가 가득 차면 다음 페이지에 남은 것이 있을 수 있다.
#
# 기본 목록은 프로젝트마다 다른 필터를 탈 수 있으므로 **필터 없는 JQL 을 명시한다.**
# 중복 검사를 하는 쪽이 닫힌 이슈를 못 보면 같은 이슈를 다시 만든다.
tracker_issue_list() {
  _from=0
  _acc=$(mktemp)
  printf '[' > "$_acc"
  _first=1
  while :; do
    _batch=$("$JIRA_CLI" issue list -q "ORDER BY created ASC" --raw \
             --paginate "${_from}:100") || { rm -f "$_acc"; return 1; }
    _counts=$(printf '%s' "$_batch" | python3 -c '
import json, sys
v = json.load(sys.stdin)
issues = v.get("issues", v) if isinstance(v, dict) else v
if not isinstance(issues, list):
    raise SystemExit("list response is not an array")
total = v.get("total", len(issues)) if isinstance(v, dict) else len(issues)
print(len(issues)); print(total)') || { rm -f "$_acc"; return 1; }
    _n=$(printf '%s' "$_counts" | sed -n 1p)
    _total=$(printf '%s' "$_counts" | sed -n 2p)
    [ "$_n" -eq 0 ] && break
    _norm=$(printf '%s' "$_batch" | python3 -c "$_jira_norm_issue") || { rm -f "$_acc"; return 1; }
    [ "$_first" -eq 1 ] || printf ',' >> "$_acc"
    printf '%s' "$_norm" | sed 's|^\[||; s|\]$||' >> "$_acc"
    _first=0
    _from=$((_from + _n))
    [ "$_from" -ge "$_total" ] && break
  done
  printf ']' >> "$_acc"
  cat "$_acc"
  rm -f "$_acc"
}

tracker_issue_create() {
  _cmd_title="$1"; _cmd_body="$2"; _cmd_label="$3"; _cmd_assignee="$4"; _cmd_ms="$5"
  _out=$(
    set -- issue create --no-input -t "$(_jira_type)" -s "$_cmd_title" -T "$_cmd_body"
    [ -n "$_cmd_label" ]    && set -- "$@" -l "$_cmd_label"
    [ -n "$_cmd_assignee" ] && set -- "$@" -a "$_cmd_assignee"
    [ -n "$_cmd_ms" ]       && set -- "$@" --fix-version "$_cmd_ms"
    "$JIRA_CLI" "$@" --raw
  ) || return 1
  # `--raw` 는 만든 이슈의 JSON 을 낸다. 형태가 달라도 키는 본문 어디엔가 있으므로
  # JSON 을 먼저 보고 안 되면 키 패턴으로 물러선다.
  printf '%s' "$_out" | python3 -c '
import json, re, sys
raw = sys.stdin.read()
try:
    v = json.loads(raw)
    if isinstance(v, dict) and v.get("key"):
        print(v["key"]); raise SystemExit
except (ValueError, TypeError):
    pass
m = re.findall(r"\b[A-Z][A-Z0-9_]+-[0-9]+\b", raw)
print(m[-1] if m else "")'
}

tracker_issue_note() {
  "$JIRA_CLI" issue comment add "$1" "$2" --no-input >/dev/null
}

# Jira 에는 일반적인 "닫기" 가 없다. 상태 전이 이름이 프로젝트마다 다르므로 설정에서 온다.
tracker_issue_close() {
  if [ -n "$2" ]; then
    "$JIRA_CLI" issue edit "$1" --no-input -l "$2" >/dev/null || return 1
  fi
  "$JIRA_CLI" issue move "$1" "${ISSUE_CLOSED_STATUS:-Done}" >/dev/null
}

tracker_current_user() {
  "$JIRA_CLI" me
}

fi

# ── 리뷰 호스트 ──────────────────────────────────────────────────────────────
# 없다. Jira 는 코드 리뷰를 호스팅하지 않는다 — `forge.review_host` 가 gitlab·github 중
# 하나여야 하고, 설정 검증이 jira 를 거부한다. 여기서 빈 함수를 두면 그 거부가 무력해진다.
