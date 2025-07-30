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
log_info "Starting snapshot setup..."

# Install zfs-auto-snapshot
log_info "Installing zfs-auto-snapshot..."
apt-get update >> "$LOG_FILE" 2>&1
apt-get install -y zfs-auto-snapshot >> "$LOG_FILE" 2>&1
log_info "zfs-auto-snapshot installed successfully."

# Verify installation
if ! command -v zfs-auto-snapshot &>/dev/null; then
  log_error "zfs-auto-snapshot failed to install properly."
  exit 1
fi

# Configure retention
log_info "Configuring snapshot retention..."
sed -i 's/^KEEP_HOURLY=.*/KEEP_HOURLY=24/' /etc/cron.hourly/zfs-auto-snapshot || true
sed -i 's/^KEEP_DAILY=.*/KEEP_DAILY=7/' /etc/cron.daily/zfs-auto-snapshot || true
sed -i 's/^KEEP_WEEKLY=.*/KEEP_WEEKLY=4/' /etc/cron.weekly/zfs-auto-snapshot || true

log_info "Retention policy: 24 hourly, 7 daily, 4 weekly."
log_success "Snapshot retention configured."