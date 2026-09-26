// 보호 문서 경로. 정본은 `bin/harness` 의 BASE_PROTECTED·PROTECTED_PATH 다 — 여기는 추가 전에 미리 걸러 보일 뿐,
// 저장할 때 CLI 가 같은 검사를 다시 한다. 한쪽을 고치면 다른 쪽도 고친다.
export const BASE_PROTECTED = [".ai/project/scope.md", ".ai/project/architecture.md", ".ai/project/glossary.md", ".ai/project/testing.md", ".ai/project/roles/"];

const PATH = /^(?!\/)(?!.*(^|\/)\.\.(\/|$))[\w.-]+(\/[\w.-]+)*(\/|\/\*\*)?$/;

export const isDir = (p) => p.endsWith("/") || p.endsWith("/**");

// 넣을 수 없으면 이유를, 넣을 수 있으면 null.
export function pathProblem(p, list) {
  if (!p) return "경로가 비어 있다";
  if (p.startsWith("/")) return "리포 기준 상대 경로로 쓴다 — 앞의 / 를 뺀다";
  if (/(^|\/)\.\.(\/|$)/.test(p)) return "`..` 로 리포 밖을 가리킬 수 없다";
  if (/\s/.test(p)) return "경로에 공백을 쓸 수 없다";
  if (!PATH.test(p)) return "파일(docs/x.md)이나 디렉터리(docs/spec/, docs/spec/**) 형태가 아니다";
  if (list.includes(p)) return "이미 있다";
  const covering = list.find((d) => isDir(d) && p.startsWith(d.replace(/\*\*$/, "")));
  if (covering) return `이미 ${covering} 가 덮는다`;
  return null;
}

// 디렉터리 하나(adr.dir). 같은 경로 규칙에서 `**` 만 뺀다. CLI validate() 가 같은 검사를 한다.
export function dirProblem(p) {
  if (p.endsWith("**")) return "디렉터리 하나를 적는다 — ** 는 쓰지 않는다";
  const why = pathProblem(p, []);
  return why && why.startsWith("파일(") ? "디렉터리(docs/adr) 형태가 아니다" : why;
}
