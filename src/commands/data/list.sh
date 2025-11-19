#!/bin/bash

# data_list_command.sh - List records with flexible query support
#
# This command handles listing records with optional query parameters:
# 1. Default listing when no parameters provided
# 2. Simple query parameters via --filter flag (limit, order, offset)
# 3. Complex queries should use 'monk find' command directly
#
# Usage Examples:
#   monk data list users                                 # List all users (default)
#   monk data list users --filter '{"limit": 10}'        # Limit results
#   monk data list users --filter '{"order": "name asc"}'  # Sort by name
#   monk data list users --filter '{"limit": 5, "offset": 10}'  # Pagination
#
# For single records, use:
#   monk data get users 123                              # Get specific user by ID
#
# For complex queries with 'where' clauses, use:
#   echo '{"where": {"status": "active"}}' | monk find users
#
# API Endpoints:
#   GET /api/data/:schema         (default listing)
#   GET /api/data/:schema?params  (with query string)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"
filter_json="${args[--filter]}"

# Data commands only support JSON format
if [[ "${args[--text]}" == "1" ]]; then
    print_error "The --text option is not supported for data operations"
    print_info "Data operations require JSON format for structured data handling"
    exit 1
fi

validate_schema "$schema"

if [ -n "$filter_json" ]; then
    # Filter provided - parse and build query string
    print_info "Processing query filter for schema: $schema"

    # Check if this is a complex query that should use find command
    if has_complex_query "$filter_json"; then
        print_error "Complex queries with 'where' clauses should use 'monk find' command"
        print_info "Example: echo '$filter_json' | monk find $schema"
        exit 1
    fi

    # Build query string from filter parameters
    query_string=$(build_query_string "$filter_json")

    if [ -n "$query_string" ]; then
        print_info "Using query parameters: $query_string"
    else
        print_info "No valid query parameters found, using default listing"
    fi

    response=$(make_request_json "GET" "/api/data/$schema$query_string" "")
    handle_response_json "$response" "list"

else
    # No filter - default listing
    print_info "Listing all records for schema: $schema"
    response=$(make_request_json "GET" "/api/data/$schema" "")
    handle_response_json "$response" "list"
fi