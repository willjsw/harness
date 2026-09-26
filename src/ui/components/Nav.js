"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { loadStatus, onStatus } from "@/lib/status-cache";

const ITEMS = [["settings", "Harness"], ["project", "Project Settings"], ["agents", "Agents"], ["workflow", "Workflows"], ["metrics", "Metrics"], ["doctor", "Doctor"]];

export default function Nav({ base, project }) {
  const here = usePathname();
  // Doctor 옆 숫자 = 확인이 필요한 항목(FAIL·WARN) 수. Doctor 화면에서 다시 돌리면 따라 바뀐다
  const [count, setCount] = useState(null);
  useEffect(() => {
    const set = (r) => setCount(r ? r.doctor.bad + r.doctor.warn : null);
    loadStatus(project).then(set);
    return onStatus((p, r) => p === project && set(r));
  }, [project]);
  return (
    <nav className="nav">
      {ITEMS.map(([seg, label]) => (
        <Link key={seg} href={`${base}/${seg}`} className={here.startsWith(`${base}/${seg}`) ? "on" : ""}>
          {label}
          {seg === "doctor" && count > 0 && <span className="nav-count" aria-label={`확인 필요 ${count}건`}>{count}</span>}
        </Link>
      ))}
    </nav>
  );
}
