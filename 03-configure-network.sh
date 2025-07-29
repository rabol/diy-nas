#!/bin/bash
set -euo pipefail

SCRIPT_NAME="03-configure-network"
LOG_DIR="/var/log/nas-setup"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting flexible network configuration using systemd-networkd..."

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  log "ERROR: This script must be run as root."
  exit 1
fi

# Confirm systemd-networkd is active
log "Checking that systemd-networkd is active..."
if ! systemctl is-active --quiet systemd-networkd; then
  log "Enabling and starting systemd-networkd..."
  systemctl enable systemd-networkd
  systemctl start systemd-networkd
else
  log "systemd-networkd is already active."
fi

# Detect available NICs
log "Detecting available NICs..."
AVAILABLE_NICS=$(ls /sys/class/net | grep -E '^e[nm].*')
NIC_COUNT=$(echo "$AVAILABLE_NICS" | wc -l)
log "Detected $NIC_COUNT NIC(s): $AVAILABLE_NICS"

read -p "Do you want to configure NIC bonding? (yes/no): " DO_BOND

NETPLAN_FILE="/etc/netplan/01-network.yaml"

if [[ "$DO_BOND" == "yes" ]]; then
  read -p "Enter the first network interface to bond (e.g. eno1): " IFACE1
  read -p "Enter the second network interface to bond (e.g. enp2s0): " IFACE2
  read -p "Use DHCP for bonded interface? (yes/no): " USE_DHCP

  log "Writing Netplan configuration for bonded interface..."
  if [[ "$USE_DHCP" == "yes" ]]; then
    cat <<EOF > "$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE1}: {dhcp4: no}
    ${IFACE2}: {dhcp4: no}
  bonds:
    bond0:
      interfaces: [${IFACE1}, ${IFACE2}]
      parameters:
        mode: active-backup
        primary: ${IFACE1}
      dhcp4: true
EOF
  else
    read -p "Enter static IP address (e.g. 192.168.1.3/24): " STATIC_IP
    read -p "Enter gateway IP (e.g. 192.168.1.1): " GATEWAY
    read -p "Enter DNS server IP (e.g. 1.1.1.1): " DNS

    cat <<EOF > "$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE1}: {dhcp4: no}
    ${IFACE2}: {dhcp4: no}
  bonds:
    bond0:
      interfaces: [${IFACE1}, ${IFACE2}]
      parameters:
        mode: active-backup
        primary: ${IFACE1}
      addresses: [${STATIC_IP}]
      nameservers:
        addresses: [${DNS}]
      routes:
        - to: default
          via: ${GATEWAY}
EOF
  fi
else
  read -p "Enter the network interface to configure (e.g. eno1): " IFACE
  read -p "Use DHCP for this interface? (yes/no): " USE_DHCP

  log "Writing Netplan configuration for ${IFACE}..."
  if [[ "$USE_DHCP" == "yes" ]]; then
    cat <<EOF > "$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      dhcp4: true
EOF
  else
    read -p "Enter static IP address (e.g. 192.168.1.3/24): " STATIC_IP
    read -p "Enter gateway IP (e.g. 192.168.1.1): " GATEWAY
    read -p "Enter DNS server IP (e.g. 1.1.1.1): " DNS

    cat <<EOF > "$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      addresses: [${STATIC_IP}]
      gateway4: ${GATEWAY}
      nameservers:
        addresses: [${DNS}]
EOF
  fi
fi

chmod 600 "$NETPLAN_FILE"
log "Netplan config written to ${NETPLAN_FILE}. Applying configuration..."

netplan apply

log "Network configuration complete."
