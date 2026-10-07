# #60 분해 — `/work` 착수 전제의 자동화와 착수 전 검증

명세: [`docs/spec/60-automate-work-prerequisites.md`](../../spec/60-automate-work-prerequisites.md)

## 분해 개요

| task | 태그 | 요약 | 선행 |
|---|---|---|---|
| T1 | feat | 훅 설정 함수와 install 의 core.hooksPath 설정 | 없음 |
| T2 | fix | doctor · uninstall · UI Doctor 가 서브프로젝트의 훅 기대 값으로 판정 | T1 |
| T3 | feat | render 가 forge 별 이슈·리뷰 요청 템플릿을 생성 파일로 생성 | T1, #58 |
| T4 | fix | GitHub 어댑터의 라벨 생성 실패를 호출부로 전달 | 없음 |
| T5 | feat | 어댑터 계약에 라벨 준비 함수 tracker_labels_ensure 추가 | T4 |
| T6 | feat | harness forge-setup 명령과 forge-setup.sh 로 원격 이슈 라벨 준비 | T5 |
| T7 | feat | work-preflight 가 이슈를 조회해 닫힌 이슈와 조회 실패에 착수하지 않음 | 없음 |
| T8 | feat | review-mr 가 회차 라벨 전에 리뷰 러너의 설치와 인증을 점검 | #59 |
| T9 | docs | README · 스크립트 안내 · 훅 활성화 문구에 자동 설정과 forge-setup 반영 | T1, T2, T3, T6 |
| T10 | docs | 아키텍처·담당 범위 문서에 템플릿 생성 · 착수 전 검증 · forge-setup 반영 | T3, T6, T7, T8 |

- T1 이 `src/bin/harness` 에 훅 기대 값 계산·켜짐 판정 함수와 설정 함수를 만들고 `cmd_install` 이 설정 함수를 부른다.
  `render-test.sh` 의 새 `UT-75` 블록을 만든다
- T2 는 T1 의 판정 함수로 `cmd_doctor` · `cmd_uninstall` 의 `"script/githooks"` 직접 비교를 없애고, `UT-75` 블록에 doctor · uninstall
  케이스를 더하며, `src/ui/lib/doctor.js` 가 detail 의 명령을 쓰게 한다
- T3 은 T1 의 "리포 안의 위치" 계산으로 모노레포 서브프로젝트를 가른다. 이 리포의 손으로 둔 `.github/` 템플릿을 넘겨받는 데
  #58 이 만드는 `--adopt` 를 쓴다
- T4 → T5 → T6 은 어댑터의 실패 전달 → 계약 함수 → 그 함수를 부르는 명령 순이다. 역순으로 만들면 forge-setup 이 실패를 삼키는
  라벨 생성 위에 선다
- T7 · T8 은 서로 기대지 않고 T1~T6 과도 기대지 않는다
- T9 · T10 은 앞 task 가 만든 동작을 문서에 적는다. 둘은 서로 기대지 않는다

## 다른 이슈와의 순서

- **#59 가 먼저 머지된다.** T8 이 부르는 `script/run-agent.py <역할> --check` 와 벤더 선언의 `auth_check` 를 #59 가 만든다.
  #59 가 머지되기 전에는 T8 에 착수하지 않는다
- **#58 의 `--adopt` 를 T3 이 쓴다.** #58 이 먼저 머지되거나, 함께 진행하면 T3 착수 전에 #58 머지분 위로 rebase 한다
- **#60 이 #62 보다 먼저 머지된다.** #62 는 UI 의 훅 조치를 CLI 로 옮기면서 T1 의 설정 함수를 부른다
- 선행 리뷰 요청이 머지되면 `git fetch -p origin` 뒤 `develop` 위로 rebase 한다. rebase 뒤 push 는 사람이 한다

## 브랜치·리뷰 요청·커밋

- 브랜치: `feat/60-automate-work-prerequisites` — 요구사항 이슈 #60 하나가 브랜치 하나·리뷰 요청 하나다
- 리뷰 요청 제목: `feat: 설치 뒤 /work 착수 전제 자동화와 착수 전 검증(#60)`
- 리뷰 요청 대상: `develop`. 관련 이슈 절에 `Closes #60` 과 task 이슈마다 `Closes #<task>` 한 줄씩
- 커밋: task 하나당 커밋 하나. 제목은 `<task 태그>: <요약>(#<task 이슈번호>)`, 본문 마지막 줄은 `relates to #60`

## 전 task 공통 사항

- CLI 는 표준 라이브러리만 쓴다. 관리 스크립트는 forge 를 `script/forge.sh` 의 어댑터 함수로만 부른다
- 관리 스크립트의 정본은 `src/templates/managed/script/` 다. 고친 뒤 이 리포의 `script/` 사본은 `harness render`(소스 리포 설치)로 맞춘다
- 생성 파일(`.ai/AI_AGENT.md` · `script/githooks/*` · `.github/` 템플릿 등)은 직접 고치지 않고 템플릿이나 `plan()` 을 고친 뒤 render 한다
- 새 관리 스크립트와 새 `test-*.sh` 는 `src/templates/managed/script/README.md` 표에 한 줄 더하고, 테스트는
  `src/templates/managed/script/run-lint-test.sh` 의 실행 목록에도 넣는다
- 터미널 출력 문구는 명세의 영어 원문 그대로 둔다. 새 블록과 새 스크립트의 출력에도 한글 검사를 적용한다
- 주석과 테스트 이름에 이슈 번호·문서 번호·테스트 항목 ID 를 넣지 않는다. `render-test.sh` 의 새 블록은 기존 `UT-<번호>` 형식을 따른다.
  rebase 뒤 `UT-75` · `UT-76` 이 이미 쓰였으면 비어 있는 다음 번호를 쓴다 — 번호 중복은 회귀 테스트가 막는다
- GitLab 어댑터에 더하는 경로는 실제 GitLab 으로 확인하지 않았다는 표기를 함수 머리 주석에 둔다
- 커밋 전 `script/run-lint-test.sh` 가 통과한다

## 이번 이슈에서 다루지 않는 것

- doctor 의 원격 준비 점검(라벨 존재 확인 등) — #59
- UI Doctor 의 훅 조치(▷ 실행)를 CLI 호출로 옮기는 것 — #62
- 라벨의 색·설명 맞추기, 회차 라벨(`<round_label>:<N>`) 미리 만들기
- 모노레포에서 리포 루트의 forge 템플릿 생성
- 이미 설치된 리포를 새로 클론한 사람의 훅 자동 설정 — doctor 가 명령을 알려 준다
