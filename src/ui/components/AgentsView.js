"use client";
import { useRef, useState, useTransition } from "react";
import { saveRoleNotes, checkMarkdown } from "@/lib/actions";
import { RoleChip, RunnerTag, ACCESS } from "@/components/Agent";
import Markdown from "@/components/Markdown";
import ModeToggle from "@/components/ModeToggle";
import CheckReport from "@/components/CheckReport";
import RoleEditor from "@/components/RoleEditor";

// 역할 카드를 가로로 넘겨 보고, 고른 역할의 계약(읽기 전용)과 이 프로젝트의 지시(편집)를 아래에 연다.
export default function AgentsView({ project, schema, tools, files }) {
  const names = Object.keys(schema.roles);
  const [sel, setSel] = useState(names[0]);
  const track = useRef(null);
  const slide = (d) => track.current?.scrollBy({ left: d * track.current.clientWidth * 0.8, behavior: "smooth" });

  return (
    <>
      <div className="carousel">
        <button type="button" className="icon car-nav" aria-label="이전 에이전트" onClick={() => slide(-1)}>‹</button>
        <div className="car-track" ref={track} role="listbox" aria-label="에이전트" aria-activedescendant={`agent-${sel}`}
          tabIndex={0} onKeyDown={(e) => {
            const i = names.indexOf(sel);
            if (e.key === "ArrowRight" && i < names.length - 1) setSel(names[i + 1]);
            if (e.key === "ArrowLeft" && i > 0) setSel(names[i - 1]);
          }}>
          {names.map((n) => {
            const r = schema.roles[n];
            return (
              <button key={n} id={`agent-${n}`} type="button" role="option" aria-selected={n === sel}
                className={`agent-card${n === sel ? " on" : ""}`} onClick={() => setSel(n)}
                ref={(el) => n === sel && el?.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "smooth" })}>
                <RoleChip name={n} />
                <p className="agent-desc">{r.about}</p>
                <div className="agent-foot">
                  <RunnerTag role={n} schema={schema} />
                  <span className="tag-sm">{ACCESS[r.access]}</span>
                  {r.model && <span className={`tag-sm mono${r.model_ok === false ? " warn" : ""}`} title={r.model_ok === false ? "실행 주체의 모델이 아니다" : undefined}>{r.model}</span>}
                  {files[n].notes.trim() && <span className="badge">Custom</span>}
                </div>
              </button>
            );
          })}
        </div>
        <button type="button" className="icon car-nav" aria-label="다음 에이전트" onClick={() => slide(1)}>›</button>
      </div>
      <AgentDetail key={sel} project={project} name={sel} schema={schema} tools={tools} file={files[sel]} />
    </>
  );
}

function AgentDetail({ project, name, schema, tools, file }) {
  const initial = file.notes;
  const [text, setText] = useState(initial);
  const [edit, setEdit] = useState(false);
  const [tab, setTab] = useState("settings");   // 설정이 먼저 — 지시는 선택 사항이라 탭 뒤에 둔다
  const [report, setReport] = useState(null);
  const [msg, setMsg] = useState(null);
  const [busy, setBusy] = useState(null);
  const [, start] = useTransition();
  // 진행 표시는 transition 밖에서 켠다 — 안에서 켜면 작업이 끝날 때까지 화면에 반영되지 않는다
  const act = (k, fn) => { setBusy(k); start(async () => { try { await fn(); } finally { setBusy(null); } }); };

  const write = () => act("save", async () => { setReport(null); setMsg(await saveRoleNotes(project, name, text)); });
  const save = () => act("check", async () => {
    const r = await checkMarkdown(project, text);
    if (!r.issues.length && !r.failed) { setMsg(await saveRoleNotes(project, name, text)); return; }
    setReport(r);
  });

  return (
    <div className="agent-detail">
      <section className="card">
        <div className="card-head"><h2>Contract <code className="key fname">{schema.roles[name].contract}</code></h2></div>
        <div className="md-view contract"><Markdown>{file.contract}</Markdown></div>
      </section>
      <section className="card draft">
        <div className="card-head">
          <div className="seg small" role="tablist" aria-label="에이전트 설정">
            <button role="tab" aria-selected={tab === "settings"} className={tab === "settings" ? "on" : ""} onClick={() => setTab("settings")}>Settings</button>
            <button role="tab" aria-selected={tab === "notes"} className={tab === "notes" ? "on" : ""} onClick={() => setTab("notes")}>
              Instructions{initial.trim() && <span className="badge">Custom</span>}
            </button>
          </div>
          {tab === "notes" && <ModeToggle edit={edit} onChange={setEdit} />}
        </div>
        {tab === "settings" ? (
          <RoleEditor project={project} name={name} schema={schema} tools={tools} />
        ) : (<>
          <code className="key notes-path fname">{schema.roles[name].notes}</code>
          {edit
            ? <textarea className="md-edit" value={text} spellCheck={false} aria-label="마크다운 편집"
                placeholder={"- 이 역할이 이 리포에서만 지킬 것\n- 제목은 쓰지 않는다 — \"이 프로젝트에서\" 절 안에 들어간다"} onChange={(e) => { setText(e.target.value); setReport(null); }} />
            : <div className="md-view">{text.trim() ? <Markdown>{text}</Markdown> : <p className="muted">더한 지시가 없다. 선택 사항이다 — 연필을 눌러 쓴다.</p>}</div>}
          {report && <CheckReport result={report} pending={busy === "save"} onSave={write} onCancel={() => { setReport(null); setEdit(true); }} />}
          {msg && <pre className={msg.ok ? "result ok" : "result err"}>{msg.out}</pre>}
          <div className="row end">
            <button className="btn" disabled={!!busy || text === initial} onClick={() => { setText(initial); setReport(null); }}>Revert</button>
            <button className="btn primary" aria-busy={!!busy} disabled={!!busy || text === initial || !!report} onClick={save}>
              {busy === "check" ? "Checking…" : busy === "save" ? "Saving…" : "Check & Save"}
            </button>
          </div>
        </>)}
      </section>
    </div>
  );
}
