# Project memory

## Goal

Ship an unofficial MIT-licensed, local-first profile manager for Codex CLI and the macOS ChatGPT/Codex app, with one shared core and explicit user-selected profiles.

## Decisions

- Swift 6.3 package with `ProfileCore`, `opm`, and a native AppKit/SwiftUI app: one language, one domain implementation, straightforward universal macOS packaging.
- macOS 15 minimum: modern SwiftUI/Observation while retaining a wider install base than macOS 26-only APIs.
- Apple `swift-argument-parser` is the only external dependency and is pinned exactly.
- Status uses the documented local Codex app-server protocol; no direct authentication-file access.
- Desktop launching references the official installed app and uses isolated profile data. It is explicitly treated as a compatibility adapter.
- Quota-driven automatic switching is out of scope because it risks service-limit circumvention.
- Profile isolation removes the official process-global Codex access/API token and SQLite-home overrides before applying the selected `CODEX_HOME`; provider-specific variables remain intact.

## Active work

- The 0.1.0 source line implements complete `en-US`/`pt-BR` native app localization. Public binary distribution remains gated as documented below.

## Project environment

- Native macOS 15+ Swift 6 package; no iOS, Android, React Native, web, or Argent-compatible target.
- Build and verification entry points are `swift build`, `swift test --parallel`, `Scripts/check.sh`, `Scripts/package_app.sh`, and `Scripts/security-check.sh`.
- `version.env` is the packaging version source; `swift-argument-parser` 1.8.2 is the sole pinned package dependency.

## Verified state

- Fifty-one tests pass, including GUI error-interpolation coverage plus concurrency, descriptor-relative and ACL-aware registry privacy, firmlink-aware profile-directory isolation, persisted-invariant validation, private launcher publication, bounded plist inspection, descriptor-safe app-server writes, system/per-user app discovery, symlink-safe diagnostics, and hostile protocol output.
- The native app contains 131 complete keys in both `en-US` and `pt-BR`; macOS preference selection and unsupported-language fallback were proven against a signed package, and isolated native renders covered the main profile and editor layouts in both languages.
- The 0.1.0 pre-production security review found no open confirmed findings; Gitleaks, TruffleHog, dependency resolution, privacy-manifest validation, and remote Dependabot/CodeQL/secret-scanning state were clean.
- The initial 0.1.0 source is available on `main` at `github.com/mneves75/open-profile-manager`; no `v0.1.0` tag or GitHub Release exists yet.
- Local CLI, GUI, Finder-launcher, signing, and two-profile isolation flows passed without retaining account identifiers in the repository.
- A public binary remains blocked until the maintainer can complete Developer ID signing and Apple notarization.
