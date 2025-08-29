#!/bin/bash

# root_tenant_show_command.sh - Show tenant details via /api/root/tenant/:name

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"

# Determine output format from global flags
output_format=$(get_output_format "text")

# Make request to get tenant details
response=$(make_root_request "GET" "tenant/${name}" "")

if echo "$response" | jq -e '.success and .tenant' >/dev/null 2>&1; then
    if [[ "$output_format" == "text" ]]; then
        # Human-readable output
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
        # JSON output - compact format
        handle_output "$response" "$output_format" "json"
    fi
else
    error_msg=$(echo "$response" | jq -r '.error // "Tenant not found"')
    print_error "$error_msg"
    exit 1
fi