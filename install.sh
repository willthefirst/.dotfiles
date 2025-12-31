#!/usr/bin/env bash
# =============================================================================
# Dotfiles Installation Script
# =============================================================================
# Deploys dotfiles using GNU Stow. Run this after cloning the repository.
# =============================================================================

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
WORK_DOTFILES_DIR="${WORK_DOTFILES_DIR:-$HOME/.dotfiles-stripe}"

# CLI flags
FORCE_MODE=false
ADOPT_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_MODE=true
            shift
            ;;
        --adopt)
            ADOPT_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force    Remove conflicting symlinks before stowing"
            echo "  --adopt    Adopt existing files into stow packages"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run './install.sh --help' for usage"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------------
# Check for Stow Conflicts
# -----------------------------------------------------------------------------
# Returns list of conflicting files for a given stow package
get_package_conflicts() {
    local pkg_dir="$1"
    local target_dir="$2"
    local conflicts=()
    local checked_dirs=()

    if [[ ! -d "$pkg_dir" ]]; then
        return
    fi

    # Find all files and directories that stow would manage
    while IFS= read -r -d '' item; do
        local rel_path="${item#$pkg_dir/}"
        local target_path="$target_dir/$rel_path"

        # For directories, check if there's a conflicting symlink at that path
        # (stow might want to "fold" and create a symlink to the directory)
        if [[ -d "$item" ]]; then
            if [[ -L "$target_path" ]]; then
                local expected_target="$pkg_dir/$rel_path"
                local actual_target
                actual_target=$(readlink -f "$target_path" 2>/dev/null || echo "")
                local expected_resolved
                expected_resolved=$(readlink -f "$expected_target" 2>/dev/null || echo "$expected_target")

                if [[ "$actual_target" != "$expected_resolved" ]]; then
                    # Check if we already reported this
                    local already_reported=false
                    for checked in "${checked_dirs[@]}"; do
                        if [[ "$target_path" == "$checked" ]]; then
                            already_reported=true
                            break
                        fi
                    done
                    if ! $already_reported; then
                        conflicts+=("symlink:$target_path:$(readlink "$target_path")")
                        checked_dirs+=("$target_path")
                    fi
                fi
            elif [[ -e "$target_path" && ! -d "$target_path" ]]; then
                # A file exists where a directory should be
                conflicts+=("file:$target_path")
            fi
        else
            # It's a file
            # First check if any parent directory is a bad symlink
            local parent_path="$target_path"
            local parent_conflict=false
            while [[ "$parent_path" != "$target_dir" ]]; do
                parent_path=$(dirname "$parent_path")
                if [[ -L "$parent_path" ]]; then
                    # Parent is a symlink - check if it's already reported
                    for checked in "${checked_dirs[@]}"; do
                        if [[ "$parent_path" == "$checked" ]]; then
                            parent_conflict=true
                            break
                        fi
                    done
                    if ! $parent_conflict; then
                        local parent_rel="${parent_path#$target_dir/}"
                        local expected_parent="$pkg_dir/$parent_rel"
                        local actual_parent
                        actual_parent=$(readlink -f "$parent_path" 2>/dev/null || echo "")
                        local expected_parent_resolved
                        expected_parent_resolved=$(readlink -f "$expected_parent" 2>/dev/null || echo "$expected_parent")

                        if [[ "$actual_parent" != "$expected_parent_resolved" ]]; then
                            conflicts+=("symlink:$parent_path:$(readlink "$parent_path")")
                            checked_dirs+=("$parent_path")
                            parent_conflict=true
                        fi
                    fi
                    break
                fi
            done

            # Only check the file itself if no parent conflict
            if ! $parent_conflict; then
                if [[ -L "$target_path" ]]; then
                    local expected_target="$pkg_dir/$rel_path"
                    local actual_target
                    actual_target=$(readlink -f "$target_path" 2>/dev/null || echo "")
                    local expected_resolved
                    expected_resolved=$(readlink -f "$expected_target" 2>/dev/null || echo "$expected_target")

                    if [[ "$actual_target" != "$expected_resolved" ]]; then
                        conflicts+=("symlink:$target_path:$(readlink "$target_path")")
                    fi
                elif [[ -e "$target_path" ]]; then
                    conflicts+=("file:$target_path")
                fi
            fi
        fi
    done < <(find "$pkg_dir" -mindepth 1 \( -type f -o -type d \) -print0 2>/dev/null)

    printf '%s\n' "${conflicts[@]}"
}

