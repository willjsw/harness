import Link from "next/link";
import { listProjects } from "@/lib/harness";
import Nav from "@/components/Nav";
import UiSettings from "@/components/UiSettings";
import { avatarStyle } from "@/lib/avatar";

export const dynamic = "force-dynamic";

export default async function ProjectLayout({ children, params }) {
  const { project } = await params;
  const name = decodeURIComponent(project);
  const projects = await listProjects();
  const current = projects.find((p) => p.name === name);
  return (
    <div className="shell">
      <aside className="sidebar">
        <details className="switcher">
          <summary>
            <span className="avatar" style={avatarStyle(name)}>{name[0]?.toUpperCase()}</span>
            <span className="grow">{name}</span>
            <span className="chev">▾</span>
          </summary>
          <div className="menu">
            {projects.map((p) => p.ok
              ? <Link key={p.name} href={`/${encodeURIComponent(p.name)}/settings`} className={p.name === name ? "on" : ""}>{p.name}<small>{p.path}</small></Link>
              : <span key={p.name} className="off" title="경로가 기록되지 않았다 — 그 프로젝트에서 harness install 을 다시 돌린다">{p.name}<small>재설치 필요</small></span>)}
          </div>
        </details>
        <Nav base={`/${project}`} project={name} />
        <Link href="/" className="home-link">
          <svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" aria-hidden="true"><path d="M2.5 7L8 2.5 13.5 7v6.5h-4v-4h-3v4h-4z" /></svg>
          Home
        </Link>
        <UiSettings />
        <div className="path muted">{current?.path}</div>
      </aside>
      <main className="content">
        {current?.ok ? children : <div className="empty"><h1>프로젝트를 찾지 못했다</h1><p>{name}</p></div>}
      </main>
    </div>
  );
}
