#!/usr/bin/env bash
# 리뷰 루프 제어의 회귀 테스트 — 회차 라벨·상한·등급 판정·반복 지적·판정 선언 계약.
#
#   script/test-review-loop.sh
#
# 종료 코드: 0 = 전 케이스 통과 · 1 = 실패한 케이스 있음 · 2 = 실행 실패
#
# 원격도 리뷰 도구도 부르지 않는다. 임시 git 리포에 검사 대상 스크립트를 복사하고
# **forge 어댑터를 페이크로, 리뷰 도구를 PATH 앞의 스텁으로** 갈아끼워 종료 코드와 라벨
# 상태만 본다. 페이크가 지키는 것은 어댑터 계약(`script/forge/_common.sh` 상단)뿐이므로
# 어느 forge 를 쓰든 같은 테스트가 돈다 — 여기서 보는 것은 루프 제어 로직이다.
#
# **상한과 표지 문자열도 설정에서 읽는다.** 값을 픽스처에 박아 두면 설정을 바꿀 때마다
# 테스트가 깨지고, 그러면 값을 바꾸는 비용이 테스트 수정으로 돌아온다.
set -uo pipefail
# 훅이 넘긴 GIT_DIR·GIT_INDEX_FILE 같은 리포 지역 변수를 비운다. 남아 있으면 임시 리포를 만드는
# git init 이 임시 디렉터리 대신 그 변수가 가리키는 리포를 다시 초기화한다.
unset $(git rev-parse --local-env-vars 2>/dev/null)

command -v python3 >/dev/null || { echo "python3 is required to run this test" >&2; exit 2; }

# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 2
. "$repo_root/script/harness.env"
. "$repo_root/script/harness-format.sh"

# 이 테스트가 쓰는 상한. 실제 설정과 무관하게 고정해 기대값을 확정한다.
cap=5
repeat=3
# 누적 이력의 형식 판별자. 등록 스크립트가 갖는 값을 읽어 쓴다 — 박아 두면 둘이 갈린다.
hist_format=$(sed -n 's/^HIST_FORMAT = .\(#format [0-9]*\).*/\1/p' \
  "$repo_root/script/_review.py" | head -1)
[ -n "$hist_format" ] || { echo "could not read the history format marker" >&2; exit 2; }
ROUND=$REVIEW_ROUND_LABEL
# 스텁으로 갈아끼울 리뷰 도구 — 실행 계획이 고른 CLI 다
reviewer_bin=$(python3 "$repo_root/script/_review.py" plan-exe "$repo_root/script/harness.plan.json") || exit 2
[ -n "$reviewer_bin" ] || { echo "roles.code-reviewer.runner is inproc — nothing to stub" >&2; exit 2; }
[ -n "$reviewer_bin" ] || { echo "no review runner configured — cannot exercise the loop" >&2; exit 2; }

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

stub="$sandbox/bin"
work="$sandbox/repo"
state="$sandbox/state"
mkdir -p "$stub" "$state" "$work/script" "$work/.ai/templates"

cp "$repo_root/script/review-mr.sh" "$repo_root/script/post-review.sh" \
   "$repo_root/script/usage-log.sh" "$repo_root/script/usage-vocab.sh" \
   "$repo_root/script/harness-format.sh" "$repo_root/script/run-agent.py" \
   "$repo_root/script/metric.py" "$repo_root/script/_review.py" "$work/script/"
# 지표는 샌드박스 안에만 남긴다 — 실제 홈의 기록을 건드리지 않고, 리뷰 도구의 사용량이 남는지 본다
python3 - "$repo_root/script/harness.plan.json" "$work/script/harness.plan.json" "$sandbox/metrics" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
p["metrics"]["dir"] = sys.argv[3]
# 로그인 확인은 스텁이 알아보는 인자로 고정한다 — 벤더 선언에 확인 명령이 없어도 그 경로를 탄다
r = p["roles"]["code-reviewer"]
r["auth_check"] = [r["exe"], "stub-auth-check"]
r["auth_timeout"] = 30
json.dump(p, open(sys.argv[2], "w"))
PY
cp "$work/script/harness.plan.json" "$sandbox/plan.json"
cp "$repo_root/.ai/templates/code-reviewer.md" "$work/.ai/templates/"

# 상한만 이 테스트의 값으로 덮는다. 나머지는 실제 설정 그대로다.
sed -e "s/^REVIEW_MAX_ROUNDS=.*/REVIEW_MAX_ROUNDS=$cap/" \
    -e "s/^REVIEW_REPEAT_FILE_MAX=.*/REVIEW_REPEAT_FILE_MAX=$repeat/" \
    -e "s|^USAGE_LOG_PATH=.*|USAGE_LOG_PATH=off|" \
    "$repo_root/script/harness.env" > "$work/script/harness.env"
chmod +x "$work/script/"*.sh "$work/script/run-agent.py"

# ── forge 페이크 ────────────────────────────────────────────────────────────
# 계약이 정한 정규화 JSON 만 돌려준다. 라벨 상태는 파일이 들고, 등록 호출은 기록만 한다.
cat > "$work/script/forge.sh" <<'FAKE'
#!/usr/bin/env sh
review_require()  { return 0; }
tracker_require() { return 0; }

review_mr_view() {
  echo "review_mr_view $1" >> "$FAKE_STATE/forge-calls"
  python3 - "$(git rev-parse --abbrev-ref HEAD)" "$(git rev-parse HEAD)" \
           "$(cat "$FAKE_STATE/labels" 2>/dev/null || true)" \
           "$(cat "$FAKE_STATE/mr-description" 2>/dev/null || true)" <<'PY'
import json, sys
print(json.dumps({"iid": "1", "source_branch": sys.argv[1], "head_sha": sys.argv[2],
                  "description": sys.argv[4], "labels": sys.argv[3].split(),
                  "state": "opened"}, ensure_ascii=False))
PY
}

review_mr_diff() {
  printf 'diff --git a/script/review-mr.sh b/script/review-mr.sh\n+테스트 변경\n'
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

# 조회에 나가는 스레드와 그 id. 시스템 노트만 있는 항목은 빠진다. 일반 노트는 픽스처가 id 를 적었어도
# 답글을 받지 않으므로 null 이다. 인라인 스레드는 픽스처가 적은 id 를 쓰고, 없으면 조회에 남은 id 없는
# 인라인 스레드 순서로 픽스처의 어느 명시 id 와도 겹치지 않는 `t<n>` 을 받는다.
# 조회와 답글이 이 목록 하나로 스레드를 찾으므로 조회가 준 id 는 조회된 그 스레드만 가리킨다.
FAKE_THREAD_ID='
def visible_threads(threads):
    taken = {str(t["id"]) for t in threads if t.get("id") is not None}
    out, n = [], 0
    for t in threads:
        if not [x for x in t.get("notes", []) if not x.get("system")]:
            continue
        if not t.get("inline"):
            tid = None
        elif "id" in t:
            tid = None if t["id"] is None else str(t["id"])
        else:
            n += 1
            while "t%d" % n in taken:
                n += 1
            tid = "t%d" % n
            taken.add(tid)
        out.append((tid, t))
    return out
'

# 실제 어댑터와 같이 시스템 메모를 걸러 정규화해 돌려준다.
review_mr_threads() {
  [ -f "$FAKE_STATE/threads.json" ] || { echo '[]'; return 0; }
  python3 - "$FAKE_STATE/threads.json" "$FAKE_THREAD_ID" <<'PY'
import json, sys
exec(sys.argv[2])
out = []
for tid, t in visible_threads(json.load(open(sys.argv[1], encoding='utf-8'))):
    out.append({"id": tid, "inline": bool(t.get("inline")),
                "path": t.get("path", ""), "line": t.get("line", ""),
                "notes": [{"body": n.get("body", ""), "created_at": n.get("created_at", "")}
                          for n in t.get("notes", []) if not n.get("system")]})
json.dump(out, sys.stdout, ensure_ascii=False)
PY
}

# 조회된 스레드에만 답글이 달린다. id 가 null 인 노트, 없는 id, 둘 이상에 걸리는 id 는 0 이 아닌 코드로 끝난다.
review_mr_thread_reply() { # <n> <스레드id> <본문>
  [ -f "$FAKE_STATE/threads.json" ] || return 1
  python3 - "$FAKE_STATE/threads.json" "$FAKE_THREAD_ID" "$2" "$3" <<'PY'
import json, sys
exec(sys.argv[2])
path, tid, body = sys.argv[1], sys.argv[3], sys.argv[4]
threads = json.load(open(path, encoding="utf-8"))
hits = [t for i, t in visible_threads(threads) if i is not None and i == tid]
if len(hits) != 1:
    print("no single thread with id: %s" % tid, file=sys.stderr)
    raise SystemExit(1)
hits[0].setdefault("notes", []).append({"body": body, "created_at": "2026-09-23T12:00:00.000+09:00"})
json.dump(threads, open(path, "w", encoding="utf-8"), ensure_ascii=False)
PY
}

review_mr_note_inline() {
  printf 'note: inline %s %s:%s %s\n' "$1" "$2" "$3" "$4" >> "$FAKE_STATE/notes"
}

review_mr_note_summary() {
  { printf 'note: summary %s\n' "$1"; cat "$2"; } >> "$FAKE_STATE/notes"
}

tracker_issue_view() { cat "$FAKE_STATE/issue.json" 2>/dev/null || echo '{}'; }
FAKE

git -C "$work" init -q >/dev/null 2>&1 || { echo "failed to create the temp repo" >&2; exit 2; }
git -C "$work" checkout -q -b mr-source >/dev/null 2>&1
git -C "$work" add -A
git -C "$work" -c core.hooksPath="$sandbox/nohooks" -c user.email=test@example.invalid \
  -c user.name=test commit -qm "init" || { echo "failed to commit in the temp repo" >&2; exit 2; }

# ── 리뷰 도구 스텁 ──────────────────────────────────────────────────────────
cat > "$stub/$reviewer_bin" <<'STUB'
#!/usr/bin/env bash
# 리뷰 도구 스텁. 호출 흔적과 받은 입력을 남기고 준비된 리뷰 본문을 결과 파일로 넘긴다.
set -uo pipefail
# 로그인 확인 — 기록만 남기고 STUB_AUTH 의 코드로 끝난다(기본 0)
if [ "$*" = "stub-auth-check" ]; then
  echo "auth" >> "$FAKE_STATE/auth-calls"
  exit "${STUB_AUTH:-0}"
fi
echo "called" >> "$FAKE_STATE/reviewer-calls"
out=""; prev=""
for a in "$@"; do
  [ "$prev" = "--output-last-message" ] && out="$a"
  prev="$a"
done
cat > "$FAKE_STATE/reviewer-input"   # stdin 으로 온 리뷰 입력
# 리뷰 도중 커밋이 생기는 상황을 재현한다. 기록되는 리비전이 리뷰한 것인지 보기 위한 것이다.
if [ -n "${STUB_COMMIT:-}" ]; then
  echo "리뷰 도중 변경" > "$STUB_COMMIT"
  git add -A
  git -c core.hooksPath=/nonexistent -c user.email=test@example.invalid -c user.name=test \
    commit -qm "during review"
fi
# 사용량을 함께 내라는 인자가 오면 그 벤더의 형식으로 낸다(claude: JSON 결과 하나, codex: JSONL 이벤트).
# 아니면 결과 파일 인자를 받는 벤더(codex)는 그 파일로, 아니면(claude) 표준 출력으로 낸다
case " $* " in
  *" --output-format json "*)
    python3 -c 'import json,sys; print(json.dumps({"type":"result","is_error":False,"result":open(sys.argv[1]).read(),
      "usage":{"input_tokens":11,"output_tokens":7,"cache_read_input_tokens":3,"cache_creation_input_tokens":2},
      "modelUsage":{"stub-model":{}}}))' "$STUB_REVIEW" ;;
  *" --json "*)
    python3 -c 'import json,sys
