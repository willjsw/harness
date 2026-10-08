#!/usr/bin/env sh
# 하네스 사용 기록. "무엇이 언제 몇 번" 만 남기고 명령 내용·문서 본문·사람 이름은 남기지 않는다.
#
#   script/usage-log.sh <종류> <출처> [상세]
#
# 종류: block(가드 차단) · preflight(착수 판정) · review(리뷰 회차) · command(커맨드 호출) · note
# 기록 위치: 설정 `usage.log_path` 가 정한다. 그 값이 `off` 면 기록하지 않는다.
# 값의 `{clone}` 은 이 클론의 키로 푼다(script/_clone_key.py).
# 환경변수(설정 `usage.env_var`)로 한 번 덮어쓸 수 있다 — 테스트와 일회성 수집에 쓴다.
# 형식: <ISO시각>|<종류>|<출처>|<상세>|<브랜치유형>
#
# 체크아웃 디렉터리 이름은 남기지 않는다 — 집계가 쓰지 않는데다 사람 이름·이메일을 담은 경로에서
# 실행하면 그 이름이 그대로 기록에 남는다. 브랜치는 이름이 아니라 유형만 남긴다.
#
# **항상 0 으로 끝난다.** 기록은 부수 효과이며, 실패해도 부른 쪽의 판정과 종료 코드를 바꾸지 않는다.
#
# 상세는 자유 문장을 받지 않는다. script/usage-vocab.sh 에 적힌 고정 라벨(`open-mr`)과
# 허용된 키의 `키=값`(`round=3`) 토큰만 통과시키고 나머지는 버린다 — 부르는 쪽이 실수로 명령줄이나
# 문서 본문을 넘겨도 기록에 남지 않게 하는 선이다. **값도 키마다 정해진 형식에만 맞아야 한다** —
# 키만 보고 자유 문자열을 통과시키면 호출부가 잘못 넘긴 사람 이름이 그대로 남는다.
# 출처도 같은 목록으로 제한하고 모르는 값은 other 다.
set -u

. "$(dirname "$0")/usage-vocab.sh"

# 설정을 읽지 못하면 판정할 값이 없으므로 아무것도 기록하지 않는다.
_env="$(dirname "$0")/harness.env"
[ -f "$_env" ] && [ -r "$_env" ] || exit 0
. "$_env"

eval "_override=\${$USAGE_ENV_VAR:-}"
log=${_override:-$USAGE_LOG_PATH}
[ "$log" = "off" ] && exit 0
# 설정 값의 자리표시 {clone}(옛 별칭 {project})은 이 클론의 키로 푼다. 환경 변수로 준 경로는 그대로 쓴다.
# 풀지 못하면(python3 가 없거나 모듈이 실패) 어디에 남길지 모르므로 기록하지 않는다.
if [ -z "$_override" ]; then
  case "$log" in
    *"{clone}"*|*"{project}"*)
      log=$(python3 "$(dirname "$0")/_clone_key.py" expand "$log" 2>/dev/null) || exit 0
      [ -n "$log" ] || exit 0 ;;
  esac
fi

[ $# -ge 2 ] || exit 0
event="$1"
source_name="$2"
detail="${3:-}"

usage_vocab_has "$USAGE_EVENTS" "$event" || event=other

usage_vocab_has "$USAGE_SOURCES" "$source_name" || source_name=other

detail=$(printf '%s' "$detail" | tr '\n\r\t|' '    ' | awk \
  -v labels="$USAGE_LABELS" -v keys="$USAGE_KEY_SPECS" '
  BEGIN {
    n = split(labels, a, " "); for (i = 1; i <= n; i++) ok_label[a[i]] = 1
    n = split(keys, a, " ")
    for (i = 1; i <= n; i++) {
      p = index(a[i], ":")
      if (p > 0) key_re[substr(a[i], 1, p - 1)] = substr(a[i], p + 1)
    }
  }
  {
    out = ""
    for (i = 1; i <= NF; i++) {
      t = $i
      keep = 0
      if (t in ok_label) {
        keep = 1
      } else if (match(t, /^[A-Za-z0-9_-]+=/)) {
        k = substr(t, 1, RLENGTH - 1)
        v = substr(t, RLENGTH + 1)
        if ((k in key_re) && v ~ key_re[k]) keep = 1
      }
      if (keep) out = (out == "" ? t : out " " t)
    }
    print out
  }' | cut -c1-80)

# 브랜치 유형은 설정의 보호 브랜치(공백 구분)와 커밋 태그(| 구분)에서 항목 단위로 판정한다.
# 태그 목록을 case 패턴 자리에 변수로 넣으면 | 가 대안으로 해석되지 않아 아무것도 맞지 않는다.
branch=$(git branch --show-current 2>/dev/null) || branch=""
set -f
if [ -z "$branch" ]; then
  branch_type="-"
else
  branch_type=unknown
  for _p in ${PROTECTED_BRANCHES:-}; do
    if [ "$branch" = "$_p" ]; then branch_type=protected; break; fi
  done
  if [ "$branch_type" = unknown ]; then
    case "$branch" in
      */*)
        _prefix=${branch%%/*}
        _ifs=$IFS; IFS='|'
        for _t in ${COMMIT_TAGS:-}; do
          if [ -n "$_t" ] && [ "$_prefix" = "$_t" ]; then branch_type=$_t; break; fi
        done
        IFS=$_ifs
        ;;
    esac
  fi
fi
set +f

mkdir -p "$(dirname "$log")" 2>/dev/null || exit 0
printf '%s|%s|%s|%s|%s\n' \
  "$(date +%Y-%m-%dT%H:%M:%S)" "$event" "$source_name" "$detail" "$branch_type" \
  >> "$log" 2>/dev/null
exit 0
