#!/bin/bash

# describe_update_command.sh - Update existing schema or column definition
#
# This command updates an existing schema or column with a new JSON definition.
#
# Usage Examples:
#   # Update schema
#   echo '{"status":"active"}' | monk describe update users
#
#   # Update column
#   echo '{"required":true,"description":"Updated"}' | monk describe update users name
#
# Input Format:
#   - JSON definition via stdin
#   - Schema: can update status, description, sudo, freeze, immutable
#   - Column: can update any column properties
#
# API Endpoints:
#   PUT /api/describe/:schema                 (update schema)
#   PUT /api/describe/:schema/columns/:column (update column)

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

# Read input data from stdin
data=$(cat)

if [ -z "$data" ]; then
    print_error "No JSON data provided on stdin"
    if [ -n "$column" ]; then
        print_info "Usage: echo '{\"required\":true}' | monk describe update $schema $column"
    else
        print_info "Usage: echo '{\"status\":\"active\"}' | monk describe update $schema"
    fi
    exit 1
fi

# Validate JSON input
if ! echo "$data" | jq . >/dev/null 2>&1; then
    print_error "Invalid JSON input"
    exit 1
fi

# Determine endpoint based on arguments
if [ -n "$column" ]; then
    # Column operation
    print_info "Updating column '$column' in schema '$schema'"
    if [ "$CLI_VERBOSE" = "true" ]; then
        echo "$data" | jq . | sed 's/^/  /'
    fi

    response=$(make_request_json "PUT" "/api/describe/$schema/columns/$column" "$data")
else
    # Schema operation
    print_info "Updating schema '$schema'"
    if [ "$CLI_VERBOSE" = "true" ]; then
        echo "$data" | jq . | sed 's/^/  /'
    fi

    response=$(make_request_json "PUT" "/api/describe/$schema" "$data")
fi

# Output response directly (API handles formatting)
echo "$response"
