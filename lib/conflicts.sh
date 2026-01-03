#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/conflicts.sh - Facade for conflict detection and resolution
# =============================================================================
# Dependencies: conflict-data.sh, conflict-detect.sh, conflict-resolve.sh
# Provides: All exports from conflict-data.sh, conflict-detect.sh,
#           conflict-resolve.sh
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_CONFLICTS_LOADED:-}" ]] && return 0
_DOTFILES_CONFLICTS_LOADED=1

# Source all conflict modules
# shellcheck source=lib/conflict-data.sh
source "${BASH_SOURCE%/*}/conflict-data.sh"
# shellcheck source=lib/conflict-detect.sh
source "${BASH_SOURCE%/*}/conflict-detect.sh"
# shellcheck source=lib/conflict-resolve.sh
source "${BASH_SOURCE%/*}/conflict-resolve.sh"
