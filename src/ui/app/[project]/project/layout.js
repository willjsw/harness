import { DOCS } from "@/lib/fields";
import DocTabs from "@/components/DocTabs";
import { INTRO } from "@/lib/help";

export default async function ProjectDocsLayout({ children, params }) {
  const { project } = await params;
  return (
    <>
      <header className="page-head">
        <h1>Project Settings</h1>
        <p className="page-intro">{INTRO.project.map((l) => <span key={l}>{l}</span>)}</p>
      </header>
      <DocTabs base={`/${project}/project`} docs={Object.entries(DOCS).map(([d, { title }]) => [d, title])} />
      {children}
    </>
  );
}
