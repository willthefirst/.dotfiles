#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for conflict detection
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source required modules
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/conflicts.sh"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"

setup() {
    setup_test_env
    create_mock_package "zsh" ".zshrc"
}

teardown() {
    teardown_test_env
}

# =============================================================================
# Test functions - each returns 0 for pass, non-zero for fail
# =============================================================================

test_detects_file_conflict() {
    touch "$TEST_HOME/.zshrc"

    local conflicts
    conflicts=$(get_package_conflicts "$TEST_DOTFILES/zsh" "$TEST_HOME")

    assert_contains "$conflicts" "file:$TEST_HOME/.zshrc"
}

test_detects_symlink_conflict() {
    ln -s /some/other/path "$TEST_HOME/.zshrc"

    local conflicts
    conflicts=$(get_package_conflicts "$TEST_DOTFILES/zsh" "$TEST_HOME")

    assert_contains "$conflicts" "symlink:$TEST_HOME/.zshrc"
}

test_no_conflict_when_correctly_linked() {
    ln -s "$TEST_DOTFILES/zsh/.zshrc" "$TEST_HOME/.zshrc"

    local conflicts
    conflicts=$(get_package_conflicts "$TEST_DOTFILES/zsh" "$TEST_HOME")

    assert "Expected no conflicts, got: $conflicts" test -z "$conflicts"
}

test_no_conflict_when_nothing_exists() {
    local conflicts
    conflicts=$(get_package_conflicts "$TEST_DOTFILES/zsh" "$TEST_HOME")

    assert "Expected no conflicts, got: $conflicts" test -z "$conflicts"
}

test_detects_directory_symlink_conflict() {
    mkdir -p "$TEST_DOTFILES/nvim/.config/nvim"
    touch "$TEST_DOTFILES/nvim/.config/nvim/init.lua"
    mkdir -p "$TEST_HOME/.config"
    ln -s /some/other/path "$TEST_HOME/.config/nvim"

    local conflicts
    conflicts=$(get_package_conflicts "$TEST_DOTFILES/nvim" "$TEST_HOME")

    assert_contains "$conflicts" "symlink:$TEST_HOME/.config/nvim"
}

test_check_all_conflicts_with_empty_packages() {
    # Empty package list should not error
    local result=0
    check_all_conflicts "$TEST_DOTFILES" > /dev/null 2>&1 || result=$?
    assert "Expected check_all_conflicts to succeed with empty packages" test "$result" -eq 0
}

test_get_package_conflicts_with_nonexistent_dir() {
    # Should handle nonexistent package directory gracefully
    local conflicts
    conflicts=$(get_package_conflicts "$TEST_DOTFILES/nonexistent" "$TEST_HOME")
    assert "Expected no conflicts for nonexistent package, got: $conflicts" test -z "$conflicts"
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_detects_file_conflict
run_test test_detects_symlink_conflict
run_test test_no_conflict_when_correctly_linked
run_test test_no_conflict_when_nothing_exists
run_test test_detects_directory_symlink_conflict
run_test test_check_all_conflicts_with_empty_packages
run_test test_get_package_conflicts_with_nonexistent_dir