# Check all packages for conflicts and report them
check_all_conflicts() {
    local base_dir="$1"
    local packages=("${@:2}")
    local has_conflicts=false
    local all_conflicts=()

    for pkg in "${packages[@]}"; do
        local pkg_dir="$base_dir/$pkg"
        if [[ -d "$pkg_dir" ]]; then
            while IFS= read -r conflict; do
                [[ -n "$conflict" ]] && all_conflicts+=("$pkg:$conflict")
            done < <(get_package_conflicts "$pkg_dir" "$HOME")
        fi
    done

    if [[ ${#all_conflicts[@]} -gt 0 ]]; then
        echo ""
        log_error "Conflicts detected that would prevent stow from running:"
        echo ""

        local current_pkg=""
        for conflict in "${all_conflicts[@]}"; do
            local pkg="${conflict%%:*}"
            local rest="${conflict#*:}"
            local type="${rest%%:*}"
            local path="${rest#*:}"

            if [[ "$pkg" != "$current_pkg" ]]; then
                [[ -n "$current_pkg" ]] && echo ""
                echo -e "  ${YELLOW}[$pkg]${NC}"
                current_pkg="$pkg"
            fi

            if [[ "$type" == "symlink" ]]; then
                local target="${path#*:}"
                path="${path%%:*}"
                echo -e "    ${RED}•${NC} $path"
                echo -e "      └─ symlink → $target (not managed by stow)"
            else
                echo -e "    ${RED}•${NC} $path"
                echo -e "      └─ regular file/directory (would be overwritten)"
            fi
        done

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${YELLOW}How to resolve:${NC}"
        echo ""
        echo "  Option 1: Remove conflicting symlinks/files automatically"
        echo -e "    ${GREEN}./install.sh --force${NC}"
        echo ""
        echo "  Option 2: Adopt existing files into stow (keeps current content)"
        echo -e "    ${GREEN}./install.sh --adopt${NC}"
        echo ""
        echo "  Option 3: Remove manually, then re-run:"
        for conflict in "${all_conflicts[@]}"; do
            local rest="${conflict#*:}"
            local path="${rest#*:}"
            path="${path%%:*}"
            echo "    rm \"$path\""
        done
        echo "    ./install.sh"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        return 1
    fi

    return 0
}

# Handle conflicts based on mode (--force or --adopt)
handle_conflicts() {
    local base_dir="$1"
    local packages=("${@:2}")
    local removed_paths=()

    for pkg in "${packages[@]}"; do
        local pkg_dir="$base_dir/$pkg"
        if [[ -d "$pkg_dir" ]]; then
            while IFS= read -r conflict; do
                [[ -z "$conflict" ]] && continue

                local type="${conflict%%:*}"
                local path="${conflict#*:}"
                path="${path%%:*}"

                # Skip if already removed (parent directory was removed)
                local already_removed=false
                for removed in "${removed_paths[@]}"; do
                    if [[ "$path" == "$removed"* ]]; then
                        already_removed=true
                        break
                    fi
                done
                $already_removed && continue

                if $FORCE_MODE; then
                    if [[ -L "$path" ]]; then
                        log_info "  Removing symlink: $path"
                        rm "$path"
                        removed_paths+=("$path")
                    elif [[ -d "$path" ]]; then
                        log_info "  Removing directory: $path"
                        rm -rf "$path"
                        removed_paths+=("$path")
                    elif [[ -f "$path" ]]; then
                        log_info "  Removing file: $path"
                        rm "$path"
                        removed_paths+=("$path")
                    fi
                fi
            done < <(get_package_conflicts "$pkg_dir" "$HOME")
        fi
    done
}

# -----------------------------------------------------------------------------
# Check Prerequisites
# -----------------------------------------------------------------------------
check_stow() {
    if ! command -v stow &> /dev/null; then
        log_error "GNU Stow is not installed."
        echo ""
        echo "Install it with:"
        echo "  macOS:  brew install stow"
        echo "  Ubuntu: sudo apt install stow"
        echo "  Arch:   sudo pacman -S stow"
        exit 1
    fi
    log_info "GNU Stow found: $(which stow)"
}

# -----------------------------------------------------------------------------
# Backup Existing Files
# -----------------------------------------------------------------------------
backup_existing() {
    local backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
    local needs_backup=false

    # Files that stow will manage
    local files_to_check=(
        "$HOME/.zshrc"
        "$HOME/.gitconfig"
        "$HOME/.gitignore_global"
        "$HOME/.config/nvim"
        "$HOME/.ssh/config"
    )

    # Check for files that exist and are NOT managed by stow
    # (either regular files or symlinks pointing outside the dotfiles dir)
    for file in "${files_to_check[@]}"; do
        if [[ -e "$file" || -L "$file" ]]; then
            if [[ -L "$file" ]]; then
                # It's a symlink - check if it's managed by stow (points into dotfiles)
                local target
                target=$(readlink -f "$file" 2>/dev/null || echo "")
                if [[ "$target" != *"$DOTFILES_DIR"* ]]; then
                    needs_backup=true
                    break
                fi
            else
                # It's a regular file/directory
                needs_backup=true
                break
            fi
        fi
    done

    if $needs_backup && ! $FORCE_MODE; then
        log_warn "Existing config files found. Creating backup at $backup_dir"
        mkdir -p "$backup_dir"

        for file in "${files_to_check[@]}"; do
            if [[ -e "$file" || -L "$file" ]]; then
                local should_backup=false

                if [[ -L "$file" ]]; then
                    local target
                    target=$(readlink -f "$file" 2>/dev/null || echo "")
                    if [[ "$target" != *"$DOTFILES_DIR"* ]]; then
                        should_backup=true
                    fi
                else
                    should_backup=true
                fi

                if $should_backup; then
                    local backup_path="$backup_dir/$(basename "$file")"
                    if [[ -L "$file" ]]; then
                        log_info "  Backing up symlink: $file -> $backup_path"
                        # For symlinks, copy the target content
                        cp -rL "$file" "$backup_path" 2>/dev/null || cp -r "$file" "$backup_path"
                    else
                        log_info "  Backing up: $file -> $backup_path"
                        cp -r "$file" "$backup_path"
                    fi
                fi
            fi
        done

        echo ""
        log_info "Backup complete. Restore with: cp -r $backup_dir/* ~/"
        echo ""
    fi
}

# -----------------------------------------------------------------------------
# Create Required Directories
# -----------------------------------------------------------------------------
create_directories() {
    log_info "Creating required directories..."
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.ssh/sockets"
    chmod 700 "$HOME/.ssh"
    chmod 700 "$HOME/.ssh/sockets"
}

# -----------------------------------------------------------------------------
# Deploy Base Dotfiles
# -----------------------------------------------------------------------------
deploy_base() {
    log_info "Deploying base dotfiles from $DOTFILES_DIR..."
    cd "$DOTFILES_DIR"

    local packages=(zsh git nvim ssh)

    # Check for conflicts first (unless in force/adopt mode)
    if ! $FORCE_MODE && ! $ADOPT_MODE; then
        if ! check_all_conflicts "$DOTFILES_DIR" "${packages[@]}"; then
            exit 1
        fi
    fi

    # Handle conflicts if in force mode
    if $FORCE_MODE; then
        log_info "Force mode: removing conflicting files..."
        handle_conflicts "$DOTFILES_DIR" "${packages[@]}"
    fi

    # Build stow options
    local stow_opts=(-v -t "$HOME")
    if $ADOPT_MODE; then
        stow_opts+=(--adopt)
        log_info "Adopt mode: existing files will be adopted into stow packages"
    fi

    for pkg in "${packages[@]}"; do
        if [[ -d "$pkg" ]]; then
            log_info "  Stowing: $pkg"
            local stow_output
            if ! stow_output=$(stow "${stow_opts[@]}" "$pkg" 2>&1); then
                log_error "  Failed to stow: $pkg"
                echo "$stow_output" | grep -v "^LINK:" || true
                exit 1
            fi
            # Show non-LINK output if any
            echo "$stow_output" | grep -v "^LINK:" || true
        else
            log_warn "  Package not found: $pkg"
        fi
    done
}

# -----------------------------------------------------------------------------
# Deploy Work Overlay (if present)
# -----------------------------------------------------------------------------
deploy_work() {
    if [[ -d "$WORK_DOTFILES_DIR" ]]; then
        log_info "Deploying work overlay from $WORK_DOTFILES_DIR..."
        cd "$WORK_DOTFILES_DIR"

        local packages=(zsh git nvim ssh)

        # Check for conflicts (work overlay adds files, shouldn't conflict much)
        if ! $FORCE_MODE && ! $ADOPT_MODE; then
            if ! check_all_conflicts "$WORK_DOTFILES_DIR" "${packages[@]}"; then
                log_warn "Work overlay has conflicts. Skipping work overlay deployment."
                return 1
            fi
        fi

        # Handle conflicts if in force mode
        if $FORCE_MODE; then
            handle_conflicts "$WORK_DOTFILES_DIR" "${packages[@]}"
        fi

        # Build stow options
        local stow_opts=(-v -t "$HOME")
        if $ADOPT_MODE; then
            stow_opts+=(--adopt)
        fi

        for pkg in "${packages[@]}"; do
            if [[ -d "$pkg" ]]; then
                log_info "  Stowing: $pkg"
                local stow_output
                if ! stow_output=$(stow "${stow_opts[@]}" "$pkg" 2>&1); then
                    log_error "  Failed to stow work overlay: $pkg"
                    echo "$stow_output" | grep -v "^LINK:" || true
                    return 1
                fi
                echo "$stow_output" | grep -v "^LINK:" || true
            fi
        done
    else
        log_info "Work dotfiles not found at $WORK_DOTFILES_DIR (skipping)"
        log_info "To install work overlay later:"
        log_info "  git clone <work-repo-url> $WORK_DOTFILES_DIR"
        log_info "  cd $WORK_DOTFILES_DIR && stow -v -t ~ zsh git nvim ssh"
    fi
}

# -----------------------------------------------------------------------------
# Verify Installation
# -----------------------------------------------------------------------------
# Check if a path is managed by stow (either is a symlink or has a parent symlink into dotfiles)
is_stow_managed() {
    local path="$1"
    local check_path="$path"

    # Check if the path itself or any parent is a symlink into dotfiles
    while [[ "$check_path" != "$HOME" && "$check_path" != "/" ]]; do
        if [[ -L "$check_path" ]]; then
            local target
            target=$(readlink -f "$check_path" 2>/dev/null || echo "")
            if [[ "$target" == *"$DOTFILES_DIR"* ]] || [[ "$target" == *"$WORK_DOTFILES_DIR"* ]]; then
                echo "$check_path"
                return 0
            fi
        fi
        check_path=$(dirname "$check_path")
    done
    return 1
}

verify_install() {
    echo ""
    log_info "Verifying installation..."

    local all_good=true

    # Check symlinks
    local symlinks=(
        "$HOME/.zshrc"
        "$HOME/.gitconfig"
        "$HOME/.config/nvim/init.lua"
        "$HOME/.ssh/config"
    )

    for link in "${symlinks[@]}"; do
        local stow_link
        if stow_link=$(is_stow_managed "$link"); then
            if [[ "$stow_link" == "$link" ]]; then
                echo -e "  ${GREEN}✓${NC} $link -> $(readlink "$link")"
            else
                echo -e "  ${GREEN}✓${NC} $link (via $stow_link)"
            fi
        elif [[ -e "$link" ]]; then
            echo -e "  ${YELLOW}!${NC} $link (exists but not managed by stow)"
            all_good=false
        else
            echo -e "  ${RED}✗${NC} $link (not found)"
            all_good=false
        fi
    done

    # Check work overlay files
    echo ""
    log_info "Work overlay status:"
    local work_files=(
        "$HOME/.zshrc.work"
        "$HOME/.gitconfig.work"
        "$HOME/.ssh/config.work"
        "$HOME/.config/nvim/lua/plugins-work"
    )

    for file in "${work_files[@]}"; do
        if [[ -e "$file" ]]; then
            echo -e "  ${GREEN}✓${NC} $file"
        else
            echo -e "  ${YELLOW}○${NC} $file (not installed)"
        fi
    done

    echo ""
    if $all_good; then
        log_info "Installation complete!"
    else
        log_warn "Installation complete with warnings. Check output above."
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo "=============================================="
    echo " Dotfiles Installation"
    echo "=============================================="
    echo ""

    check_stow
    backup_existing
    create_directories
    deploy_base
    deploy_work
    verify_install

    echo ""
    echo "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. Check git config: git config user.email"
    echo "  3. Test SSH: ssh -T git@github.com"
    echo ""
}

main "$@"
