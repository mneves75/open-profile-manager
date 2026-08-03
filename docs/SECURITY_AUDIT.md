# Pre-production security audit — 0.1.0 source

Date: 2026-08-03
Scope: the complete source tree, local persistence, child-process protocol, CLI and GUI launch paths, Finder launchers, packaging scripts, dependencies, and CI configuration.

## Result

No confirmed critical-, high-, medium-, or low-severity findings remain open in the 0.1.0 source. The localization change does not alter authentication, persistence, process execution, or network boundaries. Every GUI format string is trusted catalog data, dynamic values are format arguments rather than executable input, placeholder parity is checked for both locales, and unexpected errors fail closed to a generic localized message. The downloadable public-binary gate remains intentionally closed because a `Developer ID Application` certificate and Apple notarization are not yet available; this is a release-provenance limitation, not a source-code vulnerability.

## Fixed findings

| Finding | Severity | Resolution | Evidence |
| --- | --- | --- | --- |
| Concurrent CLI processes could lose registry updates or collide with user-selected registry names | Medium | Added an owner-only cross-process `flock`, an isolated reserved lock namespace, and exclusive lock creation around every read-modify-write operation | Concurrent 20-writer and lock-namespace regression tests |
| Registry and app-server fields had no explicit size bounds | Medium | Limited the registry to 1 MiB/128 profiles; bounded JSONL bytes and records, account fields, and percentage ranges | Oversized-registry and hostile-status tests at every response stage |
| Existing or persisted profile directories could be unsafe, silently re-permissioned, reached through a symlink, or traversed through an unsafe ancestor | Medium | Directory creation and validation are descriptor-relative and reject symlinks, unexpected ownership/modes, writable ancestors, and unsafe ACLs without mutating existing paths | Directory, ancestor, symlink, and persisted-profile regression tests plus live `doctor` checks |
| An existing registry could be replaced or read without proving its owner, file type, and exact private mode | Medium | Registry I/O uses descriptor-relative operations; reads require a current-user-owned regular file with exact mode `0600`, and durable writes use a unique file plus `renameat` and directory sync | Broad-permission, FIFO, dangling-symlink, replacement, and durability-path tests |
| macOS extended ACLs could grant other local users access despite owner-only mode bits | Medium | Existing private directories, every traversed ancestor, and registry files reject unsafe extended ACLs; newly created private objects remove inherited ACLs before validation | Direct and inherited leaf/ancestor ACL regression tests plus live `doctor` checks |
| Two profiles could select overlapping Codex or GUI storage and silently share authentication state | High | Registry validation rejects equal, nested, reserved, derived, alias, and macOS firmlink-equivalent paths both during mutation and persisted-data loading | Explicit, persisted, physical-alias, firmlink, and derived-directory isolation tests |
| Process-global Codex credential or SQLite overrides could supersede the selected profile | High | CLI, GUI, login, and status plans remove `CODEX_ACCESS_TOKEN`, `CODEX_API_KEY`, `OPENAI_API_KEY`, and `CODEX_SQLITE_HOME` before setting the selected `CODEX_HOME`; ordinary provider variables remain available | Environment-isolation regression plus live status under deliberately invalid overrides |
| Display names and paths accepted terminal control characters | Low | Added byte limits and rejected control characters; the filesystem root is also rejected as a profile directory | Validation regression tests |
| Finder launchers accepted a symlinked executable and ignored signing failure | Low | Require a regular executable file and fail installation when local signing fails | Symlink regression test and live signature verification |
| Finder launcher publication trusted unsafe destinations and unbounded property lists | High | Destinations must be private, current-user-owned, symlink-free directories; bundle modes are explicit; application and managed-launcher property lists are nonblocking regular files capped at 256 KiB | Destination, mode, FIFO, oversized-file, and dangling-symlink regression tests |
| Human-readable status printed the authenticated account email | High | Default terminal output now identifies the selected profile and account type without printing the email; the field remains available only when a caller explicitly requests structured JSON | GitHub CodeQL `swift/cleartext-logging` scan and final zero-open-alert verification |
| The App Store Connect private key could be inherited by build, plugin, test, and scan subprocesses | High | Removed private-key environment and temporary-file handling, clear legacy, `asc` credential, and authentication-routing variables at both release entrypoints, require strict authentication, and reject any default profile outside the System Keychain | ShellCheck, secret scans, fail-fast signing probe, and clean final autoreview |
| A concurrent release could claim or replace the intended version tag during packaging | Medium | The release transaction reserves an annotated tag by non-forced push immediately before draft creation and deletes only its exact tag object through a force-with-lease guard | Final autoreview of tag ownership, ambiguous API responses, and cleanup paths |
| Apple notarization could wait indefinitely when a submission remained in progress | Low | The foreground `asc` wait is bounded to 30 minutes and leaves timed-out submissions available for reconciliation | ShellCheck and final autoreview |
| The release client could disclose pseudonymous command telemetry | Low | Every release-time `asc` invocation sets `ASC_TELEMETRY_DISABLED=1` | Final autoreview and release-script inspection |
| An older `asc` could fail only after the signed app was built | Low | The release preflight verifies `notarization submit` and its required file, wait, and timeout flags before building; 3.4.0 is the documented baseline | Capability preflight, ShellCheck, and final autoreview |

