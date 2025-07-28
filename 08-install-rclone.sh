#!/bin/bash
set -euo pipefail

SCRIPT_NAME="08-install-rclone"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting rclone installation..."

# Remove any previously installed rclone
if dpkg -l | grep -q rclone; then
  log "Removing existing rclone package..."
  apt-get remove -y rclone >> "$LOG_FILE" 2>&1 || true
fi

# Download and install the latest version from rclone.org
log "Downloading and installing the latest stable rclone..."
curl -fsSL https://rclone.org/install.sh | bash >> "$LOG_FILE" 2>&1

# Validate installation
if ! command -v rclone &> /dev/null; then
  log "ERROR: rclone installation failed."
  exit 1
fi

log "rclone successfully installed."
log "Installed version: $(rclone version | head -n 1)"

log "NOTE: You must now run 'rclone config' manually to set up remotes."
log "Configuration files are stored in: $HOME/.config/rclone/rclone.conf"

log "08-install-rclone complete."
