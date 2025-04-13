return {
  {
    "nvim-neotest/neotest",
    -- adapters = { "neotest-jest" },
    dependencies = {
      "nvim-neotest/neotest-jest",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = function(_, opts)
      table.insert(
        opts.adapters,
        require("neotest-jest")({
          jestCommand = "npm test --",
          env = { CI = true },
          cwd = function()
            return vim.fn.getcwd()
          end,
        })
      )
    end,
  },
}