print(json.dumps({"type":"thread.started"}))
print(json.dumps({"type":"item.completed","item":{"type":"agent_message","text":open(sys.argv[1]).read()}}))
print(json.dumps({"type":"turn.completed","usage":{"input_tokens":14,"cached_input_tokens":3,"output_tokens":7}}))' "$STUB_REVIEW" ;;
  *) if [ -n "$out" ]; then cp "$STUB_REVIEW" "$out"; else cat "$STUB_REVIEW"; fi ;;
esac
STUB
chmod +x "$stub/$reviewer_bin"

# ── 리뷰 본문 ───────────────────────────────────────────────────────────────
# 리뷰어 출력은 판정 데이터 블록 하나다. 표본은 아래 생성기가 만든다 — 발견 한 건은 한 줄에 쓰고
# `"path": …, "line": …` 를 붙여 두어 케이스가 sed 로 위치만 바꿀 수 있게 한다.
python3 - "$sandbox" "$FMT_REVIEW_BLOCK" <<'PY' || exit 2
import json, os, sys
out, tag = sys.argv[1], sys.argv[2]


def finding(sev, path, line, title, **kw):
    f = {"severity": sev, "path": path, "line": line, "title": title,
         "problem": kw.get("problem", "문제 설명"), "repro": kw.get("repro", "입력 → 결과"),
         "recommendation": kw.get("recommendation", "권고"),
         "out_of_scope": kw.get("out_of_scope", False), "decision_basis": kw.get("decision_basis")}
    return f


def dump(data):
    """발견 한 건을 한 줄에. 키 순서를 고정해 sed 로 위치를 바꿀 수 있게 한다."""
    lines = ["{", '  "summary": %s,' % json.dumps(data["summary"], ensure_ascii=False), '  "findings": [']
    fs = data["findings"]
    for n, f in enumerate(fs):
        lines.append("    " + json.dumps(f, ensure_ascii=False) + ("," if n < len(fs) - 1 else ""))
    lines += ["  ],", '  "strengths": %s,' % json.dumps(data["strengths"], ensure_ascii=False),
              '  "verdict": %s' % json.dumps(data["verdict"]), "}"]
    return "\n".join(lines)


def write(name, data=None, raw=None, before="리뷰를 마쳤다.\n", after=""):
    body = raw if raw is not None else dump(data)
    with open(os.path.join(out, name), "w", encoding="utf-8") as fp:
        fp.write(f"{before}\n```{tag}\n{body}\n```\n{after}")


def review(findings, verdict, strengths=("종료 코드 규약을 지켰다",), summary="전반 상태 요약."):
    return {"summary": summary, "findings": list(findings), "strengths": list(strengths), "verdict": verdict}


write("clean.md", review([], "PASS"))
write("minor-only.md", review([
    finding("minor", "script/review-mr.sh", 12, "주석이 길다"),
    finding("minor", "script/post-review.sh", 30, "변수명이 모호하다")], "CHANGES_REQUESTED"))
write("same-major.md", review([
    finding("major", "script/review-mr.sh", 40, "라벨 갱신 실패를 무시한다",
            problem="회차가 기록되지 않는다", recommendation="종료 코드 2 로 멈춘다")], "CHANGES_REQUESTED"))
write("no-location.md", review([
    finding("major", None, None, "입력 검증이 없다")], "CHANGES_REQUESTED"))
write("no-line.md", review([
    finding("major", "script/review-mr.sh", None, "파일 전반에 입력 검증이 없다")], "CHANGES_REQUESTED"))
write("outside-text.md", review([], "PASS"),
      before="## 발견 사항\n\n- [major] script/review-mr.sh:1 — 블록 밖의 발견 형식 줄\n",
      after="\n## 발견 사항\n\n- [blocker] script/post-review.sh:2 — 블록 뒤의 발견 형식 줄\n")
write("rendered.md", review([
    finding("minor", "docs/a.md", 3, "결정 재검토 필요: 형식", decision_basis="docs/adr/0004-x.md 의 Consequences"),
    finding("major", "script/review-mr.sh", 7, "범위 밖의 결함", out_of_scope=True,
            problem="첫 줄\n# 제목처럼 보이는 줄", repro="입력 A → 결과 B", recommendation="이월한다"),
    finding("blocker", "script/post-review.sh", 9, "등록 전에 검증하지 않는다"),
], "CHANGES_REQUESTED", strengths=()))
write("separator-in-text.md", review([
    finding("major", "script/review-mr.sh", 5, "여러 줄 필드의 구분자",
            problem="첫 줄\u2028둘째 줄\u0085셋째 줄")], "CHANGES_REQUESTED"))
# 값 안의 코드 펜스·HTML 블록은 뒤따르는 절이나 항목을 삼키지 못한다.
write("fence-in-text.md", review([
    finding("major", "script/review-mr.sh", 5, "여러 줄 값의 코드 펜스",
            problem="첫 줄\n```", repro="재현\n~~~", recommendation="권고\n\n```\n코드")],
    "CHANGES_REQUESTED", summary="```\n정상\n~~~", strengths=("```\n잘된 점", "   <pre>\n둘째")))

with open(os.path.join(out, "no-block.md"), "w", encoding="utf-8") as fp:
    fp.write("판정 데이터 블록을 빠뜨렸다.\n\n## 발견 사항\n\n발견 사항 없음\n")
clean = dump(review([], "PASS"))
with open(os.path.join(out, "two-blocks.md"), "w", encoding="utf-8") as fp:
    fp.write(f"```{tag}\n{clean}\n```\n\n```{tag}\n{clean}\n```\n")
write("bad-json.md", raw='{"summary": "끝이 없다", "findings": [')
# 여는 줄의 info string 은 정확히 태그여야 한다. 뒤에 공백이 붙은 줄은 판정 데이터 블록이 아니다.
with open(os.path.join(out, "fence-trailing-space.md"), "w", encoding="utf-8") as fp:
    fp.write(f"```{tag} \n{clean}\n```\n")
