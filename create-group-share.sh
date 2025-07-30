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

log_info "Starting group share setup for group '${GROUP}' at ${SHARE_PATH}"

# Create group if not exists
if getent group "$GROUP" > /dev/null; then
  log_info "Group '${GROUP}' already exists."
else
  log_info "Creating group '${GROUP}'..."
  groupadd "$GROUP"
fi

# Create directory if it doesn't exist
if [[ ! -d "$SHARE_PATH" ]]; then
  log_info "Creating share directory at '${SHARE_PATH}'..."
  mkdir -p "$SHARE_PATH"
fi

# Set ownership and permissions
log_info "Setting ownership and permissions for '${SHARE_PATH}'..."
chown root:"$GROUP" "$SHARE_PATH"
chmod 2770 "$SHARE_PATH"

# Add users to group
for USER in "${USERS[@]}"; do
  if id "$USER" &>/dev/null; then
    log_info "Adding user '$USER' to group '$GROUP'..."
    usermod -aG "$GROUP" "$USER"
  else
    log_info "WARNING: User '$USER' does not exist."
  fi
done

# Create Samba config
log_info "Creating Samba config at '${GROUP_SMB_CONF}'..."
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
  log_info "Appending include to $SMB_USERS_CONF"
  echo "include = $GROUP_SMB_CONF" >> "$SMB_USERS_CONF"
fi

log_info "Reloading Samba..."
systemctl reload smbd

log_info "Group share '${DATASET}' created and configured."
