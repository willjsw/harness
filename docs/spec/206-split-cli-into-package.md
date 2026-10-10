# CLI 패키지와 고정 사본의 패키지 설치

하네스 CLI 는 진입 스크립트 하나와 Python 표준 라이브러리 패키지 `harness` 로 이루어진다. 진입 스크립트
(`bin/harness`)는 바이트코드 위치와 패키지 경로를 정하고 `harness.cli.main()` 을 부르기만 한다. 명령은 명령마다
모듈 하나(`commands/<명령>.py`)에 있고, 여러 명령이 쓰는 코드는 공용 모듈에 있다. 대상 리포의 고정 사본은
패키지를 `.harness/lib/harness/` 에 갖는다. 바이트코드는 리포 밖 등록부 아래 `.cache/pycache/` 에 쌓인다.
명령의 동작은 바뀌지 않는다.

모듈 지도는 #96(`docs/spec/96-machine-local-state-key.md`)의 변경이 들어간 통합 브랜치를 기준으로 한다 — 클론 키
모듈 불러오기, 클론 키 등록부, 옛 이름 디렉터리 옮기기, `harness projects` 가 지도에 든다.

정본 위치:

| 대상 | 정본 |
|---|---|
| 진입 스크립트 | `src/bin/harness` |
| CLI 패키지 | `src/harness/` |
| 이 리포의 검증 설정 | `harness.toml` 의 `[verify]` |
| 컴파일 · 의존 방향 검사 | `script/project/check-cli.py` |
| 회귀 테스트 | `src/test/render-test.sh` · `src/test/cli_loader.py` · `src/ui/lib/doctor.test.js` |
| CLI 패키지의 Python 단위 테스트 | `src/test/unit/` (7-5) |
| 사람용 설명 | `README.md` |
| Homebrew 포뮬러 | 탭 리포 `willjsw/homebrew-harness` 의 `Formula/harness.rb` — 이 리포 밖이다 (11절) |

## 1. 동작이 바뀌는 것과 바뀌지 않는 것

바뀌지 않는 것:

- 모든 명령의 인자 · 표준 출력 · 표준 오류 · 종료 코드 · 대상 리포에 쓰는 파일. 고정 사본의 구성(4절)만 다르다
- 같은 설정과 프로젝트 사실에서 같은 생성 파일이 나온다
- 실행 경로 셋 — `src/bin/harness` · `.harness/bin/harness` · Homebrew 의 `bin/harness`. 그래서 git 훅 · 검증 일괄 ·
  CI · 권한 규칙(`write-doc` 차단의 세 호출 형태) · UI 의 `HARNESS_BIN` 이 그대로다
- 실행 위치에서 구하는 값 — 템플릿 위치 · 기본 설정 · `harness version` 의 버전 계산 · UI 위치 (2-3)
- CLI 는 소스 그대로 `python3`(3.11 이상)로 돈다. 빌드 · 네이티브 컴파일 단계가 없고 표준 라이브러리만 쓴다
- 관리 스크립트(`src/templates/managed/script/`, `_clone_key.py` 포함)는 이 명세가 옮기지 않는다

바뀌는 것:

- 소스 트리 — `src/harness/` 가 생기고 `src/bin/harness` 는 진입 스크립트가 된다. `src/bin/harness_metrics.py` 는 없어진다
- 고정 사본 — `.harness/lib/harness/` 가 생기고 `.harness/bin/` 에는 `harness` 하나만 남는다. `.harness/managed` 의 고정
  사본 줄이 따라 바뀐다 (4절)
- 전역 CLI 의 고정 사본 대조에서 비교하는 짝 (4-4)
- 바이트코드가 등록부 아래 `.cache/pycache/` 에 쌓인다. 리포에는 `__pycache__` 가 생기지 않는다 (5절)
- 진입 스크립트가 패키지를 찾지 못하면 `error:` 를 내고 멈춘다 (2-2)
- 명령 표에 통과 표시가 생긴다. 통과 명령은 이름 뒤의 인자를 공용 파서에 넘기지 않고 그대로 받는다 (3-3). 이 명세의
  명령은 모두 통과 명령이 아니어서 인자 해석이 그대로다
- 이 리포의 `[verify]` 단계 (6절)와 CLI 패키지의 Python 단위 테스트 자리 `src/test/unit/` (7-5)

## 2. 배치

### 2-1. 세 배치

| 배치 | 진입 스크립트 | 패키지 | 템플릿 | `ROOT` |
|---|---|---|---|---|
| 소스 리포 | `src/bin/harness` | `src/harness/` | `src/templates/` | `src/` |
| Homebrew | `libexec/bin/harness` (`bin/harness` 는 그 링크) | `libexec/harness/` | `libexec/templates/` | `libexec/` |
| 고정 사본 | `.harness/bin/harness` | `.harness/lib/harness/` | `.harness/templates/` | `.harness/` |

UI 는 `ROOT/ui` 다. 소스 리포와 Homebrew 에만 있고 고정 사본에는 없다 — 지금과 같다.

### 2-2. 진입 스크립트

`bin/harness` 는 이 순서로만 한다.

1. `tomllib` 를 불러온다. 없으면 표준 오류에 `python3 3.11 이상이 필요하다 (tomllib 없음). 현재: <버전>` 을 내고
   1 로 끝난다 — 지금과 같은 문구와 종료 코드다
2. 바이트코드 위치를 정한다 (5-1)
3. 패키지 경로를 정한다. 진입 스크립트의 실제 경로(`Path(__file__).resolve()`)에서 `<base>` 는 `bin/` 의 부모다
   - `<base>/lib/harness/__init__.py` 가 있으면 `<base>/lib` 를 `sys.path` 맨 앞에 넣는다
   - 아니고 `<base>/harness/__init__.py` 가 있으면 `<base>` 를 `sys.path` 맨 앞에 넣는다
   - 둘 다 없으면 표준 오류에 아래를 내고 2 로 끝난다. 다른 경로의 같은 이름 패키지를 불러오지 않는다

     ```
     error: cannot find the harness package next to <진입 스크립트의 실제 경로>

     help: reinstall the harness — in a project, `harness install` puts the pinned copy back
     ```

4. `harness.cli.main()` 의 반환값으로 끝난다

파일 전체를 3.11 미만 Python 도 해석하는 문법으로 쓴다 — 해석이 끝나야 1번이 돈다. `match` 문 · 대입 표현식처럼
3.8 이후에 생긴 문법을 쓰지 않는다.

### 2-3. 실행 위치

`harness.base` 가 패키지 자기 위치에서 구한다. 환경 변수 · 작업 디렉터리 · `sys.argv` 를 보지 않는다 — 고정 사본으로
넘겨받은 실행이 넘긴 쪽의 값을 물려받지 않는다.

| 이름 | 값 |
|---|---|
| `PACKAGE` | `harness/__init__.py` 의 실제 경로가 있는 디렉터리 |
| `ROOT` | `PACKAGE` 의 부모 이름이 `lib` 이고 그 위에 `bin/harness` 가 파일로 있으면 그 위, 아니면 `PACKAGE` 의 부모 |
| `TEMPLATES` | `ROOT/templates` |
| `DEFAULT_CONFIG` | `TEMPLATES/harness.toml` |
| `ENTRY` | `ROOT/bin/harness` |

이 값을 쓰는 곳은 지금과 같은 값을 받는다.

| 쓰는 곳 | 값 |
|---|---|
| 템플릿 · 기본 설정 · 벤더 선언 읽기 | `TEMPLATES` · `DEFAULT_CONFIG` |
| `harness_version()` 의 소스 체크아웃 · 설치 영수증(`INSTALL_RECEIPT.json`) 판정 | `ROOT` 의 부모 |
| `start-server` 의 UI 위치 | `ROOT/ui` |
| UI 서버 환경의 `HARNESS_BIN` | `ENTRY` |
| install 이 복사하는 원본 | `ENTRY` · `PACKAGE` · `TEMPLATES` (4-2) |
| 고정 사본 대조의 짝과 읽기 실패 경로 표시 | `ENTRY` · `PACKAGE` · `TEMPLATES`, 표시는 `ROOT` 기준 (4-4) |
| `delegate()` 의 자기 판정 | `ENTRY` (4-4) |

## 3. 모듈 지도

### 3-1. 원칙

