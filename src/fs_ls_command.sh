#!/bin/bash

# fs_ls_command.sh - List directory contents with multi-tenant support

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
long_flag="${args[--long]}"
tenant_flag="${args[--tenant]}"

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

# Make request with tenant routing
response=$(make_ftp_request_with_routing "list" "$path" "$ftp_options" "$tenant_flag")

# Extract and format entries
entries=$(process_ftp_response "$response" "data")
format_ls_output "$entries"