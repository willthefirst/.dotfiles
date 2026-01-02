#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Common utilities for dotfiles scripts
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if a command exists
require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd is not installed."
        if [[ -n "$install_hint" ]]; then
            echo "$install_hint"
        fi
        return 1
    fi
    return 0
}

# Platform detection
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# Print section header
print_header() {
    echo "=============================================="
    echo " Dotfiles Installation"
    echo "=============================================="
    echo ""
}

# Print next steps after installation
print_next_steps() {
    echo ""
    echo "Next steps:"
    echo "  1. source ~/.zshrc"
    echo "  2. git config user.email"
    echo "  3. ssh -T git@github.com"
    echo ""
}

# =============================================================================
# File system helpers
# =============================================================================

# Check if a file or symlink exists (handles broken symlinks correctly)
# Usage: file_or_link_exists "/path/to/file"
# Returns 0 if exists, 1 if not
file_or_link_exists() {
    [[ -e "$1" || -L "$1" ]]
}

# Check if a path is managed by stow (symlink points into DOTFILES_DIR)
# Usage: is_dotfiles_managed "/path/to/file"
# Returns 0 if managed, 1 if not
is_dotfiles_managed() {
    local path="$1"
    local check_path="$path"
    local dotfiles_resolved
    dotfiles_resolved=$(readlink -f "$DOTFILES_DIR" 2>/dev/null || echo "$DOTFILES_DIR")

    # Check if the path itself or any parent is a symlink into dotfiles
    while [[ "$check_path" != "$HOME" && "$check_path" != "/" ]]; do
        if [[ -L "$check_path" ]]; then
            local target
            target=$(readlink -f "$check_path" 2>/dev/null || echo "")
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
    actual=$(readlink -f "$link_path" 2>/dev/null || echo "")
    local expected_resolved
    expected_resolved=$(readlink -f "$expected" 2>/dev/null || echo "$expected")
    [[ "$actual" == "$expected_resolved" ]]
}
