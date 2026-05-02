return {
  {
    "maxmx03/fluoromachine.nvim",
    lazy = true,
    priority = 1000,
    config = function()
      require("fluoromachine").setup({
        glow = true,
        theme = "fluoromachine",
        transparent = true,
      })
      vim.cmd("colorscheme fluoromachine")
    end,
  },

  {
    "qaptoR-nvim/chocolatier.nvim",
    lazy = true,
    priority = 1000,
    config = function()
      vim.cmd("colorscheme chocolatier")
    end,
  },

  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = false,
        color_overrides = {
          mocha = {
            base = "#1b1f2f",
            mantle = "#171a28",
            crust = "#121521",
            surface0 = "#2f334a",
            surface1 = "#3b405b",
            text = "#c4c8da",
            subtext1 = "#aab0c5",
            red = "#f38ba8",
            green = "#8bd5b0",
            yellow = "#f2d39b",
            blue = "#8ea6ff",
            pink = "#f6a0ca",
            mauve = "#b4befe",
            teal = "#86d8da",
            sky = "#86d8da",
            sapphire = "#78c4d4",
          },
        },
        custom_highlights = function(colors)
          return {
            Normal = { bg = "none" },
            NormalNC = { bg = "none" },
            NormalFloat = { bg = "none" },
            FloatBorder = { fg = colors.pink, bg = "none" },
            WinSeparator = { fg = colors.surface0, bg = "none" },
            LineNr = { fg = "#d386b5" },
            CursorLineNr = { fg = colors.pink, bold = true },
            CursorLine = { bg = "none" },
            Comment = { fg = colors.sapphire, italic = false },
            ["@comment"] = { fg = colors.sapphire, italic = false },
            Keyword = { fg = colors.pink },
            ["@keyword"] = { fg = colors.pink },
            ["@keyword.return"] = { fg = colors.pink },
            Statement = { fg = colors.pink },
            String = { fg = colors.green },
            ["@string"] = { fg = colors.green },
            Function = { fg = colors.teal },
            ["@function"] = { fg = colors.teal },
            ["@function.call"] = { fg = colors.teal },
            Identifier = { fg = colors.mauve },
            ["@variable"] = { fg = colors.text },
            Type = { fg = colors.blue },
            ["@type"] = { fg = colors.blue },
            Constant = { fg = colors.pink },
            ["@constant"] = { fg = colors.pink },
            Operator = { fg = colors.pink },
            Visual = { bg = colors.surface0, fg = colors.text },
            Search = { bg = colors.pink, fg = colors.crust },
            IncSearch = { bg = colors.teal, fg = colors.crust },
          }
        end,
      })
      vim.cmd("colorscheme catppuccin")
    end,
  },

  {
    "sainnhe/gruvbox-material",
    lazy = true,
    priority = 1000,
    config = function()
      vim.cmd("colorscheme gruvbox-material")
    end,
  },

  {
    "sainnhe/everforest",
    lazy = true,
    priority = 1000,
    config = function()
      vim.g.everforest_enable_italic = true
      vim.cmd("colorscheme everforest")
    end,
  },

  {
    "nvimdev/zephyr-nvim",
    lazy = true,
    priority = 1000,
  },

  {
    "ptdewey/monalisa-nvim",
    lazy = true,
    priority = 1000,
    config = function()
      vim.cmd("colorscheme monalisa")
    end,
  },

  {
    "nyngwang/nvimgelion",
    lazy = true,
    priority = 1000,
    config = function()
      vim.cmd("colorscheme nvimgelion")
    end,
  },

  {
    "zootedb0t/citruszest.nvim",
    lazy = true,
    priority = 1000,
    config = function()
      vim.cmd("colorscheme citruszest")
    end,
  },

  {
    "xero/miasma.nvim",
    lazy = true,
    priority = 1000,
    config = function()
      vim.cmd("colorscheme miasma")
    end,
  },

  {
    "ribru17/bamboo.nvim",
    lazy = true,
    priority = 1000,
    config = function()
      require("bamboo").setup({})
    end,
  },

  {
    "cryptomilk/nightcity.nvim",
    lazy = true,
    priority = 1000,
    config = function()
      vim.cmd("colorscheme nightcity")
    end,
  },

  {
    "ellisonleao/gruvbox.nvim",
    lazy = true,
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        transparent_background = true,
      })
      vim.cmd("colorscheme gruvbox")
    end,
  },

  {
    "EdenEast/nightfox.nvim",
    lazy = true,
    priority = 1000,
    config = function()
      vim.cmd("colorscheme nightfox")
    end,
  },

  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    priority = 1000,
    config = function()
      require("rose-pine").setup({
        variant = "moon",
      })
      vim.cmd("colorscheme rose-pine")
    end,
  },

  {
    "rebelot/kanagawa.nvim",
    lazy = true,
    priority = 1000,
    config = function()
      vim.cmd("colorscheme kanagawa-wave")
    end,
  },

  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("hyprwave_theme").apply("mystic-portal")
    end,
  },
}
