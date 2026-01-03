#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Configuration variables for dotfiles
# =============================================================================

SCRIPT_DIR_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging for validation errors
# shellcheck source=lib/log.sh
source "$SCRIPT_DIR_CONFIG/log.sh"

# Directory paths
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

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
    "zsh:$HOME/.zshrc:$HOME/.zshrc"
    "git:$HOME/.gitconfig:$HOME/.gitconfig"
    "git:$HOME/.gitconfig.personal:$HOME/.gitconfig.personal"
    "git:$HOME/.gitignore_global:$HOME/.gitignore_global"
    "nvim:$HOME/.config/nvim:$HOME/.config/nvim/init.lua"
    "ssh:$HOME/.ssh/config:$HOME/.ssh/config"
    "ghostty:$HOME/.config/ghostty:$HOME/.config/ghostty/config"
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
