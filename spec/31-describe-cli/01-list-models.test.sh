#!/usr/bin/env bash
#
# Describe CLI Test: List Models
# Tests listing available schemas/models

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "describe-list"

# Test 1: List models (basic)
print_step "Testing 'monk describe list' command"

output=$(monk_exec describe list 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "List models command"

# System models should exist
assert_contains "$output" "models" "List includes 'models' system table"
assert_contains "$output" "fields" "List includes 'fields' system table"
assert_contains "$output" "users" "List includes 'users' system table"

# Test 2: List with JSON format
print_step "Testing 'monk --format json describe list'"

output=$(monk_exec --format json describe list 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "List models (JSON format)"
assert_json "$output" "Output is valid JSON"
assert_api_success "$output" "API response"

print_success "Describe list tests complete"
