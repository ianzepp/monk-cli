#!/bin/bash

# init_command.sh - Initialize CLI configuration directory with complete structure
#
# This command creates the CLI configuration directory and initializes all config files
# for clean domain separation following the new architecture.
#
# Creates:
#   ~/.config/monk/cli/server.json  - Server endpoint registry
#   ~/.config/monk/cli/tenant.json  - Tenant registry (server-scoped)
#   ~/.config/monk/cli/auth.json    - Authentication sessions (per server+tenant)
#   ~/.config/monk/cli/env.json     - Current working context (server+tenant+user)

# Get arguments from bashly
path="${args[path]}"
force_flag="${args[--force]}"

# Set configuration path (respects MONK_CLI_CONFIG_DIR environment variable)
if [[ -n "$path" ]]; then
    cli_config_dir="$path"
else
    cli_config_dir="${MONK_CLI_CONFIG_DIR:-${HOME}/.config/monk/cli}"
fi

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
if [[ ! -f "$server_file" ]] || [[ "$force_flag" = "1" ]]; then
    if [[ -f "$server_file" ]] && [[ "$force_flag" = "1" ]]; then
        echo -e "${YELLOW}→${NC} Force overwriting server.json"
    else
        echo -e "${YELLOW}→${NC} Creating server.json"
    fi
    cat > "$server_file" << 'EOF'
{
  "servers": {}
}
EOF
    echo -e "${GREEN}✓${NC} Created server.json"
else
    echo -e "${GREEN}✓${NC} server.json already exists"
fi

# Initialize tenant.json
tenant_file="${cli_config_dir}/tenant.json"
if [[ ! -f "$tenant_file" ]] || [[ "$force_flag" = "1" ]]; then
    if [[ -f "$tenant_file" ]] && [[ "$force_flag" = "1" ]]; then
        echo -e "${YELLOW}→${NC} Force overwriting tenant.json"
    else
        echo -e "${YELLOW}→${NC} Creating tenant.json"
    fi
    cat > "$tenant_file" << 'EOF'
{
  "tenants": {}
}
EOF
    echo -e "${GREEN}✓${NC} Created tenant.json"
else
    echo -e "${GREEN}✓${NC} tenant.json already exists"
fi

# Initialize auth.json
auth_file="${cli_config_dir}/auth.json"
if [[ ! -f "$auth_file" ]] || [[ "$force_flag" = "1" ]]; then
    if [[ -f "$auth_file" ]] && [[ "$force_flag" = "1" ]]; then
        echo -e "${YELLOW}→${NC} Force overwriting auth.json"
    else
        echo -e "${YELLOW}→${NC} Creating auth.json"
    fi
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

# Initialize env.json (never force overwrite - preserve user context)
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
    echo -e "${GREEN}✓${NC} env.json already exists (preserved)"
    if [[ "$force_flag" = "1" ]]; then
        echo -e "${BLUE}ℹ${NC} env.json is never overwritten to preserve your context"
    fi
fi

echo -e "${GREEN}✓${NC} Monk CLI configuration initialized successfully!"
echo
echo "CLI configuration files created in: ${cli_config_dir}"
echo "  - server.json: Server endpoint registry"
echo "  - tenant.json: Tenant registry (server-scoped)"
echo "  - auth.json: Authentication sessions per server+tenant"  
echo "  - env.json: Current working context (server+tenant+user)"
echo
echo "Next steps:"
echo "  1. Add a server: monk config server add <name> <hostname:port>"
echo "  2. Add a tenant: monk config tenant add <name> <display_name>"
echo "  3. Select server: monk config server use <name>"
echo "  4. Select tenant: monk config tenant use <name>"
echo "  5. Authenticate: monk auth login <tenant> <username>"
echo "  6. Start working: monk data list <schema>"