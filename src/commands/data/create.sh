#!/bin/bash

# data_create_command.sh - Create records with flexible input handling
#
# This command creates new records in a schema with intelligent array/object handling:
# - Single object input → wraps in array for API → unwraps response to match input
# - Array input → sends directly to API → returns array response  
#
# Usage Examples:
#   echo '{"name": "John", "email": "john@example.com"}' | monk data create users
#   cat user.json | monk data create users
#   echo '[{"name": "Alice"}, {"name": "Bob"}]' | monk data create users  # Bulk create
#
# Input/Output Behavior:
#   Object in → Object out (single record creation)
#   Array in → Array out (bulk record creation)  
#
# API Endpoint:
#   POST /api/data/:schema (always expects array, handles wrapping/unwrapping)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"

validate_schema "$schema"

# Read and validate JSON input
json_data=$(read_and_validate_json_input "creating" "$schema")

# Process the create operation (uses handle_response_json which now outputs compact JSON)
process_data_operation "create" "POST" "$schema" "" "$json_data"