- 함수 · 상수 · 클래스는 본문을 바꾸지 않고 옮긴다. 이름도 그대로다. 예외는 아래 표다
- 패키지 안의 import 는 `harness.` 로 시작하는 절대 경로로 쓴다
- 패키지의 `__init__.py` 는 docstring 만 갖는다. 예외는 명령 표를 갖는 `commands/__init__.py` 다
- `harness/__init__.py` 의 docstring 은 지금 진입 스크립트의 docstring 이다. `help` 의 첫 줄과 공용 파서의 설명이 이것을 쓴다
- 가변 전역 상태(클론 키 모듈과 키 캐시)는 정의한 모듈 하나가 갖고, 그 모듈의 함수로만 읽고 바꾼다
- `urllib.request` 는 쓰는 함수 안에서 불러온다. 모듈 최상위에서 `urllib` · `http` 를 불러오지 않는다

이름이 바뀌거나 없어지는 것:

| 지금 | 바뀐 뒤 |
|---|---|
| `HERE` (진입 스크립트의 디렉터리) | 없어진다. 진입 스크립트는 `ENTRY`, 패키지 디렉터리는 `PACKAGE` 다 (2-3) |
| `cmd_render` 의 본문 | `harness.render.apply.render_target(cfg, target, args, migrate=True)`. `commands/render.py` 의 `cmd_render(cfg, target, args)` 가 그것을 부른다 |
| `cmd_check` 의 본문 | `harness.drift.check_target(cfg, target, args)`. `commands/check.py` 의 `cmd_check(cfg, target, args)` 가 그것을 부른다 |
| `metrics_module()` | 없어진다. 지표 함수는 `harness.metrics.spans` · `harness.metrics.sessions` 에서 불러온다 |
| `main()` 안의 명령 → 함수 표 | 없어진다. 명령 이름으로 명령 모듈을 찾는다 (3-3) |
| `main()` 안의 인자 해석 | `cli.py` 의 `parse_command_line(argv)`. 통과 명령이 아니면 지금 파서 그대로 해석한다 (3-3) |
| `COMMANDS` 항목의 첫 원소(함수 자리, 늘 `None`) | 통과 표시. 통과 명령은 `True`, 그 밖은 `None` 이다 (3-3) |
| 지표 모듈 · 클론 키 모듈 · 대상 리포 지표 기록기를 불러오는 곳의 `sys.dont_write_bytecode = True` | 없어진다 (5-2) |

다른 명령의 진입 함수를 부르던 명령 — `install` · `set` · `write-doc` · `steps` · `checks` 는 `render_target()` 을,
`status` 는 `check_target()` 을 부른다. 인자는 지금 `cmd_render` · `cmd_check` 에 넘기던 것 그대로다.

### 3-2. 지도

모든 경로는 `src/harness/` 기준이다. 표의 이름은 #96 이 들어간 시점의 정의 이름이다. 표에 없는 정의는 같은 책임의
모듈로 간다.

바닥:

| 모듈 | 책임 · 옮겨 오는 것 |
|---|---|
| `__init__.py` | CLI 설명 docstring |
| `base.py` | 실행 위치 `PACKAGE` · `ROOT` · `TEMPLATES` · `DEFAULT_CONFIG` · `ENTRY`, `die` · `git` · `repo_prefix` · `source_tree` · `harness_version` |
| `text.py` | 문자열 도우미: `BANNER_SH` · `VAR` · `INCLUDE` · `LEAD_COMMENT` · `substitute` · `shell_quote` · `parse_frontmatter` · `toml_str` |

설정 — `config/`:

| 모듈 | 책임 · 옮겨 오는 것 |
|---|---|
| `config/defaults.py` | 설정 상수와 기본값: `BASE_PROTECTED` · `ROLE_NOTES` · `WORKFLOW_NOTES` · `REVIEW_LIMIT` · `BRANCH_NAME` · `PROTECTED_PATH` · `COMMAND_KEYS` · `VERIFY_SCRIPT` · `VERIFY_UNSET` · `VERIFY_DEFAULTS` · `VERIFY_STAGES` · `SCRIPT_TESTS` · `VERIFY_PATH` · `LEGACY_VERIFY` · `LEGACY_VERIFY_TEMPLATE` · `LEGACY_COMMANDS` · `METRICS_DEFAULTS` · `WORKTREE_DEFAULTS` · `INCLUDE_PATH` · `PERMISSIONS_DEFAULTS` · `FORGE_DEFAULTS` · `DOCTOR_DEFAULTS` · `REMOTE_TIMEOUT_LIMIT` |
| `config/load.py` | 읽기와 검증: `load` · `normalize` · `validate` · `loaded_config` · `seed_text` · `seeded_config` · `seed_config` · `cfg_adr_dir` |
| `config/values.py` | 설정 값 해석: `worktree_dir` · `old_alias_keys` · `metrics_cfg` · `QUIET_ENV` · `legacy_verify` · `verify_entry` · `verify_steps` · `verify_when` |
| `config/agents.py` | 벤더 · 역할 선언: `VENDORS`(모듈을 불러올 때 읽고 검사한다) · `ORCHESTRATORS` · `RUNNERS` · `AGENTS` · `expand` · `OPTIONAL_ROLE_KEYS` · `RUN_AGENT` · `role_meta` · `role_model` · `model_args` · `headless_argv` · `run_plan` · `vendor` · `TOOLS_BY_ACCESS` · `tools_of` · `distinct_pairs` |
| `config/workflows.py` | 절차 설정: `COMMANDS_DIR` · `WORKFLOWS` · `STEP_KINDS` · `STEP_REF` · `default_workflows` · `fragment` · `validate_workflows` |
| `config/edit.py` | `harness.toml` 줄 편집: `toml_value` · `set_line` · `steps_block` · `workflow_span` · `section_span` |

생성 — `render/`:

| 모듈 | 책임 · 옮겨 오는 것 |
|---|---|
| `render/derive.py` | 템플릿 변수: `FORGE_CLI` · `docs_regex` · `adr_procedure` · `derive` |
| `render/plan.py` | 생성 파일 목록과 쓸 경로: `plan` · `ci_dir` · `role_file_skip` · `harness_paths` · `seeded_paths` |
| `render/apply.py` | 렌더 한 번: `render_target` |
| `render/settings.py` | 권한 파일: `deny_rules` · `WRITE_DOC_CALLERS` · `write_doc_scope` · `ALLOW_EXCLUDED` · `ALLOW_KEYS` · `allowed_scripts` · `forge_allow` · `allow_rules` · `settings_json` |
| `render/scripts.py` | 셸 생성물: `SHELL_EXPANDS` · `harness_env` · `VERIFY_SH` · `verify_script` · `commands_doc` · `POST_COMMIT_HOOK` · `PRE_PUSH_VERIFY` |
| `render/agents.py` | 에이전트 정의: `agent_table` · `command_rows` · `role_notes` · `agent_files` · `_sandbox` · `claude_md` · `codex_toml` · `ADAPTERS` |
| `render/workflows.py` | 절차 문서: `ROLE_LABEL` · `step_heading` · `step_body` · `custom_head` · `custom_command` · `workflow_doc` |
| `render/docs.py` | forge 명령 사전 · 결정 기록 문서 · forge 템플릿: `forge_doc` · `adr_files` · `ISSUE_FORMS` · `FORGE_TEMPLATE_DIRS` · `forge_template_path` · `forge_templates` |

대상 리포 쓰기와 대조:

| 모듈 | 책임 · 옮겨 오는 것 |
|---|---|
| `safepath.py` | 경로 규칙과 공용 함수: `PATH_COMPONENT` · `GUARD_VERBS` · `path_form_fault` · `link_component` · `path_fault` · `guarded_path` · `make_dirs` · `make_parents` · `copy_tree` |
| `manifest.py` | 매니페스트: `MANIFEST` · `MANIFEST_MANAGED` · `MANIFEST_LINE` · `PINNED` · `CONFLICT_MARKERS` · `read_manifest` · `manifest_entries` · `previous` · `manifest_faults` · `MANIFEST_CONFLICT_HELP` · `refuse_unsafe_manifest` · `sha256_of` · `write_manifest_hashes` · `prune` |
| `changes.py` | 바꿀 경로와 사용자 파일: `stale_paths` · `adoptable` · `change_paths` · `refuse_unsafe_paths` · `user_files` · `refuse_user_files` · `refuse_changes` · `adopt_user_files` · `revert_for_user_files` |
| `drift.py` | 생성 파일 · 관리 파일 대조: `staged_text` · `drift` · `staged_bytes` · `managed_drift` · `check_target` |
| `pin.py` | 고정 사본: `PINNED_PARTS` · `pinned_files` · `PINNED_SHOWN` · `pinned_differences` · `verify_pinned` |
| `hookspath.py` | `core.hooksPath`: `HOOKS_DIR` · `hooks_path` · `hooks_expected` · `hooks_on` · `enable_hooks` · `report_hooks` |
| `projectdocs.py` | 프로젝트 문서 · 메모: `OWNED_DOCS` · `PROJECT_DOCS` · `NOTE_HEADS` · `project_docs` · `writable_docs` · `note_body` |

