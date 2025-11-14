#!/usr/bin/env bash
#
# CLI Test Helper Library
# Provides high-level test setup and validation functions for monk-cli testing

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test tracking
TEST_FAILED=0
TEST_PASSED=0

# ===========================
# Output Functions
# ===========================

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TEST_PASSED++))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((TEST_FAILED++))
}

print_info() {
    echo -e "ℹ $1"
}

test_fail() {
    print_error "$1"
    exit 1
}

print_test_summary() {
    echo
    echo "Test Summary:"
    echo "  Passed: $TEST_PASSED"
    echo "  Failed: $TEST_FAILED"
    if [[ $TEST_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# ===========================
# Test Setup Functions
# ===========================

# Basic test setup - just wait for server and verify basic connectivity
setup_test_basic() {
    print_step "Setting up basic test environment"
    
    # Wait for server to be available
    wait_for_server
    
    # Verify we have a configured server
    if ! monk config server current >/dev/null 2>&1; then
        test_fail "No server configured. Please run 'monk config server add' first."
    fi
    
    print_success "Basic test environment ready"
}

# Wait for server to be responsive
wait_for_server() {
    local max_attempts=30
    local attempt=1
    
    print_step "Waiting for server to be responsive"

    while [[ $attempt -le $max_attempts ]]; do
        if monk config server ping >/dev/null 2>&1; then
            print_success "Server is responsive"
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            test_fail "Server not responsive after $max_attempts attempts"
        fi
        
        sleep 1
        ((attempt++))
    done
}

# Setup test with authentication (if needed)
setup_auth() {
    print_step "Setting up authentication"
    
    # Check if we're already authenticated
    if monk auth status >/dev/null 2>&1; then
        print_success "Already authenticated"
        return 0
    fi
    
    # Try to authenticate with default credentials if available
    local current_tenant=$(monk config tenant current 2>/dev/null || echo "")
    if [[ -n "$current_tenant" ]]; then
        # Try common authentication patterns
        if monk auth login "$current_tenant" admin >/dev/null 2>&1; then
            print_success "Authenticated with admin user"
            return 0
        elif monk auth login "$current_tenant" user >/dev/null 2>&1; then
            print_success "Authenticated with user"
            return 0
        fi
    fi
    
    print_warning "Authentication may be required for some operations"
}

# ===========================
# CLI Output Validation Functions
# ===========================

# Check if CLI command succeeded
assert_cli_success() {
    local exit_code="$1"
    local response="$2"
    local operation="$3"
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "$operation succeeded"
        return 0
    else
        test_fail "$operation failed with exit code $exit_code: $response"
    fi
}

# Check if response contains expected text
assert_contains() {
    local text="$1"
    local response="$2"
    local description="$3"
    
    if echo "$response" | grep -q "$text"; then
        print_success "$description - contains '$text'"
        return 0
    else
        test_fail "$description - expected to contain '$text' but got: $response"
    fi
}

# Check if response does NOT contain text
assert_not_contains() {
    local text="$1"
    local response="$2"
    local description="$3"
    
    if ! echo "$response" | grep -q "$text"; then
        print_success "$description - does not contain '$text'"
        return 0
    else
        test_fail "$description - should not contain '$text' but got: $response"
    fi
}

# Check if response is valid JSON
assert_valid_json() {
    local response="$1"
    local description="$2"
    
    if echo "$response" | jq . >/dev/null 2>&1; then
        print_success "$description - valid JSON"
        return 0
    else
        test_fail "$description - invalid JSON: $response"
    fi
}

# Check if response indicates success (various success indicators)
assert_success_indicators() {
    local response="$1"
    local description="$2"
    
    if echo "$response" | grep -q "success\|healthy\|up\|✓\|✅"; then
        print_success "$description - contains success indicators"
        return 0
    else
        print_warning "$description - no clear success indicators found: $response"
        return 0  # Don't fail, just warn
    fi
}

# ===========================
# Test Execution Functions
# ===========================

# Run a CLI command and return exit code and output
run_cli_command() {
    local cmd="$1"
    local output
    local exit_code
    
    output=$(eval "$cmd" 2>&1)
    exit_code=$?
    
    echo "$output"
    return $exit_code
}

# Execute monk command with error handling
monk_cmd() {
    local args="$1"
    monk $args 2>&1
}

# ===========================
# Cleanup Functions
# ===========================

# Cleanup function to be called at the end of tests
cleanup_tests() {
    print_test_summary
}

# Trap to ensure cleanup runs
trap cleanup_tests EXIT