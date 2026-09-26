"use client";
import { useState } from "react";

// 목록 값. 쉼표·Enter 로 태그가 되고, x 나 빈 칸의 Backspace 로 지운다. 같은 값은 한 번만 들어간다.
export default function TagInput({ id, value, onChange, disabled, placeholder = "쉼표나 Enter 로 추가" }) {
  const [draft, setDraft] = useState("");
  const add = (text) => {
    const more = text.split(/[,\n]/).map((s) => s.trim()).filter((s) => s && !value.includes(s));
    if (more.length) onChange([...value, ...new Set(more)]);
    setDraft("");
  };
  return (
    <div className={`tags-in${disabled ? " off" : ""}`} onClick={(e) => e.currentTarget.querySelector("input")?.focus()}>
      {value.map((t) => (
        <span key={t} className="tag-chip">
          {t}
          <button type="button" aria-label={`${t} 삭제`} disabled={disabled}
            onClick={(e) => { e.stopPropagation(); onChange(value.filter((x) => x !== t)); }}>×</button>
        </span>
      ))}
      <input id={id} value={draft} disabled={disabled} placeholder={value.length ? "" : placeholder}
        onChange={(e) => (/[,\n]/.test(e.target.value) ? add(e.target.value) : setDraft(e.target.value))}
        onKeyDown={(e) => {
          if (e.key === "Enter") { e.preventDefault(); if (draft.trim()) add(draft); }
          else if (e.key === "Backspace" && !draft && value.length) onChange(value.slice(0, -1));
        }}
        onBlur={() => draft.trim() && add(draft)}
        onPaste={(e) => { const t = e.clipboardData.getData("text"); if (/[,\n]/.test(t)) { e.preventDefault(); add(draft + t); } }} />
    </div>
  );
}
