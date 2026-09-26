import { test } from "node:test";
import assert from "node:assert/strict";
import { fmtTokens, fmtMs, stackedBars, hbars, waterfall, seriesColor } from "./charts.js";

test("formats", () => {
  assert.equal(fmtTokens(0), "0");
  assert.equal(fmtTokens(1234), "1.2k");
  assert.equal(fmtTokens(56000), "56k");
  assert.equal(fmtTokens(2500000), "2.5M");
  assert.equal(fmtMs(850), "850ms");
  assert.equal(fmtMs(12500), "13s");
  assert.equal(fmtMs(125000), "2m 5s");
  assert.equal(fmtMs(3900000), "1h 5m");
  assert.equal(seriesColor("claude/x"), seriesColor("claude/x"));
});

test("stackedBars", () => {
  const { keys, max, bars } = stackedBars([{ day: "d1", by: { a: 30, b: 10 } }, { day: "d2", by: { a: 20 } }], { width: 100, height: 40, gap: 0 });
  assert.deepEqual(keys, ["a", "b"]);
  assert.equal(max, 40);
  assert.equal(bars[0].w, 50);
  assert.equal(bars[1].x, 50);
  assert.deepEqual(bars[0].parts.map((p) => [p.key, p.h]), [["a", 30], ["b", 10]]);
  assert.equal(bars[0].parts[1].y, 0);          // 가장 큰 막대가 꼭대기까지
  assert.equal(bars[1].total, 20);
});

test("hbars", () => {
  assert.deepEqual(hbars([{ t: 5 }, { t: 10 }], (r) => r.t).map((r) => r.frac), [0.5, 1]);
});

test("waterfall", () => {
  const { rows, total } = waterfall([
    { span: "b", parent: "a", offset_ms: 100, dur_ms: 400 },
    { span: "a", parent: null, offset_ms: 0, dur_ms: 1000 },
    { span: "c", parent: "gone", offset_ms: 600, dur_ms: 100 },   // 부모가 목록에 없으면 뿌리로
  ]);
  assert.equal(total, 1000);
  assert.deepEqual(rows.map((r) => [r.span, r.depth]), [["a", 0], ["b", 1], ["c", 0]]);
  assert.equal(rows[1].left, 0.1);
  assert.equal(rows[1].width, 0.4);
});
