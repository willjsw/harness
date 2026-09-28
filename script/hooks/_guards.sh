#!/usr/bin/env sh
# 가드 함수 라이브러리. bash-guard.sh 가 읽어 순서대로 호출한다.
# 각 함수는 $CMD 를 검사해 위반이면 block(종료 코드 2), 아니면 return 0 한다.
#
# **판정은 문자열 목록이 아니라 명령 파싱으로 한다.** git 호출은 토큰으로 끊어 전역 옵션을
# 걷어낸 뒤 subcommand 를 보고, push 목적지는 refspec 의 오른쪽을 잘라 실제로 어느 ref 로
# 가는지 본다 — `HEAD:main`·`+feat:main`·`-u origin development`·`-c k=v push` 처럼 표기가
# 달라도 같은 행위면 같이 걸린다.
#
# 미탐은 허용하고 오탐은 피한다. 셸 한 줄로 표현할 수 있는 모든 우회를 막을 수는 없으므로
# 이 층은 보조이고, 무엇을 해도 되는지는 규칙이 정한다.
#
# **무엇을 막는지는 설정이 정한다.** 보호 브랜치 목록·보호 문서 경로·forge CLI 이름은
# `script/harness.env` 에서 오고, 이 파일은 그 값을 어떻게 판정하는지만 안다.
set -u
# 토큰 분해에 비따옴표 확장을 쓰므로 글로빙을 끈다. 명령 문자열의 * 와 ? 가 파일 이름으로
# 바뀌면 판정 대상이 달라진다.
set -f

has() { printf '%s' "$CMD" | grep -Eq -- "$1"; }

# 보호 브랜치인가. 목록은 설정이 갖는다 — 이 파일에 이름을 적지 않는다.
is_protected_branch() {
  for _b in ${PROTECTED_BRANCHES:-}; do
    [ "$1" = "$_b" ] && return 0
  done
  return 1
}

# 차단 사유와 대안을 stderr 로 내고 종료 코드 2 로 끝낸다.
# 종료 코드 2 는 명령을 실행하지 않고 사유를 모델에게 돌려주는 값이다.
block() {
  if [ -n "${GUARD_ROOT:-}" ] && [ -x "$GUARD_ROOT/script/usage-log.sh" ]; then
    "$GUARD_ROOT/script/usage-log.sh" block bash-guard "${GUARD_LABEL:-}" >/dev/null 2>&1 || true
  fi
  echo "blocked: $1" >&2
  shift
  for _line in "$@"; do echo "$_line" >&2; done
  exit 2
}

# 판정 결과 한 줄의 앞 칸(작업 디렉터리)과 뒤 칸(호출)을 가르는 구분자.
TAB=$(printf '\t')

# 따옴표 안의 글자를 토큰 분해에서 지키는 자리표. 공백·탭·구획 구분자·물결표를 제어 문자로
# 바꿔 두면 비따옴표 확장과 `tr` 이 그 글자에서 끊지 않는다. 빈 따옴표는 Q_EMPTY 한 글자다.
Q_EMPTY=$(printf '\032')

