#!/usr/bin/env bash
#
# Connection Test: Basic Server Ping
# Tests that the CLI can successfully connect to and ping the configured server

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "connection-ping"

# Test 1: Basic server ping
print_step "Testing 'monk config server ping' command"

output=$(monk_exec config server ping 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Server ping command"

# Test 2: Server list to verify connection
print_step "Testing 'monk config server list' command"

output=$(monk_exec config server list 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Server list command"

# Check if we get a meaningful response
if [[ -n "$output" ]]; then
    print_success "Server list returned data"
else
    print_warning "Server list succeeded but returned empty response"
fi

# Test 3: Server health check
print_step "Testing 'monk config server health' command"

output=$(monk_exec config server health 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Server health command"

print_success "Connection tests completed"