// Metrics 탭 차트의 좌표 계산. 그리기(SVG)와 나눠 두어 숫자만으로 검사한다. 의존성 없이 직접 그린다.

// 막대 위 숫자·요약 카드의 짧은 표기
export function fmtTokens(n) {
  if (!n) return "0";
  if (n >= 1e6) return `${(n / 1e6).toFixed(n >= 1e7 ? 0 : 1)}M`;
  if (n >= 1e3) return `${(n / 1e3).toFixed(n >= 1e4 ? 0 : 1)}k`;
  return String(n);
}

export function fmtMs(ms) {
  if (ms == null) return "—";
  if (ms < 1000) return `${ms}ms`;
  const s = ms / 1000;
  if (s < 60) return `${s.toFixed(s < 10 ? 1 : 0)}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ${Math.round(s % 60)}s`;
  return `${Math.floor(m / 60)}h ${m % 60}m`;
}

// 계열(벤더/모델) 색. 이름으로 고른다 — 같은 모델은 어느 차트에서나 같은 색이다
const SERIES = ["#3e8ed0", "#12a594", "#8e6fd8", "#d08a3e", "#d0567a", "#5aa9c4", "#7f9c3a", "#b0776a"];
export function seriesColor(key) {
  let h = 0;
  for (const ch of key) h = (h * 31 + ch.codePointAt(0)) >>> 0;
  return SERIES[h % SERIES.length];
}

// 일별 누적 막대. daily = [{ day, by: { 계열: 토큰 } }] → 막대마다 조각의 y·높이(차트 좌표)
export function stackedBars(daily, { width, height, gap = 6 }) {
  const keys = [...new Set(daily.flatMap((d) => Object.keys(d.by)))].sort();
  const max = Math.max(1, ...daily.map((d) => Object.values(d.by).reduce((a, b) => a + b, 0)));
  const bw = daily.length ? Math.max(2, (width - gap * (daily.length - 1)) / daily.length) : 0;
  const bars = daily.map((d, i) => {
    let y = height;
    const parts = keys.filter((k) => d.by[k]).map((k) => {
      const h = (d.by[k] / max) * height;
      y -= h;
      return { key: k, value: d.by[k], y, h };
    });
    return { day: d.day, x: i * (bw + gap), w: bw, total: parts.reduce((a, p) => a + p.value, 0), parts };
  });
  return { keys, max, bars };
}

// 가로 막대 — 가장 큰 값이 전체 폭
export function hbars(rows, value) {
  const max = Math.max(1, ...rows.map(value));
  return rows.map((r) => ({ ...r, frac: value(r) / max }));
}

// 워터폴 — 스팬을 부모 아래로 깊이를 매겨 시간순으로 펴고, 시간축의 비율로 놓는다
export function waterfall(spans) {
  if (!spans?.length) return { rows: [], total: 0 };
  const total = Math.max(1, ...spans.map((s) => s.offset_ms + Math.max(0, s.dur_ms)));
  const byParent = {};
  const ids = new Set(spans.map((s) => s.span));
  for (const s of spans) (byParent[s.parent && ids.has(s.parent) ? s.parent : ""] ??= []).push(s);
  const rows = [];
  const walk = (pid, depth) => {
    for (const s of (byParent[pid] ?? []).sort((a, b) => a.offset_ms - b.offset_ms)) {
      rows.push({ ...s, depth, left: s.offset_ms / total, width: Math.max(0.004, Math.max(0, s.dur_ms) / total) });
      walk(s.span, depth + 1);
    }
  };
  walk("", 0);
  return { rows, total };
}
