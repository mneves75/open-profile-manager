# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.7] - 2026-09-04

### Changed

- Remove unused core/CLI helpers, duplicate native result types, obsolete website styles and dormant video options while preserving current behavior.
- Move video dependency installation to bootstrap/CI, document isolated QA and debugging, and consolidate agent instructions for current Fable 5.1 and GPT-6 Astra workflows.
- Support numbered beta GitHub prereleases with the same notarization and redownload verification as production, without replacing the latest stable release.

### Fixed

- Rebuild the debug bundle before local launch and verify child exit-code propagation in terminal integration checks.

### Security

- Update the video toolchain's fast-uri override to 3.1.6 to resolve the reported URI-normalization advisories within the existing major version.

## [0.1.6] - 2026-08-26

### Fixed

- Use the compact unified toolbar in the native app so window controls no longer reserve an oversized header above profile content.

## [0.1.5] - 2026-08-25

### Changed

- Exercise the downloaded bundle's CLI terminal behavior and visible native-app startup under an isolated home before publication.

### Security

- Require TruffleHog for releases and block verified, unknown, or unverified secret candidates pending maintainer review.

## [0.1.4] - 2026-08-25

### Fixed

- Reject non-Boolean authentication, credit, and managed-launcher markers; reject fractional, Boolean, and overflowing app-server integer fields.
- Enforce the JSONL record-count limit when the final app-server record is not newline-terminated.

### Security

- Updated the transitive Nano ID authoring dependency to 3.3.18, closing CVE-2026-67213 without crossing the dependency's expected major version.

## [0.1.3] - 2026-08-11

### Added

- Added repeatable product-site and signed native-launch performance harnesses covering browser vitals, sitemap assets, captions, transcripts, favicon, and process-to-window timing.

### Changed

- Removed the native app's fixed first-window launch delay, made the profile editor adapt to smaller windows, and cut duplicate registry validation from batch status refreshes.
- Reworked the product site install path around the latest notarized release and reduced the hero LCP asset from a 1.51 MB PNG to a 9 KB WebP source with PNG fallback.
- Pinned the video authoring runtime to Node 24/npm 11 and updated Remotion dependencies to clear high-severity authoring-tool advisories.

### Security

- Require discovered ChatGPT/Codex desktop apps to have a valid Apple signature matching the official OpenAI bundle identifier and Team ID before launch.
- Expanded local and CI gates for web/video validation, ast-grep fixtures, version drift, and dependency auditing.

## [0.1.2] - 2026-08-04

### Added

- A public, responsive GitHub Pages product site with privacy-safe launch, CLI, and native-app tutorial videos.

### Changed

- Refined the native macOS app with a clearer profile sidebar, status hierarchy, detail cards, and editor layout while preserving the existing explicit-launch workflow.
- Removed account email addresses from the native app's human-readable status surface; explicit CLI JSON retains the documented structured field.

### Fixed

- Resolve packaged app and CLI binaries through SwiftPM's reported build directory so clean local installations work across current toolchains.

### Security

- Added automated npm dependency monitoring and blocking web/video validation to pull requests and Pages deployment.
- Scoped TruffleHog to repository source instead of generated dependency and build trees, eliminating binary scan errors without weakening tracked-source or full-history secret checks.

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

[Unreleased]: https://github.com/mneves75/open-profile-manager/compare/v0.1.6...HEAD
[0.1.6]: https://github.com/mneves75/open-profile-manager/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/mneves75/open-profile-manager/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/mneves75/open-profile-manager/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/mneves75/open-profile-manager/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/mneves75/open-profile-manager/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/mneves75/open-profile-manager/releases/tag/v0.1.1
[0.1.0]: https://github.com/mneves75/open-profile-manager/releases/tag/v0.1.0
