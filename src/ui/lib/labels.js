// 설정 키를 화면 이름으로: `default_assignee` → `Default Assignee`. 줄임말은 정식 이름으로 바꾼다.
const NAMES = { adr: "ADR", mr: "Merge Request", dir: "Directory", env_var: "Environment Variable" };

export const settingTitle = (key) =>
  NAMES[key] ?? key.split("_").map((w) => NAMES[w] ?? w[0].toUpperCase() + w.slice(1)).join(" ");

// 커밋 제목의 이슈 참조. `bin/harness` derive() 의 subject_example 과 같은 모양이다.
export function commitSubject({ ref, key, tag, summary, issue }) {
  return ref === "prefix" ? `[${key || "DEV"}-${issue}] ${tag}: ${summary}` : `${tag}: ${summary}(#${issue})`;
}
