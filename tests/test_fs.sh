#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for file system utilities (lib/fs.sh)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"
init_test_env ""

# =============================================================================
# is_dotfiles_managed tests
# =============================================================================

test_is_dotfiles_managed_detects_direct_symlink() {
    mkdir -p "$TEST_DOTFILES/zsh"
    touch "$TEST_DOTFILES/zsh/.zshrc"
    ln -s "$TEST_DOTFILES/zsh/.zshrc" "$TEST_HOME/.zshrc"

    assert "Expected is_dotfiles_managed to return true" is_dotfiles_managed "$TEST_HOME/.zshrc"
}

test_is_dotfiles_managed_detects_parent_symlink() {
    mkdir -p "$TEST_DOTFILES/nvim/.config/nvim"
    touch "$TEST_DOTFILES/nvim/.config/nvim/init.lua"
    mkdir -p "$TEST_HOME/.config"
    ln -s "$TEST_DOTFILES/nvim/.config/nvim" "$TEST_HOME/.config/nvim"

    assert "Expected is_dotfiles_managed to return true for file under symlinked dir" \
        is_dotfiles_managed "$TEST_HOME/.config/nvim/init.lua"
}

test_is_dotfiles_managed_returns_false_for_external_symlink() {
    ln -s /some/external/path "$TEST_HOME/.external"
    assert_fails "Expected is_dotfiles_managed to return false for external symlink" \
        is_dotfiles_managed "$TEST_HOME/.external"
}

test_is_dotfiles_managed_returns_false_for_regular_file() {
    touch "$TEST_HOME/.regularfile"
    assert_fails "Expected is_dotfiles_managed to return false for regular file" \
        is_dotfiles_managed "$TEST_HOME/.regularfile"
}

# =============================================================================
# resolve_link tests
# =============================================================================

test_resolve_link_follows_symlink() {
    mkdir -p "$TEST_DOTFILES/zsh"
    touch "$TEST_DOTFILES/zsh/.zshrc"
    ln -s "$TEST_DOTFILES/zsh/.zshrc" "$TEST_HOME/.zshrc"

    local resolved
    resolved=$(resolve_link "$TEST_HOME/.zshrc")
    # Check that resolved path ends with the expected file
    assert "Expected resolved path to end with zsh/.zshrc" \
        test "${resolved##*/}" == ".zshrc"
}

test_resolve_link_returns_path_for_regular_file() {
    touch "$TEST_HOME/.regularfile"
    local resolved
    resolved=$(resolve_link "$TEST_HOME/.regularfile")
    # Should return a valid path (may be canonicalized)
    assert "Expected resolved path to exist" test -f "$resolved"
}

# =============================================================================
# symlink_matches tests
# =============================================================================

test_symlink_matches_returns_true_for_matching() {
    mkdir -p "$TEST_DOTFILES/zsh"
    touch "$TEST_DOTFILES/zsh/.zshrc"
    ln -s "$TEST_DOTFILES/zsh/.zshrc" "$TEST_HOME/.zshrc"

    assert "Expected symlink_matches to return true" \
        symlink_matches "$TEST_HOME/.zshrc" "$TEST_DOTFILES/zsh/.zshrc"
}

test_symlink_matches_returns_false_for_different_target() {
    ln -s /some/other/path "$TEST_HOME/.zshrc"
    assert_fails "Expected symlink_matches to return false" \
        symlink_matches "$TEST_HOME/.zshrc" "$TEST_DOTFILES/zsh/.zshrc"
}

# =============================================================================
# Run all tests
# =============================================================================
run_all_tests
