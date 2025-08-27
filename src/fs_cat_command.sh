#!/bin/bash

# fs_cat_command.sh - Display file content with multi-tenant support

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
tenant_flag="${args[--tenant]}"

print_info "Reading file content: $path"

# Make request with tenant routing
response=$(make_ftp_request_with_routing "retrieve" "$path" "" "$tenant_flag")

# Extract and display content
content=$(process_ftp_response "$response" "content")

if [ -n "$content" ] && [ "$content" != "null" ]; then
    # Pretty print JSON objects, show raw for simple values
    echo "$content" | jq . 2>/dev/null || echo "$content" | jq -r .
else
    print_error "No content found for path: $path"
    exit 1
fi