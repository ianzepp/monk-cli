#!/bin/bash

# data_get_command.sh - Get a single record by ID
#
# This command retrieves a specific record by its ID.
#
# Usage Example:
#   monk data get users 123                  # Get specific user by ID
#
# API Endpoint:
#   GET /api/data/:schema/:id

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[model]}"
id="${args[id]}"

validate_schema "$schema"

# Get specific record by ID
print_info "Getting record: $id"

# For binary formats (sqlite, msgpack, etc.), stream directly to stdout
if is_binary_format; then
    make_request_raw "GET" "/api/data/$schema/$id" ""
else
    response=$(make_request_json "GET" "/api/data/$schema/$id" "")
    printf '%s' "$response"
fi
