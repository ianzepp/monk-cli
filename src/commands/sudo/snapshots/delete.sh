#!/bin/bash

# sudo_snapshots_delete_command.sh - Delete snapshot via /api/sudo/snapshots/:name

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for snapshot deletion"
    exit 1
fi

# Get arguments from bashly
name="${args[name]}"
force_flag="${args[--force]}"

# Validate required fields
if [ -z "$name" ]; then
    print_error "Snapshot name is required"
    exit 1
fi

# Confirm deletion unless --force is used
confirm_destructive_operation "delete" "snapshot '$name'" "$force_flag"

print_info "Deleting snapshot: $name"

# Make request to sudo API
response=$(make_sudo_request "DELETE" "snapshots/$name" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    print_success "Snapshot '$name' deleted successfully"
    print_info "The snapshot database has been permanently removed"
else
    print_error "Failed to delete snapshot"
    echo "$response" >&2
    exit 1
fi
