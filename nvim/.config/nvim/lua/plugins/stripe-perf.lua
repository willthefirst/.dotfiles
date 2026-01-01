-- Stripe-specific performance optimizations
-- Disables slow features in plugins for better performance with large repos

-- Detect if we're on a remote devbox (has /pay/src directory)
local is_remote_devbox = vim.fn.isdirectory("/pay/src") == 1

return {
  {
    -- nvim-tree: Disable git integration for performance
    "nvim-tree/nvim-tree.lua",
    optional = true,
    opts = {
      git = {
        enable = false, -- Git integration causes slowness in large repos
      },
    },
  },

  {
    -- fzf-lua: Disable git icons for performance
    "ibhagwan/fzf-lua",
    optional = true,
    opts = {
      defaults = {
        git_icons = false, -- Git icon lookups are slow in monorepos
      },
    },
  },

  {
    -- neo-tree: Disable git integration if using neo-tree instead of nvim-tree
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = {
      filesystem = {
        filtered_items = {
          hide_gitignored = false, -- Don't query git for ignored files
        },
      },
    },
  },

  {
    -- vim-fugitive: Configure GitHub Enterprise URL for Stripe
    "tpope/vim-fugitive",
    optional = true,
    init = function()
      -- Enable Stripe's GitHub Enterprise for :GBrowse command
      vim.g.github_enterprise_urls = { "https://git.corp.stripe.com" }
    end,
  },
}