# $CMD 의 단순한 따옴표 구간을 셸이 하듯 한 낱말로 푼다 — 따옴표를 떼고 안의 글자를 자리표로 바꾼다.
# 단순한 구간은 안에 `$` · 백틱 · 백슬래시가 없는 `"…"` 와 `'…'` 다. 그 밖(확장·이스케이프가 섞인
# 구간, 닫히지 않은 따옴표, 따옴표 밖의 백슬래시 이스케이프)은 그대로 두어 경로를 풀지 못한 것으로 남긴다.
quote_words() {
  printf '%s\n' "$CMD" | awk '
    BEGIN { sq = sprintf("%c", 39); dq = "\"" }
    {
      s = $0; n = length(s); out = ""; i = 1
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\\") { out = out substr(s, i, 2); i += 2; continue }
        if (c != sq && c != dq) { out = out c; i++; continue }
        j = i + 1
        while (j <= n && substr(s, j, 1) != c) {
          if (c == dq && substr(s, j, 1) == "\\") j++
          j++
        }
        if (j > n) { out = out substr(s, i); break }
        body = substr(s, i + 1, j - i - 1)
        if (body ~ /[$`\\]/) {
          out = out substr(s, i, j - i + 1)
        } else if (body == "") {
          out = out "\032"
        } else {
          gsub(/ /, "\037", body); gsub(/\t/, "\036", body); gsub(/\|/, "\035", body)
          gsub(/;/, "\034", body); gsub(/&/, "\033", body); gsub(/~/, "\031", body)
          out = out body
        }
        i = j + 1
      }
      print out
    }'
}

# quote_words 의 자리표를 원래 글자로 되돌린다.
unquote_word() {
  printf '%s' "$1" | tr -d '\032' | tr '\037\036\035\034\033\031' ' \t|;&~'
}

# 명령 문자열의 경로 토큰 $2 를 기준 디렉터리 $1 에서 푼다.
# 기준이 비었으면 훅 작업 디렉터리, `?` 이면 풀지 못한 상태다. 결과도 같은 표기로 낸다.
# 셸이 실행 때에야 정하는 값(변수·명령 치환·glob·중괄호·괄호)이 섞이면 풀지 않는다 —
# 추측한 경로로 판정하면 엉뚱한 작업 트리의 브랜치를 보게 된다.
resolve_path() {
  _base=$1
  _p=$2
  case "$_p" in
    '' | - | "$Q_EMPTY" | *'$'* | *'`'* | *'*'* | *'?'* | *'['* | *'{'* | *'}'* | *'('* | *')'* | *'"'* | *"'"* | *'\'*)
      printf '?'
      return 0
      ;;
  esac
  case "$_p" in
    '~') _p=$HOME ;;
    '~/'*) _p=$HOME/${_p#'~/'} ;;
    '~'*)
      printf '?'
      return 0
      ;;
  esac
  case "$_p" in
    /*) printf '%s' "$_p" ;;
    *)
      case "$_base" in
        '?') printf '?' ;;
        '') printf '%s' "$_p" ;;
        *) printf '%s/%s' "$_base" "$_p" ;;
      esac
      ;;
  esac
}

# `cd` 의 인수에서 옮겨 갈 디렉터리를 낸다. $1 은 지금까지의 디렉터리다.
# 인수가 없거나(`cd` 는 홈, `cd -` 는 직전 디렉터리) 풀 수 없으면 `?` 다.
cd_target() {
  _from=$1
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      -P | -L | -e | -@) shift ;;
      --)
        shift
        break
        ;;
      *) break ;;
    esac
  done
  if [ $# -eq 0 ]; then
    printf '?'
    return 0
  fi
  resolve_path "$_from" "$1"
}

# $CMD 안에서 $1 프로그램이 **실행되는 자리**의 호출만 "작업디렉터리<TAB>인수..." 한 줄씩 낸다.
# 파이프·세미콜론·& 로 끊은 구획마다 맨 앞 토큰이 명령이다. 앞선 프로그램의 인수로 적힌 말
# (`echo git push origin main`)은 실행이 아니므로 세지 않는다 — 세면 정상 명령이 막힌다.
# 환경변수 대입과 실행 래퍼(sudo·env·time 등), 여는 괄호·명령 치환 표기는 걷어내면 그 뒤가
# 다시 명령 자리다.
#
# 단순한 따옴표 구간은 quote_words 가 한 낱말로 묶어 두므로, 그 안의 공백·구분자에서 끊지 않는다.
#
# 작업 디렉터리는 앞선 구획의 `cd` 가 옮겨 놓은 곳이다. 비었으면 훅 작업 디렉터리, `?` 이면
# 풀지 못한 경로다. 자리표는 되돌리지 않은 채로 낸다 — 경로를 쓰는 branch_at 이 되돌린다.
invocations_at() {
  _prog=$1
  _dir=
  quote_words | tr '|;&' '\n\n\n' | while IFS= read -r _seg; do
    # shellcheck disable=SC2086
    set -- $_seg
    _hit=0
    while [ $# -gt 0 ]; do
      _w=$1
      while :; do
        case "$_w" in
          '$('*) _w=${_w#'$('} ;;
          '('*) _w=${_w#'('} ;;
          '`'*) _w=${_w#'`'} ;;
          *) break ;;
        esac
      done
      case "$_w" in
        "$_prog" | */"$_prog")
          shift
          _hit=1
          break
          ;;
        cd)
          shift
          _dir=$(cd_target "$_dir" "$@")
          break
          ;;
        '' | '{' | '!' | sudo | command | exec | nohup | time | env | then | do | else)
          shift
          ;;
        *=*) shift ;;
        *) break ;;
      esac
    done
    [ "$_hit" -eq 1 ] || continue
    [ $# -gt 0 ] || continue
    printf '%s\t%s\n' "$_dir" "$*"
  done
}

