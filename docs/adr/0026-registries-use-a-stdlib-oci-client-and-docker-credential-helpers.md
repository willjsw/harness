<!--
작성 규칙
- 절 이름(`## Status` 등)은 영어로 고정한다 — 도구가 문자열로 찾아 상태·링크를 조작한다.
- 본문은 프로젝트 문서 언어로 쓴다. 제목·파일명은 영어.
- **`## Status` 절에는 상태 문자열과 도구가 넣는 링크만 둔다.** 주석이나 설명을 넣으면
  대체 링크가 그 뒤로 밀려 상태를 읽기 어려워진다.
-->

# 26. Registries use a stdlib OCI client and docker credential helpers

Date: 2026-10-10

## Status

Proposed

## Context

preset 은 git 태그(0024)에 더해 OCI 레지스트리로도 배포한다. 첫 대상은 자체 운영 Docker Registry(CNCF Distribution)이고
다음은 Harbor 다. Docker Hub 는 외부 서비스라 조직 preset 을 올리는 일이 사내 승인 사항이어서 보류한다. 명세는
`docs/spec/218-oci-registry.md` 2~8절이다.

제약.

- 하네스 CLI 는 python3 표준 라이브러리만 쓴다(`.ai/project/stack.md` — 의존성 0)
- 레지스트리마다 관리 기능(저장소 생성 · 권한 · 불변 정책 · 복제)과 자격증명을 얻는 방법이 다르다. 아티팩트를 올리고 받는 API 는
  OCI Distribution 규격으로 같다
- 개발자 기기와 CI 에는 레지스트리 자격증명이 이미 docker 설정(`config.json`)과 credential helper 에 있다. forge 인증을 각 CLI 가
  갖고 리포에 두지 않는 것(0006)과 같은 자리다
- 아티팩트 형식(미디어 타입 · annotation 이름 · 레이어 구조)은 올린 뒤 바꾸면 이미 올린 아티팩트를 읽지 못하게 되는 외부 데이터 포맷이다
- 받은 아티팩트는 신뢰하지 않는 입력이다. 대상 리포를 바꾸는 경로는 0017 의 규칙을 지킨다
- 서명 강제는 레지스트리 정책이 맡고, 하네스가 반드시 지키는 것은 lock 의 digest 고정이다

