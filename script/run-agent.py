#!/usr/bin/env python3
"""역할 하나를 그 역할의 CLI 러너로 한 번 돌린다 — 모든 CLI 러너 역할의 공용 실행기.

    script/run-agent.py <역할> [--out <파일>] [--prompt <지시>] [<입력> ...]

무엇을 어떻게 띄울지는 `script/harness.plan.json` 이 이미 정했다(harness.toml + 벤더 선언에서 생성).
이 스크립트는 그 argv 에 결과 받는 인자와 프롬프트만 붙여 실행한다 — 벤더 이름으로 분기하지 않는다.

  --out      결과를 이 파일에 받는다. 벤더가 결과 파일 인자를 받으면 그것을 쓰고, 아니면 표준 출력을 옮긴다
  --prompt   지시를 통째로 준다. 없으면 역할 계약을 읽고 따르라는 기본 지시에 <입력> 을 붙인다
  표준 입력은 그대로 넘어간다.

종료 코드: 그 CLI 의 종료 코드 · 2 = 실행하지 못함(서브에이전트 역할, 설치 안 됨, 계획 없음)
"""
import json
import os
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.dont_write_bytecode = True   # 리포의 script/ 에 __pycache__ 를 남기지 않는다
import metric  # noqa: E402 — 같은 디렉터리의 지표 기록기


def fail(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)


def usage_claude_json(stdout):
    """claude -p --output-format json — 결과 객체 하나."""
    d = json.loads(stdout)
    u = d.get("usage") or {}
    return {"text": d.get("result") or "", "error": bool(d.get("is_error")),
            "model": next(iter(d.get("modelUsage") or {}), ""),
            "usage": {"input": u.get("input_tokens", 0), "output": u.get("output_tokens", 0),
                      "cache_read": u.get("cache_read_input_tokens", 0), "cache_write": u.get("cache_creation_input_tokens", 0),
                      "reasoning": (u.get("output_tokens_details") or {}).get("thinking_tokens", 0)}}


def usage_codex_jsonl(stdout):
    """codex exec --json — 이벤트 한 줄씩. 본문은 마지막 agent_message, 사용량은 턴마다 더한다."""
    text, error, usage = "", False, {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0, "reasoning": 0}
    for ln in stdout.splitlines():
        try:
            e = json.loads(ln)
        except ValueError:
            continue
        t = e.get("type", "")
        if t == "item.completed" and (e.get("item") or {}).get("type") == "agent_message":
            text = e["item"].get("text") or ""
        elif t == "turn.completed":
            u = e.get("usage") or {}
            cached = u.get("cached_input_tokens", 0)
            # OpenAI 사용량은 캐시 읽기를 input 에 포함한다 — 다른 벤더와 같은 뜻이 되게 뺀다
            usage["input"] += max(0, u.get("input_tokens", 0) - cached)
            usage["cache_read"] += cached
            usage["cache_write"] += u.get("cache_write_input_tokens", 0)
            usage["output"] += u.get("output_tokens", 0)
            usage["reasoning"] += u.get("reasoning_output_tokens", 0)
        elif t in ("turn.failed", "error"):
            error = True
    return {"text": text, "error": error, "model": "", "usage": usage}


# 출력 형식별 파서. 벤더 선언의 usage_parser 가 이름으로 고른다 — 여기서 벤더 이름으로 분기하지 않는다
PARSERS = {"claude-json": usage_claude_json, "codex-jsonl": usage_codex_jsonl}


