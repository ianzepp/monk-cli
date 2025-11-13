#!/bin/bash

# sync_copy_command.sh - Direct copy between two remote tenants (streaming)
#
# This command performs a direct synchronization between two remote tenants
# without using local filesystem as intermediary. It's the most efficient
# way to sync data between tenants, especially for large datasets.
#
# Usage Examples:
#   monk sync copy tenant-a:users tenant-b:users
#   monk sync copy server1:tenant-a:users server2:tenant-b:users
#   monk sync copy tenant-a:orders tenant-b:orders --strategy merge
#   monk sync copy tenant-a:users tenant-b:users --dry-run
#   monk sync copy tenant-a:users tenant-b:users --filter '{"where": {"status": "active"}}'
#
# Endpoint Format:
#   tenant:schema              - Uses current server
#   server:tenant:schema       - Uses specific server
#
# Sync Strategies:
#   replace (default)          - Delete all destination records, insert all source records
#   merge                      - Update existing by ID, insert new ones (no deletes)
#
# Process:
#   1. Fetch all records from source
#   2. Optionally show diff
#   3. Apply changes to destination using bulk API

# Check dependencies
check_dependencies

# Get arguments from bashly
source_endpoint="${args[source]}"
dest_endpoint="${args[destination]}"
filter_json="${args[--filter]}"
dry_run="${args[--dry-run]}"
strategy="${args[--strategy]:-replace}"

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

# Validate both are remote endpoints
source_type=$(echo "$source_info" | jq -r '.type')
dest_type=$(echo "$dest_info" | jq -r '.type')

if [ "$source_type" != "remote" ] || [ "$dest_type" != "remote" ]; then
    print_error "Both source and destination must be remote endpoints"
    print_info "Use 'monk sync pull' for remote→local or 'monk sync push' for local→remote"
    exit 1
fi

# Extract endpoint details
src_server=$(echo "$source_info" | jq -r '.server')
src_tenant=$(echo "$source_info" | jq -r '.tenant')
src_schema=$(echo "$source_info" | jq -r '.schema')

dst_server=$(echo "$dest_info" | jq -r '.server')
dst_tenant=$(echo "$dest_info" | jq -r '.tenant')
dst_schema=$(echo "$dest_info" | jq -r '.schema')

print_info "Source: $src_server:$src_tenant:$src_schema"
print_info "Destination: $dst_server:$dst_tenant:$dst_schema"
print_info "Strategy: $strategy"

# Validate schemas
validate_schema "$src_schema"
validate_schema "$dst_schema"

# Fetch source data
print_info "Fetching source records..."
source_data=$(sync_fetch_remote "$src_server" "$src_tenant" "$src_schema" "$filter_json")

if [ $? -ne 0 ] || [ -z "$source_data" ]; then
    print_error "Failed to fetch source data"
    exit 1
fi

source_count=$(echo "$source_data" | jq 'length')
print_info "Found $source_count records in source"

if [ "$source_count" -eq 0 ]; then
    print_warning "No records found in source"
    exit 0
fi

# Fetch destination data for diff
print_info "Fetching destination records..."
dest_data=$(sync_fetch_remote "$dst_server" "$dst_tenant" "$dst_schema" "")

if [ $? -ne 0 ]; then
    print_error "Failed to fetch destination data"
    exit 1
fi

dest_count=$(echo "$dest_data" | jq 'length')
print_info "Found $dest_count records in destination"

# Compute diff
print_info "Computing differences..."
diff_json=$(sync_compute_diff "$source_data" "$dest_data")

if [ $? -ne 0 ]; then
    print_error "Failed to compute diff"
    exit 1
fi

# Show summary
echo ""
sync_format_diff "$diff_json" "summary"
echo ""

# Extract operation counts
to_insert=$(echo "$diff_json" | jq -r '.summary.to_insert')
to_update=$(echo "$diff_json" | jq -r '.summary.to_update')
to_delete=$(echo "$diff_json" | jq -r '.summary.to_delete')
unchanged=$(echo "$diff_json" | jq -r '.summary.unchanged')

# Calculate total changes
total_changes=$((to_insert + to_update + to_delete))

if [ "$total_changes" -eq 0 ]; then
    print_success "No changes needed - datasets are identical"
    exit 0
