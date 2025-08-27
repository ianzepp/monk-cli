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
schema="${args[schema]}"
directory="${args[dir]}"

validate_schema "$schema"

if [ ! -d "$directory" ]; then
    print_error "Directory does not exist: $directory"
    exit 1
fi

if [ "$CLI_VERBOSE" = "true" ]; then
    print_info "Importing $schema records from: $directory"
fi

# Collect all JSON files into an array for bulk import
if command -v python3 >/dev/null 2>&1; then
    records_json=$(python3 -c "
import sys, json, os, glob
records = []
json_files = glob.glob(os.path.join('$directory', '*.json'))

if not json_files:
    print('No .json files found in $directory', file=sys.stderr)
    sys.exit(1)

for filepath in sorted(json_files):
    filename = os.path.basename(filepath)
    try:
        with open(filepath, 'r') as f:
            record = json.load(f)
        records.append(record)
        if '$CLI_VERBOSE' == 'true':
            print(f'Loaded: {filename}', file=sys.stderr)
    except Exception as e:
        print(f'Error loading {filename}: {e}', file=sys.stderr)
        sys.exit(1)

if '$CLI_VERBOSE' == 'true':
    print(f'Prepared {len(records)} records for import', file=sys.stderr)
json.dump(records, sys.stdout)
")
    
    if [ -n "$records_json" ]; then
        if [ "$CLI_VERBOSE" = "true" ]; then
            print_info "Making bulk import request..."
        fi
        
        response=$(make_request_json "PUT" "/api/data/$schema" "$records_json")
        
        print_success "Import completed successfully"
        handle_response_json "$response" "import"
    else
        print_error "Failed to prepare records for import"
        exit 1
    fi
else
    print_error "Python3 required for import functionality"
    print_info "Please install Python 3 to use import operations"
    exit 1
fi