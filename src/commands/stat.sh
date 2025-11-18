#!/bin/bash

# stat_command.sh - Get record metadata without fetching full data
#
# This command retrieves only system metadata fields (timestamps, etag, size) for a specific
# record without fetching the full record data. Useful for cache invalidation, existence checks,
# modification tracking, and checking soft delete status.
#
# Usage Examples:
#   monk stat users user-123                    # Get metadata for user record
#   monk stat orders order-456                  # Get metadata for order record
#   monk --json stat products prod-789          # Get metadata in JSON format
#   monk --pick created_at,updated_at stat users user-123  # Extract specific fields
#
# Metadata Fields Returned:
#   - id: Record identifier
#   - created_at: ISO 8601 timestamp when record was created
#   - updated_at: ISO 8601 timestamp when record was last modified
#   - trashed_at: ISO 8601 timestamp when record was soft-deleted (null if active)
#   - etag: Entity tag for HTTP caching (currently uses record ID)
#   - size: Record size in bytes (currently 0, TODO: implement on server)
#
# Use Cases:
#   - Cache invalidation: Check updated_at without fetching full record
#   - Existence checks: Verify record exists and get basic metadata
#   - Modification tracking: Monitor when records change for sync operations
#   - Soft delete status: Check trashed_at to see if record is deleted
#
# API Endpoint:
#   GET /api/stat/:schema/:id

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"
id="${args[id]}"

# Validate schema name
validate_schema "$schema"

# Validate record ID is not empty
if [ -z "$id" ]; then
    print_error "Record ID cannot be empty"
    exit 1
fi

print_info "Getting metadata for record: $schema/$id"

# Make the stat request
response=$(make_request_json "GET" "/api/stat/$schema/$id" "")

# Use standard response handler
handle_response_json "$response" "stat"
