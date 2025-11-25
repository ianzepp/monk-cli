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
#   PUT /api/describe/:model                 (update model)
#   PUT /api/describe/:model/fields/:field   (update field)

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
    # Field operation
    print_info "Updating field '$column' in model '$schema'"
    if [ "$CLI_VERBOSE" = "true" ]; then
        echo "$data" | jq . | sed 's/^/  /'
    fi

    response=$(make_request_json "PUT" "/api/describe/$schema/fields/$column" "$data")
else
    # Model operation
    print_info "Updating model '$schema'"
    if [ "$CLI_VERBOSE" = "true" ]; then
        echo "$data" | jq . | sed 's/^/  /'
    fi

    response=$(make_request_json "PUT" "/api/describe/$schema" "$data")
fi

# Output response directly (API handles formatting)
echo "$response"
