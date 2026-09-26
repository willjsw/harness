import { test } from "node:test";
import assert from "node:assert/strict";
import { pathProblem, dirProblem } from "./paths.js";

test("pathProblem", () => {
  const list = [".ai/project/scope.md", "docs/spec/"];
  for (const ok of ["docs/a.md", "docs/adr/", "docs/adr/**", "README.md", ".github/x.yml"]) assert.equal(pathProblem(ok, list), null, ok);
  for (const bad of ["", "/etc/passwd", "../x.md", "docs/../x", "docs/a b.md", "docs//x.md", "docs/*.md", ".ai/project/scope.md", "docs/spec/x.md"])
    assert.notEqual(pathProblem(bad, list), null, bad);
});

test("dirProblem", () => {
  for (const ok of ["docs/adr", "docs/adr/", "adr"]) assert.equal(dirProblem(ok), null, ok);
  for (const bad of ["", "/abs", "../x", "docs/**", "a b"]) assert.notEqual(dirProblem(bad), null, bad);
});
