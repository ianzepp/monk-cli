#!/bin/bash

# meta_select_command.sh - Retrieve specific schema definition  
#
# This command retrieves the complete YAML schema definition for a named schema.
# Returns the full schema specification including validation rules, properties, and metadata.
#
# Usage Examples:
#   monk meta select schema users           # Get users schema definition
#   monk meta select schema products > products.yaml  # Save schema to file
#
# Output Format:
#   - Returns complete YAML schema definition
#   - Includes JSON Schema validation rules, properties, required fields
#   - Contains metadata like title, description, and custom attributes
#
# API Endpoint:
#   GET /api/meta/schema/:name (returns YAML content)

# Check dependencies
check_dependencies

# Get arguments from bashly
type="${args[type]}"
name="${args[name]}"

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

print_info "Selecting $type object: $name"

response=$(make_request_yaml "GET" "/api/meta/$type/$name" "")
handle_response_yaml "$response" "select"