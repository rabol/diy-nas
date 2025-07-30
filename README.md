# DIY NAS Setup

This project provides a fully script-driven setup for building a reliable, modular NAS (Network-Attached Storage) on Ubuntu using tools like ZFS, Samba, UFW, and optional web interfaces.



# Why this project
This is a very opinionated installation, surly it's not perfect, I did it because at the end of the day all systems that I have tried needs that you do some kind of commandline work.
E.g. when I create a pool with one disk, I know that it's one disk, I do not need at warning telling me that there is no redundancy. As far as I know, ZFS is the best for a NAS, speed, snapshot etc.

in one system I spend 30 hours for it to check my array, just to tell med that I had 38.000 errors on my hard drive - it was an array of 4 brand new 4TB WD RED NAS drives. 

---

## Features

- ZFS pool creation and dataset management
- Samba sharing with group/user controls
- Time Machine support via Avahi
- Rclone for cloud sync/backup
- Snapshot and backup logic
- Email alerting via SMTP (Postmark)
- SSH hardening, UFW firewall configuration
- Optional web UIs: **Cockpit** or **Webmin**
- Fully modular and **logging-enabled** scripts

---

## Requirements

- Ubuntu Ubuntu 24.04.2 LTS 
- Root privileges
- Internet access (for installing packages)

---

## How to Use

1. Clone or extract this repository.
   ```bash
   git clone https://github.com/rabol/diy-nas.git
   ```
2. Make sure all scripts are executable:
   ```bash
   cd diy-nas
   chmod +x *.sh
   ./setup.sh
   ```

NOTE: if you have any active partitions or zfs pools on your storage, it can be that you are required to reboot

> You can comment out optional steps inside `index.sh` if not needed (e.g., `Cockpit`, `Webmin`, `Wrap-up`).

---

## Documentation

Detailed documentation is available in:

[View Documentation](docs/index.md)

---

## Note

This setup assumes you’re working in a trusted LAN environment. Still, UFW and SSH hardening steps are included for best practice.

---

Enjoy your clean, modular, scriptable NAS
