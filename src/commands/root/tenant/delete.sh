#!/bin/bash

# root_tenant_delete_command.sh - Hard delete tenant via /api/root/tenant/:name?force=true

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"
force_flag="${args[--force]}"

# Confirmation prompt (unless --force used)
confirm_destructive_operation "PERMANENTLY delete tenant and database" "$name" "$force_flag" "DELETE"

# Make hard delete request (DELETE with force=true parameter)
# Handle query parameter separately from URL encoding
base_url=$(get_base_url)
encoded_name=$(url_encode "$name")
response=$(curl -s -X DELETE "${base_url}/api/root/tenant/${encoded_name}?force=true")

# Handle response
if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    print_success "Tenant '$name' permanently deleted"
    print_warning "Database and all data have been removed"
else
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_error "Failed to delete tenant: $error_msg"
    exit 1
fi