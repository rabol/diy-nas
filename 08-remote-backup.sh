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

log_info "Starting snapshot and backup setup..."

BACKUP_LOG="/var/log/nas-backup.log"
RCLONE_JOB="/etc/cron.daily/rclone-backup"

# Ensure rclone is available
if ! command -v rclone &>/dev/null; then
  log_error "rclone is not installed. Please run install-rclone.sh first."
  exit 1
fi

# Prompt for paths
read -rp "Enter the local ZFS dataset path to back up (e.g. /tank_hdd): " LOCAL_PATH
read -rp "Enter the rclone remote destination (e.g. remote:backup): " REMOTE_PATH

# Create rclone sync job
log_info "Creating daily rclone sync job at $RCLONE_JOB..."
cat <<EOF > "$RCLONE_JOB"
#!/bin/bash
set -euo pipefail

timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
echo "[\$timestamp] Starting rclone backup..." >> "$BACKUP_LOG"

if ! /usr/bin/rclone sync "$LOCAL_PATH" "$REMOTE_PATH" >> "$BACKUP_LOG" 2>&1; then
  echo "[\$timestamp] Backup failed!" >> "$BACKUP_LOG"
  echo "Subject: [\$(hostname)] NAS Backup Failed" | /usr/bin/mailx -s "NAS backup failure" root
  exit 1
fi

echo "[\$timestamp] Backup completed successfully." >> "$BACKUP_LOG"
EOF

chmod +x "$RCLONE_JOB"
log_info "Backup job installed and logging to $BACKUP_LOG"
log_success "${SCRIPT_NAME} complete."