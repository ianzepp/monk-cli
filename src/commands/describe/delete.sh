#!/bin/bash

# describe_delete_command.sh - Delete schema or remove column
#
# This command soft deletes a schema or removes a column from a schema.
#
# Usage Examples:
#   monk describe delete users              # Delete entire schema (soft delete)
#   monk describe delete users old_column   # Remove column from schema
#
# Deletion Behavior:
#   - Schema: Soft delete (can be restored)
#   - Column: Removed from schema definition and database table
#   - System schemas and columns cannot be deleted
#
# API Endpoints:
#   DELETE /api/describe/:schema                 (delete schema)
#   DELETE /api/describe/:schema/columns/:column (remove column)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"
column="${args[column]:-}"

# Validate schema name
if [ -z "$schema" ]; then
    print_error "Schema name is required"
    exit 1
fi

# Determine endpoint based on arguments
if [ -n "$column" ]; then
    # Column operation
    print_info "Removing column '$column' from schema '$schema'"
    response=$(make_request_json "DELETE" "/api/describe/$schema/columns/$column" "")
else
    # Schema operation
    print_info "Deleting schema '$schema'"
    response=$(make_request_json "DELETE" "/api/describe/$schema" "")
fi

# Output response directly (API handles formatting)
echo "$response"
