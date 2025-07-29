#!/bin/bash
set -euo pipefail

# Check for root
if [[ $EUID -ne 0 ]]; then
  echo "❌ This script must be run as root. Please use sudo."
  exit 1
fi

LOG_DIR="/var/log/nas-setup"
mkdir -p "$LOG_DIR"

run_script() {
  local script="$1"
  local base_name
  base_name=$(basename "$script" .sh)
  local log_file="$LOG_DIR/${base_name}.log"

  echo "==== Running: $script ====" | tee -a "$log_file"
  if bash "./$script" >> "$log_file" 2>&1; then
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
run_script "06-manage-user.sh"
run_script "07-create-group-share.sh"
run_script "08-install-rclone.sh"
run_script "09-snapshot-backup.sh"
run_script "10-configure-email.sh"
run_script "11-secure-ssh.sh"
run_script "12-configure-firewall.sh"
run_script "13-validate-installation.sh"

# Optional tools
# run_script "98-install-cockpit.sh"
# run_script "99-install-webmin.sh"
# run_script "100-wrapup.sh"

echo "✅ All selected setup steps completed."