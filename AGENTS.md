# AGENTS.md

Open Profile Manager is an unofficial, local-first profile launcher for Codex CLI and the ChatGPT/Codex macOS app.

## Product boundaries

- Never implement automatic quota-driven account rotation, quota evasion, credential sharing, or hidden fallback between accounts.
- Profile selection is always an explicit user action. Quota data is status information only.
- Never read, copy, decode, migrate, print, or persist Codex authentication tokens. Authentication remains owned by the official `codex` executable under each `CODEX_HOME`.
- Never bundle, modify, or redistribute OpenAI software or branding. Launch an independently installed official app.
- Keep the project unofficial and do not imply affiliation with or endorsement by OpenAI.

## Architecture

- `Sources/ProfileCore`: the deep module. Owns profile validation/storage, launch planning, app-server status reads, and generated launcher installation.
- `Sources/opm`: thin CLI adapter. Argument parsing and human/JSON output only.
- `Sources/OpenProfileManager`: thin native AppKit/SwiftUI adapter. No duplicated domain logic.
- `Scripts`: deterministic build, package, install, signing, and verification workflows.

## Engineering rules

- Do not preserve backward compatibility. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers: start with the smallest end-to-end product that works, then add each capability without trading working behavior for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Reuse capabilities in existing dependencies before writing custom implementations or adding packages; check their current documentation and types instead of assuming a capability is absent.
- Prefer established, well-maintained libraries when they reduce total complexity or improve reliability. Reimplement common functionality only with a clear reason.
- Make architectural decisions for the long term. Do not accept stopgaps intended to be replaced later.
- Swift 6 language mode and complete concurrency checking are mandatory.
- Do not invoke a shell for user-controlled input. Use `Process.executableURL`, explicit argument arrays, and explicit environment dictionaries.
- Treat profile identifiers, paths, app locations, app-server output, and child-process errors as untrusted input.
- Writes must be atomic. Profile directories are mode `0700`; profile/config files are mode `0600`.
- Keep the registry and child-protocol inputs explicitly bounded. Preserve the cross-process writer lock.
- Keep dependencies minimal and pinned. No telemetry or network service owned by this project.
- Add tests at the `ProfileCore` interface for every behavior change.
- Use `ast-grep` through `Scripts/lint.sh`; do not add `try!`, `fatalError`, shell interpolation, or force-casts to production code.
- Run `Scripts/check.sh` before commit. Run the security audit and autoreview before public release or push.

## Commands

```bash
swift build
swift test --parallel
Scripts/lint.sh
Scripts/check.sh
Scripts/package_app.sh
```

The current security baseline and residual distribution limitation are recorded in `docs/SECURITY_AUDIT.md`.
