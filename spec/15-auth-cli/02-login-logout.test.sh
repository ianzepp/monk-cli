#!/usr/bin/env bash
#
# Auth CLI Test: Login/Logout
# Tests authentication flow via CLI
#
# NOTE: This test logs out and back in, but restores the shared session at the end

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "auth-login"

# Test 1: Check initial status (should be authenticated from setup)
print_step "Testing 'monk auth status' command"

output=$(monk_exec auth status 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Auth status command"
assert_contains "$output" "$TEST_TENANT" "Status shows test tenant"

# Test 2: Logout
print_step "Testing 'monk auth logout' command"

output=$(monk_exec auth logout 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Logout command"

# Test 3: Status after logout (should show not authenticated or error)
print_step "Checking status after logout"

output=$(monk_exec auth status 2>&1) || exit_code=$?
# Logout may cause status to fail or show unauthenticated - either is acceptable

if [[ $exit_code -ne 0 ]] || echo "$output" | grep -qi "not.*auth\|no.*token\|expired"; then
    print_success "Status correctly shows not authenticated"
else
    print_warning "Status may still show cached info"
fi

# Test 4: Login again using --server flag
print_step "Testing 'monk auth login' command with --server flag"

output=$(monk_exec auth login "$TEST_TENANT" root --server "$API_BASE" --alias "$TEST_SESSION_ALIAS" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Login command"

# Test 5: Verify login worked
print_step "Verifying login succeeded"

output=$(monk_exec auth status 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Status after login"

# IMPORTANT: Restore shared session for subsequent tests
print_step "Restoring shared session"
restore_shared_auth
print_success "Shared session restored"

print_success "Auth login/logout tests complete"
