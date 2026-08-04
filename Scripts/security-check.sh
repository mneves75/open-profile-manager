#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks is required (brew install gitleaks)" >&2
  exit 1
fi

gitleaks dir . --no-banner --redact --max-target-megabytes 20
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  gitleaks git . --no-banner --redact
fi

if command -v trufflehog >/dev/null 2>&1; then
  trufflehog filesystem --no-update --fail --fail-on-scan-errors --force-skip-binaries \
    --exclude-paths "$ROOT/.trufflehog-exclude-paths" --results verified .
else
  echo "Note: trufflehog is not installed; gitleaks completed successfully." >&2
fi

git diff --check
/usr/bin/plutil -lint Sources/OpenProfileManager/Resources/PrivacyInfo.xcprivacy
swift package show-dependencies --format json >/dev/null

echo "Security checks passed."
