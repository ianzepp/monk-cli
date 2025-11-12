#!/bin/bash

# fs_mtime_command.sh - Retrieve modified timestamps with multi-tenant support

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
tenant_flag="${args[--tenant]}"

print_info "Getting modified time for: $path"

# Make request with tenant routing - Using /api/file/modify-time endpoint
response=$(make_file_request_with_routing "modify-time" "$path" "" "$tenant_flag")

# Extract timestamp information (use raw output to avoid quotes)
modified_time=$(echo "$response" | jq -r '.data.modified_time // empty')
iso_timestamp=$(echo "$response" | jq -r '.data.timestamp_info.iso_timestamp // empty')
source_field=$(echo "$response" | jq -r '.data.timestamp_info.source // empty')

if [ -n "$modified_time" ] && [ "$modified_time" != "null" ]; then
    # Display the FTP-style timestamp
    echo "Modified Time: $modified_time"

    # Display ISO format if available
    if [ -n "$iso_timestamp" ] && [ "$iso_timestamp" != "null" ]; then
        echo "ISO Format: $iso_timestamp"
    fi

    # Show source field
    if [ -n "$source_field" ] && [ "$source_field" != "null" ]; then
        print_info "Source: $source_field"
    fi

    # Try to format in human-readable local time (macOS compatible)
    if [ ${#modified_time} -eq 14 ]; then
        formatted_time=$(date -j -f "%Y%m%d%H%M%S" "$modified_time" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || echo "")
        if [ -n "$formatted_time" ]; then
            echo "Local Time: $formatted_time"
        fi
    fi
else
    print_error "Could not retrieve modified time for: $path"
    exit 1
fi
