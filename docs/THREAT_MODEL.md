# Threat model

## Assets

- Codex authentication state owned by each `CODEX_HOME`
- User profile names and local filesystem paths
- Integrity of commands launched under the user's account
- Integrity and provenance of distributed macOS artifacts

## Trust boundaries

- CLI and GUI input enters `ProfileCore` as untrusted data.
- The local filesystem may contain symlinks, unexpected mode bits or extended ACLs, or malformed registry data.
- `codex app-server` is a child process with untrusted JSONL output and bounded response time.
- The independently installed ChatGPT/Codex app is outside this project's ownership.

## Required mitigations

- Strict profile-ID grammar and absolute normalized paths; no shell evaluation.
- Profile launch and status remove global Codex credential/state overrides before applying the selected `CODEX_HOME`.
- Descriptor-relative registry operations with owner-only permissions, no unsafe extended ACLs, durable atomic replacement, and a cross-process writer lock in a reserved namespace.
- Bounded registry size/profile count and bounded app-server fields.
- Existing managed directories and traversed ancestors must be current-user-owned or trusted system roots, non-symlinked, non-writable by other users, and free of unsafe extended ACLs.
- Codex homes and explicit or derived GUI data directories must not be equal, nested, reserved, or shared across profiles.
- Bounded child-process execution; terminate processes on timeout and output limit.
- Redacted errors: never include tokens, environment dumps, or raw authentication files.
- Status is read-only. The product never consumes reset credits or automatically chooses another account.
- Generated launchers contain identifiers and executable paths only, never credentials; publication requires a private destination and explicit owner-only bundle modes.
- Application and managed-launcher property lists must be symlink-free regular files and are read nonblocking under a strict size cap.
- Dependency pinning, secret scanning, static analysis, tests, signed release artifacts, and notarization gates.

The completed 0.1.0 review and evidence are recorded in [SECURITY_AUDIT.md](SECURITY_AUDIT.md).

## Explicit non-goals

- Sharing credentials or profiles between operating-system users
- Acting as an authentication provider
- Modifying the official Codex/ChatGPT application
- Evading or circumventing service rate limits
- Running a network daemon or exposing Codex app-server remotely
