return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
      highlight = { enable = true },
      ensure_installed = {
        "go",
        "java",
        "typescript",
        "javascript",
        "c",
        "cpp",
        "rust",
        "python",
      },
    },
  },

  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "BufReadPost",
    config = function()
      local rd = require("rainbow-delimiters")

      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rd.strategy["global"],
          vim = rd.strategy["local"],
        },
        query = {
          [""] = "rainbow-delimiters",
        },
        priority = {
          [""] = 110,
        },
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterOrange",
          "RainbowDelimiterYellow",
          "RainbowDelimiterGreen",
          "RainbowDelimiterBlue",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }

      -- Gruvbox-compatible colors
      vim.api.nvim_set_hl(0, "RainbowDelimiterRed", { fg = "#fb4934" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterOrange", { fg = "#fe8019" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterYellow", { fg = "#fabd2f" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterGreen", { fg = "#b8bb26" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterBlue", { fg = "#83a598" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterViolet", { fg = "#d3869b" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterCyan", { fg = "#8ec07c" })
    end,
  },
}
