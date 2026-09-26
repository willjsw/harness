import { globalVersion } from "@/lib/harness";
import DoctorView from "@/components/DoctorView";

export default async function Doctor({ params }) {
  const { project } = await params;
  return (
    <>
      <header className="page-head">
        <h1>Doctor</h1>
        <p className="page-intro"><span>프로젝트에서 하네스를 사용할 준비가 되었는지 점검합니다.</span></p>
      </header>
      <DoctorView project={decodeURIComponent(project)} global={await globalVersion()} />
    </>
  );
}
