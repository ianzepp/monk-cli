#!/usr/bin/env bash
#
# Data CLI Test: Update Record
# Tests updating records via CLI

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "data-update"

# Create a model and record for testing
MODEL_NAME=$(unique_name "article")

print_step "Creating test model: $MODEL_NAME"
echo '{"fields": [{"name": "title", "type": "text"}, {"name": "status", "type": "text"}]}' | \
    monk_exec describe create "$MODEL_NAME" >/dev/null 2>&1

print_step "Creating test record"
output=$(echo '{"title": "Original Title", "status": "draft"}' | \
    monk_exec --format json data create "$MODEL_NAME" 2>&1)

RECORD_ID=$(json_get "$output" ".data.id // .data[0].id")
print_info "Created record ID: $RECORD_ID"

# Test 1: Update single record by ID
print_step "Testing 'monk data update MODEL ID' with stdin"

output=$(echo '{"title": "Updated Title", "status": "published"}' | \
    monk_exec --format json data update "$MODEL_NAME" "$RECORD_ID" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Update record command"
assert_json "$output" "Output is valid JSON"

# Test 2: Verify update was applied
print_step "Verifying update was applied"

output=$(monk_exec --format json data get "$MODEL_NAME" "$RECORD_ID" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_contains "$output" "Updated Title" "Title was updated"
assert_contains "$output" "published" "Status was updated"

# Test 3: Partial update (only one field)
print_step "Testing partial update"

output=$(echo '{"status": "archived"}' | \
    monk_exec --format json data update "$MODEL_NAME" "$RECORD_ID" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Partial update"

# Verify partial update
output=$(monk_exec --format json data get "$MODEL_NAME" "$RECORD_ID" 2>&1)
assert_contains "$output" "Updated Title" "Title preserved"
assert_contains "$output" "archived" "Status changed"

# Test 4: Update non-existent record (should fail)
print_step "Testing update non-existent record (should fail)"

output=$(echo '{"title": "test"}' | \
    monk_exec data update "$MODEL_NAME" "00000000-0000-0000-0000-000000000000" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "Update non-existent record rejected"

# Test 5: Bulk update via model-level PUT
print_step "Creating additional records for bulk update"

output=$(echo '[{"title": "Bulk 1", "status": "draft"}, {"title": "Bulk 2", "status": "draft"}]' | \
    monk_exec --format json data create "$MODEL_NAME" 2>&1)

ID1=$(json_get "$output" ".data[0].id")
ID2=$(json_get "$output" ".data[1].id")

print_step "Testing bulk update"

output=$(echo "[{\"id\": \"$ID1\", \"status\": \"updated\"}, {\"id\": \"$ID2\", \"status\": \"updated\"}]" | \
    monk_exec --format json data update "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Bulk update"

print_success "Data update tests complete"
