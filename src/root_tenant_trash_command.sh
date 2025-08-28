#!/bin/bash

# root_tenant_trash_command.sh - Soft delete tenant via /api/root/tenant/:name

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"

# Confirmation prompt
confirm_destructive_operation "soft delete tenant" "$name" "0"

# Make soft delete request (DELETE without force parameter)
response=$(make_root_request "DELETE" "tenant/${name}" "")

# Handle response
if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    print_success "Tenant '$name' moved to trash"
    print_info "Use 'monk root tenant restore $name' to restore"
else
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_error "Failed to trash tenant: $error_msg"
    exit 1
fi