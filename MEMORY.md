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

- Version 0.1.2 is the current source line and release candidate; 0.1.1 remains the latest published release.
- The 0.1.2 candidate adds a graphite native-app redesign, three Remotion product videos, a static GitHub Pages product site, and pre-production privacy/supply-chain hardening.

## Project environment

- Native macOS 15+ Swift 6 package; no iOS, Android, React Native, or Argent-compatible target. A dependency-free static product site lives in `docs/`, and Remotion authoring tools live in `video/`.
- Build and verification entry points are `swift build`, `swift test --parallel`, `Scripts/check.sh`, `Scripts/package_app.sh`, and `Scripts/security-check.sh`.
- `version.env` is the packaging version source; `swift-argument-parser` 1.8.2 is the sole pinned package dependency.

## Verified state

- Fifty-four tests pass under Xcode 26.6, including PTY process replacement, exec failure/NUL handling, concurrent ordered status reads, GUI error-interpolation coverage, descriptor-relative and ACL-aware registry privacy, firmlink-aware profile-directory isolation, persisted-invariant validation, private launcher publication, bounded plist inspection, descriptor-safe app-server writes, system/per-user app discovery, symlink-safe diagnostics, and hostile protocol output. Xcode 27 beta also builds and passes all 54 tests.
- The native app contains 131 complete keys in both `en-US` and `pt-BR`; macOS preference selection and unsupported-language fallback were proven against a signed package, and isolated native renders covered the main profile and editor layouts in both languages.
- The 0.1.2 candidate security review has no open confirmed findings. The native UI omits account email, npm dependencies are monitored, web/video validation gates Pages deployment, local secret scans are source-scoped and clean, npm audit is clean, and GitHub reports zero open Dependabot, CodeQL, or secret-scanning alerts.
- Version 0.1.1 is published from commit `c5754b1` as a Developer ID-signed, notarized, stapled, immutable GitHub Release with verified ZIP, dSYMs, SPDX SBOM, checksums, and attestations.
- Local CLI, GUI, Finder-launcher, signing, and two-profile isolation flows passed without retaining account identifiers in the repository.
- Release-mode `status --all` with two configured profiles improved from a 1,642 ms median to 788 ms at load averages 5.63/6.20/7.09; `--version`, profile list, doctor, and `run ... --version` did not regress materially.
- The public 0.1.1 ZIP was downloaded, signature/staple verified, and launched under an isolated `CFFIXED_USER_HOME` before release closeout.
