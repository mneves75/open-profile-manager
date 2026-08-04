# Security policy

## Supported versions

Security fixes are provided for the latest released minor version.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Use GitHub's private vulnerability reporting for `mneves75/open-profile-manager`. Include the affected version, reproduction steps, impact, and any proposed remediation. Do not include real Codex tokens or authentication files.

You should receive an acknowledgement within seven days. Please allow time for validation and coordinated remediation before public disclosure.

## Security boundary

Open Profile Manager stores profile labels and local paths. The official Codex runtime owns authentication data under each `CODEX_HOME`; this project must never read or transfer that material. The public website is a static GitHub Pages artifact with no backend, form submission, analytics, or telemetry.
