#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Configuration variables for dotfiles
# =============================================================================

# Directory paths
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

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

# Initialize derived arrays from PACKAGE_CONFIG
# Safe to call multiple times - only runs once unless reset
init_config() {
    # Skip if already initialized (idempotent)
    $_CONFIG_INITIALIZED && return 0

    for entry in "${PACKAGE_CONFIG[@]}"; do
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
