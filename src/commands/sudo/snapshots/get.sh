#!/bin/bash

# sudo_snapshots_show_command.sh - Show snapshot details via /api/sudo/snapshots/:name

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for snapshot details"
    exit 1
fi

# Get arguments from bashly
name="${args[name]}"

# Validate required fields
if [ -z "$name" ]; then
    print_error "Snapshot name is required"
    exit 1
fi

# Determine output format from global flags
output_format=$(get_output_format "text")

print_info "Getting details for snapshot: $name"

# Make request to sudo API
response=$(make_sudo_request "GET" "snapshots/$name" "")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    if [[ "$output_format" == "text" ]]; then
        # Human-readable output
        snapshot=$(echo "$response" | jq -r '.data')
        
        echo
        print_success "Snapshot Details"
        echo
        
        snapshot_name=$(echo "$snapshot" | jq -r '.name')
        echo "Name:             $snapshot_name"
        
        database=$(echo "$snapshot" | jq -r '.database // "N/A"')
        echo "Database:         $database"
        
        status=$(echo "$snapshot" | jq -r '.status')
        echo "Status:           $status"
        
        # Provide status-specific guidance
        case "$status" in
            pending)
                print_warning "Snapshot is queued for processing"
                print_info "Poll this command again in a few seconds"
                ;;
            processing)
                print_warning "Snapshot backup is in progress"
                print_info "Poll this command again in a few seconds"
                ;;
            active)
                print_success "Snapshot is complete and available"
                ;;
            failed)
                print_error "Snapshot creation failed"
                ;;
        esac
        
        description=$(echo "$snapshot" | jq -r '.description // "N/A"')
        echo "Description:      $description"
        
        snapshot_type=$(echo "$snapshot" | jq -r '.snapshot_type // "N/A"')
        echo "Type:             $snapshot_type"
        
        size_bytes=$(echo "$snapshot" | jq -r '.size_bytes // 0')
        if [ "$size_bytes" -gt 0 ]; then
            size_mb=$((size_bytes / 1024 / 1024))
            echo "Size:             ${size_mb} MB"
        fi
        
        record_count=$(echo "$snapshot" | jq -r '.record_count // 0')
        if [ "$record_count" -gt 0 ]; then
            echo "Record Count:     $record_count"
        fi
        
        created_by=$(echo "$snapshot" | jq -r '.created_by // "N/A"')
        echo "Created By:       $created_by"
        
        created_at=$(echo "$snapshot" | jq -r '.created_at // "N/A"')
        echo "Created At:       $created_at"
        
        updated_at=$(echo "$snapshot" | jq -r '.updated_at // "N/A"')
        if [ "$updated_at" != "N/A" ] && [ "$updated_at" != "$created_at" ]; then
            echo "Updated At:       $updated_at"
        fi
        
        expires_at=$(echo "$snapshot" | jq -r '.expires_at // "N/A"')
        if [ "$expires_at" != "N/A" ] && [ "$expires_at" != "null" ]; then
            echo "Expires At:       $expires_at"
        fi
        
        # Show error message if failed
        if [ "$status" = "failed" ]; then
            error_message=$(echo "$snapshot" | jq -r '.error_message // "Unknown error"')
            echo
            print_error "Error Message:    $error_message"
        fi
        
        echo
    else
        # JSON output - pass through
        handle_response_json "$response" "select"
    fi
else
    print_error "Failed to retrieve snapshot details"
    echo "$response" >&2
    exit 1
fi
