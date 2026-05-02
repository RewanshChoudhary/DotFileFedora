return {
  {
    "folke/which-key.nvim",
    lazy = false,
    opts = function(_, opts)
      opts.delay = 120
      return opts
    end,
  },
}
