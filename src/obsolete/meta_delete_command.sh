#!/bin/bash

# meta_delete_command.sh - Soft delete schema and associated table
#
# This command soft deletes a schema definition and its associated database table.
# Uses soft deletion to preserve data while hiding the schema from normal operations.
#
# Usage Examples:
#   monk meta delete schema test-schema     # Delete test schema
#   CLI_VERBOSE=true monk meta delete schema users  # With confirmation prompt
#
# Deletion Process:
#   - Soft deletes schema definition (can be restored)
#   - Marks database table as deleted (preserves data)
#   - Removes from schema cache
#   - Hides from schema listing operations
#
# Safety Features:
#   - Confirmation prompt in verbose mode
#   - System schemas cannot be deleted
#   - Soft deletion allows data recovery
#   - All associated records remain intact but inaccessible
#
# Recovery:
#   - Schema can be restored via direct database operations
#   - Data remains in PostgreSQL table with soft-delete marker
#
# API Endpoint:
#   DELETE /api/meta/schema/:name

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"

# Meta commands now support JSON format
# Format flags are handled by the standard response handlers

# Validate schema name
if [ -z "$schema" ]; then
    print_error "Schema name is required"
    exit 1
fi

if [ "$CLI_VERBOSE" = "true" ]; then
    print_warning "Are you sure you want to delete schema '$schema'? (y/N)"
    read -r confirmation
    
    if ! echo "$confirmation" | grep -E "^[Yy]$" >/dev/null 2>&1; then
        print_info "Operation cancelled"
        exit 0
    fi
fi

response=$(make_request_json "DELETE" "/api/meta/$schema" "")
handle_response_json "$response" "delete"
