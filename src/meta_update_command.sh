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
type="${args[type]}"
name="${args[name]}"

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

# Read YAML data from stdin
data=$(cat)

if [ -z "$data" ]; then
    print_error "No YAML data provided on stdin"
    print_info "Usage: cat schema.yaml | monk meta update schema <name>"
    exit 1
fi

print_info "Updating $type '$name' with YAML data:"
if [ "$CLI_VERBOSE" = "true" ]; then
    echo "$data" | sed 's/^/  /'
fi

response=$(make_request_yaml "PUT" "/api/meta/$type/$name" "$data")
handle_response_yaml "$response" "update"