#!/bin/bash

# sudo_templates_show_command.sh - Show template details via /api/sudo/templates/:name

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for template details"
    exit 1
fi

# Get arguments from bashly
name="${args[name]}"

# Validate required fields
if [ -z "$name" ]; then
    print_error "Template name is required"
    exit 1
fi

# Determine output format from global flags
output_format=$(get_output_format "text")

print_info "Getting details for template: $name"

# Make request to sudo API
response=$(make_sudo_request "GET" "templates/$name" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    if [[ "$output_format" == "text" ]]; then
        # Human-readable output
        template=$(echo "$response" | jq -r '.data')
        
        echo
        print_success "Template Details"
        echo
        
        echo "Name:             $(echo "$template" | jq -r '.name')"
        echo "Database:         $(echo "$template" | jq -r '.database')"
        
        description=$(echo "$template" | jq -r '.description // "N/A"')
        echo "Description:      $description"
        
        parent=$(echo "$template" | jq -r '.parent_template // "N/A"')
        echo "Parent Template:  $parent"
        
        is_system=$(echo "$template" | jq -r '.is_system // false')
        echo "System Template:  $is_system"
        
        schema_count=$(echo "$template" | jq -r '.schema_count // 0')
        echo "Schema Count:     $schema_count"
        
        record_count=$(echo "$template" | jq -r '.record_count // 0')
        echo "Record Count:     $record_count"
        
        size_bytes=$(echo "$template" | jq -r '.size_bytes // 0')
        if [ "$size_bytes" -gt 0 ]; then
            size_mb=$((size_bytes / 1024 / 1024))
            echo "Size:             ${size_mb} MB"
        fi
        
        created_at=$(echo "$template" | jq -r '.created_at // "N/A"')
        echo "Created At:       $created_at"
        
        echo
    else
        # JSON output - pass through
        handle_response_json "$response" "select"
    fi
else
    print_error "Failed to retrieve template details"
    echo "$response" >&2
    exit 1
fi
