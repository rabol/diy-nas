#!/bin/bash
# Deploy NAS setup scripts to a remote host - for testing..
# Usage: ./deploy.sh [deploy_user] [target_host] [target_dir]
# Example: ./deploy.sh sysadmin nas-diy /opt/nas-setup-staging/

DEPLOY_USER="${1:-sysadmin}"
TARGET_HOST="${2:-nas-diy}"
TARGET_DIR="${3:-/nas-setup/}"

echo "🚀 Deploying NAS setup scripts to ${DEPLOY_USER}@${TARGET_HOST}:${TARGET_DIR}"

# Create the target directory as root via sudo over ssh with terminal
#ssh -t "${DEPLOY_USER}@${TARGET_HOST}" "sudo mkdir -p '${TARGET_DIR}' && sudo chown ${DEPLOY_USER}:${DEPLOY_USER} '${TARGET_DIR}'"

# Rsync project files (no sudo needed now)
rsync -avz --delete \
  --exclude='.git' \
  --exclude='*.log' \
  --exclude='node_modules' \
  --exclude='.env' \
  --exclude='*.zip' \
  --exclude='*.bak' \
  --exclude='__pycache__' \
  --exclude='*.swp' \
  ./ "${DEPLOY_USER}@${TARGET_HOST}:${TARGET_DIR}"

echo "Deployment complete."