#!/usr/bin/env bash
# 렌더·검사 회귀 테스트. 원격도 대상 리포도 건드리지 않는다 — 임시 디렉터리에서만 돈다.
#
#   src/test/render-test.sh
#
# 확인하는 것: 설정 하나를 고치면 그것을 쓰는 생성 파일이 **전부** 따라 바뀌는가,
# 생성 파일을 손으로 고치면 check 가 잡는가, 불변식 위반이 render 를 막는가.
# 이 셋이 하네스가 약속하는 전부다.
set -uo pipefail
# 블록 감시. 이 테스트 전체를 새 세션(프로세스 그룹)으로 띄우고 표준 출력의 블록 표지(`UT-<번호>` 로
# 시작하는 줄)를 지켜본다. 한 블록이 RENDER_TEST_BLOCK_LIMIT 초(기본 900) 안에 다음 표지로 넘어가지 않으면
# 그 블록 이름을 찍고 그룹째 끝낸 뒤 124 로 끝난다 — 어느 블록의 어느 명령이 멈추든 진행 없이 기다리지
# 않는다. 그때 돌던 명령도 찍지만 그 진단이 실패하거나 멈춰도 종료 절차는 그대로 돈다.
# 시간은 기기가 깨어 있는 동안만 센다(macOS CLOCK_UPTIME_RAW, 그 밖은 monotonic) — 잠자기로 얼어 있던
# 시간을 멈춤으로 세지 않는다. 표준 입력은 닫는다.
# 제한 시간이 유한한 양수가 아니면 아무것도 띄우지 않고 2 로 끝난다.
# 테스트가 감시 자체를 검사할 수 있게 본문을 변수에 두고, 모듈로 불러 시계(now)를 바꿔 끼울 수 있게 한다.
watch_py='
import math, os, re, signal, subprocess, sys, threading, time

MARKER = re.compile(rb"^UT-[0-9]+[a-z]*\b")
_clock = getattr(time, "CLOCK_UPTIME_RAW", None)
now = (lambda: time.clock_gettime(_clock)) if _clock is not None else time.monotonic
current = None   # 지금 감시 중인 Blocks — 바꿔 끼운 시계가 진행 상태를 볼 수 있게 둔다


def parse_limit(raw):
    """유한한 양수 초면 그 값, 아니면 None."""
    try:
        v = float(raw)
    except ValueError:
        return None
    return v if math.isfinite(v) and v > 0 else None


class Blocks:
    """마지막으로 시작한 블록과 그 시각. 시각은 부르는 쪽이 넘긴다."""

    def __init__(self, limit, t):
        self.limit, self.block, self.since = limit, "(before the first block)", t

    def line(self, data, t):
        if MARKER.match(data):
            self.block = data.split(b" ", 1)[0].strip().decode("ascii", "replace")
            self.since = t

    def expired(self, t):
        return t - self.since >= self.limit


def group_commands(pgid):
    """그룹에 남은 명령(그룹 대표인 본문 자신 포함). 목록을 믿을 수 없으면 None — ps 를 띄우지 못했거나,
    5초 안에 끝나지 않았거나, 0 이 아닌 코드로 끝났거나, 아직 살아 있는 본문 자신조차 목록에 없을 때."""
    try:
        r = subprocess.run(["ps", "-A", "-o", "pgid=,pid=,command="], stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, errors="replace", timeout=5)
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    out, leader = [], False
    for l in r.stdout.splitlines():
        f = l.split(None, 2)
        if len(f) == 3 and f[0] == str(pgid):
            leader = leader or f[1] == str(pgid)
            out.append("  %s %s" % (f[1], f[2][:200]))
    return out if leader else None


def main(argv):
    global current
    raw = os.environ.get("RENDER_TEST_BLOCK_LIMIT", "900")
    limit = parse_limit(raw)
    if limit is None:
        print("error: RENDER_TEST_BLOCK_LIMIT must be a positive number of seconds, got %r" % raw, file=sys.stderr)
        sys.exit(2)
    current = Blocks(limit, now())
    p = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                         env=dict(os.environ, RENDER_TEST_WATCHED="1"), start_new_session=True)

    def pump():
        for line in iter(p.stdout.readline, b""):
            current.line(line, now())
            sys.stdout.buffer.write(line)
            sys.stdout.buffer.flush()
    reader = threading.Thread(target=pump, daemon=True)
    reader.start()

    def stop(sig):
        try:
            os.killpg(p.pid, sig)
        except OSError:
            pass

    def finish(code):
        stop(signal.SIGKILL)
        p.wait()
        reader.join(5)
        for f in (sys.stdout, sys.stderr):
            try:
                f.flush()
            except Exception:
                pass
        os._exit(code)

    def interrupted(signum, _frame):
        stop(signal.SIGTERM)
        finish(128 + signum)
    for s in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(s, interrupted)

    while p.poll() is None:
        if current.expired(now()):
            # 진단은 덤이다 — 무엇이 실패하든 아래 finally 의 종료 절차와 124 는 반드시 돈다
            try:
                print("render-test: %s did not finish within %gs and was stopped" % (current.block, limit),
                      file=sys.stderr, flush=True)
                running = group_commands(p.pid)
                if running is None:
                    print("  could not list what was still running", file=sys.stderr)
                elif running:
                    print("  still running:\n" + "\n".join(running), file=sys.stderr)
            finally:
                stop(signal.SIGTERM)
                grace = now() + 5
                while p.poll() is None and now() < grace:
                    time.sleep(0.1)
                finish(124)
        time.sleep(0.2)
    # 본문이 끝나도 그룹에 남은 자식이 출력 통로를 쥔 채 다음 단계를 붙잡지 않게 정리한다
    finish(p.returncode if p.returncode >= 0 else 128 - p.returncode)


if __name__ == "__main__":
    main(sys.argv[1:])
'
# 블록 병렬 실행. 블록을 묶음으로 나눠 RENDER_TEST_JOBS(기본: 코어 수, 최대 8)개의 셸에서 동시에 돌린다.
# 블록이 자기 안에서 정하기 전에 쓰는 변수를 앞 블록이 정했으면, 그 블록부터 여기까지를 한 묶음으로 둔다
# (앞 블록이 만든 대상 `$t` 를 이어 쓰는 경우). 셸마다 머리말(공용 함수)과 자기 묶음만 담은 사본이 돌고,
# 작업 디렉터리·감시를 따로 갖는다. RENDER_TEST_JOBS=1 이면 한 셸에서 순서대로 돈다.
# ponytail: 의존은 변수 이름으로만 찾는다. 앞 블록이 만든 파일·함수를 쓰는 블록이 생기면 그 블록이 실패한다 —
#           그때는 그 블록에서 대상을 새로 만든다
shard_py='
import os, re, shlex, shutil, subprocess, sys, tempfile, time
src = os.path.abspath(sys.argv[1])
text = open(src, encoding="utf-8").read()
start = text.index("\necho \"UT-") + 1
foot = text.index("\necho\nif [ \"$fail\" -eq 0 ]")
head = text[:start].replace("cd \"$(dirname \"$0\")/..\"", "cd " + shlex.quote(os.path.dirname(os.path.dirname(src))), 1)
blocks = [b for b in re.split(r"(?m)^(?=echo \"UT-)", text[start:foot]) if b.strip()]
# 블록 안에서 정의한 도우미 함수는 다른 블록도 부른다 — 정의만 모아 셸마다 머리말 뒤에 싣는다(부작용이 없다)
lines, defs, i = text[start:foot].split("\n"), [], 0
while i < len(lines):
    if re.match(r"[A-Za-z_]\w*\(\)\s*\{", lines[i]):
        j = i   # 정의의 끝: `}` 로 끝나는 줄 중 거기까지가 셸 문법으로 닫히는 첫 줄
        while j < len(lines) and not (lines[j].rstrip().endswith("}") and subprocess.run(
                ["bash", "-n"], input="\n".join(lines[i:j + 1]), text=True, capture_output=True).returncode == 0):
            j += 1
        defs.append("\n".join(lines[i:j + 1]))
        i = j
    i += 1
head += "\n".join(defs) + "\n"
token = re.compile(r"(?<!,)\$\{?([A-Za-z_]\w*)|(?:^|[;\s(])([A-Za-z_]\w*)=|(?:for|read -r|local)\s+([A-Za-z_][\w ]*)", re.M)
shared = {"root", "work", "pass", "fail", "HOME", "PATH", "HARNESS_HOME", "PWD", "TMPDIR", "RANDOM"}
defined, unit = {}, list(range(len(blocks)))   # unit[i] = 이 블록이 속한 묶음의 첫 블록
heredoc = re.compile(r"<<-?\s*[\x27\"]?(\w+)[\x27\"]?[^\n]*\n.*?\n\s*\1\n", re.S)   # 안의 다른 언어 코드는 셸 변수가 아니다
for i, b in enumerate(blocks):
    local = set()
    for use, assign, loop in (m.groups() for m in token.finditer(heredoc.sub("\n", b))):
        if assign:
            local.add(assign)
        elif loop:
            local.update(loop.split())
        elif use and use not in local and use not in shared and use in defined:
            for k in range(defined[use], i + 1):
                unit[k] = unit[defined[use]]
    for v in local:
        defined[v] = i
for i in range(1, len(blocks)):   # 묶음은 이어진 범위다 — 범위 안 블록은 앞 묶음을 따른다
    unit[i] = min(unit[i], unit[unit[i]])
units = {}
for i, u in enumerate(unit):
    units.setdefault(u, []).append(i)
jobs = max(1, min(int(os.environ.get("RENDER_TEST_JOBS") or os.cpu_count() or 1), 8, len(units)))
shards = [[] for _ in range(jobs)]
for u in sorted(units.values(), key=lambda ix: -sum(len(blocks[i]) for i in ix)):   # 긴 묶음부터 가장 가벼운 셸에
    min(shards, key=lambda s: sum(len(blocks[i]) for i in s)).extend(u)
tmp = tempfile.mkdtemp(prefix="render-test-")
env = {k: v for k, v in os.environ.items() if k != "RENDER_TEST_WATCHED"}
procs = []
for n, s in enumerate(shards):
    f = os.path.join(tmp, "shard-%d.sh" % n)
    open(f, "w", encoding="utf-8").write(head + "".join(blocks[i] for i in sorted(s)) + text[foot:])
    log = open(os.path.join(tmp, "shard-%d.log" % n), "w+")
    procs.append((subprocess.Popen(["bash", f], stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                   env=dict(env, RENDER_TEST_SHARD=str(n))), log))
t0, took = time.time(), {}
while len(took) < len(procs):   # 셸마다 끝난 시각을 잰다 — 가장 느린 셸이 전체 시간이다
    for n, (p, _log) in enumerate(procs):
        if n not in took and p.poll() is not None:
            took[n] = time.time() - t0
    time.sleep(0.2)
passed = failed = bad = 0
for p, log in procs:
    rc = p.returncode
    log.seek(0)
    out = log.read()
    m = re.search(r"render-test: (\d+) passed(?:, (\d+) failed)?", out)
    passed += int(m.group(1)) if m else 0
    failed += int(m.group(2) or 0) if m else 0
    if rc != 0 or "command not found" in out:   # 다른 셸에만 있는 것을 부르면 검사가 조용히 빠진다
        bad += 1
        sys.stdout.write(out)
    sys.stdout.flush()
shutil.rmtree(tmp, ignore_errors=True)   # 실패한 셸의 로그는 위에서 이미 다 냈다
print("\nrender-test: %d passed%s  (%d shards, %s)" % (passed, ", %d failed" % failed if failed else "", jobs,
                                                        " ".join("%.0fs" % took[n] for n in sorted(took))))
sys.exit(1 if bad else 0)
'
[ -n "${RENDER_TEST_SHARD:-}" ] || [ "${RENDER_TEST_JOBS:-}" = 1 ] || exec python3 -c "$shard_py" "$0"
[ -n "${RENDER_TEST_WATCHED:-}" ] || exec python3 -c "$watch_py" bash "$0" "$@"
# 훅이 넘긴 GIT_DIR·GIT_INDEX_FILE 같은 리포 지역 변수를 비운다. 남아 있으면 임시 리포를 만드는
# git init 이 임시 디렉터리 대신 그 변수가 가리키는 리포를 다시 초기화한다.
unset $(git rev-parse --local-env-vars 2>/dev/null)
cd "$(dirname "$0")/.."
root=$(pwd)
pass=0
fail=0

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# 설치 등록부를 사용자 홈에 남기지 않는다.
export HARNESS_HOME="$work/home"
# 바깥 실행의 지표 문맥을 물려받지 않는다 — 이 테스트가 검증 스크립트(harness-verify.sh) 아래에서 돌면
# 트레이스와 부모 스팬이 환경으로 넘어와, 케이스가 만드는 실행이 자기 트레이스를 갖지 못한다.
unset HARNESS_TRACE_ID HARNESS_PARENT_SPAN HARNESS_METRIC_SELF HARNESS_METRICS HARNESS_WORKFLOW

ok()   { pass=$((pass + 1)); }
bad()  { fail=$((fail + 1)); echo "  FAIL: $1" >&2; }
check(){ if [ "$2" = "$3" ]; then ok; else bad "$1 — expected '$3', actual '$2'"; fi; }
has()  { if grep -qF -- "$2" "$1"; then ok; else bad "$3"; fi; }
# 제자리 편집. BSD sed 는 `-i ''`, GNU sed 는 `-i` 만 받으므로 두 쪽이 같이 받는 `-i.bak` 을 쓰고 지운다.
sedi() { sed -i.bak "$1" "$2" && rm -f "$2.bak"; }
hasnt(){ if grep -qF -- "$2" "$1"; then bad "$3"; else ok; fi; }


records_under_work() { # records_under_work <리포> — 두 기록 경로가 $work 아래를 가리키는지 본다
  local md ul
  md=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["metrics"]["dir"])' "$1/script/harness.plan.json")
  case "$md" in "$work"/*) ok ;; *) bad "$1: the plan's metrics dir is outside \$work: $md" ;; esac
  ul=$(sed -n 's/^USAGE_LOG_PATH=//p' "$1/script/harness.env" | tr -d "\"'")
  case "$ul" in "$work"/*) ok ;; *) bad "$1: the usage log path is outside \$work: $ul" ;; esac
}

isolate_records() { # isolate_records <리포> — install 한 리포의 기록 경로를 테스트 작업 디렉터리로 옮긴다
  "$root/bin/harness" set --target "$1" metrics.dir "$1.records/metrics" usage.log_path "$1.records/usage.log" >/dev/null \
    || bad "$1: could not move the record paths"
  records_under_work "$1"
}

setup() {          # setup <대상> — 기본 설정으로 렌더한 대상 하나를 만든다
  rm -rf "$1"; mkdir -p "$1"
  cp "$root/templates/harness.toml" "$1/harness.toml"
  # 아래 케이스가 바꿔 보는 값을 **전부** 알려진 상태로 고정한다.
  #
  # 고정하지 않으면 기본값이 그 값과 같아지는 순간 치환이 아무것도 바꾸지 않고, 테스트는
  # 통과하면서 아무것도 검사하지 않는 상태가 된다 — 실패보다 나쁘다. 배포되는 기본값 자체는
  # UT-00 이 따로 본다.
  # 기록 경로(지표·사용 기록)는 대상 옆의 테스트 작업 디렉터리로 둔다 — 기본값은 실제 홈 아래다.
  python3 - "$1/harness.toml" "$1.records" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding="utf-8"); rec = sys.argv[2]
for pat, repl in [
    (r'^base = .*$',            'base = "development"'),
    (r'^protected = \[.*\]$',  'protected = ["main", "development"]'),
    (r'^issue_ref = .*$',       'issue_ref = "suffix"'),
    (r'^ticket_key = .*$',      'ticket_key = ""'),
    (r'^tracker = .*$',         'tracker = "gitlab"'),
    (r'^review_host = .*$',     'review_host = "gitlab"'),
    (r'^style = .*$',           'style = "nygard"'),
    (r'^tool = .*$',            'tool = "adr-tools"'),
    (r'^deletion_forbidden = .*$', 'deletion_forbidden = true'),
]:
    s = re.sub(pat, repl, s, count=1, flags=re.M)
# 같은 키 이름이 여러 절에 있으므로 절 안에서만 바꾼다.
def in_section(s, section, pat, repl):
    m = re.search(r'^\[' + re.escape(section) + r'\]\s*$', s, flags=re.M)
    if not m:
        sys.exit("setup: no [%s] section" % section)
    nxt = re.search(r'^\[', s[m.end():], flags=re.M)
    end = m.end() + (nxt.start() if nxt else len(s) - m.end())
    body, n = re.subn(pat, lambda _: repl, s[m.end():end], count=1, flags=re.M)
    if n != 1:
        sys.exit("setup: no match for %s in [%s]" % (pat, section))
    return s[:m.end()] + body + s[end:]
s = in_section(s, "adr", r'^dir = .*$', 'dir = "docs/adr"')
s = in_section(s, "metrics", r'^dir = .*$', 'dir = "%s/metrics"' % rec)
s = in_section(s, "usage", r'^log_path = .*$', 'log_path = "%s/usage.log"' % rec)
s = in_section(s, "permissions", r'^allow_push = .*$', 'allow_push = false')
s = in_section(s, "doctor", r'^remote_timeout = .*$', 'remote_timeout = 30')
p.write_text(s, encoding="utf-8")
PY
  "$root/bin/harness" render --target "$1" >/dev/null
}

dup_ut_ids() {     # dup_ut_ids <파일> — 표지(echo "UT-<번호>")가 두 번 이상 나오는 번호를 한 줄에 하나씩 찍는다
  grep -oE '^[[:space:]]*echo "UT-[0-9]+[a-z]*' "$1" | sed -E 's/^[[:space:]]*echo "//' | sort | uniq -d
}

echo "UT-64 every case marker in this file is unique, and a repeated one is named"
# 병렬 브랜치가 같은 다음 번호를 고르면 두 블록이 다른 줄에 들어가 텍스트 충돌 없이 번호만 겹친다.
t="$work/ut-ids"; rm -rf "$t"; mkdir -p "$t"
printf '%s\n' 'echo "UT-01 one"' 'echo "UT-01b one, again"' 'echo "UT-02 two"' '  echo "UT-02 two, indented"' \
  'echo "UT-03 three"' '# echo "UT-03 in a comment"' > "$t/dup.sh"
check "a repeated marker is named, a suffixed or commented one is not" "$(dup_ut_ids "$t/dup.sh" | tr '\n' ' ')" "UT-02 "
printf '%s\n' 'echo "UT-01 one"' 'echo "UT-01b one, again"' > "$t/uniq.sh"
check "distinct markers name nothing" "$(dup_ut_ids "$t/uniq.sh")" ""
dups=$(dup_ut_ids "$root/test/render-test.sh")
[ -z "$dups" ] && ok || bad "case markers repeat in src/test/render-test.sh: $(echo $dups)"

echo "UT-00 the shipped default config renders as-is"
# 기본값이 깨져 있으면 설치한 사람이 첫 명령에서 막힌다.
t="$work/shipped"; rm -rf "$t"; mkdir -p "$t"
cp "$root/templates/harness.toml" "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
check "default config render" "$?" "0"

echo "UT-01 renders with the default config and check passes"
t="$work/base"; setup "$t"
"$root/bin/harness" check --target "$t" >/dev/null; check "check exit code" "$?" "0"
sh -n "$t/script/githooks/commit-msg"; check "commit-msg syntax" "$?" "0"
sh -n "$t/script/githooks/pre-push";   check "pre-push syntax" "$?" "0"
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$t/.claude/settings.json"
check "settings.json parses" "$?" "0"
python3 -c "
import sys, tomllib, pathlib
for p in pathlib.Path(sys.argv[1]).glob('.codex/agents/*.toml'):
    tomllib.load(p.open('rb'))
" "$t"
check "codex toml parses" "$?" "0"

echo "UT-57 the test setup keeps its records under the test work directory"
# 기본 설정의 기록 경로는 실제 홈 아래다. 테스트가 만든 대상이 거기 쌓으면 안 된다.
t="$work/recpath"; setup "$t"
python3 - "$t/harness.toml" > "$work/recpath.out" <<'PY'
import sys, tomllib
c = tomllib.load(open(sys.argv[1], "rb"))
print(c["adr"]["dir"]); print(c["metrics"]["dir"]); print(c["usage"]["log_path"])
PY
check "the adr dir in the adr section" "$(sed -n 1p "$work/recpath.out")" "docs/adr"
[ "$(sed -n 2p "$work/recpath.out")" != "docs/adr" ] && ok || bad "the adr dir value landed in the metrics dir"
records_under_work "$t"

echo "UT-02 changing the commit subject format changes the pattern and the guidance together"
# 값 하나를 바꿨는데 한쪽만 따라오면 훅이 거부하며 보여 주는 예시가 통과하지 못하는 형식이 된다.
t="$work/prefix"; setup "$t"
python3 - "$t/harness.toml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('issue_ref = "suffix"', 'issue_ref = "prefix"')
s = s.replace('ticket_key = ""', 'ticket_key = "BD"')
open(p, 'w', encoding='utf-8').write(s)
PY
"$root/bin/harness" render --target "$t" >/dev/null
hook="$t/script/githooks/commit-msg"
has   "$hook" '^\[BD-[0-9]+\]'      "the pattern did not switch to the prefix form"
has   "$hook" '[BD-123] feat: short summary' "the guidance example did not switch to the prefix form"
hasnt "$hook" '(#{issue})'          "suffix-form wording is still in the guidance"

# 같은 값을 읽는 다른 소비자도 따라와야 한다
has "$t/script/harness.env" 'BD-' "the harness.env pattern did not follow"

echo "UT-03 changing protected branches changes the hook and the permission list together"
t="$work/branch"; setup "$t"
python3 - "$t/harness.toml" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('base = "development"', 'base = "develop"')
s = s.replace('protected = ["main", "development"]', 'protected = ["trunk", "develop"]')
open(p, 'w', encoding='utf-8').write(s)
PY
"$root/bin/harness" render --target "$t" >/dev/null
has   "$t/script/githooks/pre-push" 'refs/heads/trunk|refs/heads/develop' "pre-push did not follow"
hasnt "$t/script/githooks/pre-push" 'refs/heads/main'                     "an old branch is still in pre-push"
has   "$t/.claude/settings.json"    'git push origin develop'             "the deny list did not follow"
hasnt "$t/.claude/settings.json"    'git push origin development)'        "an old branch is still in the deny list"
has   "$t/script/githooks/pre-push" 'onto develop instead'                 "the refusal message did not follow"

echo "UT-04 check catches a generated file edited by hand"
t="$work/edited"; setup "$t"
echo "# 사람이 끼워 넣은 줄" >> "$t/script/githooks/commit-msg"
out=$("$root/bin/harness" check --target "$t" 2>&1); rc=$?
check "check exit code" "$rc" "1"
case "$out" in *commit-msg*) ok ;; *) bad "did not name the file that drifted" ;; esac

echo "UT-05 check catches a missing generated file"
rm "$t/.claude/settings.json"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check exit code" "$?" "1"

echo "UT-59 check and doctor see the same drift"
t="$work/drift"; setup "$t"
"$root/bin/harness" doctor --target "$t" >"$work/drift-ok.log" 2>&1
has "$work/drift-ok.log" "files match the config" "doctor right after render does not report a match"
echo "# hand edit" >> "$t/AGENTS.md"
rm "$t/.claude/settings.json"
"$root/bin/harness" check --target "$t" >"$work/drift-check.log" 2>&1; check "check exit code on drift" "$?" "1"
grep -E '^  AGENTS.md +differs from the config$' "$work/drift-check.log" >/dev/null && ok || bad "check did not name the edited file with its reason"
grep -E '^  .claude/settings.json +missing$' "$work/drift-check.log" >/dev/null && ok || bad "check did not name the deleted file with its reason"
"$root/bin/harness" doctor --target "$t" >"$work/drift-doc.log" 2>&1
has "$work/drift-doc.log" "2 files differ from the config" "doctor does not count the same two files"

echo "UT-06 render refuses when the implementer and the reviewer share a runner"
# 같은 모델이 자기 코드를 리뷰하면 같은 맹점을 두 번 지나간다. 문서가 아니라 도구가 막아야 한다.
t="$work/samerunner"; setup "$t"
python3 - "$t/harness.toml" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('[roles.code-reviewer]\nrunner = "codex"', '[roles.code-reviewer]\nrunner = "claude"')
open(p, 'w', encoding='utf-8').write(s)
PY
out=$("$root/bin/harness" render --target "$t" 2>&1); rc=$?
check "render exit code" "$rc" "2"
case "$out" in *distinct_reviewer*) ok ;; *) bad "the refusal does not say how to lift it" ;; esac

echo "UT-07 a config that breaks the rules is refused before render"
# 티켓 접두사형인데 키가 없으면 검사식을 만들 수 없다.
t="$work/invalid"; setup "$t"
sedi 's/issue_ref = "suffix"/issue_ref = "prefix"/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "prefix form without a ticket key" "$?" "2"
sedi 's/^runner = "codex"$/runner = "unknown-runner"/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "unknown runner" "$?" "2"

echo "UT-07d a branch list written as one comma-joined string is refused"
# 브랜치 이름은 훅의 case 패턴에 그대로 들어가므로, 쉼표·공백이 섞이면 훅이 문법 오류로 깨진다.
t="$work/branchname"; setup "$t"
sedi 's/^protected = \["main", "development"\]$/protected = ["main, development"]/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "comma-joined branch list" "$?" "2"

echo "UT-07b the integration branch is protected even when it is not listed"
# 거기로 직접 push 할 수 있으면 승인 게이트가 우회된다. 선택지가 아니므로 채운다.
t="$work/autoprotect"; setup "$t"
sedi 's/^protected = \["main", "development"\]$/protected = ["main"]/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
check "render exit code" "$?" "0"
has "$t/script/githooks/pre-push" "refs/heads/development" "the integration branch did not reach the hook"
has "$t/.claude/settings.json"    "git push origin development" "the integration branch is not in the permission list"

echo "UT-07c the harness source tree runs on itself and never vendors a copy of itself"
# 소스 리포 루트의 harness.toml 은 그 리포 자신의 설정이다 — 기본값은 templates/harness.toml 에 있다.
# 사본을 고정하면 템플릿을 고칠 때마다 두 곳이 어긋나므로 소스 리포는 자기 src/bin/harness 로 돈다.
# 이 리포 자신을 건드리지 않게 소스 트리를 임시 디렉터리에 복제해서 본다.
src="$work/source"; rm -rf "$src"; mkdir -p "$src/src/bin"
cp "$root/bin/harness" "$root/bin/harness_metrics.py" "$src/src/bin/"; cp -R "$root/templates" "$src/src/templates"
( cd "$src" && git init -q . )
"$src/src/bin/harness" install --target "$src" >/dev/null 2>&1; check "install on the source tree" "$?" "0"
[ -e "$src/.harness/bin" ] && bad "the source tree vendored a copy of itself" || ok
[ -f "$src/.ai/AI_AGENT.md" ] && ok || bad "the source tree did not render"
has "$src/harness.toml" 'name = "source"' "the seeded config is not the source tree's own"
[ -f "$HARNESS_HOME/source/project.json" ] && ok || bad "the source tree was not registered"
"$src/src/bin/harness" check --target "$src" >/dev/null 2>&1; check "check on the source tree" "$?" "0"
"$src/src/bin/harness" metrics --target "$src" >"$work/source-metrics.out" 2>&1; check "metrics on the source tree" "$?" "0"
[ -e "$src/src/bin/__pycache__" ] && bad "the metrics module left bytecode in src/bin" || ok
# 다른 CLI(여기서는 $root 의 것)로 불러도 소스 리포 자신의 템플릿으로 돈다 — 템플릿을 바꿔 두면 드러난다.
printf '\n<!-- source tree only -->\n' >> "$src/src/templates/generated/AGENTS.md"
"$src/src/bin/harness" render --target "$src" >/dev/null
"$root/bin/harness" check --target "$src" >/dev/null 2>&1
check "a foreign CLI delegates to the source tree's own src/bin/harness" "$?" "0"


echo "UT-08 an update does not overwrite owned files"
# 프로젝트가 쓴 사실을 하네스 갱신이 지우면 사람이 같은 것을 다시 쓴다.
t="$work/owned"; setup "$t"
printf '\n- 이 프로젝트가 직접 쓴 줄\n' >> "$t/.ai/project/scope.md"
"$root/bin/harness" render --target "$t" >/dev/null
has "$t/.ai/project/scope.md" "이 프로젝트가 직접 쓴 줄" "the owned file was overwritten"

echo "UT-09 editing an owned file updates the rule canon, and check blocks until it does"
# 규칙 정본이 소유 파일 본문을 담아 생성되므로, render 를 잊으면 둘이 어긋난다.
printf -- '- 아직 render 하지 않은 줄\n' >> "$t/.ai/project/scope.md"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check before render" "$?" "1"
"$root/bin/harness" render --target "$t" >/dev/null
has "$t/.ai/AI_AGENT.md" "아직 render 하지 않은 줄" "the rule canon does not carry the owned file"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after render" "$?" "0"

echo "UT-09b an owned file may carry template syntax — it is prose, not a harness variable"
# 템플릿 엔진을 쓰는 프로젝트(그리고 이 하네스 자신)는 사실 문서에 {{VAR}} 같은 표기를 적는다.
# 그것을 하네스 변수로 읽으면 사실 문서 한 줄이 render 를 막는다.
printf -- '- 뷰는 {{VAR}} 표기로 값을 받는다\n' >> "$t/.ai/project/scope.md"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "render with template syntax in an owned file" "$?" "0"
has "$t/.ai/AI_AGENT.md" "{{VAR}} 표기" "the owned file's template syntax did not survive as prose"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after that render" "$?" "0"
# 소유 파일 머리의 안내 주석은 규칙 정본에 들어가지 않는다 — 에이전트가 읽는 근거의 소음이다.
hasnt "$t/.ai/AI_AGENT.md" "이 파일은 프로젝트가 소유한다" "the owned file's guidance comment leaked into the canon"

echo "UT-10 an update overwrites managed files"
# 하네스 것이므로 로컬 수정이 남으면 다음 버전의 개선이 오지 않는다.
t="$work/managed"; setup "$t"
printf '\n사람이 끼워 넣은 줄\n' >> "$t/.ai/templates/developer.md"
"$root/bin/harness" render --target "$t" >/dev/null
hasnt "$t/.ai/templates/developer.md" "사람이 끼워 넣은 줄" "the managed file was not overwritten"

echo "UT-11 changing the forge changes the adapter choice and the command glossary together"
t="$work/forge"; setup "$t"
sedi 's/tracker = "gitlab"/tracker = "github"/; s/review_host = "gitlab"/review_host = "github"/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null
has   "$t/script/forge.sh" "script/forge/github.sh" "the adapter choice did not follow"
hasnt "$t/script/forge.sh" "script/forge/gitlab.sh" "the old adapter is still there"
has   "$t/.ai/forge.md"   "gh pr view"              "the command glossary did not follow"
hasnt "$t/.ai/forge.md"   "glab mr view"            "an old command is still in the glossary"
# 두 어댑터 파일은 둘 다 깔려 있다 — 고르는 것은 생성된 진입점이다
has "$t/script/forge/gitlab.sh" "GITLAB_CLI" "the adapter implementation is missing"

echo "UT-12 changing the ADR style switches the doc set and the old one disappears"
# 설정이 더는 만들지 않는 파일이 남으면 어느 쪽이 현재인지 알 수 없다.
t="$work/adr"; setup "$t"
[ -f "$t/docs/adr/README.md" ] && ok || bad "the nygard doc set is missing"
[ -f "$t/.adr-dir" ] && ok || bad "the adr-tools target file is missing"
sedi 's/style = "nygard"/style = "madr"/; s/tool = "adr-tools"/tool = "manual"/; s|dir = "docs/adr"|dir = "docs/decisions"|' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null
[ -f "$t/docs/decisions/README.md" ] && ok || bad "the madr doc set was not created"
[ -e "$t/docs/adr" ] && bad "docs from the old style are still there" || ok
[ -e "$t/.adr-dir" ] && bad "config for an unused tool is still there" || ok
has "$t/.ai/adr.md" "front matter" "the decision-record glossary did not follow the style"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after the switch" "$?" "0"

echo "UT-13 render refuses a style and tool combination that cannot hold"
# adr-tools 는 상태와 대체 표기를 Nygard 절 구조에서 찾는다. MADR 에 쓰면 조용히 아무 일도 안 한다.
t="$work/adrbad"; setup "$t"
sedi 's/^style = .*/style = "madr"/; s/^tool = .*/tool = "adr-tools"/' "$t/harness.toml"
out=$("$root/bin/harness" render --target "$t" 2>&1); rc=$?
check "render exit code" "$rc" "2"
case "$out" in *madr*) ok ;; *) bad "the refusal does not say the combination is the problem" ;; esac

echo "UT-14 the generated file list covers rules, gateways and adapters"
# 하나라도 빠지면 그 파일만 설정과 무관하게 손으로 관리된다.
t="$work/coverage"; setup "$t"
for f in .ai/AI_AGENT.md .ai/forge.md .ai/adr.md CLAUDE.md AGENTS.md \
         .claude/settings.json .claude/agents/developer.md .codex/agents/developer.toml \
         script/harness.env script/forge.sh \
         script/githooks/commit-msg script/githooks/pre-push script/githooks/pre-commit; do
  [ -f "$t/$f" ] && ok || bad "not generated: $f"
done

echo "UT-15 an installed repo verifies right after install"
# 여기까지가 실제 사용 경로다 — 설치하고, 훅을 켜고, 검증을 돌린다.
# 설치된 회귀 테스트가 통과하는지는 바로 아래 블록이 worktree 훅 환경에서 한 번에 본다.
t="$work/installed"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null
isolate_records "$t"
# 프로젝트 명령을 정하기 전이므로 검증 일괄은 실패한다. 그 사실 자체가 신호다.
( cd "$t" && ./script/run-lint-test.sh >"$work/lint.log" 2>&1 )
check "verification bundle right after install" "$?" "1"
has "$work/lint.log" "verify: not set up" "the failure is not about unset project commands"
ls "$t.records/metrics"/spans-*.jsonl >/dev/null 2>&1 && ok || bad "the verification bundle left no spans under the isolated metrics dir"

echo "UT-61 every managed script's regression test passes from a linked worktree's hook and leaves that worktree's repo alone"
# 링크된 워크트리의 훅은 GIT_DIR·GIT_INDEX_FILE 을 절대 경로로 넘긴다. 그 값을 물려받은 채
# 임시 리포를 만들면 임시 디렉터리 대신 그 리포가 다시 초기화된다.
victim="$work/victim"; rm -rf "$victim" "$victim-wt"; mkdir -p "$victim"
( cd "$victim" && git init -q . && git -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init \
    && git worktree add -q -b side "$victim-wt" ) || bad "could not set up the linked worktree"
wt_gitdir=$(git -C "$victim-wt" rev-parse --absolute-git-dir)
branches_before=$(git -C "$victim" branch --format='%(refname:short)' | sort)
# 목록을 적지 않고 설치된 것을 센다 — 적어 두면 새 테스트가 여기서 빠진 채 지나간다. 서로 독립이라 동시에 돈다.
for f in "$t"/script/test-*.sh; do
  s=$(basename "$f" .sh)
  ( cd "$t" && GIT_DIR="$wt_gitdir" GIT_INDEX_FILE="$wt_gitdir/index" "./script/$s.sh" >"$work/$s.hookenv.log" 2>&1
    echo $? > "$work/$s.hookenv.rc" ) &
done
wait
for f in "$t"/script/test-*.sh; do
  s=$(basename "$f" .sh)
  if [ "$(cat "$work/$s.hookenv.rc")" = 0 ]; then
    ok
  else
    bad "$s failed under a linked worktree's hook environment — $work/$s.hookenv.log"
    tail -5 "$work/$s.hookenv.log" >&2
  fi
done
check "core.bare of the worktree's repo after the tests" "$(git -C "$victim" config core.bare)" "false"
check "branches of the worktree's repo after the tests" "$(git -C "$victim" branch --format='%(refname:short)' | sort)" "$branches_before"

echo "UT-58 the installed CLI carries its metrics module and leaves no bytecode"
[ -f "$t/.harness/bin/harness_metrics.py" ] && ok || bad "install did not vendor the metrics module"
python3 "$t/.harness/bin/harness" metrics --target "$t" >"$work/installed-metrics.out" 2>&1
check "metrics in an installed repo" "$?" "0"
has "$work/installed-metrics.out" '"summary"' "the installed metrics command printed no report"
[ -e "$t/.harness/bin/__pycache__" ] && bad "the metrics module left bytecode in .harness/bin" || ok

echo "UT-16 the forge self-test tells contract compliance apart"
# 자체 검사는 실제 forge 를 상대로 도는 도구라 그 자신은 검사되지 않는다.
# 계약을 지키는 페이크를 통과시키고 어기는 페이크를 잡아야 판정을 믿을 수 있다.
t="$work/selftest"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null
cp "$root/test/fake-forge.sh" "$t/script/forge.sh"
fstate="$work/fake-state"; mkdir -p "$fstate"

run_selftest() { # <FAKE_BREAK> <인수...>
  local brk=$1; shift
  rm -f "$fstate/labels" "$fstate/notes.json"
  ( cd "$t" && FAKE_STATE="$fstate" FAKE_BREAK="$brk" \
      ./script/forge-selftest.sh "$@" >"$work/selftest.log" 2>&1 )
  echo $?
}

check "read-only passes when the contract holds" "$(run_selftest '' 1 100)" "0"
has "$work/selftest.log" "skip" "read-only, but it did not report skipping the writes"
check "writes pass when the contract holds" "$(run_selftest '' --write 1 100)" "0"
check "issue creation passes when the contract holds" "$(run_selftest '' --create-issue 1 100)" "0"
hasnt "$work/selftest.log" "skip  " "ran every item, yet something was skipped"
has "$work/selftest.log" "tracker_labels_ensure" "the self-test does not prepare the issue labels"
# 페이크는 받은 라벨을 기록한다 — 자체 검사가 설정의 이슈 라벨 셋을 넘긴다
check "the self-test passes the configured issue labels" "$(LC_ALL=C sort -u "$fstate/ensured_labels" | tr '\n' ' ')" "Requirement Task invalid "
rm -f "$fstate/ensured_labels"
( cd "$t" && FAKE_STATE="$fstate" sh -c '. ./script/forge.sh && tracker_labels_ensure A "" B C' ); check "the fake's tracker_labels_ensure exits 0" "$?" "0"
check "the fake records each non-empty label" "$(tr '\n' ' ' < "$fstate/ensured_labels")" "A B C "

# 계약을 어기는 아홉 가지를 각각 잡아야 한다. 하나라도 통과로 지나가면 "검증됨" 이 거짓이 된다.
for brk in mr_view threads thread_id issue_list open_mrs; do
  check "catches a contract violation: $brk" "$(run_selftest "$brk" 1 100)" "1"
done
for brk in inline_any reply_any reply_new; do
  check "catches a contract violation: $brk" "$(run_selftest "$brk" --write 1 100)" "1"
done
check "catches a contract violation: create_url" "$(run_selftest create_url --create-issue 1 100)" "1"

# 인수를 잘못 주면 돌지 않는다 — 대상 없이 돌면 엉뚱한 리뷰 요청에 흔적이 남는다.
check "does not run without a target" "$(run_selftest '' )" "2"
check "does not run in create mode without an issue" "$(run_selftest '' --create-issue 1)" "2"

