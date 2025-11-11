#!/bin/bash

# root_tenant_health_command.sh - Check tenant database health via /api/root/tenant/:name/health

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"

# Determine output format from global flags
output_format=$(get_output_format "text")

# Make health check request
response=$(make_root_request "GET" "tenant/${name}/health" "")

if echo "$response" | jq -e '.success and .health' >/dev/null 2>&1; then
    if [[ "$output_format" == "text" ]]; then
        # Human-readable output
        health=$(echo "$response" | jq -r '.health')
        
        tenant_name=$(echo "$health" | jq -r '.tenant')
        timestamp=$(echo "$health" | jq -r '.timestamp')
        status=$(echo "$health" | jq -r '.status')
        
        echo
        print_info "Health Check for Tenant: $tenant_name"
        echo
        printf "%-20s %s\n" "Status:" "$status"
        printf "%-20s %s\n" "Checked:" "$(echo "$timestamp" | cut -d'T' -f1,2 | tr 'T' ' ')"
        echo
        
        # Display individual checks
        echo "Database Checks:"
        checks=$(echo "$health" | jq -r '.checks')
        
        echo "$checks" | jq -r 'to_entries[] | "\(.key): \(.value)"' | while read -r check; do
            key=$(echo "$check" | cut -d':' -f1)
            value=$(echo "$check" | cut -d':' -f2 | tr -d ' ')
            
            if [[ "$value" == "true" ]]; then
                printf "  %-25s %s\n" "$key" "✓"
            else
                printf "  %-25s %s\n" "$key" "✗"
            fi
        done
        
        # Show errors if any
        errors=$(echo "$health" | jq -r '.errors[]?' 2>/dev/null)
        if [[ -n "$errors" ]]; then
            echo
            echo "Errors:"
            echo "$errors" | while read -r error; do
                echo "  • $error"
            done
        fi
        
        echo
    else
        # JSON output - compact format
        handle_output "$response" "$output_format" "json"
    fi
else
    error_msg=$(echo "$response" | jq -r '.error // "Health check failed"')
    print_error "$error_msg"
    exit 1
fi