#!/usr/bin/env python3
"""하네스 CLI 의 실행 지표 모듈 — 스팬 집계와 에이전트 CLI 세션 가져오기.

`harness` 가 같은 디렉터리에서 읽어 쓴다. 표준 라이브러리만 쓰고 `harness` 를 import 하지 않는다 —
설정 해석·등록부 경로 같은 CLI 의 값은 인자로 받는다.
"""
import datetime
import importlib.util
import json
import os
import re
import sys
from pathlib import Path


def load_metric(target: Path):
    """대상 리포의 지표 기록기(script/metric.py). 없으면(옛 설치) None — 기록하지 않는다."""
    f = target / "script" / "metric.py"
    if not f.is_file():
        return None
    spec = importlib.util.spec_from_file_location("harness_metric", f)
    mod = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    try:
        spec.loader.exec_module(mod)
    except Exception:
        return None
    return mod


def read_spans(d: Path):
    """지표 파일을 읽어 스팬 id → {start, end} 로 모은다. 깨진 줄·쓰는 중인 마지막 줄은 세기만 한다."""
    spans, bad, files, size = {}, 0, 0, 0
    for p in sorted(d.glob("spans-*.jsonl")) if d.is_dir() else []:
        files += 1
        raw = p.read_bytes()
        size += len(raw)
        whole = raw[:raw.rfind(b"\n") + 1]            # 개행으로 끝나지 않은 줄은 아직 쓰는 중이다
        bad += raw[len(whole):].strip() != b""
        for ln in whole.splitlines():
            try:
                e = json.loads(ln)
                spans.setdefault(e["span"], {})[e["ev"]] = e
            except (ValueError, KeyError, TypeError):
                bad += 1
    return spans, {"bad_lines": bad, "files": files, "bytes": size}


def parse_iso(t: str):
    return datetime.datetime.fromisoformat(t.replace("Z", "+00:00"))


def pct(xs: list, q: float):
    if not xs:
        return 0
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(round(q * (len(xs) - 1))))]


def metrics_report(spans: dict, since, now, stale_h: int, trace_id: str = None) -> dict:
    """스팬 → Metrics 탭이 그리는 집계. 순수 함수라 고정 입력으로 검사한다."""
    rows = []
    for sid, e in spans.items():
        s = e.get("start")
        if not s:
            continue                                    # 끝만 남은 것(시작 줄이 지워진 파일에 있었다)
        t0 = parse_iso(s["t"])
        if t0 < since and not (trace_id and s["trace"] == trace_id):
            continue
        en = e.get("end")
        if en:
            status = en["status"]
            dur = en.get("dur_ms", int((parse_iso(en["t"]) - t0).total_seconds() * 1000))
        else:
            status = "stale" if (now - t0).total_seconds() > stale_h * 3600 else "running"
            dur = int((now - t0).total_seconds() * 1000)
        u = (en or {}).get("usage") or {}
        if s["kind"] == "marker":
            continue                                    # 단계 시작 표지 — 시각만 쓰고 집계하지 않는다
        rows.append({"span": sid, "trace": s["trace"], "parent": s.get("parent"), "name": s["name"], "kind": s["kind"],
                     "source": s.get("source", "script"), "attrs": s.get("attrs", {}), "t": s["t"], "t0": t0,
                     "status": status, "dur_ms": dur, "exit": (en or {}).get("exit"), "model": (en or {}).get("model", ""),
                     "usage": {k: u.get(k, 0) for k in ("input", "output", "cache_read", "cache_write", "reasoning")},
                     "log": (en or {}).get("log")})
    tok = lambda r: r["usage"]["input"] + r["usage"]["output"]

    def group(key):
        g = {}
        for r in rows:
            k = key(r)
            if k:
                g.setdefault(k, []).append(r)
        return sorted(({"name": k, "count": len(v), "tokens": sum(map(tok, v)),
                        "errors": sum(r["status"] == "error" for r in v),
                        "p50_ms": pct([r["dur_ms"] for r in v if r["status"] in ("ok", "error")], .5),
                        "p95_ms": pct([r["dur_ms"] for r in v if r["status"] in ("ok", "error")], .95)}
                       for k, v in g.items()), key=lambda x: (-x["tokens"], -x["count"], x["name"]))

    by_trace = {}
    for r in rows:
        by_trace.setdefault(r["trace"], []).append(r)
    traces = []
    for tid, rs in by_trace.items():
        ids = {r["span"] for r in rs}
        roots = [r for r in rs if not r["parent"] or r["parent"] not in ids]
        root = min(roots, key=lambda r: r["t0"])
        traces.append({"trace": tid, "name": "unattributed" if tid == UNATTRIBUTED else root["name"], "kind": root["kind"], "t": root["t"], "status": root["status"],
                       "dur_ms": root["dur_ms"], "spans": len(rs), "tokens": sum(map(tok, rs)),
                       "sources": sorted({r["source"] for r in rs}), "attrs": root["attrs"]})
    traces.sort(key=lambda x: x["t"], reverse=True)
    runs = [t for t in traces if t["trace"] != UNATTRIBUTED]   # 어느 실행에도 못 붙인 기록은 실행으로 세지 않는다
    done = [t for t in runs if t["status"] in ("ok", "error")]
    daily = {}
    for r in rows:
        if tok(r) or r["usage"]["cache_read"]:
            day = r["t0"].astimezone().strftime("%Y-%m-%d")      # 이 컴퓨터의 시간대로 하루를 가른다
            key = "%s%s" % (r["attrs"].get("vendor", "unknown"), "/" + r["model"] if r["model"] else "")
            d = daily.setdefault(day, {})
            d[key] = d.get(key, 0) + tok(r)
    out = {
        "summary": {"runs": len(runs), "ok": sum(t["status"] == "ok" for t in done),
                    "error": sum(t["status"] == "error" for t in done),
                    "running": sum(t["status"] == "running" for t in runs), "stale": sum(t["status"] == "stale" for t in runs),
                    "success_rate": round(sum(t["status"] == "ok" for t in done) / len(done), 4) if done else None,
                    "dur_ms": sum(t["dur_ms"] for t in done),
                    "tokens": {k: sum(r["usage"][k] for r in rows) for k in ("input", "output", "cache_read", "cache_write", "reasoning")}},
        "daily": [{"day": d, "by": v} for d, v in sorted(daily.items())],
        "by_step": group(lambda r: r["attrs"].get("step") and "%s/%s" % (r["attrs"].get("workflow", "?"), r["attrs"]["step"])),
        "by_role": group(lambda r: r["attrs"].get("role")),
        "by_script": group(lambda r: r["kind"] == "script" and r["name"]),
        "traces": traces[:200],
        "errors": [{"t": r["t"], "name": r["name"], "trace": r["trace"], "exit": r["exit"], "log": r["log"]}
                   for r in sorted(rows, key=lambda r: r["t"], reverse=True) if r["status"] == "error"][:50],
    }
    if trace_id:
        rs = sorted(by_trace.get(trace_id, []), key=lambda r: r["t0"])
        base = rs[0]["t0"] if rs else now
        out["trace"] = [dict({k: v for k, v in r.items() if k != "t0"}, offset_ms=int((r["t0"] - base).total_seconds() * 1000))
                        for r in rs]
    return out


