#!/bin/bash

# sudo_users_create_command.sh - Create new user via /api/sudo/users

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for user creation"
    exit 1
fi

# Get arguments from bashly flags
name="${args[--name]}"
auth="${args[--auth]}"
access="${args[--access]}"

# Validate required fields
if [ -z "$name" ]; then
    print_error "Name is required (--name)"
    exit 1
fi

if [ -z "$auth" ]; then
    print_error "Auth identifier is required (--auth)"
    exit 1
fi

if [ -z "$access" ]; then
    print_error "Access level is required (--access)"
    exit 1
fi

print_info "Creating user: $name ($auth) with access level: $access"

# Build user creation JSON
user_data=$(jq -n \
    --arg name "$name" \
    --arg auth "$auth" \
    --arg access "$access" \
    '{
        "name": $name,
        "auth": $auth,
        "access": $access,
        "access_read": [],
        "access_edit": [],
        "access_full": []
    }')

# Make request to sudo API
response=$(make_sudo_request "POST" "users" "$user_data")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    # Extract user data
    user=$(echo "$response" | jq -r '.data')
    user_id=$(echo "$user" | jq -r '.id')
    
    print_success "User created successfully"
    print_info_always "User ID: $user_id"
    print_info_always "Name: $name"
    print_info_always "Auth: $auth"
    print_info_always "Access: $access"
else
    print_error "Failed to create user"
    echo "$response" >&2
    exit 1
fi
