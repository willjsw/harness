#!/usr/bin/env python3
"""실행 지표 기록기 — 명령·단계·에이전트·스크립트 하나하나를 스팬으로 남긴다. Metrics 탭이 읽는다.

    script/metric.py wrap --name <이름> --kind <종류> [--attr 키=값 ...] -- <명령> [인수 ...]
    script/metric.py start --name <이름> --kind <종류> [--attr 키=값 ...]     # 스팬 id 를 출력
    script/metric.py end --span <id> [--status ok|error] [--exit N]
    script/metric.py step <절차> <단계>     # 워크플로 단계의 시작 표지 — 세션 토큰을 단계로 나누는 기준
    script/metric.py prune

어디에 얼마나 남길지는 `script/harness.plan.json` 의 metrics(= harness.toml 의 [metrics])가 정한다.
한 줄에 이벤트 하나인 JSONL 이고, 시각은 UTC 다. 트레이스는 환경 변수로 이어진다 —
HARNESS_TRACE_ID(한 실행) · HARNESS_PARENT_SPAN(부모 스팬). wrap 은 자식에게 둘 다 넘긴다.

**남기지 않는 것**: 프롬프트, 명령줄, 문서 본문, 사람 이름. 이름·속성은 정해진 모양만 통과하고,
실패 로그는 capture_logs = "errors" 일 때 실패한 스팬의 끝부분만 지울 것을 지운 뒤 남긴다.

**부수 효과다.** 기록이 실패해도 부른 쪽의 출력·종료 코드를 바꾸지 않는다. wrap 은 감싼 명령의
출력을 그대로 흘리고 그 종료 코드로 끝난다.
"""
import fcntl
import json
import os
import re
import subprocess
import sys
import threading
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = 1
KINDS = {"command", "step", "agent", "script", "session", "prompt", "marker"}
UNATTRIBUTED = "t-unattributed"   # 어느 실행(harness run)에도 붙이지 못한 기록이 모이는 트레이스
ATTR_KEYS = {"workflow", "step", "role", "vendor", "model", "issue", "script", "source"}
# 이름·속성 값의 모양. 자유 문장이 들어오지 못하게 짧은 식별자만 받는다
NAME_RE = re.compile(r"^[\w.:/@+-]{1,80}$")
ISSUE_RE = re.compile(r"^[0-9]{1,10}$")
LOG_LINES, LOG_BYTES = 20, 2048


def config():
    """지표 설정. 계획 파일이 없거나(렌더 전) 꺼져 있으면 None — 기록하지 않는다.
    HARNESS_METRICS=off 면 이 프로세스와 자식은 기록하지 않는다(doctor 같은 점검이 쓴다)."""
    if os.environ.get("HARNESS_METRICS") == "off":
        return None
    try:
        m = json.loads((ROOT / "script" / "harness.plan.json").read_text(encoding="utf-8"))["metrics"]
    except (OSError, ValueError, KeyError):
        return None
    if m.get("dir", "off") == "off":
        return None
    return dict(m, dir=Path(os.path.expandvars(os.path.expanduser(m["dir"]))))


def now():
    return datetime.now(timezone.utc)


