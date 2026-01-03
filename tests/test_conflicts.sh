#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for conflict detection
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"
init_test_env conflicts

# Custom setup to create mock zsh package
setup() {
    setup_test_env
    create_mock_package "zsh" ".zshrc"
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
# Conflict string helper tests (no setup/teardown needed)
# =============================================================================

test_make_file_conflict() {
    local result
    result=$(make_file_conflict "/path/to/file")
    assert "Expected file:/path/to/file" test "$result" == "file:/path/to/file"
}

test_make_symlink_conflict() {
    local result
    result=$(make_symlink_conflict "/path/to/link" "/target")
    assert "Expected symlink:/path/to/link:/target" test "$result" == "symlink:/path/to/link:/target"
}

test_parse_conflict_type_file() {
    local result
    result=$(parse_conflict_type "file:/path/to/file")
    assert "Expected 'file'" test "$result" == "file"
}

test_parse_conflict_type_symlink() {
    local result
    result=$(parse_conflict_type "symlink:/path:/target")
    assert "Expected 'symlink'" test "$result" == "symlink"
}

test_parse_conflict_type_with_pkg_prefix() {
    local result
    result=$(parse_conflict_type "zsh:file:/path/to/file")
    assert "Expected 'file' with pkg prefix" test "$result" == "file"
}

test_parse_conflict_path_file() {
    local result
    result=$(parse_conflict_path "file:/path/to/file")
    assert "Expected '/path/to/file'" test "$result" == "/path/to/file"
}

test_parse_conflict_path_symlink() {
    local result
    result=$(parse_conflict_path "symlink:/path/to/link:/target")
    assert "Expected '/path/to/link'" test "$result" == "/path/to/link"
}

test_parse_conflict_path_with_pkg_prefix() {
    local result
    result=$(parse_conflict_path "zsh:file:/home/user/.zshrc")
    assert "Expected '/home/user/.zshrc' with pkg prefix" test "$result" == "/home/user/.zshrc"
}

test_parse_conflict_target_symlink() {
    local result
    result=$(parse_conflict_target "symlink:/path:/target/path")
    assert "Expected '/target/path'" test "$result" == "/target/path"
}

test_parse_conflict_target_file_returns_empty() {
    local result
    result=$(parse_conflict_target "file:/path/to/file")
    assert "Expected empty for file conflict" test -z "$result"
}

# =============================================================================
# Run all tests
# =============================================================================
run_all_tests
