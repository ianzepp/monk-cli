#!/bin/bash

# fs_ls_command.sh - List directory contents with wildcard support via FTP middleware

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
long_flag="${args[--long]}"

print_info "Listing directory: $path"

# Build FTP options
long_format="false"
if [ "$long_flag" = "true" ]; then
    long_format="true"
fi

ftp_options=$(jq -n \
    --argjson long_format "$long_format" \
    '{
        "show_hidden": false,
        "recursive": false,
        "long_format": $long_format
    }')

# Build payload and make request
payload=$(build_ftp_payload "$path" "$ftp_options")
response=$(make_ftp_request "list" "$payload")

# Extract and format entries
entries=$(process_ftp_response "$response" "data")
format_ls_output "$entries"