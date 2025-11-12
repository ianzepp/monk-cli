#!/bin/bash

# fs_cat_command.sh - Display file content with multi-tenant support

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
tenant_flag="${args[--tenant]}"
format_flag="${args[--format]:-json}"
offset_flag="${args[--offset]}"
max_bytes_flag="${args[--max-bytes]}"

print_info "Reading file content: $path"

# Build file options based on flags
file_options_parts=()
file_options_parts+=("\"format\": \"$format_flag\"")
file_options_parts+=("\"binary_mode\": false")

# Add offset if provided
if [ -n "$offset_flag" ]; then
    file_options_parts+=("\"start_offset\": $offset_flag")
    print_info "Using byte offset: $offset_flag"
fi

# Add max_bytes if provided
if [ -n "$max_bytes_flag" ]; then
    file_options_parts+=("\"max_bytes\": $max_bytes_flag")
    print_info "Limiting to max bytes: $max_bytes_flag"
fi

# Join options into JSON object
file_options=$(printf '{%s}' "$(IFS=,; echo "${file_options_parts[*]}")")

# Make request with tenant routing - UPDATED to use /api/file/retrieve
response=$(make_file_request_with_routing "retrieve" "$path" "$file_options" "$tenant_flag")

# Extract and display content
content=$(process_file_response "$response" "content")

if [ -n "$content" ] && [ "$content" != "null" ]; then
    # Handle output based on format
    if [ "$format_flag" = "raw" ]; then
        # Raw format - output as-is without quotes
        echo "$content" | jq -r .
    else
        # JSON format - pretty print JSON objects, show raw for simple values
        echo "$content" | jq . 2>/dev/null || echo "$content" | jq -r .
    fi
else
    print_error "No content found for path: $path"
    exit 1
fi