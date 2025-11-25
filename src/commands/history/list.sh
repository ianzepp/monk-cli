#!/bin/bash

# history_list_command.sh - List all history entries for a record
#
# This command retrieves the audit trail for a specific record, showing all
# changes to tracked fields ordered by change_id (newest first).
#
# Usage Examples:
#   monk history list users user-123              # List all changes
#   monk history list users user-123 --limit 10  # Limit to 10 entries
#   monk history list users user-123 --offset 5  # Skip first 5 entries
#
# Output Fields:
#   - change_id: Auto-incrementing sequence number (higher = newer)
#   - operation: create, update, or delete
#   - changes: Field-level deltas with old/new values
#   - created_by: User ID who made the change
#   - created_at: Timestamp of the change
#
# API Endpoint:
#   GET /api/history/:model/:record

# Check dependencies
check_dependencies

# Get arguments from bashly
model="${args[model]}"
id="${args[id]}"
limit="${args[--limit]:-}"
offset="${args[--offset]:-}"

# Validate model name
if [ -z "$model" ]; then
    print_error "Model name is required"
    exit 1
fi

# Validate record ID
if [ -z "$id" ]; then
    print_error "Record ID is required"
    exit 1
fi

# Build query string for pagination
query_string=""
if [ -n "$limit" ]; then
    query_string="?limit=$limit"
fi
if [ -n "$offset" ]; then
    if [ -n "$query_string" ]; then
        query_string="${query_string}&offset=$offset"
    else
        query_string="?offset=$offset"
    fi
fi

print_info "Listing history for record: $model/$id"

# Make the history request
response=$(make_request_json "GET" "/api/history/$model/$id$query_string" "")

# Use standard response handler
handle_response_json "$response" "history"
