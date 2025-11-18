#!/bin/bash

# sudo_sandboxes_create_command.sh - Create new sandbox via /api/sudo/sandboxes

# Check dependencies
check_dependencies

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for sandbox creation"
    exit 1
fi

# Get arguments from bashly flags
template="${args[--template]}"
description="${args[--description]}"
expires_in_days="${args[--expires-in-days]}"

# Validate required fields
if [ -z "$template" ]; then
    print_error "Template name is required (--template)"
    exit 1
fi

print_info "Creating sandbox from template: $template"

# Build sandbox creation JSON
sandbox_data=$(jq -n \
    --arg template "$template" \
    --arg description "${description:-}" \
    --arg expires_in_days "${expires_in_days:-7}" \
    '{
        "template": $template
    } +
    (if $description != "" then {"description": $description} else {} end) +
    (if $expires_in_days != "" then {"expires_in_days": ($expires_in_days | tonumber)} else {} end)')

# Make request to sudo API
response=$(make_sudo_request "POST" "sandboxes" "$sandbox_data")

if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    # Extract sandbox data
    sandbox=$(echo "$response" | jq -r '.data')
    sandbox_name=$(echo "$sandbox" | jq -r '.name')
    sandbox_database=$(echo "$sandbox" | jq -r '.database')
    expires_at=$(echo "$sandbox" | jq -r '.expires_at')
    
    echo
    print_success "Sandbox created successfully"
    echo
    print_info "Sandbox Name:     $sandbox_name"
    print_info "Database:         $sandbox_database"
    print_info "Template:         $template"
    print_info "Expires At:       $expires_at"
    echo
    print_info "Next steps:"
    print_info "  1. Login to sandbox tenant with: monk auth login $sandbox_name <username>"
    print_info "  2. Switch context with: monk use <server> $sandbox_name"
    print_info "  3. Use sandbox for testing"
    print_info "  4. Delete when done with: monk sudo sandboxes delete $sandbox_name"
    echo
else
    print_error "Failed to create sandbox"
    echo "$response" >&2
    exit 1
fi
