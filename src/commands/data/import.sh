#!/bin/bash

# data_import_command.sh - Bulk import JSON files as records
#
# This command imports multiple JSON files from a directory as records in a schema.
# All .json files are collected into an array and sent in a single bulk API request.
#
# Usage Examples:
#   monk data import users ./backup/users/              # Import from directory
#   monk data import products /tmp/migration/           # Migration import
#
# Input Structure:
#   - Scans directory for all *.json files
#   - Each file should contain a valid JSON object (one record)
#   - Files processed in sorted order by filename
#   - All records combined into array for bulk import
#
# Requirements:
#   - Python3 required for JSON parsing and file operations
#   - Directory must exist and contain .json files
#   - Each JSON file must be valid and represent one record
#
# API Endpoint:  
#   PUT /api/data/:schema (bulk import with array payload)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[model]}"
directory="${args[dir]}"

validate_schema "$schema"

if [ ! -d "$directory" ]; then
    print_error "Directory does not exist: $directory"
    exit 1
fi

print_info "Importing $schema records from: $directory"

# Check if jq is available (should be, since it's a hard dependency)
if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for import functionality"
    exit 1
fi

# Check for JSON files in directory
json_files=("$directory"/*.json)

# Check if glob found any files (if not, array contains the literal pattern)
if [ ! -f "${json_files[0]}" ]; then
    print_error "No .json files found in directory: $directory"
    exit 1
fi

print_info "Found ${#json_files[@]} JSON files to import"

# Collect all JSON files into an array using jq
records_json=$(jq -n --slurpfile records <(cat "${json_files[@]}") '$records')

if [ -z "$records_json" ] || [ "$records_json" = "null" ]; then
    print_error "Failed to process JSON files"
    exit 1
fi

# Validate each file was valid JSON (jq would have failed above if not)
count=0
for file in "${json_files[@]}"; do
    filename=$(basename "$file")
    print_info "Loaded: $filename"
    count=$((count + 1))
done

print_info "Prepared $count records for import"

# Make bulk import request
response=$(make_request_json "PUT" "/api/data/$schema" "$records_json")

print_success "Import completed successfully"
handle_response_json "$response" "import"