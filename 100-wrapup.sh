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

read -rp "Do you want to remove unused packages? (yes/no): " ANSWER
if [[ "$ANSWER" =~ ^(yes|y)$ ]]; then
  log_info "Removing unused packages..."
  apt-get autoremove -y >> "$LOG_FILE" 2>&1
  log_info "Unused packages removed."
else
  log_info "Package cleanup skipped."
fi

log_info "Please review the following post-install checks manually:"
log_info " - Cockpit (if installed) accessible at: https://<NAS_IP>:9090"
log_info " - Webmin (if installed) accessible at: https://<NAS_IP>:10000"
log_info " - Samba shares are mountable from your client systems"
log_info " - Time Machine is discoverable on macOS (via mDNS)"
log_info " - Email alert (Step 10) test succeeded"
log_info " - Snapshot and backup jobs (Step 9) are scheduled"

echo
read -rp "Do you want to reboot now? [y/N]: " confirm
if [[ "${confirm,,}" =~ ^(y|yes)$ ]]; then
  log_info "User chose to reboot now."
  reboot
else
  log_info "User skipped reboot. Setup is complete."
fi

log_success "Wrap-up complete. System is ready."