로컬 실측(이슈 #218 댓글, `registry:3` 이미지의 Distribution 3.1.2): empty config · 사용자 정의 `artifactType` · 사용자 정의 레이어
미디어 타입의 manifest 를 받고, 올린 manifest 바이트를 그대로 돌려주며 `Docker-Content-Digest` 가 그 바이트의 sha256 과 같다.
referrers API 는 404 로 없고, `subject` 가 달린 manifest 를 받을 때 `OCI-Subject` 응답 헤더가 없다.

검토한 대안.

- 클라이언트 — 외부 CLI(oras)에 넘긴다. 설치 의존이 하나 늘고, 그 CLI 의 옵션과 출력이 하네스의 계약이 된다. API 가 표준이라
  한 번 구현하면 벤더를 가리지 않으므로, 넘겨서 덜어지는 구현보다 의존의 비용이 크다
- 클라이언트 — 레지스트리 벤더별 API 로 분기한다. 벤더마다 코드가 늘고, 분기의 대부분이 범위 밖인 관리 기능이다
- 자격증명 — 하네스가 자기 파일이나 docker 설정의 `auths`(base64)에 쓴다. 비밀번호가 평문에 가까운 형식으로 기기에 남고 하네스가
  자격증명의 소유자가 된다
- 자격증명 — 비밀번호를 인자 · 환경 변수 · 파이프로도 받는다. 셸 이력 · 프로세스 목록 · CI 로그로 새는 경로가 생긴다
- referrers — 받기(`pull`)에서 연결된 서명이 없으면 경고한다. 서명 강제를 레지스트리에 맡긴 경계가 흐려지고, 하네스가 서명
  아티팩트 형식(Cosign · Notation)을 알아야 한다
- referrers — 쓰지 않고 엔드포인트 6개만 둔다. 레지스트리가 referrers 를 어느 경로로 지원하는지를 `registry check` 가 보고할 수
  없고, 연결된 아티팩트(서명 · SBOM)를 `preset inspect` 가 보일 수 없다
- 재현성 — annotation `created` 를 빌드 시각으로 둔다. 같은 커밋을 다시 빌드하면 manifest digest 가 달라져 "같은 소스면 같은
  digest" 가 manifest 를 바이트 그대로 옮길 때만 성립한다
- 고정 대상 — lock 이 레이어 digest 를 고정하고 manifest digest 는 참고값으로 둔다. manifest 에 든 `requires` annotation 을 lock 이
  지키지 못한다
- 받은 tar — 표준 라이브러리 `tarfile` 의 data 필터 기준을 따른다. 대상 디렉터리 안을 가리키는 심볼릭 링크 · 하드 링크를 허용하고
  이름의 문자 집합을 제한하지 않아 0017 의 경로 규칙보다 느슨하다. `extractall` 은 `guarded_path()` 를 거치지 않는다. `filter`
  인자는 python3 3.11.4 에서 들어와 지원 최저 버전(3.11)의 앞 패치에는 없다

## Decision

우리는 OCI 레지스트리를 표준 라이브러리로 만든 OCI Distribution 클라이언트 하나로 다루고, 레지스트리 자격증명은 docker credential
helper 와 docker 설정에서 읽기만 하며 저장은 헬퍼로만 하고, preset 아티팩트를 같은 커밋에서 같은 바이트가 나오는 OCI image
manifest v1.1 하나로 정한다.

- 클라이언트는 엔드포인트 일곱(end-1 · 2 · 3 · 4a · 6 · 7a · 12a)만 쓰고 벤더 이름으로 분기하지 않는다. referrers API 가 404 면
  referrers 태그 규칙(`sha256-<hex>` 태그의 image index)으로 읽는다. HTTP 는 루프백 호스트에만 쓰고 TLS 검증을 끄는 경로를 두지 않는다
- 자격증명은 `credHelpers` → `credsStore` → `auths` → 익명 순서로 찾고, 401 의 `WWW-Authenticate` challenge 로 토큰을 받는다.
  토큰은 프로세스 메모리에만 둔다. `registry login` 은 헬퍼가 없으면 거부하고, 비밀번호는 터미널에서만 받는다
- referrers 조회 결과는 표시(`preset inspect`)와 기능 탐지(`registry check`)에만 쓴다. 받기 · 올리기의 판정에 쓰지 않고, 하네스는
  referrers 를 올리지 않으며 서명을 만들지도 검증하지도 않는다
- 아티팩트는 empty config, `artifactType` `application/vnd.willjsw.harness.preset.v1`, 레이어 하나
  (`application/vnd.willjsw.harness.preset.layer.v1.tar+gzip`), annotation `org.opencontainers.image.version` · `revision` · `created` ·
  `source` 와 `io.github.willjsw.harness.requires` · `io.github.willjsw.harness.schema` 다
- annotation 값은 빌드 인자와 커밋에서만 온다 — `created` 는 커미터 시각, `revision` 은 커밋 id, `source` 는 정규화한 `origin`.
  tar(USTAR, 경로 바이트 순, 모드 · 소유자 · 시각 고정) · gzip 머리 · JSON 직렬화를 고정한다
- lock 은 OCI preset 의 `resolved` 로 manifest digest 를 고정하고, 내용 해시는 git 백엔드와 같은 알고리즘이다(0024)
- 받은 아티팩트는 digest 를 직접 계산해 대조하고 크기에 상한을 둔다. tar 멤버는 일반 파일과 디렉터리만, 0017 의 경로 규칙을
  ASCII 100바이트로 좁힌 이름만 받은 뒤 git 백엔드와 같은 preset 트리 멤버 판정 함수에 넘기고, 하네스 루트 밖 임시 디렉터리에 푼다
- preset 트리 형식이 바뀌면 annotation `schema` 를, 포장(manifest · 레이어 구조)이 바뀌면 `artifactType` 과 레이어 미디어 타입의
  `v1` 을 올린다

외부 CLI 에 넘기지 않는 것은 표준 API 하나를 구현하는 비용이 의존 0 을 깨고 다른 도구의 출력을 계약으로 삼는 비용보다 작기
때문이고, 자격증명을 쓰지 않는 것은 하네스가 비밀의 저장소가 되지 않기 위해서다.

## Consequences

- 새 레지스트리를 지원하는 일은 코드가 아니라 확인과 문서다 — `registry check --push` 왕복을 통과한 레지스트리만 README 의 지원
  목록에 오른다. 레지스트리가 규격 밖으로 동작하면 그 레지스트리는 목록에 오르지 않는다
- referrers API 가 없는 레지스트리(Distribution 3.1.2)에서는 태그 규칙 경로만 탄다. referrers 는 첫 쪽만 보이고, 두 규칙 밖에서
  연결한 아티팩트는 보이지 않는다
- 하네스는 서명 없는 아티팩트도 받는다. 서명 강제가 필요한 조직은 레지스트리 정책으로 건다
- 다른 환경에서 다시 빌드한 아티팩트는 zlib 출력에 따라 manifest digest 가 다를 수 있다. 내용 해시는 같고, lock 은 0024 의
  "같은 태그가 다른 대상을 가리킨다" 규칙으로 `resolved` 를 갱신한다
- 아티팩트 형식을 바꾸면 이 형식만 아는 하네스는 새 아티팩트를 `not a preset artifact` · `unknown preset schema` 로 거부한다
- identity token 자격증명, IPv6 주소 리터럴로 적은 레지스트리, 루프백 레지스트리의 HTTPS, docker 의 인증서 디렉터리는 다루지 않는다.
  사설 CA 는 `SSL_CERT_FILE` · `SSL_CERT_DIR` 로 준다
- 헬퍼가 없는 기기(CI 등)는 다른 도구가 써 둔 `auths` 를 읽는다. 그런 기기에서 `registry login` 은 쓰지 않는다
- 받은 tar 의 이름을 ASCII 100바이트로 좁히므로 0017 이 허용하는 비ASCII 이름은 레이어에 담지 않는다. 0017 을 대체하지 않는다 —
  그 경로 규칙을 받는 쪽에 적용한 것이다
- `preset` · `registry` 명령은 하네스 루트 밖(preset 리포 · 기기)에서 돌므로 고정 사본으로 넘기지 않는다. `pull` 의 OCI 받기는
  고정 사본의 버전이 하므로, 고정 사본이 이 백엔드보다 오래된 리포는 `harness install` 로 올려야 `oci://` 를 받는다. 0005 를 대체하지 않는다
- 실제 토큰 서버를 상대로 한 인증 흐름은 자동 테스트가 없다. 회귀 테스트는 가짜 레지스트리, CI 통합 잡은 인증 없는 Distribution 을 본다
