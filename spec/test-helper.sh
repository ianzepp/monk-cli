#!/usr/bin/env bash
#
# CLI Test Helper Library
# Provides test utilities and assertions for monk-cli testing
#
# Architecture:
#   - test-all.sh registers ONE tenant for the entire run using a fixed session alias
#   - test-all.sh exports TEST_TENANT, TEST_SESSION_ALIAS
#   - Individual test files source this helper and use the shared session
#   - Uses the user's normal config directory (no temp dirs)
#
# Usage in test files:
#   source "$(dirname "$0")/../test-helper.sh"
#   use_shared_tenant "test-name"
#   # ... run tests ...

# NOTE: Don't use set -e here - individual tests handle errors
set -uo pipefail

# ===========================
# Configuration
# ===========================

# Resolve paths - handle both direct execution and sourcing
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SPEC_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
PROJECT_DIR="$(cd "$SPEC_DIR/.." && pwd)"
MONK_BIN="${PROJECT_DIR}/bin/monk"

# API configuration
API_BASE="${API_BASE:-http://localhost:9001}"

# Fixed session alias for all test runs
TEST_SESSION_ALIAS="cli-tests"

# Test state (may be inherited from test-all.sh)
TEST_TENANT="${TEST_TENANT:-}"
TEST_TOKEN="${TEST_TOKEN:-}"

# Per-file tracking
TEST_FAILED=0
TEST_PASSED=0
TEST_NAME="${TEST_NAME:-}"

# Track if we're the main test runner or a sourced helper
IS_TEST_RUNNER="${IS_TEST_RUNNER:-false}"

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ===========================
# Output Functions
# ===========================

print_header() {
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TEST_PASSED++)) || true
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((TEST_FAILED++)) || true
}

print_info() {
    echo -e "  ℹ $1"
}

print_debug() {
    if [[ "${CLI_VERBOSE:-}" == "true" ]]; then
        echo -e "  ${YELLOW}DEBUG: $1${NC}"
    fi
}

# ===========================
# Test Environment Setup
# ===========================

# Register the shared test tenant using the fixed session alias (called by test-all.sh)
register_shared_tenant() {
    local timestamp=$(date +%s)
    local random=$(head -c 4 /dev/urandom | xxd -p)

    TEST_TENANT="test_cli_${timestamp}_${random}"
    export TEST_TENANT

    print_step "Registering shared test tenant: $TEST_TENANT"
    print_info "Session alias: $TEST_SESSION_ALIAS"
    print_info "Server: $API_BASE"

    # Use the new session-based registration with --server and --alias flags
    local output
    local exit_code=0
    output=$("$MONK_BIN" auth register "$TEST_TENANT" --server "$API_BASE" --alias "$TEST_SESSION_ALIAS" 2>&1) || exit_code=$?

    print_debug "Registration output: $output"

    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}ERROR: Failed to register tenant${NC}"
        print_info "Output: $output"
        return 1
    fi

    # Verify session was created
    if ! "$MONK_BIN" auth status >/dev/null 2>&1; then
        echo -e "${RED}ERROR: Session not active after registration${NC}"
        return 1
    fi

    print_success "Shared tenant registered: $TEST_TENANT (session: $TEST_SESSION_ALIAS)"
    return 0
}

# Switch to the test session (called by test-all.sh and individual tests)
use_test_session() {
    if ! "$MONK_BIN" use "$TEST_SESSION_ALIAS" >/dev/null 2>&1; then
        echo -e "${RED}ERROR: Failed to switch to test session: $TEST_SESSION_ALIAS${NC}"
        return 1
    fi
    print_debug "Switched to test session: $TEST_SESSION_ALIAS"
    return 0
}

# Re-authenticate with the shared tenant (restore session after logout tests)
restore_shared_auth() {
    use_test_session
    print_debug "Restored test session: $TEST_SESSION_ALIAS"
}

# ===========================
# Test File Setup
# ===========================