echo "UT-17 the rule prose does not state config values as fact"
# 설정에 있는 값을 산문에 박아 두면 그 값을 바꾼 프로젝트에서 규칙이 거짓말을 한다.
t="$work/prose"; setup "$t"
has "$t/.ai/AI_AGENT.md" "이슈 삭제를 **금지**한다" "the deletion ban rule was not rendered"
sedi 's/deletion_forbidden = true/deletion_forbidden = false/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null
hasnt "$t/.ai/AI_AGENT.md" "이슈 삭제를 **금지**한다" "deletion is allowed, yet the ban rule is still there"
has   "$t/.ai/AI_AGENT.md" "지울 수 있다"             "the allowing sentence did not appear"

echo "UT-18 every owned file has a reader"
# 아무도 읽지 않는 문서는 채워 달라고 할 근거가 없다.
t="$work/readers"; setup "$t"
for f in scope glossary stack architecture testing environment review-checks; do
  # 규칙 정본이 본문을 담거나(포함), 계약·문서 지도가 경로로 가리키거나 둘 중 하나여야 한다.
  if grep -rqF ".ai/project/$f.md" "$t/.ai/AI_AGENT.md" "$t/.ai/templates" 2>/dev/null; then
    ok
  elif grep -qF "{{INCLUDE:.ai/project/$f.md}}" "$root/templates/generated/.ai/AI_AGENT.md"; then
    ok
  else
    bad "owned file nobody reads: .ai/project/$f.md"
  fi
done

echo "UT-19 uninstall removes only what the harness installed"
# 프로젝트가 쓴 산문과 작업 산출물을 지우면 되돌릴 수 없다.
t="$work/rm"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null
printf '내가 쓴 담당 범위\n' >> "$t/.ai/project/scope.md"
mkdir -p "$t/docs/spec" && echo "명세" > "$t/docs/spec/12-foo.md"
"$root/bin/harness" uninstall --target "$t" >/dev/null
check "uninstall exit code" "$?" "0"
[ -e "$t/.harness" ]        && bad "the harness copy is still there"  || ok
[ -e "$t/script/review-mr.sh" ] && bad "a managed file is still there"    || ok
[ -e "$t/.ai/AI_AGENT.md" ] && bad "a generated file is still there"   || ok
has "$t/.ai/project/scope.md" "내가 쓴 담당 범위" "prose the project wrote was deleted"
has "$t/docs/spec/12-foo.md"  "명세"              "work output was deleted"
[ -f "$t/harness.toml" ]    && ok || bad "the config was deleted"
[ -f "$t/docs/spec/README.md" ] && ok || bad "an owned file was deleted"
# 훅이 사라진 디렉터리를 가리키면 커밋할 때마다 git 이 실패한다.
check "hooks setting cleared" "$( cd "$t" && git config core.hooksPath || echo '(none)' )" "(none)"

echo "UT-20 --purge names what it removes and stops without a confirmation"
# 되돌릴 수 없는 유일한 명령이다. 목록을 보이지 않거나 묻지 않고 지우면 사람이 쓴 산문이 사라진다.
t="$work/purge"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null
mkdir -p "$t/docs/spec" && echo "명세" > "$t/docs/spec/12-foo.md"
"$root/bin/harness" uninstall --target "$t" --purge >"$work/purge.log" 2>&1
check "unconfirmed --purge exit code" "$?" "2"
[ -f "$t/harness.toml" ] && ok || bad "unconfirmed --purge deleted the config"
[ -f "$t/.ai/project/scope.md" ] && ok || bad "unconfirmed --purge deleted an owned file"
has "$work/purge.log" "harness.toml"              "the preview does not name the config"
has "$work/purge.log" ".ai/project/scope.md"      "the preview does not name the owned files"
has "$work/purge.log" "docs/spec"                 "the preview does not name the untouched work output"
has "$work/purge.log" ".harness/"                 "the preview does not name the vendored copy"

echo "UT-20b --purge with --yes removes owned files and the config but keeps work output"
"$root/bin/harness" uninstall --target "$t" --purge --yes >/dev/null
[ -e "$t/.ai" ]          && bad "owned files are still there"  || ok
[ -e "$t/harness.toml" ] && bad "the config is still there"    || ok
has "$t/docs/spec/12-foo.md" "명세" "--purge deleted work output too"

echo "UT-21 uninstall does not run where nothing was installed"
t="$work/never"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" uninstall --target "$t" >/dev/null 2>&1
check "exit code" "$?" "2"

echo "UT-22 a one-line config change flows into the output, and one that cannot hold is rolled back"
t="$work/set"; setup "$t"
"$root/bin/harness" set --target "$t" branches.base develop >/dev/null
check "set exit code" "$?" "0"
has "$t/script/githooks/pre-push" "refs/heads/develop" "the changed value did not reach the output"
before=$(grep -c 'issue_ref' "$t/harness.toml")
"$root/bin/harness" set --target "$t" commit.issue_ref prefix >/dev/null 2>&1
check "exit code for a value that cannot hold" "$?" "2"
has "$t/harness.toml" 'issue_ref = "suffix"' "a value that cannot hold was not rolled back"
"$root/bin/harness" set --target "$t" nosuch.key x >/dev/null 2>&1
check "exit code for an unknown key" "$?" "2"

echo "UT-23 help and doctor run"
"$root/bin/harness" help >"$work/help.log" 2>&1; check "help exit code" "$?" "0"
for c in install render check doctor set run vars uninstall help; do
  has "$work/help.log" "harness $c" "help does not list $c"
done
t="$work/doc"; setup "$t"
"$root/bin/harness" doctor --target "$t" >"$work/doctor.log" 2>&1
check "doctor exit code right after setup" "$?" "1"
has "$work/doctor.log" "placeholder" "did not report the places left to fill"
has "$work/doctor.log" "git hooks"   "did not report the hook state"

echo "UT-24 running a workflow launches the orchestrator interactively"
# 승인 게이트가 있으므로 비대화형으로 돌리면 그 지점이 통과된 것처럼 지나간다.
t="$work/run"; setup "$t"
# 실행 기기에 오케스트레이터가 없어도 돌도록 가짜를 PATH 앞에 둔다. --dry-run 도 설치 여부는 확인한다.
orch24="$work/orch24"; mkdir -p "$orch24"; printf '#!/bin/sh\nexit 0\n' > "$orch24/claude"; chmod +x "$orch24/claude"
out=$(PATH="$orch24:$PATH" "$root/bin/harness" run --target "$t" work 12 --dry-run 2>&1)
check "run exit code" "$?" "0"
case "$out" in *claude*"/work 12"*) ok ;; *) bad "the command to launch is not what is expected: $out" ;; esac
case "$out" in *-p*|*--print*) bad "launches non-interactively — the approval gate is skipped" ;; *) ok ;; esac
"$root/bin/harness" set --target "$t" harness.model opus >/dev/null 2>&1
out=$(PATH="$orch24:$PATH" "$root/bin/harness" run --target "$t" work 12 --dry-run 2>&1)
case "$out" in *"claude --model opus"*) ok ;; *) bad "the orchestrator model is not passed at launch: $out" ;; esac
"$root/bin/harness" run --target "$t" nosuch 12 --dry-run >/dev/null 2>&1
check "exit code for an unknown workflow" "$?" "2"

echo "UT-25 templates are found even when run through a symlink"
# Homebrew 는 트리를 libexec 에 넣고 bin 에 링크만 건다. 링크를 타고도 옆의 템플릿을
# 찾아야 전역 설치가 성립한다.
keg="$work/keg"; rm -rf "$keg"; mkdir -p "$keg/libexec" "$keg/bin"
cp -R "$root/bin" "$root/templates" "$root/harness.toml" "$keg/libexec/"
ln -s "$keg/libexec/bin/harness" "$keg/bin/harness"
t="$work/keg-target"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$keg/bin/harness" install --target "$t" >/dev/null 2>&1
check "install through the link" "$?" "0"
"$keg/bin/harness" check --target "$t" >/dev/null 2>&1
check "check through the link" "$?" "0"

echo "UT-26 a version pinned in the project wins over the global one"
# 전역을 올릴 때마다 모든 프로젝트의 생성물이 바뀌면 그 리포의 검사가 한꺼번에 깨진다.
echo "0.0.9" > "$t/.harness/VERSION"
# 그 버전의 install 이 기록했을 해시로 맞춘다 — 사본을 손으로 고친 것이 아니라 옛 버전을 고정한 리포다
python3 - "$t" <<'PY'
import hashlib, pathlib, re, sys
t = pathlib.Path(sys.argv[1]); m = t / ".harness/managed"
h = hashlib.sha256((t / ".harness/VERSION").read_bytes()).hexdigest()
m.write_text(re.sub(r"^[0-9a-f]{64}(  \.harness/VERSION)$", h + r"\1", m.read_text(encoding="utf-8"), flags=re.M), encoding="utf-8")
PY
out=$("$keg/bin/harness" check --target "$t" 2>&1)
case "$out" in *0.0.9*) ok ;; *) bad "did not report that it defers to the pinned version" ;; esac
# 넘긴 뒤에도 실제로 돌아야 한다
case "$out" in *"match the config"*) ok ;; *) bad "check did not run after deferring: $out" ;; esac
# install 은 넘기지 않는다 — 고정된 사본을 갈아 끼우는 것이 그 명령의 일이다
"$keg/bin/harness" install --target "$t" >/dev/null 2>&1
check "pinned version after install" "$(cat "$t/.harness/VERSION")" "0.1.0"

echo "UT-27 the decision-record procedure follows the tool setting"
# 도구를 바꿨는데 절차가 그대로면 없는 명령을 지시한다.
t="$work/adrtool"; setup "$t"
sedi 's/^tool = .*/tool = "manual"/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null
has   "$t/.ai/adr.md" "도구를 쓰지 않는다" "manual, yet there is no by-hand procedure"
hasnt "$t/.ai/adr.md" "adr new"            "manual, yet it prescribes a command that does not exist"
[ -e "$t/.adr-dir" ] && bad "no tool in use, yet a tool config file appeared" || ok
"$root/bin/harness" set --target "$t" adr.tool adr-tools >/dev/null
has "$t/.ai/adr.md" 'adr new -s'  "adr-tools, yet there is no supersede command"
[ -f "$t/.adr-dir" ] && ok || bad "adr-tools, yet the tool config file is missing"

echo "UT-28 no Korean leaks into CLI output"
# 규칙은 문서·커밋은 한국어, 로그 메시지는 영어다. 새 메시지를 한국어로 적으면 여기서 걸린다.
# 생성 파일로 들어가는 문자열은 문서 내용이므로 대상이 아니다.
t="$work/lang"; setup "$t"
{ "$root/bin/harness" help
  "$root/bin/harness" version --target "$t"
  "$root/bin/harness" check --target "$t"
  "$root/bin/harness" doctor --target "$t"
  "$root/bin/harness" render --target "$root"
  "$root/bin/harness" set --target "$t" nosuch.key x
  "$root/bin/harness" run --target "$t" nosuch 1
  "$root/bin/harness" uninstall --target "$work/never"
  "$root/bin/harness" uninstall --target "$t" --purge
} > "$work/lang.log" 2>&1
# grep 은 한글 범위를 이식 가능하게 못 찾는다 — BSD 에 -P 가 없어 오류로 빠지면 검사가 통과해 버린다.
python3 - "$work/lang.log" > "$work/lang.hits" <<'HANGUL'
import re, sys
for n, line in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
    if re.search(r"[가-힣]", line):
        print(f"{n}: {line.rstrip()}")
HANGUL
if [ -s "$work/lang.hits" ]; then
  bad "Korean is still in CLI output"
  head -3 "$work/lang.hits" >&2
else
  ok
fi

echo "UT-29 doctor finds broken references"
# 손으로 돌리던 grep 을 명령이 대신한다. 통과만 하는 검사는 없는 것과 같으므로,
# 깨뜨린 상태를 실제로 만들어 잡히는지 본다.
t="$work/refs"; setup "$t"
"$root/bin/harness" doctor --target "$t" > "$work/ref-clean.log" 2>&1 || true
has "$work/ref-clean.log" "every role reference resolves" "a clean install, yet it faults a role reference"
has "$work/ref-clean.log" "every path a document names exists" "a clean install, yet it reports a missing file"

python3 - "$t/harness.toml" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
p.write_text(re.sub(r'\[roles\.docs-writer\][^\[]*', '', p.read_text(encoding="utf-8")), encoding="utf-8")
PY
"$root/bin/harness" render --target "$t" >/dev/null
[ -f "$t/.ai/templates/docs-writer.md" ] && bad "the contract for an unused role is still there" || ok
hasnt "$t/CLAUDE.md" "agents/docs-writer.md" "the asset table still points at the removed role"
{ echo "docs-writer 가 여기서 돈다."; echo '`docs/nope/missing.md` 를 본다.'; } >> "$t/.ai/project/scope.md"
"$root/bin/harness" render --target "$t" >/dev/null
"$root/bin/harness" doctor --target "$t" > "$work/ref-bad.log" 2>&1 || true
has "$work/ref-bad.log" "role \`docs-writer\` is not in harness.toml" "did not find the place that calls the removed role"
has "$work/ref-bad.log" "\`docs/nope/missing.md\` does not exist"   "did not find the reference to a missing file"
hasnt "$work/ref-bad.log" "settings.local.json"                     "faulted a file that is normally absent"

echo "UT-34 the pre-commit hook blocks a credential from being committed"
# 층이 실제로 서 있는지는 훅을 돌려 봐야 안다. 스크립트만 있고 훅이 부르지 않으면 층이 없다.
t="$work/secret"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null
isolate_records "$t"
# 훅은 생성물 일치도 본다. 하네스를 먼저 커밋해 두어야 시크릿 층까지 도달한다.
gitq() { git -C "$t" -c user.name=t -c user.email=t@example.invalid "$@"; }
gitq add -A >/dev/null && gitq commit -q -m "chore: 하네스" >/dev/null
# 표본 값을 이 파일에 문자열로 적지 않는다 — 적으면 이 리포의 스캔이 이 줄에 걸린다.
( cd "$t" && printf 'aws = "%s%s"\n' AKIA IOSFODNN7EXAMPLE > leak.txt )
gitq add leak.txt >/dev/null
( cd "$t" && script/githooks/pre-commit >"$work/hook.log" 2>&1 )
check "pre-commit blocks" "$?" "1"
has "$work/hook.log" "possible credential" "the hook did not run the secret scan"
# 표지를 달면 지나간다 — 오탐에 막히는 사람이 --no-verify 로 가지 않게 하는 탈출구다.
( cd "$t" && printf 'aws = "%s%s"  # harness:allow-secret\n' AKIA IOSFODNN7EXAMPLE > leak.txt )
gitq add leak.txt >/dev/null
( cd "$t" && script/githooks/pre-commit >"$work/hook2.log" 2>&1 )
check "a marked line passes" "$?" "0"

echo "UT-33 Jira can track issues but cannot host review"
# 트래커와 리뷰 호스트를 따로 고를 수 있다는 것이 forge 분리의 요점이다.
t="$work/jira"; setup "$t"
"$root/bin/harness" set --target "$t" commit.ticket_key BD >/dev/null
"$root/bin/harness" set --target "$t" commit.issue_ref prefix >/dev/null
"$root/bin/harness" set --target "$t" forge.tracker jira >/dev/null
check "jira as tracker" "$?" "0"
has "$t/script/forge.sh" "forge/jira.sh"  "the dispatcher does not source the Jira adapter"
has "$t/.ai/forge.md"   "jira issue view" "the command glossary does not carry the Jira commands"
has "$t/.ai/forge.md"   "BD-12"           "the glossary does not use the project ticket key"
"$root/bin/harness" set --target "$t" forge.review_host jira >"$work/jira-rh.log" 2>&1
check "jira as review host is refused" "$?" "2"
has "$work/jira-rh.log" "does not host code review" "the refusal does not say why"
has "$t/harness.toml"   'review_host = "gitlab"'   "the refused value was not rolled back"
# 정규화는 어댑터의 실제 로직이다. 자격증명 없이 도는 유일한 부분이라 여기서 본다.
cat > "$work/jira-raw.json" <<'JSON'
{"total":2,"issues":[
 {"key":"BD-12","fields":{"summary":"feat: 골격",
  "status":{"name":"진행 중","statusCategory":{"key":"indeterminate"}},
  "description":{"type":"doc","content":[{"type":"paragraph","content":[
    {"type":"text","text":"첫 줄"},{"type":"hardBreak"},{"type":"text","text":"둘째 줄"}]}]},
  "labels":["Task"],"assignee":{"displayName":"담당자"},"fixVersions":[{"name":"M1"}]}},
 {"key":"BD-13","fields":{"summary":"fix: 밀림",
  "status":{"name":"완료","statusCategory":{"key":"done"}},
  "description":"평문 본문","labels":[],"assignee":null,"fixVersions":[]}}]}
JSON
( _FORGE_WANT_TRACKER=1; _FORGE_WANT_REVIEW=0
  . "$t/script/forge/jira.sh"
  python3 -c "$_jira_norm_issue" < "$work/jira-raw.json" ) > "$work/jira-norm.json" 2>&1
has "$work/jira-norm.json" '"iid": "BD-12"'   "the issue key did not become the identifier"
has "$work/jira-norm.json" '"state": "opened"' "an in-progress issue was not read as open"
has "$work/jira-norm.json" '"state": "closed"' "a done issue was not read as closed"
has "$work/jira-norm.json" '첫 줄\n둘째 줄'    "the rich-text body was not flattened"
has "$work/jira-norm.json" '"milestone": "M1"' "fixVersions did not become the milestone"

echo "UT-32 dropping a role drops its contract, its adapter and its command together"
# 손으로 적은 표는 역할을 지운 뒤에도 남아 만들어지지 않은 파일을 가리킨다.
t="$work/role"; setup "$t"
[ -f "$t/.claude/commands/security-guard.md" ] && ok || bad "the role's command was not installed"
has "$t/CLAUDE.md" "/security-guard" "the asset table does not list the command"
python3 - "$t/harness.toml" <<'DROP'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
p.write_text(re.sub(r"\n\[roles\.security-guard\][^\[]*", "\n", p.read_text(encoding="utf-8")),
             encoding="utf-8")
DROP
"$root/bin/harness" render --target "$t" >/dev/null
[ -e "$t/.claude/agents/security-guard.md" ]   && bad "the adapter survived the role removal"  || ok
[ -e "$t/.ai/templates/security-guard.md" ]    && bad "the contract survived the role removal" || ok
[ -e "$t/.claude/commands/security-guard.md" ] && bad "the command survived the role removal"  || ok
hasnt "$t/CLAUDE.md" "/security-guard" "the asset table still points at a file that is gone"

echo "UT-31 CI is seeded once and never overwritten"
# CI 는 방어층의 마지막 칸이다. 깔지 않으면 층 표가 거짓이 되고, 덮으면 설치 한 번에 빌드가 바뀐다.
t="$work/ci"; setup "$t"
[ -f "$t/.gitlab-ci.yml" ] && ok || bad "no CI config was seeded for the configured review host"
has "$t/.gitlab-ci.yml" "run-lint-test.sh" "the CI config does not run the verification bundle"
has "$t/.gitlab-ci.yml" "development"      "the CI config does not follow the integration branch"
printf 'MY OWN PIPELINE\n' > "$t/.gitlab-ci.yml"
"$root/bin/harness" render --target "$t" >/dev/null
has "$t/.gitlab-ci.yml" "MY OWN PIPELINE" "render overwrote a pipeline the project owns"
"$root/bin/harness" uninstall --target "$t" --purge --yes >/dev/null
[ -f "$t/.gitlab-ci.yml" ] && ok || bad "--purge deleted the CI config"
# 리뷰 호스트가 GitHub 이면 GitHub Actions 쪽이 깔린다.
t="$work/ci-gh"; rm -rf "$t"; mkdir -p "$t"; cp "$root/templates/harness.toml" "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null
[ -f "$t/.github/workflows/harness-verify.yml" ] && ok || bad "no GitHub workflow was seeded"
has "$t/.github/workflows/harness-verify.yml" "run-lint-test.sh" "the workflow does not run the verification bundle"

echo "UT-30 a harness installed below the repo root keeps to its own subtree"
# 모노레포: 서브프로젝트마다 하네스가 따로 선다. 스크립트가 git 루트로 올라가면 남의 것을 본다.
t="$work/mono"; rm -rf "$t"; mkdir -p "$t/packages/api" "$t/packages/web"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t/packages/api" >/dev/null
[ -f "$t/packages/api/script/harness.env" ] && ok || bad "the harness did not land in the subdirectory"
[ -e "$t/script" ]              && bad "the harness leaked into the repo root"  || ok
[ -e "$t/packages/web/script" ] && bad "the harness leaked into a sibling"      || ok
# 리포 루트에서 불러도 자기 루트를 잡는다 — git 루트로 올라가면 설정을 찾지 못하고 죽는다.
( cd "$t" && packages/api/script/test-carryover-issue.sh >"$work/mono.log" 2>&1 )
check "managed test called from the repo root" "$?" "0"
( cd "$t/packages/api" && ./script/test-sync-task-issues.sh >"$work/mono2.log" 2>&1 )
check "managed test called from the subproject" "$?" "0"
# 훅도 자기 서브프로젝트를 봐야 한다.
has "$t/packages/api/script/githooks/pre-commit" 'dirname -- "$0"' "the hook still resolves through git"

echo "UT-35 workflow steps are the config: reorder, insert, and dangling references are refused"
t="$work/steps"; setup "$t"
# 기본 단계가 조각을 그대로 잇는다 — 번호 참조가 전부 풀려 있어야 한다
hasnt "$t/.ai/workflows/work.md" "{{step:" "a step reference was left unresolved"
has "$t/.ai/workflows/work.md" "#### 4-1. 마무리" "the default numbering changed"
steps_work=$("$root/bin/harness" steps --target "$t" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["work"]))')
# 구현 뒤에 보안 검토를 끼운다 → 뒤 단계 번호와 그 번호를 가리키는 참조가 함께 밀린다
ins=$(printf '%s' "$steps_work" | python3 -c 'import json,sys; s=json.load(sys.stdin); s.insert(2,{"id":"security","type":"agent","title":"보안 검토","role":"security-guard"}); print(json.dumps(s))')
"$root/bin/harness" steps --target "$t" work "$ins" >/dev/null; check "insert a step" "$?" "0"
has "$t/.ai/workflows/work.md" "### 3. 보안 검토 — \`security-guard\` 역할에 위임" "the inserted step is not third"
has "$t/.ai/workflows/work.md" "#### 5-1. 마무리" "the sub-step did not follow its step"
has "$t/.ai/workflows/work.md" "거기서 코드가 바뀌지 않으면 6-1 이 받는다" "a reference did not follow the renumbering"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after steps" "$?" "0"
# 다른 단계가 가리키는 단계를 빼면 거부하고 설정을 되돌린다
cp "$t/harness.toml" "$work/steps.before"
del=$(printf '%s' "$ins" | python3 -c 'import json,sys; print(json.dumps([x for x in json.load(sys.stdin) if x["id"]!="limits"]))')
"$root/bin/harness" steps --target "$t" work "$del" --dry-run >/dev/null 2>&1; check "dry-run refuses a referenced step" "$?" "2"
"$root/bin/harness" steps --target "$t" work "$ins" --dry-run >/dev/null 2>&1; check "dry-run accepts valid steps" "$?" "0"
cmp -s "$t/harness.toml" "$work/steps.before"; check "dry-run leaves the config alone" "$?" "0"
"$root/bin/harness" steps --target "$t" work "$del" >/dev/null 2>&1; check "removing a referenced step" "$?" "2"
cmp -s "$t/harness.toml" "$work/steps.before"; check "config reverted" "$?" "0"
# CLI 러너 역할은 서브에이전트로 부를 수 없다
bad_role='[{"id":"x","type":"agent","title":"리뷰","role":"code-reviewer"}]'
"$root/bin/harness" steps --target "$t" retro "$bad_role" >/dev/null 2>&1; check "agent step on a script-run role" "$?" "2"
"$root/bin/harness" steps --target "$t" retro '[{"id":"x","type":"bogus","title":"t"}]' >/dev/null 2>&1; check "unknown step kind" "$?" "2"
# 설정에 절차가 없으면 기본값 — 단계 정의 전에 설치한 프로젝트도 그대로 렌더된다
t="$work/steps-legacy"; setup "$t"
python3 - "$t/harness.toml" <<'PY2'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding="utf-8")
p.write_text(re.sub(r"\n\[workflows\.[\s\S]*$", "\n", s), encoding="utf-8")
PY2
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "render without workflows" "$?" "0"
u="$work/steps-shipped"; rm -rf "$u"; mkdir -p "$u"; cp "$root/templates/harness.toml" "$u/harness.toml"
"$root/bin/harness" render --target "$u" >/dev/null 2>&1
cmp -s "$t/.ai/workflows/work.md" "$u/.ai/workflows/work.md"; check "falls back to the default steps" "$?" "0"

echo "UT-37 set replaces a multi-line array whole"
# 첫 줄만 바꾸면 나머지 줄이 떠서 설정이 통째로 읽히지 않는다.
t="$work/set-multiline"; setup "$t"
"$root/bin/harness" set --target "$t" docs.protected ".ai/project/scope.md,docs/a.md," >/dev/null 2>&1
check "set on a multi-line array" "$?" "0"
python3 -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1],"rb"))["docs"]["protected"])' "$t/harness.toml" > "$work/ml.out" 2>&1
has "$work/ml.out" "['.ai/project/scope.md', 'docs/a.md']" "the array was not replaced whole"
has "$t/harness.toml" 'usage]' "the section after the array was damaged"

echo "UT-38 base documents stay protected, directories cover their contents, bad paths are refused"
t="$work/protected"; setup "$t"
"$root/bin/harness" set --target "$t" docs.protected "docs/spec/," >/dev/null 2>&1
check "set a directory" "$?" "0"
has "$t/.claude/settings.json" '"Edit(.ai/project/scope.md)"' "a base document lost its protection when dropped from the list"
has "$t/.claude/settings.json" '"Edit(docs/spec/**)"' "a directory rule does not cover the files under it"
hasnt "$t/.claude/settings.json" '"Edit(docs/spec/)"' "a directory rule was left in a form that matches nothing"
hasnt "$t/.claude/settings.json" '"Write(' "a Write rule is left, which file permission checks never match"
hasnt "$t/.claude/settings.json" '"NotebookEdit(' "a NotebookEdit rule is left, which file permission checks never match"
for p in "/etc/passwd" "../x.md" "docs/../x.md" "docs/a b.md"; do
  "$root/bin/harness" set --target "$t" docs.protected "$p," >/dev/null 2>&1
  check "refuse protected path '$p'" "$?" "2"
done
t="$work/adrdir"; setup "$t"
"$root/bin/harness" set --target "$t" adr.dir "../outside" >/dev/null 2>&1; check "refuse adr.dir outside the repo" "$?" "2"