기기 단위 상태 — `home/` (등록부 루트 `HARNESS_HOME`, 없으면 `~/.harness`):

| 모듈 | 책임 · 옮겨 오는 것 |
|---|---|
| `home/clone_key.py` | 클론 키: `CLONE_KEY` · `clone_key_module` · `clone_key` · `expand_key` 와 그 캐시 |
| `home/registration.py` | 등록부와 등록: `registry` · `read_registration` · `registrations` · `registry_lock` · `register` · `unregister` · `report_same_name` · `LEGACY_DONE` |
| `home/legacy.py` | 옛 이름 디렉터리 옮기기: `migrate_legacy` 와 그 도우미(`legacy_dir` · `legacy_moves` · `move_state_dir` · `move_usage_log` · `migrate_worktrees` 등), 표지 상수 `METRICS_LOCK` · `METRICS_MARKS` · `SPANS_FILE` · `MOVE_TMP` · `LEGACY_OFFSETS` · `NO_HARD_LINK` |

점검 · 실행 · 기기:

| 모듈 | 책임 · 옮겨 오는 것 |
|---|---|
| `readiness/items.py` | doctor 항목 수집과 그리기: `doctor_items` · `managed_items` · `unsafe_manifest_items` · `adapter_header` · `PLACEHOLDER` · `ADAPTER_UNVERIFIED` · `ADR_EXE` · `MANAGED_SHOWN` · `doctor_counts` · `doctor_json` · `doctor_text` |
| `readiness/refs.py` | 참조 검사: `SCAN_DIRS` · `SCAN_ROOTS` · `SCAN_SUFFIX` · `REF_RE` · `REF_PREFIX` · `REF_SUFFIX` · `REF_SKIP` · `REF_OPTIONAL` · `scan_files` · `ref_paths` · `dangling_roles` · `git_ignored` · `broken_refs` |
| `readiness/remote.py` | 원격 점검: `REMOTE_UNCHECKED` · `RUNNER_CHECK_AFTER_START` · `CHECK_START_FD_ENV` · `REVIEWER` · `remote_env` · `remote_finish` · `remote_call` · `close_fds` · `runner_check_call` · `ls_remote` · `remote_git_items` · `forge_call` · `remote_forge_items` · `remote_items` · `remote_reviewer_items` |
| `worktree.py` | 이슈 worktree: `ISSUE_NO` · `worktree_state` · `git_common_dir` · `own_worktree` · `registered_worktrees` · `left_worktrees` · `issue_worktree` · `open_worktree` · `copy_include` · `close_worktree` |
| `server.py` | UI 서버: `UI_PORT` · `UI_HASH_FILES` · `UI_HASH_DIRS` · `ui_source_hash` · `needs_build` · 서버 기록의 읽기 · 쓰기 · 식별 · 중지 함수 · `ui_copy` · `build_ui` · `ui_env` · `start_dev_server` |
| `tools.py` | 기기의 도구 찾기: `ADR_TOOLS` · `claude_models` · `codex_models` · `MODEL_READERS` · `recorded_tools` · `model_ok` · `detect_tools` |
| `metrics/spans.py` | 지표 기록기 불러오기와 스팬 집계: `load_metric` · `read_spans` · `parse_iso` · `pct` · `metrics_report` · `UNATTRIBUTED` |
| `metrics/sessions.py` | 에이전트 CLI 세션 가져오기: `claude_usage` · `codex_usage` · `new_lines` · `seen` · `source_dirs` · `import_claude` · `import_codex` · `metrics_import` |

명령:

| 모듈 | 책임 · 옮겨 오는 것 |
|---|---|
| `cli.py` | `main` · `parse_command_line` · `DELEGATES` · `delegate` |
| `commands/__init__.py` | 명령 표 `COMMANDS` |
| `commands/<명령>.py` | 그 명령의 진입 함수 `cmd_<명령>` 과 그 명령만 쓰는 정의 |

명령 모듈은 명령마다 하나다 — `install` · `render` · `check` · `doctor` · `set` · `write_doc` · `fix` · `run` · `steps` ·
`checks` · `metrics` · `forge_setup` · `vars` · `uninstall` · `start_server` · `stop_server` · `server_status` · `schema` ·
`status` · `tools` · `projects` · `version` · `help`. 진입 함수 말고 명령 모듈에 두는 것:

| 명령 모듈 | 함께 두는 정의 |
|---|---|
| `commands/install.py` | `install_registered` · `undo_created` · `clear_dir` |
| `commands/uninstall.py` | `owned_files` · `by_dir` · `confirm_purge` |
| `commands/fix.py` | `FIXES` |
| `commands/steps.py` | `refuse_notes_rename` · `rename_or_delete_workflow` |
| `commands/schema.py` | `CONFIG_SECTION` · `CONFIG_KEY` · `config_notes` · `template_path` |

`src/bin/harness_metrics.py` 의 정의는 전부 `metrics/` 로 간다. `metrics/` 는 `metrics/` 밖의 하네스 모듈을 불러오지
않는다 — 등록부 경로 같은 CLI 의 값은 지금처럼 인자로 받는다.

### 3-3. 명령을 가르기

`main()` 의 순서는 지금과 같다.

1. `parse_command_line(sys.argv[1:])` 로 인자를 해석한다 — 통과 명령이 아니면 지금과 같은 파서다 (아래 "인자 통과")
2. `help` 면 `commands/help.py` 로
3. `start-server` · `stop-server` · `server-status` · `tools` · `projects` 면 대상을 해석하지 않고 그 명령 모듈로
4. 대상을 해석하고 `delegate()` 를 부른다. 넘기면 여기서 끝난다
5. 그 명령 모듈을 불러온다. `install` 은 설정 없이 부르고, 나머지는 `COMMANDS` 의 설정 필요 여부대로 설정을 읽고
   검증한 뒤 부른다

- 명령 모듈의 이름은 명령 이름의 `-` 를 `_` 로 바꾼 것이다(`write-doc` → `commands/write_doc.py`). 진입 함수는
  `cmd_<모듈 이름>` 이다
- `main()` 은 실행할 명령의 모듈 하나만 불러온다(`importlib`). 다른 명령의 모듈과 그 의존은 불러오지 않는다. 위임하는
  실행은 명령 모듈을 불러오지 않는다
- 벤더 선언(`vendors.toml`)은 `harness.cli` 를 불러올 때, 명령을 가르기 전에 읽고 검사한다 — 선언이 잘못되면 `help` ·
  `version` 을 포함한 모든 명령이 지금과 같은 오류로 멈춘다
- `help` 는 `COMMANDS` 와 `harness/__init__.py` 의 docstring 으로 지금과 같은 내용을 낸다
- 명령 표 `COMMANDS` 는 `commands/__init__.py` 에 있다. `cli.py` 는 그것을 불러와 쓰고, `DELEGATES` 는 `cli.py` 에 있다

#### 인자 통과

공용 파서는 모든 명령이 함께 쓰는 인자 파서다 — 위치 인자 `command` · `args` 와 공용 옵션(`--target` · `--staged` ·
`--json` 등). 공용 옵션을 명령줄 어디서나 받으므로(`parse_intermixed_args`) 이름 뒤에 공용 옵션과 같은 이름의 인자가
오면 공용 옵션으로 읽는다. 통과 명령은 이름 뒤를 이 해석에 넘기지 않는다.

- `COMMANDS` 의 항목은 `(통과, 설정이 필요한가, 인수, 설명)` 이다. 통과가 `True` 인 명령이 통과 명령이고, 그 밖은 `None` 이다
- 이 명세의 명령은 모두 `None` 이다. 통과 명령은 그 명령을 더하는 명세가 정한다
- 명령줄의 모양은 `harness [--target DIR] <명령> <인자…>` 이다

`parse_command_line(argv)` 는 명령 표를 부를 때 읽고, 공용 파서가 명령 이름으로 읽는 첫 위치 인자(공용 옵션의 값은 위치
인자가 아니다)로 가른다.

| 첫 위치 인자 | 해석 |
|---|---|
| 없거나 통과 명령이 아니다 | 지금 파서 그대로 argv 전체를 해석한다. 모르는 명령의 오류도 그대로다 |
| 통과 명령이다 | 이름 앞은 공용 파서가, 이름 뒤는 그 명령이 갖는다 (아래) |

