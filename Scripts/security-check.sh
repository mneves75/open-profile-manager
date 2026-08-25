#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

release_mode=false
if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [--release]" >&2
  exit 2
fi
case "${1:-}" in
  "") ;;
  --release) release_mode=true ;;
  *)
    echo "Usage: $0 [--release]" >&2
    exit 2
    ;;
esac

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks is required (brew install gitleaks)" >&2
  exit 1
fi

gitleaks dir . --no-banner --redact --max-target-megabytes 20
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  gitleaks git . --no-banner --redact
fi

if command -v trufflehog >/dev/null 2>&1; then
  trufflehog_results=verified
  if [[ "$release_mode" == true ]]; then
    trufflehog_results=verified,unknown,unverified
  fi
  trufflehog filesystem --no-update --fail --fail-on-scan-errors --force-skip-binaries \
    --exclude-paths "$ROOT/.trufflehog-exclude-paths" --results "$trufflehog_results" .
elif [[ "$release_mode" == true ]]; then
  echo "trufflehog is required for release security checks (brew install trufflehog)" >&2
  exit 1
else
  echo "Note: trufflehog is not installed; gitleaks completed successfully." >&2
fi

git diff --check
/usr/bin/plutil -lint Sources/OpenProfileManager/Resources/PrivacyInfo.xcprivacy
swift package show-dependencies --format json >/dev/null

echo "Security checks passed."
