#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== GTM Server-Side Complete Installer ===${NC}"
echo -e "${BLUE}https://github.com/johnwalkerdev/gtm-server-installer${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

# Detect OS distribution
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        echo -e "${RED}Cannot detect OS. This installer supports Ubuntu/Debian only.${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Detected OS: $OS $VER${NC}"
    
    if [[ $OS != *"Ubuntu"* ]] && [[ $OS != *"Debian"* ]]; then
        echo -e "${RED}This installer only supports Ubuntu and Debian${NC}"
        exit 1
    fi
}

# Update package repositories
update_repos() {
    echo -e "${BLUE}Updating package repositories...${NC}"
    apt update -qq
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Repositories updated${NC}"
    else
        echo -e "${RED}❌ Failed to update repositories${NC}"
        exit 1
    fi
}

# Install dependency function
install_dependency() {
    local name=$1
    local package=$2
    local custom_install=$3
    
    if command -v ${name} &> /dev/null; then
        echo -e "${GREEN}✓ $name already installed${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Installing $name...${NC}"
    
    if [ -n "$custom_install" ]; then
        # Custom installation
        eval $custom_install
    else
        # Installation via apt
        apt install -y $package -qq
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $name installed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to install $name${NC}"
        exit 1
    fi
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓ Docker already installed${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Installing Docker...${NC}"
    
    # Install Docker dependencies
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release -qq
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update repositories
    apt update -qq
    
    # Install Docker
    apt install -y docker-ce docker-ce-cli containerd.io -qq
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group (if not root)
    if [ "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
        echo -e "${YELLOW}Note: You may need to log out and back in for Docker permissions to take effect${NC}"
    fi
    
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓ Docker installed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to install Docker${NC}"
        exit 1
    fi
}

# Install Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✓ Docker Compose already installed${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Installing Docker Compose...${NC}"
    apt install -y docker-compose -qq
    
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✓ Docker Compose installed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to install Docker Compose${NC}"
        exit 1
    fi
}

# Install Caddy
install_caddy() {
    if command -v caddy &> /dev/null; then
        echo -e "${GREEN}✓ Caddy already installed${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Installing Caddy...${NC}"
    
    # Install dependencies
    apt install -y debian-keyring debian-archive-keyring apt-transport-https -qq
    
    # Add Caddy GPG key
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    
    # Add Caddy repository
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    
    # Update repositories
    apt update -qq
    
    # Install Caddy
    apt install -y caddy -qq
    
    # Start and enable Caddy
    systemctl start caddy
    systemctl enable caddy
    
    if command -v caddy &> /dev/null; then
        echo -e "${GREEN}✓ Caddy installed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to install Caddy${NC}"
        exit 1
    fi
}

# Find next available port starting from a base port
find_available_port() {
    local base_port=$1
    local port=$base_port
    
    while netstat -tuln | grep ":$port " > /dev/null 2>&1; do
        ((port++))
        if [ $port -gt $((base_port + 100)) ]; then
            echo -e "${RED}❌ Could not find available port in range ${base_port}-$((base_port + 100))${NC}"
            exit 1
        fi
    done
    
    echo $port
}

# Check existing projects and show them
show_existing_projects() {
    echo -e "${BLUE}Existing GTM projects on this server:${NC}"
    local found_projects=false
    
    for dir in /opt/*_gtm; do
        if [ -d "$dir" ]; then
            project_name=$(basename "$dir" | sed 's/_gtm$//')
            if [ -f "${dir}/project.conf" ]; then
                source "${dir}/project.conf"
                echo -e "${GREEN}• $project_name${NC} - Main: https://${MAIN_DOMAIN} (Port: ${MAIN_PORT})"
                found_projects=true
            fi
        fi
    done
    
    if [ "$found_projects" = false ]; then
        echo -e "${YELLOW}No existing projects found${NC}"
    fi
    echo ""
}

# Function to validate project name
validate_project_name() {
    if [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate base domain
validate_domain() {
    if [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate Container Configuration
validate_container_config() {
    if [[ ${#1} -lt 50 ]]; then
        echo -e "${RED}Container Configuration seems too short (minimum 50 characters)${NC}"
        return 1
    fi
    if [[ ! $1 =~ ^[a-zA-Z0-9+/]+=*$ ]]; then
        echo -e "${RED}Container Configuration must be a valid base64 string${NC}"
        return 1
    fi
    return 0
}

# Main script starts here
detect_os

echo -e "\n${BLUE}=== INSTALLING DEPENDENCIES ===${NC}"
echo -e "${YELLOW}This installer will automatically install all required dependencies:${NC}"
echo -e "• Docker"
echo -e "• Docker Compose"
echo -e "• Caddy Web Server"
echo -e "• Net Tools"
echo ""
read -p "Continue with automatic dependency installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled${NC}"
    exit 0
fi

# Update repositories
update_repos

# Install basic dependencies
install_dependency "curl" "curl"
install_dependency "wget" "wget"
install_dependency "netstat" "net-tools"

# Install Docker
install_docker

# Install Docker Compose
install_docker_compose

# Install Caddy
install_caddy

echo -e "\n${GREEN}✨ All dependencies installed successfully!${NC}"

# Show existing projects
show_existing_projects

# Find available ports automatically
echo -e "${BLUE}Finding available ports...${NC}"
MAIN_PORT=$(find_available_port 10100)
PREVIEW_PORT=$(find_available_port $((MAIN_PORT + 1)))

echo -e "${GREEN}✓ Found available ports: Main: $MAIN_PORT, Preview: $PREVIEW_PORT${NC}"

# Collect project information
echo -e "\n${BLUE}=== PROJECT CONFIGURATION ===${NC}"
echo -e "${YELLOW}Now you need to provide the following information:${NC}"
echo -e "1. Project name (only letters, numbers, and hyphens)"
echo -e "2. Base domain (e.g., yoursite.com)"
echo -e "3. GTM Container Configuration (long string from Google)\n"

while true; do
    read -p "Enter project name (e.g., contaideal): " PROJECT_NAME
    if validate_project_name "$PROJECT_NAME"; then
        # Check if project already exists
        if [ -d "/opt/${PROJECT_NAME}_gtm" ]; then
            echo -e "${RED}❌ Project '${PROJECT_NAME}' already exists in /opt/${PROJECT_NAME}_gtm${NC}"
            echo -e "${YELLOW}Choose another name or remove the existing project${NC}"
            continue
        fi
        echo -e "${GREEN}✓ Valid project name${NC}"
        break
    else
        echo -e "${RED}❌ Invalid name. Use only letters, numbers, and hyphens (3-63 characters)${NC}"
    fi
done

while true; do
    read -p "Enter base domain (e.g., huskycontent.com): " BASE_DOMAIN
    if validate_domain "$BASE_DOMAIN"; then
        echo -e "${GREEN}✓ Valid domain${NC}"
        break
    else
        echo -e "${RED}❌ Invalid domain. Use format: example.com${NC}"
    fi
done

echo -e "\n${YELLOW}To get the Container Configuration:${NC}"
echo -e "1. Access Google Tag Manager"
echo -e "2. Go to Admin > Container Settings"
echo -e "3. Copy the 'Container Configuration' value"
echo ""

while true; do
    read -p "Paste GTM Container Configuration: " CONTAINER_CONFIG
    if validate_container_config "$CONTAINER_CONFIG"; then
        echo -e "${GREEN}✓ Valid Container Configuration${NC}"
        break
    else
        echo -e "${RED}❌ Invalid Container Configuration${NC}"
    fi
done

# Define domains
MAIN_DOMAIN="gtm-${PROJECT_NAME}.${BASE_DOMAIN}"
PREVIEW_DOMAIN="preview-gtm-${PROJECT_NAME}.${BASE_DOMAIN}"

# Show summary before continuing
echo -e "\n${BLUE}=== CONFIGURATION SUMMARY ===${NC}"
echo -e "📁 Project: ${PROJECT_NAME}"
echo -e "🌐 Main domain: https://${MAIN_DOMAIN} (Port: $MAIN_PORT)"
echo -e "🔍 Preview domain: https://${PREVIEW_DOMAIN} (Port: $PREVIEW_PORT)"
echo -e "📦 Directory: /opt/${PROJECT_NAME}_gtm"
echo ""
read -p "Continue installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled${NC}"
    exit 0
fi

# Backup Caddyfile if it exists
if [ -f /etc/caddy/Caddyfile ]; then
    echo -e "${BLUE}Backing up Caddyfile...${NC}"
    cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create directories
echo -e "\n${BLUE}Creating structure...${NC}"
PROJECT_DIR="/opt/${PROJECT_NAME}_gtm"
mkdir -p "${PROJECT_DIR}/gtm-${PROJECT_NAME}"
mkdir -p "${PROJECT_DIR}/gtm-preview-${PROJECT_NAME}"
mkdir -p "${PROJECT_DIR}/logs"

# Create docker-compose for main container
cat > "${PROJECT_DIR}/gtm-${PROJECT_NAME}/docker-compose.yml" << EOL
services:
  gtag-server:
    container_name: gtag-server-${PROJECT_NAME}
    image: gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
    restart: unless-stopped
    env_file:
      - ./gtag-server.env
    ports:
      - '${MAIN_PORT}:8080'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOL

# Create docker-compose for preview
cat > "${PROJECT_DIR}/gtm-preview-${PROJECT_NAME}/docker-compose.yml" << EOL
services:
  gtag-preview:
    container_name: gtag-preview-${PROJECT_NAME}
    image: gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
    restart: unless-stopped
    env_file:
      - ./gtag-preview-server.env
    ports:
      - '${PREVIEW_PORT}:8080'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOL

# Create main container configuration file
cat > "${PROJECT_DIR}/gtm-${PROJECT_NAME}/gtag-server.env" << EOL
CONTAINER_CONFIG=${CONTAINER_CONFIG}
RUN_AS_PREVIEW_SERVER=false
PREVIEW_SERVER_URL=https://${PREVIEW_DOMAIN}
EOL

# Create preview configuration file
cat > "${PROJECT_DIR}/gtm-preview-${PROJECT_NAME}/gtag-preview-server.env" << EOL
CONTAINER_CONFIG=${CONTAINER_CONFIG}
RUN_AS_PREVIEW_SERVER=true
EOL

# Configure or update Caddy
echo -e "${BLUE}Configuring Caddy...${NC}"
if [ -f /etc/caddy/Caddyfile ] && grep -q "# GTM Projects" /etc/caddy/Caddyfile; then
    # Add to existing Caddyfile
    cat >> /etc/caddy/Caddyfile << EOL

# ${PROJECT_NAME} - GTM Server-Side
${MAIN_DOMAIN} {
    header Service-Worker-Allowed "/"
    reverse_proxy localhost:${MAIN_PORT}
}

${PREVIEW_DOMAIN} {
    header Service-Worker-Allowed "/"
    reverse_proxy localhost:${PREVIEW_PORT}
}
EOL
else
    # Create new Caddyfile
    cat > /etc/caddy/Caddyfile << EOL
# GTM Projects

# ${PROJECT_NAME} - GTM Server-Side
${MAIN_DOMAIN} {
    header Service-Worker-Allowed "/"
    reverse_proxy localhost:${MAIN_PORT}
}

${PREVIEW_DOMAIN} {
    header Service-Worker-Allowed "/"
    reverse_proxy localhost:${PREVIEW_PORT}
}
EOL
fi

# Restart Caddy
echo -e "${BLUE}Restarting Caddy...${NC}"
systemctl reload caddy

# Start containers
echo -e "${BLUE}Starting containers...${NC}"
cd "${PROJECT_DIR}/gtm-${PROJECT_NAME}" && docker-compose down && docker-compose up -d
cd "${PROJECT_DIR}/gtm-preview-${PROJECT_NAME}" && docker-compose down && docker-compose up -d

# Test containers
test_containers() {
    echo -e "${BLUE}Testing containers...${NC}"
    sleep 15
    
    if curl -f http://localhost:${MAIN_PORT}/healthz > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Main container responding on port ${MAIN_PORT}${NC}"
    else
        echo -e "${RED}❌ Main container has issues${NC}"
        echo -e "${YELLOW}Check logs: cd ${PROJECT_DIR}/gtm-${PROJECT_NAME} && docker-compose logs${NC}"
    fi
    
    if curl -f http://localhost:${PREVIEW_PORT}/healthz > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Preview container responding on port ${PREVIEW_PORT}${NC}"
    else
        echo -e "${RED}❌ Preview container has issues${NC}"
        echo -e "${YELLOW}Check logs: cd ${PROJECT_DIR}/gtm-preview-${PROJECT_NAME} && docker-compose logs${NC}"
    fi
}

test_containers

# Create project configuration file
echo -e "\n${BLUE}Saving configuration...${NC}"
cat > "${PROJECT_DIR}/project.conf" << EOL
PROJECT_NAME=${PROJECT_NAME}
BASE_DOMAIN=${BASE_DOMAIN}
MAIN_DOMAIN=${MAIN_DOMAIN}
PREVIEW_DOMAIN=${PREVIEW_DOMAIN}
MAIN_PORT=${MAIN_PORT}
PREVIEW_PORT=${PREVIEW_PORT}
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
INSTALLER_VERSION=2.1
EOL

# Create management scripts
cat > "${PROJECT_DIR}/manage.sh" << 'EOL'
#!/bin/bash
source project.conf

case $1 in
    "start")
        echo "Starting containers..."
        cd gtm-${PROJECT_NAME} && docker-compose start
        cd ../gtm-preview-${PROJECT_NAME} && docker-compose start
        ;;
    "stop")
        echo "Stopping containers..."
        cd gtm-${PROJECT_NAME} && docker-compose stop
        cd ../gtm-preview-${PROJECT_NAME} && docker-compose stop
        ;;
    "restart")
        echo "Restarting containers..."
        cd gtm-${PROJECT_NAME} && docker-compose restart
        cd ../gtm-preview-${PROJECT_NAME} && docker-compose restart
        ;;
    "logs")
        echo "=== MAIN CONTAINER LOGS ==="
        cd gtm-${PROJECT_NAME} && docker-compose logs --tail=50
        echo -e "\n=== PREVIEW CONTAINER LOGS ==="
        cd ../gtm-preview-${PROJECT_NAME} && docker-compose logs --tail=50
        ;;
    "status")
        echo "Container status:"
        docker ps | grep ${PROJECT_NAME}
        echo "Main: http://localhost:${MAIN_PORT}/healthz"
        echo "Preview: http://localhost:${PREVIEW_PORT}/healthz"
        ;;
    "info")
        echo "=== PROJECT INFORMATION ==="
        echo "Project: ${PROJECT_NAME}"
        echo "Main URL: https://${MAIN_DOMAIN} (Port: ${MAIN_PORT})"
        echo "Preview URL: https://${PREVIEW_DOMAIN} (Port: ${PREVIEW_PORT})"
        echo "Directory: $(pwd)"
        echo "Installed: ${INSTALL_DATE}"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|info}"
        exit 1
        ;;
esac
EOL

chmod +x "${PROJECT_DIR}/manage.sh"

echo -e "\n${GREEN}✨ Installation completed successfully!${NC}"
echo -e "\n${BLUE}=== PROJECT INFORMATION ===${NC}"
echo -e "📁 Directory: ${PROJECT_DIR}"
echo -e "🌐 Main container: https://${MAIN_DOMAIN} (Port: ${MAIN_PORT})"
echo -e "🔍 Preview container: https://${PREVIEW_DOMAIN} (Port: ${PREVIEW_PORT})"
echo -e "🛠️  Management script: ${PROJECT_DIR}/manage.sh"

# Check status
echo -e "\n${BLUE}Container status:${NC}"
docker ps | grep "${PROJECT_NAME}"

# Show all projects summary
echo -e "\n${BLUE}=== ALL GTM PROJECTS ON THIS SERVER ===${NC}"
for dir in /opt/*_gtm; do
    if [ -d "$dir" ]; then
        project_name=$(basename "$dir" | sed 's/_gtm$//')
        if [ -f "${dir}/project.conf" ]; then
            source "${dir}/project.conf"
            status="$(docker ps | grep $project_name > /dev/null && echo '🟢 Running' || echo '🔴 Stopped')"
            echo -e "${GREEN}• $project_name${NC} - https://${MAIN_DOMAIN} (Port: ${MAIN_PORT}) $status"
        fi
    fi
done

echo -e "\n${YELLOW}⚠️  Next steps:${NC}"
echo "1. Wait 2-5 minutes for SSL certificates to be generated"
echo "2. Test domain access in your browser"
echo "3. Configure your GTM to use:"
echo "   - Server Container URL: https://${MAIN_DOMAIN}"
echo "   - Preview Server URL: https://${PREVIEW_DOMAIN}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "• Manage project: cd ${PROJECT_DIR} && ./manage.sh {start|stop|restart|logs|status|info}"
echo "• View all projects: docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep gtag"
echo "• Update projects: curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/update.sh | sudo bash"
echo -e "\n${BLUE}Need help? https://github.com/johnwalkerdev/gtm-server-installer/issues${NC}"