통과 명령일 때:

- 이름 앞에는 `--target DIR`(`--target=DIR`)과 `-h` · `--help` 만 온다. `-h` · `--help` 가 있으면 지금처럼 `help` 로 간다
- 이름 바로 뒤의 토큰이 `--target` 이면 그다음 토큰을, `--target=DIR` 이면 `=` 뒤를 하네스 루트로 받는다. 한 번만이다 —
  그 뒤에 다시 오는 `--target` 은 명령의 인자다
- 그 밖의 이름 뒤 토큰은 순서 · 내용 그대로 명령의 인자(`args.args`)다. `-` 로 시작하는 것(`-h` · `--help` · `--` ·
  공용 옵션과 같은 이름)도 그렇다
- 하네스 루트의 뜻과 기본값(현재 디렉터리)은 전역 `--target` 과 같다. 공용 옵션의 다른 속성은 기본값이다
- 아래는 공용 파서의 오류 형식 — 사용법 줄 뒤에 `harness: error: <문구>` — 으로 2 로 끝난다

  | 경우 | 문구 |
  |---|---|
  | 이름 앞에 `--target` · `-h` · `--help` 말고 다른 공용 옵션이 있다 | `only --target may come before <명령>: <옵션>` |
  | `--target` 이 이름 앞과 이름 바로 뒤에 모두 있다 | `--target is given both before and after <명령>` |
  | 이름 바로 뒤의 `--target` 에 값이 없다 | `argument --target: expected one argument` |

- `delegate()` 는 지금처럼 `sys.argv[1:]` 를 그대로 넘긴다. 넘겨받은 CLI 가 같은 규칙으로 다시 나눈다

### 3-4. 의존 방향

| 규칙 | 대상 |
|---|---|
| 하네스 모듈을 불러오지 않는다 | `base` |
| `base` 만 불러온다 | `text` |
| `metrics/` 밖의 하네스 모듈을 불러오지 않는다 | `metrics/` |
| `cli` · `commands` · `commands.<명령>` 을 불러오지 않는다 | `cli` 와 `commands/` 가 아닌 모듈 전부 (공용 모듈) |
| 다른 `commands.<명령>` 과 `cli` 를 불러오지 않는다. `commands` 의 명령 표는 불러올 수 있다 | `commands/<명령>.py` |
| `commands.<명령>` 을 import 문으로 불러오지 않는다 (3-3 의 이름 찾기로만) | `cli` |
| 모듈 최상위에서 `urllib` · `http` 를 불러오지 않는다 | 패키지 전부 |
| 모듈 최상위 import 로 이은 하네스 모듈 사이에 순환이 없다 | 패키지 전부 |

이 규칙과 3-1 의 절대 경로 규칙은 `script/project/check-cli.py imports` 가 검사한다 (6절).

## 4. 고정 사본

### 4-1. 구성

```
.harness/
├── bin/harness       ENTRY 의 사본 (실행 권한 그대로)
├── lib/harness/      PACKAGE 의 사본 (__pycache__ 제외)
├── templates/        TEMPLATES 의 사본 (__pycache__ 제외)
├── VERSION
├── generated         매니페스트
└── managed           매니페스트
```

- `PINNED_PARTS` 는 `.harness/bin` · `.harness/lib` · `.harness/templates` · `.harness/VERSION` 이다
- `pinned_files()` 는 `bin/` · `lib/` · `templates/` 아래 파일 전부(`__pycache__/` 제외)와 `VERSION` 이다

### 4-2. install

- 고정 사본을 깔 때 진입 스크립트 · 패키지 · 템플릿 · `VERSION` 을 4-1 의 자리에 깐다. 쓰기는 모두 경로 안전 공용 함수
  (`guarded_path()`)를 거친다
- 사전 판정의 바꿀 경로(`.harness` 와 `PINNED_PARTS`)에 `.harness/lib` 가 든다. `.harness/lib` 에 링크 성분이 있으면
  아무것도 바꾸지 않고 2 로 끝난다 — `.harness/bin` 과 같은 규칙이다
- 깐 직후의 `pinned_files()` 해시로 `.harness/managed` 의 고정 사본 줄을 쓴다 — `.harness/lib/harness/` 아래 파일마다 한 줄이다.
  관리 파일 줄은 지금처럼 지난 render 의 것을 둔다
- 표준 출력은 그대로다: `install: <.harness 경로> (harness <버전>)`
- 소스 리포 분기는 `PINNED_PARTS` 전부를 걷는다 — `.harness/lib` 가 있으면 함께 걷힌다
- 실패한 install 이 이번에 깐 `.harness` 를 걷는 규칙은 그대로다

### 4-3. 옛 배치와 오가기

| 경우 | 동작 |
|---|---|
| 옛 배치(`.harness/bin/harness_metrics.py` 가 있고 `.harness/lib/` 가 없다)의 리포에서 새 CLI 로 install | `.harness/` 를 매니페스트 둘만 남기고 비운 뒤 4-1 대로 깐다. `.harness/bin/harness_metrics.py` 와 그 매니페스트 줄이 남지 않는다 |
| 옛 배치의 리포에서 새 전역 CLI 로 위임 명령 | 버전이 달라 대조하지 않고 `.harness/bin/harness` 로 넘긴다 — 지금과 같다 |
| 새 배치의 리포에서 옛 전역 CLI 로 위임 명령 | 옛 CLI 는 버전이 달라 대조하지 않고 `.harness/bin/harness` 로 넘긴다. 진입 스크립트가 `.harness/lib/harness/` 를 찾는다 |
| 새 배치의 리포에서 옛 CLI 로 install | 옛 CLI 가 `.harness/` 를 비우고 옛 배치로 깐다. `.harness/lib/` 도 걷힌다 |

### 4-4. 위임과 대조

`delegate()` 는 넘길 진입 스크립트(`.harness/bin/harness`, 소스 리포면 `src/bin/harness`)의 실제 경로가 `ENTRY` 의 실제
경로와 같으면 넘기지 않는다. 패키지 모듈의 경로와 비교하지 않는다 — 그 둘은 같아질 수 없어서, 같은 사본이 자기에게
끝없이 넘긴다.

전역 CLI 가 고정 사본과 비교하는 짝:

| 전역 CLI 쪽 | 고정 사본 쪽 |
|---|---|
| `ENTRY` | `.harness/bin/harness` |
| `PACKAGE` 아래 파일 전부 | `.harness/lib/harness/` 아래 파일 전부 |
| `TEMPLATES` 아래 파일 전부 | `.harness/templates/` 아래 파일 전부 |

- 다름으로 세는 것: 해시가 다른 파일, 한쪽에만 있는 파일. `.harness/bin/` · `.harness/lib/` · `.harness/templates/` 에서
  짝이 없는 파일도 다름이다. `__pycache__/` 는 양쪽에서 뺀다
- 버전 판정, 경고 문구, `-->` 줄 개수 제한, 표준 오류에만 낸다는 것, 넘기기를 막지 않는다는 것은 그대로다
- 읽지 못한 파일의 표시 경로는 사본 쪽이면 `.harness/` 기준, 전역 CLI 쪽이면 `ROOT` 기준이다

### 4-5. check · doctor · render · uninstall

- `check` · `doctor` 의 고정 사본 대조는 매니페스트 줄로 한다. `.harness/lib/harness/` 아래 파일도 같은 규칙으로
  `modified managed file` · `missing managed file` 이 되고, 안내(`harness install`)는 그대로다
- `render` 는 `.harness/` 줄을 이전 매니페스트에서 그대로 옮긴다 — 그대로다
- `uninstall` 은 `.harness/` 를 통째로 걷는다 — 그대로다

## 5. 바이트코드

### 5-1. 위치

진입 스크립트가 2-2 의 2번에서 정한다.

- 등록부 루트는 `HARNESS_HOME` 이 비어 있지 않으면 그 값, 아니면 `~/.harness` 다 — `registry()` 와 같은 규칙이다
- 등록부 루트가 디렉터리로 있으면
  - `sys.pycache_prefix` 를 `<등록부 루트>/.cache/pycache` 의 절대 경로로 정한다. 환경의 `PYTHONPYCACHEPREFIX` 보다 앞선다
  - `pycache` 디렉터리가 없으면 0700 으로 만든다(없는 `.cache` 는 기본 권한). 이미 있으면 권한을 바꾸지 않는다.
    만들지 못하면(`OSError`) 아무것도 내지 않고 넘어간다
- 등록부 루트가 없으면 `sys.dont_write_bytecode` 를 켠다. 접두 경로는 정하지 않는다 — 진입 스크립트는 등록부 루트를
  만들지 않는다

