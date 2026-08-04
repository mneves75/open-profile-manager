# Project status

## Current release line

Version 0.1.1 — published as an immutable, signed, notarized, and stapled [GitHub Release](https://github.com/mneves75/open-profile-manager/releases/tag/v0.1.1).

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

## Release evidence

Version 0.1.1 fixes interactive terminal ownership for `run`, `login`, and `logout`, adds a PTY integration regression, and centralizes bounded concurrent status reads in `ProfileCore`. The two-profile release benchmark improved from a 1,642 ms median to 788 ms, while inexpensive commands did not regress materially.

Tag `v0.1.1` resolves to release commit `c5754b1`. Stable Xcode 26.6 checks, 54 tests, the Xcode 27 beta compatibility build/tests, remote CI/CodeQL, secret scans, Apple notarization, Gatekeeper, stapling, redownloaded checksums, GitHub asset attestations, and a launch from the public ZIP under an isolated home all passed. See [the security audit](docs/SECURITY_AUDIT.md) for evidence.
