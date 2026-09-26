"use client";
import { useState, useTransition } from "react";
import { setValue, setValues } from "@/lib/actions";
import { AgentLogo, RoleChip, runnerLabel, ACCESS } from "@/components/Agent";
import Select from "@/components/Select";

// 역할 하나의 실행 주체와 권한. 고를 수 있는 러너는 CLI 가 정한다(schema.roles[역할].runners) —
// 벤더 선언(templates/vendors.toml)에 실행 명령이 있는 CLI 와 서브에이전트다. 설치되지 않은 CLI 는 고르지 못한다.
export default function RoleEditor({ project, name, schema, tools }) {
  const r = schema.roles[name];
  const [msg, setMsg] = useState(null);
  const [pending, start] = useTransition();
  const installed = tools ? new Set(tools.agents.map((a) => a.id)) : null;
  const set = (field, value) => start(async () => setMsg(await setValue(project, `roles.${name}.${field}`, value, false)));
  if (!r) return null;
  // 러너를 바꾸면 역할의 모델은 비운다 — 새 벤더의 기본 모델이거나, 오케스트레이터가 돌리면 오케스트레이터 모델을 따른다
  const setRunner = (x) => r.model
    ? start(async () => setMsg(await setValues(project, [[`roles.${name}.runner`, x], [`roles.${name}.model`, ""]])))
    : set("runner", x);

  return (
    <div className="role-edit" aria-busy={pending}>
      <div className="side-title"><RoleChip name={name} /></div>
      <div className="lbl-row">Runner</div>
      <div className="choice-tags" role="radiogroup" aria-label="Runner">
        {r.runners.map((x) => {
          const vendor = x === "inproc" ? schema.orchestrator : x;
          const missing = x !== "inproc" && installed && !installed.has(x);
          return (
            <button key={x} type="button" role="radio" aria-checked={r.runner === x} disabled={pending || missing}
              className={`runner-tag choice${r.runner === x ? " on" : ""}`} title={missing ? "설치되어 있지 않다" : undefined}
              onClick={() => r.runner !== x && setRunner(x)}>
              <AgentLogo id={vendor} name={schema.agents.find((a) => a.id === vendor)?.name} />
              {runnerLabel(x, schema.agents, schema.orchestrator)}{missing && <em>not installed</em>}
            </button>
          );
        })}
      </div>
      <div className="lbl-row">Access</div>
      <div className="seg small" role="radiogroup" aria-label="Access">
        {Object.entries(ACCESS).map(([x, label]) => (
          <button key={x} type="button" role="radio" aria-checked={r.access === x} className={r.access === x ? "on" : ""}
            disabled={pending} onClick={() => r.access !== x && set("access", x)}>{label}</button>
        ))}
      </div>
      {/* 오케스트레이터가 돌리는 역할의 모델은 Harness 설정의 오케스트레이터 모델이다 — 여기서 고르지 않는다 */}
      {/* 러너가 오케스트레이터와 같은 CLI 면 오케스트레이터 자신이다 — 모델은 Harness 설정에서만. 서브에이전트는 고른다.
          러너만 보고 정한다 — 옛 하네스 사본의 schema 에는 follows_orchestrator 가 없다 */}
      {r.runner !== schema.orchestrator && (<>
        <div className="lbl-row">Model</div>
        <ModelSelect r={r} schema={schema} tools={tools} pending={pending} onPick={(m) => set("model", m)} />
      </>)}
      {msg && !msg.ok && <pre className="result err">{msg.out}</pre>}
    </div>
  );
}

// 모델은 그 역할을 실제로 돌리는 에이전트가 이 기기에서 쓸 수 있는 것만 고른다(harness tools 가 CLI 기록에서 읽었다).
// 비워 두면 그 CLI 의 기본 모델이다. 지금 값이 목록에 없으면 지우지 않고 맞지 않는다고 보인다.
function ModelSelect({ r, schema, tools, pending, onPick }) {
  const vendor = r.runner === "inproc" ? schema.orchestrator : r.runner;
  const agent = tools?.agents.find((a) => a.id === vendor);
  const name = schema.agents.find((a) => a.id === vendor)?.name ?? vendor;
  const known = agent?.models ?? [];
  // 비워 둔 서브에이전트는 오케스트레이터 모델을 이어받는다. 그것도 비었으면 CLI 의 기본 모델
  const base = r.runner === "inproc" && schema.orchestrator_model ? `${schema.orchestrator_model}, Orchestrator` : agent?.default_model;
  const opts = [["", `Default${base ? ` (${base})` : ""}`], ...known.map((m) => [m.id, m.name])];
  if (r.model && !known.some((m) => m.id === r.model)) opts.push([r.model, `${r.model} — ${name} 에 없다`]);
  return (
    <>
      <Select id={`model-${vendor}`} value={r.model ?? ""} options={opts} disabled={pending || !agent} busy={pending} onChange={onPick}
        placeholder={agent ? "Default" : "모델 목록을 읽지 못했다"} />
      {!known.length && agent && <p className="hint">{name} 의 모델 목록을 읽지 못해 기본 모델로 돈다.</p>}
    </>
  );
}
