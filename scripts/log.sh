#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Thin wrapper for Makefile to use lib/log.sh functions
# Usage: ./scripts/log.sh <level> <message>
# Levels: ok, error, warn, step, info
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the main logging module
# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/../lib/log.sh"

level="$1"
shift
message="$*"

case "$level" in
    ok)    log_ok "$message" ;;
    error) log_error "$message" ;;
    warn)  log_warn "$message" ;;
    step)  log_step "$message" ;;
    info)  log_info "$message" ;;
    *)     log_info "$message" ;;
esac
