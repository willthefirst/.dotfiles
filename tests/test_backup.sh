#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for backup logic
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source required modules
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/backup.sh"

# Test variables
TEST_HOME=""
ORIGINAL_HOME=""
ORIGINAL_DOTFILES_DIR=""

setup() {
    TEST_HOME=$(mktemp -d)
    ORIGINAL_HOME="$HOME"
    ORIGINAL_DOTFILES_DIR="$DOTFILES_DIR"

    # Override HOME and DOTFILES_DIR for testing
    HOME="$TEST_HOME"
    DOTFILES_DIR="$TEST_HOME/.dotfiles"
    mkdir -p "$DOTFILES_DIR"
}

teardown() {
    HOME="$ORIGINAL_HOME"
    DOTFILES_DIR="$ORIGINAL_DOTFILES_DIR"
    rm -rf "$TEST_HOME"
}

test_needs_backup_returns_true_for_regular_file() {
    setup

    # Create a regular file
    touch "$TEST_HOME/.zshrc"

    if needs_backup "$TEST_HOME/.zshrc"; then
        echo "PASS: test_needs_backup_returns_true_for_regular_file"
    else
        echo "FAIL: test_needs_backup_returns_true_for_regular_file"
        echo "  Expected needs_backup to return true for regular file"
    fi

    teardown
}

test_needs_backup_returns_false_for_stow_managed() {
    setup

    # Create a symlink pointing into DOTFILES_DIR
    mkdir -p "$DOTFILES_DIR/zsh"
    touch "$DOTFILES_DIR/zsh/.zshrc"
    ln -s "$DOTFILES_DIR/zsh/.zshrc" "$TEST_HOME/.zshrc"

    if ! needs_backup "$TEST_HOME/.zshrc"; then
        echo "PASS: test_needs_backup_returns_false_for_stow_managed"
    else
        echo "FAIL: test_needs_backup_returns_false_for_stow_managed"
        echo "  Expected needs_backup to return false for stow-managed symlink"
    fi

    teardown
}

test_needs_backup_returns_false_when_nothing_exists() {
    setup

    if ! needs_backup "$TEST_HOME/.nonexistent"; then
        echo "PASS: test_needs_backup_returns_false_when_nothing_exists"
    else
        echo "FAIL: test_needs_backup_returns_false_when_nothing_exists"
        echo "  Expected needs_backup to return false for non-existent file"
    fi

    teardown
}

test_needs_backup_returns_true_for_external_symlink() {
    setup

    # Create a symlink pointing outside DOTFILES_DIR
    ln -s /some/other/path "$TEST_HOME/.zshrc"

    if needs_backup "$TEST_HOME/.zshrc"; then
        echo "PASS: test_needs_backup_returns_true_for_external_symlink"
    else
        echo "FAIL: test_needs_backup_returns_true_for_external_symlink"
        echo "  Expected needs_backup to return true for external symlink"
    fi

    teardown
}

test_create_backup_creates_directory() {
    setup

    # Create a file to backup
    touch "$TEST_HOME/.zshrc"
    echo "test content" > "$TEST_HOME/.zshrc"

    # Capture output to find backup directory
    output=$(create_backup "$TEST_HOME/.zshrc" 2>&1)

    # Check that a backup directory was created
    backup_dir=$(find "$TEST_HOME" -maxdepth 1 -type d -name ".dotfiles-backup-*" 2>/dev/null | head -1)

    if [[ -n "$backup_dir" && -f "$backup_dir/.zshrc" ]]; then
        echo "PASS: test_create_backup_creates_directory"
    else
        echo "FAIL: test_create_backup_creates_directory"
        echo "  Expected backup directory with .zshrc file"
        echo "  Backup dir: $backup_dir"
    fi

    teardown
}

# Run all tests
test_needs_backup_returns_true_for_regular_file
test_needs_backup_returns_false_for_stow_managed
test_needs_backup_returns_false_when_nothing_exists
test_needs_backup_returns_true_for_external_symlink
test_create_backup_creates_directory
