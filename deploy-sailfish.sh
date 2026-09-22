#!/bin/bash
# Deploy harbour-shadowline RPM to Sailfish OS device.
#
# Usage:
#   ./deploy-sailfish.sh [path-to-rpm] [target-host]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RPM_PATH="$1"
TARGET_HOST="$2"

# 1. Locate RPM package
if [ -z "$RPM_PATH" ] || [ ! -f "$RPM_PATH" ]; then
    if [ -n "$RPM_PATH" ] && [ ! -f "$RPM_PATH" ]; then
        if [ -z "$TARGET_HOST" ]; then
            TARGET_HOST="$RPM_PATH"
            RPM_PATH=""
        fi
    fi
fi

if [ -z "$RPM_PATH" ]; then
    RPM_PATH="$(ls -t "$SCRIPT_DIR/rpms/"*.rpm 2>/dev/null | head -n 1 || true)"
    if [ -z "$RPM_PATH" ]; then
        RPM_PATH="$(ls -t "$SCRIPT_DIR/"*.rpm 2>/dev/null | head -n 1 || true)"
    fi
fi

if [ -z "$RPM_PATH" ] || [ ! -f "$RPM_PATH" ]; then
    echo "ERROR: No RPM package found. Build first with ./build-sailfish.sh"
    exit 1
fi

RPM_FILE="$(basename "$RPM_PATH")"

# 2. Determine target host
if [ -z "$TARGET_HOST" ]; then
    if [ -n "$PHONE_HOST" ]; then
        TARGET_HOST="$PHONE_HOST"
    else
        for candidate in phone-wifi phone-usb phone-bt 192.168.1.200 192.168.2.15 172.28.172.1; do
            if ssh -o ConnectTimeout=2 -o BatchMode=yes "$candidate" true 2>/dev/null; then
                TARGET_HOST="$candidate"
                break
            fi
        done
        TARGET_HOST="${TARGET_HOST:-phone-wifi}"
    fi
fi

echo "=== Deploying $RPM_FILE to $TARGET_HOST ==="

# 3. Verify SSH connectivity
echo "Checking connection to $TARGET_HOST..."
REMOTE_INFO="$(ssh -o ConnectTimeout=5 "$TARGET_HOST" 'id -u; echo "$HOME"' 2>/dev/null)" || {
    echo "ERROR: Cannot connect to $TARGET_HOST. Check SSH and developer mode."
    exit 1
}

REMOTE_UID="$(echo "$REMOTE_INFO" | sed -n '1p')"
REMOTE_HOME="$(echo "$REMOTE_INFO" | sed -n '2p')"
REMOTE_DOWNLOADS="$REMOTE_HOME/Downloads"
REMOTE_DEST="$REMOTE_DOWNLOADS/$RPM_FILE"

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
