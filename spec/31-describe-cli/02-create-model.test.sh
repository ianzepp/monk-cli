#!/usr/bin/env bash
#
# Describe CLI Test: Create Model
# Tests creating new schemas/models

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "describe-create"

# Generate unique model name
MODEL_NAME=$(unique_name "product")

# Test 1: Create model via stdin JSON
print_step "Testing 'monk describe create' with JSON input"

output=$(echo '{"fields": [{"name": "title", "type": "text"}, {"name": "price", "type": "number"}]}' | \
    monk_exec describe create "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Create model command"

# Test 2: Verify model was created
print_step "Verifying model exists in list"

output=$(monk_exec describe list 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_contains "$output" "$MODEL_NAME" "Model appears in list"

# Test 3: Get model definition
print_step "Testing 'monk describe get' for created model"

output=$(monk_exec --format json describe get "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Get model definition"
assert_json "$output" "Output is valid JSON"
assert_contains "$output" "title" "Model has 'title' field"
assert_contains "$output" "price" "Model has 'price' field"

# Test 4: Create model without fields (minimal)
print_step "Testing create with empty fields"

MODEL_NAME2=$(unique_name "empty")

output=$(echo '{"fields": []}' | \
    monk_exec describe create "$MODEL_NAME2" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Create model with empty fields"

# Test 5: Duplicate model creation should fail
print_step "Testing duplicate model creation (should fail)"

output=$(echo '{"fields": []}' | \
    monk_exec describe create "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "Duplicate model rejected"

print_success "Describe create tests complete"
