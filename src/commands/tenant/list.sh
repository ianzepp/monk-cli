#!/bin/bash

# tenant_list_command.sh - List all registered tenants with universal format support

# Check dependencies
check_dependencies

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for tenant management"
    exit 1
fi

# Get arguments from bashly
server_flag="${args[--server]}"

# Determine output format from global flags
output_format=$(get_output_format "text")

current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)

# Determine target server
target_server="$server_flag"
if [ -z "$target_server" ]; then
    target_server="$current_server"
fi

if [ -z "$target_server" ] || [ "$target_server" = "null" ]; then
    error_result='{"error": "No server specified and no current server selected"}'
    
    if [[ "$output_format" == "text" ]]; then
        print_error "No server specified and no current server selected"
        print_info "Use 'monk server use <name>' to select a server or use --server flag"
    else
        handle_output "$error_result" "$output_format" "json"
    fi
    exit 1
fi

# Get tenant names for the target server
tenant_names=$(jq -r --arg server "$target_server" '.tenants | to_entries[] | select(.value.server == $server) | .key' "$TENANT_CONFIG" 2>/dev/null)

if [ -z "$tenant_names" ]; then
    empty_result=$(jq -n --arg server "$target_server" '{"tenants": [], "current_tenant": null, "server": $server}')
    
    if [[ "$output_format" == "text" ]]; then
        echo
        print_info "Registered Tenants for Server: $target_server"
        echo
        print_info "No tenants configured for this server"
        print_info "Use 'monk tenant add <name> <display_name>' to add tenants"
    else
        handle_output "$empty_result" "$output_format" "json"
    fi
    exit 0
fi

# Build JSON data for all tenants
tenants_json=$(echo "$tenant_names" | while read -r name; do
    if [ -n "$name" ]; then
        tenant_info=$(jq -r ".tenants.\"$name\"" "$TENANT_CONFIG")
        
        display_name=$(echo "$tenant_info" | jq -r '.display_name')
        description=$(echo "$tenant_info" | jq -r '.description // ""')
        server=$(echo "$tenant_info" | jq -r '.server')
        added_at=$(echo "$tenant_info" | jq -r '.added_at // "unknown"')
        
        # Check authentication count for this tenant on this specific server
        session_key="${server}:${name}"
        auth_count=$(jq --arg session_key "$session_key" '.sessions | has($session_key) | if . then 1 else 0 end' "$AUTH_CONFIG" 2>/dev/null || echo "0")
        is_current=$([ "$name" = "$current_tenant" ] && [ "$server" = "$current_server" ] && echo "true" || echo "false")
        
        jq -n \
            --arg name "$name" \
            --arg display_name "$display_name" \
            --arg description "$description" \
            --arg server "$server" \
            --arg added_at "$added_at" \
            --argjson auth_count "$auth_count" \
            --argjson is_current "$is_current" \
            '{
                name: $name,
                display_name: $display_name,
                description: $description,
                server: $server,
                added_at: $added_at,
                authenticated: ($auth_count > 0),
                is_current: $is_current
            }'
    fi
done | jq -s --arg current_tenant "$current_tenant" \
    --arg server "$target_server" \
    '{tenants: ., current_tenant: ($current_tenant | if . == "" then null else . end), server: $server}')

# Output in requested format
if [[ "$output_format" == "text" ]]; then
    echo
    print_info "Registered Tenants for Server: $target_server"
    echo
    
    # Build markdown table
    markdown_output=""
    markdown_output+="| NAME | DISPLAY NAME | AUTH | ADDED | DESCRIPTION | CURRENT |\n"
    markdown_output+="|------|--------------|------|-------|-------------|---------|"
    
    # Add data rows using process substitution to avoid subshell issues
    while IFS= read -r row; do
        if [ -n "$row" ]; then
            # Decode the row and extract fields
            decoded=$(echo "$row" | base64 -d)
            name=$(echo "$decoded" | jq -r '.name')
            display_name=$(echo "$decoded" | jq -r '.display_name')
            auth=$(echo "$decoded" | jq -r 'if .authenticated then "yes" else "no" end')
            added=$(echo "$decoded" | jq -r '.added_at' | cut -d'T' -f1)
            description=$(echo "$decoded" | jq -r '.description')
            current=$(echo "$decoded" | jq -r 'if .is_current then "*" else "" end')
            
            markdown_output+="\n| ${name} | ${display_name} | ${auth} | ${added} | ${description} | ${current} |"
        fi
    done < <(echo "$tenants_json" | jq -r '.tenants[] | @base64')
    
    # Check if stdout is a TTY (interactive terminal) and glow is available
    if [ -t 1 ] && command -v glow >/dev/null 2>&1; then
        # Render with glow for interactive terminals (width=0 auto-detects terminal width)
        echo -e "$markdown_output" | glow --width=0 -
    else
        # Output raw markdown for pipes and non-interactive use
        echo -e "$markdown_output"
    fi
    
    echo
    if [ -n "$current_tenant" ] && [ "$target_server" = "$current_server" ]; then
        print_info "Current tenant: $current_tenant (marked with *)"
    else
        print_info "No current tenant selected for this server"
        print_info "Use 'monk tenant use <name>' to select a tenant"
    fi
else
    handle_output "$tenants_json" "$output_format" "json"
fi