#!/bin/bash

# sync_push_command.sh - Push data from local directory to remote tenant
#
# This command reads JSON files from a local directory and imports them as records
# into a remote tenant. It's essentially a wrapper around data import but with
# the sync endpoint format.
#
# Usage Examples:
#   monk sync push ./backup/users/ tenant-b:users
#   monk sync push ./backup/ server2:tenant-b:users
#   monk sync push ./backup/users/ tenant-b:users --dry-run
#
# Endpoint Format:
#   tenant:schema              - Uses current server
#   server:tenant:schema       - Uses specific server
#
# Input Structure:
#   - Scans directory for all *.json files
#   - Each file should contain a valid JSON object (one record)
#   - Files processed in sorted order by filename
#   - All records combined into array for bulk import
#
# API Endpoint:
#   PUT /api/data/:schema (bulk import with array payload)

# Check dependencies
check_dependencies

# Get arguments from bashly
directory="${args[directory]}"
dest_endpoint="${args[destination]}"
dry_run="${args[--dry-run]}"

# Validate directory exists
if [ ! -d "$directory" ]; then
    print_error "Directory does not exist: $directory"
    exit 1
fi

# Parse destination endpoint
print_info "Parsing destination endpoint: $dest_endpoint"
endpoint_info=$(parse_sync_endpoint "$dest_endpoint")

if [ $? -ne 0 ]; then
    print_error "Failed to parse destination endpoint"
    exit 1
fi

# Extract endpoint details
endpoint_type=$(echo "$endpoint_info" | jq -r '.type')

if [ "$endpoint_type" != "remote" ]; then
    print_error "Destination must be a remote endpoint (tenant:schema or server:tenant:schema)"
    exit 1
fi

server=$(echo "$endpoint_info" | jq -r '.server')
tenant=$(echo "$endpoint_info" | jq -r '.tenant')
schema=$(echo "$endpoint_info" | jq -r '.schema')

print_info "Source: $directory"
print_info "Destination: server=$server, tenant=$tenant, schema=$schema"

# Validate schema
validate_schema "$schema"

# Check for JSON files in directory
json_files=("$directory"/*.json)

# Check if glob found any files
if [ ! -f "${json_files[0]}" ]; then
    print_error "No .json files found in directory: $directory"
    exit 1
fi

print_info "Found ${#json_files[@]} JSON files to push"

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for import functionality"
    exit 1
fi

# Collect all JSON files into an array using jq
records_json=$(jq -n --slurpfile records <(cat "${json_files[@]}") '$records')

if [ -z "$records_json" ] || [ "$records_json" = "null" ]; then
    print_error "Failed to process JSON files"
    exit 1
fi

# Validate each file was valid JSON
count=0
for file in "${json_files[@]}"; do
    filename=$(basename "$file")
    print_info "Loaded: $filename"
    count=$((count + 1))
done

print_info "Prepared $count records for push"

# Dry run mode
if [ "$dry_run" = "true" ]; then
    print_info "DRY RUN: Would push $count records to $server:$tenant:$schema"
    echo "$records_json" | jq '.[] | {id: .id, preview: (. | keys | .[0:3])}'
    print_success "Dry run completed (no changes made)"
    exit 0
fi

# Save current context
prev_server=$(get_current_server_name)
prev_tenant=$(get_current_tenant_name)

# Switch to target context
if [ "$server" != "$prev_server" ]; then
    switch_server "$server" >/dev/null 2>&1 || {
        print_error "Failed to switch to server: $server"
        exit 1
    }
fi

if [ "$tenant" != "$prev_tenant" ]; then
    switch_tenant "$tenant" >/dev/null 2>&1 || {
        print_error "Failed to switch to tenant: $tenant"
        # Restore previous server
        [ -n "$prev_server" ] && switch_server "$prev_server" >/dev/null 2>&1
        exit 1
    }
fi

# Make bulk import request
print_info "Pushing $count records to $server:$tenant:$schema..."
response=$(make_request_json "PUT" "/api/data/$schema" "$records_json")

# Restore previous context
[ -n "$prev_tenant" ] && switch_tenant "$prev_tenant" >/dev/null 2>&1
[ -n "$prev_server" ] && switch_server "$prev_server" >/dev/null 2>&1

# Handle response
print_success "Push completed successfully"
handle_response_json "$response" "import"
