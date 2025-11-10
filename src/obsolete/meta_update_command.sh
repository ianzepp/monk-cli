#!/bin/bash

# meta_update_command.sh - Update existing schema with new YAML definition
#
# This command updates an existing schema with a new YAML definition.
# Automatically handles database DDL changes and schema cache invalidation.
#
# Usage Examples:
#   cat updated-users.yaml | monk meta update schema users    # Update from file
#   echo "name: users..." | monk meta update schema users     # Update with inline YAML
#
# Input Format:
#   - YAML schema definition via stdin
#   - Schema name must match existing schema or be provided in YAML 'name' field
#   - Full JSON Schema specification supported
#
# Update Process:
#   - Validates new schema definition
#   - Compares with existing schema for compatibility
#   - Updates PostgreSQL table DDL (ADD/DROP columns as needed)
#   - Invalidates and regenerates schema cache
#   - Preserves existing data where possible
#
# Safety Features:
#   - System schemas cannot be updated
#   - Destructive changes require data migration planning
#
# API Endpoint:
#   PUT /api/meta/schema/:name (Content-Type: application/yaml)

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
    print_info "Usage: cat schema.json | monk meta update <schema-name>"
    print_info "       echo '{...}' | monk meta update <schema-name>"
    exit 1
fi

# Validate JSON input
if ! echo "$data" | jq . >/dev/null 2>&1; then
    print_error "Invalid JSON input"
    print_info "Meta commands require valid JSON schema definitions"
    exit 1
fi

print_info "Updating schema '$schema' with JSON data:"
if [ "$CLI_VERBOSE" = "true" ]; then
    echo "$data" | jq . | sed 's/^/  /'
fi

response=$(make_request_json "PUT" "/api/meta/$schema" "$data")
handle_response_json "$response" "update"
