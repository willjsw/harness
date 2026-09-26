#!/usr/bin/env bash
# 커밋에 들어가려는 자격증명을 찾는다.
#
#   script/secret-scan.sh            작업 트리가 HEAD 에 대해 더한 줄
#   script/secret-scan.sh --staged   인덱스(이번 커밋에 들어갈 내용)가 더한 줄
#
# 종료 코드: 0 = 발견 없음 · 1 = 발견 · 2 = 실행 실패
#
# **더한 줄만 본다.** 파일 전체를 훑으면 이미 들어와 있는 것이 매 커밋마다 다시 걸려, 몇 번
# 만에 `--no-verify` 가 습관이 된다. 이 층이 막는 것은 **새로 들어오는 것**이다.
#
# **이미 커밋된 것은 이 스크립트가 찾지 못한다.** 히스토리 전수 조사는 다른 도구의 일이다
# (`gitleaks detect`). 그리고 히스토리에서 지우는 것으로는 유출이 되돌려지지 않는다 —
# 한 번 push 된 값은 폐기하고 재발급하는 것이 유일한 조치다.
#
# **오탐이 이 층을 죽인다.** 형태가 분명한 것만 잡고, 일반 대입은 길이·엔트로피·자리표시자
# 제외를 모두 통과할 때만 잡는다. 그래도 아니면 그 줄에 표지를 단다 (아래 `허용 표지`).
#
# 의존성은 python3 뿐이다. 외부 도구가 있어야 도는 층은 대부분의 리포에서 꺼져 있는 층이다.
set -euo pipefail
# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. script/harness-format.sh

usage() { echo "usage: script/secret-scan.sh [--staged]" >&2; exit 2; }

[ $# -le 1 ] || usage
case "${1:-}" in ""|--staged) ;; *) echo "error: unknown option: $1" >&2; usage ;; esac
mode="${1:-}"

command -v python3 >/dev/null || { echo "error: python3 is not installed" >&2; exit 2; }

# 첫 커밋 전에는 HEAD 가 없다. 그때는 빈 트리를 기준으로 삼는다.
if git rev-parse --verify -q HEAD >/dev/null; then base=HEAD; else base=$(git hash-object -t tree /dev/null); fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# **diff 를 파이프가 아니라 파일로 넘긴다.** 프로그램을 heredoc 으로 주면 그것이 stdin 을
# 차지해, 파이프로 보낸 내용이 조용히 비어 버린다 — 검사가 통과만 하는 상태가 된다.
if [ "$mode" = "--staged" ]; then
  git diff --cached -U0 --no-color --diff-filter=ACMR "$base" > "$work/diff.patch"
else
  git diff -U0 --no-color --diff-filter=ACMR "$base" > "$work/diff.patch"
fi

python3 - "$FMT_SECRET_ALLOW" "$work/diff.patch" <<'PY'
import math, re, sys

allow_marker = sys.argv[1]

