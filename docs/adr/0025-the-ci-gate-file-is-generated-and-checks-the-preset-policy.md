<!--
작성 규칙
- 절 이름(`## Status` 등)은 영어로 고정한다 — 도구가 문자열로 찾아 상태·링크를 조작한다.
- 본문은 프로젝트 문서 언어로 쓴다. 제목·파일명은 영어.
- **`## Status` 절에는 상태 문자열과 도구가 넣는 링크만 둔다.** 주석이나 설명을 넣으면
  대체 링크가 그 뒤로 밀려 상태를 읽기 어려워진다.
-->

# 25. The CI gate file is generated and checks the preset policy

Date: 2026-10-10

## Status

Proposed

## Context

하네스의 머지 전 검증 파일(GitHub `.github/workflows/harness-verify.yml`, GitLab `.gitlab-ci.yml`)은 첫 설치 때만 깔리는
소유 파일이다(0002 Consequences 마지막 항목). 그래서 조직 preset(#216)이 게이트를 고칠 길이 없고, 설치본마다 손으로 고친
게이트가 남는다. 로컬 층(훅 · 가드)은 설치하지 않거나 설정을 지우면 우회된다. 조직 공용화 로드맵은 "조직 차원의 동일성은
머지 게이트(CI required check)로 보장한다", "새 서버는 만들지 않는다" 를 이미 정했다.

얽히는 사실.

- 위협 모델은 0015 의 것이다 — 대상 리포에 쓰기 권한이 있는 쪽은 고정 사본을 직접 고칠 수 있고, 하네스는 그것을 막지 않고
  감지한다. 생성된 게이트, 그것이 부르는 고정 사본, preset 사본(vendoring)과 lock 은 모두 같은 리포 안에 있다
- 최소 버전을 lock 체인 안의 값으로 정하면 오래된 lock 은 자기 최소값으로 검사를 통과한다
- 커밋마다 도는 `check --staged` 에는 네트워크를 넣지 않는다. 원격 점검은 명시 플래그(`doctor --remote`)로만 한다
- 지금 게이트는 프로젝트가 런타임 준비 단계를 직접 더해 쓰라고 안내한다. required status check 가 가리키는 체크 이름은
  조직 ruleset 이 참조하는 외부 계약이다
- GitLab 은 리포 루트 `.gitlab-ci.yml` 하나를 파이프라인으로 읽는다. 그 파일을 넘겨받으면 프로젝트 파이프라인 전체가 밀려난다
- 명세는 `docs/spec/217-org-ci-gate.md` 1~5 · 7 · 14절

검토한 대안.

- 보장 범위 — 고의 우회까지 막는다. 정책 검사를 리포 밖에서 고정한 코드(조직 중앙 리포의 워크플로나 고정 릴리스의 하네스)로 돌리고
  ruleset 의 워크플로 강제 기능으로 묶는다. 그 forge 기능의 존재와 플랜 조건이 확인되지 않았고, 0015 의 "막지 않고 감지한다" 를
  뒤집는 새 결정과 중앙 리포 운영이 필요하다. 실수로 생긴 어긋남으로 범위를 정하고 preset 템플릿 안에서 조직이 고의 우회 대책을
  고를 수 있게 두는 안은, 템플릿이 무엇이든 공급할 수 있으므로 하네스가 따로 정할 것이 없다
- 정책 기준값 — 허용 출처와 최소 버전을 모두 preset 체인의 잠긴 키로 두고 늘 오프라인으로 검사한다. 최소 버전이 lock 안의 값이라
  오래된 preset 을 잡지 못한다
- 정책 기준값 — CI 가 preset 원격에서 최신 태그를 조회해 판정한다. CI 에 네트워크와 인증(robot 계정)이 들어가 레지스트리 이슈(#218 · #219)와
  결합하고, `check` 에 원격 경로가 생긴다
- 게이트 본문 공급 — preset 이 템플릿 파일만 공급한다. 스택 preset 에 없는 프로젝트별 준비 단계는 둘 자리가 없어, 지금 게이트를 고쳐 쓴
  프로젝트가 넘겨받은 뒤 그 단계를 잃는다
- 게이트 본문 공급 — 내장 템플릿 하나에 설정 키(런타임 · 이미지 · 체크 이름)로만 매개변수를 준다. 스택마다 다른 런타임 준비를 키로 다
  표현하려면 YAML 조각을 TOML 에 옮기게 되고, preset 이 스택별이라는 로드맵 결정과 맞지 않는다
- 기록 — 0002 를 대체한다. 0002 의 Decision(세 부류, 부류가 곧 갱신 경계)은 바뀌지 않고 Consequences 의 한 항목만 바뀌므로
  `.ai/adr.md` 의 대체 규칙에 맞지 않는다(0017 이 0015 를 대체하지 않은 선례). 기록을 남기지 않는다 — 대상 리포에서 보이는 동작
  (render 가 CI 파일을 관리하고, 기존 설치본 갱신이 한 번 멈추고, uninstall 이 지운다)과 외부 계약(CI 변수 이름 · preset 경로 ·
  정책 키)이 바뀌고 대안이 여럿이다

## Decision

우리는 하네스 CI 게이트 파일을 생성 파일로 두고, `harness check` 가 lock 체인에 대해 preset 정책을 검사하게 한다.

- 게이트는 리뷰 호스트별 경로(`.github/workflows/harness-verify.yml` · `.gitlab/harness-verify.yml`) 한 파일이다. 하네스 루트가 리포
  루트이거나 git 작업 트리 밖일 때만 생성한다. 프로젝트의 다른 CI 파일은 소유 파일로 남는다
- 게이트 본문은 lock 체인에서 가장 가까운 preset 의 `ci/<host>/harness-verify.yml` 템플릿, 없으면 내장 템플릿에서 나온다. 프로젝트는
  `[ci].setup` 으로 준비 단계만 더한다. 템플릿이 쓸 수 있는 변수는 넷이고, 검증 진입점은 하네스가 `{{CI_VERIFY}}` 로만 정한다
- 허용 출처(`policy.preset_sources`)는 설정 값이고, `check` 가 늘(`--staged` 포함) 오프라인으로 본다. 조직 preset 이 `locked` 로 잠근다
- preset 최소 버전은 리포 밖의 조직·그룹 CI 변수 `HARNESS_MIN_PRESET_VERSION` 으로 받고, `policy.check_min_preset_version` 이 참일 때
  게이트가 `check --min-preset-version` 으로 넘길 때만 본다. 값이 비어 있으면 실패한다
- 게이트가 보장하는 범위는 실수로 생긴 어긋남이다. 여러 리포에 걸친 강제는 조직 ruleset 의 required status check 가 맡는다

리포 밖 고정 코드로 고의 우회까지 막지 않는 것은 그 forge 기능이 확인되지 않았고 0015 의 감지 결정을 유지하기 위해서이고,
최소 버전을 lock 밖의 CI 변수로 받는 것은 lock 안의 값으로는 오래된 preset 을 잡지 못하기 때문이다.

## Consequences

- 0002 를 대체하지 않는다. 세 부류와 갱신 경계는 그대로다. 0002 Consequences 마지막 항목("CI 설정은 첫 설치 때만 깔리는 소유
  파일이다")은 이 결정 뒤로 GitLab 의 리포 루트 `.gitlab-ci.yml` 과 모노레포 서브프로젝트의 CI 골격에만 해당한다. CI 게이트는 생성 파일이다
- 0015 를 대체하지 않는다. 게이트는 리포 안의 고정 사본 · preset 사본 · lock 으로 돈다. 쓰기 권한이 있는 사람이 그것들과 게이트를 함께
  고친 변경은 게이트가 알아채지 못하고, 리뷰 요청의 사람 리뷰가 받는다
- 게이트 경로도 0017 의 경로 규칙과 사전 판정을 받는다
- 외부 계약이 생긴다 — CI 변수 이름 `HARNESS_MIN_PRESET_VERSION` 과 그 값 형식, 정책 키 `policy.preset_sources` · `policy.check_min_preset_version`,
  preset 저장소의 `ci/github/harness-verify.yml` · `ci/gitlab/harness-verify.yml`, 템플릿 변수 넷, 조직 ruleset 이 가리키는 체크 이름
  (github `verify`, gitlab `harness-verify`). 바꾸면 조직마다 변수 · preset · ruleset 을 다시 맞춰야 한다
- 이미 깔린 GitHub 게이트는 매니페스트에 없어서, 이 결정이 든 하네스로 갱신하는 render · install 이 한 번 멈추고 `--adopt` 를 요구한다.
  넘겨받은 뒤 프로젝트가 더했던 단계는 `.orig` 에서 `[ci].setup` 으로 사람이 옮긴다
- GitLab 의 게이트는 `.gitlab/harness-verify.yml` 이고, 소유 파일인 루트 `.gitlab-ci.yml` 이 그것을 include 한다. 기존 루트 파일에 include
  줄을 더하는 것은 사람이 한다. GitLab 게이트는 실제 GitLab 으로 검증하지 않았다
- 모노레포 서브프로젝트에는 게이트가 없어 조직 강제 대상에서 빠진다
- 게이트를 끄는 설정이 없다. 다른 CI 를 쓰는 프로젝트에도 리뷰 호스트의 게이트 파일이 생긴다
- 최소 버전은 `v` 를 뗀 세 정수 버전만 비교한다. 최소 버전이 걸린 preset 의 태그가 그 형식이 아니면 위반이다
- 하네스는 게이트가 forge 에서 required check 로 지정됐는지, CI 변수가 설정됐는지 알지 못한다. 운영 안내(`docs/workflow/ci-gate.md`)가
  사람이 할 일을 적는다
- CI 에서 리뷰어 에이전트를 부르는 것과 리뷰 판정(PASS 댓글)을 머지 조건으로 확인하는 것은 이 결정의 범위 밖이다
