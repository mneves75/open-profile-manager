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

- No active source work. Public binary distribution remains gated as documented below.

## Verified state

- Forty-nine tests in six suites pass, including concurrency, descriptor-relative and ACL-aware registry privacy, firmlink-aware profile-directory isolation, persisted-invariant validation, private launcher publication, bounded plist inspection, descriptor-safe app-server writes, system/per-user app discovery, symlink-safe diagnostics, and hostile protocol output.
- The 0.1.0 source is published at `github.com/mneves75/open-profile-manager` after a clean final autoreview and security gate.
- Local CLI, GUI, Finder-launcher, signing, and two-profile isolation flows passed without retaining account identifiers in the repository.
- A public binary remains blocked until the maintainer can complete Developer ID signing and Apple notarization.
