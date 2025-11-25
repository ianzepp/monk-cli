#!/bin/bash

# Common functions for bashly CLI commands
# Clean rewrite to eliminate syntax errors and improve maintainability

# Session-based configuration:
# - sessions.json: All session data (server URLs, tenants, users, JWT tokens)
#   Each session has an alias (key) and contains server URL, tenant, user, and JWT
#   current_session points to the active session alias

# CLI configuration files
CLI_CONFIG_DIR="${MONK_CLI_CONFIG_DIR:-${HOME}/.config/monk/cli}"
SESSIONS_CONFIG="${CLI_CONFIG_DIR}/sessions.json"

# Legacy config files (for migration)
SERVER_CONFIG="${CLI_CONFIG_DIR}/server.json"
TENANT_CONFIG="${CLI_CONFIG_DIR}/tenant.json"
AUTH_CONFIG="${CLI_CONFIG_DIR}/auth.json"
ENV_CONFIG="${CLI_CONFIG_DIR}/env.json"
LEGACY_SERVERS_CONFIG="${HOME}/.config/monk/servers.json"

# Default configuration
DEFAULT_BASE_URL="http://localhost:3000"
DEFAULT_LIMIT=50
DEFAULT_FORMAT="raw"

# Colors for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output - all go to stderr to avoid interfering with data pipes
print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}" >&2
}

print_info() {
    # Only print if CLI_VERBOSE is true
    if [ "$CLI_VERBOSE" = "true" ]; then
        echo -e "${YELLOW}ℹ $1${NC}" >&2
    fi
}

print_info_always() {
    # Always print info messages (ignores CLI_VERBOSE)
    echo -e "${YELLOW}ℹ $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" >&2
}

# Initialize CLI config directory and files
init_cli_configs() {
    # Ensure CLI config directory exists
    mkdir -p "$CLI_CONFIG_DIR"

    # Migrate legacy config if needed
    migrate_legacy_configs

    # Initialize sessions config if it doesn't exist
    init_sessions_config
}

# Initialize sessions config if it doesn't exist
init_sessions_config() {
    if [ ! -f "$SESSIONS_CONFIG" ]; then
        mkdir -p "$(dirname "$SESSIONS_CONFIG")"
        cat > "$SESSIONS_CONFIG" << 'EOF'
{
  "current_session": null,
  "sessions": {}
}
EOF
        chmod 600 "$SESSIONS_CONFIG"
    fi
}

# Migrate from legacy config files to sessions.json
migrate_legacy_configs() {
    # Skip if sessions.json already exists
    if [ -f "$SESSIONS_CONFIG" ]; then
        return 0
    fi

    # Check if there's anything to migrate
    if [ ! -f "$AUTH_CONFIG" ] && [ ! -f "$ENV_CONFIG" ]; then
        return 0
    fi

    print_info "Migrating legacy configuration to sessions.json..."

    # Start with empty sessions structure
    local sessions_json='{"current_session": null, "sessions": {}}'

    # Get current context from env.json
    local current_server="" current_tenant="" current_user=""
    if [ -f "$ENV_CONFIG" ]; then
        current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
        current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
        current_user=$(jq -r '.current_user // empty' "$ENV_CONFIG" 2>/dev/null)
    fi

    # Migrate sessions from auth.json
    if [ -f "$AUTH_CONFIG" ]; then
        # Read all sessions and convert them
        local session_keys
        session_keys=$(jq -r '.sessions | keys[]' "$AUTH_CONFIG" 2>/dev/null)

        for old_key in $session_keys; do
            # Old key format: "server_name:tenant"
            local jwt_token tenant user server_name created_at
            jwt_token=$(jq -r ".sessions.\"$old_key\".jwt_token // empty" "$AUTH_CONFIG" 2>/dev/null)
            tenant=$(jq -r ".sessions.\"$old_key\".tenant // empty" "$AUTH_CONFIG" 2>/dev/null)
            user=$(jq -r ".sessions.\"$old_key\".user // empty" "$AUTH_CONFIG" 2>/dev/null)
            server_name=$(jq -r ".sessions.\"$old_key\".server // empty" "$AUTH_CONFIG" 2>/dev/null)
            created_at=$(jq -r ".sessions.\"$old_key\".created_at // empty" "$AUTH_CONFIG" 2>/dev/null)

            # Skip if no token
            [ -z "$jwt_token" ] && continue

            # Get server URL from server.json
            local server_url=""
            if [ -f "$SERVER_CONFIG" ] && [ -n "$server_name" ]; then
                local hostname port protocol
                hostname=$(jq -r ".servers.\"$server_name\".hostname // empty" "$SERVER_CONFIG" 2>/dev/null)
                port=$(jq -r ".servers.\"$server_name\".port // empty" "$SERVER_CONFIG" 2>/dev/null)
                protocol=$(jq -r ".servers.\"$server_name\".protocol // \"http\"" "$SERVER_CONFIG" 2>/dev/null)
                if [ -n "$hostname" ] && [ -n "$port" ]; then
                    server_url="${protocol}://${hostname}:${port}"
                fi
            fi

            # Use tenant as the session alias (simpler)
            local alias="$tenant"

            # Add session to sessions_json
            sessions_json=$(echo "$sessions_json" | jq \
                --arg alias "$alias" \
                --arg server "$server_url" \
                --arg tenant "$tenant" \
                --arg user "$user" \
                --arg jwt_token "$jwt_token" \
                --arg created_at "$created_at" \
                '.sessions[$alias] = {
                    "server": $server,
                    "tenant": $tenant,
                    "user": $user,
                    "jwt_token": $jwt_token,
                    "created_at": $created_at
                }')

            # Set current session if this matches the current context
            if [ "$server_name" = "$current_server" ] && [ "$tenant" = "$current_tenant" ]; then
                sessions_json=$(echo "$sessions_json" | jq --arg alias "$alias" '.current_session = $alias')
            fi
        done
    fi

    # Write sessions.json
    echo "$sessions_json" > "$SESSIONS_CONFIG"
    chmod 600 "$SESSIONS_CONFIG"

    print_success "Migrated to sessions.json"
    print_info "Legacy config files preserved (can be deleted manually)"
}

# Legacy compatibility - these functions now delegate to sessions.json
init_server_config() { :; }
init_tenant_config() { :; }
init_auth_config() { :; }
init_env_config() { :; }

# Get base URL from current session
get_base_url() {
    init_cli_configs

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for configuration" >&2
        exit 1
    fi

    # Get current session
    local current_session
    current_session=$(jq -r '.current_session // empty' "$SESSIONS_CONFIG" 2>/dev/null)

    if [[ -z "$current_session" || "$current_session" == "null" ]]; then
        echo "Error: No current session" >&2
        echo "Use 'monk auth login <tenant> --server <url>' to create a session" >&2
        exit 1
    fi

    # Get server URL from current session
    local server_url
    server_url=$(jq -r ".sessions.\"$current_session\".server // empty" "$SESSIONS_CONFIG" 2>/dev/null)

    if [[ -z "$server_url" || "$server_url" == "null" ]]; then
        echo "Error: Session '$current_session' has no server URL" >&2
        exit 1
    fi

    echo "$server_url"
}

