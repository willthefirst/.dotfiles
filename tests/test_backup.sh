#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for backup logic
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"
init_test_env backup

# Override default setup to create dotfiles structure
setup() { setup_test_env true; }

# =============================================================================
# Test functions - each returns 0 for pass, non-zero for fail
# =============================================================================

test_needs_backup_returns_true_for_regular_file() {
    touch "$TEST_HOME/.zshrc"
    assert "Expected needs_backup to return true for regular file" needs_backup "$TEST_HOME/.zshrc"
}

test_needs_backup_returns_false_for_stow_managed() {
    mkdir -p "$DOTFILES_DIR/zsh"
    touch "$DOTFILES_DIR/zsh/.zshrc"
    ln -s "$DOTFILES_DIR/zsh/.zshrc" "$TEST_HOME/.zshrc"

    assert_fails "Expected needs_backup to return false for stow-managed symlink" needs_backup "$TEST_HOME/.zshrc"
}

test_needs_backup_returns_false_when_nothing_exists() {
    assert_fails "Expected needs_backup to return false for non-existent file" needs_backup "$TEST_HOME/.nonexistent"
}

test_needs_backup_returns_true_for_external_symlink() {
    ln -s /some/other/path "$TEST_HOME/.zshrc"
    assert "Expected needs_backup to return true for external symlink" needs_backup "$TEST_HOME/.zshrc"
}

test_create_backup_creates_directory() {
    echo "test content" > "$TEST_HOME/.zshrc"

    create_backup "$TEST_HOME/.zshrc" > /dev/null 2>&1

    local backup_dir
    backup_dir=$(find "$TEST_HOME" -maxdepth 1 -type d -name "${BACKUP_PREFIX}*" 2>/dev/null | head -1)

    assert "Expected backup directory with .zshrc file" test -n "$backup_dir" -a -f "$backup_dir/.zshrc"
}

test_create_backup_handles_broken_symlinks() {
    mkdir -p "$TEST_HOME/.config/testdir"
    echo "valid content" > "$TEST_HOME/.config/testdir/valid.txt"
    ln -s "/nonexistent/path/file.txt" "$TEST_HOME/.config/testdir/broken_link"

    create_backup "$TEST_HOME/.config/testdir" > /dev/null 2>&1 || {
        echo "  create_backup failed on directory with broken symlink"
        return 1
    }

    local backup_dir
    backup_dir=$(find "$TEST_HOME" -maxdepth 1 -type d -name "${BACKUP_PREFIX}*" 2>/dev/null | head -1)

    assert "Backup succeeded but directory not found" test -n "$backup_dir" -a -d "$backup_dir/testdir"
}

# =============================================================================
# Run all tests
# =============================================================================
run_all_tests
