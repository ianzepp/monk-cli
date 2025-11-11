#!/bin/bash

# data_delete_command.sh - Delete records with confirmation and flexible input
#
# This command deletes records with multiple input patterns and safety confirmations:
# - Direct ID deletion with optional confirmation prompts  
# - ID extracted from JSON objects for scripted deletions
# - Bulk deletion from array input
#
# Usage Examples:
#   monk data delete users 123                           # Direct ID deletion
#   echo '{"id": 123}' | monk data delete users         # ID from JSON
#   echo '[{"id": 1}, {"id": 2}]' | monk data delete users  # Bulk deletion
#
# Safety Features:
#   - Confirmation prompts in CLI_VERBOSE mode for destructive operations
#   - Clear error messages when ID missing from both parameter and JSON
#
# API Endpoints:
#   DELETE /api/data/:schema/:id  (single record deletion)  
#   DELETE /api/data/:schema      (bulk deletion from array)
#
# Input Requirements:
#   - Either ID parameter OR JSON with 'id' field(s) required
#   - No payload sent for single deletions (just endpoint)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"
id="${args[id]}"

# Data commands only support JSON format
if [[ "${args[--text]}" == "1" ]]; then
    print_error "The --text option is not supported for data operations"
    print_info "Data operations require JSON format for structured data handling"
    exit 1
fi

validate_schema "$schema"

if [ -n "$id" ]; then
    # ID provided - direct delete, no stdin needed
    process_data_operation "delete" "DELETE" "$schema" "$id" "" "true"
elif [ -t 0 ]; then
    # No ID and no stdin (terminal input) - error
    print_error "No ID provided and no JSON data on stdin"
    print_info "Usage: monk data delete $schema <id> OR provide JSON with 'id' field(s) via stdin"
    exit 1
else
    # No ID but have stdin - read and process JSON data
    json_data=$(read_and_validate_json_input "deleting" "$schema")
    process_data_operation "delete" "DELETE" "$schema" "" "$json_data" "true"
fi