#!/usr/bin/env bash
# Note: Removed set -e to handle errors gracefully

# Connection Test: Basic Server Ping
# Tests that the CLI can successfully connect to and ping the configured server

# Source test helpers
source "$(dirname "$0")/../test-helper.sh"

print_step "Testing basic server connection via CLI ping"

# Setup basic test environment
setup_test_basic

# Test 1: Basic server ping
print_step "Testing 'monk config server ping' command"

# Execute the ping command and capture output
response=$(monk config server ping 2>&1)
exit_code=$?

# Check if the command executed successfully
assert_cli_success "$exit_code" "$response" "Server ping command"

# Check if response contains expected success indicators
assert_success_indicators "$response" "Server ping response"

# Test 2: Server list to verify connection
print_step "Testing 'monk config server list' command"

response=$(monk config server list 2>&1)
exit_code=$?

assert_cli_success "$exit_code" "$response" "Server list command"

# Check if we get a meaningful response
if [[ -n "$response" ]]; then
    print_success "Server list returned data"
else
    print_warning "Server list succeeded but returned empty response"
fi

# Test 3: Server health check
print_step "Testing 'monk config server health' command"

response=$(monk config server health 2>&1)
exit_code=$?

assert_cli_success "$exit_code" "$response" "Server health command"
assert_success_indicators "$response" "Server health check"

print_success "Connection tests completed successfully"
print_info "CLI can successfully communicate with the configured server"