# ─── 세션 가져오기 ─────────────────────────────────────────────────────────────
# 대화형 오케스트레이터는 하네스가 감싸지 못한다. 각 CLI 가 이미 남기는 대화 기록에서 **사용량·시각·역할만**
# 읽어 스팬으로 옮긴다. 메시지 본문은 저장하지 않는다. 형식은 이 기계의 기록으로 확인한 것이다 —
#   Claude Code  ~/.claude/projects/<경로의 영숫자 외 문자를 - 로>/<세션>.jsonl, 서브에이전트는 <세션>/subagents/
#                assistant 줄의 message.usage. 한 응답이 여러 줄로 반복되므로 message.id 로 한 번만 센다
#   Codex        ~/.codex/sessions/**/rollout-*.jsonl, session_meta.payload.cwd 로 프로젝트를 가린다
#                token_usage_record(응답마다) 가 있으면 그것을, 없으면 token_count 누적값의 증가분을 쓴다
# 붙일 곳: 같은 벤더로 그 시각에 돌던 harness run 이 **하나일 때만** 그 실행, 아니면 unattributed.
# 단계: 그 실행의 마지막 시작 표지(script/metric.py step). 없으면 단계 미상.
UNATTRIBUTED = "t-unattributed"


def claude_usage(u: dict) -> dict:
    return {"input": u.get("input_tokens", 0), "output": u.get("output_tokens", 0),
            "cache_read": u.get("cache_read_input_tokens", 0), "cache_write": u.get("cache_creation_input_tokens", 0),
            "reasoning": (u.get("output_tokens_details") or {}).get("thinking_tokens", 0)}


def codex_usage(u: dict) -> dict:
    cached = u.get("cached_input_tokens", 0)
    # OpenAI 사용량은 캐시 읽기를 input 에 포함한다 — 다른 벤더와 같은 뜻이 되게 뺀다(run-agent.py 와 같다)
    return {"input": max(0, u.get("input_tokens", 0) - cached), "output": u.get("output_tokens", 0),
            "cache_read": cached, "cache_write": u.get("cache_write_input_tokens", 0),
            "reasoning": u.get("reasoning_output_tokens", 0)}


