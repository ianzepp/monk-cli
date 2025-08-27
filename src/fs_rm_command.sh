#!/bin/bash

# fs_rm_command.sh - Remove files with multi-tenant support

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
force_flag="${args[--force]}"
tenant_flag="${args[--tenant]}"

print_info "Removing: $path"

# Build FTP options based on flags
permanent="false"
if [ "$force_flag" = "true" ]; then
    permanent="true"
    print_warning "Permanent deletion requested (not recoverable)"
else
    print_info "Using soft delete (recoverable)"
fi

ftp_options=$(jq -n \
    --argjson permanent "$permanent" \
    '{
        "permanent": $permanent,
        "atomic": true,
        "force": false
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

# Make request with tenant routing
response=$(make_ftp_request_with_routing "delete" "$path" "$ftp_options" "$tenant_flag")

# Process deletion result
if [ "$permanent" = "true" ]; then
    print_success "Permanently deleted: $path"
else
    print_success "Soft deleted: $path (recoverable)"
fi