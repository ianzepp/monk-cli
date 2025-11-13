#!/bin/bash

# sudo_users_delete_command.sh - Delete user via /api/sudo/users/:id

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for user operations"
    exit 1
fi

# Get user ID from args
user_id="${args[id]}"
force="${args[--force]}"

if [ -z "$user_id" ]; then
    print_error "User ID is required"
    exit 1
fi

# Confirm deletion unless --force is used
if [ "$force" != "1" ]; then
    echo
    print_warning "This will soft-delete the user: $user_id"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Delete cancelled"
        exit 0
    fi
fi

print_info "Deleting user: $user_id"

# Make request to sudo API
response=$(make_sudo_request "DELETE" "users/${user_id}" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    print_success "User deleted successfully"
    print_info_always "User ID: $user_id"
    
    # Show trashed_at if available
    trashed_at=$(echo "$response" | jq -r '.data.trashed_at // empty')
    if [ -n "$trashed_at" ]; then
        print_info_always "Trashed at: $trashed_at"
    fi
else
    print_error "Failed to delete user"
    echo "$response" >&2
    exit 1
fi