echo "UT-39 tools lists what is on PATH and records it per machine"
fakebin="$work/fakebin"; mkdir -p "$fakebin"
printf '#!/bin/sh\necho "hermes 9.9"\n' > "$fakebin/hermes"; printf '#!/bin/sh\necho "codex 1.2"\n' > "$fakebin/codex"; chmod +x "$fakebin"/*
# PATH 를 좁히면 env 가 다른 python3 를 집는다 — 인터프리터를 직접 준다
py=$(command -v python3)
PATH="$fakebin:/usr/bin:/bin" "$py" "$root/bin/harness" tools --sync > "$work/tools.out" 2>&1
check "tools --sync" "$?" "0"
has "$work/tools.out" '"id": "codex"' "an installed agent CLI was not listed"
has "$work/tools.out" '"version": "hermes 9.9"' "the version line was not read"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); a={x["id"]:x["supported"] for x in d["agents"]}; print(a)' "$HARNESS_HOME/tools.json" > "$work/tools.sup"
has "$work/tools.sup" "'hermes': False" "an agent the harness cannot drive was marked supported"
hasnt "$work/tools.sup" "'claude'" "a CLI that is not on PATH was listed"

echo "UT-40 the commit form in procedures follows the config"
t="$work/commitform"; setup "$t"
has "$t/.ai/workflows/prework.md" '`docs: <요약>(#<이슈번호>)`' "the default commit form changed"
"$root/bin/harness" set --target "$t" commit.ticket_key DEV >/dev/null 2>&1
"$root/bin/harness" set --target "$t" commit.issue_ref prefix >/dev/null 2>&1
has "$t/.ai/workflows/prework.md" '`[DEV-<이슈번호>] docs: <요약>`' "the procedure kept a commit form the config no longer uses"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after the form changed" "$?" "0"

echo "UT-41 runners follow the vendor registry, and schema resolves who runs each role"
t="$work/runners"; setup "$t"
"$root/bin/harness" set --target "$t" roles.planner.runner gemini > "$work/runner.out" 2>&1
check "a vendor the registry only detects" "$?" "2"
"$root/bin/harness" set --target "$t" roles.planner.runner codex >/dev/null 2>&1
check "any role may take a CLI runner" "$?" "0"
"$root/bin/harness" set --target "$t" invariants.distinct_reviewer false >/dev/null 2>&1   # 구현·리뷰 분리 규칙과 떼어 본다
"$root/bin/harness" set --target "$t" roles.code-reviewer.runner claude >/dev/null 2>&1
check "a CLI runner for the script-run role" "$?" "0"
"$root/bin/harness" schema --target "$t" > "$work/schema.out" 2>&1
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["roles"]["planner"]["vendor"], d["roles"]["planner"]["runners"], d["script_roles"])' "$work/schema.out" > "$work/schema.sum"
has "$work/schema.sum" "codex ['inproc', 'claude', 'codex'] {'code-reviewer': 'script/review-mr.sh'}" "schema does not resolve who runs each role"

echo "UT-51 the run plan is generated from the config and the vendor registry"
t="$work/plan"; setup "$t"
"$root/bin/harness" set --target "$t" roles.planner.runner codex roles.planner.model gpt-x >/dev/null 2>&1
python3 -c 'import json,sys; r=json.load(open(sys.argv[1]))["roles"]; print(r["planner"]["argv"], r["planner"]["entry"], r["developer"]["via"])' "$t/script/harness.plan.json" > "$work/plan.sum"
has "$work/plan.sum" "['codex', 'exec', '--sandbox', 'workspace-write', '--ephemeral', '-m', 'gpt-x'] script/run-agent.py planner subagent" "the plan does not carry the vendor's argv"
has "$t/.ai/workflows/prework.md" "script/run-agent.py planner <이슈번호>" "an agent step with a CLI runner does not call the runner"
has "$t/.ai/workflows/prework.md" "작업 분해자 역할을 Codex CLI 로 실행" "the step heading does not say who runs it"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check covers the plan" "$?" "0"
printf '{}\n' > "$t/script/harness.plan.json"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check catches an edited plan" "$?" "1"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
( cd "$t" && python3 script/run-agent.py developer 1 ) > "$work/ra.out" 2>&1; check "the runner refuses a subagent role" "$?" "2"
has "$work/ra.out" "runs as a subagent" "the runner does not say why"
"$root/bin/harness" steps --target "$t" work '[{"id":"r","type":"agent","title":"리뷰","role":"code-reviewer"}]' --dry-run > "$work/entry.out" 2>&1
check "an agent step for a role with its own script" "$?" "2"
has "$work/entry.out" "script/review-mr.sh" "the refusal does not name the role's script"

echo "UT-60 a missing or incomplete adapter body stops render with its message"
frontmatter_case() { # <이름> <기대 메시지> <템플릿을 바꾸는 파이썬 한 줄>
  local h="$work/fm-$1" t="$work/fm-$1-target"
  rm -rf "$h"; mkdir -p "$h"; cp -R "$root/bin" "$root/templates" "$h/"
  python3 -c "import pathlib, re; p = pathlib.Path('$h/templates/agents/planner.md'); s = p.read_text(encoding='utf-8'); $3" \
    || { bad "$1: could not prepare the template"; return; }
  setup "$t"
  "$h/bin/harness" render --target "$t" >"$work/fm-$1.out" 2>&1
  [ "$?" -ne 0 ] && ok || bad "$1: render did not stop"
  has "$work/fm-$1.out" "$2" "$1: render did not say '$2'"
}
frontmatter_case nobody "no adapter body for role \`planner\`" "p.unlink()"
for c in schema metrics; do
  "$work/fm-nobody/bin/harness" "$c" --target "$work/fm-nobody-target" >"$work/fm-nobody-$c.out" 2>&1
  check "$c stops on a role without an adapter body" "$?" "2"
  has "$work/fm-nobody-$c.out" "no adapter body for role \`planner\`" "$c did not say which role has no adapter body"
done
frontmatter_case nosummary "frontmatter has no \`summary\`" "p.write_text(re.sub(r'(?m)^summary:.*\\n', '', s, count=1), encoding='utf-8')"
frontmatter_case nodescription "frontmatter has no \`description\`" "p.write_text(re.sub(r'(?m)^description:.*\\n', '', s, count=1), encoding='utf-8')"

echo "UT-52 a role may forbid CLI runners, and orchestrator gaps show in doctor"
h="$work/harness-copy"; rm -rf "$h"; mkdir -p "$h"; cp -R "$root/bin" "$root/templates" "$h/"
python3 - "$h/templates/agents/planner.md" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding="utf-8")
p.write_text(s.replace("\n---\n", "\nheadless: false\n---\n", 1), encoding="utf-8")
PY
t="$work/nohead"; setup "$t"
"$h/bin/harness" set --target "$t" roles.planner.runner codex > "$work/nohead.out" 2>&1
check "a CLI runner for a headless: false role" "$?" "2"
has "$work/nohead.out" "headless: false" "the refusal does not say why"
"$h/bin/harness" schema --target "$t" | python3 -c 'import json,sys; print(json.load(sys.stdin)["roles"]["planner"]["runners"])' > "$work/nohead.sum"
has "$work/nohead.sum" "['inproc']" "schema offers a runner the role forbids"
t="$work/codexorch"; setup "$t"
"$root/bin/harness" set --target "$t" harness.orchestrator codex roles.code-reviewer.runner claude >/dev/null 2>&1
"$root/bin/harness" doctor --target "$t" > "$work/doc2.out" 2>&1
has "$work/doc2.out" "no command guard for Codex CLI" "doctor does not warn that the guard hook is not wired"

echo "UT-42 a role's project instructions reach both agent definitions and stay protected"
t="$work/rolenotes"; setup "$t"
mkdir -p "$t/.ai/project/roles"
printf '<!-- 사람에게 하는 안내 -->\n\n- 분해는 한 task 당 파일 다섯 개 이하로 한다\n' > "$t/.ai/project/roles/planner.md"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check notices an unrendered role note" "$?" "1"
"$root/bin/harness" render --target "$t" >/dev/null
has "$t/.claude/agents/planner.md" "## 이 프로젝트에서" "the Claude agent did not get the project section"
has "$t/.codex/agents/planner.toml" "한 task 당 파일 다섯 개 이하" "the Codex agent did not get the instruction"
hasnt "$t/.claude/agents/planner.md" "사람에게 하는 안내" "the file's guidance comment leaked into the agent"
hasnt "$t/.claude/agents/developer.md" "## 이 프로젝트에서" "another role got the note"
has "$t/.claude/settings.json" '"Edit(.ai/project/roles/**)"' "role notes are not protected"
rm "$t/.ai/project/roles/planner.md"; "$root/bin/harness" render --target "$t" >/dev/null
hasnt "$t/.claude/agents/planner.md" "## 이 프로젝트에서" "removing the note left the section behind"

echo "UT-43 steps use type, and a config that still says kind reads the same"
t="$work/wfnotes"; setup "$t"
has "$t/harness.toml" 'type = "prompt"' "the shipped steps still use kind"
sedi 's/type = "/kind = "/g' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "an old config with kind still renders" "$?" "0"

echo "UT-44 workflow notes reach that procedure only, and stay protected"
t="$work/wfnotes2"; setup "$t"
mkdir -p "$t/.ai/project/workflows"; printf -- '- 머지 전 스테이징에서 한 번 돌려 본다\n' > "$t/.ai/project/workflows/work.md"
"$root/bin/harness" render --target "$t" >/dev/null
has "$t/.ai/workflows/work.md" "## 이 프로젝트에서" "the workflow note did not reach the procedure"
has "$t/.ai/workflows/work.md" "스테이징에서 한 번" "the workflow note text is missing"
hasnt "$t/.ai/workflows/prework.md" "스테이징에서 한 번" "another workflow got the note"
has "$t/.claude/settings.json" '"Edit(.ai/project/workflows/**)"' "workflow notes are not protected"

echo "UT-45 review limits are whole numbers from 1 to 20"
t="$work/reviewlimit"; setup "$t"
for n in 0 21 abc; do
  "$root/bin/harness" set --target "$t" review.max_rounds "$n" >/dev/null 2>&1; check "refuse max_rounds=$n" "$?" "2"
done
"$root/bin/harness" set --target "$t" review.repeat_file_max 20 >/dev/null 2>&1; check "accept the upper bound" "$?" "0"

echo "UT-46 models come from each CLI's own record, and a role's model must match who runs it"
fh="$work/fakehome"; fb="$work/fakebin2"; mkdir -p "$fh/.claude" "$fh/.codex" "$fb"
cat > "$fb/claude" <<'SH'
#!/bin/sh
case "$1" in --version) echo "9.9.9 (Claude Code)";; --help) printf "  --model <model>   Model. Provide an alias (e.g.\n                    'fable', 'opus' or 'sonnet').\n  -n, --name <name>  x\n";; esac
SH
printf '#!/bin/sh\necho "codex-cli 1.0.0"\n' > "$fb/codex"; chmod +x "$fb"/*
printf '{"model": "opus[1m]"}' > "$fh/.claude/settings.json"
printf '{"models":[{"slug":"gpt-a","display_name":"GPT-A","visibility":"list"},{"slug":"gpt-hidden","visibility":"hide"}]}' > "$fh/.codex/models_cache.json"
printf 'model = "gpt-a"\n' > "$fh/.codex/config.toml"
py=$(command -v python3)
HOME="$fh" PATH="$fb:/usr/bin:/bin" "$py" "$root/bin/harness" tools --sync > "$work/models.out" 2>&1
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print({a["id"]: [m["id"] for m in a.get("models", [])] for a in d["agents"]})' "$HARNESS_HOME/tools.json" > "$work/models.sum"
has "$work/models.sum" "'claude': ['fable', 'opus', 'sonnet', 'opus[1m]']" "claude models were not read from its help and settings"
has "$work/models.sum" "'codex': ['gpt-a']" "codex models were not read from its cache (or a hidden one leaked)"
t="$work/models"; setup "$t"
"$root/bin/harness" set --target "$t" harness.model opus >/dev/null 2>&1; check "set the orchestrator model" "$?" "0"
has "$t/.claude/agents/planner.md" "model: opus" "a subagent without its own model does not inherit the orchestrator model"
"$root/bin/harness" schema --target "$t" | python3 -c 'import json,sys; d=json.load(sys.stdin)["roles"]["planner"]; print(d["model_ok"], d["follows_orchestrator"])' > "$work/mok"
check "a subagent role on the inherited model" "$(cat "$work/mok")" "True False"
"$root/bin/harness" set --target "$t" roles.planner.model sonnet >/dev/null 2>&1; check "set a model a role had no key for" "$?" "0"
has "$t/.claude/agents/planner.md" "model: sonnet" "a subagent's own model does not win over the inherited one"
"$root/bin/harness" set --target "$t" roles.planner.runner claude >/dev/null 2>&1
has "$t/.claude/agents/planner.md" "model: opus" "a role run by the orchestrator's own CLI does not use the orchestrator model"
"$root/bin/harness" doctor --target "$t" > "$work/doc.out" 2>&1
has "$work/doc.out" "roles.planner.model = sonnet is not used" "doctor does not say the role's model is unused"
"$root/bin/harness" set --target "$t" roles.code-reviewer.model opus >/dev/null 2>&1
"$root/bin/harness" schema --target "$t" | python3 -c 'import json,sys; print(json.load(sys.stdin)["roles"]["code-reviewer"]["model_ok"])' > "$work/mok"
check "a model of another vendor is flagged" "$(cat "$work/mok")" "False"
"$root/bin/harness" doctor --target "$t" > "$work/doc.out" 2>&1
has "$work/doc.out" "roles.code-reviewer.model = opus" "doctor does not warn about a model the runner lacks"

echo "UT-47 set changes several values at once, so a swap that no single step allows goes through"
t="$work/swap"; setup "$t"
"$root/bin/harness" set --target "$t" harness.orchestrator codex >/dev/null 2>&1; check "orchestrator alone collides with the reviewer" "$?" "2"
"$root/bin/harness" set --target "$t" roles.code-reviewer.runner claude >/dev/null 2>&1; check "reviewer alone collides with the orchestrator" "$?" "2"
"$root/bin/harness" set --target "$t" harness.orchestrator codex roles.code-reviewer.runner claude >/dev/null 2>&1
check "both at once" "$?" "0"
"$root/bin/harness" schema --target "$t" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["roles"]["planner"]["vendor"], d["roles"]["code-reviewer"]["vendor"])' > "$work/swap.out"
has "$work/swap.out" "codex claude" "subagent roles did not follow the orchestrator"
cp "$t/harness.toml" "$work/swap.before"
"$root/bin/harness" set --target "$t" review.max_rounds 3 review.repeat_file_max 99 >/dev/null 2>&1; check "one bad value refuses the batch" "$?" "2"
cmp -s "$t/harness.toml" "$work/swap.before"; check "the whole batch is reverted" "$?" "0"

echo "UT-48 status reports what doctor and check see, as JSON"
t="$work/status"; setup "$t"
"$root/bin/harness" status --target "$t" > "$work/status.json" 2>&1; check "status" "$?" "0"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["check_ok"], d["facts"]["total"], d["facts"]["filled"], any(i["what"]=="git hooks enabled" for i in d["doctor"]["items"]))' "$work/status.json" > "$work/status.sum"
has "$work/status.sum" "True 7 0 True" "status does not carry check, facts and the hooks warning"
printf '\nx\n' >> "$t/.ai/workflows/work.md"
"$root/bin/harness" status --target "$t" | python3 -c 'import json,sys; print(json.load(sys.stdin)["check_ok"])' > "$work/status.chk"
check "status sees generated drift" "$(cat "$work/status.chk")" "False"

echo "UT-49 a project can add its own workflow — procedure, command and table row come with it"
t="$work/customwf"; setup "$t"
wf='{"title":"긴급 수정","steps":[{"id":"step-1","type":"prompt","title":"원인 찾기","text":"로그를 본다"},{"id":"step-2","type":"agent","title":"고치기","role":"developer"}]}'
"$root/bin/harness" steps --target "$t" hotfix "$wf" --dry-run >/dev/null 2>&1; check "dry-run a new workflow" "$?" "0"
[ ! -f "$t/.ai/workflows/hotfix.md" ] && ok || bad "dry-run wrote the procedure"
"$root/bin/harness" steps --target "$t" hotfix "$wf" >/dev/null 2>&1; check "create a new workflow" "$?" "0"
has "$t/.ai/workflows/hotfix.md" "# hotfix — 긴급 수정" "the procedure has no head"
has "$t/.ai/workflows/hotfix.md" "### 2. 고치기 — 구현자 역할에 위임" "the steps were not rendered"
has "$t/.claude/commands/hotfix.md" ".ai/workflows/hotfix.md" "no command points at the procedure"
has "$t/CLAUDE.md" '`/hotfix <이슈번호>` — 긴급 수정' "the command table does not list it"
has "$t/harness.toml" 'title = "긴급 수정"' "the title was not written"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after a new workflow" "$?" "0"
"$root/bin/harness" steps --target "$t" hotfix '[{"id":"step-1","type":"prompt","title":"원인 찾기","text":"로그를 다시 본다"}]' >/dev/null 2>&1
has "$t/harness.toml" 'title = "긴급 수정"' "editing the steps dropped the title"
for bad in security-guard "Hot Fix" x; do
  "$root/bin/harness" steps --target "$t" "$bad" "$wf" >/dev/null 2>&1; check "refuse workflow name '$bad'" "$?" "2"
done
"$root/bin/harness" steps --target "$t" noname '[{"id":"a","type":"gate","title":"t"}]' >/dev/null 2>&1; check "a new workflow without a title" "$?" "0"
has "$t/.ai/workflows/noname.md" "# noname — noname" "a workflow without a title does not fall back to its name"

echo "UT-50 a project's own workflow can be renamed and deleted; the harness's cannot"
t="$work/wfrename"; setup "$t"
"$root/bin/harness" steps --target "$t" hotfix '{"title":"긴급","steps":[{"id":"a","type":"gate","title":"확인"}]}' >/dev/null 2>&1
mkdir -p "$t/.ai/project/workflows"; printf -- '- 메모\n' > "$t/.ai/project/workflows/hotfix.md"
"$root/bin/harness" steps --target "$t" hotfix --rename quickfix >/dev/null 2>&1; check "rename" "$?" "0"
[ -f "$t/.ai/workflows/quickfix.md" ] && [ ! -f "$t/.ai/workflows/hotfix.md" ] && ok || bad "the procedure did not follow the rename"
[ -f "$t/.claude/commands/quickfix.md" ] && [ ! -f "$t/.claude/commands/hotfix.md" ] && ok || bad "the command did not follow the rename"
[ -f "$t/.ai/project/workflows/quickfix.md" ] && ok || bad "the workflow note did not follow the rename"
"$root/bin/harness" steps --target "$t" quickfix --rename work >/dev/null 2>&1; check "rename onto an existing name" "$?" "2"
"$root/bin/harness" steps --target "$t" quickfix --delete >/dev/null 2>&1; check "delete" "$?" "0"
[ ! -f "$t/.ai/workflows/quickfix.md" ] && [ ! -f "$t/.claude/commands/quickfix.md" ] && ok || bad "delete left generated files"
hasnt "$t/harness.toml" "workflows.quickfix" "delete left the section in the config"
[ -f "$t/.ai/project/workflows/quickfix.md" ] && ok || bad "delete removed the person's note"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after delete" "$?" "0"
"$root/bin/harness" steps --target "$t" work --delete >/dev/null 2>&1; check "refuse deleting a harness workflow" "$?" "2"

echo "UT-36 install registers the project for the UI, uninstall drops it"
t="$work/reg/demo"; rm -rf "$t"; mkdir -p "$t"; ( cd "$t" && git init -q )
"$root/bin/harness" install --target "$t" >/dev/null 2>&1
has "$HARNESS_HOME/demo/project.json" "\"$(cd "$t" && pwd -P)\"" "install did not record the project path"
"$root/bin/harness" uninstall --target "$t" >/dev/null 2>&1
[ ! -f "$HARNESS_HOME/demo/project.json" ] && ok || bad "uninstall left the registry entry"

echo "UT-53 commands and checks live in harness.toml; verification is generated from them"
t="$work/verify"; setup "$t"
bash "$t/script/harness-verify.sh" >/dev/null 2>&1; check "unset verification" "$?" "3"
"$root/bin/harness" doctor --target "$t" > "$work/v.doc" 2>&1
has "$work/v.doc" "script/harness-verify.sh  — not set up" "doctor does not say verification is unset"
has "$t/.ai/AI_AGENT.md" "명령이 아직 정해지지 않았다" "the rules do not say the commands are unset"
# 쉼표·따옴표가 든 명령도 문자열 하나로 남는다
# 이 블록은 프로젝트 명령·검사를 본다 — 하네스 스크립트 회귀(수십 초)는 끈다
"$root/bin/harness" set --target "$t" commands.test 'echo "a, b" >/dev/null' commands.format_check 'true' verify.script_tests false >/dev/null 2>&1; check "set commands" "$?" "0"
has "$t/harness.toml" 'test = "echo \"a, b\" >/dev/null"' "the command was not kept as one string"
has "$t/.ai/AI_AGENT.md" '| 테스트 전체 | `echo "a, b" >/dev/null` |' "the rules do not list the command"
# 명령의 정본은 harness.toml 하나다 — UI 가 읽는 schema, 규칙 문서, 검증 스크립트가 모두 같은 값을 본다
"$root/bin/harness" schema --target "$t" | python3 -c 'import json,sys; print(json.load(sys.stdin)["commands"]["test"])' > "$work/v.schema"
has "$work/v.schema" 'echo "a, b" >/dev/null' "schema does not read the command from harness.toml"
has "$t/script/harness-verify.sh" "step '테스트'" "the verification script does not run the same command"
"$root/bin/harness" checks --target "$t" '[{"name":"경계","run":"! grep -rq forbidden src"}]' >/dev/null 2>&1; check "set checks" "$?" "0"
has "$t/.ai/AI_AGENT.md" "경계 → 코드 검사 → 테스트" "the check order is not in the rules"
( cd "$t" && bash script/harness-verify.sh ) > "$work/v.out" 2>&1; check "verification passes" "$?" "0"
mkdir -p "$t/src" && echo forbidden > "$t/src/a.txt"
( cd "$t" && bash script/harness-verify.sh ) > "$work/v.out" 2>&1; check "a failing check stops verification" "$?" "1"
has "$work/v.out" "verify: FAIL 경계" "the failure does not name the check"
"$root/bin/harness" doctor --target "$t" > "$work/v.doc" 2>&1
has "$work/v.doc" "fails at 경계" "doctor does not name the failing check"
"$root/bin/harness" checks --target "$t" '[{"name":"","run":"x"}]' >/dev/null 2>&1; check "refuse a nameless check" "$?" "2"
"$root/bin/harness" set --target "$t" commands.nope x >/dev/null 2>&1; check "refuse an unknown command key" "$?" "2"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after edits" "$?" "0"
# 손으로 쓴 옛 검증 스크립트가 있으면 그것이 돈다 — 옮기기 전까지 동작을 바꾸지 않는다
printf '#!/usr/bin/env bash\necho legacy-ran\n' > "$t/script/verify-project.sh"
( cd "$t" && sed -n '/^old=/,$p' script/run-lint-test.sh | bash ) > "$work/v.leg" 2>&1
has "$work/v.leg" "legacy-ran" "the hand-written script did not run"
"$root/bin/harness" doctor --target "$t" > "$work/v.doc" 2>&1
has "$work/v.doc" "runs instead of [commands] and [verify]" "doctor does not warn about the two sources"
# 옛 설정에는 [commands] 절이 없다 — set 이 절을 만든다
python3 - "$t/harness.toml" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r"(?ms)^\[commands\].*?(?=^\[verify\])", "", s)
open(p, "w").write(s)
PY
"$root/bin/harness" set --target "$t" commands.build "make" >/dev/null 2>&1; check "set on a config without [commands]" "$?" "0"
has "$t/harness.toml" 'build = "make"' "the section was not created"

echo "UT-54 run metrics: spans, rotation, retention, redaction, and the aggregate"
t="$work/metrics"; setup "$t"; md="$work/metrics-data"
"$root/bin/harness" set --target "$t" metrics.dir "$md" >/dev/null 2>&1; check "set metrics.dir" "$?" "0"
has "$t/script/harness.plan.json" "\"dir\": \"$md\"" "the plan does not carry the metrics dir"
# 감싼 명령의 출력과 종료 코드는 그대로다
( cd "$t" && script/metric.py wrap --name demo --kind script --attr step=review --attr workflow=work \
    -- bash -c 'echo out-line; echo "token=abc123 fail me@x.com at '"$HOME"'/x?q=1" >&2; exit 3' ) > "$work/m.out" 2> "$work/m.err"
check "wrap keeps the exit code" "$?" "3"
has "$work/m.out" "out-line" "wrap swallowed stdout"
has "$work/m.err" "token=abc123" "wrap swallowed stderr"
f=$(ls "$md"/spans-*.jsonl | head -1)
[ "$(stat -c %a "$md" 2>/dev/null || stat -f %Lp "$md")" = "700" ] && ok || bad "the metrics dir is not 0700"
[ "$(stat -c %a "$f" 2>/dev/null || stat -f %Lp "$f")" = "600" ] && ok || bad "a span file is not 0600"
hasnt "$f" "abc123" "a token reached the log"
hasnt "$f" "me@x.com" "an email reached the log"
hasnt "$f" "$HOME/" "the home path reached the log"
has "$f" 'token=***' "the log was not kept in redacted form"
"$root/bin/harness" set --target "$t" metrics.capture_logs off >/dev/null 2>&1
( cd "$t" && script/metric.py wrap --name demo2 --kind script -- false )
hasnt "$f" '"log":"",' "an empty log was written"
python3 -c 'import json,sys; e=[json.loads(l) for l in open(sys.argv[1])][-1]; sys.exit("log" in e)' "$f"; check "capture_logs off keeps no log" "$?" "0"
"$root/bin/harness" set --target "$t" metrics.capture_logs loud >/dev/null 2>&1; check "refuse an unknown capture_logs" "$?" "2"
# 두 프로세스가 동시에 써도 줄이 섞이지 않는다
rm -f "$md"/spans-*.jsonl
for n in 1 2; do ( cd "$t" && python3 -B -c 'import sys; sys.path.insert(0, "script"); import metric
for i in range(500): metric.start("p%d" % i, "script")' ) & done; wait
python3 -c 'import json,glob,sys; ls=[l for f in glob.glob(sys.argv[1]+"/spans-*.jsonl") for l in open(f)]; [json.loads(l) for l in ls]; print(len(ls))' "$md" > "$work/m.n"
has "$work/m.n" "1000" "concurrent writers lost or broke lines"
# 파일 하나가 상한을 넘으면 다음 번호로 넘어간다 (max_file_mb = 1)
"$root/bin/harness" set --target "$t" metrics.max_file_mb 1 metrics.max_total_mb 2 >/dev/null 2>&1
( cd "$t" && python3 -B -c 'import sys; sys.path.insert(0, "script"); import metric
for i in range(4500): metric.start("rotate-%d" % i, "script", {"workflow": "x" * 60})' )
[ "$(ls "$md"/spans-*.jsonl | wc -l | tr -d ' ')" -ge 2 ] && ok || bad "the span file did not rotate at max_file_mb"
# 보관 기간이 지난 파일과, 전체 상한을 넘는 오래된 파일은 지운다. 쓰는 중인 파일은 남는다
echo '{}' > "$md/spans-20000101-1.jsonl"
cur=$(ls "$md"/spans-*.jsonl | sort -t- -k2,2 -k3,3n | tail -1)
( cd "$t" && script/metric.py prune ) >/dev/null
[ ! -f "$md/spans-20000101-1.jsonl" ] && ok || bad "a file past retention_days was kept"
[ -f "$cur" ] && ok || bad "prune removed the file being written"
python3 -c 'import glob,os,sys; print(sum(os.path.getsize(f) for f in glob.glob(sys.argv[1]+"/spans-*.jsonl")) <= 2*1024*1024)' "$md" > "$work/m.cap"
has "$work/m.cap" "True" "prune did not enforce max_total_mb"
# 꺼져 있으면 아무것도 만들지 않고 명령만 돈다. 기록할 수 없는 곳이어도 종료 코드는 그대로다
"$root/bin/harness" set --target "$t" metrics.dir off >/dev/null 2>&1
( cd "$t" && script/metric.py wrap --name off --kind script -- sh -c 'exit 4' ); check "wrap with metrics off" "$?" "4"
"$root/bin/harness" set --target "$t" metrics.dir /dev/null/nope >/dev/null 2>&1
( cd "$t" && script/metric.py wrap --name nowhere --kind script -- sh -c 'exit 5' ) 2>/dev/null; check "an unwritable metrics dir does not change the exit code" "$?" "5"
# 집계 — 고정 스팬으로 상태·토큰·성공률·트리를 본다
"$root/bin/harness" set --target "$t" metrics.dir "$md" >/dev/null 2>&1
rm -f "$md"/spans-*.jsonl
python3 - "$md" <<'PY'
import datetime, json, sys
now = datetime.datetime.now(datetime.timezone.utc)
ts = lambda m: (now - datetime.timedelta(minutes=m)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
ev = [
  {"ev":"start","trace":"t1","span":"a","parent":None,"name":"work","kind":"command","source":"runner","attrs":{"workflow":"work"},"t":ts(30)},
  {"ev":"start","trace":"t1","span":"b","parent":"a","name":"review","kind":"agent","source":"runner","attrs":{"workflow":"work","step":"review","role":"code-reviewer","vendor":"codex"},"t":ts(29)},
  {"ev":"end","span":"b","status":"ok","dur_ms":60000,"usage":{"input":100,"output":20},"model":"m1","t":ts(28)},
  {"ev":"end","span":"a","status":"ok","dur_ms":120000,"t":ts(28)},
  {"ev":"start","trace":"t2","span":"c","parent":None,"name":"verify","kind":"script","source":"script","attrs":{},"t":ts(20)},
  {"ev":"end","span":"c","status":"error","exit":1,"dur_ms":5000,"t":ts(19)},
  {"ev":"start","trace":"t3","span":"d","parent":None,"name":"long","kind":"command","source":"runner","attrs":{},"t":ts(60*8)},
  {"ev":"start","trace":"t4","span":"e","parent":None,"name":"now","kind":"command","source":"runner","attrs":{},"t":ts(1)},
]
open(sys.argv[1] + "/spans-20990101-1.jsonl", "w").write("".join(json.dumps(dict(e, v=1)) + "\n" for e in ev) + '{"ev":"start","half')
PY
"$root/bin/harness" metrics --target "$t" --since 1d --trace t1 > "$work/m.json"; check "metrics" "$?" "0"
python3 - "$work/m.json" > "$work/m.sum" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); s = d["summary"]
print(s["runs"], s["ok"], s["error"], s["running"], s["stale"], s["success_rate"], s["tokens"]["input"] + s["tokens"]["output"])
print(d["by_role"][0]["name"], d["by_role"][0]["tokens"], d["by_step"][0]["name"], d["diagnostics"]["bad_lines"])
print([(x["name"], x["offset_ms"] >= 0) for x in d["trace"]], d["errors"][0]["name"], d["daily"][0]["by"])
PY
has "$work/m.sum" "4 1 1 1 1 0.5 120" "the summary counts are wrong (runs ok error running stale rate tokens)"
has "$work/m.sum" "code-reviewer 120 work/review 1" "grouping or the half-written line count is wrong"
has "$work/m.sum" "[('work', True), ('review', True)] verify {'codex/m1': 120}" "the trace tree, errors or daily tokens are wrong"

echo "UT-55 harness run, run-lint-test and verification steps nest under one trace"
t="$work/traced"; setup "$t"; md="$work/traced-data"
"$root/bin/harness" set --target "$t" metrics.dir "$md" commands.test "true" commands.format_check "true" verify.script_tests false >/dev/null 2>&1
( cd "$t" && git init -q . 2>/dev/null; ./script/run-lint-test.sh ) > "$work/rl.log" 2>&1; check "run-lint-test with commands set" "$?" "0"
python3 - "$md" > "$work/rl.sum" <<'PY'
import glob, json, sys
ev = [json.loads(l) for f in glob.glob(sys.argv[1] + "/spans-*.jsonl") for l in open(f)]
st = {e["span"]: e for e in ev if e["ev"] == "start"}
root = [e for e in st.values() if e["name"] == "run-lint-test"]
kids = sorted(e["name"] for e in st.values() if root and e["trace"] == root[0]["trace"] and e["name"].startswith("verify/"))
print(len(root), kids, all(st.get(e["parent"], {}).get("name") in ("run-lint-test", "harness-verify") or e["name"] == "run-lint-test" for e in st.values() if root and e["trace"] == root[0]["trace"]))
PY
has "$work/rl.sum" "1 ['verify/코드-검사', 'verify/테스트'] True" "verification steps did not nest under run-lint-test"
# doctor 는 점검이다 — 검증을 돌려도 실행 지표를 남기지 않는다. 직접 부른 검증은 한 실행으로 묶인다
n0=$(cat "$md"/spans-*.jsonl | wc -l)
"$root/bin/harness" doctor --target "$t" >/dev/null 2>&1
[ "$(cat "$md"/spans-*.jsonl | wc -l)" = "$n0" ] && ok || bad "doctor left metrics behind"
( cd "$t" && bash script/harness-verify.sh ) >/dev/null 2>&1
python3 -c 'import glob,json,sys; ev=[json.loads(l) for f in glob.glob(sys.argv[1]+"/spans-*.jsonl") for l in open(f)][int(sys.argv[2]):]; st=[e for e in ev if e["ev"]=="start"]; print(len({e["trace"] for e in st}), [e["name"] for e in st][0])' "$md" "$n0" > "$work/hv.sum"
has "$work/hv.sum" "1 harness-verify" "a direct verification run did not stay one trace"
# harness run — 오케스트레이터(스텁)를 기다렸다가 끝 기록까지 남기고, 트레이스를 자식에게 넘긴다
mkdir -p "$work/orch" && cat > "$work/orch/claude" <<'SH'
#!/usr/bin/env sh
echo "trace=$HARNESS_TRACE_ID wf=$HARNESS_WORKFLOW" > "$ORCH_OUT"
exit 0
SH
chmod +x "$work/orch/claude"
"$root/bin/harness" set --target "$t" harness.orchestrator claude roles.code-reviewer.runner codex >/dev/null 2>&1
( cd "$t" && ORCH_OUT="$work/orch.out" PATH="$work/orch:$PATH" "$root/bin/harness" run work 12 ) >/dev/null 2>&1; check "harness run exit code" "$?" "0"
has "$work/orch.out" "wf=work" "harness run did not pass the workflow to the orchestrator"
"$root/bin/harness" metrics --target "$t" --since 1d > "$work/run.json"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); r=[x for x in d["traces"] if x["name"]=="run/work"]; print(len(r), r[0]["status"], r[0]["attrs"].get("issue"), r[0]["trace"] in open(sys.argv[2]).read())' "$work/run.json" "$work/orch.out" > "$work/run.sum"
has "$work/run.sum" "1 ok 12 True" "harness run did not record its span or pass the trace"

echo "UT-56 session import: usage by run, step and role, once, without message text"
t="$work/imported"; setup "$t"; md="$work/imported-data"; cl="$work/claude-projects"; cx="$work/codex-sessions"
"$root/bin/harness" set --target "$t" metrics.dir "$md" >/dev/null 2>&1
python3 - "$t" "$cl" "$cx" <<'PY'
import datetime, json, os, re, sys
t, cl, cx = sys.argv[1:4]
sys.path.insert(0, t + "/script"); sys.dont_write_bytecode = True
import metric
now = datetime.datetime.now(datetime.timezone.utc)
at = lambda m: now - datetime.timedelta(minutes=m)
ts = lambda m: at(m).strftime("%Y-%m-%dT%H:%M:%S.000Z")
tr, run = metric.start("run/work", "command", {"workflow": "work", "vendor": "claude"}, trace="t-run", parent="", source="runner", t=at(10))
metric.end(run, "ok", 0, t=at(1))
for m, st in ((9, "implement"), (5, "review")):
    _, s = metric.start("work/" + st, "marker", {"workflow": "work", "step": st}, trace="t-run", parent=run, source="session", t=at(m)); metric.end(s, t=at(m))
d = os.path.join(cl, re.sub(r"[^A-Za-z0-9]", "-", os.path.realpath(t)))
os.makedirs(d + "/sess/subagents")
line = lambda m, mid, i, o: json.dumps({"type": "assistant", "sessionId": "sess", "timestamp": ts(m),
    "message": {"id": mid, "model": "claude-x", "content": [{"type": "text", "text": "SECRET-BODY"}], "usage": {"input_tokens": i, "output_tokens": o}}})
open(d + "/sess.jsonl", "w").write("\n".join([line(8, "a1", 10, 5), line(8, "a1", 10, 5), line(4, "a2", 20, 10)]) + "\n" + line(3, "a3", 100, 0)[:40])
open(d + "/sess/subagents/agent-1.jsonl", "w").write(line(7, "b1", 7, 3) + "\n")
open(d + "/sess/subagents/agent-1.meta.json", "w").write(json.dumps({"agentType": "developer"}))
os.makedirs(cx + "/2026/09/25")
rec = lambda m, rid: json.dumps({"timestamp": ts(m), "type": "token_usage_record", "payload": {"response_id": rid, "usage": {"input_tokens": 14, "cached_input_tokens": 4, "output_tokens": 6}}})
meta = lambda cwd: json.dumps({"timestamp": ts(3), "type": "session_meta", "payload": {"id": "cx1", "cwd": cwd}})
open(cx + "/2026/09/25/rollout-a.jsonl", "w").write("\n".join([meta(os.path.realpath(t)), rec(3, "r1"), rec(3, "r1")]) + "\n")
open(cx + "/2026/09/25/rollout-b.jsonl", "w").write("\n".join([meta("/elsewhere"), rec(3, "r9")]) + "\n")
PY
imp() { HARNESS_CLAUDE_DIR="$cl" HARNESS_CODEX_DIR="$cx" "$root/bin/harness" metrics import --target "$t" --since 1d --trace t-run; }
imp > "$work/imp1.json"; check "metrics import" "$?" "0"
sum() { python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
st = {x["name"]: x["tokens"] for x in d["by_step"]}; ro = {x["name"]: x["tokens"] for x in d["by_role"]}
un = [x["tokens"] for x in d["traces"] if x["name"] == "unattributed"]
print(d["diagnostics"]["imported"]["records"], st.get("work/implement"), st.get("work/review"), ro.get("developer"), un, d["summary"]["runs"])
PY
}
sum "$work/imp1.json" > "$work/imp1.sum"
has "$work/imp1.sum" "4 25 30 10 [16] 1" "import totals are wrong (records implement review developer unattributed runs)"
hasnt "$md"/$(ls "$md" | grep spans | head -1) "SECRET-BODY" "message text reached the metrics"
grep -rqF "SECRET-BODY" "$md" && bad "message text reached the metrics" || ok
imp > "$work/imp2.json"; sum "$work/imp2.json" > "$work/imp2.sum"
has "$work/imp2.sum" "0 25 30 10 [16] 1" "a second import counted the same usage again"
# 쓰는 중이던 마지막 줄이 끝나면 다음 가져오기에서 한 번만 센다
python3 - "$cl" "$t" <<'PY'
import glob, json, sys
f = glob.glob(sys.argv[1] + "/*/sess.jsonl")[0]
body = open(f).read(); last = body.rsplit("\n", 1)[1]
full = json.dumps({"type": "assistant", "sessionId": "sess", "timestamp": json.loads(body.split("\n")[2])["timestamp"],
                   "message": {"id": "a3", "model": "claude-x", "usage": {"input_tokens": 100, "output_tokens": 0}}})
open(f, "w").write(body[: len(body) - len(last)] + full + "\n")
PY
imp > "$work/imp3.json"; sum "$work/imp3.json" > "$work/imp3.sum"
has "$work/imp3.sum" "1 25 130 10 [16] 1" "the completed line was not imported exactly once"
cur="$HARNESS_HOME/my-project/state/import-cursor.json"   # setup 의 설정은 project.name 을 바꾸지 않는다
[ "$(stat -c %a "$cur" 2>/dev/null || stat -f %Lp "$cur")" = "600" ] && ok || bad "the import cursor is not 0600"

echo "UT-63 review threads carry an id, and a reply lands on the thread it names"
# 답글을 달려면 조회 결과가 스레드를 지목할 수 있어야 한다. 정규화와 호출 경로는 자격증명 없이 도는
# 부분이라 가짜 CLI 로 본다 — 실제 forge 로 보는 것은 자체 검사의 몫이다.
t="$work/thread-reply"; rm -rf "$t"; mkdir -p "$t"
cp "$root/templates/managed/script/forge/"*.sh "$t/"
cat > "$t/fake-gh" <<'GH'
#!/bin/sh
printf '%s\n' "$@" >> "$FAKE_CALLS"
case "$*" in
  *pulls/5/comments\?*) printf '%s' '[{"id":11,"path":"a.sh","line":3,"body":"지적","created_at":"2026-01-01T00:00:00Z"},{"id":12,"in_reply_to_id":11,"path":"a.sh","line":3,"body":"조치","created_at":"2026-01-01T00:00:01Z"}]' ;;
  *issues/5/comments\?*) printf '%s' '[{"id":21,"body":"요약","created_at":"2026-01-01T00:00:02Z"}]' ;;
  *comments/11/replies*) printf '{}' ;;
  *) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
esac
GH
cat > "$t/fake-glab" <<'GL'
#!/bin/sh
printf '%s\n' "$@" >> "$FAKE_CALLS"
case "$*" in
  *merge_requests/5/discussions\?*page=1*) printf '%s' '[{"id":"abc","individual_note":false,"notes":[{"body":"지적","created_at":"t1","position":{"new_path":"a.sh","new_line":3}},{"body":"조치","created_at":"t2"}]},{"id":"def","individual_note":true,"notes":[{"body":"요약","created_at":"t3"}]},{"id":"sys","individual_note":true,"notes":[{"body":"added 1 commit","system":true}]}]' ;;
  *discussions/abc/notes*) printf '{}' ;;
  *) echo "glab: 404 Not Found" >&2; exit 1 ;;
esac
GL
chmod +x "$t/fake-gh" "$t/fake-glab"
export FAKE_CALLS="$t/calls"

ids() { python3 -c '
import json, sys
for x in json.load(open(sys.argv[1])):
    print("%s %s %d" % (json.dumps(x.get("id", "MISSING")), x["inline"], len(x["notes"])))' "$1"; }

( _FORGE_WANT_REVIEW=1; . "$t/github.sh"; GITHUB_CLI="$t/fake-gh"; review_mr_threads 5 ) > "$work/gh-threads.json" 2>&1
ids "$work/gh-threads.json" > "$work/gh-ids.txt" 2>&1
has   "$work/gh-ids.txt" '"11" True 2' "GitHub: the inline thread does not carry its root comment id with its reply"
has   "$work/gh-ids.txt" 'null False 1' "GitHub: a plain PR comment does not carry a null id"
hasnt "$work/gh-ids.txt" '"12"'        "GitHub: a reply surfaced as a thread of its own"

: > "$FAKE_CALLS"
( _FORGE_WANT_REVIEW=1; . "$t/github.sh"; GITHUB_CLI="$t/fake-gh"; review_mr_thread_reply 5 11 "고쳤다" )
check "GitHub: a reply to an existing thread" "$?" "0"
has "$FAKE_CALLS" "repos/{owner}/{repo}/pulls/5/comments/11/replies" "GitHub: the reply did not go to the thread's replies endpoint"
has "$FAKE_CALLS" "body=고쳤다" "GitHub: the reply body was not sent"
( _FORGE_WANT_REVIEW=1; . "$t/github.sh"; GITHUB_CLI="$t/fake-gh"; review_mr_thread_reply 5 99 "고쳤다" ) 2>"$work/gh-reply.err"
check "GitHub: a reply to an unknown thread fails" "$?" "1"
has "$work/gh-reply.err" "404" "GitHub: the failure does not say why"

( _FORGE_WANT_REVIEW=1; . "$t/gitlab.sh"; GITLAB_CLI="$t/fake-glab"; review_mr_threads 5 ) > "$work/gl-threads.json" 2>&1
ids "$work/gl-threads.json" > "$work/gl-ids.txt" 2>&1
has   "$work/gl-ids.txt" '"abc" True 2' "GitLab: the inline discussion does not carry its id with its reply"
has   "$work/gl-ids.txt" 'null False 1' "GitLab: an individual note does not carry a null id"
hasnt "$work/gl-ids.txt" '"sys"'       "GitLab: a system note surfaced as a thread"

: > "$FAKE_CALLS"
( _FORGE_WANT_REVIEW=1; . "$t/gitlab.sh"; GITLAB_CLI="$t/fake-glab"; review_mr_thread_reply 5 abc "고쳤다" )
check "GitLab: a reply to an existing discussion" "$?" "0"
has "$FAKE_CALLS" "projects/:id/merge_requests/5/discussions/abc/notes" "GitLab: the reply did not go to the discussion's notes"
has "$FAKE_CALLS" "POST" "GitLab: the reply is not a POST"
( _FORGE_WANT_REVIEW=1; . "$t/gitlab.sh"; GITLAB_CLI="$t/fake-glab"; review_mr_thread_reply 5 nope "고쳤다" ) 2>/dev/null
check "GitLab: a reply to an unknown discussion fails" "$?" "1"

# 페이크 어댑터는 자체 검사의 기준이다. 계약대로 답글을 붙이고 없는 스레드를 거부해야 한다.
fst="$work/thread-fake"; rm -rf "$fst"; mkdir -p "$fst"
( FAKE_STATE="$fst"; FAKE_BREAK=""; . "$root/test/fake-forge.sh"
  review_mr_note_inline 1 sample.txt 2 "지적" >/dev/null
  printf '요약\n' > "$fst/s.md"; review_mr_note_summary 1 "$fst/s.md" >/dev/null
  review_mr_thread_reply 1 t1 "고쳤다" && review_mr_threads 1 ) > "$work/fake-threads.json" 2>&1
check "fake forge: a reply to an existing thread" "$?" "0"
python3 -c '
import json, sys
t = json.load(open(sys.argv[1]))
ok = t[0]["id"] == "t1" and [n["body"] for n in t[0]["notes"]] == ["지적", "고쳤다"] and t[1]["id"] is None and len(t) == 2
raise SystemExit(0 if ok else 1)' "$work/fake-threads.json" 2>/dev/null \
  && ok || bad "fake forge: the reply is not the last note of the thread it names"
( FAKE_STATE="$fst"; FAKE_BREAK=""; . "$root/test/fake-forge.sh"; review_mr_thread_reply 1 t9 "고쳤다" ) 2>"$work/fake-reply.err"
check "fake forge: a reply to an unknown thread fails" "$?" "1"
has "$work/fake-reply.err" "t9" "fake forge: the failure does not name the thread"

# Jira 는 리뷰를 호스트하지 않는다. 답글이 성공처럼 지나가면 조치가 어디에도 남지 않는다.
( _FORGE_WANT_TRACKER=0; _FORGE_WANT_REVIEW=1; . "$t/jira.sh"; review_mr_thread_reply 5 11 "고쳤다" ) 2>"$work/jira-reply.err"
check "Jira: a thread reply is refused" "$?" "2"
has "$work/jira-reply.err" "not supported" "Jira: the refusal does not say it is unsupported"
unset FAKE_CALLS

echo "UT-70 the worktree section: defaults, unknown keys and paths that are not relative are refused"
t="$work/wtcfg"; setup "$t"
has "$t/harness.toml" 'dir = "$HOME/.harness/{project}/worktrees"' "the default config has no worktree.dir default"
has "$t/harness.toml" 'include = [".claude/settings.local.json"]' "the default config has no worktree.include default"
cp "$t/harness.toml" "$work/wtcfg.orig"
wt_render() { "$root/bin/harness" render --target "$t" > "$work/wtcfg.log" 2>&1; }
python3 - "$t/harness.toml" <<'PY'
import sys; p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace('include = [".claude/settings.local.json"]', 'include = [".claude/settings.local.json"]\nenabled = true'))
PY
wt_render; check "render with an unknown worktree key" "$?" "2"
has "$work/wtcfg.log" "unknown key(s) in [worktree]: enabled" "the unknown worktree key is not named"
has "$work/wtcfg.log" "the keys are dir, include" "the worktree keys are not listed"
for bad_path in "/etc/x" "../x" "a/../b" "a b" "*.json" "a?" "[ab]"; do
  cp "$work/wtcfg.orig" "$t/harness.toml"
  python3 - "$t/harness.toml" "$bad_path" <<'PY'
import json, sys; p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace('include = [".claude/settings.local.json"]', 'include = [".env", %s]' % json.dumps(sys.argv[2])))
PY
  wt_render; check "render with worktree.include item $bad_path" "$?" "2"
  has "$work/wtcfg.log" "worktree.include[2] must be a path relative to the harness root" "the bad include item $bad_path is not named"
done
cp "$work/wtcfg.orig" "$t/harness.toml"
sedi 's|^dir = "\$HOME/.harness/{project}/worktrees"$|dir = "  "|' "$t/harness.toml"
wt_render; check "render with a blank worktree.dir" "$?" "2"
has "$work/wtcfg.log" "worktree.dir must be" "the blank worktree.dir is not named"
# 절이 없는 옛 설정은 기본값으로 돈다
cp "$work/wtcfg.orig" "$t/harness.toml"
python3 - "$t/harness.toml" <<'PY'
import re, sys; p = sys.argv[1]; s = open(p).read()
s, n = re.subn(r'^\[worktree\]\n(?:(?!\[).*\n)*', '', s, flags=re.M)
assert n == 1 and "[worktree]" not in s
open(p, "w").write(s)
PY
wt_render; check "render without a worktree section" "$?" "0"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check without a worktree section" "$?" "0"
cp "$work/wtcfg.orig" "$t/harness.toml"

echo "UT-71 harness run --worktree makes a worktree per issue, reopens a clean one and removes it when nothing is left"
t="$work/wtrun"; setup "$t"; wd="$work/wtrun-trees"
"$root/bin/harness" set --target "$t" worktree.dir "$wd" >/dev/null 2>&1 || bad "could not set worktree.dir"
wtg() { git -C "$1" -c user.name=t -c user.email=t@example.invalid "${@:2}"; }
git init -q --bare -b development "$work/wtrun-origin.git"
( cd "$t" && git init -q -b development . && echo a > tracked.txt )
wtg "$t" add -A && wtg "$t" commit -q -m "chore: 하네스" && wtg "$t" remote add origin "$work/wtrun-origin.git" \
  && wtg "$t" push -q origin development || bad "could not set up the worktree test repo"
# 가짜 오케스트레이터: 불린 자리와 HEAD 를 적고, 케이스에 따라 추적 파일을 고치거나 커밋한다
mkdir -p "$work/wtorch" && cat > "$work/wtorch/claude" <<'SH'
#!/bin/sh
{ pwd -P; git rev-parse HEAD; git symbolic-ref -q HEAD || echo detached; } > "$WT_OUT"
git status --porcelain > "$WT_OUT.status"
top=$(git rev-parse --show-toplevel)
case "$WT_ACT" in
  keep)   touch "$top/keep.me" ;;
  edit)   echo b >> "$top/tracked.txt" ;;
  commit) echo c >> "$top/tracked.txt"; git -c user.name=t -c user.email=t@example.invalid commit -qam "feat: x(#7)" --no-verify ;;
esac
exit "${WT_CODE:-0}"
SH
chmod +x "$work/wtorch/claude"
wtrun() { # wtrun <하네스 루트> <인자...> — 가짜 오케스트레이터로 harness run 을 돌린다. 출력은 wt.log, 불린 자리는 wt.cwd
  local dir="$1"; shift; rm -f "$work/wt.cwd"
  ( cd "$dir" && PATH="$work/wtorch:$PATH" WT_OUT="$work/wt.cwd" "$root/bin/harness" run "$@" ) > "$work/wt.log" 2>&1
}
called() { [ -f "$work/wt.cwd" ] && sed -n "${1}p" "$work/wt.cwd"; }
base_head=$(git -C "$t" rev-parse origin/development)

