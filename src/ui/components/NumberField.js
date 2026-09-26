"use client";
import { useState } from "react";

// 정수 하나. − + 로 한 칸씩, 또는 직접 친다. 숫자가 아닌 글자는 들어가지 않고,
// 범위를 벗어난 값은 입력을 마칠 때 가장 가까운 끝값으로 바뀐다. 바뀐 값만 onCommit 으로 넘긴다.
export default function NumberField({ id, value, min, max, onCommit, disabled, busy }) {
  const [draft, setDraft] = useState(String(value));
  const clamp = (n) => Math.min(max, Math.max(min, n));
  const commit = (n) => {
    const v = clamp(Number.isFinite(n) ? n : value);
    setDraft(String(v));
    if (v !== value) onCommit(v);
  };
  return (
    <div className="num" aria-busy={busy || undefined}>
      <button type="button" aria-label="하나 줄이기" disabled={disabled || value <= min} onClick={() => commit(value - 1)}>−</button>
      <input id={id} inputMode="numeric" value={draft} disabled={disabled} aria-valuemin={min} aria-valuemax={max} role="spinbutton" aria-valuenow={value}
        onChange={(e) => setDraft(e.target.value.replace(/[^0-9]/g, ""))}
        onBlur={() => commit(parseInt(draft, 10))}
        onKeyDown={(e) => {
          if (e.key === "Enter") commit(parseInt(draft, 10));
          if (e.key === "ArrowUp") { e.preventDefault(); commit(value + 1); }
          if (e.key === "ArrowDown") { e.preventDefault(); commit(value - 1); }
        }} />
      <button type="button" aria-label="하나 늘리기" disabled={disabled || value >= max} onClick={() => commit(value + 1)}>+</button>
    </div>
  );
}
