#!/usr/bin/env python3
"""리뷰 루프(review-mr.sh · post-review.sh)의 파이썬 전부. 스크립트로만 실행하고 import 하지 않는다.

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
  judge <리뷰본문> <누적파일> <반복상한> <작업디렉터리>
                                      판정 데이터를 검증·집계해 작업 디렉터리에 쓴다. 계약 위반이면 2
  render <작업디렉터리> <작성자표시> <리뷰한리비전> <인라인실패건수> <반복상한>
                                      judge 결과로 요약 댓글 본문(note.md)을 만든다

judge 가 작업 디렉터리에 쓰는 것 (post-review.sh 와의 내부 형식):
  data.json  검증을 통과한 판정 데이터       counts   "<blocker> <major> <minor>"
  computed   등급 집계로 낸 판정              inline   <path>\t<line>\t<본문>\0 의 나열
  append     이번 회차의 누적분               reset    있으면 누적 파일을 비우고 쓴다
  repeat     연속 상한에 닿은 "<회차>\t<키>"
"""
import glob
import json
import os
import re
import sys
import unicodedata


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
    """발견 본문의 첫 줄 접두. 다음 회차가 인라인 발견을 이것으로 알아본다."""
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


# ── 판정 데이터 ────────────────────────────────────────────────────────────
# 스키마의 정본. 검증·집계·렌더링이 모두 이 정의를 쓴다.

TOP_KEYS = ("summary", "findings", "strengths", "verdict")
FINDING_KEYS = ("severity", "path", "line", "title", "problem", "repro",
                "recommendation", "out_of_scope", "decision_basis")
SEVERITIES = ("blocker", "major", "minor")

# 누적 파일 첫 줄의 형식 판별자. 반복 키 구성이 바뀌면 숫자를 올린다 — 옛 형식 줄은 새 키와
# 비교할 수 없어, 이어 쓰면 회수가 틀린다. 판별자가 다르면 이전 기록을 버리고 다시 센다.
HIST_FORMAT = "#format 1"
# blocker·major 가 없던 회차의 자리표시자. 회차 번호를 잇고 연속을 끊는 역할만 한다.
NO_FINDING = "-"

# 여는 줄의 ``` 뒤 전부가 info string 이다. 공백을 걷어 내지 않는다 — 떼는 것은 CRLF 의 CR 하나뿐이다.
FENCE = re.compile(r"^```(.*?)\r?$")


class Violation(Exception):
    pass


def extract_block(text, info):
    """info string 이 정확히 info 인 fenced 블록 하나의 내용. 없거나 둘 이상이면 위반."""
    # LF 로만 자른다. splitlines 는 JSON 문자열 안의 U+2028·U+0085 에서도 잘라 블록을 깨뜨린다.
    lines = text.split("\n")
    blocks, i = [], 0
    while i < len(lines):
        m = FENCE.match(lines[i])
        if not m:
            i += 1
            continue
        tag = m.group(1)
        j = i + 1
        while j < len(lines) and not re.match(r"^```\s*$", lines[j]):
            j += 1
        if j >= len(lines):
            if tag == info:
                raise Violation(f"the ```{info} block is not closed")
            break
        if tag == info:
            blocks.append("\n".join(lines[i + 1:j]))
        i = j + 1
    if not blocks:
        raise Violation(f"no ```{info} block in the review output")
    if len(blocks) > 1:
        raise Violation(f"{len(blocks)} ```{info} blocks in the review output — exactly one is allowed")
    return blocks[0]


def _pairs(pairs):
    obj = {}
    for k, v in pairs:
        if k in obj:
            raise Violation(f"duplicate key '{k}'")
        obj[k] = v
    return obj


def _no_constant(name):
    raise Violation(f"'{name}' is not JSON")


def _text(v):
    return isinstance(v, str) and v.strip() != ""


# str.splitlines 가 줄 경계로 보는 문자 전부. 한 줄 문자열에 들어오면 등록 댓글의 줄 구조가 깨진다.
LINE_BREAKS = frozenset("\n\r\x0b\x0c\x1c\x1d\x1e\x85\u2028\u2029")
# 경로에는 제어 문자(Cc)·줄·문단 구분자(Zl·Zp)·서식 문자(Cf — 양방향 재정렬 등)를 받지 않는다.
# 누적 파일의 한 줄 기록이 깨지고, 보이는 경로와 실제 경로가 달라진다.
PATH_FORBIDDEN = ("Cc", "Zl", "Zp", "Cf")


