#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Custom neovim installation
# =============================================================================
# Uses brew on macOS, appimage on Linux for latest version
# =============================================================================

install_nvim() {
    if is_macos; then
        pkg_installed neovim || pkg_install neovim >/dev/null 2>&1
    elif is_linux; then
        # Install latest neovim appimage for newer version than apt
        local arch
        arch=$(uname -m)
        local nvim_file="nvim-linux-x86_64.appimage"
        if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
            nvim_file="nvim-linux-arm64.appimage"
        fi
        local nvim_url="https://github.com/neovim/neovim/releases/latest/download/${nvim_file}"

        log_step "Downloading neovim appimage..."
        if ! curl -fsSL -o "$DOTFILES_TEMP_DIR/nvim.appimage" "$nvim_url"; then
            log_error "  Failed to download neovim appimage"
            return 1
        fi
        chmod +x "$DOTFILES_TEMP_DIR/nvim.appimage"
        log_step "Installing to $DOTFILES_BIN_DIR/nvim..."
        install_to_bin "$DOTFILES_TEMP_DIR/nvim.appimage" nvim
    fi
}
