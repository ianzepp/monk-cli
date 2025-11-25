#!/usr/bin/env bash
#
# Auth CLI Test: Register
# Tests tenant registration via CLI
#
# NOTE: This test creates its own tenants to test registration functionality

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

# Use isolated mode since we're testing registration itself
setup_isolated_tenant "auth-register"

# Generate unique tenant names and session aliases
TENANT_NAME="test_reg_$(date +%s)_$(head -c 4 /dev/urandom | xxd -p)"
SESSION_ALIAS="test-reg-$(head -c 4 /dev/urandom | xxd -p)"

# Test 1: Register new tenant with --server and --alias flags
print_step "Testing 'monk auth register' command with --server and --alias flags"

output=$(monk_exec auth register "$TENANT_NAME" --server "$API_BASE" --alias "$SESSION_ALIAS" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Register tenant"
assert_contains "$output" "Session: $SESSION_ALIAS" "Shows session alias"

# Test 2: Verify we got a token stored
print_step "Checking authentication status after registration"

output=$(monk_exec auth status 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Auth status command"
assert_contains "$output" "$TENANT_NAME" "Status shows tenant"

# Test 3: Verify token info
print_step "Checking token info"

output=$(monk_exec auth info 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Auth info command"
assert_contains "$output" "tenant" "Token contains tenant"

# Test 4: Register with template
print_step "Testing registration with --template flag"

TENANT_NAME2="test_reg2_$(date +%s)_$(head -c 4 /dev/urandom | xxd -p)"
SESSION_ALIAS2="test-reg2-$(head -c 4 /dev/urandom | xxd -p)"

output=$(monk_exec auth register "$TENANT_NAME2" --server "$API_BASE" --alias "$SESSION_ALIAS2" --template system 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Register with template"

# Test 5: Duplicate registration should fail
print_step "Testing duplicate registration (should fail)"

output=$(monk_exec auth register "$TENANT_NAME" --server "$API_BASE" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "Duplicate registration rejected"

# Restore shared session for subsequent tests
print_step "Restoring shared session"
restore_shared_auth
print_success "Shared session restored"

print_success "Auth register tests complete"
