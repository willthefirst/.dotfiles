#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Test Runner for Dotfiles
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

log_section "Running dotfiles test suite..."

for test_file in "$SCRIPT_DIR"/test_*.sh; do
    if [[ -f "$test_file" && "$(basename "$test_file")" != "test_runner.sh" ]]; then
        log_section "$(basename "$test_file")"

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
if [[ $FAIL -gt 0 ]]; then
    log_error "Results: $PASS passed, $FAIL failed"
    exit 1
else
    log_ok "Results: $PASS passed, $FAIL failed"
    exit 0
fi
