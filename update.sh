#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== GTM Server-Side Updater ===${NC}"
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
        
        # Check version if exists
        if [ -f "${dir}/project.conf" ]; then
            source "${dir}/project.conf"
            version=${INSTALLER_VERSION:-"1.0"}
            echo -e "${GREEN}• $project_name${NC} (version: $version)"
        else
            echo -e "${GREEN}• $project_name${NC} (version: unknown)"
        fi
    fi
done

if [ ${#PROJECTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No GTM projects found${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Update options:${NC}"
echo -e "1. Update specific project"
echo -e "2. Update all projects"
echo -e "3. Only update Docker images"
echo ""
read -p "Choose an option (1-3): " OPTION

case $OPTION in
    1)
        echo ""
        read -p "Enter project name to update: " PROJECT_NAME
        
        # Check if project exists
        if [[ ! " ${PROJECTS[@]} " =~ " ${PROJECT_NAME} " ]]; then
            echo -e "${RED}❌ Project '${PROJECT_NAME}' not found${NC}"
            exit 1
        fi
        
        PROJECTS_TO_UPDATE=("$PROJECT_NAME")
        ;;
    2)
        PROJECTS_TO_UPDATE=("${PROJECTS[@]}")
        ;;
    3)
        echo -e "\n${BLUE}Updating only Docker images...${NC}"
        docker pull gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
        echo -e "${GREEN}✓ Images updated${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# Function to update a project
update_project() {
    local project_name=$1
    local project_dir="/opt/${project_name}_gtm"
    
    echo -e "\n${BLUE}=== Updating project: $project_name ===${NC}"
    
    # Check if exists
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}❌ Directory $project_dir not found${NC}"
        return 1
    fi
    
    # Load configurations
    if [ -f "${project_dir}/project.conf" ]; then
        source "${project_dir}/project.conf"
        echo -e "${BLUE}Current version: ${INSTALLER_VERSION:-"1.0"}${NC}"
    fi
    
    # Backup configurations
    echo -e "${BLUE}1. Backing up configurations...${NC}"
    backup_dir="${project_dir}/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    if [ -f "${project_dir}/gtm-${project_name}/gtag-server.env" ]; then
        cp "${project_dir}/gtm-${project_name}/gtag-server.env" "$backup_dir/"
    fi
    if [ -f "${project_dir}/gtm-preview-${project_name}/gtag-preview-server.env" ]; then
        cp "${project_dir}/gtm-preview-${project_name}/gtag-preview-server.env" "$backup_dir/"
    fi
    if [ -f "${project_dir}/project.conf" ]; then
        cp "${project_dir}/project.conf" "$backup_dir/"
    fi
    
    echo -e "${GREEN}✓ Backup created at: $backup_dir${NC}"
    
    # Stop containers
    echo -e "${BLUE}2. Stopping containers...${NC}"
    cd "${project_dir}/gtm-${project_name}" && docker-compose stop
    cd "${project_dir}/gtm-preview-${project_name}" && docker-compose stop
    
    # Update Docker image
    echo -e "${BLUE}3. Updating Docker image...${NC}"
    docker pull gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
    
    # Update docker-compose.yml if necessary
    echo -e "${BLUE}4. Updating configurations...${NC}"
    
    # Update main container docker-compose
    cat > "${project_dir}/gtm-${project_name}/docker-compose.yml" << EOL
services:
  gtag-server:
    container_name: gtag-server-${project_name}
    image: gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
    restart: unless-stopped
    env_file:
      - ./gtag-server.env
    ports:
      - '10100:8080'
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
    
    # Update preview docker-compose
    cat > "${project_dir}/gtm-preview-${project_name}/docker-compose.yml" << EOL
services:
  gtag-preview:
    container_name: gtag-preview-${project_name}
    image: gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
    restart: unless-stopped
    env_file:
      - ./gtag-preview-server.env
    ports:
      - '10101:8080'
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
    
    # Update project.conf
    if [ -f "${project_dir}/project.conf" ]; then
        # Keep existing configurations and update version
        sed -i "s/INSTALLER_VERSION=.*/INSTALLER_VERSION=2.0/" "${project_dir}/project.conf"
        echo "UPDATE_DATE=$(date '+%Y-%m-%d %H:%M:%S')" >> "${project_dir}/project.conf"
    fi
    
    # Create/update management script
    cat > "${project_dir}/manage.sh" << 'EOL'
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
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status}"
        exit 1
        ;;
esac
EOL
    
    chmod +x "${project_dir}/manage.sh"
    
    # Recreate containers
    echo -e "${BLUE}5. Recreating containers...${NC}"
    cd "${project_dir}/gtm-${project_name}" && docker-compose up -d --force-recreate
    cd "${project_dir}/gtm-preview-${project_name}" && docker-compose up -d --force-recreate
    
    # Test containers
    echo -e "${BLUE}6. Testing containers...${NC}"
    sleep 15
    
    if curl -f http://localhost:10100/healthz > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Main container working${NC}"
    else
        echo -e "${RED}❌ Main container has issues${NC}"
    fi
    
    if curl -f http://localhost:10101/healthz > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Preview container working${NC}"
    else
        echo -e "${RED}❌ Preview container has issues${NC}"
    fi
    
    echo -e "${GREEN}✨ Project '$project_name' updated successfully!${NC}"
    return 0
}

# Update selected projects
for project in "${PROJECTS_TO_UPDATE[@]}"; do
    update_project "$project"
done

# Clean old images
echo -e "\n${BLUE}Cleaning old Docker images...${NC}"
docker image prune -f > /dev/null 2>&1

echo -e "\n${GREEN}✨ Update completed!${NC}"
echo -e "\n${BLUE}General container status:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep gtag

echo -e "\n${YELLOW}Useful commands:${NC}"
echo "• Check logs: cd /opt/[project]_gtm && ./manage.sh logs"
echo "• Status: cd /opt/[project]_gtm && ./manage.sh status"
echo "• Restart: cd /opt/[project]_gtm && ./manage.sh restart"