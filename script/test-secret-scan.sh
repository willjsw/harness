#!/usr/bin/env bash
# 시크릿 스캔의 회귀 테스트 — 무엇을 잡고 무엇을 지나가는지.
#
#   script/test-secret-scan.sh
#
# 종료 코드: 0 = 전 케이스 통과 · 1 = 실패한 케이스 있음 · 2 = 실행 실패
#
# **지나가는 쪽이 절반이다.** 오탐이 나기 시작하면 사람이 `--no-verify` 를 쓰고, 그 순간
# 이 층은 없는 것과 같아진다. 자리표시자·환경변수 참조·예시 도메인은 잡히면 안 된다.
#
# **표본 값을 이 파일에 문자열 그대로 적지 않는다.** 적으면 이 리포를 스캔할 때 이 파일이
# 걸린다. 조각을 이어 붙여 임시 파일에만 완성된 형태가 생기게 한다.
set -uo pipefail

command -v python3 >/dev/null || { echo "error: python3 is required to run this test" >&2; exit 2; }

# 하네스 루트. 모노레포에서는 리포 루트가 아닐 수 있으므로 스크립트 자신의 위치에서 잡는다.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 2
. "$repo_root/script/harness-format.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

work="$sandbox/repo"
mkdir -p "$work/script"
cp "$repo_root/script/secret-scan.sh" "$repo_root/script/harness-format.sh" "$work/script/"
chmod +x "$work/script/"*.sh

git() { command git -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.invalid "$@"; }
git init -q "$work" || { echo "error: could not create the temp repo" >&2; exit 2; }

pass=0; fail=0
check() { # <ID> <무엇> <기대> <실제>
  if [ "$3" = "$4" ]; then
    pass=$((pass + 1))
  else
    echo "  FAIL $1 $2 → want '$3', got '$4'" >&2; fail=$((fail + 1))
  fi
}

# <내용줄...> 을 파일 하나에 담아 스테이징하고 스캔한다. 종료 코드를 낸다.
scan() { # <파일명> <모드>
  ( cd "$work" && git add -A >/dev/null 2>&1
    script/secret-scan.sh ${2:+"$2"} >"$sandbox/out" 2>"$sandbox/err" )
  echo $?
}
reset_repo() {
  ( cd "$work" && git rm -rq --cached . >/dev/null 2>&1 || true )
  rm -f "$work"/sample*.txt
}
saw() { grep -cF -- "$1" "$sandbox/err" 2>/dev/null || true; }

echo "UT-01 shapes that name their issuer are caught"
reset_repo
{ printf 'aws = "%s%s"\n' AKIA IOSFODNN7EXAMPLE
  printf 'gh  = "%s%s"\n' ghp_ 0123456789abcdefghijklmnopqrstuvwxyz
  printf 'url = "postgres://app:%s@db.internal/app"\n' s3cretpassphrase
  printf -- '-----BEGIN %s PRIVATE KEY-----\n' RSA
} > "$work/sample.txt"
check UT-01 "exit code" 1 "$(scan sample.txt --staged)"
check UT-01 "aws key" 1 "$(saw 'AWS access key id')"
check UT-01 "github token" 1 "$(saw 'GitHub token')"
check UT-01 "credential in a url" 1 "$(saw 'credential embedded in a URL')"
check UT-01 "private key block" 1 "$(saw 'private key block')"
# 값 자체를 출력에 옮기지 않는다 — 막으면서 한 번 더 남기면 막는 의미가 없다.
check UT-01 "does not echo the value" 0 "$(saw 'AKIA')"

echo "UT-02 placeholders and references are left alone"
# 여기서 오탐이 나면 사람이 --no-verify 를 쓰기 시작하고 층 자체가 사라진다.
reset_repo
{ printf 'api_key = "changeme"\n'
  printf 'token = "${ENV_TOKEN}"\n'
  printf 'password = "$DB_PASSWORD"\n'
  printf 'secret = "your-secret-here"\n'
  printf 'client_secret = "<CLIENT_SECRET>"\n'
  printf 'auth_url = "https://example.com/oauth/authorize"\n'
  printf 'token_path = "config/tokens/service.json"\n'
  printf 'password = "aaaaaaaaaaaaaaaaaaaa"\n'
  printf 'secret_class = "com.example.config.SecretHolder"\n'
} > "$work/sample.txt"
check UT-02 "exit code" 0 "$(scan sample.txt --staged)"

