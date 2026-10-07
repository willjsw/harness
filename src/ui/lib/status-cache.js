import { projectStatus } from "./actions";

// 프로젝트 상태(`harness status`)를 브라우저 세션 동안 한 번만 돌린다. doctor 는 검증까지 돌려 수 초가 걸린다 —
// 사이드바 건수와 Doctor 화면이 같은 결과를 나눠 쓴다. fresh 면 다시 돌리고, 구독자에게 알린다.
// remote 면 원격 준비 점검까지 언제나 새로 돌린다. 캐시는 그 프로젝트의 마지막 결과 하나다 —
// 원격 점검이 결과를 내지 못하면(null) 이전 결과를 그대로 두고, 부른 쪽에는 null 을 돌려준다.
const cache = new Map();
const subs = new Set();

export function loadStatus(project, fresh = false, remote = false) {
  if (remote || fresh || !cache.has(project)) {
    const prev = cache.get(project);
    const p = projectStatus(project, remote).then((r) => r ?? null, () => null);
    const kept = remote && prev ? p.then((r) => r ?? prev) : p;
    cache.set(project, kept);
    kept.then((r) => subs.forEach((f) => f(project, r)));
    if (remote) return p;
  }
  return cache.get(project);
}

export function onStatus(f) {
  subs.add(f);
  return () => subs.delete(f);
}
