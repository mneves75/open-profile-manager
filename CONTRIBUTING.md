# Contributing

Thank you for improving Open Profile Manager.

## Development setup

```bash
Scripts/bootstrap.sh
Scripts/check.sh
```

Use Swift 6.3/Xcode 26.6 or a compatible newer stable toolchain. Keep changes focused, add tests through the `ProfileCore` interface, and use Conventional Commit messages.

## Product and security constraints

- Do not add automatic quota-based profile switching or any rate-limit circumvention.
- Do not read, decode, print, migrate, or store authentication tokens.
- Do not copy OpenAI assets, application bundles, or branding.
- Do not build shell command strings from user input.

Open a security report privately as described in [SECURITY.md](SECURITY.md), not as a public issue.

## Pull requests

Before opening a pull request:

```bash
Scripts/check.sh
Scripts/security-check.sh
Scripts/benchmark_site.sh --validate-only
```

For product-site timing changes, follow the repeatable conditions in [docs/PERFORMANCE.md](docs/PERFORMANCE.md). Describe the user-visible behavior, why the change belongs in the project, the commands you ran, and any compatibility risk with the official Codex CLI or desktop app.

## Fast local verification

Select Node 24 from `.nvmrc` and npm 11 before bootstrap. Bootstrap installs the locked video dependencies and the local lint hook. Run `npm ci --prefix video` again when `video/package-lock.json` changes; verification reuses that installation. CI installs from the lockfile before running the same gate.

For Swift changes, start with `swift test --filter ProfileCoreTests` (or the affected test). For video source, use `npm --prefix video run lint`; for the website, use `Scripts/check_web_video.sh --site-only`. Run `Scripts/check.sh` before committing. `Scripts/launch.sh` always packages current debug source before opening the app.

## Isolated native QA and debugging

Build without replacing your installed app:

```bash
Scripts/package_app.sh debug
Scripts/test_packaged_app.sh "build/Open Profile Manager.app"
```

The packaged smoke check uses a temporary private home and fake Codex executable for terminal tests. It proves bundled version parity, terminal ownership/exit status, and creation of a real on-screen window. It does not prove every UI flow or compatibility with an authenticated upstream app.

For interactive QA, create a dedicated empty home and launch the exact binary:

```bash
qa_home=$(mktemp -d "${TMPDIR:-/tmp}/opm-qa.XXXXXX")
CFFIXED_USER_HOME="$qa_home" "build/Open Profile Manager.app/Contents/MacOS/OpenProfileManager"
```

Use only synthetic profiles under that directory. Check empty state, add, validation errors, edit, selection, copy command, removal confirmation/cancel, and close/reopen. Repeat with `-AppleLanguages '(pt-BR)'` and `'(en-US)'`; check keyboard focus and the minimum window size. Quit that instance before deleting the temporary QA directory. Do not log in or point this fixture at a real Codex home.

For a breakpoint in the same isolated build:

```bash
CFFIXED_USER_HOME="$qa_home" lldb -- "build/Open Profile Manager.app/Contents/MacOS/OpenProfileManager"
```

Use `breakpoint set --name main` and `run`, or set a source breakpoint in Xcode. No production debug endpoint or credential export is needed. Debugger attachment may require macOS developer-tool permission; window inspection requires the UI tool's existing accessibility permission.

Keep one writer and one Swift build/package process per checkout. When separate worktrees are explicitly authorized, run bootstrap in each and keep `.build`, `build`, and synthetic QA homes local to that checkout. Identify the owning process before terminating a stuck build or app; do not kill shared process names. Existing scripts and isolated homes cover this workflow without an additional worktree manager.
