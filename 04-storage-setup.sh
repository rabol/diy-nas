#!/bin/bash
set -euo pipefail

SCRIPT_NAME="04-storage-setup"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting modular ZFS storage setup..."

# Check ZFS availability
if ! command -v zpool >/dev/null; then
  log "ERROR: ZFS is not installed. Please run 02-install-packages.sh first."
  exit 1
fi

# Show available drives
log "Available block devices:"
lsblk -d -o NAME,SIZE,MODEL | tee -a "$LOG_FILE"

# Get pool name
read -rp "Enter name for the new ZFS pool: " POOL_NAME

# Get RAID layout
read -rp "RAID mode (single/mirror/raidz): " RAID_MODE
RAID_MODE=${RAID_MODE:-single}

# Get devices
read -rp "Enter device paths for the pool (space-separated): " -a DEVICES

# Confirm destructive action
echo "WARNING: This will erase all data on: ${DEVICES[*]}"
read -rp "Type 'yes' to continue: " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { log "Aborted by user."; exit 1; }

# Prepare zpool args
case "$RAID_MODE" in
  single)
    POOL_ARGS=("${DEVICES[@]}")
    ;;
  mirror)
    POOL_ARGS=("mirror" "${DEVICES[@]}")
    ;;
  raidz)
    POOL_ARGS=("raidz" "${DEVICES[@]}")
    ;;
  *)
    log "ERROR: Invalid RAID mode."
    exit 1
    ;;
esac

# Create the ZFS pool
log "Creating ZFS pool '${POOL_NAME}'..."
zpool create -f \
  -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  "${POOL_NAME}" "${POOL_ARGS[@]}"
log "ZFS pool '${POOL_NAME}' created."

# Optionally create datasets
read -rp "Do you want to create datasets in this pool now? (yes/no): " CREATE_DATASETS
if [[ "$CREATE_DATASETS" == "yes" ]]; then
  read -rp "Enter dataset names (comma-separated): " DATASETS
  IFS=',' read -ra DATASET_LIST <<< "$DATASETS"

  read -rp "Set custom mountpoint for each dataset? (yes/no): " USE_MOUNTPOINTS

  for dataset in "${DATASET_LIST[@]}"; do
    dataset_name=$(echo "$dataset" | xargs)  # trim spaces
    if [[ "$USE_MOUNTPOINTS" == "yes" ]]; then
      read -rp "Enter mountpoint for '${dataset_name}': " MOUNT
      zfs create -o mountpoint="$MOUNT" "${POOL_NAME}/${dataset_name}"
    else
      zfs create "${POOL_NAME}/${dataset_name}"
    fi
    zfs set snapdir=hidden "${POOL_NAME}/${dataset_name}"
    log "Created dataset: ${POOL_NAME}/${dataset_name}"
  done
else
  log "No datasets created."
fi

zfs list | tee -a "$LOG_FILE"
log "Storage setup for pool '${POOL_NAME}' complete."
