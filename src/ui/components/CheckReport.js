"use client";
import { TYPES } from "@/lib/mdcheck";

// 저장 전 검사 결과. 막을지 말지는 사람이 정한다 — 검사는 판정이 아니라 제안이다.
export default function CheckReport({ result, onSave, onCancel, pending }) {
  const { issues, failed, where } = result;
  return (
    <div className="check">
      <div className="check-head">
        {issues.length ? <b>검사에서 {issues.length}건을 찾았다</b> : <b>검사를 끝내지 못했다</b>}
        {failed && issues.length > 0 && <span className="muted small">모델 검사는 실패해 정적 검사 결과만 보인다</span>}
        {failed && !issues.length && <span className="muted small"><code>E_CHECK_FAILED</code> 모델을 부르지 못했다</span>}
      </div>
      {issues.length > 0 && (
        <ul className="check-list">
          {issues.map((x, i) => (
            <li key={i}>
              <span className={`ctype t-${x.type}`}>{TYPES[x.type]}</span>
              <div>
                <div className="cline">{where ? where(x.line) : `${x.line}행`}</div>
                <div><code>{x.text}</code>{x.fix && <> → {x.fix}</>}</div>
              </div>
            </li>
          ))}
        </ul>
      )}
      <div className="row end">
        <button className="btn" onClick={onCancel}>Go Back & Fix</button>
        <button className="btn primary" aria-busy={pending} disabled={pending} onClick={onSave}>{pending ? "Saving…" : "Save Anyway"}</button>
      </div>
    </div>
  );
}
