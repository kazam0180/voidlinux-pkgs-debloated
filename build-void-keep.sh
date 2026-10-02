#!/bin/sh
# Resumable build script for large/debloated Void Linux packages.
# Uses a *named, persistent* container so that the masterdir and /builddir
# survive between runs. Combined with XBPS_KEEP_BUILD_DIR=yes this lets a
# rebuild after a packaging-only failure reuse the compiled objects.
#
# Usage: ./build-void-keep.sh <package-name>
# Remove the cached container afterwards with:
#   podman rm -f void-build-<pkg>

set -e

PKG="${1:?Usage: $0 <package-name>}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE="ghcr.io/void-linux/void-glibc-full:20260901r1"
OUT_DIR="$REPO_DIR/binpkgs"
LOG_DIR="$REPO_DIR/build-logs"
NAME="void-build-$PKG"
mkdir -p "$OUT_DIR" "$LOG_DIR"

echo "=> Building $PKG (persistent container '$NAME')..."

if ! podman container exists "$NAME" 2>/dev/null; then
	podman run -d \
	    --name "$NAME" \
	    -v "$REPO_DIR":/io:Z \
	    -v "$OUT_DIR":/output:Z \
	    "$IMAGE" \
	    sleep infinity >/dev/null
fi

podman start "$NAME" >/dev/null 2>&1 || true

# the image only ships sh; install bash before we can run the xbps-src body
if ! podman exec "$NAME" sh -c 'command -v bash' >/dev/null 2>&1; then
	podman exec "$NAME" sh -c \
	    'xbps-install -Syu >/dev/null 2>&1
	     xbps-install -y bash git make gcc nasm perl pkg-config python3 xz tar patch file wget cmake ninja >/dev/null 2>&1
	     exit 0'
fi

podman exec "$NAME" bash -c "
set -ex
export XBPS_KEEP_BUILD_DIR=yes

if [ ! -e /tmp/void-packages ]; then
	cd /tmp
	git clone --depth 1 https://github.com/void-linux/void-packages.git
	cd void-packages
	ln -sf / masterdir
	xbps-uhelper arch > masterdir/.xbps_chroot_init
	echo XBPS_CHROOT_CMD=ethereal > etc/conf
	echo XBPS_ALLOW_CHROOT_BREAKOUT=yes >> etc/conf
else
	cd /tmp/void-packages
fi

if [ -d /io/srcpkgs/$PKG ]; then
	rm -rf srcpkgs/$PKG
	cp -a /io/srcpkgs/$PKG srcpkgs/$PKG
else
	echo 'ERROR: srcpkgs/$PKG not found in /io'
	exit 1
fi

XBPS_JOBS=\"\${XBPS_MAKEJOBS:+XBPS_MAKEJOBS=\$XBPS_MAKEJOBS}\"
./xbps-src pkg $PKG \$XBPS_JOBS

find /tmp/void-packages/hostdir/binpkgs/ -name '*.xbps' -exec cp -v {} /output/ \; 2>/dev/null || echo 'No packages found'
echo '=> Build complete.'
" 2>&1 | tee "$LOG_DIR/$PKG.log"

podman stop "$NAME" >/dev/null 2>&1 || true

echo "=> Output:"
ls -la "$OUT_DIR/${PKG}"*.xbps 2>/dev/null || echo 'No packages in output'