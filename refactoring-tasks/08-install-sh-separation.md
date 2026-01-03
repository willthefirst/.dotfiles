# Task: Separate Concerns in install.sh

## Branch Name
`refactor/install-separation`

## Problem Statement
`install.sh` has too many responsibilities: argument parsing, package selection, workflow orchestration, and feature flag management. This makes it hard to test and maintain.

### Current Structure (128 lines)

| Lines | Responsibility |
|-------|---------------|
| 1-35 | Script setup, sourcing modules |
| 37-84 | Argument parsing (`parse_args()`) |
| 87-93 | Package selection logic |
| 96-124 | Installation workflow orchestration |
| - | Feature flags mixed throughout (`FORCE_MODE`, `ADOPT_MODE`, `DEPS_ONLY`, `WITH_DEPS`) |

### Issues
1. **Too many reasons to change**: Adding a new flag requires touching argument parsing, help text, and usage logic
2. **Hard to test**: Can't test argument parsing without running the whole script
3. **Global state**: Feature flags are global variables set by `parse_args()` and read elsewhere
4. **Unclear data flow**: Data flows through globals, parameters, and command substitution inconsistently

## Desired Outcome
Separate `install.sh` into focused components:
1. **Argument parsing** - Extract to testable functions
2. **Workflow orchestration** - Keep in install.sh but simplified
3. **Configuration object** - Centralize feature flags

## Implementation Steps

### 1. Extract Argument Parsing

Create functions that can be tested independently:

```bash
# In lib/cli.sh (or similar)

# Parse command line arguments into configuration
# Usage: parse_install_args "$@"
# Sets: INSTALL_CONFIG associative array
parse_install_args() {
    # Initialize defaults
    INSTALL_FORCE=false
    INSTALL_ADOPT=false
    INSTALL_DEPS_ONLY=false
    INSTALL_WITH_DEPS=false
    INSTALL_PACKAGES=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_install_help
                exit 0
                ;;
            -f|--force)
                INSTALL_FORCE=true
                shift
                ;;
            -a|--adopt)
                INSTALL_ADOPT=true
                shift
                ;;
            --deps-only)
                INSTALL_DEPS_ONLY=true
                shift
                ;;
            --with-deps)
                INSTALL_WITH_DEPS=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_install_help
                exit 1
                ;;
            *)
                INSTALL_PACKAGES+=("$1")
                shift
                ;;
        esac
    done

    # Validate combinations
    if [[ "$INSTALL_DEPS_ONLY" == "true" && "$INSTALL_WITH_DEPS" == "true" ]]; then
        log_error "--deps-only and --with-deps are mutually exclusive"
        exit 1
    fi
}

# Display help text
show_install_help() {
    cat << 'EOF'
Usage: install.sh [OPTIONS] [PACKAGES...]

Options:
    -h, --help      Show this help message
    -f, --force     Force overwrite existing files
    -a, --adopt     Adopt existing files into stow
    --deps-only     Only install dependencies, skip stow
    --with-deps     Install dependencies along with packages

Packages:
    base            Base configuration (always included)
    nvim            Neovim configuration
    git             Git configuration and tools
    ...

Examples:
    ./install.sh                    # Install all packages
    ./install.sh nvim git           # Install specific packages
    ./install.sh --with-deps nvim   # Install nvim with dependencies
EOF
}
```

### 2. Create Configuration Pattern

Instead of scattered global variables, use a consistent pattern:

```bash
# Current (scattered globals):
FORCE_MODE=false
ADOPT_MODE=false
SELECTED_PACKAGES=()

# Better (prefixed, clear naming):
INSTALL_FORCE=false
INSTALL_ADOPT=false
INSTALL_PACKAGES=()

# Even better (if bash 4+ available - associative array):
declare -A INSTALL_CONFIG=(
    [force]=false
    [adopt]=false
    [deps_only]=false
    [with_deps]=false
)
```

### 3. Simplify Main Workflow

After extracting argument parsing, `install.sh` becomes cleaner:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source modules
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/cli.sh"      # New: argument parsing
source "$SCRIPT_DIR/lib/deploy.sh"
source "$SCRIPT_DIR/lib/deps.sh"
source "$SCRIPT_DIR/lib/backup.sh"
source "$SCRIPT_DIR/lib/conflicts.sh"