with open(os.path.join(out, "fence-trailing-tab.md"), "w", encoding="utf-8") as fp:
    fp.write(f"```{tag}\t\n{clean}\n```\n")
# CRLF 줄 끝은 줄 끝일 뿐 info string 의 일부가 아니다.
with open(os.path.join(out, "fence-crlf.md"), "w", encoding="utf-8", newline="") as fp:
    fp.write(f"리뷰를 마쳤다.\r\n\r\n```{tag}\r\n" + clean.replace("\n", "\r\n") + "\r\n```\r\n")
# 줄을 가르지 않는 제어 문자는 title 에 있어도 한 줄이다.
write("title-inline-control.md", review([
    finding("major", "script/review-mr.sh", 5, "요지\u0007와\t탭")], "CHANGES_REQUESTED"))
# strengths 의 원소 값은 검증하지 않는다. 공백만인 원소는 받되 댓글에 쓰지 않는다.
write("strengths-blank.md", review([], "PASS", strengths=("  ", "\t")))
write("strengths-mixed.md", review([], "PASS", strengths=(" ", "남는 원소")))

# 스키마 위반 — 한 가지씩만 어긴다. 기대하는 지목 위치를 파일 이름 옆에 적어 둔다.
base = review([finding("major", "script/review-mr.sh", 4, "요지")], "CHANGES_REQUESTED")
cases = []


def bad(name, where, mutate=None, raw=None):
    d = json.loads(json.dumps(base))
    if mutate:
        mutate(d)
    write(f"schema-{name}.md", raw=raw if raw is not None else json.dumps(d, ensure_ascii=False, indent=2))
    cases.append(f"{name}\t{where}")


bad("missing-key", "findings[0].repro", lambda d: d["findings"][0].pop("repro"))
bad("missing-top", "verdict", lambda d: d.pop("verdict"))
bad("undefined-key", "findings[0].extra", lambda d: d["findings"][0].update(extra=1))
bad("undefined-top", "note", lambda d: d.update(note="x"))
bad("duplicate-key", "duplicate key 'title'",
    raw=dump(base).replace('"title": "요지"', '"title": "요지", "title": "둘째"'))
bad("severity", "findings[0].severity", lambda d: d["findings"][0].update(severity="critical"))
bad("verdict", "verdict", lambda d: d.update(verdict="REVIEW_VERDICT: PASS"))
bad("line-string", "findings[0].line", lambda d: d["findings"][0].update(line="4"))
bad("line-bool", "findings[0].line", lambda d: d["findings"][0].update(line=True))
bad("line-zero", "findings[0].line", lambda d: d["findings"][0].update(line=0))
bad("line-without-path", "findings[0].line", lambda d: d["findings"][0].update(path=None))
bad("path-absolute", "findings[0].path", lambda d: d["findings"][0].update(path="/etc/passwd"))
bad("path-dotdot", "findings[0].path", lambda d: d["findings"][0].update(path="script/../x.sh"))
bad("path-newline", "findings[0].path", lambda d: d["findings"][0].update(path="script/x\n.sh"))
bad("path-delete", "findings[0].path", lambda d: d["findings"][0].update(path="script/x\u007f.py"))
bad("path-c1-control", "findings[0].path", lambda d: d["findings"][0].update(path="script/x\u009b.py"))
bad("path-line-separator", "findings[0].path", lambda d: d["findings"][0].update(path="script/x\u2028.py"))
bad("path-paragraph-separator", "findings[0].path", lambda d: d["findings"][0].update(path="script/x\u2029.py"))
bad("path-bidi-override", "findings[0].path", lambda d: d["findings"][0].update(path="script/x\u202e.py"))
bad("title-blank", "findings[0].title", lambda d: d["findings"][0].update(title="  "))
bad("title-multiline", "findings[0].title", lambda d: d["findings"][0].update(title="한 줄\n두 줄"))
bad("title-carriage-return", "findings[0].title", lambda d: d["findings"][0].update(title="한 줄\r두 줄"))
bad("title-line-separator", "findings[0].title", lambda d: d["findings"][0].update(title="요지\u2028# 삽입"))
bad("title-paragraph-separator", "findings[0].title", lambda d: d["findings"][0].update(title="요지\u2029# 삽입"))
bad("title-next-line", "findings[0].title", lambda d: d["findings"][0].update(title="요지\u0085# 삽입"))
bad("title-vertical-tab", "findings[0].title", lambda d: d["findings"][0].update(title="요지\u000b# 삽입"))
bad("title-form-feed", "findings[0].title", lambda d: d["findings"][0].update(title="요지\u000c# 삽입"))
bad("title-file-separator", "findings[0].title", lambda d: d["findings"][0].update(title="요지\u001c# 삽입"))
bad("title-group-separator", "findings[0].title", lambda d: d["findings"][0].update(title="요지\u001d# 삽입"))
bad("title-record-separator", "findings[0].title", lambda d: d["findings"][0].update(title="요지\u001e# 삽입"))
bad("decision-not-minor", "findings[0].decision_basis",
    lambda d: d["findings"][0].update(decision_basis="docs/adr/0004-x.md"))
bad("out-of-scope-type", "findings[0].out_of_scope", lambda d: d["findings"][0].update(out_of_scope="no"))
bad("summary-blank", "summary", lambda d: d.update(summary=""))
with open(os.path.join(out, "schema-cases.tsv"), "w", encoding="utf-8") as fp:
    fp.write("\n".join(cases) + "\n")
PY

# ── 실행 도우미 ─────────────────────────────────────────────────────────────
pass=0; fail=0
check() { # <ID> <무엇> <기대> <실제>
  if [ "$3" = "$4" ]; then
    echo "  ok   $1 $2 → $4"; pass=$((pass + 1))
  else
    echo "  FAIL $1 $2 → expected '$3', actual '$4'" >&2; fail=$((fail + 1))
  fi
}

labels() { cat "$state/labels" 2>/dev/null || true; }
reviewer_calls() { [ -f "$state/reviewer-calls" ] && wc -l < "$state/reviewer-calls" | tr -d ' ' || echo 0; }
note_hits() { # <패턴> — 등록된 댓글 중 패턴에 걸리는 줄 수. 파일이 없으면 0.
  local c
  c=$(grep -c "$1" "$state/notes" 2>/dev/null)
  echo "${c:-0}"
}
input_hits() { # <패턴> — 리뷰 도구가 받은 입력 중 패턴에 걸리는 줄 수. 파일이 없으면 0.
  local c
  c=$(grep -c "$1" "$state/reviewer-input" 2>/dev/null)
  echo "${c:-0}"
}
input_line() { # <패턴> — 리뷰 입력에서 패턴이 처음 걸린 줄 번호. 없으면 0.
  local n
  n=$(grep -n "$1" "$state/reviewer-input" 2>/dev/null | head -1 | cut -d: -f1)
  echo "${n:-0}"
}
log_hits() { # <패턴> — 마지막 실행 로그에서 패턴에 걸리는 줄 수. 파일이 없으면 0.
  local c
  c=$(grep -c "$1" "$state/last.log" 2>/dev/null)
  echo "${c:-0}"
}
incr_hits() { # <패턴> — 증분 diff 절 안에서 패턴에 걸리는 줄 수
  local c
  c=$(sed -n '/^## 증분 diff/,/^## 누적 diff/p' "$state/reviewer-input" 2>/dev/null | grep -c "$1")
  echo "${c:-0}"
}
before() { # <앞 패턴> <뒤 패턴> — 둘 다 있고 순서가 맞으면 yes
  local a b
  a=$(input_line "$1"); b=$(input_line "$2")
  { [ "$a" -gt 0 ] && [ "$b" -gt "$a" ]; } && echo yes || echo no
}

run_review() { # <리뷰본문> [옵션…]
  local body="$1"; shift
  ( cd "$work" && PATH="$stub:$PATH" FAKE_STATE="$state" STUB_REVIEW="$body" \
      STUB_COMMIT="${STUB_COMMIT:-}" script/review-mr.sh "$@" 1 >"$state/last.log" 2>&1 )
  echo $?
}

run_post() { # <MR번호> <리뷰본문> [리뷰한리비전]
  ( cd "$work" && PATH="$stub:$PATH" FAKE_STATE="$state" \
      script/post-review.sh "$1" "$2" "테스트" ${3:+"$3"} >"$state/last.log" 2>&1 )
  echo $?
}

echo "UT-01 each review run bumps the round label by 1"
rm -f "$state/labels" "$state/reviewer-calls" "$state/auth-calls"
check UT-01 "round 1 exit code" 0 "$(run_review "$sandbox/clean.md")"
check UT-01 "round 1 label" "$ROUND:1" "$(labels)"
check UT-01 "round 2 exit code" 0 "$(run_review "$sandbox/clean.md")"
check UT-01 "round 2 label — previous one removed" "$ROUND:2" "$(labels)"

check UT-01 "the runner's sign-in is checked before each round" 2 "$(wc -l < "$state/auth-calls" | tr -d ' ')"

