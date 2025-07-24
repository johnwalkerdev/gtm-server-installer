#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== GTM Server-Side Updater ===${NC}"
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
        
        # Verificar versão se existir
        if [ -f "${dir}/project.conf" ]; then
            source "${dir}/project.conf"
            version=${INSTALLER_VERSION:-"1.0"}
            echo -e "${GREEN}• $project_name${NC} (versão: $version)"
        else
            echo -e "${GREEN}• $project_name${NC} (versão: desconhecida)"
        fi
    fi
done

if [ ${#PROJECTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}Nenhum projeto GTM encontrado${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Opções de atualização:${NC}"
echo -e "1. Atualizar projeto específico"
echo -e "2. Atualizar todos os projetos"
echo -e "3. Apenas atualizar imagens Docker"
echo ""
read -p "Escolha uma opção (1-3): " OPTION

case $OPTION in
    1)
        echo ""
        read -p "Digite o nome do projeto para atualizar: " PROJECT_NAME
        
        # Verificar se o projeto existe
        if [[ ! " ${PROJECTS[@]} " =~ " ${PROJECT_NAME} " ]]; then
            echo -e "${RED}❌ Projeto '${PROJECT_NAME}' não encontrado${NC}"
            exit 1
        fi
        
        PROJECTS_TO_UPDATE=("$PROJECT_NAME")
        ;;
    2)
        PROJECTS_TO_UPDATE=("${PROJECTS[@]}")
        ;;
    3)
        echo -e "\n${BLUE}Atualizando apenas imagens Docker...${NC}"
        docker pull gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
        echo -e "${GREEN}✓ Imagens atualizadas${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Opção inválida${NC}"
        exit 1
        ;;
esac

# Função para atualizar um projeto
update_project() {
    local project_name=$1
    local project_dir="/opt/${project_name}_gtm"
    
    echo -e "\n${BLUE}=== Atualizando projeto: $project_name ===${NC}"
    
    # Verificar se existe
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}❌ Diretório $project_dir não encontrado${NC}"
        return 1
    fi
    
    # Carregar configurações
    if [ -f "${project_dir}/project.conf" ]; then
        source "${project_dir}/project.conf"
        echo -e "${BLUE}Versão atual: ${INSTALLER_VERSION:-"1.0"}${NC}"
    fi
    
    # Fazer backup das configurações
    echo -e "${BLUE}1. Fazendo backup das configurações...${NC}"
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
    
    echo -e "${GREEN}✓ Backup criado em: $backup_dir${NC}"
    
    # Parar containers
    echo -e "${BLUE}2. Parando containers...${NC}"
    cd "${project_dir}/gtm-${project_name}" && docker-compose stop
    cd "${project_dir}/gtm-preview-${project_name}" && docker-compose stop
    
    # Atualizar imagem Docker
    echo -e "${BLUE}3. Atualizando imagem Docker...${NC}"
    docker pull gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
    
    # Atualizar docker-compose.yml se necessário
    echo -e "${BLUE}4. Atualizando configurações...${NC}"
    
    # Atualizar docker-compose do container principal
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
    
    # Atualizar docker-compose do preview
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
    
    # Atualizar project.conf
    if [ -f "${project_dir}/project.conf" ]; then
        # Manter configurações existentes e atualizar versão
        sed -i "s/INSTALLER_VERSION=.*/INSTALLER_VERSION=2.0/" "${project_dir}/project.conf"
        echo "UPDATE_DATE=$(date '+%Y-%m-%d %H:%M:%S')" >> "${project_dir}/project.conf"
    fi
    
    # Criar/atualizar script de gerenciamento
    cat > "${project_dir}/manage.sh" << 'EOL'
#!/bin/bash
source project.conf

case $1 in
    "start")
        echo "Iniciando containers..."
        cd gtm-${PROJECT_NAME} && docker-compose start
        cd ../gtm-preview-${PROJECT_NAME} && docker-compose start
        ;;
    "stop")
        echo "Parando containers..."
        cd gtm-${PROJECT_NAME} && docker-compose stop
        cd ../gtm-preview-${PROJECT_NAME} && docker-compose stop
        ;;
    "restart")
        echo "Reiniciando containers..."
        cd gtm-${PROJECT_NAME} && docker-compose restart
        cd ../gtm-preview-${PROJECT_NAME} && docker-compose restart
        ;;
    "logs")
        echo "=== LOGS CONTAINER PRINCIPAL ==="
        cd gtm-${PROJECT_NAME} && docker-compose logs --tail=50
        echo -e "\n=== LOGS CONTAINER PREVIEW ==="
        cd ../gtm-preview-${PROJECT_NAME} && docker-compose logs --tail=50
        ;;
    "status")
        echo "Status dos containers:"
        docker ps | grep ${PROJECT_NAME}
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|logs|status}"
        exit 1
        ;;
esac
EOL
    
    chmod +x "${project_dir}/manage.sh"
    
    # Recriar containers
    echo -e "${BLUE}5. Recriando containers...${NC}"
    cd "${project_dir}/gtm-${project_name}" && docker-compose up -d --force-recreate
    cd "${project_dir}/gtm-preview-${project_name}" && docker-compose up -d --force-recreate
    
    # Testar containers
    echo -e "${BLUE}6. Testando containers...${NC}"
    sleep 15
    
    if curl -f http://localhost:10100/healthz > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Container principal funcionando${NC}"
    else
        echo -e "${RED}❌ Container principal com problemas${NC}"
    fi
    
    if curl -f http://localhost:10101/healthz > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Container preview funcionando${NC}"
    else
        echo -e "${RED}❌ Container preview com problemas${NC}"
    fi
    
    echo -e "${GREEN}✨ Projeto '$project_name' atualizado com sucesso!${NC}"
    return 0
}

# Atualizar projetos selecionados
for project in "${PROJECTS_TO_UPDATE[@]}"; do
    update_project "$project"
done

# Limpar imagens antigas
echo -e "\n${BLUE}Limpando imagens Docker antigas...${NC}"
docker image prune -f > /dev/null 2>&1

echo -e "\n${GREEN}✨ Atualização concluída!${NC}"
echo -e "\n${BLUE}Status geral dos containers:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep gtag

echo -e "\n${YELLOW}Comandos úteis:${NC}"
echo "• Verificar logs: cd /opt/[projeto]_gtm && ./manage.sh logs"
echo "• Status: cd /opt/[projeto]_gtm && ./manage.sh status"
echo "• Reiniciar: cd /opt/[projeto]_gtm && ./manage.sh restart"