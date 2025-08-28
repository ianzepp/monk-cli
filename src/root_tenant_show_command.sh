#!/bin/bash

# root_tenant_show_command.sh - Show tenant details via /api/root/tenant/:name

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"
json_flag="${args[--json]}"

# Make request to get tenant details
response=$(make_root_request "GET" "tenant/${name}" "")

if [[ "$json_flag" == "1" ]]; then
    # JSON output - pass through directly
    echo "$response"
else
    # Human-readable output
    if echo "$response" | jq -e '.success and .tenant' >/dev/null 2>&1; then
        tenant=$(echo "$response" | jq -r '.tenant')
        
        echo
        print_info "Tenant Details: $name"
        echo
        
        # Extract and display fields
        tenant_name=$(echo "$tenant" | jq -r '.name')
        database=$(echo "$tenant" | jq -r '.database')
        host=$(echo "$tenant" | jq -r '.host')
        status=$(echo "$tenant" | jq -r '.status')
        created_at=$(echo "$tenant" | jq -r '.created_at')
        updated_at=$(echo "$tenant" | jq -r '.updated_at')
        trashed_at=$(echo "$tenant" | jq -r '.trashed_at // "null"')
        
        printf "%-15s %s\n" "Name:" "$tenant_name"
        printf "%-15s %s\n" "Database:" "$database"
        printf "%-15s %s\n" "Host:" "$host"
        printf "%-15s %s\n" "Status:" "$status"
        printf "%-15s %s\n" "Created:" "$(echo "$created_at" | cut -d'T' -f1)"
        printf "%-15s %s\n" "Updated:" "$(echo "$updated_at" | cut -d'T' -f1)"
        
        if [[ "$trashed_at" != "null" ]]; then
            printf "%-15s %s\n" "Trashed:" "$(echo "$trashed_at" | cut -d'T' -f1)"
        fi
        
        echo
    else
        error_msg=$(echo "$response" | jq -r '.error // "Tenant not found"')
        print_error "$error_msg"
        exit 1
    fi
fi