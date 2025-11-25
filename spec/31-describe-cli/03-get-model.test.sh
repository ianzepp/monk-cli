#!/usr/bin/env bash
#
# Describe CLI Test: Get Model
# Tests retrieving schema/model definitions

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "describe-get"

# Create a model for testing
MODEL_NAME=$(unique_name "widget")

print_step "Creating test model: $MODEL_NAME"
echo '{"fields": [{"name": "name", "type": "text"}, {"name": "quantity", "type": "integer"}]}' | \
    monk_exec describe create "$MODEL_NAME" >/dev/null 2>&1

# Test 1: Get model definition
print_step "Testing 'monk describe get MODEL'"

output=$(monk_exec describe get "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Get model command"
assert_contains "$output" "name" "Response contains field 'name'"
assert_contains "$output" "quantity" "Response contains field 'quantity'"

# Test 2: Get with JSON format
print_step "Testing 'monk --format json describe get MODEL'"

output=$(monk_exec --format json describe get "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Get model (JSON format)"
assert_json "$output" "Output is valid JSON"
assert_api_success "$output" "API response success"

# Test 3: Get specific field
print_step "Testing 'monk describe get MODEL FIELD'"

output=$(monk_exec describe get "$MODEL_NAME" name 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Get field command"
assert_contains "$output" "text" "Field type is text"

# Test 4: Get non-existent model
print_step "Testing get non-existent model (should fail)"

output=$(monk_exec describe get "nonexistent_model_xyz" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "Non-existent model returns error"

# Test 5: Get system model
print_step "Testing get system model 'users'"

output=$(monk_exec --format json describe get users 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Get system model"
assert_json "$output" "Output is valid JSON"

print_success "Describe get tests complete"
