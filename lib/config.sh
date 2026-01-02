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

# Initialize derived arrays from PACKAGE_CONFIG
# Call this after sourcing config.sh
init_config() {
    local seen_packages=()

    for entry in "${PACKAGE_CONFIG[@]}"; do
        local pkg="${entry%%:*}"
        local rest="${entry#*:}"
        local backup="${rest%%:*}"
        local verify="${rest#*:}"

        # Add package if not seen
        local found=false
        for seen in "${seen_packages[@]}"; do
            if [[ "$seen" == "$pkg" ]]; then
                found=true
                break
            fi
        done
        if ! $found; then
            PACKAGES+=("$pkg")
            seen_packages+=("$pkg")
        fi

        # Add backup and verify paths
        BACKUP_FILES+=("$backup")
        VERIFY_SYMLINKS+=("$verify")
    done
}

# Auto-initialize when sourced
init_config
