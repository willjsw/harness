# preset 의 OCI 레지스트리 백엔드

preset 을 OCI 아티팩트로 만들어(`preset build`) 레지스트리에 올리고(`preset push`), `extends` 의 `oci://` 참조로
받는다(`pull` · `install --preset`). 레지스트리 클라이언트는 표준 라이브러리로 내장하고 OCI Distribution 규격의
엔드포인트 7개만 쓴다. 벤더 이름으로 분기하지 않는다. 자격증명은 docker credential helper 와 `config.json` 에서 읽고,
하네스는 자격증명을 파일에 쓰지 않는다. 받은 아티팩트는 digest 를 직접 계산해 대조하고, 레이어의 멤버는 ADR 0017 의
경로 규칙으로 판정한 뒤 하네스 루트 밖 임시 위치에 푼다.

이 명세는 아래 위에 얹는다. 그 내용은 각 이슈의 명세를 따른다.

| 기대는 것 | 정하는 곳 |
|---|---|
| `src/harness/` 패키지, 명령 하나에 모듈 하나(`src/harness/commands/<명령>.py`), 명령 표와 통과 명령(3-3), git 호출 보조, Python 단위 테스트 자리 `src/test/unit/` 와 실행 `cd src && python3 -B -m unittest discover -s test/unit`, 그것을 도는 `[verify]` 단계 "Python 단위 테스트"(7-5) | #206 |
| `extends`(부모 하나, 커밋되는 파일에는 전체 참조만), preset 트리 형식 — 받는 파일 표와 트리 멤버 판정 함수(3-1 · 3-2), lock(`.harness/preset.lock`)의 키 · 스킴별 판정 · 내용 해시 알고리즘(4-3 · 4-4), 체인 해석, `harness pull` · `install --preset` 의 준비·반영 흐름과 멈춤 조건, 참조의 스킴으로 백엔드를 고르는 자리 | #216 |
| preset 트리에 더해지는 CI 템플릿, 허용 출처 · 최소 버전 검사 | #217 (있으면) |

#206 · #216 은 선행이다. #217 은 선행이 아니다 — 통합 브랜치에 있으면 그 CI 템플릿 경로가 #216 의 받는 파일 표에 들어 레이어에도
들고(3-3), 허용 출처 검사가 OCI 출처로 2-2 의 값을 쓴다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 참조 판정 · 짧은 이름 펼치기 · 기기 기본 레지스트리 파일 | `src/harness/registry/reference.py` |
| 연결 · 리다이렉트 · 크기 상한 · 오류 출력 | `src/harness/registry/transport.py` |
| docker 설정 읽기 · credential helper 실행 · challenge 와 토큰 | `src/harness/registry/auth.py` |
| 엔드포인트 7개 · referrers 조회 | `src/harness/registry/client.py` |
| 아티팩트 쓰기(tar · gzip · manifest · 레이아웃) · 받은 아티팩트 검사 · 풀기 | `src/harness/registry/artifact.py` |
| 명령 `preset` · `registry` | `src/harness/commands/preset.py` · `src/harness/commands/registry.py` |
| OCI 백엔드(preset 받기의 `oci://` 자리) | #216 이 정한 preset 백엔드 자리 |
| 가짜 레지스트리 · 스텁 헬퍼 | `src/test/fake_registry.py` · `src/test/stub-credential-helper` |
| 단위 테스트 | `src/test/unit/test_registry_*.py` |
| 회귀 테스트 | `src/test/render-test.sh` |
| 통합 테스트 | `src/test/integration/test_registry.py` · `.github/workflows/registry-integration.yml` |
| 지원 목록 · 사람용 설명 | `README.md` |

## 1. 바뀌는 것과 바뀌지 않는 것

- 명령 둘이 생긴다 — `harness preset build|inspect|push`, `harness registry login|logout|use|check` (8절).
  둘 다 하네스 루트 밖(preset 리포 · 기기)에서 돌므로 고정 사본으로 넘기지 않는다
