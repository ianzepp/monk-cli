#!/bin/bash

# server_current_command.sh - Show currently selected server with universal format support

# Check dependencies
check_dependencies

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for server management"
    exit 1
fi

# Determine output format from global flags
output_format=$(get_output_format "text")

current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)

if [ -z "$current_server" ] || [ "$current_server" = "null" ]; then
    # No current server - generate appropriate response
    error_result='{"current_server": null, "error": "No current server selected"}'
    
    if [[ "$output_format" == "text" ]]; then
        print_info "No current server selected"
        print_info "Use 'monk server use <name>' to select a server"
    else
        handle_output "$error_result" "$output_format" "json"
    fi
    exit 0
fi

server_info=$(jq -r ".servers.\"$current_server\"" "$SERVER_CONFIG" 2>/dev/null)
if [ "$server_info" = "null" ]; then
    # Server not found in registry
    error_result=$(jq -n --arg server "$current_server" '{"current_server": $server, "error": "Server not found in registry"}')
    
    if [[ "$output_format" == "text" ]]; then
        print_error "Current server '$current_server' not found in registry"
        print_info "The server may have been deleted. Use 'monk server list' to see available servers"
    else
        handle_output "$error_result" "$output_format" "json"
    fi
    exit 1
fi

# Extract server details
hostname=$(echo "$server_info" | jq -r '.hostname')
port=$(echo "$server_info" | jq -r '.port')
protocol=$(echo "$server_info" | jq -r '.protocol')
status=$(echo "$server_info" | jq -r '.status // "unknown"')
description=$(echo "$server_info" | jq -r '.description // ""')
base_url="$protocol://$hostname:$port"

# Check authentication count
auth_count=$(jq --arg server "$current_server" '[.sessions | to_entries[] | select(.key | startswith($server + ":"))] | length' "$AUTH_CONFIG" 2>/dev/null || echo "0")

# Build JSON response
server_json=$(jq -n \
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
    }')

# Handle text format with custom formatting for single server
if [[ "$output_format" == "text" ]]; then
    echo
    print_info "Current Server"
    echo
    echo "Name: $current_server"
    echo "Endpoint: $base_url"
    echo "Status: $status"
    if [ -n "$description" ]; then
        echo "Description: $description"
    fi
    echo "Auth Sessions: $auth_count"
    echo
else
    # Use universal handler for JSON output
    handle_output "$server_json" "$output_format" "json"
fi