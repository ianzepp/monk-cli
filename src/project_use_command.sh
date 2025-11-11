#!/bin/bash

# project_use_command.sh - Switch to project context

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"

if [[ -z "$name" ]]; then
    print_error "Project name is required"
    exit 1
fi

# Check if project exists
encoded_name=$(url_encode "$name")
response=$(make_root_request "GET" "tenant/$encoded_name")

if ! echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_error "Project '$name' not found: $error_msg"
    exit 1
fi

tenant=$(echo "$response" | jq -r '.tenant')
status=$(echo "$tenant" | jq -r '.status // "active"')

# Check if tenant is active
if [[ "$status" != "active" ]]; then
    print_error "Project '$name' is not active (status: $status)"
    print_info "Use 'monk project show $name' for details"
    exit 1
fi

# Get current server
init_cli_configs
current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
if [[ -z "$current_server" || "$current_server" == "null" ]]; then
    print_error "No server selected. Use 'monk server use <name>' first."
    exit 1
fi

# Check if tenant is registered locally
tenant_info=$(jq -r ".tenants.\"$name\"" "$TENANT_CONFIG" 2>/dev/null)
if [[ "$tenant_info" == "null" ]]; then
    print_info "Project '$name' exists but is not in local registry."
    print_info "Adding to local registry..."
    
    # Add to tenant registry
    description=$(echo "$tenant" | jq -r '.description // ""')
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    temp_file=$(mktemp)
    jq --arg name "$name" \
       --arg display_name "$name" \
       --arg description "$description" \
       --arg server "$current_server" \
       --arg timestamp "$timestamp" \
       '.tenants[$name] = {
           "display_name": $display_name,
           "description": $description,
           "server": $server,
           "added_at": $timestamp
       }' "$TENANT_CONFIG" > "$temp_file" && mv "$temp_file" "$TENANT_CONFIG"
fi

# Switch to tenant context
print_info "Switching to project '$name'..."
temp_file=$(mktemp)
jq --arg tenant "$name" \
   '.current_tenant = $tenant' \
   "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"

# Verify the switch worked
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
if [[ "$current_tenant" == "$name" ]]; then
    print_success "Switched to project '$name'"
    
    # Show project info
    database=$(echo "$tenant" | jq -r '.database // "unknown"')
    host=$(echo "$tenant" | jq -r '.host // "localhost"')
    
    echo
    echo "Project: $name"
    echo "Database: $database"
    echo "Server: $current_server ($host)"
    echo
    echo "Next steps:"
    echo "  monk status              # Show current context"
    echo "  monk auth login <user>   # Authenticate to the project"
    echo "  monk data select         # List available schemas"
    echo "  monk fs ls /data/        # Browse project data"
else
    print_error "Failed to switch to project '$name'"
    exit 1
fi