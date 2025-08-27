#!/bin/bash

# Common functions for bashly CLI commands
# Clean rewrite to eliminate syntax errors and improve maintainability

# Clean separation of concerns:
# - server.json: Infrastructure endpoints  
# - auth.json: Authentication sessions per server+tenant
# - env.json: Current working context (server+tenant selection)

# CLI configuration files  
CLI_CONFIG_DIR="${HOME}/.config/monk/cli"
SERVER_CONFIG="${CLI_CONFIG_DIR}/server.json"
AUTH_CONFIG="${CLI_CONFIG_DIR}/auth.json"
ENV_CONFIG="${CLI_CONFIG_DIR}/env.json"

# Legacy config file (for migration)
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
    
    # Initialize individual config files
    init_server_config
    init_auth_config  
    init_env_config
}

# Initialize server config if it doesn't exist
init_server_config() {
    if [ ! -f "$SERVER_CONFIG" ]; then
        mkdir -p "$(dirname "$SERVER_CONFIG")"
        cat > "$SERVER_CONFIG" << 'EOF'
{
  "servers": {}
}
EOF
    fi
}

# Initialize auth config if it doesn't exist  
init_auth_config() {
    if [ ! -f "$AUTH_CONFIG" ]; then
        mkdir -p "$(dirname "$AUTH_CONFIG")"
        cat > "$AUTH_CONFIG" << 'EOF'
{
  "sessions": {}
}
EOF
    fi
}

# Initialize env config if it doesn't exist
init_env_config() {
    if [ ! -f "$ENV_CONFIG" ]; then
        mkdir -p "$(dirname "$ENV_CONFIG")"
        cat > "$ENV_CONFIG" << 'EOF'
{
  "current_server": null,
  "current_tenant": null,
  "current_user": null,
  "recents": []
}
EOF
    fi
}

# Migrate from legacy servers.json to new CLI config structure
migrate_legacy_config() {
    # Only migrate if legacy file exists and new structure doesn't
    if [[ -f "$LEGACY_SERVERS_CONFIG" && ! -f "$SERVER_CONFIG" ]]; then
        print_info "Migrating legacy configuration to new CLI structure..."
        
        # Ensure new config directory exists
        mkdir -p "$CLI_CONFIG_DIR"
        
        # Extract server info and current server from legacy config
        local servers_data current_server
        servers_data=$(jq '.servers' "$LEGACY_SERVERS_CONFIG" 2>/dev/null)
        current_server=$(jq -r '.current_server // empty' "$LEGACY_SERVERS_CONFIG" 2>/dev/null)
        
        # Create new server.json (infrastructure only)
        echo "{\"servers\": $servers_data}" > "$SERVER_CONFIG"
        
        # Create env.json with current server selection
        cat > "$ENV_CONFIG" << EOF
{
  "current_server": "$current_server",
  "current_tenant": null,
  "current_user": null,
  "recents": []
}
EOF
        
        # Create empty auth.json (tokens will be re-established)
        cat > "$AUTH_CONFIG" << 'EOF'
{
  "sessions": {}
}
EOF
        
        print_success "Configuration migrated to ~/.config/monk/cli/"
        print_warning "JWT tokens were not migrated - please re-authenticate with 'monk auth login'"
    fi
}

# Get base URL from server config - fail if not configured
get_base_url() {
    migrate_legacy_config
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for server configuration" >&2
        echo "Install jq to use server configuration" >&2
        exit 1
    fi
    
    # Check if config file exists
    if [[ ! -f "$SERVER_CONFIG" ]]; then
        echo "Error: No server configuration found" >&2
        echo "Use 'monk server add <name> <hostname:port>' to add a server" >&2
        exit 1
    fi
    
    # Get current server from env config
    init_env_config
    local current_server
    current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    
    if [[ -z "$current_server" || "$current_server" == "null" ]]; then
        echo "Error: No current server selected" >&2
        echo "Use 'monk server use <name>' to select a server" >&2
        exit 1
    fi
    
    # Get server info from server config
    local server_info
    server_info=$(jq -r ".servers.\"$current_server\"" "$SERVER_CONFIG" 2>/dev/null)
    
    if [[ "$server_info" == "null" ]]; then
        echo "Error: Current server '$current_server' not found in configuration" >&2
        echo "Use 'monk server list' to see available servers" >&2
        exit 1
    fi
    
    # Extract connection details
    local hostname=$(echo "$server_info" | jq -r '.hostname')
    local port=$(echo "$server_info" | jq -r '.port')
    local protocol=$(echo "$server_info" | jq -r '.protocol')
    
    # Validate required fields
    if [[ "$hostname" == "null" || "$port" == "null" || "$protocol" == "null" ]]; then
        echo "Error: Invalid server configuration for '$current_server'" >&2
        echo "Server configuration is missing required fields (hostname, port, protocol)" >&2
        exit 1
    fi
    
    echo "$protocol://$hostname:$port"
}

