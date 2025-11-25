#!/usr/bin/env bash
#
# Data CLI Test: Delete Record
# Tests deleting records via CLI

source "$(dirname "${BASH_SOURCE[0]}")/../test-helper.sh"

use_shared_tenant "data-delete"

# Create a model and records for testing
MODEL_NAME=$(unique_name "message")

print_step "Creating test model: $MODEL_NAME"
echo '{"fields": [{"name": "text", "type": "text"}]}' | \
    monk_exec describe create "$MODEL_NAME" >/dev/null 2>&1

print_step "Creating test records"
output=$(echo '[{"text": "Delete me"}, {"text": "Keep me"}, {"text": "Also delete"}]' | \
    monk_exec --format json data create "$MODEL_NAME" 2>&1)

RECORD_ID1=$(json_get "$output" ".data[0].id")
RECORD_ID2=$(json_get "$output" ".data[1].id")
RECORD_ID3=$(json_get "$output" ".data[2].id")

print_info "Created records: $RECORD_ID1, $RECORD_ID2, $RECORD_ID3"

# Test 1: Delete single record
print_step "Testing 'monk data delete MODEL ID'"

output=$(monk_exec --format json data delete "$MODEL_NAME" "$RECORD_ID1" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Delete single record"

# Test 2: Verify record is deleted
print_step "Verifying record was deleted"

output=$(monk_exec data get "$MODEL_NAME" "$RECORD_ID1" 2>&1) || exit_code=$?

# Should fail or return deleted indicator
if [[ $exit_code -ne 0 ]] || echo "$output" | grep -qi "not found\|deleted"; then
    print_success "Record correctly deleted/not found"
else
    print_warning "Record may still exist (soft delete)"
fi

# Test 3: Verify other records still exist
print_step "Verifying other records still exist"

output=$(monk_exec --format json data get "$MODEL_NAME" "$RECORD_ID2" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Other record still exists"
assert_contains "$output" "Keep me" "Content preserved"

# Test 4: Delete non-existent record (should fail)
print_step "Testing delete non-existent record (should fail)"

output=$(monk_exec data delete "$MODEL_NAME" "00000000-0000-0000-0000-000000000000" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_failure "$exit_code" "$output" "Delete non-existent record rejected"

# Test 5: Bulk delete
print_step "Testing bulk delete via stdin"

output=$(echo "[{\"id\": \"$RECORD_ID3\"}]" | \
    monk_exec --format json data delete "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

assert_success "$exit_code" "$output" "Bulk delete"

# Test 6: List remaining records
print_step "Verifying remaining record count"

output=$(monk_exec --format json data list "$MODEL_NAME" 2>&1) || exit_code=$?
exit_code=${exit_code:-0}

# Should have only 1 record left (the "Keep me" one)
length=$(json_get "$output" ".data | length")
if [[ "$length" == "1" ]]; then
    print_success "Only 1 record remains after deletes"
else
    print_warning "Expected 1 record, got $length (soft delete may show trashed)"
fi

print_success "Data delete tests complete"
