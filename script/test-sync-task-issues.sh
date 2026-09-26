#!/usr/bin/env bash
# task 이슈 동기화의 회귀 테스트 — 분해 절이 생성 호출의 **어느 인수**로 들어가는지.
#
#   script/test-sync-task-issues.sh
#
# 종료 코드: 0 = 전 케이스 통과 · 1 = 실패한 케이스 있음 · 2 = 실행 실패
#
# 원격을 부르지 않는다. 임시 리포와 로컬 bare 원격을 만들고 **forge 어댑터를 페이크로
# 갈아끼워** 생성 호출의 인수만 본다. 어느 forge 를 쓰든 같은 테스트가 돈다.
#
# **제목과 본문 파일이 서로 밀려 들어가는 고장을 잡는 것이 목적이다.** 스크립트는 계획을
# 탭 구분 파일로 적고 셸이 그것을 다시 읽는데, 빈 칸의 표현이 어긋나면 필드가 한 칸씩
# 밀린다 — 그러면 제목이 본문 파일 경로 자리로 들어가고 이슈 생성이 통째로 실패한다.
#
# **실제 이슈를 만들지 않는 것이 이 테스트의 전제다** — 삭제가 금지된 프로젝트에서는 되돌릴 수 없다.
set -uo pipefail

command -v python3 >/dev/null || { echo "error: python3 is required to run this test" >&2; exit 2; }

# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 2
. "$repo_root/script/harness.env"
. "$repo_root/script/harness-format.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

state="$sandbox/state"
mkdir -p "$state"

# ── forge 페이크 ────────────────────────────────────────────────────────────
# 계약(`script/forge/_common.sh` 상단)이 정한 정규화 JSON 을 상태 파일에서 돌려준다.
# 생성 호출은 인수를 자리별로 따로 기록한다 — 자리가 밀리면 그 자체가 드러나야 한다.
cat > "$sandbox/forge-fake.sh" <<'FAKE'
#!/usr/bin/env sh
tracker_require() { return 0; }
review_require()  { return 0; }
tracker_issue_view() { cat "$FAKE_STATE/meta.json"; }
tracker_issue_list() {
  # 계획을 세울 때와 만들기 직전, 두 번 불린다. 두 번째에 다른 응답을 주면 경합이 재현된다.
  _n=$(( $(cat "$FAKE_STATE/list-calls" 2>/dev/null || echo 0) + 1 ))
  echo "$_n" > "$FAKE_STATE/list-calls"
  if [ "$_n" -gt 1 ] && [ -f "$FAKE_STATE/issues2.json" ]; then
    cat "$FAKE_STATE/issues2.json"
  else
    cat "$FAKE_STATE/issues.json"
  fi
}
tracker_issue_create() {
  printf 'title=%s\n' "$1" >> "$FAKE_STATE/create-titles"
  printf 'label=%s assignee=%s milestone=%s\n' "$3" "$4" "$5" >> "$FAKE_STATE/create-meta"
  if [ -f "$2" ]; then head -1 "$2"; else printf 'NOT-A-FILE:%s\n' "$2"; fi >> "$FAKE_STATE/create-bodies"
  echo 42
}
FAKE

# ── 임시 리포와 로컬 원격 ───────────────────────────────────────────────────
# 승인 게이트가 원격의 통합 브랜치를 읽으므로, 분해는 로컬 작업 트리가 아니라 거기 있어야 한다.
git() { command git -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.invalid "$@"; }

# 하네스 루트를 리포 루트 바로 아래에도, 서브디렉터리에도 놓아 본다. **모노레포에서는 둘이
# 다르고**, git 객체 경로는 리포 루트 기준이라 접두를 붙이지 않으면 분해를 찾지 못한다.
build_repo() {  # <이름> <리포 루트로부터의 하네스 경로. 비면 리포 루트>
  _repo="$sandbox/$1"
  _root="$_repo${2:+/$2}"
  mkdir -p "$_root/script"
  cp "$repo_root/script/sync-task-issues.sh" "$_root/script/"
  cp "$repo_root/script/harness.env" "$repo_root/script/harness-format.sh" "$_root/script/"
  cp "$sandbox/forge-fake.sh" "$_root/script/forge.sh"
  chmod +x "$_root/script/"*.sh

  git init -q --bare "$sandbox/$1-origin.git" || return 2
  git init -q "$_repo" || return 2
  git -C "$_repo" symbolic-ref HEAD "refs/heads/$BASE_BRANCH"
  git -C "$_repo" remote add origin "$sandbox/$1-origin.git"

  mkdir -p "$_root/docs/plan/100"
  cp "$sandbox/task.md" "$_root/docs/plan/100/task.md"
  git -C "$_repo" add -A >/dev/null
  git -C "$_repo" commit -q -m "docs: 분해" >/dev/null || return 2
  git -C "$_repo" push -q origin "$BASE_BRANCH" || return 2
  printf '%s' "$_root"
}

cat > "$sandbox/task.md" <<'MD'
# 분해

## T1 · feat: 모듈 골격 구성

T1 본문 첫 줄

### 완료 조건

- [ ] 골격이 선다

## T2 · feat: 입력 검증 유틸

T2 본문 첫 줄

### 완료 조건

- [ ] 경계값을 막는다
MD

work=$(build_repo root "") || { echo "error: could not build the temp repo" >&2; exit 2; }

# ── 조회 응답 (정규화 JSON) ─────────────────────────────────────────────────
ref() { printf '%s' "$ISSUE_REF_DISPLAY" | sed "s|{id}|$1|"; }
t1_title="feat: 모듈 골격 구성($(ref 100))"
t2_title="feat: 입력 검증 유틸($(ref 100))"

printf '{"iid":"100","title":"요구사항","state":"opened","description":"","labels":[],"assignee":"user-a","milestone":"M1"}\n' \
  > "$sandbox/meta-full.json"
