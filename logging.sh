#!/bin/bash
# /opt/nas-setup-scripts/lib/logging.sh

LOG_DIR="/var/log/nas-setup"
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

# Color codes
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m" # No Color

# Timestamp format
timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

log_info() {
  echo -e "$(timestamp) [INFO] ${BLUE}$*${NC}" | tee -a "$LOG_FILE"
}

log_success() {
  echo -e "$(timestamp) [SUCCESS] ${GREEN}$*${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
  echo -e "$(timestamp) [WARNING] ${YELLOW}$*${NC}" | tee -a "$LOG_FILE"
}

log_error() {
  echo -e "$(timestamp) [ERROR] ${RED}$*${NC}" | tee -a "$LOG_FILE"
}
