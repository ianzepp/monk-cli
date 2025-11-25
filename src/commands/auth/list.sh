# auth list - List all stored sessions

check_dependencies
init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for session listing"
    exit 1
fi

# Determine output format from global flags
output_format=$(get_output_format "text")

# Get current session
current_session=$(get_current_session)

# Get all session aliases
session_aliases=$(jq -r '.sessions | keys[]' "$SESSIONS_CONFIG" 2>/dev/null)

if [ -z "$session_aliases" ]; then
    if [[ "$output_format" == "text" ]]; then
        echo
        echo "Sessions"
        echo "========"
        echo
        print_info "No stored sessions found"
        print_info "Use 'monk auth login <tenant> --server <url>' or 'monk auth register <tenant> --server <url>' to create a session"
    else
        handle_output '{"sessions": [], "current_session": null}' "$output_format" "json"
    fi
    exit 0
fi

# Build session data
sessions_array=()
for alias in $session_aliases; do
    server=$(get_session_info "$alias" "server")
    tenant=$(get_session_info "$alias" "tenant")
    user=$(get_session_info "$alias" "user")
    created_at=$(get_session_info "$alias" "created_at")
    token=$(get_session_info "$alias" "jwt_token")

    # Decode JWT for expiration
    exp="unknown"
    is_expired="unknown"

    if [ -n "$token" ]; then
        payload=$(echo "$token" | cut -d'.' -f2)
        case $((${#payload} % 4)) in
            2) payload="${payload}==" ;;
            3) payload="${payload}=" ;;
        esac

        decoded=$(echo "$payload" | base64 -d 2>/dev/null || echo "")
        if [ -n "$decoded" ]; then
            exp=$(echo "$decoded" | jq -r '.exp // "unknown"' 2>/dev/null)
            if [ "$exp" != "unknown" ] && [ "$exp" != "null" ]; then
                current_time=$(date +%s)
                if [ "$exp" -gt "$current_time" ]; then
                    is_expired="false"
                else
                    is_expired="true"
                fi
            fi
        fi
    fi

    is_current="false"
    [ "$alias" = "$current_session" ] && is_current="true"

    session_json=$(jq -n \
        --arg alias "$alias" \
        --arg server "$server" \
        --arg tenant "$tenant" \
        --arg user "$user" \
        --arg created_at "$created_at" \
        --arg is_expired "$is_expired" \
        --arg is_current "$is_current" \
        '{
            alias: $alias,
            server: $server,
            tenant: $tenant,
            user: $user,
            created_at: $created_at,
            is_expired: ($is_expired == "true"),
            is_current: ($is_current == "true")
        }')
    sessions_array+=("$session_json")
done

# Combine into final JSON
final_json=$(jq -n \
    --argjson sessions "$(printf '%s\n' "${sessions_array[@]}" | jq -s .)" \
    --arg current "$current_session" \
    '{sessions: $sessions, current_session: ($current | if . == "" then null else . end)}')

if [[ "$output_format" == "text" ]]; then
    echo
    echo "Sessions"
    echo "========"
    echo

    # Build markdown table
    markdown_output="| ALIAS | SERVER | TENANT | USER | CREATED | EXPIRED | CURRENT |\n"
    markdown_output+="|-------|--------|--------|------|---------|---------|---------|"

    for alias in $session_aliases; do
        server=$(get_session_info "$alias" "server")
        tenant=$(get_session_info "$alias" "tenant")
        user=$(get_session_info "$alias" "user")
        created=$(get_session_info "$alias" "created_at" | cut -d'T' -f1)

        # Check expiration
        token=$(get_session_info "$alias" "jwt_token")
        expired="?"
        if [ -n "$token" ]; then
            payload=$(echo "$token" | cut -d'.' -f2)
            case $((${#payload} % 4)) in
                2) payload="${payload}==" ;;
                3) payload="${payload}=" ;;
            esac
            decoded=$(echo "$payload" | base64 -d 2>/dev/null || echo "")
            if [ -n "$decoded" ]; then
                exp=$(echo "$decoded" | jq -r '.exp // 0' 2>/dev/null)
                if [ "$exp" -gt "$(date +%s)" ] 2>/dev/null; then
                    expired="no"
                else
                    expired="yes"
                fi
            fi
        fi

        current_marker=""
        [ "$alias" = "$current_session" ] && current_marker="*"

        markdown_output+="\n| ${alias} | ${server} | ${tenant} | ${user} | ${created} | ${expired} | ${current_marker} |"
    done

    if [ -t 1 ] && command -v glow >/dev/null 2>&1; then
        echo -e "$markdown_output" | glow --width=0 -
    else
        echo -e "$markdown_output"
    fi

    echo
    if [ -n "$current_session" ]; then
        print_info "Current session: $current_session (marked with *)"
    else
        print_info "No current session selected"
        print_info "Use 'monk auth use <session>' to select a session"
    fi
else
    handle_output "$final_json" "$output_format" "json"
fi