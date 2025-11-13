#!/bin/bash

# sudo_users_update_command.sh - Update user via /api/sudo/users/:id

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for user operations"
    exit 1
fi

# Get user ID from args
user_id="${args[id]}"
name="${args[--name]}"
access="${args[--access]}"

if [ -z "$user_id" ]; then
    print_error "User ID is required"
    exit 1
fi

# Build update JSON with only provided fields
update_fields=()

if [ -n "$name" ]; then
    update_fields+=("--arg name \"$name\"")
    update_fields+=('.name = $name')
fi

if [ -n "$access" ]; then
    update_fields+=("--arg access \"$access\"")
    update_fields+=('.access = $access')
fi

if [ ${#update_fields[@]} -eq 0 ]; then
    print_error "At least one field must be provided (--name or --access)"
    exit 1
fi

# Build jq command for partial update
jq_args=""
jq_filter="{"
first=true

i=0
while [ $i -lt ${#update_fields[@]} ]; do
    field="${update_fields[$i]}"
    if [[ "$field" == --arg* ]]; then
        jq_args="$jq_args $field"
        i=$((i + 1))
        filter="${update_fields[$i]}"
        if [ "$first" = true ]; then
            jq_filter="$jq_filter $filter"
            first=false
        else
            jq_filter="$jq_filter, $filter"
        fi
    fi
    i=$((i + 1))
done

jq_filter="$jq_filter }"

print_info "Updating user: $user_id"

# Create update payload
update_data=$(eval "jq -n $jq_args '$jq_filter'")

# Make request to sudo API
response=$(make_sudo_request "PATCH" "users/${user_id}" "$update_data")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    # Extract updated user data
    user=$(echo "$response" | jq -r '.data')
    
    print_success "User updated successfully"
    print_info_always "User ID: $user_id"
    
    if [ -n "$name" ]; then
        print_info_always "Name: $name"
    fi
    
    if [ -n "$access" ]; then
        print_info_always "Access: $access"
    fi
else
    print_error "Failed to update user"
    echo "$response" >&2
    exit 1
fi
