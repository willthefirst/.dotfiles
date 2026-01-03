#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/pkg-manager.sh - Package manager abstraction
# =============================================================================
# Dependencies: log.sh, platform.sh
# Provides: pkg_install, pkg_installed
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_PKG_MANAGER_LOADED:-}" ]] && return 0
_DOTFILES_PKG_MANAGER_LOADED=1

# Source dependencies
# shellcheck source=lib/log.sh
source "${BASH_SOURCE%/*}/log.sh"
# shellcheck source=lib/platform.sh
source "${BASH_SOURCE%/*}/platform.sh"

# Install packages using the system package manager
# Usage: pkg_install <packages...>
# Note: On macOS, packages starting with "--cask" are installed as casks
pkg_install() {
    local packages=("$@")
    [[ ${#packages[@]} -eq 0 ]] && return 0

    if is_macos; then
        local regular_pkgs=()
        local cask_pkgs=()
        local is_cask=false

        for pkg in "${packages[@]}"; do
            if [[ "$pkg" == "--cask" ]]; then
                is_cask=true
                continue
            fi
            if $is_cask; then
                cask_pkgs+=("$pkg")
                is_cask=false
            else
                regular_pkgs+=("$pkg")
            fi
        done

        [[ ${#regular_pkgs[@]} -gt 0 ]] && brew install "${regular_pkgs[@]}"
        [[ ${#cask_pkgs[@]} -gt 0 ]] && brew install --cask "${cask_pkgs[@]}"
        return 0
    elif is_linux; then
        sudo apt update
        sudo apt install -y "${packages[@]}"
    else
        log_error "Unsupported platform: $(uname -s)"
        return 1
    fi
}

# Check if a package is installed via the system package manager
# Usage: pkg_installed <package>
# Returns 0 if installed, 1 if not
pkg_installed() {
    local pkg="$1"

    if is_macos; then
        brew list "$pkg" &>/dev/null || brew list --cask "$pkg" &>/dev/null
    elif is_linux; then
        dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"
    else
        return 1
    fi
}
