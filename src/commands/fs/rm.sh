#!/bin/bash

# fs_rm_command.sh - Remove files with multi-tenant support

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
force_flag="${args[--force]}"
tenant_flag="${args[--tenant]}"

print_info "Removing: $path"

# Build file options based on flags - Using /api/file/delete endpoint
permanent="false"
if [ "$force_flag" = "true" ]; then
    permanent="true"
    print_warning "Permanent deletion requested (not recoverable)"
else
    print_info "Using soft delete (recoverable)"
fi

file_options=$(jq -n \
    --argjson permanent "$permanent" \
    '{
        "recursive": false,
        "force": false,
        "permanent": $permanent,
        "atomic": true
    }')

safety_checks=$(jq -n \
    '{
        "require_empty": false,
        "max_deletions": 100
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

# Build deletion payload with safety_checks
deletion_payload=$(jq -n \
    --arg path "$path" \
    --argjson file_options "$file_options" \
    --argjson safety_checks "$safety_checks" \
    '{
        "path": $path,
        "file_options": $file_options,
        "safety_checks": $safety_checks
    }')

# Make request - delete endpoint requires custom payload
response=$(make_request_json "POST" "/api/file/delete" "$deletion_payload")

# Process deletion result
operation=$(process_file_response "$response" "operation")
deleted_count=$(process_file_response "$response" "results.deleted_count")

if [ "$permanent" = "true" ]; then
    print_success "Permanently deleted: $path"
else
    print_success "Soft deleted: $path (recoverable)"
fi

# Show additional deletion details if available
if [ -n "$deleted_count" ] && [ "$deleted_count" != "null" ] && [ "$deleted_count" != "0" ]; then
    print_info "Deleted count: $deleted_count"
fi