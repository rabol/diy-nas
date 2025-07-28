#!/bin/bash
set -euo pipefail

SCRIPT_NAME="100-wrapup"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "=== Final Setup Summary and Optional Reboot ==="

echo
log "Please review the following post-install checks manually:"
echo " - Cockpit (if installed) accessible at: https://<NAS_IP>:9090"
echo " - Webmin (if installed) accessible at: https://<NAS_IP>:10000"
echo " - Samba shares are mountable from your client systems"
echo " - Time Machine is discoverable on macOS (via mDNS)"
echo " - Email alert (Step 10) test succeeded"
echo " - Snapshot and backup jobs (Step 9) are scheduled"

echo
read -rp "Do you want to reboot now? [y/N]: " confirm
if [[ "${confirm,,}" == "y" ]]; then
  log "User chose to reboot now."
  reboot
else
  log "User skipped reboot. Setup is complete."
fi
