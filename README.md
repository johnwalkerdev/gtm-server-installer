# GTM Server Installer 🧩

This script installs a self-hosted **Google Tag Manager Server-Side container** using Docker, Nginx, and Certbot, allowing full control over your tagging environment with custom domains.

---

## 📦 What it does

* ✅ Prompts for project name, container config, and domains
* ✅ Dynamically assigns available ports (starting from 8080+)
* ✅ Creates isolated folder at `/opt/<project_name>`
* ✅ Optionally installs dependencies (nginx, certbot, docker-compose)
* ✅ Sets up Docker containers for preview + production
* ✅ Configures Nginx reverse proxy with healthcheck
* ✅ Offers automatic SSL certificate generation via Let's Encrypt
* ✅ Logs everything at `/var/log/gtm-installer.log`

---

## ⚙️ Requirements

* Ubuntu 20.04+ with root access
* Docker & Docker Compose (optional: script can install)
* 2 subdomains pointed to your server IP:

  * `gtm-preview.example.com`
  * `gtm.example.com`

---

## 🚀 Quick Install (recommended)

Download and run locally with full permissions:

```
curl -O https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/installer.sh
chmod +x installer.sh
sudo ./installer.sh
```

> ⚠️ **Do not** use `curl ... | sudo bash` — it breaks environment variable inputs like `CONTAINER_CONFIG`.

### 🔐 Issue SSL Certificates (later):

After DNS propagates:

```bash
source /opt/YOUR_PROJECT/.env && sudo bash installer.sh --ssl
```

---

## 🧪 What you'll be asked

* Project name: `gtm-example`
* GTM container config (base64 string)
* Preview domain (e.g. `gtm-preview.example.com`)
* Production domain (e.g. `gtm.example.com`)
* Whether to install:

  * Nginx (once per server)
  * Docker Compose (once per server)
  * Certbot (per project if issuing SSL)

---

## 📂 Folder structure created

```
/opt/<project_name>/
├── docker-compose.yml
├── .env
├── logs/
│   └── container logs
└── nginx/ (optional future use)
```

---

## 🛠 Useful commands

```bash
cd /opt/<project_name>
docker-compose ps            # Check container status
docker-compose logs -f      # View logs
sudo systemctl reload nginx # Reload Nginx config
```

---

## ❓ FAQ

### Do I need to install dependencies every time?

No. You will be asked individually whether to install:

* **Nginx** (needed once per server)
* **Docker Compose** (needed once per server)
* **Certbot** (can be installed per project to handle SSL)

Answer 'n' to any that are already installed.

### What if Certbot says a certificate already exists?

Certbot may detect existing certificates and prompt to expand them. Just type `E` to confirm.

If you'd like to avoid the prompt entirely, use:

```bash
certbot --nginx --expand -d your.domain.com -d other.domain.com
```

---

## 🧹 Uninstall a GTM Project

You can completely remove any installed project using the provided uninstall script.

### 🔧 How to uninstall

1. Download the uninstaller:
   ```bash
   curl -O https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/uninstall.sh
   chmod +x uninstall.sh
   ```

2. Run the script:
   ```bash
   sudo ./uninstall.sh
   ```

3. Follow the prompts:
   - It will list all projects in `/opt` that have a `docker-compose.yml`.
   - You'll choose the project to remove.
   - It will stop and remove Docker containers, volumes, and delete the project folder.

> ✅ Only the selected project will be removed. Other projects remain intact.

---

## 💡 Notes

* Ports are assigned dynamically (starting from 8080)
* You can run multiple GTM containers by repeating the process
* Health endpoints: `/healthz`

---

## ✅ Example Output

```
Enter the project name (e.g. gtm-example): gtm-example
Paste your GTM Container Configuration (base64): aWQ9R1RNL...
Enter your Preview domain: gtm-preview.example.com
Enter your Production domain: gtm.example.com
...
Install complete!
Health check responses:
Preview: 200
Production: 200
```

---

## 👨‍💻 Author

[John Walker](https://github.com/johnwalkerdev)

MIT License
