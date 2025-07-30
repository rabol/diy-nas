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

log_info "Enabling UFW and setting basic rules..."

if ! command -v ufw &>/dev/null; then
  log_error "ufw is not installed. Install it first with 'apt install ufw'."
  exit 1
fi

ufw allow 22    # SSH
ufw allow 445   # SMB

ufw --force enable
log_info "UFW enabled with rules for SSH and SMB."

log_info "Masking nmbd.service if it exists..."
if systemctl list-unit-files | grep -q nmbd.service; then
  systemctl mask nmbd.service
  log_info "nmbd.service masked."
fi

# Samba validation
SAMBA_HOST="${SAMBA_VALIDATION_HOST:-nas-dry.lan}"
log_info "Attempting Samba validation to host: ${SAMBA_HOST}..."

if ping -c1 -W1 "$SAMBA_HOST" &>/dev/null; then
  if smbclient -L "$SAMBA_HOST" -N &>/dev/null; then
    log_info "Samba validation succeeded."
  else
    log_info "Samba validation failed (smbclient)."
  fi
else
  log_info "Samba validation skipped: $SAMBA_HOST not reachable."
fi

log_success "${SCRIPT_NAME} complete."