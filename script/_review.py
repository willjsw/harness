#!/usr/bin/env python3
"""리뷰 루프(review-mr.sh)의 파이썬 전부. 스크립트로만 실행하고 import 하지 않는다.

    python3 script/_review.py <하위명령> <인자...>

표지는 이 파일에 적지 않는다. 부르는 스크립트가 `script/harness-format.sh` 를 자동 export 로
source 하고, 여기서는 환경의 `FMT_*` 값을 읽는다. 하위명령에 필요한 표지가 환경에 없으면
종료 코드 2 로 끝난다.

하위명령:
  plan-exe <실행계획>                 code-reviewer 의 실행 파일 이름
  mr-field <리뷰요청JSON> <필드>      정규화된 리뷰 요청 JSON 의 필드 하나
  round <리뷰요청JSON> <회차접두>     회차 라벨 최댓값(첫 줄)과 해당 라벨 목록(둘째 줄). 없으면 0
  issue-ref <리뷰요청JSON>            본문의 종료 참조가 가리키는 이슈 번호. 없으면 빈 줄
  context <작업디렉터리> <직전회차> <이슈번호>
                                      리뷰 입력의 맥락 절(context.md)과 직전 리뷰 시점 head(prev-sha)
"""
import glob
import json
import os
import re
import sys


def die(msg, code=2):
    sys.stderr.write(f"error: {msg}\n")
    sys.exit(code)


def fmt(name):
    """환경의 표지 값. 없으면 종료 코드 2 — 기본값을 두면 표지 정본과 조용히 갈린다."""
    val = os.environ.get(name)
    if val is None or val == "":
        die(f"marker {name} is not in the environment — source script/harness-format.sh with set -a")
    return val


def load_json(path, default=None):
    try:
        with open(path, encoding="utf-8") as fp:
            text = fp.read().strip()
        return json.loads(text) if text else default
    except (OSError, json.JSONDecodeError):
        return default


def inline_prefix(severity):
    """인라인 발견 본문의 첫 줄 접두."""
    return f"**[{severity}]**"


def inline_finding_re():
    """인라인 발견 본문을 알아보는 패턴. 심각도는 FMT_INLINE_SEVERITIES 가 정한다."""
    sev = "|".join(re.escape(s) for s in fmt("FMT_INLINE_SEVERITIES").split())
    return re.compile(r"^\*\*\[(?:%s)\]\*\*" % sev)


# ── review-mr.sh ───────────────────────────────────────────────────────────

def cmd_plan_exe(args):
    if len(args) != 1:
        die("usage: _review.py plan-exe <plan.json>")
    try:
        with open(args[0], encoding="utf-8") as fp:
            role = json.load(fp)["roles"]["code-reviewer"]
    except (OSError, ValueError, KeyError, TypeError):
        sys.exit(1)
    print(role.get("exe", ""))


def cmd_mr_field(args):
    if len(args) != 2:
        die("usage: _review.py mr-field <mr.json> <field>")
    try:
        with open(args[0], encoding="utf-8") as fp:
            mr = json.load(fp)
    except (OSError, ValueError):
        sys.exit(1)
    print(mr.get(args[1], ""))


def cmd_round(args):
    if len(args) != 2:
        die("usage: _review.py round <mr.json> <round-label-prefix>")
    try:
        with open(args[0], encoding="utf-8") as fp:
            labels = json.load(fp).get("labels") or []
    except (OSError, ValueError, AttributeError):
        sys.exit(1)
    pat = re.compile(re.escape(args[1]) + r":(\d+)")
    found = {n: int(m.group(1)) for n in labels if (m := pat.fullmatch(n.strip()))}
    print(max(found.values()) if found else 0)
    print(" ".join(sorted(found)))


def cmd_issue_ref(args):
    if len(args) != 1:
        die("usage: _review.py issue-ref <mr.json>")
    closes = fmt("FMT_MR_CLOSES")
    mr = load_json(args[0], {}) or {}
    desc = mr.get("description") or ""
    m = re.search(r"(?i)\b%s\s+\S*?#?([0-9A-Za-z][0-9A-Za-z-]*)" % re.escape(closes), desc)
    print(m.group(1) if m else "")


HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")


def md_section(text, title):
    """제목이 일치하는 절의 본문. 같은 수준 이상의 다음 제목에서 끝난다. 없으면 None."""
    lines = (text or "").splitlines()
    start = level = None
    for i, ln in enumerate(lines):
        m = HEADING.match(ln)
        if not m:
            continue
        if start is None:
            if m.group(2).strip() == title:
                start, level = i + 1, len(m.group(1))
        elif len(m.group(1)) <= level:
            return "\n".join(lines[start:i]).strip()
    return None if start is None else "\n".join(lines[start:]).strip()


