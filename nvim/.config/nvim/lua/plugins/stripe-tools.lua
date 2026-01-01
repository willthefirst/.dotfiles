-- Stripe-specific development tools
-- Includes pay-status, code-owner, and dagger integrations
return {
  {
    -- pay-status.nvim: Integration with `pay up:status`
    -- Note: This plugin is designed for lualine. If using a different statusline,
    -- you may need to integrate it manually or use :lua require('pay_status').get_status()
    url = "git@git.corp.stripe.com:stevearc/pay-status.nvim.git",
    lazy = false,
    cond = function()
      -- Only load on local machine (not remote devbox)
      return vim.fn.isdirectory("/pay/src") == 0
    end,
    config = function()
      -- If you want to add pay_status to your statusline, you can access it via:
      -- require('pay_status').get_status()
      vim.notify("[pay-status] Loaded. Use require('pay_status').get_status() to integrate with statusline", vim.log.levels.INFO)
    end,
  },

  {
    -- stripe-code-owner.nvim: Shows code ownership information
    url = "git@git.corp.stripe.com:dbalatero/stripe-code-owner.nvim.git",
    cmd = "StripeOwner",
    config = function()
      -- Register the :StripeOwner command
      vim.api.nvim_create_user_command("StripeOwner", function()
        require("stripe-code-owner").showOverlay()
      end, {
        desc = "Show Stripe code ownership for current file",
      })
    end,
  },

  {
    -- dagger.nvim: Dagger dependency injection window for Java
    url = "git@git.corp.stripe.com:stevearc/dagger.nvim.git",
    ft = "java", -- Only load for Java files
    keys = {
      { "<leader>dt", function() require("dagger").toggle() end, desc = "Dagger Toggle" },
      { "<leader>do", function() require("dagger").open() end, desc = "Dagger Open" },
      { "<leader>dc", function() require("dagger").close() end, desc = "Dagger Close" },
    },
    config = function()
      require("dagger").setup()
    end,
  },
}
