### Global configuration for NAS setup scripts
CONFIG_FILE="/etc/nas-setup-scripts/config.sh"

### Script directory
SCRIPT_DIR="/opt/nas-setup-scripts"

### --- Log Directory ---
LOG_DIR="/var/log/nas-setup"

# /opt/nas-setup-scripts/config.sh
# Global configuration for NAS setup scripts

### --- ZFS Storage Configuration ---
DEFAULT_POOL="tank"
DEFAULT_DATASETS=("data" "backup" "media" "home")

### Optional: Mapping mount points for common datasets
declare -A DATASET_MOUNT_POINTS=(
  ["data"]="/mnt/data"
  ["backup"]="/mnt/backup"
  ["media"]="/mnt/media"
  ["home"]="/mnt/home"
)

### --- Samba Configuration ---
DEFAULT_SMB_GROUP="smbusers"
SMB_SHARE_ROOT="/$DEFAULT_POOL"

### --- User Management ---
DEFAULT_HOME_ROOT="/$DEFAULT_POOL/home"
USER_GROUPS=("smbusers")

### --- Email Notifications (Optional) ---
ADMIN_EMAIL="admin@example.com"

### --- Misc ---
# Add other defaults here as needed