- `extends` 에 `oci://` 전체 참조가, lock 의 `source` 에 태그를 뺀 `oci://` 출처가 생긴다 (2절 · 8-8)
- 기기 단위 상태에 파일 하나가 생긴다 — 등록부 최상위의 `oci.json` (2-3)
- 설정 키와 생성 파일은 늘지 않는다 — `plan()` 에 등록할 것이 없다
- 네트워크를 쓰는 것은 두 명령과 `pull` · `install --preset` 의 OCI 받기뿐이다. render · check · doctor · status 는
  레지스트리에 붙지 않는다 — vendoring 과 lock 이 커밋되어 있어 오프라인으로 대조한다(#216)
- 하네스는 서명을 만들지도 검증하지도 않는다. 서명 강제는 레지스트리 정책이 맡고, 하네스가 반드시 지키는 것은 lock 의
  digest 고정이다
- 레지스트리 벤더 관리 기능(저장소 생성 · 권한 · 불변 정책 · 복제)은 다루지 않는다
- `harness doctor` 의 `registry` 절은 지금처럼 설치 등록부를 가리킨다. 이름을 바꾸지 않는다
- `.claude/settings.json` 의 허용 목록에 새 명령을 넣지 않는다 — 에이전트가 부르면 사람의 승인을 받는다
- UI 는 바뀌지 않는다

## 2. 참조

### 2-1. 전체 참조

```
oci://<레지스트리>/<저장소>:<태그>
```

| 부분 | 규칙 |
|---|---|
| `<레지스트리>` | `<호스트>[:<포트>]`. 호스트는 소문자 DNS 이름(`[a-z0-9]([a-z0-9-]*[a-z0-9])?` 를 `.` 로 이은 것)이나 IPv4 주소. 포트는 1–65535 |
| `<저장소>` | `[a-z0-9]+((\.\|_\|__\|-+)[a-z0-9]+)*(/[a-z0-9]+((\.\|_\|__\|-+)[a-z0-9]+)*)*` |
| `<태그>` | `[A-Za-z0-9_][A-Za-z0-9._-]{0,127}` |

- 커밋되는 파일의 `extends`(`harness.toml` · preset 트리의 `preset.toml`)에는 이 형식만 쓴다. lock 은 이것을 출처(2-2)와
  태그로 나눠 담는다 (8-8)
- 태그는 정확한 버전이다(#216). 고정은 lock 의 해석된 식별자(manifest digest)가 한다
- `oci://<레지스트리>/<저장소>@sha256:<64자리 16진>` 형식의 digest 참조는 `preset inspect` 의 입력에서만 받는다

`extends` 판정 — `oci://` 로 시작하는 `extends` 는 이 규칙으로 판정한다. 그 밖의 값은 #216 2-1 이 판정한다(11-2).
어긋남과 사유는 위에서부터 처음 맞는 하나다.

| 어긋남 | 사유 |
|---|---|
| `oci://` 뒤 첫 `/` 앞에 `@` 가 있다(자격증명) | `it carries credentials` |
| `oci://` 뒤 첫 `/` 다음에 `@` 가 있다(digest 참조) | `it is a digest reference` |
| `oci://` 뒤 첫 `/` 다음에 `:` 가 없다(태그 없음) | `it has no :<tag>` |
| 그 밖의 형식 어긋남(대문자 호스트, 규칙 밖 문자, 포트 범위, 저장소 · 태그 규칙) | `not a full OCI reference` |

거부 안내는 **값을 옮기지 않는다.** 종료 코드 2.

```
error: extends is not a full OCI reference (it has no :<tag>)
  --> harness.toml

help: extends takes oci://<registry>/<repository>:<tag> — the harness reads registry credentials from the docker config
```

- `-->` 는 그 `extends` 를 담은 파일이다. preset 의 `extends` 면 `preset.toml of <그 preset 의 참조>` 다 — #216 2-1 과 같다
- 사유가 `it carries credentials` 일 때만 둘째 help 줄 `      if that credential was ever committed, revoke it and issue a new one` 을
  낸다 — #216 2-1 과 같다

### 2-2. 태그를 뺀 출처

`oci://<레지스트리>/<저장소>` 다. 전체 참조에서 마지막 `:` 와 그 뒤(태그)를 뗀 문자열 그대로이고, 정규화하지 않는다.
레지스트리의 포트는 첫 `/` 앞에 있고 저장소 · 태그에는 `:` 가 없으므로 마지막 `:` 가 태그의 구분자다.

- lock 의 `source` 가 이 값이다 (8-8)
- #216 이 OCI 출처를 비교하는 곳 — 순환 판정(2-3), 체인 연결 · 프로젝트 참조 대조(5-1) — 은 참조를 이 값과 태그로 나눠
  비교한다. 메모 절 제목(6-2)의 `<출처>` 도 이 값이다
- #217 이 있으면 그 허용 출처 검사가 OCI 출처로 이 값을 쓴다
- 출처와 태그를 다시 이으면 `<출처>:<태그>` 로 전체 참조가 된다. #216 의 안내문 · 출력 · schema 가 preset 을 그 스킴의 참조
  형식으로 적는 자리(#216 4-3)에는 OCI preset 의 이 전체 참조가 든다

### 2-3. 짧은 이름과 기기 기본 레지스트리

CLI 입력은 짧은 이름 `<저장소>[:<태그>]` 도 받는다 — `preset push` · `preset inspect` · `registry check` ·
`install --preset`. 입력 시점에 기기 기본 레지스트리로 `oci://<기본 레지스트리>/<저장소>[:<태그>]` 로 펼치고, 그 뒤로는
전체 참조만 다룬다. `install --preset` 이 씨앗 설정의 `extends` 에 쓰는 값도 펼친 값이다.

- 입력 판정 순서: `oci://` 로 시작하면 전체 참조, `https://` 로 시작하면 git 참조(#216), 그 밖은 짧은 이름
- 짧은 이름의 첫 성분이 `.` 이나 `:` 를 담거나 `localhost` 면 호스트로 읽힐 수 있으므로 거부한다 —
  `error: write the full reference (oci://<registry>/<repository>:<tag>)`, 종료 코드 2
- 기기 기본 레지스트리가 없으면 짧은 이름을 거부한다. 다른 레지스트리(Docker Hub 포함)로 대신 펼치지 않는다

```
error: no default registry is set on this machine
  --> team/preset:1.4.0

help: write the full reference, or set a default registry
        harness registry use <registry>
```

종료 코드 2.

기기 기본 레지스트리 파일:

- 위치는 등록부(`HARNESS_HOME` 이 있으면 그 경로, 없으면 `~/.harness`) 최상위의 `oci.json` 이다. 파일이므로
  `docs/spec/96-machine-local-state-key.md` 3-1 의 분류에서 기기 단위 기록이다
- 내용은 `{"default_registry": "<레지스트리>"}` 하나다. 값은 2-1 의 `<레지스트리>` 규칙을 따른다
- `registry use` 만 쓴다 (8-6). 같은 디렉터리의 임시 파일에 쓴 뒤 이름을 바꾸고, 권한은 `0600` 이다. 등록부 디렉터리가
  없으면 `0700` 으로 만든다
- 읽을 때 JSON 이 아니거나 값이 규칙에 어긋나면 펼치지 않고 멈춘다 — `error: cannot read the default registry`,
  `-->` 파일 경로, `help:` 에 `harness registry use <registry>`. 종료 코드 2. 파일 내용은 출력하지 않는다
- 커밋되는 파일에는 들어가지 않는다. 기기마다 기본값이 달라도 생성물과 lock 은 같다

## 3. 아티팩트 형식

### 3-1. manifest

OCI image manifest v1.1 하나가 아티팩트다.

```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "artifactType": "application/vnd.willjsw.harness.preset.v1",
  "config": {
    "mediaType": "application/vnd.oci.empty.v1+json",
    "digest": "sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
    "size": 2
  },
  "layers": [
    {
      "mediaType": "application/vnd.willjsw.harness.preset.layer.v1.tar+gzip",
      "digest": "sha256:<레이어 digest>",
      "size": <레이어 바이트 수>
    }
  ],
  "annotations": { "3-2 의 키": "값" }
}
```

- config 는 빈 설명자다. 그 blob 은 2바이트 `{}` 다
- 레이어는 하나다. 레이어 설명자에는 annotation 을 두지 않는다
- 직렬화: 키를 정렬하고, 구분자에 공백을 두지 않으며(`,` · `:`), ASCII 밖 문자는 `\u` 로 이스케이프하고, 끝 줄바꿈이 없다.
  manifest digest 는 이 바이트의 sha256 이다

### 3-2. annotation

| 키 | 값 | 어디서 |
|---|---|---|
| `org.opencontainers.image.version` | `--tag` 값. 올릴 태그와 같다 | 빌드 인자 |
| `org.opencontainers.image.revision` | 빌드한 커밋의 전체 id | `git rev-parse HEAD` |
| `org.opencontainers.image.created` | 그 커밋의 커미터 시각. UTC, `YYYY-MM-DDTHH:MM:SSZ` | `git log -1 --format=%ct HEAD` |
| `org.opencontainers.image.source` | preset 리포 `origin` 을 아래 표로 정규화한 URL | `git remote get-url origin` |
| `io.github.willjsw.harness.requires` | preset 트리가 선언한 요구 하네스 버전 문자열 그대로 | preset 트리(#216) |
| `io.github.willjsw.harness.schema` | 레이어가 담은 preset 트리 형식의 버전. 이 명세의 형식은 `1` | 상수 |

- 빌드 시각 · 빌드한 사람 · 기기에서 오는 값은 넣지 않는다. 같은 커밋을 누가 언제 빌드해도 annotation 이 같다
- `requires` 는 preset 트리가 선언하지 않았으면 키를 두지 않는다. `source` 는 정규화할 수 없으면 키를 두지 않는다
- `schema` 는 preset 트리 형식이 바뀌어 이 형식만 아는 하네스가 읽지 못하게 될 때 올린다. 아티팩트 포장(manifest ·
  레이어 구조)이 바뀌면 `artifactType` 과 레이어 미디어 타입의 `v1` 을 올린다

`source` 정규화:

| `origin` | 결과 |
|---|---|
| `https://[<userinfo>@]<호스트>[:<포트>]/<경로>` | `https://<호스트>[:<포트>]/<경로>` |
| `http://` · `ssh://` · `git://` 로 시작하는 `[<userinfo>@]<호스트>[:<포트>]/<경로>` | `https://<호스트>/<경로>` |
| `[<사용자>@]<호스트>:<경로>` (scp 형식) | `https://<호스트>/<경로>` |
| 그 밖(`file://` · 로컬 경로 · `origin` 없음) | 키를 두지 않는다 |

모든 경우 호스트를 소문자로 바꾸고, 경로 끝의 `/` 와 `.git` 을 떼며, userinfo(자격증명 포함)를 버린다. 결과는 #216 의
git `extends` 형식(`https://<host>/<path>`)과 같은 꼴이다.

### 3-3. 레이어

레이어는 preset 트리의 파일을 담은 tar 를 gzip 으로 압축한 것이다. 어떤 파일이 preset 트리에 드는지는 #216 의 받는 파일
표(3-1)와 트리 멤버 판정 함수(3-2)가 정한다 — #217 이 있으면 그것이 더하는 행도 든다. 이 절은 그 파일들을 바이트로 묶는
규칙만 정한다.

이름 규칙 — 빌드(8-1)와 받기(4-2)가 같이 쓴다.

- ADR 0017 의 경로 규칙(성분이 `[\w.-]+`, 절대 경로 · 빈 성분 · 끝의 `/` · `.` · `..` 성분 없음)에 더해, 성분은 ASCII
  `[A-Za-z0-9_.-]+` 이고 경로 전체는 100바이트 이하다
- #216 의 받는 파일 표의 경로는 이 규칙 안에 있다 — `<이름>` 이 `[a-z][a-z0-9-]{1,30}` 이라 가장 긴 경로도 100바이트에 못
  미친다. 표에 행을 더할 때도 이 규칙 안의 경로여야 레이어에 담긴다

tar:

| 항목 | 값 |
|---|---|
| 형식 | USTAR (`tarfile.USTAR_FORMAT`) |
| 멤버 | #216 의 함수가 받을 파일로 고른 일반 파일만. 디렉터리 항목을 넣지 않는다 |
| 순서 | 경로의 바이트 순 |
| 이름 | 트리 루트 기준 상대 경로. `./` 를 붙이지 않는다 |
| 모드 | `0644` |
| uid · gid | 0 |
| uname · gname | 빈 문자열 |
| mtime | 0 |
| 내용 | HEAD 커밋의 blob 바이트 그대로. 줄바꿈 변환 · git 필터를 거치지 않는다 |

gzip:

- 머리 10바이트는 고정값 `1f 8b 08 00 00 00 00 00 02 ff` 다 — 이름 · 주석 · 추가 필드 없음, mtime 0, OS 255.
  파이썬 버전과 상관없이 같은 바이트여야 하므로 하네스가 직접 쓴다
- 본문은 zlib raw deflate(레벨 9)이고, 끝에 CRC32 와 원래 크기를 리틀 엔디언 4바이트씩 붙인다

### 3-4. 빌드 출력 — OCI Image Layout

```
<출력 디렉터리>/
├── oci-layout                 {"imageLayoutVersion":"1.0.0"}
├── index.json
└── blobs/sha256/<hex>         빈 config · 레이어 · manifest
```

- `index.json` 은 `schemaVersion` 2, `mediaType` `application/vnd.oci.image.index.v1+json`, `manifests` 에 manifest
  설명자 하나다. 그 설명자는 `artifactType` 과 annotation `org.opencontainers.image.ref.name`(= 태그)을 갖는다
- 두 JSON 파일의 직렬화는 3-1 과 같다
- 레이아웃을 읽는 쪽(`preset inspect` · `preset push`)은 `oci-layout` 의 버전이 `1.0.0` 이고 `index.json` 의 manifest
  설명자가 하나이며 blob 마다 파일 이름 · 크기 · sha256 이 설명자와 맞는지 본다. 그 밖의 파일은 읽지 않는다

### 3-5. 재현성

| 같은 것 | 같아지는 값 |
|---|---|
| 커밋 · 태그 · 정규화한 `origin` · 하네스의 아티팩트 형식 | tar 바이트, annotation, preset 트리의 내용 해시(#216) |
| 위에 더해 zlib 의 deflate 출력 | 레이어 digest, manifest digest |

- 내용 해시는 백엔드 · 압축과 상관없이 같은 트리에서 같다. 같은 커밋을 git 백엔드로 받아도 같다
- 레지스트리 사이에서 manifest 와 blob 을 바이트 그대로 옮기면 manifest digest 가 같다. 다른 환경에서 다시 빌드해
  올린 아티팩트는 manifest digest 가 다를 수 있다. 그 경우 pull 은 #216 의 "같은 태그가 다른 대상을 가리킨다" 규칙으로
  해석된 식별자를 갱신하고, 내용 해시는 그대로다

## 4. 받은 아티팩트 검사

레지스트리의 응답과 받은 tar 는 신뢰하지 않는 입력이다. pull · `install --preset` · `preset inspect` · `preset push`
(레이아웃을 읽을 때) · `registry check --push` 가 같은 검사를 쓴다.

### 4-1. manifest

위에서부터 판정하고, 처음 어긋난 사유를 낸다.

| 검사 | 사유 |
|---|---|
| 본문이 4 MiB 이하다 | `manifest too large` |
| digest 로 받았으면 본문 sha256 이 그 digest 와 같다. 태그로 받았으면 본문 sha256 을 해석된 식별자로 쓴다 | `digest mismatch` |
| `Docker-Content-Digest` 응답 헤더가 있으면 본문 sha256 과 같다 | `digest mismatch` |
| JSON 객체이고 `schemaVersion` 이 2, `mediaType` 이 `application/vnd.oci.image.manifest.v1+json` 이다 | `not an OCI image manifest` |
| `artifactType` 이 `application/vnd.willjsw.harness.preset.v1` 이다 | `not a preset artifact` |
| `config` 가 3-1 의 빈 설명자와 같다 | `unexpected config` |
| `layers` 가 하나이고, 미디어 타입이 3-1 의 것이며, `digest` 가 `sha256:<64자리 16진>` 이다 | `expected one preset layer` |
| 레이어 `size` 가 16 MiB 이하다 | `layer too large` |
| `io.github.willjsw.harness.schema` 가 `1` 이다 | `unknown preset schema` |

```
error: not a harness preset artifact (<사유>)
  --> <참조>
```

종료 코드 1. 레지스트리에서 온 값(미디어 타입 · annotation)은 이 문구에 옮기지 않는다.

### 4-2. 레이어와 멤버

판정은 두 단계다 — tar 전용 검사를 먼저 하고, 통과한 멤버를 #216 3-2 의 트리 멤버 판정 함수에 넘긴다. 어떤 항목이 preset
트리에 드는지는 git 백엔드와 같은 그 함수가 정하고, tar 전용 검사는 tar 의 바이트 · 멤버 종류 · 이름만 본다.

tar 전용 검사:

- blob 은 설명자의 `size` 만큼만 읽는다. 더 오면 거부한다. sha256 이 설명자의 digest 와 다르면 거부한다
- 풀어낸 tar 가 64 MiB 를 넘으면 그 자리에서 멈추고 거부한다. 멤버는 2,048 개 이하다
- 멤버마다 판정한다

| 판정 | 사유 |
|---|---|
| 일반 파일(`REGTYPE` · `AREGTYPE`)이나 디렉터리(`DIRTYPE`)다. 심볼릭 링크와 하드 링크는 따로 사유를 붙인다 | `a symbolic link` · `a hard link` · `not a regular file or directory` |
| 이름이 3-3 의 이름 규칙에 맞는다. 디렉터리 멤버는 끝의 `/` 를 떼고 본다 | `not a safe path` |
| 같은 이름이 두 번 나오지 않고, 파일 이름이 다른 멤버의 부모 경로가 되지 않는다 | `a duplicate name` |

- 표준 라이브러리에 `tarfile.data_filter` 가 있으면 위 판정을 통과한 멤버에 그 필터도 적용하고, 필터가 거부하면 사유
  `rejected by the tar data filter` 로 거부한다. 판정의 기준은 위 표이고 필터는 보조다
- 크기 · 개수 상한의 사유는 `too large` · `too many members` 다

#216 의 함수:

- 멤버 전부를 tar 의 순서대로 (경로, 종류) 목록으로 넘긴다. 일반 파일은 파일, 디렉터리는 끝의 `/` 를 뗀 경로의 디렉터리다.
  tar 전용 검사를 모두 통과한 뒤라 목록의 순번이 멤버 번호와 같다
- 함수가 거부하면 그 사유와 순번을 아래 문구로 낸다. `preset.toml` 이 없어 거부하면 첫 줄이
  `error: the preset layer has no preset.toml at its root` 다
- 함수가 받지 않은 항목으로 돌려준 멤버(받는 디렉터리 밖이고 받는 파일 표에 없는 것)가 하나라도 있으면 거부한다. 사유는
  `outside the preset tree`, 번호는 그 첫 멤버의 것이다. 하네스가 빌드한 레이어(8-1)에는 그런 멤버가 없다
- 레이어에서 받는 파일은 함수가 받을 파일로 돌려준 멤버다 (4-3)

```
error: the preset layer has a member the harness does not accept (<사유>, member <번호>)
  --> <참조>
```

- 종료 코드 1. `pull` · `install --preset` 에서는 8-8 이다
- 멤버 이름은 출력하지 않는다. #216 의 안내문이 받은 이름을 옮기지 않는 것과 같은 정책이다
- `<번호>` 는 tar 안에서 1 부터 센 순번이다. `<참조>` 는 받은 참조이고, 레이아웃을 읽을 때는 레이아웃 디렉터리다

### 4-3. 풀기

- 하네스 루트 밖의 임시 디렉터리(`tempfile.mkdtemp()`)에 푼다. `extractall` 을 쓰지 않고, 4-2 에서 받는 파일의
  내용만 읽어 직접 쓴다. 파일에 필요한 부모 디렉터리만 만든다 — 디렉터리 멤버로는 아무것도 만들지 않는다
- tar 의 모드 · 소유자 · 시각은 버린다. 파일은 `0644`, 디렉터리는 `0755` 다
- 멤버 하나라도 거부되면 임시 디렉터리를 지우고 아무것도 넘기지 않는다
- 대상 리포에 반영하는 것은 #216 의 반영 단계이고, ADR 0017 의 사전 판정과 `guarded_path()` 를 거친다. 이 백엔드는 대상
  리포에 직접 쓰지 않는다
- 명령이 끝나면 성공 · 실패와 상관없이 임시 디렉터리를 지운다

## 5. 전송

### 5-1. 엔드포인트

| ID | 메서드 · 경로 | 쓰는 곳 |
|---|---|---|
| end-1 | `GET /v2/` | challenge 확인 — `registry check` · `registry login` |
| end-2 | `GET` · `HEAD /v2/<저장소>/blobs/<digest>` | 레이어 받기, push 전에 blob 이 있는지 |
| end-3 | `GET` · `HEAD /v2/<저장소>/manifests/<태그 또는 digest>` | manifest 받기, push 전에 태그 확인, referrers 태그 규칙 읽기 |
| end-4a | `POST /v2/<저장소>/blobs/uploads/` | 업로드 세션 열기 |
| end-6 | `PUT <Location>?digest=<digest>` | blob 을 한 번에 올리기 |
| end-7a | `PUT /v2/<저장소>/manifests/<태그>` | manifest 올리기 |
| end-12a | `GET /v2/<저장소>/referrers/<digest>` | referrers 조회 |

이 밖의 엔드포인트(삭제 · 태그 목록 · 마운트 · 청크 업로드 · referrers 필터)는 쓰지 않는다.

### 5-2. 연결

- 루프백 호스트(`localhost` 와 `127.0.0.0/8`)는 HTTP, 그 밖은 HTTPS 다. 다른 조합은 없다. `localhost` 는 이름을 해석한
  주소가 전부 루프백일 때만 루프백으로 본다
- HTTPS 연결에는 `ssl.create_default_context()` 로 만든 컨텍스트를 명시해 넘긴다. 인증서와 호스트 이름 검증을 끄는
  옵션 · 환경 변수 · 설정을 두지 않는다
- 사설 CA 는 OpenSSL 이 읽는 `SSL_CERT_FILE` · `SSL_CERT_DIR` 로 준다. 검증 실패 안내가 이 둘을 알린다

```
error: the certificate of the registry did not verify
  --> <참조>

help: if the registry uses a private CA, point SSL_CERT_FILE or SSL_CERT_DIR at it
```

- 프록시: 루프백에는 쓰지 않는다. 그 밖에는 표준 라이브러리가 읽는 환경 변수(`HTTPS_PROXY` · `NO_PROXY` 등)를 따른다
- 요청마다 제한 시간은 30초이고, 다시 시도하지 않는다. `User-Agent` 는 `harness/<버전>` 이다

### 5-3. 리다이렉트와 크기

- 리다이렉트는 5번까지 따라간다. 대상이 5-2 를 어기면(루프백이 아닌데 HTTP) 멈춘다
- `Authorization` 은 레지스트리 호스트로 가는 요청과 토큰 요청(6-2)에만 붙인다. 리다이렉트로 다른 호스트(blob 저장소 등)에
  가면 붙이지 않는다
- 업로드 `Location` 이 상대 경로면 레지스트리 기준으로 푼다. 절대 URL 이면 5-2 를 거치고, 호스트가 다르면 `Authorization` 을
  붙이지 않는다
- 응답 본문 상한: manifest · index 4 MiB, 토큰 · 오류 JSON 1 MiB, blob 은 설명자 크기. 넘으면 읽기를 멈추고 실패한다

### 5-4. 오류 출력

```
error: the registry answered <상태 코드> to <동작> (<OCI 오류 코드>)
  --> <참조>
```

- `<동작>` 은 `the API check` · `a manifest request` · `a blob request` · `a blob upload` · `a manifest upload` ·
  `a referrers request` · `a token request` 가운데 하나다
- 오류 코드는 응답 JSON `errors[].code` 가운데 `[A-Z_]+` 에 맞는 것만 옮긴다. 없으면 괄호를 내지 않는다
- 오류의 `message` · `detail`, 응답 본문, 헤더, URL(쿼리 포함)은 옮기지 않는다
- 연결 실패와 제한 시간 초과는 `error: cannot reach the registry (<예외 이름>)` 이다
- 종료 코드 1

## 6. 인증

### 6-1. 자격증명 찾기

docker 설정 파일은 `DOCKER_CONFIG` 가 있으면 `$DOCKER_CONFIG/config.json`, 없으면 `~/.docker/config.json` 이다.
하네스는 이 파일을 읽기만 한다.

레지스트리 `<호스트>[:<포트>]` 의 자격증명을 이 순서로 찾고, 처음 찾은 것을 쓴다.

1. `credHelpers` 에 이 레지스트리 항목이 있으면 그 헬퍼의 `get`
2. `credsStore` 가 있으면 그 헬퍼의 `get`
3. `auths` 에 있는 이 레지스트리 항목의 `auth`(base64 `<사용자>:<비밀번호>`)
4. 없으면 익명

- `auths` · `credHelpers` 의 키는 스킴(`https://` · `http://`)과 경로를 떼고 소문자로 바꿔 `<호스트>[:<포트>]` 와 비교한다
- 헬퍼의 `get` 이 0 이 아닌 코드로 끝나면 그 헬퍼에는 자격증명이 없는 것으로 보고 다음 순서로 간다
- 헬퍼에 주는 서버 값(ServerURL)은 `<호스트>[:<포트>]` 다. docker 가 같은 헬퍼에 저장한 항목을 이 값으로 찾는다
  <!-- TBD: 확인 필요 — docker 가 helper 에 저장할 때 쓰는 ServerURL 표기와 같은지 실측하지 않았다 -->
- 헬퍼가 주는 사용자 이름이 `<token>` 이거나 `auths` 항목에 `identitytoken` 만 있으면(identity token) 다루지 않는다 —
  `error: the credentials for this registry are an identity token, which the harness does not support`, 종료 코드 1
- 설정 파일이 없으면 익명이다. JSON 이 아니면 `error: cannot read the docker config` 와 `-->` 파일 경로, 종료 코드 2.
  내용은 출력하지 않는다
- 헬퍼가 없는 기기(CI 등)는 다른 도구가 써 둔 `auths` 를 읽는다. `harness registry login` 은 헬퍼가 없으면 저장하지 않으므로
  (8-4) 그런 기기에서는 쓰지 않는다

### 6-2. challenge 와 토큰

요청이 401 이면 `WWW-Authenticate` 를 읽는다.

| challenge | 동작 |
|---|---|
| `Bearer realm=…,service=…[,scope=…]` | `GET <realm>?service=<service>&scope=<scope>` 로 토큰을 받는다. scope 는 challenge 에 있으면 그것, 없으면 명령에 필요한 것이다 — 받기 `repository:<저장소>:pull`, 올리기 `repository:<저장소>:pull,push`, end-1 확인은 scope 없이. 자격증명이 있으면 Basic 으로 붙이고, 없으면 붙이지 않는다(익명 토큰). 응답 JSON 의 `token`, 없으면 `access_token` 을 쓴다 |
| `Basic` | 자격증명이 있으면 Basic 으로 다시 보낸다 |

- 원래 요청은 한 번만 다시 보낸다. 다시 401 · 403 이면 5-4 의 오류다
- 자격증명이 필요한데 없거나 challenge 를 모르면 멈춘다

```
error: the registry needs credentials
  --> <참조>

help: log in through a docker credential helper, or let another tool write them to the docker config
        harness registry login <registry>
```

종료 코드 1.

- realm 도 5-2 를 따른다 — 루프백이 아니면 HTTPS
- 토큰은 프로세스 메모리에만 두고, 한 명령 안에서 realm · service · scope 별로 다시 쓴다

### 6-3. 헬퍼 실행

- 헬퍼 이름(`credsStore` · `credHelpers` 의 값)은 `[A-Za-z0-9][A-Za-z0-9_.-]*` 여야 한다. 어긋나면 부르지 않고
  `error: the credential helper name in the docker config is not valid` 로 멈춘다. 종료 코드 2
- 실행 파일은 PATH 의 `docker-credential-<이름>` 이다. 없으면 `error: docker-credential-<이름> is not on PATH`, 종료 코드 2
- 셸을 거치지 않고 인자 하나(`get` · `store` · `erase`)로 부르며, 입력은 표준 입력으로 준다. 제한 시간은 30초다
- `get` · `erase` 의 입력은 `<호스트>[:<포트>]`, `store` 의 입력은 `{"ServerURL": …, "Username": …, "Secret": …}` JSON 이다.
  `get` 의 출력은 `Username` · `Secret` 을 담은 JSON 이다
- 헬퍼의 표준 출력과 표준 오류를 출력에 옮기지 않는다. 실패는 헬퍼 이름과 종료 코드만 낸다

### 6-4. 남기지 않는 것

자격증명 · 토큰 · `Authorization` 헤더 · 헬퍼 입출력 · URL 쿼리를 표준 출력 · 표준 오류 · 실행 지표 · 사용 기록 · 파일
어디에도 남기지 않는다. 하네스가 자격증명을 쓰는 곳은 헬퍼의 `store` 하나다.

## 7. referrers

- 조회 결과는 표시와 기능 탐지에만 쓴다 — `preset inspect` 가 연결된 아티팩트 목록을 보이고, `registry check --push` 가
  referrers API 지원 여부를 보고한다. pull · push 의 어떤 판정에도 쓰지 않는다
- 조회의 subject 는 manifest digest 다
  1. end-12a 가 200 이면 본문(image index)의 `manifests` 가 목록이다. 경로는 `api`
  2. 404 면 referrers 태그 규칙으로 읽는다 — end-3 으로 태그 `sha256-<64자리 16진>` 의 image index 를 받는다. 200 이면 그
     `manifests`, 404 면 빈 목록이다. 경로는 `fallback`
  3. 그 밖의 상태는 조회 실패다
- index 는 4 MiB 상한과 `mediaType`(`application/vnd.oci.image.index.v1+json`) 검사를 거친다. 항목은 `artifactType` ·
  `digest` · `size` 만 읽는다
- 응답 `Link` 헤더에 `rel="next"` 가 있으면 따라가지 않고 `note: the registry lists more referrers than shown` 을 낸다
- 하네스는 referrers 를 쓰지 않는다 — `subject` 가 달린 manifest 도, 태그 규칙의 index 도 올리지 않는다

## 8. 명령

공통:

- 터미널 출력은 영어다(ADR 0011)
- 레지스트리에서 온 문자열(annotation 값 · referrers 의 `artifactType`)을 출력할 때는 제어 문자를 `\x<16진 두 자리>` 로
  이스케이프한다

| 종료 코드 | 뜻 |
|---|---|
| 0 | 성공 |
| 1 | 원격 실패, 받은 아티팩트 검사 실패, `registry check` 의 FAIL, 확인을 받지 않은 덮어쓰기 |
| 2 | 입력 거부 — 참조 형식, 기본 레지스트리 없음, 헬퍼 없음, 터미널이 아님, 출력 · 소스 디렉터리, docker 설정 |

이 표는 `preset` · `registry` 명령의 것이다. `pull` · `install --preset` 의 종료 코드는 #216 을 따른다 (8-8).

### 8-1. `harness preset build`

```
harness preset build --tag <태그> --output <디렉터리> [--source <디렉터리>]
```

- `--source` 의 기본값은 현재 디렉터리다. git 작업 트리의 최상위여야 한다 — 아니면 `error: --source must be the top of a
  git work tree`, 종료 코드 2
- 내용은 HEAD 커밋에서 읽는다(`git ls-tree` · `git cat-file`). 작업 트리의 커밋하지 않은 변경은 들어가지 않는다. preset
  트리 경로에 그런 변경이 있으면 `note: uncommitted changes under the preset tree are not in the artifact (built from
  HEAD <짧은 id>)` 를 낸다
- `git ls-tree -r -t -z --full-tree HEAD` 의 항목을 #216 3-2 의 함수에 넘겨 받을 파일을 고른다. 목록과 종류는 #216 의 git
  받기와 같고, 받지 않은 항목은 버린다(README · 테스트 등). 실행 비트는 버린다
- 함수가 거부하면 아래를 내고 종료 코드 2. 괄호 안은 함수가 돌려준 사유와 순번이고, 경로는 옮기지 않는다. `preset.toml` 이
  없으면 첫 줄이 `error: the preset tree has no preset.toml at its root` 다

```
error: the preset tree has an entry the harness does not accept (<사유>, entry <순번>)
  --> <--source 디렉터리>

help: the entry number counts the lines of `git ls-tree -r -t --full-tree HEAD` in that directory
```

- 고른 파일의 경로는 3-3 의 이름 규칙 안이다. 어긋나는 경로가 있으면 위 문구로 사유 `not a safe path` 와 그 순번을 낸다
- 고른 트리를 #216 의 preset 트리 검증(`preset.toml` 판정 · UTF-8)에 넘긴다. 거부되면 그 문구로 멈추고 종료 코드 2. 문구의
  `<참조>` 자리에는 `--source` 디렉터리가 든다
- `--tag` 는 2-1 의 태그 규칙을 따른다
- `--output` 은 없거나 빈 디렉터리여야 하고 `--source` 밖이어야 한다 — `error: the output directory is not empty` ·
  `error: the output directory must be outside the preset repository`, 종료 코드 2
- 3절대로 레이아웃을 쓰고 아래를 낸다

```
built: <출력 디렉터리>
  manifest  sha256:<…>
  layer     sha256:<…> (<바이트 수> bytes)
  content   <내용 해시>
```

`content` 는 이 아티팩트를 받은 lock 이 기록할 내용 해시(#216)다.

### 8-2. `harness preset inspect`

```
harness preset inspect <참조 | 레이아웃 디렉터리>
```

- 입력이 `oci://` 로 시작하면 원격이다. `oci-layout` 파일이 있는 디렉터리면 레이아웃이다. 그 밖은 짧은 이름(2-3)이다
- 원격이면 manifest 와 레이어를 받아 4절의 검사를 하고 임시 디렉터리에 푼다. 레이아웃이면 같은 검사를 레이아웃 파일로 한다.
  실패하면 4절의 문구와 종료 코드 1
- 출력

```
manifest   sha256:<…>
version    <태그>
revision   <커밋 id>
created    <UTC 시각>
source     <URL>
requires   <요구 버전>
schema     1
layer      sha256:<…> (<바이트 수> bytes)
content    <내용 해시>
files
  <preset 트리의 파일 경로, 바이트 순>
referrers  <api | fallback>
  <artifactType>  sha256:<…>
```

- annotation 이 없는 줄은 내지 않는다. 레이아웃이면 `referrers` 줄이 없다
- referrers 조회가 실패하면 `referrers  unavailable (<상태 코드>)` 를 내고, 종료 코드는 0 이다

### 8-3. `harness preset push`

```
harness preset push <레이아웃 디렉터리> <참조> [--yes]
```

- 참조는 전체 참조나 짧은 이름이다. 태그를 빼면 레이아웃의 태그를 쓴다. 태그를 적었으면 레이아웃의 태그와 같아야 한다 —
  다르면 `error: the tag differs from the tag the layout was built with`, 종료 코드 2. 레지스트리에 요청하지 않는다
- 올리기 전에 레이아웃을 4절로 검사한다
- 순서
  1. end-3 `HEAD` 로 태그를 본다. 응답에 `Docker-Content-Digest` 가 없으면 `GET` 으로 받아 계산한다
     - 404 면 새 태그다
     - 레이아웃의 manifest digest 와 같으면 아무것도 올리지 않고 `already pushed: the tag points to the same manifest`,
       종료 코드 0
     - 다르고 `--yes` 가 없으면 아래를 내고 멈춘다. 아무것도 올리지 않고 종료 코드 1
  2. blob(빈 config · 레이어)마다 end-2 `HEAD` 로 있는지 보고, 없으면 end-4a 로 세션을 열어 end-6 으로 한 번에 올린다.
     응답의 `Docker-Content-Digest` 가 있으면 blob digest 와 같아야 한다
  3. end-7a 로 manifest 를 태그에 올린다. 응답의 `Docker-Content-Digest` 가 있으면 레이아웃의 manifest digest 와 같아야 한다
- 성공하면 `pushed: <참조>` 와 `manifest  sha256:<…>` 를 낸다

```
error: the tag already points to a different manifest
  --> oci://<레지스트리>/<저장소>:<태그>
      registry  sha256:<…>
      layout    sha256:<…>
nothing was pushed

help: projects that pulled this tag keep the old manifest in their lock until they pull again
      to replace it, run the command again with --yes
        harness preset push <layout> <reference> --yes
```

- 레지스트리 정책(태그 불변 등)이 거부하면 5-4 의 오류다

### 8-4. `harness registry login`

```
harness registry login [<레지스트리>] [--username <이름>]
```

- 레지스트리를 빼면 기기 기본 레지스트리다. 그것도 없으면 2-3 의 안내와 종료 코드 2
- 이 레지스트리에 쓸 헬퍼(`credHelpers` 항목, 없으면 `credsStore`)가 없으면 거부한다. `config.json` 에 저장하지 않는다

```
error: no credential helper is configured for this registry
  --> <docker 설정 파일 경로>
nothing was stored

help: the harness stores credentials only through a docker credential helper
      set credsStore or credHelpers in that file, then log in again
```

종료 코드 2.

- 표준 입력이 터미널이 아니면 거부한다 — `error: registry login reads the password from a terminal`, 종료 코드 2.
  비밀번호를 인자 · 환경 변수 · 파이프로 받는 경로가 없다. 비밀번호는 사람이 터미널에서만 입력한다
- 사용자 이름은 `--username` 이나 터미널 입력이고, 비밀번호는 에코 없이(`getpass`) 받는다
- 저장하기 전에 end-1 의 challenge 로 그 자격증명을 써서 6-2 의 인증을 한 번 한다
  - 거부되면 `error: the registry did not accept the credentials`, 종료 코드 1. 아무것도 저장하지 않는다
  - challenge 가 없으면 `note: this registry does not ask for credentials — nothing was stored`, 종료 코드 0
- 통과하면 헬퍼의 `store` 로 저장하고 `login succeeded: stored by docker-credential-<이름>` 을 낸다

### 8-5. `harness registry logout`

```
harness registry logout [<레지스트리>]
```

- 레지스트리를 빼면 기기 기본 레지스트리다
- 헬퍼(8-4 와 같은 판정)가 있으면 `erase` 를 부르고 `logged out: erased from docker-credential-<이름>` 을 낸다. 헬퍼가 0 이
  아닌 코드로 끝나면 `error: docker-credential-<이름> erase exited with <코드>`, 종료 코드 1
- 헬퍼가 없고 `auths` 에 항목이 있으면 docker 설정 파일을 고치지 않고 멈춘다

```
error: the credentials for this registry are in the docker config, written by another tool
  --> <docker 설정 파일 경로>

help: remove them with the tool that wrote them
```

종료 코드 1.

- 둘 다 없으면 `not logged in`, 종료 코드 0

### 8-6. `harness registry use`

```
harness registry use [<레지스트리> | --unset]
```

- 인자가 있으면 2-1 의 `<레지스트리>` 규칙으로 판정하고 `oci.json` 에 쓴다. `default registry: <레지스트리>` 를 낸다.
  어긋나면 종료 코드 2
- 인자가 없으면 지금 값을 낸다. 없으면 `no default registry`. 종료 코드 0
- `--unset` 이면 파일을 지우고 `default registry unset` 을 낸다
- 레지스트리에 접속하지 않는다

### 8-7. `harness registry check`

```
harness registry check <저장소 참조> [--push]
```

- 저장소 참조는 `oci://<레지스트리>/<저장소>` 나 짧은 이름 `<저장소>` 다. 태그는 받지 않는다

| 항목 | 확인하는 것 | `--push` 없이 |
|---|---|---|
| `api` | end-1 이 200 이나 401 로 답한다. `Docker-Distribution-Api-Version` 헤더 값을 보인다(없으면 `-`) | 돈다 |
| `transport` | HTTPS 인증서 검증 통과, 또는 루프백 HTTP | 돈다 |
| `credentials` | 자격증명의 출처 — `credHelpers` · `credsStore` · `auths` · `none`. 헬퍼면 그 이름 | 돈다 |
| `auth` | 6-2 를 거친 방식(`none` · `basic` · `bearer`)과 범위 — `pull`, `--push` 면 `pull,push` | 돈다 |
| `push` | 확인용 아티팩트를 새 태그로 올린다 — blob 둘과 manifest | `skip` |
| `digest` | 응답 `Docker-Content-Digest` 가 클라이언트가 계산한 digest 와 같다 | `skip` |
| `pull` | 태그와 digest 로 다시 받은 manifest 바이트와 레이어가 올린 것과 같고 4절 검사를 통과한다 | `skip` |
| `referrers` | 7절의 경로 — `api` 나 `fallback`. 404 는 실패가 아니다 | `skip` |

- 확인용 아티팩트는 3절 형식의 preset 아티팩트다. 레이어는 `preset.toml` 한 파일(주석 한 줄)이고, annotation 은
  `org.opencontainers.image.version`(= 태그)과 `io.github.willjsw.harness.schema` 뿐이다
- 태그는 실행마다 새로 짓는다 — `harness-check-<UTC YYYYMMDDHHMMSS>-<16진 8자리 난수>`
- 삭제 엔드포인트를 쓰지 않으므로 확인용 아티팩트는 저장소에 남는다. 출력 끝에 그 사실과 태그를 낸다
- 한 항목이 FAIL 이면 그 항목에 기대는 뒤 항목은 `skip` 이다

```
registry check
  ok    api           registry/2.0
  ok    transport     https, certificate verified
  ok    credentials   credsStore (<헬퍼 이름>)
  ok    auth          bearer, pull,push
  ok    push          tag harness-check-<…>
  ok    digest        matches
  ok    pull          byte-identical
  ok    referrers     fallback (tag schema)
note: the check artifact stays in the repository as tag harness-check-<…>
```

- 출력에 레지스트리 호스트 · 저장소 이름 · 자격증명 · 토큰을 넣지 않는다. 결과를 그대로 공개 기록(9절)에 옮길 수 있다
- 종료 코드는 FAIL 이 없으면 0, 있으면 1 이다

### 8-8. `pull` · `install --preset` 의 `oci://`

#216 의 받기 단계는 참조의 스킴으로 백엔드를 고른다. `oci://` 는 이 백엔드다. 체인의 참조마다 자기 스킴으로 고른다.

백엔드가 #216 의 준비 단계 안에서 하는 일:

1. 2-1 로 참조를 판정한다
2. end-3 으로 태그의 manifest 를 받아 4-1 로 검사한다. 본문 sha256 이 해석된 식별자다
3. end-2 로 레이어를 받아 4-2 로 검사하고(#216 의 트리 멤버 판정 함수 포함), 4-3 대로 하네스 루트 밖 임시 디렉터리에 푼다
4. `io.github.willjsw.harness.requires` 가 있으면 풀어낸 preset 트리가 선언한 값과 같아야 한다. 다르면
   `error: not a harness preset artifact (requires does not match the preset tree)`
5. 풀어낸 트리 · 해석된 식별자 · 태그 · 출처(2-2)를 넘긴다. 체인 해석 · 병합 · 검증 · render 계산 · 사전 판정 · 반영은 #216 이 한다

- 이 백엔드에서 멈추면 #216 의 준비 단계에서 멈춘 것이다. 대상 리포는 바뀌지 않는다. 4 · 5 · 6절과 위 4 의 안내문을 내고,
  줄 목록 뒤 · help 앞에 `nothing was changed` 를 더하며, 종료 코드는 2 다(#216 7-4). 4 · 5 · 6절의 종료 코드 1 은 `preset` ·
  `registry` 명령의 것이다
- lock 에 담는 값 — #216 4-3 의 스킴별 판정에 `oci://` 를 더한다

| lock 의 키(#216 4-3) | OCI |
|---|---|
| `source` | 2-2 의 출처 `oci://<레지스트리>/<저장소>` — `extends` 의 전체 참조에서 `:<태그>` 를 뗀 것 |
| `tag` | `<태그>` — 2-1 의 태그 규칙 |
| `resolved` | manifest digest `sha256:<소문자 16진 64자>` — 받은 manifest 바이트로 계산한 값 |
| `content` | 풀어낸 preset 트리를 #216 의 알고리즘으로 계산한 값 |

- 같은 출처 · 태그의 lock 항목과 `resolved` 가 다르면(같은 태그가 다른 manifest 를 가리킨다) #216 의 경고와 갱신 규칙을 따른다
- #216 이 `resolved` 의 짧은 꼴을 쓰는 자리(pull 출력 · 경고 · doctor)는 `sha256:` 을 뗀 16진의 앞 7자다(#216 4-3)
- `install --preset` 은 짧은 이름을 받으면 2-3 대로 펼친 전체 참조를 씨앗 설정의 `extends` 에 쓴다
- `install` 은 전역 CLI 로 돌고 `pull` 은 고정 사본으로 넘긴다(#216). `oci://` 를 쓰는 리포의 고정 사본은 이 백엔드를 가진
  버전이어야 한다

### 8-9. 명령 표

- 명령 표(`COMMANDS`)에 두 행을 더한다. 둘 다 #206 3-3 의 **통과 명령**(항목의 통과 값 `True`)이다 — 공용 파서는 명령
  이름 뒤의 토큰을 해석하지 않고 순서 · 내용 그대로 명령 모듈에 넘기며, 하위 명령과 옵션은 명령 모듈이 해석한다.
  공용 파서에 옵션을 더하지 않는다
- 둘 다 설정이 필요 없고 대상을 해석하지 않는다 — #206 3-3 의 3단계에서 `tools` · `projects` 처럼 대상 해석 · 위임 앞에서
  명령 모듈로 간다. 고정 사본으로 넘기는 목록(`DELEGATES`)에 넣지 않는다. 하네스 루트(이름 앞이나 이름 바로 뒤의
  `--target`)는 쓰지 않는다

| 이름 | 인수 | 설명 |
|---|---|---|
| `preset` | `build\|inspect\|push ...` | `build, inspect or push a preset as an OCI artifact` |
| `registry` | `login\|logout\|use\|check ...` | `log in through a docker credential helper, set the default registry, or check a registry` |

- 명령 모듈이 해석하는 옵션: `--tag` · `--output` · `--source`(`preset build`), `--yes`(`preset push`), `--push`(`registry check`),
  `--username`(`registry login`), `--unset`(`registry use`)
- 하위 명령이 없거나 모르는 것이면, 또는 하위 명령이 받지 않는 옵션 · 인자가 오면 사용법을 내고 종료 코드 2. `-h` · `--help`
  면 사용법을 내고 종료 코드 0

## 9. 지원 목록

README "지원 범위" 에 레지스트리 표를 둔다.

| 레지스트리 | 검증한 버전 | referrers | 인증 | 검증 수단 |
|---|---|---|---|---|

- 행은 그 레지스트리에서 `registry check --push` 의 항목이 전부 `ok` 일 때만 더한다. 통과하지 않은 레지스트리는 "미검증" 으로도
  올리지 않는다
- 버전은 검증한 버전 하나만 적는다. 범위로 일반화하지 않는다
- `referrers` 는 check 의 `referrers` 항목 값이다. `인증` 은 check 의 `auth` 항목이 실제로 거친 방식이고, 거치지 않은 방식은
  검증한 것이 아니다
- 조직 인스턴스의 호스트 · 프로젝트 · 계정 · 정책은 적지 않는다
- 표 아래 안내: `registry check --push` 는 확인용 아티팩트를 남기므로 정책(태그 불변 · 서명 강제)을 걸지 않은 확인용 저장소에서
  돌린다
- 이 이슈가 더하는 행은 CNCF Distribution 이다 — 버전은 CI 통합 잡(10-4)이 고정한 이미지의 버전, referrers `fallback`,
  인증 `none`, 검증 수단 "CI 통합 잡". 행은 그 잡이 통과한 뒤에 더한다
- 로컬 실측 기록(이슈 #218 댓글, `registry:3` 이미지의 Distribution 3.1.2): 3절의 아티팩트 형식을 받고, referrers API 는
  404 로 없으며, `subject` 가 달린 manifest 를 받을 때 `OCI-Subject` 응답 헤더가 없다

## 10. 회귀 테스트

### 10-1. 가짜 레지스트리 · 스텁 헬퍼

`src/test/fake_registry.py` — 표준 라이브러리 HTTP 서버다. 127.0.0.1 의 빈 포트에만 바인드하고 포트를 파일에 쓴다.
blob · manifest · 태그를 메모리에 둔다. 단위 테스트는 import 해서 스레드로, `render-test.sh` 는 백그라운드 프로세스로 띄운다.

| 모드 | 동작 |
|---|---|
| 인증 | `none` · `basic` · `bearer`(같은 서버에 토큰 realm 을 둔다) |
| referrers | `api`(end-12a 가 index 로 답한다) · `absent`(404) |
| 주입 | 틀린 `Docker-Content-Digest`, 4 MiB 를 넘는 manifest, 다른 호스트(두 번째 서버)로의 blob 리다이렉트, HTTP 로의 리다이렉트, 500 오류 |

받은 요청마다 메서드 · 경로 · `Authorization` 유무를 기록 파일에 남겨 테스트가 읽는다. `Authorization` 값은 남기지 않는다.

`src/test/stub-credential-helper` — 테스트가 임시 디렉터리에 `docker-credential-<이름>` 으로 링크하고 PATH 앞에 둔다.
받은 인자와 표준 입력을 기록 파일에 남기고, 환경 변수로 받은 자격증명을 `get` 에 낸다. 표준 오류에 표지 문자열을 쓴다.

### 10-2. 단위 테스트 — `src/test/unit/`

#206 7-5 의 자리와 `[verify]` 단계 "Python 단위 테스트" 가 돈다.

| 파일 | 케이스 |
|---|---|
| `test_registry_reference.py` | 전체 참조 판정(받는 것, 대문자 호스트, 태그 없음, digest 참조는 inspect 입력에서만, 저장소 규칙), `extends` 판정의 사유 넷과 그 순서, 짧은 이름 펼치기와 거부(기본 없음, 첫 성분이 호스트 꼴), `oci.json` 읽기(형식이 어긋나면 멈춤), 태그를 뺀 출처(포트가 있는 레지스트리 포함) |
| `test_registry_artifact.py` | 같은 커밋을 두 번 빌드하면 레이아웃 바이트가 같다. 작업 트리의 mtime · umask · 소유자 · 실행 비트 · 커밋하지 않은 변경이 달라도 같다. `origin` 이 https 와 scp 형식으로 달라도 manifest 가 같고, userinfo 가 annotation 에 없다. 태그만 다르면 레이어는 같고 manifest 는 다르다. gzip 머리 10바이트가 고정값이다. 받는 디렉터리 아래의 링크 · 서브모듈 · 규칙 밖 이름을 #216 의 함수로 거부하고, 문구가 사유와 `git ls-tree` 줄 순번을 담으며 경로가 없다. 받는 디렉터리 밖의 링크(README 등)와 파일은 레이어에 들지 않고 빌드가 통과한다 |
| `test_registry_extract.py` | 심볼릭 링크 · 하드 링크 · 장치 · FIFO · 절대 경로 · `..` · `./` · 공백 · 비ASCII · 100바이트를 넘는 이름 · 중복 · 파일 아래 파일 · 받는 디렉터리 아래의 규칙 밖 이름 · `preset.toml` 없음 · 받는 디렉터리 밖의 파일과 디렉터리 · 멤버 수 초과 · 압축 크기 초과 · 풀어낸 크기 초과를 각각 거부하고 임시 디렉터리를 남기지 않는다. #216 의 함수가 거부한 경우 문구에 그 사유와 순번이 그대로 든다. 받는 파일은 tar 의 모드 · 소유자와 상관없이 `0644` 로 풀린다. 거부 문구에 멤버 이름이 없다 |
| `test_registry_manifest.py` | 4-1 의 어긋남을 각각 거부하고 사유가 표와 같다 |
| `test_registry_transport.py` | 루프백 판정, 루프백이 아닌 HTTP 거부, HTTPS 에서 HTTP 로의 리다이렉트 거부, 다른 호스트로의 리다이렉트에 `Authorization` 없음, 본문 상한, 오류 출력에 메시지 · 본문 · 쿼리 없음 |
| `test_registry_auth.py` | 찾는 순서(`credHelpers` > `credsStore` > `auths` > 익명), 헬퍼 실패 시 다음 순서, 헬퍼 이름 거부, `DOCKER_CONFIG`, challenge 파싱(Bearer · Basic · 따옴표 · 인자 순서), 토큰 요청의 scope, 익명 토큰, identity token 거부, login 의 확인 · 저장 경로(터미널 입력을 대신 넣어 부른다), 출력에 헬퍼 표지 · 토큰 · 비밀번호가 없다 |
| `test_registry_referrers.py` | `api` 경로, 404 에서 태그 규칙 index 로 가는 `fallback`, 둘 다 없으면 빈 목록, 다음 쪽 안내, index 검사 |

### 10-3. `render-test.sh` — 새 UT 블록

번호는 분해가 정한다. 가짜 레지스트리와 스텁 헬퍼를 쓰고, 등록부는 `HARNESS_HOME`, docker 설정은 `DOCKER_CONFIG` 로 임시
위치에 둔다.

| 케이스 | 확인하는 것 |
|---|---|
| 왕복 | 임시 git preset 리포에서 `preset build` → 가짜 레지스트리(`bearer`)에 `preset push` → `preset inspect` 의 `manifest` · `content` 가 build 출력과 같다 |
| 다시 push | 같은 레이아웃은 `already pushed`, 종료 코드 0. 같은 태그에 다른 레이아웃은 `--yes` 없이 종료 코드 1 이고 레지스트리의 태그가 그대로다. `--yes` 면 바뀐다 |
| 태그 불일치 | 참조의 태그가 레이아웃과 다르면 종료 코드 2 이고 레지스트리에 요청이 없다 |
| `install --preset` | 빈 대상에 `install --preset oci://127.0.0.1:<포트>/<저장소>:<태그>` → vendoring 이 preset 트리와 같고, lock 의 `source` 가 `oci://127.0.0.1:<포트>/<저장소>`, `tag` 가 `<태그>`, `resolved` 가 manifest digest, `content` 가 build 의 `content` 다. 다시 render · check 하면 lock 대조가 통과한다 |
| 백엔드 사이 | 같은 preset 커밋을 git 태그(#216 의 테스트 방식)와 OCI 로 받은 두 대상의 vendoring 과 lock 내용 해시가 같다 |
| 받기 거부 | 링크 멤버가 든 레이어와 받는 디렉터리 밖 멤버가 든 레이어(가짜 레지스트리에 직접 올림)를 각각 pull 하면 종료 코드 2 와 `nothing was changed` 이고, 대상 리포의 파일 · lock · 매니페스트가 그대로이며 임시 디렉터리가 남지 않는다. 같은 레이어를 `preset inspect` 하면 종료 코드 1 이다 |
| 오프라인 | 가짜 레지스트리를 멈춘 뒤 render · check 가 통과한다 |
| 기본 레지스트리 | `registry use` 뒤 `oci.json` 이 등록부 최상위의 파일이고 `harness projects` 에 나오지 않는다. 짧은 이름 push 가 펼친 참조로 간다. `--unset` 뒤 짧은 이름은 종료 코드 2 와 `no default registry` |
| `extends` 형식 | `oci://` 의 거부 사유 넷이 각각 2-1 의 문구로 나오고 종료 코드 2 다. 자격증명 사유일 때 심은 비밀 문자열이 표준 출력 · 표준 오류 어디에도 없다. 짧은 이름은 #216 2-1 의 첫 사유로 멈추고 help 에 `oci://` 형식이 있다(11-2) |
| login | 표준 입력이 터미널이 아니면 종료 코드 2 이고 헬퍼에 `store` 가 오지 않는다. 헬퍼가 설정되지 않았으면 종료 코드 2 이고 docker 설정 파일이 바뀌지 않는다 |
| logout | 스텁 헬퍼에 `erase` 와 레지스트리가 간다. `auths` 에만 항목이 있으면 종료 코드 1 이고 docker 설정 파일이 바뀌지 않는다 |
| check | `--push` 로 가짜 레지스트리(referrers `absent`)에 돌리면 모든 항목이 `ok`, `referrers` 가 `fallback`, 종료 코드 0 이고 출력에 `127.0.0.1` · 포트 · 저장소 이름이 없다. `--push` 없이는 뒤 넷이 `skip`. 두 번 돌리면 태그가 다르다 |
| 새지 않음 | 위 케이스 전부의 출력에 스텁 헬퍼의 표지 · 비밀번호 · 토큰 문자열이 없다 |

#216 의 블록(#216 16-1)에서 "참조 형식" 케이스의 기대값을 11-2 의 문구로 바꾼다 — 첫 사유는
`not an https:// or oci:// reference` 이고, 그 사유일 때 help 첫 줄은
`help: extends takes https://<host>/<path>@<tag> or oci://<registry>/<repository>:<tag>` 다.

터미널 출력의 한글 검사는 이 블록의 출력에도 적용한다.

### 10-4. CI 통합 잡

- `.github/workflows/registry-integration.yml` — 프로젝트 소유 파일이다. 하네스 게이트 파일(`harness-verify.yml`)과 따로 둔다
- `ubuntu-latest` 러너에서 서비스 컨테이너로 `registry:3` 을 digest 로 고정해 띄운다
  <!-- TBD: 확인 필요 — 고정할 이미지 digest 전체 값. 실측 기록에는 앞부분(`sha256:ddf754342cfc…`)만 있다 -->
  러너 호스트의 루프백 포트로 붙으므로 루프백 HTTP 규칙(5-2) 안이다
- 경로 필터: `src/harness/registry/**`, 두 명령 모듈, OCI 백엔드 파일, `src/test/integration/**`, 이 워크플로 파일
- `cd src && python3 -B -m unittest discover -s test/integration` 를 레지스트리 주소(`HARNESS_TEST_REGISTRY`)와 함께 돈다.
  #206 의 단위 테스트 실행과 같은 꼴이다. 주소가 없으면 실패한다 — 건너뛰지 않는다
- `[verify]` · pre-push · `render-test.sh` 에는 넣지 않아 로컬에 docker 를 요구하지 않는다. `[verify]` 의 "Python 단위 테스트"
  단계는 `test/unit` 만 찾으므로 이 테스트를 돌지 않는다
- 케이스

| 케이스 | 확인하는 것 |
|---|---|
| check | `registry check --push` 의 항목이 전부 `ok` 이고 `referrers` 가 `fallback` 이다 |
| 왕복 | build → push → inspect 의 manifest digest 가 같고, 같은 레이아웃을 다시 push 하면 `already pushed` 다 |
| 받기 | `install --preset` 으로 받은 lock 의 `source` 가 태그를 뺀 출처이고, `resolved` · `content` 가 build 출력의 manifest · content 와 같다 |
| referrers fallback 읽기 | 테스트가 직접 올린 연결 아티팩트(`subject` 가 달린 manifest 와 태그 `sha256-<hex>` 의 index)를 `preset inspect` 가 `fallback` 경로로 보인다 <!-- TBD: 확인 필요 — Distribution 3.1.2 가 태그 규칙 index 의 push 를 받는지 실측하지 않았다 --> |

- 이 잡은 인증 흐름(토큰 교환)을 덮지 않는다 — 컨테이너에 인증이 없다. 인증은 가짜 레지스트리(10-1)가 덮는다.
  실제 토큰 서버를 상대로 한 동작은 검증하지 않았다 <!-- TBD: 확인 필요 — 실제 레지스트리의 토큰 교환을 실측하지 않았다 -->

## 11. 함께 고치는 문서

보호 문서가 아닌 것이다.

### 11-1. 현재형 문서와 원형

| 문서 · 위치 | 반영할 것 |
|---|---|
| `README.md` "명령" 표 | `harness preset build\|inspect\|push` — preset 리포의 HEAD 에서 재현 가능한 OCI 아티팩트를 만들고(`build`), annotation · 파일 · 내용 해시 · 연결된 아티팩트를 보고(`inspect`), 올린다(`push`, 같은 태그가 다른 manifest 를 가리키면 `--yes` 로만 덮는다). `harness registry login\|logout\|use\|check` — 레지스트리 자격증명을 docker credential helper 로 저장 · 삭제하고(헬퍼가 없으면 거부, 비밀번호는 터미널에서만), 짧은 이름을 펼칠 기기 기본 레지스트리를 정하며, 프로토콜 왕복을 점검한다(`--push`) |
| `README.md` "지원 범위" | 9절의 레지스트리 표와 안내. 헬퍼가 없는 CI 는 다른 도구가 써 둔 docker 설정의 `auths` 로 인증한다는 것, 사설 CA 는 `SSL_CERT_FILE` · `SSL_CERT_DIR` 로 준다는 것 |
| `.ai/project/environment.md` "필요한 도구" | `docker-credential-<이름>`(선택) — 레지스트리 자격증명. `registry login` 은 이것이 있어야 한다. `docker`(선택) — 레지스트리 통합 테스트를 로컬에서 돌릴 때만 |
| `.ai/project/environment.md` "환경 변수" | `DOCKER_CONFIG` — docker 설정 파일 위치. `SSL_CERT_FILE` · `SSL_CERT_DIR` — 사설 CA. `HTTPS_PROXY` · `NO_PROXY` — 루프백이 아닌 레지스트리의 프록시. `HARNESS_HOME` 의 용도에 기기 기본 레지스트리(`oci.json`) |
| `.ai/project/environment.md` "외부 시스템" | 레지스트리 — preset 아티팩트를 올리고 받는 곳. 자격증명은 credential helper 나 docker 설정이 갖는다 |
| `src/templates/harness.toml` 의 `extends` 주석(#216 14-4 가 둔다) | 받는 형식 줄을 `#   https://<호스트>/<경로>@<태그> 또는 oci://<레지스트리>/<저장소>:<태그> 형식의 전체 참조만 받는다` 로 |

### 11-2. `docs/spec/216-org-presets.md`

이 명세가 들어간 뒤 #216 명세의 아래 서술은 오른쪽 사실로 읽는다. 분해의 task 하나가 그 명세를 고친다.

| 위치 | 이 명세 이후의 사실 |
|---|---|
| 1절 "이 단계의 preset 백엔드는 git 태그 하나다" | preset 백엔드는 git 태그와 OCI(이 명세) 둘이다 |
| 2-1 머리의 "다른 스킴은 받지 않는다" 와 표의 `스킴` 행 | `oci://` 로 시작하는 값은 이 명세 2-1 이 판정한다. 그 밖의 값은 2-1 의 표대로 판정한다 |
| 2-1 의 첫 사유 `not an https:// reference` | `https://` 와 `oci://` 어느 쪽으로도 시작하지 않을 때의 사유이고 문구는 `not an https:// or oci:// reference` 다. 이 사유일 때 help 첫 줄은 `help: extends takes https://<host>/<path>@<tag> or oci://<registry>/<repository>:<tag>` 다 |
| 4-3 의 스킴별 `source` · `tag` · `resolved` 판정 | `oci://` 의 값과 판정은 이 명세 2-1 · 2-2 · 8-8 이다 |
| 8-1 의 `<참조>` 판정과 `--preset` 도움말 | `<참조>` 는 git 전체 참조, OCI 전체 참조, 짧은 이름(이 명세 2-3 으로 펼친다)을 받는다. 도움말은 `install: start the project from a preset (https://<host>/<path>@<tag>, oci://<registry>/<repository>:<tag>, or <repository>:<tag> on the default registry)` 다 |
| 14-4 의 씨앗 설정 주석 | 11-1 의 마지막 행 |
| 17-3 의 `전체 참조` 행 | 12-3 의 `전체 참조` 행 |

## 12. 보호 문서 개정 범위

분해의 task 하나가 아래 범위 안에서만 고친다.

### 12-1. `.ai/project/scope.md`

| 위치 | 반영할 사실 |
|---|---|
| "할 수 있는 일" | preset 을 OCI 아티팩트로 만들어 레지스트리에 올리고(`preset build` · `inspect` · `push`), `oci://` 참조로 받는다(`pull` · `install --preset`). 레지스트리 자격증명은 docker credential helper 로 저장 · 삭제하고, 짧은 이름을 펼칠 기기 기본 레지스트리를 두며, 레지스트리의 프로토콜 왕복을 점검한다(`registry login` · `logout` · `use` · `check`) |
| "만들지 않는 것" | 레지스트리와 그 관리 기능(저장소 생성 · 권한 · 불변 정책 · 복제 · 서명 강제) — 레지스트리 운영 쪽이 맡는다. 자격증명 저장소 — docker credential helper 가 맡고, 하네스는 자격증명을 파일에 쓰지 않는다. 서명과 서명 검증 — 레지스트리 정책이 맡는다 |

### 12-2. `.ai/project/architecture.md`

| 위치 | 반영할 사실 |
|---|---|
| "구성 요소" | `src/harness/registry/` — 표준 라이브러리 OCI Distribution 클라이언트. 참조 판정 · 연결 · 인증(docker 설정 · credential helper · 토큰 교환) · 엔드포인트 7개와 referrers 태그 fallback · 재현 가능한 아티팩트 쓰기와 받은 아티팩트 검사. 명령은 `commands/preset.py` · `commands/registry.py` |
| "구성 요소" 의 기기 단위 상태 | 등록부 최상위의 `oci.json` — 기기 기본 레지스트리 |
| "데이터 흐름" | preset 배포: preset 리포의 HEAD → `preset build`(재현 가능한 OCI Image Layout) → `preset push` → 레지스트리 → `pull` · `install --preset` 의 OCI 백엔드(manifest · 레이어 받기 → digest 대조 → 멤버 검사 → 하네스 루트 밖 임시 디렉터리에 풀기) → preset 의 준비 · 반영 단계 |
| "신뢰 경계" 의 들어오는 입력 | 레지스트리의 응답(manifest · blob · index · 토큰 응답 · 오류 본문 · 헤더)과 받은 tar — 신뢰하지 않는다. digest 를 직접 계산해 대조하고, 크기 상한을 두며, tar 멤버는 일반 파일 · 디렉터리만 ADR 0017 의 경로 규칙(ASCII 로 좁힘)으로 거른 뒤 git 백엔드와 같은 preset 트리 멤버 판정 함수에 넘기고, 리포 밖에 푼다. 거부 안내에 멤버 이름을 옮기지 않는다. HTTP 는 루프백에만 쓰고 TLS 검증을 끄는 경로가 없다 |
| "신뢰 경계" 의 민감 정보 | 레지스트리 자격증명은 docker credential helper 와 docker 설정에서 읽기만 하고, 쓰는 것은 헬퍼의 `store` · `erase` 뿐이다. 비밀번호는 터미널에서만 받는다. 토큰은 프로세스 메모리에만 둔다. 출력 · 지표 · 오류에 자격증명 · 토큰 · 헬퍼 입출력 · URL 쿼리를 옮기지 않는다 |
| "새 코드를 둘 곳" | 레지스트리 프로토콜 · 인증 · 아티팩트 형식 → `src/harness/registry/`. 벤더 이름으로 분기하지 않는다 |
| "계층과 의존 방향" | `registry/` 는 설정 · render 를 import 하지 않는다. 명령 모듈과 preset 의 OCI 백엔드가 부른다. 레지스트리에 붙는 것은 `preset` · `registry` 명령과 `pull` · `install --preset` 뿐이고, render · check · doctor · status 는 붙지 않는다 |
| "검사하지 않는 것" | 실제 레지스트리의 인증 흐름(토큰 서버)은 자동 테스트가 없다. CI 통합 잡은 인증 없는 Distribution 만 보고, 레지스트리별 검증 범위는 README 의 지원 목록이 적는다 |

### 12-3. `.ai/project/glossary.md`

| 위치 | 반영할 사실 |
|---|---|
| "용어" 표 | `레지스트리` — OCI Distribution 규격의 아티팩트 저장소. preset 아티팩트를 올리고 받는 곳. 명령 `harness registry` 와 코드 `src/harness/registry/` 의 registry 는 이것이고, `harness doctor` 의 `registry` 절은 등록부다 |
| "용어" 표 | `preset 아티팩트` — preset 트리를 레이어 하나로 묶은 OCI 아티팩트(`artifactType` `application/vnd.willjsw.harness.preset.v1`) |
| "용어" 표의 `전체 참조` 행(#216 이 둔다) | 두 스킴으로 고친 행: `전체 참조` — 커밋되는 파일이 preset 을 가리키는 유일한 형식. git 은 `https://<호스트>/<경로>@<태그>`, OCI 는 `oci://<레지스트리>/<저장소>:<태그>` |
| "용어" 표 | `짧은 이름` — 레지스트리를 뺀 `<저장소>[:<태그>]`. CLI 입력에서만 받고 기기 기본 레지스트리로 펼친다 |
| "용어" 표 | `기기 기본 레지스트리` — 짧은 이름을 펼칠 레지스트리. 등록부 최상위의 `oci.json` 이고 `harness registry use` 가 쓴다 |
| "용어" 표 | `credential helper` — docker 의 자격증명 헬퍼(`docker-credential-<이름>`). 하네스는 레지스트리 자격증명을 이것과 docker 설정에서 읽고, 저장도 이것으로만 한다 |
| "용어" 표 | `지원 목록` — README "지원 범위" 의 레지스트리 표. `registry check --push` 의 항목이 전부 통과한 레지스트리만 오른다 |

### 12-4. `.ai/project/testing.md`

| 위치 | 반영할 사실 |
|---|---|
| "외부 의존을 어떻게 다루나" | 레지스트리는 `src/test/fake_registry.py`(127.0.0.1 에만 바인드하는 표준 라이브러리 HTTP 서버)가 대신하고, credential helper 는 PATH 앞의 스텁이 대신한다. docker 설정은 `DOCKER_CONFIG` 로 임시 위치에 둔다 |
| "외부 의존을 어떻게 다루나" 에 한 항목 | CI 에서만 도는 실제 레지스트리 통합 테스트 — `.github/workflows/registry-integration.yml` 이 digest 로 고정한 registry 이미지를 서비스 컨테이너로 띄우고 루프백으로 붙어 `src/test/integration/test_registry.py` 를 돈다. 레지스트리 코드가 바뀔 때만 돌고, pre-push · `render-test.sh` 에는 넣지 않아 로컬에 docker 를 요구하지 않는다 |
| "하지 않는 것" 의 첫 항목 | 실제 forge · 에이전트 CLI · 네트워크에 붙는 자동 테스트. 예외는 CI 의 레지스트리 통합 잡 하나이고, 그것도 러너 안의 일회용 컨테이너에 루프백으로만 붙는다 |

## 13. 결정 기록

- 결정 기록: 레지스트리는 stdlib OCI 클라이언트로 다루고 인증은 credential helper 에 맡긴다 — 아티팩트 형식(미디어 타입 ·
  annotation 이름 공간 · 재현 규칙)을 포함한다 (분해에서 작성)
- 받은 tar 의 멤버 판정은 ADR 0017 의 경로 규칙을 적용한 것이다. lock 형식은 #216 의 결정 기록이 다룬다

## 14. 한계

- 압축 바이트는 zlib 구현을 따르고, tar 바이트는 표준 라이브러리 `tarfile` 의 USTAR 출력을 따른다. 다른 환경에서 다시 빌드한
  레이어 · manifest digest 가 같다는 보장은 없다. 내용 해시는 같다 (3-5)
- identity token 자격증명(헬퍼의 사용자 이름 `<token>`, docker 설정의 `identitytoken`)은 다루지 않는다
- IPv6 주소 리터럴로 적은 레지스트리는 받지 않는다. 루프백 레지스트리를 HTTPS 로 쓰는 구성(터널 등)은 지원하지 않는다
- 사설 CA 를 docker 의 인증서 디렉터리에서 읽지 않는다. `SSL_CERT_FILE` · `SSL_CERT_DIR` 로 준다
- 하네스는 확인용 아티팩트를 지우지 않는다. 남은 것은 레지스트리의 보존 정책이나 관리자가 정리한다
- referrers 는 첫 쪽만 보인다. referrers API 나 referrers 태그 규칙으로 연결하지 않은 아티팩트(도구 고유의 태그 규칙으로
  올린 서명 등)는 목록에 없다
- 하네스는 서명을 확인하지 않는다. 서명 없는 아티팩트도 받는다
- 레이어 멤버의 이름을 ASCII 100바이트 이하로 한정한다 (3-3). ADR 0017 이 허용하는 비ASCII 이름은 레이어에 담지 않는다 —
  지금의 받는 파일 표(#216 3-1)는 이 안에 있다
- 고정 사본이 이 기능보다 오래된 리포는 `oci://` 참조를 렌더 · pull 하지 못한다. `harness install` 로 고정 사본을 올린다
