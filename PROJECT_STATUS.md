# Project status

## Current release line

Version 0.1.1 — release candidate. Version 0.1.0 is the current published GitHub Release.

## Scope

- Shared local profile registry
- Codex CLI launching and official login/logout delegation
- Read-only account and rate-limit status
- Native macOS profile manager
- Automatic native app localization for `en-US` and `pt-BR`
- Per-profile Finder launchers
- Developer ID signing, Apple notarization, and immutable GitHub Release workflow

## Non-goals

- Automatic quota-based account rotation
- Credential sharing or cloud synchronization
- Bundling or modifying OpenAI applications
- Windows or Linux GUI support in 0.1.x

## Release readiness

The 0.1.1 candidate fixes interactive terminal ownership for `run`, `login`, and `logout`, adds a PTY integration regression, and centralizes bounded concurrent status reads in `ProfileCore`. The two-profile release benchmark improved from a 1,642 ms median to 788 ms, while inexpensive commands did not regress materially.

Stable Xcode 26.6 checks, 54 tests, the Xcode 27 beta compatibility build/tests, secret scans, and the local security gate pass. Publication still requires the release commit's remote CI and CodeQL runs followed by the signed, notarized release workflow. See [the security audit](docs/SECURITY_AUDIT.md) for evidence.
