#!/bin/bash

# init_command.sh - Initialize CLI configuration directory with new structure
#
# This command creates the CLI configuration directory and initializes
# the three separate config files for clean domain separation.
#
# Creates:
#   ~/.config/monk/cli/server.json  - Infrastructure endpoints
#   ~/.config/monk/cli/auth.json    - Authentication sessions  
#   ~/.config/monk/cli/env.json     - Current working context

# Get the configuration path
if [[ -n "${args[path]}" ]]; then
    config_path="${args[path]}"
else
    config_path="${HOME}/.config/monk"
fi

# Set CLI config directory
cli_config_dir="${config_path}/cli"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Initializing Monk CLI configuration...${NC}"
echo "Configuration path: ${cli_config_dir}"

# Create CLI directory if it doesn't exist
if [[ ! -d "$cli_config_dir" ]]; then
    echo -e "${YELLOW}→${NC} Creating CLI directory: ${cli_config_dir}"
    mkdir -p "$cli_config_dir"
else
    echo -e "${GREEN}✓${NC} CLI directory exists: ${cli_config_dir}"
fi

# Initialize server.json
server_file="${cli_config_dir}/server.json"
if [[ ! -f "$server_file" ]]; then
    echo -e "${YELLOW}→${NC} Creating server.json"
    cat > "$server_file" << 'EOF'
{
  "servers": {}
}
EOF
    echo -e "${GREEN}✓${NC} Created server.json"
else
    echo -e "${GREEN}✓${NC} server.json already exists"
fi

# Initialize auth.json
auth_file="${cli_config_dir}/auth.json"
if [[ ! -f "$auth_file" ]]; then
    echo -e "${YELLOW}→${NC} Creating auth.json"
    cat > "$auth_file" << 'EOF'
{
  "sessions": {}
}
EOF
    chmod 600 "$auth_file"
    echo -e "${GREEN}✓${NC} Created auth.json (secure permissions)"
else
    echo -e "${GREEN}✓${NC} auth.json already exists"
fi

# Initialize env.json  
env_file="${cli_config_dir}/env.json"
if [[ ! -f "$env_file" ]]; then
    echo -e "${YELLOW}→${NC} Creating env.json"
    cat > "$env_file" << 'EOF'
{
  "current_server": null,
  "current_tenant": null,
  "current_user": null,
  "recents": []
}
EOF
    echo -e "${GREEN}✓${NC} Created env.json"
else
    echo -e "${GREEN}✓${NC} env.json already exists"
fi

echo -e "${GREEN}✓${NC} Monk CLI configuration initialized successfully!"
echo
echo "CLI configuration files created in: ${cli_config_dir}"
echo "  - server.json: Server endpoint configurations"
echo "  - auth.json: Authentication sessions per server+tenant"  
echo "  - env.json: Current working context (server+tenant+user)"
echo
echo "Next steps:"
echo "  1. Add a server: monk server add <name> <hostname:port>"
echo "  2. Select server: monk server use <name>"
echo "  3. Authenticate: monk auth login <tenant> <username>"
echo "  4. Start working: monk data select <schema>"