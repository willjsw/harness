#!/usr/bin/env bash
# 이 파일은 harness.toml 에서 생성된다. 직접 고치지 않는다 —
# 값은 harness.toml 이 갖고, `harness render` 가 이 파일을 다시 만든다.
# 프로젝트 검증 — harness.toml 의 [verify] 검사, commands.format_check, commands.test 를 차례로 돈다.
# `script/run-lint-test.sh` 가 부른다. 단계마다 이름을 찍고, 실패하면 그 이름으로 멈춘다.
# 종료 코드: 0 통과 · 1 실패 · 3 아직 명령을 정하지 않았다
set -uo pipefail
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# 직접 불러도 단계들이 한 실행 아래에 모이게 자기 한 번을 스팬으로 감싼다
[ "${HARNESS_METRIC_SELF:-}" = harness-verify ] || [ ! -x script/metric.py ] || \
  exec env HARNESS_METRIC_SELF=harness-verify script/metric.py wrap --name harness-verify --kind script --attr script=harness-verify -- "$PWD/script/harness-verify.sh" "$@"

# 단계마다 실행 지표를 남긴다(script/metric.py). 기록기가 없으면 그냥 돈다
step() {
  echo "verify: $1"
  if [ -x script/metric.py ]; then
    script/metric.py wrap --name "verify/$1" --kind script --attr script=harness-verify -- bash -c "$2"
  else
    bash -c "$2"
  fi || { echo "verify: FAIL $1" >&2; exit 1; }
}

step 'CLI 가 컴파일된다' 'python3 -m py_compile src/bin/harness'
step 'UI 단위 테스트' 'cd src/ui && node --test lib/*.test.js'
step '테스트' src/test/render-test.sh
echo "verify: ok"
