#!/bin/bash
set -euo pipefail

SCRIPT_NAME="99-install-webmin"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting Webmin installation..."

# Add Webmin repository and key
log "Adding Webmin APT repository and GPG key..."
cat <<EOF > /etc/apt/sources.list.d/webmin.list
deb https://download.webmin.com/download/repository sarge contrib
EOF

wget -qO - https://download.webmin.com/jcameron-key.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/webmin.gpg

log "Updating APT and installing Webmin..."
apt-get update
apt-get install -y webmin

log "Webmin installation complete. It is accessible on port 10000 (HTTPS)."

# Ask user whether to open port 10000 in UFW
read -p "Do you want to allow access to Webmin through UFW (port 10000)? (yes/no): " OPEN_UFW

if [[ "$OPEN_UFW" == "yes" ]]; then
  log "Allowing port 10000 through UFW..."
  ufw allow 10000/tcp
  log "Port 10000 opened."
else
  log "Webmin port not opened via UFW. You may need to configure access manually."
fi

log "Webmin setup script completed."
