return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          -- Only attach gopls when a Go workspace/module root exists.
          -- This avoids attaching at monorepo .git roots and showing false import errors.
          root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            on_dir(vim.fs.root(fname, { "go.work", "go.mod" }))
          end,
        },
      },
    },
  },
}
