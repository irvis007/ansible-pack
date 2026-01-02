#!/usr/bin/env bash
# Run LXD integration tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LXD_DIR="$REPO_ROOT/tests/lxd"

cd "$REPO_ROOT"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}LXD Integration Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test selection
TEST_SCENARIO="${1:-all}"
CLEANUP="${2:-yes}"

run_test() {
    local scenario=$1
    local scenario_file="$LXD_DIR/scenarios/${scenario}.yml"

    if [[ ! -f "$scenario_file" ]]; then
        echo -e "${RED}ERROR: Scenario $scenario not found${NC}"
        return 1
    fi

    echo -e "${GREEN}----------------------------------------${NC}"
    echo -e "${GREEN}Running: $scenario${NC}"
    echo -e "${GREEN}----------------------------------------${NC}"

    if ansible-playbook -i "$LXD_DIR/inventory.yml" "$scenario_file" -v; then
        echo -e "${GREEN}✓ $scenario: PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ $scenario: FAILED${NC}"
        return 1
    fi
}

# Check if LXD is available
if ! command -v lxc &> /dev/null; then
    echo -e "${RED}ERROR: LXD is not installed${NC}"
    echo "Install with: sudo snap install lxd"
    exit 1
fi

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Run tests based on scenario
case "$TEST_SCENARIO" in
    workstation)
        echo "Testing workstation setup only..."
        if run_test "workstation"; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
            FAILED_TESTS+=("workstation")
        fi
        ;;

    server)
        echo "Testing server hardening only..."
        if run_test "server"; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
            FAILED_TESTS+=("server")
        fi
        ;;

    all)
        echo "Running all integration tests..."
        echo ""

        # Test 1: Workstation
        if run_test "workstation"; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
            FAILED_TESTS+=("workstation")
        fi
        echo ""

        # Test 2: Server
        if run_test "server"; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
            FAILED_TESTS+=("server")
        fi
        echo ""
        ;;

    *)
        echo -e "${RED}Unknown scenario: $TEST_SCENARIO${NC}"
        echo "Usage: $0 [workstation|server|all] [yes|no]"
        exit 1
        ;;
esac

# Print summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo ""
    echo "Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}✗ $test${NC}"
    done
fi

echo ""

# Cleanup option
if [[ "$CLEANUP" == "yes" ]]; then
    echo -e "${YELLOW}Cleaning up test containers...${NC}"
    "$SCRIPT_DIR/cleanup.sh"
fi

# Exit with appropriate code
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
