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
- A future experimental CLI-only shared-session pool may let explicitly selected profiles resume one local conversation while authentication and configuration remain isolated. It must run only through `opm run`, serialize pool access, migrate transcripts only after confirmation, and fail closed on unknown Codex state layouts; see ADR-0001.

## Active work

- Version 0.1.4 is the current unreleased source line; version 0.1.3 remains the latest published release.
- Version 0.1.4 hardens untrusted app-server and launcher scalar parsing, closes the unterminated-final-record JSONL limit bypass, and resolves Nano ID to patched version 3.3.18.

## Project environment

- Native macOS 15+ Swift 6 package; no iOS, Android, React Native, or Argent-compatible target. A dependency-free static product site lives in `docs/`, and Remotion authoring tools live in `video/`.
- Build and verification entry points are `swift build`, `swift test --parallel`, `Scripts/check.sh`, `Scripts/package_app.sh`, and `Scripts/security-check.sh`.
- `version.env` is the packaging version source; `swift-argument-parser` 1.8.2 is the sole pinned package dependency.

## Verified state

- Fifty-nine tests pass under stable Xcode 26.6, including strict app-server scalar parsing, the final JSONL record bound, numeric managed-launcher marker rejection, official desktop-app signature rejection, PTY process replacement, concurrent ordered status reads, descriptor-relative and ACL-aware registry privacy, firmlink-aware profile-directory isolation, and hostile protocol output.
- The native app contains 131 complete keys in both `en-US` and `pt-BR`; macOS preference selection and unsupported-language fallback were proven against a signed package, and isolated native renders covered the main profile and editor layouts in both languages.
- The 0.1.4 pre-production security review has no open confirmed findings in the reviewed source. npm audit reports zero vulnerabilities, Gitleaks and TruffleHog are clean, and the local 0.1.4/build 6 package passes strict code-signature verification. Version 0.1.4 is not yet released.
- At 128 profiles, registry validation improved from 7,145 ms to 28 ms p95. The strict static-site below-50 ms p95 goal remains failed on this host; the file-URL fallback recorded desktop FCP/LCP 56/60 ms and mobile 48/56 ms while the primary loopback benchmark was blocked by execution-environment isolation.
- The signed 0.1.3 Release build's process-to-on-screen-window proxy measured 225.625 ms p50 and 357.221 ms p95, proving that a below-50 ms native process/window budget is invalid on the current macOS surface.
- Version 0.1.3 is published from commit `86f0199` as a Developer ID-signed, notarized, stapled, immutable GitHub Release with verified universal ZIP, dSYMs, SPDX SBOM, checksums, and attestations. Apple accepted notarization submission `e042f594-beda-4191-8a5b-75f912daf649`.
- Local CLI, GUI, Finder-launcher, signing, and two-profile isolation flows passed without retaining account identifiers in the repository.
- Release-mode `status --all` with two configured profiles improved from a 1,642 ms median to 788 ms at load averages 5.63/6.20/7.09; `--version`, profile list, doctor, and `run ... --version` did not regress materially.
- The public 0.1.3 ZIP was redownloaded and passed signature, Gatekeeper, staple, checksum, SBOM, and GitHub attestation verification before release closeout.
