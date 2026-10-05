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
OUT_DIR="$REPO_DIR/binpkgs"
mkdir -p "$OUT_DIR"

echo "=> Building $PKG with ethereal chroot mode..."

podman run --rm \
    -v "$REPO_DIR":/io:Z \
    -v "$OUT_DIR":/output:Z \
    "$IMAGE" \
    sh -c "
set -ex
xbps-install -Syu >/dev/null 2>&1
xbps-install -y bash git make gcc nasm perl pkg-config python3 xz tar patch file wget cmake ninja unzip bsdtar >/dev/null 2>&1

cd /tmp
git clone --depth 1 https://github.com/void-linux/void-packages.git
cd void-packages

ln -s / masterdir
xbps-uhelper arch > masterdir/.xbps_chroot_init

echo XBPS_CHROOT_CMD=ethereal > etc/conf
echo XBPS_ALLOW_CHROOT_BREAKOUT=yes >> etc/conf

# Copy the package template (PKG expanded by outer shell)
if [ -d /io/srcpkgs/$PKG ]; then
    cp -a /io/srcpkgs/$PKG srcpkgs/$PKG
else
    echo 'ERROR: srcpkgs/$PKG not found in /io'
    exit 1
fi

# Also copy any sibling templates that might be dependencies
for dep in /io/srcpkgs/*/; do
    depname=\$(basename \"\$dep\")
    [ \"\$depname\" = '$PKG' ] && continue
    [ -d \"srcpkgs/\$depname\" ] || cp -a \"\$dep\" srcpkgs/\$depname 2>/dev/null || true
done

# Build (use XBPS_MAKEJOBS to limit parallelism for large packages)
XBPS_JOBS="${XBPS_MAKEJOBS:+XBPS_MAKEJOBS=$XBPS_MAKEJOBS}"
./xbps-src pkg $PKG $XBPS_JOBS 2>&1

# Copy output packages to mounted output dir
find /tmp/void-packages/hostdir/binpkgs/ -name '*.xbps' -exec cp -v {} /output/ \; 2>/dev/null || echo 'No packages found'
echo '=> Build complete.'
ls -la /output/${PKG}*.xbps 2>/dev/null || echo 'No packages in /output'
"