# Get stored JWT token for current server+tenant context
get_jwt_token() {
    init_cli_configs
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for JWT token management" >&2
        return 1
    fi
    
    # Get current context
    local current_server current_tenant
    current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
    
    if [ -z "$current_server" ] || [ "$current_server" = "null" ]; then
        # No current server selected
        return 1
    fi
    
    if [ -z "$current_tenant" ] || [ "$current_tenant" = "null" ]; then
        # No current tenant selected
        return 1
    fi
    
    # Get session-specific token using server:tenant key
    local session_key="${current_server}:${current_tenant}"
    local token
    token=$(jq -r ".sessions.\"$session_key\".jwt_token // empty" "$AUTH_CONFIG" 2>/dev/null)
    
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        echo "$token"
    else
        return 1
    fi
}

# Store JWT token for current server+tenant context
store_token() {
    local token="$1"
    local tenant="$2"
    local user="$3"
    
    init_cli_configs
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for JWT token management" >&2
        return 1
    fi
    
    # Get current server from env config
    local current_server
    current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    
    if [ -z "$current_server" ] || [ "$current_server" = "null" ]; then
        echo "Error: No current server selected. Use 'monk server use <name>' first" >&2
        return 1
    fi
    
    # Update env config with current tenant and user
    local temp_file=$(mktemp)
    jq --arg tenant "$tenant" \
       --arg user "$user" \
       '.current_tenant = $tenant | .current_user = $user' \
       "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"
    
    # Store token in auth config using server:tenant key
    local session_key="${current_server}:${tenant}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    temp_file=$(mktemp)
    jq --arg session_key "$session_key" \
       --arg token "$token" \
       --arg tenant "$tenant" \
       --arg user "$user" \
       --arg server "$current_server" \
       --arg timestamp "$timestamp" \
       '.sessions[$session_key] = {
           "jwt_token": $token,
           "tenant": $tenant,
           "user": $user, 
           "server": $server,
           "created_at": $timestamp
       }' "$AUTH_CONFIG" > "$temp_file" && mv "$temp_file" "$AUTH_CONFIG"
    
    # Set secure permissions on auth file
    chmod 600 "$AUTH_CONFIG"
}

# Remove stored JWT token for current server+tenant context
remove_stored_token() {
    init_cli_configs
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for JWT token management" >&2
        return 1
    fi
    
    # Get current context
    local current_server current_tenant
    current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
    
    if [ -z "$current_server" ] || [ "$current_server" = "null" ]; then
        echo "Error: No current server selected" >&2
        return 1
    fi
    
    if [ -z "$current_tenant" ] || [ "$current_tenant" = "null" ]; then
        # Clear all tenant info from env
        local temp_file=$(mktemp)
        jq '.current_tenant = null | .current_user = null' \
           "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"
        return 0
    fi
    
    # Remove session from auth config
    local session_key="${current_server}:${current_tenant}"
    local temp_file=$(mktemp)
    jq --arg session_key "$session_key" \
       'del(.sessions[$session_key])' \
       "$AUTH_CONFIG" > "$temp_file" && mv "$temp_file" "$AUTH_CONFIG"
    
    # Clear current tenant from env config
    temp_file=$(mktemp)
    jq '.current_tenant = null | .current_user = null' \
       "$ENV_CONFIG" > "$temp_file" && mv "$temp_file" "$ENV_CONFIG"
}

# Make HTTP request with JSON content-type - programmatic by default
make_request_json() {
    local method="$1"
    local url="$2"
    local data="$3"
    local base_url=$(get_base_url)
    local full_url="${base_url}${url}"
    
    print_info "Making $method request to: $full_url"
    
    local curl_args=(-s -X "$method" -H "Content-Type: application/json")
    
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
        200|201)
            print_success "Success ($http_code)"
            # Return response without formatting - let caller handle it
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

