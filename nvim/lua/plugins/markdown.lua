return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown", "markdown.mdx", "norg", "rmd", "org", "codecompanion" },
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" }, -- if you use the mini.nvim suite
  -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.icons' },        -- if you use standalone mini plugins
  --     -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
  init = function()
    vim.filetype.add({
      extension = { mdx = "markdown.mdx" },
    })
  end,
  ---@module "render-markdown"
  ---@type render.md.UserConfig
  opts = {
    preset = "lazy",
    completions = {
      lsp = { enabled = true },
    },
    anti_conceal = {
      above = 1,
      below = 1,
    },
    code = {
      conceal_delimiters = false,
    },
  },
  config = function(_, opts)
    local render_markdown = require("render-markdown")
    render_markdown.setup(opts)

    local function map_if_free(lhs, rhs, desc)
      if vim.fn.maparg(lhs, "n") == "" then
        vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
      end
    end

    map_if_free("<leader>um", render_markdown.set, "Toggle markdown render")
    map_if_free("<leader>uM", render_markdown.set_buf, "Toggle markdown render (buffer)")
  end,
}
