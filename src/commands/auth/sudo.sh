# Check dependencies
check_dependencies

# Initialize CLI configs
init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for sudo token operations"
    exit 1
fi

# Get optional reason from flags
reason="${args[--reason]}"

# Prepare sudo request
sudo_data="{}"
if [ -n "$reason" ]; then
    sudo_data="{\"reason\": \"$reason\"}"
    print_info "Requesting sudo token with reason: $reason"
else
    print_info "Requesting sudo token"
fi

# Make sudo request
if response=$(make_request_json "POST" "/api/auth/sudo" "$sudo_data"); then
    # Extract sudo token and metadata from response
    sudo_token=""
    expires_in=""
    elevated_from=""
    warning=""
    
    if [ "$JSON_PARSER" = "jq" ]; then
        sudo_token=$(echo "$response" | jq -r '.data.root_token' 2>/dev/null)
        expires_in=$(echo "$response" | jq -r '.data.expires_in' 2>/dev/null)
        elevated_from=$(echo "$response" | jq -r '.data.elevated_from' 2>/dev/null)
        warning=$(echo "$response" | jq -r '.data.warning' 2>/dev/null)
    elif [ "$JSON_PARSER" = "jshon" ]; then
        sudo_token=$(echo "$response" | jshon -e data -e root_token -u 2>/dev/null)
        expires_in=$(echo "$response" | jshon -e data -e expires_in -u 2>/dev/null)
        elevated_from=$(echo "$response" | jshon -e data -e elevated_from -u 2>/dev/null)
        warning=$(echo "$response" | jshon -e data -e warning -u 2>/dev/null)
    else
        # Fallback: extract fields manually
        sudo_token=$(echo "$response" | grep -o '"root_token":"[^"]*"' | cut -d'"' -f4)
        expires_in=$(echo "$response" | grep -o '"expires_in":[^,}]*' | cut -d':' -f2)
        elevated_from=$(echo "$response" | grep -o '"elevated_from":"[^"]*"' | cut -d'"' -f4)
        warning=$(echo "$response" | grep -o '"warning":"[^"]*"' | cut -d'"' -f4)
    fi
    
    if [ -n "$sudo_token" ] && [ "$sudo_token" != "null" ]; then
        # Store sudo token
        store_sudo_token "$sudo_token" "$reason"
        
        print_success "Sudo token acquired successfully"
        print_info_always "Elevated from: $elevated_from"
        print_info_always "Expires in: ${expires_in} seconds (15 minutes)"
        
        if [ -n "$warning" ] && [ "$warning" != "null" ]; then
            echo
            print_warning "$warning"
        fi
        
        echo
        print_info_always "Use 'monk sudo users' commands to perform user management operations"
    else
        print_error "Failed to extract sudo token from response"
        print_info "Response: $response"
        exit 1
    fi
else
    print_error "Failed to acquire sudo token"
    print_info "You must have root access level to use sudo commands"
    exit 1
fi
