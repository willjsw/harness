
`script/usage-log.sh` 가 남긴다. **명령 내용·문서 본문·사람 이름은 남지 않는다** — `script/usage-vocab.sh`
에 적힌 허용 라벨과 허용 키의 `키=값` 만 통과하고 나머지는 버려진다. 모르는 출처는 `other` 가 된다.
집계(`script/usage-report.sh`)도 같은 목록으로 입력을 다시 검증하므로, 다른 곳에서 만들어진
로그에 이름·명령이 섞여 있어도 보고서에 나오지 않는다(제외 건수만 `DROPPED` 로 표기).

| 종류 | 남기는 쪽 | 상세 |
|---|---|---|
| `block` | `githooks/commit-msg`·`pre-commit`·`pre-push` | 어느 가드가 무엇으로 막았는가 |
| `preflight` | `work-preflight.sh` | 판정 결과 (`plan`·`standalone`·`open-mr`·`spec-missing`·`fetch-failed`·`mr-query-failed`) |
| `review` | `review-mr.sh` | `mr=N round=N exit=N` — 어느 경로로 끝나든 남는다 |
| `command` | 커맨드 호출 경로 | 아직 어느 자산도 남기지 않는다 — 집계가 **미수집**으로 표기한다 |

