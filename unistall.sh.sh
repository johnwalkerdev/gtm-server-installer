#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== GTM Server-Side Uninstaller ===${NC}"
echo -e "${BLUE}https://github.com/johnwalkerdev/gtm-server-installer${NC}\n"

# Verificar se é root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Por favor, execute como root (sudo)${NC}"
    exit 1
fi

# Listar projetos disponíveis
echo -e "${BLUE}Projetos GTM instalados:${NC}"
PROJECTS=()
for dir in /opt/*_gtm; do
    if [ -d "$dir" ]; then
        project_name=$(basename "$dir" | sed 's/_gtm$//')
        PROJECTS+=("$project_name")
        echo -e "${GREEN}• $project_name${NC} (${dir})"
    fi
done

if [ ${#PROJECTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}Nenhum projeto GTM encontrado${NC}"
    exit 0
fi

echo ""
read -p "Digite o nome do projeto para desinstalar: " PROJECT_NAME

# Verificar se o projeto existe
if [[ ! " ${PROJECTS[@]} " =~ " ${PROJECT_NAME} " ]]; then
    echo -e "${RED}❌ Projeto '${PROJECT_NAME}' não encontrado${NC}"
    exit 1
fi

PROJECT_DIR="/opt/${PROJECT_NAME}_gtm"

# Verificar se existe arquivo de configuração
if [ ! -f "${PROJECT_DIR}/project.conf" ]; then
    echo -e "${RED}❌ Arquivo de configuração não encontrado em ${PROJECT_DIR}/project.conf${NC}"
    exit 1
fi

# Carregar configurações
source "${PROJECT_DIR}/project.conf"

echo -e "\n${BLUE}=== DETALHES DO PROJETO ===${NC}"
echo -e "📁 Projeto: ${PROJECT_NAME}"
echo -e "🌐 Domínio principal: https://${MAIN_DOMAIN}"
echo -e "🔍 Domínio preview: https://${PREVIEW_DOMAIN}"
echo -e "📦 Diretório: ${PROJECT_DIR}"
echo -e "📅 Instalado em: ${INSTALL_DATE}"

echo -e "\n${RED}⚠️  ATENÇÃO: Esta ação irá:${NC}"
echo -e "• Parar e remover os containers Docker"
echo -e "• Remover todo o diretório ${PROJECT_DIR}"
echo -e "• Remover as configurações do Caddy"
echo -e "• Esta ação é IRREVERSÍVEL"

echo ""
read -p "Tem certeza que deseja desinstalar? Digite 'CONFIRMAR' para continuar: " CONFIRM

if [ "$CONFIRM" != "CONFIRMAR" ]; then
    echo -e "${YELLOW}Desinstalação cancelada${NC}"
    exit 0
fi

echo -e "\n${BLUE}Iniciando desinstalação...${NC}"

# Parar e remover containers
echo -e "${BLUE}1. Parando containers...${NC}"
if docker ps | grep -q "gtag-server-${PROJECT_NAME}"; then
    docker stop "gtag-server-${PROJECT_NAME}"
    docker rm "gtag-server-${PROJECT_NAME}"
    echo -e "${GREEN}✓ Container principal removido${NC}"
fi

if docker ps | grep -q "gtag-preview-${PROJECT_NAME}"; then
    docker stop "gtag-preview-${PROJECT_NAME}"
    docker rm "gtag-preview-${PROJECT_NAME}"
    echo -e "${GREEN}✓ Container preview removido${NC}"
fi

# Remover configurações do Caddy
echo -e "${BLUE}2. Removendo configurações do Caddy...${NC}"
if [ -f /etc/caddy/Caddyfile ]; then
    # Fazer backup
    cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)
    
    # Remover as linhas específicas do projeto
    sed -i "/# ${PROJECT_NAME} - GTM Server-Side/,/^$/d" /etc/caddy/Caddyfile
    sed -i "/^${MAIN_DOMAIN} {/,/^}$/d" /etc/caddy/Caddyfile
    sed -i "/^${PREVIEW_DOMAIN} {/,/^}$/d" /etc/caddy/Caddyfile
    
    # Recarregar Caddy
    systemctl reload caddy
    echo -e "${GREEN}✓ Configurações do Caddy removidas${NC}"
fi

# Remover diretório do projeto
echo -e "${BLUE}3. Removendo arquivos do projeto...${NC}"
if [ -d "${PROJECT_DIR}" ]; then
    rm -rf "${PROJECT_DIR}"
    echo -e "${GREEN}✓ Diretório ${PROJECT_DIR} removido${NC}"
fi

# Remover imagens Docker órfãs (opcional)
echo -e "${BLUE}4. Limpando imagens Docker não utilizadas...${NC}"
docker image prune -f > /dev/null 2>&1
echo -e "${GREEN}✓ Limpeza concluída${NC}"

echo -e "\n${GREEN}✨ Desinstalação concluída com sucesso!${NC}"
echo -e "\n${BLUE}O que foi removido:${NC}"
echo -e "• Containers: gtag-server-${PROJECT_NAME} e gtag-preview-${PROJECT_NAME}"
echo -e "• Diretório: ${PROJECT_DIR}"
echo -e "• Configurações do Caddy para ${MAIN_DOMAIN} e ${PREVIEW_DOMAIN}"
echo -e "• Imagens Docker não utilizadas"

echo -e "\n${YELLOW}Verificação:${NC}"
echo -e "• Containers restantes: $(docker ps --format 'table {{.Names}}' | grep -c gtag || echo '0')"
echo -e "• Projetos GTM restantes: $(ls -d /opt/*_gtm 2>/dev/null | wc -l)"

echo -e "\n${BLUE}Obrigado por usar o GTM Server-Side Installer!${NC}"