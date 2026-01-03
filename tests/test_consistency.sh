#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for codebase consistency and conventions
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# No setup/teardown needed - these are static analysis tests

# =============================================================================
# Test functions
# =============================================================================

# Check that lib/*.sh files use log_* functions instead of raw echo for user messages
# Allowed exceptions:
#   - common.sh (defines the log functions)
#   - echo "" (blank lines)
#   - echo "$var" or echo "${var}" (function return values)
#   - echo "word" (single word returns like "darwin", "linux", "managed")
#   - echo "prefix:$var" (structured data output like "file:$path")
#   - printf statements (used for data formatting)
test_use_log_functions() {
    local violations=()

    for file in "$ROOT_DIR"/lib/*.sh; do
        # Skip common.sh - it defines the log functions
        [[ "$(basename "$file")" == "common.sh" ]] && continue

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue

            # Skip blank line echoes
            echo "$line" | grep -q 'echo ""' && continue
            echo "$line" | grep -q "echo ''" && continue

            # Skip structured data returns (word:$var patterns)
            echo "$line" | grep -qE 'echo "[a-z_]+:\$' && continue
            echo "$line" | grep -qE 'echo "\$\{?[a-zA-Z_]' && continue

            # Skip single-word returns (no spaces in the string content)
            echo "$line" | grep -qE 'echo "[a-z_]+"$' && continue

            violations+=("$(basename "$file"): $line")
        done < <(grep -nE '^\s*echo (-e )?"' "$file" 2>/dev/null)
    done

    if [[ ${#violations[@]} -gt 0 ]]; then
        echo "  Raw echo statements should use log_* functions from lib/common.sh:"
        for v in "${violations[@]}"; do
            echo "    $v"
        done
        echo "  Available: log_info, log_step, log_ok, log_warn, log_error, log_section"
        return 1
    fi
    return 0
}

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
if test_use_log_functions; then
    echo "PASS: test_use_log_functions"
else
    echo "FAIL: test_use_log_functions"
fi

if test_make_targets_exist; then
    echo "PASS: test_make_targets_exist"
else
    echo "FAIL: test_make_targets_exist"
fi
