# Check dependencies
check_dependencies

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for tenant management"
    exit 1
fi

# Get arguments from bashly
name="${args[name]}"

# Get current server
current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
if [ -z "$current_server" ] || [ "$current_server" = "null" ]; then
    print_error "No current server selected"
    print_info "Use 'monk server use <name>' to select a server first"
    exit 1
fi

# Check if tenant exists and belongs to current server
tenant_info=$(jq -r ".tenants.\"$name\"" "$TENANT_CONFIG" 2>/dev/null)
if [ "$tenant_info" = "null" ]; then
    print_error "Tenant '$name' not found"
    print_info "Use 'monk tenant list' to see available tenants for current server"
    exit 1
fi

tenant_server=$(echo "$tenant_info" | jq -r '.server')
if [ "$tenant_server" != "$current_server" ]; then
    print_error "Tenant '$name' belongs to server '$tenant_server', but current server is '$current_server'"
    print_info "Use 'monk server use $tenant_server' to switch servers first"
    exit 1
fi

# Update current tenant in env config
temp_file=$(mktemp)
jq --arg tenant "$name" \
   '.current_tenant = $tenant' \
   "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"

display_name=$(echo "$tenant_info" | jq -r '.display_name')
print_success "Switched to tenant: $name ($display_name)"

# Show authentication status for this tenant on current server
session_key="${current_server}:${name}"
if jq -e ".sessions.\"$session_key\"" "$AUTH_CONFIG" >/dev/null 2>&1; then
    user=$(jq -r ".sessions.\"$session_key\".user" "$AUTH_CONFIG" 2>/dev/null)
    print_info "Authenticated as: $user on server '$current_server'"
else
    print_warning "Not authenticated for this tenant on server '$current_server'"
    print_info "Use 'monk auth login $name <username>' to authenticate"
fi