# CLAUDE.md

Read [AGENTS.md](AGENTS.md) first. It contains the product safety contract, architecture, and required checks.

The no-backward-compatibility, simplicity, layered-growth, modularity, dependency-reuse, and long-term architecture rules are canonical in [AGENTS.md](AGENTS.md#engineering-rules) and apply to every change. They are linked here rather than duplicated so the repository retains one source of truth.

## Project map

- Shared behavior: `Sources/ProfileCore`
- CLI: `Sources/opm`
- macOS GUI and localization adapter: `Sources/OpenProfileManager`
- Localization completeness gate: `Scripts/check_localizations.swift`
- Tests: `Tests/ProfileCoreTests` and `Tests/OpenProfileManagerTests`
- Distribution automation: `Scripts` and `docs/RELEASING.md`
- Architecture and security decisions: `docs`

The supported baseline is macOS 15 or newer with Swift 6.3/Xcode 26.6. The official `codex` CLI must be installed separately. GUI launch support is a compatibility adapter for an independently installed ChatGPT/Codex app and may require updates when that app changes. Read `docs/SECURITY_AUDIT.md` before changing filesystem, process, or distribution boundaries.
