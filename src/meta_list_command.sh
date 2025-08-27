#!/bin/bash

# meta_list_command.sh - List all schemas in the current tenant
#
# This command lists all available schemas in the current tenant's database.
# Returns an array of schema names for discovery and validation purposes.
#
# Usage Examples:
#   monk meta list schema                    # List all schemas
#   monk meta list schema | jq '.[]'        # Pretty print each schema name
#
# Output Format:
#   - Returns JSON array of schema names
#   - Currently only supports 'schema' type (extensible for future metadata types)
#
# API Endpoint:
#   GET /api/meta/schema

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

if [ "$CLI_VERBOSE" = "true" ]; then
    print_info "Listing all $type objects"
fi

response=$(make_request_json "GET" "/api/meta/$type" "")
handle_response_json "$response" "list"