#!/bin/bash
# Build harbour-shadowline for Sailfish OS via sfdk shadow build.
#
# Builds for all three architectures against SailfishOS-5.1.0.11.
#
# Prerequisites:
#   - Sailfish SDK installed with Docker engine
#   - sfdk in PATH (e.g. ~/SailfishOS/bin/sfdk)
#   - Build targets installed: SailfishOS-5.1.0.11-{i486,armv7hl,aarch64}
#
# Usage:
#   ./build-sailfish.sh                  # build all three arches
#   ./build-sailfish.sh aarch64          # build one arch only
#   SAILFISH_VERSION=4.6.0.13 ./build-sailfish.sh  # override SDK version

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="${SAILFISH_VERSION:-5.1.0.11}"
ALL_ARCHES="i486 armv7hl aarch64"
ARCHES="${*:-$ALL_ARCHES}"

mkdir -p "$SCRIPT_DIR/rpms"

for ARCH in $ARCHES; do
    TARGET="SailfishOS-${VERSION}-${ARCH}"
    BUILD_DIR="$SCRIPT_DIR/build-${ARCH}"

    echo ""
    echo "=== Building harbour-shadowline for ${ARCH} (target: ${TARGET}) ==="
    echo ""

    mkdir -p "$BUILD_DIR"

    # Symlink source directories into build dir so the RPM spec's relative paths work
    for d in src qml rpm translations; do
        if [ ! -e "$BUILD_DIR/$d" ]; then
            ln -s "$SCRIPT_DIR/$d" "$BUILD_DIR/$d"
        fi
    done

    cd "$BUILD_DIR"
    sfdk -c target="$TARGET" -c no-fix-version build "$SCRIPT_DIR"

    if ls "$BUILD_DIR"/RPMS/*.rpm >/dev/null 2>&1; then
        cp "$BUILD_DIR"/RPMS/*.rpm "$SCRIPT_DIR/rpms/"
    fi

    echo "=== Done: ${ARCH} ==="
done

echo ""
echo "=== All builds complete ==="
ls -lh "$SCRIPT_DIR/rpms/"*.rpm 2>/dev/null || true
