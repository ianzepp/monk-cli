#!/bin/bash

# fs_ls_command.sh - List directory contents with multi-tenant support

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
long_flag="${args[--long]}"
tenant_flag="${args[--tenant]}"

print_info "Listing directory: $path"

# Build file options
long_format="false"
if [ "$long_flag" = "1" ]; then
    long_format="true"
fi

file_options=$(jq -n \
    --argjson long_format "$long_format" \
    '{
        "show_hidden": false,
        "recursive": false,
        "long_format": $long_format
    }')

# Make request with tenant routing - UPDATED to use /api/file/list
response=$(make_file_request_with_routing "list" "$path" "$file_options" "$tenant_flag")

# Extract and format entries
entries=$(process_file_response "$response" "entries")
format_ls_output "$entries" "$long_format"