# Check dependencies
check_dependencies
init_cli_configs

# Extract args and flags
tenant="${args[tenant]:-}"
username="${args[username]:-root}"
server_flag="${args[--server]:-}"
alias_flag="${args[--alias]:-}"

# If no tenant specified, re-login to current session
if [ -z "$tenant" ]; then
    current_session=$(get_current_session)
    if [ -z "$current_session" ]; then
        print_error "No tenant specified and no current session"
        print_info "Usage: monk auth login <tenant> --server <url>"
        exit 1
    fi

    # Get session details for re-login
    tenant=$(get_session_info "$current_session" "tenant")
    username=$(get_session_info "$current_session" "user")
    server_url=$(get_session_info "$current_session" "server")
    alias_flag="$current_session"

    print_info "Re-authenticating session: $current_session"
else
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
        print_info "Usage: monk auth login <tenant> --server <url>"
        exit 1
    fi
fi

# Determine session alias
session_alias="${alias_flag:-$tenant}"

print_info "Authenticating with tenant: $tenant, username: $username"
print_info "Server: $server_url"

# Prepare authentication request
auth_data="{\"tenant\": \"$tenant\", \"username\": \"$username\"}"

print_info "Sending authentication request to: ${server_url}/auth/login"

# Make direct curl request (bypass get_base_url which requires current session)
response=$(curl -s -X POST "${server_url}/auth/login" \
    -H "Content-Type: application/json" \
    -d "$auth_data" 2>&1)

# Extract token from response
token=""
if command -v jq >/dev/null 2>&1; then
    token=$(echo "$response" | jq -r '.data.token // empty' 2>/dev/null)
fi

if [ -n "$token" ] && [ "$token" != "null" ]; then
    # Store session with new function
    store_session "$session_alias" "$server_url" "$tenant" "$username" "$token"

    print_success "Authentication successful"
    print_info_always "Session: $session_alias"
    print_info_always "Server: $server_url"
    print_info_always "Tenant: $tenant"
    print_info_always "User: $username"
else
    error_msg=$(echo "$response" | jq -r '.error // .message // "Unknown error"' 2>/dev/null)
    print_error "Authentication failed: $error_msg"
    exit 1
fi