"use client";
import { useState } from "react";
import { LuPlay } from "react-icons/lu";
import { DOCS, fieldsOf } from "@/lib/fields";
import { runCommand, saveCommands, suggestCommands } from "@/lib/actions";
import HelpTip from "@/components/HelpTip";

// 명령 탭 — 문서가 아니라 harness.toml 의 [commands]·[verify] 를 고친다.
// 적고, ▷ 로 이 리포에서 실제로 돌려 보고, 저장한다. 저장하면 규칙 문서 3장과 검증 스크립트가 다시 생성된다.
export default function CommandsEditor({ project, initial, legacy }) {
  const fields = fieldsOf("commands");
  const [cmds, setCmds] = useState(initial.commands);
  const [checks, setChecks] = useState(initial.checks.length ? initial.checks : []);
  const [runs, setRuns] = useState({});          // 키 → { busy } | 결과
  const [msg, setMsg] = useState(null);
  const [busy, setBusy] = useState(null);
  const dirty = JSON.stringify(cmds) !== JSON.stringify(initial.commands) || JSON.stringify(checks) !== JSON.stringify(initial.checks);

  const run = async (key, cmd) => {
    setRuns((r) => ({ ...r, [key]: { busy: true } }));
    const res = await runCommand(project, cmd);
    setRuns((r) => ({ ...r, [key]: res }));
  };
  const suggest = async () => {
    setBusy("suggest"); setMsg(null);
    try {
      const r = await suggestCommands(project);
      if (!r.ok) { setMsg(r); return; }
      // 이미 적은 칸은 건드리지 않는다
      const filled = Object.entries(r.commands).filter(([k, v]) => k in cmds && v && !cmds[k].trim());
      setCmds({ ...cmds, ...Object.fromEntries(filled) });
      setMsg({ ok: true, out: filled.length ? `${filled.length}개 명령을 찾아 채웠습니다. ▷ 로 돌려 본 뒤 저장해 주세요.` : "새로 채울 명령을 찾지 못했습니다." });
    } finally { setBusy(null); }
  };
  const save = async () => {
    setBusy("save"); setMsg(null);
    try { setMsg(await saveCommands(project, cmds, checks, initial)); } finally { setBusy(null); }
  };
  const setCheck = (i, k, v) => setChecks(checks.map((c, j) => (j === i ? { ...c, [k]: v } : c)));

  return (
    <div className="cmds">
      <p className="doc-intro">{DOCS.commands.intro}</p>
      {legacy && (
        <p className="notice warn">
          손으로 쓴 <code>script/verify-project.sh</code> 가 있어 지금은 그 스크립트가 검증을 맡습니다.
          여기에 명령을 옮긴 뒤 그 파일을 지우면 이 설정으로 검증합니다.
        </p>
      )}
      <section className="card">
        <div className="card-head">
          <h2 className="panel-title">명령</h2>
          <span className="row">
            <button className="btn small" aria-busy={busy === "suggest"} disabled={!!busy} onClick={suggest}>
              {busy === "suggest" ? "Looking…" : "✦ Find in repo"}
            </button>
            <HelpTip text="AI 가 package.json·Makefile 같은 파일에서 실제로 있는 명령을 찾아 빈 칸만 채웁니다. 저장하지는 않습니다." />
          </span>
        </div>
        {fields.map((f) => (
          <div key={f.k} className="field cmd-field">
            <div className="field-head">
              <label htmlFor={`c-${f.k}`} className="step-label">
                {f.label}
                {f.verify && <span className="badge">커밋 뒤 · CI 에서 실행</span>}
                {f.advanced && <span className="badge">고급 · 선택</span>}
              </label>
            </div>
            <p className="step-why">{f.why}</p>
            <CommandRow id={`c-${f.k}`} value={cmds[f.k] ?? ""} placeholder={f.hint} onChange={(v) => setCmds({ ...cmds, [f.k]: v })}
              result={runs[f.k]} onRun={() => run(f.k, cmds[f.k])} runnable={!f.k.endsWith("_single") && !f.k.endsWith("_fix")} />
          </div>
        ))}
      </section>

      <section className="card">
        <div className="card-head">
          <h2 className="panel-title">추가 검증 <span className="badge">고급 · 선택</span></h2>
        </div>
        <p className="step-why">
          계층 의존 규칙처럼 명령 하나로 검사할 수 있는 규칙입니다. 코드 검사·테스트보다 먼저, 적은 순서대로 돕니다.
          여러 줄이 필요한 검사는 스크립트 파일로 만들어 그 경로를 적습니다.
        </p>
        {checks.map((c, i) => (
          <div key={i} className="check-row-edit">
            <input className="check-name" value={c.name} placeholder="예: domain 이 프레임워크를 import 하지 않는다" aria-label={`검사 ${i + 1} 이름`}
              onChange={(e) => setCheck(i, "name", e.target.value)} />
            <CommandRow value={c.run} placeholder="예: ! grep -rn 'import org.springframework' src/domain/" aria={`검사 ${i + 1} 명령`}
              onChange={(v) => setCheck(i, "run", v)} result={runs[`check-${i}`]} onRun={() => run(`check-${i}`, c.run)} runnable
              onRemove={() => setChecks(checks.filter((_, j) => j !== i))} />
          </div>
        ))}
        <button type="button" className="btn ghost small" onClick={() => setChecks([...checks, { name: "", run: "" }])}>+ Add check</button>
      </section>

      {msg && <pre className={msg.ok ? "result ok" : "result err"}>{msg.out}</pre>}
      <div className="row between cmds-foot">
        <span className="muted small">저장하면 코드 검사·테스트·추가 검증이 커밋 뒤와 CI 에서 실행됩니다.</span>
        <span className="row">
          <button className="btn" disabled={!!busy || !dirty} onClick={() => { setCmds(initial.commands); setChecks(initial.checks); setMsg(null); }}>Revert</button>
          <button className="btn primary" aria-busy={busy === "save"} disabled={!!busy || !dirty} onClick={save}>{busy === "save" ? "Saving…" : "Save"}</button>
        </span>
      </div>
    </div>
  );
}

