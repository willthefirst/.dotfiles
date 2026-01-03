#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/conflict-data.sh - Conflict data structures, constants, and parsers
# =============================================================================
# Dependencies: none
# Provides: CONFLICT_TYPE_*, PARENT_STATUS_*, make_file_conflict,
#           make_symlink_conflict, parse_conflict_type, parse_conflict_path,
#           parse_conflict_target
# =============================================================================

# =============================================================================
# Conflict string format: "type:path[:target]"
#   - type: "file" or "symlink"
#   - path: the conflicting path
#   - target: symlink target (only for symlink type)
# With package prefix: "pkg:type:path[:target]"
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_CONFLICT_DATA_LOADED:-}" ]] && return 0
_DOTFILES_CONFLICT_DATA_LOADED=1

# Conflict type constants
readonly CONFLICT_TYPE_FILE="file"
readonly CONFLICT_TYPE_SYMLINK="symlink"

# Status constants for check_parent_symlink (used in conflict-detect.sh)
# shellcheck disable=SC2034
readonly PARENT_STATUS_MANAGED="managed"
# shellcheck disable=SC2034
readonly PARENT_STATUS_ALREADY_REPORTED="already_reported"

# =============================================================================
# Conflict string constructors (preferred over inline string building)
# =============================================================================

# Create a file conflict string
# Usage: make_file_conflict "/path/to/file"
# Output: "file:/path/to/file"
make_file_conflict() {
    echo "${CONFLICT_TYPE_FILE}:$1"
}

# Create a symlink conflict string
# Usage: make_symlink_conflict "/path/to/link" "/actual/target"
# Output: "symlink:/path/to/link:/actual/target"
make_symlink_conflict() {
    echo "${CONFLICT_TYPE_SYMLINK}:$1:$2"
}

# =============================================================================
# Conflict string parsers
# =============================================================================

# Parse conflict type from string
# Usage: parse_conflict_type "type:path[:target]" or "pkg:type:path[:target]"
# Output: "file" or "symlink"
parse_conflict_type() {
    local conflict="$1"
    local first="${conflict%%:*}"

    # If first field is a known type, return it
    if [[ "$first" == "$CONFLICT_TYPE_FILE" || "$first" == "$CONFLICT_TYPE_SYMLINK" ]]; then
        echo "$first"
        return
    fi

    # Otherwise first field is pkg, type is second field
    local rest="${conflict#*:}"
    echo "${rest%%:*}"
}

# Parse conflict path from string
# Usage: parse_conflict_path "type:path[:target]" or "pkg:type:path[:target]"
# Output: the path component
parse_conflict_path() {
    local conflict="$1"
    local first="${conflict%%:*}"
    local rest="${conflict#*:}"

    # If first field is a type, path is second field
    if [[ "$first" == "$CONFLICT_TYPE_FILE" || "$first" == "$CONFLICT_TYPE_SYMLINK" ]]; then
        echo "${rest%%:*}"
        return
    fi

    # First field is pkg, skip it and the type
    rest="${rest#*:}"  # Skip type field
    echo "${rest%%:*}"
}

# Parse symlink target from conflict string (symlink conflicts only)
# Usage: parse_conflict_target "symlink:path:target" or "pkg:symlink:path:target"
# Output: the target, or empty string if not a symlink conflict
parse_conflict_target() {
    local conflict="$1"
    local type
    type=$(parse_conflict_type "$conflict")

    if [[ "$type" != "$CONFLICT_TYPE_SYMLINK" ]]; then
        return
    fi

    # Target is the last colon-separated field
    echo "${conflict##*:}"
}
