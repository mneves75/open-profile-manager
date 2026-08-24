# Share sessions without sharing authentication

Open Profile Manager will treat shared sessions as an explicit, local, experimental pool available to selected profiles while keeping each profile's authentication and configuration isolated under the official Codex runtime. The first version is CLI-only through `opm run`, permits one pool-backed Codex process at a time, migrates existing transcripts only after confirmation, and fails closed when the installed Codex version or state layout is not recognized.

## Consequences

- The account selected by the user for a turn may continue context originally created with another participating account.
- SQLite-backed resumable state created after activation is shared with the pool; existing goals, memories, and queues are not merged.
- Pool management never reads, copies, decodes, migrates, prints, or persists authentication material; authentication remains exclusively inside each participating profile's official Codex home.
- Removing a profile revokes its access without copying or deleting pool data.
- Desktop-app support, direct `codex` use, cloud synchronization, quota-driven switching, and credential sharing remain out of scope.
