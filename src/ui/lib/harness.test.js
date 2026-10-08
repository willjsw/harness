import { test } from "node:test";
import assert from "node:assert/strict";
import { parseProjects } from "./harness.js";

test("parseProjects 는 클론 등록을 키 · 이름 · 경로 · ok 로 옮긴다", () => {
  const out = parseProjects({
    projects: [
      { key: "c-0123456789abcdef", name: "demo", path: "/w/a/demo", ok: true },
      { key: "c-fedcba9876543210", name: "demo", path: "/w/b/demo", ok: true },
    ],
    legacy: [],
  });
  assert.deepEqual(out, [
    { key: "c-0123456789abcdef", name: "demo", path: "/w/a/demo", ok: true },
    { key: "c-fedcba9876543210", name: "demo", path: "/w/b/demo", ok: true },
  ]);
});

test("parseProjects 는 옛 이름 등록을 키 없이 재설치 필요 항목으로 붙인다", () => {
  const out = parseProjects({
    projects: [{ key: "c-0123456789abcdef", name: "demo", path: "/w/a/demo", ok: true }],
    legacy: [{ name: "old-demo", path: null }, { name: "older", path: "/w/older" }],
  });
  assert.deepEqual(out.slice(1), [
    { key: null, name: "old-demo", path: null, ok: false, legacy: true },
    { key: null, name: "older", path: "/w/older", ok: false, legacy: true },
  ]);
});

test("parseProjects 는 경로 없는 클론 등록을 ok 로 두지 않는다", () => {
  const out = parseProjects({ projects: [{ key: "c-0123456789abcdef", name: "c-0123456789abcdef", path: null, ok: false }], legacy: [] });
  assert.deepEqual(out, [{ key: "c-0123456789abcdef", name: "c-0123456789abcdef", path: null, ok: false }]);
});

test("parseProjects 는 형식이 아닌 입력에 빈 목록을 돌려준다", () => {
  for (const bad of [[], "x", null, undefined, 1, {}, { projects: [] }, { legacy: [] }, { projects: {}, legacy: [] }, { projects: [], legacy: "x" }])
    assert.deepEqual(parseProjects(bad), [], JSON.stringify(bad));
});

test("parseProjects 는 키나 이름이 없는 항목을 빼고 나머지를 옮긴다", () => {
  const out = parseProjects({
    projects: [null, "x", { name: "no-key", path: "/w/x", ok: true }, { key: "c-0123456789abcdef", path: "/w/y", ok: true },
      { key: "c-fedcba9876543210", name: "kept", path: "/w/z", ok: true }],
    legacy: [{ path: "/w/no-name" }, { name: "", path: null }, { name: "old", path: 1 }],
  });
  assert.deepEqual(out, [
    { key: "c-fedcba9876543210", name: "kept", path: "/w/z", ok: true },
    { key: null, name: "old", path: null, ok: false, legacy: true },
  ]);
});
