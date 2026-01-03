#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Common utilities for dotfiles scripts
# =============================================================================
# This module sources focused utility modules and provides additional helpers.
# Source this file to get all common utilities.
# =============================================================================

SCRIPT_DIR_COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source focused modules
# shellcheck source=lib/log.sh
source "$SCRIPT_DIR_COMMON/log.sh"
# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR_COMMON/platform.sh"
# shellcheck source=lib/fs.sh
source "$SCRIPT_DIR_COMMON/fs.sh"

# =============================================================================
# Additional utilities
# =============================================================================

# Check if a command exists
require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd is not installed."
        if [[ -n "$install_hint" ]]; then
            log_info "$install_hint"
        fi
        return 1
    fi
    return 0
}

# Print next steps after installation
print_next_steps() {
    echo ""
    log_info "Next steps:"
    log_info "  1. source ~/.zshrc"
    log_info "  2. git config user.email"
    log_info "  3. ssh -T git@github.com"
    echo ""
}
