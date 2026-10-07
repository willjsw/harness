#!/usr/bin/env bash
# 이 파일은 harness.toml 에서 생성된다. 직접 고치지 않는다 —
# 값은 harness.toml 이 갖고, `harness render` 가 이 파일을 다시 만든다.
# 프로젝트 검증 — harness.toml 의 [verify] 가 정한 단계를 차례로 돈다. `script/run-lint-test.sh` 가 부른다.
#
#   script/harness-verify.sh [--commit] [--no-cache]
#     --commit    on = "commit" 단계만 (커밋 전). 없으면 전부 (push 전 · CI)
#     --no-cache  통과 기록을 보지 않고 전부 다시 돈다. HARNESS_VERIFY_CACHE=off 도 같다
#
# 단계마다 마지막으로 통과한 작업 트리(추적·미추적, 무시 파일 제외)의 해시를 git 공통 디렉터리에 남긴다.
# 그 뒤 바뀐 파일이 단계의 경로에 하나도 걸리지 않으면 건너뛴다. 경로가 없는 단계는 무엇이든 바뀌면 돈다.
# 기록은 트리 내용만 본다 — 도구 버전·환경 변수가 바뀌었으면 --no-cache 로 돈다. git 밖이면 기록 없이 전부 돈다.
# 종료 코드: 0 통과 · 1 실패 · 2 인자 오류 · 3 아직 명령을 정하지 않았다
set -uo pipefail
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# 직접 불러도 단계들이 한 실행 아래에 모이게 자기 한 번을 스팬으로 감싼다
[ "${HARNESS_METRIC_SELF:-}" = harness-verify ] || [ ! -x script/metric.py ] || \
  exec env HARNESS_METRIC_SELF=harness-verify script/metric.py wrap --name harness-verify --kind script --attr script=harness-verify -- "$PWD/script/harness-verify.sh" "$@"

stage=push
cache=1
for a in "$@"; do
  case "$a" in
    --commit) stage=commit ;;
    --no-cache) cache=0 ;;
    *) echo "usage: script/harness-verify.sh [--commit] [--no-cache]" >&2; exit 2 ;;
  esac
done
[ "${HARNESS_VERIFY_CACHE:-}" = off ] && cache=0

tree="" rec=""
if [ "$cache" = 1 ] && rec=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  rec="$rec/harness-verify"
  idx=$(mktemp)
  # 실제 인덱스를 건드리지 않는다 — 사본에 작업 트리를 올려 그 트리 해시만 얻는다
  cp "$(git rev-parse --path-format=absolute --git-path index)" "$idx" 2>/dev/null || rm -f "$idx"
  tree=$(GIT_INDEX_FILE="$idx" git add -A . 2>/dev/null && GIT_INDEX_FILE="$idx" git write-tree 2>/dev/null) || tree=""
  rm -f "$idx"
fi

# touches <바뀐 파일 목록> [glob ...] — 목록의 파일 하나라도 glob 에 걸리는가. glob 이 없으면 무엇이든
touches() {
  local changed="$1" f g; shift
  [ -n "$changed" ] || return 1
  [ $# -gt 0 ] || return 0
  while IFS= read -r f; do
    for g in "$@"; do
      # shellcheck disable=SC2254
      case "$f" in $g) return 0 ;; esac
    done
  done <<< "$changed"
  return 1
}

# step <이름> <commit|push> <명령> [경로 glob ...]
step() {
  local name="$1" on="$2" cmd="$3" key="" last=""; shift 3
  if [ "$stage" = commit ] && [ "$on" = push ]; then echo "verify: skip $name (push stage)"; return 0; fi
  if [ -n "$tree" ]; then
    key="$rec/$(printf '%s\n%s' "$name" "$cmd" | git hash-object --stdin)"
    last=$(cat "$key" 2>/dev/null || true)
    if [ -n "$last" ] && git cat-file -e "$last^{tree}" 2>/dev/null \
       && ! touches "$(git diff --relative --name-only "$last" "$tree")" "$@"; then
      echo "verify: skip $name (unchanged since it last passed)"
      return 0
    fi
  fi
  echo "verify: $name"
  if [ -x script/metric.py ]; then
    script/metric.py wrap --name "verify/$name" --kind script --attr script=harness-verify -- bash -c "$cmd"
  else
    bash -c "$cmd"
  fi || { echo "verify: FAIL $name" >&2; exit 1; }
  [ -z "$key" ] || { mkdir -p "$rec" && echo "$tree" > "$key"; }
}

step 'CLI 가 컴파일된다' commit 'python3 -m py_compile src/bin/harness' 'src/bin/**'
step 'UI 단위 테스트' commit 'cd src/ui && node --test lib/*.test.js' 'src/ui/**'
step '테스트' push src/test/render-test.sh 'src/bin/**' 'src/templates/**' 'src/test/**'
echo "verify: ok"
