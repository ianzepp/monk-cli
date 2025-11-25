# auth status - Show authentication status

check_dependencies
init_cli_configs

# Determine output format from global flags
output_format=$(get_output_format "text")

current_session=$(get_current_session)
token=$(get_jwt_token)

if [ -n "$current_session" ] && [ -n "$token" ]; then
    server=$(get_session_info "$current_session" "server")
    tenant=$(get_session_info "$current_session" "tenant")
    user=$(get_session_info "$current_session" "user")
    created_at=$(get_session_info "$current_session" "created_at")

    # Decode JWT to get expiration
    exp="unknown"
    exp_date="unknown"
    database="unknown"

    payload=$(echo "$token" | cut -d'.' -f2)
    # Add padding if needed
    case $((${#payload} % 4)) in
        2) payload="${payload}==" ;;
        3) payload="${payload}=" ;;
    esac

    if command -v base64 &> /dev/null; then
        decoded=$(echo "$payload" | base64 -d 2>/dev/null || echo "")
        if [ -n "$decoded" ]; then
            database=$(echo "$decoded" | jq -r '.database // .db // "unknown"' 2>/dev/null)
            exp=$(echo "$decoded" | jq -r '.exp // "unknown"' 2>/dev/null)

            if [ "$exp" != "unknown" ] && [ "$exp" != "null" ]; then
                exp_date=$(date -r "$exp" 2>/dev/null || echo "unknown")
            fi
        fi
    fi

    if [[ "$output_format" == "text" ]]; then
        echo "Session: $current_session"
        echo "Server: $server"
        echo "Tenant: $tenant"
        echo "User: $user"
        [ "$database" != "unknown" ] && echo "Database: $database"
        [ "$exp_date" != "unknown" ] && echo "Expires: $exp_date"
        print_success "Authenticated"
    else
        auth_status=$(jq -n \
            --arg session "$current_session" \
            --arg server "$server" \
            --arg tenant "$tenant" \
            --arg user "$user" \
            --arg database "$database" \
            --arg exp "$exp" \
            --arg exp_date "$exp_date" \
            --arg created_at "$created_at" \
            '{
                authenticated: true,
                session: $session,
                server: $server,
                tenant: $tenant,
                user: $user,
                database: ($database | if . == "unknown" then null else . end),
                expires: ($exp | if . == "unknown" then null else (. | tonumber) end),
                expires_date: ($exp_date | if . == "unknown" then null else . end),
                created_at: ($created_at | if . == "" then null else . end)
            }')
        handle_output "$auth_status" "$output_format" "json"
    fi
else
    if [[ "$output_format" == "text" ]]; then
        print_error "Not authenticated"
        print_info "Use 'monk auth login <tenant> --server <url>' to authenticate"
        print_info "Or 'monk auth register <tenant> --server <url>' to register a new tenant"
    else
        unauth_status=$(jq -n '{
            authenticated: false,
            session: null,
            message: "Not authenticated. Use monk auth login or monk auth register."
        }')
        handle_output "$unauth_status" "$output_format" "json"
    fi
fi