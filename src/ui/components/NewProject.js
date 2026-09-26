"use client";
import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { LuPlus, LuFolderOpen } from "react-icons/lu";
import { createProject, pickDirectory } from "@/lib/actions";

// 디렉터리를 지정해 하네스가 설치된 프로젝트를 만든다. 이미 있는 디렉터리면 그 안에 설치하고 등록한다.
// 홈 카드 목록 끝의 카드를 누르면 모달에서 입력을 받는다.
export default function NewProject() {
  const ref = useRef(null);
  const [dir, setDir] = useState("");
  const [git, setGit] = useState(true);
  const [msg, setMsg] = useState(null);
  const [picking, setPicking] = useState(false);
  const [pending, start] = useTransition();
  const router = useRouter();
  const create = () => start(async () => {
    const r = await createProject(dir.trim(), git);
    setMsg(r);
    if (r.ok && r.name) { ref.current.close(); router.push(`/${encodeURIComponent(r.name)}/settings`); }
  });
  const browse = async () => {
    setPicking(true); setMsg(null);
    try {
      const r = await pickDirectory();
      if (r.ok) setDir(r.path);
      else if (!r.cancel) setMsg(r);
    } finally { setPicking(false); }
  };
  return (
    <>
      {/* 카드 목록의 마지막 자리에 늘 있다 — 프로젝트가 늘어도 같은 자리에서 찾는다 */}
      <button type="button" className="project-card new-card" onClick={() => ref.current.showModal()}>
        <span className="new-plus" aria-hidden="true"><LuPlus size={28} /></span>
        <b>New Project</b>
      </button>
      <dialog ref={ref} className="modal" aria-label="New Project" onClick={(e) => e.target === ref.current && !pending && ref.current.close()}>
        <div className="modal-body">
          <h2>New Project</h2>
          <p className="muted small">폴더를 고르면 그 안에 하네스를 설치하고 등록합니다. 없는 폴더는 새로 만듭니다.</p>
          <label className="lbl" htmlFor="np-dir">Directory</label>
          <div className="row np-row">
            <input id="np-dir" className="mono" value={dir} placeholder="/Users/me/work/my-app" spellCheck={false} disabled={pending}
              onChange={(e) => { setDir(e.target.value); setMsg(null); }} onKeyDown={(e) => e.key === "Enter" && dir.trim() && create()} />
            <button type="button" className="btn sync" aria-busy={picking} disabled={pending || picking} onClick={browse}>
              <LuFolderOpen size={15} aria-hidden="true" />{picking ? "Choosing…" : "Browse…"}
            </button>
          </div>
          <label className="check-row"><input type="checkbox" checked={git} disabled={pending} onChange={(e) => setGit(e.target.checked)} /> Initialize git repository</label>
          {msg && !msg.ok && <pre className="result err">{msg.out}</pre>}
          <div className="row end">
            <button type="button" className="btn" disabled={pending} onClick={() => ref.current.close()}>Cancel</button>
            <button type="button" className="btn primary" aria-busy={pending} disabled={pending || !dir.trim()} onClick={create}>{pending ? "Installing…" : "Create & Install"}</button>
          </div>
        </div>
      </dialog>
    </>
  );
}
