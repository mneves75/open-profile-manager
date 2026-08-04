# Project status

## Current release line

Version 0.1.2 is the current source line and release candidate. Version 0.1.1 remains the latest immutable, signed, notarized, and stapled [GitHub Release](https://github.com/mneves75/open-profile-manager/releases/tag/v0.1.1).

## Scope

- Shared local profile registry
- Codex CLI launching and official login/logout delegation
- Read-only account and rate-limit status
- Native macOS profile manager
- Static GitHub Pages product site and deterministic Remotion product videos
- Automatic native app localization for `en-US` and `pt-BR`
- Per-profile Finder launchers
- Developer ID signing, Apple notarization, and immutable GitHub Release workflow

## Non-goals

- Automatic quota-based account rotation
- Credential sharing or cloud synchronization
- Bundling or modifying OpenAI applications
- Windows or Linux GUI support in 0.1.x

## Release evidence

The 0.1.2 candidate adds the graphite native-app redesign, three privacy-safe product videos, and the responsive public site. Its pre-production review removes account email from the native human-readable UI, adds npm dependency monitoring, gates web/video sources before Pages deployment, and keeps secret scanning focused on repository source.

Version 0.1.1 fixes interactive terminal ownership for `run`, `login`, and `logout`, adds a PTY integration regression, and centralizes bounded concurrent status reads in `ProfileCore`. The two-profile release benchmark improved from a 1,642 ms median to 788 ms, while inexpensive commands did not regress materially.

Tag `v0.1.1` resolves to release commit `c5754b1`. Stable Xcode 26.6 checks, 54 tests, the Xcode 27 beta compatibility build/tests, remote CI/CodeQL, secret scans, Apple notarization, Gatekeeper, stapling, redownloaded checksums, GitHub asset attestations, and a launch from the public ZIP under an isolated home all passed. See [the security audit](docs/SECURITY_AUDIT.md) for evidence.