# Get base URL for a specific server (used when --server flag is provided)
get_base_url_for_server() {
    local server_url="$1"

    # If it looks like a URL, use it directly
    if [[ "$server_url" =~ ^https?:// ]]; then
        echo "$server_url"
        return 0
    fi

    # Otherwise, assume it's host:port and add http://
    echo "http://$server_url"
}

# Get stored JWT token for current session
get_jwt_token() {
    init_cli_configs

    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    # Get current session
    local current_session
    current_session=$(jq -r '.current_session // empty' "$SESSIONS_CONFIG" 2>/dev/null)

    if [ -z "$current_session" ] || [ "$current_session" = "null" ]; then
        return 1
    fi

    # Get token from current session
    local token
    token=$(jq -r ".sessions.\"$current_session\".jwt_token // empty" "$SESSIONS_CONFIG" 2>/dev/null)

    if [ -n "$token" ] && [ "$token" != "null" ]; then
        echo "$token"
    else
        return 1
    fi
}

# Get current session info
get_current_session() {
    init_cli_configs

    local current_session
    current_session=$(jq -r '.current_session // empty' "$SESSIONS_CONFIG" 2>/dev/null)

    if [ -z "$current_session" ] || [ "$current_session" = "null" ]; then
        return 1
    fi

    echo "$current_session"
}

# Get session details by alias
get_session_info() {
    local alias="$1"
    local field="$2"

    jq -r ".sessions.\"$alias\".$field // empty" "$SESSIONS_CONFIG" 2>/dev/null
}

# Store session (new unified function)
# Usage: store_session <alias> <server_url> <tenant> <user> <jwt_token>
store_session() {
    local alias="$1"
    local server_url="$2"
    local tenant="$3"
    local user="$4"
    local jwt_token="$5"

    init_cli_configs

    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for session management" >&2
        return 1
    fi

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local temp_file=$(mktemp)

    jq --arg alias "$alias" \
       --arg server "$server_url" \
       --arg tenant "$tenant" \
       --arg user "$user" \
       --arg jwt_token "$jwt_token" \
       --arg timestamp "$timestamp" \
       '.sessions[$alias] = {
           "server": $server,
           "tenant": $tenant,
           "user": $user,
           "jwt_token": $jwt_token,
           "created_at": $timestamp
       } | .current_session = $alias' \
       "$SESSIONS_CONFIG" > "$temp_file" && mv "$temp_file" "$SESSIONS_CONFIG"

    chmod 600 "$SESSIONS_CONFIG"
}

# Legacy compatibility wrapper - store_token now uses store_session
# This maintains backwards compatibility with existing command implementations
store_token() {
    local token="$1"
    local tenant="$2"
    local user="$3"
    local server_url="${4:-}"  # Optional: new parameter for explicit server URL
    local alias="${5:-$tenant}"  # Optional: new parameter for session alias, defaults to tenant

    init_cli_configs

    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for session management" >&2
        return 1
    fi

    # If no server URL provided, try to get from current session
    if [ -z "$server_url" ]; then
        local current_session
        current_session=$(jq -r '.current_session // empty' "$SESSIONS_CONFIG" 2>/dev/null)
        if [ -n "$current_session" ] && [ "$current_session" != "null" ]; then
            server_url=$(jq -r ".sessions.\"$current_session\".server // empty" "$SESSIONS_CONFIG" 2>/dev/null)
        fi
    fi

    if [ -z "$server_url" ]; then
        echo "Error: No server URL available. Use --server flag or set up a session first." >&2
        return 1
    fi

    store_session "$alias" "$server_url" "$tenant" "$user" "$token"
}

# Switch to a session by alias
switch_session() {
    local alias="$1"

    init_cli_configs

    # Check if session exists
    local session_exists
    session_exists=$(jq -e ".sessions.\"$alias\"" "$SESSIONS_CONFIG" 2>/dev/null)

    if [ $? -ne 0 ]; then
        # Try to find by tenant name
        local found_alias
        found_alias=$(jq -r ".sessions | to_entries[] | select(.value.tenant == \"$alias\") | .key" "$SESSIONS_CONFIG" 2>/dev/null | head -1)

        if [ -n "$found_alias" ]; then
            alias="$found_alias"
        else
            echo "Error: Session '$alias' not found" >&2
            return 1
        fi
    fi

    # Update current session
    local temp_file=$(mktemp)
    jq --arg alias "$alias" '.current_session = $alias' "$SESSIONS_CONFIG" > "$temp_file" && mv "$temp_file" "$SESSIONS_CONFIG"

    print_success "Switched to session: $alias"
}

# Remove a session by alias
remove_session() {
    local alias="$1"

    init_cli_configs

    # Check if this is the current session
    local current_session
    current_session=$(jq -r '.current_session // empty' "$SESSIONS_CONFIG" 2>/dev/null)

    local temp_file=$(mktemp)

    if [ "$current_session" = "$alias" ]; then
        # Remove session and clear current
        jq --arg alias "$alias" 'del(.sessions[$alias]) | .current_session = null' "$SESSIONS_CONFIG" > "$temp_file" && mv "$temp_file" "$SESSIONS_CONFIG"
    else
        # Just remove the session
        jq --arg alias "$alias" 'del(.sessions[$alias])' "$SESSIONS_CONFIG" > "$temp_file" && mv "$temp_file" "$SESSIONS_CONFIG"
    fi
}

# List all sessions
list_sessions() {
    init_cli_configs
    jq -r '.sessions | keys[]' "$SESSIONS_CONFIG" 2>/dev/null
}

# Legacy compatibility: remove_stored_token delegates to remove_session
remove_stored_token() {
    local current_session
    current_session=$(get_current_session)

    if [ -z "$current_session" ]; then
        echo "Error: No current session" >&2
        return 1
    fi

    remove_session "$current_session"
}

# Get sudo token for current session
get_sudo_token() {
    init_cli_configs

    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    local current_session
    current_session=$(get_current_session)

    if [ -z "$current_session" ]; then
        return 1
    fi

    local sudo_token expires_at
    sudo_token=$(jq -r ".sessions.\"$current_session\".sudo_token // empty" "$SESSIONS_CONFIG" 2>/dev/null)
    expires_at=$(jq -r ".sessions.\"$current_session\".sudo_expires_at // empty" "$SESSIONS_CONFIG" 2>/dev/null)

    if [ -z "$sudo_token" ] || [ "$sudo_token" = "null" ]; then
        return 1
    fi

    # Check if token is expired
    if [ -n "$expires_at" ] && [ "$expires_at" != "null" ]; then
        local current_time=$(date +%s)
        if [ "$current_time" -ge "$expires_at" ]; then
            clear_sudo_token
            return 1
        fi
    fi

    echo "$sudo_token"
}

# Store sudo token for current session
store_sudo_token() {
    local sudo_token="$1"
    local reason="${2:-}"

    init_cli_configs

    local current_session
    current_session=$(get_current_session)

    if [ -z "$current_session" ]; then
        echo "Error: No current session" >&2
        return 1
    fi

    # Calculate expiration time (15 minutes from now)
    local expires_at=$(($(date +%s) + 900))
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local temp_file=$(mktemp)

    if [ -n "$reason" ]; then
        jq --arg session "$current_session" \
           --arg sudo_token "$sudo_token" \
           --arg expires_at "$expires_at" \
           --arg timestamp "$timestamp" \
           --arg reason "$reason" \
           '.sessions[$session].sudo_token = $sudo_token |
            .sessions[$session].sudo_expires_at = ($expires_at | tonumber) |
            .sessions[$session].sudo_created_at = $timestamp |
            .sessions[$session].sudo_reason = $reason' \
           "$SESSIONS_CONFIG" > "$temp_file" && mv "$temp_file" "$SESSIONS_CONFIG"
    else
        jq --arg session "$current_session" \
           --arg sudo_token "$sudo_token" \
           --arg expires_at "$expires_at" \
           --arg timestamp "$timestamp" \
           '.sessions[$session].sudo_token = $sudo_token |
            .sessions[$session].sudo_expires_at = ($expires_at | tonumber) |
            .sessions[$session].sudo_created_at = $timestamp' \
           "$SESSIONS_CONFIG" > "$temp_file" && mv "$temp_file" "$SESSIONS_CONFIG"
    fi

    chmod 600 "$SESSIONS_CONFIG"
}

# Clear sudo token for current session
clear_sudo_token() {
    init_cli_configs

    local current_session
    current_session=$(get_current_session)

    if [ -z "$current_session" ]; then
        return 1
    fi

    local temp_file=$(mktemp)
    jq --arg session "$current_session" \
       'del(.sessions[$session].sudo_token) |
        del(.sessions[$session].sudo_expires_at) |
        del(.sessions[$session].sudo_created_at) |
        del(.sessions[$session].sudo_reason)' \
       "$SESSIONS_CONFIG" > "$temp_file" && mv "$temp_file" "$SESSIONS_CONFIG"
}

# Check if sudo token is expired
is_sudo_token_expired() {
    local sudo_token
    sudo_token=$(get_sudo_token 2>/dev/null)
    
    if [ -z "$sudo_token" ]; then
        return 1  # No token or expired
    fi
    
    return 0  # Token exists and is valid
}

# Make HTTP request with JSON content-type - programmatic by default
make_request_json() {
    local method="$1"
    local url="$2"
    local data="$3"
    local base_url=$(get_base_url)

    # Build query string with format and pick parameters
    local query_string=$(build_api_query_string)
    local full_url="${base_url}${url}${query_string}"

    print_info "Making $method request to: $full_url"

    local curl_args=(-s -X "$method" -H "Content-Type: application/json")

    # Add Accept header based on format parameter
    local accept_header=$(get_accept_header)
    curl_args+=(-H "Accept: $accept_header")

    # Add JWT token if available (unless it's an auth request)
    if [[ "$url" != "/auth/"* ]]; then
        local jwt_token
        jwt_token=$(get_jwt_token)
        if [ -n "$jwt_token" ]; then
            curl_args+=(-H "Authorization: Bearer $jwt_token")
            print_info "Using stored JWT token"
        fi
    fi

    if [ -n "$data" ]; then
        curl_args+=(-d "$data")
    fi

    local response
    local http_code
    local content_type

    # Make request and capture response, HTTP status code, and Content-Type
    response=$(curl "${curl_args[@]}" -w "\n%{http_code}\n%{content_type}" "$full_url")
    http_code=$(echo "$response" | tail -n2 | head -n1)
    content_type=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d' | sed '$d')

    # Store content_type in global variable for response handlers
    export RESPONSE_CONTENT_TYPE="$content_type"
    
    # Handle HTTP errors
    case "$http_code" in
        200|201)
            print_success "Success ($http_code)"
            # Return response without formatting - let caller handle it
            echo "$response"
            return 0
            ;;
        400|404|500)
            # Format error output based on output mode
            output_format=$(get_output_format "text")
            
            if [[ "$output_format" == "json" ]]; then
                # JSON mode: output compact error without stack trace
                print_error "HTTP Error ($http_code)"
                if command -v jq >/dev/null 2>&1; then
                    echo "$response" | jq -c 'del(.data.stack)' >&2
                else
                    echo "$response" >&2
                fi
            else
                # Text mode: extract human-readable error
                print_error "HTTP Error ($http_code)"
                if command -v jq >/dev/null 2>&1; then
                    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"' 2>/dev/null)
                    error_code=$(echo "$response" | jq -r '.error_code // ""' 2>/dev/null)
                    if [ -n "$error_code" ] && [ "$error_code" != "null" ]; then
                        echo "Error: $error_msg (code: $error_code)" >&2
                    else
                        echo "Error: $error_msg" >&2
                    fi
                else
                    echo "$response" >&2
                fi
            fi
            exit 1
            ;;
        *)
            print_error "HTTP $http_code"
            echo "$response" >&2
            exit 1
            ;;
    esac
}

