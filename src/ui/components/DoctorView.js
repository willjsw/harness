"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { LuPlay, LuRefreshCw } from "react-icons/lu";
import { doctorFix } from "@/lib/actions";
import { loadStatus } from "@/lib/status-cache";
import { SECTIONS, explain } from "@/lib/doctor";
import Reinstall from "@/components/Reinstall";

const LEVEL = { bad: "FAIL", warn: "WARN", ok: "OK" };
const newer = (a, b) => a && b && a.localeCompare(b, undefined, { numeric: true }) > 0;

// 프로젝트 하나의 doctor 결과. 절마다 묶고, 막힌 것부터 보인다. 바로 고칠 수 있는 것은 ▷ 로 실행한다.
// schema 는 그 프로젝트의 하네스가 낸 것이다. ▷ 조치의 보일 명령과, 사본이 fix 를 아는지(docs 키)를 여기서 본다.
export default function DoctorView({ project, global, schema }) {
  const base = `/${encodeURIComponent(project)}`;
  const [st, setSt] = useState(undefined);
  const [loading, setLoading] = useState(false);
  // 원격 점검을 한 번 돌린 뒤의 Run again 은 원격까지 다시 돈다. 화면을 새로 열면 원격 없이 시작한다
  const [remote, setRemote] = useState(false);
  const [remoteFailed, setRemoteFailed] = useState(false);
  // 처음에는 사이드바가 이미 돌린 결과를 쓰고, Run again·조치 뒤에는 새로 돌린다
  const load = async (fresh = true, withRemote = remote) => {
    setLoading(true);
    try {
      if (withRemote) {
        const r = await loadStatus(project, true, true);
        setRemoteFailed(r === null);   // 원격 점검을 모르는 옛 하네스 — 이전 결과를 그대로 둔다
        if (r !== null) { setSt(r); setRemote(true); }
      } else {
        setSt(await loadStatus(project, fresh));
      }
    } finally { setLoading(false); }
  };
  useEffect(() => { load(false); }, []); // eslint-disable-line react-hooks/exhaustive-deps

  if (st === undefined) return <p className="muted pulse">doctor 를 돌리는 중입니다…</p>;
  if (st === null) return <p className="error">상태를 읽지 못했습니다. 이 프로젝트의 하네스가 오래된 버전일 수 있습니다.</p>;

  const items = [...st.doctor.items];
  if (newer(global, st.version))
    items.unshift({ section: "harness", state: "warn", what: "", fix: { title: `하네스를 v${global} 로 올릴 수 있습니다`, body: `지금은 v${st.version} 입니다. 설정과 프로젝트 문서는 그대로 두고 하네스 사본만 바꿉니다.`, run: { kind: "upgrade", cmd: "harness install" } } });
  const groups = {};
  for (const i of items) (groups[i.section] ??= []).push(i);
  const order = ["harness", ...Object.keys(SECTIONS), ...Object.keys(groups)].filter((s, n, a) => groups[s] && a.indexOf(s) === n)
    .sort((a, b) => !groups[a].some((i) => i.state !== "ok") - !groups[b].some((i) => i.state !== "ok"));   // 손볼 절이 먼저
  // 라벨은 상태에서 오지만, 아직 설정하지 않은 항목은 SETUP 으로 따로 센다
  for (const i of items) i.label = (i.fix ?? explain(i, base, schema)).label ?? LEVEL[i.state];
  const count = (l) => items.filter((i) => i.label === l).length;
  const [bad, setup, warn] = [count("FAIL"), count("SETUP"), count("WARN")];

  return (
    <div className="doctor">
      <section className="card doc-summary">
        <div>
          <b>{bad || setup ? "프로젝트 시작 전 고쳐야 할 항목이 있습니다" : warn ? "쓸 수 있지만 남은 항목이 있습니다" : "모든 검사를 통과했습니다"}</b>
          <div className="row lvl-row">
            {bad > 0 && <span className="lvl bad">FAIL {bad}</span>}
            {setup > 0 && <span className="lvl setup">SETUP {setup}</span>}
            {warn > 0 && <span className="lvl warn">WARN {warn}</span>}
            <span className="lvl ok">OK {count("OK")}</span>
          </div>
        </div>
        <div className="row">
          <button className="btn sync" aria-busy={loading} disabled={loading} onClick={() => load()}><LuRefreshCw size={14} aria-hidden="true" />{loading ? "Running…" : "Run again"}</button>
          <button className="btn ghost" aria-busy={loading} disabled={loading} onClick={() => load(true, true)}>원격까지 점검</button>
        </div>
        {remoteFailed
          ? <p className="error small">원격 점검을 돌리지 못했습니다. 이 프로젝트의 하네스가 원격 점검을 모르는 옛 버전일 수 있습니다.</p>
          : !st.doctor.items.some((i) => i.section === "remote")
            && <p className="muted small">원격 점검은 돌리지 않았습니다. 원격까지 점검 을 누르면 origin·forge 로그인·라벨·브랜치 보호·리뷰어 러너를 확인합니다.</p>}
      </section>
      {order.map((s) => {
        const list = groups[s];
        const open = list.filter((i) => i.state !== "ok").sort((a, b) => (a.state === "bad" ? 0 : 1) - (b.state === "bad" ? 0 : 1));
        const passed = list.filter((i) => i.state === "ok");
        return (
          <section key={s} className="card doc-section">
            <h2>{s === "harness" ? "하네스 버전" : SECTIONS[s] ?? s}
              <span className="muted small">{open.length ? `${open.length}건 확인 필요` : "모두 통과"}</span></h2>
            {open.length > 0 && <ul className="doc-items">{open.map((i, n) => <Item key={n} i={i} base={base} project={project} schema={schema} onDone={load} />)}</ul>}
            {passed.length > 0 && (
              <details className="doc-passed">
                <summary className="muted small">통과 {passed.length}건</summary>
                <ul>{passed.map((i, n) => <li key={n}><span className="lvl ok">OK</span><span>{i.what}</span></li>)}</ul>
              </details>
            )}
          </section>
        );
      })}
    </div>
  );
}

