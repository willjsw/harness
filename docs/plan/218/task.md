# #218 task

## T1 · feat: OCI 참조 판정과 기기 기본 레지스트리 파일

### 상위 Requirement

- relates to #218

### 작업 내용

`oci://` 참조를 판정하고 나누고 잇는 함수, 짧은 이름을 기기 기본 레지스트리로 펼치는 함수, 등록부 최상위의 `oci.json` 을 읽고 쓰는
함수를 레지스트리 패키지의 첫 모듈로 둔다. 네트워크를 쓰지 않는다.

- 명세 2-1(전체 참조 · `extends` 판정의 사유 넷과 순서 · digest 참조) · 2-2(태그를 뺀 출처) · 2-3(짧은 이름 · 기기 기본 레지스트리 파일) · 10-2 의 `test_registry_reference.py`
- `src/harness/registry/__init__.py` — docstring 만
- `src/harness/registry/reference.py`
  - 전체 참조 `oci://<레지스트리>/<저장소>:<태그>` 판정 — 레지스트리(소문자 DNS 이름이나 IPv4, 포트 1–65535) · 저장소 · 태그 규칙.
    `<레지스트리>` 하나만 판정하는 함수도 둔다(`registry use` · `login` · `logout` 의 인자)
  - `extends` 판정 — 명세 2-1 의 사유 넷을 위에서부터 처음 맞는 하나로 돌려준다. 값을 돌려주지 않는다. 안내문(`-->` · `help:`)은 T10 이
    #216 의 판정 자리에서 낸다
  - digest 참조 `oci://<레지스트리>/<저장소>@sha256:<64자리 16진>` 판정 — `preset inspect` 입력에서만 받는다
  - 전체 참조를 출처(마지막 `:` 앞)와 태그로 나누고, `<출처>:<태그>` 로 다시 잇는 함수
  - CLI 입력 판정 — `oci://` 면 전체 참조, `https://` 면 git 참조(판정은 #216), 그 밖은 짧은 이름 `<저장소>[:<태그>]`. 짧은 이름의 첫 성분이
    `.` · `:` 를 담거나 `localhost` 면 `error: write the full reference (oci://<registry>/<repository>:<tag>)`. 기본 레지스트리가 없으면
    명세 2-3 의 `error: no default registry is set on this machine` 안내. 둘 다 종료 코드 2. 다른 레지스트리(Docker Hub 포함)로 펼치지 않는다
  - `oci.json` — 위치는 등록부(`home/registration.py` 의 등록부 함수, `HARNESS_HOME` 을 따른다) 최상위. 내용 `{"default_registry": "<레지스트리>"}`.
    읽기는 JSON 이 아니거나 값이 규칙 밖이면 `error: cannot read the default registry` · `-->` 파일 경로 · `help: harness registry use <registry>`,
    종료 코드 2, 파일 내용을 출력하지 않는다. 쓰기는 같은 디렉터리의 임시 파일에 쓴 뒤 이름을 바꾸고 `0600`, 등록부 디렉터리가 없으면
    `0700` 으로 만든다. 지우기(`--unset`)도 둔다
- `src/test/unit/test_registry_reference.py`
- 건드릴 파일: `src/harness/registry/__init__.py`(신규), `src/harness/registry/reference.py`(신규), `src/test/unit/test_registry_reference.py`(신규)

### 완료 조건

- [ ] 포트가 있는 레지스트리 · IPv4 레지스트리 · 여러 성분 저장소의 전체 참조를 받는다
- [ ] 대문자 호스트 · 포트 0 과 65536 · 저장소 규칙 밖 문자 · 129자 태그를 `not a full OCI reference` 로 거부한다
- [ ] `extends` 판정이 자격증명 → digest 참조 → 태그 없음 → 그 밖 순서로 사유를 돌려주고, 두 어긋남이 겹치면 위의 사유다
- [ ] digest 참조는 `preset inspect` 입력 판정에서만 받고 `extends` 판정에서는 `it is a digest reference` 다
- [ ] 태그를 뺀 출처가 마지막 `:` 앞 문자열 그대로이고, 포트가 있는 레지스트리에서도 맞다. 출처와 태그를 다시 이으면 원래 참조다
- [ ] 짧은 이름이 기본 레지스트리로 펼쳐지고, 기본 레지스트리가 없으면 명세 2-3 의 안내와 종료 코드 2 다
- [ ] 첫 성분이 호스트 꼴인 짧은 이름이 `write the full reference` 와 종료 코드 2 다
- [ ] 어긋난 `oci.json` 이 `cannot read the default registry` 와 종료 코드 2 이고, 심은 내용이 출력에 없다
- [ ] 쓴 `oci.json` 이 `0600` 이고, 없던 등록부 디렉터리가 `0700` 으로 생기며, 임시 파일이 남지 않는다
- [ ] `script/project/check-cli.py imports` 와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 전체 참조를 받는다 | `oci://registry.example.test:5000/team/preset:1.4.0` · `oci://10.0.0.1/a/b-c/d:v1` | 레지스트리 · 저장소 · 태그로 나뉜다 |
| UT-02 | 형식 어긋남 | 대문자 호스트 · 포트 0 · 65536 · 저장소의 `A` · `..` · 129자 태그 | `not a full OCI reference` |
| UT-03 | `extends` 사유와 순서 | `oci://user:pw@host/r:t` · `oci://host/r@sha256:<64>` · `oci://host/r` · 자격증명과 태그 없음이 겹친 값 | `it carries credentials` · `it is a digest reference` · `it has no :<tag>` · 겹치면 `it carries credentials` |
| UT-04 | digest 참조는 inspect 입력에서만 | 같은 digest 참조를 inspect 입력 판정과 `extends` 판정에 | 앞은 받고 뒤는 `it is a digest reference` |
| UT-05 | 태그를 뺀 출처 | `oci://127.0.0.1:5000/team/preset:1.4.0` | 출처 `oci://127.0.0.1:5000/team/preset`, 태그 `1.4.0`, 다시 이으면 원래 값 |
| UT-06 | 짧은 이름 펼치기 | 기본 레지스트리 `registry.example.test` 와 `team/preset:1.4.0` · `team/preset` | `oci://registry.example.test/team/preset:1.4.0` · 태그 없는 전체 참조 |
| UT-07 | 기본 레지스트리 없음 | `oci.json` 없이 `team/preset:1.4.0` | `error: no default registry is set on this machine`, 종료 코드 2 |
| UT-08 | 호스트 꼴 짧은 이름 | `registry.example.test/team:1` · `host:5000/team` · `localhost/team` | `write the full reference`, 종료 코드 2 |
| UT-09 | `oci.json` 읽기 실패 | JSON 이 아닌 파일 · 값이 대문자 호스트인 파일(표지 문자열을 심음) | `cannot read the default registry`, 종료 코드 2, 표지 문자열 없음 |
| UT-10 | `oci.json` 쓰기 | 없는 `HARNESS_HOME` 에 쓰기, 다시 쓰기, 지우기 | 디렉터리 `0700`, 파일 `0600`, 임시 파일 없음, 지운 뒤 파일 없음 |

## T2 · feat: 레지스트리 연결·리다이렉트·크기 상한·오류 출력과 가짜 레지스트리

### 상위 Requirement

- relates to #218

### 작업 내용

레지스트리로 가는 HTTP 요청 하나를 맡는 전송 모듈과, 회귀 테스트가 쓰는 가짜 레지스트리의 바탕을 만든다. 인증과 엔드포인트는 T3 · T4 가 이 위에 얹는다.

- 명세 5-2(연결) · 5-3(리다이렉트와 크기) · 5-4(오류 출력) · 10-1(가짜 레지스트리) · 10-2 의 `test_registry_transport.py`
- `src/harness/registry/transport.py`
  - 루프백 판정 — `127.0.0.0/8` 과, 해석한 주소가 전부 루프백인 `localhost`. 루프백은 HTTP, 그 밖은 HTTPS. 다른 조합은 없다
  - HTTPS 는 `ssl.create_default_context()` 로 만든 컨텍스트를 명시해 넘긴다. 검증을 끄는 옵션 · 환경 변수 · 설정을 두지 않는다.
    인증서 검증 실패는 명세 5-2 의 `error: the certificate of the registry did not verify` 와 `SSL_CERT_FILE` · `SSL_CERT_DIR` 안내
  - 프록시 — 루프백에는 쓰지 않고, 그 밖에는 표준 라이브러리가 읽는 환경 변수를 따른다
  - 요청마다 제한 시간 30초, 다시 시도하지 않는다. `User-Agent` 는 `harness/<버전>`
  - 리다이렉트는 5번까지. 대상이 루프백이 아닌 HTTP 면 연결하기 전에 멈춘다. `Authorization` 은 같은 `<레지스트리>`(호스트와 포트,
    명세 2-1)로 가는 요청과 토큰 요청에만 붙이고, 다른 호스트로 가면 떼어 낸다
  - 응답 본문 상한 — manifest · index 4 MiB, 토큰 · 오류 JSON 1 MiB, blob 은 호출자가 준 설명자 크기. 넘으면 읽기를 멈추고 실패한다
  - 오류 출력 — 명세 5-4 의 문구, `<동작>` 일곱 가지, 응답 JSON `errors[].code` 가운데 `[A-Z_]+` 만 괄호로. `message` · `detail` · 본문 ·
    헤더 · URL(쿼리 포함)은 옮기지 않는다. 연결 실패 · 제한 시간 초과는 `error: cannot reach the registry (<예외 이름>)`. 종료 코드 1
  - `urllib` · `http` 는 함수 안에서 불러온다
- `src/test/fake_registry.py` — 표준 라이브러리 HTTP 서버
  - `127.0.0.1` 의 빈 포트에만 바인드하고 포트를 파일에 쓴다. 단위 테스트는 import 해서 스레드로, 명령줄로 부르면 백그라운드 프로세스로 돈다
  - blob · manifest · 태그를 메모리에 둔다. `GET /v2/`, blob · manifest 의 `GET` · `HEAD`(manifest 는 태그 · digest 로, `Docker-Content-Digest` 를 붙인다)
  - 주입 — 틀린 `Docker-Content-Digest`, 4 MiB 를 넘는 manifest, 두 번째 서버(다른 포트)로의 blob 리다이렉트, 루프백이 아닌 HTTP 로의
    리다이렉트, 500 오류
  - 받은 요청마다 메서드 · 경로 · `Authorization` 유무를 기록 파일에 남긴다. `Authorization` 값은 남기지 않는다
- `src/test/unit/test_registry_transport.py`
- 건드릴 파일: `src/harness/registry/transport.py`(신규), `src/test/fake_registry.py`(신규), `src/test/unit/test_registry_transport.py`(신규)

### 완료 조건

- [ ] `127.0.0.1` · `127.5.6.7` 은 루프백이고, `localhost` 는 해석한 주소가 전부 루프백일 때만 루프백이다
- [ ] 루프백이 아닌 호스트를 HTTP 로 부르면 연결하지 않고 멈춘다
- [ ] HTTPS 에서 HTTP 로, 또는 루프백이 아닌 HTTP 로의 리다이렉트를 따라가지 않는다. 6번째 리다이렉트에서 멈춘다
- [ ] 두 번째 서버로 리다이렉트된 blob 요청에 `Authorization` 이 없고, 같은 레지스트리로 가는 요청에는 있다(요청 기록으로 본다)
- [ ] 4 MiB 를 넘는 manifest 와 설명자 크기를 넘는 blob 이 상한에서 멈추고 실패한다
- [ ] 500 응답의 오류 출력이 명세 5-4 형식이고, 응답에 심은 `message` · `detail` · 본문 · 쿼리 문자열이 출력에 없다. 코드가 `[A-Z_]+` 가 아니면 괄호가 없다
- [ ] 인증서 검증을 끄는 인자 · 환경 변수가 코드에 없다
- [ ] 가짜 레지스트리가 `127.0.0.1` 에만 바인드하고, 요청 기록에 `Authorization` 값이 없다
- [ ] `script/project/check-cli.py imports` 와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 루프백 판정 | `127.0.0.1` · `127.5.6.7` · `10.0.0.1` · 해석을 바꿔 끼운 `localhost`(루프백만 · 루프백과 아닌 주소 섞임) | 루프백 · 루프백 · 아님 · 루프백 · 아님 |
| UT-02 | 루프백이 아닌 HTTP | `http://registry.example.test/v2/` 요청 | 연결 시도 없이 실패 |
| UT-03 | 리다이렉트 판정 | HTTPS → HTTP, 루프백 HTTP → 루프백이 아닌 HTTP, 리다이렉트 6번 | 셋 다 멈춤 |
| UT-04 | 다른 호스트로의 리다이렉트 | 가짜 레지스트리의 blob 이 두 번째 서버로 리다이렉트, `Authorization` 을 준 요청 | 두 번째 서버 기록에 `Authorization` 없음, 첫 서버 기록에 있음 |
| UT-05 | 본문 상한 | 4 MiB + 1 바이트 manifest, 설명자보다 큰 blob | 둘 다 실패, 상한 넘어 읽지 않음 |
| UT-06 | 오류 출력 | 500 과 `{"errors":[{"code":"UNKNOWN","message":"<표지>","detail":"<표지>"}]}`, 쿼리에 표지가 든 URL | `error: the registry answered 500 to a blob request (UNKNOWN)`, 표지 없음 |
| UT-07 | 오류 코드 거르기 | `code` 가 `bad code` 인 오류 JSON | 괄호 없는 첫 줄 |
| UT-08 | 연결 실패 | 닫힌 포트 | `error: cannot reach the registry (<예외 이름>)` |
| UT-09 | 가짜 레지스트리 바인드 · 기록 | 띄운 서버의 주소, `Authorization: Bearer <표지>` 요청 뒤 기록 파일 | `127.0.0.1`, 기록에 유무만 있고 표지 없음 |

## T3 · feat: docker 설정과 credential helper 로 자격증명을 찾고 challenge 로 토큰 받기

### 상위 Requirement

- relates to #218

### 작업 내용

레지스트리 자격증명을 docker 설정과 credential helper 에서 찾고, 401 의 `WWW-Authenticate` 로 Basic 이나 Bearer 토큰 인증을 하는 모듈을
만든다. 하네스는 자격증명을 파일에 쓰지 않는다 — 헬퍼의 `store` · `erase` 를 부르는 함수만 두고, 부르는 것은 T8 의 `login` · `logout` 이다.

- 명세 6-1(자격증명 찾기) · 6-2(challenge 와 토큰) · 6-3(헬퍼 실행) · 6-4(남기지 않는 것) · 10-1(인증 모드 · 스텁 헬퍼) · 10-2 의 `test_registry_auth.py`
- `src/harness/registry/auth.py`
  - docker 설정 파일 — `DOCKER_CONFIG` 가 있으면 `$DOCKER_CONFIG/config.json`, 없으면 `~/.docker/config.json`. 읽기만 한다. 없으면 익명,
    JSON 이 아니면 `error: cannot read the docker config` · `-->` 파일 경로, 종료 코드 2. 내용을 출력하지 않는다
  - 찾는 순서 `credHelpers` → `credsStore` → `auths` → 익명. `auths` · `credHelpers` 의 키는 스킴과 경로를 떼고 소문자로 바꿔 `<호스트>[:<포트>]` 와 비교한다.
    헬퍼 `get` 이 0 이 아닌 코드면 다음 순서로 간다. 헬퍼에 주는 서버 값은 `<호스트>[:<포트>]`
  - identity token(헬퍼의 사용자 이름 `<token>`, `auths` 의 `identitytoken` 만 있는 항목)은 명세 6-1 의 오류, 종료 코드 1
  - 헬퍼 실행 — 이름이 `[A-Za-z0-9][A-Za-z0-9_.-]*` 가 아니면 부르지 않고 오류(종료 코드 2). PATH 의 `docker-credential-<이름>` 이 없으면
    `error: docker-credential-<이름> is not on PATH`(종료 코드 2). 셸 없이 인자 하나(`get` · `store` · `erase`)로, 입력은 표준 입력으로, 제한 시간 30초.
    헬퍼의 표준 출력 · 표준 오류를 옮기지 않고 실패는 헬퍼 이름과 종료 코드만 낸다
  - challenge — `Bearer realm=…,service=…[,scope=…]` 와 `Basic` 을 따옴표와 인자 순서에 상관없이 읽는다. Bearer 는 `GET <realm>?service=…&scope=…`
    로 토큰을 받는다 — scope 는 challenge 의 것, 없으면 받기 `repository:<저장소>:pull` · 올리기 `repository:<저장소>:pull,push` · end-1 은 없이.
    자격증명이 있으면 Basic 으로 붙이고 없으면 익명 토큰이다. 응답의 `token`, 없으면 `access_token`. realm 도 명세 5-2 를 따른다
  - 원래 요청은 한 번만 다시 보낸다. 다시 401 · 403 이면 명세 5-4 의 오류. 자격증명이 필요한데 없거나 challenge 를 모르면 명세 6-2 의
    `error: the registry needs credentials` 안내, 종료 코드 1
  - 토큰은 프로세스 메모리에만 두고 한 명령 안에서 realm · service · scope 별로 다시 쓴다
  - 헬퍼의 `store`(`{"ServerURL", "Username", "Secret"}`) · `erase`(`<호스트>[:<포트>]`)를 부르는 함수
- T2 의 전송에 401 을 받아 인증하고 다시 보내는 자리를 잇는다
- `src/test/fake_registry.py` — 인증 모드 `none` · `basic` · `bearer`(같은 서버에 토큰 realm). 받아들일 자격증명은 띄울 때 준다
- `src/test/stub-credential-helper` — 테스트가 임시 디렉터리에 `docker-credential-<이름>` 으로 링크하고 PATH 앞에 둔다. 받은 인자와 표준 입력을
  기록 파일에 남기고, 환경 변수로 받은 자격증명을 `get` 에 내며, 표준 오류에 표지 문자열을 쓴다. 실행 비트를 둔다
- `src/test/unit/test_registry_auth.py` — `login` 의 확인 · 저장 경로 케이스는 T8 이 더한다
- 건드릴 파일: `src/harness/registry/auth.py`(신규), `src/harness/registry/transport.py`, `src/test/fake_registry.py`,
  `src/test/stub-credential-helper`(신규), `src/test/unit/test_registry_auth.py`(신규)

### 완료 조건

- [ ] 네 출처가 모두 있으면 `credHelpers`, 없애 가며 `credsStore` → `auths` → 익명 순서로 고른다
- [ ] `credHelpers` 의 헬퍼가 0 이 아닌 코드로 끝나면 `credsStore` 로 간다
- [ ] `https://Registry.Example.Test:5000/v2/` 같은 키가 `registry.example.test:5000` 과 맞는다
- [ ] 규칙 밖 헬퍼 이름은 부르지 않고 종료 코드 2, PATH 에 없는 헬퍼는 `is not on PATH` 와 종료 코드 2 다
- [ ] `DOCKER_CONFIG` 가 가리키는 파일을 읽고, JSON 이 아니면 `cannot read the docker config` 와 종료 코드 2 이며 내용이 출력에 없다
- [ ] Bearer · Basic challenge 를 따옴표 · 인자 순서와 상관없이 읽는다
- [ ] 토큰 요청의 scope 가 challenge 의 것, 없으면 받기 · 올리기 · end-1 에 맞는 값이다. 자격증명이 없으면 Basic 없이 익명 토큰을 받는다
- [ ] 같은 realm · service · scope 의 토큰을 한 명령 안에서 다시 받지 않는다
- [ ] identity token 이 명세 6-1 의 오류와 종료 코드 1 이다
- [ ] 자격증명이 필요한데 없으면 `the registry needs credentials` 와 `harness registry login <registry>` 안내, 종료 코드 1 이다
- [ ] 출력에 스텁 헬퍼의 표지 · 토큰 · 비밀번호 문자열이 없다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 찾는 순서 | `credHelpers` · `credsStore` · `auths` 를 하나씩 지운 docker 설정 4종 | `credHelpers` · `credsStore` · `auths` · 익명 |
| UT-02 | 헬퍼 실패 시 다음 | `get` 이 1 로 끝나는 `credHelpers` 헬퍼와 정상 `credsStore` | `credsStore` 의 자격증명 |
| UT-03 | 키 정규화 | `auths` 키 `https://Registry.Example.Test:5000/v2/` | `registry.example.test:5000` 에 맞는다 |
| UT-04 | 헬퍼 이름 · PATH | 이름 `../x` · `-x`, PATH 에 없는 이름 | 부르지 않고 종료 코드 2, `is not on PATH` |
| UT-05 | `DOCKER_CONFIG` | 임시 위치의 설정, JSON 이 아닌 설정(표지 심음) | 그 파일을 읽음, `cannot read the docker config` · 종료 코드 2 · 표지 없음 |
| UT-06 | challenge 파싱 | `Bearer realm="http://127.0.0.1:P/token",service="s",scope="repository:a:pull"` · 인자 순서를 바꾼 것 · 따옴표 없는 값 · `Basic realm="x"` | realm · service · scope · 방식이 같게 읽힌다 |
| UT-07 | 토큰 요청 scope | challenge 에 scope 없음 — 받기 · 올리기 · end-1 | `repository:<저장소>:pull` · `pull,push` · scope 없음 |
| UT-08 | 익명 토큰 | 자격증명 없이 bearer 모드 가짜 레지스트리 | 토큰 요청에 `Authorization` 없음, 원래 요청 통과 |
| UT-09 | 토큰 다시 쓰기 | 같은 scope 로 요청 두 번 | 토큰 요청 한 번 |
| UT-10 | 다시 거부 | 틀린 자격증명으로 basic 모드 | 한 번만 다시 보내고 명세 5-4 의 오류 |
| UT-11 | identity token | 헬퍼 사용자 이름 `<token>` · `identitytoken` 만 있는 `auths` | 명세 6-1 의 오류, 종료 코드 1 |
| UT-12 | 자격증명 없음 | basic 모드에 익명 | `error: the registry needs credentials`, 종료 코드 1 |
| UT-13 | 새지 않음 | UT-01 · UT-02 · UT-08 · UT-10 의 출력 | 스텁 헬퍼 표지 · 토큰 · 비밀번호 문자열 없음 |

## T4 · feat: OCI Distribution 엔드포인트 7개와 referrers 조회

### 상위 Requirement

- relates to #218

### 작업 내용

명세가 쓰는 엔드포인트 일곱을 부르는 클라이언트와, referrers 를 API 경로와 태그 규칙 fallback 으로 읽는 조회를 만든다. 두 명령과 OCI
백엔드가 같이 쓰는 "blob 이 있는지 보고 올리기 · manifest 를 태그에 올리고 digest 대조" 순서도 여기 둔다.

- 명세 5-1(엔드포인트) · 5-3 의 업로드 `Location` · 7(referrers) · 8-3 의 순서 2 · 3 · 10-1(업로드 · referrers 모드) · 10-2 의 `test_registry_referrers.py`
- `src/harness/registry/client.py`
  - end-1 `GET /v2/` · end-2 blob `GET` · `HEAD` · end-3 manifest `GET` · `HEAD`(태그 또는 digest) · end-4a 업로드 세션 · end-6 `PUT <Location>?digest=<digest>` ·
    end-7a manifest `PUT` · end-12a referrers. 이 밖의 엔드포인트(삭제 · 태그 목록 · 마운트 · 청크 업로드 · referrers 필터)는 부르지 않는다
  - 오류 출력의 `<동작>` 을 엔드포인트마다 명세 5-4 의 이름으로 넘기고, 인증 scope 를 받기 · 올리기로 넘긴다
  - 업로드 `Location` 이 상대 경로면 레지스트리 기준으로 풀고, 절대 URL 이면 명세 5-2 를 거치며 호스트가 다르면 `Authorization` 을 붙이지 않는다
  - blob 은 설명자 크기만큼만 읽는다
  - 올리기 순서 — blob 마다 end-2 `HEAD` 로 보고 없으면 end-4a · end-6, 응답의 `Docker-Content-Digest` 가 있으면 blob digest 와 같아야 한다.
    end-7a 로 manifest 를 태그에 올리고, 응답의 `Docker-Content-Digest` 가 있으면 manifest digest 와 같아야 한다
  - referrers — subject 는 manifest digest. end-12a 가 200 이면 그 image index 의 `manifests`(경로 `api`), 404 면 end-3 으로 태그
    `sha256-<64자리 16진>` 의 image index 를 받아 200 이면 그 `manifests`, 404 면 빈 목록(경로 `fallback`), 그 밖의 상태는 조회 실패.
    index 는 4 MiB 상한과 `mediaType` 검사를 거치고 항목은 `artifactType` · `digest` · `size` 만 읽는다. `Link` 에 `rel="next"` 가 있으면
    따라가지 않고 그 사실을 돌려준다(출력 `note: the registry lists more referrers than shown` 은 T7)
  - `subject` 가 달린 manifest 나 태그 규칙 index 를 올리는 함수를 두지 않는다
- `src/test/fake_registry.py` — 업로드 세션(`POST` → 상대 `Location`, `PUT ?digest=` 가 내용의 sha256 과 맞는지 확인), manifest `PUT`(태그에 저장,
  `Docker-Content-Digest`, image index 미디어 타입도 받는다), referrers 모드 `api`(저장된 manifest 의 `subject` 로 index 를 만든다) · `absent`(404)
- `src/test/unit/test_registry_referrers.py`, 업로드 `Location` 케이스는 `src/test/unit/test_registry_transport.py` 에 더한다
- 건드릴 파일: `src/harness/registry/client.py`(신규), `src/test/fake_registry.py`, `src/test/unit/test_registry_referrers.py`(신규),
  `src/test/unit/test_registry_transport.py`

### 완료 조건

- [ ] 가짜 레지스트리에 blob 둘과 manifest 를 올리고 태그 · digest 로 다시 받은 바이트가 같다
- [ ] 이미 있는 blob 은 다시 올리지 않는다(요청 기록에 `POST` 가 없다)
- [ ] 틀린 `Docker-Content-Digest` 를 주입하면 올리기가 실패한다
- [ ] 상대 `Location` 은 레지스트리 기준으로, 다른 호스트의 절대 `Location` 은 `Authorization` 없이 간다
- [ ] referrers 가 `api` 모드에서 경로 `api` 와 연결된 항목을, `absent` 모드에서 태그 규칙 index 가 있으면 경로 `fallback` 과 그 항목을,
  둘 다 없으면 빈 목록을 돌려준다
- [ ] index 의 `mediaType` 이 다르거나 4 MiB 를 넘으면 조회 실패다. `rel="next"` 를 따라가지 않고 그 사실을 돌려준다
- [ ] 요청 기록에 명세 5-1 밖의 메서드 · 경로가 없다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 올리고 받기 | blob 둘 · manifest 를 올리고 태그 · digest 로 받기 | 바이트가 같다 |
| UT-02 | 있는 blob | 같은 blob 을 두 번 올리기 | 두 번째에 `POST` · `PUT` 없음 |
| UT-03 | 응답 digest 대조 | 틀린 `Docker-Content-Digest` 주입 | 올리기 실패 |
| UT-04 | 업로드 `Location` | 상대 경로, 두 번째 서버를 가리키는 절대 URL(`test_registry_transport.py`) | 레지스트리 기준으로 감, 두 번째 서버 기록에 `Authorization` 없음 |
| UT-05 | `api` 경로 | `api` 모드, subject 가 달린 manifest 하나 | 경로 `api`, 항목의 `artifactType` · `digest` · `size` |
| UT-06 | `fallback` 경로 | `absent` 모드, 태그 `sha256-<hex>` 의 index | 경로 `fallback`, 그 index 의 항목 |
| UT-07 | 둘 다 없음 | `absent` 모드, 태그 규칙 index 없음 | 경로 `fallback`, 빈 목록 |
| UT-08 | 다음 쪽 | `Link: <…>; rel="next"` | 다음 쪽 요청 없음, 더 있다는 표시 |
| UT-09 | index 검사 | `mediaType` 이 manifest 인 응답, 4 MiB 를 넘는 index | 조회 실패 |
| UT-10 | 쓰는 엔드포인트 | UT-01 ~ UT-07 의 요청 기록 | 명세 5-1 의 메서드 · 경로만 |

## T5 · feat: preset 리포 HEAD 에서 재현 가능한 아티팩트와 OCI Image Layout 쓰기

### 상위 Requirement

- relates to #218

### 작업 내용

preset 리포의 HEAD 커밋에서 preset 트리 파일을 읽어, 누가 언제 빌드해도 같은 바이트가 나오는 레이어 · manifest · OCI Image Layout 을
쓰는 함수를 만든다. 명령(`preset build`)은 T7 이 이 함수에 잇는다.

- 명세 3-1(manifest) · 3-2(annotation · `source` 정규화) · 3-3(레이어 · 이름 규칙 · tar · gzip) · 3-4(레이아웃 쓰기) · 3-5(재현성) · 8-1 의
  HEAD 읽기 · 함수 거부 문구 · 이름 규칙 · 트리 검증 · 10-2 의 `test_registry_artifact.py`
- `src/harness/registry/artifact.py` 의 쓰기 쪽 — 두 부분으로 나눈다
  - 파일 목록과 annotation 에서 만들기 — tar(USTAR, 일반 파일만, 경로 바이트 순, `./` 없음, 모드 `0644`, uid · gid 0, 빈 uname · gname,
    mtime 0), gzip(머리 10바이트 `1f 8b 08 00 00 00 00 00 02 ff` 를 직접 쓰고 zlib raw deflate 레벨 9, 끝에 CRC32 와 원래 크기를 리틀 엔디언
    4바이트씩), 빈 config, manifest(명세 3-1), 레이아웃(`oci-layout` · `index.json` 의 설명자에 `artifactType` 과 `org.opencontainers.image.ref.name` ·
    `blobs/sha256/<hex>`). JSON 직렬화는 키 정렬 · 공백 없는 구분자 · ASCII 밖 `\u` 이스케이프 · 끝 줄바꿈 없음. `registry check` 의 확인용
    아티팩트(T9)가 이 부분만 쓴다
  - preset 리포 HEAD 에서 파일 목록 읽기 — `git ls-tree -r -t -z --full-tree HEAD` 의 항목을 #216 3-2 의 트리 멤버 판정 함수에 넘기고,
    받을 파일의 바이트를 `git cat-file blob` 으로 읽는다(줄바꿈 변환 · git 필터 없음, 실행 비트 버림). 받지 않은 항목은 버린다.
    함수가 거부하면 명세 8-1 의 `error: the preset tree has an entry the harness does not accept (<사유>, entry <순번>)` · `-->` · `help:`,
    `preset.toml` 이 없으면 `error: the preset tree has no preset.toml at its root`. 고른 경로가 명세 3-3 의 이름 규칙(ASCII
    `[A-Za-z0-9_.-]+` 성분, 100바이트 이하) 밖이면 같은 문구에 사유 `not a safe path`. 고른 트리를 #216 의 preset 트리 검증(`preset.toml`
    판정 · UTF-8)에 넘기고 거부되면 그 문구(`<참조>` 자리는 `--source` 디렉터리). 모두 종료 코드 2
  - annotation — `version`(태그) · `revision`(`git rev-parse HEAD`) · `created`(`git log -1 --format=%ct HEAD` 를 UTC `YYYY-MM-DDTHH:MM:SSZ` 로) ·
    `source`(`git remote get-url origin` 을 명세 3-2 의 표로 정규화, 못 하면 키 없음) · `io.github.willjsw.harness.requires`(preset 트리의
    `[preset].requires`, 없으면 키 없음) · `io.github.willjsw.harness.schema`(`1`)
  - 내용 해시는 #216 4-4 의 함수로 받을 파일의 바이트에서 계산해 돌려준다
