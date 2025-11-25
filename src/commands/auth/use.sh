# Switch to a different session
#
# Usage:
#   monk auth use <session>    Switch to session by alias or tenant name
#
# Examples:
#   monk auth use dev-work     Switch to session named "dev-work"
#   monk auth use my-tenant    Switch to session for tenant "my-tenant"

check_dependencies
init_cli_configs

session="${args[session]}"

if [ -z "$session" ]; then
    print_error "Session name required"
    print_info "Usage: monk auth use <session>"
    exit 1
fi

# Try to switch session (handles both alias and tenant name lookup)
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