# 형태가 분명한 것들. 접두가 그 발급처를 확정하므로 오탐이 거의 없다.
# **여기 적는 것은 탐지 패턴이지 값이 아니다.**
KNOWN = [
    (r"\bAKIA[0-9A-Z]{16}\b",                      "AWS access key id"),
    (r"\bASIA[0-9A-Z]{16}\b",                      "AWS temporary access key id"),
    (r"\bgh[pousr]_[A-Za-z0-9]{36,}\b",            "GitHub token"),
    (r"\bglpat-[A-Za-z0-9_\-]{20,}\b",             "GitLab personal access token"),
    (r"\bgldt-[A-Za-z0-9_\-]{20,}\b",              "GitLab deploy token"),
    (r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b",          "Slack token"),
    (r"\bATATT3xFfGF0[A-Za-z0-9_\-=]{20,}",        "Atlassian API token"),
    (r"\bsk-ant-[A-Za-z0-9_\-]{20,}\b",            "Anthropic API key"),
    (r"\bsk-proj-[A-Za-z0-9_\-]{20,}\b",           "OpenAI project key"),
    (r"\bsk-[A-Za-z0-9]{32,}\b",                   "OpenAI API key"),
    (r"\b(sk|rk)_live_[A-Za-z0-9]{16,}\b",         "Stripe live key"),
    (r"\bAIza[0-9A-Za-z_\-]{35}\b",                "Google API key"),
    (r"\bnpm_[A-Za-z0-9]{36}\b",                   "npm token"),
    (r"\bpypi-AgEIcHlwaS5vcmc[A-Za-z0-9_\-]{10,}", "PyPI token"),
    (r"\bSG\.[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}", "SendGrid key"),
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----",        "private key block"),
    (r"\beyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.", "JSON web token"),
    (r"\b[a-z0-9]+://[^\s:@/]+:[^\s:@/]{8,}@",     "credential embedded in a URL"),
]
KNOWN = [(re.compile(p), name) for p, name in KNOWN]

# 이름이 자격증명을 가리키는 대입. 형태만으로는 알 수 없으므로 아래 세 검사를 모두 통과해야 한다.
ASSIGN = re.compile(
    r"([A-Za-z0-9_\-.]*(?:pass(?:word|wd)?|secret|token|api[_\-]?key|access[_\-]?key|"
    r"private[_\-]?key|client[_\-]?secret|credential|auth)[A-Za-z0-9_\-.]*)"
    r"\s*[:=]\s*[\"']?([A-Za-z0-9+/=_\-.]{16,})[\"']?", re.I)

# 값이 아니라 자리표시자인 신호. 하나라도 걸리면 대입 규칙에서 뺀다.
PLACEHOLDER = re.compile(
    r"^(?:changeme|change_me|password|passwd|secret|token|dummy|example|sample|"
    r"placeholder|redacted|none|null|true|false|undefined|localhost)$"
    r"|your[_\-]|my[_\-]|xxxx|\*\*\*|example\.com|<|>|\$\{|\$\(|%s|\{\}",
    re.I)

# 구분자로 나뉜 이름 — 경로(`config/tokens/service.json`)나 점 표기(`com.foo.Bar`)다.
# 엔트로피만 보면 이런 값이 자격증명으로 보인다. 오탐이 이 층을 죽이므로 먼저 걷어낸다.
STRUCTURED = re.compile(r"^[A-Za-z0-9_\-]+(?:[/.][A-Za-z0-9_\-]+)+$")


def entropy(s):
    """값이 사람이 정한 문자열인지 발급된 것인지를 가르는 대략의 신호."""
    return -sum((n / len(s)) * math.log2(n / len(s))
                for n in (s.count(c) for c in set(s)))


def findings(line):
    out = []
    for pat, name in KNOWN:
        if pat.search(line):
            out.append(name)
    for m in ASSIGN.finditer(line):
        v = m.group(2)
        if PLACEHOLDER.search(v) or STRUCTURED.match(v) or v.startswith("$") or len(set(v)) < 6:
            continue
        if entropy(v) < 3.0:
            continue
        out.append("credential-shaped assignment to `%s`" % m.group(1))
    return out


path, lineno, hits = "", 0, []
for raw in open(sys.argv[2], encoding="utf-8", errors="replace").read().splitlines():
    if raw.startswith("+++ b/"):
        path, lineno = raw[6:], 0
        continue
    if raw.startswith("@@"):
        m = re.match(r"@@ -\S+ \+(\d+)", raw)
        lineno = int(m.group(1)) if m else 0
        continue
    if not raw.startswith("+") or raw.startswith("+++"):
        continue
    line = raw[1:]
    if allow_marker not in line:
        for what in findings(line):
            hits.append((path, lineno, what))
    lineno += 1

if not hits:
    sys.exit(0)

print("blocked: possible credential in the lines being added", file=sys.stderr)
print(file=sys.stderr)
width = max(len("%s:%d" % (p, n)) for p, n, _w in hits)
for p, n, what in hits:
    print("  %-*s  %s" % (width, "%s:%d" % (p, n), what), file=sys.stderr)
print(file=sys.stderr)
print("help: if it is a real credential, remove it and **rotate it** — committing is enough to leak it",
      file=sys.stderr)
print("help: if it is not, mark that line and rerun", file=sys.stderr)
print("        <the line>   %s" % allow_marker, file=sys.stderr)
sys.exit(1)
PY
