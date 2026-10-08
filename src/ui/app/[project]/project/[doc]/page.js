import { notFound } from "next/navigation";
import { DOCS } from "@/lib/fields";
import { getProject, readDoc, readSchema } from "@/lib/harness";
import DocEditor from "@/components/DocEditor";
import CommandsEditor from "@/components/CommandsEditor";
import Reinstall from "@/components/Reinstall";

export default async function ProjectDoc({ params }) {
  const { project: raw, doc } = await params;
  if (!(doc in DOCS)) notFound();
  const project = decodeURIComponent(raw);
  const { path } = await getProject(project);
  const schema = await readSchema(path);
  // 명령은 문서가 아니라 설정이다(write-doc 대상이 아니다)
  if (doc === "commands" && schema?.commands)
    return <CommandsEditor project={project} initial={{ commands: schema.commands, checks: schema.checks }} legacy={schema.legacy_verify} verifyScript={schema.verify_script} />;
  // 문서 경로와 저장(write-doc)은 고정 사본이 안다. 모르는 사본은 편집 대신 재설치를 안내한다
  const rel = schema?.docs?.[doc]?.path;
  if (!rel) return <Reinstall path={path} what="이 문서를 편집" />;
  return <DocEditor key={doc} project={project} doc={doc} path={rel} initial={await readDoc(path, schema, doc)} />;
}
