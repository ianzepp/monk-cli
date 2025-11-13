#!/bin/bash

# bulk_command.sh - Execute multiple operations in a single transaction
#
# This command executes an array of bulk operations in a single API transaction.
# All operations are processed sequentially and results returned immediately.
#
# Usage Examples:
#   cat operations.json | monk bulk
#   echo '[{"operation": "create-one", "schema": "users", "data": {...}}]' | monk bulk
#
# Input Format - Array of operation objects:
#   [
#     {
#       "operation": "create-one",    // Required: operation type (hyphenated)
#       "schema": "users",            // Required: schema name
#       "data": {"name": "Alice"},    // Required for mutations (object or array)
#       "id": "user-123",             // Required for single-record operations
#       "filter": {...},              // Required for *-any variants
#       "aggregate": {...},           // Required for aggregate operations
#       "groupBy": ["field"],         // Optional for aggregate
#       "message": "Custom error"     // Optional: custom 404 message
#     }
#   ]
#
# Supported Operations:
#   Read Helpers:
#     - select, select-all, select-one, select-404, count, aggregate
#   Create:
#     - create, create-one, create-all
#   Update:
#     - update, update-one, update-all, update-any, update-404
#   Delete (soft delete):
#     - delete, delete-one, delete-all, delete-any, delete-404
#   Access Control:
#     - access, access-one, access-all, access-any, access-404
#
# API Request Format:
#   POST /api/bulk
#   {"operations": [...]}
#
# API Response Format:
#   {"success": true, "data": [{operation result}, ...]}
#
# Transaction Behavior:
#   All operations execute in a single transaction. On error, the entire
#   transaction rolls back - no partial writes are persisted.

# Check dependencies
check_dependencies

# Read and validate JSON input
json_data=$(read_and_validate_json_input "executing bulk operations" "multiple schemas")

# Validate that input is an array
input_type=$(detect_input_type "$json_data")

if [ "$input_type" != "array" ]; then
    print_error "Bulk operations require an array of operation objects"
    print_info "Usage: cat operations.json | monk bulk"
    print_info "Expected format: [{\"operation\": \"create-one\", \"schema\": \"users\", \"data\": {...}}]"
    exit 1
fi

# Validate basic structure of operations (best effort)
if [ "$JSON_PARSER" = "jq" ]; then
    # Check that all items have required operation and schema fields
    missing_fields=$(echo "$json_data" | jq -r '.[] | select(.operation == null or .schema == null) | "missing operation or schema"' 2>/dev/null)
    
    if [ -n "$missing_fields" ]; then
        print_error "One or more operations missing required 'operation' and 'schema' fields"
        exit 1
    fi
    
    # Count operations for user feedback
    op_count=$(echo "$json_data" | jq 'length' 2>/dev/null || echo "unknown")
    print_info "Executing $op_count bulk operations"
fi

# Wrap operations array in {"operations": [...]} for new API format
wrapped_payload=$(echo "$json_data" | jq '{operations: .}')

# Execute bulk operations via API
response=$(make_request_json "POST" "/api/bulk" "$wrapped_payload")

# Handle response - extract data array from {"success": true, "data": [...]}
if [ "$JSON_PARSER" = "jq" ]; then
    if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
        # Success - extract data array
        echo "$response" | jq '.data'
    else
        # Error - show full response
        handle_response_json "$response" "bulk"
    fi
else
    # Fallback for non-jq parsers
    handle_response_json "$response" "bulk"
fi