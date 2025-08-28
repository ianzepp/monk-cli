# Check dependencies
check_dependencies

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for tenant management"
    exit 1
fi

# Get arguments from bashly
json_flag="${args[--json]}"
server_flag="${args[--server]}"

current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)

# Determine target server
target_server="$server_flag"
if [ -z "$target_server" ]; then
    target_server="$current_server"
fi

if [ -z "$target_server" ] || [ "$target_server" = "null" ]; then
    if [ "$json_flag" = "1" ]; then
        echo '{"error": "No server specified and no current server selected"}'
    else
        print_error "No server specified and no current server selected"
        print_info "Use 'monk server use <name>' to select a server or use --server flag"
    fi
    exit 1
fi

# Get tenant names for the target server
tenant_names=$(jq -r --arg server "$target_server" '.tenants | to_entries[] | select(.value.server == $server) | .key' "$TENANT_CONFIG" 2>/dev/null)

if [ -z "$tenant_names" ]; then
    if [ "$json_flag" = "1" ]; then
        jq -n --arg server "$target_server" \
            '{"tenants": [], "current_tenant": null, "server": $server}'
    else
        echo
        print_info "Registered Tenants for Server: $target_server"
        echo
        print_info "No tenants configured for this server"
        print_info "Use 'monk tenant add <name> <display_name>' to add tenants"
    fi
    exit 0
fi

if [ "$json_flag" = "1" ]; then
    # JSON output mode
    echo "$tenant_names" | while read -r name; do
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
            
            tenant_json=$(jq -n \
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
                }')
            
            echo "$tenant_json"
        fi
    done | jq -s --arg current_tenant "$current_tenant" \
        --arg server "$target_server" \
        '{tenants: ., current_tenant: ($current_tenant | if . == "" then null else . end), server: $server}'
    
else
    # Human-readable output mode
    echo
    print_info "Registered Tenants for Server: $target_server"
    echo

    printf "%-20s %-30s %-8s %-20s %s\n" "Name" "Display Name" "Auth" "Added" "Description"
    echo "-------------------------------------------------------------------------------------"

    echo "$tenant_names" | while read -r name; do
        if [ -n "$name" ]; then
            tenant_info=$(jq -r ".tenants.\"$name\"" "$TENANT_CONFIG")
            
            display_name=$(echo "$tenant_info" | jq -r '.display_name')
            description=$(echo "$tenant_info" | jq -r '.description // ""')
            server=$(echo "$tenant_info" | jq -r '.server')
            added_at=$(echo "$tenant_info" | jq -r '.added_at // "unknown"')
            
            # Format timestamp
            if [ "$added_at" != "unknown" ]; then
                added_at=$(echo "$added_at" | cut -d'T' -f1)
            fi
            
            # Check authentication for this tenant on this specific server
            session_key="${server}:${name}"
            auth_count=$(jq --arg session_key "$session_key" '.sessions | has($session_key) | if . then 1 else 0 end' "$AUTH_CONFIG" 2>/dev/null || echo "0")
            if [ "$auth_count" -gt 0 ]; then
                auth_status="yes"
            else
                auth_status="no"
            fi
            
            # Mark current tenant (only if on current server)
            marker=""
            if [ "$name" = "$current_tenant" ] && [ "$server" = "$current_server" ]; then
                marker="*"
            fi
            
            printf "%-20s %-30s %-8s %-20s %s %s\n" \
                "$name" "$display_name" "$auth_status" "$added_at" "$description" "$marker"
        fi
    done

    echo
    if [ -n "$current_tenant" ] && [ "$target_server" = "$current_server" ]; then
        print_info "Current tenant: $current_tenant (marked with *)"
    else
        print_info "No current tenant selected for this server"
        print_info "Use 'monk tenant use <name>' to select a tenant"
    fi
fi