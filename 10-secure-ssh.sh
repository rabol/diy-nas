#!/bin/bash
set -euo pipefail

# Load logging functions
if [[ -f "./logging.sh" ]]; then
  source ./logging.sh
else
  echo "ERROR: logging.sh not found."
  exit 1
fi

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  log_error "This script must be run as root."
  exit 1
fi

# Load config
CONFIG_FILE="/etc/nas-setup-scripts/config.sh"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  log_error "Missing config file at $CONFIG_FILE"
  exit 1
fi

SCRIPT_NAME="$(basename "$0")"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

# Ask user for confirmation
read -rp "Do you want to continue with ${SCRIPT_NAME}? (yes/no): " ANSWER
ANSWER="${ANSWER,,}"  # Convert to lowercase

if [[ "$ANSWER" != "yes" && "$ANSWER" != "y"]]; then
  log_info "${SCRIPT_NAME} skipped by user."
  exit 0
fi

###### -- Main script starts here - ######
log_info "Starting SSH hardening..."

if [[ -f /etc/ssh/sshd_config ]]; then
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
  log_info "Backed up sshd_config to sshd_config.bak"

  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

  if systemctl list-units --type=service | grep -qE 'ssh\.service|sshd\.service'; then
    systemctl restart sshd || systemctl restart ssh || log_info "Warning: Failed to restart SSH service"
    log_info "SSH password authentication disabled and service restarted."
  else
    log_info "Warning: SSH service not found."
  fi
else
  log_info "Warning: /etc/ssh/sshd_config not found. SSH hardening skipped."
fi

log_info "SSH hardening complete."