import { getProject, readSteps, listWorkflows, readSchema, readText } from "@/lib/harness";
import FlowCanvas from "@/components/FlowCanvas";

export default async function Workflow({ params }) {
  const project = decodeURIComponent((await params).project);
  const { path } = await getProject(project);
  const [steps, flows, schema] = await Promise.all([readSteps(path).catch(() => null), listWorkflows(path), readSchema(path)]);
  // 프로젝트는 설치한 버전에 고정된다. 단계 편집 전 버전이면 `harness steps` 가 없다.
  if (!steps || !schema) return (
    <div className="empty">
      <h1>이 프로젝트의 하네스는 절차 편집을 지원하지 않는다</h1>
      <p>고정된 하네스가 단계 정의 이전 버전이다. 그 프로젝트에서 다시 설치하면 올라간다.</p>
      <pre>cd {path} &amp;&amp; harness install</pre>
    </div>
  );
  return (
    <FlowCanvas
      project={project} workflows={steps} schema={schema}
      docs={Object.fromEntries(flows.map((f) => [f.name, f.text]))}
      notes={Object.fromEntries(await Promise.all(Object.entries(schema.workflow_notes ?? {}).map(async ([w, rel]) => [w, await readText(path, rel)])))}
    />
  );
}
