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

log_info "Starting package installation..."

# Refresh APT metadata
log_info "Updating package list..."
apt-get update >> "$LOG_FILE" 2>&1
apt-get upgrade -y >> "$LOG_FILE" 2>&1

# Avoid time-daemon conflicts
log_info "Removing conflicting time-daemon packages..."
apt-get purge -y ntpsec >> "$LOG_FILE" 2>&1 || true
apt-mark hold ntpsec >> "$LOG_FILE" 2>&1

# Ensure systemd-networkd is enabled
log_info "Enabling systemd-networkd..."
systemctl enable systemd-networkd >> "$LOG_FILE" 2>&1
systemctl start systemd-networkd >> "$LOG_FILE" 2>&1

# Install core packages
log_info "Installing required packages..."

PACKAGE_LIST=(
  zfsutils-linux
  zfs-auto-snapshot
  samba
  avahi-daemon
  smartmontools
  curl
  wget
  htop
  unzip
  git
  msmtp
  bsd-mailx
  ufw
  smbclient
  libnss-winbind
  winbind
  avahi-utils
  libnss-mdns
  rclone
)

for pkg in "${PACKAGE_LIST[@]}"; do
  if dpkg -s "$pkg" &>/dev/null; then
    log_info "Package '$pkg' already installed, skipping."
  else
    log_info "Installing package: $pkg"
    apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1
  fi
done

log_success "Package installation complete."