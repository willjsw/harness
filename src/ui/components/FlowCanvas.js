"use client";
import { useCallback, useEffect, useMemo, useRef, useState, useTransition } from "react";
import {
  ReactFlow, ReactFlowProvider, Background, Controls, MiniMap, Handle, Position,
  MarkerType, useNodesState, useReactFlow,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { checkSteps, saveSteps, checkMarkdown, saveWorkflowNotes, renameWorkflow, deleteWorkflow } from "@/lib/actions";
import Markdown from "@/components/Markdown";
import ModeToggle from "@/components/ModeToggle";
import CheckReport from "@/components/CheckReport";
import Select from "@/components/Select";
import HelpTip from "@/components/HelpTip";
import { HELP } from "@/lib/help";
import Link from "next/link";
import { LuBrainCircuit } from "react-icons/lu";
import { RoleChip, RunnerTag, OrchestratorTag, DeveloperTag } from "@/components/Agent";

const KINDS = {
  agent: { label: "Call Agent" },
  script: { label: "Run Script" },
  prompt: { label: "Run Prompt" },
  gate: { label: "Human Gate" },
};

// 16px 선 아이콘. 종류마다 하나.
const ICON = {
  script: <><rect x="2" y="3" width="12" height="10" rx="2" /><path d="M5 7l2 1.5L5 10M8.5 10.5H11" /></>,
  prompt: <path d="M3 4.5A1.5 1.5 0 0 1 4.5 3h7A1.5 1.5 0 0 1 13 4.5v5A1.5 1.5 0 0 1 11.5 11H7l-3 2.5V11h.5A1.5 1.5 0 0 1 3 9.5z" />,
  gate: <><path d="M8 2.5l5 2v3.8c0 2.8-2.1 4.7-5 5.7-2.9-1-5-2.9-5-5.7V4.5z" /><path d="M6 8l1.5 1.5L10.5 6.5" /></>,
};
// 에이전트는 Lucide 의 brain-circuit(react-icons) 을 쓰고, 나머지는 직접 그린 선 아이콘이다
const Icon = ({ kind }) => kind === "agent" ? <LuBrainCircuit className="ico k-agent" size={16} aria-hidden="true" /> : (
  <svg className={`ico k-${kind}`} viewBox="0 0 16 16" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{ICON[kind]}</svg>
);

const NEW_WF = "\u0000new";   // 드롭다운의 "새 절차" 항목 — 절차 이름이 될 수 없는 값
const W = 260, GAP = 56;   // ponytail: 가로 한 줄 고정 배치. 분기가 설정에 생기면 dagre 로
// 맞춤 배율의 하한. 단계가 많으면 양 끝이 화면 밖으로 나가고, 전체 모습은 미니맵이 보인다.
const FIT = { padding: 0.15, minZoom: 0.7, maxZoom: 1 };
const SIDE_MIN = 340;      // 오른쪽 패널: 이 너비부터 화면 절반까지
const clampSide = (w) => Math.round(Math.max(SIDE_MIN, Math.min(window.innerWidth / 2, w)));
const MAX_W = 420;         // 긴 명령이 있는 스크립트 블럭도 이 폭을 넘으면 줄을 내린다
const cells = (t) => [...t].reduce((n, c) => n + (c.charCodeAt(0) > 0x2e80 ? 2 : 1), 0);
// ponytail: 명령 글자 수로 폭을 어림한다(고정폭 11.5px ≈ 7px/칸, 한글 2칸). 어긋나면 React Flow 가 잰 폭으로
const nodeW = (s) => (s.type === "script" && s.run ? Math.min(MAX_W, Math.max(W, 42 + cells(s.run) * 7)) : W);
const layoutXs = (steps) => steps.reduce((xs, s, i) => [...xs, i ? xs[i - 1] + nodeW(steps[i - 1]) + GAP : 0], []);

// 블럭 한 줄 요약 — 설정에 실제로 있는 값만 보인다.
// 스크립트 단계가 부르는 역할. 등록부의 script_roles 가 스크립트 → 역할을 정한다(리뷰 스크립트 → code-reviewer).
const scriptRole = (s, schema) =>
  s.type === "script" ? Object.keys(schema.script_roles).find((r) => (s.run || "").startsWith(schema.script_roles[r])) : undefined;
// 단계를 실제로 누가 돌리는가 — 에이전트 단계의 역할이거나, 스크립트가 띄우는 역할
const stepRole = (s, schema) => (s.type === "agent" ? s.role : scriptRole(s, schema));

// 블럭에 보이는 실행 정보 — 누가 돌리는지(에이전트·오케스트레이터·사람), 스크립트면 무엇을 부르는지.
function Detail({ s, schema }) {
  const sr = scriptRole(s, schema);
  if (sr) return <><div className="mono-line">{s.run}</div><div className="who"><RoleChip name={sr} /><RunnerTag role={sr} schema={schema} /></div></>;
  if (s.type === "agent") return <div className="who">{s.role ? <RoleChip name={s.role} /> : <span className="muted small">No role</span>}<RunnerTag role={s.role} schema={schema} /></div>;
  if (s.type === "script") return <div className="mono-line">{s.run || "No command"}</div>;
  // 오케스트레이터가 직접 하는 단계. 사람 게이트는 사람도 함께 참여한다
  if (s.type === "prompt") return <div className="who"><OrchestratorTag schema={schema} /></div>;
  if (s.type === "gate") return <div className="who"><OrchestratorTag schema={schema} /><DeveloperTag /></div>;
  return null;
}

function StepNode({ data }) {
  const { step: s, n, schema, error } = data;
  return (
    <div className={`fnode${error ? " has-err" : ""}`}>
      <Handle type="target" position={Position.Left} style={{ top: 20 }} />
      <div className="fnode-head">
        <Icon kind={s.type} />
        <span className="fnode-n">{n}</span>
        <span className="fnode-title">{s.title || "Untitled"}</span>
        {error && <span className="fnode-err" title={error}>!</span>}
      </div>
      <div className="fnode-body">
        <Detail s={s} schema={schema} />
        {s.text && <div className="clip">{s.text}</div>}
        <div className="fnode-tags">
          <span className="tag">{KINDS[s.type]?.label}</span>
          {s.builtin && <span className="badge">Default</span>}
        </div>
      </div>
      <Handle type="source" position={Position.Right} style={{ top: 20 }} />
    </div>
  );
}
const nodeTypes = { step: StepNode };

// CLI 오류는 `workflows.<절차>.steps[i]` 로 위치를 준다. 없으면 절차 전체의 오류다.
function locate(out) {
  const m = out.match(/steps\[(\d+)\]/);
  return m ? Number(m[1]) : null;
}

// 기본 본문의 `{{step:<id>}}` 를 지금 순서의 번호로 푼다. 없는 단계는 검사가 따로 잡는다.
const resolve = (body, steps) => body.replace(/\{\{step:([a-z0-9-]+)\}\}/g, (m, id) => {
  const i = steps.findIndex((s) => s.id === id);
  return i < 0 ? "?" : String(i + 1);
});

function Canvas({ project, workflows, schema, docs, notes }) {
  const roles = schema.roles;
  const [names, setNames] = useState(Object.keys(workflows));
  const [wf, setWf] = useState(names[0]);
  // 새 절차의 초안 { 이름: 제목 }. 저장을 누르기 전에는 설정에 아무것도 쓰지 않는다
  const [drafts, setDrafts] = useState({});
  const [creating, setCreating] = useState(null);      // 새 절차 이름·제목을 받는 중
  const [manage, setManage] = useState(null);          // { kind: "rename" | "delete", name } — 절차 이름 변경·삭제 모달
  const [view, setView] = useState("canvas");        // canvas | procedure
  const [base, setBase] = useState(workflows);        // 마지막으로 저장된 상태
  const [edits, setEdits] = useState(workflows);       // 편집 중인 상태, 절차별
  const [sel, setSel] = useState(null);                // 선택한 단계 id
  const [adding, setAdding] = useState(null);          // 추가 중인 단계 — 필수값을 채워야 끼운다
  const [check, setCheck] = useState({ ok: true, out: "" });
  const [msg, setMsg] = useState(null);
  const [pending, start] = useTransition();
  const [edit, setEdit] = useState(false);          // 노드 패널은 읽기가 기본
  const [report, setReport] = useState(null);       // 저장 전 마크다운 검사
  const { fitView } = useReactFlow();
  const [checking, setChecking] = useState(false);   // 저장 전 검사가 도는 중
  const [sideW, setSideW] = useState(SIDE_MIN);        // 오른쪽 패널 너비 — 왼쪽 가장자리를 끌어 늘린다
  const [sideAnim, setSideAnim] = useState(false);    // 원래 너비로 돌아갈 때만 움직인다 — 끄는 동안은 손을 바로 따라간다
  // 경계나 패널의 빈 곳을 두 번 누르면 원래 너비로
  const resetSide = () => { setSideAnim(true); setSideW(SIDE_MIN); setTimeout(() => setSideAnim(false), 260); };
  const dragSide = (e) => {
    e.preventDefault();
    const move = (ev) => setSideW(clampSide(window.innerWidth - ev.clientX));
    const up = () => { removeEventListener("pointermove", move); removeEventListener("pointerup", up); document.body.classList.remove("resizing"); };
    addEventListener("pointermove", move); addEventListener("pointerup", up); document.body.classList.add("resizing");
  };
  const steps = edits[wf];
  const dirty = (w) => w in drafts || JSON.stringify(edits[w]) !== JSON.stringify(base[w]);
  const setSteps = (next) => setEdits((e) => ({ ...e, [wf]: typeof next === "function" ? next(e[wf]) : next }));
  const errAt = check.ok ? null : locate(check.out);
  // 에이전트 단계가 부를 수 있는 역할 — 전용 스크립트로 도는 역할(리뷰)은 스크립트 단계로 부른다.
  // 러너가 CLI 인 역할도 된다: 절차 문서가 서브에이전트 위임 대신 공용 실행기(script/run-agent.py)를 부른다
  const stepRoles = Object.keys(roles).filter((r) => !(r in schema.script_roles));

  // 편집이 멈추면 저장하지 않고 검사만 돌린다. 늦게 도착한 옛 결과는 버린다.
  const seq = useRef(0);
  useEffect(() => {
    if (!dirty(wf) || (wf in drafts && !steps.length)) { setCheck({ ok: true, out: "" }); setChecking(false); return; }
    const my = ++seq.current;
    setChecking(true);
    const t = setTimeout(async () => {
      const r = await checkSteps(project, wf, steps, drafts[wf]);
      if (my === seq.current) { setCheck(r); setChecking(false); }
    }, 400);
    return () => clearTimeout(t);
  }, [steps, wf]); // eslint-disable-line react-hooks/exhaustive-deps

  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  useEffect(() => {
    const xs = layoutXs(steps);
    setNodes(steps.map((s, i) => ({
      id: s.id, type: "step", position: { x: xs[i], y: 0 }, style: { width: nodeW(s) }, selected: s.id === sel,
      data: { step: s, n: i + 1, schema, error: errAt === i ? check.out.split("\n")[0] : null },
    })));
  }, [steps, sel, check]); // eslint-disable-line react-hooks/exhaustive-deps
  const edges = useMemo(() => steps.slice(1).map((s, i) => ({
    id: `${steps[i].id}->${s.id}`, source: steps[i].id, target: s.id, type: "straight",
    markerEnd: { type: MarkerType.ArrowClosed, width: 16, height: 16 },
  })), [steps]);

  // 절차를 바꾸거나 단계 수가 바뀌면 가운데로 맞춘다.
  useEffect(() => { if (view === "canvas") requestAnimationFrame(() => fitView({ ...FIT, duration: 200 })); }, [wf, steps.length, view, fitView]);

  // 끌어 놓은 x 위치 = 새 순서. 그 앞에 중심이 놓인 블럭 수가 들어갈 자리다.
  const slotAt = (x, skip) => { const xs = layoutXs(steps); return steps.filter((s, i) => s.id !== skip && xs[i] + nodeW(s) / 2 < x).length; };
  const onNodeDragStop = useCallback((_, node) => {
    const rest = steps.filter((s) => s.id !== node.id);
    const moved = steps.find((s) => s.id === node.id);
    const at = slotAt(node.position.x + nodeW(moved) / 2, node.id);
    rest.splice(at, 0, moved);
    setSteps(rest);
    setNodes((ns) => ns.map((n) => ({ ...n })));   // 순서가 같아도 제자리로 돌려 놓는다
  }, [steps]); // eslint-disable-line react-hooks/exhaustive-deps

  // 추가: 종류를 고르면 필수값 폼이 열리고, 채워야 끼운다. 빈 단계를 먼저 넣으면 검사가 곧바로 막는다.
  const startAdd = (type) => setAdding({ type, title: KINDS[type].label, role: stepRoles[0] ?? "", run: "", text: "", at: selIdx + 1 });
  const missing = adding && (
    !adding.title.trim() ? "Title" :
    adding.type === "agent" && !adding.role ? "Role" :
    adding.type === "script" && !adding.run.trim() ? "Command" :
    adding.type === "prompt" && !adding.text.trim() ? "Instructions" : null);
  const commitAdd = () => {
    let n = 1;
    while (steps.some((s) => s.id === `step-${n}`)) n++;
    const { type, title, role, run, text, at } = adding;
    const s = { id: `step-${n}`, type, title: title.trim(),
      ...(type === "agent" ? { role } : {}), ...(type === "script" ? { run: run.trim() } : {}), ...(text.trim() ? { text: text.trim() } : {}) };
    setSteps((cur) => [...cur.slice(0, at), s, ...cur.slice(at)]);
    setAdding(null); setSel(s.id); setEdit(false);
  };

  const taken = new Set([...names, ...Object.keys(roles), "work", "prework", "retro"]);
  const nameProblem = (n) => !/^[a-z][a-z0-9-]{1,30}$/.test(n) ? "영문 소문자·숫자·- 로 2–31자" : taken.has(n) ? "이미 있는 절차·커맨드·역할 이름이다" : null;
  const openDraft = () => {
    const { name, title } = creating;
    setNames((ns) => [...ns, name]); setDrafts((d) => ({ ...d, [name]: title.trim() || undefined }));
    setEdits((e) => ({ ...e, [name]: [] })); setBase((b) => ({ ...b, [name]: [] }));
    setWf(name); setView("canvas"); setSel(null); setCreating(null); setMsg(null);
  };
  const discard = () => {   // 저장하지 않은 새 절차는 되돌리면 통째로 사라진다
    const rest = names.filter((n) => n !== wf);
    setDrafts(({ [wf]: _, ...d }) => d); setNames(rest); setWf(rest[0]); setSel(null); setMsg(null); setReport(null);
  };
  const title = (w) => drafts[w] ?? schema.workflows?.[w]?.title ?? "";
  // 이름 변경·삭제는 이 프로젝트가 만든, 저장된 절차만 — 기본 절차는 하네스 것이고, 초안은 "Discard Draft" 로 없앤다
  const ownWf = !(wf in drafts) && !!schema.workflows?.[wf]?.custom;
  const doManage = () => start(async () => {
    const { kind, name } = manage;
    const res = kind === "rename" ? await renameWorkflow(project, wf, name) : await deleteWorkflow(project, wf);
    setMsg(res); setManage(null);
    if (!res.ok) return;
    const move = (o) => { const { [wf]: v, ...rest } = o; return kind === "rename" ? { ...rest, [name]: v } : rest; };
    setEdits(move); setBase(move);
    const next = kind === "rename" ? names.map((n) => (n === wf ? name : n)) : names.filter((n) => n !== wf);
    setNames(next); setWf(kind === "rename" ? name : next[0]); setSel(null);
  });

  const put = (id, patch) => setSteps((cur) => cur.map((s) => (s.id === id ? { ...s, ...patch } : s)));
  const move = (i, d) => setSteps((cur) => { const n = [...cur]; [n[i], n[i + d]] = [n[i + d], n[i]]; return n; });
  const remove = (id) => { setSteps((cur) => cur.filter((s) => s.id !== id)); setSel(null); };

  const write = () => start(async () => {
    const r = await saveSteps(project, wf, steps, drafts[wf]);
    setMsg(r); setReport(null);
    if (r.ok) { setBase((b) => ({ ...b, [wf]: steps })); setDrafts(({ [wf]: _, ...rest }) => rest); }
  });
  // 바뀐 지시(text)만 모아 한 번에 검사한다. 줄 번호는 어느 단계의 몇 행인지로 되돌려 보인다.
  const save = () => start(async () => {
    const was = Object.fromEntries(base[wf].map((s) => [s.id, s.text || ""]));
    const owner = [];
    const parts = [];
    steps.forEach((s, i) => {
      const t = s.text || "";
      if (!t.trim() || t === was[s.id]) return;
      t.split("\n").forEach((_, k) => owner.push(`${i + 1}. ${s.title} · ${k + 1}행`));
      parts.push(t);
      owner.push(null);   // 단계 사이의 빈 줄
    });
    if (!parts.length) return write();
    const r = await checkMarkdown(project, parts.join("\n\n").replace(/\n\n$/, ""));
    if (!r.issues.length && !r.failed) return write();
    setReport({ ...r, where: (line) => owner[line - 1] || `${line}행` });
  });

  const selIdx = steps.findIndex((s) => s.id === sel);
  const cur = steps[selIdx];
  const who = cur && stepRole(cur, schema);

  return (
    <div className="flow-page">
      <div className="flow-bar">
        <div className="wf-pick">
          {/* 항목은 명령어만 보인다. 맨 아래 "+ New Workflow" 는 목록이 스크롤돼도 바닥에 붙어 있다 */}
          <Select id="wf-select" value={wf} pinned={NEW_WF}
            options={[...names.map((w) => [w, <span key={w} className="wf-opt">/{w}{dirty(w) && <i className="dirty" aria-label="저장하지 않은 변경" />}</span>]),
              [NEW_WF, <span key={NEW_WF} className="wf-opt new">+ New Workflow</span>]]}
            onChange={(w) => {
              if (w === NEW_WF) { setCreating({ name: "", title: "" }); setView("canvas"); setSel(null); setAdding(null); return; }
              setWf(w); setSel(null); setAdding(null); setCreating(null); setMsg(null); setReport(null);
            }} />
        </div>
        <div className="seg" role="tablist" aria-label="보기">
          {[["canvas", "Canvas"], ["procedure", "Procedure"]].map(([v, label]) => (
            <button key={v} role="tab" aria-selected={view === v} className={view === v ? "on" : ""} onClick={() => setView(v)}>{label}</button>
          ))}
        </div>
        {/* 단계는 고른 노드 뒤에 끼운다. 고른 노드가 없으면 끼울 자리가 없으므로 메뉴도 없다 */}
        {view === "canvas" && cur && !adding && (
          <div className="add-step">
            <Select id="add-step" value="" placeholder={`+ Add Step after ${selIdx + 1}`}
              options={Object.entries(KINDS).map(([k, { label }]) => [k, <span key={k} className="opt-ico"><Icon kind={k} />{label}</span>])}
              onChange={startAdd} />
          </div>
        )}
        {view === "canvas" && (
          <div className="row push">
            <span className={`status ${checking ? "checking" : check.ok ? "ok" : "err"}`} title={check.out} aria-live="polite">
              {checking ? "Checking…" : check.ok ? (dirty(wf) ? "Valid" : "Saved") : "1 error"}
            </span>
            <button className="btn" disabled={!dirty(wf) || pending} onClick={() => wf in drafts ? discard() : (setSteps(base[wf]), setSel(null), setMsg(null), setReport(null))}>{wf in drafts ? "Discard Draft" : "Revert"}</button>
            <button className="btn primary" aria-busy={pending} disabled={!dirty(wf) || !steps.length || !check.ok || checking || pending || !!report} onClick={save}>{pending ? "Checking & Saving…" : "Check & Save"}</button>
          </div>
        )}
      </div>

      {view === "procedure" && wf in drafts ? (
        <div className="empty"><h1>아직 저장하지 않은 절차다</h1><p className="muted">단계를 더하고 저장하면 절차 문서가 만들어진다.</p></div>
      ) : view === "procedure" ? (
        <Procedure key={wf} project={project} wf={wf} doc={docs[wf]} notes={notes[wf] ?? ""} path={schema.workflow_notes?.[wf]} />
      ) : (
      <div className={`flow-main${sideAnim ? " side-anim" : ""}`} style={{ "--side-w": `${sideW}px` }}>
        <div className="flow-canvas">
          {!steps.length && !adding && (
            <div className="canvas-empty">
              <p><b>/{wf}</b> 에 단계가 없다. 첫 단계를 더한다.</p>
              <Select id="add-first" value="" placeholder="+ Add First Step"
                options={Object.entries(KINDS).map(([k, { label }]) => [k, <span key={k} className="opt-ico"><Icon kind={k} />{label}</span>])}
                onChange={startAdd} />
            </div>
          )}
          <ReactFlow
            nodes={nodes} edges={edges} nodeTypes={nodeTypes}
            onNodesChange={onNodesChange} onNodeDragStop={onNodeDragStop}
            onNodeClick={(_, n) => { setSel(n.id); setEdit(false); setAdding(null); }} onPaneClick={() => { setSel(null); setAdding(null); }}
            onNodesDelete={(ns) => { const gone = new Set(ns.map((n) => n.id)); setSteps((c) => c.filter((s) => !gone.has(s.id))); setSel(null); }}
            deleteKeyCode={["Backspace", "Delete"]} nodesConnectable={false} edgesFocusable={false}
            fitView fitViewOptions={FIT} minZoom={0.2} maxZoom={1.5}
          >
            <Background gap={16} size={1} />
            <Controls showInteractive={false} position="bottom-left" />
            <MiniMap pannable zoomable position="bottom-right" nodeBorderRadius={6} style={{ width: 220, height: 90 }} ariaLabel="전체 절차 미니맵"
              nodeColor={(n) => (n.data?.error ? "var(--err)" : n.selected ? "var(--accent-hi)" : "var(--minimap-node)")} />
          </ReactFlow>
        </div>

        <aside className="flow-side" onDoubleClick={(e) => e.target.closest(".side-grip, .side-body, .side-foot") === e.target && resetSide()}>
          <div className="side-grip" role="separator" aria-orientation="vertical" aria-label="패널 너비" tabIndex={0}
            aria-valuemin={SIDE_MIN} aria-valuenow={sideW} onPointerDown={dragSide}
            onKeyDown={(e) => { const d = { ArrowLeft: 24, ArrowRight: -24 }[e.key]; if (d) { e.preventDefault(); setSideW((w) => clampSide(w + d)); } }} />
          <div className="side-body">
          {report && <CheckReport result={report} pending={pending} onSave={write} onCancel={() => { setReport(null); setEdit(true); }} />}
          {adding ? (
            <>
              <div className="side-head">
                <Icon kind={adding.type} />
                <b className="grow">New {KINDS[adding.type].label}</b>
                <span className="muted small">after {adding.at}</span>
              </div>
              <label className="lbl">Title<input value={adding.title} autoFocus onChange={(e) => setAdding({ ...adding, title: e.target.value })} /></label>
              {adding.type === "agent" && (
                <div className="lbl">Role
                  <Select id="add-role" value={adding.role} options={stepRoles.map((r) => [r, r])} onChange={(r) => setAdding({ ...adding, role: r })} />
                </div>
              )}
              {adding.type === "script" && (
                <label className="lbl">Command<input className="mono" value={adding.run} placeholder="script/<이름>.sh <인자>" onChange={(e) => setAdding({ ...adding, run: e.target.value })} /></label>
              )}
              <label className="lbl">{adding.type === "prompt" ? "Instructions" : "Extra Instructions"}
                <textarea className="md-edit" rows={6} value={adding.text} placeholder={"Markdown — # heading, - list, **bold**, `code`"} onChange={(e) => setAdding({ ...adding, text: e.target.value })} />
              </label>
            </>
          ) : cur ? (
            <>
              <div className="side-head">
                <Icon kind={cur.type} />
                <span className="fnode-n">{selIdx + 1}</span>
                <b className="grow">{cur.title || "Untitled"}</b>
                <ModeToggle edit={edit} onChange={setEdit} />
                <button className="icon" aria-label="닫기" onClick={() => setSel(null)}>✕</button>
              </div>
              {errAt === selIdx && <pre className="result err">{check.out}</pre>}
              <div className="step-meta">
                <span className="tag">{KINDS[cur.type].label}</span>
                <Detail s={cur} schema={schema} />
              </div>
              {!edit ? (
                <>
                  {cur.builtin
                    ? <Markdown>{resolve(cur.body || "", steps)}</Markdown>
                    : !cur.text && <p className="muted small">No default body.</p>}
                  {cur.text && <div className="side-sec"><div className="side-title">{cur.builtin ? "Extra Instructions" : "Instructions"}</div><Markdown>{cur.text}</Markdown></div>}
                </>
              ) : (<>
              {/* 기본 단계는 하네스의 것이다 — 이 프로젝트가 고치는 것은 덧붙일 지시뿐이다 */}
              {!cur.builtin && <label className="lbl">Title<input value={cur.title} onChange={(e) => put(cur.id, { title: e.target.value })} /></label>}
              {!cur.builtin && cur.type === "agent" && (
                <div className="lbl">Role
                  <Select id="step-role" value={cur.role || ""} options={stepRoles.map((r) => [r, r])} onChange={(r) => put(cur.id, { role: r })} />
                </div>
              )}
              {!cur.builtin && cur.type === "script" && (
                <label className="lbl">Command<input className="mono" value={cur.run || ""} placeholder="script/<이름>.sh <인자>" onChange={(e) => put(cur.id, { run: e.target.value })} /></label>
              )}
              <label className="lbl">{cur.builtin ? "Extra Instructions" : "Instructions"}
                <textarea className="md-edit" rows={8} value={cur.text || ""} placeholder={"Markdown — # heading, - list, **bold**, `code`"} onChange={(e) => { put(cur.id, { text: e.target.value }); setReport(null); }} />
              </label>
              </>)}
            </>
          ) : (
            <>
              <div className="side-title">Steps <span className="muted small">/{wf} · {steps.length}</span></div>
              {!check.ok && errAt === null && <pre className="result err">{check.out}</pre>}
              <ol className="side-list">
                {steps.map((s, i) => (
                  <li key={s.id}>
                    <button className={errAt === i ? "has-err" : ""} onClick={() => { setSel(s.id); setEdit(false); fitView({ nodes: [{ id: s.id }], padding: 1.2, duration: 250, maxZoom: 1 }); }}>
                      <Icon kind={s.type} /><span className="fnode-n">{i + 1}</span><span className="grow">{s.title}</span>
                    </button>
                  </li>
                ))}
              </ol>
            </>
          )}
          {msg && <pre className={msg.ok ? "result ok" : "result err"}>{msg.out}</pre>}
          </div>
          {/* 조작 버튼은 문서 길이와 무관하게 늘 패널 바닥에 있다 */}
          {adding ? (
            <div className="side-foot">
              <div className="row end">
                <button className="btn" onClick={() => setAdding(null)}>Cancel</button>
                <button className="btn primary" disabled={!!missing} title={missing ? `${missing} 를 채운다` : undefined} onClick={commitAdd}>Add</button>
              </div>
            </div>
          ) : !cur ? (ownWf && (
            <div className="side-foot">
              <div className="row between">
                <button className="btn" onClick={() => setManage({ kind: "rename", name: wf })}>Rename</button>
                <button className="btn danger" onClick={() => setManage({ kind: "delete", name: wf })}>Delete Workflow</button>
              </div>
            </div>
          )) : (
            <div className="side-foot">
              {who && <Link className="btn wide primary" href={`/${encodeURIComponent(project)}/agents`} title={`${who} — Agents 탭`}>Agent Setting</Link>}
              <div className="row between">
                <div className="row">
                  <button className="btn" disabled={selIdx === 0} onClick={() => move(selIdx, -1)}>← Earlier</button>
                  <button className="btn" disabled={selIdx === steps.length - 1} onClick={() => move(selIdx, 1)}>Later →</button>
                </div>
                <button className="btn danger" onClick={() => remove(cur.id)}>Delete</button>
              </div>
            </div>
          )}
        </aside>
      </div>
      )}
      {manage && (
        <Modal title={manage.kind === "rename" ? "Rename Workflow" : "Delete Workflow"} onCancel={() => setManage(null)}
          ready={manage.kind === "delete" || (manage.name !== wf && !nameProblem(manage.name))} busy={pending}
          submit={manage.kind === "rename" ? "Rename" : "Delete"} danger={manage.kind === "delete"} onSubmit={doManage}>
          {manage.kind === "rename" ? (<>
            <label className="lbl">Name<input className="mono" value={manage.name} autoFocus
              onChange={(e) => setManage({ ...manage, name: e.target.value.trim().toLowerCase() })} /></label>
            {manage.name !== wf && nameProblem(manage.name) && <p className="error">{nameProblem(manage.name)}</p>}
            <p className="hint">커맨드와 절차 문서, 이 절차에 더한 지시 파일이 새 이름을 따라간다.</p>
          </>) : (
            <p><code>/{wf}</code> 절차와 그 커맨드를 지운다. 이 절차에 더한 지시 파일(<code>.ai/project/workflows/{wf}.md</code>)은 남긴다.</p>
          )}
        </Modal>
      )}
      {creating && (
        <NewWorkflowDialog value={creating} onChange={setCreating} problem={nameProblem(creating.name)}
          onCancel={() => setCreating(null)} onCreate={openDraft} />
      )}
    </div>
  );
}

// 모달 — 브라우저의 <dialog> 가 포커스 가두기·Esc 닫기·배경 차단을 맡는다. 닫을 때도 사라지는 모션을 거친다.
function Modal({ title, children, ready, busy, submit, danger, onCancel, onSubmit }) {
  const ref = useRef(null);
  const [closing, setClosing] = useState(false);
  useEffect(() => { const d = ref.current; if (d && !d.open) d.showModal(); }, []);
  const leave = (then) => {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return then();
    setClosing(true); setTimeout(then, 160);
  };
  return (
    <dialog ref={ref} className={`modal${closing ? " closing" : ""}`} aria-label={title}
      onCancel={(e) => { e.preventDefault(); leave(onCancel); }}
      onClick={(e) => e.target === ref.current && leave(onCancel)}>
      <form method="dialog" className="modal-body" onSubmit={(e) => { e.preventDefault(); if (ready && !busy) (danger ? onSubmit() : leave(onSubmit)); }}>
        <h2>{title}</h2>
        {children}
        <div className="row end">
          <button type="button" className="btn" onClick={() => leave(onCancel)}>Cancel</button>
          <button type="submit" className={`btn ${danger ? "danger solid" : "primary"}`} aria-busy={busy} disabled={!ready || busy}>{submit}</button>
        </div>
      </form>
    </dialog>
  );
}

// 새 절차의 이름을 받는 모달. 제목은 받지 않는다 — 절차 문서·커맨드 설명에만 쓰이고, 비우면 이름을 쓴다.
function NewWorkflowDialog({ value, onChange, problem, onCancel, onCreate }) {
  return (
    <Modal title="New Workflow" ready={!problem && value.name} submit="Create" onCancel={onCancel} onSubmit={onCreate}>
      <label className="lbl">Name<input className="mono" value={value.name} autoFocus placeholder="hotfix"
        onChange={(e) => onChange({ ...value, name: e.target.value.trim().toLowerCase() })} /></label>
      {value.name && problem && <p className="error">{problem}</p>}
      <p className="hint">커맨드 <code>/{value.name || "이름"}</code> 이 함께 만들어진다. 단계를 더하고 저장해야 설정에 들어간다.</p>
    </Modal>
  );
}

// 생성된 절차를 읽고, 이 프로젝트가 절차 끝에 더하는 지시를 고친다. 생성된 부분은 설정과 단계가 정하므로 여기서 고치지 않는다.
function Procedure({ project, wf, doc, notes, path }) {
  const [text, setText] = useState(notes);
  const [edit, setEdit] = useState(false);
  const [report, setReport] = useState(null);
  const [msg, setMsg] = useState(null);
  const [busy, setBusy] = useState(null);
  const [, start] = useTransition();
  const act = (k, fn) => { setBusy(k); start(async () => { try { await fn(); } finally { setBusy(null); } }); };
  const write = () => act("save", async () => { setReport(null); setMsg(await saveWorkflowNotes(project, wf, text)); });
  const save = () => act("check", async () => {
    const r = await checkMarkdown(project, text);
    if (!r.issues.length && !r.failed) { setMsg(await saveWorkflowNotes(project, wf, text)); return; }
    setReport(r);
  });
  return (
    <div className="proc">
      <section className="card">
        <div className="card-head">
          <h2>Generated Procedure <code className="key fname">.ai/workflows/{wf}.md</code></h2>
          <ModeToggle edit={edit} onChange={setEdit} />
        </div>
        <div className="md-view proc-doc"><Markdown>{doc || ""}</Markdown></div>
      </section>
      {edit && (
        <section className="card draft">
          <div className="card-head">
            <h2 className="label-help">Project Instructions<HelpTip text={HELP["procedure.notes"]} /></h2>
            <code className="key fname">{path}</code>
          </div>
          <textarea className="md-edit" value={text} spellCheck={false} aria-label="마크다운 편집"
            placeholder={"- 이 프로젝트에서 이 절차를 돌 때 지킬 것"} onChange={(e) => { setText(e.target.value); setReport(null); }} />
          {report && <CheckReport result={report} pending={busy === "save"} onSave={write} onCancel={() => setReport(null)} />}
          {msg && <pre className={msg.ok ? "result ok" : "result err"}>{msg.out}</pre>}
          <div className="row end">
            <button className="btn" disabled={!!busy || text === notes} onClick={() => { setText(notes); setReport(null); }}>Revert</button>
            <button className="btn primary" aria-busy={!!busy} disabled={!!busy || text === notes || !!report} onClick={save}>
              {busy === "check" ? "Checking…" : busy === "save" ? "Saving…" : "Check & Save"}
            </button>
          </div>
        </section>
      )}
    </div>
  );
}

export default function FlowCanvas(props) {
  return <ReactFlowProvider><Canvas {...props} /></ReactFlowProvider>;
}
