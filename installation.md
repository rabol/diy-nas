**DIY NAS Server Setup**

---

## OVERVIEW

**Target Platform:** A mini pc with 1 or 2 NIC's.  
**OS:** Ubuntu Server 24.04 LTS (minimal install)  
**Primary Goals:**

- ZFS-based NAS with SMB sharing
- Per-user home, backup, Time Machine
- Group restricted share
- Remote backups with rclone to Backblaze
- Use `systemd-networkd` as default; `NetworkManager` is available only if Cockpit is installed.
- Web-based admin via Cockpit or webmin
- Use Postmark (msmtp/mailx) for email alerts
- Add colored output for pass/fail.
- add logging to all scripts
- Time Sync Strategy
- Use chrony as it is better accuracy/flexibility
- shared log directory: /var/log/nas-setup/ 
- make sure that the log directory exists
- enforcing logging for every script (with timestamp and status).
- create a log() function inside each script.

--- 

**Directory for Scripts:**  
`/opt/nas-setup-scripts/`

All scripts must be:

- Idempotent (safe to re-run)
- Include error handling
- Use `set -euo pipefail`
- Remove/reconfigure prior state if needed for override
- Have executable permission (`chmod +x`)

---

## Step 1: Base OS Installation

**Manual Step - No script:**

- Install Ubuntu Server 24.04 LTS (minimal, no snap)
- Use entire boot disk (expand partition fully)
- Create dedicated admin user: `sysadmin` (with sudo rights)
- Static hostname: `diy-nas.lan`

---

## Step 2: Install all needed packages

**Script:** `02-install-packages.sh`

- Installs all necessary packages for the NAS setup in one centralized script.
- Enables and starts `systemd-networkd` for networking.
- Removes and blocks `ntpsec` to avoid time daemon conflicts.
- Installs key packages:
  - `zfsutils-linux`, `samba`, `smbclient`, `libnss-winbind`, `winbind`, `avahi-daemon`
  - `smartmontools`, `ufw`, `msmtp`, `bsd-mailx`, `htop`, `curl`, `wget`, `unzip`, etc.
- Logs actions to `/var/log/nas-setup/02-install-packages.log`

--- 

## Step 3: Configure Networking

**Script:** `03-configure-network.sh`

- This script uses `systemd-networkd` to manage network interfaces.
- If multiple physical NICs are detected, the user will be prompted to create a bonded interface.
- Bonding supports active-backup mode (mode 1) for fault tolerance.
- User can choose between:
  - DHCP configuration
  - Static IP assignment (IP address, gateway, and DNS prompt)
- Automatically writes `.network` and optional `.netdev` files to `/etc/systemd/network/`.
- Ensures `systemd-networkd` is enabled and `NetworkManager` is masked if present.
- Logs all actions to: `/var/log/nas-setup/03-configure-network.log`

---

## Step 4: ZFS Pool & Dataset Setup

**Script:** `04-storage-setup.sh`

- Interactive and repeatable script to create one or more ZFS pools.
- For each pool:
  - User is prompted to enter the name, RAID layout (single/mirror/raidz), and devices.
  - A safety prompt ensures users confirm before wiping selected disks.
- After creating a pool, the user may optionally:
  - Create one or more datasets
  - Assign custom mountpoints for each dataset
- Pool is created with recommended defaults:
  - `ashift=12`, `compression=lz4`, `atime=off`, `xattr=sa`, `acltype=posixacl`
- Datasets default to `snapdir=hidden`
- Logs all actions to: `/var/log/nas-setup/04-storage-setup.log`

This script can be run multiple times to configure additional pools, e.g.:
- `tank_hdd` for backups and home directories
- `tank_ssd` or `tank_nvme` for fast project storage

---

## Step 5: Configure Samba

**Script:** `05-install-samba.sh`

- This script assumes all Samba-related packages are already installed via `02-install-packages.sh`.
- It replaces the default `/etc/samba/smb.conf` with a clean, modular configuration.
- Includes support for macOS (Apple Time Machine compatibility via `fruit` module).
- Adds an include path: `/etc/samba/users.d/users.conf` for per-user or per-share definitions.
- Disables the legacy `nmbd` service, and enables/restarts `smbd`.
- Optionally offers to enable Avahi service advertisement:
  - Creates `/etc/avahi/services/samba.service`
  - Registers `_smb._tcp` and `_device-info._tcp` for Bonjour/mDNS discovery
  - Restarts `avahi-daemon`
