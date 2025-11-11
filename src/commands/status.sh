#!/bin/bash

# status_command.sh - Show comprehensive CLI status and environment overview

# Check dependencies
check_dependencies

init_cli_configs

# Determine output format from global flags
output_format=$(get_output_format "text")

# Get current context information
current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
current_user=$(jq -r '.current_user // empty' "$ENV_CONFIG" 2>/dev/null)

# Get server details if one is selected
server_info=""
server_status="No server selected"
server_endpoint=""
server_health=""

if [[ -n "$current_server" ]]; then
    server_info=$(jq -r ".servers.\"$current_server\"" "$SERVER_CONFIG" 2>/dev/null)
    if [[ -n "$server_info" ]]; then
        hostname=$(echo "$server_info" | jq -r '.hostname')
        port=$(echo "$server_info" | jq -r '.port')
        protocol=$(echo "$server_info" | jq -r '.protocol')
        server_endpoint="$protocol://$hostname:$port"

        # Check server health using /health endpoint (same as server health command)
        if curl -s --max-time 5 --fail "$server_endpoint/health" >/dev/null 2>&1; then
            server_status="Up"
            server_health="✓ Healthy"
        else
            server_status="Down"
            server_health="✗ Unreachable"
        fi
    else
        server_status="Server config missing"
    fi
fi

# Get authentication status
auth_status="Not authenticated"
user_details=""
access_level=""

if [[ -n "$current_server" && -n "$current_tenant" ]]; then
    # Check if we have a valid token for this server/tenant combination
    # (store_token uses server:tenant format)
    session_key="${current_server}:${current_tenant}"
    session_info=$(jq -r ".sessions.\"$session_key\"" "$AUTH_CONFIG" 2>/dev/null)

    if [[ -n "$session_info" && "$session_info" != "null" ]]; then
        token=$(echo "$session_info" | jq -r '.jwt_token // empty')

        if [[ -n "$token" ]]; then
            # Check if token is expired (same logic as auth_expired_command.sh)
            # Extract payload (second part) from JWT
            payload=$(echo "$token" | cut -d'.' -f2)

            # Add padding if needed for base64 decoding
            padding=$((4 - ${#payload} % 4))
            if [ $padding -ne 4 ]; then
                payload="${payload}$(printf '%*s' $padding '' | tr ' ' '=')"
            fi

            # Decode base64 payload
            if decoded=$(echo "$payload" | base64 -d 2>/dev/null); then
                if exp_timestamp=$(echo "$decoded" | jq -r '.exp // empty' 2>/dev/null); then
                    if [ -n "$exp_timestamp" ] && [ "$exp_timestamp" != "null" ] && [ "$exp_timestamp" != "empty" ]; then
                        current_timestamp=$(date +%s)

                        if [ "$exp_timestamp" -gt "$current_timestamp" ]; then
                            # Token is still valid
                            auth_status="Authenticated"
                            user_details="$current_user@$current_tenant"

                            # Try to get user role/access level from token
                            if command -v jq >/dev/null 2>&1; then
                                role=$(echo "$decoded" | jq -r '.access // empty' 2>/dev/null)
                                if [[ -n "$role" && "$role" != "null" ]]; then
                                    access_level="$role"
                                fi
                            fi
                        else
                            # Token is expired
                            auth_status="Token expired"
                        fi
                    else
                        # No expiration found - assume expired for safety
                        auth_status="Token expired"
                    fi
                else
                    # Failed to parse JSON - assume expired for safety
                    auth_status="Token expired"
                fi
            else
                # Failed to decode - assume expired for safety
                auth_status="Token expired"
            fi
        fi
    fi
fi

# Get schemas if server is up and we're authenticated
schemas=""
schema_count=0

if [[ "$server_status" == "Up" && "$auth_status" == "Authenticated" ]]; then
    # Try to get schemas from the API using GET /api/describe
    api_response=$(make_request_json "GET" "/api/describe" "")
    if [[ $? -eq 0 ]]; then
        # Extract the data array which contains schema names
        schemas=$(echo "$api_response" | jq -r '.data[]' 2>/dev/null | sort)
        if [[ -n "$schemas" ]]; then
            schema_count=$(echo "$schemas" | grep -c '^' | tr -d ' ')
        else
            schema_count=0
            schemas="No schemas found"
        fi
    else
        schemas="Unable to fetch schemas"
    fi
fi

# Build the status information
if [[ "$output_format" == "text" ]]; then
    echo
    echo "Monk CLI Status"
    echo "==============="
    echo

    # Server Information
    echo "Server:"
    if [[ -n "$current_server" ]]; then
        echo "  Name: $current_server"
        echo "  Endpoint: ${server_endpoint:-Unknown}"
        echo "  Status: $server_status ${server_health:+($server_health)}"
    else
        echo "  No server selected (use 'monk server use <name>')"
    fi
    echo

    # Tenant Information
    echo "Tenant:"
    if [[ -n "$current_tenant" ]]; then
        echo "  Name: $current_tenant"
    else
        echo "  No tenant selected (use 'monk tenant use <name>')"
    fi
    echo

    # User Information
    echo "Authentication:"
    echo "  Status: $auth_status"
    if [[ -n "$user_details" ]]; then
        echo "  User: $user_details"
        if [[ -n "$access_level" ]]; then
            echo "  Access Level: $access_level"
        fi
    fi
    echo

    # Schemas Information
    if [[ "$server_status" == "Up" && "$auth_status" == "Authenticated" ]]; then
        echo "Available Schemas ($schema_count):"
        if [[ "$schemas" == "No schemas found" || "$schemas" == "Unable to fetch schemas" ]]; then
            echo "  $schemas"
        else
            echo "$schemas" | while read -r schema; do
                if [[ -n "$schema" ]]; then
                    echo "  • $schema"
                fi
            done
        fi
    else
        echo "Schemas: Not available (server down or not authenticated)"
    fi

else
    # JSON output
    status_json=$(jq -n \
        --arg server_name "$current_server" \
        --arg server_endpoint "$server_endpoint" \
        --arg server_status "$server_status" \
        --arg server_health "$server_health" \
        --arg tenant "$current_tenant" \
        --arg auth_status "$auth_status" \
        --arg user_details "$user_details" \
        --arg access_level "$access_level" \
        --arg schemas "$schemas" \
        --arg schema_count "$schema_count" \
        '{
            server: {
                name: $server_name,
                endpoint: $server_endpoint,
                status: $server_status,
                health: $server_health
            },
            tenant: $tenant,
            authentication: {
                status: $auth_status,
                user: $user_details,
                access_level: $access_level
            },
            schemas: {
                count: ($schema_count | tonumber),
                available: ($schemas | split("\n") | map(select(. != "")))
            }
        }')

    handle_output "$status_json" "$output_format" "json" "status"
fi