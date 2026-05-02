return {
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufReadPost",
    init = function()
      vim.o.foldcolumn = "1"
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
    end,
    opts = {
      provider_selector = function(_, _, _)
        return { "treesitter", "indent" }
      end,
      close_fold_kinds_for_ft = {
        default = { "imports", "comment" },
      },
      preview = {
        win_config = {
          border = "rounded",
          winblend = 0,
        },
      },
    },
    config = function(_, opts)
      local ufo = require("ufo")
      ufo.setup(opts)

      local function map_if_free(lhs, rhs, desc)
        if vim.fn.maparg(lhs, "n") == "" then
          vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
        end
      end

      map_if_free("zR", ufo.openAllFolds, "Open all folds")
      map_if_free("zM", ufo.closeAllFolds, "Close all folds")
      map_if_free("zp", function()
        local winid = ufo.peekFoldedLinesUnderCursor()
        if not winid then
          vim.notify("No folded lines under cursor", vim.log.levels.INFO)
        end
      end, "Peek folded lines")
    end,
  },

  {
    "dnlhc/glance.nvim",
    cmd = "Glance",
    opts = {
      border = { enable = true },
      list = { position = "right", width = 0.33 },
      theme = { enable = true, mode = "auto" },
    },
    config = function(_, opts)
      require("glance").setup(opts)

      local function map_if_free(lhs, rhs, desc)
        if vim.fn.maparg(lhs, "n") == "" then
          vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
        end
      end

      map_if_free("<leader>ld", "<cmd>Glance definitions<cr>", "Peek definitions")
      map_if_free("<leader>lr", "<cmd>Glance references<cr>", "Peek references")
      map_if_free("<leader>li", "<cmd>Glance implementations<cr>", "Peek implementations")
      map_if_free("<leader>lt", "<cmd>Glance type_definitions<cr>", "Peek type definitions")
    end,
  },

  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    opts = {},
    config = function(_, opts)
      require("inc_rename").setup(opts)

      if vim.fn.maparg("<leader>cR", "n") == "" then
        vim.keymap.set("n", "<leader>cR", function()
          return ":IncRename " .. vim.fn.expand("<cword>")
        end, { expr = true, desc = "Rename symbol (preview)" })
      end
    end,
  },

  {
    "nvim-pack/nvim-spectre",
    cmd = "Spectre",
    opts = {
      open_cmd = "noswapfile vnew",
    },
    config = function(_, opts)
      local spectre = require("spectre")
      spectre.setup(opts)

      local function map_if_free(lhs, rhs, desc)
        if vim.fn.maparg(lhs, "n") == "" then
          vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
        end
      end

      map_if_free("<leader>sr", spectre.toggle, "Project search and replace")
      map_if_free("<leader>sw", function()
        spectre.open_visual({ select_word = true })
      end, "Search current word in project")
    end,
  },
}
