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
    exit 1
fi

display_name=$(echo "$tenant_info" | jq -r '.display_name')

# Check if this is the current tenant
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
if [ "$name" = "$current_tenant" ]; then
    print_warning "Cannot delete current tenant '$name'"
    print_info "Use 'monk config tenant use <other_tenant>' to switch first"
    exit 1
fi

# Check for active sessions
auth_count=$(jq --arg tenant "$name" '[.sessions | to_entries[] | select(.key | endswith(":" + $tenant))] | length' "$AUTH_CONFIG" 2>/dev/null || echo "0")
if [ "$auth_count" -gt 0 ]; then
    print_warning "Tenant '$name' has $auth_count active sessions"
    print_info "Sessions will be removed along with tenant"
fi

# Confirmation
print_warning "Are you sure you want to delete tenant '$name' ($display_name)? (y/N)"
read -r confirmation
if ! echo "$confirmation" | grep -E "^[Yy]$" >/dev/null 2>&1; then
    print_info "Operation cancelled"
    exit 0
fi

# Remove tenant from config
temp_file=$(mktemp)
jq --arg name "$name" \
   'del(.tenants[$name])' \
   "$TENANT_CONFIG" > "$temp_file" && mv "$temp_file" "$TENANT_CONFIG"

# Remove any sessions for this tenant
temp_file=$(mktemp)
jq --arg tenant "$name" \
   'del(.sessions[] | select(.tenant == $tenant))' \
   "$AUTH_CONFIG" > "$temp_file" && mv "$temp_file" "$AUTH_CONFIG"

print_success "Deleted tenant '$name' ($display_name)"
if [ "$auth_count" -gt 0 ]; then
    print_info "Removed $auth_count authentication sessions"
fi