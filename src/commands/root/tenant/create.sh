#!/bin/bash

# root_tenant_create_command.sh - Create new tenant via /api/root/tenant

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"
host="${args[--host]:-localhost}"
force="${args[--force]}"

# Create JSON payload
payload=$(jq -n --arg name "$name" --arg host "$host" '{name: $name, host: $host}')

# Check if tenant exists (unless force flag used)
if [[ "$force" != "1" ]]; then
    # Use curl directly for existence check to avoid set -e issues
    base_url=$(get_base_url)
    local encoded_name=$(url_encode "$name")
    existing=$(curl -s "${base_url}/api/root/tenant/${encoded_name}" 2>/dev/null)
    
    if echo "$existing" | jq -e '.success and .tenant' >/dev/null 2>&1; then
        print_error "Tenant '$name' already exists. Use --force to override."
        exit 1
    fi
fi

print_info "Creating tenant with payload: $payload"

# Make create request
response=$(make_root_request "POST" "tenant" "$payload")

# Handle response
if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    # API now returns tenant as object
    tenant=$(echo "$response" | jq -r '.tenant')
    tenant_name=$(echo "$tenant" | jq -r '.name')
    database=$(echo "$tenant" | jq -r '.database')
    tenant_host=$(echo "$tenant" | jq -r '.host')
    
    print_success "Tenant '$tenant_name' created successfully"
    print_info "Database: $database"
    print_info "Host: $tenant_host"
else
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_error "Failed to create tenant: $error_msg"
    exit 1
fi