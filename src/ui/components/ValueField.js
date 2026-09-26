"use client";
import { useEffect, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { setValue, setValues } from "@/lib/actions";
import { enumFor } from "@/lib/enums";
import Select from "@/components/Select";
import TagInput from "@/components/TagInput";
import PathList from "@/components/PathList";
import NumberField from "@/components/NumberField";
import { dirProblem } from "@/lib/paths";
import HelpTip from "@/components/HelpTip";

// 저장 전에 거르는 값. CLI 가 같은 검사를 다시 한다.
const CHECKS = { "adr.dir": dirProblem };
// 범위가 있는 정수. CLI 의 validate() 가 같은 범위를 검사한다(REVIEW_LIMIT).
const RANGES = { "review.max_rounds": [1, 20], "review.repeat_file_max": [1, 20] };

// 값 하나. 바꾸면 `harness set` 이 검증하고, 성립하지 않으면 설정을 되돌린 채 이유를 돌려준다.
// 선택형(참/거짓·정해진 값)은 고르는 즉시 저장하고, 글자·목록은 저장 버튼을 누를 때 저장한다.
// allowed: 고를 수 있는 값(설치된 도구). 지금 값이 거기 없으면 지우지 않고 "not installed" 로 보인다.
// 구현·리뷰가 같은 에이전트가 되어 거부되면(invariants.distinct_reviewer) 긴 오류 대신 그 설정으로 내려가
// 짧은 경고를 띄운다 — 고칠 곳은 Agents 의 러너다. 값은 CLI 가 이미 되돌렸으므로 화면도 되돌린다.
const DISTINCT = "invariants.distinct_reviewer";
const collides = (out) => /run on the same runner/.test(out);

// also: 이 값을 바꿀 때 함께 넣을 [키, 값] 들 — 한 번에 넘겨 한 번 검증한다(오케스트레이터 → 서브에이전트 역할의 모델 비우기)
export default function ValueField({ project, k, label, value, help, compact, allowed, options, also, children }) {
  const isList = Array.isArray(value);
  const all = options ?? (typeof value === "boolean" ? [["true", "true"], ["false", "false"]] : enumFor(k));
  const choices = all && allowed
    ? all.filter(([x]) => allowed.includes(x) || x === String(value))
        .map(([x, name]) => [x, allowed.includes(x) ? name : `${name} — not installed`])
    : all;
  const initial = isList ? value : String(value);
  const [v, setV] = useState(initial);
  const [msg, setMsg] = useState(null);
  const [pending, start] = useTransition();
  const [bad, setBad] = useState(null);
  const [clash, setClash] = useState(false);          // DISTINCT 칸에만: 방금 다른 값이 이 규칙에 막혔다
  const box = useRef(null);
  useEffect(() => {
    if (k !== DISTINCT) return;
    const on = (e) => {
      setClash(e.detail.clash);
      if (e.detail.clash) box.current?.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth", block: "center" });
    };
    addEventListener("harness:distinct", on);
    return () => removeEventListener("harness:distinct", on);
  }, [k]);
  const dirty = JSON.stringify(v) !== JSON.stringify(initial);

  const save = (next = v) => {
    const why = CHECKS[k]?.(isList ? "" : String(next).trim());
    if (why) { setBad(why); return; }
    setBad(null);
    run(next);
  };
  const run = (next) => start(async () => {
    const r = also?.length ? await setValues(project, [[k, next], ...also])
      : await setValue(project, k, isList ? next.join(",") : next, isList);
    const clash = !r.ok && collides(r.out) && k !== DISTINCT;
    dispatchEvent(new CustomEvent("harness:distinct", { detail: { clash } }));
    if (clash) { setV(initial); setMsg(null); return; }
    setMsg(r);
  });

  return (
    <div ref={box} className={compact ? "field compact" : "field"}>
      <div className="field-head">
        <span className="label-help"><label htmlFor={k}>{label ?? k}</label><HelpTip text={help} /></span>
        {!compact && <code className="key fname">{k}</code>}
      </div>
      {k === "docs.protected" ? <PathList project={project} k={k} value={value} /> : (<>
      <div className="row">
        {RANGES[k] ? (
          <NumberField id={k} value={Number(v)} min={RANGES[k][0]} max={RANGES[k][1]} disabled={pending} busy={pending}
            onCommit={(n) => { setV(String(n)); save(String(n)); }} />
        ) : choices ? (
          <Select id={k} value={v} options={choices} disabled={pending} busy={pending} onChange={(x) => { setV(x); save(x); }} />
        ) : isList ? (
          <TagInput id={k} value={v} disabled={pending} onChange={setV} />
        ) : (
          <input id={k} value={v} disabled={pending}
            aria-invalid={!!bad} onChange={(e) => { setV(e.target.value); setBad(null); }}
            onKeyDown={(e) => e.key === "Enter" && dirty && save()} />
        )}
        {!choices && !RANGES[k] && dirty && <button className="btn primary" aria-busy={pending} disabled={pending} onClick={() => save()}>Save</button>}
      </div>
      {clash && <p className="error" role="alert">구현과 리뷰에 같은 에이전트를 쓸 수 없어 되돌렸습니다. <Link href={`/${encodeURIComponent(project)}/agents`}>Agents 설정</Link>을 확인하세요.</p>}
      {children}
      {bad && <p className="error">{bad}</p>}
      {msg && <pre className={msg.ok ? "result ok" : "result err"}>{msg.out}</pre>}
      </>)}
    </div>
  );
}
