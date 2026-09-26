"use client";
import { useEffect, useState } from "react";
import { LuRefreshCw } from "react-icons/lu";
import { metricsData } from "@/lib/actions";
import { fmtTokens, fmtMs, stackedBars, hbars, waterfall, seriesColor } from "@/lib/charts";

const RANGES = [["24h", "24h"], ["7d", "7 days"], ["30d", "30 days"]];
const STATUS = { ok: ["OK", "ok"], error: ["FAIL", "bad"], running: ["RUNNING", "setup"], stale: ["STALE", "warn"] };
const tokensOf = (u) => (u?.input ?? 0) + (u?.output ?? 0);

// 실행 지표. 열 때와 새로고침할 때 대화 기록을 가져온 뒤 집계를 받는다. 차트는 SVG 로 직접 그린다.
export default function MetricsView({ project }) {
  const [range, setRange] = useState("7d");
  const [data, setData] = useState(null);
  const [trace, setTrace] = useState(null);
  const [busy, setBusy] = useState(false);
  const load = async (r = range, t = trace) => {
    setBusy(true);
    try { setData(await metricsData(project, r, t)); } finally { setBusy(false); }
  };
  useEffect(() => { load(); }, []); // eslint-disable-line react-hooks/exhaustive-deps

  if (!data) return <p className="muted pulse">지표를 모으는 중입니다…</p>;
  if (data.unsupported) return <p className="notice warn">이 프로젝트의 하네스 사본은 실행 지표를 모르는 옛 버전입니다. 프로젝트에서 <code>harness install</code> 로 사본을 새로 받으면 기록이 시작됩니다.</p>;
  if (data.error) return <pre className="result err">{data.error}</pre>;
  const s = data.summary, d = data.diagnostics;
  const pick = (t) => { const next = t === trace ? null : t; setTrace(next); load(range, next); };

  return (
    <div className="metrics">
      <div className="row between">
        <div className="seg small" role="radiogroup" aria-label="기간">
          {RANGES.map(([r, label]) => (
            <button key={r} type="button" role="radio" aria-checked={range === r} className={range === r ? "on" : ""}
              onClick={() => { setRange(r); load(r); }}>{label}</button>
          ))}
        </div>
        <button className="btn sync" aria-busy={busy} disabled={busy} onClick={() => load()}>
          <LuRefreshCw size={14} aria-hidden="true" />{busy ? "Loading…" : "Refresh"}
        </button>
      </div>
      {!d.enabled && <p className="notice warn">실행 지표가 꺼져 있습니다(<code>metrics.dir = "off"</code>). Harness 탭의 Metrics 에서 켤 수 있습니다.</p>}

      <section className="m-cards">
        <Card label="Tokens" value={fmtTokens(s.tokens.input + s.tokens.output)}
          sub={`in ${fmtTokens(s.tokens.input)} · out ${fmtTokens(s.tokens.output)} · cache ${fmtTokens(s.tokens.cache_read + s.tokens.cache_write)}`} />
        <Card label="Runs" value={s.runs} sub={s.success_rate == null ? "끝난 실행 없음" : `성공률 ${Math.round(s.success_rate * 100)}% · 실패 ${s.error}`} />
        <Card label="Time" value={fmtMs(s.dur_ms)} sub="끝난 실행의 합" />
        <Card label="Now" value={s.running} sub={`실행 중 · 중단됨(STALE) ${s.stale}`} />
      </section>

      <section className="card">
        <h2 className="panel-title">일별 토큰</h2>
        <Daily daily={data.daily} />
      </section>

      <Breakdown data={data} />

      <section className="card">
        <h2 className="panel-title">실행 <span className="muted small">누르면 단계별 시간과 토큰을 펼칩니다</span></h2>
        {data.traces.length === 0 ? <p className="muted small">이 기간에 남은 실행이 없습니다.</p> : (
          <table className="m-table">
            <thead><tr><th>상태</th><th>실행</th><th>시작</th><th className="num-c">시간</th><th className="num-c">토큰</th><th>출처</th></tr></thead>
            <tbody>
              {data.traces.map((t) => {
                const [label, cls] = STATUS[t.status] ?? [t.status, "ok"];
                return (
                  <tr key={t.trace} className={t.trace === trace ? "on" : ""} onClick={() => pick(t.trace)} tabIndex={0}
                    onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && (e.preventDefault(), pick(t.trace))}>
                    <td><span className={`lvl ${cls}`}>{label}</span></td>
                    <td><b>{t.name}</b>{t.attrs?.issue && <span className="muted small"> #{t.attrs.issue}</span>}</td>
                    <td className="muted small">{new Date(t.t).toLocaleString()}</td>
                    <td className="num-c">{fmtMs(t.dur_ms)}</td>
                    <td className="num-c">{fmtTokens(t.tokens)}</td>
                    <td className="muted small">{t.sources.join(" · ")}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
        {trace && data.trace && <Waterfall spans={data.trace} />}
      </section>

      <section className="card">
        <h2 className="panel-title">실패 로그 <span className="muted small">이 컴퓨터에만 있는 기록입니다 — 지우고 남겨도 민감한 정보가 섞여 있을 수 있습니다</span></h2>
        {data.errors.length === 0 ? <p className="muted small">이 기간에 실패한 실행이 없습니다.</p> : data.errors.map((e, i) => (
          <details key={i} className="m-err">
            <summary><span className="lvl bad">FAIL</span> <b>{e.name}</b> <span className="muted small">종료 코드 {e.exit ?? "—"} · {new Date(e.t).toLocaleString()}</span></summary>
            <pre>{e.log || "(남긴 로그가 없습니다 — capture_logs 가 off 이거나 실패 출력이 없었습니다)"}</pre>
          </details>
        ))}
      </section>

      <p className="muted small">
        파일 {d.files}개 · {(d.bytes / 1024).toFixed(0)}KB / 상한 {d.max_total_mb}MB · {d.retention_days}일 보관
        {d.imported?.enabled && ` · 이번에 가져온 기록 ${d.imported.records}건`}
        {d.bad_lines > 0 && ` · 읽지 못한 줄 ${d.bad_lines}`}
        {d.imported?.unattributed > 0 && " · 어느 실행에도 붙이지 못한 기록은 unattributed 로 모았습니다"}
      </p>
    </div>
  );
}

function Card({ label, value, sub }) {
  return <div className="card m-card"><span className="muted small">{label}</span><b>{value}</b><span className="muted small">{sub}</span></div>;
}

function Daily({ daily }) {
  const W = 860, H = 160;
  if (!daily.length) return <p className="muted small">이 기간에 쓴 토큰이 없습니다.</p>;
  const { keys, max, bars } = stackedBars(daily, { width: W, height: H, gap: daily.length > 20 ? 3 : 8 });
  return (
    <>
      <svg viewBox={`0 0 ${W} ${H + 22}`} className="m-daily" role="img" aria-label={`일별 토큰, 최대 ${fmtTokens(max)}`}>
        <line x1="0" x2={W} y1={H} y2={H} className="m-axis" />
        {bars.map((b) => (
          <g key={b.day}>
            <title>{`${b.day} · ${fmtTokens(b.total)}\n${b.parts.map((p) => `${p.key}: ${fmtTokens(p.value)}`).join("\n")}`}</title>
            {b.parts.map((p) => <rect key={p.key} x={b.x} y={p.y} width={b.w} height={Math.max(0.5, p.h)} rx="2" fill={seriesColor(p.key)} />)}
            {bars.length <= 14 && <text x={b.x + b.w / 2} y={H + 15} className="m-tick">{b.day.slice(5)}</text>}
          </g>
        ))}
        <text x="2" y="11" className="m-tick start">{fmtTokens(max)}</text>
      </svg>
      <div className="m-legend">{keys.map((k) => <span key={k}><i style={{ background: seriesColor(k) }} />{k}</span>)}</div>
    </>
  );
}

function Breakdown({ data }) {
  const TABS = [["by_step", "Steps"], ["by_role", "Roles"], ["by_script", "Scripts"]];
  const [tab, setTab] = useState("by_step");
  const [metric, setMetric] = useState("tokens");
  const value = metric === "tokens" ? (r) => r.tokens : (r) => r.p95_ms;
  const rows = hbars([...data[tab]].sort((a, b) => value(b) - value(a)), value);
  return (
    <section className="card">
      <div className="card-head">
        <h2 className="panel-title">어디서 쓰였나</h2>
        <span className="row">
          <span className="seg small" role="radiogroup" aria-label="묶음">
            {TABS.map(([k, l]) => <button key={k} type="button" role="radio" aria-checked={tab === k} className={tab === k ? "on" : ""} onClick={() => setTab(k)}>{l}</button>)}
          </span>
          <span className="seg small" role="radiogroup" aria-label="값">
            {[["tokens", "Tokens"], ["p95", "p95 time"]].map(([k, l]) => <button key={k} type="button" role="radio" aria-checked={metric === k} className={metric === k ? "on" : ""} onClick={() => setMetric(k)}>{l}</button>)}
          </span>
        </span>
      </div>
      {rows.length === 0 ? <p className="muted small">이 기간에 기록이 없습니다.</p> : (
        <ul className="m-hbars">
          {rows.map((r) => (
            <li key={r.name}>
              <span className="m-name" title={r.name}>{r.name}</span>
              <span className="m-bar"><i style={{ width: `${Math.max(1, r.frac * 100)}%` }} /></span>
              <span className="m-val">{metric === "tokens" ? fmtTokens(r.tokens) : fmtMs(r.p95_ms)}</span>
              <span className="muted small m-meta">{r.count}회{r.errors ? ` · 실패 ${r.errors}` : ""}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function Waterfall({ spans }) {
  const { rows, total } = waterfall(spans);
  return (
    <div className="m-wf" aria-label="단계별 시간">
      <div className="m-wf-head muted small"><span>스팬</span><span>0 — {fmtMs(total)}</span></div>
      {rows.map((r) => {
        const [label, cls] = STATUS[r.status] ?? [r.status, "ok"];
        return (
          <div key={r.span} className="m-wf-row" title={`${r.name} · ${fmtMs(r.dur_ms)} · ${fmtTokens(tokensOf(r.usage))} tokens · ${r.source}`}>
            <span className="m-wf-name" style={{ paddingLeft: r.depth * 14 }}>
              <span className={`lvl ${cls}`}>{label}</span> {r.name}
            </span>
            <span className="m-wf-track">
              <i className={`${r.source === "session" ? "est" : ""} ${cls}`} style={{ left: `${r.left * 100}%`, width: `${r.width * 100}%` }} />
            </span>
            <span className="m-val">{fmtMs(r.dur_ms)}{tokensOf(r.usage) ? ` · ${fmtTokens(tokensOf(r.usage))}` : ""}</span>
          </div>
        );
      })}
      <p className="muted small">점선 막대는 대화 기록에서 가져온 값입니다 — 단계 경계는 시작 표지를 기준으로 한 추정입니다.</p>
    </div>
  );
}
