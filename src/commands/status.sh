#!/bin/bash

# status_command.sh - Show connection status with optional health checks
#
# Usage:
#   monk status              # Quick status overview
#   monk status --ping       # Essential health checks (fast)
#   monk status --ping --full # Comprehensive health checks (all endpoints)

# Check dependencies
check_dependencies

# Determine output format from global flags
output_format=$(get_output_format "text")

init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for status command"
    exit 1
fi

# Get flags
run_ping="${args[--ping]:-0}"
full_mode="${args[--full]:-0}"

# Validate flag usage
if [ "$full_mode" = "1" ] && [ "$run_ping" != "1" ]; then
    print_error "The --full flag requires --ping"
    print_info "Usage: monk status --ping --full"
    exit 1
fi

# Initialize results array
declare -a results=()
all_passed=true

# Color codes for status display
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
    STATUS_PASS=$'\033[0;32m✓\033[0m'
    STATUS_FAIL=$'\033[0;31m✗\033[0m'
    STATUS_SKIP=$'\033[1;33m⊘\033[0m'
else
    STATUS_PASS='✓'
    STATUS_FAIL='✗'
    STATUS_SKIP='⊘'
fi

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

# Helper function to print test result
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

        # For API endpoints, show: <icon> <route> <http_code>
        # For other tests, show: <test_name> <icon> <message>
        if [[ "$test_name" =~ ^API:\ / ]]; then
            # Extract route from "API: /route"
            local route="${test_name#API: }"
            printf "%s %-60s %s\n" "$status_icon" "$route" "$message" >&2
        else
            printf "%-40s %s %s\n" "$test_name" "$status_icon" "$message" >&2
        fi
    fi
}

# Start status output
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    if [ "$run_ping" = "1" ]; then
        if [ "$full_mode" = "1" ]; then
            echo "Connection Status & Comprehensive Health Checks" >&2
        else
            echo "Connection Status & Essential Health Checks" >&2
        fi
    else
        echo "Connection Status" >&2
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
fi

# Step 1: Check connection configuration
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

    # Early exit if no server
    if [[ "$output_format" == "text" ]]; then
        echo "" >&2
        print_error "No server configured. Use 'monk config server set' to add a server." >&2
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
    all_passed=false
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

# If not running ping checks, stop here
if [ "$run_ping" != "1" ]; then
    if [[ "$output_format" == "text" ]]; then
        echo "" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

        if [ "$all_passed" = "true" ]; then
            print_success "Connection configured" >&2
        else
            print_error "Connection has issues" >&2
        fi

        print_info "Use 'monk status --ping' for full health checks" >&2
        echo "" >&2
    else
        # JSON output
        final_result=$(jq -n \
            --argjson results "$(printf '%s\n' "${results[@]}" | jq -s '.')" \
            --arg success "$all_passed" \
            '{success: ($success == "true"), results: $results}')
        echo "$final_result"
    fi

    exit 0
fi

# Continue with ping checks...

# Step 2: Server connectivity
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    print_info "Step 2: Testing server connectivity (GET /)..." >&2
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

        # Early exit
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

# Step 3: Health endpoint
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    print_info "Step 3: Testing health endpoint (GET /health)..." >&2
fi

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

# Step 4: Authentication
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    print_info "Step 4: Testing authentication (GET /api/user/whoami)..." >&2
fi

jwt_token=$(get_jwt_token 2>/dev/null)
if [ -z "$jwt_token" ]; then
    add_result "Auth: JWT token available" "fail" "No JWT token found"
    print_test_result "Auth: JWT token available" "fail" "No token"
    all_passed=false

    add_result "Auth: GET /api/user/whoami" "skip" "No JWT token"
    print_test_result "Auth: GET /api/user/whoami" "skip" "No token"
else
    add_result "Auth: JWT token available" "pass" "Token found for $current_server:$current_tenant"
    print_test_result "Auth: JWT token available" "pass" "Token found"

    # Test whoami endpoint
    response=$(curl -s --max-time 5 -H "Authorization: Bearer $jwt_token" "$base_url/api/user/whoami" 2>/dev/null)
    http_code=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $jwt_token" "$base_url/api/user/whoami" 2>/dev/null)

    if [ "$http_code" = "200" ]; then
        user_name=$(echo "$response" | jq -r '.data.name // "unknown"' 2>/dev/null)
        add_result "Auth: GET /api/user/whoami" "pass" "Authenticated as: $user_name"
        print_test_result "Auth: GET /api/user/whoami" "pass" "Authenticated: $user_name"
    else
        add_result "Auth: GET /api/user/whoami" "fail" "Authentication failed (HTTP $http_code)"
        print_test_result "Auth: GET /api/user/whoami" "fail" "HTTP $http_code"
        all_passed=false
    fi
fi

