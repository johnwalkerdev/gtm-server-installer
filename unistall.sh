#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== GTM Server-Side Uninstaller ===${NC}"
echo -e "${BLUE}https://github.com/johnwalkerdev/gtm-server-installer${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

# List available projects
echo -e "${BLUE}Installed GTM projects:${NC}"
PROJECTS=()
for dir in /opt/*_gtm; do
    if [ -d "$dir" ]; then
        project_name=$(basename "$dir" | sed 's/_gtm$//')
        PROJECTS+=("$project_name")
        echo -e "${GREEN}• $project_name${NC} (${dir})"
    fi
done

if [ ${#PROJECTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No GTM projects found${NC}"
    exit 0
fi

echo ""
read -p "Enter the project name to uninstall: " PROJECT_NAME

# Check if project exists
if [[ ! " ${PROJECTS[@]} " =~ " ${PROJECT_NAME} " ]]; then
    echo -e "${RED}❌ Project '${PROJECT_NAME}' not found${NC}"
    exit 1
fi

PROJECT_DIR="/opt/${PROJECT_NAME}_gtm"

# Check if configuration file exists
if [ ! -f "${PROJECT_DIR}/project.conf" ]; then
    echo -e "${RED}❌ Configuration file not found at ${PROJECT_DIR}/project.conf${NC}"
    exit 1
fi

# Load configurations
source "${PROJECT_DIR}/project.conf"

echo -e "\n${BLUE}=== PROJECT DETAILS ===${NC}"
echo -e "📁 Project: ${PROJECT_NAME}"
echo -e "🌐 Main domain: https://${MAIN_DOMAIN}"
echo -e "🔍 Preview domain: https://${PREVIEW_DOMAIN}"
echo -e "📦 Directory: ${PROJECT_DIR}"
echo -e "📅 Installed on: ${INSTALL_DATE}"

echo -e "\n${RED}⚠️  WARNING: This action will:${NC}"
echo -e "• Stop and remove Docker containers"
echo -e "• Remove entire directory ${PROJECT_DIR}"
echo -e "• Remove Caddy configurations"
echo -e "• This action is IRREVERSIBLE"

echo ""
read -p "Are you sure you want to uninstall? Type 'CONFIRM' to continue: " CONFIRM

if [ "$CONFIRM" != "CONFIRM" ]; then
    echo -e "${YELLOW}Uninstallation cancelled${NC}"
    exit 0
fi

echo -e "\n${BLUE}Starting uninstallation...${NC}"

# Stop and remove containers
echo -e "${BLUE}1. Stopping containers...${NC}"
if docker ps | grep -q "gtag-server-${PROJECT_NAME}"; then
    docker stop "gtag-server-${PROJECT_NAME}"
    docker rm "gtag-server-${PROJECT_NAME}"
    echo -e "${GREEN}✓ Main container removed${NC}"
fi

if docker ps | grep -q "gtag-preview-${PROJECT_NAME}"; then
    docker stop "gtag-preview-${PROJECT_NAME}"
    docker rm "gtag-preview-${PROJECT_NAME}"
    echo -e "${GREEN}✓ Preview container removed${NC}"
fi

# Remove Caddy configurations
echo -e "${BLUE}2. Removing Caddy configurations...${NC}"
if [ -f /etc/caddy/Caddyfile ]; then
    # Make backup
    cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)
    
    # Remove project-specific lines
    sed -i "/# ${PROJECT_NAME} - GTM Server-Side/,/^$/d" /etc/caddy/Caddyfile
    sed -i "/^${MAIN_DOMAIN} {/,/^}$/d" /etc/caddy/Caddyfile
    sed -i "/^${PREVIEW_DOMAIN} {/,/^}$/d" /etc/caddy/Caddyfile
    
    # Reload Caddy
    systemctl reload caddy
    echo -e "${GREEN}✓ Caddy configurations removed${NC}"
fi

# Remove project directory
echo -e "${BLUE}3. Removing project files...${NC}"
if [ -d "${PROJECT_DIR}" ]; then
    rm -rf "${PROJECT_DIR}"
    echo -e "${GREEN}✓ Directory ${PROJECT_DIR} removed${NC}"
fi

# Remove orphaned Docker images (optional)
echo -e "${BLUE}4. Cleaning unused Docker images...${NC}"
docker image prune -f > /dev/null 2>&1
echo -e "${GREEN}✓ Cleanup completed${NC}"

echo -e "\n${GREEN}✨ Uninstallation completed successfully!${NC}"
echo -e "\n${BLUE}What was removed:${NC}"
echo -e "• Containers: gtag-server-${PROJECT_NAME} and gtag-preview-${PROJECT_NAME}"
echo -e "• Directory: ${PROJECT_DIR}"
echo -e "• Caddy configurations for ${MAIN_DOMAIN} and ${PREVIEW_DOMAIN}"
echo -e "• Unused Docker images"

echo -e "\n${YELLOW}Verification:${NC}"
echo -e "• Remaining containers: $(docker ps --format 'table {{.Names}}' | grep -c gtag || echo '0')"
echo -e "• Remaining GTM projects: $(ls -d /opt/*_gtm 2>/dev/null | wc -l)"

echo -e "\n${BLUE}Thank you for using GTM Server-Side Installer!${NC}"