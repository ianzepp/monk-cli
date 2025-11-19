#!/bin/bash

# sudo_sandboxes_show_command.sh - Show sandbox details via /api/sudo/sandboxes/:name

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for sandbox details"
    exit 1
fi

# Get arguments from bashly
name="${args[name]}"

# Validate required fields
if [ -z "$name" ]; then
    print_error "Sandbox name is required"
    exit 1
fi

# Determine output format from global flags
output_format=$(get_output_format "text")

print_info "Getting details for sandbox: $name"

# Make request to sudo API
response=$(make_sudo_request "GET" "sandboxes/$name" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    if [[ "$output_format" == "text" ]]; then
        # Human-readable output
        sandbox=$(echo "$response" | jq -r '.data')
        
        echo
        print_success "Sandbox Details"
        echo
        
        echo "Name:             $(echo "$sandbox" | jq -r '.name')"
        echo "Database:         $(echo "$sandbox" | jq -r '.database')"
        
        description=$(echo "$sandbox" | jq -r '.description // "N/A"')
        echo "Description:      $description"
        
        parent_template=$(echo "$sandbox" | jq -r '.parent_template // "N/A"')
        echo "Template:         $parent_template"
        
        parent_tenant_id=$(echo "$sandbox" | jq -r '.parent_tenant_id // "N/A"')
        echo "Parent Tenant ID: $parent_tenant_id"
        
        created_by=$(echo "$sandbox" | jq -r '.created_by // "N/A"')
        echo "Created By:       $created_by"
        
        created_at=$(echo "$sandbox" | jq -r '.created_at // "N/A"')
        echo "Created At:       $created_at"
        
        expires_at=$(echo "$sandbox" | jq -r '.expires_at // "N/A"')
        echo "Expires At:       $expires_at"
        
        last_accessed=$(echo "$sandbox" | jq -r '.last_accessed_at // "N/A"')
        echo "Last Accessed:    $last_accessed"
        
        is_active=$(echo "$sandbox" | jq -r '.is_active // false')
        echo "Active:           $is_active"
        
        echo
    else
        # JSON output - pass through
        handle_response_json "$response" "select"
    fi
else
    print_error "Failed to retrieve sandbox details"
    echo "$response" >&2
    exit 1
fi
