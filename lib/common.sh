#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Common utilities for dotfiles scripts
# =============================================================================
# This module sources focused utility modules and provides additional helpers.
# Source this file to get all common utilities.
#
# CODING CONVENTIONS
# ==================
# Variables: snake_case with descriptive names
#   - Directory paths: *_dir (e.g., pkg_dir, base_dir)
#   - File/any paths: *_path (e.g., target_path, rel_path)
#   - Boolean flags: descriptive (e.g., force_mode, has_deps)
#   - Arrays: plural names (e.g., packages, files, conflicts)
# Functions: snake_case with verb prefixes
#   - Check functions: is_*, has_*, check_* (return 0/1, no logging)
#   - Action functions: verb_noun (e.g., create_backup, deploy_packages)
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

# Print next steps after installation
print_next_steps() {
    echo ""
    log_info "Next steps:"
    log_info "  1. source ~/.zshrc"
    log_info "  2. git config user.email"
    log_info "  3. ssh -T git@github.com"
    echo ""
}
