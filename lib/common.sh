#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/common.sh - Common utilities facade for dotfiles scripts
# =============================================================================
# Dependencies: log.sh, platform.sh, fs.sh
# Provides: All exports from log.sh, platform.sh, fs.sh, plus print_next_steps
#
# CODING CONVENTIONS
# ==================
# Variables: snake_case with descriptive names
#   - Directory paths: *_dir (e.g., pkg_dir, base_dir)
#   - File/any paths: *_path (e.g., target_path, rel_path)
#   - Boolean flags: descriptive (e.g., force_mode, has_deps)
#   - Arrays: plural names (e.g., packages, files, conflicts)
#
# =============================================================================
# Function Conventions
# =============================================================================
#
# 1. CHECK FUNCTIONS (Predicates)
#    - Names: is_*, has_*, can_*
#    - Behavior: Return 0 (true) or 1 (false)
#    - Logging: NEVER log - let caller decide
#    - Side effects: None
#    - Examples:
#      is_macos()         - returns 0 if on macOS
#      has_command "git"  - returns 0 if git is installed
#      can_write_to "/path" - returns 0 if path is writable
#
# 2. VALIDATION FUNCTIONS (User-facing checks)
#    - Names: require_*, validate_*, check_* (when logging)
#    - Behavior: Return 0 (success) or 1 (failure)
#    - Logging: Log descriptive message on failure
#    - Examples:
#      require_cmd "git"  - logs error and returns 1 if missing
#      validate_config()  - logs errors for each invalid entry
#
# 3. ACTION FUNCTIONS (Do something)
#    - Names: verb_noun (create_backup, deploy_package, install_deps)
#    - Behavior: Perform action, return 0 (success) or 1 (failure)
#    - Logging: Log errors on failure, optionally log progress
#    - Examples:
#      create_backup()    - creates backup, logs error on failure
#      deploy_packages()  - deploys packages, logs progress
#
# 4. GETTER FUNCTIONS (Return data)
#    - Names: get_*
#    - Behavior: Echo result to stdout, return 0/1 for success/failure
#    - Logging: NEVER log to stdout (would corrupt return value)
#    - Examples:
#      get_all_packages() - echoes package list
#      get_platform()     - echoes "macos" or "linux"
#
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_COMMON_LOADED:-}" ]] && return 0
_DOTFILES_COMMON_LOADED=1

# Source dependencies (guards prevent double-loading)
# shellcheck source=lib/log.sh
source "${BASH_SOURCE%/*}/log.sh"
# shellcheck source=lib/platform.sh
source "${BASH_SOURCE%/*}/platform.sh"
# shellcheck source=lib/fs.sh
source "${BASH_SOURCE%/*}/fs.sh"

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
