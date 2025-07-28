#!/bin/bash
set -euo pipefail

SCRIPT_NAME="13-validate-installation"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "=== NAS Installation Validation Started ==="

# --- ZFS Pools and Datasets ---
log "Checking available ZFS pools..."
zpool list -H -o name | while read -r pool; do
  if zpool status "$pool" &>/dev/null; then
    log "ZFS pool '$pool' is healthy."
    datasets=$(zfs list -H -o name -r "$pool" | grep -v "^$pool$")
    if [[ -z "$datasets" ]]; then
      log "  No datasets found in pool '$pool'."
    else
      log "  Found datasets in '$pool':"
      echo "$datasets" | while read -r ds; do
        log "    $ds"
      done
    fi
  else
    log "ERROR: ZFS pool '$pool' not found or unhealthy."
  fi
done

# --- Samba Status ---
if systemctl is-active smbd &>/dev/null; then
  log "Samba (smbd) is active."
else
  log "WARNING: smbd is not running."
fi

if [[ -f /etc/samba/users.conf ]]; then
  log "Found Samba user config: /etc/samba/users.conf"
else
  log "WARNING: /etc/samba/users.conf not found."
fi

# --- SSH Service ---
if systemctl is-enabled ssh &>/dev/null || systemctl is-active ssh &>/dev/null; then
  log "SSH service is running and/or enabled."
else
  log "WARNING: SSH service is not running or enabled."
fi

# --- UFW Firewall ---
log "Checking UFW status..."
ufw status verbose | tee -a "$LOG_FILE"

# --- Avahi/mDNS ---
if systemctl is-active avahi-daemon &>/dev/null; then
  if avahi-browse -rt _adisk._tcp | grep -q 'TimeMachine'; then
    log "Avahi is advertising Time Machine service."
  else
    log "WARNING: Avahi is active but Time Machine service is not advertised."
  fi
else
  log "WARNING: Avahi daemon is not running."
fi

# --- Summary ---
log "Validation complete. Review the log at: $LOG_FILE"
