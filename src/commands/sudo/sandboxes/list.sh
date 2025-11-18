#!/bin/bash

# sudo_sandboxes_list_command.sh - List all sandboxes via /api/sudo/sandboxes

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for sandbox listing"
    exit 1
fi

# Determine output format from global flags
output_format=$(get_output_format "text")

print_info "Listing all sandboxes in current tenant"

# Make request to sudo API
response=$(make_sudo_request "GET" "sandboxes" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    if [[ "$output_format" == "text" ]]; then
        # Human-readable table output
        sandboxes=$(echo "$response" | jq -r '.data')
        count=$(echo "$sandboxes" | jq 'length')
        
        echo
        print_info "Total sandboxes: $count"
        echo
        
        if [[ "$count" -gt 0 ]]; then
            printf "%-30s %-35s %-15s %-20s %-10s\n" "NAME" "DATABASE" "TEMPLATE" "EXPIRES" "ACTIVE"
            echo "------------------------------------------------------------------------------------------------------------"
            
            echo "$sandboxes" | jq -r '.[] | [.name, .database, (.parent_template // ""), (.expires_at // ""), (.is_active // false)] | @tsv' | \
            while IFS=$'\t' read -r name database template expires active; do
                # Format expiration date (show only date portion)
                if [ -n "$expires" ] && [ "$expires" != "null" ]; then
                    expires="${expires:0:10}"
                fi
                printf "%-30s %-35s %-15s %-20s %-10s\n" "$name" "$database" "$template" "$expires" "$active"
            done
        else
            print_info "No sandboxes found"
        fi
        echo
    else
        # JSON output - pass through
        handle_response_json "$response" "list"
    fi
else
    print_error "Failed to retrieve sandboxes"
    echo "$response" >&2
    exit 1
fi
