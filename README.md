# DIY NAS Setup

This project provides a fully script-driven setup for building a reliable, modular NAS (Network-Attached Storage) on Ubuntu using tools like ZFS, Samba, UFW, and optional web interfaces.

---

## 🚀 Features

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

## 📦 Requirements

- Ubuntu 22.04 LTS or newer
- Root privileges
- Internet access (for installing packages)

---

## 📂 How to Use

1. Clone or extract this repository.
2. Make sure all scripts are executable:
   ```bash
   chmod +x *.sh
   ```
3. Run the orchestrator:
   ```bash
   ./index.sh
   ```

> You can comment out optional steps inside `index.sh` if not needed (e.g., `Cockpit`, `Webmin`, `Wrap-up`).

---

## 📑 Documentation

Detailed documentation is available in:

**`nas_installation.md`**  
Explains every step from prechecks to optional UI setup and backup strategy.

---

## 🧩 Optional GUI Management

- `98-install-cockpit.sh`: Cockpit GUI at `https://<NAS_IP>:9090`
- `99-install-webmin.sh`: Webmin GUI at `https://<NAS_IP>:10000`

---

## ✅ Final Validation

- Use `13-validate-installation.sh` to confirm services and storage are configured as expected.
- Run `100-wrapup.sh` to finish with a summary and reboot option.

---

## 🛠 Logging

Each script writes detailed logs to:
```
/var/log/nas-setup/
```

---

## 🔒 Note

This setup assumes you’re working in a trusted LAN environment. Still, UFW and SSH hardening steps are included for best practice.

---

Enjoy your clean, modular, scriptable NAS 🎉
