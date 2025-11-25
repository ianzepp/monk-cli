# monk use - Switch to a session or show current session info
#
# With no arguments: Shows current session info
# With session: Switch to that session (by alias or tenant name)
#
# Examples:
#   monk use              Show current session
#   monk use dev-work     Switch to session "dev-work"
#   monk use my-tenant    Switch to session for tenant "my-tenant"

# Check dependencies
check_dependencies
init_cli_configs

session="${args[session]:-}"

# If no session specified, show current context
if [ -z "$session" ]; then
    current_session=$(get_current_session)

    echo
    echo "Current Session"
    echo "==============="
    echo

    if [ -n "$current_session" ]; then
        server=$(get_session_info "$current_session" "server")
        tenant=$(get_session_info "$current_session" "tenant")
        user=$(get_session_info "$current_session" "user")
        created_at=$(get_session_info "$current_session" "created_at")

        echo "Session: $current_session"
        echo "  Server: $server"
        echo "  Tenant: $tenant"
        echo "  User: $user"
        [ -n "$created_at" ] && echo "  Created: $created_at"
    else
        echo "No current session"
        echo
        print_info "Use 'monk auth login <tenant> --server <url>' to create a session"
        print_info "Or 'monk auth register <tenant> --server <url>' to register a new tenant"
    fi

    echo

    # List other available sessions
    other_sessions=$(jq -r ".sessions | keys[] | select(. != \"$current_session\")" "$SESSIONS_CONFIG" 2>/dev/null)
    if [ -n "$other_sessions" ]; then
        echo "Other Sessions"
        echo "--------------"
        for s in $other_sessions; do
            tenant=$(get_session_info "$s" "tenant")
            server=$(get_session_info "$s" "server")
            echo "  $s -> $tenant @ $server"
        done
        echo
    fi

    exit 0
fi

# Switch to specified session
if switch_session "$session"; then
    # Show new session info
    server=$(get_session_info "$session" "server")
    tenant=$(get_session_info "$session" "tenant")
    user=$(get_session_info "$session" "user")

    print_info_always "Server: $server"
    print_info_always "Tenant: $tenant"
    print_info_always "User: $user"
else
    exit 1
fi
