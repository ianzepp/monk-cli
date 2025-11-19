# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"
endpoint="${args[endpoint]}"
description="${args[--description]}"

init_cli_configs

# Parse endpoint
parsed=$(parse_endpoint "$endpoint")
protocol=$(echo "$parsed" | cut -d'|' -f1)
hostname=$(echo "$parsed" | cut -d'|' -f2)
port=$(echo "$parsed" | cut -d'|' -f3)

print_info "Adding server: $name"
print_info "Endpoint: $protocol://$hostname:$port"
if [ -n "$description" ]; then
    print_info "Description: $description"
fi

# Check if server already exists
if command -v jq >/dev/null 2>&1; then
    if jq -e ".servers.\"$name\"" "$SERVER_CONFIG" >/dev/null 2>&1; then
        print_error "Server '$name' already exists"
        print_info "Use 'monk server delete $name' first, or choose a different name"
        exit 1
    fi
fi

# Test connectivity
print_info "Testing connectivity to $protocol://$hostname:$port"
base_url="$protocol://$hostname:$port"

if ping_server_url "$base_url"; then
    print_success "Server is reachable"
    status="up"
else
    print_info "Server appears to be down (this is OK, adding anyway)"
    status="down"
fi

# Add server to config
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if command -v jq >/dev/null 2>&1; then
    # Use jq for JSON manipulation
    temp_file=$(mktemp)
    jq --arg name "$name" \
       --arg hostname "$hostname" \
       --arg port "$port" \
       --arg protocol "$protocol" \
       --arg description "$description" \
       --arg timestamp "$timestamp" \
       --arg status "$status" \
       '.servers[$name] = {
           "hostname": $hostname,
           "port": ($port | tonumber),
           "protocol": $protocol,
           "description": $description,
           "added_at": $timestamp,
           "last_ping": $timestamp,
           "status": $status
       }' "$SERVER_CONFIG" > "$temp_file" && mv "$temp_file" "$SERVER_CONFIG"
    
    print_success "Server '$name' added successfully"
    
    # If this is the first server, make it current in env config
    server_count=$(jq '.servers | length' "$SERVER_CONFIG")
    if [ "$server_count" -eq 1 ]; then
        temp_file=$(mktemp)
        jq --arg name "$name" '.current_server = $name' "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"
        print_info "Set as current server (first server added)"
    fi
else
    print_error "jq is required for server management"
    print_info "Please install jq: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi