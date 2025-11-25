#!/usr/bin/env bash
#
# Describe CLI Test: Update Model
# Tests updating schema/model definitions

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "describe-update"

# Create a model for testing
MODEL_NAME=$(unique_name "item")

print_step "Creating test model: $MODEL_NAME"
echo '{"fields": [{"name": "name", "type": "text"}]}' | \
    monk_exec describe create "$MODEL_NAME" >/dev/null 2>&1

# Test 1: Update model by adding a field
print_step "Testing 'monk describe update MODEL' to add field"

output=$(echo '{"fields": [{"name": "name", "type": "text"}, {"name": "description", "type": "text"}]}' | \
    monk_exec describe update "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Update model command"

# Test 2: Verify field was added
print_step "Verifying field was added"

output=$(monk_exec --format json describe get "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_contains "$output" "description" "Model now has 'description' field"

# Test 3: Add a new field via column syntax
print_step "Testing 'monk describe create MODEL FIELD' to add field"

output=$(echo '{"type": "integer"}' | \
    monk_exec describe create "$MODEL_NAME" count 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Add field via create command"

# Test 4: Verify new field exists
print_step "Verifying new field exists"

output=$(monk_exec --format json describe get "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_contains "$output" "count" "Model now has 'count' field"

# Test 5: Update non-existent model (should fail)
print_step "Testing update non-existent model (should fail)"

output=$(echo '{"fields": []}' | \
    monk_exec describe update "nonexistent_model_xyz" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "Update non-existent model rejected"

print_success "Describe update tests complete"
