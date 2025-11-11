#!/bin/bash

# project_list_command.sh - List all projects (tenants)

# Check dependencies
check_dependencies

# Get arguments from bashly
include_trashed="${args[--include-trashed]}"
include_deleted="${args[--include-deleted]}"

# Build query parameters
params=""
if [[ "$include_trashed" == "1" ]]; then
    params="${params}&include_trashed=true"
fi
if [[ "$include_deleted" == "1" ]]; then
    params="${params}&include_deleted=true"
fi

# Remove leading & if present
params=${params#&}

# Make request to root API
if [[ -n "$params" ]]; then
    response=$(make_root_request "GET" "tenant?$params")
else
    response=$(make_root_request "GET" "tenant")
fi

# Handle response
if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    tenants=$(echo "$response" | jq -r '.tenants[]?')
    
    if [[ -z "$tenants" ]]; then
        if [[ "$format_json" == "1" ]]; then
            echo '{"success":true,"tenants":[],"count":0}'
        else
            echo "No projects found."
        fi
        exit 0
    fi
    
# Get current tenant for highlighting
init_cli_configs
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    
    if [[ "$format_json" == "1" ]]; then
        # JSON output - return as-is with count
        count=$(echo "$response" | jq -r '.tenants | length')
        echo "$response" | jq --argjson count "$count" '. + {count: $count}'
    else
        # Text output - format as table
        echo
        printf "%-25s %-12s %-15s %-20s %s\n" "PROJECT" "STATUS" "DATABASE" "HOST" "CREATED"
        printf "%-25s %-12s %-15s %-20s %s\n" "-----------------------" "------------" "---------------" "--------------------" "-------------------"
        
        echo "$tenants" | while read -r tenant; do
            if [[ -n "$tenant" ]]; then
                name=$(echo "$tenant" | jq -r '.name')
                status=$(echo "$tenant" | jq -r '.status // "active"')
                database=$(echo "$tenant" | jq -r '.database // "unknown"')
                host=$(echo "$tenant" | jq -r '.host // "localhost"')
                created=$(echo "$tenant" | jq -r '.created_at // "unknown"')
                
                # Format created date
                if [[ "$created" != "null" && "$created" != "unknown" ]]; then
                    created=$(date -d "$created" +%Y-%m-%d 2>/dev/null || echo "$created" | cut -d'T' -f1)
                fi
                
                # Highlight current tenant
                if [[ "$name" == "$current_tenant" ]]; then
                    name="${name} *"
                fi
                
                printf "%-25s %-12s %-15s %-20s %s\n" "$name" "$status" "$database" "$host" "$created"
            fi
        done
        
        echo
        if [[ -n "$current_tenant" ]]; then
            echo "Current project: $current_tenant (server: $current_server)"
        else
            echo "No project selected. Use 'monk project use <name>' to select a project."
        fi
        
        # Show project count
        count=$(echo "$response" | jq -r '.tenants | length')
        echo "Total projects: $count"
        
        if [[ "$include_trashed" != "1" && "$include_deleted" != "1" ]]; then
            echo "Use --include-trashed or --include-deleted to show inactive projects."
        fi
    fi
else
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_error "Failed to list projects: $error_msg"
    exit 1
fi