# Handle response based on CLI flags - optimized for testing
handle_response_json() {
    local response="$1"
    local operation_type="$2"  # "list", "create", "select", etc. (unused, kept for compatibility)

    # Pass through response directly - API handles all formatting
    echo "$response"
}

# Validate required arguments
require_args() {
    local required_count="$1"
    local actual_count="$2"
    local usage="$3"
    
    if [ "$actual_count" -lt "$required_count" ]; then
        print_error "Missing required arguments"
        print_info "Usage: $usage"
        exit 1
    fi
}

# Check dependencies - keep it simple
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed."
        exit 1
    fi
    
    # Check for JSON parser for extraction operations (prefer jq over jshon)
    if command -v jq &> /dev/null; then
        export JSON_PARSER="jq"
    elif command -v jshon &> /dev/null; then
        export JSON_PARSER="jshon"
    else
        export JSON_PARSER="none"
    fi
}

# Legacy function - kept for compatibility
init_servers_config() {
    # Redirect to new CLI config initialization
    init_cli_configs
}

# Parse hostname:port into components
parse_endpoint() {
    local endpoint="$1"
    local hostname=""
    local port=""
    local protocol=""
    
    # Handle protocol prefixes
    if echo "$endpoint" | grep -q "^https://"; then
        protocol="https"
        endpoint=$(echo "$endpoint" | sed 's|^https://||')
    elif echo "$endpoint" | grep -q "^http://"; then
        protocol="http"
        endpoint=$(echo "$endpoint" | sed 's|^http://||')
    fi
    
    # Parse hostname:port
    if echo "$endpoint" | grep -q ":"; then
        hostname=$(echo "$endpoint" | cut -d':' -f1)
        port=$(echo "$endpoint" | cut -d':' -f2)
    else
        hostname="$endpoint"
        port="80"
    fi
    
    # Auto-detect protocol if not specified
    if [ -z "$protocol" ]; then
        if [ "$port" = "443" ]; then
            protocol="https"
        else
            protocol="http"
        fi
    fi
    
    echo "$protocol|$hostname|$port"
}

# Health check a server URL
ping_server_url() {
    local base_url="$1"
    local timeout="${2:-5}"
    
    # Try to ping the /ping endpoint with a short timeout
    if curl -s --max-time "$timeout" --fail "$base_url/ping" >/dev/null 2>&1; then
        return 0
    elif curl -s --max-time "$timeout" --fail "$base_url/" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Initialize tenant database schema
init_tenant_schema() {
    local tenant_name="$1"
    local db_user="${2:-$(whoami)}"
    
    # Find the schema file relative to the CLI root
    local schema_file=""
    
    # Try different possible locations for the schema file
    if [ -f "../sql/init-tenant.sql" ]; then
        schema_file="../sql/init-tenant.sql"
    elif [ -f "../../sql/init-tenant.sql" ]; then
        schema_file="../../sql/init-tenant.sql"
    elif [ -f "sql/init-tenant.sql" ]; then
        schema_file="sql/init-tenant.sql"
    else
        print_error "Schema file not found: init-tenant.sql"
        return 1
    fi
    
    print_info "Initializing tenant database schema..."
    if psql -U "$db_user" -d "$tenant_name" -f "$schema_file" >/dev/null 2>&1; then
        print_success "Tenant database schema initialized"
        return 0
    else
        print_error "Failed to initialize tenant database schema"
        return 1
    fi
}

# Make HTTP request with YAML content-type for meta API
make_request_yaml() {
    local method="$1"
    local url="$2"
    local data="$3"
    local base_url=$(get_base_url)
    local full_url="${base_url}${url}"
    
    print_info "Making $method request to: $full_url with YAML content-type"
    
    local curl_args=(-s -X "$method" -H "Content-Type: text/yaml")
    
    # Add JWT token if available (unless it's an auth request)
    if [[ "$url" != "/auth/"* ]]; then
        local jwt_token
        jwt_token=$(get_jwt_token)
        if [ -n "$jwt_token" ]; then
            curl_args+=(-H "Authorization: Bearer $jwt_token")
            print_info "Using stored JWT token"
        fi
    fi
    
    if [ -n "$data" ]; then
        curl_args+=(-d "$data")
    fi
    
    local response
    local http_code
    
    # Make request and capture both response and HTTP status code
    response=$(curl "${curl_args[@]}" -w "\n%{http_code}" "$full_url")
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d')
    
    # Handle HTTP errors
    case "$http_code" in
        200|201|204)
            print_success "Success ($http_code)"
            # Return response directly (YAML format)
            echo "$response"
            return 0
            ;;
        400|404|500)
            print_error "HTTP Error ($http_code)"
            echo "$response" >&2
            exit 1
            ;;
        *)
            print_error "HTTP $http_code"
            echo "$response" >&2
            exit 1
            ;;
    esac
}

# Handle YAML response - much simpler than JSON
handle_response_yaml() {
    local response="$1"
    local operation_type="$2"  # "create", "select", "update", "delete"
    
    # Exit code only mode - check if response is not empty for success
    if [ "$CLI_EXIT_CODE_ONLY" = "true" ]; then
        if [ -n "$response" ] || [ "$operation_type" = "delete" ]; then
            exit 0
        else
            exit 1
        fi
    fi
    
    # For YAML responses, just output directly
    echo "$response"
}

