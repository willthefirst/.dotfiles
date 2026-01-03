#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/fs.sh - File system utilities
# =============================================================================
# Dependencies: log.sh
# Provides: ensure_dir, resolve_link, file_or_link_exists, is_dotfiles_managed,
#           install_to_bin, symlink_matches
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_FS_LOADED:-}" ]] && return 0
_DOTFILES_FS_LOADED=1

# Source dependencies
# shellcheck source=lib/log.sh
source "${BASH_SOURCE%/*}/log.sh"

# Create directory if it doesn't exist
# Usage: ensure_dir <path>
# Returns: 0 on success, 1 on failure
ensure_dir() {
    local path="$1"
    if [[ -d "$path" ]]; then
        return 0
    fi
    if ! mkdir -p "$path"; then
        log_error "Failed to create directory: $path"
        return 1
    fi
}

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
    while [[ "$check_path" != "$DOTFILES_HOME" && "$check_path" != "/" ]]; do
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

# Install file to bin directory, using sudo only if needed
# Usage: install_to_bin "/path/to/source" "name"
# Returns: 0 on success, 1 on failure
# Automatically skips sudo when DOTFILES_BIN_DIR is writable (e.g., in tests)
install_to_bin() {
    local source="$1"
    local name="$2"
    local dest="$DOTFILES_BIN_DIR/$name"

    if [[ -w "$DOTFILES_BIN_DIR" ]]; then
        if ! mv "$source" "$dest"; then
            log_error "Failed to install $name to $DOTFILES_BIN_DIR"
            return 1
        fi
    else
        if ! sudo mv "$source" "$dest"; then
            log_error "Failed to install $name to $DOTFILES_BIN_DIR (sudo)"
            return 1
        fi
    fi
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
