#!/bin/bash

# describe_delete_command.sh - Delete schema definition
#
# This command soft deletes a schema definition. The schema is marked as deleted
# but can be restored later. System schemas cannot be deleted.
#
# Usage Examples:
#   monk describe delete test-schema          # Delete a test schema
#   monk describe delete products             # Delete products schema
#   monk describe delete old-users            # Delete old user schema
#
# Deletion Behavior:
#   - Soft delete: Schema is marked as deleted but data remains
#   - System schemas: Cannot be deleted (protected)
#   - Restoration: Schemas can be restored via API (not yet in CLI)
#
# API Endpoint:
#   DELETE /api/describe/:name (soft delete)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"

# Determine output format from global flags
output_format=$(get_output_format "text")

# Validate schema name
if [ -z "$schema" ]; then
    print_error "Schema name is required"
    exit 1
fi

print_info "Deleting schema: $schema"

response=$(make_request_json "DELETE" "/api/describe/$schema" "")
handle_response_json "$response" "delete"