#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Configuration variables for dotfiles
# =============================================================================

SCRIPT_DIR_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging for validation errors
# shellcheck source=lib/log.sh
source "$SCRIPT_DIR_CONFIG/log.sh"

# =============================================================================
# Configurable Paths
# =============================================================================
# These paths can be overridden by setting environment variables before
# sourcing this file. This is useful for:
#   - Testing (redirect to isolated temp directories)
#   - Custom installations (different target paths)
#   - Containerized environments
#
# Example (for testing):
#   export DOTFILES_HOME=/tmp/test-home
#   source lib/config.sh
# =============================================================================

# Base directories
: "${DOTFILES_HOME:=$HOME}"
: "${DOTFILES_CONFIG_DIR:=$DOTFILES_HOME/.config}"
: "${DOTFILES_SSH_DIR:=$DOTFILES_HOME/.ssh}"

# Install directories
: "${DOTFILES_BIN_DIR:=/usr/local/bin}"
: "${DOTFILES_TEMP_DIR:=/tmp}"

# Backup settings
: "${DOTFILES_BACKUP_DIR:=$DOTFILES_HOME}"

# Export for subshells
export DOTFILES_HOME DOTFILES_CONFIG_DIR DOTFILES_SSH_DIR
export DOTFILES_BIN_DIR DOTFILES_TEMP_DIR DOTFILES_BACKUP_DIR

# Directory paths
DOTFILES_DIR="${DOTFILES_DIR:-$DOTFILES_HOME/.dotfiles}"

# Backup configuration
# shellcheck disable=SC2034
BACKUP_PREFIX=".dotfiles-backup-"
# shellcheck disable=SC2034
BACKUP_RETENTION_DAYS=7

# =============================================================================
# Package Configuration
# Single source of truth: package -> backup_path -> verify_path
# Format: "package:backup_path:verify_path"
# =============================================================================
PACKAGE_CONFIG=(
    "zsh:$DOTFILES_HOME/.zshrc:$DOTFILES_HOME/.zshrc"
    "git:$DOTFILES_HOME/.gitconfig:$DOTFILES_HOME/.gitconfig"
    "git:$DOTFILES_HOME/.gitconfig.personal:$DOTFILES_HOME/.gitconfig.personal"
    "git:$DOTFILES_HOME/.gitignore_global:$DOTFILES_HOME/.gitignore_global"
    "nvim:$DOTFILES_CONFIG_DIR/nvim:$DOTFILES_CONFIG_DIR/nvim/init.lua"
    "ssh:$DOTFILES_SSH_DIR/config:$DOTFILES_SSH_DIR/config"
    "ghostty:$DOTFILES_CONFIG_DIR/ghostty:$DOTFILES_CONFIG_DIR/ghostty/config"
)

# Derived arrays (populated by init_config)
# shellcheck disable=SC2034
PACKAGES=()
# shellcheck disable=SC2034
BACKUP_FILES=()
# shellcheck disable=SC2034
VERIFY_SYMLINKS=()

# Track initialization state (ensures idempotent behavior)
_CONFIG_INITIALIZED=false

# Validate a single PACKAGE_CONFIG entry
# Usage: validate_config_entry "pkg:backup:verify"
# Returns: 0 if valid, 1 if invalid (with error message)
validate_config_entry() {
    local entry="$1"

    # Check format: must have exactly 3 colon-separated fields
    local colon_count
    colon_count=$(echo "$entry" | tr -cd ':' | wc -c | tr -d ' ')
    if [[ "$colon_count" -ne 2 ]]; then
        log_error "Invalid config entry (expected pkg:backup:verify): $entry"
        return 1
    fi

    local pkg="${entry%%:*}"
    local rest="${entry#*:}"
    local backup="${rest%%:*}"
    local verify="${rest#*:}"

    # Validate each field is non-empty
    if [[ -z "$pkg" ]]; then
        log_error "Invalid config entry (empty package name): $entry"
        return 1
    fi
    if [[ -z "$backup" ]]; then
        log_error "Invalid config entry (empty backup path): $entry"
        return 1
    fi
    if [[ -z "$verify" ]]; then
        log_error "Invalid config entry (empty verify path): $entry"
        return 1
    fi

    return 0
}

# Initialize derived arrays from PACKAGE_CONFIG
# Safe to call multiple times - only runs once unless reset
init_config() {
    # Skip if already initialized (idempotent)
    $_CONFIG_INITIALIZED && return 0

    for entry in "${PACKAGE_CONFIG[@]}"; do
        # Validate entry format
        if ! validate_config_entry "$entry"; then
            return 1
        fi

        local pkg="${entry%%:*}"
        local rest="${entry#*:}"
        local backup="${rest%%:*}"
        local verify="${rest#*:}"

        # Add package if not already in PACKAGES array
        if [[ " ${PACKAGES[*]} " != *" $pkg "* ]]; then
            PACKAGES+=("$pkg")
        fi

        BACKUP_FILES+=("$backup")
        VERIFY_SYMLINKS+=("$verify")
    done

    _CONFIG_INITIALIZED=true
}

# Auto-initialize when sourced
init_config

# =============================================================================
# Package Resolution
# =============================================================================

# Check if a package name is valid (exists in PACKAGES array)
# Usage: is_valid_package "package_name"
# Returns: 0 if valid, 1 if invalid
is_valid_package() {
    local pkg="$1"
    [[ " ${PACKAGES[*]} " == *" $pkg "* ]]
}

# Resolve package list: use specified packages or all if none specified
# Usage: resolve_packages [package...]
# Output: Space-separated list of valid package names
resolve_packages() {
    local requested=("$@")

    if [[ ${#requested[@]} -eq 0 ]]; then
        # No packages specified - return all
        echo "${PACKAGES[*]}"
    else
        # Validate and return requested packages
        local valid_packages=()
        for pkg in "${requested[@]}"; do
            if is_valid_package "$pkg"; then
                valid_packages+=("$pkg")
            else
                log_warn "Unknown package: $pkg (skipping)"
            fi
        done
        echo "${valid_packages[*]}"
    fi
}
