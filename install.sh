#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Dotfiles Installation Script
# =============================================================================
# Deploys dotfiles using GNU Stow. Run this after cloning the repository.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source modules
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/cli.sh
source "$SCRIPT_DIR/lib/cli.sh"
# shellcheck source=lib/conflicts.sh
source "$SCRIPT_DIR/lib/conflicts.sh"
# shellcheck source=lib/backup.sh
source "$SCRIPT_DIR/lib/backup.sh"
# shellcheck source=lib/deploy.sh
source "$SCRIPT_DIR/lib/deploy.sh"
# shellcheck source=lib/verify.sh
source "$SCRIPT_DIR/lib/verify.sh"
# shellcheck source=lib/validate.sh
source "$SCRIPT_DIR/lib/validate.sh"
# shellcheck source=lib/pkg-manager.sh
source "$SCRIPT_DIR/lib/pkg-manager.sh"
# shellcheck source=lib/deps.sh
source "$SCRIPT_DIR/lib/deps.sh"

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
