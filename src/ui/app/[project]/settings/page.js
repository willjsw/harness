import { getProject, readConfig, readTools, readSchema } from "@/lib/harness";
import ToolSync from "@/components/ToolSync";
import ValueField from "@/components/ValueField";
import Toc from "@/components/Toc";
import CommitSettings from "@/components/CommitSettings";
import { settingTitle } from "@/lib/labels";
import { HELP, INTRO } from "@/lib/help";
import HelpTip from "@/components/HelpTip";
import CopyButton from "@/components/CopyButton";

// 버전은 설치가 정한다 — 여기서 고치면 고정 사본과 어긋난다.
// 역할과 절차 단계는 워크플로·Agents 화면이, 명령과 검증은 Project Settings 의 명령 탭이 다룬다 —
// 같은 값을 두 화면에서 고치게 두지 않는다.
const ELSEWHERE = new Set(["roles", "workflows", "commands", "verify"]);
const READONLY = new Set(["harness.version"]);
// 절을 의미로 묶는다. 여기 없는 절(설정에 새로 생긴 것)은 "기타" 로 간다.
const GROUPS = [
  ["general", "General", ["harness", "project", "usage"]],
  ["scm", "Source Control", ["branches", "commit"]],
  ["review", "Code Review", ["review", "mr", "invariants"]],
  ["integrations", "Integrations", ["forge", "issues"]],
  ["documents", "Documents", ["docs", "adr"]],
  ["metrics", "Metrics", ["metrics"]],
];
// Commit 의 이 둘은 CommitSettings 가 함께 다룬다
const COMMIT_OWN = new Set(["commit.issue_ref", "commit.ticket_key"]);

