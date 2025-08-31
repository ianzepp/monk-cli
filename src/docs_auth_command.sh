#!/bin/bash

# docs_auth_command.sh - Display auth API documentation

# Check dependencies
check_dependencies

# Determine output format from global flags
output_format=$(get_output_format "glow")

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for documentation commands"
    exit 1
fi

# Get current server
current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)

if [ -z "$current_server" ] || [ "$current_server" = "null" ]; then
    print_error "No current server selected"
    print_info "Use 'monk server use <name>' to select a server first"
    exit 1
fi

# Get server info
server_info=$(jq -r ".servers.\"$current_server\"" "$SERVER_CONFIG" 2>/dev/null)
if [ "$server_info" = "null" ]; then
    print_error "Current server '$current_server' not found in registry"
    print_info "Use 'monk server list' to see available servers"
    exit 1
fi

hostname=$(echo "$server_info" | jq -r '.hostname')
port=$(echo "$server_info" | jq -r '.port')
protocol=$(echo "$server_info" | jq -r '.protocol')
base_url="$protocol://$hostname:$port"

print_info "Fetching auth API documentation from: $current_server"

# Fetch documentation from API endpoint
if docs_content=$(curl -s --max-time 30 --fail "$base_url/docs/auth" 2>/dev/null); then
    # Display content based on output format
    if [[ "$output_format" == "text" ]]; then
        # Raw markdown output when --text flag is used
        echo "$docs_content"
    elif command -v glow >/dev/null 2>&1; then
        # Use glow for enhanced formatting when available
        echo "$docs_content" | glow --pager -
    else
        # Fallback to raw markdown if glow not installed
        echo "$docs_content"
    fi
else
    print_error "Failed to fetch documentation from server '$current_server'"
    print_info "Ensure server is running and documentation endpoint is available"
    exit 1
fi