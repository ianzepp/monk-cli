#!/bin/bash

# sudo_sandboxes_delete_command.sh - Delete sandbox via /api/sudo/sandboxes/:name

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for sandbox deletion"
    exit 1
fi

# Get arguments from bashly
name="${args[name]}"
force_flag="${args[--force]}"

# Validate required fields
if [ -z "$name" ]; then
    print_error "Sandbox name is required"
    exit 1
fi

# Confirm deletion unless --force is used
confirm_destructive_operation "delete" "sandbox '$name'" "$force_flag"

print_info "Deleting sandbox: $name"

# Make request to sudo API
response=$(make_sudo_request "DELETE" "sandboxes/$name" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    print_success "Sandbox '$name' deleted successfully"
    print_info "The sandbox database has been permanently removed"
else
    print_error "Failed to delete sandbox"
    echo "$response" >&2
    exit 1
fi
