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

- Version 0.1.3 is the current source line for performance, release, and security hardening.
- Version 0.1.3 removes a fixed native launch delay, validates official desktop-app identity before launch, adds repeatable site performance evidence, reduces the hero LCP asset, and updates web/video gates.

## Project environment

- Native macOS 15+ Swift 6 package; no iOS, Android, React Native, or Argent-compatible target. A dependency-free static product site lives in `docs/`, and Remotion authoring tools live in `video/`.
- Build and verification entry points are `swift build`, `swift test --parallel`, `Scripts/check.sh`, `Scripts/package_app.sh`, and `Scripts/security-check.sh`.
- `version.env` is the packaging version source; `swift-argument-parser` 1.8.2 is the sole pinned package dependency.

## Verified state

- Fifty-six tests pass under stable Xcode 26.6, including official desktop-app signature rejection, PTY process replacement, exec failure/NUL handling, concurrent ordered status reads, cooperative app-server cleanup, GUI error-interpolation coverage, descriptor-relative and ACL-aware registry privacy, firmlink-aware profile-directory isolation, persisted-invariant validation, private launcher publication, bounded plist inspection, descriptor-safe app-server writes, system/per-user app discovery, symlink-safe diagnostics, and hostile protocol output.
- The native app contains 131 complete keys in both `en-US` and `pt-BR`; macOS preference selection and unsupported-language fallback were proven against a signed package, and isolated native renders covered the main profile and editor layouts in both languages.
- The 0.1.3 release-candidate security review has no open confirmed findings. The native UI omits account email, official desktop-app discovery fails closed on wrong identity, npm audit reports zero vulnerabilities, local secret scans are clean, and GitHub reports zero open Dependabot, CodeQL, or secret-scanning alerts.
- At 128 profiles, registry validation improved from 7,145 ms to 28 ms p95. The strict static-site below-50 ms p95 goal remains failed on this host; the file-URL fallback recorded desktop FCP/LCP 56/60 ms and mobile 48/56 ms while the primary loopback benchmark was blocked by execution-environment isolation.
- The signed 0.1.3 Release build's process-to-on-screen-window proxy measured 225.625 ms p50 and 357.221 ms p95, proving that a below-50 ms native process/window budget is invalid on the current macOS surface.
- Version 0.1.2 is published from commit `e4470b4` as a Developer ID-signed, notarized, stapled, immutable GitHub Release with verified universal ZIP, dSYMs, SPDX SBOM, checksums, and attestations.
- Local CLI, GUI, Finder-launcher, signing, and two-profile isolation flows passed without retaining account identifiers in the repository.
- Release-mode `status --all` with two configured profiles improved from a 1,642 ms median to 788 ms at load averages 5.63/6.20/7.09; `--version`, profile list, doctor, and `run ... --version` did not regress materially.
- The public 0.1.2 ZIP was downloaded, signature/staple verified, and launched under an isolated `CFFIXED_USER_HOME` before release closeout.