main() {
    # Parse arguments (sets INSTALL_* variables)
    parse_install_args "$@"

    # Initialize configuration
    init_config

    # Resolve target packages
    local packages
    if [[ ${#INSTALL_PACKAGES[@]} -eq 0 ]]; then
        packages=($(get_all_packages))
    else
        packages=("${INSTALL_PACKAGES[@]}")
    fi

    # Execute workflow
    if [[ "$INSTALL_DEPS_ONLY" == "true" ]]; then
        install_all_deps "${packages[@]}"
    else
        if [[ "$INSTALL_WITH_DEPS" == "true" ]]; then
            install_all_deps "${packages[@]}"
        fi
        deploy_packages "${packages[@]}"
    fi

    log_section "Installation complete"
}

main "$@"
```

### 4. Extract Package Resolution

Move package resolution logic to a function:

```bash
# In lib/config.sh or lib/packages.sh

# Get list of packages to install
# Usage: resolve_packages [package...]
# If no packages specified, returns all available packages
resolve_packages() {
    local requested=("$@")

    if [[ ${#requested[@]} -eq 0 ]]; then
        # Return all packages
        get_all_packages
    else
        # Validate and return requested packages
        local valid_packages=()
        for pkg in "${requested[@]}"; do
            if is_valid_package "$pkg"; then
                valid_packages+=("$pkg")
            else
                log_warn "Unknown package: $pkg"
            fi
        done
        printf '%s\n' "${valid_packages[@]}"
    fi
}

# Check if a package exists
is_valid_package() {
    local pkg="$1"
    [[ -d "$DOTFILES_DIR/$pkg" && -f "$DOTFILES_DIR/$pkg/.stow-local-ignore" ]] || \
    [[ -d "$DOTFILES_DIR/$pkg" && ! "$pkg" =~ ^(lib|tests|scripts)$ ]]
}
```

### 5. Add Tests for Argument Parsing

Create `tests/test_cli.sh`:

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

init_test_env "cli"

test_parse_default_values() {
    parse_install_args

    assert_equals "false" "$INSTALL_FORCE" "Default force should be false"
    assert_equals "false" "$INSTALL_ADOPT" "Default adopt should be false"
    assert_equals "false" "$INSTALL_DEPS_ONLY" "Default deps_only should be false"
    assert_equals "0" "${#INSTALL_PACKAGES[@]}" "Default packages should be empty"
}

test_parse_force_flag() {
    parse_install_args --force
    assert_equals "true" "$INSTALL_FORCE"
}

test_parse_short_force_flag() {
    parse_install_args -f
    assert_equals "true" "$INSTALL_FORCE"
}

test_parse_multiple_flags() {
    parse_install_args --force --adopt --with-deps

    assert_equals "true" "$INSTALL_FORCE"
    assert_equals "true" "$INSTALL_ADOPT"
    assert_equals "true" "$INSTALL_WITH_DEPS"
}

test_parse_packages() {
    parse_install_args nvim git base

    assert_equals "3" "${#INSTALL_PACKAGES[@]}"
    assert_equals "nvim" "${INSTALL_PACKAGES[0]}"
    assert_equals "git" "${INSTALL_PACKAGES[1]}"
    assert_equals "base" "${INSTALL_PACKAGES[2]}"
}

test_parse_mixed_flags_and_packages() {
    parse_install_args --force nvim --with-deps git

    assert_equals "true" "$INSTALL_FORCE"
    assert_equals "true" "$INSTALL_WITH_DEPS"
    assert_equals "2" "${#INSTALL_PACKAGES[@]}"
}

run_all_tests
```

### 6. Consider Future Workflow Extraction

For a more complete separation, the workflow itself could be extracted:

```bash
# lib/install-workflow.sh

# Run the full installation workflow
# Usage: run_install_workflow
run_install_workflow() {
    local packages
    packages=($(resolve_packages "${INSTALL_PACKAGES[@]}"))

    log_section "Installing packages: ${packages[*]}"

    # Phase 1: Dependencies (if requested)
    if [[ "$INSTALL_WITH_DEPS" == "true" || "$INSTALL_DEPS_ONLY" == "true" ]]; then
        log_step "Installing dependencies"
        for pkg in "${packages[@]}"; do
            install_package_deps "$pkg"
        done
    fi

    # Phase 2: Deployment (unless deps-only)
    if [[ "$INSTALL_DEPS_ONLY" != "true" ]]; then
        log_step "Deploying packages"
        deploy_packages "$INSTALL_FORCE" "$INSTALL_ADOPT" "${packages[@]}"
    fi
}
```

This is optional but would make `install.sh` even simpler.

## Files to Create/Modify
- `lib/cli.sh` (CREATE - argument parsing)
- `install.sh` (MODIFY - simplify, use new modules)
- `lib/config.sh` or `lib/packages.sh` (MODIFY - add resolve_packages)
- `tests/test_cli.sh` (CREATE - test argument parsing)

## Migration Notes
- Keep backward compatibility: same command-line interface
- Rename variables consistently: `FORCE_MODE` → `INSTALL_FORCE`
- Update any scripts that source `install.sh` variables

## Testing
```bash
# Test argument parsing in isolation
source lib/cli.sh
parse_install_args --force nvim
echo "Force: $INSTALL_FORCE, Packages: ${INSTALL_PACKAGES[*]}"

# Test full workflow
./install.sh --help
./install.sh --dry-run base
./install.sh --force --with-deps nvim git

# Run new tests
./tests/run_tests.sh test_cli.sh

# Run all tests
./tests/run_tests.sh
```

## Success Criteria
- [ ] `lib/cli.sh` created with `parse_install_args()` and `show_install_help()`
- [ ] `install.sh` is simplified to ~50 lines (just orchestration)
- [ ] Feature flag variables have consistent naming (`INSTALL_*`)
- [ ] Argument parsing is testable (tests exist and pass)
- [ ] Same command-line interface works as before
- [ ] All existing tests pass
- [ ] New `tests/test_cli.sh` has good coverage
