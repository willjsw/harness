"use client";
import { useId } from "react";

// 이름 옆 도움말. 마우스를 올리거나 키보드로 포커스할 때만 보인다. 두 줄을 넘기지 않는다.
export default function HelpTip({ text }) {
  const id = useId();
  if (!text) return null;
  return (
    <span className="help">
      <button type="button" className="help-btn" aria-label="도움말" aria-describedby={id}>?</button>
      <span role="tooltip" id={id} className="help-tip">{text}</span>
    </span>
  );
}
