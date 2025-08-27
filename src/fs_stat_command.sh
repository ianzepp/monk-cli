#!/bin/bash

# fs_stat_command.sh - Display detailed file/directory status and schema information

# Check dependencies
check_dependencies

# Get arguments from bashly  
path="${args[path]}"

print_info "Getting status for: $path"

# Build payload and make request
payload=$(build_ftp_payload "$path")
response=$(make_ftp_request "stat" "$payload")

# Extract basic information
file_type=$(process_ftp_response "$response" "type")
permissions=$(process_ftp_response "$response" "permissions")
size=$(process_ftp_response "$response" "size")
modified_time=$(process_ftp_response "$response" "modified_time")

# Display basic stat information
echo "  File: '$path'"
echo "  Type: $file_type"
echo "  Permissions: $permissions" 
echo "  Size: $size bytes"

# Format and display timestamps
if [ -n "$modified_time" ] && [ "$modified_time" != "null" ] && [ ${#modified_time} -eq 14 ]; then
    formatted_time=$(date -j -f "%Y%m%d%H%M%S" "$modified_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$modified_time")
    echo "Modified: $formatted_time"
fi

# Show record information if available
record_info=$(process_ftp_response "$response" "record_info")
if [ -n "$record_info" ] && [ "$record_info" != "null" ]; then
    echo
    echo "Record Information:"
    
    schema=$(echo "$record_info" | jq -r '.schema // "unknown"' 2>/dev/null)
    soft_deleted=$(echo "$record_info" | jq -r '.soft_deleted // false' 2>/dev/null)
    
    echo "  Schema: $schema"
    echo "  Soft Deleted: $soft_deleted"
    
    # Show access permissions if available
    access_perms=$(echo "$record_info" | jq -r '.access_permissions[]?' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    if [ -n "$access_perms" ]; then
        echo "  Access: $access_perms"
    fi
fi

# Show children count for directories
children_count=$(process_ftp_response "$response" "children_count")
if [ -n "$children_count" ] && [ "$children_count" != "null" ]; then
    echo
    echo "Directory contains: $children_count entries"
fi