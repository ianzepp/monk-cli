#!/bin/bash

# describe_select_command.sh - Retrieve specific schema definition  
#
# This command retrieves the complete YAML schema definition for a named schema.
# Returns the full schema specification including validation rules, properties, and metadata.
#
# Usage Examples:
#   monk describe select schema users           # Get users schema definition
#   monk describe select schema products > products.yaml  # Save schema to file
#
# Output Format:
#   - Returns complete YAML schema definition
#   - Includes JSON Schema validation rules, properties, required fields
#   - Contains metadata like title, description, and custom attributes
#
# API Endpoint:
#   GET /api/describe/:name (returns JSON schema content)

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

print_info "Selecting schema: $schema"

response=$(make_request_json "GET" "/api/describe/$schema" "")

# Handle response based on output format
if [[ "$output_format" == "json" ]]; then
    # JSON format - use standard handler (compact output)
    handle_response_json "$response" "select"
else
    # Text format - pretty-print the schema for readability
    if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
        echo "$response" | jq -r '.data' | jq .
    else
        handle_response_json "$response" "select"
    fi
fi
