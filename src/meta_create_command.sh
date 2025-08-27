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
type="${args[type]}"

# Validate metadata type (currently only schema supported)
case "$type" in
    schema)
        # Valid type
        ;;
    *)
        print_error "Unsupported metadata type: $type"
        print_info "Currently supported types: schema"
        exit 1
        ;;
esac

# Read YAML data from stdin
data=$(cat)

if [ -z "$data" ]; then
    print_error "No YAML data provided on stdin"
    print_info "Usage: cat schema.yaml | monk meta create schema"
    exit 1
fi

print_info "Creating $type with YAML data:"
if [ "$CLI_VERBOSE" = "true" ]; then
    echo "$data" | sed 's/^/  /'
fi

response=$(make_request_yaml "POST" "/api/meta/$type" "$data")
handle_response_yaml "$response" "create"