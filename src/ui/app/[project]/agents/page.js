import { getProject, readSchema, readTools, readRoleFiles } from "@/lib/harness";
import { INTRO } from "@/lib/help";
import AgentsView from "@/components/AgentsView";

export default async function Agents({ params }) {
  const project = decodeURIComponent((await params).project);
  const { path } = await getProject(project);
  const [schema, tools] = await Promise.all([readSchema(path), readTools()]);
  if (!schema) return (
    <div className="empty">
      <h1>이 프로젝트의 하네스는 에이전트 화면을 지원하지 않는다</h1>
      <pre>cd {path} &amp;&amp; harness install</pre>
    </div>
  );
  const files = Object.fromEntries(await Promise.all(Object.entries(schema.roles).map(async ([n, r]) => [n, await readRoleFiles(path, r)])));
  return (
    <>
      <header className="page-head">
        <h1>Agents</h1>
        <p className="page-intro">{INTRO.agents.map((l) => <span key={l}>{l}</span>)}</p>
      </header>
      <AgentsView project={project} schema={schema} tools={tools} files={files} />
    </>
  );
}