wtrun "$t" work 7 --worktree; check "run --worktree exit code" "$?" "0"
real_wd=$(cd "$wd" && pwd -P)
check "the orchestrator runs inside the new worktree" "$(called 1)" "$real_wd/7"
check "the new worktree starts at the remote integration branch" "$(called 2)" "$base_head"
check "the new worktree's HEAD is detached" "$(called 3)" "detached"
has "$work/wt.log" "worktree: $wd/7 (new)" "run --worktree did not name the new worktree"
has "$work/wt.log" "removed worktree $wd/7" "a worktree left clean was not removed"
[ ! -e "$wd/7" ] && ok || bad "the clean worktree is still on disk"
git -C "$t" worktree list | grep -qF "wtrun-trees/7" && bad "the clean worktree is still registered" || ok

wtrun "$t" work 7; check "run without --worktree exit code" "$?" "0"
check "without --worktree the orchestrator runs at the harness root" "$(called 1)" "$(cd "$t" && pwd -P)"
[ ! -e "$wd/7" ] && ok || bad "a worktree was made without --worktree"

WT_ACT=edit WT_CODE=3 wtrun "$t" work 7 --worktree; check "exit code is the orchestrator's when the worktree is kept" "$?" "3"
has "$work/wt.log" "kept worktree $wd/7 — uncommitted changes" "a worktree with uncommitted changes was not kept"
[ -d "$wd/7" ] && ok || bad "the worktree with uncommitted changes was removed"

wtrun "$t" work 7 --worktree; check "exit code for a worktree with uncommitted changes" "$?" "1"
[ -f "$work/wt.cwd" ] && bad "the orchestrator launched in a worktree with uncommitted changes" || ok
has "$work/wt.log" "stop: worktree $wd/7 has uncommitted changes" "the stop does not name the worktree"
has "$work/wt.log" " M tracked.txt" "the stop does not show the status lines"
wtg "$wd/7" checkout -q -- tracked.txt

WT_ACT=commit wtrun "$t" work 7 --worktree; check "run that commits exit code" "$?" "0"
has "$work/wt.log" "worktree: $wd/7 (reopened)" "a clean worktree was not reopened"
has "$work/wt.log" "kept worktree $wd/7 — unpushed commits" "a worktree with unpushed commits was not kept"
wtg "$wd/7" push -q origin HEAD:refs/heads/wt7 || bad "could not push the worktree commit"
head7=$(git -C "$wd/7" rev-parse HEAD)
wtrun "$t" work 7 --worktree; check "reopening a clean worktree exit code" "$?" "0"
has "$work/wt.log" "worktree: $wd/7 (reopened)" "a clean worktree was not reopened"
check "the reopened worktree keeps its HEAD" "$(called 2)" "$head7"
check "the orchestrator runs inside the reopened worktree" "$(called 1)" "$real_wd/7"
[ ! -e "$wd/7" ] && ok || bad "the pushed worktree was not removed"

o="$work/wtother"; rm -rf "$o"; mkdir -p "$o"; ( cd "$o" && git init -q . && echo o > o.txt )
wtg "$o" add -A && wtg "$o" commit -q -m init && wtg "$o" worktree add -q --detach "$wd/7" || bad "could not make another repo's worktree"
ohead=$(git -C "$wd/7" rev-parse HEAD)
wtrun "$t" work 7 --worktree; check "exit code for another repository's worktree" "$?" "2"
[ -f "$work/wt.cwd" ] && bad "the orchestrator launched in another repository's worktree" || ok
has "$work/wt.log" "error: $wd/7 is not a worktree of this repository" "the path conflict is not named"
check "another repository's worktree is left as it was" "$(git -C "$wd/7" rev-parse HEAD) $(git -C "$wd/7" status --porcelain | wc -l | tr -d ' ')" "$ohead 0"
wtg "$o" worktree remove "$wd/7"

mkdir -p "$wd/7" && echo x > "$wd/7/f"
wtrun "$t" work 7 --worktree; check "exit code for a directory that is not a git tree" "$?" "2"
[ -f "$wd/7/f" ] && [ ! -f "$work/wt.cwd" ] && ok || bad "a plain directory was touched or the orchestrator launched"
rm -f "$wd/7/f"
wtrun "$t" work 7 --worktree; check "an empty directory becomes the worktree" "$?" "0"
check "the orchestrator runs inside the worktree made in an empty directory" "$(called 1)" "$real_wd/7"

wtrun "$t" retro x --worktree; check "exit code for an issue that is not a number" "$?" "2"
has "$work/wt.log" "error: --worktree needs an issue number (got x)" "the bad issue is not named"
[ ! -e "$wd/x" ] && [ ! -f "$work/wt.cwd" ] && ok || bad "something was made for an issue that is not a number"

for inside in "$t/trees" "rel/trees"; do
  "$root/bin/harness" set --target "$t" worktree.dir "$inside" >/dev/null 2>&1
  wtrun "$t" work 7 --worktree; check "exit code for worktree.dir $inside" "$?" "2"
  [ ! -e "$t/trees" ] && [ ! -e "$t/rel" ] && [ ! -f "$work/wt.cwd" ] && ok || bad "worktree.dir $inside made something or launched"
done
"$root/bin/harness" set --target "$t" worktree.dir "$wd" >/dev/null 2>&1

wtg "$t" remote rename origin upstream
wtrun "$t" work 7 --worktree; check "exit code when the fetch fails" "$?" "2"
[ ! -e "$wd/7" ] && [ ! -f "$work/wt.cwd" ] && ok || bad "a failed fetch made a worktree or launched"
wtg "$t" remote rename upstream origin

wtrun "$t" work 7 --worktree --dry-run; check "run --worktree --dry-run exit code" "$?" "0"
[ ! -e "$wd/7" ] && ok || bad "--dry-run made a worktree"
has "$work/wt.log" "worktree: $wd/7 (new)" "--dry-run does not show the worktree"
has "$work/wt.log" "/work 7" "--dry-run does not show the command"

mono="$work/wtmono"; rm -rf "$mono"; mkdir -p "$mono"; setup "$mono/sub"; wd2="$work/wtmono-trees"
"$root/bin/harness" set --target "$mono/sub" worktree.dir "$wd2" >/dev/null 2>&1
git init -q --bare -b development "$work/wtmono-origin.git"
( cd "$mono" && git init -q -b development . && echo a > tracked.txt )
wtg "$mono" add -A && wtg "$mono" commit -q -m "chore: 하네스" && wtg "$mono" remote add origin "$work/wtmono-origin.git" \
  && wtg "$mono" push -q origin development || bad "could not set up the monorepo worktree test repo"
wtrun "$mono/sub" work 7 --worktree; check "monorepo run --worktree exit code" "$?" "0"
check "in a monorepo the orchestrator runs at the harness root's place in the worktree" "$(called 1)" "$(cd "$wd2" && pwd -P)/7/sub"

echo "UT-72 a new worktree gets the ignored local files, and its hooks and guard are its own"
# UT-71 의 리포를 이어 쓴다. 무시 규칙은 checkout 이 가져가야 하므로 원격에 올린다
printf '.claude/settings.local.json\nlocal-dir/\n' >> "$t/.gitignore"
wtg "$t" add .gitignore && wtg "$t" commit -q -m "chore: 무시 규칙" && wtg "$t" push -q origin development || bad "could not push the ignore rules"
( cd "$t" && printf 'local\n' > .claude/settings.local.json && chmod 600 .claude/settings.local.json \
  && mkdir -p local-dir && echo d > local-dir/a && ln -sf a local-dir/ln && echo n > notignored.txt && echo changed > tracked.txt )
"$root/bin/harness" set --target "$t" worktree.include ".claude/settings.local.json,local-dir,notignored.txt,missing.txt,tracked.txt" >/dev/null 2>&1 \
  || bad "could not set worktree.include"
WT_ACT=keep wtrun "$t" work 8 --worktree; check "run --worktree with include exit code" "$?" "0"
cmp -s "$t/.claude/settings.local.json" "$wd/8/.claude/settings.local.json" && ok || bad "an ignored include file was not copied"
check "the copied file keeps its permission bits" "$(stat -c %a "$wd/8/.claude/settings.local.json" 2>/dev/null || stat -f %Lp "$wd/8/.claude/settings.local.json")" "600"
[ -f "$wd/8/local-dir/a" ] && [ -L "$wd/8/local-dir/ln" ] && ok || bad "an ignored directory was not copied whole with its symlink"
[ ! -e "$wd/8/notignored.txt" ] && ok || bad "a file git does not ignore was copied"
has "$work/wt.log" "warn: notignored.txt is not ignored by git — not copied" "the file git does not ignore was not warned about"
[ ! -e "$wd/8/missing.txt" ] && ok || bad "a missing include path appeared in the worktree"
hasnt "$work/wt.log" "missing.txt" "a missing include path was reported"
check "a tracked include path keeps the checkout's content" "$(cat "$wd/8/tracked.txt")" "a"
check "git status is clean after the copy" "$(wc -c < "$work/wt.cwd.status" | tr -d ' ')" "0"
hasnt "$work/wt.log" "settings.local.json" "run printed a copied path"
has "$work/wt.log" "kept worktree $wd/8 — uncommitted changes" "the kept worktree is not reported"
# 다시 열 때는 복사하지 않는다
rm -f "$wd/8/keep.me" "$wd/8/.claude/settings.local.json"
WT_ACT=keep wtrun "$t" work 8 --worktree; check "reopen with include exit code" "$?" "0"
has "$work/wt.log" "worktree: $wd/8 (reopened)" "the worktree was not reopened"
[ ! -e "$wd/8/.claude/settings.local.json" ] && ok || bad "a reopened worktree got the include files again"
# worktree 의 git 훅: core.hooksPath 의 상대 경로가 worktree 최상위 기준으로 풀린다
git -C "$t" config core.hooksPath script/githooks
rm -f "$wd/8/keep.me"; echo hook >> "$wd/8/tracked.txt"
wtg "$wd/8" commit -qam "not the commit form" > "$work/wthook.log" 2>&1; check "commit-msg in a worktree refuses a bad subject" "$?" "1"
has "$work/wthook.log" "commit subject does not match the required form" "the worktree's commit-msg hook did not run"
git -C "$t" config --unset core.hooksPath
# worktree 의 명령 가드: settings.json 의 훅 명령이 그 worktree 의 가드와 harness.env 를 부른다
gcmd=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["PreToolUse"][0]["hooks"][0]["command"])' "$wd/8/.claude/settings.json")
case "$gcmd" in '$CLAUDE_PROJECT_DIR/script/hooks/bash-guard.sh') ok ;; *) bad "the guard command is not under CLAUDE_PROJECT_DIR: $gcmd" ;; esac
printf '{"tool_input":{"command":"git push origin development"}}' | CLAUDE_PROJECT_DIR="$wd/8" sh -c "$gcmd" > "$work/wtguard.log" 2>&1
check "the worktree's guard blocks a push to a protected branch" "$?" "2"
wtg "$wd/8" checkout -q -- tracked.txt && wtg "$t" worktree remove "$wd/8" || bad "could not remove the include worktree"
"$root/bin/harness" set --target "$t" worktree.include ".claude/settings.local.json" >/dev/null 2>&1
# 모노레포: 실행 디렉터리 아래로 복사한다
printf '.claude/settings.local.json\n' > "$mono/sub/.gitignore"
wtg "$mono" add sub/.gitignore && wtg "$mono" commit -q -m "chore: 무시 규칙" && wtg "$mono" push -q origin development || bad "could not push the monorepo ignore rule"
echo local > "$mono/sub/.claude/settings.local.json"
WT_ACT=keep wtrun "$mono/sub" work 8 --worktree; check "monorepo run --worktree with include exit code" "$?" "0"
[ -f "$wd2/8/sub/.claude/settings.local.json" ] && [ ! -e "$wd2/8/.claude/settings.local.json" ] && ok \
  || bad "in a monorepo the include file was not copied under the harness root's place"

echo "UT-73 a worktree run carries only its issue number, and session import attributes each worktree's records to its run"
wtrun "$t" work 9 --worktree; check "run --worktree for the span exit code" "$?" "0"
wtrun "$t" work 9; check "run without --worktree for the span exit code" "$?" "0"
python3 - "$t.records/metrics" > "$work/wtspan.sum" <<'PY2'
import glob, json, sys
st = [json.loads(l) for f in sorted(glob.glob(sys.argv[1] + "/spans-*.jsonl")) for l in open(f)]
runs = [e["attrs"] for e in st if e["ev"] == "start" and e["name"] == "run/work" and e["attrs"].get("issue") == "9"]
print(len(runs), runs[0].get("worktree"), runs[1].get("worktree", "none"))
PY2
has "$work/wtspan.sum" "2 9 none" "the run span's worktree attribute is wrong (runs, with the flag, without)"
grep -rqF "wtrun-trees" "$t.records/metrics" && bad "a worktree path reached the spans" || ok
python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); sys.dont_write_bytecode = True; import metric; print(metric.clean_attrs(["worktree=../x", "issue=1"]), metric.clean_attrs(["worktree=12"]))' "$t/script" > "$work/wtattr.sum"
has "$work/wtattr.sum" "{'issue': '1'} {'worktree': '12'}" "metric.py does not keep only a numeric worktree attribute"
for wtcase in present removed; do
  ti="$work/wtimp-$wtcase"; setup "$ti"; wdi="$work/wtimp-$wtcase-trees"; cl="$work/wtimp-$wtcase-claude"; cx="$work/wtimp-$wtcase-codex"
  "$root/bin/harness" set --target "$ti" worktree.dir "$wdi" >/dev/null 2>&1
  [ "$wtcase" = present ] && mkdir -p "$wdi/7" "$wdi/8"
  python3 - "$ti" "$wdi" "$cl" "$cx" <<'PY2'
import datetime, json, os, re, sys
t, wd, cl, cx = sys.argv[1:5]
sys.path.insert(0, t + "/script"); sys.dont_write_bytecode = True
import metric
now = datetime.datetime.now(datetime.timezone.utc)
at = lambda m: now - datetime.timedelta(minutes=m)
ts = lambda m: at(m).strftime("%Y-%m-%dT%H:%M:%S.000Z")
for tr, vendor, wt in (("t-c7", "claude", "7"), ("t-c8", "claude", "8"), ("t-x7", "codex", "7"), ("t-x8", "codex", "8"), ("t-root", "claude", "")):
    attrs = {"workflow": "work", "vendor": vendor, **({"worktree": wt, "issue": wt} if wt else {})}
    _, run = metric.start("run/work", "command", attrs, trace=tr, parent="", source="runner", t=at(10))
    metric.end(run, "ok", 0, t=at(1))
def claude(path, n):
    d = os.path.join(cl, re.sub(r"[^A-Za-z0-9]", "-", path)); os.makedirs(d)
    open(d + "/s%d.jsonl" % n, "w").write(json.dumps({"type": "assistant", "sessionId": "s%d" % n, "timestamp": ts(5),
        "message": {"id": "m%d" % n, "model": "claude-x", "usage": {"input_tokens": n, "output_tokens": 0}}}) + "\n")
def codex(name, cwd, n):
    os.makedirs(cx, exist_ok=True)
    open(os.path.join(cx, "rollout-%s.jsonl" % name), "w").write("\n".join([
        json.dumps({"timestamp": ts(5), "type": "session_meta", "payload": {"id": name, "cwd": cwd}}),
        json.dumps({"timestamp": ts(5), "type": "token_usage_record", "payload": {"response_id": name, "usage": {"input_tokens": n, "output_tokens": 0}}})]) + "\n")
# 실행 디렉터리는 적힌 경로와 실제 경로 어느 쪽으로도 기록될 수 있다
claude(os.path.join(wd, "7"), 11)
claude(os.path.join(os.path.realpath(wd), "8"), 22)
codex("x7", os.path.join(wd, "7", "deeper"), 33)
codex("x8", os.path.join(os.path.realpath(wd), "8"), 44)
claude(os.path.realpath(t), 55)
codex("other", "/elsewhere", 66)
PY2
  HARNESS_CLAUDE_DIR="$cl" HARNESS_CODEX_DIR="$cx" "$root/bin/harness" metrics import --target "$ti" --since 1d > "$work/wtimp.json"
  check "metrics import with worktree runs ($wtcase)" "$?" "0"
  python3 - "$work/wtimp.json" "$HARNESS_HOME/my-project/state/import-cursor.json" "$cx" > "$work/wtimp.sum" <<'PY2'
import json, os, sys
d = json.load(open(sys.argv[1])); cur = json.load(open(sys.argv[2])); cx = sys.argv[3]
tok = {x["trace"]: x["tokens"] for x in d["traces"]}
other = lambda n: cur.get("codex:" + os.path.join(cx, "rollout-%s.jsonl" % n), {}).get("other")
print(tok.get("t-c7"), tok.get("t-c8"), tok.get("t-x7"), tok.get("t-x8"), tok.get("t-root"),
      d["diagnostics"]["imported"]["unattributed"], other("x7"), other("x8"), other("other"))
PY2
  has "$work/wtimp.sum" "11 22 33 44 55 0 False False True" "worktree records are not attributed to their own runs ($wtcase): c7 c8 x7 x8 root unattributed other-flags"
  rm -rf "$HARNESS_HOME/my-project/state"
done

echo "UT-74 doctor reports the issue worktrees left under worktree.dir with their state"
doc() { "$root/bin/harness" doctor --target "$1" > "$work/wtdoc.log" 2>&1; }
doc "$t"; has "$work/wtdoc.log" "no worktrees left" "doctor does not say no worktrees are left"
WT_ACT=edit wtrun "$t" work 1 --worktree
WT_ACT=commit wtrun "$t" work 2 --worktree
wtg "$t" worktree add -q --detach "$wd/3" origin/development && wtg "$t" worktree add -q --detach "$wd/4" origin/development \
  && wtg "$t" worktree add -q --detach "$work/wtoutside" origin/development || bad "could not make the doctor worktrees"
rm -rf "$wd/4"
doc "$t"
has "$work/wtdoc.log" "worktree 1  — uncommitted changes at $wd/1" "doctor does not report the worktree with uncommitted changes"
has "$work/wtdoc.log" "worktree 2  — unpushed commits at $wd/2" "doctor does not report the worktree with unpushed commits"
has "$work/wtdoc.log" "worktree 3  — clean at $wd/3 — rerun its workflow or remove it with \`git worktree remove\`" "doctor does not report the clean worktree"
has "$work/wtdoc.log" "worktree 4  — missing — run \`git worktree prune\`" "doctor does not report the missing worktree"
check "doctor reports each left worktree as a warning" "$(grep -c '^  warn worktree ' "$work/wtdoc.log")" "4"
hasnt "$work/wtdoc.log" "wtoutside" "doctor reported a worktree outside worktree.dir"
hasnt "$work/wtdoc.log" "no worktrees left" "doctor says no worktrees are left while some are"
grep -qi "ignore" "$work/wtdoc.log" && bad "doctor checks the worktree directory's gitignore" || ok
setup "$work/wt-base"
doc "$work/wt-base"; code=$?
hasnt "$work/wtdoc.log" "worktree" "doctor looked at worktrees outside a git repository"
hasnt "$work/wtdoc.log" "Traceback" "doctor failed outside a git repository"
"$root/bin/harness" set --target "$work/wt-base" worktree.dir "$work/base-trees" >/dev/null 2>&1
doc "$work/wt-base"; check "doctor's exit code outside a git repository does not depend on worktrees" "$?" "$code"

echo "UT-62 one project name points to one path: install refuses a name still in use elsewhere"
# 이름이 등록부의 키다. 같은 이름의 두 번째 클론이 등록을 덮으면 UI 와 실행 기록이 조용히 다른 리포를 가리킨다.
dup="$work/dup"; A="$dup/a/twin"; B="$dup/b/twin"
mkrepo() { rm -rf "$1"; mkdir -p "$1"; ( cd "$1" && git init -q . ); }
regpath() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("path", ""))' "$HARNESS_HOME/$1/project.json" 2>/dev/null || echo "(none)"; }
real() { ( cd "$1" && pwd -P ); }
n=0
inst() { n=$((n + 1)); "$1" install --target "$2" >"$work/dup-$n.out" 2>"$work/dup-$n.err"; }
fresh() { # A 를 twin 으로 설치하고, B 에 같은 이름의 설정만 둔다
  rm -rf "$dup" "$HARNESS_HOME"/twin*
  mkrepo "$A"; mkrepo "$B"
  inst "$root/bin/harness" "$A" || bad "could not install A"
  cp "$A/harness.toml" "$B/harness.toml"
  rA=$(real "$A"); rB=$(real "$B")
}

fresh
inst "$root/bin/harness" "$B"; check "same name at another path" "$?" "2"
has "$work/dup-$n.err" "error:" "the refusal is not an error line"
has "$work/dup-$n.err" "$rA" "the refusal does not name the registered path"
has "$work/dup-$n.err" "harness uninstall" "the refusal does not suggest uninstalling there"
has "$work/dup-$n.err" "project.name" "the refusal does not suggest renaming"
check "registry after the refusal" "$(regpath twin)" "$rA"
[ -e "$B/.harness" ] && bad "the refused install left .harness/" || ok
[ -e "$B/.ai/AI_AGENT.md" ] && bad "the refused install rendered" || ok

inst "$root/bin/harness" "$A"; check "reinstall at the same path" "$?" "0"
check "registry after the reinstall" "$(regpath twin)" "$rA"

sedi 's/^name = "twin"$/name = "twin-b"/' "$B/harness.toml"
inst "$root/bin/harness" "$B"; check "a second clone under another name" "$?" "0"
check "the first name keeps its path" "$(regpath twin)" "$rA"
check "the second name points to the clone" "$(regpath twin-b)" "$rB"

fresh
echo keep > "$HARNESS_HOME/twin/marker"
rm "$A/harness.toml"
inst "$root/bin/harness" "$B"; check "old path without a config" "$?" "0"
check "registry after taking over" "$(regpath twin)" "$rB"
has "$work/dup-$n.out" "which no longer holds this project" "the takeover was not reported"
[ -f "$HARNESS_HOME/twin/marker" ] && ok || bad "taking over removed the records under the name"

fresh
rm -rf "$A"
inst "$root/bin/harness" "$B"; check "old path gone" "$?" "0"
check "registry after the old path is gone" "$(regpath twin)" "$rB"

fresh
sedi 's/^name = "twin"$/name = "twin-renamed"/' "$A/harness.toml"
inst "$root/bin/harness" "$B"; check "old path now under another name" "$?" "0"
check "registry after the old path was renamed" "$(regpath twin)" "$rB"

fresh
printf 'this is = [not toml\n' >> "$A/harness.toml"
inst "$root/bin/harness" "$B"; check "old config unreadable" "$?" "2"
has "$work/dup-$n.err" "could not be read" "the refusal does not say the config could not be read"
has "$work/dup-$n.err" "$rA/harness.toml" "the refusal does not name the unreadable config"
check "registry after the unreadable refusal" "$(regpath twin)" "$rA"

# 권한으로 막힌 설정은 없는 설정이 아니다. root 는 권한을 무시하므로 이 두 경우를 만들 수 없다.
if [ "$(id -u)" != 0 ]; then
  fresh
  chmod 000 "$A/harness.toml"
  inst "$root/bin/harness" "$B"; check "old config without read permission" "$?" "2"
  has "$work/dup-$n.err" "could not be read" "a config without read permission was not refused as unreadable"
  check "registry after the permission refusal" "$(regpath twin)" "$rA"
  chmod 644 "$A/harness.toml"

  fresh
  chmod 000 "$A"
  inst "$root/bin/harness" "$B"; check "old path that cannot be searched" "$?" "2"
  has "$work/dup-$n.err" "could not be read" "a path that cannot be searched was taken over as stale"
  check "registry after the search-permission refusal" "$(regpath twin)" "$rA"
  chmod 755 "$A"
fi

# 같은 이름의 두 설치가 동시에 돌면 하나만 등록되고 다른 하나는 거부된다.
fresh
# 판에서 하네스 파일을 남긴 채 매니페스트만 지우면 그 파일이 사용자 파일로 보인다 — 판마다 빈 리포에서 시작한다
cp "$A/harness.toml" "$dup/twin.toml"
race=0; for i in 1 2 3 4 5; do
  rm -rf "$HARNESS_HOME"/twin*
  mkrepo "$A"; mkrepo "$B"; cp "$dup/twin.toml" "$A/harness.toml"; cp "$dup/twin.toml" "$B/harness.toml"
  "$root/bin/harness" install --target "$A" >"$work/race-a.out" 2>&1 & pa=$!
  "$root/bin/harness" install --target "$B" >"$work/race-b.out" 2>&1 & pb=$!
  wait "$pa"; ca=$?; wait "$pb"; cb=$?
  got=$(regpath twin)
  case "$ca $cb" in
    "0 2") [ "$got" = "$rA" ] || race=1 ;;
    "2 0") [ "$got" = "$rB" ] || race=1 ;;
    *) race=1 ;;
  esac
done
check "concurrent installs of one name: one succeeds, the other is refused" "$race" "0"

fresh
echo '{}' > "$HARNESS_HOME/twin/project.json"
inst "$root/bin/harness" "$B"; check "a registration without a path" "$?" "0"
check "registry after an empty registration" "$(regpath twin)" "$rB"

fresh
sedi 's/^name = "twin"$/name = "twin-new"/' "$A/harness.toml"
inst "$root/bin/harness" "$A"; check "reinstall under a new name" "$?" "0"
[ -e "$HARNESS_HOME/twin/project.json" ] && bad "the old name still points to the renamed repo" || ok
check "the new name points to the repo" "$(regpath twin-new)" "$rA"

# doctor 는 등록 상태를 보고만 한다. 경고는 두 가지이고 FAIL 은 없다.
regsec() { awk '/^registry$/{f=1; next} /^$/{f=0} f' "$1"; }
doc() { n=$((n + 1)); "$root/bin/harness" doctor --target "$1" >"$work/dup-$n.out" 2>"$work/dup-$n.err"; regsec "$work/dup-$n.out" > "$work/dup-reg-$n.txt"; }
fresh
doc "$A"
has "$work/dup-reg-$n.txt" "ok   registered as \`twin\`" "doctor: a registered repo is not ok"
grep -E "^(tools and connections|registry|git)$" "$work/dup-$n.out" | tr '\n' ' ' > "$work/dup-order.txt"
check "doctor: the registry section sits between tools and git" "$(cat "$work/dup-order.txt")" "tools and connections registry git "
# 등록하지 않은 채 생성물만 둔 같은 이름의 리포 — doctor 는 렌더된 리포에서 끝까지 돈다.
"$root/bin/harness" render --target "$B" >/dev/null 2>&1 || bad "could not render B"
cp "$HARNESS_HOME/twin/project.json" "$work/dup-before.json"
doc "$B"
has "$work/dup-reg-$n.txt" "warn \`twin\` is registered to another path" "doctor: another path is not a warning"
has "$work/dup-reg-$n.txt" "$rA" "doctor: the warning does not name the registered path"
hasnt "$work/dup-reg-$n.txt" "FAIL" "doctor: the registry section failed on another path"
cmp -s "$HARNESS_HOME/twin/project.json" "$work/dup-before.json" && ok || bad "doctor changed the registry"
rm "$HARNESS_HOME/twin/project.json"
doc "$A"
has "$work/dup-reg-$n.txt" "warn this repository is not registered" "doctor: a missing registration is not a warning"
hasnt "$work/dup-reg-$n.txt" "FAIL" "doctor: the registry section failed on a missing registration"
[ -e "$HARNESS_HOME/twin/project.json" ] && bad "doctor registered the repo" || ok

# 같은 리포의 linked worktree 는 같은 프로젝트다. 같은 리포의 다른 서브디렉터리는 아니다.
fresh
rm "$B/harness.toml"
git -C "$A" add -A && git -C "$A" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.invalid commit -q -m init \
  && git -C "$A" worktree add -q -b side "$dup/a/twin-wt" || bad "could not set up the linked worktree"
doc "$dup/a/twin-wt"
has "$work/dup-reg-$n.txt" "ok   registered as \`twin\`" "doctor: a linked worktree of the registered repo is not ok"
hasnt "$work/dup-reg-$n.txt" "warn" "doctor: a linked worktree of the registered repo warned"
mkdir -p "$A/sub"; cp "$A/harness.toml" "$A/sub/harness.toml"
"$root/bin/harness" render --target "$A/sub" >/dev/null 2>&1 || bad "could not render the subdirectory"
doc "$A/sub"
has "$work/dup-reg-$n.txt" "warn \`twin\` is registered to another path" "doctor: another subdirectory of the same repo is not a warning"
unset -f regsec doc

# 소스 리포 분기도 옛 사본을 걷어내기 전에 같은 판정을 거친다.
rm -rf "$HARNESS_HOME"/srcdup
for s in "$dup/s1/srcdup" "$dup/s2/srcdup"; do
  rm -rf "$s"; mkdir -p "$s/src/bin"
  cp "$root/bin/harness" "$root/bin/harness_metrics.py" "$s/src/bin/"; cp -R "$root/templates" "$s/src/templates"
  ( cd "$s" && git init -q . )
done
s2="$dup/s2/srcdup"
inst "$dup/s1/srcdup/src/bin/harness" "$dup/s1/srcdup"; check "first source tree install" "$?" "0"
mkdir -p "$s2/.harness/bin"; echo 0.0.1 > "$s2/.harness/VERSION"
inst "$s2/src/bin/harness" "$s2"; check "second source tree under the same name" "$?" "2"
[ -d "$s2/.harness/bin" ] && [ -f "$s2/.harness/VERSION" ] && ok || bad "the refused source install cleared the old copy"
[ -e "$s2/.ai/AI_AGENT.md" ] && bad "the refused source install rendered" || ok

cat "$work"/dup-*.out "$work"/dup-*.err > "$work/dup.log"
python3 - "$work/dup.log" > "$work/dup.hits" <<'HANGUL'
import re, sys
for n, line in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
    if re.search(r"[가-힣]", line):
        print(f"{n}: {line.rstrip()}")
HANGUL
if [ -s "$work/dup.hits" ]; then
  bad "Korean is in the registry output"
  head -3 "$work/dup.hits" >&2
else
  ok
fi
unset -f mkrepo regpath real inst fresh

