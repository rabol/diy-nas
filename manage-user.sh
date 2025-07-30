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




ACTION="${1:-}"
USERNAME="${2:-}"
POOL="${3:-}"

if [[ -z "$ACTION" ]]; then
  echo "No action specified. What do you want to do?"
  select ACTION in add remove quit; do
    [[ -n "$ACTION" ]] && break
  done
fi

if [[ "$ACTION" == "quit" ]]; then
  log_info "Aborting user management."
  exit 0
fi

if [[ -z "$USERNAME" ]]; then
  read -rp "Enter the username: " USERNAME
fi

if [[ "$ACTION" == "add" && -z "$POOL" ]]; then
  read -rp "Enter the ZFS pool (optional): " POOL
fi

set -euo pipefail

SCRIPT_NAME="06-manage-user"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

if [[ "$#" -lt 2 ]]; then
  echo "Usage:"
  echo "  $0 add <username> [pool]"
  echo "  $0 remove <username>"
  exit 1
fi

ACTION=$1
USERNAME=$2
POOL=${3:-tank_hdd}  # Default to 'tank_hdd' if not provided

USER_HOME="/${POOL}/homes/${USERNAME}"
TIMEMACHINE_DIR="/${POOL}/timemachine/${USERNAME}"
SMB_USERS_CONF="/etc/samba/users.conf"
USER_SMB_CONF="/etc/samba/users.d/${USERNAME}.conf"

if [[ "$ACTION" == "add" ]]; then
  log_info "Adding user '$USERNAME' with pool '${POOL}'"

  # Create UNIX user
  if id "$USERNAME" &>/dev/null; then
    log_info "User '$USERNAME' already exists."
  else
    log_info "Creating UNIX user '$USERNAME' with home at $USER_HOME"
    useradd -m -d "$USER_HOME" -s /bin/bash "$USERNAME"
    passwd "$USERNAME"
  fi

  # Create user directories
  log_info "Creating directories for $USERNAME..."
  mkdir -p "$USER_HOME" "$TIMEMACHINE_DIR"
  chown -R "$USERNAME:$USERNAME" "$USER_HOME" "$TIMEMACHINE_DIR"
  chmod 700 "$USER_HOME" "$TIMEMACHINE_DIR"

  # Samba user
  log_info "Creating Samba user for '$USERNAME'..."
  smbpasswd -a "$USERNAME"

  # Per-user Samba config
  log_info "Creating Samba config: $USER_SMB_CONF"
  mkdir -p /etc/samba/users.d
  tee "$USER_SMB_CONF" > /dev/null <<EOF
[${USERNAME}]
   path = ${USER_HOME}
   valid users = ${USERNAME}
   read only = no
   browsable = yes

[${USERNAME}_timemachine]
   path = ${TIMEMACHINE_DIR}
   valid users = ${USERNAME}
   read only = no
   browsable = yes
   fruit:time machine = yes
EOF

  # Append include to users.conf if not present
  if ! grep -Fxq "include = $USER_SMB_CONF" "$SMB_USERS_CONF"; then
    log_info "Appending include to $SMB_USERS_CONF"
    echo "include = $USER_SMB_CONF" >> "$SMB_USERS_CONF"
  fi

  # Optional group share setup
  read -rp "Create a group share for this user? (yes/no): " GROUP_SHARE_ANSWER
  if [[ "$GROUP_SHARE_ANSWER" == "yes" ]]; then
    read -rp "Enter group name (default: ${USERNAME}): " GROUP
    GROUP=${GROUP:-$USERNAME}
    read -rp "Enter pool name for group share: " GROUP_POOL
    read -rp "Enter dataset name for group share: " GROUP_DATASET

    GROUP_SHARE_PATH="/${GROUP_POOL}/${GROUP_DATASET}"
    GROUP_CONF="/etc/samba/users.d/${GROUP_DATASET}.conf"

    # Create group if needed
    if getent group "$GROUP" > /dev/null; then
      log_info "Group '${GROUP}' already exists."
    else
      log_info "Creating group '${GROUP}'"
      groupadd "$GROUP"
    fi

    # Add user to group
    log_info "Adding user '$USERNAME' to group '$GROUP'"
    usermod -aG "$GROUP" "$USERNAME"

    # Create and set up shared directory
    mkdir -p "$GROUP_SHARE_PATH"
    chown root:"$GROUP" "$GROUP_SHARE_PATH"
    chmod 2770 "$GROUP_SHARE_PATH"

    # Create Samba config for group share
    log_info "Creating group Samba config: ${GROUP_CONF}"
    tee "$GROUP_CONF" > /dev/null <<EOF
[${GROUP_DATASET}]
   path = ${GROUP_SHARE_PATH}
   valid users = @${GROUP}
   force group = ${GROUP}
   create mask = 0660
   directory mask = 2770
   read only = no
   browsable = yes
EOF

    # Include group config if not already listed
    if ! grep -Fxq "include = $GROUP_CONF" "$SMB_USERS_CONF"; then
      log_info "Appending include to $SMB_USERS_CONF"
      echo "include = $GROUP_CONF" >> "$SMB_USERS_CONF"
    fi
  fi

  log_info "Reloading Samba services..."
  systemctl reload smbd
  log_info "User '$USERNAME' setup complete."

elif [[ "$ACTION" == "remove" ]]; then
  log_info "Removing user '$USERNAME'..."

  # Remove UNIX and Samba user
  userdel -r "$USERNAME" || log_info "Warning: could not delete UNIX user"
  smbpasswd -x "$USERNAME" || log_info "Warning: could not delete Samba user"

  # Remove directories
  rm -rf "$USER_HOME" "$TIMEMACHINE_DIR"
  log_info "Removed home and Time Machine directories."

  # Remove Samba config
  rm -f "$USER_SMB_CONF"
  sed -i "\|include = $USER_SMB_CONF|d" "$SMB_USERS_CONF"

  log_info "Reloading Samba services..."
  systemctl reload smbd
  log_info "User '$USERNAME' removed."

else
  log_info "Invalid action: $ACTION"
  exit 1
fi
