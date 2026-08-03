# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-08-02

### Added

- Local profile management for isolated Codex homes.
- Explicit CLI and native macOS GUI launch flows.
- Read-only account and rate-limit status through the documented Codex app-server interface.
- Per-profile Finder launchers that continue to use the canonical, independently updated ChatGPT/Codex app.
- Developer-signed macOS packaging with an explicit notarization gate, deterministic checks, security scanning, and CI.
- Cross-process registry locking, bounded untrusted inputs, strict private-directory and registry-file checks, and a documented 0.1.0 security audit.
- English and Brazilian Portuguese localization for the native app.
- Finder-safe discovery for Codex installed under standard user, Homebrew, and system binary locations.
- Explicit `CODEX_HOME` forwarding through LaunchServices and isolated desktop data directories.
- Profile-editor validation that rejects relative paths without losing form input on save errors.
- macOS ACL-aware privacy validation, bounded GUI status concurrency, complete automatic-directory diagnostics, and atomic local upgrades.
- Symlink-safe missing-path diagnostics, late app-server output-cap enforcement, and visible GUI launch failures.
- Record-count bounds, injective launcher identities, regular-file executable discovery, and launchable-bundle validation.
- Removal of conflicting global Codex credential/state overrides, standardized-root rejection, and a directory picker aligned with private-path creation rules.
- Descriptor-relative private storage, durable registry replacement, safe ancestor validation, isolated lock naming, and rejection of overlapping Codex or GUI profile directories.
- Filesystem-aware alias and APFS firmlink handling, persisted-registry isolation validation, canonical doctor paths, and official-app discovery in both system and per-user Applications directories.
- Removal of the standard `OPENAI_API_KEY` override alongside Codex-specific credential and state overrides when launching a selected profile.
- Private Finder-launcher publication, explicit bundle modes, bounded/nonblocking property-list inspection, and fail-closed dangling-symlink handling.
- Descriptor-local `SIGPIPE` suppression for safe app-server failure when the child exits between protocol writes.
- Public-repository community health files, private vulnerability-report routing, CODEOWNERS, SHA-pinned least-privilege CI, and privacy-sanitized examples and audit records.

[Unreleased]: https://github.com/mneves75/open-profile-manager/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mneves75/open-profile-manager/releases/tag/v0.1.0
