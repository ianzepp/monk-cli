#!/bin/bash

# server_info_command.sh - Show server information from API root endpoint

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"

# Determine output format from global flags
output_format=$(get_output_format "text")

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for server management"
    exit 1
fi

# If no name provided, use current server
if [ -z "$name" ]; then
    name=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    
    if [ -z "$name" ] || [ "$name" = "null" ]; then
        error_result='{"error": "No server specified and no current server selected"}'
        
        if [[ "$output_format" == "text" ]]; then
            print_error "No server specified and no current server selected"
            print_info "Use 'monk config server info <name>' or 'monk config server use <name>' first"
        else
            handle_output "$error_result" "$output_format" "json"
        fi
        exit 1
    fi
    
    if [[ "$output_format" == "text" ]]; then
        print_info "Using current server: $name"
    fi
fi

# Get server info
server_info=$(jq -r ".servers.\"$name\"" "$SERVER_CONFIG" 2>/dev/null)
if [ "$server_info" = "null" ]; then
    error_result=$(jq -n --arg server_name "$name" '{"server_name": $server_name, "error": "Server not found"}')
    
    if [[ "$output_format" == "text" ]]; then
        print_error "Server '$name' not found"
        print_info "Use 'monk config server list' to see available servers"
    else
        handle_output "$error_result" "$output_format" "json"
    fi
    exit 1
fi

hostname=$(echo "$server_info" | jq -r '.hostname')
port=$(echo "$server_info" | jq -r '.port')
protocol=$(echo "$server_info" | jq -r '.protocol')
base_url="$protocol://$hostname:$port"

# Fetch server info from API root endpoint
if api_response=$(curl -s --max-time 10 --fail "$base_url/" 2>/dev/null); then
    # Parse the API response
    api_data=$(echo "$api_response" | jq -r '.data // empty' 2>/dev/null)
    
    if [ -z "$api_data" ] || [ "$api_data" = "null" ]; then
        error_result=$(jq -n --arg server_name "$name" --arg endpoint "$base_url" '{"server_name": $server_name, "endpoint": $endpoint, "error": "Invalid API response format"}')
        
        if [[ "$output_format" == "text" ]]; then
            print_error "Invalid API response format from server"
        else
            handle_output "$error_result" "$output_format" "json"
        fi
        exit 1
    fi
    
    # Extract API information
    api_name=$(echo "$api_data" | jq -r '.name // "Unknown"')
    api_version=$(echo "$api_data" | jq -r '.version // "Unknown"')
    api_description=$(echo "$api_data" | jq -r '.description // ""')
    
    # Build complete info response
    info_result=$(jq -n \
        --arg server_name "$name" \
        --arg hostname "$hostname" \
        --arg port "$port" \
        --arg protocol "$protocol" \
        --arg endpoint "$base_url" \
        --arg api_name "$api_name" \
        --arg api_version "$api_version" \
        --arg api_description "$api_description" \
        --argjson endpoints "$(echo "$api_data" | jq '.endpoints // {}')" \
        --argjson documentation "$(echo "$api_data" | jq '.documentation // null')" \
        '{
            server_name: $server_name,
            hostname: $hostname,
            port: ($port | tonumber),
            protocol: $protocol,
            endpoint: $endpoint,
            api: {
                name: $api_name,
                version: $api_version,
                description: $api_description,
                endpoints: $endpoints,
                documentation: $documentation
            },
            status: "up",
            success: true
        }')
    
    if [[ "$output_format" == "text" ]]; then
        echo
        print_info "Server Information: $name"
        echo
        print_info "Connection:"
        echo "  Endpoint: $base_url"
        echo "  Hostname: $hostname"
        echo "  Port: $port"
        echo "  Protocol: $protocol"
        echo
        print_info "API Details:"
        echo "  Name: $api_name"
        echo "  Version: $api_version"
        if [ -n "$api_description" ] && [ "$api_description" != "" ]; then
            echo "  Description: $api_description"
        fi
        echo
        print_info "Available Endpoints:"
        echo "$api_data" | jq -r '.endpoints | to_entries[] | "  \(.key): \(.value)"'
        
        # Display documentation if available
        documentation=$(echo "$api_data" | jq -r '.documentation // empty')
        if [ -n "$documentation" ] && [ "$documentation" != "null" ] && [ "$documentation" != "" ]; then
            echo
            print_info "Documentation:"
            
            # Show overview if available
            overview=$(echo "$api_data" | jq -r '.documentation.overview // empty')
            if [ -n "$overview" ] && [ "$overview" != "null" ] && [ "$overview" != "" ]; then
                echo "  Overview: $overview"
            fi
            
            # Show API documentation if available
            apis=$(echo "$api_data" | jq -r '.documentation.apis // empty')
            if [ -n "$apis" ] && [ "$apis" != "null" ] && [ "$apis" != "" ]; then
                echo "$api_data" | jq -r '.documentation.apis | to_entries[] | "  \(.key): \(.value)"'
            fi
            
            # Show errors documentation if available
            errors=$(echo "$api_data" | jq -r '.documentation.errors // empty')
            if [ -n "$errors" ] && [ "$errors" != "null" ] && [ "$errors" != "" ]; then
                echo "  Errors: $errors"
            fi
        fi
    else
        handle_output "$info_result" "$output_format" "json"
    fi
else
    error_result=$(jq -n \
        --arg server_name "$name" \
        --arg hostname "$hostname" \
        --arg port "$port" \
        --arg protocol "$protocol" \
        --arg endpoint "$base_url" \
        '{
            server_name: $server_name,
            hostname: $hostname,
            port: ($port | tonumber),
            protocol: $protocol,
            endpoint: $endpoint,
            status: "down",
            success: false,
            error: "Failed to connect to server or retrieve information"
        }')
    
    if [[ "$output_format" == "text" ]]; then
        print_error "Failed to connect to server '$name' at $base_url"
        print_info "Use 'monk config server ping $name' to check connectivity"
    else
        handle_output "$error_result" "$output_format" "json"
    fi
    exit 1
fi