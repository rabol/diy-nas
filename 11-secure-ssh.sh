#!/bin/bash
set -euo pipefail

SCRIPT_NAME="11-secure-ssh"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting SSH hardening..."

if [[ -f /etc/ssh/sshd_config ]]; then
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  if systemctl list-units --type=service | grep -qE 'ssh\.service|sshd\.service'; then
    systemctl restart ssh || systemctl restart sshd || log "Warning: Failed to restart SSH service"
    log "SSH password authentication disabled and service restarted."
  else
    log "Warning: SSH service not found."
  fi
else
  log "Warning: /etc/ssh/sshd_config not found. SSH hardening skipped."
fi

log "SSH hardening complete."
