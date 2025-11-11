#!/bin/bash

# describe_create_command.sh - Create new schema from JSON definition
#
# This command creates a new schema in the database from a JSON schema definition.
# The schema definition includes JSON Schema validation rules and automatically
# generates database DDL.
#
# Usage Examples:
#   cat schema.json | monk describe create products    # Create from file
#   echo '{...}' | monk describe create users          # Create from inline JSON
#
# Input Format:
#   - JSON schema definition via stdin
#   - Must include 'title' field for schema identification
#   - Supports full JSON Schema specification (type, properties, required, etc.)
#   - Optional metadata (description, examples)
#
# Schema Processing:
#   - Validates JSON syntax and schema structure
#   - Generates PostgreSQL table DDL automatically
#   - Creates schema cache entry for performance
#   - Prevents modification of system schemas
#
# API Endpoint:
#   POST /api/describe/:name (Content-Type: application/json)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"

# Determine output format from global flags
output_format=$(get_output_format "text")

# Validate schema name
if [ -z "$schema" ]; then
    print_error "Schema name is required"
    exit 1
fi

# Read input data from stdin
data=$(cat)

if [ -z "$data" ]; then
    print_error "No schema data provided on stdin"
    print_info "Usage: cat schema.json | monk describe create <schema-name>"
    print_info "       echo '{...}' | monk describe create <schema-name>"
    exit 1
fi

# Validate JSON input
if ! echo "$data" | jq . >/dev/null 2>&1; then
    print_error "Invalid JSON input"
    print_info "Describe create requires valid JSON schema definitions"
    exit 1
fi

# Validate that JSON has required title field
if ! echo "$data" | jq -e '.title' >/dev/null 2>&1; then
    print_error "JSON schema must have a 'title' field"
    print_info "Example: {\"title\": \"$schema\", \"properties\": {...}}"
    exit 1
fi

print_info "Creating schema '$schema' with JSON data:"
if [ "$CLI_VERBOSE" = "true" ]; then
    echo "$data" | jq . | sed 's/^/  /'
fi

response=$(make_request_json "POST" "/api/describe/$schema" "$data")
handle_response_json "$response" "create"