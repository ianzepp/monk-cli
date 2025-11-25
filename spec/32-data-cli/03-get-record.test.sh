#!/usr/bin/env bash
#
# Data CLI Test: Get Record
# Tests retrieving individual records via CLI

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "data-get"

# Create a model and record for testing
MODEL_NAME=$(unique_name "book")

print_step "Creating test model: $MODEL_NAME"
echo '{"fields": [{"name": "title", "type": "text"}, {"name": "author", "type": "text"}, {"name": "year", "type": "integer"}]}' | \
    monk_exec describe create "$MODEL_NAME" >/dev/null 2>&1

print_step "Creating test record"
output=$(echo '{"title": "The Great Test", "author": "Test Author", "year": 2024}' | \
    monk_exec --format json data create "$MODEL_NAME" 2>&1)

RECORD_ID=$(json_get "$output" ".data.id // .data[0].id")
print_info "Created record ID: $RECORD_ID"

# Test 1: Get record by ID
print_step "Testing 'monk data get MODEL ID'"

output=$(monk_exec --format json data get "$MODEL_NAME" "$RECORD_ID" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Get record command"
assert_json "$output" "Output is valid JSON"
assert_api_success "$output" "API success"
assert_contains "$output" "The Great Test" "Response contains title"
assert_contains "$output" "Test Author" "Response contains author"

# Test 2: Get record with select fields
print_step "Testing get with --select"

output=$(monk_exec --select title,year --format json data get "$MODEL_NAME" "$RECORD_ID" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Get with select"

# Test 3: Get non-existent record (should fail)
print_step "Testing get non-existent record (should fail)"

output=$(monk_exec data get "$MODEL_NAME" "00000000-0000-0000-0000-000000000000" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "Get non-existent record rejected"

# Test 4: Get from non-existent model (should fail)
print_step "Testing get from non-existent model (should fail)"

output=$(monk_exec data get "nonexistent_model_xyz" "$RECORD_ID" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "Get from non-existent model rejected"

# Test 5: Get with unwrap option
print_step "Testing get with --unwrap"

output=$(monk_exec --unwrap --format json data get "$MODEL_NAME" "$RECORD_ID" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Get with unwrap"
# Unwrapped response should have id directly at root
assert_contains "$output" '"id"' "Unwrapped has id field"

print_success "Data get tests complete"
