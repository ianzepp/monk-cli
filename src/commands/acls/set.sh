#!/bin/bash

# acls_set_command.sh - Replace all ACL arrays for a record
#
# This command completely replaces the ACL arrays for a specific record.
# Use this when you need to set the exact list of users for each access level.
#
# Usage Examples:
#   echo '{"access_read": ["user-1", "user-2"], "access_edit": ["user-3"]}' | monk acls set users user-123
#   cat acls.json | monk acls set products prod-456
#
# Input Format (JSON via stdin):
#   {
#     "access_read": ["uuid1", "uuid2"],
#     "access_edit": ["uuid3"],
#     "access_full": ["uuid4"],
#     "access_deny": []
#   }
#
# API Endpoint:
#   PUT /api/acls/:model/:record

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

# Read JSON data from stdin
if [ -t 0 ]; then
    print_error "No JSON data provided on stdin"
    print_info "Usage: echo '{\"access_read\": [\"user-id\"]}' | monk acls set $model $id"
    exit 1
fi

json_data=$(cat)

# Validate JSON
if ! echo "$json_data" | jq . >/dev/null 2>&1; then
    print_error "Invalid JSON input"
    exit 1
fi

print_info "Setting ACLs for record: $model/$id"

# Make the ACLs request
response=$(make_request_json "PUT" "/api/acls/$model/$id" "$json_data")

# Use standard response handler
handle_response_json "$response" "acls"
