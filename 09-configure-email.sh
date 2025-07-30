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

log_info "Configure Email Alerts via Postmark SMTP"

# Prompt for input
read -rp "Enter the sender email (Postmark verified): " SENDER
read -rp "Enter the recipient email (your alert inbox): " RECIPIENT
read -rsp "Enter the Postmark API token (server token): " POSTMARK_TOKEN
echo

log_info "Installing msmtp and mailx..."
apt-get update >> "$LOG_FILE" 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y msmtp msmtp-mta bsd-mailx >> "$LOG_FILE" 2>&1

log_info "Writing msmtp config to /etc/msmtprc..."
cat <<EOF > /etc/msmtprc
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        postmark
host           smtp.postmarkapp.com
port           587
from           $SENDER
user           $POSTMARK_TOKEN
password       $POSTMARK_TOKEN

account default : postmark
EOF

chmod 600 /etc/msmtprc
chown root:root /etc/msmtprc

log_info "Routing root mail to $RECIPIENT..."
log_info "root: $RECIPIENT" > /etc/aliases
newaliases || true

log_info "Sending test email to $RECIPIENT..."
log_info "Test email from NAS $(hostname) using Postmark SMTP." | mail -s "NAS Alert Test Email" "$RECIPIENT"
log_info "Email configuration complete. Check your inbox for the test email."
