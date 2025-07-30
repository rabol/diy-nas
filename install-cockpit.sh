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

log_info "Installing Cockpit and optional modules..."

# Install cockpit and optional NAS tools
apt-get update >> "$LOG_FILE" 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y   cockpit   cockpit-networkmanager   cockpit-storaged   cockpit-packagekit   cockpit-samba   cockpit-dashboard >> "$LOG_FILE" 2>&1

# Enable cockpit.socket
log_info "Enabling and starting cockpit..."
systemctl enable --now cockpit.socket >> "$LOG_FILE" 2>&1

log_info "Cockpit is now available at https://<NAS_IP>:9090/"
log_info "Installation complete."

# Open Cockpit port in UFW if firewall is active
if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
  log_info "UFW is active. Allowing port 9090 for Cockpit..."
  ufw allow 9090/tcp >> "$LOG_FILE" 2>&1
  log_info "Port 9090 opened in UFW."
else
  log_info "UFW is not active or not installed. Skipping firewall rule for Cockpit."
fi
