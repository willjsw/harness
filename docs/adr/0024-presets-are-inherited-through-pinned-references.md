<!--
작성 규칙
- 절 이름(`## Status` 등)은 영어로 고정한다 — 도구가 문자열로 찾아 상태·링크를 조작한다.
- 본문은 프로젝트 문서 언어로 쓴다. 제목·파일명은 영어.
- **`## Status` 절에는 상태 문자열과 도구가 넣는 링크만 둔다.** 주석이나 설명을 넣으면
  대체 링크가 그 뒤로 밀려 상태를 읽기 어려워진다.
-->

# 24. Presets are inherited through pinned references

Date: 2026-10-10

## Status

Proposed

## Context

조직과 스택이 같은 하네스 설정 · 역할 메모 · 절차 메모를 여러 대상 리포에 나눠 쓰려 한다. 프로젝트는 `harness.toml` 의
`extends` 로 preset 을 가리키고, 그 preset 이 다른 preset 을 가리키는 체인으로 상속한다. 받는 명령은 `harness pull` 이고
프로젝트 레이어(`harness.toml`)를 쓰지 않는다. 받기 백엔드는 git 태그로 시작하고 OCI 레지스트리가 뒤따르며, 두 백엔드가
lock 형식을 함께 쓴다. 설정 레이어의 preset 자리는 계층 설정이 비워 두었다. 명세는 `docs/spec/216-org-presets.md`.

이 요구가 지금 규칙과 부딪히는 곳.

- `.harness/` 는 install 이 깐 고정 사본의 자리다(0005). install 은 사본을 갈아 끼울 때 매니페스트 둘만 남기고 `.harness/` 를
  비우고, `docs/spec/58-separate-managed-and-project-parts.md` 2-4 · 4-2 · 4-4 는 `.harness/` 아래 경로의 조치를 `harness install`
  로 안내한다. preset 사본을 `.harness/` 에 두면 하네스를 올리는 install 이 그 사본을 지운다
- 파일 부류는 생성 · 관리 · 소유 셋이고 매니페스트가 그것을 기록한다(0002). 받은 preset 이 어느 부류인지, 그 해시를 어디에 적는지 정한 것이 없다
- 사람마다 SSH 와 HTTPS 로 다르게 받으면 커밋되는 `extends` 와 lock 이 사람마다 달라진다. 테스트는 네트워크 없이 로컬 bare 리포로 원격을 대신한다(`.ai/project/testing.md`)
- lock 의 내용 해시를 무엇으로 계산하는지 정의가 없다. OCI 백엔드는 tar 레이어와 manifest digest 를 다룬다
- 태그가 정확한 버전인지 움직이는 참조인지, preset 버전을 올릴 때 `extends` 를 누가 바꾸는지 정한 것이 없다

검토한 대안.

- `.harness/` 자리 — 항목을 쓰는 명령으로 나누되 preset 파일 해시를 `.harness/managed` 에도 적는다. lock 과 매니페스트가 어긋날 때
  어느 쪽이 정본인지 정하는 규칙이 더 필요하고, 나중에 빼려면 모든 설치본의 매니페스트를 다시 써야 한다
- `.harness/` 자리 — preset 사본을 0002 의 네 번째 부류로 선언하고 0002 를 대체한다. 사본은 render 의 출력이 아니라 입력이라
  갱신이 무엇을 덮는가라는 0002 의 결정이 바뀌지 않는다. CI 게이트 파일 분류도 0002 에 닿으므로 짧은 간격에 대체가 이어진다
- 기록 — 0005 를 대체한다. 0005 의 결정(install 이 깐 사본이 그 리포의 정본이고 전역 CLI 는 넘긴다)은 바뀌지 않으므로
  `.ai/adr.md` 의 대체 규칙(결정이 바뀔 때만 대체)에 맞지 않는다
- 참조 — https 와 ssh(`ssh://` · scp 형식)를 모두 받는다. 같은 preset 을 여러 문자열로 적을 수 있어 lock 과 순환 판정에 정규화 규칙이 필요하다
- 참조 — 스킴 없는 하네스 고유 형식(`<호스트>/<경로>@<태그>`)을 두고 받을 때 https 로 펼친다. OCI 참조(`oci://`)와 형식 규칙이 갈린다
- 내용 해시 — 백엔드 고유 식별자(커밋 id · manifest digest)만 적는다. 사본은 리포 전체가 아니라 커밋 id 를 다시 계산할 수 없어
  리포 안에서 사본을 확인할 수단이 없다
- 내용 해시 — 정규화한 tar(gzip 포함)의 sha256 으로 정의한다. tar 정규화 규칙이 lock 계약에 들어가고 git 백엔드도 tar 를 만들어야 한다
- 고정 참조 — `harness pull <참조>` 가 `extends` 한 줄과 사본 · lock 을 한 번에 바꾼다. pull 이 프로젝트 레이어를 쓰지 않는다는
  원칙을 "값을 복사하지 않는다" 로 좁혀 읽어야 한다
