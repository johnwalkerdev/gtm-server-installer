# GTM Server-Side Complete Installer

🚀 **Fully automated installer** for Google Tag Manager Server-Side Container with **automatic dependency installation** and multi-project support.

## ⚡ One-Command Installation

### **Complete Installation (Installs everything automatically)**
```bash
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh | sudo bash
```

### **Alternative: Manual Download**
```bash
# Download the script
wget https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh

# Make executable and run
chmod +x install.sh
sudo ./install.sh
```

## 🎯 What This Installer Does Automatically

### **1. 🔧 Installs All Dependencies:**
- ✅ **Docker** (latest version with proper setup)
- ✅ **Docker Compose** (for container orchestration)
- ✅ **Caddy Web Server** (automatic HTTPS/SSL)
- ✅ **Net Tools** (for port checking)
- ✅ **Essential packages** (curl, wget, etc.)

### **2. 🚀 Configures GTM Environment:**
- ✅ Creates organized project structure
- ✅ Deploys Docker containers with healthchecks
- ✅ Sets up automatic SSL certificates
- ✅ Configures reverse proxy
- ✅ Generates management scripts

### **3. ✨ Provides Management Tools:**
- ✅ Project management scripts
- ✅ Automatic container monitoring
- ✅ Log management
- ✅ Easy restart/stop commands

## 📋 Supported Operating Systems

- ✅ **Ubuntu** (18.04, 20.04, 22.04, 24.04)
- ✅ **Debian** (10, 11, 12)

## 🎮 Installation Process

### **Step 1: Automatic Dependency Installation**
The installer will automatically detect and install:
```bash
=== INSTALLING DEPENDENCIES ===
This installer will automatically install all required dependencies:
• Docker
• Docker Compose  
• Caddy Web Server
• Net Tools

Continue with automatic dependency installation? (y/N):
```

### **Step 2: Project Configuration**
You'll be asked for:

1. **Project name** (e.g., `contaideal`)
   - Only letters, numbers, and hyphens
   - 3-63 characters
   - Must be unique

2. **Base domain** (e.g., `huskycontent.com`)
   - Your main domain pointing to the server
   - No subdomains

3. **GTM Container Configuration**
   - Long base64 string from Google Tag Manager
   - Get it from Admin → Container Settings

### **Step 3: Automatic Setup**
The installer will:
- Create project directories
- Configure Docker containers
- Set up SSL certificates
- Test connectivity
- Generate management tools

## 🌐 Generated URLs

The installer automatically creates:
- **Main Server:** `https://gtm-[project].[domain]`
- **Preview Server:** `https://preview-gtm-[project].[domain]`

**Example:**
- Project: `contaideal`
- Domain: `huskycontent.com`
- **Main:** `https://gtm-contaideal.huskycontent.com`
- **Preview:** `https://preview-gtm-contaideal.huskycontent.com`

## 🛠️ Post-Installation Management

### **Project Management Script**
```bash
# Navigate to your project
cd /opt/[project]_gtm

# Available commands
./manage.sh start    # Start containers
./manage.sh stop     # Stop containers  
./manage.sh restart  # Restart containers
./manage.sh logs     # View logs
./manage.sh status   # Check status
```

### **System-Wide Commands**
```bash
# View all GTM containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep gtag

# Update all projects  
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/update.sh | sudo bash

# Uninstall a project
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/uninstall.sh | sudo bash
```

## 🔒 Security Features

- ✅ **Automatic HTTPS** via Let's Encrypt
- ✅ **Container isolation** with health monitoring
- ✅ **Log rotation** to prevent disk issues
- ✅ **Input validation** for all user inputs
- ✅ **Automatic backups** of configurations

## 📊 Multi-Project Support

Install multiple GTM projects on the same server:

```bash
# Project 1
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh | sudo bash
# Name: contaideal → https://gtm-contaideal.yourdomain.com

# Project 2  
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh | sudo bash
# Name: company2 → https://gtm-company2.yourdomain.com

# Each project runs independently with its own containers and URLs
```

## ❓ Troubleshooting

### **Installation Issues**
```bash
# If curl installation fails, try manual download:
wget https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh
chmod +x install.sh
sudo ./install.sh

# Check system compatibility:
cat /etc/os-release
```

### **Container Issues**
```bash
# Check container status
cd /opt/[project]_gtm && ./manage.sh status

# View detailed logs
cd /opt/[project]_gtm && ./manage.sh logs

# Restart containers
cd /opt/[project]_gtm && ./manage.sh restart
```

### **SSL Certificate Issues**
```bash
# Check Caddy status
systemctl status caddy

# View Caddy logs
journalctl -u caddy -f

# Reload Caddy configuration
systemctl reload caddy
```

### **Port Conflicts**
```bash
# Check what's using GTM ports
netstat -tuln | grep -E ':(10100|10101)'

# Stop conflicting containers
docker stop $(docker ps -q --filter "publish=10100-10101")
```

## 📁 File Structure

```
/opt/[project]_gtm/
├── project.conf                    # Project configuration
├── manage.sh                       # Management script
├── logs/                          # Log directory
├── gtm-[project]/
│   ├── docker-compose.yml         # Main container config
│   └── gtag-server.env            # Environment variables
└── gtm-preview-[project]/
    ├── docker-compose.yml         # Preview container config
    └── gtag-preview-server.env    # Environment variables
```

## 🆘 Support & Documentation

- 📖 **Full Documentation:** Read this README completely
- 🐛 **Report Bugs:** [GitHub Issues](https://github.com/johnwalkerdev/gtm-server-installer/issues)
- 💡 **Feature Requests:** [GitHub Discussions](https://github.com/johnwalkerdev/gtm-server-installer/discussions)
- 📧 **Support:** Through GitHub issues only

## ⭐ Key Features

- **🚀 Zero-Configuration:** Installs everything automatically
- **🔐 Production-Ready:** Automatic HTTPS, monitoring, logging
- **📦 Multi-Project:** Run multiple GTM instances on one server
- **🛠️ Easy Management:** Simple commands for daily operations
- **🔄 Auto-Updates:** Built-in update system
- **💾 Safe Backups:** Automatic configuration backups
- **🖥️ OS Detection:** Supports Ubuntu and Debian automatically

---

## 🚀 Quick Start

**New to GTM Server-Side?** Just run this command on your Ubuntu/Debian server:

```bash
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh | sudo bash
```

The installer will guide you through everything! 🎉

**Requirements:** Just a clean Ubuntu/Debian server with your domain pointing to it. Everything else is installed automatically.

Ready to get started? Copy the command above and run it on your server! 🚀