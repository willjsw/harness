"use client";
import { useEffect, useLayoutEffect, useRef, useState } from "react";

// 이 페이지의 목차. 표시 막대 하나가 현재 절로 미끄러진다.
// group 항목은 묶음 제목이다 — 누르면 그리로 가지만 현재 위치는 그 아래 절이 받는다.
// 누른 뒤 스크롤이 끝날 때까지는 위치 추적을 멈춘다 — 지나가는 절마다 표시가 옮겨 다니지 않게.
export default function Toc({ items }) {
  const [active, setActive] = useState(items.find((it) => !it.group)?.id);
  const [bar, setBar] = useState(null);
  const nav = useRef(null);
  const locked = useRef(false);

  useEffect(() => {
    const seen = new Map();
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => seen.set(e.target.id, e.isIntersecting));
      if (locked.current) return;
      const first = items.find((it) => !it.group && seen.get(it.id));
      if (first) setActive(first.id);
    }, { rootMargin: "-10% 0px -70% 0px" });
    items.filter((it) => !it.group).forEach((it) => { const el = document.getElementById(it.id); if (el) io.observe(el); });
    return () => io.disconnect();
  }, [items]);

  useLayoutEffect(() => {
    const a = nav.current?.querySelector(`a[href="#${active}"]`);
    if (a) setBar({ top: a.offsetTop, height: a.offsetHeight });
  }, [active]);

  const go = (e, id) => {
    e.preventDefault();
    // 묶음 제목을 누르면 그 첫 절이 현재 위치다
    const i = items.findIndex((it) => it.id === id);
    setActive(items[i].group ? items.slice(i).find((it) => !it.group)?.id : id);
    locked.current = true;
    // ponytail: scrollend 가 없는 브라우저는 시간으로 푼다
    const unlock = () => { locked.current = false; window.removeEventListener("scrollend", unlock); };
    window.addEventListener("scrollend", unlock);
    setTimeout(unlock, 1200);
    document.getElementById(id)?.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth", block: "start" });
    history.replaceState(null, "", `#${id}`);
  };

  return (
    <nav className="toc" aria-label="이 페이지의 목차" ref={nav}>
      {bar && <span className="toc-bar" style={{ transform: `translateY(${bar.top}px)`, height: bar.height }} aria-hidden="true" />}
      {items.map((it) => (
        <a key={it.id} href={`#${it.id}`} className={`${it.group ? "toc-group" : "toc-sub"}${it.id === active ? " on" : ""}`}
          aria-current={it.id === active ? "location" : undefined} onClick={(e) => go(e, it.id)}>{it.label}</a>
      ))}
    </nav>
  );
}