# Stop here if NOT in full mode (default ping behavior)
if [ "$full_mode" != "1" ]; then
    if [[ "$output_format" == "text" ]]; then
        echo "" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

        if [ "$all_passed" = "true" ]; then
            print_success "Essential health checks passed" >&2
        else
            print_error "Some health checks failed" >&2
        fi

        print_info "Use 'monk status --ping --full' for comprehensive diagnostics" >&2
        echo "" >&2
    else
        final_result=$(jq -n \
            --argjson results "$(printf '%s\n' "${results[@]}" | jq -s '.')" \
            --arg success "$all_passed" \
            '{success: ($success == "true"), results: $results}')
        echo "$final_result"
    fi

    if [ "$all_passed" = "true" ]; then
        exit 0
    else
        exit 1
    fi
fi

# Step 5: API endpoints (full mode only)
if [[ "$output_format" == "text" ]]; then
    echo "" >&2
    print_info "Step 5: Testing API endpoints..." >&2
fi

if [ -z "$jwt_token" ]; then
    # Skip all API endpoint tests if not authenticated
    if [ -n "$available_endpoints" ] && [ "$available_endpoints" != "{}" ]; then
        for api_category in $(echo "$available_endpoints" | jq -r 'keys[]' 2>/dev/null); do
            if [ "$api_category" != "home" ] && [ "$api_category" != "docs" ]; then
                add_result "API: ${api_category^} API" "skip" "Not authenticated"
                print_test_result "API: ${api_category^} API" "skip" "Not authenticated"
            fi
        done
    fi
else
    if [ -z "$available_endpoints" ] || [ "$available_endpoints" = "{}" ]; then
        add_result "API: Endpoints" "skip" "No endpoints discovered from root API"
        print_test_result "API: Endpoints" "skip" "No endpoints discovered"
    else
        # Test ALL endpoints in each API category for true full mode
        for api_category in $(echo "$available_endpoints" | jq -r 'keys[]' 2>/dev/null | sort); do
            if [ "$api_category" = "home" ] || [ "$api_category" = "docs" ]; then
                continue
            fi

            # Get count of endpoints in this category
            endpoint_count=$(echo "$available_endpoints" | jq -r ".$api_category | length" 2>/dev/null)

            if [ -z "$endpoint_count" ] || [ "$endpoint_count" = "0" ] || [ "$endpoint_count" = "null" ]; then
                continue
            fi

            # Test each endpoint in the category
            for ((i=0; i<endpoint_count; i++)); do
                endpoint=$(echo "$available_endpoints" | jq -r ".$api_category[$i]" 2>/dev/null)

                if [ -z "$endpoint" ] || [ "$endpoint" = "null" ]; then
                    continue
                fi

                # Remove parameter placeholders for testing
                test_endpoint=$(echo "$endpoint" | sed 's|:[^/]*||g')

                # Determine HTTP method and whether JWT is needed based on endpoint pattern
                needs_jwt=true
                http_method="GET"
                payload=""

                # Public auth endpoints don't need JWT
                if [[ "$endpoint" =~ ^/auth/ ]]; then
                    needs_jwt=false
                fi

                # Determine method based on category and endpoint
                case "$api_category" in
                    "bulk"|"find"|"aggregate")
                        http_method="POST"
                        ;;
                esac

                # Make the request
                if [ "$needs_jwt" = "true" ]; then
                    if [ "$http_method" = "POST" ]; then
                        http_code=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' \
                            -H "Authorization: Bearer $jwt_token" \
                            -H "Content-Type: application/json" \
                            -X POST "$base_url$test_endpoint" 2>/dev/null)
                    else
                        http_code=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' \
                            -H "Authorization: Bearer $jwt_token" \
                            "$base_url$test_endpoint" 2>/dev/null)
                    fi
                else
                    # Public endpoint - no JWT needed
                    if [ "$http_method" = "POST" ]; then
                        http_code=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' \
                            -H "Content-Type: application/json" \
                            -X POST "$base_url$test_endpoint" 2>/dev/null)
                    else
                        http_code=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' \
                            "$base_url$test_endpoint" 2>/dev/null)
                    fi
                fi

                # Evaluate response
                if [ "$http_code" = "200" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
                    add_result "API: $endpoint" "pass" "Reachable (HTTP $http_code)"
                    print_test_result "API: $endpoint" "pass" "HTTP $http_code"
                elif [ "$api_category" = "sudo" ] && [ "$http_code" = "403" ]; then
                    add_result "API: $endpoint" "pass" "Reachable (requires sudo token)"
                    print_test_result "API: $endpoint" "pass" "HTTP 403"
                else
                    add_result "API: $endpoint" "fail" "HTTP $http_code"
                    print_test_result "API: $endpoint" "fail" "HTTP $http_code"
                    all_passed=false
                fi
            done
        done
    fi
fi

# Step 6: Documentation
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
    echo "$final_result"
fi

# Exit with appropriate code
if [ "$all_passed" = "true" ]; then
    exit 0
else
    exit 1
fi
