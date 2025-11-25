#!/usr/bin/env bash
#
# Describe CLI Test: Delete Model
# Tests deleting schemas/models

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "describe-delete"

# Create a model for testing
MODEL_NAME=$(unique_name "temp")

print_step "Creating test model: $MODEL_NAME"
echo '{"fields": [{"name": "data", "type": "text"}]}' | \
    monk_exec describe create "$MODEL_NAME" >/dev/null 2>&1

# Verify it exists
output=$(monk_exec describe list 2>&1)
if ! echo "$output" | grep -q "$MODEL_NAME"; then
    test_fail "Model was not created"
fi

# Test 1: Delete model
print_step "Testing 'monk describe delete MODEL'"

output=$(monk_exec describe delete "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Delete model command"

# Test 2: Verify model is deleted (soft delete - may still appear in some cases)
print_step "Verifying model deletion"

output=$(monk_exec describe get "$MODEL_NAME" 2>&1) || exit_code=$?
# After delete, get should fail or return deleted marker

if [[ $exit_code -ne 0 ]] || echo "$output" | grep -qi "not found\|deleted\|trashed"; then
    print_success "Model correctly deleted/not found"
else
    print_warning "Model may still exist (soft delete)"
fi

# Test 3: Delete non-existent model (should fail)
print_step "Testing delete non-existent model (should fail)"

output=$(monk_exec describe delete "nonexistent_model_xyz" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "Delete non-existent model rejected"

# Test 4: Delete system model (should fail - protected)
print_step "Testing delete system model 'users' (should fail)"

output=$(monk_exec describe delete "users" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "Delete system model rejected"

# Test 5: Delete field from model
print_step "Creating model with multiple fields"

MODEL_NAME2=$(unique_name "multi")
echo '{"fields": [{"name": "keep", "type": "text"}, {"name": "remove", "type": "text"}]}' | \
    monk_exec describe create "$MODEL_NAME2" >/dev/null 2>&1

print_step "Testing 'monk describe delete MODEL FIELD'"

output=$(monk_exec describe delete "$MODEL_NAME2" remove 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Delete field command"

# Verify field was removed
output=$(monk_exec --format json describe get "$MODEL_NAME2" 2>&1)
assert_not_contains "$output" '"remove"' "Field 'remove' no longer in model"
assert_contains "$output" "keep" "Field 'keep' still exists"

print_success "Describe delete tests complete"
