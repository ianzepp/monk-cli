#!/bin/bash

# auth_ping_command.sh - Authenticated API health check with universal format support

# Check dependencies
check_dependencies

# Get flags from bashly args
verbose_flag="${args[--verbose]}"
jwt_token_arg="${args[--jwt-token]}"

# Determine output format from global flags
output_format=$(get_output_format "text")

# Set CLI_VERBOSE if flag is present  
if [ "$verbose_flag" = "1" ] || [ "$verbose_flag" = "true" ]; then
    CLI_VERBOSE=true
fi

# Make ping request
base_url=$(get_base_url)

if [ "$CLI_VERBOSE" = "true" ]; then
    print_info "Pinging server at: $base_url"
fi

# Prepare curl arguments
curl_args=(-s -X GET -H "Content-Type: application/json")

# Add JWT token (provided via -j flag or stored token)
token_to_use="$jwt_token_arg"
if [ -z "$token_to_use" ]; then
    token_to_use=$(get_jwt_token)
fi

if [ -n "$token_to_use" ]; then
    curl_args+=(-H "Authorization: Bearer $token_to_use")
    if [ "$CLI_VERBOSE" = "true" ]; then
        if [ -n "$jwt_token_arg" ]; then
            print_info "Using provided JWT token"
        else
            print_info "Using stored JWT token"
        fi
    fi
fi

# Make request
full_url="${base_url}/api/auth/whoami"
response=$(curl "${curl_args[@]}" -w "\n%{http_code}" "$full_url")
http_code=$(echo "$response" | tail -n1)
response=$(echo "$response" | sed '$d')
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Handle response based on HTTP code
case "$http_code" in
    200)
        # Success - build response JSON
        if [ "$JSON_PARSER" = "jq" ]; then
            ping_result=$(echo "$response" | jq --arg http_code "$http_code" \
                --arg timestamp "$timestamp" \
                --arg success "true" \
                '. + {
                    http_code: ($http_code | tonumber),
                    timestamp: $timestamp,
                    success: ($success == "true"),
                    reachable: true
                }')
        else
            # Fallback JSON
            ping_result='{"success": true, "reachable": true, "http_code": '"$http_code"', "timestamp": "'"$timestamp"'", "raw_response": "'"$response"'"}'
        fi
        
        if [[ "$output_format" == "text" ]]; then
            if [ "$CLI_VERBOSE" = "true" ]; then
                print_success "Authentication successful (HTTP $http_code)"
                echo "Response: $response"
            else
                # Parse response for clean output
                if [ "$JSON_PARSER" = "jq" ]; then
                    user_id=$(echo "$response" | jq -r '.data.id' 2>/dev/null || echo "unknown")
                    user_name=$(echo "$response" | jq -r '.data.name' 2>/dev/null || echo "unknown")
                    tenant=$(echo "$response" | jq -r '.data.tenant' 2>/dev/null || echo "null")
                    database=$(echo "$response" | jq -r '.data.database' 2>/dev/null || echo "null")
                    access=$(echo "$response" | jq -r '.data.access' 2>/dev/null || echo "null")
                    
                    print_success "Authentication successful"
                    echo "User: $user_name"
                    echo "ID: $user_id"
                    if [ "$tenant" != "null" ] && [ "$tenant" != "" ]; then
                        echo "Tenant: $tenant"
                    fi
                    if [ "$database" != "null" ] && [ "$database" != "" ]; then
                        echo "Database: $database"
                    fi
                    if [ "$access" != "null" ] && [ "$access" != "" ]; then
                        echo "Access: $access"
                    fi
                else
                    echo "Response: $response"
                fi
            fi
        else
            handle_output "$ping_result" "$output_format" "json"
        fi
        ;;
    401)
        # Unauthorized
        error_result=$(jq -n \
            --arg http_code "$http_code" \
            --arg timestamp "$timestamp" \
            --arg error "Authentication failed" \
            '{
                success: false,
                reachable: true,
                http_code: ($http_code | tonumber),
                timestamp: $timestamp,
                error: $error,
                message: "JWT token is invalid or expired"
            }')
        
        if [[ "$output_format" == "text" ]]; then
            print_error "Authentication failed (HTTP $http_code)"
            print_info "JWT token is invalid or expired"
            print_info "Use 'monk auth login TENANT USERNAME' to re-authenticate"
        else
            handle_output "$error_result" "$output_format" "json"
        fi
        exit 1
        ;;
    *)
        # Other HTTP error
        error_result=$(jq -n \
            --arg http_code "$http_code" \
            --arg timestamp "$timestamp" \
            --arg response "$response" \
            '{
                success: false,
                reachable: (if ($http_code | tonumber) == 0 then false else true end),
                http_code: ($http_code | tonumber),
                timestamp: $timestamp,
                error: "HTTP error",
                response: $response
            }')
        
        if [[ "$output_format" == "text" ]]; then
            print_error "HTTP error ($http_code)"
            if [ "$CLI_VERBOSE" = "true" ]; then
                echo "Response: $response"
            fi
        else
            handle_output "$error_result" "$output_format" "json"
        fi
        exit 1
        ;;
esac