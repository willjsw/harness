import { NONE, UNKNOWN } from "./fields.js";

// 오류 코드. UI 와 모델 검사가 같은 표를 쓴다.
export const CODES = {
  E_EMPTY: "비어 있는 입력값이 있습니다. 내용을 적어 주세요.",
  E_NO_CONTENT: "내용을 알아볼 수 없습니다. TBD·??? 같은 자리표시자 대신 실제 내용을 적어 주세요.",
  E_MEANINGLESS: "이 질문과 관련된 내용으로 보이지 않습니다. 조금 더 구체적으로 적어 주세요.",
  E_CHECK_FAILED: "AI 검사를 실행하지 못했습니다. 잠시 뒤 다시 시도해 주세요.",
  E_VALUE: "실제 값처럼 보입니다. 값은 적지 말고, 변수 이름과 얻는 곳만 적어 주세요.",
};

const PLACEHOLDER = /^(tbd|todo|tba|n\/?a|x+|-+|\.+|\?+|test|asdf|qwer|ㅁㄴㅇㄹ|ㅇㅇ+|ㅋ+|ㅎ+|모름|몰라|아무거나)$/i;

// 정적 검사. 모델을 부르기 전에 공짜로 걸러낼 수 있는 것만 본다.
// "없음" 은 유효한 답이다 — 인접 모듈이 없는 리포도 있다. "모름" 은 그 항목이 받을 때만 된다.
// fields 는 키 문자열이거나 fieldsOf() 의 항목이다. 목록 값은 줄마다 본다.
export function staticCheck(values, fields) {
  const errors = {};
  for (const f of fields.map((x) => (typeof x === "string" ? { k: x } : x))) {
    const v = values[f.k];
    const rows = (Array.isArray(v) ? v : [v ?? ""]).map((r) => String(r).trim()).filter(Boolean);
    if (!rows.length) { if (!f.advanced) errors[f.k] = "E_EMPTY"; continue; }
    for (const r of rows) {
      const e = rowError(r, f);
      if (e) { errors[f.k] = e; break; }
    }
  }
  return errors;
}

function rowError(v, f) {
  if (v === UNKNOWN && (f.unknown || f.advanced)) return null;
  // ponytail: KEY=값 · KEY: 값 모양만 잡는다. 이름 없이 붙여 넣은 토큰까지 잡으려면 엔트로피 검사를 더한다
  if (f.noValues && /\b[A-Z][A-Z0-9_]{2,}\s*[=:]\s*\S/.test(v)) return "E_VALUE";
  if (!/[\p{L}]/u.test(v) || PLACEHOLDER.test(v) || /^(.)\1{2,}$/u.test(v)) return "E_NO_CONTENT";
  return null;
}

// 모델에 물을 만한 값인가 — 비었거나 "없음"·"모름" 이면 판정할 내용이 없다.
export const answered = (v) => {
  const rows = (Array.isArray(v) ? v : [v ?? ""]).map((r) => String(r).trim()).filter(Boolean);
  return rows.length > 0 && !rows.every((r) => r === NONE || r === UNKNOWN);
};

// 프롬프트에 넣는 한 줄. 목록은 " / " 로 잇는다.
export const asText = (v) => (Array.isArray(v) ? v : [v ?? ""]).map((r) => String(r).trim()).filter(Boolean).join(" / ");

// 모델 출력에서 판정 JSON 을 꺼낸다. 앞뒤 설명이나 코드 펜스가 붙어 와도 읽는다.
export function parseVerdict(text, keys) {
  const m = text.match(/\{[\s\S]*\}/);
  if (!m) return null;
  let obj;
  try { obj = JSON.parse(m[0]); } catch { return null; }
  const errors = {};
  for (const k of keys) if (obj[k] && obj[k] !== "ok") errors[k] = "E_MEANINGLESS";
  return errors;
}
