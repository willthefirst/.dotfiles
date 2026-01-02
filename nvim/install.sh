#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Custom neovim installation
# =============================================================================
# Uses brew on macOS, appimage on Linux for latest version
# =============================================================================

install_nvim() {
    if is_macos; then
        pkg_install neovim
    elif is_linux; then
        # Install latest neovim appimage for newer version than apt
        local nvim_url="https://github.com/neovim/neovim/releases/latest/download/nvim.appimage"
        log_info "  Downloading neovim appimage..."
        curl -fLo /tmp/nvim.appimage "$nvim_url"
        chmod +x /tmp/nvim.appimage
        log_info "  Installing to /usr/local/bin/nvim..."
        sudo mv /tmp/nvim.appimage /usr/local/bin/nvim
    fi
}
