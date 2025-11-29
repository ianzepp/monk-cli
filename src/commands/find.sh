#!/bin/bash

# find_command.sh - Advanced search with enterprise Filter DSL
#
# This command performs complex searches using the enterprise Filter DSL with support
# for advanced filtering, nested queries, and result limiting options.
#
# Usage Examples:
#   echo '{"where": {"name": {"$like": "john*"}}}' | monk find users
#   echo '{"where": {"age": {"$gt": 25}}, "limit": 10}' | monk find users
#   echo '{"where": {"$and": [{"status": "active"}, {"role": "admin"}]}}' | monk find users --head
#   cat complex-query.json | monk find documents --tail
#
# Filter DSL Support:
#   - Comparison operators: $eq, $ne, $gt, $gte, $lt, $lte
#   - Array operators: $in, $nin, $any, $nany  
#   - Pattern matching: $like, $ilike (case-insensitive)
#   - Logical operators: $and, $or, $not
#   - Range operators: $between
#   - Nested object queries and complex expressions
#
# Output Options:
#   --head/-H: Return only the first record from results
#   --tail/-T: Return only the last record from results
#   (default): Return all matching records
#
# API Endpoint:
#   POST /api/find/:schema (with Filter DSL JSON payload)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[model]}"
head_flag="${args[--head]}"
tail_flag="${args[--tail]}"

validate_schema "$schema"

# Read and validate JSON input (Filter DSL)
json_data=$(read_and_validate_json_input "searching" "$schema")

# For binary formats (sqlite, msgpack, etc.), stream directly to stdout
# Note: --head and --tail options are ignored for binary formats
if is_binary_format; then
    if [ "$head_flag" = "true" ] || [ "$tail_flag" = "true" ]; then
        print_info "Note: --head/--tail options ignored for binary formats"
    fi
    make_request_raw "POST" "/api/find/$schema" "$json_data"
    exit 0
fi

# Make the find request (text formats)
response=$(make_request_json "POST" "/api/find/$schema" "$json_data")

# Process response with head/tail support
if [ "$head_flag" = "true" ]; then
    # Extract first record from array
    print_info "Returning first record only"
    if [ "$JSON_PARSER" = "jq" ]; then
        if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
            first_record=$(echo "$response" | jq '.data[0] // null')
            echo "$response" | jq --argjson first "$first_record" '{"success": .success, "data": $first}'
        else
            echo "$response"
        fi
    else
        # Fallback for jshon or no parser
        if echo "$response" | grep -q '"success":true'; then
            first_record=$(echo "$response" | jshon -e data -e 0 2>/dev/null || echo "null")
            if [ "$first_record" != "null" ]; then
                echo "{\"success\":true,\"data\":$first_record}"
            else
                echo '{"success":true,"data":null}'
            fi
        else
            echo "$response"
        fi
    fi
elif [ "$tail_flag" = "true" ]; then
    # Extract last record from array
    print_info "Returning last record only"
    if [ "$JSON_PARSER" = "jq" ]; then
        if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
            last_record=$(echo "$response" | jq '.data[-1] // null')
            echo "$response" | jq --argjson last "$last_record" '{"success": .success, "data": $last}'
        else
            echo "$response"
        fi
    else
        # Fallback for jshon or no parser
        if echo "$response" | grep -q '"success":true'; then
            array_length=$(echo "$response" | jshon -e data -l 2>/dev/null || echo "0")
            if [ "$array_length" -gt 0 ]; then
                last_index=$((array_length - 1))
                last_record=$(echo "$response" | jshon -e data -e "$last_index" 2>/dev/null || echo "null")
                echo "{\"success\":true,\"data\":$last_record}"
            else
                echo '{"success":true,"data":null}'
            fi
        else
            echo "$response"
        fi
    fi
else
    # Use standard response handler
    handle_response_json "$response" "find"
fi