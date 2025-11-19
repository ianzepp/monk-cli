# monk use - Convenience command to switch server and optionally tenant
#
# With no arguments: Shows current server and tenant context
# With server: Delegates to monk config server use <server>
# With server and tenant: Delegates to both server and tenant use commands
#
# This avoids duplicating logic and ensures consistent behavior

# Get arguments from bashly
server="${args[server]:-}"
tenant="${args[tenant]:-}"

# Check dependencies
check_dependencies
init_cli_configs

# If no server specified, show current context
if [ -z "$server" ]; then
    current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)

    echo
    echo "Current Context"
    echo "==============="
    echo

    if [ -n "$current_server" ] && [ "$current_server" != "null" ]; then
        # Get server details
        server_info=$(jq -r ".servers.\"$current_server\"" "$SERVER_CONFIG" 2>/dev/null)
        if [ -n "$server_info" ] && [ "$server_info" != "null" ]; then
            hostname=$(echo "$server_info" | jq -r '.hostname')
            port=$(echo "$server_info" | jq -r '.port')
            protocol=$(echo "$server_info" | jq -r '.protocol')
            endpoint="$protocol://$hostname:$port"

            echo "Server: $current_server"
            echo "  Endpoint: $endpoint"
        else
            echo "Server: $current_server (configuration missing)"
        fi
    else
        echo "Server: None selected"
        print_info "Use 'monk use <server>' to select a server"
    fi

    echo

    if [ -n "$current_tenant" ] && [ "$current_tenant" != "null" ]; then
        # Get tenant details
        tenant_info=$(jq -r ".tenants.\"$current_tenant\"" "$TENANT_CONFIG" 2>/dev/null)
        if [ -n "$tenant_info" ] && [ "$tenant_info" != "null" ]; then
            display_name=$(echo "$tenant_info" | jq -r '.display_name')
            echo "Tenant: $current_tenant"
            echo "  Display Name: $display_name"
        else
            echo "Tenant: $current_tenant (configuration missing)"
        fi
    else
        echo "Tenant: None selected"
        if [ -n "$current_server" ] && [ "$current_server" != "null" ]; then
            print_info "Use 'monk use $current_server <tenant>' to select a tenant"
        fi
    fi

    echo
    exit 0
fi

# Determine the monk binary path
# During development, this is ./monk; when installed, it's in PATH
if [ -x "./monk" ]; then
    MONK_CMD="./monk"
elif command -v monk >/dev/null 2>&1; then
    MONK_CMD="monk"
else
    print_error "Cannot find monk binary"
    exit 1
fi

# Handle '.' as current server - for tenant-only switching
if [ "$server" = "." ]; then
    if [ -z "$tenant" ]; then
        print_error "Must specify tenant when using '.' for current server"
        print_info "Usage: monk use . <tenant>"
        exit 1
    fi

    # Only switch tenant (current server remains)
    $MONK_CMD config tenant use "$tenant"
    exit $?
fi

# Switch server context
$MONK_CMD config server use "$server"
server_exit=$?

if [ $server_exit -ne 0 ]; then
    exit $server_exit
fi

# If tenant specified, switch to it
if [ -n "$tenant" ]; then
    $MONK_CMD config tenant use "$tenant"
    exit $?
fi