# invocations_at 에서 작업 디렉터리를 뗀 "인수..." 줄.
invocations_of() {
  invocations_at "$1" | while IFS= read -r _line; do
    printf '%s\n' "${_line#*"$TAB"}"
  done
}

# git 호출을 "작업디렉터리<TAB>subcommand 인수..." 한 줄씩 낸다.
# 값을 갖는 전역 옵션(-c, -C, --git-dir 등)은 그 값까지 걷어낸다 — 걷어내지 않으면 값이
# subcommand 로 읽힌다. `-C` 는 git 이 하듯 그때까지의 디렉터리에 차례로 덧붙인다.
# `--git-dir` · `--work-tree` 는 작업 트리를 따로 정하므로 디렉터리를 풀지 못한 것으로 둔다.
git_invocations_at() {
  invocations_at git | while IFS= read -r _line; do
    _at=${_line%%"$TAB"*}
    # shellcheck disable=SC2086
    set -- ${_line#*"$TAB"}
    while [ $# -gt 0 ]; do
      case "$1" in
        -C)
          shift
          if [ $# -gt 0 ]; then
            _at=$(resolve_path "$_at" "$1")
            shift
          fi
          ;;
        --git-dir | --work-tree)
          _at='?'
          shift
          [ $# -gt 0 ] && shift
          ;;
        --git-dir=* | --work-tree=*)
          _at='?'
          shift
          ;;
        -c | --namespace | --exec-path | --config-env)
          shift
          [ $# -gt 0 ] && shift
          ;;
        -*) shift ;;
        *) break ;;
      esac
    done
    [ $# -gt 0 ] || continue
    printf '%s\t%s\n' "$_at" "$*"
  done
}

# git 호출을 "subcommand 인수..." 한 줄씩 낸다. 작업 디렉터리가 판정에 닿지 않는 가드가 쓴다.
git_invocations() {
  git_invocations_at | while IFS= read -r _line; do
    printf '%s\n' "${_line#*"$TAB"}"
  done
}

# 디렉터리 $1 의 현재 브랜치. 비었거나 풀지 못했거나(`?`) git 작업 트리가 아니면
# 훅 작업 디렉터리의 브랜치로 판정한다 — 경로를 잘못 짚어 정상 작업을 막지 않는다.
branch_at() {
  case "${1:-}" in
    '' | '?') ;;
    *)
      _wt=$(unquote_word "$1")
      if [ "$(git -C "$_wt" rev-parse --is-inside-work-tree 2>/dev/null)" = true ]; then
        git -C "$_wt" branch --show-current 2>/dev/null
        return 0
      fi
      ;;
  esac
  git branch --show-current 2>/dev/null
}