def iso(t):
    return t.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (t.microsecond // 1000)


def new_id(prefix):
    return "%s-%s" % (prefix, uuid.uuid4().hex[:16])


def clean_attrs(pairs):
    out = {}
    for p in pairs or []:
        k, _, v = p.partition("=")
        if k in ATTR_KEYS and (ISSUE_RE if k == "issue" else NAME_RE).match(v):
            out[k] = v
    return out


# 로그에서 지우는 것. 지표는 로컬에만 있지만, 화면에 보이고 복사될 수 있다.
REDACT = [
    (re.compile(r"(?i)(authorization|cookie|set-cookie|x-api-key|api[_-]?key|token|secret|password|passwd)(\s*[:=]\s*)\S+"), r"\1\2***"),
    (re.compile(r"(?i)\bbearer\s+[\w.~+/=-]+"), "Bearer ***"),
    (re.compile(r"\b(sk|pk|rk|ghp|gho|ghs|glpat|xox[abpr])[-_][\w-]{8,}"), "***"),
    (re.compile(r"\beyJ[\w-]{10,}\.[\w-]{10,}\.[\w-]{5,}"), "***"),        # JWT
    (re.compile(r"(https?://[^\s?#]+)\?[^\s#]*"), r"\1?***"),               # URL 쿼리
    (re.compile(r"(https?://)[^/\s:@]+:[^/\s@]+@"), r"\1***@"),             # URL 의 사용자:비밀번호
    (re.compile(r"[\w.+-]+@[\w-]+(\.[\w-]+)+"), "***@***"),                   # 이메일
]


def redact(text):
    home = os.path.expanduser("~")
    if home and home != "/":
        text = text.replace(home, "~")
    for rx, sub in REDACT:
        text = rx.sub(sub, text)
    return text


def log_tail(raw):
    lines = raw.decode("utf-8", "replace").splitlines()[-LOG_LINES:]
    return redact("\n".join(lines))[-LOG_BYTES:]


class Store:
    """지표 디렉터리 하나. 쓰기와 정리는 한 잠금 안에서만 한다 — 여러 프로세스가 동시에 쓴다."""

    def __init__(self, cfg):
        self.cfg = cfg
        self.dir = cfg["dir"]

    def __enter__(self):
        self.dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        os.chmod(self.dir, 0o700)
        self.lock = os.open(self.dir / ".lock", os.O_CREAT | os.O_RDWR, 0o600)
        fcntl.flock(self.lock, fcntl.LOCK_EX)
        return self

    def __exit__(self, *_):
        fcntl.flock(self.lock, fcntl.LOCK_UN)
        os.close(self.lock)

    def files(self):
        return sorted(self.dir.glob("spans-*.jsonl"), key=lambda p: (p.name[6:14], int(p.stem.split("-")[2])))

    def current(self, need):
        """오늘 파일 중 마지막 것. 이번 줄을 더하면 상한을 넘으면 다음 번호로 넘어간다."""
        day = now().strftime("%Y%m%d")
        today = [p for p in self.files() if p.name[6:14] == day]
        p = today[-1] if today else self.dir / ("spans-%s-1.jsonl" % day)
        if p.exists() and p.stat().st_size + need > self.cfg["max_file_mb"] * 1024 * 1024:
            p = self.dir / ("spans-%s-%d.jsonl" % (day, int(p.stem.split("-")[2]) + 1))
        return p

    def write(self, event):
        line = (json.dumps(dict(event, v=SCHEMA), ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")
        self.prune_daily()
        fd = os.open(self.current(len(line)), os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
        try:
            os.write(fd, line)   # 한 번에 한 줄 — 잠금 안이라 다른 기록과 섞이지 않는다
        finally:
            os.close(fd)

    def prune_daily(self):
        stamp = self.dir / ".pruned"
        day = now().strftime("%Y%m%d")
        try:
            if stamp.read_text().strip() == day:
                return
        except OSError:
            pass
        self.prune()
        fd = os.open(stamp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        try:
            os.write(fd, day.encode())
        finally:
            os.close(fd)

    def prune(self):
        """보관 기간이 지난 파일, 그리고 전체 상한을 넘는 만큼 오래된 파일부터 지운다. 쓰는 중인 파일은 두지 않는다."""
        files = self.files()
        live = files[-1:] if files else []
        cut = (now() - timedelta(days=self.cfg["retention_days"])).strftime("%Y%m%d")
        gone = [p for p in files if p not in live and p.name[6:14] < cut]
        rest = [p for p in files if p not in gone]
        total = sum(p.stat().st_size for p in rest)
        for p in rest[:-1] if rest else []:
            if total <= self.cfg["max_total_mb"] * 1024 * 1024:
                break
            total -= p.stat().st_size
            gone.append(p)
        for p in gone:
            p.unlink(missing_ok=True)
        return len(gone)


def emit(event):
    """이벤트 하나를 남긴다. 무슨 일이 있어도 예외를 올리지 않는다."""
    try:
        cfg = config()
        if cfg:
            with Store(cfg) as s:
                s.write(event)
    except Exception:   # ponytail: 기록은 부수 효과다 — 실패를 부른 쪽에 넘기지 않는다
        pass


def start(name, kind, attrs=None, trace=None, parent=None, source="script", t=None):
    """스팬을 연다. (trace, span) 을 돌려준다. 트레이스·부모를 주지 않으면 환경 변수에서 잇는다.
    t 는 지난 일을 기록할 때(세션 가져오기)만 준다."""
    trace = trace or os.environ.get("HARNESS_TRACE_ID") or new_id("t")
    name = re.sub(r"\s+", "-", (name or "").strip())[:80]
    parent = parent if parent is not None else os.environ.get("HARNESS_PARENT_SPAN") or None
    span = new_id("s")
    if NAME_RE.match(name or "") and kind in KINDS:
        emit({"ev": "start", "trace": trace, "span": span, "parent": parent, "name": name, "kind": kind,
              "source": source, "attrs": attrs or {}, "t": iso(t or now())})
    return trace, span


def end(span, status="ok", exit_code=None, dur_ms=None, usage=None, model=None, log=None, t=None):
    cfg = config()
    ev = {"ev": "end", "span": span, "status": "error" if status == "error" else "ok", "t": iso(t or now())}
    if exit_code is not None:
        ev["exit"] = exit_code
    if dur_ms is not None:
        ev["dur_ms"] = int(dur_ms)
    if usage:
        ev["usage"] = {k: int(usage.get(k) or 0) for k in ("input", "output", "cache_read", "cache_write", "reasoning")}
    if model and NAME_RE.match(model):
        ev["model"] = model
    if log and cfg and cfg.get("capture_logs") == "errors" and ev["status"] == "error":
        ev["log"] = log
    emit(ev)


def wrap(name, kind, attrs, argv):
    """명령 하나를 스팬으로 감싼다. 출력은 그대로 흘리고, 표준 오류의 끝부분만 따로 모은다."""
    if not config():
        # 꺼져 있으면 감싸지 않는다 — 표준 오류를 파이프로 돌리면 자식이 터미널이 아닌 줄 안다
        try:
            return subprocess.call(argv)
        except OSError as e:
            print("%s: %s" % (argv[0], e), file=sys.stderr)
            return 127
    trace, span = start(name, kind, attrs)
    env = dict(os.environ, HARNESS_TRACE_ID=trace, HARNESS_PARENT_SPAN=span)
    t0 = time.monotonic()
    tail = bytearray()
    try:
        p = subprocess.Popen(argv, env=env, stderr=subprocess.PIPE)
    except OSError as e:
        end(span, "error", 127, (time.monotonic() - t0) * 1000, log=redact(str(e)))
        print("%s: %s" % (argv[0], e), file=sys.stderr)
        return 127

    def pump():
        for chunk in iter(lambda: p.stderr.read1(65536), b""):
            sys.stderr.buffer.write(chunk)
            sys.stderr.buffer.flush()
            tail.extend(chunk)
            del tail[:-65536]
    t = threading.Thread(target=pump, daemon=True)
    t.start()
    try:
        code = p.wait()
    except KeyboardInterrupt:
        p.wait()
        code = 130
    t.join()
    end(span, "ok" if code == 0 else "error", code, (time.monotonic() - t0) * 1000, log=log_tail(bytes(tail)))
    return code


def main(args):
    cmd = args[0] if args else ""
    opts = {"attr": []}
    rest = []
    i = 1
    while i < len(args):
        a = args[i]
        if a == "--":
            rest = args[i + 1:]
            break
        if a.startswith("--") and i + 1 < len(args):
            k = a[2:]
            if k == "attr":
                opts["attr"].append(args[i + 1])
            else:
                opts[k] = args[i + 1]
            i += 2
            continue
        i += 1
    if cmd == "wrap":
        if not rest:
            print("usage: metric.py wrap --name N --kind K [--attr k=v] -- <command>", file=sys.stderr)
            return 2
        return wrap(opts.get("name", ""), opts.get("kind", "script"), clean_attrs(opts["attr"]), rest)
    if cmd == "start":
        print(start(opts.get("name", ""), opts.get("kind", "script"), clean_attrs(opts["attr"]))[1])
        return 0
    if cmd == "end":
        code = opts.get("exit")
        end(opts.get("span", ""), opts.get("status", "ok"), int(code) if code and code.isdigit() else None)
        return 0
    if cmd == "step":
        # 오케스트레이터가 단계를 시작할 때 한 번 부른다. harness run 이 띄운 세션이면 그 트레이스에 붙는다
        pos = [a for a in args[1:] if not a.startswith("--")][:2]
        if len(pos) == 2:
            wf, st = pos
            _, span = start("%s/%s" % (wf, st), "marker", clean_attrs(["workflow=" + wf, "step=" + st]),
                            trace=os.environ.get("HARNESS_TRACE_ID") or UNATTRIBUTED, source="session")
            end(span)
        return 0
    if cmd == "prune":
        cfg = config()
        if cfg:
            with Store(cfg) as s:
                print("prune: %d file(s) removed" % s.prune())
        return 0
    print(__doc__.split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
