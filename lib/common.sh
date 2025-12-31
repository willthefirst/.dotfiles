#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Common utilities for dotfiles scripts
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if a command exists
require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd is not installed."
        if [[ -n "$install_hint" ]]; then
            echo "$install_hint"
        fi
        return 1
    fi
    return 0
}

# Platform detection
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# Print section header
print_header() {
    echo "=============================================="
    echo " Dotfiles Installation"
    echo "=============================================="
    echo ""
}

# Print next steps after installation
print_next_steps() {
    echo ""
    echo "Next steps:"
    echo "  1. source ~/.zshrc"
    echo "  2. git config user.email"
    echo "  3. ssh -T git@github.com"
    echo ""
}
