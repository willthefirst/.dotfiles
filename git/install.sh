#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Custom lazygit installation
# =============================================================================
# macOS uses deps.darwin (brew), Linux uses GitHub releases
# =============================================================================

install_git() {
    if is_linux; then
        # Install latest lazygit from GitHub releases
        local arch
        arch=$(uname -m)
        local lazygit_arch="x86_64"
        if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
            lazygit_arch="arm64"
        fi

        # Fetch latest version from GitHub API
        log_step "Fetching latest lazygit version..."
        local version
        version=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
        if [[ -z "$version" ]]; then
            log_error "  Failed to fetch latest version"
            return 1
        fi

        local lazygit_url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${lazygit_arch}.tar.gz"

        log_step "Downloading lazygit ${version}..."
        if ! curl -fsSL "$lazygit_url" -o /tmp/lazygit.tar.gz; then
            log_error "  Failed to download lazygit"
            return 1
        fi
        log_step "Extracting lazygit..."
        if ! tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit 2>/dev/null; then
            log_error "  Failed to extract lazygit"
            return 1
        fi
        chmod +x /tmp/lazygit
        log_step "Installing to /usr/local/bin/lazygit..."
        sudo mv /tmp/lazygit /usr/local/bin/lazygit
        rm -f /tmp/lazygit.tar.gz
    fi
}
