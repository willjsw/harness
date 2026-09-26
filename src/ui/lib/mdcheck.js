// 저장 전 마크다운 검사. 기계로 확실히 잡히는 것은 여기서, 나머지는 md-check 스킬이 모델로 본다.
export const TYPES = { markdown: "문법", spelling: "맞춤법", grammar: "문장", broken: "깨짐" };

export function staticIssues(text) {
  const out = [];
  const lines = text.split("\n");
  let fence = null;
  lines.forEach((ln, i) => {
    if (ln.includes("�")) out.push({ line: i + 1, type: "broken", text: "대체 문자(�)", fix: "원문을 다시 붙여 넣는다" });
    // UTF-8 을 Latin-1 로 잘못 읽으면 C1 제어 문자가 섞인다 (한국어가 "ì\u0095\u0088" 처럼 깨진다)
    else if (/[\u0080-\u009F]/.test(ln)) out.push({ line: i + 1, type: "broken", text: "인코딩이 깨진 글자", fix: "UTF-8 로 다시 저장한다" });
    if (/^\s*(```|~~~)/.test(ln)) fence = fence === null ? i + 1 : null;
    // `#123` 은 이슈 번호다 — 제목으로 보지 않는다
    if (/^#{1,6}[^#\s\d]/.test(ln)) out.push({ line: i + 1, type: "markdown", text: ln.slice(0, 40), fix: "`#` 뒤에 공백을 둔다" });
  });
  if (fence !== null) out.push({ line: fence, type: "markdown", text: "닫히지 않은 코드 블록", fix: "``` 로 닫는다" });
  return out;
}

export function numbered(text) {
  return text.split("\n").map((l, i) => `${String(i + 1).padStart(3)}| ${l}`).join("\n");
}

// 모델 출력에서 issues 를 꺼낸다. 형식이 어긋나면 null — 검사 실패로 다룬다.
export function parseIssues(out) {
  const m = out.match(/\{[\s\S]*\}/);
  if (!m) return null;
  try {
    const { issues } = JSON.parse(m[0]);
    if (!Array.isArray(issues)) return null;
    return issues.filter((x) => x && TYPES[x.type] && Number.isInteger(x.line))
      .map(({ line, type, text, fix }) => ({ line, type, text: String(text ?? ""), fix: String(fix ?? "") }));
  } catch { return null; }
}
