#!/bin/bash

# auth_status_command.sh - Show authentication status with universal format support

# Check dependencies
check_dependencies

# Determine output format from global flags
output_format=$(get_output_format "text")

token=$(get_jwt_token)

# Get current context information
current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
current_user=$(jq -r '.current_user // empty' "$ENV_CONFIG" 2>/dev/null)

if [ -n "$token" ]; then
    # Extract token info
    tenant="unknown"
    database="unknown"
    exp="unknown"
    exp_date="unknown"
    
    # Try to extract domain from token (basic JWT decode)
    if [ "$JSON_PARSER" = "jq" ] || [ "$JSON_PARSER" = "jshon" ]; then
        # Decode JWT payload (basic base64 decode of middle part)
        payload=$(echo "$token" | cut -d'.' -f2)
        # Add padding if needed
        case $((${#payload} % 4)) in
            2) payload="${payload}==" ;;
            3) payload="${payload}=" ;;
        esac
        
        if command -v base64 &> /dev/null; then
            decoded=$(echo "$payload" | base64 -d 2>/dev/null || echo "")
            if [ -n "$decoded" ]; then
                if [ "$JSON_PARSER" = "jq" ]; then
                    tenant=$(echo "$decoded" | jq -r '.tenant' 2>/dev/null || echo "unknown")
                    database=$(echo "$decoded" | jq -r '.database' 2>/dev/null || echo "unknown")
                    exp=$(echo "$decoded" | jq -r '.exp' 2>/dev/null || echo "unknown")
                elif [ "$JSON_PARSER" = "jshon" ]; then
                    tenant=$(echo "$decoded" | jshon -e tenant -u 2>/dev/null || echo "unknown")
                    database=$(echo "$decoded" | jshon -e database -u 2>/dev/null || echo "unknown")
                    exp=$(echo "$decoded" | jshon -e exp -u 2>/dev/null || echo "unknown")
                fi
                
                if [ "$exp" != "unknown" ] && [ "$exp" != "null" ]; then
                    if command -v date &> /dev/null; then
                        exp_date=$(date -r "$exp" 2>/dev/null || echo "unknown")
                    fi
                fi
            fi
        fi
    fi
    
    # Build authenticated status JSON
    auth_status=$(jq -n \
        --arg authenticated "true" \
        --arg tenant "$tenant" \
        --arg database "$database" \
        --arg exp "$exp" \
        --arg exp_date "$exp_date" \
        --arg current_server "$current_server" \
        --arg current_tenant "$current_tenant" \
        --arg current_user "$current_user" \
        --arg has_token "true" \
        '{
            authenticated: ($authenticated == "true"),
            has_token: ($has_token == "true"),
            token_info: {
                tenant: $tenant,
                database: $database,
                exp: ($exp | if . == "unknown" then null else (. | tonumber) end),
                exp_date: ($exp_date | if . == "unknown" then null else . end)
            },
            current_context: {
                server: ($current_server | if . == "" or . == "null" then null else . end),
                tenant: ($current_tenant | if . == "" or . == "null" then null else . end),
                user: ($current_user | if . == "" or . == "null" then null else . end)
            }
        }')
    
    if [[ "$output_format" == "text" ]]; then
        echo "Tenant: $tenant"
        echo "Database: $database"
        if [ "$exp_date" != "unknown" ]; then
            echo "Expires: $exp_date"
        fi
        echo "Server: $current_server"
        echo "Tenant: $current_tenant"
        echo "User: $current_user"
        print_success "Authenticated"
    else
        handle_output "$auth_status" "$output_format" "json"
    fi
else
    # Build unauthenticated status JSON
    unauth_status=$(jq -n \
        --arg current_server "$current_server" \
        --arg current_tenant "$current_tenant" \
        --arg current_user "$current_user" \
        '{
            authenticated: false,
            has_token: false,
            token_info: null,
            current_context: {
                server: ($current_server | if . == "" or . == "null" then null else . end),
                tenant: ($current_tenant | if . == "" or . == "null" then null else . end),
                user: ($current_user | if . == "" or . == "null" then null else . end)
            },
            message: "Not authenticated. Use monk auth login TENANT USERNAME to authenticate."
        }')
    
    if [[ "$output_format" == "text" ]]; then
        print_error "Not authenticated"
        print_info "Use 'monk auth login TENANT USERNAME' to authenticate"
    else
        handle_output "$unauth_status" "$output_format" "json"
    fi
fi