# Open Profile Manager

[![CI](https://github.com/mneves75/open-profile-manager/actions/workflows/ci.yml/badge.svg)](https://github.com/mneves75/open-profile-manager/actions/workflows/ci.yml)
[![CodeQL](https://github.com/mneves75/open-profile-manager/actions/workflows/codeql.yml/badge.svg)](https://github.com/mneves75/open-profile-manager/actions/workflows/codeql.yml)

Open Profile Manager is an unofficial, local-first macOS profile launcher for the Codex CLI and the ChatGPT/Codex desktop app. It keeps each account's Codex state in a separate `CODEX_HOME`, shows read-only account and quota status, and lets you explicitly choose which profile to launch.

It does **not** rotate accounts automatically, evade rate limits, copy credentials, or redistribute OpenAI software.

The native app follows the macOS language preference automatically. It includes complete `en-US` and `pt-BR` localizations and falls back to `en-US` for unsupported languages. The stable `opm` CLI and JSON contracts remain in English.

## Why it exists

Codex already supports `CODEX_HOME`, but remembering environment variables and keeping desktop-app sessions isolated is awkward. Open Profile Manager turns that mechanism into named profiles available from both a CLI and a native macOS app.

## Requirements

- macOS 15 or newer
- The official [`codex` CLI](https://github.com/openai/codex), installed and available on `PATH`
- For GUI launching, an independently installed `ChatGPT.app` or `Codex.app` under `/Applications` or `~/Applications`

## Build and install locally

```bash
git clone https://github.com/mneves75/open-profile-manager.git
cd open-profile-manager
Scripts/bootstrap.sh
Scripts/check.sh
Scripts/install-local.sh
```

This installs `opm` under `~/.local/bin` and `Open Profile Manager.app` under `~/Applications`. It does not modify the official ChatGPT/Codex app.

Local installation requires a `Developer ID Application` or `Apple Development` identity in your login keychain. CI packaging may use an ad-hoc signature for build verification, but public downloadable artifacts must use Developer ID and Apple notarization.

Public releases use a notarized universal app ZIP, matching dSYMs, an SPDX SBOM, and SHA-256 checksums. GitHub also provides source ZIP and `tar.gz` archives. See [the release procedure](docs/RELEASING.md).

## Quick start

```bash
# Register existing profiles. Paths are expanded by your shell here.
opm profile add work --name "Work" --home "$HOME/.codex"
opm profile add research --name "Research" --home "$HOME/.codex-research"

# Authenticate each profile using the official Codex flow.
opm login work
opm login research

# Inspect account and quota status. Selection remains manual.
opm status --all

# Launch the CLI or desktop app with an explicit profile.
opm run work
opm app launch research

# Create Finder launchers in ~/Applications.
opm launcher install work
opm launcher install research
```

Run `opm --help` for the complete command reference.

## How updates work

The generated profile launchers reference the canonical official app in `/Applications`; they never copy it. ChatGPT/Codex therefore keeps updating through its own updater. Open Profile Manager updates independently. Re-run `opm launcher install <profile>` only if the `opm` executable moves or a launcher needs to be refreshed.

## Security and privacy

- Profiles store labels and filesystem paths only.
- Authentication remains inside each official Codex home; this project never reads or exports tokens.
- Profile launches remove process-global Codex credential/state overrides before setting the selected `CODEX_HOME`; custom-provider environment variables remain available.
- Child processes are launched directly with argument arrays, never through a shell.
- The bounded registry is written atomically under a cross-process lock with owner-only modes and no extended ACLs.
- Each profile must use distinct, non-overlapping Codex and GUI data directories; existing private directories must already satisfy the owner-only security policy.
- Local upgrades stage and verify both artifacts before atomically replacing the installed CLI and app.
- There is no telemetry, hosted service, or profile sync.

See [SECURITY.md](SECURITY.md) for vulnerability reporting, [the threat model](docs/THREAT_MODEL.md) for the security design, and [the current security audit](docs/SECURITY_AUDIT.md) for completed review evidence.

## Compatibility note

`CODEX_HOME` and `account/rateLimits/read` are documented Codex interfaces. The launcher passes `CODEX_HOME` explicitly through LaunchServices and assigns a separate Chromium data directory. That desktop data-directory behavior is an empirical compatibility adapter and may need maintenance after upstream desktop-app changes. `opm doctor` is designed to detect problems safely.

## Project status

Version 0.1.0 is the current source line. See [PROJECT_STATUS.md](PROJECT_STATUS.md) and [CHANGELOG.md](CHANGELOG.md).

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and the project [Code of Conduct](CODE_OF_CONDUCT.md) first.

## License and trademark notice

MIT licensed. See [LICENSE](LICENSE).

Open Profile Manager is an independent open-source project. It is not affiliated with, sponsored by, or endorsed by OpenAI. OpenAI, ChatGPT, and Codex are trademarks of their respective owner.
