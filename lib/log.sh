#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Logging utilities for dotfiles scripts
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "  $1"; }
log_step() { echo -e "  ${GREEN}→${NC} $1"; }
log_ok() { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn() { echo -e "  ${YELLOW}!${NC} $1"; }
log_error() { echo -e "  ${RED}✗${NC} $1"; }

# Track if we've printed a section yet (for consistent newline handling)
_FIRST_SECTION=true

# Setup phase tracking (set by install.sh for multi-step output)
SETUP_PHASE=""

log_section() {
    local prefix=""
    local newline=""

    # Add leading newline after first section
    if ! $_FIRST_SECTION; then
        newline="\n"
    fi
    _FIRST_SECTION=false

    # Add phase prefix if set
    if [[ -n "$SETUP_PHASE" ]]; then
        prefix="[$SETUP_PHASE] "
    fi

    echo -e "${newline}${prefix}$1"
}
