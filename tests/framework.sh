#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Test framework - runner, setup/teardown, and initialization
# =============================================================================
# This module provides:
#   - Test environment setup/teardown
#   - Test initialization for sourcing lib modules
#   - Test runner with auto-discovery
# =============================================================================

FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$FRAMEWORK_DIR")"

# Global test state
TEST_HOME=""
TEST_DOTFILES=""
ORIGINAL_HOME=""
ORIGINAL_DOTFILES_DIR=""

# =============================================================================
# Test initialization
# =============================================================================

# Initialize test environment and source required modules
# Usage: init_test_env [module1] [module2] ...
# Example: init_test_env backup deploy
# Always sources: common.sh, config.sh
init_test_env() {
    # Always source common and config
    # shellcheck source=lib/common.sh
    source "$ROOT_DIR/lib/common.sh"
    # shellcheck source=lib/config.sh
    source "$ROOT_DIR/lib/config.sh"

    # Source additional modules passed as arguments
    for module in "$@"; do
        local module_path="$ROOT_DIR/lib/${module}.sh"
        if [[ -f "$module_path" ]]; then
            # shellcheck disable=SC1090
            source "$module_path"
        fi
    done
}

# =============================================================================
# Test environment setup/teardown
# =============================================================================

# Setup test environment with isolated HOME and DOTFILES_DIR
# Usage: setup_test_env [create_dotfiles_structure]
# If create_dotfiles_structure is "true", creates a mock .dotfiles structure
setup_test_env() {
    local create_structure="${1:-false}"

    TEST_HOME=$(mktemp -d)
    TEST_DOTFILES=$(mktemp -d)
    ORIGINAL_HOME="$HOME"
    ORIGINAL_DOTFILES_DIR="$DOTFILES_DIR"

    # Override for testing
    HOME="$TEST_HOME"
    DOTFILES_DIR="$TEST_DOTFILES"

    # Create common directories
    mkdir -p "$TEST_HOME/.config"
    mkdir -p "$TEST_HOME/.ssh"

    if [[ "$create_structure" == "true" ]]; then
        mkdir -p "$DOTFILES_DIR"
    fi
}

# Teardown test environment and restore original values
teardown_test_env() {
    HOME="$ORIGINAL_HOME"
    DOTFILES_DIR="$ORIGINAL_DOTFILES_DIR"
    rm -rf "$TEST_HOME" "$TEST_DOTFILES"
}

# =============================================================================
# Test runner
# =============================================================================

# Run a test with automatic setup/teardown and PASS/FAIL reporting
# Usage: run_test test_function_name
# The test function should return 0 for pass, non-zero for fail
# Error messages from assert_* functions are captured and displayed on failure
run_test() {
    local test_name="$1"
    local output
    setup
    if output=$("$test_name" 2>&1); then
        echo "PASS: $test_name"
    else
        echo "FAIL: $test_name"
        [[ -n "$output" ]] && echo "$output"
    fi
    teardown
}

# Run all test_* functions in the current script
# Auto-discovers functions, runs each with setup/teardown
# Usage: run_all_tests
run_all_tests() {
    # Get all function names starting with test_
    local test_functions
    test_functions=$(declare -F | awk '{print $3}' | grep '^test_')

    for test_func in $test_functions; do
        run_test "$test_func"
    done
}

# Default setup/teardown - tests can override these
# Default setup creates isolated test environment
setup() {
    setup_test_env
}

# Default teardown cleans up test environment
teardown() {
    teardown_test_env
}
