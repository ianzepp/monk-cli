#!/bin/bash

# fs_ls_command.sh - List directory contents with multi-tenant support

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
long_flag="${args[--long]}"
all_flag="${args[--all]}"
sort_flag="${args[--sort]:-name}"
reverse_flag="${args[--reverse]}"
tenant_flag="${args[--tenant]}"

print_info "Listing directory: $path"

# Build file options
long_format="false"
if [ "$long_flag" = "1" ]; then
    long_format="true"
fi

show_hidden="false"
if [ "$all_flag" = "1" ]; then
    show_hidden="true"
    print_info "Showing hidden entries"
fi

# Determine sort order
sort_order="asc"
if [ "$reverse_flag" = "1" ]; then
    sort_order="desc"
    print_info "Using reverse sort order"
fi

# Show sort info if not default
if [ "$sort_flag" != "name" ] || [ "$sort_order" != "asc" ]; then
    print_info "Sorting by: $sort_flag ($sort_order)"
fi

file_options=$(jq -n \
    --argjson long_format "$long_format" \
    --argjson show_hidden "$show_hidden" \
    --arg sort_by "$sort_flag" \
    --arg sort_order "$sort_order" \
    '{
        "show_hidden": $show_hidden,
        "recursive": false,
        "long_format": $long_format,
        "sort_by": $sort_by,
        "sort_order": $sort_order
    }')

# Make request with tenant routing - UPDATED to use /api/file/list
response=$(make_file_request_with_routing "list" "$path" "$file_options" "$tenant_flag")

# Extract and format entries
entries=$(process_file_response "$response" "entries")
format_ls_output "$entries" "$long_format"