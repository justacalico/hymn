#!/usr/bin/env bash
set -euo pipefail

# GitLab Pages deploy: pull the web landing build (web.tar.gz) out of the
# release assets that sync-from-github.sh just published, unpack it into
# public/, and drop the AltStore source next to it.

export PATH="$HOME/.local/bin:$PATH"

RELEASE_TAG="${RELEASE_TAG:-nightly}"
PROJECT_DIR="${CI_PROJECT_DIR:-$PWD}"
cd "$PROJECT_DIR"

mkdir -p public /tmp/pages-assets

# Download only the web tarball from the GitLab release.
glab release download "$RELEASE_TAG" -R "$CI_PROJECT_PATH" \
  --dir /tmp/pages-assets --asset-name "web.tar.gz" 2>/dev/null || \
glab release download "$RELEASE_TAG" -R "$CI_PROJECT_PATH" \
  --dir /tmp/pages-assets || true

if [ -f /tmp/pages-assets/web.tar.gz ]; then
  tar -xzf /tmp/pages-assets/web.tar.gz -C public
elif [ -f /tmp/pages-assets/web/web.tar.gz ]; then
  tar -xzf /tmp/pages-assets/web/web.tar.gz -C public
else
  echo "web.tar.gz not found in release $RELEASE_TAG; publishing fallback page"
  cat > public/index.html <<'HTMLEOF'
<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Hymn</title><body style="font-family:system-ui;background:#0C0F14;color:#E8EAED;display:grid;place-items:center;min-height:100vh;margin:0">
<main><h1>Hymn</h1><p>A simple, native client for TrueNAS SCALE.</p>
<p><a style="color:#5B8DEF" href="https://gitlab.com/HttpAnimations/hymn/-/releases">Download the app</a></p></main>
HTMLEOF
fi

mkdir -p public/altstore
if [ -f altstore/apps.json ]; then
  cp altstore/apps.json public/altstore/apps.json
fi

echo "Pages content:"
find public -type f | head -20
