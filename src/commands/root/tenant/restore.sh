#!/bin/bash

# root_tenant_restore_command.sh - Restore soft deleted tenant via /api/root/tenant/:name

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"

# Make restore request (PUT to clear trashed_at)
response=$(make_root_request "PUT" "tenant/${name}" "")

# Handle response
if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    print_success "Tenant '$name' restored from trash"
else
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_error "Failed to restore tenant: $error_msg"
    exit 1
fi