접두 경로가 정해지면 Python 은 그 뒤에 불러오는 모듈(CLI 패키지, 경로로 불러오는 관리 스크립트 모듈, 표준 라이브러리)의
바이트코드를 그 아래에서 소스의 절대 경로를 따라 쓰고 읽는다. 소스 옆의 `__pycache__` 는 읽지도 쓰지도 않는다.
쓰기에 실패하면 Python 이 무시하고 소스에서 컴파일해 돈다 — 출력과 종료 코드가 같다. `PYTHONDONTWRITEBYTECODE` 나
`-B` 가 켜져 있으면 쓰지 않는다.

### 5-2. 리포에 남기지 않는다

- 패키지 코드는 `sys.dont_write_bytecode` 를 바꾸지 않는다. 바꾸는 것은 진입 스크립트(등록부 루트가 없을 때)뿐이다
- 경로로 불러오는 모듈 — `TEMPLATES/managed/script/_clone_key.py` 와 대상 리포의 `script/metric.py` — 의 바이트코드도
  접두 경로 아래로 간다
- 그래서 CLI 실행은 소스 트리 · Homebrew 설치 · 고정 사본 · 대상 리포의 `script/` 어디에도 `__pycache__` 를 만들지 않는다.
  고정 사본은 커밋되는 파일이고, pre-push 와 리뷰 요청은 미추적 파일이 없는 작업 트리를 요구한다
- 관리 스크립트가 스스로 바이트코드 쓰기를 끄는 것(`_clone_key.py` · `metric.py` · `run-agent.py`)은 이 명세가 바꾸지 않는다

### 5-3. 등록부 안의 `.cache/`

- `.cache/` 는 `.` 으로 시작하는 등록부 내부 항목이다(`docs/spec/96-machine-local-state-key.md` 3-1). `harness projects` ·
  doctor `registry` 절 · 옛 이름 디렉터리 옮기기 · `uninstall` 이 보지 않는다
- 등록을 읽기만 하는 명령(`projects` · `doctor`)도 이 아래에 쓴다. 등록부를 바꾸는 것으로 보지 않는다
- 하네스는 이 아래를 정리하지 않는다. 언제 지워도 다음 실행이 다시 만든다

## 6. 검증 설정 — 이 리포의 `harness.toml`

```toml
[verify]
checks = [
  { name = "CLI 가 컴파일된다", run = "python3 script/project/check-cli.py compile", paths = ["src/bin/**", "src/harness/**", "script/project/check-cli.py"] },
  { name = "CLI 패키지 의존 방향", run = "python3 script/project/check-cli.py imports", paths = ["src/harness/**", "script/project/check-cli.py"] },
  { name = "Python 단위 테스트", run = "cd src && python3 -B -m unittest discover -s test/unit", paths = ["src/harness/**", "src/templates/**", "src/test/**"] },
  { name = "UI 단위 테스트", run = "cd src/ui && node --test lib/*.test.js", paths = ["src/ui/**", "src/bin/**", "src/harness/**"] },
]
test_paths = ["src/bin/**", "src/harness/**", "src/templates/**", "src/test/**"]
```

나머지 키는 그대로다. "UI 단위 테스트" 가 CLI 원문의 상수를 대조하므로(7-2) CLI 경로에도 걸린다. "Python 단위 테스트" 는
"CLI 패키지 의존 방향" 바로 뒤이고 `on` 은 기본값(commit)이다. 단위 테스트가 읽는 템플릿과 테스트 보조 파일
(`src/templates/` · `src/test/` 아래)만 바뀌어도 돈다. 그 자리와 실행 규칙은 7-5 다. render 가
`script/harness-verify.sh` 와 규칙 정본의 검증 순서를 따라 바꾼다.

`script/project/check-cli.py` — python3 표준 라이브러리만 쓴다. 리포 루트는 이 파일의 위치에서 구한다.

| 인자 | 하는 일 | 종료 코드 |
|---|---|---|
| `compile` | `src/bin/harness` 와 `src/harness/` 아래 `.py` 전부를 `compile()` 한다. 바이트코드를 쓰지 않는다. 실패한 파일마다 `<경로>:<줄>: <메시지>` 를 표준 오류에 낸다 | 모두 되면 0, 아니면 1 |
| `imports` | 3-1 의 절대 경로 규칙과 3-4 의 규칙을 각 모듈의 구문 트리로 본다. 어긴 import 마다 `<경로>:<줄>: <규칙>` 을 표준 오류에 낸다. 순환은 이은 모듈 이름을 한 줄로 낸다 | 어긴 것이 없으면 0, 있으면 1 |
| 없음 · 그 밖 | 사용법 한 줄을 표준 오류에 낸다 | 2 |

`script/project/README.md` 표에 한 줄을 더한다.

## 7. 회귀 테스트

### 7-1. 판정 기준과 고칠 수 있는 범위

- 판정 기준은 `src/test/render-test.sh` 와 `src/ui/lib/doctor.test.js` 검사 줄의 **기대값** — 종료 코드 · 출력 문자열 ·
  파일 상태 — 이다. 기대값은 바꾸지 않는다
- 고칠 수 있는 것은 준비부(무엇을 어디에 복사하고 어떻게 불러오나)와 CLI 의 내부 구조를 보는 검사 줄(7-2)뿐이다.
  리뷰 요청 본문에 바꾼 줄마다 전후 대응표를 둔다
- 7-2 는 배치를 바꾸기 전, 옛 배치(`src/bin/harness` 한 파일)에서 먼저 바꾸고 회귀 테스트 전체가 통과하는 것을 확인한다.
  7-2 의 복제와 로더는 두 배치를 모두 다룬다. 그 뒤 배치를 바꾸는 커밋은 테스트 파일을 고치지 않고 7-3 의 케이스와
  7-5 의 단위 테스트를 더하기만 한다
- 각 커밋에서 검증 일괄(`script/run-lint-test.sh`)이 통과한다
- 옮긴 동작의 판정 기준은 위의 셸 테스트와 UI 단위 테스트다. 7-5 의 Python 단위 테스트는 이 명세가 새로 두는 것(명령
  표와 명령 모듈의 짝, 인자 통과)을 본다

### 7-2. 배치 중립으로 바꾸는 곳

| 종류 | 지금 | 바꾼 뒤 |
|---|---|---|
| 소스 트리 복제 | `src/bin/` 의 두 파일과 `src/templates/` 를 복제본의 `src/` 로 복사한다 | `src/` 에서 `ui/` · `test/` · `__pycache__` 를 뺀 전부를 복제본의 `src/` 로 복사한다 |
| CLI 복제 (다른 CLI · Homebrew keg 흉내) | `bin/` · `templates/` 를 복사한다 | 같은 규칙으로 복제 위치에 복사한다 |
| 고정 사본의 지표 모듈 확인 | `.harness/bin/harness_metrics.py` 가 있다 | `src/` 에서 복사한 실행 부품마다 고정 사본에 같은 바이트의 파일이 있다 — `bin/` → `.harness/bin/`, `templates/` → `.harness/templates/`, 그 밖의 디렉터리 → `.harness/lib/<이름>/`. `.harness/bin/` 에 짝이 없는 파일이 없다 |
| 바이트코드 흔적 | `src/bin/__pycache__` · `.harness/bin/__pycache__` 가 없다 | 복제본의 `src/` 아래와 설치본의 `.harness/` 아래 어디에도 `__pycache__` 가 없다 |
| 프로세스 안 호출 | 진입 스크립트를 모듈 하나로 불러와 함수를 부르고, 모듈 전역(`subprocess` · `select` · `os`)을 바꿔 끼운다 | `src/test/cli_loader.py` 로 불러온다. 바꿔 끼우기는 그 전역을 쓰는 함수를 정의한 모듈에 한다 |
| CLI 원문 검사 | `src/bin/harness` 원문에서 상수 · 이름 · 금지된 호출을 찾는다(표지 상수가 하나인지, forge CLI 를 직접 부르지 않는지, 지운 이름이 없는지, `BASE_PROTECTED` 의 값) | CLI 원문 전부 — `src/bin/` 의 파일과 `src/harness/` 아래 `.py`, `__pycache__` 제외 — 에서 찾는다 |
| UI 단위 테스트의 상수 대조 | `doctor.test.js` 가 `src/bin/harness` 원문에서 `DOCTOR_DEFAULTS` · `REMOTE_TIMEOUT_LIMIT` · `RUNNER_CHECK_AFTER_START` 를 읽는다 | 같은 범위의 CLI 원문에서 읽는다 |

