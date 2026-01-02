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

# CLI flags
FORCE_MODE=false
ADOPT_MODE=false

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
    --help | -h)
      echo "Usage: ./install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --force    Remove conflicting symlinks before stowing"
      echo "  --adopt    Adopt existing files into stow packages"
      echo "  --help     Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run './install.sh --help' for usage"
      exit 1
      ;;
    esac
  done
}

# Main workflow
main() {
  print_header
  check_prerequisites
  create_backup "${BACKUP_FILES[@]}"
  create_directories
  deploy_base
  verify_installation
  print_next_steps
}

parse_args "$@"
main
