# Check dependencies
check_dependencies

# Initialize CLI configs
init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for tenant registration"
    exit 1
fi

# Extract tenant and username from bashly args
tenant="${args[tenant]}"
username="${args[username]}"

print_info "Registering new tenant: $tenant, username: $username"

# Prepare registration request
register_data="{\"tenant\": \"$tenant\", \"username\": \"$username\"}"
base_url=$(get_base_url)

print_info "Sending registration request to: ${base_url}/auth/register"

# Make registration request
if response=$(make_request_json "POST" "/auth/register" "$register_data"); then
    # Extract token and registration details from response
    token=""
    database=""
    created_tenant=""
    created_username=""
    expires_in=""
    
    if [ "$JSON_PARSER" = "jq" ]; then
        token=$(echo "$response" | jq -r '.data.token' 2>/dev/null)
        database=$(echo "$response" | jq -r '.data.database' 2>/dev/null)
        created_tenant=$(echo "$response" | jq -r '.data.tenant' 2>/dev/null)
        created_username=$(echo "$response" | jq -r '.data.username' 2>/dev/null)
        expires_in=$(echo "$response" | jq -r '.data.expires_in' 2>/dev/null)
    elif [ "$JSON_PARSER" = "jshon" ]; then
        token=$(echo "$response" | jshon -e data -e token -u 2>/dev/null)
        database=$(echo "$response" | jshon -e data -e database -u 2>/dev/null)
        created_tenant=$(echo "$response" | jshon -e data -e tenant -u 2>/dev/null)
        created_username=$(echo "$response" | jshon -e data -e username -u 2>/dev/null)
        expires_in=$(echo "$response" | jshon -e data -e expires_in -u 2>/dev/null)
    else
        # Fallback: extract fields manually
        token=$(echo "$response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        database=$(echo "$response" | grep -o '"database":"[^"]*"' | cut -d'"' -f4)
        created_tenant=$(echo "$response" | grep -o '"tenant":"[^"]*"' | cut -d'"' -f4)
        created_username=$(echo "$response" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        expires_in=$(echo "$response" | grep -o '"expires_in":[^,]*' | cut -d':' -f2)
    fi
    
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        # Get current server for tenant registration
        current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
        if [ -z "$current_server" ] || [ "$current_server" = "null" ]; then
            print_error "No current server selected"
            print_info "Use 'monk server use <name>' to select a server first"
            exit 1
        fi
        
        # Add tenant to tenant registry (similar to tenant add command)
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        temp_file=$(mktemp)
        jq --arg name "$created_tenant" \
           --arg display_name "$created_tenant" \
           --arg description "Auto-created via auth register" \
           --arg server "$current_server" \
           --arg timestamp "$timestamp" \
           '.tenants[$name] = {
               "display_name": $display_name,
               "description": $description,
               "server": $server,
               "added_at": $timestamp
           }' "$TENANT_CONFIG" > "$temp_file" && mv "$temp_file" "$TENANT_CONFIG"
        
        # Store token with tenant and username
        store_token "$token" "$created_tenant" "$created_username"
        
        print_success "Registration successful"
        print_info_always "Tenant: $created_tenant"
        print_info_always "Database: $database"
        print_info_always "Username: $created_username"
        print_info_always "Token expires in: ${expires_in} seconds"
        print_info_always "JWT token stored for server+tenant context"
        print_info_always "Tenant added to local registry for server: $current_server"
    else
        print_error "Failed to extract registration data from response"
        print_info "Response: $response"
        exit 1
    fi
else
    print_error "Registration failed"
    exit 1
fi