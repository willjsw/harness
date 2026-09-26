"use client";
import { useState, useTransition } from "react";
import { setValue } from "@/lib/actions";
import { BASE_PROTECTED, isDir, pathProblem } from "@/lib/paths";

const FILE = <path d="M4 1.5h5l3 3V14a.5.5 0 0 1-.5.5h-7.5A.5.5 0 0 1 3.5 14V2a.5.5 0 0 1 .5-.5zM9 1.5V5h3" />;
const DIR = <path d="M1.5 4a1 1 0 0 1 1-1h3.5l1.5 1.5h6a1 1 0 0 1 1 1V12a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1z" />;
const Ico = ({ d, cls = "" }) => (
  <svg className={`pico ${cls}`} viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round" aria-hidden="true">{d}</svg>
);

// 보호 문서 목록. 한 줄에 경로 하나 — 긴 경로를 태그로 늘어놓으면 앞부분이 같은 것끼리 비교하기 어렵다.
// 기준 문서는 CLI 가 늘 넣으므로 잠겨 있고, 더한 경로만 지울 수 있다.
export default function PathList({ project, k, value }) {
  const initial = value.filter((x) => !BASE_PROTECTED.includes(x));
  const [list, setList] = useState(initial);
  const [draft, setDraft] = useState("");
  const [err, setErr] = useState(null);
  const [msg, setMsg] = useState(null);
  const [pending, start] = useTransition();
  const dirty = JSON.stringify(list) !== JSON.stringify(initial);

  const add = () => {
    const p = draft.trim();
    const why = pathProblem(p, [...BASE_PROTECTED, ...list]);
    if (why) { setErr(why); return; }
    setList([...list, p]); setDraft(""); setErr(null);
  };
  const save = () => start(async () => setMsg(await setValue(project, k, [...BASE_PROTECTED, ...list].join(","), true)));

  return (
    <>
      <ul className="paths" aria-label="보호 문서 목록">
        <li className="path-group">
          <Ico d={DIR} /><code>.ai/project/</code>
        </li>
        {BASE_PROTECTED.map((p) => (
          <li key={p} className="path-row locked">
            <Ico d={isDir(p) ? DIR : FILE} /><code>{p.slice(".ai/project/".length)}</code>
          </li>
        ))}
        {list.map((p) => (
          <li key={p} className="path-row">
            <Ico d={isDir(p) ? DIR : FILE} cls={isDir(p) ? "dir" : ""} /><code>{p}</code>
            {isDir(p) && <span className="path-kind">{p.endsWith("/**") ? "하위 전체" : "디렉터리"}</span>}
            <span className="grow-x" />
            <button type="button" className="icon" aria-label={`${p} 삭제`} disabled={pending} onClick={() => setList(list.filter((x) => x !== p))}>×</button>
          </li>
        ))}
      </ul>
      <div className="row path-add">
        <input id={k} value={draft} disabled={pending} placeholder="docs/spec/ 또는 docs/guide.md" aria-invalid={!!err} aria-describedby={err ? `${k}-err` : undefined}
          onChange={(e) => { setDraft(e.target.value); setErr(null); }} onKeyDown={(e) => e.key === "Enter" && (e.preventDefault(), add())} />
        <button className="btn" disabled={pending || !draft.trim()} onClick={add}>Add</button>
        {dirty && <button className="btn primary" aria-busy={pending} disabled={pending} onClick={save}>Save</button>}
      </div>
      {err && <p className="error" id={`${k}-err`}>{err}</p>}
      {msg && <pre className={msg.ok ? "result ok" : "result err"}>{msg.out}</pre>}
    </>
  );
}