def new_lines(f: Path, st: dict):
    """커서 뒤의 온전한 줄. 파일이 바뀌었으면(다른 inode·줄어듦) 처음부터 — 메시지 id 로 중복을 막는다."""
    info = f.stat()
    if st.get("ino") != info.st_ino or info.st_size < st.get("off", 0):
        st.update(ino=info.st_ino, off=0)
    with f.open("rb") as fh:
        fh.seek(st["off"])
        raw = fh.read()
    whole = raw[:raw.rfind(b"\n") + 1]                  # 쓰는 중인 마지막 줄은 다음에 읽는다
    st["off"] += len(whole)
    for ln in whole.splitlines():
        try:
            yield json.loads(ln)
        except ValueError:
            st["bad"] = st.get("bad", 0) + 1


def seen(st: dict, key: str) -> bool:
    ids = st.setdefault("ids", [])
    if key in ids:
        return True
    ids.append(key)
    del ids[:-500]
    return False


def source_dirs(sources: dict) -> dict:
    """출처(하네스 루트는 "", worktree 는 그 이름) → 그 실행 디렉터리의 적힌 경로와 실제 경로로 푼 경로."""
    return {name: {str(p), str(Path(p).resolve())} for name, p in sources.items()}


def import_claude(sources: dict, cursor: dict, since, roles: set):
    base = Path(os.environ.get("HARNESS_CLAUDE_DIR") or Path.home() / ".claude" / "projects")
    dirs = {}
    for src, paths in source_dirs(sources).items():
        for p in paths:
            dirs.setdefault(re.sub(r"[^A-Za-z0-9]", "-", p), src)
    for d, src in ((base / n, s) for n, s in dirs.items()):
        for f in sorted(d.glob("*.jsonl")) + sorted(d.glob("*/subagents/agent-*.jsonl")) if d.is_dir() else []:
            if datetime.datetime.fromtimestamp(f.stat().st_mtime, datetime.timezone.utc) < since:
                continue
            role = ""
            if f.parent.name == "subagents":
                try:
                    role = json.loads(f.with_suffix(".meta.json").read_text(encoding="utf-8")).get("agentType", "")
                except (OSError, ValueError):
                    role = ""
                role = role if role in roles else ("other" if role else "")
            st = cursor.setdefault("claude:" + str(f), {})
            for e in new_lines(f, st):
                m = e.get("message") or {}
                if e.get("type") != "assistant" or "usage" not in m or seen(st, m.get("id") or e.get("uuid", "")):
                    continue
                t = parse_iso(e["timestamp"])
                if t >= since:
                    yield {"vendor": "claude", "session": e.get("sessionId", f.stem), "role": role, "t": t,
                           "model": m.get("model", ""), "usage": claude_usage(m["usage"]), "src": src}


def import_codex(sources: dict, cursor: dict, since):
    base = Path(os.environ.get("HARNESS_CODEX_DIR") or Path.home() / ".codex" / "sessions")
    # worktree 를 먼저 본다 — 하네스 루트와 겹치지 않지만, 겹쳐도 더 좁은 쪽이 출처다
    mine = sorted(source_dirs(sources).items(), key=lambda x: x[0] == "")
    for f in sorted(base.rglob("rollout-*.jsonl")) if base.is_dir() else []:
        st = cursor.setdefault("codex:" + str(f), {})
        if st.get("other") or datetime.datetime.fromtimestamp(f.stat().st_mtime, datetime.timezone.utc) < since:
            continue
        for e in new_lines(f, st):
            p = e.get("payload") or {}
            kind = e.get("type")
            if kind == "session_meta":
                cwd = p.get("cwd", "")
                src = next((n for n, ps in mine if any(cwd == m or cwd.startswith(m + "/") for m in ps)), None)
                st["mine"], st["src"] = src is not None, src or ""
                st["other"] = not st["mine"]            # 다른 프로젝트의 기록은 다시 열지 않는다
                st["session"] = p.get("id", f.stem)
                continue
            if not st.get("mine"):
                continue
            if kind == "turn_context" and p.get("model"):
                st["model"] = p["model"]
            t = parse_iso(e["timestamp"]) if e.get("timestamp") else None
            if kind == "token_usage_record":
                st["rec"] = True
                if seen(st, p.get("response_id", "")) or not t or t < since:
                    continue
                yield {"vendor": "codex", "session": st.get("session", f.stem), "role": "", "t": t,
                       "model": st.get("model", ""), "usage": codex_usage(p.get("usage") or {}), "src": st.get("src", "")}
            elif kind == "event_msg" and p.get("type") == "token_count" and not st.get("rec"):
                tot = ((p.get("info") or {}).get("total_token_usage")) or {}
                cur = codex_usage(tot)
                if not any(cur.values()):
                    continue                            # 합계만 있고 내역이 없는 기록(가져온 대화 등)은 세지 않는다
                prev = st.get("cum") or {k: 0 for k in cur}
                st["cum"] = cur
                delta = {k: max(0, cur[k] - prev.get(k, 0)) for k in cur}
                if any(delta.values()) and t and t >= since:
                    yield {"vendor": "codex", "session": st.get("session", f.stem), "role": "", "t": t,
                           "model": st.get("model", ""), "usage": delta, "src": st.get("src", "")}


