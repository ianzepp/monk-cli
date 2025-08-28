# Check dependencies
check_dependencies

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for tenant management"
    exit 1
fi

# Get arguments from bashly
name="${args[name]}"

# Check if tenant exists
tenant_info=$(jq -r ".tenants.\"$name\"" "$TENANT_CONFIG" 2>/dev/null)
if [ "$tenant_info" = "null" ]; then
    print_error "Tenant '$name' not found"
    print_info "Use 'monk tenant list' to see available tenants"
    exit 1
fi

# Update current tenant in env config
temp_file=$(mktemp)
jq --arg tenant "$name" \
   '.current_tenant = $tenant' \
   "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"

display_name=$(echo "$tenant_info" | jq -r '.display_name')
print_success "Switched to tenant: $name ($display_name)"

# Show authentication status for this tenant if available
current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
if [ -n "$current_server" ] && [ "$current_server" != "null" ]; then
    session_key="${current_server}:${name}"
    if jq -e ".sessions.\"$session_key\"" "$AUTH_CONFIG" >/dev/null 2>&1; then
        user=$(jq -r ".sessions.\"$session_key\".user" "$AUTH_CONFIG" 2>/dev/null)
        print_info "Authenticated as: $user"
    else
        print_warning "Not authenticated for this tenant"
        print_info "Use 'monk auth login $name <username>' to authenticate"
    fi
fi