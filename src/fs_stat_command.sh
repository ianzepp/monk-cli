#!/bin/bash

# fs_stat_command.sh - Display detailed file/directory status and schema information
#
# This command provides comprehensive status information about API data paths through
# the FTP middleware, similar to unix stat command but with schema introspection.
#
# Usage Examples:
#   monk fs stat /data/users/              # Schema information and statistics
#   monk fs stat /data/users/user-123/     # Record metadata and field info
#   monk fs stat /data/users/user-123.json # File-like metadata
#   monk fs stat /meta/schema/users        # Schema definition metadata
#
# Output Information:
#   - File/directory type and permissions
#   - Size and timestamp information  
#   - Schema introspection (field definitions, constraints)
#   - Record metadata (soft delete status, access permissions)
#   - Performance hints (cache status, query time)
#
# Schema Information:
#   - Complete field definitions with types and constraints
#   - Required vs optional field breakdown
#   - Validation rules and format specifications
#   - Human-readable constraint descriptions
#
# Performance Data:
#   - Cache hit/miss information
#   - Query execution time
#   - Pattern complexity analysis
#
# FTP Endpoint:
#   POST /ftp/stat with path → comprehensive metadata response

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"

print_info "Getting status for: $path"

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

# Process response and format as stat output
if [ "$JSON_PARSER" = "jq" ]; then
    # Check if request was successful
    if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
        # Extract basic file information
        file_type=$(echo "$response" | jq -r '.type // "unknown"')
        permissions=$(echo "$response" | jq -r '.permissions // "---"')
        size=$(echo "$response" | jq -r '.size // 0')
        modified_time=$(echo "$response" | jq -r '.modified_time // ""')
        created_time=$(echo "$response" | jq -r '.created_time // ""')
        
        # Display basic stat information
        echo "  File: '$path'"
        echo "  Type: $file_type"
        echo "  Permissions: $permissions"
        echo "  Size: $size bytes"
        
        # Format timestamps
        if [ -n "$modified_time" ] && [ "$modified_time" != "null" ]; then
            if command -v date >/dev/null 2>&1 && [ ${#modified_time} -eq 14 ]; then
                year=${modified_time:0:4}
                month=${modified_time:4:2}
                day=${modified_time:6:2}
                hour=${modified_time:8:2}
                minute=${modified_time:10:2}
                second=${modified_time:12:2}
                
                formatted_time=$(date -j -f "%Y%m%d%H%M%S" "$modified_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$modified_time")
                echo "Modified: $formatted_time"
            else
                echo "Modified: $modified_time"
            fi
        fi
        
        # Show record information if available
        record_info=$(echo "$response" | jq '.record_info // empty' 2>/dev/null)
        if [ -n "$record_info" ] && [ "$record_info" != "null" ] && [ "$record_info" != "empty" ]; then
            echo
            echo "Record Information:"
            
            schema=$(echo "$record_info" | jq -r '.schema // "unknown"')
            soft_deleted=$(echo "$record_info" | jq -r '.soft_deleted // false')
            access_perms=$(echo "$record_info" | jq -r '.access_permissions[]?' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
            
            echo "  Schema: $schema"
            echo "  Soft Deleted: $soft_deleted"
            if [ -n "$access_perms" ]; then
                echo "  Access: $access_perms"
            fi
        fi
        
        # Show schema information if available  
        schema_info=$(echo "$response" | jq '.schema_info // empty' 2>/dev/null)
        if [ -n "$schema_info" ] && [ "$schema_info" != "null" ] && [ "$schema_info" != "empty" ]; then
            echo
            echo "Schema Information:"
            
            description=$(echo "$schema_info" | jq -r '.description // ""')
            if [ -n "$description" ] && [ "$description" != "null" ]; then
                echo "  Description: $description"
            fi
            
            # Show field definitions
            field_count=$(echo "$schema_info" | jq '.field_definitions | length' 2>/dev/null || echo "0")
            if [ "$field_count" -gt 0 ]; then
                echo "  Fields ($field_count):"
                
                echo "$schema_info" | jq -r '.field_definitions[] | "    \(.name) (\(.type)\(.required | if . then ", required" else "" end)) - \(.description // "No description")"' 2>/dev/null
            fi
        fi
        
        # Show children count for directories
        children_count=$(echo "$response" | jq -r '.children_count // empty' 2>/dev/null)
        if [ -n "$children_count" ] && [ "$children_count" != "null" ] && [ "$children_count" != "empty" ]; then
            echo
            echo "Directory contains: $children_count entries"
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