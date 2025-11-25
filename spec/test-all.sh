#!/usr/bin/env bash
#
# Test Runner for monk-cli
# Runs all test suites with a single shared tenant using the session system
#
# Usage:
#   ./spec/test-all.sh              # Run all tests
#   ./spec/test-all.sh 31           # Run tests matching "31"
#   ./spec/test-all.sh describe     # Run tests matching "describe"
#   ./spec/test-all.sh 30-39        # Run tests in range 30-39
#
# Environment:
#   CLI_VERBOSE=true    Show detailed output
#   API_BASE=http://... Override API server URL
#
# Session Management:
#   Uses a fixed session alias "cli-tests" for all test runs.
#   The test tenant is registered once at the start and the session
#   is available throughout the test run.

# Mark ourselves as the test runner BEFORE sourcing helper
export IS_TEST_RUNNER=true

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SPEC_DIR/.." && pwd)"
MONK_BIN="${PROJECT_DIR}/bin/monk"

# Source helper for shared functions
source "$SPEC_DIR/test-helper.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
FILES_RUN=0
FILES_PASSED=0
FILES_FAILED=0
FAILED_FILES=()

print_banner() {
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          monk-cli Test Suite Runner                       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_usage() {
    echo "Usage: $0 [PATTERN]"
    echo
    echo "Examples:"
    echo "  $0                 # Run all tests"
    echo "  $0 31              # Run tests in 31-* directories"
    echo "  $0 describe        # Run tests matching 'describe'"
    echo "  $0 30-39           # Run tests in range 30-39"
    echo
    echo "Environment:"
    echo "  CLI_VERBOSE=true   Show detailed output"
    echo "  API_BASE=URL       Override API server (default: http://localhost:9001)"
}

# Check if directory matches pattern
matches_pattern() {
    local dir="$1"
    local pattern="$2"
    local dirname=$(basename "$dir")

    # No pattern = match all
    if [[ -z "$pattern" ]]; then
        return 0
    fi

    # Range pattern (e.g., 30-39)
    if [[ "$pattern" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local start="${BASH_REMATCH[1]}"
        local end="${BASH_REMATCH[2]}"
        local dir_num="${dirname%%-*}"

        if [[ "$dir_num" =~ ^[0-9]+$ ]]; then
            if [[ $dir_num -ge $start && $dir_num -le $end ]]; then
                return 0
            fi
        fi
        return 1
    fi

    # Simple substring match
    if [[ "$dirname" == *"$pattern"* ]]; then
        return 0
    fi

    return 1
}

# Find all test directories
find_test_dirs() {
    local pattern="${1:-}"

    for dir in "$SPEC_DIR"/*/; do
        if [[ -d "$dir" ]]; then
            local dirname=$(basename "$dir")

            # Skip hidden directories
            [[ "$dirname" == .* ]] && continue

            # Check pattern match
            if matches_pattern "$dir" "$pattern"; then
                echo "$dir"
            fi
        fi
    done | sort
}

# Run a single test file
run_test_file() {
    local test_file="$1"
    local test_name=$(basename "$test_file")

    echo -e "${BLUE}  Running: $test_name${NC}"

    # Run test with inherited environment (TEST_TENANT, TEST_SESSION_ALIAS)
    # Use a subshell so test file's exit trap doesn't affect us
    if ( bash "$test_file" ); then
        ((FILES_PASSED++)) || true
        return 0
    else
        ((FILES_FAILED++)) || true
        FAILED_FILES+=("$test_file")
        return 1
    fi
}

# Run all tests in a directory
run_test_suite() {
    local suite_dir="$1"
    local suite_name=$(basename "$suite_dir")

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Suite: $suite_name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Find test files in this directory
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$suite_dir" -maxdepth 1 -name "*.test.sh" -print0 | sort -z)

    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}  No test files found${NC}"
        return 0
    fi

    local suite_failed=0

    for test_file in "${test_files[@]}"; do
        ((FILES_RUN++)) || true

        if ! run_test_file "$test_file"; then
            ((suite_failed++)) || true
        fi
    done

    if [[ $suite_failed -eq 0 ]]; then
        echo -e "${GREEN}  Suite passed${NC}"
    else
        echo -e "${RED}  Suite had $suite_failed failure(s)${NC}"
    fi

    return $suite_failed
}

# Print final summary
print_summary() {
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Final Summary${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo
    echo "  Test files run:    $FILES_RUN"
    echo -e "  Files passed:      ${GREEN}$FILES_PASSED${NC}"
    echo -e "  Files failed:      ${RED}$FILES_FAILED${NC}"
    echo
    echo "  Session alias:     $TEST_SESSION_ALIAS"
    echo "  Shared tenant:     ${TEST_TENANT:-<none>}"

    if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
        echo
        echo -e "${RED}  Failed tests:${NC}"
        for file in "${FAILED_FILES[@]}"; do
            echo "    - $(basename "$file")"
        done
    fi

    echo
    if [[ $FILES_FAILED -eq 0 ]]; then
        echo -e "${GREEN}  All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}  Some tests failed!${NC}"
        return 1
    fi
}

# Cleanup on exit (no temp dirs to clean up with session-based approach)
cleanup() {
    echo
    echo -e "${BLUE}▶ Test run complete${NC}"
    echo -e "${GREEN}✓ Session '$TEST_SESSION_ALIAS' remains available for debugging${NC}"
}

trap cleanup EXIT

# Main
main() {
    local pattern="${1:-}"

    # Handle help flag
    if [[ "$pattern" == "-h" || "$pattern" == "--help" ]]; then
        print_usage
        exit 0
    fi

    print_banner

    # Show configuration
    echo "Configuration:"
    echo "  API Server: ${API_BASE:-http://localhost:9001}"
    echo "  Verbose:    ${CLI_VERBOSE:-false}"
    echo "  Pattern:    ${pattern:-<all>}"
    echo

    # Verify prerequisites
    if [[ ! -x "$MONK_BIN" ]]; then
        echo -e "${RED}ERROR: monk binary not found${NC}"
        echo "Run ./rebuild.sh to build the CLI"
        exit 1
    fi

    # Check API server
    if ! curl -s "${API_BASE:-http://localhost:9001}/health" >/dev/null 2>&1; then
        echo -e "${RED}ERROR: API server not responding at ${API_BASE:-http://localhost:9001}${NC}"
        echo "Start the API server first: cd monk-api && npm start"
        exit 1
    fi

    echo -e "${GREEN}✓ Prerequisites OK${NC}"
    echo

    # Register shared tenant with fixed session alias
    echo -e "${BLUE}▶ Setting up test environment...${NC}"
    if ! register_shared_tenant; then
        echo -e "${RED}ERROR: Failed to register shared tenant${NC}"
        exit 1
    fi
    echo

    # Export for child processes
    export TEST_TENANT
    export TEST_SESSION_ALIAS

    # Find and run test suites
    local test_dirs
    test_dirs=$(find_test_dirs "$pattern")

    if [[ -z "$test_dirs" ]]; then
        echo -e "${YELLOW}No test suites found matching pattern: $pattern${NC}"
        exit 0
    fi

    local overall_result=0

    while IFS= read -r dir; do
        run_test_suite "$dir" || overall_result=1
    done <<< "$test_dirs"

    print_summary

    exit $overall_result
}

main "$@"
