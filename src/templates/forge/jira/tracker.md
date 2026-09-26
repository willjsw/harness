## 이슈 명령

| 하는 일 | 명령 |
|---|---|
| 이슈 조회 | `jira issue view <키>` |
| 이슈 생성 | `jira issue create` |
| 이슈에 댓글 | `jira issue comment add <키> "<본문>"` |
| 현재 사용자명 | `jira me` |

이슈 식별자는 번호가 아니라 **키**(`{{COMMIT_TICKET_KEY}}-12`)다. 문서와 커밋 제목에 그 키를 그대로 적는다.

**인증과 프로젝트 지정은 `jira init` 이 만든 설정이 갖는다.** 리포에 토큰을 적지 않는다 —
`.ai/project/environment.md` 에는 항목명과 취득 경로만 둔다.

만들 이슈의 유형은 `{{ISSUE_TYPE}}` 이다 (`harness.toml` 의 `issues.type`).
프로젝트의 유형 이름이 다르면 그 값을 바꾼다 — 유형이 없으면 생성이 거부된다.

이슈 본문 양식은 `.ai/templates/issue-requirement.md`(요구사항)·`.ai/templates/issue-task.md`(task).
