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
log_info "Starting rclone installation..."

# Remove any previously installed rclone
if dpkg -l | grep -q rclone; then
  log_info "Removing existing rclone package..."
  apt-get remove -y rclone >> "$LOG_FILE" 2>&1 || true
fi

# Download and install latest version from official site
log_info "Downloading and installing the latest stable rclone..."
curl -fsSL https://rclone.org/install.sh | bash >> "$LOG_FILE" 2>&1

# Validate installation
if ! command -v rclone &> /dev/null; then
  log_error "rclone installation failed."
  exit 1
fi

RCLONE_VERSION=$(rclone version 2>&1 | head -n 1)
log_info "rclone successfully installed."
log_info "Installed version: ${RCLONE_VERSION}"

log_info "NOTE: You must now run 'rclone config' manually to set up remotes."
log_info "Configuration file: \$HOME/.config/rclone/rclone.conf"

log_success "${SCRIPT_NAME} complete."