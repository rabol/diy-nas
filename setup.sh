#!/bin/bash
set -euo pipefail

# Define constants
SCRIPT_NAME="setup"
SCRIPT_DIR="/opt/nas-setup-scripts"
LOG_FILE="/var/log/nas-setup/${SCRIPT_NAME}.log"

# Load logging functions
if [[ -f "./logging.sh" ]]; then
  source ./logging.sh
else
  echo "ERROR: logging.sh not found."
  exit 1
fi

# Load config functions
if [[ -f "./config.sh" ]]; then
  source ./config.sh
else
  echo "ERROR: config.sh not found."
  exit 1
fi

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  log_error "This script must be run as root."
  exit 1
fi

log_info "Starting initial setup..."

# Create script directory
if [[ ! -d "$SCRIPT_DIR" ]]; then
  mkdir -p "$SCRIPT_DIR"
  chmod 755 "$SCRIPT_DIR"
  log_info "Created script directory: $SCRIPT_DIR"
else
  log_info "Script directory already exists: $SCRIPT_DIR"
fi  

# Create log directory
if [[ ! -d "$LOG_DIR" ]]; then
  mkdir -p "$LOG_DIR"
  chmod 755 "$LOG_DIR"
  log_info "Created log directory: $LOG_DIR"
else
  log_info "Log directory already exists: $LOG_DIR"
fi  

# Copy config file to /etc
if [[ ! -d "/etc/nas-setup" ]]; then
  mkdir -p "/etc/nas-setup"
  chmod 755 "/etc/nas-setup"
  log_info "Created config directory: /etc/nas-setup"
fi

cp "config.sh" "/etc/nas-setup/config.sh"
log_info "Copied config file to /etc/nas-setup/config.sh"

# Copy setup scripts to the script directory
SCRIPT_LIST=(
  02-install-packages.sh
  03-configure-network.sh
  04-storage-setup.sh
  05-install-samba.sh
  06-install-rclone.sh
  07-zfs-snapshot.sh
  08-remote-backup.sh
  09-configure-email.sh
  10-secure-ssh.sh
  11-configure-firewall.sh 
  12-installation-validation.sh
  100-wrapup.sh                 
  create-group-share.sh         
  index.sh                      
  install-cockpit.sh            
  install-webmin.sh             
  logging.sh
  manage-user.sh
)

for file in "${SCRIPT_LIST[@]}"; do
  if [[ -f "$file" ]]; then
    cp "$file" "$SCRIPT_DIR/"
    log_info "Copied $file to $SCRIPT_DIR"
  else
    log_warn "Skipped $file: Not found."
  fi
done

cd "$SCRIPT_DIR"

log_success "Setup complete."

echo -e "\nNext steps:"
echo "1. Review /etc/nas-setup-scripts/config.sh for custom configuration."
echo "2. Run individual scripts from: $SCRIPT_DIR"
echo "   Example: sudo $SCRIPT_DIR/02-install-packages.sh"
echo "3. Or orchestrate with your orchestrator (e.g., index.sh)"