def metrics_import(target: Path, mc: dict, state: Path, roles: set, worktree_dir: str = "", prefix: str = "") -> dict:
    """새 대화 기록을 스팬으로 옮긴다. 커서는 지표와 따로(보관 정책 밖에) 두고 원자적으로 바꾼다.

    mc 는 해석한 지표 설정, state 는 가져오기 커서를 둘 디렉터리, roles 는 설정의 역할 이름이다.
    worktree_dir 은 확장한 worktree.dir, prefix 는 하네스 루트의 리포 내 위치다. run 스팬의 worktree
    이름마다 실행 디렉터리를 <worktree_dir>/<이름>/<prefix> 로 다시 계산해 그 대화 기록도 읽는다 —
    스팬은 경로를 갖지 않는다.
    """
    m = load_metric(target)
    if not m or mc["dir"] == "off":
        return {"enabled": False}
    now = datetime.datetime.now(datetime.timezone.utc)
    since = now - datetime.timedelta(days=mc["retention_days"])
    cur_file = state / "import-cursor.json"
    try:
        cursor = json.loads(cur_file.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        cursor = {}
    spans, _ = read_spans(Path(os.path.expandvars(os.path.expanduser(mc["dir"]))))
    runs, marks = [], {}
    for sid, e in spans.items():
        s = e.get("start") or {}
        if s.get("kind") == "command" and s.get("name", "").startswith("run/"):
            t1 = parse_iso(e["end"]["t"]) if e.get("end") else now
            runs.append((s["trace"], sid, s["attrs"].get("vendor", ""), parse_iso(s["t"]), t1, s["attrs"].get("worktree", "")))
        elif s.get("kind") == "marker":
            marks.setdefault(s["trace"], []).append((parse_iso(s["t"]), s["attrs"]))
    for v in marks.values():
        v.sort(key=lambda x: x[0])

    sources = {"": target}
    if os.path.isabs(worktree_dir or ""):
        for name in sorted({x[5] for x in runs if x[5] and x[4] >= since}):
            sources[name] = Path(worktree_dir, name, prefix) if prefix else Path(worktree_dir, name)
    records = list(import_claude(sources, cursor, since, roles)) + list(import_codex(sources, cursor, since))

    groups = {}
    for r in records:
        # worktree 의 기록은 그 worktree 의 실행에만, 하네스 루트의 기록은 worktree 없는 실행에만 붙는다
        hit = [x for x in runs if x[2] == r["vendor"] and x[5] == r["src"]
               and x[3] <= r["t"] <= x[4] + datetime.timedelta(seconds=60)]
        trace, parent = (hit[0][0], hit[0][1]) if len(hit) == 1 else (UNATTRIBUTED, None)
        step = next((a for t, a in reversed(marks.get(trace, [])) if t <= r["t"]), {})
        key = (trace, parent, r["session"], r["vendor"], r["role"], r["model"], step.get("workflow", ""), step.get("step", ""))
        g = groups.setdefault(key, {"t0": r["t"], "t1": r["t"], "usage": {k: 0 for k in r["usage"]}, "n": 0})
        g["t0"], g["t1"], g["n"] = min(g["t0"], r["t"]), max(g["t1"], r["t"]), g["n"] + 1
        for k, x in r["usage"].items():
            g["usage"][k] += x
    for (trace, parent, _session, vendor, role, model, wf, stp), g in groups.items():
        attrs = m.clean_attrs(["vendor=" + vendor, "model=" + model, "role=" + role, "workflow=" + wf, "step=" + stp])
        name = role or ("%s/%s" % (wf, stp) if stp else "session/%s" % vendor)
        _, sid = m.start(name, "agent" if role else "session", attrs, trace=trace, parent=parent or "", source="session", t=g["t0"])
        m.end(sid, "ok", dur_ms=(g["t1"] - g["t0"]).total_seconds() * 1000, usage=g["usage"], model=model or None, t=g["t1"])

    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    tmp = cur_file.with_suffix(".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(cursor, fh)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, cur_file)
    return {"enabled": True, "records": len(records), "spans": len(groups),
            "unattributed": sum(1 for k in groups if k[0] == UNATTRIBUTED),
            "bad_lines": sum(x.get("bad", 0) for x in cursor.values())}
