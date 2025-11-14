#!/bin/bash

# ping_command.sh - Progressive health checks on current connection and API endpoints

# Check dependencies
check_dependencies

# Determine output format from global flags
output_format=$(get_output_format "text")

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for ping command"
    exit 1
fi

# Initialize results array
declare -a results=()
all_passed=true

# Color codes for status display
STATUS_PASS="${GREEN}✓${NC}"
STATUS_FAIL="${RED}✗${NC}"
STATUS_SKIP="${YELLOW}⊘${NC}"

# Helper function to add result
add_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    local details="${4:-}"

    results+=("$(jq -n \
        --arg test "$test_name" \
        --arg status "$status" \
        --arg message "$message" \
        --arg details "$details" \
        '{test: $test, status: $status, message: $message, details: $details}')")
}

# Helper function to print test result in text mode
print_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"

    if [[ "$output_format" == "text" ]]; then
        local status_icon
        if [[ "$status" == "pass" ]]; then
            status_icon="$STATUS_PASS"
        elif [[ "$status" == "skip" ]]; then
            status_icon="$STATUS_SKIP"
        else
            status_icon="$STATUS_FAIL"
        fi

        printf "%-40s %s %s\n" "$test_name" "$status_icon" "$message" >&2
    fi
}

# Start progressive health checks
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    echo "Progressive Health Checks" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
fi

# Test 1: Check if current connection is set
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    print_info "Step 1: Checking current connection configuration..." >&2
fi

current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)

if [ -z "$current_server" ] || [ "$current_server" = "null" ]; then
    add_result "Connection: Server configured" "fail" "No server configured"
    print_test_result "Connection: Server configured" "fail" "No server configured"
    all_passed=false

    # Early exit - can't proceed without server
    if [[ "$output_format" == "text" ]]; then
        echo "" >&2
        print_error "No server configured. Use 'monk config server add' to add a server." >&2
        echo "" >&2
    fi

    final_result=$(jq -n \
        --argjson results "$(printf '%s\n' "${results[@]}" | jq -s '.')" \
        --arg success "false" \
        '{success: ($success == "true"), results: $results}')

    if [[ "$output_format" == "json" ]]; then
        echo "$final_result"
    fi
    exit 1
else
    add_result "Connection: Server configured" "pass" "Server: $current_server"
    print_test_result "Connection: Server configured" "pass" "Server: $current_server"
fi

if [ -z "$current_tenant" ] || [ "$current_tenant" = "null" ]; then
    add_result "Connection: Tenant configured" "fail" "No tenant configured"
    print_test_result "Connection: Tenant configured" "fail" "No tenant configured"
else
    add_result "Connection: Tenant configured" "pass" "Tenant: $current_tenant"
    print_test_result "Connection: Tenant configured" "pass" "Tenant: $current_tenant"
fi