# Use the shared tenant (called by individual test files)
# Usage: use_shared_tenant "describe-list"
use_shared_tenant() {
    local test_name="$1"
    TEST_NAME="$test_name"

    print_header "Test: $test_name"

    # Verify we have a shared tenant
    if [[ -z "${TEST_TENANT:-}" ]]; then
        echo -e "${RED}ERROR: No shared tenant. Run via test-all.sh${NC}"
        exit 1
    fi

    # Ensure we're using the test session
    use_test_session || exit 1

    print_info "Using tenant: $TEST_TENANT (session: $TEST_SESSION_ALIAS)"
    echo
}

# Setup for tests that need their own tenant (e.g., auth register tests)
# Usage: setup_isolated_tenant "auth-register"
setup_isolated_tenant() {
    local test_name="$1"
    TEST_NAME="$test_name"

    print_header "Test: $test_name (isolated)"

    # Wait for server
    wait_for_server_quiet

    print_info "Test will manage its own tenant(s)"
    echo
}

# ===========================
# Server Checks
# ===========================

# Wait for API server (verbose)
wait_for_server() {
    local max_attempts=30
    local attempt=1

    print_step "Waiting for API server at $API_BASE"

    while [[ $attempt -le $max_attempts ]]; do
        if curl -s "$API_BASE/health" >/dev/null 2>&1; then
            print_success "API server is responsive"
            return 0
        fi

        if [[ $attempt -eq $max_attempts ]]; then
            echo -e "${RED}ERROR: API server not responsive after $max_attempts attempts${NC}"
            echo "Start the API server: cd monk-api && npm start"
            return 1
        fi

        sleep 1
        ((attempt++))
    done
}

# Wait for API server (quiet - for individual tests)
wait_for_server_quiet() {
    local max_attempts=10
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if curl -s "$API_BASE/health" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        ((attempt++))
    done

    echo -e "${RED}ERROR: API server not responsive${NC}"
    return 1
}

# ===========================
# Test Summary
# ===========================

