# Architecture

Open Profile Manager has one domain module and two thin adapters:

```text
                 +----------------------+
                 |     ProfileCore      |
                 | validation + store   |
                 | status + launch plan |
                 +----------+-----------+
                            |
                 +----------+-----------+
                 |                      |
             +---v---+          +-------v--------+
             |  opm  |          | SwiftUI macOS  |
             |  CLI  |          | AppKit/SwiftUI |
             +-------+          +----------------+
```

`ProfileCore` is the deep module. Its interface accepts validated profile operations and returns values or typed errors. It hides JSON persistence, filesystem permissions, child-process lifecycle, Codex app-server JSONL, application discovery, and launcher bundle construction.

The CLI and GUI are adapters at that seam. They may format or localize results, but they must not reimplement profile rules or construct launch commands themselves.

The public website and product videos are documentation artifacts, not application adapters. `docs/` is a static GitHub Pages artifact with no backend or runtime dependency installation; `video/` contains deterministic Remotion authoring sources. Neither surface imports `ProfileCore`, handles profiles, or receives user data.

The GUI resolves every user-facing string through its native bundle. `en-US` is the development localization and fallback; `pt-BR` is selected automatically when it is the user's preferred supported macOS language. Typed `ProfileCore` errors are localized only after they cross into the GUI adapter, while user data, paths, CLI commands, and stable protocol values remain unchanged. `Scripts/check_localizations.swift` keeps source keys, both translations, and format placeholders in sync.

## Data model

A profile contains a stable lowercase identifier, a display name, an absolute `CODEX_HOME`, and an optional absolute GUI data directory. Authentication material is deliberately absent. The official Codex runtime owns credentials inside the selected home. The registry rejects equal or nested effective storage paths so two profiles cannot accidentally share authentication or desktop state.

The registry lives in the user's Application Support directory. Private-path traversal and registry I/O are descriptor-relative, so a concurrent symlink replacement cannot redirect an already validated operation. Storage identity uses macOS's no-firmlink physical path, preserving nonexistent suffixes, so Data-volume aliases cannot bypass isolation. Writes use a unique temporary sibling, durability syncs, and `renameat`. Managed directories and registry files require current-user ownership, exact owner-only modes, and no unsafe macOS extended ACLs; traversed ancestors must also be trusted and non-writable by other users.

## Launch behavior

- CLI `run`, `login`, and `logout` replace the `opm` process image with the discovered `codex` binary and its isolated environment. Keeping the same PID and foreground process group preserves terminal job control, signals, and the Codex exit status.
- GUI launch executes `/usr/bin/open` directly with a new-instance request, explicit `CODEX_HOME` forwarding, the independently installed app path, and a per-profile `--user-data-dir`.
- Generated Finder launchers call `opm app launch <profile-id>`. They contain no credentials.
- The canonical installed ChatGPT/Codex app remains the update owner. Launchers reference it rather than copying it, so official in-app updates continue normally.

Status reads remain child processes because `opm` must exchange bounded JSONL with each app-server and aggregate the result. `ProfileCore` loads the registry once per batch, preserves requested order, and runs at most four app-server reads concurrently; both adapters use that same implementation.

## Compatibility

`CODEX_HOME` and `account/rateLimits/read` are documented Codex interfaces. Passing a per-profile Chromium data directory to the macOS desktop app is an empirical compatibility adapter, not a documented OpenAI contract. `opm doctor` detects breakage and reports a remediation instead of mutating the official app.
