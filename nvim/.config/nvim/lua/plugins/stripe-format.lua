-- Stripe-specific formatting configuration
-- Extends LazyVim's conform.nvim with Stripe formatters
return {
  {
    "stevearc/conform.nvim",
    dependencies = {
      { url = "git@git.corp.stripe.com:stevearc/nvim-stripe-configs" },
    },
    opts = function(_, opts)
      -- Extend formatters_by_ft with Stripe-specific formatters
      opts.formatters_by_ft = vim.tbl_deep_extend("force", opts.formatters_by_ft or {}, {
        -- JavaScript/TypeScript formatting with prettierd
        javascript = { "prettierd" },
        typescript = { "prettierd" },
        javascriptreact = { "prettierd" },
        typescriptreact = { "prettierd" },
        html = { "prettierd" },
        json = { "prettierd" },
        jsonc = { "prettierd" },
        graphql = { "prettierd" },

        -- Go formatting with custom goimports path
        go = { "goimports", "gofmt" },

        -- Lua formatting
        lua = { "stylua" },

        -- Stripe-specific formatters from zoolander
        sql = { "zoolander_format_sql" },
        scala = { "zoolander_format_scala" },

        -- Infrastructure as code
        bzl = { "buildifier" }, -- Bazel
        terraform = { "sc_terraform" },
      })

      -- Configure custom formatter paths
      opts.formatters = vim.tbl_deep_extend("force", opts.formatters or {}, {
        goimports = {
          -- Use Stripe's custom goimports in ~/stripe/gocode/bin
          command = vim.env.HOME .. "/stripe/gocode/bin/goimports",
        },
      })

      -- Enable format-on-save with LSP fallback
      -- This will use formatters defined above, falling back to LSP formatting
      opts.format_after_save = { lsp_format = "fallback" }

      return opts
    end,
  },
}