def _has_category(s, categories):
    return any(unicodedata.category(c) in categories for c in s)


def validate(data, verdicts):
    """스키마를 어긴 첫 위치를 Violation 으로 알린다."""
    if not isinstance(data, dict):
        raise Violation("the block must hold one JSON object")
    for k in data:
        if k not in TOP_KEYS:
            raise Violation(f"{k}: undefined key")
    for k in TOP_KEYS:
        if k not in data:
            raise Violation(f"{k}: required key is missing")
    if not _text(data["summary"]):
        raise Violation("summary: must be a non-blank string")
    if not isinstance(data["strengths"], list):
        raise Violation("strengths: must be an array of strings")
    for i, s in enumerate(data["strengths"]):
        if not _text(s):
            raise Violation(f"strengths[{i}]: must be a non-blank string")
    if data["verdict"] not in verdicts:
        raise Violation("verdict: must be one of %s" % " · ".join(verdicts))
    if not isinstance(data["findings"], list):
        raise Violation("findings: must be an array")
    for i, f in enumerate(data["findings"]):
        at = f"findings[{i}]"
        if not isinstance(f, dict):
            raise Violation(f"{at}: must be an object")
        for k in f:
            if k not in FINDING_KEYS:
                raise Violation(f"{at}.{k}: undefined key")
        for k in FINDING_KEYS:
            if k not in f:
                raise Violation(f"{at}.{k}: required key is missing")
        if f["severity"] not in SEVERITIES:
            raise Violation(f"{at}.severity: must be one of %s" % " · ".join(SEVERITIES))
        path = f["path"]
        if path is not None:
            if not _text(path):
                raise Violation(f"{at}.path: must be a non-blank string or null")
            if path.startswith("/"):
                raise Violation(f"{at}.path: must be relative to the repo, not absolute")
            if ".." in re.split(r"[/\\]", path):
                raise Violation(f"{at}.path: must not contain a '..' segment")
            if _has_category(path, PATH_FORBIDDEN):
                raise Violation(f"{at}.path: must not contain a line break, control or format character")
        line = f["line"]
        if line is not None:
            if isinstance(line, bool) or not isinstance(line, int) or line < 1:
                raise Violation(f"{at}.line: must be an integer of 1 or more, or null")
            if path is None:
                raise Violation(f"{at}.line: must be null when path is null")
        if not _text(f["title"]) or any(c in LINE_BREAKS for c in f["title"]):
            raise Violation(f"{at}.title: must be one non-blank line")
        for k in ("problem", "repro", "recommendation"):
            if not _text(f[k]):
                raise Violation(f"{at}.{k}: must be a non-blank string")
        if not isinstance(f["out_of_scope"], bool):
            raise Violation(f"{at}.out_of_scope: must be true or false")
        basis = f["decision_basis"]
        if basis is not None:
            if not _text(basis):
                raise Violation(f"{at}.decision_basis: must be a non-blank string or null")
            if f["severity"] != "minor":
                raise Violation(f"{at}.decision_basis: a decision review must be minor")


def parse_review(text):
    """리뷰어 출력 → 검증된 판정 데이터."""
    raw = extract_block(text, fmt("FMT_REVIEW_BLOCK"))
    try:
        data = json.loads(raw, object_pairs_hook=_pairs, parse_constant=_no_constant)
    except json.JSONDecodeError as e:
        raise Violation(f"the block is not valid JSON — {e.msg} at line {e.lineno} column {e.colno}")
    validate(data, (fmt("FMT_VERDICT_PASS"), fmt("FMT_VERDICT_CHANGES")))
    return data


def tally(data):
    """등급 건수와 판정. minor 는 판정에 넣지 않는다."""
    counts = {s: 0 for s in SEVERITIES}
    for f in data["findings"]:
        counts[f["severity"]] += 1
    blocking = sum(counts[s] for s in fmt("FMT_INLINE_SEVERITIES").split() if s in counts)
    verdict = fmt("FMT_VERDICT_CHANGES") if blocking else fmt("FMT_VERDICT_PASS")
    return counts, verdict


