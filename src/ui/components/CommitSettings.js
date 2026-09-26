"use client";
import { useState, useTransition } from "react";
import { setValue } from "@/lib/actions";
import { enumFor } from "@/lib/enums";
import { commitSubject } from "@/lib/labels";
import Select from "@/components/Select";
import HelpTip from "@/components/HelpTip";
import { HELP } from "@/lib/help";

// Prefix 를 처음 고를 때 채워 두는 키. 사람이 바꿀 수 있다.
const DEFAULT_KEY = "DEV";

// Issue Ref 와 Ticket Key 는 함께 움직인다. Prefix 는 키가 있어야 성립하므로(CLI 가 거부한다)
// Prefix 를 고르면 키 입력이 먼저 나타나고, 키를 저장한 뒤에 Prefix 를 저장한다.
// 키는 Prefix 일 때와 Jira 트래커일 때만 쓰인다 — Jira 는 이슈 키를 이 값으로 만든다.
export default function CommitSettings({ project, tags, issueRef, ticketKey, tracker }) {
  const [ref, setRef] = useState(issueRef);
  const [key, setKey] = useState(ticketKey);
  const [msg, setMsg] = useState(null);
  const [pending, start] = useTransition();
  const showKey = ref === "prefix" || tracker === "jira";
  const waiting = ref === "prefix" && issueRef !== "prefix";   // 키를 기다리는 중

  const choose = (x) => {
    setRef(x); setMsg(null);
    if (x === "prefix" && !key.trim()) setKey(DEFAULT_KEY);
    if (x === "suffix" || ticketKey) start(async () => setMsg(await setValue(project, "commit.issue_ref", x, false)));
  };
  const saveKey = () => start(async () => {
    let r = await setValue(project, "commit.ticket_key", key.trim(), false);
    if (r.ok && waiting) r = await setValue(project, "commit.issue_ref", "prefix", false);
    setMsg(r);
  });

  const tag = tags.includes("chore") ? "chore" : tags[0] ?? "chore";
  const subject = commitSubject({ ref, key: key.trim(), tag, summary: "Project init", issue: 1 });

  return (
    <>
      <div className="field">
        <div className="field-head"><span className="label-help"><label htmlFor="commit.issue_ref">Issue Ref</label><HelpTip text={HELP["commit.issue_ref"]} /></span><code className="key fname">commit.issue_ref</code></div>
        <Select id="commit.issue_ref" value={ref} options={enumFor("commit.issue_ref")} disabled={pending} onChange={choose} />
      </div>
      {showKey && (
        <div className="field">
          <div className="field-head"><span className="label-help"><label htmlFor="commit.ticket_key">Ticket Key</label><HelpTip text={HELP["commit.ticket_key"]} /></span><code className="key fname">commit.ticket_key</code></div>
          {waiting && !ticketKey && <p className="hint">Ticket Key 를 저장하면 Prefix 가 적용된다.</p>}
          <div className="row">
            <input id="commit.ticket_key" value={key} disabled={pending} placeholder={DEFAULT_KEY}
              onChange={(e) => setKey(e.target.value)} onKeyDown={(e) => e.key === "Enter" && key.trim() && saveKey()} />
            {(key !== ticketKey || (waiting && key.trim())) && (
              <button className="btn primary" aria-busy={pending} disabled={pending || !key.trim()} onClick={saveKey}>Save</button>
            )}
          </div>
        </div>
      )}
      <div className="field">
        <div className="field-head"><span className="label-help"><label>Example</label><HelpTip text={HELP["commit.example"]} /></span></div>
        <div className="commit-preview" aria-label="커밋 메시지 예시">
          <div className="commit-subject">{subject}</div>
          <pre className="commit-body">{"- project setting\n- harness init"}</pre>
        </div>
      </div>
      {msg && <pre className={msg.ok ? "result ok" : "result err"}>{msg.out}</pre>}
    </>
  );
}
