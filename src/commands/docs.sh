#!/bin/bash

# docs_command.sh - Display API documentation from remote server
#
# This command fetches markdown documentation from the server's /docs endpoint
# and displays it with optional glow formatting for enhanced readability.
#
# Usage Examples:
#   monk docs                           # Display root documentation (/docs)
#   monk docs auth                      # Display authentication docs (/docs/auth)
#   monk docs api/data                  # Display Data API docs (/docs/api/data)
#   monk docs api/describe/schema/GET   # Display specific endpoint docs
#
# Output Format:
#   - Uses glow for enhanced markdown formatting when available
#   - Falls back to raw markdown if glow not installed
#   - Supports --text flag for raw markdown output
#
# Path-Based Routing:
#   - All paths map directly to /docs/<path> endpoint
#   - No discovery logic needed - API serves complete documentation tree
#   - Examples:
#     monk docs           → GET /docs
#     monk docs auth      → GET /docs/auth
#     monk docs api/data  → GET /docs/api/data

# Check dependencies
check_dependencies

# Get path argument from bashly (defaults to empty for root docs)
path="${args[path]:-}"

# Determine output format from global flags
output_format=$(get_output_format "glow")

init_cli_configs

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

# Construct documentation URL
docs_url="$base_url/docs"
if [ -n "$path" ]; then
    # Append path (ensure no double slashes)
    docs_url="$docs_url/$path"
    print_info "Fetching documentation from: /docs/$path"
else
    print_info "Fetching root documentation from: /docs"
fi

# Fetch documentation from server
if docs_content=$(curl -s --max-time 30 --fail "$docs_url" 2>/dev/null); then
    # Display content based on output format
    if [[ "$output_format" == "text" ]]; then
        # Raw markdown output when --text flag is used
        echo "$docs_content"
    elif command -v glow >/dev/null 2>&1; then
        # Use glow for enhanced formatting when available
        echo "$docs_content" | glow --width=0 --pager -
    else
        # Fallback to raw markdown if glow not installed
        echo "$docs_content"
    fi
else
    print_error "Failed to fetch documentation from: $docs_url"
    print_info "Ensure server is running and documentation endpoint is available"
    print_info "Try 'monk docs' without arguments to view available documentation"
    exit 1
fi
