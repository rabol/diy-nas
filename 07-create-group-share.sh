#!/bin/bash
set -euo pipefail

SCRIPT_NAME="07-create-group-share"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

if [[ "$#" -lt 3 ]]; then
  echo "Usage: $0 <groupname> <pool> <dataset> [user1 user2 ...]"
  exit 1
fi

GROUP="$1"
POOL="$2"
DATASET="$3"
shift 3
USERS=("$@")

SHARE_PATH="/${POOL}/${DATASET}"
SMB_USERS_CONF="/etc/samba/users.conf"
GROUP_SMB_CONF="/etc/samba/users.d/${DATASET}.conf"

log "Starting group share setup for group '${GROUP}' at ${SHARE_PATH}"

# Create group if not exists
if getent group "$GROUP" > /dev/null; then
  log "Group '${GROUP}' already exists."
else
  log "Creating group '${GROUP}'..."
  groupadd "$GROUP"
fi

# Create directory if it doesn't exist
if [[ ! -d "$SHARE_PATH" ]]; then
  log "Creating share directory at '${SHARE_PATH}'..."
  mkdir -p "$SHARE_PATH"
fi

# Set ownership and permissions
log "Setting ownership and permissions for '${SHARE_PATH}'..."
chown root:"$GROUP" "$SHARE_PATH"
chmod 2770 "$SHARE_PATH"

# Add users to group
for USER in "${USERS[@]}"; do
  if id "$USER" &>/dev/null; then
    log "Adding user '$USER' to group '$GROUP'..."
    usermod -aG "$GROUP" "$USER"
  else
    log "WARNING: User '$USER' does not exist."
  fi
done

# Create Samba config
log "Creating Samba config at '${GROUP_SMB_CONF}'..."
tee "$GROUP_SMB_CONF" > /dev/null <<EOF
[${DATASET}]
   path = ${SHARE_PATH}
   valid users = @${GROUP}
   force group = ${GROUP}
   create mask = 0660
   directory mask = 2770
   read only = no
   browsable = yes
EOF

# Include config if not already present
if ! grep -Fxq "include = $GROUP_SMB_CONF" "$SMB_USERS_CONF"; then
  log "Appending include to $SMB_USERS_CONF"
  echo "include = $GROUP_SMB_CONF" >> "$SMB_USERS_CONF"
fi

log "Reloading Samba..."
systemctl reload smbd

log "Group share '${DATASET}' created and configured."
