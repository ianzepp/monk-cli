#!/usr/bin/env bash
#
# Prerequisite Test: API Server
# Verifies the API server is running and responsive

API_BASE="${API_BASE:-http://localhost:9001}"

# Simple output functions
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
echo "Prerequisite Test: API Server"
echo "=============================="
echo "API Base: $API_BASE"
echo

# Test 1: Health endpoint
step "Checking /health endpoint"
if response=$(curl -s -w "\n%{http_code}" "$API_BASE/health" 2>&1); then
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "200" ]]; then
        pass "Health endpoint returned 200"
    else
        fail "Health endpoint returned $http_code"
    fi
else
    fail "Cannot connect to API server"
    echo "  Start the API server: cd monk-api && npm start"
fi

# Test 2: Root endpoint returns API info
step "Checking root endpoint"
if response=$(curl -s "$API_BASE/" 2>&1); then
    if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
        pass "Root endpoint returns valid JSON"
    else
        fail "Root endpoint response is not valid JSON"
    fi
else
    fail "Cannot reach root endpoint"
fi

# Test 3: Auth endpoints available
step "Checking auth endpoints"
if response=$(curl -s "$API_BASE/auth/login" -X POST -H "Content-Type: application/json" -d '{}' 2>&1); then
    # Should return an error about missing tenant, but endpoint should exist
    if echo "$response" | jq -e '.' >/dev/null 2>&1; then
        pass "Auth endpoint responds"
    else
        fail "Auth endpoint response is not valid JSON"
    fi
else
    fail "Cannot reach auth endpoint"
fi

# Test 4: Registration endpoint available
step "Checking register endpoint"
if response=$(curl -s "$API_BASE/auth/register" -X POST -H "Content-Type: application/json" -d '{}' 2>&1); then
    if echo "$response" | jq -e '.' >/dev/null 2>&1; then
        pass "Register endpoint responds"
    else
        fail "Register endpoint response is not valid JSON"
    fi
else
    fail "Cannot reach register endpoint"
fi

# Summary
echo
echo "Results: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
