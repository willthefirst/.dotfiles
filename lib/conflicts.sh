#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Facade for backward compatibility - sources all conflict modules
# =============================================================================
# This file provides a single entry point for all conflict-related
# functionality. It sources the three focused modules:
#   - conflict-data.sh    - data structures, constants, constructors, parsers
#   - conflict-detect.sh  - detection logic
#   - conflict-resolve.sh - resolution and user-facing reporting
# =============================================================================

# Guard against re-sourcing
[[ -n "${_CONFLICTS_SH_LOADED:-}" ]] && return 0
_CONFLICTS_SH_LOADED=true

# Source all conflict modules
# shellcheck source=lib/conflict-data.sh
source "${BASH_SOURCE%/*}/conflict-data.sh"
# shellcheck source=lib/conflict-detect.sh
source "${BASH_SOURCE%/*}/conflict-detect.sh"
# shellcheck source=lib/conflict-resolve.sh
source "${BASH_SOURCE%/*}/conflict-resolve.sh"