echo "UT-34 a review runner that is not ready stops before the round label and the forge"
plan_variant() { # [<파이썬 문장>] — 실행 계획 사본의 code-reviewer 항목 r 을 고친다. 인수가 없으면 되돌린다
  cp "$sandbox/plan.json" "$work/script/harness.plan.json"
  [ $# -eq 0 ] || python3 -c '
import json, sys
p = json.load(open(sys.argv[1])); r = p["roles"]["code-reviewer"]
exec(sys.argv[2])
json.dump(p, open(sys.argv[1], "w"))' "$work/script/harness.plan.json" "$1"
}
for c in "signed-out|not signed in|STUB_AUTH=1" "unconfirmed|could not check sign-in|STUB_AUTH=0" \
         "missing|is not installed|STUB_AUTH=0"; do
  name=${c%%|*}; rest=${c#*|}; want=${rest%%|*}; auth=${rest#*|}
  case "$name" in
    unconfirmed) plan_variant 'r["auth_check"] = ["/nonexistent/auth-check-for-test"]' ;;
    missing)     plan_variant 'r["exe"] = "no-such-reviewer-cli-for-test"' ;;
    *)           plan_variant ;;
  esac
  echo "$ROUND:2" > "$state/labels"
  rm -f "$state/reviewer-calls" "$state/forge-calls"
  rc=$( ( cd "$work" && env PATH="$stub:$PATH" FAKE_STATE="$state" STUB_REVIEW="$sandbox/clean.md" "$auth" \
          script/review-mr.sh 1 >"$state/last.log" 2>&1 ); echo $? )
  check UT-34 "$name: exit code" 2 "$rc"
  check UT-34 "$name: the runner's reason is passed through" 1 "$(grep -c -- "$want" "$state/last.log" | tr -d ' ')"
  check UT-34 "$name: says the round was not used" 1 "$(grep -c 'help: the round was not used — fix the review runner, then rerun' "$state/last.log" | tr -d ' ')"
  check UT-34 "$name: the round label is unchanged" "$ROUND:2" "$(labels)"
  check UT-34 "$name: the reviewer did not run" 0 "$(reviewer_calls)"
  check UT-34 "$name: the forge was not read" no "$([ -s "$state/forge-calls" ] && echo yes || echo no)"
done
# 서브에이전트 역할 — 실행 파일이 없으면 지금의 안내 그대로 멈춘다
plan_variant 'r["exe"] = ""'
echo "$ROUND:2" > "$state/labels"; rm -f "$state/reviewer-calls" "$state/auth-calls"
rc=$( ( cd "$work" && env PATH="$stub:$PATH" FAKE_STATE="$state" STUB_REVIEW="$sandbox/clean.md" \
        script/review-mr.sh 1 >"$state/last.log" 2>&1 ); echo $? )
check UT-34 "subagent: exit code" 2 "$rc"
check UT-34 "subagent: the subagent guidance" 1 "$(grep -c 'error: no review runner is configured' "$state/last.log" | tr -d ' ')"
check UT-34 "subagent: the sign-in is not checked" no "$([ -s "$state/auth-calls" ] && echo yes || echo no)"
check UT-34 "subagent: the round label is unchanged" "$ROUND:2" "$(labels)"
plan_variant
unset -f plan_variant

echo "UT-02 at the cap no review runs"
echo "$ROUND:$cap" > "$state/labels"
rm -f "$state/reviewer-calls"
check UT-02 "exit code" 3 "$(run_review "$sandbox/clean.md")"
check UT-02 "review tool calls" 0 "$(reviewer_calls)"
check UT-02 "label unchanged" "$ROUND:$cap" "$(labels)"

echo "UT-03 --force runs past the cap"
echo "$ROUND:$cap" > "$state/labels"
rm -f "$state/reviewer-calls"
check UT-03 "exit code" 0 "$(run_review "$sandbox/clean.md" --force)"
check UT-03 "review tool calls" 1 "$(reviewer_calls)"
check UT-03 "label" "$ROUND:$((cap + 1))" "$(labels)"

echo "UT-04 minor findings only is a PASS"
check UT-04 "exit code" 0 "$(run_post 2 "$sandbox/minor-only.md")"

echo "UT-05 major on the same file for the repeat cap in a row stops the loop"
rm -f "$state/notes"
check UT-05 "round 1 exit code" 1 "$(run_post 3 "$sandbox/same-major.md")"
check UT-05 "round 2 exit code" 1 "$(run_post 3 "$sandbox/same-major.md")"
check UT-05 "round 3 exit code" 3 "$(run_post 3 "$sandbox/same-major.md")"
check UT-05 "file path and round count in the summary" 1 "$(note_hits "${repeat}회차 연속: .script/review-mr.sh.")"

# 요지가 매 회차 달라도 파일이 같으면 같은 뿌리로 본다 — 문구 비교를 쓰지 않는다.
for n in 1 2 3; do
  sed "s/라벨 갱신 실패를 무시한다/서로 다른 지적 $n/" "$sandbox/same-major.md" > "$sandbox/other-major-$n.md"
done
check UT-05 "different wording — round 1 exit code" 1 "$(run_post 4 "$sandbox/other-major-1.md")"
check UT-05 "different wording — round 2 exit code" 1 "$(run_post 4 "$sandbox/other-major-2.md")"
check UT-05 "different wording — round 3 exit code" 3 "$(run_post 4 "$sandbox/other-major-3.md")"

# 중간에 그 파일이 깨끗하면 연속이 끊긴다 — 직전 수정이 파일을 닫았다는 뜻이다.
check UT-05 "streak round 1 exit code" 1 "$(run_post 22 "$sandbox/same-major.md")"
check UT-05 "streak round 2 exit code" 1 "$(run_post 22 "$sandbox/same-major.md")"
check UT-05 "clean round exit code" 0 "$(run_post 22 "$sandbox/clean.md")"
check UT-05 "exit code after the streak breaks" 1 "$(run_post 22 "$sandbox/same-major.md")"
check UT-05 "recounted round 2 exit code" 1 "$(run_post 22 "$sandbox/same-major.md")"
check UT-05 "recounted round 3 exit code" 3 "$(run_post 22 "$sandbox/same-major.md")"

# 선언은 등급 집계로 판정한 뒤에도 계약 준수 확인용으로 남는다 — 선언이 없으면 등록하지 않는다.
echo "UT-06 no verdict means nothing is posted"
rm -f "$state/notes"
check UT-06 "exit code" 2 "$(run_post 5 "$sandbox/schema-missing-top.md")"
check UT-06 "post calls" 0 "$(note_hits 'note:')"

echo "UT-07 a declaration that disagrees with the tally is noted in the summary"
rm -f "$state/notes"
check UT-07 "minor only — exit code" 0 "$(run_post 6 "$sandbox/minor-only.md")"
check UT-07 "mismatch recorded" 1 "$(note_hits '리뷰어가 선언한 판정은 .CHANGES_REQUESTED.')"
rm -f "$state/notes"
check UT-07 "declaration agrees — exit code" 0 "$(run_post 7 "$sandbox/clean.md")"
check UT-07 "no mismatch recorded" 0 "$(note_hits '리뷰어가 선언한 판정은')"
check UT-07 "no findings marker" 1 "$(note_hits "^$FMT_NO_FINDINGS\$")"

echo "UT-08 the repeat key looks at the file path only"
# 파일이 다르면 독립 결함이다 — 요지가 같고 몰아서 3회 나와도 상한에 걸리지 않는다.
for n in 1 2 3; do
  sed "s#\"path\": \"script/review-mr.sh\", \"line\": 40#\"path\": \"script/file-$n.sh\", \"line\": $((n * 10))#" \
    "$sandbox/same-major.md" > "$sandbox/other-file-$n.md"
  check UT-08 "different file — round ${n} exit code" 1 "$(run_post 8 "$sandbox/other-file-$n.md")"
done
# 같은 파일이면 줄 번호가 달라도 같은 뿌리로 센다(코드가 밀리면 줄은 바뀐다).
for n in 1 2; do
  sed "s#\"line\": 40#\"line\": $((n * 100))#" "$sandbox/same-major.md" > "$sandbox/moved-$n.md"
  check UT-08 "same file, moved line — round ${n} exit code" 1 "$(run_post 9 "$sandbox/moved-$n.md")"
done
check UT-08 "same file — round 3 exit code" 3 "$(run_post 9 "$sandbox/same-major.md")"
# 심각도가 달라도 같은 파일이면 연속을 잇는다 — 같은 뿌리가 등급만 바뀌어 돌아오는 것을 센다.
sed 's#"severity": "major"#"severity": "blocker"#' "$sandbox/same-major.md" > "$sandbox/same-file-blocker.md"
check UT-08 "major — round 1 exit code" 1 "$(run_post 10 "$sandbox/same-major.md")"
check UT-08 "major — round 2 exit code" 1 "$(run_post 10 "$sandbox/same-major.md")"
check UT-08 "blocker — round 3 exit code" 3 "$(run_post 10 "$sandbox/same-file-blocker.md")"

