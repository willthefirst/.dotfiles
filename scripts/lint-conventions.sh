#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Convention linter for dotfiles codebase
# =============================================================================
# Enforces coding patterns established during refactoring:
#   - Source guards for files with readonly declarations
#   - Use of constants instead of magic strings (colors, icons)
#   - Check functions (is_*/has_*) don't log errors
#   - Structured strings use constructors (make_*_conflict)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source logging for consistent output
# shellcheck source=lib/log.sh
source "$ROOT_DIR/lib/log.sh"

errors=0

# -----------------------------------------------------------------------------
# Check: Files with readonly declarations must have source guards
# -----------------------------------------------------------------------------
check_source_guards() {
    log_section "Checking source guards..."
    local failed=0

    for f in "$ROOT_DIR"/lib/*.sh; do
        [[ ! -f "$f" ]] && continue
        local basename
        basename=$(basename "$f")

        # Skip if no readonly declarations
        if ! grep -q '^readonly ' "$f"; then
            continue
        fi

        # Check for source guard pattern
        if ! grep -q '_LOADED:-' "$f"; then
            log_error "$basename: has readonly declarations but no source guard"
            log_info "  Add: [[ -n \"\${_MODULE_LOADED:-}\" ]] && return 0"
            ((failed++))
        fi
    done

    if [[ $failed -eq 0 ]]; then
        log_ok "All files with readonly have source guards"
    fi
    return $failed
}

# -----------------------------------------------------------------------------
# Check: No magic color codes (should use LOG_COLOR_* constants)
# -----------------------------------------------------------------------------
check_magic_colors() {
    log_section "Checking for magic color codes..."
    local failed=0

    while IFS=: read -r file line content; do
        # Skip the constant definitions themselves
        if [[ "$content" =~ readonly\ LOG_COLOR ]]; then
            continue
        fi
        log_error "$file:$line: magic color code (use LOG_COLOR_* constants)"
        log_info "  $content"
        ((failed++))
    done < <(grep -Hn '\\033\[' "$ROOT_DIR"/lib/*.sh 2>/dev/null || true)

    if [[ $failed -eq 0 ]]; then
        log_ok "No magic color codes found"
    fi
    return $failed
}

# -----------------------------------------------------------------------------
# Check: No magic icons (should use LOG_ICON_* constants)
# -----------------------------------------------------------------------------
check_magic_icons() {
    log_section "Checking for magic icons..."
    local failed=0

    # Check for common icons that should be constants
    while IFS=: read -r file line content; do
        # Skip the constant definitions themselves
        if [[ "$content" =~ readonly\ LOG_ICON ]]; then
            continue
        fi
        log_error "$file:$line: magic icon (use LOG_ICON_* constants)"
        log_info "  $content"
        ((failed++))
    done < <(grep -Hn "'[✓✗!→]'" "$ROOT_DIR"/lib/*.sh 2>/dev/null || true)

    if [[ $failed -eq 0 ]]; then
        log_ok "No magic icons found"
    fi
    return $failed
}

# -----------------------------------------------------------------------------
# Check: is_*/has_* functions should not call log_error/log_warn
# These are check functions that should return 0/1 only, letting caller decide
# -----------------------------------------------------------------------------
check_function_conventions() {
    log_section "Checking function conventions..."
    local failed=0

    for f in "$ROOT_DIR"/lib/*.sh; do
        [[ ! -f "$f" ]] && continue
        local basename
        basename=$(basename "$f")

        # Find is_* and has_* function definitions and check their bodies
        local in_check_function=false
        local function_name=""
        local line_num=0
        local brace_depth=0

        while IFS= read -r line; do
            ((line_num++))

            # Detect start of is_* or has_* function
            if [[ "$line" =~ ^(is_|has_)[a-z_]+\(\) ]]; then
                in_check_function=true
                function_name="${BASH_REMATCH[0]}"
                function_name="${function_name%()}"
                brace_depth=0
            fi

            if $in_check_function; then
                # Track brace depth
                if [[ "$line" =~ \{ ]]; then
                    ((brace_depth++))
                fi
                if [[ "$line" =~ \} ]]; then
                    ((brace_depth--))
                    if [[ $brace_depth -eq 0 ]]; then
                        in_check_function=false
                    fi
                fi

                # Check for logging calls within check functions
                if [[ "$line" =~ log_error|log_warn ]]; then
                    log_error "$basename:$line_num: $function_name() calls logging function"
                    log_info "  Check functions (is_*/has_*) should return 0/1 only, no logging"
                    ((failed++))
                fi
            fi
        done < "$f"
    done

    if [[ $failed -eq 0 ]]; then
        log_ok "Check functions follow conventions"
    fi
    return $failed
}

# -----------------------------------------------------------------------------
# Check: Conflict strings should use constructors, not raw building
# -----------------------------------------------------------------------------
check_conflict_constructors() {
    log_section "Checking conflict string constructors..."
    local failed=0

    # Look for raw conflict string patterns that should use make_*_conflict
    # Pattern: literal "file:" or "symlink:" not in a readonly or function definition
    while IFS=: read -r file line content; do
        # Skip constant definitions and function definitions
        if [[ "$content" =~ readonly|CONFLICT_TYPE|make_file_conflict|make_symlink_conflict|parse_conflict ]]; then
            continue
        fi
        # Skip test files - they may test raw strings intentionally
        if [[ "$file" =~ /tests/ ]]; then
            continue
        fi
        # Skip comments
        if [[ "$content" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        log_error "$file:$line: raw conflict string (use make_*_conflict constructors)"
        log_info "  $content"
        ((failed++))
    done < <(grep -Hn '"file:\|"symlink:' "$ROOT_DIR"/lib/*.sh 2>/dev/null || true)

    if [[ $failed -eq 0 ]]; then
        log_ok "Conflict strings use constructors"
    fi
    return $failed
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log_section "Convention Linting"

    check_source_guards || ((errors += $?))
    check_magic_colors || ((errors += $?))
    check_magic_icons || ((errors += $?))
    check_function_conventions || ((errors += $?))
    check_conflict_constructors || ((errors += $?))

    echo ""
    if [[ $errors -eq 0 ]]; then
        log_ok "All convention checks passed"
        return 0
    else
        log_error "$errors convention violation(s) found"
        return 1
    fi
}

main "$@"
