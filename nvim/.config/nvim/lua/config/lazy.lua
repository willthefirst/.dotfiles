-- =============================================================================
-- lazy.lua - Plugin Manager Configuration
-- =============================================================================
-- Loads LazyVim, personal plugins, and work plugins (if present).
-- =============================================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Build the plugin spec
local spec = {
  -- LazyVim and its plugins
  { "LazyVim/LazyVim", import = "lazyvim.plugins" },
  -- Personal plugins
  { import = "plugins" },
}

-- =============================================================================
-- Work Overlay - Load work plugins if present
-- =============================================================================
-- Check if work plugins directory exists and add to spec
local work_plugins_path = vim.fn.stdpath("config") .. "/lua/plugins-work"
if vim.fn.isdirectory(work_plugins_path) == 1 then
  table.insert(spec, { import = "plugins-work" })
end

require("lazy").setup({
  spec = spec,
  defaults = {
    lazy = false,
    version = false,
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = true,
    notify = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
