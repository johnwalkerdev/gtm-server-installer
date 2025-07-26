#!/bin/bash

# GTM Server Installer Script
# https://github.com/johnwalkerdev/gtm-server-installer

set -euo pipefail

# === Colors ===
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

function prompt_input() {
    local var_name="$1"
    local prompt="$2"
    read -rp "$prompt: " "$var_name"
}

function check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${RED}Please run this script as root.${NC}"
        exit 1
    fi
}

function find_available_port() {
    local port=$1
    while ss -tuln | grep -q ":$port"; do
        ((port++))
    done
    echo $port
}

function ask_to_install_dependencies() {
    read -rp "Do you want to install Nginx? [y/N]: " install_nginx
    if [[ "$install_nginx" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Installing Nginx...${NC}"
        apt update && apt install -y nginx
    else
        echo -e "${YELLOW}Skipping Nginx installation...${NC}"
    fi

    read -rp "Do you want to install Docker Compose? [y/N]: " install_compose
    if [[ "$install_compose" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Installing Docker Compose...${NC}"
        apt install -y docker-compose
    else
        echo -e "${YELLOW}Skipping Docker Compose installation...${NC}"
    fi

    read -rp "Do you want to install Certbot (for SSL)? [y/N]: " install_certbot
    if [[ "$install_certbot" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Installing Certbot...${NC}"
        apt install -y certbot python3-certbot-nginx
    else
        echo -e "${YELLOW}Skipping Certbot installation...${NC}"
    fi
}


function install_dependencies() {
    echo -e "${GREEN}Installing dependencies...${NC}"
    apt update
    apt install -y nginx certbot python3-certbot-nginx curl docker-compose
}

function setup_structure() {
    echo -e "${GREEN}Creating project structure...${NC}"
    if [ -d "/opt/$PROJECT_NAME" ]; then
        echo -e "${RED}Directory /opt/$PROJECT_NAME already exists. Aborting to prevent overwrite.${NC}"
        exit 1
    fi
    mkdir -p /opt/$PROJECT_NAME/{nginx,logs}
    cd /opt/$PROJECT_NAME

    echo -e "${GREEN}Saving .env file...${NC}"
    cat <<EOF > .env
PROJECT_NAME=$PROJECT_NAME
CONTAINER_CONFIG=$CONTAINER_CONFIG
PREVIEW_DOMAIN=$PREVIEW_DOMAIN
PRODUCTION_DOMAIN=$PRODUCTION_DOMAIN
PREVIEW_PORT=$PREVIEW_PORT
PRODUCTION_PORT=$PRODUCTION_PORT
PREVIEW_URL=https://$PREVIEW_DOMAIN
PRODUCTION_URL=https://$PRODUCTION_DOMAIN
LOG_PATH=/opt/$PROJECT_NAME/logs
NGINX_SITES_PATH=/etc/nginx/sites-available
EOF
}

function create_docker_compose() {
    echo -e "${GREEN}Creating Docker Compose file...${NC}"
    cat <<EOF > docker-compose.yml
version: '3.8'

services:
  gtm-preview:
    image: gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
    container_name: ${PROJECT_NAME}-preview
    ports:
      - "${PREVIEW_PORT}:8080"
    environment:
      - CONTAINER_CONFIG=$CONTAINER_CONFIG
      - RUN_AS_PREVIEW_SERVER=true
    volumes:
      - ./logs:/var/log/gtm
    restart: unless-stopped

  gtm-production:
    image: gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
    container_name: ${PROJECT_NAME}-production
    ports:
      - "${PRODUCTION_PORT}:8080"
    environment:
      - CONTAINER_CONFIG=$CONTAINER_CONFIG
      - RUN_AS_PREVIEW_SERVER=false
      - PREVIEW_SERVER_URL=https://$PREVIEW_DOMAIN
    volumes:
      - ./logs:/var/log/gtm
    restart: unless-stopped
    depends_on:
      - gtm-preview
EOF
}

function configure_nginx() {
    echo -e "${GREEN}Configuring Nginx...${NC}"

    cat <<EOF > /etc/nginx/sites-available/$PREVIEW_DOMAIN
server {
    listen 80;
    server_name $PREVIEW_DOMAIN;

    location / {
        proxy_pass http://localhost:$PREVIEW_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /healthz {
        proxy_pass http://localhost:$PREVIEW_PORT/healthz;
        access_log off;
    }
}
EOF

    cat <<EOF > /etc/nginx/sites-available/$PRODUCTION_DOMAIN
server {
    listen 80;
    server_name $PRODUCTION_DOMAIN;

    location / {
        proxy_pass http://localhost:$PRODUCTION_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /healthz {
        proxy_pass http://localhost:$PRODUCTION_PORT/healthz;
        access_log off;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/$PREVIEW_DOMAIN /etc/nginx/sites-enabled/
    ln -sf /etc/nginx/sites-available/$PRODUCTION_DOMAIN /etc/nginx/sites-enabled/

    nginx -t && systemctl reload nginx
}

function launch_services() {
    echo -e "${GREEN}Launching containers...${NC}"
    docker-compose up -d
    sleep 10
    docker-compose ps
}

function setup_ssl() {
    echo -e "${YELLOW}Setting up SSL (requires DNS to be propagated)...${NC}"
    certbot --nginx -d $PREVIEW_DOMAIN -d $PRODUCTION_DOMAIN --agree-tos --no-eff-email -m admin@$PRODUCTION_DOMAIN
    systemctl enable certbot.timer
    certbot renew --dry-run
}

# === Execution ===
check_root

if [[ "${1:-}" == "--ssl" ]]; then
    source /opt/${PROJECT_NAME:-gtm-project}/.env
    setup_ssl
    exit 0
fi

prompt_input PROJECT_NAME "Enter the project name (e.g. gtm-example)"
prompt_input CONTAINER_CONFIG "Paste your GTM Container Configuration (base64)"
prompt_input PREVIEW_DOMAIN "Enter your Preview domain (e.g. gtm-preview.example.com)"
prompt_input PRODUCTION_DOMAIN "Enter your Production domain (e.g. gtm.example.com)"

# Find dynamic ports
BASE_PORT=8080
PREVIEW_PORT=$(find_available_port $BASE_PORT)
PRODUCTION_PORT=$(find_available_port $((PREVIEW_PORT + 1)))

ask_to_install_dependencies
setup_structure
create_docker_compose
configure_nginx
launch_services

echo -e "
${GREEN}Health check responses:${NC}"
curl -s -o /dev/null -w "Preview: %{http_code}
" http://localhost:$PREVIEW_PORT/healthz
curl -s -o /dev/null -w "Production: %{http_code}
" http://localhost:$PRODUCTION_PORT/healthz

echo -e "
${YELLOW}You can re-use the configuration later using:${NC}"
echo "source /opt/$PROJECT_NAME/.env && sudo bash installer.sh --ssl"

echo -e "
${GREEN}Install complete!${NC}"
read -rp "
Do you want to issue SSL certificates now? [y/N]: " issue_ssl
if [[ "$issue_ssl" =~ ^[Yy]$ ]]; then
    setup_ssl
else
    echo -e "
${YELLOW}Next step: Run this script again with --ssl after DNS is ready:${NC}"
    echo -e "sudo bash installer.sh --ssl"
fi
