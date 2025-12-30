#!/usr/bin/env bash
# =============================================================================
# Dotfiles Installation Script
# =============================================================================
# Deploys dotfiles using GNU Stow. Run this after cloning the repository.
# =============================================================================

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
WORK_DOTFILES_DIR="${WORK_DOTFILES_DIR:-$HOME/.dotfiles-stripe}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

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

    # Check which files exist and are not symlinks
    local files_to_check=(
        "$HOME/.zshrc"
        "$HOME/.gitconfig"
        "$HOME/.gitignore_global"
        "$HOME/.config/nvim"
        "$HOME/.ssh/config"
        "$HOME/.claude"
    )

    for file in "${files_to_check[@]}"; do
        if [[ -e "$file" && ! -L "$file" ]]; then
            needs_backup=true
            break
        fi
    done

    if $needs_backup; then
        log_warn "Existing config files found. Creating backup at $backup_dir"
        mkdir -p "$backup_dir"

        for file in "${files_to_check[@]}"; do
            if [[ -e "$file" && ! -L "$file" ]]; then
                local backup_path="$backup_dir/$(basename "$file")"
                log_info "  Backing up: $file -> $backup_path"
                mv "$file" "$backup_path"
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

    local packages=(zsh git nvim ssh claude)

    for pkg in "${packages[@]}"; do
        if [[ -d "$pkg" ]]; then
            log_info "  Stowing: $pkg"
            stow -v -t "$HOME" "$pkg" 2>&1 | grep -v "^LINK:" || true
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

        local packages=(zsh git nvim ssh claude)

        for pkg in "${packages[@]}"; do
            if [[ -d "$pkg" ]]; then
                log_info "  Stowing: $pkg"
                stow -v -t "$HOME" "$pkg" 2>&1 | grep -v "^LINK:" || true
            fi
        done
    else
        log_info "Work dotfiles not found at $WORK_DOTFILES_DIR (skipping)"
        log_info "To install work overlay later:"
        log_info "  git clone <work-repo-url> $WORK_DOTFILES_DIR"
        log_info "  cd $WORK_DOTFILES_DIR && stow -v -t ~ zsh git nvim ssh claude"
    fi
}

# -----------------------------------------------------------------------------
# Verify Installation
# -----------------------------------------------------------------------------
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
        if [[ -L "$link" ]]; then
            echo -e "  ${GREEN}✓${NC} $link -> $(readlink "$link")"
        elif [[ -e "$link" ]]; then
            echo -e "  ${YELLOW}!${NC} $link (exists but not a symlink)"
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
