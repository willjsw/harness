"use client";

// 읽기 / 편집. 글자 없이 아이콘으로만 가른다 — 이름은 보조 기술과 툴팁에 남긴다.
const EYE = <><path d="M1.5 8S4 3.5 8 3.5 14.5 8 14.5 8 12 12.5 8 12.5 1.5 8 1.5 8z" /><circle cx="8" cy="8" r="2" /></>;
const PEN = <><path d="M10.5 2.5l3 3-8 8H2.5v-3z" /><path d="M9 4l3 3" /></>;

export default function ModeToggle({ edit, onChange, disabled }) {
  const b = (on, label, icon) => (
    <button type="button" className={on ? "on" : ""} aria-pressed={on} aria-label={label} title={label}
      disabled={disabled} onClick={() => onChange(label === "수정 모드")}>
      <svg viewBox="0 0 16 16" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{icon}</svg>
    </button>
  );
  return <div className="mode" role="group" aria-label="보기 방식">{b(!edit, "뷰어 모드", EYE)}{b(edit, "수정 모드", PEN)}</div>;
}
