# Check dependencies
check_dependencies
init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for tenant registration"
    exit 1
fi

# Extract args and flags
tenant="${args[tenant]}"
username="${args[username]:-}"
template="${args[--template]:-}"
database="${args[--database]:-}"
description="${args[--description]:-}"
server_flag="${args[--server]:-}"
alias_flag="${args[--alias]:-}"

# Determine server URL
if [ -n "$server_flag" ]; then
    server_url=$(get_base_url_for_server "$server_flag")
else
    # Try to get from current session
    current_session=$(get_current_session)
    if [ -n "$current_session" ]; then
        server_url=$(get_session_info "$current_session" "server")
    fi
fi

if [ -z "$server_url" ]; then
    print_error "No server specified and no current session"
    print_info "Usage: monk auth register <tenant> --server <url>"
    exit 1
fi

# Determine session alias
session_alias="${alias_flag:-$tenant}"

# Build registration request JSON
register_data="{\"tenant\": \"$tenant\""

# Add optional username (if provided)
if [ -n "$username" ]; then
    register_data+=", \"username\": \"$username\""
    print_info "Registering new tenant: $tenant, username: $username"
else
    print_info "Registering new tenant: $tenant (username will default to 'root' in personal mode)"
fi

# Add optional template
if [ -n "$template" ]; then
    register_data+=", \"template\": \"$template\""
    print_info "Using template: $template"
fi

# Add optional database (personal mode only)
if [ -n "$database" ]; then
    register_data+=", \"database\": \"$database\""
    print_info "Custom database name: $database"
fi

# Add optional description
if [ -n "$description" ]; then
    register_data+=", \"description\": \"$description\""
fi

register_data+="}"

print_info "Server: $server_url"
print_info "Sending registration request to: ${server_url}/auth/register"

# Make direct curl request (bypass get_base_url which requires current session)
response=$(curl -s -X POST "${server_url}/auth/register" \
    -H "Content-Type: application/json" \
    -d "$register_data" 2>&1)

# Extract token and registration details from response
token=$(echo "$response" | jq -r '.data.token // empty' 2>/dev/null)
db_name=$(echo "$response" | jq -r '.data.database // empty' 2>/dev/null)
created_tenant=$(echo "$response" | jq -r '.data.tenant // empty' 2>/dev/null)
created_username=$(echo "$response" | jq -r '.data.username // empty' 2>/dev/null)
expires_in=$(echo "$response" | jq -r '.data.expires_in // empty' 2>/dev/null)

if [ -n "$token" ] && [ "$token" != "null" ]; then
    # Use created_tenant if different from requested (API may normalize)
    [ -n "$created_tenant" ] && tenant="$created_tenant"
    [ -n "$created_username" ] && username="$created_username"
    [ -z "$username" ] && username="root"

    # Store session
    store_session "$session_alias" "$server_url" "$tenant" "$username" "$token"

    print_success "Registration successful"
    print_info_always "Session: $session_alias"
    print_info_always "Server: $server_url"
    print_info_always "Tenant: $tenant"
    print_info_always "Database: $db_name"
    print_info_always "Username: $username"
    [ -n "$expires_in" ] && print_info_always "Token expires in: ${expires_in} seconds"
else
    error_msg=$(echo "$response" | jq -r '.error // .message // "Unknown error"' 2>/dev/null)
    print_error "Registration failed: $error_msg"
    exit 1
fi