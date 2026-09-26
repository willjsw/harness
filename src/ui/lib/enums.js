// 값이 정해진 설정의 선택지. 에이전트(오케스트레이터·러너)는 여기 두지 않는다 — `harness schema` 의 등록부가 준다.
// 값은 설정 파일에 들어가는 그대로, 이름은 화면에 보이는 정식 명칭이다.
// 허용 여부의 정본은 CLI 의 validate() 다 — 여기 없는 값을 고르게 두지 않을 뿐, 검증은 CLI 가 한다.
// 값을 더하면 `bin/harness` 의 검사와 `harness.toml` 의 주석도 함께 고친다.
const GITLAB = ["gitlab", "GitLab"], GITHUB = ["github", "GitHub"];

const ENUMS = {
  "commit.issue_ref": [["suffix", "Suffix"], ["prefix", "Prefix"]],
  "forge.tracker": [GITLAB, GITHUB, ["jira", "Jira"]],
  "forge.review_host": [GITLAB, GITHUB],
  "adr.style": [["nygard", "Nygard"], ["madr", "MADR"], ["none", "None"]],
  "adr.tool": [["adr-tools", "adr-tools"], ["adrs", "adrs"], ["manual", "Manual"], ["none", "None"]],
  "metrics.capture_logs": [["errors", "Errors only"], ["off", "Off"]],
  "roles.*.access": [["read-only", "Read-only"], ["write", "Write"]],
};

export function enumFor(key) {
  return ENUMS[key] ?? ENUMS[key.replace(/^roles\.[^.]+\./, "roles.*.")] ?? null;
}
