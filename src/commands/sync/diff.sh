#!/bin/bash

# sync_diff_command.sh - Show differences between two endpoints
#
# This command compares two datasets (remote or local) and displays the differences.
# It can show a summary, detailed view, or output JSON for scripting.
# Optionally saves the diff as a patch file for later application.
#
# Usage Examples:
#   monk sync diff tenant-a:users tenant-b:users
#   monk sync diff tenant-a:users ./backup/users/ --format json
#   monk sync diff server1:tenant-a:users server2:tenant-b:users --output sync.patch
#   monk sync diff tenant-a:orders tenant-b:orders --filter '{"where": {"status": "paid"}}'
#
# Endpoint Formats:
#   tenant:schema              - Uses current server
#   server:tenant:schema       - Uses specific server
#   /path/to/directory         - Local filesystem
#
# Output Formats:
#   summary (default)          - Human-readable summary with counts and percentages
#   json                       - Machine-readable JSON with full diff details
#
# Patch File:
#   When --output is specified, creates a JSON patch file that can be applied
#   with 'monk sync patch' command.

# Check dependencies
check_dependencies

# Get arguments from bashly
source_endpoint="${args[source]}"
dest_endpoint="${args[destination]}"
format="${args[--format]:-summary}"
output_file="${args[--output]}"
filter_json="${args[--filter]}"

# Parse source endpoint
print_info "Parsing source endpoint: $source_endpoint"
source_info=$(parse_sync_endpoint "$source_endpoint")

if [ $? -ne 0 ]; then
    print_error "Failed to parse source endpoint"
    exit 1
fi

# Parse destination endpoint
print_info "Parsing destination endpoint: $dest_endpoint"
dest_info=$(parse_sync_endpoint "$dest_endpoint")

if [ $? -ne 0 ]; then
    print_error "Failed to parse destination endpoint"
    exit 1
fi

# Extract endpoint types
source_type=$(echo "$source_info" | jq -r '.type')
dest_type=$(echo "$dest_info" | jq -r '.type')

# Fetch source data
print_info "Fetching source data..."
if [ "$source_type" = "remote" ]; then
    server=$(echo "$source_info" | jq -r '.server')
    tenant=$(echo "$source_info" | jq -r '.tenant')
    schema=$(echo "$source_info" | jq -r '.schema')
    source_data=$(sync_fetch_remote "$server" "$tenant" "$schema" "$filter_json")
elif [ "$source_type" = "local" ]; then
    path=$(echo "$source_info" | jq -r '.path')
    if [ ! -d "$path" ]; then
        print_error "Source directory does not exist: $path"
        exit 1
    fi
    # Load all JSON files from directory
    source_data=$(jq -n --slurpfile records <(cat "$path"/*.json 2>/dev/null) '$records')
    if [ -z "$source_data" ] || [ "$source_data" = "null" ] || [ "$source_data" = "[]" ]; then
        print_error "No JSON files found in source directory: $path"
        exit 1
    fi
fi

if [ $? -ne 0 ] || [ -z "$source_data" ]; then
    print_error "Failed to fetch source data"
    exit 1
fi

# Fetch destination data
print_info "Fetching destination data..."
if [ "$dest_type" = "remote" ]; then
    server=$(echo "$dest_info" | jq -r '.server')
    tenant=$(echo "$dest_info" | jq -r '.tenant')
    schema=$(echo "$dest_info" | jq -r '.schema')
    dest_data=$(sync_fetch_remote "$server" "$tenant" "$schema" "$filter_json")
elif [ "$dest_type" = "local" ]; then
    path=$(echo "$dest_info" | jq -r '.path')
    if [ ! -d "$path" ]; then
        print_error "Destination directory does not exist: $path"
        exit 1
    fi
    # Load all JSON files from directory
    dest_data=$(jq -n --slurpfile records <(cat "$path"/*.json 2>/dev/null) '$records')
    if [ -z "$dest_data" ] || [ "$dest_data" = "null" ] || [ "$dest_data" = "[]" ]; then
        # Empty destination is okay
        dest_data="[]"
    fi
fi

if [ $? -ne 0 ]; then
    print_error "Failed to fetch destination data"
    exit 1
fi

# Compute diff
print_info "Computing diff..."
diff_json=$(sync_compute_diff "$source_data" "$dest_data")

if [ $? -ne 0 ]; then
    print_error "Failed to compute diff"
    exit 1
fi

# Add metadata to diff
diff_with_metadata=$(echo "$diff_json" | jq \
    --arg source "$source_endpoint" \
    --arg dest "$dest_endpoint" \
    --arg created "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '. + {
        metadata: {
            source: $source,
            destination: $dest,
            created_at: $created,
            filter: null
        }
    }'
)

# Save to patch file if requested
if [ -n "$output_file" ]; then
    echo "$diff_with_metadata" | jq '.' > "$output_file"
    print_success "Diff saved to patch file: $output_file"
fi

# Format and display diff
if [ "$format" = "json" ]; then
    echo "$diff_with_metadata" | jq '.'
else
    # Summary format
    echo ""
    sync_format_diff "$diff_json" "summary"
    echo ""
    
    if [ -n "$output_file" ]; then
        echo "Patch file saved: $output_file"
        echo "Apply with: monk sync patch $output_file <destination>"
    fi
fi
