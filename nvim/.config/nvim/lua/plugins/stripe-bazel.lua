-- Stripe-specific Bazel integration
-- Includes bazel.nvim for project management and overseer for task running
return {
  {
    -- bazel.nvim: Bazel project focusing and file finding
    url = "git@git.corp.stripe.com:stevearc/bazel.nvim.git",
    lazy = false,
    keys = {
      {
        "<leader>fp",
        function()
          require("bazel").fzf_project_files()
        end,
        desc = "Find Project files (Bazel)",
      },
    },
    cmd = { "BazelFocus" },
    config = function()
      local bazel = require("bazel")
      bazel.setup()

      -- :BazelFocus - Focus on a specific Bazel project
      -- :BazelFocus! - Clear the focused project
      vim.api.nvim_create_user_command("BazelFocus", function(params)
        if params.bang then
          bazel.set_project(nil)
        else
          bazel.select_project()
        end
      end, {
        bang = true,
        desc = "Focus a Bazel project, or use ! to clear the focused project",
      })
    end,
  },

  {
    -- overseer.nvim: Task runner with Bazel integration
    "stevearc/overseer.nvim",
    opts = function(_, opts)
      -- Add Bazel templates to overseer
      opts.templates = opts.templates or { "builtin" }
      table.insert(opts.templates, "bazel")

      -- Configure neotest integration
      opts.default_neotest = {
        { "on_complete_notify", on_change = true },
        "default",
      }

      return opts
    end,
    keys = {
      { "<leader>ot", "<cmd>OverseerToggle<CR>", desc = "Overseer Toggle" },
      { "<leader>or", "<cmd>OverseerRun<CR>", desc = "Overseer Run" },
      { "<leader>oq", "<cmd>OverseerQuickAction<CR>", desc = "Overseer Quick action" },
      { "<leader>oa", "<cmd>OverseerTaskAction<CR>", desc = "Overseer task Action" },
    },
  },
}