def location(f):
    if f["path"] is None:
        return fmt("FMT_NO_LOCATION")
    return f"`{f['path']}:{f['line']}`" if f["line"] is not None else f"`{f['path']}`"


def inline_note(f):
    lines = [f"{inline_prefix(f['severity'])} {f['title']}", "",
             f"문제: {f['problem']}", f"재현: {f['repro']}", f"권고: {f['recommendation']}"]
    if f["out_of_scope"]:
        lines.append(fmt("FMT_OUT_OF_SCOPE"))
    return "\n".join(lines)


def cmd_judge(args):
    if len(args) != 4:
        die("usage: _review.py judge <review-body> <history-file> <repeat-max> <work-dir>")
    body_path, hist_path, repeat_max, work = args
    repeat_max = int(repeat_max)
    inline_sev = fmt("FMT_INLINE_SEVERITIES").split()
    no_location = fmt("FMT_NO_LOCATION")
    try:
        with open(body_path, encoding="utf-8") as fp:
            text = fp.read()
    except UnicodeDecodeError:
        sys.stderr.write("contract violation: the review output is not UTF-8\n")
        sys.exit(2)
    try:
        data = parse_review(text)
    except Violation as e:
        sys.stderr.write(f"contract violation: {e}\n")
        sys.exit(2)

    counts, computed = tally(data)
    inline, keys = [], []
    for f in data["findings"]:
        if f["severity"] not in inline_sev:
            continue
        keys.append(f["path"] if f["path"] is not None else no_location)
        if f["path"] is not None and f["line"] is not None:
            inline.append((f["path"], f["line"], inline_note(f).replace("\0", "")))

    def write(name, content):
        with open(os.path.join(work, name), "w", encoding="utf-8") as fp:
            fp.write(content)

    write("data.json", json.dumps(data, ensure_ascii=False))
    write("counts", "{blocker} {major} {minor}\n".format(**counts))
    write("computed", computed + "\n")
    write("inline", "".join(f"{p}\t{ln}\t{note}\0" for p, ln, note in inline))

    # 회차별 누적. 이번 회차의 같은 키는 중복을 접어 한 번만 센다.
    hist_lines = []
    if os.path.exists(hist_path):
        with open(hist_path, encoding="utf-8") as fp:
            hist_lines = fp.read().splitlines()
    compatible = bool(hist_lines) and hist_lines[0].strip() == HIST_FORMAT

    prev, last_run = {}, 0
    for ln in (hist_lines[1:] if compatible else []):
        run, _, key = ln.partition("\t")
        if not key:
            continue
        try:
            run = int(run)
        except ValueError:
            continue
        last_run = max(last_run, run)
        prev.setdefault(key, set()).add(run)

    this_run = last_run + 1
    append = "" if compatible else HIST_FORMAT + "\n"
    for key in (list(dict.fromkeys(keys)) or [NO_FINDING]):
        append += f"{this_run}\t{key}\n"
    write("append", append)
    if not compatible:
        # 누적은 등록에 성공한 뒤에만 한다. 여기서는 갈아엎어야 한다는 사실만 남긴다.
        write("reset", "")

    # 연속한 회차만 센다. 중간에 한 회차라도 그 파일에서 blocker·major 가 나오지 않았으면
    # 직전 수정이 그 파일을 닫았다는 뜻이라, 다시 1 회차부터다.
    repeat = ""
    for key in dict.fromkeys(keys):
        runs = prev.get(key, set()) | {this_run}
        streak = 0
        while this_run - streak in runs:
            streak += 1
        if streak >= repeat_max:
            repeat += f"{streak}\t{key}\n"
    write("repeat", repeat)


def indent_rest(text, pad):
    """여러 줄 값의 둘째 줄부터 pad 만큼 들여 쓴다. 값 안의 제목 문법이 절 제목이 되지 않는다."""
    lines = text.strip("\n").splitlines() or [""]
    return "\n".join([lines[0]] + [(pad + ln).rstrip() for ln in lines[1:]])


