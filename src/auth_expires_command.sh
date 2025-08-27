#!/bin/bash

# auth_expires_command.sh - Show JWT token expiration time
#
# This command extracts and displays the expiration time from the current JWT token
# in a human-readable format.
#
# Usage Examples:
#   monk auth expires                    # Show expiration time
#   monk auth expires > expiry.txt       # Save expiration to file
#
# Output Format:
#   Displays the expiration date/time in local timezone
#   Example: "Wed Aug 28 15:30:45 PDT 2025"
#
# Requirements:
#   - Active authentication (JWT token available)
#   - base64 command for JWT decoding
#   - date command for timestamp formatting

# Check dependencies
check_dependencies

token=$(get_jwt_token)

if [ -z "$token" ]; then
    print_error "No authentication token found"
    print_info_always "Use 'monk auth login' or 'monk auth import' to authenticate"
    exit 1
fi

# Extract payload (second part) from JWT
payload=$(echo "$token" | cut -d'.' -f2)

# Add padding if needed for base64 decoding
padding=$((4 - ${#payload} % 4))
if [ $padding -ne 4 ]; then
    payload="${payload}$(printf '%*s' $padding '' | tr ' ' '=')"
fi

# Decode base64 payload
if command -v base64 >/dev/null 2>&1; then
    decoded=$(echo "$payload" | base64 -d 2>/dev/null || echo "")
else
    print_error "base64 command not found"
    exit 1
fi

if [ -n "$decoded" ]; then
    if command -v jq >/dev/null 2>&1; then
        exp_timestamp=$(echo "$decoded" | jq -r '.exp // empty' 2>/dev/null)
        if [ -n "$exp_timestamp" ] && [ "$exp_timestamp" != "null" ] && [ "$exp_timestamp" != "empty" ]; then
            exp_date=$(date -r "$exp_timestamp" 2>/dev/null || echo 'Invalid timestamp')
            echo "$exp_date"
        else
            print_error "No expiration timestamp found in JWT token"
            exit 1
        fi
    else
        print_error "jq required for JWT token parsing"
        exit 1
    fi
else
    print_error "Failed to decode JWT token"
    exit 1
fi