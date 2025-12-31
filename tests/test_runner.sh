#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Test Runner for Dotfiles
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Running dotfiles test suite..."
echo "=============================="

for test_file in "$SCRIPT_DIR"/test_*.sh; do
    if [[ -f "$test_file" && "$(basename "$test_file")" != "test_runner.sh" ]]; then
        echo ""
        echo -e "${YELLOW}Running: $(basename "$test_file")${NC}"
        echo "---"

        if output=$("$test_file" 2>&1); then
            echo "$output"
        else
            echo "$output"
        fi

        # Count results
        pass_count=$(echo "$output" | grep -c "^PASS:" || true)
        fail_count=$(echo "$output" | grep -c "^FAIL:" || true)

        PASS=$((PASS + pass_count))
        FAIL=$((FAIL + fail_count))
    fi
done

echo ""
echo "=============================="
if [[ $FAIL -gt 0 ]]; then
    echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
    exit 1
else
    echo -e "Results: ${GREEN}$PASS passed${NC}, $FAIL failed"
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
