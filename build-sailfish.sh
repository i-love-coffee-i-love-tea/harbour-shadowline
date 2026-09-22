#!/bin/bash
# Build harbour-shadowline for Sailfish OS via sfdk build.
#
# Prerequisites:
#   - Sailfish SDK installed with Docker engine
#   - sfdk in PATH (e.g. ~/SailfishOS/bin/sfdk)
#   - Build target set: e.g. SailfishOS-5.1.0.11-aarch64

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${SAILFISH_TARGET:-SailfishOS-5.1.0.11-aarch64}"

echo "=== Building harbour-shadowline via sfdk (target: $TARGET) ==="
cd "$SCRIPT_DIR"
sfdk -c target="$TARGET" build

echo "=== Copying RPM to rpms/ ==="
mkdir -p "$SCRIPT_DIR/rpms"
if ls "$SCRIPT_DIR"/RPMS/*.rpm >/dev/null 2>&1; then
    mv "$SCRIPT_DIR"/RPMS/*.rpm "$SCRIPT_DIR/rpms/"
    rmdir "$SCRIPT_DIR/RPMS" 2>/dev/null || true
else
    echo "WARNING: No RPMs found in RPMS/" >&2
fi

echo "=== Done ==="
ls -lh "$SCRIPT_DIR/rpms/"*.rpm 2>/dev/null || true