- `src/test/unit/test_registry_artifact.py` — 임시 git preset 리포를 만들어 쓴다
- 건드릴 파일: `src/harness/registry/artifact.py`(신규), `src/test/unit/test_registry_artifact.py`(신규)

### 완료 조건

- [ ] 같은 커밋을 두 번 빌드한 레이아웃의 모든 파일 바이트가 같다
- [ ] 작업 트리의 mtime · umask · 실행 비트 · 커밋하지 않은 변경을 바꿔 빌드해도 레이아웃 바이트가 같다
- [ ] `origin` 이 `https://user:token@Host.Example.Test/team/preset.git` 와 `git@host.example.test:team/preset` 일 때 manifest 가 같고, annotation 에 userinfo 가 없다
- [ ] 태그만 바꾸면 레이어 digest 는 같고 manifest digest 는 다르다
- [ ] 레이어의 앞 10바이트가 명세 3-3 의 고정값이다
- [ ] tar 멤버가 경로 바이트 순의 일반 파일뿐이고 모드 · 소유자 · 시각이 명세 3-3 의 값이다
- [ ] 받는 디렉터리 아래의 심볼릭 링크 · 서브모듈 · 규칙 밖 이름이 명세 8-1 의 문구로 거부되고, 문구에 사유와 `git ls-tree` 줄 순번이 있으며 경로가 없다
- [ ] 받는 디렉터리 밖의 링크(README 등)와 파일은 레이어에 들지 않고 빌드가 통과한다
- [ ] `[preset].requires` 가 없는 트리는 `requires` 키가 없고, `origin` 이 없으면 `source` 키가 없다
- [ ] 돌려준 내용 해시가 #216 4-4 의 셸 계산과 같다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 같은 커밋 두 번 | 한 커밋을 두 출력 디렉터리에 빌드 | 모든 파일 바이트가 같다 |
| UT-02 | 작업 트리와 무관 | mtime · umask · 실행 비트를 바꾸고 커밋하지 않은 변경을 둔 뒤 빌드 | UT-01 과 같은 바이트 |
| UT-03 | `origin` 정규화 | https(userinfo 포함) · scp · `ssh://` 형식의 같은 저장소 | 같은 manifest, `source` 가 `https://host.example.test/team/preset`, userinfo 없음 |
| UT-04 | 정규화할 수 없는 `origin` | `file://` · 로컬 경로 · `origin` 없음 | `source` 키 없음 |
| UT-05 | 태그만 다름 | 같은 커밋을 태그 `1.0.0` · `1.0.1` 로 | 레이어 digest 같음, manifest digest 다름 |
| UT-06 | gzip 머리 | 빌드한 레이어 | 앞 10바이트가 `1f 8b 08 00 00 00 00 00 02 ff` |
| UT-07 | tar 메타 | 빌드한 레이어의 멤버 | 일반 파일, 바이트 순, `0644`, uid · gid 0, 빈 이름, mtime 0 |
| UT-08 | 거부되는 항목 | `project/roles/` 아래 링크 · 서브모듈 · 규칙 밖 이름(이름에 표지) | 명세 8-1 문구, 사유와 `git ls-tree` 줄 순번, 표지 없음, 종료 코드 2 |
| UT-09 | 받지 않는 항목 | 루트의 링크 README · `tests/` 디렉터리 | 레이어에 없음, 빌드 통과 |
| UT-10 | `preset.toml` 없음 | `project/roles/a.md` 만 있는 커밋 | `error: the preset tree has no preset.toml at its root` |
| UT-11 | annotation | `[preset].requires = "0.14.0"` 인 트리, 커밋 시각을 고정한 커밋 | `requires` 가 `0.14.0`, `created` 가 커미터 시각의 UTC, `revision` 이 커밋 id, `schema` 가 `1` |
| UT-12 | 내용 해시 | 고정한 트리 | #216 4-4 의 셸 계산과 같은 값 |

