#!/usr/bin/env bash
#
# Data CLI Test: Create Record
# Tests creating records via CLI

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "data-create"

# Create a model for testing
MODEL_NAME=$(unique_name "task")

print_step "Creating test model: $MODEL_NAME"
echo '{"fields": [{"name": "title", "type": "text"}, {"name": "priority", "type": "integer"}]}' | \
    monk_exec describe create "$MODEL_NAME" >/dev/null 2>&1

# Test 1: Create single record
print_step "Testing 'monk data create MODEL' with single record"

output=$(echo '{"title": "Test Task", "priority": 1}' | \
    monk_exec --format json data create "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Create record command"
assert_json "$output" "Output is valid JSON"
assert_api_success "$output" "API success"

# Extract record ID for later tests
RECORD_ID=$(json_get "$output" ".data.id // .data[0].id")
print_info "Created record ID: $RECORD_ID"

# Test 2: Create multiple records
print_step "Testing create with array of records"

output=$(echo '[{"title": "Task A", "priority": 2}, {"title": "Task B", "priority": 3}]' | \
    monk_exec --format json data create "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Create multiple records"
assert_json "$output" "Output is valid JSON"

# Test 3: Create with missing optional field
print_step "Testing create with partial data"

output=$(echo '{"title": "Minimal Task"}' | \
    monk_exec --format json data create "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Create with partial data"

# Test 4: Create with invalid model (should fail)
print_step "Testing create on non-existent model (should fail)"

output=$(echo '{"data": "test"}' | \
    monk_exec data create "nonexistent_model_xyz" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "Create on non-existent model rejected"

# Test 5: Verify records exist via list
print_step "Verifying records were created via list"

output=$(monk_exec --format json data list "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "List records"
assert_json "$output" "Output is valid JSON"
assert_data_array "$output" "Response has data array"

print_success "Data create tests complete"
