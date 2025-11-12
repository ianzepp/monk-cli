#!/bin/bash

# fs_size_command.sh - Calculate storage footprint with multi-tenant support

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
tenant_flag="${args[--tenant]}"

print_info "Getting size for: $path"

# Make request with tenant routing - Using /api/file/size endpoint
response=$(make_file_request_with_routing "size" "$path" "" "$tenant_flag")

# Extract size information
size=$(process_file_response "$response" "size")
file_type=$(process_file_response "$response" "file_metadata.type")

if [ -n "$size" ] && [ "$size" != "null" ]; then
    # Format size in human-readable format
    if command -v numfmt >/dev/null 2>&1; then
        human_size=$(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "$size bytes")
    else
        # Fallback for macOS without numfmt
        if [ "$size" -ge 1073741824 ]; then
            human_size=$(awk "BEGIN {printf \"%.2f GiB\", $size/1073741824}")
        elif [ "$size" -ge 1048576 ]; then
            human_size=$(awk "BEGIN {printf \"%.2f MiB\", $size/1048576}")
        elif [ "$size" -ge 1024 ]; then
            human_size=$(awk "BEGIN {printf \"%.2f KiB\", $size/1024}")
        else
            human_size="$size bytes"
        fi
    fi

    echo "$human_size ($size bytes)"

    # Show additional metadata if available
    if [ -n "$file_type" ] && [ "$file_type" != "null" ]; then
        print_info "Type: $file_type"
    fi
else
    print_error "Could not retrieve size for: $path"
    exit 1
fi
