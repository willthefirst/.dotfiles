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

# Test variables
TEST_HOME=""
TEST_DOTFILES=""

setup() {
    TEST_HOME=$(mktemp -d)
    TEST_DOTFILES=$(mktemp -d)

    # Create mock package structure
    mkdir -p "$TEST_DOTFILES/zsh"
    touch "$TEST_DOTFILES/zsh/.zshrc"
}

teardown() {
    rm -rf "$TEST_HOME" "$TEST_DOTFILES"
}

test_detects_file_conflict() {
    setup

    # Create conflicting file
    touch "$TEST_HOME/.zshrc"

    # Run conflict detection
    local conflicts
    conflicts=$(get_package_conflicts "$TEST_DOTFILES/zsh" "$TEST_HOME")

    # Assert
    if [[ "$conflicts" == *"file:$TEST_HOME/.zshrc"* ]]; then
        echo "PASS: test_detects_file_conflict"
    else
        echo "FAIL: test_detects_file_conflict"
        echo "  Expected conflict for $TEST_HOME/.zshrc"
        echo "  Got: $conflicts"
    fi

    teardown
}

test_detects_symlink_conflict() {
    setup

    # Create conflicting symlink pointing elsewhere
    ln -s /some/other/path "$TEST_HOME/.zshrc"

    local conflicts
    conflicts=$(get_package_conflicts "$TEST_DOTFILES/zsh" "$TEST_HOME")

    if [[ "$conflicts" == *"symlink:$TEST_HOME/.zshrc"* ]]; then
        echo "PASS: test_detects_symlink_conflict"
    else
        echo "FAIL: test_detects_symlink_conflict"
        echo "  Expected symlink conflict"
        echo "  Got: $conflicts"
    fi

    teardown
}

test_no_conflict_when_correctly_linked() {
    setup

    # Create correct symlink
    ln -s "$TEST_DOTFILES/zsh/.zshrc" "$TEST_HOME/.zshrc"

    local conflicts
    conflicts=$(get_package_conflicts "$TEST_DOTFILES/zsh" "$TEST_HOME")

    if [[ -z "$conflicts" ]]; then
        echo "PASS: test_no_conflict_when_correctly_linked"
    else
        echo "FAIL: test_no_conflict_when_correctly_linked"
        echo "  Expected no conflicts, got: $conflicts"
    fi

    teardown
}

test_no_conflict_when_nothing_exists() {
    setup

    # No file or symlink exists
    local conflicts
    conflicts=$(get_package_conflicts "$TEST_DOTFILES/zsh" "$TEST_HOME")

    if [[ -z "$conflicts" ]]; then
        echo "PASS: test_no_conflict_when_nothing_exists"
    else
        echo "FAIL: test_no_conflict_when_nothing_exists"
        echo "  Expected no conflicts, got: $conflicts"
    fi

    teardown
}

test_detects_directory_symlink_conflict() {
    setup

    # Create a nested package structure
    mkdir -p "$TEST_DOTFILES/nvim/.config/nvim"
    touch "$TEST_DOTFILES/nvim/.config/nvim/init.lua"
    mkdir -p "$TEST_HOME/.config"

    # Create conflicting symlink at .config/nvim pointing elsewhere
    ln -s /some/other/path "$TEST_HOME/.config/nvim"

    local conflicts
    conflicts=$(get_package_conflicts "$TEST_DOTFILES/nvim" "$TEST_HOME")

    if [[ "$conflicts" == *"symlink:$TEST_HOME/.config/nvim"* ]]; then
        echo "PASS: test_detects_directory_symlink_conflict"
    else
        echo "FAIL: test_detects_directory_symlink_conflict"
        echo "  Expected directory symlink conflict"
        echo "  Got: $conflicts"
    fi

    teardown
}

# Run all tests
test_detects_file_conflict
test_detects_symlink_conflict
test_no_conflict_when_correctly_linked
test_no_conflict_when_nothing_exists
test_detects_directory_symlink_conflict