def escape_heading(text):
    """행 첫 칸의 제목 문법을 글자로 바꾼다."""
    return "\n".join(("\\" + ln) if ln.startswith("#") else ln for ln in text.strip("\n").splitlines())


def cmd_render(args):
    if len(args) != 5:
        die("usage: _review.py render <work-dir> <author-label> <reviewed-revision> <inline-failures> <repeat-max>")
    work, label, head_sha, inline_fail, repeat_max = args
    inline_fail = int(inline_fail)
    summary_head = fmt("FMT_SUMMARY_HEADING")
    reviewed_head = fmt("FMT_REVIEWED_HEAD")
    no_findings = fmt("FMT_NO_FINDINGS")
    out_of_scope = fmt("FMT_OUT_OF_SCOPE")
    with open(os.path.join(work, "data.json"), encoding="utf-8") as fp:
        data = json.load(fp)
    counts, computed = tally(data)
    repeat = []
    rp = os.path.join(work, "repeat")
    if os.path.exists(rp):
        with open(rp, encoding="utf-8") as fp:
            repeat = [ln.split("\t", 1) for ln in fp.read().splitlines() if "\t" in ln]

    out = [f"{summary_head} ({label})", "",
           "> `script/post-review.sh` 가 등록했다. 판정은 참고용이며 머지 승인은 사람이 한다.",
           ">",
           "> 발견 blocker {blocker} · major {major} · minor {minor} → **판정 {v}**".format(v=computed, **counts),
           "> (minor 는 판정에 넣지 않는다.)"]
    # 다음 회차의 증분 기준. 로컬이 아니라 원격 노트에 남겨야 클론이 바뀌어도 살아남는다.
    if head_sha:
        out += [">", f"> {reviewed_head} `{head_sha}`"]
    if data["verdict"] != computed:
        out += [">", f"> 리뷰어가 선언한 판정은 `{data['verdict']}` 였다. 판정은 발견 등급 집계를 따른다."]
    if repeat:
        out += [">", f"> **한 파일에 blocker·major 가 {repeat_max}회차 연속 나왔다. 루프를 여기서 멈춘다** "
                     "— 코드가 아니라 명세를 다시 본다."]
        out += [f"> - {seen}회차 연속: `{key}`" for seen, key in repeat]
    if inline_fail > 0:
        out += [">", f"> 인라인 {inline_fail} 건은 해당 줄이 이번 diff 에 없어 달지 못했다. 아래 본문을 참조한다."]

    out += ["", "### 요약", "", escape_heading(data["summary"]), "", "### 발견 사항", ""]
    order = {s: i for i, s in enumerate(SEVERITIES)}
    findings = sorted(enumerate(data["findings"]), key=lambda p: (order[p[1]["severity"]], p[0]))
    if not findings:
        out.append(no_findings)
    for _, f in findings:
        out.append(f"- {inline_prefix(f['severity'])} {location(f)} — {f['title']}")
        out.append("  - 문제: " + indent_rest(f["problem"], "    "))
        out.append("  - 재현: " + indent_rest(f["repro"], "    "))
        out.append("  - 권고: " + indent_rest(f["recommendation"], "    "))
        if f["out_of_scope"]:
            out.append(f"  - {out_of_scope}")
        if f["decision_basis"] is not None:
            out.append("  - 결정 재검토 근거: " + indent_rest(f["decision_basis"], "    "))
    if data["strengths"]:
        out += ["", "### 잘된 점", ""]
        out += ["- " + indent_rest(s, "  ") for s in data["strengths"]]

    with open(os.path.join(work, "note.md"), "w", encoding="utf-8") as fp:
        fp.write("\n".join(out) + "\n")


COMMANDS = {
    "plan-exe": cmd_plan_exe,
    "mr-field": cmd_mr_field,
    "round": cmd_round,
    "issue-ref": cmd_issue_ref,
    "context": cmd_context,
    "judge": cmd_judge,
    "render": cmd_render,
}


def main(argv):
    if len(argv) < 2 or argv[1] not in COMMANDS:
        die("usage: _review.py {%s} <args...>" % "|".join(COMMANDS))
    COMMANDS[argv[1]](argv[2:])


if __name__ == "__main__":
    main(sys.argv)
