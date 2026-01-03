#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/platform.sh - Platform detection utilities
# =============================================================================
# Dependencies: none
# Provides: is_macos, is_linux
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_PLATFORM_LOADED:-}" ]] && return 0
_DOTFILES_PLATFORM_LOADED=1

is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}
