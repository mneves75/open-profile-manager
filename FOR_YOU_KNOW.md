# How Open Profile Manager fits together

Think of each Codex profile as a separate apartment. `CODEX_HOME` is the key that tells Codex which apartment to enter: its own configuration, sessions, and official authentication state live there. Open Profile Manager keeps a small address book of apartment names and paths; it never opens the locked drawers where credentials live.

`ProfileCore` is the building manager. It validates addresses, writes the registry safely, asks the official Codex app-server for read-only status, and prepares exact launch instructions. The `opm` CLI and SwiftUI app are two front desks talking to the same manager. That shared ownership is important: a security fix or path rule changes once and immediately applies to both surfaces.

The Finder launchers are signposts, not copied apartments. Each one calls the installed `opm` with a validated profile ID, which then opens the canonical ChatGPT/Codex app with isolated local state. Because the official app is referenced in place, its frequent self-updates keep working normally.

There is one macOS-specific wrinkle: LaunchServices does not reliably forward arbitrary environment variables just because they exist on the process that calls `open`. The launcher therefore passes `CODEX_HOME` explicitly with `open --env` and separately provides the Chromium data-directory argument. Those two controls isolate different layers and both are necessary.

There is also an environment-level isolation trap. `CODEX_ACCESS_TOKEN`, `CODEX_API_KEY`, `OPENAI_API_KEY`, and `CODEX_SQLITE_HOME` can override the account or state selected by `CODEX_HOME`. Every launch and status read removes those four global overrides before applying the chosen home, but leaves ordinary custom-provider variables alone.

The sharp edge is desktop compatibility. `CODEX_HOME` and quota reads are documented Codex interfaces, while the extra desktop data directory is an empirical adapter. Upstream can change it. The correct response is a clear `doctor` failure and a compatibility update here—not patching or freezing the official app.

The other hard boundary is intentional: quota status informs a human choice. It never triggers account rotation. That keeps the tool useful without turning it into rate-limit circumvention.

One subtle protocol lesson came from the real integration test. Writing all JSONL requests correctly was not enough: closing stdin told `codex app-server` to shut down before it drained those requests. The status client therefore keeps the pipe open until it receives the bounded responses, then closes and terminates the child during cleanup. This is exactly why the project tests fixtures but still proves compatibility against the installed Codex version before release.

The registry has a similar real-world concern: atomic rename prevents readers from seeing half a JSON file, but it does not prevent two writers from both reading the same old value and overwriting each other. The owner-only lock file serializes that full read-modify-write transaction. It lives in a reserved namespace, so a custom registry filename cannot collide with another registry's lock. Atomic storage and concurrency control solve different problems; both are needed.

On macOS, `0700` and `0600` are not the entire privacy story. An extended ACL can grant access to another local user without changing those familiar mode bits, and a path can be swapped after a string-based check. The core walks and opens private storage relative to directory descriptors, rejects unsafe ACLs and writable ancestors, and makes `doctor` check the same effective paths that launch will use. It also rejects overlapping homes and GUI directories—the digital equivalent of discovering that two apartment labels open the same front door.
