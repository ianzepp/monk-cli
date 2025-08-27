# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for server management"
    exit 1
fi

# If no name provided, use current server
if [ -z "$name" ]; then
    name=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    
    if [ -z "$name" ] || [ "$name" = "null" ]; then
        print_error "No server specified and no current server selected"
        print_info "Use 'monk server ping <name>' or 'monk server use <name>' first"
        exit 1
    fi
    
    print_info "Using current server: $name"
fi

# Get server info
server_info=$(jq -r ".servers.\"$name\"" "$SERVER_CONFIG" 2>/dev/null)
if [ "$server_info" = "null" ]; then
    print_error "Server '$name' not found"
    print_info "Use 'monk server list' to see available servers"
    exit 1
fi

hostname=$(echo "$server_info" | jq -r '.hostname')
port=$(echo "$server_info" | jq -r '.port')
protocol=$(echo "$server_info" | jq -r '.protocol')
base_url="$protocol://$hostname:$port"

print_info "Pinging server: $name ($base_url)"

# Test connectivity to root endpoint
if curl -s --max-time 10 --fail "$base_url/" >/dev/null 2>&1; then
    print_success "Server is up and responding"
    
    # Update status in config
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    temp_file=$(mktemp)
    jq --arg name "$name" \
       --arg timestamp "$timestamp" \
       '.servers[$name].last_ping = $timestamp | .servers[$name].status = "up"' \
       "$SERVER_CONFIG" > "$temp_file" && mv "$temp_file" "$SERVER_CONFIG"
else
    print_error "Server is down or not responding"
    
    # Update status in config
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    temp_file=$(mktemp)
    jq --arg name "$name" \
       --arg timestamp "$timestamp" \
       '.servers[$name].last_ping = $timestamp | .servers[$name].status = "down"' \
       "$SERVER_CONFIG" > "$temp_file" && mv "$temp_file" "$SERVER_CONFIG"
    exit 1
fi