echo '[]' > "$sandbox/issues-none.json"
python3 - "$sandbox/issues-t1.json" "$t1_title" <<'PY'
import json, sys
json.dump([{"iid": "7", "title": sys.argv[2], "state": "closed"}],
          open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PY
# 필수 필드마다 그것만 비운 응답. 목록은 설정이 갖는다 — 여기 박아 두면 필수 필드를 줄인
# 프로젝트에서 테스트가 거짓으로 실패한다.
for f in $ISSUE_REQUIRED_FIELDS; do
  python3 - "$sandbox/meta-no-$f.json" "$f" <<'PY'
import json, sys
meta = {"iid": "100", "title": "요구사항", "state": "opened", "description": "",
        "labels": [], "assignee": "user-a", "milestone": "M1"}
meta[sys.argv[2]] = ""
json.dump(meta, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PY
done
printf 'not json\n' > "$sandbox/broken.json"

# ── 실행 도우미 ─────────────────────────────────────────────────────────────
pass=0; fail=0
check() { # <ID> <무엇> <기대> <실제>
  if [ "$3" = "$4" ]; then
    pass=$((pass + 1))
  else
    echo "  FAIL $1 $2 → want '$3', got '$4'" >&2; fail=$((fail + 1))
  fi
}

setup() { # <목록응답> <상위이슈응답>
  cp "$1" "$state/issues.json"
  cp "$2" "$state/meta.json"
  rm -f "$state/create-titles" "$state/create-meta" "$state/create-bodies" \
        "$state/list-calls" "$state/issues2.json"
}

# 스크립트가 잡는 잠금 경로. 같은 규칙으로 계산해 미리 잡아 두면 두 번째 실행을 흉내 낼 수 있다.
lock_path() { # <하네스 루트> <상위이슈>
  printf '%s/harness-sync-%s-%s' "${TMPDIR:-/tmp}" \
    "$(printf '%s' "$1" | cksum | cut -d' ' -f1)" "$2"
}

create_calls() { [ -f "$state/create-titles" ] && wc -l < "$state/create-titles" | tr -d ' ' || echo 0; }
# grep -c 는 0건일 때 0 을 찍고 1 로 끝난다 — `|| echo 0` 을 붙이면 두 줄이 나온다.
line_hits() { [ -f "$2" ] || { echo 0; return; }; grep -cxF -- "$1" "$2" || true; }
hits()      { [ -f "$2" ] || { echo 0; return; }; grep -cF  -- "$1" "$2" || true; }

run() {
  ( cd "$work" && FAKE_STATE="$state" \
      script/sync-task-issues.sh "$@" >"$state/last.out" 2>"$state/last.err" )
  echo $?
}

echo "UT-01 every breakdown section becomes one issue, with title and body in their own slots"
setup "$sandbox/issues-none.json" "$sandbox/meta-full.json"
check UT-01 "exit code" 0 "$(run 100)"
check UT-01 "create calls" 2 "$(create_calls)"
check UT-01 "T1 title" 1 "$(line_hits "title=$t1_title" "$state/create-titles")"
check UT-01 "T2 title" 1 "$(line_hits "title=$t2_title" "$state/create-titles")"
# 본문은 경로가 아니라 파일로 넘어간다. 밀리면 제목 문자열이 경로 자리에 오고 여기가 깨진다.
check UT-01 "T1 body came from a file" 1 "$(line_hits 'T1 본문 첫 줄' "$state/create-bodies")"
check UT-01 "T2 body came from a file" 1 "$(line_hits 'T2 본문 첫 줄' "$state/create-bodies")"
check UT-01 "no argument landed in the wrong slot" 0 "$(hits 'NOT-A-FILE' "$state/create-bodies")"
check UT-01 "label and inherited fields" 2 \
  "$(line_hits "label=$ISSUE_LABEL_TASK assignee=user-a milestone=M1" "$state/create-meta")"
check UT-01 "mapping output" 2 "$(hits "$(ref 42)  created" "$state/last.out")"

echo "UT-02 a section whose issue already exists is skipped with its state"
setup "$sandbox/issues-t1.json" "$sandbox/meta-full.json"
check UT-02 "exit code" 0 "$(run 100)"
check UT-02 "create calls" 1 "$(create_calls)"
check UT-02 "only the missing one is created" 1 "$(line_hits "title=$t2_title" "$state/create-titles")"
# 건너뛰는 줄도 같은 계획 파일을 타므로 자리가 밀리면 상태가 빈 괄호로 나온다.
check UT-02 "skip line carries number and state" 1 "$(line_hits "T1 $(ref 7)  skip(closed)" "$state/last.out")"

echo "UT-03 a dry run creates nothing but shows every title"
setup "$sandbox/issues-none.json" "$sandbox/meta-full.json"
check UT-03 "exit code" 0 "$(run 100 --dry-run)"
check UT-03 "create calls" 0 "$(create_calls)"
check UT-03 "T1 title in the preview" 1 "$(hits "$t1_title" "$state/last.out")"
check UT-03 "T2 title in the preview" 1 "$(hits "$t2_title" "$state/last.out")"

echo "UT-04 an unapproved breakdown creates nothing (required: ${ISSUE_REQUIRED_FIELDS:-none})"
setup "$sandbox/issues-none.json" "$sandbox/meta-full.json"
check UT-04 "no breakdown on the remote — exit code" 2 "$(run 101)"
check UT-04 "no breakdown on the remote — create calls" 0 "$(create_calls)"
for f in $ISSUE_REQUIRED_FIELDS; do
  setup "$sandbox/issues-none.json" "$sandbox/meta-no-$f.json"
  check UT-04 "$f missing — exit code" 2 "$(run 100)"
  check UT-04 "$f missing — create calls" 0 "$(create_calls)"
done

echo "UT-05 a malformed lookup response stops the run"
# 조회하지 못한 것을 "결과 없음" 으로 읽으면 이미 있는 이슈를 다시 만든다.
setup "$sandbox/broken.json" "$sandbox/meta-full.json"
check UT-05 "issue list is not JSON — exit code" 2 "$(run 100)"
check UT-05 "issue list is not JSON — create calls" 0 "$(create_calls)"

echo "UT-06 argument validation"
setup "$sandbox/issues-none.json" "$sandbox/meta-full.json"
check UT-06 "no argument — exit code" 2 "$(run)"
check UT-06 "mistyped option — exit code" 2 "$(run 100 --dryrun)"
check UT-06 "create calls" 0 "$(create_calls)"

echo "UT-07 a harness below the repo root still finds the approved breakdown"
# 모노레포. git 객체 경로는 리포 루트 기준이라, 접두를 붙이지 않으면 분해가 없다고 판정한다.
mono=$(build_repo mono packages/api) || { echo "error: could not build the monorepo fixture" >&2; exit 2; }
setup "$sandbox/issues-none.json" "$sandbox/meta-full.json"
( cd "$mono" && FAKE_STATE="$state" script/sync-task-issues.sh 100 \
    >"$state/last.out" 2>"$state/last.err" )
check UT-07 "exit code" 0 "$?"
check UT-07 "create calls" 2 "$(create_calls)"
check UT-07 "T1 title" 1 "$(line_hits "title=$t1_title" "$state/create-titles")"
# 리포 루트에서 불러도 스크립트가 자기 루트를 잡는다.
setup "$sandbox/issues-none.json" "$sandbox/meta-full.json"
( cd "$sandbox/mono" && FAKE_STATE="$state" packages/api/script/sync-task-issues.sh 100 \
    >"$state/last.out" 2>"$state/last.err" )
check UT-07 "called from the repo root — exit code" 0 "$?"
check UT-07 "called from the repo root — create calls" 2 "$(create_calls)"

echo "UT-08 a second run for the same parent issue does not start"
# 조회와 생성 사이에 잠금이 없으면 양쪽 다 "없음" 으로 보고 중복을 만든다.
setup "$sandbox/issues-none.json" "$sandbox/meta-full.json"
held=$(lock_path "$work" 100)
rm -rf "$held"; mkdir -p "$held"
printf 'pid: 1\nhost: other\nstarted: 2026-01-01 00:00:00\n' > "$held/owner"
check UT-08 "exit code" 2 "$(run 100)"
check UT-08 "create calls" 0 "$(create_calls)"
check UT-08 "names the lock" 1 "$(hits "  lock: $held" "$state/last.err")"
check UT-08 "names the holder" 1 "$(hits 'host: other' "$state/last.err")"
rm -rf "$held"
# 잠금이 풀리면 같은 실행이 그대로 돈다 — 잠금이 남아 영구히 막지 않는다.
setup "$sandbox/issues-none.json" "$sandbox/meta-full.json"
check UT-08 "runs once the lock is gone" 0 "$(run 100)"
check UT-08 "lock released afterwards" 0 "$([ -e "$held" ] && echo 1 || echo 0)"

echo "UT-09 duplicate task issues already in the tracker stop the run"
# 과거 경합의 흔적이다. 어느 쪽이 정본인지 스크립트가 정할 수 없다.
python3 - "$sandbox/issues-dup.json" "$t1_title" <<'DUP'
import json, sys
json.dump([{"iid": "7", "title": sys.argv[2], "state": "opened"},
           {"iid": "9", "title": sys.argv[2], "state": "opened"}],
          open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
DUP
setup "$sandbox/issues-dup.json" "$sandbox/meta-full.json"
check UT-09 "exit code" 2 "$(run 100)"
check UT-09 "create calls" 0 "$(create_calls)"
check UT-09 "points at both issues" 1 "$(hits "7, 9" "$state/last.err")"

echo "UT-10 an issue that appears while planning stops the run before anything is created"
# 다른 기계·CI 에서 동시에 돌면 잠금이 닿지 않는다. 만들기 직전에 한 번 더 본다.
setup "$sandbox/issues-none.json" "$sandbox/meta-full.json"
python3 - "$state/issues2.json" "$t1_title" <<'RACE'
import json, sys
json.dump([{"iid": "8", "title": sys.argv[2], "state": "opened"}],
          open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
RACE
check UT-10 "exit code" 2 "$(run 100)"
check UT-10 "created nothing at all" 0 "$(create_calls)"
check UT-10 "points at the conflict" 1 "$(hits "T1  $t1_title  ->  8" "$state/last.err")"

echo
if [ "$fail" -gt 0 ]; then
  echo "sync task issues test failed: ${pass} passed, ${fail} failed" >&2
  echo "last run output:" >&2
  cat "$state/last.out" "$state/last.err" >&2
  exit 1
fi
echo "sync task issues test passed: ${pass} cases"
