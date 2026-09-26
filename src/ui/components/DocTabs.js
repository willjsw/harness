"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useLayoutEffect, useRef, useState } from "react";

// 프로젝트 문서의 탭. 레이아웃에 있어 문서를 바꿔도 남으므로 밑줄이 옮겨 갈 수 있다.
export default function DocTabs({ base, docs }) {
  const here = usePathname();
  const box = useRef(null);
  const [bar, setBar] = useState(null);
  const current = docs.find(([d]) => here === `${base}/${d}`)?.[0];

  useLayoutEffect(() => {
    const measure = () => {
      const a = box.current?.querySelector("a.on");
      setBar(a ? { left: a.offsetLeft, width: a.offsetWidth } : null);
    };
    measure();
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, [current]);

  return (
    <div className="tabs" ref={box}>
      {docs.map(([d, title]) => (
        <Link key={d} href={`${base}/${d}`} className={d === current ? "on" : ""} aria-current={d === current ? "page" : undefined}>{title}</Link>
      ))}
      {bar && <span className="tab-bar" style={{ transform: `translateX(${bar.left}px)`, width: bar.width }} aria-hidden="true" />}
    </div>
  );
}
