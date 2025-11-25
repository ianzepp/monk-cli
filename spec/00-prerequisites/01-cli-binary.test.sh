#!/usr/bin/env bash
#
# Prerequisite Test: CLI Binary
# Verifies the monk CLI binary exists and is executable

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$(cd "$SPEC_DIR/.." && pwd)"
MONK_BIN="${PROJECT_DIR}/bin/monk"

# Simple output functions (no test-helper.sh to avoid setup)
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗ $1${NC}"
    ((FAILED++))
}

step() {
    echo -e "${BLUE}▶ $1${NC}"
}

echo
echo "Prerequisite Test: CLI Binary"
echo "=============================="
echo

# Test 1: Binary exists
step "Checking monk binary exists"
if [[ -f "$MONK_BIN" ]]; then
    pass "Binary exists at $MONK_BIN"
else
    fail "Binary not found at $MONK_BIN"
    echo "  Run ./rebuild.sh to build the CLI"
fi

# Test 2: Binary is executable
step "Checking monk binary is executable"
if [[ -x "$MONK_BIN" ]]; then
    pass "Binary is executable"
else
    fail "Binary is not executable"
    echo "  Run: chmod +x $MONK_BIN"
fi

# Test 3: Binary runs without error
step "Checking monk --version works"
if output=$("$MONK_BIN" --version 2>&1); then
    pass "Version command works: $output"
else
    fail "Version command failed"
fi

# Test 4: Binary shows help
step "Checking monk --help works"
if output=$("$MONK_BIN" --help 2>&1); then
    if echo "$output" | grep -q "monk"; then
        pass "Help command works"
    else
        fail "Help output doesn't look right"
    fi
else
    fail "Help command failed"
fi

# Summary
echo
echo "Results: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
