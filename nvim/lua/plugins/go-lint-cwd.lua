return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        golangcilint = {
          condition = function(ctx)
            return vim.fs.root(ctx.filename, { "go.work", "go.mod" }) ~= nil
          end,
          -- Run golangci-lint from the module/workspace root for the current file.
          -- This prevents false "no required module provides package" diagnostics
          -- when Neovim was started from another directory.
          cwd = function()
            local fname = vim.api.nvim_buf_get_name(0)
            return vim.fs.root(fname, { "go.work", "go.mod" }) or vim.fn.getcwd()
          end,
        },
      },
    },
  },
}
