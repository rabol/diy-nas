#!/bin/bash
set -euo pipefail

SCRIPT_NAME="09-snapshot-backup"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
BACKUP_LOG="/var/log/nas-backup.log"
RCLONE_JOB="/etc/cron.daily/rclone-backup"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE" "$BACKUP_LOG"
chmod 600 "$LOG_FILE" "$BACKUP_LOG"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting snapshot and backup setup..."

# Install zfs-auto-snapshot
log "Installing zfs-auto-snapshot..."
apt-get update >> "$LOG_FILE" 2>&1
apt-get install -y zfs-auto-snapshot >> "$LOG_FILE" 2>&1

# Configure retention
log "Configuring snapshot retention..."
sed -i 's/^KEEP_HOURLY=.*/KEEP_HOURLY=24/' /etc/cron.hourly/zfs-auto-snapshot || true
sed -i 's/^KEEP_DAILY=.*/KEEP_DAILY=7/' /etc/cron.daily/zfs-auto-snapshot || true
sed -i 's/^KEEP_WEEKLY=.*/KEEP_WEEKLY=4/' /etc/cron.weekly/zfs-auto-snapshot || true
log "Retention policy: 24 hourly, 7 daily, 4 weekly."

# Prompt for rclone source and remote
read -rp "Enter the local ZFS dataset path to back up (e.g. /tank_hdd): " LOCAL_PATH
read -rp "Enter the rclone remote destination (e.g. remote:backup): " REMOTE_PATH

# Create rclone sync job
log "Creating daily rclone sync job at $RCLONE_JOB..."
cat <<EOF > "$RCLONE_JOB"
#!/bin/bash
set -euo pipefail

timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
echo "[\$timestamp] Starting rclone backup..." >> "$BACKUP_LOG"

if ! /usr/bin/rclone sync "$LOCAL_PATH" "$REMOTE_PATH" >> "$BACKUP_LOG" 2>&1; then
  echo "[\$timestamp] Backup failed!" >> "$BACKUP_LOG"
  echo "Subject: NAS Backup Failed" | /usr/bin/mailx -s "NAS backup failure" root
  exit 1
fi

echo "[\$timestamp] Backup completed successfully." >> "$BACKUP_LOG"
EOF

chmod +x "$RCLONE_JOB"
log "Backup job installed and logging to $BACKUP_LOG"
log "09-snapshot-backup complete."
