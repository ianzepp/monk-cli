#!/bin/bash

# describe_list_command.sh - List all available schema names
#
# This command retrieves all schema names available in the current tenant.
# Returns an array of schema names that can be queried with describe select.
#
# Usage Examples:
#   monk describe list                    # List all schemas
#   monk --json describe list             # JSON output format
#   monk --text describe list             # Raw text output
#
# Output Format:
#   - Text format: One schema name per line
#   - JSON format: Returns full API response with schema array
#
# API Endpoint:
#   GET /api/describe (returns array of schema names)

# Check dependencies
check_dependencies

# Determine output format from global flags
output_format=$(get_output_format "text")

print_info "Listing all available schemas"

response=$(make_request_json "GET" "/api/describe" "")

# Handle response based on output format
if [[ "$output_format" == "json" ]]; then
    # JSON format - use standard handler (full response)
    handle_response_json "$response" "list"
else
    # Text format - extract and display schema names one per line
    if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
        schema_count=$(echo "$response" | jq -r '.data | length')
        
        if [ "$schema_count" -eq 0 ]; then
            print_info "No schemas found"
        else
            echo "$response" | jq -r '.data[]'
        fi
    else
        handle_response_json "$response" "list"
    fi
fi
