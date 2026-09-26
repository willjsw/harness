import { projectStatus } from "./actions";

// 프로젝트 상태(`harness status`)를 브라우저 세션 동안 한 번만 돌린다. doctor 는 검증까지 돌려 수 초가 걸린다 —
// 사이드바 건수와 Doctor 화면이 같은 결과를 나눠 쓴다. fresh 면 다시 돌리고, 구독자에게 알린다.
const cache = new Map();
const subs = new Set();

export function loadStatus(project, fresh = false) {
  if (fresh || !cache.has(project)) {
    const p = projectStatus(project).then((r) => r ?? null, () => null);
    cache.set(project, p);
    p.then((r) => subs.forEach((f) => f(project, r)));
  }
  return cache.get(project);
}

export function onStatus(f) {
  subs.add(f);
  return () => subs.delete(f);
}
