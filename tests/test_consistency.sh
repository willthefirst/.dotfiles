#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for consistency between Makefile targets and references in docs/code
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# No setup/teardown needed - this is a static analysis test

# =============================================================================
# Test functions
# =============================================================================

test_make_targets_exist() {
    local makefile="$ROOT_DIR/Makefile"

    # Extract valid targets from .PHONY line
    local valid_targets
    valid_targets=$(grep '^\.PHONY:' "$makefile" | sed 's/\.PHONY://' | tr ' ' '\n' | grep -v '^$')

    # Find all 'make <target>' references in shell files and markdown
    local referenced_targets
    referenced_targets=$(grep -rohE 'make [a-z][-a-z]*' "$ROOT_DIR"/*.sh "$ROOT_DIR"/*.md "$ROOT_DIR"/lib/*.sh "$ROOT_DIR"/.github 2>/dev/null \
        | sed 's/make //' \
        | sort -u)

    local missing=()
    for target in $referenced_targets; do
        if ! echo "$valid_targets" | grep -qx "$target"; then
            missing+=("$target")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "  Referenced make targets not found in Makefile:"
        for t in "${missing[@]}"; do
            echo "    - make $t"
        done
        return 1
    fi
    return 0
}

# =============================================================================
# Run all tests
# =============================================================================

# Simple pass/fail without setup/teardown
if test_make_targets_exist; then
    echo "PASS: test_make_targets_exist"
else
    echo "FAIL: test_make_targets_exist"
fi
