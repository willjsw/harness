import MetricsView from "@/components/MetricsView";

export default async function Metrics({ params }) {
  const { project } = await params;
  return (
    <>
      <header className="page-head">
        <h1>Metrics</h1>
        <p className="page-intro"><span>이 프로젝트에서 돈 명령·워크플로 단계·에이전트·스크립트의 토큰과 실행 시간을 봅니다.</span></p>
      </header>
      <MetricsView project={decodeURIComponent(project)} />
    </>
  );
}
