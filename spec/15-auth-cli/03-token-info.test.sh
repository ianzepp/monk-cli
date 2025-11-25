#!/usr/bin/env bash
#
# Auth CLI Test: Token Operations
# Tests token display, info, and expiration commands

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "auth-token"

# Test 1: Display token
print_step "Testing 'monk auth token' command"

output=$(monk_exec auth token 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Token display command"

# JWT tokens start with 'eyJ'
if echo "$output" | grep -q "eyJ"; then
    print_success "Token looks like valid JWT"
else
    print_warning "Token format may be different"
fi

# Test 2: Token info (decoded)
print_step "Testing 'monk auth info' command"

output=$(monk_exec auth info 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Token info command"
assert_contains "$output" "tenant" "Token info shows tenant"

# Test 3: Token expiration
print_step "Testing 'monk auth expires' command"

output=$(monk_exec auth expires 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Token expires command"

# Test 4: Token expired check
print_step "Testing 'monk auth expired' command"

output=$(monk_exec auth expired 2>&1) || exit_code=$?
# exit_code 0 = valid, 1 = expired

if [[ $exit_code -eq 0 ]]; then
    print_success "Token is valid (not expired)"
elif [[ $exit_code -eq 1 ]]; then
    print_warning "Token is expired (may need refresh)"
else
    print_error "Unexpected exit code: $exit_code"
fi

# Test 5: Ping (authenticated health check)
print_step "Testing 'monk auth ping' command"

output=$(monk_exec auth ping 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Authenticated ping"

print_success "Auth token tests complete"
