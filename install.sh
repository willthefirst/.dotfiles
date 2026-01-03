#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Dotfiles Installation Script
# =============================================================================
# Deploys dotfiles using GNU Stow. Run this after cloning the repository.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all library modules via central initialization
# shellcheck source=lib/init.sh
source "$SCRIPT_DIR/lib/init.sh"

# Main workflow
main() {
    # Resolve target packages
    local target_packages
    read -ra target_packages <<< "$(resolve_packages "${INSTALL_PACKAGES[@]}")"

    # Deps-only mode: just install dependencies and exit
    if [[ "$INSTALL_DEPS_ONLY" == "true" ]]; then
        install_all_deps "${target_packages[@]}"
        return
    fi

    # Full setup mode: install dependencies then configure
    if [[ "$INSTALL_WITH_DEPS" == "true" ]]; then
        SETUP_PHASE="1/2"
        install_all_deps "${target_packages[@]}"
        # shellcheck disable=SC2034  # SETUP_PHASE is used by log_section in log.sh
        SETUP_PHASE="2/2"
    fi

    # Stow workflow
    log_section "Configuring dotfiles..."
    check_prerequisites
    if [[ "$INSTALL_FORCE" == "true" ]]; then
        create_backup --skip "${BACKUP_FILES[@]}"
    else
        create_backup "${BACKUP_FILES[@]}"
    fi
    create_directories
    deploy_base "$INSTALL_FORCE" "$INSTALL_ADOPT"
    verify_installation
    print_next_steps
}

parse_install_args "$@"
main
