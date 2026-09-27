#!/usr/bin/env bash
# Package a built Flutter Linux bundle as an RPM for Fedora and friends.
# Installs to /opt/hymn with a /usr/bin/hymn symlink, matching the .deb.
#
# Usage: scripts/build-rpm.sh <bundle-dir> <version> <rpm-arch> <output-file> [release]
set -euo pipefail

BUNDLE_DIR="${1:?usage: build-rpm.sh <bundle-dir> <version> <rpm-arch> <output-file> [release]}"
VERSION="${2:?}"
ARCH="${3:?}"
OUT="${4:?}"
RELEASE="${5:-1}"

if ! command -v rpmbuild >/dev/null 2>&1; then
  echo "build-rpm: rpmbuild not found" >&2
  exit 1
fi
if [ ! -d "$BUNDLE_DIR" ]; then
  echo "build-rpm: bundle dir not found: $BUNDLE_DIR" >&2
  exit 1
fi
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
  echo "build-rpm: unsupported arch: $ARCH" >&2
  exit 1
fi

RPM_VERSION="$(printf '%s' "$VERSION" | tr '-' '~')"
TOPDIR="$(mktemp -d)"
trap 'rm -rf "$TOPDIR"' EXIT
mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

cat > "$TOPDIR/SPECS/hymn.spec" <<'EOF'
Name: hymn
Version: %{pkg_version}
Release: %{pkg_release}%{?dist}
Summary: A simple, native client for TrueNAS SCALE
License: AGPL-3.0-only
URL: https://gitlab.com/HttpAnimations/hymn

%global debug_package %{nil}
%global __os_install_post %{nil}
%global __provides_exclude_from ^/opt/hymn/.*

%description
Hymn is a native client for TrueNAS SCALE.

%install
mkdir -p %{buildroot}/opt/hymn %{buildroot}/usr/bin \
  %{buildroot}/usr/share/applications %{buildroot}/usr/share/pixmaps
cp -a %{bundle_dir}/. %{buildroot}/opt/hymn/
ln -sf /opt/hymn/hymn %{buildroot}/usr/bin/hymn
install -m644 %{desktop_file} %{buildroot}/usr/share/applications/hymn.desktop
install -m644 %{icon_file} %{buildroot}/usr/share/pixmaps/hymn.png

%files
/opt/hymn
/usr/bin/hymn
/usr/share/applications/hymn.desktop
/usr/share/pixmaps/hymn.png
EOF

rpmbuild -bb \
  --target "$ARCH" \
  --define "_topdir $TOPDIR" \
  --define "pkg_version $RPM_VERSION" \
  --define "pkg_release $RELEASE" \
  --define "bundle_dir $(realpath "$BUNDLE_DIR")" \
  --define "desktop_file $(realpath packaging/linux/hymn.desktop)" \
  --define "icon_file $(realpath assets/icon-1024.png)" \
  "$TOPDIR/SPECS/hymn.spec"

RPM_PATH="$(find "$TOPDIR/RPMS" -name '*.rpm' -print -quit)"
if [ -z "$RPM_PATH" ]; then
  echo "build-rpm: rpmbuild produced no rpm" >&2
  exit 1
fi
cp "$RPM_PATH" "$OUT"
echo "build-rpm: $RPM_PATH -> $OUT"
