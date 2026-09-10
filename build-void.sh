#!/bin/sh
# Build script for debloated Void Linux packages using ethereal chroot mode.
# Usage: ./build-void.sh <package-name>
# Example: ./build-void.sh ffmpeg-nano
#
# Requires: podman, ghcr.io/void-linux/void-glibc-full:20260901r1

set -e

PKG="${1:?Usage: $0 <package-name>}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE="ghcr.io/void-linux/void-glibc-full:20260901r1"

echo "=> Building $PKG with ethereal chroot mode..."

podman run --rm \
    -v "$REPO_DIR":/io:Z \
    "$IMAGE" \
    sh -c "
set -ex
xbps-install -Syu >/dev/null 2>&1
xbps-install -y bash git make gcc nasm perl pkg-config python3 xz tar patch file wget >/dev/null 2>&1

cd /tmp
git clone --depth 1 https://github.com/void-linux/void-packages.git
cd void-packages

ln -s / masterdir
xbps-uhelper arch > masterdir/.xbps_chroot_init

echo XBPS_CHROOT_CMD=ethereal > etc/conf
echo XBPS_ALLOW_CHROOT_BREAKOUT=yes >> etc/conf

# Copy the package template
if [ -d /io/srcpkgs/$PKG ]; then
    cp -a /io/srcpkgs/$PKG srcpkgs/$PKG
else
    echo \"ERROR: srcpkgs/$PKG not found in /io\"
    exit 1
fi

# Also copy any dependencies this package might need
for dep in /io/srcpkgs/*/; do
    depname=\$(basename \"\$dep\")
    # Skip if it's the same package or is the main ffmpeg packages
    [ \"\$depname\" = \"$PKG\" ] && continue
    # Copy dependency templates
    [ -d \"srcpkgs/\$depname\" ] || cp -a \"\$dep\" srcpkgs/\$depname 2>/dev/null || true
done

# Build
./xbps-src pkg $PKG 2>&1

# Show results
echo '=> Build output:'
ls -la /host/binpkgs/${PKG}*.xbps 2>/dev/null || echo 'No packages found in /host/binpkgs'
"
