# Check dependencies
check_dependencies

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for server management"
    exit 1
fi

# Get arguments from bashly
json_flag="${args[--json]}"

current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
server_names=$(jq -r '.servers | keys[]' "$SERVER_CONFIG" 2>/dev/null)

if [ -z "$server_names" ]; then
    if [ "$json_flag" = "1" ]; then
        echo '{"servers": [], "current_server": null}'
    else
        echo
        print_info "Registered Servers"
        echo
        print_info "No servers configured"
        print_info "Use 'monk servers add <name> <hostname:port>' to add servers"
    fi
    exit 0
fi

if [ "$json_flag" = "1" ]; then
    # JSON output mode
    servers_array="[]"
    
    echo "$server_names" | while read -r name; do
        if [ -n "$name" ]; then
            server_info=$(jq -r ".servers.\"$name\"" "$SERVER_CONFIG")
            
            hostname=$(echo "$server_info" | jq -r '.hostname')
            port=$(echo "$server_info" | jq -r '.port')
            protocol=$(echo "$server_info" | jq -r '.protocol')
            status=$(echo "$server_info" | jq -r '.status // "unknown"')
            last_ping=$(echo "$server_info" | jq -r '.last_ping // "never"')
            added_at=$(echo "$server_info" | jq -r '.added_at // "unknown"')
            description=$(echo "$server_info" | jq -r '.description // ""')
            
            endpoint="$protocol://$hostname:$port"
            
            # Check authentication count
            auth_count=$(jq --arg server "$name" '[.sessions | to_entries[] | select(.key | startswith($server + ":"))] | length' "$AUTH_CONFIG" 2>/dev/null || echo "0")
            is_current=$([ "$name" = "$current_server" ] && echo "true" || echo "false")
            
            server_json=$(jq -n \
                --arg name "$name" \
                --arg hostname "$hostname" \
                --arg port "$port" \
                --arg protocol "$protocol" \
                --arg endpoint "$endpoint" \
                --arg status "$status" \
                --arg last_ping "$last_ping" \
                --arg added_at "$added_at" \
                --arg description "$description" \
                --argjson auth_count "$auth_count" \
                --argjson is_current "$is_current" \
                '{
                    name: $name,
                    hostname: $hostname,
                    port: ($port | tonumber),
                    protocol: $protocol,
                    endpoint: $endpoint,
                    status: $status,
                    last_ping: $last_ping,
                    added_at: $added_at,
                    description: $description,
                    auth_sessions: $auth_count,
                    is_current: $is_current
                }')
            
            echo "$server_json"
        fi
    done | jq -s --arg current_server "$current_server" \
        '{servers: ., current_server: ($current_server | if . == "" then null else . end)}'
    
else
    # Human-readable output mode (original)
    echo
    print_info "Registered Servers"
    echo

    printf "%-15s %-30s %-8s %-8s %-12s %-20s %s\n" "Name" "Endpoint" "Status" "Auth" "Last Ping" "Added" "Description"
    echo "--------------------------------------------------------------------------------------------------------"

    echo "$server_names" | while read -r name; do
        if [ -n "$name" ]; then
            server_info=$(jq -r ".servers.\"$name\"" "$SERVER_CONFIG")
            
            hostname=$(echo "$server_info" | jq -r '.hostname')
            port=$(echo "$server_info" | jq -r '.port')
            protocol=$(echo "$server_info" | jq -r '.protocol')
            status=$(echo "$server_info" | jq -r '.status // "unknown"')
            last_ping=$(echo "$server_info" | jq -r '.last_ping // "never"')
            added_at=$(echo "$server_info" | jq -r '.added_at // "unknown"')
            description=$(echo "$server_info" | jq -r '.description // ""')
            
            endpoint="$protocol://$hostname:$port"
            
            # Format timestamps
            if [ "$last_ping" != "never" ] && [ "$last_ping" != "unknown" ]; then
                last_ping=$(echo "$last_ping" | cut -d'T' -f1)
            fi
            if [ "$added_at" != "unknown" ]; then
                added_at=$(echo "$added_at" | cut -d'T' -f1)
            fi
            
            # Check if authenticated (look for any sessions for this server)
            auth_status="no"
            auth_count=$(jq --arg server "$name" '[.sessions | to_entries[] | select(.key | startswith($server + ":"))] | length' "$AUTH_CONFIG" 2>/dev/null || echo "0")
            if [ "$auth_count" -gt 0 ]; then
                auth_status="yes ($auth_count)"
            fi
            
            # Mark current server
            marker=""
            if [ "$name" = "$current_server" ]; then
                marker="*"
            fi
            
            printf "%-15s %-30s %-8s %-8s %-12s %-20s %s %s\n" \
                "$name" "$endpoint" "$status" "$auth_status" "$last_ping" "$added_at" "$description" "$marker"
        fi
    done

    echo
    if [ -n "$current_server" ]; then
        print_info "Current server: $current_server (marked with *)"
    else
        print_info "No current server selected"
        print_info "Use 'monk servers use <name>' to select a server"
    fi
fi