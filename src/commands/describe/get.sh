#!/bin/bash

# describe_get_command.sh - Retrieve schema or column definition
#
# This command retrieves either a complete schema definition or a specific column definition.
#
# Usage Examples:
#   monk describe get users                    # Get complete schema definition
#   monk describe get users name               # Get specific column definition
#   monk describe get products > products.json # Save schema to file
#
# Output Format:
#   - Returns JSON schema or column definition
#   - Schema includes all columns and metadata
#   - Column includes type, constraints, validation rules
#
# API Endpoints:
#   GET /api/describe/:schema                 (get schema)
#   GET /api/describe/:schema/columns/:column (get column)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"
column="${args[column]:-}"

# Validate schema name
if [ -z "$schema" ]; then
    print_error "Schema name is required"
    exit 1
fi

# Determine endpoint based on arguments
if [ -n "$column" ]; then
    # Column operation
    print_info "Getting column: $schema.$column"
    response=$(make_request_json "GET" "/api/describe/$schema/columns/$column" "")
else
    # Schema operation
    print_info "Getting schema: $schema"
    response=$(make_request_json "GET" "/api/describe/$schema" "")
fi

# Output response directly (API handles formatting)
echo "$response"
