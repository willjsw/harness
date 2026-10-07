#!/usr/bin/env bash
# PreToolUse 가드의 회귀 테스트 — 케이스 표의 명령을 훅에 흘려 종료 코드가 기대와 같은지 본다.
#
#   script/test-bash-guard.sh
#
# 종료 코드: 0 = 전 케이스 통과 · 1 = 실패한 케이스 있음 · 2 = 실행 실패
#
# 원격도 forge 도 부르지 않는다. 보호 브랜치 commit 은 브랜치 이름에 따라 판정이 갈리므로
# 임시 git 리포를 만들어 그 안에서 돌린다. 사용 기록은 남기지 않는다.
#
# **케이스 표의 값은 설정에서 온다.** 브랜치·보호 문서·forge CLI 를 바꿔도 이 표가 그대로
# 따라온다 — 값을 박아 두면 설정을 바꿀 때마다 테스트가 깨진다.
#
# 마지막 검사들은 **가드 하나를 일부러 망가뜨린 사본**(force push · write-doc)에 차단 케이스 표를 그대로 돌린다.
# 망가뜨린 가드의 케이스가 통과로 뒤집히고 나머지 계열은 그대로 차단이어야 한다 —
# 뒤집히지 않으면 표가 무력화를 못 잡는 것이고, 다른 계열까지 뚫리면 판정이 얽힌 것이다.
set -uo pipefail
# 훅이 넘긴 GIT_DIR·GIT_INDEX_FILE 같은 리포 지역 변수를 비운다. 남아 있으면 임시 리포를 만드는
# git init 이 임시 디렉터리 대신 그 변수가 가리키는 리포를 다시 초기화한다.
unset $(git rev-parse --local-env-vars 2>/dev/null)

# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 2
. "$repo_root/script/harness.env"
eval "export $USAGE_ENV_VAR=off"

