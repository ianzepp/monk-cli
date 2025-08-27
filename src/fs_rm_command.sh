#!/bin/bash

# fs_rm_command.sh - Remove files, records, or fields via FTP middleware
#
# This command provides filesystem-like deletion of API data through the FTP middleware,
# enabling familiar rm-style operations for records, fields, and schema elements.
#
# Usage Examples:
#   monk fs rm /data/users/user-123           # Soft delete record
#   monk fs rm /data/users/user-123 --force   # Permanent delete
#   monk fs rm /data/users/user-123/temp_field # Clear specific field
#   monk fs rm /meta/schema/old-schema        # Delete schema definition
#
# Deletion Types:
#   Records:     /data/users/user-123      → Soft delete by default
#   Fields:      /data/users/user-123/name → Clear field value  
#   Schemas:     /meta/schema/users        → Schema soft delete
#   Files:       /data/users/user-123.json → Same as record deletion
#
# Safety Features:
#   - Soft delete by default (recoverable)
#   - --force flag for permanent deletion
#   - Confirmation prompts for destructive operations
#   - Atomic operations with automatic rollback on failure
#
# Force Flag Behavior:
#   Default: permanent=false (soft delete, recoverable)
#   --force: permanent=true (hard delete, not recoverable)
#
# FTP Endpoint:
#   POST /ftp/delete with path and deletion options

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

# Build JSON payload for FTP delete endpoint
json_payload=$(cat <<EOF
{
  "path": "$path",
  "ftp_options": {
    "permanent": $permanent,
    "atomic": true,
    "force": false
  }
}
EOF
)

print_info "FTP delete request for path: $path"
if [ "$CLI_VERBOSE" = "true" ]; then
    echo "$json_payload" | sed 's/^/  /' >&2
fi

# Confirmation prompt for destructive operations
if [ "$force_flag" = "true" ] && [ "$CLI_VERBOSE" = "true" ]; then
    print_warning "Are you sure you want to permanently delete: $path? (y/N)"
    read -r confirmation
    
    if ! echo "$confirmation" | grep -E "^[Yy]$" >/dev/null 2>&1; then
        print_info_always "Operation cancelled"
        exit 0
    fi
fi

# Make request to FTP delete endpoint
response=$(make_request_json "POST" "/ftp/delete" "$json_payload")

# Process response
if [ "$JSON_PARSER" = "jq" ]; then
    # Check if request was successful
    if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
        operation=$(echo "$response" | jq -r '.operation // "delete"')
        
        if [ "$permanent" = "true" ]; then
            print_success "Permanently deleted: $path"
        else
            print_success "Soft deleted: $path (recoverable)"
        fi
        
        # Show operation details in verbose mode
        if [ "$CLI_VERBOSE" = "true" ]; then
            record_id=$(echo "$response" | jq -r '.result.record_id // empty')
            if [ -n "$record_id" ] && [ "$record_id" != "null" ] && [ "$record_id" != "empty" ]; then
                print_info "Record ID: $record_id"
            fi
        fi
    else
        # Show error response
        print_error "FTP delete request failed"
        echo "$response" >&2
        exit 1
    fi
else
    # Fallback without jq
    print_error "jq required for FTP operations"
    exit 1
fi