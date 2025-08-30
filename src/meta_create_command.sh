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

# Meta commands only support YAML format
if [[ "${args[--text]}" == "1" ]]; then
    print_error "The --text option is not supported for meta operations"
    print_info "Meta operations work with YAML schema definitions"
    exit 1
fi

if [[ "${args[--json]}" == "1" ]]; then
    print_error "The --json option is not supported for meta operations"
    print_info "Meta operations work with YAML schema definitions"
    exit 1
fi

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

# Read input data from stdin
data=$(cat)

if [ -z "$data" ]; then
    print_error "No schema data provided on stdin"
    print_info "Usage: cat schema.yaml | monk meta create schema"
    print_info "       cat schema.json | monk meta create schema  # Auto-converts to YAML"
    exit 1
fi

# Detect input format and handle autoconversion
input_format=$(detect_input_format "$data")

print_info "Creating $type with ${input_format^^} data:"
if [ "$CLI_VERBOSE" = "true" ]; then
    echo "$data" | sed 's/^/  /'
fi

response=$(make_request_yaml_autodetect "POST" "/api/meta/$type" "$data" "$input_format")
handle_response_yaml_autodetect "$response" "create" "$input_format"