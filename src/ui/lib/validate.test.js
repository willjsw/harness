import { test } from "node:test";
import assert from "node:assert/strict";
import { staticCheck, parseVerdict, answered, asText } from "./validate.js";

test("staticCheck", () => {
  const e = staticCheck(
    { a: "", b: "결재 문서를 올리고 승인받는 서비스. ".repeat(4), c: "TBD", d: "...", e: "ㅋㅋㅋ", f: "없음", g: "결재".repeat(25), h: "npm test" },
    ["a", "b", "c", "d", "e", "f", "g", "h", "missing"],
  );
  assert.deepEqual(e, { a: "E_EMPTY", c: "E_NO_CONTENT", d: "E_NO_CONTENT", e: "E_NO_CONTENT", missing: "E_EMPTY" });
});

test("staticCheck with field options", () => {
  const f = [
    { k: "list", list: true }, { k: "unk", unknown: true }, { k: "noUnk" },
    { k: "adv", advanced: true }, { k: "badRow", list: true }, { k: "emptyList", list: true },
  ];
  const e = staticCheck({ list: ["결재 요청", " ", "승인"], unk: "모름", noUnk: "모름", badRow: ["조회", "TBD"], emptyList: ["", " "] }, f);
  assert.deepEqual(e, { noUnk: "E_NO_CONTENT", badRow: "E_NO_CONTENT", emptyList: "E_EMPTY" });
  assert.deepEqual(staticCheck({ adv: "모름" }, [{ k: "adv", advanced: true }]), {});
});

test("staticCheck refuses values in a no-values field", () => {
  const f = [{ k: "env", list: true, noValues: true }];
  assert.deepEqual(staticCheck({ env: ["DATABASE_URL — 1Password 개발 볼트"] }, f), {});
  assert.deepEqual(staticCheck({ env: ["DATABASE_URL=postgres://u:p@h/db"] }, f), { env: "E_VALUE" });
  assert.deepEqual(staticCheck({ env: ["API_KEY: sk-abc"] }, f), { env: "E_VALUE" });
});

test("answered / asText", () => {
  assert.equal(answered(["없음"]), false);
  assert.equal(answered("모름"), false);
  assert.equal(answered(["", "승인"]), true);
  assert.equal(asText(["결재 요청", " ", "승인"]), "결재 요청 / 승인");
});

test("parseVerdict", () => {
  assert.deepEqual(parseVerdict('판정:\n```json\n{"a":"ok","b":"meaningless"}\n```', ["a", "b"]), { b: "E_MEANINGLESS" });
  assert.equal(parseVerdict("no json", ["a"]), null);
});
