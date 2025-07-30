#!/bin/bash
set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  log_error "This script must be run as root."
  exit 1
fi

# Load logging functions
if [[ -f "./logging.sh" ]]; then
  source ./logging.sh
else
  echo "ERROR: logging.sh not found."
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


run_script() {
  local script="$1"
  local base_name
  base_name=$(basename "$script" .sh)
  local log_file="$LOG_DIR/${base_name}.log"

  echo "==== Running: $script ====" | tee -a "$log_file"
  # Run with live output and logging, preserve interactivity
  if bash "./$script" 2>&1 | tee -a "$log_file"; then
    echo "==== Completed: $script ====" | tee -a "$log_file"
  else
    echo "❌ ERROR in $script — check log: $log_file" | tee -a "$log_file"
    exit 1
  fi
  echo
}

# Main execution order (comment/uncomment optional steps as needed)
run_script "02-install-packages.sh"
run_script "03-configure-network.sh"
run_script "04-storage-setup.sh"
run_script "05-install-samba.sh"
run_script "06-install-rclone.sh"
run_script "07-zfs-snapshot.sh"
run_script "08-remote-backup.sh"
run_script "09-configure-email.sh"
run_script "10-secure-ssh.sh"
run_script "11-configure-firewall.sh"
run_script "12-installation-validation.sh"
run_script "100-wrapup.sh"

# Optional tools
# run_script "install-cockpit.sh"
# run_script "install-webmin.sh"


echo "✅ All selected setup steps completed."