#!/bin/bash

# describe_update_command.sh - Update existing schema definition
#
# This command updates an existing schema with a new JSON definition.
# Changes are applied to both the schema definition and underlying database table structure.
# Supports additive changes safely, but breaking changes may affect existing data.
#
# Usage Examples:
#   cat updated-schema.json | monk describe update users     # Update from file
#   echo '{...}' | monk describe update products             # Update with inline JSON
#
# Input Format:
#   - JSON schema definition via stdin
#   - Must include 'title' field matching the schema name
#   - Supports full JSON Schema specification
#   - Additive changes (new fields) are generally safe
#   - Breaking changes (removing required fields) may affect existing data
#
# Update Behavior:
#   - Validates new schema definition
#   - Compares with existing schema for compatibility
#   - Updates PostgreSQL table structure (ADD/DROP columns as needed)
#   - Preserves existing data where possible
#   - System schemas cannot be modified
#
# API Endpoint:
#   PUT /api/describe/:name (Content-Type: application/json)

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
    print_info "Usage: cat schema.json | monk describe update <schema-name>"
    print_info "       echo '{...}' | monk describe update <schema-name>"
    exit 1
fi

# Validate JSON input
if ! echo "$data" | jq . >/dev/null 2>&1; then
    print_error "Invalid JSON input"
    print_info "Describe update requires valid JSON schema definitions"
    exit 1
fi

# Validate that JSON has required title field and it matches the schema name
json_title=$(echo "$data" | jq -r '.title // empty')
if [ -z "$json_title" ]; then
    print_error "JSON schema must have a 'title' field"
    print_info "Example: {\"title\": \"$schema\", \"properties\": {...}}"
    exit 1
fi

if [ "$json_title" != "$schema" ]; then
    print_warning "JSON title '$json_title' does not match schema name '$schema'"
    print_info "For safety, the JSON title should match the schema name being updated"
fi

print_info "Updating schema '$schema' with JSON data:"
if [ "$CLI_VERBOSE" = "true" ]; then
    echo "$data" | jq . | sed 's/^/  /'
fi

response=$(make_request_json "PUT" "/api/describe/$schema" "$data")
handle_response_json "$response" "update"