"use client";
import { useEffect, useRef, useState, useTransition } from "react";
import { DOCS, fieldsOf, NONE, UNKNOWN } from "@/lib/fields";
import { CODES, staticCheck, asText } from "@/lib/validate";
import { checkFields, completeDoc, saveDoc, checkMarkdown } from "@/lib/actions";
import Markdown from "@/components/Markdown";
import ModeToggle from "@/components/ModeToggle";
import CheckReport from "@/components/CheckReport";
import HelpTip from "@/components/HelpTip";

export default function DocEditor({ project, doc, initial }) {
  const fields = fieldsOf(doc);
  const store = `harness:${project}:${doc}`;   // 입력 중인 항목만 브라우저에 둔다. 정본은 파일이다
  const [values, setValues] = useState({});
  const [errors, setErrors] = useState({});
  const [text, setText] = useState(initial);
  const [msg, setMsg] = useState(null);
  const [busy, setBusy] = useState(null);
  const [edit, setEdit] = useState(false);          // 기본은 읽기
  const [report, setReport] = useState(null);       // 저장 전 검사 결과
  const [, start] = useTransition();
  const [at, setAt] = useState(0);                   // 지금 입력 중인 항목(단계)

  useEffect(() => { try { setValues(JSON.parse(localStorage.getItem(store)) || {}); } catch {} }, [store]);
  const put = (k, v) => {
    const next = { ...values, [k]: v };
    setValues(next);
    try { localStorage.setItem(store, JSON.stringify(next)); } catch {}
  };

  // 진행 표시는 transition 밖에서 켠다 — 안에서 켜면 작업이 끝날 때까지 화면에 반영되지 않는다
  const act = (name, fn) => { setBusy(name); setMsg(null); start(async () => { try { await fn(); } finally { setBusy(null); } }); };

  const check = () => act("check", async () => {
    // 정적 검사로 막히면 모델을 부르지 않는다
    const local = staticCheck(values, fields);
    const e = Object.keys(local).length ? local : await checkFields(project, doc, values);
    setErrors(e);
    jumpToError(e);
    setMsg(Object.keys(e).length ? { ok: false, out: "확인이 필요한 항목이 있습니다. 표시된 항목을 고쳐 주세요." } : { ok: true, out: "모든 항목이 검사를 통과했습니다." });
  });

  const complete = () => act("complete", async () => {
    const local = staticCheck(values, fields);
    if (Object.keys(local).length) { setErrors(local); jumpToError(local); setMsg({ ok: false, out: "확인이 필요한 항목이 있습니다. 표시된 항목을 고쳐 주세요." }); return; }
    const r = await completeDoc(project, doc, values);
    setErrors(r.errors || {});
    jumpToError(r.errors || {});
    if (r.text) { setText(r.text); setEdit(false); setMsg({ ok: true, out: "초안을 채웠습니다. 읽어 본 뒤 저장해 주세요." }); }
    else setMsg({ ok: false, out: r.detail || "확인이 필요한 항목이 있습니다. 표시된 항목을 고쳐 주세요." });
  });

  // 검사가 막은 첫 항목으로 간다
  const jumpToError = (e) => { const i = fields.findIndex((f) => e[f.k]); if (i >= 0) setAt(i); };
  // 끝난 항목: 비어 있지 않고 정적 검사를 통과한 것
  const done = (f) => asText(values[f.k]) !== "" && !staticCheck(values, [f])[f.k];

  const write = () => act("save", async () => { setReport(null); setMsg(await saveDoc(project, doc, text)); });
  // 저장 전에 검사한다. 찾은 것이 없으면 바로 저장하고, 있으면 사람에게 보인다.
  const save = () => act("check-md", async () => {
    const r = await checkMarkdown(project, text);
    if (!r.issues.length && !r.failed) { setMsg(await saveDoc(project, doc, text)); return; }
    setReport(r);
  });

  return (
    <div className="editor">
      <section className="card form">
        <p className="doc-intro">{DOCS[doc].intro}</p>
        {/* 항목마다 한 단계. 끝난 항목은 체크, 지금 항목은 채워진 원으로 보인다 */}
        {fields.length > 1 && <ol className="stepper" aria-label="입력 단계">
          {fields.map((f, i) => (
            <li key={f.k} className={`${i === at ? "now" : ""}${done(f) ? " done" : ""}${errors[f.k] ? " bad" : ""}${f.advanced ? " adv" : ""}`}>
              <button type="button" onClick={() => setAt(i)} aria-current={i === at ? "step" : undefined}
                aria-label={`${i + 1}. ${f.label}${f.advanced ? " (고급, 선택)" : ""}`} title={f.advanced ? `${f.label} — 고급, 선택` : f.label}>
                {done(f) && i !== at
                  ? <svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M3.5 8.5l3 3 6-7" /></svg>
                  : i + 1}
              </button>
            </li>
          ))}
        </ol>}
        <Field key={fields[at].k} f={fields[at]} value={values[fields[at].k]} error={errors[fields[at].k]}
          onChange={(v) => put(fields[at].k, v)} onNext={at < fields.length - 1 ? () => setAt(at + 1) : null} />
        {errors._ && <p className="error" role="alert">{CODES[errors._]}</p>}
        <div className="row between">
          <div className="row">
            <button className="btn" disabled={at === 0} onClick={() => setAt(at - 1)}>← Prev</button>
            <button className="btn" disabled={at === fields.length - 1} onClick={() => setAt(at + 1)}>Next →</button>
          </div>
          <div className="row">
            <button className="btn" aria-busy={busy === "check"} disabled={!!busy} onClick={check}>{busy === "check" ? "Checking…" : "Check"}</button>
            <button className="btn primary" aria-busy={busy === "complete"} disabled={!!busy} onClick={complete}>{busy === "complete" ? "Writing…" : "✦ AI Completion"}</button>
          </div>
        </div>
      </section>
      <section className="card draft">
        <div className="card-head">
          <h2 className="panel-title">문서 <code className="key fname">.ai/project/{doc}.md</code></h2>
          <ModeToggle edit={edit} onChange={setEdit} />
        </div>
        {edit
          ? <textarea className="md-edit" value={text} onChange={(e) => { setText(e.target.value); setReport(null); }} spellCheck={false} aria-label="마크다운 편집" />
          : <div className="md-view"><Markdown>{text}</Markdown></div>}
        {report && <CheckReport result={report} pending={busy === "save"} onSave={write} onCancel={() => { setReport(null); setEdit(true); }} />}
        {msg && <pre className={msg.ok ? "result ok" : "result err"}>{msg.out}</pre>}
        <div className="row end">
          <button className="btn" disabled={!!busy || text === initial} onClick={() => { setText(initial); setReport(null); }}>Revert</button>
          <button className="btn primary" aria-busy={busy === "check-md" || busy === "save"} disabled={!!busy || text === initial || !!report} onClick={save}>{busy === "check-md" ? "Checking…" : busy === "save" ? "Saving…" : "Check & Save"}</button>
        </div>
      </section>
    </div>
  );
}

