#!/usr/bin/env bash
# Run Proxmox acceptance tests

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib/proxmox_functions.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROXMOX_DIR="$REPO_ROOT/tests/proxmox"

cd "$REPO_ROOT"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Proxmox Acceptance Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test selection
TEST_SCENARIO="${1:-all}"
CLEANUP="${2:-no}"

run_test() {
    local scenario=$1
    local scenario_file="$PROXMOX_DIR/scenarios/${scenario}.yml"

    if [[ ! -f "$scenario_file" ]]; then
        log_error "Scenario $scenario not found"
        return 1
    fi

    echo -e "${GREEN}----------------------------------------${NC}"
    echo -e "${GREEN}Running: $scenario${NC}"
    echo -e "${GREEN}----------------------------------------${NC}"

    if ansible-playbook -i "$PROXMOX_DIR/inventory.yml" "$scenario_file" -v; then
        log_success "$scenario: PASSED"
        return 0
    else
        log_error "$scenario: FAILED"
        return 1
    fi
}

# Check if on Proxmox host
if ! is_proxmox_host; then
    log_error "Not running on Proxmox host"
    echo "Run this script on the Proxmox host or via SSH"
    exit 1
fi

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Run tests based on scenario
case "$TEST_SCENARIO" in
    workstation)
        log_info "Testing workstation setup only..."
        if run_test "workstation"; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
            FAILED_TESTS+=("workstation")
        fi
        ;;

    server)
        log_info "Testing server hardening only..."
        if run_test "server"; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
            FAILED_TESTS+=("server")
        fi
        ;;

    all)
        log_info "Running all acceptance tests..."
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
        ;;

    *)
        log_error "Unknown test scenario: $TEST_SCENARIO"
        echo "Valid options: workstation, server, all"
        exit 1
        ;;
esac

# Print summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo ""
    echo "Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
fi
echo "========================================="

# Cleanup if requested
if [[ "$CLEANUP" == "cleanup_yes" || "$CLEANUP" == "yes" ]]; then
    echo ""
    log_info "Running cleanup..."
    "$SCRIPT_DIR/cleanup.sh" --force
fi

# Exit with appropriate code
if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
else
    log_success "All tests passed!"
    exit 0
fi
