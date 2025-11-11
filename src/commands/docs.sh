#!/bin/bash

# docs_command.sh - Display API documentation from remote server
#
# This command dynamically discovers available documentation areas by querying
# the API root endpoint, then fetches documentation for the requested area.
#
# Usage Examples:
#   monk docs auth              # Display authentication API documentation
#   monk docs data              # Display data API documentation  
#   monk docs meta              # Display metadata API documentation
#   monk docs badarea           # Show available areas if no exact match
#
# Output Format:
#   - Uses glow for enhanced markdown formatting when available
#   - Falls back to raw markdown if glow not installed
#   - Supports --text flag for raw markdown output
#
# Dynamic Discovery:
#   - Queries GET / to get available documentation areas
#   - Matches exact area name against documentation keys
#   - Shows available areas if no exact match found

# Check dependencies
check_dependencies

# Get arguments from bashly
area="${args[area]}"

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

print_info "Discovering available documentation areas from: $current_server"

# Query API root to get available documentation areas
if api_response=$(curl -s --max-time 30 --fail "$base_url/" 2>/dev/null); then
    # Extract documentation section
    if ! documentation_section=$(echo "$api_response" | jq -r '.data.documentation // empty' 2>/dev/null); then
        print_error "Failed to parse API response for documentation areas"
        exit 1
    fi
    
    if [ -z "$documentation_section" ] || [ "$documentation_section" = "null" ]; then
        print_error "No documentation section found in API response"
        print_info "The API may not support dynamic documentation discovery"
        exit 1
    fi
    
    # Get available areas (keys from documentation object)
    available_areas=$(echo "$documentation_section" | jq -r 'keys[]' 2>/dev/null)
    
    if [ -z "$available_areas" ]; then
        print_error "No documentation areas found"
        exit 1
    fi
    
    # Check if requested area exists (exact match)
    area_found=false
    area_routes=""
    
    for available_area in $available_areas; do
        if [ "$available_area" = "$area" ]; then
            area_found=true
            # Get the routes for this area (should be an array)
            area_routes=$(echo "$documentation_section" | jq -r ".$area[]" 2>/dev/null)
            break
        fi
    done
    
    if [ "$area_found" = false ]; then
        print_error "Documentation area '$area' not found"
        echo "Available documentation areas:" >&2
        for available_area in $available_areas; do
            echo "  - $available_area" >&2
        done
        exit 1
    fi
    
    # Use the first route for the area
    if [ -z "$area_routes" ]; then
        print_error "No documentation routes found for area '$area'"
        exit 1
    fi
    
    # Get the first route from the array
    first_route=$(echo "$area_routes" | head -n 1)
    
    if [ -z "$first_route" ]; then
        print_error "Empty documentation route for area '$area'"
        exit 1
    fi
    
    print_info "Fetching documentation for area '$area' from: $first_route"
    
    # Fetch documentation from the discovered route
    if docs_content=$(curl -s --max-time 30 --fail "$base_url$first_route" 2>/dev/null); then
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
        print_error "Failed to fetch documentation from route '$first_route'"
        print_info "Ensure server is running and documentation endpoint is available"
        exit 1
    fi
    
else
    print_error "Failed to query API root endpoint for documentation discovery"
    print_info "Ensure server '$current_server' is running and accessible"
    exit 1
fi
