#!/bin/bash
set -euo pipefail

SCRIPT_NAME="12-configure-firewall"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Enabling UFW and setting basic rules..."

ufw allow 22    # SSH
ufw allow 445   # SMB

ufw --force enable
log "UFW enabled with rules for SSH and SMB."

log "Masking nmbd.service if it exists..."
if systemctl list-unit-files | grep -q nmbd.service; then
  systemctl mask nmbd.service
  log "nmbd.service masked."
fi

log "Attempting Samba validation..."
if ping -c1 -W1 nas-dry.lan &>/dev/null; then
  if smbclient -L nas-dry.lan -N &>/dev/null; then
    log "Samba validation succeeded."
  else
    log "Samba validation failed (smbclient)."
  fi
else
  log "Samba validation skipped: nas-dry.lan not reachable."
fi

log "Firewall configuration complete."
