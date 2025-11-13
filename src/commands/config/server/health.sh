#!/bin/bash

# server_health_command.sh - Check server health status from API /health endpoint

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
            print_info "Use 'monk server health <name>' or 'monk server use <name>' first"
        else
            handle_output "$error_result" "$output_format" "json"
        fi
        exit 1
    fi
    
    if [[ "$output_format" == "text" ]]; then
        print_info "Using current server: $name"
    fi
fi

# Get server info (as JSON, not raw text)
server_info=$(jq ".servers.\"$name\"" "$SERVER_CONFIG" 2>/dev/null)
if [ "$server_info" = "null" ] || [ -z "$server_info" ]; then
    error_result=$(jq -n --arg server_name "$name" '{"server_name": $server_name, "error": "Server not found"}')
    
    if [[ "$output_format" == "text" ]]; then
        print_error "Server '$name' not found"
        print_info "Use 'monk server list' to see available servers"
    else
        handle_output "$error_result" "$output_format" "json"
    fi
    exit 1
fi

hostname=$(echo "$server_info" | jq -r '.hostname' 2>/dev/null)
port=$(echo "$server_info" | jq -r '.port' 2>/dev/null) 
protocol=$(echo "$server_info" | jq -r '.protocol' 2>/dev/null)
base_url="$protocol://$hostname:$port"

# Fetch server health from API /health endpoint
if api_response=$(curl -s --max-time 10 --fail "$base_url/health" 2>/dev/null); then
    # Parse the API response - check if there's a .data wrapper
    has_data_wrapper=$(echo "$api_response" | jq 'has("data")' 2>/dev/null)
    
    if [ "$has_data_wrapper" = "true" ]; then
        # Extract data from wrapper
        api_data=$(echo "$api_response" | jq '.data' 2>/dev/null)
    else
        # Use response directly if no wrapper
        api_data="$api_response"
    fi
    
    # Extract health information
    health_status=$(echo "$api_data" | jq -r '.status // "unknown"')
    server_version=$(echo "$api_data" | jq -r '.version // "unknown"')
    server_name_from_api=$(echo "$api_data" | jq -r '.name // "unknown"')
    uptime=$(echo "$api_data" | jq -r '.uptime // null')
    timestamp=$(echo "$api_data" | jq -r '.timestamp // null')
    
    # Extract database health if available
    database_status=$(echo "$api_data" | jq -r '.database // null')
    database_connected="null"
    
    # Extract any additional checks
    checks=$(echo "$api_data" | jq -r '.checks // {}')
    
    # Build health response
    health_result=$(jq -n \
        --arg server_name "$name" \
        --arg hostname "$hostname" \
        --arg port "$port" \
        --arg protocol "$protocol" \
        --arg endpoint "$base_url" \
        --arg status "$health_status" \
        --arg version "$server_version" \
        --arg api_name "$server_name_from_api" \
        --arg uptime "$uptime" \
        --arg timestamp "$timestamp" \
        --arg database_status "$database_status" \
        --arg database_connected "$database_connected" \
        --argjson checks "$checks" \
        '{
            server_name: $server_name,
            hostname: $hostname,
            port: ($port | tonumber),
            protocol: $protocol,
            endpoint: $endpoint,
            health: {
                status: $status,
                version: $version,
                name: $api_name,
                uptime: $uptime,
                timestamp: $timestamp,
                database: (if $database_status != "null" then {
                    status: $database_status,
                    connected: ($database_connected | if . == "null" then null else . == "true" end)
                } else null end),
                checks: (if $checks != {} then $checks else null end)
            },
            success: true
        }')
    
    if [[ "$output_format" == "text" ]]; then
        echo
        print_info "Server Health: $name"
        echo
        print_info "Connection:"
        echo "  Endpoint: $base_url/health"
        echo "  Hostname: $hostname"
        echo "  Port: $port"
        echo "  Protocol: $protocol"
        echo
        print_info "Health Status:"
        echo "  Status: $health_status"
        if [ "$server_version" != "unknown" ] && [ "$server_version" != "null" ]; then
            echo "  Version: $server_version"
        fi
        if [ "$server_name_from_api" != "unknown" ] && [ "$server_name_from_api" != "null" ]; then
            echo "  API Name: $server_name_from_api"
        fi
        if [ "$uptime" != "null" ]; then
            echo "  Uptime: $uptime"
        fi
        if [ "$timestamp" != "null" ]; then
            echo "  Timestamp: $timestamp"
        fi
        
        # Display database health if available
        if [ "$database_status" != "null" ]; then
            echo
            print_info "Database Health:"
            echo "  Status: $database_status"
            if [ "$database_connected" != "null" ]; then
                echo "  Connected: $database_connected"
            fi
        fi
        
        # Display additional checks if available
        if [ "$(echo "$checks" | jq -r '. | length')" -gt 0 ]; then
            echo
            print_info "Additional Checks:"
            echo "$checks" | jq -r 'to_entries[] | "  \(.key): \(.value)"'
        fi
        
        # Overall status message
        echo
        if [ "$health_status" = "healthy" ] || [ "$health_status" = "ok" ] || [ "$health_status" = "up" ]; then
            print_success "Server is healthy and operational"
        elif [ "$health_status" = "degraded" ] || [ "$health_status" = "warning" ]; then
            print_warning "Server is operational but degraded"
        else
            print_warning "Server health status: $health_status"
        fi
    else
        handle_output "$health_result" "$output_format" "json"
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
            health: {
                status: "down"
            },
            success: false,
            error: "Failed to connect to server health endpoint"
        }')
    
    if [[ "$output_format" == "text" ]]; then
        print_error "Failed to check health of server '$name' at $base_url/health"
        print_info "The server may be down or the /health endpoint may be unavailable"
        print_info "Use 'monk server ping $name' to check basic connectivity"
    else
        handle_output "$error_result" "$output_format" "json"
    fi
    exit 1
fi