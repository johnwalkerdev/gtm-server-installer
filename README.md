# GTM Server Installer 🧩

This script installs a self-hosted **Google Tag Manager Server-Side container** using Docker, Nginx, and Certbot, allowing full control over your tagging environment with custom domains.

---

## 📦 What it does
- ✅ Prompts for project name, container config, and domains
- ✅ Dynamically assigns available ports (starting from 8080+)
- ✅ Creates isolated folder at `/opt/<project_name>`
- ✅ Optionally installs dependencies (nginx, certbot, docker-compose)
- ✅ Sets up Docker containers for preview + production
- ✅ Configures Nginx reverse proxy with healthcheck
- ✅ Offers automatic SSL certificate generation via Let's Encrypt
- ✅ Logs everything at `/var/log/gtm-installer.log`

---

## ⚙️ Requirements

- Ubuntu 20.04+ with root access
- Docker & Docker Compose (optional: script can install)
- 2 subdomains pointed to your server IP:
  - `gtm-preview.example.com`
  - `gtm.example.com`

---

## 🚀 Quick Install (recommended)

Download and run locally with full permissions:

```bash
curl -O https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/installer.sh
chmod +x installer.sh
sudo ./installer.sh
