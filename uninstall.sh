#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== GTM Server-Side Project Uninstaller ===${NC}"
echo

# Step 1: List projects
projects=()
i=1

for dir in /opt/*/; do
    if [[ -f "${dir}docker-compose.yml" ]]; then
        project=$(basename "$dir")
        projects+=("$project")
        echo "$i) $project"
        ((i++))
    fi
done

if [ ${#projects[@]} -eq 0 ]; then
    echo -e "${RED}No GTM projects found in /opt.${NC}"
    exit 1
fi

echo
read -p "Enter the number of the project you want to uninstall: " selection

if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#projects[@]}" ]; then
    echo -e "${RED}Invalid selection.${NC}"
    exit 1
fi

selected_project="${projects[$((selection - 1))]}"
project_dir="/opt/$selected_project"

echo -e "${YELLOW}You selected: $selected_project${NC}"
read -p "Are you sure you want to completely delete this project? [y/N]: " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${RED}Aborted.${NC}"
    exit 0
fi

echo -e "${GREEN}Stopping and removing Docker containers...${NC}"
cd "$project_dir"
docker compose down -v --remove-orphans

echo -e "${GREEN}Deleting project files in $project_dir...${NC}"
rm -rf "$project_dir"

echo -e "${GREEN}Uninstallation of '$selected_project' completed.${NC}"
