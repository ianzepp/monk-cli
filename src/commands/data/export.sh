#!/bin/bash

# data_export_command.sh - Export schema records to individual JSON files
#
# This command exports all records from a schema to separate JSON files in a directory.
# Each record is saved as {record_id}.json with pretty-formatted JSON content.
#
# Usage Examples:
#   monk data export users ./backup/users/              # Export to directory
#   monk data export products /tmp/export-$(date +%Y%m%d)/  # Timestamped export
#
# Output Structure:
#   - Creates target directory if it doesn't exist
#   - One file per record: {directory}/{record_id}.json
#   - Pretty-formatted JSON with 4-space indentation
#   - Verbose progress reporting when CLI_VERBOSE=true
#
# Requirements:
#   - Python3 required for JSON parsing and file operations
#   - Records must have 'id' field for filename generation
#   - Write permissions needed for target directory
#
# API Endpoint:
#   GET /api/data/:schema (retrieves all records)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[model]}"
directory="${args[dir]}"

validate_schema "$schema"

# Create directory if it doesn't exist
if [ ! -d "$directory" ]; then
    print_info "Creating directory: $directory"
    mkdir -p "$directory"
fi

print_info "Exporting $schema records to: $directory"

# Get all records using the API
response=$(make_request_json "GET" "/api/data/$schema" "")

# Check if jq is available (should be, since it's a hard dependency)
if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for export functionality"
    exit 1
fi

# Validate API response format
if ! echo "$response" | jq -e '.success == true and .data' >/dev/null 2>&1; then
    print_error "Invalid API response format"
    echo "$response"
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
        print_info "Exported: $filename"
        count=$((count + 1))
    else
        print_error "Failed to write: $filename"
        exit 1
    fi
    
done < <(echo "$response" | jq -c '.data[]')

print_success "Successfully exported $count records to $directory"