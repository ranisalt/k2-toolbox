#!/bin/bash

set -e

USER="root"
REPO_URL="https://github.com/Arksine/moonraker"
ARCHIVE_URL="$REPO_URL/archive/refs/heads/master.tar.gz"
TARGET_DIR="/usr/share/moonraker"
PASS="creality_2024"

IP=$1
if [ -z "$IP" ]; then
    read -p "Enter printer IP: " IP
fi

if [ -z "$IP" ]; then
    echo "Error: No IP provided."
    exit 1
fi

if ! command -v scp >/dev/null 2>&1; then
    echo "Error: 'scp' is not installed."
    exit 1
fi

if ! command -v sshpass >/dev/null 2>&1; then
    echo "Error: 'sshpass' is not installed."
    exit 1
fi

WORK_DIR=$(mktemp -d)
UPDATE_SRC="$WORK_DIR/update_src"
SOURCE_TAR="$WORK_DIR/moonraker_source.tar.gz"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "Obtaining source archive..."

if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 -o "$SOURCE_TAR" "$ARCHIVE_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$SOURCE_TAR" "$ARCHIVE_URL"
elif command -v busybox >/dev/null 2>&1 && busybox wget --help >/dev/null 2>&1; then
    busybox wget -O "$SOURCE_TAR" "$ARCHIVE_URL"
elif command -v git >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    echo "No HTTP downloader found. Falling back to git clone + git archive..."

    git clone --depth 1 "$REPO_URL" "$UPDATE_SRC"
    git -C "$UPDATE_SRC" archive \
        --format=tar.gz \
        --prefix=moonraker-master/ \
        -o "$SOURCE_TAR" \
        HEAD
else
    echo "Error: could not obtain source archive: curl, wget, busybox wget, or git+tar are required." >&2
    exit 1
fi

if [ ! -s "$SOURCE_TAR" ]; then
    echo "Error: could not obtain source archive from $ARCHIVE_URL or $REPO_URL." >&2
    exit 1
fi

DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$TARGET_DIR-backup-$DATE.tar.gz"

echo "--- Transferring source code ---"
sshpass -p "$PASS" scp "$SOURCE_TAR" "$USER@$IP:/tmp/moonraker_source.tar.gz"

echo "--- Executing remote update ---"
sshpass -p "$PASS" ssh -o "StrictHostKeyChecking=no" "$USER@$IP" <<EOF
    set -e

    echo "Extracting tarball..."
    rm -rf "$TARGET_DIR.new"
    mkdir -p "$TARGET_DIR.new"
    tar xzf /tmp/moonraker_source.tar.gz -C "$TARGET_DIR.new" --strip-components=1

    echo "Installing dependencies (dbus_fast)..."
    /usr/share/moonraker-env/bin/python -m pip install dbus_fast

    echo "Stopping moonraker service..."
    /etc/init.d/moonraker stop || true

    echo "Backing up current directory to $BACKUP_FILE..."
    tar czf "$BACKUP_FILE" -C "$TARGET_DIR" .

    if [ -f "$TARGET_DIR/moonraker.conf" ]; then
      echo "Preserving configuration file..."
      cp "$TARGET_DIR/moonraker.conf" "$TARGET_DIR.new/moonraker.conf"
    fi

    echo "Replacing existing moonraker install..."
    rm -rf "$TARGET_DIR.old"
    mv "$TARGET_DIR" "$TARGET_DIR.old"
    mv "$TARGET_DIR.new" "$TARGET_DIR"

    echo "Starting moonraker service..."
    /etc/init.d/moonraker start
EOF

echo "Upgrade complete!"
