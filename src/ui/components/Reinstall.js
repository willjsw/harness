// 프로젝트에 고정된 하네스 사본이 이 화면의 명령(write-doc · fix)이나 경로를 모를 때의 안내.
// 사본을 다시 깔면 올라간다 — 설정과 프로젝트 문서는 그대로다.
export default function Reinstall({ path, what, compact }) {
  const cmd = path ? `cd ${path} && harness install` : "harness install";
  if (compact) return <p className="notice warn">이 프로젝트의 하네스가 오래돼 {what}할 수 없습니다. 다시 설치합니다: <code>{cmd}</code></p>;
  return (
    <div className="empty">
      <h1>이 프로젝트의 하네스는 {what}할 수 없다</h1>
      <p>고정된 하네스가 이 기능 이전 버전이다. 그 프로젝트에서 다시 설치하면 올라간다 — 설정과 프로젝트 문서는 그대로다.</p>
      <pre>{cmd}</pre>
    </div>
  );
}
