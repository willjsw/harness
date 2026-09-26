// 프로젝트 머리글자 아이콘의 색. 이름으로 고른다 — 홈 카드와 사이드바 전환기가 같은 색을 쓴다.
// 파랑·청록·초록 계열이되, 강조색(#63ad58 계열 황록)과는 겹치지 않게 골랐다. 글자는 모두 흰색.
// 이웃한 색이 다른 계열이 되게 파랑·청록·초록을 번갈아 둔다 — 해시가 가까운 이름끼리도 구분된다.
const PALETTE = [
  "#0b68cb", "#0d9488", "#3e63dd", "#10a37f", "#0090ff", "#177e89", "#4f46e5", "#1f8aa8",
  "#12a594", "#205d9e", "#2a9d8f", "#5b7fe0", "#1f7a5c", "#00a2c7", "#3a8f7a", "#0e7490",
];

export function avatarStyle(name) {
  let h = 0;
  for (const ch of name) h = (h * 31 + ch.codePointAt(0)) >>> 0;
  return { background: PALETTE[h % PALETTE.length], color: "#fff" };
}
