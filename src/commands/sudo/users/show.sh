#!/bin/bash

# sudo_users_show_command.sh - Show user details via /api/sudo/users/:id

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for user operations"
    exit 1
fi

# Get user ID from args
user_id="${args[id]}"

if [ -z "$user_id" ]; then
    print_error "User ID is required"
    exit 1
fi

print_info "Fetching user details for: $user_id"

# Determine output format from global flags
output_format=$(get_output_format "text")

# Make request to sudo API
response=$(make_sudo_request "GET" "users/${user_id}" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    if [[ "$output_format" == "text" ]]; then
        # Human-readable output
        user=$(echo "$response" | jq -r '.data')
        
        echo
        print_success "User Details"
        echo
        echo "ID:          $(echo "$user" | jq -r '.id')"
        echo "Name:        $(echo "$user" | jq -r '.name')"
        echo "Auth:        $(echo "$user" | jq -r '.auth')"
        echo "Access:      $(echo "$user" | jq -r '.access')"
        echo "Created:     $(echo "$user" | jq -r '.created_at')"
        echo "Updated:     $(echo "$user" | jq -r '.updated_at')"
        echo
    else
        # JSON output - pass through compact JSON
        handle_output "$response" "$output_format" "json"
    fi
else
    print_error "Failed to retrieve user details"
    echo "$response" >&2
    exit 1
fi
