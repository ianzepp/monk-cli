#!/bin/bash

# sudo_templates_list_command.sh - List all templates via /api/sudo/templates

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for template listing"
    exit 1
fi

# Determine output format from global flags
output_format=$(get_output_format "text")

print_info "Listing all available templates"

# Make request to sudo API
response=$(make_sudo_request "GET" "templates" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    if [[ "$output_format" == "text" ]]; then
        # Human-readable table output
        templates=$(echo "$response" | jq -r '.data')
        count=$(echo "$templates" | jq 'length')
        
        echo
        print_info "Total templates: $count"
        echo
        
        if [[ "$count" -gt 0 ]]; then
            printf "%-25s %-30s %-15s %-10s %-10s %-10s\n" "NAME" "DATABASE" "DESCRIPTION" "SCHEMAS" "RECORDS" "SYSTEM"
            echo "--------------------------------------------------------------------------------------------------------"
            
            echo "$templates" | jq -r '.[] | [.name, .database, (.description // ""), (.schema_count // 0), (.record_count // 0), (.is_system // false)] | @tsv' | \
            while IFS=$'\t' read -r name database description schemas records is_system; do
                # Truncate description if too long
                if [ ${#description} -gt 15 ]; then
                    description="${description:0:12}..."
                fi
                printf "%-25s %-30s %-15s %-10s %-10s %-10s\n" "$name" "$database" "$description" "$schemas" "$records" "$is_system"
            done
        else
            print_info "No templates found"
        fi
        echo
    else
        # JSON output - pass through
        handle_response_json "$response" "list"
    fi
else
    print_error "Failed to retrieve templates"
    echo "$response" >&2
    exit 1
fi
