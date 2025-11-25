#!/bin/bash

# acls_get_command.sh - Get current ACL arrays for a record
#
# This command retrieves the effective ACL arrays for a specific record,
# showing which users have read, edit, full, or denied access.
#
# Usage Examples:
#   monk acls get users user-123              # Get ACLs for user record
#   monk --json acls get products prod-456    # JSON output
#
# Output Fields:
#   - record_id: The record identifier
#   - model: The model name
#   - access_lists:
#     - access_read: User IDs with read access
#     - access_edit: User IDs with edit access
#     - access_full: User IDs with full access (read/edit/delete)
#     - access_deny: User IDs with denied access (overrides others)
#
# API Endpoint:
#   GET /api/acls/:model/:record

# Check dependencies
check_dependencies

# Get arguments from bashly
model="${args[model]}"
id="${args[id]}"

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

print_info "Getting ACLs for record: $model/$id"

# Make the ACLs request
response=$(make_request_json "GET" "/api/acls/$model/$id" "")

# Use standard response handler
handle_response_json "$response" "acls"
