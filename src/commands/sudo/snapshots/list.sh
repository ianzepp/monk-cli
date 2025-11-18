#!/bin/bash

# sudo_snapshots_list_command.sh - List all snapshots via /api/sudo/snapshots

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for snapshot listing"
    exit 1
fi

# Determine output format from global flags
output_format=$(get_output_format "text")

print_info "Listing all snapshots in current tenant"

# Make request to sudo API
response=$(make_sudo_request "GET" "snapshots" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    if [[ "$output_format" == "text" ]]; then
        # Human-readable table output
        snapshots=$(echo "$response" | jq -r '.data')
        count=$(echo "$snapshots" | jq 'length')
        
        echo
        print_info "Total snapshots: $count"
        echo
        
        if [[ "$count" -gt 0 ]]; then
            printf "%-30s %-35s %-12s %-15s %-10s %-20s\n" "NAME" "DATABASE" "STATUS" "TYPE" "SIZE (MB)" "CREATED"
            echo "----------------------------------------------------------------------------------------------------------------------------"
            
            echo "$snapshots" | jq -r '.[] | [.name, .database, .status, (.snapshot_type // ""), (.size_bytes // 0), (.created_at // "")] | @tsv' | \
            while IFS=$'\t' read -r name database status type size_bytes created; do
                # Convert size to MB
                size_mb=0
                if [ "$size_bytes" -gt 0 ]; then
                    size_mb=$((size_bytes / 1024 / 1024))
                fi
                
                # Format created date (show only date portion)
                if [ -n "$created" ] && [ "$created" != "null" ]; then
                    created="${created:0:10}"
                fi
                
                printf "%-30s %-35s %-12s %-15s %-10s %-20s\n" "$name" "$database" "$status" "$type" "$size_mb" "$created"
            done
        else
            print_info "No snapshots found"
        fi
        echo
    else
        # JSON output - pass through
        handle_response_json "$response" "list"
    fi
else
    print_error "Failed to retrieve snapshots"
    echo "$response" >&2
    exit 1
fi
