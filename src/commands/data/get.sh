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
schema="${args[schema]}"
id="${args[id]}"

# Data commands only support JSON format
if [[ "${args[--text]}" == "1" ]]; then
    print_error "The --text option is not supported for data operations"
    print_info "Data operations require JSON format for structured data handling"
    exit 1
fi

validate_schema "$schema"

# Get specific record by ID
print_info "Getting record: $id"
response=$(make_request_json "GET" "/api/data/$schema/$id" "")
handle_response_json "$response" "get"
