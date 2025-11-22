# Check dependencies
check_dependencies

# Extract tenant and username from bashly args
tenant="${args[tenant]}"
username="${args[username]:-root}"

print_info "Authenticating with tenant: $tenant, username: $username"

# Prepare authentication request
auth_data="{\"tenant\": \"$tenant\", \"username\": \"$username\"}"
base_url=$(get_base_url)

print_info "Sending authentication request to: ${base_url}/auth/login"

# Make authentication request
if response=$(make_request_json "POST" "/auth/login" "$auth_data"); then
    # Extract token from response
    token=""
    if [ "$JSON_PARSER" = "jq" ]; then
        token=$(echo "$response" | jq -r '.data.token' 2>/dev/null)
    elif [ "$JSON_PARSER" = "jshon" ]; then
        token=$(echo "$response" | jshon -e data -e token -u 2>/dev/null)
    else
        # Fallback: extract token manually
        token=$(echo "$response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    fi
    
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        # Store token with tenant and username
        store_token "$token" "$tenant" "$username"
        
        print_success "Authentication successful"
        print_info "JWT token stored for server+tenant context"
    else
        print_error "Failed to extract JWT token from response"
        print_info "Response: $response"
        exit 1
    fi
else
    print_error "Authentication failed"
    exit 1
fi