#!/bin/bash

# root_tenant_list_command.sh - List all tenants via /api/root/tenant

# Check dependencies
check_dependencies

# Get arguments from bashly
include_trashed="${args[--include-trashed]}"
include_deleted="${args[--include-deleted]}"

# Determine output format from global flags
output_format=$(get_output_format "text")

# Build query parameters
params=""
[[ "$include_trashed" == "1" ]] && params="?include_trashed=true"
[[ "$include_deleted" == "1" ]] && params="${params:+${params}&}include_deleted=true"

# Make request to root API
endpoint="tenant${params}"
response=$(make_root_request "GET" "$endpoint" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    if [[ "$output_format" == "text" ]]; then
        # Human-readable table output using existing function
        tenants=$(echo "$response" | jq -r '.tenants')
        format_tenant_table "$tenants" "$include_trashed" "$include_deleted"
    else
        # JSON output - pass through as compact JSON
        handle_output "$response" "$output_format" "json"
    fi
else
    print_error "Failed to retrieve tenants"
    echo "$response" >&2
    exit 1
fi