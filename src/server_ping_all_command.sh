# Check dependencies
check_dependencies

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for server management"
    exit 1
fi

server_names=$(jq -r '.servers | keys[]' "$SERVER_CONFIG" 2>/dev/null)

if [ -z "$server_names" ]; then
    if [ "${args[--json]}" = "true" ]; then
        echo '{"servers": [], "summary": {"total": 0, "up": 0, "down": 0}}'
    else
        echo
        print_info "Pinging All Servers"
        echo
        print_info "No servers configured"
        print_info "Use 'monk servers add <name> <hostname:port>' to add servers"
    fi
    exit 0
fi

if [ "${args[--json]}" != "true" ]; then
    echo
    print_info "Pinging All Servers"
    echo
fi

# Prepare arrays for JSON output
ping_results="[]"
up_count=0
total_count=0

echo "$server_names" | while read -r name; do
    if [ -n "$name" ]; then
        total_count=$((total_count + 1))
        
        server_info=$(jq -r ".servers.\"$name\"" "$SERVER_CONFIG")
        hostname=$(echo "$server_info" | jq -r '.hostname')
        port=$(echo "$server_info" | jq -r '.port')
        protocol=$(echo "$server_info" | jq -r '.protocol')
        base_url="$protocol://$hostname:$port"
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        
        if [ "${args[--json]}" != "true" ]; then
            print_info "Pinging server: $name ($base_url)"
        fi
        
        ping_start=$(date +%s%3N)
        if ping_server_url "$base_url" 5; then
            ping_end=$(date +%s%3N)
            response_time=$((ping_end - ping_start))
            up_count=$((up_count + 1))
            
            # Update status
            temp_file=$(mktemp)
            jq --arg name "$name" \
               --arg timestamp "$timestamp" \
               '.servers[$name].last_ping = $timestamp | .servers[$name].status = "up"' \
               "$SERVER_CONFIG" > "$temp_file" && mv "$temp_file" "$SERVER_CONFIG"
            
            if [ "${args[--json]}" = "true" ]; then
                server_result=$(jq -n \
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
                    }')
                echo "$server_result"
            else
                print_success "Server is up and responding"
            fi
        else
            # Update status
            temp_file=$(mktemp)
            jq --arg name "$name" \
               --arg timestamp "$timestamp" \
               '.servers[$name].last_ping = $timestamp | .servers[$name].status = "down"' \
               "$SERVER_CONFIG" > "$temp_file" && mv "$temp_file" "$SERVER_CONFIG"
            
            if [ "${args[--json]}" = "true" ]; then
                server_result=$(jq -n \
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
                    }')
                echo "$server_result"
            else
                print_error "Server is down or not responding"
            fi
        fi
    fi
done | if [ "${args[--json]}" = "true" ]; then
    # Collect all results and format as JSON
    jq -s '
    {
        servers: .,
        summary: {
            total: length,
            up: [.[] | select(.success == true)] | length,
            down: [.[] | select(.success == false)] | length,
            success_rate: (if length > 0 then ([.[] | select(.success == true)] | length) / length else 0 end)
        }
    }'
else
    # Count results for human-readable summary
    up_servers=0
    total_servers=0
    while IFS= read -r line; do
        total_servers=$((total_servers + 1))
        if echo "$line" | grep -q '"success": true'; then
            up_servers=$((up_servers + 1))
        fi
    done
    
    echo
    if [ "$up_servers" -eq "$total_servers" ] && [ "$total_servers" -gt 0 ]; then
        print_success "All servers are up ($up_servers/$total_servers)"
    elif [ "$up_servers" -eq 0 ] && [ "$total_servers" -gt 0 ]; then
        print_error "All servers are down (0/$total_servers)"
    elif [ "$total_servers" -gt 0 ]; then
        print_info "$up_servers/$total_servers servers are up"
    fi
fi