// 명령 한 줄 + ▷. 돌린 결과는 통과·실패와 걸린 시간을 한 줄로, 출력은 접어 둔다.
function CommandRow({ id, value, placeholder, aria, onChange, result, onRun, runnable, onRemove }) {
  const sec = result?.ms != null ? ` · ${(result.ms / 1000).toFixed(1)}초` : "";
  return (
    <>
      <div className="cmd-edit">
        {runnable && (
          <button type="button" className="play" aria-label={`실행: ${value}`} title="이 리포에서 돌려 보기"
            aria-busy={!!result?.busy} disabled={!value.trim() || result?.busy} onClick={onRun}><LuPlay size={13} aria-hidden="true" /></button>
        )}
        <input id={id} className="mono" value={value} placeholder={placeholder} aria-label={aria} spellCheck={false}
          onChange={(e) => onChange(e.target.value)} />
        {onRemove && <button type="button" className="btn icon" aria-label="검사 지우기" onClick={onRemove}>×</button>}
      </div>
      {result?.busy && <p className="muted small pulse">돌리는 중…</p>}
      {result && !result.busy && (
        <details className={`cmd-result ${result.ok ? "ok" : "bad"}`}>
          <summary>{result.ok ? `통과${sec}` : `실패 — 종료 코드 ${result.code}${sec}`}</summary>
          <pre>{result.out || "(출력 없음)"}</pre>
        </details>
      )}
    </>
  );
}

// 옛 하네스 사본 — 명령을 설정으로 받지 않는다. 올리는 곳을 알린다.
export function CommandsUnsupported() {
  return (
    <p className="notice warn">
      이 프로젝트의 하네스 사본은 명령을 설정으로 받지 않는 옛 버전입니다. 아래 문서로 적을 수 있지만 검증에는 쓰이지 않습니다.
      프로젝트에서 <code>harness install</code> 로 사본을 새로 받으면 여기서 명령을 정하고 돌려 볼 수 있습니다.
    </p>
  );
}
