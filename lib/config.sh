#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Configuration variables for dotfiles
# =============================================================================

# Directory paths
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
WORK_DOTFILES_DIR="${WORK_DOTFILES_DIR:-$HOME/.dotfiles-stripe}"

# Stow packages to deploy
# shellcheck disable=SC2034
PACKAGES=(zsh git nvim ssh ghostty)

# Files to check for backup (these are what stow will manage)
# shellcheck disable=SC2034
BACKUP_FILES=(
    "$HOME/.zshrc"
    "$HOME/.gitconfig"
    "$HOME/.gitconfig.personal"
    "$HOME/.gitignore_global"
    "$HOME/.config/nvim"
    "$HOME/.ssh/config"
    "$HOME/.config/ghostty"
)

# Symlinks to verify after installation
# shellcheck disable=SC2034
VERIFY_SYMLINKS=(
    "$HOME/.zshrc"
    "$HOME/.gitconfig"
    "$HOME/.gitconfig.personal"
    "$HOME/.config/nvim/init.lua"
    "$HOME/.ssh/config"
    "$HOME/.config/ghostty"
)

# Work overlay files to check
# shellcheck disable=SC2034
WORK_FILES=(
    "$HOME/.zshrc.work"
    "$HOME/.gitconfig.work"
    "$HOME/.ssh/config.work"
    "$HOME/.config/nvim/lua/plugins-work"
)
