#!/usr/bin/env bash
# 검증 일괄. 하나라도 실패하면 0이 아닌 종료 코드.
# 커밋 전 수동 실행, post-commit 훅에서 1회 자동 실행, CI 에서 실행.
#
# **하네스 검사와 프로젝트 검증을 나눈다.** 위쪽은 어느 리포에서나 같고, 아래쪽은
# 프로젝트가 harness.toml 의 [commands]·[verify] 에 적은 명령이다.
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

# 2) 셸 회귀 테스트. 셸은 어느 포맷터도 보지 않으므로 여기서 돈다.
#    가드와 루프 제어는 조용히 망가져도 통과만 하므로 검사 없이는 고장을 알 수 없다.
#    원격도 리뷰 도구도 부르지 않는다 — 성공하면 마지막 줄만 남긴다.
for t in script/test-review-loop.sh script/test-carryover-issue.sh \
         script/test-sync-task-issues.sh script/test-rollback-work.sh \
         script/test-secret-scan.sh script/test-bash-guard.sh script/test-usage-log.sh; do
  [ -x "$t" ] || continue
  log=$(mktemp)
  if ! "$t" > "$log" 2>&1; then
    cat "$log" >&2
    rm -f "$log"
    exit 1
  fi
  tail -1 "$log"
  rm -f "$log"
done

# 3) 프로젝트 검증 — 계층 의존 규칙·코드 검사·테스트. 명령은 harness.toml 의 [verify]·[commands] 가 갖고,
#    `script/harness-verify.sh` 가 그것으로 생성된다.
#    손으로 쓴 옛 검증 스크립트(script/verify-project.sh)가 있으면 그것을 대신 돈다 — 설정으로 옮기면 지운다.
old=script/verify-project.sh
if [ -f "$old" ] && ! grep -q "verify-project: not filled in yet" "$old"; then
  bash "$old" || exit 1
else
  script/harness-verify.sh || exit 1
fi