- Logs all output to: `/var/log/nas-setup/05-install-samba.log`

After this step, you can proceed to define Samba users and shares in the `users.conf` file or through the user management script.

---

**Script:** `06-manage-user.sh`

- This script manages both user accounts and their associated Samba shares.
- Supports the following subcommands:
  - `add <username> [pool]` – Creates a new user, home directory, Time Machine share, and Samba configuration.
  - `remove <username>` – Removes the user and their Samba/share configuration.
- Home and backup directories are created under the specified ZFS pool (default: `tank_hdd`):
  - `/POOL/homes/<username>`
  - `/POOL/timemachine/<username>`
- Samba configuration is created at:
  - `/etc/samba/users.d/<username>.conf`
- Includes the user’s config in `/etc/samba/users.conf`
- Optionally prompts to create a **group share**:
  - Prompts for group name, ZFS pool, and dataset
  - Creates `/POOL/DATASET` and sets group ownership + permissions
  - Adds the user to the group
  - Configures Samba access for that group share
- Logs all actions to: `/var/log/nas-setup/06-manage-user.log`

This script is interactive, safe to re-run, and fully scriptable for automation.

---

## Step 7: Optional – Group Share Setup

**Script:** `07-create-group-share.sh`

- This script creates a shared directory for a user group.
- It is intended for cases where multiple users should access a common dataset.
- Supports non-interactive usage and batch user setup.

### Features:
- Creates the group if it doesn’t exist
- Creates the shared directory at `/POOL/DATASET`
- Assigns correct permissions and group ownership
- Adds multiple users to the group
- Generates a dedicated Samba config at `/etc/samba/users.d/<dataset>.conf`
- Appends `include = ...` entry in `/etc/samba/users.conf` if missing
- Reloads Samba service
- Fully logged to `/var/log/nas-setup/07-create-group-share.log`

### Example:
```bash
./07-create-group-share.sh design tank_ssd projects alice bob charlie
```

This would:
- Create group `design`
- Create `/tank_ssd/projects` shared folder
- Grant access to users `alice`, `bob`, and `charlie`
- Configure it for access through Samba

Use this script when you want to provision shared project folders or department-level access, independent of individual user onboarding.

--- 

## Step 8: Install and Configure Rclone

**Script:** `08-install-rclone.sh`