echo "UT-75 the permission allow list: managed scripts, the configured forge's commands and git"
t="$work/allow"; setup "$t"
# rules <settings.json> <allow|deny> — 규칙을 한 줄에 하나씩
rules() { python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["permissions"][sys.argv[2]]))' "$1" "$2"; }
rules "$t/.claude/settings.json" allow > "$work/allow.txt"
rules "$t/.claude/settings.json" deny > "$work/deny.txt"
[ -s "$work/allow.txt" ] && ok || bad "the allow list is empty"
[ -s "$work/deny.txt" ] && ok || bad "the deny list is empty"
# 대상 스크립트는 테스트에 적지 않고 설치된 script/ 에서 센다
n=0
for f in "$t"/script/*.sh "$t"/script/*.py; do
  [ -f "$f" ] || continue
  b=$(basename "$f")
  case "$b" in _*|rollback-work.sh|create-carryover-issue.sh|forge-selftest.sh|forge-setup.sh|harness-verify.sh|forge.sh) continue ;; esac
  n=$((n + 1))
  grep -qxF "Bash(script/$b:*)" "$work/allow.txt" && ok || bad "the managed script $b is not allowed"
done
[ "$n" -gt 0 ] && ok || bad "no installed managed script was counted"
for b in rollback-work.sh create-carryover-issue.sh forge-selftest.sh forge-setup.sh; do
  [ -f "$t/script/$b" ] || bad "the excluded script $b is not installed, so its absence proves nothing"
  hasnt "$work/allow.txt" "script/$b" "the irreversible script $b is allowed"
done
grep -qxF "Bash(script/sync-task-issues.sh:*)" "$work/allow.txt" && ok || bad "sync-task-issues.sh is not allowed"
hasnt "$work/allow.txt" "Bash(script/*" "a glob rule over script/ is allowed"
hasnt "$work/allow.txt" "script/project/" "a project script is allowed"
hasnt "$work/allow.txt" "script/harness-verify.sh" "the generated verify script is allowed"
hasnt "$work/allow.txt" "script/forge.sh" "the generated forge adapter is allowed"
hasnt "$work/allow.txt" "script/_review.py" "a module script is allowed"
hasnt "$work/allow.txt" "script/hooks/" "a hook script is allowed"
grep -qxF "Bash(git switch -c:*)" "$work/allow.txt" && ok || bad "git switch -c is not allowed"
grep -qxF "Bash(git commit:*)" "$work/allow.txt" && ok || bad "git commit is not allowed"
hasnt "$work/allow.txt" "Bash(git push" "git push is allowed by default"
grep -qxF "Bash(glab mr view:*)" "$work/allow.txt" && ok || bad "glab mr view is not allowed on gitlab"
hasnt "$work/allow.txt" "Bash(gh " "a github command is allowed on gitlab"
has "$t/.ai/forge.md" "issue create" "the command reference no longer names issue creation, so the next check proves nothing"
hasnt "$work/allow.txt" "issue create" "issue creation is allowed"
check "allow rules are unique" "$(sort "$work/allow.txt" | uniq -d)" ""
# 같은 설정의 두 번째 렌더는 같은 파일을 낸다
cp "$t/.claude/settings.json" "$work/allow-first.json"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
cmp -s "$t/.claude/settings.json" "$work/allow-first.json" && ok || bad "a second render changed .claude/settings.json"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after the allow list render" "$?" "0"

# forge 를 따라간다
t="$work/allow-forge"; setup "$t"
sedi 's/^tracker = "gitlab"$/tracker = "jira"/; s/^review_host = "gitlab"$/review_host = "github"/' "$t/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "render with jira and github" "$?" "0"
rules "$t/.claude/settings.json" allow > "$work/allow-forge.txt"
grep -qxF "Bash(jira issue view:*)" "$work/allow-forge.txt" && ok || bad "jira issue view is not allowed with a jira tracker"
grep -qxF "Bash(gh pr view:*)" "$work/allow-forge.txt" && ok || bad "gh pr view is not allowed with a github review host"
hasnt "$work/allow-forge.txt" "glab" "a gitlab command is allowed with jira and github"
hasnt "$work/allow-forge.txt" "gh issue" "the github tracker commands are allowed when github only hosts review"
check "gh api rules" "$(grep -F "Bash(gh api" "$work/allow-forge.txt")" 'Bash(gh api repos/{owner}/{repo}/pulls/*/comments/*/replies:*)'

# push 를 허용해도 보호 브랜치 deny 는 그대로다
t="$work/allow"
"$root/bin/harness" set --target "$t" permissions.allow_push true >/dev/null 2>&1; check "set permissions.allow_push true" "$?" "0"
rules "$t/.claude/settings.json" allow > "$work/allow-push.txt"
rules "$t/.claude/settings.json" deny > "$work/deny-push.txt"
grep -qxF "Bash(git push:*)" "$work/allow-push.txt" && ok || bad "git push is not allowed with allow_push = true"
cmp -s "$work/deny.txt" "$work/deny-push.txt" && ok || bad "allowing push changed the deny list"
for br in main development; do
  grep -qxF "Bash(git push origin $br)" "$work/deny-push.txt" && ok || bad "the push to $br is no longer denied"
  grep -qxF "Bash(git push*refs/heads/$br*)" "$work/deny-push.txt" && ok || bad "the refspec push to $br is no longer denied"
done
for r in "Bash(git push --force:*)" "Bash(git push -f:*)" "Bash(git push --force-with-lease:*)" "Bash(git push origin +*)" \
         "Bash(git push --no-verify:*)" "Bash(git commit --no-verify:*)"; do
  grep -qxF "$r" "$work/deny-push.txt" && ok || bad "$r is no longer denied"
done

# 절이 없는 옛 설정은 기본값으로 돌고, set 이 절을 더한다
t="$work/allow-old"; setup "$t"
python3 - "$t/harness.toml" <<'PY'
import re, sys; p = sys.argv[1]; s = open(p).read()
s, n = re.subn(r'^\[permissions\]\n(?:(?!\[).*\n)*', '', s, flags=re.M)
assert n == 1 and "[permissions]" not in s and "allow_push" not in s
open(p, "w").write(s)
PY
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "render without a permissions section" "$?" "0"
hasnt "$t/.claude/settings.json" '"Bash(git push:*)"' "git push is allowed without a permissions section"
"$root/bin/harness" set --target "$t" permissions.allow_push true >/dev/null 2>&1; check "set allow_push without a permissions section" "$?" "0"
has "$t/harness.toml" "[permissions]" "set did not add the permissions section"
has "$t/harness.toml" "allow_push = true" "set did not add allow_push"
has "$t/.claude/settings.json" '"Bash(git push:*)"' "git push is not allowed after set added the section"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after set added the section" "$?" "0"

# 성립하지 않는 값은 거부한다
t="$work/allow-cfg"; setup "$t"; cp "$t/harness.toml" "$work/allow-cfg.orig"
prender() { "$root/bin/harness" render --target "$t" > "$work/allow-cfg.log" 2>&1; }
sedi 's/^allow_push = false$/allow_push = false\
allow_merge = true/' "$t/harness.toml"
prender; check "render with an unknown permissions key" "$?" "2"
has "$work/allow-cfg.log" "unknown key(s) in [permissions]: allow_merge" "the unknown permissions key is not named"
has "$work/allow-cfg.log" "the keys are allow_push" "the permissions keys are not listed"
for v in '"true"' '1'; do
  cp "$work/allow-cfg.orig" "$t/harness.toml"
  sedi "s/^allow_push = false\$/allow_push = $v/" "$t/harness.toml"
  grep -qxF "allow_push = $v" "$t/harness.toml" || bad "could not write allow_push = $v"
  prender; check "render with allow_push = $v" "$?" "2"
  has "$work/allow-cfg.log" "permissions.allow_push must be true or false" "allow_push = $v is not refused by name"
done
cp "$work/allow-cfg.orig" "$t/harness.toml"
unset -f prender

# 선언 파일과 제외 목록의 오류는 하네스 사본에서 만든다 — 소스 템플릿은 건드리지 않는다
hc="$work/allow-copy"; rm -rf "$hc"; mkdir -p "$hc/bin"
cp "$root/bin/harness" "$root/bin/harness_metrics.py" "$hc/bin/"; cp -R "$root/templates" "$hc/templates"
t="$work/allow-bad"; setup "$t"
arender() { "$hc/bin/harness" render --target "$t" > "$work/allow-bad.log" 2>&1; }
arender; check "render from the harness copy" "$?" "0"
decl="$hc/templates/forge/gitlab/allow.toml"
cp "$decl" "$work/allow-decl.orig"
rm "$decl"
arender; check "render without the tracker forge's allow list" "$?" "2"
has "$work/allow-bad.log" "no permission list for this forge" "the missing allow list is not named"
has "$work/allow-bad.log" "$decl" "the missing allow list's path is not shown"
for item in '"glab mr view:*"' '"Bash(glab mr view)"' '""' '" glab mr view"'; do
  printf 'tracker = [%s]\nreview = ["glab mr view"]\n' "$item" > "$decl"
  arender; check "render with the allow item $item" "$?" "2"
  has "$work/allow-bad.log" "tracker[1] is not a command prefix" "the bad allow item $item is not named"
done
printf 'tracker = "glab issue view"\nreview = ["glab mr view"]\n' > "$decl"
arender; check "render with a string tracker list" "$?" "2"
has "$work/allow-bad.log" '`tracker` must be a list of command prefixes' "the string tracker list is not named"
printf 'review = ["glab mr view"]\n' > "$decl"
arender; check "render without the tracker key" "$?" "2"
has "$work/allow-bad.log" '`tracker` must be a list of command prefixes' "the missing tracker key is not named"
printf 'tracker = ["glab issue view"]\nreview = ["glab mr view"]\nmerge = ["glab mr merge"]\n' > "$decl"
arender; check "render with an unknown allow key" "$?" "2"
has "$work/allow-bad.log" "unknown key(s): merge" "the unknown allow key is not named"
has "$work/allow-bad.log" "the keys are tracker, review" "the allow keys are not listed"
cp "$work/allow-decl.orig" "$decl"
rm "$hc/templates/managed/script/rollback-work.sh"
arender; check "render with an exclusion that is not shipped" "$?" "2"
has "$work/allow-bad.log" "permission exclusion names a script that is not shipped: rollback-work.sh" "the unshipped exclusion is not named"
unset -f rules arender

echo "UT-76 UI server decisions: the build hash, the server record, the process match and the server state"
# 판정 함수를 CLI 에서 불러 직접 부른다. 해시 대상 트리는 임시 디렉터리에만 만든다.
python3 - "$root/bin/harness" "$work/uitree" > "$work/uistate.out" 2>&1 <<'PY'
import importlib.machinery, importlib.util, json, sys
from pathlib import Path

loader = importlib.machinery.SourceFileLoader("harness_cli", sys.argv[1])
spec = importlib.util.spec_from_loader("harness_cli", loader)
h = importlib.util.module_from_spec(spec)
loader.exec_module(h)

def expect(name, actual, wanted):
    print("ok" if actual == wanted else "bad %s — expected %r, actual %r" % (name, wanted, actual))

ui = Path(sys.argv[2])
files = ["package.json", "package-lock.json", "jsconfig.json", "next.config.js",
         "app/page.js", "app/[project]/layout.js", "components/Nav.js", "lib/harness.js",
         "skills/a/SKILL.md", "app/.hidden.js", "app/.cache/x.js"]
for rel in files:
    (ui / rel).parent.mkdir(parents=True, exist_ok=True)
    (ui / rel).write_text("v1 " + rel, encoding="utf-8")

base = h.ui_source_hash(ui)
expect("the hash is the same for the same tree", h.ui_source_hash(ui), base)
expect("the hash is a SHA-256 hex string", len(base), 64)
for rel in ["package.json", "package-lock.json", "jsconfig.json", "next.config.js",
            "app/page.js", "app/[project]/layout.js", "components/Nav.js", "lib/harness.js"]:
    old = (ui / rel).read_text(encoding="utf-8")
    (ui / rel).write_text(old + " changed", encoding="utf-8")
    print("ok" if h.ui_source_hash(ui) != base else "bad changing %s does not change the hash" % rel)
    (ui / rel).write_text(old, encoding="utf-8")
expect("restoring the files restores the hash", h.ui_source_hash(ui), base)
for rel in ["skills/a/SKILL.md", "app/.hidden.js", "app/.cache/x.js"]:
    old = (ui / rel).read_text(encoding="utf-8")
    (ui / rel).write_text("changed", encoding="utf-8")
    expect("changing %s leaves the hash alone" % rel, h.ui_source_hash(ui), base)
    (ui / rel).write_text(old, encoding="utf-8")
(ui / "skills/b").mkdir(parents=True)
(ui / "skills/b/new.md").write_text("x", encoding="utf-8")
expect("a new file under skills/ leaves the hash alone", h.ui_source_hash(ui), base)
(ui / "lib/new.js").write_text("x", encoding="utf-8")
print("ok" if h.ui_source_hash(ui) != base else "bad a new file under lib/ does not change the hash")

expect("no build when the stamp matches and the build exists", h.needs_build(base, base + "\n", True), False)
expect("a build when there is no stamp", h.needs_build(base, None, True), True)
expect("a build when the stamp differs", h.needs_build(base, "0" * 64, True), True)
expect("a build when BUILD_ID is missing", h.needs_build(base, base, False), True)

good = {"pid": 4242, "started": "Tue Sep 29 10:00:00 2026", "root": "/opt/ui", "hash": "abc", "port": 7777}
expect("a well-formed record parses", h.parse_server_record(json.dumps(good)), good)
bad_records = {"not JSON": "pid=4242", "an array": "[1, 2]", "a JSON string": '"x"'}
for key in good:
    bad_records["no %s" % key] = json.dumps({k: v for k, v in good.items() if k != key})
for label, value in [("pid", 0), ("pid", 1), ("pid", -5), ("pid", True), ("pid", "123"), ("pid", 4.0),
                     ("port", 0), ("port", 70000), ("port", True), ("root", ""), ("started", ""), ("hash", 7)]:
    bad_records["%s %r" % (label, value)] = json.dumps(dict(good, **{label: value}))
for name, text in bad_records.items():
    expect("a record with %s is unreadable" % name, h.parse_server_record(text), None)

expect("the group id and start time match", h.process_matches(good, "  4242 Tue Sep 29 10:00:00 2026  \n"), True)
expect("empty ps output does not match", h.process_matches(good, ""), False)
expect("another group id does not match", h.process_matches(good, "4243 Tue Sep 29 10:00:00 2026\n"), False)
expect("another start time does not match", h.process_matches(good, "4242 Tue Sep 29 10:00:01 2026\n"), False)

def st(record, matches, port_busy, http_ok, root="/opt/ui", hash_="abc"):
    return h.server_state(record, matches, root, hash_, port_busy, http_ok)
expect("a matching record from another root is another copy", st(good, True, True, True, root="/other"), "other-copy")
expect("a matching record with another hash is another build", st(good, True, True, True, hash_="def"), "other-build")
expect("a matching record that responds is running", st(good, True, True, True), "running")
expect("a matching record that does not respond is unresponsive", st(good, True, True, False), "unresponsive")
expect("no record and a busy port is busy", st(None, False, True, False), "busy")
expect("no record and a free port is free", st(None, False, False, False), "free")
expect("a stale record and a busy port is busy", st(good, False, True, False, root="/other", hash_="def"), "busy")
expect("a stale record and a free port is free", st(good, False, False, False, root="/other", hash_="def"), "free")
expect("a response alone is not a harness server", st(None, False, True, True), "busy")
expect("another copy that responds is still another copy", st(good, True, True, True, root="/other"), "other-copy")
PY
[ "$?" -eq 0 ] || bad "the UI server decision checks did not run: $(tail -3 "$work/uistate.out")"
while IFS= read -r line; do
  case "$line" in
    ok) ok ;;
    "bad "*) bad "${line#bad }" ;;
    *) bad "unexpected output from the UI server decision checks: $line" ;;
  esac
done < "$work/uistate.out"

echo "UT-77 doctor collects its checks into one list; the text and status are drawn from it"
# forge CLI 와 리뷰어 러너는 PATH 앞의 빈 스텁이다 — 기기에 깔린 실제 CLI 를 부르지 않는다.
stub59="$work/stub59"; mkdir -p "$stub59"
for c in gh codex; do printf '#!/bin/sh\nexit 0\n' > "$stub59/$c"; chmod +x "$stub59/$c"; done
ready() { # ready <대상> — FAIL 없이 경고만 남는 git 리포 하나를 만든다
  setup "$1"
  "$root/bin/harness" set --target "$1" forge.tracker github forge.review_host github commands.test true >/dev/null 2>&1 \
    || bad "$1: could not configure the ready repo"
  ( cd "$1" && git init -q -b development . && git add -A && git -c user.email=t@t -c user.name=t commit -qm init \
    && git config core.hooksPath script/githooks ) || bad "$1: could not commit the ready repo"
}
doc_lines() { # doc_lines <doctor 텍스트> <JSON 파일> <status|doctor> — 텍스트의 항목 줄과 JSON 의 항목을 견준다
  python3 - "$@" <<'PY'
import json, re, sys
text, data, kind = sys.argv[1:4]
items, sec = [], ""
for ln in open(text, encoding="utf-8").read().splitlines():
    m = re.match(r"  (ok  |warn|FAIL) (.+?)(?:  — (.*))?$", ln)
    if m:
        items.append({"section": sec, "state": {"ok  ": "ok", "warn": "warn", "FAIL": "bad"}[m.group(1)],
                      "what": m.group(2), "detail": m.group(3) or ""})
    elif ln and not ln.startswith(" "):
        sec = ln
d = json.load(open(data, encoding="utf-8"))
d = d["doctor"] if kind == "status" else d
print(items == d["items"], len(items) > 0, d["bad"] == sum(i["state"] == "bad" for i in items),
      d["warn"] == sum(i["state"] == "warn" for i in items))
PY
}
no_hangul() { # no_hangul <파일> <설명> — 터미널 출력에 한글이 없는지 본다
  python3 - "$1" > "$1.hits" <<'HANGUL'
import re, sys
for n, line in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
    if re.search(r"[가-힣]", line):
        print(f"{n}: {line.rstrip()}")
HANGUL
  if [ -s "$1.hits" ]; then bad "Korean is in $2: $(head -1 "$1.hits")"; else ok; fi
}
t="$work/doclist"; setup "$t"
PATH="$stub59:$PATH" "$root/bin/harness" doctor --target "$t" > "$work/dl.txt" 2>&1; check "doctor with failures exits 1" "$?" "1"
PATH="$stub59:$PATH" "$root/bin/harness" status --target "$t" > "$work/dl.json" 2>&1; check "status exits 0" "$?" "0"
grep -q '^  FAIL ' "$work/dl.txt" && grep -q '^  warn ' "$work/dl.txt" && ok || bad "the mixed repo does not have both failures and warnings"
check "status items are the doctor text lines, in order" "$(doc_lines "$work/dl.txt" "$work/dl.json" status)" "True True True True"
no_hangul "$work/dl.txt" "doctor output"
python3 - "$work/dl.json" > "$work/dl.keys" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(sorted(d), sorted(d["doctor"]), sorted({tuple(sorted(i)) for i in d["doctor"]["items"]}), sorted(d["facts"]))
PY
check "status keys stay the same" "$(cat "$work/dl.keys")" \
  "['check_ok', 'custom', 'doctor', 'facts', 'git', 'version'] ['bad', 'items', 'warn'] [('detail', 'section', 'state', 'what')] ['filled', 'total']"
printf '# stack\n\nPython 3.11\n' > "$t/.ai/project/stack.md"
"$root/bin/harness" status --target "$t" | python3 -c 'import json,sys; d=json.load(sys.stdin)["facts"]; print(d["total"], d["filled"])' > "$work/dl.facts"
check "a filled fact counts toward the progress" "$(cat "$work/dl.facts")" "7 1"
t="$work/docready"; ready "$t"
PATH="$stub59:$PATH" "$root/bin/harness" doctor --target "$t" > "$work/dr.txt" 2>&1; check "doctor without failures exits 0" "$?" "0"
grep -q '^  FAIL ' "$work/dr.txt" && bad "the ready repo still fails: $(grep '^  FAIL ' "$work/dr.txt" | head -1)" || ok
# 수집 함수는 표준 출력에 쓰지 않는다
python3 - "$root/bin/harness" "$t" > "$work/dl.quiet" 2>&1 <<'PY'
import contextlib, importlib.machinery, importlib.util, io, sys
from pathlib import Path
loader = importlib.machinery.SourceFileLoader("harness_cli", sys.argv[1])
spec = importlib.util.spec_from_loader("harness_cli", loader)
h = importlib.util.module_from_spec(spec); loader.exec_module(h)
target = Path(sys.argv[2]).resolve()
cfg = h.load(target); h.normalize(cfg); h.validate(cfg)
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    items = h.doctor_items(cfg, target, False)
print(repr(buf.getvalue()), len(items) > 0, [i["section"] for i in items][0], [i["section"] for i in items][-1])
PY
check "the collection writes nothing to standard output" "$(cat "$work/dl.quiet")" "'' True config git"

echo "UT-78 doctor --json prints the same items as one JSON object, with the same exit code"
t="$work/doclist"
PATH="$stub59:$PATH" "$root/bin/harness" doctor --target "$t" > "$work/dj.txt" 2>/dev/null; rc_text=$?
PATH="$stub59:$PATH" "$root/bin/harness" doctor --json --target "$t" > "$work/dj.json" 2>/dev/null; rc_json=$?
check "text and JSON exit codes match where something fails" "$rc_json:$rc_text" "1:1"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(sorted(d))' "$work/dj.json" > "$work/dj.keys" 2>&1
check "standard output is one JSON object" "$(cat "$work/dj.keys")" "['bad', 'items', 'warn']"
check "each JSON item is one text line, and the counts match" "$(doc_lines "$work/dj.txt" "$work/dj.json" doctor)" "True True True True"
PATH="$stub59:$PATH" "$root/bin/harness" status --target "$t" > "$work/dj.status" 2>/dev/null
python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["doctor"] == json.load(open(sys.argv[2])))' "$work/dj.status" "$work/dj.json" > "$work/dj.same"
check "status carries what doctor --json prints" "$(cat "$work/dj.same")" "True"
no_hangul "$work/dj.json" "doctor --json output"
t="$work/docready"
PATH="$stub59:$PATH" "$root/bin/harness" doctor --target "$t" > /dev/null 2>&1; rc_text=$?
PATH="$stub59:$PATH" "$root/bin/harness" doctor --json --target "$t" > "$work/dj.ready" 2>/dev/null; rc_json=$?
check "text and JSON exit codes match where nothing fails" "$rc_json:$rc_text" "0:0"
python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["bad"])' "$work/dj.ready" > "$work/dj.bad" 2>&1
check "the ready repo has no failing item" "$(cat "$work/dj.bad")" "0"
"$root/bin/harness" help > "$work/dj.help" 2>&1
grep -E '^  harness doctor .*\[--json\]' "$work/dj.help" >/dev/null && ok || bad "help does not list --json for doctor"
# 고정 사본이 있는 대상에서는 전역 CLI 가 인자를 그대로 넘긴다
t="$work/pinjson"; rm -rf "$t"; mkdir -p "$t"; ( cd "$t" && git init -q )
"$root/bin/harness" install --target "$t" >/dev/null 2>&1 || bad "could not install the pinned repo"
[ -x "$t/.harness/bin/harness" ] && ok || bad "install did not pin a copy"
"$root/bin/harness" doctor --json --target "$t" > "$work/dj.pin" 2>/dev/null; rc_glob=$?
"$t/.harness/bin/harness" doctor --target "$t" > /dev/null 2>&1; rc_pin=$?
python3 -c 'import json,sys; print(sorted(json.load(open(sys.argv[1]))))' "$work/dj.pin" > "$work/dj.pinkeys" 2>&1
check "the delegated doctor --json prints one JSON object" "$(cat "$work/dj.pinkeys")" "['bad', 'items', 'warn']"
check "the delegated exit code is the pinned copy's" "$rc_glob" "$rc_pin"
"$root/bin/harness" uninstall --target "$t" >/dev/null 2>&1

echo "UT-79 placeholders and unverified adapters are judged by their markers only"
t="$work/markers"; setup "$t"
item() { # item <대상> <what> — doctor --json 에서 그 항목의 state 와 detail
  "$root/bin/harness" doctor --json --target "$1" 2>/dev/null | python3 -c '
import json, sys
hit = [i for i in json.load(sys.stdin)["items"] if i["what"] == sys.argv[1]]
print("%s|%s" % (hit[0]["state"], hit[0]["detail"]) if hit else "none")' "$2"
}
printf '# stack\n\nTBD 라는 낱말은 본문에 남아도 된다. Python 3.11\n' > "$t/.ai/project/stack.md"
check "the word TBD alone is not a placeholder" "$(item "$t" .ai/project/stack.md)" "ok|"
printf '# stack\n\n- 언어 <!-- TBD: 확인 필요 -->\n- 버전 <!-- TBD -->\n- TBD\n' > "$t/.ai/project/stack.md"
check "two placeholders are counted" "$(item "$t" .ai/project/stack.md)" "warn|2 placeholder(s) still to fill"
a="$t/script/forge/gitlab.sh"; cp "$a" "$work/markers.adapter"
check "a header marker leaves the adapter unverified" "$(item "$t" 'adapter `gitlab`')" "warn|unverified — run \`script/forge-selftest.sh\`"
grep -v '검증 상태: 미검증' "$work/markers.adapter" > "$a"; printf '\n# 이 분기는 아직 미검증이다\n' >> "$a"
check "unverified in a body comment is not the marker" "$(item "$t" 'adapter `gitlab`')" "ok|"
{ sed -n '1,2p' "$work/markers.adapter"; printf '\n# 검증 상태: 미검증\n'; sed -n '3,$p' "$work/markers.adapter" | grep -v '검증 상태: 미검증'; } > "$a"
check "the marker after the first comment block is not the header" "$(item "$t" 'adapter `gitlab`')" "ok|"
cp "$work/markers.adapter" "$a"
grep -c 'ADAPTER_UNVERIFIED = "검증 상태: 미검증"' "$root/bin/harness" > "$work/markers.const"
check "the header marker is one constant in the CLI" "$(cat "$work/markers.const")" "1"
check "the marker string appears once in the CLI" "$(grep -c '검증 상태: 미검증' "$root/bin/harness")" "1"
has "$root/templates/managed/script/forge/_common.sh" '머리글의 `검증 상태:` 줄이 검증 상태의 표지다' "the adapter contract does not name the header marker"
unset -f item

echo "UT-80 run-agent.py --check reports whether a CLI runner is installed and signed in, without running it"
d="$work/racheck"; rm -rf "$d"; mkdir -p "$d/script" "$d/bin"
cp "$root/templates/managed/script/run-agent.py" "$root/templates/managed/script/metric.py" "$d/script/"
cat > "$d/bin/codex" <<'SH'
#!/bin/sh
echo "$*" >> "$CODEX_CALLS"
echo "ACCOUNT-MARK-59"; echo "ACCOUNT-MARK-59" >&2
exit "${CODEX_LOGIN_EXIT:-0}"
SH
printf '#!/nonexistent/interpreter-59\n' > "$d/bin/brokencodex"; chmod +x "$d/bin/codex" "$d/bin/brokencodex"
python3 - "$d" <<'PY'
import json, sys
d = sys.argv[1]
def cli(exe, auth):
    return {"via": "headless", "vendor": "codex", "exe": exe, "argv": [exe, "exec"], "output": "stdout", "model": "",
            "usage_format": [], "usage_parser": "", "auth_check": auth, "auth_timeout": 30, "entry": "script/run-agent.py"}
plan = {"roles": {"rev": cli("codex", ["codex", "login", "status"]), "noauth": cli("codex", []),
                  "sub": {"via": "subagent", "vendor": "claude"},
                  "ghost": cli("nosuch-cli-59", ["nosuch-cli-59", "login"]),
                  "broken": cli("brokencodex", ["brokencodex", "login", "status"])},
        "metrics": {"dir": d + "/metrics", "retention_days": 30, "max_file_mb": 10, "max_total_mb": 100,
                    "stale_after_hours": 6, "capture_logs": "errors"}}
json.dump(plan, open(d + "/script/harness.plan.json", "w"))
PY
export CODEX_CALLS="$d/calls"
rac() { # rac <이름> <역할> [인자...] — 표준 출력·표준 오류를 따로 받는다
  local n="$1"; shift
  PATH="$d/bin:$PATH" python3 "$d/script/run-agent.py" "$@" > "$d/$n.out" 2> "$d/$n.err"
}
: > "$CODEX_CALLS"
rac in rev --check; check "signed in exits 0" "$?" "0"
check "signed in prints signed-in" "$(cat "$d/in.out")" "signed-in"
check "the sign-in command is the plan's" "$(cat "$CODEX_CALLS")" "login status"
CODEX_LOGIN_EXIT=1 rac out rev --check; check "not signed in exits 3" "$?" "3"
has "$d/out.err" "error: codex is not signed in (\`codex login status\` failed)" "not signed in does not say so"
cat "$d/out.out" "$d/out.err" > "$d/out.all"; hasnt "$d/out.all" "ACCOUNT-MARK-59" "the sign-in command's output was passed on"
: > "$CODEX_CALLS"
rac un noauth --check; check "no sign-in command exits 0" "$?" "0"
check "no sign-in command prints unchecked" "$(cat "$d/un.out")" "unchecked"
check "no sign-in command runs nothing" "$(cat "$CODEX_CALLS")" ""
rac sub sub --check; check "a subagent role cannot be checked" "$?" "2"
has "$d/sub.err" "error: " "a subagent role does not say error"
rac ghost ghost --check; check "a CLI not on PATH exits 2" "$?" "2"
has "$d/ghost.err" "error: nosuch-cli-59 is not installed" "a missing CLI does not say so"
rac broken broken --check; check "a sign-in command that cannot start exits 4" "$?" "4"
has "$d/broken.err" "error: could not check sign-in for codex" "a command that cannot start does not say so"
[ -e "$d/metrics" ] && bad "--check left metrics behind" || ok
rac out2 rev --check --out "$d/never.txt" --prompt x extra; check "--check with other arguments only checks" "$?" "0"
check "--check with other arguments prints only the check" "$(cat "$d/out2.out")" "signed-in"
[ -e "$d/never.txt" ] && bad "--check wrote the --out file" || ok
[ -e "$d/metrics" ] && bad "--check with other arguments left metrics behind" || ok
rac run rev x; check "a run without --check still runs the CLI" "$?" "0"
ls "$d/metrics"/spans-*.jsonl >/dev/null 2>&1 && ok || bad "a run without --check left no span"
mv "$d/script/harness.plan.json" "$d/plan.bak"
rac noplan rev --check; check "no plan exits 2" "$?" "2"
mv "$d/plan.bak" "$d/script/harness.plan.json"
cat "$d"/*.out "$d"/*.err > "$d/all.log"; no_hangul "$d/all.log" "run-agent.py --check output"
unset CODEX_CALLS; unset -f rac
t="$work/authplan"; setup "$t"
"$root/bin/harness" set --target "$t" roles.planner.runner codex >/dev/null 2>&1
python3 -c 'import json,sys; r=json.load(open(sys.argv[1]))["roles"]; print(r["planner"]["auth_check"], r["developer"].get("auth_check", "none"))' "$t/script/harness.plan.json" > "$work/authplan.sum" 2>&1
check "a codex runner carries its sign-in command in the plan" "$(cat "$work/authplan.sum")" "['codex', 'login', 'status'] none"
authdecl() { # authdecl <이름> <codex 의 auth_check 값> — 그 선언으로 렌더가 멈추는지
  local h="$work/auth-$1"
  rm -rf "$h"; mkdir -p "$h"; cp -R "$root/bin" "$root/templates" "$h/"
  python3 - "$h/templates/vendors.toml" "$2" <<'PY'
import re, sys
p, val = sys.argv[1:3]
s = open(p, encoding="utf-8").read()
s, n = re.subn(r'(?m)^auth_check = \["codex".*$', "auth_check = " + val, s)
assert n == 1
open(p, "w", encoding="utf-8").write(s)
PY
  "$h/bin/harness" render --target "$t" > "$h.out" 2>&1
  check "render stops on auth_check $1" "$?" "2"
  has "$h.out" "vendor \`codex\` auth_check must be a non-empty list of strings starting with its exe" "auth_check $1 is not named"
}
authdecl other-exe '["claude", "login", "status"]'
authdecl empty '[]'
authdecl not-strings '["codex", 1]'
authdecl not-a-list '"codex login status"'
unset -f authdecl

echo "UT-81 the forge read functions for the remote checks, and the self-test that holds adapters to them"
t="$work/selftest59"; rm -rf "$t"; mkdir -p "$t"; ( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null 2>&1 || bad "could not install the self-test repo"
cp "$root/test/fake-forge.sh" "$t/script/forge.sh"
fst59="$work/fake-state59"; mkdir -p "$fst59"
base59=$(sed -n 's/^BASE_BRANCH=//p' "$t/script/harness.env" | tr -d "\"'")
st59() { # st59 <변수=값...> -- <인수...> — 페이크를 끼운 자체 검사의 종료 코드
  local envs=()
  while [ "$1" != -- ]; do envs+=("$1"); shift; done; shift
  rm -f "$fst59/labels" "$fst59/notes.json"
  ( cd "$t" && env FAKE_STATE="$fst59" FAKE_BREAK= "${envs[@]}" ./script/forge-selftest.sh "$@" > "$work/st59.log" 2>&1 )
  echo $?
}
fake59() { # fake59 <변수=값...> -- <함수와 인수> — 페이크 함수 하나를 부른다
  local envs=()
  while [ "$1" != -- ]; do envs+=("$1"); shift; done; shift
  env FAKE_STATE="$fst59" "${envs[@]}" sh -c '. "$0"; "$@"' "$root/test/fake-forge.sh" "$@" > "$work/f59.out" 2> "$work/f59.err"
  echo $?
}
check "the self-test passes the four reads on the fake" "$(st59 -- 1 100)" "0"
for f in "ok    tracker_auth" "ok    review_auth" "ok    tracker_labels" "ok    review_branch_protected $base59 → false"; do
  has "$work/st59.log" "$f" "the self-test does not report: $f"
done
check "a tracker without labels passes" "$(st59 FAKE_LABELS=none -- 1 100)" "0"
has "$work/st59.log" "ok    tracker_labels — this tracker keeps no labels" "the self-test does not accept exit code 3 for labels"
check "tracker_labels exits 3 when the tracker keeps no labels" "$(fake59 FAKE_LABELS=none -- tracker_labels)" "3"
check "and prints nothing" "$(cat "$work/f59.out")" ""
check "catches a contract violation: labels" "$(st59 FAKE_BREAK=labels -- 1 100)" "1"
has "$work/st59.log" "FAIL  tracker_labels" "the self-test does not name tracker_labels"
check "catches a contract violation: protected" "$(st59 FAKE_BREAK=protected -- 1 100)" "1"
has "$work/st59.log" "FAIL  review_branch_protected" "the self-test does not name review_branch_protected"
check "a failed sign-in fails the self-test" "$(st59 FAKE_AUTH=fail -- 1 100)" "1"
for fn in tracker_auth review_auth; do
  check "$fn exits 1 when not signed in" "$(fake59 FAKE_AUTH=fail -- $fn)" "1"
  check "$fn says how to sign in, in one line" "$(wc -l < "$work/f59.err" | tr -d ' '):$(cat "$work/f59.err")" "1:run \`fake auth login\`"
  check "$fn exits 0 when signed in" "$(fake59 -- $fn)" "0"
done
check "a protected branch" "$(fake59 FAKE_PROTECTED="main $base59" -- review_branch_protected "$base59"):$(cat "$work/f59.out")" "0:true"
check "a branch that is not protected" "$(fake59 FAKE_PROTECTED="$base59" -- review_branch_protected other):$(cat "$work/f59.out")" "0:false"
check "the labels come back as a JSON array" "$(fake59 FAKE_LABELS="Task Bug" -- tracker_labels):$(cat "$work/f59.out")" '0:["Task", "Bug"]'
for a in gitlab jira; do
  head -5 "$root/templates/managed/script/forge/$a.sh" | grep -q '검증 상태: 미검증' && ok || bad "$a.sh lost its unverified header"
done
for fn in tracker_auth tracker_labels review_auth review_branch_protected; do
  grep -q "^#   $fn" "$root/templates/managed/script/forge/_common.sh" && ok || bad "the adapter contract does not list $fn"
  grep -q "^$fn()" "$root/templates/managed/script/forge/github.sh" && ok || bad "github.sh has no $fn"
  grep -q "^$fn()" "$root/templates/managed/script/forge/gitlab.sh" && ok || bad "gitlab.sh has no $fn"
done
for fn in tracker_auth tracker_labels; do
  grep -q "^$fn()" "$root/templates/managed/script/forge/jira.sh" && ok || bad "jira.sh has no $fn"
done
unset -f st59 fake59

echo "UT-82 doctor --remote checks origin, the base branch and origin's default branch, read-only"
# 원격은 테스트 작업 디렉터리 아래의 bare 리포다. 실제 네트워크에 닿지 않는다.
rdoc() { # rdoc <이름> <대상> [인자...] — PATH 에 forge CLI 스텁을 두고 doctor 를 돌려 텍스트와 종료 코드를 남긴다
  local n="$1" t="$2"; shift 2
  PATH="$stub59:$PATH" "$root/bin/harness" doctor --target "$t" "$@" > "$work/rd-$n.txt" 2>&1
  echo $? > "$work/rd-$n.rc"
}
rsec() { # rsec <이름> — remote 절의 항목 줄만
  sed -n '/^remote$/,/^$/p' "$work/rd-$1.txt" | grep '^  '
}
t="$work/remote59"; ready "$t"
rdoc plain "$t"
grep -q '^remote$' "$work/rd-plain.txt" && bad "doctor without --remote has a remote section" || ok
has "$work/rd-plain.txt" 'remote checks not run — use `harness doctor --remote`' "doctor without --remote does not say the remote was not checked"
check "the not-run line sits right before the summary" "$(tail -2 "$work/rd-plain.txt" | head -1)" 'remote checks not run — use `harness doctor --remote`'
git -C "$t" remote add origin "$work/nowhere59/never.git"
rdoc plain2 "$t"
cmp -s "$work/rd-plain.txt" "$work/rd-plain2.txt" && ok || bad "doctor without --remote changed with an unreachable origin"
check "doctor without --remote keeps its exit code" "$(cat "$work/rd-plain2.rc")" "$(cat "$work/rd-plain.rc")"
PATH="$stub59:$PATH" "$root/bin/harness" status --target "$t" > "$work/rd-status.json" 2>/dev/null
python3 -c 'import json,sys; print(sum(i["section"] == "remote" for i in json.load(open(sys.argv[1]))["doctor"]["items"]))' "$work/rd-status.json" > "$work/rd-status.n"
check "status without --remote has no remote items" "$(cat "$work/rd-status.n")" "0"
PATH="$stub59:$PATH" "$root/bin/harness" doctor --json --target "$t" > "$work/rd-plain.json" 2>/dev/null
cat "$work/rd-status.json" "$work/rd-plain.json" > "$work/rd-plain.alljson"
hasnt "$work/rd-plain.alljson" "remote checks not run" "the not-run line reached JSON"

t2="$work/remote59-nogit"; setup "$t2"
rdoc nogit "$t2" --remote
check "not a git repository" "$(rsec nogit | head -1)" '  FAIL remote `origin`  — not a git repository'
rsec nogit | grep -q 'on origin\|origin default branch' && bad "not a git repository, yet the git items ran" || ok
hasnt "$work/rd-nogit.txt" "remote checks not run" "doctor --remote still says the remote was not checked"

git -C "$t" remote remove origin
rdoc noorigin "$t" --remote
rsec noorigin > "$work/rd-noorigin.sec"
has "$work/rd-noorigin.sec" '  FAIL remote `origin`  — not set — run `git remote add origin <url>`' "a missing origin is not a failure"
hasnt "$work/rd-noorigin.sec" "on origin" "a missing origin still checks the base branch"
hasnt "$work/rd-noorigin.sec" "origin default branch" "a missing origin still checks the default branch"
check "a missing origin exits 1" "$(cat "$work/rd-noorigin.rc")" "1"

bare="$work/remote59.git"; rm -rf "$bare"; git init -q --bare "$bare"
git -C "$t" remote add origin "$bare"
rdoc nobase "$t" --remote
rsec nobase > "$work/rd-nobase.sec"
has "$work/rd-nobase.sec" '  ok   remote `origin`' "a set origin is not ok"
has "$work/rd-nobase.sec" '  FAIL branch `development` on origin  — missing — run `git push origin development`' "a base missing on origin is not a failure"

git -C "$t" -c core.hooksPath=/dev/null push -q origin development 2>/dev/null || bad "could not push the base"
git -C "$bare" symbolic-ref HEAD refs/heads/development
rdoc ready "$t" --remote
rsec ready > "$work/rd-ready.sec"
has "$work/rd-ready.sec" '  ok   branch `development` on origin' "the pushed base is not ok"
has "$work/rd-ready.sec" '  ok   origin default branch  — `development`' "origin's default branch is not ok"

git -C "$t" -c core.hooksPath=/dev/null push -q origin development:trunk 2>/dev/null || bad "could not push another branch"
git -C "$bare" symbolic-ref HEAD refs/heads/trunk
rdoc otherhead "$t" --remote
has "$work/rd-otherhead.txt" '  warn origin default branch  — is `trunk`, not branches.base `development` — new clones and review requests start from it' "another default branch is not a warning that names it"

git -C "$t" remote set-url origin "$work/nowhere-MARK59-SECRET/never.git"
rdoc unreach "$t" --remote
PATH="$stub59:$PATH" "$root/bin/harness" doctor --remote --json --target "$t" > "$work/rd-unreach.json" 2>/dev/null
has "$work/rd-unreach.txt" '  warn branch `development` on origin  — could not check — git ls-remote failed' "an unreachable origin is not a could-not-check warning"
has "$work/rd-unreach.txt" '  warn origin default branch  — could not check — git ls-remote failed' "an unreachable origin still judges the default branch"
cat "$work/rd-unreach.txt" "$work/rd-unreach.json" > "$work/rd-unreach.all"
hasnt "$work/rd-unreach.all" "MARK59" "the origin URL reached the output"

# 자격증명을 묻는 원격 — git 이 입력을 기다리지 않도록 GIT_TERMINAL_PROMPT=0 을 받는다
mkdir -p "$work/askbin59"
cat > "$work/askbin59/git-remote-ask59" <<'SH'
#!/bin/sh
echo "${GIT_TERMINAL_PROMPT:-unset}" > "$ASK59_SEEN"
exit 128
SH
chmod +x "$work/askbin59/git-remote-ask59"
git -C "$t" remote set-url origin "ask59://forge.invalid/repo.git"
export ASK59_SEEN="$work/ask59.seen"; rm -f "$ASK59_SEEN"
python3 - "$root/bin/harness" "$t" "$work/askbin59:$stub59" > "$work/rd-ask.out" 2>&1 <<'PY'
import os, subprocess, sys
env = dict(os.environ, PATH=sys.argv[3] + ":" + os.environ["PATH"])
try:
    r = subprocess.run([sys.argv[1], "doctor", "--remote", "--target", sys.argv[2]], env=env, capture_output=True,
                       text=True, timeout=120, stdin=subprocess.PIPE)
    print("finished", "could not check — git ls-remote failed" in r.stdout)
except subprocess.TimeoutExpired:
    print("hung")
PY
check "doctor --remote does not wait for credentials" "$(cat "$work/rd-ask.out")" "finished True"
check "the remote helper got no terminal prompt" "$(cat "$ASK59_SEEN" 2>/dev/null)" "0"
unset ASK59_SEEN

git -C "$t" remote set-url origin "$bare"
PATH="$stub59:$PATH" "$root/bin/harness" status --remote --target "$t" > "$work/rd-st.json" 2>/dev/null
PATH="$stub59:$PATH" "$root/bin/harness" doctor --remote --json --target "$t" > "$work/rd-dj.json" 2>/dev/null
python3 -c 'import json,sys; a=json.load(open(sys.argv[1]))["doctor"]; b=json.load(open(sys.argv[2])); print(a == b, any(i["section"] == "remote" for i in b["items"]))' "$work/rd-st.json" "$work/rd-dj.json" > "$work/rd-same"
check "status --remote carries what doctor --remote --json prints" "$(cat "$work/rd-same")" "True True"

md59="$t.records/metrics"
before=$(cat "$md59"/spans-*.jsonl 2>/dev/null | wc -l | tr -d ' ')
rdoc metrics "$t" --remote
after=$(cat "$md59"/spans-*.jsonl 2>/dev/null | wc -l | tr -d ' ')
check "doctor --remote leaves no metrics" "$after" "$before"
cat "$work"/rd-*.txt > "$work/rd-all.log"; no_hangul "$work/rd-all.log" "doctor --remote output"
"$root/bin/harness" help > "$work/rd-help" 2>&1
grep -E '^  harness doctor +\[--remote\] \[--json\]' "$work/rd-help" >/dev/null && ok || bad "help does not list --remote and --json for doctor"
grep -E '^  harness status +\[--remote\]' "$work/rd-help" >/dev/null && ok || bad "help does not list --remote for status"

echo "UT-83 doctor --remote checks forge sign-in, tracker labels and branch protection through the adapter"
# forge 는 script/forge.sh 를 페이크로 바꿔 끼운다. forge CLI 설치 확인은 PATH 앞의 빈 gh 스텁이 지난다.
t="$work/remote59"; cp "$root/test/fake-forge.sh" "$t/script/forge.sh"
fst83="$work/fake-state83"; mkdir -p "$fst83"
fdoc() { # fdoc <이름> <변수=값...> — 페이크 환경으로 doctor --remote 를 돌리고 remote 절만 남긴다
  local n="$1"; shift
  env FAKE_STATE="$fst83" FAKE_BREAK= "$@" PATH="$stub59:$PATH" "$root/bin/harness" doctor --remote --target "$t" > "$work/fd-$n.txt" 2>&1
  sed -n '/^remote$/,/^$/p' "$work/fd-$n.txt" | grep '^  ' > "$work/fd-$n.sec"
}
fdoc unauth FAKE_AUTH=fail
has "$work/fd-unauth.sec" '  FAIL sign-in to `github`  — not signed in — run `fake auth login`' "a failed sign-in is not a failure with the adapter's hint"
hasnt "$work/fd-unauth.sec" 'label' "a failed sign-in still checks labels"
hasnt "$work/fd-unauth.sec" 'branch protection' "a failed sign-in still checks branch protection"
fdoc signed FAKE_LABELS="Requirement Task invalid"
has "$work/fd-signed.sec" '  ok   sign-in to `github`' "a sign-in is not ok"
check "one sign-in line when the tracker and the host are the same forge" "$(grep -c 'sign-in to' "$work/fd-signed.sec")" "1"
for l in Requirement Task invalid; do has "$work/fd-signed.sec" "  ok   label \`$l\`  — on github" "label $l is not ok"; done
fdoc onemissing FAKE_LABELS="Requirement Task"
has "$work/fd-onemissing.sec" '  warn label `invalid`  — missing on github — create it on the forge' "a missing label is not a warning"
check "only the missing label warns" "$(grep -c '^  warn label' "$work/fd-onemissing.sec")" "1"
fdoc case FAKE_LABELS="requirement TASK INVALID"
check "labels that differ only in case are ok" "$(grep -c '^  ok   label' "$work/fd-case.sec")" "3"
fdoc nolabels FAKE_LABELS=none
hasnt "$work/fd-nolabels.sec" 'label' "a tracker that keeps no labels still has label lines"
fdoc brokenlabels FAKE_BREAK=labels
check "an unreadable label list is one could-not-check line" "$(grep 'label' "$work/fd-brokenlabels.sec")" '  warn labels  — could not check'
fdoc prot FAKE_PROTECTED=development
has "$work/fd-prot.sec" '  ok   branch protection `development`  — protected on github' "a protected base is not ok"
hasnt "$work/fd-prot.sec" 'branch protection `main`' "a protected branch absent from origin is checked"
fdoc noprot FAKE_PROTECTED=
has "$work/fd-noprot.sec" '  warn branch protection `development`  — not protected on github — only local hooks block direct pushes; protect it on the forge' "an unprotected base is not a warning"
fdoc brokenprot FAKE_BREAK=protected
has "$work/fd-brokenprot.sec" '  warn branch protection `development`  — could not check' "an odd protection answer is not a could-not-check warning"
# forge CLI 가 없는 종류는 로그인부터 내지 않는다
minbin="$work/minbin59"; rm -rf "$minbin"; mkdir -p "$minbin"
for c in git python3 sh bash; do ln -s "$(command -v "$c")" "$minbin/$c"; done
FAKE_STATE="$fst83" PATH="$minbin" "$root/bin/harness" doctor --remote --target "$t" > "$work/fd-nocli.txt" 2>&1
sed -n '/^remote$/,/^$/p' "$work/fd-nocli.txt" > "$work/fd-nocli.sec"
has "$work/fd-nocli.sec" 'remote `origin`' "the remote section did not run without the forge CLI"
hasnt "$work/fd-nocli.sec" 'sign-in' "a forge without its CLI still checks sign-in"
hasnt "$work/fd-nocli.sec" 'label' "a forge without its CLI still checks labels"
hasnt "$work/fd-nocli.sec" 'branch protection' "a forge without its CLI still checks branch protection"
grep -nE '"(gh|glab|jira)"[],]' "$root/bin/harness" | grep -v '^[0-9]*:FORGE_CLI = ' > "$work/fd-direct" || true
check "the CLI does not call a forge CLI directly" "$(cat "$work/fd-direct")" ""
cat "$work"/fd-*.txt > "$work/fd-all.log"; no_hangul "$work/fd-all.log" "doctor --remote forge output"
unset -f fdoc

echo "UT-84 doctor --remote checks the reviewer's CLI runner through run-agent.py --check"
# 리뷰어 러너는 PATH 앞의 codex 스텁이다. 종료 코드는 CODEX_LOGIN_EXIT 로 정한다.
t="$work/remote59"; cbin="$work/codexbin59"; mkdir -p "$cbin"
cat > "$cbin/codex" <<'SH'
#!/bin/sh
echo "RUNNER-ACCOUNT-MARK59"; echo "RUNNER-ACCOUNT-MARK59" >&2
exit "${CODEX_LOGIN_EXIT:-0}"
SH
chmod +x "$cbin/codex"
rvdoc() { # rvdoc <이름> <PATH> [변수=값...] — doctor --remote 의 리뷰어 러너 줄만 남긴다
  local n="$1" path="$2"; shift 2
  env FAKE_STATE="$fst83" "$@" PATH="$path" "$root/bin/harness" doctor --remote --target "$t" > "$work/rv-$n.txt" 2>&1
  grep 'reviewer runner' "$work/rv-$n.txt" > "$work/rv-$n.line"
}
rvdoc in "$cbin:$stub59:$PATH" CODEX_LOGIN_EXIT=0
check "a signed-in reviewer runner" "$(cat "$work/rv-in.line")" '  ok   reviewer runner `codex`  — signed in'
rvdoc out "$cbin:$stub59:$PATH" CODEX_LOGIN_EXIT=1
check "a reviewer runner that is not signed in" "$(cat "$work/rv-out.line")" '  FAIL reviewer runner `codex`  — not signed in — `codex login status` fails'
hasnt "$work/rv-out.txt" "RUNNER-ACCOUNT-MARK59" "the runner's output reached doctor"
rvdoc none "$minbin"
check "a reviewer runner that is not installed" "$(cat "$work/rv-none.line")" '  FAIL reviewer runner `codex`  — codex is not installed (roles.code-reviewer.runner = codex)'
cp "$t/script/harness.plan.json" "$work/rv-plan.bak"
python3 - "$t/script/harness.plan.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["roles"]["code-reviewer"]["auth_check"] = []
json.dump(d, open(p, "w"))
PY
rvdoc unchecked "$cbin:$stub59:$PATH"
check "a reviewer runner without a sign-in command" "$(cat "$work/rv-unchecked.line")" '  ok   reviewer runner `codex`  — installed — sign-in is not checked for Codex CLI'
cp "$work/rv-plan.bak" "$t/script/harness.plan.json"
mv "$t/script/run-agent.py" "$work/rv-runner.bak"
rvdoc norunner "$cbin:$stub59:$PATH"
check "a missing runner script" "$(cat "$work/rv-norunner.line")" '  FAIL reviewer runner `codex`  — `script/run-agent.py` is missing — run `harness render`'
mv "$work/rv-runner.bak" "$t/script/run-agent.py"
"$root/bin/harness" set --target "$t" invariants.distinct_reviewer false roles.code-reviewer.runner inproc >/dev/null 2>&1 \
  || bad "could not make the reviewer a subagent"
rvdoc inproc "$cbin:$stub59:$PATH"
check "a subagent reviewer has no runner line" "$(cat "$work/rv-inproc.line")" ""
has "$work/rv-inproc.txt" 'remote `origin`' "the remote section did not run for a subagent reviewer"
cat "$work"/rv-*.txt > "$work/rv-all.log"; no_hangul "$work/rv-all.log" "doctor --remote reviewer output"
unset -f rvdoc

echo "UT-85 doctor.remote_timeout: default, refused values, an old config without the section, and the value reaching every remote call"
grep -A1 '^\[doctor\]$' "$root/templates/harness.toml" | tail -1 > "$work/rt-default"
check "the shipped default remote_timeout" "$(cat "$work/rt-default")" "remote_timeout = 30"
t="$work/rtcfg"; setup "$t"; cp "$t/harness.toml" "$work/rtcfg.orig"
rt_with() { # rt_with <remote_timeout 줄 대체> — 원본 설정의 [doctor] 값만 바꾸고 render 한다
  cp "$work/rtcfg.orig" "$t/harness.toml"
  python3 - "$t/harness.toml" "$1" <<'PY2'
import sys; p = sys.argv[1]; s = open(p).read()
assert "[doctor]\nremote_timeout = 30\n" in s
open(p, "w").write(s.replace("[doctor]\nremote_timeout = 30\n", "[doctor]\n%s\n" % sys.argv[2]))
PY2
  "$root/bin/harness" render --target "$t" > "$work/rtcfg.log" 2>&1
}
for v in 0 -1 601 '"30"' 1.5 true; do
  rt_with "remote_timeout = $v"; check "render with doctor.remote_timeout = $v" "$?" "2"
  has "$work/rtcfg.log" "error: doctor.remote_timeout must be a whole number of seconds from 1 to 600 (got " "doctor.remote_timeout = $v is not refused by name"
done
for v in 1 600; do
  rt_with "remote_timeout = $v"; check "render with doctor.remote_timeout = $v" "$?" "0"
done
rt_with $'remote_timeout = 30\nretries = 2'; check "render with an unknown doctor key" "$?" "2"
has "$work/rtcfg.log" "unknown key(s) in [doctor]: retries" "the unknown doctor key is not named"
has "$work/rtcfg.log" "the keys are remote_timeout" "the doctor keys are not listed"
# 절이 없는 옛 설정은 기본값으로 돌고, set 이 절을 만들어 값을 넣는다
cp "$work/rtcfg.orig" "$t/harness.toml"
python3 - "$t/harness.toml" <<'PY2'
import re, sys; p = sys.argv[1]; s = open(p).read()
s, n = re.subn(r'^\[doctor\]\n(?:(?!\[).*\n)*', '', s, flags=re.M)
assert n == 1 and "[doctor]" not in s
open(p, "w").write(s)
PY2
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "render without a doctor section" "$?" "0"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check without a doctor section" "$?" "0"
rt_schema() { "$root/bin/harness" schema --target "$t" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["doctor"]["remote_timeout"])'; }
check "schema fills the default without a doctor section" "$(rt_schema)" "30"
cp "$t/harness.toml" "$work/rtcfg.nosec"
"$root/bin/harness" set --target "$t" doctor.remote_timeout 0 > "$work/rtcfg.set0" 2>&1; check "set doctor.remote_timeout 0" "$?" "2"
has "$work/rtcfg.set0" "doctor.remote_timeout must be a whole number of seconds from 1 to 600 (got 0)" "set 0 is not refused by name"
cmp -s "$t/harness.toml" "$work/rtcfg.nosec" && ok || bad "a refused set left the config changed"
"$root/bin/harness" set --target "$t" doctor.remote_timeout 45 >/dev/null 2>&1; check "set doctor.remote_timeout on a config without the section" "$?" "0"
python3 -c 'import sys,tomllib; print(repr(tomllib.load(open(sys.argv[1],"rb"))["doctor"]["remote_timeout"]))' "$t/harness.toml" > "$work/rtcfg.val" 2>&1
check "the set value is an integer in the config" "$(cat "$work/rtcfg.val")" "45"
check "schema reports the set value" "$(rt_schema)" "45"
# 원격 호출마다 설정 값을 제한 시간으로 받는다. 호출은 띄우지 않고 받은 제한만 적는다
t="$work/remote59"
"$root/bin/harness" set --target "$t" doctor.remote_timeout 7 >/dev/null 2>&1 || bad "could not set doctor.remote_timeout on the remote repo"
PATH="$stub59:$PATH" python3 - "$root/bin/harness" "$t" > "$work/rt-calls" 2>&1 <<'PY2'
import importlib.machinery, importlib.util, os, subprocess, sys, types
from pathlib import Path
loader = importlib.machinery.SourceFileLoader("harness_cli", sys.argv[1])
spec = importlib.util.spec_from_loader("harness_cli", loader)
h = importlib.util.module_from_spec(spec); loader.exec_module(h)
target = Path(sys.argv[2]).resolve()
cfg = h.load(target); h.normalize(cfg); h.validate(cfg)
cfg["roles"]["code-reviewer"]["runner"] = "codex"
seen = []
class FakePopen:
    def __init__(self, argv, **kw):
        self.argv, self.pid, self.returncode = argv, 0, 1
        if argv[0] == sys.executable:
            # 실행기가 로그인 확인을 바로 시작했다고 알린다
            os.write(int(kw["env"]["HARNESS_CHECK_START_FD"]), b"1")
    def communicate(self, timeout=None):
        seen.append((self.argv[0], timeout))
        return "", ""
# 원격 호출이 쓰는 Popen 만 바꾼다. git() 같은 로컬 호출은 진짜 subprocess 로 돈다
h.subprocess = types.SimpleNamespace(**{k: getattr(subprocess, k) for k in dir(subprocess) if not k.startswith("__")})
h.subprocess.Popen = FakePopen
h.remote_items(cfg, target, lambda *a: None)
kinds = sorted({a for a, _ in seen})
# 리뷰어 러너 확인만 시작 알림 뒤로 그 제한의 배수를 기다린다
print(sorted({t for a, t in seen if a != sys.executable}), sorted({t / h.RUNNER_CHECK_AFTER_START for a, t in seen if a == sys.executable}),
      h.RUNNER_CHECK_AFTER_START > 1, "git" in kinds, "sh" in kinds)
PY2
check "every remote call gets doctor.remote_timeout" "$(cat "$work/rt-calls")" "[7] [7.0] True True True"
unset -f rt_with rt_schema

echo "UT-86 the reviewer runner check gives its sign-in command doctor.remote_timeout, and doctor waits for it from its start"
t="$work/authto"; setup "$t"
"$root/bin/harness" set --target "$t" roles.planner.runner codex doctor.remote_timeout 7 >/dev/null 2>&1 \
  || bad "could not make the planner a codex runner with doctor.remote_timeout 7"
at_plan() { python3 -c 'import json,sys; print(repr(json.load(open(sys.argv[1]))["roles"]["planner"].get("auth_timeout")))' "$t/script/harness.plan.json" 2>&1; }
# run-agent.py --check 를 띄우되 로그인 확인 명령은 실행하지 않고, 받은 제한 시간과 그때까지 받은 시작 알림만 적는다
at_run() { # at_run <이름> <ok|expire> [notify] — 결과는 "<종료 코드> <받은 제한 시간 목록> <확인 명령 직전까지 받은 알림 목록>"
  PATH="$stub59:$PATH" python3 - "$t/script/run-agent.py" "$2" "$work/at-$1.res" "${3:-}" > "$work/at-$1.out" 2> "$work/at-$1.err" <<'PY2'
import os, runpy, subprocess, sys
script, mode, res, notify = sys.argv[1:5]
seen, marks = [], []
rfd = None
if notify:
    rfd, wfd = os.pipe()
    os.set_blocking(rfd, False)
    os.environ["HARNESS_CHECK_START_FD"] = str(wfd)
def fake_run(argv, **kw):
    seen.append(kw.get("timeout"))
    if rfd is not None:
        try:
            marks.append(os.read(rfd, 8))
        except BlockingIOError:
            marks.append(b"")
    if mode == "expire":
        raise subprocess.TimeoutExpired(argv, kw.get("timeout"))
    return subprocess.CompletedProcess(argv, 0)
subprocess.run = fake_run
sys.argv = [script, "planner", "--check"]
code = None
try:
    runpy.run_path(script, run_name="__main__")
except SystemExit as e:
    code = e.code
open(res, "w").write("%s %s %s" % (code, seen, marks))
PY2
}
check "the plan carries doctor.remote_timeout as the sign-in time limit" "$(at_plan)" "7"
at_run set ok; check "the sign-in check runs with the configured time limit" "$(cat "$work/at-set.res")" "0 [7] []"
check "a sign-in check within the limit prints signed-in" "$(cat "$work/at-set.out")" "signed-in"
at_run notify ok notify; check "the sign-in check announces its start on the given descriptor before running" "$(cat "$work/at-notify.res")" "0 [7] [b'1']"
check "a sign-in check that announces its start still prints only signed-in" "$(cat "$work/at-notify.out")" "signed-in"
at_run expire expire notify; check "a sign-in check past the limit exits 4" "$(cat "$work/at-expire.res")" "4 [7] [b'1']"
has "$work/at-expire.err" "error: could not check sign-in for codex" "a sign-in check past the limit does not say so"
# [doctor] 절이 없는 옛 설정은 기본값으로 끊는다
python3 - "$t/harness.toml" <<'PY2'
import re, sys; p = sys.argv[1]; s = open(p).read()
s, n = re.subn(r'^\[doctor\]\n(?:(?!\[).*\n)*', '', s, flags=re.M)
assert n == 1 and "[doctor]" not in s
open(p, "w").write(s)
PY2
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "render without a doctor section" "$?" "0"
check "the plan's sign-in time limit without a doctor section" "$(at_plan)" "30"
at_run default ok; check "the sign-in check without a doctor section runs with 30 seconds" "$(cat "$work/at-default.res")" "0 [30] []"
# 계획에 제한 시간이 없거나 쓸 수 없는 값이면 확인 명령을 띄우지 않고 계획을 다시 만들라고 한다. 시작도 알리지 않는다
cp "$t/script/harness.plan.json" "$work/at-plan.bak"
for v in none 0 '"30"' true; do
  python3 - "$t/script/harness.plan.json" "$v" <<'PY2'
import json, sys
p, v = sys.argv[1:3]; d = json.load(open(p)); r = d["roles"]["planner"]
if v == "none":
    del r["auth_timeout"]
else:
    r["auth_timeout"] = json.loads(v)
json.dump(d, open(p, "w"))
PY2
  at_run bad ok notify; check "a plan with auth_timeout $v" "$(cat "$work/at-bad.res")" "2 [] []"
  has "$work/at-bad.err" "error: script/harness.plan.json is missing or broken" "a plan with auth_timeout $v is not called broken"
  cp "$work/at-plan.bak" "$t/script/harness.plan.json"
done
# doctor 의 리뷰어 러너 확인을 가상 시계로 돌린다. 실행기는 기동에 prep 초를 쓰고 시작을 알린 뒤 auth 초 뒤에 끝난다.
# 시작 알림이 없으면 prep 초 뒤에 그냥 끝난다. 실제로 기다리지 않는다
python3 - "$root/bin/harness" "$work/remote59" > "$work/at-doctor" 2>&1 <<'PY2'
import contextlib, errno, importlib.machinery, importlib.util, os, subprocess, sys, types
from pathlib import Path
loader = importlib.machinery.SourceFileLoader("harness_cli", sys.argv[1])
spec = importlib.util.spec_from_loader("harness_cli", loader)
h = importlib.util.module_from_spec(spec); loader.exec_module(h)
target = Path(sys.argv[2]).resolve()
cfg = h.load(target); h.normalize(cfg); h.validate(cfg)
cfg["roles"]["code-reviewer"]["runner"] = "codex"
cfg["doctor"]["remote_timeout"] = 7
assert h.run_plan(cfg)["roles"]["code-reviewer"]["auth_timeout"] == 7
case = {}
class FakePopen:
    def __init__(self, argv, **kw):
        self.argv, self.pid, self.returncode = argv, 0, None
        fd = kw["env"]["HARNESS_CHECK_START_FD"]
        assert kw["pass_fds"] == (int(fd),)
        self.w = os.dup(int(fd))
        case["clock"], case["killed"] = 0.0, False
    def communicate(self, timeout=None):
        end = case["prep"] + (case["auth"] if case["notify"] else 0)
        if timeout is not None and end - case["clock"] > timeout:
            case["clock"] += timeout
            raise subprocess.TimeoutExpired(self.argv, timeout)
        case["clock"] = end
        self.returncode = case["code"]
        return case["out"], case["err"]
def fake_select(r, w, x, timeout):
    p = case["proc"]
    if case["prep"] > timeout:
        case["clock"] += timeout
        return [], [], []
    case["clock"] = case["prep"]
    if case["notify"]:
        os.write(p.w, b"1")
    os.close(p.w)
    return r, [], []
def fake_popen(argv, **kw):
    case["proc"] = FakePopen(argv, **kw)
    return case["proc"]
def fake_killpg(pid, sig):
    case["killed"] = True
h.subprocess = types.SimpleNamespace(**{k: getattr(subprocess, k) for k in dir(subprocess) if not k.startswith("__")})
h.subprocess.Popen = fake_popen
h.select = types.SimpleNamespace(select=fake_select)
h.os = types.SimpleNamespace(**{k: getattr(os, k) for k in dir(os) if not k.startswith("__")})
h.os.killpg = fake_killpg
def run(name, prep, notify, auth, code, out="", err=""):
    case.update(prep=prep, notify=notify, auth=auth, code=code, out=out, err=err)
    lines = []
    h.remote_reviewer_items(cfg, target, lambda *a: lines.append(a))
    print(name, lines[0][0], lines[0][2], "killed" if case["killed"] else "exited")
# 기동 6초, 로그인 확인 6.5초 — 안쪽은 7초 제한 안에 성공했다
run("slow-start", 6, True, 6.5, 0, "signed-in\n")
# 안쪽이 자기 제한 7초를 다 쓰고 4 로 끝난다 — 바깥은 그 결과를 읽는다
run("inner-timeout", 6, True, 7.01, 4, "", "error: could not check sign-in for codex\n")
# 시작을 알리지 않고 끝난 실행기는 그 종료 코드로 가른다
run("no-start", 0.5, False, 0, 2, "", "error: codex is not installed (roles.code-reviewer.runner = codex)\n")
# 시작을 알리지 못한 채 제한을 넘긴 실행기와, 시작 뒤 안쪽 제한을 지나서도 끝나지 않는 실행기는 끊는다
run("stuck-start", 7.5, True, 1, 0, "signed-in\n")
run("stuck-after", 1, True, 7 * h.RUNNER_CHECK_AFTER_START + 0.5, 0, "signed-in\n")
# 시작 알림 통로의 OS 오류는 확인하지 못한 것으로 떨어진다. 그 통로의 파일 기술자는 정확히 한 번씩 닫힌다
real_pipe, real_close, real_select = os.pipe, os.close, h.select
def fault(name, where, err):
    made, closed = [], []
    def pipe():
        if where == "pipe":
            raise err
        made.extend(real_pipe())
        return tuple(made)
    def close(fd):
        closed.append(fd)
        real_close(fd)
        if where == "close" and fd == made[1]:
            raise err
    def select_(r, w, x, timeout):
        raise err
    def read(fd, n):
        raise err
    def popen(argv, **kw):
        if where == "popen":
            raise err
        return fake_popen(argv, **kw)
    h.os.pipe, h.os.close, h.subprocess.Popen = pipe, close, popen
    # 실제로 기다리지 않는다 — 읽기 오류는 알림이 왔다고 답한 뒤에 낸다
    h.select = types.SimpleNamespace(select=(lambda r, w, x, t: (r, [], [])) if where == "read" else select_)
    h.os.read = read if where == "read" else os.read
    case["proc"], case["killed"] = None, False
    try:
        run(name, 0, True, 0, 0, "signed-in\n")
    finally:
        h.os.pipe, h.os.close, h.os.read, h.select, h.subprocess.Popen = real_pipe, real_close, os.read, real_select, fake_popen
        if case["proc"] is not None:
            with contextlib.suppress(OSError):
                real_close(case["proc"].w)
    leaked = [fd for fd in made if closed.count(fd) != 1]
    print(name, "fds", "none" if not made else "leaked %s" % leaked if leaked else "closed once")
for name, where, err in (("pipe-EMFILE", "pipe", OSError(errno.EMFILE, "Too many open files")),
                         ("popen-E2BIG", "popen", OSError(errno.E2BIG, "Argument list too long")),
                         ("close-EIO", "close", OSError(errno.EIO, "close failed")),
                         ("select-EBADF", "select", OSError(errno.EBADF, "bad fd")),
                         ("select-out-of-range", "select", ValueError("filedescriptor out of range in select()")),
                         ("read-EIO", "read", OSError(errno.EIO, "read failed"))):
    fault(name, where, err)
# 시작 알림 통로를 만들지 못해도 doctor 는 끝까지 돌고 리뷰어 러너 항목을 확인하지 못한 것으로 남긴다
def emfile():
    raise OSError(errno.EMFILE, "Too many open files")
class Quiet:
    def __init__(self, argv, **kw):
        self.pid, self.returncode = 0, 1
    def communicate(self, timeout=None):
        return "", ""
h.os.pipe, h.subprocess.Popen = emfile, Quiet
items = h.doctor_items(cfg, target, remote=True)
h.os.pipe, h.subprocess.Popen = real_pipe, fake_popen
last = items[-1]
print("doctor-emfile", last["section"], last["state"], last["what"], last["detail"])
PY2
check "the reviewer runner check waits for the sign-in check from its start, not from the runner's launch" "$(cat "$work/at-doctor")" \
"slow-start ok signed in exited
inner-timeout warn could not check exited
no-start bad codex is not installed (roles.code-reviewer.runner = codex) exited
stuck-start warn could not check killed
stuck-after warn could not check killed
pipe-EMFILE warn could not check exited
pipe-EMFILE fds none
popen-E2BIG warn could not check exited
popen-E2BIG fds closed once
close-EIO warn could not check killed
close-EIO fds closed once
select-EBADF warn could not check killed
select-EBADF fds closed once
select-out-of-range warn could not check killed
select-out-of-range fds closed once
read-EIO warn could not check killed
read-EIO fds closed once
doctor-emfile remote warn reviewer runner \`codex\` could not check"
cat "$work"/at-*.out "$work"/at-*.err > "$work/at-all.log"; no_hangul "$work/at-all.log" "run-agent.py --check output with a time limit"
unset -f at_plan at_run

echo "UT-87 user files and the project's own place: script/project/ is the project's, and a file the harness would write is not taken over silently"
# 프로젝트 스크립트를 하네스 자리에 두면 갱신이 알림 없이 덮는다. 자리를 나누고, 겹치면 쓰기 전에 멈춘다.
t="$work/own87"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null 2>&1; check "install on a new repo" "$?" "0"
cmp -s "$t/script/project/README.md" "$root/templates/owned/script/project/README.md" && ok \
  || bad "install did not lay the project scripts README as its template"
printf '| `deploy.sh` | the project deploys | by hand |\n' >> "$t/script/project/README.md"
"$root/bin/harness" render --target "$t" >/dev/null
has "$t/script/project/README.md" '`deploy.sh`' "render overwrote the project scripts README"
"$root/bin/harness" status --target "$t" > "$work/own87-status.json" 2>&1
python3 - "$work/own87-status.json" > "$work/own87-facts" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print(" ".join(i["state"] for i in d["doctor"]["items"]
               if i["section"] == "project facts" and i["what"] == "script/project/README.md"))
PY
check "doctor sees the project scripts README as filled in" "$(cat "$work/own87-facts")" "ok"
"$root/bin/harness" uninstall --target "$t" >/dev/null 2>&1; check "uninstall exit code" "$?" "0"
[ -f "$t/script/project/README.md" ] && ok || bad "uninstall removed the project scripts README"
"$root/bin/harness" install --target "$t" >/dev/null 2>&1
"$root/bin/harness" uninstall --target "$t" --purge --yes >/dev/null 2>&1; check "purge exit code" "$?" "0"
[ -e "$t/script/project/README.md" ] && bad "--purge left the project scripts README" || ok
# 하네스는 script/project/ 에 쓰지 않는다 — 관리 템플릿, 생성 템플릿, plan() 어느 쪽도
( cd "$root/templates/managed" && find . -type f | sed 's|^\./||' ) > "$work/own87-paths"
( cd "$root/templates/generated" && find . -type f | sed 's|^\./||' ) >> "$work/own87-paths"
setup "$work/own87-base"
python3 - "$root/bin/harness" "$work/own87-base" >> "$work/own87-paths" <<'PY'
import importlib.machinery, importlib.util, sys
from pathlib import Path
sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader("harness_cli", sys.argv[1])
spec = importlib.util.spec_from_loader("harness_cli", loader)
h = importlib.util.module_from_spec(spec); loader.exec_module(h)
target = Path(sys.argv[2]).resolve()
cfg = h.load(target); h.normalize(cfg); h.validate(cfg)
for rel, _c, _m in h.plan(cfg, target):
    print(rel)
PY
grep -q '^script/harness.env$' "$work/own87-paths" && ok || bad "the path list does not carry plan() paths"
grep -q '^script/project/' "$work/own87-paths" && bad "the harness writes under script/project/: $(grep '^script/project/' "$work/own87-paths" | head -1)" || ok
# 규칙 문서가 프로젝트 스크립트를 새 자리로 보낸다
t="$work/own87-base"
python3 - "$t/.ai/AI_AGENT.md" > "$work/own87-canon" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
def chapter(n):
    m = re.search(r"^## %d\. .*?(?=^## \d+\. |\Z)" % n, s, re.S | re.M)
    return m.group(0) if m else ""
print("3", "`script/project/README.md`" in chapter(3) and "`script/project/`" in chapter(3))
print("9", "| `script/project/README.md` |" in chapter(9))
print("10", re.search(r"^\| `script/project/` \| \*\*소유\*\*", chapter(10), re.M) is not None)
PY
check "the rule canon names script/project/ in chapters 3, 9 and 10" "$(cat "$work/own87-canon" | tr '\n' ' ')" "3 True 9 True 10 True "

# 첫 설치의 겹침 — 사용자 파일이 있으면 아무것도 쓰지 않고 멈춘다
u="$work/user87"; rm -rf "$u"; mkdir -p "$u/script"
( cd "$u" && git init -q . )
printf 'my own agent notes\n' > "$u/CLAUDE.md"; printf '#!/bin/sh\necho mine\n' > "$u/script/review-mr.sh"; chmod 755 "$u/script/review-mr.sh"
"$root/bin/harness" install --target "$u" > "$work/u87-1.out" 2> "$work/u87-1.err"; check "install over user files" "$?" "2"
for s in "CLAUDE.md" "script/review-mr.sh" "nothing was written" "harness install --adopt" "script/project/"; do
  has "$work/u87-1.err" "$s" "the refusal does not name: $s"
done
check "the user CLAUDE.md is untouched" "$(cat "$u/CLAUDE.md")" "my own agent notes"
check "the user script is untouched" "$(sed -n 2p "$u/script/review-mr.sh")" "echo mine"
for f in .harness .ai/AI_AGENT.md script/project/README.md; do
  [ -e "$u/$f" ] && bad "the refused install wrote $f" || ok
done
[ -e "$HARNESS_HOME/user87/project.json" ] && bad "the refused install registered the project" || ok
# 넘겨받기 — 원래 파일은 <경로>.orig 로 남고 매니페스트에는 들지 않는다
"$root/bin/harness" install --target "$u" --adopt > "$work/u87-2.out" 2> "$work/u87-2.err"; check "install --adopt" "$?" "0"
check "CLAUDE.md.orig keeps the user's content" "$(cat "$u/CLAUDE.md.orig")" "my own agent notes"
check "script/review-mr.sh.orig keeps the user's content" "$(sed -n 2p "$u/script/review-mr.sh.orig")" "echo mine"
[ -x "$u/script/review-mr.sh.orig" ] && ok || bad "the moved user script lost its mode"
grep -qx 'CLAUDE.md' "$u/.harness/generated" && ok || bad "the adopted CLAUDE.md is not in the manifest"
grep -q '  script/review-mr.sh$' "$u/.harness/managed" && ok || bad "the adopted script is not in the manifest"
cat "$u/.harness/generated" "$u/.harness/managed" | grep -q '\.orig$' && bad "an .orig file landed in a manifest" || ok
check "one adopted line per file" "$(grep -c '^render: adopted ' "$work/u87-2.out")" "2"
has "$work/u87-2.out" "render: adopted script/review-mr.sh — yours is at script/review-mr.sh.orig" "the adopted line does not say where the user's file went"
# 넘겨받을 수 없음 — .orig 가 이미 있거나 경로에 디렉터리가 있으면 --adopt 여도 멈춘다
u2="$work/user87b"; rm -rf "$u2"; mkdir -p "$u2"; ( cd "$u2" && git init -q . )
printf 'mine\n' > "$u2/CLAUDE.md"; printf 'older\n' > "$u2/CLAUDE.md.orig"
"$root/bin/harness" install --target "$u2" --adopt > "$work/u87-3.out" 2> "$work/u87-3.err"; check "adopt where .orig already exists" "$?" "2"
has "$work/u87-3.err" "(CLAUDE.md.orig already exists)" "the refusal does not say the .orig already exists"
check "CLAUDE.md is untouched" "$(cat "$u2/CLAUDE.md")" "mine"
check "CLAUDE.md.orig is untouched" "$(cat "$u2/CLAUDE.md.orig")" "older"
[ -e "$u2/.harness" ] && bad "the refused adopt wrote .harness/" || ok
u3="$work/user87c"; rm -rf "$u3"; mkdir -p "$u3/CLAUDE.md"; ( cd "$u3" && git init -q . )
"$root/bin/harness" install --target "$u3" --adopt > "$work/u87-4.out" 2> "$work/u87-4.err"; check "adopt where a directory sits" "$?" "2"
has "$work/u87-4.err" "CLAUDE.md (a directory)" "the refusal does not say the path is a directory"
[ -d "$u3/CLAUDE.md" ] && [ ! -e "$u3/CLAUDE.md.orig" ] && [ ! -e "$u3/.harness" ] && ok || bad "the refused adopt changed something"
# 재설치 — 매니페스트가 남아 하네스 파일은 사용자 파일이 아니다. 고친 관리 파일은 덮인다
printf '\n# edited by hand\n' >> "$u/script/review-mr.sh"
"$root/bin/harness" install --target "$u" > "$work/u87-5.out" 2> "$work/u87-5.err"; check "reinstall" "$?" "0"
hasnt "$u/script/review-mr.sh" "# edited by hand" "reinstall did not put the managed file back"
# 하네스가 쓰지 않는 이름의 프로젝트 스크립트는 그대로다
printf '#!/bin/sh\necho deploy\n' > "$u/script/deploy.sh"
"$root/bin/harness" render --target "$u" > "$work/u87-6.out" 2> "$work/u87-6.err"; check "render beside a project script" "$?" "0"
check "the project script is untouched" "$(sed -n 2p "$u/script/deploy.sh")" "echo deploy"
"$root/bin/harness" status --target "$u" > "$work/u87-6.json" 2>> "$work/u87-6.err"
python3 - "$work/u87-6.json" > "$work/u87-6.items" <<'PY'
import json, sys
print(" ".join(i["state"] for i in json.load(open(sys.argv[1], encoding="utf-8"))["doctor"]["items"]
               if i["section"] == "managed files"))
PY
check "a project script raises nothing in the managed files section" "$(cat "$work/u87-6.items")" "ok"
# 설정을 바꾸는 명령 — render 가 사용자 파일로 멈추면 설정을 되돌린다
cp "$u/harness.toml" "$work/u87-before.toml"
mkdir -p "$u/.claude/commands"; printf 'my ship command\n' > "$u/.claude/commands/ship.md"
"$root/bin/harness" steps --target "$u" ship '{"title":"ship it","steps":[{"id":"a","type":"gate","title":"t"}]}' \
  > "$work/u87-7.out" 2> "$work/u87-7.err"; check "steps over a user command" "$?" "2"
has "$work/u87-7.err" "reverted — the config is unchanged" "steps did not say it reverted"
has "$work/u87-7.err" "harness steps --adopt" "the refusal does not name the command that was run"
cmp -s "$u/harness.toml" "$work/u87-before.toml" && ok || bad "steps left the config changed"
check "the user command is untouched" "$(cat "$u/.claude/commands/ship.md")" "my ship command"
mkdir -p "$u/docs/decisions"; printf 'my decisions\n' > "$u/docs/decisions/README.md"
"$root/bin/harness" set --target "$u" adr.dir docs/decisions > "$work/u87-8.out" 2> "$work/u87-8.err"; check "set over a user file" "$?" "2"
has "$work/u87-8.err" "reverted — the config is unchanged" "set did not say it reverted"
has "$work/u87-8.err" "docs/decisions/README.md" "the set refusal does not name the user file"
cmp -s "$u/harness.toml" "$work/u87-before.toml" && ok || bad "set left the config changed"
# render 도 무엇이든 쓰기 전에 멈춘다 — 지운 소유 파일을 다시 깔지 않고 매니페스트도 그대로다
python3 - "$u/harness.toml" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding="utf-8")
m = re.search(r"^\[adr\]\s*$", s, re.M); n = re.search(r"^\[", s[m.end():], re.M)
end = m.end() + (n.start() if n else len(s) - m.end())
p.write_text(s[:m.end()] + re.sub(r"^dir = .*$", 'dir = "docs/decisions"', s[m.end():end], count=1, flags=re.M) + s[end:], encoding="utf-8")
PY
rm -f "$u/docs/spec/README.md"; cp "$u/.harness/managed" "$work/u87-mf"
"$root/bin/harness" render --target "$u" > "$work/u87-9.out" 2> "$work/u87-9.err"; check "render over a user file" "$?" "2"
has "$work/u87-9.err" "docs/decisions/README.md" "the render refusal does not name the user file"
[ -e "$u/docs/spec/README.md" ] && bad "the refused render laid an owned file" || ok
cmp -s "$u/.harness/managed" "$work/u87-mf" && ok || bad "the refused render rewrote the manifest"
# 쓸 경로의 부모가 파일이면 무엇이든 쓰기 전에 멈춘다 — 소유 파일의 부모도 본다
pf87="$work/parent87"; rm -rf "$pf87"; mkdir -p "$pf87"; ( cd "$pf87" && git init -q . )
printf 'not a dir\n' > "$pf87/script"
"$root/bin/harness" install --target "$pf87" > "$work/u87-13.out" 2> "$work/u87-13.err"; check "install where script is a file" "$?" "2"
has "$work/u87-13.err" "  --> script (not a directory)" "the refusal does not name the parent that is a file"
check "the user file named script is untouched" "$(cat "$pf87/script")" "not a dir"
for f in .harness .ai/AI_AGENT.md .ai/project/scope.md; do
  [ -e "$pf87/$f" ] && bad "the refused install wrote $f" || ok
done
[ -e "$HARNESS_HOME/parent87/project.json" ] && bad "the refused install registered the project" || ok
# 매니페스트에 있던 관리 파일 자리에 디렉터리가 생겨도 쓰기 전에 멈춘다
rm "$u/script/review-mr.sh"; mkdir "$u/script/review-mr.sh"; cp "$u/.harness/managed" "$work/u87-mf2"
"$root/bin/harness" render --target "$u" > "$work/u87-14.out" 2> "$work/u87-14.err"; check "render where a managed file became a directory" "$?" "2"
has "$work/u87-14.err" "  --> script/review-mr.sh (a directory)" "the refusal does not say the managed path is a directory"
cmp -s "$u/.harness/managed" "$work/u87-mf2" && ok || bad "the refused render rewrote the manifest"
rmdir "$u/script/review-mr.sh"
cat "$work"/u87-*.out "$work"/u87-*.err > "$work/u87-all.log"; no_hangul "$work/u87-all.log" "user file refusal output"

echo "UT-88 the manifest of managed files and the pinned copy: sha256 lines, the old path-list form, and comparing against it"
# 경로만 적힌 매니페스트로는 관리 파일과 고정 사본이 설치 뒤 바뀌었는지 알 수 없다.
t="$work/mf88"; rm -rf "$t"; mkdir -p "$t"
( cd "$t" && git init -q . )
"$root/bin/harness" install --target "$t" >/dev/null 2>&1; check "install on a new repo" "$?" "0"
python3 - "$t/.harness/managed" > "$work/mf88-form" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
assert lines[-1] == "", "the manifest does not end with a newline"
lines = lines[:-1]
paths = [ln[66:] for ln in lines]
print(all(re.fullmatch(r"[0-9a-f]{64}  .+", ln) for ln in lines), paths == sorted(paths))
print(" ".join(p for p in ("script/review-mr.sh", ".harness/bin/harness", ".harness/VERSION",
                           ".harness/templates/harness.toml") if p in paths))
print(sum("__pycache__" in p for p in paths))
PY
check "every line is a sha256 and a path, in path order" "$(sed -n 1p "$work/mf88-form")" "True True"
check "managed files and the pinned copy are listed" "$(sed -n 2p "$work/mf88-form")" \
  "script/review-mr.sh .harness/bin/harness .harness/VERSION .harness/templates/harness.toml"
check "no bytecode is listed" "$(sed -n 3p "$work/mf88-form")" "0"
( cd "$t" && shasum -a 256 -c .harness/managed >/dev/null 2>&1 ); check "shasum -a 256 -c reads the manifest" "$?" "0"
line_of() { grep -F "  $2" "$1/.harness/managed" | cut -c1-64; }
old_form() { # old_form <리포> — 매니페스트를 해시 없는 경로 목록(옛 형식)으로 바꾼다
  python3 - "$1/.harness/managed" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
p.write_text(re.sub(r"^[0-9a-f]{64}  ", "", p.read_text(encoding="utf-8"), flags=re.M), encoding="utf-8")
PY
  grep -qE '^[0-9a-f]{64}  ' "$1/.harness/managed" && bad "$1: the manifest still has hashes" || ok
}
pin_before=$(line_of "$t" ".harness/templates/harness.toml")
printf '\n# edited by hand\n' >> "$t/.harness/templates/harness.toml"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
check "render does not hash the pinned copy again" "$(line_of "$t" ".harness/templates/harness.toml")" "$pin_before"
# 설정을 바꿔 정리가 돌아도 고정 사본은 남는다
"$root/bin/harness" set --target "$t" branches.base trunk >/dev/null 2>&1; check "set exit code" "$?" "0"
[ -f "$t/.harness/bin/harness" ] && ok || bad "pruning removed the pinned copy"
# 재설치는 매니페스트를 남기고 사본 줄만 새 사본의 것으로 바꾼다
review_before=$(line_of "$t" "script/review-mr.sh")
"$root/bin/harness" install --target "$t" >/dev/null 2>&1; check "reinstall exit code" "$?" "0"
[ -f "$t/.harness/generated" ] && [ -f "$t/.harness/managed" ] && ok || bad "reinstall dropped a manifest"
check "a managed file line survives the reinstall" "$(line_of "$t" "script/review-mr.sh")" "$review_before"
( cd "$t" && shasum -a 256 -c .harness/managed >/dev/null 2>&1 ); check "the pinned lines are the new copy's" "$?" "0"
# 옛 형식(경로 목록)을 읽어 정리하고, 다음 render 가 새 형식으로 쓴다
old_form "$t"
[ -f "$t/.ai/templates/security-guard.md" ] && ok || bad "the role's contract was not installed"
python3 - "$t/harness.toml" <<'DROP'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
p.write_text(re.sub(r"\n\[roles\.security-guard\][^\[]*", "\n", p.read_text(encoding="utf-8")), encoding="utf-8")
DROP
"$root/bin/harness" render --target "$t" > "$work/mf88-old.out" 2>&1; check "render over an old manifest" "$?" "0"
[ -e "$t/.ai/templates/security-guard.md" ] && bad "an old manifest did not prune the dropped contract" || ok
grep -qvE '^[0-9a-f]{64}  .+$' "$t/.harness/managed" && bad "render left the manifest in the old form" || ok
# 소스 리포는 사본이 없다 — 사본 줄을 쓰지 않는다
src="$work/source88"; rm -rf "$src"; mkdir -p "$src/src/bin"
cp "$root/bin/harness" "$root/bin/harness_metrics.py" "$src/src/bin/"; cp -R "$root/templates" "$src/src/templates"
( cd "$src" && git init -q . )
"$src/src/bin/harness" install --target "$src" >/dev/null 2>&1; check "install on the source tree" "$?" "0"
grep -q '  \.harness/' "$src/.harness/managed" && bad "the source tree's manifest lists a pinned copy" || ok
grep -q '  script/review-mr.sh$' "$src/.harness/managed" && ok || bad "the source tree's manifest lacks the managed files"

# check 가 관리 파일과 고정 사본을 매니페스트와 대조한다
c="$work/chk88"; rm -rf "$c"; mkdir -p "$c"; ( cd "$c" && git init -q . )
"$root/bin/harness" install --target "$c" >/dev/null 2>&1 || bad "could not install the check repo"
"$root/bin/harness" check --target "$c" > "$work/c88-0.out" 2> "$work/c88-0.err"; check "check right after install" "$?" "0"
has "$work/c88-0.out" "managed files match the manifest" "a passing check does not report the managed files"
printf '\n# edited by hand\n' >> "$c/script/review-mr.sh"
"$root/bin/harness" check --target "$c" > "$work/c88-1.out" 2> "$work/c88-1.err"; check "check with an edited managed file" "$?" "1"
grep -qE '^  script/review-mr.sh +modified managed file$' "$work/c88-1.err" && ok || bad "check does not name the edited managed file"
has "$work/c88-1.err" "project scripts belong in script/project/" "the help does not point at script/project/"
hasnt "$work/c88-1.err" "comes back with \`harness install\`" "only managed files changed, yet the help names harness install"
"$root/bin/harness" render --target "$c" >/dev/null 2>&1
"$root/bin/harness" check --target "$c" > "$work/c88-2.out" 2> "$work/c88-2.err"; check "check after render puts it back" "$?" "0"
rm "$c/script/review-mr.sh"
"$root/bin/harness" check --target "$c" > "$work/c88-3.out" 2> "$work/c88-3.err"; check "check with a missing managed file" "$?" "1"
grep -qE '^  script/review-mr.sh +missing managed file$' "$work/c88-3.err" && ok || bad "check does not name the missing managed file"
"$root/bin/harness" render --target "$c" >/dev/null 2>&1
# 생성 파일과 관리 파일이 함께 어긋나면 둘 다 보고한다
printf '\nedited\n' >> "$c/AGENTS.md"; printf '\n# edited\n' >> "$c/script/review-mr.sh"
"$root/bin/harness" check --target "$c" > "$work/c88-4.out" 2> "$work/c88-4.err"; check "check with both kinds of drift" "$?" "1"
has "$work/c88-4.err" "generated files do not match the config" "the generated drift is not reported beside the managed one"
has "$work/c88-4.err" "managed files differ from what the harness installed" "the managed drift is not reported beside the generated one"
"$root/bin/harness" render --target "$c" >/dev/null 2>&1
# staged — 인덱스의 내용과 비교한다
( cd "$c" && git add -A ) || bad "could not stage the check repo"
"$root/bin/harness" check --target "$c" --staged > "$work/c88-5.out" 2> "$work/c88-5.err"; check "check --staged on a clean index" "$?" "0"
printf '\n# edited\n' >> "$c/script/review-mr.sh"
"$root/bin/harness" check --target "$c" --staged > "$work/c88-6.out" 2> "$work/c88-6.err"; check "check --staged with an unstaged edit" "$?" "0"
( cd "$c" && git add script/review-mr.sh )
"$root/bin/harness" check --target "$c" --staged > "$work/c88-7.out" 2> "$work/c88-7.err"; check "check --staged with a staged edit" "$?" "1"
has "$work/c88-7.err" "script/review-mr.sh" "check --staged does not name the staged managed file"
"$root/bin/harness" render --target "$c" >/dev/null 2>&1; ( cd "$c" && git add -A )
# 고정 사본 — render 는 되돌리지 않는다. install 이 되돌린다
printf '\n# edited by hand\n' >> "$c/.harness/templates/managed/script/review-mr.sh"
"$root/bin/harness" check --target "$c" > "$work/c88-8.out" 2> "$work/c88-8.err"; check "check with an edited pinned copy" "$?" "1"
has "$work/c88-8.err" ".harness/templates/managed/script/review-mr.sh" "check does not name the edited pinned file"
has "$work/c88-8.err" "comes back with \`harness install\`" "the help does not name harness install for the pinned copy"
"$root/bin/harness" render --target "$c" >/dev/null 2>&1
"$root/bin/harness" check --target "$c" > "$work/c88-9.out" 2> "$work/c88-9.err"; check "check after render, pinned copy still edited" "$?" "1"
"$root/bin/harness" install --target "$c" >/dev/null 2>&1
"$root/bin/harness" check --target "$c" > "$work/c88-10.out" 2> "$work/c88-10.err"; check "check after install restores the copy" "$?" "0"
# 옛 형식 매니페스트는 비교할 해시가 없다
old_form "$c"
"$root/bin/harness" check --target "$c" > "$work/c88-11.out" 2> "$work/c88-11.err"; check "check over an old manifest" "$?" "0"
has "$work/c88-11.out" "check: 0 managed files match the manifest" "an old manifest was compared"
cat "$work"/c88-*.out "$work"/c88-*.err > "$work/c88-all.log"; no_hangul "$work/c88-all.log" "managed file check output"

# doctor 의 관리 파일 절 — harness status 의 doctor.items 로 본다
mitems() { # mitems <리포> — 관리 파일 절의 항목을 한 줄에 하나 `state|what|detail` 로 찍는다
  "$root/bin/harness" status --target "$1" > "$work/mi.json" 2>> "$work/mi-all.log"
  python3 - "$work/mi.json" <<'PY'
import json, sys
for i in json.load(open(sys.argv[1], encoding="utf-8"))["doctor"]["items"]:
    if i["section"] == "managed files":
        print("%s|%s|%s" % (i["state"], i["what"], i["detail"]))
PY
}
d="$work/doc88"; rm -rf "$d" "$work/mi-all.log"; mkdir -p "$d"; ( cd "$d" && git init -q . )
"$root/bin/harness" install --target "$d" >/dev/null 2>&1 || bad "could not install the doctor repo"
n_hashed=$(grep -c . "$d/.harness/managed")
check "right after install the section is one ok item" "$(mitems "$d")" "ok|$n_hashed managed files match the manifest|"
"$root/bin/harness" status --target "$d" > "$work/mi.json" 2>/dev/null
python3 - "$work/mi.json" > "$work/mi-order" <<'PY'
import json, sys
secs = list(dict.fromkeys(i["section"] for i in json.load(open(sys.argv[1], encoding="utf-8"))["doctor"]["items"]))
print(secs[secs.index("generated files") + 1])
PY
check "the section comes right after generated files" "$(cat "$work/mi-order")" "managed files"
printf '\n# edited\n' >> "$d/script/review-mr.sh"
check "an edited managed file is a bad item" "$(mitems "$d")" "bad|modified managed file|script/review-mr.sh"
"$root/bin/harness" render --target "$d" >/dev/null 2>&1
rm "$d/script/review-mr.sh"
check "a missing managed file is a bad item" "$(mitems "$d")" "bad|missing managed file|script/review-mr.sh"
"$root/bin/harness" render --target "$d" >/dev/null 2>&1
for f in $(sed -E 's/^[0-9a-f]{64}  //' "$d/.harness/managed" | grep '^script/' | head -11); do printf '\n# edited\n' >> "$d/$f"; done
mitems "$d" > "$work/mi-11"
check "eleven edited files show ten paths" "$(grep -c '^bad|modified managed file|script/' "$work/mi-11")" "10"
grep -qx 'bad|1 more modified or missing managed file(s)|' "$work/mi-11" && ok || bad "the eleventh file is not summed up: $(tail -1 "$work/mi-11")"
"$root/bin/harness" render --target "$d" >/dev/null 2>&1
old_form "$d"
n_managed=$(grep -vc '^\.harness/' "$d/.harness/managed")
mitems "$d" > "$work/mi-old"
grep -qx "warn|$n_managed managed files have no recorded hash|run \`harness render\`" "$work/mi-old" && ok || bad "an old manifest is not reported: $(cat "$work/mi-old")"
grep -qx "warn|the pinned copy has no recorded hash|run \`harness install\`" "$work/mi-old" && ok || bad "an old manifest's pinned copy is not reported"
grep -q '^bad|' "$work/mi-old" && bad "an old manifest produced a bad item" || ok
rm "$d/.harness/managed"
check "without a manifest the section is one warn item" "$(mitems "$d")" "warn|no manifest of managed files|run \`harness render\`"
no_hangul "$work/mi-all.log" "status output for managed files"

echo "UT-89 the global CLI compares the pinned copy with its own files before it delegates, when the versions match"
# 사본을 고치면 그 사본이 도는 검사가 모두 고친 기준으로 돈다. 리포 밖의 기준은 같은 버전의 전역 CLI 뿐이다.
p="$work/pin89"; rm -rf "$p"; mkdir -p "$p"; ( cd "$p" && git init -q . )
"$root/bin/harness" install --target "$p" >/dev/null 2>&1 || bad "could not install the pinned repo"
"$root/bin/harness" doctor --target "$p" > "$work/p89-1.out" 2> "$work/p89-1.err"
hasnt "$work/p89-1.err" "warning:" "an untouched copy raised a warning"
hasnt "$work/p89-1.err" "cannot verify" "an untouched copy of the same version could not be verified"
printf '\n# edited by hand\n' >> "$p/.harness/templates/managed/script/review-mr.sh"
"$root/bin/harness" doctor --target "$p" > "$work/p89-2.out" 2> "$work/p89-2.err"; rc_edit=$?
has "$work/p89-2.err" "warning: the pinned harness differs" "an edited template raised no warning"
has "$work/p89-2.err" "  --> .harness/templates/managed/script/review-mr.sh" "the warning does not name the edited template"
has "$work/p89-2.err" "harness install --target" "the warning does not say how to restore the copy"
# 경고는 넘기기를 막지 않는다. doctor 는 그 사본이 돈다 — 관리 파일 절이 그 변경을 실패로 센다
check "doctor still runs through the pinned copy" "$( [ "$rc_edit" -le 1 ] && grep -q 'managed files' "$work/p89-2.out" && echo yes)" "yes"
"$root/bin/harness" status --target "$p" > "$work/p89-3.out" 2> "$work/p89-3.err"; check "status exit code" "$?" "0"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$work/p89-3.out"; check "status output is still JSON" "$?" "0"
has "$work/p89-3.err" "warning: the pinned harness differs" "status raised no warning on stderr"
"$root/bin/harness" install --target "$p" >/dev/null 2>&1
printf '\n# edited\n' >> "$p/.harness/bin/harness"
"$root/bin/harness" doctor --target "$p" > "$work/p89-4.out" 2> "$work/p89-4.err"
has "$work/p89-4.err" "  --> .harness/bin/harness" "an edited pinned CLI is not named"
"$root/bin/harness" install --target "$p" >/dev/null 2>&1
printf 'extra\n' > "$p/.harness/bin/extra.py"
"$root/bin/harness" doctor --target "$p" > "$work/p89-5.out" 2> "$work/p89-5.err"
has "$work/p89-5.err" "  --> .harness/bin/extra.py" "a file only the copy has is not named"
"$root/bin/harness" install --target "$p" >/dev/null 2>&1
for f in $(cd "$p/.harness/templates/managed/script" && ls *.sh | head -11); do printf '\n# edited\n' >> "$p/.harness/templates/managed/script/$f"; done
"$root/bin/harness" doctor --target "$p" > "$work/p89-6.out" 2> "$work/p89-6.err"
check "ten files are named" "$(grep -c '^  --> ' "$work/p89-6.err")" "10"
has "$work/p89-6.err" "  ... and 1 more" "the eleventh file is not summed up"
"$root/bin/harness" install --target "$p" >/dev/null 2>&1
# 사본의 파일을 읽지 못하면 같다고 보지 않는다 — 대조하지 못했다고 알리고 넘긴다. root 는 권한을 무시하므로 만들 수 없다
if [ "$(id -u)" != 0 ]; then
  chmod 000 "$p/.harness/templates/harness.toml"
  "$root/bin/harness" schema --target "$p" > "$work/p89-10.out" 2> "$work/p89-10.err"
  chmod 644 "$p/.harness/templates/harness.toml"
  has "$work/p89-10.err" "warning: could not compare the pinned harness" "an unreadable pinned file passed as a match"
  has "$work/p89-10.err" "  --> .harness/templates/harness.toml" "the warning does not name the unreadable file"
  has "$work/p89-10.err" "harness install --target" "the warning does not say how to restore the copy"
fi
# 버전이 다르거나 없으면 비교하지 않는다
echo "0.0.9" > "$p/.harness/VERSION"
"$root/bin/harness" doctor --target "$p" > "$work/p89-7.out" 2> "$work/p89-7.err"
check "one cannot-verify line for another version" "$(grep -c 'cannot verify the pinned harness' "$work/p89-7.err")" "1"
has "$work/p89-7.err" "the project pins 0.0.9" "the cannot-verify line does not name the pinned version"
hasnt "$work/p89-7.err" "warning: the pinned harness differs" "another version was compared"
rm "$p/.harness/VERSION"
"$root/bin/harness" doctor --target "$p" > "$work/p89-8.out" 2> "$work/p89-8.err"
has "$work/p89-8.err" "the project pins no version" "the cannot-verify line does not say there is no version"
# 소스 리포는 사본이 없다 — 대조도 줄도 없다
src="$work/source89"; rm -rf "$src"; mkdir -p "$src/src/bin"
cp "$root/bin/harness" "$root/bin/harness_metrics.py" "$src/src/bin/"; cp -R "$root/templates" "$src/src/templates"
( cd "$src" && git init -q . )
"$src/src/bin/harness" install --target "$src" >/dev/null 2>&1 || bad "could not install the source tree"
"$root/bin/harness" doctor --target "$src" > "$work/p89-9.out" 2> "$work/p89-9.err"
hasnt "$work/p89-9.err" "warning:" "the source tree raised a warning"
hasnt "$work/p89-9.err" "cannot verify" "the source tree printed a cannot-verify line"
cat "$work"/p89-*.out "$work"/p89-*.err > "$work/p89-all.log"; no_hangul "$work/p89-all.log" "pinned copy comparison output"

echo "UT-102 the harness version carries the source commit, from git in a checkout and from the Homebrew receipt in a keg"
# 번호만으로는 프로젝트가 고정한 사본이 전역보다 뒤처졌는지 알 수 없다 — 번호가 커밋마다 바뀌지 않는다.
base=$(sed -n 's/^version = "\(.*\)"$/\1/p' "$root/templates/harness.toml" | head -1)
want="$base+$(git -C "$root/.." rev-parse --short=7 HEAD)"
[ -n "$(git -C "$root/.." status --porcelain -- src)" ] && want="$want-dirty"
check "the checkout's version" "$("$root/bin/harness" version)" "harness $want"
p="$work/ver102"; rm -rf "$p"; mkdir -p "$p"; ( cd "$p" && git init -q . )
"$root/bin/harness" install --target "$p" >/dev/null 2>&1; check "install from the checkout exits 0" "$?" "0"
check "install pins the checkout's version" "$(cat "$p/.harness/VERSION")" "$want"
# Homebrew 설치본 — 영수증의 커밋을 쓴다
k="$work/keg102"; rm -rf "$k"; mkdir -p "$k/libexec" "$k/bin"
cp -R "$root/bin" "$root/templates" "$k/libexec/"; ln -s "$k/libexec/bin/harness" "$k/bin/harness"
printf '{"source": {"scm_revision": "d5d3b93b63d60e53f56993f72e3798a84cefb27d"}}\n' > "$k/INSTALL_RECEIPT.json"
check "the keg's version" "$("$k/bin/harness" version)" "harness $base+d5d3b93"
q="$work/ver102-keg"; rm -rf "$q"; mkdir -p "$q"; ( cd "$q" && git init -q . )
"$k/bin/harness" install --target "$q" >/dev/null 2>&1; check "install from the keg exits 0" "$?" "0"
check "install pins the keg's version" "$(cat "$q/.harness/VERSION")" "$base+d5d3b93"
# 영수증이 없거나 커밋이 아닌 값이면 번호만 낸다
printf '{"source": {"scm_revision": "../../etc"}}\n' > "$k/INSTALL_RECEIPT.json"
check "a receipt without a commit gives the bare number" "$("$k/bin/harness" version)" "harness $base"
rm "$k/INSTALL_RECEIPT.json"
check "no receipt gives the bare number" "$("$k/bin/harness" version)" "harness $base"
# 다른 커밋을 고정한 프로젝트는 넘길 때 그 사실과 올리는 명령을 알린다
echo "$base+0000000" > "$p/.harness/VERSION"
"$root/bin/harness" doctor --target "$p" > "$work/ver102-old.out" 2> "$work/ver102-old.err"
has "$work/ver102-old.err" "this project is pinned to harness $base+0000000 (global is $want)" "an older pinned commit is not reported"
has "$work/ver102-old.err" "to upgrade the project, run: harness install" "the note does not say how to upgrade"

echo "UT-95 a block that never finishes is stopped and named with what was still running, instead of hanging the run"
# 어느 블록의 어느 명령이 멈추든 이 테스트 전체가 진행 없이 기다린다. 블록 감시가 그것을 실패와 위치로 바꾼다.
# 실제 시각에 기대지 않는다 — 판정은 시각을 넘겨받는 Blocks 로, 종료 절차는 바꿔 끼운 시계로 본다.
wd="$work/watch"; rm -rf "$wd"; mkdir -p "$wd/nops" "$wd/denyps" "$wd/failps" "$wd/emptyps" "$wd/otherps" "$wd/hangps"
: > "$wd/denyps/ps"                                   # 실행 권한이 없는 ps
printf '#!/bin/sh\nexit 1\n' > "$wd/failps/ps"; chmod +x "$wd/failps/ps"
printf '#!/bin/sh\nexit 0\n' > "$wd/emptyps/ps"; chmod +x "$wd/emptyps/ps"          # 성공했지만 아무것도 내지 않는 ps
printf '#!/bin/sh\necho "1 1 /sbin/init"\n' > "$wd/otherps/ps"; chmod +x "$wd/otherps/ps"  # 다른 그룹만 내는 ps
printf '#!/bin/sh\nexec /bin/sleep 100000\n' > "$wd/hangps/ps"; chmod +x "$wd/hangps/ps"
cat > "$wd/hang.sh" <<'SH'
#!/bin/bash
# 끝나지 않는 블록. 손자 프로세스를 남기고, 그 번호를 적은 뒤에 표지를 낸다
export PATH=/usr/bin:/bin
( while :; do sleep 1; done ) &
echo "$!" > "$WATCH_DIR/$CASE.pid"
printf '%s\n' "UT-01 stuck"
while :; do sleep 1; done
SH
cat > "$wd/done.sh" <<'SH'
#!/bin/bash
# 제때 끝나는 본문. 표준 입력에서 무언가 읽히면 바깥 입력을 물려받은 것이다
touch "$WATCH_DIR/$CASE.started"
printf '%s\n' "UT-01 first" "UT-02 second"
if read -r _; then echo "read from the caller's stdin"; exit 1; fi
exit 3
SH
# 감시를 모듈로 불러 시계를 바꿔 끼우고 main 을 부른다.
#   jump   — 첫 표지를 읽은 뒤로 부를 때마다 1000초씩 간다: 그 블록은 반드시 제한을 넘긴다
#   frozen — 시계가 서 있다: 어느 블록도 제한을 넘기지 않는다
cat > "$wd/drive.py" <<'PY'
import os
ns = {"__name__": "watch"}
exec(os.environ["WATCH_PY"], ns)
t = [0]
def jump():
    if ns["current"] is not None and ns["current"].block == "UT-01":
        t[0] += 1000
    return t[0]
ns["now"] = jump if os.environ["CLOCK"] == "jump" else (lambda: 0)
if os.environ.get("WATCH_PATH") is not None:
    os.environ["PATH"] = os.environ["WATCH_PATH"]
ns["main"](["/bin/bash", os.path.join(os.environ["WATCH_DIR"], os.environ["BODY"])])
PY
drive() { # drive <사례> <시계> <본문> [<ps 를 찾을 PATH>] — 종료 코드를 돌려준다
  local py; py=$(command -v python3)
  WATCH_PY="$watch_py" WATCH_DIR="$wd" CASE=$1 CLOCK=$2 BODY=$3 RENDER_TEST_BLOCK_LIMIT=${LIMIT-60} \
    env ${4+"WATCH_PATH=$4"} "$py" "$wd/drive.py" >"$wd/$1.out" 2>"$wd/$1.err"
}
gone() { # gone <pid> — 그 프로세스가 끝났는가(좀비 포함). 끝내기 신호가 닿을 때까지 잠깐 기다린다
  local i st
  for i in $(seq 1 100); do
    st=$(ps -o stat= -p "$1" 2>/dev/null | tr -d ' ')
    case "$st" in ""|Z*) return 0 ;; esac
    sleep 0.1
  done
  return 1
}
# 제한 판정 — 시각을 넘겨 본다
WATCH_PY="$watch_py" python3 - > "$wd/unit.out" <<'PY'
import os
ns = {"__name__": "watch"}
exec(os.environ["WATCH_PY"], ns)
B, parse = ns["Blocks"], ns["parse_limit"]
b = B(2, 0)
print(b.block, b.expired(1.9), b.expired(2))
b.line(b"UT-01 first\n", 1.5)
print(b.block, b.expired(3.4), b.expired(3.5))
b.line(b"  FAIL: UT-02 not a marker\n", 3.0)
print(b.block, b.expired(3.5))
b.line(b"UT-07c with a suffix\n", 10)
print(b.block, b.expired(11.9), b.expired(12))
print([parse(v) for v in ("900", "0.5", "nan", "0", "-5", "abc", "inf", "-inf", "")])
PY
check "the limit is judged per block, from the time its marker was read" "$(cat "$wd/unit.out")" \
"(before the first block) False True
UT-01 False True
UT-01 True
UT-07c False True
[900.0, 0.5, None, None, None, None, None, None, None]"
# 멈춘 블록 — 이름과 남은 명령을 보고하고, 진단이 어떻게 되든 그룹째 끝내고 124
for c in normal:"$PATH" nops:"$wd/nops" denyps:"$wd/denyps" failps:"$wd/failps" \
         emptyps:"$wd/emptyps" otherps:"$wd/otherps" hangps:"$wd/hangps"; do
  name=${c%%:*}; drive "$name" jump hang.sh "${c#*:}"; check "$name: exit code of a stopped run" "$?" "124"
  has "$wd/$name.err" "render-test: UT-01 did not finish within 60s and was stopped" "$name: the failure does not name the stuck block and the limit"
  has "$wd/$name.out" "UT-01 stuck" "$name: the watched run's output did not pass through"
  pid=$(cat "$wd/$name.pid" 2>/dev/null)
  if [ -z "$pid" ]; then bad "$name: the stuck block did not record its child"
  elif gone "$pid"; then ok; else bad "$name: stopping the run left a child running"; kill "$pid" 2>/dev/null; fi
  no_hangul "$wd/$name.err" "$name: the stopped run report"
done
has "$wd/normal.err" "hang.sh" "the failure does not name the command that was still running"
has "$wd/normal.err" "still running:" "a working diagnosis does not list what was still running"
hasnt "$wd/normal.err" "could not list" "a working diagnosis was reported as failed"
for name in nops denyps failps emptyps otherps hangps; do
  has "$wd/$name.err" "could not list what was still running" "$name: a failed diagnosis is not reported as such"
done
# 제때 끝나는 본문 — 종료 코드 그대로, 멈춤 보고 없음, 바깥 입력을 받지 않는다
rc=$(yes | { drive done frozen done.sh; echo $?; }); check "a run that finishes keeps its exit code, and does not read the caller's stdin" "$rc" "3"
hasnt "$wd/done.err" "was stopped" "a run that finished was stopped"
# 유한한 양수가 아닌 제한 시간은 아무것도 띄우지 않고 바로 거부한다
for v in nan 0 -5 abc inf ""; do
  LIMIT=$v drive bad frozen done.sh; check "limit '$v' is refused" "$?" "2"
  has "$wd/bad.err" "RENDER_TEST_BLOCK_LIMIT must be a positive number of seconds" "limit '$v' is refused without saying why"
  [ -e "$wd/bad.started" ] && bad "limit '$v' still started the run" || ok
done
env -u RENDER_TEST_WATCHED RENDER_TEST_BLOCK_LIMIT=nan "$root/test/render-test.sh" >/dev/null 2>"$wd/top.err"
check "render-test refuses a limit that is not a positive number" "$?" "2"
has "$wd/top.err" "RENDER_TEST_BLOCK_LIMIT must be a positive number of seconds" "render-test does not say why it refused the limit"
unset -f drive gone

echo "UT-96 install turns git hooks on only when core.hooksPath is empty, and install, doctor and uninstall judge the value by the harness root it points at"
# 훅이 꺼진 채면 커밋 형식·시크릿 스캔·생성물 검사가 하나도 돌지 않는다. 남이 둔 설정을 덮으면 그 도구의 훅이 사라진다.
h96() { HARNESS_HOME="$work/home96" "$root/bin/harness" "$@"; }
hp96() { git -C "$1" config core.hooksPath || echo "(none)"; }
hk_item() { # hk_item <대상> — doctor --json 의 `git hooks enabled` 항목의 state 와 detail
  "$root/bin/harness" doctor --json --target "$1" 2>/dev/null | python3 -c '
import json, sys
hit = [i for i in json.load(sys.stdin)["items"] if i["what"] == "git hooks enabled"]
print("%s|%s" % (hit[0]["state"], hit[0]["detail"]) if hit else "none")'
}
hk="$work/hk"; rm -rf "$hk"; mkdir -p "$hk"
# 빈 값 — 켠다. `.sample` 훅만 있으면 비어 있는 것으로 본다
t="$hk/empty"; mkdir -p "$t"; ( cd "$t" && git init -q . )
mkdir -p "$t/.git/hooks"; : > "$t/.git/hooks/pre-commit.sample"
h96 install --target "$t" > "$work/hk-empty.out" 2>&1; check "install into an empty setting exits 0" "$?" "0"
check "an empty setting is set to the hooks directory" "$(hp96 "$t")" "script/githooks"
has "$work/hk-empty.out" "install: set core.hooksPath to script/githooks" "install does not say it set core.hooksPath"
# 재설치 — 켜진 값은 그대로이고 다시 알리지 않는다
h96 install --target "$t" > "$work/hk-again.out" 2>&1; check "reinstall exits 0" "$?" "0"
check "reinstall keeps the value" "$(hp96 "$t")" "script/githooks"
hasnt "$work/hk-again.out" "set core.hooksPath" "reinstall announced the hooks again"
# 다른 값 — 두고 켜는 명령을 알린다
t="$hk/other"; mkdir -p "$t"; ( cd "$t" && git init -q . && git config core.hooksPath .husky )
h96 install --target "$t" > "$work/hk-other.out" 2>&1; check "install over another value exits 0" "$?" "0"
check "another value is left as is" "$(hp96 "$t")" ".husky"
has "$work/hk-other.out" "core.hooksPath is already .husky — left as is" "install does not say it left the other value"
has "$work/hk-other.out" "git config core.hooksPath script/githooks" "install does not give the command that turns the hooks on"
hasnt "$work/hk-other.out" "set core.hooksPath to" "install claims it set a value it left"
# 자기 훅 — 값이 비어 있어도 `.git/hooks/` 의 훅을 가리지 않는다
t="$hk/own"; mkdir -p "$t"; ( cd "$t" && git init -q . )
mkdir -p "$t/.git/hooks"; printf '#!/bin/sh\nexit 0\n' > "$t/.git/hooks/pre-commit"; chmod +x "$t/.git/hooks/pre-commit"
h96 install --target "$t" > "$work/hk-own.out" 2>&1; check "install over own hooks exits 0" "$?" "0"
check "own hooks keep the setting empty" "$(hp96 "$t")" "(none)"
has "$work/hk-own.out" "pre-commit" "install does not name the hook it found"
has "$work/hk-own.out" "left as is" "install does not say it left the own hooks"
has "$work/hk-own.out" "git config core.hooksPath script/githooks" "install does not give the command for own hooks"
# git 밖 — 실패가 아니다
t="$hk/nogit"; mkdir -p "$t"
h96 install --target "$t" > "$work/hk-nogit.out" 2>&1; check "install outside git exits 0" "$?" "0"
has "$work/hk-nogit.out" "install: not a git repository — git hooks were not enabled" "install outside git does not say the hooks are off"
has "$work/hk-nogit.out" "git config core.hooksPath script/githooks" "install outside git does not give the command"
# 모노레포 — 서브프로젝트의 기대 값으로 켜고, 둘째 서브프로젝트는 첫째의 값을 둔다
m="$hk/mono"; mkdir -p "$m/packages/api" "$m/packages/web"; ( cd "$m" && git init -q . )
h96 install --target "$m/packages/api" > "$work/hk-mono.out" 2>&1; check "install into a subproject exits 0" "$?" "0"
check "a subproject sets its own hooks path" "$(hp96 "$m")" "packages/api/script/githooks"
has "$work/hk-mono.out" "set core.hooksPath to packages/api/script/githooks" "install does not name the subproject's value"
h96 install --target "$m/packages/web" > "$work/hk-mono2.out" 2>&1; check "install into a second subproject exits 0" "$?" "0"
check "a second subproject keeps the first one's value" "$(hp96 "$m")" "packages/api/script/githooks"
has "$work/hk-mono2.out" "git config core.hooksPath packages/web/script/githooks" "the second subproject does not give its own command"
# doctor · uninstall 도 서브프로젝트의 기대 값으로 가른다 — 리포 루트의 값은 서브프로젝트의 훅이 아니다
check "a subproject's doctor sees its own hooks on" "$(hk_item "$m/packages/api")" "ok|"
check "a sibling subproject's doctor sees its hooks off, with its own command" "$(hk_item "$m/packages/web")" \
  "bad|run \`git config core.hooksPath packages/web/script/githooks\`"
m2="$hk/mono-root"; mkdir -p "$m2/packages/svc"; ( cd "$m2" && git init -q . && git config core.hooksPath script/githooks )
h96 install --target "$m2/packages/svc" > "$work/hk-mono3.out" 2>&1; check "install under a root value exits 0" "$?" "0"
check "the repository root's value is left as is" "$(hp96 "$m2")" "script/githooks"
check "a subproject's doctor does not take the root value as its hooks" "$(hk_item "$m2/packages/svc")" \
  "bad|run \`git config core.hooksPath packages/svc/script/githooks\`"
h96 uninstall --target "$m/packages/web" > "$work/hk-rm-web.out" 2>&1; check "uninstall of the second subproject exits 0" "$?" "0"
check "uninstall keeps a value that points at another subproject" "$(hp96 "$m")" "packages/api/script/githooks"
hasnt "$work/hk-rm-web.out" "unset core.hooksPath" "uninstall announced unsetting a value it kept"
h96 uninstall --target "$m/packages/api" > "$work/hk-rm-api.out" 2>&1; check "uninstall of the first subproject exits 0" "$?" "0"
check "uninstall clears the subproject's own value" "$(hp96 "$m")" "(none)"
has "$work/hk-rm-api.out" "unset core.hooksPath" "uninstall does not say it cleared the value"
h96 uninstall --target "$hk/other" > "$work/hk-rm-other.out" 2>&1; check "uninstall over another tool's value exits 0" "$?" "0"
check "uninstall keeps another tool's value" "$(hp96 "$hk/other")" ".husky"
cat "$work"/hk-*.out > "$work/hk-all.log"; no_hangul "$work/hk-all.log" "install hooks output"
unset -f h96 hp96 hk_item

echo "UT-97 render makes the forge's issue and review request templates from the .ai/templates forms and the issue labels"
# 양식을 손으로 옮겨 두면 양식이 바뀔 때 템플릿만 옛 내용으로 남는다. 라벨이 설정과 다르면 사람이 만든 이슈가 라벨 없이 생긴다.
labels97() { # labels97 <대상> <requirement> <task> <invalid> — 이슈 라벨 줄을 그 값으로 바꾼다
  sedi "s|^labels = {.*}\$|labels = { requirement = \"$2\", task = \"$3\", invalid = \"$4\" }|" "$1/harness.toml"
}
t="$work/ftpl"; setup "$t"
labels97 "$t" Req-pinned Task-pinned invalid-pinned
"$root/bin/harness" set --target "$t" forge.tracker github forge.review_host github >/dev/null 2>&1; check "render with GitHub exits 0" "$?" "0"
for f in .github/ISSUE_TEMPLATE/requirement.md .github/ISSUE_TEMPLATE/task.md .github/pull_request_template.md; do
  [ -f "$t/$f" ] && ok || bad "GitHub template missing: $f"
  grep -qxF "$f" "$t/.harness/generated" && ok || bad "GitHub template not in the manifest: $f"
done
check "the requirement template head" "$(sed -n 1,6p "$t/.github/ISSUE_TEMPLATE/requirement.md")" '---
name: Requirement
about: 요구사항 이슈 — 브랜치 하나·리뷰 요청 하나의 단위
title: ""
labels: ["Req-pinned"]
---'
check "the task template labels" "$(sed -n 5p "$t/.github/ISSUE_TEMPLATE/task.md")" 'labels: ["Task-pinned"]'
check "a blank line follows the head" "$(sed -n 7p "$t/.github/ISSUE_TEMPLATE/task.md")" ""
tail -n +8 "$t/.github/ISSUE_TEMPLATE/requirement.md" | cmp -s - "$t/.ai/templates/issue-requirement.md" && ok || bad "the requirement template body is not the form"
tail -n +8 "$t/.github/ISSUE_TEMPLATE/task.md" | cmp -s - "$t/.ai/templates/issue-task.md" && ok || bad "the task template body is not the form"
cmp -s "$t/.github/pull_request_template.md" "$t/.ai/templates/mr.md" && ok || bad "the pull request template is not mr.md"
# 라벨을 바꾸면 따라 바뀐다. 빈 라벨은 빈 배열이다
labels97 "$t" Req-pinned Work-changed invalid-pinned
"$root/bin/harness" render --target "$t" >/dev/null 2>&1; check "render after a label change exits 0" "$?" "0"
check "the task template follows the label" "$(sed -n 5p "$t/.github/ISSUE_TEMPLATE/task.md")" 'labels: ["Work-changed"]'
labels97 "$t" "" Work-changed invalid-pinned
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
check "an empty label is an empty list" "$(sed -n 5p "$t/.github/ISSUE_TEMPLATE/requirement.md")" 'labels: []'
labels97 "$t" Req-pinned Work-changed invalid-pinned
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
# 손대면 check 가 잡는다
echo "hand edit" >> "$t/.github/pull_request_template.md"
"$root/bin/harness" check --target "$t" > "$work/ftpl-check.log" 2>&1; check "check over an edited template exits 1" "$?" "1"
has "$work/ftpl-check.log" ".github/pull_request_template.md" "check does not name the edited template"
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
# 트래커와 리뷰 호스트는 따로 적용된다 — Jira 트래커는 이슈 템플릿이 없다
"$root/bin/harness" set --target "$t" forge.tracker jira > "$work/ftpl-jira.log" 2>&1; check "render with a Jira tracker exits 0" "$?" "0"
[ -f "$t/.github/pull_request_template.md" ] && ok || bad "the pull request template is gone with a Jira tracker"
[ -e "$t/.github/ISSUE_TEMPLATE" ] && bad "issue templates are left with a Jira tracker" || ok
# GitLab — 템플릿이 옮겨 가고 GitHub 의 것은 지워진다
"$root/bin/harness" set --target "$t" forge.tracker gitlab forge.review_host gitlab >/dev/null 2>&1; check "render with GitLab exits 0" "$?" "0"
for f in .gitlab/issue_templates/Requirement.md .gitlab/issue_templates/Task.md .gitlab/merge_request_templates/Default.md; do
  [ -f "$t/$f" ] && ok || bad "GitLab template missing: $f"
done
[ -e "$t/.github/pull_request_template.md" ] && bad "the GitHub pull request template is left after moving to GitLab" || ok
check "the GitLab requirement template ends with the label action" "$(tail -1 "$t/.gitlab/issue_templates/Requirement.md")" '/label ~"Req-pinned"'
check "the GitLab task template ends with the label action" "$(tail -1 "$t/.gitlab/issue_templates/Task.md")" '/label ~"Work-changed"'
python3 - "$t/.gitlab/issue_templates/Task.md" "$t/.ai/templates/issue-task.md" <<'PY' && ok || bad "the GitLab task template is not the form with one blank line and the label action"
import sys
a, b = (open(p, encoding="utf-8").read() for p in sys.argv[1:])
sys.exit(0 if a == b + "\n" + '/label ~"Work-changed"\n' else 1)
PY
cmp -s "$t/.gitlab/merge_request_templates/Default.md" "$t/.ai/templates/mr.md" && ok || bad "the merge request template is not mr.md"
labels97 "$t" Req-pinned "" invalid-pinned
"$root/bin/harness" render --target "$t" >/dev/null 2>&1
cmp -s "$t/.gitlab/issue_templates/Task.md" "$t/.ai/templates/issue-task.md" && ok || bad "an empty label still added the label action"
# 서브프로젝트는 만들지 않는다 — forge 는 리포 루트의 템플릿만 읽는다
m="$work/ftpl-mono"; rm -rf "$m"; mkdir -p "$m/packages/tpl"; ( cd "$m" && git init -q . )
HARNESS_HOME="$work/home97" "$root/bin/harness" install --target "$m/packages/tpl" >/dev/null 2>&1; check "install into a subproject exits 0" "$?" "0"
[ -e "$m/packages/tpl/.github/ISSUE_TEMPLATE" ] || [ -e "$m/packages/tpl/.github/pull_request_template.md" ] \
  && bad "a subproject made forge templates" || ok
[ -e "$m/.github/ISSUE_TEMPLATE" ] && bad "a subproject wrote templates at the repository root" || ok
"$root/bin/harness" check --target "$m/packages/tpl" >/dev/null 2>&1; check "a subproject's check passes without templates" "$?" "0"
# 손으로 둔 템플릿은 덮지 않고 멈춘다. --adopt 면 옆으로 옮기고 넘겨받는다
a="$work/ftpl-adopt"; rm -rf "$a"; mkdir -p "$a/.github"; cp "$root/templates/harness.toml" "$a/harness.toml"
printf 'my own template\n' > "$a/.github/pull_request_template.md"
"$root/bin/harness" render --target "$a" > "$work/ftpl-adopt.log" 2>&1; check "render over a hand-made template exits 2" "$?" "2"
check "the hand-made template is untouched" "$(cat "$a/.github/pull_request_template.md")" "my own template"
has "$work/ftpl-adopt.log" ".github/pull_request_template.md" "the refusal does not name the template"
has "$work/ftpl-adopt.log" "--adopt" "the refusal does not mention --adopt"
"$root/bin/harness" render --target "$a" --adopt > "$work/ftpl-adopt2.log" 2>&1; check "render --adopt exits 0" "$?" "0"
check "the hand-made template moved aside" "$(cat "$a/.github/pull_request_template.md.orig")" "my own template"
cmp -s "$a/.github/pull_request_template.md" "$a/.ai/templates/mr.md" && ok || bad "the adopted path is not the generated template"
grep -qxF ".github/pull_request_template.md" "$a/.harness/generated" && ok || bad "the adopted template is not in the manifest"
grep -qF ".orig" "$a/.harness/generated" "$a/.harness/managed" && bad "the .orig file is in a manifest" || ok
has "$work/ftpl-adopt2.log" "render: adopted .github/pull_request_template.md — yours is at .github/pull_request_template.md.orig" "render --adopt does not say what it took over"
# 제거 — 템플릿은 지우고 CI 골격은 남긴다
[ -d "$a/.github/workflows" ] && ok || bad "the GitHub CI skeleton was not seeded"
"$root/bin/harness" uninstall --target "$a" >/dev/null 2>&1; check "uninstall exits 0" "$?" "0"
[ -e "$a/.github/pull_request_template.md" ] || [ -e "$a/.github/ISSUE_TEMPLATE" ] && bad "uninstall left a template" || ok
[ -d "$a/.github/workflows" ] && ok || bad "uninstall removed the CI skeleton"
[ -f "$a/.github/pull_request_template.md.orig" ] && ok || bad "uninstall removed the .orig file"
cat "$work"/ftpl-*.log > "$work/ftpl-all.log"; no_hangul "$work/ftpl-all.log" "forge template output"
unset -f labels97

echo "UT-98 harness forge-setup runs script/forge-setup.sh in the harness root and returns its exit code"
# 라벨이 처음 쓰일 때에야 만들어지면 권한 문제가 리뷰 루프 한가운데서 드러난다. 사람이 미리 한 번 부르는 명령이다.
t="$work/fsetup"; rm -rf "$t"; mkdir -p "$t"; ( cd "$t" && git init -q . )
HARNESS_HOME="$work/home98" "$root/bin/harness" install --target "$t" >/dev/null 2>&1 || bad "could not install for forge-setup"
cp "$root/test/fake-forge.sh" "$t/script/forge.sh"
mkdir -p "$work/fsetup-state"
FAKE_STATE="$work/fsetup-state" "$root/bin/harness" forge-setup --target "$t" > "$work/fsetup.out" 2> "$work/fsetup.err"
check "forge-setup with a working tracker exits 0" "$?" "0"
check "forge-setup passes the configured issue labels" "$(tr '\n' ' ' < "$work/fsetup-state/ensured_labels")" "Requirement Task invalid "
check "forge-setup says the labels are ready" "$(cat "$work/fsetup.out")" "forge-setup: labels ready on github: Requirement, Task, invalid"
printf '#!/usr/bin/env bash\necho "stub ran in $(pwd)"\nexit 7\n' > "$t/script/forge-setup.sh"
( cd "$work" && "$root/bin/harness" forge-setup --target "$t" > "$work/fsetup2.out" 2>&1 ); check "forge-setup returns the script's exit code" "$?" "7"
has "$work/fsetup2.out" "stub ran in $(cd "$t" && pwd -P)" "forge-setup did not run the script in the harness root"
rm -f "$t/script/forge-setup.sh"
"$root/bin/harness" forge-setup --target "$t" > "$work/fsetup3.out" 2>&1; check "forge-setup without the script exits 2" "$?" "2"
has "$work/fsetup3.out" "script/forge-setup.sh is missing" "forge-setup does not say the script is missing"
"$root/bin/harness" help > "$work/fsetup-help.out" 2>&1
has "$work/fsetup-help.out" "forge-setup" "help does not list forge-setup"
has "$work/fsetup-help.out" "writes to the remote" "help does not say forge-setup writes to the remote"
cat "$work"/fsetup*.out "$work/fsetup.err" > "$work/fsetup-all.log"; no_hangul "$work/fsetup-all.log" "forge-setup output"

echo "UT-99 an installed work-preflight reads the issue through the adapter and does not start on a closed or unreadable issue"
# 없는 번호나 닫힌 이슈에도 standalone 이 나오면 끝난 작업에 브랜치와 리뷰 요청이 새로 생긴다.
t="$work/preflight99"; rm -rf "$t"; mkdir -p "$t"; ( cd "$t" && git init -q . )
HARNESS_HOME="$work/home99" "$root/bin/harness" install --target "$t" >/dev/null 2>&1 || bad "could not install for work-preflight"
isolate_records "$t"
cp "$root/test/fake-forge.sh" "$t/script/forge.sh"
pstate="$work/preflight99-state"; mkdir -p "$pstate"
pf99() { ( cd "$t" && FAKE_STATE="$pstate" ./script/work-preflight.sh 100 ) > "$work/pf99.out" 2> "$work/pf99.err"; }
echo closed > "$pstate/issue_state"; pf99; check "a closed issue is not started" "$?" "1"
has "$work/pf99.err" "stop: issue 100 is closed" "work-preflight does not say the issue is closed"
echo fail > "$pstate/issue_state"; pf99; check "an unreadable issue stops the run" "$?" "2"
has "$work/pf99.err" "stop: could not read issue 100 from the tracker" "work-preflight does not say the issue could not be read"
echo empty > "$pstate/issue_state"; pf99; check "an issue without a state stops the run" "$?" "2"
has "$work/pf99.err" "stop: could not read the state of issue 100" "work-preflight does not say the state could not be read"
grep -q "issue-closed" "$t.records/usage.log" && grep -q "issue-query-failed" "$t.records/usage.log" && ok \
  || bad "the usage log lacks the issue labels"
no_hangul "$work/pf99.err" "work-preflight issue check output"
unset -f pf99

echo "UT-100 doctor --remote finds a configured label past the first 1,000 through the GitHub adapter"
# 목록을 개수 상한까지만 읽으면 forge-setup 이 만든 라벨을 doctor 가 없다고 보고한다.
t="$work/labels100"; setup "$t"
"$root/bin/harness" set --target "$t" forge.tracker github forge.review_host github >/dev/null 2>&1 || bad "could not switch to GitHub"
git init -q --bare "$work/labels100-origin.git"
( cd "$t" && git init -q -b development . && git remote add origin "$work/labels100-origin.git" && git add -A \
  && git -c core.hooksPath=/dev/null -c user.email=t@t -c user.name=t commit -qm init \
  && git -c core.hooksPath=/dev/null push -q origin development ) || bad "could not prepare the repo with an origin"
gh100="$work/gh100"; rm -rf "$gh100"; mkdir -p "$gh100"
cat > "$gh100/gh" <<'SH'
#!/bin/sh
# 로그인은 되어 있고, 라벨은 1,000개 뒤에 설정의 라벨이 있다. 페이지마다 배열을 이어 붙여 낸다
case "$1 $2" in
  "auth status") exit 0 ;;
  "api --paginate")
    case "$3" in
      "repos/{owner}/{repo}/labels?"*)
        python3 -c '
import json
names = ["filler-%04d" % i for i in range(1, 1001)] + ["Requirement", "Task", "invalid"]
for k in range(0, len(names), 100):
    print(json.dumps([{"name": n} for n in names[k:k + 100]]))'
        exit 0 ;;
    esac ;;
esac
exit 1
SH
chmod +x "$gh100/gh"
PATH="$gh100:$PATH" "$root/bin/harness" doctor --remote --target "$t" > "$work/labels100.txt" 2>&1
sed -n '/^remote$/,/^$/p' "$work/labels100.txt" | grep '^  ' > "$work/labels100.sec"
for l in Requirement Task invalid; do
  has "$work/labels100.sec" "  ok   label \`$l\`  — on github" "doctor does not see label $l past the first 1,000"
done
hasnt "$work/labels100.sec" "missing on github" "doctor reports a label missing that is on the forge"
no_hangul "$work/labels100.txt" "doctor --remote label output"

echo "UT-101 verification skips steps whose paths did not change since they passed, and the hooks follow [verify]"
t="$work/incr"; setup "$t"; ( cd "$t" && git init -q . )
ran="$work/incr-ran.log"; : > "$ran"
"$root/bin/harness" set --target "$t" commands.test "echo t >> $ran" verify.test_paths '["src/**"]' verify.script_tests false >/dev/null 2>&1; check "set test paths" "$?" "0"
mkdir -p "$t/src" "$t/docs"; echo a > "$t/src/a.txt"
( cd "$t" && script/harness-verify.sh --commit ) >/dev/null 2>&1; check "first run" "$?" "0"
( cd "$t" && script/harness-verify.sh --commit ) > "$work/incr.out" 2>&1
has "$work/incr.out" "skip 테스트 (unchanged" "an unchanged tree reran the test"
echo d > "$t/docs/d.md"
( cd "$t" && script/harness-verify.sh --commit ) >/dev/null 2>&1
echo b > "$t/src/a.txt"
( cd "$t" && script/harness-verify.sh --commit ) >/dev/null 2>&1
check "runs: first, then only the src change" "$(wc -l < "$ran" | tr -d ' ')" "2"
( cd "$t" && script/harness-verify.sh --no-cache ) >/dev/null 2>&1
check "--no-cache reruns" "$(wc -l < "$ran" | tr -d ' ')" "3"
# 이름 변경으로 src 밖으로 옮긴 것과 한글 경로도 src 의 변경으로 센다
mv "$t/src/a.txt" "$t/docs/moved.txt"
( cd "$t" && script/harness-verify.sh --commit ) >/dev/null 2>&1
check "a file moved out of src reruns the test" "$(wc -l < "$ran" | tr -d ' ')" "4"
mkdir -p "$t/src/한글"; echo x > "$t/src/한글/파일.txt"
( cd "$t" && script/harness-verify.sh --commit ) >/dev/null 2>&1
check "a non-ASCII path under src reruns the test" "$(wc -l < "$ran" | tr -d ' ')" "5"
"$root/bin/harness" set --target "$t" verify.test_on push >/dev/null 2>&1
echo c > "$t/src/a.txt"
( cd "$t" && script/harness-verify.sh --commit ) > "$work/incr.out" 2>&1
has "$work/incr.out" "skip 테스트 (push stage)" "a push-stage test ran before commit"
( cd "$t" && script/harness-verify.sh ) >/dev/null 2>&1
check "the push stage runs without --commit" "$(wc -l < "$ran" | tr -d ' ')" "6"
# 훅: post-commit 은 켤 때만 생기고, pre-push 는 켜져 있으면 검증을 돈다
[ ! -e "$t/script/githooks/post-commit" ] && ok || bad "post-commit exists while verify.post_commit is off"
has "$t/script/githooks/pre-push" "run-lint-test.sh" "pre-push does not verify"
# pre-push 는 작업 트리를 검증하므로 push 하는 것이 깨끗한 HEAD 일 때만 통과시킨다
g101() { git -C "$t" -c user.name=t -c user.email=t@example.invalid "$@"; }
pp101() { ( cd "$t" && printf 'refs/heads/f %s refs/heads/f %040d\n' "$1" 0 | script/githooks/pre-push origin none ) > "$work/pp101.out" 2>&1; }
g101 add -A && g101 commit -qm init; h101=$(g101 rev-parse HEAD)
echo dirty >> "$t/src/a.txt"; pp101 "$h101"; check "pre-push refuses uncommitted changes" "$?" "1"
has "$work/pp101.out" "uncommitted changes" "pre-push does not say why it refused the dirty tree"
g101 checkout -q -- src/a.txt
pp101 "$(printf '%040d' 1)"; check "pre-push refuses a revision other than HEAD" "$?" "1"
pp101 "$h101"; check "pre-push passes a clean HEAD" "$?" "0"
g101 tag -a v101 -m v101; pp101 "$(g101 rev-parse v101)"; check "pre-push passes an annotated tag on HEAD" "$?" "0"
"$root/bin/harness" checks --target "$t" '[{"name":"mut","run":"echo m >> src/a.txt"}]' >/dev/null 2>&1
g101 add -A && g101 commit -qm mut; h101=$(g101 rev-parse HEAD)
pp101 "$h101"; check "pre-push refuses when verification changes the working tree" "$?" "1"
has "$work/pp101.out" "verification changed the working tree" "pre-push does not say verification changed the tree"
g101 checkout -q -- src/a.txt; "$root/bin/harness" checks --target "$t" '[]' >/dev/null 2>&1
g101 add -A && g101 commit -qm unmut; h101=$(g101 rev-parse HEAD)
mv "$t/script/run-lint-test.sh" "$t/script/run-lint-test.sh.off"; pp101 "$h101"; check "pre-push refuses when the verification script is missing" "$?" "1"
mv "$t/script/run-lint-test.sh.off" "$t/script/run-lint-test.sh"
"$root/bin/harness" set --target "$t" verify.post_commit true verify.pre_push false >/dev/null 2>&1
[ -x "$t/script/githooks/post-commit" ] && ok || bad "post-commit was not generated when turned on"
hasnt "$t/script/githooks/pre-push" "run-lint-test.sh" "pre-push still verifies after turning it off"
"$root/bin/harness" check --target "$t" >/dev/null 2>&1; check "check after toggling hooks" "$?" "0"
"$root/bin/harness" set --target "$t" verify.test_on later >/dev/null 2>&1; check "refuse an unknown stage" "$?" "2"
"$root/bin/harness" checks --target "$t" '[{"name":"a","run":"true","paths":["/abs"]}]' >/dev/null 2>&1; check "refuse an absolute path" "$?" "2"

echo "UT-104 the harness changes the target repo only through safe paths: no symbolic link under the harness root, no path outside it"
# 경로를 지점마다 조립하면 링크를 따라 리포 밖의 파일을 바꾸는 지점이 남는다. 링크 대상과 피해 파일은 하네스 루트 바깥에 둔다.
out101="$work/outside101"; rm -rf "$out101" "$work"/p101-*; mkdir -p "$out101"
same101() { # same101 <파일> <사본> <설명> — 바이트 단위로 같은지 본다
  cmp -s "$1" "$2" && ok || bad "$3"
}
# 경로 규칙과 공용 함수 — 모듈로 읽어 부른다
gp="$work/guard101"; rm -rf "$gp"; mkdir -p "$gp" "$out101/gp-dir"
printf 'outside target\n' > "$out101/gp-dir/f.txt"; cp "$out101/gp-dir/f.txt" "$work/p101-gp.copy"
python3 - "$root/bin/harness" "$gp" "$out101" > "$work/p101-unit.out" 2>&1 <<'PY'
import contextlib, importlib.machinery, importlib.util, io, os, sys
from pathlib import Path
sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader("harness_cli", sys.argv[1])
spec = importlib.util.spec_from_loader("harness_cli", loader)
h = importlib.util.module_from_spec(spec); loader.exec_module(h)
root, outside = Path(sys.argv[2]).resolve(), Path(sys.argv[3]).resolve()

def guarded(rel, verb):
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        try:
            h.guarded_path(root, rel, verb)
            code = 0
        except SystemExit as e:
            code = e.code
    return code, err.getvalue()

print("form", "|".join(str(h.path_form_fault(p)) for p in ("/etc/x", "a/../b", "a//b", "./a", "a/", "a b")))
print("plain", "|".join(str(h.path_fault(root, p)) for p in ("script/review-mr.sh", ".harness/managed", "docs/workflow/changing.md")))
print("absent", h.path_fault(root, "no/such/dir/file.md"))
os.symlink(str(outside / "nowhere"), str(root / "dangling"))
print("dangling", h.path_fault(root, "dangling"))
(root / "sub").mkdir()
with contextlib.redirect_stderr(io.StringIO()):
    print("precheck", h.refuse_unsafe_paths(root, {"sub/f.txt": "write"}, "render"))
(root / "sub").rmdir(); os.symlink(str(outside / "gp-dir"), str(root / "sub"))
code, err = guarded("sub/f.txt", "write")
print("recheck", code, "refusing to write through a symbolic link" in err, "  --> sub\n" in err)
code, err = guarded("../victim.md", "remove")
print("form-guard", code, "(has a .. component)" in err, "victim.md" in err)
PY
check "form reasons in order" "$(sed -n 's/^form //p' "$work/p101-unit.out")" \
  "an absolute path|has a .. component|not a path|not a path|not a path|not a path"
check "plain paths pass" "$(sed -n 's/^plain //p' "$work/p101-unit.out")" "None|None|None"
check "a component that does not exist yet passes" "$(sed -n 's/^absent //p' "$work/p101-unit.out")" "None"
check "a dangling link is a link" "$(sed -n 's/^dangling //p' "$work/p101-unit.out")" "('through a symbolic link', 'dangling')"
check "the pre-check passes before the link appears" "$(sed -n 's/^precheck //p' "$work/p101-unit.out")" "False"
check "the guard looks again right before the call" "$(sed -n 's/^recheck //p' "$work/p101-unit.out")" "2 True True"
check "a malformed path is refused without printing it" "$(sed -n 's/^form-guard //p' "$work/p101-unit.out")" "2 True False"
same101 "$out101/gp-dir/f.txt" "$work/p101-gp.copy" "the guard changed the file behind the link"
[ "$(ls "$out101/gp-dir")" = "f.txt" ] && ok || bad "the guard wrote behind the link"

# 매니페스트에 있는 관리 파일이 바깥 파일 링크
m="$work/mlink101"; rm -rf "$m"; mkdir -p "$m"; ( cd "$m" && git init -q . )
"$root/bin/harness" install --target "$m" >/dev/null 2>&1 || bad "could not install the link repo"
printf 'outside file\n' > "$out101/file.sh"; cp "$out101/file.sh" "$work/p101-file.copy"
rm "$m/script/review-mr.sh"; ln -s "$out101/file.sh" "$m/script/review-mr.sh"
cp "$m/.harness/managed" "$work/p101-m.mf"; cp "$m/.harness/generated" "$work/p101-m.gen"
"$root/bin/harness" render --target "$m" > "$work/p101-1.out" 2> "$work/p101-1.err"; check "render over a managed file linked outside" "$?" "2"
has "$work/p101-1.err" "go through a symbolic link" "the refusal does not say the path goes through a link"
has "$work/p101-1.err" "  --> script/review-mr.sh" "the refusal does not name the linked managed file"
has "$work/p101-1.err" "nothing was changed" "the refusal does not say nothing was changed"
has "$work/p101-1.err" "        harness render" "the refusal does not name the command to run again"
hasnt "$work/p101-1.err" "not safe paths" "a linked manifest path was reported as a bad manifest line"
same101 "$out101/file.sh" "$work/p101-file.copy" "render changed the file behind the link"
same101 "$m/.harness/managed" "$work/p101-m.mf" "the refused render rewrote the managed manifest"
same101 "$m/.harness/generated" "$work/p101-m.gen" "the refused render rewrote the generated manifest"
"$root/bin/harness" install --target "$m" --adopt > "$work/p101-2.out" 2> "$work/p101-2.err"; check "install --adopt over the link" "$?" "2"
same101 "$out101/file.sh" "$work/p101-file.copy" "install --adopt changed the file behind the link"
rm "$m/script/review-mr.sh"; "$root/bin/harness" render --target "$m" >/dev/null 2>&1 || bad "could not restore the link repo"
# 관리 · 생성 파일의 부모 디렉터리가 바깥 디렉터리 링크 — 링크 하나만 낸다
mkdir -p "$out101/dir"; printf 'outside nested\n' > "$out101/dir/keep.txt"
mv "$m/script" "$m/script.real"; ln -s "$out101/dir" "$m/script"
"$root/bin/harness" render --target "$m" > "$work/p101-3.out" 2> "$work/p101-3.err"; check "render where script is a link to a directory outside" "$?" "2"
check "one arrow line, the link itself" "$(grep '^  --> ' "$work/p101-3.err" | tr '\n' ' ')" "  --> script "
check "the directory behind the link keeps its file" "$(cat "$out101/dir/keep.txt")" "outside nested"
check "nothing was written behind the link" "$(ls "$out101/dir" | tr '\n' ' ')" "keep.txt "
rm "$m/script"; mv "$m/script.real" "$m/script"
# 링크된 .ai/project — 내용이 같아도 멈추고, 실제 디렉터리로 바꾸면 돈다
cp -R "$m/.ai/project" "$out101/project"; rm -rf "$m/.ai/project"; ln -s "$out101/project" "$m/.ai/project"
"$root/bin/harness" render --target "$m" > "$work/p101-4.out" 2> "$work/p101-4.err"; check "render with a linked .ai/project" "$?" "2"
for s in "  --> .ai/project" "nothing was changed" "help: the harness does not write through symbolic links under the harness root"; do
  has "$work/p101-4.err" "$s" "the linked .ai/project refusal does not say: $s"
done
rm "$m/.ai/project"; cp -R "$out101/project" "$m/.ai/project"
"$root/bin/harness" render --target "$m" > "$work/p101-5.out" 2> "$work/p101-5.err"; check "render once .ai/project is a directory again" "$?" "0"
# 정리가 지울 옛 경로의 부모가 링크 — 설정을 바꾸는 명령은 되돌린다
mv "$m/docs/adr" "$out101/adr"; ln -s "$out101/adr" "$m/docs/adr"; cp "$out101/adr/README.md" "$work/p101-adr.copy"
cp "$m/harness.toml" "$work/p101-m.toml"; cp "$m/.harness/managed" "$work/p101-m.mf"; cp "$m/.harness/generated" "$work/p101-m.gen"
"$root/bin/harness" set --target "$m" adr.dir docs/decisions > "$work/p101-6.out" 2> "$work/p101-6.err"; check "set whose prune would go through a link" "$?" "2"
has "$work/p101-6.err" "  --> docs/adr" "the refusal does not name the linked directory prune would remove from"
has "$work/p101-6.err" "reverted — the config is unchanged" "set did not revert"
same101 "$out101/adr/README.md" "$work/p101-adr.copy" "prune changed the README behind the link"
same101 "$m/harness.toml" "$work/p101-m.toml" "set left the config changed"
same101 "$m/.harness/managed" "$work/p101-m.mf" "the refused set rewrote the managed manifest"
same101 "$m/.harness/generated" "$work/p101-m.gen" "the refused set rewrote the generated manifest"
[ -e "$m/docs/decisions" ] && bad "the refused set wrote the new decision-record directory" || ok
rm "$m/docs/adr"; mv "$out101/adr" "$m/docs/adr"
# 소유 원형의 부모가 링크인 새 리포
n="$work/ownlink101"; rm -rf "$n"; mkdir -p "$n/script" "$out101/proj"; ( cd "$n" && git init -q . )
ln -s "$out101/proj" "$n/script/project"
"$root/bin/harness" install --target "$n" > "$work/p101-7.out" 2> "$work/p101-7.err"; check "install where script/project links outside" "$?" "2"
has "$work/p101-7.err" "  --> script/project" "the refusal does not name script/project"
[ -e "$out101/proj/README.md" ] && bad "install laid the owned README behind the link" || ok
# 넘겨받을 사용자 파일이 바깥 파일 링크
a="$work/adoptlink101"; rm -rf "$a"; mkdir -p "$a"; ( cd "$a" && git init -q . )
printf 'my notes outside\n' > "$out101/notes.md"; cp "$out101/notes.md" "$work/p101-notes.copy"
ln -s "$out101/notes.md" "$a/CLAUDE.md"
"$root/bin/harness" install --target "$a" --adopt > "$work/p101-8.out" 2> "$work/p101-8.err"; check "install --adopt over a linked user file" "$?" "2"
has "$work/p101-8.err" "  --> CLAUDE.md" "the refusal does not name the linked user file"
same101 "$out101/notes.md" "$work/p101-notes.copy" "the adopt changed the file behind the link"
[ -L "$a/CLAUDE.md" ] && [ ! -e "$a/CLAUDE.md.orig" ] && [ ! -L "$a/CLAUDE.md.orig" ] && ok || bad "the refused adopt moved the link"
# 하네스 루트 자신과 그 위의 링크는 보지 않는다
ln -sfn "$m" "$work/rootlink101"
"$root/bin/harness" render --target "$work/rootlink101" > "$work/p101-9.out" 2> "$work/p101-9.err"; check "render through a link to the harness root" "$?" "0"
[ -e "$n/.harness" ] && bad "the install refused over script/project still wrote .harness/" || ok

# install 의 사본 교체 — .harness 가 바깥 디렉터리 링크면 새 리포에서도 설치된 리포에서도 멈춘다
hl="$work/hlink101"; rm -rf "$hl"; mkdir -p "$hl" "$out101/pin/keep-dir"; ( cd "$hl" && git init -q . )
printf 'outside\n' > "$out101/pin/keep.txt"; printf 'nested\n' > "$out101/pin/keep-dir/nested.txt"
ln -s "$out101/pin" "$hl/.harness"
"$root/bin/harness" install --target "$hl" > "$work/p101-10.out" 2> "$work/p101-10.err"; check "install on a new repo with a linked .harness" "$?" "2"
has "$work/p101-10.err" "  --> .harness" "the refusal does not name the linked .harness"
check "the link target's file is kept" "$(cat "$out101/pin/keep.txt")" "outside"
check "the link target's nested file is kept" "$(cat "$out101/pin/keep-dir/nested.txt")" "nested"
check "nothing was written behind the link" "$(ls "$out101/pin" | tr '\n' ' ')" "keep-dir keep.txt "
[ -e "$HARNESS_HOME/hlink101/project.json" ] && bad "the refused install registered the project" || ok
cp "$HARNESS_HOME/mlink101/project.json" "$work/p101-reg.copy"
cp -R "$m/.harness" "$out101/pinned"; mv "$m/.harness" "$m/.harness.real"; ln -s "$out101/pinned" "$m/.harness"
"$root/bin/harness" install --target "$m" > "$work/p101-11.out" 2> "$work/p101-11.err"; check "reinstall with a linked .harness" "$?" "2"
[ -f "$out101/pinned/bin/harness" ] && [ -f "$out101/pinned/managed" ] && ok || bad "the reinstall removed files behind the link"
same101 "$HARNESS_HOME/mlink101/project.json" "$work/p101-reg.copy" "the refused reinstall changed the registry"
rm "$m/.harness"; mv "$m/.harness.real" "$m/.harness"
# 소스 리포의 옛 사본 정리 — .harness/bin 이 바깥 디렉터리 링크면 멈춘다
s101="$work/source101"; rm -rf "$s101"; mkdir -p "$s101/src/bin" "$out101/oldbin"
cp "$root/bin/harness" "$root/bin/harness_metrics.py" "$s101/src/bin/"; cp -R "$root/templates" "$s101/src/templates"
( cd "$s101" && git init -q . )
printf 'outside bin\n' > "$out101/oldbin/keep"; mkdir -p "$s101/.harness"; ln -s "$out101/oldbin" "$s101/.harness/bin"
"$s101/src/bin/harness" install --target "$s101" > "$work/p101-12.out" 2> "$work/p101-12.err"; check "install on a source tree with a linked .harness/bin" "$?" "2"
has "$work/p101-12.err" "  --> .harness/bin" "the refusal does not name the linked old copy"
check "the directory behind the old copy's link is kept" "$(ls "$out101/oldbin" | tr '\n' ' ')" "keep "
[ -L "$s101/.harness/bin" ] && ok || bad "the refused install removed the link"
# 설정 씨앗 — 대상 없는 harness.toml 링크를 따라 쓰지 않는다
sd="$work/seed101"; rm -rf "$sd"; mkdir -p "$sd"; ( cd "$sd" && git init -q . )
ln -s "$out101/seeded.toml" "$sd/harness.toml"
"$root/bin/harness" install --target "$sd" > "$work/p101-13.out" 2> "$work/p101-13.err"; check "install over a dangling harness.toml link" "$?" "2"
has "$work/p101-13.err" "refusing to write through a symbolic link" "the refusal does not say it would write through a link"
has "$work/p101-13.err" "  --> harness.toml" "the refusal does not name harness.toml"
[ -e "$out101/seeded.toml" ] && bad "install wrote the default config behind the link" || ok
# uninstall — 지울 경로의 부모가 링크면 아무것도 지우지 않는다
mv "$m/docs/adr" "$out101/adr"; ln -s "$out101/adr" "$m/docs/adr"
cp "$m/.harness/managed" "$work/p101-m.mf"; cp "$m/.harness/generated" "$work/p101-m.gen"
"$root/bin/harness" uninstall --target "$m" > "$work/p101-14.out" 2> "$work/p101-14.err"; check "uninstall through a link" "$?" "2"
has "$work/p101-14.err" "  --> docs/adr" "the uninstall refusal does not name the link"
has "$work/p101-14.err" "nothing was changed" "the uninstall refusal does not say nothing was changed"
has "$work/p101-14.err" "        harness uninstall" "the uninstall refusal does not name the command"
same101 "$out101/adr/README.md" "$work/p101-adr.copy" "uninstall changed the README behind the link"
same101 "$m/.harness/managed" "$work/p101-m.mf" "the refused uninstall changed the managed manifest"
same101 "$m/.harness/generated" "$work/p101-m.gen" "the refused uninstall changed the generated manifest"
missing101=$(cd "$m" && { cat .harness/generated; sed -E 's/^[0-9a-f]{64}  //' .harness/managed; } | while read -r f; do [ -e "$f" ] || echo "$f"; done)
check "every manifest path is still there" "$missing101" ""
rm "$m/docs/adr"; mv "$out101/adr" "$m/docs/adr"
# uninstall --purge — 소유 파일의 부모가 링크면 확인 목록보다 먼저 멈춘다
cp -R "$m/.ai/project" "$out101/purge-project"; rm -rf "$m/.ai/project"; ln -s "$out101/purge-project" "$m/.ai/project"
"$root/bin/harness" uninstall --target "$m" --purge --yes > "$work/p101-15.out" 2> "$work/p101-15.err"; check "uninstall --purge --yes through a linked owned directory" "$?" "2"
[ -f "$out101/purge-project/scope.md" ] && ok || bad "--purge removed an owned file behind the link"
"$root/bin/harness" uninstall --target "$m" --purge < /dev/null > "$work/p101-16.out" 2> "$work/p101-16.err"; check "uninstall --purge without --yes through a link" "$?" "2"
has "$work/p101-16.err" "  --> .ai/project" "the purge refusal does not name the link"
hasnt "$work/p101-16.out" "purge target:" "the purge listed what it would remove before refusing the link"
[ -f "$out101/purge-project/scope.md" ] && [ -d "$m/.harness" ] && ok || bad "the refused purge removed something"
rm "$m/.ai/project"; cp -R "$out101/purge-project" "$m/.ai/project"
# 링크가 없으면 uninstall 이 하네스 것을 지운다
cp "$m/.harness/generated" "$work/p101-final.gen"
"$root/bin/harness" uninstall --target "$m" > "$work/p101-17.out" 2> "$work/p101-17.err"; check "uninstall without links" "$?" "0"
left101=$(cd "$m" && while read -r f; do [ -e "$f" ] && echo "$f"; done < "$work/p101-final.gen")
check "the generated files are gone" "$left101" ""
[ -e "$m/.harness" ] && bad "uninstall left .harness/" || ok
grep -c 'refuse_link\|linked_component' "$root/bin/harness" > "$work/p101-names" || true
check "no per-point link check is left in the CLI" "$(cat "$work/p101-names")" "0"

# 매니페스트는 신뢰하지 않는 입력이다 — 어긋난 줄이 하나라도 있으면 바꾸는 명령은 아무것도 바꾸지 않는다
mf="$work/mf101/repo"; rm -rf "$work/mf101"; mkdir -p "$mf"; ( cd "$mf" && git init -q . )
"$root/bin/harness" install --target "$mf" >/dev/null 2>&1 || bad "could not install the manifest repo"
printf 'victim\n' > "$work/mf101/victim.md"; cp "$work/mf101/victim.md" "$work/p101-victim.copy"
printf 'outside file\n' > "$out101/abs.md"; cp "$out101/abs.md" "$work/p101-abs.copy"
cp "$mf/.harness/generated" "$work/p101-mf.gen"; cp "$mf/.harness/managed" "$work/p101-mf.mf"; cp "$mf/harness.toml" "$work/p101-mf.toml"
restore101() { cp "$work/p101-mf.gen" "$mf/.harness/generated"; cp "$work/p101-mf.mf" "$mf/.harness/managed"; }
# 상위 경로 줄 — 리포 밖 파일을 지우지 않고, 고친 관리 · 생성 파일도 되돌리지 않는다
printf '\n# edited\n' >> "$mf/script/review-mr.sh"; printf '\nedited\n' >> "$mf/AGENTS.md"
cp "$mf/script/review-mr.sh" "$work/p101-mf.review"; cp "$mf/AGENTS.md" "$work/p101-mf.agents"
printf '../victim.md\n' >> "$mf/.harness/generated"; n101=$(wc -l < "$mf/.harness/generated" | tr -d ' ')
cp "$mf/.harness/generated" "$work/p101-mf.gen-bad"
"$root/bin/harness" render --target "$mf" > "$work/p101-20.out" 2> "$work/p101-20.err"; check "render with a .. manifest line" "$?" "2"
has "$work/p101-20.err" "  --> .harness/generated:$n101 (has a .. component)" "the refusal does not name the manifest line and its reason"
has "$work/p101-20.err" "the harness manifest has 1 line(s) that are not safe paths under the harness root" "the refusal does not count the bad lines"
has "$work/p101-20.err" "nothing was changed" "the refusal does not say nothing was changed"
same101 "$work/mf101/victim.md" "$work/p101-victim.copy" "render changed the file outside the harness root"
same101 "$mf/.harness/generated" "$work/p101-mf.gen-bad" "the refused render rewrote the generated manifest"
same101 "$mf/.harness/managed" "$work/p101-mf.mf" "the refused render rewrote the managed manifest"
same101 "$mf/script/review-mr.sh" "$work/p101-mf.review" "the refused render put a managed file back"
same101 "$mf/AGENTS.md" "$work/p101-mf.agents" "the refused render regenerated a file"
# 설정을 바꾸는 명령은 설정을 쓰기 전에 멈춘다
"$root/bin/harness" set --target "$mf" branches.base trunk > "$work/p101-21.out" 2> "$work/p101-21.err"; check "set with a bad manifest line" "$?" "2"
"$root/bin/harness" steps --target "$mf" ship '{"title":"ship it","steps":[{"id":"a","type":"gate","title":"t"}]}' \
  > "$work/p101-22.out" 2> "$work/p101-22.err"; check "steps with a bad manifest line" "$?" "2"
"$root/bin/harness" checks --target "$mf" '[{"name":"lint","run":"true"}]' > "$work/p101-23.out" 2> "$work/p101-23.err"; check "checks with a bad manifest line" "$?" "2"
for i in 21 22 23; do has "$work/p101-$i.err" "not safe paths under the harness root" "command $i did not name the bad manifest"; done
same101 "$mf/harness.toml" "$work/p101-mf.toml" "a config command changed the config over a bad manifest"
same101 "$work/mf101/victim.md" "$work/p101-victim.copy" "a config command changed the file outside the harness root"
restore101
# 절대 경로 줄 — render · install · uninstall 모두 멈추고, 줄의 내용을 출력하지 않는다
printf '%s  %s\n' "$(printf x | shasum -a 256 | cut -c1-64)" "$out101/abs.md" >> "$mf/.harness/managed"
for c in render install uninstall; do
  "$root/bin/harness" $c --target "$mf" > "$work/p101-24-$c.out" 2> "$work/p101-24-$c.err"; check "$c with an absolute manifest line" "$?" "2"
  has "$work/p101-24-$c.err" "(an absolute path)" "$c does not give the absolute path reason"
  cat "$work/p101-24-$c.out" "$work/p101-24-$c.err" | grep -qF "$out101/abs.md" && bad "$c printed the bad line's path" || ok
done
same101 "$out101/abs.md" "$work/p101-abs.copy" "a command changed the file the bad line names"
[ -f "$mf/.harness/bin/harness" ] && [ -f "$mf/CLAUDE.md" ] && [ -f "$mf/script/review-mr.sh" ] && ok || bad "the refused uninstall removed harness files"
restore101
# 형식이 어긋난 줄
for l in 'script/my file.sh' 'script//x.sh' './CLAUDE.md' 'script/'; do
  printf '%s\n' "$l" >> "$mf/.harness/generated"
  "$root/bin/harness" render --target "$mf" > "$work/p101-25.out" 2> "$work/p101-25.err"; check "render with the manifest line '$l'" "$?" "2"
  has "$work/p101-25.err" "(not a path)" "the line '$l' is not reported as not a path"
  cat "$work/p101-25.out" "$work/p101-25.err" >> "$work/p101-25-all.log"
  restore101
done
# 병합 충돌 표지 — 표지 줄을 지우면 install 이 다시 쓴다
printf '<<<<<<< HEAD\n=======\n>>>>>>> other\n' >> "$mf/.harness/managed"
"$root/bin/harness" render --target "$mf" > "$work/p101-26.out" 2> "$work/p101-26.err"; check "render with conflict markers" "$?" "2"
check "every marker line is reported" "$(grep -c '(a merge conflict marker)$' "$work/p101-26.err")" "3"
has "$work/p101-26.err" "a merge left conflict markers in it" "the help does not explain the conflict markers"
has "$work/p101-26.err" "        harness install" "the help does not name harness install"
grep -vE '^(<<<<<<< |=======$|>>>>>>> )' "$mf/.harness/managed" > "$work/p101-unmarked"; cp "$work/p101-unmarked" "$mf/.harness/managed"
same101 "$mf/.harness/managed" "$work/p101-mf.mf" "the marker lines were not removed"
"$root/bin/harness" install --target "$mf" > "$work/p101-27.out" 2> "$work/p101-27.err"; check "install once the marker lines are gone" "$?" "0"
# CR 줄 끝은 받는다
for f in generated managed; do python3 -c 'import sys; p = sys.argv[1]; d = open(p, "rb").read(); open(p, "wb").write(d.replace(b"\n", b"\r\n"))' "$mf/.harness/$f"; done
"$root/bin/harness" render --target "$mf" > "$work/p101-28.out" 2> "$work/p101-28.err"; check "render over CRLF manifests" "$?" "0"
# uninstall 은 매니페스트가 없다고 판정하기 전에 본다
rm "$mf/.harness/generated"; printf '../victim.md\n' > "$mf/.harness/managed"
"$root/bin/harness" uninstall --target "$mf" > "$work/p101-29.out" 2> "$work/p101-29.err"; check "uninstall over a manifest of bad lines only" "$?" "2"
has "$work/p101-29.err" "not safe paths under the harness root" "uninstall did not name the bad manifest"
hasnt "$work/p101-29.err" "no harness manifest" "uninstall took a bad manifest for none"
same101 "$work/mf101/victim.md" "$work/p101-victim.copy" "uninstall changed the file outside the harness root"
cat "$work"/p101-*.out "$work"/p101-*.err > "$work/p101-all.log"; no_hangul "$work/p101-all.log" "safe path output"

echo
if [ "$fail" -eq 0 ]; then
  echo "render-test: ${pass} passed"
  exit 0
fi
echo "render-test: ${pass} passed, ${fail} failed" >&2
exit 1