echo "UT-03 a secret-ish word inside a longer identifier still counts"
# `db_password`·`AWS_SECRET_ACCESS_KEY` 가 가장 흔한 형태다. 단어 경계만 보면 전부 놓친다.
reset_repo
{ printf 'db_password = "%s"\n' Kd93mZq7XbT2wLp0RvYc8HnE
  printf 'AWS_SECRET_ACCESS_KEY=%s\n' wJalrXUtnFEMIK7MDENGbPxRfiCYEXAMPLEKEY
} > "$work/sample.txt"
check UT-03 "exit code" 1 "$(scan sample.txt --staged)"
check UT-03 "underscored name" 1 "$(saw 'db_password')"
check UT-03 "screaming snake case" 1 "$(saw 'AWS_SECRET_ACCESS_KEY')"

echo "UT-04 a marked line is skipped"
reset_repo
printf 'fixture = "%s%s"  # %s\n' AKIA IOSFODNN7EXAMPLE "$FMT_SECRET_ALLOW" > "$work/sample.txt"
check UT-04 "exit code" 0 "$(scan sample.txt --staged)"

echo "UT-05 what is already committed does not come back every time"
# 파일 전체를 훑으면 기존 값이 매 커밋마다 다시 걸려 몇 번 만에 훅이 꺼진다.
reset_repo
printf 'aws = "%s%s"  # %s\n' AKIA IOSFODNN7EXAMPLE "$FMT_SECRET_ALLOW" > "$work/sample.txt"
( cd "$work" && git add -A >/dev/null && git commit -q -m "chore: 표본" >/dev/null )
# 표지를 떼고 커밋해 "이미 들어와 있는" 상태를 만든다.
( cd "$work" && sed -i.bak "s|  # $FMT_SECRET_ALLOW||" sample.txt && rm -f sample.txt.bak
  git add -A >/dev/null && git commit -q -m "chore: 표지 제거" >/dev/null )
printf 'note = "plain text"\n' >> "$work/sample.txt"
check UT-05 "exit code" 0 "$(scan sample.txt --staged)"

echo "UT-06 --staged looks at the index, not the working tree"
reset_repo
( cd "$work" && git rm -q sample.txt >/dev/null 2>&1 || true
  git commit -q -m "chore: 표본 제거" >/dev/null 2>&1 || true )
printf 'gh = "%s%s"\n' ghp_ 0123456789abcdefghijklmnopqrstuvwxyz > "$work/sample2.txt"
( cd "$work" && script/secret-scan.sh --staged >"$sandbox/out" 2>"$sandbox/err" )
check UT-06 "unstaged file is not in the index" 0 "$?"
( cd "$work" && git add sample2.txt >/dev/null
  script/secret-scan.sh --staged >"$sandbox/out" 2>"$sandbox/err" )
check UT-06 "staged file is" 1 "$?"
# 기본 모드는 작업 트리를 본다.
( cd "$work" && script/secret-scan.sh >"$sandbox/out" 2>"$sandbox/err" )
check UT-06 "the default mode sees it too" 1 "$?"

echo "UT-07 argument validation"
( cd "$work" && script/secret-scan.sh --stage >/dev/null 2>&1 )
check UT-07 "mistyped option — exit code" 2 "$?"
( cd "$work" && script/secret-scan.sh --staged extra >/dev/null 2>&1 )
check UT-07 "too many arguments — exit code" 2 "$?"

echo
if [ "$fail" -gt 0 ]; then
  echo "secret scan test failed: ${pass} passed, ${fail} failed" >&2
  echo "last run output:" >&2
  cat "$sandbox/out" "$sandbox/err" >&2
  exit 1
fi
echo "secret scan test passed: ${pass} cases"
