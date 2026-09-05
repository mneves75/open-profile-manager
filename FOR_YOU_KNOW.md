# How Open Profile Manager fits together

Think of each Codex profile as a separate apartment. `CODEX_HOME` is the key that tells Codex which apartment to enter: its own configuration, sessions, and official authentication state live there. Open Profile Manager keeps a small address book of apartment names and paths; it never opens the locked drawers where credentials live.

`ProfileCore` is the building manager. It validates addresses, writes the registry safely, asks the official Codex app-server for read-only status, and prepares exact launch instructions. The `opm` CLI and SwiftUI app are two front desks talking to the same manager. That shared ownership is important: a security fix or path rule changes once and immediately applies to both surfaces.

The Finder launchers are signposts, not copied apartments. Each one calls the installed `opm` with a validated profile ID, which then opens the canonical ChatGPT/Codex app with isolated local state. Because the official app is referenced in place, its frequent self-updates keep working normally.

An address is not proof of identity. A lookalike app can sit at a familiar path, so launch planning now asks macOS Security.framework to verify the entire signed bundle and requires OpenAI's Team ID plus the expected bundle identifier. The check deliberately pins the publisher identity, not one leaf certificate, because legitimate certificates rotate.

Interactive terminal ownership is different from ordinary child-process launching. Foundation's `Process` left `opm` in the terminal's foreground group while Codex started behind it; as soon as Codex tried to read, macOS stopped it with `SIGTTIN`. `run`, `login`, and `logout` now use `execve`, replacing the launcher in place so Codex inherits the same PID, process group, terminal, signals, and exit status. GUI launch still uses `Process` because `opm` must wait for and report `/usr/bin/open` rather than become it.

There is one macOS-specific wrinkle: LaunchServices does not reliably forward arbitrary environment variables just because they exist on the process that calls `open`. The launcher therefore passes `CODEX_HOME` explicitly with `open --env` and separately provides the Chromium data-directory argument. Those two controls isolate different layers and both are necessary.

There is also an environment-level isolation trap. `CODEX_ACCESS_TOKEN`, `CODEX_API_KEY`, `OPENAI_API_KEY`, and `CODEX_SQLITE_HOME` can override the account or state selected by `CODEX_HOME`. Every launch and status read removes those four global overrides before applying the chosen home, but leaves ordinary custom-provider variables alone.

The sharp edge is desktop compatibility. `CODEX_HOME` and quota reads are documented Codex interfaces, while the extra desktop data directory is an empirical adapter. Upstream can change it. The correct response is a clear `doctor` failure and a compatibility update here—not patching or freezing the official app.

The other hard boundary is intentional: quota status informs a human choice. It never triggers account rotation. That keeps the tool useful without turning it into rate-limit circumvention.

Localization follows the same front-desk boundary. `ProfileCore` keeps stable English diagnostics for the CLI and typed errors for callers; the native front desk translates those errors, menus, views, and accessibility text after they enter the GUI. macOS chooses `en-US` or `pt-BR` from the user's preferred languages, with English as the fallback. A small checker compares every source key with both catalog entries and their format placeholders, so a translated sentence cannot accidentally drop a profile ID, path, or number.

One subtle protocol lesson came from the real integration test. Writing all JSONL requests correctly was not enough: closing stdin told `codex app-server` to shut down before it drained those requests. The status client therefore keeps the pipe open until it receives the bounded responses, then closes and terminates the child during cleanup. Its parser also counts a final record without a newline and distinguishes real JSON Booleans and integers from Foundation's permissive numeric bridges. This is exactly why the project tests fixtures but still proves compatibility against the installed Codex version before release.

Status also exposed a smaller ownership smell: the SwiftUI adapter had its own concurrency pool while the CLI queried profiles serially. The pool now belongs to `ProfileCore`, where both front desks share it. The core reads the registry once, keeps result order stable, and permits at most four app-servers at a time; a two-process barrier test proves actual overlap without depending on a timing threshold.

The registry has a similar real-world concern: atomic rename prevents readers from seeing half a JSON file, but it does not prevent two writers from both reading the same old value and overwriting each other. The owner-only lock file serializes that full read-modify-write transaction. It lives in a reserved namespace, so a custom registry filename cannot collide with another registry's lock. Atomic storage and concurrency control solve different problems; both are needed.

Directory isolation once spent most of its time repeatedly asking the filesystem the same physical-path question. The registry now resolves each profile path once per validation pass and reuses those strings for every overlap comparison. At the maximum 128 profiles, the measured p95 fell from about 7.1 seconds to 28 milliseconds without caching across user actions.

The public website is the showroom, not another application layer. It is plain HTML, CSS, and a few lines of progressive JavaScript under `docs/`, so there is no package manager, framework runtime, analytics SDK, or hosted backend to maintain. GitHub Actions uploads only that directory to Pages. The three videos are deterministic Remotion renders: their editable sources live under `video/`, while the finished MP4s and lightweight poster frames are copied into `docs/media/` because the Pages artifact deliberately cannot reach outside its own directory.

That separation does not make the showroom exempt from release discipline. Pull requests and Pages deployment both syntax-check the site and run the existing Remotion lint/typecheck, while Dependabot watches the video lockfile. Human-readable CLI and native-app status also omit account email; only an explicit structured JSON request retains that documented field.

SwiftPM's output layout is a toolchain detail, not a stable path contract. Packaging asks SwiftPM where each product landed, and public releases explicitly select the supported stable `/Applications/Xcode.app`. Xcode 27 beta currently puts sequential arm64 and x86_64 builds in one shared product directory, where the second build overwrites the first; keep the beta for compatibility builds and tests until that packaging behavior changes.

A signed ZIP is still only inert evidence until its contents run. The release gate now downloads the canonical artifact, verifies its checksums, signature, Gatekeeper policy, and notarization ticket, then exercises the bundled CLI's terminal ownership and waits for a real native window under an isolated home. Release-mode secret scanning is similarly fail-closed: TruffleHog must be installed, and verified, unknown, or unverified candidates stop publication for review.

On macOS, `0700` and `0600` are not the entire privacy story. An extended ACL can grant access to another local user without changing those familiar mode bits, and a path can be swapped after a string-based check. The core walks and opens private storage relative to directory descriptors, rejects unsafe ACLs and writable ancestors, and makes `doctor` check the same effective paths that launch will use. It also rejects overlapping homes and GUI directories—the digital equivalent of discovering that two apartment labels open the same front door.

## Less code, clearer proof

The September audit removed unused entry points and old presentation options, while keeping the filesystem and authentication protections. The native adapter now uses one result shape for background operations. The website lost obsolete CSS and reveal code, with matching rendered styles; sampled video frames remained identical after removing dormant options.

Verification no longer reinstalls the video toolchain on every run: bootstrap and CI install the lockfile, checks reuse it. The debug launcher rebuilds before opening, so a stale bundle cannot masquerade as a successful fix. Terminal tests now inspect the child's exit status as well as its output and foreground process group. See CONTRIBUTING.md for isolated QA and debugging, and the archived audit plan for measurements and deferred candidates.

Beta and production are two publication labels over the same reviewed source. A beta tag such as `v0.1.7-beta1` goes through the full notarization and downloaded-execution checks but leaves the latest stable download unchanged. Production uses `v0.1.7` and becomes the stable download only after passing those checks. Keep extraction and signing work outside synced folders: this Mac's Documents file provider added Finder metadata to a valid downloaded app, while extracting the identical ZIP in local staging preserved signature verification.
