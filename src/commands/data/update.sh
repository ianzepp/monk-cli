#!/bin/bash

# data_update_command.sh - Update records with flexible ID handling
#
# This command updates existing records with multiple input patterns:
# - ID as parameter: uses object endpoint, removes ID from JSON payload
# - ID extracted from JSON: uses object endpoint for single updates
# - Array input: uses array endpoint for bulk updates
#
# Usage Examples:
#   echo '{"name": "Updated Name"}' | monk data update users 123  # ID as param
#   echo '{"id": 123, "name": "Updated Name"}' | monk data update users  # ID in JSON  
#   echo '[{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]' | monk data update users  # Bulk
#
# API Endpoints:
#   PUT /api/data/:schema/:id  (single record - ID from parameter or extracted)
#   PUT /api/data/:schema      (bulk update - array input)
#
# ID Handling:
#   - Parameter ID takes precedence over JSON ID
#   - JSON ID automatically extracted when parameter omitted
#   - ID removed from payload for object endpoints (API requirement)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[model]}"
id="${args[id]}"

# Data commands only support JSON format
if [[ "${args[--text]}" == "1" ]]; then
    print_error "The --text option is not supported for data operations"
    print_info "Data operations require JSON format for structured data handling"
    exit 1
fi

validate_schema "$schema"

# Read and validate JSON input
json_data=$(read_and_validate_json_input "updating" "$schema")

# Process the update operation
process_data_operation "update" "PUT" "$schema" "$id" "$json_data"