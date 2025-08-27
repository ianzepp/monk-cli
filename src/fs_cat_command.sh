#!/bin/bash

# fs_cat_command.sh - Display file content or record data via FTP middleware
#
# This command displays the content of API data files through the FTP middleware,
# providing familiar cat-like access to records, fields, and schema definitions.
#
# Usage Examples:
#   monk fs cat /data/users/user-123.json     # Complete record as JSON
#   monk fs cat /data/users/user-123/email    # Individual field value
#   monk fs cat /data/users/user-123/name     # Individual field value
#   monk fs cat /meta/schema/users.yaml       # Schema definition
#
# Path Types:
#   .json files    → Complete record content (formatted JSON)
#   field paths    → Individual field values (raw content)
#   .yaml files    → Schema definitions (formatted YAML)
#
# Output Format:
#   - JSON records: Pretty-formatted with jq if available
#   - Field values: Raw content (string, number, etc.)
#   - YAML content: Raw YAML output
#   - Error responses: Formatted error messages
#
# Content Processing:
#   - Automatic content type detection based on path
#   - JSON pretty-printing for readability
#   - Raw field values for scripting compatibility
#
# FTP Endpoint:
#   POST /ftp/stat with path → extract content field from response

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"

print_info "Reading file content: $path"

# Build JSON payload for FTP stat endpoint
json_payload=$(cat <<EOF
{
  "path": "$path"
}
EOF
)

print_info "FTP stat request for path: $path"
if [ "$CLI_VERBOSE" = "true" ]; then
    echo "$json_payload" | sed 's/^/  /' >&2
fi

# Make request to FTP stat endpoint
response=$(make_request_json "POST" "/ftp/stat" "$json_payload")

# Process response and extract content
if [ "$JSON_PARSER" = "jq" ]; then
    # Check if request was successful
    if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
        # Check if this is a file (has content) or directory
        file_type=$(echo "$response" | jq -r '.type // "unknown"')
        
        if [ "$file_type" = "file" ]; then
            # Extract and display content
            content=$(echo "$response" | jq -r '.content // empty')
            
            if [ -n "$content" ] && [ "$content" != "null" ] && [ "$content" != "empty" ]; then
                # Detect if content is JSON for pretty printing
                if echo "$content" | jq . >/dev/null 2>&1; then
                    # Pretty print JSON content
                    echo "$content" | jq .
                else
                    # Raw content (field values, YAML, etc.)
                    echo "$content"
                fi
            else
                print_error "No content found for path: $path"
                exit 1
            fi
        elif [ "$file_type" = "directory" ]; then
            print_error "Cannot cat directory: $path"
            print_info_always "Use 'monk fs ls $path' to list directory contents"
            exit 1
        else
            print_error "Unknown file type: $file_type"
            exit 1
        fi
    else
        # Show error response
        print_error "FTP stat request failed"
        echo "$response" >&2
        exit 1
    fi
else
    # Fallback without jq
    print_error "jq required for FTP operations"
    exit 1
fi