# Detect if input is array or object
detect_input_type() {
    local input="$1"
    
    if [ "$JSON_PARSER" = "jq" ]; then
        if echo "$input" | jq -e 'type == "array"' >/dev/null 2>&1; then
            echo "array"
        else
            echo "object"
        fi
    else
        # Fallback detection - check first non-whitespace character
        first_char=$(echo "$input" | sed 's/^[[:space:]]*//' | cut -c1)
        if [ "$first_char" = "[" ]; then
            echo "array"
        else
            echo "object"
        fi
    fi
}

# Extract ID from object
extract_id_from_object() {
    local input="$1"
    
    if [ "$JSON_PARSER" = "jq" ]; then
        echo "$input" | jq -r '.id // empty'
    elif [ "$JSON_PARSER" = "jshon" ]; then
        echo "$input" | jshon -e id -u 2>/dev/null || echo ""
    else
        # Fallback extraction
        echo "$input" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1
    fi
}

# Remove ID from object (for update operations)
remove_id_from_object() {
    local input="$1"
    
    if [ "$JSON_PARSER" = "jq" ]; then
        echo "$input" | jq 'del(.id)'
    elif [ "$JSON_PARSER" = "jshon" ]; then
        echo "$input" | jshon -d id 2>/dev/null || echo "$input"
    else
        # Fallback - remove id field (basic regex)
        echo "$input" | sed 's/"id"[[:space:]]*:[[:space:]]*"[^"]*"[[:space:]]*,\?//g' | sed 's/,[[:space:]]*}/}/g'
    fi
}

# Read and validate JSON input from stdin
read_and_validate_json_input() {
    local operation="$1"
    local schema="$2"
    
    # Read JSON data from stdin
    local json_data
    json_data=$(cat)
    
    if [ -z "$json_data" ]; then
        print_error "No JSON data provided on stdin"
        exit 1
    fi
    
    print_info "${operation^} $schema record(s) with data:"
    if [ "$CLI_VERBOSE" = "true" ]; then
        echo "$json_data" | sed 's/^/  /' >&2
    fi
    
    echo "$json_data"
}

# Process data operations with flexible input handling
process_data_operation() {
    local operation="$1"      # create/update/delete
    local http_method="$2"    # POST/PUT/DELETE
    local schema="$3"
    local id="$4"            # optional
    local json_data="$5"
    local confirmation="${6:-false}"  # require confirmation for destructive ops
    
    # Special case: DELETE with ID but no JSON data
    if [ "$operation" = "delete" ] && [ -n "$id" ] && [ -z "$json_data" ]; then
        if [ "$confirmation" = "true" ] && [ "$CLI_VERBOSE" = "true" ]; then
            print_warning "Are you sure you want to delete $schema record: $id? (y/N)"
            read -r user_confirmation
            
            if ! echo "$user_confirmation" | grep -E "^[Yy]$" >/dev/null 2>&1; then
                print_info "Operation cancelled"
                exit 0
            fi
        fi
        
        response=$(make_request_json "$http_method" "/api/data/$schema/$id" "")
        handle_response_json "$response" "$operation"
        return
    fi
    
    # All other cases require JSON data
    if [ -z "$json_data" ]; then
        print_error "No JSON data provided"
        exit 1
    fi
    
    # Detect input type and handle accordingly
    input_type=$(detect_input_type "$json_data")
    
    if [ -n "$id" ]; then
        # ID provided as parameter - use object endpoint
        print_info "Using provided ID: $id"
        
        # For object endpoint, remove ID from payload if present (API doesn't expect it)
        local clean_data
        if [ "$operation" = "update" ]; then
            clean_data=$(remove_id_from_object "$json_data")
        else
            clean_data="$json_data"
        fi
        
        response=$(make_request_json "$http_method" "/api/data/$schema/$id" "$clean_data")
        handle_response_json "$response" "$operation"
        
    elif [ "$input_type" = "array" ]; then
        # Array input → Bulk operation via array endpoint
        print_info "Processing array input for bulk $operation"
        response=$(make_request_json "$http_method" "/api/data/$schema" "$json_data")
        handle_response_json "$response" "$operation"
        
    elif [ "$operation" = "create" ]; then
        # CREATE: Object input → Array API → Object output (unwrap)
        print_info "Processing single object input"
        array_data="[$json_data]"
        response=$(make_request_json "$http_method" "/api/data/$schema" "$array_data")
        
        # Extract single object from array response to match input format
        if [ "$JSON_PARSER" = "jq" ]; then
            single_response=$(echo "$response" | jq '{"success": .success, "data": .data[0], "error": .error, "error_code": .error_code}' 2>/dev/null || echo "$response")
            handle_response_json "$single_response" "$operation"
        else
            handle_response_json "$response" "$operation"
        fi
        
    else
        # UPDATE/DELETE: Object input, no ID param → Extract ID from object, use object endpoint
        extracted_id=$(extract_id_from_object "$json_data")
        
        if [ -z "$extracted_id" ] || [ "$extracted_id" = "null" ]; then
            print_error "No ID provided as parameter and no 'id' field found in JSON object"
            print_info "Usage: monk data $operation $schema <id> OR provide JSON with 'id' field"
            exit 1
        fi
        
        print_info "Extracted ID from object: $extracted_id"
        
        # Confirmation for extracted ID delete operations
        if [ "$operation" = "delete" ] && [ "$confirmation" = "true" ] && [ "$CLI_VERBOSE" = "true" ]; then
            print_warning "Are you sure you want to delete $schema record: $extracted_id? (y/N)"
            read -r user_confirmation
            
            if ! echo "$user_confirmation" | grep -E "^[Yy]$" >/dev/null 2>&1; then
                print_info "Operation cancelled"
                exit 0
            fi
        fi
        
        # Remove ID from payload for object endpoint (UPDATE only)
        local clean_data
        if [ "$operation" = "update" ]; then
            clean_data=$(remove_id_from_object "$json_data")
        else
            clean_data=""  # DELETE doesn't need payload
        fi
        
        response=$(make_request_json "$http_method" "/api/data/$schema/$extracted_id" "$clean_data")
        handle_response_json "$response" "$operation"
    fi
}

# Check if JSON has complex where clause (indicating need for find command)
has_complex_query() {
    local json_data="$1"
    
    if [ "$JSON_PARSER" = "jq" ]; then
        # Check if 'where' field exists
        echo "$json_data" | jq -e '.where' >/dev/null 2>&1
    elif [ "$JSON_PARSER" = "jshon" ]; then
        echo "$json_data" | jshon -e where >/dev/null 2>&1
    else
        # Fallback: basic grep for "where" key
        echo "$json_data" | grep -q '"where"[[:space:]]*:'
    fi
}

# Build query string from JSON parameters (excluding 'where')
build_query_string() {
    local json_data="$1"
    local query_params=""
    
    if [ "$JSON_PARSER" = "jq" ]; then
        # Extract all keys except 'where' and build query string
        local keys
        keys=$(echo "$json_data" | jq -r 'del(.where) | to_entries[] | "\(.key)=\(.value)"' 2>/dev/null)
        
        if [ -n "$keys" ]; then
            # URL encode and join with &
            query_params=$(echo "$keys" | sed 's/ /+/g' | tr '\n' '&' | sed 's/&$//')
        fi
    elif [ "$JSON_PARSER" = "jshon" ]; then
        # Basic jshon parsing (limited functionality)
        local limit offset order
        limit=$(echo "$json_data" | jshon -e limit -u 2>/dev/null || echo "")
        offset=$(echo "$json_data" | jshon -e offset -u 2>/dev/null || echo "")
        order=$(echo "$json_data" | jshon -e order -u 2>/dev/null || echo "")
        
        local params=""
        [ -n "$limit" ] && params="${params}limit=${limit}&"
        [ -n "$offset" ] && params="${params}offset=${offset}&"
        [ -n "$order" ] && params="${params}order=$(echo "$order" | sed 's/ /+/g')&"
        
        query_params="${params%&}"  # Remove trailing &
    else
        # Fallback: basic regex extraction for common parameters
        local limit offset order
        limit=$(echo "$json_data" | grep -o '"limit"[[:space:]]*:[[:space:]]*[0-9]*' | sed 's/.*:[[:space:]]*//')
        offset=$(echo "$json_data" | grep -o '"offset"[[:space:]]*:[[:space:]]*[0-9]*' | sed 's/.*:[[:space:]]*//')
        order=$(echo "$json_data" | grep -o '"order"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/' | sed 's/ /+/g')
        
        local params=""
        [ -n "$limit" ] && params="${params}limit=${limit}&"
        [ -n "$offset" ] && params="${params}offset=${offset}&"
        [ -n "$order" ] && params="${params}order=${order}&"
        
        query_params="${params%&}"  # Remove trailing &
    fi
    
    if [ -n "$query_params" ]; then
        echo "?${query_params}"
    fi
}

