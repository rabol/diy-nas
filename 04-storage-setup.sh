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
log_info "Starting modular ZFS storage setup..."

# Check ZFS availability
if ! command -v zpool >/dev/null; then
  log_error "ERROR: ZFS is not installed. Please run 02-install-packages.sh first."
  exit 1
fi

# Show available drives
log_info "Available block devices:"
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
[[ "$CONFIRM" != "yes" ]] && { log_info "Aborted by user."; exit 1; }

# Optional wipe of existing data
read -rp "Wipe filesystem signatures before creating the pool? (yes/no): " WIPE_CHOICE
if [[ "$WIPE_CHOICE" =~ ^[Yy] ]]; then
  for dev in "${DEVICES[@]}"; do
    # Check if device has partitions
    if ls /dev/"${dev}"?* &>/dev/null; then
      log_info "WARNING: /dev/${dev} has existing partitions."
      read -rp "Force wipe /dev/${dev} anyway? (yes/no): " FORCE_PART
      if [[ "$FORCE_PART" != "yes" ]]; then
        log_info "User aborted wipe of /dev/${dev}."
        exit 1
      fi
    fi

    log_info "Attempting to unmount and deactivate /dev/${dev}..."
    umount -f /dev/${dev}?* &>/dev/null || true
    zpool labelclear -f /dev/${dev} &>/dev/null || true
    mdadm --zero-superblock /dev/${dev} &>/dev/null || true

    log_info "Removing all partitions on /dev/${dev} with parted..."
    if ! parted -s /dev/${dev} mklabel gpt; then
      log_info "ERROR: Failed to reset partition table with parted on /dev/${dev}."
      log_info "Partition table may still be in use — reboot and try again."
      exit 1
    fi

    log_info "Wiping signatures on /dev/$dev..."
    if ! wipefs -a "/dev/$dev"; then
      log_info "ERROR: Could not wipe /dev/$dev. Device may be in use."
      exit 1
    fi

    if ! dd if=/dev/zero of="/dev/$dev" bs=1M count=10 status=none; then
      log_info "ERROR: Failed to zero beginning of /dev/$dev."
      exit 1
    fi

    log_info "Running sgdisk --zap-all on /dev/$dev..."
    if ! sgdisk --zap-all "/dev/$dev"; then
      log_info "ERROR: Failed to zap partition table on /dev/$dev."
      exit 1
    fi
  done
fi

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
    log_error "ERROR: Invalid RAID mode."
    exit 1
    ;;
esac

# Create the ZFS pool
log_info "Creating ZFS pool '${POOL_NAME}'..."
zpool create -f \
  -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  "${POOL_NAME}" "${POOL_ARGS[@]}"
log_info "ZFS pool '${POOL_NAME}' created."

# Optionally create datasets
read -rp "Do you want to create datasets in this pool now? (yes/no): " CREATE_DATASETS
if [[ "$CREATE_DATASETS" == "yes" ]]; then
  read -rp "Enter dataset names (comma-separated): " DATASETS
  IFS=',' read -ra DATASET_LIST <<< "$DATASETS"

  read -rp "Set custom mountpoint for each dataset? (yes/no): " USE_MOUNTPOINTS

  for dataset in "${DATASET_LIST[@]}"; do
    dataset_name=$(echo "$dataset" | xargs)  # trim spaces
    if [[ "$USE_MOUNTPOINTS" == "yes" ]]; then
      #read -rp "Enter mountpoint for '${dataset_name}': " MOUNT
      while true; do
        read -rp "Enter mountpoint for '${dataset_name}' (must be an absolute path): " mountpoint
        if [[ "$mountpoint" == /* ]]; then
          break
        else
          log_error "Mountpoint must start with '/'. Try again."
        fi
      done

      zfs create -o mountpoint="$mountpoint" "${POOL_NAME}/${dataset_name}"
    else
      zfs create "${POOL_NAME}/${dataset_name}"
    fi
    zfs set snapdir=hidden "${POOL_NAME}/${dataset_name}"
    log_info "Created dataset: ${POOL_NAME}/${dataset_name}"
  done
else
  log_info "No datasets created."
fi

zfs list | tee -a "$LOG_FILE"
log_info "Storage setup for pool '${POOL_NAME}' complete."
