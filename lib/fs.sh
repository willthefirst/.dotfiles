#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# File system utilities
# =============================================================================

# Resolve a path to its absolute target (follows symlinks)
# Usage: resolve_link "/path/to/link"
# Outputs: resolved path, or original path if resolution fails
resolve_link() {
    readlink -f "$1" 2>/dev/null || echo "$1"
}

# Check if a file or symlink exists (handles broken symlinks correctly)
# Usage: file_or_link_exists "/path/to/file"
# Returns 0 if exists, 1 if not
file_or_link_exists() {
    [[ -e "$1" || -L "$1" ]]
}

# Check if a path is managed by stow (symlink points into DOTFILES_DIR)
# Usage: is_dotfiles_managed "/path/to/file"
# Returns 0 if managed, 1 if not
# Note: Requires DOTFILES_DIR to be set
is_dotfiles_managed() {
    local path="$1"
    local check_path="$path"
    local dotfiles_resolved
    dotfiles_resolved=$(resolve_link "$DOTFILES_DIR")

    # Check if the path itself or any parent is a symlink into dotfiles
    while [[ "$check_path" != "$HOME" && "$check_path" != "/" ]]; do
        if [[ -L "$check_path" ]]; then
            local target
            target=$(resolve_link "$check_path")
            if [[ "$target" == *"$dotfiles_resolved"* ]]; then
                return 0
            fi
        fi
        check_path=$(dirname "$check_path")
    done
    return 1
}

# Resolve symlink and check if it points to expected target
# Usage: symlink_matches "/path/to/link" "/expected/target"
# Returns 0 if matches, 1 if not
symlink_matches() {
    local link_path="$1"
    local expected="$2"
    local actual
    actual=$(resolve_link "$link_path")
    local expected_resolved
    expected_resolved=$(resolve_link "$expected")
    [[ "$actual" == "$expected_resolved" ]]
}
