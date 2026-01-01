-- Stripe-specific test runner configuration
-- Configures neotest with Stripe's pay-test adapter
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "haydenmeade/neotest-jest",
      { url = "git@git.corp.stripe.com:stevearc/neotest-pay-test.git" },
      "stevearc/overseer.nvim",
    },
    keys = {
      { "<leader>tf", function() require("neotest").run.run(vim.api.nvim_buf_get_name(0)) end, desc = "Test File" },
      { "<leader>tn", function() require("neotest").run.run() end, desc = "Test Nearest" },
      { "<leader>tl", function() require("neotest").run.run_last() end, desc = "Test Last" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Test Summary" },
      { "<leader>to", function() require("neotest").output.open({ short = true }) end, desc = "Test Output" },
      { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Test Debug" },
    },
    opts = function(_, opts)
      -- Configure neotest adapters
      opts.adapters = opts.adapters or {}

      -- Jest adapter for JavaScript/TypeScript tests
      local neotest_jest = require("neotest-jest")
      table.insert(opts.adapters, neotest_jest({
        cwd = neotest_jest.root,
      }))

      -- Stripe's pay-test adapter for Ruby and other Stripe tests
      table.insert(opts.adapters, require("neotest-pay-test")())

      -- Disable discovery for performance (enable manually with :NeotestDiscover)
      opts.discovery = {
        enabled = false,
      }

      -- Configure overseer integration
      opts.consumers = opts.consumers or {}
      opts.consumers.overseer = require("neotest.consumers.overseer")

      -- Customize icons for test status
      opts.icons = {
        passed = " ",
        running = " ",
        failed = " ",
        unknown = " ",
        running_animated = vim.tbl_map(function(s)
          return s .. " "
        end, { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }),
      }

      -- Don't automatically open output window on test run
      opts.output = {
        open_on_run = false,
      }

      return opts
    end,
  },
}
