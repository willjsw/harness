import { listProjects, readConfig, readSchema, globalVersion } from "@/lib/harness";
import { INTRO } from "@/lib/help";
import { enumFor } from "@/lib/enums";
import HomeGrid from "@/components/HomeGrid";

export const dynamic = "force-dynamic";

// 홈 — 등록된 프로젝트를 카드로 보인다. 손볼 곳은 프로젝트마다 Doctor 탭에 있다. 카드는 먼저 그리고 상태(check·doctor)는
// 프로젝트마다 몇 초씩 걸려 화면에서 뒤이어 채운다.
export default async function Home() {
  const [list, global] = await Promise.all([listProjects(), globalVersion()]);
  const projects = await Promise.all(list.map(async (p) => {
    if (!p.ok) return p;
    const [cfg, schema] = await Promise.all([readConfig(p.path).catch(() => null), readSchema(p.path)]);
    const o = cfg?.harness.orchestrator;
    return { ...p, orchestrator: o, orchestratorName: schema?.agents.find((a) => a.id === o)?.name ?? o, forge: cfg?.forge };
  }));
  const labels = Object.fromEntries([...(enumFor("forge.tracker") ?? [])]);
  return (
    <div className="home">
      <header className="page-head">
        <h1>Projects</h1>
        <p className="page-intro">{INTRO.home.map((l) => <span key={l}>{l}</span>)}</p>
      </header>
      <HomeGrid projects={projects} global={global} labels={labels} />
    </div>
  );
}