`src/test/cli_loader.py` 의 계약:

- `load(<진입 스크립트 경로>)` — 진입 스크립트의 `bin/` 부모에 `harness/__init__.py` 가 있으면 그 부모를 `sys.path` 맨 앞에
  넣고 패키지의 모듈을 전부 불러온다. 없으면 진입 스크립트를 모듈 하나로 불러온다. 불러오기 전에 `sys.dont_write_bytecode`
  를 켠다 — 소스 트리에 `__pycache__` 를 쓰지 않는다
- 돌려주는 객체의 `<이름>` 속성은 그 이름을 모듈 최상위에서 정의한(대입 · `def` · `class`) 모듈의 값이다. import 로 받은
  이름은 정의로 치지 않는다
- `module_of(<이름>)` 은 그 이름을 정의한 모듈을 돌려준다. 옛 배치에서는 진입 스크립트 모듈 하나다
- 같은 이름을 두 모듈이 정의하거나 아무 모듈도 정의하지 않으면 예외로 멈춘다

### 7-3. 새 케이스

`render-test.sh` 에 새 `UT-<번호>` 블록 둘을 더한다. 번호는 머지 시점에 겹치지 않는 다음 번호다. 바이트코드를 보는
케이스는 `PYTHONDONTWRITEBYTECODE` 를 뺀 환경에서 CLI 를 부른다.

"CLI 패키지와 고정 사본":

| 케이스 | 확인하는 것 |
|---|---|
| 패키지 사본 | install 한 리포의 `.harness/lib/harness/` 의 파일 목록과 바이트가 `src/harness/` 와 같고(`__pycache__` 제외), `.harness/bin/` 에는 `harness` 하나뿐이다. `.harness/managed` 에 `.harness/lib/harness/` 아래 파일마다 줄이 있고, 하네스 루트에서 `shasum -a 256 -c .harness/managed` 가 통과한다 |
| 옛 배치에서 갱신 | 고정 사본을 옛 배치로 바꾼 리포(`.harness/lib/` 와 그 매니페스트 줄을 지우고 `.harness/bin/harness_metrics.py` 와 그 줄을 더한 것)에서 install 하면 종료 코드 0 이다. `.harness/bin/harness_metrics.py` 와 그 줄이 없고, `.harness/lib/harness/` 와 그 줄이 있고, `check` 가 0 이다 |
| 사본 자리의 링크 | `.harness/lib` 가 바깥 디렉터리를 가리키는 링크인 리포에서 install 하면 종료 코드 2 이고 바깥 디렉터리가 그대로다 |
| 패키지 변경 | `.harness/lib/harness/` 아래 파일 하나를 고치면 `check` 가 1 이고 `help:` 에 `harness install` 이 있다. 회귀 테스트의 `src/bin/harness` 로 그 리포의 `doctor` 를 부르면 표준 오류의 `warning: the pinned harness differs` 아래에 그 경로가 있다. `.harness/lib/harness/` 에 파일 하나를 더해도 그 경로가 나온다 |
| 위임이 끝난다 | 고정 사본이 있는 리포에서 `src/bin/harness check` 와 `.harness/bin/harness check` 가 각각 60초 안에 0 으로 끝난다. 뒤의 것은 표준 오류에 `note: this project is pinned` 가 없다 |
| 패키지 없음 | `.harness/lib` 를 지운 리포에서 `.harness/bin/harness version` 이 2 로 끝나고 표준 오류 첫 줄이 `error: cannot find the harness package` 로 시작한다 |
| help 첫 줄 | `harness help` 의 첫 줄이 `harness — generate the AI development harness from one config, and block drift.` 이다 |
| 가벼운 시작 | 소스 트리 밖에서 `python3 -X importtime src/bin/harness version` 을 부르면 표준 오류에 `urllib.request` · `http.client` 가 없고, `harness.commands.` 로 시작하는 모듈은 `harness.commands.version` 하나다 |

"바이트코드 캐시":

| 케이스 | 확인하는 것 |
|---|---|
| 캐시 위치 | 새로 만든 빈 디렉터리를 `HARNESS_HOME` 으로 두고 install 한 리포에서 `harness check` 를 부르면 `$HARNESS_HOME/.cache/pycache` 가 0700 이고, 그 아래 리포 `.harness/lib/harness/` 의 실제 경로를 따른 자리에 `cli` 모듈의 `.pyc` 가 있다. 리포 아래 어디에도 `__pycache__` 가 없다 |
| 소스 트리 | 같은 방식으로 소스 트리 복제본의 `src/bin/harness check` 를 부르면 복제본 `src/` 아래 어디에도 `__pycache__` 가 없고, `$HARNESS_HOME/.cache/pycache` 아래에 복제본 `src/harness/` 를 따른 `.pyc` 가 있다 |
| 등록부가 없을 때 | 없는 경로를 `HARNESS_HOME` 으로 두고 소스 트리 복제본의 `harness version` · `harness projects` 를 부르면 둘 다 0 으로 끝나고(`projects` 는 `{"projects": [], "legacy": []}`), 그 경로가 생기지 않으며, 복제본 `src/` 아래에 `__pycache__` 가 없다 |
| 등록부 자리가 파일일 때 | `HARNESS_HOME` 이 파일이면 `harness version` 이 0 이고 출력이 `harness <버전>` 이다 |
| 등록 목록 | `.cache/` 가 생긴 등록부에서 `harness projects` 의 `projects` · `legacy` 어디에도 `.cache` 가 없다 |

터미널 출력의 한글 검사는 이 블록들의 출력에도 적용한다.

### 7-4. 기존 케이스

7-2 의 표에 든 것 말고는 바꾸지 않는다. 명세 64 12-2 의 "설치본의 지표 모듈" · "소스 리포의 지표 모듈" 케이스는 7-2 의
배치 중립 확인과 7-3 이 덮는다.

### 7-5. Python 단위 테스트

CLI 패키지의 단위 테스트 기반이다. CLI 패키지의 단위 테스트는 모두 이 자리와 이 단계 하나를 쓴다.

- 자리: `src/test/unit/test_<대상>.py`. 소스 리포에만 있고 대상 리포 · 고정 사본 · Homebrew 설치로 가지 않는다 — install 이
  복사하는 것은 `ENTRY` · `PACKAGE` · `TEMPLATES` 다 (4-2)
- 실행: `cd src && python3 -B -m unittest discover -s test/unit`. `-B` 라서 리포에 `__pycache__` 가 생기지 않는다. 표준
  라이브러리 `unittest` 만 쓴다. 작업 디렉터리가 `src/` 이므로 `import harness` 가 `src/harness/` 를 불러온다
- 검증 단계: 6절의 "Python 단위 테스트"
- 단위 테스트는 CLI 를 하위 프로세스로 띄우지 않는다. 패키지 모듈을 불러 함수를 부르고, 외부 명령은 그것을 부르는 함수를
  바꿔 끼운다
- `unittest discover` 는 테스트가 0건이면 종료 코드 5 로 끝난다(python3 3.13 · 3.14). 그래서 스모크 테스트
  `test_commands.py` 를 늘 둔다
- 두 파일과 검증 단계는 패키지가 생기는 커밋에 함께 더한다 — 옛 배치에는 불러올 패키지가 없다

| 파일 | 보는 것 |
|---|---|
| `test_commands.py` (스모크) | 명령 표의 이름마다 `harness.commands.<모듈 이름>` 을 불러올 수 있고 그 모듈에 `cmd_<모듈 이름>` 이 있다. `src/harness/commands/` 의 명령 모듈마다 명령 표에 이름이 있다. 명령 표 항목은 네 원소이고 첫 원소(통과 표시)는 `True` 또는 `None` 이다 |
| `test_cli.py` | `parse_command_line()` 의 인자 나누기 (3-3). 통과 명령은 시험용 항목 `probe` 를 명령 표에 잠시 더해 본다 — 아래 표 |

| 명령줄 | 결과 |
|---|---|
| `set --target D a.b v` · `--target D set a.b v` | 명령 `set`, 하네스 루트 `D`, 인자 `a.b` `v` — 통과 명령이 아닌 명령의 해석이 그대로다 |
| `--target D probe x --json -h --target E` | 명령 `probe`, 하네스 루트 `D`, 인자 `x` `--json` `-h` `--target` `E` |
| `probe --target D x` · `probe --target=D x` | 하네스 루트 `D`, 인자 `x` |
| `probe x --target D` | 하네스 루트 기본값(`.`), 인자 `x` `--target` `D` |
| `probe -- --help` | 인자 `--` `--help` |
| `-h probe x` | 도움말 요청이 켜진다 (`help` 로 간다) |
| `--json probe x` · `--target D probe --target E` · `probe --target` | 종료 코드 2 와 3-3 의 문구 |

