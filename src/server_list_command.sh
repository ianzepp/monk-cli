#!/bin/bash

# server_list_command.sh - List all servers with universal output format support

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
server_names=$(jq -r '.servers | keys[]' "$SERVER_CONFIG" 2>/dev/null)

if [ -z "$server_names" ]; then
    # No servers - handle based on output format
    empty_result='{"servers": [], "current_server": null}'
    
    if [[ "$output_format" == "text" ]]; then
        echo
        print_info "Registered Servers"
        echo
        print_info "No servers configured"
        print_info "Use 'monk server add <name> <hostname:port>' to add servers"
    else
        handle_output "$empty_result" "$output_format" "json" "server_list"
    fi
    exit 0
fi

# Build JSON data internally (always generate JSON first)
servers_json=$(echo "$server_names" | while read -r name; do
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
        
        # Create JSON object for this server
        jq -n \
            --arg name "$name" \
            --arg hostname "$hostname" \
            --argjson port "$port" \
            --arg protocol "$protocol" \
            --arg endpoint "$endpoint" \
            --arg status "$status" \
            --arg last_ping "$last_ping" \
            --arg added_at "$added_at" \
            --arg description "$description" \
            --argjson auth_sessions "$auth_count" \
            --argjson is_current "$is_current" \
            '{
                name: $name,
                hostname: $hostname,
                port: $port,
                protocol: $protocol,
                endpoint: $endpoint,
                status: $status,
                last_ping: $last_ping,
                added_at: $added_at,
                description: $description,
                auth_sessions: $auth_sessions,
                is_current: $is_current
            }'
    fi
done | jq -s --arg current_server "$current_server" \
    '{servers: ., current_server: ($current_server | if . == "" then null else . end)}')

# Output in requested format
if [[ "$output_format" == "text" ]]; then
    echo
    print_info "Registered Servers"
    echo
    
    # Build markdown table
    markdown_output=""
    markdown_output+="| NAME | ENDPOINT | STATUS | AUTH SESSIONS | ADDED | CURRENT |\n"
    markdown_output+="|------|----------|--------|---------------|-------|---------|"
    
    # Add data rows using process substitution to avoid subshell issues
    while IFS= read -r row; do
        if [ -n "$row" ]; then
            # Decode the row and extract fields
            decoded=$(echo "$row" | base64 -d)
            name=$(echo "$decoded" | jq -r '.name')
            endpoint=$(echo "$decoded" | jq -r '.endpoint')
            status=$(echo "$decoded" | jq -r '.status')
            auth_sessions=$(echo "$decoded" | jq -r '.auth_sessions')
            added=$(echo "$decoded" | jq -r '.added_at' | cut -d'T' -f1)
            current=$(echo "$decoded" | jq -r 'if .is_current then "*" else "" end')
            
            markdown_output+="\n| ${name} | ${endpoint} | ${status} | ${auth_sessions} | ${added} | ${current} |"
        fi
    done < <(echo "$servers_json" | jq -r '.servers[] | @base64')
    
    # Check if stdout is a TTY (interactive terminal) and glow is available
    if [ -t 1 ] && command -v glow >/dev/null 2>&1; then
        # Render with glow for interactive terminals (width=0 auto-detects terminal width)
        echo -e "$markdown_output" | glow --width=0 -
    else
        # Output raw markdown for pipes and non-interactive use
        echo -e "$markdown_output"
    fi
    
    echo
    if [ -n "$current_server" ]; then
        print_info "Current server: $current_server (marked with *)"
    else
        print_info "No current server selected"
        print_info "Use 'monk server use <name>' to select a server"
    fi
else
    handle_output "$servers_json" "$output_format" "json" "server_list"
fi