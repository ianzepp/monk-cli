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
#   GET /api/describe/:model                 (get model)
#   GET /api/describe/:model/fields/:field   (get field)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[model]}"
column="${args[field]:-}"

# Validate schema name
if [ -z "$schema" ]; then
    print_error "Schema name is required"
    exit 1
fi

# Determine endpoint based on arguments
if [ -n "$column" ]; then
    # Field operation
    print_info "Getting field: $schema.$column"
    response=$(make_request_json "GET" "/api/describe/$schema/fields/$column" "")
else
    # Schema operation
    print_info "Getting schema: $schema"
    response=$(make_request_json "GET" "/api/describe/$schema" "")
fi

# Output response directly (API handles formatting)
echo "$response"
