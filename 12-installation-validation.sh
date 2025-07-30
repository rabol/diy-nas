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

log_info "NAS Installation Validation Started"

# --- ZFS Pools and Datasets ---
log_info "Checking available ZFS pools..."
zpool list -H -o name | while read -r pool; do
  if zpool status "$pool" &>/dev/null; then
    log_info "ZFS pool '$pool' is healthy."
    datasets=$(zfs list -H -o name -r "$pool" | grep -v "^$pool$")
    if [[ -z "$datasets" ]]; then
      log_info "  No datasets found in pool '$pool'."
    else
      log_info "  Found datasets in '$pool':"
      echo "$datasets" | while read -r ds; do
        log_info "    $ds"
      done
    fi
  else
    log_info "ERROR: ZFS pool '$pool' not found or unhealthy."
  fi
done

# --- Samba Status ---
if systemctl is-active smbd &>/dev/null; then
  log_info "Samba (smbd) is active."
else
  log_info "WARNING: smbd is not running."
fi

if [[ -f /etc/samba/users.conf ]]; then
  log_info "Found Samba user config: /etc/samba/users.conf"
else
  log_warn "WARNING: /etc/samba/users.conf not found."
fi

# --- SSH Service ---
if systemctl is-enabled ssh &>/dev/null || systemctl is-active ssh &>/dev/null; then
  log_info "SSH service is running and/or enabled."
else
  log_info "WARNING: SSH service is not running or enabled."
fi

# --- UFW Firewall ---
log_info "Checking UFW status..."
ufw status verbose | tee -a "$LOG_FILE"

# --- Avahi/mDNS ---
if systemctl is-active avahi-daemon &>/dev/null; then
  if avahi-browse -rt _adisk._tcp | grep -q 'TimeMachine'; then
    log_info "Avahi is advertising Time Machine service."
  else
    log_info "WARNING: Avahi is active but Time Machine service is not advertised."
  fi
else
  log_info "WARNING: Avahi daemon is not running."
fi

# --- Summary ---
log_info "Validation complete. Review the log at: $LOG_FILE"