# Redirect to find command with JSON input
redirect_to_find() {
    local schema="$1"
    local json_data="$2"
    
    print_info "Complex query detected, redirecting to 'monk find $schema'"
    
    # Execute find command with the JSON data
    echo "$json_data" | "${BASH_SOURCE[0]%/*}/find_command.sh" "$schema"
}

# Build file API request payload with path and options
build_file_payload() {
    local path="$1"
    local options="$2"
    
    if [ -n "$options" ]; then
        jq -n --arg path "$path" --argjson options "$options" \
           '{"path": $path, "file_options": $options}'
    else
        jq -n --arg path "$path" '{"path": $path}'
    fi
}

# Process file API response and extract specific field - UPDATED for new API format
process_file_response() {
    local response="$1"
    local extract_field="$2"  # "content", "entries", "results.deleted_count", etc. (optional)
    
    if [ "$JSON_PARSER" = "jq" ]; then
        if [ -n "$extract_field" ]; then
            local jq_suffix=""
            local IFS='.'
            read -ra path_parts <<< "$extract_field"
            unset IFS
            for part in "${path_parts[@]}"; do
                if [[ "$part" =~ ^[0-9]+$ ]]; then
                    jq_suffix+="[${part}]"
                else
                    jq_suffix+="[\"$part\"]"
                fi
            done
            local jq_filter=".data${jq_suffix} // .${jq_suffix}"
            echo "$response" | jq "$jq_filter" 2>/dev/null
        else
            echo "$response"
        fi
    else
        print_error "jq required for file operations"
        exit 1
    fi
}

# Make file API request with standard error handling - UPDATED to use /api/file endpoints
make_file_request() {
    local endpoint="$1"    # list, retrieve, store, stat
    local payload="$2"
    
    local response
    response=$(make_request_json "POST" "/api/file/$endpoint" "$payload")
    
    # Check for file-specific error handling if needed
    echo "$response"
}

# Format ls-style output from FTP list entries - UPDATED for new API format
format_ls_output() {
    local entries="$1"
    local long_format="${2:-false}"
    
    if [ "$long_format" = "true" ]; then
        # Long format shows detailed information - use printf for formatting
        echo "$entries" | jq -r '.[] | "\(.file_permissions) \(.file_size | tostring) \(.file_modified) \(.name)"' | \
        while IFS=' ' read -r permissions size modified name; do
            printf "%-10s %8s %s %s\n" "$permissions" "$size" "$modified" "$name"
        done
    else
        # Simple format shows just names
        echo "$entries" | jq -r '.[] | .name'
    fi
}

# Parse tenant path and extract routing information
parse_tenant_path() {
    local path="$1"
    
    if [[ "$path" =~ ^/tenant/([^/]+)/(.*) ]]; then
        local tenant_spec="${BASH_REMATCH[1]}"
        local api_path="/${BASH_REMATCH[2]}"
        
        # Parse tenant specification (server:tenant or just tenant)
        if [[ "$tenant_spec" =~ ^([^:]+):(.+)$ ]]; then
            # Full server:tenant specification
            echo "server=${BASH_REMATCH[1]};tenant=${BASH_REMATCH[2]};path=$api_path;tenant_routing=true"
        else
            # Tenant only, use current server
            echo "server=current;tenant=$tenant_spec;path=$api_path;tenant_routing=true"
        fi
    else
        # Standard path, use current session
        echo "server=current;tenant=current;path=$path;tenant_routing=false"
    fi
}

# Get current session alias (for backwards compatibility, returns session alias)
current_session_key() {
    get_current_session
}

# Resolve session from alias or tenant name
# Returns the session alias if found
resolve_session() {
    local alias_or_tenant="$1"

    init_cli_configs

    # If empty, return current session
    if [ -z "$alias_or_tenant" ]; then
        get_current_session
        return $?
    fi

    # Check if it's an exact alias match
    if jq -e ".sessions.\"$alias_or_tenant\"" "$SESSIONS_CONFIG" >/dev/null 2>&1; then
        echo "$alias_or_tenant"
        return 0
    fi

    # Try to find by tenant name
    local found_alias
    found_alias=$(jq -r ".sessions | to_entries[] | select(.value.tenant == \"$alias_or_tenant\") | .key" "$SESSIONS_CONFIG" 2>/dev/null | head -1)

    if [ -n "$found_alias" ]; then
        echo "$found_alias"
        return 0
    fi

    print_error "No session found for '$alias_or_tenant'"
    print_info_always "Use 'monk auth login $alias_or_tenant --server <url>' to create a session"
    return 1
}

# Temporarily switch context for single operation
with_tenant_context() {
    local target_alias="$1"
    local operation_func="$2"
    shift 2
    local args=("$@")

    # Save current session
    local original_session
    original_session=$(get_current_session)

    print_info "Switching to session: $target_alias"

    # Temporarily switch
    local temp_file=$(mktemp)
    jq --arg alias "$target_alias" '.current_session = $alias' "$SESSIONS_CONFIG" > "$temp_file" && mv "$temp_file" "$SESSIONS_CONFIG"

    # Execute operation with new context
    local result exit_code
    result=$("$operation_func" "${args[@]}")
    exit_code=$?

    # Restore original session
    temp_file=$(mktemp)
    if [ -n "$original_session" ]; then
        jq --arg alias "$original_session" '.current_session = $alias' "$SESSIONS_CONFIG" > "$temp_file" && mv "$temp_file" "$SESSIONS_CONFIG"
    else
        jq '.current_session = null' "$SESSIONS_CONFIG" > "$temp_file" && mv "$temp_file" "$SESSIONS_CONFIG"
    fi

    print_info "Restored session: ${original_session:-<none>}"

    echo "$result"
    return $exit_code
}

# Enhanced file API request with tenant routing support
make_file_request_with_routing() {
    local endpoint="$1"    # list, stat, retrieve, store
    local path="$2"
    local options="$3"
    local tenant_flag="$4" # Optional --tenant flag value
    
    local routing_info target_session_key api_path
    
    # Determine routing: flag takes precedence over path-based routing
    if [ -n "$tenant_flag" ]; then
        # Use --tenant flag specification
        if [[ "$tenant_flag" =~ ^([^:]+):(.+)$ ]]; then
            # Full server:tenant from flag
            target_session_key=$(resolve_session "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}")
        else
            # Tenant only from flag, use current server  
            target_session_key=$(resolve_session "current" "$tenant_flag")
        fi
        api_path="$path"  # Use path as-is when flag provided
        
    else
        # Parse path for tenant routing
        routing_info=$(parse_tenant_path "$path")
        eval "$routing_info"  # Sets server, tenant, path, tenant_routing variables
        
        if [ "$tenant_routing" = "true" ]; then
            target_session_key=$(resolve_session "$server" "$tenant")
            api_path="$path"  # api_path from parsing
        else
            # Standard operation with current session
            target_session_key=$(current_session_key)
            api_path="$path"
        fi
    fi
    
    # Validate session exists
    if ! validate_session "$target_session_key"; then
        return 1
    fi
    
    # Build payload
    local payload
    payload=$(build_file_payload "$api_path" "$options")
    
    # Execute request with appropriate context
    local current_key
    current_key=$(current_session_key 2>/dev/null)
    
    if [ "$target_session_key" = "$current_key" ]; then
        # Same as current context - direct execution
        make_file_request "$endpoint" "$payload"
    else
        # Different context - use temporary switching
        with_tenant_context "$target_session_key" make_file_request "$endpoint" "$payload"
    fi
}

