# AGENTS.md

Open Profile Manager is an unofficial, local-first launcher for the official Codex CLI and independently installed ChatGPT/Codex macOS app.

## Product boundaries

- Profile selection is explicit. Quota data is status only: no automatic rotation, quota evasion, credential sharing or hidden account fallback.
- Never read, copy, decode, migrate, print or persist Codex authentication tokens. The official `codex` executable owns authentication under each `CODEX_HOME`.
- Never bundle, modify or redistribute OpenAI software/branding, or imply affiliation or endorsement.
- Launch only desktop apps whose valid Apple signature matches the official OpenAI Team ID and bundle identifier.

## Architecture and invariants

- `Sources/ProfileCore`: validation/storage, launch plans, app-server status and Finder launchers. `Sources/opm` and `Sources/OpenProfileManager` are thin CLI/native adapters.
- `Scripts`: build/package/install/release workflows. `docs`: architecture/security references and static site. `video`: offline Remotion sources.
- Swift 6 language mode and complete concurrency checking are mandatory. Keep blocking work off the GUI's MainActor. Support macOS 15; consult bundled Apple documentation before adopting newer APIs.
- Use `Process.executableURL`, explicit argument arrays and environments; never a shell for user-controlled input. Treat identifiers, paths, app metadata and child output as untrusted.
- Preserve atomic writes, descriptor-relative I/O, cross-process writer locking, registry/protocol bounds and path isolation. Profile directories are `0700`, files `0600`, without extended ACLs.
- Prefer deletion and simple modules over compatibility layers or speculative abstractions. Reuse existing capabilities; keep dependencies minimal and pinned. No project-owned network service or telemetry.
- Preserve native `en-US`/`pt-BR` localization and English CLI/JSON contracts. Keep personal paths and account details out of public QA artifacts.

## Agent workflow

Read `PROJECT_STATUS.md`, `MEMORY.md`, relevant recent `memory/` entries, then `README.md`. For domain changes read `docs/ARCHITECTURE.md`; for filesystem/process/distribution changes read `docs/SECURITY_AUDIT.md`.

Plan substantial changes, then finish authorized implementation and verification. User instructions outrank skill procedure; name the exact conflicting instruction if blocked. No push, release, installation over user apps or branch/worktree change without authorization. Delegate independent substantial work with disjoint ownership; review returned diffs and proof. Keep one writer and one build/package operation per checkout.

Batch independent reads, give brief progress updates, preserve decisions and unfinished proof across compaction, and stop once acceptance checks pass. Keep model/effort settings in the harness. This follows current [Fable 5.1](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1) and [GPT-6 Astra](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra) guidance (checked 2026-09-04): clear scope and completion criteria, targeted edits, proportionate tests, no repeated prompting rules.

## Verification

- Setup: Node 24 (`.nvmrc`), npm 11, then `Scripts/bootstrap.sh`. Run `npm ci --prefix video` after lockfile changes; checks reuse installed dependencies.
- Focused proof: `swift test --filter <SuiteOrTest>`; terminal changes also need `swift build` and `Scripts/test_interactive_launch.sh`. Site: `Scripts/check_web_video.sh --site-only`. Video: `npm --prefix video run lint`.
- Before commit: `Scripts/check.sh`. It includes structural-rule positive controls, script contracts, localization, build/version, PTY/exit status, Swift tests and web/video checks. Rerun focused proof after fixes; do not repeat passing gates without cause.
- Domain behavior changes need `ProfileCore` regression tests; native/tooling changes need their own boundary checks. Avoid tests that merely match source text.
- `Scripts/lint.sh` enforces ast-grep, Swift formatting and shellcheck. No production `try!`, `fatalError`, force-casts or shell interpolation.
- Native QA: `Scripts/package_app.sh debug`, then `Scripts/test_packaged_app.sh "build/Open Profile Manager.app"`. Isolated-home interactive flows, LLDB and worktree isolation are in `CONTRIBUTING.md`. Window smoke alone does not prove editor or real-account behavior.
- Website changes need desktop/mobile rendered checks. Performance claims follow `docs/PERFORMANCE.md`; preserve raw evidence and report platform noise honestly.
- Run security audit and autoreview before public release/push; non-trivial edits also require autoreview at P3. Verify findings before applying fixes.

Release channels: `Scripts/release.sh --beta <positive count>` publishes a verified GitHub prerelease tagged `v<version>-beta<count>`; `Scripts/release.sh` publishes production `v<version>`. Use `version.env` and synchronize `OPMVersion.current` (the full gate checks parity). See `docs/RELEASING.md`; never tag separately from the wrapper.
