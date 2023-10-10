#!/usr/bin/env bash
# Cleanup LXD test containers

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Cleaning Up LXD Test Containers${NC}"
echo -e "${YELLOW}========================================${NC}"

# Check if LXD is installed
if ! command -v lxc &> /dev/null; then
    echo -e "${RED}ERROR: LXD is not installed${NC}"
    exit 1
fi

# List of test container patterns
TEST_PATTERNS=(
    "test-*"
    "dev-*"
    "minimal-*"
)

# Count containers to delete
CONTAINERS_DELETED=0

# Find and delete test containers
echo "Searching for test containers..."
for pattern in "${TEST_PATTERNS[@]}"; do
    # Find containers matching pattern
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -e "${YELLOW}Deleting: $container${NC}"

            # Stop container (force)
            if lxc stop "$container" --force 2>/dev/null; then
                echo "  Stopped"
            fi

            # Delete container
            if lxc delete "$container" --force 2>/dev/null; then
                echo -e "  ${GREEN}Deleted${NC}"
                ((CONTAINERS_DELETED++))
            else
                echo -e "  ${RED}Failed to delete${NC}"
            fi
        fi
    done < <(lxc list --format csv -c n | grep -E "^${pattern//\*/.*}" || true)
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Containers deleted: $CONTAINERS_DELETED"

# Optionally clean up unused images
if [[ "${1:-}" == "--images" ]]; then
    echo ""
    echo -e "${YELLOW}Cleaning up unused images...${NC}"
    lxc image list --format csv | while IFS=, read -r fingerprint alias; do
        # Check if image is used
        if ! lxc list --format csv -c volatile.base_image | grep -q "$fingerprint"; then
            echo "Deleting unused image: $alias"
            lxc image delete "$fingerprint" 2>/dev/null || true
        fi
    done
fi

echo ""
echo "Current containers:"
lxc list

echo ""
echo "Done!"