# push 인수에서 목적지 브랜치 후보를 한 줄씩 낸다.
# 인수가 없거나 원격만 있으면 작업 디렉터리 $_AT 의 현재 브랜치가 목적지다. --tags 처럼 브랜치 refspec 을 보내지
# 않는 모드에서는 현재 브랜치로 대체하지 않는다. --all·--mirror 는 모든 브랜치를 보내므로
# 목적지를 하나로 지목할 수 없고, 보호 브랜치가 그 안에 든다.
push_destinations() {
  _n=0
  _found=0
  _noref=0
  while [ $# -gt 0 ]; do
    case "$1" in
      # 값을 다음 토큰으로 받는 옵션. 값을 원격·refspec 으로 세면 목적지를 놓친다.
      -o | --push-option | --receive-pack | --exec)
        shift
        [ $# -gt 0 ] && shift
        continue
        ;;
      # --repo 가 원격을 지정하면 남은 비옵션 토큰은 모두 refspec 이다.
      --repo)
        shift
        [ $# -gt 0 ] && shift
        _n=1
        continue
        ;;
      --repo=*)
        shift
        _n=1
        continue
        ;;
      --all | --mirror)
        printf '%s\n' '*all*'
        return 0
        ;;
      --tags)
        _noref=1
        shift
        continue
        ;;
      -*)
        shift
        continue
        ;;
    esac
    _n=$((_n + 1))
    if [ "$_n" -eq 1 ]; then # 첫 비옵션 토큰은 원격 이름
      shift
      continue
    fi
    _t=${1#+} # +feat:main 의 강제 표기
    case "$_t" in *:*) _t=${_t#*:} ;; esac
    _t=${_t#refs/heads/}
    if [ -n "$_t" ]; then
      printf '%s\n' "$_t"
      _found=1
    fi
    shift
  done
  if [ "$_found" -eq 0 ] && [ "$_noref" -eq 0 ]; then
    branch_at "${_AT:-}"
  fi
}

# 1) 보호 브랜치 직접 push·commit
#    commit 과 목적지 없는 push 는 명령이 `cd` · `git -C` 로 가리키는 작업 트리의 브랜치로 판정한다.
#    훅은 세션의 작업 트리에서 돌므로, 그 자리의 브랜치로 판정하면 다른 작업 트리의 커밋을 잘못 가른다.
guard_protected_branch() {
  GUARD_LABEL=protected-branch
  _invs=$(git_invocations_at)
  _ifs=$IFS
  IFS='
'
  for _line in $_invs; do
    IFS=$_ifs
    _AT=${_line%%"$TAB"*}
    # shellcheck disable=SC2086
    set -- ${_line#*"$TAB"}
    case "$1" in
      push)
        shift
        for _dest in $(push_destinations "$@"); do
          if [ "$_dest" = '*all*' ]; then
            block "push that sends every branch at once" \
              "a protected branch is among the destinations, and protected branches take changes only through a review request" \
              "help: name the branch you mean with an explicit refspec"
          elif is_protected_branch "$_dest"; then
            block "direct push to the protected branch $_dest" \
              "protected branches take changes only through a review request" \
              "help: push a ${BRANCH_PATTERN:-topic} branch and open a review request onto ${BASE_BRANCH:-the integration branch}"
          fi
        done
        ;;
      commit)
        _cur=$(branch_at "$_AT")
        if is_protected_branch "$_cur"; then
          block "direct commit on the protected branch $_cur" \
            "help: create a topic branch first — git checkout -b ${BRANCH_PATTERN:-<topic-branch>}"
        fi
        ;;
    esac
    IFS='
'
  done
  IFS=$_ifs
  return 0
}

# 2) 원격 이력을 덮어쓰거나 지우는 push
guard_force_push() {
  GUARD_LABEL=force-push
  _alt="this is hard to undo — if it is genuinely needed, run it yourself in a terminal"
  _invs=$(git_invocations)
  _ifs=$IFS
  IFS='
'
  for _inv in $_invs; do
    IFS=$_ifs
    # shellcheck disable=SC2086
    set -- $_inv
    [ "$1" = push ] || {
      IFS='
'
      continue
    }
    shift
    while [ $# -gt 0 ]; do
      case "$1" in
        -o | --push-option | --repo | --receive-pack | --exec)
          shift
          [ $# -gt 0 ] && shift
          continue
          ;;
        --force | --force-with-lease | --force-with-lease=* | --force-if-includes)
          block "force push (overwrites remote history)" "$_alt" \
            "help: fix it with a new commit and use a normal push — a push after rebase is done by a person"
          ;;
        --delete | --mirror)
          block "deletion of a remote branch or tag" "$_alt"
          ;;
        --*) ;;
        -[!-]*)
          # 짧은 옵션 묶음. -f 와 -d 는 각각 force push 와 삭제다.
          case "$1" in
            *f*)
              block "force push (overwrites remote history)" "$_alt" \
                "help: fix it with a new commit and use a normal push — a push after rebase is done by a person"
              ;;
            *d*) block "deletion of a remote branch or tag" "$_alt" ;;
          esac
          ;;
        +*)
          # +refspec 은 옵션 없이도 강제로 밀어 넣는다.
          block "force push written as a +refspec" "$_alt"
          ;;
      esac
      shift
    done
    IFS='
