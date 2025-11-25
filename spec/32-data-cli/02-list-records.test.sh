#!/usr/bin/env bash
#
# Data CLI Test: List Records
# Tests listing records via CLI

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "data-list"

# Create a model and populate with test data
MODEL_NAME=$(unique_name "note")

print_step "Creating test model: $MODEL_NAME"
echo '{"fields": [{"name": "content", "type": "text"}, {"name": "author", "type": "text"}]}' | \
    monk_exec describe create "$MODEL_NAME" >/dev/null 2>&1

print_step "Populating test data"
echo '[
    {"content": "First note", "author": "alice"},
    {"content": "Second note", "author": "bob"},
    {"content": "Third note", "author": "alice"}
]' | monk_exec data create "$MODEL_NAME" >/dev/null 2>&1

# Test 1: List all records
print_step "Testing 'monk data list MODEL'"

output=$(monk_exec --format json data list "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "List records command"
assert_json "$output" "Output is valid JSON"
assert_api_success "$output" "API success"
assert_data_array "$output" "Response has data array"

# Check we got 3 records
length=$(json_get "$output" ".data | length")
if [[ "$length" == "3" ]]; then
    print_success "List returned expected 3 records"
else
    print_error "Expected 3 records, got $length"
fi

# Test 2: List with limit
print_step "Testing list with --limit"

output=$(monk_exec --format json data list "$MODEL_NAME" --limit 2 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "List with limit"
assert_data_length "$output" 2 "Limit applied"

# Test 3: List from non-existent model (should fail)
print_step "Testing list non-existent model (should fail)"

output=$(monk_exec data list "nonexistent_model_xyz" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "List non-existent model rejected"

# Test 4: List system model (users)
print_step "Testing list system model 'users'"

output=$(monk_exec --format json data list users 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "List system model"
assert_json "$output" "Output is valid JSON"

# Test 5: List with different format
print_step "Testing list with YAML format"

output=$(monk_exec --format yaml data list "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "List with YAML format"

print_success "Data list tests complete"
