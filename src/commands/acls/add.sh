#!/bin/bash

# acls_add_command.sh - Merge user IDs into existing ACL arrays
#
# This command merges additional user IDs into the existing ACL arrays
# without disturbing existing entries. Use this to add readers or editors
# while preserving the current access list.
#
# Usage Examples:
#   echo '{"access_read": ["user-5"]}' | monk acls add users user-123
#   echo '{"access_edit": ["user-6", "user-7"]}' | monk acls add products prod-456
#
# Input Format (JSON via stdin):
#   {
#     "access_read": ["uuid-to-add"],
#     "access_edit": ["uuid-to-add"],
#     "access_full": ["uuid-to-add"],
#     "access_deny": ["uuid-to-add"]
#   }
#
# Note: Only include the arrays you want to modify. Omitted arrays
# are left unchanged.
#
# API Endpoint:
#   POST /api/acls/:model/:record

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
    print_info "Usage: echo '{\"access_read\": [\"user-id\"]}' | monk acls add $model $id"
    exit 1
fi

json_data=$(cat)

# Validate JSON
if ! echo "$json_data" | jq . >/dev/null 2>&1; then
    print_error "Invalid JSON input"
    exit 1
fi

print_info "Adding to ACLs for record: $model/$id"

# Make the ACLs request
response=$(make_request_json "POST" "/api/acls/$model/$id" "$json_data")

# Use standard response handler
handle_response_json "$response" "acls"
