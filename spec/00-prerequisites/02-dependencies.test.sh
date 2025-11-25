#!/usr/bin/env bash
#
# Prerequisite Test: Dependencies
# Verifies required commands are available

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

check_command() {
    local cmd="$1"
    local desc="${2:-$cmd}"

    step "Checking $desc"
    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        case "$cmd" in
            curl) version=$(curl --version | head -1) ;;
            jq) version=$(jq --version 2>&1) ;;
            *) version="installed" ;;
        esac
        pass "$desc available: $version"
        return 0
    else
        fail "$desc not found"
        return 1
    fi
}

echo
echo "Prerequisite Test: Dependencies"
echo "================================"
echo

# Required commands
check_command "curl" "curl (HTTP client)"
check_command "jq" "jq (JSON processor)"
check_command "grep" "grep (text search)"
check_command "sed" "sed (text processing)"

# Summary
echo
echo "Results: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
