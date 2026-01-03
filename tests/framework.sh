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
TEST_ROOT=""
TEST_HOME=""
TEST_DOTFILES=""
ORIGINAL_HOME=""
ORIGINAL_DOTFILES_DIR=""
ORIGINAL_DOTFILES_HOME=""
ORIGINAL_DOTFILES_CONFIG_DIR=""
ORIGINAL_DOTFILES_SSH_DIR=""
ORIGINAL_DOTFILES_BIN_DIR=""
ORIGINAL_DOTFILES_TEMP_DIR=""
ORIGINAL_DOTFILES_BACKUP_DIR=""

# =============================================================================
# Test initialization
# =============================================================================

# Initialize test environment and source required modules
# Usage: init_test_env [module1] [module2] ...
# Example: init_test_env backup deploy
# Sources all modules via lib/init.sh (guards prevent double-loading)
init_test_env() {
    # Source all library modules via central initialization
    # Guards prevent redundant sourcing when modules are explicitly requested
    # shellcheck source=lib/init.sh
    source "$ROOT_DIR/lib/init.sh"

    # Source additional modules passed as arguments (no-op if already loaded via init.sh)
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
# Creates fully isolated test directories for all configurable paths
setup_test_env() {
    # Initialize mock system
    mock_init

    # Create isolated test root
    TEST_ROOT=$(mktemp -d)
    TEST_HOME="$TEST_ROOT/home"
    TEST_DOTFILES="$TEST_ROOT/dotfiles"

    # Save original values
    ORIGINAL_HOME="$HOME"
    ORIGINAL_DOTFILES_DIR="$DOTFILES_DIR"
    ORIGINAL_DOTFILES_HOME="${DOTFILES_HOME:-}"
    ORIGINAL_DOTFILES_CONFIG_DIR="${DOTFILES_CONFIG_DIR:-}"
    ORIGINAL_DOTFILES_SSH_DIR="${DOTFILES_SSH_DIR:-}"
    ORIGINAL_DOTFILES_BIN_DIR="${DOTFILES_BIN_DIR:-}"
    ORIGINAL_DOTFILES_TEMP_DIR="${DOTFILES_TEMP_DIR:-}"
    ORIGINAL_DOTFILES_BACKUP_DIR="${DOTFILES_BACKUP_DIR:-}"

    # Override all paths for testing
    HOME="$TEST_HOME"
    DOTFILES_DIR="$TEST_DOTFILES"
    export DOTFILES_HOME="$TEST_HOME"
    export DOTFILES_CONFIG_DIR="$TEST_HOME/.config"
    export DOTFILES_SSH_DIR="$TEST_HOME/.ssh"
    export DOTFILES_BIN_DIR="$TEST_ROOT/bin"
    export DOTFILES_TEMP_DIR="$TEST_ROOT/tmp"
    export DOTFILES_BACKUP_DIR="$TEST_HOME"

    # Create all test directories
    mkdir -p "$TEST_HOME"
    mkdir -p "$TEST_DOTFILES"
    mkdir -p "$DOTFILES_CONFIG_DIR"
    mkdir -p "$DOTFILES_SSH_DIR"
    mkdir -p "$DOTFILES_BIN_DIR"
    mkdir -p "$DOTFILES_TEMP_DIR"
}

# Teardown test environment and restore original values
teardown_test_env() {
    # Cleanup mock system
    mock_cleanup

    # Restore original values
    HOME="$ORIGINAL_HOME"
    DOTFILES_DIR="$ORIGINAL_DOTFILES_DIR"

    # Restore or unset path overrides
    if [[ -n "$ORIGINAL_DOTFILES_HOME" ]]; then
        export DOTFILES_HOME="$ORIGINAL_DOTFILES_HOME"
    else
        unset DOTFILES_HOME
    fi
    if [[ -n "$ORIGINAL_DOTFILES_CONFIG_DIR" ]]; then
        export DOTFILES_CONFIG_DIR="$ORIGINAL_DOTFILES_CONFIG_DIR"
    else
        unset DOTFILES_CONFIG_DIR
    fi
    if [[ -n "$ORIGINAL_DOTFILES_SSH_DIR" ]]; then
        export DOTFILES_SSH_DIR="$ORIGINAL_DOTFILES_SSH_DIR"
    else
        unset DOTFILES_SSH_DIR
    fi
    if [[ -n "$ORIGINAL_DOTFILES_BIN_DIR" ]]; then
        export DOTFILES_BIN_DIR="$ORIGINAL_DOTFILES_BIN_DIR"
    else
        unset DOTFILES_BIN_DIR
    fi
    if [[ -n "$ORIGINAL_DOTFILES_TEMP_DIR" ]]; then
        export DOTFILES_TEMP_DIR="$ORIGINAL_DOTFILES_TEMP_DIR"
    else
        unset DOTFILES_TEMP_DIR
    fi
    if [[ -n "$ORIGINAL_DOTFILES_BACKUP_DIR" ]]; then
        export DOTFILES_BACKUP_DIR="$ORIGINAL_DOTFILES_BACKUP_DIR"
    else
        unset DOTFILES_BACKUP_DIR
    fi

    # Clean up test directories
    [[ -d "$TEST_ROOT" ]] && rm -rf "$TEST_ROOT"
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