## T6 · feat: 받은 manifest·레이어·멤버 검사와 하네스 루트 밖 풀기

### 상위 Requirement

- relates to #218

### 작업 내용

레지스트리나 레이아웃에서 받은 아티팩트를 신뢰하지 않는 입력으로 검사하고, 받는 파일만 하네스 루트 밖 임시 디렉터리에 푸는 함수를
만든다. 참조 하나에서 manifest 를 받아 검사하고 레이어를 받아 검사하고 푸는 함수도 두어 `preset inspect`(T7) · `registry check`(T9) ·
OCI 백엔드(T11)가 같이 쓴다.

- 명세 4-1(manifest) · 4-2(레이어와 멤버) · 4-3(풀기) · 3-4 의 레이아웃 읽기 · 10-2 의 `test_registry_manifest.py` · `test_registry_extract.py`
- `src/harness/registry/artifact.py` 의 검사 쪽
  - manifest — 명세 4-1 의 검사 아홉을 위에서부터, 처음 어긋난 사유로 `error: not a harness preset artifact (<사유>)` · `--> <참조>`, 종료 코드 1.
    레지스트리에서 온 값(미디어 타입 · annotation)을 문구에 옮기지 않는다. 태그로 받았으면 본문 sha256 이 해석된 식별자다
  - 레이어 tar 전용 검사 — blob 은 설명자 크기만 읽고 sha256 대조, 풀어낸 크기가 64 MiB 를 넘으면 그 자리에서 멈춘다, 멤버 2,048 개 이하,
    멤버마다 종류(일반 파일 · 디렉터리, 링크 둘은 따로 사유) · 이름(명세 3-3 의 규칙, 디렉터리는 끝의 `/` 를 뗌) · 중복과 "파일이 다른 멤버의
    부모" 판정. 표준 라이브러리에 `tarfile.data_filter` 가 있으면 통과한 멤버에 보조로 적용해 사유 `rejected by the tar data filter`
  - #216 3-2 의 함수 — 멤버 전부를 tar 순서대로 (경로, 종류) 목록으로 넘긴다. 함수의 거부는 사유와 순번 그대로, `preset.toml` 없음은
    `error: the preset layer has no preset.toml at its root`, 받지 않은 항목이 하나라도 있으면 사유 `outside the preset tree` 와 그 첫 멤버의 번호
  - 멤버 문구는 `error: the preset layer has a member the harness does not accept (<사유>, member <번호>)` · `--> <참조>`, 종료 코드 1. 멤버 이름을 내지 않는다.
    blob 의 크기 · sha256 어긋남은 manifest 문구에 사유 `digest mismatch` 로, 풀어낸 크기 · 멤버 수 상한은 멤버 문구에 사유 `too large` ·
    `too many members` 와 넘친 멤버의 번호로 낸다
  - 풀기 — `tempfile.mkdtemp()` 에 받는 파일의 내용만 직접 쓴다(`extractall` 을 쓰지 않는다). 파일에 필요한 부모 디렉터리만 만들고,
    파일 `0644` · 디렉터리 `0755`. 하나라도 거부되면 임시 디렉터리를 지우고 아무것도 넘기지 않는다. 명령이 끝나면 성공 · 실패와 상관없이
    지우도록 쓰는 쪽이 감싸 쓰는 형태로 둔다
  - 레이아웃 읽기 — `oci-layout` 의 버전 `1.0.0`, `index.json` 의 manifest 설명자 하나, blob 마다 파일 이름 · 크기 · sha256 이 설명자와 맞는지.
    그 밖의 파일은 읽지 않는다. `oci-layout` · `index.json` 이 어긋나면 manifest 문구에 사유 `not an OCI image layout`, blob 이 어긋나면 `digest mismatch`.
    `<참조>` 는 레이아웃 디렉터리다
  - 받기 순서 — 참조(전체 참조 또는 digest 참조)에서 T4 로 manifest 를 받아 검사하고, 레이어를 받아 검사하고, 풀어 낸 트리 · 해석된 식별자 ·
    annotation · 받는 파일 목록 · 내용 해시(#216 4-4)를 돌려준다
- `src/test/unit/test_registry_manifest.py` · `src/test/unit/test_registry_extract.py`
- 건드릴 파일: `src/harness/registry/artifact.py`, `src/test/unit/test_registry_manifest.py`(신규), `src/test/unit/test_registry_extract.py`(신규)

### 완료 조건

- [ ] 명세 4-1 의 어긋남 아홉이 각각 표의 사유로 거부되고, 둘이 겹치면 위의 사유다
- [ ] 거부 문구에 레지스트리에서 온 미디어 타입 · annotation 값(심은 표지)이 없다
- [ ] 명세 10-2 의 `test_registry_extract.py` 케이스가 각각 거부되고, 거부 뒤 임시 디렉터리가 남지 않는다
- [ ] #216 의 함수가 거부한 경우 문구에 그 사유와 순번이 그대로 든다
- [ ] 받는 파일이 tar 의 모드 · 소유자와 상관없이 `0644` 로 풀리고 디렉터리 멤버로는 아무것도 만들지 않는다
- [ ] 거부 문구에 멤버 이름(심은 표지)이 없다
- [ ] 레이아웃의 `oci-layout` 버전 · 설명자 수 · blob 크기와 sha256 이 어긋나면 각각 거부된다
- [ ] 받기 순서 함수가 가짜 레지스트리에서 받은 트리의 내용 해시가 T5 가 같은 트리로 돌려준 값과 같다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | manifest 어긋남 | 4 MiB 초과 · digest 다름 · `Docker-Content-Digest` 다름 · 다른 `mediaType` · 다른 `artifactType` · 다른 config · 레이어 둘 · 16 MiB 초과 레이어 · `schema` `2` | 명세 4-1 표의 사유 각각, 종료 코드 1 |
| UT-02 | 거부 문구에 값 없음 | `artifactType` · annotation 에 표지를 심은 manifest | 표지 없음 |
| UT-03 | 멤버 종류 | 심볼릭 링크 · 하드 링크 · 장치 · FIFO | `a symbolic link` · `a hard link` · `not a regular file or directory` |
| UT-04 | 멤버 이름 | 절대 경로 · `..` · `./` · 공백 · 비ASCII · 100바이트 초과 | `not a safe path` |
| UT-05 | 중복 | 같은 이름 둘 · 파일 아래 파일 | `a duplicate name` |
| UT-06 | #216 의 함수 | 받는 디렉터리 아래 규칙 밖 이름 · `preset.toml` 없음 | 함수의 사유와 순번 · `the preset layer has no preset.toml at its root` |
| UT-07 | 받는 디렉터리 밖 | 루트의 `README.md` · `tests/` 디렉터리 | `outside the preset tree`, 첫 멤버 번호 |
| UT-08 | 상한 | 멤버 2,049 개 · 설명자보다 큰 blob · 64 MiB 를 넘게 풀리는 tar | `too many members` · `digest mismatch` · `too large` |
| UT-09 | 남는 것 없음 | UT-03 ~ UT-08 의 거부 뒤 임시 위치 | 새 디렉터리 없음 |
| UT-10 | 풀린 모드 | 모드 `0755` · 다른 uid 의 멤버 | 파일 `0644`, 디렉터리 `0755` |
| UT-11 | 멤버 이름이 문구에 없음 | 이름에 표지를 심은 거부 멤버 | 표지 없음 |
| UT-12 | 레이아웃 읽기 | `oci-layout` 버전 `1.1.0` · 설명자 둘 · 크기가 다른 blob · 바뀐 blob | `not an OCI image layout` · `not an OCI image layout` · `digest mismatch` · `digest mismatch` |
| UT-13 | 받기 순서 | T5 로 만든 아티팩트를 가짜 레지스트리에 올리고 받기 | 받는 파일 목록과 내용 해시가 T5 의 값과 같다 |

## T7 · feat: harness preset build·inspect·push 명령

### 상위 Requirement

- relates to #218

### 작업 내용

`harness preset` 명령을 통과 명령으로 더하고, 하위 명령 `build` · `inspect` · `push` 를 T1 ~ T6 의 함수에 잇는다. 회귀 테스트의 새 블록을 만든다.

- 명세 8 공통(종료 코드 · 이스케이프) · 8-1 · 8-2 · 8-3 · 8-9(`preset` 행과 하위 명령 해석) · 10-3 의 "왕복" · "다시 push" · "태그 불일치" · "새지 않음"
- `src/harness/commands/__init__.py` — 명령 표에 `preset` 항목 `(True, False, "build|inspect|push ...", "build, inspect or push a preset as an OCI artifact")`
- `src/harness/cli.py` — `preset` 을 대상 해석 · 위임 앞에서 명령 모듈로 가는 목록(#206 3-3 의 3단계)에 더한다. `DELEGATES` 에 넣지 않는다
- `src/harness/commands/preset.py`
  - 하위 명령과 옵션을 해석한다 — `--tag` · `--output` · `--source`(build), `--yes`(push). 하위 명령이 없거나 모르거나 받지 않는 옵션 · 인자가
    오면 사용법과 종료 코드 2, `-h` · `--help` 면 사용법과 종료 코드 0
  - `build` — `--source`(기본 현재 디렉터리)가 git 작업 트리 최상위가 아니면 거부, `--tag` 는 태그 규칙, `--output` 은 없거나 빈 디렉터리이고
    `--source` 밖. 명세 8-1 의 오류 문구와 종료 코드 2. preset 트리 경로에 커밋하지 않은 변경이 있으면 `note: uncommitted changes under the preset tree are not in the artifact (built from HEAD <짧은 id>)`.
    T5 로 쓰고 `built:` 네 줄을 낸다
  - `inspect` — 입력이 `oci://` 면 원격(전체 참조 · digest 참조), `oci-layout` 파일이 있는 디렉터리면 레이아웃, 그 밖은 짧은 이름. T6 으로 받아
    검사하고 명세 8-2 의 출력. annotation 이 없는 줄은 내지 않고, 레이아웃이면 `referrers` 줄이 없다. referrers 조회가 실패하면
    `referrers  unavailable (<상태 코드>)` 이고 종료 코드 0. 다음 쪽이 있으면 `note: the registry lists more referrers than shown`.
    레지스트리에서 온 문자열(annotation 값 · `artifactType`)은 제어 문자를 이스케이프한다. 임시 디렉터리는 끝날 때 지운다
  - `push` — 참조는 전체 참조나 짧은 이름. 태그를 빼면 레이아웃의 태그, 적었으면 레이아웃의 태그와 같아야 한다(다르면 레지스트리에 요청하지
    않고 종료 코드 2). 올리기 전에 레이아웃을 T6 으로 검사한다. end-3 `HEAD` 로 태그를 보고(`Docker-Content-Digest` 가 없으면 `GET` 으로
    계산) — 404 면 새 태그, 같으면 `already pushed: the tag points to the same manifest` 와 종료 코드 0, 다르고 `--yes` 가 없으면 명세 8-3 의
    `error: the tag already points to a different manifest` 안내와 종료 코드 1. 그 뒤 T4 의 올리기 순서. 성공하면 `pushed:` 와 `manifest` 줄
- `src/test/render-test.sh` — 새 `UT-<번호>` 블록 "OCI 레지스트리"
  - 준비: `HARNESS_HOME` · `DOCKER_CONFIG` · `TMPDIR` 을 블록 전용 임시 위치에, 스텁 헬퍼를 PATH 앞에, 가짜 레지스트리를 백그라운드로 띄우고
    블록이 끝나면(실패 포함) 멈춘다. 임시 git preset 리포를 만든다
  - 블록의 모든 명령 출력을 모아 스텁 헬퍼 표지 · 비밀번호 · 토큰 문자열이 없는지 보는 도우미를 둔다. 뒤 task 의 케이스도 이것을 거친다
  - 케이스: 왕복 · 다시 push · 태그 불일치 · 사용법 · 위임하지 않음. 한글 검사를 이 블록의 출력에도 적용한다
- 건드릴 파일: `src/harness/commands/__init__.py`, `src/harness/cli.py`, `src/harness/commands/preset.py`(신규), `src/test/render-test.sh`

### 완료 조건

- [ ] 임시 git preset 리포에서 `preset build` → bearer 모드 가짜 레지스트리에 `preset push` → `preset inspect` 의 `manifest` · `content` 가 build 출력과 같다
- [ ] 레이아웃 디렉터리를 `preset inspect` 하면 같은 `manifest` · `content` 이고 `referrers` 줄이 없다
- [ ] 같은 레이아웃을 다시 push 하면 `already pushed` 와 종료 코드 0 이다
- [ ] 같은 태그에 다른 레이아웃을 `--yes` 없이 push 하면 종료 코드 1 · `nothing was pushed` 이고 레지스트리의 태그가 그대로다. `--yes` 면 바뀐다
- [ ] 참조의 태그가 레이아웃의 태그와 다르면 종료 코드 2 이고 가짜 레지스트리의 요청 기록이 늘지 않는다
- [ ] build 의 입력 거부(작업 트리 최상위 아님 · 비지 않은 출력 · `--source` 안의 출력 · 규칙 밖 태그)가 각각 명세 8-1 의 문구와 종료 코드 2 다
- [ ] 하위 명령 없음 · 모르는 하위 명령 · 받지 않는 옵션이 종료 코드 2, `--help` 가 종료 코드 0 이다
- [ ] 고정 사본이 있는 리포 안에서 불러도 고정 사본으로 넘기지 않는다(`note: this project is pinned` 가 없다)
- [ ] `harness help` 에 `preset` 행이 있고, 생성된 `.claude/settings.json` 의 허용 목록에 `preset` 이 없다
- [ ] 블록 출력에 스텁 헬퍼 표지 · 비밀번호 · 토큰 문자열과 한글이 없다
- [ ] `test_commands.py` 스모크 테스트와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 왕복 (render-test) | build → bearer 가짜 레지스트리에 push → 원격 inspect | `manifest` · `content` 가 build 출력과 같다 |
| UT-02 | 레이아웃 inspect (render-test) | build 출력 디렉터리 | 같은 `manifest` · `content`, `referrers` 줄 없음, `files` 가 바이트 순 |
| UT-03 | 다시 push (render-test) | 같은 레이아웃 · 같은 태그의 다른 레이아웃(`--yes` 없이, 있게) | `already pushed` · 0 / 1 · `nothing was pushed` · 태그 그대로 / 태그 바뀜 |
| UT-04 | 태그 불일치 (render-test) | 레이아웃 태그 `1.0.0` 을 `oci://127.0.0.1:<포트>/team/preset:1.0.1` 로 | 종료 코드 2, 요청 기록 그대로 |
| UT-05 | build 입력 거부 (render-test) | 하위 디렉터리를 `--source` 로 · 파일이 든 `--output` · `--source` 안의 `--output` · 태그 `.x` | 명세 8-1 의 문구 각각, 종료 코드 2 |
| UT-06 | 커밋하지 않은 변경 (render-test) | preset 트리 파일을 고친 뒤 build | `note: uncommitted changes under the preset tree …`, 레이아웃은 HEAD 와 같다 |
| UT-07 | 사용법 (render-test) | `preset` · `preset x` · `preset build --yes` · `preset --help` | 2 · 2 · 2 · 0 |
| UT-08 | 위임하지 않음 (render-test) | 고정 사본이 있는 리포를 현재 디렉터리로 `src/bin/harness preset build …` | `note: this project is pinned` 없음, 소스 CLI 로 빌드 |
| UT-09 | 명령 표 (render-test) | `harness help`, 생성된 `.claude/settings.json` | `preset` 행 있음, 허용 목록에 없음 |
| UT-10 | 새지 않음 (render-test) | 블록의 모든 출력 | 표지 · 비밀번호 · 토큰 · 한글 없음 |

## T8 · feat: harness registry use·login·logout 명령

### 상위 Requirement

- relates to #218

### 작업 내용

`harness registry` 명령을 통과 명령으로 더하고, 기기 기본 레지스트리를 정하는 `use` 와 credential helper 로 자격증명을 저장 · 삭제하는
`login` · `logout` 을 만든다. 비밀번호는 터미널에서만 받는다.

- 명세 8-4 · 8-5 · 8-6 · 8-9(`registry` 행) · 10-2 의 `test_registry_auth.py` 가운데 login 의 확인 · 저장 경로 · 10-3 의 "기본 레지스트리" · "login" · "logout"
- `src/harness/commands/__init__.py` — 명령 표에 `registry` 항목 `(True, False, "login|logout|use|check ...", "log in through a docker credential helper, set the default registry, or check a registry")`
- `src/harness/cli.py` — `registry` 를 대상 해석 · 위임 앞 목록에 더한다. `DELEGATES` 에 넣지 않는다
- `src/harness/commands/registry.py`
  - 하위 명령 해석 — `--username`(login), `--unset`(use). 사용법 규칙은 T7 과 같다. `check` 는 T9 가 채운다
  - `use` — 인자가 있으면 `<레지스트리>` 규칙으로 판정해 `oci.json` 에 쓰고 `default registry: <레지스트리>`, 어긋나면 종료 코드 2. 인자가
    없으면 지금 값이나 `no default registry`(종료 코드 0). `--unset` 이면 파일을 지우고 `default registry unset`. 레지스트리에 접속하지 않는다
  - `login` — 레지스트리를 빼면 기기 기본 레지스트리(없으면 명세 2-3 의 안내). 이 레지스트리에 쓸 헬퍼(`credHelpers` 항목, 없으면
    `credsStore`)가 없으면 명세 8-4 의 `error: no credential helper is configured for this registry` 안내와 종료 코드 2. 표준 입력이 터미널이
    아니면 `error: registry login reads the password from a terminal`, 종료 코드 2. 사용자 이름은 `--username` 이나 터미널 입력, 비밀번호는
    `getpass`. 저장 전에 end-1 의 challenge 로 그 자격증명을 한 번 써 본다 — 거부되면 `error: the registry did not accept the credentials`(종료 코드 1,
    저장하지 않음), challenge 가 없으면 `note: this registry does not ask for credentials — nothing was stored`(종료 코드 0). 통과하면 헬퍼 `store`
    와 `login succeeded: stored by docker-credential-<이름>`
  - `logout` — 헬퍼가 있으면 `erase` 와 `logged out: erased from docker-credential-<이름>`(0 이 아니면 `error: docker-credential-<이름> erase exited with <코드>`,
    종료 코드 1). 헬퍼가 없고 `auths` 에 항목이 있으면 명세 8-5 의 안내와 종료 코드 1, docker 설정 파일을 고치지 않는다. 둘 다 없으면 `not logged in`(종료 코드 0)
- `src/test/unit/test_registry_auth.py` — login 의 확인 · 저장 경로(터미널 판정과 입력 함수를 바꿔 끼워 부른다)
- `src/test/render-test.sh` 의 새 블록 — 케이스 기본 레지스트리 · login · logout
- 건드릴 파일: `src/harness/commands/__init__.py`, `src/harness/cli.py`, `src/harness/commands/registry.py`(신규),
  `src/test/unit/test_registry_auth.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] `registry use <레지스트리>` 뒤 `oci.json` 이 등록부 최상위의 파일이고 `harness projects` 의 `projects` · `legacy` 어디에도 나오지 않는다
- [ ] 기본 레지스트리를 둔 뒤 짧은 이름 `preset push` 가 펼친 참조로 간다(가짜 레지스트리의 요청 기록)
- [ ] `--unset` 뒤 짧은 이름이 종료 코드 2 와 `no default registry` 다
- [ ] 표준 입력이 터미널이 아니면 login 이 종료 코드 2 이고 스텁 헬퍼에 `store` 가 오지 않는다
- [ ] 헬퍼가 설정되지 않았으면 login 이 종료 코드 2 이고 docker 설정 파일의 바이트가 그대로다
- [ ] 터미널 입력을 바꿔 끼운 login 이 basic · bearer 모드에서 확인을 거친 뒤에만 헬퍼 `store` 를 부르고, 틀린 자격증명이면 `store` 를 부르지 않는다
- [ ] logout 이 스텁 헬퍼에 `erase` 와 `<호스트>[:<포트>]` 를 보내고, `auths` 에만 항목이 있으면 종료 코드 1 이고 docker 설정 파일이 그대로다
- [ ] 출력에 헬퍼 표지 · 토큰 · 비밀번호가 없다. `harness help` 에 `registry` 행이 있다
- [ ] `test_commands.py` 스모크 테스트와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 기본 레지스트리 (render-test) | `registry use 127.0.0.1:<포트>` → `harness projects` → 짧은 이름 `preset push` | `oci.json` 은 등록부 최상위 파일, 목록에 없음, 펼친 참조로 요청 |
| UT-02 | 해제 (render-test) | `registry use --unset` 뒤 짧은 이름 push, 인자 없는 `registry use` | 종료 코드 2 · `no default registry` / `no default registry` · 0 |
| UT-03 | use 형식 (render-test) | `registry use Registry.Example.Test` | 종료 코드 2, `oci.json` 그대로 |
| UT-04 | 터미널 아님 (render-test) | 파이프로 표준 입력을 준 `registry login` | 종료 코드 2, 헬퍼 기록에 `store` 없음 |
| UT-05 | 헬퍼 없음 (render-test) | `credsStore` · `credHelpers` 없는 docker 설정 | 종료 코드 2, `nothing was stored`, docker 설정 바이트 그대로 |
| UT-06 | 확인 뒤 저장 (단위) | 터미널 판정과 입력을 바꿔 끼우고 basic · bearer 모드, 맞는 · 틀린 자격증명 | 맞으면 `store` 한 번과 `login succeeded`, 틀리면 `store` 없음 · 종료 코드 1 |
| UT-07 | challenge 없음 (단위) | `none` 모드 | `nothing was stored` note, 종료 코드 0, `store` 없음 |
| UT-08 | logout (render-test) | 헬퍼 설정 · `auths` 만 · 둘 다 없음 | `erase` 와 레지스트리 · 종료 코드 1 과 설정 그대로 · `not logged in` |
| UT-09 | 새지 않음 (render-test) | UT-01 ~ UT-08 의 출력 | 표지 · 토큰 · 비밀번호 없음 |

## T9 · feat: harness registry check 명령

### 상위 Requirement

- relates to #218

### 작업 내용

레지스트리가 하네스의 프로토콜 왕복을 통과하는지 항목별로 점검하는 `registry check` 를 만든다. `--push` 는 확인용 아티팩트를 새 태그로
올리고 다시 받는다. 출력은 공개 기록(지원 목록)에 그대로 옮길 수 있게 호스트 · 저장소 · 자격증명을 담지 않는다.

- 명세 8-7 · 10-3 의 "check"
- `src/harness/commands/registry.py` 의 `check`
  - 인자는 `oci://<레지스트리>/<저장소>` 나 짧은 이름 `<저장소>`. 태그를 받지 않는다(태그가 있으면 사용법과 종료 코드 2)
  - 항목 여덟 — `api`(end-1 이 200 이나 401, `Docker-Distribution-Api-Version` 값, 없으면 `-`) · `transport`(HTTPS 인증서 검증 통과는
    `https, certificate verified`, 루프백 HTTP 는 `http, loopback`) · `credentials`(`credHelpers` · `credsStore` · `auths` · `none`, 헬퍼면 그 이름) ·
    `auth`(`none` · `basic` · `bearer` 와 범위 `pull` 또는 `pull,push`) · `push` · `digest` · `pull` · `referrers`(`api` 나 `fallback`, 404 는 실패가 아니다)
  - `--push` 없이는 뒤 넷이 `skip`. 한 항목이 FAIL 이면 그 항목에 기대는 뒤 항목은 `skip`
  - 확인용 아티팩트 — T5 의 "파일 목록과 annotation 에서 만들기" 로 레이어는 `preset.toml` 한 파일(주석 한 줄), annotation 은
    `org.opencontainers.image.version`(= 태그)과 `io.github.willjsw.harness.schema` 뿐. 태그는 실행마다 `harness-check-<UTC YYYYMMDDHHMMSS>-<16진 8자리 난수>`
  - `pull` 은 태그와 digest 로 다시 받은 manifest 바이트와 레이어가 올린 것과 같고 T6 의 검사를 통과하는지 본다
  - 끝에 `note: the check artifact stays in the repository as tag <태그>`. 레지스트리에서 온 헤더 값은 제어 문자를 이스케이프한다
  - 종료 코드는 FAIL 이 없으면 0, 있으면 1
- `src/test/render-test.sh` 의 새 블록 — 케이스 check
- 건드릴 파일: `src/harness/commands/registry.py`, `src/test/render-test.sh`

### 완료 조건

- [ ] referrers `absent` 모드 가짜 레지스트리에 `--push` 로 돌리면 여덟 항목이 모두 `ok`, `referrers` 가 `fallback`, 종료 코드 0 이다
- [ ] 출력에 `127.0.0.1` · 포트 · 저장소 이름 · 헬퍼 표지 · 토큰이 없다
- [ ] `--push` 없이 돌리면 `push` · `digest` · `pull` · `referrers` 가 `skip` 이다
- [ ] 두 번 돌리면 확인용 태그가 다르고, 끝 줄이 그 태그를 알린다
- [ ] 500 오류를 주입해 `push` 가 FAIL 이면 `digest` · `pull` · `referrers` 가 `skip` 이고 종료 코드 1 이다
- [ ] 태그가 붙은 인자는 종료 코드 2 다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 전부 통과 (render-test) | bearer · referrers `absent` 가짜 레지스트리, `registry check oci://127.0.0.1:<포트>/team/check --push` | 여덟 항목 `ok`, `referrers` `fallback`, 종료 코드 0 |
| UT-02 | 공개 가능한 출력 (render-test) | UT-01 의 출력 | `127.0.0.1` · 포트 · `team/check` · 표지 · 토큰 없음 |
| UT-03 | `--push` 없이 (render-test) | 같은 인자에서 `--push` 를 뺌 | 앞 넷 `ok`, 뒤 넷 `skip`, 종료 코드 0 |
| UT-04 | 새 태그 (render-test) | UT-01 을 두 번 | 두 끝 줄의 태그가 다르다 |
| UT-05 | FAIL 과 skip (render-test) | blob 업로드에 500 주입 | `push` FAIL, 뒤 셋 `skip`, 종료 코드 1 |
| UT-06 | 태그 거부 (render-test) | `registry check team/check:1` | 종료 코드 2 |

## T10 · feat: extends 의 oci:// 판정과 lock 의 oci:// 항목

### 상위 Requirement

- relates to #218

### 작업 내용

#216 이 만든 참조 판정과 lock 판정에 `oci://` 스킴을 더한다. `extends` 에 OCI 전체 참조를 쓸 수 있고, lock 이 OCI 항목을 읽고 쓰며,
출처와 태그를 나누고 잇는 자리가 `oci://` 를 안다. 네트워크는 쓰지 않는다 — 받기는 T11 이다.

- 명세 2-1 의 `extends` 판정과 거부 안내 · 2-2 · 8-8 의 lock 표 · 10-3 의 "`extends` 형식" 과 #216 블록의 "참조 형식" 기대값 · 11-1 의 씨앗 설정 주석 · 11-2 의 2-1 · 4-3 행
- `src/harness/preset/` 의 참조 판정 — `oci://` 로 시작하는 값은 T1 의 `extends` 판정에 넘기고, 거부하면 명세 2-1 의 안내
  (`error: extends is not a full OCI reference (<사유>)` · `-->` · `help: extends takes oci://<registry>/<repository>:<tag> — the harness reads registry credentials from the docker config`,
  사유가 자격증명일 때만 둘째 help 줄). `-->` 는 그 `extends` 를 담은 파일이고, preset 의 것이면 `preset.toml of <그 preset 의 참조>`. 값을 옮기지 않는다
- 같은 판정의 첫 사유 — `https://` 와 `oci://` 어느 쪽으로도 시작하지 않으면 `not an https:// or oci:// reference` 이고 그때 help 첫 줄은
  `help: extends takes https://<host>/<path>@<tag> or oci://<registry>/<repository>:<tag>`
- lock 판정 — 스킴 표에 `oci://` 행(`source` 는 `oci://<레지스트리>/<저장소>`, `tag` 는 태그 규칙, `resolved` 는 `sha256:` 뒤 소문자 16진 64자).
  읽기 판정과 쓰기가 이 행을 따른다. `resolved` 의 짧은 꼴은 #216 대로 `sha256:` 을 뗀 앞 7자다
- 출처와 태그를 나누고 잇는 자리 — 순환 판정 · 체인 연결 · 프로젝트 참조 대조는 `oci://` 를 T1 의 규칙(마지막 `:`)으로 나눠 비교하고,
  안내문 · doctor · schema `ref` 는 `<출처>:<태그>` 로 잇는다
- `set extends <oci 전체 참조>` 는 같은 판정을 거쳐 받는다. 짧은 이름은 받지 않는다(첫 사유)
- `src/templates/harness.toml`(씨앗 설정 원형)의 `extends` 주석의 받는 형식 줄을
  `#   https://<호스트>/<경로>@<태그> 또는 oci://<레지스트리>/<저장소>:<태그> 형식의 전체 참조만 받는다` 로 바꾼다
- `src/test/render-test.sh` — #216 블록 "참조 형식" 케이스의 첫 사유 · help 기대값을 위 문구로 바꾸고, 새 블록에 "`extends` 형식" 케이스
- #216 의 preset 단위 테스트에 `oci://` lock 항목 케이스를 더한다
- 건드릴 파일: `src/harness/preset/` 의 참조 판정 · lock 모듈, `src/templates/harness.toml`, `src/test/render-test.sh`, #216 의 preset 단위 테스트 파일

### 완료 조건

- [ ] `harness.toml` 의 `extends` 에 OCI 전체 참조를 두면 판정을 통과한다
- [ ] `oci://` 의 거부 사유 넷이 각각 명세 2-1 의 문구로 나오고 종료 코드 2 다. 자격증명 사유일 때만 둘째 help 줄이 있다
- [ ] 자격증명 사유일 때 심은 비밀 문자열이 표준 출력 · 표준 오류 어디에도 없다
- [ ] 짧은 이름 `extends` 가 첫 사유 `not an https:// or oci:// reference` 로 멈추고 help 첫 줄에 `oci://` 형식이 있다
- [ ] #216 블록의 "참조 형식" 케이스가 바뀐 기대값으로 통과하고 나머지 기대값은 그대로다
- [ ] `oci://` 출처와 `sha256:` 64자리 `resolved` 의 lock 이 읽히고, 다시 쓴 바이트가 같다
- [ ] `oci://` 출처에 40자리 `resolved`, `https://` 출처에 `sha256:` `resolved`, 태그가 든 `oci://` 출처는 읽을 수 없는 lock 이다
- [ ] 같은 저장소의 다른 태그 둘이 한 체인에 있으면 순환으로 거부된다(포트가 있는 레지스트리 포함)
- [ ] `set extends oci://…:<태그>` 가 `harness.toml` 만 바꾸고, `set extends team/preset:1` 은 쓰지 않고 종료 코드 2 다
- [ ] 새 대상에 `install` 하면 씨앗 설정의 `extends` 주석이 두 형식을 적는다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | `extends` 형식 (render-test) | `harness.toml` 의 `extends` 를 `oci://u:<비밀>@h/r:t` · `oci://h/r@sha256:<64>` · `oci://h/r` · `oci://H/r:t` 로 render | 사유 넷의 2-1 문구, 종료 코드 2, 첫 값에만 둘째 help, `<비밀>` 없음 |
| UT-02 | 짧은 이름 `extends` (render-test) | `extends = "team/preset:1.0.0"` | `not an https:// or oci:// reference`, help 첫 줄에 `oci://<registry>/<repository>:<tag>` |
| UT-03 | #216 참조 형식 (render-test) | #216 블록의 거부 케이스 | 첫 사유 · help 가 바뀐 문구, 나머지 사유는 그대로 |
| UT-04 | lock 의 `oci://` 행 (단위) | `oci://127.0.0.1:5000/team/preset` · `1.0.0` · `sha256:<64>` 항목 | 읽힘, 쓴 바이트가 고정 기대값과 같음, 짧은 꼴 7자 |
| UT-05 | 스킴과 맞지 않는 lock (단위) | `oci://` 에 40자리, `https://` 에 `sha256:`, `source` 에 태그 | 읽을 수 없는 lock |
| UT-06 | 순환 (단위) | `oci://127.0.0.1:5000/a:1` 이 `oci://127.0.0.1:5000/a:2` 를 잇는 체인 | 순환 거부 |
| UT-07 | `set extends` (render-test) | OCI 전체 참조 · 짧은 이름 | `harness.toml` 만 바뀜 · 종료 코드 2 와 `harness.toml` 바이트 그대로 |
| UT-08 | 씨앗 설정 주석 (render-test) | 새 대상에 `install` | `harness.toml` 에 `oci://<레지스트리>/<저장소>:<태그>` 를 적은 주석 줄 |

## T11 · feat: pull 과 install --preset 이 oci:// preset 을 레지스트리에서 받음

### 상위 Requirement

- relates to #218

### 작업 내용

#216 의 받기 단계가 참조의 스킴으로 백엔드를 고르는 자리에 OCI 백엔드를 더한다. `oci://` preset 을 레지스트리에서 받아 검사하고 풀어,
#216 의 준비 · 반영 흐름에 넘긴다. `install --preset` 은 OCI 전체 참조와 짧은 이름을 받는다.

- 명세 8-8 · 3-5 의 내용 해시 · 10-3 의 "`install --preset`" · "백엔드 사이" · "받기 거부" · "오프라인" · 11-2 의 8-1 행
- `src/harness/preset/` 의 OCI 백엔드 모듈
  - #216 의 준비 단계 안에서 — 참조 판정(T1), end-3 으로 태그의 manifest 를 받아 검사하고 레이어를 받아 검사하고 하네스 루트 밖 임시 디렉터리에
    풀기(T6 의 받기 순서), `io.github.willjsw.harness.requires` 가 있으면 풀어 낸 트리가 선언한 값과 같은지(다르면
    `error: not a harness preset artifact (requires does not match the preset tree)`), 풀어 낸 트리 · 해석된 식별자 · 태그 · 출처를 넘긴다
  - 멈추면 명세 4 · 5 · 6 절과 위 문구를 내고, 줄 목록 뒤 · help 앞에 `nothing was changed`, 종료 코드 2. 대상 리포에 직접 쓰지 않는다
  - 임시 디렉터리는 성공 · 실패와 상관없이 지운다
- 스킴으로 백엔드를 고르는 자리에 `oci://` 를 잇는다. 체인의 참조마다 자기 스킴으로 고른다
- `install --preset` — `<참조>` 는 git 전체 참조 · OCI 전체 참조 · 짧은 이름이다. 짧은 이름은 T1 로 펼친 전체 참조를 씨앗 설정의 `extends` 에 쓴다.
  `src/harness/cli.py` 의 공용 파서에 있는 `--preset` 도움말을
  `install: start the project from a preset (https://<host>/<path>@<tag>, oci://<registry>/<repository>:<tag>, or <repository>:<tag> on the default registry)` 로 바꾼다
- `src/test/render-test.sh` 의 새 블록 — 케이스 `install --preset` · 백엔드 사이 · 섞인 체인 · 받기 거부 · `requires` 불일치 · 오프라인 · 짧은 이름 install
- 건드릴 파일: `src/harness/preset/` 의 백엔드 선택 자리와 OCI 백엔드 모듈(신규), `src/harness/commands/install.py`, `src/harness/cli.py`,
  `src/test/render-test.sh`

### 완료 조건

- [ ] 빈 대상에 `install --preset oci://127.0.0.1:<포트>/<저장소>:<태그>` 하면 `.harness/preset/1/` 이 preset 트리와 같고, lock 의 `source` 가
  `oci://127.0.0.1:<포트>/<저장소>`, `tag` 가 `<태그>`, `resolved` 가 build 의 manifest digest, `content` 가 build 의 `content` 다
- [ ] 이어서 render · check 하면 lock 대조가 통과하고, pull 출력의 preset 줄이 `<출처>:<태그> -> <resolved 의 짧은 꼴>` 이다
- [ ] schema `layers` 의 preset 항목 `ref` 가 `<출처>:<태그>` 이고, 메모 절 제목의 출처가 태그 없는 `oci://` 출처다
- [ ] 같은 preset 커밋을 git 태그와 OCI 로 받은 두 대상의 vendoring 바이트와 lock `content` 가 같다
- [ ] git preset 이 `oci://` preset 을 잇는 체인을 pull 하면 lock 에 `https://` 항목과 `oci://` 항목이 깊이 순으로 있다
- [ ] 링크 멤버가 든 레이어 · 받는 디렉터리 밖 멤버가 든 레이어 · `requires` 가 트리와 다른 아티팩트를 각각 pull 하면 종료 코드 2 와
  `nothing was changed` 이고, 대상 리포의 파일 · lock · 매니페스트 바이트가 그대로이며 `TMPDIR` 에 남은 것이 없다
- [ ] 같은 레이어를 `preset inspect` 하면 종료 코드 1 이다
- [ ] 가짜 레지스트리를 멈춘 뒤 render · check 가 통과한다
- [ ] 기본 레지스트리를 둔 기기에서 `install --preset <저장소>:<태그>` 가 씨앗 설정의 `extends` 에 펼친 전체 참조를 쓴다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | `install --preset` (render-test) | build · push 한 preset 을 빈 대상에 OCI 전체 참조로 install, 이어서 render · check | vendoring 이 트리와 같음, lock 네 값이 명세 8-8 대로, check 0 |
| UT-02 | 표시 (render-test) | UT-01 의 출력 · `harness schema` · 역할 정의 | `-> <7자>` 줄, `ref` 가 `<출처>:<태그>`, 메모 절 제목에 태그 없는 출처 |
| UT-03 | 백엔드 사이 (render-test) | 같은 preset 커밋을 git 태그(#216 의 bare 리포 방식)와 OCI 로 두 대상에 | vendoring 바이트 · lock `content` 가 같다 |
| UT-04 | 섞인 체인 (render-test) | git preset 의 `preset.toml` 이 `oci://` preset 을 `extends` | lock 의 깊이 1 이 `https://`, 깊이 2 가 `oci://` |
| UT-05 | 받기 거부 (render-test) | 링크 멤버 레이어 · `README.md` 멤버 레이어를 블록이 직접 올리고 pull | 종료 코드 2, `nothing was changed`, 대상 리포 · lock · 매니페스트 바이트 그대로, `TMPDIR` 비어 있음 |
| UT-06 | inspect 로 같은 레이어 (render-test) | UT-05 의 참조를 `preset inspect` | 종료 코드 1 |
| UT-07 | `requires` 불일치 (render-test) | annotation `requires` 가 `preset.toml` 과 다른 아티팩트 | `requires does not match the preset tree`, 종료 코드 2 |
| UT-08 | 오프라인 (render-test) | UT-01 대상에서 가짜 레지스트리를 멈춘 뒤 render · check | 둘 다 통과 |
| UT-09 | 짧은 이름 install (render-test) | `registry use` 뒤 `install --preset team/preset:<태그>` | 씨앗 설정의 `extends` 가 펼친 전체 참조 |

## T12 · chore: 실제 레지스트리를 띄우는 CI 통합 잡

### 상위 Requirement

- relates to #218

### 작업 내용

가짜 레지스트리는 클라이언트와 같은 명세 해석으로 만들어져 해석이 틀리면 함께 통과한다. 그래서 CI 에서만 실제 CNCF Distribution 을
서비스 컨테이너로 띄워 왕복을 확인하는 잡을 따로 둔다. 로컬 검증(`[verify]` · pre-push · `render-test.sh`)에는 넣지 않는다.

- 명세 10-4
- `.github/workflows/registry-integration.yml` — 프로젝트 소유 파일. 하네스 게이트 파일(`harness-verify.yml`)과 따로 둔다
  - 트리거는 `harness-verify.yml` 과 같은 브랜치(`develop` · `main` 의 `pull_request` · `push`)에 경로 필터 — `src/harness/registry/**`, 두 명령 모듈,
    OCI 백엔드 파일, `src/test/integration/**`, 이 워크플로 파일
  - `ubuntu-latest` 러너, 서비스 컨테이너로 `registry:3` 을 digest 로 고정해 띄우고 러너 호스트의 루프백 포트로 붙는다
  - `actions/setup-python` 으로 `harness-verify.yml` 과 같은 python3 버전
  - `cd src && python3 -B -m unittest discover -s test/integration` 를 레지스트리 주소 `HARNESS_TEST_REGISTRY` 와 함께 돈다
- 이미지 digest — `registry:3` 의 지금 digest 전체 값을 확인해 고정하고, 확인한 경로와 그 이미지의 Distribution 버전을 리뷰 요청 본문에 적는다
- `src/test/integration/test_registry.py` — `HARNESS_TEST_REGISTRY` 가 없으면 실패한다(건너뛰지 않는다). 케이스
  - check — `registry check --push` 의 항목이 전부 `ok` 이고 `referrers` 가 `fallback`
  - 왕복 — build → push → inspect 의 manifest digest 가 같고, 같은 레이아웃을 다시 push 하면 `already pushed`
  - 받기 — `install --preset` 으로 받은 lock 의 `source` 가 태그를 뺀 출처이고 `resolved` · `content` 가 build 출력의 manifest · content 와 같다
  - referrers fallback 읽기 — 테스트가 직접 올린 연결 아티팩트(`subject` 가 달린 manifest 와 태그 `sha256-<hex>` 의 index)를 `preset inspect` 가 `fallback` 경로로 보인다
- `[verify]` 의 "Python 단위 테스트" 단계는 `test/unit` 만 찾으므로 이 테스트를 돌지 않는다. `harness.toml` 을 고치지 않는다
- 건드릴 파일: `.github/workflows/registry-integration.yml`(신규), `src/test/integration/test_registry.py`(신규)

### 완료 조건

- [ ] 워크플로가 digest 로 고정한 `registry` 이미지를 서비스 컨테이너로 쓰고, 태그만 적은 이미지 참조가 없다
- [ ] 경로 필터가 명세 10-4 의 다섯 경로이고, 트리거 브랜치가 `harness-verify.yml` 과 같다
- [ ] `HARNESS_TEST_REGISTRY` 없이 통합 테스트를 돌리면 실패한다
- [ ] `script/run-lint-test.sh` 와 `[verify]` 가 통합 테스트를 돌지 않는다
- [ ] 리뷰 요청에서 이 잡이 네 케이스를 모두 통과한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | check (CI) | 서비스 컨테이너의 레지스트리에 `registry check --push` | 여덟 항목 `ok`, `referrers` `fallback` |
| UT-02 | 왕복 (CI) | build → push → inspect, 같은 레이아웃 다시 push | manifest digest 같음, `already pushed` |
| UT-03 | 받기 (CI) | `install --preset oci://<주소>/<저장소>:<태그>` | lock `source` · `resolved` · `content` 가 build 출력과 맞다 |
| UT-04 | referrers fallback 읽기 (CI) | `subject` 가 달린 manifest 와 `sha256-<hex>` 태그의 index 를 올린 뒤 `preset inspect` | `referrers  fallback` 아래 그 아티팩트 |
| UT-05 | 주소 없음 (로컬) | `HARNESS_TEST_REGISTRY` 없이 통합 테스트 | 실패 |

## T13 · docs: README 명령·지원 범위와 환경 문서에 레지스트리 반영

### 상위 Requirement

- relates to #218

### 작업 내용

사람용 설명과 환경 문서에 두 명령과 레지스트리 인증 · 환경 변수 · 외부 시스템을 적는다. 지원 목록의 행은 T16 이 더한다.

- 명세 11-1 의 `README.md` 두 행 · `.ai/project/environment.md` 세 행 · 9절(지원 목록 표 머리와 안내)
- `README.md` "명령" 표 — `harness preset build|inspect|push` · `harness registry login|logout|use|check` 행(명세 11-1 의 서술)
- `README.md` "지원 범위" — 레지스트리 표의 머리(`레지스트리 | 검증한 버전 | referrers | 인증 | 검증 수단`)와 등재 규칙(`registry check --push` 의
  항목이 전부 `ok` 인 레지스트리만, 검증한 버전 하나, 조직 인스턴스의 호스트 · 프로젝트 · 계정 · 정책은 적지 않는다), 표 아래 안내(확인용
  아티팩트가 남으므로 정책을 걸지 않은 확인용 저장소에서 돌린다), 헬퍼가 없는 CI 는 다른 도구가 써 둔 docker 설정의 `auths` 로 인증한다는 것,
  사설 CA 는 `SSL_CERT_FILE` · `SSL_CERT_DIR` 로 준다는 것
- `.ai/project/environment.md` — "필요한 도구" 에 `docker-credential-<이름>`(선택) · `docker`(선택), "환경 변수" 에 `DOCKER_CONFIG` ·
  `SSL_CERT_FILE` · `SSL_CERT_DIR` · `HTTPS_PROXY` · `NO_PROXY` 와 `HARNESS_HOME` 용도의 `oci.json`, "외부 시스템" 에 레지스트리. 값은 적지 않는다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 환경 문서는 9장 문서 지도가 가리킬 뿐 본문에 들지 않으므로 render 로 바뀌는 것이 없는지 `src/bin/harness check` 로 본다
- 건드릴 파일: `README.md`, `.ai/project/environment.md`

### 완료 조건

- [ ] README "명령" 표에 두 명령 행이 명세 11-1 의 서술대로 있다
- [ ] README "지원 범위" 에 레지스트리 표의 머리 · 등재 규칙 · 안내 · CI 인증 · 사설 CA 문장이 있고 행은 없다
- [ ] `.ai/project/environment.md` 세 절이 명세 11-1 의 항목을 담고 값이 없다
- [ ] `src/bin/harness check` 와 `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 반영 확인 | README · `environment.md` | 명세 11-1 의 다섯 행과 9절의 표 머리 · 안내가 있다 |

## T14 · docs: #216 명세의 서술을 OCI 백엔드 이후 사실로 고침

### 상위 Requirement

- relates to #218

### 작업 내용

OCI 백엔드가 들어간 뒤 `docs/spec/216-org-presets.md` 에서 git 백엔드 하나를 전제한 서술을 지금의 사실로 고친다. 명세 11-2 표의 일곱 위치만 고친다.

- 명세 11-2
- `docs/spec/216-org-presets.md`
  - 1절 "이 단계의 preset 백엔드는 git 태그 하나다" → 백엔드가 git 태그와 OCI 둘이다
  - 2-1 머리의 "다른 스킴은 받지 않는다" 와 표의 `스킴` 행 → `oci://` 로 시작하는 값은 #218 명세 2-1 이 판정하고 그 밖의 값은 2-1 의 표대로
  - 2-1 의 첫 사유 → `not an https:// or oci:// reference` 와 그 사유의 help 첫 줄
  - 4-3 의 스킴별 판정 → `oci://` 의 값과 판정은 #218 명세 2-1 · 2-2 · 8-8
  - 8-1 의 `<참조>` 판정과 `--preset` 도움말 → git 전체 참조 · OCI 전체 참조 · 짧은 이름과 명세 11-2 의 도움말 문구
  - 14-4 의 씨앗 설정 주석 → #218 명세 11-1 의 마지막 행
  - 17-3 의 `전체 참조` 행 → #218 명세 12-3 의 `전체 참조` 행
- 건드릴 파일: `docs/spec/216-org-presets.md`

### 완료 조건

- [ ] 일곱 위치가 명세 11-2 의 오른쪽 사실과 같고, 그 밖의 서술은 바뀌지 않는다
- [ ] 고친 문구가 T10 · T11 이 낸 터미널 출력 · 주석과 글자까지 같다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 문구 대조 | #216 명세의 2-1 첫 사유 · help, 8-1 도움말, 14-4 주석과 코드 · 씨앗 설정의 문자열 | 글자까지 같다 |
| UT-02 | 범위 | `git diff` 의 바뀐 줄 | 명세 11-2 의 일곱 위치 안 |

## T15 · docs: 보호 문서에 OCI 레지스트리 백엔드 반영

### 상위 Requirement

- relates to #218

### 작업 내용

에이전트가 근거로 읽는 사실 문서를 OCI 레지스트리 백엔드에 맞춘다. 명세 12절 "보호 문서 개정 범위" 를 그대로 고치고 그 범위 밖은 고치지 않는다.

**보호 문서를 수정하는 task 다.** 2026-10-09 결정 게이트에서 사용자가 허용한 범위다. `.ai/project/scope.md` · `architecture.md` · `glossary.md` ·
`testing.md` 는 보호 문서이고 권한 설정과 명령 가드가 쓰기를 막으므로, 걸리면 사람이 대응한다.

- 명세 12-1 · 12-2 · 12-3 · 12-4
- `.ai/project/scope.md` — "할 수 있는 일" 에 preset 의 OCI 배포 · 받기와 `registry` 명령, "만들지 않는 것" 에 레지스트리와 그 관리 기능 ·
  자격증명 저장소 · 서명과 서명 검증
- `.ai/project/architecture.md` — "구성 요소"(`src/harness/registry/` · 두 명령 모듈 · 기기 단위 상태의 `oci.json`), "데이터 흐름"(preset 배포),
  "신뢰 경계"(레지스트리 응답과 받은 tar · 레지스트리 자격증명), "새 코드를 둘 곳", "계층과 의존 방향", "검사하지 않는 것"
- `.ai/project/glossary.md` — "용어" 표에 `레지스트리` · `preset 아티팩트` · `짧은 이름` · `기기 기본 레지스트리` · `credential helper` · `지원 목록`,
  #216 이 둔 `전체 참조` 행을 두 스킴으로
- `.ai/project/testing.md` — "외부 의존을 어떻게 다루나" 에 가짜 레지스트리 · 스텁 헬퍼 · `DOCKER_CONFIG` 와 CI 통합 테스트 한 항목, "하지 않는 것" 의 첫 항목을 CI 레지스트리 통합 잡 예외로
- 같은 절을 먼저 고친 이슈(#206 · #216 등)의 문장 위에 더한다 — 그 문장을 지우거나 되돌리지 않는다
- `.ai/AI_AGENT.md` 는 생성 파일이다. 문서를 고친 뒤 `src/bin/harness render` 로 갱신한다
- 건드릴 파일: `.ai/project/scope.md`, `.ai/project/architecture.md`, `.ai/project/glossary.md`, `.ai/project/testing.md`, render 로 갱신되는 `.ai/AI_AGENT.md`

### 완료 조건

- [ ] 네 문서가 명세 12-1 ~ 12-4 표의 사실을 담는다
- [ ] 바뀐 줄이 명세 12절의 위치 밖에 없고, 앞선 이슈가 고친 문장이 남아 있다
- [ ] `glossary.md` 의 `전체 참조` 행이 하나이고 두 스킴을 적는다
- [ ] `src/bin/harness render` 뒤 `.ai/AI_AGENT.md` 1 · 2 · 5장이 네 문서와 일치한다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 생성물 일치 | 문서 수정 뒤 `src/bin/harness check` | 어긋남 없음 |
| UT-02 | 반영 확인 | `.ai/AI_AGENT.md` | 1장에 레지스트리 명령과 만들지 않는 것, 2장에 새 용어 여섯과 두 스킴의 `전체 참조`, 5장에 `src/harness/registry/` · `oci.json` · 레지스트리 신뢰 경계 |
| UT-03 | 범위 | 네 문서의 `git diff` | 명세 12절 표의 위치 안 |

## T16 · docs: README 지원 목록에 CNCF Distribution 행 추가

### 상위 Requirement

- relates to #218

### 작업 내용

CI 통합 잡이 실제 CNCF Distribution 에서 왕복을 통과한 것을 근거로 README 지원 목록에 첫 행을 더한다. 명세 9절은 행을 그 잡이 통과한
뒤에 더하므로, 리뷰 요청을 올린 뒤 그 리뷰 요청에서 T12 의 잡이 통과한 실행을 확인하고 같은 브랜치에 커밋한다. 잡이 실패하면 T12 를
고치고 이 행을 넣지 않는다.

- 명세 9절의 이 이슈가 더하는 행
- `README.md` "지원 범위" 의 레지스트리 표 — `CNCF Distribution | <T12 가 고정한 이미지의 Distribution 버전> | fallback | none | CI 통합 잡`
- 버전은 T12 가 리뷰 요청 본문에 적은 값 하나다. 범위로 일반화하지 않는다
- 건드릴 파일: `README.md`

### 완료 조건

- [ ] 이 브랜치의 리뷰 요청에서 레지스트리 통합 잡이 통과한 실행이 있고, 그 실행의 링크를 리뷰 요청 본문에 적는다
- [ ] 행의 버전이 그 잡의 이미지 버전과 같고, `referrers` 가 `fallback`, `인증` 이 `none`, 검증 수단이 `CI 통합 잡` 이다
- [ ] 조직 인스턴스의 호스트 · 계정 · 정책이 표에 없다
- [ ] `script/run-lint-test.sh --commit` 이 통과한다

### 브랜치

- `feat/218-oci-registry` — 상위 이슈의 브랜치를 함께 쓴다
- 머지 타깃: `develop`

### 단위 테스트 항목

| ID | 테스트 내용 | 입력 | 기대 결과 |
| --- | --- | --- | --- |
| UT-01 | 근거 대조 | README 의 행과 통과한 잡 실행의 `registry check --push` 출력 | `referrers` · `auth` 값이 같다 |
| UT-02 | 버전 대조 | README 의 버전과 워크플로가 고정한 이미지 | 같은 버전 |