# 설정에서 케이스 값을 뽑는다.
set -- $PROTECTED_BRANCHES
protected_a=$1
protected_b=${2:-$1}
forge_cli=${FORGE_CLIS%% *}
doc=$PROTECTED_DOCS_SAMPLE
# write-doc 이 받는 문서 이름. 보호되는 것은 견본에서 떼고, 보호되지 않는 것은 보호 목록에 걸리지 않는 첫 이름이다
doc_name=${doc#.ai/project/}
doc_name=${doc_name%.md}
open_name=
for n in stack environment review-checks; do
  printf '%s' ".ai/project/$n.md" | grep -Eq -- "^($PROTECTED_DOCS_RE)" || {
    open_name=$n
    break
  }
done
work_branch="feat/100-x"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

pass=0
fail=0

# probe <훅경로> <명령> → 훅의 종료 코드
probe() {
  local hook=$1 cmd=$2 esc
  # 줄바꿈은 JSON 문자열에 그대로 올 수 없으므로 하네스가 보내는 대로 \n 으로 이스케이프한다.
  esc=$(printf '%s' "$cmd" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' |
    awk '{ printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }')
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$esc" | "$hook" >/dev/null 2>&1
  echo $?
}

# case <기대코드> <명령> [설명]
case_is() {
  local expect=$1 cmd=$2 note=${3:-} rc
  rc=$(probe "$repo_root/script/hooks/bash-guard.sh" "$cmd")
  if [ "$rc" = "$expect" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "fail: want=$expect got=$rc  $cmd ${note:+($note)}" >&2
  fi
}

# 차단되어야 하는 케이스는 표로 모은다. 같은 표를 망가뜨린 가드 사본에도 돌려,
# 가드가 무력화되면 이 표가 실제로 알아채는지 확인한다.
protected_cases=(
  "git push origin $protected_a"
  "git push origin $protected_b"
  "git push -u origin $protected_b"
  "git push --set-upstream origin $protected_a"
  "git push origin HEAD:$protected_a"
  "git push origin $work_branch:$protected_b"
  "git push origin HEAD:refs/heads/$protected_b"
  "git -c advice.detachedHead=false push origin $protected_b"
  "git -C /tmp push origin $protected_a"
  "git push -o ci.skip origin $protected_b"
  "git push --repo origin $protected_b"
  'git push --all origin'
)

force_cases=(
  "git push --force origin $work_branch"
  "git push -f origin $work_branch"
  "git push --force-with-lease origin $work_branch"
  "git push --force-with-lease=$work_branch origin $work_branch"
  "git push origin +$work_branch:$work_branch"
  "git push origin --delete $work_branch"
  "git -c push.default=current push --force origin $work_branch"
  "git push -o ci.skip --force origin $work_branch"
)

verify_cases=(
  "git push --no-verify origin $work_branch"
  'git commit --no-verify -m "요약"'
  'git commit -n -m "요약"'
  'git -c core.hooksPath=/dev/null commit --no-verify -m "요약"'
)

remote_delete_cases=(
  "$forge_cli issue delete 100"
  "$forge_cli mr delete 7"
)

arch_cases=(
  "echo \"x\" >> $doc"
  "sed -i \"\" \"s/a/b/\" $doc"
  "cat > $doc <<EOF"
)

write_doc_cases=(
  "harness write-doc $doc_name -"
  ".harness/bin/harness write-doc $doc_name -"
  "src/bin/harness write-doc $doc_name -"
  "./src/bin/harness write-doc $doc_name -"
  "harness --target . write-doc $doc_name -"
  "harness write-doc --target . $doc_name -"
  "harness write-doc roles/developer -"
  "harness write-doc workflows/work -"
  "cd x && harness write-doc $doc_name -"
  "printf x | harness write-doc $doc_name -"
)

for c in "${protected_cases[@]}" "${force_cases[@]}" "${verify_cases[@]}" \
  "${remote_delete_cases[@]}" "${arch_cases[@]}" "${write_doc_cases[@]}"; do
  case_is 2 "$c"
done

# ── write-doc 의 보호되지 않은 문서·다른 하네스 명령·인수로 적힌 말은 통과 ──────
[ -n "$open_name" ] && case_is 0 "harness write-doc $open_name -"
case_is 0 'harness schema'
case_is 0 'harness render'
case_is 0 "echo harness write-doc $doc_name"
case_is 0 'grep write-doc README.md'

# ── 읽기·정상 git 표기는 통과 ──────────────────────────────────────────────
case_is 0 "sed -n 1,20p $doc"
case_is 0 "grep -n 범위 $doc"

# ── 통과해야 하는 정상 명령 ────────────────────────────────────────────────
case_is 0 "git push origin $work_branch"
case_is 0 "git push -u origin $work_branch"
case_is 0 "git push -o ci.skip origin $work_branch"
case_is 0 "git -c advice.detachedHead=false push origin $work_branch"
case_is 0 'git fetch -p origin'
case_is 0 "$forge_cli issue view 100"
case_is 0 "$forge_cli mr create --title \"요약\" --target-branch $BASE_BRANCH"
case_is 0 'script/run-lint-test.sh'
case_is 0 'ls -la script/hooks'

# ── 다른 프로그램의 인수로 적힌 말은 실행이 아니다 ─────────────────────────
case_is 0 "echo git push origin $protected_b"
case_is 0 "echo \"git push --force origin $work_branch\""
case_is 0 'grep -n "git commit --no-verify" script/hooks/_guards.sh'
case_is 0 "echo $forge_cli issue delete 100"
case_is 0 "echo \"a; git push --force origin $work_branch\""
case_is 0 "echo 'a && git push origin $protected_b'"

# ── 따옴표로 감싼 낱말은 셸이 넘기는 값으로 읽는다 ─────────────────────────
case_is 2 "git push \"--force\" origin $work_branch"
case_is 2 "git push origin '$protected_a'"

# ── 래퍼·환경변수 대입 뒤의 git 은 실행 자리다 ─────────────────────────────
case_is 2 "env GIT_TRACE=1 git push origin $protected_a"
case_is 2 "git fetch -p origin; git push origin $protected_b"

# ── 명령을 꺼내지 못하는 입력은 통과 ───────────────────────────────────────
rc=$(printf '{"tool_name":"Read"}' | "$repo_root/script/hooks/bash-guard.sh" >/dev/null 2>&1; echo $?)
if [ "$rc" = 0 ]; then pass=$((pass + 1)); else
  fail=$((fail + 1))
  echo "fail: input with no command must pass — got=$rc" >&2
fi

# ── 브랜치에 따라 갈리는 commit 판정 ───────────────────────────────────────
work="$sandbox/repo"
mkdir -p "$work"
if git -C "$work" init -q -b "$protected_a" >/dev/null 2>&1 &&
  git -C "$work" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1; then
  rc=$(cd "$work" && probe "$repo_root/script/hooks/bash-guard.sh" 'git commit -m "요약"')
  if [ "$rc" = 2 ]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "fail: a commit on a protected branch must be blocked — got=$rc" >&2
  fi
  rc=$(cd "$work" && probe "$repo_root/script/hooks/bash-guard.sh" 'git push origin --tags')
  if [ "$rc" = 0 ]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "fail: --tags sends no branch, so it must pass — got=$rc" >&2
  fi
  rc=$(cd "$work" && probe "$repo_root/script/hooks/bash-guard.sh" 'git push origin')
  if [ "$rc" = 2 ]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "fail: a push with no destination on a protected branch must be blocked — got=$rc" >&2
  fi
  git -C "$work" checkout -q -b "$work_branch"
  # 작업 브랜치에서의 commit 은 전부 통과다. 훅을 우회하는 표기만 걸린다.
  for c in 'git commit -m "요약"' \
           'git commit -am "요약"' \
           'git commit --amend --no-edit' \
           'git commit -F - <<EOF
요약

- --no-verify 로 훅을 우회하는 명령을 차단
EOF'; do
    rc=$(cd "$work" && probe "$repo_root/script/hooks/bash-guard.sh" "$c")
    if [ "$rc" = 0 ]; then pass=$((pass + 1)); else
      fail=$((fail + 1))
      echo "fail: a commit on a work branch must pass — got=$rc  $c" >&2
    fi
  done
else
  fail=$((fail + 1))
  echo "fail: could not create the temp repo, so the commit rulings went unchecked" >&2
fi

# ── 명령이 가리키는 작업 트리의 브랜치로 판정한다 ──────────────────────────
# 훅은 세션의 작업 트리에서 돈다. 명령이 `cd` 나 `git -C` 로 다른 작업 트리를 가리키면
# 판정은 그 트리의 브랜치를 따라야 한다. 링크된 작업 트리는 임시 리포 안에만 만든다.
#
# 가드는 자기가 속한 리포의 작업 트리만 판정하므로, 임시 리포에 훅 사본과 설정을 깔아
# 그 리포를 하네스가 지키는 리포로 만든다. at_is 는 at_hook 이 가리키는 사본을 부른다.
wt_prot="$sandbox/wt-protected"
wt_feat="$sandbox/wt-feature"
feat_branch="feat/101-other"
# install_hooks <리포 디렉터리> → 그 리포의 script/ 에 훅 사본과 설정을 깐다
install_hooks() {
  mkdir -p "$1/script/hooks" &&
    cp "$repo_root/script/hooks/bash-guard.sh" "$repo_root/script/hooks/_guards.sh" "$1/script/hooks/" &&
    cp "$repo_root/script/harness.env" "$1/script/" &&
    chmod +x "$1/script/hooks/"*.sh
}
at_hook="$repo_root/script/hooks/bash-guard.sh"
# at_is <기대코드> <훅 작업 디렉터리> <명령> <설명>
at_is() {
  local expect=$1 dir=$2 cmd=$3 note=$4 rc
  rc=$(cd "$dir" && probe "$at_hook" "$cmd")
  if [ "$rc" = "$expect" ]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "fail: $note — want=$expect got=$rc  $cmd" >&2
  fi
}
mkdir -p "$wt_prot"
if git -C "$wt_prot" init -q -b "$protected_b" >/dev/null 2>&1 &&
  git -C "$wt_prot" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 &&
  git -C "$wt_prot" worktree add -q -b "$feat_branch" "$wt_feat" >/dev/null 2>&1 &&
  install_hooks "$wt_prot"; then
  at_hook="$wt_prot/script/hooks/bash-guard.sh"
  at_is 0 "$wt_prot" "cd $wt_feat && git commit -m x" \
    "a commit in another work tree on a work branch must pass"
  at_is 0 "$wt_prot" "git -C $wt_feat commit -m x" \
    "a commit through git -C into a work branch tree must pass"
  at_is 2 "$wt_feat" "git -C $wt_prot commit -m x" \
    "a commit through git -C into a protected branch tree must be blocked"
  at_is 2 "$wt_feat" "cd $wt_prot && git commit -m x" \
    "a commit after cd into a protected branch tree must be blocked"
  at_is 2 "$wt_feat" "cd $sandbox && git -C wt-protected commit -m x" \
    "git -C applies relative to the directory cd moved to"
  at_is 0 "$wt_prot" "cd $wt_prot && git -C ../wt-feature commit -m x" \
    "a relative git -C after cd resolves from the cd target"
  at_is 0 "$wt_prot" "cd $wt_feat; cd ../wt-feature && git commit -m x" \
    "a relative cd resolves from the previous cd"
  at_is 2 "$wt_prot" "cd \"\$(something)\" && git commit -m x" \
    "an unresolved cd path falls back to the hook directory"
  at_is 0 "$wt_feat" "cd \"\$(something)\" && git commit -m x" \
    "an unresolved cd path falls back to the hook directory"
  at_is 2 "$wt_prot" "cd $sandbox && git commit -m x" \
    "a cd target that is not a work tree falls back to the hook directory"
  at_is 2 "$wt_prot" "git -C $sandbox/missing commit -m x" \
    "a git -C path that does not exist falls back to the hook directory"
  at_is 2 "$wt_prot" "(cd $wt_feat) && git commit -m x" \
    "a cd closed inside a subshell does not move the later command"
  at_is 2 "$wt_feat" "git -C $wt_prot push origin" \
    "a push with no destination from a protected branch tree must be blocked"
  at_is 0 "$wt_prot" "cd $wt_feat && git push origin" \
    "a push with no destination from a work branch tree must pass"
  at_is 0 "$wt_prot" "git -C $wt_feat commit -m \"keep -n out\"" \
    "an option-like word inside a quoted message is not an option"
  at_is 2 "$wt_prot" "git -C \"\$HOME/x\" commit -m x" \
    "a quoted path with an expansion falls back to the hook directory"
  at_is 0 "$wt_feat" "git -C \"\$HOME/x\" commit -m x" \
    "a quoted path with an expansion falls back to the hook directory"
else
  fail=$((fail + 1))
  echo "fail: could not create the temp work trees, so the work tree rulings went unchecked" >&2
fi

# ── 공백이 든 작업 트리 경로를 따옴표로 감싸도 그 트리의 브랜치로 판정한다 ──
sp_prot="$sandbox/prot tree"
sp_feat="$sandbox/feat tree"
mkdir -p "$sp_prot"
if git -C "$sp_prot" init -q -b "$protected_b" >/dev/null 2>&1 &&
  git -C "$sp_prot" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 &&
  git -C "$sp_prot" worktree add -q -b "feat/102-space" "$sp_feat" >/dev/null 2>&1 &&
  install_hooks "$sp_prot"; then
  at_hook="$sp_prot/script/hooks/bash-guard.sh"
  at_is 2 "$wt_feat" "git -C \"$sp_prot\" commit -m x" \
    "a double-quoted git -C path with a space into a protected branch tree must be blocked"
  at_is 2 "$wt_feat" "git -C '$sp_prot' commit -m x" \
    "a single-quoted git -C path with a space into a protected branch tree must be blocked"
  at_is 2 "$wt_feat" "cd \"$sp_prot\" && git commit -m x" \
    "a double-quoted cd path with a space into a protected branch tree must be blocked"
  at_is 2 "$wt_feat" "cd $sandbox && git -C 'prot tree' commit -m x" \
    "a quoted relative git -C path with a space resolves from the cd target"
  at_is 2 "$wt_feat" "git -C $sandbox/\"prot tree\" commit -m x" \
    "a quoted part inside a path joins the rest of the word"
  at_is 2 "$wt_feat" "git -C \"$sp_feat\" push origin \"$protected_a\"" \
    "a quoted push destination is read as the branch it names"
  at_is 0 "$wt_prot" "git -C \"$sp_feat\" commit -m x" \
    "a double-quoted git -C path with a space into a work branch tree must pass"
  at_is 0 "$wt_prot" "cd '$sp_feat' && git commit -m x" \
    "a single-quoted cd path with a space into a work branch tree must pass"
  at_is 0 "$wt_prot" "cd \"$sp_feat\" && git push origin" \
    "a push with no destination from a quoted work branch tree must pass"
else
  fail=$((fail + 1))
  echo "fail: could not create the temp work trees with a space, so the quoted path rulings went unchecked" >&2
fi

# ── 하네스가 지키지 않는 다른 리포에는 보호 브랜치 규칙을 적용하지 않는다 ──
# 하네스 리포(본 작업 트리 · 링크된 worktree)와 무관한 리포를 함께 만든다. 무관한 리포도
# 보호 목록과 같은 이름의 브랜치에 있다 — 그 리포의 브랜치 규칙은 이 하네스의 설정이 정하지 않는다.
h_root="$sandbox/h-root"
h_feat="$sandbox/h-feature"
h_prot="$sandbox/h-protected"
other="$sandbox/other-repo"
mkdir -p "$h_root" "$other/sub"
if git -C "$h_root" init -q -b "$protected_a" >/dev/null 2>&1 &&
  git -C "$h_root" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 &&
  git -C "$h_root" worktree add -q -b "feat/103-guard" "$h_feat" >/dev/null 2>&1 &&
  install_hooks "$h_root" && mkdir -p "$h_root/sub" &&
  git -C "$other" init -q -b "$protected_a" >/dev/null 2>&1 &&
  git -C "$other" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1; then
  at_hook="$h_root/script/hooks/bash-guard.sh"
  at_is 0 "$h_feat" "cd $other && git commit -m x" \
    "a commit after cd into an unrelated repo on a protected name must pass"
  at_is 0 "$h_feat" "git -C $other commit -m x" \
    "a commit through git -C into an unrelated repo on a protected name must pass"
  at_is 0 "$h_feat" "git -C $other/sub commit -m x" \
    "a subdirectory of an unrelated repo is that unrelated repo"
  at_is 0 "$h_feat" "cd $other && git push origin" \
    "a push with no destination from an unrelated repo must pass"
  at_is 0 "$h_feat" "git -C $other push origin $protected_a" \
    "a push from an unrelated repo is not ruled by this harness's protected list"
  at_is 2 "$h_feat" "git -C $other push --force origin $work_branch" \
    "a force push stays blocked in an unrelated repo"
  at_is 2 "$h_feat" "git -C $h_root commit -m x" \
    "a commit through git -C into the harness main work tree on a protected branch must be blocked"
  at_is 2 "$h_feat" "git -C $h_root/sub commit -m x" \
    "a subdirectory of the harness main work tree is the harness repo"
  at_is 2 "$h_feat" "cd $other && git -C $h_root commit -m x" \
    "git -C back into the harness repo after cd into an unrelated repo is ruled again"
  at_is 2 "$other" "git commit -m x" \
    "a command with no directory is ruled by the hook directory"
  # 본 작업 트리를 작업 브랜치로 옮기고, 비워진 보호 브랜치를 링크된 worktree 로 연다.
  if git -C "$h_root" checkout -q -b "feat/104-root" >/dev/null 2>&1 &&
    git -C "$h_root" worktree add -q "$h_prot" "$protected_a" >/dev/null 2>&1; then
    at_is 2 "$h_feat" "cd $h_prot && git commit -m x" \
      "a linked worktree of the harness repo on a protected branch must be blocked"
    at_is 2 "$h_feat" "cd $h_prot && git push origin" \
      "a push with no destination from a linked harness worktree on a protected branch must be blocked"
    at_is 0 "$h_prot" "git -C $h_feat commit -m x" \
      "a linked harness worktree on a work branch must pass"
  else
    fail=$((fail + 1))
    echo "fail: could not open a protected branch in a linked worktree of the temp harness repo" >&2
  fi
else
  fail=$((fail + 1))
  echo "fail: could not create the temp harness repo and the unrelated repo, so the repo boundary rulings went unchecked" >&2
fi

# ── 따옴표 안의 구획 문자와 빈 따옴표는 셸이 넘기는 값으로 되돌려 판정한다 ──
# git ref 에는 `&` · `;` · `|` 가 들어갈 수 있다. 그런 이름을 보호 목록에 둔 사본 레이아웃에서
# 인용된 목적지가 실제로 가는 브랜치로 비교되는지 본다.
punct="$sandbox/punct/script/hooks"
mkdir -p "$punct"
cp "$repo_root/script/hooks/bash-guard.sh" "$repo_root/script/hooks/_guards.sh" "$punct/"
chmod +x "$punct"/*.sh
p_amp="$protected_a&prod"
p_semi="rel;x"
p_bar="ops|y"
{
  cat "$repo_root/script/harness.env"
  printf "PROTECTED_BRANCHES='%s %s %s'\n" "$p_amp" "$p_semi" "$p_bar"
} >"$sandbox/punct/script/harness.env"
# punct_is <기대코드> <명령> <설명>
punct_is() {
  local expect=$1 cmd=$2 note=$3 rc
  rc=$(probe "$punct/bash-guard.sh" "$cmd")
  if [ "$rc" = "$expect" ]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "fail: $note — want=$expect got=$rc  $cmd" >&2
  fi
}
punct_is 2 "git push origin '$p_amp'" "a single-quoted destination with & is the protected branch it names"
punct_is 2 "git push origin \"$p_semi\"" "a double-quoted destination with ; is the protected branch it names"
punct_is 2 "git push origin '$p_bar'" "a single-quoted destination with | is the protected branch it names"
punct_is 2 "git push origin HEAD:'$p_amp'" "a quoted refspec right side with & is the protected branch it names"
punct_is 2 "git push origin $protected_a'&prod'" "a quoted part with & joins the rest of the destination"
punct_is 2 "git push origin '$p_amp' $work_branch" "a quoted protected destination among several is found"
punct_is 0 "git push origin '$p_amp-2'" "a quoted destination that only starts with a protected name passes"
punct_is 0 "git push origin $work_branch" "a work branch push passes under a punctuated protected list"

# 빈 따옴표는 셸이 지운다. 낱말에 붙은 빈 따옴표가 명령·옵션·목적지 판정을 비껴가지 않는다.
case_is 2 "g''it push origin $protected_a"
case_is 2 "git pu\"\"sh origin $protected_a"
case_is 2 "git push origin $protected_b''"
case_is 2 "git push --for''ce origin $work_branch"
case_is 2 "git push origin --del''ete $work_branch"
case_is 2 "git commit --no-''verify -m x"
case_is 2 "${forge_cli%?}''${forge_cli#"${forge_cli%?}"} issue delete 100"
case_is 2 "$forge_cli issue de''lete 100"
case_is 0 "git push origin '' $work_branch"
case_is 0 "echo g''it push origin $protected_a"

# 보호 목록과 비교되는 값에 자리표(제어 문자)가 남지 않는다. 비교 함수를 기록하는 것으로 바꿔
# 인용이 섞인 명령마다 비교된 값을 모으고, 제어 문자가 하나라도 있으면 실패다.
seen="$sandbox/compared"
for c in "git push origin '$p_amp'" "git push origin \"$p_semi\" '$p_bar'" \
  "git push origin HEAD:\"$protected_a\"''" "git push origin 'a b~c'" \
  "git -C 'x&y' push origin" "cd 'p;q' && git commit -m x" "git push origin ''"; do
  (
    CMD=$c
    PROTECTED_BRANCHES=$protected_a
    . "$repo_root/script/hooks/_guards.sh"
    is_protected_branch() { printf '%s\n' "$1" >>"$seen"; return 1; }
    guard_protected_branch
  ) >/dev/null 2>&1
done
if [ -s "$seen" ] && ! LC_ALL=C grep -q '[[:cntrl:]]' "$seen"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "fail: a value compared against the protected list still carries a quote placeholder" >&2
  LC_ALL=C od -c "$seen" >&2 2>/dev/null || true
fi

# ── 망가진 가드를 이 표가 잡는가 ───────────────────────────────────────────
# force push 가드만 무력화한 사본에 차단 케이스 표를 그대로 돌린다.
# force 케이스가 전부 통과(코드 0)로 뒤집히고 다른 계열은 그대로 차단이어야,
# 이 표가 무력화를 잡아내며 그 감지가 해당 가드에 한정된다고 말할 수 있다.
# 사본은 같은 레이아웃이어야 한다 — 훅이 자기 위치에서 설정을 찾으므로,
# 설정을 함께 깔지 않으면 가드 로직이 아니라 설정 부재를 검사하게 된다.
broken="$sandbox/broken/script/hooks"
mkdir -p "$broken"
cp "$repo_root/script/hooks/bash-guard.sh" "$repo_root/script/hooks/_guards.sh" "$broken/"
cp "$repo_root/script/harness.env" "$sandbox/broken/script/"
chmod +x "$broken"/*.sh
sed -i.bak 's/^guard_force_push() {$/guard_force_push() { return 0;/' "$broken/_guards.sh"

broken_missed=0
broken_wrong=""
for c in "${force_cases[@]}"; do
  rc=$(probe "$broken/bash-guard.sh" "$c")
  if [ "$rc" = 2 ]; then
    # 보호 브랜치 가드가 대신 잡는 케이스는 force 가드 무력화의 증거가 되지 못한다.
    broken_wrong+="  still blocked: $c"$'\n'
  else
    broken_missed=$((broken_missed + 1))
  fi
done
if [ "$broken_missed" -gt 0 ] && [ -z "$broken_wrong" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "fail: the table did not catch the broken force push guard (${broken_missed} case(s) missed)" >&2
  [ -n "$broken_wrong" ] && printf '%s' "$broken_wrong" >&2
fi

broken_side=0
for c in "${protected_cases[@]}" "${verify_cases[@]}" "${remote_delete_cases[@]}" "${arch_cases[@]}" \
  "${write_doc_cases[@]}"; do
  rc=$(probe "$broken/bash-guard.sh" "$c")
  [ "$rc" = 2 ] || {
    broken_side=$((broken_side + 1))
    echo "  a case unrelated to the force guard got through: $c (got=$rc)" >&2
  }
done
if [ "$broken_side" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "fail: only one guard was broken, yet other families passed too — the rulings are entangled" >&2
fi

# write-doc 가드만 무력화한 사본. write-doc 케이스가 전부 통과로 뒤집히고 다른 계열은 그대로 차단이어야 한다
broken_wd="$sandbox/broken-wd/script/hooks"
mkdir -p "$broken_wd"
cp "$repo_root/script/hooks/bash-guard.sh" "$repo_root/script/hooks/_guards.sh" "$broken_wd/"
cp "$repo_root/script/harness.env" "$sandbox/broken-wd/script/"
chmod +x "$broken_wd"/*.sh
sed -i.bak 's/^guard_write_doc() {$/guard_write_doc() { return 0;/' "$broken_wd/_guards.sh"
wd_still=""
for c in "${write_doc_cases[@]}"; do
  rc=$(probe "$broken_wd/bash-guard.sh" "$c")
  [ "$rc" = 0 ] || wd_still+="  still blocked: $c (got=$rc)"$'\n'
done
if [ -z "$wd_still" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "fail: the table did not catch the broken write-doc guard" >&2
  printf '%s' "$wd_still" >&2
fi
wd_side=0
for c in "${protected_cases[@]}" "${force_cases[@]}" "${verify_cases[@]}" "${remote_delete_cases[@]}" "${arch_cases[@]}"; do
  rc=$(probe "$broken_wd/bash-guard.sh" "$c")
  [ "$rc" = 2 ] || {
    wd_side=$((wd_side + 1))
    echo "  a case unrelated to the write-doc guard got through: $c (got=$rc)" >&2
  }
done
if [ "$wd_side" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "fail: only the write-doc guard was broken, yet other families passed too — the rulings are entangled" >&2
fi

echo "PreToolUse guard regression test: ${pass} of $((pass + fail)) passed, ${fail} failed"
[ "$fail" -eq 0 ]