- 고정 참조 — 움직이는 태그를 허용하고 pull 이 lock 만 갱신한다. 같은 `extends` 로 받아도 시점마다 결과가 다르고, 나중에 막으면
  움직이는 태그를 쓰던 리포가 깨진다

## Decision

우리는 프로젝트가 preset 을 git 태그로 고정한 전체 참조로만 상속하게 하고, 받은 체인을 대상 리포의 `.harness/preset/` 사본과
`.harness/preset.lock` 으로 커밋하며, `.harness/` 를 하네스 입력의 사본 자리로 다시 정의해 항목마다 쓰는 명령을 정한다.

- 참조는 `https://<호스트>/<경로>@<태그>` 하나다. 자격증명을 담은 참조와 다른 스킴은 거부하고, 적힌 문자열을 정규화하지 않고 git 에 넘긴다.
  SSH 로 받는 사람은 자기 git 설정의 `insteadOf` 로 바꿔 받는다
- 태그는 정확한 버전이다. 받은 커밋은 lock 의 `resolved` 가 고정하고, 태그가 원격에서 옮겨졌으면 다음 pull 이 경고하고 새 커밋으로 고정한다.
  preset 을 올리는 것은 사람이 `extends` 를 고치고(손으로 또는 `harness set extends`) `harness pull` 하는 것이다. pull 은 `harness.toml` 을 쓰지 않는다
- lock 은 고정 형식의 TOML 이다 — `format = 1` 과, 깊이 순의 항목마다 `source` · `tag` · `resolved` · `content`. 백엔드와 `source` · `tag` · `resolved` 의 형식은
  `source` 의 스킴이 정한다
- `content` 는 백엔드 중립 내용 해시다 — 사본 파일마다 `<파일 바이트의 sha256>  <상대 경로>\n` 를 경로의 UTF-8 바이트 순으로 이은 바이트의 sha256.
  모든 백엔드가 같은 알고리즘으로 계산한다
- `.harness/` 의 고정 사본(`bin` · `lib` · `templates` · `VERSION`)은 install 만, 매니페스트는 render · install 만, preset 사본과 lock 은
  `harness pull` 과 `harness install --preset` 만 쓴다. preset 사본은 render 의 입력이고 매니페스트에 들지 않으며, 그 해시는 lock 에만 있다

출력 부류를 늘리지 않는 것은 사본이 render 의 입력이라 0002 의 갱신 경계에 닿지 않기 때문이고, 해시를 lock 한 곳에만 두는 것은 정본을
하나로 두기 위해서다. 스킴을 https 하나로 좁히는 것은 커밋되는 문자열이 사람마다 같아 정규화 규칙이 필요 없기 때문이고, 내용 해시를
백엔드 중립으로 두는 것은 리포 안의 사본만으로 대조할 수 있고 OCI 백엔드가 같은 lock 을 쓰기 때문이다.

## Consequences

- 0005 를 대체하지 않는다. 고정 사본이 그 리포의 정본이고 전역 CLI 가 넘긴다는 결정은 그대로이고, 이 결정은 같은 원리를 preset 으로 넓힌다.
  install 의 사본 교체는 매니페스트 둘과 preset 사본 · lock 을 남긴다
- 0002 를 대체하지 않는다. 세 부류와 매니페스트 형식은 그대로다. `docs/spec/58-separate-managed-and-project-parts.md` 의 "`.harness/` 아래" 서술
  (2-2 · 2-4 · 4-2 · 4-4)은 고정 사본 부분을 뜻하는 것으로 고친다
- 네트워크는 `harness pull` 과 `harness install --preset` 만 쓴다. render · check · doctor · run 과 CI 는 리포 안의 사본으로 돌고, 클론한 사람과 CI 에게
  preset 리포의 자격증명이 필요 없다
- 설정을 읽는 명령은 사본을 lock 과 대조한다. 사본과 lock 을 함께 고친 변경은 대조가 잡지 못하고 리뷰 요청의 diff 를 사람이 본다.
  원격과 다시 맞춰 보는 검사는 두지 않는다 — lock 이 출처 · 태그 · `resolved` 를 갖고 있어 나중에 더할 수 있다
- `extends` 만 바꾸고 pull 하지 않은 커밋은 pre-commit 의 `check --staged` 가 막는다
- 리포 하나에 preset 하나다. SSH 참조, 짧은 이름, 리포 안의 하위 경로는 받지 않는다. 받는 범위를 넓히는 것은 문법을 더하는 일이지만, 좁히면 기존 `extends` 가 깨진다
- lock 과 내용 해시는 모든 대상 리포에 커밋되고 OCI 백엔드도 같은 형식을 쓴다. 해시 정의를 바꾸려면 `format` 을 올리고 모든 lock 을 다시 써야 한다
- 태그 보호와 서명은 preset 리포 운영의 몫이다. 태그가 원격에서 옮겨진 것은 다음 pull 에서만 보인다
- 사본은 바이트로 대조하므로 줄바꿈을 바꾸는 git 설정(`core.autocrlf`)으로 체크아웃하면 내용이 어긋난다. 관리 파일 대조와 같은 한계다
