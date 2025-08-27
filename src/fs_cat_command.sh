#!/bin/bash

# fs_cat_command.sh - Display file content via FTP retrieve

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"

print_info "Reading file content: $path"

# Build payload and make request
payload=$(build_ftp_payload "$path")
response=$(make_ftp_request "retrieve" "$payload")

# Extract and display content
content=$(process_ftp_response "$response" "content")

if [ -n "$content" ] && [ "$content" != "null" ]; then
    # Pretty print JSON objects, show raw for simple values
    echo "$content" | jq . 2>/dev/null || echo "$content" | jq -r .
else
    print_error "No content found for path: $path"
    exit 1
fi