#!/usr/bin/env bash
# shellcheck shell=bash
# =================================================================
# Mock Infrastructure for Bash Testing
# =================================================================
#
# Usage:
#   1. Call mock_init() in test setup (done automatically by setup_test_env)
#   2. Create mocks: mock_function "function_name"
#   3. Run code under test
#   4. Verify: assert_called "function_name"
#   5. Cleanup happens automatically in teardown
#
# Examples:
#
#   # Mock a function to succeed
#   mock_function "stow"
#   deploy_package "mypackage"
#   assert_called "stow"
#
#   # Mock a function to fail
#   mock_function_fail "brew" "Package not found"
#   result=$(install_dep "nonexistent" 2>&1) || true
#   assert_called "brew"
#
#   # Verify specific arguments
#   mock_function "pkg_install"
#   install_package_deps "git"
#   assert_called_with "pkg_install" "lazygit"
#
#   # Check call count
#   mock_function "log_step"
#   some_function_that_logs
#   assert_call_count "log_step" 3
#
# =================================================================

# Global call log file
MOCK_CALL_LOG=""

# =================================================================
# Core Mock Functions
# =================================================================

# Initialize mock system
mock_init() {
    MOCK_CALL_LOG=$(mktemp)
    echo "" > "$MOCK_CALL_LOG"
}

# Cleanup mock system
mock_cleanup() {
    [[ -f "$MOCK_CALL_LOG" ]] && rm -f "$MOCK_CALL_LOG"
    MOCK_CALL_LOG=""
}

# Record a function call
# Usage: mock_record <function_name> [args...]
mock_record() {
    local func_name="$1"
    shift
    echo "${func_name}|$*" >> "$MOCK_CALL_LOG"
}

# Create a mock function that records calls and returns success
# Usage: mock_function <function_name> [return_value]
mock_function() {
    local func_name="$1"
    local return_val="${2:-0}"

    eval "${func_name}() {
        mock_record '${func_name}' \"\$@\"
        return ${return_val}
    }"
}

# Create a mock that outputs specific text
# Usage: mock_function_output <function_name> <output>
mock_function_output() {
    local func_name="$1"
    local output="$2"

    eval "${func_name}() {
        mock_record '${func_name}' \"\$@\"
        echo '${output}'
        return 0
    }"
}

# Create a mock that fails
# Usage: mock_function_fail <function_name> [error_message]
mock_function_fail() {
    local func_name="$1"
    local error_msg="${2:-Mock failure}"

    eval "${func_name}() {
        mock_record '${func_name}' \"\$@\"
        echo '${error_msg}' >&2
        return 1
    }"
}

# =================================================================
# Verification Functions
# =================================================================

# Verify a function was called
# Usage: mock_verify_called <function_name>
# Returns: 0 if called, 1 if not
mock_verify_called() {
    local func_name="$1"
    grep -q "^${func_name}|" "$MOCK_CALL_LOG"
}

# Verify a function was called with specific arguments
# Usage: mock_verify_called_with <function_name> <expected_args>
mock_verify_called_with() {
    local func_name="$1"
    local expected_args="$2"
    grep -q "^${func_name}|${expected_args}$" "$MOCK_CALL_LOG"
}

# Get the number of times a function was called
# Usage: mock_call_count <function_name>
mock_call_count() {
    local func_name="$1"
    grep -c "^${func_name}|" "$MOCK_CALL_LOG" || echo "0"
}

# Get all calls to a function (for debugging)
# Usage: mock_get_calls <function_name>
mock_get_calls() {
    local func_name="$1"
    grep "^${func_name}|" "$MOCK_CALL_LOG" | sed "s/^${func_name}|//"
}

# Verify a function was NOT called
# Usage: mock_verify_not_called <function_name>
mock_verify_not_called() {
    local func_name="$1"
    ! grep -q "^${func_name}|" "$MOCK_CALL_LOG"
}

# Clear call history (useful between tests)
mock_reset() {
    echo "" > "$MOCK_CALL_LOG"
}

# =================================================================
# Test Assertions for Mocks
# =================================================================

# Assert function was called (fails test if not)
assert_called() {
    local func_name="$1"
    if ! mock_verify_called "$func_name"; then
        echo "ASSERTION FAILED: Expected $func_name to be called"
        mock_get_calls "$func_name"
        return 1
    fi
}

# Assert function was called with args
assert_called_with() {
    local func_name="$1"
    local expected_args="$2"
    if ! mock_verify_called_with "$func_name" "$expected_args"; then
        echo "ASSERTION FAILED: Expected $func_name to be called with: $expected_args"
        echo "Actual calls:"
        mock_get_calls "$func_name"
        return 1
    fi
}

# Assert function was called N times
assert_call_count() {
    local func_name="$1"
    local expected_count="$2"
    local actual_count
    actual_count=$(mock_call_count "$func_name")
    if [[ "$actual_count" -ne "$expected_count" ]]; then
        echo "ASSERTION FAILED: Expected $func_name to be called $expected_count times, was called $actual_count times"
        return 1
    fi
}

# Assert function was NOT called
assert_not_called() {
    local func_name="$1"
    if ! mock_verify_not_called "$func_name"; then
        echo "ASSERTION FAILED: Expected $func_name NOT to be called"
        echo "But it was called with:"
        mock_get_calls "$func_name"
        return 1
    fi
}

# =================================================================
# Package/Directory Mocks
# =================================================================

# Create a mock stow package
# Usage: create_mock_package "package_name" "relative/path/to/file"
create_mock_package() {
    local pkg="$1"
    local file_path="$2"
    local pkg_dir="$TEST_DOTFILES/$pkg"
    local full_path="$pkg_dir/$file_path"

    mkdir -p "$(dirname "$full_path")"
    touch "$full_path"
}

# Create a mock stow package with content
# Usage: create_mock_package_with_content "package_name" "relative/path" "content"
create_mock_package_with_content() {
    local pkg="$1"
    local file_path="$2"
    local content="$3"
    local pkg_dir="$TEST_DOTFILES/$pkg"
    local full_path="$pkg_dir/$file_path"

    mkdir -p "$(dirname "$full_path")"
    echo "$content" > "$full_path"
}

# =================================================================
# Common Mock Presets
# =================================================================

# Mock stow command
mock_stow() {
    mock_function "stow"
}

# Mock stow to fail
mock_stow_fail() {
    mock_function_fail "stow" "stow: conflict detected"
}

# Mock brew command
mock_brew() {
    mock_function "brew"
}

# Mock apt-get command
mock_apt_get() {
    mock_function "apt-get"
}

# Mock git command
mock_git() {
    mock_function "git"
}

# Mock pkg_install for dependency tests
mock_pkg_install() {
    mock_function "pkg_install"
}
