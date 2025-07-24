#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== GTM Server-Side Installer ===${NC}"
echo -e "${BLUE}https://github.com/johnwalkerdev/gtm-server-installer${NC}\n"

# Verificar se é root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Por favor, execute como root (sudo)${NC}"
    exit 1
fi

# Verificar dependências
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $2 não está instalado${NC}"
        echo -e "${YELLOW}Execute: $3${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ $2 instalado${NC}"
    fi
}

echo -e "${BLUE}Verificando dependências...${NC}"
check_dependency "docker" "Docker" "curl -fsSL https://get.docker.com | sh"
check_dependency "docker-compose" "Docker Compose" "apt install docker-compose"
check_dependency "caddy" "Caddy" "apt install caddy"

# Função para validar nome do projeto
validate_project_name() {
    if [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Função para validar domínio base
validate_domain() {
    if [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Coletar informações
echo -e "\n${BLUE}Configuração do Projeto${NC}"
read -p "Digite o nome do projeto (ex: contaideal): " PROJECT_NAME
if ! validate_project_name "$PROJECT_NAME"; then
    echo -e "${RED}Nome do projeto inválido. Use apenas letras, números e hífen${NC}"
    exit 1
fi

read -p "Digite o domínio base (ex: huskycontent.com): " BASE_DOMAIN
if ! validate_domain "test.$BASE_DOMAIN"; then
    echo -e "${RED}Domínio base inválido${NC}"
    exit 1
fi

read -p "Digite a Container Configuration do GTM: " CONTAINER_CONFIG

# Definir domínios
MAIN_DOMAIN="gtm-${PROJECT_NAME}.${BASE_DOMAIN}"
PREVIEW_DOMAIN="preview-gtm-${PROJECT_NAME}.${BASE_DOMAIN}"

# Criar diretórios
echo -e "\n${BLUE}Criando estrutura...${NC}"
PROJECT_DIR="/opt/${PROJECT_NAME}_gtm"
mkdir -p "${PROJECT_DIR}/gtm-${PROJECT_NAME}"
mkdir -p "${PROJECT_DIR}/gtm-preview-${PROJECT_NAME}"

# Criar docker-compose para o container principal
cat > "${PROJECT_DIR}/gtm-${PROJECT_NAME}/docker-compose.yml" << EOL
services:
  gtag-server:
    container_name: gtag-server-${PROJECT_NAME}
    image: gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
    restart: unless-stopped
    env_file:
      - ./gtag-server.env
    ports:
      - '10100:8080'
EOL

# Criar docker-compose para o preview
cat > "${PROJECT_DIR}/gtm-preview-${PROJECT_NAME}/docker-compose.yml" << EOL
services:
  gtag-preview:
    container_name: gtag-preview-${PROJECT_NAME}
    image: gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
    restart: unless-stopped
    env_file:
      - ./gtag-preview-server.env
    ports:
      - '10101:8080'
EOL

# Criar arquivo de configuração do container principal
cat > "${PROJECT_DIR}/gtm-${PROJECT_NAME}/gtag-server.env" << EOL
CONTAINER_CONFIG=${CONTAINER_CONFIG}
RUN_AS_PREVIEW_SERVER=false
PREVIEW_SERVER_URL=https://${PREVIEW_DOMAIN}
EOL

# Criar arquivo de configuração do preview
cat > "${PROJECT_DIR}/gtm-preview-${PROJECT_NAME}/gtag-preview-server.env" << EOL
CONTAINER_CONFIG=${CONTAINER_CONFIG}
RUN_AS_PREVIEW_SERVER=true
EOL

# Configurar Caddy
echo -e "${BLUE}Configurando Caddy...${NC}"
cat > /etc/caddy/Caddyfile << EOL
${MAIN_DOMAIN} {
    header Service-Worker-Allowed "/"
    reverse_proxy localhost:10100
}

${PREVIEW_DOMAIN} {
    header Service-Worker-Allowed "/"
    reverse_proxy localhost:10101
}
EOL

# Reiniciar Caddy
echo -e "${BLUE}Reiniciando Caddy...${NC}"
systemctl reload caddy

# Iniciar containers
echo -e "${BLUE}Iniciando containers...${NC}"
cd "${PROJECT_DIR}/gtm-${PROJECT_NAME}" && docker-compose down && docker-compose up -d
cd "${PROJECT_DIR}/gtm-preview-${PROJECT_NAME}" && docker-compose down && docker-compose up -d

# Criar arquivo de configuração do projeto
echo -e "\n${BLUE}Salvando configuração...${NC}"
cat > "${PROJECT_DIR}/project.conf" << EOL
PROJECT_NAME=${PROJECT_NAME}
MAIN_DOMAIN=${MAIN_DOMAIN}
PREVIEW_DOMAIN=${PREVIEW_DOMAIN}
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOL

echo -e "\n${GREEN}✨ Instalação concluída!${NC}"
echo -e "\n${BLUE}Informações do Projeto:${NC}"
echo -e "📁 Diretório: ${PROJECT_DIR}"
echo -e "🌐 Container principal: https://${MAIN_DOMAIN}"
echo -e "🔍 Container preview: https://${PREVIEW_DOMAIN}"

# Verificar status
echo -e "\n${BLUE}Status dos containers:${NC}"
docker ps | grep "${PROJECT_NAME}"

echo -e "\n${YELLOW}⚠️  Próximos passos:${NC}"
echo "1. Aguarde alguns minutos para os certificados SSL serem gerados"
echo "2. Teste o acesso aos domínios no navegador"
echo "3. Configure seu GTM para usar os domínios acima"
echo -e "\n${BLUE}Precisa de ajuda? https://github.com/johnwalkerdev/gtm-server-installer/issues${NC}" 