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

# Validate tenant name
if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
    print_error "Invalid tenant name: '$name'"
    print_info "Tenant names must start with alphanumeric character and contain only letters, numbers, hyphens, and underscores"
    exit 1
fi

# Check if tenant already exists
existing_tenant=$(jq -r ".tenants.\"$name\"" "$TENANT_CONFIG" 2>/dev/null)
if [ "$existing_tenant" != "null" ]; then
    print_error "Tenant '$name' already exists"
    exit 1
fi

# Create timestamp
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Add tenant to config
temp_file=$(mktemp)
jq --arg name "$name" \
   --arg display_name "$display_name" \
   --arg description "${description:-}" \
   --arg timestamp "$timestamp" \
   '.tenants[$name] = {
       "display_name": $display_name,
       "description": $description,
       "added_at": $timestamp
   }' "$TENANT_CONFIG" > "$temp_file" && mv "$temp_file" "$TENANT_CONFIG"

print_success "Added tenant '$name' ($display_name)"
if [ -n "$description" ]; then
    print_info "Description: $description"
fi