# Validate session exists and has valid authentication
validate_session() {
    local session_alias="$1"

    if [ -z "$session_alias" ]; then
        return 1
    fi

    local jwt_token
    jwt_token=$(jq -r ".sessions.\"$session_alias\".jwt_token" "$SESSIONS_CONFIG" 2>/dev/null)

    if [ -n "$jwt_token" ] && [ "$jwt_token" != "null" ]; then
        return 0
    else
        return 1
    fi
}

# Validate schema exists (best effort)
validate_schema() {
    local schema="$1"
    
    # Don't validate if running in non-verbose mode for speed
    if [ "$CLI_VERBOSE" != "true" ]; then
        return 0
    fi
    
    # Try to get schema info - if it fails, just warn but continue
    local response
    if response=$(make_request_json "GET" "/api/meta/schema" "" 2>/dev/null); then
        if echo "$response" | grep -q "\"$schema\""; then
            print_info "Schema validated: $schema"
        else
            print_warning "Schema '$schema' not found in meta API, but continuing anyway"
        fi
    else
        print_info "Could not validate schema dynamically, assuming valid: $schema"
    fi
}

# URL encode a string for safe HTTP requests
url_encode() {
    local string="$1"
    # Use python for proper URL encoding if available, otherwise basic sed
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import urllib.parse; print(urllib.parse.quote('''$string''', safe=''))"
    else
        # Fallback: basic encoding for common characters
        printf '%s' "$string" | sed \
            -e 's/ /%20/g' \
            -e 's/!/%21/g' \
            -e 's/"/%22/g' \
            -e 's/#/%23/g' \
            -e 's/\$/%24/g' \
            -e 's/%/%25/g' \
            -e 's/&/%26/g' \
            -e "s/'/%27/g"
    fi
}

# Build query string with format, unwrap, select, and encrypt parameters
build_api_query_string() {
    local format="${args[--format]:-}"
    local unwrap="${args[--unwrap]:-}"
    local select="${args[--select]:-}"
    local encrypt="${args[--encrypt]:-}"
    local query_params=""

    # Add format parameter
    if [ -n "$format" ]; then
        query_params="format=$(url_encode "$format")"
    fi

    # Add unwrap parameter (boolean flag)
    if [ -n "$unwrap" ]; then
        if [ -n "$query_params" ]; then
            query_params="${query_params}&"
        fi
        query_params="${query_params}unwrap"
    fi

    # Add select parameter
    if [ -n "$select" ]; then
        if [ -n "$query_params" ]; then
            query_params="${query_params}&"
        fi
        query_params="${query_params}select=$(url_encode "$select")"
    fi

    # Add encrypt parameter
    if [ -n "$encrypt" ]; then
        if [ -n "$query_params" ]; then
            query_params="${query_params}&"
        fi
        query_params="${query_params}encrypt=$(url_encode "$encrypt")"
    fi

    # Return query string with leading ? if params exist
    if [ -n "$query_params" ]; then
        echo "?${query_params}"
    fi
}

# Get Accept header based on format parameter
get_accept_header() {
    local format="${args[--format]:-}"

    case "$format" in
        toon)
            echo "application/toon"
            ;;
        yaml)
            echo "application/yaml"
            ;;
        markdown)
            echo "text/markdown"
            ;;
        morse)
            echo "application/morse"
            ;;
        qr)
            echo "text/plain"
            ;;
        brainfuck)
            echo "text/plain"
            ;;
        json|"")
            echo "application/json"
            ;;
        *)
            echo "application/json"
            ;;
    esac
}

# Make HTTP request to sudo API (requires sudo token from /api/auth/sudo)
make_sudo_request() {
    local method="$1"
    local endpoint="$2"  # e.g., "users", "users/:id"
    local data="$3"
    local base_url=$(get_base_url)
    
    # Get sudo token
    local sudo_token
    sudo_token=$(get_sudo_token)
    
    if [ -z "$sudo_token" ]; then
        print_error "No sudo token found or token expired"
        print_info "Use 'monk auth sudo' to acquire a sudo token first"
        exit 1
    fi
    
    local full_url="${base_url}/api/sudo/${endpoint}"
    
    print_info "Making $method request to: $full_url"
    
    local curl_args=(-s -X "$method")
    
    # Add sudo token
    curl_args+=(-H "Authorization: Bearer $sudo_token")
    print_info "Using stored sudo token"
    
    # Add content-type header if data provided
    if [ -n "$data" ]; then
        curl_args+=(-H "Content-Type: application/json" -d "$data")
    fi
    
    local response
    local http_code
    
    # Make request and capture both response and HTTP status code
    response=$(curl "${curl_args[@]}" -w "\n%{http_code}" "$full_url")
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d')
    
    # Handle HTTP errors
    case "$http_code" in
        200|201|204)
            print_success "Success ($http_code)"
            echo "$response"
            return 0
            ;;
        401)
            print_error "HTTP Error ($http_code) - Unauthorized"
            print_info "Your sudo token may have expired. Use 'monk auth sudo' to get a new token"
            echo "$response" >&2
            exit 1
            ;;
        403)
            print_error "HTTP Error ($http_code) - Forbidden"
            print_info "Sudo token required. Use 'monk auth sudo' to escalate privileges"
            echo "$response" >&2
            exit 1
            ;;
        400|404|409|500)
            print_error "HTTP Error ($http_code)"
            echo "$response" >&2
            exit 1
            ;;
        *)
            print_error "HTTP $http_code"
            echo "$response" >&2
            exit 1
            ;;
    esac
}

# Confirm destructive operation with user input
confirm_destructive_operation() {
    local operation="$1"
    local target="$2"
    local force_flag="$3"
    local confirmation_word="${4:-y}"  # Default to 'y', or use custom word like 'DELETE'
    
    if [[ "$force_flag" == "1" ]]; then
        return 0  # Skip confirmation if --force used
    fi
    
    if [[ "$confirmation_word" == "y" ]]; then
        print_warning "Are you sure you want to $operation '$target'? (y/N)"
        read -r user_input
        
        if echo "$user_input" | grep -E "^[Yy]$" >/dev/null 2>&1; then
            return 0
        else
            print_info "Operation cancelled"
            exit 0
        fi
    else
        print_warning "DANGER: This will $operation '$target'!"
        print_warning "Type '$confirmation_word' to confirm:"
        read -r user_input
        
        if [[ "$user_input" == "$confirmation_word" ]]; then
            return 0
        else
            print_info "Operation cancelled"
            exit 0
        fi
    fi
}

# Determine output format from global flags
get_output_format() {
    local default_format="$1"  # "text" or "json"
    
    # Legacy function - now that formatting is handled server-side via --format,
    # this just returns the default. Commands should migrate to server-side formatting.
    echo "$default_format"
}

# Validate format compatibility and show error if incompatible
validate_output_format() {
    local requested_format="$1"
    local supported_formats="$2"  # Space-separated list: "text json"
    
    if [[ "$supported_formats" == *"$requested_format"* ]]; then
        return 0
    else
        print_error "Output format '$requested_format' not supported for this command"
        print_info "Supported formats: $(echo "$supported_formats" | tr ' ' ', ')"
        exit 1
    fi
}

