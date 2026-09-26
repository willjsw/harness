# 6. Forge access goes through an adapter contract

Date: 2026-09-23

## Status

Accepted

## Context

이슈 추적과 코드 리뷰 호스트는 GitHub·GitLab·Jira 로 갈리고, 명령·페이지네이션·응답 형태·상태 이름이
다르다. 배관 스크립트가 `gh`·`glab` 을 직접 부르면 forge 를 바꿀 때 스크립트 전부를 고쳐야 하고, Jira 처럼
코드 리뷰를 호스팅하지 않는 forge 를 고르면 없는 기능으로 루프가 돈다.

검토한 대안.

- 스크립트마다 forge 별 분기. 같은 분기가 스크립트 수만큼 복제된다
- forge 하나만 지원. 첫 사용자가 GitLab 이었다

## Decision

우리는 forge 접근을 `script/forge.sh` 의 어댑터 함수(tracker 군·review 군)로만 하기로 한다. 호출부는
forge 를 모르고 정규화된 JSON 을 받는다. 트래커와 리뷰 호스트는 따로 고르되, 리뷰 호스트로 Jira 는
설정 검증이 거부한다. 어댑터가 계약을 지키는지는 실제 forge 를 상대로 한 자체 검사
(`script/forge-selftest.sh`)로 확인하고, 통과하기 전까지 어댑터 머리글에 미검증 표기를 둔다.

## Consequences

- 새 forge 는 어댑터 하나와 명령 사전 조각(`templates/forge/<kind>/`)을 더하면 된다
- 회귀 테스트는 페이크 어댑터를 쓰므로 실제 어댑터를 한 줄도 타지 않는다. 계약 준수는 자체 검사가
  본다 — 그리고 자체 검사 자신은 위반을 주입한 페이크로 검사한다
- 되돌릴 수 없는 동작(이슈 생성)은 자체 검사에서도 따로 켠다
- 인증은 각 CLI 가 갖고 리포에 두지 않는다