print_test_summary() {
    echo
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    echo "Test: ${TEST_NAME:-unknown}"
    echo "  Passed: $TEST_PASSED"
    echo "  Failed: $TEST_FAILED"

    if [[ $TEST_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
    else
        echo -e "${RED}Some tests failed!${NC}"
    fi
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
}

# Exit handler for test files
cleanup_test_file() {
    local exit_code=$?

    # Print summary for individual test files (not the runner itself)
    if [[ "$IS_TEST_RUNNER" != "true" ]]; then
        print_test_summary
    fi

    # Exit with failure if any assertions failed
    if [[ $TEST_FAILED -gt 0 ]]; then
        exit 1
    fi

    exit $exit_code
}

# Set up exit trap for all test files (including when run from test-all.sh)
trap cleanup_test_file EXIT

# ===========================
# CLI Execution Functions
# ===========================

# Run monk command and capture output
monk_run() {
    "$MONK_BIN" "$@" 2>&1
}

# Run monk command, capture output and exit code
monk_exec() {
    local output
    local exit_code=0

    output=$("$MONK_BIN" "$@" 2>&1) || exit_code=$?

    echo "$output"
    return $exit_code
}

# ===========================
# Assertion Functions
# ===========================

assert_success() {
    local exit_code="$1"
    local output="$2"
    local description="$3"

    if [[ $exit_code -eq 0 ]]; then
        print_success "$description"
        return 0
    else
        print_error "$description - exit code $exit_code"
        print_info "Output: $output"
        return 1
    fi
}

assert_failure() {
    local exit_code="$1"
    local output="$2"
    local description="$3"

    if [[ $exit_code -ne 0 ]]; then
        print_success "$description (expected failure)"
        return 0
    else
        print_error "$description - expected failure but got success"
        print_info "Output: $output"
        return 1
    fi
}

assert_contains() {
    local output="$1"
    local expected="$2"
    local description="$3"

    if echo "$output" | grep -q "$expected"; then
        print_success "$description - contains '$expected'"
        return 0
    else
        print_error "$description - expected '$expected'"
        print_info "Got: $output"
        return 1
    fi
}

assert_not_contains() {
    local output="$1"
    local unexpected="$2"
    local description="$3"

    if ! echo "$output" | grep -q "$unexpected"; then
        print_success "$description - does not contain '$unexpected'"
        return 0
    else
        print_error "$description - should not contain '$unexpected'"
        print_info "Got: $output"
        return 1
    fi
}

assert_json() {
    local output="$1"
    local description="$2"

    if echo "$output" | jq . >/dev/null 2>&1; then
        print_success "$description - valid JSON"
        return 0
    else
        print_error "$description - invalid JSON"
        print_info "Got: $output"
        return 1
    fi
}

assert_api_success() {
    local output="$1"
    local description="$2"

    local success
    success=$(echo "$output" | jq -r '.success // false' 2>/dev/null || echo "false")

    if [[ "$success" == "true" ]]; then
        print_success "$description - API success"
        return 0
    else
        print_error "$description - API returned success=$success"
        print_info "Got: $output"
        return 1
    fi
}

assert_has_data() {
    local output="$1"
    local description="$2"

    local has_data
    has_data=$(echo "$output" | jq 'has("data")' 2>/dev/null || echo "false")

    if [[ "$has_data" == "true" ]]; then
        print_success "$description - has data field"
        return 0
    else
        print_error "$description - missing data field"
        print_info "Got: $output"
        return 1
    fi
}

assert_data_array() {
    local output="$1"
    local description="$2"

    local is_array
    is_array=$(echo "$output" | jq '.data | type == "array"' 2>/dev/null || echo "false")

    if [[ "$is_array" == "true" ]]; then
        print_success "$description - data is array"
        return 0
    else
        print_error "$description - data is not an array"
        print_info "Got: $output"
        return 1
    fi
}

assert_data_length() {
    local output="$1"
    local expected="$2"
    local description="$3"

    local length
    length=$(echo "$output" | jq '.data | length' 2>/dev/null || echo "0")

    if [[ "$length" == "$expected" ]]; then
        print_success "$description - data length is $expected"
        return 0
    else
        print_error "$description - expected length $expected, got $length"
        return 1
    fi
}

# ===========================
# Utility Functions
# ===========================

json_get() {
    local output="$1"
    local path="$2"
    echo "$output" | jq -r "$path" 2>/dev/null || echo ""
}

unique_name() {
    local prefix="${1:-test}"
    local random=$(head -c 4 /dev/urandom | xxd -p)
    echo "${prefix}_${random}"
}

skip_test() {
    local reason="$1"
    print_warning "SKIPPED: $reason"
    return 0
}

# ===========================
# Legacy Compatibility
# ===========================

# For backward compatibility with old test pattern
setup_test_suite() {
    local test_name="$1"

    # If we have a shared tenant, use it
    if [[ -n "${TEST_TENANT:-}" ]]; then
        use_shared_tenant "$test_name"
        return
    fi

    # Otherwise fall back to creating isolated tenant (standalone run)
    TEST_NAME="$test_name"
    print_header "Test Suite: $test_name (standalone)"

    if [[ ! -x "$MONK_BIN" ]]; then
        echo -e "${RED}ERROR: monk binary not found at $MONK_BIN${NC}"
        exit 1
    fi

    wait_for_server || exit 1

    register_shared_tenant || exit 1

    print_success "Test suite ready: tenant=$TEST_TENANT"
    echo
}

setup_test_basic() {
    print_step "Setting up basic test environment"
    wait_for_server_quiet || return 1
    print_success "Basic test environment ready"
}

setup_auth() {
    print_step "Checking authentication"
    if "$MONK_BIN" auth status >/dev/null 2>&1; then
        print_success "Already authenticated"
        return 0
    fi
    print_warning "Not authenticated - some tests may fail"
}

assert_cli_success() {
    assert_success "$1" "$2" "$3"
}

test_fail() {
    print_error "$1"
    exit 1
}
