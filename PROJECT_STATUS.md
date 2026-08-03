# Project status

## Current release line

Version 0.2.0 — source line ready; localized package verified and the existing local installation workflow retained.

## Scope

- Shared local profile registry
- Codex CLI launching and official login/logout delegation
- Read-only account and rate-limit status
- Native macOS profile manager
- Automatic native app localization for `en-US` and `pt-BR`
- Per-profile Finder launchers
- Developer-signing workflow with a closed notarization gate

## Non-goals

- Automatic quota-based account rotation
- Credential sharing or cloud synchronization
- Bundling or modifying OpenAI applications
- Windows or Linux GUI support in 0.2.x

## Release blocker

The public source is available at [github.com/mneves75/open-profile-manager](https://github.com/mneves75/open-profile-manager). A downloadable macOS binary requires a valid `Developer ID Application` identity and successful Apple notarization.

The source, package, signing, diagnostics, two-profile isolation, and native-window flows passed the documented local verification without recording account identifiers. See [the security audit](docs/SECURITY_AUDIT.md) for the evidence and residual distribution limitation.
