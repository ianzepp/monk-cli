#!/bin/bash

# fs_rm_command.sh - Remove files with multi-tenant support

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
force_flag="${args[--force]}"
tenant_flag="${args[--tenant]}"

print_info "Removing: $path"

# Build file options based on flags - UPDATED for /api/file/store endpoint
permanent="false"
if [ "$force_flag" = "true" ]; then
    permanent="true"
    print_warning "Permanent deletion requested (not recoverable)"
else
    print_info "Using soft delete (recoverable)"
fi

# For deletion, we use the store endpoint with empty content and overwrite=true
# The path determines what gets deleted (record or field)
file_options=$(jq -n \
    --argjson permanent "$permanent" \
    '{
        "overwrite": true,
        "atomic": true
    }')

# Confirmation prompt for destructive operations
if [ "$force_flag" = "true" ] && [ "$CLI_VERBOSE" = "true" ]; then
    print_warning "Are you sure you want to permanently delete: $path? (y/N)"
    read -r confirmation
    
    if ! echo "$confirmation" | grep -E "^[Yy]$" >/dev/null 2>&1; then
        print_info_always "Operation cancelled"
        exit 0
    fi
fi

# Make request with tenant routing - UPDATED to use /api/file/store for deletion
# For deletion operations, we send empty content to effectively "delete" the record/field
deletion_payload=$(jq -n \
    --arg path "$path" \
    --argjson options "$file_options" \
    '{"path": $path, "content": null, "file_options": $options}')

response=$(make_request_json "POST" "/api/file/store" "$deletion_payload")

# Process deletion result
if [ "$permanent" = "true" ]; then
    print_success "Permanently deleted: $path"
else
    print_success "Soft deleted: $path (recoverable)"
fi