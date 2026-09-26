// `.ai/project/` 문서마다 사람이 채울 짧은 항목. AI Completion 이 이것과 리포를 근거로 문서 본문을 완성한다.
// intro 는 입력 칸 위에 보이는 안내 — 이 탭에서 무엇을 적는지 알린다.
//
//   [키, 질문, 예시, { why, list, none, unknown, advanced }]
//   why       에이전트가 이 답으로 하는 일 — 무엇을 적을지 정하게 돕는다
//   list      여러 줄로 받는다
//   none      "없음" 을 한 번에 넣는 버튼
//   unknown   "모름" 을 받는다 — AI 가 리포에서 확인해 채우고, 못 하면 TBD 로 남긴다
//   advanced  고급 항목. 비워도 되고, 비우면 "모름" 과 같다
//   noValues  값(KEY=값)을 받지 않는다 — 시크릿이 문서에 들어가지 않게
//   severity  줄마다 심각도를 고른다. 줄은 "점검 — 심각도" 로 저장된다
// 리뷰 점검 한 줄의 심각도. code-reviewer 계약의 등급과 같다.
export const SEVERITY = ["blocker", "major", "minor"];

export const DOCS = {
  // 사람만 아는 것. 이것만 채워도 무엇을 누구를 위해 만드는지 보여야 한다.
  scope: {
    title: "개요",
    intro: "이 프로젝트가 무엇을, 누구를 위해 만드는지 정합니다. 모든 AI 에이전트가 작업을 시작하기 전에 이 내용을 읽습니다.",
    fields: [
      ["what", "한 문장으로, 무엇을 만드나요?", "예: 사내 결재 문서를 올리고 승인받는 서비스",
        { why: "모든 에이전트가 작업 전에 읽는 첫 문장입니다." }],
      ["users", "누가 쓰나요?", "예: 사내 임직원, 결재권자",
        { why: "기능과 화면을 누구 기준으로 판단할지 정합니다." }],
      ["features", "사용자가 할 수 있는 일", "예: 결재 요청",
        { list: true, why: "여기 없는 기능을 요구하면 요구사항 검토가 이 리포 소관인지부터 묻습니다." }],
      ["notHere", "여기서 만들지 않는 것", "예: 로그인·권한은 auth 서비스 담당",
        { none: true, why: "리뷰어는 여기 적힌 것을 이 리포에서 구현하면 blocker 로 잡습니다." }],
      ["neighbors", "함께 도는 다른 서비스와 그 역할", "예: auth — 로그인·권한",
        { list: true, none: true, why: "그 서비스의 책임을 이 리포에 다시 만들지 않게 합니다." }],
    ],
  },
  // 설명 칸 대신 시스템의 모양을 묻는다. 리포에서 읽을 수 있는 것은 "모름" 으로 두면 AI 가 채운다.
  architecture: {
    title: "구조",
    intro: "시스템이 어떤 덩어리로 이뤄지고 데이터가 어떻게 흐르는지 정리합니다. 에이전트는 이 구조를 보고 새 코드를 둘 곳을 정합니다.",
    fields: [
      ["parts", "무엇으로 이뤄져 있나요?", "예: 화면 — Next.js",
        { list: true, unknown: true, why: "화면·서버·DB·외부 서비스 같은 덩어리입니다." }],
      ["flow", "데이터는 어떻게 흐르나요?", "예: 사용자 → 화면 → API → DB",
        { unknown: true, why: "변경이 어디까지 번지는지 판단하는 기준입니다." }],
      ["inputs", "밖에서 들어오는 입력", "예: 웹 요청, 업로드 파일, 웹훅",
        { list: true, unknown: true, why: "보안 점검이 검증 없이 들어오는 값을 찾는 기준(신뢰 경계)입니다." }],
      ["sensitive", "다루는 민감 정보", "예: 결재 금액, 사번",
        { none: true, unknown: true, why: "로그·응답·커밋에 새면 안 되는 값입니다. 값이 아니라 종류만 적습니다." }],
      ["placement", "새 코드를 둘 곳", "예: 외부 API 호출 → client/",
        { list: true, unknown: true, why: "새 구조를 만들기 전에 기존 자리를 쓰게 합니다. 리뷰어가 과설계를 잡는 근거입니다." }],
      ["layers", "계층과 의존 방향", "예: api → service → repo, 역방향 금지",
        { advanced: true, why: "누가 누구를 import 할 수 있는지입니다." }],
      ["unchecked", "검사하지 않는 기존 패턴", "예: 없음",
        { advanced: true, none: true, why: "바람직하지 않지만 이미 있는 패턴입니다. 규칙으로 올리려면 먼저 걷어냅니다." }],
    ],
  },
  // 리포에서 읽을 수 있는 것. 모르면 "모름" 으로 두고 AI 가 찾게 한다.
  // 명령 탭은 문서가 아니라 harness.toml 의 [commands]·[verify] 를 쓴다(CommandsEditor). 키는 CLI 의 COMMAND_KEYS 와 같다.
  commands: {
    title: "명령",
    intro: "빌드·테스트·코드 검사 명령을 정합니다. 에이전트는 구현이 끝났는지 이 명령으로 확인하고, 코드 검사와 테스트는 커밋 뒤와 CI 에서 자동으로 돕니다.",
    fields: [
      ["test", "전체 테스트 명령", "예: npm test",
        { verify: true, why: "구현과 리뷰가 끝났는지 이 명령의 결과로 판정합니다." }],
      ["format_check", "코드 모양 검사", "예: npm run lint",
        { verify: true, why: "코드를 고치지 않고 검사만 합니다. 커밋 뒤에 테스트보다 먼저 돕니다." }],
      ["format_fix", "코드 모양 자동 수정", "예: npm run lint:fix",
        { why: "에이전트가 코드 검사에서 걸린 것을 고칠 때 씁니다." }],
      ["build", "빌드 명령", "예: npm run build",
        { why: "구현 뒤 빌드가 되는지 확인할 때 씁니다." }],
      ["test_single", "테스트 하나만 돌리는 명령", "예: npm test -- {file}",
        { advanced: true, why: "고친 부분만 빠르게 확인할 때 씁니다. 파일 자리는 {file} 로 적습니다." }],
    ],
  },
  stack: {
    title: "스택",
    intro: "프로젝트를 만드는 언어·런타임·프레임워크를 정리합니다. 에이전트는 여기에 맞는 관례로 코드를 씁니다.",
    fields: [
      ["stack", "무엇으로 만드나요?", "예: TypeScript, Node 22, Next.js",
        { unknown: true, why: "언어·런타임·프레임워크입니다. 에이전트가 따를 관례를 정합니다." }],
      ["manifest", "의존성 목록 파일", "예: package.json",
        { unknown: true, why: "정확한 버전은 이 파일에서 읽습니다. 버전을 문서에 옮겨 적지 않습니다." }],
      ["planned", "도입 예정이지만 아직 없는 것", "예: Redis 캐시 — 설계만 있음",
        { advanced: true, none: true, why: "파일만 봐서는 모르는 차이입니다. 에이전트가 없는 것을 있다고 가정하지 않게 합니다." }],
    ],
  },
  testing: {
    title: "테스트",
    intro: "무엇을 어떤 수준으로 테스트할지 정합니다. 에이전트가 쓰는 테스트의 범위와 방식이 이 기준을 따릅니다.",
    fields: [
      ["levels", "무엇을 어떤 테스트로 확인하나요?", "예: 계산 로직은 단위, API 는 통합",
        { unknown: true, why: "개발 에이전트가 테스트를 어느 수준으로 쓸지 정합니다. 비면 사람마다 달라집니다." }],
      ["external", "테스트에서 DB·외부 API 는 어떻게 하나요?", "예: DB 는 testcontainers, 외부 API 는 목",
        { unknown: true, why: "테스트가 실제 서비스에 붙어도 되는지, 무엇으로 대신하는지 정합니다." }],
      ["never", "하지 않는 테스트", "예: 실제 시각·sleep 에 의존하는 테스트",
        { list: true, none: true, advanced: true, why: "리뷰어가 이런 테스트를 지적합니다." }],
    ],
  },
  environment: {
    title: "환경",
    intro: "개발에 필요한 도구, 환경 변수, 외부 시스템 접근 방법을 정리합니다. 값은 적지 않고 얻는 곳만 적습니다.",
    fields: [
      ["tools", "개발에 필요한 프로그램", "예: node 22",
        { list: true, unknown: true, why: "없으면 에이전트가 무엇을 설치해야 하는지 알리고 멈춥니다." }],
      ["env", "환경 변수 이름과 얻는 곳", "예: DATABASE_URL — 1Password 개발 볼트",
        { list: true, none: true, unknown: true, noValues: true,
          why: "값은 적지 않습니다. 이름과 어디서 얻는지만 적습니다 — 시크릿은 리포에 남기지 않습니다." }],
      ["external", "접속하는 외부 시스템과 권한 받는 법", "예: 스테이징 DB — 인프라팀에 요청",
        { list: true, none: true, why: "보안 점검이 자격증명을 올바른 경로로 얻는지 판정하는 근거입니다." }],
    ],
  },
  glossary: {
    title: "용어",
    intro: "프로젝트 전반에서 AI 에이전트가 표준으로 사용할 용어 사전을 만듭니다.",
    fields: [
      ["terms", "이 프로젝트의 용어와 뜻", "예: 결재선 — 승인자 순서 목록",
        { list: true, none: true, why: "명세·코드·리뷰가 같은 것을 같은 이름으로 부르게 합니다." }],
      ["aliases", "더 이상 쓰지 않는 옛 이름", "예: 품의서 → 결재 문서",
        { list: true, none: true, advanced: true, why: "옛 문서에만 남은 표기입니다. 새 산출물에는 정식 이름만 씁니다." }],
    ],
  },
  "review-checks": {
    title: "리뷰 점검",
    intro: "이 리포에서만 지켜야 하는 리뷰 점검 항목을 정합니다. 리뷰 에이전트가 변경마다 이 목록을 확인합니다.",
    fields: [
      ["checks", "이 리포에서만 지켜야 하는 점검", "예: 금액은 BigDecimal 만 쓴다",
        { list: true, none: true, severity: SEVERITY,
          why: "리뷰어가 마지막 장에서 확인합니다. 일반론은 적지 않습니다. blocker 는 머지를 막습니다." }],
    ],
  },
};

// 항목을 객체로 편다. 옵션을 적지 않은 문서도 같은 모양으로 읽는다.
export const fieldsOf = (doc) => DOCS[doc].fields.map(([k, label, hint, o = {}]) => ({ k, label, hint, ...o }));

export const NONE = "없음";
export const UNKNOWN = "모름";
