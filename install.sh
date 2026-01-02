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
# shellcheck source=lib/conflicts.sh
source "$SCRIPT_DIR/lib/conflicts.sh"
# shellcheck source=lib/backup.sh
source "$SCRIPT_DIR/lib/backup.sh"
# shellcheck source=lib/deploy.sh
source "$SCRIPT_DIR/lib/deploy.sh"
# shellcheck source=lib/verify.sh
source "$SCRIPT_DIR/lib/verify.sh"
# shellcheck source=lib/deps.sh
source "$SCRIPT_DIR/lib/deps.sh"

# CLI flags
FORCE_MODE=false
ADOPT_MODE=false
DEPS_ONLY=false
WITH_DEPS=false
SELECTED_PACKAGES=()

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    --force)
      FORCE_MODE=true
      shift
      ;;
    --adopt)
      ADOPT_MODE=true
      shift
      ;;
    --deps-only)
      DEPS_ONLY=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --help | -h)
      echo "Usage: ./install.sh [OPTIONS] [PACKAGES...]"
      echo ""
      echo "Options:"
      echo "  --force      Remove conflicting symlinks before stowing"
      echo "  --adopt      Adopt existing files into stow packages"
      echo "  --deps-only  Install dependencies only (no stow)"
      echo "  --with-deps  Install dependencies before stowing"
      echo "  --help       Show this help message"
      echo ""
      echo "Examples:"
      echo "  ./install.sh                    # Stow all packages"
      echo "  ./install.sh --with-deps        # Install deps + stow all"
      echo "  ./install.sh --deps-only nvim   # Install deps for nvim only"
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Run './install.sh --help' for usage"
      exit 1
      ;;
    *)
      # Positional argument = package name
      SELECTED_PACKAGES+=("$1")
      shift
      ;;
    esac
  done
}

# Get packages to operate on (selected or all)
get_target_packages() {
  if [[ ${#SELECTED_PACKAGES[@]} -gt 0 ]]; then
    echo "${SELECTED_PACKAGES[@]}"
  else
    echo "${PACKAGES[@]}"
  fi
}

# Main workflow
main() {
  local target_packages
  read -ra target_packages <<< "$(get_target_packages)"

  print_header

  # Deps-only mode: just install dependencies and exit
  if $DEPS_ONLY; then
    log_info "Installing dependencies only..."
    install_all_deps "${target_packages[@]}"
    return
  fi

  # With-deps mode: install dependencies first
  if $WITH_DEPS; then
    log_info "Installing dependencies..."
    install_all_deps "${target_packages[@]}"
    echo ""
  fi

  # Normal stow workflow
  check_prerequisites
  create_backup "${BACKUP_FILES[@]}"
  create_directories
  deploy_base
  verify_installation
  print_next_steps
}

parse_args "$@"
main
