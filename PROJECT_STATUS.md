# Project status

## Current release line

Version 0.1.4 is the current source line and latest immutable, signed, notarized, and stapled [GitHub Release](https://github.com/mneves75/open-profile-manager/releases/tag/v0.1.4). The next unreleased target is 0.1.5.

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

Version 0.1.4 hardens untrusted JSON and property-list scalar parsing, closes the unterminated-final-record JSONL limit bypass, and updates Nano ID to 3.3.18 for CVE-2026-67213. Tag `v0.1.4` resolves to release commit `c348ab1`. Stable Xcode 26.6 passed the complete gate with 59 tests; CI, CodeQL, Gitleaks, TruffleHog, npm audit, and the privacy-manifest check passed. Apple accepted notarization submission `eae747a3-52df-4181-b589-db1db88c3f86`; Developer ID verification, universal architecture checks, stapling, Gatekeeper, matching dSYMs, SPDX SBOM, checksums, GitHub asset attestations, immutable publication, and verification of the redownloaded and locally installed release all passed.

Version 0.1.3 removes the native first-window delay, hardens official desktop-app discovery with a valid Apple-signature requirement pinned to the official Team ID and bundle identifier, defines repeatable site performance evidence, shrinks the hero LCP asset, updates video dependencies, and keeps status batch refreshes to one registry load per user action.

Tag `v0.1.3` resolves to release commit `86f0199`. Stable Xcode 26.6 checks, 56 tests, CI/CodeQL, secret scans, Apple notarization submission `e042f594-beda-4191-8a5b-75f912daf649`, Gatekeeper, stapling, redownloaded checksums, and GitHub attestations for the universal ZIP, dSYMs, SPDX SBOM, and checksum manifest all passed.

At the maximum 128 profiles, registry validation improved from 7,145 ms to 28 ms p95. The preferred hero asset fell from 1,511,821 bytes to 9,156 bytes. Chromium file-URL fallback measurements at load averages 5.13/5.98/12.73 produced desktop p95 FCP/LCP of 56/60 ms and mobile 48/56 ms. That does not satisfy the strict below-50 ms p95 gate; the primary loopback harness was blocked by the execution environment's browser/server network isolation, so the repository records the failed target instead of relabeling the metric.

The signed Release app's repeatable process-to-on-screen-window proxy measured 225.625 ms p50 and 357.221 ms p95 at load averages 4.88/5.98/8.24. The native process/window surface therefore has a measured platform floor well above 50 ms even after deleting the avoidable 500 ms source delay.

Version 0.1.2 adds the graphite native-app redesign, three privacy-safe product videos, and the responsive public site. Its review removes account email from the native human-readable UI, adds npm dependency monitoring, gates web/video sources before Pages deployment, and keeps secret scanning focused on repository source.

Version 0.1.1 fixes interactive terminal ownership for `run`, `login`, and `logout`, adds a PTY integration regression, and centralizes bounded concurrent status reads in `ProfileCore`. The two-profile release benchmark improved from a 1,642 ms median to 788 ms, while inexpensive commands did not regress materially.

Tag `v0.1.2` resolves to release commit `e4470b4`. Stable Xcode 26.6 checks, 54 tests, remote CI/CodeQL, secret scans, Apple notarization, Gatekeeper, stapling, redownloaded checksums, GitHub asset attestations, and a launch from the public ZIP under an isolated home all passed. See [the security audit](docs/SECURITY_AUDIT.md) for evidence.
