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

log_info "Configuring system networking..."

NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
NICs=($(ls /sys/class/net | grep -vE '^(lo|docker|veth|br|virbr|vmbr)' | sort))

log_info "Detected network interfaces: ${NICs[*]}"

# Ask user if they want to configure bonding
USE_BONDING=false
if (( ${#NICs[@]} > 1 )); then
  log_info "Multiple network interfaces detected: ${NICs[*]}"
  read -rp "Do you want to configure bonding (yes/no)? " BOND_CHOICE
  [[ "$BOND_CHOICE" =~ ^[Yy] ]] && USE_BONDING=true
else
  log_info "Only one network interface detected: ${NICs[0]}. Skipping bonding."
fi

if $USE_BONDING; then
  IFACE1="${NICs[0]}"
  IFACE2="${NICs[1]:-}"
  if [[ -z "$IFACE2" ]]; then
    log_error "Bonding requires at least two interfaces, but only one was detected."
    exit 1
  fi

  read -rp "Enter static IP address (CIDR format, e.g., 192.168.1.10/24): " STATIC_IP
  read -rp "Enter default gateway: " GATEWAY
  read -rp "Enter DNS server IP(s), comma-separated: " DNS
  DNS=$(echo "$DNS" | tr -d '[:space:]')

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

else
  IFACE="${NICs[0]}"
  read -rp "Use DHCP for ${IFACE}? (yes/no): " DHCP_CHOICE
  if [[ "$DHCP_CHOICE" =~ ^[Yy] ]]; then
    cat <<EOF > "$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      dhcp4: true
EOF
  else
    read -rp "Enter static IP address (CIDR format, e.g., 192.168.1.10/24): " STATIC_IP
    read -rp "Enter default gateway: " GATEWAY
    read -rp "Enter DNS server IP(s), comma-separated: " DNS
    DNS=$(echo "$DNS" | tr -d '[:space:]')

    cat <<EOF > "$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      dhcp4: no
      addresses: [${STATIC_IP}]
      nameservers:
        addresses: [${DNS}]
      routes:
        - to: default
          via: ${GATEWAY}
EOF
  fi
fi

chmod 600 "$NETPLAN_FILE"

log_info "Applying netplan configuration..."
netplan generate
netplan apply

log_success "Network configuration complete."