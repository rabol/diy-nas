#!/bin/bash
set -euo pipefail

SCRIPT_NAME="05-install-samba"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting Samba configuration..."

# Ensure required binaries exist
for bin in samba smbclient smbd; do
  if ! command -v "$bin" &> /dev/null; then
    log "ERROR: Required package '$bin' is not installed. Please run 02-install-packages.sh first."
    exit 1
  fi
done

# Backup existing config
if [[ -f /etc/samba/smb.conf ]]; then
  cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
  log "Backed up existing smb.conf to smb.conf.bak"
fi

# Ensure include directory exists
mkdir -p /etc/samba/users.d
touch /etc/samba/users.d/users.conf

# Create main smb.conf
log "Creating new smb.conf..."
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

log "smb.conf created with Apple/macOS compatibility settings."

# Restart Samba services
log "Restarting Samba services..."
systemctl restart smbd
systemctl enable smbd

# Disable legacy service
log "Disabling nmbd service..."
systemctl disable --now nmbd || true

# Optional: Avahi configuration
read -rp "Enable Avahi (Bonjour/mDNS) service advertisement for Samba? (yes/no): " AVAHI_ENABLE
if [[ "$AVAHI_ENABLE" == "yes" ]]; then
  log "Creating Avahi Samba service definition..."
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

  log "Restarting avahi-daemon..."
  systemctl restart avahi-daemon
  log "Avahi Samba service enabled and advertised."
else
  log "Avahi configuration skipped."
fi

log "Samba configuration completed. You can now create users and define shares via /etc/samba/users.d/users.conf."
