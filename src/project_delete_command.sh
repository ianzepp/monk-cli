#!/bin/bash

# project_delete_command.sh - Delete project (soft delete by default)

# Check dependencies
check_dependencies

# Get arguments from bashly
name="${args[name]}"
force="${args[--force]}"
permanent="${args[--permanent]}"

if [[ -z "$name" ]]; then
    print_error "Project name is required"
    exit 1
fi

# Check if project exists
encoded_name=$(url_encode "$name")
response=$(make_root_request "GET" "tenant/$encoded_name")

if ! echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_error "Project '$name' not found: $error_msg"
    exit 1
fi

tenant=$(echo "$response" | jq -r '.tenant')
status=$(echo "$tenant" | jq -r '.status // "active"')

# Check if already deleted
if [[ "$status" == "deleted" ]]; then
    print_error "Project '$name' is already permanently deleted"
    exit 1
fi

# Determine deletion type
if [[ "$permanent" == "1" ]]; then
    delete_type="permanent"
    action="delete"
    warning="DANGER: This will PERMANENTLY delete project '$name' and all its data!"
else
    delete_type="soft"
    action="trash"
    warning="This will move project '$name' to trash (can be restored)"
fi

# Confirmation prompt
if [[ "$force" != "1" ]]; then
    echo "$warning"
    echo "Type 'DELETE' to confirm:"
    read -r confirmation
    if [[ "$confirmation" != "DELETE" ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# Perform deletion
print_info "Deleting project '$name' ($delete_type deletion)..."

if [[ "$permanent" == "1" ]]; then
    # Hard delete
    delete_response=$(make_root_request "DELETE" "tenant/$encoded_name?force=true")
else
    # Soft delete (trash)
    delete_response=$(make_root_request "DELETE" "tenant/$encoded_name")
fi

if echo "$delete_response" | jq -e '.success' >/dev/null 2>&1; then
    if [[ "$permanent" == "1" ]]; then
        print_success "Project '$name' permanently deleted"
        
# Remove from local registry
init_cli_configs
current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
if [[ -n "$current_server" && "$current_server" != "null" ]]; then
    tenant_info=$(jq -r ".tenants.\"$name\"" "$TENANT_CONFIG" 2>/dev/null)
    if [[ "$tenant_info" != "null" ]]; then
        temp_file=$(mktemp)
        jq --arg name "$name" 'del(.tenants[$name])' "$TENANT_CONFIG" > "$temp_file" && mv "$temp_file" "$TENANT_CONFIG"
        print_info "Removed from local registry"
    fi
fi
        
        # Remove from project metadata
        project_file="${CLI_CONFIG_DIR}/projects.json"
        if [[ -f "$project_file" ]]; then
            temp_file=$(mktemp)
            jq --arg name "$name" '.projects |= map(select(.name != $name))' "$project_file" > "$temp_file"
            mv "$temp_file" "$project_file"
        fi
        
# Clear context if this was the current project
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
if [[ "$current_tenant" == "$name" ]]; then
    temp_file=$(mktemp)
    jq 'del(.current_tenant)' "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"
    print_info "Cleared current project context"
fi
    else
        print_success "Project '$name' moved to trash"
        print_info "Restore with: monk root tenant restore $name"
        print_info "Permanent delete with: monk project delete $name --permanent"
    fi
else
    error_msg=$(echo "$delete_response" | jq -r '.error // "Unknown error"')
    print_error "Failed to delete project: $error_msg"
    exit 1
fi