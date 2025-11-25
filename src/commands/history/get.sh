#!/bin/bash

# history_get_command.sh - Get a specific history entry by change ID
#
# This command retrieves detailed information about a specific change event
# identified by its change_id (auto-incrementing sequence number).
#
# Usage Examples:
#   monk history get users user-123 42            # Get change #42
#   monk --json history get users user-123 42     # JSON output
#
# Output Fields:
#   - id: History record UUID
#   - change_id: Auto-incrementing sequence number
#   - model_name: Model containing the changed record
#   - record_id: ID of the record that was modified
#   - operation: create, update, or delete
#   - changes: Field-level deltas with old/new values
#   - created_by: User ID who made the change
#   - created_at: Timestamp of the change
#   - request_id: Request correlation ID
#   - metadata: Additional context (user role, tenant, etc.)
#
# API Endpoint:
#   GET /api/history/:model/:record/:change_id

# Check dependencies
check_dependencies

# Get arguments from bashly
model="${args[model]}"
id="${args[id]}"
change_id="${args[change_id]}"

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

# Validate change ID
if [ -z "$change_id" ]; then
    print_error "Change ID is required"
    exit 1
fi

print_info "Getting history entry: $model/$id change #$change_id"

# Make the history request
response=$(make_request_json "GET" "/api/history/$model/$id/$change_id" "")

# Use standard response handler
handle_response_json "$response" "history"
