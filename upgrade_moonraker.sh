#!/bin/bash

set -e

USER="root"
REPO_URL="https://github.com/Arksine/moonraker"
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

if ! command -v git &> /dev/null; then
    echo "Error: 'git' is not installed."
    exit 1
fi

if ! command -v scp &> /dev/null; then
    echo "Error: 'scp' is not installed."
    exit 1
fi

if ! command -v sshpass &> /dev/null; then
    echo "Error: 'sshpass' is not installed."
    exit 1
fi

WORK_DIR=$(mktemp -d)
SOURCE_TAR="$WORK_DIR/moonraker_source.tar.gz"

echo "Cloning repository..."
git clone --depth 1 "$REPO_URL" "$WORK_DIR/update_src"

echo "Creating compressed tarball..."
tar czf "$SOURCE_TAR" -C "$WORK_DIR/update_src/moonraker" .

DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="/usr/share/moonraker-backup-$DATE.tar.gz"

echo "--- Transferring source code ---"
sshpass -p "$PASS" scp "$SOURCE_TAR" "$USER@$IP:/tmp/moonraker_source.tar.gz"

echo "--- Executing remote update ---"
sshpass -p "$PASS" ssh -o "StrictHostKeyChecking=no" "$USER@$IP" <<EOF
    echo "Extracting tarball..."
    mkdir -p /usr/share/moonraker.new
    tar xzf /tmp/moonraker_source.tar.gz -C /usr/share/moonraker.new

    echo "Installing dependencies (dbus_fast)..."
    /usr/share/moonraker-env/bin/python -m pip install dbus_fast

    echo "Stopping moonraker service..."
    /etc/init.d/moonraker stop || true

    echo "Backing up current directory to $BACKUP_FILE..."
    tar czf "$BACKUP_FILE" -C /usr/share/moonraker .

    if [ -f /usr/share/moonraker/moonraker.conf ]; then
      echo "Preserving configuration file..."
      cp /usr/share/moonraker/moonraker.conf /usr/share/moonraker.new/moonraker.conf
    fi

    echo "Replacing existing moonraker install..."
    mv /usr/share/moonraker /usr/share/moonraker.old
    mv /usr/share/moonraker.new /usr/share/moonraker

    echo "Starting moonraker service..."
    /etc/init.d/moonraker start || exit 1
EOF

echo "--- Cleaning up local resources ---"
rm -rf "$WORK_DIR"

echo "Upgrade complete!"
