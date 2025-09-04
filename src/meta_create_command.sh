#!/bin/bash

# meta_create_command.sh - Create new schema from YAML definition
#
# This command creates a new schema in the database from a YAML schema definition.
# The schema definition includes JSON Schema validation rules and generates database DDL.
#
# Usage Examples:
#   cat users.yaml | monk meta create schema           # Create from file
#   echo "name: test..." | monk meta create schema     # Create from inline YAML
#
# Input Format:
#   - YAML schema definition via stdin
#   - Must include 'name' field for schema identification  
#   - Supports full JSON Schema specification (type, properties, required, etc.)
#   - Optional metadata (title, description)
#
# Schema Processing:
#   - Validates YAML syntax and schema structure
#   - Generates PostgreSQL table DDL automatically
#   - Creates schema cache entry for performance
#   - Prevents modification of system schemas
#
# API Endpoint:
#   POST /api/meta/schema (Content-Type: application/yaml)

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
    print_info "Usage: cat schema.json | monk meta create <schema-name>"
    print_info "       echo '{...}' | monk meta create <schema-name>"
    exit 1
fi

# Validate JSON input
if ! echo "$data" | jq . >/dev/null 2>&1; then
    print_error "Invalid JSON input"
    print_info "Meta commands require valid JSON schema definitions"
    exit 1
fi

print_info "Creating schema '$schema' with JSON data:"
if [ "$CLI_VERBOSE" = "true" ]; then
    echo "$data" | jq . | sed 's/^/  /'
fi

response=$(make_request_json "POST" "/api/meta/$schema" "$data")
handle_response_json "$response" "create"
