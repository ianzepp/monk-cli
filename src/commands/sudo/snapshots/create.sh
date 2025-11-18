#!/bin/bash

# sudo_snapshots_create_command.sh - Create new snapshot via /api/sudo/snapshots

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for snapshot creation"
    exit 1
fi

# Get arguments from bashly flags
name="${args[--name]}"
description="${args[--description]}"
snapshot_type="${args[--type]}"
expires_in_days="${args[--expires-in-days]}"

print_info "Creating new snapshot (async operation)"

# Build snapshot creation JSON (all fields optional)
snapshot_data=$(jq -n \
    --arg name "${name:-}" \
    --arg description "${description:-}" \
    --arg snapshot_type "${snapshot_type:-manual}" \
    --arg expires_in_days "${expires_in_days:-}" \
    '{}' | \
    jq \
    --arg name "${name:-}" \
    --arg description "${description:-}" \
    --arg snapshot_type "${snapshot_type:-manual}" \
    --arg expires_in_days "${expires_in_days:-}" \
    '(if $name != "" then . + {"name": $name} else . end) |
     (if $description != "" then . + {"description": $description} else . end) |
     (if $snapshot_type != "" then . + {"snapshot_type": $snapshot_type} else . end) |
     (if $expires_in_days != "" then . + {"expires_in_days": ($expires_in_days | tonumber)} else . end)')

# Make request to sudo API
response=$(make_sudo_request "POST" "snapshots" "$snapshot_data")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    # Extract snapshot data
    snapshot=$(echo "$response" | jq -r '.data')
    snapshot_name=$(echo "$snapshot" | jq -r '.name')
    snapshot_database=$(echo "$snapshot" | jq -r '.database')
    snapshot_status=$(echo "$snapshot" | jq -r '.status')
    
    echo
    print_success "Snapshot queued successfully"
    echo
    print_warning "IMPORTANT: Snapshot creation is an ASYNC operation"
    print_warning "The snapshot is queued with status='pending' and will be processed in the background"
    echo
    print_info "Snapshot Name:    $snapshot_name"
    print_info "Database:         $snapshot_database"
    print_info "Status:           $snapshot_status"
    echo
    print_info "To check snapshot status:"
    print_info "  monk sudo snapshots show $snapshot_name"
    echo
    print_info "Status progression: pending → processing → active (or failed)"
    print_info "Poll every 5-10 seconds until status is 'active' or 'failed'"
    echo
else
    print_error "Failed to create snapshot"
    echo "$response" >&2
    exit 1
fi