# Convert JSON to human-readable text format
json_to_text() {
    local json_data="$1"
    local context="$2"  # Context hint for formatting (e.g., "server_list", "tenant_status")
    
    if [ "$JSON_PARSER" != "jq" ]; then
        print_error "jq required for text formatting"
        echo "$json_data"
        return
    fi
    
    case "$context" in
        "server_list")
            echo
            printf "%-15s %-30s %-8s %-8s %-12s %-20s %s\n" "Name" "Endpoint" "Status" "Auth" "Last Ping" "Added" "Description"
            echo "--------------------------------------------------------------------------------------------"
            echo "$json_data" | jq -r '.servers[]? | [.name, .endpoint, .status, (if .auth_sessions > 0 then "yes (\(.auth_sessions))" else "no" end), (.last_ping | split("T")[0]), (.added_at | split("T")[0]), .description] | @tsv' | \
            while IFS=$'\t' read -r name endpoint status auth last_ping added desc; do
                current_marker=""
                if echo "$json_data" | jq -e ".current_server == \"$name\"" >/dev/null 2>&1; then
                    current_marker=" *"
                fi
                printf "%-15s %-30s %-8s %-8s %-12s %-20s %s%s\n" "$name" "$endpoint" "$status" "$auth" "$last_ping" "$added" "$desc" "$current_marker"
            done
            echo
            ;;
        "tenant_list")
            echo
            printf "%-20s %-30s %-8s %-20s %s\n" "Name" "Display Name" "Auth" "Added" "Description"
            echo "-------------------------------------------------------------------------------------"
            echo "$json_data" | jq -r '.tenants[]? | [.name, .display_name, (if .authenticated then "yes" else "no" end), (.added_at | split("T")[0]), .description] | @tsv' | \
            while IFS=$'\t' read -r name display_name auth added desc; do
                current_marker=""
                if echo "$json_data" | jq -e ".current_tenant == \"$name\"" >/dev/null 2>&1; then
                    current_marker=" *"
                fi
                printf "%-20s %-30s %-8s %-20s %s%s\n" "$name" "$display_name" "$auth" "$added" "$desc" "$current_marker"
            done
            echo
            ;;
        "auth_status")
            if echo "$json_data" | jq -e '.authenticated' >/dev/null 2>&1; then
                local tenant=$(echo "$json_data" | jq -r '.current_context.tenant')
                local server=$(echo "$json_data" | jq -r '.current_context.server')
                local user=$(echo "$json_data" | jq -r '.current_context.user')
                local database=$(echo "$json_data" | jq -r '.token_info.database')
                local exp_date=$(echo "$json_data" | jq -r '.token_info.exp_date')
                
                echo "Tenant: $tenant"
                echo "Database: $database"
                echo "Expires: $exp_date"
                echo "Server: $server"
                echo "Tenant: $tenant"
                echo "User: $user"
                print_success "Authenticated"
            else
                print_error "Not authenticated"
            fi
            ;;
        "data_table")
            # Generic data table - try to format as table if array
            if echo "$json_data" | jq -e 'type == "array"' >/dev/null 2>&1; then
                if echo "$json_data" | jq -e 'length > 0' >/dev/null 2>&1; then
                    # Get column headers from first object
                    local headers=$(echo "$json_data" | jq -r '.[0] | keys_unsorted | @tsv')
                    echo "$headers" | tr '\t' '\n' | nl -w3 -s') ' -v0
                    echo "---"
                    echo "$json_data" | jq -r '.[] | [.[] | tostring] | @tsv'
                else
                    echo "No data found"
                fi
            else
                echo "$json_data" | jq '.'
            fi
            ;;
        *)
            # Default: output compact JSON for machine readability
            echo "$json_data" | jq -c '.'
            ;;
    esac
}

# Convert JSON to YAML format
json_to_yaml() {
    local json_data="$1"
    
    if [ "$JSON_PARSER" = "jq" ]; then
        # Use yq if available, otherwise fallback to compact JSON with warning
        if command -v yq >/dev/null 2>&1; then
            echo "$json_data" | yq -P '.'
        else
            print_warning "yq not available - outputting compact JSON instead of YAML" >&2
            echo "$json_data" | jq -c '.'
        fi
    else
        print_error "jq required for YAML conversion"
        echo "$json_data"
    fi
}

# Convert YAML to JSON format
yaml_to_json() {
    local yaml_data="$1"
    
    if command -v yq >/dev/null 2>&1; then
        echo "$yaml_data" | yq -o=json '.'
    else
        print_error "yq required for YAML to JSON conversion"
        echo "$yaml_data"
    fi
}

# Detect input format based on first non-whitespace character
detect_input_format() {
    local input_data="$1"
    
    # Get first non-whitespace character
    local first_char=$(echo "$input_data" | sed 's/^[[:space:]]*//' | cut -c1)
    
    if [[ "$first_char" == "{" || "$first_char" == "[" ]]; then
        echo "json"
    else
        echo "yaml"
    fi
}

