# GTM Server-Side Installer

Automatic installer for Google Tag Manager Server-Side Container with multi-project support.

## ⚡ Quick Installation

### **Method 1: Direct Installation (Recommended)**
```bash
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh | sudo bash
```

### **Method 2: Manual Download (If method 1 has issues)**
```bash
# Download the script
wget https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh

# View script content (optional - for debugging)
head -50 install.sh

# Make executable
chmod +x install.sh

# Execute
sudo ./install.sh
```

### **Method 3: Clone Repository**
```bash
git clone https://github.com/johnwalkerdev/gtm-server-installer.git
cd gtm-server-installer
sudo ./install.sh
```

## 🔧 Prerequisites:

1. Ubuntu/Debian server
2. Docker and Docker Compose installed
3. Caddy installed
4. Base domain pointing to your server

**Quick command to install dependencies:**
```bash
# Docker
curl -fsSL https://get.docker.com | sh

# Docker Compose and Caddy
apt update && apt install -y docker-compose caddy net-tools
```

## 🚀 What the installer does:

1. ✅ Checks dependencies and available ports
2. 📁 Creates organized structure for your project
3. 🐳 Configures Docker containers with healthchecks
4. 🌐 Sets up automatic SSL via Caddy
5. 🔧 Generates management scripts
6. 🧪 Tests container connectivity

## 📝 During installation you will provide:

1. **Project name** (e.g., contaideal) - only letters, numbers, and hyphens
2. **Base domain** (e.g., huskycontent.com) - your main domain
3. **Container Configuration** - long string from Google Tag Manager

### 🔍 How to get Container Configuration:
1. Access [Google Tag Manager](https://tagmanager.google.com)
2. Select your workspace (server-side container)
3. Go to **Admin** → **Container Settings**
4. Copy the value from **"Container Configuration"** field

## 🌐 The installer will create:

- **Main URL:** `https://gtm-[project].[your-domain]`
- **Preview URL:** `https://preview-gtm-[project].[your-domain]`

**Example with project "contaideal" and domain "huskycontent.com":**
- Main: `https://gtm-contaideal.huskycontent.com`
- Preview: `https://preview-gtm-contaideal.huskycontent.com`

## 🛠️ Management Scripts

After installation, you'll have access to the following scripts:

### **Individual Project Management:**
```bash
# Go to project directory
cd /opt/[project]_gtm

# Available commands
./manage.sh start    # Start containers
./manage.sh stop     # Stop containers
./manage.sh restart  # Restart containers
./manage.sh logs     # View logs
./manage.sh status   # View status
```

### **Update Projects:**
```bash
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/update.sh | sudo bash
```

### **Uninstall Project:**
```bash
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/uninstall.sh | sudo bash
```

## 📋 Useful Commands

### View status of all GTM containers
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep gtag
```

### View specific logs
```bash
# Main container
docker logs -f gtag-server-[project]

# Preview container
docker logs -f gtag-preview-[project]
```

### Restart specific containers
```bash
docker restart gtag-server-[project] gtag-preview-[project]
```

### Check Caddy configuration
```bash
systemctl status caddy
cat /etc/caddy/Caddyfile
```

## ❓ Troubleshooting

### **Installation error with curl:**
Use the manual download method:
```bash
wget https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

### **If preview doesn't work:**
- Clear browser cache
- Restart Tag Assistant
- Check logs: `./manage.sh logs`
- Test preview URL directly

### **If you get 502 error:**
- Check if containers are running: `docker ps`
- Check logs: `./manage.sh logs`
- Check if Caddy is running: `systemctl status caddy`
- Test ports locally: `curl http://localhost:10100/healthz`

### **Ports in use:**
```bash
# Check what's using the ports
netstat -tuln | grep -E ':(10100|10101)'

# Stop conflicting containers
docker stop $(docker ps -q --filter "publish=10100-10101")
```

### **SSL issues:**
```bash
# Check Caddy logs
journalctl -u caddy -f

# Force certificate renewal
systemctl reload caddy
```

## 📄 File Structure

The installer creates the following structure:

```
/opt/[project]_gtm/
├── project.conf              # Project configuration
├── manage.sh                 # Management script
├── logs/                     # Logs directory
├── gtm-[project]/
│   ├── docker-compose.yml    # Main container
│   └── gtag-server.env       # Environment variables
└── gtm-preview-[project]/
    ├── docker-compose.yml    # Preview container
    └── gtag-preview-server.env
```

## 🔒 Security

- ✅ Isolated containers with healthchecks
- ✅ Automatic SSL via Let's Encrypt
- ✅ Logs with automatic rotation
- ✅ Automatic configuration backup
- ✅ User input validation

## 📊 Multiple Projects

This installer supports multiple GTM projects on the same server:

```bash
# Project 1
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh | sudo bash
# Name: contaideal

# Project 2  
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh | sudo bash
# Name: company2

# Each project will have its own URLs and containers
```

## 🆘 Support

- 📖 **Documentation:** Read this README completely
- 🐛 **Bugs:** [Open an issue](https://github.com/johnwalkerdev/gtm-server-installer/issues)
- 💡 **Suggestions:** [GitHub Discussions](https://github.com/johnwalkerdev/gtm-server-installer/discussions)
- 📧 **Contact:** Through GitHub issues

## 📝 Changelog

### v2.0
- ✅ Robust input validations
- ✅ Port availability checking
- ✅ Update and uninstall scripts
- ✅ Container healthchecks
- ✅ Automatic configuration backup
- ✅ Improved management script

### v1.0
- ✅ Basic GTM Server-Side installation
- ✅ Automatic Caddy configuration
- ✅ Multi-project support

---

## 🌟 Features

- **Zero-config SSL** - Automatic HTTPS certificates
- **Multi-project support** - Run multiple GTM instances
- **Health monitoring** - Built-in container healthchecks
- **Easy management** - Simple scripts for daily operations
- **Backup system** - Automatic configuration backups
- **Production ready** - Optimized for server environments

## 📖 How it works

1. **Validation Phase**: Checks all prerequisites and validates user inputs
2. **Setup Phase**: Creates directory structure and configuration files
3. **Container Phase**: Deploys Docker containers with proper networking
4. **Proxy Phase**: Configures Caddy reverse proxy with SSL
5. **Testing Phase**: Verifies container health and connectivity
6. **Completion**: Provides management tools and usage instructions

Ready to get started? Run the installation command above! 🚀
