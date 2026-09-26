# 8. Agent CLIs are declared in a vendor registry

Date: 2026-09-25

## Status

Accepted

## Context

오케스트레이터와 역할 러너로 고를 수 있는 에이전트 CLI 가 검증 코드의 문자열로 흩어져 있었고,
`bin/harness` 가 벤더 이름으로 분기했다. 리뷰 스크립트에는 codex 전용 인자가 claude 리뷰어에도 붙었다.
모델 이름을 코드에 적으면 CLI 가 올라갈 때마다 낡는다.

검토한 대안.

- 벤더별 분기를 코드에 유지. 새 벤더마다 검증·감지·실행·UI 선택지를 따로 고쳐야 한다
- 실행 명령을 프로젝트의 `harness.toml` 에 둔다. 실행되는 값이라 프로젝트가 잘못 적으면 하네스가 깨진다

## Decision

우리는 에이전트 CLI 를 `templates/vendors.toml` 에 선언하기로 한다 — 띄우는 명령(launch·headless),
권한 인자, 결과 받는 법, 사용량 형식, 어댑터 형식, 모델 리더. 역할이 무엇을 요구하는지는 역할 선언의
frontmatter(`distinct_from`·`headless`)가 갖는다. 둘에서 역할별 실행 계획 `script/harness.plan.json`
을 생성하고, 공용 실행기 `script/run-agent.py` 가 그 계획대로 띄운다. 모델 목록은 CLI 자신의 기록에서
읽고 코드에 적지 않는다.

## Consequences

- 새 벤더는 등록부 한 항목이다. 명령을 확인하기 전까지는 감지만 한다
- 프로젝트 설정은 벤더 id 만 고르고 명령을 담지 못한다
- 러너·오케스트레이터를 바꾸면 모델이 그 주체의 것인지 다시 판정한다(`model_ok`). doctor 가 경고한다
- 실행 계획은 생성물이라 `check` 대상이다
