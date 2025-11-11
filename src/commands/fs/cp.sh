#!/usr/bin/env bash

# fs_cp_command.sh
# Copy records between schemas or duplicate records within the same schema

# Check dependencies
check_dependencies

# Source and destination parsing
source_path="${args[source]}"
dest_path="${args[destination]}"
force_flag="${args[--force]}"
tenant_flag="${args[--tenant]}"

print_info "Copying from: $source_path"
print_info "Copying to: $dest_path"

# Validate paths
if [[ "$source_path" == "$dest_path" ]]; then
    print_error "Source and destination cannot be the same"
    exit 1
fi

# For now, implement single record copy only
if [[ "$source_path" != *.json ]]; then
    print_error "Currently only single record copy is supported (must end in .json)"
    print_info "Use: monk fs cp /data/users/123.json /data/users/456.json"
    exit 1
fi

if [[ "$dest_path" != *.json ]]; then
    print_error "Destination must be a record file (must end in .json)"
    print_info "Use: monk fs cp /data/users/123.json /data/users/456.json"
    exit 1
fi

# First, get the source record
print_info "Reading source record..."
source_response=$(make_file_request_with_routing "retrieve" "$source_path" "" "$tenant_flag")
source_content=$(process_file_response "$source_response" "content")

if [ -z "$source_content" ] || [ "$source_content" = "null" ]; then
    print_error "Source record not found: $source_path"
    exit 1
fi

print_info "Source record loaded successfully"

# For copy operations, we need to handle ID generation and remove system fields
# Extract the record data without system fields
clean_content=$(echo "$source_content" | jq 'del(.id, .created_at, .updated_at, .trashed_at, .deleted_at, .access_read, .access_edit, .access_full, .access_deny)')

# Copy the record to destination
print_info "Creating copy at destination..."
copy_payload=$(jq -n \
    --arg path "$dest_path" \
    --argjson content "$clean_content" \
    '{"path": $path, "content": $content, "file_options": {"overwrite": true, "atomic": true}}')

copy_response=$(make_request_json "POST" "/api/file/store" "$copy_payload")

if echo "$copy_response" | jq -e '.success' > /dev/null; then
    print_success "Record copied successfully!"
    print_info "From: $source_path"
    print_info "To: $dest_path"
    
    # Show the new record
    dest_response=$(make_file_request_with_routing "retrieve" "$dest_path" "" "$tenant_flag")
    dest_content=$(process_file_response "$dest_response" "content")
    
    if [ -n "$dest_content" ] && [ "$dest_content" != "null" ]; then
        print_info "Copied record:"
        echo "$dest_content" | jq '.'
    fi
else
    print_error "Copy failed: $(echo "$copy_response" | jq -r '.error // "Unknown error"')"
    exit 1
fi