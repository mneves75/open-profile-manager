# Contributing

Thank you for improving Open Profile Manager.

## Development setup

```bash
Scripts/bootstrap.sh
Scripts/check.sh
```

Use Swift 6.3/Xcode 26.6 or a compatible newer stable toolchain. Keep changes focused, add tests through the `ProfileCore` interface, and use Conventional Commit messages.

## Product and security constraints

- Do not add automatic quota-based profile switching or any rate-limit circumvention.
- Do not read, decode, print, migrate, or store authentication tokens.
- Do not copy OpenAI assets, application bundles, or branding.
- Do not build shell command strings from user input.

Open a security report privately as described in [SECURITY.md](SECURITY.md), not as a public issue.

## Pull requests

Before opening a pull request:

```bash
Scripts/check.sh
Scripts/security-check.sh
```

Describe the user-visible behavior, why the change belongs in the project, the commands you ran, and any compatibility risk with the official Codex CLI or desktop app.
