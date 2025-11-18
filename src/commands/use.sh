# Check dependencies
check_dependencies

# Get arguments from bashly
server="${args[server]}"
tenant="${args[tenant]:-}"

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for server/tenant management"
    exit 1
fi

# Handle '.' as current server
if [ "$server" = "." ]; then
    server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    
    if [ -z "$server" ] || [ "$server" = "null" ]; then
        print_error "No current server selected"
        print_info "Use 'monk use <server>' to select a server first"
        exit 1
    fi
    
    # If using '.' and no tenant specified, show error
    if [ -z "$tenant" ]; then
        print_error "Must specify tenant when using '.' for current server"
        print_info "Usage: monk use . <tenant>"
        exit 1
    fi
else
    # Validate server exists
    server_info=$(jq -r ".servers.\"$server\"" "$SERVER_CONFIG" 2>/dev/null)
    if [ "$server_info" = "null" ] || [ -z "$server_info" ]; then
        print_error "Server '$server' not found"
        print_info "Use 'monk config server list' to see available servers"
        exit 1
    fi
fi

# Switch server context
temp_file=$(mktemp)
jq --arg name "$server" '.current_server = $name' "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"

# Get server details for confirmation
server_info=$(jq -r ".servers.\"$server\"" "$SERVER_CONFIG" 2>/dev/null)
hostname=$(echo "$server_info" | jq -r '.hostname')
port=$(echo "$server_info" | jq -r '.port')
protocol=$(echo "$server_info" | jq -r '.protocol')
base_url="$protocol://$hostname:$port"

print_success "Switched to server: $server"
print_info "Endpoint: $base_url"

# If tenant specified, switch to it
if [ -n "$tenant" ]; then
    # Check if tenant exists and belongs to current server
    tenant_info=$(jq -r ".tenants.\"$tenant\"" "$TENANT_CONFIG" 2>/dev/null)
    if [ "$tenant_info" = "null" ] || [ -z "$tenant_info" ]; then
        print_error "Tenant '$tenant' not found"
        print_info "Use 'monk config tenant list' to see available tenants for server '$server'"
        exit 1
    fi
    
    tenant_server=$(echo "$tenant_info" | jq -r '.server')
    if [ "$tenant_server" != "$server" ]; then
        print_error "Tenant '$tenant' belongs to server '$tenant_server', but you're switching to '$server'"
        print_info "Use 'monk config tenant list' to see tenants for server '$server'"
        exit 1
    fi
    
    # Update current tenant in env config
    temp_file=$(mktemp)
    jq --arg tenant "$tenant" \
       '.current_tenant = $tenant' \
       "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"
    
    display_name=$(echo "$tenant_info" | jq -r '.display_name')
    print_success "Switched to tenant: $tenant ($display_name)"
    
    # Show authentication status for this tenant on current server
    session_key="${server}:${tenant}"
    if jq -e ".sessions.\"$session_key\"" "$AUTH_CONFIG" >/dev/null 2>&1; then
        user=$(jq -r ".sessions.\"$session_key\".user" "$AUTH_CONFIG" 2>/dev/null)
        print_info "Authenticated as: $user on server '$server'"
    else
        print_warning "Not authenticated for this tenant on server '$server'"
        print_info "Use 'monk auth login $tenant <username>' to authenticate"
    fi
else
    # Clear current tenant when switching servers without specifying tenant
    temp_file=$(mktemp)
    jq 'del(.current_tenant)' "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"
    print_info "Tenant context cleared. Use 'monk use $server <tenant>' to select a tenant"
fi