'
  done
  IFS=$_ifs
  return 0
}

# 3) 검사 훅 우회
guard_no_verify() {
  GUARD_LABEL=no-verify
  _alt="this skips the commit-message, copy-sync and protected-branch checks — fix the change so the checks pass"
  _invs=$(git_invocations)
  _ifs=$IFS
  IFS='
'
  for _inv in $_invs; do
    IFS=$_ifs
    # shellcheck disable=SC2086
    set -- $_inv
    _sub=$1
    case "$_sub" in push | commit | merge | rebase) ;; *)
      IFS='
'
      continue
      ;;
    esac
    shift
    while [ $# -gt 0 ]; do
      case "$1" in
        # 값을 다음 토큰으로 받는 옵션. 값에 적힌 말을 옵션으로 읽지 않는다.
        -m | -F | -t | -c | -C | --message | --file | --template | --author | --date | --cleanup | -o | --push-option | --repo)
          shift
          [ $# -gt 0 ] && shift
          continue
          ;;
        --no-verify) block "bypassing git hooks with --no-verify" "$_alt" ;;
        --*) ;;
        -[!-]*)
          [ "$_sub" = commit ] && case "$1" in
            *n*) block "bypassing git hooks with git commit -n" "$_alt" ;;
          esac
          ;;
      esac
      shift
    done
    IFS='
'
  done
  IFS=$_ifs
  return 0
}

# 4) 되돌릴 수 없는 원격 산출물 삭제
#    삭제를 금지한 프로젝트에서만 돈다 — 허용한 조직에 이 규칙을 강요하지 않는다.
guard_remote_delete() {
  GUARD_LABEL=remote-delete
  [ "${ISSUE_DELETE_FORBIDDEN:-0}" = 1 ] || return 0
  for _cli in ${FORGE_CLIS:-}; do
    case "$CMD" in *"$_cli"*) ;; *) continue ;; esac
    _invs=$(invocations_of "$_cli")
    _ifs=$IFS
    IFS='
'
    for _inv in $_invs; do
      IFS=$_ifs
      # shellcheck disable=SC2086
      set -- $_inv
      case "$1" in
        issue | mr | pr | release | milestone)
          shift
          [ "${1:-}" = delete ] &&
            block "deleting an issue, review request or release with $_cli" \
              "this project forbids deleting issues — close a mistaken one with the ${ISSUE_LABEL_INVALID:-invalid} label instead"
          ;;
      esac
      IFS='
'
    done
    IFS=$_ifs
  done
  return 0
}

# 5) 보호 문서를 셸로 고치는 것
#    Edit/Write 도구는 권한 설정이 막지만 그것은 도구를 막은 것이지 행위를 막은 것이 아니다.
#    읽기(cat·grep·sed -n)는 통과하고 쓰기 동작이 함께 있을 때만 막는다.
guard_arch_docs() {
  GUARD_LABEL=arch-doc
  _paths=${PROTECTED_DOCS_RE:-}
  [ -n "$_paths" ] || return 0
  has "$_paths" || return 0
  _write=0
  has ">>?[[:space:]]*['\"]?($_paths)" && _write=1
  has '(^|[[:space:];&|(])(sed[[:space:]]+-[a-zA-Z]*i|tee|patch|dd|cp|mv|rm|install|truncate)([[:space:]]|$)' && _write=1
  [ "$_write" -eq 1 ] &&
    block "editing a protected document from the shell" \
      "agents read these documents as ground truth — if a request conflicts with one, report it instead of editing" \
      "help: if the user explicitly asked for this edit, they run it themselves"
  return 0
}