fi

# Dry run mode
if [ "$dry_run" = "true" ]; then
    print_info "DRY RUN: Would apply $total_changes changes"
    print_success "Dry run completed (no changes made)"
    exit 0
fi

# Save current context
prev_server=$(get_current_server_name)
prev_tenant=$(get_current_tenant_name)

# Switch to destination context
if [ "$dst_server" != "$prev_server" ]; then
    switch_server "$dst_server" >/dev/null 2>&1 || {
        print_error "Failed to switch to destination server: $dst_server"
        exit 1
    }
fi

if [ "$dst_tenant" != "$prev_tenant" ]; then
    switch_tenant "$dst_tenant" >/dev/null 2>&1 || {
        print_error "Failed to switch to destination tenant: $dst_tenant"
        # Restore previous server
        [ -n "$prev_server" ] && switch_server "$prev_server" >/dev/null 2>&1
        exit 1
    }
fi

# Apply changes based on strategy
if [ "$strategy" = "replace" ]; then
    print_info "Applying replace strategy: delete all + insert all"
    
    # Delete all existing records (if any)
    if [ "$dest_count" -gt 0 ]; then
        print_info "Deleting $dest_count existing records..."
        delete_response=$(make_request_json "DELETE" "/api/data/$dst_schema" '{"where": {}}')
        
        if ! echo "$delete_response" | jq -e '.success == true' >/dev/null 2>&1; then
            print_error "Failed to delete existing records"
            echo "$delete_response" | jq -r '.error // "Unknown error"' >&2
            # Restore context
            [ -n "$prev_tenant" ] && switch_tenant "$prev_tenant" >/dev/null 2>&1
            [ -n "$prev_server" ] && switch_server "$prev_server" >/dev/null 2>&1
            exit 1
        fi
    fi
    
    # Insert all source records
    print_info "Inserting $source_count records..."
    import_response=$(make_request_json "PUT" "/api/data/$dst_schema" "$source_data")
    
elif [ "$strategy" = "merge" ]; then
    print_info "Applying merge strategy: upsert records"
    
    # Use bulk API for mixed operations
    operations="[]"
    
    # Add insert operations
    if [ "$to_insert" -gt 0 ]; then
        print_info "Preparing $to_insert insert operations..."
        operations=$(echo "$diff_json" | jq -c --arg schema "$dst_schema" '
            [.operations[] | select(.op == "insert") | {
                operation: "create-one",
                schema: $schema,
                data: .record
            }]
        ')
    fi
    
    # Add update operations
    if [ "$to_update" -gt 0 ]; then
        print_info "Preparing $to_update update operations..."
        updates=$(echo "$diff_json" | jq -c --arg schema "$dst_schema" '
            [.operations[] | select(.op == "update") | {
                operation: "update-one",
                schema: $schema,
                id: .id,
                data: .new
            }]
        ')
        operations=$(jq -n --argjson ops "$operations" --argjson updates "$updates" '$ops + $updates')
    fi
    
    # Execute bulk operations with new API format
    if [ "$operations" != "[]" ]; then
        print_info "Executing $(echo "$operations" | jq 'length') operations via bulk API..."
        wrapped_payload=$(echo "$operations" | jq '{operations: .}')
        bulk_response=$(make_request_json "POST" "/api/bulk" "$wrapped_payload")
        
        # Extract data from response
        if echo "$bulk_response" | jq -e '.success == true' >/dev/null 2>&1; then
            import_response=$(echo "$bulk_response" | jq '{success: true, data: .data}')
        else
            import_response="$bulk_response"
        fi
    else
        import_response='{"success": true, "message": "No operations to perform"}'
    fi
fi

# Restore previous context
[ -n "$prev_tenant" ] && switch_tenant "$prev_tenant" >/dev/null 2>&1
[ -n "$prev_server" ] && switch_server "$prev_server" >/dev/null 2>&1

# Check response
if echo "$import_response" | jq -e '.success == true' >/dev/null 2>&1; then
    print_success "Sync completed successfully"
    echo "$import_response" | jq '.'
else
    print_error "Sync failed"
    echo "$import_response" | jq '.'
    exit 1
fi
