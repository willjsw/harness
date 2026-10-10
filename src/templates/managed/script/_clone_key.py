#!/usr/bin/env python3
"""클론 키 — 이 기기에서 하네스 루트 하나를 가리키는 불투명 값, 그리고 설정 값의 자리표시 풀기.

    python3 script/_clone_key.py expand <text>

키는 실행할 때 계산한다. 하네스 루트가 git 트리 안이면 git 공통 디렉터리(실제 경로)와 리포 안의 위치를,
그 밖이면 하네스 루트의 실제 경로를 SHA-256 으로 해시해 `c-` 뒤에 16진 16자를 붙인다.
같은 클론의 worktree 는 공통 디렉터리와 위치가 같아 같은 키다. 같은 리포를 두 번 클론하면 공통 디렉터리가,
모노레포의 두 서브프로젝트는 위치가 달라 키가 다르다. 키는 경로를 드러내지 않는다.

`expand` 는 `{clone}` 과 그 옛 별칭 `{project}` 를 키로 바꾼다. `~` 와 환경 변수는 풀지 않는다.
명령줄은 하네스 루트를 이 파일이 있는 디렉터리의 부모로 보고 결과를 한 줄 낸다. 인자가 맞지 않거나
계산이 실패하면 아무것도 내지 않고 1 로 끝난다.

표준 라이브러리만 쓰고 바이트코드를 남기지 않는다.
"""
import sys

sys.dont_write_bytecode = True

import hashlib  # noqa: E402
import os  # noqa: E402
import subprocess  # noqa: E402

PLACEHOLDERS = ("{clone}", "{project}")
# git 이 리포를 찾는 데 쓰는 지역 변수. 훅 안에서는 이 값들이 넘어와 하네스 루트가 아닌 리포·위치를 답하게 하므로
# 키를 구할 때는 비운다 — 같은 루트는 어디서 불러도 같은 키여야 한다.
GIT_LOCAL_ENV = ("GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_CONFIG", "GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT",
                 "GIT_OBJECT_DIRECTORY", "GIT_DIR", "GIT_WORK_TREE", "GIT_IMPLICIT_WORK_TREE", "GIT_GRAFT_FILE",
                 "GIT_INDEX_FILE", "GIT_NO_REPLACE_OBJECTS", "GIT_REPLACE_REF_BASE", "GIT_PREFIX", "GIT_SHALLOW_FILE",
                 "GIT_COMMON_DIR")


def _rev_parse(root, *args):
    """root 에서 돈 `git rev-parse <args>` 의 출력(끝 개행 제외). git 을 띄우지 못했거나 실패하면 None."""
    env = {k: v for k, v in os.environ.items() if k not in GIT_LOCAL_ENV}
    try:
        r = subprocess.run(["git", "-C", str(root), "rev-parse", *args], capture_output=True, text=True, env=env,
                           stdin=subprocess.DEVNULL)
    except OSError:
        return None
    if r.returncode != 0:
        return None
    return r.stdout[:-1] if r.stdout.endswith("\n") else r.stdout


def clone_key(root) -> str:
    """하네스 루트 root 의 클론 키 — `c-` 와 16진 16자."""
    common = _rev_parse(root, "--path-format=absolute", "--git-common-dir")
    prefix = _rev_parse(root, "--show-prefix") if common else None
    if common and prefix is not None:
        seed = "git\0%s\0%s" % (os.path.realpath(common), prefix)
    else:
        seed = "dir\0%s" % os.path.realpath(str(root))
    return "c-" + hashlib.sha256(seed.encode("utf-8")).hexdigest()[:16]


def expand(text: str, root) -> str:
    """text 의 `{clone}` · `{project}` 를 전부 root 의 클론 키로 바꾼 것. 자리표시가 없으면 git 을 부르지 않는다."""
    if not any(p in text for p in PLACEHOLDERS):
        return text
    key = clone_key(root)
    for p in PLACEHOLDERS:
        text = text.replace(p, key)
    return text


def main(argv) -> int:
    if len(argv) != 2 or argv[0] != "expand":
        return 1
    root = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    try:
        out = expand(argv[1], root)
    except Exception:
        return 1
    sys.stdout.write(out + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
