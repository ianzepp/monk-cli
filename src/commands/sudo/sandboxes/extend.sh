#!/bin/bash

# sudo_sandboxes_extend_command.sh - Extend sandbox expiration via /api/sudo/sandboxes/:name/extend

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for extending sandbox"
    exit 1
fi

# Get arguments from bashly
name="${args[name]}"
days="${args[--days]}"

# Validate required fields
if [ -z "$name" ]; then
    print_error "Sandbox name is required"
    exit 1
fi

if [ -z "$days" ]; then
    print_error "Number of days is required (--days)"
    exit 1
fi

print_info "Extending sandbox '$name' by $days days"

# Build extend JSON
extend_data=$(jq -n \
    --arg days "$days" \
    '{
        "days": ($days | tonumber)
    }')

# Make request to sudo API
response=$(make_sudo_request "POST" "sandboxes/$name/extend" "$extend_data")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    # Extract new expiration date
    new_expires=$(echo "$response" | jq -r '.data.expires_at')
    
    echo
    print_success "Sandbox expiration extended successfully"
    echo
    print_info "Sandbox:      $name"
    print_info "New Expires:  $new_expires"
    echo
else
    print_error "Failed to extend sandbox expiration"
    echo "$response" >&2
    exit 1
fi
