# Check dependencies
check_dependencies

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for tenant management"
    exit 1
fi

# Get arguments from bashly
name="${args[name]}"
display_name="${args[display_name]}"
description="${args[--description]}"

# Get current server
current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
if [ -z "$current_server" ] || [ "$current_server" = "null" ]; then
    print_error "No current server selected"
    print_info "Use 'monk config server use <name>' to select a server first"
    exit 1
fi

# Validate tenant name
if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
    print_error "Invalid tenant name: '$name'"
    print_info "Tenant names must start with alphanumeric character and contain only letters, numbers, hyphens, and underscores"
    exit 1
fi

# Check if tenant already exists for this server
existing_tenant=$(jq -r ".tenants.\"$name\"" "$TENANT_CONFIG" 2>/dev/null)
if [ "$existing_tenant" != "null" ]; then
    existing_server=$(echo "$existing_tenant" | jq -r '.server')
    if [ "$existing_server" = "$current_server" ]; then
        print_error "Tenant '$name' already exists for server '$current_server'"
        exit 1
    elif [ "$existing_server" != "null" ]; then
        print_error "Tenant '$name' already exists for server '$existing_server'"
        print_info "Use a different tenant name or remove the existing tenant first"
        exit 1
    fi
fi

# Create timestamp
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Add tenant to config with server association
temp_file=$(mktemp)
jq --arg name "$name" \
   --arg display_name "$display_name" \
   --arg description "${description:-}" \
   --arg server "$current_server" \
   --arg timestamp "$timestamp" \
   '.tenants[$name] = {
       "display_name": $display_name,
       "description": $description,
       "server": $server,
       "added_at": $timestamp
   }' "$TENANT_CONFIG" > "$temp_file" && mv "$temp_file" "$TENANT_CONFIG"

print_success "Added tenant '$name' ($display_name) for server '$current_server'"
if [ -n "$description" ]; then
    print_info "Description: $description"
fi