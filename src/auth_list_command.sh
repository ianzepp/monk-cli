#!/bin/bash

# auth_list_command.sh - List all stored JWT tokens and sessions

# Check dependencies
check_dependencies

# Initialize CLI configs
init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for token listing"
    exit 1
fi

# Determine output format from global flags
output_format=$(get_output_format "text")

# Get current context information
current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
current_user=$(jq -r '.current_user // empty' "$ENV_CONFIG" 2>/dev/null)

# Get all sessions from auth config
sessions=$(jq -r '.sessions | to_entries[] | .key' "$AUTH_CONFIG" 2>/dev/null)

if [ -z "$sessions" ]; then
    empty_result='{"sessions": [], "current_session": null}'
    
    if [[ "$output_format" == "text" ]]; then
        echo
        print_info "Stored JWT Tokens"
        echo
        print_info "No stored authentication sessions found"
        print_info "Use 'monk auth login TENANT USERNAME' or 'monk auth register TENANT USERNAME' to create sessions"
    else
        handle_output "$empty_result" "$output_format" "json"
    fi
    exit 0
fi

# Build JSON data for all sessions
sessions_json=$(echo "$sessions" | while read -r session_key; do
    if [ -n "$session_key" ]; then
        session_info=$(jq -r ".sessions.\"$session_key\"" "$AUTH_CONFIG")
        
        server=$(echo "$session_info" | jq -r '.server')
        tenant=$(echo "$session_info" | jq -r '.tenant')
        user=$(echo "$session_info" | jq -r '.user')
        created_at=$(echo "$session_info" | jq -r '.created_at // "unknown"')
        
        # Extract token expiration info
        token=$(echo "$session_info" | jq -r '.jwt_token')
        exp="unknown"
        exp_date="unknown"
        is_expired="unknown"
        
        # Try to decode JWT payload for expiration
        payload=$(echo "$token" | cut -d'.' -f2)
        case $((${#payload} % 4)) in
            2) payload="${payload}==" ;;
            3) payload="${payload}=" ;;
        esac
        
        if command -v base64 &> /dev/null; then
            decoded=$(echo "$payload" | base64 -d 2>/dev/null || echo "")
            if [ -n "$decoded" ]; then
                exp=$(echo "$decoded" | jq -r '.exp' 2>/dev/null || echo "unknown")
                
                if [ "$exp" != "unknown" ] && [ "$exp" != "null" ]; then
                    # Check if expired
                    current_time=$(date +%s)
                    if [ "$exp" -gt "$current_time" ]; then
                        is_expired="false"
                    else
                        is_expired="true"
                    fi
                    
                    # Format expiration date
                    if command -v date &> /dev/null; then
                        exp_date=$(date -r "$exp" 2>/dev/null || date -d "@$exp" 2>/dev/null || echo "unknown")
                    fi
                fi
            fi
        fi
        
        # Check if this is the current session
        is_current="false"
        if [ "$server" = "$current_server" ] && [ "$tenant" = "$current_tenant" ] && [ "$user" = "$current_user" ]; then
            is_current="true"
        fi
        
        jq -n \
            --arg session_key "$session_key" \
            --arg server "$server" \
            --arg tenant "$tenant" \
            --arg user "$user" \
            --arg created_at "$created_at" \
            --arg exp "$exp" \
            --arg exp_date "$exp_date" \
            --argjson is_expired "$is_expired" \
            --argjson is_current "$is_current" \
            '{
                session_key: $session_key,
                server: $server,
                tenant: $tenant,
                user: $user,
                created_at: $created_at,
                expires_at: ($exp | if . == "unknown" then null else (. | tonumber) end),
                expires_date: ($exp_date | if . == "unknown" then null else . end),
                is_expired: ($is_expired == "true"),
                is_current: ($is_current == "true")
            }'
    fi
done | jq -s '{sessions: .}')

# Find current session key
current_session_key=""
if [ -n "$current_server" ] && [ -n "$current_tenant" ] && [ -n "$current_user" ]; then
    current_session_key="${current_server}:${current_tenant}"
fi

# Add current session info to JSON
final_json=$(echo "$sessions_json" | jq --arg current_session_key "$current_session_key" '. + {current_session: ($current_session_key | if . == "" then null else . end)}')

# Output in requested format
if [[ "$output_format" == "text" ]]; then
    echo
    print_info "Stored JWT Tokens"
    echo
    
    # Generate markdown table
    markdown="| SESSION | SERVER | TENANT | USER | CREATED | EXPIRED | CURRENT |\n"
    markdown="${markdown}|---|---|---|---|---|---|---|\n"
    
    # Add data rows using process substitution to avoid subshell issues
    while IFS= read -r row; do
        if [ -n "$row" ]; then
            # Decode the row and extract fields
            decoded=$(echo "$row" | base64 -d)
            session_key=$(echo "$decoded" | jq -r '.session_key')
            server=$(echo "$decoded" | jq -r '.server')
            tenant=$(echo "$decoded" | jq -r '.tenant')
            user=$(echo "$decoded" | jq -r '.user')
            created=$(echo "$decoded" | jq -r '.created_at' | cut -d'T' -f1)
            expired=$(echo "$decoded" | jq -r 'if .is_expired then "yes" else "no" end')
            current=$(echo "$decoded" | jq -r 'if .is_current then "*" else "" end')
            
            markdown="${markdown}| ${session_key} | ${server} | ${tenant} | ${user} | ${created} | ${expired} | ${current} |\n"
        fi
    done < <(echo "$final_json" | jq -r '.sessions[] | @base64')
    
    # Render markdown through glow
    echo -e "$markdown" | glow --pager -
    
    if [ -n "$current_session_key" ]; then
        print_info "Current session: $current_session_key (marked with *)"
    else
        print_info "No current session selected"
        print_info "Use 'monk tenant use <name>' to select a tenant"
    fi
    
    # Show expiration details for current session if available
    if [ -n "$current_session_key" ]; then
        current_session_info=$(echo "$final_json" | jq -r ".sessions[] | select(.session_key == \"$current_session_key\")")
        if [ -n "$current_session_info" ]; then
            exp_date=$(echo "$current_session_info" | jq -r '.expires_date // "unknown"')
            if [ "$exp_date" != "null" ] && [ "$exp_date" != "unknown" ]; then
                print_info "Current session expires: $exp_date"
            fi
        fi
    fi
else
    handle_output "$final_json" "$output_format" "json"
fi