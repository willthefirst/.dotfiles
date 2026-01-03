#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Platform detection utilities
# =============================================================================

is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}