def quote(text):
    """인용한 본문의 제목 줄이 입력의 절 제목으로 읽히지 않게 접두한다."""
    return "\n".join(("> " + ln).rstrip() for ln in (text or "").strip().splitlines())


def cmd_context(args):
    if len(args) != 3:
        die("usage: _review.py context <work-dir> <previous-rounds> <issue-ref>")
    work, prev_rounds, issue_ref = args
    prev_rounds = int(prev_rounds)
    purpose = fmt("FMT_MR_PURPOSE")
    points = fmt("FMT_MR_REVIEW_POINTS")
    summary_head = fmt("FMT_SUMMARY_HEADING")
    reviewed_head = fmt("FMT_REVIEWED_HEAD")
    finding = inline_finding_re()
    head_line = re.compile(re.escape(reviewed_head) + r" `([0-9a-f]{7,40})`")

    mr = load_json(os.path.join(work, "mr.json"), {}) or {}
    out = []

    # 본문에서 목적과 리뷰 요청 포인트만 가져온다. 둘 다 찾지 못하면 본문 전체를 넘긴다.
    desc = mr.get("description") or ""
    parts = []
    for title in (purpose, points):
        body = md_section(desc, title)
        if body:
            parts.append(f"### {title}\n\n{quote(body)}")
    if not parts and desc.strip():
        parts.append(quote(desc))
    if parts:
        out.append("## 리뷰 요청 본문\n\n" + "\n\n".join(parts))

    issue = load_json(os.path.join(work, "issue.json"), {}) or {}
    if issue.get("description"):
        spec = sorted(glob.glob(f"docs/spec/{issue_ref}-*.md"))
        tail = ("\n\n명세: " + " · ".join(spec)) if spec else ""
        out.append(f"## 이슈 본문 — {issue_ref} {issue.get('title', '').strip()}".rstrip()
                   + f"\n\n{quote(issue['description'])}{tail}")

    # 직전 회차의 요약과, 그 회차 발견에 달린 답글.
    if prev_rounds >= 1:
        threads = load_json(os.path.join(work, "threads.json"), []) or []
        summaries = sorted(
            (n for t in threads for n in t.get("notes", [])
             if (n.get("body") or "").lstrip().startswith(summary_head)),
            key=lambda n: n.get("created_at") or "")

        if summaries:
            last = summaries[-1]
            last_at = last.get("created_at") or ""
            since = summaries[-2].get("created_at") or "" if len(summaries) > 1 else ""
            found = head_line.search(last.get("body") or "")
            if found:
                with open(os.path.join(work, "prev-sha"), "w", encoding="utf-8") as fp:
                    fp.write(found.group(1))
            else:
                sys.stderr.write("warning: the previous summary records no reviewed revision — "
                                 "falling back to the cumulative diff\n")
            block = [f"## 직전 회차 리뷰 ({prev_rounds}회차)", "", "### 자동 리뷰 요약", "",
                     quote(last.get("body"))]
            # 인라인 발견은 그 회차 요약 직전에 달린다. 직전 요약과 그 앞 요약 사이가 직전 회차다.
            for t in threads:
                notes = t.get("notes") or []
                if len(notes) < 2 or not finding.match((notes[0].get("body") or "").strip()):
                    continue
                at = notes[0].get("created_at") or ""
                if not (since < at <= last_at):
                    continue
                block += ["", "### 발견과 그에 달린 답글", "", quote(notes[0].get("body"))]
                for n in notes[1:]:
                    block += ["", "답글:", "", quote(n.get("body"))]
            out.append("\n".join(block))

    if out:
        with open(os.path.join(work, "context.md"), "w", encoding="utf-8") as fp:
            fp.write("\n\n".join(out) + "\n\n")


COMMANDS = {
    "plan-exe": cmd_plan_exe,
    "mr-field": cmd_mr_field,
    "round": cmd_round,
    "issue-ref": cmd_issue_ref,
    "context": cmd_context,
}


def main(argv):
    if len(argv) < 2 or argv[1] not in COMMANDS:
        die("usage: _review.py {%s} <args...>" % "|".join(COMMANDS))
    COMMANDS[argv[1]](argv[2:])


if __name__ == "__main__":
    main(sys.argv)
