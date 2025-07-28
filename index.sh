#!/bin/bash
set -euo pipefail

LOG_DIR="/var/log/nas-setup"
mkdir -p "$LOG_DIR"

log() {
  local script="$1"
  echo "==== Running: $script ===="
  bash "./$script"
  echo "==== Completed: $script ===="
  echo
}

# Main execution order (comment/uncomment optional steps as needed)

log "02-install-packages.sh"
log "03-configure-network.sh"
log "04-storage-setup.sh"
log "05-install-samba.sh"
log "06-manage-user.sh"
log "07-create-group-share.sh"
log "08-install-rclone.sh"
log "09-snapshot-backup.sh"
log "10-configure-email.sh"
log "11-secure-ssh.sh"
log "12-configure-firewall.sh"
log "13-validate-installation.sh"

# Optional tools
# log "98-install-cockpit.sh"
# log "99-install-webmin.sh"
# log "100-wrapup.sh"

echo "All selected setup steps completed."
