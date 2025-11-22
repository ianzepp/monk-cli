#!/bin/bash

# describe_columns_command.sh - List all columns in a schema
#
# This command lists all column definitions for a specific schema.
#
# Usage Examples:
#   monk describe columns users                # List all columns in users schema
#   monk --format=yaml describe columns users  # List columns as YAML
#   monk --format=csv describe columns users   # List columns as CSV
#
# Output Format:
#   - Controlled by --format flag (or API default)
#   - Returns array of column definitions
#   - Each column includes type, constraints, validation rules
#
# API Endpoint:
#   GET /api/describe/:schema/columns

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"

# Validate schema name
if [ -z "$schema" ]; then
    print_error "Schema name is required"
    exit 1
fi

print_info "Listing columns for schema: $schema"

response=$(make_request_json "GET" "/api/describe/$schema/columns" "")

# Output response directly (API handles formatting)
echo "$response"
