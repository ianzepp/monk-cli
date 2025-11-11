#!/bin/bash

# project_init_command.sh - Initialize new project with automatic tenant creation

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"
description="${args[--description]}"
tags="${args[--tags]}"
create_user="${args[--create-user]}"
auto_login="${args[--auto-login]}"
host="${args[--host]:-localhost}"

# Validate project name
if [[ -z "$name" ]]; then
    print_error "Project name is required"
    exit 1
fi

# Sanitize tags if provided
if [[ -n "$tags" ]]; then
    # Convert comma-separated to array and clean spaces
    IFS=',' read -ra TAG_ARRAY <<< "$tags"
    tags_json=$(printf '%s\n' "${TAG_ARRAY[@]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R . | jq -s .)
else
    tags_json="[]"
fi

print_info "Initializing project '$name'..."

# Step 1: Create tenant using root API
print_info "Creating tenant for project..."
payload=$(jq -n \
    --arg name "$name" \
    --arg host "$host" \
    '{name: $name, host: $host}')

response=$(make_root_request "POST" "tenant" "$payload")

if ! echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_error "Failed to create project tenant: $error_msg"
    exit 1
fi

tenant_info=$(echo "$response" | jq -r '.tenant')
tenant_name=$(echo "$tenant_info" | jq -r '.name')
database=$(echo "$tenant_info" | jq -r '.database')

print_success "Project '$tenant_name' created successfully"
print_info "Database: $database"

# Step 2: Add tenant to local registry
print_info "Adding tenant to local registry..."
init_cli_configs

current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
if [[ -z "$current_server" || "$current_server" == "null" ]]; then
    print_error "No server selected. Use 'monk server use <name>' first."
    exit 1
fi

# Add to tenant registry
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
temp_file=$(mktemp)
jq --arg name "$tenant_name" \
   --arg display_name "$tenant_name" \
   --arg description "${description:-}" \
   --arg server "$current_server" \
   --arg timestamp "$timestamp" \
   '.tenants[$name] = {
       "display_name": $display_name,
       "description": $description,
       "server": $server,
       "added_at": $timestamp
   }' "$TENANT_CONFIG" > "$temp_file" && mv "$temp_file" "$TENANT_CONFIG"

# Step 3: Switch to new tenant context
print_info "Switching to project context..."
temp_file=$(mktemp)
jq --arg tenant "$tenant_name" \
   '.current_tenant = $tenant' \
   "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"

# Step 4: Create initial user if requested
if [[ -n "$create_user" ]]; then
    print_info "Creating initial user '$create_user'..."
    
    # Create user payload
    user_payload=$(jq -n \
        --arg username "$create_user" \
        --arg email "${create_user}@example.com" \
        --arg role "admin" \
        '{username: $username, email: $email, role: $role, password: "admin123"}')
    
    # Create user via API
    user_response=$(make_authenticated_request "POST" "data/users" "$user_payload")
    
    if echo "$user_response" | jq -e '.success or .id' >/dev/null 2>&1; then
        print_success "User '$create_user' created successfully"
        print_info "Default password: admin123 (change after first login)"
        
        # Auto-login if requested
        if [[ "$auto_login" == "1" ]]; then
            print_info "Logging in as '$create_user'..."
            login_payload=$(jq -n --arg username "$create_user" --arg password "admin123" '{username: $username, password: $password}')
            
            auth_response=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "$login_payload" \
                "$(get_base_url)/api/auth/login")
            
            if echo "$auth_response" | jq -e '.token' >/dev/null 2>&1; then
                token=$(echo "$auth_response" | jq -r '.token')
                store_auth_token "$server_name" "$tenant_name" "$create_user" "$token"
                print_success "Logged in as '$create_user'"
            else
                print_error "Auto-login failed. Manual login required."
            fi
        fi
    else
        error_msg=$(echo "$user_response" | jq -r '.error // "Unknown error"')
        print_error "Failed to create user: $error_msg"
        print_info "You can create users manually after setup"
    fi
fi

# Step 5: Store project metadata
project_metadata=$(jq -n \
    --arg name "$name" \
    --arg description "${description:-""}" \
    --argjson tags "$tags_json" \
    --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    --arg database "$database" \
    '{name: $name, description: $description, tags: $tags, created_at: $created_at, database: $database}')

# Store in project registry
project_file="${CLI_CONFIG_DIR}/projects.json"
if [[ ! -f "$project_file" ]]; then
    echo '{"projects": []}' > "$project_file"
fi

# Add project to registry
temp_file=$(mktemp)
jq --argjson new_project "$project_metadata" '.projects += [$new_project]' "$project_file" > "$temp_file"
mv "$temp_file" "$project_file"

# Success message
print_success "Project '$name' is ready!"
echo
print_info "Next steps:"
echo "  monk status                    # Show current context"
echo "  monk data select users         # Start working with data"
echo "  monk describe create schema    # Create your first schema"

if [[ -n "$create_user" ]]; then
    echo "  monk auth login $create_user  # Login as your user"
fi

echo
print_info "Project management:"
echo "  monk project list              # List all projects"
echo "  monk project use <name>        # Switch projects"
echo "  monk project show $name       # Project details"