echo "UT-09 findings without a path share one slot and get no inline comment"
rm -f "$state/notes"
check UT-09 "round 1 exit code" 1 "$(run_post 11 "$sandbox/no-location.md")"
check UT-09 "no inline comment" 0 "$(note_hits '^note: inline')"
check UT-09 "round 2 exit code" 1 "$(run_post 11 "$sandbox/no-location.md")"
check UT-09 "round 3 exit code" 3 "$(run_post 11 "$sandbox/no-location.md")"
check UT-09 "each round is keyed by the no-location marker" 3 "$(grep -cF "$FMT_NO_LOCATION" "$work/.git/work-loop/review-findings-11.tsv")"
# 경로만 있고 줄이 없으면 그 경로로 누적하고 인라인에서 빠진다.
rm -f "$state/notes"
check UT-09 "path without a line — exit code" 1 "$(run_post 25 "$sandbox/no-line.md")"
check UT-09 "path without a line — no inline comment" 0 "$(note_hits '^note: inline')"
check UT-09 "path without a line — keyed by the path" "1	script/review-mr.sh" \
  "$(sed -n 2p "$work/.git/work-loop/review-findings-25.tsv")"
check UT-09 "path without a line — location in the summary" 1 "$(note_hits '`script/review-mr.sh` — 파일 전반에')"

echo "UT-10 history in the old format is not continued"
hist="$work/.git/work-loop/review-findings-12.tsv"
mkdir -p "$(dirname "$hist")"
printf '#format 2\n1\t[major] script/review-mr.sh — 라벨 갱신 실패를 무시한다\n2\t[major] script/review-mr.sh — 라벨 갱신 실패를 무시한다\n' > "$hist"
check UT-10 "exit code after two old records" 1 "$(run_post 12 "$sandbox/same-major.md")"
check UT-10 "format marker" "$hist_format" "$(head -1 "$hist")"
check UT-10 "history line count — marker plus this round" 2 "$(wc -l < "$hist" | tr -d ' ')"
check UT-10 "this round's number — old rounds not continued" 1 "$(sed -n '2p' "$hist" | cut -f1)"

echo "UT-11 text outside the block is neither counted nor posted"
rm -f "$state/notes"
check UT-11 "exit code" 0 "$(run_post 13 "$sandbox/outside-text.md")"
check UT-11 "tally" 1 "$(note_hits '발견 blocker 0 · major 0 · minor 0')"
check UT-11 "outside lines are not posted" 0 "$(note_hits '블록 밖의 발견 형식 줄\|블록 뒤의 발견 형식 줄')"
check UT-11 "no inline comment" 0 "$(note_hits '^note: inline')"

echo "UT-12 no block, two blocks or broken JSON means nothing is posted"
for c in no-block two-blocks bad-json fence-trailing-space fence-trailing-tab; do
  rm -f "$state/notes"
  check UT-12 "$c — exit code" 2 "$(run_post 16 "$sandbox/$c.md")"
  check UT-12 "$c — post calls" 0 "$(note_hits 'note:')"
  check UT-12 "$c — first line names the violation" 1 "$(head -1 "$state/last.log" | grep -c '^contract violation: ')"
  check UT-12 "$c — help line" 1 "$(sed -n 2p "$state/last.log" | grep -c '^help: nothing was posted — the raw review follows$')"
  check UT-12 "$c — the raw review follows" yes "$(tail -n +3 "$state/last.log" | cmp -s - "$sandbox/$c.md" && echo yes || echo no)"
done

echo "UT-13 a schema violation names where it is and posts nothing"
while IFS=$'\t' read -r name where; do
  rm -f "$state/notes"
  check UT-13 "$name — exit code" 2 "$(run_post 17 "$sandbox/schema-$name.md")"
  check UT-13 "$name — post calls" 0 "$(note_hits 'note:')"
  check UT-13 "$name — names $where" 1 "$(head -1 "$state/last.log" | grep -cF "contract violation: $where")"
done < "$sandbox/schema-cases.tsv"

echo "UT-13 a line separator inside a multi-line field is not a violation"
rm -f "$state/notes"
check UT-13 "separator-in-text — exit code" 1 "$(run_post 17 "$sandbox/separator-in-text.md")"
check UT-13 "separator-in-text — inline posted" 1 "$(note_hits '^note: inline')"

echo "UT-13 a control character that does not break the line is allowed in the title"
rm -f "$state/notes"
check UT-13 "title-inline-control — exit code" 1 "$(run_post 17 "$sandbox/title-inline-control.md")"
check UT-13 "title-inline-control — inline posted" 1 "$(note_hits '^note: inline')"

echo "UT-29 blank strengths are accepted and left out of the summary"
rm -f "$state/notes"
check UT-29 "strengths-blank — exit code" 0 "$(run_post 28 "$sandbox/strengths-blank.md")"
check UT-29 "strengths-blank — summary posted" 1 "$(note_hits '^note: summary')"
check UT-29 "strengths-blank — no strengths section" 0 "$(note_hits '^### 잘된 점')"
rm -f "$state/notes"
check UT-29 "strengths-mixed — exit code" 0 "$(run_post 28 "$sandbox/strengths-mixed.md")"
check UT-29 "strengths-mixed — strengths section" 1 "$(note_hits '^### 잘된 점')"
check UT-29 "strengths-mixed — only the non-blank element" 1 \
  "$(sed -n '/^### 잘된 점/,$p' "$state/notes" | grep -c '^- ')"
check UT-29 "strengths-mixed — the element is written" 1 "$(note_hits '^- 남는 원소$')"

echo "UT-12 CRLF line endings around the block are accepted"
rm -f "$state/notes"
check UT-12 "fence-crlf — exit code" 0 "$(run_post 16 "$sandbox/fence-crlf.md")"
check UT-12 "fence-crlf — summary posted" 1 "$(note_hits '^note: summary')"

echo "UT-29 the summary and inline comments are rendered from the data"
rm -f "$state/notes"
check UT-29 "exit code" 1 "$(run_post 26 "$sandbox/rendered.md")"
sed -n '/^note: summary/,$p' "$state/notes" > "$sandbox/summary.out"
order=$(grep -n '^- \*\*\[' "$sandbox/summary.out" | sed 's/^\([0-9]*\):- \*\*\[\([a-z]*\)\].*/\2/' | tr '\n' ' ')
check UT-29 "findings in severity order" "blocker major minor " "$order"
check UT-29 "location, title" 1 "$(grep -cF -- '- **[blocker]** `script/post-review.sh:9` — 등록 전에 검증하지 않는다' "$sandbox/summary.out")"
check UT-29 "problem, repro, recommendation" 3 "$(grep -cE '^  - (문제: 첫 줄|재현: 입력 A → 결과 B|권고: 이월한다)$' "$sandbox/summary.out")"
check UT-29 "a multi-line value stays indented" 1 "$(grep -cxF '    # 제목처럼 보이는 줄' "$sandbox/summary.out")"
check UT-29 "out of scope line" 1 "$(grep -cxF "  - $FMT_OUT_OF_SCOPE" "$sandbox/summary.out")"
check UT-29 "decision basis line" 1 "$(grep -cxF '  - 결정 재검토 근거: docs/adr/0004-x.md 의 Consequences' "$sandbox/summary.out")"
check UT-29 "no strengths section when empty" 0 "$(grep -c '^### 잘된 점' "$sandbox/summary.out")"
check UT-29 "summary section" 1 "$(grep -c '^### 요약' "$sandbox/summary.out")"
check UT-29 "inline comments for blocker and major only" 2 "$(note_hits '^note: inline')"
check UT-29 "inline body starts with the severity" 1 "$(note_hits '^note: inline 26 script/post-review.sh:9 \*\*\[blocker\]\*\* 등록 전에 검증하지 않는다$')"
check UT-29 "inline carries the out-of-scope line" 1 "$(grep -cxF "$FMT_OUT_OF_SCOPE" "$state/notes")"

echo "UT-29 a code fence or HTML block inside a value stays inside it"
rm -f "$state/notes"
check UT-29 "fence-in-text — exit code" 1 "$(run_post 26 "$sandbox/fence-in-text.md")"
check UT-29 "no fence or HTML block at the first column" 0 "$(note_hits '^\(```\|~~~\|<pre\)')"
sed -n '/^### 요약$/,/^### 발견 사항$/p' "$state/notes" > "$sandbox/fence-summary.out"
sed -n '/^### 잘된 점$/,/^note: /p' "$state/notes" > "$sandbox/fence-strengths.out"
check UT-29 "summary first line is escaped" 1 "$(grep -cxF '\```' "$sandbox/fence-summary.out")"
check UT-29 "summary continuation is indented" 2 "$(grep -cxE '    (정상|~~~)' "$sandbox/fence-summary.out")"
check UT-29 "strength first lines are escaped" 2 "$(grep -cxE -e '- \\(```|<pre>)' "$sandbox/fence-strengths.out")"
check UT-29 "strength continuation is indented" 2 "$(grep -cxE '  (잘된 점|둘째)' "$sandbox/fence-strengths.out")"
check UT-29 "finding and inline field continuations are indented" 4 "$(grep -cxF '    ```' "$state/notes")"

