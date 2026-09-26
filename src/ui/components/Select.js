"use client";
import { useEffect, useId, useRef, useState } from "react";

// 목록을 직접 그리는 선택 상자. 네이티브 select 는 펼친 목록을 꾸밀 수 없다.
// 키보드: ↑↓ 이동 · Enter/Space 선택 · Esc 닫기 · Tab 은 닫고 넘어간다.
// options 는 [값, 보이는 이름] 쌍이다. 목록에 없는 값이면 그 값을 그대로 보인다.
// pinned: 목록 맨 아래에 붙여 둘 항목의 값(예: "새로 만들기"). 스크롤돼도 바닥에 보인다
export default function Select({ id, value, options, onChange, disabled, busy, pinned, placeholder = "선택…" }) {
  const vals = options.map(([v]) => v);
  const hit = options.find(([v]) => v === value);
  const shown = hit?.[1] ?? value;
  // 빈 값도 목록에 이름이 있으면(예: "Default") 그 이름을 보인다
  const empty = !hit && (value === undefined || value === "");
  const [open, setOpen] = useState(false);
  const [at, setAt] = useState(Math.max(0, vals.indexOf(value)));
  const box = useRef(null);
  const list = useId();

  useEffect(() => {
    if (!open) return;
    const off = (e) => box.current && !box.current.contains(e.target) && setOpen(false);
    document.addEventListener("mousedown", off);
    return () => document.removeEventListener("mousedown", off);
  }, [open]);

  const pick = (i) => { setOpen(false); if (vals[i] !== value) onChange(vals[i]); };
  const key = (e) => {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      if (!open) { setOpen(true); setAt(Math.max(0, vals.indexOf(value))); return; }
      setAt((i) => (i + (e.key === "ArrowDown" ? 1 : -1) + options.length) % options.length);
    } else if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      open ? pick(at) : setOpen(true);
    } else if (e.key === "Escape") setOpen(false);
    else if (e.key === "Tab") setOpen(false);
  };

  return (
    <div className={`sel${open ? " open" : ""}`} ref={box}>
      <button id={id} type="button" className="sel-btn" disabled={disabled} aria-busy={busy || undefined}
        role="combobox" aria-haspopup="listbox" aria-expanded={open} aria-controls={list}
        aria-activedescendant={open ? `${list}-${at}` : undefined}
        onClick={() => { setAt(Math.max(0, vals.indexOf(value))); setOpen(!open); }} onKeyDown={key}>
        <span className={empty ? "sel-ph" : ""}>{empty ? placeholder : shown}</span>
        <svg className="sel-caret" viewBox="0 0 12 12" width="12" height="12" aria-hidden="true"><path d="M2 8l4-4 4 4z" fill="currentColor" /></svg>
      </button>
      {open && (
        <ul id={list} role="listbox" className="sel-list">
          {options.map(([o, name], i) => (
            <li key={o} id={`${list}-${i}`} role="option" aria-selected={o === value}
              className={`${i === at ? "at" : ""}${o === value ? " on" : ""}${o === pinned ? " pinned" : ""}`}
              onMouseEnter={() => setAt(i)} onMouseDown={(e) => { e.preventDefault(); pick(i); }}>{name}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
