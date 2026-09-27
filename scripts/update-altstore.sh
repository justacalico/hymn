#!/usr/bin/env bash
set -euo pipefail

# Regenerate altstore/apps.json from the freshly synced GitLab release and
# commit it back to main. Runs inside the github-release-sync job, after
# sync-from-github.sh has recreated the release with package-registry links.
# Only acts on real version tags; the nightly release is skipped.

export PATH="$HOME/.local/bin:$PATH"

RELEASE_TAG="${RELEASE_TAG:-}"
PROJECT_DIR="${CI_PROJECT_DIR:-$PWD}"
cd "$PROJECT_DIR"

if [ -z "$RELEASE_TAG" ]; then
  echo "No RELEASE_TAG provided, skipping AltStore update"
  exit 0
fi

case "$RELEASE_TAG" in
  v[0-9]*.[0-9]*.[0-9]*) ;;
  *)
    echo "Not a version tag ($RELEASE_TAG), skipping AltStore update"
    exit 0
    ;;
esac

IPA_URL=$(glab api "projects/$CI_PROJECT_ID/releases/$RELEASE_TAG" \
  | jq -r '.assets.links[] | select(.name | test("ipa$")) | .url' | head -n1)

if [ -z "$IPA_URL" ] || [ "$IPA_URL" = "null" ]; then
  echo "No .ipa asset on release $RELEASE_TAG, skipping AltStore update"
  exit 0
fi

VERSION="${RELEASE_TAG#v}"
ICON_URL="https://${CI_SERVER_HOST#gitlab.}/HttpAnimations/hymn/-/raw/main/assets/icon-1024.png"
ICON_URL="https://gitlab.com/HttpAnimations/hymn/-/raw/main/assets/icon-1024.png"
SOURCE_URL="https://httpanimations.gitlab.io/hymn/altstore/apps.json"
SIZE=$(curl -fsSIL "$IPA_URL" | awk '/content-length/ {print $2}' | tr -d '\r' | tail -n1)
SIZE="${SIZE:-0}"

mkdir -p altstore
jq -n \
  --arg version "$VERSION" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg url "$IPA_URL" \
  --argjson size "${SIZE:-0}" \
  --arg icon "$ICON_URL" \
  --arg source "$SOURCE_URL" \
  '{
    name: "Hymn",
    identifier: "com.httpanimations.hymn.source",
    sourceURL: $source,
    apps: [{
      name: "Hymn",
      bundleIdentifier: "com.httpanimations.hymn",
      developerName: "HttpAnimations",
      subtitle: "A simple client for TrueNAS SCALE",
      localizedDescription: "Manage pools, shares, snapshots and apps on your TrueNAS SCALE server.",
      iconURL: $icon,
      tintedIconURL: $icon,
      category: "utilities",
      appPermissions: {},
      versions: [{
        version: $version,
        date: $date,
        downloadURL: $url,
        size: $size,
        minOSVersion: "14.0"
      }],
      news: []
    }]
  }' > altstore/apps.json

git config user.name "GitLab CI"
git config user.email "ci@gitlab.com"
git fetch origin main "+refs/tags/*:refs/tags/*"
git checkout -B main origin/main
git add altstore/apps.json
if git diff --cached --quiet; then
  echo "AltStore source already up to date"
  exit 0
fi
git commit -m "chore: 更新 AltStore 源"
git remote add gitlab-ssh "git@gitlab.com:${CI_PROJECT_PATH}.git" 2>/dev/null || true
git push -o ci.skip gitlab-ssh HEAD:main
echo "AltStore source updated for $RELEASE_TAG"