## 8. 문서

### 8-1. README

| 절 | 적는 사실 |
|---|---|
| "구조" 트리 | `src/bin/harness` 는 진입 스크립트(패키지를 찾아 `harness.cli.main()` 을 부른다), `src/harness/` 는 CLI 패키지(명령마다 `commands/<명령>.py`, 여러 명령이 쓰는 공용 모듈), `src/test/unit/` 은 CLI 패키지의 Python 단위 테스트 |
| "검증" | `cd src && python3 -B -m unittest discover -s test/unit` 이 CLI 패키지의 단위 테스트를 돈다. 소스 리포에서만 돈다 |
| "시작하기" 의 `install` 설명 | `.harness/` 에 진입 스크립트(`bin/`) · CLI 패키지(`lib/harness/`) · 템플릿(`templates/`) · `VERSION` 이 깔리고 커밋된다 |
| "업데이트" | 바이트코드 캐시는 등록부 아래 `.cache/pycache/`(`HARNESS_HOME` 이 있으면 그 아래)에 쌓이고 지워도 된다. 리포에는 `__pycache__` 가 생기지 않는다. Homebrew 설치는 `src/` 의 `bin/` · `harness/` · `templates/` · `ui/` 를 `libexec` 에 넣는다 |

### 8-2. 다른 명세

- `docs/spec/` 의 명세에서 함수 · 상수의 자리로 `src/bin/harness` 를 적은 서술(정본 위치 표 포함)은 3-2 지도의 모듈로
  바꾼다. 명령줄로서의 `src/bin/harness`(실행 경로)는 그대로 둔다. 대상은 58 · 59 · 60 · 61 · 62 · 64 · 70 · 71 · 96 이다
- 각 명세의 "보호 문서에 반영할 것" 절과 분해 문서(`docs/plan/`)는 고치지 않는다

그 밖에 내용을 바꾸는 곳:

| 명세 · 위치 | 바꾼 뒤의 서술 |
|---|---|
| 58 · 2-2 고정 사본 행 | `.harness/bin/` · `.harness/lib/` · `.harness/templates/` 아래 파일 전부와 `.harness/VERSION` |
| 58 · 5-2 대조 표와 그 아래 목록 | 4-4 의 짝. 다름은 해시가 다른 파일, 한쪽에만 있는 파일, `.harness/bin/` · `.harness/lib/` · `.harness/templates/` 에서 짝이 없는 파일 |
| 58 · 11-1 `install_registered()` 행 | 지우는 것에 `.harness/lib` |
| 58 · 11-4 install 행 | 바꿀 경로에 `.harness/lib` |
| 61 · 8 판정 함수 불러오기 | `src/test/cli_loader.py` 로 불러 직접 부른다 |
| 64 · 8 전체 | 지표 집계와 세션 가져오기는 `src/harness/metrics/`(`spans.py` · `sessions.py`)가 갖고 `metrics/` 밖의 하네스 모듈을 불러오지 않는다. 설정 해석(`METRICS_DEFAULTS` · `metrics_cfg`)은 `src/harness/config/`, 명령은 `src/harness/commands/metrics.py` 다. 배치와 바이트코드는 이 명세가 정한다 |
| 64 · 12-2 "설치본의 지표 모듈" · "소스 리포의 지표 모듈" | 이 명세 7-2 · 7-3 을 가리키는 한 줄 |
| 96 · 1-2 부르는 쪽 표의 CLI 행 | `src/harness/home/clone_key.py` 가 `TEMPLATES / "managed" / "script" / "_clone_key.py"` 를 `importlib` 로 불러온다. 바이트코드는 이 명세 5절을 따른다 |
| 96 · 3-1 표의 `.` 으로 시작하는 항목 | 예에 `.cache/`(바이트코드 캐시) |

### 8-3. 프로젝트 문서

`.ai/project/review-checks.md` 의 생성 파일 점검 줄은 `src/harness/render/plan.py` 의 `plan()` 을 가리킨다.

## 9. 보호 문서 개정 범위

분해의 task 하나가 이 범위 안에서 고친다. 고친 뒤 render 해서 `.ai/AI_AGENT.md` 를 다시 만든다.

`.ai/project/architecture.md`:

| 위치 | 문안 |
|---|---|
| "구성 요소" 의 `src/bin/harness` 항목 | 두 항목으로 바꾼다. ① `src/bin/harness` — 진입 스크립트. 바이트코드 위치와 패키지 경로를 정하고 `harness.cli.main()` 을 부른다. 소스 리포 · Homebrew(`libexec/bin/harness`) · 고정 사본(`.harness/bin/harness`)이 같은 파일이다 ② `src/harness/` — CLI 패키지. 설정을 읽어 검증하고(`config/`), 생성물을 만들고(`render/`), 검사하고(`check`), 점검하고(`doctor`, `readiness/`), 설정을 고치고(`set` · `steps` · `checks`), 프로젝트 문서 · 메모를 쓰고(`write-doc`), Doctor 조치를 돌고(`fix`), 절차를 띄우고(`run`), 지표를 집계한다(`metrics`, `metrics/`). 명령마다 `commands/<명령>.py` 에 진입 함수가 있고, 여러 명령이 쓰는 코드는 공용 모듈에 있다. `cli.py` 가 명령을 가르고 고정 사본으로 넘긴다. doctor 는 점검 결과를 항목 목록으로 모으고 텍스트 · JSON 으로 그린다. `status` 는 그 목록을 쓴다. python3 표준 라이브러리만 쓴다 |
| "구성 요소" 의 기기 단위 상태 항목 | 끝에 더한다: 등록부 최상위의 `.cache/pycache/`(CLI 의 바이트코드 캐시 — 지워도 된다) |
| "구성 요소" 의 `src/test/render-test.sh` 항목 | 끝에 더한다: `src/test/unit/` 은 CLI 패키지의 Python 단위 테스트(`unittest`)다. 소스 리포에서만 돌고 대상 리포로 가지 않는다 |
| "신뢰 경계" | 새 항목: CLI 의 바이트코드는 등록부 아래 `.cache/pycache/`(0700)에 둔다 — 그 아래 바이트코드는 CLI 가 실행하는 코드다. 리포에는 `__pycache__` 를 남기지 않는다 |
| "새 코드를 둘 곳" 의 새 생성 파일 | `src/harness/render/plan.py` 의 `plan()` 에 등록한다. 어느 설정 키가 어느 파일에 닿는지 기록하는 유일한 자리다 |
| "새 코드를 둘 곳" 의 새 설정 키 | `src/templates/harness.toml` 의 주석과 기본값, `src/harness/config/load.py` 의 `validate()` · `src/harness/render/derive.py` 의 `derive()`, README 의 "harness.toml 이 정하는 것" 표. UI 는 `harness schema` 와 `src/ui/lib/fields.js` 가 그것을 그린다 |
| "새 코드를 둘 곳" 의 새 CLI 명령 | `src/harness/commands/__init__.py` 의 `COMMANDS` 표 한 줄과 `src/harness/commands/<명령>.py`(`-` 는 `_`)의 `cmd_<명령>()`. 다른 명령과 함께 쓰는 코드는 명령 모듈이 아니라 공용 모듈에 둔다. 이름 뒤의 인자를 스스로 해석하는 명령은 `COMMANDS` 항목의 통과 표시를 `True` 로 둔다. 프로젝트에 고정된 버전이 답해야 하면 `src/harness/cli.py` 의 `DELEGATES` 에도 넣는다 |
| "새 코드를 둘 곳" 의 지표 코드 | 지표 집계 · 세션 가져오기 코드 → `src/harness/metrics/` (리뷰 루프 파이썬 서술은 그대로) |
| "새 코드를 둘 곳" 의 새 회귀 테스트 | 끝에 더한다: CLI 패키지의 내부 로직은 `src/test/unit/test_<대상>.py` |
| "계층과 의존 방향" 의 첫 항목 | `src/templates/` 는 아무것도 import 하지 않는다. CLI 패키지가 읽고, 결과가 대상 리포에 놓인다 |
| "계층과 의존 방향" | 새 항목: CLI 패키지 안에서는 `cli` → 명령 모듈(실행할 하나) → 공용 모듈 방향으로만 부른다. 명령 모듈끼리 부르지 않고, 공용 모듈은 `cli` · `commands` 를 부르지 않는다. `base` · `text` 가 바닥이고 `metrics/` 는 다른 하네스 모듈을 부르지 않는다. `[verify]` 의 "CLI 패키지 의존 방향" 이 검사한다 |
| "검사하지 않는 것" 의 한 파일 항목 | 지운다 |
| "검사하지 않는 것" 의 고정 사본 항목 | 괄호를 `.harness/bin` · `.harness/lib` · `.harness/templates` 로 |
| "검사하지 않는 것" | 새 항목: 프로젝트 `.gitignore` 가 `lib/` · `bin/` 처럼 이름만 적은 규칙으로 모든 깊이의 디렉터리를 무시하면 고정 사본 일부가 커밋되지 않는다. install 과 doctor 는 이것을 보지 않는다 |

