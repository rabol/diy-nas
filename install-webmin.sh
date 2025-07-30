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

log_info "Starting Webmin installation..."

# Add Webmin repository and key
log_info "Adding Webmin APT repository and GPG key..."
cat <<EOF > /etc/apt/sources.list.d/webmin.list
deb https://download.webmin.com/download/repository sarge contrib
EOF

wget -qO - https://download.webmin.com/jcameron-key.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/webmin.gpg

log_info "Updating APT and installing Webmin..."
apt-get update
apt-get install -y webmin

log_info "Webmin installation complete. It is accessible on port 10000 (HTTPS)."

# Ask user whether to open port 10000 in UFW
read -p "Do you want to allow access to Webmin through UFW (port 10000)? (yes/no): " OPEN_UFW

if [[ "$OPEN_UFW" == "yes" ]]; then
  log_info "Allowing port 10000 through UFW..."
  ufw allow 10000/tcp
  log_info "Port 10000 opened."
else
  log_info "Webmin port not opened via UFW. You may need to configure access manually."
fi

log_info "Webmin setup script completed."
