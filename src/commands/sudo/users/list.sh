#!/bin/bash

# sudo_users_list_command.sh - List all users via /api/sudo/users

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for user listing"
    exit 1
fi

# Determine output format from global flags
output_format=$(get_output_format "text")

# Make request to sudo API
response=$(make_sudo_request "GET" "users" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    if [[ "$output_format" == "text" ]]; then
        # Human-readable table output
        users=$(echo "$response" | jq -r '.data')
        count=$(echo "$users" | jq 'length')
        
        echo
        print_info "Total users: $count"
        echo
        
        if [[ "$count" -gt 0 ]]; then
            printf "%-36s %-30s %-30s %-10s\n" "ID" "NAME" "AUTH" "ACCESS"
            echo "--------------------------------------------------------------------------------"
            
            echo "$users" | jq -r '.[] | [.id, .name, .auth, .access] | @tsv' | \
            while IFS=$'\t' read -r id name auth access; do
                printf "%-36s %-30s %-30s %-10s\n" "$id" "$name" "$auth" "$access"
            done
        else
            print_info "No users found"
        fi
        echo
    else
        # JSON output - pass through compact JSON
        handle_output "$response" "$output_format" "json"
    fi
else
    print_error "Failed to retrieve users"
    echo "$response" >&2
    exit 1
fi