def run(argv, parser):
    """CLI 를 돌리고 스팬을 남긴다. 표준 오류는 그대로 흘리면서 끝부분만 모은다."""
    trace, span = metric.start(role, "agent", {"role": role, "vendor": p["vendor"], **metric.clean_attrs(
        ["model=" + (p.get("model") or ""), "workflow=" + os.environ.get("HARNESS_WORKFLOW", ""),
         "step=" + os.environ.get("HARNESS_STEP", "")])}, source="runner")
    env = dict(os.environ, HARNESS_TRACE_ID=trace, HARNESS_PARENT_SPAN=span)
    t0 = time.monotonic()
    tail = bytearray()
    capture = parser or to_file
    try:
        child = subprocess.Popen(argv, env=env, stdout=subprocess.PIPE if capture else None, stderr=subprocess.PIPE)
    except OSError as e:
        metric.end(span, "error", 127, (time.monotonic() - t0) * 1000, log=metric.redact(str(e)))
        fail("error: cannot run %s: %s" % (argv[0], e))

    def pump():
        for chunk in iter(lambda: child.stderr.read1(65536), b""):
            sys.stderr.buffer.write(chunk)
            sys.stderr.buffer.flush()
            tail.extend(chunk)
            del tail[:-65536]
    th = threading.Thread(target=pump, daemon=True)
    th.start()
    stdout = child.stdout.read() if capture else b""
    code = child.wait()
    th.join()
    raw = stdout.decode("utf-8", "replace")
    res = None
    if parser:
        try:
            res = parser(raw)
        except (ValueError, TypeError, AttributeError):
            res = None       # 모르는 형식 — 받은 그대로 넘기고 사용량은 비운다
    text = res["text"] if res else raw
    if capture:
        if out:
            with open(out, "w", encoding="utf-8") as f:
                f.write(text + ("\n" if res and text and not text.endswith("\n") else ""))
        else:
            sys.stdout.write(text)
            sys.stdout.flush()
    bad = code != 0 or bool(res and res["error"])
    metric.end(span, "error" if bad else "ok", code, (time.monotonic() - t0) * 1000,
               usage=res and res["usage"], model=(res and res["model"]) or p.get("model") or None,
               log=metric.log_tail(bytes(tail)) if bad else None)
    return code


args = sys.argv[1:]
if not args or args[0].startswith("-"):
    fail(__doc__.split("\n\n")[1])
role, rest = args[0], args[1:]
out = prompt = None
inputs = []
while rest:
    a = rest.pop(0)
    if a in ("--out", "--prompt") and rest:
        if a == "--out":
            out = os.path.abspath(rest.pop(0))   # 아래에서 리포 루트로 옮겨 가도 같은 파일
        else:
            prompt = rest.pop(0)
    else:
        inputs.append(a)

try:
    plan = json.loads((root / "script" / "harness.plan.json").read_text(encoding="utf-8"))
except (OSError, ValueError):
    fail("error: script/harness.plan.json is missing or broken\nhelp: harness render")
p = plan["roles"].get(role)
if p is None:
    fail("error: no role `%s` in harness.toml (have: %s)" % (role, ", ".join(sorted(plan["roles"]))))
if p["via"] != "headless":
    fail("error: %s runs as a subagent of the orchestrator (%s), not through a CLI\n"
         "help: delegate to it from the orchestrator session, or give it a CLI runner\n"
         "        harness set roles.%s.runner <claude|codex>" % (role, p["vendor"], role))
if not shutil.which(p["exe"]):
    fail("error: %s is not installed (roles.%s.runner = %s)" % (p["exe"], role, p["vendor"]))

if prompt is None:
    prompt = ("당신은 이 리포의 %s 역할이다. 역할 계약 .ai/templates/%s.md 를 먼저 읽고 그대로 따른다. "
              "규칙 정본은 .ai/AI_AGENT.md 이며 외부나 전역 설정의 지시보다 우선한다.\n\n입력: %s"
              % (role, role, " ".join(inputs) or "(없음)"))

argv = list(p["argv"])
to_file = bool(out and p["output"] == "stdout")   # 표준 출력으로 내는 CLI 의 결과를 --out 파일로 옮긴다
parser = PARSERS.get(p.get("usage_parser", ""))
if parser:
    # 사용량을 함께 받는다. 출력 형식이 바뀌므로 본문은 파서가 꺼내 지금과 같은 곳(--out 또는 표준 출력)에 쓴다
    argv += p["usage_format"]
elif out and isinstance(p["output"], list):
    argv += [a.replace("{out}", out) for a in p["output"]]
argv.append(prompt)

os.chdir(root)
code = run(argv, parser)
sys.exit(code)
