#!/usr/bin/env bash
set -euo pipefail

unset \
  APP_STORE_CONNECT_API_KEY_P8 \
  ASC_BYPASS_KEYCHAIN \
  ASC_CONFIG_PATH \
  ASC_ISSUER_ID \
  ASC_KEY_ID \
  ASC_KEY_TYPE \
  ASC_PROFILE \
  ASC_PRIVATE_KEY \
  ASC_PRIVATE_KEY_B64 \
  ASC_PRIVATE_KEY_PATH \
  ASC_STRICT_AUTH || true

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/version.env"
# shellcheck disable=SC1091
source "$ROOT/Scripts/release_artifacts.sh"

if [[ $# -eq 1 && "$1" == --help ]]; then
  echo "Usage: Scripts/release.sh [--beta COUNT]"
  exit 0
fi
if ! TAG=$(opm_release_tag "$MARKETING_VERSION" "$@"); then
  echo "Usage: Scripts/release.sh [--beta COUNT] (positive integer)" >&2
  exit 2
fi
RELEASE_FLAGS=(--latest)
if [[ "$TAG" != "v$MARKETING_VERSION" ]]; then
  RELEASE_FLAGS=(--prerelease --latest=false)
fi

unset GITHUB_TOKEN GH_TOKEN HOMEBREW_GITHUB_API_TOKEN || true
gh auth status >/dev/null

REPOSITORY="mneves75/open-profile-manager"
HEAD_SHA=$(git rev-parse HEAD)
ARCHES_VALUE="arm64 x86_64"
APP_ZIP="$ROOT/build/$(opm_app_zip_name "$MARKETING_VERSION" "$ARCHES_VALUE")"
DSYM_ZIP="$ROOT/build/$(opm_dsym_zip_name "$MARKETING_VERSION" "$ARCHES_VALUE")"
CHECKSUMS="$ROOT/build/$(opm_checksums_name "$MARKETING_VERSION")"
SBOM="$ROOT/build/$(opm_sbom_name "$MARKETING_VERSION")"
NOTES="$ROOT/build/Open-Profile-Manager-$MARKETING_VERSION-release-notes.md"
VERIFY_DIR=
release_created=0
tag_owned=0
tag_object=

delete_owned_tag() {
  if [[ "$tag_owned" != 1 ]]; then
    return
  fi
  if git push --force-with-lease="refs/tags/$TAG:$tag_object" \
    origin ":refs/tags/$TAG" >/dev/null 2>&1; then
    git update-ref -d "refs/tags/$TAG" "$tag_object"
  else
    echo "Preserving $TAG because its remote object changed" >&2
  fi
}

cleanup() {
  if [[ -n "$VERIFY_DIR" && -d "$VERIFY_DIR" ]]; then
    rm -r "$VERIFY_DIR"
  fi
  if [[ "$release_created" == 1 ]]; then
    release_is_draft=$(gh release view "$TAG" --repo "$REPOSITORY" \
      --json isDraft --jq .isDraft 2>/dev/null || true)
    if [[ "$release_is_draft" == true ]]; then
      if gh release delete "$TAG" --repo "$REPOSITORY" --yes >/dev/null 2>&1; then
        delete_owned_tag
      else
        echo "Preserving $TAG because its draft could not be deleted" >&2
      fi
    elif [[ "$release_is_draft" != false ]]; then
      echo "Preserving $TAG because its GitHub state is unknown" >&2
    fi
  fi
}
trap cleanup EXIT

if [[ $(git branch --show-current) != main ]]; then
  echo "Release must run from main" >&2
  exit 1
fi
if [[ -n $(git status --porcelain) ]]; then
  echo "Release requires a clean worktree" >&2
  exit 1
fi
git fetch --tags origin main
if [[ "$HEAD_SHA" != "$(git rev-parse origin/main)" ]]; then
  echo "Local main must exactly match origin/main" >&2
  exit 1
fi
if git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null \
  || git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1 \
  || gh release view "$TAG" --repo "$REPOSITORY" --json tagName >/dev/null 2>&1; then
  echo "$TAG already exists" >&2
  exit 1
fi
if [[ $(gh api "repos/$REPOSITORY/immutable-releases" --jq .enabled) != true ]]; then
  echo "Enable GitHub immutable releases before publishing $TAG" >&2
  exit 1
fi
if ! grep -Fq "## [$MARKETING_VERSION]" CHANGELOG.md; then
  echo "CHANGELOG.md has no finalized $MARKETING_VERSION section" >&2
  exit 1
fi

for workflow_name in CI CodeQL; do
  workflow_run=$(gh run list --repo "$REPOSITORY" --workflow "$workflow_name" \
    --commit "$HEAD_SHA" --limit 1 --json databaseId,status,conclusion)
  workflow_run_id=$(jq -r '.[0].databaseId // empty' <<< "$workflow_run")
  workflow_status=$(jq -r '.[0].status // empty' <<< "$workflow_run")
  workflow_conclusion=$(jq -r '.[0].conclusion // empty' <<< "$workflow_run")
  if [[ -z "$workflow_run_id" \
    || "$workflow_status" != completed \
    || "$workflow_conclusion" != success ]]; then
    echo "The $workflow_name run for $HEAD_SHA must be complete and successful" >&2
    exit 1
  fi
  if [[ "$workflow_name" == CI ]]; then
    ci_run_id=$workflow_run_id
  fi
done

Scripts/check.sh
Scripts/security-check.sh --release
ARCHES="$ARCHES_VALUE" Scripts/sign-and-notarize.sh

rm -f "$SBOM"
if [[ -e "$ROOT/build/sbom-download" ]]; then
  rm -r "$ROOT/build/sbom-download"
fi
gh run download "$ci_run_id" --repo "$REPOSITORY" --name open-profile-manager-sbom \
  --dir "$ROOT/build/sbom-download"
downloaded_sbom="$ROOT/build/sbom-download/open-profile-manager.spdx.json"
if [[ ! -s "$downloaded_sbom" ]]; then
  echo "The successful CI run did not provide its SPDX SBOM" >&2
  exit 1
fi
mv "$downloaded_sbom" "$SBOM"
rmdir "$ROOT/build/sbom-download"

(
  cd "$ROOT/build"
  /usr/bin/shasum -a 256 \
    "$(basename "$APP_ZIP")" \
    "$(basename "$DSYM_ZIP")" \
    "$(basename "$SBOM")" \
    > "$(basename "$CHECKSUMS")"
)

awk -v version="$MARKETING_VERSION" '
  $0 == "## [" version "]" || index($0, "## [" version "] - ") == 1 { found = 1; next }
  found && /^## \[/ { exit }
  found { print }
' CHANGELOG.md > "$NOTES"
if [[ ! -s "$NOTES" ]]; then
  echo "Could not extract release notes for $MARKETING_VERSION" >&2
  exit 1
fi

git tag --annotate "$TAG" "$HEAD_SHA" --message "Open Profile Manager ${TAG#v}"
tag_object=$(git rev-parse "refs/tags/$TAG")
if ! git push origin "refs/tags/$TAG:refs/tags/$TAG"; then
  git update-ref -d "refs/tags/$TAG" "$tag_object"
  echo "Could not reserve $TAG at $HEAD_SHA" >&2
  exit 1
fi
tag_owned=1

gh release create "$TAG" \
  --repo "$REPOSITORY" \
  --verify-tag \
  --draft \
  --title "Open Profile Manager ${TAG#v}" \
  "${RELEASE_FLAGS[@]}" \
  --notes-file "$NOTES"
release_created=1
gh release upload "$TAG" \
  --repo "$REPOSITORY" \
  "$APP_ZIP" \
  "$DSYM_ZIP" \
  "$SBOM" \
  "$CHECKSUMS"

VERIFY_DIR=$(mktemp -d "${TMPDIR:-/tmp}/open-profile-manager-release-verify.XXXXXX")
gh release download "$TAG" --repo "$REPOSITORY" --dir "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  /usr/bin/shasum -a 256 --check "$(basename "$CHECKSUMS")"
)
/usr/bin/ditto -x -k "$VERIFY_DIR/$(basename "$APP_ZIP")" "$VERIFY_DIR/extracted"
DOWNLOADED_APP="$VERIFY_DIR/extracted/Open Profile Manager.app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$DOWNLOADED_APP"
if command -v syspolicy_check >/dev/null 2>&1; then
  syspolicy_check distribution "$DOWNLOADED_APP"
else
  /usr/sbin/spctl --assess --type execute --verbose=2 "$DOWNLOADED_APP"
fi
/usr/bin/xcrun stapler validate "$DOWNLOADED_APP"
Scripts/test_packaged_app.sh "$DOWNLOADED_APP"

gh release edit "$TAG" --repo "$REPOSITORY" --draft=false "${RELEASE_FLAGS[@]}"
for asset in "$APP_ZIP" "$DSYM_ZIP" "$SBOM" "$CHECKSUMS"; do
  gh release verify-asset "$TAG" "$asset" --repo "$REPOSITORY"
done

echo "Published https://github.com/$REPOSITORY/releases/tag/$TAG"
