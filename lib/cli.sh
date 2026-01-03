#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/cli.sh - CLI argument parsing for install.sh
# =============================================================================
# Dependencies: log.sh
# Provides: parse_install_args, show_install_help, INSTALL_* variables
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_CLI_LOADED:-}" ]] && return 0
_DOTFILES_CLI_LOADED=1

# Source dependencies
# shellcheck source=lib/log.sh
source "${BASH_SOURCE%/*}/log.sh"

# =============================================================================
# Install configuration variables (set by parse_install_args)
# Used by install.sh after sourcing this module
# =============================================================================
# shellcheck disable=SC2034
INSTALL_FORCE=false
# shellcheck disable=SC2034
INSTALL_ADOPT=false
# shellcheck disable=SC2034
INSTALL_DEPS_ONLY=false
# shellcheck disable=SC2034
INSTALL_WITH_DEPS=false
# shellcheck disable=SC2034
INSTALL_PACKAGES=()

# =============================================================================
# Help display
# =============================================================================

# Display help text for install.sh
# Usage: show_install_help
show_install_help() {
    cat << 'EOF'
Usage: ./install.sh [OPTIONS] [PACKAGES...]

Options:
    -h, --help      Show this help message
    -f, --force     Remove conflicting symlinks before stowing
    -a, --adopt     Adopt existing files into stow packages
    --deps-only     Install dependencies only (no stow)
    --with-deps     Install dependencies before stowing

Packages:
    zsh             Zsh configuration
    git             Git configuration and tools
    nvim            Neovim configuration
    ssh             SSH configuration
    ghostty         Ghostty terminal configuration

Examples:
    ./install.sh                    # Stow all packages
    ./install.sh nvim git           # Stow specific packages
    ./install.sh --with-deps        # Install deps + stow all
    ./install.sh --deps-only nvim   # Install deps for nvim only
    ./install.sh --force --with-deps nvim git
EOF
}

# =============================================================================
# Argument parsing
# =============================================================================

# Parse command line arguments into INSTALL_* variables
# Usage: parse_install_args "$@"
# Sets: INSTALL_FORCE, INSTALL_ADOPT, INSTALL_DEPS_ONLY, INSTALL_WITH_DEPS, INSTALL_PACKAGES
# shellcheck disable=SC2034
parse_install_args() {
    # Reset to defaults (allows re-parsing in tests)
    INSTALL_FORCE=false
    INSTALL_ADOPT=false
    INSTALL_DEPS_ONLY=false
    INSTALL_WITH_DEPS=false
    INSTALL_PACKAGES=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_install_help
                exit 0
                ;;
            -f|--force)
                INSTALL_FORCE=true
                shift
                ;;
            -a|--adopt)
                INSTALL_ADOPT=true
                shift
                ;;
            --deps-only)
                INSTALL_DEPS_ONLY=true
                shift
                ;;
            --with-deps)
                INSTALL_WITH_DEPS=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                log_info "Run './install.sh --help' for usage"
                exit 1
                ;;
            *)
                INSTALL_PACKAGES+=("$1")
                shift
                ;;
        esac
    done

    # Validate mutually exclusive options
    if [[ "$INSTALL_DEPS_ONLY" == "true" && "$INSTALL_WITH_DEPS" == "true" ]]; then
        log_error "--deps-only and --with-deps are mutually exclusive"
        exit 1
    fi
}