// fix 를 모르는 옛 사본에서 hooks · verify 조치는 돌리지 않고 재설치를 안내한다. render · upgrade 는 그대로 돈다
const NEEDS_FIX = new Set(["hooks", "verify"]);

function Item({ i, base, project, schema, onDone }) {
  const x = i.fix ?? explain(i, base, schema);
  const stale = x.run && NEEDS_FIX.has(x.run.kind) && !schema?.docs;
  const [out, setOut] = useState(null);
  const [busy, setBusy] = useState(false);
  const run = async () => {
    setBusy(true); setOut(null);
    try {
      const r = await doctorFix(project, x.run.kind);
      setOut(r);
      if (r.ok) onDone();
    } finally { setBusy(false); }
  };
  return (
    <li className="doc-item">
      <span className={`lvl ${i.label === "SETUP" ? "setup" : i.state}`}>{i.label}</span>
      <div className="doc-main">
        <b>{x.title}</b>
        {x.body && <p>{x.body}</p>}
        {x.run && stale && <Reinstall what="이 조치를 실행" compact />}
        {x.run && !stale && (
          <div className="cmd-run">
            <button type="button" className="play" aria-label={`실행: ${x.run.cmd || x.run.kind}`} title="실행" aria-busy={busy} disabled={busy} onClick={run}>
              <LuPlay size={13} aria-hidden="true" />
            </button>
            {x.run.cmd && <code>{x.run.cmd}</code>}
          </div>
        )}
        {x.cmd && <div className="cmd-run"><code>{x.cmd}</code></div>}
        {out && <pre className={out.ok ? "result ok" : "result err"}>{out.out || (out.ok ? "완료했습니다." : "실패했습니다.")}</pre>}
      </div>
      {x.href && <Link className="btn ghost small" href={x.href}>Open</Link>}
    </li>
  );
}
