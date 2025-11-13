#!/bin/bash

# sync_pull_command.sh - Pull data from remote tenant to local directory
#
# This command fetches records from a remote tenant and saves them as individual
# JSON files in a local directory. It's essentially a wrapper around data export
# but with the sync endpoint format.
#
# Usage Examples:
#   monk sync pull tenant-a:users ./backup/users/
#   monk sync pull server1:tenant-a:users ./backup/
#   monk sync pull tenant-a:orders ./backup/ --filter '{"where": {"status": "paid"}}'
#
# Endpoint Format:
#   tenant:schema              - Uses current server
#   server:tenant:schema       - Uses specific server
#
# Output Structure:
#   - Creates target directory if it doesn't exist
#   - One file per record: {directory}/{record_id}.json
#   - Pretty-formatted JSON with indentation
#
# API Endpoint:
#   GET /api/data/:schema or POST /api/find/:schema (with filter)

# Check dependencies
check_dependencies

# Get arguments from bashly
source_endpoint="${args[source]}"
directory="${args[directory]}"
filter_json="${args[--filter]}"
overwrite="${args[--overwrite]}"

# Parse source endpoint
print_info "Parsing source endpoint: $source_endpoint"
endpoint_info=$(parse_sync_endpoint "$source_endpoint")

if [ $? -ne 0 ]; then
    print_error "Failed to parse source endpoint"
    exit 1
fi

# Extract endpoint details
endpoint_type=$(echo "$endpoint_info" | jq -r '.type')

if [ "$endpoint_type" != "remote" ]; then
    print_error "Source must be a remote endpoint (tenant:schema or server:tenant:schema)"
    exit 1
fi

server=$(echo "$endpoint_info" | jq -r '.server')
tenant=$(echo "$endpoint_info" | jq -r '.tenant')
schema=$(echo "$endpoint_info" | jq -r '.schema')

print_info "Source: server=$server, tenant=$tenant, schema=$schema"
print_info "Destination: $directory"

# Validate schema
validate_schema "$schema"

# Create directory if it doesn't exist
if [ ! -d "$directory" ]; then
    print_info "Creating directory: $directory"
    mkdir -p "$directory"
fi

# Check for existing files
if [ "$overwrite" != "true" ] && [ -n "$(ls -A "$directory"/*.json 2>/dev/null)" ]; then
    print_error "Directory contains existing JSON files. Use --overwrite to replace them."
    exit 1
fi

# Fetch data from remote
print_info "Fetching records from $server:$tenant:$schema..."
records_json=$(sync_fetch_remote "$server" "$tenant" "$schema" "$filter_json")

if [ $? -ne 0 ]; then
    print_error "Failed to fetch records from remote"
    exit 1
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for export functionality"
    exit 1
fi

# Validate that we got an array
if ! echo "$records_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
    print_error "Expected array of records from remote"
    echo "$records_json" >&2
    exit 1
fi

# Export each record to individual JSON file
count=0
while IFS= read -r record; do
    # Extract ID from record
    id=$(echo "$record" | jq -r '.id // empty')
    
    if [ -z "$id" ] || [ "$id" = "null" ]; then
        print_warning "Skipping record without id field"
        continue
    fi
    
    # Write pretty-formatted JSON to file
    filename="$directory/$id.json"
    echo "$record" | jq '.' > "$filename"
    
    if [ $? -eq 0 ]; then
        print_info "Pulled: $filename"
        count=$((count + 1))
    else
        print_error "Failed to write: $filename"
        exit 1
    fi
    
done < <(echo "$records_json" | jq -c '.[]')

print_success "Successfully pulled $count records to $directory"
