#!/bin/bash
set -euo pipefail

SCRIPT_NAME="10-configure-email"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "=== Step 10: Configure Email Alerts via Postmark SMTP ==="

# Prompt for input
read -rp "Enter the sender email (Postmark verified): " SENDER
read -rp "Enter the recipient email (your alert inbox): " RECIPIENT
read -rsp "Enter the Postmark API token (server token): " POSTMARK_TOKEN
echo

log "Installing msmtp and mailx..."
apt-get update >> "$LOG_FILE" 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y msmtp msmtp-mta bsd-mailx >> "$LOG_FILE" 2>&1

log "Writing msmtp config to /etc/msmtprc..."
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

log "Routing root mail to $RECIPIENT..."
echo "root: $RECIPIENT" > /etc/aliases
newaliases || true

log "Sending test email to $RECIPIENT..."
echo "Test email from NAS $(hostname) using Postmark SMTP." | mail -s "NAS Alert Test Email" "$RECIPIENT"

log "Email configuration complete. Check your inbox for the test email."
