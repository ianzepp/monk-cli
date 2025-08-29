# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"
json_flag="${args[--json]}"

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for server management"
    exit 1
fi

# If no name provided, use current server
if [ -z "$name" ]; then
    name=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    
    if [ -z "$name" ] || [ "$name" = "null" ]; then
        if [ "$json_flag" = "1" ]; then
            echo '{"error": "No server specified and no current server selected"}'
        else
            print_error "No server specified and no current server selected"
            print_info "Use 'monk server ping <name>' or 'monk server use <name>' first"
        fi
        exit 1
    fi
    
    if [ "$json_flag" != "1" ]; then
        print_info "Using current server: $name"
    fi
fi

# Get server info
server_info=$(jq -r ".servers.\"$name\"" "$SERVER_CONFIG" 2>/dev/null)
if [ "$server_info" = "null" ]; then
    if [ "$json_flag" = "1" ]; then
        echo "{\"server_name\": \"$name\", \"error\": \"Server not found\"}"
    else
        print_error "Server '$name' not found"
        print_info "Use 'monk server list' to see available servers"
    fi
    exit 1
fi

hostname=$(echo "$server_info" | jq -r '.hostname')
port=$(echo "$server_info" | jq -r '.port')
protocol=$(echo "$server_info" | jq -r '.protocol')
base_url="$protocol://$hostname:$port"
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ "$json_flag" != "1" ]; then
    print_info "Pinging server: $name ($base_url)"
fi

# Test connectivity to root endpoint
# Use curl's built-in timing to avoid bash arithmetic overflow
if response_time_raw=$(curl -s --max-time 10 --fail -w '%{time_total}' -o /dev/null "$base_url/" 2>/dev/null); then
    # Convert seconds to milliseconds using awk (more portable than bc)
    response_time=$(echo "$response_time_raw" | awk '{printf "%.0f", $1 * 1000}')
    
    # Update status in config
    temp_file=$(mktemp)
    jq --arg name "$name" \
       --arg timestamp "$timestamp" \
       '.servers[$name].last_ping = $timestamp | .servers[$name].status = "up"' \
       "$SERVER_CONFIG" > "$temp_file" && mv "$temp_file" "$SERVER_CONFIG"
    
    if [ "$json_flag" = "1" ]; then
        jq -n \
            --arg server_name "$name" \
            --arg hostname "$hostname" \
            --arg port "$port" \
            --arg protocol "$protocol" \
            --arg endpoint "$base_url" \
            --arg status "up" \
            --arg timestamp "$timestamp" \
            --argjson response_time_ms "$response_time" \
            '{
                server_name: $server_name,
                hostname: $hostname,
                port: ($port | tonumber),
                protocol: $protocol,
                endpoint: $endpoint,
                status: $status,
                timestamp: $timestamp,
                response_time_ms: $response_time_ms,
                success: true
            }'
    else
        print_success "Server is up and responding"
    fi
else
    # Update status in config
    temp_file=$(mktemp)
    jq --arg name "$name" \
       --arg timestamp "$timestamp" \
       '.servers[$name].last_ping = $timestamp | .servers[$name].status = "down"' \
       "$SERVER_CONFIG" > "$temp_file" && mv "$temp_file" "$SERVER_CONFIG"
    
    if [ "$json_flag" = "1" ]; then
        jq -n \
            --arg server_name "$name" \
            --arg hostname "$hostname" \
            --arg port "$port" \
            --arg protocol "$protocol" \
            --arg endpoint "$base_url" \
            --arg status "down" \
            --arg timestamp "$timestamp" \
            '{
                server_name: $server_name,
                hostname: $hostname,
                port: ($port | tonumber),
                protocol: $protocol,
                endpoint: $endpoint,
                status: $status,
                timestamp: $timestamp,
                success: false,
                error: "Server is down or not responding"
            }'
    else
        print_error "Server is down or not responding"
    fi
    exit 1
fi