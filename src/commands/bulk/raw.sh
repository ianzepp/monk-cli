#!/bin/bash

# bulk_raw_command.sh - Execute bulk operations immediately (synchronous)
#
# This command executes an array of bulk operations in a single API transaction.
# All operations are processed sequentially and results returned immediately.
#
# Usage Examples:
#   cat operations.json | monk bulk raw
#   echo '[{"operation": "create", "schema": "users", "data": {...}}]' | monk bulk raw
#
# Input Format - Array of operation objects:
#   [
#     {
#       "operation": "create",        // Required: operation type
#       "schema": "users",            // Required: schema name
#       "data": {"name": "Alice"},    // Optional: record data
#       "id": "123",                  // Optional: record ID
#       "filter": {"status": "active"}, // Optional: filter criteria
#       "message": "Custom error"     // Optional: custom error message
#     }
#   ]
#
# Supported Operations:
#   Read: select, select-all, select-one, select-404, count
#   Write: create, create-one, create-all, update, update-one, update-all, update-any, update-404
#   Write: delete, delete-one, delete-all, delete-any, delete-404
#   Access: access, access-one, access-all, access-any, access-404
#   (upsert operations not yet implemented in API)
#
# Output Format:
#   Returns same array with 'result' field added to each operation containing the operation outcome
#
# API Endpoint:
#   POST /api/bulk (with operations array)
#
# Future Extensions:
#   This 'raw' command provides immediate execution. Future async commands:
#   - monk bulk submit (get operation ID)
#   - monk bulk status <id> (check progress)  
#   - monk bulk result <id> (download results)

# Check dependencies
check_dependencies

# Read and validate JSON input
json_data=$(read_and_validate_json_input "executing bulk operations" "multiple schemas")

# Validate that input is an array
input_type=$(detect_input_type "$json_data")

if [ "$input_type" != "array" ]; then
    print_error "Bulk operations require an array of operation objects"
    print_info "Usage: cat operations.json | monk bulk raw"
    print_info "Expected format: [{\"operation\": \"create\", \"schema\": \"users\", \"data\": {...}}]"
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

# Execute bulk operations via API
response=$(make_request_json "POST" "/api/bulk" "$json_data")

# Handle response - return full operations array with results
handle_response_json "$response" "bulk"