echo "UT-30 the next round reads what this round rendered"
# 이번 회차가 등록한 요약·인라인 본문을 그대로 다음 회차의 스레드로 준다. 알아보는 표지가 만드는
# 코드와 어긋나면 직전 회차 절과 증분 기준이 조용히 사라진다.
rm -f "$state/notes" "$state/labels"
reviewed=$(git -C "$work" rev-parse HEAD)
check UT-30 "this round — exit code" 1 "$(run_post 27 "$sandbox/rendered.md" "$reviewed")"
python3 - "$state/notes" "$state/threads.json" <<'PY'
import json, re, sys
text = open(sys.argv[1], encoding="utf-8").read()
parts = re.split(r"^note: ", text, flags=re.M)[1:]
threads, t = [], 0
for p in parts:
    t += 1
    at = "2026-09-23T10:%02d:00.000+09:00" % t
    if p.startswith("inline "):
        m = re.match(r"inline \S+ (\S+?):(\d+) ", p)
        body = p[m.end():].rstrip("\n")
        threads.append({"id": "t%d" % t, "inline": True, "path": m.group(1), "line": int(m.group(2)),
                        "notes": [{"body": body, "created_at": at},
                                  {"body": "이번 회차 발견에 단 답글이다.", "created_at": "2026-09-23T11:00:00.000+09:00"}]})
    else:
        body = p.split("\n", 1)[1]
        threads.append({"id": None, "inline": False, "path": "", "line": "",
                        "notes": [{"body": body, "created_at": at}]})
