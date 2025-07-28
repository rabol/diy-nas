#!/bin/bash
set -euo pipefail

SCRIPT_NAME="02-install-packages"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting package installation..."

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  log "ERROR: This script must be run as root."
  exit 1
fi

# Refresh APT metadata
log "Updating package list..."
apt-get update

# Avoid time-daemon conflicts
log "Removing conflicting time-daemon packages..."
apt-get purge -y ntpsec || true
apt-mark hold ntpsec

# Ensure systemd-networkd is enabled
log "Enabling systemd-networkd..."
systemctl enable systemd-networkd
systemctl start systemd-networkd

# Install core packages
log "Installing required packages..."
apt-get install -y \
    zfsutils-linux \
    samba \
    avahi-daemon \
    smartmontools \
    curl \
    wget \
    htop \
    unzip \
    git \
    msmtp \
    bsd-mailx \
    ufw


# Samba-related packages
log "Installing Samba and support packages..."
apt-get install -y \
    samba \
    smbclient \
    libnss-winbind \
    winbind \
    avahi-daemon \
    avahi-utils \
    libnss-mdns

log "Package installation complete."

 