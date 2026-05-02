return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      local group = vim.api.nvim_create_augroup("user_lsp_inlay_hints", { clear = true })
      vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function(args)
          local client = args.data and vim.lsp.get_client_by_id(args.data.client_id) or nil
          if client and client.supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
          end
        end,
      })
    end,
    opts = {
      inlay_hints = {
        enabled = true,
        exclude = {},
      },
      servers = {},
    },
  },
}
