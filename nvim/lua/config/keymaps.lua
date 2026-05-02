-- Remove default keymaps if they conflict
pcall(vim.keymap.del, "n", "<leader>l")

-- VSCode-like keybindings
local map = vim.keymap.set

-- Delete visual selection with Backspace
vim.keymap.set("v", "<BS>", "d", { noremap = true, silent = true })
-- Select All (Ctrl+A)
map("n", "<C-a>", "ggVG", { desc = "Select all" })
map("i", "<C-a>", "<Esc>ggVG", { desc = "Select all" })
map("v", "<C-a>", "<Esc>ggVG", { desc = "Select all" })

-- Copy (Ctrl+C)
map("v", "<C-c>", '"+y', { desc = "Copy" })
map("n", "<C-c>", '"+yy', { desc = "Copy line" })

-- Cut (Ctrl+X)
map("v", "<C-x>", '"+d', { desc = "Cut" })
map("n", "<C-x>", '"+dd', { desc = "Cut line" })

-- Paste (Ctrl+V)
map("n", "<C-v>", '"+p', { desc = "Paste" })
map("i", "<C-v>", "<C-r>+", { desc = "Paste" })
map("v", "<C-v>", '"+p', { desc = "Paste" })

-- Undo (Ctrl+Z)
map("n", "<C-z>", "u", { desc = "Undo" })
map("i", "<C-z>", "<C-o>u", { desc = "Undo" })

-- Redo (Ctrl+Y or Ctrl+Shift+Z)
map("n", "<C-y>", "<C-r>", { desc = "Redo" })
map("i", "<C-y>", "<C-o><C-r>", { desc = "Redo" })
map("n", "<C-S-z>", "<C-r>", { desc = "Redo" })
map("i", "<C-S-z>", "<C-o><C-r>", { desc = "Redo" })

-- Save (Ctrl+S)
map("n", "<C-s>", ":w<CR>", { desc = "Save file" })
map("i", "<C-s>", "<C-o>:w<CR>", { desc = "Save file" })
map("v", "<C-s>", "<Esc>:w<CR>", { desc = "Save file" })

-- Shift+Arrow for selection in insert mode
map("i", "<S-Up>", "<Esc>v<Up>", { desc = "Select up" })
map("i", "<S-Down>", "<Esc>v<Down>", { desc = "Select down" })
map("i", "<S-Left>", "<Esc>v<Left>", { desc = "Select left" })
map("i", "<S-Right>", "<Esc>v<Right>", { desc = "Select right" })

-- Shift+Arrow for selection in normal mode
map("n", "<S-Up>", "v<Up>", { desc = "Select up" })
map("n", "<S-Down>", "v<Down>", { desc = "Select down" })
map("n", "<S-Left>", "v<Left>", { desc = "Select left" })
map("n", "<S-Right>", "v<Right>", { desc = "Select right" })

-- Shift+Arrow for extending selection in visual mode
map("v", "<S-Up>", "<Up>", { desc = "Extend selection up" })
map("v", "<S-Down>", "<Down>", { desc = "Extend selection down" })
map("v", "<S-Left>", "<Left>", { desc = "Extend selection left" })
map("v", "<S-Right>", "<Right>", { desc = "Extend selection right" })

-- Backspace to delete in normal mode
map("n", "<BS>", "X", { desc = "Delete character before cursor" })

-- Delete line (Ctrl+Shift+K)
map("n", "<C-S-k>", "dd", { desc = "Delete line" })
map("i", "<C-S-k>", "<C-o>dd", { desc = "Delete line" })

-- Duplicate line (Ctrl+Shift+D)
map("n", "<C-S-d>", "yyp", { desc = "Duplicate line down" })
map("i", "<C-S-d>", "<C-o>yyp", { desc = "Duplicate line down" })

-- Find (Ctrl+F)
map("n", "<C-f>", "/", { desc = "Find" })
map("i", "<C-f>", "<Esc>/", { desc = "Find" })

-- Comment toggle (Ctrl+/)
map("n", "<C-_>", "gcc", { desc = "Toggle comment", remap = true })
map("i", "<C-_>", "<C-o>gcc", { desc = "Toggle comment", remap = true })
map("v", "<C-_>", "gc", { desc = "Toggle comment", remap = true })

-- LSP docs / hover
map("n", "K", vim.lsp.buf.hover, { desc = "Hover Documentation" })
map("n", "gh", vim.lsp.buf.hover, { desc = "Hover Documentation" })

-- Cmdline UX: arrow keys navigate command completion/history and <CR> executes selected entry.
map("c", "<Down>", function()
  if vim.fn.wildmenumode() == 1 then
    return "<C-n>"
  end
  return "<Down>"
end, { expr = true, noremap = true, desc = "Cmdline next completion/history" })

map("c", "<Up>", function()
  if vim.fn.wildmenumode() == 1 then
    return "<C-p>"
  end
  return "<Up>"
end, { expr = true, noremap = true, desc = "Cmdline previous completion/history" })

map("c", "<CR>", function()
  if vim.fn.wildmenumode() == 1 then
    return "<C-y><CR>"
  end
  return "<CR>"
end, { expr = true, noremap = true, desc = "Accept cmdline selection" })

-- Harpoon quick menu: guard against accidental double-trigger closing right after open.
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    local uv = vim.uv or vim.loop
    local last_toggle_ns = 0
    local min_interval_ns = 220 * 1000000

    vim.keymap.set("n", "<leader>h", function()
      local now = uv.hrtime()
      if now - last_toggle_ns < min_interval_ns then
        return
      end
      last_toggle_ns = now

      local harpoon = require("harpoon")
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end, { desc = "Harpoon Quick Menu", silent = true })
  end,
})
