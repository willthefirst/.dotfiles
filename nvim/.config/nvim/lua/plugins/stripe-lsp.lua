-- Stripe-specific LSP configuration
-- Integrates Stripe internal language servers and tooling
return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      -- Stripe internal LSP configurations
      { url = "git@git.corp.stripe.com:stevearc/nvim-stripe-configs" },
    },
    opts = function(_, opts)
      -- Merge Stripe LSP servers into LazyVim's LSP config
      opts.servers = opts.servers or {}

      -- Enable Stripe-specific language servers
      -- These will be automatically configured via nvim-stripe-configs
      local stripe_servers = {
        "stripe_autogen",
        "stripe_checkmate",
        "stripe_gopls",
        "stripe_scip",
        "stripe_sorbet",
        "stripe_starpls",
        "stripe_typescript_native",
        "eslint",
        "ruff",
      }

      for _, server in ipairs(stripe_servers) do
        opts.servers[server] = {}
      end

      return opts
    end,
    init = function()
      -- Auto-build JavaScript CLI tools for Stripe's JS language server
      -- This ensures the latest version is available
      local ok, stripe_js = pcall(require, "stripe_configs.javascript")
      if ok then
        stripe_js.auto_build_js_cli()
      end
    end,
    keys = {
      -- Integration with Snacks.nvim picker for LSP navigation
      -- These override LazyVim's default LSP keymaps to use Snacks
      { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition" },
      { "gi", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
      { "grr", function() Snacks.picker.lsp_references() end, desc = "Goto References" },
      { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Goto Declaration" },
      { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto Type Definition" },
    },
  },
}
