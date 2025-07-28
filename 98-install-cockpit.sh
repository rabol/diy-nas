#!/bin/bash
set -euo pipefail

SCRIPT_NAME="98-install-cockpit"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Installing Cockpit and optional modules..."

# Install cockpit and optional NAS tools
apt-get update >> "$LOG_FILE" 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y   cockpit   cockpit-networkmanager   cockpit-storaged   cockpit-packagekit   cockpit-samba   cockpit-dashboard >> "$LOG_FILE" 2>&1

# Enable cockpit.socket
log "Enabling and starting cockpit..."
systemctl enable --now cockpit.socket >> "$LOG_FILE" 2>&1

log "Cockpit is now available at https://<NAS_IP>:9090/"
log "Installation complete."

# Open Cockpit port in UFW if firewall is active
if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
  log "UFW is active. Allowing port 9090 for Cockpit..."
  ufw allow 9090/tcp >> "$LOG_FILE" 2>&1
  log "Port 9090 opened in UFW."
else
  log "UFW is not active or not installed. Skipping firewall rule for Cockpit."
fi
