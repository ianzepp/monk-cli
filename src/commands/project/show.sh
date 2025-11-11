#!/bin/bash

# project_show_command.sh - Show project details

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"

if [[ -z "$name" ]]; then
    print_error "Project name is required"
    exit 1
fi

# Get tenant details from root API
encoded_name=$(url_encode "$name")
response=$(make_root_request "GET" "tenant/$encoded_name")

if ! echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_error "Failed to get project details: $error_msg"
    exit 1
fi

tenant=$(echo "$response" | jq -r '.tenant')

if [[ "$format_json" == "1" ]]; then
    # JSON output - return tenant details
    echo "$response" | jq '{success: true, project: .tenant}'
else
    # Text output - format nicely
    name=$(echo "$tenant" | jq -r '.name')
    status=$(echo "$tenant" | jq -r '.status // "active"')
    database=$(echo "$tenant" | jq -r '.database // "unknown"')
    host=$(echo "$tenant" | jq -r '.host // "localhost"')
    created=$(echo "$tenant" | jq -r '.created_at // "unknown"')
    updated=$(echo "$tenant" | jq -r '.updated_at // "unknown"')
    trashed=$(echo "$tenant" | jq -r '.trashed_at // null')
    deleted=$(echo "$tenant" | jq -r '.deleted_at // null')
    
    echo
    echo "Project: $name"
    echo "Status: $status"
    echo "Database: $database"
    echo "Host: $host"
    
    if [[ "$created" != "null" && "$created" != "unknown" ]]; then
        created_date=$(date -d "$created" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || echo "$created")
        echo "Created: $created_date"
    fi
    
    if [[ "$updated" != "null" && "$updated" != "unknown" && "$updated" != "$created" ]]; then
        updated_date=$(date -d "$updated" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || echo "$updated")
        echo "Updated: $updated_date"
    fi
    
    if [[ "$trashed" != "null" ]]; then
        trashed_date=$(date -d "$trashed" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || echo "$trashed")
        echo "Trashed: $trashed_date"
    fi
    
    if [[ "$deleted" != "null" ]]; then
        deleted_date=$(date -d "$deleted" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || echo "$deleted")
        echo "Deleted: $deleted_date"
    fi
    
# Check if this is the current project
init_cli_configs
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    
    echo
    if [[ "$name" == "$current_tenant" ]]; then
        echo "✓ This is your current project (server: $current_server)"
        echo
        echo "Quick actions:"
        echo "  monk data select          # List available schemas"
        echo "  monk describe select      # Show schema definitions"
        echo "  monk fs ls /data/         # Browse data"
    else
        echo "→ Switch to this project: monk project use $name"
    fi
    
    # Show project metadata if available
    project_file="${CLI_CONFIG_DIR}/projects.json"
    if [[ -f "$project_file" ]]; then
        project_meta=$(jq -r --arg name "$name" '.projects[] | select(.name == $name)' "$project_file")
        if [[ -n "$project_meta" && "$project_meta" != "null" ]]; then
            description=$(echo "$project_meta" | jq -r '.description // empty')
            tags=$(echo "$project_meta" | jq -r '.tags // [] | join(", ") // empty')
            
            if [[ -n "$description" ]]; then
                echo "Description: $description"
            fi
            
            if [[ -n "$tags" ]]; then
                echo "Tags: $tags"
            fi
        fi
    fi
fi