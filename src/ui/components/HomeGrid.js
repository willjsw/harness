"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { projectStatus } from "@/lib/actions";
import { AgentLogo } from "@/components/Agent";
import { avatarStyle } from "@/lib/avatar";
import NewProject from "@/components/NewProject";

const ago = (iso) => {
  if (!iso) return "";
  const s = (new Date(iso) - Date.now()) / 1000, rtf = new Intl.RelativeTimeFormat("ko", { numeric: "auto" });
  for (const [u, n] of [["year", 31536000], ["month", 2592000], ["day", 86400], ["hour", 3600], ["minute", 60]])
    if (Math.abs(s) >= n) return rtf.format(Math.round(s / n), u);
  return "방금";
};
const newer = (a, b) => a && b && a.localeCompare(b, undefined, { numeric: true }) > 0;

export default function HomeGrid({ projects, global, labels }) {
  const [status, setStatus] = useState({});
  const load = (name) => projectStatus(name).then((st) => setStatus((s) => ({ ...s, [name]: st ?? false })));
  useEffect(() => { projects.filter((p) => p.ok).forEach((p) => load(p.name)); }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return (
      <div className="project-grid">
        {projects.map((p) => {
          if (!p.ok) return (
            <div key={p.name} className="project-card off" title="경로가 기록되지 않은 옛 설치다">
              <div className="pc-head"><span className="avatar big" style={avatarStyle(p.name)}>{p.name[0]?.toUpperCase()}</span><b className="grow">{p.name}</b><span className="tag-sm warn">재설치 필요</span></div>
            </div>
          );
          const st = status[p.name];
          return (
            <Link key={p.name} href={`/${encodeURIComponent(p.name)}/settings`} className="project-card">
              <div className="pc-head">
                <span className="avatar big" style={avatarStyle(p.name)}>{p.name[0]?.toUpperCase()}</span>
                <b className="grow">{p.name}</b>
              </div>
              <div className="pc-state">
                {st === undefined && <span className="tag-sm pulse">상태 읽는 중</span>}
                {st === false && <span className="tag-sm">상태를 읽지 못했다 — 옛 버전</span>}
                {st && <>
                  <span className={`tag-sm ${st.doctor.bad ? "bad" : st.doctor.warn ? "warn" : "okc"}`}>
                    {[st.doctor.bad && `FAIL ${st.doctor.bad}`, st.doctor.warn && `WARN ${st.doctor.warn}`].filter(Boolean).join(" · ") || "준비됨"}
                  </span>
                  {!st.check_ok && <span className="tag-sm bad">생성물 불일치</span>}
                  {newer(global, st.version) && <span className="tag-sm warn">v{global} 가능</span>}
                </>}
              </div>
              <div className="pc-foot">
                <span className="runner-tag"><AgentLogo id={p.orchestrator} name={p.orchestratorName} />{p.orchestratorName}</span>
                {/* 소스 코드 저장소(리뷰 호스트)만 보인다. 이슈 트래커는 설정 화면에서 본다 */}
                {p.forge && <span className="tag-sm" title="소스 코드 저장소">{labels[p.forge.review_host] ?? p.forge.review_host}</span>}
                {st?.version && <span className="tag-sm mono">v{st.version}</span>}
                {st?.git.branch && (
                  <span className="tag-sm mono git" title={st.git.dirty ? "커밋하지 않은 변경이 있다" : "작업 트리가 깨끗하다"}>
                    {st.git.branch}{st.git.dirty && <i className="dirty" aria-label="미커밋 변경" />}{st.git.last_commit && ` · ${ago(st.git.last_commit)}`}
                  </span>
                )}
              </div>
            </Link>
          );
        })}
      <NewProject />
      </div>
  );
}
