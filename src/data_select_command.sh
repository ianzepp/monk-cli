#!/bin/bash

# data_select_command.sh - Unified data selection with intelligent query routing
#
# This command handles all data selection scenarios with flexible input:
# 1. Direct ID selection for single records
# 2. Default listing when no parameters provided  
# 3. Simple query parameters via JSON (limit, order, offset)
# 4. Complex queries automatically redirected to 'find' command
#
# Usage Examples:
#   monk data select users 123                    # Get specific user by ID
#   monk data select users                        # List all users (default)
#   echo '{"limit": 10}' | monk data select users           # Limit results
#   echo '{"order": "name asc"}' | monk data select users   # Sort by name
#   echo '{"limit": 5, "offset": 10}' | monk data select users  # Pagination
#   echo '{"where": {"status": "active"}}' | monk data select users  # → Redirects to find
#
# API Endpoints:
#   GET /api/data/:schema/:id     (direct ID)
#   GET /api/data/:schema         (default listing)
#   GET /api/data/:schema?params  (with query string)
#
# Complex Query Redirection:
#   JSON with 'where' field automatically redirects to 'monk find :schema'
#   for advanced filtering capabilities using the enterprise Filter DSL

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"
id="${args[id]}"

# Data commands only support JSON format
if [[ "${args[--text]}" == "1" ]]; then
    print_error "The --text option is not supported for data operations"
    print_info "Data operations require JSON format for structured data handling"
    exit 1
fi

validate_schema "$schema"

if [ -n "$id" ]; then
    # Case 1: ID provided - direct record selection
    print_info "Selecting specific record: $id"
    response=$(make_request_json "GET" "/api/data/$schema/$id" "")
    handle_response_json "$response" "select"
    
elif [ -t 0 ]; then
    # Case 2: No ID and no stdin (terminal input) - default listing
    print_info "Selecting all records for schema: $schema"
    response=$(make_request_json "GET" "/api/data/$schema" "")
    handle_response_json "$response" "select"
    
else
    # Case 3: No ID but have stdin - parse JSON for query parameters or complex queries
    json_data=$(read_and_validate_json_input "selecting" "$schema")
    
    if [ -z "$json_data" ]; then
        print_error "No JSON data provided on stdin"
        exit 1
    fi
    
    print_info "Processing query parameters for schema: $schema"
    if [ "$CLI_VERBOSE" = "true" ]; then
        echo "$json_data" | sed 's/^/  /'
    fi
    
    # Check if this is a complex query that should use find command
    if has_complex_query "$json_data"; then
        # Case 3a: Complex query with 'where' clause - redirect to find
        redirect_to_find "$schema" "$json_data"
    else
        # Case 3b: Simple query parameters - build query string
        query_string=$(build_query_string "$json_data")
        
        if [ -n "$query_string" ]; then
            print_info "Using query parameters: $query_string"
        else
            print_info "No valid query parameters found, using default selection"
        fi
        
        response=$(make_request_json "GET" "/api/data/$schema$query_string" "")
        handle_response_json "$response" "select"
    fi
fi