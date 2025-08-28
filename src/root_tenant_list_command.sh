#!/bin/bash

# root_tenant_list_command.sh - List all tenants via /api/root/tenant

# Check dependencies
check_dependencies

# Get arguments from bashly
include_trashed="${args[--include-trashed]}"
include_deleted="${args[--include-deleted]}"
json_flag="${args[--json]}"

# Build query parameters
params=""
[[ "$include_trashed" == "1" ]] && params="?include_trashed=true"
[[ "$include_deleted" == "1" ]] && params="${params:+${params}&}include_deleted=true"

# Make request to root API
endpoint="tenant${params}"
response=$(make_root_request "GET" "$endpoint" "")

if [[ "$json_flag" == "1" ]]; then
    # JSON output - pass through directly
    echo "$response"
else
    # Human-readable table output
    if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
        tenants=$(echo "$response" | jq -r '.tenants')
        format_tenant_table "$tenants" "$include_trashed" "$include_deleted"
    else
        print_error "Failed to retrieve tenants"
        echo "$response" >&2
        exit 1
    fi
fi