# Get base URL
base_url=$(get_base_url 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$base_url" ]; then
    add_result "Connection: Base URL resolved" "fail" "Could not resolve base URL"
    print_test_result "Connection: Base URL resolved" "fail" "Could not resolve base URL"
    all_passed=false
else
    add_result "Connection: Base URL resolved" "pass" "$base_url"
    print_test_result "Connection: Base URL resolved" "pass" "$base_url"
fi

# Test 2: Check if server is reachable at GET / and extract endpoints/documentation
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    print_info "Step 2: Testing server connectivity and discovering endpoints (GET /)..." >&2
fi

root_response=""
available_endpoints=""
available_documentation=""

if [ -z "$base_url" ]; then
    add_result "Server: GET /" "skip" "Skipped due to previous failure"
    print_test_result "Server: GET /" "skip" "Skipped"
    all_passed=false
else
    if root_response=$(curl -s --max-time 5 --fail "$base_url/" 2>/dev/null); then
        add_result "Server: GET /" "pass" "Server is reachable"
        print_test_result "Server: GET /" "pass" "Reachable"

        # Extract endpoints and documentation for later use
        available_endpoints=$(echo "$root_response" | jq -r '.data.endpoints // {}' 2>/dev/null)
        available_documentation=$(echo "$root_response" | jq -r '.data.documentation // {}' 2>/dev/null)
    else
        add_result "Server: GET /" "fail" "Server is not reachable"
        print_test_result "Server: GET /" "fail" "Not reachable"
        all_passed=false

        # Early exit - can't proceed without connectivity
        if [[ "$output_format" == "text" ]]; then
            echo "" >&2
            print_error "Server is not reachable at $base_url" >&2
            echo "" >&2
        fi

        final_result=$(jq -n \
            --argjson results "$(printf '%s\n' "${results[@]}" | jq -s '.')" \
            --arg success "false" \
            '{success: ($success == "true"), results: $results}')

        if [[ "$output_format" == "json" ]]; then
            echo "$final_result"
        fi
        exit 1
    fi
fi

# Test 3: Check GET /health endpoint (if advertised in endpoints)
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    print_info "Step 3: Testing health endpoint (GET /health)..." >&2
fi

# Check if /health is in the home endpoints
if echo "$available_endpoints" | jq -e '.home[] | select(. == "/health")' >/dev/null 2>&1; then
    http_code=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' "$base_url/health" 2>/dev/null)
    if [ "$http_code" = "200" ]; then
        add_result "Server: GET /health" "pass" "Health check passed"
        print_test_result "Server: GET /health" "pass" "Healthy"
    else
        add_result "Server: GET /health" "fail" "HTTP $http_code"
        print_test_result "Server: GET /health" "fail" "HTTP $http_code"
        all_passed=false
    fi
else
    add_result "Server: GET /health" "skip" "Health endpoint not advertised"
    print_test_result "Server: GET /health" "skip" "Not advertised"
fi

# Test 4: Check authentication via /api/auth/whoami
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    print_info "Step 4: Testing authentication (GET /api/auth/whoami)..." >&2
fi

jwt_token=$(get_jwt_token 2>/dev/null)
if [ -z "$jwt_token" ]; then
    add_result "Auth: JWT token available" "fail" "No JWT token found"
    print_test_result "Auth: JWT token available" "fail" "No token"
    all_passed=false

    # Skip authenticated endpoints
    add_result "Auth: GET /api/auth/whoami" "skip" "No JWT token"
    print_test_result "Auth: GET /api/auth/whoami" "skip" "No token"
else
    add_result "Auth: JWT token available" "pass" "Token found for $current_server:$current_tenant"
    print_test_result "Auth: JWT token available" "pass" "Token found"

    # Test whoami endpoint
    response=$(curl -s --max-time 5 -H "Authorization: Bearer $jwt_token" "$base_url/api/auth/whoami" 2>/dev/null)
    http_code=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $jwt_token" "$base_url/api/auth/whoami" 2>/dev/null)

    if [ "$http_code" = "200" ]; then
        user_name=$(echo "$response" | jq -r '.data.name // "unknown"' 2>/dev/null)
        add_result "Auth: GET /api/auth/whoami" "pass" "Authenticated as: $user_name"
        print_test_result "Auth: GET /api/auth/whoami" "pass" "Authenticated: $user_name"
    else
        add_result "Auth: GET /api/auth/whoami" "fail" "Authentication failed (HTTP $http_code)"
        print_test_result "Auth: GET /api/auth/whoami" "fail" "HTTP $http_code"
        all_passed=false
    fi
fi

# Test 5: Check API endpoints (only if authenticated and endpoints discovered)
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    print_info "Step 5: Testing API endpoints..." >&2
fi

if [ -z "$jwt_token" ]; then
    # Skip all API endpoint tests if not authenticated
    if [ -n "$available_endpoints" ] && [ "$available_endpoints" != "{}" ]; then
        # List the endpoints that would be tested
        for api_category in $(echo "$available_endpoints" | jq -r 'keys[]' 2>/dev/null); do
            # Skip home and docs categories
            if [ "$api_category" != "home" ] && [ "$api_category" != "docs" ]; then
                add_result "API: ${api_category^} API" "skip" "Not authenticated"
                print_test_result "API: ${api_category^} API" "skip" "Not authenticated"
            fi
        done
    fi
else
    # Test each API category discovered from root endpoint
    if [ -z "$available_endpoints" ] || [ "$available_endpoints" = "{}" ]; then
        add_result "API: Endpoints" "skip" "No endpoints discovered from root API"
        print_test_result "API: Endpoints" "skip" "No endpoints discovered"
    else
        # Iterate through each API category (skip home and docs)
        for api_category in $(echo "$available_endpoints" | jq -r 'keys[]' 2>/dev/null | sort); do
            # Skip home and docs categories
            if [ "$api_category" = "home" ] || [ "$api_category" = "docs" ]; then
                continue
            fi

            # Get the first endpoint for this category
            first_endpoint=$(echo "$available_endpoints" | jq -r ".$api_category[0]" 2>/dev/null)

            if [ -z "$first_endpoint" ] || [ "$first_endpoint" = "null" ]; then
                continue
            fi

            # Replace :param placeholders with test values for basic connectivity check
            test_endpoint=$(echo "$first_endpoint" | sed 's|:[^/]*||g')

            # Special handling for specific endpoints
            case "$api_category" in
                "file")
                    # File API needs POST with JSON payload
                    payload='{"path": "/"}'
                    http_code=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' \
                        -H "Authorization: Bearer $jwt_token" \
                        -H "Content-Type: application/json" \
                        -X POST -d "$payload" "$base_url$test_endpoint" 2>/dev/null)
                    ;;
                "bulk"|"find"|"aggregate")
                    # These are POST endpoints
                    http_code=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' \
                        -H "Authorization: Bearer $jwt_token" \
                        -H "Content-Type: application/json" \
                        -X POST "$base_url$test_endpoint" 2>/dev/null)
                    ;;
                *)
                    # Default GET request
                    http_code=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' \
                        -H "Authorization: Bearer $jwt_token" \
                        "$base_url$test_endpoint" 2>/dev/null)
                    ;;
            esac

            # Evaluate response
            # Accept 200, 400, 404 as "reachable"
            # Accept 403 for sudo API (requires sudo token)
            if [ "$http_code" = "200" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
                add_result "API: ${api_category^} API" "pass" "Reachable (HTTP $http_code)"
                print_test_result "API: ${api_category^} API" "pass" "Reachable"
            elif [ "$api_category" = "sudo" ] && [ "$http_code" = "403" ]; then
                # Sudo API requires sudo token, 403 means it's reachable but unauthorized
                add_result "API: ${api_category^} API" "pass" "Reachable (requires sudo token)"
                print_test_result "API: ${api_category^} API" "pass" "Reachable (403)"
            else
                add_result "API: ${api_category^} API" "fail" "HTTP $http_code"
                print_test_result "API: ${api_category^} API" "fail" "HTTP $http_code"
                all_passed=false
            fi
        done
    fi
fi

# Test 6: Check documentation availability
if [ -n "$available_documentation" ] && [ "$available_documentation" != "{}" ]; then
    doc_count=$(echo "$available_documentation" | jq -r 'keys | length' 2>/dev/null)
    add_result "Docs: Documentation" "pass" "Available ($doc_count areas)"
    print_test_result "Docs: Documentation" "pass" "Available ($doc_count areas)"
else
    add_result "Docs: Documentation" "skip" "No documentation advertised"
    print_test_result "Docs: Documentation" "skip" "Not advertised"
fi

# Build final result
final_result=$(jq -n \
    --argjson results "$(printf '%s\n' "${results[@]}" | jq -s '.')" \
    --arg success "$all_passed" \
    '{success: ($success == "true"), results: $results}')

# Output results
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

    if [ "$all_passed" = "true" ]; then
        print_success "All health checks passed" >&2
    else
        print_error "Some health checks failed" >&2
    fi
    echo "" >&2
else
    # JSON output
    echo "$final_result"
fi

# Exit with appropriate code
if [ "$all_passed" = "true" ]; then
    exit 0
else
    exit 1
fi
