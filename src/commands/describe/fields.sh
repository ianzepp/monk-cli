#!/bin/bash

# describe_columns_command.sh - List all fields in a model
#
# This command lists all field definitions for a specific model.
#
# Usage Examples:
#   monk describe columns users                # List all fields in users model
#   monk --format=yaml describe columns users  # List fields as YAML
#   monk --format=csv describe columns users   # List fields as CSV
#
# Output Format:
#   - Controlled by --format flag (or API default)
#   - Returns array of field definitions
#   - Each field includes type, constraints, validation rules
#
# API Endpoint:
#   GET /api/describe/:model/fields

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[model]}"

# Validate schema name
if [ -z "$schema" ]; then
    print_error "Schema name is required"
    exit 1
fi

print_info "Listing fields for model: $schema"

response=$(make_request_json "GET" "/api/describe/$schema/fields" "")

# Output response directly (API handles formatting)
echo "$response"
