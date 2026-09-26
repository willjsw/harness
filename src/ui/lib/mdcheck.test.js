import { test } from "node:test";
import assert from "node:assert/strict";
import { staticIssues, parseIssues } from "./mdcheck.js";

test("staticIssues", () => {
  const t = ["# 제목", "##붙은 제목", "깨진 � 글자", "모지바케 ì\u0095\u0088", "```bash", "echo"].join("\n");
  assert.deepEqual(staticIssues(t).map((x) => [x.line, x.type]), [[2, "markdown"], [3, "broken"], [4, "broken"], [5, "markdown"]]);
  assert.deepEqual(staticIssues("# 정상\n\n```\ncode\n```\n"), []);
  assert.deepEqual(staticIssues("#123 이슈 번호로 시작"), []);
});

test("parseIssues", () => {
  assert.deepEqual(parseIssues('```json\n{"issues":[{"line":2,"type":"spelling","text":"됬다","fix":"됐다"},{"line":"x","type":"spelling"}]}\n```'),
    [{ line: 2, type: "spelling", text: "됬다", fix: "됐다" }]);
  assert.deepEqual(parseIssues('{"issues":[]}'), []);
  assert.equal(parseIssues("nope"), null);
});