The live compatibility tests also found and fixed reliability defects in app-server pipe lifetime and LaunchServices environment forwarding. Later review bounded GUI status refresh to four child processes, bounded JSONL record counts as well as bytes, enforced the output cap after every response stage, suppressed descriptor-local `SIGPIPE` during app-server writes, taught `doctor` to validate missing paths, executables, and app bundles, made launcher bundle identifiers injective, surfaced nonzero LaunchServices exits, made app discovery include per-user installations, and made local CLI/app upgrades stage, verify, and atomically replace each artifact. The status transport stays open until responses arrive, and app launch plans pass `CODEX_HOME` with `/usr/bin/open --env` while retaining a validated, isolated data directory.

## Review by domain

1. **Authentication:** delegated exclusively to the official Codex CLI under the selected `CODEX_HOME`. Conflicting global Codex credential/state overrides are removed; the project does not parse, migrate, print, or persist authentication tokens.
2. **Authorization:** no server or multi-user boundary exists. Local profile changes run with the current macOS user's authority.
3. **Input validation:** profile identifiers, names, paths, registry size/count, app-server output, and launcher metadata are bounded and validated. Localization keys are static, and the gate rejects divergent format placeholders before packaging.
4. **Injection:** child processes use fixed executable URLs and argument arrays. No user-controlled value is evaluated by a shell.
5. **Cryptography:** the application performs no custom encryption or hashing. Distribution trust uses Apple code signing and notarization gates.
6. **Secrets:** Gitleaks and TruffleHog found no verified or unverified secrets. The repository contains no credential fixtures or environment files. Both release entrypoints clear legacy, `asc` credential, and authentication-routing variables before invoking project code, then require strict authentication through the default System Keychain profile without temporary key files. Release-time `asc` telemetry is disabled.
7. **Data protection:** registry and lock files are `0600`; managed and launcher directories are `0700`; symlinks, unsafe ancestors, and extended ACLs are rejected; writes use descriptor-relative operations, a unique temporary file, atomic rename, and durability syncs.
8. **Dependencies:** the sole package dependency is Apple `swift-argument-parser` pinned to 1.8.2 in `Package.resolved`.
9. **Logging and errors:** the project does not dump environments, account email addresses, raw authentication files, child stderr, or raw app-server payloads in human-readable output. The GUI localizes known typed errors and replaces unknown errors with a generic message; explicit JSON output retains its documented account field.
10. **API security:** not applicable; the project exposes no HTTP service or listening socket. The Codex app-server child uses local stdio only.
11. **Frontend security:** native SwiftUI only; there is no HTML rendering, script evaluation, web view, or remote content. User-controlled profile values are rendered verbatim rather than reinterpreted as localization keys.
12. **File upload:** not applicable.
13. **Business logic:** profile selection is always explicit. Quota data never triggers automatic switching, credit consumption, or account rotation.
14. **SSRF and outbound-service abuse:** not applicable; the project owns no network client. Network behavior belongs to independently installed official OpenAI software.
15. **Infrastructure:** CI permissions are least-privilege, third-party actions are SHA-pinned, dependency review is enabled, CodeQL analyzes Swift, and the blocking local check validates both localization catalogs.
16. **Supply chain:** deterministic universal builds, SBOM generation, secret scanning, Developer ID signing, bounded Apple notarization, stapling, Gatekeeper assessment, dSYM matching, SHA-256 checksums, immutable GitHub Releases, race-safe tag ownership, and verification of redownloaded assets are gated before publication.

## Verification performed

- `Scripts/check.sh`: strict Swift format, ast-grep rules, ShellCheck, localization completeness and placeholder checks for 131 keys, debug build, CLI contract check, and 51 tests.
- `Scripts/security-check.sh`: Gitleaks, TruffleHog, dependency resolution, diff checks, and privacy-manifest validation.
- `$autoreview`: `gpt-5.6-sol`/high found and verified localization defects plus release-process risks in tag ownership, ambiguous cleanup, GitHub authentication context, private-key inheritance, architecture parsing, and unbounded notarization. Each accepted finding was fixed; the final consolidated rerun reported no actionable findings.
- Security-audit heuristics: full-history secret scan, route enumeration, and risky-pattern scan. Route/auth and error-leak hits were reviewed as false positives caused by generic pattern matching against local Swift methods and `Label(..., systemImage:)`; the product has no HTTP service or listening socket.
- GitHub security state: zero open Dependabot, CodeQL, or secret-scanning alerts at audit time; the latest `main` CI and CodeQL runs were successful before this unpushed change.
- Locally signed package: `codesign --verify --deep --strict` passed with an Apple Development identity; the app bundle contains `en-US` and `pt-BR`, and isolated native-window renders verified the main profile and editor layouts in both languages without using real profile data.
- Live integration: two sanitized test profiles returned status, passed expanded `doctor` checks under a restricted Finder-like `PATH`, and launched the official app with distinct data directories. No account identifiers or status payloads are retained in the repository.

## Residual limitations

- The desktop `--user-data-dir` adapter is empirical and may change when the official app changes. It was verified against the supported desktop-app discovery and launch flow on the audit date.
- A public downloadable app must not be published until it is signed with `Developer ID Application`, notarized by Apple, stapled, and assessed by Gatekeeper. Source publication and local development-signed use are not blocked.
