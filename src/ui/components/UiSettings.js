"use client";
import { useEffect, useRef, useState } from "react";
import { LuSettings } from "react-icons/lu";

// 이 브라우저에만 적용되는 화면 설정. 하네스 설정(harness.toml)과 무관하다.
// 값은 <html data-fname / data-theme> 에 두고 CSS 가 따른다 — 첫 화면 깜빡임은 layout 의 인라인 스크립트가 막는다.
const THEMES = [["system", "System"], ["dark", "Dark"], ["light", "Light"]];

function save(key, value) {
  try { localStorage.setItem(`harness.ui.${key}`, value); } catch {}
}

export default function UiSettings() {
  const ref = useRef(null);
  const [show, setShow] = useState(true);
  const [theme, setTheme] = useState("system");
  useEffect(() => {
    const d = document.documentElement.dataset;
    setShow(d.fname !== "off");
    setTheme(d.theme || "system");
  }, []);
  const toggle = (on) => {
    setShow(on);
    document.documentElement.dataset.fname = on ? "on" : "off";
    save("fname", on ? "on" : "off");
  };
  const pick = (t) => {
    setTheme(t);
    if (t === "system") delete document.documentElement.dataset.theme;
    else document.documentElement.dataset.theme = t;
    save("theme", t);
  };
  return (
    <>
      <button type="button" className="home-link settings-link" onClick={() => ref.current.showModal()}>
        <LuSettings size={15} aria-hidden="true" />
        System Setting
      </button>
      <dialog ref={ref} className="modal" aria-label="System Setting" onClick={(e) => e.target === ref.current && ref.current.close()}>
        <div className="modal-body">
          <h2>System Setting</h2>
          <div className="set-row">
            <span id="theme-label">테마</span>
            <div className="seg small" role="radiogroup" aria-labelledby="theme-label">
              {THEMES.map(([t, label]) => (
                <button key={t} type="button" role="radio" aria-checked={theme === t} className={theme === t ? "on" : ""} onClick={() => pick(t)}>{label}</button>
              ))}
            </div>
          </div>
          <label className="switch-row">
            <span>설정 파일명 표시<small className="muted">UI를 통해 변경하는 실제 파일명을 표시합니다</small></span>
            <input type="checkbox" role="switch" className="switch" checked={show} onChange={(e) => toggle(e.target.checked)} />
          </label>
          <div className="row end"><button type="button" className="btn" onClick={() => ref.current.close()}>Close</button></div>
        </div>
      </dialog>
    </>
  );
}
