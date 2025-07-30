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

log_info "Starting Samba configuration..."

# Ensure required binaries exist
for bin in samba smbclient smbd; do
  if ! command -v "$bin" &>/dev/null; then
    log_error "Required package '$bin' is not installed. Please run 02-install-packages.sh first."
    exit 1
  fi
done

# Backup existing config
if [[ -f /etc/samba/smb.conf ]]; then
  cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
  log_info "Backed up existing smb.conf to smb.conf.bak"
fi

# Ensure include directory exists
mkdir -p /etc/samba/users.d
touch /etc/samba/users.d/users.conf

# Create main smb.conf
log_info "Creating new smb.conf..."
cat <<EOF > /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   server string = NAS Server
   netbios name = NAS
   dns proxy = no
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   passdb backend = tdbsam
   obey pam restrictions = yes
   unix password sync = yes
   pam password change = yes
   map to guest = bad user
   usershare allow guests = yes
   include = /etc/samba/users.d/users.conf

   vfs objects = fruit streams_xattr
   fruit:metadata = stream
   fruit:model = MacSamba
   fruit:posix_rename = yes
   fruit:veto_appledouble = no
   fruit:wipe_intentionally_left_blank_rfork = yes
   fruit:delete_empty_adfiles = yes
EOF

log_info "smb.conf created with Apple/macOS compatibility settings."

# Restart Samba services
log_info "Restarting Samba services..."
systemctl restart smbd
systemctl enable --now smbd

# Disable legacy service
log_info "Disabling nmbd service..."
systemctl disable --now nmbd || true

# Optional: Avahi configuration
read -rp "Enable Avahi (Bonjour/mDNS) service advertisement for Samba? (yes/no): " AVAHI_ENABLE
if [[ "$AVAHI_ENABLE" == "yes" ]]; then
  log_info "Creating Avahi Samba service definition..."
  mkdir -p /etc/avahi/services
  tee /etc/avahi/services/samba.service > /dev/null <<EOF
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
  </service>
  <service>
    <type>_device-info._tcp</type>
    <port>0</port>
    <txt-record>model=NAS</txt-record>
  </service>
</service-group>
EOF

  log_info "Restarting avahi-daemon..."
  systemctl restart avahi-daemon
  systemctl enable --now avahi-daemon
  log_info "Avahi Samba service enabled and advertised."
else
  log_info "Avahi configuration skipped."
fi

log_success "Samba configuration complete. You can now define shares in /etc/samba/users.d/users.conf."