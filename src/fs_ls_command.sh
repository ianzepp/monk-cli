#!/bin/bash

# Check dependencies
check_dependencies

# Get arguments
path="${args[path]}"

# Build payload
json_payload=$(jq -n --arg path "$path" '{
    "path": $path,
    "ftp_options": {"show_hidden": false, "recursive": false, "long_format": false}
}')

# Make request
response=$(make_request_json "POST" "/ftp/list" "$json_payload")

# Debug what we got
echo "Full response:" >&2
echo "$response" >&2

# Try to show just names
echo "$response" | jq -r '.data[].name' 2>/dev/null || echo "Failed to extract names"