#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Test helpers - shared setup/teardown for all test files
# =============================================================================

# Global test state
TEST_HOME=""
TEST_DOTFILES=""
ORIGINAL_HOME=""
ORIGINAL_DOTFILES_DIR=""

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

# Assert that a symlink exists and points to the expected target
# Usage: assert_symlink "/path/to/link" "/expected/target"
assert_symlink() {
    local link="$1"
    local expected="$2"

    if [[ ! -L "$link" ]]; then
        echo "FAIL: Expected symlink at $link"
        return 1
    fi

    local actual
    actual=$(resolve_link "$link")
    local expected_resolved
    expected_resolved=$(resolve_link "$expected")

    if [[ "$actual" != "$expected_resolved" ]]; then
        echo "FAIL: Symlink $link points to $actual, expected $expected_resolved"
        return 1
    fi
    return 0
}

# Assert a file exists (not a symlink)
# Usage: assert_file_exists "/path/to/file"
assert_file_exists() {
    local path="$1"
    if [[ -f "$path" && ! -L "$path" ]]; then
        return 0
    fi
    echo "FAIL: Expected regular file at $path"
    return 1
}

# Assert a directory exists
# Usage: assert_dir_exists "/path/to/dir"
assert_dir_exists() {
    local path="$1"
    if [[ -d "$path" ]]; then
        return 0
    fi
    echo "FAIL: Expected directory at $path"
    return 1
}

# Get file permissions in octal (portable across macOS and Linux)
# Usage: get_file_permissions "/path/to/file"
get_file_permissions() {
    local path="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f "%Lp" "$path"
    else
        stat -c "%a" "$path"
    fi
}

# Assert file has expected permissions
# Usage: assert_permissions "/path/to/file" "700"
assert_permissions() {
    local path="$1"
    local expected="$2"
    local actual
    actual=$(get_file_permissions "$path")
    if [[ "$actual" == "$expected" ]]; then
        return 0
    fi
    echo "  Expected permissions $expected on $path, got $actual"
    return 1
}

# =============================================================================
# Test runner helpers - reduce boilerplate in test functions
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

# Assert a condition is true
# Usage: assert "description" command [args...]
# Example: assert "directory exists" test -d "$path"
assert() {
    local msg="$1"
    shift
    if "$@"; then
        return 0
    fi
    echo "  $msg"
    return 1
}

# Assert a command fails (returns non-zero)
# Usage: assert_fails "description" command [args...]
# Example: assert_fails "file does not exist" test -f "$path"
assert_fails() {
    local msg="$1"
    shift
    if ! "$@"; then
        return 0
    fi
    echo "  $msg"
    return 1
}

# Assert output contains expected string
# Usage: assert_contains "$output" "expected"
assert_contains() {
    local output="$1"
    local expected="$2"
    if echo "$output" | grep -q "$expected"; then
        return 0
    fi
    echo "  Expected output to contain: $expected"
    return 1
}