# Convert JSON to YAML with graceful fallback
convert_json_to_yaml() {
    local json_data="$1"
    
    # Try yq first (best option)
    if command -v yq >/dev/null 2>&1; then
        echo "$json_data" | yq -P '.'
        return $?
    fi
    
    # Try python fallback
    if command -v python3 >/dev/null 2>&1; then
        if echo "$json_data" | python3 -c "import yaml,json,sys; print(yaml.dump(json.load(sys.stdin), default_flow_style=False).rstrip())" 2>/dev/null; then
            return 0
        fi
    fi
    
    # Try ruby fallback  
    if command -v ruby >/dev/null 2>&1; then
        if echo "$json_data" | ruby -e "require 'yaml','json'; puts YAML.dump(JSON.parse(STDIN.read))" 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# Convert YAML to JSON with graceful fallback
convert_yaml_to_json() {
    local yaml_data="$1"
    
    # Try yq first (best option)
    if command -v yq >/dev/null 2>&1; then
        echo "$yaml_data" | yq -o=json '.'
        return $?
    fi
    
    # Try python fallback
    if command -v python3 >/dev/null 2>&1; then
        if echo "$yaml_data" | python3 -c "import yaml,json,sys; print(json.dumps(yaml.safe_load(sys.stdin), separators=(',', ':')))" 2>/dev/null; then
            return 0
        fi
    fi
    
    # Try ruby fallback
    if command -v ruby >/dev/null 2>&1; then
        if echo "$yaml_data" | ruby -e "require 'yaml','json'; puts JSON.generate(YAML.load(STDIN.read))" 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# Make HTTP request with YAML content-type and JSON/YAML autodetect
make_request_yaml_autodetect() {
    local method="$1"
    local url="$2"
    local input_data="$3"
    local input_format="$4"
    
    local yaml_data="$input_data"
    
    # Convert JSON to YAML if needed
    if [[ "$input_format" == "json" ]]; then
        print_info "Converting JSON input to YAML for API"
        
        yaml_data=$(convert_json_to_yaml "$input_data")
        if [[ $? -ne 0 ]]; then
            print_error "Failed to convert JSON input to YAML"
            print_info "JSON input detected but no suitable conversion tool available"
            print_info "Please install 'yq' or provide input in YAML format instead"
            print_info "Example: cat schema.yaml | monk describe select"
            exit 1
        fi
    fi
    
    # Make standard YAML request
    make_request_yaml "$method" "$url" "$yaml_data"
}

# Handle YAML response with JSON/YAML autodetect conversion
handle_response_yaml_autodetect() {
    local response="$1"
    local operation_type="$2"
    local original_input_format="$3"
    
    # Convert YAML response to JSON if original input was JSON
    if [[ "$original_input_format" == "json" && -n "$response" ]]; then
        print_info "Converting YAML response to JSON for format consistency"
        
        local json_response
        json_response=$(convert_yaml_to_json "$response")
        if [[ $? -eq 0 ]]; then
            # Output the JSON response (compact format)
            echo "$json_response" | jq -c '.' 2>/dev/null || echo "$json_response"
            return
        else
            print_warning "Failed to convert YAML response to JSON, outputting original YAML"
        fi
    fi
    
    # Default: handle as standard YAML response
    handle_response_yaml "$response" "$operation_type"
}

# Universal output handler - handles text and JSON formats
handle_output() {
    local data="$1"
    local requested_format="$2"
    local default_format="$3"
    local context="${4:-default}"
    local supported_formats="${5:-text json}"
    
    # Validate format is supported
    validate_output_format "$requested_format" "$supported_formats"
    
    # Handle JSON format - always compress to single line for machine readability
    if [[ "$requested_format" == "json" ]]; then
        if [[ "$default_format" == "json" ]]; then
            # Already JSON - compress it
            echo "$data" | jq -c '.'
        else
            print_error "Cannot convert text output to structured format"
            print_info "Text format is human-readable only"
            exit 1
        fi
        return
    fi
    
    # Handle text format
    if [[ "$requested_format" == "text" ]]; then
        if [[ "$default_format" == "text" ]]; then
            # Already text - output directly
            echo "$data"
        elif [[ "$default_format" == "json" ]]; then
            # Convert JSON to text
            json_to_text "$data" "$context"
        else
            print_error "Unsupported format conversion: $default_format to $requested_format"
            echo "$data"
        fi
        return
    fi
    
    # Fallback: output data as-is
    echo "$data"
}

##############################################################################
# Sync Helper Functions
##############################################################################

# Parse sync endpoint into components
# Formats supported:
#   tenant:schema                 (current server)
#   server:tenant:schema          (specific server)
#   /path/to/directory            (local filesystem)
#   ./relative/path               (local filesystem)
#
# Returns JSON object with:
#   {"type": "remote|local", "server": "...", "tenant": "...", "schema": "...", "path": "..."}
parse_sync_endpoint() {
    local endpoint="$1"
    
    # Check if it's a directory path
    if [[ "$endpoint" =~ ^[./] ]] || [[ "$endpoint" == /* ]]; then
        echo "{\"type\":\"local\",\"path\":\"$endpoint\"}"
        return 0
    fi
    
    # Count colons to determine format
    local colon_count=$(echo "$endpoint" | tr -cd ':' | wc -c | tr -d ' ')
    
    if [ "$colon_count" -eq 1 ]; then
        # Format: tenant:schema
        local tenant=$(echo "$endpoint" | cut -d: -f1)
        local schema=$(echo "$endpoint" | cut -d: -f2)
        local server=$(get_current_server_name)
        
        if [ -z "$server" ]; then
            print_error "No current server set. Use 'monk config server use <name>' first."
            return 1
        fi
        
        echo "{\"type\":\"remote\",\"server\":\"$server\",\"tenant\":\"$tenant\",\"schema\":\"$schema\"}"
        return 0
        
    elif [ "$colon_count" -eq 2 ]; then
        # Format: server:tenant:schema
        local server=$(echo "$endpoint" | cut -d: -f1)
        local tenant=$(echo "$endpoint" | cut -d: -f2)
        local schema=$(echo "$endpoint" | cut -d: -f3)
        
        echo "{\"type\":\"remote\",\"server\":\"$server\",\"tenant\":\"$tenant\",\"schema\":\"$schema\"}"
        return 0
    else
        print_error "Invalid endpoint format: $endpoint"
        print_info "Expected: tenant:schema, server:tenant:schema, or /path/to/dir"
        return 1
    fi
}

# Fetch data from a remote endpoint
# Args: server, tenant, schema, filter_json
# Returns: JSON array of records
sync_fetch_remote() {
    local server="$1"
    local tenant="$2"
    local schema="$3"
    local filter_json="$4"
    
    # Save current context
    local prev_server=$(get_current_server_name)
    local prev_tenant=$(get_current_tenant_name)
    
    # Switch to target context
    if [ "$server" != "$prev_server" ]; then
        switch_server "$server" >/dev/null 2>&1 || {
            print_error "Failed to switch to server: $server"
            return 1
        }
    fi
    
    if [ "$tenant" != "$prev_tenant" ]; then
        switch_tenant "$tenant" >/dev/null 2>&1 || {
            print_error "Failed to switch to tenant: $tenant"
            # Restore previous server
            [ -n "$prev_server" ] && switch_server "$prev_server" >/dev/null 2>&1
            return 1
        }
    fi
    
    # Fetch data
    local response
    if [ -n "$filter_json" ] && [ "$filter_json" != "null" ]; then
        # Use find API with filter
        response=$(make_request_json "POST" "/api/find/$schema" "$filter_json")
    else
        # Use data list API
        response=$(make_request_json "GET" "/api/data/$schema" "")
    fi
    
    # Restore previous context
    [ -n "$prev_tenant" ] && switch_tenant "$prev_tenant" >/dev/null 2>&1
    [ -n "$prev_server" ] && switch_server "$prev_server" >/dev/null 2>&1
    
    # Extract data array from response
    if [ "$JSON_PARSER" = "jq" ]; then
        if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
            echo "$response" | jq -c '.data'
        else
            print_error "API request failed"
            echo "$response" | jq -r '.error // "Unknown error"' >&2
            return 1
        fi
    else
        echo "$response"
    fi
}

# Compute diff between two datasets
# Args: source_data (JSON array), dest_data (JSON array)
# Returns: JSON diff object
sync_compute_diff() {
    local source_data="$1"
    local dest_data="$2"
    
    if [ "$JSON_PARSER" != "jq" ]; then
        print_error "jq is required for diff computation"
        return 1
    fi
    
    # Compute diff using jq
    jq -n \
        --argjson source "$source_data" \
        --argjson dest "$dest_data" '
        # Build ID-keyed maps
        ($source | map({(.id): .}) | add // {}) as $src_map |
        ($dest | map({(.id): .}) | add // {}) as $dst_map |
        
        # Find all unique IDs
        (($src_map | keys) + ($dst_map | keys) | unique) as $all_ids |
        
        # Categorize operations
        {
            summary: {
                source_count: ($source | length),
                dest_count: ($dest | length),
                total_ids: ($all_ids | length)
            },
            operations: (
                $all_ids | map(
                    . as $id |
                    if ($src_map | has($id) | not) then
                        {op: "delete", id: $id, record: $dst_map[$id]}
                    elif ($dst_map | has($id) | not) then
                        {op: "insert", id: $id, record: $src_map[$id]}
                    elif ($src_map[$id] == $dst_map[$id]) then
                        {op: "unchanged", id: $id}
                    else
                        {
                            op: "update",
                            id: $id,
                            old: $dst_map[$id],
                            new: $src_map[$id]
                        }
                    end
                )
            )
        } |
        # Add operation counts to summary
        .summary += {
            unchanged: ([.operations[] | select(.op == "unchanged")] | length),
            to_insert: ([.operations[] | select(.op == "insert")] | length),
            to_update: ([.operations[] | select(.op == "update")] | length),
            to_delete: ([.operations[] | select(.op == "delete")] | length)
        }
    '
}

# Format diff output for display
# Args: diff_json, format (summary|json)
sync_format_diff() {
    local diff_json="$1"
    local format="$2"
    
    if [ "$format" = "json" ]; then
        echo "$diff_json" | jq '.'
        return 0
    fi
    
    # Summary format (default)
    local source_count=$(echo "$diff_json" | jq -r '.summary.source_count')
    local dest_count=$(echo "$diff_json" | jq -r '.summary.dest_count')
    local unchanged=$(echo "$diff_json" | jq -r '.summary.unchanged')
    local to_insert=$(echo "$diff_json" | jq -r '.summary.to_insert')
    local to_update=$(echo "$diff_json" | jq -r '.summary.to_update')
    local to_delete=$(echo "$diff_json" | jq -r '.summary.to_delete')
    
    local total=$((unchanged + to_insert + to_update + to_delete))
    
    # Calculate percentages
    local unchanged_pct=0
    local insert_pct=0
    local update_pct=0
    local delete_pct=0
    
    if [ "$total" -gt 0 ]; then
        unchanged_pct=$(awk "BEGIN {printf \"%.1f\", ($unchanged / $total) * 100}")
        insert_pct=$(awk "BEGIN {printf \"%.1f\", ($to_insert / $total) * 100}")
        update_pct=$(awk "BEGIN {printf \"%.1f\", ($to_update / $total) * 100}")
        delete_pct=$(awk "BEGIN {printf \"%.1f\", ($to_delete / $total) * 100}")
    fi
    
    # Print summary
    echo "Sync Diff Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Source records:      $source_count"
    echo "Destination records: $dest_count"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Changes:"
    echo "  ✓ Unchanged:       $unchanged records (${unchanged_pct}%)"
    
    if [ "$to_insert" -gt 0 ]; then
        echo "  + To insert:       $to_insert records (${insert_pct}%)"
    fi
    
    if [ "$to_update" -gt 0 ]; then
        echo "  ~ To update:       $to_update records (${update_pct}%)"
    fi
    
    if [ "$to_delete" -gt 0 ]; then
        echo "  - To delete:       $to_delete records (${delete_pct}%)"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show totals
    local changes=$((to_insert + to_update + to_delete))
    if [ "$changes" -eq 0 ]; then
        echo "No changes needed - datasets are identical"
    else
        echo "Total changes: $changes operations"
    fi
}