# #218 분해 — preset 의 OCI 레지스트리 백엔드

명세: [`docs/spec/218-oci-registry.md`](../../spec/218-oci-registry.md)
결정 기록: [`docs/adr/0026-registries-use-a-stdlib-oci-client-and-docker-credential-helpers.md`](../../adr/0026-registries-use-a-stdlib-oci-client-and-docker-credential-helpers.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | OCI 참조 판정과 기기 기본 레지스트리 파일 | 없음 |
| T2 | feat | 레지스트리 연결·리다이렉트·크기 상한·오류 출력과 가짜 레지스트리 | T1 |
| T3 | feat | docker 설정과 credential helper 로 자격증명을 찾고 challenge 로 토큰 받기 | T2 |
| T4 | feat | OCI Distribution 엔드포인트 7개와 referrers 조회 | T3 |
| T5 | feat | preset 리포 HEAD 에서 재현 가능한 아티팩트와 OCI Image Layout 쓰기 | T1 |
| T6 | feat | 받은 manifest·레이어·멤버 검사와 하네스 루트 밖 풀기 | T4, T5 |
| T7 | feat | harness preset build·inspect·push 명령 | T6 |
| T8 | feat | harness registry use·login·logout 명령 | T7 |
| T9 | feat | harness registry check 명령 | T8 |
| T10 | feat | extends 의 oci:// 판정과 lock 의 oci:// 항목 | T1, T7 |
| T11 | feat | pull 과 install --preset 이 oci:// preset 을 레지스트리에서 받음 | T7, T10 |
| T12 | chore | 실제 레지스트리를 띄우는 CI 통합 잡 | T9, T11 |
| T13 | docs | README 명령·지원 범위와 환경 문서에 레지스트리 반영 | T9, T11 |
| T14 | docs | #216 명세의 서술을 OCI 백엔드 이후 사실로 고침 | T10, T11 |
| T15 | docs | 보호 문서에 OCI 레지스트리 백엔드 반영 | T12 |
| T16 | docs | README 지원 목록에 CNCF Distribution 행 추가 | T12, T13 |

- T1~T6 은 `src/harness/registry/` 의 공용 모듈을 바닥부터 쌓는다 — 참조(T1) → 전송(T2) → 인증(T3) → 엔드포인트(T4) 가 한 줄이고,
  아티팩트 쓰기(T5)는 네트워크 없이 T1 위에 선다. T6 이 받은 아티팩트 검사 · 풀기와 "참조 하나에서 받아 검사하고 푸는" 함수를 둬서
  T7 · T9 · T11 이 같은 함수를 쓴다
- 가짜 레지스트리(`src/test/fake_registry.py`)는 T2 가 바탕(저장 · 조회 · 주입 · 요청 기록)을 두고, T3 이 인증 모드를, T4 가 업로드 ·
  referrers 모드를 더한다. 각 task 는 자기가 시험하는 동작만큼 키운다. 스텁 헬퍼는 T3 이 둔다
- T5 는 "파일 목록과 annotation 으로 레이어 · manifest · 레이아웃을 만드는 부분" 과 "preset 리포 HEAD 에서 그 파일 목록을 읽는 부분" 을
  나눈다. `registry check --push` 의 확인용 아티팩트(T9)는 앞쪽만 쓴다
- 두 명령 모듈은 서로를 불러오지 못한다(#206 3-4). 그래서 올리기 순서(blob 있는지 보고 올리기 · manifest 올리기 · digest 대조)는 T4 의
  `client.py`, 받기 순서는 T6 의 `artifact.py` 에 두고 `preset` · `registry` 명령과 OCI 백엔드가 부른다
- T7 이 `render-test.sh` 의 새 블록과 그 준비(가짜 레지스트리 백그라운드 기동 · `HARNESS_HOME` · `DOCKER_CONFIG` 임시 위치 · 출력 모음과
  표지 검사)를 만든다. T8 · T9 · T10 · T11 은 같은 블록에 케이스를 더한다
- T10 은 #216 의 참조 판정과 lock 판정에 `oci://` 를 더하는 것만 하고 네트워크를 쓰지 않는다. 받기는 T11 이다. 두 task 모두 #216 이
  만든 `src/harness/preset/` 를 고친다. T10 이 T7 뒤인 것은 T7 이 만든 회귀 테스트 블록에 케이스를 더하기 때문이다
- T12 의 통합 테스트는 세 명령과 OCI 받기가 다 있어야 케이스(check · 왕복 · 받기 · referrers fallback 읽기)를 돌 수 있다
- T15 는 명세 12절의 보호 문서 개정 범위 하나만 고친다. testing 의 CI 통합 테스트 문장이 T12 의 파일을 가리키므로 T12 뒤다
- T16 은 리뷰 요청을 올린 뒤, 그 리뷰 요청에서 T12 의 통합 잡이 통과한 것을 확인하고 커밋한다 — 명세 9절은 지원 목록의 행을 그 잡이
  통과한 뒤에 더한다

## 착수 순서와 다른 이슈

- 착수 조건: #206 과 #216 의 구현이 `develop` 에 머지된 뒤 착수한다. #206 은 `src/harness/` 패키지 · 명령 표의 통과 명령 · Python 단위
  테스트 자리와 단계를, #216 은 preset 트리 멤버 판정 함수 · preset 트리 검증 · 내용 해시 · lock · 준비/반영 흐름과 스킴으로 백엔드를
  고르는 자리를 만든다(#216 은 #207 · #208 위에 놓인다)
- #217 은 선행이 아니다. 레이어에 드는 파일은 #216 의 받는 파일 표와 멤버 판정 함수가 정하므로, #217 이 그 표에 더한 `ci/` 두 행도 이
  이슈의 코드 변경 없이 레이어에 담긴다. #217 의 허용 출처 검사는 lock 의 `source` 를 보므로 T10 의 `oci://<레지스트리>/<저장소>` 를
  그대로 쓴다
- #219(Harbor)는 이 이슈의 `registry check --push` 와 지원 목록 형식(T13 · T16)을 쓴다. 이 이슈가 머지된 뒤 착수한다
- `render-test.sh` 의 새 블록 번호는 착수 시점의 최대 `UT-<번호>` 다음이다(지금 `develop` 은 UT-105). 같은 배치의 다른 이슈가 먼저
  블록을 더하면 그 다음 번호를 쓴다 — 번호 중복은 회귀 테스트가 막는다
- #216 · #217 · #219 · #206 의 구현과 같은 파일(`src/harness/commands/__init__.py` 의 명령 표, `src/harness/cli.py` 의 대상 해석 앞 목록,
  `src/harness/preset/`, `README.md`, `src/test/render-test.sh`, 보호 문서)을 건드린다. 동작은 서로 기대지 않는다. 먼저 머지된 쪽
  위로 `git fetch -p origin` 뒤 rebase 한다. rebase 뒤 push 는 사람이 한다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/218-oci-registry` — 요구사항 이슈 #218 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: preset 을 OCI 아티팩트로 레지스트리에 올리고 받음(#218)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #218` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #218`

## 전 task 공통 사항

- python3 표준 라이브러리만 쓴다. oras · docker CLI · 그 밖의 외부 클라이언트를 부르지 않는다
- `src/harness/registry/` 의 모듈은 `urllib`(`urllib.parse` 포함) · `http` 를 그것을 쓰는 함수 안에서 불러온다. 모듈 최상위에서
  불러오면 `script/project/check-cli.py imports` 가 막는다(#206 3-4)
- `src/harness/registry/` 는 `harness.config` · `harness.render` 를 불러오지 않는다. preset 트리 판정(#216 의 멤버 판정 함수 ·
  preset 트리 검증 · 내용 해시)은 `harness.preset` 의 공용 함수를 부른다. 모듈 최상위 import 로 이은 모듈 사이에 순환을 만들지 않는다
- `commands/preset.py` · `commands/registry.py` 는 서로와 `cli` 를 불러오지 않는다. 두 명령이 함께 쓰는 것은 `src/harness/registry/` 에 둔다
- 두 명령은 #206 3-3 의 통과 명령이다 — 명령 표 항목의 통과 표시 `True`, 설정이 필요 없음. 대상 해석 · 위임 앞에서 명령 모듈로 가고,
  `DELEGATES` 에 넣지 않는다. 공용 파서에 옵션을 더하지 않고, 하네스 루트(`--target`)를 쓰지 않는다
- 설정 키 · 생성 파일 · `plan()` 등록이 늘지 않는다. `.claude/settings.json` 의 허용 목록, doctor 의 `registry` 절, UI 는 바뀌지 않는다
- 네트워크는 `preset` · `registry` 명령과 `pull` · `install --preset` 의 OCI 받기만 쓴다. render · check · doctor · status 는 레지스트리에
  붙지 않는다
- 터미널 출력은 영어이고 명세의 원문 그대로다(ADR 0011). 새 출력에도 회귀 테스트의 한글 검사를 적용한다
- 자격증명 · 토큰 · `Authorization` 값 · 헬퍼 입출력 · URL 쿼리 · 레지스트리 오류의 `message` · `detail` · 응답 본문 · 받은 tar 의 멤버
  이름을 출력 · 지표 · 사용 기록 · 파일 어디에도 옮기지 않는다(명세 6-4 · 5-4 · 4-2). 레지스트리에서 온 문자열을 출력할 때는 제어
  문자를 `\x<16진 두 자리>` 로 이스케이프한다(명세 8 공통)
- 단위 테스트는 `src/test/unit/test_registry_*.py` 에 두고 #206 7-5 의 규칙대로 쓴다 — `[verify]` 의 "Python 단위 테스트" 단계가
  돈다. CLI 를 하위 프로세스로 띄우지 않고 패키지 함수를 부른다. 가짜 레지스트리는 import 해서 스레드로 띄운다
- 단위 테스트는 `src/test/fake_registry.py` 를 파일 경로로 불러온다. `src/test/` 는 패키지가 아니고 `test` 는 표준 라이브러리
  패키지 이름과 겹쳐 `import test.fake_registry` 가 표준 라이브러리 쪽을 찾는다
- 가짜 레지스트리는 `127.0.0.1` 의 빈 포트에만 바인드하고, `Authorization` 값을 기록하지 않는다. `render-test.sh` 는 백그라운드로 띄우고
  블록이 끝나면(실패 포함) 멈춘다
- 테스트의 등록부는 `HARNESS_HOME`, docker 설정은 `DOCKER_CONFIG` 로 임시 위치에 둔다. 사용자의 `~/.docker` 와 헬퍼를 읽지 않는다
- 명령 모듈의 이름 `registry` 와 등록부 함수 `registry()`(`home/registration.py`), 패키지 `harness.registry` 가 한 모듈에서 서로를 가리지
  않게 불러온다
- 주석과 테스트 이름에 이슈 번호 · 문서 번호 · 테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 케이스는 기존 `UT-<번호>` 블록 형식을 따른다
- 셸 shim 과 `script/` 아래 관리 스크립트는 만들지 않는다. 새 코드는 `src/harness/` 와 `src/test/` 에만 둔다
- 커밋 전 `script/run-lint-test.sh --commit` 이 통과한다

## 이번 이슈에서 정하지 않는 값

- OCI 백엔드 모듈의 파일 이름 — 명세는 #216 이 정한 preset 백엔드 자리(`src/harness/preset/`)만 정한다. #216 구현이 git 백엔드를 둔 꼴을 따른다
- HTTP 를 부르는 표준 라이브러리 수단(`urllib.request` 의 opener 나 `http.client`) — 명세는 연결 · 프록시 · 리다이렉트 · 상한의 동작만 정한다
- 가짜 레지스트리 · 스텁 헬퍼의 명령줄 옵션과 환경 변수 이름
- 레지스트리 문자열의 제어 문자 이스케이프 함수를 둘 모듈 — `src/harness/registry/` 안에 하나 둔다
- CI 통합 잡이 고정할 `registry:3` 이미지 digest 의 전체 값 — T12 가 구현할 때 확인해 고정하고, 확인한 경로를 리뷰 요청 본문에 적는다

## 이번 이슈에서 다루지 않는 것

- Harbor 의 실측과 지원 목록 행 — #219
- 서명 만들기 · 검증, referrers 올리기(`subject` 가 달린 manifest · 태그 규칙 index)
- identity token 자격증명, IPv6 주소 리터럴, 루프백 레지스트리의 HTTPS, docker 의 인증서 디렉터리
- 확인용 아티팩트 지우기, 레지스트리 관리 기능(저장소 생성 · 권한 · 불변 정책 · 복제)
- Docker Hub 를 기본값이나 대체 레지스트리로 쓰는 것
- UI · doctor · settings.json 의 변경
