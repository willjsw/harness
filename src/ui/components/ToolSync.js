"use client";
import { useTransition, useState } from "react";
import { syncTools } from "@/lib/actions";

// 이 기기에서 찾은 도구와 다시 찾는 버튼. 드롭다운은 찾은 것 중 하네스가 쓸 수 있는 것만 보인다.
export default function ToolSync({ project, tools, kind }) {
  const [pending, start] = useTransition();
  const [msg, setMsg] = useState(null);
  const found = kind === "agents" ? tools?.agents ?? [] : tools?.adr_tools ?? [];
  return (
    <div className="tools">
      <div className="tools-list">
        {found.length ? found.map((t) => (
          <span key={t.id} className={`tool${t.supported === false ? " off" : ""}`} title={t.path}>
            {t.name ?? t.id}{t.version && <em>{t.version.replace(t.name ?? "", "").replace(/[()]/g, "").trim()}</em>}
            {t.supported === false && <b>Not Supported</b>}
          </span>
        )) : <span className="muted small">{kind === "agents" ? "찾은 에이전트 CLI 가 없다" : "찾은 도구가 없다 — Manual 이나 None 만 고를 수 있다"}</span>}
      </div>
      <button type="button" className="btn ghost sync" disabled={pending} onClick={() => start(async () => setMsg(await syncTools(project)))}
        aria-label="설치된 도구 다시 찾기" title={tools?.synced_at ? `마지막 동기화 ${tools.synced_at}` : "아직 찾지 않았다"}>
        <svg className={pending ? "spin" : ""} viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" aria-hidden="true">
          <path d="M13.5 8a5.5 5.5 0 1 1-1.6-3.9M13.5 2.5v3h-3" />
        </svg>
        Sync
      </button>
      {msg && !msg.ok && <pre className="result err">{msg.out}</pre>}
    </div>
  );
}
