#!/bin/bash

# describe_create_command.sh - Create new schema or add column from JSON definition
#
# This command creates a new schema or adds a column to an existing schema.
#
# Usage Examples:
#   # Create schema
#   echo '{"schema_name":"users","status":"pending"}' | monk describe create users
#
#   # Add column
#   echo '{"type":"text","required":true}' | monk describe create users name
#
# Input Format:
#   - JSON definition via stdin
#   - Schema: requires schema_name field
#   - Column: requires type field
#
# API Endpoints:
#   POST /api/describe/:model                 (create model)
#   POST /api/describe/:model/fields/:field   (add field)

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
        print_info "Usage: echo '{\"type\":\"text\"}' | monk describe create $schema $column"
    else
        print_info "Usage: echo '{\"schema_name\":\"$schema\"}' | monk describe create $schema"
    fi
    exit 1
fi

# Validate JSON input
if ! echo "$data" | jq . >/dev/null 2>&1; then
    print_error "Invalid JSON input"
    exit 1
fi

# Determine endpoint and validation based on arguments
if [ -n "$column" ]; then
    # Field operation - validate type field
    if ! echo "$data" | jq -e '.type' >/dev/null 2>&1; then
        print_error "Field definition must have a 'type' field"
        print_info "Example: {\"type\": \"text\", \"required\": true}"
        exit 1
    fi

    print_info "Adding field '$column' to model '$schema'"
    if [ "$CLI_VERBOSE" = "true" ]; then
        echo "$data" | jq . | sed 's/^/  /'
    fi

    response=$(make_request_json "POST" "/api/describe/$schema/fields/$column" "$data")
else
    # Model operation - validate model_name field
    if ! echo "$data" | jq -e '.model_name' >/dev/null 2>&1; then
        print_error "Model definition must have a 'model_name' field"
        print_info "Example: {\"model_name\": \"$schema\", \"status\": \"pending\"}"
        exit 1
    fi

    print_info "Creating model '$schema'"
    if [ "$CLI_VERBOSE" = "true" ]; then
        echo "$data" | jq . | sed 's/^/  /'
    fi

    response=$(make_request_json "POST" "/api/describe/$schema" "$data")
fi

# Output response directly (API handles formatting)
echo "$response"
