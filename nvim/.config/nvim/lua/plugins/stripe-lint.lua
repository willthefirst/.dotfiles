-- Stripe-specific linting configuration
-- Configures nvim-lint with Stripe's internal linters
return {
  {
    "mfussenegger/nvim-lint",
    dependencies = {
      { url = "git@git.corp.stripe.com:stevearc/nvim-stripe-configs" },
    },
    opts = {
      linters_by_ft = {
        -- Use Stripe's pay-server rubocop for Ruby files
        ruby = { "pay-server-rubocop" },
      },
    },
    config = function(_, opts)
      local lint = require("lint")
      lint.linters_by_ft = opts.linters_by_ft

      -- Create debounced auto-lint autocmds for save and text change events
      -- This is provided by nvim-stripe-configs for optimal performance
      local ok, stripe_lint = pcall(require, "stripe_configs.lint")
      if ok then
        stripe_lint.create_lint_autocmds()
      else
        vim.notify("[stripe-lint] Failed to load stripe_configs.lint", vim.log.levels.WARN)
      end
    end,
  },
}
