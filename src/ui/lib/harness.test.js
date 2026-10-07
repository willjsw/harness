import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

const home = await fs.mkdtemp(path.join(os.tmpdir(), "harness-ui-home-"));
process.env.HARNESS_HOME = home;
const { registeredPath, listProjects } = await import("./harness.js");

test("registeredPath 는 비어 있지 않은 문자열만 경로로 유지한다", () => {
  assert.equal(registeredPath({ path: "/some/repo" }), "/some/repo");
  for (const bad of [{ path: 1 }, { path: {} }, { path: [] }, { path: "" }, { path: null }, { path: true }, {}, [], null, 1, "x"])
    assert.equal(registeredPath(bad), null, JSON.stringify(bad));
});

test("listProjects 는 비문자열·빈 path 등록을 예외 없이 재설치 필요 항목으로 남긴다", async (t) => {
  t.after(() => fs.rm(home, { recursive: true, force: true }));
  const repo = await fs.mkdtemp(path.join(os.tmpdir(), "harness-ui-repo-"));
  t.after(() => fs.rm(repo, { recursive: true, force: true }));
  await fs.writeFile(path.join(repo, "harness.toml"), "");
  const regs = { a_num: { path: 1 }, b_obj: { path: {} }, c_empty: { path: "" }, d_ok: { path: repo } };
  for (const [name, data] of Object.entries(regs)) {
    await fs.mkdir(path.join(home, name));
    await fs.writeFile(path.join(home, name, "project.json"), JSON.stringify(data));
  }
  assert.deepEqual(await listProjects(), [
    { name: "a_num", path: null, ok: false },
    { name: "b_obj", path: null, ok: false },
    { name: "c_empty", path: null, ok: false },
    { name: "d_ok", path: repo, ok: true },
  ]);
});
