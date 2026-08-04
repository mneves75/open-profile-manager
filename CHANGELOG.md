# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A public, responsive GitHub Pages product site with privacy-safe launch, CLI, and native-app tutorial videos.

### Changed

- Refined the native macOS app with a clearer profile sidebar, status hierarchy, detail cards, and editor layout while preserving the existing explicit-launch workflow.

## [0.1.1] - 2026-08-04

### Fixed

- Preserve terminal ownership for interactive `run`, `login`, and `logout` sessions by replacing `opm` with Codex, with a PTY regression covering PID, foreground process group, arguments, and bidirectional input.

### Changed

- Read profile status concurrently through one bounded `ProfileCore` implementation shared by the CLI and native app, reducing the two-profile `status --all` median from 1,642 ms to 788 ms in the release benchmark.

## [0.1.0] - 2026-08-03

### Added

- Complete native macOS localization for `en-US` and `pt-BR`, selected automatically from the user's preferred system languages with an `en-US` fallback.
- A deterministic localization gate that rejects missing, obsolete, incomplete, or placeholder-incompatible catalog entries.
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
- A gated macOS release pipeline for universal Developer ID signing, keychain-backed `asc` notarization, dSYMs, SPDX SBOMs, checksums, immutable GitHub Releases, and post-download verification.

### Changed

- Human-readable status output no longer prints account email addresses; callers that explicitly request JSON retain the documented structured field.
- Native menus, views, accessibility labels, interpolated values, and GUI error messages now resolve through one localization boundary without translating profile data, paths, commands, or protocol values.

[Unreleased]: https://github.com/mneves75/open-profile-manager/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/mneves75/open-profile-manager/releases/tag/v0.1.1
[0.1.0]: https://github.com/mneves75/open-profile-manager/releases/tag/v0.1.0