export default async function Settings({ params }) {
  const project = decodeURIComponent((await params).project);
  const { path } = await getProject(project);
  const [cfg, tools, schema] = await Promise.all([readConfig(path), readTools(), readSchema(path)]);
  // 등록부의 오케스트레이터 후보. 옛 버전에 고정된 프로젝트는 schema 가 없어 지금 값만 보인다
  // 오케스트레이터 모델(harness.model). 오케스트레이터가 돌리는 역할도 이 모델을 쓴다 — 오케스트레이터 설정은 여기서만.
  // 옛 설정에는 키가 없어 오케스트레이터 바로 뒤에 빈 값으로 보인다(이 기능을 아는 하네스 버전일 때만)
  const hasModel = schema && Object.values(schema.roles).some((r) => "follows_orchestrator" in r);
  if (hasModel && !("model" in cfg.harness)) {
    cfg.harness = Object.fromEntries(Object.entries(cfg.harness).flatMap(([k, v]) => k === "orchestrator" ? [[k, v], ["model", ""]] : [[k, v]]));
  }
  // 오케스트레이터를 바꾸면 모델은 새 벤더의 기본 모델로 — 전 벤더의 모델 이름은 새 벤더에 없다.
  // 서브에이전트 역할도 실행 주체가 따라 바뀌므로 함께 비운다
  const resetModel = [...(cfg.harness.model ? [["harness.model", ""]] : []),
    ...(schema ? Object.entries(schema.roles).filter(([, r]) => r.runner === "inproc" && r.model).map(([n]) => [`roles.${n}.model`, ""]) : [])];
  const orch = tools?.agents.find((a) => a.id === cfg.harness.orchestrator);
  const options = {
    "harness.orchestrator": schema ? schema.agents.filter((a) => a.orchestrator).map((a) => [a.id, a.name]) : [[cfg.harness.orchestrator, cfg.harness.orchestrator]],
    "harness.model": [["", `Default${orch?.default_model ? ` (${orch.default_model})` : ""}`], ...(orch?.models ?? []).map((m) => [m.id, m.name]),
      ...(cfg.harness.model && !(orch?.models ?? []).some((m) => m.id === cfg.harness.model) ? [[cfg.harness.model, cfg.harness.model]] : [])],
  };
  // 설치된 도구만 고르게 한다. 기록을 못 읽으면 거르지 않는다 — 고를 수 없게 만드는 것보다 낫다.
  const allowed = tools && {
    "harness.orchestrator": tools.agents.filter((a) => a.supported).map((a) => a.id),
    "adr.tool": ["manual", "none", ...tools.adr_tools.map((a) => a.id)],
  };
  const sync = { "harness.orchestrator": "agents", "adr.tool": "adr" };
  const sections = Object.fromEntries(Object.entries(cfg).filter(([s]) => !ELSEWHERE.has(s)));
  const title = settingTitle;
  const grouped = new Set(GROUPS.flatMap(([, , ss]) => ss));
  const rest = Object.keys(sections).filter((s) => !grouped.has(s));
  const groups = [...GROUPS, ...(rest.length ? [["other", "Other", rest]] : [])]
    .map(([id, label, ss]) => [id, label, ss.filter((s) => s in sections)]).filter(([, , ss]) => ss.length);
  return (
    <div className="settings-page">
      <div className="settings-main">
      <header className="page-head">
        <h1>Harness</h1>
        <p className="page-intro">{INTRO.harness.map((l) => <span key={l}>{l}</span>)}</p>
      </header>
      {groups.map(([gid, glabel, ss]) => (
        <div key={gid} id={`g-${gid}`} className="settings-group">
        <h2 className="group-title">{glabel}</h2>
      {ss.map((section) => [section, sections[section]]).map(([section, body]) => (
        <section key={section} id={`s-${section}`} className="settings-sec">
          <h3 className="sec-title">{title(section)}</h3>
          <div className="card">
          {Object.entries(body).filter(([key]) => !COMMIT_OWN.has(`${section}.${key}`)).map(([key, val]) => {
            const k = `${section}.${key}`;
            const plain = val === null || typeof val !== "object" || (Array.isArray(val) && val.every((x) => typeof x === "string"));
            return plain && !READONLY.has(k)
              ? <ValueField key={k} project={project} k={k} label={settingTitle(key)} value={val} help={HELP[k]} allowed={allowed?.[k]} options={options[k]} also={k === "harness.orchestrator" ? resetModel : undefined}>
                  {sync[k] && <ToolSync project={project} tools={tools} kind={sync[k]} />}
                  {k === "harness.orchestrator" && schema && Object.entries(schema.roles).some(([, r]) => r.model_ok === false) && (
                    <p className="error">모델이 실행 주체와 맞지 않는 역할: {Object.entries(schema.roles).filter(([, r]) => r.model_ok === false).map(([n, r]) => `${n} (${r.model})`).join(", ")} —{" "}
                      <a href={`/${encodeURIComponent(project)}/agents`}>Agents 탭에서 고친다</a></p>
                  )}
                </ValueField>
              : (
                <div key={k} className="field">
                  <div className="field-head"><span className="label-help"><label>{settingTitle(key)}</label><HelpTip text={HELP[k]} /></span><code className="key fname">{k}</code></div>
                  {typeof val === "object" && val !== null
                    ? <div className="ro-box">{Object.entries(val).map(([a, b]) => <span key={a} className="tag-md"><span className="muted">{a}</span> {String(b)}</span>)}</div>
                    : <span className="tag-md">{String(val)}</span>}
                  {k === "harness.version" && (<>
                    <div className="field-head" style={{ marginTop: 16 }}><label>Project Directory</label></div>
                    <div className="row"><span className="path-box">{path}</span><CopyButton text={path} /></div>
                  </>)}
                </div>
              );
          })}
          {section === "commit" && (
            <CommitSettings key={`${body.issue_ref}|${body.ticket_key}`} project={project} tags={body.tags}
              issueRef={body.issue_ref} ticketKey={body.ticket_key} tracker={cfg.forge?.tracker} />
          )}
          </div>
        </section>
      ))}
        </div>
      ))}
      </div>
      <aside className="settings-toc"><Toc items={groups.flatMap(([gid, glabel, ss]) => [
        { id: `g-${gid}`, label: glabel, group: true },
        ...ss.map((s) => ({ id: `s-${s}`, label: title(s) })),
      ])} /></aside>
    </div>
  );
}
