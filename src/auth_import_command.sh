#!/bin/bash

# auth_import_command.sh - Import JWT token from external auth flow
#
# This command allows users to manually store JWT tokens obtained from external
# authentication systems (OAuth, SSO, external tools, web UI, etc.) without
# going through the standard login flow.
#
# Usage Examples:
#   monk auth import tenant-a admin --token "eyJhbGciOiJIUzI1NiIs..."
#   echo "eyJhbGciOiJIUzI1NiIs..." | monk auth import tenant-a admin
#   cat jwt-token.txt | monk auth import my-tenant developer
#
# Input Methods:
#   1. Via --token/-t flag: Direct token parameter
#   2. Via stdin: Pipe token content (useful for scripting)
#
# Token Storage:
#   - Stores in current server+tenant context in auth.json
#   - Updates env.json with current tenant and user
#   - Validates token format (basic JWT structure check)
#   - Sets secure permissions on auth config file
#
# Use Cases:
#   - OAuth/SSO authentication flows
#   - External authentication tools
#   - Token sharing between environments  
#   - Manual token management for automation
#   - Development/testing with pre-generated tokens
#
# Requirements:
#   - Current server must be selected (monk server use <name>)
#   - Valid JWT token format (basic validation only)
#   - Tenant and username must be specified

# Check dependencies
check_dependencies

# Get arguments from bashly
tenant="${args[tenant]}"
username="${args[username]}"
token_flag="${args[--token]}"

print_info "Importing JWT token for tenant: $tenant, username: $username"

# Get token from flag or stdin
if [ -n "$token_flag" ]; then
    token="$token_flag"
    print_info "Using token from --token parameter"
else
    # Read token from stdin
    token=$(cat)
    if [ -z "$token" ]; then
        print_error "No JWT token provided"
        print_info "Usage: monk auth import <tenant> <username> --token <jwt>"
        print_info "   or: echo '<jwt>' | monk auth import <tenant> <username>"
        exit 1
    fi
    print_info "Using token from stdin"
fi

# Basic JWT format validation (should have 3 parts separated by dots)
if ! echo "$token" | grep -q '^[^.]*\.[^.]*\.[^.]*$'; then
    print_error "Invalid JWT token format"
    print_info "JWT tokens should have format: header.payload.signature"
    exit 1
fi

# Store the token using the same mechanism as login
store_token "$token" "$tenant" "$username"

print_success "JWT token imported successfully"
print_info_always "Token stored for server+tenant context"

# Show current context
if [ "$CLI_VERBOSE" = "true" ]; then
    current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    print_info "Context: server=$current_server, tenant=$tenant, user=$username"
fi