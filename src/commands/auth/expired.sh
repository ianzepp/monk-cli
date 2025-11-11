#!/bin/bash

# auth_expired_command.sh - Check if JWT token is expired (exit code based)
#
# This command checks if the current JWT token has expired and returns
# appropriate exit codes for scripting and automation.
#
# Usage Examples:
#   monk auth expired && echo "Token valid"
#   if monk auth expired; then echo "Need to re-authenticate"; fi
#   monk auth expired || monk auth login tenant user
#
# Exit Codes:
#   0: Token is valid (not expired)
#   1: Token is expired or no token found
#   1: Error in token processing
#
# Output:
#   Minimal output by design - primarily for scripting
#   Use 'monk auth expires' for human-readable expiration time
#
# Requirements:
#   - Active authentication (JWT token available)
#   - base64 command for JWT decoding
#   - date command for timestamp comparison

# Check dependencies
check_dependencies

token=$(get_jwt_token)

if [ -z "$token" ]; then
    # No token found
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
    # Can't decode - assume expired for safety
    exit 1
fi

if [ -n "$decoded" ]; then
    if command -v jq >/dev/null 2>&1; then
        exp_timestamp=$(echo "$decoded" | jq -r '.exp // empty' 2>/dev/null)
        if [ -n "$exp_timestamp" ] && [ "$exp_timestamp" != "null" ] && [ "$exp_timestamp" != "empty" ]; then
            current_timestamp=$(date +%s)
            
            if [ "$exp_timestamp" -gt "$current_timestamp" ]; then
                # Token is still valid
                exit 0
            else
                # Token is expired
                exit 1
            fi
        else
            # No expiration found - assume expired for safety
            exit 1
        fi
    else
        # No jq - can't parse - assume expired for safety
        exit 1
    fi
else
    # Failed to decode - assume expired for safety
    exit 1
fi