// 항목 하나. 질문 · 이 답으로 에이전트가 하는 일 · 입력(한 칸 또는 여러 줄) · 없음/모름.
function Field({ f, value, error, onChange, onNext }) {
  const rows = Array.isArray(value) ? value : value ? [value] : [""];
  const one = typeof value === "string" ? value : rows.join("\n");
  const quick = [f.none && NONE, (f.unknown || f.advanced) && UNKNOWN].filter(Boolean);
  // 없음·모름과 직접 적은 내용은 함께 두지 않는다 — 하나를 고르면 다른 쪽은 잠긴다
  const picked = quick.includes(one) ? one : null;
  const typed = !picked && asText(value) !== "";
  const setRow = (i, v) => onChange(rows.map((r, j) => (j === i ? v : r)));
  const want = useRef(false);   // 줄을 더한 뒤 새 줄에 커서를 둔다 — 그려진 뒤에 옮겨야 입력이 앞 줄로 새지 않는다
  const addRow = () => { want.current = true; onChange([...rows, ""]); };
  const dropRow = (i) => onChange(rows.length > 1 ? rows.filter((_, j) => j !== i) : [""]);
  const box = useRef(null);
  useEffect(() => {
    if (!want.current) return;
    want.current = false;
    [...(box.current?.querySelectorAll("input") || [])].at(-1)?.focus();
  }, [rows.length]);
  const pickedText = picked === UNKNOWN ? "모름 — AI 가 리포에서 찾아 채웁니다" : picked;
  const id = `f-${f.k}`;
  const quickButtons = quick.length > 0 && <>
    {quick.map((q) => (
      <button key={q} type="button" className={`btn small${picked === q ? " on" : ""}`} aria-pressed={picked === q}
        disabled={typed} title={typed ? "적은 내용을 지우면 고를 수 있습니다" : undefined}
        onClick={() => onChange(picked === q ? (f.list ? [""] : "") : f.list ? [q] : q)}>{q === NONE ? "None" : "Don't know"}</button>
    ))}
    <HelpTip text={[
      f.none && "None: 해당하는 것이 없을 때 누릅니다.",
      quick.includes(UNKNOWN) && "Don't know: AI 가 리포에서 찾아 채우고, 찾지 못하면 TBD 로 남깁니다.",
    ].filter(Boolean).join(" ")} />
  </>;
  return (
    <div className={error ? "field step-field bad" : "field step-field"}>
      <div className="field-head">
        <label htmlFor={id} className="step-label">{f.label}{f.advanced && <span className="badge">고급 · 선택</span>}</label>
      </div>
      {f.why && <p className="step-why">{f.why}</p>}
      {f.list
        ? <div className="step-rows" ref={box}>
            {picked
              ? <div className="step-row"><input id={id} value="" placeholder={pickedText} disabled aria-label={f.label} /></div>
              : rows.map((r, i) => {
              // 심각도를 고르는 항목은 줄을 "점검 — 심각도" 로 저장한다
              const [, text, sev] = f.severity ? r.match(new RegExp(`^(.*?)(?: — (${f.severity.join("|")}))?$`, "s")) : [, r];
              const joined = (t, s) => (f.severity && t ? `${t} — ${s || f.severity[1]}` : t);
              return (
                <div className="step-row" key={i}>
                  <input id={i === 0 ? id : undefined} value={text} placeholder={i === 0 ? f.hint : ""} aria-label={`${f.label} ${i + 1}`}
                    onChange={(e) => setRow(i, joined(e.target.value, sev))}
                    onKeyDown={(e) => { if (e.key === "Enter" && !e.nativeEvent.isComposing) { e.preventDefault(); if (r.trim()) addRow(); } }} />
                  {f.severity && (
                    <select value={sev || f.severity[1]} aria-label={`${i + 1}번째 점검의 심각도`} disabled={!text}
                      onChange={(e) => setRow(i, joined(text, e.target.value))}>
                      {f.severity.map((x) => <option key={x}>{x}</option>)}
                    </select>
                  )}
                  <button type="button" className="btn icon" aria-label={`${i + 1}번째 줄 지우기`} onClick={() => dropRow(i)}>×</button>
                </div>
              );
            })}
            <div className="row quick">
              <button type="button" className="btn ghost small" disabled={!!picked}
                title={picked ? "None·Don't know 를 풀면 줄을 더할 수 있습니다" : undefined} onClick={addRow}>+ Add row</button>
              {quickButtons}
            </div>
          </div>
        : <>
            <textarea id={id} className="step-input short" value={picked ? "" : one} placeholder={picked ? pickedText : f.hint} disabled={!!picked}
              onChange={(e) => onChange(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey) && onNext) { e.preventDefault(); onNext(); } }} />
            {/[*_`#\[\]-]/.test(one) && !picked && <div className="step-preview"><Markdown>{one}</Markdown></div>}
            {quickButtons && <div className="row quick">{quickButtons}</div>}
          </>}
      {error && <p className="error" role="alert">{CODES[error]}</p>}
    </div>
  );
}
