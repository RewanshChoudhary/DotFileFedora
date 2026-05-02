return {
  {
    "nacro90/numb.nvim",
    event = "CmdlineEnter",
    opts = {},
  },

  {
    "Wansmer/treesj",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    cmd = { "TSJToggle", "TSJJoin", "TSJSplit" },
    opts = {
      use_default_keymaps = false,
    },
  },

  {
    "axieax/urlview.nvim",
    cmd = "UrlView",
    opts = {},
  },
}