- Installs the latest stable version of [rclone](https://rclone.org/) from the official source.
- Removes any previously installed version from the system package manager.
- Verifies the rclone installation.
- Logs all activity to: `/var/log/nas-setup/08-install-rclone.log`

### Notes:
- This script does **not** run `rclone config` interactively — you must run it manually:
  ```bash
  rclone config
  ```
- Rclone configuration is stored in:
  ```
  ~/.config/rclone/rclone.conf
  ```

This tool can be used for syncing with cloud storage providers like Google Drive, Dropbox, S3, etc.

---

## Step 9: ZFS Snapshots and Cloud Backup

**Script:** `09-snapshot-backup.sh`

- Installs and configures `zfs-auto-snapshot` to handle automatic local ZFS snapshots.
- Retention policy:
  - `24` hourly snapshots
  - `7` daily snapshots
  - `4` weekly snapshots
- Creates a daily cron job for `rclone` to sync a dataset to a cloud remote.
- All actions are logged to:
  - Snapshot/cron setup log: `/var/log/nas-setup/09-snapshot-backup.log`
  - Daily rclone sync log: `/var/log/nas-backup.log`

### Prompts:
- Path to the local dataset to back up (e.g. `/tank_hdd`)
- Target remote (e.g. `remote:backup`)

### Behavior:
- If backup fails, an alert is sent via `mailx` to the `root` user (adjustable).
- The cron job is saved at: `/etc/cron.daily/rclone-backup`

You should ensure that `rclone config` is already completed before running this step.

---

## Step 10: Configure Email Alerts (Postmark SMTP)

**Script:** `10-configure-email.sh`

- Sets up outbound email notifications via [Postmark SMTP](https://postmarkapp.com/).
- Useful for system alerts (e.g., backup failures, SMART warnings).
- Uses `msmtp` and `mailx` for minimal MTA functionality.

### What it does:
- Installs `msmtp`, `msmtp-mta`, and `bsd-mailx`
- Prompts for:
  - Sender address (must be verified in Postmark)
  - Recipient address (target inbox for alerts)
  - Postmark server token (used as SMTP credentials)
- Writes configuration to `/etc/msmtprc` with secure permissions
- Routes system mail from `root` to the recipient
- Sends a test email to verify delivery
- Logs actions to: `/var/log/nas-setup/10-configure-email.log`

### Note:
This is intended for authenticated SMTP relay via Postmark. You may adapt it for other SMTP providers if desired.

---


## Step 11: Secure SSH Access

**Script:** `11-secure-ssh.sh`

- Disables SSH password authentication to enforce key-based login only.
- Modifies `/etc/ssh/sshd_config` to set:
  ```text
  PasswordAuthentication no
  ```
- Attempts to restart the `ssh` or `sshd` service.
- Logs all actions to: `/var/log/nas-setup/11-secure-ssh.log`

⚠️ Ensure you have working SSH key access **before** applying this script, or you may lock yourself out.


## Step 12: Configure Firewall (UFW)

**Script:** `12-configure-firewall.sh`

- Enables the uncomplicated firewall (UFW) and applies baseline rules.
- Opens ports:
  - `22` (SSH)
  - `445` (Samba/SMB)
- Masks `nmbd.service` to avoid legacy NetBIOS conflicts.
- Validates Samba availability (via `ping` and `smbclient`) if possible.
- Logs all actions to: `/var/log/nas-setup/12-configure-firewall.log`

This script provides basic security hardening for the NAS server.

---

## Step 13: Validate Installation

**Script:** `13-validate-installation.sh`

- Performs a complete validation of the NAS configuration after setup.
- Logs all results to: `/var/log/nas-setup/13-validate-installation.log`

### What it checks:
- **ZFS**:
  - Lists pools and datasets
  - Verifies pool health and dataset presence
- **Samba**:
  - Checks `smbd` service status
  - Confirms presence of `/etc/samba/users.conf`
- **SSH**:
  - Confirms SSH service is enabled and/or running
- **Firewall (UFW)**:
  - Displays current UFW status and open ports
- **Avahi (mDNS)**:
  - Confirms `avahi-daemon` is running
  - Verifies that `_adisk._tcp` service is advertised (for Time Machine)

This script should be used at the end of the install process to verify everything was provisioned correctly.

--- 


## Step 98 (Optional): Install Cockpit GUI

**Script:** `98-install-cockpit.sh`

- Installs [Cockpit](https://cockpit-project.org/), a web-based interface for managing Linux systems.
- Enables management of:
  - Network configuration
  - Storage (disks, ZFS, LVM)
  - Installed packages and updates
  - Samba shares
- Accessible via: `https://<NAS_IP>:9090`

### What it installs:
- `cockpit`
- `cockpit-networkmanager`
- `cockpit-storaged`
- `cockpit-packagekit`
- `cockpit-samba`
- `cockpit-dashboard`

### Notes:
- Useful for users who prefer a visual overview or multi-node dashboard.
- Logs actions to: `/var/log/nas-setup/98-install-cockpit.log`
- Ensure firewall (UFW) has port 9090 open if you wish to access remotely.


**Script:** `99-install-webmin.sh`

- Installs [Webmin](https://www.webmin.com/), a browser-based interface for system administration.
- Offers control over:
  - Users and groups
  - File systems and partitions
  - Samba shares
  - Firewall, scheduled jobs, and more

### What it installs:
- Webmin from the official Webmin APT repository
- Adds GPG key and configures secure APT source

### Access:
- Web interface: `https://<NAS_IP>:10000`
- Default credentials:
  - Username: `root`
  - Password: your root password

### Notes:
- Logs actions to: `/var/log/nas-setup/99-install-webmin.log`
- If UFW is enabled, ensure port `10000` is allowed.

## Step 100 (Optional): Final Wrap-Up and Reboot

**Script:** `100-wrapup.sh`

- Displays a checklist of key setup components for manual verification:
  - Cockpit and/or Webmin availability
  - Samba share accessibility
  - Time Machine discovery
  - Email alert delivery
  - Snapshot and backup schedule

- Asks if the user wants to **reboot the NAS** immediately.

### Notes:
- Logs actions to: `/var/log/nas-setup/100-wrapup.log`
- No actual changes are made unless reboot is confirmed.
- Intended as a friendly last step after setup is complete.

