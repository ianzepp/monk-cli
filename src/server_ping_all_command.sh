#!/bin/bash

# server_ping_all_command.sh - Health check all servers with universal format support

# Check dependencies
check_dependencies

# Determine output format from global flags
output_format=$(get_output_format "text")

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for server management"
    exit 1
fi

server_names=$(jq -r '.servers | keys[]' "$SERVER_CONFIG" 2>/dev/null)

if [ -z "$server_names" ]; then
    empty_result='{"servers": [], "summary": {"total": 0, "up": 0, "down": 0}}'
    
    if [[ "$output_format" == "text" ]]; then
        echo
        print_info "Pinging All Servers"
        echo
        print_info "No servers configured"
        print_info "Use 'monk server add <name> <hostname:port>' to add servers"
    else
        handle_output "$empty_result" "$output_format" "json"
    fi
    exit 0
fi

if [[ "$output_format" == "text" ]]; then
    echo
    print_info "Pinging All Servers"
    echo
fi

# Build results array for JSON output
ping_results=$(echo "$server_names" | while read -r name; do
    if [ -n "$name" ]; then
        server_info=$(jq -r ".servers.\"$name\"" "$SERVER_CONFIG")
        hostname=$(echo "$server_info" | jq -r '.hostname')
        port=$(echo "$server_info" | jq -r '.port')
        protocol=$(echo "$server_info" | jq -r '.protocol')
        base_url="$protocol://$hostname:$port"
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        
        # Test connectivity with timeout
        if response_time_raw=$(curl -s --max-time 5 --fail -w '%{time_total}' -o /dev/null "$base_url/" 2>/dev/null); then
            response_time=$(echo "$response_time_raw" | awk '{printf "%.0f", $1 * 1000}')
            server_status="up"
            success=true
            
            if [[ "$output_format" == "text" ]]; then
                printf "%-15s %-30s %-8s %s\n" "$name" "$base_url" "up" "${response_time}ms"
            fi
        else
            response_time=0
            server_status="down"
            success=false
            
            if [[ "$output_format" == "text" ]]; then
                printf "%-15s %-30s %-8s %s\n" "$name" "$base_url" "down" "timeout"
            fi
        fi
        
        # Update server status in config
        temp_file=$(mktemp)
        jq --arg name "$name" \
           --arg timestamp "$timestamp" \
           --arg status "$server_status" \
           '.servers[$name].last_ping = $timestamp | .servers[$name].status = $status' \
           "$SERVER_CONFIG" > "$temp_file" && mv "$temp_file" "$SERVER_CONFIG"
        
        # Generate JSON result for this server
        jq -n \
            --arg server_name "$name" \
            --arg hostname "$hostname" \
            --arg port "$port" \
            --arg protocol "$protocol" \
            --arg endpoint "$base_url" \
            --arg status "$server_status" \
            --arg timestamp "$timestamp" \
            --argjson response_time_ms "$response_time" \
            --argjson success "$success" \
            '{
                server_name: $server_name,
                hostname: $hostname,
                port: ($port | tonumber),
                protocol: $protocol,
                endpoint: $endpoint,
                status: $status,
                timestamp: $timestamp,
                response_time_ms: $response_time_ms,
                success: $success
            }'
    fi
done)

# Calculate summary statistics and build final result
if [[ "$output_format" == "json" ]]; then
    # Build complete JSON response with summary
    final_result=$(echo "$ping_results" | jq -s '{
        servers: .,
        summary: {
            total: length,
            up: [.[] | select(.success == true)] | length,
            down: [.[] | select(.success == false)] | length
        }
    }')
    handle_output "$final_result" "$output_format" "json"
elif [[ "$output_format" == "text" ]]; then
    # Show summary for text output
    total_servers=$(echo "$ping_results" | jq -s 'length')
    up_servers=$(echo "$ping_results" | jq -s '[.[] | select(.success == true)] | length')
    down_servers=$(echo "$ping_results" | jq -s '[.[] | select(.success == false)] | length')
    
    echo
    print_info "Summary: $up_servers up, $down_servers down (total: $total_servers)"
fi