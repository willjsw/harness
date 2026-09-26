"use client";
import { useState } from "react";

export default function CopyButton({ text }) {
  const [done, setDone] = useState(false);
  const copy = async () => {
    await navigator.clipboard.writeText(text);
    setDone(true);
    setTimeout(() => setDone(false), 1500);
  };
  return (
    <button type="button" className="btn ghost" onClick={copy} aria-label="경로 복사" title={done ? "복사됨" : "복사"}>
      {done
        ? <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true"><path d="M3 8l3 3 7-7" fill="none" stroke="currentColor" strokeWidth="1.8" /></svg>
        : <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true"><rect x="5" y="5" width="9" height="9" rx="1.5" fill="none" stroke="currentColor" strokeWidth="1.4" /><path d="M11 3H3.5A1.5 1.5 0 0 0 2 4.5V11" fill="none" stroke="currentColor" strokeWidth="1.4" /></svg>}
    </button>
  );
}