`.ai/project/glossary.md`:

| 위치 | 문안 |
|---|---|
| "용어" 의 `소스 리포` | 이 리포. `src/bin/harness`(진입 스크립트) · `src/harness/`(CLI 패키지) · `src/templates/` 를 갖고, 자기 자신은 고정하지 않고 자기 것으로 돈다 |
| "용어" 의 `고정(pin)` | 끝에 더한다: 사본은 진입 스크립트(`.harness/bin/harness`) · CLI 패키지(`.harness/lib/harness/`) · 템플릿(`.harness/templates/`) · `VERSION` 이다 |
| "용어" 새 행 `진입 스크립트` | `bin/harness`. 바이트코드 위치와 패키지 경로를 정하고 `harness.cli.main()` 을 부르는 실행 파일. 소스 리포 `src/bin/harness`, 고정 사본 `.harness/bin/harness` |
| "용어" 새 행 `CLI 패키지` | 하네스 로직을 담은 Python 표준 라이브러리 패키지 `harness`(`src/harness/`, 고정 사본 `.harness/lib/harness/`) |
| "용어" 새 행 `명령 모듈` · `공용 모듈` | 명령 모듈은 명령 하나의 진입 함수 `cmd_<명령>()` 을 갖는 `src/harness/commands/<명령>.py`. 공용 모듈은 여러 명령이 쓰는 CLI 패키지의 나머지 모듈이고 명령 모듈을 부르지 않는다 |
| "용어" 새 행 `통과 명령` | 명령 표(`COMMANDS`)에 통과 표시가 있는 명령. 이름 뒤의 인자를 공용 옵션(모든 명령이 함께 쓰는 `--target` · `--json` 등)으로 해석하지 않고 순서 · 내용 그대로 받는다. 이름 앞의 `--target DIR`, 또는 이름 바로 뒤의 `--target DIR` 하나를 하네스 루트로 읽는다 (`harness [--target DIR] <명령> <인자…>`) |
| "폐기된 별칭" 새 행 | `src/bin/harness_metrics.py` · `.harness/bin/harness_metrics.py` (지표 모듈) → `src/harness/metrics/` · `.harness/lib/harness/metrics/` |
| "폐기된 별칭" 새 행 | `src/bin/harness` (명령 전부를 담은 CLI 파일) → 진입 스크립트 `src/bin/harness` 와 CLI 패키지 `src/harness/` |

`.ai/project/testing.md`:

| 위치 | 문안 |
|---|---|
| "외부 의존을 어떻게 다루나" 의 등록부 줄 | "설치 등록부는 `HARNESS_HOME` 으로 임시 위치에 두고" 뒤에 "(CLI 의 바이트코드 캐시도 그 아래다)" |
| "외부 의존을 어떻게 다루나" 의 소스 트리 복제 줄 | 끝에 더한다: `src/` 에서 `ui/` · `test/` · `__pycache__` 를 뺀 전부를 복제한다. CLI 를 이루는 파일을 케이스마다 적지 않는다 |
| "무엇을 어느 수준으로 검증하나" | 새 항목: CLI 내부 함수를 프로세스 안에서 부르는 케이스는 `src/test/cli_loader.py` 로 불러온다 — 이름을 정의한 모듈을 찾아 주므로 모듈 배치가 바뀌어도 케이스가 그대로다. 모듈 전역을 바꿔 끼울 때는 그 전역을 쓰는 함수를 정의한 모듈에 한다 |
| "무엇을 어느 수준으로 검증하나" | 새 항목: CLI 패키지(`src/harness/`)의 내부 로직 — 셸 테스트로는 하나씩 볼 수 없는 것 — 은 `src/test/unit/test_<대상>.py` 의 Python 단위 테스트(표준 라이브러리 `unittest`)로 본다. CLI 를 하위 프로세스로 띄우지 않고 패키지 모듈을 불러 함수를 부르며, 외부 명령은 그것을 부르는 함수를 바꿔 끼운다. 소스 리포에서만 돌고(`[verify]` 의 "Python 단위 테스트", `cd src && python3 -B -m unittest discover -s test/unit`) 대상 리포로 가지 않는다. 셸 테스트(`render-test.sh` · `script/test-*.sh`)는 외부 계약(인자 · 표준 출력 · 종료 코드)을 본다 |

`.ai/project/scope.md` 는 바뀌지 않는다 — 인접 모듈 항목("이 리포의 `src/` 아래를 `libexec` 에 넣는다")이 그대로 맞다.

## 10. 결정 기록

결정 기록: 하네스 로직은 Python 표준 라이브러리 패키지 하나에 둔다 (분해에서 작성)

## 11. 릴리스 전제 — Homebrew 포뮬러

포뮬러(`willjsw/homebrew-harness` 의 `Formula/harness.rb`)는 `src/bin` · `src/templates` · `src/ui` 를 이름으로 골라
`libexec` 에 넣는다. 그대로면 `src/harness/` 가 깔리지 않아, 이 명세의 변경이 든 `main` 을 받은 전역 CLI 는 모든 명령에서
2-2 의 `error:` 로 멈춘다. 전역 CLI 를 부르는 UI 도 멈춘다. 고정 사본으로 도는 훅 · 검증 일괄 · CI 는 `.harness/bin/harness`
를 직접 부르므로 영향이 없다.

| 항목 | 내용 |
|---|---|
| 바꿀 것 | `libexec` 아래에 `bin/` · `templates/` · `ui/` 와 같은 깊이로 `harness/` 를 둔다(`libexec/harness/`). `src/harness/` 가 없는 커밋에서도 설치가 성공한다. `bin` 링크와 `test do` 는 그대로다. 포뮬러 머리 주석의 배치 설명을 함께 고친다 |
| 누가 | 사람이 탭 리포에서 한다. 이 리포의 task 가 아니다 — 인접 모듈의 책임이고, 리포 밖 파일은 고치지 않는다 |
| 언제 | 탭 리포의 변경이 들어가고 바뀐 포뮬러가 이 변경 전 · 뒤 두 트리 모두에서 설치되는 것을 확인한 뒤에, 이 명세의 변경이 든 `develop` 을 `main` 에 머지한다. `main` push 가 곧 배포 단위다(`.github/workflows/harness-verify.yml` 의 release) |

## 12. 한계

- 프로젝트 `.gitignore` 가 `lib/` 처럼 이름만 적은 규칙을 가지면 `.harness/lib/` 가 커밋되지 않는다. 그 리포를 받은 쪽의
  고정 사본은 2-2 의 `error:` 로 멈춘다. `bin/` 규칙이면 `.harness/bin/` 이 같은 이유로 커밋되지 않는다. install 과 doctor 는
  이것을 보지 않는다
- 캐시는 정리하지 않는다. 리포 · worktree 를 옮기거나 지워도 그 경로의 항목이 남는다
- 캐시에는 하네스 패키지와, 진입 뒤에 처음 불러온 표준 라이브러리 모듈의 바이트코드가 Python 경로와 버전마다 쌓인다.
  그 Python 의 첫 실행은 그 모듈들을 컴파일한다
- 등록부 루트가 없는 동안(첫 install 전)은 바이트코드를 쓰지 않고 실행마다 컴파일한다
- 경로로 불러오는 관리 스크립트 모듈(`_clone_key.py` · 대상 리포의 `metric.py`)이 스스로 바이트코드 쓰기를 끄면, 같은 실행에서
  그 뒤에 처음 불러오는 모듈은 캐시되지 않는다
- 캐시 디렉터리가 이미 있으면 권한을 고치지 않는다
- 진입 스크립트를 거치지 않고 패키지를 불러오는 쪽(테스트 로더)에는 접두 경로가 없다. 로더는 바이트코드 쓰기를 끄고 불러온다
- 3.11 미만 Python 의 안내는 진입 스크립트의 문법 제약에 기댄다. 회귀 테스트는 3.11 미만 Python 을 돌리지 않는다
