#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/init.sh - Central module initialization
# =============================================================================
# Usage: source lib/init.sh
# This sources all library modules in the correct order.
# Individual modules can still be sourced directly if needed.
#
# DEPENDENCY GRAPH
# ================
# lib/log.sh          (no dependencies)
# lib/platform.sh     (no dependencies)
# lib/fs.sh           depends on: log.sh
# lib/config.sh       depends on: log.sh
# lib/common.sh       depends on: log.sh, platform.sh, fs.sh (facade)
# lib/validate.sh     depends on: log.sh
# lib/pkg-manager.sh  depends on: log.sh, platform.sh
# lib/cli.sh          depends on: log.sh
# lib/conflict-data.sh    (no dependencies)
# lib/conflict-detect.sh  depends on: conflict-data.sh, fs.sh
# lib/conflict-resolve.sh depends on: conflict-data.sh, conflict-detect.sh, log.sh, config.sh
# lib/conflicts.sh    depends on: conflict-data.sh, conflict-detect.sh, conflict-resolve.sh (facade)
# lib/backup.sh       depends on: log.sh, fs.sh, config.sh
# lib/deploy.sh       depends on: log.sh, fs.sh, config.sh, conflicts.sh, pkg-manager.sh
# lib/deps.sh         depends on: log.sh, platform.sh, config.sh, validate.sh, pkg-manager.sh
# lib/verify.sh       depends on: log.sh, fs.sh, config.sh
# lib/install-helpers.sh depends on: log.sh
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_INIT_LOADED:-}" ]] && return 0
_DOTFILES_INIT_LOADED=1

DOTFILES_LIB_DIR="${BASH_SOURCE%/*}"

# Core modules (no dependencies)
# shellcheck source=lib/log.sh
source "$DOTFILES_LIB_DIR/log.sh"
# shellcheck source=lib/platform.sh
source "$DOTFILES_LIB_DIR/platform.sh"

# Filesystem utilities
# shellcheck source=lib/fs.sh
source "$DOTFILES_LIB_DIR/fs.sh"

# Configuration
# shellcheck source=lib/config.sh
source "$DOTFILES_LIB_DIR/config.sh"

# Common facade (for backward compatibility)
# shellcheck source=lib/common.sh
source "$DOTFILES_LIB_DIR/common.sh"

# Validation helpers
# shellcheck source=lib/validate.sh
source "$DOTFILES_LIB_DIR/validate.sh"

# Package manager
# shellcheck source=lib/pkg-manager.sh
source "$DOTFILES_LIB_DIR/pkg-manager.sh"

# CLI argument parsing
# shellcheck source=lib/cli.sh
source "$DOTFILES_LIB_DIR/cli.sh"

# Conflict handling
# shellcheck source=lib/conflicts.sh
source "$DOTFILES_LIB_DIR/conflicts.sh"

# Feature modules
# shellcheck source=lib/backup.sh
source "$DOTFILES_LIB_DIR/backup.sh"
# shellcheck source=lib/deploy.sh
source "$DOTFILES_LIB_DIR/deploy.sh"
# shellcheck source=lib/deps.sh
source "$DOTFILES_LIB_DIR/deps.sh"
# shellcheck source=lib/verify.sh
source "$DOTFILES_LIB_DIR/verify.sh"

# Install helpers (for custom package installers)
# shellcheck source=lib/install-helpers.sh
source "$DOTFILES_LIB_DIR/install-helpers.sh"
