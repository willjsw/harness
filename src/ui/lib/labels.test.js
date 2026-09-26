import { test } from "node:test";
import assert from "node:assert/strict";
import { settingTitle, commitSubject } from "./labels.js";

test("settingTitle", () => {
  assert.equal(settingTitle("default_assignee"), "Default Assignee");
  assert.equal(settingTitle("mr"), "Merge Request");
  assert.equal(settingTitle("adr"), "ADR");
  assert.equal(settingTitle("log_path"), "Log Path");
});

test("commitSubject", () => {
  assert.equal(commitSubject({ ref: "suffix", key: "", tag: "chore", summary: "Project init", issue: 1 }), "chore: Project init(#1)");
  assert.equal(commitSubject({ ref: "prefix", key: "DEV", tag: "chore", summary: "Project init", issue: 1 }), "[DEV-1] chore: Project init");
});
