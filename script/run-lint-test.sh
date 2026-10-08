#!/usr/bin/env bash
# 검증 일괄. 하나라도 실패하면 0이 아닌 종료 코드.
#
#   script/run-lint-test.sh [--commit] [--no-cache]
#     --commit    커밋 전 검증 — on = "push" 단계를 뺀다. 없으면 전부 (pre-push 훅 · CI)
#     --no-cache  통과 기록을 보지 않고 전부 다시 돈다
#
# **하네스 검사와 프로젝트 검증을 나눈다.** 위쪽은 어느 리포에서나 같고, 아래쪽은 harness.toml 의
# [commands]·[verify] 에서 생성되는 `script/harness-verify.sh` 다. 언제 무엇을 돌릴지는 거기서 정한다.
set -euo pipefail
# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# 실행 지표 — 이 스크립트 한 번을 스팬으로 남긴다(script/metric.py). 출력·종료 코드는 그대로다
[ "${HARNESS_METRIC_SELF:-}" = run-lint-test ] || [ ! -x script/metric.py ] || \
  exec env HARNESS_METRIC_SELF=run-lint-test script/metric.py wrap --name run-lint-test --kind script --attr script=run-lint-test -- "$PWD/script/run-lint-test.sh" "$@"

# 1) 생성물이 설정과 일치하는가. 어긋나면 훅·권한·에이전트 정의가 설정과 다른 것을 강제한다.
for cli in .harness/bin/harness src/bin/harness; do
  if [ -x "$cli" ]; then
    "$cli" check || exit 1
    break
  fi
done

# 2) 검증 단계 — 하네스 스크립트 회귀 테스트, 계층 의존 규칙·코드 검사·테스트.
#    손으로 쓴 옛 검증 스크립트(script/verify-project.sh)가 있으면 그것을 대신 돈다 — 설정으로 옮기면 지운다.
old=script/verify-project.sh
if [ -f "$old" ] && ! grep -q "verify-project: not filled in yet" "$old"; then
  bash "$old" || exit 1
else
  script/harness-verify.sh "$@" || exit 1
fi
