# Check dependencies
check_dependencies

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for server management"
    exit 1
fi

current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)

if [ -z "$current_server" ] || [ "$current_server" = "null" ]; then
    if [ "${args[--json]}" = "true" ]; then
        echo '{"current_server": null, "error": "No current server selected"}'
    else
        print_info "No current server selected"
        print_info "Use 'monk servers use <name>' to select a server"
    fi
    exit 0
fi

server_info=$(jq -r ".servers.\"$current_server\"" "$SERVER_CONFIG" 2>/dev/null)
if [ "$server_info" = "null" ]; then
    if [ "${args[--json]}" = "true" ]; then
        echo "{\"current_server\": \"$current_server\", \"error\": \"Server not found in registry\"}"
    else
        print_error "Current server '$current_server' not found in registry"
        print_info "The server may have been deleted. Use 'monk servers list' to see available servers"
    fi
    exit 1
fi

hostname=$(echo "$server_info" | jq -r '.hostname')
port=$(echo "$server_info" | jq -r '.port')
protocol=$(echo "$server_info" | jq -r '.protocol')
status=$(echo "$server_info" | jq -r '.status // "unknown"')
description=$(echo "$server_info" | jq -r '.description // ""')
base_url="$protocol://$hostname:$port"

# Check authentication count
auth_count=$(jq --arg server "$current_server" '[.sessions | to_entries[] | select(.key | startswith($server + ":"))] | length' "$AUTH_CONFIG" 2>/dev/null || echo "0")

if [ "${args[--json]}" = "true" ]; then
    # JSON output mode
    jq -n \
        --arg name "$current_server" \
        --arg hostname "$hostname" \
        --arg port "$port" \
        --arg protocol "$protocol" \
        --arg endpoint "$base_url" \
        --arg status "$status" \
        --arg description "$description" \
        --argjson auth_count "$auth_count" \
        '{
            name: $name,
            hostname: $hostname,
            port: ($port | tonumber),
            protocol: $protocol,
            endpoint: $endpoint,
            base_url: $endpoint,
            status: $status,
            description: $description,
            auth_sessions: $auth_count
        }'
else
    # Human-readable output mode (original)
    echo
    print_info "Current Server"
    echo

    echo "Name: $current_server"
    echo "Endpoint: $base_url"
    echo "Status: $status"
    if [ -n "$description" ]; then
        echo "Description: $description"
    fi
    echo "Base URL: $base_url"
fi