# Handle response based on CLI flags - optimized for testing
handle_response_json() {
    local response="$1"
    local operation_type="$2"  # "list", "create", "select", etc.
    
    # Exit code only mode - no output, just exit status
    if [ "$CLI_EXIT_CODE_ONLY" = "true" ]; then
        if echo "$response" | grep -q '"success":true'; then
            exit 0
        else
            exit 1
        fi
    fi
    
    # Count mode for list operations
    if [ "$CLI_COUNT_MODE" = "true" ] && [ "$operation_type" = "list" ]; then
        if [ "$JSON_PARSER" = "jq" ]; then
            echo "$response" | jq '.data | length' 2>/dev/null || echo "0"
        elif [ "$JSON_PARSER" = "jshon" ]; then
            echo "$response" | jshon -e data -l 2>/dev/null || echo "0"
        else
            echo "$response"
        fi
        return
    fi
    
    # Field extraction mode
    if [ -n "$CLI_FORMAT" ]; then
        if [ "$JSON_PARSER" = "jq" ]; then
            # Handle both single objects and arrays
            if echo "$response" | jq -e '.data | type == "array"' >/dev/null 2>&1; then
                # Array case - extract field from each item
                echo "$response" | jq -r ".data[].${CLI_FORMAT}" 2>/dev/null || {
                    print_error "Failed to extract field: $CLI_FORMAT"
                    exit 1
                }
            else
                # Single object case - extract field directly
                echo "$response" | jq -r ".data.${CLI_FORMAT}" 2>/dev/null || {
                    print_error "Failed to extract field: $CLI_FORMAT"
                    exit 1
                }
            fi
        elif [ "$JSON_PARSER" = "jshon" ]; then
            echo "$response" | jshon -e data -e "$CLI_FORMAT" -u 2>/dev/null || {
                print_error "Failed to extract field: $CLI_FORMAT"
                exit 1
            }
        else
            print_error "jq or jshon required for field extraction"
            exit 1
        fi
        return
    fi
    
    # Default: auto-extract 'data' property for cleaner output
    if [ "$JSON_PARSER" = "jq" ]; then
        # Check if response has success:true and extract data
        if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
            if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
                # Success response - extract data
                echo "$response" | jq '.data'
            else
                # Error response - show full response for debugging
                echo "$response"
            fi
        else
            # Not a standard API response - show raw
            echo "$response"
        fi
    elif [ "$JSON_PARSER" = "jshon" ]; then
        # Check if response has success:true and extract data
        if echo "$response" | jshon -e success -u 2>/dev/null | grep -q "true"; then
            echo "$response" | jshon -e data 2>/dev/null || echo "$response"
        else
            echo "$response"
        fi
    else
        # No JSON parser - raw output
        echo "$response"
    fi
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

# Build FTP request payload with path and options
build_ftp_payload() {
    local path="$1"
    local options="$2"
    
    if [ -n "$options" ]; then
        jq -n --arg path "$path" --argjson options "$options" \
           '{"path": $path, "ftp_options": $options}'
    else
        jq -n --arg path "$path" '{"path": $path}'
    fi
}

# Process FTP response and extract specific field
process_ftp_response() {
    local response="$1"
    local extract_field="$2"  # "content", "data", etc. (optional)
    
    if [ "$JSON_PARSER" = "jq" ]; then
        if [ -n "$extract_field" ]; then
            echo "$response" | jq ".$extract_field" 2>/dev/null
        else
            echo "$response"
        fi
    else
        print_error "jq required for FTP operations"
        exit 1
    fi
}

# Make FTP request with standard error handling
make_ftp_request() {
    local endpoint="$1"    # list, stat, retrieve, delete
    local payload="$2"
    
    local response
    response=$(make_request_json "POST" "/ftp/$endpoint" "$payload")
    
    # Check for FTP-specific error handling if needed
    echo "$response"
}

# Format ls-style output from FTP list entries
format_ls_output() {
    local entries="$1"
    local long_format="${2:-false}"
    
    echo "$entries" | jq -r '.[] | .name'
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