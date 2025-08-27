#!/bin/bash

# fs_rm_command.sh - Remove files, records, or fields via FTP middleware

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
force_flag="${args[--force]}"

print_info "Removing: $path"

# Build FTP options based on flags
permanent="false"
if [ "$force_flag" = "true" ]; then
    permanent="true"
    print_warning "Permanent deletion requested (not recoverable)"
else
    print_info "Using soft delete (recoverable)"
fi

# Build FTP options
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

# Build payload and make request
payload=$(build_ftp_payload "$path" "$ftp_options")
response=$(make_ftp_request "delete" "$payload")

# Process deletion result
operation=$(process_ftp_response "$response" "operation")
result=$(process_ftp_response "$response" "result")

if [ "$permanent" = "true" ]; then
    print_success "Permanently deleted: $path"
else
    print_success "Soft deleted: $path (recoverable)"
fi

# Show operation details in verbose mode
if [ "$CLI_VERBOSE" = "true" ] && [ -n "$result" ] && [ "$result" != "null" ]; then
    record_id=$(echo "$result" | jq -r '.record_id // empty' 2>/dev/null)
    if [ -n "$record_id" ] && [ "$record_id" != "null" ] && [ "$record_id" != "empty" ]; then
        print_info "Record ID: $record_id"
    fi
fi