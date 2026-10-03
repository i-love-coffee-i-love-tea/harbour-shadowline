#!/bin/bash
# Deploy harbour-shadowline RPM to Sailfish OS device.
#
# Usage:
#   ./deploy-sailfish.sh [path-to-rpm] [target-host]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ARG1="$1"
ARG2="$2"

if [ -n "$ARG1" ] && [ -f "$ARG1" ]; then
    RPM_PATH="$ARG1"
    TARGET_HOST="$ARG2"
elif [ -n "$ARG1" ]; then
    TARGET_HOST="$ARG1"
    RPM_PATH="$ARG2"
fi

# 1. Determine target host
if [ -z "$TARGET_HOST" ]; then
    if [ -n "$PHONE_HOST" ]; then
        TARGET_HOST="$PHONE_HOST"
    else
        for candidate in xa2 xperia10 phone-wifi phone-usb phone-bt 192.168.1.105 192.168.1.101 192.168.1.200 192.168.2.15 172.28.172.1; do
            if ssh -o ConnectTimeout=2 -o BatchMode=yes "$candidate" true 2>/dev/null; then
                TARGET_HOST="$candidate"
                break
            fi
        done
        TARGET_HOST="${TARGET_HOST:-phone-wifi}"
    fi
fi

# 2. Verify SSH connectivity and target architecture
echo "Checking connection to $TARGET_HOST..."
REMOTE_INFO="$(ssh -o ConnectTimeout=5 "$TARGET_HOST" 'id -u; echo "$HOME"; ARCH=$(rpm -E "%{_arch}" 2>/dev/null); [ "$ARCH" = "arm" ] && ARCH=armv7hl; echo "${ARCH:-$(uname -m)}"' 2>/dev/null)" || {
    echo "ERROR: Cannot connect to $TARGET_HOST. Check SSH and developer mode."
    exit 1
}

REMOTE_UID="$(echo "$REMOTE_INFO" | sed -n '1p')"
REMOTE_HOME="$(echo "$REMOTE_INFO" | sed -n '2p')"
TARGET_ARCH="$(echo "$REMOTE_INFO" | sed -n '3p')"
REMOTE_DOWNLOADS="$REMOTE_HOME/Downloads"

# 3. Locate RPM package (prefer architecture matching target device)
if [ -z "$RPM_PATH" ] || [ ! -f "$RPM_PATH" ]; then
    RPM_PATH=""
    if [ -n "$TARGET_ARCH" ]; then
        RPM_PATH="$(ls -t "$SCRIPT_DIR/rpms/"*."$TARGET_ARCH".rpm 2>/dev/null | head -n 1 || true)"
    fi
    if [ -z "$RPM_PATH" ]; then
        RPM_PATH="$(ls -t "$SCRIPT_DIR/rpms/"*.rpm 2>/dev/null | head -n 1 || true)"
    fi
    if [ -z "$RPM_PATH" ]; then
        RPM_PATH="$(ls -t "$SCRIPT_DIR/"*.rpm 2>/dev/null | head -n 1 || true)"
    fi
fi

if [ -z "$RPM_PATH" ] || [ ! -f "$RPM_PATH" ]; then
    echo "ERROR: No RPM package found. Build first with ./build-sailfish.sh"
    exit 1
fi

RPM_FILE="$(basename "$RPM_PATH")"
REMOTE_DEST="$REMOTE_DOWNLOADS/$RPM_FILE"

echo "=== Deploying $RPM_FILE to $TARGET_HOST ($TARGET_ARCH) ==="

# 4. Copy and install
echo "Stopping any running harbour-shadowline on $TARGET_HOST..."
ssh "$TARGET_HOST" 'killall -9 harbour-shadowline 2>/dev/null || true'

echo "Copying $RPM_FILE to device..."
ssh "$TARGET_HOST" "mkdir -p '$REMOTE_DOWNLOADS'"
scp -p "$RPM_PATH" "$TARGET_HOST:$REMOTE_DEST"

echo "Triggering install dialog..."
ssh "$TARGET_HOST" bash -s <<EOF
set -e
BUS="unix:path=/run/user/$REMOTE_UID/dbus/user_bus_socket"
if [ ! -e "/run/user/$REMOTE_UID/dbus/user_bus_socket" ]; then
    BUS="\$DBUS_SESSION_BUS_ADDRESS"
fi
DBUS_SESSION_BUS_ADDRESS="\$BUS" gdbus call --session \
    --dest org.sailfishos.fileservice \
    --object-path / \
    --method org.sailfishos.fileservice.openUrl \
    "file://$REMOTE_DEST" >/dev/null 2>&1 || true
EOF

echo "=== Done! Check your phone to confirm installation. ==="
