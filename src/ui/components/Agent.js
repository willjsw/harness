"use client";
import { AGENT_ICONS } from "@/lib/agent-icons";
import { LuBrainCircuit, LuCodeXml } from "react-icons/lu";
import { RiOpenaiFill } from "react-icons/ri";

// simple-icons 에 없는 로고는 이미 쓰는 react-icons 에서 가져온다. Codex CLI 는 OpenAI 제품이라 OpenAI 로고(Remix Icon, Apache-2.0).
// 색은 브랜드가 흑백이라 글자색을 따른다.
const COMPONENT_ICONS = { codex: [RiOpenaiFill, "OpenAI"] };

// 에이전트 로고. 등록부(harness schema)의 id 로 찾고, 로고가 없으면 이름 첫 글자를 쓴다.
export function AgentLogo({ id, name, size = 14 }) {
  if (COMPONENT_ICONS[id]) {
    const [Icon, title] = COMPONENT_ICONS[id];
    return <Icon className="alogo" size={size} role="img" aria-label={title} style={{ color: "var(--text)" }} />;
  }
  const icon = AGENT_ICONS[id];
  if (icon) {
    return (
      <svg className="alogo" viewBox="0 0 24 24" width={size} height={size} role="img" aria-label={icon.title} style={{ color: `#${icon.hex}` }}>
        <path d={icon.path} fill="currentColor" />
      </svg>
    );
  }
  return <span className="alogo initial" style={{ width: size, height: size, fontSize: size * 0.62 }} aria-hidden="true">{(name || id || "?")[0].toUpperCase()}</span>;
}


// 역할 이름 블럭 — PLANNER 처럼 대문자로.
export function RoleChip({ name }) {
  return (
    <span className="role-chip">
      <LuBrainCircuit size={14} aria-hidden="true" />
      {name.toUpperCase()}
    </span>
  );
}

// 누가 이 역할을 실제로 돌리는가. 오케스트레이터 벤더는 이름 대신 역할로 부른다 — inproc 은 그 세션의 "Subagent",
// 러너가 오케스트레이터와 같은 CLI 면 "Orchestrator". 로고가 벤더를 알려 준다. 다른 벤더는 이름 그대로다.
export function runnerLabel(runner, agents, orchestrator) {
  if (runner === "inproc") return "Subagent";
  if (runner === orchestrator) return "Orchestrator";
  return agents.find((a) => a.id === runner)?.name ?? runner;
}

export function RunnerTag({ role, schema }) {
  const r = schema.roles[role];
  if (!r) return null;
  const who = schema.agents.find((a) => a.id === r.vendor);
  return (
    <span className="runner-tag" title={r.runner === "inproc" ? `${who?.name ?? r.vendor} 오케스트레이터의 서브에이전트` : `${who?.name ?? r.vendor} CLI 로 따로 돈다`}>
      <AgentLogo id={r.vendor} name={who?.name} />
      {runnerLabel(r.runner, schema.agents, schema.orchestrator)}
    </span>
  );
}

// 오케스트레이터 세션이 직접 하는 단계(prompt·gate)의 참여자
export function OrchestratorTag({ schema }) {
  const who = schema.agents.find((a) => a.id === schema.orchestrator);
  return (
    <span className="runner-tag" title={`${who?.name ?? schema.orchestrator} 오케스트레이터가 직접 수행한다`}>
      <AgentLogo id={schema.orchestrator} name={who?.name} />Orchestrator
    </span>
  );
}

// 사람 참여자 — 사람 게이트에서 답하는 개발자. 에이전트 로고 자리에 코드 기호를 둔다
export function DeveloperTag() {
  return (
    <span className="runner-tag" title="사람이 답할 때까지 멈춘다">
      <LuCodeXml className="alogo" size={14} aria-hidden="true" />Developer
    </span>
  );
}

export const ACCESS = { "read-only": "Read-only", write: "Write" };
