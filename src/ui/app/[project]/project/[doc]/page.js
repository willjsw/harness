import { notFound } from "next/navigation";
import { DOCS } from "@/lib/fields";
import { getProject, readDoc, readSchema } from "@/lib/harness";
import DocEditor from "@/components/DocEditor";
import CommandsEditor, { CommandsUnsupported } from "@/components/CommandsEditor";

export default async function ProjectDoc({ params }) {
  const { project: raw, doc } = await params;
  if (!(doc in DOCS)) notFound();
  const project = decodeURIComponent(raw);
  const { path } = await getProject(project);
  if (doc === "commands") {
    // 명령은 문서가 아니라 설정이다. 옛 하네스 사본(스키마에 commands 가 없다)은 예전처럼 문서로 받는다
    const schema = await readSchema(path);
    if (schema?.commands)
      return <CommandsEditor project={project} initial={{ commands: schema.commands, checks: schema.checks }} legacy={schema.legacy_verify} />;
    return <><CommandsUnsupported /><DocEditor key={doc} project={project} doc={doc} initial={await readDoc(path, doc)} /></>;
  }
  return <DocEditor key={doc} project={project} doc={doc} initial={await readDoc(path, doc)} />;
}
