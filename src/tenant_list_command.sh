# Check dependencies
check_dependencies

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for tenant management"
    exit 1
fi

# Get arguments from bashly
json_flag="${args[--json]}"

current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
tenant_names=$(jq -r '.tenants | keys[]' "$TENANT_CONFIG" 2>/dev/null)

if [ -z "$tenant_names" ]; then
    if [ "$json_flag" = "1" ]; then
        echo '{"tenants": [], "current_tenant": null}'
    else
        echo
        print_info "Registered Tenants"
        echo
        print_info "No tenants configured"
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
            added_at=$(echo "$tenant_info" | jq -r '.added_at // "unknown"')
            
            # Check authentication count for this tenant across all servers
            auth_count=$(jq --arg tenant "$name" '[.sessions | to_entries[] | select(.key | endswith(":" + $tenant))] | length' "$AUTH_CONFIG" 2>/dev/null || echo "0")
            is_current=$([ "$name" = "$current_tenant" ] && echo "true" || echo "false")
            
            tenant_json=$(jq -n \
                --arg name "$name" \
                --arg display_name "$display_name" \
                --arg description "$description" \
                --arg added_at "$added_at" \
                --argjson auth_count "$auth_count" \
                --argjson is_current "$is_current" \
                '{
                    name: $name,
                    display_name: $display_name,
                    description: $description,
                    added_at: $added_at,
                    auth_sessions: $auth_count,
                    is_current: $is_current
                }')
            
            echo "$tenant_json"
        fi
    done | jq -s --arg current_tenant "$current_tenant" \
        '{tenants: ., current_tenant: ($current_tenant | if . == "" then null else . end)}'
    
else
    # Human-readable output mode
    echo
    print_info "Registered Tenants"
    echo

    printf "%-20s %-30s %-8s %-20s %s\n" "Name" "Display Name" "Auth" "Added" "Description"
    echo "-------------------------------------------------------------------------------------"

    echo "$tenant_names" | while read -r name; do
        if [ -n "$name" ]; then
            tenant_info=$(jq -r ".tenants.\"$name\"" "$TENANT_CONFIG")
            
            display_name=$(echo "$tenant_info" | jq -r '.display_name')
            description=$(echo "$tenant_info" | jq -r '.description // ""')
            added_at=$(echo "$tenant_info" | jq -r '.added_at // "unknown"')
            
            # Format timestamp
            if [ "$added_at" != "unknown" ]; then
                added_at=$(echo "$added_at" | cut -d'T' -f1)
            fi
            
            # Check authentication count for this tenant across all servers
            auth_count=$(jq --arg tenant "$name" '[.sessions | to_entries[] | select(.key | endswith(":" + $tenant))] | length' "$AUTH_CONFIG" 2>/dev/null || echo "0")
            if [ "$auth_count" -gt 0 ]; then
                auth_status="yes ($auth_count)"
            else
                auth_status="no"
            fi
            
            # Mark current tenant
            marker=""
            if [ "$name" = "$current_tenant" ]; then
                marker="*"
            fi
            
            printf "%-20s %-30s %-8s %-20s %s %s\n" \
                "$name" "$display_name" "$auth_status" "$added_at" "$description" "$marker"
        fi
    done

    echo
    if [ -n "$current_tenant" ]; then
        print_info "Current tenant: $current_tenant (marked with *)"
    else
        print_info "No current tenant selected"
        print_info "Use 'monk tenant use <name>' to select a tenant"
    fi
fi