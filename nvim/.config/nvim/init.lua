-- =============================================================================
-- init.lua - Neovim Configuration Entry Point
-- =============================================================================
-- This is a portable base config using LazyVim. Work-specific plugins are
-- loaded from lua/plugins-work/ if present (managed by dotfiles-stripe overlay).
-- =============================================================================

-- Bootstrap lazy.nvim and LazyVim
require("config.lazy")
