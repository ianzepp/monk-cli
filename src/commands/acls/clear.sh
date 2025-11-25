#!/bin/bash

# acls_clear_command.sh - Reset all ACL arrays to empty
#
# This command clears all ACL arrays so the record reverts to the model's
# default role-based permissions. This is the fastest way to undo manual
# ACL tweaks and let standard access tiers govern the record.
#
# Usage Examples:
#   monk acls clear users user-123           # Interactive confirmation
#   monk acls clear users user-123 --force   # Skip confirmation
#
# Warning: This removes all explicit access grants and denials.
# The record will fall back to role-based defaults.
#
# API Endpoint:
#   DELETE /api/acls/:model/:record

# Check dependencies
check_dependencies

# Get arguments from bashly
model="${args[model]}"
id="${args[id]}"
force="${args[--force]}"

# Validate model name
if [ -z "$model" ]; then
    print_error "Model name is required"
    exit 1
fi

# Validate record ID
if [ -z "$id" ]; then
    print_error "Record ID is required"
    exit 1
fi

# Confirm deletion unless --force is used
if [ "$force" != "1" ]; then
    echo
    print_warning "This will clear all ACL arrays for record: $model/$id"
    print_warning "The record will fall back to role-based defaults."
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        exit 0
    fi
fi

print_info "Clearing ACLs for record: $model/$id"

# Make the ACLs request
response=$(make_request_json "DELETE" "/api/acls/$model/$id" "")

# Use standard response handler
handle_response_json "$response" "acls"
