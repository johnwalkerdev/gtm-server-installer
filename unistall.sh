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

# Function to detect project name from directory structure
detect_project_name() {
    local dir=$1
    local basename_dir=$(basename "$dir")
    
    # Try to extract project name from directory name
    if [[ $basename_dir =~ ^(.+)_gtm$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        # Fallback: look inside directory for project structure
        for subdir in "$dir"/gtm-*; do
            if [ -d "$subdir" ]; then
                local subdir_name=$(basename "$subdir")
                if [[ $subdir_name =~ ^gtm-(.+)$ ]]; then
                    echo "${BASH_REMATCH[1]}"
                    return
                fi
            fi
        done
        # Last resort: use directory name as-is
        echo "$basename_dir"
    fi
}

# Function to get project info
get_project_info() {
    local project_dir=$1
    local project_name=$2
    
    # Try to load from project.conf
    if [ -f "${project_dir}/project.conf" ]; then
        source "${project_dir}/project.conf"
        echo "📁 $project_name - https://${MAIN_DOMAIN:-N/A} (Port: ${MAIN_PORT:-N/A}) [Config: ✓]"
        return
    fi
    
    # Try to detect from docker-compose files
    local main_port="N/A"
    local preview_port="N/A"
    local main_domain="N/A"
    
    if [ -f "${project_dir}/gtm-${project_name}/docker-compose.yml" ]; then
        main_port=$(grep -o "'[0-9]*:8080'" "${project_dir}/gtm-${project_name}/docker-compose.yml" 2>/dev/null | cut -d"'" -f2 | cut -d":" -f1)
    fi
    
    if [ -f "${project_dir}/gtm-preview-${project_name}/docker-compose.yml" ]; then
        preview_port=$(grep -o "'[0-9]*:8080'" "${project_dir}/gtm-preview-${project_name}/docker-compose.yml" 2>/dev/null | cut -d"'" -f2 | cut -d":" -f1)
    fi
    
    # Try to get domain from Caddy config
    if [ -f /etc/caddy/Caddyfile ]; then
        main_domain=$(grep -A5 "# ${project_name}" /etc/caddy/Caddyfile 2>/dev/null | grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" | head -1 | tr -d ' {')
    fi
    
    echo "📁 $project_name - ${main_domain} (Port: ${main_port:-N/A}) [Config: ✗]"
}

# List available projects with improved detection
echo -e "${BLUE}Scanning for GTM projects...${NC}"
PROJECTS=()
PROJECT_DIRS=()

# Look for GTM project directories
for dir in /opt/*_gtm /opt/*gtm* /opt/gtm-* /root/*_gtm /home/*_gtm; do
    if [ -d "$dir" ]; then
        project_name=$(detect_project_name "$dir")
        if [ -n "$project_name" ]; then
            PROJECTS+=("$project_name")
            PROJECT_DIRS+=("$dir")
        fi
    fi
done

# Also check for containers that might indicate GTM projects
echo -e "${BLUE}Checking running containers...${NC}"
while IFS= read -r container; do
    if [[ $container =~ gtag-(server|preview)-(.+) ]]; then
        container_project="${BASH_REMATCH[2]}"
        # Check if we already have this project
        if [[ ! " ${PROJECTS[@]} " =~ " ${container_project} " ]]; then
            echo -e "${YELLOW}Found container-only project: $container_project${NC}"
            PROJECTS+=("$container_project")
            PROJECT_DIRS+=("container-only")
        fi
    fi
done < <(docker ps --format "{{.Names}}" 2>/dev/null | grep -E "gtag-(server|preview)-")

if [ ${#PROJECTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No GTM projects found${NC}"
    echo -e "${BLUE}Locations searched:${NC}"
    echo -e "• /opt/*_gtm"
    echo -e "• /opt/*gtm*" 
    echo -e "• /opt/gtm-*"
    echo -e "• Running Docker containers"
    echo -e "\n${BLUE}Manual check:${NC}"
    echo -e "• Directories: $(ls -d /opt/*gtm* 2>/dev/null | wc -l) found"
    echo -e "• Containers: $(docker ps --format '{{.Names}}' 2>/dev/null | grep -c gtag || echo '0') GTM containers running"
    exit 0
fi

echo -e "\n${BLUE}Detected GTM projects:${NC}"
for i in "${!PROJECTS[@]}"; do
    project_name="${PROJECTS[i]}"
    project_dir="${PROJECT_DIRS[i]}"
    
    if [ "$project_dir" = "container-only" ]; then
        echo -e "${YELLOW}📦 $project_name - Container only (no directory found)${NC}"
    else
        get_project_info "$project_dir" "$project_name"
    fi
done

echo ""
read -p "Enter the project name to uninstall: " PROJECT_NAME

# Check if project exists
if [[ ! " ${PROJECTS[@]} " =~ " ${PROJECT_NAME} " ]]; then
    echo -e "${RED}❌ Project '${PROJECT_NAME}' not found${NC}"
    echo -e "${YELLOW}Available projects: ${PROJECTS[*]}${NC}"
    exit 1
fi

# Find project directory
PROJECT_DIR=""
for i in "${!PROJECTS[@]}"; do
    if [ "${PROJECTS[i]}" = "$PROJECT_NAME" ]; then
        PROJECT_DIR="${PROJECT_DIRS[i]}"
        break
    fi
done

# Load configuration if available
MAIN_DOMAIN="gtm-${PROJECT_NAME}.unknown"
PREVIEW_DOMAIN="preview-gtm-${PROJECT_NAME}.unknown"
INSTALL_DATE="Unknown"

if [ "$PROJECT_DIR" != "container-only" ] && [ -f "${PROJECT_DIR}/project.conf" ]; then
    source "${PROJECT_DIR}/project.conf"
fi

echo -e "\n${BLUE}=== PROJECT DETAILS ===${NC}"
echo -e "📁 Project: ${PROJECT_NAME}"
echo -e "🌐 Main domain: https://${MAIN_DOMAIN}"
echo -e "🔍 Preview domain: https://${PREVIEW_DOMAIN}"
echo -e "📦 Directory: ${PROJECT_DIR}"
echo -e "📅 Installed on: ${INSTALL_DATE}"

echo -e "\n${RED}⚠️  WARNING: This action will:${NC}"
echo -e "• Stop and remove Docker containers"
if [ "$PROJECT_DIR" != "container-only" ]; then
    echo -e "• Remove entire directory ${PROJECT_DIR}"
fi
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
containers_removed=0

# Try different container name patterns
for container_pattern in "gtag-server-${PROJECT_NAME}" "gtag-preview-${PROJECT_NAME}" "${PROJECT_NAME}-gtag-server" "${PROJECT_NAME}-gtag-preview"; do
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_pattern}$"; then
        docker stop "$container_pattern" 2>/dev/null
        docker rm "$container_pattern" 2>/dev/null
        echo -e "${GREEN}✓ Container $container_pattern removed${NC}"
        ((containers_removed++))
    fi
done

if [ $containers_removed -eq 0 ]; then
    echo -e "${YELLOW}No containers found for project ${PROJECT_NAME}${NC}"
else
    echo -e "${GREEN}✓ $containers_removed containers removed${NC}"
fi

# Remove Caddy configurations
echo -e "${BLUE}2. Removing Caddy configurations...${NC}"
if [ -f /etc/caddy/Caddyfile ]; then
    # Make backup
    cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)
    
    # Remove project-specific lines (more aggressive pattern matching)
    sed -i "/# ${PROJECT_NAME}/,/^$/d" /etc/caddy/Caddyfile
    sed -i "/^.*gtm-${PROJECT_NAME}\..*{/,/^}$/d" /etc/caddy/Caddyfile
    sed -i "/^.*preview-gtm-${PROJECT_NAME}\..*{/,/^}$/d" /etc/caddy/Caddyfile
    
    # Reload Caddy
    systemctl reload caddy 2>/dev/null
    echo -e "${GREEN}✓ Caddy configurations cleaned${NC}"
fi

# Remove project directory
echo -e "${BLUE}3. Removing project files...${NC}"
if [ "$PROJECT_DIR" != "container-only" ] && [ -d "${PROJECT_DIR}" ]; then
    rm -rf "${PROJECT_DIR}"
    echo -e "${GREEN}✓ Directory ${PROJECT_DIR} removed${NC}"
elif [ "$PROJECT_DIR" = "container-only" ]; then
    echo -e "${YELLOW}No directory to remove (container-only project)${NC}"
else
    echo -e "${YELLOW}Directory ${PROJECT_DIR} not found${NC}"
fi

# Remove orphaned Docker images
echo -e "${BLUE}4. Cleaning unused Docker images...${NC}"
docker image prune -f > /dev/null 2>&1
echo -e "${GREEN}✓ Cleanup completed${NC}"

echo -e "\n${GREEN}✨ Uninstallation completed successfully!${NC}"
echo -e "\n${BLUE}What was removed:${NC}"
echo -e "• Containers: gtag-server-${PROJECT_NAME} and gtag-preview-${PROJECT_NAME}"
if [ "$PROJECT_DIR" != "container-only" ]; then
    echo -e "• Directory: ${PROJECT_DIR}"
fi
echo -e "• Caddy configurations for ${MAIN_DOMAIN} and ${PREVIEW_DOMAIN}"
echo -e "• Unused Docker images"

echo -e "\n${YELLOW}Verification:${NC}"
remaining_containers=$(docker ps --format 'table {{.Names}}' | grep -c gtag || echo '0')
remaining_projects=$(ls -d /opt/*_gtm 2>/dev/null | wc -l)
echo -e "• Remaining GTM containers: $remaining_containers"
echo -e "• Remaining GTM projects: $remaining_projects"

if [ $remaining_projects -gt 0 ]; then
    echo -e "\n${BLUE}Remaining projects:${NC}"
    for dir in /opt/*_gtm; do
        if [ -d "$dir" ]; then
            project_name=$(detect_project_name "$dir")
            get_project_info "$dir" "$project_name"
        fi
    done
fi

echo -e "\n${BLUE}Thank you for using GTM Server-Side Installer!${NC}"