json.dump(threads, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
PY
echo "증분 확인" > "$work/next-round.txt"
git -C "$work" add -A
git -C "$work" -c core.hooksPath="$sandbox/nohooks" -c user.email=test@example.invalid \
  -c user.name=test commit -qm "next round"
echo "$ROUND:1" > "$state/labels"
rm -f "$state/reviewer-input"
check UT-30 "next round — exit code" 0 "$(run_review "$sandbox/clean.md")"
check UT-30 "previous summary in the input" 1 "$(input_hits '^> ### 요약')"
check UT-30 "previous finding in the input" 1 "$(input_hits '^> \*\*\[blocker\]\*\* 등록 전에 검증하지 않는다')"
check UT-30 "reply in the input" 2 "$(input_hits '이번 회차 발견에 단 답글이다')"
check UT-30 "increment from the rendered revision" 1 "$(input_hits "^## 증분 diff (직전 리뷰 ${reviewed:0:12}")"
rm -f "$state/threads.json"

echo "UT-14 the review input carries the MR body, issue body and previous round"
cat > "$state/mr-description" <<'MD'
## 관련 이슈

Closes #42

## 작업 목적

리뷰어가 맥락 없이 매 회차 백지에서 본다.

## 작업 사항

- 이 줄은 넘기지 않는다

## 리뷰 요청 포인트

증분 경계를 특히 본다.
MD
cat > "$state/issue.json" <<'JSON'
{"iid": 42, "title": "chore: 리뷰 루프 수렴",
 "description": "## 작업 내용\n\n이슈 본문에만 있는 문장이다."}
JSON
cat > "$state/threads.json" <<'JSON'
[{"notes": [{"body": "assigned to someone", "system": true,
             "created_at": "2026-09-22T10:00:00.000+09:00"}]},
 {"notes": [{"body": "**[major]** script/review-mr.sh:10 — 맥락이 없다", "system": false,
             "created_at": "2026-09-22T10:10:00.000+09:00"},
            {"body": "직전 회차 답글에만 있는 문장이다.", "system": false,
             "created_at": "2026-09-22T10:20:00.000+09:00"}]},
 {"notes": [{"body": "## 자동 리뷰 결과 (테스트)\n\n직전 요약에만 있는 문장이다.", "system": false,
             "created_at": "2026-09-22T10:11:00.000+09:00"}]}]
JSON
echo "$ROUND:1" > "$state/labels"
rm -f "$state/reviewer-input"
check UT-14 "exit code" 0 "$(run_review "$sandbox/clean.md")"
check UT-14 "purpose section of the MR body" 1 "$(input_hits '리뷰어가 맥락 없이')"
check UT-14 "review points section of the MR body" 1 "$(input_hits '증분 경계를 특히 본다')"
check UT-14 "other sections are left out" 0 "$(input_hits '이 줄은 넘기지 않는다')"
check UT-14 "issue body" 1 "$(input_hits '이슈 본문에만 있는 문장')"
check UT-14 "previous round summary" 1 "$(input_hits '직전 요약에만 있는 문장')"
check UT-14 "reply on the previous round's finding" 1 "$(input_hits '직전 회차 답글에만 있는 문장')"
check UT-14 "system notes are left out" 0 "$(input_hits 'assigned to someone')"
check UT-14 "diff comes after the context" yes "$(before '^## 직전 회차 리뷰' '^## 누적 diff')"
check UT-14 "diff body" 1 "$(input_hits '^+테스트 변경')"

echo "UT-15 round 1 has neither a previous round nor an increment"
rm -f "$state/labels" "$state/reviewer-input" "$state/notes"
check UT-15 "round 1 exit code" 0 "$(run_review "$sandbox/clean.md")"
check UT-15 "no previous-round section" 0 "$(input_hits '^## 직전 회차 리뷰')"
check UT-15 "no incremental section" 0 "$(input_hits '^## 증분 diff')"
check UT-15 "cumulative diff is present" 1 "$(input_hits '^## 누적 diff')"
check UT-15 "reviewed revision recorded in the summary" 1 "$(note_hits '리뷰 시점 head')"

echo "UT-16 the incremental diff is based on the revision in the previous summary note"
reviewed=$(git -C "$work" rev-parse HEAD)
cat > "$state/threads.json" <<JSON
[{"notes": [{"body": "## 자동 리뷰 결과 (테스트)\n\n> 리뷰 시점 head \`$reviewed\`", "system": false,
             "created_at": "2026-09-22T11:00:00.000+09:00"}]}]
JSON
for n in 1 2; do
  echo "증분 $n" > "$work/incremental-$n.txt"
  git -C "$work" add -A
  git -C "$work" -c core.hooksPath="$sandbox/nohooks" -c user.email=test@example.invalid \
    -c user.name=test commit -qm "incremental $n"
done
echo "$ROUND:1" > "$state/labels"
rm -f "$state/reviewer-input"
check UT-16 "exit code" 0 "$(run_review "$sandbox/clean.md")"
check UT-16 "incremental section" 1 "$(input_hits '^## 증분 diff')"
check UT-16 "file 1 added after the previous review" 1 "$(incr_hits '^+증분 1')"
check UT-16 "file 2 added after the previous review" 1 "$(incr_hits '^+증분 2')"
check UT-16 "changes before the previous review are left out" 0 "$(incr_hits 'review-mr.sh')"
check UT-16 "cumulative diff unchanged" 1 "$(input_hits '^## 누적 diff')"

echo "UT-17 with no revision in the previous note it runs without an increment"
cat > "$state/threads.json" <<'JSON'
[{"notes": [{"body": "## 자동 리뷰 결과 (테스트)\n\n리비전을 적지 않던 옛 형식이다.", "system": false,
             "created_at": "2026-09-22T11:00:00.000+09:00"}]}]
JSON
echo "$ROUND:1" > "$state/labels"
rm -f "$state/reviewer-input"
check UT-17 "exit code" 0 "$(run_review "$sandbox/clean.md")"
check UT-17 "no incremental section" 0 "$(input_hits '^## 증분 diff')"
check UT-17 "previous-round section is present" 1 "$(input_hits '^## 직전 회차 리뷰')"
check UT-17 "cumulative diff is present" 1 "$(input_hits '^## 누적 diff')"

echo "UT-18 the revision left in the summary is the reviewed one even if HEAD moves mid-review"
rm -f "$state/labels" "$state/notes" "$state/threads.json" "$state/mr-description" "$state/issue.json"
reviewed=$(git -C "$work" rev-parse HEAD)
STUB_COMMIT="$work/during-review.txt"
check UT-18 "exit code" 0 "$(run_review "$sandbox/clean.md")"
STUB_COMMIT=""
moved=$(git -C "$work" rev-parse HEAD)
check UT-18 "HEAD moved during the review" yes "$([ "$moved" != "$reviewed" ] && echo yes || echo no)"
check UT-18 "summary carries the reviewed revision" 1 "$(note_hits "리뷰 시점 head .$reviewed")"
check UT-18 "the unreviewed revision is not recorded" 0 "$(note_hits "리뷰 시점 head .$moved")"

echo "UT-19 the reviewed revision is accepted only in SHA form"
rm -f "$state/notes"
check UT-19 "malformed — exit code" 2 "$(run_post 23 "$sandbox/clean.md" "not-a-sha")"
check UT-19 "malformed — post calls" 0 "$(note_hits 'note:')"
rm -f "$state/notes"
check UT-19 "records the passed revision as given" 0 "$(run_post 24 "$sandbox/clean.md" "0123456789abcdef")"
check UT-19 "recorded value" 1 "$(note_hits '리뷰 시점 head .0123456789abcdef')"

echo "UT-20 a revision that is not an ancestor is not used as the increment base"
# 리베이스·force push 를 재현한다 — 옛 리비전은 객체로 남지만 현재 리비전의 조상이 아니다.
rebased_away=$(git -C "$work" rev-parse HEAD)
git -C "$work" branch -q keep-rebased-away "$rebased_away"
git -C "$work" reset -q --hard HEAD~1
echo "리베이스로 들어온 변경" > "$work/after-rebase.txt"
git -C "$work" add -A
git -C "$work" -c core.hooksPath="$sandbox/nohooks" -c user.email=test@example.invalid \
  -c user.name=test commit -qm "after rebase"
cat > "$state/threads.json" <<JSON
[{"notes": [{"body": "## 자동 리뷰 결과 (테스트)\n\n> 리뷰 시점 head \`$rebased_away\`", "system": false,
             "created_at": "2026-09-22T12:00:00.000+09:00"}]}]
JSON
echo "$ROUND:1" > "$state/labels"
rm -f "$state/reviewer-input"
check UT-20 "the old revision object still exists" yes \
  "$(git -C "$work" cat-file -e "$rebased_away^{commit}" 2>/dev/null && echo yes || echo no)"
check UT-20 "exit code" 0 "$(run_review "$sandbox/clean.md")"
check UT-20 "no incremental section" 0 "$(input_hits '^## 증분 diff')"
check UT-20 "records the reason" 1 "$(log_hits 'not an ancestor')"
check UT-20 "cumulative diff is present" 1 "$(input_hits '^## 누적 diff')"
# 조상이면 그대로 증분을 만든다 — 차이가 조상 여부뿐임을 보인다.
ancestor=$(git -C "$work" rev-parse HEAD)
echo "리뷰 이후 변경" > "$work/after-review.txt"
git -C "$work" add -A
git -C "$work" -c core.hooksPath="$sandbox/nohooks" -c user.email=test@example.invalid \
  -c user.name=test commit -qm "after review"
cat > "$state/threads.json" <<JSON
[{"notes": [{"body": "## 자동 리뷰 결과 (테스트)\n\n> 리뷰 시점 head \`$ancestor\`", "system": false,
             "created_at": "2026-09-22T12:00:00.000+09:00"}]}]
JSON
echo "$ROUND:1" > "$state/labels"
rm -f "$state/reviewer-input"
check UT-20 "ancestor — exit code" 0 "$(run_review "$sandbox/clean.md")"
check UT-20 "ancestor — incremental section" 1 "$(input_hits '^## 증분 diff')"
check UT-20 "increment holds only the post-review change" 1 "$(incr_hits '^+리뷰 이후 변경')"
check UT-20 "the rebased-in change is left out" 0 "$(incr_hits '리베이스로 들어온 변경')"

echo "UT-21 the judgment data schema agrees between the module and the role contracts"
# 쓰는 쪽(역할 계약)과 읽는 쪽(모듈)이 서로 다른 키를 보면, 리뷰는 정상인데 등록이 계약 위반으로
# 멈춘다. 둘을 잇는 것은 이 검사뿐이다.
python3 - "$repo_root/script/_review.py" > "$sandbox/schema-terms" <<'PY'
import runpy, sys
sys.dont_write_bytecode = True
m = runpy.run_path(sys.argv[1], run_name="schema")
for k in m["TOP_KEYS"] + m["FINDING_KEYS"] + m["SEVERITIES"]:
    print(k)
PY
for contract in "$repo_root/.ai/templates/code-reviewer.md" "$repo_root/.ai/templates/security-guard.md"; do
  # 역할을 뺀 설정에서는 그 계약이 깔리지 않는다. 있는 계약만 본다.
  [ -f "$contract" ] || continue
  name=$(basename "$contract")
  while read -r term; do
    check UT-21 "$name names \`$term\`" 1 "$(grep -cF -- "\`$term\`" "$contract" >/dev/null 2>&1 && echo 1 || echo 0)"
  done < "$sandbox/schema-terms"
  for m in "$FMT_REVIEW_BLOCK" "$FMT_VERDICT_PASS" "$FMT_VERDICT_CHANGES"; do
    check UT-21 "$name names \`$m\`" 1 "$(grep -cF -- "\`$m\`" "$contract" >/dev/null 2>&1 && echo 1 || echo 0)"
  done
  check UT-21 "$name has no findings-heading rule" 0 "$(grep -c '## 발견 사항' "$contract")"
  check UT-21 "$name has no REVIEW_VERDICT rule" 0 "$(grep -c 'REVIEW_VERDICT' "$contract")"
done
[ ! -e "$repo_root/script/__pycache__" ] && [ ! -e "$work/script/__pycache__" ] && ok_pyc=yes || ok_pyc=no
check UT-21 "reading the schema leaves no bytecode" yes "$ok_pyc"

echo "UT-24 the review scripts carry no embedded python"
# 파이썬은 script/_review.py 한 곳에 둔다. 스크립트 본문에 흩어지면 같은 규칙이 두 번 적힌다.
for f in review-mr.sh post-review.sh; do
  check UT-24 "$f — python3 -c" 0 "$(grep -c 'python3 -c' "$work/script/$f")"
  check UT-24 "$f — python heredoc" 0 "$(grep -cE 'python3 +-( |$)' "$work/script/$f")"
done

echo "UT-25 the MR body goes whole when neither context section is there"
cat > "$state/mr-description" <<'MD'
## 다른 절

목적 절도 포인트 절도 없는 본문의 문장이다.
MD
rm -f "$state/threads.json" "$state/issue.json" "$state/reviewer-input"
echo "$ROUND:1" > "$state/labels"
check UT-25 "exit code" 0 "$(run_review "$sandbox/clean.md")"
check UT-25 "the whole body is passed" 1 "$(input_hits '목적 절도 포인트 절도 없는 본문의 문장')"
check UT-25 "the other heading is quoted" 1 "$(input_hits '^> ## 다른 절')"
rm -f "$state/mr-description"

echo "UT-26 the round is the largest round label"
printf '{"labels": ["%s:1", "other", "%s:3", "%s:x"]}' "$ROUND" "$ROUND" "$ROUND" > "$sandbox/round.json"
check UT-26 "largest round" 3 "$(python3 "$work/script/_review.py" round "$sandbox/round.json" "$ROUND" | sed -n 1p)"
check UT-26 "round labels" "$ROUND:1 $ROUND:3" "$(python3 "$work/script/_review.py" round "$sandbox/round.json" "$ROUND" | sed -n 2p)"
printf '{"labels": ["other"]}' > "$sandbox/round.json"
check UT-26 "no round label" 0 "$(python3 "$work/script/_review.py" round "$sandbox/round.json" "$ROUND" | sed -n 1p)"

echo "UT-27 a marker missing from the environment stops the module"
printf '{"description": "Closes #1"}' > "$sandbox/ref.json"
check UT-27 "issue-ref without FMT_MR_CLOSES" 2 \
  "$(env -u FMT_MR_CLOSES python3 "$work/script/_review.py" issue-ref "$sandbox/ref.json" >/dev/null 2>&1; echo $?)"
mkdir -p "$sandbox/ctx"
check UT-27 "context without FMT_SUMMARY_HEADING" 2 \
  "$(env -u FMT_SUMMARY_HEADING FMT_MR_PURPOSE=a FMT_MR_REVIEW_POINTS=b FMT_REVIEWED_HEAD=c FMT_INLINE_SEVERITIES=major \
       python3 "$work/script/_review.py" context "$sandbox/ctx" 0 "" >/dev/null 2>&1; echo $?)"

echo "UT-28 the review loop leaves no bytecode"
check UT-28 "no script/__pycache__" no "$([ -e "$work/script/__pycache__" ] && echo yes || echo no)"

echo "UT-31 the main tree and a linked worktree share one review history"
git -C "$work" worktree add -q --detach "$sandbox/linked" >/dev/null 2>&1 || { echo "failed to add a linked worktree" >&2; exit 2; }
run_post_at() { # <하네스 루트> <MR번호> <리뷰본문>
  ( cd "$1" && PATH="$stub:$PATH" FAKE_STATE="$state" script/post-review.sh "$2" "$3" "테스트" >"$state/last.log" 2>&1 )
  echo $?
}
check UT-31 "main tree — round 1 exit code" 1 "$(run_post_at "$work" 31 "$sandbox/same-major.md")"
check UT-31 "linked worktree — round 2 exit code" 1 "$(run_post_at "$sandbox/linked" 31 "$sandbox/same-major.md")"
check UT-31 "main tree — round 3 counts on from the worktree's round" 3 "$(run_post_at "$work" 31 "$sandbox/same-major.md")"
check UT-31 "one history file in the common git directory" "1 2 3" \
  "$(tail -n +2 "$work/.git/work-loop/review-findings-31.tsv" | cut -f1 | tr '\n' ' ' | sed 's/ $//')"
check UT-31 "the linked worktree keeps no history of its own" no \
  "$([ -e "$(git -C "$sandbox/linked" rev-parse --absolute-git-dir)/work-loop" ] && echo yes || echo no)"
# 하네스 루트가 리포 루트 아래에 있어도 같은 자리를 쓴다
mkdir -p "$work/sub" && cp -R "$work/script" "$work/sub/"
check UT-31 "harness root below the repo root — exit code" 1 "$(run_post_at "$work/sub" 32 "$sandbox/same-major.md")"
check UT-31 "harness root below the repo root — history in the common git directory" yes \
  "$([ -f "$work/.git/work-loop/review-findings-32.tsv" ] && [ ! -e "$work/sub/.git" ] && echo yes || echo no)"
git -C "$work" worktree remove --force "$sandbox/linked" >/dev/null 2>&1
rm -rf "$work/sub"

echo "UT-32 the fake thread listing emits every contract key"
# 페이크가 어댑터 계약보다 좁으면, 계약 키에 기대는 호출부가 테스트에서는 통과하고 실제 forge 에서 깨진다.
fake() { ( cd "$work" && FAKE_STATE="$state" sh -c '. script/forge.sh && "$@"' fake "$@" ) }
cat > "$state/threads.json" <<'JSON'
[{"inline": true, "path": "script/review-mr.sh", "line": 10,
  "notes": [{"body": "인라인 발견", "created_at": "2026-09-23T10:00:00.000+09:00"}]},
 {"notes": [{"body": "일반 노트", "created_at": "2026-09-23T10:01:00.000+09:00"}]}]
JSON
fake review_mr_threads 1 > "$sandbox/fake-threads.json"
check UT-32 "listing — exit code" 0 "$?"
check UT-32 "every item has the contract keys" yes "$(python3 - "$sandbox/fake-threads.json" <<'PY'
import json, sys
keys = {"id", "inline", "path", "line", "notes"}
print("yes" if all(set(t) == keys for t in json.load(open(sys.argv[1]))) else "no")
PY
)"
check UT-32 "inline thread id is a string" yes "$(python3 - "$sandbox/fake-threads.json" <<'PY'
import json, sys
t = json.load(open(sys.argv[1]))[0]
print("yes" if t["inline"] and isinstance(t["id"], str) and t["id"] else "no")
PY
)"
check UT-32 "plain note id is null" yes "$(python3 - "$sandbox/fake-threads.json" <<'PY'
import json, sys
t = json.load(open(sys.argv[1]))[1]
print("yes" if not t["inline"] and t["id"] is None else "no")
PY
)"

echo "UT-33 the fake replies on an existing thread"
tid=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))[0]["id"])' "$sandbox/fake-threads.json")
fake review_mr_thread_reply 1 "$tid" "페이크 답글" 2>/dev/null
check UT-33 "reply — exit code" 0 "$?"
fake review_mr_threads 1 > "$sandbox/fake-threads.json"
check UT-33 "reply is appended to that thread's notes" "인라인 발견|페이크 답글" \
  "$(python3 -c 'import json, sys; print("|".join(n["body"] for n in json.load(open(sys.argv[1]))[0]["notes"]))' "$sandbox/fake-threads.json")"
check UT-33 "the other thread is untouched" 1 \
  "$(python3 -c 'import json, sys; print(len(json.load(open(sys.argv[1]))[1]["notes"]))' "$sandbox/fake-threads.json")"
fake review_mr_thread_reply 1 "no-such-thread" "x" 2>/dev/null
check UT-33 "unknown id — exit code" 1 "$?"
fake review_mr_thread_reply 1 "None" "x" 2>/dev/null
check UT-33 "a plain note takes no reply" 1 "$?"
# 시스템 노트만 있어 조회에서 빠지는 id 없는 인라인 항목과, 합성 id 와 같은 값을 명시한 스레드가 함께 있다.
# 조회가 준 id 로 단 답글은 조회된 그 스레드에만 붙어야 한다.
cat > "$state/threads.json" <<'JSON'
[{"inline": true, "path": "script/review-mr.sh", "line": 1,
  "notes": [{"body": "added a commit", "system": true, "created_at": "2026-09-23T10:00:00.000+09:00"}]},
 {"id": "t1", "inline": true, "path": "script/review-mr.sh", "line": 2,
  "notes": [{"body": "명시 id 스레드", "created_at": "2026-09-23T10:01:00.000+09:00"}]},
 {"inline": true, "path": "script/review-mr.sh", "line": 3,
  "notes": [{"body": "합성 id 스레드", "created_at": "2026-09-23T10:02:00.000+09:00"}]}]
JSON
fake review_mr_threads 1 > "$sandbox/fake-threads.json"
check UT-33 "synthetic ids stay clear of explicit ones" yes "$(python3 - "$sandbox/fake-threads.json" <<'PY'
import json, sys
ids = [t["id"] for t in json.load(open(sys.argv[1]))]
print("yes" if len(ids) == 2 and ids[0] == "t1" and ids[1] not in (None, "t1") else "no")
PY
)"
fake review_mr_thread_reply 1 t1 "명시 id 에 단 답글" 2>/dev/null
check UT-33 "explicit id reply — exit code" 0 "$?"
check UT-33 "the reply lands only on the listed thread" "1:|2:명시 id 에 단 답글|3:합성 id 스레드" "$(python3 - "$state/threads.json" <<'PY'
import json, sys
ts = json.load(open(sys.argv[1]))
print("|".join("%d:%s" % (t["line"], "" if t["notes"][-1].get("system") else t["notes"][-1]["body"]) for t in ts))
PY
)"
cat > "$state/threads.json" <<'JSON'
[{"id": "dup", "inline": true, "notes": [{"body": "a", "created_at": ""}]},
 {"id": "dup", "inline": true, "notes": [{"body": "b", "created_at": ""}]}]
JSON
fake review_mr_thread_reply 1 dup "x" 2>/dev/null
check UT-33 "an id naming two threads takes no reply" 1 "$?"
# 일반 노트는 픽스처가 id 를 적었어도 답글을 받지 않는다 — 실제 어댑터가 null 로 내는 자리다.
cat > "$state/threads.json" <<'JSON'
[{"id": "note-1", "inline": false, "notes": [{"body": "일반 노트", "created_at": ""}]}]
JSON
check UT-33 "a plain note with a fixture id lists a null id" yes \
  "$(fake review_mr_threads 1 | python3 -c 'import json, sys; print("yes" if json.load(sys.stdin)[0]["id"] is None else "no")')"
fake review_mr_thread_reply 1 note-1 "x" 2>/dev/null
check UT-33 "a plain note with a fixture id takes no reply" 1 "$?"
check UT-33 "that plain note is untouched" 1 \
  "$(python3 -c 'import json, sys; print(len(json.load(open(sys.argv[1]))[0]["notes"]))' "$state/threads.json")"
# 합성 id 순번은 조회에 남은 id 없는 인라인 스레드만 센다. 걸러진 항목은 번호를 차지하지 않는다.
cat > "$state/threads.json" <<'JSON'
[{"inline": true, "notes": [{"body": "added a commit", "system": true, "created_at": ""}]},
 {"inline": true, "notes": [{"body": "남은 인라인", "created_at": ""}]}]
JSON
check UT-33 "a filtered item takes no synthetic number" t1 \
  "$(fake review_mr_threads 1 | python3 -c 'import json, sys; print(json.load(sys.stdin)[0]["id"])')"
rm -f "$state/threads.json"

# 리뷰 도구를 부를 때마다 지표에 에이전트 스팬이 남고, 벤더 형식에서 꺼낸 사용량이 같은 뜻으로 맞춰진다.
# 스텁은 두 벤더 모두 입력(캐시 제외) 11 + 출력 7 = 18 을 낸다
tokens=$(python3 - "$sandbox/metrics" <<'PY'
import glob, json, sys
ev = [json.loads(l) for f in glob.glob(sys.argv[1] + "/spans-*.jsonl") for l in open(f)]
agents = {e["span"] for e in ev if e.get("ev") == "start" and e.get("kind") == "agent" and e["attrs"].get("role") == "code-reviewer"}
ends = [e for e in ev if e.get("ev") == "end" and e["span"] in agents and e.get("usage")]
print(sorted({e["usage"]["input"] + e["usage"]["output"] for e in ends}) if ends else "none")
PY
)
check UT-23 "the reviewer's token usage lands in the metrics" "[18]" "$tokens"

echo
if [ "$fail" -gt 0 ]; then
  echo "review loop test failed: $pass passed, $fail failed" >&2
  echo "last run log:" >&2
  cat "$state/last.log" >&2
  exit 1
fi
echo "review loop test passed: $pass checks"
