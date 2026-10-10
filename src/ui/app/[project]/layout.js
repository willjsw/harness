import Link from "next/link";
import { notFound } from "next/navigation";
import { listProjects } from "@/lib/harness";
import Nav from "@/components/Nav";
import UiSettings from "@/components/UiSettings";
import { avatarStyle } from "@/lib/avatar";

export const dynamic = "force-dynamic";

export default async function ProjectLayout({ children, params }) {
  const { project } = await params;
  const key = decodeURIComponent(project);
  const projects = await listProjects();
  const current = projects.find((p) => p.key === key);
  // 등록부에 없는 클론 키이거나 경로를 쓸 수 없는 등록이면 404 다.
  if (!current?.ok) notFound();
  const name = current.name;
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
              ? <Link key={p.key} href={`/${encodeURIComponent(p.key)}/settings`} className={p.key === key ? "on" : ""}>{p.name}<small>{p.path}</small></Link>
              : <span key={p.key ?? `legacy:${p.name}`} className="off" title={p.legacy ? "옛 설치다 — 그 프로젝트에서 harness install 을 다시 돌린다" : "경로가 기록되지 않았다 — 그 프로젝트에서 harness install 을 다시 돌린다"}>{p.name}<small>재설치 필요</small></span>)}
          </div>
        </details>
        <Nav base={`/${project}`} project={key} />
        <Link href="/" className="home-link">
          <svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" aria-hidden="true"><path d="M2.5 7L8 2.5 13.5 7v6.5h-4v-4h-3v4h-4z" /></svg>
          Home
        </Link>
        <UiSettings />
        <div className="path muted">{current.path}</div>
      </aside>
      <main className="content">
        {children}
      </main>
    </div>
  );
}
