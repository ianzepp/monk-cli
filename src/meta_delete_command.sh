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
type="${args[type]}"
name="${args[name]}"

# Meta commands only support YAML format
if [[ "${args[--text]}" == "1" ]]; then
    print_error "The --text option is not supported for meta operations"
    print_info "Meta operations work with YAML schema definitions"
    exit 1
fi

if [[ "${args[--json]}" == "1" ]]; then
    print_error "The --json option is not supported for meta operations"
    print_info "Meta operations work with YAML schema definitions"
    exit 1
fi

# Validate metadata type (currently only schema supported)
case "$type" in
    schema)
        # Valid type
        ;;
    *)
        print_error "Unsupported metadata type: $type"
        print_info "Currently supported types: schema"
        exit 1
        ;;
esac

if [ "$CLI_VERBOSE" = "true" ]; then
    print_warning "Are you sure you want to delete $type '$name'? (y/N)"
    read -r confirmation
    
    if ! echo "$confirmation" | grep -E "^[Yy]$" >/dev/null 2>&1; then
        print_info "Operation cancelled"
        exit 0
    fi
fi

response=$(make_request_yaml "DELETE" "/api/meta/$type/$name" "")

# Check if response is JSON (delete operations may return JSON success messages)
if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    # API returned JSON success message - handle appropriately
    if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
        print_success "Schema '$name' deleted successfully"
    else
        error_msg=$(echo "$response" | jq -r '.error // "Delete operation failed"')
        print_error "$error_msg"
        exit 1
    fi
else
    # API returned YAML or other format - output directly
    handle_response_yaml "$response" "delete"
fi